// The façade the phone's screens read and drive (android/BRIDGE.md §2). It owns the DeviceSession, builds
// each ViewState area from it, and publishes an area as JSON only when it changed, at most once per display
// frame per area. Change detection is Observation's withObservationTracking around each area's builder.
import Foundation
import Observation
import SloopKit

@MainActor
public final class PhoneCore {
    public let session: DeviceSession
    private let publish: (String, String) -> Void
    let log: (String) -> Void
    private var runTask: Task<Void, Never>?
    private var areas: [AreaWatch] = []
    private var clockTask: Task<Void, Never>?
    private var projectTask: Task<Void, Never>?
    /// Screen-local choices (nothing sent to the FM-1): the pad the editor shows, the step selected.
    var pickedPad: PadsArea.Ref?
    var selectedStep = 0

    /// `publish(area, json)` is called on the main actor. `log` gets lines worth keeping (intents not done yet).
    public init(session: DeviceSession, publish: @escaping (String, String) -> Void, log: @escaping (String) -> Void = { _ in }) {
        self.session = session; self.publish = publish; self.log = log
    }

    /// Starts the session's search loop and the area watches. Each area is published once at once.
    public func start() {
        guard runTask == nil else { return }
        let s = session
        runTask = Task { await s.run() }
        areas = [
            AreaWatch(name: "link", build: { [unowned self] in AreaJSON.encode(self.linkArea()) }, publish: publish),
            AreaWatch(name: "top", build: { [unowned self] in AreaJSON.encode(self.topArea()) }, publish: publish),
            // Only once the FM-1 has been read: before that Session holds placeholder tracks, not the FM-1's.
            AreaWatch(name: "pads", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.padsArea()) : nil }, publish: publish),
            AreaWatch(name: "editor", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.editorArea()) : nil }, publish: publish),
            // Only while the FM-1's screen is on a sound page (nil otherwise: the last page stays; the shell says what shows).
            AreaWatch(name: "page", build: { [unowned self] in self.pageArea().map(AreaJSON.encode) }, publish: publish),
            AreaWatch(name: "diag", build: { [unowned self] in AreaJSON.encode(self.diagArea()) }, publish: publish),
        ]
        areas.forEach { $0.start() }
        // The clock count isn't observed (Session samples it per frame on the iPad), so while playing the top
        // area is rebuilt every 50 ms; it is only sent when the bar or beat actually moved.
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self else { return }
                if self.session.playing {
                    self.areas.first { $0.name == "top" }?.poke()
                    for n in ["diag", "pads", "editor"] { self.areas.first { $0.name == n }?.poke() }
                }
            }
        }
        // The project's name (top.project): Session reads PROJ_NAME only when the iPad's Projects sheet opens, so
        // the phone reads it on reaching ready and every 5 s after (a read; a SAVE AS on the FM-1 shows up).
        projectTask = Task { [weak self] in
            var wasReady = false
            while !Task.isCancelled {
                guard let self else { return }
                let ready = self.session.isConnected
                if ready { await self.session.refreshSkiffProjects() }
                try? await Task.sleep(for: ready && wasReady ? .seconds(5) : .milliseconds(250))
                wasReady = ready
            }
        }
    }

    private func poke(_ names: [String]) { for n in names { areas.first { $0.name == n }?.poke() } }

    public func stop() {
        runTask?.cancel(); runTask = nil
        clockTask?.cancel(); clockTask = nil
        projectTask?.cancel(); projectTask = nil
        areas.forEach { $0.stop() }; areas = []
    }

    // MARK: Areas

    public func linkArea() -> LinkArea {
        switch session.status {
        case .searching: return LinkArea(phase: .searching)
        case .connecting: return LinkArea(phase: session.reading ? .reading : .connecting)
        case .connected: return LinkArea(phase: .ready)
        case .wrongFirmware(let found, _): return LinkArea(phase: .wrongFirmware, firmware: found)
        case .lost(let why):
            // Session's words: "FM-1 disconnected" (the frames stream ended while connected) or "Lost the FM-1
            // while reading it".
            return LinkArea(phase: .lost, reason: why.contains("reading") ? "readFailed" : "unplugged")
        }
    }

    public func topArea() -> TopArea {
        let s = session
        let song = s.skiffSong?.song
        let mode: TopArea.Mode = switch song?.mode ?? .off { case .off: .loop; case .on: .song; case .once: .once }
        let launch: TopArea.Launch = switch s.launchMode { case .loop: .loop; case .bar: .bar; case .beat: .beat; case .now: .now }
        // Launches queued for the launch point (the pads' "waiting"), not the song's own next entries ("next").
        let waiting = s.trackIndices.filter { s.skiffSong?.marks($0, launchIn: nil).queued != nil }.count
        let selectedArmed = s.armedTracks & (1 << s.selectedTrack) != 0
        var bar = 1, beat = 1
        if s.playing, s.clockTicks >= 0 {
            let beats = s.clockTicks / 24             // MIDI clock: 24 pulses a beat
            bar = beats / 4 + 1; beat = beats % 4 + 1
        }
        return TopArea(project: s.skiffProjects?.name ?? "", playing: s.playing, rec: selectedArmed || s.isRecordingAnything,
                       tempo: Double(s.bpm), mode: mode, launch: launch, waiting: waiting, bar: bar, beat: beat)
    }

    public func diagArea() -> DiagArea {
        let s = session, d = s.deviceScreen
        return DiagArea(firmware: s.info?.version, tracks: s.trackCount, selectedTrack: s.selectedTrack, screenLinked: s.screenLinked,
                        page: d?.page, layer: d?.layer, menu: d?.menu, home: d?.home, clockTicks: s.clockTicks, playing: s.playing)
    }

    // MARK: Intents

    /// One intent from Compose, as JSON.
    public func handle(json: String) {
        if handlePageJSON(json) { return }       // setParam, pickPage, pickRoute, pickTile (PageArea.swift)
        do { handle(try PhoneIntent.decode(json)) } catch { log("intent not understood: \(json) (\(error))") }
    }

    public func handle(_ intent: PhoneIntent) {
        switch intent {
        case .retry:
            // Session looks again every second on its own; retry restarts the loop at once (a wrong-firmware
            // FM-1 otherwise waits 3 s between looks).
            runTask?.cancel()
            let s = session
            runTask = Task { await s.run() }
        case .play: session.setPlaying(true)
        case .stop: session.setPlaying(false)
        case .padSelect(let track, let entry): pickedPad = PadsArea.Ref(track: track, entry: entry); poke(["pads", "editor"])
        case .stepSelect(let i): selectedStep = max(0, min(15, i)); poke(["editor"])
        default: log("intent not handled yet (later phase): \(intent)")
        }
    }
}

/// Re-runs one area's builder whenever something it read changes, and publishes the JSON when it differs from
/// the last one sent. Changes within one display frame (16 ms) are coalesced into a single send.
@MainActor
final class AreaWatch {
    let name: String
    /// nil: nothing to send yet.
    private let build: () -> String?
    private let publish: (String, String) -> Void
    private var last: String?
    private var scheduled = false
    private var live = false

    init(name: String, build: @escaping () -> String?, publish: @escaping (String, String) -> Void) {
        self.name = name; self.build = build; self.publish = publish
    }

    func start() { live = true; evaluate() }
    func stop() { live = false }

    private func evaluate() {
        guard live else { return }
        let json = withObservationTracking { build() } onChange: { [weak self] in
            Task { @MainActor in self?.changed() }
        }
        if let json, json != last { last = json; publish(name, json) }
    }

    /// Rebuild soon even though nothing observed changed (the clock count).
    func poke() { changed() }

    private func changed() {
        guard live, !scheduled else { return }
        scheduled = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            scheduled = false
            evaluate()
        }
    }
}

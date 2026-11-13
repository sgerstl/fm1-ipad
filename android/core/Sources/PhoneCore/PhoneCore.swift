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
    /// The editor's own state (PadsEditorIntents.swift): a step held, Lock latched, Chord entry, the lane shown, the
    /// step copied. None of it is sent to the FM-1 except through Session.lockStep.
    var heldStep: Int?
    var lockLatched = false
    var chordMode = false
    var pickedLane: String?
    var copiedStep: SynthStep?
    /// The note the last key wrote and when (the FM-1 sounds a written step: not a new key).
    var lastKeyWrite: (note: Int, at: Date)?
    var notesIn = 0
    private var motionTask: Task<Void, Never>?
    private var followTask: Task<Void, Never>?
    /// Whether writes may go to the FM-1 now (the link's read-only switch). Write intents are refused up front
    /// while false, so Session's optimistic copy never shows what the FM-1 didn't get.
    let canWrite: () -> Bool

    /// `publish(area, json)` is called on the main actor. `log` gets lines worth keeping (intents not done yet).
    public init(session: DeviceSession, publish: @escaping (String, String) -> Void, log: @escaping (String) -> Void = { _ in },
                canWrite: @escaping () -> Bool = { true }) {
        self.session = session; self.publish = publish; self.log = log; self.canWrite = canWrite
    }

    /// Starts the session's search loop and the area watches. Each area is published once at once.
    public func start() {
        guard runTask == nil else { return }
        let s = session
        runTask = Task { await s.run() }
        s.onDeviceNote = { [weak self] e in                            // the FM-1's keys into the step (decision 5)
            guard let self else { return }
            if e.on { self.notesIn += 1; self.pokeAreas(["diag"]) }
            self.keyIntoStep(e)
        }
        areas = [
            AreaWatch(name: "link", build: { [unowned self] in AreaJSON.encode(self.linkArea()) }, publish: publish),
            AreaWatch(name: "top", build: { [unowned self] in AreaJSON.encode(self.topArea()) }, publish: publish),
            // Only once the FM-1 has been read: before that Session holds placeholder tracks, not the FM-1's.
            AreaWatch(name: "pads", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.padsArea()) : nil }, publish: publish),
            AreaWatch(name: "editor", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.editorArea()) : nil }, publish: publish),
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
        // The song lists kept current, as the iPad's Pads page does (`.task { await store.follow() }`): LIST read
        // again on its own pace, closer to a launch point. Without it the phone saw a launch land only after its own
        // next write (Scott's run, 2026-11-14: "waiting" stuck for ten bars, take-back taps acting on old lists).
        // A new store comes with each connection: the loop follows whichever is current.
        followTask = Task { [weak self] in
            var running: (store: SkiffSongStore, task: Task<Void, Never>)?
            while !Task.isCancelled {
                guard let self else { return }
                let store = self.session.isConnected ? self.session.skiffSong : nil
                if running?.store !== store || (store?.offline ?? false) {
                    running?.task.cancel(); running = nil
                    if let store, !store.offline { running = (store, Task { await store.follow() }) }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            running?.task.cancel()
        }
        // The editor's locks and automation (MOTION, a read): the editor's track every 3 s, at once when it changes.
        motionTask = Task { [weak self] in
            var last = -1
            while !Task.isCancelled {
                guard let self else { return }
                if self.session.isConnected, self.session.dialect == .skiff {
                    let t = self.editorTrack()
                    await self.session.readMotion(track: t)
                    if t != last { last = t; self.poke(["editor"]) }
                }
                for _ in 0..<30 { try? await Task.sleep(for: .milliseconds(100)); if self.editorTrack() != last { break } }
            }
        }
    }

    private func poke(_ names: [String]) { for n in names { areas.first { $0.name == n }?.poke() } }
    func pokeAreas(_ names: [String]) { poke(names) }

    public func stop() {
        session.onDeviceNote = nil
        runTask?.cancel(); runTask = nil
        clockTask?.cancel(); clockTask = nil
        projectTask?.cancel(); projectTask = nil
        motionTask?.cancel(); motionTask = nil
        followTask?.cancel(); followTask = nil
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
        // A take-back stages the entry already playing (the FM-1 has no per-track cancel): not a launch waiting.
        let waiting = s.trackIndices.filter { t in
            guard let l = s.skiffSong?.song?.tracks[safe: t], l.staged != l.entryOn else { return false }
            return s.skiffSong?.marks(t, launchIn: nil).queued != nil
        }.count
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
                        page: d?.page, layer: d?.layer, menu: d?.menu, home: d?.home, clockTicks: s.clockTicks, playing: s.playing, notesIn: notesIn)
    }

    // MARK: Intents

    /// One intent from Compose, as JSON.
    public func handle(json: String) {
        do {
            if let p = try PadEditIntent.decode(json) { handle(p); return }   // P3's pads and editor
            handle(try PhoneIntent.decode(json))
        } catch { log("intent not understood: \(json) (\(error))") }
    }

    public func handle(_ intent: PhoneIntent) {
        switch intent {
        case .retry:
            // Session looks again every second on its own; retry restarts the loop at once (a wrong-firmware
            // FM-1 otherwise waits 3 s between looks).
            runTask?.cancel()
            let s = session
            runTask = Task { await s.run() }
        case .play, .stop:
            guard canWrite() else { log("read-only: \(intent) not sent (allow writes to send it)"); return }
            session.setPlaying(intent == .play)
        case .padSelect(let track, let entry):
            pickedPad = PadsArea.Ref(track: track, entry: entry)
            // as the iPad's Edit steps: the track selected and, stopped, put on that entry (Skiff edits only the
            // pattern a track is on). While read-only only the screen's choice moves.
            if canWrite() {
                let t = track - 1
                session.select(track: t)
                if !session.playing, let store = session.skiffSong, store.song?.tracks[safe: t]?.entryOn != entry {
                    Task { await store.send(.play(track: t, entry: entry)) }
                }
            }
            poke(["pads", "editor"])
        case .stepSelect(let i):
            selectedStep = max(0, min(15, i))
            if lockLatched { syncLockStep() }   // a latched lock follows the selection (the iPad's Lock does)
            poke(["editor"])
        case .cancelWaiting:
            guard canWrite() else { log("read-only: cancelWaiting not sent"); return }
            if let store = session.skiffSong { Task { await store.performOp(.cancel) } }
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

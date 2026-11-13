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
    /// The editor's own state (PadsEditorIntents.swift): a step held, Lock latched, the lane shown, the
    /// step copied. None of it is sent to the FM-1 except through Session.lockStep.
    var heldStep: Int?
    var lockLatched = false
    var pickedLane: String?
    var copiedStep: SynthStep?
    var notesIn = 0
    /// P5's screen-local state (P5Areas.swift): the Mix section on screen, Lupe's solos, the Sounds browser's target
    /// and the engine browsed, a project op going on.
    var mixSection = "mixer"
    var soundsTrack: Int?          // nil: the selected track
    var soundsEntry: Int?
    var soundsViewing: Int?
    var projectBusy = false
    /// The page lag's timing (LagTrace.swift), opened by pickPage and goHome.
    lazy var lag = LagTrace(log: log)
    private var lastScreen: UIState?
    private var motionTask: Task<Void, Never>?
    private var followTask: Task<Void, Never>?
    private var sendsTask: Task<Void, Never>?
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
        // The FM-1's keys play its sound and never write from the phone (decision 5 revised, Scott 2026-11-14: "the
        // fm1 keys should work just like they do on the ipad"). The notes are only counted, for the debug screen.
        s.onDeviceNote = { [weak self] e in
            guard let self, e.on else { return }
            self.notesIn += 1; self.pokeAreas(["diag"])
        }
        areas = [
            // marks the screen's changes in an open lag trace (the optimistic one, then the FM-1's reply or push)
            AreaWatch(name: "screenTrace", build: { [unowned self] in
                let sc = self.session.deviceScreen
                if sc != self.lastScreen {
                    self.lastScreen = sc
                    if self.lag.active { self.lag.mark("screen now page \(sc?.page ?? -1) home \(sc?.home ?? false)") }
                }
                return nil
            }, publish: { _, _ in }),
            AreaWatch(name: "link", build: { [unowned self] in AreaJSON.encode(self.linkArea()) }, publish: publish),
            AreaWatch(name: "top", build: { [unowned self] in AreaJSON.encode(self.topArea()) }, publish: publish),
            // Only once the FM-1 has been read: before that Session holds placeholder tracks, not the FM-1's.
            AreaWatch(name: "pads", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.padsArea()) : nil }, publish: publish),
            AreaWatch(name: "editor", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.editorArea()) : nil }, publish: publish),
            // Only while the FM-1's screen is on a sound page (nil otherwise: the last page stays; the shell says what shows).
            // shell.bottom only (tab and divider are Kotlin's): the sound page the FM-1 shows, else the editor
            AreaWatch(name: "shell", build: { [unowned self] in self.shellArea().map(AreaJSON.encode) }, publish: publish),
            AreaWatch(name: "pageReads", build: { [unowned self] in self.readDenseData() }, publish: { _, _ in }),   // asks for the dense pages' data
            // FREE TAKE (FreeTakeArea.swift): the offer, the FM-1's picker, the landing
            AreaWatch(name: "freetake", build: { [unowned self] in self.freeTakeArea().map(AreaJSON.encode) }, publish: publish),
            AreaWatch(name: "page", build: { [unowned self] in self.pageArea().map(AreaJSON.encode) }, publish: publish),
            // HOME's four knobs (decision 21): the selected track's engine's, as the FM-1 shows them
            AreaWatch(name: "homeKnobs", build: { [unowned self] in self.homeKnobsArea().map(AreaJSON.encode) }, publish: publish),
            // P5: once the FM-1 has been read, as pads and editor
            AreaWatch(name: "mix", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.mixArea()) : nil }, publish: publish),
            AreaWatch(name: "meters", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.metersArea()) : nil }, publish: publish),
            AreaWatch(name: "sounds", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.soundsArea()) : nil }, publish: publish),
            AreaWatch(name: "projects", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.projectsArea()) : nil }, publish: publish),
            // P6: once the FM-1 has been read
            AreaWatch(name: "timeline", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.timelineArea()) : nil }, publish: publish),
            AreaWatch(name: "automation", build: { [unowned self] in self.session.isConnected ? AreaJSON.encode(self.automationArea()) : nil }, publish: publish),
            AreaWatch(name: "diag", build: { [unowned self] in AreaJSON.encode(self.diagArea()) }, publish: publish),
        ]
        for a in areas {
            a.trace = { [weak self] name, ms, bytes, published in
                guard let self, self.lag.active else { return }
                self.lag.mark(String(format: "%@ built in %.1f ms, %d bytes%@", name, ms, bytes, published ? ", published" : ""))
            }
        }
        areas.forEach { $0.start() }
        // The clock count isn't observed (Session samples it per frame on the iPad), so while playing the top
        // area is rebuilt every 50 ms; it is only sent when the bar or beat actually moved.
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self else { return }
                // the meters fall back after the notes stop: sampled while connected (sent only when they move)
                if self.session.isConnected { self.areas.first { $0.name == "meters" }?.poke() }
                if self.session.playing {
                    self.areas.first { $0.name == "top" }?.poke()
                    for n in ["diag", "pads", "editor", "timeline"] { self.areas.first { $0.name == n }?.poke() }
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
        // Every track's REVERB send for the Mix rows (TRACK_PARAM reads), every 3 s, as the iPad's Mix strips read it
        sendsTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.session.isConnected, let id = self.reverbSendID { await self.session.readEveryTrack(id: id); self.poke(["mix"]) }
                try? await Task.sleep(for: .seconds(3))
            }
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
    /// The named areas built and published at once (AreaWatch.now).
    func publishNow(_ names: [String]) { for n in names { areas.first { $0.name == n }?.now() } }

    public func stop() {
        session.onDeviceNote = nil
        runTask?.cancel(); runTask = nil
        clockTask?.cancel(); clockTask = nil
        projectTask?.cancel(); projectTask = nil
        motionTask?.cancel(); motionTask = nil
        followTask?.cancel(); followTask = nil
        sendsTask?.cancel(); sendsTask = nil
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
        if handlePageJSON(json) || handleFreeTakeJSON(json) || handleHomeJSON(json) { return }       // setParam, pickPage, pickRoute, pickTile (PageArea.swift)
        do {
            if let p = try PadEditIntent.decode(json) { handle(p); return }   // P3's pads and editor
            if let p = try P5Intent.decode(json) { handle(p); return }        // P5's mix, sounds, projects
            if let p = try P6Intent.decode(json) { handle(p); return }        // P6's timeline, automation
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
        case .setPlaybackMode(let m):
            guard canWrite() else { log("read-only: setPlaybackMode not sent"); return }
            let mode: SongMode = switch m { case .loop: .off; case .song: .on; case .once: .once }
            if let store = session.skiffSong { Task { if !(await store.send(.song(mode))) { self.reportRefusal(store) } } }
        case .cancelWaiting:
            guard canWrite() else { log("read-only: cancelWaiting not sent"); return }
            if let store = session.skiffSong { Task { await store.performOp(.cancel) } }
        // the readout's controls, through the iPad's calls: TempoPanel's setBPM (clamped to the FM-1's range; not
        // while following another clock), the REC button's toggleRec (Skiff's arm-the-others case included), and
        // SongTools' launch quantise (PERFORM's launch, adopted once the FM-1 takes it). Each republishes `top`
        // once the FM-1's answer is read back.
        case .setTempo(let bpm):
            guard canWrite() else { log("read-only: setTempo not sent (allow writes to send it)"); return }
            if session.externalClock != nil { log("the FM-1 follows another clock: its tempo comes from there"); return }
            let s = session
            s.setBPM(Int(bpm.rounded()))
            Task {
                try? await Task.sleep(for: .milliseconds(300))      // the write sent; the FM-1 may have clamped it
                await s.refreshTempo()
                self.poke(["top"])
            }
        case .rec:
            guard canWrite() else { log("read-only: rec not sent (allow writes to send it)"); return }
            session.toggleRec()                                      // reads TRANSPORT back itself
            Task { try? await Task.sleep(for: .milliseconds(300)); self.poke(["top"]) }
        case .setLaunch(let q):
            guard canWrite() else { log("read-only: setLaunch not sent (allow writes to send it)"); return }
            guard let store = session.skiffSong else { log("no song read yet"); return }
            let l: SongPlayback.Launch = switch q { case .loop: .loop; case .bar: .bar; case .beat: .beat; case .now: .now }
            let s = session
            Task {
                if await store.performOp(.launch(l)) { s.adoptLaunch(l) } else { self.reportRefusal(store) }
                self.poke(["top"])
            }
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
    /// Set by PhoneCore: called after every build (area, build time ms, bytes, published), for the lag trace.
    var trace: ((String, Double, Int, Bool) -> Void)?

    init(name: String, build: @escaping () -> String?, publish: @escaping (String, String) -> Void) {
        self.name = name; self.build = build; self.publish = publish
    }

    func start() { live = true; evaluate() }
    func stop() { live = false }

    private func evaluate() {
        guard live else { return }
        let t = trace == nil ? 0 : LagClock.now()
        let json = withObservationTracking { build() } onChange: { [weak self] in
            Task { @MainActor in self?.changed() }
        }
        let fresh = json != nil && json != last
        if let json, fresh { last = json; publish(name, json) }
        if let trace { trace(name, LagClock.now() - t, json?.utf8.count ?? 0, fresh) }
    }

    /// Rebuild soon even though nothing observed changed (the clock count).
    func poke() { changed() }
    /// Rebuild now, without the frame's wait: for an intent the person is watching (a family key, the back gesture),
    /// after Session has set its optimistic copy. An unchanged build sends nothing, and a rebuild already scheduled
    /// finds nothing new.
    func now() { evaluate() }

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

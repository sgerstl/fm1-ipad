import Foundation
import Observation

/// What the app knows about one track. The FM-1 is the authority; this is a mirror.
public struct TrackState: Equatable, Sendable {
    public var index: Int
    public var isDrums: Bool { index == 3 }
    public var engine = 0
    public var engineName = ""
    public var preset = 0
    public var presetName = ""
    public var steps = Array(repeating: SynthStep.empty, count: 64)
    public var drumSteps = Array(repeating: DrumStep.empty, count: 64)
    public var level = 100          // P_LEVEL; the drum track's is G_DRLVL
    public var root = 0
    public var scale = 0
    public var quant = 0            // P_QNT: 0 OFF, 1 SNAP, 2 WHITE (how the FM-1's keys map to notes)
    public var transpose = 0        // P_TRN, semitones
    public var chord = 0            // P_CHORD: 0 OFF
    public var arpMode = 0          // P_AMODE: 0 OFF
    public var length = 16          // P_SLEN
    public var division = 2         // P_SDIV, 1/16
    public var pan = 0
    public var mute = false
    public var loaded = false

    public init(index: Int) { self.index = index }

    public func isOn(_ i: Int) -> Bool {
        isDrums ? drumSteps[i].isOn : steps[i].isOn || steps[i].time == .tie
    }

    public var displayName: String {
        if isDrums { return presetName.isEmpty ? "Drums" : "Drums · \(presetName.capitalized)" }
        let e = engineName.capitalized
        return presetName.isEmpty ? e : "\(e) · \(presetName.capitalized)"
    }
}

public enum ConnectionStatus: Equatable, Sendable {
    case searching                         // no FM-1 found
    case connecting
    case connected(version: String)
    case wrongFirmware(found: String, protocolVersion: Int)
    case lost(String)
}

/// Follows a SLOOP device: reads all four tracks, keeps them in sync from pushes and a slow
/// background re-sync, and polls LIVE for the playhead.
@MainActor @Observable
public final class SloopSession {
    public private(set) var status: ConnectionStatus = .searching
    public private(set) var info: DeviceInfo?
    public private(set) var tracks = (0..<4).map(TrackState.init)
    public private(set) var selectedTrack = 0
    public private(set) var playing = false {
        // stopped (from the FM-1 or the iPad): the song order the iPad kept for now goes to the FM-1
        didSet { if oldValue, !playing, pendingOrder != nil { drainSettings() } }
    }
    /// The song: sections A–D, the mode, the position (LIVE), and the order (the settings object).
    public private(set) var song = SongState()
    public private(set) var songOrder: SongOrder?
    /// The tracks were edited from the iPad since the last section was stored or loaded: picking a
    /// section in loop mode would replace those edits (SLOOP keeps no copy there).
    public private(set) var tracksEdited = false
    /// The chain the iPad last asked for (LIVE reports its length and position, not its sections).
    public private(set) var chainAsked: [Int] = []
    /// Why the last song edit didn't take, for the Song page to say (nil: fine).
    public private(set) var songMessage: String?
    private var settingsCache: [UInt8]?
    @ObservationIgnored private var pendingOrder: SongOrder?
    @ObservationIgnored private var orderWriting = false
    @ObservationIgnored private var orderWriteBefore: SongOrder?
    /// The FM-1's HOME > AUDIO > USB AUDIO, from the settings object (nil until read): FULL sends a fixed
    /// level over USB whatever the MASTER, so the speaker can be muted while the iPad plays the sound.
    public private(set) var usbAudioFull: Bool?
    /// The iPad plays the FM-1's sound and wants its speaker quiet (AudioThrough, via the app).
    @ObservationIgnored private var speakerMuted = false
    @ObservationIgnored private var wantUSBFull = false
    /// A new song order the FM-1 will take once playback stops (SLOOP refuses one while anything plays).
    public private(set) var orderWaitingForStop = false

    /// Recording (a track is REC) or armed and waiting for a note: the REC pad lights.
    public private(set) var recording = false
    public private(set) var bpm = 120
    public private(set) var swing = 0
    public private(set) var otherChannelsPlaySelected = true
    public private(set) var drumMapGM = true
    public private(set) var positions = Array(repeating: LiveState.TrackPosition(step: 0, length: 16, meter: 0), count: 4)
    public private(set) var isDemo = false
    /// Counted on every poll, and no view reads it: kept out of observation so a poll doesn't count
    /// as a change.
    @ObservationIgnored public private(set) var stats = Stats()

    public struct Stats: Equatable, Sendable {
        public var polls = 0
        public var pushes = 0
        public var stepPushes = 0
        public var resyncFixes = 0         // steps a re-sync found out of date: a push that never came
        public var timeouts = 0
        public var connectedAt = Date()
        public var pollsPerSecond: Double { Double(polls) / max(1, Date().timeIntervalSince(connectedAt)) }
    }

    /// When each track's current step began (for interpolating the playhead between polls).
    /// (Not observed: the playheads read these inside their own animation timeline, so a poll needn't
    /// redraw them.)
    /// Called on anything that may change the project: an edit from the iPad, or a push about one made
    /// on the FM-1. Not observed: a knob drag would otherwise redraw whoever watched a counter.
    @ObservationIgnored public var onEdit: (@MainActor () -> Void)?
    /// A project being written: the settings writer waits, so the two never interleave their BK_PUTs.
    @ObservationIgnored private var projectBusy = false
    /// One backup operation at a time. SLOOP stages a restore in the buffer BK_LIST snapshots into, so a
    /// LIST between a BK_PUT begin and its commit drops what was staged (rc 5): that broke New project
    /// on the FM-1, when emptying sections made LIVE ask for the song order mid-write (2026-11-02).
    @ObservationIgnored private var backupHeld = false
    @ObservationIgnored private var backupWaiting: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var loopFingerprint: (raw: UInt32, music: UInt32)?
    @ObservationIgnored private var stepStart = Array(repeating: Date.distantPast, count: 4)
    @ObservationIgnored private var lastPoll = Date.distantPast

    private var client: SloopClient?
    private var tasks: [Task<Void, Never>] = []
    /// Factory preset names per engine (NAMES), all read at connect: the library's lists.
    public private(set) var namesCache: [Int: [String]] = [:]
    public private(set) var userPresets: [UserPreset] = []
    /// The drum track's kits (DESC of P_E0 while it is selected; empty until then).
    public private(set) var kitNames: [String] = []

    // Every parameter, for the Sound tab (step 4).
    /// The selected track's P_* values (DUMP), kept current from CHANGED pushes and the iPad's writes.
    public private(set) var params: [Int] = []
    public private(set) var globals: [Int] = []
    /// DESC of every parameter: label, range, format, enum names. The engine's P_E0..P_E7 are re-read
    /// whenever the selected track or its engine changes.
    public private(set) var trackDescs: [Int: ParamDesc] = [:]
    public private(set) var globalDescs: [Int: ParamDesc] = [:]
    /// fm1-ipad firmware (SLOOP 2.8.4 plus the UI push): the FM-1 reports its page and the iPad can set it.
    public private(set) var screenLinked = false
    /// What the FM-1's screen shows, when screenLinked.
    public private(set) var deviceScreen: UIState?
    /// The parameter last turned on the FM-1 itself (CHANGED), for the Sound tab to follow.
    public private(set) var lastTouched: (scope: Int, id: Int, at: Date)?

    private var pendingSteps: Set<Int> = []        // track * 64 + index
    /// Steps and parameters the iPad wrote lately. SLOOP doesn't push about the editor's own writes,
    /// and a read already queued before a write would bring back the old value, so reads leave these
    /// alone for a moment. Keys: "s<track*64+index>", "p<track>.<id>", "g<id>".
    private var recentWrites: [String: Date] = [:]
    private var stepWrites: [Int: SynthStep] = [:]
    @ObservationIgnored private var reloadingAll = false
    @ObservationIgnored private var reloadAgain = false
    private var stepSending: Set<Int> = []
    @ObservationIgnored private var drumWrites: [Int: DrumStep] = [:]
    @ObservationIgnored private var drumSending: Set<Int> = []
    private var paramWrites: [String: Int] = [:]      // latest value waiting to be sent (knob drags)
    private var paramSending: Set<String> = []
    private func recentlyWritten(_ key: String) -> Bool {
        guard let d = recentWrites[key] else { return false }
        return Date().timeIntervalSince(d) < 1.5
    }
    private let makeTransport: () -> SysExTransport?

    /// About 20 a second once a reply's 2 ms is added. SLOOP pushes only while its USB send ring is
    /// at most half full (editor.c ed_room), so polling harder can hold the pushes back.
    public var pollInterval: Duration = .milliseconds(48)
    /// While nothing plays.
    public var stoppedPollInterval: Duration = .milliseconds(120)
    /// The selected track is re-read this often: the device only edits the selected track, and a
    /// push it held back shows up here at the latest. Each pass also re-reads one other track.
    public var resyncInterval: Duration = .seconds(1)

    public init(demo: Bool = false) {
        isDemo = demo
        // -demo-still: the demo FM-1 makes no edits of its own (screen recordings, screenshots)
        let still = ProcessInfo.processInfo.arguments.contains("-demo-still")
        makeTransport = demo ? { FakeSloop(autoEdits: !still) } : { MIDITransport() }
    }

    public init(transport: @escaping () -> SysExTransport?) {
        makeTransport = transport
    }

    // MARK: Lifecycle

    /// Keeps looking for the device and reconnects after it goes away.
    public func run() async {
        while !Task.isCancelled {
            if let t = makeTransport() {
                await connect(t)
            } else if status != .searching, !(status.isLost) {
                status = .searching
            }
            if case .wrongFirmware = status {
                try? await Task.sleep(for: .seconds(3))
            } else {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func connect(_ transport: SysExTransport) async {
        let c = SloopClient(transport: transport)
        client = c
        settingsCache = nil; songOrder = nil; usbAudioFull = nil     // never write a settings object read from another FM-1
        await c.start()
        if case .wrongFirmware = status {} else { status = .connecting }
        do {
            try await Task.sleep(for: .milliseconds(200))      // let notes queued in the USB buffer drain
            let i = try await c.info()
            guard i.isSupported else {
                status = .wrongFirmware(found: i.version, protocolVersion: i.protocolVersion)
                await c.close()
                return
            }
            info = i
            deviceNotes = []          // whatever the USB buffer held from before isn't live
            try await readEverything()
            // fm1-ipad firmware answers UI; stock SLOOP doesn't (a short timeout, then the link stays off)
            if let s = try? await c.uiState() { deviceScreen = s; screenLinked = true } else { screenLinked = false }
            _ = try await c.watch(screenLinked ? 7 : 3)
            status = .connected(version: i.version.replacingOccurrences(of: "FELUCCA ", with: ""))
            stats = Stats()
        } catch {
            status = .lost("Lost the FM-1 while reading it")
            await c.close()
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.pushLoop(c) }
            group.addTask { await self.pingLoop(c) }
            group.addTask { await self.liveLoop(c) }
            group.addTask { await self.resyncLoop(c) }
            group.addTask { await self.noteLoop(transport); try? await Task.sleep(for: .seconds(86400 * 365)) }
            await group.next()           // any loop ending means the device went away
            group.cancelAll()
        }
        await c.close()
        client = nil
        if !Task.isCancelled { status = .lost("FM-1 disconnected") }
    }

    // MARK: Reading

    private func readEverything() async throws {
        try await readTrackList()
        for t in 0..<4 { try await readParams(t) }
        try await readGlobals()
        for t in 0..<4 { try await readSteps(t) }
        try await readLibrary()
        try await readSoundParams(descs: true)
        try? await readSongOrder()
    }

    // MARK: The song

    /// Runs `body` when no other backup operation is under way (the session is on the main actor, so
    /// the flag needs no lock of its own).
    private func backupTurn<T>(_ body: @MainActor () async throws -> T) async rethrows -> T {
        while backupHeld { await withCheckedContinuation { backupWaiting.append($0) } }
        backupHeld = true
        defer {
            backupHeld = false
            if !backupWaiting.isEmpty { backupWaiting.removeFirst().resume() }
        }
        return try await body()
    }

    public func readSongOrder() async throws {
        guard let c = client else { return }
        let s = try await backupTurn { try await c.settingsObject() }
        settingsCache = s
        songOrder = SongOrder(settings: s)
        usbAudioFull = Self.usbFull(in: s)
    }

    /// USB AUDIO = FULL: bit 11 of the settings' last word (persist_t.lights at byte 84, panel.c lights_word).
    static func usbFull(in s: [UInt8]) -> Bool? { s.count >= 88 ? s[85] & 0x08 != 0 : nil }

    // MARK: Projects (kept on the iPad; the FM-1 holds one at a time)

    public enum ProjectError: Error, Equatable {
        case notConnected, playing, unreadable(String), refused(object: Int, rc: Int)
    }

    /// What the FM-1 holds now, as a project. Reading doesn't need a stop.
    public func readProject() async throws -> ProjectData {
        try await backupTurn { try await readProjectNow() }
    }

    private func readProjectNow() async throws -> ProjectData {
        guard let c = client else { throw ProjectError.notConnected }
        var attempt = 0
        while true {
            do {
                let list = try await c.objectList()
                let working = try await c.object(id: 0, length: list[0]?.length ?? 0)
                var sections: [[UInt8]] = []
                for k in 0..<4 { sections.append(try await c.object(id: 2 + k, length: list[2 + k]?.length ?? 0)) }
                let settings = try await c.object(id: 1, length: list[1]?.length ?? 0)
                guard Fun6(working) != nil else { throw ProjectError.unreadable("the loop isn't a SLOOP 2.8 project") }
                guard settings.count >= SongOrder.offset + SongOrder.size else { throw ProjectError.unreadable("no song order") }
                return ProjectData(working: working, sections: sections,
                                   songOrder: Array(settings[SongOrder.offset..<(SongOrder.offset + SongOrder.size)]))
            } catch let e as ProjectError {
                throw e
            } catch {
                // the settings writer's LIST between ours and a GET drops the snapshot (rc 5): once more
                attempt += 1
                if attempt > 1 { throw error }
            }
        }
    }

    /// The fingerprint of what the FM-1 holds (ProjectData.fingerprint), cheaply: BK_LIST gives the
    /// sections' CRCs, the settings are one GET, and the loop is read again only when its snapshot changed.
    public func deviceFingerprint() async throws -> String {
        try await backupTurn { try await deviceFingerprintNow() }
    }

    private func deviceFingerprintNow() async throws -> String {
        guard let c = client else { throw ProjectError.notConnected }
        let list = try await c.objectList()
        var music: UInt32
        if let l = list[0], let known = loopFingerprint, known.raw == l.crc {
            music = known.music
        } else {
            let working = try await c.object(id: 0, length: list[0]?.length ?? 0)
            music = Fun6(working).map { CRC32.of($0.musicOnly) } ?? CRC32.of(working)
            if let l = list[0] { loopFingerprint = (l.crc, music) }
        }
        let sections = (2...5).map { (list[$0]?.length ?? 0) == 0 ? CRC32.of([]) : list[$0]!.crc }
        let settings = try await c.object(id: 1, length: list[1]?.length ?? 0)
        guard settings.count >= SongOrder.offset + SongOrder.size else { throw ProjectError.unreadable("no song order") }
        let order = CRC32.of(Array(settings[SongOrder.offset..<(SongOrder.offset + SongOrder.size)]))
        return ([music] + sections + [order]).map { String($0, radix: 16) }.joined(separator: "-")
    }

    /// Puts a project on the FM-1: the loop (loaded at once), sections A–D, then the song order spliced
    /// into the settings as they are now. SLOOP takes all of it only stopped. `progress` goes 0…1.
    public func writeProject(_ p: ProjectData, progress: @escaping @MainActor (Double) -> Void = { _ in }) async throws {
        guard client != nil else { throw ProjectError.notConnected }
        guard !playing, !song.songPlaying else { throw ProjectError.playing }
        guard p.loop != nil else { throw ProjectError.unreadable("not a SLOOP 2.8 project") }
        projectBusy = true
        defer { projectBusy = false; drainSettings() }
        pendingOrder = nil
        do {
            try await backupTurn { try await writeProjectNow(p, progress: progress) }
        } catch {
            await rereadAfterProject()          // part of it may be on the FM-1 now: show what is
            throw error
        }
        await rereadAfterProject()
    }

    /// A BK_PUT, once more if SLOOP lost what was staged (rc 5).
    /// A BK_PUT, again if SLOOP lost what was staged (rc 5), or briefly said "stop first" (rc 3) while
    /// the app knows it is stopped: loading a loop queues a stop (project_apply, transport_req) that the
    /// audio clears on its next block, and a commit before then is refused (2026-11-02, the FM-1).
    private func put(_ c: SloopClient, id: Int, _ bytes: [UInt8]) async throws -> Int {
        var rc = try await c.putObject(id: id, bytes)
        if rc == 5 { rc = try await c.putObject(id: id, bytes) }
        var tries = 0
        while rc == 3, !playing, tries < 10 {
            try await Task.sleep(for: .milliseconds(50))
            rc = try await c.putObject(id: id, bytes)
            tries += 1
        }
        return rc
    }

    /// The order matters: the song order and the sections first, the loop last, since only the loop
    /// queues a stop on the FM-1 (and with it, a moment of "stop first" for whatever comes next).
    private func writeProjectNow(_ p: ProjectData, progress: @escaping @MainActor (Double) -> Void) async throws {
        guard let c = client else { throw ProjectError.notConnected }
        guard let loop = p.loop?.sealed else { throw ProjectError.unreadable("not a SLOOP 2.8 project") }
        func check(_ id: Int, _ rc: Int) throws {
            if rc == 3 { throw ProjectError.playing }
            guard rc == 0 else { throw ProjectError.refused(object: id, rc: rc) }
        }
        progress(0)
        let fresh = try await c.settingsObject()
        guard fresh.count >= SongOrder.offset + SongOrder.size, p.songOrder.count == SongOrder.size else {
            throw ProjectError.unreadable("no song order")
        }
        var settings = fresh
        settings.replaceSubrange(SongOrder.offset..<(SongOrder.offset + SongOrder.size), with: p.songOrder)
        if settings != fresh { try check(1, try await put(c, id: 1, settings)) }
        settingsCache = settings
        songOrder = SongOrder(settings: settings)
        orderWriteBefore = nil
        for k in 0..<4 {
            progress(Double(1 + k) / 6)
            try check(2 + k, try await put(c, id: 2 + k, k < p.sections.count ? p.sections[k] : []))
        }
        progress(5.0 / 6)
        try check(0, try await put(c, id: 0, loop.bytes))
        progress(1)
    }

    private func rereadAfterProject() async {
        // SLOOP pushes nothing for the editor's own restore: read everything the app shows again
        try? await readTrackList()
        for t in 0..<4 { try? await readParams(t) }
        try? await readGlobals()
        for t in 0..<4 { _ = try? await readSteps(t, deviceWins: true) }
        try? await readSoundParams(descs: false)
        try? await readSongOrder()
        tracksEdited = false
    }

    // MARK: The FM-1's speaker while the iPad plays

    /// Quiets the FM-1's speaker (and its headphones) while the iPad plays its sound over USB, or gives
    /// the MASTER knob back. Quieting needs USB AUDIO = FULL first, or the iPad would go quiet too: the
    /// app writes that setting once (it's refused while the FM-1 plays, so it waits for a stop).
    /// Unplugged while quiet, the FM-1 stays quiet until its MASTER knob turns (SLOOP gives the knob back then).
    public func muteSpeaker(_ mute: Bool) {
        speakerMuted = mute
        guard let c = client else { return }
        if mute, usbAudioFull != true {
            wantUSBFull = true
            drainSettings()
            return
        }
        Task { _ = try? await c.masterLevel(mute ? 0 : 127) }
    }

    private let saveLayer = 7          // LIVE op 2's layer for SAVE held (ui_layers.c LY_SONG)

    /// Plays a section from the next bar (playing) or loads it as the loop (stopped), as SAVE + key 1–4.
    public func playSection(_ k: Int) {
        guard let c = client else { return }
        if song.songPlaying { songMessage = "The song is playing: stop it to pick a section"; return }
        if !song.stored(k) { songMessage = "Section \(Self.sectionName(k)) is empty: store a loop in it first"; return }
        songMessage = nil
        if playing { song.sectionQueued = k } else { song.sectionPlaying = k }
        Task {
            _ = try? await c.layerTap(layer: saveLayer, key: k)
            // stopped, the section loads at once: read what it put on the tracks (when playing, the
            // change of section in LIVE triggers the same on the bar)
            if !self.playing { self.tracksEdited = false; self.reloadAllTracks() }
        }
    }

    /// Stores the working loop into a section, as SAVE + key 5–8 (over a used one the FM-1 wants the key
    /// twice within 3 s: the iPad asks first, then sends both).
    /// Empties section k (the editor's restore of no bytes, project.c project_restore). SLOOP does it only
    /// stopped, and keeps no copy.
    public func clearSection(_ k: Int) {
        guard let c = client, (0..<4).contains(k) else { return }
        guard !playing else { songMessage = "Stop the FM-1 to clear a section"; return }
        songMessage = nil
        Task {
            let rc = await self.backupTurn { (try? await c.putObject(id: 2 + k, [])) ?? 99 }
            if rc == 0 {
                self.song.sectionsStored &= ~(1 << k)
                self.onEdit?()
            } else {
                self.songMessage = rc == 3 ? "Stop the FM-1 to clear a section" : "The FM-1 didn't clear section \(Self.sectionName(k)) (code \(rc))"
            }
        }
    }

    public func storeLoop(in k: Int) {
        guard let c = client else { return }
        let twice = song.stored(k)
        song.sectionsStored |= 1 << k
        tracksEdited = false
        onEdit?()
        songMessage = nil
        Task {
            _ = try? await c.layerTap(layer: saveLayer, key: 4 + k)
            if twice { _ = try? await c.layerTap(layer: saveLayer, key: 4 + k) }
            try? await self.readSongOrder()
        }
    }

    /// Loop mode / song mode (SAVE + key 13): in song mode PLAY plays the song order.
    public func toggleSongMode() {
        guard let c = client else { return }
        if song.songRecording { songMessage = "SONG REC is on"; return }
        song.songMode.toggle()
        Task { _ = try? await c.layerTap(layer: saveLayer, key: 12) }
    }

    /// SONG REC (SAVE + key 14): from the next bar, every section played (and how long) becomes the song.
    public func toggleSongRec() {
        guard let c = client else { return }
        if !song.songRecording && song.songPlaying { songMessage = "Stop the song first"; return }
        songMessage = nil
        let ending = song.songRecording
        song.songRecording.toggle()
        Task {
            _ = try? await c.layerTap(layer: saveLayer, key: 13)
            // ending it writes the order on the FM-1: read it back (the flag above already flipped, so
            // the LIVE check for "SONG REC just ended" won't see it)
            if ending { try? await self.readSongOrder() }
        }
    }

    /// A chain: the sections in turn, each for its pattern length, round and round. Only while playing.
    public func playChain(_ sections: [Int]) {
        guard let c = client else { return }
        guard playing else { songMessage = "Press play first: a chain starts on the next bar"; return }
        guard sections.allSatisfy(song.stored) else { songMessage = "A chain can only use stored sections"; return }
        songMessage = nil
        chainAsked = Array(sections.prefix(8))
        Task { _ = try? await c.chain(chainAsked) }
    }

    public func stopChain() {
        guard let c = client else { return }
        chainAsked = []
        Task { _ = try? await c.chain([]) }
    }

    /// Writes a new song order (only while the song is stopped, as on the device).
    /// Each write re-reads the settings object first and changes only the order's bytes, so settings
    /// changed on the FM-1 since connect are kept; one write runs at a time and the latest order wins.
    public func setSongOrder(_ order: SongOrder) {
        guard client != nil, songOrder != nil else { return }     // never over an order the app couldn't read
        if song.songPlaying || song.songRecording { songMessage = "Stop the song to change its order"; return }
        if orderWriteBefore == nil { orderWriteBefore = songOrder }
        songOrder = order
        songMessage = nil
        onEdit?()
        pendingOrder = order
        drainSettings()
    }

    /// The one writer of the settings object: the song order and USB AUDIO = FULL go through here, one
    /// write at a time, each on a fresh read so settings changed on the FM-1 since are kept.
    private func drainSettings() {
        guard let c = client, !orderWriting, !projectBusy else { return }
        orderWriting = true
        Task {
            while self.pendingOrder != nil || self.wantUSBFull {
                // SLOOP takes a new order only when stopped (settings_restore): it waits for the stop
                let order = self.playing ? nil : self.pendingOrder, full = self.wantUSBFull
                if order == nil, !full { break }
                if order != nil { self.pendingOrder = nil }
                self.wantUSBFull = false
                var rc = 99
                let written: [UInt8]? = await self.backupTurn {
                    guard let fresh = try? await c.settingsObject(), SongOrder(settings: fresh) != nil else { return nil }
                    var bytes = order.map { $0.written(into: fresh) } ?? fresh
                    if full, bytes.count >= 88 { bytes[85] |= 0x08 }
                    rc = bytes == fresh ? 0 : (try? await c.putSettings(bytes)) ?? 99
                    return bytes
                }
                if let bytes = written {
                    if rc == 0 {
                        self.settingsCache = bytes
                        self.usbAudioFull = Self.usbFull(in: bytes)
                    }
                }
                if let order, rc == 3 {
                    // still playing as far as the FM-1 knows: keep it for the next stop, don't roll back
                    if self.pendingOrder == nil { self.pendingOrder = order }
                    break
                }
                if order != nil, rc != 0, self.pendingOrder == nil {
                    self.songOrder = self.orderWriteBefore
                    self.songMessage = "The FM-1 didn't take the order (code \(rc))"
                }
                // FULL now: the speaker can go quiet without the iPad losing the sound
                if full, self.usbAudioFull == true, self.speakerMuted { _ = try? await c.masterLevel(0) }
            }
            self.orderWaitingForStop = self.pendingOrder != nil
            if self.pendingOrder == nil { self.orderWriteBefore = nil }
            self.orderWriting = false
        }
    }

    public static func sectionName(_ k: Int) -> String { ["A", "B", "C", "D"][k & 3] }

    private func readSoundParams(descs all: Bool) async throws {
        guard let c = client, let i = info else { return }
        if all {
            for id in 0..<i.paramCount where id < i.firstEngineParam { trackDescs[id] = try await c.desc(scope: 0, id: id) }
            for id in 0..<i.globalCount { globalDescs[id] = try await c.desc(scope: 1, id: id) }
        }
        for id in min(i.firstEngineParam, i.paramCount)..<i.paramCount { trackDescs[id] = try await c.desc(scope: 0, id: id) }
        let d = try await c.dump(paramCount: i.paramCount, globalCount: i.globalCount)
        let t = selectedTrack
        for (id, v) in d.track.enumerated() where !recentlyWritten("p\(t).\(id)") { apply(track: t, id: id, value: v) }
        if params.count != i.paramCount { params = Array(repeating: 0, count: i.paramCount) }
        for (id, v) in d.track.enumerated() where !recentlyWritten("p\(t).\(id)") { params[id] = v }
        if globals.count != i.globalCount { globals = Array(repeating: 0, count: i.globalCount) }
        for (id, v) in d.globals.enumerated() where !recentlyWritten("g\(id)") { globals[id] = v; applyGlobal(id: id, value: v) }
    }

    private func readLibrary() async throws {
        guard let c = client, let i = info else { return }
        for e in 0..<i.engines.count { _ = try await presetNames(e) }
        userPresets = try await c.userPresets()
        if selectedTrack == 3 { try await readKits() }
    }

    private func readKits() async throws {
        guard let c = client, let i = info, selectedTrack == 3 else { return }
        let d = try await c.desc(scope: 0, id: i.firstEngineParam)       // the drum track selected: the enum KIT
        if d.format == 8, !d.names.isEmpty {
            kitNames = d.names
            if tracks[3].preset < d.names.count { tracks[3].presetName = d.names[tracks[3].preset] }
        }
    }

    /// The library page asks for this: user presets may have changed on the device, and the kit names
    /// can only be read while the drum track is selected.
    public func refreshLibrary() {
        guard let c = client else { return }
        Task {
            if let u = try? await c.userPresets() { self.userPresets = u }
            if self.selectedTrack == 3, self.kitNames.isEmpty { try? await self.readKits() }
        }
    }

    private func readTrackList() async throws {
        guard let c = client, let i = info else { return }
        let list = try await c.tracks()
        if (0..<4).contains(list.selected) { selectedTrack = list.selected }
        for (k, s) in list.tracks.enumerated() where k < 4 {
            tracks[k].engine = s.engine
            if s.engine < i.engines.count { tracks[k].preset = s.preset }
            tracks[k].mute = s.mute
            if k < 3 { tracks[k].level = s.level }
            if s.engine < i.engines.count {
                tracks[k].engineName = i.engines[s.engine]
                let names = try await presetNames(s.engine)
                tracks[k].presetName = s.preset < names.count ? names[s.preset] : "Preset \(s.preset + 1)"
            } else {
                // the drum track's kit is its KIT parameter: TRACK's preset there is the last synth preset the
                // track held (editor.c ed_b(trk.preset)), and naming the kit from it made the name flicker
                tracks[k].engineName = "Drums"
                if let kit = try? await c.trackParam(track: k, id: i.firstEngineParam) {
                    tracks[k].preset = kit
                    // (the names come with the drum track selected: readKits; until then, the kit number only)
                    if kitNames.indices.contains(kit) { tracks[k].presetName = kitNames[kit] }
                }
            }
        }
    }

    private func presetNames(_ engine: Int) async throws -> [String] {
        if let n = namesCache[engine] { return n }
        guard let c = client else { return [] }
        let r = try await c.names(engine: engine)
        namesCache[engine] = r.names
        editPageTitles[engine] = r.pageTitles
        return r.names
    }

    /// Each engine's two edit-page titles (NAMES ends with them): what EDIT 1 and EDIT 2 are called.
    public private(set) var editPageTitles: [Int: [String]] = [:]

    private func readParams(_ t: Int) async throws {
        guard let c = client else { return }
        var ids = Param.all
        if t == 3, let i = info { ids.append(i.firstEngineParam) }      // the drum track's kit
        for id in ids {
            let v = try await c.trackParam(track: t, id: id)
            if !recentlyWritten("p\(t).\(id)") { apply(track: t, id: id, value: v) }
        }
    }

    private func readGlobals() async throws {
        guard let c = client else { return }
        for id in Global.all {
            let v = try await c.global(id: id)
            if !recentlyWritten("g\(id)") { applyGlobal(id: id, value: v) }
        }
    }

    /// Reads a track's 64 steps; returns how many differed from what the app had.
    @discardableResult
    /// `deviceWins`: after a section loaded over the tracks, the device's steps replace even ones the
    /// iPad just wrote.
    private func readSteps(_ t: Int, deviceWins: Bool = false) async throws -> Int {
        guard let c = client, (0..<4).contains(t) else { return 0 }
        var fixes = 0
        for i in 0..<64 {
            if t == 3 {
                let s = try await c.drumStep(index: i)
                if tracks[3].drumSteps[i] != s, deviceWins || !recentlyWritten("s\(3 * 64 + i)") { tracks[3].drumSteps[i] = s; fixes += 1 }
            } else {
                let s = try await c.synthStep(track: t, index: i)
                if tracks[t].steps[i] != s, deviceWins || !recentlyWritten("s\(t * 64 + i)") { tracks[t].steps[i] = s; fixes += 1 }
            }
        }
        if !tracks[t].loaded { tracks[t].loaded = true }
        return fixes
    }

    private func readStep(_ t: Int, _ i: Int) async {
        guard let c = client else { return }
        let key = t * 64 + i
        guard !pendingSteps.contains(key) else { return }
        pendingSteps.insert(key)
        defer { pendingSteps.remove(key) }
        do {
            if t == 3 {
                let s = try await c.drumStep(index: i)
                if !recentlyWritten("s\(key)"), tracks[3].drumSteps[i] != s { tracks[3].drumSteps[i] = s }
            } else {
                let s = try await c.synthStep(track: t, index: i)
                if !recentlyWritten("s\(key)"), tracks[t].steps[i] != s { tracks[t].steps[i] = s }
            }
        } catch { stats.timeouts += 1 }
    }

    // MARK: Applying values

    private func apply(track t: Int, id: Int, value v: Int) {
        guard t < 4 else { return }
        if t == selectedTrack, id < params.count { params[id] = v }
        if t == 3, id == info?.firstEngineParam {               // the drum track's kit
            tracks[3].preset = v
            if kitNames.indices.contains(v) { tracks[3].presetName = kitNames[v] }
            return
        }
        switch id {
        case Param.level: if t < 3 { tracks[t].level = v }
        case Param.root: tracks[t].root = max(0, min(11, v))
        case Param.scale: tracks[t].scale = max(0, min(Music.scales.count - 1, v))
        case Param.quant: tracks[t].quant = v
        case Param.transpose: tracks[t].transpose = v
        case Param.chord: tracks[t].chord = max(0, v)
        case Param.arpMode: tracks[t].arpMode = max(0, v)
        case Param.length: tracks[t].length = max(1, min(64, v))
        case Param.division: tracks[t].division = max(0, min(Music.divisionBeats.count - 1, v))
        case Param.pan: tracks[t].pan = v
        case Param.mute: tracks[t].mute = v != 0
        default: break
        }
    }

    private func applyGlobal(id: Int, value v: Int) {
        if id < globals.count { globals[id] = v }
        switch id {
        case Global.bpm: bpm = v
        case Global.swing: swing = v
        case Global.drumLevel: tracks[3].level = v
        case Global.otherChannels: otherChannelsPlaySelected = v == 0
        case Global.drumMap: drumMapGM = v == 0
        default: break
        }
    }

    // MARK: Loops

    private func pushLoop(_ c: SloopClient) async {
        for await p in c.pushes {
            stats.pushes += 1
            if case .ui = p {} else { onEdit?() }
            switch p {
            case .stepChanged(let i, let t):
                stats.stepPushes += 1
                guard (0..<4).contains(t), (0..<64).contains(i) else { break }
                Task { await self.readStep(t, i) }
            case .reload(_, _, let t):
                guard (0..<4).contains(t) else { break }
                selectedTrack = t
                Task {
                    if t == 3, self.kitNames.isEmpty { try? await self.readKits() }
                    try? await self.readSoundParams(descs: false)
                    try? await self.readTrackList()
                    try? await self.readParams(t)
                    _ = try? await self.readSteps(t)
                }
            case .changed(let scope, let id, let v):
                if scope == 0 { apply(track: selectedTrack, id: id, value: v) } else { applyGlobal(id: id, value: v) }
                lastTouched = (scope, id, Date())
            case .trackChanged(let t, let id, let v):
                apply(track: t, id: id, value: v)
            case .ui(let s):
                screenLinked = true
                if s != deviceScreen { deviceScreen = s }
            }
        }
    }

    private func pingLoop(_ c: SloopClient) async {
        var n = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            n += 1
            do {
                try await c.ping()
                if n % 10 == 0 { _ = try await c.watch(screenLinked ? 7 : 3) }   // watching ends on a USB reset: renew it
            } catch ClientError.closed { return } catch { stats.timeouts += 1 }
        }
    }

    private func liveLoop(_ c: SloopClient) async {
        var misses = 0
        while !Task.isCancelled {
            do {
                let l = try await c.live()
                misses = 0
                applyLive(l)
            } catch ClientError.closed {
                return
            } catch {
                misses += 1
                stats.timeouts += 1
                if misses > 40 { return }     // about 6 s with no answer: treat it as gone
            }
            // stopped, there is no playhead to keep smooth: a slower poll still catches a track switch or
            // PLAY quickly, with about half the traffic (2026-11-02, battery)
            try? await Task.sleep(for: playing ? pollInterval : stoppedPollInterval)
        }
    }

    private func resyncLoop(_ c: SloopClient) async {
        var pass = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: resyncInterval)
            do {
                let sel = selectedTrack
                stats.resyncFixes += try await readSteps(sel)
                if pass % 3 == 0 {                       // every third pass: the next other track, params, globals
                    let other = (sel + 1 + (pass / 3) % 3) % 4
                    if other == 0 { try await readTrackList(); try await readGlobals() }
                    try await readParams(sel)
                    try await readParams(other)
                    stats.resyncFixes += try await readSteps(other)
                }
            } catch ClientError.closed { return } catch { stats.timeouts += 1 }
            pass += 1
        }
    }

    /// Every track's steps and settings again, once (a call while one runs asks for one more pass).
    private func reloadAllTracks() {
        guard !reloadingAll else { reloadAgain = true; return }
        reloadingAll = true
        Task {
            repeat {
                reloadAgain = false
                for t in 0..<4 {
                    try? await self.readParams(t)
                    _ = try? await self.readSteps(t, deviceWins: true)
                }
            } while reloadAgain
            reloadingAll = false
        }
    }

    func applyLive(_ l: LiveState, at now: Date = Date()) {
        stats.polls += 1
        // About 20 a second: every write here is guarded, because writing an observed property (even
        // the same value, and any element of `tracks`) makes every view that reads it draw again; the
        // drum grid redrew its whole canvas on every poll (2026-11-02, battery)
        let wasPlaying = playing
        if l.selected != selectedTrack, l.selected < 4 { selectedTrack = l.selected }
        if playing != l.playing { playing = l.playing }
        let rec = l.recTracks != 0 || l.recArmed
        if recording != rec { recording = rec }
        let before = song
        if song != l.song { song = l.song }
        if l.song.chainLength == 0 { chainAsked = [] }
        // SONG REC just ended, or a section was stored on the device: the order may have changed
        if (before.songRecording && !l.song.songRecording) || before.sectionsStored != l.song.sectionsStored {
            onEdit?()
            Task { try? await self.readSongOrder() }
        }
        // a section loaded over the tracks, or the song stopped and SLOOP put the loop back: SLOOP only
        // pushes RELOAD for the selected track, so re-read all four (arranger_scene.c)
        let songStopped = before.songPlaying && !l.song.songPlaying
        if before.sectionPlaying != l.song.sectionPlaying || songStopped { reloadAllTracks() }
        if before.sectionPlaying != l.song.sectionPlaying, !l.song.songPlaying { tracksEdited = false }
        if bpm != l.bpm { bpm = l.bpm }
        // mutes from the device too (GLO + key on the FM-1), unless the iPad just set one
        for k in 0..<4 where !recentlyWritten("p\(k).\(Param.mute)") {
            let m = l.mutes >> k & 1 == 1
            if tracks[k].mute != m { tracks[k].mute = m }
        }
        for k in 0..<min(4, l.tracks.count) {
            let new = l.tracks[k], old = positions[k]
            if new.step != old.step || !wasPlaying {
                let dur = stepDuration(k)
                let predicted = stepStart[k].addingTimeInterval(dur)
                let advancedByOne = (old.step + 1) % max(old.length, 1) == new.step
                // The step changed somewhere between the last poll and now. Keep the phase we
                // predicted when it falls in that window; otherwise take the middle.
                if wasPlaying, advancedByOne, predicted > lastPoll, predicted <= now {
                    stepStart[k] = predicted
                } else {
                    stepStart[k] = lastPoll > now.addingTimeInterval(-0.25) ? lastPoll.addingTimeInterval(now.timeIntervalSince(lastPoll) / 2) : now
                }
            }
            if positions[k] != new { positions[k] = new }
            let len = max(1, min(64, new.length))
            if tracks[k].length != len { tracks[k].length = len }
        }
        lastPoll = now
    }

    /// Seconds per step for a track, from BPM and its division.
    public func stepDuration(_ t: Int) -> TimeInterval {
        let div = tracks[t].division
        let beats = Music.divisionBeats.indices.contains(div) ? Music.divisionBeats[div] : 0.25
        return 60.0 / Double(max(bpm, 20)) * beats
    }

    /// The playhead in steps (fractional) for a track at a moment, interpolated between polls.
    public func playhead(track t: Int, at date: Date, interpolate: Bool = true) -> Double {
        let p = positions[t]
        guard playing, interpolate else { return Double(p.step) }
        let frac = date.timeIntervalSince(stepStart[t]) / stepDuration(t)
        return Double(p.step) + min(max(frac, 0), 0.999)
    }

    // MARK: Actions from the iPad

    /// Selects a track on the FM-1. SLOOP doesn't push about the editor's own TRACK, so the app
    /// updates itself at once.
    public func select(track t: Int) {
        guard t != selectedTrack else { return }
        selectedTrack = t
        guard let c = client else { return }
        Task {
            _ = try? await c.selectTrack(t)
            if t == 3, self.kitNames.isEmpty { try? await self.readKits() }
            try? await self.readSoundParams(descs: false)
        }
    }

    // MARK: Playing from the iPad's keyboard

    /// The channel the keyboard plays on: 16, which no track owns by default, so SLOOP plays the
    /// selected track with it (GLO > MIDI > OTHER = SEL, seq.c midi_route), drums included.
    public static let keyboardChannel: UInt8 = 15
    private var held: [Int: Int] = [:]        // key id -> MIDI note sent, so a note-off matches its note-on
    /// The FM-1's OCT buttons (song.octave), which the protocol doesn't report. The iPad keeps its own
    /// and follows the FM-1: a note from the FM-1's keys that only fits another octave moves it there.
    public var keyboardOctave = 0

    /// What key k (0 = F3 ... 26 = G5, as on the FM-1) plays on the selected track, as the FM-1's own
    /// keyboard would; nil for a silent key (black keys in WHITE mode).
    public func pitch(ofKey k: Int, octave: Int? = nil) -> Int? {
        let t = tracks[selectedTrack]
        return Music.keyPitch(k, root: t.root, scale: t.scale, quant: t.quant, chord: t.chord,
                              transpose: t.transpose, octave: octave ?? keyboardOctave)
    }
    /// Notes held on the FM-1's own keys right now (MIDI notes it sends), to light the iPad's keys too.
    public private(set) var deviceNotes: Set<Int> = []

    /// The key id a note from the device lights: the note itself, or on the drum track its lane.
    public func keyID(forDeviceNote n: Int) -> Int {
        guard selectedTrack == 3 else { return n }
        if drumMapGM { return Music.laneNotes.firstIndex(of: n) ?? Music.laneNotes.enumerated().min { abs($0.element - n) < abs($1.element - n) }!.offset }
        return ((n - 36) % 16 + 16) % 16
    }

    private func noteLoop(_ t: SysExTransport) async {
        for await e in t.notes {
            let n = Int(e.note)
            if e.on { deviceNotes.insert(n); followOctave(n) } else { deviceNotes.remove(n) }
        }
    }

    /// A note from the FM-1 that no key plays at the iPad's octave, but one does at another: the FM-1's
    /// OCT buttons moved, so follow them (nearest octave first).
    private func followOctave(_ n: Int) {
        guard selectedTrack < 3 else { return }
        func fits(_ o: Int) -> Bool { (0..<27).contains { pitch(ofKey: $0, octave: o) == n } }
        guard !fits(keyboardOctave) else { return }
        for d in [1, -1, 2, -2, 3, -3] where fits(keyboardOctave + d) && abs(keyboardOctave + d) <= 3 {
            keyboardOctave += d
            return
        }
    }

    /// A key down. `key` is the FM-1 key index on a synth track (0...26), the lane (0...15) on drums.
    public func keyDown(_ key: Int, velocity: Int = 100) {
        let note: Int
        if selectedTrack == 3 { note = drumMapGM ? Music.laneNotes[key % 16] : 36 + key % 16 }
        else if let p = pitch(ofKey: key) { note = p } else { return }
        held[key] = note
        client?.sendMIDI([0x90 | Self.keyboardChannel, UInt8(note & 0x7F), UInt8(min(max(velocity, 1), 127))])
    }

    /// A piano-roll row: that exact note, held while touched (drum lanes go through keyDown).
    public func noteDown(_ note: Int) {
        held[1000 + note] = note
        client?.sendMIDI([0x90 | Self.keyboardChannel, UInt8(note & 0x7F), 100])
    }
    public func noteUp(_ note: Int) { keyUp(1000 + note) }

    public func keyUp(_ key: Int) {
        guard let note = held.removeValue(forKey: key) else { return }
        client?.sendMIDI([0x80 | Self.keyboardChannel, UInt8(note & 0x7F), 0])
    }

    /// The notes (or drum lanes) the selected track plays at the playhead, to light the keys.
    public var sounding: Set<Int> {
        guard playing else { return [] }
        let t = selectedTrack, i = positions[t].step % 64
        if t == 3 { return Set(tracks[3].drumSteps[i].lanes) }
        // a held note sounds through its TIE steps
        var k = i
        while k > 0, tracks[t].steps[k].time == .tie { k -= 1 }
        let s = tracks[t].steps[k]
        return s.time == .note ? Set(s.notes) : []
    }

    // MARK: Editing from the iPad (step 2). The app shows each change at once; the reply is what
    // the device stored, and it wins.

    public func write(track t: Int, index i: Int, _ step: SynthStep) {
        guard t < 3 else { return }
        var st = step
        if st.time != .note { st.notes = []; st.levels = []; st.ratchets = [] }
        tracks[t].steps[i] = st
        tracksEdited = true
        onEdit?()
        let key = t * 64 + i
        recentWrites["s\(key)"] = Date()
        // latest value wins, one write in flight per step: a dial turned fast sends what it passes
        // through without queueing, and a reply only lands if nothing newer is waiting (else an older
        // velocity would snap the dial back mid-turn)
        stepWrites[key] = st
        guard let c = client, !stepSending.contains(key) else { return }
        stepSending.insert(key)
        Task {
            while let next = self.stepWrites.removeValue(forKey: key) {
                do {
                    let stored = try await c.setSynthStep(track: t, index: i, next)
                    if self.stepWrites[key] == nil { self.tracks[t].steps[i] = stored }
                } catch { self.stats.timeouts += 1 }
                self.recentWrites["s\(key)"] = Date()
            }
            self.stepSending.remove(key)
        }
    }

    public func write(drumIndex i: Int, _ step: DrumStep) {
        tracks[3].drumSteps[i] = step
        tracksEdited = true
        onEdit?()
        recentWrites["s\(3 * 64 + i)"] = Date()
        // as synth steps: latest value wins, one write in flight, a reply lands only if nothing newer waits
        drumWrites[i] = step
        guard let c = client, !drumSending.contains(i) else { return }
        drumSending.insert(i)
        Task {
            while let next = self.drumWrites.removeValue(forKey: i) {
                do {
                    let stored = try await c.setDrumStep(index: i, next)
                    if self.drumWrites[i] == nil { self.tracks[3].drumSteps[i] = stored }
                } catch { self.stats.timeouts += 1 }
                self.recentWrites["s\(3 * 64 + i)"] = Date()
            }
            self.drumSending.remove(i)
        }
    }

    /// Sets how many steps the note on `start` lasts: the steps after it become TIEs (a tie holds the
    /// whole step, every note of a chord), or go back to empty when it gets shorter. Stops before the
    /// next step with notes of its own, so a drag never overwrites them.
    public func setLength(track t: Int, start: Int, steps want: Int) {
        guard t < 3, tracks[t].steps[start].time == .note else { return }
        var limit = 1
        while start + limit < 64, tracks[t].steps[start + limit].time != .note { limit += 1 }
        let len = max(1, min(want, limit))
        var cur = 1
        while start + cur < 64, tracks[t].steps[start + cur].time == .tie { cur += 1 }
        guard len != cur else { return }
        let tie = SynthStep(notes: [], time: .tie, accent: false, slide: false, velocity: tracks[t].steps[start].velocity)
        if len > cur {
            for i in (start + cur)..<(start + len) { write(track: t, index: i, tie) }
        } else {
            for i in (start + len)..<(start + cur) { write(track: t, index: i, .empty) }
        }
    }

    /// A note in a synth step on or off. Adding to a step that holds four replaces nothing and returns false.
    @discardableResult
    public func toggle(track t: Int, index i: Int, note: Int) -> Bool {
        var st = tracks[t].steps[i]
        if st.time == .note, let k = st.notes.firstIndex(of: note) {
            st.notes.remove(at: k)
            if k < st.levels.count { st.levels.remove(at: k) }
            if k < st.ratchets.count { st.ratchets.remove(at: k) }
            if st.notes.isEmpty { st.time = .rest }
        } else {
            if st.time != .note { st = SynthStep(notes: [], time: .note, accent: st.accent, slide: st.slide, velocity: st.velocity > 0 ? st.velocity : 100) }
            guard st.notes.count < 4 else { return false }
            st.notes.append(note); st.levels.append(0); st.ratchets.append(0)
        }
        write(track: t, index: i, st)
        return true
    }

    public func toggle(drumIndex i: Int, lane: Int) {
        let d = tracks[3].drumSteps[i]
        write(drumIndex: i, d.setting(lane, on: !d.has(lane)))
    }

    /// A track parameter from a knob: shown at once, sent latest-value-wins so a drag never queues up.
    public func set(track t: Int, param id: Int, to v: Int) {
        apply(track: t, id: id, value: v)
        if t == 3 && id == Param.level { sendParam("g\(Global.drumLevel)", v) { c, v in try await c.setGlobal(id: Global.drumLevel, value: v) } ; return }
        sendParam("p\(t).\(id)", v) { c, v in try await c.setTrackParam(track: t, id: id, value: v) }
    }

    public func set(global id: Int, to v: Int) {
        applyGlobal(id: id, value: v)
        sendParam("g\(id)", v) { c, v in try await c.setGlobal(id: id, value: v) }
    }

    private func sendParam(_ key: String, _ v: Int, _ op: @escaping (SloopClient, Int) async throws -> Int) {
        recentWrites[key] = Date()
        onEdit?()
        paramWrites[key] = v
        guard let c = client, !paramSending.contains(key) else { return }
        paramSending.insert(key)
        Task {
            while let next = self.paramWrites.removeValue(forKey: key) {
                _ = try? await op(c, next)
                self.recentWrites[key] = Date()
            }
            self.paramSending.remove(key)
        }
    }

    // MARK: The library (step 3)

    /// Loads a factory preset onto the selected synth track. SLOOP switches the engine if needed and
    /// keeps the pattern, mix and key; it pushes RELOAD, which re-reads the track.
    public func loadPreset(engine e: Int, index i: Int) {
        let t = selectedTrack
        guard t < 3, let info else { return }
        tracks[t].engine = e; tracks[t].preset = i
        tracks[t].engineName = info.engines[e]
        tracks[t].presetName = i < (namesCache[e]?.count ?? 0) ? namesCache[e]![i] : "Preset \(i + 1)"
        onEdit?()
        guard let c = client else { return }
        Task { _ = try? await c.preset(engine: e, index: i) }
    }

    public func loadUserPreset(_ p: UserPreset) {
        let t = selectedTrack
        guard t < 3, let info else { return }
        if p.engine < info.engines.count { tracks[t].engine = p.engine; tracks[t].engineName = info.engines[p.engine] }
        tracks[t].presetName = p.name
        onEdit?()
        guard let c = client else { return }
        Task { _ = try? await c.userLoad(slot: p.slot) }
    }

    /// What a clear took away, so the iPad can put it back (SLOOP's own undo covers device edits only).
    public struct ClearedTrack: Equatable, Sendable {
        public let track: Int
        let steps: [SynthStep]
        let drumSteps: [DrumStep]
    }

    /// Empties all 64 steps of a track (only the ones not already empty are written).
    @discardableResult
    public func clearAll(track t: Int) -> ClearedTrack {
        let before = ClearedTrack(track: t, steps: tracks[t].steps, drumSteps: tracks[t].drumSteps)
        for i in 0..<64 {
            if t == 3 { if tracks[3].drumSteps[i] != .empty { write(drumIndex: i, .empty) } }
            else if tracks[t].steps[i] != .empty { write(track: t, index: i, .empty) }
        }
        return before
    }

    /// Writes back whatever a clear took away (steps edited since are left as they are now).
    public func undo(_ c: ClearedTrack) {
        for i in 0..<64 {
            if c.track == 3 {
                if tracks[3].drumSteps[i] == .empty, c.drumSteps[i] != .empty { write(drumIndex: i, c.drumSteps[i]) }
            } else if tracks[c.track].steps[i] == .empty, c.steps[i] != .empty {
                write(track: c.track, index: i, c.steps[i])
            }
        }
    }

    /// Opens a page on the FM-1 (fm1-ipad firmware): its screen switches as if its button had been pressed.
    public func showOnDevice(page: Int) {
        guard screenLinked, let c = client else { return }
        deviceScreen = UIState(home: false, page: page)
        Task { if let s = try? await c.uiGoto(page: page) { self.deviceScreen = s } }
    }

    public func toggleMute(track t: Int) {
        set(track: t, param: Param.mute, to: tracks[t].mute ? 0 : 1)
    }

    public func loadKit(_ k: Int) {
        guard let i = info else { return }
        set(track: 3, param: i.firstEngineParam, to: k)
    }

    public func toggleRec() {
        guard let c = client else { return }
        Task { if let l = try? await c.rec() { self.applyLive(l) } }
    }

    public func setPlaying(_ on: Bool) {
        playing = on
        guard let c = client else { return }
        Task { if let l = try? await c.transport(play: on) { self.applyLive(l) } }
    }
}

extension ConnectionStatus {
    var isLost: Bool { if case .lost = self { true } else { false } }
}

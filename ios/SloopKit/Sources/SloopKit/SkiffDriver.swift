import Foundation

// Skiff 2.2 (github.com/illuminus5/skiff, web/EDITOR_PROTOCOL.md): the same FL frames as SLOOP, Felucca's
// command numbers. Six tracks, any of which plays any engine (T5 and T6 not PHYS or GRAIN); no drum track,
// a step's drum hits ride on every track. Parameter ids move between releases: P_COUNT and P_E0 come from
// INFO's wide-ids tag, ids from 128 go out as scope 2, and the ids the session follows are found by DESC.
// No step positions over SysEx (the playhead is counted from MIDI clock, SkiffPlayhead) and no screen link.

/// INFO's reply on Skiff: SLOOP's fields, then NTRK, CHAIN_ROWS and the tagged capability blocks.
public struct SkiffInfo: Equatable, Sendable {
    public static let expectedVersion = "FELUCCA v2.2"

    public var version: String
    public var engines: [String]
    public var paramCount: Int
    public var globalCount: Int
    public var stepCount: Int
    public var firstEngineParam: Int
    public var trackCount: Int
    /// Tag → its payload ("tag 01 payload" blocks).
    public var tags: [UInt8: [UInt8]] = [:]

    /// Payload bytes after "tag 01", per EDITOR_PROTOCOL.md's INFO row; an unknown tag ends the reading.
    static let tagLength: [UInt8: Int] = [0x55: 1, 0x4D: 2, 0x42: 1, 0x46: 2, 0x53: 1, 0x50: 1, 0x4E: 1, 0x52: 1, 0x4C: 1,
                                          0x54: 4, 0x43: 1, 0x4B: 1, 0x57: 1, 0x49: 4, 0x58: 1,
                                          0x56: 1]

    public init?(_ body: [UInt8]) {
        var r = ByteReader(body, cmd: Cmd.info)
        guard let v = try? r.string(), let n = try? r.u8(), let pc = try? r.u8(), let gc = try? r.u8(),
              let ns = try? r.u8(), let pe = try? r.u8() else { return nil }
        version = v; paramCount = pc; globalCount = gc; stepCount = ns; firstEngineParam = pe
        var names: [String] = []
        for _ in 0..<n { guard let s = try? r.string() else { return nil }; names.append(s) }
        engines = names
        trackCount = (try? r.u8()) ?? 1
        _ = try? r.u8()                                       // CHAIN_ROWS
        while r.remaining >= 2 {
            guard let tag = try? r.u8(), let one = try? r.u8(), one == 1, let len = Self.tagLength[UInt8(tag)],
                  r.remaining >= len else { break }
            tags[UInt8(tag)] = (0..<len).compactMap { _ in (try? r.u8()).map(UInt8.init) }
        }
        if let w = tags[0x49], w.count == 4 {                 // wide ids: the whole counts
            paramCount = Int(w[0]) | Int(w[1]) << 7
            firstEngineParam = Int(w[2]) | Int(w[3]) << 7
        }
    }

    /// TRANSPORT (57 bit 0) and the wide ids: what this driver relies on.
    public var isSupported: Bool { (tags[0x57]?.first ?? 0) & 1 != 0 && tags[0x49] != nil && trackCount >= 1 }
    /// Tracks that can't play some engines, and which (`54 01 tracks e0 e1 e2`).
    public var lightTracks: Int { Int(tags[0x54]?.first ?? 0) }
    public var lightEngines: Int {
        guard let t = tags[0x54], t.count == 4 else { return 0 }
        return Int(t[1]) | Int(t[2]) << 7 | Int(t[3]) << 14
    }
    /// A step's ties byte (57 bit 6) and FLAM / COND / NUDGE (43): how long a step is on the wire.
    public var hasTies: Bool { (tags[0x57]?.first ?? 0) & 0x40 != 0 }
    public var hasFlam: Bool { tags[0x43] != nil }
    /// Skiff 2.0's song (`58 01` bit 0): LIST2, NEW, COPY+, CHAIN, SONG ONCE; bit 1 the entries' sounds.
    public var hasSongLists: Bool { (tags[0x58]?.first ?? 0) & 1 != 0 }
    public var hasEntrySounds: Bool { (tags[0x58]?.first ?? 0) & 2 != 0 }
    /// Lupe's screen link patch on Skiff 2.2 (`56 01 02`, after `58 01`; `56 01 01` the first build, no cursor;
    /// fm1-ipad skiff/README.md): SCREEN (90), SCREEN_GOTO (91), WATCH bit 2. The version string stays FELUCCA v2.2: the tag is what tells it apart.
    public var hasScreenLink: Bool { (tags[0x56]?.first ?? 0) >= 1 }
    /// The second build (`56 01 02`): SCREEN carries the page's cursor, and SCREEN_GOTO can set it.
    public var hasScreenCursor: Bool { (tags[0x56]?.first ?? 0) >= 2 }
    /// The third (`56 01 03`): METER, each track's level as the MIXER draws it, pushed with WATCH bit 3.
    public var hasMeter: Bool { (tags[0x56]?.first ?? 0) >= 3 }

    public var deviceInfo: DeviceInfo {
        DeviceInfo(version: version, engines: engines, paramCount: paramCount, globalCount: globalCount, stepCount: stepCount,
                   firstEngineParam: firstEngineParam, trackCount: trackCount, protocolVersion: 0)
    }
}

/// Skiff's command numbers (Felucca's), where they differ from SLOOP's or SLOOP lacks them.
enum SkiffCmd {
    static let get: UInt8 = 2, set: UInt8 = 3, dump: UInt8 = 4, desc: UInt8 = 5, preset: UInt8 = 8, names: UInt8 = 10
    static let userList: UInt8 = 16, userLoad: UInt8 = 20, watch: UInt8 = 22, ping: UInt8 = 25
    static let track: UInt8 = 27, trackStep: UInt8 = 30, trackParam: UInt8 = 31
    static let transport: UInt8 = 76
    static let pool: UInt8 = 78, list2: UInt8 = 82
    static let menuDesc: UInt8 = 72, menuSet: UInt8 = 73
    static let screen: UInt8 = 90, screenGoto: UInt8 = 91
    static let motion: UInt8 = 64
}

/// A track's motion (MOTION 64): knob moves recorded per step while the track is armed, playing and selected,
/// from the FM-1's knobs and from SET / TRACK_PARAM alike (EDITOR_PROTOCOL.md "Motion"). Not pushed: polled.
public struct TrackMotion: Equatable, Sendable {
    public struct Event: Equatable, Sendable {
        public var step: Int, id: Int, value: Int
        /// false: recorded motion (automation); true: a step's lock.
        public var lock: Bool
        public init(step: Int, id: Int, value: Int, lock: Bool) { self.step = step; self.id = id; self.value = value; self.lock = lock }
    }
    public var on: Bool
    public var events: [Event]
    public init(on: Bool = false, events: [Event] = []) { self.on = on; self.events = events }
    /// The steps that carry recorded motion.
    public var steps: Set<Int> { Set(events.filter { !$0.lock }.map(\.step)) }
    public var recorded: Int { events.filter { !$0.lock }.count }

    public enum Source: Equatable, Sendable { case lock, recorded, sound }
    /// What parameter `id` sounds at `step` (motion.c motion_step / motion_unlock): a lock on that step; else the
    /// latest recorded change at a step up to it in this pass (each pass starts from the sound, motion_restore);
    /// else the sound's own value, `base`.
    public func value(of id: Int, at step: Int, base: Int) -> (value: Int, source: Source) {
        if let l = events.first(where: { $0.lock && $0.id == id && $0.step == step }) { return (l.value, .lock) }
        if let e = events.filter({ !$0.lock && $0.id == id && $0.step <= step }).max(by: { $0.step < $1.step }) {
            return (e.value, .recorded)
        }
        return (base, .sound)
    }
    /// The parameters with a record, in order of their first step.
    public var ids: [Int] {
        var seen: [Int] = []
        for e in events.sorted(by: { $0.step < $1.step }) where !seen.contains(e.id) { seen.append(e.id) }
        return seen
    }
    /// The record of `id` on `step`, of either kind.
    public func record(_ id: Int, at step: Int) -> Event? { events.first { $0.id == id && $0.step == step } }
}

/// MOTION's codes (motion.c motion_put): 0 done, 1 invalid (not a motion parameter, out of range), 2 all 64 used.
public enum MotionRC: Int, Sendable { case done = 0, invalid = 1, full = 2, songPlaying = 3 }

/// Which parameters Skiff records as motion (motion.c motion_param, Skiff 2.2's ids from core.h): LEVEL, ENV and its
/// routes, the LFO and its routes (0–16), GATE (32), the FX sends (33–36), GLIDE, PAN, DETUNE, the FM operators
/// (61–80), and from the DRUM lanes (83) up all but DIR, the duck's source, LFO SYNC TRIG POLARITY, ENV SYNC and the
/// chord follow. Any other id is refused (rc 1): never offered as a lane.
public enum SkiffMotion {
    public static func recordable(_ id: Int) -> Bool {
        guard (0..<146).contains(id) else { return false }
        if id <= 16 || id == 32 || (33...36).contains(id) || [38, 39, 44].contains(id) || (61...80).contains(id) { return true }
        return id >= 83 && id != 91 && id != 92 && !(117...119).contains(id) && id != 126 && !(135...137).contains(id)
    }
}

/// MENU settings the editor protocol can set (editor_menu.c ED_MENU's ids, append-only).
public enum SkiffMenu {
    /// MENU > USB LEVEL: 0 MASTER (USB audio follows the MASTER knob), 1 FIXED (USB at the full level, MASTER
    /// after it: the speaker can go down while the iPad keeps the sound). fx.c fx_usb_fixed.
    public static let usbLevel = 10
}

public final class SkiffDriver: FirmwareDriver, @unchecked Sendable {
    public let client: SloopClient
    public let skiff: SkiffInfo
    public let info: DeviceInfo
    public var dialect: FirmwareDialect { .skiff }
    public let shape: DeviceShape
    public var capabilities: FirmwareCapabilities { [.userPresets, .recording] }
    public let pushes: AsyncStream<Push>
    private let pushSink: AsyncStream<Push>.Continuation
    private var pushTask: Task<Void, Never>?

    // Set once in prepare(), before the session reads anything; read-only after.
    public private(set) var params = ParamIDs()
    public private(set) var pageLayout: [PageSpec]?
    /// DESC of every track parameter below P_E0 and every global, read once (the engine's are re-read).
    private var descCache: [Int: ParamDesc] = [:]          // key: scope * 1000 + id

    public init(client: SloopClient, body: [UInt8]) throws {
        guard let s = SkiffInfo(body) else { throw DecodeError.unexpected("Skiff INFO") }
        self.client = client
        skiff = s
        info = s.deviceInfo
        shape = DeviceShape(trackCount: s.trackCount, stepCount: s.stepCount, drumTrack: nil,
                            lightTracks: s.lightTracks, lightEngines: s.lightEngines, trackColours: DeviceShape.skiffColours)
        (pushes, pushSink) = AsyncStream.makeStream(of: Push.self, bufferingPolicy: .bufferingNewest(256))
        let source = client.pushes, sink = pushSink
        pushTask = Task {
            for await p in source { if let q = Self.normalize(p) { sink.yield(q) } }
            sink.finish()
        }
    }

    deinit { pushTask?.cancel() }

    // MARK: The wire

    func request(_ cmd: UInt8, _ args: [UInt8], match: Int, _ name: String,
                         timeout: Duration = .milliseconds(300), retries: Int = 1) async throws -> [UInt8] {
        try await client.send(.raw(cmd: cmd, args: args, match: match, name: name), timeout: timeout, retries: retries)
    }

    /// A track parameter's (scope, id) on the wire: ids from 128 are scope 2, id − 128.
    static func wire(_ id: Int) -> [UInt8] { id < 128 ? [0, UInt8(id)] : [2, UInt8(id - 128)] }
    /// TRACK_PARAM's first two bytes: the id's bit 7 rides in bit 6 of the track byte.
    static func trackID(_ t: Int, _ id: Int) -> [UInt8] { [UInt8(t | (id >> 7 & 1) << 6), UInt8(id & 127)] }

    /// Pushes in the session's terms: scope 2 is a track parameter from 128, TRACK_CHANGED's bit 6 the id's bit 7.
    static func normalize(_ p: Push) -> Push? {
        switch p {
        case .changed(2, let id, let v): return .changed(scope: 0, id: id + 128, value: v)
        case .trackChanged(let t, let id, let v): return .trackChanged(track: t & 0x3F, id: id | (t >> 6 & 1) << 7, value: v)
        default: return p
        }
    }

    // MARK: Steps

    /// A step from TRACK_STEP's bytes after `track, index`: SLOOP's first eight, then Skiff's own, kept whole.
    static func decodeStep(_ b: ArraySlice<UInt8>) throws -> SynthStep {
        let a = Array(b)
        guard a.count >= 8 else { throw DecodeError.short(cmd: SkiffCmd.trackStep) }
        let n = min(Int(a[0]), 4)
        var s = SynthStep(notes: a[1...4].prefix(n).map(Int.init), time: StepTime(rawValue: Int(a[5])) ?? .rest,
                          accent: a[6] & 1 != 0, slide: a[6] & 2 != 0, velocity: Int(a[7]))
        s.extra = Array(a[8...])
        // hits (3), chance, then the ratchet 1..4 for the whole step: shown as each note's
        if s.extra.count >= 5, (1...4).contains(s.extra[4]) { s.ratchets = Array(repeating: Int(s.extra[4]) - 1, count: n) }
        return s
    }

    /// TRACK_STEP's step bytes: the eight SLOOP has; then, when the step came from the device, its own
    /// hits, chance, FLAM, COND, NUDGE and ties back as they were, with the ratchet from the first note.
    /// A step made on the iPad sends eight bytes, and the device keeps whatever else the step had.
    static func encodeStep(_ s: SynthStep) -> [UInt8] {
        let n = min(s.notes.count, 4)
        var b: [UInt8] = [UInt8(n)] + (0..<4).map { $0 < n ? UInt8(s.notes[$0] & 0x7F) : 0 }
        // velocity 0 is Skiff's "as designed" (it plays 96): an empty step holds it
        b += [UInt8(s.time.rawValue), UInt8((s.accent ? 1 : 0) | (s.slide ? 2 : 0)), UInt8(min(max(s.velocity, 0), 127))]
        if s.extra.count >= 3, s.extra.count < 5 { return b + s.extra.prefix(3) }     // hits only: the rest kept
        guard s.extra.count >= 5 else { return b }
        var x = s.extra
        x[4] = UInt8(min(max((s.ratchets.first ?? Int(x[4]) - 1) + 1, 1), 4))
        if x[3] > 100 { x[3] = 100 }                          // a chance above 100 gets no reply
        return b + x
    }

    // MARK: FirmwareDriver

    public func prepare() async throws {
        for id in 0..<info.firstEngineParam { descCache[id] = try await readDesc(scope: 0, id: id) }
        for id in 0..<info.globalCount { descCache[1000 + id] = try await readDesc(scope: 1, id: id) }
        let track = (0..<info.firstEngineParam).compactMap { descCache[$0] }
        let globals = (0..<info.globalCount).compactMap { descCache[1000 + $0] }
        params = Self.findIDs(track: track, globals: globals)
        pageLayout = SkiffPages.build(track: track, globals: globals, firstEngineParam: info.firstEngineParam)
    }

    /// The ids by DESC label, falling back to Felucca's numbers where a label isn't found.
    static func findIDs(track: [ParamDesc], globals: [ParamDesc]) -> ParamIDs {
        func first(_ label: String, in ds: [ParamDesc], after: Int = -1) -> Int? { ds.first { $0.label == label && $0.id > after }?.id }
        var p = ParamIDs()
        p.level = first("LEVEL", in: track) ?? p.level
        p.root = first("ROOT", in: track) ?? p.root
        p.scale = first("SCALE", in: track) ?? p.scale
        p.quant = first("QUANTIZE", in: track) ?? p.quant
        p.transpose = first("TRANSP", in: track) ?? p.transpose
        p.length = first("LENGTH", in: track) ?? p.length
        p.division = first("DIV", in: track) ?? p.division
        p.pan = first("PAN", in: track) ?? p.pan
        p.mute = first("MUTE", in: track) ?? p.mute
        p.chord = first("CHORD", in: track) ?? 81
        p.arpMode = first("MODE", in: track) ?? p.arpMode              // ARP's MODE comes first
        p.direction = first("DIR", in: track)
        p.swing = first("SWING", in: track, after: p.length)           // the PATTERN page's, after ARP's
        p.insertType = nil; p.envSync = nil                            // SLOOP's screen rules: not Skiff's
        p.bpm = first("BPM", in: globals) ?? 0
        p.globalSwing = first("SWING+", in: globals) ?? 1
        p.drumLevel = nil; p.otherChannels = nil; p.drumMap = nil
        return p
    }

    private func readDesc(scope: Int, id: Int) async throws -> ParamDesc {
        let a: [UInt8] = scope == 0 ? Self.wire(id) : [UInt8(scope), UInt8(id)]
        var d = try ParamDesc(await request(SkiffCmd.desc, a, match: 2, "DESC"))
        if scope == 0 { d.scope = 0; d.id = id }
        return d
    }

    public func close() async {
        pushTask?.cancel()
        await client.close()
        pushSink.finish()
    }
    public func sendMIDI(_ bytes: [UInt8]) { client.sendMIDI(bytes) }

    public func tracks() async throws -> TrackList { try TrackList(await request(SkiffCmd.track, [], match: 0, "TRACK")) }
    public func selectTrack(_ t: Int) async throws -> TrackList {
        try TrackList(await request(SkiffCmd.track, [UInt8(t)], match: 0, "TRACK"))
    }
    public func names(engine: Int) async throws -> PresetNames {
        try PresetNames(await request(SkiffCmd.names, [UInt8(engine)], match: 1, "NAMES"))
    }
    public func synthStep(track: Int, index: Int) async throws -> SynthStep {
        let b = try await request(SkiffCmd.trackStep, [UInt8(track), UInt8(index)], match: 2, "TRACK_STEP")
        return try Self.decodeStep(b.dropFirst(2))
    }
    public func setSynthStep(track: Int, index: Int, _ step: SynthStep) async throws -> SynthStep {
        let b = try await request(SkiffCmd.trackStep, [UInt8(track), UInt8(index)] + Self.encodeStep(step), match: 2, "TRACK_STEP set")
        return try Self.decodeStep(b.dropFirst(2))
    }
    public func drumStep(index: Int) async throws -> DrumStep { throw DecodeError.unexpected("Skiff has no drum track") }
    public func setDrumStep(index: Int, _ step: DrumStep) async throws -> DrumStep { throw DecodeError.unexpected("Skiff has no drum track") }

    public func trackParam(track: Int, id: Int) async throws -> Int {
        let b = try await request(SkiffCmd.trackParam, Self.trackID(track, id), match: 2, "TRACK_PARAM")
        return try ParamValue(b, cmd: SkiffCmd.trackParam).value
    }
    public func setTrackParam(track: Int, id: Int, value: Int) async throws -> Int {
        let b = try await request(SkiffCmd.trackParam, Self.trackID(track, id) + Frame.v14(value), match: 2, "TRACK_PARAM set")
        return try ParamValue(b, cmd: SkiffCmd.trackParam).value
    }
    public func global(id: Int) async throws -> Int {
        try ParamValue(await request(SkiffCmd.get, [1, UInt8(id)], match: 2, "GET"), cmd: SkiffCmd.get).value
    }
    public func setGlobal(id: Int, value: Int) async throws -> Int {
        try ParamValue(await request(SkiffCmd.set, [1, UInt8(id)] + Frame.v14(value), match: 2, "SET"), cmd: SkiffCmd.set).value
    }
    public func desc(scope: Int, id: Int) async throws -> ParamDesc {
        if scope == 0, id < info.firstEngineParam, let d = descCache[id] { return d }
        if scope == 1, let d = descCache[1000 + id] { return d }
        return try await readDesc(scope: scope, id: id)
    }
    public func dump() async throws -> ParamDump {
        try ParamDump(await request(SkiffCmd.dump, [], match: 0, "DUMP"), paramCount: info.paramCount, globalCount: info.globalCount)
    }
    /// WATCH 3: the pushes and TRACK_CHANGED. Skiff has no screen link.
    /// WATCH: steps and parameters (bits 0, 1), and with the screen link patch the screen too (bit 2).
    public func watch(screenLink: Bool) async throws {
        let bits = (screenLink && skiff.hasScreenLink ? 7 : 3) | (screenLink && skiff.hasMeter ? 8 : 0)
        _ = try await request(SkiffCmd.watch, [UInt8(bits)], match: 0, "WATCH")
    }

    /// SCREEN (90, the screen link patch): home, page (Skiff's PAGES), layer, menu, the selected track, flags, and
    /// on `56 01 02` the page's two cursors.
    public func screen() async throws -> UIState {
        try UIState(await request(SkiffCmd.screen, [], match: 0, "SCREEN"))
    }

    /// SCREEN_GOTO (91): a page of Skiff's PAGES, or 127 for HOME, and on `56 01 02` the page's cursor (clamped
    /// to its range). Always answered: a request refused (past the table, a page the track's engine doesn't show,
    /// a dialog open, a cursor for a page with none) answers the state unchanged.
    public func screenGoto(_ page: Int, cursor: Int? = nil) async throws -> UIState {
        var a = [UInt8(page & 127)]
        if let cursor, skiff.hasScreenCursor { a.append(UInt8(max(0, min(126, cursor)))) }
        return try UIState(await request(SkiffCmd.screenGoto, a, match: 0, "SCREEN_GOTO", retries: 0))
    }
    /// PERFORM's state (80, no args): op, rc, LAUNCH (0 LOOP, 1 BAR, 2 BEAT, 3 NOW), … Only LAUNCH is read.
    public func launchMode() async throws -> SongPlayback.Launch {
        let r = try await request(80, [], match: 0, "PERFORM")
        guard r.count >= 3 else { throw DecodeError.short(cmd: 80) }
        return SongPlayback.Launch(rawValue: Int(r[2])) ?? .loop
    }
    /// TRANSPORT is Skiff's keep-alive (EDITOR_PROTOCOL.md: "instead of PING").
    public func ping() async throws { _ = try await transportState() }
    public func preset(engine: Int, index: Int) async throws -> (engine: Int, preset: Int) {
        let b = try await request(SkiffCmd.preset, [UInt8(engine), UInt8(index)], match: 0, "PRESET")
        return (Int(b.first ?? 0), Int(b.count > 1 ? b[1] : 0))
    }
    public func userPresets() async throws -> [UserPreset] {
        var all: [UserPreset] = [], start = 0
        while true {
            let l = try UserPresetList(await request(SkiffCmd.userList, [UInt8(start), 16], match: 1, "UP_LIST"))
            all += l.used
            start += 16
            if start >= l.total { break }
        }
        return all
    }
    public func userLoad(slot: Int) async throws -> Int {
        let b = try await request(SkiffCmd.userLoad, [UInt8(slot)], match: 1, "UP_LOAD")
        return Int(b.count > 1 ? b[1] : 1)
    }
    public func transport(play: Bool) async throws -> LiveState? {
        _ = try await request(SkiffCmd.transport, [play ? 1 : 2], match: 0, "TRANSPORT", retries: 0)
        return nil
    }
    /// TRANSPORT's state: rc, playing, counting in, the request the audio has yet to take, armed tracks,
    /// selected. A PLAY or STOP still pending counts as done (the reply comes before the audio takes it).
    public func transportState() async throws -> TransportState? {
        let b = try await request(SkiffCmd.transport, [], match: 0, "TRANSPORT", timeout: .milliseconds(200))
        guard b.count >= 6 else { throw DecodeError.short(cmd: SkiffCmd.transport) }
        let pending = b[3]
        let playing = pending == 1 || pending == 3 ? true : pending == 2 ? false : b[1] != 0
        return TransportState(playing: playing, countingIn: b[2] != 0, armedTracks: Int(b[4]), selected: Int(b[5]))
    }

    /// REC, as the FM-1's button (TRANSPORT op 4). Sent once: it toggles.
    public func rec() async throws { _ = try await request(SkiffCmd.transport, [4], match: 0, "TRANSPORT REC", retries: 0) }

    // MARK: Motion (MOTION 64)

    /// MOTION op 7 (the query with the kinds): track, rc, on, count, max, count × (step, id, v14), count × kind.
    /// A step byte's bit 6 is the id's bit 7.
    public func motion(track t: Int) async throws -> TrackMotion {
        let b = try await request(SkiffCmd.motion, [UInt8(t), 7], match: 1, "MOTION")
        return try Self.parseMotion(b)
    }

    /// MOTION op 3 (a recorded change) or 5 (a lock, this step only) on `step` for `id`: a new record, or the one
    /// there becomes this. The track's records after it, with their kinds.
    public func setMotion(track t: Int, step: Int, id: Int, value: Int, lock: Bool) async throws -> (rc: MotionRC, motion: TrackMotion) {
        let b = try await request(SkiffCmd.motion, [UInt8(t), lock ? 5 : 3, UInt8(step & 63 | (id >> 7 & 1) << 6), UInt8(id & 127)] + Frame.v14(value),
                                  match: 1, "MOTION set", retries: 0)
        let m = try Self.parseMotion(b)
        if lock { return (MotionRC(rawValue: Int(b[1])) ?? .invalid, m) }
        // op 3 replies without the kinds: read them again
        return (MotionRC(rawValue: Int(b[1])) ?? .invalid, try await motion(track: t))
    }

    /// MOTION op 4: the record of `id` on `step` gone (either kind).
    public func deleteMotion(track t: Int, step: Int, id: Int) async throws -> TrackMotion {
        _ = try await request(SkiffCmd.motion, [UInt8(t), 4, UInt8(step & 63 | (id >> 7 & 1) << 6), UInt8(id & 127)],
                              match: 1, "MOTION delete", retries: 0)
        return try await motion(track: t)
    }

    /// MOTION op 6: the locks on `step` gone (127: on every step); its recorded changes stay.
    public func clearLocks(track t: Int, step: Int) async throws -> TrackMotion {
        let b = try await request(SkiffCmd.motion, [UInt8(t), 6, UInt8(step)], match: 1, "MOTION clear locks", retries: 0)
        return try Self.parseMotion(b)
    }

    static func parseMotion(_ b: [UInt8]) throws -> TrackMotion {
        guard b.count >= 5 else { throw DecodeError.short(cmd: SkiffCmd.motion) }
        var r = ByteReader(Array(b[2...]), cmd: SkiffCmd.motion)
        let on = try r.u8() != 0, n = try r.u8()
        _ = try r.u8()                                         // max (64)
        var events: [TrackMotion.Event] = []
        for _ in 0..<n {
            let s = try r.u8(), id = try r.u8(), v = try r.v14()
            events.append(.init(step: s & 63, id: id | (s >> 6 & 1) << 7, value: v, lock: false))
        }
        for k in 0..<n where r.remaining > 0 { events[k].lock = try r.u8() == 1 }
        return TrackMotion(on: on, events: events)
    }

    /// MOTION op 2: the track's motion dropped and off (on the FM-1, SAVE held undoes it). Skiff answers rc 0.
    @discardableResult
    public func clearMotion(track t: Int) async throws -> Int {
        let b = try await request(SkiffCmd.motion, [UInt8(t), 2], match: 1, "MOTION clear", retries: 0)
        guard b.count >= 2 else { throw DecodeError.short(cmd: SkiffCmd.motion) }
        return Int(b[1])
    }

    // MARK: MENU settings (editor_menu.c)

    /// A MENU setting's value, by its id: MENU_DESC walks the list (index → index, id, kind, value v14, …;
    /// id 127: the list has ended). nil when this firmware doesn't offer it.
    public func menuValue(id: Int) async throws -> Int? {
        for i in 0..<64 {
            let b = try await request(SkiffCmd.menuDesc, [UInt8(i)], match: 1, "MENU_DESC")
            guard b.count >= 2, b[1] != 127 else { return nil }
            if Int(b[1]) == id {
                guard b.count >= 5 else { throw DecodeError.short(cmd: SkiffCmd.menuDesc) }
                var r = ByteReader(Array(b[3...]), cmd: SkiffCmd.menuDesc)
                return try r.v14()
            }
        }
        return nil
    }

    /// MENU_SET: id, value → rc (0 applied and saved, 1 no such setting, 3 applied but not saved, 4 queued
    /// until STOP), id, the value the device took.
    public func setMenu(id: Int, value: Int) async throws -> (rc: Int, value: Int) {
        let b = try await request(SkiffCmd.menuSet, [UInt8(id)] + Frame.v14(value), match: 0, "MENU_SET", retries: 0)
        guard b.count >= 4 else { throw DecodeError.short(cmd: SkiffCmd.menuSet) }
        var r = ByteReader(Array(b[2...]), cmd: SkiffCmd.menuSet)
        return (Int(b[0]), try r.v14())
    }

    // MARK: The song: lists and the pattern pool (SkiffSong.swift)

    /// The lists, as they are (LIST2 with no arguments).
    public func songLists() async throws -> SkiffSong {
        let b = try await request(SkiffCmd.list2, [], match: 0, "LIST2", timeout: .milliseconds(400))
        guard b.count >= 3 else { throw DecodeError.short(cmd: SkiffCmd.list2) }
        return try SkiffSong(b[2...], tracks: shape.trackCount, sounds: skiff.hasEntrySounds)
    }

    /// One change, then the lists after it. Sent once: a change that timed out is never resent (a COPY sent
    /// twice copies twice); read the lists again instead.
    public func list(_ op: ListOp) async throws -> (rc: SongRC, song: SkiffSong) {
        let a = op.bytes
        let b = try await request(SkiffCmd.list2, a, match: 1, "LIST2 op \(a[0])", timeout: .milliseconds(1500), retries: 0)
        guard b.count >= 3 else { throw DecodeError.short(cmd: SkiffCmd.list2) }
        return (SongRC(rawValue: Int(b[1])) ?? .failed, try SkiffSong(b[2...], tracks: shape.trackCount, sounds: skiff.hasEntrySounds))
    }

    /// The pool: every pattern's LEN and uses.
    public func pool() async throws -> PatternPool {
        let b = try await request(SkiffCmd.pool, [], match: 0, "POOL", timeout: .milliseconds(400))
        guard b.count >= 2 else { throw DecodeError.short(cmd: SkiffCmd.pool) }
        return try PatternPool(b[2...])
    }

    /// CLEAR UNUSED (POOL op 3): every pattern nothing uses, stopped only. Can't be undone.
    public func clearUnusedPatterns() async throws -> (rc: SongRC, pool: PatternPool) {
        let b = try await request(SkiffCmd.pool, [3], match: 1, "POOL CLEAR UNUSED", timeout: .milliseconds(3000), retries: 0)
        guard b.count >= 2 else { throw DecodeError.short(cmd: SkiffCmd.pool) }
        // POOL's codes: 0 done, 1 nothing to clear, 2 in use, 3 playing, 4 failed
        let rc: SongRC = switch b[1] { case 0: .done; case 1: .empty; case 3: .playing; default: .failed }
        return (rc, try PatternPool(b[2...]))
    }
}

/// The Sound tab's pages on Skiff: Skiff's own page layout (firmware params.c PAGES, 2.2), each knob found
/// by its DESC label, the first parameter with that label after the knob before it (or, for a page's
/// first knob, its `n`th). Ids that move between releases leave the pages right; a label that is gone
/// leaves its knob empty, and a page with none left is dropped.
public enum SkiffPages {
    struct Spec {
        let title: String, family: String, scope: Int
        let labels: [String?]
        var nth = 1
    }

    /// In Skiff's PAGES order (params.c), button by button: ENV, LFO, FX, SCL, EDIT, GLO, ARP, SEQ. The fixed MOD
    /// routes' and the matrix slots' pages aren't shown: they make up MOD (`modSources`).
    static let specs: [Spec] = [
        Spec(title: "ENV", family: "ENV", scope: 0, labels: ["ATTACK", "DECAY", "SUSTAIN", "RELEASE"]),
        Spec(title: "ENV 2", family: "ENV", scope: 0, labels: ["ATTACK", "DECAY", "SUSTAIN", "RELEASE"], nth: 2),
        Spec(title: "LFO", family: "LFO", scope: 0, labels: ["RATE", "WAVE", "PHASE", "FADE"]),
        Spec(title: "LFO 2", family: "LFO", scope: 0, labels: ["SYNC", "TRIG", "POLARITY", "ENV SYNC"]),
        Spec(title: "MOD", family: "LFO", scope: 0, labels: [nil, "SRC1", "DEST1", "AMT1"]),
        Spec(title: "FX", family: "FX", scope: 0, labels: ["DIST", "CHORUS", "DELAY", "REVERB"]),
        Spec(title: "DRIVE", family: "FX", scope: 0, labels: ["DIST", "TYPE", "TONE", nil]),
        Spec(title: "INSERT", family: "FX", scope: 0, labels: ["TYPE", "A", "B", "C"], nth: 2),
        Spec(title: "INSERT 2", family: "FX", scope: 0, labels: ["MIX", nil, nil, nil]),
        Spec(title: "SLICER", family: "FX", scope: 0, labels: ["SLICER", "PATTERN", "RATE", "DEPTH"]),
        Spec(title: "DUCK", family: "FX", scope: 0, labels: ["BY", "DEPTH", "RELEASE", nil]),
        Spec(title: "SCALE", family: "SEL", scope: 0, labels: ["ROOT", "SCALE", "QUANTIZE", "TRANSP"]),
        Spec(title: "CHORD", family: "SEL", scope: 0, labels: ["CHORD", "VOICING", nil, nil]),
        Spec(title: "FOLLOW", family: "SEL", scope: 0, labels: ["FOLLOW", "MODE", "NOTE", nil]),
        Spec(title: "VOICE", family: "EDIT", scope: 0, labels: ["VOICE", "GLIDE", "GL MODE", "PRIORITY"]),
        Spec(title: "VOICE 2", family: "EDIT", scope: 0, labels: ["ALLOC", "DETUNE", "SPREAD", nil]),
        Spec(title: "DELAY", family: "GLO", scope: 1, labels: ["TIME", "FEEDBACK", "COLOR", "MIX"]),
        Spec(title: "REVERB", family: "GLO", scope: 1, labels: ["TYPE", "SIZE", "DAMP", nil]),
        Spec(title: "CHORUS", family: "GLO", scope: 1, labels: ["RATE", "DEPTH", "MODE", "FEEDBACK"]),
        Spec(title: "GLOBAL", family: "GLO", scope: 1, labels: ["BPM", "SWING+", nil, nil]),
        Spec(title: "ARP", family: "ARP", scope: 0, labels: ["MODE", "RATE", "OCTAVE", "GATE"]),
        Spec(title: "ARP 2", family: "ARP", scope: 0, labels: ["SWING", "CHANCE", "HOLD", "ORDER"]),
        Spec(title: "PATTERN", family: "SEQ", scope: 0, labels: ["LENGTH", "DIV", "SWING", "GATE"]),
        Spec(title: "PATTERN 2", family: "SEQ", scope: 0, labels: ["DIR", nil, nil, nil]),
    ]

    /// Where MOD's routes come from (ui.c MOD_FIXED, then the slots): LFO DEST's and ENV DEST's of before, by label.
    static let modSources: [Spec] = [
        Spec(title: "LFO DEST", family: "LFO", scope: 0, labels: ["PITCH", "CUTOFF", "SHAPE", "AMP"], nth: 2),
        Spec(title: "ENV DEST", family: "ENV", scope: 0, labels: ["CUTOFF", "PITCH", "SHAPE", "FX"]),
        Spec(title: "MOD 1", family: "LFO", scope: 0, labels: ["SRC1", "DEST1", "AMT1", nil]),
        Spec(title: "MOD 2", family: "LFO", scope: 0, labels: ["SRC2", "DEST2", "AMT2", nil]),
        Spec(title: "MOD 3", family: "LFO", scope: 0, labels: ["SRC3", "DEST3", "AMT3", nil]),
        Spec(title: "MOD 4", family: "LFO", scope: 0, labels: ["SRC4", "DEST4", "AMT4", nil]),
    ]

    public static func build(track: [ParamDesc], globals: [ParamDesc], firstEngineParam e0: Int) -> [PageSpec] {
        func ids(_ s: Spec) -> [Int?] {
            let ds = s.scope == 0 ? track : globals
            var prev = -1
            var ids: [Int?] = []
            for (k, label) in s.labels.enumerated() {
                guard let label else { ids.append(nil); continue }
                let hits = ds.filter { $0.label == label }.map(\.id)
                let id: Int?
                if k == 0 { id = hits.count >= s.nth ? hits[s.nth - 1] : nil }
                else { id = hits.first { $0 > prev } ?? hits.first }        // after the knob before, else the first
                if let id { prev = id }
                ids.append(id)
            }
            return ids
        }
        var pages: [PageSpec] = []
        let src = modSources.map(ids)
        for s in specs {
            let k = ids(s)
            guard k.contains(where: { $0 != nil }) else { continue }
            var page = PageSpec(title: s.title, family: s.family, scope: s.scope, ids: k)
            if s.title == "MOD" {
                // the fixed routes: LFO → PITCH CUT SHAPE AMP, ENV → PITCH CUT SHAPE (ENV DEST lists CUTOFF first)
                let lfo = src[0], env = src[1]
                page.routes = [[lfo[0]], [lfo[1]], [lfo[2]], [lfo[3]], [env[1]], [env[0]], [env[2]]]
                    + src[2...5].map { Array($0.prefix(3)) }
            }
            pages.append(page)
        }
        // the engine's eight, titled by NAMES; after VOICE's pages on the EDIT button, as on the device
        let edit = [PageSpec(title: "EDIT 1", family: "EDIT", scope: 0, ids: (0..<4).map { e0 + $0 }, engineEdit: 1),
                    PageSpec(title: "EDIT 2", family: "EDIT", scope: 0, ids: (4..<8).map { e0 + $0 }, engineEdit: 2)]
        let at = pages.firstIndex { $0.family == "EDIT" } ?? pages.count
        pages.insert(contentsOf: edit + enginePages(track: track, e0: e0), at: at)
        return pages
    }

    /// Skiff 2.2's engines (engines.c), for the pages only some of them show (ui.c page_visible).
    public enum Engine {
        public static let sample = 4, drum = 10, fm6 = 12, slice = 13, drumX = 14
    }

    /// The engine pages after EDIT 1 and 2, in PAGES order (ui.c page_visible): OPERATOR and ALL OPS (FM6), LANES
    /// (DRUM), SOUND (DRUM-X), LANE MIX (DRUM, DRUM-X), SLICES (SLICE), SAMPLES (SAMPLE on a user set). Their knobs
    /// come from code on the FM-1, not from PAGES. The lanes' parameters are found from the first KICK (P_LN0):
    /// TUNE, DECAY and PAN share labels with other parameters, so each is the first after the block before it.
    /// OP1–OP4 ENV and OP LEVEL belong to DIGITAL, which Skiff 2.2 doesn't build: never shown, not here.
    static func enginePages(track: [ParamDesc], e0: Int) -> [PageSpec] {
        func first(_ label: String, after: Int) -> Int? { track.filter { $0.label == label && $0.id > after }.map(\.id).min() }
        var pages = [PageSpec(title: "OPERATOR", family: "EDIT", scope: 0, ids: [nil, nil, nil, nil], engines: [Engine.fm6]),
                     PageSpec(title: "ALL OPS", family: "EDIT", scope: 0, ids: [nil, nil, nil, nil], engines: [Engine.fm6])]
        if let ln = first("KICK", after: -1), let tune = first("TUNE", after: ln + 7), let decay = first("DECAY", after: tune + 7),
           let pan = first("PAN", after: decay + 7) {
            pages.append(PageSpec(title: "LANES", family: "EDIT", scope: 0, ids: [nil, ln, tune, decay], engines: [Engine.drum],
                                  picks: (0..<8).map { [ln + $0, tune + $0, decay + $0] }))
            pages.append(PageSpec(title: "SOUND", family: "EDIT", scope: 0, ids: [nil, nil, nil, nil], engines: [Engine.drumX],
                                  picks: (0..<8).map { [ln + $0] }))
            pages.append(PageSpec(title: "LANE MIX", family: "EDIT", scope: 0, ids: [nil, ln, pan, nil], engines: [Engine.drum, Engine.drumX],
                                  picks: (0..<8).map { [ln + $0, pan + $0, nil] }))
        }
        pages.append(PageSpec(title: "SLICES", family: "EDIT", scope: 0, ids: [e0, e0 + 1, nil, nil], engines: [Engine.slice]))
        pages.append(PageSpec(title: "SAMPLES", family: "EDIT", scope: 1, ids: [nil, nil, nil, nil], engines: [Engine.sample]))
        return pages
    }
}

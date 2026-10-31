// Requests, replies and pushes of SLOOP 2.8.4's editor protocol (v12), the subset pass 1 uses.

public enum Cmd {
    public static let info: UInt8 = 1
    public static let get: UInt8 = 2
    public static let set: UInt8 = 3
    public static let desc: UInt8 = 5
    public static let names: UInt8 = 10
    public static let watch: UInt8 = 22
    public static let changed: UInt8 = 23
    public static let reload: UInt8 = 24
    public static let ping: UInt8 = 25
    public static let stepChanged: UInt8 = 26
    public static let track: UInt8 = 27
    public static let trackStep: UInt8 = 30
    public static let trackParam: UInt8 = 31
    public static let trackChanged: UInt8 = 32
    public static let drumStep: UInt8 = 33
    public static let live: UInt8 = 77

    /// Frames the device sends on its own; they are never replies.
    public static let pushes: Set<UInt8> = [changed, reload, stepChanged, trackChanged]
}

/// Track parameter ids (`P_*`, firmware core.h) and global ids (`G_*`) that pass 1 reads.
public enum Param {
    public static let level = 0, root = 25, scale = 26, quant = 27, transpose = 28, length = 29, division = 30, pan = 39, mute = 40
    public static let chord = 49
    public static let all = [level, root, scale, quant, transpose, length, division, pan, mute, chord]
}
public enum Global {
    public static let bpm = 0, swing = 1, drumLevel = 25
    /// GLO > MIDI > OTHER: what channels no track owns play (0 SEL: the selected track, 1 OFF).
    public static let otherChannels = 36
    /// GLO > MIDI 3 > DR MAP: how MIDI notes pick drum lanes (0 GM notes, 1 any 16 notes in a row from 36).
    public static let drumMap = 46
    public static let all = [bpm, swing, drumLevel, otherChannels, drumMap]
}

public enum Request: Equatable, Sendable, CustomStringConvertible {
    case info
    case track                                 // query
    case selectTrack(Int)
    case names(engine: Int)
    case trackStep(track: Int, index: Int)
    case drumStep(index: Int)
    case trackParam(track: Int, id: Int)
    case global(id: Int)
    case desc(scope: Int, id: Int)
    case watch(Int)
    case ping
    case live
    case transport(play: Bool)                 // LIVE op 1
    case setTrackStep(track: Int, index: Int, SynthStep)
    case setDrumStep(index: Int, DrumStep)
    case setTrackParam(track: Int, id: Int, value: Int)
    case setGlobal(id: Int, value: Int)

    public var cmd: UInt8 {
        switch self {
        case .info: Cmd.info
        case .track, .selectTrack: Cmd.track
        case .names: Cmd.names
        case .trackStep: Cmd.trackStep
        case .drumStep: Cmd.drumStep
        case .trackParam: Cmd.trackParam
        case .global: Cmd.get
        case .desc: Cmd.desc
        case .watch: Cmd.watch
        case .ping: Cmd.ping
        case .live, .transport: Cmd.live
        case .setTrackStep: Cmd.trackStep
        case .setDrumStep: Cmd.drumStep
        case .setTrackParam: Cmd.trackParam
        case .setGlobal: Cmd.set
        }
    }

    public var args: [UInt8] {
        switch self {
        case .info, .track, .ping: []
        case .selectTrack(let t): [UInt8(t)]
        case .names(let e): [UInt8(e)]
        case .trackStep(let t, let i): [UInt8(t), UInt8(i)]
        case .drumStep(let i): [UInt8(i)]
        case .trackParam(let t, let id): [UInt8(t), UInt8(id)]
        case .global(let id): [1, UInt8(id)]
        case .desc(let s, let id): [UInt8(s), UInt8(id)]
        case .watch(let on): [UInt8(on)]
        case .live: [0]
        case .transport(let play): [1, play ? 1 : 0]
        case .setTrackStep(let t, let i, let step): [UInt8(t), UInt8(i)] + step.encoded
        case .setDrumStep(let i, let step): [UInt8(i)] + step.encoded
        case .setTrackParam(let t, let id, let v): [UInt8(t), UInt8(id)] + Frame.v14(v)
        case .setGlobal(let id, let v): [1, UInt8(id)] + Frame.v14(v)
        }
    }

    public var bytes: [UInt8] { Frame.encode(cmd, args) }

    /// Whether a reply body answers this request. Another editor on the same port gets its replies
    /// too, so a reply with the right command but other arguments is not ours.
    public func matches(_ body: [UInt8]) -> Bool {
        switch self {
        case .info, .track, .selectTrack, .ping, .watch: true
        case .names(let e): body.first == UInt8(e)
        case .trackStep(let t, let i): body.count >= 2 && body[0] == UInt8(t) && body[1] == UInt8(i)
        case .drumStep(let i): body.first == UInt8(i)
        case .trackParam(let t, let id): body.count >= 2 && body[0] == UInt8(t) && body[1] == UInt8(id)
        case .global(let id): body.count >= 2 && body[0] == 1 && body[1] == UInt8(id)
        case .desc(let s, let id): body.count >= 2 && body[0] == UInt8(s) && body[1] == UInt8(id)
        case .live: body.first == 0
        case .transport: body.first == 1
        case .setTrackStep(let t, let i, _): body.count >= 2 && body[0] == UInt8(t) && body[1] == UInt8(i)
        case .setDrumStep(let i, _): body.first == UInt8(i)
        case .setTrackParam(let t, let id, _): body.count >= 2 && body[0] == UInt8(t) && body[1] == UInt8(id)
        case .setGlobal(let id, _): body.count >= 2 && body[0] == 1 && body[1] == UInt8(id)
        }
    }

    /// The doc says requests that toggle are never sent twice. None of these toggle (transport sets
    /// an explicit state), so every request may be retried after a timeout.
    public var description: String { "\(self.cmdName)(\(args.map(String.init).joined(separator: ",")))" }
    var cmdName: String {
        switch self {
        case .info: "INFO"
        case .track, .selectTrack: "TRACK"
        case .names: "NAMES"
        case .trackStep: "TRACK_STEP"
        case .drumStep: "DRUM_STEP"
        case .trackParam: "TRACK_PARAM"
        case .global: "GET"
        case .desc: "DESC"
        case .watch: "WATCH"
        case .ping: "PING"
        case .live, .transport: "LIVE"
        case .setTrackStep: "TRACK_STEP set"
        case .setDrumStep: "DRUM_STEP set"
        case .setTrackParam: "TRACK_PARAM set"
        case .setGlobal: "SET"
        }
    }
}

// MARK: - Replies

public struct DeviceInfo: Equatable, Sendable {
    public var version: String
    public var engines: [String]
    public var paramCount: Int
    public var globalCount: Int
    public var stepCount: Int
    public var firstEngineParam: Int
    public var trackCount: Int
    public var protocolVersion: Int

    public static let expectedVersion = "FELUCCA SLOOP 2.8.4"
    public static let expectedProtocol = 12
    public var isSupported: Bool { version == Self.expectedVersion && protocolVersion == Self.expectedProtocol }

    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.info)
        version = try r.string()
        let n = try r.u8()
        paramCount = try r.u8(); globalCount = try r.u8(); stepCount = try r.u8(); firstEngineParam = try r.u8()
        engines = try (0..<n).map { _ in try r.string() }
        trackCount = r.remaining > 0 ? try r.u8() : 1
        protocolVersion = r.remaining > 0 ? try r.u8() : 0
    }

    public init(version: String, engines: [String], paramCount: Int, globalCount: Int, stepCount: Int,
                firstEngineParam: Int, trackCount: Int, protocolVersion: Int) {
        self.version = version; self.engines = engines; self.paramCount = paramCount; self.globalCount = globalCount
        self.stepCount = stepCount; self.firstEngineParam = firstEngineParam; self.trackCount = trackCount
        self.protocolVersion = protocolVersion
    }
}

public struct TrackSummary: Equatable, Sendable {
    public var engine: Int          // == engine count: the drum track
    public var preset: Int
    public var level: Int
    public var mute: Bool
    public var armed: Bool
    public init(engine: Int, preset: Int, level: Int, mute: Bool, armed: Bool) {
        self.engine = engine; self.preset = preset; self.level = level; self.mute = mute; self.armed = armed
    }
}

public struct TrackList: Equatable, Sendable {
    public var selected: Int
    public var tracks: [TrackSummary]
    public var soloMask: Int

    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.track)
        selected = try r.u8()
        let n = try r.u8()
        tracks = try (0..<n).map { _ in
            TrackSummary(engine: try r.u8(), preset: try r.u8(), level: try r.v14(), mute: try r.u8() != 0, armed: try r.u8() != 0)
        }
        soloMask = r.remaining > 0 ? try r.u8() : 0
    }
}

public struct PresetNames: Equatable, Sendable {
    public var engine: Int
    public var names: [String]
    public var pageTitles: [String]

    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.names)
        engine = try r.u8()
        let n = try r.u8()
        names = try (0..<n).map { _ in try r.string() }
        var titles: [String] = []
        while r.remaining > 0, titles.count < 2 { titles.append(try r.string()) }
        pageTitles = titles
    }
}

public enum StepTime: Int, Sendable { case note = 0, tie = 1, rest = 2 }

/// A synth step: up to four notes with a level (0 NORM, 1 GHOST, 2 SOFT, 3 HARD) and a ratchet (x1..x4) each.
public struct SynthStep: Equatable, Sendable {
    public var notes: [Int]
    public var time: StepTime
    public var accent: Bool
    public var slide: Bool
    public var velocity: Int
    public var levels: [Int]
    public var ratchets: [Int]

    public static let empty = SynthStep(notes: [], time: .rest, accent: false, slide: false, velocity: 100)

    public init(notes: [Int], time: StepTime, accent: Bool, slide: Bool, velocity: Int,
                levels: [Int]? = nil, ratchets: [Int]? = nil) {
        self.notes = notes; self.time = time; self.accent = accent; self.slide = slide; self.velocity = velocity
        self.levels = levels ?? Array(repeating: 0, count: notes.count)
        self.ratchets = ratchets ?? Array(repeating: 0, count: notes.count)
    }

    public var isOn: Bool { time == .note && !notes.isEmpty }

    /// The bytes after `track, index` in a TRACK_STEP write: n, note0..3, time, flags, vel, then the
    /// v5 lvl, hi, rat (without them SLOOP zeroes the levels and ratchets).
    public var encoded: [UInt8] {
        let n = min(notes.count, 4)
        let ns = (0..<4).map { $0 < n ? UInt8(notes[$0] & 0x7F) : 0 }
        var lvl = 0, rat = 0
        for k in 0..<n {
            lvl |= (k < levels.count ? levels[k] & 3 : 0) << (2 * k)
            rat |= (k < ratchets.count ? ratchets[k] & 3 : 0) << (2 * k)
        }
        return [UInt8(n)] + ns + [UInt8(time.rawValue), UInt8((accent ? 1 : 0) | (slide ? 2 : 0)), UInt8(min(max(velocity, 1), 127)),
                UInt8(lvl & 0x7F), UInt8((lvl >> 7 & 1) | (rat >> 7 & 1) << 1), UInt8(rat & 0x7F)]
    }

    /// Decodes the body after `track, index` (TRACK_STEP) or after `index` (STEP_GET).
    public init(reader r: inout ByteReader) throws {
        let n = min(try r.u8(), 4)
        let raw = try (0..<4).map { _ in try r.u8() }
        time = StepTime(rawValue: try r.u8()) ?? .rest
        let flags = try r.u8()
        accent = flags & 1 != 0; slide = flags & 2 != 0
        velocity = try r.u8()
        notes = Array(raw.prefix(n))
        var lvl = 0, rat = 0
        if r.remaining >= 3 {
            lvl = try r.u8(); let hi = try r.u8(); rat = try r.u8()
            lvl |= (hi & 1) << 7; rat |= (hi & 2) << 6
        }
        levels = (0..<n).map { (lvl >> (2 * $0)) & 3 }
        ratchets = (0..<n).map { (rat >> (2 * $0)) & 3 }
    }
}

public struct TrackStepReply: Equatable, Sendable {
    public var track: Int, index: Int, step: SynthStep
    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.trackStep)
        track = try r.u8(); index = try r.u8()
        step = try SynthStep(reader: &r)
    }
}

/// The 16 drum lanes of one step: lane l is on when bit l is set; level and ratchet are 2 bits per lane.
public struct DrumStep: Equatable, Sendable {
    public var on: UInt16
    public var levels: UInt32
    public var ratchets: UInt32
    public static let empty = DrumStep(on: 0, levels: 0, ratchets: 0)
    public init(on: UInt16, levels: UInt32, ratchets: UInt32) { self.on = on; self.levels = levels; self.ratchets = ratchets }

    public func has(_ lane: Int) -> Bool { on >> lane & 1 == 1 }
    public func level(_ lane: Int) -> Int { Int(levels >> (2 * lane) & 3) }
    public func ratchet(_ lane: Int) -> Int { Int(ratchets >> (2 * lane) & 3) }
    public var lanes: [Int] { (0..<16).filter(has) }
    public var isOn: Bool { on != 0 }

    /// A lane switched on (level and ratchet as given) or off (its level and ratchet cleared, as SLOOP reads them back).
    public func setting(_ lane: Int, on enabled: Bool, level: Int = 0, ratchet: Int = 0) -> DrumStep {
        var d = self
        let sh = UInt32(2 * lane)
        d.levels &= ~(3 << sh); d.ratchets &= ~(3 << sh)
        if enabled {
            d.on |= 1 << UInt16(lane)
            d.levels |= UInt32(level & 3) << sh; d.ratchets |= UInt32(ratchet & 3) << sh
        } else {
            d.on &= ~(1 << UInt16(lane))
        }
        return d
    }

    /// The bytes after `index` in a DRUM_STEP write: on (3 x 7 bits), lvl and rat (5 x 7 bits each), LSB first.
    public var encoded: [UInt8] {
        func b(_ v: UInt64, _ n: Int) -> [UInt8] { (0..<n).map { UInt8((v >> (7 * UInt64($0))) & 0x7F) } }
        return b(UInt64(on), 3) + b(UInt64(levels), 5) + b(UInt64(ratchets), 5)
    }
}

public struct DrumStepReply: Equatable, Sendable {
    public var index: Int, step: DrumStep
    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.drumStep)
        index = try r.u8()
        step = DrumStep(on: UInt16(truncatingIfNeeded: try r.bits(3)),
                        levels: UInt32(truncatingIfNeeded: try r.bits(5)),
                        ratchets: UInt32(truncatingIfNeeded: try r.bits(5)))
    }
}

public struct ParamValue: Equatable, Sendable {
    public var owner: Int, id: Int, value: Int     // owner: the track (TRACK_PARAM) or the scope (GET)
    public init(_ body: [UInt8], cmd: UInt8) throws {
        var r = ByteReader(body, cmd: cmd)
        owner = try r.u8(); id = try r.u8(); value = try r.v14()
    }
}

public struct ParamDesc: Equatable, Sendable {
    public var scope: Int, id: Int, format: Int, min: Int, max: Int, defaultValue: Int
    public var label: String, unit: String, names: [String]
    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.desc)
        scope = try r.u8(); id = try r.u8(); format = try r.u8()
        min = try r.v14(); max = try r.v14(); defaultValue = try r.v14()
        label = try r.string(); unit = try r.string()
        var n: [String] = []
        if format == 8 { while r.remaining > 0 { n.append(try r.string()) } }
        names = n
    }
}

/// LIVE's state (firmware editor_live.c): op, then 49 bytes.
public struct LiveState: Equatable, Sendable {
    public struct TrackPosition: Equatable, Sendable {
        public var step: Int, length: Int, meter: Int
        public init(step: Int, length: Int, meter: Int) { self.step = step; self.length = length; self.meter = meter }
    }
    public var playing: Bool
    public var songMode: Bool
    public var bpm: Int
    public var section: Int?          // 0..3 = A..D
    public var mutes: Int
    public var solos: Int
    public var recTracks: Int
    public var selected: Int
    public var cpu: Int
    public var tracks: [TrackPosition]

    public init(playing: Bool, songMode: Bool = false, bpm: Int, section: Int? = nil, mutes: Int = 0, solos: Int = 0,
                recTracks: Int = 0, selected: Int, cpu: Int = 0, tracks: [TrackPosition]) {
        self.playing = playing; self.songMode = songMode; self.bpm = bpm; self.section = section; self.mutes = mutes
        self.solos = solos; self.recTracks = recTracks; self.selected = selected; self.cpu = cpu; self.tracks = tracks
    }

    public init(_ body: [UInt8]) throws {
        var r = ByteReader(body, cmd: Cmd.live)
        _ = try r.u8()                                  // op
        let flags = try r.u8(); _ = try r.u8()
        playing = flags & 1 != 0; songMode = flags & 4 != 0
        bpm = try r.v14()
        let sec = try r.u8(); section = sec == 0 ? nil : sec - 1
        _ = try r.u8(); _ = try r.u8(); _ = try r.u8()  // section asked for, chain entries, chain index
        mutes = try r.u8(); solos = try r.u8(); recTracks = try r.u8()
        selected = try r.u8()
        _ = try r.u8()                                  // punch-in effect
        cpu = try r.u8()
        for _ in 0..<5 { _ = try r.u8() }               // song entry, entries, bar, bars, sections stored
        tracks = try (0..<4).map { _ in TrackPosition(step: try r.u8(), length: try r.u8(), meter: try r.u8()) }
    }
}

// MARK: - Pushes

public enum Push: Equatable, Sendable {
    case changed(scope: Int, id: Int, value: Int)
    case reload(engine: Int, preset: Int, track: Int)
    case stepChanged(index: Int, track: Int)
    case trackChanged(track: Int, id: Int, value: Int)

    public init?(cmd: UInt8, body: [UInt8]) throws {
        var r = ByteReader(body, cmd: cmd)
        switch cmd {
        case Cmd.changed: self = .changed(scope: try r.u8(), id: try r.u8(), value: try r.v14())
        case Cmd.reload: self = .reload(engine: try r.u8(), preset: try r.u8(), track: try r.u8())
        case Cmd.stepChanged: self = .stepChanged(index: try r.u8(), track: try r.u8())
        case Cmd.trackChanged: self = .trackChanged(track: try r.u8(), id: try r.u8(), value: try r.v14())
        default: return nil
        }
    }
}

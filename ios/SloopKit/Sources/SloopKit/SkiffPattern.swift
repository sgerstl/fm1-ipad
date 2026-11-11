import Foundation

// A stored Skiff pattern read whole, for the exports (vault export-plan.md): everything a step holds and the pattern's
// timing, as bank.c lays out its 888-byte record (bank.c, top comment; pat_decode) and project.c reads a step
// (step_get9). SkiffPatternSketch reads the same record for the pads' pictures; this one keeps what playing it needs.
//
// The record: 0 the version (1, 2 or 3; 0 empty), 1 the motion's parameter count, 2…6 LEN DIV SWING GATE DIR each + 64,
// 7 the motion count (bit 7: it plays), 8…583 the 64 steps of 9 bytes, 584…631 their NUDGE (6 bits each, 4 steps in 3
// bytes), 632…887 the motion, 64 × (step | id bit 7 << 6, id | lock << 7, value lo, value hi).

/// One stored pattern, as the sequencer plays it.
public struct SkiffPattern: Equatable, Sendable {
    public enum Time: Int, Sendable { case note = 0, tie = 1, rest = 2 }     // core.h ST_NOTE, ST_TIE, ST_REST
    public enum Direction: Int, Sendable { case forward = 0, reverse = 1, pingPong = 2, random = 3 }   // seq.c DIR_*

    /// A step (core.h step_t), as step_get9 reads its 9 bytes.
    public struct Step: Equatable, Sendable {
        /// Its notes, 0…4 of them (MIDI note numbers).
        public var notes: [Int] = []
        public var time: Time = .note
        public var accent = false
        public var slide = false
        /// FLAM (Skiff): a grace hit before the full one; only with RATCH ×1.
        public var flam = false
        /// 0…127; 0 plays as 96 (seq.c seq_step).
        public var velocity = 0
        /// Bit l: drum lane l hits (its GM note, DRUM_LANE_NOTE).
        public var hits = 0
        /// Bit l: that hit is accented (velocity 127).
        public var hitAccents = 0
        /// (2.0, #25) Bit k: note k goes on from the step before (only on a step without hits).
        public var ties = 0
        /// 0…100 %.
        public var chance = 100
        /// RATCH, 1…4: the step plays that many times in equal parts.
        public var ratchet = 1
        /// The trig condition (core.h TC_*): 0 none, 1 FILL, 2 !FILL, 3… A:B.
        public var condition = 0
        /// NUDGE, −32…31: 64ths of the step later (earlier when negative). A NOTE step's only.
        public var nudge = 0

        public init() {}

        /// Something starts here: a NOTE step with notes or hits.
        public var sounds: Bool { time == .note && (!notes.isEmpty || hits != 0) }
    }

    /// LEN, 1…64 steps.
    public var length: Int
    /// DIV, as TRACK_PARAM has it (0 1/4, 1 1/8, 2 1/16, 3 1/32, 4 8T, 5 16T, 6 1/2, 7 1 bar, 8 2 bars, 9 4 bars).
    public var division: Int
    /// SWING, 0…100 (the track's own; the global one is added when it plays).
    public var swing: Int
    /// GATE, 1…127: a note's length as 128ths of its step.
    public var gate: Int
    public var direction: Direction
    public var steps: [Step]
    /// Motion records it carries (automation and locks), and whether its automation plays.
    public var motionCount: Int
    public var motionOn: Bool

    public static let recordSize = 888
    static let stepsAt = 8, nudgeAt = 8 + 64 * 9

    /// From an 888-byte record (version 1, 2 or 3); nil for an empty one or bytes no firmware writes (step_get9's checks).
    public init?(record r: [UInt8]) {
        guard r.count >= Self.recordSize, [1, 2, 3].contains(r[0]) else { return nil }
        func p(_ i: Int) -> Int { Int(r[i]) - 64 }
        length = max(1, min(64, p(2)))
        division = max(0, min(9, p(3)))
        swing = max(0, min(100, p(4)))
        gate = max(1, min(127, p(5)))
        direction = Direction(rawValue: max(0, min(3, p(6)))) ?? .forward
        motionCount = Int(r[7] & 127)
        motionOn = r[7] & 128 != 0
        var out: [Step] = []
        out.reserveCapacity(64)
        for i in 0..<64 {
            guard var s = Self.step(Array(r[(Self.stepsAt + 9 * i)..<(Self.stepsAt + 9 * i + 9)])) else { return nil }
            s.nudge = Self.nudge(r, i)
            out.append(s)
        }
        steps = out
    }

    /// project.c step_get9: nil for bytes it refuses.
    static func step(_ b: [UInt8]) -> Step? {
        var s = Step()
        let meta = Int(b[4])
        let n = meta & 7, time = (meta >> 3) & 3, flags = (meta >> 5) & 3
        let ratchet = Int(b[5] >> 7) | Int(b[8] >> 7) << 1
        let probability = Int(b[8] & 127)
        guard n <= 4, time <= 2, probability <= 101, !(meta & 128 != 0 && ratchet != 0) else { return nil }
        var cond = 0
        for j in 0..<4 { cond |= Int(b[j] >> 7) << j }
        guard cond < 12 else { return nil }
        let hit = Int(b[6]), acc = Int(b[7])
        guard acc & ~(hit != 0 ? hit : (1 << n) - 1) == 0 else { return nil }
        s.notes = (0..<n).map { Int(b[$0] & 127) }
        s.time = Time(rawValue: time) ?? .rest
        s.accent = flags & 1 != 0
        s.slide = flags & 2 != 0
        s.flam = meta & 128 != 0
        s.velocity = Int(b[5] & 127)
        s.hits = hit
        s.hitAccents = hit != 0 ? acc : 0
        s.ties = hit != 0 ? 0 : acc & 15 & ((1 << n) - 1)
        s.chance = probability == 0 ? 100 : probability <= 100 ? probability : 0      // core.h step_chance
        s.ratchet = ratchet + 1
        s.condition = cond
        return s
    }

    /// core.h nudge_unpack: 4 steps in 3 bytes, 6 bits each, two's complement.
    static func nudge(_ r: [UInt8], _ i: Int) -> Int {
        let o = nudgeAt + i / 4 * 3
        let w = Int(r[o]) | Int(r[o + 1]) << 8 | Int(r[o + 2]) << 16
        let v = (w >> (6 * (i % 4))) & 63
        return v >= 32 ? v - 64 : v
    }
}

// MARK: - What an SKF4 record says about the song

extension SKF4 {
    /// The offset of the SONG byte (0 OFF, 1 ON, 2 ONCE) and of the entry each track is on (EDITOR_PROTOCOL.md, SKF4).
    static let songModeAt = 483

    /// Track t's 16 entries (A…P): each names a pattern (pool id + 1), a REST (65) or nothing (0), and its REPS byte
    /// (repeats − 1, 0…15; 16 CHAIN into the next).
    public func entries(track t: Int) -> [SongEntry] {
        (0..<Self.entries).map { e in
            let o = Self.entriesAt + 4 * (t * Self.entries + e)
            let p = Int(bytes[o]), reps = Int(bytes[o + 1])
            return SongEntry(pattern: p <= 65 ? p : 0, reps: reps >= 16 ? 1 : reps + 1, chained: reps == 16)
        }
    }

    /// SONG: OFF (each track loops the entry it's on), ON (each loops its list), ONCE (each plays its list once).
    public var songMode: SongMode { SongMode(rawValue: Int(bytes[Self.songModeAt])) ?? .off }

    /// G_BPM (GSID 0), 40…240; nil when the globals don't read.
    public var tempo: Int? { globals.flatMap { $0.first }.map { max(20, min(300, $0)) } }

    /// G_SWING (GSID 1), added to each pattern's own SWING as it plays (core.h track_swing).
    public var globalSwing: Int { globals.flatMap { $0.count > 1 ? $0[1] : nil } ?? 0 }

    /// Track t's engine number (engines.c ENGINES[]), nil when the parameters don't read.
    public func engine(track t: Int) -> Int? { trackParams?[safe: t]?.engine }
}

/// Skiff's engines by number (engines.c ENGINES[]: 1 and 13 are reserved in builds without DIGITAL or SLICE).
public enum SkiffEngines {
    public static let names = ["ANALOG", "DIGITAL", "PHASE", "LOFI", "SAMPLE", "VOICE", "TRIO", "WHEEL", "GRAIN", "PHYS",
                               "DRUM", "NOISE", "FM6", "SLICE", "DRUM-X"]
    public static func name(_ e: Int?) -> String? { e.flatMap { names[safe: $0] } }
    /// DRUM (10) and DRUM-X (14): a kit, its notes the lanes'.
    public static func isDrum(_ e: Int?) -> Bool { e == 10 || e == 14 }
}

import Foundation

// Skiff's song (EDITOR_PROTOCOL.md "Pool, lists, PERFORM"; DESIGN.md "Patterns, lists and the song"): each
// track has 16 entries, A–P, and an entry names a pattern from the pool of 64 (or a REST) and how many passes
// it plays. Entries play back to back: there is no free placement, a gap is a REST. Jib reads the lists with
// LIST2 (82) and the pool with POOL (78), draws each entry as long as it plays, and rewrites entries to
// insert, move or delete, as Skiff has no insert op.

/// One entry in a track's list.
public struct SongEntry: Equatable, Sendable {
    public static let rest = 65

    /// 0 empty, 1...64 a pattern (pool index `pattern - 1`), 65 a REST.
    public var pattern: Int
    /// Passes, 1...16. An entry on CHAIN keeps the REPS the device last had for it only in our copy.
    public var reps: Int
    /// On CHAIN: goes on into the next entry as one pattern.
    public var chained: Bool
    /// The entry's sound (LIST2 op 9's bytes; nil: none): s0 1...63 engine s0 − 1 with preset s1,
    /// 64...127 the user preset in slot s0 − 64.
    public var sound: EntrySound?

    public init(pattern: Int = 0, reps: Int = 1, chained: Bool = false, sound: EntrySound? = nil) {
        self.pattern = pattern; self.reps = reps; self.chained = chained; self.sound = sound
    }

    public static let empty = SongEntry()
    public var isEmpty: Bool { pattern == 0 }
    public var isRest: Bool { pattern == Self.rest }
    /// The pool index (0...63) it names, if it names a pattern.
    public var poolIndex: Int? { (1...64).contains(pattern) ? pattern - 1 : nil }
}

public struct EntrySound: Equatable, Sendable {
    public var s0: Int, s1: Int
    public init(s0: Int, s1: Int) { self.s0 = s0; self.s1 = s1 }
    public var isUser: Bool { s0 >= 64 }
    public var engine: Int? { s0 >= 1 && s0 < 64 ? s0 - 1 : nil }
    public var userSlot: Int? { s0 >= 64 ? s0 - 64 : nil }
}

/// A track's list, as LIST2 has it.
public struct SongList: Equatable, Sendable {
    /// The entry the track is on (nil: on no entry's pattern), the entry staged to come in, and the
    /// pattern it plays (0...63).
    public var entryOn: Int?
    public var staged: Int?
    public var patternOn: Int?
    public var entries: [SongEntry]

    public init(entryOn: Int? = nil, staged: Int? = nil, patternOn: Int? = nil, entries: [SongEntry] = Array(repeating: .empty, count: 16)) {
        self.entryOn = entryOn; self.staged = staged; self.patternOn = patternOn; self.entries = entries
    }

    /// Entries in use: the list runs from its first pattern or REST to its last.
    public var used: Int { entries.filter { !$0.isEmpty }.count }
    public var span: ClosedRange<Int>? {
        guard let a = entries.firstIndex(where: { !$0.isEmpty }), let b = entries.lastIndex(where: { !$0.isEmpty }) else { return nil }
        return a...b
    }
    /// The other entries naming this entry's pattern.
    public func sharing(_ i: Int) -> [Int] {
        guard let p = entries[i].poolIndex else { return [] }
        return entries.indices.filter { $0 != i && entries[$0].poolIndex == p }
    }
}

public enum SongMode: Int, Sendable, CaseIterable {
    case off = 0, on = 1, once = 2
}

/// LIST2's reply: the song mode, then each track's list.
public struct SkiffSong: Equatable, Sendable {
    public var mode: SongMode
    public var tracks: [SongList]

    public init(mode: SongMode = .off, tracks: [SongList]) { self.mode = mode; self.tracks = tracks }

    /// After `op, rc`: SONG, then per track entry on, staged, pattern on (127 none), 16 × (pattern, REPS byte
    /// [, s0, s1 when the device has entry sounds]). REPS byte: REPS − 1, or 16 on CHAIN.
    public init(_ b: ArraySlice<UInt8>, tracks n: Int, sounds: Bool) throws {
        var r = ByteReader(Array(b), cmd: SkiffCmd.list2)
        mode = SongMode(rawValue: try r.u8()) ?? .on
        var lists: [SongList] = []
        for _ in 0..<n {
            func opt(_ v: Int) -> Int? { v == 127 ? nil : v }
            var l = SongList(entryOn: opt(try r.u8()), staged: opt(try r.u8()), patternOn: opt(try r.u8()), entries: [])
            for _ in 0..<16 {
                let p = try r.u8(), reps = try r.u8()
                var e = SongEntry(pattern: p, reps: reps >= 16 ? 1 : reps + 1, chained: reps >= 16)
                if sounds {
                    let s0 = try r.u8(), s1 = try r.u8()
                    if s0 != 0 { e.sound = EntrySound(s0: s0, s1: s1) }
                }
                l.entries.append(e)
            }
            lists.append(l)
        }
        tracks = lists
    }
}

/// POOL's reply: each of the 64 patterns' LEN (0: empty) and how many use it (entries in the lists and the
/// saved projects, and a track on it that no entry names; at most 127).
public struct PatternPool: Equatable, Sendable {
    public struct Pattern: Equatable, Sendable {
        public var length: Int, uses: Int
        public init(length: Int, uses: Int) { self.length = length; self.uses = uses }
        public var isFree: Bool { length == 0 && uses == 0 }
    }
    public var patterns: [Pattern]

    public init(patterns: [Pattern]) { self.patterns = patterns }

    init(_ b: ArraySlice<UInt8>) throws {
        var r = ByteReader(Array(b), cmd: SkiffCmd.pool)
        patterns = try (0..<64).map { _ in Pattern(length: try r.u8(), uses: try r.u8()) }
    }

    public var free: Int { patterns.filter(\.isFree).count }
    /// Kept but named by nothing: CLEAR UNUSED's.
    public var unused: Int { patterns.filter { $0.length > 0 && $0.uses == 0 }.count }
}

/// LIST2's and POOL's answer codes, and what Jib says for each.
public enum SongRC: Int, Sendable, Error {
    case done = 0, empty = 1, withoutAutomation = 2, playing = 3, patternsFull = 4, failed = 5

    public var isDone: Bool { self == .done || self == .withoutAutomation }
    public var reason: String {
        switch self {
        case .done: "Done"
        case .empty: "Skiff refused it: the entry is empty, there's nothing to copy, or no room after it"
        case .withoutAutomation: "Done, without its automation (no room for it)"
        case .playing: "Stop to change this: Skiff does it only while stopped"
        case .patternsFull: "All 64 patterns are taken. Clear unused ones to free a number"
        case .failed: "Skiff couldn't do it"
        }
    }
}

/// One LIST2 change, as the device's SEQ › SONG makes it.
public enum ListOp: Equatable, Sendable {
    case set(track: Int, entry: Int, pattern: Int)       // a kept pattern 1...64, or 65 a REST
    case copy(track: Int, entry: Int)
    case play(track: Int, entry: Int)
    case clear(track: Int, entry: Int)                   // only stopped (a REST at once, playing too)
    case reps(track: Int, entry: Int, reps: Int)         // 1...16
    case chain(track: Int, entry: Int)                   // REPS 0: on into the next as one pattern
    case new(track: Int, entry: Int)
    case copyPlus(track: Int, entry: Int)
    case sound(track: Int, entry: Int, EntrySound?)
    case song(SongMode)

    var bytes: [UInt8] {
        switch self {
        case .set(let t, let e, let p): [1, UInt8(t), UInt8(e), UInt8(p)]
        case .copy(let t, let e): [2, UInt8(t), UInt8(e)]
        case .play(let t, let e): [3, UInt8(t), UInt8(e)]
        case .clear(let t, let e): [4, UInt8(t), UInt8(e)]
        case .reps(let t, let e, let n): [5, UInt8(t), UInt8(e), UInt8(max(1, min(16, n)))]
        case .chain(let t, let e): [5, UInt8(t), UInt8(e), 0]
        case .new(let t, let e): [7, UInt8(t), UInt8(e)]
        case .copyPlus(let t, let e): [8, UInt8(t), UInt8(e)]
        case .sound(let t, let e, let s): [9, UInt8(t), UInt8(e), UInt8(s?.s0 ?? 0), UInt8(s?.s1 ?? 0)]
        case .song(let m): [6, UInt8(m.rawValue)]
        }
    }

    public var track: Int? {
        switch self {
        case .set(let t, _, _), .copy(let t, _), .play(let t, _), .clear(let t, _), .reps(let t, _, _),
             .chain(let t, _), .new(let t, _), .copyPlus(let t, _), .sound(let t, _, _): t
        case .song: nil
        }
    }
    public var entry: Int? {
        switch self {
        case .set(_, let e, _), .copy(_, let e), .play(_, let e), .clear(_, let e), .reps(_, let e, _),
             .chain(_, let e), .new(_, let e), .copyPlus(_, let e), .sound(_, let e, _): e
        case .song: nil
        }
    }
}

// MARK: - Time: where each entry sits on the bar ruler

/// Where an entry (or a chain of them) plays, in MIDI clock ticks from the top of the song: 24 a quarter,
/// 96 a 4/4 bar. A pass is the pattern's LENGTH × its DIV's ticks; swing moves steps, not passes.
public struct SongBlock: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable { case pattern, rest, gap }      // gap: an empty entry inside the list

    /// The entries it covers: one, or a chain's from its first to the one it ends on.
    public var entries: ClosedRange<Int>
    public var kind: Kind
    public var start: Double
    /// One pass of each part, in ticks (a chain's parts in order; one for a single entry).
    public var parts: [Double]
    public var reps: Int
    public var id: Int { entries.lowerBound }

    public var pass: Double { parts.reduce(0, +) }
    public var length: Double { pass * Double(reps) }
    public var end: Double { start + length }
    public var isChain: Bool { entries.count > 1 }
}

public enum SongPlacement {
    public static let ticksPerBar = 96.0

    /// The blocks of one track's list. `length(p)` and `division(p)` are pattern p's (0...63) LENGTH and DIV
    /// (DIV as TRACK_PARAM's 0...9); nil when not known, and the track's own (`trackLength`, `trackDivision`)
    /// stands in. A REST or an empty entry inside the list plays passes of the pattern before it (the
    /// track's timing at that point); one before any pattern, the track's own.
    public static func blocks(_ list: SongList, length: (Int) -> Int?, division: (Int) -> Int?,
                              trackLength: Int, trackDivision: Int) -> [SongBlock] {
        guard let span = list.span else { return [] }
        func ticks(_ len: Int, _ div: Int) -> Double {
            Double(max(1, len)) * CountedPlayhead.divisionTicks[max(0, min(9, div))]
        }
        var timing = ticks(trackLength, trackDivision)
        var out: [SongBlock] = []
        var at = 0.0
        var i = span.lowerBound
        while i <= span.upperBound {
            // a chain: entries on CHAIN with the one they end on; an empty entry ends it
            var j = i
            while j < span.upperBound, list.entries[j].chained, !list.entries[j].isEmpty, !list.entries[j + 1].isEmpty { j += 1 }
            var parts: [Double] = []
            for k in i...j {
                let e = list.entries[k]
                if let p = e.poolIndex {
                    timing = ticks(length(p) ?? trackLength, division(p) ?? trackDivision)
                }
                parts.append(timing)
            }
            let first = list.entries[i]
            let kind: SongBlock.Kind = first.isEmpty ? .gap : (i == j && first.isRest) ? .rest : .pattern
            let b = SongBlock(entries: i...j, kind: kind, start: at, parts: parts, reps: list.entries[j].reps)
            out.append(b)
            at = b.end
            i = j + 1
        }
        return out
    }

    /// The song's length: the longest track.
    public static func length(_ lanes: [[SongBlock]]) -> Double { lanes.map { $0.last?.end ?? 0 }.max() ?? 0 }
}

// MARK: - Rewriting a list

/// The LIST2 ops that turn one list into another: Skiff has no insert or move, so Jib rewrites the entries
/// that change. Entries that name a pattern or a REST first, from the last back (an entry goes on CHAIN only
/// with one after it), then the clears, last, so a pattern that moved is named again before its old entry
/// is cleared (CLEAR erases a pattern nothing else names).
public struct ListRewrite: Equatable, Sendable {
    public var ops: [ListOp]
    /// Why it can't be done while playing (nil: it can): CLEAR is refused while playing, and SET on the
    /// entry the track is on launches it there and then.
    public var needsStop: String?

    public static func plan(track t: Int, from old: SongList, to new: [SongEntry], playing: Bool, sounds: Bool) -> ListRewrite {
        var ops: [ListOp] = []
        var clears: [ListOp] = []
        var stop: String?
        for i in stride(from: 15, through: 0, by: -1) {
            let a = old.entries[i], b = new[i]
            if a == b { continue }
            if b.isEmpty {
                clears.append(.clear(track: t, entry: i))
                if playing && !a.isRest { stop = "Stop to rearrange: Skiff clears an entry only while stopped" }
                continue
            }
            if a.pattern != b.pattern {
                ops.append(.set(track: t, entry: i, pattern: b.pattern))
                if playing && old.entryOn == i { stop = "Stop to rearrange: another pattern on the entry T\(t + 1) is playing would launch it" }
            }
            if a.chained != b.chained || (!b.chained && a.reps != b.reps) || a.pattern != b.pattern {
                ops.append(b.chained ? .chain(track: t, entry: i) : .reps(track: t, entry: i, reps: b.reps))
            }
            if sounds, a.sound != b.sound || (a.pattern != b.pattern && b.sound != nil) {
                ops.append(.sound(track: t, entry: i, b.sound))
            }
        }
        return ListRewrite(ops: ops + clears, needsStop: stop)
    }
}

import Foundation

/// A note on a step: the step it starts on (a NOTE step) and its pitch.
public struct NoteRef: Hashable, Sendable, Comparable {
    public var step: Int, note: Int
    public init(step: Int, note: Int) { self.step = step; self.note = note }
    public static func < (a: NoteRef, b: NoteRef) -> Bool { (a.step, a.note) < (b.step, b.note) }
}

/// Editing a synth pattern's steps as Skiff keeps them (core.h step_t): a NOTE step holds up to four notes and the
/// step's own fields (velocity, chance, ratchet, FLAM, COND, NUDGE), TIE steps after it hold it on, a REST is empty.
/// Pure: the views apply a result by writing the steps that changed (TRACK_STEP) and LENGTH.
public enum PatternEdit {
    public static let maxNotes = 4
    public static let maxSteps = 64

    /// How many steps the NOTE step at i plays: itself and the TIE steps after it.
    public static func length(_ s: [SynthStep], _ i: Int) -> Int {
        var n = 1
        while i + n < s.count, s[i + n].time == .tie { n += 1 }
        return n
    }

    /// The NOTE step a step belongs to (itself, or the one a TIE holds on).
    public static func owner(_ s: [SynthStep], _ i: Int) -> Int {
        var k = i
        while k > 0, s[k].time == .tie { k -= 1 }
        return k
    }

    /// Every note in these steps.
    public static func notes(_ s: [SynthStep], in steps: Set<Int>) -> Set<NoteRef> {
        Set(steps.flatMap { i in i < s.count && s[i].time == .note ? s[i].notes.map { NoteRef(step: i, note: $0) } : [] })
    }

    /// A note added on step i (a REST or a NOTE with room): false where it can't go (a TIE, four notes already).
    @discardableResult
    public static func add(_ s: inout [SynthStep], step i: Int, note n: Int, velocity: Int = 100) -> Bool {
        guard s.indices.contains(i), s[i].time != .tie else { return false }
        if s[i].time == .note {
            guard !s[i].notes.contains(n), s[i].notes.count < maxNotes else { return s[i].notes.contains(n) }
            s[i].notes.append(n); s[i].levels.append(0); s[i].ratchets.append(s[i].ratchets.first ?? 0)
        } else {
            var st = s[i]
            st.time = .note; st.notes = [n]; st.levels = [0]; st.ratchets = [0]
            if st.velocity == 0 { st.velocity = velocity }
            s[i] = st
        }
        return true
    }

    /// A note taken off its step; the step's last note takes the step's TIE steps with it.
    public static func remove(_ s: inout [SynthStep], _ r: NoteRef) {
        guard s.indices.contains(r.step), s[r.step].time == .note, let k = s[r.step].notes.firstIndex(of: r.note) else { return }
        if s[r.step].notes.count == 1 {
            let len = length(s, r.step)
            for j in r.step..<(r.step + len) { s[j].time = .rest; s[j].notes = []; s[j].levels = []; s[j].ratchets = [] }
        } else {
            s[r.step].notes.remove(at: k)
            if k < s[r.step].levels.count { s[r.step].levels.remove(at: k) }
            if k < s[r.step].ratchets.count { s[r.step].ratchets.remove(at: k) }
        }
    }

    /// Notes moved by `steps` and to new pitches (`pitch` maps each note's pitch: by rows in the roll's folded
    /// scale, or by semitones), each keeping its length and its step's fields. A note alone on its step moves the
    /// whole step (its fields, its TIEs); one of a chord leaves the chord and lands as a note of the target step
    /// (taking the source step's fields where the target was empty). A target that's a TIE, full, or past 64 keeps
    /// the note where it was. Returns where each note went.
    @discardableResult
    public static func move(_ s: inout [SynthStep], _ refs: Set<NoteRef>, by steps: Int, pitch: (Int) -> Int?) -> [NoteRef: NoteRef] {
        let before = s
        var moved: [NoteRef: NoteRef] = [:]
        // take them all off first, so notes moving onto each other's places don't collide
        var lifted: [(from: NoteRef, step: SynthStep, length: Int, alone: Bool)] = []
        for r in refs.sorted() {
            guard before.indices.contains(r.step), before[r.step].time == .note, before[r.step].notes.contains(r.note) else { continue }
            let alone = before[r.step].notes.allSatisfy { refs.contains(NoteRef(step: r.step, note: $0)) }
            lifted.append((r, before[r.step], length(before, r.step), alone))
        }
        for l in lifted { remove(&s, l.from) }
        for l in lifted {
            let to = l.from.step + steps
            guard let p = pitch(l.from.note), (0...127).contains(p), to >= 0, to + l.length <= s.count,
                  s[to].time != .tie, s[to].time != .note || s[to].notes.count < maxNotes || s[to].notes.contains(p) else {
                // can't land: back where it was
                put(&s, l, at: l.from.step, pitch: l.from.note)
                moved[l.from] = l.from
                continue
            }
            put(&s, l, at: to, pitch: p)
            moved[l.from] = NoteRef(step: to, note: p)
        }
        return moved
    }

    private static func put(_ s: inout [SynthStep], _ l: (from: NoteRef, step: SynthStep, length: Int, alone: Bool), at to: Int, pitch p: Int) {
        if s[to].time == .note {
            add(&s, step: to, note: p)
            return
        }
        // an empty target: the source step's fields come along, with this one note
        var st = l.step
        st.time = .note; st.notes = [p]; st.levels = [0]; st.ratchets = [l.step.ratchets.first ?? 0]
        s[to] = st
        for j in (to + 1)..<min(s.count, to + l.length) where s[j].time == .rest { s[j].time = .tie }
    }

    /// Notes up or down: `pitch` maps each (rows or semitones); returns where they went.
    @discardableResult
    public static func transpose(_ s: inout [SynthStep], _ refs: Set<NoteRef>, pitch: (Int) -> Int?) -> [NoteRef: NoteRef] {
        move(&s, refs, by: 0, pitch: pitch)
    }

    /// The span a selection covers: from its first step to the end of its last note (TIEs included).
    public static func span(_ s: [SynthStep], _ refs: Set<NoteRef>) -> ClosedRange<Int>? {
        guard let a = refs.map(\.step).min() else { return nil }
        let b = refs.map { $0.step + length(s, $0.step) - 1 }.max() ?? a
        return a...b
    }

    /// Whole steps, as they are, from `range` to the steps starting at `to` (past the end: cut).
    public static func copySteps(_ s: inout [SynthStep], _ range: ClosedRange<Int>, to: Int) {
        let clip = Array(s[range])
        for (k, st) in clip.enumerated() where to + k < s.count { s[to + k] = st }
    }

    /// Duplicate after (Scott's pick): the selection again right after itself. Whole steps when steps were
    /// picked (`refs` nil), else the notes alone. Past LENGTH, LENGTH grows to fit, up to 64. Returns the steps
    /// added (nil when nothing fits) and the length before and after.
    public static func duplicateAfter(_ s: inout [SynthStep], steps: ClosedRange<Int>?, notes refs: Set<NoteRef>?, length: inout Int)
        -> (added: ClosedRange<Int>, oldLength: Int, newLength: Int)? {
        let old = length
        guard let span = steps ?? refs.flatMap({ span(s, $0) }) else { return nil }
        let n = span.count, to = span.upperBound + 1
        guard to < min(s.count, maxSteps) else { return nil }
        let end = min(to + n, min(s.count, maxSteps)) - 1
        if let refs, steps == nil {
            var copy = s
            let moved = move(&copy, refs, by: n, pitch: { $0 })
            // move took them off their steps: put the originals back, keep the copies
            for (from, dest) in moved where from != dest { add(&copy, step: from.step, note: from.note); _ = dest }
            for r in refs where copy[r.step].time != .note || !copy[r.step].notes.contains(r.note) { add(&copy, step: r.step, note: r.note) }
            // the originals keep their own fields and lengths
            for i in span { copy[i] = s[i] }
            s = copy
        } else {
            copySteps(&s, span, to: to)
        }
        if end + 1 > length { length = min(maxSteps, end + 1) }
        return (to...end, old, length)
    }

    /// Steps that differ between two versions of a pattern: what to write.
    public static func changed(_ a: [SynthStep], _ b: [SynthStep]) -> [Int] {
        a.indices.filter { $0 < b.count && a[$0] != b[$0] }
    }
}

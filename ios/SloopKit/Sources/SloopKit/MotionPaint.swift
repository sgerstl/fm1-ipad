import Foundation

/// A finger stroke across a motion lane, turned into MOTION writes (motion lane editor, approach A: canvas
/// "Lupe motion lane editing", qa/motion-design-2026-11-06). Hold strokes are step-and-hold: a change is written only
/// where the painted value differs from the step before, and one more after the stroke puts back what was playing
/// there, so steps the finger didn't touch sound as before. Lock strokes put a lock on every step they touch. Locks
/// already on the lane survive a hold stroke unless a change has to land on their step.
public enum MotionPaint {
    public struct Write: Equatable, Sendable {
        public var step: Int, value: Int, lock: Bool
        public init(step: Int, value: Int, lock: Bool) { self.step = step; self.value = value; self.lock = lock }
    }

    public struct Plan: Equatable, Sendable {
        /// Steps whose record of the parameter goes (MOTION op 4), done first.
        public var deletes: [Int]
        /// Records to set (op 3 or 5), in the order to send them: the restore after the stroke first, so a stroke cut
        /// short by the 64 never changes the steps after it.
        public var writes: [Write]
        /// What the plan adds to the shared 64 (negative: it frees some).
        public var cost: Int
        public static let none = Plan(deletes: [], writes: [], cost: 0)
    }

    /// `events`: the track's records (any parameter); `painted`: step → value under the finger; `base`: the sound's
    /// own value; `steps`: the pattern's length. `restore` false (a tap, not a stroke): no put-back after it, so the
    /// tapped change holds until the next one, as a recorded change does.
    public static func plan(events: [TrackMotion.Event], id: Int, base: Int, painted: [Int: Int], lock: Bool, steps: Int,
                            restore: Bool = true) -> Plan {
        guard let lo = painted.keys.min(), let hi = painted.keys.max() else { return .none }
        let mine = events.filter { $0.id == id }
        func record(_ s: Int) -> TrackMotion.Event? { mine.first { $0.step == s } }
        var writes: [Write] = [], deletes: [Int] = []

        if lock {
            for s in painted.keys.sorted() {
                let v = painted[s]!
                if let r = record(s), r.lock, r.value == v { continue }
                writes.append(Write(step: s, value: v, lock: true))
            }
        } else {
            // the held value as it was: the latest recorded change at or before `s`, else the sound
            func held(_ s: Int) -> Int { mine.filter { !$0.lock && $0.step <= s }.max { $0.step < $1.step }?.value ?? base }
            // a stroke that skipped steps (a fast finger) holds its last value across the gap
            var filled: [Int: Int] = [:], last = painted[lo]!
            for s in lo...hi { if let v = painted[s] { last = v }; filled[s] = last }

            var changes: [Write] = []
            var prev = lo > 0 ? held(lo - 1) : base
            for s in lo...hi {
                let v = filled[s]!
                if v != prev { changes.append(Write(step: s, value: v, lock: false)) }
                prev = v
            }
            // after the stroke: what played there before, unless a record there already says it
            let after = hi + 1
            if restore, after < steps, record(after) == nil, held(after) != prev {
                writes.append(Write(step: after, value: held(after), lock: false))
            }
            for c in changes {
                if let r = record(c.step), !r.lock, r.value == c.value { continue }
                writes.append(c)
            }
            // recorded changes the stroke painted over go; locks stay
            let changed = Set(changes.map(\.step))
            for r in mine where !r.lock && (lo...hi).contains(r.step) && !changed.contains(r.step) { deletes.append(r.step) }
        }
        let added = writes.filter { record($0.step) == nil }.count
        return Plan(deletes: deletes.sorted(), writes: writes, cost: added - deletes.count)
    }
}

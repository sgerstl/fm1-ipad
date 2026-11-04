import Foundation

/// The playhead on firmware that sends no step positions (Skiff): MIDI clock counted from Start, each track
/// walked a step at a time the way Skiff's sequencer does (seq.c seq_tick / seq_next). Ported from the model
/// `tools/skiffprobe playhead` measured against skiff-sim (vault skiff-plan.md, "Phase 1 result"): exact for
/// FWD, RVRS and PING with swing and LENGTH / DIV changes. Not modelled yet: launches (LIST, PERFORM, the
/// song moving on), the shift after a BPM change on the device's own clock, and re-anchoring from notes.
/// RAND can't be predicted: such a track shows no playhead (step −1).
public struct CountedPlayhead: Equatable, Sendable {
    /// A track's settings, as TRACK_PARAM reads them: LENGTH 1..64, DIV 0..9, DIR 0..3, SWING 0..100.
    public struct Settings: Equatable, Sendable {
        public var length: Int, division: Int, direction: Int, swing: Int
        public init(length: Int, division: Int, direction: Int = 0, swing: Int = 0) {
            self.length = length; self.division = division; self.direction = direction; self.swing = swing
        }
    }

    struct Walk: Equatable, Sendable {
        var step = -1             // the step playing (−1: before the first, or RAND)
        var count = 0             // steps into the pass (RVRS and PING start a pass on their first step)
        var down = false          // PING going back
        var nextAt = 0.0          // the tick the next step starts on
        var stepTicks = 6.0       // this step's ticks before swing (DIV can change it while it plays)
        var startedAt = 0.0
    }

    /// Ticks per step for DIV 0..9: 1/4 1/8 1/16 1/32 8T 16T 1/2 1/1 2BAR 4BAR.
    public static let divisionTicks: [Double] = [24, 12, 6, 3, 8, 4, 48, 96, 192, 384]

    public private(set) var ticks = 0          // clock pulses since Start; the first pulse is tick 0
    public private(set) var running = false
    var walks: [Walk]

    public init(tracks: Int) { walks = Array(repeating: Walk(), count: tracks) }

    /// Each track's step now (−1: none known).
    public var steps: [Int] { walks.map(\.step) }
    /// How far into its step each track is, 0..1.
    public func phase(_ t: Int, at tick: Double) -> Double {
        let w = walks[t]
        return max(0, min(0.999, (tick - w.startedAt) / max(1, w.nextAt - w.startedAt)))
    }

    /// Start (0xFA): every track before its first step, which plays on the first pulse.
    public mutating func start() {
        ticks = -1
        running = true
        walks = Array(repeating: Walk(), count: walks.count)
    }

    public mutating func stop() { running = false }

    /// A clock pulse. Returns true when any track moved to another step.
    @discardableResult
    public mutating func tick(_ settings: [Settings], globalSwing: Int) -> Bool {
        guard running else { return false }
        ticks += 1
        let k = Double(ticks)
        var moved = false
        for t in walks.indices where t < settings.count {
            let s = settings[t]
            let T = Self.divisionTicks[max(0, min(9, s.division))]
            var w = walks[t]
            if ticks == 0 { w.nextAt = 0; w.stepTicks = T }
            // a DIV change resizes the step that's playing
            if ticks > 0, T != w.stepTicks {
                w.nextAt = max(k, w.startedAt + T)
                w.stepTicks = T
            }
            if k >= w.nextAt {
                Self.next(&w, s)
                w.startedAt = w.nextAt
                w.stepTicks = T
                let sw = Double(min(100, max(0, s.swing + globalSwing)))
                w.nextAt += T * (1 + (w.step >= 0 && w.step & 1 == 1 ? -sw : sw) / 250)
                moved = true
            }
            walks[t] = w
        }
        return moved
    }

    /// seq_next: the step after this one, for the track's LENGTH and DIR as they are now.
    static func next(_ w: inout Walk, _ s: Settings) {
        let ln = max(1, s.length), dir = s.direction
        if dir == 3 { w.step = -1 }
        else if w.count == 0 && dir != 0 { w.down = false; w.step = dir == 1 ? ln - 1 : 0 }
        else {
            let i = w.step < ln ? w.step : ln - 1
            switch dir {
            case 1: w.step = i > 0 ? i - 1 : ln - 1
            case 2:
                let n = ln < 2 ? 0 : w.down ? (i > 0 ? i - 1 : 1) : (i + 1 < ln ? i + 1 : ln - 2)
                w.down = n < i
                w.step = n
            default: w.step = (w.step + 1) % ln
            }
        }
        if dir == 0 ? w.step == 0 : (w.count == 0 || w.count >= ln) { w.count = 0 }
        w.count += 1
    }
}

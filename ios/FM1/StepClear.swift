import SloopKit

// Clearing a pattern's steps with an Undo that works on Skiff (P1, d953844): SloopKit's clearAll / undo compare against
// SynthStep.empty, but an emptied Skiff step reads back with its extra bytes, so it never equals that: undo found no
// empty steps and wrote nothing back, and clearAll rewrote every step every time. Here the old steps are kept by the app
// and a step counts as empty by what it plays (no note, tie or lane hit). Used by Clear steps (decision 41) and the
// iPad's Clear all. Writes go to the pattern the track is on (Skiff edits no other).

struct StepsKept: Equatable {
    var track: Int
    var drums: Bool
    var steps: [SynthStep]
    var drumSteps: [DrumStep]
}

@MainActor
enum StepClear {
    /// A synth step that plays nothing (Skiff's emptied step, whatever its extra bytes).
    static func blank(_ s: SynthStep) -> Bool { !(s.isOn || s.time == .tie || (s.time == .note && s.hits.isOn)) }

    /// Empties every step that plays something, and returns what was there.
    @discardableResult
    static func clear(_ session: DeviceSession, track t: Int) -> StepsKept {
        let tr = session.tracks[t]
        let kept = StepsKept(track: t, drums: session.isDrums(t), steps: tr.steps, drumSteps: tr.drumSteps)
        for i in session.stepIndices {
            if kept.drums { if tr.drumSteps[safe: i]?.isOn == true { session.write(drumIndex: i, .empty) } }
            else if let s = tr.steps[safe: i], !blank(s) { session.write(track: t, index: i, .empty) }
        }
        return kept
    }

    /// Writes back what a clear took away; steps edited since (not empty any more) are left as they are now.
    static func undo(_ session: DeviceSession, _ k: StepsKept) {
        let tr = session.tracks[k.track]
        for i in session.stepIndices {
            if k.drums {
                if tr.drumSteps[safe: i]?.isOn == false, let old = k.drumSteps[safe: i], old.isOn { session.write(drumIndex: i, old) }
            } else if let now = tr.steps[safe: i], blank(now), let old = k.steps[safe: i], !blank(old) {
                session.write(track: k.track, index: i, old)
            }
        }
    }
}

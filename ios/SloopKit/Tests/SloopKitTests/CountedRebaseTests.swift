import Testing
@testable import SloopKit

/// 2026-11-11: a track that came onto a pattern of another DIV or LEN was corrected only at the step it was on, and stayed
/// steps off the FM-1 after. rebase walks it again from the pass's start with the right settings.
struct CountedRebaseTests {
    @Test func aLateDivChangeIsRecountedFromThePassStart() {
        let old = CountedPlayhead.Settings(length: 16, division: 2)     // 1/16: 6 ticks a step, a pass 96
        let new = CountedPlayhead.Settings(length: 16, division: 1)     // 1/8: 12 ticks a step
        // the FM-1 moves on at the pass end (tick 96) and plays the new pattern from its first step there: at tick k
        // after that, step (k − 96) / 12 of 16
        func truth(_ k: Int) -> Int { ((k - 96) / 12) % 16 }
        var counted = CountedPlayhead(tracks: 1); counted.start()
        var k = 0
        while k <= 140 { counted.tick([k < 120 ? old : new], globalSwing: 0); k += 1 }   // Lupe learns of it a beat late
        #expect(counted.steps[0] != truth(140), "without the rebase the count is off")
        counted.rebase(track: 0, new, globalSwing: 0)
        #expect(counted.steps[0] == truth(140))
        #expect(counted.passCount(0) == 2)
        while k <= 700 { counted.tick([new], globalSwing: 0); #expect(counted.steps[0] == truth(k), "tick \(k)"); k += 1 }
    }

    @Test func aShorterPatternIsRecounted() {
        let old = CountedPlayhead.Settings(length: 16, division: 2), new = CountedPlayhead.Settings(length: 4, division: 2)
        var truth = CountedPlayhead(tracks: 1); truth.start()
        var counted = CountedPlayhead(tracks: 1); counted.start()
        for k in 0...150 {
            truth.tick([k < 96 ? old : new], globalSwing: 0)
            counted.tick([k < 140 ? old : new], globalSwing: 0)
        }
        counted.rebase(track: 0, new, globalSwing: 0)
        #expect(counted.steps == truth.steps)
        for _ in 0..<100 { truth.tick([new], globalSwing: 0); counted.tick([new], globalSwing: 0) }
        #expect(counted.steps == truth.steps)
    }
}

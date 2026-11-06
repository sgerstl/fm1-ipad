import Foundation
import Testing
@testable import SloopKit

/// The motion lane editor's strokes (MotionPaint): step-and-hold writes only where the value changes, puts back
/// what played after the stroke, and counts what it costs of the shared 64.
struct MotionPaintTests {
    // REVERB (id 36) as on the canvas: the sound's 12, changes at 3 (40), 7 (70), 11 (25), a lock on 15 (90)
    let id = 36
    var lane: [TrackMotion.Event] {
        [.init(step: 2, id: id, value: 40, lock: false), .init(step: 6, id: id, value: 70, lock: false),
         .init(step: 10, id: id, value: 25, lock: false), .init(step: 14, id: id, value: 90, lock: true),
         .init(step: 4, id: 34, value: 99, lock: false)]                                    // another lane's record
    }

    @Test func aFlatStrokeCostsOneChangeAndARestore() {
        // steps 5–12 (4…11) at 50: a change at 4, the old 25 put back at 12, the changes at 6 and 10 gone
        let p = MotionPaint.plan(events: lane, id: id, base: 12, painted: Dictionary(uniqueKeysWithValues: (4...11).map { ($0, 50) }), lock: false, steps: 16)
        #expect(p.writes == [.init(step: 12, value: 25, lock: false), .init(step: 4, value: 50, lock: false)])
        #expect(p.deletes == [6, 10])
        #expect(p.cost == 0)                                                                // two added, two freed
    }

    @Test func aRisingStrokeWritesEveryStepThatChanges() {
        let painted = [1: 20, 2: 28, 3: 36, 4: 45, 5: 52, 6: 58, 7: 62, 8: 66]
        let p = MotionPaint.plan(events: lane, id: id, base: 12, painted: painted, lock: false, steps: 16)
        // 8 changes (those at 2 and 6 rewrite records already there), then 70 put back at 9, as before the stroke
        #expect(p.writes.map(\.step) == [9, 1, 2, 3, 4, 5, 6, 7, 8])
        #expect(p.writes.first == .init(step: 9, value: 70, lock: false))
        #expect(p.deletes.isEmpty && p.cost == 7)
    }

    @Test func aStrokeMatchingWhatPlaysWritesNothing() {
        let p = MotionPaint.plan(events: lane, id: id, base: 12, painted: [7: 70, 8: 70, 9: 70], lock: false, steps: 16)
        #expect(p == .none || (p.writes.isEmpty && p.deletes.isEmpty && p.cost == 0))
    }

    @Test func aFastFingerHoldsAcrossTheStepsItSkipped() {
        // touched 0 and 3 only: 1 and 2 hold 0's value, so one change at 0 and one at 3
        let p = MotionPaint.plan(events: [], id: id, base: 12, painted: [0: 60, 3: 80], lock: false, steps: 16)
        #expect(p.writes == [.init(step: 4, value: 12, lock: false), .init(step: 0, value: 60, lock: false), .init(step: 3, value: 80, lock: false)])
        #expect(p.cost == 3)
    }

    @Test func aHoldStrokeLeavesLocksAlone() {
        let p = MotionPaint.plan(events: lane, id: id, base: 12, painted: [13: 25, 14: 25, 15: 25], lock: false, steps: 16)
        #expect(p.writes.isEmpty && p.deletes.isEmpty)                                      // 25 already holds there
    }

    @Test func aLockStrokeLocksEachStepItTouches() {
        let p = MotionPaint.plan(events: lane, id: id, base: 12, painted: [5: 85, 7: 95, 14: 90], lock: true, steps: 16)
        #expect(p.writes == [.init(step: 5, value: 85, lock: true), .init(step: 7, value: 95, lock: true)])
        #expect(p.deletes.isEmpty && p.cost == 2)
    }

    @Test func aTappedChangeHoldsOn() {
        let p = MotionPaint.plan(events: [], id: id, base: 12, painted: [4: 60], lock: false, steps: 16, restore: false)
        #expect(p.writes == [.init(step: 4, value: 60, lock: false)] && p.cost == 1)
    }

    @Test func noRestorePastTheEnd() {
        let p = MotionPaint.plan(events: [], id: id, base: 12, painted: [14: 60, 15: 60], lock: false, steps: 16)
        #expect(p.writes == [.init(step: 14, value: 60, lock: false)])
    }
}

/// A stroke sent to the pretend Skiff: what lands is what the plan said, and the 64 stop it cleanly.
@Suite(.serialized) @MainActor struct MotionPaintSessionTests {
    private func connect() async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        return (s, fake, run)
    }

    @Test func aPaintedStrokeLandsAsPlanned() async throws {
        let (s, fake, run) = try await connect()
        try await waitFor(5) { fake.watching }
        let before = s.motion[0] ?? TrackMotion()
        let p = MotionPaint.plan(events: before.events, id: 36, base: 12, painted: [3: 50, 4: 50, 5: 50], lock: false, steps: 64)
        let rc = await s.paintMotion(track: 0, id: 36, plan: p)
        #expect(rc == nil)
        let m = s.motion[0] ?? TrackMotion()
        #expect(m.value(of: 36, at: 3, base: 12).value == 50 && m.value(of: 36, at: 5, base: 12).value == 50)
        #expect(m.value(of: 36, at: 6, base: 12).value == 12)                               // put back
        #expect(fake.motion[0].contains { $0.step == 3 && $0.id == 36 && $0.value == 50 })
        run.cancel()
    }

    @Test func theSixtyFourStopAStroke() async throws {
        let (s, fake, run) = try await connect()
        try await waitFor(5) { fake.watching }
        let used = fake.motion.reduce(0) { $0 + $1.count }
        for k in 0..<(64 - used - 1) { fake.motion[3].append((k, 0, 1, false)) }          // one left
        let p = MotionPaint.plan(events: [], id: 36, base: 12, painted: [20: 30, 21: 40, 22: 50], lock: false, steps: 64)
        let rc = await s.paintMotion(track: 1, id: 36, plan: p)
        #expect(rc == .full && s.motionRefusal?.rc == .full)
        // the restore went first, so the steps after the stroke still sound as before
        #expect(fake.motion[1].contains { $0.step == 23 && $0.id == 36 && $0.value == 12 })
        run.cancel()
    }
}

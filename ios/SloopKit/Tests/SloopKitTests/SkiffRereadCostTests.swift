import Foundation
import Testing
@testable import SloopKit

/// Scott, 2026-11-11: with lots of pattern changes, the pads fell progressively behind the FM-1, and a write after stop
/// was slow. Each change of the selected track's entry or pattern re-reads its steps (SongTab's two onChange →
/// rereadSteps), one TRACK_STEP request a step, on the one-at-a-time queue the list polls also wait in.
@Suite(.serialized) @MainActor struct SkiffRereadCostTests {
    // Before the fix (2026-11-11) this was 128: two full 64-step reads. Now SongTab has one trigger, and a second reread
    // cancels the first, reading only the pattern's LENGTH steps.
    @Test func oneArrivalReadsThePatternOnce() async throws {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { run.cancel() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        try await Task.sleep(for: .seconds(1))
        let before = fake.requests.count
        // what SongTab does on one arrival: entryOn and patternOn both change, each onChange rereads
        async let a: Void = s.rereadSteps(track: s.selectedTrack)
        async let b: Void = s.rereadSteps(track: s.selectedTrack)
        _ = await (a, b)
        let sent = fake.requests[before...]
        let steps = sent.filter { $0 == SkiffCmd.trackStep }.count
        print("REREAD stepCount \(s.stepCount); one arrival sent \(steps) TRACK_STEP of \(sent.count) requests")
        let len = max(1, min(s.stepCount, s.tracks[s.selectedTrack].length))
        #expect(steps <= len + 2, "\(steps) step reads for a \(len)-step pattern")
    }
}

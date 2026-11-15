import Foundation
import Testing
@testable import SloopKit

/// Out-of-range values from the device must never index past an array (the review of 2026-11-01; on FakeSkiff since
/// SLOOP went, 2026-11-15).
@MainActor @Suite(.serialized) struct BadInputTests {
    @Test func pushesWithImpossibleValuesAreIgnoredOrClamped() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught"); run.cancel() }
        try await waitFor { if case .connected = s.status { true } else { false } }
        try await waitFor { fake.watching }
        let ids = s.ids
        try #require([ids.root, ids.scale, ids.division].allSatisfy { $0 < 128 })

        fake.push(Cmd.reload, [1, 1, 9])                       // track 9
        fake.push(Cmd.stepChanged, [70, 0])                    // step 71
        fake.push(Cmd.stepChanged, [3, 9])                     // track 9
        fake.push(Cmd.trackChanged, [0, UInt8(ids.root)] + Frame.v14(-5))
        fake.push(Cmd.trackChanged, [0, UInt8(ids.scale)] + Frame.v14(99))
        fake.push(Cmd.trackChanged, [0, UInt8(ids.division)] + Frame.v14(-1))
        try await Task.sleep(for: .milliseconds(300))

        #expect(s.trackIndices.contains(s.selectedTrack))
        #expect((0...11).contains(s.tracks[0].root))
        #expect(s.stepDuration(0) > 0)
        if case .connected = s.status {} else { Issue.record("the session dropped the connection") }
    }

    @Test func aFrameThatNeverEndsIsDropped() {
        var a = SysExAssembler()
        let out = a.feed([0xF0, 0x7D] + [UInt8](repeating: 0x10, count: 10_000))
        #expect(out.isEmpty)
        // the next good frame still comes through
        #expect(a.feed([0xF0, 0x7D, 0x46, 0x4C, 0x01, 0xF7]).count == 1)
    }
}

import Foundation
import Testing
@testable import SloopKit

@Suite(.serialized) @MainActor struct InsertDescTests {
    /// The INSERT's A B C are named by its TYPE (params.c ins_desc): changing the TYPE renames them.
    @Test func insertKnobsFollowTheType() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        session.set(track: session.selectedTrack, param: Param.insertType, to: 4)          // FUZZ
        try await waitFor { session.trackDescs[54]?.label == "DRIVE" && session.trackDescs[56]?.label == "LEVEL" }
        session.set(track: session.selectedTrack, param: Param.insertType, to: 5)          // CRUSH
        try await waitFor { session.trackDescs[54]?.label == "BITS" }
        run.cancel()
    }
}

import Foundation
import Testing
@testable import SloopKit

@Suite(.serialized) @MainActor struct RecTests {
    @Test func recTogglesWhilePolling() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        try await waitFor { session.stats.polls > 5 }
        session.toggleRec()
        try await waitFor { session.recording }
        session.toggleRec()
        try await waitFor { !session.recording }
        run.cancel()
    }
}

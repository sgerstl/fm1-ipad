import Foundation
import Testing
@testable import SloopKit

/// Lupe's own session against a real FM-1 on this Mac's USB (FM1_HW=1 only): a scope shown, what reaches
/// session.scope. Debugging the flat trace, 2026-11-07.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FM1_HW"] == "1"))
@MainActor struct ScopeHardwareProbe {
    @Test func scopeReachesTheSession() async throws {
        let s = DeviceSession()
        let run = Task { await s.run() }
        for _ in 0..<100 { if case .connected = s.status { break }; try await Task.sleep(for: .milliseconds(100)) }
        print("PROBE status \(s.status) screenLinked \(s.screenLinked) screenScope \(s.screenScope)")
        let id = UUID()
        s.showScope(id, true)
        var seen = 0, moving = 0, last: [UInt8] = []
        for _ in 0..<60 {
            try await Task.sleep(for: .milliseconds(50))
            let f = s.scope.frame
            if f != last { seen += 1; last = f; if (f.max() ?? 64) - (f.min() ?? 64) > 2 { moving += 1 } }
        }
        print("PROBE frames changed \(seen) moving \(moving) last n=\(last.count) spread=\((last.max() ?? 0) - (last.min() ?? 0))")
        s.showScope(id, false)
        run.cancel()
    }
}

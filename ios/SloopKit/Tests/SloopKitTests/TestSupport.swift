import Foundation
import Testing

@MainActor
func waitFor(_ timeout: TimeInterval = 5, sourceLocation: SourceLocation = #_sourceLocation, _ cond: () -> Bool) async throws {
    let end = Date().addingTimeInterval(timeout)
    while !cond() {
        if Date() > end { Issue.record("timed out waiting", sourceLocation: sourceLocation); return }
        try await Task.sleep(for: .milliseconds(20))
    }
}

import Foundation
import Testing
@testable import SloopKit

@MainActor
func waitFor(_ timeout: TimeInterval = 5, sourceLocation: SourceLocation = #_sourceLocation, _ cond: () -> Bool) async throws {
    let end = Date().addingTimeInterval(timeout)
    while !cond() {
        if Date() > end { Issue.record("timed out waiting", sourceLocation: sourceLocation); return }
        try await Task.sleep(for: .milliseconds(20))
    }
}

/// SLOOP-Lupe 2.8.4's package (firmware/releases/), kept as a test fixture after Lupe stopped offering it (decision 43):
/// an FM-1 can still run SLOOP, and Lupe installs Skiff-Lupe or stock V15 over it.
enum SloopPackage {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appending(path: "../../../../firmware/releases/SLOOP-Lupe-2.8.4.fwsc").standardizedFileURL
    static func load() throws -> FirmwarePackage { try FirmwarePackage(data: [UInt8](Data(contentsOf: url))) }
}

import Foundation
import Testing
@testable import SloopKit

/// The move to each firmware's own folders: every file kept, nothing overwritten, old folders gone only when empty.
struct ProjectFoldersTests {
    private func write(_ url: URL, _ text: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
    private func text(_ url: URL) -> String? { (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) } }

    @Test func oldFoldersMoveIntoEachFirmwares() throws {
        let d = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: d) }
        try write(d.appending(path: "Projects/A.json"), "a")
        try write(d.appending(path: "Projects/B.json"), "b old")
        try write(d.appending(path: "Projects/Safety copies/C.json"), "c")
        try write(d.appending(path: "SLOOP/Projects/B.json"), "b new")          // taken where it goes: the old one stays
        try write(d.appending(path: "Backups/s.json"), #"{"format":"sloop-backup"}"#)
        try write(d.appending(path: "Backups/k.json"), #"{"format":"felucca-backup"}"#)
        try write(d.appending(path: "Backups/notes.txt"), "mine")

        ProjectFolders.migrate(documents: d)

        #expect(text(d.appending(path: "SLOOP/Projects/A.json")) == "a")
        #expect(text(d.appending(path: "SLOOP/Projects/Safety copies/C.json")) == "c")
        #expect(text(d.appending(path: "SLOOP/Projects/B.json")) == "b new")
        #expect(text(d.appending(path: "Projects/B.json")) == "b old")
        #expect(!FileManager.default.fileExists(atPath: d.appending(path: "Projects/Safety copies").path))
        #expect(text(d.appending(path: "SLOOP/Backups/s.json")) != nil)
        #expect(text(d.appending(path: "Skiff/Backups/k.json")) != nil)
        #expect(text(d.appending(path: "Backups/notes.txt")) == "mine")       // not Lupe's: left where it is
        #expect(!FileManager.default.fileExists(atPath: d.appending(path: "Skiff/Projects").path))

        // a second run changes nothing; once the old folders are empty they go
        try FileManager.default.removeItem(at: d.appending(path: "Projects/B.json"))
        try FileManager.default.removeItem(at: d.appending(path: "Backups/notes.txt"))
        ProjectFolders.migrate(documents: d)
        #expect(!FileManager.default.fileExists(atPath: d.appending(path: "Projects").path))
        #expect(!FileManager.default.fileExists(atPath: d.appending(path: "Backups").path))
        #expect(text(d.appending(path: "SLOOP/Projects/A.json")) == "a")
    }
}

import Foundation

/// Whose projects: each firmware keeps its own on the iPad, in its own folder (Files › Lupe › SLOOP or Skiff), in its
/// own words. Connected to one, the other's files and name don't show (Scott, 2026-11-06).
public enum ProjectFirmware: String, Sendable {
    case sloop, skiff

    public init(_ d: FirmwareDialect) { self = d == .skiff ? .skiff : .sloop }

    /// The folder's name and the firmware's, as the user reads it.
    public var name: String { self == .sloop ? "SLOOP" : "Skiff" }

    public func projects(in documents: URL) -> URL { documents.appending(path: name).appending(path: "Projects") }
}

/// Each firmware's own folders under Lupe's documents (Files › On My iPad › Lupe): SLOOP/Projects, Skiff/Projects (each
/// with "Safety copies"), SLOOP/Backups, Skiff/Backups. Before 2026-11-06 there was one Projects folder (all SLOOP's: Skiff
/// had none on the iPad) and one Backups folder: their files move here once. A file is moved, never deleted; one whose
/// name is taken where it goes stays where it was, and an old folder goes only once it is empty.
public enum ProjectFolders {
    public static func migrate(documents: URL) {
        let fm = FileManager.default
        func move(_ from: URL, to dir: URL) {
            let to = dir.appending(path: from.lastPathComponent)
            guard !fm.fileExists(atPath: to.path) else { return }
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try? fm.moveItem(at: from, to: to)
        }
        func files(_ dir: URL) -> [URL] { (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? [] }
        func isDir(_ u: URL) -> Bool { (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        func removeIfEmpty(_ dir: URL) { if fm.fileExists(atPath: dir.path), files(dir).isEmpty { try? fm.removeItem(at: dir) } }

        let oldProjects = documents.appending(path: "Projects")
        let sloop = ProjectFirmware.sloop.projects(in: documents)
        for f in files(oldProjects) {
            if isDir(f), f.lastPathComponent == "Safety copies" {
                for c in files(f) { move(c, to: sloop.appending(path: "Safety copies")) }
                removeIfEmpty(f)
            } else {
                move(f, to: sloop)
            }
        }
        removeIfEmpty(oldProjects)

        let oldBackups = documents.appending(path: "Backups")
        for f in files(oldBackups) where !isDir(f) {
            let format = (try? Data(contentsOf: f)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["format"] as? String
            guard let format else { continue }            // not a backup Lupe wrote: left where it is
            move(f, to: documents.appending(path: DeviceBackup.folder(format: format)).appending(path: "Backups"))
        }
        removeIfEmpty(oldBackups)
    }
}

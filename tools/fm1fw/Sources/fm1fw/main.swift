// fm1fw: an FM-1's backup and a firmware install from the Mac, with SloopKit's own code. Usage: README.md, or no arguments.
import FM1FWCore
import Foundation
import SloopKit

let usage = """
usage:
  fm1fw info                                   what the FM-1 runs (INFO and the update handshake)
  fm1fw backup <dir>                           every object the firmware lists, to <dir>/Skiff/Backups/<date> <fw>.json
  fm1fw install <file.fwsc> --backup-dir <dir> [--experimental] [--backup-taken <backup.json>] [--accept-older-link] [--yes]
        checks the file and a backup from the last hour (or the one named), says what it will do;
        installs only with --yes. --experimental: accept a file Lupe doesn't pin. --accept-older-link: an unpinned
        file over the take build (screen link v7).
exit: 0 done, 1 failed, 2 refused before anything was written (it may have read INFO), 3 a dry run (install without --yes)
"""

var args = Array(CommandLine.arguments.dropFirst())
func take(_ flag: String) -> Bool { if let i = args.firstIndex(of: flag) { args.remove(at: i); return true }; return false }
func value(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    let v = args[i + 1]; args.removeSubrange(i...(i + 1)); return v
}
func url(_ p: String) -> URL { URL(fileURLWithPath: (p as NSString).expandingTildeInPath).standardizedFileURL }

/// CoreMIDI only for a command that talks to the FM-1 (the usage text opens nothing).
func tool() -> FM1FW { FM1FW(transport: { MIDITransport() }, ports: CoreMIDIUpdatePorts()) }
let code: Int32
do {
    switch args.first {
    case "info":
        try await tool().printInfo()
        code = 0
    case "backup":
        guard args.count >= 2 else { print(usage); exit(2) }
        try await tool().backup(into: url(args[1]))
        code = 0
    case "install":
        let experimental = take("--experimental"), yes = take("--yes"), older = take("--accept-older-link")
        let taken = value("--backup-taken").map(url)
        guard let dir = value("--backup-dir").map(url) ?? taken?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
              args.count >= 2 else { print(usage); exit(2) }
        var o = FM1FW.InstallOptions(backupDir: dir)
        o.experimental = experimental; o.yes = yes; o.backupTaken = taken; o.acceptOlderLink = older
        code = try await tool().install(url(args[1]), o) == nil ? 3 : 0
    default:
        print(usage)
        code = 2
    }
} catch let f as FM1FW.Failure {
    FileHandle.standardError.write(Data("fm1fw: \(f.description)\n".utf8))
    code = f.code
} catch {
    FileHandle.standardError.write(Data("fm1fw: \(error)\n".utf8))
    code = 1
}
exit(code)

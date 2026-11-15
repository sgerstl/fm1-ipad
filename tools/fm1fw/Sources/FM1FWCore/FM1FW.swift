// fm1fw's commands, with what they talk to passed in (CoreMIDI in the tool, FakeSkiff / FakeFM1 in the tests).
// Everything that touches the FM-1 is SloopKit's: FirmwareDetector (INFO, the Skiff driver), BackupCapture (the
// backup the iPad takes before an install, Skiff's felucca-backup file) and FirmwareInstaller (both update steps, the
// resume). This file only checks, orders and prints.
import Foundation
import SloopKit

public final class FM1FW: @unchecked Sendable {
    /// The editor link (INFO, BACKUP_LIST / GET): a fresh transport each time, nil when no FM-1 is plugged in.
    public let transport: () -> SysExTransport?
    /// The update ports (the installer's handshake and both steps).
    public let ports: UpdatePorts
    public var delays = FirmwareInstaller.Delays()
    public var now: () -> Date = Date.init
    public var out: (String) -> Void = { print($0); fflush(stdout) }
    /// (tests) what `info` would find, instead of asking the FM-1: FakeSkiff's screen link is internal to SloopKit.
    public var probeInfo: (() async -> Info)?

    public init(transport: @escaping () -> SysExTransport?, ports: UpdatePorts) {
        self.transport = transport
        self.ports = ports
    }

    public struct Failure: Error, CustomStringConvertible {
        public let description: String
        public let code: Int32
        public init(_ d: String, code: Int32 = 1) { description = d; self.code = code }
    }

    /// The longest a backup may be old for an install.
    public static let backupMaxAge: TimeInterval = 3600

    // MARK: info

    public struct Info: Sendable {
        public init(version: String? = nil, identity: String? = nil, screenLink: Int? = nil) {
            self.version = version; self.identity = identity; self.screenLink = screenLink
        }
        public var version: String?        // INFO's version string ("FELUCCA v2.5.1"), nil if INFO didn't answer
        public var identity: String?       // the update handshake's ("FM-1_725", "ota-FM-1_725" in update mode)
        public var screenLink: Int?        // INFO's 56 01 tag: Lupe's screen link version (6: Skiff-Lupe 2.5.1, 7: its take build)
    }

    public func info() async -> Info {
        if let p = probeInfo { return await p() }
        var i = Info()
        if let t = transport(), case .driver(let d)? = try? await FirmwareDetector.connect(t) {
            i.version = d.info.version
            i.screenLink = (d as? SkiffDriver)?.skiff.tags[0x56]?.first.map(Int.init)
            await d.close()
        }
        i.identity = await FirmwareInstaller(ports: ports, delays: delays).probe()?.text
        return i
    }

    public func printInfo() async throws {
        let i = await info()
        guard i.version != nil || i.identity != nil else { throw Failure("No FM-1 answered. Plug it into this Mac with a USB data cable and close other music apps (Lupe, Skiff's web editor).") }
        out("firmware (INFO): \(i.version ?? "no answer (not a firmware Lupe speaks, or in update mode)")")
        out("identity (update handshake): \(i.identity ?? "no answer")")
        if let l = i.screenLink { out("screen link: v\(l)\(l >= 7 ? " (the take build: FREE TAKE)" : "")") }
        if let id = i.identity, let f = LupeFirmware.matching(identity: id) { out("that identity is \(f.title)'s (a build with the same identity reads the same)") }
        if let id = i.identity, id.lowercased().hasPrefix("ota-") { out("the FM-1 is in update mode: running the same install again finishes it") }
    }

    // MARK: backup

    /// The backup, saved in `dir`/Skiff/Backups (DeviceBackup.save, as the iPad keeps it). Throws on any failure.
    @discardableResult
    public func backup(into dir: URL) async throws -> URL {
        guard let t = transport() else { throw Failure("No FM-1 found over USB-MIDI (a port named Felucca). Plug it in, close Lupe and the web editor, and try again.") }
        let outcome: FirmwareDetector.Outcome
        do { outcome = try await FirmwareDetector.connect(t) } catch { throw Failure("The FM-1 didn't answer INFO: \(error)") }
        guard case .driver(let d) = outcome else {
            if case .unknown(let info) = outcome { throw Failure("The FM-1 runs \(info.version), which Lupe can't back up.") }
            throw Failure("The FM-1 didn't answer as a firmware Lupe knows.")
        }
        out("backing up \(d.info.version)… (the FM-1 stops playing: BACKUP_LIST stops its transport)")
        let progress = Progress(out)
        let b: DeviceBackup
        do {
            b = try await BackupCapture.capture(driver: d) { done, total in progress.update(done, total) }
        } catch let e as BackupError {
            await d.close()
            throw Failure("Backup failed: \(e.description)")
        } catch {
            await d.close()
            throw Failure("Backup failed: \(error)")
        }
        await d.close()
        let url = try b.save(in: dir)
        // read it back as the install will: the same checks, from the file
        let check = try Self.readBackup(url)
        out("backup saved: \(url.path)")
        out("  \(b.objects.count) objects, \(b.byteCount) bytes, firmware \(b.firmware), every object's CRC-32 checked on reading and again from the file")
        out("  objects: " + check.objects.map { "\($0.id):\($0.size)" }.joined(separator: " "))
        return url
    }

    public struct BackupFile: Sendable {
        public let url: URL
        public let firmware: String
        public let created: Date
        public let objects: [(id: Int, size: Int)]
    }

    /// A felucca-backup file, checked: the format, every object's base64 decoding to its size and its CRC-32.
    public static func readBackup(_ url: URL) throws -> BackupFile {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure("\(url.path): not a backup file (unreadable JSON)") }
        guard file["format"] as? String == "felucca-backup" else { throw Failure("\(url.path): not a felucca-backup file") }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let fw = file["firmware"] as? String, let c = file["created"] as? String, let created = iso.date(from: c),
              let objs = file["objects"] as? [[String: Any]] else { throw Failure("\(url.path): a backup without its firmware, date or objects") }
        var list: [(id: Int, size: Int)] = []
        for o in objs {
            guard let id = o["id"] as? Int, let size = o["size"] as? Int, let crc = (o["crc"] as? NSNumber)?.uint32Value,
                  let b64 = o["data"] as? String, let bytes = Data(base64Encoded: b64) else { throw Failure("\(url.path): a damaged object entry") }
            guard bytes.count == size, CRC32.of([UInt8](bytes)) == crc else { throw Failure("\(url.path): object \(id) doesn't match its size or CRC-32") }
            list.append((id, size))
        }
        guard !list.isEmpty else { throw Failure("\(url.path): an empty backup") }
        return BackupFile(url: url, firmware: fw, created: created, objects: list)
    }

    /// The newest backup in `dir`/Skiff/Backups, if any.
    public static func newestBackup(in dir: URL) -> URL? {
        let folder = dir.appendingPathComponent("Skiff/Backups", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "json" }
            .max { (a, b) in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da < db
            }
    }

    // MARK: install

    public struct InstallOptions: Sendable {
        public var experimental = false          // accept a file Lupe doesn't pin
        public var backupTaken: URL? = nil       // the backup to rely on (else the newest in backupDir)
        public var backupDir: URL
        public var yes = false                   // without it: say what would happen and stop
        public var acceptOlderLink = false       // install an unpinned file over the take build (screen link v7+)
        public init(backupDir: URL) { self.backupDir = backupDir }
    }

    /// Checks the file and the backup, says what it will do, and (with `yes`) installs. Returns the identity the FM-1
    /// reports afterwards, or nil for a dry run.
    @discardableResult
    public func install(_ file: URL, _ o: InstallOptions) async throws -> String? {
        guard let raw = try? Data(contentsOf: file) else { throw Failure("\(file.path): can't read it") }
        let sha = LupeDigest.sha256Hex(raw)
        let pinned = LupeFirmware.allCases.first { $0.sha256 == sha }
        let pkg: FirmwarePackage
        do { pkg = try FirmwarePackage(data: [UInt8](raw), pinned: pinned) } catch { throw Failure("\(file.lastPathComponent) isn't a firmware package the installer accepts: \(error)") }
        out("file: \(file.path)")
        out("  SHA-256 \(sha)")
        out("  \(raw.count) bytes, identity \(pkg.product), \(pinned.map { "pinned in Lupe as \($0.title)" } ?? "NOT pinned in Lupe")")
        if pinned == nil, !o.experimental {
            throw Failure("This file isn't one Lupe pins. To install it anyway, add --experimental (and be sure of where it came from).", code: 2)
        }
        // the backup: one this unit's firmware wrote in the last hour, checked object by object
        guard let bURL = o.backupTaken ?? Self.newestBackup(in: o.backupDir) else {
            throw Failure("No backup found in \(o.backupDir.path)/Skiff/Backups. Take one first: fm1fw backup \(o.backupDir.path)", code: 2)
        }
        let b = try Self.readBackup(bURL)
        let age = now().timeIntervalSince(b.created)
        out("backup: \(b.url.path)")
        out("  \(b.objects.count) objects, firmware \(b.firmware), taken \(Int(age / 60)) min ago, every object checked")
        if o.backupTaken == nil, age > Self.backupMaxAge || age < -300 {
            throw Failure("That backup is \(Int(age / 60)) minutes old: take a fresh one (fm1fw backup \(o.backupDir.path)), or name one with --backup-taken.", code: 2)
        }
        // the unit now: the backup must be this firmware's (one FM-1 at a time: the backup can't name its unit)
        let now = await info()
        guard let identity = now.identity else { throw Failure("No FM-1 answered the update handshake. Plug it in and close other music apps.") }
        out("FM-1 now: \(identity)\(now.version.map { ", \($0)" } ?? "")\(now.screenLink.map { ", screen link v\($0)" } ?? "")")
        // Skiff-Lupe 2.5.1 and its take build share FM-1_725; an unpinned file can't say which it's built from. B1 is
        // built from 737e3fb (screen link v6, no FREE TAKE): over a take build it would take FREE TAKE away.
        if pinned == nil, (now.screenLink ?? 0) >= 7, !o.acceptOlderLink {
            throw Failure("The FM-1 runs the take build (screen link v\(now.screenLink!), FREE TAKE). This file isn't pinned, so fm1fw can't tell whether it has the take link; the B1 build doesn't (737e3fb, v6). Add --accept-older-link to install it anyway.", code: 2)
        }
        if let v = now.version, v != b.firmware, o.backupTaken == nil {
            throw Failure("The backup was taken from \(b.firmware), but the FM-1 runs \(v): take a backup of this unit first.", code: 2)
        }
        out("")
        out("it will: step 1, the running firmware reads the file's header and loader and restarts into the update loader;")
        out("         step 2, the loader reads all of flash.bin twice (a check, then the write) and restarts into \(pkg.product).")
        out("         About 2 minutes. Don't unplug the FM-1 or let the Mac sleep. A cut-off write is resumed (up to 5 tries),")
        out("         and if it stops anyway, the FM-1 stays in update mode: run the same command again to finish.")
        out("         Projects, presets, samples and settings aren't touched (the loader writes only the app area); the backup is there anyway.")
        guard o.yes else {
            out("")
            out("Nothing done (a dry run). Add --yes to install.")
            return nil
        }
        out("")
        let installer = FirmwareInstaller(ports: ports, delays: delays)
        var lastWrite = -1
        do {
            let back = try await installer.install(pkg) { s in
                switch s {
                case .start(let id): self.out("step 1: \(id) checks the file")
                case .check(let n): if n % 8 == 0 { self.out("  check: \(n) reads") }
                case .loader: self.out("step 1 done: waiting for the update loader")
                case .write(let p): if p / 10 != lastWrite / 10 || p == 100 { lastWrite = p; self.out("step 2: writing \(p) %") }
                case .dropped: self.out("  the loader dropped off: waiting for it to come back")
                case .resume(let n): self.out("  back: resuming (try \(n))")
                case .reboot: self.out("written: waiting for the FM-1 to restart")
                case .done(let id): self.out("done: the FM-1 reports \(id)")
                }
            }
            out("installed: \(back). Backup kept at \(b.url.path)")
            return back
        } catch let e as InstallError {
            var msg = "Install stopped: \(e.message)"
            if e.inUpdateMode { msg += "\nThe FM-1 is in update mode. Run the same command again (with --backup-taken \(b.url.path)) to finish." }
            throw Failure(msg)
        }
    }
}

/// "backup: 37 % (12,345 of 33,000 bytes)" every 10 %, then 100 %.
final class Progress: @unchecked Sendable {
    private let out: (String) -> Void
    private var last = -1
    private let lock = NSLock()
    init(_ out: @escaping (String) -> Void) { self.out = out }
    func update(_ done: Int, _ total: Int) {
        let p = total > 0 ? done * 100 / total : 100
        let say: Bool = lock.withLock { if p / 10 != last / 10 || (p == 100 && last != 100) { last = p; return true }; return false }
        if say { out("  backup: \(p) % (\(done) of \(total) bytes)") }
    }
}

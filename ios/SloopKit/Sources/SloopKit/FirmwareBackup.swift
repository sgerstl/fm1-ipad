// The backup taken before a firmware install, in each firmware's own file format so its web editor restores it:
// SLOOP's "sloop-backup" (editor.html backupCapture: BK_LIST 34 / BK_GET 35) and Felucca's and Skiff's
// "felucca-backup" (web/fm1backup.js captureBackup: BACKUP_LIST 65 / BACKUP_GET 66).
//
// What an install touches (from the sources, 2026-11-05): the loader writes only the app area [0x4000, 0x93000),
// never the head nor the store [0x97000, 0xE0000) where projects, presets and samples live (Skiff ldr_core.c
// FL_RANGE_OK and LDR_DATA_LO/HI; SLOOP's README: "SLOOP keeps projects, presets, samples and settings across
// installs"). A switch between the two firmwares keeps the bytes but not their reading: Skiff converts SLOOP's FUN
// projects on load (project.c proj_old_magic), SLOOP doesn't read Skiff's SKF projects (proj_ok wants FUN6), and the
// two keep the autosave and the FM6 patches in each other's sectors. So the backup covers every object the running
// firmware lists: the projects, the music now, the settings, the presets, the samples (and Skiff's pattern bank).
import Foundation

public struct DeviceBackup: Sendable {
    /// "sloop-backup" or "felucca-backup".
    public let format: String
    public let firmware: String
    public let created: Date
    public let objects: [(id: Int, crc: UInt32, data: [UInt8])]
    /// The file, as the firmware's web editor reads it.
    public let json: Data

    public var byteCount: Int { objects.reduce(0) { $0 + $1.data.count } }

    /// "2026-11-05 0412 SLOOP 2.8.4.json".
    public var fileName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HHmm"
        let fw = firmware.replacingOccurrences(of: "FELUCCA ", with: "").replacingOccurrences(of: "/", with: "-")
        return "\(f.string(from: created)) \(fw).json"
    }

    /// Kept in Documents/Backups, where the Files app shows it.
    public func save(in documents: URL) throws -> URL {
        let dir = documents.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try json.write(to: url, options: .atomic)
        return url
    }
}

public enum BackupError: Error, Equatable, CustomStringConvertible {
    case refused(Int)              // the device's rc
    case changed                   // an object's CRC differs from the list: the device changed during the backup
    case unreadable(String)
    case notSupported

    public var description: String {
        switch self {
        case .refused(let rc): rc == 3 ? "Stop the FM-1 playing, then try again." : "The FM-1 refused the backup (rc \(rc))."
        case .changed: "The FM-1 changed during the backup. Stop it playing and try again."
        case .unreadable(let why): "The backup couldn't be read: \(why)."
        case .notSupported: "This firmware has no backup Lupe can read."
        }
    }
}

/// One request: a command and its arguments → the reply body.
public typealias BackupRequest = @Sendable (_ cmd: UInt8, _ args: [UInt8], _ match: Int) async throws -> [UInt8]

public enum BackupCapture {
    static let sloopList: UInt8 = 34, sloopGet: UInt8 = 35
    static let feluccaList: UInt8 = 65, feluccaGet: UInt8 = 66
    static let chunk = 256

    /// Every object the running firmware lists. `skiff`: Felucca's commands and file; else SLOOP's.
    public static func capture(skiff: Bool, firmware: String, request: BackupRequest,
                               progress: @Sendable (Int, Int) -> Void = { _, _ in }) async throws -> DeviceBackup {
        let list = try await request(skiff ? feluccaList : sloopList, [], 0)
        // SLOOP: rc, count, items. Felucca: 1, rc, count, items. Each item: id, size (5 × 7 bit), CRC-32 (5 × 7 bit)
        let head = skiff ? 1 : 0
        guard list.count >= head + 2 else { throw BackupError.unreadable("a short list") }
        if skiff, list[0] != 1 { throw BackupError.unreadable("archive protocol \(list[0])") }
        if list[head] != 0 { throw BackupError.refused(Int(list[head])) }
        let count = Int(list[head + 1])
        guard list.count >= head + 2 + count * 11 else { throw BackupError.unreadable("an incomplete list") }
        var items: [(id: Int, size: Int, crc: UInt32)] = []
        for k in 0..<count {
            let p = head + 2 + k * 11
            items.append((Int(list[p]), Int(Pack7.readU35(list[(p + 1)...])), Pack7.readU35(list[(p + 6)...])))
        }
        guard items.allSatisfy({ $0.size <= 0x14000 }) else { throw BackupError.unreadable("an object too large") }
        let total = items.reduce(0) { $0 + $1.size }
        var done = 0
        var objects: [(id: Int, crc: UInt32, data: [UInt8])] = []
        for it in items {
            var data: [UInt8] = []
            data.reserveCapacity(it.size)
            while data.count < it.size {
                let n = min(chunk, it.size - data.count)
                let args = [UInt8(it.id)] + Pack7.u35(UInt32(data.count)) + [UInt8(n & 127), UInt8(n >> 7)]
                let b = try await request(skiff ? feluccaGet : sloopGet, args, 1)
                guard b.count >= 9, Int(b[0]) == it.id else { throw BackupError.unreadable("an unexpected reply") }
                if b[1] == 5 { throw BackupError.changed }
                if b[1] != 0 { throw BackupError.refused(Int(b[1])) }
                guard Int(Pack7.readU35(b[2...])) == data.count, Int(b[7]) | Int(b[8]) << 7 == n else {
                    throw BackupError.unreadable("a reply for another piece")
                }
                let piece = Pack7.decode(Array(b[9...]))
                guard piece.count >= n else { throw BackupError.unreadable("a short piece") }
                data += piece.prefix(n)
                done += n
                progress(done, total)
            }
            guard CRC32.of(data) == it.crc else { throw BackupError.changed }
            objects.append((it.id, it.crc, data))
        }
        let created = Date()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let file: [String: Any] = skiff
            ? ["format": "felucca-backup", "version": 1, "firmware": firmware, "created": iso.string(from: created),
               "objects": objects.map { ["id": $0.id, "size": $0.data.count, "crc": $0.crc, "data": Data($0.data).base64EncodedString()] }]
            : ["format": "sloop-backup", "version": 1, "firmware": firmware, "date": iso.string(from: created),
               "objects": objects.map { ["id": $0.id, "len": $0.data.count, "crc": $0.crc, "data": Data($0.data).base64EncodedString()] }]
        let json = try JSONSerialization.data(withJSONObject: file, options: [.sortedKeys])
        return DeviceBackup(format: skiff ? "felucca-backup" : "sloop-backup", firmware: firmware, created: created,
                            objects: objects, json: json)
    }

    /// The backup through a connected driver.
    public static func capture(driver: FirmwareDriver, progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }) async throws -> DeviceBackup {
        let skiff = driver is SkiffDriver
        let client: SloopClient
        if let d = driver as? SkiffDriver { client = d.client } else if let d = driver as? SloopDriver { client = d.client } else {
            throw BackupError.notSupported
        }
        return try await capture(skiff: skiff, firmware: driver.info.version, request: { cmd, args, match in
            // LIST stops the transport and snapshots: give it time, and never send it twice
            let list = cmd == sloopList || cmd == feluccaList
            return try await client.send(.raw(cmd: cmd, args: args, match: match, name: list ? "BACKUP_LIST" : "BACKUP_GET"),
                                         timeout: .milliseconds(list ? 5000 : 1500), retries: list ? 0 : 2)
        }, progress: progress)
    }
}

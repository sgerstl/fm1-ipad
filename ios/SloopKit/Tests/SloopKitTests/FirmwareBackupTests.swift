import Foundation
import Testing
@testable import SloopKit

/// The backup before an install: SLOOP's BK_LIST / BK_GET against FakeSloop, Skiff's BACKUP_LIST / GET against a
/// small responder, each written in the file format its web editor restores.
@Suite(.serialized) struct FirmwareBackupTests {
    @Test func sloopBackupHasEveryObject() async throws {
        let fake = FakeSloop(autoEdits: false)
        let client = SloopClient(transport: fake)
        await client.start()
        defer { Task { await client.close() } }
        let b = try await BackupCapture.capture(skiff: false, firmware: "FELUCCA SLOOP 2.8.4") { cmd, args, match in
            try await client.send(.raw(cmd: cmd, args: args, match: match, name: "bk"), timeout: .seconds(2))
        }
        #expect(b.format == "sloop-backup")
        #expect(b.objects.map(\.id) == [0, 1, 2, 3, 4, 5])
        #expect(b.objects[0].data.count > 1000)
        let file = try #require(try JSONSerialization.jsonObject(with: b.json) as? [String: Any])
        #expect(file["format"] as? String == "sloop-backup" && file["version"] as? Int == 1)
        let objs = try #require(file["objects"] as? [[String: Any]])
        for (o, raw) in zip(objs, b.objects) {
            let data = try #require(Data(base64Encoded: o["data"] as? String ?? ""))
            #expect(o["len"] as? Int == data.count && [UInt8](data) == raw.data)
            #expect((o["crc"] as? NSNumber)?.uint32Value == CRC32.of([UInt8](data)))
        }
        #expect(b.fileName.hasSuffix("SLOOP 2.8.4.json"))
    }

    /// Skiff's archive: 1, rc, count, then id, size, crc; GET in 256-byte pieces.
    static func skiffResponder(_ objects: [Int: [UInt8]], rcList: UInt8 = 0, changeAfter: Int? = nil) -> BackupRequest {
        final class Box: @unchecked Sendable { var gets = 0; var objects: [Int: [UInt8]] = [:] }
        let box = Box(); box.objects = objects
        return { cmd, args, _ in
            if cmd == 65 {
                var b: [UInt8] = [1, rcList, UInt8(box.objects.count)]
                for id in box.objects.keys.sorted() {
                    b += [UInt8(id)] + Pack7.u35(UInt32(box.objects[id]!.count)) + Pack7.u35(CRC32.of(box.objects[id]!))
                }
                return b
            }
            #expect(cmd == 66)
            box.gets += 1
            if let c = changeAfter, box.gets == c { box.objects[0]?[999] ^= 0xFF }
            let id = Int(args[0]), off = Int(Pack7.readU35(args[1...])), n = Int(args[6]) | Int(args[7]) << 7
            let o = box.objects[id] ?? []
            return [args[0], 0] + Pack7.u35(UInt32(off)) + [args[6], args[7]] + Pack7.encode(Array(o[off..<min(off + n, o.count)]))
        }
    }

    @Test func skiffBackupIsAFeluccaArchive() async throws {
        let objects: [Int: [UInt8]] = [0: (0..<2560).map { UInt8($0 % 251) }, 1: Array(repeating: 7, count: 656),
                                       2: [], 32: (0..<9000).map { UInt8($0 & 0xFF) }]
        let b = try await BackupCapture.capture(skiff: true, firmware: "SKIFF 2.2", request: Self.skiffResponder(objects)) { d, t in
            #expect(d <= t)
        }
        #expect(b.objects.map(\.id) == [0, 1, 2, 32])
        let file = try #require(try JSONSerialization.jsonObject(with: b.json) as? [String: Any])
        #expect(file["format"] as? String == "felucca-backup" && file["version"] as? Int == 1 && file["created"] != nil)
        let objs = try #require(file["objects"] as? [[String: Any]])
        #expect(objs.map { $0["size"] as? Int } == [2560, 656, 0, 9000])
        // fm1backup.js readBackup: the base64 is exactly 4 × ceil(size / 3) long
        for o in objs { #expect((o["data"] as? String)?.count == 4 * (((o["size"] as? Int ?? 0) + 2) / 3)) }
    }

    @Test func aChangeDuringTheBackupIsCaught() async throws {
        let objects: [Int: [UInt8]] = [0: Array(repeating: 1, count: 1000), 1: Array(repeating: 2, count: 300)]
        await #expect(throws: BackupError.changed) {
            try await BackupCapture.capture(skiff: true, firmware: "SKIFF 2.2", request: Self.skiffResponder(objects, changeAfter: 2))
        }
    }

    @Test func playingRefusesTheList() async throws {
        await #expect(throws: BackupError.refused(3)) {
            try await BackupCapture.capture(skiff: true, firmware: "SKIFF 2.2", request: Self.skiffResponder([:], rcList: 3))
        }
    }

    @Test func savedInDocumentsBackups() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let b = DeviceBackup(format: "sloop-backup", firmware: "FELUCCA SLOOP 2.8.4", created: Date(timeIntervalSince1970: 0),
                             objects: [], json: Data("{}".utf8))
        let url = try b.save(in: dir)
        #expect(url.path.contains("/SLOOP/Backups/") && FileManager.default.fileExists(atPath: url.path))
        // each firmware its own folder: Skiff's beside SLOOP's, never in it
        let k = DeviceBackup(format: "felucca-backup", firmware: "FELUCCA v2.2", created: Date(timeIntervalSince1970: 0),
                             objects: [], json: Data("{}".utf8))
        let ku = try k.save(in: dir)
        #expect(ku.path.contains("/Skiff/Backups/") && k.place(ku).hasPrefix("Skiff › Backups › "))
        try? FileManager.default.removeItem(at: dir)
    }
}

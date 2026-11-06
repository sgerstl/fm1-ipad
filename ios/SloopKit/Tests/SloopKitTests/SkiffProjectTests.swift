import Foundation
import Testing
@testable import SloopKit

/// A Skiff project in and out, against a pretend archive (BACKUP_LIST / GET / PUT as editor_backup.c answers them).
@MainActor struct SkiffProjectTests {
    /// The objects a Skiff archive lists, and what a PUT commit does with them.
    final class Archive: @unchecked Sendable {
        var objects: [Int: [UInt8]] = [:]
        var staged: (id: Int, bytes: [UInt8], len: Int)?
        var commits: [Int] = []

        func pattern(_ id: Int) -> [UInt8] {
            let c = objects[16 + id / 4] ?? []
            return c.isEmpty ? [UInt8](repeating: 0, count: 888) : Array(c[(id % 4 * 888)..<(id % 4 * 888 + 888)])
        }
        func setPattern(_ id: Int, _ r: [UInt8]) {
            var c = objects[16 + id / 4] ?? []
            if c.isEmpty { c = [UInt8](repeating: 0, count: 3552) }
            c.replaceSubrange((id % 4 * 888)..<(id % 4 * 888 + 888), with: r)
            objects[16 + id / 4] = c
        }

        var request: BackupRequest {
            { cmd, a, _ in
                switch cmd {
                case 65:
                    let ids = [0, 1, 2, 3, 4, 5] + Array(16...31)
                    return [1, 0, UInt8(ids.count)] + ids.flatMap { id -> [UInt8] in
                        let b = self.objects[id] ?? []
                        let empty = id >= 16 && b.allSatisfy { $0 == 0 }
                        return [UInt8(id)] + Pack7.u35(UInt32(empty ? 0 : b.count)) + Pack7.u35(CRC32.of(empty ? [] : b))
                    }
                case 66:
                    let id = Int(a[0]), off = Int(Pack7.readU35(a[1...])), n = Int(a[6]) | Int(a[7]) << 7
                    let b = self.objects[id] ?? []
                    return [a[0], 0] + Pack7.u35(UInt32(off)) + [a[6], a[7]] + Pack7.encode(Array(b[off..<(off + n)]))
                default:
                    let id = Int(a[1])
                    switch a[0] {
                    case 0: self.staged = (id, [], Int(Pack7.readU35(a[2...])))
                    case 1: self.staged!.bytes += Pack7.decode(Array(a[7...]))
                    default:
                        guard let s = self.staged, s.bytes.count == s.len else { return [a[0], a[1], 2] }
                        if id == 0 { guard SKF4(s.bytes) != nil else { return [a[0], a[1], 2] } }
                        self.objects[id] = s.bytes
                        self.commits.append(id)
                    }
                    return [a[0], a[1], 0]
                }
            }
        }
    }

    static func record(_ n: UInt8) -> [UInt8] { var r = [UInt8](repeating: n, count: 888); r[0] = 1; return r }

    /// The blank project with T1's entry A on pattern `a`, T2's on `b`.
    static func project(_ a: Int, _ b: Int) -> [UInt8] {
        var p = SkiffProjectData.blank.record.map { $0 }
        p[SKF4.entriesAt] = UInt8(a + 1)
        p[SKF4.entriesAt + 4 * SKF4.entries] = UInt8(b + 1)
        return p.withSealed()
    }

    @Test func blankIsASkiffProject() {
        let b = SkiffProjectData.blank
        #expect(b.project != nil && b.project!.patternIDs.isEmpty && b.project!.name.isEmpty)
    }

    @Test func savedWithItsPatternsAndOpenedWhereFree() async throws {
        let ar = Archive()
        ar.objects[0] = Self.project(5, 9)
        ar.setPattern(5, Self.record(5)); ar.setPattern(9, Self.record(9)); ar.setPattern(4, Self.record(4))
        let saved = try await SkiffProjectTransfer.read(firmware: "FELUCCA v2.2", request: ar.request)
        #expect(saved.patterns.map(\.id) == [5, 9])

        // the same pool: only the project goes back
        try await SkiffProjectTransfer.write(saved, name: "Night drive", request: ar.request)
        #expect(ar.commits == [0])
        #expect(SKF4(ar.objects[0]!)?.name == "NIGHT DRIVE")

        // pattern 5 changed on the FM-1, and a slot names the empty 0: the saved 5 goes to 1, 4 and 6 left as they were
        ar.commits = []
        ar.setPattern(5, Self.record(55))
        ar.objects[2] = Self.project(0, 9)
        try await SkiffProjectTransfer.write(saved, name: nil, request: ar.request)
        #expect(ar.commits == [16, 0])
        #expect(ar.pattern(1) == Self.record(5) && ar.pattern(5) == Self.record(55) && ar.pattern(0)[0] == 0)
        let now = try #require(SKF4(ar.objects[0]!))
        #expect(now.patternIDs == [1, 9])
        let reread = try await SkiffProjectTransfer.read(firmware: "FELUCCA v2.2", request: ar.request)
        #expect(reread.fingerprint == saved.fingerprint)
    }

    @Test func aFullPoolOpensNothing() async throws {
        let ar = Archive()
        ar.objects[0] = Self.project(5, 9)
        ar.setPattern(5, Self.record(5)); ar.setPattern(9, Self.record(9))
        let saved = try await SkiffProjectTransfer.read(firmware: "FELUCCA v2.2", request: ar.request)
        for id in 0..<64 { ar.setPattern(id, Self.record(UInt8(100 + id % 50))) }
        ar.objects[0] = SkiffProjectData.blank.record.map { $0 }
        ar.commits = []
        await #expect(throws: SkiffProjectError.poolFull(needed: 2, free: 0)) {
            try await SkiffProjectTransfer.write(saved, name: nil, request: ar.request)
        }
        #expect(ar.commits.isEmpty)
    }

    @Test func skiffNames() {
        #expect(SKF4.skiffName("Night drive é long name") == Array("NIGHT DRIVE ".utf8))
    }
}

private extension Array where Element == UInt8 {
    /// The SKF4 checksum made right.
    func withSealed() -> [UInt8] {
        var b = self
        let s = SKF4.hash(b[0..<SKF4.sumAt])
        for k in 0..<4 { b[SKF4.sumAt + k] = UInt8(s >> (8 * k) & 0xFF) }
        return b
    }
}

// A Skiff project kept on the iPad, and how it moves (qa/skiff-projects-2026-11-06): Skiff 2.x's project record (SKF4,
// project.c proj_pack4) holds no steps, its entries name patterns in the pool every project shares (bank.c). So Lupe keeps
// the record and the patterns it names, and moves them with the backup commands Skiff already has (editor_backup.c):
// BACKUP_LIST snapshots the music as object 0, GET reads it and the pool's chunks (16…31, 4 patterns each), PUT of a chunk
// writes it as a save does, PUT of object 0 loads the record as the music (no slot, no flash). No firmware patch.
import Foundation

/// Skiff's SKF4 project record: only what Lupe reads or changes (the entries' patterns, the name, the checksum).
public struct SKF4: Equatable, Sendable {
    public static let size = 2560
    static let magic: UInt32 = 0x534B_4634          // "SKF4"
    static let layout: UInt8 = 1                   // PROJ_LAYOUT4
    static let entriesAt = 10, tracks = 6, entries = 16
    static let nameLength = 12
    static let nameAt = size - 4 - nameLength, sumAt = size - 4
    /// An entry's first byte: the pattern id + 1, 0 none, 65 a REST (core.h PAT_REST).
    static let rest: UInt8 = 65

    public private(set) var bytes: [UInt8]

    public init?(_ bytes: [UInt8]) {
        guard bytes.count == Self.size, Fun6.u32(bytes, 0) == Self.magic, Fun6.u32(bytes, 4) == UInt32(Self.size),
              bytes[8] == Self.layout, Fun6.u32(bytes, Self.sumAt) == Self.hash(bytes[0..<Self.sumAt]) else { return nil }
        self.bytes = bytes
    }

    /// The pattern ids (0…63) its entries name, in entry order, each once.
    public var patternIDs: [Int] {
        var seen = Set<Int>(), out: [Int] = []
        for k in 0..<(Self.tracks * Self.entries) {
            let b = bytes[Self.entriesAt + 4 * k]
            if b >= 1, b < Self.rest, seen.insert(Int(b) - 1).inserted { out.append(Int(b) - 1) }
        }
        return out
    }

    /// The name Skiff shows (upper case, up to 12 letters); "" none.
    public var name: String {
        String(decoding: bytes[Self.nameAt..<(Self.nameAt + Self.nameLength)].prefix { $0 != 0 }, as: UTF8.self)
    }

    /// The entries renumbered (old id → new id), the name set, the checksum made right again.
    public func moved(_ map: [Int: Int], name: String?) -> SKF4 {
        var b = bytes
        for k in 0..<(Self.tracks * Self.entries) {
            let o = Self.entriesAt + 4 * k
            if b[o] >= 1, b[o] < Self.rest, let to = map[Int(b[o]) - 1] { b[o] = UInt8(to + 1) }
        }
        if let name {
            let n = Self.skiffName(name)
            for i in 0..<Self.nameLength { b[Self.nameAt + i] = i < n.count ? n[i] : 0 }
        }
        let s = Self.hash(b[0..<Self.sumAt])
        for k in 0..<4 { b[Self.sumAt + k] = UInt8(s >> (8 * k) & 0xFF) }
        return SKF4(b)!
    }

    /// A name as Skiff takes one (editor_project.c ed_proj_name_in): 32…126, upper case, 12 at most.
    public static func skiffName(_ s: String) -> [UInt8] {
        Array(s.uppercased().unicodeScalars.filter { $0.value >= 32 && $0.value <= 126 }.map { UInt8($0.value) }.prefix(nameLength))
    }

    static func hash(_ b: ArraySlice<UInt8>) -> UInt32 {     // project.c proj_hash: FNV-1a
        var s: UInt32 = 0x811C_9DC5
        for x in b { s = (s ^ UInt32(x)) &* 16_777_619 }
        return s
    }
}

/// What a Lupe Skiff project keeps: the record and the patterns its entries name, by the ids it names them with.
public struct SkiffProjectData: Codable, Equatable, Sendable {
    public var record: Data
    public var patterns: [Pattern]
    /// The firmware it was saved from ("FELUCCA v2.2").
    public var firmware: String

    public struct Pattern: Codable, Equatable, Sendable {
        public var id: Int
        public var data: Data
    }

    public init(record: [UInt8], patterns: [Int: [UInt8]], firmware: String) {
        self.record = Data(record)
        self.patterns = patterns.keys.sorted().map { Pattern(id: $0, data: Data(patterns[$0]!)) }
        self.firmware = firmware
    }

    /// A fresh start: a new unit's music (TOOLS NEW's, project.c project_new: each track's power-on sound, no
    /// patterns, no name). Captured from skiff-sim, a new unit of Skiff 2.2 (BACKUP_LIST, object 0), 2026-11-06.
    public static let blank = SkiffProjectData(record: Array(Data(base64Encoded: blankBase64, options: .ignoreUnknownCharacters)!),
                                               patterns: [:], firmware: SkiffInfo.expectedVersion)

    public var project: SKF4? { SKF4(Array(record)) }
    /// How many patterns its tracks play.
    public var patternCount: Int { patterns.count }
    /// The tracks with at least one pattern in their list.
    public var tracksUsed: Int {
        guard let p = project else { return 0 }
        return (0..<SKF4.tracks).filter { t in
            (0..<SKF4.entries).contains { e in let b = p.bytes[SKF4.entriesAt + 4 * (t * SKF4.entries + e)]; return b >= 1 && b < SKF4.rest }
        }.count
    }

    /// Equal when the music is: the record without its name and checksum, each pattern by content (not by id, so a
    /// project opened into other ids is still the same project).
    public var fingerprint: String {
        guard let p = project else { return "" }
        var b = p.bytes
        let byID = Dictionary(patterns.map { ($0.id, CRC32.of(Array($0.data))) }, uniquingKeysWith: { a, _ in a })
        var order: [Int: Int] = [:]
        for k in 0..<(SKF4.tracks * SKF4.entries) {     // ids by first use, so a renumbering reads the same
            let o = SKF4.entriesAt + 4 * k
            guard b[o] >= 1, b[o] < SKF4.rest else { continue }
            let id = Int(b[o]) - 1
            if order[id] == nil { order[id] = order.count }
            b[o] = UInt8(order[id]! + 1)
        }
        for i in SKF4.nameAt..<SKF4.size { b[i] = 0 }
        let pats = order.sorted { $0.value < $1.value }.map { String(byID[$0.key] ?? 0, radix: 16) }
        return ([String(CRC32.of(b), radix: 16)] + pats).joined(separator: "-")
    }

    private static let blankBase64 = """
        NEZLUwAKAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AAACAGNjY2NjY2MAJwAAADgAAAIAY2NjY2Nj
        YwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AAACAGNjY2NjY2MAJwAAADgAYwIAY2NjYzIyMjIACCMAAAAxGElOSVQgVk9JQ0UjHigoVVpVACcAAAA4ADICACYe
        KChjX1oAJwAAADgAUAQAHhkoKFBaVQAnAAAAOAQ3BAAoHigoY19aACcAAABQAFwCACMeKChVWlAAJwAAADgEPAIAKB4oKGNfWgAnAAAAKABcAgBjY2NjMjIy
        MgQKHjwEACkYU09GVCBQQUQgIGNjY2NjY2MAJwAAADgAAAIAY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AAACAGNjY2NjY2MAJwAAADgAAAIAY2Nj
        Y2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AGMCAGNjY2MyMjIyAAgjAAAAMRhJTklUIFZPSUNFY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AAAC
        AGNjY2NjY2MAJwAAADgAAAIAY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AAACAGNjY2NjY2MAJwAAADgAYwIAY2NjYzIyMjIACCMAAAAxGElOSVQg
        Vk9JQ0VjY2NjY2NjACcAAAA4AAACAGNjY2NjY2MAJwAAADgAAAIAY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AAACAGNjY2NjY2MAJwAAADgAAAIA
        Y2NjY2NjYwAnAAAAOABjAgBjY2NjMjIyMgAIIwAAADEYSU5JVCBWT0lDRWNjY2NjY2MAJwAAADgAAAIAY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4
        AAACAGNjY2NjY2MAJwAAADgAAAIAY2NjY2NjYwAnAAAAOAAAAgBjY2NjY2NjACcAAAA4AGMCAGNjY2MyMjIyAAgjAAAAMRhJTklUIFZPSUNFG3gAAAAAAAAA
        AQA8AEYAWgBaADwAKAA8AAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAJKoQHdUXnBAQEB8QEBAQEBAQEBCQYBAv0BAQEBAQFBCQL9UQG1PQkBA
        QEBAQGhAQUG/QEBAQEBAQEBAQEBAQEC/QL9AQL9Av0BAv0C/QEC/QL9AQL+/v7+/v7+/QECgiUBAQHxAaICAgICAgICAQEBAQEBAQEBAQEBAQICgoL9AQEBA
        QHKkWYBAQEBAQEBAQEBAQAwEAJKoQEC/QEBAQEB8QEBAQEBAQEBCQYBAv0BAQEBAQFBCQL9AfF6GQEBAQEBAQGhAQUG/QEBAQEBAQEBAQEBAQEC/QL9AQL9A
        v0BAv0C/QEC/QL9AQL+/v7+/v7+/QECgiUBAQHxAaICAgICAgICAQEBAQEBAQEBAQEBAQICgoL9AQEBAQEBAXkRAQEBAQEBAQEBAQAMAAJKoQHyaXkBAQEB8
        QEBAQEBAQEBCQYBAv0BAQEBAQFBCQL9AQGhUQkBAQEBAQGhAQUG/QEBAQEBAQEBAQEBAQEC/QL9AQL9Av0BAv0C/QEC/QL9AQL+/v7+/v7+/QECgiUBAQHxA
        aICAgICAgICAQEBAQEBAQEBAQEBAQICgoL9AQEBgQEBUQL9AQEBAQEBAQEBAQAoAAJKoQKS/pEBAQEB8QEBAQEBAQEBCQYBAv0BAQEBAQFBCQL9AQEBUQEBA
        QEBAQGhAQUG/QEBAQEBAQEBAQEBAQEC/QL9AQL9Av0BAv0C/QEC/QL9AQL+/v7+/v7+/QECgiUBAQHxAaICAgICAgICAQEBAQEBAQEBAQEBAQICgoL9AQICG
        gICkQEBAQEBAQEBAQEBAQAQAAJKoQL+/hkBAQEB8QEBAQEBAQEBCQYBAv0BAQEBAQFBCQL9AWFxkQEBAQEBAQGhAQUG/QEBAQEBAQEBAQEBAQEC/QL9AQL9A
        v0BAv0C/QEC/QL9AQL+/v7+/v7+/QECgiUBAQHxAaICAgICAgICAQEBAQEBAQEBAQEBAQICgoL9AQEBAQb9AQEBAQEBAQEBAQEBAQAoAAJKoQKS/pEBAQEB8
        QEBAQEBAQEBCQYBAv0BAQEBAQFBCQL9AQEBUQEBAQEBAQGhAQUG/QEBAQEBAQEBAQEBAQEC/QL9AQL9Av0BAv0C/QEC/QL9AQL+/v7+/v7+/QECgiUBAQHxA
        aICAgICAgICAQEBAQEBAQEBAQEBAQICgoL9AQICGgICkQEBAQEBAQEBAQEBAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAr5Bj/w==

        """
}

public enum SkiffProjectError: Error, Equatable, CustomStringConvertible {
    case playing
    case refused(object: Int, rc: Int)
    case unreadable(String)
    /// The pool hasn't room for the patterns this project brings.
    case poolFull(needed: Int, free: Int)

    public var description: String {
        switch self {
        case .playing: "the FM-1 is playing"
        case .refused(let o, let rc): "the FM-1 didn't take \(o == 0 ? "the project" : "patterns \(4 * (o - 16) + 1)–\(4 * (o - 16) + 4)") (code \(rc))"
        case .unreadable(let why): why
        case .poolFull(let n, let f):
            "the FM-1's pattern pool has \(f) free \(f == 1 ? "pattern" : "patterns") and this project brings \(n). Clear unused patterns on the FM-1 (SAVE › PATTERNS) and try again"
        }
    }
}

/// Moving one project out of the FM-1 and back in, over the backup commands (a BackupRequest, as BackupCapture's).
public enum SkiffProjectTransfer {
    static let list: UInt8 = 65, get: UInt8 = 66, put: UInt8 = 67
    static let record = 888, perChunk = 4, chunkLength = 888 * 4, poolSize = 64
    static let chunk = 256

    static func chunkObject(_ id: Int) -> Int { 16 + id / perChunk }
    static func offset(_ id: Int) -> Int { id % perChunk * record }

    /// LIST: stops the transport, writes the tracks' waiting patterns to the pool, snapshots the music as object 0.
    static func listObjects(_ request: BackupRequest) async throws -> [Int: (size: Int, crc: UInt32)] {
        let b = try await request(list, [], 0)
        guard b.count >= 3, b[0] == 1 else { throw SkiffProjectError.unreadable("an unexpected list") }
        if b[1] == 3 { throw SkiffProjectError.playing }
        guard b[1] == 0 else { throw SkiffProjectError.refused(object: 0, rc: Int(b[1])) }
        let n = Int(b[2])
        guard b.count >= 3 + 11 * n else { throw SkiffProjectError.unreadable("an incomplete list") }
        var out: [Int: (Int, UInt32)] = [:]
        for k in 0..<n {
            let p = 3 + 11 * k
            out[Int(b[p])] = (Int(Pack7.readU35(b[(p + 1)...])), Pack7.readU35(b[(p + 6)...]))
        }
        return out
    }

    static func read(_ id: Int, from: Int, count: Int, _ request: BackupRequest) async throws -> [UInt8] {
        var data: [UInt8] = []
        while data.count < count {
            let n = min(chunk, count - data.count), off = from + data.count
            let b = try await request(get, [UInt8(id)] + Pack7.u35(UInt32(off)) + [UInt8(n & 127), UInt8(n >> 7)], 1)
            guard b.count >= 9, Int(b[0]) == id else { throw SkiffProjectError.unreadable("an unexpected reply") }
            if b[1] == 3 { throw SkiffProjectError.playing }
            guard b[1] == 0 else { throw SkiffProjectError.refused(object: id, rc: Int(b[1])) }
            let piece = Pack7.decode(Array(b[9...]))
            guard Int(Pack7.readU35(b[2...])) == off, piece.count >= n else { throw SkiffProjectError.unreadable("a short piece") }
            data += piece.prefix(n)
        }
        return data
    }

    /// PUT begin, the pieces, commit. The commit's rc 0: written (object 0: loaded as the music).
    static func write(_ id: Int, _ bytes: [UInt8], _ request: BackupRequest, progress: (Int) -> Void) async throws {
        func check(_ b: [UInt8]) throws {
            guard b.count >= 3 else { throw SkiffProjectError.unreadable("an unexpected reply") }
            if b[2] == 3 { throw SkiffProjectError.playing }
            guard b[2] == 0 else { throw SkiffProjectError.refused(object: id, rc: Int(b[2])) }
        }
        try check(try await request(put, [0, UInt8(id)] + Pack7.u35(UInt32(bytes.count)) + Pack7.u35(CRC32.of(bytes)), 2))
        var off = 0
        while off < bytes.count {
            let piece = Array(bytes[off..<min(off + chunk, bytes.count)])
            try check(try await request(put, [1, UInt8(id)] + Pack7.u35(UInt32(off)) + Pack7.encode(piece), 2))
            off += piece.count
            progress(piece.count)
        }
        try check(try await request(put, [2, UInt8(id)], 2))
    }

    /// The music on the FM-1 as a project (it stops the transport, as Skiff's own save does).
    public static func read(firmware: String, request: BackupRequest) async throws -> SkiffProjectData {
        let objects = try await listObjects(request)
        guard let o = objects[0], o.size == SKF4.size else { throw SkiffProjectError.unreadable("the music isn't a Skiff 2 project") }
        let bytes = try await read(0, from: 0, count: o.size, request)
        guard CRC32.of(bytes) == o.crc else { throw SkiffProjectError.unreadable("the FM-1 changed while it was read") }
        guard let p = SKF4(bytes) else { throw SkiffProjectError.unreadable("the music isn't a Skiff 2 project") }
        var patterns: [Int: [UInt8]] = [:]
        for (c, ids) in Dictionary(grouping: p.patternIDs, by: chunkObject) {
            guard (objects[c]?.size ?? 0) > 0 else { continue }        // all empty there
            let chunk = try await read(c, from: 0, count: chunkLength, request)
            for id in ids {
                let r = Array(chunk[offset(id)..<(offset(id) + record)])
                if r[0] != 0 { patterns[id] = r }                     // (an entry on an empty pattern plays nothing)
            }
        }
        return SkiffProjectData(record: bytes, patterns: patterns, firmware: firmware)
    }

    /// Puts a project on the FM-1 as the music, named `name`: its patterns already in the pool (the same bytes, the same
    /// id) are used as they are, the others go to free ids and the entries are renumbered. Only chunks that take a pattern
    /// are written, each with its other patterns as they were. The project loads last, so a failure leaves the music.
    public static func write(_ p: SkiffProjectData, name: String?, request: BackupRequest,
                             progress: @escaping (Double) -> Void = { _ in }) async throws {
        guard let project = p.project else { throw SkiffProjectError.unreadable("not a Skiff 2 project") }
        progress(0)
        let objects = try await listObjects(request)
        let want = Dictionary(p.patterns.map { ($0.id, Array($0.data)) }, uniquingKeysWith: { a, _ in a })

        // the pool as it is, read lazily: whole chunks only where needed
        var chunks: [Int: [UInt8]] = [:]
        func chunkBytes(_ c: Int) async throws -> [UInt8] {
            if let b = chunks[c] { return b }
            let b = (objects[c]?.size ?? 0) > 0 ? try await read(c, from: 0, count: chunkLength, request) : [UInt8](repeating: 0, count: chunkLength)
            chunks[c] = b
            return b
        }
        var map: [Int: Int] = [:], missing: [Int] = []
        for id in want.keys.sorted() {
            let c = try await chunkBytes(chunkObject(id))
            if Array(c[offset(id)..<(offset(id) + record)]) == want[id] { map[id] = id } else { missing.append(id) }
        }
        var dirty = Set<Int>()
        if !missing.isEmpty {
            // free: empty in the pool and named by no entry of the music or a slot (so nothing starts playing it)
            var named = Set<Int>()
            for s in [0, 2, 3, 4, 5] where objects[s]?.size == SKF4.size {
                let e = try await read(s, from: SKF4.entriesAt, count: 4 * SKF4.tracks * SKF4.entries, request)
                for k in stride(from: 0, to: e.count, by: 4) where e[k] >= 1 && e[k] < SKF4.rest { named.insert(Int(e[k]) - 1) }
            }
            var free: [Int] = []
            for id in 0..<poolSize where !named.contains(id) && !map.values.contains(id) {
                if (objects[chunkObject(id)]?.size ?? 0) == 0 { free.append(id); continue }
                if try await chunkBytes(chunkObject(id))[offset(id)] == 0 { free.append(id) }
            }
            guard free.count >= missing.count else { throw SkiffProjectError.poolFull(needed: missing.count, free: free.count) }
            for (id, to) in zip(missing, free) {
                var c = try await chunkBytes(chunkObject(to))
                c.replaceSubrange(offset(to)..<(offset(to) + record), with: want[id]!)
                chunks[chunkObject(to)] = c
                dirty.insert(chunkObject(to))
                map[id] = to
            }
        }
        let total = Double(dirty.count * chunkLength + SKF4.size)
        var done = 0
        let step: (Int) -> Void = { n in done += n; progress(Double(done) / total) }
        for c in dirty.sorted() { try await write(c, chunks[c]!, request, progress: step) }
        try await write(0, project.moved(map, name: name).bytes, request, progress: step)
        progress(1)
    }

    /// Through a connected Skiff driver: LIST and the PUT commits get time (a stop, a flash write), and none is sent twice.
    public static func request(_ d: SkiffDriver) -> BackupRequest {
        { cmd, args, match in
            let slow = cmd == list || (cmd == put && args.first != 1)
            return try await d.request(cmd, args, match: match, cmd == list ? "BACKUP_LIST" : cmd == get ? "BACKUP_GET" : "BACKUP_PUT",
                                       timeout: .milliseconds(slow ? 5000 : 1500), retries: cmd == get ? 2 : 0)
        }
    }
}

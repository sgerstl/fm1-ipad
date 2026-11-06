import Foundation

// Skiff's SAVE pages for an editor (EDITOR_PROTOCOL.md): USER's 32 slots (UP_STORE 19, UP_ERASE 21), PATTERNS' pool
// housekeeping (POOL 78: CLEAR one, EMPTY one), PROJECT's 4 slots (PROJECT 9, PROJ_NAME 77). Every write is to flash:
// Skiff stops the transport itself where it must, and refuses (or says nothing) otherwise.

/// The FM-1's 4 project slots and the music playing (PROJ_NAME's reply).
public struct SkiffProjects: Equatable, Sendable {
    public struct Slot: Equatable, Sendable { public var used: Bool; public var name: String }
    /// The slot the music came from or was saved to (nil: neither since power on), and whether it changed since.
    public var musicSlot: Int?
    public var changed: Bool
    public var name: String
    public var slots: [Slot]

    init(_ b: [UInt8]) throws {
        var r = ByteReader(b, cmd: 77)
        _ = try r.u8(); _ = try r.u8()                       // op, rc
        let m = try r.u8()
        musicSlot = m == 127 ? nil : m
        changed = try r.u8() != 0
        name = try r.string()
        var s: [Slot] = []
        while r.remaining > 0, s.count < 4 { s.append(Slot(used: try r.u8() != 0, name: try r.string())) }
        slots = s
    }
}

extension SkiffDriver {
    /// A name as Skiff takes one: 0…12 bytes 32…126, upper case (it stores names so), then its 0.
    static func nameBytes(_ name: String) -> [UInt8] {
        Array(name.uppercased().utf8.filter { (32...126).contains($0) }.prefix(12)) + [0]
    }

    /// UP_STORE: the selected track's sound into user slot 0…31 under `name`. Returns rc (0 done).
    public func userStore(slot: Int, name: String) async throws -> Int {
        let b = try await request(19, [UInt8(slot)] + Self.nameBytes(name), match: 1, "UP_STORE", timeout: .milliseconds(1500), retries: 0)
        return Int(b.count > 1 ? b[1] : 2)
    }
    /// UP_ERASE: user slot 0…31 emptied. Returns rc (0 done).
    public func userErase(slot: Int) async throws -> Int {
        let b = try await request(21, [UInt8(slot)], match: 1, "UP_ERASE", timeout: .milliseconds(1500), retries: 0)
        return Int(b.count > 1 ? b[1] : 2)
    }

    /// POOL op 1 (CLEAR a pattern nothing uses) or 2 (EMPTY one: its steps, the entries naming it stay); stopped only.
    public func poolOp(_ op: Int, pattern p: Int) async throws -> (rc: SongRC, pool: PatternPool) {
        let b = try await request(SkiffCmd.pool, [UInt8(op), UInt8(p)], match: 1, op == 1 ? "POOL CLEAR" : "POOL EMPTY",
                                  timeout: .milliseconds(3000), retries: 0)
        guard b.count >= 2 else { throw DecodeError.short(cmd: SkiffCmd.pool) }
        let rc: SongRC = switch b[1] { case 0: .done; case 1: .empty; case 2: .inUse; case 3: .playing; default: .failed }
        return (rc, try PatternPool(b[2...]))
    }

    /// PROJ_NAME (no args): the 4 slots' names and the music's.
    public func projects() async throws -> SkiffProjects {
        try SkiffProjects(try await request(77, [], match: 0, "PROJ_NAME"))
    }
    /// PROJECT load: slot 0…3 replaces the music (and stops the transport). True when the slot held a project.
    public func projectLoad(slot: Int) async throws -> Bool {
        let b = try await request(9, [0, UInt8(slot)], match: 2, "PROJECT LOAD", timeout: .milliseconds(4000), retries: 0)
        return b.count > 2 && b[2] != 0
    }
    /// PROJ_NAME SAVE AS: the music into slot 0…3 under `name` (stopping the transport first). Returns rc (0 done).
    public func projectSaveAs(slot: Int, name: String) async throws -> Int {
        let b = try await request(77, [1, UInt8(slot)] + Self.nameBytes(name), match: 1, "PROJ_NAME SAVE AS",
                                  timeout: .milliseconds(5000), retries: 0)
        return Int(b.count > 1 ? b[1] : 2)
    }
}

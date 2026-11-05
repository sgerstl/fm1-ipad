import Foundation
import Observation

// What Skiff's EDIT engine pages edit beyond track parameters (EDITOR_PROTOCOL.md "FM6 patches (68-71)", "DRUM-X kit
// (74, 75)", "User sample mix (81)"): a track's FM6 patch, the project's DRUM-X kit, a user set's mix. Each is read
// and written whole, and none is pushed when the FM-1 changes it: read again as a page opens and as its screen moves.

/// An FM6 patch as FM6_GET sends it: 128 bytes, every one 7-bit (eng_fm6.c fm6_pack). Operator n (1…6) is the block
/// at (6 − n) × 17; the voice's fields from 102.
public struct FM6Patch: Equatable, Sendable {
    public var bytes: [UInt8]
    public init(bytes: [UInt8]) { self.bytes = bytes.count >= 128 ? Array(bytes.prefix(128)) : bytes + Array(repeating: 0, count: 128 - bytes.count) }

    public enum Op: Int, CaseIterable, Sendable {
        case r1, r2, r3, r4, l1, l2, l3, l4, breakPoint, leftDepth, rightDepth, leftCurve, rightCurve, rateScale, detune
        case ampMod, velocity, output, mode, coarse, fine
        /// Its range (eng_fm6.c fm6_max).
        public var max: Int {
            switch self {
            case .leftCurve, .rightCurve, .ampMod: 3
            case .rateScale, .velocity: 7
            case .detune: 14
            case .mode: 1
            case .coarse: 31
            default: 99
            }
        }
    }

    public enum Voice: Int, CaseIterable, Sendable {
        case pr1, pr2, pr3, pr4, pl1, pl2, pl3, pl4, algorithm, feedback, keySync, lfoSpeed, lfoDelay, pitchDepth, ampDepth
        case lfoKeySync, lfoWave, pitchSens, transpose
        public var max: Int {
            switch self {
            case .algorithm: 31
            case .feedback, .pitchSens: 7
            case .keySync, .lfoKeySync: 1
            case .lfoWave: 5
            case .transpose: 48
            default: 99
            }
        }
    }

    /// Where a field is: its byte, and the bits within it (shift, width).
    private static func place(_ f: Op) -> (Int, Int, Int) {
        switch f {
        case .r1, .r2, .r3, .r4, .l1, .l2, .l3, .l4: (f.rawValue, 0, 7)
        case .breakPoint: (8, 0, 7)
        case .leftDepth: (9, 0, 7)
        case .rightDepth: (10, 0, 7)
        case .leftCurve: (11, 0, 2)
        case .rightCurve: (11, 2, 2)
        case .rateScale: (12, 0, 3)
        case .detune: (12, 3, 4)
        case .ampMod: (13, 0, 2)
        case .velocity: (13, 2, 3)
        case .output: (14, 0, 7)
        case .mode: (15, 0, 1)
        case .coarse: (15, 1, 5)
        case .fine: (16, 0, 7)
        }
    }
    private static func place(_ f: Voice) -> (Int, Int, Int) {
        switch f {
        case .pr1, .pr2, .pr3, .pr4, .pl1, .pl2, .pl3, .pl4: (102 + f.rawValue, 0, 7)
        case .algorithm: (110, 0, 5)
        case .feedback: (111, 0, 3)
        case .keySync: (111, 3, 1)
        case .lfoSpeed: (112, 0, 7)
        case .lfoDelay: (113, 0, 7)
        case .pitchDepth: (114, 0, 7)
        case .ampDepth: (115, 0, 7)
        case .lfoKeySync: (116, 0, 1)
        case .lfoWave: (116, 1, 3)
        case .pitchSens: (116, 4, 3)
        case .transpose: (117, 0, 7)
        }
    }
    private func get(_ p: (Int, Int, Int)) -> Int { Int(bytes[p.0]) >> p.1 & (1 << p.2 - 1) }
    private mutating func put(_ p: (Int, Int, Int), _ v: Int, max: Int) {
        let m = (1 << p.2 - 1) << p.1
        bytes[p.0] = UInt8((Int(bytes[p.0]) & ~m | (Swift.min(Swift.max(v, 0), max) << p.1) & m) & 127)
    }

    public func op(_ n: Int, _ f: Op) -> Int {
        let (b, s, w) = Self.place(f)
        return get(((6 - n) * 17 + b, s, w))
    }
    public mutating func setOp(_ n: Int, _ f: Op, _ v: Int) {
        let (b, s, w) = Self.place(f)
        put(((6 - n) * 17 + b, s, w), v, max: f.max)
    }
    public subscript(f: Voice) -> Int {
        get { get(Self.place(f)) }
        set { put(Self.place(f), newValue, max: f.max) }
    }
    public var name: String {
        String(bytes: bytes[118..<128].map { (32...126).contains($0) ? $0 : 32 }, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}

/// One sound of the DRUM-X kit (KIT_GET 74): its mode and the five values at A and B (PITCH, P MOD, DECAY, NOISE,
/// COLOR), between which a track's MORPH blends. One kit per project, shared by every DRUM-X track.
public struct DXLane: Equatable, Sendable {
    public var lane: Int
    public var wave = 0, filter = 0, snap = 0, pitchShape = 0, drive = 0
    public var a = [Int](repeating: 0, count: 5), b = [Int](repeating: 0, count: 5)
    public static let names = ["PITCH", "P MOD", "DECAY", "NOISE", "COLOR"]

    public init(lane: Int) { self.lane = lane }
    public init?(_ r: [UInt8]) {
        guard r.count >= 16, r[0] < 8 else { return nil }
        lane = Int(r[0]); wave = Int(r[1]); filter = Int(r[2]); snap = Int(r[3]); pitchShape = Int(r[4]); drive = Int(r[5])
        a = r[6..<11].map(Int.init); b = r[11..<16].map(Int.init)
    }
    /// KIT_PUT's 16 bytes, every value in its range (one out of range and Skiff doesn't answer).
    public var bytes: [UInt8] {
        func c(_ v: Int, _ hi: Int) -> UInt8 { UInt8(min(max(v, 0), hi)) }
        return [c(lane, 7), c(wave, 3), c(filter, 2), c(snap, 1), c(pitchShape, 3), c(drive, 1)] + a.map { c($0, 127) } + b.map { c($0, 127) }
    }
}

/// A user sample set's mix (SMP_MIX 81): each sound's key range, LEVEL, REVERB and DELAY.
public struct SampleMix: Equatable, Sendable {
    public var slot: Int
    /// 0 fine, 1 an empty slot (nothing set), 2 set but not kept (the sample fills the slot's last sector).
    public var rc: Int
    public var zones: [ClosedRange<Int>]
    public var level: [Int], reverb: [Int], delay: [Int]

    public init?(_ r: [UInt8]) {
        guard r.count >= 3 else { return nil }
        let nz = Int(r[2])
        guard r.count >= 3 + nz * 2 + 48 else { return nil }
        slot = Int(r[0]); rc = Int(r[1])
        zones = (0..<nz).map { k in Int(r[3 + 2 * k])...max(Int(r[3 + 2 * k]), Int(r[4 + 2 * k])) }
        let v = r[(3 + nz * 2)...].map(Int.init)
        level = Array(v[0..<16]); reverb = Array(v[16..<32]); delay = Array(v[32..<48])
    }
    var values: [UInt8] { (level + reverb + delay).map { UInt8(min(max($0, 0), 127)) } }
}

extension SkiffCmd {
    static let fm6Get: UInt8 = 68, fm6Put: UInt8 = 69, kitGet: UInt8 = 74, kitPut: UInt8 = 75, sampleMix: UInt8 = 81
}

extension SkiffDriver {
    /// FM6_GET: a track's own patch (target 0). nil when Skiff has none to give (rc ≠ 0).
    public func fm6Patch(track: Int) async throws -> FM6Patch? {
        let r = try await request(SkiffCmd.fm6Get, [0, UInt8(track)], match: 2, "FM6_GET", timeout: .milliseconds(500))
        guard r.count >= 3 + 128, r[2] == 0 else { return nil }
        return FM6Patch(bytes: Array(r[3..<131]))
    }
    /// FM6_PUT to a track: Skiff clamps it, plays it at once and sets the track's PATCH (OWN, or F n when it's a
    /// factory patch). Returns the rc (0 done).
    @discardableResult
    public func putFM6Patch(track: Int, _ p: FM6Patch) async throws -> Int {
        let r = try await request(SkiffCmd.fm6Put, [0, UInt8(track)] + p.bytes.map { $0 & 127 }, match: 2, "FM6_PUT",
                                  timeout: .milliseconds(500), retries: 0)
        return r.count >= 3 ? Int(r[2]) : 1
    }
    public func kitLane(_ lane: Int) async throws -> DXLane? {
        DXLane(try await request(SkiffCmd.kitGet, [UInt8(lane & 7)], match: 1, "KIT_GET"))
    }
    public func putKitLane(_ l: DXLane) async throws -> DXLane? {
        DXLane(try await request(SkiffCmd.kitPut, l.bytes, match: 1, "KIT_PUT", retries: 0))
    }
    public func sampleMix(slot: Int) async throws -> SampleMix? {
        SampleMix(try await request(SkiffCmd.sampleMix, [UInt8(slot)], match: 1, "SMP_MIX"))
    }
    public func putSampleMix(_ m: SampleMix) async throws -> SampleMix? {
        SampleMix(try await request(SkiffCmd.sampleMix, [UInt8(m.slot)] + m.values, match: 1, "SMP_MIX SET", retries: 0))
    }
}

/// The patches, the kit and the mixes as the EDIT pages show them: read when a page opens or the FM-1's screen moves,
/// edited at once here and sent one write at a time (a knob drag sends its latest value when the write before is
/// answered). The session makes one per Skiff connection.
@MainActor @Observable
public final class SkiffEditStore {
    public private(set) var patches: [Int: FM6Patch] = [:]
    public private(set) var kit: [Int: DXLane] = [:]
    public private(set) var mixes: [Int: SampleMix] = [:]
    @ObservationIgnored private var driver: SkiffDriver?
    @ObservationIgnored private var sending: Set<String> = []
    @ObservationIgnored private var pending: [String: () async -> Void] = [:]
    @ObservationIgnored private var lastEdit: [String: Date] = [:]
    /// After a patch is written: the track's PATCH parameter may have moved (OWN, or F n).
    @ObservationIgnored var patchWritten: (Int) async -> Void = { _ in }

    init(driver: SkiffDriver) { self.driver = driver }
    func attach(_ d: SkiffDriver) { driver = d }

    /// Edited here in the last second: a read doesn't overwrite what's still being sent.
    private func fresh(_ key: String) -> Bool { Date.now.timeIntervalSince(lastEdit[key] ?? .distantPast) < 1 || sending.contains(key) }

    public func readPatch(track t: Int) async {
        guard let d = driver, let p = try? await d.fm6Patch(track: t), !fresh("p\(t)") else { return }
        if patches[t] != p { patches[t] = p }
    }
    public func readKit(lane l: Int) async {
        guard let d = driver, let k = try? await d.kitLane(l), !fresh("k\(l)") else { return }
        if kit[l] != k { kit[l] = k }
    }
    public func readMix(slot s: Int) async {
        guard let d = driver, let m = try? await d.sampleMix(slot: s), !fresh("m\(s)") else { return }
        if mixes[s] != m { mixes[s] = m }
    }

    public func editPatch(track t: Int, _ change: (inout FM6Patch) -> Void) {
        guard var p = patches[t] else { return }
        change(&p)
        guard p != patches[t] else { return }
        patches[t] = p
        send("p\(t)") { [weak self] in
            guard let self, let d = self.driver, let now = self.patches[t] else { return }
            _ = try? await d.putFM6Patch(track: t, now)
            await self.patchWritten(t)
        }
    }
    public func editKit(lane l: Int, _ change: (inout DXLane) -> Void) {
        guard var k = kit[l] else { return }
        change(&k)
        guard k != kit[l] else { return }
        kit[l] = k
        send("k\(l)") { [weak self] in
            guard let self, let d = self.driver, let now = self.kit[l] else { return }
            _ = try? await d.putKitLane(now)
        }
    }
    public func editMix(slot s: Int, _ change: (inout SampleMix) -> Void) {
        guard var m = mixes[s] else { return }
        change(&m)
        guard m != mixes[s] else { return }
        mixes[s] = m
        send("m\(s)") { [weak self] in
            guard let self, let d = self.driver, let now = self.mixes[s] else { return }
            _ = try? await d.putSampleMix(now)
        }
    }

    /// One write at a time per thing; the latest waits while one is out (it sends what's current when it goes).
    private func send(_ key: String, _ write: @escaping () async -> Void) {
        lastEdit[key] = .now
        guard !sending.contains(key) else { pending[key] = write; return }
        sending.insert(key)
        Task {
            await write()
            while let next = pending.removeValue(forKey: key) { await next() }
            sending.remove(key)
            lastEdit[key] = .now
        }
    }
}

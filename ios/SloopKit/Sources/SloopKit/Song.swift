// The song: four sections A–D, the order they play in, chains, loop / song mode, SONG REC
import Foundation

// (EDITOR_PROTOCOL.md v6 backup, v12 LIVE; SLOOP GUIDE §14).

/// SLOOP's 7-bit packing: groups of up to 7 bytes, each preceded by a byte holding their top bits
/// (bit j = bit 7 of byte j).
public enum Pack7 {
    public static func encode(_ data: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var i = 0
        while i < data.count {
            let group = Array(data[i..<min(i + 7, data.count)])
            var msb: UInt8 = 0
            for (j, b) in group.enumerated() where b & 0x80 != 0 { msb |= 1 << UInt8(j) }
            out.append(msb)
            out += group.map { $0 & 0x7F }
            i += 7
        }
        return out
    }

    public static func decode(_ data: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var i = 0
        while i < data.count {
            let msb = data[i]
            let group = data[(i + 1)..<min(i + 8, data.count)]
            for (j, b) in group.enumerated() { out.append(b | ((msb >> UInt8(j)) & 1) << 7) }
            i += 8
        }
        return out
    }

    /// A 35-bit number as 5 × 7 bits, LSB first (backup offsets, lengths, CRCs).
    public static func u35(_ v: UInt32) -> [UInt8] { (0..<5).map { UInt8((UInt64(v) >> (7 * UInt64($0))) & 0x7F) } }
    public static func readU35(_ b: ArraySlice<UInt8>) -> UInt32 {
        b.prefix(5).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (7 * UInt32($1.offset)) }
    }
}

/// CRC-32 as zlib computes it (the backup objects' checksum).
public enum CRC32 {
    static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }
    public static func of(_ data: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

/// The song order (firmware arranger.h arr_config_t), bytes 48..83 of the settings object (backup
/// object 1, magic "PER3"): up to 16 steps of a section (0..3 = A..D) and a length in bars (1..64).
public struct SongOrder: Equatable, Sendable {
    public struct Step: Equatable, Sendable, Identifiable {
        public var section: Int, bars: Int
        public var id = UUID()
        public init(section: Int, bars: Int) { self.section = section; self.bars = bars }
        public static func == (a: Step, b: Step) -> Bool { a.section == b.section && a.bars == b.bars }
    }
    public var steps: [Step]
    public var loop: Bool                 // the song plays round and round (else it stops at the end)

    public static let offset = 48, size = 36, maxSteps = 16
    public static let standard = SongOrder(steps: (0..<4).map { Step(section: $0, bars: 4) }, loop: false)

    public init(steps: [Step], loop: Bool) { self.steps = steps; self.loop = loop }

    /// Reads it out of the settings object; nil if the object isn't SLOOP's settings (magic "PER3",
    /// stored little-endian, so the bytes read "3REP").
    public init?(settings s: [UInt8]) {
        guard s.count >= Self.offset + Self.size, Array(s.prefix(4)) == Array("3REP".utf8) else { return nil }
        let b = Array(s[Self.offset..<(Self.offset + Self.size)])
        let n = Int(b[0])
        guard (1...Self.maxSteps).contains(n) else { return nil }
        loop = b[1] != 0
        steps = (0..<n).map { k in Step(section: Int(b[4 + 2 * k]) & 3, bars: max(1, min(64, Int(b[5 + 2 * k])))) }
    }

    /// The settings object with this order written into it (every other byte kept).
    public func written(into settings: [UInt8]) -> [UInt8] {
        var s = settings
        guard s.count >= Self.offset + Self.size else { return s }
        let n = max(1, min(Self.maxSteps, steps.count))
        s[Self.offset] = UInt8(n)
        s[Self.offset + 1] = loop ? 1 : 0
        for k in 0..<Self.maxSteps {
            let step = k < n ? steps[k] : Step(section: 0, bars: 4)
            s[Self.offset + 4 + 2 * k] = UInt8(step.section & 3)
            s[Self.offset + 5 + 2 * k] = UInt8(max(1, min(64, step.bars)))
        }
        return s
    }

    public var totalBars: Int { steps.reduce(0) { $0 + $1.bars } }
}

/// What LIVE says about the song (firmware editor_live.c), beyond the transport.
public struct SongState: Equatable, Sendable {
    public var songMode = false           // PLAY plays the song, not the loop
    public var songPlaying = false
    public var songRecording = false      // SONG REC
    public var fillNow = false, fillNextBar = false
    public var sectionPlaying: Int?       // 0..3
    public var sectionQueued: Int?        // asked for: starts on the next bar
    public var chainLength = 0, chainIndex = 0
    public var songStep = 0, songSteps = 0, songBar = 0, songStepBars = 0
    public var sectionsStored = 0         // bit per section
    public init() {}
    public func stored(_ k: Int) -> Bool { sectionsStored >> k & 1 == 1 }
}

extension LiveState {
    /// The song half of LIVE's reply, from the same body.
    public static func song(_ body: [UInt8]) -> SongState? {
        guard body.count >= 20 else { return nil }
        var s = SongState()
        let f = Int(body[1])
        s.songMode = f & 4 != 0; s.songPlaying = f & 8 != 0; s.fillNow = f & 16 != 0; s.fillNextBar = f & 32 != 0
        s.songRecording = f & 64 != 0
        s.sectionPlaying = body[5] == 0 ? nil : Int(body[5]) - 1
        s.sectionQueued = body[6] == 0 ? nil : Int(body[6]) - 1
        s.chainLength = Int(body[7]); s.chainIndex = Int(body[8])
        s.songStep = Int(body[15]); s.songSteps = Int(body[16]); s.songBar = Int(body[17]); s.songStepBars = Int(body[18])
        s.sectionsStored = Int(body[19])
        return s
    }
}

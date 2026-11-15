// The editor protocol's 7-bit packing and the backup objects' CRC (Felucca's, as Skiff keeps them).
import Foundation

/// The 7-bit packing: groups of up to 7 bytes, each preceded by a byte holding their top bits
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

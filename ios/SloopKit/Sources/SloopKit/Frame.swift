// SLOOP's editor protocol framing: F0 7D 46 4C <cmd> <args...> F7 (vendor/sloop-2.8.4/EDITOR_PROTOCOL.md).
import Foundation


public enum Frame {
    public static let header: [UInt8] = [0xF0, 0x7D, 0x46, 0x4C]

    public static func encode(_ cmd: UInt8, _ args: [UInt8] = []) -> [UInt8] {
        header + [cmd] + args.map { $0 & 0x7F } + [0xF7]
    }

    /// The command and the bytes between it and F7, or nil for any other SysEx.
    public static func decode(_ bytes: [UInt8]) -> (cmd: UInt8, body: [UInt8])? {
        guard bytes.count >= 6, Array(bytes.prefix(4)) == header, bytes.last == 0xF7 else { return nil }
        return (bytes[4], Array(bytes[5..<(bytes.count - 1)]))
    }

    /// A value as two 7-bit bytes, LSB first, offset by 8192.
    public static func v14(_ v: Int) -> [UInt8] {
        let u = max(-8192, min(8191, v)) + 8192
        return [UInt8(u & 0x7F), UInt8((u >> 7) & 0x7F)]
    }
}

/// Collects MIDI bytes into whole SysEx frames. Real-time bytes (F8 and up) may land inside a frame
/// and are skipped; a new F0 drops an unfinished frame; anything outside a frame is ignored.
public struct SysExAssembler {
    private var partial: [UInt8] = []
    private var inFrame = false
    public init() {}

    public mutating func feed(_ bytes: some Sequence<UInt8>) -> [[UInt8]] {
        var out: [[UInt8]] = []
        for b in bytes {
            if b >= 0xF8 { continue }
            if b == 0xF0 { partial = [b]; inFrame = true; continue }
            guard inFrame else { continue }
            if b == 0xF7 { partial.append(b); out.append(partial); partial = []; inFrame = false }
            else if b & 0x80 != 0 { partial = []; inFrame = false }   // a status byte ends a broken frame
            else { partial.append(b) }
        }
        return out
    }
}

public enum DecodeError: Error, Equatable {
    case short(cmd: UInt8)
    case unexpected(String)
}

/// Reads a reply body. Running off the end throws, so a short frame never decodes into zeros.
public struct ByteReader {
    public let bytes: [UInt8]
    public private(set) var index = 0
    let cmd: UInt8
    public init(_ bytes: [UInt8], cmd: UInt8 = 0) { self.bytes = bytes; self.cmd = cmd }

    public var remaining: Int { bytes.count - index }

    public mutating func u8() throws -> Int {
        guard index < bytes.count else { throw DecodeError.short(cmd: cmd) }
        defer { index += 1 }
        return Int(bytes[index])
    }

    public mutating func v14() throws -> Int {
        let lo = try u8(), hi = try u8()
        return (lo | hi << 7) - 8192
    }

    /// 7-bit groups, LSB first (DRUM_STEP's 3- and 5-byte fields).
    public mutating func bits(_ count: Int) throws -> UInt64 {
        var v: UInt64 = 0
        for k in 0..<count { v |= UInt64(try u8()) << (7 * UInt64(k)) }
        return v
    }

    public mutating func string() throws -> String {
        var s: [UInt8] = []
        while true {
            let b = try u8()
            if b == 0 { break }
            s.append(UInt8(b))
        }
        return String(decoding: s, as: UTF8.self)
    }
}

public func hexString(_ b: [UInt8]) -> String {
    b.map { String(format: "%02X", $0) }.joined(separator: " ")
}

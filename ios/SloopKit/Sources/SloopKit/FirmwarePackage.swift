// FM-1 .fwsc packages: the identity, the logical image the device reads during an update, and the files' CRCs.
// After Skiff's web/fm1pkg.js and tools/fm1_install.py, and SLOOP's package_damage (GPL-3.0, Leo Kuroshita).
import CryptoKit
import Foundation

/// The firmware files Jib carries, exactly as tested. Each is pinned by its SHA-256: a file that doesn't
/// match is never installed (docs: FIRMWARE.md).
public enum BundledFirmware: String, CaseIterable, Identifiable, Sendable {
    case skiff = "skiff-2.2"
    case sloop = "sloop-2.8.4-screen-link"

    public var id: String { rawValue }
    /// What the app shows.
    public var title: String { self == .skiff ? "Skiff 2.2" : "SLOOP 2.8.4" }
    public var detail: String {
        self == .skiff ? "Six tracks, songs and Arrange. Built from Skiff v2.2."
                       : "Three tracks and drums, with Jib's screen link. SLOOP 2.8.4 plus a 47-line patch."
    }
    /// The package's identity, as the device reports it once installed (and the loader's, with "ota-").
    public var product: String { self == .skiff ? "FM-1_722" : "FM-1_900" }
    public var sha256: String {
        self == .skiff ? "d0013c4f1a60bc2116178c72c60eacd3d8464cbfa40dbbb7f48ba790912d8603"
                       : "97ee40fcd18de2c39e175fa825af05b787a6ea06e846ea260db2eeede74f9110"
    }
    public var size: Int { self == .skiff ? 610_429 : 610_052 }
    /// Where its source is offered (GPL-3.0).
    public var source: String {
        self == .skiff ? "github.com/illuminus5/skiff, tag v2.2"
                       : "github.com/isod89/sloop-fm1, tag v2.8.4, plus sloop/0001-screen-link.patch in Jib's repository"
    }

    /// The firmware a running FM-1 or its update loader reports, when it's one of these.
    public static func matching(identity text: String) -> BundledFirmware? {
        let t = text.hasPrefix("ota-") ? String(text.dropFirst(4)) : text
        return allCases.first { $0.product == t }
    }

    public var url: URL? { Bundle.module.url(forResource: rawValue, withExtension: "fwsc", subdirectory: "Firmware") }

    /// The bundled file, checked against its pin and parsed.
    public func load() throws -> FirmwarePackage {
        guard let url, let data = try? Data(contentsOf: url) else { throw PackageError.missing(rawValue) }
        return try FirmwarePackage(data: [UInt8](data), pinned: self)
    }
}

public enum PackageError: Error, Equatable, CustomStringConvertible {
    case missing(String)
    case hashMismatch(expected: String, found: String)
    case wrongIdentity(expected: String, found: String)
    case notFM1(String)
    case noLoader
    case damaged(String)

    public var description: String {
        switch self {
        case .missing(let n): "The firmware file \(n) is missing from the app."
        case .hashMismatch: "The firmware file isn't the one Jib was tested with (its SHA-256 differs). Nothing was sent."
        case .wrongIdentity(let e, let f): "The firmware file says it is \(f), not \(e). Nothing was sent."
        case .notFM1(let p): "This isn't an FM-1 firmware package (identity “\(p)”)."
        case .noLoader: "This package has no Felucca update loader. Nothing was sent."
        case .damaged(let why): "The firmware file is damaged (\(why)). Nothing was sent."
        }
    }
}

/// A parsed package: its identity and the logical image the device reads (cmd 0x30) during both steps.
public struct FirmwarePackage: Sendable {
    public let product: String
    public let sha256: String
    public let image: [UInt8]
    /// flash.bin in the image (offset, size): the write's progress.
    public let flashSpan: (off: Int, size: Int)?

    static let blocks = 20, blk = 0x30, keep = 0x2F, maxBlocks = 64
    static let loaderMark = Array("FELUCCA-LOADER-1".utf8)

    /// A package checked as SLOOP's installer checks it: an FM-1 identity, Felucca's update loader, an intact header,
    /// file list and files. With `pinned`, the bytes must also be exactly that file.
    public init(data: [UInt8], pinned: BundledFirmware? = nil) throws {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let p = pinned, digest != p.sha256 { throw PackageError.hashMismatch(expected: p.sha256, found: digest) }
        let product = try Self.productOf(data)
        guard product.range(of: #"^FM-1_\d+$"#, options: .regularExpression) != nil else { throw PackageError.notFM1(product) }
        if let p = pinned, product != p.product { throw PackageError.wrongIdentity(expected: p.product, found: product) }
        guard Self.contains(data, Self.loaderMark) else { throw PackageError.noLoader }
        let image = Self.logicalImage(data)
        if let bad = Self.damage(image) { throw PackageError.damaged(bad) }
        self.product = product
        self.sha256 = digest
        self.image = image
        self.flashSpan = Self.flashSpan(image)
    }

    // MARK: The format

    /// CRC-16/XMODEM, as the package and the device use.
    public static func crc16(_ d: some Collection<UInt8>, _ start: UInt16 = 0) -> UInt16 {
        var c = start
        for b in d {
            c ^= UInt16(b) << 8
            for _ in 0..<8 { c = c & 0x8000 != 0 ? (c << 1) ^ 0x1021 : c << 1 }
        }
        return c
    }

    /// JieLi's ENC stream cipher, key 0xFFFF (its own inverse): the UFW header and entries.
    public static func jlEnc(_ d: some Collection<UInt8>) -> [UInt8] {
        var key: UInt16 = 0xFFFF
        return d.map { b in
            defer { key = (key << 1) ^ (key & 0x8000 != 0 ? 0x1021 : 0) }
            return b ^ UInt8(key & 0xFF)
        }
    }

    static func u16(_ b: [UInt8], _ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
    static func u32(_ b: [UInt8], _ o: Int) -> Int { u16(b, o) | u16(b, o + 2) << 16 }

    /// The package identity ("FM-1_722"): one marker byte after each of the first 20 blocks.
    public static func productOf(_ raw: [UInt8]) throws -> String {
        guard raw.count >= blocks * blk else { throw PackageError.notFM1("too short") }
        var s = ""
        for i in 0..<blocks {
            let m = raw[i * blk + keep]
            if m != 0x7D { s.unicodeScalars.append(Unicode.Scalar(m &- UInt8(i) &- 1)) }
        }
        return s
    }

    /// Interleave blocks: 20, then more while the marker is the unused 0x7D.
    static func blockCount(_ raw: [UInt8]) -> Int {
        var n = blocks
        while n < maxBlocks, (n + 1) * blk <= raw.count, raw[n * blk + keep] == 0x7D { n += 1 }
        return n
    }

    static func deinterleave(_ raw: [UInt8], _ n: Int) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(raw.count - n)
        for i in 0..<n { out += raw[(i * blk)..<(i * blk + keep)] }
        out += raw[(n * blk)...]
        return out
    }

    /// The image the device addresses: the package without the marker bytes (20 blocks, or the detected count
    /// when the files' CRCs agree).
    public static func logicalImage(_ raw: [UInt8]) -> [UInt8] {
        let n = blockCount(raw)
        if n != blocks {
            let img = deinterleave(raw, n)
            if damage(img) == nil || damage(deinterleave(raw, blocks)) != nil { return img }
        }
        return deinterleave(raw, blocks)
    }

    /// What is wrong with the image (header, file list, each file's CRC), or nil. The device checks only the loader
    /// before it rewrites the firmware, so a damaged file is caught here (SLOOP's package_damage).
    public static func damage(_ image: [UInt8]) -> String? {
        guard image.count >= 0x40 else { return "too short" }
        let hdr = jlEnc(image[0..<0x40])
        guard crc16(hdr[2..<0x40]) == u16(hdr, 0) else { return "header CRC" }
        let count = u16(hdr, 8)
        guard (1...8).contains(count), image.count >= 0x40 + 0x50 * count else { return "file list" }
        let list = Array(image[0x40..<(0x40 + 0x50 * count)])
        guard Int(crc16(list)) == u16(hdr, 2) else { return "file list CRC" }
        for i in 0..<count {
            let e = jlEnc(list[(i * 0x50)..<((i + 1) * 0x50)])
            let off = u32(e, 8), size = u32(e, 12)
            let name = String(decoding: e[0x40..<0x50].prefix { $0 != 0 }, as: UTF8.self)
            guard off + size <= image.count else { return "\(name): cut short" }
            guard Int(crc16(image[off..<(off + size)])) == u16(e, 4) else { return "\(name): CRC" }
        }
        return nil
    }

    /// Where flash.bin (entry type 0) lies in a logical image, or nil.
    static func flashSpan(_ image: [UInt8]) -> (off: Int, size: Int)? {
        guard image.count >= 0x40 else { return nil }
        let count = u16(jlEnc(image[0..<0x40]), 8)
        for i in 0..<min(count, 8) where 0x90 + i * 0x50 <= image.count {
            let e = jlEnc(image[(0x40 + i * 0x50)..<(0x90 + i * 0x50)])
            let off = u32(e, 8), size = u32(e, 12)
            if u16(e, 0) == 0, size > 0, off + size <= image.count { return (off, size) }
        }
        return nil
    }

    static func contains(_ hay: [UInt8], _ needle: [UInt8]) -> Bool {
        guard hay.count >= needle.count, let first = needle.first else { return false }
        var i = 0
        while i <= hay.count - needle.count {
            if hay[i] == first, hay[i..<(i + needle.count)].elementsEqual(needle) { return true }
            i += 1
        }
        return false
    }
}

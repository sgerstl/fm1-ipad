import Foundation
import Testing
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import SloopKit

/// The plain SHA-256 the phone uses for the firmware pins, against the standard's vectors, CryptoKit, and the pinned
/// firmware files themselves.
struct DigestTests {
    func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }

    @Test func theStandardsVectors() {
        #expect(hex(LupeDigest.plainSHA256([])) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(hex(LupeDigest.plainSHA256(Array("abc".utf8))) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(hex(LupeDigest.plainSHA256(Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)))
                == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        #expect(hex(LupeDigest.plainSHA256([UInt8](repeating: 0x61, count: 1_000_000))) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    #if canImport(CryptoKit)
    @Test func agreesWithCryptoKitAtEveryLengthRoundABlock() {
        var bytes: [UInt8] = []
        var x: UInt32 = 12345
        for n in 0..<200 {
            #expect(hex(LupeDigest.plainSHA256(bytes)) == SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined(), "length \(n)")
            x = x &* 1664525 &+ 1013904223
            bytes.append(UInt8(truncatingIfNeeded: x >> 16))
        }
    }
    #endif

    @Test func thePinnedFirmwareFilesHashToTheirPins() throws {
        var checked = 0
        for f in LupeFirmware.allCases {
            guard let url = f.localCopy, let data = try? Data(contentsOf: url) else { continue }
            #expect(hex(LupeDigest.plainSHA256([UInt8](data))) == f.sha256, "\(f.rawValue)")
            #expect(LupeDigest.sha256Hex(data) == f.sha256)
            checked += 1
        }
        #expect(checked >= 1, "no firmware file found to check")
    }
}

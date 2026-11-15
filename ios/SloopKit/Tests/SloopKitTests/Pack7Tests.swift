import Foundation
import Testing
@testable import SloopKit

@Suite struct Pack7Tests {
    @Test func pack7RoundTrip() {
        let data: [UInt8] = (0..<300).map { UInt8(($0 * 37) & 0xFF) }
        let packed = Pack7.encode(data)
        #expect(packed.allSatisfy { $0 < 0x80 })
        #expect(Pack7.decode(packed) == data)
        #expect(Pack7.encode([0x80, 0x01]) == [0x01, 0x00, 0x01])
        #expect(Pack7.readU35(Pack7.u35(0x1234_5678)[...]) == 0x1234_5678)
    }

    @Test func crc32IsZlibs() {
        #expect(CRC32.of(Array("123456789".utf8)) == 0xCBF4_3926)       // the standard check value
    }
}

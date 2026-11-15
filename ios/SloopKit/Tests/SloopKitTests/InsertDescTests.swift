import Foundation
import Testing
@testable import SloopKit

@Suite(.serialized) @MainActor struct InsertDescTests {
    /// param_format's curves, against values worked out from tools/gen_tables.py.
    @Test func valuesAsTheDeviceShowsThem() throws {
        func d(_ f: Int, max: Int = 127, names: [String] = []) -> ParamDesc {
            var b: [UInt8] = [0, 54, UInt8(f)] + Frame.v14(0) + Frame.v14(max) + Frame.v14(0) + Array("X".utf8) + [0, 0]
            if f == 8 { for n in names { b += Array(n.utf8) + [0] } }
            var x = try! ParamDesc(b); x.names = names; return x
        }
        #expect(DeviceDisplay.value(d(6), 93)! == ("-9.5", "dB"))             // (93 - 112) / 2
        #expect(DeviceDisplay.value(d(6), 112)! == ("0.0", "dB"))
        #expect(DeviceDisplay.value(d(6), 0)! == ("OFF", ""))
        #expect(DeviceDisplay.value(d(6), 80)! == ("-16", "dB"))             // -160: "(x - 5) / 10"
        #expect(DeviceDisplay.value(d(5), 0)! == ("30", "Hz"))
        #expect(DeviceDisplay.value(d(5), 127)! == ("16", "kHz"))
        #expect(DeviceDisplay.value(d(1), 61)! == ("48", "%"))                // DRIVE 48 %
        #expect(DeviceDisplay.value(d(4), 0)! == ("0.05", "Hz"))
        #expect(DeviceDisplay.value(d(3), 0)! == ("1.0", "ms"))
        #expect(DeviceDisplay.value(d(3), 127)! == ("10.0", "s"))            // 10 s and up: one decimal
        #expect(DeviceDisplay.value(d(0, names: DeviceDisplay.crushBits), 127)! == ("16", ""))
    }
}

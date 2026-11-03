import Foundation

// User sample slots (USR1..USR4): SLOOP's slot builder (tools/sampleio.py) ported byte for byte, and
// SMP_INFO's reply. The upload itself is SloopSession.uploadSample (Session.swift).

/// A user sample slot as the device builds and plays it: mono, 22050 Hz, 4-bit IMA ADPCM, a 480-byte
/// header at 0 and the data at 512 (EDITOR_PROTOCOL.md, "User sample slot").
public enum UserSample {
    public static let rate = 22050, slotSize = 0x14000, dataOffset = 512, headerLength = 480
    public static let maxData = slotSize - dataOffset
    public static var maxSamples: Int { maxData * 2 }          // 4-bit ADPCM: two samples a byte
    public static var maxSeconds: Double { Double(maxSamples) / Double(rate) }

    static let magic: UInt32 = 0x504D_5346                    // "FSMP"

    static let imaStep: [Int] = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
                                 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
                                 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
                                 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
                                 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]
    static let imaIndex = [-1, -1, -1, -1, 2, 4, 6, 8]

    /// sampleio.resample: a crude anti-alias (moving average over the ratio), then linear
    /// interpolation. The float arithmetic is the output: the order of operations is Python's.
    public static func resample(_ x: [Double], from sr: Int, to: Int) -> [Double] {
        if sr == to { return x }
        var x = x
        if sr > to {
            let k = max(1, Int((Double(sr) / Double(to)).rounded(.toNearestOrEven)))   // Python's round()
            if k == 2 {
                if !x.isEmpty {
                    var y = [Double]()
                    y.reserveCapacity(x.count)
                    for i in 0..<(x.count - 1) { y.append((x[i] + x[i + 1]) / 2) }
                    y.append(x[x.count - 1] / 2)
                    x = y
                }
            } else if k > 1 {
                // left to right (reduce(add)), the window shorter at the end but still divided by k
                let n = x.count
                x = (0..<n).map { i in
                    var s = x[i]
                    var j = i + 1
                    while j < min(i + k, n) { s += x[j]; j += 1 }
                    return s / Double(k)
                }
            }
        }
        let step = Double(sr) / Double(to), last = Double(x.count - 1)
        var out = [Double](), p = 0.0
        out.reserveCapacity(Int(Double(x.count) / step) + 1)
        while p < last {
            let i = Int(p)
            let f = p - Double(i)
            out.append(x[i] * (1 - f) + x[i + 1] * f)
            p += step
        }
        return out
    }

    /// sampleio.to_int16: peak normalised to 30000, truncated toward zero.
    public static func toInt16(_ x: [Double]) -> [Int16] {
        let pk = max(1e-9, x.reduce(0) { max($0, abs($1)) })
        return x.map { Int16(max(-32768, min(32767, Int($0 / pk * 30000)))) }
    }

    /// sampleio.ima_encode(s, 0)[0]: IMA ADPCM, 4 bit, low nibble first, from predictor 0 / index 0.
    public static func imaEncode(_ s: [Int16]) -> [UInt8] {
        var pred = 0, idx = 0
        var nib = [UInt8]()
        nib.reserveCapacity(s.count + 1)
        for v in s {
            let step = imaStep[idx]
            var diff = Int(v) - pred
            var code = 0
            if diff < 0 { code = 8; diff = -diff }
            var vd = step >> 3
            if diff >= step { code |= 4; diff -= step; vd += step }
            if diff >= step >> 1 { code |= 2; diff -= step >> 1; vd += step >> 1 }
            if diff >= step >> 2 { code |= 1; vd += step >> 2 }
            pred = code & 8 != 0 ? pred - vd : pred + vd
            pred = min(32767, max(-32768, pred))
            idx = min(88, max(0, idx + imaIndex[code & 7]))
            nib.append(UInt8(code))
        }
        if nib.count & 1 == 1 { nib.append(0) }
        return stride(from: 0, to: nib.count, by: 2).map { nib[$0] | nib[$0 + 1] << 4 }
    }

    /// One zone covering the whole keyboard (lo 0, hi 127), one-shot (looped 0), root MIDI note.
    /// sampleio.user_slot(name, [(samples, root, None, None)]).
    public static func slot(name: String, samples: [Int16], root: Int = 60) throws -> (header: [UInt8], data: [UInt8]) {
        guard !samples.isEmpty else { throw SloopSession.SampleError.empty }
        let data = imaEncode(samples)
        guard data.count <= maxData else { throw SloopSession.SampleError.tooLong }
        var h = [UInt8]()
        func u32(_ v: UInt32) { h += (0..<4).map { UInt8(truncatingIfNeeded: v >> (8 * UInt32($0))) } }
        func u16(_ v: UInt16) { h += [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 8)] }
        // the name as the tool cleans it: upper case, printable ASCII only, 8 bytes 0-padded
        let nm = name.uppercased().unicodeScalars.filter { (0x20...0x7E).contains($0.value) }.prefix(8).map { UInt8($0.value) }
        u32(magic); u16(1); h += [1, 0]
        h += nm + [UInt8](repeating: 0, count: 8 - nm.count)
        u32(UInt32(data.count)); u32(CRC32.of(data)); h += [UInt8](repeating: 0, count: 8)
        // the zone: off, n, loop start, loop end, rate; root x 16, predictor; index, lo, hi, looped
        let rate = UInt32((Double(rate) / 44100 * 65536).rounded(.toNearestOrEven))
        u32(0); u32(UInt32(samples.count)); u32(0); u32(UInt32(samples.count - 1)); u32(rate)
        u16(UInt16(truncatingIfNeeded: Int16(truncatingIfNeeded: root * 16))); u16(0)
        h += [0, 0, 127, 0]
        h += [UInt8](repeating: 0, count: headerLength - h.count)
        return (h, data)
    }
}

/// A user sample slot as SMP_INFO reports it.
public struct SampleSlot: Equatable, Sendable {
    public var zones: Int
    public var name: String
    public var kib: Int
    public var isEmpty: Bool { zones == 0 }
    public init(zones: Int, name: String, kib: Int) { self.zones = zones; self.name = name; self.kib = kib }

    /// SMP_INFO: slots, slot KiB, then per slot: zone count (0 = empty), name string, data KiB.
    static func list(_ body: [UInt8]) throws -> [SampleSlot] {
        var r = ByteReader(body, cmd: Cmd.smpInfo)
        let n = try r.u8()
        _ = try r.u8()
        return try (0..<n).map { _ in SampleSlot(zones: try r.u8(), name: try r.string(), kib: try r.u8()) }
    }
}

import Foundation

/// A project as SLOOP keeps it (firmware project.c `project_t`, format 6 "FUN6", 3816 bytes): what the
/// backup objects 0 (the working loop) and 2…5 (sections A–D) hold. Only the parts the app reads or
/// writes are mapped; the rest rides along untouched.
public struct Fun6: Equatable, Sendable {
    public static let size = 3816
    static let magic: UInt32 = 0x4655_4E36
    static let tracksAt = 76, trackSize = 934, stepsAt = 134, engineAt = 132, sumAt = 3812, selAt = 72

    public private(set) var bytes: [UInt8]

    public init?(_ bytes: [UInt8]) {
        guard bytes.count == Self.size, Self.u32(bytes, 0) == Self.magic, Self.u32(bytes, 4) == UInt32(Self.size) else { return nil }
        self.bytes = bytes
    }

    /// What TOOLS > NEW leaves: every track empty, the default sounds (808 BOOM, RHODES, LOFI FLUTE, the
    /// 808 kit), 90 BPM. Captured from the firmware itself (tools/blank_project.c: project_new, then
    /// proj_capture, on the host build of SLOOP 2.8.4).
    public static let blank = Fun6(Array(Data(base64Encoded: blankBase64, options: .ignoreUnknownCharacters)!))!

    public var bpm: Int {
        get { Int(Self.i16(bytes, 8)) }
        set { put16(8, newValue) }
    }

    /// P_SLEN, the track's pattern length in steps.
    public func length(track t: Int) -> Int { Int(Self.i16(bytes, Self.tracksAt + t * Self.trackSize + 2 * Param.length)) }
    public mutating func setLength(track t: Int, _ v: Int) { put16(Self.tracksAt + t * Self.trackSize + 2 * Param.length, v) }

    public func engine(track t: Int) -> Int { Int(bytes[Self.tracksAt + t * Self.trackSize + Self.engineAt]) }
    public func preset(track t: Int) -> Int { Int(bytes[Self.tracksAt + t * Self.trackSize + Self.engineAt + 1]) }

    private func stepAt(_ t: Int, _ i: Int) -> Int { Self.tracksAt + t * Self.trackSize + Self.stepsAt + 10 * i }

    /// core.h step_t: note[4], n, time, flags, vel, lvl, rat.
    public func steps(track t: Int) -> [SynthStep] {
        (0..<64).map { i in
            let o = stepAt(t, i), n = min(Int(bytes[o + 4]), 4)
            if n == 0 && bytes[o + 5] != UInt8(StepTime.tie.rawValue) { return .empty }   // seq.c steps_clear: REST, no notes
            return SynthStep(notes: (0..<n).map { Int(bytes[o + $0]) }, time: StepTime(rawValue: Int(bytes[o + 5])) ?? .rest,
                             accent: bytes[o + 6] & 1 != 0, slide: bytes[o + 6] & 2 != 0, velocity: Int(bytes[o + 7]),
                             levels: (0..<n).map { Int(bytes[o + 8]) >> (2 * $0) & 3 }, ratchets: (0..<n).map { Int(bytes[o + 9]) >> (2 * $0) & 3 })
        }
    }

    public mutating func setSteps(track t: Int, _ s: [SynthStep]) {
        for i in 0..<64 {
            let o = stepAt(t, i), step = i < s.count ? s[i] : .empty
            let n = min(step.notes.count, 4)
            var lvl = 0, rat = 0
            for k in 0..<n {
                lvl |= (k < step.levels.count ? step.levels[k] & 3 : 0) << (2 * k)
                rat |= (k < step.ratchets.count ? step.ratchets[k] & 3 : 0) << (2 * k)
            }
            for k in 0..<4 { bytes[o + k] = k < n ? UInt8(step.notes[k] & 127) : 0 }
            bytes[o + 4] = UInt8(n)
            bytes[o + 5] = UInt8(n == 0 && step.time != .tie ? StepTime.rest.rawValue : step.time.rawValue)
            bytes[o + 6] = UInt8((step.accent ? 1 : 0) | (step.slide ? 2 : 0))
            bytes[o + 7] = n == 0 && step.time != .tie ? 0 : UInt8(min(max(step.velocity, 1), 127))
            bytes[o + 8] = UInt8(lvl); bytes[o + 9] = UInt8(rat)
        }
    }

    /// core.h dstep_t: on[2], lvl[4], rat[4], each little-endian bit fields.
    public func drumSteps() -> [DrumStep] {
        (0..<64).map { i in
            let o = stepAt(3, i)
            return DrumStep(on: UInt16(Self.u16(bytes, o)), levels: Self.u32(bytes, o + 2), ratchets: Self.u32(bytes, o + 6))
        }
    }

    public mutating func setDrumSteps(_ s: [DrumStep]) {
        for i in 0..<64 {
            let o = stepAt(3, i), d = i < s.count ? s[i] : .empty
            bytes[o] = UInt8(d.on & 0xFF); bytes[o + 1] = UInt8(d.on >> 8)
            for k in 0..<4 { bytes[o + 2 + k] = UInt8(d.levels >> (8 * k) & 0xFF); bytes[o + 6 + k] = UInt8(d.ratchets >> (8 * k) & 0xFF) }
        }
    }

    /// The bytes with their checksum made right again (FNV-1a over all but the last 4, project.c proj_sum).
    public var sealed: Fun6 {
        var f = self
        var s: UInt32 = 0x811C_9DC5
        for b in bytes[0..<Self.sumAt] { s = (s ^ UInt32(b)) &* 16_777_619 }
        for k in 0..<4 { f.bytes[Self.sumAt + k] = UInt8(s >> (8 * k) & 0xFF) }
        return f
    }

    /// What a snapshot of the working loop holds that isn't the music, zeroed so picking a track doesn't
    /// read as an edit: the selected track, the GO globals (LOAD, ENGSEL, ENGGO, CLRSEQ, INITSND, NEW)
    /// and the FM-1's own settings a load leaves alone (MIDI, SYNC, ROUTE, the drum channel).
    public var musicOnly: [UInt8] {
        var b = bytes
        b[Self.selAt] = 0
        for g in [12, 13, 14, 18, 20, 21, 22, 23, 24, 31] { b[8 + 2 * g] = 0; b[9 + 2 * g] = 0 }
        for k in 0..<4 { b[Self.sumAt + k] = 0 }
        return b
    }

    private mutating func put16(_ o: Int, _ v: Int) {
        let u = UInt16(bitPattern: Int16(clamping: v))
        bytes[o] = UInt8(u & 0xFF); bytes[o + 1] = UInt8(u >> 8)
    }
    static func u16(_ b: [UInt8], _ o: Int) -> UInt16 { UInt16(b[o]) | UInt16(b[o + 1]) << 8 }
    static func i16(_ b: [UInt8], _ o: Int) -> Int16 { Int16(bitPattern: u16(b, o)) }
    static func u32(_ b: [UInt8], _ o: Int) -> UInt32 { UInt32(u16(b, o)) | UInt32(u16(b, o + 2)) << 16 }

    private static let blankBase64 = """
        Nk5VRugOAABaAAAAAAAAAAEAPABGAFoAWgA8ACgAPAAAAAAAAAAoAAEAAAAAAFpUAAAAAAAAAABAIGQAEAAAAAAAAAABAAAAAADAAmgAAABwAAAANAAAABIA
        AAD3/zwAAAAAAAAAAAAAAAAAAAAAAAIAAQBAAAAAfwAAAAAAAAAAAAAA6P8QAAIAAABAAAAAAAAAAAAAAgA7AAAAAAABAAAAAAAoAAAAAQABAH8AAAAAAAAA
        AAADAAAAAAAAAH8AAAAwAAAAAEBgYH8AAAAAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAA
        AAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA
        /wAAAP8AAAD/AAAA/wAAAP8AAABoAAAAVQAjADcAAAAAAAAAFwBUAAAAAAAAAAAAAAAAABoAAAACAAEAQAAAAH8AAAAAAAAAAAAAAAAAEAACAAAAQAAAAB4A
        DAAaAAAAAAAAAAAAAAAAAAAAKAAAAAEAAQB/AAAAAAAAAAAABAABAAEADgAaACMAAAAAAABAYGB/AAAAAAABAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAC
        AAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8A
        AAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAAaAAMAFAAeAA8AAAAAAAAAP//WQAAAAAAKAABAAAAAAAAAAAA
        AgABAEAAAAB/AAAAAAAAAAAAAAAAABAAAgAAAEAAAAAQABoAHgACAAAAAAAAAAAAAAAAACgAAAABAAEAfwAAAAAAAAAAAAUAAAAMAAEAZAAAAAAAAAAAQGBg
        fwAAAAAABAUAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAAAAAAAgAAAAAAAAAAAAIAAAAAAAAAAAACAAAAAAAA
        AAAAAgAAAAAAAAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP8AAAD/AAAA
        /wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAGgA
        CgBGAFoAPAAAAAAAAAAAADwAAAAAAAAAAAAAAAAAAAAAAAIAAQBAAAAAfwAAAAAAAAAAAAAAAAAQAAIAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoAAAA
        AQABAH8AAAAAAAAAAAAFAAAAAAAAAAAAAAAAAAAAAEBgYH8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA
        /wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAADKvI8I
        """
}

/// Everything a Jib project keeps of the FM-1: the working loop, sections A–D and the song order. The
/// sounds in the user presets, the SYN kits and the samples stay on the FM-1 (they belong to it, not
/// to a song).
public struct ProjectData: Codable, Equatable, Sendable {
    public var working: [UInt8]          // backup object 0
    public var sections: [[UInt8]]       // objects 2…5; no bytes: an empty section
    public var songOrder: [UInt8]        // the settings object's bytes 48..<84 (arr_config_t)

    public init(working: [UInt8], sections: [[UInt8]], songOrder: [UInt8]) {
        self.working = working; self.sections = sections; self.songOrder = songOrder
    }

    /// A fresh start: TOOLS > NEW's loop, no sections, the song order SLOOP falls back on.
    public static var blank: ProjectData {
        ProjectData(working: Fun6.blank.bytes, sections: [[], [], [], []],
                    songOrder: Array(SongOrder.standard.written(into: [UInt8](repeating: 0, count: 96))[48..<84]))
    }

    public var loop: Fun6? { Fun6(working) }
    public var bpm: Int? { loop?.bpm }
    public var sectionsFilled: [Bool] { sections.map { !$0.isEmpty } }

    /// Equal when the music is: the loop's music bytes, each section, the order.
    public var fingerprint: String {
        let loopPart = loop.map { CRC32.of($0.musicOnly) } ?? CRC32.of(working)
        return ([loopPart] + sections.map { CRC32.of($0) } + [CRC32.of(songOrder)]).map { String($0, radix: 16) }.joined(separator: "-")
    }
}

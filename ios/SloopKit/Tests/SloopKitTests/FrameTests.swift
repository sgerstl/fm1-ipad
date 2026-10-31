import Testing
@testable import SloopKit

@Suite struct FrameTests {
    @Test func encodeAndDecode() {
        #expect(Frame.encode(Cmd.live, [0]) == [0xF0, 0x7D, 0x46, 0x4C, 0x4D, 0x00, 0xF7])
        let d = Frame.decode([0xF0, 0x7D, 0x46, 0x4C, 0x19, 0x00, 0xF7])
        #expect(d?.cmd == Cmd.ping && d?.body == [0])
        #expect(Frame.decode([0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]) == nil)
    }

    @Test func v14RoundTrip() throws {
        for v in [-8192, -64, -1, 0, 1, 63, 108, 8191] {
            var r = ByteReader(Frame.v14(v))
            #expect(try r.v14() == v)
        }
        #expect(Frame.v14(108) == [0x6C, 0x40])
    }

    @Test func assemblerSplitsAndSkipsRealtime() {
        var a = SysExAssembler()
        #expect(a.feed([0x90, 0x3C, 0x64, 0xF0, 0x7D, 0x46]).isEmpty)
        #expect(a.feed([0xF8, 0x4C, 0x19, 0x00, 0xF7, 0xF0, 0x7D]) == [[0xF0, 0x7D, 0x46, 0x4C, 0x19, 0x00, 0xF7]])
        #expect(a.feed([0x46, 0x4C, 0x19, 0x00, 0xF7]) == [[0xF0, 0x7D, 0x46, 0x4C, 0x19, 0x00, 0xF7]])
        // a broken frame is dropped at the next status byte
        #expect(a.feed([0xF0, 0x7D, 0x90, 0x3C, 0xF0, 0x01, 0xF7]) == [[0xF0, 0x01, 0xF7]])
    }

    @Test func shortRepliesThrow() {
        #expect(throws: DecodeError.self) { try LiveState([0, 0, 2]) }
        #expect(throws: DecodeError.self) { try TrackStepReply([0, 1, 2]) }
    }

    @Test func changedPushFromTheDoc() throws {
        // CHANGED scope 0 (track), id 0 (LVL), value 90 — the shape the doc gives; not captured yet.
        let p = try Push(cmd: Cmd.changed, body: [0, 0] + Frame.v14(90))
        #expect(p == .changed(scope: 0, id: 0, value: 90))
        let tc = try Push(cmd: Cmd.trackChanged, body: [2, UInt8(Param.pan)] + Frame.v14(-20))
        #expect(tc == .trackChanged(track: 2, id: Param.pan, value: -20))
    }

    @Test func synthStepLevelsAndRatchets() throws {
        // two notes: note 1 HARD (3) x3 (2); note 0 GHOST (1) x1 (0) → lvl 0b1101, rat 0b1000
        var r = ByteReader([2, 60, 64, 0, 0, 0, 1, 90, 0b1101, 0, 0b1000])
        let s = try SynthStep(reader: &r)
        #expect(s.notes == [60, 64] && s.accent && !s.slide)
        #expect(s.levels == [1, 3] && s.ratchets == [0, 2])
    }

    @Test func drumStepBits() throws {
        // lanes 0 and 15 on; lane 15 HARD (3 << 30), ratchet x2 (1 << 30)
        let on: UInt64 = 1 | 1 << 15, lvl: UInt64 = 3 << 30, rat: UInt64 = 1 << 30
        func b(_ v: UInt64, _ n: Int) -> [UInt8] { (0..<n).map { UInt8((v >> (7 * UInt64($0))) & 0x7F) } }
        let d = try DrumStepReply([7] + b(on, 3) + b(lvl, 5) + b(rat, 5))
        #expect(d.index == 7 && d.step.lanes == [0, 15])
        #expect(d.step.level(15) == 3 && d.step.ratchet(15) == 1 && d.step.level(0) == 0)
    }

    @Test func foldedRowsCMinor() {
        // the mockup's T1: C minor, D♯4 (63) .. G5 (79) → 10 rows
        let rows = Music.foldedRows(used: [63, 67, 70, 72, 75, 79, 74, 77], root: 0, scale: 2, minRows: 10)
        #expect(rows.first == 79 && rows.last == 63 && rows.count == 10)
        #expect(Music.noteName(70) == "A♯4")
        // chromatic: only the notes used (B4, E6, B6, C7 from the real T1), padded out to 10 rows
        let chr = Music.foldedRows(used: [71, 88, 95, 96], root: 0, scale: 0, minRows: 10)
        #expect(chr.count == 10 && chr.contains(71) && chr.contains(96) && !chr.contains(80))
    }
}

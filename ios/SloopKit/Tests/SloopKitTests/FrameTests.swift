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

    @Test func synthStepWriteRoundTrips() throws {
        let st = SynthStep(notes: [60, 64, 67, 71], time: .note, accent: true, slide: true, velocity: 90,
                           levels: [0, 1, 2, 3], ratchets: [3, 2, 1, 0])
        let req = Request.setTrackStep(track: 2, index: 9, st)
        #expect(req.bytes.prefix(7) == [0xF0, 0x7D, 0x46, 0x4C, Cmd.trackStep, 2, 9])
        #expect(req.args.count == 2 + 11)
        var r = ByteReader(Array(req.args.dropFirst(2)))
        #expect(try SynthStep(reader: &r) == st)    // levels bit 7 and ratchet bit 7 go through hi
    }

    @Test func drumStepWriteRoundTrips() throws {
        let d = DrumStep.empty.setting(0, on: true).setting(15, on: true, level: 3, ratchet: 1)
        let back = try DrumStepReply([4] + d.encoded)
        #expect(back.step == d && back.step.lanes == [0, 15])
        #expect(d.setting(15, on: false).level(15) == 0)
    }

    @Test func writesMatchTheirEchoes() {
        #expect(Request.setTrackParam(track: 1, id: Param.pan, value: -3).matches([1, UInt8(Param.pan)] + Frame.v14(-3)))
        #expect(Request.setGlobal(id: Global.swing, value: 20).bytes == Frame.encode(Cmd.set, [1, 1] + Frame.v14(20)))
    }

    @Test func notesOutsideSysEx() {
        var a = SysExAssembler()
        // note on C4, running-status note on E4, a SysEx frame in between, note on with velocity 0 = off
        let frames = a.feed([0x90, 60, 100, 64, 90, 0xF0, 0x7D, 0x46, 0x4C, 0x19, 0x00, 0xF7, 0x80, 60, 0, 0x91, 64, 0, 0xB0, 1, 2])
        #expect(frames.count == 1)
        #expect(a.drainNotes() == [NoteEvent(on: true, channel: 0, note: 60), NoteEvent(on: true, channel: 0, note: 64),
                                   NoteEvent(on: false, channel: 0, note: 60), NoteEvent(on: false, channel: 1, note: 64)])
        #expect(a.drainNotes().isEmpty)
    }

    @Test func keyPitchFollowsTheFM1() {
        // OFF: chromatic from F3; OCT and TRN shift it
        #expect(Music.keyPitch(0, root: 0, scale: 0, quant: 0, chord: 0, transpose: 0, octave: 0) == 53)
        #expect(Music.keyPitch(7, root: 0, scale: 0, quant: 0, chord: 0, transpose: -12, octave: -1) == 36)
        // SNAP to C minor: E4 (key 11) rounds down to D#4
        #expect(Music.keyPitch(11, root: 0, scale: 2, quant: 1, chord: 0, transpose: 0, octave: 0) == 63)
        // WHITE, C major: C4 (key 7) is the root, D4 the next degree, black keys silent
        #expect(Music.keyPitch(7, root: 0, scale: 1, quant: 2, chord: 0, transpose: 0, octave: 0) == 60)
        #expect(Music.keyPitch(9, root: 0, scale: 1, quant: 2, chord: 0, transpose: 0, octave: 0) == 62)
        #expect(Music.keyPitch(8, root: 0, scale: 1, quant: 2, chord: 0, transpose: 0, octave: 0) == nil)
        // WHITE, C minor pentatonic: the white key after C4 walks to D#4
        #expect(Music.keyPitch(9, root: 0, scale: 6, quant: 2, chord: 0, transpose: 0, octave: 0) == 63)
        // F3 (key 0) in WHITE C major: three degrees below C4 = F3
        #expect(Music.keyPitch(0, root: 0, scale: 1, quant: 2, chord: 0, transpose: 0, octave: 0) == 53)
    }

    @Test func userPresetListFromTheDoc() throws {
        // start 0, count 3, total 32; slot 0 used DIGITAL "MY RHODES", slot 1 empty, slot 2 used ANALOG "BASS"
        let body: [UInt8] = [0, 3, 32, 1, 1] + Array("MY RHODES".utf8) + [0, 0, 0, 0, 1, 0] + Array("BASS".utf8) + [0]
        let l = try UserPresetList(body)
        #expect(l.total == 32)
        #expect(l.used == [UserPreset(slot: 0, engine: 1, name: "MY RHODES"), UserPreset(slot: 2, engine: 0, name: "BASS")])
    }
}

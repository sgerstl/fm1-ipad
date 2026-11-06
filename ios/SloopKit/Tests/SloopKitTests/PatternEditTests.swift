import Testing
@testable import SloopKit

@Suite struct PatternEditTests {
    func pattern(_ notes: [(Int, [Int], Int)]) -> [SynthStep] {
        var s = Array(repeating: SynthStep.empty, count: 64)
        for (i, ns, len) in notes {
            s[i] = SynthStep(notes: ns, time: .note, accent: false, slide: false, velocity: 90 + i)
            for j in 1..<max(1, len) { s[i + j].time = .tie }
        }
        return s
    }

    @Test func addAndRemove() {
        var s = pattern([(0, [60], 2)])
        #expect(PatternEdit.add(&s, step: 4, note: 62) && s[4].notes == [62] && s[4].time == .note)
        #expect(!PatternEdit.add(&s, step: 1, note: 64))                    // a TIE: no
        for n in [61, 63, 65] { PatternEdit.add(&s, step: 0, note: n) }
        #expect(!PatternEdit.add(&s, step: 0, note: 67))                    // four already
        PatternEdit.remove(&s, NoteRef(step: 4, note: 62))
        #expect(s[4].time == .rest)
        for n in [60, 61, 63, 65] { PatternEdit.remove(&s, NoteRef(step: 0, note: n)) }
        #expect(s[0].time == .rest && s[1].time == .rest)                   // the last note takes its TIE
    }

    @Test func moveKeepsLengthAndFields() {
        var s = pattern([(0, [60], 3)])
        s[0].extra = [0, 0, 0, 75, 2, 0, 3, 36, 0]                          // chance, ratchet, COND, NUDGE
        let m = PatternEdit.move(&s, [NoteRef(step: 0, note: 60)], by: 4, pitch: { $0 + 2 })
        #expect(m[NoteRef(step: 0, note: 60)] == NoteRef(step: 4, note: 62))
        #expect(s[0].time == .rest && s[4].notes == [62] && s[4].velocity == 90 && s[4].extra == [0, 0, 0, 75, 2, 0, 3, 36, 0])
        #expect(s[5].time == .tie && s[6].time == .tie && s[7].time == .rest)
        // one note of a chord: it leaves the chord
        var c = pattern([(0, [60, 64], 1), (2, [67], 1)])
        PatternEdit.move(&c, [NoteRef(step: 0, note: 64)], by: 2, pitch: { $0 })
        #expect(c[0].notes == [60] && Set(c[2].notes) == [67, 64])
        // past the end: stays
        var e = pattern([(62, [60], 2)])
        PatternEdit.move(&e, [NoteRef(step: 62, note: 60)], by: 4, pitch: { $0 })
        #expect(e[62].notes == [60])
    }

    @Test func duplicateAfterGrowsLength() {
        var s = pattern([(0, [60], 1), (4, [62], 2)])
        var len = 8
        let r = PatternEdit.duplicateAfter(&s, steps: 0...7, notes: nil, length: &len)
        #expect(r?.added == 8...15 && r?.oldLength == 8 && r?.newLength == 16 && len == 16)
        #expect(s[8].notes == [60] && s[12].notes == [62] && s[13].time == .tie)
        // up to 64 only
        var t = pattern([(40, [60], 1)])
        var l2 = 64
        let r2 = PatternEdit.duplicateAfter(&t, steps: 32...63, notes: nil, length: &l2)
        #expect(r2 == nil && l2 == 64)
        // notes alone: copies after their span, the originals stay
        var u = pattern([(0, [60, 64], 1), (1, [62], 1)])
        var l3 = 16
        let r3 = PatternEdit.duplicateAfter(&u, steps: nil, notes: [NoteRef(step: 0, note: 60), NoteRef(step: 1, note: 62)], length: &l3)
        #expect(r3?.added == 2...3 && u[0].notes == [60, 64] && u[2].notes == [60] && u[3].notes == [62] && l3 == 16)
    }

    @Test func changedSteps() {
        let a = pattern([(0, [60], 1)])
        var b = a
        PatternEdit.add(&b, step: 3, note: 61)
        #expect(PatternEdit.changed(a, b) == [3])
    }

    /// Paste replaces (Scott, 2026-11-06): the covered steps take the clip's as they are; "Paste and keep" merges.
    /// Duplicate before (2026-11-06): steps 9–12 copied onto 5–8, replacing what was there; no room before step 3.
    @Test func duplicateBeforeReplacesTheStepsToTheLeft() {
        var s = pattern([(5, [60], 1), (8, [62], 1), (9, [72], 1), (11, [74], 1)])
        let r = PatternEdit.duplicateBefore(&s, steps: 8...11, notes: nil)
        #expect(r == 4...7)
        #expect(s[4].notes == [62] && s[5].notes == [72] && s[6].time == .rest && s[7].notes == [74])
        #expect(s[8].notes == [62] && s[9].notes == [72])                  // the originals stay
        var t = pattern([(2, [60], 1)])
        #expect(PatternEdit.duplicateBefore(&t, steps: 2...5, notes: nil) == nil)
    }

    @Test func pasteReplacesOrKeeps() {
        // the clip: a note held one step, then a REST
        let clip = Array(pattern([(0, [72], 2)])[0...2])
        // over a chord, a note and a long note that runs past the clip
        var r = pattern([(4, [60, 64], 1), (5, [67], 1), (6, [55], 4)])
        var len = 16
        PatternEdit.paste(&r, clip: clip, at: 4, length: &len, keep: false)
        #expect(r[4].notes == [72] && r[4].velocity == 90 && r[5].time == .tie && r[6].time == .rest && r[6].notes.isEmpty)
        #expect(r[7].time == .rest && r[8].time == .rest && r[9].time == .rest)    // the cut note's TIEs go with it
        #expect(len == 16)
        // and keep: the clip's note joins the chord, a clip TIE doesn't land on a NOTE
        var k = pattern([(4, [60, 64], 1), (5, [67], 1)])
        PatternEdit.paste(&k, clip: clip, at: 4, length: &len, keep: true)
        #expect(Set(k[4].notes) == [60, 64, 72] && k[5].notes == [67] && k[5].time == .note)
        // past the end: LENGTH grows to fit, up to 64
        var e = pattern([]), l = 16
        PatternEdit.paste(&e, clip: clip, at: 15, length: &l, keep: false)
        #expect(l == 18 && e[15].notes == [72] && e[16].time == .tie)
        var m = pattern([]), ml = 64
        PatternEdit.paste(&m, clip: clip, at: 63, length: &ml, keep: false)
        #expect(ml == 64 && m[63].notes == [72])
    }
}

extension SkiffScreenLinkTests {
    /// Duplicate after on the fake: the copied steps written (TRACK_STEP) and LENGTH grown, read back from the device.
    @Test func duplicateAfterReachesTheDevice() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        let t = s.selectedTrack
        var steps = s.tracks[t].steps, len = 8
        steps[0] = SynthStep(notes: [60, 64], time: .note, accent: false, slide: false, velocity: 100)
        s.writePattern(track: t, steps, length: len)
        try await waitFor(5) { s.tracks[t].length == 8 && s.tracks[t].steps[0].notes == [60, 64] }
        let r = PatternEdit.duplicateAfter(&steps, steps: 0...7, notes: nil, length: &len)
        #expect(r?.newLength == 16)
        s.writePattern(track: t, steps, length: len)
        try await waitFor(5) { s.tracks[t].length == 16 && s.tracks[t].steps[8].notes == [60, 64] }
        // what the device keeps: read again
        await s.rereadSteps(track: t)
        #expect(s.tracks[t].steps[8].notes == [60, 64])
        run.cancel()
    }
}

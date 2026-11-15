import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Clearing a pad with no confirm and an Undo (batch item 13), and the pattern's step count (item 9), on FakeSkiff.
extension PatternsTests {
    /// A pad of track `t` whose pattern nothing else uses: the FM-1's own CLEAR would erase it.
    func soloPad(_ core: PhoneCore, _ fake: FakeSkiff) throws -> (t: Int, e: Int, p: Int) {
        let song = try #require(core.session.skiffSong?.song), pool = try #require(core.session.skiffSong?.pool)
        for (t, l) in song.tracks.enumerated() {
            for (e, x) in l.entries.enumerated() {
                if let p = x.poolIndex, pool.patterns[p].uses == 1, l.entryOn != e { return (t, e, p + 1) }
            }
        }
        // none in the demo: make one on the first empty entry
        let t = 1, e = try #require(song.tracks[t].entries.firstIndex { $0.isEmpty }), p = try #require((1...64).first { fake.poolLen[$0 - 1] == 0 })
        fake.poolLen[p - 1] = 16
        fake.lists[t][e].p = p
        return (t, e, p)
    }

    @Test func aClearedPadComesBackWithItsPattern() async throws {
        let box = Box()
        PhoneCore.undoClearWindow = 30
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let pad = try soloPad(core, fake)
        fake.lists[pad.t][pad.e].r = 3                                        // REPS 4
        try await wait("the pad read") { core.session.skiffSong?.song?.tracks[pad.t].entries[pad.e] == SongEntry(pattern: pad.p, reps: 4) }
        try await wait("its use read") { core.session.skiffSong?.pool?.patterns[pad.p - 1].uses == 1 }
        // playing: a pattern's pad isn't cleared
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: #"{"intent":"padClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        #expect(box.notices.last?.text.hasPrefix("Stop playback to clear a pad") == true && fake.lists[pad.t][pad.e].p == pad.p)
        try await stop(core, fake)
        // stopped: the pad is empty, with no confirm, and the pattern is still kept
        core.handle(json: #"{"intent":"padClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        try await wait("cleared") { fake.lists[pad.t][pad.e].p == 0 }
        try await wait("undo offered") { core.padsArea().clearUndo == [PadsArea.ClearUndo(track: pad.t + 1, entry: pad.e, pattern: pad.p)] }
        #expect(fake.poolLen[pad.p - 1] > 0, "the pattern must survive the clear for the undo")
        // undo: the pattern and its REPS back
        try await idle(core)
        core.handle(json: #"{"intent":"undoClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        try await wait("back") { fake.lists[pad.t][pad.e].p == pad.p && fake.lists[pad.t][pad.e].r == 3 }
        #expect(core.padsArea().clearUndo.isEmpty)
        // a second undo has nothing to undo
        core.handle(json: #"{"intent":"undoClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        #expect(box.notices.last?.text.hasPrefix("That clear can't be undone") == true)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func whenTheUndoTimeIsUpThePatternGoesAsTheFM1WouldHaveClearedIt() async throws {
        let box = Box()
        PhoneCore.undoClearWindow = 1
        defer { PhoneCore.undoClearWindow = 30 }
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let pad = try soloPad(core, fake)
        try await wait("the pad read") { core.session.skiffSong?.song?.tracks[pad.t].entries[pad.e].pattern == pad.p }
        try await wait("its use read") { core.session.skiffSong?.pool?.patterns[pad.p - 1].uses == 1 }
        core.handle(json: #"{"intent":"padClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        try await wait("cleared") { fake.lists[pad.t][pad.e].p == 0 }
        try await wait("undo gone") { core.padsArea().clearUndo.isEmpty && fake.poolLen[pad.p - 1] == 0 }
        core.handle(json: #"{"intent":"undoClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        #expect(box.notices.last?.text.hasPrefix("That clear can't be undone") == true && fake.lists[pad.t][pad.e].p == 0)
        // a pattern another pad also names: cleared the FM-1's own way, the pattern stays, and it comes back too
        PhoneCore.undoClearWindow = 30
        let song = try #require(core.session.skiffSong?.song)
        let src = try #require(song.tracks[0].entries.firstIndex { $0.poolIndex != nil })
        let p = song.tracks[0].entries[src].pattern
        let spare = try #require(song.tracks[0].entries.firstIndex { $0.isEmpty })
        try await idle(core)                                                   // (the pattern's own clear just went in)
        core.handle(json: #"{"intent":"padSet","track":1,"entry":\#(spare),"pattern":\#(p)}"#)
        try await wait("named twice") { fake.lists[0][spare].p == p && (core.session.skiffSong?.pool?.patterns[p - 1].uses ?? 0) >= 2 }
        try await idle(core)
        core.handle(json: #"{"intent":"padClear","track":1,"entry":\#(spare)}"#)
        try await wait("cleared") { fake.lists[0][spare].p == 0 }
        #expect(fake.poolLen[p - 1] > 0)
        try await idle(core)
        core.handle(json: #"{"intent":"undoClear"}"#)                           // no pad named: the last clear
        try await wait("back") { fake.lists[0][spare].p == p }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func setPatternStepsSetsTheFM1sLength() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let s = core.session, t = core.editorTrack()
        let a = core.editorArea()
        #expect(a.patternSteps == s.tracks[t].length && a.patternStepsMax == s.stepCount)
        let want = a.patternSteps == 12 ? 8 : 12
        box.writes = false
        core.handle(json: #"{"intent":"setPatternSteps","steps":\#(want)}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.params[t][s.ids.length] != want && box.notices.last?.text == PhoneCore.readOnlyNotice)
        box.writes = true
        core.handle(json: #"{"intent":"setPatternSteps","steps":\#(want)}"#)
        try await wait("LENGTH on the FM-1") { fake.params[t][s.ids.length] == want }
        try await wait("in the editor") { core.editorArea().patternSteps == want }
        // past the FM-1's range: clamped
        core.handle(json: #"{"intent":"setPatternSteps","steps":500}"#)
        try await wait("clamped") { fake.params[t][s.ids.length] == s.stepCount }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    /// Scott, 2026-11-15: the Edit grid scrolls through the whole pattern in 16-step chunks, so the editor carries
    /// every step up to the length, and any of them can be read, selected and written.
    @Test func theEditorCarriesEveryStepOfALongPattern() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let s = core.session
        // a note track for the editor
        let t = try #require(s.trackIndices.first { !s.isKit($0) })
        core.handle(json: #"{"intent":"trackSelect","track":\#(t + 1)}"#)
        try await wait("the editor on it") { core.editorTrack() == t && s.selectedTrack == t }
        #expect(core.editorArea().steps.count == max(16, (s.tracks[t].length + 15) / 16 * 16))
        core.handle(json: #"{"intent":"setPatternSteps","steps":40}"#)
        try await wait("40 steps") { core.editorArea().patternSteps == 40 }
        var a = core.editorArea()
        #expect(a.steps.count == 48 && a.laneValues.count <= 48, "whole chunks: 48 for 40 steps")
        // a note on step 36 (index 35), past the first chunk: written to the FM-1, shown in the area
        core.handle(json: #"{"intent":"setStepNotes","step":35,"notes":[64]}"#)
        try await wait("step 36 on the FM-1") { s.tracks[t].steps[35].isOn && s.tracks[t].steps[35].notes == [64] }
        a = core.editorArea()
        #expect(a.steps[35].on && a.steps[35].notes == [64] && !a.steps[34].on)
        // selecting it, and a step past the chunks is held to the last one carried
        core.handle(json: #"{"intent":"stepSelect","step":35}"#)
        #expect(core.editorArea().selected == 35)
        core.handle(json: #"{"intent":"stepSelect","step":60}"#)
        #expect(core.editorArea().selected == 47)
        // a step outside the chunks isn't written
        core.handle(json: #"{"intent":"setStepNotes","step":50,"notes":[60]}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(!s.tracks[t].steps[50].isOn)
        // all 64
        core.handle(json: #"{"intent":"setPatternSteps","steps":64}"#)
        try await wait("64 steps") { core.editorArea().steps.count == 64 }
        core.handle(json: #"{"intent":"setPatternSteps","steps":16}"#)
        try await wait("16 again") { core.editorArea().steps.count == 16 }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func aDeletedBlockComesBack() async throws {
        let box = Box()
        PhoneCore.undoClearWindow = 30
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        // track 2: two new patterns at the end, so a block in the middle and one at the end can go
        for _ in 0..<2 {
            try await idle(core)
            core.handle(json: #"{"intent":"blockNew","track":2}"#)
            try await Task.sleep(for: .milliseconds(300))
        }
        try await idle(core)
        try await wait("three blocks") { core.timelineArea().tracks[1].blocks.count >= 3 }
        let blocks = core.timelineArea().tracks[1].blocks
        let before = fake.lists[1].map(\.p)
        // the middle one (the entries after it move up)
        let mid = blocks[blocks.count - 2], midP = try #require(mid.pattern)
        try await wait("its use read") { core.session.skiffSong?.pool?.patterns[midP - 1].uses == 1 }
        core.handle(json: #"{"intent":"blockDelete","track":2,"block":\#(mid.id)}"#)
        try await wait("deleted") { !fake.lists[1].map(\.p).contains(midP) }
        try await wait("undo offered") { core.timelineArea().clearUndo == [PadsArea.ClearUndo(track: 2, entry: mid.id, pattern: midP, block: true)] }
        #expect(fake.poolLen[midP - 1] > 0 && core.padsArea().clearUndo == core.timelineArea().clearUndo)
        try await idle(core)
        core.handle(json: #"{"intent":"undoClear"}"#)
        try await wait("back as it was") { fake.lists[1].map(\.p) == before }
        #expect(core.timelineArea().clearUndo.isEmpty)
        // the last one (its entry is cleared, which on the FM-1 erases a pattern nothing else names): kept all the same
        try await idle(core)
        let last = try #require(core.timelineArea().tracks[1].blocks.last), lastP = try #require(last.pattern)
        core.handle(json: #"{"intent":"blockDelete","track":2,"block":\#(last.id)}"#)
        try await wait("deleted") { fake.lists[1][last.id].p == 0 }
        #expect(fake.poolLen[lastP - 1] > 0, "the pattern must survive the delete for the undo")
        try await idle(core)
        core.handle(json: #"{"intent":"undoClear","track":2,"entry":\#(last.id)}"#)
        try await wait("back") { fake.lists[1].map(\.p) == before }
        // playing: refused, nothing changed
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: #"{"intent":"blockDelete","track":2,"block":\#(last.id)}"#)
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.lists[1].map(\.p) == before && box.notices.last?.text.hasPrefix("Delete: Stop") == true, "\(box.notices.last?.text ?? "")")
        try await stop(core, fake)
        // the undo's time over: the pattern goes
        PhoneCore.undoClearWindow = 1
        defer { PhoneCore.undoClearWindow = 30 }
        try await idle(core)
        core.handle(json: #"{"intent":"blockDelete","track":2,"block":\#(last.id)}"#)
        try await wait("deleted") { fake.lists[1][last.id].p == 0 }
        try await wait("its pattern cleared") { fake.poolLen[lastP - 1] == 0 && core.timelineArea().clearUndo.isEmpty }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

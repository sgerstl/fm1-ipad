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

    /// Scott, 2026-11-17, messages rule: Undo lasts until the next edit, never a timer. Waiting ends nothing; the next
    /// change to the song ends it, and then the pattern goes as the FM-1's own CLEAR would have taken it.
    @Test func theNextEditEndsTheUndoAndThePatternGoesAsTheFM1WouldHaveClearedIt() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let pad = try soloPad(core, fake)
        try await wait("the pad read") { core.session.skiffSong?.song?.tracks[pad.t].entries[pad.e].pattern == pad.p }
        try await wait("its use read") { core.session.skiffSong?.pool?.patterns[pad.p - 1].uses == 1 }
        core.handle(json: #"{"intent":"padClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        try await wait("cleared") { fake.lists[pad.t][pad.e].p == 0 }
        try await wait("undo offered") { core.padsArea().clearUndo.count == 1 }
        // time alone ends nothing (the old window was ten seconds; three is past the half-second loop several times)
        try await Task.sleep(for: .seconds(3))
        #expect(core.padsArea().clearUndo.count == 1 && fake.poolLen[pad.p - 1] > 0, "an undo has no timer")
        // nor do selecting, muting or copying a step: they don't change the song
        core.handle(json: #"{"intent":"trackSelect","track":1}"#)
        core.handle(json: #"{"intent":"trackMute","track":1}"#)
        core.handle(json: #"{"intent":"trackMute","track":1}"#)
        core.handle(json: #"{"intent":"stepAction","step":0,"action":"copy"}"#)
        #expect(core.padsArea().clearUndo.count == 1)
        // read-only: a refused edit changed nothing, so the undo stays
        box.writes = false
        core.handle(json: #"{"intent":"blockNew","track":3}"#)
        #expect(core.padsArea().clearUndo.count == 1)
        box.writes = true
        // the next edit (a new pattern on another track) ends it, and the kept pattern is cleared
        try await idle(core)
        core.handle(json: #"{"intent":"blockNew","track":\#(pad.t == 2 ? 4 : 3)}"#)
        #expect(core.padsArea().clearUndo.isEmpty && core.timelineArea().clearUndo.isEmpty, "the menus' Undo goes with it")
        try await wait("its pattern cleared") { fake.poolLen[pad.p - 1] == 0 }
        core.handle(json: #"{"intent":"undoClear","track":\#(pad.t + 1),"entry":\#(pad.e)}"#)
        #expect(box.notices.last?.text.hasPrefix("That clear can't be undone") == true && fake.lists[pad.t][pad.e].p == 0)
        // a pattern another pad also names: cleared the FM-1's own way, the pattern stays, and it comes back too
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
        try await wait("undo offered") { core.timelineArea().clearUndo == [PadsArea.ClearUndo(track: 2, entry: mid.id, pattern: midP, block: true, kind: "block")] }
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
        // the next edit ends the undo (Scott, 2026-11-17, messages rule): then the pattern goes
        try await idle(core)
        core.handle(json: #"{"intent":"blockDelete","track":2,"block":\#(last.id)}"#)
        try await wait("deleted") { fake.lists[1][last.id].p == 0 }
        try await wait("undo offered") { !core.timelineArea().clearUndo.isEmpty }
        try await idle(core)
        core.handle(json: #"{"intent":"blockNew","track":3}"#)
        #expect(core.timelineArea().clearUndo.isEmpty)
        try await wait("its pattern cleared") { fake.poolLen[lastP - 1] == 0 }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    /// padMove, as the iPad's drag (pattern-pad.md B15–B17): its own row only, a swap with a filled pad, a move onto
    /// an empty one leaving its old place empty, stopped only.
    @Test func padMoveSwapsAndMovesWithinItsTrack() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        // track 2 with three pads: A, B, C
        for _ in 0..<2 {
            try await idle(core)
            core.handle(json: #"{"intent":"blockNew","track":2}"#)
            try await Task.sleep(for: .milliseconds(300))
        }
        try await idle(core)
        try await wait("three pads") { fake.lists[1].filter { $0.p != 0 }.count >= 3 }
        let before = fake.lists[1].map(\.p)
        let used = before.lastIndex { $0 != 0 }!
        // another track: refused, with what to do
        core.handle(json: #"{"intent":"padMove","track":2,"from":0,"toTrack":3,"to":0}"#)
        #expect(box.notices.last?.text.hasPrefix("A pad moves only within its own track") == true && box.notices.last?.track == 2)
        // playing: refused
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: #"{"intent":"padMove","track":2,"from":0,"to":1}"#)
        #expect(box.notices.last?.text.hasPrefix("Stop to rearrange") == true)
        try await stop(core, fake)
        try await idle(core)
        #expect(fake.lists[1].map(\.p) == before)
        // onto a filled pad: the two swap
        core.handle(json: #"{"intent":"padMove","track":2,"from":0,"to":1}"#)
        var want = before; want.swapAt(0, 1)
        try await wait("swapped") { fake.lists[1].map(\.p) == want }
        // onto an empty pad far past the end: it lands on the first empty place, and its old place stays empty
        try await idle(core)
        core.handle(json: #"{"intent":"padMove","track":2,"from":0,"to":12}"#)
        var moved = want; moved[used + 1] = want[0]; moved[0] = 0
        try await wait("moved, the gap kept") { fake.lists[1].map(\.p) == moved }
        // read-only: nothing sent
        try await idle(core)
        box.writes = false
        core.handle(json: #"{"intent":"padMove","track":2,"from":1,"to":2}"#)
        try await Task.sleep(for: .milliseconds(250))
        #expect(fake.lists[1].map(\.p) == moved && box.notices.last?.text == PhoneCore.readOnlyNotice)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    /// clearSteps: the notes wiped step by step while it plays, the pad and its pattern kept, and back with undoClear.
    @Test func clearStepsWipesTheNotesAndPutsThemBack() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let s = core.session
        // a note track that is on a pad with notes in it
        let t = try #require(s.trackIndices.first { k in !s.isKit(k) && s.skiffSong?.song?.tracks[k].entryOn != nil && s.tracks[k].steps.contains { $0.isOn } })
        let e = try #require(s.skiffSong?.song?.tracks[t].entryOn)
        let p = try #require(s.skiffSong?.song?.tracks[t].entries[e].pattern)
        let had = s.tracks[t].steps
        let lists = fake.lists[t].map(\.p), len = fake.poolLen[p - 1]
        // playing: it still goes
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { s.playing }
        guard s.skiffSong?.song?.tracks[t].patternOn == p - 1 else { return }       // (the song moved the track on: not this test's case)
        core.handle(json: #"{"intent":"clearSteps","track":\#(t + 1),"entry":\#(e)}"#)
        try await wait("no notes on the FM-1") { fake.steps[t].allSatisfy { ($0.first ?? 0) == 0 } }       // (a step's first byte: how many notes)
        try await wait("undo offered") { core.padsArea().clearUndo.contains { $0.kind == "steps" && $0.track == t + 1 && $0.entry == e && $0.pattern == p } }
        #expect(fake.lists[t].map(\.p) == lists && fake.poolLen[p - 1] == len, "the pad and its pattern stay")
        #expect(s.tracks[t].steps.allSatisfy { !$0.isOn })
        // a pad the track isn't on, while playing: refused
        if let other = s.skiffSong?.song?.tracks[t].entries.indices.first(where: { $0 != e && s.skiffSong?.song?.tracks[t].entries[$0].poolIndex != nil && s.skiffSong?.song?.tracks[t].entries[$0].poolIndex != p - 1 }) {
            core.handle(json: #"{"intent":"clearSteps","track":\#(t + 1),"entry":\#(other)}"#)
            #expect(box.notices.last?.text.contains("isn't playing that pad") == true)
        }
        // undo: every note back
        core.handle(json: #"{"intent":"undoClear","track":\#(t + 1),"entry":\#(e)}"#)
        try await wait("the notes back") { s.tracks[t].steps.map(\.notes) == had.map(\.notes) && fake.steps[t].filter { ($0.first ?? 0) > 0 }.count == had.filter { !$0.notes.isEmpty }.count }
        if s.tracks[t].steps.map(\.notes) != had.map(\.notes) {
            let bad = had.indices.filter { s.tracks[t].steps[$0].notes != had[$0].notes }
            Issue.record("steps not back: \(bad.prefix(6)) now \(bad.prefix(3).map { s.tracks[t].steps[$0] }) had \(bad.prefix(3).map { had[$0] }); fake on \(fake.steps[t].filter { ($0.first ?? 0) > 0 }.count) of \(had.filter { !$0.notes.isEmpty }.count); notices \(box.notices.map(\.text))")
        }
        #expect(core.padsArea().clearUndo.isEmpty)
        try await stop(core, fake)
        // an empty pad has no notes to clear
        if let empty = s.skiffSong?.song?.tracks[t].entries.firstIndex(where: { $0.isEmpty }) {
            core.handle(json: #"{"intent":"clearSteps","track":\#(t + 1),"entry":\#(empty)}"#)
            #expect(box.notices.last?.text.contains("holds no pattern") == true)
        }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    /// A stable key on every pad and block (EntryKeys.swift): it travels with a move or swap, the others keep theirs
    /// when a block goes, an undo gives the old ones back, and a copy or a new pad gets a new one.
    @Test func padKeysSurviveRewrites() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        // track 3 set up plain: four pads in a row, four patterns of their own, none chained
        let T = 2
        let nums = Array((1...64).filter { fake.poolLen[$0 - 1] == 0 }.prefix(4))
        for p in nums { fake.poolLen[p - 1] = 16 }
        for i in 0..<16 { fake.lists[T][i] = FakeEntry(p: i < 4 ? nums[i] : 0) }
        let n = 4
        func keys() -> [Int] { let k = core.padsArea().rows[T].entries.map(\.key); return k + Array(repeating: 0, count: max(0, 16 - k.count)) }
        func pats() -> [Int] { fake.lists[T].map(\.p) }
        try await wait("the list read") { core.session.skiffSong?.song?.tracks[T].entries.prefix(4).map(\.pattern) == nums
            && core.session.skiffSong?.song?.tracks[T].entries.dropFirst(4).allSatisfy(\.isEmpty) == true
            && nums.allSatisfy { (core.session.skiffSong?.pool?.patterns[$0 - 1].length ?? 0) > 0 } }
        try await idle(core)
        try await wait("pads keyed") { keys().prefix(n).allSatisfy { $0 != 0 } }
        let k0 = Array(keys().prefix(n)), p0 = Array(pats().prefix(n))
        #expect(Set(k0).count == n && keys().dropFirst(n).allSatisfy { $0 == 0 }, "\(keys())")
        // the Timeline's blocks carry the same keys
        #expect(core.timelineArea().tracks[T].blocks.filter { $0.kind != "gap" }.map(\.key) == k0)
        // a swap: the keys travel
        core.handle(json: #"{"intent":"padMove","track":3,"from":0,"to":1}"#)
        try await wait("swapped") { Array(pats().prefix(2)) == [p0[1], p0[0]] }
        try await wait("keys swapped") { Array(keys().prefix(n)) == [k0[1], k0[0]] + k0[2...] }
        try await idle(core)
        core.handle(json: #"{"intent":"padMove","track":3,"from":0,"to":1}"#)
        try await wait("back") { Array(pats().prefix(n)) == p0 && Array(keys().prefix(n)) == k0 }
        // a block deleted in the middle: the ones after it move up with their keys
        try await idle(core)
        core.handle(json: #"{"intent":"blockDelete","track":3,"block":1}"#)
        try await wait("deleted") { Array(pats().prefix(n)) == [p0[0]] + p0[2...] + [0] }
        try await wait("keys moved up") { Array(keys().prefix(n)) == [k0[0]] + k0[2...] + [0] }
        // undo: the old key back in its place
        try await idle(core)
        core.handle(json: #"{"intent":"undoClear"}"#)
        try await wait("undone") { Array(pats().prefix(n)) == p0 }
        try await wait("its key back") { Array(keys().prefix(n)) == k0 }
        // a pad cleared and put back: the same key
        try await idle(core)
        core.handle(json: #"{"intent":"padClear","track":3,"entry":\#(n - 1)}"#)
        try await wait("cleared") { pats()[n - 1] == 0 && keys()[n - 1] == 0 }
        try await idle(core)
        core.handle(json: #"{"intent":"undoClear","track":3,"entry":\#(n - 1)}"#)
        try await wait("back with its key") { pats()[n - 1] == p0[n - 1] && keys()[n - 1] == k0[n - 1] }
        // a duplicate: the copy gets a key of its own, the others keep theirs
        try await idle(core)
        core.handle(json: #"{"intent":"blockDuplicate","track":3,"block":0}"#)
        try await wait("duplicated") { Array(pats().prefix(n + 1)) == [p0[0]] + p0 }
        try await wait("keyed") { keys()[n] != 0 }
        let k1 = Array(keys().prefix(n + 1))
        #expect(k1[0] == k0[0] && Array(k1[2...]) == Array(k0[1...]) && !k0.contains(k1[1]) && k1[1] != 0, "\(k1) from \(k0)")
        // a new pattern: a new key
        try await idle(core)
        core.handle(json: #"{"intent":"blockNew","track":3}"#)
        try await wait("new pad") { pats()[n + 1] != 0 && keys()[n + 1] != 0 }
        #expect(!k1.contains(keys()[n + 1]) && Array(keys().prefix(n + 1)) == k1)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

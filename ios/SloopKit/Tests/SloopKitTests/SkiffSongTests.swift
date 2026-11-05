import Foundation
import Testing
@testable import SloopKit

/// Skiff's song offline: where entries sit in time, the rewrite helper, LIST2 and POOL through FakeSkiff.
@Suite(.serialized) @MainActor struct SkiffSongTests {
    private func list(_ es: [SongEntry], on: Int? = nil) -> SongList {
        SongList(entryOn: on, entries: es + Array(repeating: .empty, count: 16 - es.count))
    }
    private func e(_ p: Int, _ reps: Int = 1, chain: Bool = false) -> SongEntry { SongEntry(pattern: p, reps: reps, chained: chain) }

    // MARK: Time

    @Test func blocksSitBackToBackAsLongAsTheyPlay() {
        // 16 steps at 1/16 is a bar; pattern 2 is 64 steps; pattern 3 is 12 steps at 1/8
        let len: [Int: Int] = [0: 16, 1: 64, 2: 12]
        let div: [Int: Int] = [2: 1]
        let b = SongPlacement.blocks(list([e(1, 4), e(2, 2), e(3, 1)]), length: { len[$0] }, division: { div[$0] },
                                     trackLength: 16, trackDivision: 2)
        #expect(b.map { $0.start / 96 } == [0, 4, 12])
        #expect(b.map { $0.length / 96 } == [4, 8, 1.5])
        #expect(b.map(\.kind) == [.pattern, .pattern, .pattern])
    }

    @Test func restsAndGapsPlayThePatternBeforeThem() {
        // a REST first: the track's own LEN (12 steps); a REST after 64 steps: 4 bars a pass; an empty entry inside
        let b = SongPlacement.blocks(list([e(65, 4), e(1, 1), e(65, 2), .empty, e(1, 1)]),
                                     length: { $0 == 0 ? 64 : nil }, division: { _ in nil }, trackLength: 12, trackDivision: 2)
        #expect(b.map(\.kind) == [.rest, .pattern, .rest, .gap, .pattern])
        #expect(b.map { $0.length / 96 } == [3, 4, 8, 4, 4])
    }

    @Test func aChainIsOneBlockRepeatedWhole() {
        // B and C chained, C ×2: B C B C; D after it; an empty entry ends a chain
        let b = SongPlacement.blocks(list([e(1, 1), e(2, 1, chain: true), e(3, 2), e(4, 1)]),
                                     length: { _ in 16 }, division: { _ in nil }, trackLength: 16, trackDivision: 2)
        #expect(b.count == 3)
        #expect(b[1].entries == 1...2 && b[1].isChain && b[1].reps == 2 && b[1].length / 96 == 4)
        #expect(b[2].start / 96 == 5)
    }

    @Test func entriesOutsideTheListArePassedOver() {
        let b = SongPlacement.blocks(list([.empty, e(1, 2), .empty]), length: { _ in 16 }, division: { _ in nil },
                                     trackLength: 16, trackDivision: 2)
        #expect(b.count == 1 && b[0].entries == 1...1 && b[0].start == 0)
    }

    // MARK: Rewriting

    @Test func insertingRewritesFromTheInsertionPointLastFirst() {
        let old = list([e(1, 4), e(2, 2), e(3, 1)])
        var new = old.entries
        new.insert(e(5, 1), at: 1); new.removeLast()
        let p = ListRewrite.plan(track: 0, from: old, to: new, playing: false, sounds: false)
        #expect(p.needsStop == nil)
        #expect(p.ops == [.set(track: 0, entry: 3, pattern: 3), .reps(track: 0, entry: 3, reps: 1),
                          .set(track: 0, entry: 2, pattern: 2), .reps(track: 0, entry: 2, reps: 2),
                          .set(track: 0, entry: 1, pattern: 5), .reps(track: 0, entry: 1, reps: 1)])
    }

    @Test func deletingClearsLastSoAMovedPatternIsNamedFirst() {
        let old = list([e(1), e(2), e(3)])
        var new = old.entries
        new.remove(at: 0); new.append(.empty)
        let p = ListRewrite.plan(track: 1, from: old, to: new, playing: false, sounds: false)
        #expect(p.ops.last == .clear(track: 1, entry: 2))
        #expect(p.ops.filter { if case .clear = $0 { true } else { false } }.count == 1)
    }

    @Test func playingRefusesWhatSkiffWould() {
        let old = list([e(1, 4), e(2), e(3)], on: 0)
        // ahead of the playhead: fine (the sim takes SET and REPS there, 2026-11-05)
        var ahead = old.entries; ahead[2].reps = 5
        #expect(ListRewrite.plan(track: 0, from: old, to: ahead, playing: true, sounds: false).needsStop == nil)
        // the entry it's on: REPS fine, another pattern launches
        var reps = old.entries; reps[0].reps = 8
        #expect(ListRewrite.plan(track: 0, from: old, to: reps, playing: true, sounds: false).needsStop == nil)
        var swap = old.entries; swap[0].pattern = 9
        #expect(ListRewrite.plan(track: 0, from: old, to: swap, playing: true, sounds: false).needsStop != nil)
        // emptying an entry: CLEAR, stopped only (a REST clears playing too)
        var gone = old.entries; gone[2] = .empty
        #expect(ListRewrite.plan(track: 0, from: old, to: gone, playing: true, sounds: false).needsStop != nil)
        let withRest = list([e(1), e(65)], on: 0)
        var restGone = withRest.entries; restGone[1] = .empty
        #expect(ListRewrite.plan(track: 0, from: withRest, to: restGone, playing: true, sounds: false).needsStop == nil)
    }

    @Test func chainingGoesOutLastFirstAfterTheEntryAfterIt() {
        let old = list([e(1), e(2)])
        var new = old.entries; new[0].chained = true
        #expect(ListRewrite.plan(track: 0, from: old, to: new, playing: false, sounds: false).ops == [.chain(track: 0, entry: 0)])
    }

    // MARK: Through FakeSkiff

    private func store() async throws -> (DeviceSession, FakeSkiff, SkiffSongStore, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load())
        fake.seedSong()
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        let s = try #require(session.skiffSong)
        try await waitFor(5) { s.song != nil && s.pool != nil }
        return (session, fake, s, run)
    }

    @Test func readsBoardAsSong() async throws {
        let (_, _, s, run) = try await store()
        let song = try #require(s.song)
        #expect(song.mode == .on && song.tracks.count == 6)
        #expect(song.tracks[0].entries.prefix(6).map(\.pattern) == [1, 2, 3, 2, 3, 4])
        #expect(song.tracks[1].entries[2].chained && song.tracks[4].entries[1].sound == EntrySound(s0: 3, s1: 2))
        #expect(song.tracks[0].sharing(1) == [3])
        #expect(s.pool?.patterns[7].length == 64 && s.pool?.free == 50)
        // T1: 4 + 8 + 1 + 7 + 1 + 4 bars; T3 (64 steps): 8 + 4 + 8, then a REST of 4
        #expect(s.laneEnds[0] == 25 && s.laneEnds[2] == 24)
        run.cancel()
    }

    @Test func insertingAnEntryRoundTrips() async throws {
        let (_, fake, s, run) = try await store()
        var es = try #require(s.song).tracks[4].entries
        es.insert(SongEntry(pattern: 11, reps: 1), at: 2); es.removeLast()
        #expect(await s.rewrite(track: 4, to: es))
        let got = try #require(s.song).tracks[4].entries
        #expect(got.prefix(6).map(\.pattern) == [65, 12, 11, 13, 12, 12])
        #expect(got[1].sound == EntrySound(s0: 3, s1: 2) && got[4].sound == nil)
        #expect(fake.lists[4][2].p == 11)
        // undo puts it back
        await s.undo()
        #expect(try #require(s.song).tracks[4].entries.prefix(6).map(\.pattern) == [65, 12, 13, 12, 12, 0])
        run.cancel()
    }

    @Test func aRefusalPutsTheListBackWithItsReason() async throws {
        let (_, fake, s, run) = try await store()
        fake.poolLen = Array(repeating: 16, count: 64)            // every number taken
        #expect(await s.send(.new(track: 0, entry: 6)) == false)
        #expect(s.refusal?.text.contains("64 patterns") == true)
        #expect(try #require(s.song).tracks[0].entries[6].isEmpty)
        run.cancel()
    }
}

/// Skiff's drum hits on kit tracks (DRUM, DRUM-X): the lane grid from a step's hit bytes, and back.
@Suite(.serialized) @MainActor struct SkiffKitTests {
    @Test func hitBytesRoundTrip() {
        // kick and bell (lane 7) hit, the bell accented; chance 100, ratchet x2
        var s = SynthStep(notes: [], time: .note, accent: false, slide: false, velocity: 0)
        s.extra = [0b1, 0, 0b11, 100, 2, 0, 0, 32, 0]           // lane 7's hit and accent ride in the third byte
        let d = s.hits
        #expect(d.lanes == [0, 7] && d.level(7) == 3 && d.level(0) == 0 && d.ratchet(0) == 1)
        let back = s.withHits(d)
        #expect(back.extra == s.extra && back.time == .note)
        // clearing every lane of a step without notes makes it a rest; a hit on a rest makes it a note
        let none = s.withHits(.empty)
        #expect(none.time == .rest && none.extra.prefix(3) == [0, 0, 0])
        let one = SynthStep.empty.withHits(DrumStep.empty.setting(3, on: true))
        #expect(one.time == .note && one.extra == [0b1000, 0, 0] && SkiffDriver.encodeStep(one).count == 11)
    }

    @Test func kitTracksShowAndWriteTheirLanes() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        defer { run.cancel() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        // the recorded sim: T4 and T6 on DRUM
        #expect(session.isKit(3) && session.isKit(5) && !session.isKit(0))
        #expect(session.drumLanes.count == 8 && session.drumTrack == nil)
        session.select(track: 3)
        try await waitFor(3) { session.kitTrack == 3 }
        session.toggle(drumIndex: 5, lane: 1)                 // snare on step 6
        try await waitFor(3) { fake.steps[3][5].count >= 11 && fake.steps[3][5][8] == 0b10 }
        #expect(session.tracks[3].gridSteps[5].lanes == [1] && session.tracks[3].isOn(5))
        session.toggle(drumIndex: 5, lane: 1)
        try await waitFor(3) { fake.steps[3][5][8] == 0 }
    }
}

extension SkiffKitTests {
    @Test func notesShowOnTheirLanesAndAnEditOwnsTheLane() {
        // a kick note (36) and a low tom (41, on TOM): the grid shows KICK and TOM
        var s = SynthStep(notes: [36, 41], time: .note, accent: false, slide: false, velocity: 100)
        s.extra = [0, 0, 0, 100, 1, 0, 0, 32, 0]
        #expect(s.kitLanes.lanes == [0, 5] && s.hits.lanes == [])
        #expect(SynthStep.lane(ofNote: 49) == 7 && SynthStep.lane(ofNote: 100) == SynthStep.lane(ofNote: 40))
        // turning TOM off takes its note; KICK keeps its note; adding SNARE is a hit
        let t = s.withHits(s.kitLanes.setting(5, on: false).setting(1, on: true))
        #expect(t.notes == [36] && t.hits.lanes == [1] && t.kitLanes.lanes == [0, 1])
        // accenting KICK makes the note its hit
        let u = t.withHits(t.kitLanes.setting(0, on: true, level: 3))
        #expect(u.notes.isEmpty && u.hits.lanes == [0, 1] && u.hits.level(0) == 3 && u.time == .note)
    }
}

/// Sections (board 3): a bar range across the lanes, each track snapped to its own passes.
@Suite struct SongSectionTests {
    private func list(_ es: [SongEntry]) -> SongList { SongList(entries: es + Array(repeating: .empty, count: 16 - es.count)) }
    private func e(_ p: Int, _ reps: Int = 1, chain: Bool = false) -> SongEntry { SongEntry(pattern: p, reps: reps, chained: chain) }
    private func blocks(_ l: SongList, len: [Int: Int] = [:], trackLength: Int = 16) -> [SongBlock] {
        SongPlacement.blocks(l, length: { len[$0] ?? 16 }, division: { _ in nil }, trackLength: trackLength, trackDivision: 2)
    }
    private let bar = SongPlacement.ticksPerBar

    @Test func duplicatingBars5to12AddsLinkedCopies() {
        let l = list([e(1, 4), e(2, 8), e(3, 1)])
        let p = SongSections.plan(track: 0, list: l, blocks: blocks(l), from: 4 * bar, to: 12 * bar, op: .duplicateAfter)
        #expect(p.exact && p.splits.isEmpty)
        #expect(p.result?.prefix(5).map(\.pattern) == [1, 2, 2, 3, 0])
        #expect(p.result?.prefix(4).map(\.reps) == [4, 8, 8, 1])
    }

    @Test func aPassBoundaryInsideAnEntrySplitsIt() {
        // T3 on 64 steps: 08 ×2 is bars 1–8, so bars 5–12 start at its 2nd pass
        let l = list([e(8, 2), e(9, 1), e(8, 2), e(65, 1)])
        let p = SongSections.plan(track: 2, list: l, blocks: blocks(l, len: [7: 64, 8: 64]), from: 4 * bar, to: 12 * bar, op: .duplicateAfter)
        #expect(p.exact && p.splits == ["Splits A at its 2nd pass"])
        #expect(p.result?.prefix(7).map(\.pattern) == [8, 8, 9, 8, 9, 8, 65])
        #expect(p.result?.prefix(7).map(\.reps) == [1, 1, 1, 1, 1, 2, 1])
    }

    @Test func passesThatCantMeetTheRangeSayWhatSnappingCosts() {
        // 12 steps: ¾-bar passes after a 3-bar REST
        let l = list([e(65, 4), e(10, 16)])
        let p = SongSections.plan(track: 3, list: l, blocks: blocks(l, len: [9: 12], trackLength: 12), from: 4 * bar, to: 12 * bar, op: .clear)
        #expect(!p.exact && p.from == 3.75 * bar && p.to == 12 * bar)
        #expect(p.cost(rangeBars: 8) == "Bars 4¾–12: 8¼ bars, ¼ more")
        #expect(p.result?.prefix(3).map(\.pattern) == [65, 10, 0] && p.result?[1].reps == 5)
    }

    @Test func clearingRemovesTheBarsAndAChainStaysWhole() {
        // B–C chained ×2 (bars 5–8), then D: clearing bars 5–8 leaves A, D
        let l = list([e(1, 4), e(2, 1, chain: true), e(3, 2), e(4, 1)])
        let p = SongSections.plan(track: 1, list: l, blocks: blocks(l), from: 4 * bar, to: 8 * bar, op: .clear)
        #expect(p.result?.prefix(3).map(\.pattern) == [1, 4, 0])
        // duplicating one time through the chain copies both parts, chained
        let d = SongSections.plan(track: 1, list: l, blocks: blocks(l), from: 4 * bar, to: 6 * bar, op: .duplicateAfter)
        #expect(d.result?.prefix(7).map(\.pattern) == [1, 2, 3, 2, 3, 2, 3])
        #expect(d.result?.prefix(7).map(\.chained) == [false, true, false, true, false, true, false])
        #expect(d.splits == ["Splits B at its 2nd pass"])
    }

    @Test func noRoomIsRefused() {
        let l = list((0..<15).map { _ in e(1, 1) } + [e(2, 1)])
        let p = SongSections.plan(track: 0, list: l, blocks: blocks(l), from: 0, to: 4 * bar, op: .duplicateAfter)
        #expect(p.result == nil && p.refusal?.contains("16") == true)
    }
}

extension SkiffSongTests {
    @Test func emptyEntriesRepsMatterOnlyInsideTheList() {
        var old = list([e(1), .empty, e(2)])
        old.entries[1].reps = 3; old.entries[9].reps = 7                 // a rest of 3 inside; leftover REPS outside
        var new = old.entries
        new[9].reps = 1
        #expect(ListRewrite.plan(track: 0, from: old, to: new, playing: false, sounds: false).ops.isEmpty)
        new[1].reps = 2
        #expect(ListRewrite.plan(track: 0, from: old, to: new, playing: false, sounds: false).ops == [.reps(track: 0, entry: 1, reps: 2)])
    }
}

extension SongSectionTests {
    @Test func aDropInsideARepeatingEntrySplitsIt() {
        let l = list([e(1, 4), e(2, 2)])
        // bar 3 is inside A's passes: A ×2, the new entry, A ×2, B
        let r = SongSections.insert(e(9), list: l, blocks: blocks(l), at: 2.1 * bar)
        #expect(r.index == 1 && r.at == 2 * bar && r.split == "splits A after its 2nd pass")
        #expect(r.result?.prefix(5).map(\.pattern) == [1, 9, 1, 2, 0] && r.result?.prefix(4).map(\.reps) == [2, 1, 2, 2])
        // at an entry's edge, nothing splits
        let s = SongSections.insert(e(9), list: l, blocks: blocks(l), at: 4.2 * bar)
        #expect(s.index == 1 && s.split == nil && s.result?.prefix(3).map(\.pattern) == [1, 9, 2])
    }
}

/// The review's findings (2026-11-05), each pinned.
extension SkiffSongTests {
    @Test func oneChangeAtATime() async throws {
        let (_, _, s, run) = try await store()
        var a = try #require(s.song).tracks[0].entries; a[0].reps = 3
        var b = try #require(s.song).tracks[1].entries; b[1].reps = 3
        async let x = s.rewrite(track: 0, to: a)
        async let y = s.rewrite(track: 1, to: b)
        let (ok1, ok2) = await (x, y)
        #expect(ok1 != ok2)                                       // one went in, the other was refused
        #expect(s.refusal?.text.contains("One change at a time") == true || ok1 && ok2 == false)
        run.cancel()
    }

    @Test func aClearThatErasesAPatternAsksFirst() async throws {
        let (_, fake, s, run) = try await store()
        // T1's F names 04, and nothing else does: deleting it would erase 04
        var es = try #require(s.song).tracks[0].entries
        es[5] = .empty
        #expect(await s.rewrite(track: 0, to: es) == false)
        let c = try #require(s.confirmation)
        #expect(c.title == "Erase pattern 04?" && fake.lists[0][5].p == 4)
        s.confirmation = nil
        await c.action()
        #expect(fake.lists[0][5].p == 0 && fake.poolLen[3] == 0)
        // deleting a middle entry keeps its pattern (named again elsewhere, or left unused): no question
        var mid = try #require(s.song).tracks[0].entries
        mid.remove(at: 1); mid.append(.empty)                     // B (02) also on D
        #expect(await s.rewrite(track: 0, to: mid) && s.confirmation == nil)
        run.cancel()
    }

    @Test func aFreePatternIsRefusedBeforeAnythingIsSent() async throws {
        let (_, fake, s, run) = try await store()
        let before = fake.lists[4]
        var es = try #require(s.song).tracks[4].entries
        es.insert(SongEntry(pattern: 40, reps: 1), at: 1); es.removeLast()
        #expect(await s.rewrite(track: 4, to: es) == false)
        #expect(s.refusal?.text.contains("Pattern 40 is empty") == true && fake.lists[4] == before)
        run.cancel()
    }

    @Test func aSectionIsAllOrNothing() async throws {
        let (_, fake, s, run) = try await store()
        let before = fake.lists
        let song = try #require(s.song)
        var plans = song.tracks.indices.map { t in
            SongSections.plan(track: t, list: song.tracks[t], blocks: s.blocks(t), from: 4 * 96, to: 12 * 96, op: .duplicateAfter)
        }
        plans[3].refusal = "T4 would need 17 entries; it has 16"
        let refused = await s.apply(section: plans)
        #expect(refused[3] != nil && fake.lists == before)
        #expect(s.refusal?.text.hasPrefix("Nothing changed") == true)
        run.cancel()
    }
}

extension SongSectionTests {
    @Test func aRestLeftAtAnEdgeStaysARest() {
        // A, a 2-pass rest (empty entry), B: clearing A's bars leaves the rest first, so it becomes a REST
        var l = list([e(1, 1), .empty, e(2, 1)])
        l.entries[1].reps = 2
        let p = SongSections.plan(track: 0, list: l, blocks: blocks(l), from: 0, to: 1 * bar, op: .clear)
        #expect(p.result?.prefix(3).map(\.pattern) == [65, 2, 0] && p.result?[0].reps == 2)
        #expect(SongSections.restsAtEdges([.empty, e(2), .empty], range: 0..<3).map(\.pattern) == [65, 2, 65])
    }

    @Test func aDanglingChainComesOff() {
        let es = SongSections.unchainDangling([e(1, chain: true), .empty, e(2, chain: true), e(3)])
        #expect(es.map(\.chained) == [false, false, true, false])
    }
}

extension SkiffKitTests {
    @Test func theStepRatchetGoesDownAsWellAsUp() {
        var s = SynthStep(notes: [36], time: .note, accent: false, slide: false, velocity: 100)
        s.extra = [0b1000, 0, 0, 100, 2, 0, 0, 32, 0]               // a hat hit and a kick note, ×2
        let d = s.kitLanes
        #expect(d.lanes == [0, 3] && d.ratchet(0) == 1 && d.ratchet(3) == 1)
        let down = s.withHits(d.setting(0, on: true, level: 0, ratchet: 0))
        #expect(down.extra[4] == 1 && down.notes == [36])            // ×1, and the kick note untouched
        // a REST's stale hit bytes don't show, and a lane turned on doesn't wake them
        var r = s; r.time = .rest; r.notes = []
        #expect(r.kitLanes.isOn == false)
        #expect(r.withHits(DrumStep.empty.setting(1, on: true)).hits.lanes == [1])
    }
}

/// Moving a block within its track (Scott, 2026-11-05): a reorder, a REST to hold a gap past the end.
extension SongSectionTests {
    @Test func movingEarlierAndLaterIsAReorder() {
        let l = list([e(1, 4), e(2, 8), e(3, 1), e(4, 2)])
        let b = blocks(l)
        // D to the front: everything else moves over
        let early = SongSections.move(list: l, blocks: b, block: 3, to: 0)
        #expect(early.index == 0 && !early.unchanged && early.result?.prefix(5).map(\.pattern) == [4, 1, 2, 3, 0])
        #expect(early.result?.prefix(4).map(\.reps) == [2, 4, 8, 1])
        // A after C: B and C close up
        let late = SongSections.move(list: l, blocks: b, block: 0, to: 2)
        #expect(late.index == 2 && late.result?.prefix(4).map(\.pattern) == [2, 3, 1, 4])
        // dropped where it was: nothing to send
        #expect(SongSections.move(list: l, blocks: b, block: 1, to: 1).unchanged)
    }

    @Test func pastTheEndARestHoldsTheGap() {
        let l = list([e(1, 4), e(2, 2)])
        let m = SongSections.move(list: l, blocks: blocks(l), block: 0, to: 1, restPasses: 3)
        #expect(m.rests == 1 && m.index == 2)
        #expect(m.result?.prefix(4).map(\.pattern) == [2, 65, 1, 0] && m.result?.prefix(3).map(\.reps) == [2, 3, 4])
        // more than 16 passes: a second REST
        let far = SongSections.move(list: l, blocks: blocks(l), block: 0, to: 1, restPasses: 20)
        #expect(far.rests == 2 && far.result?.prefix(4).map(\.reps) == [2, 16, 4, 4])
    }

    @Test func aFullTrackCantTakeTheRest() {
        let l = list((0..<16).map { e($0 + 1, 1) })
        #expect(SongSections.move(list: l, blocks: blocks(l), block: 0, to: 15, restPasses: 1).result == nil)
        // a plain reorder needs no extra entry
        #expect(SongSections.move(list: l, blocks: blocks(l), block: 0, to: 15).result?[15].pattern == 1)
    }

    @Test func aChainMovesAsOne() {
        // REST, 05, 06→07 chained ×2, 05: the chain to the front keeps its flag and its REPS
        let l = list([e(65, 4), e(5, 8), e(6, 1, chain: true), e(7, 2), e(5, 8)])
        let m = SongSections.move(list: l, blocks: blocks(l), block: 2, to: 0)
        #expect(m.result?.prefix(6).map(\.pattern) == [6, 7, 65, 5, 5, 0])
        #expect(m.result?.prefix(5).map(\.chained) == [true, false, false, false, false])
        #expect(m.result?.prefix(5).map(\.reps) == [1, 2, 4, 8, 8])
    }

    @Test func anEmptyEntryMovedToTheEndBecomesARest() {
        // entries before the list's first stay passed over; an empty entry moved to the end becomes a REST
        var l = list([.empty, e(1, 1), .empty, e(2, 1)])
        l.entries[2].reps = 2
        let m = SongSections.move(list: l, blocks: blocks(l), block: 1, to: 2)
        #expect(m.result?.prefix(5).map(\.pattern) == [0, 1, 2, 65, 0] && m.result?[3].reps == 2)
    }
}

extension SkiffSongTests {
    @Test func movesRoundTripThroughTheFake() async throws {
        let (_, fake, s, run) = try await store()
        // T1 (A–F: 01 02 03 02 03 04): F to the front
        var l = try #require(s.song).tracks[0]
        var m = SongSections.move(list: l, blocks: s.blocks(0), block: 5, to: 0)
        #expect(await s.rewrite(track: 0, to: try #require(m.result)) && s.confirmation == nil)
        #expect(fake.lists[0].prefix(7).map(\.p) == [4, 1, 2, 3, 2, 3, 0])
        // then the new B (01 ×4) after the last, with 2 passes of REST before it
        l = try #require(s.song).tracks[0]
        m = SongSections.move(list: l, blocks: s.blocks(0), block: 1, to: 5, restPasses: 2)
        #expect(await s.rewrite(track: 0, to: try #require(m.result)))
        #expect(fake.lists[0].prefix(8).map(\.p) == [4, 2, 3, 2, 3, 65, 1, 0])
        #expect(try #require(s.song).tracks[0].entries[5].reps == 2)
        // T2's chain 06→07 to the front moves whole, still chained
        l = try #require(s.song).tracks[1]
        m = SongSections.move(list: l, blocks: s.blocks(1), block: 2, to: 0)
        #expect(await s.rewrite(track: 1, to: try #require(m.result)))
        let t2 = try #require(s.song).tracks[1]
        #expect(t2.entries.prefix(5).map(\.pattern) == [6, 7, 65, 5, 5] && t2.entries[0].chained && !t2.entries[1].chained)
        // undo puts T2 back
        await s.undo()
        #expect(try #require(s.song).tracks[1].entries.prefix(5).map(\.pattern) == [65, 5, 6, 7, 5])
        run.cancel()
    }

    @Test func aMoveThatWouldCutInWaitsForStop() async throws {
        let (session, fake, s, run) = try await store()
        session.setPlaying(true)
        try await waitFor(5) { session.playing }
        let before = fake.lists[0]
        // T1 is on A: moving it changes the pattern on the entry it's playing
        let l = try #require(s.song).tracks[0]
        let m = SongSections.move(list: l, blocks: s.blocks(0), block: 0, to: 2)
        #expect(await s.rewrite(track: 0, to: try #require(m.result)) == false)
        #expect(s.refusal?.needsStop == true && fake.lists[0] == before)
        session.setPlaying(false)
        run.cancel()
    }
}

/// Found on the real FM-1 with Skiff 2.2 (2026-11-05): the keyboard, the iPad's sound, each lane's pass.
@Suite(.serialized) @MainActor struct SkiffOnTheDeviceTests {
    @Test func theKeyboardPlaysOnTheSelectedTracksChannel() {
        // Skiff's MIDI IN CH1-6 drops channel 16; track k listens on channel k + 1
        #expect(DeviceSession.keyChannel(.skiff, track: 0) == 0)
        #expect(DeviceSession.keyChannel(.skiff, track: 5) == 5)
        // SLOOP routes channel 16 to the selected track
        #expect(DeviceSession.keyChannel(.sloop, track: 3) == 15)
    }

    @Test func passProgressCountsThroughEachPass() {
        // 4 steps of 1/16 (6 ticks): a pass is 24 ticks
        var c = CountedPlayhead(tracks: 1)
        let s = [CountedPlayhead.Settings(length: 4, division: 2)]
        #expect(c.passProgress(0, at: 0, length: 4) == nil)            // stopped
        c.start()
        c.tick(s, globalSwing: 0)                                      // tick 0: step 0
        #expect(c.passProgress(0, at: 0, length: 4) == 0)
        for _ in 0..<12 { c.tick(s, globalSwing: 0) }                  // tick 12: step 2
        #expect(c.passProgress(0, at: 12, length: 4) == 0.5)
        #expect(abs(c.passProgress(0, at: 15, length: 4)! - 0.625) < 0.001)
        for _ in 0..<12 { c.tick(s, globalSwing: 0) }                  // tick 24: the next pass
        #expect(c.passProgress(0, at: 24, length: 4) == 0)
    }

    @Test func playingThroughTheIPadSetsUSBLevelFixed() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        #expect(session.canQuietSpeaker == false)
        session.muteSpeaker(true)
        try await waitFor(5) { session.usbAudioFull == true }
        #expect(fake.usbLevel == 1 && session.usbAudioProblem == nil)
        run.cancel()
    }
}

extension SkiffOnTheDeviceTests {
    @Test func recStopsRecordingWhateverTrackIsSelected() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        session.toggleRec()                                          // T1 armed, playing
        try await waitFor(5) { session.recording && fake.armed == 1 }
        session.select(track: 1)
        try await waitFor(5) { fake.selected == 1 }
        session.toggleRec()                                          // stop, with T2 selected
        try await waitFor(5) { !session.recording }
        #expect(fake.armed == 0 && fake.playing)                     // nothing armed, still playing
        session.toggleRec()                                          // and REC on T2 arms T2 alone
        try await waitFor(5) { session.recording }
        #expect(fake.armed == 0b10)
        run.cancel()
    }
}

extension SkiffOnTheDeviceTests {
    @Test func theTempoSetsWithinItsRangeAndNotOnAnotherClock() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        try await waitFor(5) { !session.globalDescs.isEmpty }
        // from DESC: BPM 40–240, and Skiff's clock source is CLOCK (global 2), not its empty SYNC slot
        #expect(session.bpmRange == 40...240)
        #expect(session.clockSourceID == 2 && session.externalClock == nil)
        session.setBPM(150)
        try await waitFor(5) { fake.globals[0] == 150 }
        #expect(session.bpm == 150)
        session.setBPM(999)                                           // clamped
        try await waitFor(5) { fake.globals[0] == 240 }
        // following USB clock: the tempo is the other device's
        fake.globals[2] = 1
        await session.refreshTempo()
        #expect(session.externalClock == "USB")
        session.setBPM(100)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.globals[0] == 240 && session.bpm == 240)
        run.cancel()
    }
}

/// Jib's screen link patch on Skiff 2.2 (skiff/README.md), through FakeSkiff.
@Suite(.serialized) @MainActor struct SkiffScreenLinkTests {
    private func connect(link: Bool) async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load())
        fake.screenLink = link
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        return (session, fake, run)
    }

    @Test func stockSkiffHasNoLink() async throws {
        let (s, fake, run) = try await connect(link: false)
        #expect(!s.screenLinked && s.deviceScreen == nil && !fake.screenWatched)
        run.cancel()
    }

    @Test func thePatchIsFoundInINFOAndFollowed() async throws {
        let (s, fake, run) = try await connect(link: true)
        try await waitFor(5) { s.screenLinked && fake.screenWatched }
        #expect(s.capabilities.contains(.screenLink) && s.deviceScreen?.home == true)
        // a button on the FM-1: DELAY (31)
        fake.pressOnDevice(page: 31)
        try await waitFor(5) { s.deviceScreen?.page == 31 && s.deviceScreen?.home == false }
        // another track selected on the FM-1 comes with the screen
        fake.pressOnDevice(page: 31, track: 2)
        try await waitFor(5) { s.selectedTrack == 2 }
        run.cancel()
    }

    @Test func goingToAPageAndARefusal() async throws {
        let (s, fake, run) = try await connect(link: true)
        try await waitFor(5) { s.screenLinked }
        s.showOnDevice(page: 43)                                         // PATTERN
        try await waitFor(5) { fake.screen.page == 43 && s.deviceScreen?.page == 43 }
        s.showOnDevice(page: 18)                                         // LANES on an ANALOG track: refused
        try await waitFor(5) { s.deviceScreen?.page == 43 }              // put back from the reply, not a timeout
        #expect(fake.screen.page == 43)
        s.showOnDevice(page: 127)                                        // HOME
        try await waitFor(5) { fake.screen.home && s.deviceScreen?.home == true }
        run.cancel()
    }
}

extension SkiffOnTheDeviceTests {
    /// A song entry with its own sound loads it as the entry starts: a burst of CHANGED (or a RELOAD). That isn't a
    /// knob turned on the FM-1, so Shape mustn't follow it to a page (it jumped to EDIT bar by bar).
    @Test func aSoundLoadingIsNotAKnobTurn() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        try await waitFor(5) { fake.watching }
        func changed(_ id: Int, _ v: Int) { fake.push(23, [0, UInt8(id)] + Frame.v14(v)) }
        // an entry's sound: many parameters at once
        for (k, id) in [1, 2, 3, 4, 9, 10, 63, 64].enumerated() { changed(id, 20 + k) }
        try await Task.sleep(for: .milliseconds(400))
        #expect(session.lastTouched == nil)
        // a RELOAD (another engine or preset), then a value
        fake.push(24, [1, 3, 0])
        changed(63, 50)
        try await Task.sleep(for: .milliseconds(400))
        #expect(session.lastTouched == nil)
        // later, one knob turned on the FM-1: followed
        try await Task.sleep(for: .milliseconds(400))
        changed(34, 70); changed(34, 72)
        try await waitFor(5) { session.lastTouched?.id == 34 }
        run.cancel()
    }
}

extension SkiffOnTheDeviceTests {
    /// Skiff records knob moves (Jib's SET / TRACK_PARAM too) while the selected track is armed and playing: Scott
    /// recorded edits by accident. Jib reads MOTION, says it's recording, and clears a track's motion.
    @Test func motionIsReadFlaggedAndCleared() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        session.toggleRec()                                           // T1 armed, playing
        try await waitFor(5) { session.recordingKnobs }
        session.set(track: 0, param: 34, to: 90)                      // an edit from the iPad: recorded
        try await waitFor(5) { fake.motion[0].count == 1 }
        await session.readMotion(track: 0)
        #expect(session.motion[0]?.steps == [0] && session.motion[0]?.recorded == 1 && session.motion[0]?.on == true)
        session.clearMotion(track: 0)
        try await waitFor(5) { session.motion[0]?.events.isEmpty == true }
        #expect(fake.motion[0].isEmpty)
        session.toggleRec()                                           // stop recording
        try await waitFor(5) { !session.recordingKnobs }
        run.cancel()
    }
}

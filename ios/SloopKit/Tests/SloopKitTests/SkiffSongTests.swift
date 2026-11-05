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

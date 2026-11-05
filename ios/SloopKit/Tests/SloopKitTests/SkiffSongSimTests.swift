import Foundation
import Testing
@testable import SloopKit

/// The song lists against skiff-sim (SKIFF_SIM=1, the sim running), as SkiffSimTests. They change the sim's
/// lists on T6 (track 5) and put them back.
///   SKIFF_SIM=1 swift test --filter SkiffSongSimTests
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct SkiffSongSimTests {
    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return s
    }

    private func line(_ s: SkiffSong, _ t: Int) -> String {
        let l = s.tracks[t]
        let es = l.entries.prefix(6).map { e in e.isEmpty ? "--" : e.isRest ? "R×\(e.reps)" : "\(e.pattern)×\(e.chained ? "ch" : "\(e.reps)")" }
        return "T\(t + 1) on \(l.entryOn.map(String.init) ?? "-") staged \(l.staged.map(String.init) ?? "-") pat \(l.patternOn.map(String.init) ?? "-"): \(es.joined(separator: " "))"
    }

    private func clearT6(_ d: SkiffDriver) async throws {
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        let s = try await d.songLists()
        for i in stride(from: 15, through: 0, by: -1) where !s.tracks[5].entries[i].isEmpty {
            _ = try await d.list(.clear(track: 5, entry: i))
        }
    }

    /// The spec's open question (skiff-arrange-spec.md "Rules"): can entries be rearranged while playing?
    @Test func rearrangingWhilePlaying() async throws {
        let d = try await driver()
        #expect(d.skiff.hasSongLists)
        try await clearT6(d)
        // stopped: A and B new patterns, C a copy of A's pattern name, the track on A
        var r = try await d.list(.new(track: 5, entry: 0)); print("NEW A", r.rc, line(r.song, 5))
        r = try await d.list(.new(track: 5, entry: 1)); print("NEW B", r.rc, line(r.song, 5))
        let pa = r.song.tracks[5].entries[0].pattern, pb = r.song.tracks[5].entries[1].pattern
        r = try await d.list(.reps(track: 5, entry: 0, reps: 4)); print("REPS A 4", r.rc, line(r.song, 5))
        r = try await d.list(.play(track: 5, entry: 0)); print("PLAY A", r.rc, line(r.song, 5))
        r = try await d.list(.song(.on)); print("SONG ON", r.rc)

        _ = try await d.transport(play: true)
        try await Task.sleep(for: .milliseconds(400))
        var s = try await d.songLists(); print("playing", line(s, 5))

        // an entry ahead of the playhead
        r = try await d.list(.set(track: 5, entry: 2, pattern: pa)); print("SET C (ahead) =A's", r.rc, line(r.song, 5))
        r = try await d.list(.reps(track: 5, entry: 2, reps: 2)); print("REPS C 2", r.rc, line(r.song, 5))
        // the staged entry (B is next)
        r = try await d.list(.reps(track: 5, entry: 1, reps: 3)); print("REPS B (staged) 3", r.rc, line(r.song, 5))
        // the entry it is on: REPS, then SET
        r = try await d.list(.reps(track: 5, entry: 0, reps: 8)); print("REPS A (on) 8", r.rc, line(r.song, 5))
        r = try await d.list(.set(track: 5, entry: 0, pattern: pb)); print("SET A (on) =B's", r.rc, line(r.song, 5))
        try await Task.sleep(for: .milliseconds(150))
        s = try await d.songLists(); print("  150 ms later", line(s, 5))
        try await Task.sleep(for: .milliseconds(1500))
        s = try await d.songLists(); print("  1.65 s later", line(s, 5))
        // CLEAR a pattern entry, and a REST, playing
        r = try await d.list(.clear(track: 5, entry: 2)); print("CLEAR C playing", r.rc, line(r.song, 5))
        r = try await d.list(.set(track: 5, entry: 3, pattern: SongEntry.rest)); print("SET D REST", r.rc, line(r.song, 5))
        r = try await d.list(.clear(track: 5, entry: 3)); print("CLEAR D (REST) playing", r.rc, line(r.song, 5))
        // CHAIN and sound while playing
        r = try await d.list(.chain(track: 5, entry: 1)); print("CHAIN B playing", r.rc, line(r.song, 5))
        r = try await d.list(.reps(track: 5, entry: 1, reps: 1)); print("unCHAIN B", r.rc, line(r.song, 5))
        let p = try await d.pool(); print("pool free", p.free, "unused", p.unused, "A's len", p.patterns[pa - 1].length)

        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(300))
        r = try await d.list(.song(.off)); print("SONG OFF", r.rc)
        try await clearT6(d)
        s = try await d.songLists(); print("after", line(s, 5))
        #expect(s.tracks[5].used == 0)
        await d.close()
    }

    /// The store's writes against the sim: each one read back with LIST2 matches what was drawn.
    @Test func storeWritesRoundTrip() async throws {
        let d0 = try await driver()
        try await clearT6(d0)
        await d0.close()
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return MIDITransport() })
        let run = Task { await session.run() }
        defer { run.cancel() }
        try await waitFor(20) { if case .connected = session.status { true } else { false } }
        let s = try #require(session.skiffSong)
        try await waitFor(5) { s.song != nil }
        func t6() -> [SongEntry] { s.song!.tracks[5].entries }
        func check(_ what: String) async throws {
            let drawn = t6()
            await s.refresh(pool: true)
            print(what, t6().prefix(6).map { $0.isEmpty ? "--" : "\($0.pattern)×\($0.chained ? "ch" : String($0.reps))" })
            #expect(t6() == drawn, "\(what): read back as drawn")
        }
        // NEW twice (two new empty patterns), then the rewrites
        #expect(await s.send(.new(track: 5, entry: 0)))
        #expect(await s.send(.new(track: 5, entry: 1)))
        let a = t6()[0].pattern, b = t6()[1].pattern
        try await check("two new")
        var es = t6()
        es.insert(SongEntry(pattern: SongEntry.rest, reps: 2), at: 1); es.removeLast()
        #expect(await s.rewrite(track: 5, to: es)); try await check("REST inserted at B")
        es = t6(); es[2].reps = 7
        #expect(await s.rewrite(track: 5, to: es)); try await check("REPS 7")
        es = t6(); es.insert(SongEntry(pattern: a, reps: 3), at: 3); es.removeLast()
        #expect(await s.rewrite(track: 5, to: es)); try await check("A again at D (linked)")
        es = t6(); es[0].chained = true
        #expect(await s.rewrite(track: 5, to: es)); try await check("A chained into the REST")
        es = t6(); es.remove(at: 1); es.append(.empty)
        #expect(await s.rewrite(track: 5, to: es)); try await check("REST deleted")
        #expect(t6().prefix(4).map(\.pattern) == [a, b, a, 0])
        await s.undo(); try await check("undo")
        #expect(t6()[1].isRest)
        // COPY: make unique, then COPY+
        #expect(await s.send(.copy(track: 5, entry: 3))); try await check("make unique D")
        #expect(t6()[3].pattern != a)
        #expect(await s.send(.copyPlus(track: 5, entry: 0))); try await check("COPY+ A")
        // playing: a REPS ahead is taken, a delete is refused before anything is sent
        _ = try await session.skiffSongDriverForTests?.transport(play: true)
        try await waitFor(3) { session.playing }
        es = t6(); es[3].reps = 2
        #expect(await s.rewrite(track: 5, to: es)); try await check("REPS ahead, playing")
        es = t6(); es[3] = .empty
        #expect(await s.rewrite(track: 5, to: es) == false)
        #expect(s.refusal?.needsStop == true)
        _ = try await session.skiffSongDriverForTests?.transport(play: false)
        try await waitFor(3) { !session.playing }
        let d = try #require(session.skiffSongDriverForTests)
        try await clearT6(d)
        await s.refresh(pool: true)
        #expect(s.song!.tracks[5].used == 0)
    }

    /// A lane on a kit track: written as the step's hit bytes, read back from the sim.
    @Test func kitLaneRoundTrips() async throws {
        let d = try await driver()
        let names = d.info.engines
        let tracks = try await d.tracks()
        guard let t = tracks.tracks.indices.first(where: { ["DRUM", "DRUM-X"].contains(names[safe: tracks.tracks[$0].engine] ?? "") }) else {
            print("no kit track on the sim"); await d.close(); return
        }
        let before = try await d.synthStep(track: t, index: 62)
        let on = before.withHits(before.hits.setting(4, on: true, level: 3))      // an accented open hat
        let got = try await d.setSynthStep(track: t, index: 62, on)
        print("kit T\(t + 1) step 63:", got.extra.prefix(5).map { $0 })
        #expect(got.hits.has(4) && got.hits.level(4) == 3 && got.time == .note)
        _ = try await d.setSynthStep(track: t, index: 62, before)
        #expect(try await d.synthStep(track: t, index: 62).hits == before.hits)
        await d.close()
    }
}


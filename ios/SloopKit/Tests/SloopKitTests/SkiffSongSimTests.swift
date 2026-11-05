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
        try await waitFor(20) { if case .connected = session.status { true } else { false } }
        let s = try #require(session.skiffSong)
        try await waitFor(5) { s.song != nil }
        func t6() -> [SongEntry] { s.song!.tracks[5].entries }
        func check(_ what: String) async throws {
            let drawn = t6()
            await s.refresh(pool: true)
            print(what, t6().prefix(6).map { $0.isEmpty ? "--" : "\($0.pattern)×\($0.chained ? "ch" : String($0.reps))" })
            #expect(SongList(entries: t6()).playing == SongList(entries: drawn).playing, "\(what): read back as drawn")
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
        run.cancel(); _ = await run.value                 // the port free for the next test
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

    /// A section on the sim: T6's bars duplicated after themselves, an entry split, read back as planned.
    @Test func sectionRoundTrips() async throws {
        let d0 = try await driver()
        try await clearT6(d0)
        await d0.close()
        // a fresh transport each try: right after the driver above lets go, the first connect can miss
        let session = DeviceSession(transport: { MIDITransport() })
        let run = Task { await session.run() }
        try await waitFor(20) { if case .connected = session.status { true } else { false } }
        let s = try #require(session.skiffSong)
        try await waitFor(5) { s.song != nil }
        #expect(await s.send(.new(track: 5, entry: 0)))
        #expect(await s.send(.new(track: 5, entry: 1)))
        let pa = s.song!.tracks[5].entries[0].pattern, pb = s.song!.tracks[5].entries[1].pattern
        var es = Array(repeating: SongEntry.empty, count: 16)
        es[0] = SongEntry(pattern: pa, reps: 4); es[1] = SongEntry(pattern: pb, reps: 2)
        #expect(await s.rewrite(track: 5, to: es))
        await s.refresh(pool: true)
        #expect(s.song!.tracks[5].playing == SongList(entries: es).playing, "T6 set up as A ×4, B ×2")
        // A's 3rd pass to B's 1st: splits both
        let blocks = s.blocks(5)
        let from = blocks[0].start + 2 * blocks[0].pass, to = blocks[1].start + blocks[1].pass
        let plan = SongSections.plan(track: 5, list: s.song!.tracks[5], blocks: blocks, from: from, to: to, op: .duplicateAfter)
        print("section on T6: splits \(plan.splits)")
        #expect(plan.splits == ["Splits A at its 3rd pass", "Splits B at its 2nd pass"])
        let planned = try #require(plan.result)
        let refused = await s.apply(section: [plan])
        #expect(refused.isEmpty)
        await s.refresh(pool: true)
        #expect(s.song!.tracks[5].playing == SongList(entries: planned).playing)
        print("T6 after:", s.song!.tracks[5].entries.prefix(6).map { $0.isEmpty ? "--" : "\($0.pattern)×\($0.reps)" })
        await s.undo()
        await s.refresh()
        #expect(s.song!.tracks[5].entries.prefix(3).map(\.reps) == [4, 2, 1] || s.song!.tracks[5].entries[2].isEmpty)
        let d = try #require(session.skiffSongDriverForTests)
        try await clearT6(d)
        run.cancel(); _ = await run.value
    }
}


extension SkiffSongSimTests {
    /// MENU > USB LEVEL over the editor protocol (MENU_DESC / MENU_SET id 10), as the iPad's sound sets it;
    /// put back as it was.
    @Test func usbLevelFixedRoundTrips() async throws {
        let d = try await driver()
        let before = try #require(try await d.menuValue(id: SkiffMenu.usbLevel))
        let r = try await d.setMenu(id: SkiffMenu.usbLevel, value: 1)
        #expect([0, 3, 4].contains(r.rc) && r.value == 1)
        #expect(try await d.menuValue(id: SkiffMenu.usbLevel) == 1)
        _ = try await d.setMenu(id: SkiffMenu.usbLevel, value: before)
        #expect(try await d.menuValue(id: SkiffMenu.usbLevel) == before)
    }
}

extension SkiffSongSimTests {
    /// "I can't stop recording while it's still playing" (Scott, the FM-1, 2026-11-05): Skiff's REC toggles the
    /// selected track (ui_input.c rec_tap). Armed on T1, then T2 selected, REC arms T2 too instead of stopping.
    @Test func recOnAnotherTrackArmsItInsteadOfStopping() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        _ = try await d.selectTrack(0)
        try await d.rec()                                           // T1 armed; stopped, so it starts playing
        try await Task.sleep(for: .milliseconds(300))
        var s = try #require(try await d.transportState())
        print("REC on T1:", s)
        #expect(s.armedTracks == 1 && s.playing)
        _ = try await d.selectTrack(1)
        try await d.rec()                                           // "stop recording", with T2 selected
        try await Task.sleep(for: .milliseconds(100))
        s = try #require(try await d.transportState())
        print("REC on T2:", s)
        #expect(s.armedTracks == 0b11)                              // still recording, on two tracks now
        try await d.rec()                                           // T2 armed now: REC disarms them all
        try await Task.sleep(for: .milliseconds(100))
        s = try #require(try await d.transportState())
        print("REC again:", s)
        #expect(s.armedTracks == 0 && s.playing)                    // stopped recording, still playing
        _ = try await d.transport(play: false)
        _ = try await d.selectTrack(0)
    }
}

/// The screen link patch against skiff-sim built from Skiff's `screen-link` branch (SKIFF_SIM=1 SKIFF_LINK=1).
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_LINK"] == "1"))
@MainActor struct SkiffScreenLinkSimTests {
    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else { throw ClientError.timeout("not Skiff") }
        return s
    }

    @Test func screenAndGotoOnTheRealFirmware() async throws {
        let d = try await driver()
        #expect(d.skiff.hasScreenLink && d.info.version == "FELUCCA v2.2")
        _ = try await d.selectTrack(0)                                  // T1, ANALOG
        var s = try await d.screen()
        print("SCREEN at connect:", s)
        #expect(s.track == 0 && s.flags != nil)
        s = try await d.screenGoto(31)                                  // DELAY
        #expect(!s.home && s.page == 31 && s.layer == 0 && s.menu == 0)
        s = try await d.screenGoto(18)                                  // LANES: not ANALOG's, refused
        #expect(s.page == 31)                                           // answered, unchanged
        s = try await d.screenGoto(43)                                  // PATTERN
        #expect(s.page == 43)
        s = try await d.screenGoto(127)                                 // HOME
        #expect(s.home)
        await d.close()
    }

    @Test func theSessionLinksAndDrivesTheScreen() async throws {
        let session = DeviceSession(transport: { MIDITransport() })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(15) { if case .connected = session.status { true } else { false } }
        #expect(session.screenLinked && session.capabilities.contains(.screenLink))
        session.showOnDevice(page: 39)                                  // ARP
        try await waitFor(5) { session.deviceScreen?.page == 39 && session.deviceScreen?.home == false }
        session.showOnDevice(page: 127)
        try await waitFor(5) { session.deviceScreen?.home == true }
        run.cancel()
    }
}

extension SkiffScreenLinkSimTests {
    /// A button pressed on the (sim's) FM-1 reaches the session as a SCREEN push. SKIFF_CONSOLE: the sim's
    /// console, a FIFO its stdin reads.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SKIFF_CONSOLE"] != nil))
    func aButtonOnTheFM1MovesJib() async throws {
        let console = try #require(ProcessInfo.processInfo.environment["SKIFF_CONSOLE"])
        let session = DeviceSession(transport: { MIDITransport() })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(15) { if case .connected = session.status { true } else { false } }
        session.showOnDevice(page: 127)
        try await waitFor(5) { session.deviceScreen?.home == true }
        func press(_ b: String) throws {
            let h = try #require(FileHandle(forWritingAtPath: console))
            h.write(Data("press \(b)\n".utf8)); try h.close()
        }
        try press("GLO")                                                // GLO's first page: MIXER (30)
        try await waitFor(5) { session.deviceScreen?.home == false && session.deviceScreen?.page == 30 }
        try press("SEQ")                                                // SEQ: NOTES (41)
        try await waitFor(5) { session.deviceScreen?.page == 41 }
        print("pushed:", session.deviceScreen as Any)
        run.cancel()
    }
}

extension SkiffSongSimTests {
    /// MOTION on the real firmware: an editor TRACK_PARAM while the selected track is armed and playing is
    /// recorded; op 7 reads it with its kind; op 2 clears it.
    @Test func motionRecordsEditorEditsAndClears() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        _ = try await d.selectTrack(0)
        _ = try await d.clearMotion(track: 0)
        try await d.rec()                                               // T1 armed: playing
        try await Task.sleep(for: .milliseconds(300))
        for v in [20, 60, 100] {                                        // CHO (34), as a knob turned from Jib
            _ = try await d.setTrackParam(track: 0, id: 34, value: v)
            try await Task.sleep(for: .milliseconds(150))
        }
        let m = try await d.motion(track: 0)
        print("MOTION T1:", m)
        #expect(m.recorded >= 1 && m.on && m.events.allSatisfy { $0.id == 34 && !$0.lock })
        try await d.rec()                                               // disarm
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await d.clearMotion(track: 0) == 0)
        #expect(try await d.motion(track: 0).events.isEmpty)
    }
}

extension SkiffSongSimTests {
    /// Leaves motion recorded on T1 and T2 for the app to show (SKIFF_SIM=1 SKIFF_KEEP_MOTION=1): Jib on the iPad
    /// simulator, connected to the same skiff-sim, then reads it as it would a real FM-1's.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SKIFF_KEEP_MOTION"] == "1"))
    func leavesMotionForTheApp() async throws {
        let d = try await driver()
        for t in [0, 1] {
            _ = try await d.transport(play: false)
            _ = try await d.selectTrack(t)
            try await d.rec()
            try await Task.sleep(for: .milliseconds(300))
            for v in stride(from: 10, through: 120, by: 10) {
                _ = try await d.setTrackParam(track: t, id: 34, value: v)
                try await Task.sleep(for: .milliseconds(120))
            }
            try await d.rec()
            _ = try await d.transport(play: false)
            try await Task.sleep(for: .milliseconds(200))
            let m = try await d.motion(track: t)
            print("MOTION T\(t + 1):", m.steps.sorted())
            #expect(m.recorded > 0)
        }
    }
}

extension SkiffScreenLinkSimTests {
    /// Every page the map uses, on the patched firmware: SCREEN_GOTO there, and the screen says where Jib lands.
    @Test func theButtonMapOnTheRealFirmware() async throws {
        let d = try await driver()
        _ = try await d.selectTrack(0)                                  // T1, ANALOG: no FM6, kit or sample pages
        for place: SkiffButtonMap.Place in [.shape(page: 0), .shape(page: 4), .shape(page: 7), .shape(page: 11), .shape(page: 28),
                                            .shape(page: 39), .mixer(.mixer), .mixer(.delay), .mixer(.reverb), .mixer(.chorus),
                                            .mixer(.global), .browse, .arrange(patterns: true), .projects, .sequence(.notes),
                                            .sequence(.feel), .sequence(.pattern), .sequence(.automation), .arrange(patterns: false)] {
            let p = SkiffButtonMap.page(for: place)
            let s = try await d.screenGoto(p)
            #expect(!s.home && s.page == p, "SCREEN_GOTO \(p): \(s)")
            #expect(SkiffButtonMap.place(for: s) == place, "page \(p)")
        }
        let h = try await d.screenGoto(127)
        #expect(SkiffButtonMap.place(for: h) == .home)
        await d.close()
    }
}

extension SkiffSongSimTests {
    /// MOTION's editing ops on the real firmware: a change (op 3), a lock (op 5), a lock made to hold, the step's
    /// locks cleared (op 6), a record deleted (op 4).
    @Test func motionEditsOnTheRealFirmware() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        _ = try await d.clearMotion(track: 0)
        var r = try await d.setMotion(track: 0, step: 4, id: 34, value: 90, lock: false)
        #expect(r.rc == .done && r.motion.record(34, at: 4)?.lock == false && r.motion.record(34, at: 4)?.value == 90)
        r = try await d.setMotion(track: 0, step: 7, id: 34, value: 20, lock: true)
        #expect(r.rc == .done && r.motion.record(34, at: 7)?.lock == true)
        r = try await d.setMotion(track: 0, step: 7, id: 34, value: 20, lock: false)
        #expect(r.motion.record(34, at: 7)?.lock == false && r.motion.events.count == 2)
        r = try await d.setMotion(track: 0, step: 9, id: 34, value: 5, lock: true)
        var m = try await d.clearLocks(track: 0, step: 9)
        #expect(m.record(34, at: 9) == nil && m.events.count == 2)
        m = try await d.deleteMotion(track: 0, step: 4, id: 34)
        #expect(m.events.map(\.step) == [7])
        r = try await d.setMotion(track: 0, step: 4, id: 200, value: 1, lock: false)             // not a parameter
        #expect(r.rc == .invalid)
        _ = try await d.clearMotion(track: 0)
    }
}

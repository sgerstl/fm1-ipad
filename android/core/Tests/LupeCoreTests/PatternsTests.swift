import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Managing patterns (board 79) on FakeSkiff: the `patterns` area from POOL and LIST, the stored pictures read only
/// while stopped and only with the sheet open, and clearPatterns, recyclePattern, copyPattern with their notices.
@Suite(.serialized) @MainActor struct PatternsTests {
    final class Box { var writes = true; var notices: [NoticeArea] = []; var log: [String] = [] }

    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        PhoneCore.picturesQuiet = 0.3
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { area, json in
                                 if area == "notice", let n = try? JSONDecoder().decode(NoticeArea.self, from: Data(json.utf8)) { box.notices.append(n) }
                             }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        try await wait("connected") { core.session.isConnected && core.patternsArea() != nil }
        if fake.playing { try await stop(core, fake) }
        box.notices.removeAll(); box.log.removeAll()
        return (core, fake)
    }
    func wait(_ what: String, _ seconds: Double = 12, _ ok: () -> Bool) async throws {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end, !ok() { try await Task.sleep(for: .milliseconds(20)) }
        #expect(ok(), "\(what)")
    }
    /// No change still going in (the store takes one at a time and refuses a second).
    func idle(_ core: PhoneCore) async throws {
        try await wait("idle") { core.session.skiffSong?.busy == false }
    }
    func stop(_ core: PhoneCore, _ fake: FakeSkiff) async throws {
        core.handle(json: #"{"intent":"stop"}"#)
        try await wait("stopped") { !fake.playing && !core.session.playing }
    }
    /// An 888-byte stored record: LEN, and a note on each given step.
    func record(len: Int, notes: [Int: Int]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: 888)
        r[0] = 3; r[2] = UInt8(len + 64); r[6] = 64
        for (i, n) in notes { r[8 + 9 * i] = UInt8(n); r[8 + 9 * i + 4] = 1 }
        return r
    }

    @Test func theAreaSaysWhereEachPatternIsUsed() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let pool = try #require(core.session.skiffSong?.pool?.patterns)
        let song = try #require(core.session.skiffSong?.song)
        var a = try #require(core.patternsArea())
        #expect(a.kept == pool.filter { $0.length > 0 }.count && a.free + a.kept == 64 && a.patterns.map(\.number) == a.patterns.map(\.number).sorted())
        for it in a.patterns {
            let p = it.number - 1
            let here = song.tracks.enumerated().flatMap { t, l in l.entries.indices.filter { l.entries[$0].poolIndex == p }.map { PatternsArea.Use(track: t + 1, entry: $0) } }
            #expect(it.len == pool[p].length && it.uses == pool[p].uses && it.here == here)
            #expect(it.unused == (pool[p].uses == 0) && it.on == song.tracks.indices.filter { song.tracks[$0].patternOn == p }.map { $0 + 1 })
            // the fake has no saved projects' entries: nothing is held elsewhere
            #expect(!it.saved)
        }
        // a kept pattern nothing names: unused, and the one Recycle would take when it is the lowest
        let spare = try #require((1...64).first { fake.poolLen[$0 - 1] == 0 })
        fake.poolLen[spare - 1] = 32
        try await wait("the spare pattern read") { core.patternsArea()?.patterns.contains { $0.number == spare } ?? false }
        a = try #require(core.patternsArea())
        let it = try #require(a.patterns.first { $0.number == spare })
        #expect(it.unused && it.len == 32 && it.here.isEmpty && it.uses == 0 && a.unused >= 1 && a.recycle == a.patterns.first { $0.unused }?.number)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func storedPicturesAreReadOnlyStoppedAndOnlyWithTheSheetOpen() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let on = Set(core.session.skiffSong!.song!.tracks.compactMap(\.patternOn))
        let spare = try #require((1...64).first { fake.poolLen[$0 - 1] == 0 && !on.contains($0 - 1) })
        fake.poolLen[spare - 1] = 16
        fake.bankRecords[spare - 1] = record(len: 16, notes: [0: 60, 4: 67, 8: 72])
        try await wait("the spare pattern read") { core.patternsArea()?.patterns.contains { $0.number == spare } ?? false }
        // the sheet closed: nothing read from the bank, however long it is stopped
        try await Task.sleep(for: .milliseconds(1200))
        #expect(fake.backupLists == 0 && core.patternPicturesArea()?.pictures.contains { $0.number == spare } == false)
        // a track's own pattern is drawn from the track, live
        let live = try #require(core.patternPicturesArea()?.pictures.filter(\.live))
        #expect(Set(live.map { $0.number - 1 }) == on && live.allSatisfy { $0.notes.count == $0.len && $0.hits.count == $0.len })
        // playing with the sheet open: still nothing read, and the area says the pictures wait
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: #"{"intent":"patternsOpen","open":true}"#)
        try await Task.sleep(for: .milliseconds(1500))
        #expect(fake.backupLists == 0 && fake.playing, "a BACKUP_LIST while playing would stop the FM-1")
        #expect(core.patternsArea()?.picturesWaitForStop == true)
        #expect(core.patternsArea()?.picturesLoading == false)
        // stopped: read once, cached
        try await stop(core, fake)
        try await wait("the stored picture") { core.patternPicturesArea()?.pictures.contains { $0.number == spare } ?? false }
        let pic = try #require(core.patternPicturesArea()?.pictures.first { $0.number == spare })
        #expect(!pic.live && !pic.drums && pic.len == 16 && pic.notes == [60, -1, -1, -1, 67, -1, -1, -1, 72, -1, -1, -1, -1, -1, -1, -1])
        #expect(core.patternsArea()?.picturesWaitForStop == false && core.patternsArea()?.picturesLoading == false)
        let lists = fake.backupLists
        #expect(lists == 1)
        try await Task.sleep(for: .milliseconds(1500))
        #expect(fake.backupLists == lists, "nothing changed in the pool: nothing read again")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func clearPatternsTakesOnlyTheUnused() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let spare = Array((1...64).filter { fake.poolLen[$0 - 1] == 0 }.prefix(2))
        for p in spare { fake.poolLen[p - 1] = 16 }
        try await wait("the unused read") { (core.patternsArea()?.unused ?? 0) >= 2 }
        let used = try #require(core.patternsArea()?.patterns.first { !$0.unused }?.number)
        let lens = fake.poolLen
        let ask = #"{"intent":"clearPatterns","numbers":[\#(spare[0]),\#(used),\#(spare[1])],"confirmed":true}"#
        // read-only, unconfirmed, playing: nothing cleared
        box.writes = false
        core.handle(json: ask)
        #expect(box.notices.last?.text == PhoneCore.readOnlyNotice)
        box.writes = true
        core.handle(json: #"{"intent":"clearPatterns","numbers":[\#(spare[0])]}"#)
        #expect(box.log.contains { $0.contains("must confirm") })
        core.handle(json: #"{"intent":"clearPatterns","numbers":[\#(used)],"confirmed":true}"#)
        #expect(box.notices.last?.text.contains("can't be cleared") == true)
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: ask)
        #expect(box.notices.last?.text.hasPrefix("Stop playback to clear patterns") == true)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.poolLen == lens)
        try await stop(core, fake)
        // stopped and confirmed: the two unused go, the used one is left and named
        core.handle(json: ask)
        try await wait("cleared") { spare.allSatisfy { fake.poolLen[$0 - 1] == 0 } }
        try await wait("said") { box.notices.last?.text.hasPrefix("Cleared patterns") == true }
        let text = try #require(box.notices.last?.text)
        #expect(text.contains(String(format: "%02d and %02d", spare[0], spare[1])) && text.contains("Left alone") && text.contains(String(format: "%02d", used)), "\(text)")
        #expect(fake.poolLen[used - 1] == lens[used - 1])
        #expect(core.patternsArea()?.patterns.contains { spare.contains($0.number) } == false)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func recycleAndCopy() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        // an empty entry on track 2
        let e = try #require(core.session.skiffSong?.song?.tracks[1].entries.firstIndex { $0.isEmpty })
        // nothing unused: Recycle says so
        if core.patternsArea()?.unused == 0 {
            core.handle(json: #"{"intent":"recyclePattern","track":2,"entry":\#(e)}"#)
            #expect(box.notices.last?.text.hasPrefix("No pattern is unused") == true && box.notices.last?.track == 2 && box.notices.last?.entry == e)
        }
        let spare = try #require((1...64).first { fake.poolLen[$0 - 1] == 0 })
        fake.poolLen[spare - 1] = 16
        try await wait("the unused read") { core.patternsArea()?.recycle != nil }
        let n = try #require(core.patternsArea()?.recycle)
        // playing: refused
        core.handle(json: #"{"intent":"play"}"#)
        try await wait("playing") { core.session.playing }
        core.handle(json: #"{"intent":"recyclePattern","track":2,"entry":\#(e)}"#)
        #expect(box.notices.last?.text.hasPrefix("Stop playback to recycle") == true && fake.lists[1][e].p == 0)
        try await stop(core, fake)
        // stopped: the lowest unused onto the entry, then emptied
        try await idle(core)
        core.handle(json: #"{"intent":"recyclePattern","track":2,"entry":\#(e)}"#)
        try await wait("recycled") { fake.lists[1][e].p == n && fake.emptiedPatterns == [n - 1] }
        try await wait("said") { box.notices.last?.text.contains("was emptied and put on T2 pad \(e + 1)") == true }
        #expect(core.patternsArea()?.patterns.first { $0.number == n }?.here == [PatternsArea.Use(track: 2, entry: e)])
        // copy: onto an empty entry, a new number
        let e2 = try #require(core.session.skiffSong?.song?.tracks[2].entries.firstIndex { $0.isEmpty })
        core.handle(json: #"{"intent":"copyPattern","number":\#(n),"track":2,"entry":\#(e)}"#)
        #expect(box.notices.last?.text.contains("isn't empty") == true)
        let before = fake.poolLen.filter { $0 > 0 }.count
        try await idle(core)
        core.handle(json: #"{"intent":"copyPattern","number":\#(n),"track":3,"entry":\#(e2)}"#)
        try await wait("copied") { fake.lists[2][e2].p != 0 && fake.lists[2][e2].p != n && fake.poolLen.filter { $0 > 0 }.count == before + 1 }
        try await wait("said") { box.notices.last?.text.contains("was copied to") == true && box.notices.last?.track == 3 }
        // the pool full: a copy has nowhere to go
        for i in 0..<64 where fake.poolLen[i] == 0 { fake.poolLen[i] = 16 }
        try await wait("full") { core.patternsArea()?.free == 0 }
        let e3 = try #require(core.session.skiffSong?.song?.tracks[3].entries.firstIndex { $0.isEmpty })
        core.handle(json: #"{"intent":"copyPattern","number":\#(n),"track":4,"entry":\#(e3)}"#)
        #expect(box.notices.last?.text.hasPrefix("All 64 patterns are taken") == true && fake.lists[3][e3].p == 0)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

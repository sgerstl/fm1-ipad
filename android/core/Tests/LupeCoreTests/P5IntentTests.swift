import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// P5's intents through PhoneCore into FakeSkiff: each reaches the fake as the write the iPad sends for the same thing
/// and changes its state; anything that loses something waits for the screen's confirm; read-only sends none.
@Suite(.serialized) @MainActor struct P5IntentTests {
    final class Box { var writes = true; var log: [String] = [] }

    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { _, _ in }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil && core.session.skiffProjects != nil) {
            try await Task.sleep(for: .milliseconds(20))
        }
        if fake.playing {
            let w = box.writes; box.writes = true
            core.handle(json: #"{"intent":"stop"}"#); box.writes = w
            let stop = Date().addingTimeInterval(3)
            while Date() < stop, fake.playing || core.session.playing { try await Task.sleep(for: .milliseconds(20)) }
        }
        box.log.removeAll()
        return (core, fake)
    }

    func settle(_ cond: () -> Bool, _ what: String) async throws {
        let end = Date().addingTimeInterval(4)
        while !cond() { if Date() > end { Issue.record("timed out: \(what)"); return }; try await Task.sleep(for: .milliseconds(10)) }
    }
    func idle(_ core: PhoneCore) async throws {
        try await Task.sleep(for: .milliseconds(30))
        try await settle({ !(core.session.skiffSong?.busy ?? false) && !core.projectBusy }, "idle")
    }
    func send(_ core: PhoneCore, _ json: String) { core.handle(json: json) }

    @Test func theAreasCarryWhatTheScreensShow() async throws {
        let box = Box()
        let (core, _) = try await connected(box)
        defer { core.stop() }
        let m = core.mixArea()
        #expect(m.sections.map(\.key) == ["mixer", "delay", "reverb", "chorus", "global"] && m.rows.count == 6 && m.card == nil)
        send(core, #"{"intent":"mixSection","section":"delay"}"#)
        let card = try #require(core.mixArea().card)
        #expect(card.title == "DELAY" && card.controls.count == 4 && card.controls.contains { $0 != nil })
        let snd = core.soundsArea()
        #expect(snd.user.count == 32 && !snd.presets.isEmpty && snd.engines.contains { $0.name == "DRUM" && $0.kit })
        let p = core.projectsArea()
        #expect(p.slots.count == 4 && p.slots[0].used && p.slots[0].current)
    }

    @Test func mixReachesTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        send(core, #"{"intent":"setLevel","track":2,"value":90}"#)
        try await settle({ fake.params[1][Param.level] == 90 }, "level")
        send(core, #"{"intent":"setPan","track":2,"value":-20}"#)
        try await settle({ fake.params[1][Param.pan] == -20 }, "pan")
        let rid = try #require(core.reverbSendID)
        send(core, #"{"intent":"setReverb","track":3,"value":70}"#)
        try await settle({ fake.params[2][rid] == 70 }, "reverb send")
        send(core, #"{"intent":"trackSolo","track":4}"#)                                  // the others muted (PERFORM)
        try await settle({ (0..<6).filter { $0 != 3 }.allSatisfy { fake.muted[$0] } && !fake.muted[3] }, "solo")
        try await idle(core)
        #expect(core.mixArea().rows[3].solo)
        send(core, #"{"intent":"mixSection","section":"reverb"}"#)
        let card = try #require(core.mixArea().card)
        let k = try #require(card.controls.firstIndex { $0 != nil })
        let p = try #require(core.mixPage("reverb")); let gid = try #require(p.ids[k] ?? nil)
        let want = min(card.controls[k]!.max, card.controls[k]!.raw + 5)
        send(core, #"{"intent":"setMixParam","slot":\#(k),"value":\#(want)}"#)
        try await settle({ fake.globals[gid] == want }, "card knob")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func soundsReachTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let t = core.session.selectedTrack
        // a preset onto the track (PRESET)
        let e = try #require(core.soundsArea().engines.first { $0.offered && !$0.kit && $0.index != core.session.tracks[t].engine })
        send(core, #"{"intent":"soundsView","engine":\#(e.index)}"#)
        #expect(core.soundsArea().viewing == e.index)
        send(core, #"{"intent":"pickPreset","engine":\#(e.index),"preset":2}"#)
        try await settle({ fake.engines[t].engine == e.index && fake.engines[t].preset == 2 }, "preset")
        // SAVE into an empty slot (UP_STORE), then over it only confirmed
        send(core, #"{"intent":"saveSound","slot":5,"name":"BRIGHT"}"#)
        try await settle({ fake.userSlots[5]?.name == "BRIGHT" }, "saved")
        try await settle({ core.session.userPresets.contains { $0.slot == 5 } }, "slots read")
        send(core, #"{"intent":"saveSound","slot":5,"name":"DARK"}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.userSlots[5]?.name == "BRIGHT" && box.log.contains { $0.contains("must confirm") })
        send(core, #"{"intent":"saveSound","slot":5,"name":"DARK","confirmed":true}"#)
        try await settle({ fake.userSlots[5]?.name == "DARK" }, "replaced")
        // a user slot onto the track (UP_LOAD: the fake answers "empty"; the request is what's checked)
        let before = fake.requests.filter { $0 == 20 }.count
        send(core, #"{"intent":"pickUser","slot":5}"#)
        try await settle({ fake.requests.filter { $0 == 20 }.count > before }, "UP_LOAD sent")
        // erase only confirmed (UP_ERASE)
        send(core, #"{"intent":"eraseUser","slot":5}"#)
        try await Task.sleep(for: .milliseconds(150))
        #expect(fake.userSlots[5] != nil)
        send(core, #"{"intent":"eraseUser","slot":5,"confirmed":true}"#)
        try await settle({ fake.userSlots[5] == nil }, "erased")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    /// Decision 15: a pad's own sound overrides one pad (LIST2 SOUND through the store's rewrite), and goes again.
    @Test func aPadsOwnSound() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let t = try #require(fake.lists.indices.first { t in fake.lists[t].contains { $0.p > 0 && $0.p <= 64 } })
        let e = try #require(fake.lists[t].firstIndex { $0.p > 0 && $0.p <= 64 })
        send(core, #"{"intent":"soundsTarget","track":\#(t + 1),"entry":\#(e)}"#)
        #expect(core.soundsArea().target.entry == e && core.soundsArea().entrySound?.kind == "none")
        send(core, #"{"intent":"pickPreset","engine":3,"preset":4}"#)
        let block = try #require(core.session.skiffSong?.blocks(t).first { $0.entries.contains(e) })
        try await settle({ fake.lists[t][block.entries.lowerBound].s0 == 4 && fake.lists[t][block.entries.lowerBound].s1 == 4 }, "entry sound")
        try await idle(core)
        try await settle({ core.soundsArea().entrySound?.kind == "preset" }, "shown")
        #expect(core.padsArea().rows[t].entries[block.entries.lowerBound].hasSound)        // the pad is marked
        send(core, #"{"intent":"clearEntrySound"}"#)
        try await settle({ fake.lists[t][block.entries.lowerBound].s0 == 0 }, "entry sound gone")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func projectsLoadSaveRename() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        // save as into an empty slot, then over a used one only confirmed
        send(core, #"{"intent":"projectSaveAs","slot":1,"name":"Night Set"}"#)
        try await settle({ fake.projectSlots[1] == "NIGHT SET" && fake.musicSlot == 1 }, "save as"); try await idle(core)
        send(core, #"{"intent":"projectSaveAs","slot":0,"name":"Other"}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.projectSlots[0] == "SONG ONE" && box.log.contains { $0.contains("must confirm") })
        // save over the music's own slot: only confirmed
        send(core, #"{"intent":"projectSave"}"#)
        try await Task.sleep(for: .milliseconds(150))
        send(core, #"{"intent":"projectSave","confirmed":true}"#)
        try await settle({ !core.projectBusy && fake.musicSlot == 1 }, "saved"); try await idle(core)
        // rename (PROJ_NAME op 2): a used slot only
        send(core, #"{"intent":"projectRename","slot":1,"name":"Late Set"}"#)
        try await settle({ fake.projectSlots[1] == "LATE SET" }, "renamed"); try await idle(core)
        send(core, #"{"intent":"projectRename","slot":3,"name":"Nothing"}"#)
        try await settle({ box.log.contains { $0.contains("refused the rename") } }, "empty slot refused"); try await idle(core)
        // load: with unsaved changes only confirmed (it loses them)
        fake.musicChanged = true
        await core.session.refreshSkiffProjects()
        #expect(core.projectsArea().changed)
        let loads = fake.projectLoads
        send(core, #"{"intent":"projectLoad","slot":0}"#)
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.projectLoads == loads && box.log.contains { $0.contains("loses them") })
        send(core, #"{"intent":"projectLoad","slot":0,"confirmed":true}"#)
        try await settle({ fake.projectLoads == loads + 1 && fake.musicSlot == 0 }, "loaded"); try await idle(core)
        #expect(!core.projectsArea().changed)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func readOnlySendsNoneOfThem() async throws {
        let box = Box(); box.writes = false
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let params = fake.params, users = fake.userSlots.map { $0?.name }, slots = fake.projectSlots, engines = fake.engines.map(\.engine)
        for j in [#"{"intent":"setLevel","track":1,"value":10}"#, #"{"intent":"setPan","track":1,"value":10}"#,
                  #"{"intent":"trackSolo","track":1}"#, #"{"intent":"pickPreset","engine":3,"preset":1}"#,
                  #"{"intent":"saveSound","slot":2,"name":"X","confirmed":true}"#,
                  #"{"intent":"projectSaveAs","slot":2,"name":"X","confirmed":true}"#, #"{"intent":"projectRename","slot":0,"name":"X"}"#] {
            send(core, j)
        }
        send(core, #"{"intent":"mixSection","section":"chorus"}"#)                         // the screen's own: allowed
        try await Task.sleep(for: .milliseconds(400))
        #expect(fake.params == params && fake.userSlots.map { $0?.name } == users && fake.projectSlots == slots && fake.engines.map(\.engine) == engines)
        #expect(box.log.filter { $0.hasPrefix("read-only:") }.count == 7, "\(box.log)")
        #expect(core.mixArea().section == "chorus")
    }
}

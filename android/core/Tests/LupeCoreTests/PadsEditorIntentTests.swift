import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// P3's pads and editor intents through PhoneCore into FakeSkiff (Skiff 2.2 as skiff-sim answered it): each reaches
/// the fake as the write the iPad sends for the same thing and changes the fake's state; while read-only none is
/// sent at all. FakeSkiff stays strict (rule 5): nothing it doesn't model may be asked.
@Suite(.serialized) @MainActor struct PadsEditorIntentTests {
    final class Box { var writes = true; var log: [String] = [] }

    /// A core connected to a fresh FakeSkiff (no demo motion), the song and pool read.
    func connected(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        // the demo's seed: patterns in the lists and notes in the steps (it starts playing: stopped below)
        let fake = try #require(FakeSkiff(demo: true))
        fake.screenLink = true
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { _, _ in }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil) { try await Task.sleep(for: .milliseconds(20)) }
        #expect(core.session.isConnected)
        if fake.playing {                                       // the demo plays: stopped, as most edits want
            let w = box.writes; box.writes = true
            core.handle(json: #"{"intent":"stop"}"#)
            box.writes = w
            let stop = Date().addingTimeInterval(3)
            while Date() < stop, fake.playing || core.session.playing { try await Task.sleep(for: .milliseconds(20)) }
            box.log.removeAll()
        }
        return (core, fake)
    }

    func settle(_ cond: () -> Bool, _ what: String) async throws {
        let end = Date().addingTimeInterval(3)
        while !cond() {
            if Date() > end { Issue.record("timed out: \(what)"); return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func send(_ core: PhoneCore, _ json: String) { core.handle(json: json) }

    /// The song store takes one op at a time (as on the iPad): the next waits for this one to finish.
    func idle(_ core: PhoneCore) async throws {
        try await Task.sleep(for: .milliseconds(30))
        try await settle({ !(core.session.skiffSong?.busy ?? false) && (core.session.skiffSong?.launching.isEmpty ?? true) }, "store idle")
    }

    /// A track and entry holding a pattern, and an empty entry on the same track.
    func padWithPattern(_ fake: FakeSkiff) -> (track: Int, entry: Int, empty: Int)? {
        for t in fake.lists.indices {
            if let e = fake.lists[t].firstIndex(where: { $0.p > 0 && $0.p <= 64 }), let x = fake.lists[t].firstIndex(where: { $0.p == 0 }) { return (t, e, x) }
        }
        return nil
    }

    @Test func readOnlySendsNoneOfThem() async throws {
        let box = Box(); box.writes = false
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let lists = fake.lists, on = fake.entryOn, muted = fake.muted, sel = fake.selected, steps = fake.steps
        let pad = try #require(padWithPattern(fake))
        for j in [#"{"intent":"padTap","track":\#(pad.track + 1),"entry":\#(pad.entry)}"#,
                  #"{"intent":"padNew","track":\#(pad.track + 1),"entry":\#(pad.empty)}"#,
                  #"{"intent":"trackMute","track":1}"#, #"{"intent":"trackSelect","track":3}"#,
                  #"{"intent":"sceneStore","scene":2}"#, #"{"intent":"stepAdjust","field":"velocity","delta":3}"#,
                  #"{"intent":"stepAction","step":0,"action":"clear"}"#, #"{"intent":"locksClearAll","step":0}"#,
                  #"{"intent":"play"}"#] { send(core, j) }
        try await Task.sleep(for: .milliseconds(400))
        #expect(fake.lists == lists && fake.entryOn == on && fake.muted == muted && fake.selected == sel && fake.steps == steps)
        #expect(box.log.filter { $0.hasPrefix("read-only:") }.count == 9, "\(box.log)")
        #expect(fake.unansweredCommands.isEmpty)
    }

    @Test func padsReachTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let pad = try #require(padWithPattern(fake))
        // tap: stopped, the track goes onto the entry at once (LIST PLAY)
        send(core, #"{"intent":"padTap","track":\#(pad.track + 1),"entry":\#(pad.entry)}"#)
        try await settle({ fake.entryOn[pad.track] == pad.entry }, "launch"); try await idle(core)
        // mute (PERFORM 3), and back
        #expect(!box.log.contains { $0.hasPrefix("FM-1 refused") }, "\(box.log)")
        let m = fake.muted[pad.track]
        send(core, #"{"intent":"trackMute","track":\#(pad.track + 1)}"#)
        try await settle({ fake.muted[pad.track] != m }, "mute"); try await idle(core)
        // scene store (PERFORM 1) and recall (2)
        send(core, #"{"intent":"sceneStore","scene":3}"#)
        try await settle({ fake.scenes[3] != nil }, "scene store"); try await idle(core)
        send(core, #"{"intent":"sceneRecall","scene":3}"#)
        try await settle({ fake.lastScene == 3 }, "scene recall"); try await idle(core)
        // the hold menu: New pattern on an empty entry (LIST 7), Set pattern (1), Clear (4, stopped)
        send(core, #"{"intent":"padNew","track":\#(pad.track + 1),"entry":\#(pad.empty)}"#)
        try await settle({ fake.lists[pad.track][pad.empty].p > 0 }, "new pattern"); try await idle(core)
        send(core, #"{"intent":"padSet","track":\#(pad.track + 1),"entry":\#(pad.empty),"pattern":\#(fake.lists[pad.track][pad.entry].p)}"#)
        try await settle({ fake.lists[pad.track][pad.empty].p == fake.lists[pad.track][pad.entry].p }, "set pattern"); try await idle(core)
        send(core, #"{"intent":"padClear","track":\#(pad.track + 1),"entry":\#(pad.empty)}"#)
        try await settle({ fake.lists[pad.track][pad.empty].p == 0 }, "clear")
        // select a track (TRACK with an argument)
        send(core, #"{"intent":"trackSelect","track":4}"#)
        try await settle({ fake.selected == 3 }, "select")
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func stepFieldsReachTheFM1() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let t = core.editorTrack()
        let i = try #require(core.session.tracks[t].steps.indices.first { core.session.tracks[t].steps[$0].isOn && $0 + 1 < 16 && !core.session.tracks[t].steps[$0 + 1].isOn })
        send(core, #"{"intent":"stepSelect","step":\#(i)}"#)
        func b(_ k: Int) -> Int { Int(fake.steps[t][i][k]) }      // n, note0..3, time, flags, vel, hits ×3, chance, ratchet, FLAM, COND, NUDGE+32
        let note = b(1), vel = b(7)
        send(core, #"{"intent":"stepAdjust","field":"pitch","delta":2}"#)
        try await settle({ b(1) == note + 2 }, "pitch")
        send(core, #"{"intent":"stepAdjust","field":"velocity","delta":-2}"#)          // 2 units of 4
        try await settle({ b(7) == max(1, (vel == 0 ? 96 : vel) - 8) }, "velocity")
        let chance = b(11)
        send(core, #"{"intent":"stepAdjust","field":"chance","delta":-1}"#)            // 1 unit of 5
        try await settle({ b(11) == max(0, chance - 5) }, "chance")
        send(core, #"{"intent":"stepAdjust","field":"cond","delta":1}"#)
        try await settle({ b(14) == 1 }, "cond")
        send(core, #"{"intent":"stepAdjust","field":"nudge","delta":3}"#)
        try await settle({ b(15) == 35 }, "nudge")
        send(core, #"{"intent":"stepAdjust","field":"length","delta":1}"#)            // the next step becomes a TIE
        try await settle({ fake.steps[t][i + 1][5] == 1 }, "length")
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func moveCopyPasteClear() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let t = core.editorTrack()
        let steps = core.session.tracks[t].steps
        let i = try #require(steps.indices.first { steps[$0].isOn && $0 + 1 < 16 && steps[$0 + 1] != steps[$0] })
        let a = fake.steps[t][i], b = fake.steps[t][i + 1]
        send(core, #"{"intent":"stepSelect","step":\#(i)}"#)
        send(core, #"{"intent":"stepAdjust","field":"move","delta":1}"#)               // swapped, the selection with it
        try await settle({ fake.steps[t][i + 1] == a && fake.steps[t][i] == b }, "move")
        #expect(core.selectedStep == i + 1)
        send(core, #"{"intent":"stepAction","step":\#(i + 1),"action":"copy"}"#)
        send(core, #"{"intent":"stepAction","step":\#(i),"action":"paste"}"#)
        try await settle({ fake.steps[t][i] == a }, "paste")
        send(core, #"{"intent":"stepAction","step":\#(i),"action":"clear"}"#)
        try await settle({ fake.steps[t][i][0] == 0 }, "clear")
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func locks() async throws {
        let box = Box()
        let (core, fake) = try await connected(box)
        defer { core.stop() }
        let s = core.session, t = s.selectedTrack
        // Lock latched: knob turns from Lupe lock to the selected step (Session.lockStep, as the iPad's Lock)
        send(core, #"{"intent":"stepSelect","step":5}"#)
        send(core, #"{"intent":"lockToggle"}"#)
        #expect(s.lockStep == 5 && core.editorArea().lock == .latched)
        send(core, #"{"intent":"stepSelect","step":6}"#)
        #expect(s.lockStep == 6)                                                           // follows the selection
        let id = try #require(s.trackDescs.first { $0.value.label == "CUTOFF" }?.key ?? s.trackDescs.keys.sorted().first)
        s.set(track: t, param: id, to: 40)                                                 // a knob turn from Lupe
        try await settle({ fake.motion[t].contains { $0.step == 6 && $0.id == id && $0.lock } }, "lock written")
        send(core, #"{"intent":"lockToggle"}"#)
        #expect(s.lockStep == nil)
        // held: down locks to that step, up lets go
        send(core, #"{"intent":"stepHold","step":9,"down":true}"#)
        #expect(s.lockStep == 9 && core.editorArea().lock == .held)
        send(core, #"{"intent":"stepHold","step":9,"down":false}"#)
        #expect(s.lockStep == nil)
        // the editor shows it once MOTION is read, then ✕ removes it (MOTION op 4)
        await s.readMotion(track: t)
        let label = s.trackDescs[id]?.label ?? ""
        #expect(core.editorArea().steps[6].values.contains { $0.param == label && $0.locked })
        send(core, #"{"intent":"lockClear","step":6,"param":"\#(label)"}"#)
        try await settle({ !fake.motion[t].contains { $0.step == 6 && $0.id == id } }, "lock cleared")
        // clear all on a step (MOTION op 6)
        s.lockStep = 2; s.set(track: t, param: id, to: 50); s.lockStep = nil
        try await settle({ fake.motion[t].contains { $0.step == 2 } }, "second lock")
        send(core, #"{"intent":"locksClearAll","step":2}"#)
        try await settle({ !fake.motion[t].contains { $0.step == 2 && $0.lock } }, "clear all")
        try await Task.sleep(for: .milliseconds(200))
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func chordAndLaneAreTheScreens() async throws {
        let box = Box(); box.writes = false                                                  // not writes: allowed read-only
        let (core, _) = try await connected(box)
        defer { core.stop() }
        send(core, #"{"intent":"chordToggle"}"#)
        #expect(core.editorArea().chord)
        send(core, #"{"intent":"lockToggle"}"#)
        #expect(core.session.lockStep == 0)
        #expect(!box.log.contains { $0.hasPrefix("read-only:") })
    }

    /// The second layer: even if PhoneCore let a write through, the link's guard drops it before the FM-1.
    @Test func theGuardStillDropsWritesUnderneath() async throws {
        let fake = try #require(FakeSkiff(demo: true))
        final class Blocked: @unchecked Sendable { let lock = NSLock(); var n = 0; func add() { lock.withLock { n += 1 } } }
        let blocked = Blocked()
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: {
            if once { return nil }; once = true
            return GuardedTransport(fake, onBlocked: { _ in blocked.add() })
        }), publish: { _, _ in }, canWrite: { true })
        core.start()
        defer { core.stop() }
        let end = Date().addingTimeInterval(10)
        while Date() < end, !(core.session.isConnected && core.session.skiffSong?.song != nil) { try await Task.sleep(for: .milliseconds(20)) }
        let muted = fake.muted
        core.handle(json: #"{"intent":"trackMute","track":1}"#)
        core.handle(json: #"{"intent":"stepAdjust","field":"velocity","delta":1}"#)
        try await settle({ blocked.lock.withLock { blocked.n } >= 2 }, "both blocked")
        #expect(fake.muted == muted)
    }
}

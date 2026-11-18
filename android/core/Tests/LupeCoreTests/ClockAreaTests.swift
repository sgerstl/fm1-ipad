import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The clock reference and the launch countdowns (Scott's play test, 2026-11-14) on FakeSkiff's demo while it plays:
/// the reference run forward stays on the session's count, a pass bar from the row's ticks matches the session's, a
/// waiting pad, mute and scene carry the pulse they land on, and the readout's bar stays within its bars.
// every test ends within 3 minutes, so a stuck test fails instead of stalling the run (2026-11-18)
@Suite(.serialized, .timeLimit(.minutes(3))) @MainActor struct ClockAreaTests {
    final class Box { var writes = true; var log: [String] = [] }

    func playing(_ box: Box) async throws -> (PhoneCore, FakeSkiff) {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { _, _ in }, log: { box.log.append($0) }, canWrite: { box.writes })
        core.start()
        try await settle(10, "playing with a clock") {
            core.session.isConnected && core.session.skiffSong?.song != nil && core.session.skiffSong?.perform != nil
                && core.session.playing && core.session.clockTicks >= 24 && core.clockArea().running
        }
        return (core, fake)
    }
    func settle(_ seconds: Double = 4, _ what: String, _ cond: () -> Bool) async throws {
        let end = Date().addingTimeInterval(seconds)
        while !cond() { if Date() > end { Issue.record("timed out: \(what)"); return }; try await Task.sleep(for: .milliseconds(10)) }
    }
    func ticksNow(_ c: ClockArea) -> Double { Double(c.ticks) + (LagClock.now() - Double(c.atMs)) * c.ticksPerSecond / 1000 }

    @Test func theReferenceRunForwardStaysOnTheCount() async throws {
        let box = Box()
        let (core, _) = try await playing(box)
        defer { core.stop() }
        var worst = 0.0
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(37))
            let c = core.clockArea()
            #expect(c.running && c.ticksPerSecond == Double(core.session.bpm) * 24 / 60)
            worst = max(worst, abs(ticksNow(c) - Double(core.session.clockTicks)))
        }
        #expect(worst < 4, "the interpolated count strayed \(worst) pulses from the session's")
        // a row's pass bar from its ticks is the session's own progress
        let pads = core.padsArea()
        let row = try #require(pads.rows.first { $0.passTicks != nil })
        let t = row.track - 1
        let mine = ((Double(core.session.clockTicks) - row.passStartTick!) / row.passTicks!).truncatingRemainder(dividingBy: 1)
        let theirs = try #require(core.session.passProgress(t))
        #expect(abs(mine - theirs) < 0.05 || abs(mine - theirs) > 0.95, "\(mine) against \(theirs)")
    }

    @Test func aWaitingPadMuteAndSceneCarryTheirLaunchTick() async throws {
        let box = Box()
        let (core, fake) = try await playing(box)
        defer { core.stop() }
        // a pad launched while playing waits for the launch point
        let t = 0
        let list = try #require(core.session.skiffSong?.song?.tracks.first)
        // (not the entry the song brings next anyway: that one shows as "next", not "waiting")
        let next = core.padsArea().rows[t].entries.firstIndex { $0.play == .next }
        let other = try #require((0..<16).last { $0 != list.entryOn && $0 != next && !(list.entries[$0].isEmpty) })
        core.handle(json: #"{"intent":"padTap","track":1,"entry":\#(other)}"#)
        try await settle(3, "the pad waiting") { core.padsArea().rows[t].entries[other].play == .waiting }
        var row = core.padsArea().rows[t]
        let tick = try #require(row.entries[other].launchTick)
        #expect(tick > Double(core.session.clockTicks) - 1 && row.launchTick == tick)
        // a mute while playing is staged: pending, with the same kind of tick
        core.handle(json: #"{"intent":"trackMute","track":2}"#)
        try await settle(3, "the mute pending") { core.padsArea().rows[1].mutePending == "mute" }
        row = core.padsArea().rows[1]
        #expect(row.launchTick != nil && !row.muted)
        try await settle(5, "the mute landed") { fake.muted[1] && core.padsArea().rows[1].mutePending == "none" && core.padsArea().rows[1].muted }
        #expect(core.padsArea().rows[1].launchTick == nil)
        // a kept scene recalled while playing waits until its tracks are in
        if let k = core.padsArea().scenes.firstIndex(where: { $0.stored && !$0.current }) {
            core.handle(json: #"{"intent":"sceneRecall","scene":\#(k)}"#)
            try await settle(3, "the scene waiting") { core.padsArea().scenes[k].waiting || core.padsArea().scenes[k].current }
            if core.padsArea().scenes[k].waiting { #expect(core.padsArea().scenes[k].launchTick != nil) }
        }
    }

    @Test func theReadoutStaysWithinItsBars() async throws {
        let box = Box()
        let (core, _) = try await playing(box)
        defer { core.stop() }
        // the demo plays with SONG on: within the song
        var top = core.topArea()
        #expect(top.mode == .song)
        let song = try #require(top.bars)
        #expect(song == Int(core.timelineArea().bars.rounded(.up)) && (1...song).contains(top.bar) && (1...4).contains(top.beat))
        // Loop: within the selected track's block
        core.handle(json: #"{"intent":"setPlaybackMode","mode":"loop"}"#)
        try await settle(3, "loop") { core.topArea().mode == .loop }
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(50))
            top = core.topArea()
            if let bars = top.bars { #expect((1...bars).contains(top.bar), "bar \(top.bar) of \(bars)") }
            #expect((1...4).contains(top.beat))
        }
        #expect(top.bars != nil)
        // stopped: no clock, 1·1, nothing to count down
        core.handle(json: #"{"intent":"stop"}"#)
        try await settle(3, "stopped") { !core.session.playing && !core.clockArea().running }
        top = core.topArea()
        #expect(top.bar == 1 && top.beat == 1 && top.bars == nil)
        #expect(core.padsArea().rows.allSatisfy { $0.passTicks == nil && $0.launchTick == nil })
    }

    /// What is published, not what a builder returns when asked (Scott's device session: the outlines didn't show): a
    /// pad tapped while playing goes out as waiting with its tick, the clock goes out at least every beat, and the log
    /// says when the wait began and ended.
    @Test func theWaitIsPublishedWithItsTickAndTheClockKeepsComing() async throws {
        final class Frames { var pads: [String] = []; var clock: [String] = []; var log: [String] = [] }
        let f = Frames()
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { a, j in if a == "pads" { f.pads.append(j) } else if a == "clock" { f.clock.append(j) } },
                             log: { f.log.append($0) }, canWrite: { true })
        core.start()
        defer { core.stop() }
        try await settle(10, "playing with a clock") {
            core.session.playing && core.session.clockTicks >= 24 && core.session.skiffSong?.perform != nil
                && core.clockArea().running && f.clock.contains { $0.contains("\"running\":true") }
        }
        let clocks = f.clock.count
        let list = try #require(core.session.skiffSong?.song?.tracks.first)
        let next = core.padsArea().rows[0].entries.firstIndex { $0.play == .next }
        let other = try #require((0..<16).last { $0 != list.entryOn && $0 != next && !list.entries[$0].isEmpty })
        let n = f.pads.count
        core.handle(json: #"{"intent":"padTap","track":1,"entry":\#(other)}"#)
        func waiting(_ json: String) -> PadsArea.Entry? {
            (try? JSONDecoder().decode(PadsArea.self, from: Data(json.utf8)))?.rows[0].entries[other]
        }
        try await settle(3, "the wait published") { f.pads.dropFirst(n).contains { waiting($0)?.play == .waiting } }
        let first = try #require(f.pads.dropFirst(n).first { waiting($0)?.play == .waiting })
        #expect(waiting(first)?.launchTick != nil, "published waiting without a tick: \(first.prefix(300))")
        #expect(f.log.contains { $0.hasPrefix("wait: T1 pad \(other + 1) lands at") && $0.contains("clock running") }, "\(f.log)")
        try await settle(5, "landed") { f.log.contains { $0.hasPrefix("wait over: T1 pad \(other + 1)") } }
        // two seconds at 120 BPM: four beats, a reference each
        try await Task.sleep(for: .milliseconds(2000))
        #expect(f.clock.count - clocks >= 3, "\(f.clock.count - clocks) clock frames")
        let last = try #require(f.clock.last.flatMap { try? JSONDecoder().decode(ClockArea.self, from: Data($0.utf8)) })
        #expect(last.running && abs(Double(last.atMs) - LagClock.now()) < 1500)
    }

    /// The playhead on its own (2026-11-15): while a pattern plays the `playhead` area goes out a step at a time,
    /// small, and the editor area (up to 15 KB) isn't sent again.
    @Test func thePlayheadGoesOutAloneWhileTheEditorStaysPut() async throws {
        final class Frames { var sent: [(area: String, json: String)] = [] }
        let frames = Frames()
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: { if once { return nil }; once = true; return fake }),
                             publish: { a, j in frames.sent.append((a, j)) }, log: { _ in }, canWrite: { true })
        core.start()
        defer { core.stop() }
        func wait(_ what: String, _ ok: () -> Bool) async throws {
            let end = Date().addingTimeInterval(10)
            while Date() < end, !ok() { try await Task.sleep(for: .milliseconds(20)) }
            #expect(ok(), "\(what)")
        }
        try await wait("connected") { core.session.isConnected && core.session.skiffSong?.song != nil }
        if !fake.playing { core.handle(json: #"{"intent":"play"}"#) }
        try await wait("playing with a clock") { core.session.playing && core.session.clockTicks >= 24 }
        try await Task.sleep(for: .milliseconds(500))                          // (the first reads settle)
        frames.sent.removeAll()
        try await Task.sleep(for: .seconds(3))
        let heads = frames.sent.filter { $0.area == "playhead" }.compactMap { try? JSONDecoder().decode(PlayheadArea.self, from: Data($0.json.utf8)) }
        let editors = frames.sent.filter { $0.area == "editor" }
        var counts: [String: (n: Int, bytes: Int)] = [:]
        for f in frames.sent { counts[f.area, default: (0, 0)].n += 1; counts[f.area, default: (0, 0)].bytes += f.json.utf8.count }
        print("AREAS IN 3 S PLAYING:", counts.sorted { $0.value.bytes > $1.value.bytes }.map { "\($0.key) \($0.value.n)x \($0.value.bytes) B" }.joined(separator: ", "))
        // a step at a time: several in three seconds, each small, on the editor's track, with the pulses to run between
        #expect(heads.count >= 4, "\(heads.count) playhead frames in 3 s")
        #expect(frames.sent.filter { $0.area == "playhead" }.allSatisfy { $0.json.utf8.count < 160 })
        let t = core.editorTrack()
        for h in heads where h.step >= 0 {
            #expect(h.track == t + 1 && h.step < h.steps && h.steps == core.session.tracks[t].length)
            let a = try #require(h.startTick), b = try #require(h.nextTick)
            #expect(b > a)
        }
        // forward: each frame the step after the last (wrapping at the pattern's length)
        if core.session.tracks[t].direction == 0 {
            let steps = heads.map(\.step).filter { $0 >= 0 }
            for (x, y) in zip(steps, steps.dropFirst()) { #expect(y == (x + 1) % heads[0].steps || y == x, "\(steps)") }
        }
        // the editor: not once for the playhead (nothing in it changed)
        #expect(editors.isEmpty, "\(editors.count) editor frames while only the playhead moved")
        // nor the pads and the Timeline many times a second (they were, 19 times: 180 KB a second between them)
        let pads = counts["pads"]?.n ?? 0, timeline = counts["timeline"]?.n ?? 0
        #expect(pads <= 12 && timeline <= 12, "pads \(pads), timeline \(timeline) frames in 3 s")
        #expect(frames.sent.reduce(0) { $0 + $1.json.utf8.count } < 60_000, "bytes sent in 3 s of playing")
        #expect(core.editorArea().playhead == -1)
        // stopped: the playhead says so
        core.handle(json: #"{"intent":"stop"}"#)
        try await wait("stopped") { !core.session.playing }
        try await wait("no step") { core.playheadArea().step == -1 && core.playheadArea().startTick == nil }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }
}

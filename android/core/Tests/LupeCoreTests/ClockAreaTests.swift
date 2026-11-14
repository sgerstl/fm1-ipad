import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The clock reference and the launch countdowns (Scott's play test, 2026-11-14) on FakeSkiff's demo while it plays:
/// the reference run forward stays on the session's count, a pass bar from the row's ticks matches the session's, a
/// waiting pad, mute and scene carry the pulse they land on, and the readout's bar stays within its bars.
@Suite(.serialized) @MainActor struct ClockAreaTests {
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
}

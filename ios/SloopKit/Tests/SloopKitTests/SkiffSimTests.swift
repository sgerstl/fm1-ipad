import Foundation
import Testing
@testable import SloopKit

/// Against skiff-sim (Skiff 2.2's own firmware on the Mac, `skiff-sim/`), over CoreMIDI. Skipped unless
/// SKIFF_SIM=1, so `swift test` stays offline. Run the sim first: `skiff-sim/build/skiff-sim`.
///   SKIFF_SIM=1 swift test --filter SkiffSimTests
/// SKIFF_RECORD=1 also writes Sources/SloopKit/Resources/skiff-2.2.json (what FakeSkiff answers with) from the sim.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct SkiffSimTests {
    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return s
    }

    @Test func detectsSkiffAndFindsItsIDs() async throws {
        let d = try await driver()
        #expect(d.dialect == .skiff)
        #expect(d.shape.trackCount == 6 && d.shape.stepCount == 64 && d.shape.drumTrack == nil)
        #expect(!d.shape.canPlay(track: 4, engine: 9) && d.shape.canPlay(track: 0, engine: 9))
        #expect(d.info.paramCount == 146 && d.info.firstEngineParam == 138)
        #expect(d.params.chord == 81 && d.params.direction == 91 && d.params.swing == 31)
        let pages = d.pageLayout ?? []
        #expect(pages.first { $0.title == "ENV 2" }?.ids == [97, 98, 99, 100])
        #expect(pages.first { $0.title == "INSERT" }?.ids == [121, 122, 123, 124])
        #expect(pages.first { $0.title == "CHORUS" }?.ids == [10, 11, 25, 26])
        let e = try await d.desc(scope: 0, id: 138)               // scope 2 on the wire
        #expect(e.label == "WAVE" && e.id == 138)
        if ProcessInfo.processInfo.environment["SKIFF_RECORD"] == "1" { try await record(d) }
        await d.close()
    }

    /// The firmware's motion_param against Lupe's port (SkiffMotion): a set on each id is taken exactly when Lupe
    /// offers it as a lane, refused (rc 1) otherwise; each one taken is deleted again.
    @Test func motionIsRecordedExactlyWhereLupeOffersIt() async throws {
        let d = try await driver()
        for id in [0, 9, 16, 17, 24, 31, 32, 34, 37, 39, 44, 51, 60, 61, 81, 83, 91, 92, 101, 117, 126, 127, 135, 138, 145] {
            let desc = try await d.desc(scope: 0, id: id)
            let r = try await d.setMotion(track: 0, step: 63, id: id, value: desc.defaultValue, lock: false)
            #expect((r.rc == .done) == SkiffMotion.recordable(id), "id \(id): rc \(r.rc)")
            if r.rc == .done { _ = try await d.deleteMotion(track: 0, step: 63, id: id) }
        }
    }

    @Test func stepsRoundTripKeepingSkiffsBytes() async throws {
        let d = try await driver()
        let before = try await d.synthStep(track: 5, index: 63)
        var s = SynthStep(notes: [60, 64], time: .note, accent: true, slide: false, velocity: 90)
        s.extra = before.extra
        let stored = try await d.setSynthStep(track: 5, index: 63, s)
        #expect(stored.notes == [60, 64] && stored.accent && stored.velocity == 90)
        #expect(stored.extra.count == before.extra.count)
        _ = try await d.setSynthStep(track: 5, index: 63, before)       // put it back
        #expect(try await d.synthStep(track: 5, index: 63) == before)
        // a wide id through TRACK_PARAM: bit 6 of the track byte
        let v = try await d.trackParam(track: 2, id: 140)
        #expect(try await d.setTrackParam(track: 2, id: 140, value: 33) == 33)
        _ = try await d.setTrackParam(track: 2, id: 140, value: v)
        await d.close()
    }

    @Test func sessionFollowsTheSimAndCountsItsClock() async throws {
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return MIDITransport() })
        let run = Task { await session.run() }
        try await waitFor(20) { if case .connected = session.status { true } else { false } }
        #expect(session.dialect == .skiff && session.trackCount == 6 && session.tracks.count == 6)
        #expect(session.tracks.allSatisfy { $0.loaded && $0.steps.count == 64 && !$0.isDrums })
        #expect(session.pageLayout?.isEmpty == false)
        #expect(session.tracks[0].engineName == "ANALOG")

        // a note from the iPad, read back by the device's own reply
        let i = 47
        let had = session.tracks[1].steps[i]
        session.write(track: 1, index: i, SynthStep(notes: [67], time: .note, accent: false, slide: false, velocity: 100))
        try await waitFor { session.tracks[1].steps[i].notes == [67] }

        // PLAY: TRANSPORT says so, and the counted playhead moves on T1 (LENGTH 16, 1/16 by default)
        session.setPlaying(true)
        try await waitFor(5) { session.playing }
        try await Task.sleep(for: .seconds(1.2))
        try await waitFor(5) { session.positions[0].step != 0 }
        let s1 = session.positions[0].step
        try await Task.sleep(for: .milliseconds(400))
        #expect(session.positions[0].step != s1)
        session.setPlaying(false)
        try await waitFor(5) { !session.playing }

        session.write(track: 1, index: i, had)
        try await Task.sleep(for: .milliseconds(300))
        run.cancel()
    }

    /// CountedPlayhead against the sequencer's own step: skiff-sim's --truth sends each track's playing step
    /// (`F0 7D 53 4D s0..s5 F7`) whenever one changes. Six tracks of different LENGTH, DIV, DIR and swing,
    /// then a BPM change (the shift) and a LENGTH change mid-play. Needs the sim run with --truth:
    ///   SKIFF_SIM=1 SKIFF_TRUTH=1 swift test --filter SkiffSimTests
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SKIFF_TRUTH"] == "1"))
    func countedPlayheadMatchesTheSimsOwnStep() async throws {
        let d = try await driver()
        guard let watch = MIDITransport() else { throw ClientError.timeout("no port") }
        let ids = d.params
        let dir = try #require(ids.direction), sw = try #require(ids.swing)
        var settings: [CountedPlayhead.Settings] = [
            .init(length: 5, division: 2), .init(length: 4, division: 3, direction: 1, swing: 40),
            .init(length: 6, division: 4, direction: 2), .init(length: 7, division: 1),
            .init(length: 3, division: 5, direction: 2, swing: 20), .init(length: 16, division: 2, swing: 10)]
        var saved: [[Int]] = []
        for (t, c) in settings.enumerated() {
            var was: [Int] = []
            for (id, v) in [(ids.length, c.length), (ids.division, c.division), (dir, c.direction), (sw, c.swing)] {
                was.append(try await d.trackParam(track: t, id: id))
                _ = try await d.setTrackParam(track: t, id: id, value: v)
            }
            saved.append(was)
        }
        let bpm0 = try await d.global(id: ids.bpm), gsw0 = try await d.global(id: ids.globalSwing)
        _ = try await d.setGlobal(id: ids.bpm, value: 137); _ = try await d.setGlobal(id: ids.globalSwing, value: 0)

        var model = CountedPlayhead(tracks: 6)
        var history: [[(step: Int, start: Double)]] = []  // the model's steps at each tick, and when each began
        var reports: [(tick: Int, steps: [Int])] = []
        let clock = Task { @MainActor in
            for await e in watch.clock {
                switch e {
                case .start: model.start(); history = []
                case .tick:
                    model.tick(settings, globalSwing: 0)
                    if model.running { history.append(model.walks.map { ($0.step, $0.startedAt) }) }
                default: break
                }
            }
        }
        let truth = Task { @MainActor in
            for await f in watch.frames where f.count == 11 && Array(f.prefix(4)) == [0xF0, 0x7D, 0x53, 0x4D] {
                if model.running { reports.append((history.count - 1, f[4..<10].map(Int.init))) }
            }
        }
        _ = try await d.transport(play: true)
        try await Task.sleep(for: .seconds(3))
        _ = try await d.setGlobal(id: ids.bpm, value: 90)          // the shift: applied as Jib would, on sending
        let changeTick = history.count
        model.tempoChanged(from: 137, to: 90)
        try await Task.sleep(for: .seconds(2))
        _ = try await d.setTrackParam(track: 0, id: ids.length, value: 3)
        settings[0].length = 3
        try await Task.sleep(for: .seconds(2))
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        clock.cancel(); truth.cancel()

        // a report can come before its step's (fractional) start: the sequencer runs an audio block (~0.4
        // tick) ahead of its MIDI, and the clock and the reports are read from two streams, up to a tick
        // apart. The model's step at that tick counts, or one starting within 1.5 ticks after it
        // before the BPM change: exact. After it: the shift, which Jib can only time to a few ms (a track with
        // a step boundary inside that window can stay a step off), so a looser bar and the rate printed
        var checked = [0, 0], matched = [0, 0], misses: [String] = []
        for r in reports where r.tick >= 0 && r.tick + 2 < history.count {
            let phase = r.tick < changeTick - 3 ? 0 : 1               // (the device may switch a moment before the model)
            for t in 0..<6 {
                checked[phase] += 1
                let ahead = (1...2).map { history[r.tick + $0][t] }.filter { $0.start <= Double(r.tick) + 1.5 }
                if history[r.tick][t].step == r.steps[t] || ahead.contains(where: { $0.step == r.steps[t] }) { matched[phase] += 1 }
                else if misses.count < 8 { misses.append("tick \(r.tick) T\(t + 1): sim \(r.steps[t]), model \(history[r.tick][t].step)") }
            }
        }
        print("counted playhead vs --truth: before the BPM change \(matched[0]) of \(checked[0]), after \(matched[1]) of \(checked[1]) (\(history.count) ticks)", misses)
        #expect(checked[0] > 300 && checked[1] > 300)
        #expect(matched[0] == checked[0])
        #expect(Double(matched[1]) >= Double(checked[1]) * 0.9)

        for (t, was) in saved.enumerated() {
            for (id, v) in zip([ids.length, ids.division, dir, sw], was) { _ = try await d.setTrackParam(track: t, id: id, value: v) }
        }
        _ = try await d.setGlobal(id: ids.bpm, value: bpm0); _ = try await d.setGlobal(id: ids.globalSwing, value: gsw0)
        await d.close()
    }

    /// What FakeSkiff answers with, from the sim: INFO, every DESC, NAMES, TRACK, each track's steps and
    /// parameters (TRACK_DUMP), the globals, UP_LIST.
    private func record(_ d: SkiffDriver) async throws {
        let c = d.client
        func raw(_ cmd: UInt8, _ a: [UInt8], _ match: Int) async throws -> [UInt8] {
            try await c.send(.raw(cmd: cmd, args: a, match: match, name: "rec"))
        }
        var f = SkiffFixture()
        f.info = try await raw(1, [], 0)
        for id in 0..<d.info.paramCount { f.desc["0.\(id)"] = try await raw(5, SkiffDriver.wire(id), 2) }
        for id in 0..<d.info.globalCount { f.desc["1.\(id)"] = try await raw(5, [1, UInt8(id)], 2) }
        for e in 0..<d.info.engines.count { f.names["\(e)"] = try await raw(10, [UInt8(e)], 1) }
        f.track = try await raw(27, [], 0)
        for t in 0..<d.shape.trackCount {
            f.trackDump["\(t)"] = try await raw(29, [UInt8(t)], 1)
            for i in 0..<d.shape.stepCount { f.steps["\(t).\(i)"] = try await raw(30, [UInt8(t), UInt8(i)], 2) }
        }
        f.dump = try await raw(4, [], 0)
        f.userList = try await raw(16, [0, 16], 1)
        f.transport = try await raw(76, [], 0)
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/SloopKit/Resources/skiff-2.2.json").standardized
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        try enc.encode(f).write(to: url)
    }
}

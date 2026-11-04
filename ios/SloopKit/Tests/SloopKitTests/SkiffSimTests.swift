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

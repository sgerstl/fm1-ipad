import Foundation
import Testing
@testable import SloopKit

/// Skiff 2.2 offline: FakeSkiff answers with what skiff-sim answered (Resources/skiff-2.2.json).
@Suite(.serialized) @MainActor struct SkiffTests {
    private func connected() async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let session = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor(10) { if case .connected = session.status { true } else { false } }
        return (session, fake, run)
    }

    @Test func infoFromTheSimIsSkiff() throws {
        let fx = try SkiffFixture.load()
        let info = try DeviceInfo(fx.info)
        #expect(FirmwareDialect.detect(info, body: fx.info) == .skiff)
        let s = try #require(SkiffInfo(fx.info))
        #expect(s.paramCount == 146 && s.firstEngineParam == 138 && s.trackCount == 6)
        #expect(s.lightTracks == 0x30 && s.lightEngines == 1 << 8 | 1 << 9)       // T5, T6: not GRAIN, PHYS
        #expect(s.hasTies && s.hasFlam)
        // another Felucca, or Skiff without the tags this driver needs, is refused
        #expect(FirmwareDialect.detect(info, body: []) == nil)
        var other = info; other.version = "FELUCCA v1.1.5"
        #expect(FirmwareDialect.detect(other, body: fx.info) == nil)
    }

    @Test func sessionReadsSixTracksAndSkiffsPages() async throws {
        let (s, _, run) = try await connected()
        #expect(s.dialect == .skiff && s.trackCount == 6 && s.drumTrack == nil)
        #expect(s.tracks.count == 6 && s.tracks.allSatisfy { $0.loaded && !$0.isDrums && $0.steps.count == 64 })
        #expect(s.tracks.map(\.engineName) == ["ANALOG", "FM6", "LOFI", "DRUM", "SAMPLE", "DRUM"])
        #expect(s.ids.chord == 81 && s.ids.direction == 91)
        #expect(s.shape.trackColours == DeviceShape.skiffColours && s.shape.trackColours.count >= s.trackCount)
        #expect(s.ids.drumLevel == nil && s.ids.otherChannels == nil)
        #expect(!s.capabilities.contains(.livePlayhead) && !s.capabilities.contains(.sloopSong) && !s.capabilities.contains(.screenLink))
        let pages = try #require(s.pageLayout)
        #expect(pages.first { $0.title == "EDIT 1" }?.ids == [138, 139, 140, 141])
        #expect(pages.first { $0.title == "PATTERN" }?.ids == [29, 30, 31, 32])
        #expect(s.trackDescs[138]?.label == "WAVE")
        // the EDIT engine pages after EDIT 2, the lanes' parameters found from the first KICK (core.h: LN 83, LTUNE 101,
        // LDECAY 109, LPAN 127; PAN 39 and ENV's DECAY come before and mustn't be taken)
        #expect(pages.filter { $0.family == "EDIT" }.map(\.title)
                == ["EDIT 1", "EDIT 2", "OPERATOR", "ALL OPS", "LANES", "SOUND", "LANE MIX", "SLICES", "SAMPLES", "VOICE", "VOICE 2"])
        let lanes = try #require(pages.first { $0.title == "LANES" })
        #expect(lanes.engines == [10] && lanes.picks.count == 8 && lanes.picks[1] == [84, 102, 110] && lanes.picks[7] == [90, 108, 116])
        let mix = try #require(pages.first { $0.title == "LANE MIX" })
        #expect(mix.engines == [10, 14] && mix.picks[0] == [83, 127, nil] && mix.picks[7] == [90, 134, nil])
        #expect(pages.first { $0.title == "SLICES" }?.ids == [138, 139, nil, nil])
        #expect(s.bpm == 120)
        run.cancel()
    }

    @Test func editsKeepTheStepsOwnBytesAndOneRequestAtATime() async throws {
        let (s, fake, run) = try await connected()
        s.toggle(track: 4, index: 3, note: 62)
        try await waitFor { fake.steps[4][3].prefix(2) == [1, 62] }
        #expect(fake.steps[4][3].count == 17)                     // hits, chance, ratchet, FLAM, COND, NUDGE, ties kept
        // a burst: a knob drag and a run of steps, as fast as the views send them
        for v in 0..<40 { s.set(track: 2, param: 140, to: v) }
        for i in 0..<16 { s.toggle(track: 0, index: i, note: 48 + i) }
        try await waitFor { fake.params[2][140] == 39 && fake.steps[0][15].prefix(2) == [1, 63] }
        #expect(fake.dropped == 0)                                  // nothing sent while a request was in flight
        run.cancel()
    }

    @Test func transportPlaysAndFollowsTheDevice() async throws {
        let (s, fake, run) = try await connected()
        s.setPlaying(true)
        try await waitFor { fake.playing }
        try await Task.sleep(for: .seconds(1.6))                    // past the iPad's own write's grace
        fake.playing = false                                        // STOP on the device
        try await waitFor(3) { !s.playing }
        fake.selected = 3                                           // a track picked on the device
        try await waitFor(3) { s.selectedTrack == 3 }
        run.cancel()
    }

    @Test func pushesUseWholeIDs() {
        #expect(SkiffDriver.normalize(.changed(scope: 2, id: 10, value: 5)) == .changed(scope: 0, id: 138, value: 5))
        #expect(SkiffDriver.normalize(.trackChanged(track: 0x42, id: 12, value: 1)) == .trackChanged(track: 2, id: 140, value: 1))
        #expect(SkiffDriver.wire(140) == [2, 12] && SkiffDriver.trackID(5, 140) == [0x45, 12])
    }

    // MARK: The counted playhead (CountedPlayhead), against Skiff's seq_next walks

    private func run(_ s: [CountedPlayhead.Settings], ticks: Int, globalSwing: Int = 0) -> [[Int]] {
        var p = CountedPlayhead(tracks: s.count)
        p.start()
        var out: [[Int]] = Array(repeating: [], count: s.count), next = Array(repeating: -1.0, count: s.count)
        for _ in 0..<ticks {
            p.tick(s, globalSwing: globalSwing)
            for t in s.indices where p.walks[t].nextAt != next[t] { out[t].append(p.steps[t]); next[t] = p.walks[t].nextAt }
        }
        return out
    }

    @Test func walksForwardBackwardAndPing() {
        let r = run([.init(length: 5, division: 2), .init(length: 4, division: 2, direction: 1),
                     .init(length: 4, division: 3, direction: 2), .init(length: 1, division: 2, direction: 2)], ticks: 6 * 8)
        #expect(r[0] == [0, 1, 2, 3, 4, 0, 1, 2])
        #expect(r[1] == [3, 2, 1, 0, 3, 2, 1, 0])
        #expect(Array(r[2].prefix(9)) == [0, 1, 2, 3, 2, 1, 0, 1, 2])   // 1/32: twice as many
        #expect(r[3].allSatisfy { $0 == 0 })
    }

    @Test func stepsLastTheirDivisionAndSwingByPosition() {
        var p = CountedPlayhead(tracks: 2)
        p.start()
        let s: [CountedPlayhead.Settings] = [.init(length: 16, division: 4), .init(length: 5, division: 2, swing: 50)]
        var starts: [[Int]] = [[], []], next = [-1.0, -1.0]
        for _ in 0..<60 {
            p.tick(s, globalSwing: 0)
            for t in 0..<2 where p.walks[t].nextAt != next[t] { starts[t].append(p.ticks); next[t] = p.walks[t].nextAt }
        }
        #expect(Array(starts[0].prefix(4)) == [0, 8, 16, 24])             // 8T: 8 ticks
        // swing 50: even positions 6 × 1.2 = 7.2 ticks, odd 4.8; L5 plays 4 then 0, both long
        #expect(Array(starts[1].prefix(7)) == [0, 8, 12, 20, 24, 32, 39])
    }

    @Test func lengthChangesAtTheNextStepAndRandShowsNone() {
        var p = CountedPlayhead(tracks: 2)
        p.start()
        var s: [CountedPlayhead.Settings] = [.init(length: 16, division: 2), .init(length: 8, division: 2, direction: 3)]
        for _ in 0..<(6 * 10 + 1) { p.tick(s, globalSwing: 0) }    // step 10
        #expect(p.steps[0] == 10 && p.steps[1] == -1)
        s[0].length = 4
        for _ in 0..<6 { p.tick(s, globalSwing: 0) }
        #expect(p.steps[0] == 3)                                    // (10 + 1) mod 4: carries on from where it was
    }

    @Test func aTempoChangeShiftsTheStepPlayingAndTheGridAfter() {
        var p = CountedPlayhead(tracks: 1)
        p.start()
        let s: [CountedPlayhead.Settings] = [.init(length: 16, division: 2)]
        for _ in 0...15 { p.tick(s, globalSwing: 0) }              // tick 15: step 2, 3 ticks in (it began on 12)
        #expect(p.steps[0] == 2)
        p.tempoChanged(from: 90, to: 150)                           // ends 6 − 3 × 150/90 = 1 tick from now
        p.tick(s, globalSwing: 0)
        #expect(p.steps[0] == 3)                                    // tick 16, not 18
        for _ in 0..<6 { p.tick(s, globalSwing: 0) }
        #expect(p.steps[0] == 4 && p.walks[0].startedAt == 22)     // the grid stays 2 ticks early
    }

    @Test func aRandTrackIsPlacedByItsNotes() {
        var p = CountedPlayhead(tracks: 1)
        p.start()
        let s: [CountedPlayhead.Settings] = [.init(length: 8, division: 2, direction: 3)]
        for _ in 0...10 { p.tick(s, globalSwing: 0) }
        #expect(p.steps[0] == -1)
        p.anchor(track: 0, step: 5, s[0])
        #expect(p.steps[0] == 5)
        for _ in 0..<6 { p.tick(s, globalSwing: 0) }
        #expect(p.steps[0] == -1)                                   // unknown again until the next note
    }
}

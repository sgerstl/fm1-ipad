import Foundation
import Testing
@testable import SloopKit

/// HOME's four knobs as the phones read them (DeviceSession.homeKnobs, shared by Android's PhoneCore and the iPhone),
/// on FakeSkiff 2.5.1: the engine's four as the FM-1 shows them, the FM-1's own turn, the write, another track.
@Suite(.serialized) @MainActor struct SkiffHomeKnobsTests {
    private func connect() async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load(.v2_5_1))
        fake.screenLink = true
        fake.screenLinkVersion = 6
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        try await waitFor(5) { s.screenLinked && fake.screenWatched }
        return (s, fake, run)
    }

    @Test func theFourAreTheEnginesAsTheFM1ShowsThem() async throws {
        let (s, fake, run) = try await connect()
        defer { run.cancel() }
        let h = try #require(s.homeKnobs)
        let ids = try #require(s.homeKnobIDs)
        #expect(h.track == s.selectedTrack && h.knobs.count == 4 && h.knobs.map(\.id) == ids)
        #expect(h.engine == s.tracks[h.track].engineName.uppercased() && h.preset == s.tracks[h.track].presetName)
        for k in h.knobs {
            // the label and text a sound page's column has for the same parameter
            let d = s.trackDesc(k.id)
            #expect(k.label == d?.label && k.value == s.cell(k.id).value && k.text == formatValue(d, k.value, skiff: true).shown)
            #expect(k.scope == 0 && !k.locked && k.min <= k.max)
        }
        #expect(h.hot == nil)
        // the FM-1's own knob 2: the value follows and knob 2 is hot
        let to = h.knobs[1].value == h.knobs[1].min ? h.knobs[1].min + 1 : h.knobs[1].min
        fake.turnKnobOnDevice(id: ids[1], to: to)
        try await waitFor(3) { s.homeKnobs?.hot == 1 && s.homeKnobs?.knobs[1].value == to }
        #expect(s.homeKnobs?.hotAt != nil)
        // the phone turns knob 3
        let k3 = h.knobs[2], v3 = k3.value == k3.max ? k3.max - 1 : k3.max
        #expect(s.setHomeKnob(2, to: v3))
        try await waitFor(3) { fake.params[s.selectedTrack][ids[2]] == v3 }
        #expect(s.homeKnobs?.knobs[2].value == v3)
        #expect(!s.setHomeKnob(4, to: 0) && !s.setHomeKnob(-1, to: 0))
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func theyFollowTheSelectedTrack() async throws {
        let (s, _, run) = try await connect()
        defer { run.cancel() }
        let e0 = try #require(s.info?.firstEngineParam)
        let other = try #require(s.tracks.indices.first { $0 != s.selectedTrack && s.tracks[$0].engine != s.tracks[s.selectedTrack].engine })
        s.select(track: other)
        try await waitFor(3) { s.selectedTrack == other }
        let h = try #require(s.homeKnobs)
        #expect(h.track == other && h.knobs.map(\.id) == SkiffHomeKnobs.ids(engine: s.tracks[other].engine, firstEngineParam: e0))
    }
}

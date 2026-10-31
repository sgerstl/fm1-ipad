import Foundation
import Testing
@testable import SloopKit

@Suite(.serialized) @MainActor struct SessionTests {
    @Test func clientMatchesRepliesAndRetries() async throws {
        let fake = FakeSloop(autoEdits: false)
        let c = SloopClient(transport: fake)
        await c.start()
        let info = try await c.info()
        #expect(info.isSupported)
        let s = try await c.synthStep(track: 0, index: 8)
        #expect(s.notes == [70, 72, 75, 79] && s.accent)
        let d = try await c.drumStep(index: 4)
        #expect(d.lanes == [0, 3])
        await c.close()
    }

    @Test func refusesOtherFirmware() async throws {
        let session = SloopSession(transport: {
            let f = FakeSloop(autoEdits: false); f.version = "FELUCCA SLOOP 2.9.0"; return f
        })
        let run = Task { await session.run() }
        try await waitFor { if case .wrongFirmware = session.status { true } else { false } }
        #expect(session.status == .wrongFirmware(found: "FELUCCA SLOOP 2.9.0", protocolVersion: 12))
        run.cancel()
    }

    @Test func readsAllTracksAndFollowsPushes() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        #expect(session.tracks.allSatisfy { $0.loaded })
        #expect(session.tracks[0].steps[8].notes == [70, 72, 75, 79])
        #expect(session.tracks[0].presetName == "DX RHODES")
        #expect(session.tracks[3].drumSteps[0].has(0))
        #expect(session.tracks[0].length == 32 && session.tracks[0].scale == 2)

        // An edit on the device: the step changes, then STEP_CHANGED arrives.
        fake.edit(track: 0, index: 1, step: SynthStep(notes: [48], time: .note, accent: false, slide: false, velocity: 64))
        try await waitFor { session.tracks[0].steps[1].notes == [48] }
        try await waitFor { session.stats.polls > 5 }
        #expect(session.playing)
        run.cancel()
    }

    @Test func playheadInterpolatesBetweenPolls() {
        let session = SloopSession(transport: { nil })
        let t0 = Date()
        func live(_ step: Int) -> LiveState {
            LiveState(playing: true, bpm: 120, selected: 0, tracks: (0..<4).map { _ in .init(step: step, length: 16, meter: 0) })
        }
        session.applyLive(live(3), at: t0)
        session.applyLive(live(4), at: t0.addingTimeInterval(0.04))
        // 120 BPM sixteenths: 0.125 s a step. Half a step after the change, about 4.5.
        let mid = session.playhead(track: 0, at: t0.addingTimeInterval(0.02 + 0.0625))
        #expect(abs(mid - 4.5) < 0.1)
        #expect(session.playhead(track: 0, at: t0.addingTimeInterval(5)) < 5)   // never runs past the next step
        #expect(session.playhead(track: 0, at: t0, interpolate: false) == 4)
    }
}

@MainActor
func waitFor(_ timeout: TimeInterval = 5, _ cond: () -> Bool) async throws {
    let end = Date().addingTimeInterval(timeout)
    while !cond() {
        if Date() > end { Issue.record("timed out waiting"); return }
        try await Task.sleep(for: .milliseconds(20))
    }
}

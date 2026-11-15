import Foundation
import Testing
@testable import SloopKit

/// The keys' lit notes (DeviceSession.sounding) on a kit track while playing (Scott, 2026-11-15: record on a drum track
/// with the keyboard drawer open crashed every time, Array index out of range in `sounding`). A Skiff kit track (engine
/// DRUM or DRUM-X) is a kit but not a fixed drum track, so its drumSteps is empty: its lanes live in its steps.
@MainActor @Suite(.serialized) struct SoundingKitTests {
    @Test func aKitTrackPlayingLightsItsLanesWithoutCrashing() async throws {
        let fake = FakeSkiff(try SkiffFixture.load())
        let drum = 10                                       // INFO's engines: 10 DRUM
        fake.engines[0].engine = drum                       // T1 on the DRUM engine: a kit
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { #expect(fake.unansweredCommands.isEmpty, "the app sent a request this fake was never taught"); run.cancel() }
        try await waitFor { if case .connected = s.status { true } else { false } }
        #expect(s.info?.engines[safe: drum] == "DRUM")
        s.select(track: 0)
        try await waitFor { s.selectedTrack == 0 }
        #expect(s.isKit(0) && !s.isDrums(0))
        #expect(s.tracks[0].drumSteps.isEmpty)               // (the crash's cause: nothing there to index)
        s.setPlaying(true)
        try await waitFor { s.playing }
        // the playhead runs through every step while the keys ask what sounds, as KeyboardDrawer does each frame
        let end = Date().addingTimeInterval(2.5)
        while Date() < end {
            let lit = s.sounding
            let i = s.positions[0].step % s.stepCount
            #expect(lit == Set(s.tracks[0].gridSteps[i].lanes))
            try await Task.sleep(for: .milliseconds(20))
        }
        s.setPlaying(false)
    }
}

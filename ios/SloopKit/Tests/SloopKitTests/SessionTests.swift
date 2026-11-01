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

    @Test func editsFromTheIPadReachTheDeviceAndStick() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .milliseconds(200)        // re-reads race the writes on purpose
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }

        session.toggle(track: 0, index: 2, note: 72)            // step 3 was a TIE: becomes a C5 note
        #expect(session.tracks[0].steps[2].notes == [72])        // shown at once
        session.toggle(track: 0, index: 8, note: 79)            // remove G5 from the chord on step 9
        session.toggle(drumIndex: 1, lane: 2)                    // a snare on step 2
        session.set(track: 1, param: Param.pan, to: -20)
        session.set(global: Global.swing, to: 40)
        try await Task.sleep(for: .milliseconds(800))            // several re-sync passes later

        // what the device stored (the fake's state; its frames stream has one reader, the session)
        #expect(fake.steps[0][2].notes == [72])
        #expect(fake.steps[0][8].notes == [70, 72, 75])
        #expect(fake.drums[1].has(2))
        #expect(fake.params[1][Param.pan] == -20)
        #expect(fake.swing == 40)
        #expect(session.tracks[0].steps[2].notes == [72])        // and the app still agrees
        #expect(session.tracks[1].pan == -20 && session.swing == 40)

        session.toggle(track: 0, index: 2, note: 72)            // off again: an empty REST
        try await waitFor { session.tracks[0].steps[2].time == .rest }
        run.cancel()
    }

    @Test func libraryLoadsPresetsUserPresetsAndKits() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        #expect(session.namesCache.count == 12)                      // every engine's names, read at connect
        #expect(session.userPresets.map(\.slot) == [0, 1, 4])

        session.loadPreset(engine: 0, index: 3)                       // ANALOG REESE onto track 1 (was DIGITAL)
        #expect(session.tracks[0].engineName == "ANALOG" && session.tracks[0].presetName == "REESE")
        try await waitFor { fake.engine[0] == 0 && fake.preset[0] == 3 }

        session.toggleMute(track: 0)                                  // mute holds past the write guard, via LIVE
        try await Task.sleep(for: .milliseconds(1700))
        #expect(session.tracks[0].mute && fake.params[0][Param.mute] == 1)

        session.setLength(track: 0, start: 8, steps: 3)               // stretch step 9's chord over 3 steps
        #expect(session.tracks[0].steps[9].time == .tie && session.tracks[0].steps[10].time == .tie)
        try await waitFor { fake.steps[0][10].time == .tie }
        session.setLength(track: 0, start: 8, steps: 1)               // and back
        try await waitFor { fake.steps[0][9].time == .rest && fake.steps[0][10].time == .rest }
        session.setLength(track: 0, start: 8, steps: 20)              // stops before step 13's own notes
        #expect(session.tracks[0].steps[11].time == .tie && session.tracks[0].steps[12].time == .note)
        session.setLength(track: 0, start: 8, steps: 1)

        let cleared = session.clearAll(track: 1)                       // clear all, then undo
        #expect(session.tracks[1].steps.allSatisfy { $0 == .empty })
        try await waitFor { fake.steps[1].allSatisfy { !$0.isOn } }
        session.undo(cleared)
        try await waitFor { fake.steps[1][0].notes == [36] }
        #expect(session.tracks[1].steps[0].notes == [36])

        session.select(track: 3)                                      // the drum track: kits come from DESC
        try await waitFor { !session.kitNames.isEmpty }
        session.loadKit(6)
        try await waitFor { fake.params[3][63] == 6 }
        #expect(session.tracks[3].displayName == "Drums · 808")
        run.cancel()
    }

    @Test func everyParameterAndFollowingTheKnobs() async throws {
        let fake = FakeSloop(autoEdits: false)
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }
        #expect(session.trackDescs.count == 71 && session.globalDescs.count == 50)
        #expect(session.trackDescs[Param.scale]?.names == Music.scales.map(\.name))
        #expect(session.params.count == 71 && session.params[Param.length] == 32 && session.params[1] == 10)

        fake.turnKnob(scope: 0, id: 34, to: 99)                       // CHO on the device
        try await waitFor { session.params[34] == 99 }
        #expect(session.lastTouched?.scope == 0 && session.lastTouched?.id == 34)
        session.set(track: 0, param: 35, to: 80)                      // DLY from the iPad
        try await waitFor { fake.params[0][35] == 80 }
        #expect(session.params[35] == 80)
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

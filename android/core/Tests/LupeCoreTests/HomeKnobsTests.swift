import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// HOME's four knobs (decision 21) on FakeSkiff 2.5.1: the area as the FM-1 shows them, kept current when the FM-1's
/// knob turns or the engine changes, the hot knob, and setHomeKnob through Session (read-only: refused).
@MainActor extension FixtureRecordingTests {
    func homes(_ r: Recorder) -> [HomeKnobsArea] {
        r.frames.filter { $0.area == "homeKnobs" }.compactMap { try? JSONDecoder().decode(HomeKnobsArea.self, from: Data($0.json.utf8)) }
    }

    @Test func homeKnobsAreTheEnginesFour() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1, engine: 0)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        try await waitFor(3, "published") { !self.homes(r).isEmpty }
        let a = try #require(homes(r).last)
        print("HOMEKNOBS", r.frames.last { $0.area == "homeKnobs" }?.json ?? "")
        #expect(a.track == 1 && a.engine == "ANALOG")
        #expect(a.controls.map(\.label) == ["CUTOFF", "RES", "ATTACK", "RELEASE"])       // eng_analog.c .knob
        let e0 = try #require(core.session.info?.firstEngineParam)
        #expect(a.controls[0].raw == fake.params[0][e0 + 4])
        // the FM-1's own knob 1 turns CUTOFF: the value follows and knob 1 is hot
        let seq = a.hotSeq
        fake.turnKnobOnDevice(id: e0 + 4, to: 10)
        try await waitFor(3, "the FM-1's turn") { self.homes(r).last.map { $0.controls[0].raw == 10 && $0.hot == 0 && $0.hotSeq != seq } ?? false }
        #expect(homes(r).last?.controls[0].value == "49 Hz")                             // param_format's CUTOFF at 10 (the dump's)
    }

    @Test func setHomeKnobTurnsTheParameter() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1, engine: 0)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let e0 = try #require(core.session.info?.firstEngineParam)
        core.handle(json: #"{"intent":"setHomeKnob","slot":1,"value":90}"#)                // RES
        try await waitFor(3, "RES on the FM-1") { fake.params[0][e0 + 5] == 90 }
        try await waitFor(3, "shown") { self.homes(r).last?.controls[1].raw == 90 }
        // another engine: its four (PHASE: DCW ENV DETUNE RELEASE, eng_phase.c .knob {E2, E3, E4, REL})
        core.handle(json: #"{"intent":"pickPreset","engine":2,"preset":0}"#)
        try await waitFor(4, "PHASE's four") { self.homes(r).last?.controls.map(\.label) == ["DCW", "ENV", "DETUNE", "RELEASE"] }
        #expect(homes(r).last?.engine == "PHASE")
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func setHomeKnobIsRefusedWhileReadOnly() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1, engine: 0)
        let (core, plug) = try await readyCore(fake, r, writes: false)
        defer { core.stop(); plug.unplug() }
        let e0 = try #require(core.session.info?.firstEngineParam)
        let before = fake.params[0][e0 + 5]
        core.handle(json: #"{"intent":"setHomeKnob","slot":1,"value":\#(before == 90 ? 91 : 90)}"#)
        try await Task.sleep(for: .milliseconds(300))
        #expect(fake.params[0][e0 + 5] == before)
    }
}

import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// Note entry from the phone's keyboard strip (decision 28) on FakeSkiff 2.5.1: a step's notes set and toggled (the
/// chord's four), a kit's hits, the audition's note-on and note-off, the editor area's new fields, and read-only
/// sending none.
@MainActor extension FixtureRecordingTests {
    /// The step as the fake holds it: its notes and time (TRACK_STEP's bytes: n, note0..3, time, flags, vel…).
    func fakeStep(_ fake: FakeSkiff, _ t: Int, _ i: Int) -> (notes: [Int], time: Int, velocity: Int) {
        let b = fake.steps[t][i]
        return (Array(b[1..<(1 + Int(min(b[0], 4)))]).map(Int.init), Int(b[5]), Int(b[7]))
    }
    func editor(_ core: PhoneCore) -> EditorArea { core.editorArea() }
    /// Whether the fake's step has `lane`'s hit (the first hit byte, after n, note0..3, time, flags, vel: bits 0…6).
    func fakeHit(_ fake: FakeSkiff, _ t: Int, _ i: Int, _ lane: Int) -> Bool { fake.steps[t][i].count > 8 && fake.steps[t][i][8] >> lane & 1 == 1 }

    @Test func setStepNotesWritesANoteAChordAndClears() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let t = core.editorTrack()
        let on = try #require((0..<16).first { core.session.tracks[t].steps[$0].isOn })
        let empty = try #require((0..<16).first { core.session.tracks[t].steps[$0].time == .rest })
        let vel = fakeStep(fake, t, on).velocity
        // one note replaces the step's, its velocity kept
        core.handle(json: #"{"intent":"setStepNotes","step":\#(on),"notes":[65]}"#)
        try await waitFor(3, "one note") { self.fakeStep(fake, t, on).notes == [65] }
        #expect(fakeStep(fake, t, on).velocity == vel)
        // an empty step: the defaults
        core.handle(json: #"{"intent":"setStepNotes","step":\#(empty),"notes":[60,64,67]}"#)
        try await waitFor(3, "a chord") { self.fakeStep(fake, t, empty).notes == [60, 64, 67] }
        #expect(fakeStep(fake, t, empty).time == StepTime.note.rawValue && fakeStep(fake, t, empty).velocity == 100)
        try await waitFor(3, "shown") { self.editor(core).steps[empty].notes == [60, 64, 67] }
        #expect(editor(core).maxNotes == 4 && editor(core).kitLanes.isEmpty && editor(core).steps[empty].on)
        // five notes: refused whole
        core.handle(json: #"{"intent":"setStepNotes","step":\#(empty),"notes":[60,62,64,65,67]}"#)
        try await Task.sleep(for: .milliseconds(250))
        #expect(fakeStep(fake, t, empty).notes == [60, 64, 67])
        // cleared
        core.handle(json: #"{"intent":"setStepNotes","step":\#(empty),"notes":[]}"#)
        try await waitFor(3, "cleared") { self.fakeStep(fake, t, empty).time == StepTime.rest.rawValue }
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func toggleStepNoteAddsToFourAndRemovesToEmpty() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let t = core.editorTrack()
        let i = try #require((0..<16).first { core.session.tracks[t].steps[$0].time == .rest })
        for (k, n) in [60, 64, 67, 71].enumerated() {
            core.handle(json: #"{"intent":"toggleStepNote","step":\#(i),"note":\#(n)}"#)
            try await waitFor(3, "note \(k + 1)") { self.fakeStep(fake, t, i).notes.count == k + 1 }
        }
        // a fifth: no room, nothing changes
        core.handle(json: #"{"intent":"toggleStepNote","step":\#(i),"note":74}"#)
        try await Task.sleep(for: .milliseconds(250))
        #expect(fakeStep(fake, t, i).notes == [60, 64, 67, 71])
        // each off again; the last empties the step
        for (k, n) in [64, 60, 71, 67].enumerated() {
            core.handle(json: #"{"intent":"toggleStepNote","step":\#(i),"note":\#(n)}"#)
            try await waitFor(3, "removed \(k + 1)") { k == 3 ? self.fakeStep(fake, t, i).time == StepTime.rest.rawValue : self.fakeStep(fake, t, i).notes.count == 3 - k }
        }
        #expect(!editor(core).steps[i].on)
    }

    @Test func toggleHitWritesAKitLane() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 4)                                    // the demo's DRUM track
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let t = core.editorTrack()
        #expect(core.session.isKit(t))
        let a = editor(core)
        #expect(a.kind == .drum && a.maxNotes == 0 && a.kitLanes.count == 8 && a.kitNotes == Music.skiffLaneNotes)
        let i = try #require((0..<16).first { !a.steps[$0].hits.contains { $0.lane == 6 } })
        core.handle(json: #"{"intent":"toggleHit","lane":6,"step":\#(i)}"#)
        try await waitFor(3, "the hit on") { self.editor(core).steps[i].hits.contains { $0.lane == 6 } && self.fakeHit(fake, t, i, 6) }
        core.handle(json: #"{"intent":"toggleHit","lane":6,"step":\#(i)}"#)
        try await waitFor(3, "the hit off") { !self.fakeHit(fake, t, i, 6) && !self.editor(core).steps[i].hits.contains { $0.lane == 6 } }
        // a note intent on a kit track is refused
        let before = fake.steps[t][i]
        core.handle(json: #"{"intent":"setStepNotes","step":\#(i),"notes":[60]}"#)
        try await Task.sleep(for: .milliseconds(250))
        #expect(fake.steps[t][i] == before)
        #expect(fake.unansweredCommands.isEmpty, "\(fake.unansweredCommands)")
    }

    @Test func playNoteSoundsTheTrackAndWritesNothing() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 3)
        let (core, plug) = try await readyCore(fake, r)
        defer { core.stop(); plug.unplug() }
        let steps = fake.steps
        core.handle(json: #"{"intent":"playNote","note":62,"on":true}"#)
        try await waitFor(3, "note on") { fake.midiIn.last == [0x92, 62, 100] }     // T3's channel
        core.handle(json: #"{"intent":"playNote","note":62,"on":false}"#)
        try await waitFor(3, "note off") { fake.midiIn.last == [0x82, 62, 0] }
        #expect(fake.steps == steps)
    }

    @Test func noteEntryIsRefusedWhileReadOnly() async throws {
        let r = Recorder()
        let fake = try linkedFake(track: 1)
        let (core, plug) = try await readyCore(fake, r, writes: false)
        defer { core.stop(); plug.unplug() }
        let steps = fake.steps
        for j in [#"{"intent":"setStepNotes","step":1,"notes":[60]}"#, #"{"intent":"toggleStepNote","step":1,"note":60}"#,
                  #"{"intent":"toggleHit","lane":0,"step":1}"#, #"{"intent":"playNote","note":60,"on":true}"#] { core.handle(json: j) }
        try await Task.sleep(for: .milliseconds(400))
        #expect(fake.steps == steps && fake.midiIn.isEmpty)
    }
}

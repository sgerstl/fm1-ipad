import Foundation
import Testing
@testable import SloopKit

@Suite struct ProjectFormatTests {
    @Test func blankIsTOOLSNew() {
        let b = Fun6.blank
        #expect(b.bytes.count == Fun6.size && b.sealed == b)            // its own checksum holds
        #expect(b.bpm == 90)
        #expect((0..<3).map(b.engine) == [0, 1, 4] && (0..<3).map(b.preset) == [0, 0, 5])
        #expect((0..<3).allSatisfy { t in b.steps(track: t).allSatisfy { $0 == .empty } })
        #expect(b.drumSteps().allSatisfy { !$0.isOn })
    }

    @Test func sloopSongRoundTrip() throws {
        var p = ProjectData.blank
        p.sections[0] = Fun6.blank.bytes
        p.sections[2] = Array(repeating: 7, count: 100)
        let file = SloopSong.encode(p, name: "Neukölln Nights")
        let json = try #require(try JSONSerialization.jsonObject(with: file) as? [String: Any])
        #expect(json["format"] as? String == "sloop-song" && json["version"] as? Int == 1)
        // as the editor writes it: the loop and the filled sections only
        #expect((json["objects"] as? [[String: Any]])?.compactMap { $0["id"] as? Int } == [0, 2, 4])
        let back = try SloopSong.decode(file)
        #expect(back.data == p && back.name == "Neukölln Nights")
    }

    @Test func sloopSongRejectsDamage() throws {
        var json = try #require(try JSONSerialization.jsonObject(with: SloopSong.encode(.blank, name: "x")) as? [String: Any])
        var objects = try #require(json["objects"] as? [[String: Any]])
        objects[0]["crc"] = 1
        json["objects"] = objects
        #expect(throws: SloopSong.ReadError.damaged(object: 0)) { try SloopSong.decode(try JSONSerialization.data(withJSONObject: json)) }
        #expect(throws: SloopSong.ReadError.notASong) { try SloopSong.decode(Data("{}".utf8)) }
    }

    @Test func stepsRoundTrip() {
        var f = Fun6.blank
        var s = Array(repeating: SynthStep.empty, count: 64)
        s[0] = SynthStep(notes: [60, 64], time: .note, accent: true, slide: false, velocity: 90, levels: [3, 1], ratchets: [0, 2])
        s[1] = SynthStep(notes: [], time: .tie, accent: false, slide: false, velocity: 90)
        f.setSteps(track: 1, s)
        var d = Array(repeating: DrumStep.empty, count: 64)
        d[5] = DrumStep.empty.setting(0, on: true, level: 3).setting(15, on: true, ratchet: 2)
        f.setDrumSteps(d)
        f.setLength(track: 2, 48)
        #expect(f.steps(track: 1)[0] == s[0] && f.steps(track: 1)[1].time == .tie && f.steps(track: 1)[2] == .empty)
        #expect(f.drumSteps()[5] == d[5] && f.length(track: 2) == 48)
        #expect(f.sealed != f && Fun6(f.sealed.bytes) != nil)
    }

    @Test func fingerprintIgnoresTheSelectedTrack() {
        var a = ProjectData.blank, b = a
        b.working[Fun6.selAt] = 2
        #expect(a.fingerprint == b.fingerprint)
        a.sections[1] = Fun6.blank.bytes
        #expect(a.fingerprint != b.fingerprint)
    }
}

@Suite(.serialized) @MainActor struct ProjectSessionTests {
    @Test func readWriteAndFingerprintOnTheDemo() async throws {
        let fake = FakeSloop(autoEdits: false)
        fake.manualClock = true
        var once = false
        let session = SloopSession(transport: { if once { return nil }; once = true; return fake })
        session.resyncInterval = .seconds(60)
        let run = Task { await session.run() }
        try await waitFor { if case .connected = session.status { true } else { false } }

        let saved = try await session.readProject()
        #expect(saved.sectionsFilled == [true, true, true, false])
        #expect(try await session.deviceFingerprint() == saved.fingerprint)

        // the demo plays from the start: a project goes on only stopped
        await #expect(throws: SloopSession.ProjectError.playing) { try await session.writeProject(.blank) }
        session.setPlaying(false)
        try await waitFor { !session.playing && !fake.playing }

        var edits = 0
        session.onEdit = { edits += 1 }
        session.toggle(drumIndex: 0, lane: 4)
        #expect(edits == 1)
        try await waitFor { fake.drums[0].has(4) }
        #expect(try await session.deviceFingerprint() != saved.fingerprint)

        // a fresh start: everything empty, 90 BPM; then the saved project back as it was
        var steps: [Double] = []
        try await session.writeProject(.blank) { steps.append($0) }
        #expect(steps.last == 1)
        #expect(fake.stored == 0 && fake.drums.allSatisfy { !$0.isOn } && fake.bpm == 90)
        try await waitFor { session.tracks[3].drumSteps.allSatisfy { !$0.isOn } && session.bpm == 90 }
        #expect(try await session.deviceFingerprint() == ProjectData.blank.fingerprint)

        try await session.writeProject(saved)
        #expect(fake.stored == 0b0111)
        #expect(try await session.deviceFingerprint() == saved.fingerprint)
        #expect(try await session.readProject().fingerprint == saved.fingerprint)
        run.cancel()
    }
}

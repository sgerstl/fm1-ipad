import Foundation
import Testing
@testable import SloopKit

/// A Skiff project out to the iPad and back in, against skiff-sim's real firmware (SKIFF_SIM=1, the sim running; with a
/// second sim, FELUCCA_PORT names its port). Writes only the sim's flash.
///   SKIFF_SIM=1 swift test --filter SkiffProjectSimTests
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct SkiffProjectSimTests {
    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return s
    }

    private func note(_ n: Int) -> SynthStep {
        var s = SynthStep.empty
        s.notes = [n]; s.time = .note; s.velocity = 100; s.levels = [0]; s.ratchets = [0]
        return s
    }

    /// Counts the chunk writes a request makes (PUT begins of ids 16…31).
    final class Counter: @unchecked Sendable { var chunkPuts = 0, projectPuts = 0 }

    @Test func roundTrip() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        // two tracks with a pattern each, a note in each
        var s = try await d.songLists()
        for t in [0, 1] {
            let free = s.tracks[t].entries.firstIndex { $0.isEmpty }
            let e = try #require(free)
            s = try await d.list(.new(track: t, entry: e)).song
            _ = try await d.list(.play(track: t, entry: e))
        }
        _ = try await d.setSynthStep(track: 0, index: 0, note(60))
        _ = try await d.setSynthStep(track: 1, index: 3, note(64))

        let saved = try await SkiffProjectTransfer.read(firmware: d.info.version, request: SkiffProjectTransfer.request(d))
        let project = try #require(saved.project)
        print("saved: patterns", saved.patterns.map(\.id), "named", project.patternIDs)
        #expect(saved.patterns.count >= 2)
        #expect(Set(saved.patterns.map(\.id)) == Set(project.patternIDs))

        // back in unchanged: every pattern is in the pool already, so only the project goes
        let c = Counter()
        let base = SkiffProjectTransfer.request(d)
        let counting: BackupRequest = { cmd, args, m in
            if cmd == SkiffProjectTransfer.put, args.first == 0 { if args[1] == 0 { c.projectPuts += 1 } else { c.chunkPuts += 1 } }
            return try await base(cmd, args, m)
        }
        try await SkiffProjectTransfer.write(saved, name: "Round trip", request: counting)
        #expect(c.chunkPuts == 0 && c.projectPuts == 1)
        let names = try await d.projects()
        print("music now", names.name, "slot", names.musicSlot as Any)
        #expect(names.name == "ROUND TRIP")

        // change T1's pattern on the FM-1, then open the saved project: its T1 pattern goes to a free id, the changed
        // one stays where it was
        let t1 = try #require(project.patternIDs.first)
        _ = try await d.setSynthStep(track: 0, index: 0, note(72))
        let changed = try await SkiffProjectTransfer.read(firmware: d.info.version, request: base)
        let changedT1 = try #require(changed.patterns.first { $0.id == t1 })
        #expect(changedT1.data != saved.patterns.first { $0.id == t1 }!.data)

        let c2 = Counter()
        let counting2: BackupRequest = { cmd, args, m in
            if cmd == SkiffProjectTransfer.put, args.first == 0 { if args[1] == 0 { c2.projectPuts += 1 } else { c2.chunkPuts += 1 } }
            return try await base(cmd, args, m)
        }
        try await SkiffProjectTransfer.write(saved, name: "Night drive", request: counting2)
        #expect(c2.chunkPuts == 1 && c2.projectPuts == 1)
        let step = try await d.synthStep(track: 0, index: 0)
        print("T1 step 1 after open:", step.notes)
        #expect(step.notes == [60])
        let after = try await SkiffProjectTransfer.read(firmware: d.info.version, request: base)
        let newT1 = try #require(after.project?.patternIDs.first)
        #expect(newT1 != t1)
        #expect(after.fingerprint == saved.fingerprint)          // the same music, under another id
        // the changed pattern is still in the pool under its own id (bytes as they were)
        let list = try await SkiffProjectTransfer.listObjects(base)
        _ = list
        let chunk = try await SkiffProjectTransfer.read(SkiffProjectTransfer.chunkObject(t1), from: SkiffProjectTransfer.offset(t1),
                                                        count: SkiffProjectTransfer.record, base)
        #expect(Data(chunk) == changedT1.data)
        #expect((try await d.projects()).name == "NIGHT DRIVE")
    }
}

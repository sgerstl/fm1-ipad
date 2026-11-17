#if canImport(CoreMIDI)
// Apple-only: not built for Android (android/BRIDGE.md §3).
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

    /// SKIFF_RECORD=1 on a new unit (no flash file): the music as BACKUP_LIST snapshots it, base64, to SKF4_OUT. How
    /// SkiffProjectData.blank (2.2) and .blank251 were captured.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SKF4_OUT"] != nil)) func capturesANewUnitsRecord() async throws {
        let d = try await driver()
        let p = try await SkiffProjectTransfer.read(firmware: d.info.version, request: SkiffProjectTransfer.request(d))
        try p.record.base64EncodedString().write(toFile: ProcessInfo.processInfo.environment["SKF4_OUT"]!, atomically: true, encoding: .utf8)
        await d.close()
    }

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

    /// Copy a slot to the iPad (ProjectStore.copySlot, 2026-11-17): the music read, the slot loaded and read, the music
    /// written back. The copy is the slot's music; what comes back is what was playing, with no new pool numbers.
    @Test func copySlotThenPutTheMusicBack() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        let base = SkiffProjectTransfer.request(d)
        // music with a pattern and a note, saved to P1
        var s = try await d.songLists()
        let e = try #require(s.tracks[0].entries.firstIndex { $0.isEmpty })
        s = try await d.list(.new(track: 0, entry: e)).song
        _ = try await d.list(.play(track: 0, entry: e))
        _ = try await d.setSynthStep(track: 0, index: 0, note(60))
        #expect(try await d.projectSaveAs(slot: 0, name: "SLOT ONE") == 0)
        let inSlot = try await SkiffProjectTransfer.read(firmware: d.info.version, request: base)
        // then changed, and not saved anywhere
        _ = try await d.setSynthStep(track: 0, index: 0, note(67))
        _ = try await d.setSynthStep(track: 0, index: 5, note(70))
        let before = try await SkiffProjectTransfer.read(firmware: d.info.version, request: base)
        #expect(before.fingerprint != inSlot.fingerprint)
        // (step 6 is a new note, but the pattern is the slot's pattern too: only the arrangement tells them apart)

        #expect(try await d.projectLoad(slot: 0))
        let copy = try await SkiffProjectTransfer.read(firmware: d.info.version, request: base)
        // A slot keeps the arrangement and names pattern numbers; it doesn't keep its own copy of the patterns (Skiff
        // 2.2, seen here 2026-11-17). Editing a pattern after saving changes the slot too, so the copy is P1's
        // arrangement with the patterns as the pool holds them now: what loading P1 on the FM-1 plays.
        #expect(copy.record == inSlot.record)
        #expect(copy.patterns.map(\.id) == before.patterns.map(\.id))
        #expect(copy.patterns.map(\.data) == before.patterns.map(\.data))
        #expect(copy.patterns.map(\.data) != inSlot.patterns.map(\.data))

        let c = Counter()
        let counting: BackupRequest = { cmd, args, m in
            if cmd == SkiffProjectTransfer.put, args.first == 0 { if args[1] == 0 { c.projectPuts += 1 } else { c.chunkPuts += 1 } }
            return try await base(cmd, args, m)
        }
        let poolBefore = try await d.pool()
        try await SkiffProjectTransfer.write(before, name: "SLOT ONE", request: counting)
        let after = try await SkiffProjectTransfer.read(firmware: d.info.version, request: base)
        print("copy: chunk puts", c.chunkPuts, "project puts", c.projectPuts)
        #expect(after.fingerprint == before.fingerprint)         // what was playing is back
        #expect((try await d.synthStep(track: 0, index: 5)).notes == [70])
        let poolAfter = try await d.pool()
        #expect(poolAfter.patterns.filter { $0.length > 0 }.count == poolBefore.patterns.filter { $0.length > 0 }.count)
        let names = try await d.projects()
        #expect(names.slots[0].used && names.slots[0].name == "SLOT ONE")   // P1 untouched
    }
}

#endif

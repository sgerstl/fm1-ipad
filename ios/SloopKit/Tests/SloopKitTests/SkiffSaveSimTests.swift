import Foundation
import Testing
@testable import SloopKit

/// The SAVE pages' commands against skiff-sim (SKIFF_SIM=1, the sim running). A user slot stored and erased again (the
/// last empty one), a pattern made, emptied and cleared again, the project slots read; nothing is saved to a project slot.
///   SKIFF_SIM=1 swift test --filter SkiffSaveSimTests
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct SkiffSaveSimTests {
    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return s
    }

    @Test func userSlotStoredAndErased() async throws {
        let d = try await driver()
        let before = try await d.userPresets()
        let used = Set(before.map(\.slot))
        let free = (0..<32).last { !used.contains($0) }
        let slot = try #require(free)
        let rcStore = try await d.userStore(slot: slot, name: "sim test")
        #expect(rcStore == 0)
        let stored = try await d.userPresets()
        print("stored", stored.filter { $0.slot == slot })
        #expect(stored.contains { $0.slot == slot && $0.name == "SIM TEST" })
        let rcErase = try await d.userErase(slot: slot)
        let after = try await d.userPresets()
        #expect(rcErase == 0 && !after.contains { $0.slot == slot })
    }

    @Test func patternEmptiedThenCleared() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        let s = try await d.songLists()
        let firstEmpty = s.tracks[5].entries.firstIndex(where: \.isEmpty)
        let e = try #require(firstEmpty)
        let r = try await d.list(.new(track: 5, entry: e))
        let p = r.song.tracks[5].entries[e].pattern - 1
        print("NEW on T6 entry", e, "pattern", p + 1, r.rc)
        var o = try await d.poolOp(1, pattern: p); print("CLEAR in use", o.rc)
        #expect(o.rc == .inUse)
        o = try await d.poolOp(2, pattern: p); print("EMPTY", o.rc, o.pool.patterns[p])
        #expect(o.rc == .done || o.rc == .empty)
        _ = try await d.list(.clear(track: 5, entry: e))
        o = try await d.poolOp(1, pattern: p); print("CLEAR unused", o.rc, o.pool.patterns[p])
        #expect([.done, .empty].contains(o.rc) && o.pool.patterns[p].length == 0)
        // playing: refused (a pattern made for it, cleared again after)
        let r2 = try await d.list(.new(track: 5, entry: e))
        let q = r2.song.tracks[5].entries[e].pattern - 1
        _ = try await d.transport(play: true)
        try await Task.sleep(for: .milliseconds(200))
        o = try await d.poolOp(2, pattern: q); print("EMPTY playing", q + 1, o.rc, o.pool.patterns[q])
        #expect(o.rc == .playing)
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        _ = try await d.list(.clear(track: 5, entry: e))
    }

    /// What a save over a used project slot takes first: a whole backup.
    @Test func backupBeforeASave() async throws {
        let d = try await driver()
        let b = try await BackupCapture.capture(driver: d)
        print("backup", b.objects.count, "objects")
        #expect(!b.objects.isEmpty)
    }

    @Test func projectSlotsRead() async throws {
        let d = try await driver()
        let p = try await d.projects()
        print("projects", p)
        #expect(p.slots.count == 4)
        // an empty slot loads nothing (and leaves the music alone)
        if let empty = p.slots.firstIndex(where: { !$0.used }) {
            let loaded = try await d.projectLoad(slot: empty)
            #expect(!loaded)
        }
    }
}

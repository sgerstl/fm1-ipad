import Foundation
import Testing
@testable import SloopKit

/// Skiff's SAVE pages through FakeSkiff: USER's slots, the pool's one-pattern housekeeping, PROJECT's slots.
@Suite(.serialized) @MainActor struct SkiffSaveTests {
    private func connect() async throws -> (DeviceSession, FakeSkiff, Task<Void, Never>) {
        let fake = FakeSkiff(try SkiffFixture.load())
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        return (s, fake, run)
    }

    @Test func aSoundStoredAndErased() async throws {
        let (s, fake, run) = try await connect()
        #expect(await s.storeUserPreset(slot: 4, name: "deep acid") == 0)
        #expect(fake.userSlots[4]?.name == "DEEP ACID" && s.userPresets.contains { $0.slot == 4 && $0.name == "DEEP ACID" })
        #expect(s.tracks[s.selectedTrack].presetName == "DEEP ACID")
        #expect(await s.eraseUserPreset(slot: 4) == 0)
        #expect(fake.userSlots[4] == nil && !s.userPresets.contains { $0.slot == 4 })
        run.cancel()
    }

    @Test func onePatternEmptiedOrCleared() async throws {
        let (s, fake, run) = try await connect()
        let store = try #require(s.skiffSong)
        fake.seedSong(); fake.poolLen[40] = 16                 // the demo song, and a pattern nothing uses
        await store.refresh(pool: true)
        let unused = 40
        #expect(store.pool?.patterns[unused].uses == 0)
        #expect(await store.poolOp(1, pattern: unused) == .done && fake.poolLen[unused] == 0)
        let used = try #require((0..<64).first { (store.pool?.patterns[$0].uses ?? 0) > 0 })
        #expect(await store.poolOp(1, pattern: used) == .inUse)
        #expect(await store.poolOp(2, pattern: used) == .done && fake.poolLen[used] > 0)     // emptied, kept
        run.cancel()
    }

    @Test func projectSlotsReadSavedAndLoaded() async throws {
        let (s, fake, run) = try await connect()
        await s.refreshSkiffProjects()
        #expect(s.skiffProjects?.slots.count == 4 && s.skiffProjects?.slots[0].name == "SONG ONE" && s.skiffProjects?.slots[1].used == false)
        #expect(await s.saveSkiffProject(slot: 2, name: "night set") == 0)
        #expect(fake.projectSlots[2] == "NIGHT SET" && s.skiffProjects?.slots[2].used == true && s.skiffProjects?.musicSlot == 2)
        #expect(await s.loadSkiffProject(slot: 0) && fake.projectLoads == 1 && s.skiffProjects?.musicSlot == 0)
        #expect(await s.loadSkiffProject(slot: 3) == false)                               // empty
        run.cancel()
    }
}

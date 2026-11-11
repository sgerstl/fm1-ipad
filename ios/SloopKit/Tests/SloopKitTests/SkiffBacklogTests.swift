import Foundation
import Testing
@testable import SloopKit

/// Scott, 2026-11-11: with lots of pattern changes the pads fell progressively behind the FM-1, and a write right after
/// stop was slow. The same rapid changes, as the app handled them before (two full 64-step rereads a change, never
/// cancelled, one first-in-first-out queue) and now (one reread of the pattern's LENGTH, cancelled by the next change,
/// in the client's back queue), with an 8 ms round trip a request: how long the song's poll takes to come back, how long
/// a pad write takes right after stop, and how many step reads went out.
@Suite(.serialized) @MainActor struct SkiffBacklogTests {
    struct Result { var polls: [Double]; var write: Double; var steps: Int }

    private func run(legacy: Bool) async throws -> Result {
        let fake = try #require(FakeSkiff(demo: true))
        fake.replyDelay = 0.008
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(600)
        let run = Task { await s.run() }
        defer { run.cancel(); SloopClient.prioritise = true }
        try await waitFor(15) { if case .connected = s.status { true } else { false } }
        let store = try #require(s.skiffSong)
        try await waitFor(5) { store.pool != nil }
        try await Task.sleep(for: .seconds(1.5))       // (the connection's own reads done)
        SloopClient.prioritise = !legacy
        let t = s.selectedTrack
        let before = fake.requests.count

        // 12 pattern changes on the selected track, one every 150 ms, while the song is polled every 100 ms
        var readers: [Task<Void, Never>] = []
        var polls: [Double] = []
        let changes = Task { @MainActor in
            for _ in 0..<12 {
                if legacy {
                    for _ in 0..<2 { readers.append(Task { _ = try? await s.readSteps(t) }) }     // (both onChanges, whole track)
                } else {
                    readers.append(Task { await s.rereadSteps(track: t) })
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        for _ in 0..<18 {
            let t0 = Date()
            await store.refresh()
            polls.append(Date().timeIntervalSince(t0) * 1000)
            try? await Task.sleep(for: .milliseconds(100))
        }
        _ = await changes.value
        // stop, and write a pad straight away
        s.setPlaying(false)
        let kept = (store.pool?.patterns.firstIndex { !$0.isFree } ?? 0) + 1
        let w0 = Date()
        _ = await store.send(.set(track: t, entry: 9, pattern: kept), readPool: false)
        let write = Date().timeIntervalSince(w0) * 1000
        for r in readers { _ = await r.value }
        let steps = fake.requests[before...].filter { $0 == SkiffCmd.trackStep }.count
        return Result(polls: polls, write: write, steps: steps)
    }

    @Test func rapidChangesBeforeAndAfter() async throws {
        let old = try await run(legacy: true)
        let new = try await run(legacy: false)
        func line(_ n: String, _ r: Result) -> String {
            let avg = r.polls.reduce(0, +) / Double(r.polls.count), late = r.polls.suffix(6).reduce(0, +) / 6
            return String(format: "BACKLOG %@: step reads %d; poll avg %.0f ms, last six %.0f ms, worst %.0f ms; write after stop %.0f ms",
                          n, r.steps, avg, late, r.polls.max() ?? 0, r.write)
        }
        print(line("before", old)); print(line("after ", new))
        #expect(new.steps < old.steps / 4)
        #expect((new.polls.max() ?? 0) < 120, "a poll waited behind the rereads")
        #expect(new.write < 120, "the write after stop waited behind the rereads")
        #expect((old.polls.max() ?? 0) > (new.polls.max() ?? 0))
    }
}

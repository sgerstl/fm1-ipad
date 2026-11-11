import Foundation
import Testing
@testable import SloopKit

/// Scott, 2026-11-11: after stopping, writing to a pad took a long time. On stop the Song tab reads the pattern pool's
/// changed chunks for the pads' pictures (PadThumb.fromPool → readSkiffPool, BACKUP_GET), the first time on a connection
/// after a BACKUP_LIST. This measures what goes over the wire for that read, and where a pad write lands in the queue.
@Suite(.serialized) @MainActor struct SkiffStopWriteTests {
    @Test func aPadWriteWaitsOnlyForTheRequestInFlight() async throws {
        let fake = try #require(FakeSkiff(demo: true))
        var once = false
        let s = DeviceSession(transport: { if once { return nil }; once = true; return fake })
        s.resyncInterval = .seconds(60)
        let run = Task { await s.run() }
        defer { run.cancel() }
        try await waitFor(10) { if case .connected = s.status { true } else { false } }
        s.setPlaying(false)
        try await waitFor(5) { !fake.playing && !s.playing }
        let store = try #require(s.skiffSong)
        try await waitFor(5) { store.pool != nil }
        let before = fake.requests.count

        // the whole pool, as the first stop on a connection reads it (every chunk changed since never read)
        let read = Task { await s.readSkiffPool(chunks: Array(0..<16)) }
        try await waitFor(5) { fake.requests[before...].contains(66) }
        // a pad written while it reads
        let t = 0, entry = 7, kept = (store.pool?.patterns.firstIndex { !$0.isFree } ?? 0) + 1
        let wrote = await store.send(.set(track: t, entry: entry, pattern: kept))
        _ = await read.value

        let sent = Array(fake.requests[before...])
        let gets = sent.filter { $0 == 66 }.count, lists = sent.filter { $0 == 65 }.count
        let firstOther = sent.firstIndex { $0 != 66 && $0 != 65 } ?? sent.count
        let getsBeforeWrite = sent[..<firstOther].filter { $0 == 66 }.count
        print("STOPWRITE pool read: \(lists) BACKUP_LIST, \(gets) BACKUP_GET; the pad write went out after \(getsBeforeWrite) GET(s); wrote \(wrote)")
        #expect(wrote)
        #expect(lists <= 1)
        // one request in flight at a time, first in first out: the write waits for the GET on the wire, not the read
        #expect(getsBeforeWrite <= 2, "the pad write waited behind \(getsBeforeWrite) pool reads")
    }
}

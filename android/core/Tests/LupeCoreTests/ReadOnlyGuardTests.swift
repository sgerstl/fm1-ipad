import Foundation
import Testing
@testable import AndroidLink
@testable import PhoneCore
@testable import SloopKit

/// The read-only guard used for unattended runs against the real FM-1. Frames come from SloopKit's own
/// requests; what counts as a read is Skiff's EDITOR_PROTOCOL.md table (ReadOnlyGuard.swift).
@Suite(.serialized) @MainActor struct ReadOnlyGuardTests {
    final class Blocked: @unchecked Sendable {
        let lock = NSLock(); var frames: [[UInt8]] = []
        func add(_ f: [UInt8]) { lock.withLock { frames.append(f) } }
        var all: [[UInt8]] { lock.withLock { frames } }
    }

    @Test func readsPassAndWritesDont() {
        let reads: [Request] = [.info, .track, .ping, .watch(7), .dump, .desc(scope: 0, id: 3), .names(engine: 2),
                                .trackStep(track: 1, index: 4), .trackParam(track: 0, id: 9), .global(id: 0),
                                .uiState, .raw(cmd: 76, args: [], match: 0, name: "TRANSPORT"),
                                .raw(cmd: 64, args: [2, 7], match: 1, name: "MOTION kinds")]
        for r in reads { #expect(ReadOnlyGuard.isRead(r.bytes), "\(r) should pass") }

        let writes: [Request] = [.selectTrack(2), .setTrackParam(track: 0, id: 9, value: 5), .setGlobal(id: 0, value: 120),
                                 .preset(engine: 0, index: 1), .userLoad(slot: 0), .uiGoto(page: 3), .transport(play: true), .rec,
                                 .smpErase(slot: 0), .bkPut(op: 0, id: 1, args: []),
                                 .raw(cmd: 76, args: [1], match: 0, name: "TRANSPORT PLAY"),
                                 .raw(cmd: 64, args: [0, 2], match: 1, name: "MOTION clear"),
                                 .raw(cmd: 73, args: [1, 0, 64], match: 0, name: "MENU_SET")]
        for w in writes { #expect(!ReadOnlyGuard.isRead(w.bytes), "\(w) should be refused") }
        #expect(!ReadOnlyGuard.isRead([0x90, 60, 100]))   // a note
        #expect(!ReadOnlyGuard.isRead([0xFA]))            // clock start
    }

    /// The question for the overnight run: does Session reach ready on Skiff 2.2 (with the screen link, as
    /// Skiff-Lupe 2.2 has) and keep running for a while when only reads get through? Lists whatever it tried
    /// to write, so a write needed for ready shows up here before it ever meets the FM-1.
    @Test(arguments: [false, true]) func sessionReachesReadyReadOnly(screenLink: Bool) async throws {
        let fake = try #require(FakeSkiff(demo: false))
        fake.screenLink = screenLink
        let blocked = Blocked()
        var once = false
        let session = DeviceSession(transport: {
            if once { return nil }; once = true
            return GuardedTransport(fake, onBlocked: { blocked.add($0) })
        })
        let run = Task { await session.run() }
        defer { run.cancel() }
        let end = Date().addingTimeInterval(10)
        while Date() < end { if case .connected = session.status { break }; try await Task.sleep(for: .milliseconds(20)) }
        #expect(session.status == .connected(version: "v2.2"), "status: \(session.status)")
        try await Task.sleep(for: .seconds(4))   // polling, re-sync, pushes: still only reads
        let kinds = Set(blocked.all.map(ReadOnlyGuard.describe))
        print("guard (screen link \(screenLink)): blocked \(blocked.all.count): \(kinds.sorted())")
        #expect(blocked.all.isEmpty, "Session tried to write: \(kinds.sorted())")
        #expect(fake.unansweredCommands.isEmpty)
        if case .connected = session.status {} else { Issue.record("lost the link: \(session.status)") }
    }

    /// PhoneCore adds its own reads (the project's name every 5 s): still nothing but reads, for 7 s.
    @Test func phoneCoreStaysReadOnly() async throws {
        let fake = try #require(FakeSkiff(demo: false))
        fake.screenLink = true
        let blocked = Blocked()
        var once = false
        let core = PhoneCore(session: DeviceSession(transport: {
            if once { return nil }; once = true
            return GuardedTransport(fake, onBlocked: { blocked.add($0) })
        }), publish: { _, _ in })
        core.start()
        defer { core.stop() }
        let end = Date().addingTimeInterval(10)
        while Date() < end, core.linkArea().phase != .ready { try await Task.sleep(for: .milliseconds(20)) }
        #expect(core.linkArea().phase == .ready)
        try await Task.sleep(for: .seconds(7))
        #expect(blocked.all.isEmpty, "PhoneCore tried to write: \(Set(blocked.all.map(ReadOnlyGuard.describe)).sorted())")
        #expect(fake.requests.contains(77))       // PROJ_NAME was read
    }
}

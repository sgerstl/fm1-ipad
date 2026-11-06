import Foundation
import Testing
@testable import SloopKit

/// Hold PLAY = Skiff's GLO + PLAY (Scott, 2026-11-06), against skiff-sim (SKIFF_SIM=1, the sim running), as
/// SkiffSongSimTests. T5 and T6 (tracks 4, 5) get two new entries each, are put on the second, and play from the
/// start must land every track with a list on its first entry, playing or stopped. Their lists are cleared after.
///   SKIFF_SIM=1 swift test --filter PlayFromStartSimTests
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SKIFF_SIM"] == "1"))
@MainActor struct PlayFromStartSimTests {
    private let tracks = [4, 5]

    private func driver() async throws -> SkiffDriver {
        guard let t = MIDITransport() else { throw ClientError.timeout("no Felucca port: is skiff-sim running?") }
        guard case .driver(let d) = try await FirmwareDetector.connect(t), let s = d as? SkiffDriver else {
            throw ClientError.timeout("not Skiff")
        }
        return s
    }

    private func clear(_ d: SkiffDriver) async throws {
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        let s = try await d.songLists()
        for t in tracks {
            for i in stride(from: 15, through: 0, by: -1) where !s.tracks[t].entries[i].isEmpty {
                _ = try await d.list(.clear(track: t, entry: i))
            }
        }
    }

    /// Each track with a list: on its first entry.
    private func expectFirstEntries(_ s: SkiffSong, _ when: String) {
        for (t, l) in s.tracks.enumerated() {
            guard let first = l.entries.firstIndex(where: { !$0.isEmpty }) else { continue }
            #expect(l.entryOn == first, "\(when): T\(t + 1) on \(l.entryOn.map(String.init) ?? "none"), its first is \(first)")
        }
    }

    private func onSecond(_ d: SkiffDriver) async throws {
        for t in tracks { _ = try await d.list(.play(track: t, entry: 1)) }
    }

    @Test func songOnLandsEveryTrackOnItsFirstEntry() async throws {
        let d = try await driver()
        #expect(d.skiff.hasSongLists)
        try await clear(d)
        for t in tracks {
            for e in 0..<2 {
                _ = try await d.list(.new(track: t, entry: e))
                _ = try await d.list(.reps(track: t, entry: e, reps: 16))     // no pass end during the test
            }
        }
        _ = try await d.list(.song(.on))

        // playing, on the second entries
        try await onSecond(d)
        _ = try await d.transport(play: true)
        try await Task.sleep(for: .milliseconds(400))
        var s = try await d.songLists()
        for t in tracks { #expect(s.tracks[t].entryOn == 1, "set up: T\(t + 1) on its second entry") }
        try await d.playFromStart()
        try await Task.sleep(for: .milliseconds(300))
        s = try await d.songLists()
        expectFirstEntries(s, "playing")
        #expect(try await d.transportState()?.playing == true, "playing after it")

        // stopped, on the second entries
        _ = try await d.transport(play: false)
        try await Task.sleep(for: .milliseconds(200))
        try await onSecond(d)
        s = try await d.songLists()
        for t in tracks { #expect(s.tracks[t].entryOn == 1, "set up stopped: T\(t + 1) on its second entry") }
        try await d.playFromStart()
        try await Task.sleep(for: .milliseconds(300))
        s = try await d.songLists()
        expectFirstEntries(s, "stopped")
        #expect(try await d.transportState()?.playing == true, "playing after it (from stopped)")

        try await clear(d)
        _ = try await d.list(.song(.off))
    }

    /// SONG off: RESTART while playing keeps it playing; from stopped it plays.
    @Test func songOffRestartsAndPlays() async throws {
        let d = try await driver()
        _ = try await d.transport(play: false)
        _ = try await d.list(.song(.off))
        try await Task.sleep(for: .milliseconds(200))
        try await d.playFromStart()
        try await Task.sleep(for: .milliseconds(300))
        #expect(try await d.transportState()?.playing == true, "from stopped: playing")
        try await d.playFromStart()
        try await Task.sleep(for: .milliseconds(300))
        #expect(try await d.transportState()?.playing == true, "RESTART: still playing")
        _ = try await d.transport(play: false)
    }
}

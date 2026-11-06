import Foundation
import Testing
@testable import SloopKit

/// The Song tab's playback marks (SongPlayback): where each track is in its entry's REPS and where it goes next.
@Suite @MainActor struct SongPlaybackTests {
    /// A track with A (×2), B (×1), a REST (×1), C (×3); the track on `on`, `staged` waiting.
    private func store(_ mode: SongMode, on: Int?, staged: Int? = nil) -> SkiffSongStore {
        var es = Array(repeating: SongEntry.empty, count: 16)
        es[0] = SongEntry(pattern: 1, reps: 2); es[1] = SongEntry(pattern: 2); es[2] = SongEntry(pattern: SongEntry.rest); es[3] = SongEntry(pattern: 3, reps: 3)
        let song = SkiffSong(mode: mode, tracks: [SongList(entryOn: on, staged: staged, patternOn: on.map { $0 + 1 }, entries: es)])
        return SkiffSongStore(song: song, pool: PatternPool(patterns: (0..<4).map { _ in .init(length: 16, uses: 1) }), timing: [(16, 2)])
    }

    @Test func songOnGoesToTheNextAndWrapsToTheFirst() {
        let s = store(.on, on: 1)
        var m = s.marks(0, launchIn: nil)
        #expect(m.playing == 1 && m.next == 2 && !m.wraps && !m.loops)    // B, then the REST (Skiff plays it)
        let last = store(.on, on: 3)
        m = last.marks(0, launchIn: nil)
        #expect(m.playing == 3 && m.next == 0 && m.wraps)                 // after the last, the first
    }

    @Test func songOnceEndsAfterTheLast() {
        let m = store(.once, on: 3).marks(0, launchIn: nil)
        #expect(m.playing == 3 && m.next == nil && m.ends)
        #expect(store(.once, on: 0).marks(0, launchIn: nil).next == 1)
    }

    @Test func songOffLoopsTheEntry() {
        let m = store(.off, on: 0).marks(0, launchIn: nil)
        #expect(m.playing == 0 && m.loops && m.next == nil)
    }

    @Test func aLaunchWaitingAndTheRepeatCount() {
        let s = store(.on, on: 3, staged: 1)          // B launched (the song's own next would be A, wrapping)
        var pass = 7
        s.passCount = { _ in pass }
        var m = s.marks(0, launchIn: 30)
        #expect(m.queued == 1 && m.launchIn == 30)
        #expect(m.pass == 1 && m.reps == 3)                               // came onto C on pass 7: its first
        pass = 9
        m = s.marks(0, launchIn: nil)
        #expect(m.pass == 3)                                              // passes 7, 8, 9: the third of three
    }

    /// SONG ON stages its own next entry: that's "next", not a launch waiting.
    @Test func theSongsOwnNextIsNotALaunch() {
        let m = store(.on, on: 0, staged: 1).marks(0, launchIn: 12)
        #expect(m.next == 1 && m.queued == nil)
        #expect(store(.off, on: 0, staged: 1).marks(0, launchIn: 12).queued == 1)
    }

    @Test func whereALaunchLands() {
        #expect(SongPlayback.ticksToLaunch(.bar, ticks: 100, passProgress: nil, passTicks: 96) == 92)
        #expect(SongPlayback.ticksToLaunch(.beat, ticks: 100, passProgress: nil, passTicks: 96) == 20)
        #expect(SongPlayback.ticksToLaunch(.now, ticks: 100, passProgress: nil, passTicks: 96) == 0)
        #expect(SongPlayback.ticksToLaunch(.loop, ticks: 100, passProgress: 0.25, passTicks: 192) == 144)
        #expect(SongPlayback.ticksToLaunch(.bar, ticks: -1, passProgress: nil, passTicks: 96) == nil)
    }
}

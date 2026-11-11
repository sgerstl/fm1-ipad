import Foundation

// FREE TAKE, level 1 (vault batch-list.md item 4, decided 2026-11-11). Skiff 2.5 captures what's played while the
// transport is stopped: SHIFT + SAVE opens its picker (ui_take.c free_open), which writes the phrase into the track
// (fr_render: every step, LENGTH, DIV and, unless another track has notes, BPM) and keeps it on OCT+ or puts it back on
// OCT−. The screen link doesn't report the picker, and the editor protocol has no undo. What Lupe does see: the FM-1's
// notes on that track while stopped (MIDI OUT), then the editor's live sync pushing the rewrite (STEP_CHANGED for the
// steps that differ, CHANGED for LENGTH, DIV and BPM). That pair, stopped, on a page that isn't a step editor, is a
// take landing: Lupe re-reads the pattern and the tempo and lands on the Timeline with its block selected.

/// A take the FM-1 put into a track, as Lupe saw it land.
public struct FreeTake: Equatable, Sendable {
    /// Bumped each time one lands, so the app can react to a second take on the same track.
    public let id: Int
    public let track: Int
    /// The entry the track is on (its block on the Timeline); nil when the song lists aren't read.
    public let entry: Int?
    /// Steps and BPM after the re-read.
    public let length: Int
    public let bpm: Int
    /// The FM-1's undo depth (SAVE held, then OCT−): 6 on 2.5.
    public let undoLevels: Int
}

/// The evidence for a take: notes heard per track while stopped, and the rewrite's pushes after them.
struct FreeTakeWatch {
    /// When the FM-1 last played a note on each track while stopped.
    private(set) var heardAt: [Int: Date] = [:]
    /// The rewrite under way: its track and when its first push came.
    private(set) var burst: (track: Int, at: Date)?
    private(set) var landed = 0

    mutating func heard(track t: Int, at now: Date = Date()) { heardAt[t] = now }

    /// A rewrite push on `track` (STEP_CHANGED, or CHANGED of LENGTH, DIV, BPM): true when it starts a burst worth
    /// checking, given the transport stopped at `stoppedAt` and nothing in the way.
    mutating func signal(track t: Int, stoppedAt: Date, now: Date = Date()) -> Bool {
        guard let h = heardAt[t], h >= stoppedAt, now.timeIntervalSince(h) < Self.heardWithin else { return false }
        if let b = burst, b.track == t, now.timeIntervalSince(b.at) < Self.window { return false }
        burst = (t, now)
        return true
    }

    mutating func land() -> Int { burst = nil; landed += 1; return landed }
    mutating func forget() { burst = nil }

    /// A take is the notes played since the stop; one opened minutes later still counts (free_n0 holds them till PLAY).
    static let heardWithin: TimeInterval = 600
    /// The rewrite comes in a few passes of the editor's sync (4 frames every 5 ms): gathered for this long.
    static let window: TimeInterval = 0.4
}

extension DeviceSession {
    /// A rewrite push on the selected track (pushLoop). Skiff 2.5 only, stopped, not on SEQ's step pages (NOTES, FEEL,
    /// AUTOMATION: edits there are the user's own) and not a step Lupe itself just wrote.
    func takeSignal(track t: Int) {
        guard skiffFirmware?.hasFreeTake == true, !playing else { return }
        if screenLinked, let s = deviceScreen, !s.home, [41, 42, 44].contains(s.page) { return }
        guard freeTakeWatch.signal(track: t, stoppedAt: stoppedAt) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(FreeTakeWatch.window))
            guard !self.playing else { self.freeTakeWatch.forget(); return }
            await self.landFreeTake(track: t)
        }
    }

    /// The take landed: LENGTH and DIV, the steps, and the tempo read again, then said (the app goes to the Timeline).
    func landFreeTake(track t: Int) async {
        guard trackIndices.contains(t) else { return }
        await rereadParam(track: t, id: ids.length)
        await rereadParam(track: t, id: ids.division)
        await rereadSteps(track: t)
        if let c = driver, let v = try? await c.global(id: ids.bpm) { applyGlobal(id: ids.bpm, value: v) }
        if let store = skiffSong { await store.refresh(pool: true) }
        let id = freeTakeWatch.land()
        freeTake = FreeTake(id: id, track: t, entry: skiffSong?.song?.tracks[safe: t]?.entryOn, length: tracks[t].length,
                            bpm: globalCell(ids.bpm).value, undoLevels: skiffFirmware?.undoLevels ?? 6)
    }

    public func dismissFreeTake() { freeTake = nil }

    // MARK: MENU › CONTROL › KEEP SENDS

    func readKeepSends(_ k: SkiffDriver) async {
        guard let v = try? await inBackground({ try await k.menuValue(id: SkiffMenu.keepSends) }) else { return }
        keepSends = v != 0
    }

    /// KEEP SENDS on or off (MENU_SET id 21). Shown at once; the FM-1's answer wins.
    public func setKeepSends(_ on: Bool) {
        guard let k = driver as? SkiffDriver, keepSends != nil else { return }
        keepSends = on
        Task {
            guard let r = try? await k.setMenu(id: SkiffMenu.keepSends, value: on ? 1 : 0) else { await readKeepSends(k); return }
            keepSends = r.value != 0
        }
    }
}

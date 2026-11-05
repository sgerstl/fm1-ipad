import Foundation
import Observation

/// Skiff's song as the app shows it: the lists and the pool, read with LIST2 and POOL, edited optimistically
/// (drawn at once, sent one request at a time, then read again) and put back with the reason when Skiff
/// refuses. Undo is Jib's own: the lists before each change. The session makes one per Skiff connection
/// that has the 2.0 song (INFO `58 01` bit 0) and keeps it, offline, when the device goes away.
@MainActor @Observable
public final class SkiffSongStore {
    public private(set) var song: SkiffSong?
    public private(set) var pool: PatternPool?
    /// Each pattern's DIV, as seen while a track played it (POOL gives LEN, not DIV); unknown ones take
    /// their track's.
    public private(set) var divisions: [Int: Int] = [:]
    /// Why the last change didn't take, and where (nil: fine).
    public private(set) var refusal: Refusal?
    /// A change is being sent.
    public private(set) var busy = false
    /// The device is gone: the last song stays to look at, editing is off.
    public private(set) var offline = false
    public private(set) var undoStack: [SkiffSong] = []
    public let sounds: Bool

    public struct Refusal: Equatable, Sendable {
        public var track: Int?
        public var entry: Int?
        public var text: String
        public var needsStop = false
    }

    @ObservationIgnored private var driver: SkiffDriver?
    @ObservationIgnored private var reads = 0
    /// The tracks' LENGTH and DIV and whether it plays: the session's.
    @ObservationIgnored let trackTiming: @MainActor (Int) -> (length: Int, division: Int)
    @ObservationIgnored let isPlaying: @MainActor () -> Bool

    init(driver: SkiffDriver, trackTiming: @escaping @MainActor (Int) -> (length: Int, division: Int),
         isPlaying: @escaping @MainActor () -> Bool) {
        self.driver = driver
        self.sounds = driver.skiff.hasEntrySounds
        self.trackTiming = trackTiming
        self.isPlaying = isPlaying
    }

    /// For previews and tests: a song with no device behind it.
    public init(song: SkiffSong, pool: PatternPool, sounds: Bool = true, timing: [(length: Int, division: Int)]) {
        self.song = song
        self.pool = pool
        self.sounds = sounds
        self.trackTiming = { t in t < timing.count ? timing[t] : (16, 2) }
        self.isPlaying = { false }
        self.offline = false
    }

    func attach(_ d: SkiffDriver) { driver = d; offline = false }
    func detach() { driver = nil; offline = true; busy = false }

    // MARK: Reading

    /// LIST2, and POOL every fourth time (and whenever `pool` is asked for).
    public func refresh(pool withPool: Bool = false) async {
        guard let d = driver, !busy else { return }
        do {
            let s = try await d.songLists()
            if !busy { song = s; learnDivisions(s) }
            reads += 1
            if withPool || pool == nil || reads % 4 == 0 { pool = try await d.pool() }
        } catch {}
    }

    /// About once a second while a view shows the song (as Skiff's own editor does).
    public func follow() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func learnDivisions(_ s: SkiffSong) {
        for (t, l) in s.tracks.enumerated() {
            if let p = l.patternOn { divisions[p] = trackTiming(t).division }
        }
    }

    // MARK: Time

    /// The blocks of a track, placed on the bar ruler (ticks; 96 a bar).
    public func blocks(_ t: Int) -> [SongBlock] {
        guard let l = song?.tracks[safe: t] else { return [] }
        let timing = trackTiming(t)
        return SongPlacement.blocks(l, length: { p in self.pool.flatMap { $0.patterns[p].length > 0 ? $0.patterns[p].length : nil } },
                                    division: { p in self.divisions[p] }, trackLength: timing.length, trackDivision: timing.division)
    }

    public var lanes: [[SongBlock]] { (0..<(song?.tracks.count ?? 0)).map(blocks) }

    /// The bars each lane ends on, and the song's length in bars.
    public var laneEnds: [Double] { lanes.map { ($0.last?.end ?? 0) / SongPlacement.ticksPerBar } }

    // MARK: Changes

    /// Whether a change to these entries can be sent now; the reason when it can't.
    public func blocked(track t: Int, to entries: [SongEntry]) -> String? {
        guard let l = song?.tracks[safe: t] else { return "No song yet" }
        if offline { return "The FM-1 is disconnected" }
        return ListRewrite.plan(track: t, from: l, to: entries, playing: isPlaying(), sounds: sounds).needsStop
    }

    /// Rewrites a track's list to `entries`: drawn at once, then sent op by op, then read back. On a refusal
    /// the lists go back as Skiff has them, with the reason.
    @discardableResult
    public func rewrite(track t: Int, to entries: [SongEntry], focus: Int? = nil) async -> Bool {
        guard let d = driver, let before = song, let l = before.tracks[safe: t] else {
            refusal = Refusal(track: t, entry: focus, text: offline ? "The FM-1 is disconnected: editing is off until it's back" : "No song yet")
            return false
        }
        let plan = ListRewrite.plan(track: t, from: l, to: entries, playing: isPlaying(), sounds: sounds)
        if let why = plan.needsStop {
            refusal = Refusal(track: t, entry: focus, text: why, needsStop: true)
            return false
        }
        if plan.ops.isEmpty { return true }
        var s = before
        s.tracks[t].entries = entries
        song = s
        refusal = nil
        busy = true
        defer { busy = false }
        for op in plan.ops {
            do {
                let r = try await d.list(op)
                if !r.rc.isDone {
                    song = r.song
                    refusal = Refusal(track: t, entry: op.entry ?? focus, text: r.rc.reason, needsStop: r.rc == .playing)
                    await settle(d)
                    return false
                }
            } catch {
                refusal = Refusal(track: t, entry: focus, text: "The FM-1 didn't answer; the song is as it says now")
                await settle(d)
                return false
            }
        }
        undoStack.append(before)
        if undoStack.count > 32 { undoStack.removeFirst() }
        await settle(d)
        return true
    }

    /// One op that the rewrite can't express (NEW, COPY, COPY+): sent, then read back.
    @discardableResult
    public func send(_ op: ListOp) async -> Bool {
        guard let d = driver, let before = song else {
            refusal = Refusal(track: op.track, entry: op.entry, text: "The FM-1 is disconnected: editing is off until it's back")
            return false
        }
        busy = true
        defer { busy = false }
        do {
            let r = try await d.list(op)
            song = r.song
            if !r.rc.isDone {
                refusal = Refusal(track: op.track, entry: op.entry, text: r.rc.reason, needsStop: r.rc == .playing)
                return false
            }
            refusal = nil
            undoStack.append(before)
            pool = try? await d.pool()
            return true
        } catch {
            refusal = Refusal(track: op.track, entry: op.entry, text: "The FM-1 didn't answer; the song is as it says now")
            await settle(d)
            return false
        }
    }

    /// Back to the lists before the last change (Jib's undo; Skiff's own covers the device's edits).
    public func undo() async {
        guard let last = undoStack.popLast(), let now = song else { return }
        for t in last.tracks.indices where t < now.tracks.count && last.tracks[t].entries != now.tracks[t].entries {
            let n = undoStack.count
            await rewrite(track: t, to: last.tracks[t].entries)
            if undoStack.count > n { undoStack.removeLast() }       // an undo isn't itself undone
        }
    }

    public func clearUnused() async -> SongRC {
        guard let d = driver else { return .failed }
        busy = true
        defer { busy = false }
        guard let r = try? await d.clearUnusedPatterns() else { return .failed }
        pool = r.pool
        return r.rc
    }

    public func dismissRefusal() { refusal = nil }

    private func settle(_ d: SkiffDriver) async {
        if let s = try? await d.songLists() { song = s; learnDivisions(s) }
        if let p = try? await d.pool() { pool = p }
    }
}

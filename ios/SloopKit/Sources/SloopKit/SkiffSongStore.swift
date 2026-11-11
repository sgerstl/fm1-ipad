import Foundation
import Observation

/// Skiff's song as the app shows it: the lists and the pool, read with LIST2 and POOL, edited optimistically
/// (drawn at once, sent one request at a time, then read again) and put back with the reason when Skiff
/// refuses. Undo is Lupe's own: the lists before each change. The session makes one per Skiff connection
/// that has the 2.0 song (INFO `58 01` bit 0) and keeps it, offline, when the device goes away.
@MainActor @Observable
public final class SkiffSongStore {
    public private(set) var song: SkiffSong? { didSet { noticeLaunches(oldValue) } }
    /// A launch staged on a track (true), or one taken back or cancelled before it landed (false): the session's
    /// counted clock starts the track's new pass where Skiff will (CountedPlayhead.relaunch).
    @ObservationIgnored public var onLaunch: @MainActor (Int, Bool) -> Void = { _, _ in }
    /// A track came onto another entry (a launch landed, the song moved on): the session takes its pattern's LEN and
    /// DIV at once, not at its next round of reads (every 15 s for a track not selected).
    @ObservationIgnored public var onArrive: @MainActor (Int) -> Void = { _ in }
    private func noticeLaunches(_ old: SkiffSong?) {
        guard isPlaying(), let s = song else { return }
        for (t, l) in s.tracks.enumerated() {
            if let o = old?.tracks[safe: t]?.entryOn, let e = l.entryOn, o != e || old?.tracks[safe: t]?.patternOn != l.patternOn { onArrive(t) }
            let was = old?.tracks[safe: t]?.staged
            if let st = l.staged, st != was || old?.tracks[safe: t]?.entryOn != l.entryOn,
               marks(t, launchIn: nil).queued != nil { onLaunch(t, true) }     // (a launch, not the song's own next)
            else if l.staged == nil, was != nil, old?.tracks[safe: t]?.entryOn == l.entryOn { onLaunch(t, false) }
        }
    }
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
    /// PERFORM (57 bit 4): the scenes, the staged mutes and LAUNCH, read with the lists (SkiffPerform.swift).
    public let performs: Bool
    public private(set) var perform: PerformState?

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
    /// The passes a track has begun since Start (the session's counted clock), to know where an entry's REPS are.
    @ObservationIgnored public var passCount: @MainActor (Int) -> Int? = { _ in nil }
    /// The pass each track came onto its entry on (Skiff doesn't say how many REPS have played): recorded as the list
    /// shows another entry (entries change at a pass end, so the pass playing then is the first), and from pass 1 at
    /// Start. Read by the marks' own timelines, not drawn from.
    @ObservationIgnored public private(set) var arrival: [Int: (entry: Int, pass: Int)] = [:]
    /// The playback marks of track t now (SongPlayback).
    public func marks(_ t: Int, launchIn: Double?) -> SongPlayback.Marks {
        guard let s = song, let l = s.tracks[safe: t] else { return SongPlayback.Marks() }
        let p = passCount(t)
        if let e = l.entryOn, let p {
            // came onto another entry, or the clock started again: from the pass playing now
            if arrival[t]?.entry != e || (arrival[t]?.pass ?? 0) > p { arrival[t] = (e, p == 1 ? 1 : p) }
        }
        return SongPlayback.marks(mode: s.mode, list: l, blocks: blocks(t), passCount: p, arrivalPass: arrival[t]?.pass, launchIn: launchIn)
    }

    init(driver: SkiffDriver, trackTiming: @escaping @MainActor (Int) -> (length: Int, division: Int),
         isPlaying: @escaping @MainActor () -> Bool) {
        self.driver = driver
        self.sounds = driver.skiff.hasEntrySounds
        self.performs = driver.skiff.hasPerform
        self.trackTiming = trackTiming
        self.isPlaying = isPlaying
    }

    /// For previews and tests: a song with no device behind it.
    public init(song: SkiffSong, pool: PatternPool, sounds: Bool = true, timing: [(length: Int, division: Int)]) {
        self.song = song
        self.pool = pool
        self.sounds = sounds
        self.performs = false
        self.trackTiming = { t in t < timing.count ? timing[t] : (16, 2) }
        self.isPlaying = { false }
        self.offline = false
    }

    /// (A reconnect may be another project or another FM-1: the scenes seen are forgotten.)
    func attach(_ d: SkiffDriver) { driver = d; offline = false; scenesSeen = [:] }
    func detach() { driver = nil; offline = true; busy = false }

    // MARK: Reading

    /// LIST2, and POOL every fourth time (and whenever `pool` is asked for).
    public func refresh(pool withPool: Bool = false) async {
        guard let d = driver, !busy else { return }
        do {
            let s = try await d.songLists()
            // set only when changed: an assignment wakes every view that reads it, once a second while stopped too
            if !busy { if song != s { song = s }; learnDivisions(s) }
            reads += 1
            if performs, let p = try? await d.perform().state, !busy, perform != p { perform = p }
            if withPool || pool == nil || reads % 4 == 0 { let p = try await d.pool(); if pool != p { pool = p } }
        } catch {}
    }

    /// Seconds to the next launch the session's clock expects (nil: none waiting).
    @ObservationIgnored public var nextLanding: @MainActor () -> Double? = { nil }
    /// About once a second while a view shows the song (as Skiff's own editor does), and just after a launch's line, so
    /// the pad it brings in lights then, not up to a second later (Scott, 2026-11-10: the hand-off)
    public func follow() async {
        var overdueUntil = Date.distantPast
        while !Task.isCancelled {
            await refresh()
            let next = nextLanding()
            // a landing expected now: if the list doesn't show it yet, ask every 0.1 s for a second (not a whole second
            // later), so a launch that lands a little after the count expects lights within 0.1 s (2026-11-11)
            if let n = next, n < 0.15 { overdueUntil = Date().addingTimeInterval(max(0, n) + 1) }
            let waiting = song?.tracks.contains { $0.staged != nil } ?? false
            let wait = Date() < overdueUntil && waiting ? 0.1 : next.map { min(1, max(0.03, $0 + 0.06)) } ?? 1
            try? await Task.sleep(for: .seconds(wait))
        }
    }
    /// When the user last changed the song (a send, a rewrite): the pool's pictures wait until it's been quiet a while.
    public private(set) var lastChange = Date.distantPast

    private func learnDivisions(_ s: SkiffSong) {
        for (t, l) in s.tracks.enumerated() {
            if let p = l.patternOn, divisions[p] != trackTiming(t).division { divisions[p] = trackTiming(t).division }
        }
    }

    // MARK: Time

    /// The blocks of a track, placed on the bar ruler (ticks; 96 a bar).
    public func blocks(_ t: Int) -> [SongBlock] {
        guard let l = song?.tracks[safe: t] else { return [] }
        return blocks(t, list: l)
    }

    /// A track's blocks for a list it may get (a drag in progress, before it's sent).
    public func blocks(_ t: Int, list l: SongList) -> [SongBlock] {
        let timing = trackTiming(t)
        return SongPlacement.blocks(l, length: { p in self.pool.flatMap { $0.patterns[p].length > 0 ? $0.patterns[p].length : nil } },
                                    division: { p in self.divisions[p] }, trackLength: timing.length, trackDivision: timing.division)
    }

    public var lanes: [[SongBlock]] { (0..<(song?.tracks.count ?? 0)).map(blocks) }

    /// The bars each lane ends on, and the song's length in bars.
    public var laneEnds: [Double] { lanes.map { ($0.last?.end ?? 0) / SongPlacement.ticksPerBar } }

    /// One pass of pattern p (0...63) on track t, in ticks.
    public func passTicks(_ p: Int, track t: Int) -> Double {
        let timing = trackTiming(t)
        let len = pool.flatMap { $0.patterns[p].length > 0 ? $0.patterns[p].length : nil } ?? timing.length
        return Double(len) * CountedPlayhead.divisionTicks[max(0, min(9, divisions[p] ?? timing.division))]
    }

    // MARK: Changes
    //
    // One change at a time: a second one while the first is still going in is refused (two rewrites
    // interleaved op by op would leave a list nobody asked for). Everything a change needs is checked
    // before the first request goes out, and a CLEAR that would erase a pattern asks first.

    /// A question before a change that can't be undone (a pattern Skiff would erase).
    public struct Confirmation: Identifiable {
        public let id = UUID()
        public var title: String
        public var message: String
        public var confirmLabel: String
        public var action: @MainActor () async -> Void
    }
    public var confirmation: Confirmation?
    /// Asks before a change that can't be taken back (the Pads view's Clear): the same dialog as a scene stored over.
    public func ask(_ title: String, _ message: String, confirm: String, action: @escaping @MainActor () async -> Void) {
        confirmation = Confirmation(title: title, message: message, confirmLabel: confirm, action: action)
    }

    /// Why a change to a track's list can't be sent now, before anything is sent (nil: it can).
    public func blocked(track t: Int, to entries: [SongEntry]) -> String? {
        guard let l = song?.tracks[safe: t] else { return "No song yet" }
        if offline { return "The FM-1 is disconnected: editing is off until it's back" }
        let plan = ListRewrite.plan(track: t, from: l, to: entries, playing: isPlaying(), sounds: sounds)
        if let why = plan.needsStop { return why }
        // a playing track on a rest or an empty entry reports no entry: a pattern put there would launch
        if isPlaying(), l.entryOn == nil, plan.ops.contains(where: {
            if case .set(_, let e, _) = $0 { return l.entries[e].isEmpty || l.entries[e].isRest } else { return false }
        }) { return "Stop to rearrange: T\(t + 1) is on a rest, and Skiff would launch what goes there" }
        // SET takes only a kept pattern (or a REST)
        for op in plan.ops {
            if case .set(_, _, let p) = op, p != SongEntry.rest, let pat = pool?.patterns[safe: p - 1], pat.isFree {
                return "Pattern \(String(format: "%02d", p)) is empty. Make one with New empty pattern instead"
            }
        }
        return nil
    }

    /// The patterns (0...63) a change would erase: named by an entry it clears, named nowhere after it, and
    /// used by nothing else (POOL counts the lists' entries and the saved projects).
    public func erased(_ changes: [Int: [SongEntry]]) -> [Int] {
        guard let song, let pool else { return [] }
        let now = song.tracks.flatMap(\.entries).compactMap(\.poolIndex)
        let after = song.tracks.indices.flatMap { changes[$0] ?? song.tracks[$0].entries }.compactMap(\.poolIndex)
        return Set(now).filter { p in
            !after.contains(p) && pool.patterns[p].uses <= now.filter { $0 == p }.count
        }.sorted()
    }

    private func numbers(_ ps: [Int]) -> String { ps.map { String(format: "%02d", $0 + 1) }.joined(separator: ", ") }

    private func busyRefusal(_ t: Int?) -> Bool {
        if busy { refusal = Refusal(track: t, entry: nil, text: "One change at a time: the last one is still going in"); return true }
        return false
    }

    /// Rewrites a track's list to `entries`: drawn at once, then sent op by op, then read back. On a refusal
    /// the lists go back as Skiff has them, with the reason.
    @discardableResult
    public func rewrite(track t: Int, to entries: [SongEntry], focus: Int? = nil, confirmed: Bool = false) async -> Bool {
        guard !busyRefusal(t) else { return false }
        lastChange = Date()
        guard driver != nil, let before = song, song?.tracks[safe: t] != nil else {
            refusal = Refusal(track: t, entry: focus, text: offline ? "The FM-1 is disconnected: editing is off until it's back" : "No song yet")
            return false
        }
        if let why = blocked(track: t, to: entries) {
            refusal = Refusal(track: t, entry: focus, text: why, needsStop: why.hasPrefix("Stop"))
            return false
        }
        let gone = erased([t: entries])
        if !gone.isEmpty && !confirmed {
            confirmation = Confirmation(
                title: "Erase pattern\(gone.count == 1 ? "" : "s") \(numbers(gone))?",
                message: "Nothing else uses \(gone.count == 1 ? "it" : "them"), so Skiff erases \(gone.count == 1 ? "it" : "them") with the entry. This can't be undone.",
                confirmLabel: "Erase \(numbers(gone))") { [weak self] in
                    await self?.rewrite(track: t, to: entries, focus: focus, confirmed: true)
                }
            return false
        }
        busy = true
        defer { busy = false }
        refusal = nil
        let ok = await perform(t, entries, focus: focus)
        if ok { record(before) }
        return ok
    }

    /// The ops, one at a time; on a refusal partway, the track's list is put back as it was, as far as
    /// Skiff takes it.
    private func perform(_ t: Int, _ entries: [SongEntry], focus: Int?) async -> Bool {
        guard let d = driver, let before = song, let l = before.tracks[safe: t] else { return false }
        let plan = ListRewrite.plan(track: t, from: l, to: entries, playing: isPlaying(), sounds: sounds)
        if plan.ops.isEmpty { return true }
        var s = before
        s.tracks[t].entries = entries
        song = s
        var sent = 0
        for op in plan.ops {
            do {
                let r = try await d.list(op)
                if !r.rc.isDone {
                    refusal = Refusal(track: t, entry: op.entry ?? focus, text: r.rc.reason, needsStop: r.rc == .playing)
                    if sent > 0, let now = r.song.tracks[safe: t] { await restore(d, t, from: now, to: l.entries) }
                    await settle(d)
                    return false
                }
                sent += 1
            } catch {
                refusal = Refusal(track: t, entry: focus, text: "The FM-1 didn't answer; the song is as it says now")
                await settle(d)
                return false
            }
        }
        await settle(d)
        return true
    }

    private func restore(_ d: SkiffDriver, _ t: Int, from now: SongList, to old: [SongEntry]) async {
        for op in ListRewrite.plan(track: t, from: now, to: old, playing: isPlaying(), sounds: sounds).ops {
            if case .clear = op { continue }            // never erase on the way back
            _ = try? await d.list(op)
        }
    }

    private func record(_ before: SkiffSong) {
        undoStack.append(before)
        if undoStack.count > 32 { undoStack.removeFirst() }
    }

    /// Pads launched whose PLAY hasn't been answered yet: track → entry. Drawn as waiting at once (Scott, 2026-11-10:
    /// several fingers at once, each queued).
    public private(set) var launching: [Int: Int] = [:]
    @ObservationIgnored private var launchOrder: [Int] = []
    @ObservationIgnored private var draining = false

    /// A pad's launch (PLAY), queued: several in a row (fingers on three pads) go one after another, as SloopClient
    /// takes one request at a time, never refused for the one before still going in. One a track: a later touch on
    /// the same track replaces one not sent yet (as tapping one pad after another in a row does).
    public func launch(track t: Int, entry e: Int) {
        launching[t] = e
        if !launchOrder.contains(t) { launchOrder.append(t) }
        guard !draining else { return }
        draining = true
        Task { await drainLaunches() }
    }

    private func drainLaunches() async {
        var sent = false
        while let t = launchOrder.first {
            // an edit going in: wait for it (up to a second), the launch after it
            var waited = 0
            while busy, waited < 50 { try? await Task.sleep(for: .milliseconds(20)); waited += 1 }
            launchOrder.removeFirst()
            guard let e = launching[t] else { continue }
            _ = await send(.play(track: t, entry: e), readPool: false)
            sent = true
            if launching[t] == e { launching[t] = nil }      // (else touched again meanwhile: queued again by launch)
        }
        draining = false
        // the pool once for the lot (a launch can file what went out as a new pattern), not once a launch
        if sent, let d = driver, let p = try? await d.pool(), pool != p { pool = p }
    }

    /// One op that the rewrite can't express (NEW, COPY, COPY+, PLAY, SONG): sent, then read back.
    @discardableResult
    public func send(_ op: ListOp, readPool: Bool = true) async -> Bool {
        guard !busyRefusal(op.track) else { return false }
        lastChange = Date()
        guard let d = driver, let before = song else {
            refusal = Refusal(track: op.track, entry: op.entry, text: "The FM-1 is disconnected: editing is off until it's back")
            return false
        }
        busy = true
        defer { busy = false }
        do {
            var r = try await d.list(op)
            if case .play = op {
                r = try await retryWhileSaving(d, r, full: { $0.rc == .patternsFull }) { try await d.list(op) }
            }
            song = r.song
            if r.rc == .patternsFull, case .play = op, (pool?.free ?? 0) > 0 {
                refusal = Refusal(track: op.track, entry: op.entry, text: Self.stillSaving)
                return false
            }
            if !r.rc.isDone {
                refusal = Refusal(track: op.track, entry: op.entry, text: r.rc.reason, needsStop: r.rc == .playing)
                return false
            }
            refusal = nil
            switch op { case .play, .song: break; default: record(before) }     // undo is for the lists
            if readPool { pool = try? await d.pool() }
            return true
        } catch {
            refusal = Refusal(track: op.track, entry: op.entry, text: "The FM-1 didn't answer; the song is as it says now")
            await settle(d)
            return false
        }
    }

    /// A section's op on every track that takes part, as one change: all of it or none (every track is
    /// checked first), one undo puts all of it back. Returns why it didn't go, by track.
    @discardableResult
    public func apply(section plans: [SectionTrack], confirmed: Bool = false) async -> [Int: String] {
        guard !busyRefusal(nil) else { return [-1: "busy"] }
        guard let before = song else { return [:] }
        var refused: [Int: String] = [:]
        var changes: [Int: [SongEntry]] = [:]
        for p in plans {
            if let why = p.refusal { refused[p.track] = why; continue }
            guard let es = p.result else { continue }
            if let why = blocked(track: p.track, to: es) { refused[p.track] = why } else { changes[p.track] = es }
        }
        if let first = refused.sorted(by: { $0.key < $1.key }).first {
            refusal = Refusal(track: first.key, entry: nil, text: "Nothing changed. T\(first.key + 1): \(first.value)",
                              needsStop: first.value.hasPrefix("Stop"))
            return refused
        }
        let gone = erased(changes)
        if !gone.isEmpty && !confirmed {
            confirmation = Confirmation(
                title: "Erase pattern\(gone.count == 1 ? "" : "s") \(numbers(gone))?",
                message: "Nothing else uses \(gone.count == 1 ? "it" : "them"), so Skiff erases \(gone.count == 1 ? "it" : "them") with the bars. This can't be undone.",
                confirmLabel: "Erase \(numbers(gone))") { [weak self] in _ = await self?.apply(section: plans, confirmed: true) }
            return [-1: "asked"]
        }
        busy = true
        defer { busy = false }
        refusal = nil
        var any = false
        for (t, es) in changes.sorted(by: { $0.key < $1.key }) {
            if await perform(t, es, focus: nil) { any = true } else { refused[t] = refusal?.text ?? "Not done"; break }
        }
        if any { record(before) }
        return refused
    }

    /// Back to the lists before the last change (Lupe's undo; Skiff's own covers the device's edits). A
    /// pattern a change erased can't come back.
    public func undo() async {
        guard !busyRefusal(nil), let last = undoStack.last, let now = song else { return }
        let tracks = last.tracks.indices.filter { $0 < now.tracks.count && last.tracks[$0].entries != now.tracks[$0].entries }
        for t in tracks {
            if let why = blocked(track: t, to: last.tracks[t].entries) {
                refusal = Refusal(track: t, entry: nil, text: "Can't undo yet. T\(t + 1): \(why)", needsStop: why.hasPrefix("Stop"))
                return
            }
        }
        busy = true
        defer { busy = false }
        undoStack.removeLast()
        for t in tracks { _ = await perform(t, last.tracks[t].entries, focus: nil) }
    }

    /// EMPTY one pattern (its steps; every entry naming it stays) or CLEAR one nothing uses (POOL ops 2, 1): stopped only.
    public func poolOp(_ op: Int, pattern p: Int) async -> SongRC {
        guard let d = driver, !busy else { return .failed }
        busy = true
        defer { busy = false }
        guard let r = try? await d.poolOp(op, pattern: p) else { return .failed }
        pool = r.pool
        if r.rc.isDone { if let s = try? await d.songLists() { song = s } }
        return r.rc
    }

    public func clearUnused() async -> SongRC {
        guard !busyRefusal(nil), let d = driver else { return .failed }
        busy = true
        defer { busy = false }
        guard let r = try? await d.clearUnusedPatterns() else { return .failed }
        pool = r.pool
        return r.rc
    }

    // MARK: PERFORM (the Pads view)

    /// A scene stored, recalled, a track's mute switched (staged while playing), all that waits cancelled, or LAUNCH
    /// set; then the lists again (a recall moves entries). Storing over a kept scene asks first: the editor's STORE
    /// overwrites without the FM-1's own dialog (bank.c scene_saved; EDITOR_PROTOCOL.md: "the editor asks").
    @discardableResult
    public func performOp(_ op: PerformOp, confirmed: Bool = false) async -> Bool {
        if case .store(let s) = op, !confirmed, perform?.kept[safe: s] == true {
            confirmation = Confirmation(title: "Replace scene \(s + 1)?",
                                        message: "Scene \(s + 1) becomes what each track plays now, and its mute. The scene it held is gone: the FM-1 keeps no copy.",
                                        confirmLabel: "Replace scene \(s + 1)") { [weak self] in await self?.performOp(op, confirmed: true) }
            return false
        }
        guard !busyRefusal(nil) else { return false }
        guard let d = driver else {
            refusal = Refusal(track: nil, entry: nil, text: "The FM-1 is disconnected: editing is off until it's back")
            return false
        }
        busy = true
        defer { busy = false }
        do {
            var r = try await d.perform(op)
            if case .recall = op {
                r = try await retryWhileSaving(d, r, full: { $0.rc == .patternsFull }) { try await d.perform(op) }
            }
            perform = r.state
            if let s = try? await d.songLists() { song = s }
            guard r.rc.isDone else {
                refusal = Refusal(track: nil, entry: nil, text: r.rc == .patternsFull && (pool?.free ?? 0) > 0 ? Self.stillSaving : r.rc.reason)
                return false
            }
            switch op {
            case .store(let s), .recall(let s): learnScene(s)
            default: break
            }
            if case .recall = op { soloed = []; mutesBeforeSolo = nil; soloStaged = [:] }      // (the scene's mutes now: the solo is over)
            if case .recall(let s) = op, isPlaying() { recallStaged = (s, Set(song?.tracks.indices ?? 0..<0)) }
            if case .cancel = op { soloStaged = [:]; recallStaged = nil }
            refusal = nil
            return true
        } catch {
            refusal = Refusal(track: nil, entry: nil, text: "The FM-1 didn't answer; the scenes are as it says now")
            if let p = try? await d.perform().state { perform = p }
            return false
        }
    }

    // MARK: Solo (Scott, 2026-11-09, board 43)

    /// The tracks soloed. Skiff's editor protocol has no solo (the FM-1 solos only from GLO's black keys), so Lupe
    /// does it with PERFORM's mutes: while any track is soloed every other one is muted (staged to the launch point
    /// while playing, as a mute is), and the mutes from before the first solo come back when the last one is let go.
    /// Until a firmware SOLO op exists, a scene stored meanwhile keeps the soloed mutes.
    public private(set) var soloed: Set<Int> = []
    /// What waits for the launch point because of a key, drawn round that key until it lands (Scott, 2026-11-10): a
    /// Solo's staged mutes (solo track → the tracks still waiting), a recalled scene's tracks. Only the ones still
    /// staged; gone when none are.
    public var soloWaiting: [Int: Set<Int>] { soloStaged.compactMapValues { let w = stillStaged($0); return w.isEmpty ? nil : w } }
    public var recallWaiting: (scene: Int, tracks: Set<Int>)? {
        guard let r = recallStaged else { return nil }
        let w = stillStaged(r.tracks)
        return w.isEmpty ? nil : (r.scene, w)
    }
    private var soloStaged: [Int: Set<Int>] = [:]
    private var recallStaged: (scene: Int, tracks: Set<Int>)?
    /// Of `ks`, the tracks with a mute or a launch waiting.
    public func stillStaged(_ ks: Set<Int>) -> Set<Int> {
        guard isPlaying() else { return [] }
        return ks.filter { k in
            (perform?.staged[safe: k] ?? .none) != .none || launching[k] != nil
                || (song?.tracks[safe: k]?.staged != nil && marks(k, launchIn: nil).queued != nil)
        }
    }
    private var mutesBeforeSolo: [Bool]?

    /// A track's mute as it will be: a staged change already counted.
    func mutedSoon(_ p: PerformState, _ t: Int) -> Bool {
        switch p.staged[safe: t] ?? .none { case .mute: true; case .unmute: false; case .none: p.muted[safe: t] ?? false }
    }

    /// Solo `t` on or off; every track's mute set to match (one MUTE each that differs).
    @discardableResult
    public func toggleSolo(_ t: Int) async -> Bool {
        guard let p = perform else { return false }
        let n = p.muted.count
        let now = (0..<n).map { mutedSoon(p, $0) }
        if soloed.isEmpty { mutesBeforeSolo = now }
        if soloed.contains(t) { soloed.remove(t) } else { soloed.insert(t) }
        let target = soloed.isEmpty ? (mutesBeforeSolo ?? now) : (0..<n).map { !soloed.contains($0) }
        if soloed.isEmpty { mutesBeforeSolo = nil }
        var ok = true, staged: Set<Int> = []
        for k in 0..<n where now[k] != target[k] {
            if await !performOp(.mute(track: k)) { ok = false } else { staged.insert(k) }
        }
        if isPlaying() { soloStaged = soloStaged.filter { !stillStaged($0.value).isEmpty }; soloStaged[t] = staged }
        return ok
    }

    /// What each scene holds, as Lupe last saw it: PERFORM says only which scenes are kept, not what's in them, and
    /// no read gives a scene's entries (EDITOR_PROTOCOL.md; a project's music holds them but the editor can't read it).
    /// Learned when a scene is stored or recalled from Lupe (the lists and mutes just after); for the Pads view's preview
    /// (Scott, 2026-11-07: hold a scene to see what it would do). Forgotten with the FM-1 (another project, another unit).
    public private(set) var scenesSeen: [Int: [SceneTrack]] = [:]
    public struct SceneTrack: Equatable, Sendable {
        /// The entry the track goes to (nil: on none).
        public var entry: Int?
        public var muted: Bool
        public init(entry: Int?, muted: Bool) { self.entry = entry; self.muted = muted }
    }

    /// Just after a STORE or RECALL: each track's entry (a launch waiting for it, playing; else the one it's on) and
    /// its mute (a staged change counted as made).
    private func learnScene(_ s: Int) {
        guard let song, let perf = perform else { return }
        scenesSeen[s] = song.tracks.indices.map { t in
            let l = song.tracks[t]
            let staged = perf.staged[safe: t] ?? .none
            let muted = staged == .mute ? true : staged == .unmute ? false : perf.muted[safe: t] ?? false
            // (staged is also the song's own next in Play song: only a launch waiting is the scene's)
            let launching = marks(t, launchIn: nil).queued != nil
            return SceneTrack(entry: (launching ? l.staged : nil) ?? l.entryOn, muted: muted)
        }
    }

    /// Skiff answers PATTERNS FULL for two things (bank.c stage_entry): the pool truly full (a track's unsaved steps
    /// need a number to keep them), or the track's last swap still being written to flash, its numbers held meanwhile.
    /// Scott hit the second with 41 free (2026-11-07), told "all 64 taken". With numbers free it's the second: wait and
    /// ask again, about 1.5 s in all, before saying anything; still refused, `stillSaving` says what it is.
    private func retryWhileSaving<R>(_ d: SkiffDriver, _ first: R, full: (R) -> Bool, ask: () async throws -> R) async throws -> R {
        var r = first
        for _ in 0..<6 {
            guard full(r) else { return r }
            pool = try? await d.pool()
            guard (pool?.free ?? 0) > 0 else { return r }
            try await Task.sleep(for: Self.savingRetry)
            r = try await ask()
        }
        return r
    }
    static let savingRetry: Duration = .milliseconds(250)
    static let stillSaving = "The FM-1 is still saving the last change. Try again in a moment"

    public func dismissRefusal() { refusal = nil }
    /// A refusal the app decides itself (before sending anything).
    public func refuse(track: Int?, entry: Int?, _ text: String, needsStop: Bool = false) {
        refusal = Refusal(track: track, entry: entry, text: text, needsStop: needsStop)
    }

    private func settle(_ d: SkiffDriver) async {
        if let s = try? await d.songLists() { song = s; learnDivisions(s) }
        if let p = try? await d.pool() { pool = p }
    }
}

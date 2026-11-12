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
    /// Skiff-Lupe's screen link v7: Lupe can undo it (UNDO, 95), so the strip offers Undo instead of naming SAVE held.
    public var undoFromHere = false
    /// Undone from the strip (it then offers Redo).
    public var undone = false
}

// FREE TAKE, levels 2 and 3 (Skiff-Lupe's screen link v7, `56 01 07`): TAKE (94) reports the FM-1's picker (open, the
// tempo guesses, BARS, the first beat, TEMPO SET or KEEP; pushed with WATCH bit 5) and sets each the way its knob would;
// it listens (PLAY), keeps (OCT+), puts back (OCT−) and starts a take on the selected track (SHIFT + SAVE). The picker
// writes the take into the track as each choice changes, so the notes themselves come by the live sync, exact. UNDO
// (95) is the panel's undo. Older builds keep level 1 (FreeTakeWatch).

/// The FM-1's FREE TAKE picker (ui_take.c `fr`), as TAKE reports it: 21 bytes.
public struct TakePicker: Equatable, Sendable {
    public enum Close: Int, Sendable { case none = 0, kept = 1, putBack = 2 }
    static let length = 21
    public static let barChoices = [1, 2, 4, 8]

    public var open: Bool
    /// How the last picker closed: so a put-back is told from a keep (level 1 couldn't).
    public var lastClose: Close
    public var track: Int
    /// The pattern the track was on when it opened (0…63): what Keep replaces. nil: none.
    public var pattern: Int?
    /// The tempo guesses, the likeliest first (double and half time among the others).
    public var guesses: [Int]
    public var guess: Int
    /// BARS as an index into barChoices (8 bars is 64 steps at 1/8).
    public var barsIndex: Int
    /// Which onset is the 1 (0…), of `firstBeats` offered.
    public var firstBeat: Int
    public var firstBeats: Int
    /// TEMPO SET: the song takes the guess's BPM; KEEP: as it was (`tempoBefore`).
    public var setsTempo: Bool
    public var tempoBefore: Int
    /// On an external clock the tempo can't be set (TEMPO stays KEEP).
    public var externalClock: Bool

    public init(open: Bool = true, lastClose: Close = .none, track: Int = 0, pattern: Int? = nil, guesses: [Int] = [120],
                guess: Int = 0, barsIndex: Int = 1, firstBeat: Int = 0, firstBeats: Int = 1, setsTempo: Bool = true,
                tempoBefore: Int = 120, externalClock: Bool = false) {
        self.open = open; self.lastClose = lastClose; self.track = track; self.pattern = pattern; self.guesses = guesses
        self.guess = guess; self.barsIndex = barsIndex; self.firstBeat = firstBeat; self.firstBeats = firstBeats
        self.setsTempo = setsTempo; self.tempoBefore = tempoBefore; self.externalClock = externalClock
    }

    public init(_ body: [UInt8]) throws {
        guard body.count >= Self.length else { throw DecodeError.short(cmd: Cmd.take) }
        let b = body.map(Int.init)
        open = b[0] != 0
        lastClose = Close(rawValue: b[1]) ?? .none
        track = b[2]
        pattern = b[3] < 64 ? b[3] : nil
        let n = max(0, min(4, b[4]))
        guesses = (0..<n).map { b[6 + 2 * $0] | b[7 + 2 * $0] << 7 }
        guess = b[5]
        barsIndex = min(3, b[14])
        firstBeat = b[15]; firstBeats = b[16]
        setsTempo = b[17] != 0
        tempoBefore = b[18] | b[19] << 7
        externalClock = b[20] != 0
    }

    public var bars: Int { Self.barChoices[barsIndex] }
    /// The BPM of the guess in use.
    public var bpm: Int { guesses.indices.contains(guess) ? guesses[guess] : tempoBefore }
    /// The song's tempo while it's open (SET: the guess's).
    public var songTempo: Int { setsTempo ? bpm : tempoBefore }
    /// How guess i relates to the likeliest: "half", "double", or nil.
    public func relation(_ i: Int) -> String? {
        guard i > 0, guesses.indices.contains(i), let g0 = guesses.first, g0 > 0 else { return nil }
        let g = guesses[i]
        if abs(2 * g - g0) <= 2 { return "half" }
        if abs(g - 2 * g0) <= 4 { return "double" }
        return nil
    }
}

/// TAKE's ops (editor.c, `56 01 07`): each as the picker's knob or key would do it.
public enum TakeOp: Equatable, Sendable {
    case guess(Int), bars(Int), firstBeat(Int), setTempo(Bool), listen, keep, putBack
    /// SHIFT + SAVE on the selected track: a free take when stopped and something was played.
    case start
    var bytes: [UInt8] {
        switch self {
        case .guess(let i): [1, UInt8(max(0, min(127, i)))]
        case .bars(let i): [2, UInt8(max(0, min(127, i)))]
        case .firstBeat(let i): [3, UInt8(max(0, min(127, i)))]
        case .setTempo(let on): [4, on ? 1 : 0]
        case .listen: [5, 0]
        case .keep: [6, 0]
        case .putBack: [7, 0]
        case .start: [8, 0]
        }
    }
}

/// A phrase Lupe heard on the selected track with the transport stopped, offered as a take once it ends (Skiff's own
/// 2.5 s pause). Level 3 offers Keep that (TAKE op 8); before it the strip names SHIFT + SAVE.
public struct TakeOffer: Equatable, Sendable {
    public let id: Int
    public let track: Int
    public let notes: Int
    /// Keep that works from here (screen link v7).
    public let canStart: Bool
    /// Keep that was refused, or the FM-1 found nothing to take (it says why on its screen).
    public var refused = false
}

/// The evidence for a take: notes heard per track while stopped, and the rewrite's pushes after them.
struct FreeTakeWatch {
    /// When the FM-1 last played a note on each track while stopped.
    private(set) var heardAt: [Int: Date] = [:]
    /// The phrase being heard: its track, its onsets, and the last note's time (a note within 30 ms of the same one
    /// is the same onset: Lupe's own key and the FM-1's echo of it).
    private(set) var phrase: (track: Int, notes: Int, last: Date, note: Int)?
    private(set) var offers = 0
    /// The rewrite under way: its track and when its first push came.
    private(set) var burst: (track: Int, at: Date)?
    private(set) var landed = 0

    mutating func heard(track t: Int, note: Int = -1, at now: Date = Date()) {
        heardAt[t] = now
        if let p = phrase, p.track == t, now.timeIntervalSince(p.last) <= Self.pause {
            let same = p.note == note && now.timeIntervalSince(p.last) < 0.03
            phrase = (t, p.notes + (same ? 0 : 1), now, note)
        } else {
            phrase = (t, 1, now, note)
        }
    }
    /// The phrase ended (nothing for `pause`): its track and onsets, once.
    mutating func phraseEnded(now: Date = Date()) -> (track: Int, notes: Int, id: Int)? {
        guard let p = phrase, now.timeIntervalSince(p.last) >= Self.pause else { return nil }
        offers += 1
        return (p.track, p.notes, offers)
    }
    mutating func forgetPhrase() { phrase = nil }
    /// Skiff's: a phrase starts after 2.5 s of silence (ui_take.c FR_GAP), so the offer waits for it.
    static let pause: TimeInterval = 2.5
    /// How long the offer stays.
    static let offerFor: TimeInterval = 30

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
        guard skiffFirmware?.hasFreeTake == true, !playing, !takeLinked else { return }   // (v7 reports it: TAKE)
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
        freeTake?.undoFromHere = takeLinked
    }

    public func dismissFreeTake() { freeTake = nil }

    // MARK: Levels 2 and 3 (screen link v7)

    /// Skiff-Lupe's screen link v7 is talking: the picker is reported and driven from here.
    var takeDriver: SkiffDriver? { takeLinked ? driver as? SkiffDriver : nil }

    /// A note on track `t` with the transport stopped (the FM-1's notes out, or Lupe's own keys): the phrase grows,
    /// and once it ends (2.5 s) it's offered, on the selected track only (SHIFT + SAVE takes that one's).
    func takeNoteHeard(track t: Int, note: Int) {
        guard skiffFirmware?.hasFreeTake == true, !playing, takePicker == nil else { return }
        freeTakeWatch.heard(track: t, note: note)
        if takeOffer != nil { takeOffer = nil }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(FreeTakeWatch.pause + 0.05))
            guard !self.playing, self.takePicker == nil, let p = self.freeTakeWatch.phraseEnded(),
                  p.track == self.selectedTrack else { return }
            if self.takeOffer?.id == p.id { return }
            self.takeOffer = TakeOffer(id: p.id, track: p.track, notes: p.notes, canStart: self.takeLinked)
            try? await Task.sleep(for: .seconds(FreeTakeWatch.offerFor))
            if self.takeOffer?.id == p.id { self.takeOffer = nil }
        }
    }

    public func dismissTakeOffer() { takeOffer = nil; freeTakeWatch.forgetPhrase() }

    /// The picker as the FM-1 reports it (a TAKE reply or push). Opened: shown, the offer and the last landing gone.
    /// Closed after a keep: the take lands as level 1's does (re-read, the Timeline, the strip). After a put-back:
    /// the track and the tempo are read again, and nothing lands.
    func takeReported(_ p: TakePicker) {
        if p.open {
            if takePicker != p { takePicker = p }
            takeOffer = nil
            freeTake = nil
            freeTakeWatch.forgetPhrase()
            return
        }
        guard let was = takePicker else { return }
        takePicker = nil
        let t = was.track
        Task { @MainActor in
            if p.lastClose == .kept {
                await self.landFreeTake(track: t)
            } else {
                await self.rereadParam(track: t, id: self.ids.length)
                await self.rereadParam(track: t, id: self.ids.division)
                await self.rereadSteps(track: t)
                if let c = self.driver, let v = try? await c.global(id: self.ids.bpm) { self.applyGlobal(id: self.ids.bpm, value: v) }
            }
        }
    }

    /// Reads the picker once (connecting, or a SCREEN flags bit 3 seen without its state).
    func readTakePicker() async {
        guard let k = takeDriver, let r = try? await k.take() else { return }
        takeReported(r.picker)
    }

    /// One of the picker's choices or keys, from here. Shown at once; the FM-1's answer wins.
    public func takeOp(_ op: TakeOp) {
        guard let k = takeDriver else { return }
        if var p = takePicker {
            switch op {
            case .guess(let i): p.guess = max(0, min(p.guesses.count - 1, i))
            case .bars(let i): p.barsIndex = max(0, min(3, i))
            case .firstBeat(let i): p.firstBeat = max(0, min(p.firstBeats - 1, i))
            case .setTempo(let on): p.setsTempo = on && !p.externalClock
            default: break
            }
            if p != takePicker { takePicker = p }
        }
        if op == .start { takeOffer?.refused = false }
        Task { @MainActor in
            guard let r = try? await k.take(op) else { await self.readTakePicker(); return }
            self.takeReported(r.picker)
            if op == .start, !r.picker.open { self.takeOffer?.refused = true }
        }
    }

    /// Keep that (level 3): the take started from the iPad, as SHIFT + SAVE on the selected track.
    public func startTake() { takeOp(.start) }

    /// The landing strip's Undo (or Redo): the FM-1's own undo, then the track and tempo read again.
    public func undoFreeTake() {
        guard let k = takeDriver, let f = freeTake else { return }
        let redo = f.undone
        Task { @MainActor in
            guard let r = try? await k.undo(redo: redo), r.rc == 0 else { return }
            if self.freeTake?.id == f.id { self.freeTake?.undone = !redo }
            await self.rereadParam(track: f.track, id: self.ids.length)
            await self.rereadParam(track: f.track, id: self.ids.division)
            await self.rereadSteps(track: f.track)
            if let c = self.driver, let v = try? await c.global(id: self.ids.bpm) { self.applyGlobal(id: self.ids.bpm, value: v) }
        }
    }

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

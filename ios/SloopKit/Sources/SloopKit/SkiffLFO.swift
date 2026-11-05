import Foundation

/// Skiff's LFO as its LFO page draws it (firmware ui_graph.c lfo_view_at, voice.c lfo_wave / lfo_sync_inc,
/// tools/gen_tables.py): RATE's curve, SYNC's note values, the five waves, PHASE, FADE, BI / UNI, S&H's value a
/// cycle from the graph's own hash. Pure, so the page and the tests agree.
public struct SkiffLFO: Equatable, Sendable {
    public var rate = 60, wave = 0, phase = 0, fade = 0
    /// LFO 2: SYNC 0 = OFF (RATE), 1… = 4BAR 2BAR 1/1 1/2 1/4 1/8 8T 1/16 16T 1/32; TRIG 0 = NOTE, 1 = FREE; POLARITY 0 = BI, 1 = UNI.
    public var sync = 0, trig = 0, polarity = 0

    public init(rate: Int = 60, wave: Int = 0, phase: Int = 0, fade: Int = 0, sync: Int = 0, trig: Int = 0, polarity: Int = 0) {
        self.rate = rate; self.wave = wave; self.phase = phase; self.fade = fade
        self.sync = sync; self.trig = trig; self.polarity = polarity
    }

    /// The window the page shows: 2 s from the restart, then the last 2 s (LFO_WIN).
    public static let window = 2.0

    /// RATE 0…127: 0.05 Hz × 800^(v/127), 0.05 … 40 Hz (gen_tables.py LFO_HZ).
    public static func hz(_ v: Int) -> Double { 0.05 * pow(800, Double(min(max(v, 0), 127)) / 127) }

    /// SYNC's cycle in quarter notes (voice.c LSYNC_DIV → DIV_48 / 48); nil for OFF.
    public static func syncQuarters(_ s: Int) -> Double? {
        let q: [Double] = [16, 8, 4, 2, 1, 0.5, 1.0 / 3, 0.25, 1.0 / 6, 0.125]
        return s >= 1 && s <= q.count ? q[s - 1] : nil
    }

    /// FADE 1…127: 1 ms × 10000^(v/127) (TIME_MS_X10), in seconds; 0: none.
    public static func fadeSeconds(_ v: Int) -> Double { v <= 0 ? 0 : pow(10000, Double(v & 127) / 127) / 1000 }

    /// Cycles a second at a tempo (SYNC), or RATE's.
    public func cyclesPerSecond(bpm: Double) -> Double {
        if let q = Self.syncQuarters(sync) { return bpm / 60 / q }
        return Self.hz(rate)
    }

    /// PHASE as a part of a cycle (PHASE << 25 of 2^32).
    public var startPhase: Double { Double(phase & 127) / 128 }

    /// −1…1 (UNI: 0…1) at `cycles` (counted from where the phase is 0, so S&H's cycle number is whole cycles),
    /// `since` seconds after the restart (FADE's share).
    public func value(cycles: Double, since: Double) -> Double {
        var v = Self.wave(wave, cycles)
        if polarity != 0 { v = (v + 1) / 2 }
        let ft = Self.fadeSeconds(fade)
        return ft > 0 && since < ft ? v * max(0, since) / ft : v
    }

    /// One wave at `cycles` (lfo_wave; dsp.c osc_tri; S&H: ui_graph.c's hash of the cycle number).
    public static func wave(_ w: Int, _ cycles: Double) -> Double {
        let ph = cycles - cycles.rounded(.down)
        switch w {
        case 1: return ph < 0.5 ? ph * 4 - 1 : 3 - ph * 4
        case 2: return ph * 2 - 1
        case 3: return ph < 0.5 ? 1 : -1
        case 4:
            let n = UInt32(truncatingIfNeeded: Int64(cycles.rounded(.down)))
            return Double(Int((n &* 2_654_435_761) >> 16) - 32768) / 32768
        default: return sin(ph * 2 * .pi)
        }
    }

    /// The page's view: `count` values across the window and where "now" is in it (0…1), given the cycles now
    /// and the seconds since the restart (as lfo_view_at: the window starts at the restart, then scrolls).
    public func view(cyclesNow: Double, since: Double, bpm: Double, count: Int) -> (values: [Double], now: Double) {
        let k = max(0, since), t0 = max(0, k - Self.window), rate = cyclesPerSecond(bpm: bpm)
        let values = (0..<max(count, 2)).map { i -> Double in
            let t = t0 + Self.window * Double(i) / Double(max(count, 2) - 1)
            return value(cycles: cyclesNow - rate * (k - t), since: t)
        }
        return (values, min(1, (k - t0) / Self.window))
    }
}

/// When the selected track's LFO restarted and where the clock is, as Jib can know it: the track's notes from
/// Skiff's NOTES OUT (a note while none is held is a fresh phrase, voice.c lfo_restart) and MIDI clock since Start.
public struct LFOClock: Equatable, Sendable {
    public private(set) var startedAt: Date?            // Start seen (nil: stopped, or no Start seen)
    public private(set) var ticks = 0                   // pulses since Start
    public private(set) var lastTickAt: Date?
    public private(set) var tickSeconds: Double?        // a pulse's length, smoothed (24 a quarter)
    var held: [Int: Set<Int>] = [:]
    public private(set) var restarts: [Int: (at: Date, quarters: Double?)] = [:]

    public init() {}

    public static func == (a: LFOClock, b: LFOClock) -> Bool {
        a.startedAt == b.startedAt && a.ticks == b.ticks && a.lastTickAt == b.lastTickAt && a.held == b.held
            && a.restarts.keys.sorted() == b.restarts.keys.sorted()
    }

    public mutating func start(at d: Date) { startedAt = d; ticks = 0; lastTickAt = nil }
    public mutating func stop() { startedAt = nil; lastTickAt = nil; held = [:] }
    public mutating func tick(at d: Date) {
        if let l = lastTickAt {
            let dt = d.timeIntervalSince(l)
            // a pulse between 1 and 60 ms (25…2500 BPM); a gap (a stall) doesn't move the estimate
            if dt > 0.001, dt < 0.06 { tickSeconds = tickSeconds.map { $0 + (dt - $0) * 0.1 } ?? dt }
        }
        if startedAt != nil, lastTickAt != nil { ticks += 1 }
        lastTickAt = d
    }

    /// Quarters since Start at `d`, between pulses too; nil when not running.
    public func quarters(at d: Date) -> Double? {
        guard startedAt != nil, let l = lastTickAt else { return nil }
        let part = tickSeconds.map { min(1, max(0, d.timeIntervalSince(l) / $0)) } ?? 0
        return (Double(ticks) + part) / 24
    }

    /// The tempo the clock runs at, from its pulses.
    public var bpm: Double? { tickSeconds.map { 60 / ($0 * 24) } }

    public mutating func note(track: Int, note: Int, on: Bool, at d: Date) {
        var h = held[track] ?? []
        if on {
            if h.isEmpty { restarts[track] = (d, quarters(at: d)) }
            h.insert(note)
        } else {
            h.remove(note)
        }
        held[track] = h
    }

    /// The selected track's LFO now: its cycles and the seconds since its restart. `opened`: when the page
    /// opened, standing in for a restart Jib didn't see. `exact`: the phase is the device's, not a guess.
    public func lfoNow(_ lfo: SkiffLFO, track: Int, bpm fallbackBPM: Double, opened: Date, at now: Date)
        -> (cycles: Double, since: Double, bpm: Double, exact: Bool) {
        let bpm = bpm ?? fallbackBPM
        let restart = restarts[track]
        let r = restart?.at ?? opened
        let since = now.timeIntervalSince(r)
        let p0 = lfo.startPhase
        if let q = SkiffLFO.syncQuarters(lfo.sync) {
            if lfo.trig != 0, let qn = quarters(at: now) {
                return (p0 + qn / q, since, bpm, true)               // FREE + SYNC: with the bars from PLAY
            }
            if lfo.trig == 0, let qr = restart?.quarters, let qn = quarters(at: now) {
                return (p0 + (qn - qr) / q, since, bpm, true)        // NOTE + SYNC: from PHASE, at the clock's pace
            }
            return (p0 + since * bpm / 60 / q, since, bpm, false)
        }
        // RATE: NOTE from PHASE at the restart (exact while notes are seen); FREE: its phase can't be known
        return (p0 + since * SkiffLFO.hz(lfo.rate), since, bpm, lfo.trig == 0 && restart != nil)
    }
}

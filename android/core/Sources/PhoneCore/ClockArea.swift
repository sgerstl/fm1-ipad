// The clock the screens interpolate from (Scott's play test, 2026-11-14: "the bar counts don't really work"; the pads'
// bars jumped with each publish). MIDI clock from the FM-1 is 24 pulses a beat; the areas are published far less often.
// So the `clock` area gives a reference the UI runs forward each frame, and the pads give ticks, not fractions:
//     ticksNow = clock.ticks + (uptimeMillis − clock.atMs) × clock.ticksPerSecond / 1000
// A pad's pass bar is ((ticksNow − row.passStartTick) / row.passTicks) mod 1; a waiting pad, Mute key or scene has
// launchTick − ticksNow ticks to go (the iPad's LaunchTrace draws its outline from that). `atMs` is CLOCK_MONOTONIC in
// milliseconds: Android's SystemClock.uptimeMillis.
import Foundation
import SloopKit

public struct ClockArea: Codable, Equatable, Sendable {
    /// MIDI clock is counted (playing, and Start was seen). false: no clock, nothing to interpolate; the launch
    /// outlines are drawn dashed, as the iPad's.
    public var running: Bool
    /// Pulses since Start at `atMs` (24 a beat, 96 a bar in 4/4).
    public var ticks: Int
    public var atMs: Int
    /// From the tempo (BPM × 24 / 60). A new reference comes every beat, so a drift never grows past one.
    public var ticksPerSecond: Double
}

extension PhoneCore {
    public func clockArea() -> ClockArea {
        let s = session
        guard s.isConnected, s.playing, let ref = clockRef, s.clockTicks >= 0 else {
            return ClockArea(running: false, ticks: 0, atMs: 0, ticksPerSecond: 0)
        }
        return ClockArea(running: true, ticks: ref.ticks, atMs: Int(ref.atMs), ticksPerSecond: Double(s.bpm) * 24 / 60)
    }

    /// Stamps the pulse count as it changes (the session counts pulses but keeps no time for them): every 4 ms while
    /// the clock runs, a new reference on each beat, on Start, and when the count jumps (a restart).
    func runClockStamp() async {
        var seen = -2
        while !Task.isCancelled {
            let k = session.isConnected && session.playing ? session.clockTicks : -1
            if k != seen {
                let was = seen
                seen = k
                if k < 0 {
                    if clockRef != nil { clockRef = nil; pokeAreas(["clock", "pads", "top"]) }
                } else if clockRef == nil || k % 24 == 0 || k < was || k - was > 12 {
                    clockRef = (k, LagClock.now())
                    pokeAreas(["clock"])
                }
            }
            try? await Task.sleep(for: .milliseconds(k < 0 ? 50 : 4))
        }
    }

    /// The absolute pulse a launch on track t lands on (the count now plus Session.ticksToLaunch), nil with no clock.
    func launchTick(_ t: Int) -> Double? {
        let s = session
        guard s.playing, s.clockTicks >= 0, let left = s.ticksToLaunch(t) else { return nil }
        return (Double(s.clockTicks) + left).rounded()
    }

    /// A track's pass in pulses (its division × its length), and the pulse its current pass began on.
    func passClock(_ t: Int) -> (ticks: Double, start: Double)? {
        let s = session
        guard s.playing, s.clockTicks >= 0, let prog = s.passProgress(t) else { return nil }
        let tr = s.tracks[t]
        let pass = CountedPlayhead.divisionTicks[max(0, min(9, tr.division))] * Double(max(1, tr.length))
        return (pass, ((Double(s.clockTicks) - prog * pass) * 2).rounded() / 2)
    }

    /// The readout's bar and beat (4/4), and the bars it counts within. Skiff's own screen shows no bar or beat
    /// while it plays (only its count-in does), so there is nothing to match; this is Lupe's:
    /// - Loop (SONG OFF): within the selected track's block, all its passes (a 1-bar pattern played 4 times: 1…4).
    /// - Song: within the song (the longest track's list), wrapping as the song comes round.
    /// - Once: within the song, not wrapping.
    func readout() -> (bar: Int, beat: Int, bars: Int?) {
        let s = session
        guard s.playing, s.clockTicks >= 0 else { return (1, 1, nil) }
        let k = s.clockTicks
        let plain = (k / 96 + 1, k / 24 % 4 + 1)
        let store = s.skiffSong
        switch store?.song?.mode ?? .off {
        case .off:
            let t = s.selectedTrack
            guard let pc = passClock(t), pc.ticks > 0 else { return (plain.0, plain.1, nil) }
            let marks = store?.marks(t, launchIn: nil) ?? SongPlayback.Marks()
            let reps = max(1, marks.reps), pass = max(1, min(reps, marks.pass ?? 1))
            let pos = Double(pass - 1) * pc.ticks + max(0, Double(k) - pc.start)
            let bars = max(1, Int((pc.ticks * Double(reps) / 96).rounded(.up)))
            return (min(bars, Int(pos / 96) + 1), Int(pos / 24) % 4 + 1, bars)
        case .on, .once:
            let end = s.trackIndices.compactMap { store?.blocks($0).last?.end }.max() ?? 0
            let bars = Int((end / 96).rounded(.up))
            guard bars > 0 else { return (plain.0, plain.1, nil) }
            let wraps = store?.song?.mode == .on
            let p = wraps ? k % (bars * 96) : k
            return (wraps ? p / 96 + 1 : min(bars, p / 96 + 1), p / 24 % 4 + 1, bars)
        }
    }
}

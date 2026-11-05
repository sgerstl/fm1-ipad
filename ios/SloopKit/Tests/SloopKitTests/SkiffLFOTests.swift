import Foundation
import Testing
@testable import SloopKit

/// The LFO page's model against Skiff's own tables and rules (ui_graph.c lfo_view_at, voice.c, gen_tables.py).
@Suite struct SkiffLFOTests {
    @Test func rateCurveMatchesSkiffsTable() {
        // LFO_HZ_X100: 5 at 0, 4000 at 127; RATE's default 60 shows 1.18 Hz on the FM-1
        #expect(abs(SkiffLFO.hz(0) - 0.05) < 1e-9)
        #expect(abs(SkiffLFO.hz(127) - 40) < 1e-9)
        #expect(Int((SkiffLFO.hz(60) * 100).rounded()) == 118)
    }

    @Test func syncNoteValues() {
        #expect(SkiffLFO.syncQuarters(0) == nil)        // OFF
        #expect(SkiffLFO.syncQuarters(1) == 16)         // 4BAR
        #expect(SkiffLFO.syncQuarters(5) == 1)          // 1/4
        #expect(SkiffLFO.syncQuarters(7) == 1.0 / 3)    // 8T
        #expect(SkiffLFO.syncQuarters(10) == 0.125)     // 1/32
        // 1/4 at 120 BPM: two cycles a second, whatever RATE says
        #expect(SkiffLFO(rate: 0, sync: 5).cyclesPerSecond(bpm: 120) == 2)
    }

    @Test func wavesAndPolarity() {
        #expect(abs(SkiffLFO.wave(0, 0.25) - 1) < 1e-9)       // SIN peaks a quarter in
        #expect(SkiffLFO.wave(1, 0) == -1)                    // TRI rises from the bottom
        #expect(SkiffLFO.wave(1, 0.5) == 1)
        #expect(SkiffLFO.wave(2, 0.75) == 0.5)                // SAW rises
        #expect(SkiffLFO.wave(3, 0.2) == 1 && SkiffLFO.wave(3, 0.7) == -1)
        // S&H: one value a cycle, the same all through it
        #expect(SkiffLFO.wave(4, 3.1) == SkiffLFO.wave(4, 3.9))
        #expect(SkiffLFO.wave(4, 3.5) != SkiffLFO.wave(4, 4.5))
        // UNI: 0…1
        let uni = SkiffLFO(wave: 3, polarity: 1)
        #expect(uni.value(cycles: 0.7, since: 1) == 0)
        #expect(uni.value(cycles: 0.2, since: 1) == 1)
    }

    @Test func fadeGrowsFromNothing() {
        let l = SkiffLFO(wave: 3, fade: 127)                  // 10 s
        #expect(abs(SkiffLFO.fadeSeconds(127) - 10) < 1e-9)
        #expect(l.value(cycles: 0.1, since: 0) == 0)
        #expect(abs(l.value(cycles: 0.1, since: 5) - 0.5) < 1e-9)
        #expect(l.value(cycles: 0.1, since: 11) == 1)
    }

    @Test func windowStartsAtTheRestartThenScrolls() {
        let l = SkiffLFO(rate: 60)
        let early = l.view(cyclesNow: 1, since: 0.5, bpm: 120, count: 217)
        #expect(abs(early.now - 0.25) < 1e-9)                 // half a second into the 2 s
        let late = l.view(cyclesNow: 9, since: 7, bpm: 120, count: 217)
        #expect(late.now == 1)                                // past 2 s: now is the window's right edge
        #expect(abs(late.values.last! - l.value(cycles: 9, since: 7)) < 1e-9)
    }

    @Test func freeSyncFollowsTheClockFromStart() {
        var c = LFOClock()
        let t0 = Date(timeIntervalSinceReferenceDate: 1000)
        c.start(at: t0)
        // 48 pulses at 120 BPM (a pulse every 1/48 s): two quarters
        for i in 0...48 { c.tick(at: t0.addingTimeInterval(Double(i) / 48)) }
        #expect(abs((c.bpm ?? 0) - 120) < 0.01)
        let lfo = SkiffLFO(phase: 32, sync: 5, trig: 1)       // 1/4, FREE, PHASE a quarter cycle in
        let now = c.lfoNow(lfo, track: 0, bpm: 100, opened: t0, at: t0.addingTimeInterval(1))
        #expect(now.exact)
        #expect(abs(now.cycles - (0.25 + 2)) < 0.01)
    }

    @Test func aFreshPhraseRestartsANoteLFO() {
        var c = LFOClock()
        let t0 = Date(timeIntervalSinceReferenceDate: 2000)
        c.note(track: 2, note: 60, on: true, at: t0)
        c.note(track: 2, note: 64, on: true, at: t0.addingTimeInterval(0.3))   // held over: no restart
        let lfo = SkiffLFO(rate: 60)
        let n = c.lfoNow(lfo, track: 2, bpm: 120, opened: t0.addingTimeInterval(-5), at: t0.addingTimeInterval(1))
        #expect(n.exact)
        #expect(abs(n.since - 1) < 1e-9)
        #expect(abs(n.cycles - SkiffLFO.hz(60)) < 1e-9)
        c.note(track: 2, note: 60, on: false, at: t0.addingTimeInterval(1.5))
        c.note(track: 2, note: 64, on: false, at: t0.addingTimeInterval(1.6))
        c.note(track: 2, note: 62, on: true, at: t0.addingTimeInterval(2))      // nothing held: a restart
        #expect(abs(c.lfoNow(lfo, track: 2, bpm: 120, opened: t0, at: t0.addingTimeInterval(2.5)).since - 0.5) < 1e-9)
        // a FREE LFO off the clock: its phase isn't known
        #expect(!c.lfoNow(SkiffLFO(trig: 1), track: 2, bpm: 120, opened: t0, at: t0.addingTimeInterval(3)).exact)
    }
}

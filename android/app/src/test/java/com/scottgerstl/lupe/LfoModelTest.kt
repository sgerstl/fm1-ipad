package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.ClockState
import com.scottgerstl.lupe.ui.page.SkiffLfo
import com.scottgerstl.lupe.ui.page.lfoNow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LfoModelTest {
    @Test fun rateRunsFrom005To40Hz() {
        assertEquals(0.05, SkiffLfo.hz(0), 1e-9)
        assertEquals(40.0, SkiffLfo.hz(127), 1e-9)
    }

    @Test fun syncSetsTheRateFromTheTempo() {
        // 1/4 at 120 BPM: two cycles a second; 4BAR: one cycle in 8 s
        assertEquals(2.0, SkiffLfo(sync = 5).cyclesPerSecond(120.0), 1e-9)
        assertEquals(1.0 / 8, SkiffLfo(sync = 1).cyclesPerSecond(120.0), 1e-9)
        assertEquals("1/4 at 120 BPM", SkiffLfo(sync = 5).caption(120.0))
        assertEquals("0.05 Hz", SkiffLfo(rate = 0).caption(120.0))
    }

    @Test fun fadeRampsInFromTheRestart() {
        val l = SkiffLfo(wave = 3, fade = 127)          // square, 10 s fade
        assertEquals(10.0, SkiffLfo.fadeSeconds(127), 1e-9)
        assertEquals(0.0, l.value(0.25, 0.0), 1e-9)
        assertEquals(0.5, l.value(0.25, 5.0), 1e-9)
        assertEquals(1.0, l.value(0.25, 12.0), 1e-9)
    }

    @Test fun uniStaysAboveZero() {
        val l = SkiffLfo(wave = 3, polarity = 1)
        assertEquals(1.0, l.value(0.25, 9.0), 1e-9)
        assertEquals(0.0, l.value(0.75, 9.0), 1e-9)
    }

    @Test fun theWindowStartsAtTheRestartThenScrolls() {
        val l = SkiffLfo()
        assertEquals(0.5, l.view(0.0, 1.0, 120.0, 217).second, 1e-9)
        assertEquals(1.0, l.view(0.0, 7.0, 120.0, 217).second, 1e-9)
        assertEquals(217, l.view(0.0, 7.0, 120.0, 217).first.size)
    }

    @Test fun aSyncedLfoKeepsTheClocksPace() {
        // 120 BPM: 48 pulses a second; 96 pulses in (a bar) with a 1/1 LFO is exactly one cycle
        val clock = ClockState(running = true, ticks = 96.0, atMs = 5000, ticksPerSecond = 48.0)
        val n = lfoNow(SkiffLfo(sync = 3), clock, tempo = 90.0, openedMs = 0, nowMs = 5000)
        assertEquals(1.0, n.cycles, 1e-9)
        assertEquals(2.0, n.since, 1e-9)
        assertEquals(120.0, n.bpm, 1e-9)
    }

    @Test fun withNoClockItRunsFromWhenThePictureOpened() {
        val n = lfoNow(SkiffLfo(sync = 5), ClockState(), tempo = 120.0, openedMs = 1000, nowMs = 2500)
        assertEquals(1.5, n.since, 1e-9)
        assertEquals(3.0, n.cycles, 1e-9)
        assertTrue(lfoNow(SkiffLfo(phase = 64), ClockState(), 120.0, 0, 0).cycles == 0.5)
    }
}

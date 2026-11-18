package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.ClockState
import com.scottgerstl.lupe.core.PlayheadState
import com.scottgerstl.lupe.ui.edit.PlayheadMotion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The smooth playhead and the hit bounce run off the FM-1's clock (Scott, 2026-11-17). */
class PlayheadMotionTest {
    // 24 ticks a step at 96 ticks a second: a step lasts 250 ms
    private val clock = ClockState(running = true, ticks = 240.0, atMs = 1000, ticksPerSecond = 96.0)

    @Test fun sweepsThroughTheStepByTheClockNotTheFrame() {
        val ph = PlayheadState(track = 1, step = 10, startTick = 240.0, nextTick = 264.0, direction = 1)
        assertEquals(10f, PlayheadMotion.position(ph, clock, 1000)!!, 0.001f)
        assertEquals(10.5f, PlayheadMotion.position(ph, clock, 1125)!!, 0.001f)     // halfway: 125 ms in
        assertEquals(11f, PlayheadMotion.position(ph, clock, 2000)!!, 0.001f)       // past the next tick: it waits on the boundary, never runs ahead
        assertEquals(10.5f, PlayheadMotion.position(ph.copy(direction = -1), clock, 1125)!!, 0.001f)
    }

    @Test fun withoutTicksOrAClockItSitsOnTheStep() {
        assertEquals(3f, PlayheadMotion.position(PlayheadState(step = 3), clock, 5000)!!, 0f)
        assertEquals(3f, PlayheadMotion.position(PlayheadState(step = 3, startTick = 1.0, nextTick = 25.0), clock.copy(running = false), 5000)!!, 0f)
        assertEquals(null, PlayheadMotion.position(PlayheadState(step = -1), clock, 5000))
    }

    @Test fun aHitRisesIn50msAndSettlesBackToOne() {
        assertEquals(1f, PlayheadMotion.hitBounce(-5f), 0f)                         // before its step sounds
        assertEquals(1.12f, PlayheadMotion.hitBounce(50f), 0.001f)                   // the peak at 50 ms
        assertTrue(PlayheadMotion.hitBounce(25f) in 1.05f..1.12f)
        assertEquals(1f, PlayheadMotion.hitBounce(50f + 200f), 0.01f)                 // settled within the spring's 200 ms
        assertEquals(1f, PlayheadMotion.hitBounce(1000f), 0f)
        assertEquals(1f, PlayheadMotion.hitBounce(50f, scale = 1f), 0f)               // Labs at 100 %: no bounce
        assertEquals(125f, PlayheadMotion.msSince(228.0, clock, 1000)!!, 0.01f)        // the step before began 12 ticks (125 ms) ago
    }
}

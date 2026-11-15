package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.TraceProgress
import org.junit.Assert.assertEquals
import org.junit.Test

/** The waiting outline's rules, as the iPad's LaunchTrace (ios/FM1/PadsPage.swift). */
class LaunchTraceTest {
    @Test fun theLineGrowsFromTheTimeLeftWhenTheWaitBegan() {
        val p = TraceProgress()
        assertEquals(0f, p.at(96.0), 0.001f)
        assertEquals(0.5f, p.at(48.0), 0.001f)
        assertEquals(1f, p.at(0.0), 0.001f)
    }

    @Test fun onceRoundItHoldsClosedAndNeverRestartsFromTheNextPass() {
        val p = TraceProgress()
        p.at(96.0); p.at(6.0)
        assertEquals(1f, p.at(96.0), 0.001f)     // the time left jumped up after it was nearly there: the line passed; hold it closed
        assertEquals(1f, p.at(50.0), 0.001f)
    }

    @Test fun stagedAgainFurtherOffItStartsFromWhereItIsNow() {
        val p = TraceProgress()
        p.at(96.0); p.at(60.0)
        assertEquals(0f, p.at(192.0), 0.001f)    // re-staged a bar later, well before landing
        assertEquals(0.5f, p.at(96.0), 0.001f)
    }

    @Test fun theClockReferenceCarriesTheCountOnBetweenPublishes() {
        val clock = com.scottgerstl.lupe.core.ClockState(running = true, ticks = 480.0, atMs = 1000, ticksPerSecond = 48.0)   // 120 BPM
        assertEquals(492.0, clock.ticksNow(1250), 0.001)
        assertEquals(84.0, clock.ticksLeft(576.0, 1250)!!, 0.001)
        assertEquals(0.0, clock.ticksLeft(576.0, 9000)!!, 0.001)                 // never past the launch point: the line holds closed
        assertEquals(0.125f, clock.passProgress(480.0, 96.0, 1250)!!, 0.001f)
        assertEquals(0.125f, clock.passProgress(384.0, 96.0, 1250)!!, 0.001f)    // a later pass of the same entry: mod 1
    }

    @Test fun withNoClockNothingIsInterpolatedAndTheOutlineIsDashed() {
        val none = com.scottgerstl.lupe.core.ClockState()
        assertEquals(null, none.ticksLeft(576.0, 1250))                          // null draws the dashed outline
        assertEquals(null, none.passProgress(480.0, 96.0, 1250))                 // the screen falls back to the entry's own progress
        assertEquals(null, com.scottgerstl.lupe.core.ClockState(true, 0.0, 0, 48.0).ticksLeft(null, 10))
    }

    @Test fun p1sSampleDecodes() {
        val c = com.scottgerstl.lupe.core.lupeJson.decodeFromString(com.scottgerstl.lupe.core.ClockState.serializer(), """{"running":true,"ticks":480,"atMs":123456789,"ticksPerSecond":48.0}""")
        assertEquals(480.0, c.ticks, 0.0); assertEquals(123456789L, c.atMs)
    }
}

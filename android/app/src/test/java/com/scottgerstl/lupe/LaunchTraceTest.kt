package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.TraceProgress
import com.scottgerstl.lupe.ui.shell.passProgressNow
import com.scottgerstl.lupe.ui.shell.ticksLeftNow
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

    @Test fun betweenPublishesTheClockCarriesItOn() {
        assertEquals(84.0, ticksLeftNow(96.0, 48.0, 250), 0.001)      // 120 BPM is 48 ticks a second
        assertEquals(0.0, ticksLeftNow(6.0, 48.0, 1000), 0.001)        // never past the launch point
        assertEquals(0.375f, passProgressNow(0.25f, 96.0, 48.0, 250), 0.001f)
        assertEquals(1f, passProgressNow(0.9f, 96.0, 48.0, 1000), 0.001f)   // it stops at the pass's end
        assertEquals(0.25f, passProgressNow(0.25f, null, 48.0, 250), 0.001f) // no pass length known: the core's word as it is
        assertEquals(0.25f, passProgressNow(0.25f, 96.0, 0.0, 250), 0.001f)  // stopped
    }
}

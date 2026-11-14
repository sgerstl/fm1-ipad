package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.HoldTimer
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The page's picture under the dials: up on a knob turn or a dial touch, down after the hold (decision 30). */
class HoldTimerTest {
    @Test fun theFirstKnobCountIsOnlyTheBaseline() {
        val t = HoldTimer(); t.turn(5, 0)
        assertFalse(t.up)
        t.turn(5, 100); assertFalse(t.up)
    }

    @Test fun aKnobTurnOrADialTouchRaisesItAndEachRestartsTheWait() {
        val t = HoldTimer().also { it.holdMs = 8000 }
        t.turn(0, 0); t.turn(1, 1000); assertTrue(t.up)
        t.tick(8999); assertTrue(t.up)
        t.poke(8999)                       // a dial touched on the phone
        t.tick(9001); assertTrue(t.up)
        t.tick(16999); assertFalse(t.up)
    }

    @Test fun aPageChangeDropsItAtOnce() {
        val t = HoldTimer(); t.turn(0, 0); t.turn(1, 10)
        t.drop(); assertFalse(t.up)
    }
}

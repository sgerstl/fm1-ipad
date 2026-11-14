package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.SoundPanelModel
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SoundPanelModelTest {
    @Test fun restingOnASoundPageAtLaunchDoesNotRaiseIt() {
        val m = SoundPanelModel()
        m.page("FX/5", 0); m.turn(3, 0)
        assertFalse(m.up)
        m.page("FX/5", 5000)             // the same page again (a tab switch re-reads it): still down
        assertFalse(m.up)
    }

    @Test fun aPageChangeRaisesItAndItLeavesAfterTheHold() {
        val m = SoundPanelModel()
        m.page(null, 0); m.turn(0, 0)
        m.page("FX/5", 1000)
        assertTrue(m.up)
        m.tick(4900); assertTrue(m.up)
        m.tick(5000); assertFalse(m.up)
        m.page("FX/46", 6000)            // a page step within the family
        assertTrue(m.up)
    }

    @Test fun knobTurnsAndTouchesKeepItUpAndATurnBringsItBack() {
        val m = SoundPanelModel()
        m.page(null, 0); m.turn(0, 0)
        m.page("ENV/0", 1000)
        m.turn(1, 4000); m.tick(5000); assertTrue(m.up)      // the turn restarted the timer
        m.touch(7000); m.tick(8000); assertTrue(m.up)
        m.tick(11000); assertFalse(m.up)
        m.turn(2, 20000); assertTrue(m.up)                   // a knob turned while it's down brings it back for that page
    }

    @Test fun homeASwipeAndAReconnectLowerIt() {
        val m = SoundPanelModel()
        m.page(null, 0); m.turn(0, 0)
        m.page("LFO/2", 100); m.page(null, 200); assertFalse(m.up)   // HOME
        m.page("LFO/2", 300); m.dismiss(); assertFalse(m.up)          // a swipe down
        m.turn(1, 400); assertTrue(m.up)
        m.reset(); assertFalse(m.up)
        m.page("LFO/2", 500); assertFalse(m.up)                       // after a reconnect the page it finds is only the baseline
    }

    @Test fun aKnobTurnedWithNoSoundPageDoesNothing() {
        val m = SoundPanelModel()
        m.page(null, 0); m.turn(0, 0); m.turn(1, 100)
        assertFalse(m.up)
    }
}

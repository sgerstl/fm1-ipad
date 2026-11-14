package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.SoundPanelModel
import com.scottgerstl.lupe.ui.shell.railTarget
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The docked sound panel's rule (decision 32): it opens on a change, and stays until HOME, its close key or another tab. No timeout. */
class SoundPanelModelTest {
    @Test fun restingOnASoundPageAtLaunchDoesNotOpenIt() {
        val m = SoundPanelModel()
        m.page("FX/5"); m.turn(3)
        assertFalse(m.up)
        m.page("FX/5")                   // the same page again (a tab switch re-reads it): still shut
        assertFalse(m.up)
    }

    @Test fun aPageChangeOpensItAndItStays() {
        val m = SoundPanelModel()
        m.page(null); m.turn(0)
        m.page("FX/5")
        assertTrue(m.up)
        m.page("FX/46")                  // a page step within the family: still open, on the new page
        assertTrue(m.up)
        m.turn(1); m.turn(2)             // knobs turning change nothing about it being open
        assertTrue(m.up)
    }

    @Test fun homeShutsIt() {
        val m = SoundPanelModel()
        m.page(null); m.page("ENV/0"); assertTrue(m.up)
        m.page(null)
        assertFalse(m.up)
    }

    @Test fun theCloseKeyShutsItAndAKnobOrAPageChangeBringsItBack() {
        val m = SoundPanelModel()
        m.page(null); m.turn(0); m.page("LFO/2")
        m.dismiss(); assertFalse(m.up)
        m.turn(9); assertTrue(m.up)      // a knob turned on the FM-1, still on that page
        m.dismiss()
        m.page("LFO/3"); assertTrue(m.up)
    }

    @Test fun aKnobTurnOnHomeDoesNotOpenIt() {
        val m = SoundPanelModel()
        m.page(null); m.turn(0); m.turn(1)
        assertFalse(m.up)
    }

    @Test fun aLostLinkStartsAgainFromABaseline() {
        val m = SoundPanelModel()
        m.page(null); m.page("FX/5"); assertTrue(m.up)
        m.reset(); assertFalse(m.up)
        m.page("FX/5"); assertFalse(m.up)    // the first page after the link comes back is only the baseline
    }

    @Test fun theRailsKeyOpensAFamilyAndTheSameKeyAgainStepsItsPages() {
        assertNull(railTarget("ENV", null, emptyList(), 0))                       // shut: the FM-1 chooses the family's page
        assertNull(railTarget("ENV", "FX", listOf(5, 46, 47), 5))                 // another family's panel is open: this one opens
        assertEquals(46, railTarget("FX", "FX", listOf(5, 46, 47, 6), 5))         // the open family's key: its next page
        assertEquals(5, railTarget("FX", "FX", listOf(5, 46, 47, 6), 6))          // and round to the first
    }
}

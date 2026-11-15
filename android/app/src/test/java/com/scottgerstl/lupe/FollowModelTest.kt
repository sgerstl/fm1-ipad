package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.BottomPage
import com.scottgerstl.lupe.ui.shell.FollowModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FollowModelTest {
    private fun page(f: String) = BottomPage(BottomKind.Page, f, f)
    private val editor = BottomPage()

    @Test fun aPageTheFm1ChangesItselfIsHeldAfterATouchWithPause() {
        val m = FollowModel(page("FX")).also { it.pause = true }
        m.touch(1000)
        m.onActual(page("SEL"), 1500)
        assertEquals(page("FX"), m.shown); assertTrue(m.frozen)
        m.tick(4100)   // the hold ran out: it catches up
        assertEquals(page("SEL"), m.shown); assertFalse(m.frozen)
    }

    @Test fun pauseOnTapFxOnThePhoneThenTheCoreAndTheFm1BothSayFxShowsFxWithNoHold() {
        val m = FollowModel(page("ENV")).also { it.pause = true }
        m.touch(1000)                 // the tap on the family row is a touch…
        m.ask(1010)                   // …and a page change the phone asked for
        m.onActual(page("FX"), 1013)  // the core publishes FX (+3 ms)
        assertEquals(page("FX"), m.shown); assertFalse(m.frozen)
        m.onActual(page("FX"), 1050)  // the FM-1's reply: the same page
        assertEquals(page("FX"), m.shown); assertFalse(m.frozen)
        // and the FM-1 moving on by itself afterwards is held only by a *new* touch
        m.onActual(page("LFO"), 2000)
        assertEquals(page("LFO"), m.shown)
    }

    @Test fun pinStillAppliesWhatThePhoneAsksFor() {
        val m = FollowModel(page("ENV")).also { it.pin = true }
        m.onActual(page("LFO"), 100)             // the FM-1 by itself: held
        assertEquals(page("ENV"), m.shown)
        m.ask(200); m.onActual(page("FX"), 203)  // the phone asked: applies at once
        assertEquals(page("FX"), m.shown)
        m.onActual(page("SEL"), 5000)            // later FM-1 change, long after the window: held again
        assertEquals(page("FX"), m.shown); assertTrue(m.frozen)
    }

    @Test fun backAppliesAtOnceWithPauseOn() {
        val m = FollowModel(page("ENV")).also { it.pause = true }
        m.touch(0); m.ask(10); m.onActual(editor, 14)
        assertEquals(editor, m.shown)
    }
}

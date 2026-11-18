package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.GoHome
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.PickPage
import com.scottgerstl.lupe.core.ScreenGoto
import com.scottgerstl.lupe.ui.shell.FollowModel
import com.scottgerstl.lupe.ui.shell.isPhoneAsk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** A page the phone asks for is never held by Pause following (2026-11-18: FX after closing the step panel waited 3 s). */
class PhoneAskTest {
    @Test fun theSoundKeysPagePickIsAnAsk() {
        assertTrue(isPhoneAsk(PickPage("FX", null)))
        assertTrue(isPhoneAsk(ScreenGoto("GLO", 30)))
        assertTrue(isPhoneAsk(GoHome))
        assertFalse(isPhoneAsk(Intent.StepSelect(0)))
    }

    @Test fun pausedThenAskedTheNewPageShowsAtOnce() {
        val m = FollowModel("EDIT"); m.pause = true
        m.touch(1000)                       // a touch on Edit (the step panel closed)
        m.onActual("EDIT", 1000)
        m.ask(1200)                         // FX tapped on the sound keys
        m.onActual("FX", 1203)              // the core's update, 3 ms later
        assertEquals("FX", m.shown)
    }
}

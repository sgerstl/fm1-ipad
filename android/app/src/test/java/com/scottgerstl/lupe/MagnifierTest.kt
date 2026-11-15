package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.MagnifierState
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Magnifier never outlives the gesture that raised it (Scott's stuck ATTACK overlay, 2026-11-14). */
class MagnifierTest {
    private val face = MagnifierFace("ATTACK", { "12" })

    @Test fun theGestureThatRaisedItTakesItDownHoweverItEnds() {
        val m = MagnifierState(); val dial = Any()
        m.show(dial, face, Offset.Zero); assertTrue(m.shown)
        m.hide(dial); assertFalse(m.shown)           // finger up, a pointer cancel and the dial leaving the screen all end here
    }

    @Test fun anEarlierGestureEndingLateDoesNotTakeDownALaterOnes() {
        val m = MagnifierState(); val a = Any(); val b = Any()
        m.show(a, face, Offset.Zero); m.show(b, face, Offset.Zero)
        m.hide(a); assertTrue(m.shown)
        m.hide(b); assertFalse(m.shown)
    }

    @Test fun aTabOrPanelLeavingTakesItDownWhoeverRaisedIt() {
        val m = MagnifierState()
        m.show(Any(), face, Offset.Zero)
        m.hideAll(); assertFalse(m.shown)
    }
}

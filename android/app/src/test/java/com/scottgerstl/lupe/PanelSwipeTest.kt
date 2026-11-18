package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.PanelSwipeRule
import com.scottgerstl.lupe.ui.shell.panelX
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** A panel follows the finger as it's swiped away (Scott, 2026-11-18). */
class PanelSwipeTest {
    @Test fun followsRightResistsLeft() {
        assertEquals(40f, PanelSwipeRule.follow(40f, 72f), 0f)        // 1:1 rightward
        assertEquals(-10f, PanelSwipeRule.follow(-30f, 72f), 0.001f)  // a third leftward
        assertEquals(-72f, PanelSwipeRule.follow(-900f, 72f), 0f)     // capped (24 dp at 3×)
    }

    @Test fun releaseClosesPastAThirdOrOnAFling() {
        assertTrue(PanelSwipeRule.dismisses(400f, 1080f, 0f, 1500f))       // 37 % of the width
        assertFalse(PanelSwipeRule.dismisses(300f, 1080f, 0f, 1500f))      // 28 %: back
        assertTrue(PanelSwipeRule.dismisses(60f, 1080f, 2400f, 1500f))     // a quick flick
        assertFalse(PanelSwipeRule.dismisses(60f, 1080f, -2400f, 1500f))   // flung the wrong way
    }

    @Test fun aSwipedOutPanelDoesntJumpAsItCloses() {
        assertEquals(1080f, panelX(0f, 1080f), 0f)       // out by the finger, its close not begun
        assertEquals(1080f, panelX(540f, 1080f), 0f)     // its close half way: still out
        assertEquals(-20f, panelX(0f, -20f), 0f)         // dragged left from its place
    }
}

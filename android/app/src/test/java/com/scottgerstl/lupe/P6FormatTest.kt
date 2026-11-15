package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.AutomationLane
import com.scottgerstl.lupe.core.AutomationState
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.ui.automation.automationParams
import com.scottgerstl.lupe.ui.timeline.BlockUi
import com.scottgerstl.lupe.ui.timeline.barRange
import com.scottgerstl.lupe.ui.timeline.barsText
import org.junit.Assert.assertEquals
import org.junit.Test

/** The words on the Timeline (the run on 40c8629 read "1.00000 bars" and "BARS 2–2") and the lane picker for a fresh pattern. */
class P6FormatTest {
    @Test fun barsReadAsWords() {
        assertEquals("1 bar", barsText(1f)); assertEquals("5 bars", barsText(5.00000f)); assertEquals("½ bar", barsText(0.5f))
        assertEquals("2½ bars", barsText(2.5f)); assertEquals("1 bar", barsText(1.0000001f)); assertEquals("0.25 bars", barsText(0.25f))
    }

    @Test fun aBlockInsideOneBarIsBarN() {
        fun b(start: Float, len: Float) = BlockUi(1, 0, 1, start, len, 1f, len.toInt().coerceAtLeast(1), 7, false, false)
        assertEquals("bar 2", barRange(b(1f, 1f))); assertEquals("bars 2–5", barRange(b(1f, 4f))); assertEquals("bar 1", barRange(b(0f, 0.5f)))
    }

    @Test fun aFreshPatternOffersTheSoundPagesParameters() {
        val page = PageState(controls = listOf(PageControl("ATTACK", "10", 10), PageControl("DECAY", "30", 30), null, PageControl("ROUTE", "", ringless = true)))
        assertEquals(listOf("ATTACK", "DECAY"), automationParams(AutomationState(), page))
        assertEquals(listOf("CUTOFF", "ATTACK", "DECAY"), automationParams(AutomationState(lanes = listOf(AutomationLane("CUTOFF", 1))), page))
    }
}

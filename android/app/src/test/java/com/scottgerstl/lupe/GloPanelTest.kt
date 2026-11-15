package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.Fm1ScreenState
import com.scottgerstl.lupe.core.MixCard
import com.scottgerstl.lupe.core.MixState
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.core.ScreenGoto
import com.scottgerstl.lupe.ui.shell.*
import org.junit.Assert.*
import org.junit.Test

class GloPanelTest {
    private fun screen(page: Int, title: String) = Fm1ScreenState(key = "GLO", page = page, title = title)
    private val card = MixCard("Delay", controls = listOf(PageControl("TIME", "1/8", 3), PageControl("FDBK", "40", 40), PageControl("MIX", "30", 30), PageControl("TONE", "0", 0)))

    @Test fun theBusPagesAreTheSoundPanelsAndTheMixerIsNot() {
        assertTrue(onGloBus(screen(31, "DELAY"))); assertTrue(onGloBus(screen(34, "GLOBAL")))
        assertFalse(onGloBus(screen(30, "MIXER"))); assertFalse(onGloBus(Fm1ScreenState(key = "FX", page = 3)))
    }

    @Test fun thePanelsPageSaysGlo2Of5DelayWithFourControlsAndNoTrackColour() {
        val p = gloPageState(MixState(section = "delay", card = card), screen(31, "DELAY"), 3, "Lead")!!
        assertEquals("GLO", p.family); assertEquals(5, p.pages.size); assertEquals(1, p.pages.indexOfFirst { it.index == p.page }); assertEquals("DELAY", p.title)
        assertEquals(4, p.controls.size); assertEquals("TIME", p.controls[0]?.label)
        assertNull(gloPageState(MixState(section = "mixer"), screen(30, "MIXER"), 1, ""))
    }

    @Test fun theGloKeyOpensTwoOfFiveThenStepsAndWraps() {
        assertEquals(31, gloKeyTarget(open = false, page = 99))
        assertEquals(32, gloKeyTarget(open = true, page = 31)); assertEquals(33, gloKeyTarget(true, 32)); assertEquals(34, gloKeyTarget(true, 33))
        assertEquals(31, gloKeyTarget(true, 34))                        // 5/5 → 2/5
        assertEquals("GLO", SOUND_KEYS.last())                           // after ARP
    }

    @Test fun thePanelsDialsAndPageStepsMeanTheMixAreasIntents() {
        val sent = mutableListOf<com.scottgerstl.lupe.core.Intent>()
        val base = com.scottgerstl.lupe.core.FakeLupeCore(kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined), emptyMap(), "searching")
        val glo = object : com.scottgerstl.lupe.core.LupeCore by base { override fun send(intent: com.scottgerstl.lupe.core.Intent) { sent += intent } }
        val c = GloCore(glo)
        c.send(com.scottgerstl.lupe.core.SetParam(1, 50)); c.send(com.scottgerstl.lupe.core.PickPage("GLO", 33)); c.send(com.scottgerstl.lupe.core.PickTile(2))
        assertEquals(listOf(com.scottgerstl.lupe.core.SetMixParam(1, 50), ScreenGoto("GLO", 33), com.scottgerstl.lupe.core.SetMixSetting(0, 2)), sent)
    }
}

class RailKeyActionTest {
    @org.junit.Test fun aShutPanelWithTheFm1AlreadyOnThatFamilyJustShowsIt() {
        assertEquals(RailKeyAction.Show, railKeyAction("GLO", openFamily = null, fm1Family = "GLO"))      // closed with ×, the FM-1 still on GLO 2/5
        assertEquals(RailKeyAction.Show, railKeyAction("FX", null, "FX"))
    }
    @org.junit.Test fun anOpenPanelOnThatFamilyStepsAndOtherwiseTheFm1IsSent() {
        assertEquals(RailKeyAction.Step, railKeyAction("FX", "FX", "FX"))
        assertEquals(RailKeyAction.Goto, railKeyAction("ENV", "FX", "FX"))       // another family's panel is open
        assertEquals(RailKeyAction.Goto, railKeyAction("ENV", null, "FX"))       // shut, the FM-1 on another family
        assertEquals(RailKeyAction.Goto, railKeyAction("ENV", null, null))       // shut, the FM-1 on none (HOME)
    }
}

class MixRowSpecTest {
    @org.junit.Test fun sixRowsFitAtTheIPhonesHeightWhenThereIsRoomAndShrinkWhenNot() {
        val spec = com.scottgerstl.lupe.ui.mix.MixRowSpec
        assertEquals(48f, spec.rowHeight(330f, 6), 0.001f)          // 6 × 48 + 5 × 4 = 308 fits in 330
        assertEquals((290f - 20f) / 6, spec.rowHeight(290f, 6), 0.001f)   // fewer: they share it
        assertEquals(36f, spec.rowHeight(100f, 6), 0f)             // never under 36
        assertEquals(92f, spec.HEAD, 0f); assertEquals(84f, spec.PAN, 0f); assertEquals(84f, spec.SEND, 0f); assertEquals(120f, spec.LEVEL_MIN, 0f)
    }
}

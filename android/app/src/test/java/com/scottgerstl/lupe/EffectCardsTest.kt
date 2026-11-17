package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.MixCard
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.ui.mix.collapsedPair
import com.scottgerstl.lupe.ui.mix.pickedCardWidth
import org.junit.Assert.assertEquals
import org.junit.Test

/** Mix › Effects, direction C (Scott, 2026-11-17). */
class EffectCardsTest {
    @Test fun thePickedCardTakesWhatTheThreeCollapsedOnesLeave() {
        assertEquals(882f - 3 * 112f - 18f, pickedCardWidth(882f), 0f)    // the Pixel's body: about 528
        assertEquals(112f, pickedCardWidth(200f), 0f)                       // never narrower than a collapsed card
    }

    @Test fun aCollapsedCardShowsItsTwoValuesOrADash() {
        val delay = MixCard("Delay", listOf(PageControl("TIME", "3/16"), PageControl("FEEDBACK", "48 %"), PageControl("COLOR", "62"), PageControl("MIX", "30 %")))
        assertEquals(listOf("TIME" to "3/16", "MIX" to "30 %"), collapsedPair("delay", delay))
        assertEquals(listOf("TYPE" to "—", "MIX" to "—"), collapsedPair("reverb", null))    // not seen yet
    }
}

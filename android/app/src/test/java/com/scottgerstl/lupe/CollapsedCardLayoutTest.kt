package com.scottgerstl.lupe

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.core.MixCard
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.ui.mix.EffectsPage
import com.scottgerstl.lupe.ui.mix.MixActions
import com.scottgerstl.lupe.ui.mix.MixUi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The collapsed effect cards (Scott on the Pixel, 2026-11-18): the caption sits at the text's 14 dp edge inside the card, and the picture is centred between it and the values. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w952dp-h427dp-land-xxhdpi")
class CollapsedCardLayoutTest {
    @get:Rule val rule = createComposeRule()

    private val cards = mapOf(
        "delay" to MixCard("Delay", listOf(PageControl("TIME", "1/8", 1), PageControl("FEEDBACK", "60", 60), PageControl("COLOR", "64", 64), PageControl("MIX", "90", 90))),
        "chorus" to MixCard("Chorus", listOf(PageControl("RATE", "40", 40), PageControl("DEPTH", "80", 80), PageControl("MIX", "60", 60), null)),
        "global" to MixCard("Global", listOf(PageControl("TEMPO", "120", 120), PageControl("SWING", "50", 50, 0, 100), PageControl("MASTER", "100", 100), PageControl("TRANSPOSE", "0", 0))),
    )
    private val actions = MixActions({}, { _, _ -> }, { _, _ -> }, { _, _ -> }, {}, {}, { _, _ -> }, { _, _ -> }, {})

    @Test fun captionAndPictureSitInTheCard() {
        rule.mainClock.autoAdvance = false
        var ui by mutableStateOf(MixUi(page = 3, sectionKey = "chorus", card = cards["chorus"]))
        rule.setContent { EffectsPage(ui, actions, graphics = true) }
        fun settle() { androidx.compose.runtime.snapshots.Snapshot.sendApplyNotifications(); rule.mainClock.advanceTimeBy(1500) }
        settle()
        ui = MixUi(page = 4, sectionKey = "global", card = cards["global"]); settle()
        ui = MixUi(page = 1, sectionKey = "delay", card = cards["delay"]); settle()
        for (key in listOf("chorus", "global")) {
            val cap = rule.onNodeWithTag("fx-caption-$key", useUnmergedTree = true).getUnclippedBoundsInRoot()
            val pic = rule.onNodeWithTag("fx-picture-$key", useUnmergedTree = true).getUnclippedBoundsInRoot()
            val vals = rule.onNodeWithTag("fx-values-$key", useUnmergedTree = true).getUnclippedBoundsInRoot()
            assertEquals("$key caption width", 84f, (cap.right - cap.left).value, 0.5f)        // 112 less 14 each side: never past the card
            assertEquals("$key caption left edge", vals.left.value, cap.left.value, 0.5f)      // same edge as the values
            assertEquals("$key picture left edge", vals.left.value, pic.left.value, 0.5f)
            assertTrue("$key picture below the caption", pic.top >= cap.bottom)
            assertTrue("$key picture above the values", pic.bottom + 8.dp <= vals.top + 0.5.dp)
            val above = (pic.top - cap.bottom).value; val below = (vals.top - 8.dp - pic.bottom).value
            assertEquals("$key picture centred", above, below, 1f)
        }
        // every collapsed card's picture box at the same height
        val a = rule.onNodeWithTag("fx-picture-chorus", useUnmergedTree = true).getUnclippedBoundsInRoot()
        val b = rule.onNodeWithTag("fx-picture-global", useUnmergedTree = true).getUnclippedBoundsInRoot()
        assertEquals(a.top.value, b.top.value, 0.5f)
    }
}

package com.scottgerstl.lupe

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.width
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.MagnifierPlate
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The magnifier plate (Figma 141:9654, 2026-11-18) composes for a tile and for a dial, with the label, the knob badge and the value. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
class MagnifierPlateTest {
    @get:Rule val rule = createComposeRule()

    @Test fun aTile() {
        rule.setContent { MagnifierPlate(MagnifierFace("VELOCITY", { "96" }, { 0.75f }, tint = Color.Red, knob = 4)) }
        rule.onNodeWithText("VELOCITY").assertExists(); rule.onNodeWithText("4").assertExists(); rule.onNodeWithText("96").assertExists()
    }

    @Test fun aDial() {
        rule.setContent { MagnifierPlate(MagnifierFace("CUTOFF", { "1.2k" }, { 0.4f }, ring = true, tint = Color.Red, knob = 1)) }
        rule.onNodeWithText("CUTOFF").assertExists(); rule.onNodeWithText("1").assertExists(); rule.onNodeWithText("1.2k").assertExists()
    }

    // the plate hugs its content (Scott, 2026-11-18: "too wide for no reason"), never under 120, and doesn't change width while dragging
    @Test fun hugsItsContentAndHoldsItsWidth() {
        var v by mutableStateOf("1")
        rule.setContent { MagnifierPlate(MagnifierFace("TUNE", { v }, { 0.5f }, bipolar = true, knob = 2, widest = listOf("-100", "100"))) }
        val w1 = rule.onRoot().getUnclippedBoundsInRoot().width
        assertTrue("narrower than the old 220 floor: $w1", w1.value < 220f)
        assertTrue("at least 120: $w1", w1.value >= 119.5f)
        for (x in listOf("-100", "42", "-7", "100")) { v = x; rule.waitForIdle(); assertEquals("width with $x", w1.value, rule.onRoot().getUnclippedBoundsInRoot().width.value, 0.5f) }
    }

    @Test fun theValueSlotCoversItsTemplates() {
        val t = com.scottgerstl.lupe.ui.slide.valueTemplates("19", listOf("0", "127"), bipolar = true, wideDigit = '8')
        assertTrue(t.containsAll(listOf("19", "88", "-88", "0", "127")))
    }
}

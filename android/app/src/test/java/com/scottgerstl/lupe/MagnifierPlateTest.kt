package com.scottgerstl.lupe

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
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
}

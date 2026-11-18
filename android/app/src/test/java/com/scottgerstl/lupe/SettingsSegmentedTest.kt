package com.scottgerstl.lupe

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.click
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performTouchInput
import com.scottgerstl.lupe.ui.settings.Segmented
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** "Sound keys side" is disabled while Sound keys is off (2026-11-18): dimmed, no touch, TalkBack says why. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w400dp-h800dp", application = android.app.Application::class)
class SettingsSegmentedTest {
    @get:Rule val rule = createComposeRule()

    @Test fun disabledItSaysWhyAndTakesNoTap() {
        var picked = -1
        rule.setContent { Segmented(listOf("Left", "Right"), 1, "Sound keys side", enabled = false, disabledWhy = "Turn on Sound keys first") { picked = it } }
        val node = rule.onNode(hasContentDescription("Sound keys side"))
        node.assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Disabled))
        node.assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Turn on Sound keys first"))
        node.performTouchInput { click(androidx.compose.ui.geometry.Offset(width * 0.25f, height / 2f)) }
        rule.waitForIdle()
        assertEquals("no pick while disabled", -1, picked)
    }

    @Test fun enabledItPicks() {
        var picked = -1
        rule.setContent { Segmented(listOf("Left", "Right"), 1, "Sound keys side") { picked = it } }
        rule.onNode(hasContentDescription("Sound keys side: Left")).performTouchInput { click() }
        rule.waitForIdle()
        assertEquals(0, picked)
    }
}

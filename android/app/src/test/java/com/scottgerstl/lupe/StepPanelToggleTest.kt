package com.scottgerstl.lupe

import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performTouchInput
import com.scottgerstl.lupe.core.AutomationState
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.Step
import com.scottgerstl.lupe.core.TopState
import com.scottgerstl.lupe.ui.shell.EditTab
import com.scottgerstl.lupe.ui.shell.EditUi
import com.scottgerstl.lupe.ui.shell.StepPick
import com.scottgerstl.lupe.ui.shell.stepPanelX
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The step panel opens, closes and opens again straight away, by real touches (they go through hit testing, as a finger's do), and a closed
 * panel takes no touches where it used to sit (2026-11-18: c38b22a left an invisible strip over Edit's right side; "i can't even open the
 * step panel").
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
class StepPanelToggleTest {
    @get:Rule val rule = createComposeRule()

    private class RecCore(ed: EditorState) : LupeCore {
        val sent = mutableListOf<Intent>()
        override val link: StateFlow<LinkState> = MutableStateFlow(LinkState())
        override val top: StateFlow<TopState> = MutableStateFlow(TopState())
        override val shell: StateFlow<ShellState> = MutableStateFlow(ShellState())
        override val pads: StateFlow<PadsState> = MutableStateFlow(PadsState())
        override val editor: StateFlow<EditorState> = MutableStateFlow(ed)
        override val page: StateFlow<PageState> = MutableStateFlow(PageState())
        override fun send(intent: Intent) { sent += intent }
    }

    private val ed = EditorState(track = 1, trackName = "Acid", steps = (0 until 16).map { if (it % 4 == 0) Step(on = true, note = "C4", length = 1) else Step() }, patternSteps = 16)

    @Test fun theStepKeyOpensClosesAndReopensStraightAway() {
        val ui = EditUi(); val pick = StepPick().apply { step = 0 }
        rule.mainClock.autoAdvance = false
        rule.setContent { EditTab(ed, RecCore(ed), AutomationState(), pick, ui) }
        rule.mainClock.advanceTimeBy(500)
        val key = rule.onNodeWithContentDescription("Step 1 panel")
        key.performTouchInput { click() }; rule.mainClock.advanceTimeBy(600); assertTrue("opened", ui.stepPanel)
        key.performTouchInput { click() }; rule.mainClock.advanceTimeBy(600); assertFalse("closed", ui.stepPanel)
        key.performTouchInput { click() }; rule.mainClock.advanceTimeBy(600); assertTrue("opened again at once", ui.stepPanel)
        key.performTouchInput { click() }; rule.mainClock.advanceTimeBy(600); assertFalse("closed again", ui.stepPanel)
    }

    @Test fun aClosedPanelTakesNoTouchesWhereItSat() {
        val ui = EditUi(); val pick = StepPick().apply { step = 0 }
        val core = RecCore(ed)
        rule.mainClock.autoAdvance = false
        rule.setContent { EditTab(ed, core, AutomationState(), pick, ui) }
        rule.mainClock.advanceTimeBy(500)
        val key = rule.onNodeWithContentDescription("Step 1 panel")
        key.performTouchInput { click() }; rule.mainClock.advanceTimeBy(600)
        key.performTouchInput { click() }; rule.mainClock.advanceTimeBy(600)
        rule.mainClock.advanceTimeBy(1000)
        core.sent.clear()
        // the right part of the grid, where the docked panel was: a tap there reaches the grid (it writes or picks a step)
        rule.onNodeWithContentDescription("Step 16,", substring = true).performTouchInput { click() }
        rule.mainClock.advanceTimeBy(600)
        assertTrue("the grid took the tap: ${core.sent}", core.sent.isNotEmpty())
    }

    @Test fun closedItSitsAWholeWidthOffWithOrWithoutReduceMotion() {
        assertEquals(1080f, stepPanelX(0f, 1080f, 0f, reduce = false), 0f)
        assertEquals(1080f, stepPanelX(0f, 1080f, 0f, reduce = true), 0f)
        assertEquals(0f, stepPanelX(1f, 1080f, 0f, reduce = true), 0f)
        assertEquals(540f, stepPanelX(0.5f, 1080f, 0f, reduce = false), 0f)
    }
}

package com.scottgerstl.lupe

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import com.scottgerstl.lupe.core.AutomationState
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.Step
import com.scottgerstl.lupe.core.StepField
import com.scottgerstl.lupe.core.TopState
import com.scottgerstl.lupe.ui.shell.EditTab
import com.scottgerstl.lupe.ui.shell.EditUi
import com.scottgerstl.lupe.ui.shell.StepPick
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The step panel's gutter (Scott, 2026-11-18, "1 · Gutter"): a sideways drag from the gutter moves the panel; one on the pitch tile edits it. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
class StepPanelGutterTest {
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
    private fun pitchEdits(c: RecCore) = c.sent.count { it is Intent.StepAdjust && it.field == StepField.Pitch }

    @Test fun aDragFromTheGutterMovesThePanelAndLeavesPitch() {
        val ui = EditUi().apply { stepPanel = true }; val core = RecCore(ed)
        rule.setContent { EditTab(ed, core, AutomationState(), StepPick().apply { step = 0 }, ui) }
        rule.waitForIdle()
        rule.onNode(hasContentDescription("Close the step panel")).performTouchInput { swipe(center, center + Offset(220f, 0f), durationMillis = 250) }
        rule.waitForIdle()
        assertFalse("swiped away", ui.stepPanel)
        assertTrue("pitch untouched: ${core.sent}", pitchEdits(core) == 0)
    }


    @Test fun aDragOnThePitchTileEditsItAndLeavesThePanel() {
        val ui = EditUi().apply { stepPanel = true }; val core = RecCore(ed)
        rule.setContent { EditTab(ed, core, AutomationState(), StepPick().apply { step = 0 }, ui) }
        rule.waitForIdle()
        rule.onNode(hasContentDescription("Pitch", substring = true)).performTouchInput { swipe(center, center + Offset(120f, 0f), durationMillis = 400) }
        rule.waitForIdle()
        assertTrue("still open", ui.stepPanel)
        assertTrue("pitch edited: ${core.sent}", pitchEdits(core) > 0)
    }
}

package com.scottgerstl.lupe

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Rule
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
/** Edit comes to rest: nothing recomposes or animates once a change has settled (2026-11-18: the grid recomposed itself every frame on 8-step pages). */
class EditIdleTest {
    @get:Rule val rule = createComposeRule()
    private class RecCore(ed: EditorState) : LupeCore {
        override val link: StateFlow<LinkState> = MutableStateFlow(LinkState())
        override val top: StateFlow<TopState> = MutableStateFlow(TopState())
        override val shell: StateFlow<ShellState> = MutableStateFlow(ShellState())
        override val pads: StateFlow<PadsState> = MutableStateFlow(PadsState())
        override val editor: StateFlow<EditorState> = MutableStateFlow(ed)
        override val page: StateFlow<PageState> = MutableStateFlow(PageState())
        override fun send(intent: Intent) {}
    }
    private val ed = EditorState(track = 1, trackName = "Acid", steps = (0 until 16).map { if (it % 4 == 0) Step(on = true, note = "C4", length = 1) else Step() }, patternSteps = 16)
    fun idles(step: Int?, open: Boolean): String {
        val ui = EditUi().apply { stepPanel = open }; val pick = StepPick().apply { this.step = step }
        rule.setContent { EditTab(ed, RecCore(ed), AutomationState(), pick, ui) }
        return try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" }
    }
    @Test fun noStepPicked() { org.junit.Assert.assertEquals("noStepPicked", "idle", idles(null, false)) }
    @Test fun pickedClosed() { org.junit.Assert.assertEquals("pickedClosed", "idle", idles(0, false)) }
    @Test fun afterToggle() {
        val ui = EditUi(); val pick = StepPick().apply { step = 0 }
        rule.setContent { EditTab(ed, RecCore(ed), AutomationState(), pick, ui) }
        rule.waitForIdle()
        ui.stepPanel = true
        org.junit.Assert.assertEquals("afterOpenByState", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
        ui.stepPanel = false
        org.junit.Assert.assertEquals("afterCloseByState", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
    }
    @Test fun afterTouch() {
        val ui = EditUi(); val pick = StepPick().apply { step = 0 }
        rule.setContent { EditTab(ed, RecCore(ed), AutomationState(), pick, ui) }
        rule.waitForIdle()
        rule.mainClock.autoAdvance = false
        rule.onNode(hasContentDescription("Step 1 panel")).performTouchInput { click() }
        rule.mainClock.advanceTimeBy(2000)
        rule.mainClock.autoAdvance = true
        org.junit.Assert.assertEquals("afterTouchOpen", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
    }
    @Test fun gridPageChange() {
        var page by androidx.compose.runtime.mutableStateOf(16)
        rule.setContent { com.scottgerstl.lupe.ui.edit.StepGrid(ed, androidx.compose.ui.graphics.Color.Red, RecCore(ed), 0, {}, androidx.compose.ui.unit.Dp(0f), canPlay = { false }, pageSteps = page) }
        rule.waitForIdle()
        page = 8
        org.junit.Assert.assertEquals("grid16to8", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
    }
    @Test fun gridPageChangeNoPick() {
        var page by androidx.compose.runtime.mutableStateOf(16)
        rule.setContent { com.scottgerstl.lupe.ui.edit.StepGrid(ed, androidx.compose.ui.graphics.Color.Red, RecCore(ed), null, {}, androidx.compose.ui.unit.Dp(0f), canPlay = { false }, pageSteps = page) }
        rule.waitForIdle()
        page = 8
        org.junit.Assert.assertEquals("grid16to8 nopick", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
    }
    @Test fun gridPageChangeReduce() {
        var page by androidx.compose.runtime.mutableStateOf(16)
        rule.setContent { androidx.compose.runtime.CompositionLocalProvider(com.scottgerstl.lupe.ui.theme.LocalReduceMotion provides true) { com.scottgerstl.lupe.ui.edit.StepGrid(ed, androidx.compose.ui.graphics.Color.Red, RecCore(ed), 0, {}, androidx.compose.ui.unit.Dp(0f), canPlay = { false }, pageSteps = page) } }
        rule.waitForIdle()
        page = 8
        org.junit.Assert.assertEquals("grid16to8 reduce", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
    }
    @Test fun gridAt8() {
        rule.setContent { com.scottgerstl.lupe.ui.edit.StepGrid(ed, androidx.compose.ui.graphics.Color.Red, RecCore(ed), 0, {}, androidx.compose.ui.unit.Dp(0f), canPlay = { false }, pageSteps = 8) }
        org.junit.Assert.assertEquals("gridAt8", "idle", try { rule.waitForIdle(); "idle" } catch (e: Throwable) { "NOT idle" })
    }
    @Test fun pickedOpen() { org.junit.Assert.assertEquals("pickedOpen", "idle", idles(0, true)) }
}

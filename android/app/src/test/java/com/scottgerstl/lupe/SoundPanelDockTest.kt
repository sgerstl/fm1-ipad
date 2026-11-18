package com.scottgerstl.lupe

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.printToString
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
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
import com.scottgerstl.lupe.ui.shell.SoundPanel
import com.scottgerstl.lupe.ui.shell.StepPick
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The docked sound panel moves as an offset and stays built (2026-11-18): it opens, closes and opens again; closed, taps where it sat reach
 * what is under it; and Edit comes to rest after it docks or leaves.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
class SoundPanelDockTest {
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

    @Test fun opensClosesReopensAndClosedLetsTapsThrough() {
        var visible by mutableStateOf(false)
        var t by mutableFloatStateOf(0f)
        var under = 0
        rule.setContent {
            Box(Modifier.fillMaxSize()) {
                Box(Modifier.fillMaxSize().testTag("under").clickable { under++ })
                SoundPanel({ t }, visible, PageState(family = "FX"), RecCore(ed), null, { visible = false }, Modifier.align(Alignment.TopEnd))
            }
        }
        val right = { rule.onNodeWithTag("under").performTouchInput { click(Offset(width - 60f, height / 2f)) } }
        right(); rule.waitForIdle(); assertEquals("never shown: the tap reaches what's under", 1, under)
        visible = true; t = 1f; rule.waitForIdle()
        rule.onNode(androidx.compose.ui.test.hasContentDescription("Close the sound panel")).assertExists()
        right(); rule.waitForIdle(); assertEquals("open: the panel takes the tap", 1, under)
        visible = false; t = 0f; rule.waitForIdle()
        right(); rule.waitForIdle(); assertEquals("closed (still built): the tap reaches what's under", 2, under)
        rule.onNode(androidx.compose.ui.test.hasContentDescription("Close the sound panel")).assertDoesNotExist()   // hidden from TalkBack too
        visible = true; t = 1f; rule.waitForIdle()
        rule.onNode(androidx.compose.ui.test.hasContentDescription("Close the sound panel")).assertExists()
        right(); rule.waitForIdle(); assertEquals("open again: the panel takes it", 2, under)
    }

    @Test fun editComesToRestAfterTheSoundPanelDocksAndLeaves() {
        var dock by mutableStateOf(0.dp)
        rule.setContent { EditTab(ed, RecCore(ed), AutomationState(), StepPick().apply { step = 0 }, EditUi(), soundDock = dock) }
        rule.waitForIdle()
        dock = 360.dp
        rule.waitForIdle()                // throws if Edit never comes to rest
        dock = 0.dp
        rule.waitForIdle()
    }
}

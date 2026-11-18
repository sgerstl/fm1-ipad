package com.scottgerstl.lupe

import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
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
import com.scottgerstl.lupe.ui.shell.SOUND_DOCK_W
import com.scottgerstl.lupe.ui.shell.StepPick
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** At the Pixel 10 Pro's page width (about 868 dp with the sound keys rail), Edit's pattern bar keeps every key whole beside the wider sound panel. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w868dp-h360dp-land-mdpi", application = android.app.Application::class)
class DockFitTest {
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
    private val ed = EditorState(track = 1, trackName = "Lofi · Piano", entry = "A", pattern = 21, steps = (0 until 16).map { Step() }, patternSteps = 48)

    @Test fun thePatternBarFitsBesideTheSoundPanel() {
        rule.setContent { EditTab(ed, RecCore(ed), AutomationState(), StepPick().apply { step = 0 }, EditUi(), soundDock = SOUND_DOCK_W) }
        rule.waitForIdle()
        val root = rule.onRoot().fetchSemanticsNode().boundsInRoot
        val dockLeft = root.right - SOUND_DOCK_W.value - 8f
        for (k in listOf("Step 1 panel", "Follow the playhead", "Chord", "Automation lane", "Pattern length", "Undo")) {
            val b = rule.onNode(hasContentDescription(k, substring = true)).fetchSemanticsNode().boundsInRoot
            println("FIT $k ${b.left}..${b.right} (dock at $dockLeft)")
            assertTrue("$k ends before the dock: ${b.right} <= $dockLeft", b.right <= dockLeft + 0.5f)
            assertTrue("$k keeps its width", b.width >= 40f)
        }
    }
}

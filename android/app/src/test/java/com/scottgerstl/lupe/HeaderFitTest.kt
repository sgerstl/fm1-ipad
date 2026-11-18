package com.scottgerstl.lupe

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.audio.AudioThrough
import com.scottgerstl.lupe.audio.LocalAudioThrough
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.FreeTakeState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.core.TakeOffer
import com.scottgerstl.lupe.core.TopState
import com.scottgerstl.lupe.ui.shell.TopBar
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.TestScope
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

/**
 * The header with the speaker key (Scott, 2026-11-18) and the FREE TAKE chip both showing, a long project name and launches waiting: every
 * piece in order, none overlapping, all inside the width. The Pixel 10 Pro's landscape width less a cutout, and the give-way's last step.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w952dp-h427dp-land-xxhdpi")
class HeaderFitTest {
    @get:Rule val rule = createComposeRule()

    private fun core(): LupeCore {
        val dir = File("../fixtures/state")
        val scenarios = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        val fake = FakeLupeCore(TestScope(), scenarios, "searching")
        return object : LupeCore by fake {
            override val freeTake: StateFlow<FreeTakeState> = MutableStateFlow(FreeTakeState(TakeOffer(3, "Analog", 12)))
        }
    }

    private fun fits(widthDp: Int) {
        val c = core()
        val through = AudioThrough(RuntimeEnvironment.getApplication(), null)
        rule.setContent {
            CompositionLocalProvider(LocalAudioThrough provides through) {
                Box(Modifier.width(widthDp.dp)) { TopBar(TopState(project = "SUMMER JAM 2", waiting = 3, playing = true, bar = 128, beat = 4), c, Tab.Pads, {}) }
            }
        }
        rule.waitForIdle()
        val d = rule.density.density
        fun at(desc: String): Rect = rule.onNode(hasContentDescription(desc, substring = true)).fetchSemanticsNode().boundsInRoot
        val order = listOf("Song menu", "Pads", "Mix", "Play through the phone", "Launch at", "beats per minute", "Played phrase", "Record", "Stop")
        val rects = order.map { it to at(it) }
        rects.zipWithNext().forEach { (a, b) ->
            assertTrue("${a.first} (${a.second.right / d}) runs into ${b.first} (${b.second.left / d}) at $widthDp dp", a.second.right <= b.second.left + 0.5f)
        }
        assertTrue("Stop past the edge at $widthDp dp", rects.last().second.right <= widthDp * d + 0.5f)
    }

    @Test fun pixelLandscape() = fits(880)
    @Test fun narrowestGiveWay() = fits(700)
}

package com.scottgerstl.lupe

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.shell.TabPager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Tab changes (2026-11-18): the page showing moves into the outgoing slot rather than being built again, and the clock starts after the first frame. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
class TabPagerTest {
    @get:Rule val rule = createComposeRule()

    @Test fun theOutgoingPageIsMovedNotRebuilt() {
        var tab by mutableStateOf(Tab.Pads)
        val built = mutableMapOf<Tab, Int>()
        rule.setContent { TabPager(tab, Color.Red, 380) { t -> remember { built[t] = (built[t] ?: 0) + 1; 0 }; Box(Modifier.fillMaxSize()) } }
        rule.waitForIdle()
        assertEquals(1, built[Tab.Pads])
        tab = Tab.Mix
        rule.waitForIdle()                                         // the whole switch, Pads fading out in the outgoing slot
        assertEquals("Pads moved into the outgoing slot, not built again", 1, built[Tab.Pads])
        assertEquals(1, built[Tab.Mix])
    }

    @Test fun theClockStartsAfterTheSwitchsFirstFrame() {
        var tab by mutableStateOf(Tab.Pads)
        var startedAtFrame = -1; var frame = 0
        rule.mainClock.autoAdvance = false
        rule.setContent { TabPager(tab, Color.Red, 380, onMotionStart = { startedAtFrame = frame }) { Box(Modifier.fillMaxSize()) } }
        rule.mainClock.advanceTimeBy(100)
        tab = Tab.Edit; Snapshot.sendApplyNotifications()
        repeat(6) { frame++; rule.mainClock.advanceTimeByFrame() }
        assertTrue("motion started only after the switch's first frame (started on frame $startedAtFrame)", startedAtFrame >= 3)
    }
}

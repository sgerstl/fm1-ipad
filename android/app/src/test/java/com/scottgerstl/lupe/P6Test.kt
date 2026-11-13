package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.AutomationDraw
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.ui.timeline.MockTimeline
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Timeline's stand-in keeps the rules a core enforces (no overlap on a track), and drawing on a lane writes locks. */
@OptIn(ExperimentalCoroutinesApi::class)
class P6Test {
    @Test fun aBlockMovesAndStretchesOnlyWithinItsGap() {
        val t = MockTimeline()
        // track 1: blocks at 0–4, 4–8 (id 2) and 8–16; id 2 can't move or grow into its neighbours
        t.actions.move(2, 6); assertEquals(4, t.ui.blocks.first { it.id == 2 }.start)
        t.actions.resize(2, 9); assertEquals(4, t.ui.blocks.first { it.id == 2 }.bars)
        t.actions.resize(1, 2); assertEquals(2, t.ui.blocks.first { it.id == 1 }.bars)       // shorter is free
        t.actions.move(1, 2); assertEquals(2, t.ui.blocks.first { it.id == 1 }.start)         // and then it has room to move (gap 0–4)
    }

    @Test fun duplicateNeedsRoomAndDeleteLeavesAGap() {
        val t = MockTimeline()
        val before = t.ui.blocks.size
        t.actions.duplicate(3)                                   // 8–16 on track 1: the copy would start at 16, past the end: room
        assertEquals(before + 1, t.ui.blocks.size)
        t.actions.duplicate(1)                                   // 0–4 would copy into 4–8: refused
        assertEquals(before + 1, t.ui.blocks.size)
        t.actions.delete(2)
        assertTrue(t.ui.blocks.none { it.id == 2 })
        t.actions.duplicate(1); assertEquals(before + 1, t.ui.blocks.size)   // the gap now fits it
    }

    @Test fun drawingALaneWritesLocksStepByStep() = runTest(StandardTestDispatcher()) {
        val dir = File("../fixtures/state")
        val scenarios = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        val core = FakeLupeCore(this, scenarios, "searching"); testScheduler.advanceTimeBy(10)
        val lane = core.editor.value.lane
        for (step in 11..14) core.send(AutomationDraw(step, lane, 80 - (step - 11) * 20))
        for (step in 11..14) assertTrue(core.editor.value.steps[step].values.any { it.param == lane && it.locked })
        assertTrue(core.editor.value.laneValues[14] in 18..20)                          // the lane follows what was drawn (20 of 100, through the FM-1's 0–127)
    }
}

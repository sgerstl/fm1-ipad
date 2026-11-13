package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.BlockDelete
import com.scottgerstl.lupe.core.BlockDuplicate
import com.scottgerstl.lupe.core.BlockMove
import com.scottgerstl.lupe.core.BlockSetPattern
import com.scottgerstl.lupe.core.BlockStretch
import com.scottgerstl.lupe.core.DrawLane
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.FakeP6
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.ui.timeline.toUi
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The fake's answers for P6's areas copy P1's core (P6State.kt): a song is a list of blocks played back to back. */
@OptIn(ExperimentalCoroutinesApi::class)
class P6Test {
    private fun core(scope: kotlinx.coroutines.test.TestScope): FakeLupeCore {
        val dir = File("../fixtures/state")
        val scenarios = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        return FakeLupeCore(scope, scenarios, "searching").also { scope.testScheduler.advanceTimeBy(10) }
    }

    @Test fun aBlocksPlaceInTimeIsWhereTheOnesBeforeItEnd() = runTest(StandardTestDispatcher()) {
        val t = core(this).timeline.value.tracks[0]
        var at = 0.0
        for (b in t.blocks) { assertEquals(at, b.startBar, 0.0001); at += b.lengthBars }
        assertEquals(at, t.endBar, 0.0001)
    }

    @Test fun moveReordersAndStretchSetsReps() {
        var s = FakeP6.seedTimeline(com.scottgerstl.lupe.core.PadsState(rows = listOf(com.scottgerstl.lupe.core.PadRow(1, "Acid", entries = listOf(
            com.scottgerstl.lupe.core.PadEntry(com.scottgerstl.lupe.core.PadKind.Pattern, 5, passes = 4), com.scottgerstl.lupe.core.PadEntry(com.scottgerstl.lupe.core.PadKind.Pattern, 7, passes = 8))))))
        val first = s.tracks[0].blocks
        assertEquals(listOf(5, 7), first.map { it.pattern }); assertEquals(4.0, first[1].startBar, 0.0001)
        s = FakeP6.timeline(s, BlockMove(1, 0, 1))                       // the first one moves a place later
        assertEquals(listOf(7, 5), s.tracks[0].blocks.map { it.pattern }); assertEquals(8.0, s.tracks[0].blocks[1].startBar, 0.0001)
        s = FakeP6.timeline(s, BlockStretch(1, 1, 2))
        assertEquals(2, s.tracks[0].blocks[1].reps); assertEquals(10.0, s.bars, 0.0001)
    }

    @Test fun deleteOfAPatternUsedNowhereElseNeedsConfirmation() {
        var s = FakeP6.seedTimeline(com.scottgerstl.lupe.core.PadsState(rows = listOf(com.scottgerstl.lupe.core.PadRow(1, "Acid", entries = listOf(
            com.scottgerstl.lupe.core.PadEntry(com.scottgerstl.lupe.core.PadKind.Pattern, 5), com.scottgerstl.lupe.core.PadEntry(com.scottgerstl.lupe.core.PadKind.Pattern, 7))))))
        s = FakeP6.timeline(s, BlockDelete(1, 0)); assertEquals(2, s.tracks[0].blocks.size)               // refused: pattern 5 is used nowhere else
        s = FakeP6.timeline(s, BlockDelete(1, 0, confirmed = true)); assertEquals(listOf(7), s.tracks[0].blocks.map { it.pattern })
        s = FakeP6.timeline(s, BlockDuplicate(1, 0)); assertEquals(2, s.tracks[0].blocks.size)
        s = FakeP6.timeline(s, BlockSetPattern(1, 1, 9)); assertEquals(9, s.tracks[0].blocks[1].pattern)
        assertEquals(mapOf(7 to 1, 9 to 1), s.toUi(null, 1).uses)
    }

    @Test fun drawingOverRecordedChangesNeedsConfirmation() = runTest(StandardTestDispatcher()) {
        val c = core(this)
        val lane = c.automation.value.lane
        c.send(DrawLane(lane, 11, listOf(100, 80, 60, 40), lock = true))                              // nothing recorded yet: draws
        assertTrue(c.automation.value.points.slice(11..14).all { it.source == "lock" })
        assertEquals(7, c.automation.value.lanes.first { it.param == lane }.locks)      // the pattern had 3 CUTOFF locks, now 4 more
    }

    @Test fun drawingOnAStepShowingRecordedDataNeedsConfirmation() = runTest(StandardTestDispatcher()) {
        val c = core(this)
        // pattern 12: RESONANCE is recorded at step 6 (held through the steps after it)
        c.send(com.scottgerstl.lupe.core.AutomationLanePick("RESONANCE"))
        assertEquals("recorded", c.automation.value.points[7].source)
        c.send(DrawLane("RESONANCE", 7, listOf(100), lock = true))                              // refused
        assertEquals("recorded", c.automation.value.points[7].source)
        c.send(DrawLane("RESONANCE", 7, listOf(100), lock = true, confirmed = true))
        assertEquals("lock", c.automation.value.points[7].source)
    }
}

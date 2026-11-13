package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LockMode
import com.scottgerstl.lupe.core.PadPlay
import com.scottgerstl.lupe.core.Scenario
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** What the fake answers, so the P3 screens can be driven by hand and the real core has something to match. */
@OptIn(ExperimentalCoroutinesApi::class)
class FakeLupeCoreTest {
    private fun fake(scope: TestScope): FakeLupeCore {
        val dir = File("../fixtures/state")
        val scenarios = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        return FakeLupeCore(scope, scenarios, "searching").also { scope.testScheduler.advanceTimeBy(10) }
    }

    @Test fun launchWaitsWhilePlayingAndCountsInTheTopBar() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.Play); advanceTimeBy(10)
        core.send(Intent.PadTap(1, 1)) // B07 on track 1, playing A05
        val row = core.pads.value.rows[0]
        assertEquals(PadPlay.Waiting, row.entries[1].play)
        assertEquals(PadPlay.Playing, row.entries[0].play)
        assertEquals(2, core.top.value.waiting) // the fixture's C14 waits too
        core.send(Intent.PadTap(1, 1)) // a waiting pad tapped takes the launch back
        assertEquals(PadPlay.Idle, core.pads.value.rows[0].entries[1].play)
        core.send(Intent.Stop)
    }

    @Test fun launchWhenStoppedTakesOverAtOnce() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.PadTap(1, 1))
        val e = core.pads.value.rows[0].entries
        assertEquals(PadPlay.Playing, e[1].play); assertEquals(PadPlay.Idle, e[0].play)
    }

    @Test fun holdingAStepLocksAKnobTurnToIt() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.StepHold(2, true))
        assertEquals(LockMode.Held, core.editor.value.lock)
        core.fm1Knob(1, 3)
        assertTrue(core.editor.value.steps[2].values.any { it.param == "CUTOFF" && it.locked && it.value == 72 })
        core.send(Intent.StepHold(2, false))
        assertEquals(LockMode.Off, core.editor.value.lock)
        core.send(Intent.LocksClearAll(2))
        assertTrue(core.editor.value.steps[2].values.none { it.locked })
        // one lock at a time
        core.send(Intent.LockClear(5, "CUTOFF"))
        assertEquals(listOf("DECAY", "RESONANCE"), core.editor.value.steps[5].values.map { it.param })
    }

    @Test fun fm1KeyEntersTheNoteAndChordAdds() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.StepSelect(1))
        core.fm1Key(60)
        assertEquals("C4", core.editor.value.steps[1].note)
        assertEquals(2, core.editor.value.selected) // the cursor moves on
        core.send(Intent.StepSelect(1)); core.send(Intent.ChordToggle); core.fm1Key(63)
        assertEquals(1, core.editor.value.steps[1].extra)
    }

    @Test fun selectingAnotherPadLoadsItsOwnPattern() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.PadSelect(4, 0))
        assertEquals("Drum Kit", core.editor.value.trackName)
        assertEquals(1, core.editor.value.pattern)
        assertEquals(4, core.pads.value.selected.track)
    }

    @Test fun noteNamesUseSloopKitsSharpSign() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.StepSelect(3)); core.fm1Key(61)
        assertEquals("C♯4", core.editor.value.steps[3].note)
        core.send(Intent.StepSelect(3)); core.send(Intent.StepAdjust(com.scottgerstl.lupe.core.StepField.Pitch, 1))
        assertEquals("D4", core.editor.value.steps[3].note)
    }

    @Test fun storingOverAKeptSceneNeedsConfirmation() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.PadTap(1, 1))                       // what plays now
        core.send(Intent.SceneStore(0))                      // scene 1 is kept: refused
        core.send(Intent.SceneRecall(0)); assertEquals(PadPlay.Playing, core.pads.value.rows[0].entries[0].play) // still the old snapshot
        core.send(Intent.PadTap(1, 1))                       // what plays now, again
        core.send(Intent.SceneStore(0, confirmed = true))
        core.send(Intent.PadTap(1, 0)); core.send(Intent.SceneRecall(0))
        assertEquals(PadPlay.Playing, core.pads.value.rows[0].entries[1].play)   // now the new one
        core.send(Intent.SceneStore(10))                     // an empty scene stores at once
        assertTrue(core.pads.value.scenes[10].stored)
    }

    @Test fun lengthStopsAtTheNextNote() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        core.send(Intent.StepSelect(0))                       // pattern 12: step 1 holds C4, the next note is on step 3
        assertEquals(2, core.editor.value.steps[0].maxLength)
        core.send(Intent.StepAdjust(com.scottgerstl.lupe.core.StepField.Length, 5))
        assertEquals(2, core.editor.value.steps[0].length)
    }

    @Test fun aStepInsideANotesLengthSaysWhoHoldsIt() = runTest(StandardTestDispatcher()) {
        val core = fake(this)
        // pattern 12: C4 on step 1 has length 2, so step 2 holds it; step 4 (empty, outside any note) doesn't
        assertEquals(0, core.editor.value.steps[1].heldFrom)
        assertEquals(-1, core.editor.value.steps[3].heldFrom)
    }
}

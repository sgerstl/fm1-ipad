package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.Step
import com.scottgerstl.lupe.core.StepHit
import com.scottgerstl.lupe.ui.shell.firstHit
import com.scottgerstl.lupe.ui.shell.laneHitSteps
import com.scottgerstl.lupe.ui.shell.nextHit
import com.scottgerstl.lupe.ui.shell.prevHit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** A drum hit's step panel (Scott, 2026-11-18): the Step key on kits, ‹ › through a lane's hits. */
class DrumStepPanelTest {
    private fun kit(vararg hits: Pair<Int, Int>) = EditorState(kitLanes = listOf("BD", "SD", "CH"),
        steps = (0 until 16).map { i -> val hs = hits.filter { it.second == i }.map { StepHit(it.first) }; Step(on = hs.isNotEmpty(), hits = hs) })

    @Test fun laneHitsStepRound() {
        val ed = kit(0 to 0, 1 to 4, 0 to 8, 0 to 12)
        val bd = laneHitSteps(ed, 0)
        assertEquals(listOf(0, 8, 12), bd)
        assertEquals(12, nextHit(bd, 8)); assertEquals(0, nextHit(bd, 12))   // round to the first
        assertEquals(0, prevHit(bd, 8)); assertEquals(12, prevHit(bd, 0))
        assertNull(nextHit(emptyList(), 3))
    }

    @Test fun theStepKeyOpensOnTheFirstHit() {
        assertEquals("SD" to 4, firstHit(kit(1 to 4, 0 to 8)))
        assertNull(firstHit(kit()))
    }
}

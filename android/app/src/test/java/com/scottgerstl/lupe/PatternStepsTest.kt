package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.core.SetPatternSteps
import com.scottgerstl.lupe.core.lupeJson
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/** The pattern's step count (batch item 9): the intent's wire form, and the fake resizing the pattern the way the FM-1's LENGTH does. */
@OptIn(ExperimentalCoroutinesApi::class)
class PatternStepsTest {
    private fun fake(scope: TestScope, name: String): FakeLupeCore {
        val scenarios = File("../fixtures/state").listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        return FakeLupeCore(scope.backgroundScope, scenarios, name).also { scope.testScheduler.advanceTimeBy(10) }
    }

    @Test fun theIntentEncodesAsThePhoneCoreReadsIt() {
        assertEquals("""{"intent":"setPatternSteps","steps":32}""", lupeJson.encodeToString(Intent.serializer(), SetPatternSteps(32)))
    }

    @Test fun anOldEditorFrameIsSixteenOfSixtyFour() {
        val e = lupeJson.decodeFromString(com.scottgerstl.lupe.core.EditorState.serializer(), """{"track":1}""")
        assertEquals(16, e.patternSteps); assertEquals(64, e.patternStepsMax)
    }

    @Test fun theFakeGrowsAndShrinksThePattern() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "drums")
        assertEquals(16, core.editor.value.patternSteps)
        core.send(SetPatternSteps(40))
        assertEquals(40, core.editor.value.patternSteps); assertEquals(40, core.editor.value.steps.size)
        core.send(SetPatternSteps(9999)); assertEquals(64, core.editor.value.steps.size)         // the FM-1's NSTEP
        core.send(SetPatternSteps(0)); assertEquals(1, core.editor.value.steps.size)             // never none
        core.send(SetPatternSteps(24)); assertEquals(24, core.editor.value.patternSteps)
        core.send(Intent.StepSelect(23)); assertEquals(23, core.editor.value.selected)           // a step past sixteen can be selected
    }
}

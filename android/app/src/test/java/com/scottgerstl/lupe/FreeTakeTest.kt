package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.FreeTakeState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.core.TakeBarsPick
import com.scottgerstl.lupe.core.TakeDismissLanded
import com.scottgerstl.lupe.core.TakeGuessPick
import com.scottgerstl.lupe.core.TakeKeep
import com.scottgerstl.lupe.core.TakePutBack
import com.scottgerstl.lupe.core.TakeStart
import com.scottgerstl.lupe.core.TakeUndo
import com.scottgerstl.lupe.core.lupeJson
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The FREE TAKE area: PhoneCore's recordings decode, the fake clicks through the picker, and the intents encode as the core expects. */
@OptIn(ExperimentalCoroutinesApi::class)
class FreeTakeTest {
    private val dir = File("../fixtures/state")
    private fun scenarios() = dir.listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
    private fun fake(scope: TestScope, name: String) = FakeLupeCore(scope.backgroundScope, scenarios(), name).also { scope.testScheduler.advanceTimeBy(10) }
    private fun last(name: String): FreeTakeState =
        lupeJson.decodeFromJsonElement(FreeTakeState.serializer(), Scenario.parse(name, File(dir, "$name.json").readText()).frames.last { it.area == "freetake" }.state)

    @Test fun theRecordedAreasDecode() {
        val offer = last("take-offer").offer!!
        assertEquals(5, offer.track); assertEquals(8, offer.notes); assertTrue(offer.canStart)
        val p = last("take-picker").picker!!
        assertEquals(listOf(96, 48, 192), p.guesses.map { it.bpm }); assertEquals(listOf("guess", "half", "double"), p.guesses.map { it.caption })
        assertEquals(2, p.barsIndex); assertEquals(64, p.length); assertTrue(p.notes.isNotEmpty())
        val l = last("take-landed").landed!!
        assertTrue(l.undoFromHere); assertEquals(false, l.undone)
    }

    @Test fun thePickerScenarioOpensOnTheShellsFreeTakeBottom() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "take-picker")
        assertEquals(BottomKind.FreeTake, core.shell.value.bottom.kind)
        assertNotNull(core.freeTake.value.picker)
    }

    @Test fun theFakeClicksThroughOfferPickerAndKeep() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "take-offer")
        assertNotNull(core.freeTake.value.offer)
        core.send(TakeStart)
        assertNull(core.freeTake.value.offer); assertNotNull(core.freeTake.value.picker)
        assertEquals(BottomKind.FreeTake, core.shell.value.bottom.kind)
        core.send(TakeGuessPick(2)); assertEquals(192, core.freeTake.value.picker!!.bpm)
        core.send(TakeBarsPick(0)); assertEquals(16, core.freeTake.value.picker!!.length)
        core.send(TakeKeep)
        assertNull(core.freeTake.value.picker); assertNotNull(core.freeTake.value.landed)
        assertEquals(BottomKind.Editor, core.shell.value.bottom.kind)
        core.send(TakeUndo); assertEquals(true, core.freeTake.value.landed!!.undone)
        core.send(TakeDismissLanded); assertNull(core.freeTake.value.landed)
    }

    @Test fun putBackLeavesNothing() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "take-offer")
        core.send(TakeStart); core.send(TakePutBack)
        assertNull(core.freeTake.value.picker); assertNull(core.freeTake.value.landed)
        assertEquals(BottomKind.Editor, core.shell.value.bottom.kind)
    }

    @Test fun intentsEncodeTheWayThePhoneCoreReadsThem() {
        fun enc(i: Intent) = lupeJson.encodeToString(Intent.serializer(), i)
        assertEquals("""{"intent":"takeStart"}""", enc(TakeStart))
        assertEquals("""{"intent":"takeGuess","index":2}""", enc(TakeGuessPick(2)))
        assertEquals("""{"intent":"takeKeep"}""", enc(TakeKeep))
    }
}

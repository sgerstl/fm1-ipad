package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.PickPage
import com.scottgerstl.lupe.core.PickRoute
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.core.SetParam
import com.scottgerstl.lupe.core.lupeJson
import java.io.File
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The page area through the fake: a scenario puts the shell on a page, intents change the numbers, and the encoding is stable. */
@OptIn(ExperimentalCoroutinesApi::class)
class FakePagesTest {
    private fun fake(scope: TestScope, name: String): FakeLupeCore {
        val scenarios = File("../fixtures/state").listFiles { f -> f.extension == "json" }!!.associate { it.nameWithoutExtension to Scenario.parse(it.nameWithoutExtension, it.readText()) }
        return FakeLupeCore(scope.backgroundScope, scenarios, name).also { scope.testScheduler.advanceTimeBy(10) }
    }

    @Test fun envScenarioPutsTheShellOnTheEnvPage() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "page-env")
        assertEquals(BottomKind.Page, core.shell.value.bottom.kind)
        assertEquals("ENV", core.page.value.family)
        assertEquals(4, core.page.value.controls.size)
    }

    @Test fun setParamMovesTheNumber() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "page-env")
        val max = core.page.value.controls[1]!!.max
        core.send(SetParam(1, 100))
        assertEquals(100, core.page.value.controls[1]!!.raw)
        core.send(SetParam(1, 999))
        assertEquals(max, core.page.value.controls[1]!!.raw)   // clamped to the control's range
    }

    @Test fun pickPageSwitchesToAKnownPageAndFollowsInTheShell() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "page-env")
        core.send(PickPage("ENV", 1))
        assertEquals(1, core.page.value.page)
        assertEquals("ENV 2", core.shell.value.bottom.page)
        core.send(PickPage("FX"))      // a family the scenario never showed: built from the map (FakePageMap)
        assertEquals("FX", core.page.value.family)
        assertEquals(listOf("DIST", "CHORUS", "DELAY", "REVERB"), core.page.value.controls.map { it!!.label })
        assertTrue(core.page.value.trackName.isNotEmpty())
        for (family in listOf("LFO", "SEL", "EDIT", "ARP")) {       // every family key opens a filled page, with the track's name
            core.send(PickPage(family))
            val p = core.page.value
            assertTrue("$family has controls", p.controls.any { it != null })
            assertTrue("$family has a name", p.trackName.isNotEmpty())
        }
    }

    @Test fun modRoutePickMovesTheTile() = runTest(StandardTestDispatcher()) {
        val core = fake(this, "page-env")
        core.send(PickPage("LFO", 4))    // MOD, built from the map: its eleven routes as tiles
        assertEquals("routes", core.page.value.tiles!!.kind)
        core.send(PickRoute(5))
        assertEquals(5, core.page.value.tiles!!.picked)
    }

    @Test fun theRecordedSheetsCarryTheirTilesWindowAndTitle() = runTest(StandardTestDispatcher()) {
        val op = fake(this, "page-operator").page.value
        assertTrue(op.title.startsWith("OPERATOR")); assertEquals("pick", op.tiles!!.kind); assertTrue(op.window != null); assertTrue(op.controls.any { it != null })
        val mod = fake(this, "page-mod").page.value
        assertEquals("routes", mod.tiles!!.kind); assertEquals(11, mod.tiles!!.routes.size)
    }

    @Test fun theNewPageShapeDecodes() {
        val s = lupeJson.decodeFromString(com.scottgerstl.lupe.core.PageState.serializer(),
            """{"family":"EDIT","title":"OPERATOR 4","controls":[{"label":"RATE 1","value":"99"},null,null,null],"tiles":{"kind":"pick","labels":["OP1","OP2","OP3","OP4"],"picked":3,"routes":[]},"window":{"count":5,"index":1,"title":"ENV 1"}}""")
        assertEquals("OPERATOR 4", s.title); assertEquals(3, s.tiles!!.picked); assertEquals("ENV 1", s.window!!.title)
    }

    @Test fun emptyWellsSurviveTheRoundTrip() {
        val s = lupeJson.decodeFromString(com.scottgerstl.lupe.core.PageState.serializer(), """{"family":"FX","controls":[{"label":"DIST","value":"72"},null,null,null]}""")
        assertNull(s.controls[1]); assertEquals(4, s.controls.size)
        assertEquals("""{"intent":"setParam","slot":2,"value":64}""", lupeJson.encodeToString(com.scottgerstl.lupe.core.Intent.serializer(), SetParam(2, 64)))
    }

    /** Page numbers above the driver are Skiff 2.2's (SkiffPageMap): 41-45 are NOTES, FEEL, PATTERN, AUTOMATION and SONG, so no sound page may use them. */
    @Test fun noSoundPageNumberCollidesWithTheSeqPages() {
        val files = File("../fixtures/state").listFiles { f -> f.name.startsWith("page-") && f.extension == "json" }!!
        for (f in files) for (fr in Scenario.parse(f.nameWithoutExtension, f.readText()).frames.filter { it.area == "page" }) {
            val p = lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.PageState.serializer(), fr.state)
            for (r in p.pages) assertTrue("${f.name}: ${r.title} is page ${r.index}", r.index !in 41..45)
        }
        val fx = lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.PageState.serializer(),
            Scenario.parse("d", File("../fixtures/state/page-drive.json").readText()).frames.last { it.area == "page" }.state).pages
        assertEquals(46, fx.first { it.title == "DELAY" }.index); assertEquals(47, fx.first { it.title == "REVERB" }.index)
    }

    /** What Swift's shell area carries: only the bottom half (BridgedLupeCore merges it in; tab and divider stay Kotlin's). */
    @Test fun shellBottomFromSwiftDecodes() {
        val b = lupeJson.decodeFromString(com.scottgerstl.lupe.core.ShellBottom.serializer(), """{"bottom":{"family":"ENV","kind":"page","page":"ENV 2"}}""").bottom
        assertEquals(BottomKind.Page, b.kind); assertEquals("ENV", b.family); assertEquals("ENV 2", b.page)
        val e = lupeJson.decodeFromString(com.scottgerstl.lupe.core.ShellBottom.serializer(), """{"bottom":{"kind":"editor"}}""").bottom
        assertEquals(BottomKind.Editor, e.kind)
    }
}

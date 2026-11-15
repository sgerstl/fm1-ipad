package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.lupeJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The page fixtures can't carry another page's knobs. Added after Scott's run (2026-11-13): page-drive.json's
 * DELAY frame held DRIVE's TYPE, and the scenario opened on DELAY. Labels are SloopKit's (SkiffPages.specs for
 * Skiff 2.5.1, knobLabels where the FM-1 names a knob apart from DESC); pages not listed here aren't checked.
 */
class PageFixturesTest {
    private val dir = File("../fixtures/state")

    private val knobs: Map<String, List<String?>> = mapOf(
        "ENV" to listOf("ATTACK", "DECAY", "SUSTAIN", "RELEASE"),
        "LFO" to listOf("RATE", "WAVE", "PHASE", "FADE"),
        "FX" to listOf("DIST", "CHORUS", "DELAY", "REVERB"),
        "DELAY" to listOf("SEND", "TIME", "FEEDBACK", "COLOR"),
        "REVERB" to listOf("SEND", "TYPE", "SIZE", "DAMP"),
        "DRIVE" to listOf("DIST", "TYPE", "TONE", null),
        "SCALE" to listOf("ROOT", "SCALE", "QUANTIZE", "TRANSP"),
        "ARP" to listOf("MODE", "RATE", "OCTAVE", "GATE"),
        "ARP 2" to listOf("SWING", "CHANCE", "HOLD", "ORDER"),
    )

    private fun pageFiles() = dir.listFiles { f -> f.name.startsWith("page-") && f.name.endsWith(".json") }.orEmpty().sorted()

    @Test fun everyPageCarriesItsOwnKnobs() {
        assertTrue(pageFiles().isNotEmpty())
        var checked = 0
        for (f in pageFiles()) {
            val s = Scenario.parse(f.name, f.readText())
            for (fr in s.frames.filter { it.area == "page" }) {
                val p = lupeJson.decodeFromJsonElement(PageState.serializer(), fr.state)
                val title = p.pages.firstOrNull { it.index == p.page }?.title ?: continue
                val want = knobs[title] ?: continue
                assertEquals("${f.name}: page ${p.page} $title", want, p.controls.map { it?.label })
                checked++
            }
        }
        assertTrue("no page checked", checked > 0)
    }

    @Test fun eachScenarioOpensOnThePageItLastShows() {
        for (f in pageFiles()) {
            val s = Scenario.parse(f.name, f.readText())
            val shell = s.frames.lastOrNull { it.area == "shell" }?.let { lupeJson.decodeFromJsonElement(ShellState.serializer(), it.state) } ?: continue
            val last = s.frames.lastOrNull { it.area == "page" }?.let { lupeJson.decodeFromJsonElement(PageState.serializer(), it.state) } ?: continue
            val title = last.pages.firstOrNull { it.index == last.page }?.title
            assertEquals("${f.name}: the shell's page and the last page frame", title, shell.bottom.page)
        }
    }
}

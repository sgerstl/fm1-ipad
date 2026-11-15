package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkPhase
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.ProjectsState
import com.scottgerstl.lupe.core.SoundsState
import com.scottgerstl.lupe.core.MixState
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.Scenario
import com.scottgerstl.lupe.core.TopState
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.core.lupeJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Every recording in android/fixtures/state decodes into the Kotlin areas: a renamed field fails here, not on a screen. */
class FixturesTest {
    private val dir = File("../fixtures/state")

    @Test fun everyFixtureDecodes() {
        val files = dir.listFiles { f -> f.extension == "json" }!!
        assertTrue(files.size >= 5)
        for (f in files) {
            val s = Scenario.parse(f.nameWithoutExtension, f.readText())
            assertTrue("${f.name} has frames", s.frames.isNotEmpty())
            for (fr in s.frames) when (fr.area) {
                "link" -> lupeJson.decodeFromJsonElement(LinkState.serializer(), fr.state)
                "top" -> lupeJson.decodeFromJsonElement(TopState.serializer(), fr.state)
                "shell" -> lupeJson.decodeFromJsonElement(ShellState.serializer(), fr.state)
                "pads" -> assertEquals(6, lupeJson.decodeFromJsonElement(PadsState.serializer(), fr.state).rows.size)
                "page" -> { val p = lupeJson.decodeFromJsonElement(PageState.serializer(), fr.state); assertEquals("${f.name}: four controls", 4, p.controls.size); assertTrue(p.pages.any { it.index == p.page }) }
                // every step of the pattern in whole 16-step chunks (Scott, 2026-11-15: the Edit grid scrolls by chunk)
                "editor" -> assertTrue("${f.name}: editor steps", lupeJson.decodeFromJsonElement(EditorState.serializer(), fr.state).steps.size in setOf(16, 32, 48, 64))
                "mix" -> assertEquals(6, lupeJson.decodeFromJsonElement(MixState.serializer(), fr.state).rows.size)
                "sounds" -> assertEquals(32, lupeJson.decodeFromJsonElement(SoundsState.serializer(), fr.state).user.size)
                "meters" -> assertEquals(6, lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.MetersState.serializer(), fr.state).levels.size)
                "timeline" -> assertEquals(6, lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.TimelineState.serializer(), fr.state).tracks.size)
                "automation" -> { val a = lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.AutomationState.serializer(), fr.state); assertTrue(a.lane.isEmpty() || a.points.size == a.steps) }
                "projects" -> assertEquals(4, lupeJson.decodeFromJsonElement(ProjectsState.serializer(), fr.state).slots.size)
                "freetake" -> lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.FreeTakeState.serializer(), fr.state)
                // P1's clock reference (ClockArea.swift): no Kotlin class yet (P2's to add), so only its shape is checked
                "clock" -> assertTrue("${f.name}: clock", (fr.state as kotlinx.serialization.json.JsonObject).containsKey("running"))
                "fm1Screen" -> { val sc = lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.Fm1ScreenState.serializer(), fr.state); assertTrue("${f.name}: ${sc.key}", sc.key in setOf("", "HOME", "FX", "SEL", "ENV", "LFO", "EDIT", "ARP", "GLO", "SAVE", "SEQ")) }
                "homeKnobs" -> { val h = lupeJson.decodeFromJsonElement(com.scottgerstl.lupe.core.HomeKnobsState.serializer(), fr.state); assertEquals("${f.name}: HOME's four", 4, h.controls.size); assertTrue(h.hot in -1..3) }
                // P1's Patterns sheet data (Patterns.swift, board 79): no Kotlin classes yet (P2's to add), so only their shape is checked
                "patterns" -> assertTrue("${f.name}: patterns", (fr.state as kotlinx.serialization.json.JsonObject).let { it.containsKey("patterns") && it.containsKey("free") })
                "patternPictures" -> assertTrue("${f.name}: patternPictures", (fr.state as kotlinx.serialization.json.JsonObject).containsKey("pictures"))
                "notice" -> assertTrue("${f.name}: notice", (fr.state as kotlinx.serialization.json.JsonObject).containsKey("text"))
                else -> error("${f.name}: unknown area ${fr.area}")
            }
        }
    }

    @Test fun wrongFirmwareCarriesItsVersion() {
        val s = Scenario.parse("w", File(dir, "wrongFirmware.json").readText())
        // P1's recording (PhoneCore over FakeSloop reporting 2.9.0, as SloopKit's refusesOtherFirmware test)
        val last = lupeJson.decodeFromJsonElement(LinkState.serializer(), s.frames.last { it.area == "link" }.state)
        assertEquals(LinkPhase.WrongFirmware, last.phase)
        assertEquals("FELUCCA SLOOP 2.9.0", last.firmware)
    }

    @Test fun intentsEncodeWithTheirDiscriminator() {
        assertEquals("""{"intent":"setTempo","bpm":128.0}""", lupeJson.encodeToString(Intent.serializer(), Intent.SetTempo(128.0)))
        assertEquals("""{"intent":"play"}""", lupeJson.encodeToString(Intent.serializer(), Intent.Play))
    }
}

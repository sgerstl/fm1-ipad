package com.scottgerstl.lupe

import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkPhase
import com.scottgerstl.lupe.core.PageState
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
                "editor" -> assertEquals(16, lupeJson.decodeFromJsonElement(EditorState.serializer(), fr.state).steps.size)
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

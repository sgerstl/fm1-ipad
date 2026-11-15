package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.shell.holdIcon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Every choice in the pad, head and block menus has an icon, each drawable exists, and the mapping table in HoldIcons.kt names the same glyphs. */
class HoldIconsTest {
    private val choices = listOf(
        "Edit steps", "Select sound", "Sounds…", "Set pattern…", "Pick a pattern…", "Pattern 03", "New pattern", "Rest", "REST", "Play once more",
        "Play once less", "Duplicate after", "Duplicate", "Move earlier", "Move later", "Clear", "Delete…", "Erase user slot 3…", "Clear 12 unused patterns…",
        "No unused patterns", "Chain with the next", "Split the chain", "Insert before…", "Add a pattern…", "Add a REST", "Passes…", "Mute", "Solo", "LEVEL", "PAN",
    )

    @Test fun everyChoiceHasAnIcon() { choices.forEach { assertNotNull(it, holdIcon(it)) } }

    @Test fun theLikelyConfusionsGoToTheRightGlyph() {
        assertEquals(holdIcon("Clear 5 unused patterns…"), holdIcon("No unused patterns"))
        assertTrue(holdIcon("Clear") != holdIcon("Clear 5 unused patterns…"))
        assertEquals(holdIcon("Clear"), holdIcon("Delete…"))
        assertEquals(holdIcon("Duplicate"), holdIcon("Duplicate after"))
        assertNull(holdIcon("Something with no glyph"))
    }

    /** Each vector drawable is Google's glyph unchanged: one path under the group that lifts its 0 -960 viewBox. */
    @Test fun theDrawablesAreTheGlyphsAndLicensed() {
        val dir = File("src/main/res/drawable")
        val files = dir.listFiles { f -> f.name.startsWith("ms_") }!!
        assertTrue(files.size >= 22)
        files.forEach { f ->
            val x = f.readText()
            assertTrue(f.name, "Material Symbols Rounded" in x && "Apache License 2.0" in x && "android:translateY=\"960\"" in x && x.count { it == '<' } >= 5)
            assertEquals(f.name, 1, Regex("<path ").findAll(x).count())
        }
        assertTrue(File("../THIRD_PARTY.md").readText().contains("Apache License"))
    }
}

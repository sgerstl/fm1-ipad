package com.scottgerstl.lupe

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.onNodeWithTag
import org.junit.Assert.assertEquals
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.unit.Density
import androidx.compose.ui.semantics.getOrNull
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.ui.settings.SettingsSheet
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.SheetHost
import com.scottgerstl.lupe.ui.sheet.SheetKind
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Settings at the Pixel 10 Pro's width (952 × 427 dp) and in portrait, at 200 % font: every option stays inside the 560 dp column. */
abstract class SettingsLayoutBase {
    @get:Rule val rule = createComposeRule()
    fun check(fontScale: Float, wide: Boolean) {
        rule.setContent {
            val d = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(d.density, fontScale), LocalSheetHost provides SheetHost().apply { show(SheetKind.Settings) }) { SettingsSheet(LinkState(), fake = true) }
        }
        rule.waitForIdle()
        val root = rule.onRoot().fetchSemanticsNode().boundsInRoot
        val options = rule.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.Role)).fetchSemanticsNodes()
            .filter { (it.config.getOrNull(SemanticsProperties.ContentDescription)?.firstOrNull() ?: "").contains(": ") }
        assertTrue("found the segmented options", options.isNotEmpty())
        // unclipped: rows scrolled out of the sheet's view report an empty clipped rect
        fun androidx.compose.ui.semantics.SemanticsNode.full() = androidx.compose.ui.geometry.Rect(positionInRoot, androidx.compose.ui.geometry.Size(size.width.toFloat(), size.height.toFloat()))
        val left = options.minOf { it.full().left }; val right = options.maxOf { it.full().right }
        val d = rule.density.density
        assertTrue("the column is at most 560 dp wide: ${(right - left) / d}", (right - left) / d <= 560.5f)
        // the sheet itself: 608 dp at most, centred, on a wide screen; full width on a narrow one (Scott, 2026-11-18)
        val sheet = rule.onNodeWithTag("lupe-sheet").fetchSemanticsNode().boundsInRoot
        if (wide) {
            assertEquals(608f, sheet.width / d, 0.5f)
            assertEquals((root.left + root.right) / 2, (sheet.left + sheet.right) / 2, 1f)
        } else assertEquals(root.width, sheet.width, 0.5f)
        options.forEach { assertTrue("${it.config.getOrNull(SemanticsProperties.ContentDescription)} inside the sheet: ${it.full()} vs $sheet", it.full().right <= sheet.right + 0.5f && it.full().left >= sheet.left - 0.5f) }
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w952dp-h427dp-land-xxhdpi", application = android.app.Application::class)
class SettingsLayoutLandscapeTest : SettingsLayoutBase() {
    @Test fun normalFont() = check(1f, wide = true)
    @Test fun largeFont() = check(2f, wide = true)
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w427dp-h952dp-port-xxhdpi", application = android.app.Application::class)
class SettingsLayoutPortraitTest : SettingsLayoutBase() {
    @Test fun largeFont() = check(2f, wide = false)
}

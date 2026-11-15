package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import com.scottgerstl.lupe.core.Tab

/**
 * Where each tab draws the selected track (Pads: its row; Edit: the step row; the Timeline: its row), in the tab page's own coordinates, so
 * the track's band can travel from one to the other while the pages slide (decision 29). A page that reports nothing is simply not
 * travelled to.
 */
class TrackAnchors {
    val rects = mutableStateMapOf<Tab, Rect>()
}

/** The page a composable is on: its box (to measure against, whatever the slide is doing to it) and where to report. Null outside the pager. */
class TabPage(val tab: Tab, val anchors: TrackAnchors) { var box: LayoutCoordinates? = null }

val LocalTabPage = compositionLocalOf<TabPage?> { null }

/** True while the pages are sliding: a page hides its own selected-track band then, because the travelling one stands in for it. */
val LocalTabTravelling = compositionLocalOf { false }

/** Marks this as where the page shows the selected track. Public so the Timeline (ui/timeline) can mark its row too. */
fun Modifier.selectedTrackAnchor(outset: androidx.compose.ui.unit.Dp = androidx.compose.ui.unit.Dp(0f)): Modifier = composed {
    val page = LocalTabPage.current ?: return@composed this
    val grow = with(androidx.compose.ui.platform.LocalDensity.current) { outset.toPx() }
    // [outset]: how far outside this box the page draws its outline, so the travelling one lands exactly on it
    onGloballyPositioned { c -> page.box?.takeIf { it.isAttached }?.let { page.anchors.rects[page.tab] = it.localBoundingBoxOf(c, clipBounds = false).inflate(grow) } }
}

/** How much of the track's colour the selected track's band takes over the page (decision 31, board 76): the same mix as the docked panel's tint. */
const val ROW_TINT = 0.28f

/** The selected track's band: its colour muted over the page, running under the whole row on Pads and the Timeline. The 2 dp outline is the launch timer's alone now. */
fun trackBand(colour: androidx.compose.ui.graphics.Color): androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.lerp(com.scottgerstl.lupe.ui.theme.Tok.page, colour, ROW_TINT)

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
 * the track's outline can travel from one to the other while the pages slide (decision 29). A page that reports nothing is simply not
 * travelled to.
 */
class TrackAnchors {
    val rects = mutableStateMapOf<Tab, Rect>()
}

/** The page a composable is on: its box (to measure against, whatever the slide is doing to it) and where to report. Null outside the pager. */
class TabPage(val tab: Tab, val anchors: TrackAnchors) { var box: LayoutCoordinates? = null }

val LocalTabPage = compositionLocalOf<TabPage?> { null }

/** True while the pages are sliding: a page hides its own selected-track outline then, because the travelling one stands in for it. */
val LocalTabTravelling = compositionLocalOf { false }

/** Marks this as where the page shows the selected track. Public so the Timeline (ui/timeline) can mark its row too. */
fun Modifier.selectedTrackAnchor(): Modifier = composed {
    val page = LocalTabPage.current ?: return@composed this
    onGloballyPositioned { c -> page.box?.takeIf { it.isAttached }?.let { page.anchors.rects[page.tab] = it.localBoundingBoxOf(c, clipBounds = false) } }
}

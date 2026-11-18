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
    /** Each place's corner radii (left, right, px); a negative left is half the height (a fully round end). The travelling band takes them. */
    val radii = mutableStateMapOf<Tab, Pair<Float, Float>>()
}

/** The selected track's band: [inset] is the even space between the band and the head pill (and the pads) inside it (2 dp: half the row gap). */
val BAND_INSET = androidx.compose.ui.unit.Dp(2f)

/** A band's left and right radii (px) for its [height]: [left] < 0 means a fully round end. */
fun bandRadii(height: Float, left: Float, right: Float): Pair<Float, Float> = (if (left < 0f) height / 2f else left).coerceAtMost(height / 2f) to right.coerceAtMost(height / 2f)

/**
 * Draws the band with its two ends' radii: the nested-corner rule (DESIGN.md: outer = inner + padding, Scott 2026-11-18). On Pads and the
 * Timeline the left end wraps the round head pill, so it is fully round; the right end wraps the last pad (or the lane) plus the inset.
 */
fun androidx.compose.ui.graphics.drawscope.DrawScope.drawBand(colour: androidx.compose.ui.graphics.Color, topLeft: androidx.compose.ui.geometry.Offset, size: androidx.compose.ui.geometry.Size, leftR: Float, rightR: Float) {
    val (l, r) = bandRadii(size.height, leftR, rightR)
    val lc = androidx.compose.ui.geometry.CornerRadius(l); val rc = androidx.compose.ui.geometry.CornerRadius(r)
    drawPath(androidx.compose.ui.graphics.Path().apply { addRoundRect(androidx.compose.ui.geometry.RoundRect(topLeft.x, topLeft.y, topLeft.x + size.width, topLeft.y + size.height, lc, rc, rc, lc)) }, colour)
}

/** The page a composable is on: its box (to measure against, whatever the slide is doing to it) and where to report. Null outside the pager. */
class TabPage(val tab: Tab, val anchors: TrackAnchors) { var box: LayoutCoordinates? = null }

val LocalTabPage = compositionLocalOf<TabPage?> { null }

/** True while the pages are sliding: a page hides its own selected-track band then, because the travelling one stands in for it. */
val LocalTabTravelling = compositionLocalOf { false }

/** Marks this as where the page shows the selected track. Public so the Timeline (ui/timeline) can mark its row too. */
fun Modifier.selectedTrackAnchor(outset: androidx.compose.ui.unit.Dp = androidx.compose.ui.unit.Dp(0f),
    /** The corner radii the page draws here (dp); a negative [leftR] is a fully round left end. */
    leftR: androidx.compose.ui.unit.Dp = androidx.compose.ui.unit.Dp(10f), rightR: androidx.compose.ui.unit.Dp = leftR): Modifier = composed {
    val page = LocalTabPage.current ?: return@composed this
    val d = androidx.compose.ui.platform.LocalDensity.current
    val grow = with(d) { outset.toPx() }
    val radii = with(d) { (if (leftR.value < 0f) -1f else leftR.toPx()) to rightR.toPx() }
    // [outset]: how far outside this box the page draws its outline, so the travelling one lands exactly on it
    onGloballyPositioned { c -> page.box?.takeIf { it.isAttached }?.let { page.anchors.rects[page.tab] = it.localBoundingBoxOf(c, clipBounds = false).inflate(grow); page.anchors.radii[page.tab] = radii } }
}

/** How much of the track's colour the selected track's band takes over the page (decision 31, board 76): the same mix as the docked panel's tint. */
const val ROW_TINT = 0.28f

/** The selected track's band: its colour muted over the page, running under the whole row on Pads and the Timeline. The 2 dp outline is the launch timer's alone now. */
fun trackBand(colour: androidx.compose.ui.graphics.Color): androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.lerp(com.scottgerstl.lupe.ui.theme.Tok.page, colour, ROW_TINT)


/** A selected track head's corner radius (Scott, 2026-11-18: "Square the outline"): the hybrid selectable rule, a pill unselected, 12 dp selected. */
val HEAD_SELECTED_R = androidx.compose.ui.unit.Dp(12f)
/** The head's radius (px) at shape spring [s] (0 a pill, 1 selected) for its [height]. */
fun headRadius(height: Float, selectedPx: Float, s: Float): Float = (height / 2f + (selectedPx - height / 2f) * s).coerceIn(2f, height / 2f)
/** The head's shape at its current radius, for clipping (the edge and the band are drawn on the same numbers). */
fun headShape(radius: () -> Float) = androidx.compose.foundation.shape.GenericShape { size, _ ->
    addRoundRect(androidx.compose.ui.geometry.RoundRect(0f, 0f, size.width, size.height, androidx.compose.ui.geometry.CornerRadius(radius())))
}

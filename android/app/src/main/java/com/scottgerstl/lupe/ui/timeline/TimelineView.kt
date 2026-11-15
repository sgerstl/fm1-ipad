package com.scottgerstl.lupe.ui.timeline

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.setValue
import kotlin.math.ceil
import kotlin.math.max

// The landscape Timeline's view: how wide a bar is drawn and how far the song is panned. Pure arithmetic, apart from the
// two numbers of state, so the pan, the pinch, the keys and the playhead's following can all be tested without a screen.

/** Bars across the lanes: about 8 (zoomed in) to 16 (zoomed out), 12 to begin with (decision 28). */
const val BARS_MIN = 8f
const val BARS_MAX = 16f
const val BARS_START = 12f

@Stable
class TimelineViewState {
    /** Pixels a bar; 0 until the lanes have been measured (then [BARS_START] bars across). */
    var barPx by mutableFloatStateOf(0f)
    /** Pixels the song is panned to the left. */
    var scroll by mutableFloatStateOf(0f)
    /** When a finger last panned or zoomed (ms): the playhead doesn't pull the view away from under it. */
    var touchedAt = 0L
}

/** A bar's width kept between [BARS_MAX] and [BARS_MIN] bars across the lanes; an unmeasured one starts at [BARS_START]. */
fun clampBarPx(barPx: Float, lanePx: Float): Float =
    if (lanePx <= 0f) barPx else (if (barPx <= 0f) lanePx / BARS_START else barPx).coerceIn(lanePx / BARS_MAX, lanePx / BARS_MIN)

/** Bars the lanes hold: the song and four empty bars after it (room to add), and never fewer than fill the view. */
fun contentBars(totalBars: Int, barPx: Float, lanePx: Float): Int =
    max(totalBars + 4, if (barPx > 0f) ceil(lanePx / barPx).toInt() else 0)

fun clampScroll(scroll: Float, contentPx: Float, lanePx: Float): Float = scroll.coerceIn(0f, max(0f, contentPx - lanePx))

/** The pan after a zoom from [barPx] to [newBarPx] that keeps the bar under [focusX] (lane pixels) where it is. */
fun zoomAbout(scroll: Float, barPx: Float, newBarPx: Float, focusX: Float): Float =
    if (barPx <= 0f) scroll else (scroll + focusX) / barPx * newBarPx - focusX

/** The ruler numbers every bar while they fit, then every second, then every fourth. [barDp] is a bar's width in dp. */
fun rulerStep(barDp: Float): Int = when { barDp >= 40f -> 1; barDp >= 22f -> 2; else -> 4 }

/**
 * Where to pan so the playhead stays in view: null while it is inside the lanes, else the pan that puts it a tenth of
 * the way in from the left (a page turn, not a crawl).
 */
fun followScroll(headBar: Double, scroll: Float, barPx: Float, lanePx: Float): Float? {
    val x = headBar.toFloat() * barPx - scroll
    return if (x < 0f || x > lanePx * 0.9f) max(0f, headBar.toFloat() * barPx - lanePx * 0.1f) else null
}

/** While a block is dragged near an end of the lanes the song pans under it: [step] pixels a move inside [edge] of that end. */
fun edgePan(pointerX: Float, lanePx: Float, edge: Float, step: Float): Float = when {
    pointerX > lanePx - edge -> step
    pointerX < edge -> -step
    else -> 0f
}

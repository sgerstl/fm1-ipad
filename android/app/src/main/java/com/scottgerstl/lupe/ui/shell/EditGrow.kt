package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color

/**
 * Where Edit grows from (Scott, 2026-11-17, tab motion C): a pad's or a Timeline block's bounds (window px), its colour and corner, set by their
 * menus' "Edit steps" just before the tab changes. The tab pager takes it (once) and grows the Edit page out of it; a plain tab tap leaves it
 * empty and uses the fade-through.
 */
class EditGrow {
    var origin by mutableStateOf<EditOrigin?>(null)
    /** The selected track's current pad as Pads last laid it out (round 12: the Edit tab grows out of it, and shrinks back into it). */
    var selectedPad: EditOrigin? = null
    fun from(rect: Rect, colour: Color, radiusDp: Float) { origin = EditOrigin(rect, colour, radiusDp, System.currentTimeMillis()) }
    /** Takes the origin if it was set a moment ago (a stale one, from a menu that didn't change the tab, is dropped). */
    fun take(): EditOrigin? { val o = origin; origin = null; return o?.takeIf { System.currentTimeMillis() - it.atMs < 800 } }
}

data class EditOrigin(val rect: Rect, val colour: Color, val radiusDp: Float, val atMs: Long)

val LocalEditGrow = staticCompositionLocalOf { EditGrow() }

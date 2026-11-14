package com.scottgerstl.lupe.ui.edit

import kotlin.math.max
import kotlin.math.min

// The Edit tab's step grid (decision 31: the iPhone's piano roll, board 75): the arithmetic of which rows show, what a tap
// on a cell does, and how the grid scrolls under a panel docked at its right. No Compose here, so it can all be tested.

object Roll {
    /** An octave of rows in view (board 75: 12 rows in the grid's height). */
    const val ROWS = 12
    const val STEPS = 16
    /** With no notes yet the window is C4 to B4. */
    const val DEFAULT_TOP = 71

    private val BLACK = setOf(1, 3, 6, 8, 10)
    fun isBlack(midi: Int) = Math.floorMod(midi, 12) in BLACK
    fun isC(midi: Int) = Math.floorMod(midi, 12) == 0

    /**
     * The highest pitch in view so the pattern's notes sit in the window: centred when they fit in [rows], else from the highest
     * down (the rest is a scroll away). MIDI 0…127.
     */
    fun topFor(notes: List<Int>, rows: Int = ROWS): Int {
        if (notes.isEmpty()) return DEFAULT_TOP
        val lo = notes.min(); val hi = notes.max()
        if (hi - lo + 1 > rows) return hi.coerceIn(rows - 1, 127)
        val spare = rows - (hi - lo + 1)
        return (hi + spare / 2).coerceIn(rows - 1, 127)
    }

    /** The step under [x] (grid pixels) with the grid scrolled [scroll] to the left. */
    fun stepAt(x: Float, scroll: Float, stepPx: Float): Int = ((x + scroll) / stepPx).toInt().coerceIn(0, STEPS - 1)

    /** The pitch under [y] with the rows scrolled [scrollY] (row 0 is MIDI 127). */
    fun pitchAt(y: Float, scrollY: Float, rowPx: Float): Int = (127 - ((y + scrollY) / rowPx).toInt()).coerceIn(0, 127)

    /** The rows' scroll that puts [top] in the first row. */
    fun scrollYFor(top: Int, rowPx: Float): Float = (127 - top) * rowPx
    fun clampScrollY(scrollY: Float, rowPx: Float, viewPx: Float): Float = scrollY.coerceIn(0f, max(0f, 128 * rowPx - viewPx))

    /** A panel docked over the grid's right [dockPx]: the grid keeps its step width and can scroll left by that much (decision 35, B). */
    fun clampScrollX(scroll: Float, dockPx: Float): Float = scroll.coerceIn(0f, max(0f, dockPx))

    /** The scroll that brings step [i] clear of the dock (and of the left edge), moving as little as possible. */
    fun reveal(i: Int, scroll: Float, stepPx: Float, viewPx: Float, dockPx: Float): Float {
        val left = i * stepPx; val right = left + stepPx; val clear = viewPx - dockPx
        val s = when { right - scroll > clear -> right - clear; left - scroll < 0f -> left; else -> scroll }
        return clampScrollX(s, dockPx)
    }

    /** How much of the steps is in view beside the dock, as the scroll indicator draws it: start and end, 0…1. */
    fun indicator(scroll: Float, stepPx: Float, viewPx: Float, dockPx: Float): Pair<Float, Float> {
        val total = STEPS * stepPx
        if (total <= 0f) return 0f to 1f
        return (scroll / total).coerceIn(0f, 1f) to ((scroll + viewPx - dockPx) / total).coerceIn(0f, 1f)
    }

    /** What a tap on a cell does. */
    enum class Tap { Pick, Remove, Set, Add, Full }

    /**
     * A tap on (step, [pitch]): on a note of a step that isn't picked it only picks the step; on a note of the picked step it takes
     * the note off. On an empty cell it writes: with Chord off the step plays that note (replacing what it had), with Chord on the
     * note is added, up to [maxNotes] (the FM-1's four).
     */
    fun tap(stepNotes: List<Int>, pitch: Int, picked: Boolean, chord: Boolean, maxNotes: Int): Tap = when {
        pitch in stepNotes -> if (picked) Tap.Remove else Tap.Pick
        !chord -> Tap.Set
        stepNotes.size >= max(1, maxNotes) -> Tap.Full
        else -> Tap.Add
    }

    /** The first and last visible rows' pitches for a scroll, a row more each way so partial rows draw. */
    fun visiblePitches(scrollY: Float, rowPx: Float, viewPx: Float): IntRange {
        val first = (scrollY / rowPx).toInt(); val last = ((scrollY + viewPx) / rowPx).toInt()
        return max(0, 127 - last)..min(127, 127 - first)
    }
}

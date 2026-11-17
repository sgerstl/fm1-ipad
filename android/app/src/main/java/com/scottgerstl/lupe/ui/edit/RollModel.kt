package com.scottgerstl.lupe.ui.edit

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
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

    /** The step under [x] (grid pixels) with the grid scrolled [scroll] to the left; [total] steps in the pattern. */
    fun stepAt(x: Float, scroll: Float, stepPx: Float, total: Int = STEPS): Int = ((x + scroll) / stepPx).toInt().coerceIn(0, max(1, total) - 1)

    /** The pitch under [y] with the rows scrolled [scrollY] (row 0 is MIDI 127). */
    fun pitchAt(y: Float, scrollY: Float, rowPx: Float): Int = (127 - ((y + scrollY) / rowPx).toInt()).coerceIn(0, 127)

    /** The rows' scroll that puts [top] in the first row. */
    fun scrollYFor(top: Int, rowPx: Float): Float = (127 - top) * rowPx
    fun clampScrollY(scrollY: Float, rowPx: Float, viewPx: Float): Float = scrollY.coerceIn(0f, max(0f, 128 * rowPx - viewPx))

    // ---- across the pattern: up to 64 steps in chunks of sixteen (batch item 9; Scott: it snaps to 16-step chunks, bar lines between them)

    /** How many chunks of sixteen a pattern of [total] steps is (the last may be shorter). */
    fun chunks(total: Int, page: Int = STEPS): Int = max(1, (total + page - 1) / page)

    /** The 8-step page (or chunk of [page]) holding step [i]. */
    fun pageOf(i: Int, page: Int = STEPS): Int = max(0, i) / page

    /**
     * How far the grid can scroll: to the last chunk's start, and, with a panel docked over the right [dockPx], that much more so its last
     * step comes clear of it (decision 35, B: the steps keep their width and scroll under the panel).
     */
    fun maxScroll(total: Int, chunkPx: Float, dockPx: Float, page: Int = STEPS): Float = (chunks(total, page) - 1) * chunkPx + max(0f, dockPx)
    fun clampScrollX(scroll: Float, maxScroll: Float): Float = scroll.coerceIn(0f, max(0f, maxScroll))

    /**
     * Where a scroll settles: the nearest chunk start, or (a panel docked) the nearest chunk start or that start plus the dock, which is
     * where its last steps come clear of the panel.
     */
    fun snap(scroll: Float, total: Int, chunkPx: Float, dockPx: Float, page: Int = STEPS): Float {
        var best = 0f; var bestD = Float.MAX_VALUE
        for (c in 0 until chunks(total, page)) for (o in if (dockPx > 0.5f) listOf(0f, dockPx) else listOf(0f)) {
            val stop = c * chunkPx + o; val d = kotlin.math.abs(stop - scroll)
            if (d < bestD) { best = stop; bestD = d }
        }
        return best
    }

    /** The steps wholly in view beside a panel docked over the right [dockPx], with the grid scrolled [scroll]. */
    fun inView(scroll: Float, stepPx: Float, viewPx: Float, dockPx: Float, total: Int): IntRange {
        val first = ceil((scroll - 0.5f) / stepPx).toInt().coerceAtLeast(0)
        val last = floor((scroll + viewPx - max(0f, dockPx) + 0.5f) / stepPx).toInt() - 1
        return first..min(total - 1, last)
    }

    /**
     * The scroll that brings step [i] into view beside the dock: where it is if it already is, else the start of its chunk, else that start
     * plus the dock (its last steps). Always one of the places the grid settles.
     */
    fun reveal(i: Int, scroll: Float, stepPx: Float, viewPx: Float, dockPx: Float, total: Int = STEPS, page: Int = STEPS): Float {
        if (i in inView(scroll, stepPx, viewPx, dockPx, total)) return scroll
        val chunk = (i / page) * page * stepPx
        return if (i in inView(chunk, stepPx, viewPx, dockPx, total)) chunk else chunk + max(0f, dockPx)
    }

    /** While playing: null while the playhead's step is in view, else where to settle so it is (a page turn, not a crawl). */
    fun follow(head: Int, scroll: Float, stepPx: Float, viewPx: Float, dockPx: Float, total: Int, page: Int = STEPS): Float? =
        if (head < 0 || head >= total) null else reveal(head, scroll, stepPx, viewPx, dockPx, total, page).takeIf { abs(it - scroll) > 0.5f }

    /** What is in view along the whole pattern, as the scroll indicator draws it: start and end, 0…1. */
    fun indicator(scroll: Float, stepPx: Float, viewPx: Float, dockPx: Float, total: Int): Pair<Float, Float> {
        val all = max(1, total) * stepPx
        if (all <= 0f) return 0f to 1f
        return (scroll / all).coerceIn(0f, 1f) to ((scroll + viewPx - max(0f, dockPx)) / all).coerceIn(0f, 1f)
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

    // ---- 8-step pages (hybrid UI, Scott 2026-11-17): with the sound panel docked the grid shows 8 steps a page beside it, not 16 under it

    /** Steps a page: 8 while a panel is docked, else 16. */
    const val PAGE_DOCKED = 8

    /**
     * Whether the grid turns its page for the playhead: with 8-step pages only when Follow is on (Scott, 2026-11-17); 16-step chunks keep
     * following as built (batch item 9), unless a finger moved the steps a moment ago ([recentlyTouched]).
     */
    fun pagesFollow(page: Int, follow: Boolean, recentlyTouched: Boolean): Boolean = if (page == PAGE_DOCKED) follow else !recentlyTouched

    /** The minimap's sixteen cells: the bar of 16 that holds [page] of [pageSteps] (its first step), so a 32-step pattern shows its second bar there. */
    fun minimapStart(pageIndex: Int, pageSteps: Int): Int = (pageIndex * pageSteps / STEPS) * STEPS

    /** The label at the minimap's left: "1–8", "9–16", "17–24"… (an en dash), clipped to the pattern's [total]. */
    fun pageLabel(pageIndex: Int, pageSteps: Int, total: Int): String {
        val a = pageIndex * pageSteps + 1; val b = min(total, (pageIndex + 1) * pageSteps)
        return "$a\u2013$b"
    }

    /** A fling turns the page from this finger speed, in dp a second (Android's pagers use about 400). */
    const val FLING_DP_S = 400f
    /** …or a drag past this share of the page. */
    const val TURN_SHARE = 0.2f

    /**
     * Where a let-go settles (Scott, 2026-11-17: "you really have to drag it all the way over"): the page the drag began on, or the next one
     * either way once the finger flung ([fingerVelocity] px/s, the finger's x speed; leftward is negative, toward later steps) faster than
     * [flingPx] or dragged more than [TURN_SHARE] of a page ([startScroll] → [scroll]). Never past the pattern's first or last page.
     */
    fun pageTarget(startScroll: Float, scroll: Float, fingerVelocity: Float, pagePx: Float, total: Int, page: Int, flingPx: Float): Float {
        if (pagePx <= 0f) return 0f
        val startPage = kotlin.math.round(startScroll / pagePx).toInt()
        val moved = scroll - startScroll
        val step = when {
            fingerVelocity <= -flingPx -> 1
            fingerVelocity >= flingPx -> -1
            abs(moved) > TURN_SHARE * pagePx -> if (moved > 0) 1 else -1
            else -> 0
        }
        return (startPage + step).coerceIn(0, chunks(total, page) - 1) * pagePx
    }
}

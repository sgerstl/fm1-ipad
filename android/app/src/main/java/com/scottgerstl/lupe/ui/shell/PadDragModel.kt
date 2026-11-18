package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import kotlin.math.hypot

// Pad drag-and-drop (Scott on the Pixel, 2026-11-15: "long press is still bringing up the menu, which prevents me from dragging anything")
// and the edge action wells (board 81, tile 81.4). The rule is the iPhone's (PadsPage.swift): press then slide past the touch slop and the pad
// lifts at once (no menu), unless the slide came before the dwell, which is a swipe (the row scrolls); a still hold opens the menu, and if
// the finger then moves off the hold the menu closes and the pad lifts; a quick tap stays a tap. This file is the part that needs no screen.

enum class WellEdge { Bottom, Top, Left, Right }

/**
 * The wells on the screen's edges while a pad is lifted (decision 41, Scott 2026-11-15): Cancel at the bottom (puts the pad back), Clear steps and Delete
 * pattern sharing the top, Duplicate on the left, Edit on the right. They slide in bottom, top, left, right, 30 ms apart.
 */
enum class EdgeAction(val title: String, val edge: WellEdge, val staggerMs: Int) {
    Cancel("Cancel", WellEdge.Bottom, 0), ClearSteps("Clear steps", WellEdge.Top, 30), Delete("Delete pattern", WellEdge.Top, 30),
    Duplicate("Duplicate", WellEdge.Left, 60), Edit("Edit", WellEdge.Right, 90);
    /** Laid out along its edge (the bottom and top wells) rather than up it. */
    val across: Boolean get() = edge == WellEdge.Top || edge == WellEdge.Bottom
}

/**
 * The distances to tune by hand (CLAUDE.md rule 3), from Labs in dp, as the geometry needs them in px: the glow starts [glowPx] out and rises steadily to full at
 * [hotPx], where the well is hot; [off] the wells that refuse a drop now (Delete pattern while playing): greyed, never hot. (No camera-cutout inset on Android:
 * Scott, 2026-11-15, "not needed".)
 */
data class WellFeel(
    val glowPx: Float, val hotPx: Float, val off: Set<EdgeAction> = emptySet(),
    /** The side wells (Edit, Duplicate) light up sooner: the drag crosses much more width (Scott, 2026-11-15). */
    val sideGlowPx: Float = glowPx, val sideHotPx: Float = hotPx,
) {
    fun glow(a: EdgeAction) = if (a.edge == WellEdge.Left || a.edge == WellEdge.Right) sideGlowPx else glowPx
    fun hot(a: EdgeAction) = if (a.edge == WellEdge.Left || a.edge == WellEdge.Right) sideHotPx else hotPx
}

object EdgeWellsGeometry {
    /** The top pair's gap, and the least it may close to while one grows (each inner side grows at most half the difference). */
    const val TOP_GAP = 24f
    const val TOP_GAP_MIN = 16f
    /** How far a top well's inner side (the one facing its pair) may grow along the edge: [along] up to half of what the gap can give. */
    fun innerAlong(along: Float, d: Float): Float = minOf(along, (TOP_GAP - TOP_GAP_MIN) / 2f * d)
    /** Board 81.4 at the iPhone's 874 × 402: the bottom well 434 × 52 (half the width at most), the side wells 64 wide and 238 tall (a half of the height at most, a 0.6 of it at most), centred. [d] is the density. */
    fun rect(a: EdgeAction, w: Float, h: Float, d: Float): Rect {
        val sideH = minOf(h * 0.6f, maxOf(238f * d, h * 0.5f))
        // the top pair: two 260 × 52 wells [TOP_GAP] apart, at most 0.6 of the width (the wells narrow, never the gap; Scott, 2026-11-18: "need some space between them")
        val topW = minOf((2 * 260f + TOP_GAP) * d, w * 0.6f); val half = (topW - TOP_GAP * d) / 2; val topX = (w - topW) / 2
        return when (a) {
            EdgeAction.Cancel -> { val bw = minOf(434f * d, w * 0.5f); Rect((w - bw) / 2, h - 52f * d, (w + bw) / 2, h) }
            EdgeAction.ClearSteps -> Rect(topX, 0f, topX + half, 52f * d)
            EdgeAction.Delete -> Rect(topX + half + TOP_GAP * d, 0f, topX + topW, 52f * d)
            EdgeAction.Duplicate -> Rect(0f, (h - sideH) / 2, 64f * d, (h + sideH) / 2)
            EdgeAction.Edit -> Rect(w - 64f * d, (h - sideH) / 2, w, (h + sideH) / 2)
        }
    }

    /** How far a point is from a rectangle (0 inside). */
    fun distance(p: Offset, r: Rect): Float {
        val dx = maxOf(r.left - p.x, 0f, p.x - r.right); val dy = maxOf(r.top - p.y, 0f, p.y - r.bottom)
        return hypot(dx, dy)
    }

    /** 0…1: how near the pad's centre is to a well: 0 at the glow distance, rising steadily to 1 at the hot distance (so the target shows well before you reach it). */
    fun closeness(a: EdgeAction, centre: Offset, w: Float, h: Float, d: Float, feel: WellFeel): Float =
        if (a in feel.off) 0f else ((feel.glow(a) - distance(centre, rect(a, w, h, d))) / (feel.glow(a) - feel.hot(a)).coerceAtLeast(1f)).coerceIn(0f, 1f)

    /** The well a drop at [centre] lands in: the nearest within the hot distance. */
    fun hot(centre: Offset, w: Float, h: Float, d: Float, feel: WellFeel): EdgeAction? =
        EdgeAction.entries.filter { it !in feel.off }.map { it to distance(centre, rect(it, w, h, d)) }.filter { it.second <= feel.hot(it.first) }.minByOrNull { it.second / feel.hot(it.first) }?.first
}

/** One pad slot on the screen, in window pixels: [idx] the slot drawn, [landing] the entry a touch on it acts on (an outlined slot past the list's end stands for the first free one). */
data class DropSlot(val track: Int, val idx: Int, val landing: Int, val empty: Boolean, val rect: Rect)

/** The pad being carried. [grab] is where on the pad it was taken, from its top left; the copy keeps that point under the finger. */
@Stable
data class PadDrag(
    val track: Int, val from: Int, val rest: Boolean, val pattern: Int?, val colour: Color, val size: Size, val grab: Offset, val finger: Offset, val letter: String,
) {
    val topLeft: Offset get() = finger - grab
    val centre: Offset get() = topLeft + Offset(size.width / 2, size.height / 2)
}

/** What a drop does. */
sealed interface DropAction {
    data class Well(val action: EdgeAction) : DropAction
    /** The pad moves in its own list ([PadMove]): onto another pad of its track, or onto the track's empty slot. */
    data class Move(val track: Int, val from: Int, val to: Int) : DropAction
    /** A pattern onto an empty slot of another track: the same pattern (shared) or a copy, asked at the finger. */
    data class Offer(val toTrack: Int, val to: Int, val pattern: Int) : DropAction
}

/** Where a drop at [d]'s finger lands (the iPhone's rule): a hot well first, then the slot under the finger, otherwise nothing: it goes back. */
fun decideDrop(d: PadDrag, slots: Collection<DropSlot>, w: Float, h: Float, density: Float, feel: WellFeel): DropAction? {
    EdgeWellsGeometry.hot(d.centre, w, h, density, feel)?.let { return DropAction.Well(it) }
    val s = slots.firstOrNull { it.rect.contains(d.finger) && !(it.track == d.track && it.idx == d.from) } ?: return null
    return if (s.empty) {
        when {
            s.track == d.track -> DropAction.Move(d.track, d.from, s.landing)
            d.pattern != null -> DropAction.Offer(s.track, s.landing, d.pattern)      // (a REST has no pattern to copy: only its own row)
            else -> null
        }
    } else if (s.track == d.track) DropAction.Move(d.track, d.from, s.idx) else null
}

/** Whether a slide that began a press is a lift or a swipe: a slide before the dwell is a swipe (the row scrolls); after it, the pad lifts. */
fun liftsOrSwipes(movedPx: Float, slopPx: Float, heldMs: Long, dwellMs: Long): Boolean? =
    if (movedPx <= slopPx) null else heldMs >= dwellMs

/** A duplicate on its way into its slot: grown out of [from] (the source pad, window px), travelling to [to] (set once the new pad is placed). */
data class PadSprout(val track: Int, val idx: Int, val from: Rect, val colour: Color, val to: Rect? = null, val usedBefore: Int = 0)

class PadDragState {
    var drag by mutableStateOf<PadDrag?>(null)
    var sprout by mutableStateOf<PadSprout?>(null)
    /** The sprouting pad's real pad stays hidden while its copy flies (it swaps in at once as the copy lands). */
    var sproutHidden by mutableStateOf(false)
    /** The wells' feel as drawn now (one place, so a drop decides on what was shown). */
    fun feel(glowPx: Float, hotPx: Float, sideGlowPx: Float, sideHotPx: Float, playing: Boolean) =
        WellFeel(glowPx, hotPx, if (playing) setOf(EdgeAction.Delete) else emptySet(), sideGlowPx, sideHotPx).also { lastFeel = it }
    /** The page, recorded as it is drawn, and a blurred copy of it for the wells' glass (only while a pad is dragged). */
    /** The window as it was when the pad lifted (a PixelCopy), for the wells' glass: blurred behind each of them. Null until it arrives. */
    var backdrop by mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null)
    var lastFeel = WellFeel(0f, 0f)
    /** The slots on screen, kept by each pad as it is placed (plain, not observed: read at the drop). */
    val slots = HashMap<Any, DropSlot>()
    var screen by mutableStateOf(Size.Zero)
    var origin by mutableStateOf(Offset.Zero)
}

val LocalPadDrag = compositionLocalOf<PadDragState?> { null }

/** What a pad's touch hands the gesture: it lifts at [lift], follows with [move], and ends with [drop] (or [cancel]). Positions are in window pixels. */
interface PadDragger {
    fun lift(finger: Offset, grabLocal: Offset)
    fun move(finger: Offset)
    fun drop(finger: Offset)
    fun cancel()
}

package com.scottgerstl.lupe.ui.timeline

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.math.abs
import kotlin.math.floor

/**
 * A drag on one track's column, lifted out of the block so its neighbours can make room while it moves, and so the drag's end reads
 * what the finger did at that moment (an end handler that captured the numbers when the gesture began read the old ones and sent
 * nothing: the fault from Scott's hands on the device). [accPx] is state; everything else derives from it when asked.
 */
@Stable
class TrackDrag {
    /** The dragged block (null when none), and whether its foot (stretching) or its body (moving) is held. */
    var source by mutableStateOf<BlockUi?>(null)
    var resizing by mutableStateOf(false)
    var accPx by mutableFloatStateOf(0f)
    var barPx = 1f

    val active get() = source != null
    val offsetBars get() = accPx / barPx

    fun start(b: BlockUi, resize: Boolean, px: Float) { source = b; resizing = resize; accPx = 0f; barPx = px }
    fun end() { source = null; accPx = 0f }
}

/** How many places earlier (negative) or later in its track's list a block dragged by [offsetBars] would land: the slot whose centre is nearest its own. */
fun placesFor(mine: List<BlockUi>, id: Int, offsetBars: Float): Int {
    val sorted = mine.filter { !it.gap }.sortedBy { it.start }
    val idx = sorted.indexOfFirst { it.id == id }
    if (idx < 0) return 0
    val b = sorted[idx]
    val c = b.start + b.length / 2 + offsetBars
    var best = 0; var bestD = abs(c - (b.start + b.length / 2))
    for (k in 1..(sorted.size - 1 - idx)) {
        val centre = b.start + sorted.subList(idx + 1, idx + k + 1).sumOf { it.length.toDouble() }.toFloat() + b.length / 2
        val d = abs(c - centre); if (d < bestD) { best = k; bestD = d }
    }
    for (k in 1..idx) {
        val centre = b.start - sorted.subList(idx - k, idx).sumOf { it.length.toDouble() }.toFloat() + b.length / 2
        val d = abs(c - centre); if (d < bestD) { best = -k; bestD = d }
    }
    return best
}

/** The REPS a block dragged by its foot by [offsetBars] would have: whole passes, 1 to 16. */
fun repsFor(b: BlockUi, offsetBars: Float): Int =
    floor((b.length + offsetBars) / b.passBars + 0.5f).toInt().coerceIn(1, 16)

/**
 * How far (in bars) a block that is not being dragged moves to make room: while a block is stretched the ones after it slide
 * by the change in its length; while one is moved, the ones it passes slide the other way by its length.
 */
fun siblingShift(b: BlockUi, mine: List<BlockUi>, source: BlockUi?, resizing: Boolean, offsetBars: Float): Float {
    if (source == null || b.id == source.id || b.track != source.track) return 0f
    val sorted = mine.filter { !it.gap }.sortedBy { it.start }
    if (resizing) return if (b.start >= source.end - 0.001f) repsFor(source, offsetBars) * source.passBars - source.length else 0f
    val p = placesFor(sorted, source.id, offsetBars)
    val si = sorted.indexOfFirst { it.id == source.id }; val bi = sorted.indexOfFirst { it.id == b.id }
    return when {
        p > 0 && bi in (si + 1)..(si + p) -> -source.length
        p < 0 && bi in (si + p) until si -> source.length
        else -> 0f
    }
}

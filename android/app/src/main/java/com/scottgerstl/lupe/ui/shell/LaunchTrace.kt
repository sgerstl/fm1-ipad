package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * How far round the line is, as the launch point comes (the iPad's LaunchTrace, ios/FM1/PadsPage.swift): it starts from the time left when
 * the wait began, and once it has come round it holds closed until the thing lands; it is never started again from the next pass's time. Fed
 * the clock ticks left every frame. No Compose in it, so tests can run it.
 */
class TraceProgress {
    private var from: Double? = null
    private var last = 0.0
    private var closed = false

    /** [left]: ticks to the launch point now. Returns how much of the outline is drawn, 0…1. */
    fun at(left: Double): Float {
        if (from == null) { from = left; last = left }
        // the time left jumping up: the line had come round (it was nearly there), or the wait was staged again further off (start from where it is now)
        if (left > last + 1 && !closed) { if (last <= 12) closed = true else from = left }
        last = left
        if (closed) return 1f
        val f = from ?: return 0f
        return if (f > 0) (1 - left / f).coerceIn(0.0, 1.0).toFloat() else 1f
    }
}

/**
 * A rounded rectangle's outline from its top left corner, counter-clockwise on the screen: the corner, down the left, along the bottom, up the
 * right, back along the top (the iPad's TraceOutline). [inset] is half the line's width, so the line sits inside the shape; the corner radius
 * shrinks by it (the nested-corner rule: inner radius = outer radius − the inset).
 */
fun traceOutline(size: Size, radius: Float, inset: Float): Path = traceOutline(size, radius, radius, radius, radius, inset)

/**
 * The same outline with each corner its own radius (top left, bottom left, bottom right, top right, in px, the shape's own as it draws), so a
 * key whose corners differ (the joined Mute · Solo pair) or change (a scene squaring off) is traced on the shape it shows (Scott, 2026-11-17).
 */
fun traceOutline(size: Size, tl: Float, bl: Float, br: Float, tr: Float, inset: Float): Path {
    val l = inset; val t = inset; val r = size.width - inset; val b = size.height - inset
    fun c(x: Float) = (x - inset).coerceAtMost((r - l) / 2).coerceAtMost((b - t) / 2).coerceAtLeast(0f)
    val a = c(tl); val d = c(bl); val e = c(br); val f = c(tr)
    return Path().apply {
        moveTo(l + a, t)
        if (a > 0f) arcTo(Rect(l, t, l + 2 * a, t + 2 * a), 270f, -90f, false)
        lineTo(l, b - d)
        if (d > 0f) arcTo(Rect(l, b - 2 * d, l + 2 * d, b), 180f, -90f, false)
        lineTo(r - e, b)
        if (e > 0f) arcTo(Rect(r - 2 * e, b - 2 * e, r, b), 90f, -90f, false)
        lineTo(r, t + f)
        if (f > 0f) arcTo(Rect(r - 2 * f, t, r, t + 2 * f), 0f, -90f, false)
        lineTo(l + a, t)
    }
}

/**
 * Anything waiting for the launch point, its outline drawn as that comes (the iPad's LaunchTrace; Scott, 2026-11-10: "the same pattern for…
 * anything else that waits for the loop"): the whole outline faint ([base]: 0.3 on pads, 0.6 on keys so a waiting edge reads at 3:1), and the
 * line drawn over it from the top left corner, counter-clockwise, closing as it lands. [left] is the clock ticks to go, read every frame;
 * null means no clock (joined mid-play): a dashed outline. Reduce Motion: drawn the same (a line growing in place; nothing travels). It
 * takes no touches and says nothing to TalkBack (the thing it sits on says "waiting").
 */
@Composable
fun LaunchTrace(left: () -> Double?, colour: Color, radius: Dp, width: Dp, modifier: Modifier = Modifier, base: Float = 0.3f,
    /** The shape's corners as it draws them now (tl, bl, br, tr, px, for the size given), read every frame; null: [radius] all round. */
    corners: (androidx.compose.ui.graphics.drawscope.DrawScope.(Size) -> FloatArray)? = null) {
    val cornersNow by rememberUpdatedState(corners)
    val read by rememberUpdatedState(left)
    val progress = remember { TraceProgress() }
    // a frame clock: reading it in the draw redraws every frame without recomposing
    var frame by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) { while (true) withFrameNanos { frame = it } }
    val measure = remember { PathMeasure() }
    Canvas(modifier.clearAndSetSemantics { }) {
        frame   // read: redraw each frame
        val w = width.toPx()
        val whole = cornersNow?.let { f -> f(this, size) }?.let { k -> traceOutline(size, k[0], k[1], k[2], k[3], w / 2) } ?: traceOutline(size, radius.toPx(), w / 2)
        val now = read()
        if (now == null) {
            drawPath(whole, colour, style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8.dp.toPx(), 5.dp.toPx()))))
        } else {
            drawPath(whole, colour.copy(alpha = base), style = Stroke(w))
            val done = progress.at(now)
            if (done > 0f) {
                measure.setPath(whole, false)
                val part = Path()
                measure.getSegment(0f, measure.length * done, part, true)
                drawPath(part, colour, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
        }
    }
}

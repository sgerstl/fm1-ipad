package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.R
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlin.math.roundToInt

private val SlideIn = CubicBezierEasing(0.2f, 0.8f, 0.2f, 1f)

/**
 * The wells for a dragged pad (board 81.4) and the lifted pad over them, in one layer over the whole screen. Three wells sit flush on the edges, square on the
 * edge side and rounded 12 inside, dashed on the three inner sides, resting as dark glass (black 62 %; the iPhone blurs what is behind, which this does not):
 * Clear at the bottom, Edit on the right, Duplicate on the left. They slide in from their edges as the pad lifts (Labs: slide, staggered 30 ms) and out in 72 %
 * of that; a glow in the track colour (red for Clear) builds from the glow distance; hot, within the hot distance, the well fills solid with a dark label, ticks,
 * and the lifted pad tilts toward it. Reduce Motion: they fade, the pad doesn't tilt or grow. It takes no touches. TalkBack keeps the hold menu.
 */
@Composable
fun PadDragOverlay(state: PadDragState, modifier: Modifier = Modifier) {
    val labs = LocalPhoneSettings.current
    val reduce = LocalReduceMotion.current
    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current
    val d = density.density
    val drag = state.drag
    // the last pad stays drawn while the wells leave
    var last by remember { mutableStateOf<PadDrag?>(null) }
    if (drag != null) last = drag
    val feel = WellFeel(labs.wellGlowDp * d, labs.wellHotDp * d)
    val w = state.screen.width; val h = state.screen.height
    val hot = if (drag != null && w > 0f) EdgeWellsGeometry.hot(drag.centre - state.origin, w, h, d, feel) else null
    LaunchedEffect(hot) { if (hot != null && labs.haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) }

    Box(modifier.fillMaxSize().onGloballyPositioned { state.screen = Size(it.size.width.toFloat(), it.size.height.toFloat()); state.origin = it.positionInWindow() }.clearAndSetSemantics { }) {
        if (w > 0f) {
            for (a in EdgeAction.entries) {
                val p = remember(a) { Animatable(0f) }
                LaunchedEffect(drag != null, reduce, labs.wellSlideMs) {
                    unscaled {
                        if (drag != null) p.animateTo(1f, if (reduce) tween(150) else tween(labs.wellSlideMs, delayMillis = a.staggerMs, easing = SlideIn))
                        else p.animateTo(0f, if (reduce) tween(150) else tween((labs.wellSlideMs * 0.72f).roundToInt(), easing = FastOutLinearInEasing))
                    }
                }
                if (p.value > 0.001f) {
                    val on = (drag ?: last)
                    Well(a, Rect(0f, 0f, w, h), d, p.value, hot == a, if (drag != null) EdgeWellsGeometry.closeness(a, drag.centre - state.origin, w, h, d, feel) else 0f,
                        if (a == EdgeAction.Clear) Tok.rec else on?.colour ?: Tok.text, reduce)
                }
            }
        }
        // the lifted pad, over the wells, tilting toward a hot one
        if (drag != null) {
            val tilt = animatedTilt(hot, reduce)
            val tl = drag.topLeft - state.origin
            Box(
                Modifier.offset { IntOffset(tl.x.roundToInt(), tl.y.roundToInt()) }
                    .size(with(density) { drag.size.width.toDp() }, with(density) { drag.size.height.toDp() })
                    .graphicsLayer {
                        val s = if (reduce) 1f else 1.06f; scaleX = s; scaleY = s
                        cameraDistance = 12f * this.density
                        rotationY = tilt.first; rotationX = tilt.second
                    }
                    .shadow(12.dp, androidx.compose.foundation.shape.RoundedCornerShape(8.dp), ambientColor = Color.Black, spotColor = Color.Black)
                    .then(Modifier),
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    drawRoundRect(drag.colour, cornerRadius = CornerRadius(8.dp.toPx()))
                }
                Row(Modifier.align(Alignment.CenterStart).offset(x = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (drag.rest) BasicText("REST", style = LupeType.label.copy(color = Tok.onColour))
                    else {
                        BasicText(drag.letter, style = LupeType.label.copy(color = Tok.onColour))
                        BasicText("  %02d".format(drag.pattern ?: 0), style = LupeType.number.copy(fontSize = 20.sp, color = Tok.onColour))
                    }
                }
            }
        }
    }
}

@Composable
private fun animatedTilt(hot: EdgeAction?, reduce: Boolean): Pair<Float, Float> {
    val y = com.scottgerstl.lupe.ui.theme.animatedFloat(if (reduce) 0f else when (hot) { EdgeAction.Edit -> -14f; EdgeAction.Duplicate -> 14f; else -> 0f }, 150)
    val x = com.scottgerstl.lupe.ui.theme.animatedFloat(if (reduce) 0f else if (hot == EdgeAction.Clear) -14f else 0f, 150)
    return y.value to x.value
}

/** One well: [full] is the screen, [p] 0…1 how far it has slid in, [glow] 0…1 how near the pad is. */
@Composable
private fun Well(a: EdgeAction, full: Rect, d: Float, p: Float, hot: Boolean, glow: Float, tint: Color, reduce: Boolean) {
    val r = EdgeWellsGeometry.rect(a, full.width, full.height, d)
    // the hot one grows by 8 dp into the screen (the board's 64 → 72)
    val hotT = com.scottgerstl.lupe.ui.theme.animatedFloat(if (hot) 1f else 0f, 120).value
    val g = 8f * d * hotT
    val grown = when (a) {
        EdgeAction.Clear -> Rect(r.left - 4f * d * hotT, r.top - g, r.right + 4f * d * hotT, r.bottom)
        EdgeAction.Edit -> Rect(r.left - g, r.top - g, r.right, r.bottom + g)
        EdgeAction.Duplicate -> Rect(r.left, r.top - g, r.right + g, r.bottom + g)
    }
    // slides in from its own edge
    val slide = if (reduce) Offset.Zero else when (a) {
        EdgeAction.Clear -> Offset(0f, (1f - p) * (grown.height + 8f * d))
        EdgeAction.Edit -> Offset((1f - p) * (grown.width + 8f * d), 0f)
        EdgeAction.Duplicate -> Offset(-(1f - p) * (grown.width + 8f * d), 0f)
    }
    val glowA = if (hot) 1f else glow
    Box(
        Modifier.offset { IntOffset((grown.left + slide.x).roundToInt(), (grown.top + slide.y).roundToInt()) }
            .size(with(androidx.compose.ui.platform.LocalDensity.current) { grown.width.toDp() }, with(androidx.compose.ui.platform.LocalDensity.current) { grown.height.toDp() })
            .graphicsLayer { alpha = if (reduce) p else 1f },
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val rad = 12.dp.toPx()
            val z = CornerRadius.Zero; val c = CornerRadius(rad)
            // square on the edge side, rounded 12 inside
            val shape = RoundRect(Rect(Offset.Zero, size),
                topLeft = if (a == EdgeAction.Duplicate) z else c,
                bottomLeft = if (a == EdgeAction.Clear || a == EdgeAction.Duplicate) z else c,
                bottomRight = if (a == EdgeAction.Clear || a == EdgeAction.Edit) z else c,
                topRight = if (a == EdgeAction.Edit) z else c)
            val path = Path().apply { addRoundRect(shape) }
            // the glow around it, building in the track colour
            if (glowA > 0f) for (k in 3 downTo 1) drawPath(path, tint.copy(alpha = (if (hot) 0.5f else 0.4f * glowA) * 0.18f), style = Stroke(width = k * 5.dp.toPx() * glowA.coerceAtLeast(0.2f)))
            if (!hot) drawPath(path, Color.Black.copy(alpha = 0.62f))
            drawPath(path, tint.copy(alpha = if (hot) 1f else 0.35f * glowA))
            // dashes on the three inner sides: the outline, pushed 4 dp past the edge it sits on so that side is off the screen
            val pad = 4.dp.toPx()
            val out = Rect(
                if (a == EdgeAction.Duplicate) -pad else 0f, 0f,
                if (a == EdgeAction.Edit) size.width + pad else size.width, if (a == EdgeAction.Clear) size.height + pad else size.height)
            val dashed = Path().apply {
                addRoundRect(RoundRect(out, topLeft = shape.topLeftCornerRadius, bottomLeft = shape.bottomLeftCornerRadius, bottomRight = shape.bottomRightCornerRadius, topRight = shape.topRightCornerRadius))
            }
            drawPath(dashed, if (hot) tint else Tok.text2.copy(alpha = 0.55f + 0.45f * glowA),
                style = Stroke(1.5.dp.toPx(), pathEffect = if (hot) null else PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))))
        }
        val ink = if (hot) Tok.onColour else Tok.text
        val icon = if (a == EdgeAction.Clear) R.drawable.ms_delete else if (a == EdgeAction.Edit) R.drawable.ms_edit else R.drawable.ms_library_add
        val tintF = ColorFilter.tint(if (hot) Tok.onColour else Tok.text2)
        if (a == EdgeAction.Clear) {
            Row(Modifier.align(Alignment.Center), verticalAlignment = Alignment.CenterVertically) {
                Image(painterResource(icon), null, Modifier.size(18.dp), colorFilter = tintF)
                BasicText("  Clear", style = LupeType.key.copy(fontSize = 14.sp, color = ink))
            }
        } else {
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Image(painterResource(icon), null, Modifier.size(18.dp), colorFilter = tintF)
                BasicText(a.title, Modifier.offset(y = 4.dp), style = LupeType.key.copy(fontSize = 13.sp, color = ink), maxLines = 1)
            }
        }
    }
}

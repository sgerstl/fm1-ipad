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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
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
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.drawLayer
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
 * The wells for a dragged pad (board 81.4; hybrid look, Scott 2026-11-17: edge tabs that grow, then fill) and the lifted pad over them, in one layer
 * over the whole screen. Decision 41: Cancel at the bottom, Clear steps and Delete pattern on the top, Edit on the right, Duplicate on the left. They
 * slide in from their edges on the spatial spring as the pad lifts (Labs: wells slide in, staggered 30 ms) and out quicker; each grows with the pad's
 * closeness and, hot, fills with its track colour and ticks, and the lifted pad tilts toward it ([Well]). Reduce Motion: they fade, the pad doesn't
 * tilt or grow. It takes no touches. TalkBack keeps the hold menu.
 */
@Composable
fun PadDragOverlay(state: PadDragState, playing: Boolean, modifier: Modifier = Modifier) {
    val labs = LocalPhoneSettings.current
    val reduce = LocalReduceMotion.current
    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current
    val d = density.density
    val drag = state.drag
    // the last pad stays drawn while the wells leave
    var last by remember { mutableStateOf<PadDrag?>(null) }
    if (drag != null) last = drag
    val feel = state.feel(labs.wellGlowPct / 100f * state.screen.height, labs.wellHotDp * d, labs.wellSideGlowPct / 100f * state.screen.width, labs.wellSideHotDp * d, playing)
    val w = state.screen.width; val h = state.screen.height
    val hot = if (drag != null && w > 0f) EdgeWellsGeometry.hot(drag.centre - state.origin, w, h, d, feel) else null
    val wellBounce = com.scottgerstl.lupe.ui.theme.hybridMotion.bounce
    LaunchedEffect(hot) { if (hot != null && labs.haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) }

    Box(modifier.fillMaxSize().onGloballyPositioned { state.screen = Size(it.size.width.toFloat(), it.size.height.toFloat()); state.origin = it.positionInWindow() }.clearAndSetSemantics { }) {
        val progress = HashMap<EdgeAction, Float>()
        if (w > 0f) {
            for (a in EdgeAction.entries) {
                val p = remember(a) { Animatable(0f) }
                progress[a] = p.value
                LaunchedEffect(drag != null, reduce, labs.wellSlideMs) {
                    unscaled {
                        // in on the spatial spring (Labs: wells slide in sets its length; hybrid UI, Scott 2026-11-17), staggered; out quicker
                        if (drag != null) { if (!reduce && a.staggerMs > 0) kotlinx.coroutines.delay(a.staggerMs.toLong()); p.animateTo(1f, if (reduce) tween(150) else com.scottgerstl.lupe.ui.theme.lupeSpring(labs.wellSlideMs, wellBounce)) }
                        else p.animateTo(0f, if (reduce) tween(150) else tween((labs.wellSlideMs * 0.72f).roundToInt(), easing = FastOutLinearInEasing))
                    }
                }
                if (p.value > 0.001f) {
                    val on = (drag ?: last)
                    // hot, every well fills with the dragged pad's track colour (Scott, 2026-11-17: Clear steps and Delete too, not red, unless he says otherwise)
                    val tint = on?.colour ?: Tok.text
                    Well(a, Rect(0f, 0f, w, h), d, p.value, hot == a, a in feel.off, state,
                        if (drag != null) EdgeWellsGeometry.closeness(a, drag.centre - state.origin, w, h, d, feel) else 0f, tint, reduce, feel, labels = false)
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
                    .shadow(12.dp, androidx.compose.foundation.shape.RoundedCornerShape(8.dp), ambientColor = Color.Black, spotColor = Color.Black),
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
        // the wells' labels, over the lifted pad (it would cover Cancel's otherwise)
        if (w > 0f) for (a in EdgeAction.entries) {
            val p = progress[a] ?: 0f
            if (p > 0.001f) Well(a, Rect(0f, 0f, w, h), d, p, hot == a, a in feel.off, state,
                if (drag != null) EdgeWellsGeometry.closeness(a, drag.centre - state.origin, w, h, d, feel) else 0f, (drag ?: last)?.colour ?: Tok.text, reduce, feel, labels = true)
        }
        // a duplicate the core never answered (refused): the sprout is forgotten after a while and the pad is shown
        LaunchedEffect(state.sprout) { val sp = state.sprout; if (sp != null && sp.to == null) { kotlinx.coroutines.delay(3000); if (state.sprout == sp) { state.sprout = null; state.sproutHidden = false } } }
        // a duplicated pad sprouting into its slot
        state.sprout?.let { Sprout(state, it, reduce) }
    }
}

@Composable
private fun animatedTilt(hot: EdgeAction?, reduce: Boolean): Pair<Float, Float> {
    val y = com.scottgerstl.lupe.ui.theme.animatedFloat(if (reduce) 0f else when (hot) { EdgeAction.Edit -> -14f; EdgeAction.Duplicate -> 14f; else -> 0f }, 150)
    val x = com.scottgerstl.lupe.ui.theme.animatedFloat(if (reduce) 0f else when (hot) { EdgeAction.Cancel -> -14f; EdgeAction.ClearSteps, EdgeAction.Delete -> 14f; else -> 0f }, 150)
    return y.value to x.value
}

/**
 * A duplicate sprouting into its slot: the new pad grows out of the source pad, travels to its slot and settles with a small spring (0.32 s, damping 0.68),
 * then one soft ring in the track colour grows and fades (0.6 s). Reduce Motion: a fade in place, then the ring. The real pad is there from the start.
 */
@Composable
private fun Sprout(state: PadDragState, s: PadSprout, reduce: Boolean) {
    val to = s.to ?: return
    val move = remember(s) { Animatable(0f) }
    val ring = remember(s) { Animatable(0f) }
    var flying by remember(s) { mutableStateOf(true) }
    LaunchedEffect(s, reduce) {
        // the real pad is hidden until the copy lands, then swaps in at once (no cross-fade)
        state.sproutHidden = true
        unscaled {
            // a spring of response 0.32 s, damping 0.68 (the iPhone's): a small overshoot; Reduce Motion: the new pad fades in place (0.2 s)
            if (reduce) move.animateTo(1f, tween(200))
            else move.animateTo(1f, androidx.compose.animation.core.spring(dampingRatio = 0.68f, stiffness = 385f))
            flying = false
            state.sproutHidden = false
            ring.animateTo(1f, tween(600, easing = androidx.compose.animation.core.FastOutSlowInEasing))
        }
        state.sprout = null
    }
    val o = state.origin
    val t = move.value
    val dens = LocalDensity.current
    if (flying) {
        // it starts at 60 % size centred on the source pad and springs to the slot's frame at full size, its 10 dp shadow fading as it lands
        val k = if (reduce) 1f else 0.6f + 0.4f * t
        val cx = if (reduce) to.center.x else s.from.center.x + (to.center.x - s.from.center.x) * t
        val cy = if (reduce) to.center.y else s.from.center.y + (to.center.y - s.from.center.y) * t
        val wd = to.width * k; val ht = to.height * k
        Box(
            Modifier.offset { IntOffset((cx - wd / 2 - o.x).roundToInt(), (cy - ht / 2 - o.y).roundToInt()) }.size(with(dens) { wd.toDp() }, with(dens) { ht.toDp() })
                .graphicsLayer { alpha = if (reduce) t.coerceIn(0f, 1f) else 1f }
                .shadow(10.dp * (1f - t.coerceIn(0f, 1f)), androidx.compose.foundation.shape.RoundedCornerShape(8.dp)),
        ) { Canvas(Modifier.fillMaxSize()) { drawRoundRect(s.colour, cornerRadius = CornerRadius(8.dp.toPx())) } }
    }
    // the ring: a rounded rect 8 larger than the pad (corner = the pad's radius + 4), 2 dp in the track colour, scaling 1 → 1.18 while fading 1 → 0 over 0.6 s
    if (ring.value > 0f && ring.value < 1f) Canvas(Modifier.fillMaxSize()) {
        val e = ring.value
        val sc = 1f + 0.18f * e
        val w = (to.width + 8.dp.toPx()) * sc; val h = (to.height + 8.dp.toPx()) * sc
        drawRoundRect(s.colour.copy(alpha = 1f - e), Offset(to.center.x - o.x - w / 2, to.center.y - o.y - h / 2), Size(w, h), CornerRadius(12.dp.toPx()), style = Stroke(2.dp.toPx()))
    }
}

/**
 * One well, hybrid look (Scott, 2026-11-17: "1 · Edge tabs", "Grow, then fill"). A solid `held` surface flush to its screen edge, square on the
 * edge side and radius 24 (the sheet radius) facing in, elevation 3; an icon (22) over its label on the side wells, beside it on the top and
 * bottom ones. As the dragged pad nears, the well grows outward with closeness ([near] 0…1, read straight from the finger: no spring lag), from
 * the glow distance to the hot one; hot, it fills with the pad's track colour ([tint], 150 ms ease-out), the ink turns dark and the icon grows to
 * 26 (the tick is the caller's). [p] is how far it has slid in; [off] refuses a drop now (greyed, "Stop first"). Reduce Motion: no slide, no
 * growth; it fades. Drawn twice: the surface under the lifted pad, the label ([labels]) over it.
 */
@Composable
private fun Well(a: EdgeAction, full: Rect, d: Float, p: Float, hot: Boolean, off: Boolean, state: PadDragState, near: Float, tint: Color, reduce: Boolean, feel: WellFeel, labels: Boolean) {
    val r = EdgeWellsGeometry.rect(a, full.width, full.height, d)
    // round 3 (Scott: "the color should swell as the user gets closer"): the fill blends from `held` toward the track colour with closeness,
    // straight from the finger (no step), full at the hot distance; the size grows with it
    val swell = if (off) 0f else (if (hot) 1f else near.coerceIn(0f, 1f))
    val fillColour = androidx.compose.ui.graphics.lerp(Tok.held, tint, swell)
    // the ink crosses to the dark on-colour once that reads better on the fill, blended over a short band (computed contrast, not a fixed point)
    val hotT = inkWeight(fillColour)
    // size is the signal: up to 16 dp outward (and 8 along) with closeness, all of it once hot
    val k = if (reduce || off) 0f else (if (hot) 1f else near.coerceIn(0f, 1f))
    val g = 16f * d * k; val along = 8f * d * k
    val e = a.edge
    val grown = when (e) {
        WellEdge.Bottom -> Rect(r.left - along, r.top - g, r.right + along, r.bottom)
        WellEdge.Top -> Rect(r.left - along, r.top, r.right + along, r.bottom + g)
        WellEdge.Right -> Rect(r.left - g, r.top - along, r.right, r.bottom + along)
        WellEdge.Left -> Rect(r.left, r.top - along, r.right + g, r.bottom + along)
    }
    val travel = if (a.across) grown.height else grown.width
    val slide = if (reduce) Offset.Zero else when (e) {
        WellEdge.Bottom -> Offset(0f, (1f - p) * (travel + 8f * d))
        WellEdge.Top -> Offset(0f, -(1f - p) * (travel + 8f * d))
        WellEdge.Right -> Offset((1f - p) * (travel + 8f * d), 0f)
        WellEdge.Left -> Offset(-(1f - p) * (travel + 8f * d), 0f)
    }
    val dens = androidx.compose.ui.platform.LocalDensity.current
    val rIn = com.scottgerstl.lupe.ui.theme.Shape.sheet; val r0 = 0.dp
    val shape = androidx.compose.foundation.shape.RoundedCornerShape(
        topStart = if (e == WellEdge.Bottom || e == WellEdge.Right) rIn else r0, topEnd = if (e == WellEdge.Bottom || e == WellEdge.Left) rIn else r0,
        bottomEnd = if (e == WellEdge.Top || e == WellEdge.Left) rIn else r0, bottomStart = if (e == WellEdge.Top || e == WellEdge.Right) rIn else r0)
    Box(
        Modifier.offset { IntOffset((grown.left + slide.x).roundToInt(), (grown.top + slide.y).roundToInt()) }
            .size(with(dens) { grown.width.toDp() }, with(dens) { grown.height.toDp() })
            .graphicsLayer {
                alpha = (if (reduce) p else 1f) * (if (off) 0.45f else 1f)
                if (!labels) { shadowElevation = 12.dp.toPx(); this.shape = shape; clip = true; ambientShadowColor = Color.Black; spotShadowColor = Color.Black }
            },
    ) {
        if (!labels) Canvas(Modifier.fillMaxSize()) {
            drawRect(fillColour)
        }
        if (labels) {
            val ink = androidx.compose.ui.graphics.lerp(Tok.text, Tok.onColour, hotT)
            val icon = when (a) { EdgeAction.Cancel -> R.drawable.ms_close; EdgeAction.ClearSteps -> R.drawable.ms_delete_sweep; EdgeAction.Delete -> R.drawable.ms_delete; EdgeAction.Edit -> R.drawable.ms_edit; EdgeAction.Duplicate -> R.drawable.ms_library_add }
            val iconDp = (22f + 4f * swell).dp
            val labelBox = Modifier.align(Alignment.Center)
            val word = LupeType.key.copy(fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal, color = ink)
            if (a.across) {
                Row(labelBox, verticalAlignment = Alignment.CenterVertically) {
                    Image(painterResource(icon), null, Modifier.size(iconDp), colorFilter = ColorFilter.tint(ink))
                    Column(Modifier.padding(start = 8.dp)) {
                        BasicText(a.title, style = word, maxLines = 1)
                        if (off) BasicText("Stop first", style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised))
                    }
                }
            } else {
                Column(labelBox, horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(painterResource(icon), null, Modifier.size(iconDp), colorFilter = ColorFilter.tint(ink))
                    BasicText(a.title, Modifier.padding(top = 4.dp), style = word, maxLines = 1)
                }
            }
        }
    }
}

/** WCAG relative luminance of [c]. */
private fun lum(c: Color): Float {
    fun ch(v: Float) = if (v <= 0.03928f) v / 12.92f else Math.pow(((v + 0.055f) / 1.055f).toDouble(), 2.4).toFloat()
    return 0.2126f * ch(c.red) + 0.7152f * ch(c.green) + 0.0722f * ch(c.blue)
}
private fun contrast(a: Color, b: Color): Float { val x = lum(a); val y = lum(b); return (maxOf(x, y) + 0.05f) / (minOf(x, y) + 0.05f) }

/**
 * How dark a well's ink is on [fill], 0 (the light `text`) … 1 (`onColour`): whichever has the higher contrast, blended over about a unit of
 * contrast either side of the crossover so the ink never flips in one frame.
 */
internal fun inkWeight(fill: Color): Float = ((contrast(Tok.onColour, fill) - contrast(Tok.text, fill)) / 2f + 0.5f).coerceIn(0f, 1f)

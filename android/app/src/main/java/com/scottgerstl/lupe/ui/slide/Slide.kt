package com.scottgerstl.lupe.ui.slide

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitTouchSlopOrCancellation
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.systemGestureExclusion
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlin.math.abs

/** Whether a drag whose first stronger movement is up-and-down ([up]) or across begins a slide under this setting. */
fun SlideDirection.takes(up: Boolean) = when (this) { SlideDirection.Sideways -> !up; SlideDirection.UpDown -> up; SlideDirection.Both -> true }

val LocalSlideSettings = staticCompositionLocalOf { SlideSettings() }
val LocalMagnifier = staticCompositionLocalOf<MagnifierState?> { null }

/** What the Magnifier shows: the control's label and live value, and a ring or a gauge for where it sits. Lambdas read live state, so the digits move with the finger. */
@Stable
class MagnifierFace(
    val label: String,
    val value: () -> String,
    /** 0..1, or null for a value with no range (a pitch). */
    val fraction: () -> Float? = { null },
    val bipolar: Boolean = false,
    val ring: Boolean = false,
    val tint: Color = Tok.text,
)

/** True while a sound page is showing: the back gesture sends HOME then (decision 19), so no control may exclude the screen's edges from it. */
val LocalBackGoesHome = androidx.compose.runtime.compositionLocalOf { false }

/** The loupe's state: one at the top of the screen, driven by whichever control is being slid. */
@Stable
class MagnifierState {
    var face by mutableStateOf<MagnifierFace?>(null)
    var shown by mutableStateOf(false)
    var finger by mutableStateOf(Offset.Zero)
    /** True when the finger is reported in screen coordinates (a control inside a pop-up window, whose own root isn't the activity's). */
    var screenSpace = false
}

/**
 * Slide to turn, on the control itself. The drag begins only when the finger moves in the direction the setting
 * asks for (ios/FM1/Knobs.swift ColumnSlidePan): Sideways, only more across than up and down; Up and down, only
 * more up and down; Both, the first movement's stronger axis decides for that drag. Up and right raise.
 * [onSlide] gets the whole drag so far in steps of [stepDp] (so a value is base + steps, whatever frames did), and
 * [onEnd] the end. While it slides, the Magnifier (when on) floats a bigger copy of [face] above the finger.
 */
@Composable
fun Modifier.slideToTurn(
    enabled: Boolean,
    stepDp: Float,
    face: MagnifierFace?,
    onStart: () -> Unit = {},
    onSlide: (steps: Int) -> Unit,
    onEnd: () -> Unit = {},
    /** The steps the value can move from where it is when the slide starts (low..high, around 0), or null for no limit. The slide stops there, with no dead zone to unwind when the finger turns back. */
    bounds: () -> IntRange? = { null },
    onLimit: () -> Unit = {},
    /** A control drawn as a line (a fader) follows the finger along its own axis whatever the setting; the setting is for knobs and value boxes. */
    forceDirection: SlideDirection? = null,
): Modifier {
    val settings = LocalSlideSettings.current
    val magnifier = LocalMagnifier.current
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val dir = forceDirection ?: settings.direction
    val slide by rememberUpdatedState(onSlide)
    val start by rememberUpdatedState(onStart)
    val end by rememberUpdatedState(onEnd)
    val boundsNow by rememberUpdatedState(bounds)
    val limit by rememberUpdatedState(onLimit)
    val currentFace by rememberUpdatedState(face)
    val loupeOn by rememberUpdatedState(settings.magnifier)
    val density = LocalDensity.current
    val stepPx = with(density) { stepDp.dp.toPx() }
    // a sideways slide at the screen's edge must not become the system's back gesture (P1's run, 2026-11-13)
    return this.onGloballyPositioned { coords = it }.then(
        if (!enabled) Modifier else (if (LocalBackGoesHome.current) Modifier else Modifier.systemGestureExclusion()).pointerInput(dir, stepPx) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                var vertical = false
                var first = Offset.Zero
                val claimed: PointerInputChange = awaitTouchSlopOrCancellation(down.id) { change, over ->
                    val up = abs(over.y) > abs(over.x)
                    if (dir.takes(up)) { vertical = up; first = over; change.consume() }
                } ?: return@awaitEachGesture
                var acc = if (vertical) -first.y else first.x
                start()
                val limits = boundsNow()
                var atLimit = false
                fun clampAcc() {
                    if (limits == null) return
                    val c = acc.coerceIn(limits.first * stepPx, limits.last * stepPx)
                    if (c != acc) { if (!atLimit) { atLimit = true; limit() }; acc = c } else atLimit = false
                }
                clampAcc()
                fun finger(c: PointerInputChange) = coords?.takeIf { it.isAttached }?.let { if (magnifier?.screenSpace == true) it.localToScreen(c.position) else it.localToRoot(c.position) } ?: c.position
                if (loupeOn) { magnifier?.face = currentFace; magnifier?.finger = finger(claimed); magnifier?.shown = currentFace != null }
                drag(claimed.id) { change ->
                    val d = change.positionChange()
                    acc += if (vertical) -d.y else d.x
                    clampAcc()
                    change.consume()
                    slide((acc / stepPx).toInt())
                    if (magnifier?.shown == true) magnifier.finger = finger(change)
                }
                magnifier?.shown = false
                end()
            }
        },
    )
}

/**
 * Where the Magnifier draws: over the whole screen, above the finger, kept on screen. It takes no touches (no
 * handlers) and is hidden from TalkBack (the control says its own value). Grows out of the finger in 200 ms and
 * shrinks back in 150; with Reduce Motion it only fades.
 */
@Composable
fun MagnifierHost(state: MagnifierState, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val t = animatedFloat(if (state.shown) 1f else 0f, if (state.shown) Dur.FINGER else Dur.EXIT)
    val face = state.face
    if (face == null || (t.value <= 0.001f && !state.shown)) return
    val density = LocalDensity.current
    val lift = with(density) { 64.dp.roundToPx() }
    val margin = with(density) { 12.dp.roundToPx() }
    Box(modifier.fillMaxSize().clearAndSetSemantics { }) {
        Box(
            Modifier
                .layout { m, c ->
                    val p = m.measure(c.copy(minWidth = 0, minHeight = 0))
                    layout(c.maxWidth, c.maxHeight) {
                        val f = state.finger
                        val x = (f.x - p.width / 2f).coerceIn(margin.toFloat(), (c.maxWidth - margin - p.width).toFloat().coerceAtLeast(margin.toFloat()))
                        val y = (f.y - lift - p.height).coerceAtLeast(margin.toFloat())
                        p.place(x.toInt(), y.toInt())
                    }
                }
                .graphicsLayer {
                    alpha = t.value
                    if (!reduce) {
                        val s = 0.2f + 0.8f * t.value
                        scaleX = s; scaleY = s
                        // grows from the finger: the origin is where the finger is, relative to the plate
                        transformOrigin = TransformOrigin(0.5f, 1f)
                    }
                    shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(12.dp); clip = false
                    ambientShadowColor = Color.Black; spotShadowColor = Color.Black
                }
                .background(Tok.held, RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) { MagnifierPlate(face) }
    }
}

/** 1.6 times the column: label 18, value 36, and the ring or gauge. */
@Composable
private fun MagnifierPlate(face: MagnifierFace) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        if (face.ring) {
            val frac = face.fraction() ?: 0f
            Canvas(Modifier.size(44.dp)) {
                val w = 6.dp.toPx(); val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                drawArc(Tok.control, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                if (frac > 0.003f) drawArc(face.tint, 135f, 270f * frac, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
            }
        }
        Column {
            BasicText(face.label, style = LupeType.number.copy(fontSize = 18.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp), maxLines = 1)
            BasicText(face.value(), style = LupeType.number.copy(fontSize = 36.sp, lineHeight = 38.sp, color = Tok.text), maxLines = 1)
            val f = if (face.ring) null else face.fraction()
            if (f != null) Canvas(Modifier.padding(top = 4.dp).width(128.dp).height(5.dp)) {
                drawRect(Tok.stepEmpty)
                val x = f.coerceIn(0f, 1f) * size.width; val from = if (face.bipolar) size.width / 2 else 0f
                drawRect(face.tint, Offset(minOf(from, x), 0f), Size(maxOf(abs(x - from), if (face.bipolar) 2f else 0f), size.height))
            }
        }
    }
}

/**
 * The Magnifier for a control inside a pop-up window (a menu row): the activity's Magnifier layer is behind that
 * window, so this floats the plate in a small non-focusable pop-up of its own, above the finger (screen coordinates).
 */
@Composable
fun MagnifierPopup(state: MagnifierState) {
    val reduce = LocalReduceMotion.current
    val t = animatedFloat(if (state.shown) 1f else 0f, if (state.shown) Dur.FINGER else Dur.EXIT)
    val face = state.face
    if (face == null || (t.value <= 0.001f && !state.shown)) return
    val density = LocalDensity.current
    val lift = with(density) { 72.dp.roundToPx() }
    val margin = with(density) { 12.dp.roundToPx() }
    val f = state.finger
    val provider = remember(f) {
        object : androidx.compose.ui.window.PopupPositionProvider {
            override fun calculatePosition(anchorBounds: androidx.compose.ui.unit.IntRect, windowSize: androidx.compose.ui.unit.IntSize, layoutDirection: androidx.compose.ui.unit.LayoutDirection, popupContentSize: androidx.compose.ui.unit.IntSize) =
                androidx.compose.ui.unit.IntOffset(
                    (f.x - popupContentSize.width / 2f).toInt().coerceIn(margin, (windowSize.width - margin - popupContentSize.width).coerceAtLeast(margin)),
                    (f.y - lift - popupContentSize.height).toInt().coerceAtLeast(margin))
        }
    }
    androidx.compose.ui.window.Popup(provider, properties = androidx.compose.ui.window.PopupProperties(focusable = false, clippingEnabled = false)) {
        Box(
            Modifier.clearAndSetSemantics { }
                .graphicsLayer {
                    alpha = t.value
                    if (!reduce) { val s = 0.2f + 0.8f * t.value; scaleX = s; scaleY = s; transformOrigin = TransformOrigin(0.5f, 1f) }
                }
                .background(Tok.held, RoundedCornerShape(12.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
        ) { MagnifierPlate(face) }
    }
}

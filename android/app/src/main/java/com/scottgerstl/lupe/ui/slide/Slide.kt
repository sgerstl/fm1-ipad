package com.scottgerstl.lupe.ui.slide

import kotlinx.coroutines.launch

import androidx.compose.foundation.layout.fillMaxWidth

import androidx.compose.ui.draw.drawBehind

import androidx.compose.ui.unit.em

import androidx.compose.foundation.layout.widthIn

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
    /** The FM-1 knob that turns it (1–4): a badge at the plate's top right; null for none. */
    val knob: Int? = null,
    /** Values it can reach that may be wider than the one showing (its range's ends): the value's slot is sized to the widest, so the plate never changes width while you drag. */
    val widest: List<String> = emptyList(),
)

/** A plate's least width: a short value ("1") doesn't make a sliver (Scott, 2026-11-18: the magnifier "too wide for no reason"). */
internal const val PLATE_MIN_W = 120f

/**
 * The widths a value's slot must hold: the value now, its [MagnifierFace.widest] values, and the value now with every digit made the widest
 * digit (so 19 → 20 → 88 can't grow it) and, bipolar, a minus in front. The slot takes the widest of these and of any value shown so far.
 */
internal fun valueTemplates(value: String, widest: List<String>, bipolar: Boolean, wideDigit: Char): List<String> {
    val digits = value.map { if (it.isDigit()) wideDigit else it }.joinToString("")
    return listOfNotNull(value, digits, if (bipolar && !digits.startsWith("-")) "-$digits" else null) + widest
}

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
    /** Whose gesture has it up. A gesture that ends any way at all (finger up, pointer cancel, its control leaving the screen) takes its own down. */
    private var owner: Any? = null

    fun show(by: Any, face: MagnifierFace?, finger: Offset) { owner = by; this.face = face; this.finger = finger; shown = face != null }
    /** Down, if [by] is the one that put it up (a later gesture's Magnifier is not taken down by an earlier one ending late). */
    fun hide(by: Any) { if (owner === by) { shown = false; owner = null } }
    /** Down, whoever put it up: the tab changed, a panel or sheet left. */
    fun hideAll() { shown = false; owner = null }
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
    /**
     * Inside something that scrolls (Settings): claim the drag only once it is clearly along this control's axis (1.5 × the other way after touch
     * slop), so a mostly vertical drag passes to the scroll (Scott, 2026-11-17: sliders stole the scroll).
     */
    strictAxis: Boolean = false,
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
    // this control's own token: if it leaves the composition mid-slide (a tab change, a panel falling), its Magnifier goes with it
    val token = remember { Any() }
    androidx.compose.runtime.DisposableEffect(magnifier) { onDispose { magnifier?.hide(token) } }
    // a sideways slide at the screen's edge must not become the system's back gesture (P1's run, 2026-11-13)
    return this.onGloballyPositioned { coords = it }.then(
        if (!enabled) Modifier else (if (LocalBackGoesHome.current) Modifier else Modifier.systemGestureExclusion()).pointerInput(dir, stepPx) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                var vertical = false
                var first = Offset.Zero
                val claimed: PointerInputChange = awaitTouchSlopOrCancellation(down.id) { change, over ->
                    val up = abs(over.y) > abs(over.x)
                    val clear = !strictAxis || (if (up) abs(over.y) > 1.5f * abs(over.x) else abs(over.x) > 1.5f * abs(over.y))
                    if (clear && dir.takes(up)) { vertical = up; first = over; change.consume() }
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
                // whatever ends the slide (finger up, a pointer cancel, this control leaving the screen), the Magnifier comes down and the control hears onEnd
                try {
                    if (loupeOn) magnifier?.show(token, currentFace, finger(claimed))
                    drag(claimed.id) { change ->
                        val d = change.positionChange()
                        acc += if (vertical) -d.y else d.x
                        clampAcc()
                        change.consume()
                        slide((acc / stepPx).toInt())
                        if (magnifier?.shown == true) magnifier.finger = finger(change)
                    }
                } finally {
                    magnifier?.hide(token)
                    end()
                }
            }
        },
    )
}

/**
 * Where the Magnifier draws: over the whole screen, above the finger, kept 12 dp from the edges. It takes no touches (no handlers) and is
 * hidden from TalkBack (the control says its own value). The held control lifted at 1.6× (Scott approved, 2026-11-18; Figma 141:9654): it grows
 * out of the finger on the elastic spring (to about 1.03, then settles) and leaves faster than it came; with Reduce Motion it only fades.
 */
@Composable
fun MagnifierHost(state: MagnifierState, modifier: Modifier = Modifier) {
    val face = state.face
    val (alpha, scale) = magnifierMotion(state.shown)
    if (face == null || (alpha.value <= 0.001f && !state.shown)) return
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
                .graphicsLayer { this.alpha = alpha.value; scaleX = scale.value; scaleY = scale.value; transformOrigin = TransformOrigin(0.5f, 1f) },
        ) { MagnifierPlate(face) }
    }
}

/** The plate's fade and scale: in on the elastic spring (overshoot about 3 %), out in 120 ms; Reduce Motion: the fade alone. */
@Composable
internal fun magnifierMotion(shown: Boolean): Pair<androidx.compose.runtime.State<Float>, androidx.compose.runtime.State<Float>> {
    val reduce = LocalReduceMotion.current
    val a = remember { androidx.compose.animation.core.Animatable(0f) }
    val s = remember { androidx.compose.animation.core.Animatable(if (reduce) 1f else 0.6f) }
    androidx.compose.runtime.LaunchedEffect(shown, reduce) {
        com.scottgerstl.lupe.ui.theme.unscaled {
            kotlinx.coroutines.coroutineScope {
                if (shown) {
                    launch { a.animateTo(1f, androidx.compose.animation.core.tween(if (reduce) Dur.FINGER else 90)) }
                    if (reduce) s.snapTo(1f) else launch { s.animateTo(1f, androidx.compose.animation.core.spring(dampingRatio = MAGNIFIER_DAMPING, stiffness = 700f)) }
                } else {
                    launch { a.animateTo(0f, androidx.compose.animation.core.tween(if (reduce) Dur.EXIT else 120)) }
                    if (!reduce) launch { s.animateTo(0.6f, androidx.compose.animation.core.tween(120, easing = com.scottgerstl.lupe.ui.theme.EaseIn)) }
                }
            }
        }
    }
    return a.asState() to s.asState()
}
/** The spring's damping: its overshoot is about 3 % (e^(−ζπ/√(1−ζ²)) at 0.75). */
internal const val MAGNIFIER_DAMPING = 0.75f

/**
 * The plate (Figma 141:9654): `held`, corner 16, a 2 dp edge inside in the track's colour, no shadow; 13 top, 16 right and bottom, 19 left so it
 * sits optically centred. Top row: the label (Barlow 19, +4 % tracking; `text`, since `text2` on `held` is 4.13:1) and the knob's badge (28 on
 * `panel`). A tile: the value (Barlow Condensed Bold 42) and a 6 dp track across the plate. A dial: the flat arc dial at 64 with the value beside it.
 */
@Composable
internal fun MagnifierPlate(face: MagnifierFace) {
    val shape = RoundedCornerShape(16.dp)
    // the plate hugs its content (2026-11-18): the label row or the value's slot, whichever is wider, never under [PLATE_MIN_W]
    Column(
        Modifier.widthIn(min = PLATE_MIN_W.dp).width(androidx.compose.foundation.layout.IntrinsicSize.Max).background(Tok.held, shape)
            .drawBehind { val w = 2.dp.toPx(); drawRoundRect(face.tint, Offset(w / 2, w / 2), Size(size.width - w, size.height - w), androidx.compose.ui.geometry.CornerRadius(16.dp.toPx() - w / 2), style = Stroke(w)) }
            .padding(start = 19.dp, top = 13.dp, end = 16.dp, bottom = 16.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            BasicText(face.label, Modifier.padding(end = 10.dp),
                style = LupeType.body.copy(fontSize = 19.sp, lineHeight = 22.sp, color = Tok.text, letterSpacing = 0.04.em), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            androidx.compose.foundation.layout.Spacer(Modifier.weight(1f, fill = true))
            face.knob?.let { k ->
                Box(Modifier.size(28.dp).background(Tok.panel, androidx.compose.foundation.shape.CircleShape), contentAlignment = Alignment.Center) {
                    BasicText("$k", style = LupeType.number.copy(fontSize = 19.sp, lineHeight = 19.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, color = Tok.text))
                }
            }
        }
        androidx.compose.foundation.layout.Spacer(Modifier.height(6.dp))
        val valueStyle = LupeType.number.copy(fontSize = 42.sp, lineHeight = 44.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, color = Tok.text)
        // the value's slot: as wide as the widest value this control can show, so dragging never changes the plate's width
        val tm = androidx.compose.ui.text.rememberTextMeasurer()
        val density = androidx.compose.ui.platform.LocalDensity.current
        val seen = remember(face) { floatArrayOf(0f) }
        val now = face.value()
        val wideDigit = remember(tm) { ('0'..'9').maxBy { tm.measure("$it", valueStyle).size.width } }
        val slotPx = valueTemplates(now, face.widest, face.bipolar, wideDigit).maxOf { tm.measure(it, valueStyle).size.width.toFloat() }
        seen[0] = maxOf(seen[0], slotPx)
        val slot = with(density) { seen[0].toDp() }
        if (face.ring) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                val frac = face.fraction() ?: 0f
                // the sound panel's flat arc dial at 64: a ring 0.86 inside, swept 270°, `control` with the value's arc in the track colour
                Canvas(Modifier.size(64.dp)) {
                    val w = size.minDimension / 2f * (1f - 0.86f)      // inner radius 0.86 of the outer
                    val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                    drawArc(Tok.control, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                    if (frac > 0.003f) drawArc(face.tint, 135f, 270f * frac.coerceIn(0f, 1f), false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                }
                BasicText(now, Modifier.widthIn(min = slot), style = valueStyle, maxLines = 1, softWrap = false)
            }
        } else {
            BasicText(now, Modifier.widthIn(min = slot), style = valueStyle, maxLines = 1, softWrap = false)
            val f = face.fraction()
            if (f != null) Canvas(Modifier.padding(top = 8.dp).fillMaxWidth().height(6.dp)) {
                val r = androidx.compose.ui.geometry.CornerRadius(3.dp.toPx())
                drawRoundRect(Tok.control, cornerRadius = r)
                val x = f.coerceIn(0f, 1f) * size.width; val from = if (face.bipolar) size.width / 2 else 0f
                drawRoundRect(face.tint, Offset(minOf(from, x), 0f), Size(maxOf(abs(x - from), if (face.bipolar) 3.dp.toPx() else 0f), size.height), r)
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
    val face = state.face
    val (alpha, scale) = magnifierMotion(state.shown)
    if (face == null || (alpha.value <= 0.001f && !state.shown)) return
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
                .graphicsLayer { this.alpha = alpha.value; scaleX = scale.value; scaleY = scale.value; transformOrigin = TransformOrigin(0.5f, 1f) },
        ) { MagnifierPlate(face) }
    }
}

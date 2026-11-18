package com.scottgerstl.lupe.ui.page

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.input.pointer.pointerInput
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.slideToTurn
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.unscaled

/** The dial's ring, and the touch target around it and its label. */
val DIAL_RING = 52.dp
/** The dial's whole box: the ring, 4 dp, the label. Its touch target. */
val DIAL_W = 84.dp
val DIAL_H = 74.dp

/**
 * One round dial (board 70, decision 25): the value inside the ring, the label under it, ◆ before the label when this step locks
 * it. The ring goes white while a finger slides it and for 600 ms after the FM-1 turns it. A picker's knob 1 (ringless) and a fixed
 * value draw without a ring and don't turn. The gesture is [KnobTarget]'s: direction setting, Magnifier, double tap back, TalkBack.
 */
@Composable
fun RoundDial(slot: Int, c: PageControl, colour: Color, litKey: Int, kc: KnobControls) {
    val reduce = LocalReduceMotion.current
    val lit = remember { Animatable(0f) }
    var sliding by remember { mutableStateOf(false) }
    LaunchedEffect(litKey) {
        if (litKey < 0) return@LaunchedEffect
        unscaled { lit.animateTo(1f, tween(if (reduce) 0 else 80)); lit.animateTo(0f, tween(LIT_FADE_MS, easing = EaseOut)) }
    }
    val on = if (sliding) 1f else lit.value
    val frac = if (c.max > c.min) (c.raw - c.min).toFloat() / (c.max - c.min) else 0f
    val editable = !c.ringless && !c.fixed
    Box(Modifier.size(width = DIAL_W, height = DIAL_H), contentAlignment = Alignment.TopCenter) {
        DialFace(c.label, c.value, if (c.ringless) null else frac, colour, on, locked = c.locked, dim = c.fixed)
        if (editable) KnobTarget(slot, kc, Modifier, DIAL_W, DIAL_H, onHot = { sliding = it })
    }
}

/** What a dial draws (no gesture, hidden from TalkBack: the target over it speaks): the ring with the value inside, the label under. [frac] null draws no ring. */
@Composable
fun DialFace(label: String, value: String, frac: Float?, colour: Color, on: Float, locked: Boolean = false, dim: Boolean = false, bipolar: Boolean = false) {
    val ring = lerp(colour, Tok.text, on)
    Column(Modifier.clearAndSetSemantics { }, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(DIAL_RING), contentAlignment = Alignment.Center) {
            if (frac != null) Canvas(Modifier.fillMaxSize().padding(2.dp)) {
                val w = 5.dp.toPx(); val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                drawArc(Tok.control, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                val f = frac.coerceIn(0f, 1f)
                if (bipolar) { val from = 135f + 135f; drawArc(ring, minOf(from, 135f + 270f * f), kotlin.math.abs(270f * f - 135f).coerceAtLeast(2f), false, tl, sz, style = Stroke(w, cap = StrokeCap.Round)) }
                else if (f > 0.003f) drawArc(ring, 135f, 270f * f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
            }
            FittedDialValue(value, if (dim) Tok.text2 else Tok.text, key = label)
        }
        Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            if (locked) { Diamond(colour); Box(Modifier.width(4.dp)) }
            BasicText(label, style = LupeType.number.copy(fontSize = 12.sp, lineHeight = 14.sp, color = lerp(if (dim) Tok.text2 else Tok.text2Raised, Tok.text, on), letterSpacing = 0.5.sp), maxLines = 1)
        }
    }
}

/**
 * A dial that turns by steps rather than to a value (the step panel's: PITCH, MOVE, LENGTH…; the core's StepAdjust takes deltas). The same
 * slide (direction setting, Magnifier), a double tap back to what it was when [key] last changed, TalkBack Increase, Decrease and Put back.
 * [num]/[min]/[max] give the ring and the slide's ends; [unit] is how much of the value one step is.
 */
@Composable
fun DeltaDial(
    label: String, value: String, name: String, tint: Color, key: Any, dpPerStep: Float, tick: Boolean, locked: Boolean,
    num: Int? = null, min: Int = 0, max: Int = 0, bipolar: Boolean = false, unit: Int = 1, limitWord: String? = null, enabled: Boolean = true, onSteps: (Int) -> Unit,
) {
    val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
    val send by androidx.compose.runtime.rememberUpdatedState(onSteps)
    var net by remember(key) { mutableStateOf(0) }
    var last by remember { mutableStateOf(0) }
    var hot by remember { mutableStateOf(false) }
    val fraction = if (num != null && max > min) (num - min).toFloat() / (max - min) else null
    val shown by androidx.compose.runtime.rememberUpdatedState(value)
    val frac by androidx.compose.runtime.rememberUpdatedState(fraction)
    fun step(d: Int) { if (d == 0) return; net += d; send(d); if (tick) haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.SegmentTick) }
    val range = if (num != null) ", range $min to $max" else ""
    Box(Modifier.size(width = DIAL_W, height = DIAL_H), contentAlignment = Alignment.TopCenter) {
        DialFace(label, value, fraction ?: 0f, tint, if (hot) 1f else 0f, locked = locked, dim = !enabled, bipolar = bipolar)
        if (enabled) Box(
            Modifier.fillMaxSize()
                .semantics {
                    contentDescription = name + if (locked) ", locked on this step" else ""
                    stateDescription = value + range + (limitWord?.let { ", can't grow: $it" } ?: "")
                    role = androidx.compose.ui.semantics.Role.Button
                    if (num != null) {
                        progressBarRangeInfo = androidx.compose.ui.semantics.ProgressBarRangeInfo(num.toFloat(), min.toFloat()..max.toFloat(), max - min - 1)
                        setProgress { v -> step((kotlin.math.round(v).toInt() - num) / unit); true }
                    }
                    customActions = listOf(
                        androidx.compose.ui.semantics.CustomAccessibilityAction("Increase $name") { step(1); true },
                        androidx.compose.ui.semantics.CustomAccessibilityAction("Decrease $name") { step(-1); true },
                        androidx.compose.ui.semantics.CustomAccessibilityAction("Put $name back as it was") { val b = -net; net = 0; send(b); true },
                    )
                }
                .pointerInput(key) { detectTapGestures(onDoubleTap = { val b = -net; net = 0; if (b != 0) { send(b); haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.Confirm) } }) }
                .slideToTurn(
                    enabled = true, stepDp = dpPerStep,
                    face = remember(label, tint) { MagnifierFace(label, { shown }, { frac }, bipolar, ring = true, tint = tint) },
                    onStart = { last = 0; hot = true },
                    onSlide = { total -> step(total - last); last = total },
                    onEnd = { hot = false },
                    bounds = { num?.let { n -> -((n - min) / unit)..((max - n) / unit) } },
                    onLimit = { haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.ContextClick) },
                ),
        )
    }
}

/**
 * The value inside the ring: 18 sp shrinking one step at a time to fit the ring's inner width, floor 13 sp. A list value too long even
 * then ("GOSPEL" on a WHEEL track) is cut to the letters that fit, as the FM-1 does with its short forms.
 */
@Composable
fun FittedDialValue(value: String, color: Color, key: Any? = null) {
    val tm = androidx.compose.ui.text.rememberTextMeasurer()
    val density = androidx.compose.ui.platform.LocalDensity.current
    val inner = with(density) { 38.dp.roundToPx() }
    val base = LupeType.number.copy(color = color, textAlign = TextAlign.Center)
    fun fits(t: String, sp: Int) = tm.measure(t, base.copy(fontSize = sp.sp), maxLines = 1, softWrap = false).size.width <= inner
    // the size only steps down while the dial shows the same control, never back up as the value turns: per control, never per value
    // (Scott, 2026-11-17: the numbers jumped while a value changed, "-12" at 18 sp and "-120" at 16)
    var cap by remember(key) { androidx.compose.runtime.mutableIntStateOf(18) }
    var size = 13; var text = value
    for (sp in cap downTo 13) if (fits(value, sp)) { size = sp; break }
    if (size < cap) androidx.compose.runtime.SideEffect { cap = size }
    if (!fits(value, size)) { var n = value.length; while (n > 1 && !fits(value.take(n), 13)) n-- ; text = value.take(n) }
    BasicText(text, style = base.copy(fontSize = size.sp, lineHeight = size.sp), maxLines = 1, softWrap = false)
}

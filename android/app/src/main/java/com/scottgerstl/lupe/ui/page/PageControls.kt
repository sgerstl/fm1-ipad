package com.scottgerstl.lupe.ui.page

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

/** How long the FM-1's knob keeps its control lit after the last turn: it fades over this (map: "lit-while-the-FM-1-turns, 600 ms"). PROVISIONAL: Labs candidate (CLAUDE.md rule 3). */
const val LIT_FADE_MS = 600

/** A drag of this many dp moves the value one step: about 2 dp for a 0–127 range, wider where there are few steps (a list). PROVISIONAL, Labs candidate. */
private fun stepDp(c: PageControl): Float = if (c.max - c.min >= 64) 2f else if (c.max - c.min >= 16) 6f else 20f

/** The row of four. [litSeq] / [litSlot] come from the page area (the FM-1's knob turning). */
@Composable
fun PageControlsRow(
    controls: List<PageControl?>, colour: Color, litSlot: Int, litSeq: Int, opened: (Int, PageControl) -> Int,
    onSet: (slot: Int, value: Int) -> Unit, modifier: Modifier = Modifier,
) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        for (slot in 0 until 4) {
            val c = controls.getOrNull(slot)
            Box(Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
                if (c == null) EmptyWell(slot) else PageKnob(slot, c, colour, if (slot == litSlot) litSeq else -1, opened(slot, c)) { onSet(slot, it) }
            }
        }
    }
}

/** An FM-1 knob with no parameter on this page (0xFF): the well stays so knob 3 is always knob 3. Hidden from TalkBack. */
@Composable
private fun EmptyWell(slot: Int) {
    Column(Modifier.width(96.dp).clearAndSetSemantics { }, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.padding(top = 6.dp).size(RING_BOX - 8.dp).clip(CircleShape).background(Tok.well))
    }
}

private val RING_BOX = 64.dp

@Composable
private fun PageKnob(slot: Int, c: PageControl, colour: Color, litKey: Int, openedRaw: Int, onSet: (Int) -> Unit) {
    val reduce = LocalReduceMotion.current
    val haptic = LocalHapticFeedback.current
    val lit = remember { Animatable(0f) }
    // lit while the FM-1 turns: it comes on at once, then fades 600 ms after the last turn
    LaunchedEffect(litKey) {
        if (litKey < 0) return@LaunchedEffect
        unscaled { lit.animateTo(1f, tween(if (reduce) 0 else 80)); lit.animateTo(0f, tween(LIT_FADE_MS, easing = EaseOut)) }
    }
    // an optimistic value while a finger moves it: the ring follows at once; the FM-1's answer then settles the words
    var optimistic by remember { mutableIntStateOf(Int.MIN_VALUE) }
    LaunchedEffect(c.raw) { if (optimistic == c.raw) optimistic = Int.MIN_VALUE }
    val raw = if (optimistic != Int.MIN_VALUE) optimistic else c.raw
    var armed by remember { mutableStateOf(false) }
    LaunchedEffect(armed, raw) { if (armed) { delay(3500); armed = false } }

    val editable = !c.ringless && !c.fixed
    // The value right now, read from state rather than from `raw` (fixed at the last recomposition): taps that come
    // faster than a frame each add their step instead of all adding to the same old value (adb taps lost steps,
    // 2026-11-13).
    val latest by rememberUpdatedState(c)   // the gesture blocks outlive recompositions: read the control through this
    val latestOnSet by rememberUpdatedState(onSet)
    fun now() = if (optimistic != Int.MIN_VALUE) optimistic else latest.raw
    fun set(v: Int) {
        val n = v.coerceIn(c.min, c.max)
        if (n == now()) { if (v != n) haptic.performHapticFeedback(HapticFeedbackType.ContextClick) ; return }   // at an end
        optimistic = n
        if (c.list || n == c.min || n == c.max) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
        latestOnSet(n)
    }

    val litF = lit.value
    val frac = if (c.max > c.min) (raw - c.min).toFloat() / (c.max - c.min) else 0f
    val ring = lerp(colour, Tok.text, litF)
    val labelColour = lerp(if (c.fixed) Tok.text2 else Tok.text2Raised, Tok.text, litF)
    val valueColour = if (c.fixed) Tok.text2 else Tok.text
    val spoken = c.label + (if (c.locked) ", locked on this step" else "")

    Column(
        Modifier.width(96.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = spoken
                stateDescription = c.value + if (c.fixed) ", fixed" else ""
                if (editable) {
                    role = Role.Button
                    progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), c.min.toFloat()..c.max.toFloat(), c.max - c.min - 1)
                    setProgress { v -> set(v.roundToInt()); true }
                    customActions = listOf(
                        CustomAccessibilityAction("Increase $spoken") { set(now() + 1); true },
                        CustomAccessibilityAction("Decrease $spoken") { set(now() - 1); true },
                        CustomAccessibilityAction("Put $spoken back to ${openedRaw}") { set(openedRaw); true },
                    )
                }
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      // Tap, double tap and drag belong to the ring, label and value only. The − / + keys sat inside the same
      // tap detector, so quick taps on + read as a double tap on the control, which puts the value back
      // (Scott's run 2026-11-13: five taps on + raised ATTACK by 3; over adb by 0).
      Column(Modifier.fillMaxWidth().then(if (!editable) Modifier else Modifier
                .pointerInput(c.max, c.min, openedRaw) {
                    detectTapGestures(onTap = { armed = !armed }, onDoubleTap = { armed = false; set(openedRaw) })
                }
                .pointerInput(c.max, c.min) {
                    var acc = 0f; var base = 0
                    detectVerticalDragGestures(
                        onDragStart = { acc = 0f; base = now(); armed = false },
                        onDragEnd = { }, onDragCancel = { },
                    ) { change, dy ->
                        change.consume()
                        acc -= dy   // up is more
                        set(base + (acc / (stepDp(c).dp.toPx())).toInt())
                    }
                }), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(RING_BOX).padding(top = 2.dp), contentAlignment = Alignment.Center) {
            if (!c.ringless) Canvas(Modifier.fillMaxSize().padding(4.dp)) {
                val w = 5.dp.toPx()
                val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                drawArc(Tok.control, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                if (frac > 0.003f) drawArc(ring, 135f, 270f * frac, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
            if (c.locked) { Diamond(colour); Box(Modifier.width(4.dp)) }
            BasicText(c.label, style = LupeType.number.copy(fontSize = 12.sp, color = labelColour, letterSpacing = 0.5.sp), maxLines = 1, overflow = TextOverflow.Clip)
        }
        // the value: 24 (shrinking to 18 for a long name), and 30 while the FM-1 turns it
        val grow = if (reduce) 1f else 1f + 0.25f * litF
        Box(Modifier.height(34.dp).fillMaxWidth().graphicsLayer { scaleX = grow; scaleY = grow }, contentAlignment = Alignment.Center) {
            BasicText(
                c.value, Modifier.padding(horizontal = 2.dp),
                style = LupeType.number.copy(fontSize = 24.sp, color = valueColour, textAlign = TextAlign.Center),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                autoSize = TextAutoSize.StepBased(minFontSize = 18.sp, maxFontSize = 24.sp, stepSize = 1.sp),
            )
        }
      }
        // − / + under the value after a tap (board 59): one step at a time
        Row(Modifier.height(48.dp).fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            if (armed && editable) {
                StepButton("−", "Decrease $spoken") { set(now() - 1); armed = true }
                StepButton("+", "Increase $spoken") { set(now() + 1); armed = true }
            }
        }
    }
}

@Composable
private fun StepButton(glyph: String, description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(48.dp).padding(2.dp).clip(RoundedCornerShape(8.dp)).background(Tok.control)
            .semantics { contentDescription = description; role = Role.Button }
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { BasicText(glyph, style = LupeType.number.copy(fontSize = 22.sp)) }
}

/** ◆ drawn, not a glyph from a font: a step's lock on this control. */
@Composable
fun Diamond(colour: Color, modifier: Modifier = Modifier) = Canvas(modifier.size(9.dp)) {
    drawPath(Path().apply { moveTo(size.width / 2, 0f); lineTo(size.width, size.height / 2); lineTo(size.width / 2, size.height); lineTo(0f, size.height / 2); close() }, colour)
}

package com.scottgerstl.lupe.ui.page

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
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
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.slideToTurn
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

/**
 * The row of four dials (decision 25: the sound page is the page row, a header, tiles if any, and these). Round, as the FM-1's are and as
 * board 70's HOME knobs: the value inside the ring, the label under it. Slide to turn (the direction setting, the Magnifier), double tap
 * back to where the page opened. [litSlot] / [litSeq] come from the page area (the FM-1's knob turning): the ring goes white.
 */
@Composable
fun PageControlsRow(
    controls: List<PageControl?>, colour: Color, litSlot: Int, litSeq: Int, opened: (Int, PageControl) -> Int,
    onSet: (slot: Int, value: Int) -> Unit, modifier: Modifier = Modifier,
) {
    val kc = KnobControls(controls, colour, opened, onSet)
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        for (slot in 0 until 4) {
            Box(Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
                val c = controls.getOrNull(slot)
                if (c == null) Box(Modifier.size(DIAL_W, DIAL_H))   // an FM-1 knob with no parameter on this page (0xFF): the well stays so knob 3 is always knob 3
                else RoundDial(slot, c, colour, if (slot == litSlot) litSeq else -1, kc)
            }
        }
    }
}

/** The four dials two by two (the Mix pop-up, board 77): knob 1 and 2 above 3 and 4. A knob the page doesn't use is an outlined well, so knob 3 is always knob 3. */
@Composable
fun PageControlsGrid(
    controls: List<PageControl?>, colour: Color, opened: (Int, PageControl) -> Int, onSet: (slot: Int, value: Int) -> Unit, modifier: Modifier = Modifier,
) {
    val kc = KnobControls(controls, colour, opened, onSet)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        for (row in 0 until 2) Row(Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (slot in row * 2 until row * 2 + 2) {
                val c = controls.getOrNull(slot)
                Box(
                    Modifier.weight(1f).fillMaxHeight().then(
                        if (c == null) Modifier.drawBehind { drawRoundRect(Tok.outline, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(9.25.dp.toPx()), style = Stroke(1.5.dp.toPx())) }.clearAndSetSemantics { }
                        else Modifier.background(Tok.control, RoundedCornerShape(10.dp)),
                    ),
                    contentAlignment = Alignment.Center,
                ) { if (c != null) RoundDial(slot, c, colour, -1, kc) }
            }
        }
    }
}

/** ◆ drawn, not a glyph from a font: a step's lock on this control. */
@Composable
fun Diamond(colour: Color, modifier: Modifier = Modifier) = Canvas(modifier.size(9.dp)) {
    drawPath(Path().apply { moveTo(size.width / 2, 0f); lineTo(size.width, size.height / 2); lineTo(size.width / 2, size.height); lineTo(0f, size.height / 2); close() }, colour)
}


/** What a picture needs to turn one of the page's controls: the control (by its FM-1 knob slot), where it opened, and how to send it. */
class KnobControls(val controls: List<PageControl?>, val colour: Color, val opened: (Int, PageControl) -> Int, val onSet: (Int, Int) -> Unit) {
    /** The slot whose control is called [label], or -1 (EDIT 1's CUTOFF and RES sit in different knobs on other engines). */
    fun slotOf(label: String) = controls.indexOfFirst { it?.label == label }
}

/**
 * A place in a picture that stands for one of the page's controls (decision 22): an invisible 44 dp target over the
 * drawn slider or handle, turned exactly as the knob below it is: the Slide-to-turn direction, the Magnifier, a double
 * tap back to where the page opened, the same steps per dp, the same TalkBack range and actions. Draws nothing.
 */
@Composable
fun KnobTarget(slot: Int, pc: KnobControls, modifier: Modifier = Modifier, width: androidx.compose.ui.unit.Dp = 44.dp, height: androidx.compose.ui.unit.Dp = 44.dp, onHot: (Boolean) -> Unit = {}) {
    val hotNow by rememberUpdatedState(onHot)
    val c = pc.controls.getOrNull(slot) ?: return
    if (c.ringless || c.fixed) return
    val haptic = LocalHapticFeedback.current
    var optimistic by remember { mutableIntStateOf(Int.MIN_VALUE) }
    LaunchedEffect(c.raw) { if (optimistic == c.raw) optimistic = Int.MIN_VALUE }
    val latest by rememberUpdatedState(c)
    val send by rememberUpdatedState(pc.onSet)
    val openedRaw = pc.opened(slot, c)
    var base by remember { mutableIntStateOf(0) }
    fun now() = if (optimistic != Int.MIN_VALUE) optimistic else latest.raw
    fun set(v: Int) {
        val n = v.coerceIn(c.min, c.max)
        if (n == now()) return
        optimistic = n
        if (c.list || n == c.min || n == c.max) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
        send(slot, n)
    }
    val colour = pc.colour
    Box(
        modifier.size(width, height)
            .semantics {
                contentDescription = c.label; stateDescription = c.value; role = Role.Button
                progressBarRangeInfo = ProgressBarRangeInfo(now().toFloat(), c.min.toFloat()..c.max.toFloat(), c.max - c.min - 1)
                setProgress { v -> set(v.roundToInt()); true }
                customActions = listOf(
                    CustomAccessibilityAction("Increase ${c.label}") { set(now() + 1); true },
                    CustomAccessibilityAction("Decrease ${c.label}") { set(now() - 1); true },
                    CustomAccessibilityAction("Put ${c.label} back to $openedRaw") { set(openedRaw); true },
                )
            }
            .pointerInput(c.max, c.min, openedRaw) { detectTapGestures(onDoubleTap = { set(openedRaw) }) }
            .slideToTurn(
                enabled = true, stepDp = stepDp(c),
                face = remember(c.label, colour) { MagnifierFace(c.label, { latest.value }, { val l = latest; if (l.max > l.min) (now() - l.min).toFloat() / (l.max - l.min) else 0f }, ring = true, tint = colour, knob = slot + 1) },
                onStart = { base = now(); hotNow(true) },
                onSlide = { steps -> set(base + steps) },
                onEnd = { hotNow(false) },
            ),
    )
}

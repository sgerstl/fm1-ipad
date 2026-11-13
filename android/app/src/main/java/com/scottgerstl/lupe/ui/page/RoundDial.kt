package com.scottgerstl.lupe.ui.page

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
val DIAL_RING = 60.dp

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
    val ring = lerp(colour, Tok.text, on)
    val frac = if (c.max > c.min) (c.raw - c.min).toFloat() / (c.max - c.min) else 0f
    val editable = !c.ringless && !c.fixed
    Box(Modifier.size(width = 84.dp, height = 88.dp), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.clearAndSetSemantics { }, horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(DIAL_RING), contentAlignment = Alignment.Center) {
                if (!c.ringless) Canvas(Modifier.fillMaxSize().padding(2.dp)) {
                    val w = 5.dp.toPx(); val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                    drawArc(Tok.control, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                    if (frac > 0.003f) drawArc(ring, 135f, 270f * frac, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                }
                FittedDialValue(c.value, if (c.fixed) Tok.text2 else Tok.text)
            }
            Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                if (c.locked) { Diamond(colour); Box(Modifier.width(4.dp)) }
                BasicText(c.label, style = LupeType.number.copy(fontSize = 12.sp, color = lerp(if (c.fixed) Tok.text2 else Tok.text2Raised, Tok.text, on), letterSpacing = 0.5.sp), maxLines = 1)
            }
        }
        if (editable) KnobTarget(slot, kc, Modifier, 84.dp, 88.dp, onHot = { sliding = it })
    }
}

/**
 * The value inside the ring: 22 sp shrinking one step at a time to fit the ring's inner width, floor 13 sp. A list value too long even
 * then ("GOSPEL" on a WHEEL track) is cut to the letters that fit, as the FM-1 does with its short forms.
 */
@Composable
fun FittedDialValue(value: String, color: Color) {
    val tm = androidx.compose.ui.text.rememberTextMeasurer()
    val density = androidx.compose.ui.platform.LocalDensity.current
    val inner = with(density) { 46.dp.roundToPx() }
    val base = LupeType.number.copy(color = color, textAlign = TextAlign.Center)
    fun fits(t: String, sp: Int) = tm.measure(t, base.copy(fontSize = sp.sp), maxLines = 1, softWrap = false).size.width <= inner
    var size = 13; var text = value
    for (sp in 22 downTo 13) if (fits(value, sp)) { size = sp; break }
    if (!fits(value, size)) { var n = value.length; while (n > 1 && !fits(value.take(n), 13)) n-- ; text = value.take(n) }
    BasicText(text, style = base.copy(fontSize = size.sp, lineHeight = size.sp), maxLines = 1, softWrap = false)
}

package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.HomeKnobsState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.SetHomeKnob
import com.scottgerstl.lupe.ui.page.LIT_FADE_MS
import com.scottgerstl.lupe.ui.page.PictureControls
import com.scottgerstl.lupe.ui.page.PictureSlider
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.unscaled

/**
 * The strip under the step grid while no step is picked (decision 21, board 70): the selected track's four sound knobs,
 * the same four the FM-1's knobs turn on HOME, drawn round with the value in the ring and the label under it. It is the
 * step panel's height (122 dp), so the grid never changes size between the two. Each knob is the sound pages' control:
 * slide to turn (the direction setting, the Magnifier), double tap back to where the row stood when the editor opened;
 * it lights white while it turns, from the phone or the FM-1.
 */
@Composable
fun HomeKnobsStrip(ed: EditorState, core: LupeCore, modifier: Modifier = Modifier) {
    val home by core.homeKnobs.collectAsStateWithLifecycle()
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    // the value each knob had when the strip appeared: what a double tap puts back (the FM-1 has no per-sound factory value)
    val opened = remember(ed.track, home.engine) { mutableMapOf<Int, Int>() }
    val pc = PictureControls(home.controls, track, { slot, c -> opened.getOrPut(slot) { c.raw } }) { slot, v -> core.send(SetHomeKnob(slot, v)) }
    Column(modifier.fillMaxWidth().height(STRIP_HEIGHT)) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            BasicText("Sound", Modifier.semantics { heading() }, style = LupeType.key)
            if (home.engine.isNotEmpty()) BasicText(home.engine, Modifier.padding(start = 8.dp), style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1)
            if (home.preset.isNotEmpty()) BasicText("· ${home.preset}", Modifier.padding(start = 4.dp), style = LupeType.small, maxLines = 1)
        }
        Row(Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.SpaceBetween) {
            for (slot in 0 until 4) Box(Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
                val c = home.controls.getOrNull(slot)
                if (c == null) Box(Modifier.size(KNOB))   // an empty well keeps knob 3 knob 3
                else RoundKnob(slot, c.label, c.value, c.raw, c.min, c.max, track, if (slot == home.hot) home.hotSeq else -1, pc)
            }
        }
    }
}

internal val STRIP_HEIGHT = 122.dp
private val KNOB = 60.dp

@Composable
private fun RoundKnob(slot: Int, label: String, value: String, raw: Int, min: Int, max: Int, track: androidx.compose.ui.graphics.Color, litKey: Int, pc: PictureControls) {
    val reduce = LocalReduceMotion.current
    val lit = remember { Animatable(0f) }
    var sliding by remember { mutableStateOf(false) }
    // the FM-1 turned it: white at once, then fading over 600 ms (the sound pages' rule); while a finger slides it, white throughout
    LaunchedEffect(litKey) {
        if (litKey < 0) return@LaunchedEffect
        unscaled { lit.animateTo(1f, tween(if (reduce) 0 else 80)); lit.animateTo(0f, tween(LIT_FADE_MS, easing = EaseOut)) }
    }
    val on = if (sliding) 1f else lit.value
    val ring = lerp(track, Tok.text, on)
    val frac = if (max > min) (raw - min).toFloat() / (max - min) else 0f
    Box(Modifier.size(width = 84.dp, height = 88.dp), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.clearAndSetSemantics { }, horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(KNOB), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize().padding(2.dp)) {
                    val w = 5.dp.toPx(); val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                    drawArc(Tok.control, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                    if (frac > 0.003f) drawArc(ring, 135f, 270f * frac, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                }
                BasicText(
                    value, Modifier.padding(horizontal = 10.dp),
                    style = LupeType.number.copy(fontSize = 22.sp, color = Tok.text, textAlign = TextAlign.Center), maxLines = 1,
                    autoSize = TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 22.sp, stepSize = 1.sp),
                )
            }
            BasicText(label, Modifier.padding(top = 4.dp), style = LupeType.number.copy(fontSize = 12.sp, color = lerp(Tok.text2Raised, Tok.text, on), letterSpacing = 0.5.sp), maxLines = 1)
        }
        // the whole knob and its label is the target; it says its own name and value to TalkBack
        PictureSlider(slot, pc, Modifier, 84.dp, 88.dp, onHot = { sliding = it })
    }
}

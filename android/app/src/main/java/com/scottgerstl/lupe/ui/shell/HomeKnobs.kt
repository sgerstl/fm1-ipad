package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import com.scottgerstl.lupe.ui.page.KnobControls
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.unscaled

/**
 * The dials area while no step is picked (decision 21, board 70; landscape board 73 note 4): the selected track's four sound knobs,
 * the same four the FM-1's knobs turn on HOME, as round dials. Slide to turn (the direction setting, the Magnifier), double tap back to
 * where the row stood when it appeared; a dial lights white while it turns, from the phone or the FM-1. [header] off leaves only the
 * dials (the kit's shorter area; the ruler above already names the track).
 */
@Composable
fun HomeKnobsStrip(ed: EditorState, core: LupeCore, modifier: Modifier = Modifier, header: Boolean = true) {
    val home by core.homeKnobs.collectAsStateWithLifecycle()
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    // the value each knob had when the strip appeared: what a double tap puts back (the FM-1 has no per-sound factory value)
    val opened = remember(ed.track, home.engine) { mutableMapOf<Int, Int>() }
    Column(modifier) {
        if (header) {
            Row(Modifier.fillMaxWidth().height(32.dp).padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                BasicText("Sound", Modifier.semantics { heading() }, style = LupeType.key)
                if (home.engine.isNotEmpty()) BasicText(home.engine, Modifier.padding(start = 8.dp), style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1)
                if (home.preset.isNotEmpty()) BasicText("· ${home.preset}", Modifier.padding(start = 4.dp), style = LupeType.small, maxLines = 1)
            }
            Spacer(Modifier.height(4.dp))
        }
        com.scottgerstl.lupe.ui.page.PageControlsRow(home.controls, track, home.hot, home.hotSeq, opened = { slot, c -> opened.getOrPut(slot) { c.raw } }, onSet = { slot, v -> core.send(SetHomeKnob(slot, v)) })
    }
}

/** The scene row's HOME knob: width and ring as the iPad's (decision 50); the iPhone's numbers replace these if they differ. */
val HOME_KNOB_W = 100.dp
private val HOME_KNOB_GAP = 4.dp

/**
 * The selected track's four HOME knobs at the end of the Pads scene row (decision 50): each a well with a ring in the track's colour
 * and, beside it, the label over the value. Turned by the app's slide (the same [KnobTarget] as the sound page's dials, so the Magnifier,
 * double tap back and TalkBack come with it), and the FM-1's own knob lights it, white, for a moment. None before the FM-1 is read.
 */
@Composable
fun SceneHomeKnobs(core: LupeCore, height: androidx.compose.ui.unit.Dp, modifier: Modifier = Modifier) {
    val home by core.homeKnobs.collectAsStateWithLifecycle()
    if (home.controls.none { it != null }) return
    val colour = Tok.track[(home.track - 1).coerceAtLeast(0) % Tok.track.size]
    val opened = remember(home.track, home.engine) { mutableMapOf<Int, Int>() }
    val kc = com.scottgerstl.lupe.ui.page.KnobControls(home.controls, colour, { slot, c -> opened.getOrPut(slot) { c.raw } }, { slot, v -> core.send(SetHomeKnob(slot, v)) })
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(HOME_KNOB_GAP)) {
        for (slot in 0 until 4) {
            val c = home.controls.getOrNull(slot)
            if (c == null) Spacer(Modifier.size(HOME_KNOB_W, height))
            else SceneHomeKnob(slot, c, colour, if (slot == home.hot) home.hotSeq else -1, kc, height)
        }
    }
}

@Composable
private fun SceneHomeKnob(slot: Int, c: com.scottgerstl.lupe.core.PageControl, colour: androidx.compose.ui.graphics.Color, litKey: Int, kc: com.scottgerstl.lupe.ui.page.KnobControls, height: androidx.compose.ui.unit.Dp) {
    val reduce = LocalReduceMotion.current
    val lit = remember { Animatable(0f) }
    var sliding by remember { mutableStateOf(false) }
    LaunchedEffect(litKey) {
        if (litKey < 0) return@LaunchedEffect
        unscaled { lit.animateTo(1f, tween(if (reduce) 0 else 80)); lit.animateTo(0f, tween(LIT_FADE_MS, easing = EaseOut)) }
    }
    val on = if (sliding) 1f else lit.value
    val frac = if (c.max > c.min) (c.raw - c.min).toFloat() / (c.max - c.min) else 0f
    val ring = lerp(colour, Tok.text, on)
    Box(Modifier.size(HOME_KNOB_W, height)) {
        Row(
            Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).background(Tok.control).clearAndSetSemantics { }.padding(horizontal = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Canvas(Modifier.size(height - 10.dp)) {
                val w = 3.dp.toPx(); val tl = Offset(w / 2, w / 2); val sz = Size(size.width - w, size.height - w)
                drawArc(Tok.outline, 135f, 270f, false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
                if (!c.ringless && frac > 0.003f) drawArc(ring, 135f, 270f * frac.coerceIn(0f, 1f), false, tl, sz, style = Stroke(w, cap = StrokeCap.Round))
            }
            Column(Modifier.weight(1f)) {
                BasicText(c.label, style = LupeType.small.copy(fontSize = 10.sp, lineHeight = 12.sp, color = lerp(Tok.text2Raised, Tok.text, on)), maxLines = 1)
                BasicText(c.value, style = LupeType.number.copy(fontSize = 14.sp, lineHeight = 16.sp, color = Tok.text), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Clip)
            }
        }
        // the FM-1's knob lights the edge of its well in the track's colour while it turns, as the iPad's does
        if (on > 0f) Box(Modifier.fillMaxSize().border(1.5.dp, colour.copy(alpha = on), RoundedCornerShape(8.dp)))
        if (!c.ringless && !c.fixed) com.scottgerstl.lupe.ui.page.KnobTarget(slot, kc, Modifier, HOME_KNOB_W, height, onHot = { sliding = it })
    }
}

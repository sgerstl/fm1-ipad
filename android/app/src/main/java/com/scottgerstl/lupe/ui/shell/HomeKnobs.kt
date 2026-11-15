package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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

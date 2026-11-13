package com.scottgerstl.lupe.ui.sounds

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * The Sounds browser, in the bottom half over the editor (board 66): from a track number held on Pads, a Mix row, or a
 * pad's hold menu. The engines down the left at 40 dp, then User (the FM-1's 32 user slots) and Samples (USR1–3,
 * read-only: sample import is out of scope); the presets in two columns at 40 dp. Tapping one puts the track on it at
 * once, so you hear it; ✓ marks what it plays. Drum tracks get Kits first, one per track, and a pad's own sound
 * (opened from its menu) overrides one pad of the kit (decision 15). Done or Back closes it and the editor returns.
 */
@Composable
fun SoundsBrowser(ui: SoundsUi, actions: SoundsActions, onDone: () -> Unit, modifier: Modifier = Modifier) {
    BackHandler { onDone() }
    val colour = Tok.track[(ui.track - 1).coerceAtLeast(0) % Tok.track.size]
    val haptic = LocalHapticFeedback.current
    val drum = ui.kits.isNotEmpty()
    // the list on the left: Kits (drum tracks, when it isn't a pad's own sound), then the engines
    val showKits = drum && ui.pad == null
    val names = (if (showKits) listOf("KITS") else emptyList()) + ui.engines.map { it.name }
    var shown by remember { mutableIntStateOf(if (showKits) 0 else ui.engine + 0) }
    val engineIndex = shown - if (showKits) 1 else 0       // -1: Kits
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().height(40.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.size(10.dp).background(colour, RoundedCornerShape(5.dp)))
            BasicText(
                if (ui.pad != null) "Sound for pad ${ui.pad} on track ${ui.track}" else "Choose a sound for track ${ui.track}",
                Modifier.weight(1f).semantics { heading() }, style = LupeType.key.copy(fontSize = 15.sp), maxLines = 1,
            )
            Key(onDone, "Done: keep this sound and go back", width = 64.dp, height = 32.dp, minTarget = 40.dp) { fg -> KeyLabel("Done", fg) }
        }
        Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LazyColumn(Modifier.width(112.dp).fillMaxHeight()) {
                itemsIndexed(names) { i, n ->
                    val on = i == shown
                    val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                    Box(
                        Modifier.fillMaxWidth().height(40.dp)
                            .drawBehind { if (lit.value > 0f) { drawRect(Tok.well.copy(alpha = lit.value)); drawRect(colour.copy(alpha = lit.value), size = Size(3.dp.toPx(), size.height)) } }
                            .semantics(mergeDescendants = true) { role = Role.Tab; selected = on; contentDescription = if (n == "KITS") "Kits" else "${n.lowercase().replaceFirstChar { it.uppercase() }} sounds" }
                            .pointerInput(i) { detectTapGestures { shown = i } }
                            .padding(start = 12.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) { BasicText(n, style = LupeType.key.copy(fontSize = 13.sp, letterSpacing = 0.4.sp, color = lerp(Tok.text2, Tok.text, lit.value)), maxLines = 1) }
                }
            }
            val presets = if (engineIndex < 0) ui.kits else ui.engines.getOrNull(engineIndex)?.presets.orEmpty()
            val readOnly = engineIndex >= 0 && ui.engines.getOrNull(engineIndex)?.readOnly == true
            Column(Modifier.weight(1f).fillMaxHeight()) {
                LazyVerticalGrid(GridCells.Fixed(2), Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    itemsIndexed(presets) { i, p ->
                        val current = when {
                            engineIndex < 0 -> ui.kit == i
                            ui.pad != null -> ui.padSounds[ui.pad] == "${ui.engines[engineIndex].name} $p"
                            else -> ui.engine == engineIndex && ui.preset == i
                        }
                        val lit = animatedFloat(if (current) 1f else 0f, Dur.STATE)
                        Box(
                            Modifier.fillMaxWidth().height(40.dp).clip(RoundedCornerShape(8.dp))
                                .background(lerp(Tok.control, lerp(Tok.page, colour, 0.35f), lit.value))
                                .drawBehind { if (lit.value > 0f) drawRoundRect(Tok.text.copy(alpha = lit.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx())) }
                                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = p.lowercase().replaceFirstChar { it.uppercase() }; stateDescription = if (current) "Playing on this track" else if (readOnly) "Read only" else "" }
                                .pointerInput(i, engineIndex, readOnly) {
                                    detectTapGestures {
                                        if (readOnly) return@detectTapGestures
                                        haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
                                        when {
                                            engineIndex < 0 -> actions.pickKit(i)
                                            ui.pad != null -> actions.setPadSound(ui.pad, engineIndex, i)
                                            else -> actions.pickPreset(engineIndex, i)
                                        }
                                    }
                                }
                                .padding(horizontal = 10.dp),
                            contentAlignment = Alignment.CenterStart,
                        ) {
                            BasicText(p, style = LupeType.key.copy(fontSize = 13.sp, letterSpacing = 0.3.sp, color = if (readOnly) Tok.text2Raised else Tok.text), maxLines = 1)
                            if (current) Canvas(Modifier.align(Alignment.CenterEnd).size(14.dp, 12.dp)) {
                                val path = Path().apply { moveTo(1.dp.toPx(), size.height * 0.55f); lineTo(size.width * 0.38f, size.height - 1.dp.toPx()); lineTo(size.width - 1.dp.toPx(), 1.dp.toPx()) }
                                drawPath(path, Tok.text, style = Stroke(2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
                            }
                        }
                    }
                }
                BasicText(
                    when {
                        readOnly -> "Samples are read-only on the phone"
                        ui.pad != null -> "Tap a sound for pad ${ui.pad} · Done keeps it"
                        else -> "Tap a preset to hear it on the track · Done keeps it"
                    },
                    Modifier.padding(top = 6.dp), style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1,
                )
            }
        }
    }
}

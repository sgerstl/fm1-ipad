package com.scottgerstl.lupe.ui.automation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.gestures.waitForUpOrCancellation
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.AutomationLanePick
import com.scottgerstl.lupe.core.AutomationState
import com.scottgerstl.lupe.core.DrawLane
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.ui.shell.Chevron
import com.scottgerstl.lupe.ui.shell.Grid
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.ui.shell.MenuHeading
import com.scottgerstl.lupe.ui.shell.WideKey
import com.scottgerstl.lupe.ui.shell.diamond
import com.scottgerstl.lupe.ui.slide.LocalMagnifier
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import kotlin.math.roundToInt

/** How a lane stands on this pattern: its locks, and whether the FM-1 recorded motion on it (knob moves while REC was on). */
private data class LaneInfo(val lane: String, val locks: Int, val recorded: Boolean)

private fun laneInfo(auto: AutomationState, lane: String): LaneInfo = auto.lanes.firstOrNull { it.param == lane }.let { LaneInfo(lane, it?.locks ?: 0, (it?.recorded ?: 0) > 0) }

/** A raw value as a percent of the lane's range (the lane is drawn 0..100), and back. */
private fun AutomationState.pct(v: Int) = if (max > min) ((v - min) * 100f / (max - min)).coerceIn(0f, 100f) else 0f
private fun AutomationState.raw(pct: Int) = min + (pct * (max - min) / 100f).roundToInt()

/**
 * One automation lane over the whole bottom half (board 69, decision 7): the picker for the lane, the grid kept short
 * above it, and the lane to draw on. Drag along it and each step you pass becomes a lock at the height you drew (what the FM-1
 * stores); tap a ◆ to select its step. **Decision 16:** the first touch on a lane that holds recorded motion asks in place,
 * "Draw over the recorded CUTOFF?"; after yes, drawing flows until you lift (and until the lane or the view changes).
 * The Magnifier follows the finger with the step and value. Done, or Back, returns to the editor.
 */
@Composable
fun AutomationFull(ed: EditorState, auto: AutomationState, core: LupeCore, track: Color, onDone: () -> Unit, modifier: Modifier = Modifier) {
    BackHandler { onDone() }
    val haptic = LocalHapticFeedback.current
    val magnifier = LocalMagnifier.current
    var pickerOpen by remember { mutableStateOf(false) }
    val lane = auto.lane
    val info = laneInfo(auto, lane)
    // the yes of decision 16, for this lane: until it changes, touches draw at once
    var armedLane by remember { mutableStateOf<String?>(null) }
    var asking by remember { mutableStateOf<Long?>(null) }
    val trail = remember { mutableStateListOf<Offset>() }
    var drawnSteps by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    if (armedLane != ed.lane && asking != null && armedLane == null) { /* the question stands until answered */ }

    val vals = auto.points.map { auto.pct(it.value).roundToInt() }
    val steps = auto.points.size.coerceAtLeast(2)
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().height(40.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(10.dp).background(track, RoundedCornerShape(5.dp)))
            BasicText("${ed.track} ${ed.trackName}", style = LupeType.key, maxLines = 1)
            BasicText("· AUTOMATION", Modifier.weight(1f), style = LupeType.body.copy(fontSize = 14.sp), maxLines = 1)
            Box {
                Key({ pickerOpen = true }, "Lane $lane, ${auto.lanes.indexOfFirst { it.param == lane } + 1} of ${auto.lanes.size}. Change lane", width = 104.dp, height = 32.dp, minTarget = 40.dp) { fg ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel(lane, fg, style = LupeType.key.copy(fontSize = 13.sp)); Chevron(fg) }
                }
                // each lane says how many locks it has, or that it's recorded
                LupeMenu(pickerOpen, { pickerOpen = false }, alignEnd = true, width = 232.dp) {
                    MenuHeading("Lane")
                    auto.lanes.map { it.param }.forEach { l ->
                        val i = laneInfo(auto, l)
                        Row(
                            Modifier.fillMaxWidth().height(48.dp)
                                .drawBehind { if (l == lane) drawRect(track, size = androidx.compose.ui.geometry.Size(3.dp.toPx(), size.height)) }
                                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "$l, ${laneWords(i)}"; onClick { core.send(AutomationLanePick(l)); pickerOpen = false; true } }
                                .pointerInput(l) { detectTapGestures { core.send(AutomationLanePick(l)); pickerOpen = false } }
                                .padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            BasicText(l, Modifier.weight(1f), style = LupeType.key)
                            BasicText(laneWords(i), style = LupeType.small.copy(fontSize = 12.sp))
                        }
                    }
                }
            }
            Key(onDone, "Done: back to the editor", width = 56.dp, height = 32.dp, minTarget = 40.dp) { fg -> KeyLabel("Done", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
        }
        // the grid stays short above the lane; tapping a step selects it (and the step panel follows when the editor returns)
        Box(Modifier.fillMaxWidth().height(184.dp).padding(top = 4.dp)) { Grid(ed.copy(selected = ed.selected), track, core, Modifier.fillMaxSize()) }
        Spacer(Modifier.height(8.dp))
        Box(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(Tok.well).onGloballyPositioned { coords = it }) {
            Canvas(
                Modifier.fillMaxSize()
                    .semantics {
                        contentDescription = "Lane $lane: drag along it to draw; each step you pass becomes a lock"
                        customActions = (0 until minOf(steps, 4)).flatMap { st ->
                            listOf(
                                CustomAccessibilityAction("Lock step ${st + 1} higher") { core.send(DrawLane(lane, st, listOf(auto.raw((vals.getOrElse(st) { 50 } + 10).coerceAtMost(100))), lock = true, confirmed = armedLane == lane)); true },
                                CustomAccessibilityAction("Lock step ${st + 1} lower") { core.send(DrawLane(lane, st, listOf(auto.raw((vals.getOrElse(st) { 50 } - 10).coerceAtLeast(0))), lock = true, confirmed = armedLane == lane)); true },
                            )
                        }   // the first four steps; TalkBack users set the rest from the step panel's SOUND tab
                    }
                    .pointerInput(lane, info.recorded, armedLane) {
                        awaitEachGesture {
                            val down = awaitFirstDown(requireUnconsumed = false)
                            val pad = 12.dp.toPx()
                            fun stepAt(x: Float) = (((x - pad) / (size.width - 2 * pad)) * (steps - 1)).roundToInt().coerceIn(0, steps - 1)
                            fun valueAt(y: Float) = (100f * (1f - (y - 10.dp.toPx()) / (size.height - 20.dp.toPx()))).roundToInt().coerceIn(0, 100)
                            // decision 16: the first touch on recorded motion asks once, in place
                            if (info.recorded && armedLane != lane) {
                                asking = System.currentTimeMillis()
                                waitForUpOrCancellation()
                                return@awaitEachGesture
                            }
                            // a tap on a ◆ selects its step
                            val near = auto.points.firstOrNull { p -> p.source == "lock" && kotlin.math.abs(down.position.x - (pad + p.step * (size.width - 2 * pad) / (steps - 1))) < 22.dp.toPx() }?.step
                            var last = -1
                            var lastV = 0
                            var moved = false
                            fun apply(c: PointerInputChange) {
                                val st = stepAt(c.position.x); val v = valueAt(c.position.y)
                                // every step passed since the last one, the height eased between: a fast finger skips none, and each is a lock
                                val range = if (last < 0) listOf(st) else if (st >= last) (last + 1..st).toList() else (last - 1 downTo st).toList()
                                val from = last.coerceAtLeast(0)
                                if (range.isNotEmpty()) {
                                    val values = range.mapIndexed { n, _ -> auto.raw(if (last < 0) v else (lastV + (v - lastV) * (n + 1) / range.size)) }
                                    core.send(DrawLane(lane, range.first(), values, lock = true, confirmed = armedLane == lane))
                                    haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
                                }
                                last = st; lastV = v
                                trail.add(c.position)
                                drawnSteps = (drawnSteps?.first ?: st) to st
                                if (magnifier != null) {
                                    magnifier.face = MagnifierFace("$lane · step ${st + 1}", { "$v%" }, { v / 100f }, tint = track)
                                    magnifier.finger = coords?.takeIf { it.isAttached }?.localToRoot(c.position) ?: c.position
                                    magnifier.shown = true
                                }
                            }
                            trail.clear(); drawnSteps = null
                            if (near != null) {
                                val up = waitForUpOrCancellation()
                                if (up != null) { core.send(Intent.StepSelect(near)); return@awaitEachGesture }
                            }
                            apply(down)
                            drag(down.id) { c -> moved = true; apply(c); c.consume() }
                            magnifier?.shown = false
                            trail.clear()
                        }
                    }
                    .drawBehind {
                        val pad = 12.dp.toPx(); val vp = 10.dp.toPx()
                        fun x(i: Int) = pad + i * (size.width - 2 * pad) / (steps - 1)
                        fun y(v: Int) = size.height - vp - (v / 100f) * (size.height - 2 * vp)
                        if (vals.isNotEmpty()) {
                            if (ed.playhead >= 0) drawLine(Tok.text3, Offset(x(ed.playhead), 0f), Offset(x(ed.playhead), size.height), 1.dp.toPx())
                            drawPath(Path().apply { vals.forEachIndexed { i, v -> if (i == 0) moveTo(x(i), y(v)) else lineTo(x(i), y(v)) } }, track, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
                            auto.points.forEach { p -> if (p.source == "lock") diamond(Tok.text, x(p.step), y(vals.getOrElse(p.step) { 0 }), 4.dp.toPx()) }
                        }
                        // the finger's own stroke, in white, as board 69 draws it
                        if (trail.size > 1) drawPath(Path().apply { trail.forEachIndexed { i, o -> if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) } }, Tok.text, style = Stroke(4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
                    },
            ) {}
            // decision 16, in place: asked over the lane on the first touch of recorded motion; taps ignored for 0.4 s
            LupeCrossfade(asking, Modifier.align(Alignment.TopCenter).fillMaxWidth().padding(8.dp)) { at ->
                if (at != null) Column(Modifier.background(Tok.panel, RoundedCornerShape(8.dp)).padding(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    val words = "Draw over the recorded $lane?"
                    Box(
                        Modifier.fillMaxWidth().drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Confirm: $words"; onClick { if (System.currentTimeMillis() - at > 400) { armedLane = lane; asking = null; true } else false } }
                            .pointerInput(at) { detectTapGestures { if (System.currentTimeMillis() - at > 400) { armedLane = lane; asking = null } } }
                            .padding(12.dp),
                    ) { BasicText(words, style = LupeType.key) }
                    WideKey("Cancel", { asking = null })
                }
            }
        }
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            val d = drawnSteps
            BasicText(
                if (d != null && trail.size > 1) "Drawing steps ${minOf(d.first, d.second) + 1}–${maxOf(d.first, d.second) + 1}: each step you pass becomes a lock" else "Drag along the lane to draw · tap a ◆ to select its step",
                Modifier.weight(1f), style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1,
            )
            BasicText("◆ = a lock", style = LupeType.small.copy(fontSize = 12.sp))
        }
    }
}

private fun laneWords(i: LaneInfo) = when {
    i.locks > 0 -> "${i.locks} lock${if (i.locks == 1) "" else "s"}"
    i.recorded -> "recorded"
    else -> "nothing yet"
}

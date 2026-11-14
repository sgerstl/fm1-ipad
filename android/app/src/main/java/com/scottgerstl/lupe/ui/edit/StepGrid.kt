package com.scottgerstl.lupe.ui.edit

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.FakeData
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LockMode
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PlayNote
import com.scottgerstl.lupe.core.SetStepNotes
import com.scottgerstl.lupe.core.Step
import com.scottgerstl.lupe.core.StepActionKind
import com.scottgerstl.lupe.core.ToggleStepNote
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/** The piano down the grid's left edge (board 75): white keys its full width, black keys about 62 % of it, C named. */
val PIANO_EDGE = 40.dp

/** The notes on a step: the core's MIDI numbers, or (an older recording) what its PITCH text names. */
fun stepNotes(s: Step): List<Int> = if (!s.on) emptyList() else s.notes.ifEmpty { s.pitchText.ifEmpty { s.note }.split(" ").filter { it.isNotEmpty() }.map { FakeData.parseNote(it) } }

/**
 * A melodic pattern as the iPhone's step grid (decision 31, board 75): pitches up, the sixteen steps across, each note a block in
 * the track's colour as long as it holds, the picked step's column lifted and its notes ringed white, the playing step marked by a
 * bar along the top. A piano runs down the left edge in the note names' place; a key plays its note.
 *
 * A tap on an empty cell writes that note to the step (Chord on: adds it, up to the FM-1's four) and picks the step; a tap on a
 * note picks its step, and on the picked step's note takes it off. A hold is the FM-1's own: lock mode while the finger stays
 * down. One finger up or down scrolls the pitches. [dock] is how much of the right side a docked panel covers: the steps keep
 * their width and scroll under it (decision 35, B), with an indicator along the foot. [canPlay] is false while REC is armed and
 * playing (a note played then would be recorded).
 */
@Composable
fun StepGrid(ed: EditorState, track: Color, core: LupeCore, picked: Int?, onPick: (Int?) -> Unit, dock: Dp, canPlay: () -> Boolean, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    val haptic = LocalHapticFeedback.current
    val reduce = LocalReduceMotion.current
    val longPress = LocalViewConfiguration.current.longPressTimeoutMillis
    val scope = rememberCoroutineScope()
    val tm = rememberTextMeasurer()
    val edNow by rememberUpdatedState(ed)
    val pickedNow by rememberUpdatedState(picked)
    Row(modifier.fillMaxSize()) {
        var scrollY by remember(ed.track, ed.pattern) { mutableFloatStateOf(-1f) }
        var scrollX by remember { mutableFloatStateOf(0f) }
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val viewH = with(density) { maxHeight.toPx() }
            val rowPx = viewH / Roll.ROWS
            val gridW = maxWidth - PIANO_EDGE - 4.dp
            val viewPx = with(density) { gridW.toPx() }
            val stepPx = viewPx / Roll.STEPS
            val dockPx = with(density) { dock.toPx() }.coerceAtMost(viewPx - stepPx * 4)
            val geo by rememberUpdatedState(floatArrayOf(rowPx, viewH, stepPx, viewPx, dockPx))
            // the window opens on the pattern's notes; after that it is where the finger left it
            val sy = if (scrollY < 0f) Roll.scrollYFor(Roll.topFor(ed.steps.flatMap { stepNotes(it) }), rowPx) else Roll.clampScrollY(scrollY, rowPx, viewH)
            fun sx() = Roll.clampScrollX(scrollX, geo[4])
            // a panel docking: the picked step comes clear of it; undocking: the grid goes back to its place. Eased, nothing pops.
            LaunchedEffect(dockPx > 0f, picked) {
                val to = if (dockPx <= 0f) 0f else picked?.let { Roll.reveal(it, sx(), stepPx, viewPx, dockPx) } ?: sx()
                if (to != scrollX) animate(scrollX, to, animationSpec = tween(if (reduce) 0 else Dur.PANEL, easing = EaseOut)) { v, _ -> scrollX = v }
            }

            fun play(midi: Int) { if (canPlay()) { core.send(PlayNote(note = midi, on = true)); scope.launch { delay(160); core.send(PlayNote(note = midi, on = false)) } } }
            fun pick(i: Int) { onPick(i); core.send(Intent.StepSelect(i)) }
            fun tapCell(i: Int, pitch: Int) {
                val e = edNow; val s = e.steps.getOrNull(i) ?: Step()
                when (Roll.tap(stepNotes(s), pitch, pickedNow == i, e.chord, e.maxNotes)) {
                    Roll.Tap.Pick -> pick(i)
                    Roll.Tap.Remove -> { core.send(ToggleStepNote(i, pitch)); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                    Roll.Tap.Set -> { pick(i); core.send(SetStepNotes(i, listOf(pitch))); play(pitch); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                    Roll.Tap.Add -> { pick(i); core.send(ToggleStepNote(i, pitch)); play(pitch); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                    Roll.Tap.Full -> { pick(i); haptic.performHapticFeedback(HapticFeedbackType.Reject) }
                }
            }

            Row(Modifier.fillMaxSize()) {
                PianoEdge(sy, rowPx, core, canPlay, Modifier.width(PIANO_EDGE).fillMaxHeight())
                Spacer(Modifier.width(4.dp))
                Box(
                    Modifier.width(gridW).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(Tok.well)
                        // one finger: up and down scrolls the pitches, sideways scrolls the steps under a docked panel
                        .pointerInput(Unit) {
                            detectDragGestures { change, d ->
                                change.consume()
                                val base = if (scrollY < 0f) Roll.scrollYFor(Roll.topFor(edNow.steps.flatMap { stepNotes(it) }), geo[0]) else scrollY
                                scrollY = Roll.clampScrollY(base - d.y, geo[0], geo[1])
                                scrollX = Roll.clampScrollX(scrollX - d.x, geo[4])
                            }
                        }
                        // a tap writes or picks; a hold is lock mode for as long as the finger stays down (the FM-1's own gesture)
                        .pointerInput(Unit) {
                            awaitEachGesture {
                                val down = awaitFirstDown()
                                val g = geo
                                val base = if (scrollY < 0f) Roll.scrollYFor(Roll.topFor(edNow.steps.flatMap { stepNotes(it) }), g[0]) else Roll.clampScrollY(scrollY, g[0], g[1])
                                val i = Roll.stepAt(down.position.x, Roll.clampScrollX(scrollX, g[4]), g[2]); val pitch = Roll.pitchAt(down.position.y, base, g[0])
                                var cancelled = false
                                val up = withTimeoutOrNull(longPress) { waitForUpOrCancellation().also { if (it == null) cancelled = true } }
                                if (cancelled) return@awaitEachGesture
                                if (up != null) tapCell(i, pitch)
                                else {
                                    onPick(i); haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    core.send(Intent.StepHold(i, true)); waitForUpOrCancellation(); core.send(Intent.StepHold(i, false))
                                }
                            }
                        },
                ) {
                    Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
                        val x0 = -sx()
                        val pitches = Roll.visiblePitches(sy, rowPx, size.height)
                        val line = Tok.page
                        // the rows: a black key's row a shade darker; the beats' first columns a shade lighter; the picked step's column lifted
                        for (p in pitches) {
                            val y = (127 - p) * rowPx - sy
                            if (Roll.isBlack(p)) drawRect(lerp(Tok.well, Tok.page, 0.6f), Offset(0f, y), Size(size.width, rowPx))
                        }
                        for (i in 0 until Roll.STEPS) {
                            val x = x0 + i * stepPx
                            if (i % 4 == 0) drawRect(Tok.text.copy(alpha = 0.03f), Offset(x, 0f), Size(stepPx, size.height))
                            if (picked == i) drawRect(Tok.stepEmpty, Offset(x, 0f), Size(stepPx, size.height))
                        }
                        for (p in pitches) { val y = (127 - p) * rowPx - sy; drawLine(line, Offset(0f, y), Offset(size.width, y), 1.dp.toPx()) }
                        for (i in 0..Roll.STEPS) { val x = x0 + i * stepPx; drawLine(if (i % 4 == 0) Tok.control else line, Offset(x, 0f), Offset(x, size.height), 1.dp.toPx()) }
                        // the notes: as long as they hold, stronger the harder they are played; the picked step's ringed white; ◆ for a lock
                        ed.steps.forEachIndexed { i, s ->
                            for (n in stepNotes(s)) {
                                if (n !in pitches) continue
                                val x = x0 + i * stepPx + 2.dp.toPx(); val y = (127 - n) * rowPx - sy + 2.dp.toPx()
                                val w = (s.length.coerceAtLeast(1) * stepPx - 4.dp.toPx()).coerceAtLeast(6.dp.toPx()); val h = (rowPx - 4.dp.toPx()).coerceAtLeast(4.dp.toPx())
                                drawRoundRect(lerp(Tok.page, track, 0.55f + 0.45f * (s.velocity / 127f)), Offset(x, y), Size(w, h), CornerRadius(5.dp.toPx()))
                                if (picked == i) drawRoundRect(Tok.text, Offset(x - 1.dp.toPx(), y - 1.dp.toPx()), Size(w + 2.dp.toPx(), h + 2.dp.toPx()), CornerRadius(6.dp.toPx()), style = Stroke(2.dp.toPx()))
                                if (s.locked) { val cx = x + w - 7.dp.toPx(); val cy = y + h / 2; val r = 3.5.dp.toPx(); drawPath(Path().apply { moveTo(cx, cy - r); lineTo(cx + r, cy); lineTo(cx, cy + r); lineTo(cx - r, cy); close() }, Tok.onColour) }
                            }
                        }
                        // notes above or below the window: a small mark at that edge of their step, so nothing is silently out of view
                        ed.steps.forEachIndexed { i, s ->
                            val ns = stepNotes(s); val x = x0 + i * stepPx + stepPx / 2
                            if (ns.any { it > pitches.last }) drawCircle(track, 2.5.dp.toPx(), Offset(x, 5.dp.toPx()))
                            if (ns.any { it < pitches.first }) drawCircle(track, 2.5.dp.toPx(), Offset(x, size.height - 5.dp.toPx()))
                        }
                        // the playhead: a bar along the top of the playing step
                        if (ed.playhead in 0 until Roll.STEPS) drawRect(Tok.text, Offset(x0 + ed.playhead * stepPx, 0f), Size(stepPx, 3.dp.toPx()))
                        // the held step (lock mode): its column outlined in the track's colour
                        if (ed.lock == LockMode.Held && ed.selected in 0 until Roll.STEPS) drawRect(track, Offset(x0 + ed.selected * stepPx + 1.dp.toPx(), 1.dp.toPx()), Size(stepPx - 2.dp.toPx(), size.height - 2.dp.toPx()), style = Stroke(2.dp.toPx()))
                        // the scroll indicator, while a panel covers part of the grid: what is in view beside it, along the foot
                        if (dockPx > 0.5f) {
                            val (a, b) = Roll.indicator(sx(), stepPx, viewPx, dockPx); val wv = size.width - dockPx - 8.dp.toPx()
                            drawRoundRect(Tok.control, Offset(4.dp.toPx(), size.height - 4.dp.toPx()), Size(wv, 2.dp.toPx()), CornerRadius(1.dp.toPx()))
                            drawRoundRect(Tok.text2Raised, Offset(4.dp.toPx() + a * wv, size.height - 4.dp.toPx()), Size((b - a) * wv, 2.dp.toPx()), CornerRadius(1.dp.toPx()))
                        }
                    }
                    // TalkBack: a step is one thing to land on, with what it holds and the ways to change it (the cells themselves aren't nodes)
                    val window = Roll.visiblePitches(sy, rowPx, viewH)
                    for (i in 0 until Roll.STEPS) {
                        val s = ed.steps.getOrNull(i) ?: Step(); val ns = stepNotes(s)
                        Box(
                            Modifier.offset { IntOffset((i * stepPx - sx()).toInt(), 0) }.width(with(density) { stepPx.toDp() }).fillMaxHeight()
                                .semantics {
                                    role = Role.Button
                                    contentDescription = "Step ${i + 1}, " + (if (ns.isEmpty()) "empty" else ns.joinToString(" ") { FakeData.noteName(it) } + ", length ${s.length}, velocity ${s.velocity}") + (if (s.locked) ", has a lock" else "")
                                    stateDescription = if (picked == i) "Selected" else ""
                                    onClick { if (pickedNow == i) onPick(null) else pick(i); true }
                                    customActions = buildList {
                                        ns.forEach { n -> add(CustomAccessibilityAction("Take ${FakeData.noteName(n)} off") { core.send(ToggleStepNote(i, n)); true }) }
                                        // the notes in view, lowest first: the way to write one without finding a cell
                                        for (p in window.first + 1 until window.last) if (p !in ns) add(CustomAccessibilityAction(if (ed.chord) "Add ${FakeData.noteName(p)}" else "Set ${FakeData.noteName(p)}") { tapCell(i, p); true })
                                        add(CustomAccessibilityAction("Lock knob turns to this step") { pick(i); core.send(Intent.LockToggle); true })
                                        add(CustomAccessibilityAction("Copy step") { core.send(Intent.StepAction(i, StepActionKind.Copy)); true })
                                    }
                                },
                        )
                    }
                }
            }
        }
    }
}

/** The piano edge: the rows' keys, a black key 62 % of the width over a white one, the white keys' joins drawn, C named. A key plays its note while it is held. */
@Composable
private fun PianoEdge(scrollY: Float, rowPx: Float, core: LupeCore, canPlay: () -> Boolean, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val sy by rememberUpdatedState(scrollY)
    val row by rememberUpdatedState(rowPx)
    Canvas(
        modifier.clip(RoundedCornerShape(4.dp))
            .semantics { contentDescription = "Piano keys: touch one to hear its note" }
            .pointerInput(Unit) {
                detectTapGestures(onPress = { at ->
                    val midi = Roll.pitchAt(at.y, sy, row)
                    if (canPlay()) { core.send(PlayNote(note = midi, on = true)); tryAwaitRelease(); core.send(PlayNote(note = midi, on = false)) }
                })
            },
    ) {
        drawRect(Tok.text2Raised)
        for (p in Roll.visiblePitches(scrollY, rowPx, size.height)) {
            val y = (127 - p) * rowPx - scrollY
            if (Roll.isBlack(p)) drawRoundRect(Tok.panel, Offset(-4.dp.toPx(), y), Size(size.width * 0.62f + 4.dp.toPx(), rowPx), CornerRadius(3.dp.toPx()))
            // two white keys side by side (B over C, E over F): the join between them
            val m = Math.floorMod(p, 12)
            if (m == 0 || m == 5) drawLine(Tok.primaryEdge, Offset(0f, y + rowPx), Offset(size.width, y + rowPx), 1.dp.toPx())
            if (Roll.isC(p)) {
                val r = tm.measure(FakeData.noteName(p), LupeType.label.copy(fontSize = 10.sp, color = Tok.onColour))
                drawText(r, topLeft = Offset(size.width - r.size.width - 3.dp.toPx(), y + (rowPx - r.size.height) / 2))
            }
        }
    }
}

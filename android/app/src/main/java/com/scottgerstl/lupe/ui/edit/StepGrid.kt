package com.scottgerstl.lupe.ui.edit

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Spacer
import androidx.compose.ui.Alignment
import androidx.compose.foundation.text.BasicText
import androidx.compose.ui.unit.sp

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
fun StepGrid(
    ed: EditorState, track: Color, core: LupeCore, picked: Int?, onPick: (Int?) -> Unit, dock: Dp, canPlay: () -> Boolean, modifier: Modifier = Modifier,
    /** Steps a page: 16, or [Roll.PAGE_DOCKED] beside a docked panel (the caller then gives the grid only the room left of it, and [dock] is 0). */
    pageSteps: Int = Roll.STEPS,
    /** 8-step pages turn with the playhead only while Follow is on (Scott, 2026-11-17). */
    follow: Boolean = true,
) {
    val motion = com.scottgerstl.lupe.ui.theme.hybridMotion
    val paged = pageSteps == Roll.PAGE_DOCKED
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
        // when a finger last moved the steps: while it plays the grid pages along with the playhead, unless it was touched a moment ago
        var touchedAt by remember { mutableStateOf(0L) }
        // the pattern's steps: its count, or what the core sends if that is more (sixteen until the core carries more)
        val total = maxOf(ed.patternSteps, ed.steps.size, 1).coerceAtMost(64)
        val totalNow by rememberUpdatedState(total)
        BoxWithConstraints(Modifier.fillMaxSize()) {
            // 8-step pages: the minimap (spec 3.14) takes 28 dp and a 6 dp gap at the foot
            val mapH = if (paged) MINIMAP_H + 6.dp else 0.dp
            val viewH = with(density) { (maxHeight - mapH).toPx() }
            val rowPx = viewH / Roll.ROWS
            val gridW = maxWidth - PIANO_EDGE - 4.dp
            val viewPx = with(density) { gridW.toPx() }
            val stepPx = viewPx / pageSteps
            val dockPx = with(density) { dock.toPx() }.coerceAtMost(viewPx - stepPx * 4)
            val geo by rememberUpdatedState(floatArrayOf(rowPx, viewH, stepPx, viewPx, dockPx))
            val pageNow by rememberUpdatedState(pageSteps)
            // the window opens on the pattern's notes; after that it is where the finger left it
            val sy = if (scrollY < 0f) Roll.scrollYFor(Roll.topFor(ed.steps.flatMap { stepNotes(it) }), rowPx) else Roll.clampScrollY(scrollY, rowPx, viewH)
            fun maxScroll() = Roll.maxScroll(totalNow, geo[3], geo[4], pageNow)
            fun sx() = Roll.clampScrollX(scrollX, maxScroll())
            /** Eases the steps to [to] (a place the grid settles; at once with Reduce Motion): nothing pops. */
            suspend fun glide(to: Float) {
                val target = Roll.clampScrollX(to, maxScroll())
                // 8-step pages flip on the spring (spec §5, Labs: Edit page flip); with Reduce Motion the page cuts and its label cross-fades
                if (kotlin.math.abs(target - scrollX) > 0.5f) animate(scrollX, target,
                    animationSpec = if (reduce) tween(0) else if (paged) com.scottgerstl.lupe.ui.theme.lupeSpring(motion.pageFlipMs, motion.bounce) else tween(Dur.PANEL, easing = EaseOut)) { v, _ -> scrollX = v }
            }
            // a panel docking or leaving, the pattern's length changing, or a step picked: the picked step comes into view (clear of the panel),
            // else the grid settles on its nearest chunk
            LaunchedEffect(dockPx > 0f, picked, total, pageSteps) { glide(picked?.let { Roll.reveal(it, sx(), stepPx, viewPx, dockPx, total, pageSteps) } ?: Roll.snap(sx(), total, viewPx, dockPx, pageSteps)) }
            // playing: the playhead's chunk (batch item 9), unless a finger moved the steps in the last two and a half seconds
            LaunchedEffect(ed.playhead, total) {
                if (ed.playhead < 0 || !Roll.pagesFollow(pageSteps, follow, System.currentTimeMillis() - touchedAt < 2500L)) return@LaunchedEffect
                Roll.follow(ed.playhead, sx(), stepPx, viewPx, dockPx, total, pageSteps)?.let { glide(it) }
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

            androidx.compose.foundation.layout.Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().height(with(density) { viewH.toDp() })) {
                PianoEdge(sy, rowPx, core, canPlay, Modifier.width(PIANO_EDGE).fillMaxHeight())
                Spacer(Modifier.width(4.dp))
                Box(
                    Modifier.width(gridW).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(Tok.well)
                        // one finger: up and down scrolls the pitches, sideways scrolls the steps under a docked panel
                        .pointerInput(Unit) {
                            detectDragGestures(
                                onDragStart = { touchedAt = System.currentTimeMillis() },
                                // let go: the steps settle on a chunk (or, a panel docked, on the place its last steps come clear)
                                onDragEnd = { touchedAt = System.currentTimeMillis(); scope.launch { glide(Roll.snap(sx(), totalNow, geo[3], geo[4], pageNow)) } },
                                onDragCancel = { scope.launch { glide(Roll.snap(sx(), totalNow, geo[3], geo[4], pageNow)) } },
                            ) { change, d ->
                                change.consume(); touchedAt = System.currentTimeMillis()
                                val base = if (scrollY < 0f) Roll.scrollYFor(Roll.topFor(edNow.steps.flatMap { stepNotes(it) }), geo[0]) else scrollY
                                scrollY = Roll.clampScrollY(base - d.y, geo[0], geo[1])
                                scrollX = Roll.clampScrollX(scrollX - d.x, Roll.maxScroll(totalNow, geo[3], geo[4], pageNow))
                            }
                        }
                        // a tap writes or picks; a hold is lock mode for as long as the finger stays down (the FM-1's own gesture)
                        .pointerInput(Unit) {
                            awaitEachGesture {
                                val down = awaitFirstDown()
                                touchedAt = System.currentTimeMillis()
                                val g = geo
                                val base = if (scrollY < 0f) Roll.scrollYFor(Roll.topFor(edNow.steps.flatMap { stepNotes(it) }), g[0]) else Roll.clampScrollY(scrollY, g[0], g[1])
                                val i = Roll.stepAt(down.position.x, Roll.clampScrollX(scrollX, Roll.maxScroll(totalNow, g[3], g[4], pageNow)), g[2], totalNow); val pitch = Roll.pitchAt(down.position.y, base, g[0])
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
                        for (i in 0 until total) {
                            val x = x0 + i * stepPx
                            if (i % 4 == 0) drawRect(Tok.text.copy(alpha = 0.03f), Offset(x, 0f), Size(stepPx, size.height))
                            if (picked == i) drawRect(Tok.stepEmpty, Offset(x, 0f), Size(stepPx, size.height))
                        }
                        for (p in pitches) { val y = (127 - p) * rowPx - sy; drawLine(line, Offset(0f, y), Offset(size.width, y), 1.dp.toPx()) }
                        // bar lines between the chunks of sixteen, the beats a shade stronger than the steps
                        for (i in 0..total) { val x = x0 + i * stepPx; if (i % Roll.STEPS == 0 && i > 0 && i < total) drawLine(Tok.text3, Offset(x, 0f), Offset(x, size.height), 2.dp.toPx()) else drawLine(if (i % 4 == 0) Tok.control else line, Offset(x, 0f), Offset(x, size.height), 1.dp.toPx()) }
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
                        if (ed.playhead in 0 until total) drawRect(Tok.text, Offset(x0 + ed.playhead * stepPx, 0f), Size(stepPx, 3.dp.toPx()))
                        // the held step (lock mode): its column outlined in the track's colour
                        if (ed.lock == LockMode.Held && ed.selected in 0 until total) drawRect(track, Offset(x0 + ed.selected * stepPx + 1.dp.toPx(), 1.dp.toPx()), Size(stepPx - 2.dp.toPx(), size.height - 2.dp.toPx()), style = Stroke(2.dp.toPx()))
                        // the scroll indicator, while a panel covers part of the grid: what is in view beside it, along the foot
                        if (dockPx > 0.5f || total > Roll.STEPS) {
                            val (a, b) = Roll.indicator(sx(), stepPx, viewPx, dockPx, total); val wv = size.width - dockPx - 8.dp.toPx()
                            drawRoundRect(Tok.control, Offset(4.dp.toPx(), size.height - 4.dp.toPx()), Size(wv, 2.dp.toPx()), CornerRadius(1.dp.toPx()))
                            drawRoundRect(Tok.text2Raised, Offset(4.dp.toPx() + a * wv, size.height - 4.dp.toPx()), Size((b - a) * wv, 2.dp.toPx()), CornerRadius(1.dp.toPx()))
                        }
                    }
                    // TalkBack: a step is one thing to land on, with what it holds and the ways to change it (the cells themselves aren't nodes)
                    val window = Roll.visiblePitches(sy, rowPx, viewH)
                    for (i in 0 until total) {
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
            // 8-step pages: the minimap (spec 3.14) under the grid; its label sits under the piano edge
            if (paged) {
                Spacer(Modifier.height(6.dp))
                val pagePx = pageSteps * stepPx
                MiniMap(ed, track, total, pageSteps, sx() / pagePx.coerceAtLeast(1f), follow, gridW, reduce) { p -> touchedAt = System.currentTimeMillis(); scope.launch { glide(p * pagePx) } }
            }
            }
        }
    }
}

private val MINIMAP_H = 28.dp

/**
 * The 8-step pages' minimap (spec 3.14): sixteen cells as wide as the grid, the current page's on `control`, the other page's on `panel`, a `lifted`
 * window at radius 10 behind the page showing that slides with the grid, the notes as dots in the track's colour. With Follow off it marks the
 * playhead's cell, so you can see where the song is. A tap on a cell turns to its page (the non-drag way in, WCAG 2.5.7); the label at the left
 * reads "1–8" or "9–16", cross-fading as the page turns.
 */
@Composable
private fun MiniMap(ed: EditorState, track: Color, total: Int, pageSteps: Int, pageAt: Float, follow: Boolean, gridW: Dp, reduce: Boolean, onPage: (Int) -> Unit) {
    val page = kotlin.math.round(pageAt).toInt().coerceAtLeast(0)
    val start = Roll.minimapStart(page, pageSteps)
    val cells = Roll.STEPS
    Row(Modifier.fillMaxWidth().height(MINIMAP_H), verticalAlignment = Alignment.CenterVertically) {
        com.scottgerstl.lupe.ui.theme.LupeCrossfade(Roll.pageLabel(page, pageSteps, total), Modifier.width(PIANO_EDGE + 4.dp)) { label ->
            BasicText(label, Modifier.semantics { contentDescription = "Steps $label" },
                style = com.scottgerstl.lupe.ui.theme.LupeType.number.copy(fontSize = 13.sp, lineHeight = 14.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, color = Tok.text2Raised))
        }
        Box(
            Modifier.width(gridW).fillMaxHeight()
                .pointerInput(start, pageSteps) { detectTapGestures { o -> val c = (o.x / (size.width / cells.toFloat())).toInt().coerceIn(0, cells - 1); val step = start + c; if (step < total) onPage(step / pageSteps) } }
                .semantics(mergeDescendants = true) {
                    role = Role.Button
                    contentDescription = "Page ${Roll.pageLabel(page, pageSteps, total)} of $total steps"
                    customActions = (0 until Roll.chunks(total, pageSteps)).filter { it != page }.map { p -> CustomAccessibilityAction("Show steps ${Roll.pageLabel(p, pageSteps, total)}") { onPage(p); true } }
                },
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val gap = 2.dp.toPx(); val cw = size.width / cells
                // the window behind the page showing: slides with the grid (the fraction of a page it has scrolled)
                val wx = ((pageAt * pageSteps) - start) * cw
                drawRoundRect(Tok.lifted, Offset(wx, 0f), Size(pageSteps * cw, size.height), CornerRadius(10.dp.toPx()))
                for (c in 0 until cells) {
                    val step = start + c
                    if (step >= total) break
                    val onPage = step / pageSteps == page
                    val x = c * cw + gap; val inset = 4.dp.toPx()
                    val cell = Size(cw - 2 * gap, size.height - 2 * inset)
                    drawRoundRect(if (onPage) Tok.control else Tok.panel, Offset(x, inset), cell, CornerRadius(4.dp.toPx()))
                    if (!follow && step == ed.playhead) drawRoundRect(Tok.text.copy(alpha = 0.35f), Offset(x, inset), cell, CornerRadius(4.dp.toPx()))
                    val s = ed.steps.getOrNull(step)
                    if (s != null && stepNotes(s).isNotEmpty()) drawCircle(track, 3.dp.toPx(), Offset(x + cell.width / 2, size.height / 2))
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

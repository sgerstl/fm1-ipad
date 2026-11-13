package com.scottgerstl.lupe.ui.timeline

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.TopState
import com.scottgerstl.lupe.ui.shell.ConfirmBox
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.ui.shell.MenuHeading
import com.scottgerstl.lupe.ui.shell.MenuRow
import com.scottgerstl.lupe.ui.slide.MenuSlideRow
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.launch

/** The ruler along the top; the track heads' column (decision 28: compact heads, about 72 dp); the gap between rows, as Pads'. */
private val RULER = 32.dp
private val HEAD = 72.dp
private val GAP = 4.dp

/**
 * The Timeline tab in landscape (decision 28): **time runs across**. Six track rows in Pads' order and height, each
 * with a compact head (its number in the track's colour and a short name; tap selects the track) and a lane of its
 * song's blocks. A bar ruler runs along the top. About 12 bars show to begin with: one finger on empty space (or on a
 * block that isn't selected) pans the song sideways, a pinch zooms it between about 8 and 16 bars, and the − + and ‹ ›
 * keys do the same without a drag or a second finger.
 *
 * Blocks are the track's colour at 45 % over the page with the pattern's number; a REST is a dashed outline. Tap
 * selects (white ring, a grip at its right end) and tap again lets go. A selected block drags along its own row to
 * REORDER it (a track's song is a list played back to back, so a block has no free place; its neighbours open a gap) and
 * drags by its grip to set its REPS in whole passes (the blocks after it move as it goes). Hold opens its menu beside
 * the finger. Holding the empty lane after a track's last block adds to its song. While the song plays the FM-1 refuses
 * changes to the order: a strip on the ruler says so, with Stop; a playhead runs across and the view pages to keep it in.
 *
 * Every drag reads what the finger did when it ENDS and sends that (the fault portrait had before fb7a661: the end
 * handler had captured the numbers from when the gesture began).
 */
@Composable
fun TimelinePage(uiState: State<TimelineUi>, actions: TimelineActions, head: State<Double?>, top: State<TopState>, modifier: Modifier = Modifier) {
    val ui = uiState.value
    val playing by remember { derivedStateOf { top.value.playing } }
    val density = LocalDensity.current
    val reduce = LocalReduceMotion.current
    val view = remember { TimelineViewState() }
    val scope = rememberCoroutineScope()
    val tm = rememberTextMeasurer()
    BoxWithConstraints(modifier.fillMaxSize()) {
        val lanePx = with(density) { (maxWidth - HEAD - GAP).toPx() }
        // what is drawn: the state, kept inside what the lanes allow (the state itself is only written by a touch)
        val barPx = clampBarPx(view.barPx, lanePx)
        val bars = contentBars(ui.totalBars, barPx, lanePx)
        val contentPx = bars * barPx
        val barDp = with(density) { barPx.toDp() }
        val latest = rememberUpdatedState(Triple(lanePx, barPx, contentPx))
        val total by rememberUpdatedState(ui.totalBars)     // (the gesture blocks outlive a recomposition: they read these)
        fun scrollNow() = clampScroll(view.scroll, latest.value.third, latest.value.first)

        /** Pans to [to] the way everything else moves (300 ms ease-out; at once with Reduce Motion). */
        fun panTo(to: Float) {
            val target = clampScroll(to, latest.value.third, latest.value.first)
            scope.launch { animate(scrollNow(), target, animationSpec = tween(if (reduce) 0 else Dur.PANEL, easing = EaseOut)) { v, _ -> view.scroll = v } }
        }
        fun zoomTo(newBarPx: Float, focusX: Float) {
            val (lane, bar, _) = latest.value
            val nb = clampBarPx(newBarPx, lane)
            val sc = zoomAbout(scrollNow(), bar, nb, focusX)
            view.barPx = nb
            view.scroll = clampScroll(sc, contentBars(total, nb, lane) * nb, lane)
        }
        fun page(by: Int) = panTo(scrollNow() + by * latest.value.first * 0.75f)
        fun zoomStep(wider: Boolean) = zoomTo(latest.value.first / ((latest.value.first / latest.value.second) + if (wider) 4f else -4f).coerceIn(BARS_MIN, BARS_MAX), latest.value.first / 2)

        // while the song plays the view pages along with the playhead, unless a finger has just moved it
        LaunchedEffect(playing) {
            if (!playing) return@LaunchedEffect
            snapshotFlow { head.value?.let { (it * 4).toInt() } }.collect {
                val h = head.value ?: return@collect
                if (System.currentTimeMillis() - view.touchedAt < 3000) return@collect
                followScroll(h, scrollNow(), latest.value.second, latest.value.first)?.let { panTo(it) }
            }
        }

        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(GAP)) {
            // ---- the ruler row: the zoom keys over the heads' column, the bar numbers, and the page keys (or the Stop strip)
            Row(Modifier.fillMaxWidth().height(RULER), horizontalArrangement = Arrangement.spacedBy(GAP), verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.width(HEAD).fillMaxHeight(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val shown = (lanePx / barPx)
                    Key({ zoomStep(true) }, "Show more bars", width = 34.dp, height = 26.dp, minTarget = 32.dp, enabled = shown < BARS_MAX - 0.01f) { fg -> KeyLabel("−", fg) }
                    Key({ zoomStep(false) }, "Show fewer bars", width = 34.dp, height = 26.dp, minTarget = 32.dp, enabled = shown > BARS_MIN + 0.01f) { fg -> KeyLabel("+", fg) }
                }
                Box(Modifier.weight(1f).fillMaxHeight()) {
                    Canvas(
                        Modifier.fillMaxSize().clip(RoundedCornerShape(6.dp)).clearAndSetSemantics { }
                            .pointerInput(Unit) { detectTransformGestures { c, pan, zoom, _ -> view.touchedAt = System.currentTimeMillis(); if (zoom != 1f) zoomTo(latest.value.second * zoom, c.x); view.scroll = scrollNow() - pan.x } },
                    ) {
                        val sc = scrollNow(); val step = rulerStep(barDp.value)
                        val first = (sc / barPx).toInt().coerceAtLeast(0)
                        for (b in first..minOf(bars, first + (size.width / barPx).toInt() + 1)) {
                            val x = b * barPx - sc
                            drawLine(if (b % 4 == 0) Tok.text3 else Tok.control, Offset(x, size.height - (if (b % 4 == 0) 10 else 6).dp.toPx()), Offset(x, size.height), 1.dp.toPx())
                            if (b % step == 0 && b < bars) {
                                val r = tm.measure("${b + 1}", LupeType.small.copy(fontSize = 12.sp, color = if (b >= ui.totalBars) Tok.text2 else Tok.text2Raised))
                                drawText(r, topLeft = Offset(x + 4.dp.toPx(), 2.dp.toPx()))
                            }
                        }
                    }
                    // the keys that pan without a drag; while it plays, the strip that says why nothing can be changed
                    if (playing) Row(
                        Modifier.align(Alignment.CenterEnd).height(RULER).clip(RoundedCornerShape(8.dp)).background(Tok.control).padding(start = 10.dp, end = 2.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        BasicText("Stop to change the song", style = LupeType.key.copy(fontSize = 13.sp))
                        Key({ actions.stop() }, "Stop the song to change it", width = 70.dp, height = 26.dp, minTarget = 32.dp, on = true) { fg -> KeyLabel("■ Stop", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                    } else Row(Modifier.align(Alignment.CenterEnd).background(Tok.page), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        val sc = scrollNow()
                        Key({ page(-1) }, "Earlier bars", width = 34.dp, height = 26.dp, minTarget = 32.dp, enabled = sc > 0.5f) { fg -> KeyLabel("‹", fg) }
                        Key({ page(1) }, "Later bars", width = 34.dp, height = 26.dp, minTarget = 32.dp, enabled = sc < contentPx - lanePx - 0.5f) { fg -> KeyLabel("›", fg) }
                    }
                }
            }
            // ---- six rows: a head and a lane each
            Box(
                Modifier.weight(1f).fillMaxWidth()
                    .semantics {
                        customActions = listOf(
                            CustomAccessibilityAction("Later bars") { page(1); true }, CustomAccessibilityAction("Earlier bars") { page(-1); true },
                            CustomAccessibilityAction("Show more bars") { zoomStep(true); true }, CustomAccessibilityAction("Show fewer bars") { zoomStep(false); true },
                        )
                    }
                    // one finger pans, two zoom; a selected block's own drag is taken first by the block (it consumes it)
                    .pointerInput(Unit) { detectTransformGestures { c, pan, zoom, _ -> view.touchedAt = System.currentTimeMillis(); if (zoom != 1f) zoomTo(latest.value.second * zoom, c.x - HEAD.toPx() - GAP.toPx()); view.scroll = scrollNow() - pan.x } },
            ) {
                Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(GAP)) {
                    for (t in 1..6) {
                        val colour = Tok.track[(t - 1) % Tok.track.size]
                        Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(GAP)) {
                            TrackHead(t, ui.trackNames.getOrNull(t - 1).orEmpty(), colour, ui.selectedTrack == t) { actions.selectTrack(t) }
                            val drag = remember(t) { TrackDrag() }
                            Box(
                                Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(Tok.well)
                                    .drawBehind {
                                        // the bar lines, every fourth a little stronger
                                        val sc = scrollNow(); val first = (sc / barPx).toInt().coerceAtLeast(0)
                                        for (b in first..first + (size.width / barPx).toInt() + 1) {
                                            val x = b * barPx - sc
                                            drawLine(if (b % 4 == 0) Tok.lifted else Tok.control, Offset(x, 0f), Offset(x, size.height), 1.dp.toPx())
                                        }
                                    },
                            ) {
                                TrackEnd(t, ui, actions, barPx, ::scrollNow, !playing)
                                ui.blocks.filter { it.track == t && !it.gap }.forEach { b ->
                                    key(b.key) { BlockView(b, colour, b.key == ui.selected, barPx, bars, ui, actions, !playing, drag, lanePx, ::scrollNow) { d -> view.scroll = clampScroll(scrollNow() + d, latest.value.third, latest.value.first) } }
                                }
                            }
                        }
                    }
                }
                // the playhead, over the lanes (read while drawing: it moves with the clock, nothing recomposes)
                Canvas(Modifier.fillMaxSize().padding(start = HEAD + GAP).clip(RoundedCornerShape(6.dp)).clearAndSetSemantics { }) {
                    val p = head.value
                    if (p != null) { val x = p.toFloat() * barPx - scrollNow(); if (x >= 0f && x <= size.width) drawLine(Tok.text, Offset(x, 0f), Offset(x, size.height), 2.dp.toPx()) }
                }
            }
        }
    }
}

/** A track's head: its number on the track's colour and a short name. Tap selects the track (a white ring says which is). */
@Composable
private fun TrackHead(track: Int, name: String, colour: Color, selected: Boolean, onTap: () -> Unit) {
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    Row(
        Modifier.width(HEAD).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(Tok.control)
            .drawBehind { drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx())) }
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Track $track, $name"; stateDescription = if (selected) "Selected" else "" }
            .pointerInput(track) { detectTapGestures { onTap() } }
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(Modifier.size(24.dp).clip(RoundedCornerShape(6.dp)).background(colour), contentAlignment = Alignment.Center) {
            BasicText("$track", style = LupeType.key.copy(fontSize = 14.sp, color = Tok.onColour))
        }
        BasicText(name, Modifier.clearAndSetSemantics { }, style = LupeType.small.copy(fontSize = 11.sp, lineHeight = 12.sp, color = Tok.text2Raised), maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}

private enum class BlockMenu { Root, Pattern, PatternConfirm, Delete, Insert }

/**
 * One block, a bar of its track's colour lying along the row. Dragging its body REORDERS it among its track's blocks (it
 * follows the finger and lands in the slot it is closest to); dragging its right end sets its REPS (whole passes). Only a
 * selected block drags: an unselected one's drag is the song's pan. Near either end of the lanes the song pans under it.
 */
@Composable
private fun BlockView(
    b: BlockUi, colour: Color, selected: Boolean, barPx: Float, totalBars: Int, ui: TimelineUi, actions: TimelineActions, editable: Boolean, drag: TrackDrag,
    lanePx: Float, scrollNow: () -> Float, panBy: (Float) -> Unit,
) {
    val density = LocalDensity.current
    val haptic = LocalHapticFeedback.current
    val reduce = LocalReduceMotion.current
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    var menuMode by remember { mutableStateOf(BlockMenu.Root) }
    var pendingPattern by remember { mutableStateOf(0) }
    var armedAt by remember { mutableStateOf(0L) }
    var tickKey by remember { mutableIntStateOf(0) }
    val mine = ui.blocks.filter { it.track == b.track && !it.gap }.sortedBy { it.start }
    // the drag's handlers read these when they run, not when the gesture began
    val nowB by rememberUpdatedState(b)
    val nowMine by rememberUpdatedState(mine)
    val nowBarPx by rememberUpdatedState(barPx)

    val dragging = drag.source?.key == b.key
    val resizing = dragging && drag.resizing
    val offsetBars = drag.offsetBars
    val repsNow = if (resizing) repsFor(b, offsetBars) else b.reps
    // a neighbour makes room: it slides by what the dragged block takes or gives up, eased like everything else (nothing pops)
    val shiftTarget = if (!dragging) siblingShift(b, mine, drag.source, drag.resizing, offsetBars) else 0f
    val shift = animatedFloat(shiftTarget, if (reduce) 1 else Dur.STATE)
    val shownStart = if (dragging && !resizing) (b.start + offsetBars).coerceIn(0f, (totalBars - b.length).coerceAtLeast(0f)) else b.start + shift.value
    val shownLen = if (resizing) repsNow * b.passBars else b.length
    val widthDp = with(density) { (shownLen * barPx).toDp() } - 2.dp
    val size0 = shownLen * barPx
    val fill = if (b.rest) Tok.page else lerp(Tok.page, colour, 0.45f)
    val name = ui.trackNames.getOrNull(b.track - 1).orEmpty()
    val what = if (b.rest) "rest" else "pattern ${"%02d".format(b.pattern ?: 0)}"
    val words = "Track ${b.track} $name, ${barRange(b)}, $what" + if (b.playing) ", playing" else ""

    fun openMenu(at: Offset) { if (editable) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); menuMode = BlockMenu.Root; menuAt = at } }

    Box(
        Modifier
            .offset { IntOffset((shownStart * barPx - scrollNow()).toInt(), 0) }
            .width(widthDp.coerceAtLeast(4.dp)).fillMaxHeight()
            .graphicsLayer { if (dragging && !resizing) { shadowElevation = 8.dp.toPx(); shape = RoundedCornerShape(6.dp) } }
            .clip(RoundedCornerShape(6.dp)).background(fill)
            .drawBehind {
                if (b.rest) drawRoundRect(Tok.outline, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(5.dp.toPx()), style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.dp.toPx()))))
                if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(5.dp.toPx()), style = Stroke(2.dp.toPx()))
                // what the FM-1 is playing on this track now: a bar along the block's top edge; what comes next: a thin outline
                if (b.playing) drawRect(Tok.text, size = Size(size.width, 3.dp.toPx()))
                else if (b.next) drawRoundRect(Tok.text2, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(5.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                // the grip at its right end, when it can be stretched (a narrow block's is closer to the edge, clear of the number)
                if (selected && editable) {
                    val wide = size.width >= 56.dp.toPx(); val gh = size.height * 0.45f
                    drawRoundRect(Tok.text.copy(alpha = 0.85f), Offset(size.width - (if (wide) 9.dp.toPx() else 6.dp.toPx()), (size.height - gh) / 2), Size(3.dp.toPx(), gh), CornerRadius(1.5.dp.toPx()))
                }
            }
            .semantics(mergeDescendants = true) {
                role = Role.Button; contentDescription = words; stateDescription = if (selected) "Selected" else ""
                onClick { actions.select(if (selected) null else b.key); true }
                onLongClick("Block menu") { openMenu(Offset(60f, 30f)); true }
                if (editable) customActions = listOf(
                    CustomAccessibilityAction("Move one place later") { actions.moveBy(b, 1); true },
                    CustomAccessibilityAction("Move one place earlier") { actions.moveBy(b, -1); true },
                    CustomAccessibilityAction("One pass longer") { actions.stretch(b, b.reps + 1); true },
                    CustomAccessibilityAction("One pass shorter") { actions.stretch(b, b.reps - 1); true },
                    CustomAccessibilityAction("Duplicate") { actions.duplicate(b); true },
                    CustomAccessibilityAction("Delete…") { menuMode = BlockMenu.Delete; armedAt = System.currentTimeMillis(); menuAt = Offset(60f, 30f); true },
                )
            }
            .pointerInput(b.key, editable, selected) { detectTapGestures(onTap = { actions.select(if (selected) null else b.key) }, onLongPress = { openMenu(it) }) }
            // only a selected block drags (an unselected one's drag is the song's pan)
            .then(if (selected && editable) Modifier.pointerInput(b.key) {
                val edgePx = 28.dp.toPx()
                detectDragGestures(
                    onDragStart = { at -> drag.start(nowB, at.x > size.width - minOf(edgePx, size.width / 2f), nowBarPx); tickKey = 0 },
                    onDragEnd = {
                        // what the finger did, read NOW (fb7a661): not what it had done when the gesture began
                        val src = drag.source ?: nowB
                        if (drag.resizing) { val r = repsFor(src, drag.offsetBars); if (r != src.reps) actions.stretch(src, r) }
                        else { val p = placesFor(nowMine, src.id, drag.offsetBars); if (p != 0) actions.moveBy(src, p) }
                        drag.end()
                    },
                    onDragCancel = { drag.end() },
                ) { change, dragAmount ->
                    change.consume(); drag.accPx += dragAmount.x
                    // near an end of the lanes the song pans under the block, and the block keeps its place under the finger
                    val src = drag.source ?: nowB
                    val pointerX = (src.start * drag.barPx - scrollNow()) + (if (drag.resizing) 0f else drag.accPx) + change.position.x
                    val pan = edgePan(pointerX, lanePx, 36.dp.toPx(), 10.dp.toPx())
                    if (pan != 0f) { val before = scrollNow(); panBy(pan); drag.accPx += scrollNow() - before }
                    val k = if (drag.resizing) repsFor(src, drag.offsetBars) else placesFor(nowMine, src.id, drag.offsetBars)
                    if (k != tickKey) { tickKey = k; haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                }
            } else Modifier),
    ) {
        // the number stays in view while any of the block is: it rides the lanes' left edge when the block starts before it
        val pin = Modifier.align(Alignment.CenterStart).offset { IntOffset((scrollNow() - shownStart * barPx).coerceIn(0f, (size0 - 34.dp.toPx()).coerceAtLeast(0f)).toInt(), 0) }.padding(start = 6.dp)
        if (!b.rest) BasicText("%02d".format(b.pattern ?: 0), pin, style = LupeType.number.copy(fontSize = 16.sp, color = Tok.text), maxLines = 1, softWrap = false)
        else BasicText("REST", pin, style = LupeType.small.copy(fontSize = 11.sp), maxLines = 1, softWrap = false)
        // anchored to the block, so the menu opens beside the finger
        BlockMenuPopup(b, menuAt, menuMode, armedAt, pendingPattern, ui, actions, { menuMode = it; if (it == BlockMenu.Delete || it == BlockMenu.PatternConfirm) armedAt = System.currentTimeMillis() }, { pendingPattern = it }, { menuAt = null })
    }
}

/** The block's hold menu, beside the finger: Pattern, PASSES (slid), Duplicate, Select sound, Delete… (asked in place). */
@Composable
private fun BlockMenuPopup(
    b: BlockUi, at: Offset?, mode: BlockMenu, armedAt: Long, pendingPattern: Int, ui: TimelineUi, actions: TimelineActions,
    setMode: (BlockMenu) -> Unit, setPending: (Int) -> Unit, close: () -> Unit,
) {
    val erases = !b.rest && b.pattern != null && (ui.uses[b.pattern] ?: 0) <= 1
    LupeMenu(at != null, close, width = 240.dp, at = at) {
        LupeCrossfade(mode) { m ->
            Column {
                when (m) {
                    BlockMenu.Root -> {
                        MenuHeading("Track ${b.track} · ${barRange(b)}")
                        MenuRow(if (b.rest) "Pattern: REST ⌄" else "Pattern ${"%02d".format(b.pattern ?: 0)} ⌄", { setMode(BlockMenu.Pattern) })
                        // how long it plays: its passes, set by sliding (no − / +); the bars follow
                        MenuSlideRow("PASSES · ${barsText(b.length)}".uppercase(), "${b.reps}", b.reps, 1, 16, "Passes, block on track ${b.track}", stepDp = 22f) { actions.stretch(b, it) }
                        MenuRow("Duplicate", { actions.duplicate(b); close() })
                        MenuRow("Insert before…", { setMode(BlockMenu.Insert) }, enabled = (ui.entries[b.track] ?: 0) < 16)
                        // a chain plays its patterns as one block; Chain joins this block to the next, Split takes a chain apart
                        if (ui.blocks.any { it.track == b.track && !it.gap && it.id == b.id + b.entries }) MenuRow("Chain with the next", { actions.chain(b); close() })
                        if (b.entries > 1) MenuRow("Split the chain", { actions.split(b); close() })
                        MenuRow("Select sound", { actions.openSounds(b.track); close() })
                        MenuRow("Delete…", { setMode(BlockMenu.Delete) })
                    }
                    BlockMenu.Pattern -> {
                        MenuHeading("Pattern for this block")
                        ui.kept.forEach { p ->
                            MenuRow("Pattern ${"%02d".format(p)}", { if (erases && p != b.pattern) { setPending(p); setMode(BlockMenu.PatternConfirm) } else { actions.setPattern(b, p); close() } }, checked = !b.rest && b.pattern == p)
                        }
                        MenuRow("Back", { setMode(BlockMenu.Root) })
                    }
                    BlockMenu.Insert -> {
                        MenuHeading("Insert before this block")
                        MenuRow("REST", { actions.insert(b.track, b.id, 65); close() })
                        ui.kept.forEach { p -> MenuRow("Pattern ${"%02d".format(p)}", { actions.insert(b.track, b.id, p); close() }) }
                        MenuRow("Back", { setMode(BlockMenu.Root) })
                    }
                    BlockMenu.PatternConfirm -> {
                        // the old pattern is used nowhere else, so setting another erases it
                        val words = "Pattern ${"%02d".format(b.pattern ?: 0)} is used nowhere else, so setting ${"%02d".format(pendingPattern)} erases it. Set it?"
                        ConfirmBox(words, "Confirm: $words", armedAt) { actions.setPattern(b, pendingPattern); close() }
                        MenuRow("Cancel", { setMode(BlockMenu.Pattern) })
                    }
                    BlockMenu.Delete -> {
                        val gone = if (b.rest) "the REST" else "pattern ${"%02d".format(b.pattern ?: 0)}"
                        val words = "Delete $gone (${barsText(b.length)}) from track ${b.track}?" + if (erases) " It is used nowhere else, so it's erased." else ""
                        ConfirmBox(words, "Confirm: $words", armedAt) { actions.delete(b); close() }
                        MenuRow("Cancel", { setMode(BlockMenu.Root) })
                    }
                }
            }
        }
    }
}

/** "1 bar", "5 bars", "½ bar", "2½ bars": never a float's tail. */
internal fun barsText(bars: Float): String {
    val whole = kotlin.math.floor(bars + 1e-4f).toInt(); val frac = bars - whole
    val half = kotlin.math.abs(frac - 0.5f) < 0.01f
    return when {
        kotlin.math.abs(frac) < 0.01f || kotlin.math.abs(frac - 1f) < 0.01f -> { val n = kotlin.math.round(bars).toInt(); "$n ${if (n == 1) "bar" else "bars"}" }
        half -> if (whole == 0) "½ bar" else "$whole½ bars"
        else -> "%.2f".format(bars).trimEnd('0').trimEnd('.') + " bars"
    }
}

/** "bar 2" for a block inside one bar, "bars 2–5" otherwise. */
internal fun barRange(b: BlockUi): String {
    val first = b.start.toInt() + 1; val last = kotlin.math.ceil(b.end - 1e-4f).toInt().coerceAtLeast(first)
    return if (first == last) "bar $first" else "bars $first–$last"
}

/** Holding the empty part of a track's lane, after its last block: a menu beside the finger to add to the song (New pattern, or a kept pattern or a REST at the end). */
@Composable
private fun TrackEnd(track: Int, ui: TimelineUi, actions: TimelineActions, barPx: Float, scrollNow: () -> Float, editable: Boolean) {
    val haptic = LocalHapticFeedback.current
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    var listing by remember { mutableStateOf(false) }
    val end = ui.blocks.filter { it.track == track && !it.gap }.maxOfOrNull { it.end } ?: 0f
    val full = (ui.entries[track] ?: 0) >= 16
    val endPx by rememberUpdatedState(end * barPx)
    Box(
        Modifier.fillMaxSize()
            .semantics { onLongClick("Add to track $track's song") { if (editable) { listing = false; menuAt = Offset((endPx - scrollNow()).coerceAtLeast(0f) + 40f, 20f); true } else false } }
            .pointerInput(track, editable) {
                detectTapGestures(onLongPress = { at -> if (editable && at.x + scrollNow() > endPx) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); listing = false; menuAt = at } })
            },
    ) {
        // the menu opens beside the finger (the lane is its anchor)
        LupeMenu(menuAt != null, { menuAt = null }, width = 232.dp, at = menuAt) {
            LupeCrossfade(listing) { l ->
                Column {
                    if (!l) {
                        MenuHeading("Track $track · end of the song")
                        MenuRow("New pattern", { actions.newBlock(track); menuAt = null }, enabled = !full)
                        MenuRow("Add a pattern ⌄", { listing = true }, enabled = !full)
                        MenuRow("Add a REST", { actions.insert(track, ui.entries[track] ?: 0, 65); menuAt = null }, enabled = !full)
                        if (full) BasicText("The track's 16 entries are full.", Modifier.padding(horizontal = 16.dp, vertical = 6.dp), style = LupeType.small)
                    } else {
                        MenuHeading("Add at the end")
                        ui.kept.forEach { p -> MenuRow("Pattern ${"%02d".format(p)}", { actions.insert(track, ui.entries[track] ?: 0, p); menuAt = null }) }
                        MenuRow("Back", { listing = false })
                    }
                }
            }
        }
    }
}

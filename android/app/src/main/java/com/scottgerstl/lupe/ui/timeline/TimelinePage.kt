package com.scottgerstl.lupe.ui.timeline

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
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
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
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
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.LocalTabTravelling
import com.scottgerstl.lupe.ui.shell.HOLD_MS
import com.scottgerstl.lupe.ui.shell.HoldItem
import com.scottgerstl.lupe.ui.shell.LocalHoldMenu
import com.scottgerstl.lupe.ui.shell.tapOrHoldMenu
import com.scottgerstl.lupe.ui.shell.selectedTrackAnchor
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

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
 * drags by its grip to set its REPS in whole passes (the blocks after it move as it goes). Hold opens the hold menu
 * under the finger (the shell's HoldMenu). Holding the empty lane after a track's last block adds to its song. While the song plays the FM-1 refuses
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
            BoxWithConstraints(
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
                // The selected track: a 2 dp outline in its own colour across its whole row (head and lane), never white (DESIGN.md "White is
                // global, the track's colour is the track's"; decision 29), as Pads draws it. It glides to the newly selected row and draws
                // nothing a finger can hit. While the tab pages slide the shell's travelling outline stands in for it (selectedTrackAnchor).
                if (ui.selectedTrack in 1..6) {
                    val rh = (maxHeight - GAP * 5) / 6
                    val at = animatedFloat((ui.selectedTrack - 1).toFloat(), Dur.STATE)
                    val travelling = LocalTabTravelling.current
                    val colour = Tok.track[(ui.selectedTrack - 1) % Tok.track.size]
                    Box(
                        Modifier.fillMaxWidth().height(rh + 4.dp).offset { IntOffset(0, ((rh + GAP).toPx() * at.value - 2.dp.toPx()).toInt()) }
                            .selectedTrackAnchor()
                            .drawBehind { if (!travelling) drawRoundRect(colour, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(9.dp.toPx()), style = Stroke(2.dp.toPx())) }
                            .clearAndSetSemantics { },
                    )
                }
            }
        }
    }
}

/** A track's head: its number on the track's colour and a short name. Tap selects the track (the row's outline, in the track's colour, says which is). */
@Composable
private fun TrackHead(track: Int, name: String, colour: Color, selected: Boolean, onTap: () -> Unit) {
    Row(
        Modifier.width(HEAD).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(Tok.control)
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
    val holdMenu = LocalHoldMenu.current
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
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

    /**
     * The block's hold menu (design/boards/radial-menu.html: the circle under the finger, the choices on lines out of it): Set pattern,
     * Passes, Duplicate, Insert before, Select sound, Delete (asked in place), and Chain or Split where they apply. Its choices are
     * pick-and-go, so PASSES is a short list here; the grip at the block's right end is the way to slide it.
     */
    fun blockItems(): List<HoldItem> = buildList {
        val erases = !b.rest && b.pattern != null && (ui.uses[b.pattern] ?: 0) <= 1
        val old = "%02d".format(b.pattern ?: 0)
        add(HoldItem("Set pattern…", sub = if (b.rest) "REST" else "Pattern $old", children = {
            ui.kept.map { p ->
                val n = "%02d".format(p)
                HoldItem("Pattern $n", checked = !b.rest && b.pattern == p,
                    confirm = if (erases && p != b.pattern) "Set $n: pattern $old is used nowhere else, so it's erased" else null) { actions.setPattern(b, p) }
            }
        }))
        add(HoldItem("Passes…", sub = "${b.reps} · ${barsText(b.length)}", children = {
            (listOf(1, 2, 3, 4, 6, 8, 12, 16) + b.reps).distinct().sorted().map { n -> HoldItem(if (n == 1) "1 pass" else "$n passes", sub = barsText(n * b.passBars), checked = n == b.reps) { actions.stretch(b, n) } }
        }))
        add(HoldItem("Duplicate") { actions.duplicate(b) })
        add(HoldItem("Insert before…", enabled = (ui.entries[b.track] ?: 0) < 16, sub = if ((ui.entries[b.track] ?: 0) < 16) null else "The track's 16 entries are full", children = {
            listOf(HoldItem("REST") { actions.insert(b.track, b.id, 65) }) + ui.kept.map { p -> HoldItem("Pattern ${"%02d".format(p)}") { actions.insert(b.track, b.id, p) } }
        }))
        add(HoldItem("Select sound") { actions.openSounds(b.track) })
        val gone = if (b.rest) "the REST" else "pattern $old"
        add(HoldItem("Delete…", confirm = "Delete block: $gone (${barsText(b.length)}) from track ${b.track}" + if (erases) ". It is used nowhere else, so it's erased" else "") { actions.delete(b) })
        // a chain plays its patterns as one block; Chain joins this block to the next, Split takes a chain apart
        if (ui.blocks.any { it.track == b.track && !it.gap && it.id == b.id + b.entries }) add(HoldItem("Chain with the next") { actions.chain(b) })
        if (b.entries > 1) add(HoldItem("Split the chain") { actions.split(b) })
    }
    fun openMenuAtCentre() { if (editable) coords?.takeIf { it.isAttached }?.let { c -> holdMenu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), colour, blockItems()) } }

    Box(
        Modifier
            .offset { IntOffset((shownStart * barPx - scrollNow()).toInt(), 0) }
            .width(widthDp.coerceAtLeast(4.dp)).fillMaxHeight()
            .onGloballyPositioned { coords = it }
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
                onLongClick("Block menu") { openMenuAtCentre(); true }
                if (editable) customActions = listOf(
                    CustomAccessibilityAction("Move one place later") { actions.moveBy(b, 1); true },
                    CustomAccessibilityAction("Move one place earlier") { actions.moveBy(b, -1); true },
                    CustomAccessibilityAction("One pass longer") { actions.stretch(b, b.reps + 1); true },
                    CustomAccessibilityAction("One pass shorter") { actions.stretch(b, b.reps - 1); true },
                    CustomAccessibilityAction("Duplicate") { actions.duplicate(b); true },
                    CustomAccessibilityAction("Delete…") { openMenuAtCentre(); true },
                )
            }
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
            } else Modifier)
            // a tap selects (or lets go); a hold opens the menu under the finger, and the same finger slides to a choice. Put after the drag, so
            // it hears the finger first: once its menu is open it keeps the finger and the block doesn't start to move under it.
            .tapOrHoldMenu(b.key, colour, items = { if (editable) blockItems() else emptyList() }, onTap = { actions.select(if (selected) null else b.key) }),
    ) {
        // the number stays in view while any of the block is: it rides the lanes' left edge when the block starts before it
        val pin = Modifier.align(Alignment.CenterStart).offset { IntOffset((scrollNow() - shownStart * barPx).coerceIn(0f, (size0 - 34.dp.toPx()).coerceAtLeast(0f)).toInt(), 0) }.padding(start = 6.dp)
        if (!b.rest) BasicText("%02d".format(b.pattern ?: 0), pin, style = LupeType.number.copy(fontSize = 16.sp, color = Tok.text), maxLines = 1, softWrap = false)
        else BasicText("REST", pin, style = LupeType.small.copy(fontSize = 11.sp), maxLines = 1, softWrap = false)
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

/** Holding the empty part of a track's lane, after its last block: the hold menu under the finger, to add to the song (New pattern, a kept pattern or a REST at the end). */
@Composable
private fun TrackEnd(track: Int, ui: TimelineUi, actions: TimelineActions, barPx: Float, scrollNow: () -> Float, editable: Boolean) {
    val haptic = LocalHapticFeedback.current
    val holdMenu = LocalHoldMenu.current
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val colour = Tok.track[(track - 1) % Tok.track.size]
    val end = ui.blocks.filter { it.track == track && !it.gap }.maxOfOrNull { it.end } ?: 0f
    val endPx by rememberUpdatedState(end * barPx)
    val items by rememberUpdatedState({
        val full = (ui.entries[track] ?: 0) >= 16
        val at = ui.entries[track] ?: 0
        val why = if (full) "The track's 16 entries are full" else null
        listOf(
            HoldItem("New pattern", sub = why, enabled = !full) { actions.newBlock(track) },
            HoldItem("Add a pattern…", sub = why, enabled = !full, children = { ui.kept.map { p -> HoldItem("Pattern ${"%02d".format(p)}") { actions.insert(track, at, p) } } }),
            HoldItem("Add a REST", sub = why, enabled = !full) { actions.insert(track, at, 65) },
        )
    })
    Box(
        Modifier.fillMaxSize().onGloballyPositioned { coords = it }
            .semantics { onLongClick("Add to track $track's song") { val c = coords?.takeIf { it.isAttached }; if (editable && c != null) { holdMenu?.open(c.localToWindow(Offset(((endPx - scrollNow()).coerceAtLeast(0f) + 40f).coerceAtMost(c.size.width - 1f), c.size.height / 2f)), colour, items()); true } else false } }
            // a hold on the empty lane (never a tap): as Modifier.tapOrHoldMenu, but only past the track's last block
            .pointerInput(track, editable) {
                if (!editable) return@pointerInput
                awaitEachGesture {
                    val down = awaitFirstDown()
                    if (down.position.x + scrollNow() <= endPx) return@awaitEachGesture
                    var cancelled = false
                    val up = withTimeoutOrNull(HOLD_MS) { waitForUpOrCancellation().also { if (it == null) cancelled = true } }
                    val c = coords?.takeIf { it.isAttached }
                    if (cancelled || up != null || holdMenu == null || c == null) return@awaitEachGesture
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    holdMenu.open(c.localToWindow(currentEvent.changes.firstOrNull { it.id == down.id }?.position ?: down.position), colour, items())
                    while (true) {
                        val e = awaitPointerEvent()
                        val ch = e.changes.firstOrNull { it.id == down.id } ?: break
                        ch.consume()
                        if (!ch.pressed) { holdMenu.release(); break }
                        holdMenu.drag(c.localToWindow(ch.position))
                    }
                }
            },
    )
}

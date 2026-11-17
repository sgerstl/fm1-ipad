package com.scottgerstl.lupe.ui.timeline

import androidx.compose.ui.layout.boundsInWindow

import androidx.compose.ui.semantics.disabled

import androidx.compose.foundation.interaction.collectIsPressedAsState

import androidx.compose.foundation.clickable

import androidx.compose.ui.draw.drawWithContent

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
private val RULER = 40.dp
private val HEAD = 104.dp   // hybrid UI (spec 4.4): track heads are 104-wide pills, badge and name
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

        // while it plays, the FM-1 refuses changes to the song: the app strip says so, with Stop (spec 4.4); it leaves when the song stops
        val messages = com.scottgerstl.lupe.ui.shell.LocalMessages.current
        LaunchedEffect(playing) {
            if (playing) messages.refuse("Stop to change the song", fix = com.scottgerstl.lupe.ui.shell.STOP_FIX)
            else messages.fixed { it == com.scottgerstl.lupe.ui.shell.STOP_FIX }
        }
        // it belongs to the Timeline: leaving the tab takes it down
        androidx.compose.runtime.DisposableEffect(Unit) { onDispose { messages.fixed { it == com.scottgerstl.lupe.ui.shell.STOP_FIX } } }
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
                // zoom: a connected − + pair, 50 × 40 each (spec 3.4, 4.4)
                Row(Modifier.width(HEAD).fillMaxHeight(), horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
                    val shown = (lanePx / barPx)
                    ZoomHalf("−", "Show more bars", first = true, enabled = shown < BARS_MAX - 0.01f) { zoomStep(true) }
                    ZoomHalf("+", "Show fewer bars", first = false, enabled = shown > BARS_MIN + 0.01f) { zoomStep(false) }
                }
                Box(Modifier.weight(1f).fillMaxHeight()) {
                    Canvas(
                        Modifier.fillMaxSize().clearAndSetSemantics { }
                            .pointerInput(Unit) { detectTransformGestures { c, pan, zoom, _ -> view.touchedAt = System.currentTimeMillis(); if (zoom != 1f) zoomTo(latest.value.second * zoom, c.x); view.scroll = scrollNow() - pan.x } },
                    ) {
                        val sc = scrollNow(); val step = rulerStep(barDp.value)
                        val first = (sc / barPx).toInt().coerceAtLeast(0)
                        for (b in first..minOf(bars, first + (size.width / barPx).toInt() + 1)) {
                            val x = b * barPx - sc
                            drawLine(if (b % 4 == 0) Tok.text3 else Tok.control, Offset(x, size.height - (if (b % 4 == 0) 10 else 6).dp.toPx()), Offset(x, size.height), 1.dp.toPx())
                            if (b % step == 0 && b < bars) {
                                val r = tm.measure("${b + 1}", LupeType.small.copy(fontSize = 12.sp, color = if (b >= ui.totalBars) Tok.text2 else Tok.text2Raised))
                                drawText(r, topLeft = Offset(x + 4.dp.toPx(), 6.dp.toPx()))
                            }
                        }
                        // the playhead's handle: a 14 round knob on the ruler, over the line that runs down the lanes
                        head.value?.let { p -> val x = p.toFloat() * barPx - sc; if (x >= -7.dp.toPx() && x <= size.width + 7.dp.toPx()) {
                            drawLine(Tok.text, Offset(x, size.height - 12.dp.toPx()), Offset(x, size.height), 2.dp.toPx())
                            drawCircle(Tok.text, 7.dp.toPx(), Offset(x, size.height - 14.dp.toPx()))
                        } }
                    }
                    // the keys that pan without a drag (while it plays the app strip says why nothing can be changed, with Stop)
                    if (!playing) Row(Modifier.align(Alignment.CenterEnd).background(Tok.page), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
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
                // The selected track: its colour muted over the page (28 %) under its whole row, head and lane, as Pads draws it (decision 31,
                // board 76; the 2 dp outline is the launch timer's alone now). It glides to the newly selected row, behind everything. While
                // the tab pages slide the shell's travelling band stands in for it (selectedTrackAnchor).
                if (ui.selectedTrack in 1..6) {
                    val rh = (maxHeight - GAP * 5) / 6
                    val at = animatedFloat((ui.selectedTrack - 1).toFloat(), Dur.STATE)
                    val travelling = LocalTabTravelling.current
                    val band = com.scottgerstl.lupe.ui.shell.trackBand(Tok.track[(ui.selectedTrack - 1) % Tok.track.size])
                    Box(
                        Modifier.fillMaxWidth().height(rh + 4.dp).offset { IntOffset(0, ((rh + GAP).toPx() * at.value - 2.dp.toPx()).toInt()) }
                            .selectedTrackAnchor()
                            .drawBehind { if (!travelling) drawRoundRect(band, cornerRadius = CornerRadius(10.dp.toPx())) }
                            .clearAndSetSemantics { },
                    )
                }
                Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(GAP)) {
                    for (t in 1..6) {
                        val colour = Tok.track[(t - 1) % Tok.track.size]
                        Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(GAP)) {
                            TrackHead(t, ui.trackNames.getOrNull(t - 1).orEmpty(), colour, ui.selectedTrack == t) { actions.selectTrack(t) }
                            val drag = remember(t) { TrackDrag() }
                            // the selected track's lane lets its band show through: the well fades out as the band arrives
                            val onBand = animatedFloat(if (ui.selectedTrack == t) 1f else 0f, Dur.STATE)
                            Box(
                                Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(14.dp))
                                    .drawBehind {
                                        if (onBand.value < 1f) drawRect(Tok.well.copy(alpha = 1f - onBand.value))
                                    }
                                    .drawWithContent {
                                        drawContent()
                                        // the selected lane: a 2 dp edge in its colour (spec 4.4), drawn over its blocks
                                        if (onBand.value > 0f) drawRoundRect(colour.copy(alpha = onBand.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(13.dp.toPx()), style = Stroke(2.dp.toPx()))
                                    }
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
                                    key(b.key) { BlockView(b, colour, b.key == ui.selected, barPx, bars, ui, actions, !playing, drag, lanePx, ::scrollNow, headBars = if (b.playing) head.value?.toFloat() else null) { d -> view.scroll = clampScroll(scrollNow() + d, latest.value.third, latest.value.first) } }
                                }
                            }
                        }
                    }
                }
                // the playhead, over the lanes (read while drawing: it moves with the clock, nothing recomposes)
                Canvas(Modifier.fillMaxSize().padding(start = HEAD + GAP).clip(RoundedCornerShape(14.dp)).clearAndSetSemantics { }) {
                    val p = head.value
                    if (p != null) { val x = p.toFloat() * barPx - scrollNow(); if (x >= 0f && x <= size.width) drawLine(Tok.text, Offset(x, 0f), Offset(x, size.height), 2.dp.toPx()) }
                }
            }
        }
    }
}

/**
 * A track's head (hybrid UI, spec 4.4): a 104-wide pill on `control`, the badge and the name. Selected, the track's tint with a 2 dp edge in its
 * colour (its lane gets the same edge), and the badge squares off on the spring. Tap selects the track.
 */
@Composable
private fun TrackHead(track: Int, name: String, colour: Color, selected: Boolean, onTap: () -> Unit) {
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE).value
    Row(
        Modifier.width(HEAD).fillMaxHeight().clip(RoundedCornerShape(50))
            .drawBehind {
                drawRoundRect(lerp(Tok.control, lerp(Tok.page, colour, 0.30f), sel), cornerRadius = CornerRadius(size.height / 2))
                if (sel > 0f) drawRoundRect(colour.copy(alpha = sel), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(size.height / 2 - 1.dp.toPx()), style = Stroke(2.dp.toPx()))
            }
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Track $track, $name"; stateDescription = if (selected) "Selected" else "" }
            .pointerInput(track) { detectTapGestures { onTap() } }
            .padding(horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        com.scottgerstl.lupe.ui.mix.TrackBadge(track, colour, selected, 24.dp, 15)
        BasicText(name, Modifier.weight(1f).clearAndSetSemantics { }, style = LupeType.key.copy(fontSize = 14.sp, lineHeight = 16.sp, color = Tok.text, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal), maxLines = 1, overflow = TextOverflow.Ellipsis,
            autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 14.sp, stepSize = 0.5.sp))
    }
}

/** Half of the zoom pair (spec 3.4): 50 × 40 on `control`, the group's outer end round, the inner corner 8; a press darkens it. */
@Composable
private fun ZoomHalf(label: String, description: String, first: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val press = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100).value
    Box(
        Modifier.size(50.dp, 40.dp)
            .drawBehind {
                val pill = size.height / 2; val inner = 8.dp.toPx()
                with(com.scottgerstl.lupe.ui.shell.SegmentDraw) { segment(Tok.control, if (first) pill else inner, if (first) inner else pill) }
                if (press > 0f) with(com.scottgerstl.lupe.ui.shell.SegmentDraw) { segment(Color.Black.copy(alpha = 0.2f * press), if (first) pill else inner, if (first) inner else pill) }
            }
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = description; if (!enabled) disabled() }
            .clickable(source, null, enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { BasicText(label, style = LupeType.key.copy(fontSize = 20.sp, color = if (enabled) Tok.text else Tok.text3)) }
}

/**
 * One block, a bar of its track's colour lying along the row. Dragging its body REORDERS it among its track's blocks (it
 * follows the finger and lands in the slot it is closest to); dragging its right end sets its REPS (whole passes). Only a
 * selected block drags: an unselected one's drag is the song's pan. Near either end of the lanes the song pans under it.
 */
@Composable
private fun BlockView(
    b: BlockUi, colour: Color, selected: Boolean, barPx: Float, totalBars: Int, ui: TimelineUi, actions: TimelineActions, editable: Boolean, drag: TrackDrag,
    lanePx: Float, scrollNow: () -> Float, headBars: Float? = null, panBy: (Float) -> Unit,
) {
    val density = LocalDensity.current
    val haptic = LocalHapticFeedback.current
    val reduce = LocalReduceMotion.current
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    val holdMenu = LocalHoldMenu.current
    val editGrow = com.scottgerstl.lupe.ui.shell.LocalEditGrow.current
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
    // shape as state, as the pads: playing fills in the track's colour (eased) and the block squashes and settles on the spring
    val play = animatedFloat(if (b.playing && !b.rest) 1f else 0f, Dur.STATE).value
    val playSquash = com.scottgerstl.lupe.ui.theme.rememberSquash(b.playing && !b.rest, reduce)
    val fill = if (b.rest) Color.Transparent else lerp(lerp(Tok.page, colour, 0.30f), colour, play)
    val name = ui.trackNames.getOrNull(b.track - 1).orEmpty()
    val what = if (b.rest) "rest" else "pattern ${"%02d".format(b.pattern ?: 0)}"
    val words = "Track ${b.track} $name, ${barRange(b)}, $what" + if (b.playing) ", playing" else ""
    // the pass playing now (1-based), from the playhead's place in the song, while this block plays
    val passNow = if (b.playing && b.passBars > 0f) headBars?.let { h -> ((h - b.start) / b.passBars).toInt().coerceIn(0, b.reps - 1) + 1 } else null

    /**
     * The block's hold menu (design/boards/radial-menu.html: the circle under the finger, the choices on lines out of it): Set pattern,
     * Passes, Duplicate, Insert before, Select sound, Delete (asked in place), and Chain or Split where they apply. Its choices are
     * pick-and-go, so PASSES is a short list here; the grip at the block's right end is the way to slide it.
     */
    fun blockItems(): List<HoldItem> = buildList {
        val erases = !b.rest && b.pattern != null && (ui.uses[b.pattern] ?: 0) <= 1
        val old = "%02d".format(b.pattern ?: 0)
        // the iPad's block menu opens with Edit pattern (decision 31: the full set): the Edit tab, on this block's pattern
        // priority tiles (Scott, 2026-11-17, "C"): Edit steps, Pattern, Sound. The menu opens only while stopped (editable), so nothing folds
        if (!b.rest) add(HoldItem("Edit steps", tile = true) { coords?.takeIf { it.isAttached }?.let { editGrow.from(it.boundsInWindow(), colour, 12f) }
            actions.selectTrack(b.track); actions.select(b.key); actions.edit(b) })
        add(HoldItem("Set pattern…", sub = if (b.rest) "REST" else "Pattern $old", tile = true, short = "Pattern", tileSub = if (b.rest) "REST" else old, children = {
            ui.kept.map { p ->
                val n = "%02d".format(p)
                HoldItem("Pattern $n", checked = !b.rest && b.pattern == p,
                    confirm = if (erases && p != b.pattern) "Set $n: pattern $old is used nowhere else, so it's erased" else null) { actions.setPattern(b, p) }
            }
        }))
        add(HoldItem("Passes…", sub = "${b.reps} · ${barsText(b.length)}", group = "Playback", children = {
            (listOf(1, 2, 3, 4, 6, 8, 12, 16) + b.reps).distinct().sorted().map { n -> HoldItem(if (n == 1) "1 pass" else "$n passes", sub = barsText(n * b.passBars), checked = n == b.reps) { actions.stretch(b, n) } }
        }))
        add(HoldItem("Duplicate", group = "Arrange") { actions.duplicate(b) })
        add(HoldItem("Insert before…", group = "Arrange", enabled = (ui.entries[b.track] ?: 0) < 16, sub = if ((ui.entries[b.track] ?: 0) < 16) null else "The track's 16 entries are full", children = {
            listOf(HoldItem("REST") { actions.insert(b.track, b.id, 65) }) + ui.kept.map { p -> HoldItem("Pattern ${"%02d".format(p)}") { actions.insert(b.track, b.id, p) } }
        }))
        add(HoldItem("Select sound", tile = true, short = "Sound", tileSub = name.ifEmpty { null }) { actions.openSounds(b.track) })
        // the way to reorder that isn't a drag (WCAG 2.5.7), as the iPad's Move earlier / Move later
        val at = mine.indexOfFirst { it.key == b.key }
        add(HoldItem("Move earlier", enabled = at > 0, group = "Arrange") { actions.moveBy(b, -1) })
        add(HoldItem("Move later", enabled = at in 0 until mine.size - 1, group = "Arrange") { actions.moveBy(b, 1) })
        // no confirm: it goes at once and can come back until the next edit (the app strip, and "Undo delete" in this track's lane menu)
        add(HoldItem("Delete", sub = if (erases) "Pattern $old is used nowhere else" else null, group = "Remove") { actions.delete(b) })
        // a chain plays its patterns as one block; Chain joins this block to the next, Split takes a chain apart
        if (ui.blocks.any { it.track == b.track && !it.gap && it.id == b.id + b.entries }) add(HoldItem("Chain with the next", group = "Chain") { actions.chain(b) })
        if (b.entries > 1) add(HoldItem("Split the chain", group = "Chain") { actions.split(b) })
    }
    fun openMenuAtCentre() { if (editable) coords?.takeIf { it.isAttached }?.let { c -> holdMenu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), colour, blockItems()) } }

    Box(
        Modifier
            .offset { IntOffset((shownStart * barPx - scrollNow()).toInt(), 0) }
            .width(widthDp.coerceAtLeast(4.dp)).fillMaxHeight()
            .onGloballyPositioned { coords = it }
            .padding(vertical = 3.dp)
            .graphicsLayer {
                if (dragging && !resizing) { shadowElevation = 8.dp.toPx(); shape = RoundedCornerShape(12.dp) }
                val (qx, qy) = playSquash(); scaleX = qx; scaleY = qy
            }
            .clip(RoundedCornerShape(12.dp)).background(fill)
            .drawBehind {
                val r = CornerRadius(11.dp.toPx())
                // a rest: a dashed box in the edge grey; any other block not playing: its tint with a 1.5 dp edge in the track's colour (fading as it fills)
                if (b.rest) drawRoundRect(Tok.primaryEdge, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), r, style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.dp.toPx()))))
                else if (play < 1f) drawRoundRect(colour.copy(alpha = 1f - play), Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), r, style = Stroke(1.5.dp.toPx()))
                if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), r, style = Stroke(2.dp.toPx()))
                // what comes next: a thin white outline
                if (b.next && !b.playing) drawRoundRect(Tok.text2Raised, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), r, style = Stroke(1.5.dp.toPx()))
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
                    CustomAccessibilityAction("Delete") { actions.delete(b); true },
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
        if (!b.rest) BasicText("%02d".format(b.pattern ?: 0), pin, style = LupeType.number.copy(fontSize = 17.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, color = lerp(Tok.text, Tok.onColour, play)), maxLines = 1, softWrap = false)
        else BasicText("Rest", pin, style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised), maxLines = 1, softWrap = false)
        // the pass count in a dark chip at the right end ("×4", or "2/4" while it plays), when there's room
        if (!b.rest && b.reps > 1 && size0 >= 72.dp.value * density.density) {
            val chip = if (b.playing && passNow != null) "$passNow/${b.reps}" else "×${b.reps}"
            Box(Modifier.align(Alignment.CenterEnd).padding(end = if (selected && editable) 14.dp else 6.dp).background(Tok.page, RoundedCornerShape(50)).padding(horizontal = 6.dp, vertical = 2.dp)) {
                BasicText(chip, style = LupeType.number.copy(fontSize = 11.sp, lineHeight = 12.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, color = Tok.text))
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
        // a block deleted a moment ago: the way back, here as well as in the app strip (only while the track is as the delete left it)
        val undo = ui.deleted.lastOrNull { it.track == track }
        listOfNotNull(
            undo?.let { u -> HoldItem("Undo delete", sub = u.pattern?.let { "Pattern %02d comes back".format(it) } ?: "The REST comes back", group = "Undo") { actions.undoDelete(u) } },
            HoldItem("New pattern", sub = why, enabled = !full, tile = true, short = "New") { actions.newBlock(track) },
            HoldItem("Add a pattern…", sub = why, enabled = !full, tile = true, short = "Pattern", children = { ui.kept.map { p -> HoldItem("Pattern ${"%02d".format(p)}") { actions.insert(track, at, p) } } }),
            HoldItem("Add a REST", sub = why, enabled = !full, tile = true, short = "Rest") { actions.insert(track, at, 65) },
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
                        if (!ch.pressed) break   // (decision 36: the menu's choices are picked by a tap; the held finger only opens it)
                    }
                }
            },
    )
}

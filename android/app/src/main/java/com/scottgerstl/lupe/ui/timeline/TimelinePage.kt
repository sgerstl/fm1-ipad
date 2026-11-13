package com.scottgerstl.lupe.ui.timeline

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import com.scottgerstl.lupe.ui.shell.WideKey
import com.scottgerstl.lupe.ui.slide.MenuSlideRow
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

private val RULER = 28.dp
private val GAP = 4.dp

/**
 * The Timeline tab (board 58, decision 6): six tracks as columns, bars running down, the same song as board 57's lanes.
 * At top only about 20 bars show, at split about 8 and the song scrolls. Blocks are the track's colour at 45 % over the page
 * (the boards' contrast fix). Tap selects; a selected block drags to move along its own column and drags by its foot to
 * stretch, snapping to whole bars; hold opens its menu beside the finger (Pattern, Bars by sliding, Duplicate, Select
 * sound, Delete… asked in place). While the song plays the FM-1 refuses changes to the order: a strip says so, with Stop.
 * The playhead runs with the clock.
 */
@Composable
fun TimelinePage(uiState: State<TimelineUi>, actions: TimelineActions, head: State<Double?>, top: State<TopState>, modifier: Modifier = Modifier) {
    val ui = uiState.value
    val playing by remember { derivedStateOf { top.value.playing } }
    Box(modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val headerH = 36.dp
            // the Stop strip overlays the foot: the rows keep their scale (the song scrolls up to clear it)
            val viewport = maxHeight - headerH - 6.dp
            val visible = if (viewport >= 420.dp) 20 else 8
            val barH = viewport / visible
            val scroll = rememberScrollState()
            Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                // the tracks, as column heads
                Row(Modifier.fillMaxWidth().height(headerH), horizontalArrangement = Arrangement.spacedBy(GAP)) {
                    Spacer(Modifier.width(RULER))
                    for (t in 1..6) {
                        val colour = Tok.track[(t - 1) % Tok.track.size]
                        val sel = animatedFloat(if (ui.selectedTrack == t) 1f else 0f, Dur.STATE)
                        Box(
                            Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(colour)
                                .drawBehind { drawRoundRect(Tok.text.copy(alpha = sel.value), cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Track $t, ${ui.trackNames.getOrNull(t - 1) ?: ""}"; stateDescription = if (ui.selectedTrack == t) "Selected" else "" }
                                .pointerInput(t) { detectTapGestures { actions.selectTrack(t) } },
                            contentAlignment = Alignment.Center,
                        ) { BasicText("$t", style = LupeType.key.copy(fontSize = 15.sp, color = Tok.onColour)) }
                    }
                }
                Box(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(6.dp))) {
                    val bars = maxOf(ui.totalBars + 4, visible)
                    val contentH = barH * bars
                    Box(Modifier.fillMaxSize().verticalScroll(scroll).padding(bottom = if (playing) 48.dp else 0.dp)) {
                        Row(Modifier.fillMaxWidth().height(contentH), horizontalArrangement = Arrangement.spacedBy(GAP)) {
                            // the ruler: a number a bar, the first bar 1
                            Box(Modifier.width(RULER).fillMaxHeight().clearAndSetSemantics { }) {
                                for (b in 0 until bars) BasicText(
                                    "${b + 1}", Modifier.offset(y = barH * b).padding(top = 2.dp),
                                    style = LupeType.small.copy(fontSize = 12.sp, color = if (b >= ui.totalBars) Tok.text2 else Tok.text2Raised),
                                )
                            }
                            for (t in 1..6) {
                                val colour = Tok.track[(t - 1) % Tok.track.size]
                                val drag = remember(t) { TrackDrag() }
                                Box(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(Tok.well)) {
                                    TrackEnd(t, ui, actions, barH, !playing)
                                    ui.blocks.filter { it.track == t && !it.gap }.forEach { b ->
                                        key(b.key) { BlockView(b, colour, b.key == ui.selected, barH, bars, ui, actions, !playing, drag) }
                                    }
                                }
                            }
                        }
                        // the bar lines, and the playhead (read while drawing: it moves with the clock, nothing recomposes)
                        Canvas(Modifier.fillMaxWidth().height(contentH).clearAndSetSemantics { }) {
                            val h = barH.toPx()
                            for (b in 0..bars) drawLine(Tok.control, Offset(0f, b * h), Offset(RULER.toPx() - 2.dp.toPx(), b * h), 1.dp.toPx())
                            val p = head.value
                            if (p != null) { val y = p.toFloat() * h; drawLine(Tok.text, Offset(0f, y), Offset(size.width, y), 2.dp.toPx()) }
                        }
                    }
                }
            }
            // while it plays the order is locked: a strip says so, with Stop
            if (playing) Row(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(40.dp).clip(RoundedCornerShape(8.dp)).background(Tok.control).padding(start = 12.dp, end = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                BasicText("Stop to change the song", Modifier.weight(1f), style = LupeType.key)
                Key({ actions.stop() }, "Stop the song to change it", width = 70.dp, height = 32.dp, minTarget = 40.dp, on = true) { fg -> KeyLabel("■ Stop", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            }
        }
    }
}

private enum class BlockMenu { Root, Pattern, PatternConfirm, Delete, Insert }

/**
 * One block. A track's song is a list of entries that play back to back, so a block has no free place: dragging it by its
 * body REORDERS it among its track's blocks (it follows the finger, and lands where it is closest to a slot), and dragging
 * its foot sets its REPS (whole passes, so whole multiples of its pass). Only a selected block drags.
 */
@Composable
private fun BlockView(b: BlockUi, colour: Color, selected: Boolean, barH: androidx.compose.ui.unit.Dp, totalBars: Int, ui: TimelineUi, actions: TimelineActions, editable: Boolean, drag: TrackDrag) {
    val density = LocalDensity.current
    val haptic = LocalHapticFeedback.current
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    var menuMode by remember { mutableStateOf(BlockMenu.Root) }
    var pendingPattern by remember { mutableStateOf(0) }
    var armedAt by remember { mutableStateOf(0L) }
    var tickKey by remember { mutableIntStateOf(0) }
    val reduce = com.scottgerstl.lupe.ui.theme.LocalReduceMotion.current
    val barPx = with(density) { barH.toPx() }
    val edgePx = with(density) { 28.dp.toPx() }
    val mine = ui.blocks.filter { it.track == b.track && !it.gap }.sortedBy { it.start }
    val idx = mine.indexOfFirst { it.id == b.id }

    val dragging = drag.source?.key == b.key
    val resizing = dragging && drag.resizing
    val offsetBars = drag.offsetBars
    val places = if (dragging && !resizing) placesFor(mine, b.id, offsetBars) else 0
    val repsNow = if (resizing) repsFor(b, offsetBars) else b.reps
    // a neighbour makes room: it slides by what the dragged block takes or gives up, with the same easing as everything else (nothing pops)
    val shiftTarget = if (!dragging) siblingShift(b, mine, drag.source, drag.resizing, offsetBars) else 0f
    val shift = animatedFloat(shiftTarget, if (reduce) 1 else Dur.STATE)
    val shownStart = if (dragging && !resizing) (b.start + offsetBars).coerceIn(0f, (totalBars - b.length).coerceAtLeast(0f)) else b.start + shift.value
    val shownLen = if (resizing) repsNow * b.passBars else b.length
    val fill = if (b.rest) Tok.page else lerp(Tok.page, colour, 0.45f)
    val name = ui.trackNames.getOrNull(b.track - 1).orEmpty()
    val what = if (b.rest) "rest" else "pattern ${"%02d".format(b.pattern ?: 0)}"
    val words = "Track ${b.track} $name, ${barRange(b)}, $what" + if (b.playing) ", playing" else ""

    fun openMenu(at: Offset) { if (editable) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); menuMode = BlockMenu.Root; menuAt = at } }

    Box(
        Modifier
            .offset { IntOffset(0, (shownStart * barPx).toInt()) }
            .fillMaxWidth().height(barH * shownLen - 2.dp)
            .graphicsLayer { if (dragging && !resizing) { shadowElevation = 8.dp.toPx(); shape = RoundedCornerShape(6.dp) } }
            .clip(RoundedCornerShape(6.dp)).background(fill)
            .drawBehind {
                if (b.rest) drawRoundRect(Tok.outline, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(5.dp.toPx()), style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 3.dp.toPx()))))
                if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(5.dp.toPx()), style = Stroke(2.dp.toPx()))
                // what the FM-1 is playing on this track now: a bar along the head of the block; what comes next: a thin outline
                if (b.playing) drawRect(Tok.text, size = Size(size.width, 3.dp.toPx()))
                else if (b.next) drawRoundRect(Tok.text2, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(5.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                // the foot's grip, when it can be stretched
                // (a one-bar block is short: its grip is a small notch at the very foot, clear of the number)
                if (selected && editable) { val tall = size.height >= 56.dp.toPx(); val gw = if (tall) 28.dp.toPx() else 16.dp.toPx(); drawRoundRect(Tok.text.copy(alpha = 0.8f), Offset(size.width / 2 - gw / 2, size.height - (if (tall) 8.dp.toPx() else 4.dp.toPx())), Size(gw, 2.dp.toPx()), CornerRadius(1.dp.toPx())) }
            }
            .semantics(mergeDescendants = true) {
                role = Role.Button; contentDescription = words; stateDescription = if (selected) "Selected" else ""
                onClick { actions.select(if (selected) null else b.key); true }
                onLongClick("Block menu") { openMenu(Offset(60f, 60f)); true }
                if (editable) customActions = listOf(
                    CustomAccessibilityAction("Move one place later") { actions.moveBy(b, 1); true },
                    CustomAccessibilityAction("Move one place earlier") { actions.moveBy(b, -1); true },
                    CustomAccessibilityAction("One pass longer") { actions.stretch(b, b.reps + 1); true },
                    CustomAccessibilityAction("One pass shorter") { actions.stretch(b, b.reps - 1); true },
                    CustomAccessibilityAction("Duplicate") { actions.duplicate(b); true },
                    CustomAccessibilityAction("Delete…") { menuMode = BlockMenu.Delete; armedAt = System.currentTimeMillis(); menuAt = Offset(60f, 60f); true },
                )
            }
            .pointerInput(b.key, editable, selected) { detectTapGestures(onTap = { actions.select(if (selected) null else b.key) }, onLongPress = { openMenu(it) }) }
            // only a selected block drags (an unselected one's drag is the page's scroll)
            .then(if (selected && editable) Modifier.pointerInput(b.key, b.start, b.reps, mine.size) {
                detectDragGestures(
                    onDragStart = { at -> drag.start(b, at.y > size.height - edgePx, barPx); tickKey = 0 },
                    onDragEnd = {
                        // what the finger did, read now (not what it had done when the gesture began)
                        if (drag.resizing) { val r = repsFor(b, drag.offsetBars); if (r != b.reps) actions.stretch(b, r) }
                        else { val p = placesFor(mine, b.id, drag.offsetBars); if (p != 0) actions.moveBy(b, p) }
                        drag.end()
                    },
                    onDragCancel = { drag.end() },
                ) { change, dragAmount ->
                    change.consume(); drag.accPx += dragAmount.y
                    val k = if (drag.resizing) repsFor(b, drag.offsetBars) else placesFor(mine, b.id, drag.offsetBars)
                    if (k != tickKey) { tickKey = k; haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                }
            } else Modifier),
    ) {
        if (!b.rest) BasicText("%02d".format(b.pattern ?: 0), Modifier.align(Alignment.TopCenter).padding(top = 3.dp), style = LupeType.number.copy(fontSize = 18.sp, color = Tok.text))
        else BasicText("REST", Modifier.align(Alignment.TopCenter).padding(top = 6.dp), style = LupeType.small.copy(fontSize = 12.sp))
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

/** Holding the empty part of a track's column, after its last block: a menu beside the finger to add to the song (New pattern, or a kept pattern or a REST at the end). */
@Composable
private fun TrackEnd(track: Int, ui: TimelineUi, actions: TimelineActions, barH: androidx.compose.ui.unit.Dp, editable: Boolean) {
    val density = LocalDensity.current
    val haptic = LocalHapticFeedback.current
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    var listing by remember { mutableStateOf(false) }
    val end = ui.blocks.filter { it.track == track && !it.gap }.maxOfOrNull { it.end } ?: 0f
    val endPx = with(density) { (barH * end).toPx() }
    val full = (ui.entries[track] ?: 0) >= 16
    Box(
        Modifier.fillMaxSize()
            .semantics { onLongClick("Add to track $track's song") { if (editable) { listing = false; menuAt = Offset(60f, endPx + 40f); true } else false } }
            .pointerInput(track, editable, endPx) {
                detectTapGestures(onLongPress = { at -> if (editable && at.y > endPx) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); listing = false; menuAt = at } })
            },
    ) {
        // anchored to a 1 dp box at the empty spot, so the menu opens beside the finger
        Box(Modifier.offset { IntOffset(0, endPx.toInt()) }.height(1.dp).width(1.dp)) {
            LupeMenu(menuAt != null, { menuAt = null }, width = 232.dp, at = menuAt?.let { Offset(it.x, it.y - endPx) }) {
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
}

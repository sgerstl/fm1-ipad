package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PadEntry
import com.scottgerstl.lupe.core.PadKind
import com.scottgerstl.lupe.core.PadPlay
import com.scottgerstl.lupe.core.PadRow
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.delay

private val PAD_W = 78.dp
private val GAP = 4.dp

/**
 * The Pads tab (board 53): six track rows (number, Mute, then the entries panning together), the scenes row
 * under them (Store, sixteen scenes, Select). With Select on a pad tap picks the pad for the editor and
 * launches nothing. Row height grows with the space: 40 dp at split, about 110 at top only.
 */
@Composable
fun PadsPage(pads: PadsState, core: LupeCore, modifier: Modifier = Modifier) {
    var select by rememberSaveable { mutableStateOf(false) }
    var store by rememberSaveable { mutableStateOf(false) }
    var notice by remember { mutableStateOf<String?>(null) }
    // Store over a kept scene asks once more, in place (Scott, 2026-11-14): the scene, and when it was asked
    var confirmScene by remember { mutableStateOf<Int?>(null) }
    var confirmAt by remember { mutableStateOf(0L) }
    val scroll = rememberScrollState()
    val haptic = LocalHapticFeedback.current

    BoxWithConstraints(modifier.fillMaxSize()) {
        val scenesH = 34.dp
        val rows = pads.rows.ifEmpty { return@BoxWithConstraints }
        val rh = ((maxHeight - scenesH - 8.dp - GAP * (rows.size - 1)) / rows.size).coerceAtLeast(24.dp)
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(GAP)) {
                // row heads: the number (tap: select the track) and Mute
                Column(verticalArrangement = Arrangement.spacedBy(GAP)) {
                    rows.forEach { r -> RowHead(r, rh, r.track == pads.selected.track, core) }
                }
                Box(Modifier.weight(1f).fillMaxHeight().horizontalScroll(scroll)) {
                    Column(verticalArrangement = Arrangement.spacedBy(GAP)) {
                        rows.forEach { r ->
                            Row(horizontalArrangement = Arrangement.spacedBy(GAP)) {
                                r.entries.forEachIndexed { i, e ->
                                    Pad(r, i, e, rh, selected = pads.selected.track == r.track && pads.selected.entry == i, core = core, selectMode = select, pads = pads)
                                }
                            }
                        }
                    }
                }
            }
            // scenes: Store, sixteen in a pan, Select
            Box(Modifier.fillMaxWidth().height(scenesH)) {
                Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(GAP), verticalAlignment = Alignment.CenterVertically) {
                    Key({ store = !store; if (store) select = false }, "Store scene", width = 56.dp, height = scenesH, minTarget = scenesH, on = store,
                        role = Role.Switch, state = if (store) "On: tap a scene to store what plays now" else "Off") { fg -> KeyLabel("Store", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                    Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(GAP)) {
                        pads.scenes.forEachIndexed { i, s ->
                            val label = "Scene ${i + 1}" + if (!s.stored) ", empty" else if (s.current) ", current" else ""
                            Box(
                                Modifier.width(34.dp).height(scenesH)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (s.current) Tok.lifted else if (s.stored) Tok.control else Tok.well)
                                    .drawBehind { if (s.current) drawRoundRect(Tok.text2Raised, size = size, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(1.5.dp.toPx())) }
                                    .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = label }
                                    .pointerInput(i, store, s.stored) {
                                        detectTapGestures {
                                            when {
                                                store && s.stored -> { confirmScene = i; confirmAt = System.currentTimeMillis(); notice = null }   // a kept scene: ask first
                                                store -> { core.send(Intent.SceneStore(i)); store = false; haptic.performHapticFeedback(HapticFeedbackType.Confirm) }
                                                s.stored -> core.send(Intent.SceneRecall(i))
                                                else -> notice = "Scene ${i + 1} is empty. Tap Store, then a scene, to keep what plays now."
                                            }
                                        }
                                    },
                                contentAlignment = Alignment.Center,
                            ) { BasicText("${i + 1}", style = LupeType.key.copy(fontSize = 13.sp, color = if (s.stored) Tok.text else Tok.text2)) }
                        }
                    }
                    Key({ select = !select; if (select) store = false }, "Select pad for the editor", width = 64.dp, height = scenesH, minTarget = scenesH, on = select,
                        role = Role.Switch, state = if (select) "On: a pad tap picks it and launches nothing" else "Off") { fg -> KeyLabel("Select", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                }
                // Store over a kept scene: a red-outlined row naming it, Cancel beside it; a tap ignores the first 0.4 s
                LupeCrossfade(confirmScene, Modifier.fillMaxSize()) { c ->
                    if (c != null) Row(Modifier.fillMaxSize().background(Tok.page), horizontalArrangement = Arrangement.spacedBy(GAP), verticalAlignment = Alignment.CenterVertically) {
                        val words = "Replace scene ${c + 1} with what plays now"
                        Box(
                            Modifier.weight(1f).fillMaxHeight()
                                .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                                .semantics(mergeDescendants = true) {
                                    role = Role.Button; contentDescription = "Confirm: $words"
                                    onClick { if (System.currentTimeMillis() - confirmAt > 400) { core.send(Intent.SceneStore(c, confirmed = true)); confirmScene = null; store = false; true } else false }
                                }
                                .pointerInput(c, confirmAt) { detectTapGestures { if (System.currentTimeMillis() - confirmAt > 400) { core.send(Intent.SceneStore(c, confirmed = true)); confirmScene = null; store = false; haptic.performHapticFeedback(HapticFeedbackType.Confirm) } } }
                                .padding(horizontal = 12.dp),
                            contentAlignment = Alignment.CenterStart,
                        ) { BasicText(words, style = LupeType.key.copy(fontSize = 13.sp), maxLines = 1) }
                        Key({ confirmScene = null }, "Cancel", width = 72.dp, height = scenesH, minTarget = scenesH) { fg -> KeyLabel("Cancel", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                    }
                }
                // a refusal shows over the scenes until dismissed
                LupeCrossfade(notice, Modifier.fillMaxSize()) { n ->
                    if (n != null) Row(
                        Modifier.fillMaxSize().background(Tok.held, RoundedCornerShape(8.dp)).padding(start = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        BasicText(n, Modifier.weight(1f), style = LupeType.small.copy(color = Tok.text), maxLines = 2)
                        Key({ notice = null }, "Dismiss", width = 44.dp, height = scenesH, minTarget = scenesH) { fg -> BasicText("✕", style = LupeType.key.copy(color = fg)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun RowHead(r: PadRow, h: Dp, selected: Boolean, core: LupeCore) {
    val color = Tok.track[(r.track - 1) % Tok.track.size]
    val ring = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    Row(Modifier.height(h), horizontalArrangement = Arrangement.spacedBy(GAP)) {
        Box(
            Modifier.width(28.dp).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(color)
                .drawBehind { drawRoundRect(Tok.text.copy(alpha = ring.value), cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(2.dp.toPx() * 2)) }
                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Track ${r.track}, ${r.name}"; stateDescription = if (selected) "Selected" else "" }
                .pointerInput(r.track) { detectTapGestures { core.send(Intent.TrackSelect(r.track)) } },
            contentAlignment = Alignment.Center,
        ) { BasicText("${r.track}", style = LupeType.key.copy(fontSize = 15.sp, color = Tok.onColour)) }
        val on = r.muted
        val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
        Box(
            Modifier.width(28.dp).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(lerp(Tok.control, Tok.primaryTop, lit.value))
                .semantics(mergeDescendants = true) { role = Role.Switch; contentDescription = "Mute ${r.name}"; stateDescription = if (on) "Muted" else "Not muted" }
                .pointerInput(r.track) { detectTapGestures { core.send(Intent.TrackMute(r.track)) } },
            contentAlignment = Alignment.Center,
        ) { BasicText("M", style = LupeType.label.copy(color = lerp(Tok.text2, Tok.onColour, lit.value))) }
    }
}

/** One entry of one track: its faces are the board's (playing, muted, waiting, next, selected, empty, REST). */
@Composable
fun Pad(row: PadRow, idx: Int, e: PadEntry, h: Dp, selected: Boolean, core: LupeCore, selectMode: Boolean, pads: PadsState, modifier: Modifier = Modifier) {
    val color = Tok.track[(row.track - 1) % Tok.track.size]
    val reduce = LocalReduceMotion.current
    val haptic = LocalHapticFeedback.current
    val playing = e.play == PadPlay.Playing
    val fill = animatedFloat(if (playing && !row.muted) 1f else 0f, Dur.STATE)
    val ringMuted = animatedFloat(if (playing && row.muted) 1f else 0f, Dur.STATE)
    val wait = animatedFloat(if (e.play == PadPlay.Waiting) 1f else 0f, Dur.STATE)
    val next = animatedFloat(if (e.play == PadPlay.Next) 1f else 0f, Dur.STATE)
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    var pressed by remember { mutableStateOf(false) }
    val press = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100)
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    val letter = ('A' + idx).toString()
    val empty = e.kind == PadKind.Empty
    val what = when (e.kind) { PadKind.Empty -> "empty"; PadKind.Rest -> "rest"; PadKind.Pattern -> "pattern ${e.pattern}" }
    val stateWord = when (e.play) {
        PadPlay.Playing -> ", playing" + if (row.muted) " but muted" else ""
        PadPlay.Waiting -> ", waiting" + (e.bar?.let { ", bar $it" } ?: "")
        PadPlay.Next -> ", next"
        PadPlay.Idle -> ""
    }
    val desc = "${row.name}, entry $letter, $what$stateWord" + if (selected) ", selected" else ""

    fun tap() { if (selectMode) core.send(Intent.PadSelect(row.track, idx)) else core.send(Intent.PadTap(row.track, idx)) }

    Box(modifier.width(PAD_W).height(h)) {
        Box(
            Modifier.matchParentSize()
                .drawBehind {
                    val r = CornerRadius(8.dp.toPx())
                    drawRoundRect(if (empty) Tok.well else Tok.control, cornerRadius = r)
                    if (fill.value > 0f) drawRoundRect(color.copy(alpha = fill.value), cornerRadius = r)
                    if (ringMuted.value > 0f) drawRoundRect(color.copy(alpha = ringMuted.value), cornerRadius = r, style = Stroke(4.dp.toPx()), topLeft = Offset.Zero)
                    if (ringMuted.value > 0f) drawRoundRect(if (empty) Tok.well else Tok.control, topLeft = Offset(2.dp.toPx(), 2.dp.toPx()), size = Size(size.width - 4.dp.toPx(), size.height - 4.dp.toPx()), cornerRadius = CornerRadius(6.dp.toPx()), alpha = ringMuted.value)
                    if (wait.value > 0f) drawRoundRect(color.copy(alpha = wait.value), topLeft = Offset(1.dp.toPx(), 1.dp.toPx()), size = Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), cornerRadius = CornerRadius(7.dp.toPx()),
                        style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 4.dp.toPx()))))
                    if (next.value > 0f) drawRoundRect(Tok.text2.copy(alpha = next.value), topLeft = Offset(0.75.dp.toPx(), 0.75.dp.toPx()), size = Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), cornerRadius = CornerRadius(7.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                    if (e.hasSound && !empty) drawPath(Path().apply { moveTo(size.width - 10.dp.toPx(), 0f); lineTo(size.width, 0f); lineTo(size.width, 10.dp.toPx()); close() }, Tok.page)
                    if (press.value > 0f) drawRoundRect(Color.Black.copy(alpha = 0.25f * press.value), cornerRadius = r)
                    if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), topLeft = Offset(1.dp.toPx(), 1.dp.toPx()), size = Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), cornerRadius = CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                }
                .semantics(mergeDescendants = true) {
                    role = Role.Button
                    contentDescription = desc
                    onClick { tap(); true }
                    onLongClick("Pad menu") { menuAt = Offset(40f, 20f); true }
                    // every long-press has a non-hold way in (WCAG 2.5.7)
                    customActions = buildList {
                        if (e.kind == PadKind.Pattern) { add(CustomAccessibilityAction("Edit steps") { core.send(Intent.PadSelect(row.track, idx)); true }); add(CustomAccessibilityAction("Select sound") { core.send(Intent.PadSelectSound(row.track, idx)); true }) }
                        if (empty) add(CustomAccessibilityAction("New pattern") { core.send(Intent.PadNew(row.track, idx)); true })
                        if (!empty) add(CustomAccessibilityAction("Clear pad") { core.send(Intent.PadClear(row.track, idx)); true })
                    }
                }
                .pointerInput(row.track, idx, selectMode, empty) {
                    detectTapGestures(
                        onPress = { pressed = true; tryAwaitRelease(); pressed = false },
                        onTap = { tap() },
                        onLongPress = { at -> haptic.performHapticFeedback(HapticFeedbackType.LongPress); menuAt = at },
                    )
                },
        ) {
            val fg = Color.lerp(Tok.text, Tok.onColour, fill.value)
            if (e.kind == PadKind.Rest) {
                BasicText("REST", Modifier.align(Alignment.CenterStart).padding(start = 8.dp), style = LupeType.label.copy(color = fg))
            } else if (e.kind == PadKind.Pattern) {
                Row(Modifier.align(Alignment.CenterStart).padding(start = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    BasicText(letter, style = LupeType.label.copy(color = Color.lerp(Tok.text2Raised, Tok.onColour, fill.value)))
                    BasicText("%02d".format(e.pattern ?: 0), style = LupeType.number.copy(fontSize = 20.sp, color = fg))
                }
            }
            if (h >= 36.dp) {
                val side = when {
                    e.play == PadPlay.Waiting && e.bar != null -> "bar\n${e.bar}"
                    e.play == PadPlay.Next -> "next"
                    e.passes != null && e.passes > 1 -> if (playing && e.pass != null) "${e.pass}/${e.passes}" else "×${e.passes}"
                    else -> null
                }
                if (side != null) BasicText(side, Modifier.align(Alignment.CenterEnd).padding(end = 8.dp), style = LupeType.small.copy(fontSize = 11.sp, lineHeight = 11.sp, color = Color.lerp(Tok.text2Raised, Tok.onColour, fill.value), textAlign = androidx.compose.ui.text.style.TextAlign.End))
            }
            if (e.progress != null && playing && !row.muted) {
                Box(Modifier.align(Alignment.BottomStart).padding(start = 6.dp, bottom = 3.dp).width((PAD_W - 12.dp) * e.progress.coerceIn(0f, 1f)).height(3.dp)
                    .background(Tok.onColour.copy(alpha = 0.55f), RoundedCornerShape(2.dp)))
            }
        }
        PadMenu(row, idx, e, pads, menuAt, { menuAt = null }, core)
    }
}

private fun Color.Companion.lerp(a: Color, b: Color, t: Float) = androidx.compose.ui.graphics.lerp(a, b, t)

private enum class PadMenuMode { Root, Set, ClearConfirm }

/** Where else a pattern is used: "T2 B". Skiff erases a pattern only when no other entry names it (P1, 2026-11-14). */
private fun otherUsers(pads: PadsState, track: Int, idx: Int, pattern: Int): List<String> =
    pads.rows.flatMap { r -> r.entries.mapIndexedNotNull { i, x -> if (x.kind == PadKind.Pattern && x.pattern == pattern && !(r.track == track && i == idx)) "T${r.track} ${'A' + i}" else null } }

/** The pattern numbers the FM-1 holds: from the core, or (an older recording) the ones the pads name. */
private fun keptPatterns(pads: PadsState): List<Int> =
    pads.kept.ifEmpty { pads.rows.flatMap { r -> r.entries.mapNotNull { if (it.kind == PadKind.Pattern) it.pattern else null } }.distinct().sorted() }

/**
 * The pad's hold menu, opened beside the finger: Edit steps, Select sound, New, Set, Clear. Set lists only the
 * kept patterns (Skiff's LIST SET refuses an empty number; "New pattern" is the way to a new one), a list so no
 * tap can be taken for half a double tap. Clear asks only when it would erase a pattern nothing else uses; if
 * another entry names it, the pattern stays and the entry clears at once, as on the iPad.
 */
@Composable
private fun PadMenu(row: PadRow, idx: Int, e: PadEntry, pads: PadsState, at: Offset?, close: () -> Unit, core: LupeCore) {
    var mode by remember { mutableStateOf(PadMenuMode.Root) }
    var armedAt by remember { mutableStateOf(0L) }
    val open = at != null
    // start from the root each time it opens
    if (!open && mode != PadMenuMode.Root) mode = PadMenuMode.Root
    val letter = ('A' + idx).toString()
    val others = if (e.kind == PadKind.Pattern && e.pattern != null) otherUsers(pads, row.track, idx, e.pattern) else emptyList()
    LupeMenu(open, { close() }, width = 240.dp, at = at) {
        LupeCrossfade(mode) { m ->
            Column {
                when (m) {
                    PadMenuMode.Root -> {
                        if (e.kind == PadKind.Pattern) {
                            MenuRow("Edit steps", { core.send(Intent.PadSelect(row.track, idx)); close() })
                            MenuRow("Select sound", { core.send(Intent.PadSelectSound(row.track, idx)); close() })
                        }
                        if (e.kind == PadKind.Empty) MenuRow("New pattern", { core.send(Intent.PadNew(row.track, idx)); close() })
                        MenuRow("Set pattern…", { mode = PadMenuMode.Set })
                        if (e.kind != PadKind.Empty) {
                            val erases = e.kind == PadKind.Pattern && others.isEmpty()
                            MenuRow("Clear", { if (erases) { mode = PadMenuMode.ClearConfirm; armedAt = System.currentTimeMillis() } else { core.send(Intent.PadClear(row.track, idx)); close() } },
                                sub = if (others.isNotEmpty()) "Pattern %02d stays: ${others.first()} uses it".format(e.pattern) else null)
                        }
                    }
                    PadMenuMode.Set -> {
                        val kept = keptPatterns(pads)
                        MenuHeading("Pattern for $letter on ${row.name}")
                        if (kept.isEmpty()) BasicText("No patterns yet. Use New pattern on an empty pad.", Modifier.padding(horizontal = 16.dp, vertical = 8.dp), style = LupeType.body.copy(fontSize = 14.sp))
                        kept.forEach { p -> MenuRow("Pattern %02d".format(p), { core.send(Intent.PadSet(row.track, idx, p)); close() }, checked = e.pattern == p) }
                        MenuRow("Back", { mode = PadMenuMode.Root })
                    }
                    PadMenuMode.ClearConfirm -> {
                        // nothing else names this pattern, so Clear erases it: a button outlined in REC red that says so; it ignores taps for 0.4 s
                        val words = "Clear entry $letter on T${row.track} ${row.name}. Pattern %02d is used nowhere else, so it's erased; can't be undone".format(e.pattern ?: 0)
                        Box(
                            Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp)
                                .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Confirm: $words" }
                                .pointerInput(Unit) { detectTapGestures { if (System.currentTimeMillis() - armedAt > 400) { core.send(Intent.PadClear(row.track, idx)); close() } } }
                                .padding(12.dp),
                        ) { BasicText(words, style = LupeType.key) }
                        MenuRow("Cancel", { mode = PadMenuMode.Root })
                    }
                }
            }
        }
    }
}

/** Bottom full: only the selected track's pads stay up, as a 40 dp strip (board 54). */
@Composable
fun PadsStrip(pads: PadsState, core: LupeCore, modifier: Modifier = Modifier) {
    val row = pads.rows.firstOrNull { it.track == pads.selected.track } ?: return
    val color = Tok.track[(row.track - 1) % Tok.track.size]
    Row(modifier.fillMaxWidth().height(40.dp), horizontalArrangement = Arrangement.spacedBy(GAP)) {
        Box(
            Modifier.width(28.dp).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(color)
                .drawBehind { drawRoundRect(Tok.text, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                .semantics(mergeDescendants = true) { contentDescription = "Track ${row.track}, ${row.name}, selected" },
            contentAlignment = Alignment.Center,
        ) { BasicText("${row.track}", style = LupeType.key.copy(fontSize = 15.sp, color = Tok.onColour)) }
        Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(GAP)) {
            row.entries.forEachIndexed { i, e -> Pad(row, i, e, 40.dp, selected = pads.selected.entry == i, core = core, selectMode = false, pads = pads) }
        }
    }
}

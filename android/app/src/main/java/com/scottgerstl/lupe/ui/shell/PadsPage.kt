package com.scottgerstl.lupe.ui.shell

import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitEachGesture
import kotlin.math.roundToInt
import androidx.compose.ui.unit.IntOffset
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Spacer
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.foundation.layout.size
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PadEntry
import com.scottgerstl.lupe.core.PadKind
import com.scottgerstl.lupe.core.PadPlay
import com.scottgerstl.lupe.core.PadRow
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.ui.sounds.LocalSoundsHost
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.delay

private val PAD_W = 80.dp
private val GAP = 4.dp

/**
 * The Pads tab in landscape (decision 28, board 74): six track rows (a wide head to select the track and reach its sounds, MUTE with the
 * word on it, then the entries panning together, about eight in view), and Store with all sixteen scenes across the foot.
 */
@Composable
fun PadsPage(pads: PadsState, core: LupeCore, modifier: Modifier = Modifier) {
    var store by rememberSaveable { mutableStateOf(false) }
    var notice by remember { mutableStateOf<String?>(null) }
    // Store over a kept scene asks once more, in place (Scott, 2026-11-14): the scene, and when it was asked
    var confirmScene by remember { mutableStateOf<Int?>(null) }
    var confirmAt by remember { mutableStateOf(0L) }
    val scroll = rememberScrollState()
    val haptic = LocalHapticFeedback.current
    val mix by core.mix.collectAsStateWithLifecycle()
    // the clock reference: the pass bars and the waiting outlines move on from it every frame (read inside the draw, so a new reference recomposes nothing)
    val clock = core.clock.collectAsStateWithLifecycle()

    BoxWithConstraints(modifier.fillMaxSize()) {
        val scenesH = 40.dp
        val rows = pads.rows.ifEmpty { return@BoxWithConstraints }
        val rh = ((maxHeight - scenesH - 8.dp - GAP * (rows.size - 1)) / rows.size).coerceAtLeast(24.dp)
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                // The selected track: its colour muted over the page (28 %), under the whole row: head, MUTE and every slot (decision 31, board 76;
                // DESIGN.md "White is global, the track's colour is the track's"). It glides to the newly selected row, sits behind everything
                // and draws nothing a finger can hit. While the tab pages slide, the shell's travelling band stands in for it.
                val at = rows.indexOfFirst { it.track == pads.selected.track }
                if (at >= 0) {
                    val y = animatedFloat(at.toFloat(), Dur.STATE)
                    val travelling = LocalTabTravelling.current
                    val band = trackBand(Tok.track[(pads.selected.track - 1).coerceAtLeast(0) % Tok.track.size])
                    Box(
                        Modifier.fillMaxWidth().height(rh + 4.dp).offset { IntOffset(0, ((rh + GAP).toPx() * y.value - 2.dp.toPx()).roundToInt()) }
                            .selectedTrackAnchor()
                            .drawBehind { if (!travelling) drawRoundRect(band, cornerRadius = CornerRadius(10.dp.toPx())) }
                            .clearAndSetSemantics { },
                    )
                }
                Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(GAP)) {
                        rows.forEach { r ->
                            // the core names a track "Engine · Sound" ("Phase · Pd Organ"): the head shows the sound's name, and the engine under it
                            val full = r.name.takeIf { " · " in it } ?: mix.rows.getOrNull(r.track - 1)?.name.orEmpty()
                            val engine = full.takeIf { " · " in it }?.substringBefore(" · ").orEmpty()
                            RowHead(r, rh, r.track == pads.selected.track, r.name.substringAfter(" · "), engine, mix.rows.getOrNull(r.track - 1)?.solo == true, core, clock)
                        }
                    }
                    MuteColumn(rows, rh, core, clock)
                    BoxWithConstraints(Modifier.weight(1f).fillMaxHeight()) {
                        // slots to the row's end: as many as fit the width (drawn as empty wells past the entries the core lists), the rest by the pan
                        val fit = ((maxWidth + GAP) / (PAD_W + GAP)).toInt() + 1
                        Box(Modifier.fillMaxSize().horizontalScroll(scroll)) {
                            Column(verticalArrangement = Arrangement.spacedBy(GAP)) {
                                rows.forEach { r ->
                                    Row(horizontalArrangement = Arrangement.spacedBy(GAP)) {
                                        r.entries.forEachIndexed { i, e ->
                                            Pad(r, i, e, rh, selected = pads.selected.track == r.track && pads.selected.entry == i, core = core, selectMode = false, pads = pads, clock = clock)
                                        }
                                        // past the core's last (empty) entry, to H (and to the row's end): outlined slots with their letter (decision 33).
                                        val onRow = animatedFloat(if (r.track == pads.selected.track) 1f else 0f, Dur.STATE)
                                        val trackCol = Tok.track[(r.track - 1).coerceAtLeast(0) % Tok.track.size]
                                        // Each of them stands for the row's next free entry (Scott, 2026-11-14: a hold on an outlined G or H did nothing, though
                                        // the outline invites it): a tap selects that entry, a hold opens its menu, and what is made lands in the first free place.
                                        val free = r.entries.indexOfFirst { it.kind == PadKind.Empty }
                                        for (k in r.entries.size until maxOf(fit, 8)) {
                                            if (free >= 0 && k < 16) Pad(r, k, r.entries[free], rh, selected = false, core = core, selectMode = false, pads = pads, target = free, clock = clock)
                                            else EmptySlot(k, rh, { emptyOutline(trackCol, onRow.value) })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // scenes: Store, then all sixteen
            Box(Modifier.fillMaxWidth().height(scenesH)) {
                Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(GAP), verticalAlignment = Alignment.CenterVertically) {
                    // the iPhone's short Store key with a dot (decision 33): the same word either way, lit while armed, so the scenes beside it never move
                    Key({ store = !store }, "Store scene", width = 88.dp, height = scenesH, minTarget = scenesH, on = store,
                        role = Role.Switch, state = if (store) "On: tap a scene to store what plays now" else "Off") { fg ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            val armed = animatedFloat(if (store) 1f else 0f, Dur.STATE)
                            androidx.compose.foundation.Canvas(Modifier.size(6.dp)) { drawCircle(androidx.compose.ui.graphics.lerp(Tok.text3, Tok.rec, armed.value)) }
                            KeyLabel("Store", fg)
                        }
                    }
                    Spacer(Modifier.width(2.dp))
                    pads.scenes.forEachIndexed { i, s ->
                        val kept = animatedFloat(if (s.stored || s.current) 1f else 0f, Dur.STATE); val cur = animatedFloat(if (s.current) 1f else 0f, Dur.STATE)
                        val label = "Scene ${i + 1}" + (if (!s.stored) ", empty" else if (s.current) ", current" else "") + if (s.waiting) ", waiting for the launch point" else ""
                        Box(
                            Modifier.weight(1f).height(scenesH)
                                .clip(RoundedCornerShape(8.dp))
                                // the current scene white, a stored one filled, an empty one only outlined (the fills and the outline blend, nothing pops)
                                .drawBehind {
                                    val r = CornerRadius(8.dp.toPx())
                                    if (kept.value > 0f) drawRoundRect(Tok.control.copy(alpha = kept.value), cornerRadius = r)
                                    if (cur.value > 0f) drawRoundRect(Tok.primaryTop.copy(alpha = cur.value), cornerRadius = r)
                                    if (kept.value < 1f) drawRoundRect(Tok.outline.copy(alpha = 1f - kept.value), Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(7.25.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                                }
                                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = label }
                                .pointerInput(i, store, s.stored) {
                                    detectTapGestures {
                                        when {
                                            store && s.stored -> { confirmScene = i; confirmAt = System.currentTimeMillis(); notice = null }   // a kept scene: ask first
                                            store -> { core.send(Intent.SceneStore(i)); store = false; haptic.performHapticFeedback(HapticFeedbackType.Confirm) }
                                            s.stored -> core.send(Intent.SceneRecall(i))
                                            else -> notice = "Scene ${i + 1} is empty. Tap Store scene, then a scene, to keep what plays now."
                                        }
                                    }
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            BasicText("${i + 1}", style = LupeType.key.copy(color = if (s.current) Tok.onColour else if (s.stored) Tok.text else Tok.text2))
                            // recalled while playing: it waits for the launch point, its outline drawn as that comes (a scene is global: white, or dark on the lit key)
                            if (s.waiting) LaunchTrace({ clock.value.ticksLeft(s.launchTick, android.os.SystemClock.uptimeMillis()) }, if (s.current) Tok.onColour else Tok.text, 8.dp, 2.dp, Modifier.matchParentSize(), base = 0.6f)
                        }
                    }
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
                        ) { BasicText(words, style = LupeType.key, maxLines = 1) }
                        Key({ confirmScene = null }, "Cancel", width = 88.dp, height = scenesH, minTarget = scenesH) { fg -> KeyLabel("Cancel", fg) }
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

private val HEAD_W = 132.dp   // the track head: the "pick a sound without tiny buttons" target (board 74)
private val MUTE_W = 54.dp

/**
 * A track's head, 132 dp wide: its number in the track's colour, the sound's name, the engine under it. A tap selects the track and does
 * nothing else (decision 29: taps select, holds open menus); a hold opens its menu beside the finger: Sounds…, Mute, Solo. The tap is taken on
 * the finger lifting anywhere on the head, with no movement limit, so a rolling finger still selects.
 */
@Composable
private fun RowHead(r: PadRow, h: Dp, selected: Boolean, sound: String, engine: String, solo: Boolean, core: LupeCore, clock: androidx.compose.runtime.State<com.scottgerstl.lupe.core.ClockState>) {
    val color = Tok.track[(r.track - 1) % Tok.track.size]
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    val soundsHost = LocalSoundsHost.current
    val haptic = LocalHapticFeedback.current
    val longPress = androidx.compose.ui.platform.LocalViewConfiguration.current.longPressTimeoutMillis
    var pressed by remember { mutableStateOf(false) }
    val press = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100)
    val holdMenu = LocalHoldMenu.current
    var headCoords by remember { mutableStateOf<androidx.compose.ui.layout.LayoutCoordinates?>(null) }
    // the head's hold menu (the iPad's rows, and LEVEL and PAN now the track controls box is gone: decision 31): its sounds, level, pan, mute, solo
    val mixNow = core.mix.collectAsStateWithLifecycle()
    fun headItems() = listOf(
        HoldItem("Sounds…", sub = engine.ifEmpty { null }) { soundsHost.open(r.track) },
        HoldItem("LEVEL", slide = HoldSlide({ mixNow.value.rows.getOrNull(r.track - 1)?.level ?: 0 }, { mixNow.value.rows.getOrNull(r.track - 1)?.levelText.orEmpty() }, 0, 127) { core.send(com.scottgerstl.lupe.core.SetLevel(r.track, it)) }),
        HoldItem("PAN", slide = HoldSlide({ mixNow.value.rows.getOrNull(r.track - 1)?.pan ?: 0 }, { mixNow.value.rows.getOrNull(r.track - 1)?.panText.orEmpty() }, -64, 63, bipolarAt = 0) { core.send(com.scottgerstl.lupe.core.SetPan(r.track, it)) }),
        HoldItem("Mute", checked = r.muted) { core.send(Intent.TrackMute(r.track)) },
        HoldItem("Solo", sub = "Plays this track alone", checked = solo) { core.send(com.scottgerstl.lupe.core.TrackSolo(r.track)) },
    )
    Box(Modifier.width(HEAD_W).height(h).onGloballyPositioned { headCoords = it }) {
        Row(
            Modifier.fillMaxSize().clip(RoundedCornerShape(8.dp))
                .drawBehind {
                    drawRect(lerp(Tok.control, lerp(Tok.page, color, 0.30f), sel.value))
                    if (press.value > 0f) drawRect(Color.Black.copy(alpha = 0.25f * press.value))
                }
                .semantics(mergeDescendants = true) {
                    role = Role.Button; contentDescription = "Track ${r.track}, $sound" + (if (engine.isNotEmpty()) ", $engine" else "") + (if (solo) ", solo" else ""); stateDescription = if (selected) "Selected" else ""
                    onClick("Select track") { core.send(Intent.TrackSelect(r.track)); true }
                    onLongClick("Track menu") { headCoords?.takeIf { it.isAttached }?.let { c -> holdMenu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), color, headItems()) }; true }
                    // every hold has a non-hold way in (WCAG 2.5.7)
                    customActions = listOf(
                        CustomAccessibilityAction("Choose a sound for this track") { soundsHost.open(r.track); true },
                        CustomAccessibilityAction(if (solo) "Solo off" else "Solo") { core.send(com.scottgerstl.lupe.core.TrackSolo(r.track)); true },
                    )
                }
                .tapOrHoldMenu(r.track, color, { headItems() }, onTap = { core.send(Intent.TrackSelect(r.track)) }, pressed = { pressed = it }),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.width(30.dp).fillMaxHeight().background(color), contentAlignment = Alignment.Center) { BasicText("${r.track}", style = LupeType.key.copy(fontSize = 15.sp, color = Tok.onColour)) }
            Column(Modifier.padding(start = 8.dp, end = 4.dp), verticalArrangement = Arrangement.Center) {
                BasicText(sound, style = LupeType.key.copy(fontSize = 15.sp, lineHeight = 17.sp), maxLines = 1, softWrap = false,
                    autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 15.sp, stepSize = 1.sp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (engine.isNotEmpty()) BasicText(engine, style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 14.sp), maxLines = 1)
                    // solo: a lit pill with the word (never the colour alone)
                    if (solo) BasicText("SOLO", Modifier.background(Tok.primaryTop, RoundedCornerShape(4.dp)).padding(horizontal = 4.dp, vertical = 1.dp), style = LupeType.label.copy(fontSize = 10.sp, lineHeight = 11.sp, color = Tok.onColour))
                }
            }
        }
        // a solo that waits for the launch point: the head's outline drawn as it comes, in the track's colour
        if (r.soloPending) LaunchTrace({ clock.value.ticksLeft(r.launchTick, android.os.SystemClock.uptimeMillis()) }, color, 8.dp, 2.dp, Modifier.matchParentSize(), base = 0.6f)
    }
}

/**
 * The MUTE keys, one a row, 54 dp wide with the word on them, white when muted. A tap toggles one. Press one and drag up or down the column
 * and every key the finger crosses takes the state the first one changed to (paint mutes, decision 29), each sent as it is crossed with a tick.
 */
@Composable
private fun MuteColumn(rows: List<PadRow>, rh: Dp, core: LupeCore, clock: androidx.compose.runtime.State<com.scottgerstl.lupe.core.ClockState>) {
    val haptic = LocalHapticFeedback.current
    val now by rememberUpdatedState(rows)
    Column(
        Modifier.width(MUTE_W).pointerInput(rows.size) {
            awaitEachGesture {
                val down = awaitFirstDown()
                val pitch = (rh + GAP).toPx()
                fun rowAt(y: Float) = (y / pitch).toInt().coerceIn(0, now.size - 1)
                val first = now.getOrNull(rowAt(down.position.y)) ?: return@awaitEachGesture
                val target = !first.muted
                val painted = mutableSetOf(first.track)
                core.send(Intent.TrackMute(first.track)); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
                drag(down.id) { c ->
                    c.consume()
                    val r = now.getOrNull(rowAt(c.position.y)) ?: return@drag
                    if (painted.add(r.track) && r.muted != target) { core.send(Intent.TrackMute(r.track)); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                }
            }
        },
        verticalArrangement = Arrangement.spacedBy(GAP),
    ) {
        rows.forEach { r ->
            val lit = animatedFloat(if (r.muted) 1f else 0f, Dur.STATE)
            val sound = r.name.substringAfter(" · ")
            Box(
                Modifier.fillMaxWidth().height(rh).clip(RoundedCornerShape(8.dp)).background(lerp(Tok.control, Tok.primaryTop, lit.value))
                    .semantics(mergeDescendants = true) { role = Role.Switch; contentDescription = "Mute $sound"; stateDescription = (if (r.muted) "Muted" else "Not muted") + if (r.mutePending != "none") ", changing at the launch point" else ""; onClick { core.send(Intent.TrackMute(r.track)); true } },
                contentAlignment = Alignment.Center,
            ) {
                BasicText("MUTE", style = LupeType.key.copy(fontSize = 13.sp, color = lerp(Tok.text2Raised, Tok.onColour, lit.value)))
                // a mute that waits for the launch point: the key's outline drawn as it comes, in the track's colour (dark on the lit, white key)
                if (r.mutePending != "none") LaunchTrace({ clock.value.ticksLeft(r.launchTick, android.os.SystemClock.uptimeMillis()) },
                    if (r.muted) Tok.onColour else Tok.track[(r.track - 1) % Tok.track.size], 8.dp, 2.dp, Modifier.matchParentSize(), base = 0.6f)
            }
        }
    }
}

/** Whether the song is stopped, for the choices the FM-1 takes only then: the transport and the timeline area's say, never a pad's own play state. */
fun padMenuIdle(transportPlaying: Boolean, timelinePlaying: Boolean): Boolean = !transportPlaying && !timelinePlaying

/** One entry of one track: its faces are the board's (playing, muted, waiting, next, selected, empty, REST). */
@Composable
fun Pad(row: PadRow, idx: Int, e: PadEntry, h: Dp, selected: Boolean, core: LupeCore, selectMode: Boolean, pads: PadsState, modifier: Modifier = Modifier, target: Int = idx, clock: androidx.compose.runtime.State<com.scottgerstl.lupe.core.ClockState> = remember { mutableStateOf(com.scottgerstl.lupe.core.ClockState()) }) {
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
    val onRow = animatedFloat(if (pads.selected.track == row.track) 1f else 0f, Dur.STATE)
    val letter = ('A' + idx).toString()
    // The entry its touches act on. An outlined slot past the row's one free entry stands for that entry (Skiff's list has no gaps, so
    // whatever is made there lands in the first free place): [target] is that entry, and the menu says where it goes.
    val at = target
    val goes = if (at != idx) "Goes in ${'A' + at}" else null
    val empty = e.kind == PadKind.Empty
    val holdMenu = LocalHoldMenu.current
    val sheetHost = com.scottgerstl.lupe.ui.sheet.LocalSheetHost.current
    val pool by core.patterns.collectAsStateWithLifecycle()
    val soundsHost = LocalSoundsHost.current
    var padCoords by remember { mutableStateOf<androidx.compose.ui.layout.LayoutCoordinates?>(null) }
    val dragState = LocalPadDrag.current
    val labs = com.scottgerstl.lupe.ui.slide.LocalPhoneSettings.current
    val dens = androidx.compose.ui.platform.LocalDensity.current.density
    // this slot, for a drop to find (window pixels; kept as it is placed, forgotten when it goes)
    androidx.compose.runtime.DisposableEffect(row.track, idx) { onDispose { dragState?.slots?.remove(row.track to idx) } }
    /**
     * The pad's hold menu (the iPad's rows, decision 31: the full set the core can do): Edit steps, Select sound, Set pattern, Play once more /
     * less, Duplicate after, Move earlier / later, Clear; an empty slot: New pattern, Rest, Pick a pattern. Not here because the core has no
     * way to ask for them yet: Make unique, Copy to another track, Move to a named pad, the Patterns pool. Set lists only the kept patterns (Skiff's LIST SET
     * refuses an empty number; "New pattern" is the way to a new one). Clear asks in place only when it would erase a pattern nothing else uses;
     * if another entry names it, the pattern stays and the entry clears at once, as on the iPad.
     */
    fun padItems(): List<HoldItem> = buildList {
        val others = if (e.kind == PadKind.Pattern && e.pattern != null) otherUsers(pads, row.track, at, e.pattern) else emptyList()
        // the song's blocks (the Timeline's): this pad's block, for the choices that change the track's list. They need the song stopped.
        val tl = core.timeline.value
        val blocks = tl.tracks.firstOrNull { it.track == row.track }?.blocks.orEmpty().filter { it.kind != "gap" }
        val block = blocks.firstOrNull { idx in it.first..it.last }
        // the transport's word, never this pad's own: each track's current entry reads "playing" even when stopped (Scott, Pixel, 2026-11-15)
        val idle = padMenuIdle(core.top.value.playing, tl.playing)
        val stopFirst = if (idle) null else "Stop first"
        if (e.kind == PadKind.Pattern) {
            add(HoldItem("Edit steps") { core.send(Intent.PadSelect(row.track, at)); core.send(Intent.SetTab(com.scottgerstl.lupe.core.Tab.Edit)) })
            // the Sounds sheet, for this pad's own sound on any track (as on the iPad: an entry can carry its own sound)
            add(HoldItem("Select sound", sub = row.name.substringAfter(" · ")) { core.send(Intent.PadSelectSound(row.track, at)); soundsHost.open(row.track, letter) })
        }
        val kept0 = keptPatterns(pads)
        val fullPool = empty && (pads.patternsFree == 0 || kept0.size >= 64)
        // a pad cleared a moment ago: the way back, here as well as in the Undo strip
        val undo = pads.clearUndo.lastOrNull { !it.block && it.track == row.track && it.entry == at }
        if (undo != null) add(HoldItem("Undo clear", sub = undo.pattern?.let { "Pattern %02d comes back".format(it) } ?: "The REST comes back") { core.send(com.scottgerstl.lupe.core.UndoClear(row.track, at)) })
        if (empty) {
            // no pattern number free: the FM-1 would refuse it, so the menu says so before the tap, and offers the ways on (board 79.4)
            val full = fullPool
            add(HoldItem("New pattern", sub = if (full) com.scottgerstl.lupe.core.NO_PATTERN_FREE else goes, enabled = !full) { core.send(Intent.PadNew(row.track, at)) })
            if (full) {
                // a fresh pattern without a free number: the lowest unused one onto this pad, then emptied (stopped only); it names the number
                val recycle = pool.recycle ?: pads.unused.minOrNull()
                add(HoldItem("Recycle an unused pattern", sub = if (recycle == null) "None unused: saved projects hold them" else stopFirst ?: "Takes ${"%02d".format(recycle)}", enabled = idle && recycle != null) {
                    core.send(com.scottgerstl.lupe.core.RecyclePattern(row.track, at)) })
                // the sheet in pick mode: the pad then plays the same pattern as its other users
                add(HoldItem("Put a kept pattern here…", sub = "Edits are shared") { sheetHost.showPatterns(row.track to at) })
            }
            // (a REST added at the list's end is one LIST SET, which Skiff takes while playing; if it can't, its refusal shows on screen)
            add(HoldItem("Rest", sub = goes) { core.send(com.scottgerstl.lupe.core.BlockInsert(row.track, at, 65)) })
        }
        val kept = keptPatterns(pads)
        // (with the pool full, "Put a kept pattern here…" above is the way to a kept one)
        if (!fullPool)         add(HoldItem(if (empty) "Pick a pattern…" else "Set pattern…", sub = if (kept.isEmpty()) "No patterns yet" else if (empty) goes else null, enabled = kept.isNotEmpty(),
            children = { kept.map { p -> HoldItem("Pattern %02d".format(p), checked = e.pattern == p) { core.send(Intent.PadSet(row.track, at, p)) } } }))
        if (empty) add(HoldItem("Patterns…", sub = if (pool.kept > 0) "${pool.kept} kept · ${pool.unused} unused" else null) { sheetHost.showPatterns() })
        if (!empty && block != null) {
            // how many passes it plays (the iPad's Play once more / less); a chain repeats whole, on its last entry's count
            val chained = block.last > block.first
            add(HoldItem("Play once more", sub = stopFirst ?: (if (chained) "The chain: " else "") + "×${block.reps} to ×${minOf(16, block.reps + 1)}", enabled = idle && block.reps < 16) { core.send(com.scottgerstl.lupe.core.BlockStretch(row.track, block.id, block.reps + 1)) })
            add(HoldItem("Play once less", sub = stopFirst ?: (if (chained) "The chain: " else "") + "×${block.reps} to ×${maxOf(1, block.reps - 1)}", enabled = idle && block.reps > 1) { core.send(com.scottgerstl.lupe.core.BlockStretch(row.track, block.id, block.reps - 1)) })
            val full = (tl.tracks.firstOrNull { it.track == row.track }?.entriesUsed ?: 0) >= 16
            add(HoldItem("Duplicate after", sub = stopFirst ?: if (full) "The track's 16 entries are full" else null, enabled = idle && !full) { core.send(com.scottgerstl.lupe.core.BlockDuplicate(row.track, block.id)) })
            val at = blocks.indexOfFirst { it.id == block.id }
            add(HoldItem("Move earlier", sub = stopFirst, enabled = idle && at > 0) { core.send(com.scottgerstl.lupe.core.BlockMove(row.track, block.id, -1)) })
            add(HoldItem("Move later", sub = stopFirst, enabled = idle && at in 0 until blocks.size - 1) { core.send(com.scottgerstl.lupe.core.BlockMove(row.track, block.id, 1)) })
        }
        if (!empty) {
            val erases = e.kind == PadKind.Pattern && others.isEmpty()
            // no confirm (batch item 13): it clears at once and an Undo strip, and "Undo clear" in this pad's menu, put it back for ten seconds
            add(HoldItem("Clear", sub = if (others.isNotEmpty()) "Pattern %02d stays: ${others.first()} uses it".format(e.pattern) else null) { core.send(Intent.PadClear(row.track, at)) })
        }
    }
    val what = when (e.kind) { PadKind.Empty -> "empty"; PadKind.Rest -> "rest"; PadKind.Pattern -> "pattern ${e.pattern}" }
    val stateWord = when (e.play) {
        PadPlay.Playing -> ", playing" + if (row.muted) " but muted" else ""
        PadPlay.Waiting -> ", waiting" + (e.bar?.let { ", bar $it" } ?: "")
        PadPlay.Next -> ", next"
        PadPlay.Idle -> ""
    }
    val desc = "${row.name}, entry $letter, $what$stateWord" + (if (goes != null) ". ${goes.replaceFirst("Goes in", "What you add here goes in")}, the next free entry" else "") + if (selected) ", selected" else ""

    // a tap selects the pad and its track (the editor follows) and still launches it (decision 29)
    // …an empty slot is only selected: the FM-1 refuses to play one, and selecting it is the way in that isn't a hold
    // …and a second tap on the pad that is already selected opens its menu, but only while stopped (batch item 10): while the song plays a tap
    // keeps queuing launches, and the hold opens the menu
    fun tap() {
        val already = pads.selected.track == row.track && pads.selected.entry == at
        if (secondTapOpensMenu(already, core.top.value.playing, selectMode)) {
            padCoords?.takeIf { it.isAttached }?.let { c -> holdMenu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), color, padItems()) }
            return
        }
        core.send(Intent.PadSelect(row.track, at)); if (!selectMode && !empty) core.send(Intent.PadTap(row.track, at))
    }

    // dragging (the iPhone's rule): press then slide lifts the pad with no menu; a still hold opens the menu and moving off it lifts; the drop goes to a well, a slot or back
    val dragger = if (empty || dragState == null) null else object : PadDragger {
        override fun lift(finger: Offset, grabLocal: Offset) {
            val sz = padCoords?.size ?: return
            dragState.drag = PadDrag(row.track, at, e.kind == PadKind.Rest, e.pattern, color, Size(sz.width.toFloat(), sz.height.toFloat()), grabLocal, finger, letter)
        }
        override fun move(finger: Offset) { dragState.drag = dragState.drag?.copy(finger = finger) }
        override fun cancel() { dragState.drag = null }
        override fun drop(finger: Offset) {
            val d = dragState.drag?.copy(finger = finger); dragState.drag = null
            if (d == null) return
            val feel = WellFeel(labs.wellGlowDp * dens, labs.wellHotDp * dens)
            // (the finger and the slots are both in window pixels; the wells are in the layer's own)
            val act = decideDrop(d.copy(finger = finger - dragState.origin), dragState.slots.values.map { it.copy(rect = it.rect.translate(-dragState.origin)) }, dragState.screen.width, dragState.screen.height, dens, feel) ?: return
            when (act) {
                is DropAction.Move -> core.send(com.scottgerstl.lupe.core.PadMove(act.track, act.from, act.track, act.to))
                is DropAction.Offer -> holdMenu?.open(finger, color, listOf(
                    HoldItem("Same pattern", sub = "Edits are shared") { core.send(Intent.PadSet(act.toTrack, act.to, act.pattern)) },
                    HoldItem("A copy", sub = "Takes a free number") { core.send(com.scottgerstl.lupe.core.CopyPattern(act.pattern, act.toTrack, act.to)) },
                ))
                is DropAction.Well -> when (act.action) {
                    // no confirm (batch item 13): it clears at once and the Undo strip puts it back
                    EdgeAction.Clear -> core.send(Intent.PadClear(row.track, at))
                    EdgeAction.Edit -> { core.send(Intent.PadSelect(row.track, at)); core.send(Intent.SetTab(com.scottgerstl.lupe.core.Tab.Edit)) }
                    EdgeAction.Duplicate -> {
                        // into the track's next empty slot; with none, or no free number, the core says so in its refusal
                        val free = row.entries.indexOfFirst { it.kind == PadKind.Empty }
                        val blk = core.timeline.value.tracks.firstOrNull { it.track == row.track }?.blocks.orEmpty().firstOrNull { it.kind != "gap" && at in it.first..it.last }
                        when {
                            free < 0 || free >= 16 -> blk?.let { core.send(com.scottgerstl.lupe.core.BlockDuplicate(row.track, it.id)) }
                            e.kind == PadKind.Rest -> core.send(com.scottgerstl.lupe.core.BlockInsert(row.track, free, 65))
                            e.pattern != null -> core.send(com.scottgerstl.lupe.core.CopyPattern(e.pattern, row.track, free))
                        }
                    }
                }
            }
        }
    }
    val lifted = dragState?.drag?.let { it.track == row.track && it.from == at } == true
    Box(modifier.width(PAD_W).height(h).graphicsLayer { alpha = if (lifted) 0.35f else 1f }.onGloballyPositioned {
        padCoords = it
        dragState?.slots?.set(row.track to idx, DropSlot(row.track, idx, at, empty, it.boundsInWindow()))
    }) {
        Box(
            Modifier.matchParentSize()
                .drawBehind {
                    val r = CornerRadius(8.dp.toPx())
                    // an empty slot is an outline with its letter (decision 33); a filled one a key
                    if (empty) drawRoundRect(emptyOutline(color, onRow.value), Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(7.25.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                    else drawRoundRect(Tok.control, cornerRadius = r)
                    if (fill.value > 0f) drawRoundRect(color.copy(alpha = fill.value), cornerRadius = r)
                    if (ringMuted.value > 0f) drawRoundRect(color.copy(alpha = ringMuted.value), cornerRadius = r, style = Stroke(4.dp.toPx()), topLeft = Offset.Zero)
                    if (ringMuted.value > 0f && !empty) drawRoundRect(Tok.control, topLeft = Offset(2.dp.toPx(), 2.dp.toPx()), size = Size(size.width - 4.dp.toPx(), size.height - 4.dp.toPx()), cornerRadius = CornerRadius(6.dp.toPx()), alpha = ringMuted.value)
                    // (a waiting pad's outline is the LaunchTrace drawn over the pad, below)
                    if (next.value > 0f) drawRoundRect(Tok.text2.copy(alpha = next.value), topLeft = Offset(0.75.dp.toPx(), 0.75.dp.toPx()), size = Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), cornerRadius = CornerRadius(7.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                    if (e.hasSound && !empty) drawPath(Path().apply { moveTo(size.width - 10.dp.toPx(), 0f); lineTo(size.width, 0f); lineTo(size.width, 10.dp.toPx()); close() }, Tok.page)
                    if (press.value > 0f) drawRoundRect(Color.Black.copy(alpha = 0.25f * press.value), cornerRadius = r)
                    // the selected pad: a ring in the track's colour (never white), with a dark gap inside it so it reads on a filled, playing pad
                    // …but not while it waits: a tap selects the pad it launches, and the ring (the same colour, the same place) hid the waiting outline
                    // drawn over it (Scott, 2026-11-14: "the outline timer still doesn't show"). The outline says both until it lands.
                    val ringA = sel.value * (1f - wait.value)
                    if (ringA > 0f) {
                        drawRoundRect(color.copy(alpha = ringA), topLeft = Offset(1.dp.toPx(), 1.dp.toPx()), size = Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), cornerRadius = CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                        drawRoundRect(Tok.page.copy(alpha = ringA), topLeft = Offset(2.75.dp.toPx(), 2.75.dp.toPx()), size = Size(size.width - 5.5.dp.toPx(), size.height - 5.5.dp.toPx()), cornerRadius = CornerRadius(5.25.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                    }
                }
                .semantics(mergeDescendants = true) {
                    role = Role.Button
                    contentDescription = desc
                    onClick { tap(); true }
                    onLongClick("Pad menu") { padCoords?.takeIf { it.isAttached }?.let { c -> holdMenu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), color, padItems()) }; true }
                    // every long-press has a non-hold way in (WCAG 2.5.7)
                    customActions = buildList {
                        if (e.kind == PadKind.Pattern) { add(CustomAccessibilityAction("Edit steps") { core.send(Intent.PadSelect(row.track, at)); core.send(Intent.SetTab(com.scottgerstl.lupe.core.Tab.Edit)); true }); add(CustomAccessibilityAction("Select sound") { core.send(Intent.PadSelectSound(row.track, at)); true }) }
                        if (empty && pads.patternsFree != 0) add(CustomAccessibilityAction("New pattern") { core.send(Intent.PadNew(row.track, at)); true })
                        if (!empty) add(CustomAccessibilityAction("Clear pad") { core.send(Intent.PadClear(row.track, at)); true })
                    }
                }
                .tapOrHoldMenu(Triple(row.track, at, e.kind), color, { padItems() }, onTap = { tap() }, pressed = { pressed = it }, dragger = dragger),
        ) {
            val fg = Color.lerp(Tok.text, Tok.onColour, fill.value)
            if (empty) {
                BasicText(letter, Modifier.align(Alignment.CenterStart).padding(start = 8.dp), style = LupeType.label.copy(color = Tok.text2Raised))
            } else if (e.kind == PadKind.Rest) {
                BasicText("REST", Modifier.align(Alignment.CenterStart).padding(start = 8.dp), style = LupeType.label.copy(color = fg))
            } else if (e.kind == PadKind.Pattern) {
                Row(Modifier.align(Alignment.CenterStart).padding(start = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    BasicText(letter, style = LupeType.label.copy(color = Color.lerp(Tok.text2Raised, Tok.onColour, fill.value)))
                    BasicText("%02d".format(e.pattern ?: 0), style = LupeType.number.copy(fontSize = 20.sp, color = fg))
                }
            }
            if (h >= 36.dp) {
                val side = when {
                    e.play == PadPlay.Next -> "next"
                    e.passes != null && e.passes > 1 -> if (playing && e.pass != null) "${e.pass}/${e.passes}" else "×${e.passes}"
                    else -> null
                }
                if (side != null) BasicText(side, Modifier.align(Alignment.CenterEnd).padding(end = 8.dp), style = LupeType.small.copy(fontSize = 11.sp, lineHeight = 11.sp, color = Color.lerp(Tok.text2Raised, Tok.onColour, fill.value), textAlign = androidx.compose.ui.text.style.TextAlign.End))
            }
            // the pass bar along the foot: it moves every frame, on from the core's last word by the clock's rate (never stepping on each publish)
            if ((e.progress != null || row.passTicks != null) && playing && !row.muted) PassBar({ clock.value.passProgress(row.passStartTick, row.passTicks, android.os.SystemClock.uptimeMillis()) ?: e.progress }, Modifier.align(Alignment.BottomStart).padding(start = 6.dp, bottom = 3.dp).width(PAD_W - 12.dp).height(3.dp))
            // waiting for the launch point: the outline drawn as that comes, in the track's colour; dashed when there is no clock
            if (wait.value > 0f) LaunchTrace({ clock.value.ticksLeft(e.launchTick ?: row.launchTick, android.os.SystemClock.uptimeMillis()) }, color, 8.dp, 2.dp, Modifier.matchParentSize().graphicsLayer { alpha = wait.value })
        }
    }
}

private fun Color.Companion.lerp(a: Color, b: Color, t: Float) = androidx.compose.ui.graphics.lerp(a, b, t)

/** A tap on the pad that is already selected opens its menu: only while stopped, and not in a select mode. While playing a tap keeps queuing a launch. */
internal fun secondTapOpensMenu(alreadySelected: Boolean, transportPlaying: Boolean, selectMode: Boolean) = alreadySelected && !transportPlaying && !selectMode

/** Where else a pattern is used: "T2 B". Skiff erases a pattern only when no other entry names it (P1, 2026-11-14). */
private fun otherUsers(pads: PadsState, track: Int, idx: Int, pattern: Int): List<String> =
    pads.rows.flatMap { r -> r.entries.mapIndexedNotNull { i, x -> if (x.kind == PadKind.Pattern && x.pattern == pattern && !(r.track == track && i == idx)) "T${r.track} ${'A' + i}" else null } }

/** The pattern numbers the FM-1 holds: from the core, or (an older recording) the ones the pads name. */
private fun keptPatterns(pads: PadsState): List<Int> =
    pads.kept.ifEmpty { pads.rows.flatMap { r -> r.entries.mapNotNull { if (it.kind == PadKind.Pattern) it.pattern else null } }.distinct().sorted() }

/**
 * An empty slot's outline: the rest-outline grey on the page; on the selected track's band (where that grey would vanish) the track's own
 * colour, which keeps 3:1 against every band (PadsLookTest).
 */
internal fun emptyOutline(track: Color, onBand: Float): Color = androidx.compose.ui.graphics.lerp(Tok.outline, track, onBand)

/** A slot with no free entry behind it (the row's 16 are full, or past P): the outline and its letter, nothing to touch. */
@Composable
private fun EmptySlot(idx: Int, h: Dp, outline: () -> Color) {
    Box(Modifier.width(PAD_W).height(h).drawBehind {
        drawRoundRect(outline(), Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(7.25.dp.toPx()), style = Stroke(1.5.dp.toPx()))
    }.clearAndSetSemantics { }) {
        if (idx < 8) BasicText(('A' + idx).toString(), Modifier.align(Alignment.CenterStart).padding(start = 8.dp), style = LupeType.label.copy(color = Tok.text2Raised))
    }
}

/** The playing pad's pass bar: [progress] is read every frame, so it glides. */
@Composable
private fun PassBar(progress: () -> Float?, modifier: Modifier) {
    val read by rememberUpdatedState(progress)
    var frame by remember { androidx.compose.runtime.mutableLongStateOf(0L) }
    androidx.compose.runtime.LaunchedEffect(Unit) { while (true) androidx.compose.runtime.withFrameNanos { frame = it } }
    androidx.compose.foundation.Canvas(modifier.clearAndSetSemantics { }) {
        frame
        drawRoundRect(Tok.onColour.copy(alpha = 0.55f), size = Size(size.width * (read() ?: 0f).coerceIn(0f, 1f), size.height), cornerRadius = CornerRadius(size.height / 2))
    }
}

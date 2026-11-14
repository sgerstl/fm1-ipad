package com.scottgerstl.lupe.ui.shell

import com.scottgerstl.lupe.core.SetStepNotes
import com.scottgerstl.lupe.core.ToggleStepNote
import com.scottgerstl.lupe.core.PlayNote
import com.scottgerstl.lupe.core.ToggleHit
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.systemGestureExclusion
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.foundation.gestures.horizontalDrag
import androidx.compose.foundation.gestures.awaitHorizontalTouchSlopOrCancellation
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlin.math.roundToInt
import com.scottgerstl.lupe.ui.slide.slideToTurn
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.runtime.rememberUpdatedState
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
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.EditorKind
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LockMode
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.Step
import com.scottgerstl.lupe.core.StepActionKind
import com.scottgerstl.lupe.core.StepField
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.withTimeoutOrNull

private enum class PanelTab(val label: String) { Notes("NOTES"), Feel("FEEL"), Sound("SOUND") }

/**
 * Which step the person has picked, or none (decision 21): with none, no step shows a ring and the dials area is HOME's
 * four sound knobs; a tap picks a step and the dials become its controls. Kept above the tabs so it survives a visit to Pads. OPEN, left to Scott: it stays picked when the pattern changes.
 */
class StepPick { var step by mutableStateOf<Int?>(null) }

/** What the Edit tab keeps while you visit the other tabs: the Lane view in the keyboard's place, and the keyboard's octave. */
class EditUi {
    var lane by mutableStateOf(false)
    var octave by mutableStateOf(4)
}

private val PANEL_H = 110.dp      // the step panel: a 32 dp header row, 4, the dials (74)
private val KIT_PANEL_H = 76.dp   // a kit's: one row (the picked hit's boxes, or the dials alone), so the lanes keep their height
private val LEFT_W = 420.dp       // the dials area; the keyboard, lane or tiles take the rest

/**
 * The Edit tab (decision 28, board 73): the ruler, the pattern's sixteen steps across in fours (a kit: lanes by steps), and under them
 * the step panel: the dials area on the left (HOME's four sound knobs with no step picked, the picked step's controls, or the FM-1's
 * sound page), and on the right the keyboard strip that writes the picked step (or the one-lane view, or a sound page's tiles).
 * [sound] is the sound page the FM-1 shows, or null; [soundCore] is the core to send its values to (a held page drops them).
 */
@Composable
fun EditTab(
    ed: EditorState, core: LupeCore, auto: com.scottgerstl.lupe.core.AutomationState, pick: StepPick, ui: EditUi, modifier: Modifier = Modifier,
    sound: com.scottgerstl.lupe.core.PageState? = null, soundCore: LupeCore = core, notice: String? = null,
) {
    var tab by rememberSaveable { mutableStateOf(PanelTab.Notes) }
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    if (ed.steps.isEmpty()) { Placeholder("No pattern", "Pick a pad on the Pads tab: hold it, then Edit steps", modifier); return }
    val drum = ed.kind == EditorKind.Drum
    // a kit's picked hit: the lane and the step (the step is also the core's selected step, so its values follow)
    var hit by remember(ed.track, ed.pattern) { mutableStateOf<Pair<String, Int>?>(null) }
    Column(modifier.fillMaxSize()) {
        Ruler(ed, track, core, if (drum) hit != null else pick.step != null)
        Spacer(Modifier.height(4.dp))
        Box(Modifier.weight(1f).fillMaxWidth().selectedTrackAnchor()) {
            if (drum) DrumGrid(ed, track, core, hit) { hit = it } else StepRow(ed, track, core, pick.step) { pick.step = it }
        }
        Spacer(Modifier.height(6.dp))
        Box(Modifier.fillMaxWidth().height(1.dp).background(Tok.control))
        Spacer(Modifier.height(6.dp))
        val mode = when { sound != null -> PanelMode.Sound; (if (drum) hit != null else pick.step != null) -> PanelMode.Step; else -> PanelMode.Home }
        var lastSound by remember { mutableStateOf(sound) }
        if (sound != null) lastSound = sound
        if (drum) Row(Modifier.fillMaxWidth().height(KIT_PANEL_H)) {
            LupeCrossfade(mode, Modifier.fillMaxSize(), Dur.PANEL) { m ->
                when (m) {
                    PanelMode.Sound -> Row(Modifier.fillMaxSize()) {
                        lastSound?.let { p ->
                            com.scottgerstl.lupe.ui.page.SoundDials(p, soundCore, Modifier.width(LEFT_W + 140.dp).fillMaxHeight(), notice, inline = true)
                            Spacer(Modifier.width(16.dp))
                            p.tiles?.let { t -> com.scottgerstl.lupe.ui.page.PageTilesContent(t, track, { soundCore.send(com.scottgerstl.lupe.core.PickRoute(it)) }, { soundCore.send(com.scottgerstl.lupe.core.PickTile(it)) }, Modifier.weight(1f).fillMaxHeight()) }
                        }
                    }
                    PanelMode.Step -> HitPanel(ed, track, core, hit) { hit = null }
                    PanelMode.Home -> Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                        HomeKnobsStrip(ed, core, Modifier.width(LEFT_W), header = false)
                        Spacer(Modifier.width(16.dp))
                        BasicText("Tap a cell to put a hit on or take it off. Hold a cell to pick it: its values show here.", Modifier.weight(1f), style = LupeType.small.copy(color = Tok.text2Raised))
                    }
                }
            }
        } else Row(Modifier.fillMaxWidth().height(PANEL_H)) {
            Box(Modifier.width(LEFT_W).fillMaxHeight()) {
                LupeCrossfade(mode, Modifier.fillMaxSize(), Dur.PANEL) { m ->
                    when (m) {
                        PanelMode.Sound -> lastSound?.let { com.scottgerstl.lupe.ui.page.SoundDials(it, soundCore, Modifier.fillMaxSize(), notice) }
                        PanelMode.Step -> StepControls(ed, track, core, tab, { tab = it }, pick)
                        PanelMode.Home -> HomeKnobsStrip(ed, core, Modifier.fillMaxSize())
                    }
                }
            }
            Spacer(Modifier.width(16.dp))
            // the right: a sound page's tiles need the room; else the one-lane view when Lane is on; else the keyboard
            val right = when { sound?.tiles != null -> RightMode.Tiles; ui.lane -> RightMode.Lane; else -> RightMode.Keys }
            Box(Modifier.weight(1f).fillMaxHeight()) {
                LupeCrossfade(right, Modifier.fillMaxSize(), Dur.PANEL) { r ->
                    when (r) {
                        RightMode.Tiles -> lastSound?.tiles?.let { t -> com.scottgerstl.lupe.ui.page.PageTilesContent(t, track, { soundCore.send(com.scottgerstl.lupe.core.PickRoute(it)) }, { soundCore.send(com.scottgerstl.lupe.core.PickTile(it)) }, Modifier.fillMaxSize()) }
                        RightMode.Lane -> Column(Modifier.fillMaxSize()) {
                            Box(Modifier.weight(1f)) { com.scottgerstl.lupe.ui.automation.LaneView(ed, auto, core, track, Modifier.fillMaxSize(), trailing = { LaneKey(ui) }) }
                        }
                        RightMode.Keys -> KeyboardStrip(ed, track, core, pick.step, ui)
                    }
                }
            }
        }
    }
}

private enum class PanelMode { Home, Step, Sound }
private enum class RightMode { Keys, Lane, Tiles }

/** "Lane": swaps the keyboard for the one-lane view (decision 7), and back. */
@Composable
private fun LaneKey(ui: EditUi) =
    Key({ ui.lane = !ui.lane }, "Automation lane", width = 56.dp, height = 28.dp, minTarget = 32.dp, on = ui.lane, role = Role.Switch,
        state = if (ui.lane) "On: the lane is in the keyboard's place" else "Off") { fg -> KeyLabel("Lane", fg, style = LupeType.key.copy(fontSize = 13.sp)) }

// ---- ruler and lock banner

@Composable
private fun Ruler(ed: EditorState, track: Color, core: LupeCore, stepPicked: Boolean) {
    val locking = ed.lock != LockMode.Off
    LupeCrossfade(locking, Modifier.fillMaxWidth().height(32.dp)) { l ->
        if (l) LockBanner(ed, track) else Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f).semantics(mergeDescendants = true) { contentDescription = "Editing track ${ed.track} ${ed.trackName}, entry ${ed.entry}, pattern ${ed.pattern}${if (ed.scale.isNotEmpty()) ", ${ed.scale}" else ""}"; heading() },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.size(10.dp).background(track, RoundedCornerShape(5.dp)))
                BasicText("${ed.track} ${ed.trackName}", style = LupeType.key, maxLines = 1)
                BasicText("· ${ed.entry} · pattern ${"%02d".format(ed.pattern)}" + if (ed.scale.isNotEmpty()) " · ${ed.scale}" else "", style = LupeType.body.copy(fontSize = 14.sp), maxLines = 1)
            }
            StepMenuKey(ed, core, stepPicked)
        }
    }
}

@Composable
private fun LockBanner(ed: EditorState, track: Color) {
    val held = ed.lock == LockMode.Held
    Row(
        Modifier.fillMaxWidth().height(32.dp).background(lerp(Tok.page, track, 0.30f), RoundedCornerShape(8.dp)).padding(horizontal = 12.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Locking knob turns to step ${ed.selected + 1}. " + if (held) "Let go to stop." else "Tap Lock to stop." },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Diamond(track, 8.dp)
        BasicText("Locking knob turns to step ${ed.selected + 1}", style = LupeType.key, maxLines = 1)
        Spacer(Modifier.weight(1f))
        BasicText(if (held) "let go to stop" else "tap Lock to stop", style = LupeType.small, maxLines = 1)
    }
}

@Composable
private fun Diamond(color: Color, size: Dp, modifier: Modifier = Modifier) =
    Canvas(modifier.size(size + 2.dp)) { diamond(color, this.size.width / 2, this.size.height / 2, size.toPx() / 2) }

internal fun DrawScope.diamond(color: Color, cx: Float, cy: Float, r: Float) =
    drawPath(Path().apply { moveTo(cx, cy - r * 1.2f); lineTo(cx + r * 1.2f, cy); lineTo(cx, cy + r * 1.2f); lineTo(cx - r * 1.2f, cy); close() }, color)

private enum class StepMenuMode { Root, ClearConfirm, PasteConfirm }

@Composable
private fun StepMenuKey(ed: EditorState, core: LupeCore, enabled: Boolean) {
    var open by remember { mutableStateOf(false) }
    var mode by remember { mutableStateOf(StepMenuMode.Root) }
    var armedAt by remember { mutableStateOf(0L) }
    val n = ed.selected + 1
    val step = ed.steps.getOrNull(ed.selected)
    // A step that holds the note before it (a TIE): writing here shortens that note (Skiff's own behaviour; Scott lost
    // step 15's D5 length this way without a warning, 2026-11-14). `heldFrom` is the 0-based step whose note it holds.
    val held = step?.heldFrom?.takeIf { it >= 0 }?.let { ed.steps.getOrNull(it)?.let { owner -> it to owner } }
    fun shortens(verb: String) = held?.let { (from, owner) ->
        val left = ed.selected - from
        "$verb here shortens step ${from + 1} (${owner.pitchText.ifEmpty { owner.note }}) to $left step${if (left == 1) "" else "s"}."
    }
    Box {
        Key({ open = true; mode = StepMenuMode.Root }, "Step menu", width = 64.dp, height = 28.dp, minTarget = 32.dp, enabled = enabled, state = if (enabled) null else "Pick a step first") { fg ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                KeyLabel("Step", fg)
                Canvas(Modifier.size(14.dp, 4.dp)) { for (i in 0..2) drawCircle(fg, 1.5.dp.toPx(), Offset(2.dp.toPx() + i * 5.dp.toPx(), 2.dp.toPx())) }
            }
        }
        LupeMenu(open, { open = false }, alignEnd = true, width = 232.dp) {
            LupeCrossfade(mode) { m ->
                Column {
                    when (m) {
                        StepMenuMode.Root -> {
                            MenuHeading("Step $n")
                            MenuRow("Copy step", { core.send(Intent.StepAction(ed.selected, StepActionKind.Copy)); open = false })
                            MenuRow("Paste step", { if (held != null) { mode = StepMenuMode.PasteConfirm; armedAt = System.currentTimeMillis() } else { core.send(Intent.StepAction(ed.selected, StepActionKind.Paste)); open = false } },
                                sub = shortens("Pasting"))
                            MenuRow("Clear step", { mode = StepMenuMode.ClearConfirm; armedAt = System.currentTimeMillis() }, enabled = step?.on == true || held != null,
                                sub = shortens("Clearing"))
                        }
                        StepMenuMode.ClearConfirm -> {
                            val goes = buildString {
                                append(step?.note.orEmpty().ifEmpty { "the step" })
                                val l = step?.values?.count { it.locked } ?: 0
                                if (l > 0) append(" and its $l lock${if (l == 1) "" else "s"}")
                            }
                            val note = shortens("Clearing")
                            val words = (if (step?.on == true) "Clear step $n, removing $goes." else "Clear step $n.") + (note?.let { " $it" } ?: "")
                            ConfirmBox(words, "Confirm: $words", armedAt) { core.send(Intent.StepAction(ed.selected, StepActionKind.Clear)); open = false }
                            MenuRow("Cancel", { mode = StepMenuMode.Root })
                        }
                        StepMenuMode.PasteConfirm -> {
                            val words = "Paste into step $n. ${shortens("Pasting") ?: ""}".trim()
                            ConfirmBox(words, "Confirm: $words", armedAt) { core.send(Intent.StepAction(ed.selected, StepActionKind.Paste)); open = false }
                            MenuRow("Cancel", { mode = StepMenuMode.Root })
                        }
                    }
                }
            }
        }
    }
}

/** DESIGN.md "Destructive actions": a row outlined in REC red naming exactly what goes. It ignores taps for 0.4 s. */
@Composable
fun ConfirmBox(text: String, description: String, armedAt: Long, modifier: Modifier = Modifier, onConfirm: () -> Unit) {
    Box(
        modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp)
            .drawBehind { drawRoundRect(Tok.rec, cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = description; onClick { if (System.currentTimeMillis() - armedAt > 400) { onConfirm(); true } else false } }
            .pointerInput(armedAt) { awaitEachGesture { awaitFirstDown(); if (waitForUpOrCancellation() != null && System.currentTimeMillis() - armedAt > 400) onConfirm() } }
            .padding(12.dp),
        contentAlignment = Alignment.CenterStart,
    ) { BasicText(text, style = LupeType.key) }
}

// ---- the grid

// ---- sixteen steps across, in fours

private val GAP_IN = 4.dp      // between steps
private val GAP_BEAT = 12.dp   // between beats: the FM-1's steps and keys run in fours

/** Step [i]'s left edge and the step width, across [w]. */
private fun colX(i: Int, w: Dp): Pair<Dp, Dp> {
    val cw = (w - GAP_IN * 12 - GAP_BEAT * 3) / 16
    return (cw * i + GAP_IN * (i - i / 4) + GAP_BEAT * (i / 4)) to cw
}

/** The notes on a step: the core's MIDI numbers, or (an older recording) what its PITCH text names. */
private fun stepNotes(s: Step): List<Int> = if (!s.on) emptyList() else s.notes.ifEmpty { s.pitchText.ifEmpty { s.note }.split(" ").filter { it.isNotEmpty() }.map { com.scottgerstl.lupe.core.FakeData.parseNote(it) } }

/**
 * A melodic pattern (board 73 A and B): each step shows its note large (a chord: the root large and the other notes under it), its velocity
 * as the fill's strength and a bar, ◆ for a lock; the playing step is outlined in the track's colour and the picked one ringed in white. A
 * note that holds on draws its length as a bar across the steps it ties over, on top of the cells.
 */
@Composable
private fun StepRow(ed: EditorState, track: Color, core: LupeCore, picked: Int?, onPick: (Int?) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = maxWidth; val h = maxHeight
        for (i in 0 until 16) {
            val (x, cw) = colX(i, w)
            Box(Modifier.offset(x = x)) { StepCell(i, ed.steps.getOrNull(i) ?: Step(), ed, track, cw, h, core, picked, onPick) }
        }
        // the ties: over the cells, never touched
        Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            ed.steps.forEachIndexed { i, s ->
                if (s.on && s.length > 1) {
                    val (x0, cw) = colX(i, w); val (x1, _) = colX(minOf(15, i + s.length - 1), w)
                    drawRoundRect(track, Offset(x0.toPx() + 7.dp.toPx(), size.height - 8.dp.toPx()), Size((x1 + cw - x0).toPx() - 14.dp.toPx(), 4.dp.toPx()), CornerRadius(2.dp.toPx()))
                }
            }
        }
    }
}

@Composable
private fun StepCell(i: Int, s: Step, ed: EditorState, track: Color, w: Dp, h: Dp, core: LupeCore, picked: Int?, onPick: (Int?) -> Unit) {
    val selected = picked == i
    val held = ed.lock == LockMode.Held && ed.selected == i
    val pickNow by rememberUpdatedState(picked)
    val now = ed.playhead == i
    val onF = animatedFloat(if (s.on) 1f else 0f, Dur.STATE)
    val vel = animatedFloat(s.velocity / 127f, Dur.STATE)
    val sel = animatedFloat(if (selected) 1f else 0f, Dur.STATE)
    val nowF = animatedFloat(if (now) 1f else 0f, 60)
    val lift = animatedFloat(if (held) 1f else 0f, Dur.STATE)
    val haptic = LocalHapticFeedback.current
    val longPress = LocalViewConfiguration.current.longPressTimeoutMillis
    val fillOn = lerp(Tok.page, track, (18 + vel.value * 26) / 100f)
    val notes = if (s.notes.isNotEmpty()) s.notes.map { com.scottgerstl.lupe.core.FakeData.noteName(it) } else s.pitchText.ifEmpty { s.note }.split(" ").filter { it.isNotEmpty() }
    Box(
        Modifier.width(w).height(h)
            .graphicsLayer { translationY = -2.dp.toPx() * lift.value }
            .drawBehind {
                val r = CornerRadius(8.dp.toPx())
                drawRoundRect(lerp(Tok.stepEmpty, fillOn, onF.value), cornerRadius = r)
                // the velocity again as a bar: its height says how hard, inside the cell above the tie's line
                if (s.on) { val bh = 28.dp.toPx() * vel.value; drawRoundRect(track.copy(alpha = 0.35f * onF.value), Offset(7.dp.toPx(), size.height - 16.dp.toPx() - bh), Size(size.width - 14.dp.toPx(), bh), CornerRadius(2.dp.toPx())) }
                if (nowF.value > 0f) drawRoundRect(track.copy(alpha = nowF.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                if (s.locked) diamond(Tok.text, size.width - 11.dp.toPx(), 12.dp.toPx(), 4.dp.toPx())
            }
            .semantics(mergeDescendants = true) {
                role = Role.Button
                contentDescription = "Step ${i + 1}, " + (if (s.on) notes.joinToString(" ") + ", length ${s.length}, velocity ${s.velocity}" else "empty") + (if (s.locked) ", has a lock" else "")
                stateDescription = if (selected) "Selected" else ""
                onClick { if (pickNow == i) onPick(null) else { onPick(i); core.send(Intent.StepSelect(i)) }; true }
                customActions = listOf(
                    CustomAccessibilityAction("Lock knob turns to this step") { onPick(i); core.send(Intent.StepSelect(i)); core.send(Intent.LockToggle); true },
                    CustomAccessibilityAction("Copy step") { core.send(Intent.StepAction(i, StepActionKind.Copy)); true },
                )
            }
            // tap: pick (again: let go). Hold: lock mode for as long as the finger stays down (the FM-1's own gesture).
            .pointerInput(i) {
                awaitEachGesture {
                    awaitFirstDown()
                    var cancelled = false
                    val up = withTimeoutOrNull(longPress) { waitForUpOrCancellation().also { if (it == null) cancelled = true } }
                    if (cancelled) return@awaitEachGesture
                    if (up != null) { if (pickNow == i) onPick(null) else { onPick(i); core.send(Intent.StepSelect(i)) } }
                    else {
                        onPick(i)
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        core.send(Intent.StepHold(i, true))
                        waitForUpOrCancellation()
                        core.send(Intent.StepHold(i, false))
                    }
                }
            },
    ) {
        BasicText("${i + 1}", Modifier.padding(start = 7.dp, top = 5.dp), style = LupeType.small.copy(color = if (s.on) Tok.text2Raised else Tok.text2))
        if (s.on && notes.isNotEmpty()) {
            val fit = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 13.sp, maxFontSize = 22.sp, stepSize = 1.sp)
            if (notes.size == 1) BasicText(notes[0], Modifier.align(Alignment.CenterStart).padding(start = 7.dp, end = 4.dp, bottom = 16.dp), style = LupeType.number.copy(fontSize = 22.sp, lineHeight = 24.sp), maxLines = 1, softWrap = false, autoSize = fit)
            else Column(Modifier.padding(start = 7.dp, end = 4.dp, top = 24.dp)) {
                // a chord: the root large, the other notes under it (up to the FM-1's four)
                BasicText(notes[0], style = LupeType.number.copy(fontSize = 20.sp, lineHeight = 22.sp), maxLines = 1, softWrap = false, autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 13.sp, maxFontSize = 20.sp, stepSize = 1.sp))
                notes.drop(1).take(3).forEach { BasicText(it, style = LupeType.number.copy(fontSize = 15.sp, lineHeight = 17.sp, color = Tok.text2Raised), maxLines = 1, softWrap = false) }
            }
        }
    }
}

// ---- a kit: lanes by steps

/**
 * A kit (board 73 C): its lanes down, the sixteen steps across in fours. A tap puts a hit on or takes it off; a hold picks the hit without
 * toggling it (white ring; its values show under the grid). The fill's strength is the step's velocity.
 */
@Composable
private fun DrumGrid(ed: EditorState, track: Color, core: LupeCore, hit: Pair<String, Int>?, onPick: (Pair<String, Int>?) -> Unit) {
    val lanes = ed.kitLanes.ifEmpty { ed.steps.flatMap { it.note.split(" ") }.filter { it.isNotEmpty() }.distinct() }.ifEmpty { listOf("—") }
    val top by core.top.collectAsStateWithLifecycle()
    val haptic = LocalHapticFeedback.current
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val gap = 3.dp
        val rh = ((maxHeight - gap * (lanes.size - 1)) / lanes.size)
        val labelW = 44.dp
        val gw = maxWidth - labelW
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            lanes.forEachIndexed { k, lane ->
                Box(Modifier.fillMaxWidth().height(rh)) {
                    // the lane's name plays it while pressed (not while recording: the FM-1 would record it)
                    BasicText(lane, Modifier.align(Alignment.CenterStart).width(labelW - 4.dp)
                        .semantics { role = Role.Button; contentDescription = "Play $lane" }
                        .pointerInput(k) { detectTapGestures(onPress = { if (!(top.rec && top.playing)) { core.send(PlayNote(lane = k, on = true)); tryAwaitRelease(); core.send(PlayNote(lane = k, on = false)) } }) }, style = LupeType.label.copy(fontSize = 13.sp, color = if (hit?.first == lane) Tok.text else Tok.text2Raised), maxLines = 1)
                    for (i in 0 until 16) {
                        val s = ed.steps.getOrNull(i) ?: Step()
                        val on = s.on && (if (s.hits.isNotEmpty()) s.hits.any { it.lane == k } else lane in s.note.split(" "))
                        val picked = hit?.first == lane && hit.second == i
                        val (x, cw) = colX(i, gw)
                        val onF = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                        val sel = animatedFloat(if (picked) 1f else 0f, Dur.STATE)
                        val fill = lerp(Tok.page, track, (30 + s.velocity / 127f * 60) / 100f)
                        Box(
                            Modifier.offset(x = labelW + x).width(cw).fillMaxHeight()
                                .drawBehind {
                                    val r = CornerRadius(5.dp.toPx())
                                    drawRoundRect(lerp(Tok.stepEmpty, fill, onF.value), cornerRadius = r)
                                    if (ed.playhead == i) drawRoundRect(track.copy(alpha = 0.7f), Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(4.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                                    if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(4.dp.toPx()), style = Stroke(2.dp.toPx()))
                                }
                                .semantics(mergeDescendants = true) {
                                    role = Role.Button
                                    contentDescription = "$lane, step ${i + 1}" + (if (on) ", hit" else ", empty") + if (picked) ", picked" else ""
                                    onClick { core.send(ToggleHit(k, i)); true }
                                    customActions = listOf(CustomAccessibilityAction("Pick this hit without changing it") { onPick(lane to i); core.send(Intent.StepSelect(i)); true })
                                }
                                .pointerInput(k, i) {
                                    detectTapGestures(
                                        onTap = { core.send(ToggleHit(k, i)) },
                                        onLongPress = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); onPick(lane to i); core.send(Intent.StepSelect(i)) },
                                    )
                                },
                        )
                    }
                }
            }
        }
    }
}

/** The picked hit's values in one row of boxes (a kit has more than four per hit, so boxes, not dials), under a "SD · step 5 ✕" key. */
@Composable
private fun HitPanel(ed: EditorState, track: Color, core: LupeCore, hit: Pair<String, Int>?, onClose: () -> Unit) {
    val (lane, step) = hit ?: return
    val s = ed.steps.getOrNull(step) ?: Step()
    val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
    Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Key(onClose, "$lane, step ${step + 1}: close and show the sound knobs", width = 112.dp, height = 28.dp, minTarget = 44.dp) { fg ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel("$lane · step ${step + 1}", fg, style = LupeType.key.copy(fontSize = 13.sp)); Cross(fg) }
        }
        ValueBox("VELOCITY", "${s.velocity}", "Velocity", track, "velocity" to step, 3f, false, s.velocity, 1, 127, unit = 4, modifier = Modifier.weight(1f)) { send(StepField.Velocity, it) }
        ValueBox("CHANCE", "${s.chance}%", "Chance", track, "chance" to step, 4f, false, s.chance, 0, 100, unit = 5, modifier = Modifier.weight(1f)) { send(StepField.Chance, it) }
        ValueBox("RATCHET", "×${s.ratchet}", "Ratchet", track, "ratchet" to step, 28f, true, s.ratchet, 1, 4, modifier = Modifier.weight(1f)) { send(StepField.Ratchet, it) }
        ValueBox("NUDGE", "${s.nudge}", "Nudge", track, "nudge" to step, 12f, false, s.nudge, -12, 12, bipolar = true, modifier = Modifier.weight(1f)) { send(StepField.Nudge, it) }
        // the lane's own PITCH and DECAY: the editor area doesn't carry a lane's sound yet, so they show and say so (P1)
        ValueBox("PITCH", "—", "Lane pitch, not available yet", track, "lp" to lane, 12f, false, null, enabled = false, modifier = Modifier.weight(1f)) { }
        ValueBox("DECAY", "—", "Lane decay, not available yet", track, "ld" to lane, 12f, false, null, enabled = false, modifier = Modifier.weight(1f)) { }
    }
}

@Composable
private fun Cross(fg: Color) = Canvas(Modifier.size(9.dp)) { val w = 1.5.dp.toPx(); drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), w, StrokeCap.Round); drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), w, StrokeCap.Round) }

/** A value in a box: label over value, a gauge along the foot. It slides like a dial (the direction setting, the Magnifier, double tap back). */
@Composable
private fun ValueBox(
    label: String, value: String, name: String, tint: Color, key: Any, dpPerStep: Float, tick: Boolean, num: Int?, min: Int = 0, max: Int = 0,
    bipolar: Boolean = false, unit: Int = 1, enabled: Boolean = true, modifier: Modifier = Modifier, onSteps: (Int) -> Unit,
) {
    val haptic = LocalHapticFeedback.current
    val send by rememberUpdatedState(onSteps)
    var net by remember(key) { mutableStateOf(0) }
    var last by remember { mutableStateOf(0) }
    var hot by remember { mutableStateOf(false) }
    val hotF = animatedFloat(if (hot) 1f else 0f, Dur.STATE)
    val fraction = if (num != null && max > min) (num - min).toFloat() / (max - min) else null
    val shown by rememberUpdatedState(value)
    val frac by rememberUpdatedState(fraction)
    fun step(d: Int) { if (d == 0) return; net += d; send(d); if (tick) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
    Box(
        modifier.height(56.dp).clip(RoundedCornerShape(10.dp)).background(Tok.panel)
            .semantics(mergeDescendants = true) {
                contentDescription = name; stateDescription = value; role = Role.Button
                if (!enabled) disabled()
                if (num != null && enabled) {
                    progressBarRangeInfo = ProgressBarRangeInfo(num.toFloat(), min.toFloat()..max.toFloat(), max - min - 1)
                    setProgress { v -> step((v.roundToInt() - num) / unit); true }
                    customActions = listOf(
                        CustomAccessibilityAction("Increase $name") { step(1); true }, CustomAccessibilityAction("Decrease $name") { step(-1); true },
                        CustomAccessibilityAction("Put $name back as it was") { val b = -net; net = 0; send(b); true },
                    )
                }
            }
            .then(if (!enabled) Modifier else Modifier
                .pointerInput(key) { detectTapGestures(onDoubleTap = { val b = -net; net = 0; if (b != 0) { send(b); haptic.performHapticFeedback(HapticFeedbackType.Confirm) } }) }
                .slideToTurn(
                    enabled = true, stepDp = dpPerStep,
                    face = remember(label, tint) { MagnifierFace(label, { shown }, { frac }, bipolar, ring = false, tint = tint) },
                    onStart = { last = 0; hot = true }, onSlide = { total -> step(total - last); last = total }, onEnd = { hot = false },
                    bounds = { num?.let { n -> -((n - min) / unit)..((max - n) / unit) } },
                    onLimit = { haptic.performHapticFeedback(HapticFeedbackType.ContextClick) },
                )),
    ) {
        Column(Modifier.padding(start = 10.dp, end = 8.dp, top = 7.dp)) {
            BasicText(label, style = LupeType.label.copy(fontFamily = LupeType.number.fontFamily, letterSpacing = 0.5.sp, color = Tok.text2Raised), maxLines = 1)
            BasicText(value, style = LupeType.number.copy(fontSize = 22.sp, lineHeight = 24.sp, color = if (enabled) Tok.text else Tok.text2), maxLines = 1)
        }
        if (fraction != null) Canvas(Modifier.align(Alignment.BottomStart).fillMaxWidth().height(3.dp)) {
            drawRect(Tok.stepEmpty)
            val x = fraction.coerceIn(0f, 1f) * size.width; val from = if (bipolar) size.width / 2 else 0f
            drawRect(tint, Offset(minOf(from, x), 0f), Size(maxOf(kotlin.math.abs(x - from), if (bipolar) 2f else 0f), size.height))
        }
        Box(Modifier.align(Alignment.TopStart).fillMaxWidth().height(3.dp).graphicsLayer { alpha = hotF.value }.background(Tok.text))
    }
}

// ---- the step panel: Step N ✕, ‹ ›, NOTES · FEEL · SOUND, Lock, and the four dials

@Composable
private fun StepControls(ed: EditorState, track: Color, core: LupeCore, tab: PanelTab, setTab: (PanelTab) -> Unit, pick: StepPick) {
    val s = ed.steps.getOrNull(ed.selected) ?: Step()
    val n = ed.selected + 1
    var confirm by remember { mutableStateOf(false) }
    var armedAt by remember { mutableStateOf(0L) }
    val lockedCount = s.values.count { it.locked }
    // leaving the SOUND tab, or the step, closes a pending confirm
    if (confirm && (tab != PanelTab.Sound || lockedCount == 0)) confirm = false
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            // "Step 6 ✕": the way back to the sound knobs (also: tap the step again)
            Key({ if (ed.lock == LockMode.Latched) core.send(Intent.LockToggle); pick.step = null }, "Step $n: close and show the sound knobs", width = 72.dp, height = 28.dp, minTarget = 32.dp) { fg ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel("Step $n", fg, style = LupeType.key.copy(fontSize = 13.sp)); Cross(fg) }
            }
            Spacer(Modifier.width(6.dp))
            Key({ val to = Math.floorMod(ed.selected - 1, 16); pick.step = to; core.send(Intent.StepSelect(to)) }, "Previous step", width = 28.dp, height = 28.dp, minTarget = 32.dp) { fg -> Chevron90(fg, true) }
            Spacer(Modifier.width(2.dp))
            Key({ val to = Math.floorMod(ed.selected + 1, 16); pick.step = to; core.send(Intent.StepSelect(to)) }, "Next step", width = 28.dp, height = 28.dp, minTarget = 32.dp) { fg -> Chevron90(fg, false) }
            Spacer(Modifier.width(6.dp))
            PanelTabs(tab, setTab)
            Spacer(Modifier.weight(1f))
            if (tab == PanelTab.Sound) {
                Key({ if (lockedCount > 0) { confirm = true; armedAt = System.currentTimeMillis() } }, "Clear all locks on step $n", width = 72.dp, height = 28.dp, minTarget = 32.dp,
                    enabled = lockedCount > 0 && !confirm) { fg -> KeyLabel("Clear all", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            } else {
                val latched = ed.lock == LockMode.Latched
                Key({ core.send(Intent.LockToggle) }, "Lock", width = 72.dp, height = 28.dp, minTarget = 32.dp, on = latched, role = Role.Switch,
                    state = if (latched) "On: knob turns lock to step $n" else "Off") { fg ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Canvas(Modifier.size(10.dp)) { if (latched) diamond(fg, size.width / 2, size.height / 2, 4.dp.toPx()) else
                            drawPath(Path().apply { moveTo(size.width / 2, 0f); lineTo(size.width, size.height / 2); lineTo(size.width / 2, size.height); lineTo(0f, size.height / 2); close() }, fg, style = Stroke(1.5.dp.toPx())) }
                        KeyLabel("Lock", fg, style = LupeType.key.copy(fontSize = 13.sp))
                    }
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        LupeCrossfade(Pair(tab, confirm), Modifier.fillMaxSize()) { (t, c) ->
            val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
            val chord = stepNotes(s).size > 1
            when {
                t == PanelTab.Notes -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    // a chord step's first dial is its ROOT; the keys beside it add and take notes
                    com.scottgerstl.lupe.ui.page.DeltaDial(if (chord) "ROOT" else "PITCH", if (s.on) s.pitchText.substringBefore(' ').ifEmpty { s.note } else "—", "Pitch", track, key = "pitch" to ed.selected,
                        dpPerStep = 16f, tick = false, locked = s.isLocked("PITCH")) { send(StepField.Pitch, it) }
                    // MOVE follows the step, so its undo spans the selection changing
                    com.scottgerstl.lupe.ui.page.DeltaDial("MOVE", "$n", "Move", track, key = "move" to ed.pattern, num = n, min = 1, max = 16, dpPerStep = 22f, tick = true, locked = false) { d ->
                        pick.step = Math.floorMod(ed.selected + d, 16); send(StepField.Move, d) }
                    // LENGTH grows only up to the next note (the core's maxLength): at the limit the slide stops
                    val cap = s.maxLength.coerceIn(1, 16)
                    val nextNote = ed.selected + 1 + cap
                    com.scottgerstl.lupe.ui.page.DeltaDial("LENGTH", "${s.length}", "Length", track, key = "length" to ed.selected, num = s.length, min = 1, max = cap, dpPerStep = 16f, tick = false, locked = s.isLocked("LENGTH"),
                        limitWord = if (s.length >= cap) (if (nextNote > 16) "pattern ends" else "note at step $nextNote") else null) { send(StepField.Length, it) }
                    com.scottgerstl.lupe.ui.page.DeltaDial("VELOCITY", "${s.velocity}", "Velocity", track, key = "velocity" to ed.selected, num = s.velocity, min = 1, max = 127, unit = 4, dpPerStep = 3f, tick = false, locked = s.isLocked("VELOCITY")) { send(StepField.Velocity, it) }
                }
                t == PanelTab.Feel -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    com.scottgerstl.lupe.ui.page.DeltaDial("CHANCE", "${s.chance}%", "Chance", track, key = "chance" to ed.selected, num = s.chance, min = 0, max = 100, unit = 5, dpPerStep = 4f, tick = false, locked = s.isLocked("CHANCE")) { send(StepField.Chance, it) }
                    com.scottgerstl.lupe.ui.page.DeltaDial("RATCHET", "${s.ratchet}", "Ratchet", track, key = "ratchet" to ed.selected, num = s.ratchet, min = 1, max = 4, dpPerStep = 28f, tick = true, locked = s.isLocked("RATCHET")) { send(StepField.Ratchet, it) }
                    // COND is a list: each step through it ticks
                    com.scottgerstl.lupe.ui.page.DeltaDial("COND", s.cond, "Condition", track, key = "cond" to ed.selected, dpPerStep = 26f, tick = true, locked = s.isLocked("COND")) { send(StepField.Cond, it) }
                    com.scottgerstl.lupe.ui.page.DeltaDial("NUDGE", "${s.nudge}", "Nudge", track, key = "nudge" to ed.selected, num = s.nudge, min = -12, max = 12, bipolar = true, dpPerStep = 12f, tick = false, locked = s.isLocked("NUDGE")) { send(StepField.Nudge, it) }
                }
                c -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    val names = s.values.filter { it.locked }.joinToString(", ") { it.param }
                    ConfirmBox("Clear ${if (lockedCount == 1) "the lock" else "both locks".takeIf { lockedCount == 2 } ?: "all $lockedCount locks"} on step $n ($names)",
                        "Confirm: clear $lockedCount lock${if (lockedCount == 1) "" else "s"} on step $n: $names", armedAt, Modifier.weight(1f)) { core.send(Intent.LocksClearAll(ed.selected)); confirm = false }
                    Key({ confirm = false }, "Cancel", width = 72.dp, height = 36.dp, minTarget = 40.dp) { fg -> KeyLabel("Cancel", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                }
                else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                    if (s.values.isEmpty()) BasicText("No locks on this step. Hold it and turn a knob on the FM-1, or latch Lock.", Modifier.padding(top = 6.dp), style = LupeType.body.copy(fontSize = 14.sp))
                    s.values.forEach { v -> LockRow(v.param, v.value, v.locked, track) { core.send(Intent.LockClear(ed.selected, v.param)) } }
                }
            }
        }
    }
}

// ---- the keyboard strip: the phone's own keys write the picked step

/**
 * About an octave and a half (C to the F above), moved an octave at a time by ‹ ›. With a step picked a key tap writes that note to the
 * step and plays it; with Chord on each tap adds the note or takes it off, up to the FM-1's four (the keys on the step are lit). With
 * nothing picked the keys only play. Only these keys write: the FM-1's own never write from the phone (decision 5).
 */
@Composable
private fun KeyboardStrip(ed: EditorState, track: Color, core: LupeCore, picked: Int?, ui: EditUi) {
    val onStep = if (picked != null) ed.steps.getOrNull(picked)?.let { stepNotes(it) }.orEmpty() else emptyList()
    val base = (ui.octave + 1) * 12                        // C of the octave shown
    val whites = listOf(0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17)
    val blacks = listOf(0 to 1, 1 to 3, 3 to 6, 4 to 8, 5 to 10, 7 to 13, 8 to 15)   // after white [first]: semitone [second]
    val top by core.top.collectAsStateWithLifecycle()
    val max = ed.maxNotes.coerceAtLeast(1)
    // a key going down plays (never while REC is armed and playing: the FM-1 would record it); with a step picked it also writes
    fun down(midi: Int) {
        if (picked != null) core.send(if (ed.chord) ToggleStepNote(picked, midi) else SetStepNotes(picked, listOf(midi)))
        if (!(top.rec && top.playing)) core.send(PlayNote(note = midi, on = true))
    }
    fun up(midi: Int) { if (!(top.rec && top.playing)) core.send(PlayNote(note = midi, on = false)) }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            Key({ core.send(Intent.ChordToggle) }, "Chord", width = 64.dp, height = 28.dp, minTarget = 32.dp, on = ed.chord, role = Role.Switch,
                state = if (ed.chord) "On: each key adds a note to the step or takes it off" else "Off: a key replaces the step's note") { fg -> KeyLabel("Chord", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            Spacer(Modifier.width(6.dp))
            LaneKey(ui)
            Spacer(Modifier.width(8.dp))
            BasicText(
                when { picked == null -> "Keys play the track"; ed.chord -> "Tap keys to add or take notes · ${onStep.size} of $max"; else -> "Tap a key: step ${picked + 1} plays it" },
                Modifier.weight(1f), style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1,
            )
            Key({ ui.octave = (ui.octave - 1).coerceAtLeast(0) }, "Keys an octave lower", width = 28.dp, height = 28.dp, minTarget = 32.dp, enabled = ui.octave > 0) { fg -> Chevron90(fg, true) }
            Spacer(Modifier.width(2.dp))
            Key({ ui.octave = (ui.octave + 1).coerceAtMost(7) }, "Keys an octave higher", width = 28.dp, height = 28.dp, minTarget = 32.dp, enabled = ui.octave < 7) { fg -> Chevron90(fg, false) }
        }
        Spacer(Modifier.height(4.dp))
        BoxWithConstraints(Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(8.dp)).background(Tok.chicletEdge)) {
            val kw = maxWidth / whites.size
            whites.forEachIndexed { i, semi ->
                val midi = base + semi; val name = com.scottgerstl.lupe.core.FakeData.noteName(midi); val on = midi in onStep
                val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                Box(
                    Modifier.offset(x = kw * i).width(kw).fillMaxHeight().padding(1.dp).clip(RoundedCornerShape(bottomStart = 6.dp, bottomEnd = 6.dp)).drawBehind { drawRect(lerp(Tok.text2Raised, track, lit.value)) }
                        .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = name + if (on) ", on the step" else ""; onClick { down(midi); up(midi); true } }
                        .pointerInput(midi, picked, ed.chord) { detectTapGestures(onPress = { down(midi); tryAwaitRelease(); up(midi) }) },
                ) { BasicText(name, Modifier.align(Alignment.BottomCenter).padding(bottom = 3.dp), style = LupeType.label.copy(fontSize = 11.sp, color = Tok.onColour), maxLines = 1) }
            }
            blacks.forEach { (after, semi) ->
                val midi = base + semi; val name = com.scottgerstl.lupe.core.FakeData.noteName(midi); val on = midi in onStep
                val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                Box(
                    Modifier.offset(x = kw * (after + 1) - kw * 0.32f).width(kw * 0.64f).fillMaxHeight(0.58f).clip(RoundedCornerShape(bottomStart = 4.dp, bottomEnd = 4.dp))
                        .drawBehind { drawRect(Tok.chicletEdge); drawRect(lerp(Tok.panel, track, lit.value), Offset(1.dp.toPx(), 0f), Size(size.width - 2.dp.toPx(), size.height - 1.dp.toPx())) }
                        .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = name + if (on) ", on the step" else ""; onClick { down(midi); up(midi); true } }
                        .pointerInput(midi, picked, ed.chord) { detectTapGestures(onPress = { down(midi); tryAwaitRelease(); up(midi) }) },
                )
            }
        }
    }
}

@Composable
private fun Chevron90(color: Color, left: Boolean) =
    Canvas(Modifier.size(6.dp, 10.dp)) {
        val p = Path().apply { if (left) { moveTo(size.width - 1.dp.toPx(), 1.dp.toPx()); lineTo(1.dp.toPx(), size.height / 2); lineTo(size.width - 1.dp.toPx(), size.height - 1.dp.toPx()) } else { moveTo(1.dp.toPx(), 1.dp.toPx()); lineTo(size.width - 1.dp.toPx(), size.height / 2); lineTo(1.dp.toPx(), size.height - 1.dp.toPx()) } }
        drawPath(p, color, style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    }

@Composable
private fun PanelTabs(tab: PanelTab, setTab: (PanelTab) -> Unit) {
    Row(Modifier.width(168.dp).height(28.dp).background(Tok.well, RoundedCornerShape(8.dp)).selectableGroup().padding(2.dp)) {
        PanelTab.entries.forEach { t ->
            val lit = animatedFloat(if (t == tab) 1f else 0f, Dur.STATE)
            Box(
                Modifier.weight(1f).fillMaxHeight()
                    .semantics(mergeDescendants = true) { role = Role.Tab; selected = t == tab; contentDescription = t.label.lowercase().replaceFirstChar { it.uppercase() } }
                    .pointerInput(t) { awaitEachGesture { awaitFirstDown(); if (waitForUpOrCancellation() != null) setTab(t) } }
                    .drawBehind {
                        val r = CornerRadius(6.dp.toPx())
                        drawRoundRect(Tok.chicletEdge.copy(alpha = lit.value), Offset(0f, 2.dp.toPx()), Size(size.width, size.height - 2.dp.toPx()), r)
                        drawRoundRect(Tok.control.copy(alpha = lit.value), Offset.Zero, Size(size.width, size.height - 2.dp.toPx()), r)
                    },
                contentAlignment = Alignment.Center,
            ) { BasicText(t.label, style = LupeType.label.copy(fontFamily = LupeType.number.fontFamily, letterSpacing = 0.5.sp, color = lerp(Tok.text2Raised, Tok.text, lit.value))) }
        }
    }
}

@Composable
private fun LockRow(param: String, value: Int, locked: Boolean, track: Color, onClear: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(30.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (locked) Diamond(track, 6.dp) else BasicText("—", Modifier.width(12.dp), style = LupeType.body.copy(textAlign = TextAlign.Center))
        BasicText(param, style = LupeType.key)
        BasicText("$value", style = LupeType.number.copy(fontSize = 18.sp, lineHeight = 18.sp))
        BasicText(if (locked) "locked on this step" else "recorded", style = LupeType.small, maxLines = 1)
        Spacer(Modifier.weight(1f))
        if (locked) Key(onClear, "Clear the $param lock", width = 44.dp, height = 28.dp, minTarget = 30.dp) { fg ->
            Canvas(Modifier.size(10.dp)) { val st = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round); drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), st.width, StrokeCap.Round); drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), st.width, StrokeCap.Round) }
        }
    }
}

private fun Step.isLocked(param: String) = values.any { it.locked && it.param == param }

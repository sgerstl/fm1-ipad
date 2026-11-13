package com.scottgerstl.lupe.ui.shell

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
import com.scottgerstl.lupe.ui.automation.AutomationFull
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.withTimeoutOrNull

private enum class PanelTab(val label: String) { Notes("NOTES"), Feel("FEEL"), Sound("SOUND") }

/**
 * The editor in the bottom half (boards 53, 54 and 56): the ruler (or the lock banner), the 4 × 4 step grid, one
 * automation lane when there is room (bottom full), and the step panel in the strip under the grid. Notes go in
 * from the FM-1's keys only, so there is no piano. [autoFraction] is 0..1: how much of the lane fits.
 */
/**
 * Which step the person has picked, or none (decision 21): with none, the grid shows no selected step and the strip under
 * it is HOME's four sound knobs; a tap picks a step and the strip becomes its controls. Kept above the editor so a sound page
 * (or the FM-1 changing page) can clear it. OPEN, left to Scott: it stays picked when the pattern changes.
 */
class StepPick { var step by mutableStateOf<Int?>(null) }

@Composable
fun EditorPage(
    ed: EditorState, core: LupeCore, autoFraction: Float, auto: com.scottgerstl.lupe.core.AutomationState = com.scottgerstl.lupe.core.AutomationState(),
    modifier: Modifier = Modifier, pick: StepPick = remember { StepPick() },
    /** The sound section (family keys, page row, sound page) while the FM-1 shows a sound page, or null (decision 20c). */
    sound: (@Composable () -> Unit)? = null,
    /** What the sound section needs (page row, header, dials, and tiles if any); the grid gets the rest. */
    soundNeeds: Dp = SOUND_IDEAL,
) {
    var tab by rememberSaveable { mutableStateOf(PanelTab.Notes) }
    // the whole bottom half for one lane (board 69): drawn on with a finger. Done, or Back, returns to the editor
    var drawing by rememberSaveable { mutableStateOf(false) }
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    if (ed.steps.isEmpty()) { Placeholder("No pattern", "Pick a pad: hold it, then Edit steps", modifier); return }
    if (drawing && auto.lane.isNotEmpty() && sound == null) { AutomationFull(ed, auto, core, track, { drawing = false }, modifier); return }
    // One flexible page (decision 20c): with a sound page up, the grid stays, the dials row (HOME knobs or the step's controls) goes, and the
    // sound section takes its place and more. [s] is 0 for the editor, 1 for the sound page; the two glide, never pop.
    val s by animatedFloat(if (sound != null) 1f else 0f, Dur.PANEL)
    var lastSound by remember { mutableStateOf(sound) }
    if (sound != null) lastSound = sound
    BoxWithConstraints(modifier.fillMaxSize()) {
        val ruler = 40.dp
        val lane0 = 162.dp * autoFraction
        // the grid in the editor: what is left above the lane and the strip. With a sound page: no smaller than 36 dp a row, no bigger than 72, and
        // leaving the sound section its four controls first; the section's picture takes what remains (0 at split on a 915 dp phone)
        val grid0 = (maxHeight - ruler - 12.dp - STRIP_HEIGHT - lane0).coerceAtLeast(MIN_GRID)
        // a page with tiles lets the grid squeeze to 26 dp rows at split so the tiles have some room
        val grid1 = (maxHeight - ruler - 6.dp - soundNeeds - 6.dp).coerceIn(if (soundNeeds > SOUND_IDEAL) MIN_GRID_TILES else MIN_GRID, MAX_GRID)
        val grid = grid0 + (grid1 - grid0) * s
        Column(Modifier.fillMaxSize()) {
            Ruler(ed, track, core, pick.step != null)
            Grid(ed, track, core, Modifier.height(grid), pick.step) { pick.step = it }
            // the lane shows for every pattern: with no locks or recorded motion yet it is a parameter picker, so a fresh pattern has a way in
            val laneF = autoFraction * (1f - s)
            if (laneF > 0.02f) {
                Spacer(Modifier.height(12.dp * laneF))
                AutoLane(ed, auto, track, core, { drawing = true }, Modifier.height(150.dp * laneF).graphicsLayer { alpha = laneF })
            }
            Spacer(Modifier.height(12.dp - 6.dp * s))
            Box(Modifier.weight(1f).fillMaxWidth().clipToBounds()) {
                if (s < 0.999f) Box(Modifier.fillMaxWidth().height(STRIP_HEIGHT).graphicsLayer { alpha = 1f - s }) {
                    LupeCrossfade(pick.step != null, Modifier.fillMaxSize()) { picked ->
                        if (picked) StepPanel(ed, track, core, tab, { tab = it }, pick) else HomeKnobsStrip(ed, core)
                    }
                }
                if (s > 0.001f) Box(Modifier.fillMaxSize().graphicsLayer { alpha = s }) { lastSound?.invoke() }
            }
        }
    }
}

private val MIN_GRID_TILES = 116.dp     // rows of 26 dp
private val MIN_GRID = 128.dp          // four rows of 29 dp and three 4 dp gaps (the board's miniGrid, about 30)
private val MAX_GRID = 420.dp          // rows of 102 dp
internal val SOUND_IDEAL = 120.dp       // header 28 and dials 88 (decisions 25 and 27: no picture, no page row, no button block)
internal val SOUND_IDEAL_TILES = 236.dp // with tiles to pick from: about 116 dp more for them

// ---- ruler and lock banner

@Composable
private fun Ruler(ed: EditorState, track: Color, core: LupeCore, stepPicked: Boolean) {
    val locking = ed.lock != LockMode.Off
    LupeCrossfade(locking, Modifier.fillMaxWidth().height(40.dp)) { l ->
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
        Key({ open = true; mode = StepMenuMode.Root }, "Step menu", width = 64.dp, height = 32.dp, minTarget = 40.dp, enabled = enabled, state = if (enabled) null else "Pick a step first") { fg ->
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

@Composable
internal fun Grid(ed: EditorState, track: Color, core: LupeCore, modifier: Modifier, picked: Int? = ed.selected, onPick: (Int?) -> Unit = {}) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val gap = 4.dp
        val cw = (maxWidth - gap * 3) / 4
        val ch = ((maxHeight - gap * 3) / 4).coerceAtLeast(20.dp)
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            for (r in 0 until 4) Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (c in 0 until 4) {
                    val i = r * 4 + c
                    StepCell(i, ed.steps.getOrNull(i) ?: Step(), ed, track, cw, ch, core, picked, onPick)
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
    Box(
        Modifier.width(w).height(h)
            .graphicsLayer { translationY = -2.dp.toPx() * lift.value }
            .drawBehind {
                val r = CornerRadius(8.dp.toPx())
                drawRoundRect(lerp(Tok.stepEmpty, fillOn, onF.value), cornerRadius = r)
                if (nowF.value > 0f) drawRoundRect(track.copy(alpha = nowF.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                if (s.locked) diamond(Tok.text, size.width - 12.dp.toPx(), 12.dp.toPx(), 4.dp.toPx())
            }
            .semantics(mergeDescendants = true) {
                role = Role.Button
                contentDescription = "Step ${i + 1}, " + (if (s.on) s.note + (if (s.extra > 0) " plus ${s.extra}" else "") + ", length ${s.length}" else "empty") + (if (s.locked) ", has a lock" else "")
                stateDescription = if (selected) "Selected" else ""
                onClick { if (pickNow == i) onPick(null) else { onPick(i); core.send(Intent.StepSelect(i)) }; true }
                customActions = listOf(
                    CustomAccessibilityAction("Lock knob turns to this step") { onPick(i); core.send(Intent.StepSelect(i)); core.send(Intent.LockToggle); true },
                    CustomAccessibilityAction("Copy step") { core.send(Intent.StepAction(i, StepActionKind.Copy)); true },
                )
            }
            // tap: select. Hold: lock mode for as long as the finger stays down (the FM-1's own gesture).
            .pointerInput(i) {
                awaitEachGesture {
                    awaitFirstDown()
                    var cancelled = false
                    val up = withTimeoutOrNull(longPress) { waitForUpOrCancellation().also { if (it == null) cancelled = true } }
                    if (cancelled) return@awaitEachGesture   // a swipe that something took (the stack's flip) is not a hold
                    if (up != null) { if (pickNow == i) onPick(null) else { onPick(i); core.send(Intent.StepSelect(i)) } }   // tapping the picked step again lets it go
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
        val compact = h < 52.dp   // a sound page is up and the rows are squeezed: the number and the note share one line
        if (compact) {
            Row(Modifier.align(Alignment.CenterStart).padding(start = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                BasicText("${i + 1}", Modifier.width(18.dp), style = LupeType.small.copy(fontSize = 11.sp, color = if (s.on) Tok.text2Raised else Tok.text2), maxLines = 1)
                if (s.on) {
                    BasicText(s.note, style = LupeType.number.copy(fontSize = 17.sp, lineHeight = 17.sp, color = Tok.text), maxLines = 1)
                    if (s.extra > 0) BasicText("+${s.extra}", Modifier.padding(start = 3.dp), style = LupeType.small.copy(fontSize = 10.sp))
                }
            }
            if (s.on) Box(Modifier.align(Alignment.BottomStart).padding(start = 8.dp, bottom = 2.dp).width(((w - 16.dp) / 4) * minOf(s.length, 4)).height(2.dp).background(track, RoundedCornerShape(2.dp)))
        } else BasicText("${i + 1}", Modifier.padding(start = 8.dp, top = 5.dp), style = LupeType.small.copy(color = if (s.on) Tok.text2Raised else Tok.text2))
        if (s.on && !compact) {
            val size = if (h > 80.dp) 26.sp else if (ed.kind == EditorKind.Drum) 17.sp else 20.sp
            Row(Modifier.align(Alignment.CenterStart).padding(start = 8.dp), verticalAlignment = Alignment.Bottom) {
                BasicText(s.note, style = LupeType.number.copy(fontSize = size, lineHeight = size, color = Tok.text), maxLines = 1)
                if (s.extra > 0) BasicText("+${s.extra}", Modifier.padding(start = 4.dp), style = LupeType.small)
            }
            Box(Modifier.align(Alignment.BottomStart).padding(start = 8.dp, bottom = 7.dp).width(((w - 16.dp) / 4) * minOf(s.length, 4)).height(3.dp).background(track, RoundedCornerShape(2.dp)))
        }
    }
}

// ---- the step panel

@Composable
private fun StepPanel(ed: EditorState, track: Color, core: LupeCore, tab: PanelTab, setTab: (PanelTab) -> Unit, pick: StepPick) {
    val s = ed.steps.getOrNull(ed.selected) ?: Step()
    val n = ed.selected + 1
    var confirm by remember { mutableStateOf(false) }
    var armedAt by remember { mutableStateOf(0L) }
    val lockedCount = s.values.count { it.locked }
    // leaving the SOUND tab, or the step, closes a pending confirm
    if (confirm && (tab != PanelTab.Sound || lockedCount == 0)) confirm = false
    Column(Modifier.fillMaxWidth().height(STRIP_HEIGHT)) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            // "Step 6 ✕": the way back to the sound knobs (also: tap the step again, or the FM-1 changes page)
            Key({ if (ed.lock == LockMode.Latched) core.send(Intent.LockToggle); pick.step = null }, "Step $n: close and show the sound knobs", width = 72.dp, height = 28.dp, minTarget = 32.dp) { fg ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    KeyLabel("Step $n", fg, style = LupeType.key.copy(fontSize = 13.sp))
                    Canvas(Modifier.size(9.dp)) { val w = 1.5.dp.toPx(); drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), w, StrokeCap.Round); drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), w, StrokeCap.Round) }
                }
            }
            Spacer(Modifier.width(8.dp))
            Key({ val to = Math.floorMod(ed.selected - 1, 16); pick.step = to; core.send(Intent.StepSelect(to)) }, "Previous step", width = 28.dp, height = 28.dp, minTarget = 32.dp) { fg -> Chevron90(fg, true) }
            Spacer(Modifier.width(4.dp))
            Key({ val to = Math.floorMod(ed.selected + 1, 16); pick.step = to; core.send(Intent.StepSelect(to)) }, "Next step", width = 28.dp, height = 28.dp, minTarget = 32.dp) { fg -> Chevron90(fg, false) }
            Spacer(Modifier.width(10.dp))
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
            when {
                t == PanelTab.Notes -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
                    SlideColumn(if (ed.kind == EditorKind.Drum) "LANE" else "PITCH", if (s.on) s.pitchText else "—", "Pitch", track, key = "pitch" to ed.selected,
                        dpPerStep = 16f, tick = false, locked = s.isLocked("PITCH")) { send(StepField.Pitch, it) }
                    // MOVE follows the step, so its undo spans the selection changing
                    SlideColumn("MOVE", "$n", "Move", track, key = "move" to ed.pattern, num = n, min = 1, max = 16,
                        dpPerStep = 22f, tick = true, locked = false) { send(StepField.Move, it) }
                    // LENGTH grows only up to the next note (the core's maxLength): at the limit the slide stops and says where
                    val cap = s.maxLength.coerceIn(1, 16)
                    val nextNote = ed.selected + 1 + cap
                    SlideColumn("LENGTH", "${s.length}", "Length", track, key = "length" to ed.selected, num = s.length, min = 1, max = cap,
                        dpPerStep = 16f, tick = false, locked = s.isLocked("LENGTH"),
                        limitWord = if (s.length >= cap) (if (nextNote > 16) "pattern ends" else "note at step $nextNote") else null) { send(StepField.Length, it) }
                    SlideColumn("VELOCITY", "${s.velocity}", "Velocity", track, key = "velocity" to ed.selected, num = s.velocity, min = 1, max = 127, unit = 4,
                        dpPerStep = 3f, tick = false, locked = s.isLocked("VELOCITY")) { send(StepField.Velocity, it) }
                }
                t == PanelTab.Feel -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
                    SlideColumn("CHANCE", "${s.chance}%", "Chance", track, key = "chance" to ed.selected, num = s.chance, min = 0, max = 100, unit = 5,
                        dpPerStep = 4f, tick = false, locked = s.isLocked("CHANCE")) { send(StepField.Chance, it) }
                    SlideColumn("RATCHET", "${s.ratchet}", "Ratchet", track, key = "ratchet" to ed.selected, num = s.ratchet, min = 1, max = 4,
                        dpPerStep = 28f, tick = true, locked = s.isLocked("RATCHET")) { send(StepField.Ratchet, it) }
                    // COND is a list: each step through it ticks
                    SlideColumn("COND", s.cond, "Condition", track, key = "cond" to ed.selected,
                        dpPerStep = 26f, tick = true, locked = s.isLocked("COND")) { send(StepField.Cond, it) }
                    SlideColumn("NUDGE", "${s.nudge}", "Nudge", track, key = "nudge" to ed.selected, num = s.nudge, min = -12, max = 12, bipolar = true,
                        dpPerStep = 12f, tick = false, locked = s.isLocked("NUDGE")) { send(StepField.Nudge, it) }
                }
                c -> Column {
                    val names = s.values.filter { it.locked }.joinToString(", ") { it.param }
                    ConfirmBox("Clear ${if (lockedCount == 1) "the lock" else "both locks".takeIf { lockedCount == 2 } ?: "all $lockedCount locks"} on step $n ($names)",
                        "Confirm: clear $lockedCount lock${if (lockedCount == 1) "" else "s"} on step $n: $names", armedAt, Modifier.padding(horizontal = 0.dp)) { core.send(Intent.LocksClearAll(ed.selected)); confirm = false }
                    Spacer(Modifier.height(2.dp))
                    WideKey("Cancel", { confirm = false })
                }
                else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                    if (s.values.isEmpty()) BasicText("No locks on this step. Hold it and turn a knob on the FM-1, or latch Lock.", Modifier.padding(top = 6.dp), style = LupeType.body.copy(fontSize = 14.sp))
                    s.values.forEach { v -> LockRow(v.param, v.value, v.locked, track) { core.send(Intent.LockClear(ed.selected, v.param)) } }
                }
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
    Row(Modifier.width(186.dp).height(28.dp).background(Tok.well, RoundedCornerShape(8.dp)).selectableGroup().padding(2.dp)) {
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

// ---- one automation lane, for bottom full

@Composable
private fun AutoLane(ed: EditorState, auto: com.scottgerstl.lupe.core.AutomationState, track: Color, core: LupeCore, onDraw: () -> Unit, modifier: Modifier) {
    var open by remember { mutableStateOf(false) }
    val page by core.page.collectAsStateWithLifecycle()
    val params = com.scottgerstl.lupe.ui.automation.automationParams(auto, page)
    Column(modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            Box {
                Key({ open = true }, if (auto.lane.isEmpty()) "Pick a parameter to automate" else "Automation lane ${auto.lane}. Pick another", width = 140.dp, height = 28.dp, minTarget = 32.dp) { fg ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel(auto.lane.ifEmpty { "Pick a parameter" }, fg, style = LupeType.key.copy(fontSize = 13.sp)); Chevron(fg) }
                }
                LupeMenu(open, { open = false }) {
                    MenuHeading("Lane")
                    params.forEach { l -> MenuRow(l, { core.send(com.scottgerstl.lupe.core.AutomationLanePick(l)); open = false }, checked = l == auto.lane) }
                    if (params.isEmpty()) BasicText("Open a sound page on the FM-1: its knobs are the parameters to draw.", Modifier.padding(horizontal = 16.dp, vertical = 8.dp), style = LupeType.small)
                }
            }
            Spacer(Modifier.width(6.dp))
            Key(onDraw, "Draw on the lane: opens it full size", width = 64.dp, height = 28.dp, minTarget = 32.dp, enabled = auto.lane.isNotEmpty()) { fg -> KeyLabel("Draw", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            Spacer(Modifier.weight(1f))
            BasicText(if (auto.lane.isEmpty()) "Pick a parameter, then Draw" else "${auto.lanes.indexOfFirst { it.param == auto.lane } + 1} of ${auto.lanes.size} lanes · ◆ = a lock", style = LupeType.small, maxLines = 1)
        }
        Spacer(Modifier.height(4.dp))
        Canvas(Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(8.dp)).background(Tok.well)
            .semantics { contentDescription = "Lane ${auto.lane} across the ${auto.points.size} steps" + auto.points.filter { it.source == "lock" }.joinToString("") { ", locked on step ${it.step + 1}" } }) {
            val pad = 12.dp.toPx(); val vp = 10.dp.toPx()
            val vals = auto.points.map { if (auto.max > auto.min) ((it.value - auto.min) * 100f / (auto.max - auto.min)).toInt().coerceIn(0, 100) else 0 }.ifEmpty { return@Canvas }
            fun x(i: Int) = pad + i * (size.width - 2 * pad) / (vals.size - 1)
            fun y(v: Int) = size.height - vp - (v / 100f) * (size.height - 2 * vp)
            val line = Path().apply { vals.forEachIndexed { i, v -> if (i == 0) moveTo(x(i), y(v)) else lineTo(x(i), y(v)) } }
            if (ed.playhead >= 0) drawLine(Tok.text3, Offset(x(ed.playhead), 0f), Offset(x(ed.playhead), size.height), 1.dp.toPx())
            drawPath(line, track, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            auto.points.forEach { p -> if (p.source == "lock") diamond(Tok.text, x(p.step), y(vals[p.step]), 4.dp.toPx()) }
        }
    }
}

private fun Step.isLocked(param: String) = values.any { it.locked && it.param == param }

/**
 * One of the step panel's values (the iPad's column: label, value, a gauge at the foot, a white bar along the top
 * while it slides). It turns by sliding on it, in the direction the setting says; the Magnifier floats the value
 * above the finger; a double tap puts it back to what it was when this step was selected ([key] says what "this"
 * is). [dpPerStep] is how far a finger moves for one step; a list ([tick]) ticks on each step. TalkBack gets
 * Increase and Decrease, the range, and Put back. [onSteps] gets a change in steps, never an absolute value.
 */
@Composable
private fun SlideColumn(
    label: String, value: String, name: String, tint: Color, key: Any, dpPerStep: Float, tick: Boolean, locked: Boolean,
    num: Int? = null, min: Int = 0, max: Int = 0, bipolar: Boolean = false, unit: Int = 1, limitWord: String? = null, onSteps: (Int) -> Unit,
) {
    val haptic = LocalHapticFeedback.current
    val send by rememberUpdatedState(onSteps)
    var net by remember(key) { mutableStateOf(0) }       // steps applied since this step was selected, for the double tap
    var last by remember { mutableStateOf(0) }
    var hot by remember { mutableStateOf(false) }
    val hotF = animatedFloat(if (hot) 1f else 0f, Dur.STATE)
    val fraction = if (num != null && max > min) (num - min).toFloat() / (max - min) else null
    val shown by rememberUpdatedState(value)
    val frac by rememberUpdatedState(fraction)
    fun step(d: Int) { if (d == 0) return; net += d; send(d); if (tick) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
    val range = if (num != null) ", range $min to $max" else ""
    Box(
        Modifier.width(96.dp).height(84.dp)
            .clip(RoundedCornerShape(6.dp)).background(Tok.well)
            .semantics(mergeDescendants = true) {
                contentDescription = name + if (locked) ", locked on this step" else ""
                stateDescription = value + range + (limitWord?.let { ", can't grow: $it" } ?: "")
                role = Role.Button
                if (num != null) {
                    progressBarRangeInfo = ProgressBarRangeInfo(num.toFloat(), min.toFloat()..max.toFloat(), max - min - 1)
                    // one step is `unit` of the value (VELOCITY 4, CHANCE 5: StepAdjust's units, P1's 9533897)
                    setProgress { v -> step((v.roundToInt() - num) / unit); true }
                }
                customActions = listOf(
                    CustomAccessibilityAction("Increase $name") { step(1); true },
                    CustomAccessibilityAction("Decrease $name") { step(-1); true },
                    CustomAccessibilityAction("Put $name back as it was") { val b = -net; net = 0; send(b); true },
                )
            }
            // double tap: back to what it was when this step was selected
            .pointerInput(key) { detectTapGestures(onDoubleTap = { val b = -net; net = 0; if (b != 0) { send(b); haptic.performHapticFeedback(HapticFeedbackType.Confirm) } }) }
            .slideToTurn(
                enabled = true, stepDp = dpPerStep,
                face = remember(label, tint) { MagnifierFace(label, { shown }, { frac }, bipolar, ring = false, tint = tint) },
                onStart = { last = 0; hot = true },
                onSlide = { total -> step(total - last); last = total },
                onEnd = { hot = false },
                // the slide stops at the value's ends (LENGTH: the next note), with a tick as it meets the limit
                bounds = { num?.let { n -> -((n - min) / unit)..((max - n) / unit) } },
                onLimit = { haptic.performHapticFeedback(HapticFeedbackType.ContextClick) },
            ),
    ) {
        Column(Modifier.padding(start = 10.dp, end = 10.dp, top = 9.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                BasicText(label, style = LupeType.label.copy(fontFamily = LupeType.number.fontFamily, letterSpacing = 0.5.sp, color = Tok.text2), maxLines = 1)
                if (locked) Diamond(Tok.text, 6.dp)
            }
            BasicText(value, Modifier.padding(top = 2.dp), style = LupeType.number.copy(fontSize = 22.sp, lineHeight = 26.sp), maxLines = 1,
                autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 14.sp, maxFontSize = 22.sp, stepSize = 1.sp))
            // the short hint ("note at step 7") shrinks to fit the column rather than being cut off
            if (limitWord != null) BasicText(limitWord, style = LupeType.small.copy(fontSize = 11.sp, lineHeight = 12.sp), maxLines = 1,
                autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 9.sp, maxFontSize = 11.sp, stepSize = 0.5.sp))
        }
        // the gauge along the foot: from the left, or from the middle on a value centred on zero
        if (fraction != null) Canvas(Modifier.align(Alignment.BottomStart).fillMaxWidth().height(3.dp)) {
            drawRect(Tok.stepEmpty)
            val x = fraction.coerceIn(0f, 1f) * size.width; val from = if (bipolar) size.width / 2 else 0f
            drawRect(tint, Offset(minOf(from, x), 0f), Size(maxOf(kotlin.math.abs(x - from), if (bipolar) 2f else 0f), size.height))
        }
        // sliding (here or on the FM-1): a white bar along the top, the column as it is
        Box(Modifier.align(Alignment.TopStart).fillMaxWidth().height(3.dp).graphicsLayer { alpha = hotF.value }.background(Tok.text))
    }
}

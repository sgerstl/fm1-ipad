package com.scottgerstl.lupe.ui.shell

import androidx.compose.ui.layout.onGloballyPositioned
import com.scottgerstl.lupe.core.SetPatternSteps
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.unit.IntOffset
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
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
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

private enum class PanelTab(val label: String) { Notes("NOTES"), Feel("FEEL"), Sound("SOUND") }

/**
 * Which step the person has picked, or none (decision 21): with none, no step shows a ring and the dials area is HOME's
 * four sound knobs; a tap picks a step and the dials become its controls. Kept above the tabs so it survives a visit to Pads. OPEN, left to Scott: it stays picked when the pattern changes.
 */
class StepPick { var step by mutableStateOf<Int?>(null) }

/** What the Edit tab keeps while you visit the other tabs: the Lane view under the grid, and whether the step panel is latched. */
class EditUi {
    var lane by mutableStateOf(false)
    var octave by mutableStateOf(4)
    /** The step panel is latched open (the Step key): it docks at the grid's right while a step is picked. */
    var stepPanel by mutableStateOf(false)
}

private val PANEL_H = 110.dp      // the step panel: a 32 dp header row, 4, the dials (74)
private val KIT_PANEL_H = 76.dp   // a kit's: one row (the picked hit's boxes, or the dials alone), so the lanes keep their height
private val DIALS_W = 420.dp      // the dials area, at the right; the keyboard, lane or tiles take the rest

/** The docked panels' width (the step panel here, the shell's sound panel): four 84 dp dials and their padding, about two fifths of the phone. */
val DOCK_W = 360.dp

/**
 * The Edit tab (decisions 31 and 35, board 75): the ruler, then the pattern as the iPhone's step grid: a melodic track's piano roll
 * with a piano down its left edge (ui/edit/StepGrid), a kit's lanes by steps. The grid takes the whole width. The step panel (the
 * Step key) docks over the grid's right side; so does the shell's sound panel, which passes how much it covers in [soundDock]. The grid
 * keeps its step width and scrolls under whichever is there, with an indicator. With Lane on, the one-lane view sits under the grid.
 */
@Composable
fun EditTab(
    ed: EditorState, core: LupeCore, auto: com.scottgerstl.lupe.core.AutomationState, pick: StepPick, ui: EditUi, modifier: Modifier = Modifier,
    /** How much of the right side the shell's docked sound panel covers now (it animates). */
    soundDock: Dp = 0.dp,
) {
    var tab by rememberSaveable { mutableStateOf(PanelTab.Notes) }
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    if (ed.steps.isEmpty()) { Placeholder("No pattern", "Pick a pad on the Pads tab: hold it, then Edit steps", modifier); return }
    val drum = ed.kind == EditorKind.Drum
    val reduce = LocalReduceMotion.current
    val top by core.top.collectAsStateWithLifecycle()
    // a kit's picked hit: the lane and the step (the step is also the core's selected step, so its values follow)
    var hit by remember(ed.track, ed.pattern) { mutableStateOf<Pair<String, Int>?>(null) }
    val stepPicked = if (drum) hit != null else pick.step != null
    // the step panel: docked while Step is latched and something is picked; the shell's sound panel stands in front of it
    val panelOpen = ui.stepPanel && stepPicked
    val panelT = animatedFloat(if (panelOpen) 1f else 0f, if (panelOpen) Dur.PANEL else Dur.FINGER)
    val dock = maxOf(DOCK_W * panelT.value, soundDock)
    Column(modifier.fillMaxSize()) {
        Ruler(ed, track, core, stepPicked) {
            if (!drum) {
                Key({ core.send(Intent.ChordToggle) }, "Chord", width = 64.dp, height = 28.dp, minTarget = 32.dp, on = ed.chord, role = Role.Switch,
                    state = if (ed.chord) "On: a tap adds a note to the step, up to ${ed.maxNotes}" else "Off: a tap replaces the step's note") { fg -> KeyLabel("Chord", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
                Spacer(Modifier.width(6.dp))
                LaneKey(ui)
                Spacer(Modifier.width(6.dp))
            }
            StepsKey(ed, track, core)
            Spacer(Modifier.width(6.dp))
            // "Step 6": latches the step panel. With nothing picked it picks the core's selected step (a kit: hold a cell first).
            val n = (if (drum) hit?.second else pick.step) ?: ed.selected
            Key({
                if (panelOpen) ui.stepPanel = false
                else { if (!drum && pick.step == null) { pick.step = ed.selected; core.send(Intent.StepSelect(ed.selected)) }; ui.stepPanel = true }
            }, "Step ${n + 1} panel", width = 72.dp, height = 28.dp, minTarget = 32.dp, on = panelOpen, role = Role.Switch, enabled = !drum || hit != null,
                state = when { panelOpen -> "Open"; drum && hit == null -> "Hold a cell to pick a hit first"; else -> "Closed" }) { fg -> KeyLabel("Step ${n + 1}", fg, style = LupeType.key.copy(fontSize = 13.sp)) }
            Spacer(Modifier.width(6.dp))
        }
        Spacer(Modifier.height(4.dp))
        // the track thread rests round the pattern (the tab-thread mockup): the selected track's outline in its colour; while the tabs slide the
        // travelling one stands in for it
        val travelling = LocalTabTravelling.current
        Box(Modifier.weight(1f).fillMaxWidth().selectedTrackAnchor(outset = 4.dp).drawBehind {
            if (!travelling) drawRoundRect(track, Offset(-3.dp.toPx(), -3.dp.toPx()), Size(size.width + 6.dp.toPx(), size.height + 6.dp.toPx()), CornerRadius(11.dp.toPx()), style = Stroke(2.dp.toPx()))
        }) {
            Column(Modifier.fillMaxSize()) {
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    if (drum) DrumGrid(ed, track, core, hit, dock) { hit = it }
                    else com.scottgerstl.lupe.ui.edit.StepGrid(ed, track, core, pick.step, { pick.step = it }, dock, canPlay = { !(top.rec && top.playing) })
                }
                // the one-lane view (decision 7), under the grid while Lane is on
                if (ui.lane && !drum) {
                    Spacer(Modifier.height(6.dp))
                    com.scottgerstl.lupe.ui.automation.LaneView(ed, auto, core, track, Modifier.fillMaxWidth().height(96.dp))
                }
            }
            // the step panel, docked: it slides in from the right over the grid (with Reduce Motion it only fades)
            if (panelT.value > 0.001f) Box(
                Modifier.align(Alignment.TopEnd).width(DOCK_W).fillMaxHeight()
                    .graphicsLayer { if (reduce) alpha = panelT.value else translationX = (1f - panelT.value) * size.width; shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(12.dp); clip = true }
                    .background(Tok.panel)
                    .pointerInput(Unit) { detectTapGestures { } }      // a touch on the panel doesn't reach the grid under it
                    .semantics { paneTitle = "Step panel"; isTraversalGroup = true }
                    .padding(12.dp),
            ) {
                if (drum) HitPanel(ed, track, core, hit, narrow = true) { hit = null } else StepControls(ed, track, core, tab, { tab = it }, pick, narrow = true)
            }
        }
    }
}

/**
 * STEPS (batch item 9): the pattern's step count, the FM-1's LENGTH knob, 1 to 64. The key shows it ("32 steps") and follows the FM-1's
 * knob (the editor area's patternSteps). A tap opens the hold menu at the key: one more or fewer, and the usual lengths. It is a write:
 * PhoneCore drops it while read-only. The grid scrolls through the steps in chunks of sixteen.
 */
@Composable
private fun StepsKey(ed: EditorState, track: Color, core: LupeCore) {
    val menu = LocalHoldMenu.current
    var coords by remember { mutableStateOf<androidx.compose.ui.layout.LayoutCoordinates?>(null) }
    val n = ed.patternSteps; val max = ed.patternStepsMax
    fun items(): List<HoldItem> = buildList {
        add(HoldItem("One more step", sub = if (n >= max) "The most is $max" else null, enabled = n < max) { core.send(SetPatternSteps(n + 1)) })
        add(HoldItem("One fewer step", sub = if (n <= 1) "The least is 1" else null, enabled = n > 1) { core.send(SetPatternSteps(n - 1)) })
        for (v in listOf(4, 8, 12, 16, 24, 32, 48, 64)) if (v <= max) add(HoldItem("$v steps", checked = v == n) { core.send(SetPatternSteps(v)) })
    }
    Box(Modifier.onGloballyPositioned { coords = it }) {
        Key({ coords?.takeIf { it.isAttached }?.let { c -> menu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), track, items()) } },
            "Pattern length: $n steps", width = 76.dp, height = 28.dp, minTarget = 32.dp, state = "Opens the choices: one more, one fewer, 4 to 64") { fg ->
            KeyLabel("$n steps", fg, style = LupeType.key.copy(fontSize = 13.sp))
        }
    }
}

/** "Lane": shows the one-lane view (decision 7) under the grid, and hides it. */
@Composable
private fun LaneKey(ui: EditUi) =
    Key({ ui.lane = !ui.lane }, "Automation lane", width = 56.dp, height = 28.dp, minTarget = 32.dp, on = ui.lane, role = Role.Switch,
        state = if (ui.lane) "On: the lane is under the grid" else "Off") { fg -> KeyLabel("Lane", fg, style = LupeType.key.copy(fontSize = 13.sp)) }

// ---- ruler and lock banner

@Composable
private fun Ruler(ed: EditorState, track: Color, core: LupeCore, stepPicked: Boolean, keys: @Composable RowScope.() -> Unit = {}) {
    val locking = ed.lock != LockMode.Off
    LupeCrossfade(locking, Modifier.fillMaxWidth().height(32.dp)) { l ->
        if (l) LockBanner(ed, track) else Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f).semantics(mergeDescendants = true) { contentDescription = "Editing track ${ed.track} ${ed.trackName}, entry ${ed.entry}, pattern ${ed.pattern}${if (ed.scale.isNotEmpty()) ", ${ed.scale}" else ""}"; heading() },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.size(10.dp).background(track, RoundedCornerShape(5.dp)))
                BasicText("${ed.track} ${ed.trackName}", style = LupeType.key, maxLines = 1)
                BasicText("· ${ed.entry} · pattern ${"%02d".format(ed.pattern)}" + if (ed.scale.isNotEmpty()) " · ${ed.scale}" else "", style = LupeType.body.copy(fontSize = 14.sp), maxLines = 1)
            }
            keys()
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

// ---- the steps' places across a kit's lanes, in fours

private val GAP_IN = 4.dp      // between steps
private val GAP_BEAT = 12.dp   // between beats: the FM-1's steps and keys run in fours

/** Step [i]'s left edge and the step width, across [w]. */
private fun colX(i: Int, w: Dp): Pair<Dp, Dp> {
    val cw = (w - GAP_IN * 12 - GAP_BEAT * 3) / 16
    return (cw * i + GAP_IN * (i - i / 4) + GAP_BEAT * (i / 4)) to cw
}

/** The notes on a step: the core's MIDI numbers, or (an older recording) what its PITCH text names. */
private fun stepNotes(s: Step): List<Int> = if (!s.on) emptyList() else s.notes.ifEmpty { s.pitchText.ifEmpty { s.note }.split(" ").filter { it.isNotEmpty() }.map { com.scottgerstl.lupe.core.FakeData.parseNote(it) } }

// ---- a kit: lanes by steps

/**
 * A kit (board 73 C): its lanes down, the sixteen steps across in fours. A tap puts a hit on or takes it off; a hold picks the hit without
 * toggling it (white ring; its values show under the grid). The fill's strength is the step's velocity.
 */
@Composable
private fun DrumGrid(ed: EditorState, track: Color, core: LupeCore, hit: Pair<String, Int>?, dock: Dp = 0.dp, onPick: (Pair<String, Int>?) -> Unit) {
    val lanes = ed.kitLanes.ifEmpty { ed.steps.flatMap { it.note.split(" ") }.filter { it.isNotEmpty() }.distinct() }.ifEmpty { listOf("—") }
    val top by core.top.collectAsStateWithLifecycle()
    val haptic = LocalHapticFeedback.current
    val reduce = LocalReduceMotion.current
    val density = LocalDensity.current
    // a docked panel covers the right side: the steps keep their width and scroll under it (decision 35, B); the names stay
    var scrollX by remember { mutableFloatStateOf(0f) }
    var touchedAt by remember { mutableStateOf(0L) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val total = maxOf(ed.patternSteps, ed.steps.size, 1).coerceAtMost(64)
    val totalNow by rememberUpdatedState(total)
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val gap = 3.dp
        val rh = ((maxHeight - gap * (lanes.size - 1)) / lanes.size)
        val labelW = 44.dp
        val gw = maxWidth - labelW
        val viewPx = with(density) { gw.toPx() }; val stepPx = viewPx / 16
        val dockPx by rememberUpdatedState(with(density) { dock.toPx() }.coerceAtMost(viewPx - stepPx * 4))
        val roll = com.scottgerstl.lupe.ui.edit.Roll
        fun sx() = roll.clampScrollX(scrollX, roll.maxScroll(totalNow, viewPx, dockPx))
        suspend fun glide(to: Float) {
            val target = roll.clampScrollX(to, roll.maxScroll(totalNow, viewPx, dockPx))
            if (kotlin.math.abs(target - scrollX) > 0.5f) androidx.compose.animation.core.animate(scrollX, target, animationSpec = androidx.compose.animation.core.tween(if (reduce) 0 else Dur.PANEL, easing = com.scottgerstl.lupe.ui.theme.EaseOut)) { v, _ -> scrollX = v }
        }
        // a panel docking or leaving, the length changing or a hit picked: it comes into view (clear of the panel), else the grid settles on a chunk
        LaunchedEffect(dockPx > 0f, hit?.second, total) { glide(hit?.second?.let { roll.reveal(it, sx(), stepPx, viewPx, dockPx, total) } ?: roll.snap(sx(), total, viewPx, dockPx)) }
        // playing: the playhead's chunk, unless a finger moved the steps in the last two and a half seconds
        LaunchedEffect(ed.playhead, total) {
            if (ed.playhead < 0 || System.currentTimeMillis() - touchedAt < 2500L) return@LaunchedEffect
            roll.follow(ed.playhead, sx(), stepPx, viewPx, dockPx, total)?.let { glide(it) }
        }
        Column(
            Modifier.pointerInput(Unit) {
                detectHorizontalDragGestures(
                    onDragStart = { touchedAt = System.currentTimeMillis() },
                    onDragEnd = { touchedAt = System.currentTimeMillis(); scope.launch { glide(roll.snap(sx(), totalNow, viewPx, dockPx)) } },
                    onDragCancel = { scope.launch { glide(roll.snap(sx(), totalNow, viewPx, dockPx)) } },
                ) { change, dx -> if (totalNow > 16 || dockPx > 0f) { change.consume(); touchedAt = System.currentTimeMillis(); scrollX = roll.clampScrollX(scrollX - dx, roll.maxScroll(totalNow, viewPx, dockPx)) } }
            }
                .drawWithContent {
                    drawContent()
                    // the scroll indicator, while a panel covers part of the steps
                    if (dockPx > 0.5f || total > 16) {
                        val (a, b) = roll.indicator(sx(), stepPx, viewPx, dockPx, total); val x0 = labelW.toPx() + 4.dp.toPx(); val wv = viewPx - dockPx - 8.dp.toPx()
                        drawRoundRect(Tok.control, Offset(x0, size.height - 3.dp.toPx()), Size(wv, 2.dp.toPx()), CornerRadius(1.dp.toPx()))
                        drawRoundRect(Tok.text2Raised, Offset(x0 + a * wv, size.height - 3.dp.toPx()), Size((b - a) * wv, 2.dp.toPx()), CornerRadius(1.dp.toPx()))
                    }
                },
            verticalArrangement = Arrangement.spacedBy(gap),
        ) {
            lanes.forEachIndexed { k, lane ->
                Box(Modifier.fillMaxWidth().height(rh).clipToBounds()) {
                    for (i in 0 until total) {
                        val s = ed.steps.getOrNull(i) ?: Step()
                        val on = s.on && (if (s.hits.isNotEmpty()) s.hits.any { it.lane == k } else lane in s.note.split(" "))
                        val picked = hit?.first == lane && hit.second == i
                        val (x0, cw) = colX(i % 16, gw); val x = x0 + gw * (i / 16)
                        val onF = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                        val sel = animatedFloat(if (picked) 1f else 0f, Dur.STATE)
                        val fill = lerp(Tok.page, track, (30 + s.velocity / 127f * 60) / 100f)
                        Box(
                            Modifier.offset(x = labelW + x).offset { IntOffset(-sx().toInt(), 0) }.width(cw).fillMaxHeight()
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
                    // the lane's name, over the cells that scroll under it: it plays the lane while pressed (not while recording: the FM-1 would
                    // record it)
                    BasicText(lane, Modifier.align(Alignment.CenterStart).width(labelW).fillMaxHeight().background(Tok.page).wrapContentHeight().padding(end = 4.dp)
                        .semantics { role = Role.Button; contentDescription = "Play $lane" }
                        .pointerInput(k) { detectTapGestures(onPress = { if (!(top.rec && top.playing)) { core.send(PlayNote(lane = k, on = true)); tryAwaitRelease(); core.send(PlayNote(lane = k, on = false)) } }) }, style = LupeType.label.copy(fontSize = 13.sp, color = if (hit?.first == lane) Tok.text else Tok.text2Raised), maxLines = 1)
                }
            }
        }
    }
}

/** The picked hit's values in boxes (a kit has more than four per hit, so boxes, not dials), under a "SD · step 5 ✕" key: one row, or docked ([narrow]) two rows of three. */
@Composable
private fun HitPanel(ed: EditorState, track: Color, core: LupeCore, hit: Pair<String, Int>?, narrow: Boolean = false, onClose: () -> Unit) {
    val (lane, step) = hit ?: return
    val s = ed.steps.getOrNull(step) ?: Step()
    val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
    val close: @Composable () -> Unit = {
        Key(onClose, "$lane, step ${step + 1}: close", width = 112.dp, height = 28.dp, minTarget = 44.dp) { fg ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel("$lane · step ${step + 1}", fg, style = LupeType.key.copy(fontSize = 13.sp)); Cross(fg) }
        }
    }
    val boxes: List<@Composable (Modifier) -> Unit> = listOf(
        { m -> ValueBox("VELOCITY", "${s.velocity}", "Velocity", track, "velocity" to step, 3f, false, s.velocity, 1, 127, unit = 4, modifier = m) { send(StepField.Velocity, it) } },
        { m -> ValueBox("CHANCE", "${s.chance}%", "Chance", track, "chance" to step, 4f, false, s.chance, 0, 100, unit = 5, modifier = m) { send(StepField.Chance, it) } },
        { m -> ValueBox("RATCHET", "×${s.ratchet}", "Ratchet", track, "ratchet" to step, 28f, true, s.ratchet, 1, 4, modifier = m) { send(StepField.Ratchet, it) } },
        { m -> ValueBox("NUDGE", "${s.nudge}", "Nudge", track, "nudge" to step, 12f, false, s.nudge, -12, 12, bipolar = true, modifier = m) { send(StepField.Nudge, it) } },
        // the lane's own PITCH and DECAY: the editor area doesn't carry a lane's sound yet, so they show and say so (P1)
        { m -> ValueBox("PITCH", "—", "Lane pitch, not available yet", track, "lp" to lane, 12f, false, null, enabled = false, modifier = m) { } },
        { m -> ValueBox("DECAY", "—", "Lane decay, not available yet", track, "ld" to lane, 12f, false, null, enabled = false, modifier = m) { } },
    )
    if (narrow) Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        close()
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) { boxes.take(3).forEach { it(Modifier.weight(1f)) } }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) { boxes.drop(3).forEach { it(Modifier.weight(1f)) } }
    } else Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        close()
        boxes.forEach { it(Modifier.weight(1f)) }
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
private fun StepControls(ed: EditorState, track: Color, core: LupeCore, tab: PanelTab, setTab: (PanelTab) -> Unit, pick: StepPick, narrow: Boolean = false) {
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
            if (!narrow) { Spacer(Modifier.width(6.dp)); PanelTabs(tab, setTab) }
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
        // docked (narrow): NOTES · FEEL · SOUND on a row of their own
        if (narrow) { Spacer(Modifier.height(4.dp)); Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) { PanelTabs(tab, setTab) } }
        Spacer(Modifier.height(if (narrow) 8.dp else 4.dp))
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

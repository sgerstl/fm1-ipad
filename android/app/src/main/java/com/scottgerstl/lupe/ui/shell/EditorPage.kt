package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
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
 * The editor in the bottom half (boards 53, 54 and 56): the ruler (or the lock banner), the 4 × 4 step grid, one
 * automation lane when there is room (bottom full), and the step panel in the strip under the grid. Notes go in
 * from the FM-1's keys only, so there is no piano. [autoFraction] is 0..1: how much of the lane fits.
 */
@Composable
fun EditorPage(ed: EditorState, core: LupeCore, autoFraction: Float, modifier: Modifier = Modifier) {
    var tab by rememberSaveable { mutableStateOf(PanelTab.Notes) }
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    if (ed.steps.isEmpty()) { Placeholder("No pattern", "Pick a pad: hold it, then Edit steps", modifier); return }
    Column(modifier.fillMaxSize()) {
        Ruler(ed, track, core)
        Spacer(Modifier.height(0.dp))
        Grid(ed, track, core, Modifier.weight(1f).padding(top = 0.dp))
        // the core sends no lanes until MOTION is read (P1's recordings): then there is no lane to show
        if (autoFraction > 0.02f && ed.lanes.isNotEmpty()) {
            Spacer(Modifier.height(12.dp * autoFraction))
            AutoLane(ed, track, core, Modifier.height(150.dp * autoFraction).graphicsLayer { alpha = autoFraction })
        }
        Spacer(Modifier.height(12.dp))
        StepPanel(ed, track, core, tab, { tab = it })
    }
}

// ---- ruler and lock banner

@Composable
private fun Ruler(ed: EditorState, track: Color, core: LupeCore) {
    val locking = ed.lock != LockMode.Off
    LupeCrossfade(locking, Modifier.fillMaxWidth().height(40.dp)) { l ->
        if (l) LockBanner(ed, track) else Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f).semantics(mergeDescendants = true) { contentDescription = "Editing track ${ed.track} ${ed.trackName}, entry ${ed.entry}, pattern ${ed.pattern}${if (ed.scale.isNotEmpty()) ", ${ed.scale}" else ""}"; heading() },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.size(10.dp).background(track, RoundedCornerShape(5.dp)))
                BasicText("${ed.track} ${ed.trackName}", style = LupeType.key, maxLines = 1)
                BasicText("· ${ed.entry} · pattern ${"%02d".format(ed.pattern)}" + if (ed.scale.isNotEmpty()) " · ${ed.scale}" else "", style = LupeType.body.copy(fontSize = 14.sp), maxLines = 1)
            }
            if (ed.kind == EditorKind.Roll) {
                Key({ core.send(Intent.ChordToggle) }, "Chord", width = 66.dp, height = 32.dp, minTarget = 40.dp, on = ed.chord, role = Role.Switch,
                    state = if (ed.chord) "On: a second FM-1 key adds to the step's chord" else "Off") { fg -> KeyLabel("Chord", fg) }
                Spacer(Modifier.width(6.dp))
            }
            StepMenuKey(ed, core)
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

private fun DrawScope.diamond(color: Color, cx: Float, cy: Float, r: Float) =
    drawPath(Path().apply { moveTo(cx, cy - r * 1.2f); lineTo(cx + r * 1.2f, cy); lineTo(cx, cy + r * 1.2f); lineTo(cx - r * 1.2f, cy); close() }, color)

private enum class StepMenuMode { Root, ClearConfirm }

@Composable
private fun StepMenuKey(ed: EditorState, core: LupeCore) {
    var open by remember { mutableStateOf(false) }
    var mode by remember { mutableStateOf(StepMenuMode.Root) }
    var armedAt by remember { mutableStateOf(0L) }
    val n = ed.selected + 1
    val step = ed.steps.getOrNull(ed.selected)
    Box {
        Key({ open = true; mode = StepMenuMode.Root }, "Step menu", width = 64.dp, height = 32.dp, minTarget = 40.dp) { fg ->
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
                            MenuRow("Paste step", { core.send(Intent.StepAction(ed.selected, StepActionKind.Paste)); open = false })
                            MenuRow("Clear step", { mode = StepMenuMode.ClearConfirm; armedAt = System.currentTimeMillis() }, enabled = step?.on == true)
                        }
                        StepMenuMode.ClearConfirm -> {
                            val goes = buildString {
                                append(step?.note.orEmpty().ifEmpty { "the step" })
                                val l = step?.values?.count { it.locked } ?: 0
                                if (l > 0) append(" and its $l lock${if (l == 1) "" else "s"}")
                            }
                            ConfirmBox("Clear step $n, removing $goes", "Confirm: clear step $n, removing $goes", armedAt) { core.send(Intent.StepAction(ed.selected, StepActionKind.Clear)); open = false }
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
private fun Grid(ed: EditorState, track: Color, core: LupeCore, modifier: Modifier) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val gap = 4.dp
        val cw = (maxWidth - gap * 3) / 4
        val ch = ((maxHeight - gap * 3) / 4).coerceAtLeast(20.dp)
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            for (r in 0 until 4) Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (c in 0 until 4) {
                    val i = r * 4 + c
                    StepCell(i, ed.steps.getOrNull(i) ?: Step(), ed, track, cw, ch, core)
                }
            }
        }
    }
}

@Composable
private fun StepCell(i: Int, s: Step, ed: EditorState, track: Color, w: Dp, h: Dp, core: LupeCore) {
    val selected = ed.selected == i
    val held = ed.lock == LockMode.Held && selected
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
                onClick { core.send(Intent.StepSelect(i)); true }
                customActions = listOf(
                    CustomAccessibilityAction("Lock knob turns to this step") { core.send(Intent.StepSelect(i)); core.send(Intent.LockToggle); true },
                    CustomAccessibilityAction("Copy step") { core.send(Intent.StepAction(i, StepActionKind.Copy)); true },
                )
            }
            // tap: select. Hold: lock mode for as long as the finger stays down (the FM-1's own gesture).
            .pointerInput(i) {
                awaitEachGesture {
                    awaitFirstDown()
                    val up = withTimeoutOrNull(longPress) { waitForUpOrCancellation() }
                    if (up != null) core.send(Intent.StepSelect(i))
                    else {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        core.send(Intent.StepHold(i, true))
                        waitForUpOrCancellation()
                        core.send(Intent.StepHold(i, false))
                    }
                }
            },
    ) {
        BasicText("${i + 1}", Modifier.padding(start = 8.dp, top = 5.dp), style = LupeType.small.copy(color = if (s.on) Tok.text2Raised else Tok.text2))
        if (s.on) {
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
private fun StepPanel(ed: EditorState, track: Color, core: LupeCore, tab: PanelTab, setTab: (PanelTab) -> Unit) {
    val s = ed.steps.getOrNull(ed.selected) ?: Step()
    val n = ed.selected + 1
    var confirm by remember { mutableStateOf(false) }
    var armedAt by remember { mutableStateOf(0L) }
    val lockedCount = s.values.count { it.locked }
    // leaving the SOUND tab, or the step, closes a pending confirm
    if (confirm && (tab != PanelTab.Sound || lockedCount == 0)) confirm = false
    Column(Modifier.fillMaxWidth().height(122.dp)) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            BasicText("Step $n", Modifier.width(62.dp).semantics { heading() }, style = LupeType.key)
            Key({ core.send(Intent.StepSelect(Math.floorMod(ed.selected - 1, 16))) }, "Previous step", width = 28.dp, height = 28.dp, minTarget = 32.dp) { fg -> Chevron90(fg, true) }
            Spacer(Modifier.width(4.dp))
            Key({ core.send(Intent.StepSelect(Math.floorMod(ed.selected + 1, 16))) }, "Next step", width = 28.dp, height = 28.dp, minTarget = 32.dp) { fg -> Chevron90(fg, false) }
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
                    val pitch = if (s.on) s.pitchText else "—"
                    Stepper(if (ed.kind == EditorKind.Drum) "LANE" else "PITCH", pitch, "Pitch", s, "PITCH", { core.send(Intent.StepAdjust(StepField.Pitch, -1)) }, { core.send(Intent.StepAdjust(StepField.Pitch, 1)) })
                    Stepper("MOVE", "$n", "Move", s, "MOVE", { core.send(Intent.StepAdjust(StepField.Move, -1)) }, { core.send(Intent.StepAdjust(StepField.Move, 1)) })
                    Stepper("LENGTH", "${s.length}", "Length", s, "LENGTH", { core.send(Intent.StepAdjust(StepField.Length, -1)) }, { core.send(Intent.StepAdjust(StepField.Length, 1)) })
                    Stepper("VELOCITY", "${s.velocity}", "Velocity", s, "VELOCITY", { core.send(Intent.StepAdjust(StepField.Velocity, -1)) }, { core.send(Intent.StepAdjust(StepField.Velocity, 1)) })
                }
                t == PanelTab.Feel -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Stepper("CHANCE", "${s.chance}", "Chance", s, "CHANCE", { core.send(Intent.StepAdjust(StepField.Chance, -1)) }, { core.send(Intent.StepAdjust(StepField.Chance, 1)) })
                    Stepper("RATCHET", "${s.ratchet}", "Ratchet", s, "RATCHET", { core.send(Intent.StepAdjust(StepField.Ratchet, -1)) }, { core.send(Intent.StepAdjust(StepField.Ratchet, 1)) })
                    Stepper("COND", s.cond, "Condition", s, "COND", { core.send(Intent.StepAdjust(StepField.Cond, -1)) }, { core.send(Intent.StepAdjust(StepField.Cond, 1)) })
                    Stepper("NUDGE", "${s.nudge}", "Nudge", s, "NUDGE", { core.send(Intent.StepAdjust(StepField.Nudge, -1)) }, { core.send(Intent.StepAdjust(StepField.Nudge, 1)) })
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

/** A value with its − and +: 96 dp wide, the label over the number over two 46 × 36 keys. */
@Composable
private fun Stepper(label: String, value: String, name: String, s: Step, param: String, down: () -> Unit, up: () -> Unit) {
    val locked = s.values.any { it.locked && it.param == param }
    Column(Modifier.width(96.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            BasicText(label, style = LupeType.label.copy(fontFamily = LupeType.number.fontFamily, letterSpacing = 0.5.sp), maxLines = 1)
            if (locked) Diamond(Tok.text, 6.dp)
        }
        BasicText(value, Modifier.height(30.dp).semantics { contentDescription = "$name $value" }, style = LupeType.number.copy(fontSize = 24.sp, lineHeight = 30.sp), maxLines = 1)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Key(down, "$name down", width = 46.dp, height = 36.dp, minTarget = 36.dp) { fg -> BasicText("−", style = LupeType.key.copy(color = fg, fontSize = 18.sp)) }
            Key(up, "$name up", width = 46.dp, height = 36.dp, minTarget = 36.dp) { fg -> BasicText("+", style = LupeType.key.copy(color = fg, fontSize = 18.sp)) }
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
private fun AutoLane(ed: EditorState, track: Color, core: LupeCore, modifier: Modifier) {
    var open by remember { mutableStateOf(false) }
    Column(modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().height(32.dp), verticalAlignment = Alignment.CenterVertically) {
            Box {
                Key({ open = true }, "Automation lane ${ed.lane}, ${ed.lanes.indexOf(ed.lane) + 1} of ${ed.lanes.size}. Pick another", width = 120.dp, height = 28.dp, minTarget = 32.dp) { fg ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel(ed.lane, fg, style = LupeType.key.copy(fontSize = 13.sp)); Chevron(fg) }
                }
                LupeMenu(open, { open = false }) {
                    MenuHeading("Lane")
                    ed.lanes.forEach { l -> MenuRow(l, { core.send(Intent.LanePick(l)); open = false }, checked = l == ed.lane) }
                }
            }
            Spacer(Modifier.weight(1f))
            BasicText("${ed.lanes.indexOf(ed.lane) + 1} of ${ed.lanes.size} lanes · ◆ = a lock", style = LupeType.small, maxLines = 1)
        }
        Spacer(Modifier.height(4.dp))
        Canvas(Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(8.dp)).background(Tok.well)
            .semantics { contentDescription = "Lane ${ed.lane} across the 16 steps" + ed.steps.withIndex().filter { (_, s) -> s.values.any { it.locked && it.param == ed.lane } }.joinToString("") { ", locked on step ${it.index + 1}" } }) {
            val pad = 12.dp.toPx(); val vp = 10.dp.toPx()
            val vals = ed.laneValues.ifEmpty { return@Canvas }
            fun x(i: Int) = pad + i * (size.width - 2 * pad) / (vals.size - 1)
            fun y(v: Int) = size.height - vp - (v / 100f) * (size.height - 2 * vp)
            val line = Path().apply { vals.forEachIndexed { i, v -> if (i == 0) moveTo(x(i), y(v)) else lineTo(x(i), y(v)) } }
            if (ed.playhead >= 0) drawLine(Tok.text3, Offset(x(ed.playhead), 0f), Offset(x(ed.playhead), size.height), 1.dp.toPx())
            drawPath(line, track, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            ed.steps.forEachIndexed { i, s -> if (s.values.any { it.locked && it.param == ed.lane }) diamond(Tok.text, x(i), y(vals[i]), 4.dp.toPx()) }
        }
    }
}

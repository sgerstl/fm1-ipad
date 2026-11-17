package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.gestures.drag

import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.collectIsPressedAsState

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
    /** 8-step pages turn with the playhead (Scott, 2026-11-17: "follows only when Follow is on"). On by default, as `phone-01` draws it. */
    var follow by mutableStateOf(true)
    /**
     * Chord: a tap on another pitch adds a note to the step (up to its maxNotes) instead of replacing it. The phone's own editing mode, kept for
     * the session (Scott, 2026-11-17: "the chord key doesn't work"). It was the core's `chord`, which only the demo core flipped: the real core
     * sends `chord: false` and has no chordToggle, so on the FM-1 the key never turned on.
     */
    var chord by mutableStateOf(false)
}

/** What the grid and the panel see: the editor area with the phone's Chord mode in place of the core's flag. */
internal fun withChord(ed: EditorState, chord: Boolean): EditorState = if (ed.chord == chord) ed else ed.copy(chord = chord)

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
    edArea: EditorState, core: LupeCore, auto: com.scottgerstl.lupe.core.AutomationState, pick: StepPick, ui: EditUi, modifier: Modifier = Modifier,
    /** How much of the right side the shell's docked sound panel covers now (it animates). */
    soundDock: Dp = 0.dp,
) {
    val ed = withChord(edArea, ui.chord)
    var tab by rememberSaveable { mutableStateOf(PanelTab.Notes) }
    val track = Tok.track[(ed.track - 1).coerceAtLeast(0) % Tok.track.size]
    if (ed.steps.isEmpty()) { Placeholder("No pattern", "Pick a pad on the Pads tab: hold it, then Edit steps", modifier); return }
    val drum = ed.kind == EditorKind.Drum
    val reduce = LocalReduceMotion.current
    val top by core.top.collectAsStateWithLifecycle()
    // a kit's picked hit: the lane and the step (the step is also the core's selected step, so its values follow)
    var hit by remember(ed.track, ed.pattern) { mutableStateOf<Pair<String, Int>?>(null) }
    // the first time a kit opens here, once per install: a one-line hint in the app strip; it goes on a timer or at the next touch on the grid
    val phone = com.scottgerstl.lupe.ui.slide.LocalPhoneSettings.current
    val messages = LocalMessages.current
    var hintId by remember { mutableStateOf<Long?>(null) }
    LaunchedEffect(drum) { if (drum && !phone.kitHintShown) { messages.post(MessageKind.Confirmation, "Hold a hit to edit it"); hintId = messages.current?.id; phone.markKitHintShown() } }
    val stepPicked = if (drum) hit != null else pick.step != null
    // the step panel: docked while Step is latched and something is picked; the shell's sound panel stands in front of it
    val panelOpen = ui.stepPanel && stepPicked
    val panelT = animatedFloat(if (panelOpen) 1f else 0f, if (panelOpen) Dur.PANEL else Dur.FINGER)
    val dock = maxOf(DOCK_W * panelT.value, soundDock)
    // the FM-1's knobs drive the picked step (Edit redesign, Scott 2026-11-17; the iPad's SeqCursor, both ways). Skiff 2.5.1: on SEQ › NOTES knobs
    // 1–4 are PITCH START LENGTH VELOCITY of the step under the FM-1's cursor, on FEEL CHANCE RATCHET NUDGE TYPE; its PRESETS encoder moves the cursor.
    val screen by core.fm1Screen.collectAsStateWithLifecycle()
    val screenNow by rememberUpdatedState(screen)
    val linkState by core.link.collectAsStateWithLifecycle()
    val linked = linkState.phase == com.scottgerstl.lupe.core.LinkPhase.Ready
    // the FM-1 to the phone: its cursor is the picked step; the step panel opens on the matching tab; the grid pages to it (the reveal does that)
    LaunchedEffect(screen.key, screen.page, screen.cursor) {
        if (drum || screen.key != "SEQ" || (screen.page != 41 && screen.page != 42)) return@LaunchedEffect
        val c = screen.cursor ?: return@LaunchedEffect
        val want = if (screen.page == 42) PanelTab.Feel else PanelTab.Notes
        if (tab != want && tab != PanelTab.Sound) tab = want
        if (!ui.stepPanel) ui.stepPanel = true
        if (pick.step != c) { pick.step = c; core.send(Intent.StepSelect(c)) }
    }
    // the phone to the FM-1: a step picked with the panel open on Notes or Feel puts the FM-1 on that page with its cursor there (screenGoto's cursor,
    // the core's showOnDevice(page:cursor:)); nothing is sent when it is already there, so the two don't echo. Knob turns are the FM-1's own: no StepAdjust.
    val hitNow by rememberUpdatedState(hit)
    LaunchedEffect(panelOpen, pick.step, hit, tab, linked) {
        if (!panelOpen || !linked || (!drum && tab == PanelTab.Sound)) return@LaunchedEffect
        // a kit (2026-11-18): its NOTES page is the FM-1's drum grid, the cursor its step (Skiff 2.5.1 grid_edit); its LANE knob keeps its own lane
        val st = (if (drum) hitNow?.second else pick.step) ?: return@LaunchedEffect
        kotlinx.coroutines.delay(120)
        val pg = if (!drum && tab == PanelTab.Feel) 42 else 41
        val now = screenNow
        if (now.key == "SEQ" && now.page == pg && now.cursor == st) return@LaunchedEffect
        core.send(com.scottgerstl.lupe.core.ScreenGoto("SEQ", pg, cursor = st))
    }
    // a panel docked: a melodic grid shows 8 steps a page beside it (hybrid UI, Scott 2026-11-17), and the pattern bar spans the width left of it.
    // A kit's lanes keep scrolling under it (decision 35, B) until the drum grid gets pages too.
    // round 5: a kit pages by 8 too (`build-gaps-2026-11-17/1-drum-edit-docked.png`)
    val paged = panelOpen || soundDock > 0.dp
    val beside = if (paged) dock + 8.dp * (dock / DOCK_W).coerceIn(0f, 1f) else 0.dp
    Box(modifier.fillMaxSize()) {
    Column(Modifier.fillMaxSize().padding(end = beside)) {
        Ruler(ed, track, core, stepPicked) {
            // the pattern bar (Edit redesign, Scott 2026-11-17): keys 40 tall; the step menu moved into the step panel's header (⋯)
            if (!drum) {
                ToggleKey("Chord", ed.chord, "Chord", if (ed.chord) "On: a tap adds a note to the step, up to ${ed.maxNotes}" else "Off: a tap replaces the step's note") { ui.chord = !ui.chord }
                Spacer(Modifier.width(6.dp))
                ToggleKey("Lane", ui.lane, "Automation lane", if (ui.lane) "On: the lane is under the grid" else "Off") { ui.lane = !ui.lane }
                Spacer(Modifier.width(6.dp))
            }
            StepsKey(ed, track, core)
            Spacer(Modifier.width(6.dp))
            // Follow: only where the grid pages by 8 (a 16-step grid follows as built); on, it is the white key
            if (paged) {
                ToggleKey("Follow", ui.follow, "Follow the playhead", if (ui.follow) "On: the page turns with the playhead" else "Off: turn pages by hand; the minimap shows the playhead") { ui.follow = !ui.follow }
                Spacer(Modifier.width(6.dp))
            }
            // "Step 6 ⌄": opens and closes the step panel. With nothing picked it picks the core's selected step (a kit: hold a cell first).
            val n = (if (drum) hit?.second else pick.step) ?: ed.selected
            Key({
                if (panelOpen) ui.stepPanel = false
                else {
                    if (!drum && pick.step == null) { pick.step = ed.selected; core.send(Intent.StepSelect(ed.selected)) }
                    // a kit: the last picked hit, else the pattern's first hit (Scott, 2026-11-18: the key no longer waits for a hold)
                    if (drum && hit == null) firstHit(ed)?.let { hit = it; core.send(Intent.StepSelect(it.second)) }
                    ui.stepPanel = true
                }
            }, "Step ${n + 1} panel", width = 96.dp, height = 40.dp, minTarget = 44.dp, on = panelOpen, role = Role.Switch, enabled = !drum || hit != null || firstHit(ed) != null,
                state = when { panelOpen -> "Open"; drum && hit == null && firstHit(ed) == null -> "No hits yet: tap a cell to add one"; else -> "Closed" }) { fg ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel("Step ${n + 1}", fg, style = LupeType.key.copy(fontSize = 15.sp)); Chevron(fg) }
            }
        }
        Spacer(Modifier.height(4.dp))
        // the track thread rests round the pattern (the tab-thread mockup): the selected track's outline in its colour; while the tabs slide the
        // travelling one stands in for it
        val travelling = LocalTabTravelling.current
        Box(Modifier.weight(1f).fillMaxWidth().selectedTrackAnchor(outset = 4.dp, leftR = 11.dp).drawBehind {
            if (!travelling) drawRoundRect(track, Offset(-3.dp.toPx(), -3.dp.toPx()), Size(size.width + 6.dp.toPx(), size.height + 6.dp.toPx()), CornerRadius(11.dp.toPx()), style = Stroke(2.dp.toPx()))
        }) {
            Column(Modifier.fillMaxSize()) {
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    if (drum) DrumGrid(ed, track, core, hit, if (paged) 0.dp else dock, pageSteps = if (paged) com.scottgerstl.lupe.ui.edit.Roll.PAGE_DOCKED else 16, follow = ui.follow,
                        onOpen = { hit = it; ui.stepPanel = true }, onTouch = { hintId?.let { messages.dismiss(it) }; hintId = null }) { hit = it }
                    else com.scottgerstl.lupe.ui.edit.StepGrid(ed, track, core, pick.step, { pick.step = it }, if (paged) 0.dp else dock, canPlay = { !(top.rec && top.playing) },
                        pageSteps = if (paged) com.scottgerstl.lupe.ui.edit.Roll.PAGE_DOCKED else com.scottgerstl.lupe.ui.edit.Roll.STEPS, follow = ui.follow)
                }
                // the one-lane view (decision 7), under the grid while Lane is on
                if (ui.lane && !drum) {
                    Spacer(Modifier.height(6.dp))
                    com.scottgerstl.lupe.ui.automation.LaneView(ed, auto, core, track, Modifier.fillMaxWidth().height(96.dp))
                }
            }
        }
    }
    // the step panel, docked at the tab's right: `panel`, its left corners at the sheet radius (spec 4.3); it slides in from the right (with Reduce Motion it only fades)
    if (panelT.value > 0.001f) Box(
            Modifier.align(Alignment.TopEnd).width(DOCK_W).fillMaxHeight()
                .graphicsLayer { if (reduce) alpha = panelT.value else translationX = (1f - panelT.value) * size.width; shape = RoundedCornerShape(topStart = com.scottgerstl.lupe.ui.theme.Shape.sheet, bottomStart = com.scottgerstl.lupe.ui.theme.Shape.sheet); clip = true }
                .background(Tok.panel)
                // a swipe to the right that no control took shuts it, the sound panel's gesture (round 7); it slides out on the panel's own motion
                .pointerInput(Unit) {
                    var total = 0f
                    detectHorizontalDragGestures(onDragStart = { total = 0f }, onDragEnd = { if (total > 32.dp.toPx()) { ui.stepPanel = false } }) { change, dx -> change.consume(); total += dx }
                }
                .pointerInput(Unit) { detectTapGestures { } }      // a touch on the panel doesn't reach the grid under it
                .semantics { paneTitle = "Step panel"; isTraversalGroup = true
                    customActions = listOf(androidx.compose.ui.semantics.CustomAccessibilityAction("Close the step panel") { ui.stepPanel = false; true }) }
                .padding(12.dp),
        ) {
            if (drum) HitPanel(ed, track, core, hit, narrow = true, onLane = { l -> hit = l to (hit?.second ?: ed.selected) },
                onStep = { st -> hit = (hit?.first ?: "") to st; core.send(Intent.StepSelect(st)) }) { hit = null } else StepControls(ed, track, core, tab, { tab = it }, pick, narrow = true)
            // the grab handle (Scott, 2026-11-17; WCAG 2.5.1): tap closes the panel as the swipe does
            PanelHandle("Close the step panel", { ui.stepPanel = false }, Modifier.align(Alignment.CenterStart).offset(x = (-12).dp))
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
        // two tiles, then the lengths as a 4 × 2 grid of pills, the current one white (Scott, 2026-11-17: as a list it ran off the screen at 48)
        add(HoldItem("One fewer step", tile = true, short = "One fewer", tileSub = if (n <= 1) "The least is 1" else "${n - 1} steps", enabled = n > 1) { core.send(SetPatternSteps(n - 1)) })
        add(HoldItem("One more step", tile = true, short = "One more", tileSub = if (n >= max) "The most is $max" else "${n + 1} steps", enabled = n < max) { core.send(SetPatternSteps(n + 1)) })
        for (v in listOf(4, 8, 12, 16, 24, 32, 48, 64)) if (v <= max) add(HoldItem("$v steps", short = "$v", checked = v == n, pill = true, group = "Length") { core.send(SetPatternSteps(v)) })
    }
    Box(Modifier.onGloballyPositioned { coords = it }) {
        Key({ coords?.takeIf { it.isAttached }?.let { c -> menu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), track, items()) } },
            "Pattern length: $n steps", width = 112.dp, height = 40.dp, minTarget = 44.dp, state = "Opens the choices: one more, one fewer, 4 to 64") { fg ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) { KeyLabel("$n steps", fg, style = LupeType.key.copy(fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal)); Chevron(fg) }
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
    LupeCrossfade(locking, Modifier.fillMaxWidth().height(44.dp)) { l ->
        if (l) LockBanner(ed, track) else Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f).semantics(mergeDescendants = true) { contentDescription = "Editing track ${ed.track} ${ed.trackName}, entry ${ed.entry}, pattern ${ed.pattern}${if (ed.scale.isNotEmpty()) ", ${ed.scale}" else ""}"; heading() },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                com.scottgerstl.lupe.ui.mix.TrackBadge(ed.track, track, true, 30.dp, 18)
                Column {
                    BasicText("${ed.trackName.substringAfter(" · ")} · ${ed.entry} ${"%02d".format(ed.pattern)}", style = LupeType.key.copy(fontSize = 16.sp, lineHeight = 18.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal), maxLines = 1,
                        autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 16.sp, stepSize = 0.5.sp))
                    BasicText(ed.scale.ifEmpty { if (ed.kind == EditorKind.Drum) "Drum" else "" } + " · ${ed.patternSteps} steps", style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 14.sp, color = Tok.text2Raised), maxLines = 1)
                }
            }
            keys()
        }
    }
}

/**
 * A toggle in the pattern bar (Edit redesign; Scott 2026-11-17: no dots, one toggle language with Store): 40 tall, hugging its word. Off, an
 * outlined pill (1.5 dp `primaryEdge`); on, the white key with dark text, its corners squaring to 12 on the spatial spring, the colour blending
 * in 150 ms (the hybrid selectable rule: shape and fill together). Reduce Motion: the corners ease, no overshoot.
 */
@Composable
private fun ToggleKey(label: String, on: Boolean, description: String, state: String, onClick: () -> Unit) {
    val reduce = LocalReduceMotion.current
    val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE).value
    val square by com.scottgerstl.lupe.ui.theme.spatialFloat(if (on) 1f else 0f, reduce)
    val squash = com.scottgerstl.lupe.ui.theme.rememberSquash(on, reduce)
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    Box(
        Modifier.defaultMinSize(minHeight = 44.dp)
            .semantics(mergeDescendants = true) { role = Role.Switch; contentDescription = description; stateDescription = state }
            .clickable(source, null, role = Role.Switch, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.height(40.dp).graphicsLayer { val (qx, qy) = squash(); scaleX = qx; scaleY = qy }.drawBehind {
                val pill = size.height / 2; val k = square.coerceIn(0f, 1.15f)
                val r = (pill + (12.dp.toPx() - pill) * k).coerceAtLeast(4f)
                if (lit < 1f) drawRoundRect(Tok.primaryEdge.copy(alpha = 1f - lit), Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(r - 0.75.dp.toPx()), style = Stroke(1.5.dp.toPx()))
                if (lit > 0f) drawRoundRect(Tok.text.copy(alpha = lit), cornerRadius = CornerRadius(r))
            }.padding(horizontal = 18.dp),
            contentAlignment = Alignment.Center,
        ) { BasicText(label, style = LupeType.key.copy(fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal, color = lerp(Tok.text, Tok.onColour, lit)), maxLines = 1) }
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
        // ⋯ in the step panel's header (Edit redesign): Copy, Paste, Clear step, with their confirms as before
        Key({ open = true; mode = StepMenuMode.Root }, "Step menu: copy, paste, clear", width = 40.dp, height = 40.dp, minTarget = 44.dp, enabled = enabled, state = if (enabled) null else "Pick a step first") { fg ->
            Canvas(Modifier.size(18.dp, 4.dp)) { for (i in 0..2) drawCircle(fg, 2.dp.toPx(), Offset(2.dp.toPx() + i * 7.dp.toPx(), 2.dp.toPx())) }
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
 * A kit (board 73 C; hybrid look, `build-gaps-2026-11-17/1-drum-edit-docked.png`): its lanes down, the steps across. The lane names are keys down
 * the left; the picked lane's key is white and squarer (shape as state); pressing a key plays the lane, a tap picks it (and, while the FM-1 is on
 * EDIT › LANES, turns that page's LANE knob so the docked panel follows). Hits are rounded squares in the track colour on the `well` grid; an
 * accent wears a white cap; a ratchet splits the hit into its repeats with 3 dp gaps. A tap toggles a hit, a hold picks it (white ring) without
 * toggling. With a panel docked ([pageSteps] 8) the grid pages by 8 beside it, with the 16-cell minimap, turning with the playhead only while
 * [follow] is on; otherwise 16 steps in chunks, as built. Every lane is in view on shorter rows, never a scroll (Scott, 2026-11-17, `1b`):
 * eight lanes share the height six used (pitch about 32), hits 41 × 23 centred in their row, lane keys 40 × 28 with their names on one line,
 * each key's touch area the whole row pitch with no gap between rows.
 */
@Composable
private fun DrumGrid(ed: EditorState, track: Color, core: LupeCore, hit: Pair<String, Int>?, dock: Dp = 0.dp, pageSteps: Int = 16, follow: Boolean = true,
    /** A hit held and let go without moving: the step panel opens on it (Scott, 2026-11-18). */
    onOpen: (Pair<String, Int>) -> Unit = {}, onTouch: () -> Unit = {}, onPick: (Pair<String, Int>?) -> Unit) {
    val lanes = ed.kitLanes.ifEmpty { ed.steps.flatMap { it.note.split(" ") }.filter { it.isNotEmpty() }.distinct() }.ifEmpty { listOf("—") }
    val top by core.top.collectAsStateWithLifecycle()
    val haptic = LocalHapticFeedback.current
    val reduce = LocalReduceMotion.current
    val density = LocalDensity.current
    val motion = com.scottgerstl.lupe.ui.theme.hybridMotion
    val paged = pageSteps == com.scottgerstl.lupe.ui.edit.Roll.PAGE_DOCKED
    var scrollX by remember { mutableFloatStateOf(0f) }
    var touchedAt by remember { mutableStateOf(0L) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val total = maxOf(ed.patternSteps, ed.steps.size, 1).coerceAtMost(64)
    val totalNow by rememberUpdatedState(total)
    val pageNow by rememberUpdatedState(pageSteps)
    // the picked lane: the picked hit's, else the first
    val pickedLane = hit?.first ?: lanes.first()
    // the smooth playhead and the hits' bounce, by the FM-1's clock (Scott, 2026-11-17)
    val pc = com.scottgerstl.lupe.ui.edit.rememberPlayheadClock(core)
    // a hit being dragged along its lane (Edit redesign): lane, from step, to step; [hitLift] on the spatial spring
    var hitDrag by remember { mutableStateOf<Triple<Int, Int, Int>?>(null) }
    // the FM-1's pads hit now on this kit (its lane notes): their lane keys light (Scott, 2026-11-17)
    val keysArea by core.keys.collectAsStateWithLifecycle()
    val linkNow by core.link.collectAsStateWithLifecycle()
    val heldLanes = if (linkNow.phase != com.scottgerstl.lupe.core.LinkPhase.Ready) emptySet() else keysArea.on(ed.track).let { on -> ed.kitNotes.indices.filter { ed.kitNotes[it] in on }.toSet() }
    val laneGlow = com.scottgerstl.lupe.ui.edit.rememberKeyGlow(heldLanes)
    val dwellMs by rememberUpdatedState(com.scottgerstl.lupe.ui.slide.LocalPhoneSettings.current.padSlideDwellMs.toLong())
    val hitLift = remember { androidx.compose.animation.core.Animatable(0f) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        // rows touch (no gap): the pitch is the touch target; what's drawn sits inside it
        val gap = 0.dp
        val mapH = if (paged) 34.dp else 0.dp
        val rh = ((maxHeight - mapH) / lanes.size)
        val labelW = 48.dp
        val gw = maxWidth - labelW - 4.dp
        val viewPx = with(density) { gw.toPx() }; val stepPx = viewPx / pageSteps
        val dockPx by rememberUpdatedState(with(density) { dock.toPx() }.coerceAtMost(viewPx - stepPx * 4))
        val roll = com.scottgerstl.lupe.ui.edit.Roll
        fun sx() = roll.clampScrollX(scrollX, roll.maxScroll(totalNow, viewPx, dockPx, pageNow))
        suspend fun glide(to: Float) {
            val target = roll.clampScrollX(to, roll.maxScroll(totalNow, viewPx, dockPx, pageNow))
            if (kotlin.math.abs(target - scrollX) > 0.5f) androidx.compose.animation.core.animate(scrollX, target,
                animationSpec = if (reduce) androidx.compose.animation.core.tween(0) else if (paged) com.scottgerstl.lupe.ui.theme.lupeSpring(motion.pageFlipMs, motion.bounce) else androidx.compose.animation.core.tween(Dur.PANEL, easing = com.scottgerstl.lupe.ui.theme.EaseOut)) { v, _ -> scrollX = v }
        }
        LaunchedEffect(dockPx > 0f, hit?.second, total, pageSteps) { glide(hit?.second?.let { roll.reveal(it, sx(), stepPx, viewPx, dockPx, total, pageSteps) } ?: roll.snap(sx(), total, viewPx, dockPx, pageSteps)) }
        LaunchedEffect(ed.playhead, total) {
            if (ed.playhead < 0 || !roll.pagesFollow(pageSteps, follow, System.currentTimeMillis() - touchedAt < 2500L)) return@LaunchedEffect
            roll.follow(ed.playhead, sx(), stepPx, viewPx, dockPx, total, pageSteps)?.let { glide(it) }
        }
        Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().weight(1f)) {
            // the lane keys
            Column(Modifier.width(labelW).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(gap)) {
                lanes.forEachIndexed { k, lane ->
                    val on = lane == pickedLane
                    val lit = animatedFloat(if (on) 1f else 0f, Dur.STATE).value
                    val sq by com.scottgerstl.lupe.ui.theme.spatialFloat(if (on) 1f else 0f, reduce)
                    val squash = com.scottgerstl.lupe.ui.theme.rememberSquash(on, reduce)
                    // the key is drawn 40 × 28 (less on a very short phone); its touch area is the whole row, wider and taller than the key
                    val keyH = minOf(28.dp, rh - 4.dp)
                    Box(
                        Modifier.fillMaxWidth().height(rh)
                            .graphicsLayer { val (qx, qy) = squash(); val g = if (reduce) 1f else 1f - 0.04f * laneGlow.of(k); scaleX = qx * g; scaleY = qy * g }
                            .drawBehind {
                                val kw = 40.dp.toPx(); val kh = keyH.toPx()
                                // the FM-1 hitting this lane: the key fills with the track's colour, fading back over 150 ms
                                drawRoundRect(lerp(lerp(Tok.control, Tok.text, lit), track, laneGlow.of(k)), Offset((size.width - kw) / 2, (size.height - kh) / 2), Size(kw, kh), CornerRadius((10f - 4f * sq.coerceIn(0f, 1.2f)).dp.toPx()))
                            }
                            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "$lane lane"; selected = on; onClick("Pick the lane") { pickLane(core, k, lane, hit, ed, onPick); true } }
                            .pointerInput(k, hit) {
                                detectTapGestures(
                                    onPress = { if (!(top.rec && top.playing)) { core.send(PlayNote(lane = k, on = true)); tryAwaitRelease(); core.send(PlayNote(lane = k, on = false)) } },
                                    onTap = { pickLane(core, k, lane, hit, ed, onPick) },
                                )
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        BasicText(lane, Modifier.width(38.dp), style = LupeType.label.copy(fontSize = 10.sp, lineHeight = 11.sp, color = lerp(lerp(Tok.text2Raised, Tok.onColour, lit), Tok.onColour, laneGlow.of(k)), textAlign = androidx.compose.ui.text.style.TextAlign.Center), maxLines = 1,
                            autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 7.sp, maxFontSize = 10.sp, stepSize = 0.5.sp))
                    }
                }
            }
            Spacer(Modifier.width(4.dp))
            // the grid
            Box(
                Modifier.width(gw).fillMaxHeight().clip(RoundedCornerShape(18.dp)).background(Tok.well)
                    .pointerInput(Unit) {
                        val tracker = androidx.compose.ui.input.pointer.util.VelocityTracker()
                        var startX = 0f
                        val fling = roll.FLING_DP_S.dp.toPx()
                        detectHorizontalDragGestures(
                            onDragStart = { touchedAt = System.currentTimeMillis(); startX = sx(); tracker.resetTracking() },
                            // a fling or a fifth of the page turns it (Scott, 2026-11-17), then it springs the rest of the way
                            onDragEnd = { touchedAt = System.currentTimeMillis(); val v = tracker.calculateVelocity().x
                                scope.launch { glide(if (dockPx > 0.5f) roll.snap(sx(), totalNow, viewPx, dockPx, pageNow) else roll.pageTarget(startX, sx(), v, viewPx, totalNow, pageNow, fling)) } },
                            onDragCancel = { scope.launch { glide(roll.pageTarget(startX, startX, 0f, viewPx, totalNow, pageNow, fling)) } },
                        ) { change, dx -> if (totalNow > pageNow || dockPx > 0f) { change.consume(); touchedAt = System.currentTimeMillis(); tracker.addPosition(change.uptimeMillis, change.position); scrollX = roll.clampScrollX(scrollX - dx, roll.maxScroll(totalNow, viewPx, dockPx, pageNow)) } }
                    },
            ) {
                // the beats: odd beats on a band; the playhead's column lit, with a cap; lane lines faint
                Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
                    val x0 = -sx()
                    for (i in 0 until total) { val x = x0 + i * stepPx; if ((i / 4) % 2 == 1) drawRect(Tok.panel, Offset(x, 0f), Size(stepPx, size.height)) }
                    val rowPx = rh.toPx() + gap.toPx()
                    for (k in 1 until lanes.size) drawLine(Tok.outline.copy(alpha = 0.5f), Offset(0f, k * rowPx - gap.toPx() / 2), Offset(size.width, k * rowPx - gap.toPx() / 2), 1.dp.toPx())
                    // the playhead sweeps continuously by the FM-1's clock; Reduce Motion: it jumps step to step
                    pc.position(ed.track)?.let { p -> if (p < total) {
                        val x = x0 + p * stepPx
                        drawRect(Tok.text.copy(alpha = 0.12f), Offset(x, 0f), Size(stepPx, size.height))
                        drawRoundRect(Tok.text, Offset(x + 6.dp.toPx(), 4.dp.toPx()), Size(stepPx - 12.dp.toPx(), 4.dp.toPx()), CornerRadius(2.dp.toPx()))
                    } }
                }
                Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(gap)) {
                    lanes.forEachIndexed { k, lane ->
                        Box(Modifier.fillMaxWidth().height(rh).clipToBounds()) {
                            for (i in 0 until total) {
                                val s = ed.steps.getOrNull(i) ?: Step()
                                val h = s.hits.firstOrNull { it.lane == k }
                                val on = s.on && (if (s.hits.isNotEmpty()) h != null else lane in s.note.split(" "))
                                val accent = h?.accent == true
                                val picked = hit?.first == lane && hit.second == i
                                val onF = animatedFloat(if (on) 1f else 0f, Dur.STATE)
                                val sel = animatedFloat(if (picked) 1f else 0f, Dur.STATE)
                                val pop by com.scottgerstl.lupe.ui.theme.spatialFloat(if (on) 1f else 0f, reduce, fast = true)
                                Box(
                                    Modifier.offset { IntOffset((i * stepPx - sx()).roundToInt(), 0) }.width(with(density) { stepPx.toDp() }).fillMaxHeight()
                                        .drawBehind {
                                            val hd = hitDrag
                                            // carried away from here: a dashed ghost; carried to here: the hit, lifted (1.08, a shadow)
                                            if (hd != null && hd.first == k && hd.second == i && hd.third != i) {
                                                val gw = minOf(41.dp.toPx(), size.width - 8.dp.toPx()); val gh = minOf(23.dp.toPx(), size.height - 9.dp.toPx())
                                                drawRoundRect(Tok.text2Raised.copy(alpha = 0.7f), Offset((size.width - gw) / 2, (size.height - gh) / 2), Size(gw, gh), CornerRadius(6.dp.toPx()),
                                                    style = Stroke(1.5.dp.toPx(), pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))))
                                                return@drawBehind
                                            }
                                            if (hd != null && hd.first == k && hd.third == i) {
                                                val lk = 1f + 0.08f * hitLift.value.coerceIn(0f, 1.2f)
                                                val gw = minOf(41.dp.toPx(), size.width - 8.dp.toPx()) * lk; val gh = minOf(23.dp.toPx(), size.height - 9.dp.toPx()) * lk
                                                val l = (size.width - gw) / 2; val tp = (size.height - gh) / 2
                                                drawRect(Tok.text.copy(alpha = 0.06f), Offset.Zero, size)
                                                drawRoundRect(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.35f), Offset(l, tp + 3.dp.toPx()), Size(gw, gh), CornerRadius(6.dp.toPx()))
                                                drawRoundRect(track, Offset(l, tp), Size(gw, gh), CornerRadius(6.dp.toPx()))
                                                drawRoundRect(Tok.text, Offset(l - 1.dp.toPx(), tp - 1.dp.toPx()), Size(gw + 2.dp.toPx(), gh + 2.dp.toPx()), CornerRadius(7.dp.toPx()), style = Stroke(2.dp.toPx()))
                                                return@drawBehind
                                            }
                                            if (onF.value <= 0.001f && sel.value <= 0f) return@drawBehind
                                            // the hit: a rounded square, inset; it grows in on the spring when placed
                                            // 41 × 23 centred in the row (smaller only where the step or the row is narrower)
                                            // grows in when placed; bounces as its step sounds (a ratchet's segments bounce together, as one hit)
                                            val g = (if (reduce) 1f else pop.coerceIn(0f, 1.15f)) * (if (on) pc.bounce(i, ed.track) else 1f)
                                            val w = minOf(41.dp.toPx(), size.width - 8.dp.toPx()) * g; val hh = minOf(23.dp.toPx(), size.height - 9.dp.toPx()) * g
                                            val left = (size.width - w) / 2; val topY = (size.height - hh) / 2
                                            val fill = track.copy(alpha = onF.value * (0.7f + 0.3f * s.velocity / 127f))
                                            val r = CornerRadius(6.dp.toPx())
                                            val n = if (s.ratchet > 1) s.ratchet.coerceAtMost(4) else 1
                                            if (n == 1) drawRoundRect(fill, Offset(left, topY), Size(w, hh), r)
                                            else { val sg = 3.dp.toPx(); val sw = (w - sg * (n - 1)) / n
                                                for (j in 0 until n) drawRoundRect(fill, Offset(left + j * (sw + sg), topY), Size(sw, hh), CornerRadius(minOf(6.dp.toPx(), sw / 2))) }
                                            // an accent: a white cap along the top
                                            if (accent) drawRoundRect(Tok.text.copy(alpha = onF.value), Offset(left + 4.dp.toPx(), (topY - 4.dp.toPx()).coerceAtLeast(0f)), Size(w - 8.dp.toPx(), 3.dp.toPx()), CornerRadius(1.5.dp.toPx()))
                                            if (sel.value > 0f) drawRoundRect(Tok.text.copy(alpha = sel.value), Offset(left - 2.dp.toPx(), topY - 2.dp.toPx()), Size(w + 4.dp.toPx(), hh + 4.dp.toPx()), CornerRadius(10.dp.toPx()), style = Stroke(2.dp.toPx()))
                                        }
                                        .semantics(mergeDescendants = true) {
                                            role = Role.Button
                                            contentDescription = "$lane, step ${i + 1}" + (if (on) ", hit" + (if (accent) ", accent" else "") + (if (s.ratchet > 1) ", ratchet ${s.ratchet}" else "") else ", empty") + if (picked) ", picked" else ""
                                            onClick { core.send(ToggleHit(k, i)); true }
                                            customActions = listOf(CustomAccessibilityAction("Pick this hit without changing it") { onPick(lane to i); core.send(Intent.StepSelect(i)); true })
                                        }
                                        .pointerInput(k, i, on) {
                                            awaitEachGesture {
                                                val down = awaitFirstDown()
                                                onTouch()
                                                var dragging = false; var cancelled = false
                                                // a tap toggles on touch-up, only if the finger never left the slop; a still hold picks the hit. Past the slop it
                                                // is a page swipe and the cell isn't touched, unless the finger pressed on a hit and held still for the dwell
                                                // first: then the hit is carried along its lane (Roll.move; Scott, 2026-11-17)
                                                // a hit lifts after the dwell; an empty cell has no hold (a lift is a tap, a move a swipe)
                                                val up = withTimeoutOrNull(if (on) dwellMs else Long.MAX_VALUE) {
                                                    while (true) {
                                                        val ev = awaitPointerEvent()
                                                        val ch = ev.changes.firstOrNull { it.id == down.id }
                                                        if (ch == null || ch.isConsumed) { cancelled = true; return@withTimeoutOrNull null }
                                                        if (!ch.pressed) return@withTimeoutOrNull ch
                                                        when (com.scottgerstl.lupe.ui.edit.Roll.move((ch.position - down.position).getDistance(), viewConfiguration.touchSlop, ch.uptimeMillis - down.uptimeMillis, dwellMs, on)) {
                                                            com.scottgerstl.lupe.ui.edit.Roll.Move.Drag -> { ch.consume(); dragging = true; return@withTimeoutOrNull null }
                                                            com.scottgerstl.lupe.ui.edit.Roll.Move.Swipe -> { cancelled = true; return@withTimeoutOrNull null }
                                                            null -> Unit
                                                        }
                                                    }
                                                    @Suppress("UNREACHABLE_CODE") null
                                                }
                                                // held still on a hit for the dwell: it lifts at once (Scott, 2026-11-17). A move carries it along its lane; a lift without
                                                // moving settles it back, unchanged, and picks it for the panel (a tap toggles, so this is the grid's way to pick a hit)
                                                if (on && !dragging && !cancelled && up == null) {
                                                    haptic.performHapticFeedback(HapticFeedbackType.GestureThresholdActivate)
                                                    hitDrag = Triple(k, i, i)
                                                    scope.launch { com.scottgerstl.lupe.ui.theme.unscaled { hitLift.animateTo(1f, if (reduce) androidx.compose.animation.core.tween(150) else motion.spatial()) } }
                                                    while (true) {
                                                        val ev = awaitPointerEvent()
                                                        val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                                                        if (!ch.pressed || ch.isConsumed) break
                                                        if ((ch.position - down.position).getDistance() > viewConfiguration.touchSlop) { ch.consume(); dragging = true; break }
                                                    }
                                                    if (!dragging) {
                                                        scope.launch { com.scottgerstl.lupe.ui.theme.unscaled { hitLift.animateTo(0f, if (reduce) androidx.compose.animation.core.tween(150) else motion.spatial()) }; hitDrag = null }
                                                        onPick(lane to i); core.send(Intent.StepSelect(i)); onOpen(lane to i)
                                                        return@awaitEachGesture
                                                    }
                                                }
                                                when {
                                                    dragging -> {
                                                        hitDrag = Triple(k, i, i)
                                                        scope.launch { com.scottgerstl.lupe.ui.theme.unscaled { hitLift.animateTo(1f, if (reduce) androidx.compose.animation.core.tween(150) else motion.spatial()) } }
                                                        var to = i
                                                        drag(down.id) { ch ->
                                                            ch.consume()
                                                            val j = (i + kotlin.math.round((ch.position.x - down.position.x) / stepPx).toInt()).coerceIn(0, totalNow - 1)
                                                            if (j != to) { to = j; hitDrag = Triple(k, i, j); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                                                        }
                                                        val target = edStepsHit(ed, to, k)
                                                        if (to != i && !target) { core.send(ToggleHit(k, i)); core.send(ToggleHit(k, to)); onPick(lane to to); core.send(Intent.StepSelect(to)) }
                                                        else if (to != i) haptic.performHapticFeedback(HapticFeedbackType.Reject)
                                                        scope.launch { com.scottgerstl.lupe.ui.theme.unscaled { hitLift.animateTo(0f, if (reduce) androidx.compose.animation.core.tween(150) else motion.spatial()) }; hitDrag = null }
                                                    }
                                                    cancelled -> Unit
                                                    up != null -> core.send(ToggleHit(k, i))
                                                    else -> { haptic.performHapticFeedback(HapticFeedbackType.LongPress); onPick(lane to i); core.send(Intent.StepSelect(i)); waitForUpOrCancellation() }
                                                }
                                            }
                                        },
                                )
                            }
                        }
                    }
                }
            }
        }
        if (paged) {
            Spacer(Modifier.height(6.dp))
            val pagePx = pageSteps * stepPx
            com.scottgerstl.lupe.ui.edit.MiniMap(ed, track, total, pageSteps, sx() / pagePx.coerceAtLeast(1f), follow, gw, reduce, labelW = labelW + 4.dp) { p -> touchedAt = System.currentTimeMillis(); scope.launch { glide(p * pagePx) } }
        }
        }
    }
}

/** A lane key tapped: the lane is picked (its hit at the picked step, else the selected one); on EDIT › LANES the FM-1's LANE knob follows. */
private fun pickLane(core: LupeCore, k: Int, lane: String, hit: Pair<String, Int>?, ed: EditorState, onPick: (Pair<String, Int>?) -> Unit) {
    onPick(lane to (hit?.second ?: ed.selected))
    val p = core.page.value
    if (p.family == "EDIT" && p.title.contains("LANE", ignoreCase = true) && p.tiles != null) core.send(com.scottgerstl.lupe.core.PickTile(k))
}

/** The picked hit's values in boxes (a kit has more than four per hit, so boxes, not dials), under a "SD · step 5 ✕" key: one row, or docked ([narrow]) two rows of three. */
@Composable
private fun HitPanel(ed: EditorState, track: Color, core: LupeCore, hit: Pair<String, Int>?, narrow: Boolean = false, onLane: (String) -> Unit = {}, onStep: (Int) -> Unit = {}, onClose: () -> Unit) {
    val (lane, step) = hit ?: return
    val s = ed.steps.getOrNull(step) ?: Step()
    val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
    val lanes = ed.kitLanes.ifEmpty { listOf(lane) }
    val k = lanes.indexOf(lane).coerceAtLeast(0)
    val h = s.hits.firstOrNull { it.lane == k }
    val on = s.on && (if (s.hits.isNotEmpty()) h != null else lane in s.note.split(" "))
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f).semantics(mergeDescendants = true) { heading() }) {
                // "KICK · STEP 5" (Scott, 2026-11-18): the lane and the step together
                BasicText("${lane.uppercase()} · STEP ${step + 1}", style = LupeType.title.copy(fontSize = 19.sp, lineHeight = 21.sp), maxLines = 1,
                    autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 13.sp, maxFontSize = 19.sp, stepSize = 1.sp))
                BasicText(if (on) "Hit" else "Empty", style = LupeType.small.copy(fontSize = 13.sp, color = Tok.text2Raised), maxLines = 1)
            }
            // ‹ › step through this lane's hits (round to the other end)
            val laneHits = laneHitSteps(ed, k)
            if (laneHits.size > 1 || (laneHits.isNotEmpty() && step !in laneHits)) {
                PagerHalf("‹", "Previous ${lane} hit", first = true) { prevHit(laneHits, step)?.let(onStep) }
                Spacer(Modifier.width(2.dp))
                PagerHalf("›", "Next ${lane} hit", first = false) { nextHit(laneHits, step)?.let(onStep) }
            }
        }
        Spacer(Modifier.height(8.dp))
        // the FM-1's NOTES knobs on a kit (Skiff v2.5.1 source, grid_edit; not a live probe): 1 LANE, 2 HIT, 3 ACC, 4 VELOCITY
        BasicText("NOTES", Modifier.padding(bottom = 6.dp), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            com.scottgerstl.lupe.ui.page.ParamTile("LANE", 1, lane, "Lane", track, "lane" to step, Modifier.weight(1f), num = k, min = 0, max = (lanes.size - 1).coerceAtLeast(0), dpPerStep = 24f, tick = true) { d ->
                lanes.getOrNull((k + d).coerceIn(0, lanes.lastIndex))?.let(onLane) }
            com.scottgerstl.lupe.ui.page.ParamTile("HIT", 2, if (on) "On" else "Off", "Hit", track, "hit" to (step to k), Modifier.weight(1f), num = if (on) 1 else 0, min = 0, max = 1, dpPerStep = 24f, tick = true) { d ->
                if ((d > 0) != on) core.send(ToggleHit(k, step)) }
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            // ACC: the core has no intent for one hit's accent yet; the FM-1's knob 3 turns it
            com.scottgerstl.lupe.ui.page.ParamTile("ACC", 3, if (h?.accent == true) "On" else "Off", "Accent", track, "acc" to (step to k), Modifier.weight(1f), enabled = false,
                disabledWhy = "Turn the FM-1's knob 3; Lupe can't set an accent yet") { }
            com.scottgerstl.lupe.ui.page.ParamTile("VELOCITY", 4, "${s.velocity}", "Velocity", track, "velocity" to step, Modifier.weight(1f), num = s.velocity, min = 1, max = 127, dpPerStep = 3f) { send(StepField.Velocity, it) }
        }
        Spacer(Modifier.height(12.dp))
        BasicText("FEEL", Modifier.padding(bottom = 6.dp), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
        val chanceV = chanceValue(s.chance, s.cond)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            com.scottgerstl.lupe.ui.page.ParamTile("CHANCE", 1, chanceText(chanceV), "Chance, then the trig conditions", track, "chance" to step, Modifier.weight(1f), num = chanceV, min = 0, max = CHANCE_MAX, dpPerStep = 4f) { d -> chanceSteps(s.chance, s.cond, d).forEach { (f, v) -> send(f, v) } }
            com.scottgerstl.lupe.ui.page.ParamTile("RATCHET", 2, "${s.ratchet}", "Ratchet", track, "ratchet" to step, Modifier.weight(1f), num = s.ratchet, min = 1, max = 5, dpPerStep = 28f, tick = true) { send(StepField.Ratchet, it) }
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            com.scottgerstl.lupe.ui.page.ParamTile("NUDGE", 3, if (s.nudge > 0) "+${s.nudge}" else "${s.nudge}", "Nudge", track, "nudge" to step, Modifier.weight(1f), num = s.nudge, min = -32, max = 31, bipolar = true, dpPerStep = 6f) { send(StepField.Nudge, it) }
            com.scottgerstl.lupe.ui.page.ParamTile("TYPE", 4, "—", "Type", track, "type" to step, Modifier.weight(1f), enabled = false, disabledWhy = "Turn the FM-1's knob 4; Lupe doesn't read it yet") { }
        }
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
    val total = maxOf(ed.patternSteps, 1)
    var confirm by remember { mutableStateOf(false) }
    var armedAt by remember { mutableStateOf(0L) }
    val lockedCount = s.values.count { it.locked }
    if (confirm && lockedCount == 0) confirm = false
    val notes = stepNotes(s)
    val pitch = if (s.on) s.pitchText.substringBefore(' ').ifEmpty { s.note } else "—"
    val link by core.link.collectAsStateWithLifecycle()
    val linked = link.phase == com.scottgerstl.lupe.core.LinkPhase.Ready
    fun go(to: Int) { val t = Math.floorMod(to, total); pick.step = t; core.send(Intent.StepSelect(t)) }
    Column(Modifier.fillMaxSize()) {
        // the header (Edit redesign, Scott 2026-11-17): STEP N, what it holds, a connected ‹ › pager, and ⋯ (Copy, Paste, Clear step)
        Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f).semantics(mergeDescendants = true) { heading() }) {
                BasicText("STEP $n", style = LupeType.title.copy(fontSize = 19.sp, lineHeight = 21.sp))
                BasicText(if (notes.isEmpty()) "empty" else "$pitch · ${notes.size} note${if (notes.size == 1) "" else "s"}", style = LupeType.small.copy(fontSize = 13.sp, color = Tok.text2Raised), maxLines = 1)
            }
            PagerHalf("‹", "Previous step", first = true) { go(ed.selected - 1) }
            Spacer(Modifier.width(2.dp))
            PagerHalf("›", "Next step", first = false) { go(ed.selected + 1) }
            Spacer(Modifier.width(8.dp))
            StepMenuKey(ed, core, true)
        }
        Spacer(Modifier.height(8.dp))
        // Notes · Feel · Sound: a connected group the panel's width
        SegmentGroup(PanelTab.entries.map { it.label.lowercase().replaceFirstChar { c -> c.uppercase() } }, tab.ordinal, { setTab(PanelTab.entries[it]) }, Modifier.fillMaxWidth(),
            height = 40.dp, padH = 8.dp, role = Role.Tab, fontSize = 15, fill = true)
        Spacer(Modifier.height(8.dp))
        LupeCrossfade(Pair(tab, confirm), Modifier.fillMaxSize()) { (t, c) ->
            val send = { f: StepField, d: Int -> core.send(Intent.StepAdjust(f, d)) }
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                when (t) {
                    PanelTab.Notes -> {
                        // the FM-1's knobs 1–4 edit this step on SEQ › NOTES (Skiff 2.5.1 step_edit: PITCH START LENGTH VELOCITY); the ‹ › stand for its PRESETS cursor
                        Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Canvas(Modifier.size(12.dp)) { drawCircle(Tok.text2Raised, size.width / 2 - 1.dp.toPx(), style = Stroke(1.5.dp.toPx())) }
                            BasicText(if (linked) "FM-1 knobs 1–4 → step $n" else "FM-1 knobs 1–4 drive the step once the FM-1 is linked", style = LupeType.small.copy(fontSize = 13.sp, color = Tok.text2Raised), maxLines = 1)
                        }
                        val chord = notes.size > 1
                        val cap = s.maxLength.coerceIn(1, 16)
                        val nextNote = ed.selected + 1 + cap
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            com.scottgerstl.lupe.ui.page.ParamTile(if (chord) "ROOT" else "PITCH", 1, pitch, "Pitch", track, "pitch" to ed.selected, Modifier.weight(1f), dpPerStep = 16f, locked = s.isLocked("PITCH")) { send(StepField.Pitch, it) }
                            // START moves the note along the pattern, a step a turn (the FM-1's knob 2); the panel follows it
                            com.scottgerstl.lupe.ui.page.ParamTile("START", 2, "$n", "Start step", track, "move" to ed.pattern, Modifier.weight(1f), num = n, min = 1, max = total, dpPerStep = 22f, tick = true) { d ->
                                pick.step = Math.floorMod(ed.selected + d, total); send(StepField.Move, d) }
                        }
                        Spacer(Modifier.height(8.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            com.scottgerstl.lupe.ui.page.ParamTile("LENGTH", 3, "${s.length}", "Length", track, "length" to ed.selected, Modifier.weight(1f), unit = if (s.length == 1) "step" else "steps",
                                num = s.length, min = 1, max = cap, dpPerStep = 16f, locked = s.isLocked("LENGTH"),
                                limitWord = if (s.length >= cap) (if (nextNote > 16) "pattern ends" else "note at step $nextNote") else null) { send(StepField.Length, it) }
                            com.scottgerstl.lupe.ui.page.ParamTile("VELOCITY", 4, "${s.velocity}", "Velocity", track, "velocity" to ed.selected, Modifier.weight(1f), num = s.velocity, min = 1, max = 127, dpPerStep = 3f, locked = s.isLocked("VELOCITY")) { send(StepField.Velocity, it) }
                        }
                        Spacer(Modifier.height(8.dp))
                        if (c) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                            val names = s.values.filter { it.locked }.joinToString(", ") { it.param }
                            ConfirmBox("Clear ${if (lockedCount == 1) "the lock" else "all $lockedCount locks"} on step $n ($names)", "Confirm: clear $lockedCount lock${if (lockedCount == 1) "" else "s"} on step $n: $names", armedAt, Modifier.weight(1f)) {
                                core.send(Intent.LocksClearAll(ed.selected)); confirm = false }
                            Key({ confirm = false }, "Cancel", width = 80.dp, height = 40.dp, minTarget = 44.dp) { fg -> KeyLabel("Cancel", fg) }
                        } else Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            val latched = ed.lock == LockMode.Latched
                            Key({ core.send(Intent.LockToggle) }, "Lock", height = 40.dp, minTarget = 44.dp, on = latched, role = Role.Switch, fill = true, modifier = Modifier.weight(1f),
                                state = if (latched) "On: knob turns lock to step $n" else "Off") { fg ->
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Canvas(Modifier.size(10.dp)) { if (latched) diamond(fg, size.width / 2, size.height / 2, 4.dp.toPx()) else
                                        drawPath(Path().apply { moveTo(size.width / 2, 0f); lineTo(size.width, size.height / 2); lineTo(size.width / 2, size.height); lineTo(0f, size.height / 2); close() }, fg, style = Stroke(1.5.dp.toPx())) }
                                    KeyLabel("Lock", fg)
                                }
                            }
                            Key({ if (lockedCount > 0) { confirm = true; armedAt = System.currentTimeMillis() } }, "Clear all locks on step $n", height = 40.dp, minTarget = 44.dp, fill = true, modifier = Modifier.weight(1f),
                                enabled = lockedCount > 0) { fg -> KeyLabel("Clear all", fg) }
                        }
                    }
                    PanelTab.Feel -> {
                        // the FM-1's FEEL knobs (Skiff v2.5.1 source, feel_turn; not a live probe): 1 CHANCE (running past 100 into the trig conditions),
                        // 2 RATCHET, 3 NUDGE, 4 TYPE. Same control language as Notes, linked the same way (the panel on Feel puts the FM-1 on SEQ › FEEL)
                        Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Canvas(Modifier.size(12.dp)) { drawCircle(Tok.text2Raised, size.width / 2 - 1.dp.toPx(), style = Stroke(1.5.dp.toPx())) }
                            BasicText(if (linked) "FM-1 knobs 1–4 → step $n" else "FM-1 knobs 1–4 drive the step once the FM-1 is linked", style = LupeType.small.copy(fontSize = 13.sp, color = Tok.text2Raised), maxLines = 1)
                        }
                        val chanceV = chanceValue(s.chance, s.cond)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            com.scottgerstl.lupe.ui.page.ParamTile("CHANCE", 1, chanceText(chanceV), "Chance, then the trig conditions", track, "chance" to ed.selected, Modifier.weight(1f),
                                num = chanceV, min = 0, max = CHANCE_MAX, dpPerStep = 4f, locked = s.isLocked("CHANCE")) { d -> chanceSteps(s.chance, s.cond, d).forEach { (f, v) -> send(f, v) } }
                            // the core writes 1–4 (it keeps 0–3); the FM-1's knob reaches 5 (feel_turn), shown when it does: a core follow-up
                            com.scottgerstl.lupe.ui.page.ParamTile("RATCHET", 2, "${s.ratchet}", "Ratchet", track, "ratchet" to ed.selected, Modifier.weight(1f),
                                num = s.ratchet, min = 1, max = 5, dpPerStep = 28f, tick = true, locked = s.isLocked("RATCHET")) { send(StepField.Ratchet, it) }
                        }
                        Spacer(Modifier.height(8.dp))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            com.scottgerstl.lupe.ui.page.ParamTile("NUDGE", 3, if (s.nudge > 0) "+${s.nudge}" else "${s.nudge}", "Nudge", track, "nudge" to ed.selected, Modifier.weight(1f),
                                num = s.nudge, min = -32, max = 31, bipolar = true, dpPerStep = 6f, locked = s.isLocked("NUDGE")) { send(StepField.Nudge, it) }
                            // TYPE: the FM-1's knob 4; the core carries no field for it yet, so the phone shows the tile and leaves the turning to the FM-1
                            com.scottgerstl.lupe.ui.page.ParamTile("TYPE", 4, "—", "Type", track, "type" to ed.selected, Modifier.weight(1f), enabled = false,
                                disabledWhy = "Turn the FM-1's knob 4; Lupe doesn't read it yet") { }
                        }
                        Spacer(Modifier.height(8.dp))
                        // a touch shortcut to the same value as CHANCE past 100 (not a parameter of its own)
                        CondPicker(s.cond, label = "Conditions") { idx -> val now = CONDITIONS.indexOf(s.cond).coerceAtLeast(0); send(StepField.Cond, idx - now) }
                    }
                    PanelTab.Sound -> {
                        if (s.values.isEmpty()) BasicText("No locks on this step. Hold it and turn a knob on the FM-1, or latch Lock.", Modifier.padding(top = 6.dp), style = LupeType.body.copy(fontSize = 14.sp))
                        s.values.forEach { v -> LockRow(v.param, v.value, v.locked, track) { core.send(Intent.LockClear(ed.selected, v.param)) } }
                    }
                }
            }
        }
    }
}

/** CHANCE's range on the FM-1's knob: 0–100, then the trig conditions after ALWAYS (100 + condition number; Skiff v2.5.1 feel_turn). */
internal val CHANCE_MAX = 100 + 11

/** The knob's value for a step: its chance, or 100 + its condition when it has one (on the FM-1 one knob turns through both). */
internal fun chanceValue(chance: Int, cond: String): Int { val c = CONDITIONS.indexOf(cond); return if (c > 0) 100 + c else chance.coerceIn(0, 100) }

/** What the CHANCE tile shows: "75%", or past 100 the condition ("2nd of 4"). */
internal fun chanceText(v: Int): String = if (v <= 100) "$v%" else condWords(CONDITIONS[(v - 100).coerceIn(1, CONDITIONS.lastIndex)]).removePrefix("Every ")

/**
 * A turn of the CHANCE tile by [d] steps, as the core's two fields: the chance (0–100) and the condition (0 = ALWAYS). Past 100 the chance sits at
 * 100 and the condition counts up; back under, the condition returns to ALWAYS.
 */
internal fun chanceSteps(chance: Int, cond: String, d: Int): List<Pair<StepField, Int>> {
    val now = chanceValue(chance, cond)
    val to = (now + d).coerceIn(0, CHANCE_MAX)
    val c0 = CONDITIONS.indexOf(cond).coerceAtLeast(0)
    val (ch1, c1) = if (to <= 100) to to 0 else 100 to (to - 100)
    return buildList { if (ch1 != chance) add(StepField.Chance to (ch1 - chance)); if (c1 != c0) add(StepField.Cond to (c1 - c0)) }
}

/** The trig conditions by COND number (the core's table: PadsEditor.swift, the iPad's StepInspector). */
internal val CONDITIONS = listOf("ALWAYS", "FILL", "!FILL", "1:2", "2:2", "1:3", "2:3", "3:3", "1:4", "2:4", "3:4", "4:4")

/** A condition's words for the picker ("1:4" → "Every 1st of 4"). */
internal fun condWords(c: String): String {
    val m = Regex("^(\\d):(\\d)$").find(c) ?: return when (c) { "ALWAYS" -> "Always"; "FILL" -> "Fill"; "!FILL" -> "Not fill"; else -> c }
    val (a, b) = m.destructured
    val nth = when (a) { "1" -> "1st"; "2" -> "2nd"; "3" -> "3rd"; else -> "${a}th" }
    return "Every $nth of $b"
}

/** Half of the step pager (spec 3.4): 44 × 40 on `control`, outer end round, inner corner 8. */
@Composable
private fun PagerHalf(label: String, description: String, first: Boolean, onClick: () -> Unit) {
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val press = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else 100).value
    Box(
        Modifier.size(44.dp, 40.dp)
            .drawBehind {
                val pill = size.height / 2; val inner = 8.dp.toPx()
                with(SegmentDraw) { segment(lerp(Tok.control, Tok.lifted, press), if (first) pill else inner, if (first) inner else pill) }
            }
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = description }
            .clickable(source, null, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { BasicText(label, style = LupeType.key.copy(fontSize = 20.sp)) }
}

/** COND as a picker row (Edit redesign): `control` at radius 12, 52 tall, "COND" and the condition in words with ⌄; it opens the list. */
@Composable
private fun CondPicker(cond: String, label: String = "COND", onPick: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier.fillMaxWidth().height(44.dp).clip(RoundedCornerShape(12.dp)).background(Tok.control)
                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "$label, ${condWords(cond)}. Opens the list" }
                .clickable { open = true }.padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(label, Modifier.weight(1f), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
            BasicText(condWords(cond), style = LupeType.key.copy(fontSize = 16.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Normal))
            Spacer(Modifier.width(8.dp)); Chevron(Tok.text2Raised)
        }
        LupeMenu(open, { open = false }, alignEnd = true, width = 220.dp) {
            CONDITIONS.forEachIndexed { i, c -> MenuRow(condWords(c), { onPick(i); open = false }, checked = c == cond) }
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
    Row(Modifier.fillMaxWidth().height(48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (locked) Diamond(track, 6.dp) else BasicText("—", Modifier.width(12.dp), style = LupeType.body.copy(textAlign = TextAlign.Center))
        BasicText(param, style = LupeType.key)
        BasicText("$value", style = LupeType.number.copy(fontSize = 18.sp, lineHeight = 18.sp))
        BasicText(if (locked) "locked on this step" else "recorded", style = LupeType.small, maxLines = 1)
        Spacer(Modifier.weight(1f))
        if (locked) Key(onClear, "Clear the $param lock", width = 44.dp, height = 40.dp, minTarget = 44.dp) { fg ->
            Canvas(Modifier.size(10.dp)) { val st = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round); drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), st.width, StrokeCap.Round); drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), st.width, StrokeCap.Round) }
        }
    }
}

private fun Step.isLocked(param: String) = values.any { it.locked && it.param == param }

/** Whether step [i] already has a hit on lane [k] (a carried hit lands only on an empty cell; an accent isn't carried). */
private fun edStepsHit(ed: EditorState, i: Int, k: Int): Boolean {
    val s = ed.steps.getOrNull(i) ?: return false
    return s.on && (if (s.hits.isNotEmpty()) s.hits.any { it.lane == k } else (ed.kitLanes.getOrNull(k) ?: "") in s.note.split(" "))
}


/** The steps where kit lane [k] has a hit, in order. */
internal fun laneHitSteps(ed: EditorState, k: Int): List<Int> = ed.steps.indices.filter { i -> val s = ed.steps[i]; s.on && s.hits.any { it.lane == k } }
/** The lane's hit before [step], round from the first to the last; null when it has none. */
internal fun prevHit(hits: List<Int>, step: Int): Int? = if (hits.isEmpty()) null else hits.lastOrNull { it < step } ?: hits.last()
/** The lane's hit after [step], round from the last to the first. */
internal fun nextHit(hits: List<Int>, step: Int): Int? = if (hits.isEmpty()) null else hits.firstOrNull { it > step } ?: hits.first()
/** A kit's first hit in the pattern, as (lane name, step), for the Step key with nothing picked. */
internal fun firstHit(ed: EditorState): Pair<String, Int>? {
    val i = ed.steps.indices.firstOrNull { ed.steps[it].on && ed.steps[it].hits.isNotEmpty() } ?: return null
    val k = ed.steps[i].hits.first().lane
    return (ed.kitLanes.getOrNull(k) ?: return null) to i
}

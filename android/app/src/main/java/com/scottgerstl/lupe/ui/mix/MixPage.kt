package com.scottgerstl.lupe.ui.mix

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.ui.shell.MenuDivider
import com.scottgerstl.lupe.ui.shell.MenuRow
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.SlideDirection
import com.scottgerstl.lupe.ui.slide.slideToTurn
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import com.scottgerstl.lupe.ui.theme.hybridMotion
import com.scottgerstl.lupe.ui.theme.springFloat
import kotlin.math.roundToInt

/** The level's unity (the FM-1's 0 dB): a small tick beside the fader. */
const val UNITY = 100

/**
 * The Mix tab (hybrid UI, Scott 2026-11-17: "most people want it more accessible"; spec 4.5, `phone-06`). GLO's five pages as quiet sub-pages
 * along the top (Mixer · Delay · Reverb · Chorus · Global); a tap sends the FM-1 to that GLO page and the tab follows it, as GLO on the FM-1
 * does. Mixer: six strips across the width. The shared pages: [bus], the card's four dials, its settings and the FM-1's grey picture
 * (decision 34). [soundDock] is the width the docked sound panel takes at the right.
 */
@Composable
fun MixTab(ui: MixUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>, modifier: Modifier = Modifier, soundDock: Dp = 0.dp, bus: @Composable () -> Unit = {}) {
    Column(modifier.fillMaxSize().padding(end = soundDock)) {
        SubPages(ui.pages, ui.page, actions.page)
        Spacer(Modifier.height(4.dp))
        LupeCrossfade(ui.page == 0, Modifier.weight(1f).fillMaxWidth()) { mixer ->
            if (mixer) Strips(ui, actions, meters) else bus()
        }
    }
}

/** The sub-pages: a quiet segmented row, the page showing a `lifted` pill (36 tall) that slides between the bare grey words. */
@Composable
private fun SubPages(pages: List<String>, current: Int, onPick: (Int) -> Unit) =
    com.scottgerstl.lupe.ui.shell.SegmentGroup(pages, current, onPick, height = 36.dp, padH = 16.dp, role = Role.Tab,
        descriptions = pages.mapIndexed { i, n -> "$n, GLO ${i + 1} of ${pages.size}" }, fontSize = 15,
        selectedFill = Tok.lifted, idleFill = null, selectedInk = Tok.text, idleInk = Tok.text2, gap = 4.dp)

@Composable
private fun Strips(ui: MixUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>) {
    Row(Modifier.fillMaxSize().semantics { isTraversalGroup = true }, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ui.tracks.forEach { t -> Strip(t, actions, meters, Modifier.weight(1f).fillMaxHeight()) }
    }
}

/**
 * One track's strip (spec 4.5): `panel` at radius 20, the selected track's tinted with a 2 dp edge in its colour. Badge and name (a tap selects the
 * track), the level fader with its meter, dB, the values line "C · Rev 12%", then Mute and Solo joined. A long press anywhere but the fader opens
 * the strip's menu at the finger: Pan, the reverb send, Select sound… (Scott, 2026-11-17: "you can longpress most things in the app for more
 * options"). TalkBack gets Pan and Reverb send as actions on the strip, so they never depend on the long press.
 */
@Composable
private fun Strip(t: MixTrackUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>, modifier: Modifier) {
    val colour = Tok.track[(t.number - 1) % Tok.track.size]
    val sel by animatedFloat(if (t.selected) 1f else 0f, Dur.STATE)
    val dim by animatedFloat(if (t.muted) 1f else 0f, Dur.STATE)
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    val haptic = LocalHapticFeedback.current
    val latest by rememberUpdatedState(t)
    Column(
        modifier
            .clip(RoundedCornerShape(20.dp))
            .background(lerp(Tok.panel, lerp(Tok.page, colour, 0.28f), sel))
            .drawBehind { if (sel > 0f) drawRoundRect(colour.copy(alpha = sel), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(19.dp.toPx()), style = Stroke(2.dp.toPx())) }
            .pointerInput(t.number) { detectTapGestures(onTap = { actions.select(latest.number) }, onLongPress = { at -> haptic.performHapticFeedback(HapticFeedbackType.LongPress); menuAt = at }) }
            .semantics {
                isTraversalGroup = true
                customActions = listOf(
                    CustomAccessibilityAction("Pan right, ${t.name}") { actions.pan(latest.number, (latest.pan + 4).coerceAtMost(127)); true },
                    CustomAccessibilityAction("Pan left, ${t.name}") { actions.pan(latest.number, (latest.pan - 4).coerceAtLeast(0)); true },
                    CustomAccessibilityAction("Pan to the centre, ${t.name}") { actions.pan(latest.number, 64); true },
                    CustomAccessibilityAction("Reverb send up, ${t.name}") { actions.send(latest.number, (latest.send + 4).coerceAtMost(127)); true },
                    CustomAccessibilityAction("Reverb send down, ${t.name}") { actions.send(latest.number, (latest.send - 4).coerceAtLeast(0)); true },
                )
            }
            .padding(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // the head: badge and name; a tap selects the track
        Row(
            Modifier.fillMaxWidth().defaultMinSize(minHeight = 32.dp)
                .semantics(mergeDescendants = true) {
                    role = Role.Button; contentDescription = "Track ${t.number}, ${t.name}"; stateDescription = if (t.selected) "Selected" else ""
                    onLongClick("Track menu: pan, reverb send, select sound") { menuAt = Offset(80f, 40f); true }
                },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TrackBadge(t.number, colour, t.selected, 24.dp, 15)
            BasicText(t.name, Modifier.weight(1f), style = LupeType.key.copy(fontSize = 15.sp, color = Tok.text, fontWeight = FontWeight.Normal), maxLines = 1,
                autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 15.sp, stepSize = 0.5.sp))
        }
        Spacer(Modifier.height(8.dp))
        // the fader and its meter, centred, taking the height
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LevelFader(t, colour, dim, { actions.level(t.number, it) }, Modifier.width(44.dp).fillMaxHeight())
            Meter(t.number, colour, dim, meters, Modifier.width(6.dp).fillMaxHeight().padding(vertical = 4.dp))
        }
        Spacer(Modifier.height(8.dp))
        BasicText(t.levelText, style = LupeType.number.copy(fontSize = 18.sp, lineHeight = 20.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center), maxLines = 1)
        Spacer(Modifier.height(2.dp))
        BasicText("${panShort(t.panText)} · Rev ${t.sendText}", style = LupeType.small.copy(color = Tok.text2Raised, textAlign = TextAlign.Center), maxLines = 1,
            autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 9.sp, maxFontSize = 12.sp, stepSize = 0.5.sp))
        Spacer(Modifier.height(6.dp))
        MuteSolo(t, actions, Modifier.fillMaxWidth())
    }
    StripMenu(t, colour, menuAt, { menuAt = null }, actions)
}

/** The FM-1's pan words shortened for the values line: centre → "C", "L12" stays. */
internal fun panShort(text: String): String = when (text.trim().uppercase()) { "", "C", "0", "CENTER", "CENTRE", "CTR", "MID" -> "C"; else -> text.trim() }

/**
 * A track badge: the number on the track's colour. Shape as state (spec 3.2): round when not selected, squared to about a third of its size
 * when selected, on the spring (with Reduce Motion it lands at once; the colour never changes).
 */
@Composable
fun TrackBadge(number: Int, colour: Color, selected: Boolean, size: Dp, fontSize: Int) {
    val reduce = LocalReduceMotion.current
    val m = hybridMotion
    val sq by springFloat(if (selected) 1f else 0f, m.fingerMs, m.bounce, spring = !reduce)
    Box(
        Modifier.size(size).drawBehind {
            val s = sq.coerceIn(0f, 1.2f)   // Reduce Motion: the corners ease over 150 ms, no overshoot
            val half = this.size.minDimension / 2
            val r = half - (half - this.size.minDimension * 0.3f) * s
            drawRoundRect(colour, cornerRadius = CornerRadius(r.coerceAtLeast(2f)))
        },
        contentAlignment = Alignment.Center,
    ) { BasicText("$number", style = LupeType.number.copy(fontSize = fontSize.sp, lineHeight = fontSize.sp, fontWeight = FontWeight.Bold, color = Tok.onColour)) }
}

/**
 * The level fader, drawn up (spec 3.13): a 32-wide `control` track at radius 14, the level in the track's colour (its top corners 5), and a line
 * handle 44 × 6 in `text` that grows to 1.6× its height while held (150 ms, back on the spring). Slid up and down whatever Slide to turn says
 * (a fader follows its own axis); the Magnifier shows the value. Double tap puts it back to what it was when the tab opened. TalkBack: the
 * range, Increase, Decrease and Put back.
 */
@Composable
private fun LevelFader(t: MixTrackUi, colour: Color, dim: Float, onSet: (Int) -> Unit, modifier: Modifier) {
    val reduce = LocalReduceMotion.current
    val m = hybridMotion
    var optimistic by remember { mutableIntStateOf(Int.MIN_VALUE) }
    androidx.compose.runtime.LaunchedEffect(t.level) { if (optimistic == t.level) optimistic = Int.MIN_VALUE }
    val raw = if (optimistic != Int.MIN_VALUE) optimistic else t.level
    val latestValue by rememberUpdatedState(t.level)
    val send by rememberUpdatedState(onSet)
    val latestText by rememberUpdatedState(t.levelText)
    val opened = remember(t.number) { t.level }
    var base by remember { mutableIntStateOf(0) }
    var held by remember { mutableStateOf(false) }
    fun now() = if (optimistic != Int.MIN_VALUE) optimistic else latestValue
    fun set(v: Int) { val n = v.coerceIn(0, 127); if (n != now()) { optimistic = n; send(n) } }
    val haptic = LocalHapticFeedback.current
    val grow by springFloat(if (held) 1.6f else 1f, if (held) 150 else m.fingerMs, m.bounce, spring = !reduce)
    Box(
        modifier
            .semantics(mergeDescendants = true) {
                contentDescription = "Level, ${t.name}"; stateDescription = t.levelText
                progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), 0f..127f, 126)
                setProgress { v -> set(v.roundToInt()); true }
                customActions = listOf(
                    CustomAccessibilityAction("Increase level, ${t.name}") { set(now() + 1); true },
                    CustomAccessibilityAction("Decrease level, ${t.name}") { set(now() - 1); true },
                    CustomAccessibilityAction("Put level back, ${t.name}") { set(opened); true },
                )
            }
            .pointerInput(opened) { detectTapGestures(onDoubleTap = { set(opened); haptic.performHapticFeedback(HapticFeedbackType.Confirm) }) }
            .slideToTurn(
                enabled = true, stepDp = 2f,
                face = remember(t.number, colour) { MagnifierFace("LEVEL · ${t.name}", { latestText }, { now() / 127f }, tint = colour) },
                onStart = { base = now(); held = true }, onSlide = { set(base + it) }, onEnd = { held = false },
                bounds = { -now()..(127 - now()) },
                forceDirection = SlideDirection.UpDown,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            val trackW = 32.dp.toPx(); val x0 = (size.width - trackW) / 2
            val handleH = 6.dp.toPx(); val inset = handleH
            val usable = size.height - 2 * inset
            val y = inset + usable * (1f - raw / 127f)
            val fill = lerp(colour, Tok.text3, dim)
            drawRoundRect(Tok.control, Offset(x0, 0f), Size(trackW, size.height), CornerRadius(14.dp.toPx()))
            // the level, from the foot up to the handle: its top corners 5, its foot following the track's round end
            val top = CornerRadius(5.dp.toPx()); val foot = CornerRadius(14.dp.toPx())
            if (size.height - y > 1f) drawPath(Path().apply { addRoundRect(RoundRect(x0, y, x0 + trackW, size.height, top, top, foot, foot)) }, fill)
            // unity: a short tick beside the track
            val uy = inset + usable * (1f - UNITY / 127f)
            drawRect(Tok.text3, Offset(x0 - 5.dp.toPx(), uy - 0.75.dp.toPx()), Size(3.dp.toPx(), 1.5.dp.toPx()))
            val h = handleH * (if (reduce) (if (held) 1.6f else 1f) else grow)
            drawRoundRect(lerp(Tok.text, Tok.text2, dim), Offset(0f, y - h / 2), Size(size.width, h), CornerRadius(3.dp.toPx()))
        }
    }
}

/** The track's meter beside its fader: 6 wide, the track's colour at 80 %, read while drawing (20 updates a second redraw only this). */
@Composable
private fun Meter(track: Int, colour: Color, dim: Float, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>, modifier: Modifier) {
    Canvas(modifier.clearAndSetSemantics { }) {
        drawRoundRect(Tok.control, cornerRadius = CornerRadius(3.dp.toPx()))
        val v = (meters.value.levels.getOrNull(track - 1)?.toFloat() ?: 0f).coerceIn(0f, 1f)
        if (v > 0f) drawRoundRect(lerp(colour, Tok.text3, dim).copy(alpha = 0.8f), Offset(0f, size.height * (1f - v)), Size(size.width, size.height * v), CornerRadius(3.dp.toPx()))
    }
}

/**
 * Mute and Solo, joined (spec 3.4: a connected pair, labelled; Google's own study found dropping the words cost usability). Each is a switch: on,
 * the white key with a pill radius (shape as state); off, `control` with the inner corners 8.
 */
@Composable
private fun MuteSolo(t: MixTrackUi, actions: MixActions, modifier: Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        ToggleSegment("Mute", "Mute ${t.name}", t.muted, if (t.muted) "Muted" else "Not muted", first = true, last = false, Modifier.weight(1f)) { actions.mute(t.number) }
        ToggleSegment("Solo", "Solo ${t.name}", t.solo, if (t.solo) "Solo" else "Not solo", first = false, last = true, Modifier.weight(1f)) { actions.solo(t.number) }
    }
}

/** A switch drawn as one end of a connected pair: on, the white key gone fully round; off, `control` with its inner corners 8. */
@Composable
fun ToggleSegment(label: String, description: String, on: Boolean, state: String, first: Boolean, last: Boolean, modifier: Modifier = Modifier, height: Dp = 36.dp, onClick: () -> Unit) {
    val reduce = LocalReduceMotion.current
    val m = hybridMotion
    val shape by springFloat(if (on) 1f else 0f, m.fingerMs, m.bounce, spring = !reduce)
    val lit by animatedFloat(if (on) 1f else 0f, Dur.STATE)
    Box(
        modifier.defaultMinSize(minHeight = 44.dp)
            .semantics(mergeDescendants = true) { role = Role.Switch; contentDescription = description; stateDescription = state }
            .clickable(remember { MutableInteractionSource() }, null, role = Role.Switch, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.fillMaxWidth().height(height).drawBehind {
                val pill = size.height / 2; val inner = 8.dp.toPx()
                val s = shape.coerceIn(0f, 1.2f)
                fun r(outer: Boolean) = if (outer) pill else inner + (pill - inner) * s
                val l = CornerRadius(r(first).coerceAtMost(pill)); val rr = CornerRadius(r(last).coerceAtMost(pill))
                drawPath(Path().apply { addRoundRect(RoundRect(0f, 0f, size.width, size.height, l, rr, rr, l)) }, Tok.control)
                // on: the white grows out from the middle as the corners round (Reduce Motion: it fades in where it stands)
                val g = if (reduce) 1f else (0.55f + 0.45f * s).coerceAtMost(1.04f)
                if (lit > 0f) { val w = size.width * g; val h = size.height * g; val x = (size.width - w) / 2; val y = (size.height - h) / 2
                    drawPath(Path().apply { addRoundRect(RoundRect(x, y, x + w, y + h, CornerRadius(l.x * g), CornerRadius(rr.x * g), CornerRadius(rr.x * g), CornerRadius(l.x * g))) }, Tok.text.copy(alpha = lit)) }
            },
            contentAlignment = Alignment.Center,
        ) { BasicText(label, style = LupeType.key.copy(fontSize = 13.sp, color = lerp(Tok.text2, Tok.onColour, lit), fontWeight = FontWeight.SemiBold), maxLines = 1) }
    }
}

/**
 * The strip's long-press menu at the finger (`phone-06b`): the track's badge and name, a centred Pan slider, the Reverb send, a divider, then
 * Select sound…. On `held`, with its secondary text in `textSecondaryRaised`.
 */
@Composable
private fun StripMenu(t: MixTrackUi, colour: Color, at: Offset?, close: () -> Unit, actions: MixActions) {
    LupeMenu(at != null, close, width = 272.dp, at = at) {
        Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TrackBadge(t.number, colour, true, 24.dp, 15)
            BasicText(t.name, style = LupeType.key.copy(fontSize = 16.sp, color = Tok.text), maxLines = 1)
        }
        MenuSlider("Pan", t.name, t.pan, t.panText, colour, bipolarAt = 64) { actions.pan(t.number, it) }
        MenuSlider("Reverb send", t.name, t.send, t.sendText, colour, bipolarAt = null) { actions.send(t.number, it) }
        MenuDivider()
        val sounds = com.scottgerstl.lupe.ui.sounds.LocalSoundsHost.current
        MenuRow("Select sound…", { close(); sounds.open(t.number) })
    }
}

/**
 * A slider in a menu (spec 3.13's send): its label and value over an 8-tall track with a 4 × 16 handle; Pan fills from its centre mark. Slid
 * sideways; double tap puts it back to what it was when the menu opened. TalkBack: range, Increase, Decrease, Put back. The unfilled track
 * against the menu is low contrast (spec 7, `[open]`); the handle and the fill carry the value.
 */
@Composable
private fun MenuSlider(what: String, track: String, value: Int, text: String, colour: Color, bipolarAt: Int?, onSet: (Int) -> Unit) {
    var optimistic by remember { mutableIntStateOf(Int.MIN_VALUE) }
    androidx.compose.runtime.LaunchedEffect(value) { if (optimistic == value) optimistic = Int.MIN_VALUE }
    val raw = if (optimistic != Int.MIN_VALUE) optimistic else value
    val latestValue by rememberUpdatedState(value)
    val send by rememberUpdatedState(onSet)
    val latestText by rememberUpdatedState(text)
    val opened = remember(track, what) { value }
    var base by remember { mutableIntStateOf(0) }
    fun now() = if (optimistic != Int.MIN_VALUE) optimistic else latestValue
    fun set(v: Int) { val n = v.coerceIn(0, 127); if (n != now()) { optimistic = n; send(n) } }
    Column(
        Modifier.fillMaxWidth().defaultMinSize(minHeight = 52.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = "$what, $track"; stateDescription = text
                progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), 0f..127f, 126)
                setProgress { v -> set(v.roundToInt()); true }
                customActions = listOf(
                    CustomAccessibilityAction("Increase ${what.lowercase()}") { set(now() + 1); true },
                    CustomAccessibilityAction("Decrease ${what.lowercase()}") { set(now() - 1); true },
                    CustomAccessibilityAction("Put ${what.lowercase()} back") { set(opened); true },
                )
            }
            .pointerInput(opened) { detectTapGestures(onDoubleTap = { set(opened) }) }
            .slideToTurn(
                enabled = true, stepDp = 2f,
                face = remember(track, what, colour) { MagnifierFace("${what.uppercase()} · $track", { latestText }, { now() / 127f }, bipolar = bipolarAt != null, tint = colour) },
                onStart = { base = now() }, onSlide = { set(base + it) }, bounds = { -now()..(127 - now()) }, forceDirection = SlideDirection.Sideways,
            )
            .padding(horizontal = 16.dp, vertical = 6.dp),
    ) {
        Row(Modifier.fillMaxWidth()) {
            BasicText(what, Modifier.weight(1f), style = LupeType.small.copy(fontSize = 13.sp, color = Tok.text2Raised))
            BasicText(text, style = LupeType.number.copy(fontSize = 15.sp, lineHeight = 16.sp))
        }
        Spacer(Modifier.height(8.dp))
        Canvas(Modifier.fillMaxWidth().height(16.dp)) {
            val th = 8.dp.toPx(); val y = (size.height - th) / 2
            val hw = 4.dp.toPx()
            val x = hw / 2 + (size.width - hw) * (raw / 127f)
            drawRoundRect(Tok.lifted, Offset(0f, y), Size(size.width, th), CornerRadius(th / 2))
            if (bipolarAt != null) {
                val cx = hw / 2 + (size.width - hw) * (bipolarAt / 127f)
                drawRoundRect(colour, Offset(minOf(cx, x), y), Size(kotlin.math.abs(x - cx).coerceAtLeast(2.dp.toPx()), th), CornerRadius(2.dp.toPx()))
                drawRect(Tok.text2, Offset(cx - 0.75.dp.toPx(), y - 3.dp.toPx()), Size(1.5.dp.toPx(), th + 6.dp.toPx()))
            } else drawRoundRect(colour, Offset(0f, y), Size(x, th), CornerRadius(th / 2))
            drawRoundRect(Tok.text, Offset(x - hw / 2, 0f), Size(hw, size.height), CornerRadius(2.dp.toPx()))
        }
    }
}

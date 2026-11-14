package com.scottgerstl.lupe.ui.mix

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.page.PageControlsRow
import com.scottgerstl.lupe.ui.settings.Segmented
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.shell.KeyLabel
import com.scottgerstl.lupe.ui.shell.LupeMenu
import com.scottgerstl.lupe.ui.shell.MenuHeading
import com.scottgerstl.lupe.ui.slide.LocalMagnifier
import com.scottgerstl.lupe.ui.slide.MagnifierFace
import com.scottgerstl.lupe.ui.slide.slideToTurn
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlin.math.roundToInt

/**
 * The Mix pop-up (decision 31, board 77): GLO's five pages one at a time. No title: MIXER DELAY REVERB CHORUS GLOBAL sit as words in one
 * line with the close key, and the room goes to the page. Mixer is the six tracks as rows: LEVEL on a fader in the track's colour, Mute,
 * and the row's hold menu for PAN and the reverb send. Delay, Reverb, Chorus and Global are the shared buses: four white dials at the
 * left (white because turning them changes every track) and the FM-1's own picture at the right, at its 1.7 : 1.
 */
@Composable
fun MixPage(ui: MixUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>, onClose: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
            WordTabs(ui.pages.map { it.uppercase() }, ui.page) { actions.page(it) }
            BasicText("${ui.page + 1}/${ui.pages.size}", Modifier.padding(start = 16.dp).clearAndSetSemantics { }, style = LupeType.number.copy(fontSize = 15.sp, color = Tok.text2))
            androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
            Key(onClose, "Close Mix", width = 40.dp, height = 36.dp, minTarget = 44.dp) { fg ->
                Canvas(Modifier.width(12.dp).height(12.dp)) {
                    val w = 2.dp.toPx()
                    drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), w, androidx.compose.ui.graphics.StrokeCap.Round)
                    drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), w, androidx.compose.ui.graphics.StrokeCap.Round)
                }
            }
        }
        LupeCrossfade(ui.page, Modifier.weight(1f).fillMaxWidth(), Dur.STATE) { p ->
            if (p == 0) Mixer(ui, actions, meters) else BusPage(ui, p, actions)
        }
    }
}

/** The pages as words in a line, the chosen one white with a line under it (the header's tabs, smaller); the line and the ink blend from one to the next. */
@Composable
private fun WordTabs(labels: List<String>, selected: Int, onPick: (Int) -> Unit) {
    Row(Modifier.semantics { isTraversalGroup = true }, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        labels.forEachIndexed { i, label ->
            val on = animatedFloat(if (i == selected) 1f else 0f, Dur.STATE)
            Box(
                Modifier.height(44.dp)
                    .semantics(mergeDescendants = true) { role = Role.Tab; this.selected = i == selected; contentDescription = "Mix page: " + label.lowercase().replaceFirstChar { it.uppercase() } }
                    .pointerInput(i) { detectTapGestures { onPick(i) } }
                    .padding(horizontal = 8.dp)
                    .drawBehind { if (on.value > 0f) drawRect(Tok.text.copy(alpha = on.value), Offset(0f, size.height - 8.dp.toPx()), Size(size.width, 2.dp.toPx())) },
                contentAlignment = Alignment.Center,
            ) { BasicText(label, style = LupeType.key.copy(fontSize = 15.sp, color = lerp(Tok.text2, Tok.text, on.value))) }
        }
    }
}

@Composable
private fun Mixer(ui: MixUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val gap = 4.dp
        // landscape: the six tracks in two columns of three, so each row keeps a long fader and room for its meter and send line
        val cols = if (maxWidth >= 600.dp) 2 else 1
        val rows = ((ui.tracks.size + cols - 1) / cols).coerceAtLeast(1)
        val rh = ((maxHeight - gap * (rows - 1)) / rows).coerceAtLeast(36.dp)
        val roomy = rh >= 64.dp      // the meter and the send line show
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ui.tracks.chunked(rows).forEach { col ->
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(gap)) { col.forEach { t -> TrackRow(t, rh, roomy, actions, meters) } }
            }
        }
    }
}

@Composable
private fun TrackRow(t: MixTrackUi, h: androidx.compose.ui.unit.Dp, roomy: Boolean, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>) {
    val colour = Tok.track[(t.number - 1) % Tok.track.size]
    val haptic = LocalHapticFeedback.current
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    val selected = animatedFloat(if (t.selected) 1f else 0f, Dur.STATE)
    val dim = animatedFloat(if (t.muted) 1f else 0f, Dur.STATE)
    Row(
        Modifier.fillMaxWidth().height(h).clip(RoundedCornerShape(8.dp)).background(Tok.panel)
            .semantics { onLongClick("Track menu: pan and reverb send") { menuAt = Offset(80f, 40f); true } }
            .pointerInput(t.number) { detectTapGestures(onLongPress = { at -> haptic.performHapticFeedback(HapticFeedbackType.LongPress); menuAt = at }) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // the number (tap: select the track), the track's colour
        Box(
            Modifier.width(36.dp).fillMaxHeight().background(colour, RoundedCornerShape(topStart = 8.dp, bottomStart = 8.dp))
                .drawBehind { drawRoundRect(Tok.text.copy(alpha = selected.value), cornerRadius = CornerRadius(8.dp.toPx()), style = Stroke(4.dp.toPx())) }
                .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Track ${t.number}, ${t.name}" + if (t.solo) ", solo" else ""; stateDescription = if (t.selected) "Selected" else "" }
                .pointerInput(t.number) { detectTapGestures { actions.select(t.number) } },
            contentAlignment = Alignment.Center,
        ) { BasicText("${t.number}", style = LupeType.key.copy(fontSize = 16.sp, color = Tok.onColour)) }
        Column(Modifier.width(92.dp).padding(horizontal = 8.dp), verticalArrangement = Arrangement.Center) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                BasicText(t.name, Modifier.weight(1f, fill = false), style = LupeType.key.copy(fontSize = 14.sp), maxLines = 1, autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 14.sp, stepSize = 0.5.sp))
                // solo: a lit pill with the word (never the colour alone)
                if (t.solo) BasicText("SOLO", Modifier.background(Tok.primaryTop, RoundedCornerShape(4.dp)).padding(horizontal = 4.dp, vertical = 1.dp), style = LupeType.label.copy(fontSize = 10.sp, lineHeight = 11.sp, color = Tok.onColour))
            }
            BasicText("${t.levelText} · ${t.panText}", style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1)
        }
        Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.Center) {
            if (roomy) BasicText("LEVEL · send REV ${t.sendText}", style = LupeType.small.copy(fontSize = 12.sp), maxLines = 1)
            LevelFader(t, colour, dim.value, actions)
            if (roomy) {
                Canvas(Modifier.padding(top = 6.dp).fillMaxWidth().height(4.dp).clearAndSetSemantics { }) {
                    drawRect(Tok.control)
                    drawRect(lerp(colour, Tok.text3, dim.value).copy(alpha = 0.55f), size = Size(size.width * (t.send / 127f), size.height))
                }
                // the meter: the core's `meters` area, read while drawing so 20 updates a second redraw only this line
                Canvas(Modifier.padding(top = 3.dp).fillMaxWidth().height(3.dp).clearAndSetSemantics { }) {
                    drawRect(Tok.control)
                    val m = meters.value.levels.getOrNull(t.number - 1)?.toFloat() ?: 0f
                    drawRect(lerp(colour, Tok.text3, dim.value), size = Size(size.width * m.coerceIn(0f, 1f), size.height))
                }
            }
        }
        Box(Modifier.padding(horizontal = 6.dp)) {
            Key({ actions.mute(t.number) }, "Mute ${t.name}", width = 56.dp, height = 32.dp, minTarget = 40.dp, on = t.muted, role = Role.Switch, state = if (t.muted) "Muted" else "Not muted") { fg ->
                KeyLabel("Mute", fg, style = LupeType.key.copy(fontSize = 13.sp))
            }
        }
    }
    RowMenu(t, menuAt, { menuAt = null }, actions)
}

/** The level fader: drawn across, turned by the slide setting (up and down by default), the Magnifier above the finger. */
@Composable
private fun LevelFader(t: MixTrackUi, colour: Color, dim: Float, actions: MixActions) {
    var optimistic by remember { mutableIntStateOf(Int.MIN_VALUE) }
    androidx.compose.runtime.LaunchedEffect(t.level) { if (optimistic == t.level) optimistic = Int.MIN_VALUE }
    val raw = if (optimistic != Int.MIN_VALUE) optimistic else t.level
    val latest by rememberUpdatedState(t)
    val send by rememberUpdatedState(actions.level)
    val opened = remember(t.number) { t.level }
    var base by remember { mutableIntStateOf(0) }
    fun now() = if (optimistic != Int.MIN_VALUE) optimistic else latest.level
    fun set(v: Int) { val n = v.coerceIn(0, 127); if (n != now()) { optimistic = n; send(latest.number, n) } }
    val haptic = LocalHapticFeedback.current
    Box(
        Modifier.fillMaxWidth().height(34.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = "Level, ${t.name}"; stateDescription = t.levelText; role = Role.Button
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
                face = remember(t.name, colour) { MagnifierFace("LEVEL · ${t.name}", { latest.levelText }, { now() / 127f }, tint = colour) },
                onStart = { base = now() }, onSlide = { set(base + it) },
                bounds = { -now()..(127 - now()) },
                forceDirection = com.scottgerstl.lupe.ui.slide.SlideDirection.Sideways,   // drawn across: it follows the finger across (decision 10's setting is for knobs and value boxes)
            ),
        contentAlignment = Alignment.CenterStart,
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val trackH = 6.dp.toPx(); val y = (size.height - trackH) / 2
            val thumbW = 26.dp.toPx(); val thumbH = 20.dp.toPx()
            val x = thumbW / 2 + (size.width - thumbW) * (raw / 127f)
            val fill = lerp(colour, Tok.text3, dim)
            drawRoundRect(Tok.control, Offset(0f, y), Size(size.width, trackH), CornerRadius(trackH / 2))
            drawRoundRect(fill, Offset(0f, y), Size(x, trackH), CornerRadius(trackH / 2))
            drawRoundRect(lerp(Tok.primaryTop, Tok.text2, dim), Offset(x - thumbW / 2, (size.height - thumbH) / 2), Size(thumbW, thumbH), CornerRadius(8.dp.toPx()))
        }
    }
}

/** The row's hold menu, beside the finger: PAN and the reverb send, each turned by sliding (the Magnifier would sit behind this window, so the value is large here). */
@Composable
private fun RowMenu(t: MixTrackUi, at: Offset?, close: () -> Unit, actions: MixActions) {
    LupeMenu(at != null, close, width = 248.dp, at = at) {
        MenuHeading("${t.number} ${t.name}")
        val sounds = com.scottgerstl.lupe.ui.sounds.LocalSoundsHost.current
        com.scottgerstl.lupe.ui.shell.MenuRow("Solo", { actions.solo(t.number); close() }, checked = t.solo, sub = "Plays this track alone")
        com.scottgerstl.lupe.ui.shell.MenuRow("Sounds…", { close(); sounds.open(t.number) })
        CompositionLocalProvider(LocalMagnifier provides null) {
            MenuSlide("PAN", t.panText, t.pan, "Pan, ${t.name}", bipolar = true, mid = 64) { actions.pan(t.number, it) }
            MenuSlide("REVERB SEND", t.sendText, t.send, "Reverb send, ${t.name}") { actions.send(t.number, it) }
        }
    }
}

@Composable
private fun MenuSlide(label: String, text: String, raw: Int, name: String, bipolar: Boolean = false, mid: Int = 0, onSet: (Int) -> Unit) {
    val latest by rememberUpdatedState(raw)
    val send by rememberUpdatedState(onSet)
    var base by remember { mutableIntStateOf(0) }
    val colour = Tok.text
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp).clip(RoundedCornerShape(8.dp)).background(Tok.well)
            .semantics(mergeDescendants = true) {
                contentDescription = name; stateDescription = text; role = Role.Button
                progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), 0f..127f, 126)
                setProgress { v -> send(v.roundToInt().coerceIn(0, 127)); true }
                customActions = listOf(CustomAccessibilityAction("Increase $name") { send((latest + 1).coerceIn(0, 127)); true }, CustomAccessibilityAction("Decrease $name") { send((latest - 1).coerceIn(0, 127)); true })
            }
            .slideToTurn(enabled = true, stepDp = 2f, face = null, onStart = { base = latest }, onSlide = { send((base + it).coerceIn(0, 127)) }, bounds = { -latest..(127 - latest) })
            .padding(10.dp),
    ) {
        BasicText(label, style = LupeType.number.copy(fontSize = 12.sp, color = Tok.text2, letterSpacing = 0.5.sp))
        BasicText(text, style = LupeType.number.copy(fontSize = 28.sp, lineHeight = 30.sp))
        Canvas(Modifier.padding(top = 4.dp).fillMaxWidth().height(3.dp)) {
            drawRect(Tok.stepEmpty)
            val x = (raw / 127f) * size.width; val from = if (bipolar) (mid / 127f) * size.width else 0f
            drawRect(colour, Offset(minOf(from, x), 0f), Size(maxOf(kotlin.math.abs(x - from), if (bipolar) 2f else 0f), size.height))
        }
    }
}

/**
 * Delay, Reverb, Chorus, Global (board 77, decision 34): the page's four dials two by two at the left, white because they are shared, with
 * the card's settings (DELAY MODE) under them; at the right the FM-1's own picture of the page at its 1.7 : 1, in the global greys and
 * white. With Show graphics off the dials take the width.
 */
@Composable
private fun BusPage(ui: MixUi, p: Int, actions: MixActions) {
    val graphics = com.scottgerstl.lupe.ui.slide.LocalPhoneSettings.current.showGraphics
    val picture = ui.graph?.takeIf { graphics && com.scottgerstl.lupe.ui.page.hasPicture(it) }
    Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            com.scottgerstl.lupe.ui.page.PageControlsGrid(ui.bus, Tok.text, opened = { _, c -> c.raw }, onSet = { slot, v -> actions.setBus(slot, v) }, modifier = Modifier.weight(1f).fillMaxWidth())
            // the card's settings (DELAY MODE on 2.5.1): a choice, not a knob
            ui.settings.forEachIndexed { i, c ->
                // the core may publish the label as "DLY MODE" and no names: the screen says DELAY MODE and knows its three
                val label = if (c.label.equals("DLY MODE", true)) "DELAY MODE" else c.label
                val names = c.names.ifEmpty { if (label == "DELAY MODE") com.scottgerstl.lupe.core.FakeP5.DELAY_MODES else emptyList() }
                if (names.size in 2..4) Segmented(names, c.raw.coerceIn(0, names.lastIndex), label) { actions.setSetting(i, it) }
                else BasicText("$label  ${c.value}", style = LupeType.key)
            }
        }
        // 936 : 552 is the FM-1's graph panel
        if (picture != null) Box(Modifier.fillMaxHeight().aspectRatio(936f / 552f).clip(RoundedCornerShape(8.dp)).background(Tok.well)) {
            com.scottgerstl.lupe.ui.page.GraphContent(picture, Tok.text2Raised, -1, Modifier.fillMaxSize())
        }
    }
}

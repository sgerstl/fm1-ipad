package com.scottgerstl.lupe.ui.mix

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.size
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

/** The Mix row's measures (the iPhone's PhoneMixerRow, 5ce07a3; dp): 48 tall, 4 apart, the head 92 wide, PAN and the send 84, Mute and Solo 40, the level fader at least 120. */
object MixRowSpec {
    const val HEIGHT = 48f
    const val GAP = 4f
    const val HEAD = 92f
    const val PAN = 84f
    const val SEND = 84f
    const val KEY = 40f
    const val LEVEL_MIN = 120f
    /** The row height for [available] dp and [rows] rows: 48, or less when the six don't fit (never under 36). */
    fun rowHeight(available: Float, rows: Int): Float = ((available - GAP * (rows - 1)) / rows.coerceAtLeast(1)).coerceIn(36f, HEIGHT)
}

/**
 * The Mix tab (batch item 11; decision 49: the iPhone's): one column of the six tracks, each row lined up like the Pads rows: the track head (its number chip
 * in the track's colour and its name; a tap selects it), then LEVEL, PAN and the reverb SEND as faders right in the row (no long press), Mute and Solo, and the
 * track's meter as a thin line along the row's leading edge. [soundDock] is the width the docked sound panel takes at the right.
 */
@Composable
fun MixTab(ui: MixUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>, modifier: Modifier = Modifier, soundDock: androidx.compose.ui.unit.Dp = 0.dp) {
    Box(modifier.fillMaxSize().padding(end = soundDock)) { Mixer(ui, actions, meters) }
}

@Composable
private fun Mixer(ui: MixUi, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>) {
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val rh = MixRowSpec.rowHeight(maxHeight.value, ui.tracks.size).dp
        Column(Modifier.padding(start = 8.dp), verticalArrangement = Arrangement.spacedBy(MixRowSpec.GAP.dp)) {
            ui.tracks.forEach { t -> TrackRow(t, rh, actions, meters) }
        }
    }
}

@Composable
private fun TrackRow(t: MixTrackUi, h: androidx.compose.ui.unit.Dp, actions: MixActions, meters: androidx.compose.runtime.State<com.scottgerstl.lupe.core.MetersState>) {
    val colour = Tok.track[(t.number - 1) % Tok.track.size]
    val sel = animatedFloat(if (t.selected) 1f else 0f, Dur.STATE)
    val dim = animatedFloat(if (t.muted) 1f else 0f, Dur.STATE)
    var menuAt by remember { mutableStateOf<Offset?>(null) }
    val haptic = LocalHapticFeedback.current
    Box(Modifier.fillMaxWidth().height(h)) {
        // the track's meter, read while drawing (20 updates a second redraw only this line): a live line in its colour along the row's leading edge
        Canvas(Modifier.align(Alignment.CenterStart).offset(x = (-6).dp).width(3.dp).fillMaxHeight().padding(vertical = 6.dp).clearAndSetSemantics { }) {
            drawRoundRect(Tok.control, cornerRadius = CornerRadius(1.5.dp.toPx()))
            val m = (meters.value.levels.getOrNull(t.number - 1)?.toFloat() ?: 0f).coerceIn(0f, 1f)
            if (m > 0f) drawRoundRect(lerp(colour, Tok.text3, dim.value), Offset(0f, size.height * (1f - m)), Size(size.width, size.height * m), CornerRadius(1.5.dp.toPx()))
        }
        Row(
            Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)).background(lerp(Tok.well, colour, 0.28f * sel.value)).padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // the head: the number chip and the name; a tap selects the track, a hold has Sounds…
            Row(
                Modifier.width(MixRowSpec.HEAD.dp).fillMaxHeight().defaultMinSize(minHeight = 44.dp)
                    .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Track ${t.number}, ${t.name}"; stateDescription = if (t.selected) "Selected" else ""
                        onLongClick("Track menu: Sounds") { menuAt = Offset(80f, 40f); true } }
                    .pointerInput(t.number) { detectTapGestures(onTap = { actions.select(t.number) }, onLongPress = { at -> haptic.performHapticFeedback(HapticFeedbackType.LongPress); menuAt = at }) },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(Modifier.size(28.dp).background(colour, RoundedCornerShape(7.dp)), contentAlignment = Alignment.Center) { BasicText("${t.number}", style = LupeType.key.copy(fontSize = 15.sp, color = Tok.onColour)) }
                BasicText(t.name, Modifier.weight(1f), style = LupeType.key.copy(fontSize = 13.sp, color = if (t.selected) Tok.text else Tok.text2Raised), maxLines = 1,
                    autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 13.sp, stepSize = 0.5.sp))
            }
            RowFader("Level", t.name, t.level, t.levelText, if (t.muted) Tok.text3 else colour, dim.value, bipolarAt = null, onSet = { actions.level(t.number, it) }, modifier = Modifier.weight(1f).defaultMinSize(minWidth = MixRowSpec.LEVEL_MIN.dp), detent = UNITY)
            RowFader("Pan", t.name, t.pan, t.panText, colour, 0f, bipolarAt = 64, onSet = { actions.pan(t.number, it) }, modifier = Modifier.width(MixRowSpec.PAN.dp))
            RowFader("Reverb send", t.name, t.send, t.sendText, colour, 0f, bipolarAt = null, onSet = { actions.send(t.number, it) }, modifier = Modifier.width(MixRowSpec.SEND.dp))
            Key({ actions.mute(t.number) }, "Mute ${t.name}", width = MixRowSpec.KEY.dp, height = MixRowSpec.KEY.dp, minTarget = 40.dp, on = t.muted, role = Role.Switch, state = if (t.muted) "Muted" else "Not muted") { fg ->
                androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(if (t.muted) com.scottgerstl.lupe.R.drawable.ms_volume_off else com.scottgerstl.lupe.R.drawable.ms_volume_up), null,
                    Modifier.size(18.dp), colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(fg))
            }
            Key({ actions.solo(t.number) }, "Solo ${t.name}", width = MixRowSpec.KEY.dp, height = MixRowSpec.KEY.dp, minTarget = 40.dp, on = t.solo, role = Role.Switch, state = if (t.solo) "Solo" else "Not solo") { fg ->
                androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(com.scottgerstl.lupe.R.drawable.ms_headphones), null,
                    Modifier.size(18.dp), colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(fg))
            }
        }
    }
    RowMenu(t, menuAt, { menuAt = null }, actions)
}

/** The level's unity (the FM-1's 0 dB): a small detent while sliding across it. */
const val UNITY = 100

/**
 * A horizontal fader in a row, turned by sliding across it (LEVEL, PAN, the reverb SEND): the track, the fill in the track's colour (from the centre for PAN), a thumb. The
 * Magnifier shows its name and value above the finger. TalkBack gets the range, Increase, Decrease and, for LEVEL, put back. Double tap puts it back to what it was when the row
 * appeared. [detent] is a value the slide slows at.
 */
@Composable
private fun RowFader(
    what: String, track: String, value: Int, text: String, colour: Color, dim: Float, bipolarAt: Int?, onSet: (Int) -> Unit, modifier: Modifier = Modifier, detent: Int? = null,
) {
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
    val haptic = LocalHapticFeedback.current
    Box(
        modifier.fillMaxHeight().defaultMinSize(minHeight = 40.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = "$what, $track"; stateDescription = text; role = Role.Button
                progressBarRangeInfo = ProgressBarRangeInfo(raw.toFloat(), 0f..127f, 126)
                setProgress { v -> set(v.roundToInt()); true }
                customActions = listOf(
                    CustomAccessibilityAction("Increase ${what.lowercase()}, $track") { set(now() + 1); true },
                    CustomAccessibilityAction("Decrease ${what.lowercase()}, $track") { set(now() - 1); true },
                    CustomAccessibilityAction("Put ${what.lowercase()} back, $track") { set(opened); true },
                )
            }
            .pointerInput(opened) { detectTapGestures(onDoubleTap = { set(opened); haptic.performHapticFeedback(HapticFeedbackType.Confirm) }) }
            .slideToTurn(
                enabled = true, stepDp = 2f,
                face = remember(track, what, colour) { MagnifierFace("${what.uppercase()} · $track", { latestText }, { now() / 127f }, bipolar = bipolarAt != null, tint = colour) },
                onStart = { base = now() }, onSlide = { set(base + it) },
                bounds = { -now()..(127 - now()) },
                forceDirection = com.scottgerstl.lupe.ui.slide.SlideDirection.Sideways,   // drawn across: it follows the finger across
            ),
        contentAlignment = Alignment.CenterStart,
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val trackH = 6.dp.toPx(); val y = (size.height - trackH) / 2
            val thumbW = 22.dp.toPx(); val thumbH = 20.dp.toPx()
            val x = thumbW / 2 + (size.width - thumbW) * (raw / 127f)
            val fill = lerp(colour, Tok.text3, dim)
            drawRoundRect(Tok.control, Offset(0f, y), Size(size.width, trackH), CornerRadius(trackH / 2))
            if (bipolarAt != null) {
                val cx = thumbW / 2 + (size.width - thumbW) * (bipolarAt / 127f)
                drawRoundRect(fill, Offset(minOf(cx, x), y), Size(kotlin.math.abs(x - cx).coerceAtLeast(2.dp.toPx()), trackH), CornerRadius(trackH / 2))
                drawRect(Tok.text3, Offset(cx - 0.75.dp.toPx(), y - 3.dp.toPx()), Size(1.5.dp.toPx(), trackH + 6.dp.toPx()))      // the centre mark
            } else {
                drawRoundRect(fill, Offset(0f, y), Size(x, trackH), CornerRadius(trackH / 2))
                if (detent != null) drawRect(Tok.text3, Offset(thumbW / 2 + (size.width - thumbW) * (detent / 127f) - 0.75.dp.toPx(), y - 3.dp.toPx()), Size(1.5.dp.toPx(), trackH + 6.dp.toPx()))
            }
            drawRoundRect(lerp(Tok.primaryTop, Tok.text2, dim), Offset(x - thumbW / 2, (size.height - thumbH) / 2), Size(thumbW, thumbH), CornerRadius(7.dp.toPx()))
        }
    }
}

/** The row's hold menu (an extra beside the faders): Solo and Sounds…, as the track head has. */
@Composable
private fun RowMenu(t: MixTrackUi, at: Offset?, close: () -> Unit, actions: MixActions) {
    LupeMenu(at != null, close, width = 248.dp, at = at) {
        MenuHeading("${t.number} ${t.name}")
        val sounds = com.scottgerstl.lupe.ui.sounds.LocalSoundsHost.current
        com.scottgerstl.lupe.ui.shell.MenuRow("Sounds…", { close(); sounds.open(t.number) })
    }
}

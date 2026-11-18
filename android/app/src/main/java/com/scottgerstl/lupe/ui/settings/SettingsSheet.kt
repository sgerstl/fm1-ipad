package com.scottgerstl.lupe.ui.settings

import androidx.compose.foundation.layout.widthIn

import androidx.compose.foundation.layout.wrapContentWidth

import androidx.compose.ui.semantics.disabled

import androidx.compose.ui.semantics.clearAndSetSemantics

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.LinkPhase
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.LupeSheet
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings
import com.scottgerstl.lupe.ui.slide.LocalSlideSettings
import com.scottgerstl.lupe.ui.slide.SlideDirection
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import com.scottgerstl.lupe.ui.theme.unscaled

/**
 * Settings, from the song-name menu (board 67; decision 33: the grouped sheet with both phones' options): the FM-1, Audio, Touch (Slider
 * gesture, the Magnifier, Sound keys and their side, Haptics, played phrases), Sound pages (Show graphics). Labs left on 2026-11-18. These
 * replace the adb extras (`--es slide`, `--ez magnifier`), which stay for testing. Everything is kept the moment it changes.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SettingsSheet(link: LinkState, fake: Boolean = false) {
    val host = LocalSheetHost.current
    val slide = LocalSlideSettings.current
    val phone = LocalPhoneSettings.current
    val scroll = rememberScrollState()
    LupeSheet(host.open == SheetKind.Settings, "Settings", { host.close() }, scroll = scroll, widthCap = 608.dp) {
      // the content column: at most 560 wide, centred in the sheet (Scott, 2026-11-18: "narrow it down a little bit"), about 45–75 characters a
      // subtitle line; the sheet's surface stays full width, as the sheet is a full-width drawer from the bottom
      Column(Modifier.fillMaxWidth().wrapContentWidth(Alignment.CenterHorizontally).widthIn(max = 560.dp)) {
        Section("FM-1")
        Plain(
            "FM-1", if (fake) "A fake core: no FM-1 is connected" else when (link.phase) { LinkPhase.Ready -> "Skiff, connected over USB"; LinkPhase.WrongFirmware -> "Connected, but not running Skiff"; else -> "Not connected" },
        )
        Plain("Theme", "Follows the FM-1 (SKIFF)")

        com.scottgerstl.lupe.audio.LocalAudioThrough.current?.let { AudioSection(it) }

        Section("Touch")
        Text2("Slider gesture", "Which way a finger slides a value. Up and right raise it.")
        Segmented(
            options = SlideDirection.entries.map { it.title },
            selected = SlideDirection.entries.indexOf(slide.direction),
            name = "Slider gesture",
        ) { slide.chooseDirection(SlideDirection.entries[it]) }
        Spacer(Modifier.height(8.dp))
        SwitchRow("Magnifier", "A bigger copy of the value floats above your finger as you slide", slide.magnifier) { slide.chooseMagnifier(it) }
        // Sound keys, then its side right under it; the side is dimmed and says why while the keys are off (2026-11-18)
        SwitchRow("Sound keys", "Off, sound pages open from the FM-1's own keys. On, FX SEL ENV LFO EDIT ARP stay down the side, so the phone can open them too", phone.soundKeys) { phone.chooseSoundKeys(it) }
        Text2("Sound keys side", "Which edge the sound keys sit on.")
        Segmented(options = listOf("Left", "Right"), selected = if (phone.railLeft) 0 else 1, name = "Sound keys side", enabled = phone.soundKeys, disabledWhy = "Turn on Sound keys first") { phone.chooseRailLeft(it == 0) }
        Spacer(Modifier.height(8.dp))
        SwitchRow("Haptics", "On pads and value steps", phone.haptics) { phone.chooseHaptics(it) }
        Text2("Offer played phrases", "When you play a phrase on the FM-1 while stopped: a small chip by Record, a pop-up over Edit, or nothing.")
        Segmented(options = listOf("Chip", "Pop-up", "Off"), selected = phone.takeOffer, name = "Offer played phrases") { phone.chooseTakeOffer(it) }
        Spacer(Modifier.height(8.dp))

        Section("Sound pages")
        SwitchRow("Show graphics", "Each sound page shows its picture with its dials, and the Mix pages show theirs. Off: dials only", phone.showGraphics) { phone.chooseShowGraphics(it) }

        // Following (Scott, 2026-11-18): Labs' two built trials, kept as ordinary settings. The piano under the grid and the Timeline with time
        // across were never built and are in design/backlog.md
        Section("Following")
        SwitchRow("Pause following after a touch", "The sound page you touched holds for 3 s before it follows the FM-1 again", phone.pauseFollowing) { phone.choosePauseFollowing(it) }
        SwitchRow("Pin the sound page", "The sound page and the sheets stop following the FM-1 while this is on", phone.pinBottom) { phone.choosePinBottom(it) }
      }
    }
}

/**
 * Audio: Play through the phone (the iPhone's "Play through the iPhone"). While it plays: where the sound goes, the phone's
 * share of the delay, what Bluetooth adds, and one technical line for the device check.
 */
@Composable
private fun AudioSection(through: com.scottgerstl.lupe.audio.AudioThrough) {
    Section("Audio")
    SwitchRow("Play through the phone", "The FM-1's sound on the phone's speaker or headphones, over the USB cable", through.enabled) { through.choose(it) }
    if (!through.enabled) return
    val state = through.state
    com.scottgerstl.lupe.audio.ThroughModel.action(state)?.let { Plain("Needs a hand", it) }
    // (Output, Delay and Details left on 2026-11-18, Scott; the Bluetooth note stays while the output is Bluetooth: it explains the lag)
    if (state is com.scottgerstl.lupe.audio.ThroughState.Playing) com.scottgerstl.lupe.audio.ThroughModel.bluetoothNote(state.kind)?.let { Text2("Bluetooth", it) }
}

@Composable
private fun Section(title: String) =
    BasicText(title, Modifier.padding(top = 16.dp, bottom = 6.dp).semantics { heading() }, style = LupeType.label.copy(letterSpacing = 0.5.sp))

@Composable
private fun Plain(title: String, sub: String) =
    Column(Modifier.fillMaxWidth().padding(vertical = 6.dp).semantics(mergeDescendants = true) { }) {
        BasicText(title, style = LupeType.key.copy(fontSize = 15.sp))
        BasicText(sub, style = LupeType.small.copy(fontSize = 13.sp))
    }

@Composable
private fun Text2(title: String, sub: String) =
    Column(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
        BasicText(title, style = LupeType.key.copy(fontSize = 15.sp))
        BasicText(sub, style = LupeType.small.copy(fontSize = 13.sp))
    }

/** A switch row, 56 dp tall: the words and the switch; the whole row is the touch target. [trial] marks a Labs entry. */
@Composable
fun SwitchRow(title: String, sub: String, on: Boolean, trial: Boolean = false, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().defaultMinSize(minHeight = 56.dp).padding(vertical = 4.dp)
            .semantics(mergeDescendants = true) {
                role = Role.Switch
                contentDescription = title + if (trial) ", trial" else ""
                stateDescription = if (on) "On" else "Off"
            }
            .pointerInput(on) { detectTapGestures { onChange(!on) } },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                BasicText(title, style = LupeType.key.copy(fontSize = 15.sp))
                if (trial) BasicText("TRIAL", Modifier.drawBehind { drawRoundRect(Tok.outline, cornerRadius = CornerRadius(4.dp.toPx()), style = androidx.compose.ui.graphics.drawscope.Stroke(1.dp.toPx())) }.padding(horizontal = 5.dp, vertical = 1.dp),
                    style = LupeType.label.copy(fontSize = 10.sp, lineHeight = 12.sp, letterSpacing = 0.5.sp))
            }
            BasicText(sub, style = LupeType.small.copy(fontSize = 13.sp))
        }
        LupeSwitch(on)
    }
}

/**
 * The hybrid switch (spec 3.6): 52 × 32, round. On: a `text` track with a 24 `onColour` thumb. Off: a `control` track with a 2 dp `primaryEdge`
 * edge (4.4:1) and a 16 thumb in `primaryEdge`. The thumb's size is the shape-as-state cue beside the colour; it travels and grows on the
 * spring, the colours ease (Reduce Motion: it lands at once and only the colours blend).
 */
@Composable
fun LupeSwitch(on: Boolean) {
    val reduce = LocalReduceMotion.current
    val m = com.scottgerstl.lupe.ui.theme.hybridMotion
    val t = animatedFloat(if (on) 1f else 0f, Dur.STATE)
    val move by com.scottgerstl.lupe.ui.theme.springFloat(if (on) 1f else 0f, m.fingerMs, m.bounce, spring = !reduce)
    Box(
        Modifier.width(52.dp).height(32.dp)
            .drawBehind {
                val r = CornerRadius(size.height / 2)
                drawRoundRect(lerp(Tok.control, Tok.text, t.value), cornerRadius = r)
                if (t.value < 1f) drawRoundRect(Tok.primaryEdge.copy(alpha = 1f - t.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius((size.height - 2.dp.toPx()) / 2), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
                val off = com.scottgerstl.lupe.ui.theme.Shape.switchThumbOff.toPx(); val onD = com.scottgerstl.lupe.ui.theme.Shape.switchThumbOn.toPx()
                val inset = (size.height - onD) / 2
                fun thumb(k: Float, alpha: Float) {
                    val d = off + (onD - off) * k.coerceIn(0f, 1.1f)
                    val cx = (inset + onD / 2) + (size.width - 2 * inset - onD) * k
                    drawCircle(lerp(Tok.primaryEdge, Tok.onColour, t.value).copy(alpha = alpha), d / 2, Offset(cx, size.height / 2))
                }
                // Reduce Motion: nothing travels; the thumb fades out of one end and into the other
                if (reduce) { thumb(0f, 1f - t.value); thumb(1f, t.value) } else thumb(move, 1f)
            },
    )
}

/** A few choices as the connected group (spec 3.4), filling the width: the white pill slides between them (see `SegmentGroup`). */
@Composable
fun Segmented(options: List<String>, selected: Int, name: String, enabled: Boolean = true, disabledWhy: String? = null, onPick: (Int) -> Unit) {
    // disabled: dimmed, takes no touch, and TalkBack hears one unfocusable-as-action node saying why
    val m = if (enabled) Modifier else Modifier.graphicsLayer { alpha = 0.4f }
        .clearAndSetSemantics { contentDescription = name; stateDescription = disabledWhy ?: "Off"; disabled() }
        .pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent(androidx.compose.ui.input.pointer.PointerEventPass.Initial).changes.forEach { it.consume() } } }
    // each option its label plus 16 each side, at least 72 wide and 44 tall, the group left under its label (Scott, 2026-11-18: buttons not
    // "obscenely wide"); when they don't fit (a large font size), equal shares with labels on two lines rather than cut
    val tm = androidx.compose.ui.text.rememberTextMeasurer()
    val style = LupeType.key.copy(fontSize = 15.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold)
    androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxWidth()) {
        val density = androidx.compose.ui.platform.LocalDensity.current
        val labelWidths = options.map { with(density) { tm.measure(it, style).size.width.toDp() } }
        val fits = segmentedFits(labelWidths.map { it.value }, maxWidth.value)
        com.scottgerstl.lupe.ui.shell.SegmentGroup(options, selected, { if (enabled) onPick(it) }, (if (fits) Modifier else Modifier.fillMaxWidth()).then(m),
            height = 44.dp, padH = if (fits) SEG_PAD.dp else 8.dp, minWidth = SEG_MIN.dp, role = Role.RadioButton, descriptions = options.map { "$name: $it" },
            fontSize = 15, fill = !fits, wrap = !fits)
    }
}

/** A settings option's padding each side and least width (dp). */
const val SEG_PAD = 16f
const val SEG_MIN = 72f
/** Whether options with labels [labelWidths] wide (dp), each its label plus [SEG_PAD] each side and at least [SEG_MIN], with 2 between, fit [available]. */
fun segmentedFits(labelWidths: List<Float>, available: Float): Boolean =
    labelWidths.sumOf { maxOf(it + 2 * SEG_PAD, SEG_MIN).toDouble() } + 2.0 * (labelWidths.size - 1).coerceAtLeast(0) <= available

package com.scottgerstl.lupe.ui.settings

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
 * Settings, from the song-name menu (board 67; decision 33: the grouped sheet with both phones' options): the FM-1, Touch (Slide to turn,
 * the Magnifier, Handedness, Haptics), Sound pages (Show graphics, Sound keys), and
 * Labs, the trials, each off until you switch it on. These replace the adb extras (`--es slide`, `--ez magnifier`),
 * which stay for testing. Everything is kept the moment it changes.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SettingsSheet(link: LinkState, fake: Boolean = false) {
    val host = LocalSheetHost.current
    val slide = LocalSlideSettings.current
    val phone = LocalPhoneSettings.current
    val scroll = rememberScrollState()
    // the Labs heading's place in the scrolling content, so the FM-1 menu's Labs row can open the sheet scrolled to it
    var labsY by remember { androidx.compose.runtime.mutableStateOf(-1) }
    LaunchedEffect(host.open, host.toLabs, labsY) { if (host.open == SheetKind.Settings && host.toLabs && labsY >= 0) { kotlinx.coroutines.delay(350); scroll.animateScrollTo(labsY) } }
    LupeSheet(host.open == SheetKind.Settings, "Settings", { host.close() }, scroll = scroll) {
        Section("FM-1")
        Plain(
            "FM-1", if (fake) "A fake core: no FM-1 is connected" else when (link.phase) { LinkPhase.Ready -> "Skiff, connected over USB"; LinkPhase.WrongFirmware -> "Connected, but not running Skiff"; else -> "Not connected" },
        )
        Plain("Theme", "Follows the FM-1 (SKIFF)")

        com.scottgerstl.lupe.audio.LocalAudioThrough.current?.let { AudioSection(it) }

        Section("Touch")
        Text2("Slide to turn", "Which way a finger slides a value. Up and right raise it.")
        Segmented(
            options = SlideDirection.entries.map { it.title },
            selected = SlideDirection.entries.indexOf(slide.direction),
            name = "Slide to turn",
        ) { slide.chooseDirection(SlideDirection.entries[it]) }
        Spacer(Modifier.height(8.dp))
        SwitchRow("Magnifier", "A bigger copy of the value floats above your finger as you slide", slide.magnifier) { slide.chooseMagnifier(it) }
        Text2("Sound keys side", "Which edge the sound keys sit on (when Sound keys is on).")
        Segmented(options = listOf("Left", "Right"), selected = if (phone.railLeft) 0 else 1, name = "Sound keys side") { phone.chooseRailLeft(it == 0) }
        Spacer(Modifier.height(8.dp))
        Text2("Menus open", "Which side of your finger hold menus and pop-outs open to; they flip when there is no room.")
        Segmented(options = listOf("Left", "Right"), selected = if (phone.menusRight) 1 else 0, name = "Menus open") { phone.chooseMenusRight(it == 1) }
        Spacer(Modifier.height(8.dp))
        SwitchRow("Haptics", "On pads and value steps", phone.haptics) { phone.chooseHaptics(it) }

        Section("Sound pages")
        SwitchRow("Show graphics", "Each sound page shows its picture with its dials, and the Mix pages show theirs. Off: dials only", phone.showGraphics) { phone.chooseShowGraphics(it) }
        SwitchRow("Sound keys", "Off, sound pages open from the FM-1's own keys. On, FX SEL ENV LFO EDIT ARP stay down the side, so the phone can open them too", phone.soundKeys) { phone.chooseSoundKeys(it) }

        Column(Modifier.onGloballyPositioned { labsY = it.positionInParent().y.toInt() }) {
            Spacer(Modifier.height(12.dp))
            Box(Modifier.fillMaxWidth().height(1.dp).background(Tok.lifted))
            Spacer(Modifier.height(16.dp))
            BasicText("Labs", Modifier.semantics { heading() }, style = LupeType.title.copy(fontSize = 17.sp))
            BasicText("Settings to try on the phone. Each starts off; keep what works.", Modifier.padding(top = 2.dp, bottom = 8.dp), style = LupeType.small.copy(fontSize = 13.sp))
        }
        SwitchRow("Pause following after a touch", "The sound page you touched holds for 3 s before it follows the FM-1 again", phone.pauseFollowing, trial = true) { phone.choosePauseFollowing(it) }
        SwitchRow("Pin the sound page", "The sound page and the sheets stop following the FM-1 while this is on", phone.pinBottom, trial = true) { phone.choosePinBottom(it) }
        // a feel value to tune by hand (added 2026-11-14, review 2026-11-28): slide it
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("TAB CHANGE · MS", "${phone.tabSlideMs} ms", phone.tabSlideMs / 10, 15, 70, "How long a tab change takes", stepDp = 8f, revertTo = 38) { phone.chooseTabSlide(it * 10) }
        // hybrid motion (design/hybrid-ui/spec.md §5; added 2026-11-17, review 2026-12-01): starting values, tuned by hand on the Pixel
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("HYBRID · SPRING BOUNCE", "${phone.motionBounce} %", phone.motionBounce, 0, 50, "How far shapes and panels spring past where they land", stepDp = 8f, revertTo = 25) { phone.chooseMotionBounce(it) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("HYBRID · AT THE FINGER", "${phone.motionFingerMs} ms", phone.motionFingerMs / 10, 10, 40, "Pads changing shape, menus and pop-ups", stepDp = 8f, revertTo = 20) { phone.chooseMotionFinger(it * 10) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("HYBRID · SHEETS AND PANELS", "${phone.motionPanelMs} ms", phone.motionPanelMs / 10, 15, 48, "Sheets rising and the docked panel sliding in", stepDp = 8f, revertTo = 30) { phone.chooseMotionPanel(it * 10) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("HYBRID · EDIT PAGE FLIP", "${phone.motionPageFlipMs} ms", phone.motionPageFlipMs / 10, 15, 48, "The 8-step grid turning a page", stepDp = 8f, revertTo = 28) { phone.chooseMotionPageFlip(it * 10) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("HYBRID · PRESS SQUASH", "${phone.motionPressScale} %", phone.motionPressScale, 80, 100, "How small a scene key squashes while pressed", stepDp = 8f, revertTo = 92) { phone.chooseMotionPress(it) }
        // expressive springs (round 3, 2026-11-17, review 2026-12-01): Material 3 Expressive's default spatial spring and the squash that makes a shape change read
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("SHAPE SPRING · STIFFNESS", "${phone.spatialStiffness}", phone.spatialStiffness / 20, 5, 75, "How quickly a pad, badge, scene or tab changes shape (M3 Expressive: 380)", stepDp = 8f, revertTo = 19) { phone.chooseSpatialStiffness(it * 20) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("SHAPE SPRING · DAMPING", "0.${"%02d".format(phone.spatialDamping)}".replace("0.100", "1.00"), phone.spatialDamping, 30, 100, "Lower bounces more (M3 Expressive: 0.80)", stepDp = 8f, revertTo = 80) { phone.chooseSpatialDamping(it) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("FAST SPRING · STIFFNESS", "${phone.fastStiffness}", phone.fastStiffness / 50, 4, 60, "Presses and quick shape changes (M3 Expressive fast spatial: 800, damping 0.6)", stepDp = 8f, revertTo = 16) { phone.chooseFastStiffness(it * 50) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("SQUASH AND STRETCH · %", "${phone.squashPct} %", phone.squashPct, 0, 15, "How far a shape squashes as it changes (wider and shorter, then settling)", stepDp = 10f, revertTo = 6) { phone.chooseSquash(it) }
        // pad drag and its edge wells (added 2026-11-15, review 2026-11-29)
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · SLIDE BEFORE IT LIFTS", "${phone.padSlideStart} dp", phone.padSlideStart, 4, 30, "How far you slide a pad before it picks up", stepDp = 8f, revertTo = 8) { phone.choosePadSlideStart(it) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · PRESS BEFORE SLIDING", "${phone.padSlideDwellMs} ms", phone.padSlideDwellMs / 10, 5, 40, "A slide quicker than this after you touch is a swipe and doesn't pick the pad up", stepDp = 8f, revertTo = 15) { phone.choosePadSlideDwell(it * 10) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · WELLS SLIDE IN", "${phone.wellSlideMs} ms", phone.wellSlideMs / 10, 10, 50, "How long the Clear, Edit and Duplicate wells take to slide in", stepDp = 8f, revertTo = 22) { phone.chooseWellSlide(it * 10) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · TOP/BOTTOM GLOW START", "${phone.wellGlowPct} % of height", phone.wellGlowPct, 20, 70, "How far from the Cancel, Clear steps and Delete wells the dragged pad is when they start to glow, as a share of the screen height", stepDp = 6f, revertTo = 45) { phone.chooseWellGlow(it) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · TOP/BOTTOM HOT DISTANCE", "${phone.wellHotDp} dp", phone.wellHotDp / 4, 6, 32, "How near the dragged pad comes before a well is hot and a drop there acts", stepDp = 8f, revertTo = 16) { phone.chooseWellHot(it * 4) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · SIDE GLOW START", "${phone.wellSideGlowPct} % of width", phone.wellSideGlowPct, 20, 70, "How far from the Edit and Duplicate wells the dragged pad is when they start to glow, as a share of the screen width", stepDp = 6f, revertTo = 45) { phone.chooseWellSideGlow(it) }
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("PAD DRAG · SIDE HOT DISTANCE", "${phone.wellSideHotDp} dp", phone.wellSideHotDp / 4, 8, 48, "How near the dragged pad comes before Edit or Duplicate is hot and a drop there acts", stepDp = 8f, revertTo = 24) { phone.chooseWellSideHot(it * 4) }
        SwitchRow("Piano under the grid", "A one-octave piano for entering notes without the FM-1. Not built yet", phone.piano, trial = true) { phone.choosePiano(it) }
        SwitchRow("Timeline: time across", "Tracks as lanes, as on the FM-1 and the iPad. Not built yet: the Timeline runs time down", phone.timelineAcross, trial = true) { phone.chooseTimelineAcross(it) }
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
    if (state is com.scottgerstl.lupe.audio.ThroughState.Playing) {
        Plain("Output", state.output)
        val ms = com.scottgerstl.lupe.audio.ThroughModel.latencyText(through.stats)
        Plain("Delay", if (ms == null) "Measuring…" else "$ms on the phone, from the USB cable to the output")
        com.scottgerstl.lupe.audio.ThroughModel.bluetoothNote(state.kind)?.let { Text2("Bluetooth", it) }
        Plain("Details", com.scottgerstl.lupe.audio.ThroughModel.details(through.stats))
    } else if (state == com.scottgerstl.lupe.audio.ThroughState.Starting) {
        Plain("Output", "Starting…")
    }
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
fun Segmented(options: List<String>, selected: Int, name: String, onPick: (Int) -> Unit) =
    com.scottgerstl.lupe.ui.shell.SegmentGroup(options, selected, onPick, Modifier.fillMaxWidth(), height = 40.dp, padH = 8.dp,
        role = Role.RadioButton, descriptions = options.map { "$name: $it" }, fontSize = 15, fill = true)

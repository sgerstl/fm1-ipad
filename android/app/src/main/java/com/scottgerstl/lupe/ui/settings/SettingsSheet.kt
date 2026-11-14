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
 * Settings, from the FM-1 key's menu (board 67): what the phone does (Slide to turn, the Magnifier, Haptics), and
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

        Section("Turning values")
        Text2("Slide to turn", "Which way a finger slides a value. Up and right raise it.")
        Segmented(
            options = SlideDirection.entries.map { it.title },
            selected = SlideDirection.entries.indexOf(slide.direction),
            name = "Slide to turn",
        ) { slide.chooseDirection(SlideDirection.entries[it]) }
        Spacer(Modifier.height(8.dp))
        SwitchRow("Magnifier", "A bigger copy of the value floats above your finger as you slide", slide.magnifier) { slide.chooseMagnifier(it) }
        SwitchRow("Haptics", "On pads and value steps", phone.haptics) { phone.chooseHaptics(it) }

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
        com.scottgerstl.lupe.ui.slide.MenuSlideRow("SOUND PANEL STAYS · SECONDS", "${phone.panelHoldSeconds} s", phone.panelHoldSeconds, 2, 12, "How long the sound panel stays after the last knob turn or touch", stepDp = 18f, revertTo = 4) { phone.choosePanelHold(it) }
        SwitchRow("Piano under the grid", "A one-octave piano for entering notes without the FM-1. Not built yet", phone.piano, trial = true) { phone.choosePiano(it) }
        SwitchRow("Timeline: time across", "Tracks as lanes, as on the FM-1 and the iPad. Not built yet: the Timeline runs time down", phone.timelineAcross, trial = true) { phone.chooseTimelineAcross(it) }
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

/** 52 × 30: the thumb slides and the track blends in 150 ms (Reduce Motion: the blend only). On is the light key, off the dark. */
@Composable
fun LupeSwitch(on: Boolean) {
    val reduce = LocalReduceMotion.current
    val t = animatedFloat(if (on) 1f else 0f, Dur.STATE)
    Box(
        Modifier.width(52.dp).height(30.dp)
            .drawBehind {
                val r = CornerRadius(size.height / 2)
                drawRoundRect(lerp(Tok.control, Tok.primaryTop, t.value), cornerRadius = r)
                // off: a 2 dp outline in text2 (about 6:1 on the sheet), so the control's edge and state read without colour alone
                if (t.value < 1f) drawRoundRect(Tok.text2.copy(alpha = 1f - t.value), Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius((size.height - 2.dp.toPx()) / 2), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
                val pad = 5.dp.toPx(); val d = size.height - 2 * pad
                val x = if (reduce) (if (on) size.width - pad - d else pad) else pad + (size.width - 2 * pad - d) * t.value
                drawRoundRect(lerp(Tok.text2, Tok.onColour, t.value), Offset(x, pad), Size(d, d), CornerRadius(d / 2))
            },
    )
}

/** Three (or so) choices in a well, the chosen one a raised key blending in over 150 ms (as the Pads · Timeline · Mix tabs). */
@Composable
fun Segmented(options: List<String>, selected: Int, name: String, onPick: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().height(40.dp).background(Tok.well, RoundedCornerShape(10.dp)).selectableGroup()) {
        options.forEachIndexed { i, label ->
            val lit = animatedFloat(if (i == selected) 1f else 0f, Dur.STATE)
            Box(
                Modifier.weight(1f).fillMaxHeight()
                    .semantics(mergeDescendants = true) { role = Role.RadioButton; this.selected = i == selected; contentDescription = "$name: $label" }
                    .pointerInput(i) { detectTapGestures { onPick(i) } }
                    .padding(3.dp)
                    .drawBehind {
                        val r = CornerRadius(8.dp.toPx())
                        drawRoundRect(Tok.chicletEdge.copy(alpha = lit.value), Offset(0f, 2.dp.toPx()), Size(size.width, size.height - 2.dp.toPx()), r)
                        drawRoundRect(Tok.control.copy(alpha = lit.value), Offset.Zero, Size(size.width, size.height - 2.dp.toPx()), r)
                    },
                contentAlignment = Alignment.Center,
            ) { BasicText(label, style = LupeType.key.copy(color = lerp(Tok.text2, Tok.text, lit.value))) }
        }
    }
}

package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.Image
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.R
import com.scottgerstl.lupe.audio.AudioThrough
import com.scottgerstl.lupe.audio.OutputKind
import com.scottgerstl.lupe.audio.ThroughModel
import com.scottgerstl.lupe.audio.ThroughState
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * Play through the phone as a key in the header (Scott, 2026-11-18: "playing through the phone maybe should come out of settings and instead be
 * the little speaker button to the left of the loop dropdown. styled the same"). The Launch pill's look: a 40 round shape in a 48 touch target,
 * outlined while off with the speaker crossed out (volume_off); on, filled like a selected tab (`text`, the icon `onColour`) with the speaker
 * sounding (volume_up). The icon carries the state as well as the fill. Both cross-fade over the state time; it presses like the pills.
 */
@Composable
fun ThroughKey(through: AudioThrough, modifier: Modifier = Modifier) {
    val on = through.enabled
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val focused by source.collectIsFocusedAsState()
    val reduce = com.scottgerstl.lupe.ui.theme.LocalReduceMotion.current
    val press = com.scottgerstl.lupe.ui.theme.pressScale(pressed, reduce)
    val k = animatedFloat(if (on) 1f else 0f, Dur.STATE).value
    val wash = animatedFloat(if (pressed) 1f else 0f, if (pressed) 60 else Dur.STATE).value
    Box(
        modifier.size(48.dp)
            .semantics { contentDescription = "Play through the phone" }
            .toggleable(on, source, indication = null, role = Role.Switch) { through.choose(it) },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.size(40.dp).graphicsLayer { val s = press.value; scaleX = s; scaleY = s }
                .drawBehind {
                    val r = CornerRadius(size.height / 2)
                    val w = 1.dp.toPx()
                    if (k < 1f) drawRoundRect(Tok.primaryEdge.copy(alpha = 1f - k), Offset(w / 2, w / 2), Size(size.width - w, size.height - w), CornerRadius(size.height / 2 - w / 2), style = Stroke(w))
                    if (k > 0f) drawRoundRect(Tok.text.copy(alpha = k), cornerRadius = r)
                    if (wash > 0f) drawRoundRect(lerp(Tok.text, Tok.onColour, k).copy(alpha = 0.10f * wash), cornerRadius = r)
                    if (focused) drawRoundRect(Tok.text, Offset(-3.dp.toPx(), -3.dp.toPx()), Size(size.width + 6.dp.toPx(), size.height + 6.dp.toPx()), CornerRadius(size.height / 2 + 3.dp.toPx()), style = Stroke(2.dp.toPx()))
                },
            contentAlignment = Alignment.Center,
        ) {
            if (k < 1f) Image(painterResource(R.drawable.ms_volume_off), null, Modifier.size(22.dp).graphicsLayer { alpha = 1f - k }, colorFilter = ColorFilter.tint(Tok.text))
            if (k > 0f) Image(painterResource(R.drawable.ms_volume_up), null, Modifier.size(22.dp).graphicsLayer { alpha = k }, colorFilter = ColorFilter.tint(Tok.onColour))
        }
    }
}

/** The refusal play-through puts in the strip while it can't play ("Needs a hand" in Settings until 2026-11-18); null when nothing needs doing. */
internal fun throughNeedsHand(enabled: Boolean, state: ThroughState): String? = if (enabled) ThroughModel.action(state) else null

/** The Bluetooth note, once, when play-through starts on a Bluetooth output: [was] the output kind before (null while not playing), [now] after. */
internal fun throughStartNote(was: OutputKind?, now: OutputKind?): String? = if (now != null && now != was) ThroughModel.bluetoothNote(now) else null

/**
 * Play-through's messages, under the messages rule (Scott, 2026-11-17), now its Settings section is gone (2026-11-18): what needs a hand is a
 * refusal that stays until it's fixed (it leaves by itself once play-through plays or is turned off); the Bluetooth note is a 4 s confirmation
 * when it starts on Bluetooth. Neither carries an action.
 */
@Composable
fun ThroughMessages(through: AudioThrough) {
    val messages = LocalMessages.current
    val need = throughNeedsHand(through.enabled, through.state)
    LaunchedEffect(need) {
        if (need != null) messages.refuse(need, fix = THROUGH_FIX) else messages.fixed { it == THROUGH_FIX }
    }
    val kind = (through.state as? ThroughState.Playing)?.kind?.takeIf { through.enabled }
    val last = remember { arrayOfNulls<OutputKind>(1) }
    LaunchedEffect(kind) {
        throughStartNote(last[0], kind)?.let { messages.post(MessageKind.Confirmation, it) }
        last[0] = kind
    }
}

private const val THROUGH_FIX = "through"

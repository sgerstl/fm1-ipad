package com.scottgerstl.lupe.ui.mix

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.MixCard
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.lupeSpring
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The effect cards' order (GLO 2–5) and titles. */
internal val EFFECT_KEYS = listOf("delay", "reverb", "chorus", "global")
private val EFFECT_TITLES = listOf("DELAY", "REVERB", "CHORUS", "GLOBAL")
/** A collapsed card's width, and the gap between cards (dp). */
internal const val CARD_NARROW = 112f
internal const val CARD_GAP = 6f

/** The picked card's width in a body [bodyW] wide: what the three collapsed cards and the gaps leave. */
internal fun pickedCardWidth(bodyW: Float): Float = (bodyW - 3 * CARD_NARROW - 3 * CARD_GAP).coerceAtLeast(CARD_NARROW)

/** The two values a collapsed card shows, by label (Delay TIME and MIX, Reverb TYPE and MIX, Chorus RATE and DEPTH, Global TEMPO and SWING). */
internal fun collapsedPair(key: String, card: MixCard?): List<Pair<String, String>> {
    val want = when (key) { "delay" -> listOf("TIME", "MIX"); "reverb" -> listOf("TYPE", "MIX"); "chorus" -> listOf("RATE", "DEPTH"); else -> listOf("TEMPO", "SWING") }
    val controls = card?.controls.orEmpty().filterNotNull()
    return want.map { w -> w to (controls.firstOrNull { it.label.equals(w, true) || it.label.startsWith(w, true) }?.value ?: "—") }
}

/**
 * Mix › Effects (direction C, Scott 2026-11-17: "yes send the cards"; vault `assets/mix-effect-cards-2026-11-17/`). Four cards in GLO's order,
 * Delay · Reverb · Chorus · Global. The picked one is wide (the body less three 112 cards and the gaps) on `panel` at radius 20, holding its four
 * knob tiles (numbered to the FM-1's knobs on that GLO page), the FM-1's picture in greys and white (decision 34) and, for Delay, DELAY MODE as
 * pills; for Reverb the six tracks' sends as chips (a tap opens that track's send slide row, the strip menu's control). The others are 112 wide
 * on `held`, with the name, a small picture and two values; a tap picks one (the whole card), which sends the FM-1 to that GLO page, and the
 * picked card follows the FM-1's page. Widths spring (bounce 0.2, ~420 ms); contents cross-fade overlapping so nothing goes blank; the tapped
 * card squashes. Reduce Motion: a cross-fade, no width animation. The core sends one card at a time (the FM-1's page), so a collapsed card shows
 * its values from when it was last picked ("—" before).
 */
@Composable
fun EffectsPage(ui: MixUi, actions: MixActions, graphics: Boolean, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val picked = (ui.page - 1).coerceIn(0, 3)
    val cache = remember { mutableStateMapOf<String, MixCard>() }
    LaunchedEffect(ui.card, ui.sectionKey) { val c = ui.card; if (c != null && ui.sectionKey in EFFECT_KEYS) cache[ui.sectionKey] = c }
    BoxWithConstraints(modifier.fillMaxSize().padding(bottom = 16.dp)) {
        val wide = pickedCardWidth(maxWidth.value)
        Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(CARD_GAP.dp)) {
            EFFECT_KEYS.forEachIndexed { i, key ->
                EffectCard(i, key, i == picked, wide, cache[key], ui, actions, graphics, reduce)
            }
        }
    }
}

@Composable
private fun EffectCard(i: Int, key: String, isPicked: Boolean, wideDp: Float, card: MixCard?, ui: MixUi, actions: MixActions, graphics: Boolean, reduce: Boolean) {
    val width = remember { Animatable(if (isPicked) wideDp else CARD_NARROW) }
    val full = remember { Animatable(if (isPicked) 1f else 0f) }
    val small = remember { Animatable(if (isPicked) 0f else 1f) }
    val first = remember { booleanArrayOf(true) }
    LaunchedEffect(isPicked, wideDp) {
        val target = if (isPicked) wideDp else CARD_NARROW
        if (first[0]) { first[0] = false; width.snapTo(target); return@LaunchedEffect }
        unscaled {
            kotlinx.coroutines.coroutineScope {
                // every card's width on the same spring, so the four always fill the body (a growing and a shrinking card add up)
                launch { if (reduce) width.snapTo(target) else width.animateTo(target, lupeSpring(420, 0.2f)) }
                if (isPicked) {
                    launch { if (!reduce) delay(40); small.animateTo(0f, tween(if (reduce) 150 else 100, easing = EaseIn)) }
                    launch { if (!reduce) delay(100); full.animateTo(1f, tween(if (reduce) 150 else 180, easing = EaseOut)) }
                } else {
                    launch { full.animateTo(0f, tween(if (reduce) 150 else 100, easing = EaseIn)) }
                    launch { if (!reduce) delay(60); small.animateTo(1f, tween(if (reduce) 150 else 180, easing = EaseOut)) }
                }
            }
        }
    }
    val pick = com.scottgerstl.lupe.ui.theme.animatedFloat(if (isPicked) 1f else 0f, 150).value
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val squash by com.scottgerstl.lupe.ui.theme.spatialFloat(if (pressed && !isPicked) 0.95f else 1f, reduce, fast = true)
    Box(
        Modifier.width(width.value.dp).fillMaxHeight()
            .graphicsLayer { scaleX = squash; scaleY = squash }
            .clip(RoundedCornerShape(20.dp))
            .background(lerp(Tok.held, Tok.panel, pick))
            .semantics(mergeDescendants = !isPicked) {
                role = Role.Tab; selected = isPicked
                contentDescription = EFFECT_TITLES[i].lowercase().replaceFirstChar { it.uppercase() } + if (isPicked) ", picked" else ", GLO ${i + 2} of 5"
            }
            .then(if (isPicked) Modifier else Modifier.clickable(source, null, role = Role.Tab) { actions.page(i + 1) }),
    ) {
        // collapsed: name, a small picture, two values
        if (small.value > 0.001f) Column(Modifier.width(CARD_NARROW.dp).fillMaxHeight().graphicsLayer { alpha = small.value }.padding(18.dp)) {
            BasicText(EFFECT_TITLES[i], style = LupeType.key.copy(fontSize = 14.sp, lineHeight = 16.sp), maxLines = 1)
            Spacer(Modifier.height(16.dp))
            val g = busGraphOf(key, card)
            if (graphics && g != null) com.scottgerstl.lupe.ui.page.GraphContent(g, Tok.text2Raised, -1, Modifier.fillMaxWidth().height(64.dp).clearAndSetSemantics { })
            Spacer(Modifier.weight(1f))
            collapsedPair(key, card).forEach { (label, value) ->
                BasicText(label, style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
                BasicText(value, Modifier.padding(bottom = 10.dp), style = LupeType.number.copy(fontSize = 22.sp, lineHeight = 24.sp, fontWeight = FontWeight.Bold), maxLines = 1)
            }
        }
        // picked: its full content, laid out at the wide width and clipped while the card grows, so nothing reflows
        if (full.value > 0.001f) Box(Modifier.requiredWidth(wideDp.dp).fillMaxHeight().align(Alignment.TopStart).graphicsLayer { alpha = full.value }) {
            EffectFull(i, key, card ?: ui.card.takeIf { ui.sectionKey == key }, ui, actions, graphics)
        }
    }
}

@Composable
private fun EffectFull(i: Int, key: String, card: MixCard?, ui: MixUi, actions: MixActions, graphics: Boolean) {
    Column(Modifier.fillMaxSize().padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 16.dp)) {
        BasicText(EFFECT_TITLES[i], Modifier.semantics { heading() }, style = LupeType.title.copy(fontSize = 19.sp, lineHeight = 21.sp))
        BasicText(if (key == "global") "Every track · the FM-1's GLOBAL page" else "Shared effect · all tracks", style = LupeType.small.copy(fontSize = 13.sp, color = Tok.text2Raised), maxLines = 1)
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            // the four knob tiles, 2 × 2, numbered to the FM-1's knobs on this GLO page (the device's card); an empty slot is an empty well
            Column(Modifier.weight(1.15f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (row in 0..1) Row(Modifier.fillMaxWidth().weight(1f), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (col in 0..1) {
                        val k = row * 2 + col
                        val c: PageControl? = card?.controls?.getOrNull(k)
                        if (c == null) Box(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(10.dp)).background(Tok.well).clearAndSetSemantics { })
                        else {
                            val unitSplit = c.value.split(' ', limit = 2)
                            val (v, u) = if (!c.list && unitSplit.size == 2) unitSplit[0] to unitSplit[1] else c.value to null
                            com.scottgerstl.lupe.ui.page.ParamTile(c.label, k + 1, v, c.label.lowercase().replaceFirstChar { it.uppercase() }, Tok.text, key to k, Modifier.weight(1f).fillMaxHeight(),
                                unit = u, num = c.raw, min = c.min, max = c.max, dpPerStep = if (c.list) 24f else 3f, tick = c.list, enabled = !c.fixed) { d -> actions.setBus(k, (c.raw + d).coerceIn(c.min, c.max)) }
                        }
                    }
                }
            }
            // the FM-1's picture, greys and white (decision 34)
            val g = busGraphOf(key, card)
            if (graphics && g != null) Box(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(16.dp)).background(Tok.well).padding(10.dp)) {
                com.scottgerstl.lupe.ui.page.GraphContent(g, Tok.text, -1, Modifier.fillMaxSize())
            }
        }
        Spacer(Modifier.height(12.dp))
        when (key) {
            "delay" -> card?.settings?.firstOrNull()?.let { s -> if (s.names.size in 2..6) Row(verticalAlignment = Alignment.CenterVertically) {
                BasicText("DELAY MODE", Modifier.width(110.dp), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
                com.scottgerstl.lupe.ui.shell.SegmentGroup(s.names.map { n -> n.lowercase().replaceFirstChar { it.uppercase() } }, s.raw.coerceIn(0, s.names.lastIndex), { actions.setSetting(0, it) },
                    height = 40.dp, padH = 18.dp, role = Role.RadioButton, fontSize = 15)
            } }
            "reverb" -> ReverbSends(ui, actions)
            else -> Unit
        }
    }
}

/** The six tracks' reverb sends as chips (track colour dot, the send); a tap opens that track's send as a slide row, the strip menu's control. */
@Composable
private fun ReverbSends(ui: MixUi, actions: MixActions) {
    val menu = com.scottgerstl.lupe.ui.shell.LocalHoldMenu.current
    val latest by rememberUpdatedState(ui.tracks)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        BasicText("SENDS", Modifier.width(64.dp), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
        ui.tracks.forEach { t ->
            val colour = Tok.track[(t.number - 1) % Tok.track.size]
            var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
            Row(
                Modifier.height(40.dp).clip(RoundedCornerShape(50)).background(Tok.control)
                    .onGloballyPositioned { coords = it }
                    .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Reverb send, track ${t.number} ${t.name}: ${t.sendText}. Opens its slide" }
                    .clickable {
                        val c = coords?.takeIf { it.isAttached } ?: return@clickable
                        menu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), colour, listOf(
                            com.scottgerstl.lupe.ui.shell.HoldItem("REVERB SEND", group = "Mix", slide = com.scottgerstl.lupe.ui.shell.HoldSlide(
                                { latest.firstOrNull { it.number == t.number }?.send ?: 0 }, { latest.firstOrNull { it.number == t.number }?.sendText.orEmpty() }, 0, 127) { actions.send(t.number, it) }),
                        ))
                    }
                    .padding(start = 8.dp, end = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(Modifier.size(18.dp).background(colour, CircleShape))
                BasicText(t.sendText.removeSuffix("%").ifEmpty { "–" }, style = LupeType.number.copy(fontSize = 15.sp, lineHeight = 16.sp, fontWeight = FontWeight.Bold))
            }
        }
    }
}

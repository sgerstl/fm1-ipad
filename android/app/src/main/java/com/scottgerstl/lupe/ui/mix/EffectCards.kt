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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
/** A collapsed card's one inset, and its picture box: [PICTURE_H] tall, [PICTURE_TOP] from the card's top, the inner width (Scott, 2026-11-17). */
internal const val COLLAPSED_INSET = 14f
internal const val PICTURE_TOP = 46f
internal const val PICTURE_H = 62f

/** A knob tile's least height: the hybrid tile's padding, label row, value and gauge, so its value always shows in full (Scott, 2026-11-17). */
internal const val TILE_MIN_H = 80f
/** The picked card's picture when Delay's modes or Reverb's sends sit under it. */
internal const val PICTURE_SHORT_H = 64f
/** A 2 × 2 tile's height in a body [availH] tall (8 between the rows): its share, never below [TILE_MIN_H] (the tiles scroll instead). */
internal fun tileHeight(availH: Float): Float = maxOf(TILE_MIN_H, (availH - 8f) / 2f)

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
    val squash by com.scottgerstl.lupe.ui.theme.pressScale(pressed && !isPicked, reduce)
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
        // collapsed (Scott, 2026-11-17: "truncated and left aligned with all the rest of the card content… This sure goes for all of these cards"):
        // one 14 dp left inset for everything; every line single and clipped to the inner width with an ellipsis; the picture in one fixed box
        // (inner width × 62, 46 from the top) in every card, so they line up; the two value pairs pinned to the bottom inset
        if (small.value > 0.001f) Box(Modifier.width(CARD_NARROW.dp).fillMaxHeight().graphicsLayer { alpha = small.value }.padding(horizontal = COLLAPSED_INSET.dp, vertical = COLLAPSED_INSET.dp)) {
            val inner = (CARD_NARROW - 2 * COLLAPSED_INSET).dp
            BasicText(EFFECT_TITLES[i], Modifier.width(inner).align(Alignment.TopStart), style = LupeType.key.copy(fontSize = 14.sp, lineHeight = 16.sp), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            val g = busGraphOf(key, card)
            if (graphics && g != null) Box(Modifier.align(Alignment.TopStart).padding(top = (PICTURE_TOP - COLLAPSED_INSET).dp).width(inner).height(PICTURE_H.dp), contentAlignment = Alignment.CenterStart) {
                com.scottgerstl.lupe.ui.page.GraphContent(g, Tok.text2Raised, -1, Modifier.fillMaxSize().clearAndSetSemantics { })
            }
            Column(Modifier.align(Alignment.BottomStart).width(inner)) {
                collapsedPair(key, card).forEachIndexed { n, (label, value) ->
                    BasicText(label, Modifier.width(inner), style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp), maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                    BasicText(value, Modifier.width(inner).padding(bottom = if (n == 0) 10.dp else 0.dp), style = LupeType.number.copy(fontSize = 22.sp, lineHeight = 24.sp, fontWeight = FontWeight.Bold),
                        maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                }
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
        // the tiles take the card's full height and never shrink below [TILE_MIN_H], where the value shows in full (Scott, 2026-11-17: the
        // sends row squeezed them and cut the values off); Delay's modes and Reverb's sends sit under the picture in the right column
        BoxWithConstraints(Modifier.fillMaxWidth().weight(1f)) {
            val tileH = tileHeight(maxHeight.value).dp
            val short = tileH * 2 + 8.dp > maxHeight
        Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            // the four knob tiles, 2 × 2, numbered to the FM-1's knobs on this GLO page (the device's card); an empty slot is an empty well
            Column(Modifier.weight(1.15f).fillMaxHeight().then(if (short) Modifier.verticalScroll(rememberScrollState()) else Modifier), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (row in 0..1) Row(Modifier.fillMaxWidth().height(tileH), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
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
            // the right column: the FM-1's picture, greys and white (decision 34); with Delay's modes or Reverb's sends under it, the picture is 64 tall
            val g = busGraphOf(key, card)
            val modes = if (key == "delay") card?.settings?.firstOrNull()?.takeIf { it.names.size in 2..6 } else null
            val under = modes != null || key == "reverb"
            Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (graphics && g != null) Box((if (under) Modifier.fillMaxWidth().height(PICTURE_SHORT_H.dp) else Modifier.fillMaxWidth().weight(1f))
                    .clip(RoundedCornerShape(16.dp)).background(Tok.well).padding(10.dp)) {
                    com.scottgerstl.lupe.ui.page.GraphContent(g, Tok.text, -1, Modifier.fillMaxSize())
                }
                if (modes != null) {
                    BasicText("MODE", style = LupeType.small.copy(fontSize = 12.sp, color = Tok.text2Raised, letterSpacing = 0.5.sp))
                    com.scottgerstl.lupe.ui.shell.SegmentGroup(modes.names.map { n -> n.lowercase().replaceFirstChar { it.uppercase() } }, modes.raw.coerceIn(0, modes.names.lastIndex), { actions.setSetting(0, it) },
                        Modifier.fillMaxWidth(), height = 40.dp, padH = 8.dp, role = Role.RadioButton, fontSize = 14, fill = true,
                        descriptions = modes.names.map { n -> "Delay mode " + n.lowercase() })
                }
                if (key == "reverb") ReverbSends(ui, actions)
            }
        }
        }
    }
}

/** The six tracks' reverb sends as chips (track colour dot, the send); a tap opens that track's send as a slide row, the strip menu's control. */
@Composable
private fun ReverbSends(ui: MixUi, actions: MixActions) {
    val menu = com.scottgerstl.lupe.ui.shell.LocalHoldMenu.current
    val latest by rememberUpdatedState(ui.tracks)
    // a 3 × 2 grid under Reverb's picture: a track-colour dot and the send, each chip 40 tall (the touch target)
    Column(Modifier.fillMaxWidth().semantics { contentDescription = "Reverb sends" }, verticalArrangement = Arrangement.spacedBy(6.dp)) {
      ui.tracks.chunked(3).forEach { rowTracks -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        rowTracks.forEach { t ->
            val colour = Tok.track[(t.number - 1) % Tok.track.size]
            var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
            Row(
                Modifier.weight(1f).height(40.dp).clip(RoundedCornerShape(50)).background(Tok.control)
                    .onGloballyPositioned { coords = it }
                    .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Reverb send, track ${t.number} ${t.name}: ${t.sendText}. Opens its slide" }
                    .clickable {
                        val c = coords?.takeIf { it.isAttached } ?: return@clickable
                        menu?.open(c.localToWindow(Offset(c.size.width / 2f, c.size.height / 2f)), colour, listOf(
                            com.scottgerstl.lupe.ui.shell.HoldItem("REVERB SEND", group = "Mix", slide = com.scottgerstl.lupe.ui.shell.HoldSlide(
                                { latest.firstOrNull { it.number == t.number }?.send ?: 0 }, { latest.firstOrNull { it.number == t.number }?.sendText.orEmpty() }, 0, 127) { actions.send(t.number, it) }),
                        ))
                    }
                    .padding(start = 8.dp, end = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(Modifier.size(14.dp).background(colour, CircleShape))
                BasicText(t.sendText.removeSuffix("%").ifEmpty { "–" }, style = LupeType.number.copy(fontSize = 15.sp, lineHeight = 16.sp, fontWeight = FontWeight.Bold), maxLines = 1)
            }
        }
        // a short last row keeps the chips' width
        repeat(3 - rowTracks.size) { Spacer(Modifier.weight(1f)) }
      } }
    }
}

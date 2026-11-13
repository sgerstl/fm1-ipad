package com.scottgerstl.lupe.ui.shell

import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.RenderEffect
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkPhase
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/** How the link shows (design/structure-map.md › "The FM-1 disconnected", option A). */
enum class LinkMode { Normal, Card, Page }

fun linkMode(link: LinkState, everReady: Boolean): LinkMode = when {
    link.phase == LinkPhase.Ready -> LinkMode.Normal
    link.phase == LinkPhase.WrongFirmware -> LinkMode.Page
    !everReady -> LinkMode.Page
    else -> LinkMode.Card
}

private data class PageCopy(val title: String, val line: String, val busy: Boolean, val retry: Boolean)

private fun pageCopy(l: LinkState) = when (l.phase) {
    LinkPhase.WrongFirmware -> PageCopy(
        "This FM-1 isn't running Skiff",
        "Lupe on the phone works with Skiff firmware. This FM-1 reports ${l.firmware ?: "a firmware it doesn't know"}.",
        busy = false, retry = true,
    )
    LinkPhase.Connecting -> PageCopy("Found your FM-1", "Connecting to it.", busy = true, retry = false)
    LinkPhase.Reading -> PageCopy("Reading your FM-1", "Loading the project and the patterns.", busy = true, retry = false)
    LinkPhase.Lost -> PageCopy("Lost your FM-1", "Check the USB cable and that the FM-1 is on, then try again.", busy = false, retry = true)
    else -> PageCopy("Looking for your FM-1", "Plug it into the phone with a USB cable. Lupe finds it by itself.", busy = true, retry = false)
}

/** Searching (never connected this launch) and wrong firmware: a full page, below the status bar. */
@Composable
fun LinkPage(link: LinkState, core: LupeCore, modifier: Modifier = Modifier) {
    LupeCrossfade(pageCopy(link), modifier.fillMaxSize().background(Tok.page), Dur.STATE) { c ->
        Column(
            Modifier.fillMaxSize().padding(horizontal = 32.dp),
            verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            BasicText(c.title, Modifier.semantics { heading(); liveRegion = LiveRegionMode.Polite }, style = LupeType.title.copy(textAlign = TextAlign.Center))
            BasicText(c.line, Modifier.padding(top = 8.dp), style = LupeType.body.copy(textAlign = TextAlign.Center))
            if (c.busy) BusyBar(Modifier.padding(top = 24.dp))
            if (c.retry) Key({ core.send(Intent.Retry) }, "Try again", Modifier.padding(top = 20.dp), width = 160.dp, on = true) { fg -> KeyLabel("Try again", fg) }
        }
    }
}

private data class CardCopy(val line: String)

/** Lost, and back-and-reading: a card that drops from under the top bar over the faded page. */
@Composable
fun LinkCard(link: LinkState, modifier: Modifier = Modifier) {
    val line = when (link.phase) {
        LinkPhase.Reading -> "Back · reading the FM-1"
        else -> when (link.reason) {
            "unplugged" -> "The cable or the FM-1's power was removed. Looking for it."
            else -> "Lupe lost contact with it. Looking for it."
        }
    }
    Column(
        modifier.fillMaxWidth().padding(horizontal = 8.dp)
            .graphicsLayer { shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(12.dp); clip = false }
            .background(Tok.held, RoundedCornerShape(12.dp))
            .padding(16.dp)
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
    ) {
        BasicText("FM-1 disconnected", style = LupeType.title)
        LupeCrossfade(line, Modifier.padding(top = 4.dp)) { BasicText(it, style = LupeType.body.copy(color = Tok.text2Raised)) }
        BusyBar(Modifier.padding(top = 12.dp))
    }
}

/** An indeterminate bar. With Reduce Motion it stands still at half. */
@Composable
fun BusyBar(modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val x = if (reduce) 0.3f else rememberInfiniteTransition(label = "busy").animateFloat(
        0f, 0.6f, infiniteRepeatable(tween(1100, easing = LinearEasing), RepeatMode.Reverse), label = "busyX").value
    Box(
        modifier.width(160.dp).height(3.dp).clip(RoundedCornerShape(2.dp)).background(Tok.control)
            .drawBehind { drawRoundRect(Tok.text2Raised, Offset(size.width * x, 0f), Size(size.width * 0.4f, size.height), CornerRadius(2.dp.toPx())) }
            .semantics { },
    )
}

/** The page behind a lost card: dimmed and grey (300 ms), read-only. */
fun Modifier.greyedBy(amount: () -> Float): Modifier = graphicsLayer {
    val a = amount()
    alpha = 1f - 0.5f * a
    renderEffect = if (a > 0.01f) RenderEffect.createColorFilterEffect(ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(1f - a) })).asComposeRenderEffect() else null
}

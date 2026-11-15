package com.scottgerstl.lupe.ui.page

import android.graphics.Bitmap
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.scottgerstl.lupe.core.LupeNative
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import kotlin.math.floor
import kotlin.math.min

// Decision 46 (Scott, 2026-11-15): the sound panel's pictures drawn by Skiff's own code in the Swift core (ios/SkiffDraw), from the session's
// mirror, so their shapes and pixels are the FM-1's. Only when the FM-1 runs the Skiff-Lupe build SkiffDraw was copied from and only for its
// pages (GLO's four, FX › DELAY and REVERB, ENV, LFO, EDIT's OSC / FLT / FM6 / scope); anything else gets null and the hand-drawn picture.
// GLO's shared pages draw in the panel's grey ink, white kept (decision 34); track pages in the FM-1's own colours.

/** The panel's grey ink for GLO's shared pages (the SoundPanel's inkColour there: Tok.text2Raised). */
const val SKIFF_GLO_INK = 0xC4C4CC

/** One picture: [width] × [height] ARGB pixels, and whether it moves on its own (the LFO, the scope's sea). */
class SkiffPixels(val width: Int, val height: Int, val argb: IntArray, val animated: Boolean, val drawMicros: Int)

/** What LupeNative.skiffPicture returns, decoded: 8 bytes (width, height u16 LE; animated; µs u16 LE; 0), then RGBA. Null when there is none. */
fun decodeSkiffPicture(b: ByteArray?): SkiffPixels? {
    if (b == null || b.size < 8) return null
    fun u(i: Int) = b[i].toInt() and 255
    val w = u(0) or (u(1) shl 8)
    val h = u(2) or (u(3) shl 8)
    if (w <= 0 || h <= 0 || b.size < 8 + w * h * 4) return null
    val px = IntArray(w * h) { i -> val o = 8 + 4 * i; (u(o + 3) shl 24) or (u(o) shl 16) or (u(o + 1) shl 8) or u(o + 2) }
    return SkiffPixels(w, h, px, u(4) != 0, u(5) or (u(6) shl 8))
}

/** Where pictures come from: the native core, or nothing (unit tests, previews, before the library loads). */
fun interface SkiffSource { fun picture(page: Int, gloInk: Int): ByteArray? }

val LocalSkiffSource = staticCompositionLocalOf<SkiffSource?> {
    if (LupeNative.isLoaded) SkiffSource { p, ink -> LupeNative.skiffPicture(p, ink) } else null
}

/** The FM-1's own picture of [page], or null (then draw the app's own). Asked again whenever the page's state changes (a knob, the track,
 *  the bus), and about 30 times a second while an animated one shows (not with Reduce Motion: then it holds still). */
@Composable
fun rememberSkiffPicture(page: PageState, glo: Boolean, enabled: Boolean): SkiffPixels? {
    val src = LocalSkiffSource.current
    if (!enabled || src == null) return null
    val ink = if (glo) SKIFF_GLO_INK else 0
    // the page as it is now (a new PageState after every change), then, for a moving one, newer frames until the page changes again
    val first = remember(page, glo) { decodeSkiffPicture(src.picture(page.page, ink)) }
    var live by remember(page, glo) { mutableStateOf<SkiffPixels?>(null) }
    val moving = first?.animated == true && !LocalReduceMotion.current
    LaunchedEffect(page, glo, moving) {
        if (!moving) return@LaunchedEffect
        var last = 0L
        while (true) {
            val now = withFrameMillis { it }
            if (now - last < 33) continue
            last = now
            live = decodeSkiffPicture(src.picture(page.page, ink)) ?: break
        }
    }
    return live ?: first
}

/** Draws [p] whole pixels at a time where the space allows (nearest neighbour, never smoothed), centred, at its own 234 : 138. */
@Composable
fun SkiffPictureImage(p: SkiffPixels, description: String, modifier: Modifier = Modifier) {
    val img = remember(p) { Bitmap.createBitmap(p.argb, p.width, p.height, Bitmap.Config.ARGB_8888).asImageBitmap() }
    Canvas(modifier.clearAndSetSemantics { contentDescription = description }) {
        val fit = min(size.width / p.width, size.height / p.height)
        val s = if (fit >= 1f) floor(fit) else fit                    // whole device pixels per FM-1 pixel where it fits
        val w = (p.width * s).toInt(); val h = (p.height * s).toInt()
        val x = ((size.width - w) / 2).toInt(); val y = ((size.height - h) / 2).toInt()
        drawImage(img, dstOffset = IntOffset(x, y), dstSize = IntSize(w, h), filterQuality = FilterQuality.None)
    }
}

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
import androidx.compose.foundation.layout.fillMaxSize
import kotlin.math.min

// Decision 46 (Scott, 2026-11-15): the sound panel's pictures drawn by Skiff's own code in the Swift core (ios/SkiffDraw), from the session's
// mirror, so their shapes and pixels are the FM-1's. Only when the FM-1 runs the Skiff-Lupe build SkiffDraw was copied from and only for its
// pages (GLO's four, FX › DELAY and REVERB, ENV, LFO, EDIT's OSC / FLT / FM6 / scope); anything else gets null and the hand-drawn picture.
// GLO's shared pages draw in the panel's grey ink, white kept (decision 34); track pages in the FM-1's own colours.

/** The panel's grey ink for GLO's shared pages (the SoundPanel's inkColour there: Tok.text2Raised). */
const val SKIFF_GLO_INK = 0xC4C4CC

/** The picture box's background (Tok.well): the FM-1's panel surface is drawn in it, so the picture has no frame of its own. */
const val SKIFF_SURFACE = 0x111114

/** One picture: [width] × [height] pixels, kept as the core sent them (RGBA, premultiplied: a transparent pixel is all 0) in [bytes] from
 *  offset 8, so they go into a bitmap as they are (Bitmap.copyPixelsFromBuffer: ARGB_8888's memory order is RGBA). [animated]: it moves
 *  on its own (the LFO, the scope's sea). */
class SkiffPixels(val width: Int, val height: Int, val bytes: ByteArray, val animated: Boolean, val drawMicros: Int) {
    /** Pixel [i] as ARGB (the tests). */
    fun argb(i: Int): Int {
        val o = 8 + 4 * i
        fun u(k: Int) = bytes[o + k].toInt() and 255
        return (u(3) shl 24) or (u(0) shl 16) or (u(1) shl 8) or u(2)
    }
}

/** What LupeNative.skiffPicture returns, checked: 8 bytes (width, height u16 LE; animated; µs u16 LE; 0), then RGBA. Null when there is none. */
fun decodeSkiffPicture(b: ByteArray?): SkiffPixels? {
    if (b == null || b.size < 8) return null
    fun u(i: Int) = b[i].toInt() and 255
    val w = u(0) or (u(1) shl 8)
    val h = u(2) or (u(3) shl 8)
    if (w <= 0 || h <= 0 || b.size < 8 + w * h * 4) return null
    return SkiffPixels(w, h, b, u(4) != 0, u(5) or (u(6) shl 8))
}

/** How often a moving picture is asked for again: 20 a second. Each frame costs the main thread, where the core's own updates wait (the
 *  Pixel's rail went dead when the sea redrew 30 times a second with a full copy of the state and new bitmaps each frame, 2026-11-15). */
const val SKIFF_FRAME_MS = 50L

/** Where pictures come from: the native core, or nothing (unit tests, previews, before the library loads). */
fun interface SkiffSource { fun picture(page: Int, gloInk: Int, surface: Int): ByteArray? }

val LocalSkiffSource = staticCompositionLocalOf<SkiffSource?> {
    if (LupeNative.isLoaded) SkiffSource { p, ink, surf -> LupeNative.skiffPicture(p, ink, surf) } else null
}

/** A picture on show: [current] is its latest frame (a state read only by [SkiffPictureImage], so a moving picture's frames redraw the picture
 *  and nothing else around it). */
class SkiffPicture(first: SkiffPixels) { var current by mutableStateOf(first) }

/** The FM-1's own picture of [page], or null (then draw the app's own). Asked again whenever the page's state changes (a knob, the track,
 *  the bus), and every [SKIFF_FRAME_MS] while a moving one shows (not with Reduce Motion: then it holds still). */
@Composable
fun rememberSkiffPicture(page: PageState, glo: Boolean, enabled: Boolean): SkiffPicture? {
    val src = LocalSkiffSource.current
    if (!enabled || src == null) return null
    val ink = if (glo) SKIFF_GLO_INK else 0
    // the page as it is now (a new PageState after every change), then, for a moving one, newer frames until the page changes again
    val first = remember(page, glo) { decodeSkiffPicture(src.picture(page.page, ink, SKIFF_SURFACE)) } ?: return null
    val holder = remember(page, glo) { SkiffPicture(first) }
    val moving = first.animated && !LocalReduceMotion.current
    // Never a frame always pending: while one is, Choreographer's barrier holds back the main thread's ordinary messages, the intents to the
    // core among them (BridgedLupeCore's scope.launch), and the Pixel's rail went dead while the sea moved (2026-11-15). So a new picture is
    // set, then an ordinary message is posted and awaited (it runs only once the frame that draws the picture is done and its barrier gone,
    // after anything queued before it, such as a tap's intent), and only then the pause: SKIFF_FRAME_MS with nothing pending.
    LaunchedEffect(holder, moving) {
        if (!moving) return@LaunchedEffect
        while (true) {
            kotlinx.coroutines.delay(SKIFF_FRAME_MS)
            holder.current = decodeSkiffPicture(src.picture(page.page, ink, SKIFF_SURFACE)) ?: break
            afterFrame()
        }
    }
    return holder
}

/** Whether the FM-1's picture goes under a page's list of tiles (MOD's routes, LANES, SOUND, OPERATOR) in [heightPx] shared half and half:
 *  only while its half gives it at least 2× the FM-1's 138 px; otherwise the tiles, Lupe's controls, have the space alone. */
fun skiffBesideTiles(heightPx: Float): Boolean = heightPx / 2f >= 2f * 138f

/** How [p] is scaled into a box of [boxW] × [boxH] pixels: as large as fits at its own 234 : 138 (1.7 : 1). [whole] is the whole-number
 *  factor it is first enlarged by, nearest neighbour, so each FM-1 pixel is a crisp block; when the fit itself is whole (or nearly) that is all,
 *  otherwise the enlarged copy is brought down to the fit with one smoothing step, which softens only the blocks' edges (Pixel 10's box: 2.75×,
 *  drawn as 3× then 0.92). Pure, for the tests. */
data class SkiffFit(val width: Int, val height: Int, val whole: Int, val exact: Boolean)

fun skiffFit(pw: Int, ph: Int, boxW: Float, boxH: Float): SkiffFit {
    val fit = min(boxW / pw, boxH / ph)
    if (fit <= 0f) return SkiffFit(0, 0, 1, true)
    val near = kotlin.math.round(fit)
    val exact = near >= 1f && kotlin.math.abs(fit - near) < 0.03f
    val f = if (exact) near else fit
    return SkiffFit((pw * f).toInt(), (ph * f).toInt(), if (exact) near.toInt() else kotlin.math.ceil(fit).toInt().coerceIn(1, 8), exact)
}

/** The bitmaps a picture is drawn from, made once and filled again for every frame: the FM-1's pixels, and the copy enlarged by a whole number. */
private class SkiffBitmaps {
    var small: Bitmap? = null
    var big: Bitmap? = null
    private val paint = android.graphics.Paint().apply { isFilterBitmap = false; isAntiAlias = false }
    var version = 0
    fun fill(p: SkiffPixels, whole: Int): Bitmap {
        val s = small?.takeIf { it.width == p.width && it.height == p.height } ?: Bitmap.createBitmap(p.width, p.height, Bitmap.Config.ARGB_8888).also { small = it }
        s.copyPixelsFromBuffer(java.nio.ByteBuffer.wrap(p.bytes, 8, p.width * p.height * 4))
        version++
        if (whole <= 1) return s
        val bw = p.width * whole; val bh = p.height * whole
        val b = big?.takeIf { it.width == bw && it.height == bh } ?: Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888).also { big = it }
        b.eraseColor(0)
        android.graphics.Canvas(b).drawBitmap(s, null, android.graphics.Rect(0, 0, bw, bh), paint)   // nearest neighbour: crisp blocks
        return b
    }
}

private val mainHandler by lazy { android.os.Handler(android.os.Looper.getMainLooper()) }

/** Resumes once an ordinary message posted now runs on the main thread: after the frame in hand is drawn (Choreographer's barrier holds
 *  ordinary messages until then) and after every message posted before it. */
private suspend fun afterFrame() = kotlinx.coroutines.suspendCancellableCoroutine<Unit> { c ->
    val r = Runnable { c.resume(Unit) { } }
    mainHandler.post(r)
    c.invokeOnCancellation { mainHandler.removeCallbacks(r) }
}

/** Draws [p] filling the box at its own 1.7 : 1, centred, its pixels crisp (see [skiffFit]). */
@Composable
fun SkiffPictureImage(picture: SkiffPicture, description: String, modifier: Modifier = Modifier) {
    androidx.compose.foundation.layout.BoxWithConstraints(modifier.clearAndSetSemantics { contentDescription = description }) {
        val p = picture.current
        val d = androidx.compose.ui.platform.LocalDensity.current
        val fit = skiffFit(p.width, p.height, with(d) { maxWidth.toPx() }, with(d) { maxHeight.toPx() })
        val bitmaps = remember { SkiffBitmaps() }
        // a moving picture (the sea, the LFO) is drawn from its own 234 × 138 pixels, scaled by the GPU nearest neighbour: a frame then
        // uploads 130 kB, not the enlarged copy's 1 MB, and nothing is enlarged on the main thread
        val whole = if (p.animated) 1 else fit.whole
        val img = remember(p, whole) { bitmaps.fill(p, whole).asImageBitmap() }
        Canvas(androidx.compose.ui.Modifier.fillMaxSize()) {
            val x = ((size.width - fit.width) / 2).toInt(); val y = ((size.height - fit.height) / 2).toInt()
            drawImage(img, dstOffset = IntOffset(x, y), dstSize = IntSize(fit.width, fit.height),
                      filterQuality = if (fit.exact || p.animated) FilterQuality.None else FilterQuality.Low)
        }
    }
}

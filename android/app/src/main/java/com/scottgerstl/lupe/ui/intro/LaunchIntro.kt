package com.scottgerstl.lupe.ui.intro

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.R
import com.scottgerstl.lupe.ui.intro.IntroMath.FRESH
import com.scottgerstl.lupe.ui.intro.IntroMath.OLD
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/** The splash screen's icon, in dp (res/drawable/splash_icon.xml centres the art at this size): where the zoom starts, so the hand-off is seamless. */
const val SPLASH_ICON_DP = 160

/**
 * Lupe's launch intro, ported from ios/FM1/LaunchIntro.swift (approved prototype: design/brand/intro-prototype.html). Drawn on a canvas over the app:
 * the icon grows from the splash screen's size past the screen, a line opens, one pass of the Lissajous with the trail cooling from white to dim grey,
 * the beam settles to the icon's rest, "lupe" fades in, a hold, then the CRT switch-off while the app fades up behind it. About 2.9 s (IntroMath).
 * Each bit of trail is drawn from its age in the prototype's 60 Hz frames, so the picture is the same at any frame rate. A tap skips to the app.
 * With [reduceMotion] (Remove animations): the finished logo fades in and crossfades to the app. Only one flash (WCAG 2.3.1).
 * [frozenAt] holds the intro at that many seconds (to compare frames with the iPhone build's `-intro-at`).
 */
@Composable
fun LaunchIntro(reduceMotion: Boolean, onDone: () -> Unit, modifier: Modifier = Modifier, frozenAt: Double? = null) {
    val icon = ImageBitmap.imageResource(R.drawable.lupe_icon)
    val word = ImageBitmap.imageResource(R.drawable.lupe_wordmark)
    var t by remember { mutableDoubleStateOf(frozenAt ?: 0.0) }
    var finished by remember { mutableStateOf(false) }
    fun finish() { if (!finished) { finished = true; onDone() } }
    val limit = if (reduceMotion) IntroMath.REDUCED_END else IntroMath.end
    LaunchedEffect(frozenAt, reduceMotion) {
        if (frozenAt != null) return@LaunchedEffect
        var start = 0L
        while (true) {
            val now = androidx.compose.runtime.withFrameNanos { it }
            if (start == 0L) start = now
            t = (now - start) / 1e9
            if (t >= limit) { finish(); break }
        }
    }
    Canvas(
        modifier.fillMaxSize()
            // the switch-off erases to nothing over the app behind: an offscreen layer lets Src replace pixels
            .graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)
            .pointerInput(Unit) { detectTapGestures { finish() } }       // a tap skips straight to the app
            .semantics(mergeDescendants = true) { contentDescription = "Lupe. Starting. Tap to skip."; role = Role.Button; onClick("Skip") { finish(); true } },
    ) {
        val scene = IntroScene(this, SPLASH_ICON_DP.dp.toPx(), icon, word)
        if (reduceMotion) scene.drawReduced(t) else scene.draw(t)
    }
}

/** The prototype's drawing at time t, in the canvas of [d]. Geometry as the Swift's IntroScene. */
private class IntroScene(val d: DrawScope, val iconSide: Float, val icon: ImageBitmap, val word: ImageBitmap) {
    val W = d.size.width; val H = d.size.height
    val S = min(W, H) * 0.525f                               // the scope square
    val ox = (W - S) / 2; val oy = (H - S * 1.32f) / 2       // the scope and the name centred as one group
    val glass = Color(10 / 255f, 10 / 255f, 11 / 255f)

    fun X(v: Double) = ox + (v / 100 * S).toFloat()
    fun Y(v: Double) = oy + (v / 100 * S).toFloat()
    fun P(u: Double): Offset { val f = IntroMath.fig(u); return Offset(X(f.first), Y(f.second)) }
    fun white(a: Float) = Color(244 / 255f, 244 / 255f, 246 / 255f).copy(alpha = a.coerceIn(0f, 1f))
    fun rgb(c: Triple<Double, Double, Double>, a: Double = 1.0) = Color((c.first / 255).toFloat(), (c.second / 255).toFloat(), (c.third / 255).toFloat(), a.toFloat().coerceIn(0f, 1f))

    fun draw(t: Double) = with(d) {
        drawRect(glass)
        when {
            t < IntroMath.tz -> zoom(IntroMath.ease(t / IntroMath.ZOOM))
            t < IntroMath.tf -> {
                graticule(1f)
                val e = (t - IntroMath.tz) / IntroMath.FLASH; val h = (S * e.pow(2.2)).toFloat(); val a = 1 - e * 0.85
                // flat: a white line opening, no bloom and no flash
                val hh = max(2.dp.toPx(), h)
                drawRect(rgb(FRESH, a * 0.6), Offset(ox - S * 0.15f * (1 - e.toFloat()), oy + S / 2 - hh / 2), Size(S * (1 + 0.3f * (1 - e.toFloat())), hh))
            }
            t < IntroMath.th -> scope(t, 1f)
            else -> off(t - IntroMath.th)
        }
    }

    /** 1. The icon grows to full size, the scope off: the splash's icon crossfades into the dark scope while the room around it goes from #0A0A0B to black. */
    private fun zoom(e: Double) = with(d) {
        drawRect(Color.Black.copy(alpha = e.toFloat()))
        val side = iconSide + (max(W, H) * 1.05f - iconSide) * e.toFloat()
        val left = (W - side) / 2; val top = (H - side) / 2
        val shape = Path().apply { addRoundRect(RoundRect(left, top, left + side, top + side, CornerRadius(side * 0.225f * (1 - e.toFloat())))) }
        drawPath(shape, glass)
        graticule(0.6f * e.toFloat())
        // the icon's art gone by a third of the zoom
        clipPath(shape) {
            drawImage(icon, srcSize = IntSize(icon.width, icon.height), dstOffset = IntOffset(left.toInt(), top.toInt()), dstSize = IntSize(side.toInt(), side.toInt()), alpha = max(0f, 1 - e.toFloat() * 3))
        }
    }

    /** 3–5: the trace, the settle, the name. [ga] is the whole picture's alpha (Reduce Motion fades it). */
    private fun scope(t: Double, ga: Float) {
        graticule(ga)
        floorFigure((min(1.0, (t - IntroMath.tf) / 0.4)).toFloat() * ga)
        trail(t, ga)
        beam(IntroMath.beamU(t), ga)
        if (t >= IntroMath.na) name(IntroMath.ease((t - IntroMath.na) / IntroMath.NAME).toFloat() * ga)
    }

    /** The phosphor: every bit of the path the beam has drawn, coloured and faded by its age. */
    private fun trail(t: Double, ga: Float) = with(d) {
        val uNow = IntroMath.beamU(t)
        if (uNow <= 0) return
        val n = IntroMath.trailSegments(uNow)
        val w = S * 0.028f
        for (i in 0 until n) {
            val u0 = uNow * i / n; val u1 = uNow * (i + 1) / n
            val age = IntroMath.coolFrames(IntroMath.paintTime((u0 + u1) / 2), t)
            val (k, a) = IntroMath.cool(age)
            drawLine(rgb(IntroMath.mix(OLD, FRESH, k), a * ga), P(u0), P(u1), w, StrokeCap.Round)
        }
    }

    private fun graticule(a: Float) = with(d) {
        val lw = max(1f, S / 400)
        var v = 14.0
        while (v <= 86) {
            drawLine(white(0.07f * a), Offset(X(v), Y(14.0)), Offset(X(v), Y(86.0)), lw)
            drawLine(white(0.07f * a), Offset(X(14.0), Y(v)), Offset(X(86.0), Y(v)), lw)
            v += 12
        }
        for (k in 0..30) {
            val v2 = 14 + 2.4 * k
            drawLine(white(0.12f * a), Offset(X(v2), Y(48.8)), Offset(X(v2), Y(51.2)), lw)
            drawLine(white(0.12f * a), Offset(X(48.8), Y(v2)), Offset(X(51.2), Y(v2)), lw)
        }
    }

    /** The faint full figure still lit. */
    private fun floorFigure(a: Float) = with(d) {
        val p = Path()
        for (i in 0..600) { val pt = P(i / 600.0); if (i == 0) p.moveTo(pt.x, pt.y) else p.lineTo(pt.x, pt.y) }
        drawPath(p, white(0.10f * a), style = Stroke(S * 0.022f, join = StrokeJoin.Round))
    }

    /** The beam: a flat white dot and a faint ring round it (no halo). */
    private fun beam(u: Double, a: Float) = with(d) {
        val c = P(u); val dot = S * 0.026f; val r = S * 0.05f
        drawCircle(white(0.18f * a), r, c, style = Stroke(max(1f, S / 300)))
        drawCircle(Color.White.copy(alpha = a), dot, c)
    }

    /** The name: the wordmark (Michroma, the e's bar tilted; design/brand/wordmark.py), flat white, no glow. */
    private fun name(a: Float) = with(d) {
        val w = S * 0.62f; val h = w * word.height / word.width
        drawImage(word, srcSize = IntSize(word.width, word.height), dstOffset = IntOffset((W / 2 - w / 2).toInt(), (oy + S * 1.3f - h * 0.78f).toInt()), dstSize = IntSize(w.toInt(), h.toInt()), alpha = a)
    }

    /** 6. The switch-off: the picture squashes to a line, the line pinches to a dot, the dot blips out over the app. */
    private fun off(dt: Double) = with(d) {
        val cy = oy + S * 0.66f; val cx = W / 2
        when {
            dt < IntroMath.SQUASH -> {
                drawRect(Color.Black)
                val e = IntroMath.ease(dt / IntroMath.SQUASH); val sy = max(0.004, 1 - e).toFloat()
                withTransform({ translate(0f, cy); scale(1f, sy, Offset.Zero); translate(0f, -cy) }) {
                    drawRect(glass)
                    scope(IntroMath.th, 1f)                       // the held frame
                }
                drawRect(rgb(FRESH, 0.35 * e), Offset(0f, cy - H * sy / 2), Size(W, H * sy))
            }
            dt < IntroMath.SQUASH + IntroMath.PINCH -> {
                drawRect(Color.Black)
                val e = IntroMath.ease((dt - IntroMath.SQUASH) / IntroMath.PINCH); val w = W * 0.9f * (1 - e.toFloat()) + S * 0.03f
                drawRect(rgb(FRESH), Offset(cx - w / 2, cy - S * 0.006f), Size(w, S * 0.012f))
            }
            else -> {
                // the app comes up behind: this layer's black goes as the dot blips out
                val e = min(1.0, (dt - IntroMath.SQUASH - IntroMath.PINCH) / IntroMath.BLIP)
                drawRect(Color.Black.copy(alpha = (1 - IntroMath.ease(e)).toFloat()), blendMode = BlendMode.Src)
                val r = S * (0.012f + 0.02f * sin(min(1.0, e * 1.6) * PI).toFloat()); val a = 1 - e
                drawCircle(rgb(FRESH, a), r, Offset(cx, cy))
            }
        }
    }

    /** Reduce Motion: the finished logo fades in, then crossfades to the app. */
    fun drawReduced(t: Double) = with(d) {
        val fadeIn = min(1.0, t / IntroMath.REDUCED_FADE_IN); val out = if (t < IntroMath.REDUCED_HOLD) 0.0 else min(1.0, (t - IntroMath.REDUCED_HOLD) / IntroMath.REDUCED_FADE_OUT)
        drawRect(glass.copy(alpha = (1 - out).toFloat()), blendMode = BlendMode.Src)
        // the rest pose: long after the trace, nothing moves
        scope(IntroMath.ts + 10, (fadeIn * (1 - out)).toFloat())
    }
}

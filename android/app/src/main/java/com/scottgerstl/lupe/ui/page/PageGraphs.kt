package com.scottgerstl.lupe.ui.page

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.BoxWithConstraintsScope
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.GraphKind
import com.scottgerstl.lupe.core.PageGraph
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.tanh

// The page pictures, ported from ios/FM1/PageGraphs.swift (which mirrors Skiff's ui_graph.c / ui_pgraph.c): Skiff's own 240 × 140 drawing
// space stretched to the panel, in the track's colour. Taken out by decision 25, back by decision 30 behind Settings › Show graphics, drawn
// under the page's four dials. Ported: ENV, LFO (a sweep, not the live clock), DRIVE, FX sends, SCALE, ARP, EDIT 1's ANALOG picture.

private const val GW = 240f
private const val GH = 140f

private val line = Tok.stepEmpty   // T_LINE
private val dim = Tok.text3        // T_DIM: decoration only, never words that carry information
private val mid = Tok.text2        // T_MID

/** Skiff's space on a canvas: x 0…240 and y 0…140 stretched to the size. */
private class Sp(val d: DrawScope, val tm: TextMeasurer) {
    fun Float.px() = with(d) { this@px.dp.toPx() }
    val w get() = d.size.width
    val h get() = d.size.height
    fun x(v: Float) = v / GW * w
    fun y(v: Float) = v / GH * h
    fun o(x: Float, y: Float) = Offset(x(x), y(y))
    fun path(pts: List<Pair<Float, Float>>, close: Boolean = false) = Path().apply {
        pts.forEachIndexed { i, p -> if (i == 0) moveTo(x(p.first), y(p.second)) else lineTo(x(p.first), y(p.second)) }
        if (close) close()
    }
    fun rect(c: Color, x: Float, y: Float, w: Float, h: Float, r: Float = 0f) =
        d.drawRoundRect(c, o(x, y), Size(x(w), y(h)), CornerRadius(r.px()))
    fun stroke(c: Color, pts: List<Pair<Float, Float>>, width: Float = 2.5f) =
        d.drawPath(path(pts), c, style = Stroke(width.px(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    fun text(s: String, x: Float, base: Float, c: Color, size: Float = 11f, right: Boolean = false) {
        val r = tm.measure(s, LupeType.small.copy(fontSize = size.sp, color = c))
        val ox = x(x) - if (right) r.size.width else 0
        d.drawText(r, topLeft = Offset(ox, y(base) - r.size.height))
    }
}

/** True when the page has a picture to draw. */
fun hasPicture(g: PageGraph): Boolean = when (g.kind) {
    GraphKind.Env, GraphKind.Lfo, GraphKind.Drive, GraphKind.Fx, GraphKind.Scale, GraphKind.Arp, GraphKind.Analog,
    GraphKind.FxDelay, GraphKind.FxReverb, GraphKind.Insert, GraphKind.Slicer, GraphKind.Duck, GraphKind.Delay, GraphKind.Reverb -> true
    GraphKind.Fm6Op, GraphKind.Fm6All -> g.fm6 != null
    GraphKind.Sound -> g.sheet != null
    else -> false
}

/** The page's picture for [g] (decision 30: under the dials, shown by Settings › Show graphics). [hot] is the control the FM-1's knob is turning (0…3), or -1. Read-only: the dials are the controls. */
@Composable
fun GraphContent(g: PageGraph, colour: Color, hot: Int, modifier: Modifier = Modifier) {
    when (g.kind) {
        GraphKind.Fm6Op -> Fm6OperatorPicture(g, colour, modifier)
        GraphKind.Fm6All -> Fm6AllOpsPicture(g, colour, modifier)
        GraphKind.Sound -> SoundSheetPicture(g, modifier)
        GraphKind.Env -> EnvGraph(g, colour, hot, modifier)
        GraphKind.Lfo, GraphKind.Drive, GraphKind.Fx, GraphKind.Scale, GraphKind.Arp, GraphKind.Analog,
        GraphKind.FxDelay, GraphKind.FxReverb, GraphKind.Insert, GraphKind.Slicer, GraphKind.Duck, GraphKind.Delay, GraphKind.Reverb -> CanvasGraph(g, colour, hot, modifier)
        else -> Unit
    }
}

private fun describe(g: PageGraph): String = when (g.kind) {
    GraphKind.Env -> "Envelope shape. " + listOf("attack", "decay", "sustain", "release").mapIndexed { i, n -> "$n ${g.values.getOrElse(i) { 0 }}" }.joinToString(", ")
    GraphKind.Lfo -> "LFO wave. ${g.caption ?: ""}"
    GraphKind.Drive -> "Drive curve. ${g.caption ?: ""} ${g.side ?: ""}"
    GraphKind.Fx -> "FX sends: " + listOf("drive", "chorus", "delay", "reverb").mapIndexed { i, n -> "$n ${g.values.getOrElse(i) { 0 }}" }.joinToString(", ")
    GraphKind.Scale -> "Scale keys. ${g.side ?: ""}"
    GraphKind.Arp -> "Arpeggio pattern. ${g.side ?: ""}"
    GraphKind.Fm6Op -> "Operator envelopes and operator tiles"
    GraphKind.Fm6All -> "FM algorithm chart"
    GraphKind.Sound -> "DRUM-X sound sheet"
    GraphKind.Analog -> "Oscillator and filter. ${g.caption ?: ""}, ${g.side ?: ""}"
    GraphKind.FxDelay, GraphKind.Delay -> "Echoes: feedback ${g.values.getOrElse(1) { 0 }}" + if (g.kind == GraphKind.FxDelay) ", send ${g.send}" else ""
    GraphKind.FxReverb, GraphKind.Reverb -> "Reverb tail: size ${g.values.getOrElse(1) { 0 }}" + if (g.kind == GraphKind.FxReverb) ", send ${g.send}" else ""
    GraphKind.Insert -> if (g.values.getOrElse(0) { 0 } == 9) "Filter response, cutoff ${g.caption ?: ""}" else "Insert: " + (INSERT_NAMES.getOrNull(g.values.getOrElse(0) { 0 }) ?: "OFF")
    GraphKind.Slicer -> "Slicer pattern ${g.values.getOrElse(1) { 1 }}"
    GraphKind.Duck -> if (g.notes.isEmpty()) "Ducking: no source" else "Ducking over a bar, depth ${g.values.getOrElse(0) { 0 }}"
    else -> ""
}

// ---- ENV: ADSR, with a handle to drag for each point (the controls under it are the non-drag way in)

private class EnvGeo(v: List<Int>) {
    val a = 4f + (v.getOrElse(0) { 0 } * 50 / 127)
    val d = 6f + (v.getOrElse(1) { 0 } * 50 / 127)
    val r = 6f + (v.getOrElse(3) { 0 } * 60 / 127)
    val x1 = 12f + a
    val x3 = 226f - r
    val top = 6f * GH / 100f
    val bot = 88f * GH / 100f
    val sus = v.getOrElse(2) { 0 } / 127f
    fun y(l: Float) = bot - l * (bot - top)
}

@Composable
private fun EnvGraph(g: PageGraph, colour: Color, hot: Int, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val geo = EnvGeo(g.values)
    Canvas(
        modifier
            .semantics { contentDescription = describe(g) }
    ) {
        val s = Sp(this, tm)
        for (gy in listOf(geo.top, (geo.top + geo.bot) / 2, geo.bot)) s.rect(line, 12f, gy, 216f, 1f)
        val atk = listOf(12f to geo.bot, geo.x1 to geo.top)
        val dec = mutableListOf(geo.x1 to geo.top)
        var e = 1f
        val kd = 1f - 4.6f / geo.d
        var i = 1f
        while (i <= geo.d) { e *= kd; dec += (geo.x1 + i) to geo.y(geo.sus + (1f - geo.sus) * e); i += 1f }
        val hold = listOf(dec.last(), geo.x3 to geo.y(geo.sus))
        val rel = mutableListOf(geo.x3 to geo.y(geo.sus))
        e = 1f
        val kr = 1f - 4.6f / geo.r
        i = 1f
        while (i <= geo.r) { e *= kr; rel += (geo.x3 + i) to geo.y(geo.sus * e); i += 1f }
        val all = atk + dec.drop(1) + hold.drop(1) + rel.drop(1)
        val fill = s.path(all, false).apply { lineTo(s.x(rel.last().first), s.y(geo.bot)); lineTo(s.x(12f), s.y(geo.bot)); close() }
        drawPath(fill, colour.copy(alpha = 0.14f))
        // the segment being changed is drawn white (board 55): ATTACK the rise, DECAY the fall, SUSTAIN the hold, RELEASE the end
        fun seg(pts: List<Pair<Float, Float>>, on: Boolean) = s.stroke(if (on) Tok.text else colour, pts)
        seg(atk, hot == 0); seg(dec, hot == 1); seg(hold, hot == 2); seg(rel, hot == 3)
        // a mark on each of the four points
        val handles = listOf(geo.x1 to geo.top, geo.x1 + geo.d to geo.y(geo.sus), (geo.x1 + geo.d + geo.x3) / 2 to geo.y(geo.sus), geo.x3 to geo.y(geo.sus))
        handles.forEachIndexed { n, (hx, hy) ->
            val on = hot == n
            val c = s.o(hx, hy)
            drawRoundRect(if (on) Tok.text else colour, Offset(c.x - 6.dp.toPx(), c.y - 6.dp.toPx()), Size(12.dp.toPx(), 12.dp.toPx()), CornerRadius(2.dp.toPx()))
        }
    }
}

// ---- everything drawn on a plain canvas

@Composable
private fun CanvasGraph(g: PageGraph, colour: Color, hot: Int, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val reduce = LocalReduceMotion.current
    // the LFO's "now" dot sweeps its two seconds; with Reduce Motion it stays at the start
    val sweep by rememberInfiniteTransition(label = "lfo").animateFloat(0f, 1f, infiniteRepeatable(tween(2000, easing = LinearEasing), RepeatMode.Restart), label = "now")
    val now = if (reduce) 0f else sweep
    Canvas(modifier.clearAndSetSemantics { contentDescription = describe(g) }) {
        val s = Sp(this, tm)
        when (g.kind) {
            GraphKind.Lfo -> drawLfo(s, g, colour, now)
            GraphKind.Drive -> drawDrive(s, g, colour)
            GraphKind.Fx -> drawFx(s, g, colour)
            GraphKind.Scale -> drawScale(s, g, colour)
            GraphKind.Arp -> drawArp(s, g, colour)
            GraphKind.Analog -> drawAnalog(s, g, colour)
            GraphKind.FxDelay, GraphKind.Delay -> drawDelay(s, g, colour)
            GraphKind.FxReverb, GraphKind.Reverb -> drawReverb(s, g, colour)
            GraphKind.Insert -> drawInsert(s, g, colour)
            GraphKind.Slicer -> drawSlicer(s, g, colour)
            GraphKind.Duck -> drawDuck(s, g, colour)
            else -> Unit
        }
    }
}

private fun lfoWave(w: Int, cycles: Double): Double {
    val ph = cycles - kotlin.math.floor(cycles)
    return when (w) {
        1 -> if (ph < 0.5) ph * 4 - 1 else 3 - ph * 4
        2 -> ph * 2 - 1
        3 -> if (ph < 0.5) 1.0 else -1.0
        4 -> { val n = (kotlin.math.floor(cycles).toLong() and 0xFFFFFFFFL); (((n * 2654435761L) and 0xFFFFFFFFL) shr 16).toInt().let { (it - 32768) / 32768.0 } }
        else -> sin(ph * 2 * Math.PI)
    }
}

private fun drawLfo(s: Sp, g: PageGraph, c: Color, now: Float) {
    val rate = g.values.getOrElse(0) { 60 }; val wave = g.values.getOrElse(1) { 0 }; val phase = g.values.getOrElse(2) { 0 }
    val hz = 0.05 * 800.0.pow(rate / 127.0)
    val cycles = (hz * 2).coerceIn(0.5, 12.0)   // TODO: Skiff's view scrolls at the real rate from the restart, and FADE ramps in; this is the plain two seconds
    val cy = GH / 2; val a = 38f * GH / 100f
    s.rect(Tok.lifted, 12f, cy, 216f, 1f)
    val pts = (0..216).map { x -> (12f + x) to (cy - (lfoWave(wave, cycles * x / 216.0 + phase / 127.0)).toFloat() * a) }
    s.stroke(c, pts)
    val k = (now * 216).toInt().coerceIn(0, 216)
    val (dx, dy) = pts[k]
    s.rect(Tok.text, dx - 5f, dy - 5f * GH / GW * 1.7f, 10f, 10f * GH / GW * 1.7f, 2f)
    g.caption?.let { s.text(it, 228f, 16f, mid, right = true) }
}

private fun softclip(x: Int): Int { val a = min(abs(x), 65536); val y = (32767 * tanh(a / 32768.0)).toInt(); return if (x < 0) -y else y }
private fun mulq15(a: Int, b: Int) = (a * b) shr 15
private fun driveShape(ty: Int, v: Int, sh: Int): Int = when (ty) {
    0 -> softclip(v)
    1 -> v.coerceIn(-24000, 24000)
    2 -> { var u = ((v + 16384) and 0xFFFF) - 32768; u = 16384 - abs(u); u + (u shr 1) }
    3 -> ((v + ((1 shl sh) shr 1)) shr sh) shl sh
    4 -> if (v > 0) min(v, 20000) else softclip(v) shr 1
    else -> v
}
private fun driveAt(type: Int, d: Int, x: Int): Int {
    if (d == 0) return x
    if (type == 3) return mulq15(driveShape(3, x, d / 11), 32000 - d * 20)
    val g = 4096 + d * d * 2; val y0 = ((x shr 2) * g) shr 10
    val y = if (type == 0) softclip(y0 + 2400) - softclip(2400) else driveShape(type, y0, 0)
    return mulq15(y.coerceIn(-40000, 40000), 30000 - d * 120)
}
private fun driveWave(type: Int, d: Int, tone: Int): IntArray {
    val hm = if (type == 3) (1 shl (d shr 5)) - 1 else 0
    var lp1 = 0; var lp2 = 0; var h = 0; val out = IntArray(88)
    val k = ((if (type == 3) 32700 - d * 40 else 32000 - d * 95) + tone * 150).coerceIn(2000, 32700)
    for (i in 0 until 176) {
        val ph = ((i.toLong() * 48806447L) and 0xFFFFFFFFL) / 4294967296.0
        val x = (32767 * sin(ph * 2 * Math.PI)).toInt() * 3 / 4
        if (i and hm == 0) h = driveAt(type, d, x)
        lp1 += mulq15(h - lp1, k); lp2 += mulq15(lp1 - lp2, k)
        if (i >= 88) out[i - 88] = if (d != 0) lp2 else x
    }
    return out
}

private fun drawDrive(s: Sp, g: PageGraph, c: Color) {
    val d = g.values.getOrElse(0) { 0 }; val type = g.values.getOrElse(1) { 0 }.coerceIn(0, 4); val tone = g.values.getOrElse(2) { 0 }
    val ys = (0..116).map { i -> 66f - driveAt(type, d, (i - 58) * 32768 / 58) * 58f / 32768f }
    val curve = ys.mapIndexed { i, y -> (12f + i) to y }
    s.d.drawPath(s.path(curve).apply { lineTo(s.x(128f), s.y(124f)); lineTo(s.x(12f), s.y(124f)); close() }, c.copy(alpha = 0.14f))
    s.rect(line, 12f, 66f, 116f, 1f); s.rect(line, 70f, 8f, 1f, 117f)
    s.d.drawPath(s.path(listOf(12f to 124f, 128f to 8f)), dim, style = Stroke(s.run { 1f.px() }, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f))))
    s.stroke(c, curve)
    // TODO: the drive's output wave (iPad: driveWave, ported above) is not drawn: board 59 shows the curve and the type's name
}

private fun drawFx(s: Sp, g: PageGraph, c: Color) {
    for (i in 0 until 4) {
        val v = g.values.getOrElse(i) { 0 }
        val x = 30f + i * 60f - 2f; val h = v * 76f / 127f
        s.rect(Tok.lifted, x, 6f, 4f, 82f, 2f)
        if (h > 3) s.rect(c, x, 88f - h, 4f, h, 2f)
        s.rect(c, x - 7f, 85f - h, 18f, 6f, 3f)
    }
    listOf("DIST", "CHORUS", "DELAY", "REVERB").forEachIndexed { i, n -> s.text(n, 30f + i * 60f - 14f, 112f, mid, 10f) }
}

private val BLACK = setOf(1, 3, 6, 8, 10)
private val NAMES = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")

private fun drawScale(s: Sp, g: PageGraph, c: Color) {
    val inScale = g.notes.map { (it + g.root) % 12 }.toSet()
    val whites = listOf(0, 2, 4, 5, 7, 9, 11)
    val kw = 216f / 7f
    val top = 8f; val hh = 118f
    whites.forEachIndexed { i, n ->
        val on = n in inScale
        s.rect(if (on) c.copy(alpha = 0.85f) else Tok.lifted, 12f + i * kw + 1f, top, kw - 2f, hh, 4f)
        s.text(NAMES[n] + if (n == g.root) " ●" else "", 12f + i * kw + kw / 2 - 6f, top + hh - 5f, if (on) Tok.onColour else mid, 11f)
    }
    val blacks = mapOf(1 to 0, 3 to 1, 6 to 3, 8 to 4, 10 to 5)
    blacks.forEach { (n, left) ->
        val on = n in inScale
        val x = 12f + (left + 1) * kw - kw * 0.3f
        s.rect(Tok.page, x - 1.5f, top, kw * 0.6f + 3f, hh * 0.58f + 3f, 4f)
        s.rect(if (on) c else Tok.well, x, top, kw * 0.6f, hh * 0.58f, 3f)
        if (n == g.root) s.text("●", x + kw * 0.3f - 3f, top + hh * 0.58f - 6f, Tok.onColour, 10f)
    }
}

private val ARP_MODES = 15
private fun drawArp(s: Sp, g: PageGraph, c: Color) {
    val v = g.values
    val m = v.getOrElse(0) { 0 }; val oct = max(1, v.getOrElse(2) { 1 })
    val gate = v.getOrElse(3) { 64 }; val swing = v.getOrElse(4) { 0 }; val chance = v.getOrElse(5) { 127 }
    val list = mutableListOf<Int>()
    for (o in 0 until oct) for (n in intArrayOf(60, 64, 67)) if (list.size < 64) list += min(127, n + 12 * o)
    if (m == 6) { list.clear(); list += 67 }
    if (m == 8) list += min(127, list[0] + 12 * oct)
    val len = list.size
    val pitch = min(18, 102 / len); val th = if (pitch >= 12) 10 else if (pitch > 3) pitch - 1 else 2
    val base = 115 - (102 - (len - 1) * pitch) / 2
    val gw = 2 + gate * 10 / 127; val sw = swing * 12 / 250
    for (i in 0 until len) {
        val y = (base - i * pitch).toFloat()
        var x = 30f; while (x <= 228f) { s.rect(line, x, y, 1f, 1f); x += 3f }
        if (pitch >= 12) s.text(NAMES[list[i] % 12], 12f, y + 4f, dim, 10f)
    }
    for (i in 0 until 16) {
        val k = i % (if (2 * len > 2) 2 * len - 2 else 1)
        val x = 30f + i * 124f / 10f + if (i and 1 == 1) sw else 0
        val hash = ((i.toLong() * 2654435761L) and 0xFFFFFFFFL)
        val r = when (m) {
            2 -> len - 1 - i % len
            3 -> if (k < len) k else 2 * len - 2 - k
            7 -> if (k < len) len - 1 - k else k - (len - 1)
            4, 13 -> ((hash shr 20).toInt()) % len
            9, 10 -> { var q = i % len; if (m == 10) q = len - 1 - q; if (q and 1 == 1) len - 1 - q / 2 else q / 2 }
            11 -> if (len < 2) 0 else if (k and 1 == 1) len - 1 else k / 2
            12 -> if (len < 2) 0 else if (k and 1 == 1) 1 + k / 2 else 0
            else -> i % len
        }
        val rows = if (m == 14) (0 until 3).map { min(len - 1, (i % oct) * 3 + it) } else listOf(r)
        val skip = ((hash shr 25) and 127).toInt() > chance
        for (row in rows) {
            val y = (base - row * pitch - th / 2).toFloat()
            val col = if (m == 0) dim else if (i % 4 == 0) Tok.text else c
            if (skip) s.d.drawRoundRect(mid, s.o(x, y), Size(s.x(gw.toFloat()), s.y(th.toFloat())), CornerRadius(s.run { 1.5f.px() }), style = Stroke(s.run { 1f.px() }))
            else s.rect(col, x, y, gw.toFloat(), th.toFloat(), 1.5f)
        }
    }
}

private fun shape(w: Int, f0: Double): Double {
    val f = f0 - kotlin.math.floor(f0)
    return when (w) { 1 -> if (f < 0.5) 1.0 else -1.0; 2 -> if (f < 0.5) -1 + 4 * f else 3 - 4 * f; 3 -> sin(f * 2 * Math.PI); 4 -> if (f < 0.25) 1.0 else -1.0; else -> -1 + 2 * f }
}

private fun drawAnalog(s: Sp, g: PageGraph, c: Color) {
    val v = g.values
    val wave = ((v.getOrElse(0) { 0 } % 5) + 5) % 5; val detune = v.getOrElse(1) { 0 }; val mix = v.getOrElse(2) { 0 }; val noise = v.getOrElse(3) { 0 }
    val cutoff = v.getOrElse(4) { 64 }; val reso = v.getOrElse(5) { 0 }
    val x0 = 12f; val ow = 104; val cyc = 52.0
    val k = 1 + detune / 1000.0
    if (mix > 0) s.stroke(mid, (0..ow).map { x -> (x0 + x) to (72f - shape(wave, x / cyc * k).toFloat() * 48f) }, 1f)
    // NOISE roughens the wave itself (up to ±10 units at 127), the same each frame. It used to scatter 2 × 2 specks,
    // which the graph's uneven scale stretched into stray dashes inside the saw (Scott's run, 2026-11-13).
    fun grain(x: Int): Float {
        val h = ((x + 1).toLong() * 2654435761L) and 0xFFFFFFFFL
        return ((h % 1000) / 1000f - 0.5f) * 20f * noise / 127f
    }
    if (mix < 127) s.stroke(c, (0..ow).map { x -> (x0 + x) to (72f - shape(wave, x / cyc).toFloat() * 48f + grain(x)) })
    g.caption?.let { s.text(it, x0, 16f, mid) }
    s.rect(line, 122f, 8f, 1f, 116f)
    val f0 = 128f; val fw = 100
    val fc = cutoff / 127.0; val xc = f0 + (fc * fw).toFloat()
    s.rect(dim, xc, 8f, 1f, 114f)
    s.rect(c, xc - 3f, 8f, 6f, 10f, 2f)   // the cutoff's handle; RES's sits on the peak below
    val peak = 0.62 + 0.38 * reso / 127
    val pts = (0..fw).map { x ->
        val f = x.toDouble() / fw; val d = fc - f
        val l = max(0.0, if (d >= 0) 0.62 + (if (d < 0.06) (0.38 * reso / 127) * (0.0036 - d * d) / 0.0036 else 0.0) else peak + d * 3.2)
        (f0 + x) to (120f - (l * 104).toFloat())
    }
    s.d.drawPath(s.path(pts).apply { lineTo(s.x(f0 + fw), s.y(120f)); lineTo(s.x(f0), s.y(120f)); close() }, c.copy(alpha = 0.14f))
    s.stroke(c, pts)
    s.rect(c, xc - 3f, 120f - (peak * 104).toFloat() - 5f, 6f, 10f, 2f)
    g.side?.let { s.text(it, 228f, 16f, mid, right = true) }
    s.text("LOW", f0, 135f, dim); s.text("HIGH", 228f, 135f, dim, right = true)
}


// ---- the FX family's other pages, ported from ios/FM1/PageGraphs.swift (Skiff's ui_pgraph.c): DELAY, REVERB, INSERT, SLICER, DUCK

/** DELAY (graph_delay): the echoes on a beat grid; the first as loud as MIX times the track's send, each after it down by FEEDBACK. */
private fun drawDelay(s: Sp, g: PageGraph, c: Color) {
    val v = List(4) { g.values.getOrElse(it) { 0 } }
    val sixths = intArrayOf(24, 12, 6, 3, 8, 4, 48, 96, 192, 384, 18, 9, 36)
    val tap = sixths[((v[0] % 13) + 13) % 13]; val win = max(tap * 4, 96); val unit = if (win > 96) 96 else 24
    val n = win / unit
    val w = min(max(tap * 208 / win - 3, 2), 13).toFloat()
    for (i in 0 until n) {
        val x = 14f + i * unit * 208 / win
        s.rect(dim, x, 123f, 2f, 3f)
        if (n <= 8 || i % 4 == 0) s.text("${i + 1}", x + 4f, 138f, mid, 10f)
    }
    var lvl = 1000
    for (i in 0 until 9) {
        if (lvl < 40) break
        val x = 14f + i * tap * 208 / win; val h = lvl / 10f
        if (x + w > 228f) break
        s.rect(if (i == 0) Tok.text else c.copy(alpha = 1f - (15 + 50 * (i - 1) / 6) / 100f), x, 120f - h, w, h, 2f)
        lvl = if (i > 0) lvl * v[1] * 230 / 32768 else v[3] * 1000 / 127 * g.send.coerceIn(0, 127) / 127
    }
    s.text("DRY", 14f, 18f, mid)
    g.caption?.let { s.text(it, 228f, 18f, mid, right = true) }
}

/** REVERB (graph_reverb): the early reflections in white, then the tail falling away (longer with SIZE, twice for HALL), its top dimmed by DAMP; all as loud as the send. */
private fun drawReverb(s: Sp, g: PageGraph, c: Color) {
    val v = List(3) { g.values.getOrElse(it) { 0 } }
    val amp = g.send.coerceIn(0, 127)
    // the type by its name when the page gives it (the FM-1's own word), else by its number (0 ROOM, 1 SPRING, 2 HALL)
    val type = g.caption?.uppercase() ?: listOf("ROOM", "SPRING", "HALL").getOrElse(v[0]) { "ROOM" }
    val hall = type == "HALL"
    val len = ((40 + v[1] * 144 / 127) * (if (hall) 2 else 1)).toFloat(); val k = 1f - 3f / len
    val dimTop = (20 + v[2] * 60 / 127) / 100f
    listOf(84, 60, 72, 46, 52).forEachIndexed { i, e -> val h = (e * amp / 127).toFloat(); s.rect(Tok.text, 12f + i * 6, 126f - h, 3f, h) }
    val tops = mutableListOf<Pair<Float, Float>>(); val mids = mutableListOf<Pair<Float, Float>>()
    var e = 1f
    for (x in 44..229) { val h = (84 * amp / 127) * e; tops += x.toFloat() to 126f - h; mids += x.toFloat() to 126f - h + h * dimTop; e *= k }
    val band = s.path(tops + mids.reversed(), close = true)
    val body = s.path(mids + listOf(229f to 126f, 44f to 126f), close = true)
    val x0 = s.x(44f); val x1 = s.x(228f)
    s.d.drawPath(band, androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(c.copy(alpha = 0.45f), c.copy(alpha = 0.15f)), x0, x1))
    s.d.drawPath(body, androidx.compose.ui.graphics.Brush.horizontalGradient(listOf(c, c.copy(alpha = 0.4f)), x0, x1))
    if (type == "SPRING") {
        s.text("SPRING", 12f, 19f, mid)
        s.stroke(mid, (64..228).map { x -> x.toFloat() to 13f + (sin((x - 64) * 13 / 256.0 * 2 * Math.PI) * 3).toFloat() }, 1f)   // the coil
    } else s.text(type, 12f, 19f, mid)
}

/** SLICER (graph_slicer): the sixteen steps of its pattern in fours: open steps full, closed ones down by DEPTH (GATE) or hatched (STUT); OFF is grey. */
private val SLICER_PATTERNS = intArrayOf(0x5555, 0xB6DB, 0x5249, 0xB777, 0x6D6D, 0x0F0F, 0x1111, 0x54A5, 0x5333, 0xA929, 0xAAFF, 0xD501, 0xAAAA, 0xAB6B, 0xBB5D, 0x7597)
private fun drawSlicer(s: Sp, g: PageGraph, c: Color) {
    val v = List(4) { g.values.getOrElse(it) { 0 } }
    val pat = SLICER_PATTERNS[((v[1] - 1) % 16 + 16) % 16]; val mode = v[0]
    val k = GH / 96f                                   // Skiff draws this one in a 96-high space
    val open = (70 - v[3] * 70 / 127).toFloat()
    val col = if (mode == 0) dim else c
    for (i in 0 until 16) {
        val x = (12 + i * 13 + (i / 4) * 4).toFloat()
        if ((pat shr i) and 1 == 1) s.rect(if (mode == 0) Tok.lifted else col, x, 8f * k, 9f, 72f * k, 2f)
        else if (mode == 2) { var y = 8f; while (y < 80f) { s.rect(col, x, y * k, 9f, 1f * k); y += 4f } }
        else { s.rect(Tok.lifted, x, 77f * k, 9f, 3f * k, 1f); if (open > 3) s.rect(Tok.lifted, x, (80f - open) * k, 9f, open * k, 2f) }
    }
}

/** DUCK (graph_duck): the track's level over a bar: full, down by DEPTH at each of its source's hits, back in a line over RELEASE. No source: the empty box. */
private fun drawDuck(s: Sp, g: PageGraph, c: Color) {
    val k = GH / 96f
    s.rect(Tok.lifted, 8f, 10f * k, 224f, 62f * k)
    val hits = g.notes.map { it / 1000f }.sorted()
    if (hits.isEmpty()) return
    val depth = g.values.getOrElse(0) { 0 }; val release = g.values.getOrElse(1) { 0 } / 1000f
    for (h in hits) s.rect(mid, 8f + h * 224f, 78f * k, 3f, 8f * k)
    val pts = (0..224).map { x ->
        val tau = x / 224f
        val last = hits.lastOrNull { it <= tau } ?: hits.last()
        val dt = if (last <= tau) tau - last else tau + 1 - last
        val dip = if (release > 0 && dt < release) 62f * depth / 127f * (release - dt) / release else 0f
        (8f + x) to (10f + dip) * k
    }
    s.d.drawPath(s.path(pts + listOf(232f to 72f * k, 8f to 72f * k), close = true), c)
}

/** INSERT (graph_insert, fx.c ins_*): TYPE's names, 0…9. */
private val INSERT_NAMES = listOf("OFF", "SOFT", "HARD", "FOLD", "FUZZ", "CRUSH", "PHASR", "FLANG", "CHOR", "FILTR")
private val INSERT_SHAPE = mapOf(1 to 0, 2 to 1, 3 to 2, 4 to 4, 5 to 3)       // IT_* to the drive's shapes (SOFT HARD FOLD CRUSH FUZZ)
private fun insSine(ph: Long) = (32767 * sin((ph and 0xFFFFFFFFL) / 4294967296.0 * 2 * Math.PI)).toInt()
private fun insTri(q: Long): Int { val t = ((q and 0xFFFFFFFFL) shr 16).toInt(); return if (t < 32768) t shl 1 else (65535 - t) shl 1 }
private fun insLevel(v: Int) = if (v <= 0) 0 else (4096 * 10.0.pow((v - 112) / 40.0)).roundToInt()
private fun insLpk(cut: Int): Int {
    val f = 30 * (16000.0 / 30).pow(cut.coerceIn(0, 127) / 127.0)
    val gq = (4096 * kotlin.math.tan(Math.PI * min(f, 0.45 * 44100) / 44100)).toInt()
    return (gq shl 16) / (4096 + gq)
}
private fun insMix(m: Int) = if (m >= 127) 32768 else if (m <= 0) 0 else m * 258
/** pg_ins_curve: the drives' transfer blended by MIX; the swept ones' sweep over a cycle. */
private fun insAt(v: List<Int>, x: Int): Int {
    val ty = v[0]; val a = v[1]; val b = v[2]; val cc = v[3]; val mix = insMix(v[4])
    if (ty <= 0 || ty >= 9 || mix <= 0) return x
    if (ty >= 6) {
        val ph = (x + 32768).toLong() shl 16
        var w = if (ty == 8) insSine(ph) else insTri(ph) - 32768
        if (ty == 7) w = (((w + 32768).toLong() * (w + 32768).toLong()) shr 16).toInt() - 32768
        return w * b / 127
    }
    val y = if (ty == 5) driveShape(3, x, 15 - (a.coerceIn(0, 127) shr 3))
        else ((driveShape(INSERT_SHAPE[ty] ?: 0, ((x shr 3) * (4096 + a * a * 3)) shr 9, 0).toLong() * insLevel(cc)) shr 12).toInt()
    return x + (((y.coerceIn(-40000, 40000) - x).toLong() * mix) shr 15).toInt()
}
private fun insWave(v: List<Int>): IntArray {
    val ty = v[0]; val b = v[2]; val cc = v[3]
    val hold = intArrayOf(64, 48, 40, 32, 24, 20, 16, 12, 10, 8, 6, 5, 4, 3, 2, 1)[b.coerceIn(0, 127) shr 3]
    val kq = insLpk(if (ty == 5) cc else b)
    var lp1 = 0; var lp2 = 0; var h = 0; val out = IntArray(88)
    for (i in 0 until 176) {
        val x = insSine(i.toLong() * 48806447L) * 3 / 4
        val y = if (ty >= 6) insAt(v, (i % 44) * 65536 / 44 - 32768) else {
            if (ty != 5 || i % hold == 0) h = insAt(v, x)
            lp1 += (((h - lp1).toLong() * kq) shr 16).toInt() * 2
            lp2 += (((lp1 - lp2).toLong() * kq) shr 16).toInt() * 2
            if (ty != 0) lp2 else x
        }
        if (i >= 88) out[i - 88] = y
    }
    return out
}
/** The filter's level (ui_pgraph.c flt_level): LP flat with a peak at the cutoff as high as RES, HP its mirror, BP a peak falling both ways; SHAPE blends them. */
private fun fltOff(w: Int): Int { val t = intArrayOf(-1000, -482, -321, -227, -161, -109, -67, -31, 0); val i = w shr 3; return if (i >= 8) 0 else t[i] + (t[i + 1] - t[i]) * (w and 7) / 8 }
private fun fltLevel(d: Int, res: Int, shape: Int): Int {
    val ad = abs(d); val bump = if (ad < 60) (380 * res / 127) * (3600 - ad * ad) / 3600 else 0
    val peak = 620 + 380 * res / 127; val lp = if (d >= 0) 620 + bump else peak + d * 32 / 10
    val hp = if (d <= 0) 620 + bump else peak - d * 32 / 10; val bp = 620 - ad * (16 + res / 8) / 10
    val (a, b) = if (shape <= 64) (lp + fltOff(64 - shape)) to (bp + fltOff(shape)) else (bp + fltOff((127 - shape) * 64 / 63)) to (hp + fltOff((shape - 64) * 64 / 63))
    return max(0, max(a, b))
}
private fun drawInsert(s: Sp, g: PageGraph, c: Color) {
    val v = List(5) { g.values.getOrElse(it) { if (it == 4) 127 else 0 } }
    if (v[0] == 9) {
        // FILTR: the filter across the panel, low pass into band pass into high pass by SHAPE (knob 4), LP BP HP with its place marked
        val cut = v[1].coerceIn(0, 127); val res = v[2].coerceIn(0, 127); val sh = v[3].coerceIn(0, 127)
        val fc = cut * 1000 / 127; val xc = 12f + fc * 216 / 1000
        s.rect(dim, xc, 8f, 1f, 114f)
        val pts = (0..216).map { x -> (12f + x) to (120f - fltLevel(fc - x * 1000 / 216, res, sh) * 104 / 1000f) }
        s.d.drawPath(s.path(pts + listOf(228f to 120f, 12f to 120f), close = true), c.copy(alpha = 0.25f))
        s.stroke(c, pts, 3f)
        s.text("LP", 12f, 20f, if (sh <= 32) Tok.text else dim); s.text("BP", 46f, 20f, if (sh in 33..95) Tok.text else dim); s.text("HP", 80f, 20f, if (sh >= 96) Tok.text else dim)
        s.rect(line, 12f, 24f, 81f, 1f)
        s.d.drawCircle(Tok.text, s.run { 4f.px() }, s.o(12f + sh * 80 / 127 + 2.5f, 24.5f))
        g.caption?.let { s.text(it, if (xc + 5 < 180f) xc + 5f else xc - 4f, 116f, Tok.text, right = xc + 5 >= 180f) }
        return
    }
    // the transfer curve at the left (the dashed line is "unchanged"), a cycle of the wave it makes at the right
    val ys = (0..116).map { i -> 66f - insAt(v, (i - 58) * 32768 / 58) * 58f / 32768f }
    val pts = ys.mapIndexed { i, y -> (12f + i) to y }
    s.d.drawPath(s.path(pts + listOf(128f to 124f, 12f to 124f), close = true), c.copy(alpha = 0.14f))
    s.rect(line, 12f, 66f, 116f, 1f); s.rect(line, 70f, 8f, 1f, 117f); s.rect(line, 140f, 88f, 87f, 1f)
    s.d.drawPath(s.path(listOf(12f to 124f, 128f to 8f)), dim, style = Stroke(s.run { 1f.px() }, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f))))
    s.stroke(c, pts)
    val wp = insWave(v).mapIndexed { i, y -> (140f + i) to (88f - y * 32f / 32768f) }
    s.d.drawPath(s.path(wp + listOf(227f to 88f, 140f to 88f), close = true), c.copy(alpha = 0.14f))
    s.stroke(c, wp, 2f)
    s.text(INSERT_NAMES.getOrNull(v[0]) ?: "OFF", 140f, 28f, if (v[0] != 0 && v[4] != 0) c else dim, 13f)
}

/**
 * The picture for a page: the core's ([PageState.graph]) when it sends one; else, for the FX family's pages it doesn't cover yet (DELAY,
 * REVERB, INSERT, SLICER, DUCK), one made from the page's own four knobs. What the page area doesn't carry is assumed and said in the
 * comments: the delay bus's MIX (full), INSERT's MIX on the PRESETS encoder (full), and DUCK's source hits (none known: its box only).
 */
fun pictureOf(page: com.scottgerstl.lupe.core.PageState): PageGraph {
    if (page.graph.kind != GraphKind.None) return page.graph
    if (page.family != "FX") return page.graph
    val title = page.pages.firstOrNull { it.index == page.page }?.title ?: page.title
    val v = page.controls.map { it?.raw ?: 0 }
    return when (title) {
        "DELAY" -> PageGraph(GraphKind.FxDelay, values = listOf(v[1], v[2], v[3], 127), send = v[0], caption = page.controls.getOrNull(1)?.value)   // SEND (or DELAY), TIME, FEEDBACK, COLOR
        "REVERB" -> PageGraph(GraphKind.FxReverb, values = listOf(v[1], v[2], v[3]), send = v[0], caption = page.controls.getOrNull(1)?.value)                                                // SEND (or REVERB), TYPE, SIZE, DAMP
        "INSERT" -> PageGraph(GraphKind.Insert, values = listOf(v[0], v[1], v[2], v[3], 127), caption = page.controls.getOrNull(1)?.value)       // TYPE, A, B, C
        "SLICER" -> PageGraph(GraphKind.Slicer, values = v)
        "DUCK" -> PageGraph(GraphKind.Duck, values = listOf(v[1], 250))                                                                          // BY, DEPTH, RELEASE: no hits known
        else -> page.graph
    }
}

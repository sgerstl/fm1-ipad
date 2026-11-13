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

// The page graphs, ported from ios/FM1/PageGraphs.swift (which mirrors Skiff's ui_graph.c / ui_pgraph.c): Skiff's own
// 240 × 140 drawing space stretched to the panel, in the track's colour. Ported: ENV, LFO (a sweep, not the live clock),
// DRIVE, FX sends, SCALE (a keyboard octave, as board 61), ARP, EDIT 1's ANALOG picture; MOD's route tiles and the picker
// tiles; the dense pages' card. TODO (not ported yet; those pages show the panel without a graph): CHORD, FOLLOW,
// DELAY, REVERB, CHORUS (Skiff 2.5 FX pages), INSERT, INSERT 2, SLICER, DUCK, VOICE, the scope for engines other than
// ANALOG, and LFO's live clock (restart and BPM) with FADE.

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

/** The graph panel's content for [g]. [hot] is the control the FM-1's knob is turning (0…3), or -1. */
@Composable
fun GraphContent(g: PageGraph, colour: Color, hot: Int, onSet: (slot: Int, value: Int) -> Unit, onPickRoute: (Int) -> Unit, onPickTile: (Int) -> Unit, modifier: Modifier = Modifier) {
    when (g.kind) {
        GraphKind.None -> Unit
        GraphKind.Mod -> ModRoutes(g, colour, onPickRoute, modifier)
        GraphKind.Tiles -> PickTiles(g, colour, onPickTile, modifier)
        GraphKind.Card -> DenseCard(g, modifier)
        GraphKind.Env -> EnvGraph(g, colour, hot, onSet, modifier)
        else -> CanvasGraph(g, colour, hot, modifier)
    }
}

private fun describe(g: PageGraph): String = when (g.kind) {
    GraphKind.Env -> "Envelope shape. " + listOf("attack", "decay", "sustain", "release").mapIndexed { i, n -> "$n ${g.values.getOrElse(i) { 0 }}" }.joinToString(", ")
    GraphKind.Lfo -> "LFO wave. ${g.caption ?: ""}"
    GraphKind.Drive -> "Drive curve. ${g.caption ?: ""} ${g.side ?: ""}"
    GraphKind.Fx -> "FX sends: " + listOf("drive", "chorus", "delay", "reverb").mapIndexed { i, n -> "$n ${g.values.getOrElse(i) { 0 }}" }.joinToString(", ")
    GraphKind.Scale -> "Scale keys. ${g.side ?: ""}"
    GraphKind.Arp -> "Arpeggio pattern. ${g.side ?: ""}"
    GraphKind.Analog -> "Oscillator and filter. ${g.caption ?: ""}, ${g.side ?: ""}"
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
private fun EnvGraph(g: PageGraph, colour: Color, hot: Int, onSet: (Int, Int) -> Unit, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    var grabbed by remember { androidx.compose.runtime.mutableIntStateOf(-1) }
    val geo = EnvGeo(g.values)
    Canvas(
        modifier
            .semantics { contentDescription = describe(g) }
            .pointerInput(g.values) {
                // a handle is a 44 dp target of its own; only a drag that starts on it moves it
                detectDragGestures(
                    onDragStart = { p ->
                        val k = EnvGeo(g.values)
                        val hs = listOf(k.x1 to k.top, k.x1 + k.d to k.y(k.sus), k.x3 to k.y(k.sus))
                        val best = hs.indices.minByOrNull { i -> val dx = hs[i].first / GW * size.width - p.x; val dy = hs[i].second / GH * size.height - p.y; dx * dx + dy * dy }!!
                        val dx = hs[best].first / GW * size.width - p.x; val dy = hs[best].second / GH * size.height - p.y
                        grabbed = if (dx * dx + dy * dy <= (22.dp.toPx()).let { it * it }) best else -1
                    },
                    onDragEnd = { grabbed = -1 }, onDragCancel = { grabbed = -1 },
                ) { change, _ ->
                    if (grabbed < 0) return@detectDragGestures
                    change.consume()
                    val k = EnvGeo(g.values)
                    val x = change.position.x / size.width * GW; val yy = change.position.y / size.height * GH
                    val sus = ((k.bot - yy) / (k.bot - k.top) * 127).roundToInt().coerceIn(0, 127)
                    fun send(slot: Int, v: Int) { val n = v.coerceIn(0, 127); if (g.values.getOrElse(slot) { -1 } != n) onSet(slot, n) }
                    when (grabbed) {
                        0 -> send(0, ((x - 16f) * 127 / 50).roundToInt())
                        1 -> { send(1, ((x - k.x1 - 6f) * 127 / 50).roundToInt()); send(2, sus) }
                        2 -> { send(3, ((226f - x - 6f) * 127 / 60).roundToInt()); send(2, sus) }
                    }
                }
            },
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
        seg(atk, hot == 0 || grabbed == 0); seg(dec, hot == 1 || grabbed == 1); seg(hold, hot == 2); seg(rel, hot == 3 || grabbed == 2)
        val handles = listOf(geo.x1 to geo.top, geo.x1 + geo.d to geo.y(geo.sus), geo.x3 to geo.y(geo.sus))
        handles.forEachIndexed { n, (hx, hy) ->
            val on = grabbed == n || hot == n || (n > 0 && hot == n + 1)
            s.rect(Tok.well, hx - 7f, hy - 7f * GH / GW * 1.7f, 14f, 14f * GH / GW * 1.7f, 3f)
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
    if (mix < 127) s.stroke(c, (0..ow).map { x -> (x0 + x) to (72f - shape(wave, x / cyc).toFloat() * 48f) })
    for (i in 0 until noise / 3) {
        val h = (((i + 1).toLong() * 2654435761L) and 0xFFFFFFFFL)
        s.rect(mid, x0 + (h % ow).toFloat(), 24f + ((h shr 16) % 96).toFloat(), 2f, 2f)
    }
    g.caption?.let { s.text(it, x0, 16f, mid) }
    s.rect(line, 122f, 8f, 1f, 116f)
    val f0 = 128f; val fw = 100
    val fc = cutoff / 127.0; val xc = f0 + (fc * fw).toFloat()
    s.rect(dim, xc, 8f, 1f, 114f)
    val peak = 0.62 + 0.38 * reso / 127
    val pts = (0..fw).map { x ->
        val f = x.toDouble() / fw; val d = fc - f
        val l = max(0.0, if (d >= 0) 0.62 + (if (d < 0.06) (0.38 * reso / 127) * (0.0036 - d * d) / 0.0036 else 0.0) else peak + d * 3.2)
        (f0 + x) to (120f - (l * 104).toFloat())
    }
    s.d.drawPath(s.path(pts).apply { lineTo(s.x(f0 + fw), s.y(120f)); lineTo(s.x(f0), s.y(120f)); close() }, c.copy(alpha = 0.14f))
    s.stroke(c, pts)
    g.side?.let { s.text(it, 228f, 16f, mid, right = true) }
    s.text("LOW", f0, 135f, dim); s.text("HIGH", 228f, 135f, dim, right = true)
}

// ---- MOD's eleven routes, the pickers' tiles, the dense pages' card

@Composable
private fun ModRoutes(g: PageGraph, colour: Color, onPick: (Int) -> Unit, modifier: Modifier) {
    val groups = listOf("LFO" to "LFO →", "ENV" to "ENV →", "SLOTS" to "SLOTS")
    Column(modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        groups.forEach { (key, head) ->
            val rows = g.routes.withIndex().filter { it.value.group == key }
            Row(Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                BasicText(head, Modifier.size(width = 40.dp, height = 16.dp), style = LupeType.number.copy(fontSize = 11.sp, color = Tok.text2Raised))
                for (slot in 0 until 4) {
                    val r = rows.getOrNull(slot)
                    if (r == null) { Box(Modifier.weight(1f)); continue }
                    RouteTile(r.value.label, r.value.amount, r.value.empty, r.index == g.picked, colour, "${head.removeSuffix(" →")} to ${r.value.label}", Modifier.weight(1f).fillMaxSize()) { onPick(r.index) }
                }
            }
        }
    }
}

@Composable
private fun RouteTile(label: String, amount: Int, empty: Boolean, picked: Boolean, colour: Color, desc: String, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(8.dp))
            .background(if (picked) colour.copy(alpha = 0.35f) else Tok.control)
            .then(if (picked) Modifier.drawWithOutline() else Modifier)
            .semantics(mergeDescendants = true) { contentDescription = "$desc, amount $amount" + if (picked) ", picked" else "" }
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick),
    ) {
        BasicText(label, Modifier.align(Alignment.TopStart).padding(start = 8.dp, top = 6.dp), style = LupeType.label.copy(color = if (empty) Tok.text2 else Tok.text), maxLines = 1)
        if (!empty && amount > 0) Box(Modifier.align(Alignment.BottomStart).padding(start = 8.dp, bottom = 6.dp).height(3.dp).fillMaxWidthFraction(amount / 127f * 0.7f).background(colour, RoundedCornerShape(2.dp)))
    }
}

private fun Modifier.fillMaxWidthFraction(f: Float) = this.then(Modifier.fillMaxWidth(f.coerceIn(0.05f, 1f)))
private fun Modifier.drawWithOutline(): Modifier = this.then(Modifier.drawWithContent {
    drawContent()
    drawRoundRect(Tok.text, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(8.dp.toPx()), style = Stroke(2.dp.toPx()))
})

@Composable
private fun PickTiles(g: PageGraph, colour: Color, onPick: (Int) -> Unit, modifier: Modifier) {
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        g.tiles.withIndex().chunked(4).forEach { row ->
            Row(Modifier.fillMaxWidth().height(48.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { (i, t) ->
                    val on = i == g.picked
                    Box(
                        Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(8.dp)).background(if (on) colour else Tok.control)
                            .semantics(mergeDescendants = true) { contentDescription = t.label + if (on) ", picked" else "" }
                            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { onPick(i) },
                        contentAlignment = Alignment.Center,
                    ) { BasicText(t.label, style = LupeType.number.copy(fontSize = 16.sp, color = if (on) Tok.onColour else Tok.text), maxLines = 1) }
                }
                repeat(4 - row.size) { Box(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun DenseCard(g: PageGraph, modifier: Modifier) {
    Column(modifier.fillMaxSize().clip(RoundedCornerShape(8.dp)).background(Tok.well).padding(12.dp), verticalArrangement = Arrangement.Top) {
        BasicText(g.title ?: "", style = LupeType.number.copy(fontSize = 22.sp))
        BasicText("The FM-1's cursor is here. This page is edited on the FM-1 for now; its phone picture comes after v1.", Modifier.padding(top = 4.dp), style = LupeType.small)
    }
}

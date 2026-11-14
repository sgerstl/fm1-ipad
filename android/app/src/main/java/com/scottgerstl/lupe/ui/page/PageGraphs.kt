package com.scottgerstl.lupe.ui.page

import android.os.SystemClock
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.withFrameMillis
import com.scottgerstl.lupe.core.ClockDefaults
import com.scottgerstl.lupe.core.ClockState
import com.scottgerstl.lupe.core.LupeCore
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
// under the page's four dials. Ported: ENV, LFO (live, on the clock area), DRIVE, FX sends, SCALE, ARP, EDIT 1's ANALOG picture, VOICE.

/** The core the pictures read the clock and the tempo from (the live LFO); null in previews and tests: the LFO then runs from when it opened. */
val LocalPictureCore = staticCompositionLocalOf<LupeCore?> { null }

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
    /** A square-cornered bar on whole device pixels, so neighbours meet with no seam (the FM-1's finish: no rounded ends, no soft edges). */
    fun bar(c: Color, x: Float, y: Float, w: Float, h: Float) {
        if (w <= 0f || h <= 0f) return
        val l = kotlin.math.floor(x(x)); val t = kotlin.math.floor(y(y)); val r = kotlin.math.ceil(x(x + w)); val b = kotlin.math.ceil(y(y + h))
        d.drawRect(c, Offset(l, t), Size(r - l, b - t))
    }
    fun stroke(c: Color, pts: List<Pair<Float, Float>>, width: Float = 2.5f) =
        d.drawPath(path(pts), c, style = Stroke(width.px(), cap = StrokeCap.Round, join = StrokeJoin.Round))
    fun text(s: String, x: Float, base: Float, c: Color, size: Float = 11f, right: Boolean = false, centre: Boolean = false, strong: Boolean = false) {
        val r = tm.measure(s, LupeType.small.copy(fontSize = size.sp, color = c, fontWeight = if (strong) androidx.compose.ui.text.font.FontWeight.SemiBold else LupeType.small.fontWeight))
        val ox = x(x) - if (right) r.size.width.toFloat() else if (centre) r.size.width / 2f else 0f
        d.drawText(r, topLeft = Offset(ox, y(base) - r.size.height))
    }
}

/** True when the page has a picture to draw. */
fun hasPicture(g: PageGraph): Boolean = when (g.kind) {
    GraphKind.Env, GraphKind.Lfo, GraphKind.Drive, GraphKind.Fx, GraphKind.Scale, GraphKind.Arp, GraphKind.Analog,
    GraphKind.FxDelay, GraphKind.FxReverb, GraphKind.Insert, GraphKind.Slicer, GraphKind.Duck, GraphKind.Delay, GraphKind.Reverb, GraphKind.Chorus, GraphKind.Global, GraphKind.Voice, GraphKind.Chord, GraphKind.Follow -> true
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
        GraphKind.Lfo -> LfoGraph(g, colour, modifier)
        GraphKind.Drive, GraphKind.Fx, GraphKind.Scale, GraphKind.Arp, GraphKind.Analog, GraphKind.Voice, GraphKind.Chord, GraphKind.Follow,
        GraphKind.FxDelay, GraphKind.FxReverb, GraphKind.Insert, GraphKind.Slicer, GraphKind.Duck, GraphKind.Delay, GraphKind.Reverb, GraphKind.Chorus, GraphKind.Global -> CanvasGraph(g, colour, hot, modifier)
        else -> Unit
    }
}

private fun describe(g: PageGraph): String = when (g.kind) {
    GraphKind.Env -> "Envelope shape. " + listOf("attack", "decay", "sustain", "release").mapIndexed { i, n -> "$n ${g.values.getOrElse(i) { 0 }}" }.joinToString(", ")
    GraphKind.Lfo -> "LFO wave"
    GraphKind.Chord -> chordSpoken(g)
    GraphKind.Follow -> listOfNotNull(g.title, g.caption).joinToString(", ").lowercase().replaceFirstChar { it.uppercase() }
    GraphKind.Voice -> VOICE_SAYS.getOrElse(g.values.getOrElse(0) { 0 } and 3) { "" }.lowercase().replaceFirstChar { it.uppercase() } + ". Glide ${if (g.values.getOrElse(1) { 0 } == 0) "off" else g.caption ?: "on"}"
    GraphKind.Drive -> "Drive curve. ${g.caption ?: ""} ${g.side ?: ""}"
    GraphKind.Fx -> "FX sends: " + listOf("drive", "chorus", "delay", "reverb").mapIndexed { i, n -> "$n ${g.values.getOrElse(i) { 0 }}" }.joinToString(", ")
    GraphKind.Scale -> "Scale keys. ${g.side ?: ""}"
    GraphKind.Arp -> "Arpeggio pattern. ${g.side ?: ""}"
    GraphKind.Fm6Op -> "Operator envelopes and operator tiles"
    GraphKind.Fm6All -> "FM algorithm chart"
    GraphKind.Sound -> "DRUM-X sound sheet"
    GraphKind.Analog -> "Oscillator and filter. ${g.caption ?: ""}, ${g.side ?: ""}"
    GraphKind.Chorus -> when (g.values.getOrElse(2) { 0 }) { 1 -> "Flanger: the dry and its copy, a comb, swept"; 2 -> "Phaser: four stages, two notches, swept"; else -> "Chorus: the dry and its drifting copy" }
    GraphKind.Global -> swingText(g.values.getOrElse(1) { 0 }).lowercase().replaceFirstChar { it.uppercase() } + " over a bar of sixteenths"
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
    Canvas(modifier.clearAndSetSemantics { contentDescription = describe(g) }) {
        val s = Sp(this, tm)
        when (g.kind) {
            GraphKind.Voice -> drawVoice(s, g, colour)
            GraphKind.Chord -> drawChord(s, g, colour)
            GraphKind.Follow -> drawTwoLines(s, g.title, g.caption, g.follow?.takeIf { !it.kit }?.let { trackColour(it.track + 1) } ?: Tok.text)
            GraphKind.Drive -> drawDrive(s, g, colour)
            GraphKind.Fx -> drawFx(s, g, colour)
            GraphKind.Scale -> drawScale(s, g, colour)
            GraphKind.Arp -> drawArp(s, g, colour)
            GraphKind.Analog -> drawAnalog(s, g, colour)
            // the track's own send pages keep its colour; GLO's shared pages are the global greys and white (decision 34)
            GraphKind.FxDelay -> drawDelay(s, g, colour)
            GraphKind.FxReverb -> drawReverb(s, g, colour)
            GraphKind.Delay -> drawDelay(s, g, GLOBAL_INK)
            GraphKind.Reverb -> drawReverb(s, g, GLOBAL_INK)
            GraphKind.Chorus -> drawChorus(s, g, GLOBAL_INK)
            GraphKind.Global -> drawGlobal(s, g, GLOBAL_INK)
            GraphKind.Insert -> drawInsert(s, g, colour)
            GraphKind.Slicer -> drawSlicer(s, g, colour)
            GraphKind.Duck -> drawDuck(s, g, colour)
            else -> Unit
        }
    }
}

/** One shared "when an LFO picture first showed": the stand-in restart while there is no clock, so every LFO picture shows the same moment. */
private val lfoOpened: Long by lazy { SystemClock.uptimeMillis() }

/**
 * LFO, LFO 2: the wave as it runs (the iPad's LiveLFOGraph, Skiff's graph_lfo): its two seconds from the restart, then the last two
 * seconds scrolling, at its real rate (SYNC's at the clock's tempo), FADE ramping in, UNI above the line, a dot where it is now.
 * With Reduce Motion it is the still two seconds from the restart.
 */
@Composable
private fun LfoGraph(g: PageGraph, colour: Color, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val reduce = LocalReduceMotion.current
    val core = LocalPictureCore.current
    val clock by (core?.clock ?: ClockDefaults.clock).collectAsState()
    val tempo = core?.top?.collectAsState()?.value?.tempo ?: 120.0
    val lfo = SkiffLfo.of(g.values)
    val opened = lfoOpened
    var frame by remember { mutableLongStateOf(SystemClock.uptimeMillis()) }
    if (!reduce) LaunchedEffect(Unit) { while (true) withFrameMillis { frame = SystemClock.uptimeMillis() } }
    val bpmNow = if (clock.running && clock.ticksPerSecond > 0) clock.ticksPerSecond * 60 / 24 else tempo
    val caption = if (lfo.sync > 0 || g.caption == null) lfo.caption(bpmNow) else g.caption
    val spoken = "LFO wave${if (reduce) "" else ", running"}. ${SkiffLfo.WAVE_NAMES.getOrElse(lfo.wave) { "wave" }}, $caption" +
        (if (lfo.polarity != 0) ", above zero only" else "") + (if (lfo.fade > 0) ", fades in" else "")
    Canvas(modifier.clearAndSetSemantics { contentDescription = spoken }) {
        val s = Sp(this, tm)
        val n = if (reduce) LfoNow(lfo.startPhase, 0.0, bpmNow) else lfoNow(lfo, clock, tempo, opened, frame)
        val (values, now) = lfo.view(n.cycles, n.since, n.bpm, 217)
        val cy = GH / 2; val a = 38f * GH / 100f
        s.rect(Tok.lifted, 12f, cy, 216f, 1f)
        val pts = values.mapIndexed { x, v -> (12f + x) to (cy - v.toFloat() * a) }
        s.stroke(colour, pts)
        val k = (now * 216).roundToInt().coerceIn(0, 216)
        val dot = s.o(pts[k].first, pts[k].second); val half = s.run { 5f.px() }
        drawRoundRect(Tok.text, Offset(dot.x - half, dot.y - half), Size(half * 2, half * 2), CornerRadius(s.run { 2f.px() }))
        s.text(caption, 228f, 16f, mid, right = true)
    }
}

// ---- VOICE (ui_pgraph.c graph_voice, the iPad's VoiceDrawing): what the mode does in words, and the glide as a ramp from the old note to the new

// UNI stacks all the voices on Skiff 2.2 and 8 of 16 on 2.5; the phone isn't told which, so it doesn't count them
private val VOICE_SAYS = listOf("POLY: A VOICE A NOTE", "MONO: ONE VOICE, NEW ATTACK", "LEG: ONE VOICE, NO NEW ATTACK", "UNI: STACKED VOICES, ONE NOTE")

private fun drawVoice(s: Sp, g: PageGraph, c: Color) {
    val mode = g.values.getOrElse(0) { 0 } and 3; val gl = g.values.getOrElse(1) { 0 }.coerceIn(0, 127)
    val w = if (gl != 0) 6f + gl * 90 / 127 else 0f
    s.text(VOICE_SAYS[mode], 12f, 16f, mid)
    s.rect(mid, 12f, 92f, 88f, 11f, 2f)                                            // the note before
    s.stroke(c, listOf(100f to 97f, (100f + w) to 39f), 4f)                        // the glide between
    s.rect(c, 100f + w, 34f, 128f - w, 11f, 2f)                                    // the note after
    if (gl != 0) {
        s.rect(dim, 100f, 116f, 1f, 9f); s.rect(dim, 100f + w, 116f, 1f, 9f); s.rect(dim, 100f, 120f, w, 1f)
        g.caption?.let { s.text(it, 100f + w / 2, 135f, mid, centre = true) }
    }
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
    s.rect(line, 12f, 66f, 116f, 1f); s.rect(line, 70f, 8f, 1f, 117f); s.rect(line, 140f, 88f, 87f, 1f)
    s.d.drawPath(s.path(listOf(12f to 124f, 128f to 8f)), dim, style = Stroke(s.run { 1f.px() }, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f))))
    s.stroke(c, curve)
    // a cycle of the wave it makes, at the right, under the type's name (CRUSH says its bits and hold)
    val wp = driveWave(type, d, tone).mapIndexed { i, y -> (140f + i) to (88f - y * 32f / 32768f) }
    s.d.drawPath(s.path(wp + listOf(227f to 88f, 140f to 88f), close = true), c.copy(alpha = 0.14f))
    s.stroke(c, wp, 2f)
    s.text(listOf("SOFT", "HARD", "FOLD", "CRUSH", "FUZZ")[type], 140f, 28f, if (d != 0) c else dim, 13f)
    if (type == 3 && d != 0) s.text("${16 - d / 11} BITS, HOLD ${1 shl (d shr 5)}", 140f, 44f, mid)
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

// ---- SEL › CHORD and FOLLOW (ui_graph.c graph_chord, graph_strum, graph_follow; the iPad's ChordDrawing)

private val BLACK_KEY = booleanArrayOf(false, true, false, true, false, false, true, false, true, false, true, false)
private fun noteName(n: Int) = NAMES[((n % 12) + 12) % 12] + (n / 12 - 1)

/** What the picture says aloud: the chord and its notes, how it is strummed, or the two lines that say why there is none. */
internal fun chordSpoken(g: PageGraph): String {
    if (g.notes.isEmpty()) return listOfNotNull(g.title, g.caption).joinToString(", ").lowercase().replaceFirstChar { it.uppercase() }
    val notes = g.notes.joinToString(", ") { noteName(it).replace("#", " sharp ") }
    val ms = g.values.getOrNull(0) ?: return "${g.title ?: "Chord"}, $notes"
    val how = when (g.values.getOrElse(1) { 0 }) { 2 -> "down, then up, alternating"; 1 -> "up"; else -> "down" }
    return "${g.title ?: "Chord"}, strummed $how over $ms milliseconds, $notes"
}

/** When each note of a strummed chord starts, in ms, by its place in [n] notes (low first): DOWN and ALT play low to high, UP high to low. */
internal fun strumStart(i: Int, n: Int, ms: Int, dir: Int): Int { val o = if (dir == 1) n - 1 - i else i; return if (n > 1) ms * o / (n - 1) else 0 }

/** How many keys the chord's picture shows, from the C below its lowest note: two octaves, three for a wide chord. */
internal fun chordKeys(notes: List<Int>): Pair<Int, Int> { val lo = notes.first() - notes.first().mod(12); return lo to if (notes.last() - lo < 24) 24 else 36 }

/** Where there's nothing to draw: two centred lines that say why (Skiff's panel_note). */
private fun drawTwoLines(s: Sp, a: String?, b: String?, first: Color) {
    a?.let { s.text(it, 120f, 62f, first, 13f, centre = true, strong = true) }
    b?.let { s.text(it, 120f, 86f, mid, centre = true) }
}

private fun drawChord(s: Sp, g: PageGraph, c: Color) {
    val notes = g.notes.take(4)
    if (notes.isEmpty()) { drawTwoLines(s, g.title, g.caption, Tok.text); return }
    s.text(g.title ?: "", 14f, 30f, Tok.text, 17f, strong = true)
    g.caption?.let { s.text(it, 226f, 28f, mid, right = true) }
    val ms = g.values.getOrNull(0)
    if (ms != null) {
        // strummed: a row a note (low at the bottom, named), its bar from when the strum plays it (0…120 ms across), the root white;
        // the stroke is a line through the starts in the order played. ALT draws the downstroke.
        val dir = g.values.getOrElse(1) { 0 }; val n = notes.size
        val pitch = min(if (n > 1) 64 / (n - 1) else 0, 20); val th = if (pitch >= 14) 10 else max(4, pitch - 4)
        s.rect(line, 43f, 34f, 1f, 78f)
        val starts = arrayOfNulls<Pair<Float, Float>>(n)
        for (i in 0 until n) {
            val o = if (dir == 1) n - 1 - i else i
            val y = (104 - i * pitch - th / 2).toFloat(); val xs = 44f + strumStart(i, n, ms, dir) * 182 / 120
            if (th >= 8 || i % 2 == 0) s.text(noteName(notes[i]), 12f, y + th + 3f, mid, 10f)
            s.rect(if (notes[i].mod(12) == g.root) Tok.text else c, xs, y, 226f - xs, th.toFloat(), 3f)
            starts[o] = xs to (y + th / 2f)
        }
        if (n > 1) s.stroke(Tok.text, starts.filterNotNull(), 1.5f)
        return
    }
    val (lo, cnt) = chordKeys(notes); val w = 216 / cnt
    for (i in 0 until cnt) {
        val n = lo + i
        val col = if (n !in notes) Tok.lifted else if (n.mod(12) == g.root) Tok.text else c
        s.rect(col, (13 + i * w).toFloat(), if (BLACK_KEY[n.mod(12)]) 40f else 66f, (w - 2).toFloat(), 48f, if (w > 6) 3f else 2f)
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

// ---- The FM-1's own DELAY, REVERB, CHORUS and GLOBAL (decision 34, board 77): Skiff 2.5.1's ui_pgraph.c graph_delay (:21–78), graph_reverb
// (:82–147), graph_chorus (:172–243, pg_cho_resp :152–170) and graph_global (:431–468), as design/boards/fm1-screens/NOTES.md sets them out.
// Its shapes and its finish: square bar corners, whole-pixel steps (the tail's staircase), fades made by blending toward the picture's
// surface (ux_mix), never by gradient or opacity. FX › DELAY and FX › REVERB are the same drawings in the track's colour, scaled by its send.

/** GLO's pages are shared by every track, so they are drawn in the global greys and white, never a track's colour. */
// text2, a mid grey: the reverb keeps three tones apart (white reflections, this for the body, a dark band where it is damped)
private val GLOBAL_INK = Tok.text2

/** ux_mix(c, T_SURF, p): [p] percent of the way from the colour to the picture's surface. */
internal fun uxMix(c: Color, p: Int): Color = androidx.compose.ui.graphics.lerp(c, Tok.well, p.coerceIn(0, 100) / 100f)

/** TIME as sixths of a 1/16 (Skiff's DLY_6TH): 1/4 24, 1/8 12, 1/16 6… */
private val DLY_6TH = intArrayOf(24, 12, 6, 3, 8, 4, 48, 96, 192, 384, 18, 9, 36)

/** The delay's bars: each echo's left edge (x), width and height in the FM-1's pixels, the dry hit first. [send] 127 on GLO › DELAY. */
internal fun delayBars(time: Int, feedback: Int, mix: Int, send: Int = 127): List<Triple<Int, Int, Int>> {
    val tap = DLY_6TH[time.mod(13)]; val win = max(tap * 4, 96)
    val w = (tap * 208 / win - 3).coerceIn(2, 13)
    val out = mutableListOf<Triple<Int, Int, Int>>()
    var lvl = 1000
    for (i in 0 until 9) {
        if (lvl < 40) break
        val x = 14 + i * tap * 208 / win
        if (x + w > 228) break
        out += Triple(x, w, lvl / 10)
        lvl = if (i > 0) lvl * feedback * 230 / 32768 else mix * 1000 / 127 * send.coerceIn(0, 127) / 127
    }
    return out
}

/** DELAY: the dry hit in white, then the echoes on a beat (or bar) ruler; echo 1 as tall as MIX (times the track's send), each next one down by FEEDBACK. values: TIME, FEEDBACK, COLOR, MIX. */
private fun drawDelay(s: Sp, g: PageGraph, c: Color) {
    val v = List(4) { g.values.getOrElse(it) { if (it == 3) 127 else 0 } }
    val tap = DLY_6TH[v[0].mod(13)]; val win = max(tap * 4, 96); val unit = if (win > 96) 96 else 24
    val n = win / unit
    for (i in 0 until n) {
        val x = 14f + i * unit * 208 / win
        s.bar(dim, x, 123f, 2f, 3f)
        if (n <= 8 || i % 4 == 0) s.text("${i + 1}", x, 138f, mid, 10f)
    }
    delayBars(v[0], v[1], v[3], g.send).forEachIndexed { i, (x, w, h) ->
        s.bar(if (i == 0) Tok.text else uxMix(c, 15 + 50 * (i - 1) / 6), x.toFloat(), 120f - h, w.toFloat(), h.toFloat())
    }
    s.text("DRY", 14f, 17f, mid)
    // the FM-1 has MODE on its PRESETS card here; the phone names the mode (GLO › DELAY) beside the picture's top right
    if (g.kind == GraphKind.Delay) g.caption?.let { s.text(it.uppercase(), 228f, 17f, Tok.text, right = true) }
}

/** The reverb's tail: for each pixel column from x 44, its whole height and how much of its top is the dark DAMP band, in the FM-1's pixels. */
internal fun reverbTail(size: Int, damp: Int, hall: Boolean, send: Int = 127): List<Pair<Int, Int>> {
    val len = (40 + size.coerceIn(0, 127) * 144 / 127) * (if (hall) 2 else 1)
    val dimPct = 20 + damp.coerceIn(0, 127) * 60 / 127
    val amp = 84 * send.coerceIn(0, 127) / 127
    var e = 32768
    return (44..228).map { val h = amp * e / 32768; e = e - e * 3 / len; h to h * dimPct / 100 }
}

/** REVERB: five white reflections, then the tail a column a pixel, falling in whole-pixel steps to the floor; each column's top is the dark DAMP band over a lighter body. values: TYPE, SIZE, DAMP. */
private fun drawReverb(s: Sp, g: PageGraph, c: Color) {
    val v = List(3) { g.values.getOrElse(it) { 0 } }
    val amp = g.send.coerceIn(0, 127)
    // the type by its name when the page gives it (the FM-1's own word), else by its number (0 ROOM, 1 SPRING, 2 HALL)
    val type = g.caption?.uppercase()?.takeIf { it in setOf("ROOM", "SPRING", "HALL") } ?: listOf("ROOM", "SPRING", "HALL").getOrElse(v[0]) { "ROOM" }
    listOf(84, 60, 72, 46, 52).forEachIndexed { i, e -> val h = (e * amp / 127).toFloat(); s.bar(Tok.text, 12f + i * 6, 126f - h, 3f, h) }
    reverbTail(v[1], v[2], type == "HALL", amp).forEachIndexed { i, (h, band) ->
        if (h <= 0) return@forEachIndexed
        val x = 44f + i
        s.bar(uxMix(c, 55 + 30 * i / 184), x, 126f - h, 1f, band.toFloat())             // the damped top: dark
        s.bar(uxMix(c, 60 * i / 184), x, 126f - h + band, 1f, (h - band).toFloat())      // the body: the full colour, darker to the right
    }
    s.text(type, 12f, 18f, mid)
    if (type == "SPRING") s.stroke(mid, (64..228).map { x -> x.toFloat() to 13f + (sin((x - 64) * 13 / 256.0 * 2 * Math.PI) * 3).toFloat() }, 1f)   // the coil
}

private fun sineI(ph: Long): Double = sin((ph and 0xFFFFFFFFL) / 4294967296.0 * 2 * Math.PI)

/** pg_cho_resp: FLANGER's comb (mode 1) or PHASER's two notches (mode 2) at [x] 0…216, as 0…1 (and a little over with FEEDBACK). */
internal fun chorusResp(mode: Int, x: Int, depth: Int, fb: Int): Double {
    if (mode == 1) {
        val n = (4 + depth * 6 / 127).toLong()
        val sn = kotlin.math.abs(sineI(x.toLong() * n * 9942053L + 0x40000000L) * 32768)
        val kk = (sn * sn / 32768) * (sn * sn / 32768) / 32768
        return (sn * (127 - fb) + kk * fb) / 127 * (127 + fb) / 127 / 32768
    }
    var h = 32768.0
    for (k in 0 until 2) {
        val d = (x - if (k == 1) 150 else 66).toDouble(); val w = (10 + depth / 8).toDouble(); val r = d - (if (d < 0) -2 else 2) * w
        h -= 30000 * w * w / (w * w + d * d)
        h += fb * 128 * w * w / (w * w + r * r)
    }
    return max(0.0, h) / 32768
}

/** CHORUS: the dry line and its drifting copy (a sine, more waves with RATE, taller with DEPTH, a fainter ghost with FEEDBACK); as FLANGER or PHASER, the response curve filled to the floor. values: RATE, DEPTH, MODE, FEEDBACK. */
private fun drawChorus(s: Sp, g: PageGraph, c: Color) {
    val v = List(4) { g.values.getOrElse(it) { 0 } }
    val mode = v[2]
    if (mode == 1 || mode == 2) {
        val ys = (0..216).map { 124f - (chorusResp(mode, it, v[1], v[3]) * 40).toFloat() }
        ys.forEachIndexed { i, y -> s.bar(uxMix(c, 75), 12f + i, y, 1f, 124f - y) }
        s.bar(line, 12f, 84f, 216f, 1f)
        s.d.drawPath(s.path(ys.mapIndexed { i, y -> (12f + i) to y }), c, style = Stroke(s.run { 3f.px() }, join = StrokeJoin.Miter))
        s.text(if (mode == 1) "THE DRY AND ITS COPY: A COMB, SWEPT" else "FOUR STAGES: TWO NOTCHES, SWEPT", 12f, 17f, mid)
        return
    }
    val a = (v[1] * 44 / 127).toFloat(); val b = a * v[3] / 127
    val inc = (0xFFFFFFFFL / 216) * (1 + v[0] * 5 / 127)
    s.bar(mid, 12f, 74f, 216f, 1f)
    if (v[3] != 0) s.d.drawPath(s.path((0..216 step 2).map { (12f + it) to (74f + (sineI(it * inc - 0x30000000L) * b).toFloat()) }), mid, style = Stroke(s.run { 1f.px() }))
    s.d.drawPath(s.path((0..216 step 2).map { (12f + it) to (74f + (sineI(it * inc) * a).toFloat()) }), c, style = Stroke(s.run { 3f.px() }, join = StrokeJoin.Miter))
    s.text("DRY AND ITS DRIFTING COPY", 12f, 17f, mid)
}

/** "SWING 60:40": the long and short steps' share. */
internal fun swingText(swing: Int): String = "SWING ${50 + swing * 50 / 250}:${50 - swing * 50 / 250}"

/** GLOBAL: a bar's sixteen steps, downbeats tallest and white, the off sixteenths late by SWING+ over a dash where they'd be straight; the beats numbered. values: BPM, SWING+. */
private fun drawGlobal(s: Sp, g: PageGraph, c: Color) {
    val swing = g.values.getOrElse(1) { 0 }.coerceIn(0, 100)
    val push = swing * 13 / 250
    for (i in 0 until 16) {
        var x = 14 + i * 13
        val h = if (i % 4 == 0) 74 else if (i % 2 == 0) 52 else 40
        if (i % 2 == 1) { s.bar(dim, x.toFloat(), 125f, 7f, 3f); x += push }
        s.bar(if (i % 4 == 0) Tok.text else if (i % 2 == 0) c else uxMix(c, 35), x.toFloat(), 120f - h, 7f, h.toFloat())
    }
    for (i in 0 until 4) s.text("${i + 1}", 14f + i * 52, 38f, mid, 13f, strong = true)
    s.text(swingText(swing), 228f, 17f, mid, right = true)
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
    val title = page.pages.firstOrNull { it.index == page.page }?.title ?: page.title
    val v = page.controls.map { it?.raw ?: 0 }
    if (page.graph.kind == GraphKind.Lfo) {
        // the core sends LFO's four values on both pages; SYNC, TRIG and POLARITY are LFO 2's own knobs, kept a track for when LFO shows
        if (title == "LFO 2" && v.size >= 3) lfo2Seen[page.track] = v.take(3)
        val more = lfo2Seen[page.track]
        return if (page.graph.values.size >= 7 || more == null) page.graph else page.graph.copy(values = List(4) { page.graph.values.getOrElse(it) { 0 } } + more)
    }
    if (page.graph.kind != GraphKind.None) return page.graph
    if (page.family == "EDIT" && title == "VOICE" && v.size >= 4) return PageGraph(GraphKind.Voice, values = v, caption = page.controls.getOrNull(1)?.value)
    if (page.family != "FX") return page.graph
    return when (title) {
        "DELAY" -> PageGraph(GraphKind.FxDelay, values = listOf(v[1], v[2], v[3], 127), send = v[0], caption = page.controls.getOrNull(1)?.value)   // SEND (or DELAY), TIME, FEEDBACK, COLOR
        "REVERB" -> PageGraph(GraphKind.FxReverb, values = listOf(v[1], v[2], v[3]), send = v[0], caption = page.controls.getOrNull(1)?.value)                                                // SEND (or REVERB), TYPE, SIZE, DAMP
        "INSERT" -> PageGraph(GraphKind.Insert, values = listOf(v[0], v[1], v[2], v[3], 127), caption = page.controls.getOrNull(1)?.value)       // TYPE, A, B, C
        "SLICER" -> PageGraph(GraphKind.Slicer, values = v)
        "DUCK" -> PageGraph(GraphKind.Duck, values = listOf(v[1], 250))                                                                          // BY, DEPTH, RELEASE: no hits known
        else -> page.graph
    }
}

/** LFO 2's SYNC, TRIG, POLARITY as last seen on that page, by track: the LFO page's picture needs them and the page area doesn't send them. */
private val lfo2Seen = java.util.concurrent.ConcurrentHashMap<Int, List<Int>>()

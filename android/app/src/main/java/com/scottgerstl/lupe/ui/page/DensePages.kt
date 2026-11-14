package com.scottgerstl.lupe.ui.page

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.Fm6Operator
import com.scottgerstl.lupe.core.Fm6Patch
import com.scottgerstl.lupe.core.PageGraph
import com.scottgerstl.lupe.core.SoundSheet
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

// The dense EDIT pages' pictures (decision 12): OPERATOR's operator tiles and envelopes, ALL OPS' algorithm chart, DRUM-X
// SOUND's sheet. Ported from ios/FM1/FM6Pages.swift (FM6Algorithm, FM6AlgorithmChart, FM6EnvelopeGraph) and
// SkiffEdit's DXSoundPage, as pictures of what the FM-1 shows: read-only here, with the FM-1's own cursor lit. Tapping a
// tile moves the FM-1's cursor (pickTile), which the link's read-only switch drops until writes are allowed.

/** The 32 algorithms (fm6_core.c FM6_ALG, ui_graph.c FM6_CELL): carriers | routes (a>b: a into b) | feedback operator | cells (col,row per operator). Same table as FM6.algorithms on the iPad. */
private class Algorithm(val carriers: Set<Int>, val routes: List<Pair<Int, Int>>, val feedback: Int, val cells: Map<Int, Pair<Int, Int>>)

private val Algorithms: List<Algorithm> by lazy {
    listOf(
        "1,3|2>1 4>3 5>4 6>5|6|0,0 0,1 1,0 1,1 1,2 1,3", "1,3|2>1 4>3 5>4 6>5|2|0,0 0,1 2,0 2,1 2,2 2,3",
        "1,4|2>1 3>2 5>4 6>5|6|0,0 0,1 0,2 1,0 1,1 1,2", "1,4|2>1 3>2 5>4 6>5|6|0,0 0,1 0,2 1,0 1,1 1,2",
        "1,3,5|2>1 4>3 6>5|6|0,0 0,1 1,0 1,1 2,0 2,1", "1,3,5|2>1 4>3 6>5|6|0,0 0,1 1,0 1,1 2,0 2,1",
        "1,3|2>1 4>3 5>3 6>5|6|0,0 0,1 1,0 1,1 2,1 2,2", "1,3|2>1 4>3 5>3 6>5|4|0,0 0,1 1,0 2,1 1,1 1,2",
        "1,3|2>1 4>3 5>3 6>5|2|0,0 0,1 2,0 2,1 3,1 3,2", "1,4|2>1 3>2 5>4 6>4|3|0,0 0,1 0,2 1,0 1,1 2,1",
        "1,4|2>1 3>2 5>4 6>4|6|0,0 0,1 0,2 1,0 1,1 2,1", "1,3|2>1 4>3 5>3 6>3|2|0,0 0,1 3,0 2,1 3,1 4,1",
        "1,3|2>1 4>3 5>3 6>3|6|0,0 0,1 2,0 1,1 2,1 3,1", "1,3|2>1 4>3 5>4 6>4|6|0,0 0,1 1,0 1,1 0,2 1,2",
        "1,3|2>1 4>3 5>4 6>4|2|0,0 0,1 2,0 2,1 1,2 2,2", "1|2>1 3>1 5>1 4>3 6>5|6|1,0 0,1 1,1 1,2 2,1 2,2",
        "1|2>1 3>1 5>1 4>3 6>5|2|1,0 2,1 0,1 0,2 1,1 1,2", "1|2>1 3>1 4>1 5>4 6>5|3|1,0 0,1 2,1 1,1 1,2 1,3",
        "1,4,5|2>1 3>2 6>4 6>5|6|0,0 0,1 0,2 1,0 2,0 1,1", "1,2,4|3>1 3>2 5>4 6>4|3|0,0 1,0 0,1 2,0 2,1 3,1",
        "1,2,4,5|3>1 3>2 6>4 6>5|3|0,0 1,0 0,1 2,0 3,0 2,1", "1,3,4,5|2>1 6>3 6>4 6>5|6|0,0 0,1 1,0 2,0 3,0 2,1",
        "1,2,4,5|3>2 6>4 6>5|6|0,0 1,0 1,1 2,0 3,0 2,1", "1,2,3,4,5|6>3 6>4 6>5|6|0,0 1,0 2,0 3,0 4,0 3,1",
        "1,2,3,4,5|6>4 6>5|6|0,0 1,0 2,0 3,0 4,0 3,1", "1,2,4|3>2 5>4 6>4|6|0,0 1,0 1,1 2,0 2,1 3,1",
        "1,2,4|3>2 5>4 6>4|3|0,0 1,0 1,1 3,0 3,1 4,1", "1,3,6|2>1 4>3 5>4|5|0,0 0,1 1,0 1,1 1,2 2,0",
        "1,2,3,5|4>3 6>5|6|0,0 1,0 2,0 2,1 3,0 3,1", "1,2,3,6|4>3 5>4|5|0,0 1,0 2,0 2,1 2,2 3,0",
        "1,2,3,4,5|6>5|6|0,0 1,0 2,0 3,0 4,0 4,1", "1,2,3,4,5,6||6|0,0 1,0 2,0 3,0 4,0 5,0",
    ).map { r ->
        val f = r.split("|")
        Algorithm(
            f[0].split(",").map { it.toInt() }.toSet(),
            f[1].split(" ").filter { it.isNotEmpty() }.map { p -> p.split(">").let { it[0].toInt() to it[1].toInt() } },
            f[2].toInt(),
            f[3].split(" ").mapIndexed { k, c -> (k + 1) to c.split(",").let { it[0].toInt() to it[1].toInt() } }.toMap(),
        )
    }
}

private fun silent(p: Fm6Patch, op: Int) = (p.ops.getOrNull(op - 1)?.output ?: 0) == 0

private fun algorithmCaption(p: Fm6Patch, alg: Algorithm, picked: Int): String = when {
    silent(p, picked) -> "OP$picked IS SILENT: OUTPUT 0"
    picked in alg.carriers -> "OP$picked GOES TO THE OUTPUT"
    else -> "OP$picked MODULATES " + alg.routes.filter { it.first == picked }.joinToString(", ") { "OP${it.second}" }
}

// ---------------------------------------------------------------- OPERATOR

@Composable
fun Fm6OperatorPicture(g: PageGraph, colour: Color, modifier: Modifier = Modifier) {
    val p = g.fm6 ?: return
    val alg = Algorithms[p.algorithm.coerceIn(0, 31)]
    // the operators themselves are the page's tiles (PageState.tiles); this is only their envelopes
    Box(modifier.clip(RoundedCornerShape(8.dp)).background(Tok.well)) { EnvelopeGraph(p, alg, colour) }
}

/** Each operator's envelope as a line over the note (a sketch of ui_fm6.c fm_lines, as on the iPad): carriers thick, modulators thin, the picked one white. */
@Composable
private fun EnvelopeGraph(p: Fm6Patch, alg: Algorithm, colour: Color) {
    val tm = rememberTextMeasurer()
    val picked = p.picked.coerceIn(1, 6)
    Canvas(Modifier.fillMaxSize().semantics { contentDescription = "Operator envelopes, operator $picked picked" }) {
        val x0 = 12.dp.toPx(); val y0 = 12.dp.toPx()
        val w = size.width - 24.dp.toPx(); val h = size.height - 40.dp.toPx()   // room under the baseline for the operator's role
        val held = w * 0.72f
        fun time(r: Int) = 0.02f + ((99 - r) / 99f).pow(2) * 1.2f
        fun points(n: Int): List<Offset> {
            val o = p.ops.getOrNull(n - 1) ?: return emptyList()
            val r = o.r.ifEmpty { listOf(0, 0, 0, 0) }; val l = o.l.map { it / 99f }.ifEmpty { listOf(0f, 0f, 0f, 0f) }
            val t1 = time(r[0]); val t2 = t1 + time(r[1]); val t3 = t2 + time(r[2])
            val scale = (held - 20.dp.toPx()) / max(t3, 0.3f)
            fun y(v: Float) = y0 + h - v * h * o.output / 99f
            return listOf(
                Offset(x0, y(l[3])), Offset(x0 + t1 * scale, y(l[0])), Offset(x0 + t2 * scale, y(l[1])), Offset(x0 + t3 * scale, y(l[2])),
                Offset(x0 + held, y(l[2])), Offset(x0 + held + min(w - held, time(r[3]) * (w - held) / 1.2f), y(l[3])),
            )
        }
        fun line(pts: List<Offset>, c: Color, width: Float) {
            if (pts.size < 2) return
            val path = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { lineTo(it.x, it.y) } }
            drawPath(path, c, style = Stroke(width, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
        drawLine(Tok.text3, Offset(x0 + held, y0), Offset(x0 + held, y0 + h), 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 3.dp.toPx())))
        val order = (1..6).filter { it !in alg.carriers } + (1..6).filter { it in alg.carriers }
        for (n in order) if (n != picked) line(points(n), colour.copy(alpha = if (n in alg.carriers) 1f else 0.6f), (if (n in alg.carriers) 4 else 2).dp.toPx())
        val pts = points(picked)
        line(pts, Tok.text, (if (picked in alg.carriers) 5 else 3).dp.toPx())
        for (q in pts.drop(1).take(4)) drawCircle(Tok.text, 4.5.dp.toPx(), q, style = Stroke(1.5.dp.toPx()))
        label(tm, "KEY UP", x0 + held + 4.dp.toPx(), y0, Tok.text2, 10f)
        label(tm, "OP$picked ${if (picked in alg.carriers) "CARRIER" else "MODULATOR"}", x0, size.height - 6.dp.toPx(), Tok.text2Raised, 11f, bottomAnchor = true)
    }
}

private fun DrawScope.label(tm: androidx.compose.ui.text.TextMeasurer, s: String, x: Float, y: Float, c: Color, sp: Float, right: Boolean = false, bottomAnchor: Boolean = false) {
    val r = tm.measure(s, LupeType.small.copy(fontSize = sp.sp, color = c))
    drawText(r, topLeft = Offset(if (right) x - r.size.width else x, if (bottomAnchor) y - r.size.height else y))
}

// ---------------------------------------------------------------- ALL OPS

@Composable
fun Fm6AllOpsPicture(g: PageGraph, colour: Color, modifier: Modifier = Modifier) {
    val p = g.fm6 ?: return
    val alg = Algorithms[p.algorithm.coerceIn(0, 31)]
    val picked = p.picked.coerceIn(1, 6)
    // landscape: the chart beside the voice's other settings
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(8.dp)).background(Tok.well)) { AlgorithmChart(p, alg, picked, colour) }
        if (p.lines.isNotEmpty()) Column(Modifier.width(150.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            for (line in p.lines) BasicText(line, style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 2)
        }
    }
}

/** The algorithm as Skiff charts it (ui_graph.c graph_fm6): carriers on the output bus, modulators above with their routes, the feedback loop; the picked operator lit, a silent one dim. */
@Composable
private fun AlgorithmChart(p: Fm6Patch, alg: Algorithm, picked: Int, colour: Color) {
    val tm = rememberTextMeasurer()
    Canvas(Modifier.fillMaxSize().semantics { contentDescription = "Algorithm ${p.algorithm + 1}. " + algorithmCaption(p, alg, picked) }) {
        val maxCol = alg.cells.values.maxOf { it.first }; val maxRow = alg.cells.values.maxOf { it.second }
        // The chart at its full size (40 × 30 boxes, 54 across, 44 up) where it fits; in a short picture (110 dp in the pop-up, 64 on Edit)
        // or a narrow one, the boxes and the gaps between them shrink together so no row meets the next.
        val algLabel = tm.measure("ALG %02d".format(p.algorithm + 1), LupeType.small.copy(fontSize = 11.sp))
        val capLabel = tm.measure(algorithmCaption(p, alg, picked), LupeType.small.copy(fontSize = 11.sp))
        val kx = min(1f, (size.width - 60.dp.toPx()) / ((maxCol * 54 + 40).dp.toPx())).coerceAtLeast(0.4f)
        val bw = 40.dp.toPx() * kx; val dx = 54.dp.toPx() * kx
        // the two captions sit in the top corners; they take a line of their own only when the chart is wide enough to run under them
        val chartHalf = maxCol * dx / 2 + bw / 2 + 12.dp.toPx()
        val clear = size.width / 2 - chartHalf >= max(algLabel.size.width, capLabel.size.width) + 12.dp.toPx()
        val top = if (clear) 0f else algLabel.size.height + 8.dp.toPx()
        val rows = maxRow + 1
        val ky = min(1f, (size.height - top) / ((rows * 30 + maxRow * 14 + 30).dp.toPx())).coerceAtLeast(0.2f)
        val bh = 30.dp.toPx() * ky; val gap = 14.dp.toPx() * ky; val stub = 10.dp.toPx() * ky
        val bus = size.height - 12.dp.toPx() * ky
        val dy = min(52.dp.toPx(), bh + max(gap, (bus - stub - top - 8.dp.toPx() * ky - rows * bh) / max(1, maxRow)))
        fun centre(op: Int): Offset {
            val c = alg.cells[op] ?: (0 to 0)
            return Offset(size.width / 2 + c.first * dx - maxCol * dx / 2, bus - stub - bh / 2 - c.second * dy)
        }
        val line = Tok.text2; val lw = 1.5.dp.toPx()
        val cs = alg.carriers.map { centre(it).x }
        val ax = cs.max() + bw / 2 + 20.dp.toPx() * kx
        drawLine(line, Offset(cs.min() - 10.dp.toPx() * kx, bus), Offset(ax, bus), lw)
        drawPath(Path().apply { moveTo(ax - 6.dp.toPx(), bus - 4.dp.toPx()); lineTo(ax, bus); lineTo(ax - 6.dp.toPx(), bus + 4.dp.toPx()) }, line, style = Stroke(lw))
        for (c in alg.carriers) { val o = centre(c); drawLine(line, Offset(o.x, o.y + bh / 2), Offset(o.x, bus), lw) }
        for ((a, t) in alg.routes) {
            val s = centre(a); val d = centre(t); val y = d.y - bh / 2 - gap * 0.36f
            drawPath(Path().apply { moveTo(s.x, s.y + bh / 2); lineTo(s.x, y); lineTo(d.x, y); lineTo(d.x, d.y - bh / 2) }, line, style = Stroke(lw))
        }
        val f = centre(alg.feedback)
        drawPath(Path().apply {
            val out = 8.dp.toPx() * kx; val up = gap * 0.5f
            moveTo(f.x + bw / 2, f.y); lineTo(f.x + bw / 2 + out, f.y); lineTo(f.x + bw / 2 + out, f.y - bh / 2 - up)
            lineTo(f.x, f.y - bh / 2 - up); lineTo(f.x, f.y - bh / 2)
        }, if (p.feedback > 0) Tok.text else Tok.text3, style = Stroke(lw))
        for (op in 1..6) {
            val o = centre(op)
            // a silent operator is a dim tile whatever its role (grey words on the track colour wouldn't read)
            val fill = if (op == picked) Tok.text else if (silent(p, op)) Tok.control else if (op in alg.carriers) colour else Tok.control
            drawRoundRect(fill, Offset(o.x - bw / 2, o.y - bh / 2), Size(bw, bh), CornerRadius(min(5.dp.toPx(), bh / 3)))
            val ink = if (op == picked) Tok.onColour else if (silent(p, op)) Tok.text2 else if (op in alg.carriers) Tok.onColour else Tok.text
            // the number keeps the label size while the box holds it, then shrinks with the box (never under 9 sp)
            val r = tm.measure("$op", LupeType.label.copy(color = ink, fontSize = min(LupeType.label.fontSize.value, max(9f, bh.toDp().value * 0.62f)).sp, lineHeight = androidx.compose.ui.unit.TextUnit.Unspecified))
            drawText(r, topLeft = Offset(o.x - r.size.width / 2f, o.y - r.size.height / 2f))
        }
        label(tm, "ALG %02d".format(p.algorithm + 1), 8.dp.toPx(), 4.dp.toPx(), Tok.text2Raised, 11f)
        label(tm, algorithmCaption(p, alg, picked), size.width - 8.dp.toPx(), 4.dp.toPx(), Tok.text2Raised, 11f, right = true)
    }
}

// ---------------------------------------------------------------- DRUM-X SOUND

@Composable
fun SoundSheetPicture(g: PageGraph, modifier: Modifier = Modifier) {
    val s: SoundSheet = g.sheet ?: return
    // the lanes are the page's tiles (PageState.tiles); this is the picked sound's windows, read-only, the FM-1's knobs' row lit
    Column(modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        s.rows.forEachIndexed { r, row ->
            val lit = s.lit == r
            Row(Modifier.fillMaxWidth().height(36.dp), horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.width(52.dp).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(if (lit) Tok.text else Tok.control)
                        .semantics { contentDescription = row.title + " row" + if (lit) ", the FM-1's knobs" else "" },
                    contentAlignment = Alignment.Center,
                ) { BasicText(row.title, style = LupeType.small.copy(fontSize = 10.sp, color = if (lit) Tok.onColour else Tok.text2Raised), maxLines = 2) }
                row.cells.forEach { c ->
                    Row(
                        Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(6.dp)).background(Tok.well).padding(horizontal = 6.dp)
                            .semantics(mergeDescendants = true) { contentDescription = "${c.label}, ${c.value}" },
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        BasicText(c.label, style = LupeType.small.copy(fontSize = 10.sp, color = Tok.text2Raised), maxLines = 1)
                        BasicText(c.value, style = LupeType.number.copy(fontSize = 15.sp, color = Tok.text), maxLines = 1)
                    }
                }
            }
        }
    }
}

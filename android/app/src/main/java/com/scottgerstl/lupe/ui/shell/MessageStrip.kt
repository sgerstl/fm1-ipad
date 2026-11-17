package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.ClearedPad
import com.scottgerstl.lupe.core.CoreNotice
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.NO_PATTERN_FREE
import com.scottgerstl.lupe.core.NoticeKind
import com.scottgerstl.lupe.core.UndoClear
import com.scottgerstl.lupe.core.clearedWords
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.delay

// Messages: one component, two homes (design/DESIGN.md; Scott, 2026-11-17, messages rule). This is the app strip: one place, bottom
// centre over the page, for every passing message about the app or the song. It replaces the refusal strip, the Undo strip and the scene
// row's own notice, which had three looks, two timers and could show two refusals at once (qa/messages-audit-2026-11-17.md rows 17, 18, 20).
//
// It holds one message: a refusal, an Undo or a confirmation, and a new one replaces the old. The rule allows an ongoing state under it
// (knob recording, a FREE TAKE to keep); Android has none to show there today (its free take is a page of its own), so there is no row for one.

/** How long a confirmation stays. Nothing else leaves on a timer (Scott, 2026-11-17, messages rule). */
const val CONFIRMATION_MS = 4000L

enum class MessageKind { Refusal, Undo, Confirmation }

/**
 * One message. [id] grows with each, so the same words twice still replace (and are announced) twice. [undo] is the clear an Undo puts back;
 * [fix] names what fixes a refusal ("patternsFree", "scene:3"), so it can leave when that happens rather than wait for ✕.
 */
data class StripMessage(val id: Long, val kind: MessageKind, val text: String, val undo: ClearedPad? = null, val fix: String? = null) {
    /** The first sentence: what happened. */
    val line: String get() = split().first
    /** The rest, on a second line: what to do. */
    val detail: String? get() = split().second
    private fun split(): Pair<String, String?> {
        val i = text.indexOf(". ")
        return if (i < 0 || kind == MessageKind.Undo) text to null else text.substring(0, i + 1) to text.substring(i + 2).trim().ifEmpty { null }
    }
    /** The one action it carries: Undo for an Undo, Patterns on the all-64-taken refusal (board 79). */
    val opensPatterns: Boolean get() = kind == MessageKind.Refusal && text.startsWith(NO_PATTERN_FREE)
    /** The Timeline's "Stop to change the song" (hybrid UI, spec 4.4): it carries Stop, and leaves by itself when the song stops. */
    val offersStop: Boolean get() = kind == MessageKind.Refusal && fix == STOP_FIX
}

/**
 * Which message the strip shows. Kept apart from the drawing so it can be tested. The core's notices and its list of clears come in through
 * [onNotice] and [onClearUndo]; a screen's own refusal (the scene row's) through [refuse].
 */
class MessageModel(noticeSeen: Int = -1, undoSeen: ClearedPad? = null) {
    var current by mutableStateOf<StripMessage?>(null)
        private set
    private var next = 0L
    /** The core notice last taken (or already there when the screen opened: not news). */
    private var noticeSeen = noticeSeen
    /** The clear last offered, so the same list republished doesn't offer it again. */
    private var undoSeen = undoSeen

    fun post(kind: MessageKind, text: String, undo: ClearedPad? = null, fix: String? = null) {
        current = StripMessage(++next, kind, text, undo, fix)
    }

    fun refuse(text: String, fix: String? = null) = post(MessageKind.Refusal, text, fix = fix)

    /** ✕, the Undo done, or a confirmation's time up: only that message goes (a newer one that replaced it stays). */
    fun dismiss(id: Long) { if (current?.id == id) current = null }

    /** What a refusal was about is fixed: it leaves without ✕. */
    fun fixed(test: (String) -> Boolean) { val c = current; if (c?.kind == MessageKind.Refusal && c.fix != null && test(c.fix)) current = null }

    fun onNotice(n: CoreNotice) {
        if (n.seq <= noticeSeen || n.text.isEmpty()) return
        noticeSeen = n.seq
        if (n.kind == NoticeKind.Confirmation) post(MessageKind.Confirmation, n.text)
        else post(MessageKind.Refusal, n.text, fix = if (n.text.startsWith(NO_PATTERN_FREE)) "patternsFree" else null)
    }

    /**
     * The core's open clears. A new last one is offered; when the one showing is no longer in the list, the next edit ended it (or it was
     * undone), so it leaves: Undo lasts until the next edit or ✕, never a timer (Scott, 2026-11-17, messages rule).
     */
    fun onClearUndo(open: List<ClearedPad>) {
        val last = open.lastOrNull()
        if (undoSeen != null && undoSeen !in open) undoSeen = null      // (the same pad cleared again later is news again)
        if (last != null && last != undoSeen) { undoSeen = last; post(MessageKind.Undo, clearedWords(last), undo = last) }
        val c = current
        if (c?.kind == MessageKind.Undo && c.undo !in open) current = null
    }

    fun onPatternsFree(free: Int?) { if (free != null && free > 0) fixed { it == "patternsFree" } }
}

/** The shell's strip, for a screen with a refusal of its own (the scene row). */
val LocalMessages = staticCompositionLocalOf { MessageModel() }

/** The fix that names a stop: the strip offers Stop, and the message leaves when the song stops. */
const val STOP_FIX = "stop"

/**
 * The app strip: Tok.held, radius 12, the held shadow, up to 560 dp wide, 12 dp above the foot. An icon by kind, the message (14 sp, a second
 * line 13 sp), its one key and ✕. In: 200 ms rising 16 dp with a fade; out: 150 ms; a replacement cross-fades in place in 150 ms; with Reduce
 * Motion it only fades, 150 ms. Each message is announced once (a polite live region); its keys are buttons with their words.
 */
@Composable
fun MessageStrip(core: LupeCore, model: MessageModel, modifier: Modifier = Modifier) {
    val notice by core.notice.collectAsStateWithLifecycle()
    val pads by core.pads.collectAsStateWithLifecycle()
    val reduce = LocalReduceMotion.current
    LaunchedEffect(notice) { model.onNotice(notice) }
    LaunchedEffect(pads.clearUndo) { model.onClearUndo(pads.clearUndo) }
    LaunchedEffect(pads.patternsFree) { model.onPatternsFree(pads.patternsFree) }
    val msg = model.current
    // a confirmation leaves after 4 s; nothing else has a timer
    LaunchedEffect(msg?.id) { if (msg?.kind == MessageKind.Confirmation) { delay(CONFIRMATION_MS); model.dismiss(msg.id) } }
    // the words stay while the strip leaves
    var shown by remember { mutableStateOf<StripMessage?>(null) }
    if (msg != null) shown = msg
    val showing = msg != null
    val t = animatedFloat(if (showing) 1f else 0f, if (showing && !reduce) Dur.FINGER else Dur.STATE, if (showing) EaseOut else EaseIn)
    val m = shown
    if (m == null || (t.value <= 0.001f && !showing)) return
    val sheets = com.scottgerstl.lupe.ui.sheet.LocalSheetHost.current
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
        Row(
            Modifier.widthIn(max = 560.dp).fillMaxWidth()
                .graphicsLayer { alpha = t.value; if (!reduce) translationY = (1f - t.value) * 16.dp.toPx() }
                .shadow(12.dp, RoundedCornerShape(12.dp), ambientColor = Color.Black, spotColor = Color.Black)
                .background(Tok.held, RoundedCornerShape(12.dp))
                .defaultMinSize(minHeight = 44.dp)
                // the keys' 44 dp touch boxes stand 6 dp past their 32 dp faces, so the ✕ face sits 12 dp in from the edge
                .padding(start = 12.dp, end = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // one node for TalkBack: its words change with each message, so each is said once
            Box(
                Modifier.weight(1f).clearAndSetSemantics { contentDescription = m.text; liveRegion = LiveRegionMode.Polite },
            ) {
                LupeCrossfade(m, Modifier.fillMaxWidth()) { x ->
                    Row(Modifier.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                        MessageIcon(x.kind, Tok.text)
                        Spacer(Modifier.width(8.dp))
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            BasicText(x.line, style = MESSAGE, maxLines = 2)
                            x.detail?.let { BasicText(it, style = DETAIL, maxLines = 3) }
                        }
                    }
                }
            }
            LupeCrossfade(m) { x ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.width(2.dp))
                    if (x.kind == MessageKind.Undo && x.undo != null) {
                        Key({ core.send(UndoClear(x.undo.track, x.undo.entry)); model.dismiss(x.id) }, "Undo", width = 72.dp, height = 32.dp, minTarget = 44.dp) { fg -> KeyLabel("Undo", fg) }
                    }
                    if (x.opensPatterns) {
                        Key({ model.dismiss(x.id); sheets.showPatterns() }, "Patterns", width = 88.dp, height = 32.dp, minTarget = 44.dp) { fg -> KeyLabel("Patterns", fg) }
                    }
                    if (x.offersStop) {
                        Key({ model.dismiss(x.id); core.send(com.scottgerstl.lupe.core.Intent.Stop) }, "Stop the song", width = 72.dp, height = 32.dp, minTarget = 44.dp) { fg -> KeyLabel("Stop", fg) }
                    }
                    Key({ model.dismiss(x.id) }, "Dismiss", width = 32.dp, height = 32.dp, minTarget = 44.dp) { fg -> CrossIcon(fg) }
                }
            }
        }
    }
}

/** The message: Barlow 14 regular (the key size at the words' weight), in the app's white. */
private val MESSAGE = LupeType.key.copy(fontWeight = FontWeight.Normal, color = Tok.text)
/**
 * The second line, 13 sp. In text2Raised, not text2: #A1A1AA on held #3E3E46 is about 4.1:1, under the 4.5:1 small text needs; #C4C4CC is
 * about 6:1 (Scott, 2026-11-17, messages rule asks for the secondary grey; this is the secondary grey for a raised surface).
 */
private val DETAIL = LupeType.small.copy(fontSize = 13.sp, lineHeight = (13 * 1.2f).sp, color = Tok.text2Raised)

/** The kind's icon, 16 dp, drawn in one stroke as the app's other drawn icons: refusal ⓘ-style exclamation in a circle, Undo a turning-back arrow, confirmation a check. */
@Composable
private fun MessageIcon(kind: MessageKind, color: Color) = Canvas(Modifier.size(16.dp)) {
    val w = 1.5.dp.toPx()
    val u = size.width / 16f
    val stroke = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round)
    when (kind) {
        MessageKind.Refusal -> {
            drawCircle(color, radius = 7f * u - w / 2, style = stroke)
            drawLine(color, Offset(8f * u, 4.5f * u), Offset(8f * u, 9f * u), w, StrokeCap.Round)
            drawCircle(color, radius = w * 0.65f, center = Offset(8f * u, 11.5f * u))
        }
        MessageKind.Undo -> {
            // arrow.uturn.backward: left along the top, round and back down
            val p = Path().apply {
                moveTo(3f * u, 5.5f * u); lineTo(10f * u, 5.5f * u)
                arcTo(Rect(6.5f * u, 5.5f * u, 13.5f * u, 12.5f * u), -90f, 180f, false)
                lineTo(7f * u, 12.5f * u)
            }
            drawPath(p, color, style = stroke)
            drawPath(Path().apply { moveTo(6f * u, 2.5f * u); lineTo(3f * u, 5.5f * u); lineTo(6f * u, 8.5f * u) }, color, style = stroke)
        }
        MessageKind.Confirmation -> {
            drawPath(Path().apply { moveTo(2.5f * u, 8.5f * u); lineTo(6.5f * u, 12.5f * u); lineTo(13.5f * u, 3.5f * u) }, color, style = stroke)
        }
    }
}

/** ✕, drawn in the same stroke as the icons. */
@Composable
private fun CrossIcon(color: Color) = Canvas(Modifier.size(12.dp)) {
    val w = 1.5.dp.toPx()
    drawLine(color, Offset(w, w), Offset(size.width - w, size.height - w), w, StrokeCap.Round)
    drawLine(color, Offset(size.width - w, w), Offset(w, size.height - w), w, StrokeCap.Round)
}

package com.scottgerstl.lupe.ui.shell

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.layout.fillMaxWidth
import com.scottgerstl.lupe.ui.slide.slideToTurn
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * One choice in a hold menu, as the iPad's MenuItem (ios/FM1/Menus.swift): a title, a small second line, a tick when it is the current
 * choice. [confirm] makes it a choice that loses something: picked, it asks once more in place, a red-outlined button with these words naming
 * what goes. [children] makes it open a second set of choices in the same place (Set pattern…). A page of too many is cut into "More…".
 */
class HoldItem(
    val title: String, val sub: String? = null, val checked: Boolean = false, val enabled: Boolean = true,
    val confirm: String? = null, val children: (() -> List<HoldItem>)? = null,
    /** A value set by sliding on the row (LEVEL, PAN on a track's head): the row stays, the menu stays open. */
    val slide: HoldSlide? = null,
    val action: () -> Unit = {},
)

/**
 * A value in a hold menu, set by sliding a finger along its row (decision 10: no − / + anywhere). [raw] and [text] are read as the row draws,
 * so they should read Compose state. TalkBack gets the range, Increase and Decrease (the way in that isn't a drag).
 */
class HoldSlide(val raw: () -> Int, val text: () -> String, val min: Int, val max: Int, val bipolarAt: Int? = null, val stepDp: Float = 3f, val onSet: (Int) -> Unit)

/** The hold menu that is open: where the finger was when the hold fired (window pixels), the track's colour, the choices. */
class HoldMenuOpen(val at: Offset, val colour: Color, val items: List<HoldItem>, val title: String?)

/**
 * The hold menu (design/boards/radial-menu.html, Scott 2026-11-14): it replaces the menus that used to open beside the finger. One for the
 * whole screen; whatever was held opens it with [open] and, while that finger stays down, feeds it the finger's place with [drag] so a choice
 * can be picked in the same gesture ([release]). Let go on nothing and it stays open for a tap.
 */
@Stable
class HoldMenuState {
    var menu by mutableStateOf<HoldMenuOpen?>(null); private set
    /** Counts each opening (and each new set of choices), so the entrance plays again. */
    var opened by mutableIntStateOf(0); private set
    var hot by mutableIntStateOf(-1)
    /** The choice asking to be confirmed, and when it began asking (taps are ignored for 0.4 s). */
    var confirming by mutableIntStateOf(-1)
    var confirmAt = 0L
    /** Where the choices are on screen, for the held finger's hit test. Set by the host as it lays them out. */
    internal var rects: List<Rect> = emptyList()
    internal var tick: () -> Unit = {}

    fun open(at: Offset, colour: Color, items: List<HoldItem>, title: String? = null) {
        if (items.isEmpty()) return
        menu = HoldMenuOpen(at, colour, paged(items)); hot = -1; confirming = -1; opened++
    }
    private fun HoldMenuOpen(at: Offset, colour: Color, items: List<HoldItem>) = HoldMenuOpen(at, colour, items, null)
    fun close() { menu = null; hot = -1; confirming = -1 }

    /** The held finger moved to [pos] (window pixels): the choice under it lights. */
    fun drag(pos: Offset) {
        val k = rects.indexOfFirst { it.contains(pos) }.let { if (it >= 0 && menu?.items?.getOrNull(it)?.enabled == true) it else -1 }
        if (k != hot) { hot = k; if (k >= 0) tick() }
    }
    /** The held finger lifted: the lit choice is picked; with none lit the menu stays, for a tap. */
    fun release() { if (hot >= 0) pick(hot) }

    fun pick(k: Int) {
        val m = menu ?: return
        val item = m.items.getOrNull(k) ?: return
        if (!item.enabled || item.slide != null) return   // a slide row is slid, not picked
        when {
            item.children != null -> { menu = HoldMenuOpen(m.at, m.colour, paged(item.children.invoke())); hot = -1; confirming = -1; opened++ }
            item.confirm != null && confirming != k -> { confirming = k; confirmAt = System.currentTimeMillis(); hot = -1 }
            item.confirm != null && System.currentTimeMillis() - confirmAt < 400 -> Unit   // the second tap of a quick double tap can't confirm
            else -> { close(); item.action() }
        }
    }

    companion object {
        /** No more than six in one place (they are 56 dp apart in a 412 dp screen): the rest go behind "More…". */
        fun paged(items: List<HoldItem>, per: Int = 6): List<HoldItem> =
            if (items.size <= per) items else items.take(per - 1) + HoldItem("More…", sub = "${items.size - (per - 1)} more", children = { items.drop(per - 1) })
    }
}

val LocalHoldMenu = compositionLocalOf<HoldMenuState?> { null }

/** Where one choice sits: its near edge ([edgeX], [cy]) and which way it opens. In dp. */
class HoldSpot(val edgeX: Float, val cy: Float, val left: Boolean)

/**
 * The choices' places (the mockup's geometry): stacked one above another, [step] apart, around the finger's height and kept on the screen;
 * each pushed out to where its height meets a circle of [radius] round the finger, so the stack bows with the circle. They open to the left when
 * the finger is too near the right edge. All in dp.
 */
fun holdSpots(x: Float, y: Float, n: Int, screenW: Float, screenH: Float, itemW: Float = 200f, itemH: Float = 48f, radius: Float = 120f, step: Float = 56f, preferLeft: Boolean = false): List<HoldSpot> {
    // [preferLeft] (Settings › Handedness, right-handed): to the left of the finger whenever there is room there, so the hand doesn't cover them
    val left = if (preferLeft) x >= radius + itemW + 24f else x > screenW - (radius + itemW + 24f)
    val lowest = screenH - 16f - itemH / 2 - (n - 1) * step
    val top = (y - (n - 1) * step / 2).coerceAtMost(lowest).coerceAtLeast(8f + itemH / 2)
    return List(n) { k ->
        val cy = top + k * step; val dy = cy - y
        val dx = sqrt((radius * radius - dy * dy).coerceAtLeast(0f)).let { if (it <= 0f) 24f else it }
        // kept on the screen sideways too
        val edge = if (left) (x - dx).coerceAtLeast(8f + itemW) else (x + dx).coerceAtMost(screenW - 8f - itemW)
        HoldSpot(edge, cy, left)
    }
}

/** The circle's size as it grows in: past its size ([spring] 0…1 sets how far), one undershoot, settle. [p] is 0…1 through the entrance. */
fun hubScale(p: Float, spring: Float): Float {
    if (p >= 1f) return 1f
    if (spring <= 0f) return 1f - (1f - p) * (1f - p)                       // a plain ease-out
    val over = 1f + 0.35f * spring; val under = 1f - 0.1f * spring
    fun ease(t: Float) = 1f - (1f - t) * (1f - t)
    return when {
        p < 0.45f -> over * ease(p / 0.45f)
        p < 0.75f -> over + (under - over) * ease((p - 0.45f) / 0.30f)
        else -> under + (1f - under) * ease((p - 0.75f) / 0.25f)
    }
}

/**
 * Draws the hold menu over everything. A filled circle in the track's colour at about 45 % over the page grows exactly under the finger
 * (64 dp at rest, an elastic grow-in); lines 1.5 dp in the track's colour run out from its edge one by one to each choice, each ending in a
 * small node, the lit choice's line white; the choices are the iPad's rows in 48 dp rounded rectangles. Leaving: choices and lines fade in
 * 120 ms and the circle shrinks out faster than it came. Reduce Motion: fades only. TalkBack reads the choices as a plain menu.
 */
@Composable
fun HoldMenuHost(state: HoldMenuState, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val labs = LocalPhoneSettings.current
    val haptic = LocalHapticFeedback.current
    state.tick = { haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
    val density = LocalDensity.current
    // what is drawn: the open menu, or the last one while it leaves
    var shown by remember { mutableStateOf(state.menu) }
    val live = state.menu
    if (live != null) shown = live
    val elapsed = remember { Animatable(0f) }      // ms since it opened, at the Labs speed
    val leave = remember { Animatable(0f) }        // 0…1 as it leaves
    val speed = labs.menuSpeed / 100f
    LaunchedEffect(state.opened) {
        if (state.menu == null) return@LaunchedEffect
        leave.snapTo(0f); elapsed.snapTo(0f)
        unscaled { elapsed.animateTo(1200f, tween((1200 / speed).roundToInt(), easing = LinearEasing)) }
    }
    LaunchedEffect(live == null) {
        if (live == null && shown != null) { unscaled { leave.animateTo(1f, tween(140, easing = LinearEasing)) }; shown = null; state.rects = emptyList() }
    }
    val m = shown ?: return
    BackHandler(enabled = live != null) { state.close() }
    var origin by remember { mutableStateOf<LayoutCoordinates?>(null) }
    BoxWithConstraints(
        modifier.fillMaxSize().onGloballyPositioned { origin = it }
            // the page behind is dimmed and can't be touched; a tap outside the choices closes the menu
            .drawBehind { drawRect(Color.Black.copy(alpha = 0.45f * (1f - leave.value) * (elapsed.value / 150f).coerceAtMost(1f))) }
            .pointerInput(Unit) { detectTapGestures { state.close() } }
            .semantics { paneTitle = "Menu"; isTraversalGroup = true },
    ) {
        val w = maxWidth.value; val h = maxHeight.value
        // the finger, in this layer's dp
        val fingerPx = origin?.takeIf { it.isAttached }?.windowToLocal(m.at) ?: m.at
        val fx = with(density) { fingerPx.x.toDp().value }; val fy = with(density) { fingerPx.y.toDp().value }
        val spots = remember(m, w, h, labs.leftHanded) { holdSpots(fx, fy, m.items.size, w, h, preferLeft = !labs.leftHanded) }
        val itemW = 200f; val itemH = 48f
        // where the choices are, in window pixels, for the held finger
        state.rects = spots.map { s ->
            val l = if (s.left) s.edgeX - itemW else s.edgeX
            val tl = with(density) { Offset(l.dp.toPx(), (s.cy - itemH / 2).dp.toPx()) }
            val win = origin?.takeIf { it.isAttached }?.localToWindow(tl) ?: tl
            with(density) { Rect(win, Size(itemW.dp.toPx(), itemH.dp.toPx())) }
        }
        val fadeAll = 1f - (leave.value / 0.86f).coerceAtMost(1f)   // choices and lines: gone in 120 of the 140 ms
        Canvas(Modifier.fillMaxSize()) {
            val c = Offset(fx.dp.toPx(), fy.dp.toPx())
            // the circle: the track's colour at about 45 % over the page, a thin edge in the full colour; exactly under the finger
            val scale = if (reduce) 1f else hubScale((elapsed.value / 460f).coerceIn(0f, 1f), labs.menuSpring / 100f) * (1f - leave.value)
            val hubA = if (reduce) (elapsed.value / 150f).coerceAtMost(1f) * (1f - leave.value) else 1f
            drawCircle(lerp(Tok.page, m.colour, 0.45f).copy(alpha = hubA), 32.dp.toPx() * scale, c)
            drawCircle(m.colour.copy(alpha = hubA), 32.dp.toPx() * scale, c, style = Stroke(1.5.dp.toPx()))
            spots.forEachIndexed { k, s ->
                val end = Offset(s.edgeX.dp.toPx(), s.cy.dp.toPx())
                val ang = atan2(end.y - c.y, end.x - c.x)
                val start = Offset(c.x + cos(ang) * 32.dp.toPx(), c.y + sin(ang) * 32.dp.toPx())
                val d0 = 160f + k * 30f
                // the line draws out from the circle's edge (with Reduce Motion it only fades in)
                val drawn = if (reduce) 1f else ((elapsed.value - d0) / 180f).coerceIn(0f, 1f).let { 1f - (1f - it) * (1f - it) }
                val a = (if (reduce) (elapsed.value / 150f).coerceAtMost(1f) else 1f) * fadeAll * (if (state.confirming >= 0 && state.confirming != k) 0.3f else 1f)
                val col = if (state.hot == k) Tok.text else m.colour
                if (drawn > 0f) drawLine(col.copy(alpha = a), start, Offset(start.x + (end.x - start.x) * drawn, start.y + (end.y - start.y) * drawn), 1.5.dp.toPx(), StrokeCap.Round)
                val nodeA = (if (reduce) 1f else ((elapsed.value - d0 - 140f) / 120f).coerceIn(0f, 1f)) * a
                if (nodeA > 0f) drawCircle(col.copy(alpha = nodeA), 3.dp.toPx(), end)
            }
        }
        m.items.forEachIndexed { k, item ->
            val s = spots[k]
            val d0 = 160f + k * 30f
            val inP = if (reduce) (elapsed.value / 150f).coerceAtMost(1f) else ((elapsed.value - d0 - 100f) / 220f).coerceIn(0f, 1f).let { 1f - (1f - it) * (1f - it) }
            val confirming = state.confirming == k
            val dimmed = state.confirming >= 0 && !confirming
            Box(
                Modifier.offset { IntOffset(((if (s.left) s.edgeX - itemW else s.edgeX).dp.toPx()).roundToInt(), ((s.cy - itemH / 2).dp.toPx()).roundToInt()) }
                    .width(itemW.dp).height(itemH.dp)
                    .graphicsLayer {
                        alpha = inP * fadeAll * (if (dimmed) 0.3f else 1f)
                        if (!reduce) { translationX = (if (s.left) 10.dp.toPx() else -10.dp.toPx()) * (1f - inP); val sc = 0.96f + 0.04f * inP; scaleX = sc; scaleY = sc }
                    }
                    .drawBehind {
                        val r = CornerRadius(12.dp.toPx())
                        drawRoundRect(if (state.hot == k && !confirming) Tok.lifted else Tok.panel, cornerRadius = r)
                        if (confirming) drawRoundRect(Tok.rec, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(11.dp.toPx()), style = Stroke(2.dp.toPx()))
                        // the edge the line arrives at carries the track's colour
                        else drawRoundRect(m.colour, Offset(if (s.left) size.width - 3.dp.toPx() else 0f, 8.dp.toPx()), Size(3.dp.toPx(), size.height - 16.dp.toPx()), CornerRadius(1.5.dp.toPx()))
                    }
                    .then(if (item.slide != null) Modifier.pointerInput(k, m) { detectTapGestures { } } else Modifier.semantics(mergeDescendants = true) {
                        role = Role.Button
                        contentDescription = if (confirming) "Confirm: ${item.confirm}" else item.title + (item.sub?.let { ", $it" } ?: "")
                        if (item.checked) selected = true
                        if (!item.enabled) disabled()
                        onClick { state.pick(k); true }
                    }
                    .pointerInput(k, m) { detectTapGestures { state.pick(k) } })
                    .padding(start = if (s.left) 14.dp else 16.dp, end = if (s.left) 16.dp else 14.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                // the iPad's row: the title at 17, a small second line, a tick for the current choice; a choice that can't be made is dimmer
                val ink = if (!item.enabled) Tok.text3 else Tok.text
                if (item.slide != null) HoldSlideRow(item.title, item.slide)
                else if (confirming) BasicText(item.confirm.orEmpty(), style = LupeType.key.copy(fontSize = 14.sp, lineHeight = 16.sp), maxLines = 2, overflow = TextOverflow.Ellipsis)
                else Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        BasicText(item.title, style = LupeType.body.copy(fontSize = 17.sp, lineHeight = 20.sp, color = ink), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (item.sub != null) BasicText(item.sub, style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 14.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (item.checked) { Spacer(Modifier.width(8.dp)); Check(Tok.text) }
                    if (item.children != null) { Spacer(Modifier.width(8.dp)); BasicText("›", style = LupeType.key.copy(color = Tok.text2)) }
                }
            }
        }
    }
}

/** A slide row's inside: the name, the value large at the right, a gauge along the foot; a finger slid along it (either way) sets the value. */
@Composable
private fun HoldSlideRow(title: String, sl: HoldSlide) {
    val raw = sl.raw(); val text = sl.text()
    val latest by rememberUpdatedState(raw)
    var base by remember { mutableIntStateOf(0) }
    fun set(v: Int) { val n = v.coerceIn(sl.min, sl.max); if (n != latest) sl.onSet(n) }
    Box(
        Modifier.fillMaxSize()
            .semantics(mergeDescendants = true) {
                contentDescription = title; stateDescription = text; role = Role.Button
                progressBarRangeInfo = androidx.compose.ui.semantics.ProgressBarRangeInfo(raw.toFloat(), sl.min.toFloat()..sl.max.toFloat(), sl.max - sl.min - 1)
                setProgress { v -> set(v.roundToInt()); true }
                customActions = listOf(
                    androidx.compose.ui.semantics.CustomAccessibilityAction("Increase $title") { set(latest + 1); true },
                    androidx.compose.ui.semantics.CustomAccessibilityAction("Decrease $title") { set(latest - 1); true },
                )
            }
            .slideToTurn(enabled = true, stepDp = sl.stepDp, face = null, forceDirection = com.scottgerstl.lupe.ui.slide.SlideDirection.Both,
                onStart = { base = latest }, onSlide = { set(base + it) }, bounds = { (sl.min - latest)..(sl.max - latest) }),
    ) {
        Row(Modifier.align(Alignment.CenterStart).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            BasicText(title, Modifier.weight(1f), style = LupeType.label.copy(color = Tok.text2Raised), maxLines = 1)
            BasicText(text, style = LupeType.number.copy(fontSize = 20.sp, lineHeight = 22.sp), maxLines = 1)
        }
        Canvas(Modifier.align(Alignment.BottomStart).padding(bottom = 5.dp).fillMaxWidth().height(3.dp)) {
            drawRect(Tok.stepEmpty)
            val span = (sl.max - sl.min).coerceAtLeast(1).toFloat()
            val x = (raw - sl.min) / span * size.width
            val from = if (sl.bipolarAt != null) (sl.bipolarAt - sl.min) / span * size.width else 0f
            drawRect(Tok.text, Offset(minOf(from, x), 0f), Size(maxOf(kotlin.math.abs(x - from), if (sl.bipolarAt != null) 2.dp.toPx() else 0f), size.height))
        }
    }
}

/**
 * A tap, or a hold that opens the hold menu exactly under the finger. The hold fires after 0.35 s; while the same finger stays down its place
 * is fed to the menu, so sliding onto a choice and letting go picks it. The tap is taken on the finger lifting anywhere on this thing (no
 * movement limit). [pressed] says when the finger is down, for the press look. A gesture that something else takes (a pan) is neither.
 */
fun Modifier.tapOrHoldMenu(
    key: Any?, colour: Color, items: () -> List<HoldItem>, onTap: () -> Unit, pressed: (Boolean) -> Unit = {}, enabled: Boolean = true,
): Modifier = composed {
    val menu = LocalHoldMenu.current
    val haptic = LocalHapticFeedback.current
    var coords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val tap by rememberUpdatedState(onTap)
    val list by rememberUpdatedState(items)
    val press by rememberUpdatedState(pressed)
    val tint by rememberUpdatedState(colour)
    onGloballyPositioned { coords = it }.pointerInput(key, enabled) {
        if (!enabled) return@pointerInput
        awaitEachGesture {
            val down = awaitFirstDown()
            press(true)
            var cancelled = false
            val up = withTimeoutOrNull(HOLD_MS) { waitForUpOrCancellation().also { if (it == null) cancelled = true } }
            press(false)
            if (cancelled) return@awaitEachGesture
            if (up != null) { tap(); return@awaitEachGesture }
            val c = coords?.takeIf { it.isAttached }
            val choices = list()
            if (menu == null || c == null || choices.isEmpty()) return@awaitEachGesture
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            // exactly under the finger: where the pointer is as the hold fires
            menu.open(c.localToWindow(currentEvent.changes.firstOrNull { it.id == down.id }?.position ?: down.position), tint, choices)
            // the same finger, still down: feed its place to the menu until it lifts
            while (true) {
                val e = awaitPointerEvent()
                val ch = e.changes.firstOrNull { it.id == down.id } ?: break
                ch.consume()
                if (!ch.pressed) { menu.release(); break }
                menu.drag(c.localToWindow(ch.position))
            }
        }
    }
}

/** How long a hold is before its menu opens (the mockup's 0.35 s). */
const val HOLD_MS = 350L

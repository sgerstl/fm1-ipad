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
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.runtime.mutableFloatStateOf
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
import kotlinx.coroutines.launch
import androidx.compose.ui.semantics.clearAndSetSemantics
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
    /** The choice asking to be confirmed, and when it began asking (taps are ignored for 0.4 s). */
    var confirming by mutableIntStateOf(-1)
    var confirmAt = 0L

    fun open(at: Offset, colour: Color, items: List<HoldItem>, title: String? = null) {
        if (items.isEmpty()) return
        menu = HoldMenuOpen(at, colour, items); confirming = -1; opened++
    }
    private fun HoldMenuOpen(at: Offset, colour: Color, items: List<HoldItem>) = HoldMenuOpen(at, colour, items, null)
    fun close() { menu = null; confirming = -1 }

    /** A tap on choice [k] (decision 36: a tap picks; a drag never does, it only turns the wheel). */
    fun pick(k: Int) {
        val m = menu ?: return
        val item = m.items.getOrNull(k) ?: return
        if (!item.enabled || item.slide != null) return   // a slide row is slid, not picked
        when {
            item.children != null -> { menu = HoldMenuOpen(m.at, m.colour, item.children.invoke()); confirming = -1; opened++ }
            item.confirm != null && confirming != k -> { confirming = k; confirmAt = System.currentTimeMillis() }
            item.confirm != null && System.currentTimeMillis() - confirmAt < 400 -> Unit   // the second tap of a quick double tap can't confirm
            else -> { close(); item.action() }
        }
    }

}

val LocalHoldMenu = compositionLocalOf<HoldMenuState?> { null }

/** The circle under the finger is 64 dp across. */
const val HUB_R = 32f
/** Every choice's stalk: 22 dp, from the wheel's rim out to the choice (decision 36). */
const val STALK = 22f

/**
 * One choice's place on the wheel, in dp: its row's top-left corner, its node (where the stalk meets the row's near edge), where its stalk
 * starts on the rim, and how much of it shows ([alpha]: 1 on the arc, falling to 0 past its ends).
 */
class WheelSpot(val rowX: Float, val rowY: Float, val nodeX: Float, val nodeY: Float, val stalkX: Float, val stalkY: Float, val alpha: Float)

/**
 * The hold menu as a wheel (decision 36, Scott's option A; the iPhone's numbers, ios/FM1/RadialMenu.swift at 3ab5e14, pt = dp).
 *
 * The choices (200 × 48, centres 56 apart) have their near edges on a circle of [ARC] 150 round a centre level with the finger: five in
 * view, the middle one furthest out. Each has a 22 dp stalk running in toward that centre, ending on a thin rim of radius 128 that a spoke
 * links back to the circle under the finger. The centre is the finger's height, moved only as far as keeps the whole column between the
 * header (56) and 16 above the foot. With more than five choices it is a wheel: it opens with the first at the arc's top, a drag rolls
 * the choices along the arc, and one fades (and stops taking taps under half) as it passes an end. Five or fewer: no turning, no fade.
 * Side: right-handed, to the left of the finger where the whole reach fits there, or where the right doesn't; left-handed, the mirror.
 */
class HoldWheel(val x: Float, val y: Float, val n: Int, val screenW: Float, val screenH: Float, leftHanded: Boolean = false) {
    val shown: Int = minOf(n, 5)
    private val half = (shown - 1) / 2f * PITCH + ROW_H / 2
    /** The arc's centre height: the finger's, kept so the column stays on the screen. */
    val mid: Float = if (HEADER + half <= screenH - 16f - half) y.coerceIn(HEADER + half, screenH - 16f - half) else y
    val left: Boolean = run {
        val reach = ARC + ROW_W + 8f; val fitsLeft = x - reach >= 0f; val fitsRight = x + reach <= screenW
        if (leftHanded) !(fitsRight || !fitsLeft) else (fitsLeft || !fitsRight)
    }
    /** How far the wheel can turn, in choices; 0 for five or fewer. */
    val maxTurn: Float = (n - 5).coerceAtLeast(0).toFloat()

    /** Choice [k]'s position on the arc: 0 its middle, ±2 its ends, not whole while the wheel turns. */
    fun position(k: Int, turn: Float = 0f): Float = k - turn - (shown - 1) / 2f

    fun spot(p: Float): WheelSpot {
        val cy = mid + p * PITCH
        val dx = sqrt((ARC * ARC - (cy - mid) * (cy - mid)).coerceAtLeast(0f))
        val nodeX = if (left) (x - dx).coerceAtLeast(8f + ROW_W) else (x + dx).coerceAtMost(screenW - 8f - ROW_W)
        // the stalk: 22 dp back from the node toward the arc's centre, so its inner end is on the rim
        val ux = nodeX - x; val uy = cy - mid; val len = sqrt(ux * ux + uy * uy).coerceAtLeast(0.001f)
        val alpha = if (n > 5) (1f - (kotlin.math.abs(p) - 2f) / 0.8f).coerceIn(0f, 1f) else 1f
        return WheelSpot(if (left) nodeX - ROW_W else nodeX, cy - ROW_H / 2, nodeX, cy, nodeX - STALK * ux / len, cy - STALK * uy / len, alpha)
    }
    fun spot(k: Int, turn: Float): WheelSpot = spot(position(k, turn))

    /** Where a drag has the wheel: past either end it gives, at 0.35 of the finger's travel. */
    fun give(turn: Float): Float = when { turn < 0f -> turn * 0.35f; turn > maxTurn -> maxTurn + (turn - maxTurn) * 0.35f; else -> turn }
    /** Where the wheel settles after a drag that would have ended at [turn]: a whole choice, inside its range. */
    fun settle(turn: Float): Float = kotlin.math.round(turn).coerceIn(0f, maxTurn)

    companion object {
        const val ROW_W = 200f
        const val ROW_H = 48f
        const val PITCH = 56f
        /** The choices' near edges are this far from the arc's centre; the rim is a stalk inside that. */
        const val ARC = 150f
        const val RIM = ARC - STALK
        /** Under the header's line. */
        const val HEADER = 56f
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
 * Decision 36 (Scott, 2026-11-14): the menu is a wheel ([HoldWheel]). Five choices in view on an arc 150 dp from its centre, each on a
 * 22 dp stalk from a thin rim that a spoke links back to the circle; a drag rolls the rest along the arc, fading at its ends, and it
 * settles on a whole choice. A tap picks; a drag never does. There is no "More…" page.
 *
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
        if (live == null && shown != null) { unscaled { leave.animateTo(1f, tween(140, easing = LinearEasing)) }; shown = null }
    }
    val m = shown ?: return
    BackHandler(enabled = live != null) { state.close() }
    // From the moment it is told to close it takes no touches, though it is still on screen fading out for 140 ms (the iPhone's cbdc2ad:
    // a hold begun at once after closing went to the leaving menu, so nothing opened). The page underneath gets them.
    val takes = live != null
    var origin by remember { mutableStateOf<LayoutCoordinates?>(null) }
    // how far the wheel is turned, in choices. The geometry is made inside the layout box; the drag on the whole layer reads it from here
    var turn by remember(m) { mutableFloatStateOf(0f) }
    var wheelNow by remember(m) { mutableStateOf<HoldWheel?>(null) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var settling by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    fun settleTo(to: Float) {
        settling?.cancel()
        // 320 ms ease-out cubic, travelling along the curve (every place is recomputed from the turn); with Reduce Motion it is simply there
        settling = scope.launch { if (reduce) turn = to else unscaled { androidx.compose.animation.core.animate(turn, to, animationSpec = tween(320, easing = androidx.compose.animation.core.CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f))) { v, _ -> turn = v } } }
    }
    BoxWithConstraints(
        modifier.fillMaxSize().onGloballyPositioned { origin = it }
            // the page behind is dimmed and can't be touched; a tap outside the choices closes the menu
            .drawBehind { drawRect(Color.Black.copy(alpha = 0.45f * (1f - leave.value) * (elapsed.value / 150f).coerceAtMost(1f))) }
            .then(if (takes) Modifier.pointerInput(Unit) { detectTapGestures { state.close() } } else Modifier)
            // more than five choices: a drag anywhere on the menu rolls them along the arc (56 dp of finger a choice, giving past the ends);
            // let go and it settles on a whole choice, carried on by the finger's speed. A drag never picks: only a tap does.
            .then(if (!takes) Modifier else Modifier.pointerInput(m) {
                val tracker = androidx.compose.ui.input.pointer.util.VelocityTracker()
                var start = 0f; var total = 0f
                detectVerticalDragGestures(
                    onDragStart = { settling?.cancel(); start = turn; total = 0f; tracker.resetTracking() },
                    onDragEnd = {
                        val w = wheelNow
                        if (w != null && w.maxTurn > 0f) { val ahead = total + tracker.calculateVelocity().y * 0.2f; settleTo(w.settle(start - ahead.toDp().value / HoldWheel.PITCH)) }
                    },
                    onDragCancel = { wheelNow?.let { settleTo(it.settle(turn)) } },
                ) { change, dy ->
                    val w = wheelNow
                    if (w != null && w.maxTurn > 0f) { change.consume(); tracker.addPosition(change.uptimeMillis, change.position); total += dy; turn = w.give(start - total.toDp().value / HoldWheel.PITCH) }
                }
            })
            .semantics {
                paneTitle = "Menu"; isTraversalGroup = true
                // the way to the rest of the wheel that isn't a drag (WCAG 2.5.7)
                val w = wheelNow
                if (w != null && w.maxTurn > 0f) customActions = listOf(
                    androidx.compose.ui.semantics.CustomAccessibilityAction("Later choices") { turn = w.settle(turn + 5f); true },
                    androidx.compose.ui.semantics.CustomAccessibilityAction("Earlier choices") { turn = w.settle(turn - 5f); true },
                )
            },
    ) {
        val w = maxWidth.value; val h = maxHeight.value
        // the finger, in this layer's dp
        val fingerPx = origin?.takeIf { it.isAttached }?.windowToLocal(m.at) ?: m.at
        val fx = with(density) { fingerPx.x.toDp().value }; val fy = with(density) { fingerPx.y.toDp().value }
        val wheel = remember(m, w, h, fx, fy, labs.leftHanded) { HoldWheel(fx, fy, m.items.size, w, h, leftHanded = labs.leftHanded) }
        wheelNow = wheel
        val spots = List(m.items.size) { wheel.spot(it, turn) }
        val itemW = HoldWheel.ROW_W; val itemH = HoldWheel.ROW_H
        val fadeAll = 1f - (leave.value / 0.86f).coerceAtMost(1f)   // choices and lines: gone in 120 of the 140 ms
        Canvas(Modifier.fillMaxSize()) {
            val c = Offset(fx.dp.toPx(), fy.dp.toPx())
            // the circle: the track's colour at about 45 % over the page, a thin edge in the full colour; exactly under the finger
            val scale = if (reduce) 1f else hubScale((elapsed.value / 460f).coerceIn(0f, 1f), labs.menuSpring / 100f) * (1f - leave.value)
            val hubA = if (reduce) (elapsed.value / 150f).coerceAtMost(1f) * (1f - leave.value) else 1f
            drawCircle(lerp(Tok.page, m.colour, 0.45f).copy(alpha = hubA), 32.dp.toPx() * scale, c)
            drawCircle(m.colour.copy(alpha = hubA), 32.dp.toPx() * scale, c, style = Stroke(1.5.dp.toPx()))
            // the wheel's rim: a thin arc in the track's colour, a stalk inside the choices, over ±70° of the open side; and one spoke from
            // the circle's edge out to the rim's middle. Both grow in from 100 ms over 260 (the sweep opening, the radius from 0.9)
            val grow = if (reduce) 1f else ((elapsed.value - 100f) / 260f).coerceIn(0f, 1f).let { 1f - (1f - it) * (1f - it) }
            val rimA = 0.55f * fadeAll * (if (reduce) (elapsed.value / 150f).coerceAtMost(1f) else 1f)
            if (grow > 0f && rimA > 0f) {
                val cc = Offset(fx.dp.toPx(), wheel.mid.dp.toPx())
                val rr = HoldWheel.RIM.dp.toPx() * (0.9f + 0.1f * grow)
                drawArc(m.colour.copy(alpha = rimA), (if (wheel.left) 180f else 0f) - 70f * grow, 140f * grow, false, Offset(cc.x - rr, cc.y - rr), Size(rr * 2, rr * 2), style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round))
                val rimMid = Offset(cc.x + (if (wheel.left) -1f else 1f) * HoldWheel.RIM.dp.toPx(), cc.y)
                val ang = atan2(rimMid.y - c.y, rimMid.x - c.x)
                val from = Offset(c.x + cos(ang) * HUB_R.dp.toPx(), c.y + sin(ang) * HUB_R.dp.toPx())
                drawLine(m.colour.copy(alpha = rimA), from, Offset(from.x + (rimMid.x - from.x) * grow, from.y + (rimMid.y - from.y) * grow), 1.5.dp.toPx(), StrokeCap.Round)
            }
            spots.forEachIndexed { k, s ->
                val vis = s.alpha
                if (vis <= 0f) return@forEachIndexed
                // the stalk: 22 dp from the rim out to the choice's node
                val start = Offset(s.stalkX.dp.toPx(), s.stalkY.dp.toPx()); val end = Offset(s.nodeX.dp.toPx(), s.nodeY.dp.toPx())
                val d0 = 160f + (k - kotlin.math.floor(turn)).coerceIn(0f, 7f) * 30f
                // it draws out from the rim (with Reduce Motion it only fades in)
                val drawn = if (reduce) 1f else ((elapsed.value - d0) / 180f).coerceIn(0f, 1f).let { 1f - (1f - it) * (1f - it) }
                val a = (if (reduce) (elapsed.value / 150f).coerceAtMost(1f) else 1f) * fadeAll * vis * (if (state.confirming >= 0 && state.confirming != k) 0.3f else 1f)
                if (drawn > 0f) drawLine(m.colour.copy(alpha = a), start, Offset(start.x + (end.x - start.x) * drawn, start.y + (end.y - start.y) * drawn), 1.5.dp.toPx(), StrokeCap.Round)
                val nodeA = (if (reduce) 1f else ((elapsed.value - d0 - 140f) / 120f).coerceIn(0f, 1f)) * a
                if (nodeA > 0f) drawCircle(m.colour.copy(alpha = nodeA), 3.dp.toPx(), end)
            }
        }
        m.items.forEachIndexed { k, item ->
            val s = spots[k]
            // a choice under half shown isn't there (to a finger or to TalkBack's focus); past the arc's end it fades and shrinks a little
            val vis = s.alpha
            if (vis <= 0f) return@forEachIndexed
            val d0 = 160f + (k - kotlin.math.floor(turn)).coerceIn(0f, 7f) * 30f
            val inP = if (reduce) (elapsed.value / 150f).coerceAtMost(1f) else ((elapsed.value - d0 - 100f) / 220f).coerceIn(0f, 1f).let { 1f - (1f - it) * (1f - it) }
            val confirming = state.confirming == k
            val dimmed = state.confirming >= 0 && !confirming
            Box(
                Modifier.offset { IntOffset((s.rowX.dp.toPx()).roundToInt(), (s.rowY.dp.toPx()).roundToInt()) }
                    .width(itemW.dp).height(itemH.dp)
                    .graphicsLayer {
                        alpha = inP * fadeAll * vis * (if (dimmed) 0.3f else 1f)
                        if (!reduce) { translationX = (if (wheel.left) 10.dp.toPx() else -10.dp.toPx()) * (1f - inP); val sc = (0.96f + 0.04f * inP) * (0.9f + 0.1f * vis); scaleX = sc; scaleY = sc }
                    }
                    .drawBehind {
                        val r = CornerRadius(12.dp.toPx())
                        drawRoundRect(Tok.panel, cornerRadius = r)
                        if (confirming) drawRoundRect(Tok.rec, Offset(1.dp.toPx(), 1.dp.toPx()), Size(size.width - 2.dp.toPx(), size.height - 2.dp.toPx()), CornerRadius(11.dp.toPx()), style = Stroke(2.dp.toPx()))
                        // the edge the line arrives at carries the track's colour
                        else drawRoundRect(m.colour, Offset(if (wheel.left) size.width - 3.dp.toPx() else 0f, 8.dp.toPx()), Size(3.dp.toPx(), size.height - 16.dp.toPx()), CornerRadius(1.5.dp.toPx()))
                    }
                    .then(if (vis < 0.5f || !takes) Modifier.clearAndSetSemantics { } else if (item.slide != null) Modifier.pointerInput(k, m) { detectTapGestures { } } else Modifier.semantics(mergeDescendants = true) {
                        role = Role.Button
                        contentDescription = if (confirming) "Confirm: ${item.confirm}" else item.title + (item.sub?.let { ", $it" } ?: "")
                        if (item.checked) selected = true
                        if (!item.enabled) disabled()
                        onClick { state.pick(k); true }
                    }
                    .pointerInput(k, m) { detectTapGestures { state.pick(k) } })
                    .padding(start = if (wheel.left) 14.dp else 16.dp, end = if (wheel.left) 16.dp else 14.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                // the iPad's row: the title at 17, a small second line, a tick for the current choice; a choice that can't be made is dimmer
                val ink = if (!item.enabled) Tok.text3 else Tok.text
                if (item.slide != null) HoldSlideRow(item.title, item.slide, takes)
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
private fun HoldSlideRow(title: String, sl: HoldSlide, enabled: Boolean = true) {
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
            .slideToTurn(enabled = enabled, stepDp = sl.stepDp, face = null, forceDirection = com.scottgerstl.lupe.ui.slide.SlideDirection.Sideways,   // along the row only: up and down is the column's scroll
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
 * A tap, or a hold that opens the hold menu exactly under the finger. The hold fires after 0.35 s; the choices are then picked by a tap. The tap is taken on the finger lifting anywhere on this thing (no
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
            // the same finger, still down, does nothing more (decision 36: a tap picks; sliding onto a choice and letting go does not):
            // its moves are swallowed until it lifts, so nothing under it sees them
            while (true) {
                val e = awaitPointerEvent()
                val ch = e.changes.firstOrNull { it.id == down.id } ?: break
                ch.consume()
                if (!ch.pressed) break
            }
        }
    }
}

/** How long a hold is before its menu opens (the mockup's 0.35 s). */
const val HOLD_MS = 350L

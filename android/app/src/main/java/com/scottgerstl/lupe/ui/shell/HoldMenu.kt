package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.shape.RoundedCornerShape

import androidx.compose.ui.draw.clip

import androidx.compose.foundation.verticalScroll

import androidx.compose.foundation.layout.heightIn

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
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.Image
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
import androidx.compose.ui.unit.em
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
 * The hold menu as a wheel (decision 36, Scott's option A with his tuning; the iPhone's final numbers, ios/FM1/RadialMenu.swift at
 * 4386982, pt = dp).
 *
 * The choices (200 × 48, centres 56 apart, up to five in view) have their near edges on a shallow curve: a circle of radius [CURVE] 400
 * whose middle point is [NEAR] 76 from the finger, so across the five the ends come in only about 16. Each has a 22 dp stalk running in
 * toward the curve's centre, ending on a thin rim (radius 378). Nothing joins the rim to the circle under the finger. The curve's middle
 * height is the finger's, moved only as far as keeps the whole column between the header (56) and 16 above the foot. With more than five
 * it is a wheel: it opens on the first choice, a drag rolls the choices along the curve, one fades (and stops taking taps under half) as
 * it passes an end, and a small triangle past each end of the rim says there is more that way, blending out as that end is reached.
 * Side: away from the playing hand (left for right-handed) wherever the press is, flipping only when there isn't room.
 */
class HoldWheel(val x: Float, val y: Float, val n: Int, val screenW: Float, val screenH: Float, leftHanded: Boolean = false) {
    /**
     * How many whole choices the column shows (iPhone 3205327): five, or more when the usable height (header to 8 above the foot, less the triangles' room) holds
     * more at the 56 pitch. A menu with no more choices than that fits and stays level with the finger; one with more spans the full usable height and rolls.
     */
    private val fullHalf: Float = (screenH - 8f - HEADER) / 2f - (TRI_GAP + TRI_H)
    private val cap: Int = maxOf(5, ((2f * fullHalf - ROW_H) / PITCH).toInt() + 1)
    /** True when the column is the full height and the wheel rolls. */
    val spans: Boolean = n > cap
    val shown: Int = if (spans) cap else n
    /** From the curve's middle height to the outer edge of its top or bottom choice. */
    val reachY: Float = if (spans) fullHalf else (shown - 1) / 2f * PITCH + ROW_H / 2
    /** …and, on a wheel, the triangle past it (an 8 gap and its 7 height). */
    private val half = reachY + if (spans) TRI_GAP + TRI_H else 0f
    /** The curve's middle height: the finger's, kept so the column stays on the screen; a full-height column is centred between the header and 8 above the foot. */
    val mid: Float = if (spans) (HEADER + screenH - 8f) / 2f else if (HEADER + half <= screenH - 16f - half) y.coerceIn(HEADER + half, screenH - 16f - half) else y
    /**
     * The room beside the finger on each side for a 200 wide row and an 8 margin, in the menu layer's own coordinates. The layer is the
     * whole screen, edge to edge (under the camera cutout and the system bars), so these are the physical edges: a menu may run into the
     * safe-area margins (iPhone d0797f9), and the page dim covers them too.
     */
    private val roomLeft = x - 8f - ROW_W
    private val roomRight = screenW - 8f - ROW_W - x
    /**
     * The side it opens on (iPhone b565310, replacing the reach rule): the side away from the playing hand (left for right-handed) wherever
     * the press is, if there is room for the stalk and the hub there ([MIN_NEAR] 54); else the other side if it has; else the roomier one.
     */
    val left: Boolean = run {
        val away = if (leftHanded) roomRight else roomLeft; val other = if (leftHanded) roomLeft else roomRight
        val awayIsLeft = !leftHanded
        when { away >= MIN_NEAR -> awayIsLeft; other >= MIN_NEAR -> !awayIsLeft; else -> roomLeft > roomRight }
    }
    private val side = if (left) -1f else 1f
    /** How far the middle choice's near edge is from the finger: 76, coming in to as little as 54 near an edge rather than flipping. */
    val near: Float = (if (left) roomLeft else roomRight).coerceIn(MIN_NEAR, NEAR)
    /** The curve's centre: far behind the finger, on the side the choices are not. */
    val centreX: Float = x + side * (near - CURVE)
    /** How far the wheel can turn, in choices; 0 for five or fewer. */
    val maxTurn: Float = (n - shown).coerceAtLeast(0).toFloat()

    /** Choice [k]'s position on the curve: 0 its middle, ±2 its ends, not whole while the wheel turns. */
    fun position(k: Int, turn: Float = 0f): Float = k - turn - (shown - 1) / 2f

    fun spot(p: Float): WheelSpot {
        val cy = mid + p * PITCH
        val dx = sqrt((CURVE * CURVE - (cy - mid) * (cy - mid)).coerceAtLeast(0f))
        val nodeX = if (left) (centreX - dx).coerceAtLeast(8f + ROW_W) else (centreX + dx).coerceAtMost(screenW - 8f - ROW_W)
        // the stalk: 22 dp back from the node toward the curve's centre, so its inner end is on the rim
        val ux = nodeX - centreX; val uy = cy - mid; val len = sqrt(ux * ux + uy * uy).coerceAtLeast(0.001f)
        val alpha = if (spans) (1f - (kotlin.math.abs(p) - (shown - 1) / 2f) / 0.8f).coerceIn(0f, 1f) else 1f
        return WheelSpot(if (left) nodeX - ROW_W else nodeX, cy - ROW_H / 2, nodeX, cy, nodeX - STALK * ux / len, cy - STALK * uy / len, alpha)
    }
    fun spot(k: Int, turn: Float): WheelSpot = spot(position(k, turn))

    /** The black field's half height: the reach to the outer edge of the top and bottom choices (and the triangles' room on a wheel), plus 14. */
    val fieldHalf: Float = half + FIELD_PAD
    /** The field's inner and outer arcs reach this far either side of level, in degrees. */
    val fieldInnerSweep: Float = Math.toDegrees(kotlin.math.asin((fieldHalf / FIELD_INNER).coerceIn(-1f, 1f)).toDouble()).toFloat()
    val fieldOuterSweep: Float = Math.toDegrees(kotlin.math.asin((fieldHalf / FIELD_OUTER).coerceIn(-1f, 1f)).toDouble()).toFloat()

    /** The rim reaches this far either side of level, in degrees: to the outer edge of the top and bottom choices. */
    val rimHalfSweep: Float = Math.toDegrees(kotlin.math.asin((reachY / RIM).coerceIn(-1f, 1f)).toDouble()).toFloat()

    /** The middle of a triangle's base: on the rim's curve, 8 past its end, above ([up]) or below. Its tip is 7 further out. */
    fun triangle(up: Boolean): Pair<Float, Float> {
        val dy = reachY + TRI_GAP
        return (centreX + side * sqrt((RIM * RIM - dy * dy).coerceAtLeast(0f))) to (mid + if (up) -dy else dy)
    }
    /** How much of each triangle shows: the upper one once there are choices before the first in view, the lower while there are more after; none at five or fewer. */
    fun moreAbove(turn: Float): Float = if (spans) (turn / 0.5f).coerceIn(0f, 1f) else 0f
    fun moreBelow(turn: Float): Float = if (spans) ((n - shown - turn) / 0.5f).coerceIn(0f, 1f) else 0f

    /** Where a drag has the wheel: past either end it gives, at 0.35 of the finger's travel. */
    fun give(turn: Float): Float = when { turn < 0f -> turn * 0.35f; turn > maxTurn -> maxTurn + (turn - maxTurn) * 0.35f; else -> turn }
    /** Where the wheel settles after a drag that would have ended at [turn]: a whole choice, inside its range. */
    fun settle(turn: Float): Float = kotlin.math.round(turn).coerceIn(0f, maxTurn)

    companion object {
        const val ROW_W = 200f
        const val ROW_H = 48f
        const val PITCH = 56f
        /** The middle choice's near edge is this far from the finger (less near an edge, to [MIN_NEAR])… */
        const val NEAR = 76f
        /** …at the least the hub (32) and a stalk (22). */
        const val MIN_NEAR = 54f
        /** …on a curve of this radius (shallow: nearly a straight column), with the rim a stalk inside it. */
        const val CURVE = 400f
        const val RIM = CURVE - STALK
        /** The black field behind the arc, a backing (iPhone d0797f9): 12 inside the rim and 12 past the rows, 14 past the top and bottom choices, 53 %, feathered 8. */
        const val FIELD_INNER = RIM - 12f
        const val FIELD_OUTER = CURVE + ROW_W + 12f
        const val FIELD_PAD = 14f
        const val FIELD_ALPHA = 0.53f
        const val FIELD_FEATHER = 8f
        /** Under the header's line. */
        const val HEADER = 56f
        /** The more-to-come triangles: 10 wide, 7 tall, 8 past the rim's end. */
        const val TRI_W = 10f
        const val TRI_H = 7f
        const val TRI_GAP = 8f
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
 * The hold menu, straight (Scott, 2026-11-17, on the Pixel: "let's adopt the material menu, and not the arc menu"; spec 3.9,
 * `phone-04-pads-hold-menu`). It replaces decision 36's wheel on Android ([HoldWheel] stays for its tests and the iPhone's reference).
 *
 * A touch disc (56, `text` at 18 %) grows from half its size exactly under the finger. Beside it a `held` card at radius 14 (elevation 3, 6
 * inside) holds the choices as rows 44 tall (52 with a second line) at radius 10: an icon in grey, the label, its second line in
 * `textSecondaryRaised`, a tick on the current choice (the row a `lifted` pill), a chevron on one that opens more. The card opens on the side
 * Settings › Menus open names, flipping when there's no room, its first row level with the finger, kept between the header and the foot; a
 * long list scrolls. It slides 16 out from the finger, grows from 0.94 and fades in on the spring, its rows fading in 20 ms apart; it leaves in
 * 120 ms. A tap picks; a drag never does (decision 36's rule stays). A confirm turns its row into a red-edged row naming what goes, the others
 * dim. The page isn't dimmed; a tap outside closes it. Reduce Motion: it fades in and out where it stands. TalkBack reads a plain menu.
 */
@Composable
fun HoldMenuHost(state: HoldMenuState, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val labs = LocalPhoneSettings.current
    val hm = com.scottgerstl.lupe.ui.theme.hybridMotion
    val density = LocalDensity.current
    var shown by remember { mutableStateOf(state.menu) }
    val live = state.menu
    if (live != null) shown = live
    val enter = remember { Animatable(0f) }     // 0…1 on the spring (Reduce Motion: eased)
    val clock = remember { Animatable(0f) }     // ms since it opened, for the rows' stagger
    val leave = remember { Animatable(0f) }     // 0…1 as it leaves
    LaunchedEffect(state.opened) {
        if (state.menu == null) return@LaunchedEffect
        leave.snapTo(0f); enter.snapTo(0f); clock.snapTo(0f)
        kotlinx.coroutines.coroutineScope {
            launch { unscaled { enter.animateTo(1f, if (reduce) tween(150, easing = com.scottgerstl.lupe.ui.theme.EaseOut) else com.scottgerstl.lupe.ui.theme.lupeSpring(hm.fingerMs, hm.bounce)) } }
            launch { unscaled { clock.animateTo(600f, tween(600, easing = LinearEasing)) } }
        }
    }
    LaunchedEffect(live == null) {
        if (live == null && shown != null) { unscaled { leave.animateTo(1f, tween(120, easing = com.scottgerstl.lupe.ui.theme.EaseIn)) }; shown = null }
    }
    val m = shown ?: return
    BackHandler(enabled = live != null) { state.close() }
    val takes = live != null
    var origin by remember { mutableStateOf<LayoutCoordinates?>(null) }
    BoxWithConstraints(
        modifier.fillMaxSize().onGloballyPositioned { origin = it }
            .then(if (takes) Modifier.pointerInput(Unit) { detectTapGestures { state.close() } } else Modifier)
            .semantics { paneTitle = "Menu"; isTraversalGroup = true },
    ) {
        val w = maxWidth.value; val h = maxHeight.value
        val fingerPx = origin?.takeIf { it.isAttached }?.windowToLocal(m.at) ?: m.at
        val fx = with(density) { fingerPx.x.toDp().value }; val fy = with(density) { fingerPx.y.toDp().value }
        val out = 1f - leave.value
        // the touch disc under the finger
        Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            val k = if (reduce) 1f else (0.5f + 0.5f * enter.value) * (1f - 0.3f * leave.value)
            val a = (if (reduce) enter.value else 1f) * out
            drawCircle(Tok.text.copy(alpha = 0.18f * a), (STRAIGHT_DISC / 2).dp.toPx() * k, Offset(fx.dp.toPx(), fy.dp.toPx()))
        }
        val place = straightMenuPlace(fx, fy, w, h, menuHeight(m.items), labs.menusRight)
        val maxH = (h - HEADER_FOOT - 16f).coerceAtLeast(120f)
        Column(
            Modifier.offset { IntOffset(place.x.dp.roundToPx(), place.y.dp.roundToPx()) }
                .width(STRAIGHT_W.dp).heightIn(max = maxH.dp)
                .graphicsLayer {
                    alpha = (if (reduce) enter.value else enter.value.coerceIn(0f, 1f)) * out
                    if (!reduce) {
                        val sc = (0.94f + 0.06f * enter.value) * (1f - 0.04f * leave.value)
                        scaleX = sc; scaleY = sc
                        translationX = (if (place.left) 16.dp.toPx() else -16.dp.toPx()) * (1f - enter.value)
                        transformOrigin = androidx.compose.ui.graphics.TransformOrigin(if (place.left) 1f else 0f, ((fy - place.y) / menuHeight(m.items).coerceAtLeast(1f)).coerceIn(0f, 1f))
                    }
                    shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(com.scottgerstl.lupe.ui.theme.Shape.panel); clip = true
                    ambientShadowColor = Color.Black; spotShadowColor = Color.Black
                }
                .background(Tok.held)
                .pointerInput(m) { detectTapGestures { } }   // a tap on the card's padding doesn't close it
                .verticalScroll(androidx.compose.foundation.rememberScrollState())
                .padding(6.dp),
        ) {
            m.items.forEachIndexed { k, item ->
                val confirming = state.confirming == k
                val dimmed = state.confirming >= 0 && !confirming
                // each row fades in 20 ms after the one above it
                val rowIn = if (reduce) 1f else ((clock.value - 20f * k) / 120f).coerceIn(0f, 1f)
                val rowH = if (item.sub != null || item.slide != null || confirming) 52.dp else 44.dp
                Row(
                    Modifier.fillMaxWidth().heightIn(min = rowH)
                        .graphicsLayer { alpha = rowIn * (if (dimmed) 0.4f else 1f) }
                        .clip(RoundedCornerShape(if (item.checked) rowH / 2 else 10.dp))
                        .background(if (item.checked) Tok.lifted else Color.Transparent)
                        .drawBehind { if (confirming) drawRoundRect(Tok.rec, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(10.dp.toPx()), style = Stroke(1.5.dp.toPx())) }
                        .then(if (!takes) Modifier.clearAndSetSemantics { } else if (item.slide != null) Modifier else Modifier.semantics(mergeDescendants = true) {
                            role = Role.Button
                            contentDescription = if (confirming) "Confirm: ${item.confirm}" else item.title + (item.sub?.let { ", $it" } ?: "")
                            if (item.checked) selected = true
                            if (!item.enabled) disabled()
                            onClick { state.pick(k); true }
                        }.pointerInput(k, m) { detectTapGestures { state.pick(k) } })
                        .padding(horizontal = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val ink = if (!item.enabled) Tok.text3 else Tok.text
                    Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) {
                        holdIcon(item.title)?.let { Image(androidx.compose.ui.res.painterResource(it), null, Modifier.size(20.dp), colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(if (item.enabled) Tok.text2Raised else Tok.text3)) }
                    }
                    Spacer(Modifier.width(12.dp))
                    if (item.slide != null) Box(Modifier.weight(1f).height(rowH)) { HoldSlideRow(item.title, item.slide, takes) }
                    else if (confirming) BasicText(item.confirm.orEmpty(), Modifier.weight(1f), style = LupeType.key.copy(fontSize = 14.sp, lineHeight = 1.15.em, color = Tok.rec), maxLines = 3, overflow = TextOverflow.Ellipsis,
                        autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 14.sp, stepSize = 1.sp))
                    else {
                        Column(Modifier.weight(1f)) {
                            BasicText(item.title, style = LupeType.body.copy(fontSize = 16.sp, lineHeight = 1.15.em, color = ink), maxLines = 1, overflow = TextOverflow.Ellipsis,
                                autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 12.sp, maxFontSize = 16.sp, stepSize = 1.sp))
                            if (item.sub != null) BasicText(item.sub, style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 1.15.em, color = Tok.text2Raised), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        if (item.checked) { Spacer(Modifier.width(8.dp)); Check(Tok.text) }
                        if (item.children != null) { Spacer(Modifier.width(8.dp)); BasicText("›", style = LupeType.key.copy(fontSize = 18.sp, color = Tok.text2Raised)) }
                    }
                }
            }
        }
    }
}

/** The straight menu's measures (dp): the card's width, the touch disc, the header's foot it stays under. */
const val STRAIGHT_W = 264f
const val STRAIGHT_DISC = 56f
const val HEADER_FOOT = 60f
/** How far the card's near edge sits from the finger: past the touch disc's edge with a gap. */
const val STRAIGHT_GAP = 36f

/** The card's height for these choices (dp): 6 inside top and foot, rows 44, or 52 with a second line or a slider. */
fun menuHeight(items: List<HoldItem>): Float = 12f + items.sumOf { (if (it.sub != null || it.slide != null) 52 else 44).toInt() }.toFloat()

/** Where the card goes: its top-left (dp) and whether it opens to the finger's left. */
data class StraightPlace(val x: Float, val y: Float, val left: Boolean)

/**
 * Beside the finger: to its left unless [menusRight] (Settings › Menus open), flipping to the other side when there's no room; its first row
 * level with the finger (the row's middle 28 below the card's top); held between the header's foot and 16 above the screen's foot. A card
 * taller than that room starts at the header and scrolls.
 */
fun straightMenuPlace(fx: Float, fy: Float, screenW: Float, screenH: Float, menuH: Float, menusRight: Boolean, margin: Float = 16f): StraightPlace {
    val leftX = fx - STRAIGHT_GAP - STRAIGHT_W
    val rightX = fx + STRAIGHT_GAP
    val fitsLeft = leftX >= margin; val fitsRight = rightX + STRAIGHT_W <= screenW - margin
    val left = if (menusRight) !fitsRight && fitsLeft else fitsLeft || !fitsRight
    val x = (if (left) leftX else rightX).coerceIn(margin, (screenW - margin - STRAIGHT_W).coerceAtLeast(margin))
    val room = screenH - HEADER_FOOT - margin
    val y = if (menuH >= room) HEADER_FOOT else (fy - 28f).coerceIn(HEADER_FOOT, screenH - margin - menuH)
    return StraightPlace(x, y, left)
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
    /** Something that can be picked up and carried (a pad): press then slide lifts it at once with no menu; a still hold opens the menu, and moving off the hold closes it and lifts. */
    dragger: PadDragger? = null,
): Modifier = composed {
    val labs = LocalPhoneSettings.current
    val carry by rememberUpdatedState(dragger)
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
            var lifted = false
            val up = if (carry == null) withTimeoutOrNull(HOLD_MS) { waitForUpOrCancellation().also { if (it == null) cancelled = true } }
            else withTimeoutOrNull(HOLD_MS) {
                // watch the finger: lifting is a tap; sliding past the slop is a lift (after the dwell) or a swipe (before it: the row scrolls)
                val slop = labs.padSlideStart.dp.toPx()
                while (true) {
                    val ev = awaitPointerEvent()
                    val ch = ev.changes.firstOrNull { it.id == down.id }
                    if (ch == null || ch.isConsumed) { cancelled = true; return@withTimeoutOrNull null }
                    if (!ch.pressed) return@withTimeoutOrNull ch
                    when (liftsOrSwipes((ch.position - down.position).getDistance(), slop, ch.uptimeMillis - down.uptimeMillis, labs.padSlideDwellMs.toLong())) {
                        true -> { lifted = true; return@withTimeoutOrNull null }
                        false -> { cancelled = true; return@withTimeoutOrNull null }
                        null -> Unit
                    }
                }
                @Suppress("UNREACHABLE_CODE") null
            }
            press(false)
            if (lifted) {
                val c0 = coords?.takeIf { it.isAttached } ?: return@awaitEachGesture
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                carryOn(down, c0, carry)
                return@awaitEachGesture
            }
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
            val slop = labs.padSlideStart.dp.toPx()
            val holdAt = currentEvent.changes.firstOrNull { it.id == down.id }?.position ?: down.position
            while (true) {
                val e = awaitPointerEvent()
                val ch = e.changes.firstOrNull { it.id == down.id } ?: break
                ch.consume()
                if (!ch.pressed) break
                // held, then moved off the hold: the menu goes and the pad lifts and follows the finger
                if (carry != null && (ch.position - holdAt).getDistance() > slop) {
                    menu.close()
                    carryOn(down, c, carry, startedAt = ch.position)
                    break
                }
            }
        }
    }
}

/** The carried thing follows the finger until it lifts: [PadDragger.lift], each move, then [PadDragger.drop] (or [PadDragger.cancel] if the gesture is taken away). */
private suspend fun androidx.compose.ui.input.pointer.AwaitPointerEventScope.carryOn(
    down: androidx.compose.ui.input.pointer.PointerInputChange, c: LayoutCoordinates, dragger: PadDragger?, startedAt: Offset = down.position,
) {
    if (dragger == null) return
    dragger.lift(c.localToWindow(startedAt), down.position)
    var done = false
    try {
        while (true) {
            val e = awaitPointerEvent()
            val ch = e.changes.firstOrNull { it.id == down.id } ?: break
            ch.consume()
            val at = c.localToWindow(ch.position)
            if (!ch.pressed) { done = true; dragger.drop(at); break }
            dragger.move(at)
        }
    } finally { if (!done) dragger.cancel() }
}

/** How long a hold is before its menu opens (the mockup's 0.35 s). */
const val HOLD_MS = 350L

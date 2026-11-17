package com.scottgerstl.lupe.ui.shell

import androidx.compose.ui.text.font.FontWeight

import androidx.compose.foundation.layout.Arrangement

import androidx.compose.foundation.interaction.collectIsPressedAsState

import androidx.compose.foundation.clickable

import androidx.compose.animation.animateContentSize

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
    /**
     * Priority tiles (Scott, 2026-11-17, "C: priority tiles"): one of the menu's three most-used actions, shown as a big tile across the top,
     * labelled [short] (the title if null) with [tileSub] under it.
     */
    val tile: Boolean = false, val short: String? = null, val tileSub: String? = null,
    /** The row group it sits in when stopped: "Playback", "Arrange", "Remove"… Consecutive items of one group share a rounded surface. */
    val group: String? = null,
    /** It waits for Stop right now (Skiff rewrites a list only while stopped): folded into the one "N more after Stop" row while playing. */
    val afterStop: Boolean = false,
    /** One of a set of short values (the pattern's lengths): drawn as a pill in a grid of [PILLS_ACROSS] inside its group, [checked] is the current one. */
    val pill: Boolean = false,
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

    /** What rebuilds the open menu's choices (round 5): when the transport starts or stops with it open, its layout changes in place. */
    private var builder: (() -> List<HoldItem>)? = null

    fun open(at: Offset, colour: Color, items: List<HoldItem>, title: String? = null, live: (() -> List<HoldItem>)? = null) {
        if (items.isEmpty()) return
        builder = live
        menu = HoldMenuOpen(at, colour, items); confirming = -1; opened++
    }

    /** Rebuilds the open menu's choices from its builder (the transport changed); nothing when it has none or is shut. */
    fun refresh() {
        val m = menu ?: return
        val b = builder ?: return
        val items = b().ifEmpty { return }
        menu = HoldMenuOpen(m.at, m.colour, items); confirming = -1
    }
    private fun HoldMenuOpen(at: Offset, colour: Color, items: List<HoldItem>) = HoldMenuOpen(at, colour, items, null)
    fun close() { menu = null; confirming = -1; builder = null }

    /** A tap on choice [k] (decision 36: a tap picks; a drag never does, it only turns the wheel). */
    fun pick(k: Int) {
        val m = menu ?: return
        val item = m.items.getOrNull(k) ?: return
        if (!item.enabled || item.slide != null) return   // a slide row is slid, not picked
        when {
            item.children != null -> { builder = null; menu = HoldMenuOpen(m.at, m.colour, item.children.invoke()); confirming = -1; opened++ }
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
 * The hold menu as priority tiles (Scott, 2026-11-17: "C: priority tiles"; spec 3.9; vault `fm1-ipad/assets/hold-menu-hybrid-2026-11-17/` and
 * `build-gaps-2026-11-17/` 2a–2f, 3). Under a touch disc at the finger: the menu's three most-used actions as tiles (96 × 84, `held`, radius 18,
 * 4 apart), then what's available now as rows in rounded `held` groups (radius 16, 4 apart, rows 44 or 52). Playing: what waits for Stop folds
 * into "N more after Stop", which unfolds in place, dimmed. Stopped: Playback, Arrange and Remove groups, two columns when taller than the screen
 * minus 24. Never scrolls; 12 from every edge; the Menus open side; a tap picks.
 *
 * Every tile, group and row is placed from [menuGeometry] and animated by its key (round 5, `3-menu-layout-switch.mp4`): when the transport
 * starts or stops with the menu open ([playing]) the choices rebuild. The tiles never move; what waits for Stop folds away (fade, 0.94, 24 to
 * the left, 120 ms ease-in, 20 ms apart); what stays travels to its new place on a spring (bounce 0.25, about 360 ms), changing size and corner
 * on the way; the after-Stop row arrives last (from 0.94 and 12 up, spring, fade 150 ms). Back the other way: it leaves first, the rest travel
 * back and the groups come in. The menu keeps its finger-side edge. Unfolding moves things the same way. Reduce Motion: 150 ms cross-fades.
 */
@Composable
fun HoldMenuHost(state: HoldMenuState, modifier: Modifier = Modifier, playing: Boolean = false) {
    val reduce = LocalReduceMotion.current
    val labs = LocalPhoneSettings.current
    val hm = com.scottgerstl.lupe.ui.theme.hybridMotion
    val density = LocalDensity.current
    var shown by remember { mutableStateOf(state.menu) }
    val live = state.menu
    if (live != null) shown = live
    val enter = remember { Animatable(0f) }
    val leave = remember { Animatable(0f) }
    var expanded by remember { mutableStateOf(false) }
    LaunchedEffect(state.opened) {
        if (state.menu == null) return@LaunchedEffect
        expanded = false
        leave.snapTo(0f); enter.snapTo(0f)
        unscaled { enter.animateTo(1f, if (reduce) tween(150, easing = com.scottgerstl.lupe.ui.theme.EaseOut) else hm.spatial()) }
    }
    LaunchedEffect(live == null) {
        if (live == null && shown != null) { unscaled { leave.animateTo(1f, tween(120, easing = com.scottgerstl.lupe.ui.theme.EaseIn)) }; shown = null }
    }
    // the transport started or stopped with the menu open: its choices rebuild and the layout changes in place
    val firstPlaying = remember { booleanArrayOf(true) }
    LaunchedEffect(playing) { if (firstPlaying[0]) { firstPlaying[0] = false; return@LaunchedEffect }; expanded = false; state.refresh() }
    val m = shown ?: return
    BackHandler(enabled = live != null) { state.close() }
    val takes = live != null
    var origin by remember { mutableStateOf<LayoutCoordinates?>(null) }
    BoxWithConstraints(
        modifier.fillMaxSize().onGloballyPositioned { origin = it }
            .then(if (takes) Modifier.pointerInput(Unit) { detectTapGestures { state.close() } } else Modifier)
            .semantics { paneTitle = "Menu"; isTraversalGroup = true },
    ) {
        val sw = maxWidth.value; val sh = maxHeight.value
        val fingerPx = origin?.takeIf { it.isAttached }?.windowToLocal(m.at) ?: m.at
        val fx = with(density) { fingerPx.x.toDp().value }; val fy = with(density) { fingerPx.y.toDp().value }
        val out = 1f - leave.value
        Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            val k = if (reduce) 1f else (0.5f + 0.5f * enter.value) * (1f - 0.3f * leave.value)
            drawCircle(Tok.text.copy(alpha = 0.18f * (if (reduce) enter.value else 1f) * out), (STRAIGHT_DISC / 2).dp.toPx() * k, Offset(fx.dp.toPx(), fy.dp.toPx()))
        }
        val lay = layoutHoldMenu(m.items, sh - 2 * MENU_MARGIN, expanded)
        val geom = menuGeometry(m.items, lay, expanded)
        // the side is chosen when it opens and kept, so a change of layout shrinks toward the finger rather than jumping across it
        val side = remember(state.opened) { mutableStateOf<Boolean?>(null) }
        val place0 = holdMenuPlace(fx, fy, sw, sh, geom.w, geom.h, labs.menusRight)
        val left = side.value ?: place0.left.also { side.value = it }
        val px = (if (left) fx - STRAIGHT_GAP - geom.w else fx + STRAIGHT_GAP).coerceIn(MENU_MARGIN, (sw - MENU_MARGIN - geom.w).coerceAtLeast(MENU_MARGIN))
        val py = place0.y
        // targets in screen dp
        val targets = geom.els.map { it.copy(x = it.x + px, y = it.y + py) }
        val anims = remember(state.opened) { androidx.compose.runtime.mutableStateMapOf<String, MenuElAnim>() }
        LaunchedEffect(targets) { animateMenu(anims, targets, reduce) }
        Box(
            Modifier.fillMaxSize().graphicsLayer {
                alpha = enter.value.coerceIn(0f, 1f) * out
                if (!reduce) {
                    val sc = (0.94f + 0.06f * enter.value) * (1f - 0.04f * leave.value)
                    scaleX = sc; scaleY = sc
                    translationX = (if (left) 16.dp.toPx() else -16.dp.toPx()) * (1f - enter.value)
                    transformOrigin = androidx.compose.ui.graphics.TransformOrigin((fx / sw).coerceIn(0f, 1f), (fy / sh).coerceIn(0f, 1f))
                }
            },
        ) {
            // backgrounds first (groups, the after-Stop card), then rows and tiles over them
            val sorted = anims.values.sortedBy { if (it.el.kind == ElKind.Group || it.el.kind == ElKind.After) 0 else 1 }
            for (a in sorted) androidx.compose.runtime.key(a.el.key) {
                Box(
                    Modifier.offset { IntOffset((a.x.value + a.dx.value).dp.roundToPx(), (a.y.value + a.dy.value).dp.roundToPx()) }
                        .size(a.w.value.coerceAtLeast(1f).dp, a.h.value.coerceAtLeast(1f).dp)
                        .graphicsLayer { alpha = a.alpha.value.coerceIn(0f, 1f); scaleX = a.scale.value; scaleY = a.scale.value; transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, 0.5f) },
                ) {
                    val el = a.el
                    val usable = takes && !a.leaving
                    when (el.kind) {
                        ElKind.Group -> Box(Modifier.fillMaxSize().cardSurface(a.r.value).pointerInput(Unit) { detectTapGestures { } })
                        ElKind.After -> Box(Modifier.fillMaxSize().cardSurface(a.r.value).pointerInput(Unit) { detectTapGestures { } }) {
                            AfterStopHeader(m.items, geom.waiting, expanded, { expanded = !expanded }, usable, reduce)
                        }
                        ElKind.Tile -> MenuTile(el.item, el.index, state, usable, 1f, a.r.value)
                        ElKind.Row -> MenuRowItem(el.item, el.index, state, usable, 1f, dimmed = el.dim, colour = m.colour)
                        ElKind.Pill -> MenuPill(el.item, el.index, state, usable)
                    }
                }
            }
        }
    }
}

/** A card in the menu: `held` at [radiusDp], elevation 3 (the shadow), clipped. */
private fun Modifier.cardSurface(radiusDp: Float) = this.graphicsLayer {
    shadowElevation = 8.dp.toPx(); shape = RoundedCornerShape(radiusDp.dp); clip = true; ambientShadowColor = Color.Black; spotShadowColor = Color.Black
}.background(Tok.held)

/** One piece of the menu as it is drawn now: where (screen dp), its corner, and how it is fading or travelling. */
class MenuElAnim(var el: MenuEl) {
    val x = Animatable(el.x); val y = Animatable(el.y); val w = Animatable(el.w); val h = Animatable(el.h); val r = Animatable(el.radius)
    val alpha = Animatable(0f); val scale = Animatable(1f); val dx = Animatable(0f); val dy = Animatable(0f)
    var leaving by mutableStateOf(false)
}

/**
 * Moves the drawn pieces to [targets] (round 5). First opening: everything fades in 20 ms apart. A change of layout: what's gone folds away first
 * (120 ms ease-in, 20 ms apart, 0.94, 24 to the left), what stays travels on a spring (bounce 0.25, ~360 ms) from 60 ms, what's new comes in after
 * (groups at 160 ms; the after-Stop row last, at 300). Reduce Motion: fades only.
 */
private suspend fun animateMenu(anims: MutableMap<String, MenuElAnim>, targets: List<MenuEl>, reduce: Boolean) = kotlinx.coroutines.coroutineScope {
    val first = anims.isEmpty()
    val keys = targets.map { it.key }.toSet()
    val gone = anims.values.filter { it.el.key !in keys }
    val travel = com.scottgerstl.lupe.ui.theme.lupeSpring<Float>(360, 0.25f)
    gone.sortedBy { it.el.order }.forEachIndexed { i, a ->
        a.leaving = true
        launch {
            if (!reduce) kotlinx.coroutines.delay(20L * i)
            unscaled {
                kotlinx.coroutines.coroutineScope {
                    launch { a.alpha.animateTo(0f, tween(if (reduce) 150 else 120, easing = com.scottgerstl.lupe.ui.theme.EaseIn)) }
                    if (!reduce) { launch { a.scale.animateTo(0.94f, tween(120, easing = com.scottgerstl.lupe.ui.theme.EaseIn)) }; if (a.el.kind != ElKind.Tile) launch { a.dx.animateTo(-24f, tween(120, easing = com.scottgerstl.lupe.ui.theme.EaseIn)) } }
                }
            }
            if (anims[a.el.key] === a && a.leaving) anims.remove(a.el.key)
        }
    }
    val folding = gone.isNotEmpty()
    for (t in targets) {
        val a = anims[t.key]
        if (a == null) {
            val n = MenuElAnim(t); anims[t.key] = n
            if (!reduce && !first) { n.scale.snapTo(0.94f); n.dy.snapTo(-12f) }
            launch {
                val wait = when { first -> 20L * t.order; !folding -> 0L; t.kind == ElKind.After -> 300L; else -> 160L }
                kotlinx.coroutines.delay(if (reduce && !first) 0L else wait)
                unscaled {
                    kotlinx.coroutines.coroutineScope {
                        launch { n.alpha.animateTo(1f, tween(if (first) 140 else 150, easing = com.scottgerstl.lupe.ui.theme.EaseOut)) }
                        if (!reduce && !first) { launch { n.scale.animateTo(1f, com.scottgerstl.lupe.ui.theme.lupeSpring(220, 0.2f)) }; launch { n.dy.animateTo(0f, com.scottgerstl.lupe.ui.theme.lupeSpring(220, 0.2f)) } }
                    }
                }
            }
        } else {
            a.el = t; a.leaving = false
            launch {
                unscaled {
                    kotlinx.coroutines.coroutineScope {
                        launch { a.alpha.animateTo(1f, tween(150)) }; launch { a.scale.animateTo(1f, tween(150)) }; launch { a.dx.animateTo(0f, tween(150)) }; launch { a.dy.animateTo(0f, tween(150)) }
                    }
                }
            }
            launch {
                if (folding && !reduce) kotlinx.coroutines.delay(60)
                unscaled {
                    if (reduce) { a.alpha.snapTo(0f); a.x.snapTo(t.x); a.y.snapTo(t.y); a.w.snapTo(t.w); a.h.snapTo(t.h); a.r.snapTo(t.radius); a.alpha.animateTo(1f, tween(150)) }
                    else kotlinx.coroutines.coroutineScope {
                        launch { a.x.animateTo(t.x, travel) }; launch { a.y.animateTo(t.y, travel) }
                        launch { a.w.animateTo(t.w, travel) }; launch { a.h.animateTo(t.h, travel) }; launch { a.r.animateTo(t.radius, travel) }
                    }
                }
            }
        }
    }
}

enum class ElKind { Tile, Group, Row, After, Pill }

/** A piece of the menu: [key] stays the same across layouts, so it can travel. [x], [y] in dp from the menu's corner (screen dp once placed). */
data class MenuEl(val key: String, val kind: ElKind, val item: HoldItem, val index: Int, val x: Float, val y: Float, val w: Float, val h: Float, val radius: Float, val order: Int, val dim: Boolean = false)
data class MenuGeom(val els: List<MenuEl>, val w: Float, val h: Float, val waiting: List<Int>)

/** Columns sit 8 apart. */
const val COL_GAP = 8f

/**
 * Places every piece of a laid-out menu (pure, tested): the tiles across the first column's top, each group as a card with its rows inside (4 in),
 * the after-Stop card (a 52 header, then its dimmed rows when unfolded). Keys: "t:"/"r:" + the choice's title, "g:" + the group, "after".
 */
fun menuGeometry(items: List<HoldItem>, lay: MenuLayout, expanded: Boolean): MenuGeom {
    val els = mutableListOf<MenuEl>()
    var order = 0
    var maxY = 0f
    var waiting = emptyList<Int>()
    lay.columns.forEachIndexed { ci, col ->
        val cx = ci * (MENU_W + COL_GAP)
        var y = 0f
        if (ci == 0 && lay.tiles.isNotEmpty()) {
            lay.tiles.forEachIndexed { j, t -> els += MenuEl("t:" + items[t].title, ElKind.Tile, items[t], t, cx + j * (TILE_W + TILE_GAP), 0f, TILE_W, TILE_H, 18f, order++) }
            y = TILE_H + GROUP_GAP
        }
        for (g in col) {
            val gh = groupH(items, g, expanded)
            if (g.waiting) {
                waiting = g.rows
                els += MenuEl("after", ElKind.After, items[g.rows.first()], -1, cx, y, MENU_W, gh, 16f, order++)
                if (expanded) g.rows.forEachIndexed { i, r -> els += MenuEl("d:" + items[r].title, ElKind.Row, items[r], r, cx + 4f, y + 4f + 52f + i * 44f, MENU_W - 8f, 44f, 12f, order++, dim = true) }
            } else {
                els += MenuEl("g:" + (g.name ?: items[g.rows.first()].title), ElKind.Group, items[g.rows.first()], -1, cx, y, MENU_W, gh, 16f, order++)
                var ry = y + 4f
                for (r in g.rows.filter { !items[it].pill }) { val rh = rowH(items[r]); els += MenuEl("r:" + items[r].title, ElKind.Row, items[r], r, cx + 4f, ry, MENU_W - 8f, rh, 12f, order++); ry += rh }
                // the short values as pills, four across (each 69 × 40)
                g.rows.filter { items[it].pill }.forEachIndexed { j, r ->
                    els += MenuEl("p:" + items[r].title, ElKind.Pill, items[r], r, cx + 4f + (j % PILLS_ACROSS) * (PILL_W + PILL_GAP), ry + (j / PILLS_ACROSS) * (PILL_H + PILL_GAP), PILL_W, PILL_H, PILL_H / 2, order++)
                }
            }
            y += gh + GROUP_GAP
        }
        maxY = maxOf(maxY, y - GROUP_GAP)
    }
    val w = lay.columns.size * MENU_W + (lay.columns.size - 1) * COL_GAP
    return MenuGeom(els, w, maxY, waiting)
}

/** 0…1 as the [order]th piece of the menu fades in (tiles first, then rows, 20 ms apart). */
private fun appear(clockMs: Float, order: Int, reduce: Boolean) = if (reduce) 1f else ((clockMs - 20f * order) / 140f).coerceIn(0f, 1f)

/** A priority tile: 96 × 84, `held` at radius 18 (white with dark ink while its choice is on, Mute or Solo), icon 24 over the label and a second line. */
@Composable
private fun MenuTile(item: HoldItem, k: Int, state: HoldMenuState, takes: Boolean, appear: Float, radiusDp: Float = 18f) {
    val reduce = LocalReduceMotion.current
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val lit = com.scottgerstl.lupe.ui.theme.animatedFloat(if (item.checked) 1f else 0f, com.scottgerstl.lupe.ui.theme.Dur.STATE).value
    val sq by com.scottgerstl.lupe.ui.theme.spatialFloat(if (pressed) 0.94f else 1f, reduce, fast = true)
    val ink = lerp(Tok.text, Tok.onColour, lit)
    // a toggled tile (Mute, Solo on) turns white and squares off, 18 → 12, with a squash (shape as state, `2c`)
    val square by com.scottgerstl.lupe.ui.theme.spatialFloat(if (item.checked) 1f else 0f, reduce)
    val tileSquash = com.scottgerstl.lupe.ui.theme.rememberSquash(item.checked, reduce)
    Column(
        Modifier.size(TILE_W.dp, TILE_H.dp)
            .graphicsLayer { alpha = appear * (if (item.enabled) 1f else 0.4f); val (qx, qy) = tileSquash(); scaleX = sq * qx; scaleY = sq * qy; shadowElevation = 8.dp.toPx(); shape = RoundedCornerShape((radiusDp - 6f * square.coerceIn(0f, 1.2f)).coerceAtLeast(4f).dp); clip = true; ambientShadowColor = Color.Black; spotShadowColor = Color.Black }
            .background(lerp(Tok.held, Tok.text, lit))
            .then(if (!takes) Modifier.clearAndSetSemantics { } else Modifier.semantics(mergeDescendants = true) {
                role = Role.Button; contentDescription = item.title + (item.tileSub?.let { ", $it" } ?: "")
                if (item.checked) selected = true
                if (!item.enabled) disabled()
            })
            .clickable(source, null, enabled = takes && item.enabled) { state.pick(k) }
            .padding(horizontal = 6.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
            holdIcon(item.title)?.let { Image(androidx.compose.ui.res.painterResource(it), null, Modifier.size(24.dp), colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(lerp(Tok.text2Raised, Tok.onColour, lit))) }
        }
        Spacer(Modifier.height(6.dp))
        BasicText(item.short ?: item.title, style = LupeType.body.copy(fontSize = 14.sp, lineHeight = 16.sp, color = ink, textAlign = androidx.compose.ui.text.style.TextAlign.Center), maxLines = 1,
            autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 14.sp, stepSize = 1.sp))
        if (item.tileSub != null) BasicText(item.tileSub, style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 14.sp, color = lerp(Tok.text2Raised, Tok.onColour, lit), textAlign = androidx.compose.ui.text.style.TextAlign.Center), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun MenuRowItem(item: HoldItem, k: Int, state: HoldMenuState, takes: Boolean, appear: Float, dimmed: Boolean = false, colour: Color = Tok.text) {
    val reduce = LocalReduceMotion.current
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val confirming = state.confirming == k
    val others = state.confirming >= 0 && !confirming
    val rowH = if (item.sub != null || item.slide != null || confirming) 52.dp else 44.dp
    // a pressed or current row grows a lifted pill (shape as state)
    val pill by com.scottgerstl.lupe.ui.theme.spatialFloat(if (pressed || item.checked) 1f else 0f, reduce, fast = true)
    val pillA = com.scottgerstl.lupe.ui.theme.animatedFloat(if (pressed || item.checked) 1f else 0f, 100).value
    val usable = takes && item.enabled && !dimmed
    Row(
        Modifier.fillMaxWidth().heightIn(min = rowH)
            .graphicsLayer { alpha = appear * (if (others || dimmed || !item.enabled) 0.4f else 1f) }
            .drawBehind {
                if (pillA > 0f) { val g = if (reduce) 1f else (0.86f + 0.14f * pill).coerceAtMost(1.03f); val w = size.width * g; val hh = size.height * g
                    drawRoundRect(Tok.lifted.copy(alpha = pillA), Offset((size.width - w) / 2, (size.height - hh) / 2), Size(w, hh), CornerRadius(hh / 2)) }
                if (confirming) drawRoundRect(Tok.rec, Offset(0.75.dp.toPx(), 0.75.dp.toPx()), Size(size.width - 1.5.dp.toPx(), size.height - 1.5.dp.toPx()), CornerRadius(12.dp.toPx()), style = Stroke(1.5.dp.toPx()))
            }
            .then(if (!takes || dimmed) Modifier.clearAndSetSemantics { if (dimmed) { contentDescription = "${item.title}, after Stop"; disabled() } } else if (item.slide != null) Modifier else Modifier.semantics(mergeDescendants = true) {
                role = Role.Button
                contentDescription = if (confirming) "Confirm: ${item.confirm}" else item.title + (item.sub?.let { ", $it" } ?: "")
                if (item.checked) selected = true
                if (!item.enabled) disabled()
            })
            .then(if (item.slide != null || !usable) Modifier else Modifier.clickable(source, null) { state.pick(k) })
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) {
            holdIcon(item.title)?.let { Image(androidx.compose.ui.res.painterResource(it), null, Modifier.size(20.dp), colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(Tok.text2Raised)) }
        }
        Spacer(Modifier.width(12.dp))
        if (item.slide != null) Box(Modifier.weight(1f).height(rowH)) { HoldSlideRow(item.title, item.slide, takes, colour) }
        else if (confirming) BasicText(item.confirm.orEmpty(), Modifier.weight(1f), style = LupeType.key.copy(fontSize = 14.sp, lineHeight = 1.15.em, color = Tok.rec), maxLines = 3, overflow = TextOverflow.Ellipsis,
            autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 14.sp, stepSize = 1.sp))
        else {
            Column(Modifier.weight(1f)) {
                BasicText(item.title, style = LupeType.body.copy(fontSize = 16.sp, lineHeight = 1.15.em, color = Tok.text), maxLines = 1, overflow = TextOverflow.Ellipsis,
                    autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 12.sp, maxFontSize = 16.sp, stepSize = 1.sp))
                if (item.sub != null && !dimmed) BasicText(item.sub, style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 1.15.em, color = Tok.text2Raised), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            if (item.checked) { Spacer(Modifier.width(8.dp)); Check(Tok.text) }
            if (item.children != null) { Spacer(Modifier.width(8.dp)); BasicText("›", style = LupeType.key.copy(fontSize = 18.sp, color = Tok.text2Raised)) }
        }
    }
}

/** A value pill (the pattern's lengths): `control`, round; the current one white with dark ink, its corners squaring to 12 on the spring. */
@Composable
private fun MenuPill(item: HoldItem, k: Int, state: HoldMenuState, takes: Boolean) {
    val reduce = LocalReduceMotion.current
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val press by com.scottgerstl.lupe.ui.theme.pressScale(pressed, reduce)
    val lit = com.scottgerstl.lupe.ui.theme.animatedFloat(if (item.checked) 1f else 0f, com.scottgerstl.lupe.ui.theme.Dur.STATE).value
    val square by com.scottgerstl.lupe.ui.theme.spatialFloat(if (item.checked) 1f else 0f, reduce)
    val squash = com.scottgerstl.lupe.ui.theme.rememberSquash(item.checked, reduce)
    Box(
        Modifier.fillMaxSize()
            .graphicsLayer { val (qx, qy) = squash(); scaleX = press * qx; scaleY = press * qy; alpha = if (item.enabled) 1f else 0.4f }
            .drawBehind { val r = size.height / 2 + (12.dp.toPx() - size.height / 2) * square.coerceIn(0f, 1.2f); drawRoundRect(lerp(Tok.control, Tok.text, lit), cornerRadius = CornerRadius(r.coerceAtLeast(4f))) }
            .then(if (!takes) Modifier.clearAndSetSemantics { } else Modifier.semantics(mergeDescendants = true) {
                role = Role.RadioButton; contentDescription = item.title; selected = item.checked
                if (!item.enabled) disabled()
            })
            .clickable(source, null, enabled = takes && item.enabled) { state.pick(k) },
        contentAlignment = Alignment.Center,
    ) {
        BasicText(item.short ?: item.title, style = LupeType.number.copy(fontSize = 17.sp, lineHeight = 18.sp, fontWeight = FontWeight.Bold, color = lerp(Tok.text, Tok.onColour, lit)), maxLines = 1)
    }
}

/** The after-Stop card's header row: ⏸, "N more after Stop", what they are, a ⌄ that turns as it unfolds. */
@Composable
private fun AfterStopHeader(items: List<HoldItem>, rows: List<Int>, expanded: Boolean, toggle: () -> Unit, takes: Boolean, reduce: Boolean) {
    if (rows.isEmpty()) return
    val turn = com.scottgerstl.lupe.ui.theme.spatialFloat(if (expanded) 1f else 0f, reduce).value
    Row(
        Modifier.padding(4.dp).fillMaxWidth().height(52.dp)
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = afterStopTitle(rows.size) + ": " + afterStopNames(items, rows); stateDescription = if (expanded) "Shown" else "Folded" }
            .clickable(enabled = takes) { toggle() }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Canvas(Modifier.size(20.dp)) { val bw = 3.dp.toPx(); val bh = 12.dp.toPx(); val y = (size.height - bh) / 2
            drawRoundRect(Tok.text2Raised, Offset(size.width / 2 - bw - 1.5.dp.toPx(), y), Size(bw, bh), CornerRadius(1.dp.toPx()))
            drawRoundRect(Tok.text2Raised, Offset(size.width / 2 + 1.5.dp.toPx(), y), Size(bw, bh), CornerRadius(1.dp.toPx())) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            BasicText(afterStopTitle(rows.size), style = LupeType.body.copy(fontSize = 16.sp, lineHeight = 1.15.em, color = Tok.text), maxLines = 1)
            BasicText(afterStopNames(items, rows), style = LupeType.small.copy(fontSize = 12.sp, lineHeight = 1.15.em, color = Tok.text2Raised), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Chevron(Tok.text2Raised, Modifier.graphicsLayer { rotationZ = 180f * turn })
    }
}

internal fun afterStopTitle(n: Int) = "$n more after Stop"

/** The waiting choices named briefly, without repeats: "Play once ±, Duplicate, Move, Delete". */
internal fun afterStopNames(items: List<HoldItem>, rows: List<Int>): String = rows.map { k ->
    val t = items[k].title
    when {
        t.startsWith("Play once") -> "Play once ±"
        t.startsWith("Move ") -> "Move"
        t.startsWith("Duplicate") -> "Duplicate"
        t.startsWith("Delete") -> "Delete"
        t.startsWith("Recycle") -> "Recycle"
        else -> t.removeSuffix("…")
    }
}.distinct().joinToString(", ")

/** The menu's measures (dp). */
const val TILE_W = 96f
const val TILE_H = 84f
const val TILE_GAP = 4f
/** A column: three tiles and their gaps. */
const val MENU_W = TILE_W * 3 + TILE_GAP * 2
const val GROUP_GAP = 4f
const val MENU_MARGIN = 12f
const val STRAIGHT_DISC = 56f
const val HEADER_FOOT = 60f
const val STRAIGHT_GAP = 36f

/** A group of rows in the menu: their indices into the items, or the folded after-Stop row ([waiting]). */
data class MenuGroup(val name: String?, val rows: List<Int>, val waiting: Boolean = false)
/** The tiles (indices) and the groups in one or two columns. */
data class MenuLayout(val tiles: List<Int>, val columns: List<List<MenuGroup>>)

internal fun rowH(i: HoldItem) = if (i.sub != null || i.slide != null) 52f else 44f
internal fun groupH(items: List<HoldItem>, g: MenuGroup, expanded: Boolean): Float {
    if (g.waiting) return 8f + 52f + (if (expanded) g.rows.size * 44f else 0f)
    val pills = g.rows.count { items[it].pill }
    val pillRows = (pills + PILLS_ACROSS - 1) / PILLS_ACROSS
    return 8f + g.rows.filter { !items[it].pill }.sumOf { rowH(items[it]).toDouble() }.toFloat() + (if (pillRows > 0) pillRows * PILL_H + (pillRows - 1) * PILL_GAP else 0f)
}

/** Value pills in a group: four across the column, 40 tall (Scott, 2026-11-17: the steps menu ran off the screen as a list). */
const val PILLS_ACROSS = 4
const val PILL_GAP = 4f
const val PILL_H = 40f
const val PILL_W = (MENU_W - 8f - (PILLS_ACROSS - 1) * PILL_GAP) / PILLS_ACROSS

/**
 * Lays out a hold menu (pure, tested): up to three [HoldItem.tile]s; the rest grouped by [HoldItem.group] in order, with every
 * [HoldItem.afterStop] choice folded into one last group; one column if it fits [maxH], else two, the tiles always at the top left.
 */
fun layoutHoldMenu(items: List<HoldItem>, maxH: Float, expanded: Boolean = false): MenuLayout {
    val tiles = items.indices.filter { items[it].tile }.take(3)
    val rest = items.indices.filter { it !in tiles }
    val groups = mutableListOf<MenuGroup>()
    for (k in rest.filter { !items[it].afterStop }) {
        val last = groups.lastOrNull()
        if (last != null && last.name == items[k].group) groups[groups.lastIndex] = last.copy(rows = last.rows + k) else groups += MenuGroup(items[k].group, listOf(k))
    }
    val waiting = rest.filter { items[it].afterStop }
    if (waiting.isNotEmpty()) groups += MenuGroup("after-stop", waiting, waiting = true)
    val tilesH = if (tiles.isEmpty()) 0f else TILE_H + GROUP_GAP
    // one group taller than the screen (a long list with no groups) is cut in two, so it can take a second column instead of running off the
    // bottom: hold menus don't scroll (Scott, 2026-11-17: the steps menu stopped at 48)
    if (groups.size == 1 && !groups[0].waiting && groups[0].rows.size > 1 && tilesH + groupH(items, groups[0], expanded) > maxH) {
        val g = groups[0]; val half = (g.rows.size + 1) / 2
        groups[0] = g.copy(rows = g.rows.take(half)); groups += MenuGroup(g.name?.let { "$it ·2" } ?: "·2", g.rows.drop(half))
    }
    val heights = groups.map { groupH(items, it, expanded) + GROUP_GAP }
    if (tilesH + heights.sum() - GROUP_GAP <= maxH || groups.size < 2) return MenuLayout(tiles, listOf(groups))
    // two columns: the left takes groups while it stays at or under half the total (and always the first), the rest go right
    val total = tilesH + heights.sum()
    var left = tilesH; var split = 0
    while (split < groups.size && (split == 0 || left + heights[split] <= maxOf(total / 2f, tilesH + heights[0]) + 1f) && left + heights[split] <= maxH + GROUP_GAP) { left += heights[split]; split++ }
    if (split == 0) split = 1
    return MenuLayout(tiles, listOf(groups.take(split), groups.drop(split)))
}

/** Where the menu's top-left goes (dp) and whether it opens to the finger's left. */
data class StraightPlace(val x: Float, val y: Float, val left: Boolean)

/**
 * Beside the finger: to its left unless [menusRight] (Settings › Menus open), flipping when there's no room; its top 42 above the finger so
 * the tiles sit level with it; under the header when it fits, never nearer an edge than [margin].
 */
fun holdMenuPlace(fx: Float, fy: Float, screenW: Float, screenH: Float, menuW: Float, menuH: Float, menusRight: Boolean, margin: Float = MENU_MARGIN): StraightPlace {
    val leftX = fx - STRAIGHT_GAP - menuW
    val rightX = fx + STRAIGHT_GAP
    val fitsLeft = leftX >= margin; val fitsRight = rightX + menuW <= screenW - margin
    val left = if (menusRight) !fitsRight && fitsLeft else fitsLeft || !fitsRight
    val x = (if (left) leftX else rightX).coerceIn(margin, (screenW - margin - menuW).coerceAtLeast(margin))
    val top = if (menuH <= screenH - HEADER_FOOT - margin) HEADER_FOOT else margin
    val y = (fy - 42f).coerceIn(top, (screenH - margin - menuH).coerceAtLeast(top))
    return StraightPlace(x, y, left)
}

/** A slide row's inside: the name, the value large at the right, a gauge along the foot; a finger slid along it (either way) sets the value. */
@Composable
private fun HoldSlideRow(title: String, sl: HoldSlide, enabled: Boolean = true, colour: Color = Tok.text) {
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
            // the fill in the held track's colour (`2f`)
            drawRect(colour, Offset(minOf(from, x), 0f), Size(maxOf(kotlin.math.abs(x - from), if (sl.bipolarAt != null) 2.dp.toPx() else 0f), size.height))
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
            menu.open(c.localToWindow(currentEvent.changes.firstOrNull { it.id == down.id }?.position ?: down.position), tint, choices, live = { list() })
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

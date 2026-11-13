package com.scottgerstl.lupe.ui.shell

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.unit.sp
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.delay
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings
import com.scottgerstl.lupe.core.BottomPage
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.ui.mix.MixPage
import com.scottgerstl.lupe.ui.timeline.TimelinePage
import com.scottgerstl.lupe.ui.timeline.rememberTimeline
import com.scottgerstl.lupe.ui.sounds.LocalSoundsHost
import com.scottgerstl.lupe.ui.sounds.SoundsBrowser
import com.scottgerstl.lupe.ui.mix.rememberMix
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.Divider
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.heightPx
import com.scottgerstl.lupe.ui.theme.unscaled
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.systemGestures
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import kotlin.math.abs
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.foundation.gestures.verticalDrag
import androidx.compose.foundation.gestures.awaitVerticalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitEachGesture
import kotlinx.coroutines.flow.first

private fun Divider.index() = when (this) { Divider.Top -> 0; Divider.Split -> 1; Divider.Bottom -> 2 }
private fun Int.toDivider() = Divider.entries[this]

private const val HANDLE_H = 16f   // dp, the divider's drawn band (board 53)
private const val GAP = 4f         // dp above and below it
private const val HEADER_H = 36f   // the tab row
private const val STRIP_H = 40f    // bottom full: the selected track's pads stay up as a strip
private const val TOP_OFFSET = HEADER_H + 8f // content starts 8 below the tabs
private const val BOTTOM_TOP = STRIP_H + GAP // the divider's top at bottom full
private const val STRIP_H_STACK = 134f // the step settings strip (122) and the gap above it: the grid ends this far above the body's bottom
private const val EDITOR_STRIP_H = 40f // top only: the "Editor ⌃" strip that brings the bottom half back

/**
 * Tabs, the top half, the divider, the bottom half. [p] is the divider's place as a number: 0 top only,
 * 1 split, 2 bottom full, with everything between. The positions are the boards' (board 54): at 412 × 915 dp
 * split puts the divider at 350 dp below the tabs, top only at the bottom edge, bottom full under a 40 dp
 * strip. Heights scale with the screen.
 */
@Composable
fun ShellBody(shell: ShellState, core: LupeCore, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val density = LocalDensity.current
    // Labs: the bottom half can hold its page for 3 s after a touch, or be pinned (it stops following the FM-1)
    val labs = LocalPhoneSettings.current
    var bottomTouches by remember { mutableIntStateOf(0) }
    var phoneAsks by remember { mutableIntStateOf(0) }
    val followed = followedBottom(shell.bottom, labs.pinBottom, labs.pauseFollowing, bottomTouches, phoneAsks)
    val shown = followed.first
    val frozen = followed.second
    val shellShown = if (shown == shell.bottom) shell else shell.copy(bottom = shown)
    val onBottomTouch = { bottomTouches++ ; Unit }
    // the bottom half's page changes the phone itself asks for are never held; its core says so before sending them
    val askCore = remember(core) { AskingCore(core) { phoneAsks++ } }
    val pads by core.pads.collectAsStateWithLifecycle()
    val editor by core.editor.collectAsStateWithLifecycle()
    // the picked step (decision 21): none shows HOME's knobs. The FM-1 changing page (or a sound page opening) puts the knobs back
    val pick = remember { StepPick() }
    // A sound page opening clears the pick (HOME then brings the knobs back); tapping a step while a sound page shows picks it and
    // keeps the page up, through page changes within the section (decision 20c)
    LaunchedEffect(shell.bottom.kind) { pick.step = null }

    // Decision 19: while a sound page shows (and only then), the back gesture is HOME on the FM-1. Registered before the
    // content, so the Sounds browser's own BackHandler (composed later) wins while it is open.
    val soundPageUp = shell.bottom.kind == BottomKind.Page
    androidx.activity.compose.BackHandler(enabled = soundPageUp) { core.send(com.scottgerstl.lupe.core.GoHome) }
    androidx.compose.runtime.CompositionLocalProvider(com.scottgerstl.lupe.ui.slide.LocalBackGoesHome provides soundPageUp) {
    BoxWithConstraints(modifier.fillMaxSize()) {
        val hb = with(density) { maxHeight.toPx() }
        fun dp(v: Float) = with(density) { v.dp.toPx() }
        // Android's bottom gesture zone can reach above the body (LupeShell pads it only by the navigation bar).
        // Nothing that takes a drag may sit in it, or Android takes the upward swipe home (Scott's run, 2026-11-13).
        val navBottom = WindowInsets.navigationBars.getBottom(density).toFloat()
        val under = maxOf(navBottom, dp(24f)) + dp(8f)   // LupeShell's padding under the body: keep in step
        val gestureOverlap = (WindowInsets.systemGestures.getBottom(density) - under).coerceAtLeast(0f)
        // the divider's top, in px below the body's top, for each position. Top only leaves room for the
        // Editor strip under the handle, and keeps both clear of the gesture zone.
        val stops = floatArrayOf(hb - gestureOverlap - dp(EDITOR_STRIP_H) - dp(GAP) - dp(HANDLE_H), (hb * 350f / 787f).coerceAtLeast(dp(BOTTOM_TOP) + dp(80f)), dp(BOTTOM_TOP))
        fun topAt(p: Float): Float {
            val c = p.coerceIn(0f, 2f); val i = c.toInt().coerceAtMost(1); val f = c - i
            return stops[i] + (stops[i + 1] - stops[i]) * f
        }
        fun pAt(top: Float): Float {
            val t = top.coerceIn(stops[2], stops[0])
            return if (t >= stops[1]) (stops[0] - t) / (stops[0] - stops[1]) else 1f + (stops[1] - t) / (stops[1] - stops[2])
        }

        val place = remember { Animatable(shell.divider.index().toFloat()) }
        var dragging by remember { mutableStateOf(false) }
        // Reduce Motion: nothing travels. The settled position cross-fades; a drag only moves the handle's choice.
        var dragP by remember { mutableStateOf(0f) }

        LaunchedEffect(shell.divider, reduce) {
            if (dragging) return@LaunchedEffect
            val target = shell.divider.index().toFloat()
            if (reduce) place.snapTo(target) else unscaled { place.animateTo(target, tween(Dur.PANEL, easing = EaseOut)) }
        }

        fun settle(to: Divider) {
            if (to != shell.divider) haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
            core.send(Intent.SetDivider(to))
            scope.launch {
                if (reduce) place.snapTo(to.index().toFloat()) else unscaled { place.animateTo(to.index().toFloat(), tween(Dur.PANEL, easing = EaseOut)) }
            }
        }

        if (reduce) {
            LupeCrossfade(shell.divider) { d -> Layers(d.index().toFloat(), shellShown, pads, editor, askCore, hb, ::topAt, onBottomTouch, frozen, pick) }
        } else {
            Layers(place.value, shellShown, pads, editor, askCore, hb, ::topAt, onBottomTouch, frozen, pick)
        }

        // The divider's touch target: 48 dp tall around the 16 dp band, over both halves.
        Box(
            Modifier
                .fillMaxWidth().height(48.dp)
                .offset {
                    val centre = topAt(if (reduce) shell.divider.index().toFloat() else place.value) + dp(HANDLE_H) / 2
                    // never into the gesture zone: the band's bottom stays above it
                    IntOffset(0, (centre - dp(24f)).coerceAtMost(hb - gestureOverlap - dp(48f)).toInt())
                }
                .semantics {
                    role = Role.Button
                    contentDescription = "Divider between the top and bottom halves"
                    stateDescription = when (shell.divider) { Divider.Top -> "Top only"; Divider.Split -> "Split"; Divider.Bottom -> "Bottom full" }
                    customActions = Divider.entries.map { d ->
                        CustomAccessibilityAction(when (d) { Divider.Top -> "Top only"; Divider.Split -> "Split"; Divider.Bottom -> "Bottom full" }) { settle(d); true }
                    }
                }
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                    // a tap steps through the three: top → split → bottom → split …
                    settle(when (shell.divider) { Divider.Top -> Divider.Split; Divider.Split -> Divider.Bottom; Divider.Bottom -> Divider.Split })
                }
                .draggable(
                    orientation = Orientation.Vertical,
                    state = rememberDraggableState { dy ->
                        dragP = pAt(topAt(dragP) + dy)
                        if (!reduce) scope.launch { place.snapTo(dragP) }
                    },
                    onDragStarted = { dragging = true; dragP = place.value },
                    onDragStopped = { v ->
                        dragging = false
                        // a fling carries it: aim where it would be in 150 ms
                        val aim = pAt(topAt(dragP) + v * 0.15f)
                        settle(Math.round(aim).coerceIn(0, 2).toDivider())
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.width(44.dp).height(5.dp).background(Tok.lifted, RoundedCornerShape(3.dp)))
        }

        // Top only: a visible way back to the editor that needs no drag (WCAG 2.5.7), above the gesture zone.
        val stripShown = if (reduce) (if (shell.divider == Divider.Top) 1f else 0f) else ((0.6f - place.value) / 0.6f).coerceIn(0f, 1f)
        if (stripShown > 0f) {
            val source = remember { MutableInteractionSource() }
            val focused by source.collectIsFocusedAsState()
            val pressed by source.collectIsPressedAsState()
            val shape = RoundedCornerShape(Tok.CHICLET_RADIUS.dp)
            Box(
                Modifier
                    .padding(horizontal = 8.dp)
                    .fillMaxWidth()
                    .height(EDITOR_STRIP_H.dp)
                    .offset { IntOffset(0, (hb - gestureOverlap - dp(EDITOR_STRIP_H)).toInt()) }
                    .graphicsLayer { alpha = stripShown }
                    .background(if (pressed) Tok.pressed else Tok.panel, shape)
                    .border(if (focused) 2.dp else 0.dp, if (focused) Tok.text else Tok.panel, shape)
                    .clickable(interactionSource = source, indication = null, role = Role.Button,
                               onClickLabel = "Show the editor") { settle(Divider.Split) },
                contentAlignment = Alignment.Center,
            ) { BasicText("Editor ⌃", style = LupeType.key) }
        }
    }
    }
}

/** The top half's page for the tab: Pads, Timeline or Mix. */
@Composable
private fun TopContent(tab: Tab, pads: PadsState, core: LupeCore) {
    val mix = rememberMix(core)
    val timeline = rememberTimeline(core)   // the song is a stand-in until the core's timeline area lands
    val topState = core.top.collectAsStateWithLifecycle()
    val meters = core.meters.collectAsStateWithLifecycle()   // read only while drawing a meter line, so 20 updates a second never recompose the shell
    LupeCrossfade(tab, Modifier.fillMaxSize(), Dur.STATE) { when (it) { Tab.Pads -> PadsPage(pads, core); Tab.Mix -> MixPage(mix.first, mix.second, meters)
        Tab.Timeline -> TimelinePage(timeline.first, timeline.second, timeline.third, topState); else -> TopPlaceholder(it) } }
}

/** The picture at one divider place. */
@Composable
private fun Layers(p: Float, shell: ShellState, pads: PadsState, editor: EditorState, core: LupeCore, hb: Float, topAt: (Float) -> Float, onBottomTouch: () -> Unit, frozen: Boolean = false, pick: StepPick = remember { StepPick() }) {
    val density = LocalDensity.current
    val automation by core.automation.collectAsStateWithLifecycle()
    val soundsHost = LocalSoundsHost.current
    // at top only the bottom half is hidden: the browser glides the divider to split so it can be seen
    androidx.compose.runtime.LaunchedEffect(soundsHost.request) {
        val r = soundsHost.request ?: return@LaunchedEffect
        if (shell.divider == Divider.Top) core.send(Intent.SetDivider(Divider.Split))
        // the browser changes what the core's `sounds` area is about: this track, or this pad's own sound
        core.send(com.scottgerstl.lupe.core.SoundsTargetPick(r.track, r.pad?.let { it[0] - 'A' }))
    }
    fun dp(v: Float) = with(density) { v.dp.toPx() }
    // tabs fade out and the strip fades in as the divider goes past split
    val tabsAlpha = ((1.6f - p) / 0.6f).coerceIn(0f, 1f)
    val stripAlpha = ((p - 1.4f) / 0.6f).coerceIn(0f, 1f)

    Box(Modifier.fillMaxSize()) {
        if (tabsAlpha > 0f) Tabs(shell.tab, { core.send(Intent.SetTab(it)) }, Modifier.padding(horizontal = 8.dp).graphicsLayer { alpha = tabsAlpha })
        if (stripAlpha > 0f) PadsStrip(pads, core, Modifier.padding(horizontal = 8.dp).graphicsLayer { alpha = stripAlpha })

        // top half: from 8 dp under the tabs to 4 dp above the divider
        Box(
            Modifier
                .padding(horizontal = 8.dp)
                .offset(0.dp, TOP_OFFSET.dp)
                .heightPx { (topAt(p) - dp(GAP) - dp(TOP_OFFSET)).toInt() }
                .clipToBounds()
                .graphicsLayer { alpha = (1f - stripAlpha * 2f).coerceIn(0f, 1f) },
        ) { TopContent(shell.tab, pads, core) }

        // bottom half: from 4 dp under the divider band to the bottom; it follows the FM-1's page
        Box(
            Modifier
                .padding(horizontal = 8.dp)
                .offset { IntOffset(0, (topAt(p) + dp(HANDLE_H) + dp(GAP)).toInt()) }
                .heightPx { (hb - topAt(p) - dp(HANDLE_H) - dp(GAP)).toInt() }
                .clipToBounds()
                // at top only the Editor strip takes this room: the page fades out under it
                .graphicsLayer { alpha = (p / 0.4f).coerceIn(0f, 1f) }
                // any new touch down in this half is counted (Labs: pause following), and passes on unconsumed
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) { val e = awaitPointerEvent(androidx.compose.ui.input.pointer.PointerEventPass.Initial); if (e.changes.any { it.pressed && !it.previousPressed }) onBottomTouch() }
                    }
                },
        ) {
            val freeTake by core.freeTake.collectAsStateWithLifecycle()
            // the lane fits only when the bottom half is nearly full height
            val autoFraction = (((hb - topAt(p) - dp(HANDLE_H) - dp(GAP)) - dp(560f)) / dp(100f)).coerceIn(0f, 1f)
            LupeCrossfade(soundsHost.request, Modifier.fillMaxSize(), Dur.PANEL) { req ->
                if (req != null) {
                    // the Sounds browser opens over the editor or the sound page; Done or Back brings it back
                    SoundsBrowser(core, req, { soundsHost.close() })
                } else LupeCrossfade(shell.bottom.kind == BottomKind.FreeTake, Modifier.fillMaxSize(), Dur.PANEL) { take ->
                    // the editor and a sound page share one layout (decision 20c): the grid stays, the dials row gives way to the sound section
                    when (if (take) BottomKind.FreeTake else BottomKind.Editor) {
                        // the offer and the landing sit on top of the editor; the FM-1's picker takes its place
                        BottomKind.Editor -> Box(Modifier.fillMaxSize()) {
                            EditorPage(editor, core, autoFraction, automation, pick = pick,
                                sound = if (shell.bottom.kind == BottomKind.Page) ({ HeldSoundPage(shell.bottom, core, frozen) }) else null)
                            com.scottgerstl.lupe.ui.freetake.TakeStrips(freeTake, core, Modifier.align(Alignment.TopCenter).padding(top = 2.dp))
                        }
                        BottomKind.FreeTake -> com.scottgerstl.lupe.ui.freetake.FreeTakePicker(freeTake, core)
                        else -> Unit
                    }
                }
            }
        }
    }
}


/**
 * Which page the bottom half shows, and whether it is held. It follows the FM-1 ([actual]) unless a Labs trial says
 * otherwise: [pin] stops following altogether; [pause] holds the page it's on for 3 s after each touch in the bottom half,
 * then catches up to the FM-1's.
 */
@Composable
private fun followedBottom(actual: BottomPage, pin: Boolean, pause: Boolean, touches: Int, asks: Int): Pair<BottomPage, Boolean> {
    val m = remember { FollowModel(actual) }
    m.pin = pin; m.pause = pause
    val now = { System.currentTimeMillis() }
    LaunchedEffect(touches) { if (touches > 0) { m.touch(now()); delay(FollowModel.HOLD_MS + 20); m.tick(now()) } }
    LaunchedEffect(asks) { if (asks > 0) { m.ask(now()); m.onActual(actual, now()) } }
    LaunchedEffect(actual, pin, pause) { m.onActual(actual, now()); m.tick(now()) }
    return m.shown to m.frozen
}

/**
 * A sound page while the bottom half is held (Labs: pin, or pause after a touch). The core's `page` area follows the FM-1, so
 * if the FM-1 has moved on, the page that was shown is frozen as it was and read-only (a value set now would land on the
 * FM-1's page, not this one), with a word saying so; while both are on the same page it stays live.
 */
@Composable
private fun HeldSoundPage(page: BottomPage, core: LupeCore, frozen: Boolean) {
    val live by core.page.collectAsStateWithLifecycle()
    var snap by remember { mutableStateOf(live) }
    LaunchedEffect(live, frozen) { if (!frozen) snap = live }
    val moved = frozen && (snap.family != live.family || snap.page != live.page)
    Box(Modifier.fillMaxSize()) {
        com.scottgerstl.lupe.ui.page.SoundOrPlaceholder(page, if (moved) remember(snap) { HeldPageCore(core, snap) } else core, notice = if (moved) "The FM-1 is on ${live.family} · held here" else null)
    }
}

/** The core as the bottom half sees it: a page change the phone asks for tells the follower first. */
private class AskingCore(private val base: LupeCore, private val asked: () -> Unit) : LupeCore by base {
    override fun send(intent: Intent) {
        if (intent is com.scottgerstl.lupe.core.PickPage || intent is com.scottgerstl.lupe.core.PickRoute || intent is com.scottgerstl.lupe.core.PickTile || intent == com.scottgerstl.lupe.core.GoHome) asked()
        base.send(intent)
    }
}

private class HeldPageCore(private val base: LupeCore, snapshot: com.scottgerstl.lupe.core.PageState) : LupeCore by base {
    override val page: kotlinx.coroutines.flow.StateFlow<com.scottgerstl.lupe.core.PageState> = kotlinx.coroutines.flow.MutableStateFlow(snapshot)
    override fun send(intent: Intent) {
        // this page is not the FM-1's any more: what would change its values, or pick things on it, is dropped
        if (intent is com.scottgerstl.lupe.core.SetParam || intent is com.scottgerstl.lupe.core.PickRoute || intent is com.scottgerstl.lupe.core.PickTile) return
        base.send(intent)
    }
}

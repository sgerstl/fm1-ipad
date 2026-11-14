package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.GoHome
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkPhase
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.page.PageTilesContent
import com.scottgerstl.lupe.ui.page.SoundDials
import com.scottgerstl.lupe.ui.page.isSoundFamily
import com.scottgerstl.lupe.ui.page.trackColour
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.slide.LocalBackGoesHome
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings
import com.scottgerstl.lupe.ui.sounds.LocalSoundsHost
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import kotlinx.coroutines.delay

/**
 * Under the header line (decision 28): one tab at a time, Pads · Edit · Timeline. The FM-1 drives what else shows: a sound page puts its
 * four dials in the Edit tab's dials area, or in a short panel that rises over the foot of Pads and the Timeline; GLO opens the Mix sheet,
 * SAVE the Sounds or Projects sheet, SEQ the Edit tab; HOME (the FM-1's, or the back gesture) puts things back. The FREE TAKE picker takes
 * the whole body while the FM-1 shows it.
 */
@Composable
fun ShellBody(shell: ShellState, core: LupeCore, modifier: Modifier = Modifier) {
    // Labs: the sound page can hold for 3 s after a touch on it, or be pinned (it stops following the FM-1)
    val labs = LocalPhoneSettings.current
    var touches by remember { mutableIntStateOf(0) }
    var phoneAsks by remember { mutableIntStateOf(0) }
    val followed = followed(shell.bottom, labs.pinBottom, labs.pauseFollowing, touches, phoneAsks)
    val shown = followed.first
    val frozen = followed.second
    val onSoundTouch = { touches++; Unit }
    // a change the phone itself asks for is never held; its core says so before sending
    val askCore = remember(core) { AskingCore(core) { phoneAsks++ } }
    val pads by core.pads.collectAsStateWithLifecycle()
    val editor by core.editor.collectAsStateWithLifecycle()
    val automation by core.automation.collectAsStateWithLifecycle()
    val freeTake by core.freeTake.collectAsStateWithLifecycle()
    // the picked step (decision 21) and the Edit tab's own view state live here, so they survive a visit to another tab
    val pick = remember { StepPick() }
    val editUi = remember { EditUi() }
    // a sound page opening or closing clears the pick (HOME then shows the sound knobs); a step tapped while one shows stays picked
    LaunchedEffect(shell.bottom.kind) { pick.step = null }

    // Decision 19: while a sound page shows (and only then), the back gesture is HOME on the FM-1.
    val soundUp = shown.kind == BottomKind.Page && isSoundFamily(shown.family)
    androidx.activity.compose.BackHandler(enabled = shell.bottom.kind == BottomKind.Page) { askCore.send(GoHome) }

    FollowFm1Screen(shell, core, editUi, touches, phoneAsks)

    // the page to draw, held as it was if Labs holds it while the FM-1 has moved on
    val live by core.page.collectAsStateWithLifecycle()
    var snap by remember { mutableStateOf(live) }
    LaunchedEffect(live, frozen) { if (!frozen) snap = live }
    val moved = frozen && (snap.family != live.family || snap.page != live.page)
    val soundCore: LupeCore = if (moved) remember(snap) { HeldPageCore(askCore, snap) } else askCore
    val soundPage = if (moved) snap else live
    val notice = if (moved) "The FM-1 is on ${live.family} · held here" else null

    CompositionLocalProvider(LocalBackGoesHome provides (shell.bottom.kind == BottomKind.Page)) {
        Box(modifier.fillMaxSize()) {
            LupeCrossfade(shell.bottom.kind == BottomKind.FreeTake, Modifier.fillMaxSize(), Dur.PANEL) { take ->
                if (take) com.scottgerstl.lupe.ui.freetake.FreeTakePicker(freeTake, core)
                else TabPager(shell.tab, Tok.track[(pads.selected.track - 1).coerceAtLeast(0) % Tok.track.size], labs.tabSlideMs) { tab ->
                    when (tab) {
                        Tab.Pads -> PadsPage(pads, core)
                        Tab.Edit -> Box(Modifier.fillMaxSize()) {
                            EditTab(editor, core, automation, pick, editUi, Modifier.countTouches(onSoundTouch), sound = if (soundUp) soundPage else null, soundCore = soundCore, notice = notice, graphics = labs.showGraphics)
                            // the FREE TAKE offer and the landing sit on top of the editor
                            com.scottgerstl.lupe.ui.freetake.TakeStrips(freeTake, core, Modifier.align(Alignment.TopCenter).padding(top = 2.dp))
                        }
                        Tab.Timeline -> TimelineSlot(core)
                    }
                }
            }
            // Pads and the Timeline: the sound page's header and dials in a short panel that rises only when the FM-1 changes page or a knob turns
            // on it, and leaves on HOME, a swipe down, or a few seconds after the last turn or touch (Scott, 2026-11-14)
            val panel = remember { SoundPanelModel() }
            panel.holdMs = labs.panelHoldSeconds * 1000L
            val linkNow by core.link.collectAsStateWithLifecycle()
            val linked = linkNow.phase == LinkPhase.Ready
            val pageKey = if (soundUp) "${soundPage.family}/${soundPage.page}" else null
            LaunchedEffect(linked) { if (!linked) panel.reset() }
            LaunchedEffect(pageKey, linked) { if (linked) panel.page(pageKey, System.currentTimeMillis()) }
            LaunchedEffect(live.turnSeq, live.turned, linked) { if (linked) panel.turn(live.turnSeq * 8 + live.turned, System.currentTimeMillis()) }
            // a Magnifier never outlives its dial: the tab changing or the panel falling takes it down (Scott's stuck ATTACK overlay)
            val magnifier = com.scottgerstl.lupe.ui.slide.LocalMagnifier.current
            LaunchedEffect(shell.tab, panel.up, shell.bottom.kind) { magnifier?.hideAll() }
            LaunchedEffect(panel.up, panel.deadline) { if (panel.up) { delay((panel.deadline - System.currentTimeMillis()).coerceAtLeast(0) + 20); panel.tick(System.currentTimeMillis()) } }
            SoundPanel(panel.up && pageKey != null && shell.tab != Tab.Edit && shell.bottom.kind != BottomKind.FreeTake, soundPage, soundCore, notice, { panel.dismiss() },
                Modifier.align(Alignment.BottomEnd).countTouches { panel.touch(System.currentTimeMillis()); onSoundTouch() }, graphics = labs.showGraphics)
        }
    }
}

/**
 * The tabs' pages slide in the tab's direction, and the track thread travels with them (the tab-thread mockup, Scott 2026-11-14): going right
 * (Pads → Edit → Timeline) the old page leaves to the left and the new one comes in from the right, and back the other way; ease-out over
 * [ms] (Labs, default 380), the outgoing page done at 85 % of the time. The selected track's band (its colour muted, decision 31) never leaves the
 * screen: it eases from its rectangle on the old tab (Pads: the track's row; Edit: the step row; Timeline: the lane) to the one on the new tab,
 * on the same curve, landing with the incoming page. No scale, no overshoot. With Reduce Motion the pages cross-fade (150 ms) and the outline
 * cross-fades between its two places.
 */
@Composable
private fun TabPager(tab: Tab, colour: androidx.compose.ui.graphics.Color, ms: Int, content: @Composable (Tab) -> Unit) {
    val reduce = LocalReduceMotion.current
    val anchors = remember { TrackAnchors() }
    var shown by remember { mutableStateOf(tab) }
    var from by remember { mutableStateOf<Tab?>(null) }
    var fromRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    val t = remember { androidx.compose.animation.core.Animatable(1f) }
    LaunchedEffect(tab, reduce) {
        if (tab == shown) return@LaunchedEffect
        from = shown; fromRect = anchors.rects[shown]; shown = tab
        t.snapTo(0f)
        com.scottgerstl.lupe.ui.theme.unscaled { t.animateTo(1f, androidx.compose.animation.core.tween(if (reduce) Dur.STATE else ms, easing = EaseOut)) }
        from = null
    }
    val dir = if ((from?.ordinal ?: shown.ordinal) <= shown.ordinal) 1f else -1f
    Box(Modifier.fillMaxSize().clipToBounds()) {
        // the thread while the pages move: the selected track's band easing from the old place to the new, behind both pages (their own
        // bands are hidden while they slide); with Reduce Motion, the two places cross-fading
        val a = fromRect; val b = anchors.rects[shown]
        if (from != null && (a != null || b != null)) androidx.compose.foundation.Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            val p = t.value; val band = trackBand(colour)
            fun fill(r: androidx.compose.ui.geometry.Rect, alpha: Float) = drawRoundRect(band.copy(alpha = alpha), Offset(r.left, r.top),
                androidx.compose.ui.geometry.Size(r.width, r.height), androidx.compose.ui.geometry.CornerRadius(10.dp.toPx()))
            when {
                reduce || a == null || b == null -> { a?.let { fill(it, 1f - p) }; b?.let { fill(it, p) } }   // nothing travels: each fades where it stands
                else -> fill(androidx.compose.ui.geometry.Rect(a.left + (b.left - a.left) * p, a.top + (b.top - a.top) * p, a.right + (b.right - a.right) * p, a.bottom + (b.bottom - a.bottom) * p), 1f)
            }
        }
        from?.let { old ->
            androidx.compose.runtime.key(old) {
                val page = remember { TabPage(old, anchors) }
                Box(Modifier.fillMaxSize().graphicsLayer { val out = (t.value / 0.85f).coerceAtMost(1f); if (reduce) alpha = 1f - t.value else { translationX = -dir * size.width * out; alpha = 1f - 0.4f * out } }
                    .onGloballyPositioned { page.box = it }.clearAndSetSemantics { }) {
                    CompositionLocalProvider(LocalTabPage provides page, LocalTabTravelling provides true) { content(old) }
                }
            }
        }
        androidx.compose.runtime.key(shown) {
            val page = remember { TabPage(shown, anchors) }
            Box(Modifier.fillMaxSize().graphicsLayer { if (from != null) { if (reduce) alpha = t.value else translationX = dir * size.width * (1f - t.value) } }.onGloballyPositioned { page.box = it }) {
                CompositionLocalProvider(LocalTabPage provides page, LocalTabTravelling provides (from != null)) { content(shown) }
            }
        }
    }
}

/** Counts each new touch down (Labs: pause following after a touch); the touch passes on unconsumed. */
private fun Modifier.countTouches(onTouch: () -> Unit) = pointerInput(Unit) {
    awaitPointerEventScope { while (true) { val e = awaitPointerEvent(PointerEventPass.Initial); if (e.changes.any { it.pressed && !it.previousPressed }) onTouch() } }
}

/**
 * The Timeline tab's slot. P4 owns ui/timeline and keeps `TimelinePage`'s signature for the landscape Timeline (agreed 2026-11-14), fed by
 * `rememberTimeline(core)`; it fills the box it is given.
 */
@Composable
private fun TimelineSlot(core: LupeCore) {
    val timeline = com.scottgerstl.lupe.ui.timeline.rememberTimeline(core)
    val top = core.top.collectAsStateWithLifecycle()
    com.scottgerstl.lupe.ui.timeline.TimelinePage(timeline.first, timeline.second, timeline.third, top)
}

/**
 * The sound page over Pads or the Timeline (decisions 25, 27, 28): the header and four dials, in a panel the dials' width at the right; a page
 * with tiles gets the full width for them. It rises from the bottom in 300 ms and falls in 200 (with Reduce Motion it only fades); a swipe down
 * on it (not on a dial) sends it away. It is a pane of its own for TalkBack, with Dismiss as an action. [reveal] 0…1 grows it to show the page's
 * picture under the dials (decision 30).
 */
@Composable
private fun SoundPanel(visible: Boolean, page: PageState, core: LupeCore, notice: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier, graphics: Boolean = true) {
    val reduce = LocalReduceMotion.current
    val t = animatedFloat(if (visible) 1f else 0f, if (visible) Dur.PANEL else Dur.FINGER, if (visible) EaseOut else EaseIn)
    var last by remember { mutableStateOf(page) }
    if (visible) last = page
    if (!visible && t.value <= 0.001f) return
    val colour = trackColour(last.track)
    val tiles = last.tiles
    // Show graphics: the page's picture is there from the start, under the dials; the panel is as tall as both
    val picture = com.scottgerstl.lupe.ui.page.pictureOf(last)
    val pictured = graphics && com.scottgerstl.lupe.ui.page.hasPicture(picture)
    val tall = animatedFloat(if (pictured) 1f else 0f, Dur.STATE)
    // It stands out from the page: the track's colour muted, 35 % over the page. Computed for all six track colours (2026-11-14): white text is
    // 6.7:1 or better on it, the raised grey of the labels 4.5:1 or better (lime is the least, 4.52), the track's own colour (the dials' arcs)
    // 3.6:1 or better. At 40 % the labels fall under 4.5:1 on yellow and lime, so 35 it is. A line in the track's colour marks its top edge.
    val surface = androidx.compose.ui.graphics.lerp(Tok.page, colour, PANEL_TINT)
    androidx.compose.foundation.layout.Column(
        modifier.then(if (tiles != null) Modifier.fillMaxWidth() else Modifier.width(444.dp)).height(134.dp + 118.dp * tall.value)
            .graphicsLayer { alpha = if (reduce) t.value else 1f; if (!reduce) translationY = (1f - t.value) * size.height; shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(topStart = 12.dp.toPx(), topEnd = 12.dp.toPx()); clip = true }
            .background(surface)
            .drawBehind { drawRect(colour, size = androidx.compose.ui.geometry.Size(size.width, 1.5.dp.toPx())) }
            // a swipe down that no dial took sends it away; taps on the panel don't reach the pads under it
            .pointerInput(Unit) {
                var total = 0f
                detectVerticalDragGestures(onDragStart = { total = 0f }, onDragEnd = { if (total > 32.dp.toPx()) onDismiss() }) { change, dy -> change.consume(); total += dy }
            }
            .pointerInput(Unit) { detectTapGestures { } }
            .semantics {
                paneTitle = "Sound page ${last.family}"; isTraversalGroup = true
                customActions = listOf(androidx.compose.ui.semantics.CustomAccessibilityAction("Dismiss the sound panel") { onDismiss(); true })
            }
            .padding(horizontal = 12.dp, vertical = 12.dp),
    ) {
        Row(Modifier.fillMaxWidth().height(110.dp)) {
            SoundDials(last, core, Modifier.width(420.dp).fillMaxHeight(), notice)
            if (tiles != null) {
                Spacer(Modifier.width(16.dp))
                PageTilesContent(tiles, colour, { core.send(com.scottgerstl.lupe.core.PickRoute(it)) }, { core.send(com.scottgerstl.lupe.core.PickTile(it)) }, Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(8.dp)))
            }
        }
        if (tall.value > 0.001f) {
            Spacer(Modifier.height(8.dp))
            com.scottgerstl.lupe.ui.page.GraphContent(picture, colour, if (last.turned >= 0 && last.turnSeq > 0) last.turned else -1,
                Modifier.then(if (tiles != null) Modifier.width(420.dp) else Modifier.fillMaxWidth()).height(110.dp).graphicsLayer { alpha = tall.value }.background(Tok.well, RoundedCornerShape(8.dp)).padding(4.dp))
        }
    }
}

/** How much of the track's colour the pop-up's surface carries over the page (see the contrast note in [SoundPanel]). */
internal const val PANEL_TINT = 0.35f

/**
 * The phone follows the FM-1's own GLO, SAVE and SEQ (fm1Screen): the Mix sheet, the Sounds sheet or Projects, the Edit tab with its lane
 * view or the Timeline. HOME or a sound family returns to where the phone was. Pause and Pin hold it as they hold sound pages. On a
 * (re)connect the link may pass through screens while it reads the FM-1: only changes seen once linked are followed, and only a screen that
 * stays 300 ms; the first screen seen is the baseline (a restart on FX must not open the Sounds sheet).
 */
@Composable
private fun FollowFm1Screen(shell: ShellState, core: LupeCore, editUi: EditUi, touches: Int, asks: Int) {
    val labs = LocalPhoneSettings.current
    val screenNow by core.fm1Screen.collectAsStateWithLifecycle()
    var lastScreen by remember { mutableStateOf(screenNow) }
    if (screenNow.key.isNotEmpty()) lastScreen = screenNow   // under a MENU or a held layer nothing changes here
    val screen = followed(lastScreen, labs.pinBottom, labs.pauseFollowing, touches, asks).first
    val place = remember { PlaceFollower() }
    val sheets = LocalSheetHost.current
    val sounds = LocalSoundsHost.current
    val pads by core.pads.collectAsStateWithLifecycle()
    val link by core.link.collectAsStateWithLifecycle()
    val linked = link.phase == LinkPhase.Ready
    LaunchedEffect(linked) { if (!linked) place.reset() }
    var settledKey by remember { mutableStateOf("") }
    LaunchedEffect(screen.key, screen.page, screen.title, linked) {
        if (!linked) return@LaunchedEffect
        // a new key must stay 300 ms (the link passes through screens as it connects); a page step within the key follows at once, after a
        // short settle so a fast run of presses on the FM-1 isn't answered page by page
        delay(if (screen.key != settledKey) 300 else 120)
        settledKey = screen.key
        place.follow(screen, PlaceNow(shell.tab, editUi.lane, sheets.open == SheetKind.Mix, sounds.request != null, sheets.open == SheetKind.Projects)).forEach { a ->
            when (a) {
                is PlaceAction.Tab -> core.send(Intent.SetTab(a.tab))
                is PlaceAction.Lane -> editUi.lane = a.on
                PlaceAction.OpenMix -> sheets.show(SheetKind.Mix)
                PlaceAction.CloseMix -> if (sheets.open == SheetKind.Mix) sheets.close()
                PlaceAction.OpenSounds -> sounds.open(pads.selected.track.coerceAtLeast(1))
                PlaceAction.CloseSounds -> sounds.close()
                is PlaceAction.SoundsView -> sounds.show(a.user)
                PlaceAction.ShowProjects -> sheets.show(SheetKind.Projects)
                PlaceAction.CloseProjects -> if (sheets.open == SheetKind.Projects) sheets.close()
            }
        }
    }
}

/**
 * What to show of something that follows the FM-1 ([actual]), and whether it is held. Labs: [pin] stops following altogether; [pause] holds
 * for 3 s after each counted touch, then catches up. A change the phone asked for ([asks]) is never held.
 */
@Composable
private fun <T> followed(actual: T, pin: Boolean, pause: Boolean, touches: Int, asks: Int): Pair<T, Boolean> {
    val m = remember { FollowModel(actual) }
    m.pin = pin; m.pause = pause
    val now = { System.currentTimeMillis() }
    LaunchedEffect(touches) { if (touches > 0) { m.touch(now()); delay(FollowModel.HOLD_MS + 20); m.tick(now()) } }
    LaunchedEffect(asks) { if (asks > 0) { m.ask(now()); m.onActual(actual, now()) } }
    LaunchedEffect(actual, pin, pause) { m.onActual(actual, now()); m.tick(now()) }
    return m.shown to m.frozen
}

/** The core as the sound page sees it: a change the phone asks for tells the follower first. */
private class AskingCore(private val base: LupeCore, private val asked: () -> Unit) : LupeCore by base {
    override fun send(intent: Intent) {
        if (intent is com.scottgerstl.lupe.core.PickRoute || intent is com.scottgerstl.lupe.core.PickTile || intent is com.scottgerstl.lupe.core.MixSectionPick || intent == GoHome) asked()
        base.send(intent)
    }
}

/**
 * A sound page while Labs holds it and the FM-1 has moved on: frozen as it was and read-only (a value set now would land on the FM-1's page,
 * not this one).
 */
private class HeldPageCore(private val base: LupeCore, snapshot: PageState) : LupeCore by base {
    override val page: kotlinx.coroutines.flow.StateFlow<PageState> = kotlinx.coroutines.flow.MutableStateFlow(snapshot)
    override fun send(intent: Intent) {
        if (intent is com.scottgerstl.lupe.core.SetParam || intent is com.scottgerstl.lupe.core.PickRoute || intent is com.scottgerstl.lupe.core.PickTile) return
        base.send(intent)
    }
}

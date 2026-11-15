package com.scottgerstl.lupe.ui.shell

import com.scottgerstl.lupe.core.withPlayhead
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.size
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
    val editorArea by core.editor.collectAsStateWithLifecycle()
    // the playhead comes in its own area now (P1, 2026-11-15): one small send per step, and the editor area changes only with its content
    val playheadArea by core.playhead.collectAsStateWithLifecycle()
    val editor = remember(editorArea, playheadArea) { editorArea.withPlayhead(playheadArea) }
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

    // The sound panel, docked at the right of all three tabs (decision 32, the iPad's rule): it comes in when the FM-1 changes to a sound page
    // (its own sound key, or the phone's rail) or a knob turns on one, and stays until HOME, its close key or another tab. No timeout.
    val panel = remember { SoundPanelModel() }
    val linkNow by core.link.collectAsStateWithLifecycle()
    val linked = linkNow.phase == LinkPhase.Ready
    val pageKey = if (soundUp) "${soundPage.family}/${soundPage.page}" else null
    LaunchedEffect(linked) { if (!linked) panel.reset() }
    LaunchedEffect(pageKey, linked) { if (linked) panel.page(pageKey) }
    LaunchedEffect(live.turnSeq, live.turned, linked) { if (linked) panel.turn(live.turnSeq * 8 + live.turned) }
    // another tab shuts it (the first tab seen is only where the app opened)
    var tabSeen by remember { mutableStateOf(shell.tab) }
    LaunchedEffect(shell.tab) { if (shell.tab != tabSeen) { tabSeen = shell.tab; panel.dismiss() } }
    val docked = panel.up && pageKey != null && shell.bottom.kind != BottomKind.FreeTake
    val dockT = animatedFloat(if (docked) 1f else 0f, if (docked) Dur.PANEL else Dur.FINGER, if (docked) EaseOut else EaseIn)
    // a Magnifier never outlives its dial: the tab changing or the panel leaving takes it down (Scott's stuck ATTACK overlay)
    val magnifier = com.scottgerstl.lupe.ui.slide.LocalMagnifier.current
    LaunchedEffect(shell.tab, panel.up, shell.bottom.kind) { magnifier?.hideAll() }
    // Settings › Sound keys: the rail down the right edge takes its width from every tab; the panel docks beside it
    val rail = labs.soundKeys && shell.bottom.kind != BottomKind.FreeTake

    CompositionLocalProvider(LocalBackGoesHome provides (shell.bottom.kind == BottomKind.Page)) {
        // right-handed: the sound keys and the panel on the right; left-handed: the keys on the left (Settings › Handedness). The panel stays on
        // the right, where board 75 has it.
        val railNode: @Composable () -> Unit = {
            SoundKeysRail(open = if (docked) soundPage.family else null, onKey = { family ->
                // the open family's key again steps its pages, as on the FM-1; another opens that family (the FM-1 goes there and the panel follows)
                askCore.send(com.scottgerstl.lupe.core.PickPage(family, railTarget(family, if (docked) soundPage.family else null, soundPage.pages.map { it.index }, soundPage.page)))
            })
        }
        Row(modifier.fillMaxSize()) {
            if (rail && labs.leftHanded) { railNode(); Spacer(Modifier.width(4.dp)) }
            Box(Modifier.weight(1f).fillMaxHeight()) {
                LupeCrossfade(shell.bottom.kind == BottomKind.FreeTake, Modifier.fillMaxSize(), Dur.PANEL) { take ->
                    if (take) com.scottgerstl.lupe.ui.freetake.FreeTakePicker(freeTake, core)
                    else TabPager(shell.tab, Tok.track[(pads.selected.track - 1).coerceAtLeast(0) % Tok.track.size], labs.tabSlideMs) { tab ->
                        when (tab) {
                            Tab.Pads -> PadsPage(pads, core)
                            Tab.Edit -> Box(Modifier.fillMaxSize()) {
                                // the grid keeps its step width and scrolls under the docked panel (decision 35, B)
                                EditTab(editor, core, automation, pick, editUi, Modifier.countTouches(onSoundTouch), soundDock = DOCK_W * dockT.value)
                                // the FREE TAKE offer and the landing sit on top of the editor
                                com.scottgerstl.lupe.ui.freetake.TakeStrips(freeTake, core, Modifier.align(Alignment.TopCenter).padding(top = 2.dp))
                            }
                            Tab.Timeline -> TimelineSlot(core)
                            Tab.Mix -> { val mix = com.scottgerstl.lupe.ui.mix.rememberMix(core); val meters = core.meters.collectAsStateWithLifecycle()
                                com.scottgerstl.lupe.ui.mix.MixTab(mix.first, mix.second, meters) }
                        }
                    }
                }
                SoundPanel(dockT.value, docked, soundPage, soundCore, notice, { panel.dismiss() }, Modifier.align(Alignment.TopEnd).countTouches(onSoundTouch), graphics = labs.showGraphics)
            }
            if (rail && !labs.leftHanded) { Spacer(Modifier.width(4.dp)); railNode() }
        }
    }
}

/**
 * Settings › Sound keys (decision 32, board 75.4): a 48 dp rail down the right edge, FX SEL ENV LFO EDIT ARP in the iPad's order, so the phone
 * can open the sound panel too. The open family's key is lit in the track's colour. A key sends the FM-1 to that family (a write: nothing
 * happens while the link is read-only), and the panel follows the FM-1 as always.
 */
@Composable
private fun SoundKeysRail(open: String?, onKey: (String) -> Unit) {
    androidx.compose.foundation.layout.Column(Modifier.width(48.dp).fillMaxHeight().semantics { isTraversalGroup = true }, verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(4.dp)) {
        for (family in SOUND_KEYS) {
            val on = family == open
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Key({ onKey(family) }, "$family sound pages", width = 48.dp, height = 40.dp, minTarget = 44.dp, on = on, role = androidx.compose.ui.semantics.Role.Button,
                    state = if (on) "Open: again for its next page" else null) { fg -> KeyLabel(family, fg, style = com.scottgerstl.lupe.ui.theme.LupeType.key.copy(fontSize = 12.sp)) }
            }
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
 * The docked sound panel (decisions 25, 27, 30, 32; board 75): the FM-1's page as a header, four dials, its tiles if it has any, and its picture
 * under them when Show graphics is on, in a panel [DOCK_W] wide down the right side, tinted with the track's muted colour. It slides in from the
 * right in 300 ms and out in 200 ([t] 0…1; with Reduce Motion it only fades). Its close key, or a swipe to the right that no dial took, shuts
 * it. It is a pane of its own for TalkBack, with Close as an action.
 */
@Composable
private fun SoundPanel(t: Float, visible: Boolean, page: PageState, core: LupeCore, notice: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier, graphics: Boolean = true) {
    val reduce = LocalReduceMotion.current
    var last by remember { mutableStateOf(page) }
    if (visible) last = page
    if (t <= 0.001f) return
    val colour = trackColour(last.track)
    val tiles = last.tiles
    val picture = com.scottgerstl.lupe.ui.page.pictureOf(last)
    val pictured = graphics && com.scottgerstl.lupe.ui.page.hasPicture(picture)
    // It stands out from the page: the track's colour muted, 35 % over the page. Computed for all six track colours (2026-11-14): white text is
    // 6.7:1 or better on it, the raised grey of the labels 4.5:1 or better (lime is the least, 4.52), the track's own colour (the dials' arcs)
    // 3.6:1 or better. At 40 % the labels fall under 4.5:1 on yellow and lime, so 35 it is. A line in the track's colour marks its left edge.
    val surface = androidx.compose.ui.graphics.lerp(Tok.page, colour, PANEL_TINT)
    androidx.compose.foundation.layout.Column(
        modifier.width(DOCK_W).fillMaxHeight()
            .graphicsLayer { alpha = if (reduce) t else 1f; if (!reduce) translationX = (1f - t) * size.width; shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(12.dp.toPx()); clip = true }
            .background(surface)
            .drawBehind { drawRect(colour, size = androidx.compose.ui.geometry.Size(1.5.dp.toPx(), size.height)) }
            // a swipe to the right that no dial took shuts it; taps on the panel don't reach what is under it
            .pointerInput(Unit) {
                var total = 0f
                detectHorizontalDragGestures(onDragStart = { total = 0f }, onDragEnd = { if (total > 32.dp.toPx()) onDismiss() }) { change, dx -> change.consume(); total += dx }
            }
            .pointerInput(Unit) { detectTapGestures { } }
            .semantics {
                paneTitle = "Sound page ${last.family}"; isTraversalGroup = true
                customActions = listOf(androidx.compose.ui.semantics.CustomAccessibilityAction("Close the sound panel") { onDismiss(); true })
            }
            .padding(12.dp),
    ) {
        SoundDials(last, core, Modifier.fillMaxWidth().height(110.dp), notice, trailing = {
            Key(onDismiss, "Close the sound panel", width = 32.dp, height = 28.dp, minTarget = 32.dp) { fg ->
                androidx.compose.foundation.Canvas(Modifier.size(9.dp)) { val w = 1.5.dp.toPx(); drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), w, androidx.compose.ui.graphics.StrokeCap.Round); drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), w, androidx.compose.ui.graphics.StrokeCap.Round) }
            }
        })
        if (tiles != null) {
            Spacer(Modifier.height(8.dp))
            PageTilesContent(tiles, colour, { core.send(com.scottgerstl.lupe.core.PickRoute(it)) }, { core.send(com.scottgerstl.lupe.core.PickTile(it)) }, Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(8.dp)))
        }
        // Show graphics: the page's picture, under the dials, in what height is left
        if (pictured) {
            Spacer(Modifier.height(8.dp))
            LupeCrossfade(picture.kind to last.page, Modifier.fillMaxWidth().weight(1f), Dur.STATE) { _ ->
                com.scottgerstl.lupe.ui.page.GraphContent(picture, colour, if (last.turned >= 0 && last.turnSeq > 0) last.turned else -1, Modifier.fillMaxSize().background(Tok.well, RoundedCornerShape(8.dp)).padding(4.dp))
            }
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

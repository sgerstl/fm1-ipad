package com.scottgerstl.lupe.ui.shell

import androidx.compose.ui.layout.boundsInWindow

import androidx.compose.ui.semantics.role

import androidx.compose.ui.semantics.contentDescription

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
import kotlinx.coroutines.launch

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
    // GLO's shared pages (DELAY, REVERB, CHORUS, GLOBAL) are sound pages too (decision 44): the panel's page is made from the core's `mix` area
    val mixNow by core.mix.collectAsStateWithLifecycle()
    val screenLive by core.fm1Screen.collectAsStateWithLifecycle()
    // hybrid UI (2026-11-17): GLO's shared pages are the Mix tab's sub-pages now, not the docked panel's (decision 44 superseded by the agreed map)
    val gloPage: PageState? = null
    val selName = pads.rows.firstOrNull { it.track == pads.selected.track }?.name?.substringAfter(" · ").orEmpty()
    androidx.activity.compose.BackHandler(enabled = shell.bottom.kind == BottomKind.Page || gloPage != null) { askCore.send(GoHome) }

    FollowFm1Screen(shell, core, editUi, touches, phoneAsks)

    // the page to draw, held as it was if Labs holds it while the FM-1 has moved on
    val live by core.page.collectAsStateWithLifecycle()
    var snap by remember { mutableStateOf(live) }
    LaunchedEffect(live, frozen) { if (!frozen) snap = live }
    val moved = frozen && (snap.family != live.family || snap.page != live.page)
    val soundCore0: LupeCore = if (moved) remember(snap) { HeldPageCore(askCore, snap) } else askCore
    val soundPage0 = if (moved) snap else live
    val notice = if (moved && gloPage == null) "The FM-1 is on ${live.family} · held here" else null
    val glo = gloPage != null
    val soundPage = gloPage ?: soundPage0
    val gloCore = remember(askCore) { GloCore(askCore) }
    val soundCore = if (glo) gloCore else soundCore0

    // The sound panel, docked at the right of all three tabs (decision 32, the iPad's rule): it comes in when the FM-1 changes to a sound page
    // (its own sound key, or the phone's rail) or a knob turns on one, and stays until HOME, its close key or another tab. No timeout.
    val panel = remember { SoundPanelModel() }
    val linkNow by core.link.collectAsStateWithLifecycle()
    val linked = linkNow.phase == LinkPhase.Ready
    val pageKey = if (glo) "GLO/${screenLive.page}" else if (soundUp) "${soundPage.family}/${soundPage.page}" else null
    LaunchedEffect(linked) { if (!linked) panel.reset() }
    LaunchedEffect(pageKey, linked) { if (linked) panel.page(pageKey) }
    LaunchedEffect(live.turnSeq, live.turned, linked) { if (linked) panel.turn(live.turnSeq * 8 + live.turned) }
    // another tab shuts it (the first tab seen is only where the app opened)
    var tabSeen by remember { mutableStateOf(shell.tab) }
    LaunchedEffect(shell.tab) { if (shell.tab != tabSeen) { tabSeen = shell.tab; panel.dismiss() } }
    val docked = panel.up && pageKey != null && shell.bottom.kind != BottomKind.FreeTake
    val dockT = animatedFloat(if (docked) 1f else 0f, if (docked) Dur.PANEL else Dur.FINGER, if (docked) EaseOut else EaseIn)
    // closing the panel (its handle, a swipe, TalkBack's action) does what the close key did (sound-panel B5): it shuts, and the FM-1 goes back to
    // the tab's own place: GLO's page on Mix, HOME elsewhere
    val closePanel: () -> Unit = {
        panel.dismiss()
        if (linked) {
            if (shell.tab == Tab.Mix) { val i = com.scottgerstl.lupe.ui.mix.EFFECT_KEYS.indexOf(mixNow.section) + 1
                askCore.send(com.scottgerstl.lupe.core.ScreenGoto("GLO", com.scottgerstl.lupe.core.ScreenPages.GLO.getOrNull(i.coerceAtLeast(0))?.first)) }
            else askCore.send(GoHome)
        }
    }
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
                val fm1Family = if (glo) "GLO" else if (soundUp) soundPage0.family else null
                // a shut panel with the FM-1 already on that family's page: the FM-1 won't change, so the panel is simply shown
                if (railKeyAction(family, if (docked) soundPage.family else null, fm1Family) == RailKeyAction.Show) { panel.show(); return@SoundKeysRail }
                // GLO opens the Mix tab; pressed again there, it steps GLO's pages (the agreed map, 2026-11-17)
                if (family == "GLO") { val onMix = shell.tab == Tab.Mix; if (!onMix) askCore.send(Intent.SetTab(Tab.Mix))
                    askCore.send(com.scottgerstl.lupe.core.ScreenGoto("GLO", gloStep(onMix, screenLive))); return@SoundKeysRail }
                askCore.send(com.scottgerstl.lupe.core.PickPage(family, railTarget(family, if (docked) soundPage.family else null, soundPage.pages.map { it.index }, soundPage.page)))
            })
        }
        Row(modifier.fillMaxSize()) {
            if (rail && labs.railLeft) { railNode(); Spacer(Modifier.width(4.dp)) }
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
                                com.scottgerstl.lupe.ui.freetake.TakeStrips(freeTake, core, Modifier.align(Alignment.TopCenter).padding(top = 2.dp), showOffer = labs.takeOffer == com.scottgerstl.lupe.ui.slide.PhoneSettings.TAKE_POPUP)
                            }
                            Tab.Timeline -> TimelineSlot(core)
                            Tab.Mix -> { val mix = com.scottgerstl.lupe.ui.mix.rememberMix(core); val meters = core.meters.collectAsStateWithLifecycle()
                                // Mixer · Effects: the shared pages as effect cards (direction C, 2026-11-17), replacing the bus dials
                                val launch = com.scottgerstl.lupe.ui.mix.MixLaunch(core.pads.collectAsStateWithLifecycle(), core.clock.collectAsStateWithLifecycle())
                                androidx.compose.runtime.CompositionLocalProvider(com.scottgerstl.lupe.ui.mix.LocalMixLaunch provides launch) {
                                    com.scottgerstl.lupe.ui.mix.MixTab(mix.first, mix.second, meters, soundDock = DOCK_W * dockT.value, graphics = labs.showGraphics) } }
                        }
                    }
                }
                SoundPanel(dockT.value, docked, soundPage, soundCore, notice, closePanel, Modifier.align(Alignment.TopEnd).countTouches(onSoundTouch), graphics = labs.showGraphics)
            }
            if (rail && !labs.railLeft) { Spacer(Modifier.width(4.dp)); railNode() }
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
 * The tab change (Scott, 2026-11-17: tab motion "b and c"). **B, fade-through:** the outgoing page fades out in 90 ms (ease-in) while the
 * incoming one fades in over 210 ms (ease-out) and settles from 98 % to full size on the spatial spring. **C, Edit grows out of the pad:** when
 * Edit was opened from a pad's or a Timeline block's "Edit steps" ([LocalEditGrow] holds its bounds), a surface grows from that pad to the page
 * (panel fill, a 2 dp edge in its colour, the pad's colour over it fading in the first ~120 ms; spatial spring, bounce 0.15, ~420 ms; the corner
 * from the pad's to the page's), Edit's content fading in over the last ~200 ms and Pads fading out under it. The selected track's band
 * (decision 29) still travels between its places on both tabs, over the fade. Reduce Motion: a plain 150 ms cross-fade.
 */
@Composable
private fun TabPager(tab: Tab, colour: androidx.compose.ui.graphics.Color, ms: Int, content: @Composable (Tab) -> Unit) {
    val reduce = LocalReduceMotion.current
    val anchors = remember { TrackAnchors() }
    val grow = LocalEditGrow.current
    var shown by remember { mutableStateOf(tab) }
    var from by remember { mutableStateOf<Tab?>(null) }
    var fromRect by remember { mutableStateOf<androidx.compose.ui.geometry.Rect?>(null) }
    var origin by remember { mutableStateOf<EditOrigin?>(null) }
    var shrink by remember { mutableStateOf(false) }   // Edit → Pads: Edit shrinks back into the pad (the reverse of C)
    var pagerBox by remember { mutableStateOf<androidx.compose.ui.layout.LayoutCoordinates?>(null) }
    val t = remember { androidx.compose.animation.core.Animatable(1f) }       // the band's travel, 0…1
    val outA = remember { androidx.compose.animation.core.Animatable(1f) }    // the outgoing page
    val inA = remember { androidx.compose.animation.core.Animatable(1f) }     // the incoming page
    val inS = remember { androidx.compose.animation.core.Animatable(1f) }     // the incoming page's scale (B)
    val g = remember { androidx.compose.animation.core.Animatable(1f) }       // the grow (C), 0 pad … 1 page
    val m = com.scottgerstl.lupe.ui.theme.hybridMotion
    LaunchedEffect(tab, reduce) {
        if (tab == shown) return@LaunchedEffect
        from = shown; fromRect = anchors.rects[shown]; shown = tab
        // C: from a menu's "Edit steps", or (round 12, Scott: "the same animation as when edit is selected from the long press menu") the Edit tab
        // tapped on Pads, out of the selected track's pad when it's in view; back to Pads, into it. Otherwise fade-through.
        val menuOrigin = grow.take()
        val box = pagerBox?.takeIf { it.isAttached }?.boundsInWindow()
        fun inView(o: EditOrigin?) = o?.takeIf { box != null && it.rect.left >= box.left - 1f && it.rect.right <= box.right + 1f && it.rect.top >= box.top - 1f && it.rect.bottom <= box.bottom + 1f }
        shrink = !reduce && tab == Tab.Pads && from == Tab.Edit && inView(grow.selectedPad) != null
        origin = when {
            reduce -> null
            tab == Tab.Edit -> menuOrigin ?: if (from == Tab.Pads) inView(grow.selectedPad) else null
            shrink -> inView(grow.selectedPad)
            else -> null
        }
        t.snapTo(0f); outA.snapTo(1f); inA.snapTo(0f); inS.snapTo(if (reduce || origin != null) 1f else 0.98f); g.snapTo(if (shrink) 1f else 0f)
        com.scottgerstl.lupe.ui.theme.unscaled {
            kotlinx.coroutines.coroutineScope {
                when {
                    reduce -> {
                        launch { outA.animateTo(0f, androidx.compose.animation.core.tween(Dur.STATE)) }
                        launch { inA.animateTo(1f, androidx.compose.animation.core.tween(Dur.STATE)) }
                        launch { t.animateTo(1f, androidx.compose.animation.core.tween(Dur.STATE)) }
                    }
                    shrink -> {
                        // the reverse: Edit fades quickly, the surface shrinks from the page into the pad, Pads fades in under it
                        launch { g.animateTo(0f, com.scottgerstl.lupe.ui.theme.lupeSpring(420, 0.15f)) }
                        launch { outA.animateTo(0f, androidx.compose.animation.core.tween(100, easing = EaseIn)) }
                        launch { kotlinx.coroutines.delay(60); inA.animateTo(1f, androidx.compose.animation.core.tween(260, easing = EaseOut)) }
                        launch { t.animateTo(1f, androidx.compose.animation.core.tween(420, easing = EaseOut)) }
                    }
                    origin != null -> {
                        launch { g.animateTo(1f, com.scottgerstl.lupe.ui.theme.lupeSpring(420, 0.15f)) }
                        launch { outA.animateTo(0f, androidx.compose.animation.core.tween(300, easing = EaseIn)) }
                        launch { kotlinx.coroutines.delay(220); inA.animateTo(1f, androidx.compose.animation.core.tween(200, easing = EaseOut)) }
                        launch { t.animateTo(1f, androidx.compose.animation.core.tween(420, easing = EaseOut)) }
                    }
                    else -> {
                        launch { outA.animateTo(0f, androidx.compose.animation.core.tween(90, easing = EaseIn)) }
                        launch { inA.animateTo(1f, androidx.compose.animation.core.tween(210, easing = EaseOut)) }
                        launch { inS.animateTo(1f, m.spatial()) }
                        launch { t.animateTo(1f, androidx.compose.animation.core.tween(maxOf(210, minOf(ms, 380)), easing = EaseOut)) }
                    }
                }
            }
        }
        from = null; origin = null; shrink = false
    }
    Box(Modifier.fillMaxSize().clipToBounds().onGloballyPositioned { pagerBox = it }) {
        from?.let { old ->
            androidx.compose.runtime.key(old) {
                val page = remember { TabPage(old, anchors) }
                Box(Modifier.fillMaxSize().graphicsLayer { alpha = outA.value }.onGloballyPositioned { page.box = it }.clearAndSetSemantics { }) {
                    CompositionLocalProvider(LocalTabPage provides page, LocalTabTravelling provides true) { content(old) }
                }
            }
        }
        // C: the surface growing out of the pad (under the incoming page), or shrinking back into it (over Pads, landing on the pad)
        val surface: @Composable () -> Unit = {
            val o = origin
            if (o != null && from != null) androidx.compose.foundation.Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
                val box = pagerBox?.takeIf { it.isAttached } ?: return@Canvas
                val tl = box.windowToLocal(o.rect.topLeft); val br = box.windowToLocal(o.rect.bottomRight)
                val k = g.value
                val l = tl.x + (0f - tl.x) * k; val tp = tl.y + (0f - tl.y) * k
                val r = br.x + (size.width - br.x) * k; val b = br.y + (size.height - br.y) * k
                val rad = (o.radiusDp + (20f - o.radiusDp) * k.coerceIn(0f, 1f)).dp.toPx()
                val shape = androidx.compose.ui.geometry.CornerRadius(rad)
                val sz = androidx.compose.ui.geometry.Size((r - l).coerceAtLeast(1f), (b - tp).coerceAtLeast(1f))
                // growing: it hands over to Edit's content as that fades in; shrinking: it fades as it reaches the pad
                val fade = if (shrink) (k / 0.25f).coerceIn(0f, 1f) else (1f - inA.value)
                val tint = if (shrink) fade * (1f - (k / 0.3f).coerceIn(0f, 1f)) else fade * (1f - (k / 0.3f).coerceIn(0f, 1f))
                drawRoundRect(Tok.panel.copy(alpha = fade), Offset(l, tp), sz, shape)
                drawRoundRect(o.colour.copy(alpha = tint), Offset(l, tp), sz, shape)
                drawRoundRect(o.colour.copy(alpha = fade), Offset(l + 1.dp.toPx(), tp + 1.dp.toPx()), androidx.compose.ui.geometry.Size(sz.width - 2.dp.toPx(), sz.height - 2.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(rad - 1.dp.toPx()), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
            }
        }
        if (!shrink) surface()
        // the band, travelling between its places over the fade (both pages hide their own while it does)
        val a = fromRect; val bb = anchors.rects[shown]
        if (from != null && (a != null || bb != null)) androidx.compose.foundation.Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            val p = t.value; val band = trackBand(colour)
            fun fill(rr: androidx.compose.ui.geometry.Rect, alpha: Float) = drawRoundRect(band.copy(alpha = alpha), Offset(rr.left, rr.top),
                androidx.compose.ui.geometry.Size(rr.width, rr.height), androidx.compose.ui.geometry.CornerRadius(10.dp.toPx()))
            when {
                reduce || a == null || bb == null -> { a?.let { fill(it, 1f - p) }; bb?.let { fill(it, p) } }
                else -> fill(androidx.compose.ui.geometry.Rect(a.left + (bb.left - a.left) * p, a.top + (bb.top - a.top) * p, a.right + (bb.right - a.right) * p, a.bottom + (bb.bottom - a.bottom) * p), 1f)
            }
        }
        androidx.compose.runtime.key(shown) {
            val page = remember { TabPage(shown, anchors) }
            Box(Modifier.fillMaxSize().graphicsLayer { if (from != null) { alpha = inA.value; scaleX = inS.value; scaleY = inS.value } }.onGloballyPositioned { page.box = it }) {
                CompositionLocalProvider(LocalTabPage provides page, LocalTabTravelling provides (from != null)) { content(shown) }
            }
        }
        if (shrink) surface()
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
    // GLO's pages are neutral grey (decision 44), the others the track's colour
    val glo = last.family == "GLO"
    val colour = if (glo) Tok.text3 else trackColour(last.track)
    val inkColour = if (glo) Tok.text2Raised else colour
    val tiles = last.tiles
    val compactTiles = tiles != null && tiles.kind == "pick" && tiles.labels.size <= 4
    val picture = com.scottgerstl.lupe.ui.page.pictureOf(last)
    // decision 46: the FM-1's own picture, drawn by Skiff's code, where SkiffDraw can (its build, its pages); else the hand-drawn one
    val skiff = com.scottgerstl.lupe.ui.page.rememberSkiffPicture(last, glo, enabled = graphics)
    val pictured = graphics && (skiff != null || com.scottgerstl.lupe.ui.page.hasPicture(picture))
    // It stands out from the page: the track's colour muted, 35 % over the page. Computed for all six track colours (2026-11-14): white text is
    // 6.7:1 or better on it, the raised grey of the labels 4.5:1 or better (lime is the least, 4.52), the track's own colour (the dials' arcs)
    // 3.6:1 or better. At 40 % the labels fall under 4.5:1 on yellow and lime, so 35 it is. A line in the track's colour marks its left edge.
    Box(
        modifier.width(DOCK_W).fillMaxHeight()
            // hybrid UI (spec 4.3): `panel`, its left corners at the sheet radius, beside the grid rather than over it; no border, no track tint
            .graphicsLayer { alpha = if (reduce) t else 1f; if (!reduce) translationX = (1f - t) * size.width; shape = RoundedCornerShape(topStart = com.scottgerstl.lupe.ui.theme.Shape.sheet, bottomStart = com.scottgerstl.lupe.ui.theme.Shape.sheet); clip = true }
            .background(Tok.panel)
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
    ) {
        // the grab handle (Scott, 2026-11-17: no close key; EN 301 549 / WCAG 2.5.1: a swipe needs a single-tap way too): tap it to close, drag it to swipe
        PanelHandle("Close the sound panel", onDismiss, Modifier.align(Alignment.CenterStart))
        androidx.compose.foundation.layout.Column(Modifier.fillMaxSize().padding(start = 14.dp, end = 12.dp, top = 12.dp, bottom = 12.dp)) {
        // the header: the page and, at its right end, "3 of 7" (the close key is gone)
        SoundDials(last, core, Modifier.fillMaxWidth().height(110.dp), notice, count = true)
        // the tiles and the picture share what height is left. A page whose knob picks from a list of names (MOD's routes, LANES, SOUND,
        // OPERATOR's six) keeps Lupe's tappable tiles; the FM-1's own picture (decision 46) goes under them only while it gets at least 2×
        // the FM-1's pixels (276 px) in its half, otherwise the tiles have the space alone: they're the controls, the picture repeats them
        androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxWidth().weight(1f)) {
            val roomy = com.scottgerstl.lupe.ui.page.skiffBesideTiles(with(androidx.compose.ui.platform.LocalDensity.current) { (maxHeight - 16.dp).toPx() })
            val showPicture = pictured && (skiff == null || tiles == null || compactTiles || roomy)
            androidx.compose.foundation.layout.Column(Modifier.fillMaxSize()) {
            if (tiles != null) {
                Spacer(Modifier.height(8.dp))
                // a single row of choices (MONO / STEREO / PING-PONG) is only as tall as a row; the picture under it takes the rest. A long list (MOD's routes, SOUND's tiles) shares the height.
                PageTilesContent(tiles, inkColour, { core.send(com.scottgerstl.lupe.core.PickRoute(it)) }, { core.send(com.scottgerstl.lupe.core.PickTile(it)) },
                    (if (compactTiles) Modifier.fillMaxWidth().height(56.dp) else Modifier.fillMaxWidth().weight(1f)).clip(RoundedCornerShape(8.dp)))
            }
            // Show graphics: the page's picture, under the dials, in what height is left
            if (showPicture) {
                Spacer(Modifier.height(8.dp))
                LupeCrossfade(picture.kind to last.page, Modifier.fillMaxWidth().weight(1f), Dur.STATE) { _ ->
                    val turned = if (last.turned >= 0 && last.turnSeq > 0) last.turned else -1
                    val said = "${last.title}: " + if (com.scottgerstl.lupe.ui.page.hasPicture(picture)) com.scottgerstl.lupe.ui.page.describe(picture) else "the FM-1's picture"
                    if (skiff != null) com.scottgerstl.lupe.ui.page.SkiffPictureImage(skiff, said, Modifier.fillMaxSize().background(Tok.well, RoundedCornerShape(8.dp)).padding(4.dp))
                    else if (tiles == null) com.scottgerstl.lupe.ui.page.GraphContent(picture, inkColour, turned, Modifier.fillMaxSize().background(Tok.well, RoundedCornerShape(8.dp)).padding(4.dp))
                    else androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        // under a row of tiles the picture takes all the height that is left, at the FM-1's 936 : 552 where the width allows, centred
                        val ratio = 936f / 552f
                        val w = minOf(maxWidth.value, maxHeight.value * ratio).dp
                        com.scottgerstl.lupe.ui.page.GraphContent(picture, inkColour, turned, Modifier.width(w).height(w / ratio).background(Tok.well, RoundedCornerShape(8.dp)).padding(4.dp))
                    }
                }
            }
            }
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
    LaunchedEffect(shell.tab) { place.noteTab(shell.tab) }
    var settledKey by remember { mutableStateOf("") }
    LaunchedEffect(screen.key, screen.page, screen.title, linked) {
        if (!linked) return@LaunchedEffect
        // a new key must stay 300 ms (the link passes through screens as it connects); a page step within the key follows at once, after a
        // short settle so a fast run of presses on the FM-1 isn't answered page by page
        delay(if (screen.key != settledKey) 300 else 120)
        settledKey = screen.key
        place.follow(screen, PlaceNow(shell.tab, editUi.lane, sheets.open == SheetKind.Mix, sounds.request != null, sheets.open == SheetKind.Projects, homeAsked = PhoneHome.recent())).forEach { a ->
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

/** When the phone itself last sent the FM-1 HOME: the HOME that comes back moves no tab (a panel closed on Edit stays on Edit). */
internal object PhoneHome { @Volatile var askedAt = 0L; const val WINDOW_MS = 1500L
    fun recent(): Boolean = android.os.SystemClock.uptimeMillis() - askedAt < WINDOW_MS }

/** The core as the sound page sees it: a change the phone asks for tells the follower first. */
private class AskingCore(private val base: LupeCore, private val asked: () -> Unit) : LupeCore by base {
    override fun send(intent: Intent) {
        if (intent == GoHome) PhoneHome.askedAt = android.os.SystemClock.uptimeMillis()
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

/** The GLO key's next page: off the Mix tab, the page the FM-1 last showed there (MIXER at first); on it, the next of GLO's five, round again. */
internal fun gloStep(onMix: Boolean, screen: com.scottgerstl.lupe.core.Fm1ScreenState): Int {
    val pages = com.scottgerstl.lupe.core.ScreenPages.GLO.map { it.first }
    val at = if (screen.key == "GLO") pages.indexOf(screen.page) else -1
    return if (!onMix) pages[at.coerceAtLeast(0)] else pages[(at + 1).mod(pages.size)]
}

/**
 * A docked panel's grab handle (Scott, 2026-11-17; EN 301 549 / WCAG 2.5.1): a 4 × 36 rounded bar in the raised grey, vertically centred on the
 * panel's leading edge, in a 24 × 48 touch area that takes no header space. A tap closes the panel exactly as the swipe does; a drag on it is the
 * swipe (the panel's own); it shows the panel can be swiped away. TalkBack: a button named [description].
 */
@Composable
internal fun PanelHandle(description: String, onClose: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier.width(24.dp).height(48.dp)
            .semantics(mergeDescendants = true) { role = androidx.compose.ui.semantics.Role.Button; contentDescription = description }
            .pointerInput(Unit) { detectTapGestures { onClose() } }
            .drawBehind { val w = 4.dp.toPx(); val h = 36.dp.toPx(); drawRoundRect(Tok.text2Raised, Offset((size.width - w) / 2 - 4.dp.toPx(), (size.height - h) / 2), androidx.compose.ui.geometry.Size(w, h), androidx.compose.ui.geometry.CornerRadius(w / 2)) },
    )
}

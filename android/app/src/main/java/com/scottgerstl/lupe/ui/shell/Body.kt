package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.isTraversalGroup
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
                else LupeCrossfade(shell.tab, Modifier.fillMaxSize(), Dur.STATE) { tab ->
                    when (tab) {
                        Tab.Pads -> PadsPage(pads, core)
                        Tab.Edit -> Box(Modifier.fillMaxSize()) {
                            EditTab(editor, core, automation, pick, editUi, Modifier.countTouches(onSoundTouch), sound = if (soundUp) soundPage else null, soundCore = soundCore, notice = notice)
                            // the FREE TAKE offer and the landing sit on top of the editor
                            com.scottgerstl.lupe.ui.freetake.TakeStrips(freeTake, core, Modifier.align(Alignment.TopCenter).padding(top = 2.dp))
                        }
                        Tab.Timeline -> TimelineSlot(core)
                    }
                }
            }
            // Pads and the Timeline: the sound page's header and dials in a short panel that rises over the lower rows; HOME lowers it
            SoundPanel(soundUp && shell.tab != Tab.Edit && shell.bottom.kind != BottomKind.FreeTake, soundPage, soundCore, notice, Modifier.align(Alignment.BottomCenter).countTouches(onSoundTouch))
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
 * The sound page over Pads or the Timeline (decisions 25, 27, 28): the header and four dials, and tiles beside them where a knob picks from
 * names. It rises from the bottom in 300 ms and leaves in 200 (with Reduce Motion it only fades). It is a pane of its own for TalkBack.
 */
@Composable
private fun SoundPanel(visible: Boolean, page: PageState, core: LupeCore, notice: String?, modifier: Modifier = Modifier) {
    val reduce = LocalReduceMotion.current
    val t = animatedFloat(if (visible) 1f else 0f, if (visible) Dur.PANEL else Dur.FINGER, if (visible) EaseOut else EaseIn)
    var last by remember { mutableStateOf(page) }
    if (visible) last = page
    if (!visible && t.value <= 0.001f) return
    val colour = trackColour(last.track)
    Row(
        modifier.fillMaxWidth().height(134.dp)
            .graphicsLayer { alpha = if (reduce) t.value else 1f; if (!reduce) translationY = (1f - t.value) * size.height; shadowElevation = 12.dp.toPx(); shape = RoundedCornerShape(topStart = 12.dp.toPx(), topEnd = 12.dp.toPx()); clip = true }
            .background(Tok.panel)
            .pointerInput(Unit) { detectTapGestures { } }   // taps on the panel don't reach the pads under it
            .semantics { paneTitle = "Sound page ${last.family}"; isTraversalGroup = true }
            .padding(horizontal = 12.dp, vertical = 12.dp),
    ) {
        SoundDials(last, core, Modifier.width(420.dp).fillMaxHeight(), notice)
        last.tiles?.let { tiles ->
            Spacer(Modifier.width(16.dp))
            PageTilesContent(tiles, colour, { core.send(com.scottgerstl.lupe.core.PickRoute(it)) }, { core.send(com.scottgerstl.lupe.core.PickTile(it)) }, Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(8.dp)))
        }
    }
}

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
    LaunchedEffect(screen.key, screen.page, linked) {
        if (!linked) return@LaunchedEffect
        delay(300)
        place.follow(screen, PlaceNow(shell.tab, editUi.lane, sheets.open == SheetKind.Mix, sounds.request != null, sheets.open == SheetKind.Projects)).forEach { a ->
            when (a) {
                is PlaceAction.Tab -> core.send(Intent.SetTab(a.tab))
                is PlaceAction.Lane -> editUi.lane = a.on
                PlaceAction.OpenMix -> sheets.show(SheetKind.Mix)
                PlaceAction.CloseMix -> if (sheets.open == SheetKind.Mix) sheets.close()
                PlaceAction.OpenSounds -> sounds.open(pads.selected.track.coerceAtLeast(1))
                PlaceAction.CloseSounds -> sounds.close()
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

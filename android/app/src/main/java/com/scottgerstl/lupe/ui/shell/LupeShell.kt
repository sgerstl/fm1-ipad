package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import com.scottgerstl.lupe.ui.projects.ProjectsSheet
import com.scottgerstl.lupe.ui.projects.rememberProjects
import com.scottgerstl.lupe.ui.settings.SettingsSheet
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sounds.LocalSoundsHost
import com.scottgerstl.lupe.ui.sounds.SoundsHost
import com.scottgerstl.lupe.ui.sheet.SheetHost
import com.scottgerstl.lupe.ui.slide.LocalMagnifier
import com.scottgerstl.lupe.ui.slide.MagnifierHost
import com.scottgerstl.lupe.ui.slide.MagnifierState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.LinkPhase
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * The whole screen in landscape (decision 28, boards 73 and 74): one header line with the tabs in it, a hairline, then the tab's body. It only reads the core's areas and
 * sends intents. The page behind a lost card is read-only and hidden from TalkBack.
 */
@Composable
fun LupeShell(core: LupeCore) {
    val link by core.link.collectAsStateWithLifecycle()
    val top by core.top.collectAsStateWithLifecycle()
    val shell by core.shell.collectAsStateWithLifecycle()
    val reduce = LocalReduceMotion.current

    var everReady by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(link.phase) { if (link.phase == LinkPhase.Ready) everReady = true }
    val mode = linkMode(link, everReady)

    // the page behind a link card or the no-FM-1 card (the header stays above it, decision 33) is greyed and read-only
    val grey = animatedFloat(if (mode != LinkMode.Normal) 1f else 0f, Dur.PANEL)
    val page = animatedFloat(if (mode == LinkMode.Page) 1f else 0f, Dur.PANEL)
    val card = animatedFloat(if (mode == LinkMode.Card) 1f else 0f, if (mode == LinkMode.Card) 250 else Dur.EXIT, if (mode == LinkMode.Card) EaseOut else EaseIn)
    // keep what the card/page said while they leave
    var lastLink by remember { mutableStateOf(link) }
    if (mode != LinkMode.Normal) lastLink = link


    val magnifier = remember { MagnifierState() }
    val sheets = remember { SheetHost() }
    val soundsHost = remember { SoundsHost() }
    val holdMenu = remember { HoldMenuState() }
    val padDrag = remember { PadDragState() }
    // the app strip's one message (MessageStrip.kt; Scott, 2026-11-17, messages rule): what was there when the screen opened is not news
    val messages = remember(core) { MessageModel(core.notice.value.seq, core.pads.value.clearUndo.lastOrNull()) }
    val firmwareHost = remember { com.scottgerstl.lupe.ui.firmware.FirmwareHost() }
    // a debug build can be launched with a pad already held over the wells, to look at them without a finger:
    // adb shell am start -n com.scottgerstl.lupe/.MainActivity --ez wellsDemo true --ef x 1000 --ef y 540  (the finger's place, px)
    val ctx = androidx.compose.ui.platform.LocalContext.current
    androidx.compose.runtime.LaunchedEffect(Unit) {
        val i = (ctx as? android.app.Activity)?.intent
        if (i != null && (ctx.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0 && i.getBooleanExtra("wellsDemo", false)) {
            padDrag.drag = PadDrag(2, 1, false, 7, Tok.track[1], androidx.compose.ui.geometry.Size(240f, 120f), androidx.compose.ui.geometry.Offset(120f, 60f),
                androidx.compose.ui.geometry.Offset(i.getFloatExtra("x", 1000f), i.getFloatExtra("y", 540f)), "B")
        }
    }
    val sheetOpen = sheets.open != null
    Box(Modifier.fillMaxSize().background(Tok.page)) {
      CompositionLocalProvider(LocalMagnifier provides magnifier, LocalSheetHost provides sheets, LocalSoundsHost provides soundsHost, LocalHoldMenu provides holdMenu, LocalPadDrag provides padDrag, com.scottgerstl.lupe.ui.firmware.LocalFirmwareHost provides firmwareHost, LocalMessages provides messages) {
        Column(
            Modifier.fillMaxSize()
                .greyedBy { grey.value }
                .then(if (mode != LinkMode.Normal || sheetOpen) Modifier.clearAndSetSemantics { } else Modifier),
        ) {
            // Landscape (decisions 28 and 29). The content runs to a 16 dp margin on both sides and ignores the camera's hole punch; only a navigation
            // bar at the side (three-button navigation) and the gesture bar at the bottom are kept clear, by the window's own insets. The status bar
            // is hidden while Lupe runs. At the right the round keys sit inside the display's rounded corner.
            val sides = WindowInsets.navigationBars.only(WindowInsetsSides.Horizontal)
            TopBar(top, core, shell.tab, { core.send(com.scottgerstl.lupe.core.Intent.SetTab(it)) },
                Modifier.windowInsetsPadding(sides).padding(start = 8.dp, end = cornerInset(), top = 4.dp))
            // the hairline that ends the header runs the full width
            Box(Modifier.fillMaxWidth().padding(top = 3.dp).height(1.dp).background(Tok.control))
            ShellBody(shell, core, Modifier.windowInsetsPadding(sides).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom)).padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 4.dp))
        }
      }

        if (page.value > 0.001f || card.value > 0.001f || mode != LinkMode.Normal) {
            // read-only: swallow touches over the held page
            Box(Modifier.fillMaxSize().pointerInput(mode) {
                if (mode != LinkMode.Normal) awaitPointerEventScope { while (true) awaitPointerEvent().changes.forEach { it.consume() } }
            })
        }

        if (page.value > 0.001f) {
            LinkPage(lastLink, core, Modifier.windowInsetsPadding(WindowInsets.navigationBars.only(WindowInsetsSides.Horizontal)).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Bottom)).graphicsLayer { alpha = page.value })
        }
        if (card.value > 0.001f) {
            LinkCard(
                lastLink,
                Modifier.windowInsetsPadding(WindowInsets.safeDrawing).padding(top = 60.dp).graphicsLayer {
                    alpha = card.value
                    if (!reduce) translationY = -(1f - card.value) * 96.dp.toPx()
                },
            )
        }
        // the sheets (FM-1 menu › Projects…, Settings) rise over the page and its link states
        CompositionLocalProvider(LocalMagnifier provides magnifier, LocalSheetHost provides sheets, LocalSoundsHost provides soundsHost, LocalHoldMenu provides holdMenu, LocalPadDrag provides padDrag, LocalMessages provides messages) {
            SettingsSheet(link, fake = core is com.scottgerstl.lupe.core.FakeLupeCore)
            ProjectsSheet(rememberProjects(core))
            // Patterns (decision 38, board 79): the song-name menu, the full-pool notice and an empty slot's menu open it
            com.scottgerstl.lupe.ui.patterns.PatternsSheet(core)
            // Sounds: for a track (its head on Pads, or SAVE on the FM-1) or one pad's own sound. The browser has its own heading and Done.
            var lastRequest by remember { mutableStateOf(soundsHost.request) }
            soundsHost.request?.let { lastRequest = it }
            com.scottgerstl.lupe.ui.sheet.LupeSheet(soundsHost.request != null, "Sounds", { soundsHost.close() }, fixed = 320.dp, showTitle = false) {
                lastRequest?.let { com.scottgerstl.lupe.ui.sounds.SoundsBrowser(core, it, { soundsHost.close() }) }
            }
        }
        // the app strip (Scott, 2026-11-17, messages rule): every refusal, Undo and confirmation, one at a time, bottom centre 12 dp above the
        // foot, over the page and over a sheet when one is up
        CompositionLocalProvider(LocalSheetHost provides sheets) {
            MessageStrip(core, messages,
                Modifier.align(androidx.compose.ui.Alignment.BottomCenter).windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom)).padding(horizontal = 16.dp).padding(bottom = 12.dp))
        }
        // a pad being dragged, with the Clear / Edit / Duplicate wells on the screen's edges (board 81.4)
        PadDragOverlay(padDrag, top.playing)
        // the hold menu: over the page and the sheets, under the finger that opened it
        HoldMenuHost(holdMenu)
        // installing Skiff-Lupe (decision 42): the offer, the confirm and, while it runs, the cover over everything
        com.scottgerstl.lupe.ui.firmware.FirmwareLayer(core, firmwareHost)
        // the Magnifier floats over everything, above the finger
        MagnifierHost(magnifier)
    }
}

/**
 * How far in from the right edge the header's last round key (Play: a 40 dp circle in a 48 dp box, its centre 28 dp below the top) must sit to
 * be wholly inside the display's rounded corner. From the corner's own radius (Android's RoundedCorner); 32 dp where the system gives none.
 */
@Composable
private fun cornerInset(): androidx.compose.ui.unit.Dp {
    val view = androidx.compose.ui.platform.LocalView.current
    val density = androidx.compose.ui.platform.LocalDensity.current
    val corner = view.rootWindowInsets?.getRoundedCorner(android.view.RoundedCorner.POSITION_TOP_RIGHT)?.radius ?: return 32.dp
    val r = with(density) { corner.toDp() }.value
    return headerCornerInset(r).dp
}

/**
 * The geometry, in dp: the circle's upper right (45°) must lie inside the corner's curve with 2 dp to spare. [radius] is the corner's; the result
 * is the inset of the key's 48 dp box from the screen edge. Never under 24: at 8 dp Play was cut off on the Pixel 10 (Scott, 2026-11-14), whose
 * real corner is tighter than the circle the system reports, so the result also carries 6 dp over the geometry.
 */
internal fun headerCornerInset(radius: Float): Float {
    val keyR = 20f; val centreY = 28f; val boxPad = 4f; val spare = 2f
    val py = centreY - keyR * 0.7071f                     // the 45° point's distance below the top
    if (radius <= py) return 24f                           // the corner's curve ends above it
    val reach = kotlin.math.sqrt(((radius - spare) * (radius - spare) - (radius - py) * (radius - py)).coerceAtLeast(0f))
    return (radius - reach - boxPad - keyR + keyR * 0.7071f + 6f).coerceAtLeast(24f)
}

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
import androidx.compose.foundation.layout.statusBarsPadding
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
import com.scottgerstl.lupe.ui.page.FollowFm1Divider
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

/**
 * The whole screen (boards 53 and 54): top bar, then the divided body. It only reads the core's areas and
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

    val grey = animatedFloat(if (mode == LinkMode.Card) 1f else 0f, Dur.PANEL)
    val page = animatedFloat(if (mode == LinkMode.Page) 1f else 0f, Dur.PANEL)
    val card = animatedFloat(if (mode == LinkMode.Card) 1f else 0f, if (mode == LinkMode.Card) 250 else Dur.EXIT, if (mode == LinkMode.Card) EaseOut else EaseIn)
    // keep what the card/page said while they leave
    var lastLink by remember { mutableStateOf(link) }
    if (mode != LinkMode.Normal) lastLink = link

    FollowFm1Divider(shell, core)

    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    val magnifier = remember { MagnifierState() }
    val sheets = remember { SheetHost() }
    val soundsHost = remember { SoundsHost() }
    val sheetOpen = sheets.open != null
    Box(Modifier.fillMaxSize().background(Tok.page)) {
      CompositionLocalProvider(LocalMagnifier provides magnifier, LocalSheetHost provides sheets, LocalSoundsHost provides soundsHost) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding()
                .greyedBy { grey.value }
                .then(if (mode != LinkMode.Normal || sheetOpen) Modifier.clearAndSetSemantics { } else Modifier),
        ) {
            TopBar(top, core, Modifier.padding(top = 0.dp))
            androidx.compose.foundation.layout.Spacer(Modifier.height(6.dp))
            // the bottom ~24 dp stays clear for the home gesture; board 53 ends the body 32 dp up
            ShellBody(shell, core, Modifier.padding(bottom = maxOf(navBottom, 24.dp) + 8.dp))
        }
      }

        if (page.value > 0.001f || card.value > 0.001f || mode != LinkMode.Normal) {
            // read-only: swallow touches over the held page
            Box(Modifier.fillMaxSize().pointerInput(mode) {
                if (mode != LinkMode.Normal) awaitPointerEventScope { while (true) awaitPointerEvent().changes.forEach { it.consume() } }
            })
        }

        if (page.value > 0.001f) {
            LinkPage(lastLink, core, Modifier.statusBarsPadding().graphicsLayer { alpha = page.value })
        }
        if (card.value > 0.001f) {
            LinkCard(
                lastLink,
                Modifier.statusBarsPadding().padding(top = 52.dp).graphicsLayer {
                    alpha = card.value
                    if (!reduce) translationY = -(1f - card.value) * 96.dp.toPx()
                },
            )
        }
        // the sheets (FM-1 menu › Projects…, Settings) rise over the page and its link states
        CompositionLocalProvider(LocalSheetHost provides sheets) {
            SettingsSheet(link)
            val projects = rememberProjects(core)
            ProjectsSheet(projects.first, projects.second)
        }
        // the Magnifier floats over everything, above the finger
        MagnifierHost(magnifier)
    }
}

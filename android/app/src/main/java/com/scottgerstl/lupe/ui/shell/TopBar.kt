package com.scottgerstl.lupe.ui.shell

import androidx.compose.ui.draw.clip

import androidx.compose.foundation.background

import androidx.compose.foundation.shape.RoundedCornerShape

import androidx.compose.ui.graphics.graphicsLayer

import androidx.compose.foundation.interaction.collectIsPressedAsState

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlin.math.roundToInt
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LaunchQuantize
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PlaybackMode
import com.scottgerstl.lupe.core.TopState
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.LupeCrossfade
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.Shape
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.ui.theme.animatedFloat

private fun TopState.tempoText(): String = if (tempo % 1.0 == 0.0) tempo.toInt().toString() else "%.1f".format(tempo)
private val LaunchQuantize.word get() = name
private val PlaybackMode.word get() = name

/**
 * The one header line, hybrid UI (Scott, 2026-11-17; spec 4.1): the Song menu as a `lifted` pill, the four tabs as connected pills, then flush
 * right the Bar ⌄ pill (Launch at), the readout, Record (round 48) and Play/Stop (round 56, the view's white key and its largest). 56 tall; the
 * space between the tabs and Bar grows. At narrow widths it gives way in the spec's order and never drops a tab, Record or Play/Stop:
 * (1) the song name truncates to 96, (2) the tabs' padding goes 16 → 12, (3) the readout's second line goes (the readout's menu still has the
 * tempo), (4) the Bar pill tightens to 12/6.
 */
@Composable
fun TopBar(top: TopState, core: LupeCore, tab: com.scottgerstl.lupe.core.Tab, onTab: (com.scottgerstl.lupe.core.Tab) -> Unit, modifier: Modifier = Modifier) {
    var menu by remember { mutableStateOf<Menu?>(null) }
    androidx.compose.foundation.layout.BoxWithConstraints(modifier.fillMaxWidth().height(56.dp)) {
    val give = headerGiveWay(maxWidth.value)
    Row(
        Modifier.fillMaxWidth().height(56.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // the Song menu: Projects…, Settings, Labs and the rest (decision 33's song-name menu)
        Box {
            val projects by core.projects.collectAsStateWithLifecycle()
            val project = top.project.ifEmpty { projects.name.ifEmpty { "FM-1" } }   // the core's top.project stays empty until a save or load; projects knows it
            HeaderPill({ menu = Menu.Fm1 }, "Song menu, project $project", project, textMax = if (give >= 1) 96.dp else 140.dp)
            LupeMenu(menu == Menu.Fm1, { menu = null }) {
                val sheets = LocalSheetHost.current
                MenuRow("Projects…", { menu = null; sheets.show(SheetKind.Projects) })
                // the shared effects are the Mix tab's sub-pages now (hybrid UI, 2026-11-17)
                MenuRow("Shared effects…", { menu = null; onTab(com.scottgerstl.lupe.core.Tab.Mix); core.send(com.scottgerstl.lupe.core.ScreenGoto("GLO", com.scottgerstl.lupe.core.ScreenPages.GLO[1].first)) }, sub = "Delay, reverb, chorus, global")
                val firmwareHost = com.scottgerstl.lupe.ui.firmware.LocalFirmwareHost.current
                val fw by core.firmware.collectAsStateWithLifecycle()
                MenuRow("FM-1 firmware…", { menu = null; firmwareHost?.info = true }, sub = com.scottgerstl.lupe.ui.firmware.firmwareLine(fw))
                MenuRow("Settings", { menu = null; sheets.show(SheetKind.Settings) })
                MenuRow("Labs", { menu = null; sheets.show(SheetKind.Settings, labs = true) }, sub = "Settings to try")
                // Patterns… (decision 38, board 79): the pool's sheet, where unused patterns are cleared; a way in from the empty slot's menu and the full-pool notice too
                val poolNow by core.patterns.collectAsStateWithLifecycle()
                MenuRow("Patterns…", { menu = null; sheets.showPatterns() }, sub = if (poolNow.kept > 0) "${poolNow.kept} kept · ${poolNow.unused} unused" else "The FM-1's 64 pattern numbers")
                // Play through the phone (as the iPhone's "Play through the iPhone"): the FM-1's USB audio to the phone's output
                com.scottgerstl.lupe.audio.LocalAudioThrough.current?.let { through ->
                    MenuDivider()
                    MenuRow("Play through the phone", { menu = null; through.choose(!through.enabled) }, checked = through.enabled,
                        sub = if (through.enabled) through.summary else "The FM-1's sound on the phone's speaker or headphones")
                }
                val demo = LocalDemo.current
                if (demo.inDemo) { MenuDivider(); MenuRow("Leave the demo", { menu = null; demo.leave() }, sub = "Back to looking for your FM-1") }
                if (core is FakeLupeCore) FakeMenu(core) { menu = null }
            }
        }
        Spacer(Modifier.width(12.dp))
        // the tabs: Pads · Edit · Timeline · Mix, connected pills
        Tabs(tab, onTab, padH = if (give >= 2) 12.dp else 16.dp)
        // the space that grows (a mock bug once left the room at the far right instead)
        Spacer(Modifier.weight(1f).width(12.dp))
        // Launch at: the Bar ⌄ pill, outlined; the waiting count as a small disc on it
        Box {
            HeaderPill({ menu = Menu.Launch }, "Launch at ${top.launch.word}" + if (top.waiting > 0) ", ${top.waiting} waiting" else "", top.launch.word, outlined = true,
                padStart = if (give >= 4) 12.dp else 16.dp, padEnd = if (give >= 4) 6.dp else 12.dp, badge = if (top.waiting > 0) "${top.waiting}" else null)
            LupeMenu(menu == Menu.Launch, { menu = null }) {
                MenuHeading("Launch at")
                LaunchQuantize.entries.forEach { q ->
                    MenuRow(q.word, { core.send(Intent.SetLaunch(q)); menu = null }, checked = top.launch == q)
                }
                // the iPhone's footer (decision 33): always there, so Cancel waiting is where you saw it last
                MenuDivider()
                if (top.waiting > 0) MenuRow("Cancel waiting", { core.send(Intent.CancelWaiting); menu = null }, sub = "${top.waiting} launch${if (top.waiting == 1) "" else "es"} waiting")
                else MenuRow("Nothing waiting", {}, enabled = false)
            }
        }
        Spacer(Modifier.width(12.dp))
        // Readout: bar · beat over the tempo; opens the tempo slide and Loop · Song · Once (Android's menu: which popup the phones keep is phone-header I6, open)
        Box {
            Column(
                Modifier
                    .defaultMinSize(minWidth = 64.dp, minHeight = 48.dp)
                    .semantics(mergeDescendants = true) {
                        role = Role.Button
                        contentDescription = "Bar ${top.bar}, beat ${top.beat}, ${top.tempoText()} beats per minute, ${top.mode.word}. Opens tempo and playback mode"
                    }
                    .clickable { menu = Menu.Readout },
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.Center,
            ) {
                BasicText("${top.bar}·${top.beat}", style = LupeType.number.copy(fontSize = 26.sp, lineHeight = 26.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold))
                if (give < 3) BasicText("${top.tempoText()} bpm · ${top.mode.word}", style = LupeType.small.copy(color = Tok.text2Raised), maxLines = 1)
            }
            LupeMenu(menu == Menu.Readout, { menu = null }, alignEnd = true, width = 240.dp) {
                // the tempo is a value you slide (decision 10: no steppers anywhere); double tap puts it back to what it was when the menu opened
                val opened = remember(menu == Menu.Readout) { top.tempo.roundToInt() }
                com.scottgerstl.lupe.ui.slide.MenuSlideRow("TEMPO · BPM", top.tempoText(), top.tempo.roundToInt(), 20, 300, "Tempo", stepDp = 9f, revertTo = opened) { core.send(Intent.SetTempo(it.toDouble())) }
                MenuDivider()
                MenuHeading("Playback")
                PlaybackMode.entries.forEach { m ->
                    MenuRow(m.word, { core.send(Intent.SetPlaybackMode(m)) }, checked = top.mode == m)
                }
            }
        }
        // a played phrase on offer (FREE TAKE), as a chip beside Record when Settings › Offer played phrases is Chip (Scott, 2026-11-18)
        TakeChip(core)
        Spacer(Modifier.width(12.dp))
        // Record: round 48, `lifted` with the red dot (22); latched, it fills REC red and the dot goes dark (shape: the dot never moves)
        TransportKey({ core.send(Intent.Rec) }, "Record", Shape.record, primary = false, lit = top.rec, role = Role.Switch, state = if (top.rec) "On" else "Off") { fg ->
            Canvas(Modifier.size(22.dp)) { drawCircle(fg) }
        }
        Spacer(Modifier.width(8.dp))
        // Play/Stop: round 56, the white key; the icon is the state (▶ stopped, ■ playing)
        TransportKey({ core.send(if (top.playing) Intent.Stop else Intent.Play) }, if (top.playing) "Stop" else "Play", Shape.playStop, primary = true) { fg ->
            val stop = animatedFloat(if (top.playing) 1f else 0f, Dur.STATE)
            PlayStopIcon(stop.value, fg, iconSize = if (top.playing) 20.dp else 22.dp)
        }
    }
    }
}

/**
 * How far the header gives way at [widthDp] (spec 4.1): 0 none, then each step in order. The row as drawn needs about 760; the steps win
 * about 44, 32, 0 (height only: the readout's width is its number) and 10. Never a tab, Record or Play/Stop.
 */
internal fun headerGiveWay(widthDp: Float): Int = when {
    widthDp >= 790f -> 0
    widthDp >= 750f -> 1
    widthDp >= 720f -> 2
    widthDp >= 700f -> 3
    else -> 4
}

private enum class Menu { Fm1, Launch, Readout }

/** Only while the core is the fake: jump to a link state or a bottom page, to try the shell without an FM-1. */
@Composable
private fun FakeMenu(core: FakeLupeCore, close: () -> Unit) {
    MenuDivider()
    MenuHeading("Fake core (no FM-1)")
    // step through a family's pages as the FM-1's key would (the phone has no page row any more): for looking at each page's picture
    for (fam in listOf("FX", "LFO", "EDIT", "SEL")) MenuRow("$fam: next page", { val p = core.page.value; val same = p.family == fam; val at = p.pages.indexOfFirst { it.index == p.page }
        core.send(com.scottgerstl.lupe.core.PickPage(fam, if (same && p.pages.isNotEmpty()) p.pages[(at + 1).mod(p.pages.size)].index else null)); close() })
    MenuRow("FM-1: all 64 patterns taken", { core.fillPool(core.pads.value.patternsFree != 0); close() }, checked = core.pads.value.patternsFree == 0, sub = "New pattern is refused, as Skiff does")
    MenuRow("FM-1 refuses (stopped only)", { core.refuse("Stop to change this: Skiff does it only while stopped"); close() })
    core.scenarioNames.forEach { MenuRow("Play “$it”", { core.play(it); close() }) }
    MenuRow("FM-1 knob 1 up (locks CUTOFF)", { core.fm1Knob(1, 1); close() })
    MenuRow("FM-1 knob 2 up (locks DECAY)", { core.fm1Knob(2, 1); close() })
    MenuRow("Firmware: stock Skiff 2.6 offer", { core.showFirmwareOffer("install"); close() })
    MenuRow("Firmware: SLOOP offer", { core.showFirmwareOffer("sloop"); close() })
    MenuRow("Firmware: update offer", { core.showFirmwareOffer("update"); close() })
    MenuRow("Firmware: finish offer", { core.showFirmwareOffer("finish"); close() })
    MenuRow("Firmware: foreign loader", { core.showFirmwareOffer("foreign"); close() })
    MenuRow("Firmware: no offer", { core.showFirmwareOffer(null); close() })
    MenuRow("Bottom: editor", { core.showBottom(com.scottgerstl.lupe.core.BottomPage()); close() })
    listOf("ENV" to "ENV", "LFO" to "LFO", "FX" to "REVERB").forEach { (fam, page) ->
        MenuRow("Bottom: $fam page", { core.showBottom(com.scottgerstl.lupe.core.BottomPage(com.scottgerstl.lupe.core.BottomKind.Page, fam, page)); close() })
    }
}


/**
 * The FM-1's FREE TAKE offer as a chip by Record (Scott, 2026-11-18): a track-colour dot and the note count. It scales in once on the spring and
 * doesn't pulse; a newer offer changes the count; it goes when the offer expires or is taken. A tap opens the picker (Keep that). It covers nothing.
 */
@Composable
private fun TakeChip(core: com.scottgerstl.lupe.core.LupeCore) {
    val phone = com.scottgerstl.lupe.ui.slide.LocalPhoneSettings.current
    val take by core.freeTake.collectAsStateWithLifecycle()
    val offer = take.offer?.takeIf { phone.takeOffer == com.scottgerstl.lupe.ui.slide.PhoneSettings.TAKE_CHIP && !it.refused }
    var last by remember { mutableStateOf<com.scottgerstl.lupe.core.TakeOffer?>(null) }
    if (offer != null) last = offer
    val reduce = com.scottgerstl.lupe.ui.theme.LocalReduceMotion.current
    val inT by com.scottgerstl.lupe.ui.theme.springFloat(if (offer != null) 1f else 0f, if (offer != null) 380 else 150, if (offer != null) 0.3f else 0f, spring = !reduce && offer != null)
    val shown = last ?: return
    if (inT <= 0.01f && offer == null) return
    val messages = LocalMessages.current
    val colour = Tok.track[(shown.track - 1).coerceAtLeast(0) % Tok.track.size]
    val source = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val press by com.scottgerstl.lupe.ui.theme.pressScale(pressed, reduce)
    Spacer(Modifier.width(8.dp))
    Row(
        Modifier.height(32.dp)
            .graphicsLayer { val k = if (reduce) 1f else inT.coerceIn(0f, 1.2f); scaleX = k * press; scaleY = k * press; alpha = inT.coerceIn(0f, 1f) }
            .clip(RoundedCornerShape(50)).background(Tok.held)
            .semantics(mergeDescendants = true) { role = Role.Button; contentDescription = "Played phrase on track ${shown.track}, ${shown.notes} note${if (shown.notes == 1) "" else "s"}. Double-tap to keep it" }
            .clickable(source, null, enabled = offer != null) {
                if (shown.canStart) core.send(com.scottgerstl.lupe.core.TakeStart) else messages.refuse("The FM-1 can't open its picker from here. Press SHIFT + SAVE on the FM-1 to keep it.")
            }
            .padding(start = 10.dp, end = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.size(10.dp).background(colour, androidx.compose.foundation.shape.CircleShape))
        BasicText("${shown.notes}", style = LupeType.number.copy(fontSize = 15.sp, lineHeight = 16.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold), maxLines = 1)
    }
}

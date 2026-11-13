package com.scottgerstl.lupe.ui.shell

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
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat

private fun TopState.tempoText(): String = if (tempo % 1.0 == 0.0) tempo.toInt().toString() else "%.1f".format(tempo)
private val LaunchQuantize.word get() = name
private val PlaybackMode.word get() = name

/**
 * Board 53's top bar: the FM-1 key ⌄, Launch ⌄, REC, Play, the readout ⌄. Keys draw at 44 dp as on the board
 * and answer to 48 dp. The row is 6 dp in from each edge so the drawn keys sit 8 dp from them.
 */
@Composable
fun TopBar(top: TopState, core: LupeCore, modifier: Modifier = Modifier) {
    var menu by remember { mutableStateOf<Menu?>(null) }
    Row(
        modifier.fillMaxWidth().padding(horizontal = 6.dp).height(48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // FM-1 key: Projects…, Settings, Labs. Later phases fill them in (P5, Labs); none exist yet, so they say so.
        Box {
            val projects by core.projects.collectAsStateWithLifecycle()
            val project = top.project.ifEmpty { projects.name.ifEmpty { "FM-1" } }   // the core's top.project stays empty until a save or load; projects knows it
            Key({ menu = Menu.Fm1 }, "FM-1 menu, project $project", width = 128.dp) { fg -> MenuLabel(project, fg, textMax = 98.dp) }
            LupeMenu(menu == Menu.Fm1, { menu = null }) {
                val sheets = LocalSheetHost.current
                MenuRow("Projects…", { menu = null; sheets.show(SheetKind.Projects) })
                MenuRow("Settings", { menu = null; sheets.show(SheetKind.Settings) })
                MenuRow("Labs", { menu = null; sheets.show(SheetKind.Settings, labs = true) }, sub = "Settings to try")
                if (core is FakeLupeCore) FakeMenu(core) { menu = null }
            }
        }
        Spacer(Modifier.width(4.dp))
        // Launch: how a launch waits (Loop Bar Beat Now), and what is waiting
        Box {
            Key({ menu = Menu.Launch }, "Launch quantize, ${top.launch.word}" + if (top.waiting > 0) ", ${top.waiting} waiting" else "", width = 96.dp) { fg ->
                MenuLabel(top.launch.word, fg, sub = if (top.waiting > 0) "${top.waiting} waiting" else null)
            }
            LupeMenu(menu == Menu.Launch, { menu = null }) {
                MenuHeading("Launch at")
                LaunchQuantize.entries.forEach { q ->
                    MenuRow(q.word, { core.send(Intent.SetLaunch(q)); menu = null }, checked = top.launch == q)
                }
                if (top.waiting > 0) {
                    MenuDivider()
                    MenuRow("Cancel waiting", { core.send(Intent.CancelWaiting); menu = null }, sub = "${top.waiting} launch${if (top.waiting == 1) "" else "es"} waiting")
                }
            }
        }
        Spacer(Modifier.weight(1f))
        // REC
        // On, REC latches: the key fills with REC red and the dot goes dark (6:1); off, a red dot on the key.
        Key({ core.send(Intent.Rec) }, "Record", on = top.rec, role = Role.Switch, state = if (top.rec) "On" else "Off",
            litTop = Tok.rec, litEdge = lerp(Tok.rec, Tok.chicletEdge, 0.5f)) { _ ->
            val lit = animatedFloat(if (top.rec) 1f else 0f, Dur.STATE)
            Canvas(Modifier.size(14.dp)) { drawCircle(lerp(Tok.rec, Tok.onColour, lit.value)) }
        }
        Spacer(Modifier.width(4.dp))
        // Play
        Key({ core.send(if (top.playing) Intent.Stop else Intent.Play) }, if (top.playing) "Stop" else "Play", on = top.playing) { fg ->
            val stop = animatedFloat(if (top.playing) 1f else 0f, Dur.STATE)
            PlayStopIcon(stop.value, fg)
        }
        Spacer(Modifier.width(4.dp))
        // Readout: bar · beat, tempo; opens tempo and Loop · Song · Once
        Box {
            Column(
                Modifier
                    .width(60.dp).defaultMinSize(minHeight = 48.dp)
                    .semantics(mergeDescendants = true) {
                        role = Role.Button
                        contentDescription = "Bar ${top.bar}, beat ${top.beat}, ${top.tempoText()} beats per minute, ${top.mode.word}. Opens tempo and playback mode"
                    }
                    .clickable { menu = Menu.Readout }
                    .padding(end = 2.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.Center,
            ) {
                BasicText("${top.bar}·${top.beat}", style = LupeType.number)
                BasicText(if (top.mode == PlaybackMode.Loop) "${top.tempoText()} BPM" else "${top.tempoText()} ${top.mode.word.uppercase()}", style = LupeType.small, maxLines = 1)
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
    }
}

private enum class Menu { Fm1, Launch, Readout }

/** Only while the core is the fake: jump to a link state or a bottom page, to try the shell without an FM-1. */
@Composable
private fun FakeMenu(core: FakeLupeCore, close: () -> Unit) {
    MenuDivider()
    MenuHeading("Fake core (no FM-1)")
    core.scenarioNames.forEach { MenuRow("Play “$it”", { core.play(it); close() }) }
    MenuRow("FM-1 knob 1 up (locks CUTOFF)", { core.fm1Knob(1, 1); close() })
    MenuRow("FM-1 knob 2 up (locks DECAY)", { core.fm1Knob(2, 1); close() })
    MenuRow("Bottom: editor", { core.showBottom(com.scottgerstl.lupe.core.BottomPage()); close() })
    listOf("ENV" to "ENV", "LFO" to "LFO", "FX" to "REVERB").forEach { (fam, page) ->
        MenuRow("Bottom: $fam page", { core.showBottom(com.scottgerstl.lupe.core.BottomPage(com.scottgerstl.lupe.core.BottomKind.Page, fam, page)); close() })
    }
}

package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.GoHome
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PickPage
import com.scottgerstl.lupe.core.ScreenGoto
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.sheet.LocalSheetHost
import com.scottgerstl.lupe.ui.sheet.SheetKind
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

/** The block's height: two keys of 36 dp and the 4 dp between (decision 24, board 72). */
val BLOCK_HEIGHT = 76.dp

private enum class BlockKey(val label: String, val family: String? = null) {
    FX("FX", "FX"), SEL("SEL", "SEL"), ENV("ENV", "ENV"), LFO("LFO", "LFO"), EDIT("EDIT", "EDIT"), GLO("GLO"),
    HOME("HOME"), SAVE("SAVE"), ARP("ARP", "ARP"), SEQ("SEQ"), PLAY("PLAY"), REC("REC"),
}

/**
 * The FM-1's 2 × 6 button block, key for key and in its places (decision 24, from Scott's photo): FX SEL ENV LFO EDIT GLO over
 * HOME SAVE ARP SEQ PLAY/STOP REC. Always at the very bottom of the bottom half. The lit key (white, dark label) is the FM-1's
 * current screen as the link reports it: a sound family while a sound page shows, HOME when the FM-1 is on HOME, SEQ otherwise.
 * The families open the sound page (a lit one again steps to its next page, as the FM-1's button does); HOME is goHome; GLO, SAVE and
 * SEQ send the FM-1 there and open the phone's own place; PLAY/STOP and REC are the header's actions. PLAY/STOP and REC are red words,
 * as printed on the device.
 */
@Composable
fun ButtonBlock(core: LupeCore, modifier: Modifier = Modifier) {
    val shell by core.shell.collectAsStateWithLifecycle()
    val page by core.page.collectAsStateWithLifecycle()
    val home by core.homeKnobs.collectAsStateWithLifecycle()
    val top by core.top.collectAsStateWithLifecycle()
    val screen by core.fm1Screen.collectAsStateWithLifecycle()
    // The lit key is the FM-1's own: the link's fm1Screen.key ("" under a MENU or a held layer lights none). Until the link has reported
    // (nothing published yet) it falls back to what the shell shows.
    val reported = screen.key.isNotEmpty() || screen.menu || screen.layer != 0
    val lit: BlockKey? = if (reported) BlockKey.entries.firstOrNull { it.name == screen.key }
        else when {
            shell.bottom.kind == BottomKind.Page -> BlockKey.entries.firstOrNull { it.family == page.family } ?: BlockKey.HOME
            home.fm1Home -> BlockKey.HOME
            else -> BlockKey.SEQ
        }
    /** The key's page this press lands on: its first, or the next when the key is already lit (as the FM-1's button steps). */
    fun target(k: BlockKey): Pair<Int, String>? {
        val pages = com.scottgerstl.lupe.core.ScreenPages.of(k.name).ifEmpty { return null }
        val at = if (k == lit) pages.indexOfFirst { it.first == screen.page } else -1
        return pages[(at + 1).mod(pages.size)]
    }
    fun press(k: BlockKey) {
        when (k) {
            BlockKey.HOME -> core.send(GoHome)
            // GLO, SAVE and SEQ send the FM-1 there; the phone's own place (Mix tab, Sounds sheet, Projects, the lane, the Timeline) follows from the
            // link's fm1Screen, exactly as when the FM-1's own button is pressed (FollowPlace.kt), so what was open before can be put back
            BlockKey.GLO -> target(k)?.let { (n, _) ->
                core.send(ScreenGoto("GLO", n))
                core.send(com.scottgerstl.lupe.core.MixSectionPick(listOf("mixer", "delay", "reverb", "chorus", "global")[n - 30]))
            }
            BlockKey.SAVE, BlockKey.SEQ -> target(k)?.let { (n, _) -> core.send(ScreenGoto(k.name, n)) }
            BlockKey.PLAY -> core.send(if (top.playing) Intent.Stop else Intent.Play)
            BlockKey.REC -> core.send(Intent.Rec)
            else -> {
                val f = k.family ?: return
                // the lit family again: its next page, as the FM-1's button steps
                val next = if (k == lit && page.family == f && page.pages.size > 1) page.pages.let { ps -> ps[(ps.indexOfFirst { it.index == page.page } + 1).mod(ps.size)].index } else null
                core.send(PickPage(f, next))
            }
        }
    }
    BoxWithConstraints(modifier.fillMaxWidth().height(BLOCK_HEIGHT)) {
        val gap = 4.dp
        val w = (maxWidth - gap * 5) / 6
        Column(verticalArrangement = Arrangement.spacedBy(gap)) {
            for (r in 0 until 2) Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (c in 0 until 6) {
                    val k = BlockKey.entries[r * 6 + c]
                    val isLit = k == lit
                    val red = k == BlockKey.PLAY || k == BlockKey.REC
                    val desc = when (k) {
                        BlockKey.PLAY -> if (top.playing) "Stop" else "Play"
                        BlockKey.REC -> "Record"
                        BlockKey.HOME -> "Home"
                        else -> k.label
                    }
                    val recOn = k == BlockKey.REC && top.rec
                    Key(
                        { press(k) }, desc, width = w, height = 36.dp, minTarget = 36.dp,
                        on = isLit || recOn, litTop = if (recOn) Tok.rec else Tok.text, litEdge = if (recOn) Tok.rec else Tok.text2,
                        role = if (k == BlockKey.REC) Role.Switch else Role.Button,
                        state = when { k == BlockKey.REC -> if (top.rec) "On" else "Off"; isLit && k != BlockKey.PLAY -> "The FM-1 is here"; else -> null },
                    ) { fg ->
                        val ink: Color = if (red && !recOn) Tok.rec else fg
                        if (k == BlockKey.PLAY) Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            BasicText("PLAY", style = LupeType.number.copy(fontSize = 10.sp, lineHeight = 11.sp, color = ink, textAlign = TextAlign.Center))
                            BasicText("STOP", style = LupeType.number.copy(fontSize = 10.sp, lineHeight = 11.sp, color = ink, textAlign = TextAlign.Center))
                        } else BasicText(k.label, style = LupeType.number.copy(fontSize = 15.sp, lineHeight = 16.sp, color = ink, textAlign = TextAlign.Center), maxLines = 1)
                    }
                }
            }
        }
    }
}

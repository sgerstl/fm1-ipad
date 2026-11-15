package com.scottgerstl.lupe.ui.shell

import com.scottgerstl.lupe.core.Fm1ScreenState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.MixSectionPick
import com.scottgerstl.lupe.core.MixState
import com.scottgerstl.lupe.core.PageControl
import com.scottgerstl.lupe.core.PageRef
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.PageTilesState
import com.scottgerstl.lupe.core.ScreenGoto
import com.scottgerstl.lupe.core.ScreenPages
import com.scottgerstl.lupe.core.SetMixParam
import com.scottgerstl.lupe.core.SetMixSetting
import com.scottgerstl.lupe.core.SetParam
import com.scottgerstl.lupe.core.PickPage
import com.scottgerstl.lupe.core.PickTile
import com.scottgerstl.lupe.ui.mix.busGraphOf

// Decision 44 (Scott, 2026-11-15): GLO's DELAY, REVERB, CHORUS and GLOBAL are sound pages like the rest: the docked sound panel, a header "GLO 2/5 DELAY", four
// dials (white: turning them changes every track), the FM-1's own grey picture under them. The panel is neutral grey, not a track's colour. GLO 1/5 MIXER is
// the Mix tab. The Mix pop-up is gone. This file makes the panel's page from the core's `mix` area and routes what the panel does back to it.

/** The four shared pages' numbers in Lupe's numbering (screenGoto's `page`), what the GLO key on the sound-keys rail steps through (MIXER is the Mix tab). */
val GLO_BUS_PAGES: List<Int> = ScreenPages.GLO.drop(1).map { it.first }

/** Whether the FM-1 is on one of GLO's shared pages now (not MIXER): the sound panel's. */
fun onGloBus(screen: Fm1ScreenState): Boolean = screen.key == "GLO" && screen.page in GLO_BUS_PAGES

/**
 * The panel's page for GLO's shared pages: family "GLO", all five pages listed (so the header reads "GLO 2/5 DELAY"), the card's four controls, its picture, and
 * DELAY's MODE as tiles under the dials. Null when the core's `mix` area is on the mixer or has no card yet.
 */
fun gloPageState(mix: MixState, screen: Fm1ScreenState, track: Int, trackName: String): PageState? {
    if (!onGloBus(screen)) return null
    val card = mix.card ?: return null
    val controls = (card.controls + List(4) { null }).take(4)
    val key = mix.section
    // a card's settings (DELAY MODE on 2.5.1): the choice, as tiles under the dials
    val setting: PageControl? = card.settings.firstOrNull()
    val label = setting?.label?.let { if (it.equals("DLY MODE", true)) "DELAY MODE" else it }
    val names = setting?.names.orEmpty().ifEmpty { if (label == "DELAY MODE") com.scottgerstl.lupe.core.FakeP5.DELAY_MODES else emptyList() }
    val tiles = if (setting != null && names.size in 2..6) PageTilesState(kind = "pick", labels = names, picked = setting.raw.coerceIn(0, names.lastIndex)) else null
    return PageState(
        family = "GLO", pages = ScreenPages.GLO.map { PageRef(it.first, it.second) }, page = screen.page,
        track = track, trackName = trackName, controls = controls, title = screen.title.ifEmpty { card.title.uppercase() },
        tiles = tiles, graph = busGraphOf(key, card) ?: com.scottgerstl.lupe.core.PageGraph(),
    )
}

/** What the panel's dials, tiles and page steps mean for a GLO page: the mix area's own intents, and the FM-1's GLO pages. */
class GloCore(private val base: LupeCore) : LupeCore by base {
    override fun send(intent: Intent) {
        when (intent) {
            is SetParam -> base.send(SetMixParam(intent.slot, intent.value))
            is PickTile -> base.send(SetMixSetting(0, intent.tile))
            is PickPage -> base.send(ScreenGoto("GLO", intent.page))
            else -> base.send(intent)
        }
    }
}

/** The GLO key on the rail: closed, it opens 2/5; open, it steps 3/5, 4/5, 5/5 and round to 2/5. */
fun gloKeyTarget(open: Boolean, page: Int): Int = if (!open) GLO_BUS_PAGES.first() else railTarget("GLO", "GLO", GLO_BUS_PAGES, page) ?: GLO_BUS_PAGES.first()

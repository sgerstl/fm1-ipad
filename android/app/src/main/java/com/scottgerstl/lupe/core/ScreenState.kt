package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

// The FM-1 key whose screen is up (decision 24, board 72: the phone's button block lights it). Mirrors P1's
// android/core/Sources/PhoneCore/ScreenArea.swift. The intent that sends the FM-1 to GLO, SAVE or SEQ is P2's
// ScreenGoto (PageState.kt): {"intent":"screenGoto","screen":"GLO"|"SAVE"|"SEQ"[,"page":n]}.

@Serializable
data class Fm1ScreenState(
    /** "HOME", "FX", "SEL", "ENV", "LFO", "EDIT", "ARP", "GLO", "SAVE", "SEQ"; "" under a MENU or a held layer. */
    val key: String = "",
    /** The page in Lupe's numbers (pickPage's and screenGoto's), -1 on HOME or none. GLO 30–34, SAVE 35–38, SEQ 41–45. */
    val page: Int = -1,
    /** The FM-1's title: "MIXER", "PRESETS", "USER", "PATTERNS", "PROJECT", "NOTES", "SONG", a sound page's. */
    val title: String = "",
    val menu: Boolean = false,
    /** A layer held on the FM-1: 0 none, 3 SCL's keys (shown as SEL › SCALE), 7 ARP's PERFORM. */
    val layer: Int = 0,
)

object ScreenDefaults {
    val fm1Screen: StateFlow<Fm1ScreenState> = MutableStateFlow(Fm1ScreenState())
}

package com.scottgerstl.lupe.core

/** The pages behind the block's GLO, SAVE and SEQ keys, in Lupe's numbers (screenGoto's `page`, fm1Screen's `page`) and the FM-1's titles. */
object ScreenPages {
    val GLO = listOf(30 to "MIXER", 31 to "DELAY", 32 to "REVERB", 33 to "CHORUS", 34 to "GLOBAL")
    val SAVE = listOf(35 to "PRESETS", 36 to "USER", 37 to "PATTERNS", 38 to "PROJECT")
    val SEQ = listOf(41 to "NOTES", 42 to "FEEL", 43 to "PATTERN", 44 to "AUTOMATION", 45 to "SONG")
    fun of(key: String) = when (key) { "GLO" -> GLO; "SAVE" -> SAVE; "SEQ" -> SEQ; else -> emptyList() }
}

package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable

/**
 * Something the FM-1 (or the core) has to say about an action: usually a refusal (what happened and what to do), sometimes an answer
 * ("Cleared 5 unused patterns. 5 pattern numbers are free."), so the strip that shows it is neutral, not an error's red. It is shown on the screen where the action was taken (Scott,
 * 2026-11-14: New pattern "did nothing" on the Pixel; the FM-1 had refused it and only the log said so). [seq] grows with each one, so the
 * same words twice still show twice; 0 is "none yet". [track] (1…6) and [entry] (0-based) say where, when the core knows.
 *
 * The core's `notice` area, and nothing else: the log is never read for these (a startup line "read-only: OFF…" once showed as a refusal,
 * Scott's Pixel 10, 2026-11-14).
 */
@Serializable
data class CoreNotice(val seq: Int = 0, val text: String = "", val track: Int? = null, val entry: Int? = null)

object NoticeDefaults { val notice: StateFlow<CoreNotice> = MutableStateFlow(CoreNotice()) }

/** The FM-1's own reason, with what to do where its words stop short. */
fun refusalWords(reason: String): String {
    val r = reason.trim().trimEnd('.')
    return when {
        r.startsWith("All 64 patterns are taken") -> "All 64 patterns are taken. Pick a pattern, or clear the unused ones (hold an empty slot, or the song's menu)."
        r.startsWith("Stop to ") || r.startsWith("Stop first") -> "$r. Press Stop, then try again."
        r.startsWith("Skiff refused it: the entry is empty") -> "The FM-1 refused it: the entry is empty, there's nothing to copy, or there's no room after it."
        r.startsWith("Skiff couldn't do it") -> "The FM-1 couldn't do it. Try again; if it keeps refusing, unplug it and plug it in again."
        r.startsWith("Something still uses that pattern") -> "$r. Clear those first."
        else -> "$r."
    }
}

/** No pattern number is free: what New pattern's sub line says before the tap. */
const val NO_PATTERN_FREE = "All 64 patterns are taken"

/**
 * Erase every kept pattern nothing uses ([PadsState.unused]), to free their numbers. It loses data, so the screen confirms in place first
 * and sends [confirmed]; the core refuses an unconfirmed one. JSON `{"intent":"clearUnusedPatterns","confirmed":true}`.
 */
@Serializable @kotlinx.serialization.SerialName("clearUnusedPatterns") data class ClearUnusedPatterns(val confirmed: Boolean = false) : Intent

/** "Clear 5 unused patterns…": the menu's row. */
fun clearUnusedTitle(unused: List<Int>): String = "Clear ${unused.size} unused pattern${if (unused.size == 1) "" else "s"}…"

/** What the confirm says goes, by number: "Clears 03, 17, 22 · can't be undone"; past six, the first six and how many more. */
fun clearUnusedWords(unused: List<Int>): String {
    val shown = unused.sorted().take(6).joinToString(", ") { "%02d".format(it) }
    val more = unused.size - 6
    return "Clears $shown" + (if (more > 0) " and $more more" else "") + " · can't be undone"
}

package com.scottgerstl.lupe.core

// What the Projects sheet says about the playing music and the pattern pool. Pure, so the tests can hold it to its words.

enum class PlayingSource { Slot, Phone, New }

/**
 * The playing music: its [name], where it came from ([source]: an FM-1 [slot] 0…3, a phone file [projectId], or new) and whether it [changed]
 * since it was saved there. [sourceText]: "FM-1 P2", "this phone", "new".
 */
data class PlayingNow(
    val name: String, val source: PlayingSource, val changed: Boolean, val slot: Int? = null, val projectId: String? = null,
) {
    val sourceText: String get() = when (source) { PlayingSource.Slot -> "FM-1 P${(slot ?: 0) + 1}"; PlayingSource.Phone -> "this phone"; PlayingSource.New -> "new" }

    /** The line under the name, in the iPad's words (Projects sheet, 2026-11-17): "From the FM-1's P2 · changed since", "Saved on this phone". */
    val line: String get() = when (source) {
        PlayingSource.Slot -> "From the FM-1's P${(slot ?: 0) + 1}"
        PlayingSource.Phone -> "Saved on this phone"
        PlayingSource.New -> "New, not saved anywhere"
    } + if (changed) " · changed since" else ""

    /** Opening something over it loses work unless a safety copy is kept: it changed, or it was never saved anywhere. */
    val needsSaving: Boolean get() = changed || source == PlayingSource.New
}

/**
 * Where the playing music came from. A phone file while the FM-1 still shows the name it was opened or saved under and the same slot is current
 * (a load or a save on a slot, here or on the FM-1, moves it there); else the FM-1's current slot; else new.
 * The phone's "changed" is the core's [ProjectsState.phoneEdited]: unknown (null, the app started since) counts as changed.
 */
fun playingNow(state: ProjectsState, home: PhoneHome?, projectName: (String) -> String?): PlayingNow {
    val slot = state.slots.firstOrNull { it.current }
    val homeName = home?.let { projectName(it.projectId) }
    if (home != null && homeName != null && state.name == home.fm1Name && slot?.slot == home.slotAtSave) {
        return PlayingNow(homeName, PlayingSource.Phone, state.phoneEdited ?: true, projectId = home.projectId)
    }
    if (slot != null) return PlayingNow(slot.name.ifEmpty { state.name }.ifEmpty { "P${slot.slot + 1}" }, PlayingSource.Slot, state.changed, slot = slot.slot)
    return PlayingNow(state.name.ifEmpty { "Untitled" }, PlayingSource.New, false)
}

/**
 * The pool line's numbers: pattern numbers taken (kept) of 64, how many of those nothing uses, and how many only FM-1 slots keep. Worded as the
 * iPad's (2026-11-17): "14 of 64 pattern numbers taken · 3 unused · 12 kept only by FM-1 slots".
 */
data class PoolLine(val taken: Int, val unused: Int, val slotOnly: Int) {
    val text: String get() = "$taken of 64 pattern numbers taken · $unused unused · $slotOnly kept only by FM-1 slots"
    val spoken: String get() = "$taken of 64 pattern numbers taken. $unused unused. $slotOnly kept only by FM-1 project slots."
}

/**
 * From the core's pool: the FM-1 counts every use of a pattern ([PoolPattern.uses]: the working music and the saved slots together). A kept
 * pattern (length over 0) that the working music doesn't use (no pad names it, no track is on it) but whose count is over 0 is kept only by
 * slots. Per-slot counts aren't given by the FM-1, so none are made up. Null until the pool has been read.
 */
fun poolLine(p: PatternsState): PoolLine? {
    if (p.free + p.kept == 0) return null
    val kept = p.patterns.filter { it.len > 0 }
    return PoolLine(
        taken = maxOf(p.kept, kept.size),
        unused = maxOf(p.unused, kept.count { it.uses == 0 }),
        slotOnly = kept.count { it.here.isEmpty() && it.on.isEmpty() && it.uses > 0 },
    )
}

/** What a failed transfer means to the person: what happened, then what to do. [what] is the action ("open Night Drive"). */
fun transferWords(e: TransferEvent, what: String): String = when (e.error) {
    "poolFull" -> "Couldn't $what: it needs ${e.needed ?: "more"} pattern numbers and ${e.free ?: 0} ${if (e.free == 1) "is" else "are"} free. " +
        "Nothing on the FM-1 changed. Patterns kept by FM-1 slots are the usual cause: Copy a slot to this phone, then save over it or clear unused patterns."
    "playing" -> "Couldn't $what: the FM-1 is still playing. Press Stop, then try again."
    "notConnected" -> "Couldn't $what: the FM-1 isn't connected. Plug it in, then try again."
    "readOnly" -> "Couldn't $what: Lupe is read-only, so nothing was sent to the FM-1. Turn on Allow writes to change it."
    "busy" -> "Couldn't $what: a project load or save is still going. Wait for it to finish."
    "empty" -> "Couldn't $what: that slot is empty. Pick a slot with a project in it."
    "noAnswer" -> "Couldn't $what: the FM-1 didn't answer. Check the cable, then try again."
    else -> "Couldn't $what: the FM-1 refused it. Try again; if it keeps refusing, unplug it and plug it in again."
}

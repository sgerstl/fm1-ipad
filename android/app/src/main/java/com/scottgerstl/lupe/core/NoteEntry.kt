package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Note entry from the phone's own keyboard strip and kit grid (decision 28, board 73); P1's shapes (aae214f). Only these write: the FM-1's
// keys never write steps from the phone (decision 5). All four writes are refused while read-only and allowed while playing. They act on
// the editor's track; [step] is 0–15.

/**
 * The step's notes become [notes] (MIDI numbers): one replaces what was there, two to four make a chord, more than four is refused whole,
 * and none clears the note (the step's locks stay). Velocity, length and the other step bytes are kept. Refused on a kit track.
 */
@Serializable @SerialName("setStepNotes") data class SetStepNotes(val step: Int, val notes: List<Int>) : Intent

/** Adds [note] to the step if it's absent and there's room (four), or takes it off; taking off the last empties the step. Refused on a kit track. */
@Serializable @SerialName("toggleStepNote") data class ToggleStepNote(val step: Int, val note: Int) : Intent

/** A kit cell: the hit on [lane] (0–7) at [step] goes on or off, at the step's velocity. Refused on a note track. */
@Serializable @SerialName("toggleHit") data class ToggleHit(val lane: Int, val step: Int) : Intent

/**
 * Plays [note], or a kit's [lane], on the editor's track; it writes nothing. Send [on] true on the key going down and false on its release (a
 * note never released stops after 5 s). The FM-1 records what it is sent while REC is armed and playing, so the screen doesn't send it then.
 */
@Serializable @SerialName("playNote") data class PlayNote(val note: Int? = null, val lane: Int? = null, val on: Boolean) : Intent

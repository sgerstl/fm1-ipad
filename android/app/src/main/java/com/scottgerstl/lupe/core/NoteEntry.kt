package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Note entry from the phone's own keyboard strip (decision 28, board 73). Only these write: the FM-1's keys never write steps
// from the phone (decision 5). PROVISIONAL names and shapes: P1 is adding the core side and will send the real ones.

/** A key tapped with no step picked: it only plays the selected track. [note] is a MIDI number. */
@Serializable @SerialName("keyPlay") data class KeyPlay(val note: Int) : Intent

/** A key tapped with a step picked and Chord off: the step's note becomes [note] (and it plays). */
@Serializable @SerialName("stepNote") data class StepNote(val step: Int, val note: Int) : Intent

/** A key tapped with a step picked and Chord on: [note] is added to the step, or taken off if it is on it; at most the FM-1's four. */
@Serializable @SerialName("stepChordNote") data class StepChordNote(val step: Int, val note: Int) : Intent

/** A kit cell tapped: the hit on [lane] at [step] goes on or off. */
@Serializable @SerialName("drumHit") data class DrumHit(val step: Int, val lane: String) : Intent

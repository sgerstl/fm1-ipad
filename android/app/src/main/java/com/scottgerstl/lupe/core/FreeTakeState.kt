package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The `freetake` area: Skiff's FREE TAKE on the phone (screen link v7). A phrase played on the FM-1 with the transport
// stopped is offered once its 2.5 s pause has passed; Keep that opens the FM-1's picker, shown in the editor's place in
// the bottom half (`shell.bottom.kind = freetake`); Keep it lands the take, with the FM-1's undo. Mirrors PhoneCore's
// FreeTakeArea.swift field for field. The FM-1's keys never write from the phone: every choice is a TAKE op, a write
// behind the read-only gate, and the choices come back through the area.

@Serializable
data class TakeGuess(val bpm: Int = 120, val caption: String = "")

@Serializable
data class TakeNote(val step: Int = 0, val len: Int = 1, val pitch: Int = 60)

/** A phrase heard on the selected track, offered as a take. [canStart] false: the strip names SHIFT + SAVE on the FM-1. */
@Serializable
data class TakeOffer(val track: Int = 1, val trackName: String = "", val notes: Int = 0, val canStart: Boolean = true, val refused: Boolean = false)

@Serializable
data class TakePicker(
    val track: Int = 1,
    val trackName: String = "",
    /** "Replaces pattern 12 there, and on its 1 other entry. Undo brings it back." */
    val replaces: String = "",
    /** Keep it asks once more when it replaces a pattern: the words on that key; null: nothing to replace. */
    val confirm: String? = null,
    val guesses: List<TakeGuess> = emptyList(),
    val guess: Int = 0,
    val bars: List<Int> = listOf(1, 2, 4, 8),
    val barsIndex: Int = 1,
    val firstBeat: Int = 0,
    val firstBeats: Int = 1,
    val setsTempo: Boolean = true,
    val tempoBefore: Int = 120,
    val bpm: Int = 120,
    val externalClock: Boolean = false,
    /** The transport is playing: the Listen key says Stop. */
    val playing: Boolean = false,
    /** Steps shown (16 a bar, at most 64) and the track's notes over them. */
    val length: Int = 32,
    val notes: List<TakeNote> = emptyList(),
)

@Serializable
data class TakeLanded(val track: Int = 1, val trackName: String = "", val length: Int = 0, val bpm: Int = 120, val undoFromHere: Boolean = true, val undone: Boolean = false)

@Serializable
data class FreeTakeState(val offer: TakeOffer? = null, val picker: TakePicker? = null, val landed: TakeLanded? = null)

object FreeTakeDefaults { val state: StateFlow<FreeTakeState> = MutableStateFlow(FreeTakeState()) }

// ---- intents (same "intent" discriminator as Intent.kt). Indexes are 0-based. All but the two dismissals are writes.

@Serializable @SerialName("takeStart") data object TakeStart : Intent
@Serializable @SerialName("takeGuess") data class TakeGuessPick(val index: Int) : Intent
@Serializable @SerialName("takeBars") data class TakeBarsPick(val index: Int) : Intent
@Serializable @SerialName("takeFirstBeat") data class TakeFirstBeat(val index: Int) : Intent
@Serializable @SerialName("takeSetTempo") data class TakeSetTempo(val on: Boolean) : Intent
@Serializable @SerialName("takeListen") data object TakeListen : Intent
@Serializable @SerialName("takeKeep") data object TakeKeep : Intent
@Serializable @SerialName("takePutBack") data object TakePutBack : Intent
@Serializable @SerialName("takeUndo") data object TakeUndo : Intent
@Serializable @SerialName("takeDismissOffer") data object TakeDismissOffer : Intent
@Serializable @SerialName("takeDismissLanded") data object TakeDismissLanded : Intent

/** What the fake core does with the take intents: a small model of the picker, enough to click through it. PROVISIONAL, for testing. */
object FakeTake {
    private val notes = listOf(0 to 60, 2 to 63, 4 to 67, 6 to 65, 8 to 60, 12 to 62, 14 to 67, 18 to 70, 20 to 67, 24 to 63, 28 to 60, 32 to 65, 36 to 62, 40 to 67, 48 to 60, 56 to 63)

    fun picker(track: Int, name: String, bars: Int = 1) = TakePicker(
        track = track, trackName = name, replaces = "Replaces pattern 12 there, and on its 1 other entry. Undo brings it back.", confirm = "Replace pattern 12 on T$track and 1 more",
        guesses = listOf(TakeGuess(96, "guess"), TakeGuess(48, "half"), TakeGuess(192, "double")), guess = 0, barsIndex = bars, firstBeat = 0, firstBeats = 8,
        setsTempo = true, tempoBefore = 120, bpm = 96, length = 16 * listOf(1, 2, 4, 4)[bars.coerceIn(0, 3)],
    ).let { it.copy(notes = notesFor(it.length)) }

    private fun notesFor(length: Int) = notes.filter { it.first < length }.map { (s, p) -> TakeNote(s, 2, p) }

    fun apply(s: FreeTakeState, i: Intent, track: Int, name: String): FreeTakeState = when (i) {
        TakeStart -> if (s.picker != null) s else s.copy(offer = null, landed = null, picker = picker(track, name))
        is TakeGuessPick -> s.withPicker { it.copy(guess = i.index.coerceIn(0, it.guesses.size - 1), bpm = it.guesses.getOrNull(i.index)?.bpm ?: it.bpm) }
        is TakeBarsPick -> s.withPicker { val b = i.index.coerceIn(0, 3); val len = 16 * listOf(1, 2, 4, 4)[b]; it.copy(barsIndex = b, length = len, notes = notesFor(len)) }
        is TakeFirstBeat -> s.withPicker { it.copy(firstBeat = i.index.coerceIn(0, it.firstBeats - 1)) }
        is TakeSetTempo -> s.withPicker { it.copy(setsTempo = i.on && !it.externalClock) }
        TakeListen -> s.withPicker { it.copy(playing = !it.playing) }
        TakeKeep -> s.picker?.let { p -> s.copy(picker = null, landed = TakeLanded(p.track, p.trackName, p.length, if (p.setsTempo) p.bpm else p.tempoBefore)) } ?: s
        TakePutBack -> s.copy(picker = null)
        TakeUndo -> s.landed?.let { s.copy(landed = it.copy(undone = !it.undone)) } ?: s
        TakeDismissOffer -> s.copy(offer = null)
        TakeDismissLanded -> s.copy(landed = null)
        else -> s
    }

    private fun FreeTakeState.withPicker(f: (TakePicker) -> TakePicker) = picker?.let { copy(picker = f(it)) } ?: this
}

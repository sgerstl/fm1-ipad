package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * What the person did (android/BRIDGE.md §2). Encoded as JSON for `LupeNative.intent(json)`; the discriminator
 * is the "intent" key. P2 lists play … setDivider in BRIDGE.md; [SetPlaybackMode] is P2's one addition (the
 * readout's Loop · Song · Once needs a way to send the choice) — P1 to adopt or rename.
 */
@Serializable
sealed interface Intent {
    @Serializable @SerialName("retry") data object Retry : Intent
    @Serializable @SerialName("play") data object Play : Intent
    @Serializable @SerialName("stop") data object Stop : Intent
    @Serializable @SerialName("rec") data object Rec : Intent
    @Serializable @SerialName("setTempo") data class SetTempo(val bpm: Double) : Intent
    @Serializable @SerialName("setLaunch") data class SetLaunch(val quantize: LaunchQuantize) : Intent
    @Serializable @SerialName("cancelWaiting") data object CancelWaiting : Intent
    @Serializable @SerialName("setTab") data class SetTab(val tab: Tab) : Intent
    @Serializable @SerialName("setDivider") data class SetDivider(val position: Divider) : Intent
    @Serializable @SerialName("setPlaybackMode") data class SetPlaybackMode(val mode: PlaybackMode) : Intent

    // ---- P3: pads. Track numbers are 1-based, entries 0-based (A = 0).
    @Serializable @SerialName("padTap") data class PadTap(val track: Int, val entry: Int) : Intent
    /** Hold menu › Edit steps, and a tap while Select is on: the pad goes to the editor, nothing launches. */
    @Serializable @SerialName("padSelect") data class PadSelect(val track: Int, val entry: Int) : Intent
    @Serializable @SerialName("padSelectSound") data class PadSelectSound(val track: Int, val entry: Int) : Intent
    @Serializable @SerialName("padNew") data class PadNew(val track: Int, val entry: Int) : Intent
    @Serializable @SerialName("padSet") data class PadSet(val track: Int, val entry: Int, val pattern: Int) : Intent
    @Serializable @SerialName("padClear") data class PadClear(val track: Int, val entry: Int) : Intent
    @Serializable @SerialName("trackSelect") data class TrackSelect(val track: Int) : Intent
    @Serializable @SerialName("trackMute") data class TrackMute(val track: Int) : Intent
    @Serializable @SerialName("sceneRecall") data class SceneRecall(val scene: Int) : Intent
    @Serializable @SerialName("sceneStore") data class SceneStore(val scene: Int) : Intent

    // ---- P3: editor. Steps are 0-based.
    @Serializable @SerialName("stepSelect") data class StepSelect(val step: Int) : Intent
    /** Down: lock mode while held. Up: back to off unless the Lock key latched it. */
    @Serializable @SerialName("stepHold") data class StepHold(val step: Int, val down: Boolean) : Intent
    /** A − or + on the step panel (the FM-1's knobs send the same through the core). While locking, it locks the value to the step. */
    @Serializable @SerialName("stepAdjust") data class StepAdjust(val field: StepField, val delta: Int) : Intent
    @Serializable @SerialName("chordToggle") data object ChordToggle : Intent
    @Serializable @SerialName("lockToggle") data object LockToggle : Intent
    @Serializable @SerialName("lockClear") data class LockClear(val step: Int, val param: String) : Intent
    @Serializable @SerialName("locksClearAll") data class LocksClearAll(val step: Int) : Intent
    @Serializable @SerialName("stepAction") data class StepAction(val step: Int, val action: StepActionKind) : Intent
    @Serializable @SerialName("lanePick") data class LanePick(val lane: String) : Intent
}

@Serializable
enum class StepField {
    @SerialName("pitch") Pitch, @SerialName("move") Move, @SerialName("length") Length, @SerialName("velocity") Velocity,
    @SerialName("chance") Chance, @SerialName("ratchet") Ratchet, @SerialName("cond") Cond, @SerialName("nudge") Nudge,
}

@Serializable
enum class StepActionKind { @SerialName("copy") Copy, @SerialName("paste") Paste, @SerialName("clear") Clear }

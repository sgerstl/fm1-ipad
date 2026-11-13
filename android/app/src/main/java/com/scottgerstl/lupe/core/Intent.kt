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
}

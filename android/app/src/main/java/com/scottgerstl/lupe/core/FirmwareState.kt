package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Installing Skiff-Lupe from the phone (decision 42; P1's fe3faaf, android/core/Sources/PhoneCore/Firmware.swift). The `firmware` area is always published;
// the screens draw the offer, the install cover and the menu's firmware sheet from it, and send the three intents below. The firmware intents are NOT behind
// the read-only gate: the confirm on the screen is the gate.

/**
 * What the FM-1's firmware lets the phone offer. [kind]: "install" (it runs something else), "update" (an earlier Skiff-Lupe), "finish" (it waits in update mode
 * after a cut), "foreign" (another firmware's update mode: only an OK; [firmware] absent). [from]: stockSkiff / newerSkiff / olderLupe / sloop / mvave / unknown /
 * loader. [title] and [text] are ready to show as they are. [key] is the same for the same FM-1 state, for "not now for 14 days" (the screen persists that).
 */
@Serializable
data class FirmwareOffer(val kind: String, val from: String = "", val key: String = "", val firmware: String? = null, val title: String = "", val text: String = "")

/**
 * [state]: idle / downloading / backingUp / staging / writing / resuming / restarting / done / failed. [progress] 0…1 for the whole install, never going back.
 * [message] is one line to show. [installing] is the firmware's title while not idle. [backup] is the path of the backup file taken first (under filesDir/Backups).
 * [inUpdateMode]: after a failure the FM-1 may be waiting in update mode; installing again finishes it.
 */
@Serializable
data class FirmwareState(
    val running: String? = null,
    val identity: String? = null,
    val offer: FirmwareOffer? = null,
    val state: String = "idle",
    val progress: Double = 0.0,
    val message: String = "",
    val installing: String? = null,
    val backup: String? = null,
    val inUpdateMode: Boolean = false,
) {
    /** A write is going on or about to: the screen stays on and nothing lets the person leave. */
    val busy: Boolean get() = state != "idle" && state != "done" && state != "failed"
    val active: Boolean get() = state != "idle"
}

object FirmwareDefaults { val state: StateFlow<FirmwareState> = MutableStateFlow(FirmwareState()) }

/** Start the install. Nothing begins without [confirmed]; [battery] 0…100 and [charging] are the phone's (under 30 % off the charger is refused); [skipBackup] only after a failed backup. */
@Serializable @SerialName("firmwareInstall")
data class FirmwareInstall(val which: String? = null, val confirmed: Boolean = false, val battery: Int? = null, val charging: Boolean? = null, val skipBackup: Boolean = false) : Intent

/** "Not now": the core hides the offer until the FM-1 is unplugged (the 14 days are the screen's). */
@Serializable @SerialName("firmwareCancelOffer") data object FirmwareCancelOffer : Intent

/** After done or failed: back to idle. */
@Serializable @SerialName("firmwareClose") data object FirmwareClose : Intent

/** "Skiff-Lupe-2.5.1" as a person reads it: "Skiff-Lupe 2.5.1". */
fun firmwareWords(name: String?): String = (name ?: "Skiff-Lupe-2.5.1").replace(Regex("-(\\d)"), " $1")

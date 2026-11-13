package com.scottgerstl.lupe.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// P5's areas: mix, sounds, projects (android/BRIDGE.md §2's phase table). Mirrors P1's
// android/core/Sources/PhoneCore/P5State.swift field for field; the fixtures in android/fixtures/state are recorded
// from FakeSkiff by P1's Mac test. A file of its own so P2's, P3's and P4's edits to State.kt don't collide.

// ---- mix: GLO's five pages one at a time (design/structure-map.md "Mix")

@Serializable
data class MixSection(
    /** "mixer", "delay", "reverb", "chorus", "global" */
    val key: String,
    val title: String,
    /** The FM-1's page (30…34). */
    val page: Int,
)

@Serializable
data class MixRow(
    val track: Int,
    val name: String,
    val selected: Boolean = false,
    /** P_LEVEL 0…127; [levelText] as the FM-1 shows it: "-3 dB", "OFF". */
    val level: Int = 0,
    val levelText: String = "",
    /** −64…63; decision 14: in the row's hold menu, the row shows level only. */
    val pan: Int = 0,
    val panText: String = "C",
    val mute: Boolean = false,
    /** Lupe's solo (the iPad's, through PERFORM's mutes). */
    val solo: Boolean = false,
    /** The REVERB send (FX knob 4), read for every track every 3 s; null until read. */
    val reverb: Int? = null,
    val reverbText: String? = null,
    val reverbMax: Int = 127,
)

/** An effect card: the page's four knobs (P4's [PageControl], null = no knob) and its settings (DELAY MODE on 2.5.1). */
@Serializable
data class MixCard(
    val title: String,
    val controls: List<PageControl?> = List(4) { null },
    val settings: List<PageControl> = emptyList(),
)

@Serializable
data class MixState(
    val sections: List<MixSection> = emptyList(),
    /** The section on screen. */
    val section: String = "mixer",
    val rows: List<MixRow> = emptyList(),
    /** delay, reverb, chorus, global; null on mixer. */
    val card: MixCard? = null,
)

/** The six tracks' output levels 0…1 (METER over the screen link), sampled every 50 ms, sent when one moves. */
@Serializable
data class MetersState(val levels: List<Double> = emptyList())

// ---- sounds: the browser in the bottom half (track name ⌄, SAVE, the hold menu)

@Serializable
data class SoundEngine(val index: Int, val name: String, val offered: Boolean = true, val kit: Boolean = false)

@Serializable
data class SoundPreset(val index: Int, val name: String, val current: Boolean = false)

@Serializable
data class UserSlot(
    val slot: Int,
    val used: Boolean = false,
    val name: String = "",
    val engine: Int? = null,
    val engineName: String? = null,
    val current: Boolean = false,
)

/** What a pick changes: the track ([entry] null) or one pad's own sound (decision 15). [track] 1-based, [entry] 0-based. */
@Serializable
data class SoundTarget(val track: Int = 1, val entry: Int? = null)

/** An entry's own sound: [kind] "none", "preset" or "user". */
@Serializable
data class EntrySound(
    val kind: String = "none",
    val engine: Int? = null,
    val preset: Int? = null,
    val slot: Int? = null,
    val name: String? = null,
)

@Serializable
data class SoundsState(
    val target: SoundTarget = SoundTarget(),
    val trackName: String = "",
    val engine: Int = 0,
    val preset: Int = 0,
    val engines: List<SoundEngine> = emptyList(),
    /** The engine whose presets are listed. */
    val viewing: Int = 0,
    val presets: List<SoundPreset> = emptyList(),
    /** Skiff's 32 user slots. */
    val user: List<UserSlot> = emptyList(),
    val entrySound: EntrySound? = null,
    /** Why the FM-1 kept the old sound, until the next pick. */
    val refusal: String? = null,
)

// ---- projects: the FM-1's four slots

@Serializable
data class ProjectSlot(val slot: Int, val used: Boolean = false, val name: String = "", val current: Boolean = false)

@Serializable
data class ProjectsState(
    val slots: List<ProjectSlot> = emptyList(),
    /** The music's name, and whether it changed since its slot was loaded or saved (what a load would lose). */
    val name: String = "",
    val changed: Boolean = false,
    val busy: Boolean = false,
)

/** Defaults for a core that doesn't publish P5 yet (the fake until P2 fills it). */
object P5Defaults {
    val mix: StateFlow<MixState> = MutableStateFlow(MixState())
    val sounds: StateFlow<SoundsState> = MutableStateFlow(SoundsState())
    val projects: StateFlow<ProjectsState> = MutableStateFlow(ProjectsState())
    val meters: StateFlow<MetersState> = MutableStateFlow(MetersState())
}

// ---- intents (same "intent" discriminator as Intent.kt)

/** Show a section (a write too when linked: the FM-1 goes to that GLO page). */
@Serializable @SerialName("mixSection") data class MixSectionPick(val section: String) : Intent
@Serializable @SerialName("setLevel") data class SetLevel(val track: Int, val value: Int) : Intent
@Serializable @SerialName("setPan") data class SetPan(val track: Int, val value: Int) : Intent
@Serializable @SerialName("setReverb") data class SetReverb(val track: Int, val value: Int) : Intent
@Serializable @SerialName("trackSolo") data class TrackSolo(val track: Int) : Intent
/** A card's knob 0…3 to [value] (raw). */
@Serializable @SerialName("setMixParam") data class SetMixParam(val slot: Int, val value: Int) : Intent
/** A card's setting (MixCard.settings index). */
@Serializable @SerialName("setMixSetting") data class SetMixSetting(val index: Int, val value: Int) : Intent

/** What the browser changes: a track, or a pad's own sound ([entry]). */
@Serializable @SerialName("soundsTarget") data class SoundsTargetPick(val track: Int, val entry: Int? = null) : Intent
@Serializable @SerialName("soundsView") data class SoundsView(val engine: Int) : Intent
@Serializable @SerialName("pickPreset") data class PickPreset(val engine: Int, val preset: Int) : Intent
@Serializable @SerialName("pickUser") data class PickUser(val slot: Int) : Intent
/** A pad's own sound off: it plays the track's again. */
@Serializable @SerialName("clearEntrySound") data object ClearEntrySound : Intent
/** SAVE the track's sound into user slot [slot]; over a used slot only [confirmed] (confirm in place, naming it). */
@Serializable @SerialName("saveSound") data class SaveSound(val slot: Int, val name: String, val confirmed: Boolean = false) : Intent
@Serializable @SerialName("eraseUser") data class EraseUser(val slot: Int, val confirmed: Boolean = false) : Intent

/** Load slot [slot]; when the music [ProjectsState.changed], only [confirmed] (the confirm names what's lost). */
@Serializable @SerialName("projectLoad") data class ProjectLoad(val slot: Int, val confirmed: Boolean = false) : Intent
/** Save over the music's own slot (confirm in place: it replaces what the slot held). */
@Serializable @SerialName("projectSave") data class ProjectSave(val confirmed: Boolean = false) : Intent
/** Save into [slot] under [name]; over a used slot only [confirmed]. */
@Serializable @SerialName("projectSaveAs") data class ProjectSaveAs(val slot: Int, val name: String, val confirmed: Boolean = false) : Intent
@Serializable @SerialName("projectRename") data class ProjectRename(val slot: Int, val name: String) : Intent

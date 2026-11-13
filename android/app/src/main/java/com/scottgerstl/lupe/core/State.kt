package com.scottgerstl.lupe.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The ViewState areas P2 draws (android/BRIDGE.md §2). PROVISIONAL: hand-written to the contract until P1's
// PhoneCore writes recordings into android/fixtures/state/. When P1's State.swift lands, these are checked
// against it (a renamed field fails a build, not a screen) and replaced if they differ.

// ---- link (P1)

@Serializable
enum class LinkPhase {
    @SerialName("searching") Searching,
    @SerialName("connecting") Connecting,
    @SerialName("reading") Reading,
    @SerialName("ready") Ready,
    @SerialName("lost") Lost,
    @SerialName("wrongFirmware") WrongFirmware,
}

/** [reason] says why it was lost ("unplugged", "silent"); [firmware] is what a wrong-firmware FM-1 reported. */
@Serializable
data class LinkState(
    val phase: LinkPhase = LinkPhase.Searching,
    val reason: String? = null,
    val firmware: String? = null,
)

// ---- top (P2)

@Serializable
enum class PlaybackMode {
    @SerialName("loop") Loop,
    @SerialName("song") Song,
    @SerialName("once") Once,
}

@Serializable
enum class LaunchQuantize {
    @SerialName("loop") Loop,
    @SerialName("bar") Bar,
    @SerialName("beat") Beat,
    @SerialName("now") Now,
}

@Serializable
data class TopState(
    /** The FM-1 key's label: the project's name. */
    val project: String = "",
    val playing: Boolean = false,
    val rec: Boolean = false,
    val tempo: Double = 120.0,
    val mode: PlaybackMode = PlaybackMode.Loop,
    val launch: LaunchQuantize = LaunchQuantize.Bar,
    /** How many launches wait for the quantize point. */
    val waiting: Int = 0,
    /** The readout's position, 1-based: "10·3". */
    val bar: Int = 1,
    val beat: Int = 1,
)

// ---- shell (P2)

@Serializable
enum class Tab {
    @SerialName("pads") Pads,
    @SerialName("timeline") Timeline,
    @SerialName("mix") Mix,
}

@Serializable
enum class Divider {
    @SerialName("top") Top,
    @SerialName("split") Split,
    @SerialName("bottom") Bottom,
}

@Serializable
enum class BottomKind {
    /** SEQ: the step editor (P3). */
    @SerialName("editor") Editor,
    /** A sound page: ENV, LFO, FX, SEL, EDIT, ARP (P4). */
    @SerialName("page") Page,
}

/** Which page the FM-1's screen shows; the bottom half follows it. [family] and [page] are only set for [BottomKind.Page]. */
@Serializable
data class BottomPage(
    val kind: BottomKind = BottomKind.Editor,
    val family: String? = null,
    val page: String? = null,
)

@Serializable
data class ShellState(
    val tab: Tab = Tab.Pads,
    val divider: Divider = Divider.Split,
    val bottom: BottomPage = BottomPage(),
)

package com.scottgerstl.lupe.audio

/**
 * The pure parts of audio through (no Android in here, so the JVM tests cover them): which input is the FM-1, what
 * kind of output the sound goes to, the stats the engine reports, and the words the menu and Settings show.
 */

/** An audio device as audio through needs it (AudioDeviceInfo, flattened). */
data class AudioDev(val id: Int, val type: Int, val name: String, val isInput: Boolean)

/** Where the sound goes, by what it means for the delay. */
enum class OutputKind { Speaker, Wired, Usb, Bluetooth, BluetoothLe, Other }

/** What audio through is doing. Mirrors the iPad's AudioThrough.State. */
sealed interface ThroughState {
    data object Off : ThroughState
    data object Starting : ThroughState
    /** On, but no FM-1 audio input: not plugged in, or its USB audio isn't up yet. */
    data object NoInput : ThroughState
    /** Android counts a USB audio input as a microphone, and the permission is off. */
    data object NeedsPermission : ThroughState
    data class Playing(val output: String, val kind: OutputKind) : ThroughState
    data class Failed(val why: String) : ThroughState
}

/** One reading of the engine (ThroughNative.stats). Latencies in ms; -1 where the phone gave no timestamp yet. */
data class ThroughStats(
    val running: Boolean = false,
    val disconnected: Boolean = false,
    val inRate: Int = 0, val outRate: Int = 0,
    val inExclusive: Boolean = false, val outExclusive: Boolean = false, val outLowLatency: Boolean = false,
    val outBurst: Int = 0, val outBuffer: Int = 0,
    val inDevice: Int = 0, val outDevice: Int = 0, val inChannels: Int = 0,
    val inLatencyMs: Double = -1.0, val ringMs: Double = 0.0, val filterMs: Double = 0.0, val outLatencyMs: Double = -1.0,
    val totalMs: Double = -1.0, val targetMs: Double = 0.0, val jitterMs: Double = 0.0, val ratioPpm: Double = 0.0,
    val underruns: Long = 0, val catchUps: Long = 0, val overflows: Long = 0,
    val zeroRuns: Long = 0, val repeatRuns: Long = 0,
    val inXruns: Long = 0, val outXruns: Long = 0,
    val framesIn: Long = 0, val framesOut: Long = 0,
    val playing: Boolean = false, val callbacks: Long = 0, val peak: Double = 0.0,
    /** Bit 0: the input gave a timestamp; bit 1: the output did. Without one, that side's latency is its buffer's fill plus a burst. */
    val tsFlags: Int = 0,
    /** The last stream error (an AAudio code, 0: none) and whether the input raised it. */
    val lastError: Int = 0, val lastErrorInput: Boolean = false,
    /** How many times the controller restarted the streams (route changes, errors); filled in by AudioThrough. */
    val restarts: Int = 0,
    /** The input has been exact digital silence for half a second: the FM-1 dithers, so that isn't the FM-1's quiet, and gaps can't be seen. */
    val blind: Boolean = false,
    /** Gap zero runs concealed (dropped if the phone inserts them, filled if it replaces real frames). */
    val concealed: Long = 0,
    /** 0 not known yet, 1 the phone inserts its zeros, 2 it replaces real frames; and the measure behind it (~1 / ~0). */
    val gapMode: Int = 0, val insertedness: Double = 0.0,
    /** 0 no capture, 1 recording, 2 ready. */
    val capture: Int = 0,
) {
    /** Gaps the phone's own USB audio path filled before the sound reached Lupe (the FM-1 dithers, so it never sends these). */
    val phoneDropouts get() = zeroRuns + repeatRuns

    companion object {
        /** The engine's array, in through_engine.cpp's `Stat` order. */
        fun from(a: DoubleArray): ThroughStats {
            fun d(i: Int) = a.getOrElse(i) { 0.0 }
            fun b(i: Int) = d(i) != 0.0
            fun l(i: Int) = d(i).toLong()
            fun n(i: Int) = d(i).toInt()
            return ThroughStats(
                running = b(0), disconnected = b(1), inRate = n(2), outRate = n(3), inExclusive = b(4), outExclusive = b(5),
                outLowLatency = b(6), outBurst = n(7), outBuffer = n(8), inDevice = n(9), outDevice = n(10),
                inLatencyMs = d(11), ringMs = d(12), filterMs = d(13), outLatencyMs = d(14), totalMs = d(15), targetMs = d(16),
                jitterMs = d(17), ratioPpm = d(18), underruns = l(19), catchUps = l(20), overflows = l(21), zeroRuns = l(22),
                repeatRuns = l(23), inXruns = l(24), outXruns = l(25), framesIn = l(26), framesOut = l(27), playing = b(28),
                callbacks = l(29), inChannels = n(30), peak = d(31), tsFlags = n(32), lastError = n(33), lastErrorInput = b(34), blind = b(35),
                concealed = l(36), gapMode = n(37), insertedness = d(38), capture = n(39),
            )
        }
        const val COUNT = 40
    }
}

object ThroughModel {
    // android.media.AudioDeviceInfo.TYPE_*, copied so the JVM tests don't need Android
    const val TYPE_BUILTIN_EARPIECE = 1
    const val TYPE_BUILTIN_SPEAKER = 2
    const val TYPE_WIRED_HEADSET = 3
    const val TYPE_WIRED_HEADPHONES = 4
    const val TYPE_BLUETOOTH_SCO = 7
    const val TYPE_BLUETOOTH_A2DP = 8
    const val TYPE_USB_DEVICE = 11
    const val TYPE_USB_ACCESSORY = 12
    const val TYPE_USB_HEADSET = 22
    const val TYPE_HEARING_AID = 23
    const val TYPE_BUILTIN_SPEAKER_SAFE = 24
    const val TYPE_BLE_HEADSET = 26
    const val TYPE_BLE_SPEAKER = 27
    const val TYPE_BLE_BROADCAST = 30

    /**
     * The FM-1's audio input: a USB input named "Felucca" (Skiff's USB name), else any USB device input. Never the
     * phone's own microphone: playing that to the speaker would howl (the iPad's rule too).
     */
    fun pickFm1(devices: List<AudioDev>): AudioDev? {
        val usb = devices.filter { it.isInput && (it.type == TYPE_USB_DEVICE || it.type == TYPE_USB_HEADSET || it.type == TYPE_USB_ACCESSORY) }
        return usb.firstOrNull { it.name.contains("Felucca", ignoreCase = true) } ?: usb.firstOrNull { it.type == TYPE_USB_DEVICE }
    }

    fun kind(type: Int): OutputKind = when (type) {
        TYPE_BUILTIN_SPEAKER, TYPE_BUILTIN_SPEAKER_SAFE, TYPE_BUILTIN_EARPIECE -> OutputKind.Speaker
        TYPE_WIRED_HEADSET, TYPE_WIRED_HEADPHONES -> OutputKind.Wired
        TYPE_USB_DEVICE, TYPE_USB_HEADSET, TYPE_USB_ACCESSORY -> OutputKind.Usb
        TYPE_BLUETOOTH_A2DP, TYPE_BLUETOOTH_SCO, TYPE_HEARING_AID -> OutputKind.Bluetooth
        TYPE_BLE_HEADSET, TYPE_BLE_SPEAKER, TYPE_BLE_BROADCAST -> OutputKind.BluetoothLe
        else -> OutputKind.Other
    }

    /** The output's name as people say it: "Phone speaker", "Wired headphones", or the headphones' own name. */
    fun outputName(type: Int, productName: String): String = when (kind(type)) {
        OutputKind.Speaker -> "Phone speaker"
        OutputKind.Wired -> "Wired headphones"
        OutputKind.Usb -> productName.ifBlank { "USB headphones" }
        OutputKind.Bluetooth, OutputKind.BluetoothLe -> productName.ifBlank { "Bluetooth headphones" }
        OutputKind.Other -> productName.ifBlank { "the phone's output" }
    }

    /** The phone's share of the delay, rounded: "24 ms" (a no-break space: the menu's line never wraps between them). Null before the streams have timestamps. */
    fun latencyText(s: ThroughStats): String? =
        if (!s.running || s.totalMs < 0) null else "${Math.round(s.totalMs)}\u00A0ms"

    /** What Bluetooth adds, said plainly. Null for outputs where the phone's number is the whole delay. */
    fun bluetoothNote(kind: OutputKind): String? = when (kind) {
        OutputKind.Bluetooth -> "Bluetooth adds its own delay on top, often 150 to 250 ms, which the phone can't measure. Fine for listening; to play live, use wired headphones or the FM-1's own jack."
        OutputKind.BluetoothLe -> "Bluetooth LE Audio adds its own delay on top, usually less than older Bluetooth but still more than wired, and the phone can't measure it. To play live, use wired headphones or the FM-1's own jack."
        else -> null
    }

    /** One short line, for the song-name menu and TalkBack. */
    fun summary(state: ThroughState, stats: ThroughStats): String = when (state) {
        ThroughState.Off -> "Off"
        ThroughState.Starting -> "Starting…"
        ThroughState.NoInput -> "No sound from the FM-1 over USB"
        ThroughState.NeedsPermission -> "Needs microphone access"
        is ThroughState.Playing -> buildString {
            append("Playing on ").append(state.output)
            latencyText(stats)?.let { append(" · ").append(it) }
            if (state.kind == OutputKind.Bluetooth || state.kind == OutputKind.BluetoothLe) append(" + Bluetooth")
        }
        is ThroughState.Failed -> state.why
    }

    /** The one line under the switch when there's something to do (null when all is well): the iPad's audioAction. */
    fun action(state: ThroughState): String? = when (state) {
        ThroughState.NeedsPermission -> "Allow the microphone for Lupe: Android counts the FM-1's USB audio as a microphone"
        ThroughState.NoInput -> "No sound from the FM-1 over USB: plug it in, or unplug it and plug it in again"
        is ThroughState.Failed -> state.why
        else -> null
    }

    /** The technical line for the device check: rates, sharing, buffer, and both kinds of dropout. */
    fun details(s: ThroughStats): String {
        if (!s.running) return "Stopped"
        fun khz(r: Int) = if (r % 1000 == 0) "${r / 1000}" else "%.1f".format(r / 1000.0)
        fun ms(v: Double) = if (v < 0) "–" else "%.1f".format(v)
        return "${khz(s.inRate)} → ${khz(s.outRate)} kHz · in ${if (s.inExclusive) "exclusive" else "shared"}, out ${if (s.outExclusive) "exclusive" else "shared"}" +
            (if (s.outLowLatency) "" else " (not low latency)") +
            " · in ${ms(s.inLatencyMs)} + buffer ${ms(s.ringMs + s.filterMs)} + out ${ms(s.outLatencyMs)} ms" +
            " · burst ${s.outBurst} · ${"%+.0f".format(s.ratioPpm)} ppm" +
            " · Lupe gaps ${s.underruns} · phone gaps ${s.phoneDropouts} (${s.zeroRuns} zero, ${s.repeatRuns} repeat)${if (s.blind) " (blind: the input is digital silence)" else ""}" +
            (if (s.concealed > 0) " · concealed ${s.concealed}" else "") +
            (when (s.gapMode) { 1 -> " · gaps inserted (${"%.2f".format(s.insertedness)})"; 2 -> " · gaps replace (${"%.2f".format(s.insertedness)})"; else -> "" }) +
            " · xruns ${s.inXruns}/${s.outXruns}" +
            " · timestamps ${if (s.tsFlags and 1 != 0) "in" else "–"}/${if (s.tsFlags and 2 != 0) "out" else "–"}" +
            (if (s.restarts > 0) " · restarts ${s.restarts}" else "")
    }
}

package com.scottgerstl.lupe.core

import android.content.Context
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiInputPort
import android.media.midi.MidiManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log

/**
 * The FM-1 over Android's MIDI service (android/BRIDGE.md §1). One instance for the app's life.
 *
 * Finds the FM-1 among the USB MIDI devices, opens it, and passes every received chunk straight to Swift
 * ([LupeNative.onBytes], no buffering here). Swift sends frames back through [send]. When the device goes
 * away it closes both ports and tells Swift ([LupeNative.onLost]); when it comes back it opens it again.
 *
 * Android names ports from the device's side: we SEND to its INPUT port and RECEIVE from its OUTPUT port.
 */
class FM1Link(context: Context) {
    enum class State { None, Opening, Open }

    private val midi = context.getSystemService(MidiManager::class.java)
    /** Android's MIDI callbacks and our receive run here, off the UI thread. */
    private val thread = HandlerThread("FM1Link").apply { start() }
    private val handler = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())

    @Volatile var state = State.None
        private set
    @Volatile private var device: MidiDevice? = null
    @Volatile private var deviceInfo: MidiDeviceInfo? = null
    @Volatile private var input: MidiInputPort? = null
    @Volatile private var output: MidiOutputPort? = null

    /** Called on the UI thread whenever [state] or [seen] changes. */
    var onChange: (() -> Unit)? = null

    /** Every MIDI device Android listed, with its property strings, for the debug screen. */
    @Volatile var seen: List<String> = emptyList()
        private set

    private val callback = object : MidiManager.DeviceCallback() {
        override fun onDeviceAdded(info: MidiDeviceInfo) { log("added: ${describe(info)}"); remember(info); consider(info) }
        override fun onDeviceRemoved(info: MidiDeviceInfo) {
            log("removed: ${describe(info)}")
            if (info.id == deviceInfo?.id) lose("unplugged")
        }
    }

    fun start() {
        midi.registerDeviceCallback(MidiManager.TRANSPORT_MIDI_BYTE_STREAM, { handler.post(it) }, callback)
        handler.post {
            val all = midi.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)
            log("${all.size} MIDI device(s) at start")
            all.forEach { remember(it); log("present: ${describe(it)}") }
            all.firstOrNull(::isFM1)?.let(::consider)
        }
    }

    /**
     * Whether [info] is the FM-1. Skiff keeps Felucca's USB name (BRIDGE.md §1); the iPad's findDevice
     * looks for "Felucca" in the port name. Checked here against every string Android gives us, case-insensitively,
     * until the Pixel's real strings are logged (gate 3); then narrowed to what the FM-1 actually reports.
     */
    fun isFM1(info: MidiDeviceInfo): Boolean {
        if (info.type != MidiDeviceInfo.TYPE_USB) return false
        if (info.inputPortCount < 1 || info.outputPortCount < 1) return false
        return strings(info).any { MATCH.any { m -> it.contains(m, ignoreCase = true) } }
    }

    private fun consider(info: MidiDeviceInfo) {
        if (!isFM1(info)) { log("not the FM-1: ${info.id}"); return }
        if (state != State.None) { log("already ${state.name.lowercase()}; ignoring device ${info.id}"); return }
        setState(State.Opening)
        LupeNative.onOpening()
        log("opening device ${info.id}")
        midi.openDevice(info, { dev -> handler.post { opened(info, dev) } }, handler)
    }

    private fun opened(info: MidiDeviceInfo, dev: MidiDevice?) {
        if (dev == null) { log("openDevice failed for ${info.id}"); setState(State.None); LupeNative.onLost(); return }
        val inPort = dev.openInputPort(0)
        val outPort = dev.openOutputPort(0)
        if (inPort == null || outPort == null) {
            log("couldn't open ports (input ${inPort != null}, output ${outPort != null}); another app may hold the FM-1")
            inPort?.close(); outPort?.close(); dev.close()
            setState(State.None); LupeNative.onLost()
            return
        }
        device = dev; deviceInfo = info; input = inPort; output = outPort
        outPort.connect(receiver)
        setState(State.Open)
        LupeNative.onOpened()
        log("open: input port max message ${inPort.maxMessageSize} bytes")
    }

    private val receiver = object : MidiReceiver() {
        override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
            LupeNative.onBytes(msg, offset, count, timestamp)
        }
    }

    /** One frame to the FM-1. Called from Swift on any thread. Splits frames longer than the port takes. */
    fun send(frame: ByteArray) {
        val port = input ?: return
        try {
            val max = port.maxMessageSize.coerceAtLeast(1)
            var at = 0
            while (at < frame.size) {
                val n = minOf(max, frame.size - at)
                port.send(frame, at, n)
                at += n
            }
        } catch (e: java.io.IOException) {
            log("send failed: ${e.message}")
            handler.post { lose("send failed") }
        }
    }

    private fun lose(why: String) {
        val had = device != null || state != State.None
        try { output?.disconnect(receiver) } catch (_: Exception) {}
        try { output?.close() } catch (_: Exception) {}
        try { input?.close() } catch (_: Exception) {}
        try { device?.close() } catch (_: Exception) {}
        device = null; deviceInfo = null; input = null; output = null
        if (had) {
            setState(State.None)
            LupeNative.onLost()
            log("lost: $why")
        }
    }

    private fun remember(info: MidiDeviceInfo) {
        val line = describe(info)
        seen = (seen.filterNot { it.startsWith("#${info.id} ") } + line)
        main.post { onChange?.invoke() }
    }

    private fun setState(s: State) { state = s; main.post { onChange?.invoke() } }

    private fun log(line: String) {
        Log.i(TAG, line)
        LinkLog.add(line)
    }

    companion object {
        private const val TAG = "LupeLink"
        /** What the FM-1's strings contain. BRIDGE.md's guess; gate 3 logs the real ones. */
        val MATCH = listOf("Felucca", "FM-1", "FM1", "M-VAVE")

        fun strings(info: MidiDeviceInfo): List<String> {
            val p = info.properties
            return listOf(
                MidiDeviceInfo.PROPERTY_NAME, MidiDeviceInfo.PROPERTY_PRODUCT,
                MidiDeviceInfo.PROPERTY_MANUFACTURER, MidiDeviceInfo.PROPERTY_SERIAL_NUMBER,
            ).mapNotNull { p.getString(it) } + info.ports.mapNotNull { it.name }
        }

        /** Every property string and port name, for the log: what the gate-3 check asks Scott to read out. */
        fun describe(info: MidiDeviceInfo): String {
            val p = info.properties
            val type = when (info.type) { MidiDeviceInfo.TYPE_USB -> "USB"; MidiDeviceInfo.TYPE_BLUETOOTH -> "BT"; MidiDeviceInfo.TYPE_VIRTUAL -> "virtual"; else -> "type ${info.type}" }
            val props = p.keySet().sorted().joinToString(", ") { k ->
                @Suppress("DEPRECATION") val v = p.get(k)
                "$k=\"${if (v is android.os.Bundle) "{usb device}" else v}\""
            }
            val ports = info.ports.joinToString(", ") { port ->
                "${if (port.type == android.media.midi.MidiDeviceInfo.PortInfo.TYPE_INPUT) "in" else "out"}${port.portNumber}=\"${port.name}\""
            }
            return "#${info.id} $type ins=${info.inputPortCount} outs=${info.outputPortCount} [$props] ports [$ports]"
        }
    }
}

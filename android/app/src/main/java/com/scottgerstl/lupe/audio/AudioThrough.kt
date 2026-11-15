package com.scottgerstl.lupe.audio

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Plays the FM-1 through the phone, as the iPad's and iPhone's AudioThrough do: Skiff is a class-compliant USB audio
 * input ("Felucca"), so the phone reads it and plays it to its speaker or whatever headphones are on.
 *
 * The switch is kept. The engine (ThroughNative, AAudio) runs only while the switch is on, the app is in front and an
 * FM-1 audio input is there; Android doesn't let an app record in the background without a foreground service, so the
 * sound stops when Lupe goes to the background and comes back when it returns (the iPad keeps playing; a gap, noted
 * in the device check).
 *
 * Everything here runs on the main thread; the audio itself runs on AAudio's own thread in C++. A stream that the
 * phone disconnects (headphones in or out, Bluetooth connecting, the FM-1 unplugged) is restarted from here.
 */
class AudioThrough(private val ctx: Context, private val prefs: SharedPreferences?) {
    var enabled by mutableStateOf(prefs?.getBoolean(KEY, false) ?: false)
        private set
    var state by mutableStateOf<ThroughState>(ThroughState.Off)
        private set
    var stats by mutableStateOf(ThroughStats())
        private set

    /** Test settings from adb (MainActivity's extras): the input's rate (0: its own), exclusive or shared streams, any input (an emulator has no FM-1). */
    var testRate = 0
    var testExclusiveIn = true
    var testExclusiveOut = true
    var testAnyInput = false

    /** Asks the Activity for RECORD_AUDIO; set by MainActivity. */
    var requestPermission: (() -> Unit)? = null

    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val main = Handler(Looper.getMainLooper())
    private var inFront = false
    private var running = false
    private var restarts = 0
    private var polls = 0
    /** Asked for the microphone since the switch went on (once: a "Don't allow" is respected until it's switched on again). */
    private var asked = false

    private val devices = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = scheduleCheck()
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = scheduleCheck()
    }
    private val checkRunnable = Runnable { check() }
    private val pollRunnable = object : Runnable {
        override fun run() { poll(); if (running) main.postDelayed(this, POLL_MS) }
    }

    init { am.registerAudioDeviceCallback(devices, main) }

    fun choose(on: Boolean) {
        if (on == enabled) return
        enabled = on
        prefs?.edit()?.putBoolean(KEY, on)?.apply()
        if (on) { state = ThroughState.Starting; asked = false }
        check()
    }

    /** The Activity came to the front / went to the background. */
    fun foreground(front: Boolean) { inFront = front; check() }

    /** RECORD_AUDIO was answered. */
    fun permissionResult() = check()

    private fun scheduleCheck(delayMs: Long = 300) {
        main.removeCallbacks(checkRunnable)
        main.postDelayed(checkRunnable, delayMs)
    }

    /** Brings things to where they should be, touching only what isn't. */
    private fun check() {
        main.removeCallbacks(checkRunnable)
        if (!enabled) { stopEngine(); state = ThroughState.Off; return }
        if (ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            stopEngine()
            if (!asked && inFront) { asked = true; requestPermission?.invoke() }
            state = ThroughState.NeedsPermission
            return
        }
        if (!inFront) { stopEngine(); return }   // the switch keeps its setting; it starts again in front
        val fm1 = fm1Input()
        if (fm1 == null && !testAnyInput) { stopEngine(); state = ThroughState.NoInput; return }
        if (running) return
        val r = ThroughNative.start(fm1?.id ?: 0, testRate, testExclusiveIn, testExclusiveOut)
        if (r != 0) {
            Log.w(TAG, "start failed: ${ThroughNative.error()}")
            state = ThroughState.Failed("The phone's audio couldn't start (${ThroughNative.error()})")
            scheduleCheck(RETRY_MS)
            return
        }
        running = true
        val s = ThroughNative.stats()
        // safety: the input must be the FM-1. If the phone routed us to its own microphone, playing it would howl.
        if (fm1 != null && s.inDevice != 0 && s.inDevice != fm1.id) {
            stopEngine()
            state = ThroughState.Failed("The phone didn't open the FM-1's audio input")
            scheduleCheck(RETRY_MS)
            return
        }
        stats = s
        state = playingState(s)
        main.removeCallbacks(pollRunnable)
        main.postDelayed(pollRunnable, POLL_MS)
    }

    private fun poll() {
        if (!running) return
        val s = ThroughNative.stats()
        stats = s
        if (s.disconnected || !s.running) {
            // a route change or the FM-1 gone: start again from scratch (a few times quickly, then slower)
            stopEngine()
            restarts++
            scheduleCheck(if (restarts < 5) 200 else RETRY_MS)
            return
        }
        restarts = 0
        state = playingState(s)
        // every 5 s, for the device check: adb logcat -s LupeThrough
        if (++polls % 20 == 0) Log.i(TAG, "stats: total ${"%.1f".format(s.totalMs)} ms · ${ThroughModel.details(s)} · target ${"%.1f".format(s.targetMs)} ms · jitter ${"%.1f".format(s.jitterMs)} ms · catch-ups ${s.catchUps} · peak ${"%.3f".format(s.peak)}")
    }

    private fun playingState(s: ThroughStats): ThroughState {
        val out = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { it.id == s.outDevice }
        val type = out?.type ?: ThroughModel.TYPE_BUILTIN_SPEAKER
        return ThroughState.Playing(ThroughModel.outputName(type, out?.productName?.toString().orEmpty()), ThroughModel.kind(type))
    }

    private fun stopEngine() {
        main.removeCallbacks(pollRunnable)
        if (running) { ThroughNative.stop(); running = false }
        stats = ThroughStats()
    }

    private fun fm1Input(): AudioDev? = ThroughModel.pickFm1(
        am.getDevices(AudioManager.GET_DEVICES_INPUTS).map { AudioDev(it.id, it.type, it.productName.toString(), true) },
    )

    val summary get() = ThroughModel.summary(state, stats)

    companion object {
        private const val TAG = "LupeThrough"
        private const val KEY = "audioThrough"
        private const val POLL_MS = 250L
        private const val RETRY_MS = 1500L
    }
}

/** The app's AudioThrough (MainActivity provides it); null in previews and tests. */
val LocalAudioThrough = staticCompositionLocalOf<AudioThrough?> { null }

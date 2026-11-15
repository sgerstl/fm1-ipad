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
    /** Shared by default (2026-11-15, Pixel 10): its exclusive (MMAP) USB input inserts ~45 gaps a second, the crunch; shared had none. */
    var testExclusiveIn = false
        set(v) { field = v; exclusiveIn = v }
    var testExclusiveOut = true
        set(v) { field = v; exclusiveOut = v }
    var testAnyInput = false

    /** Asks the Activity for RECORD_AUDIO; set by MainActivity. */
    var requestPermission: (() -> Unit)? = null

    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val main = Handler(Looper.getMainLooper())
    private var inFront = false
    private var running = false
    private var restarts = 0
    private var totalRestarts = 0
    private val errorTimes = ArrayDeque<Pair<Long, Boolean>>()
    /** Exclusive (MMAP) per stream: the setting (input shared, output exclusive by default), until a stream keeps failing in it (then shared, for this session). */
    private var exclusiveIn = false
    private var exclusiveOut = true
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

    /**
     * The stats line for the device check (adb logcat -s LupeThrough): 1 s after a start, then every 5 s, on its own
     * thread, so a busy main thread (the core's first read of the FM-1 at launch) can't hold it up. On the Pixel the
     * first lines only came once the menu was open (2026-11-15).
     */
    private val logThread = android.os.HandlerThread("through-stats").apply { start() }
    private val logHandler = Handler(logThread.looper)
    private val logRunnable = object : Runnable {
        override fun run() {
            val s = ThroughNative.stats()
            if (!s.running) return
            Log.i(TAG, "stats: total ${"%.1f".format(s.totalMs)} ms · ${ThroughModel.details(s.copy(restarts = totalRestarts))} · target ${"%.1f".format(s.targetMs)} ms · jitter ${"%.1f".format(s.jitterMs)} ms · catch-ups ${s.catchUps} · peak ${"%.4f".format(s.peak)}")
            logHandler.postDelayed(this, 5000)
        }
    }
    private var lastPollAt = 0L

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

    /** Test settings changed (adb extras on a running app): reopen the streams with them. */
    fun restartForSettings() {
        exclusiveIn = testExclusiveIn; exclusiveOut = testExclusiveOut
        errorTimes.clear()
        if (running) { Log.i(TAG, "restart for new test settings"); stopEngine() }
        check()
    }

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
        if (!inFront) { if (running) Log.i(TAG, "check: in the background, stopping"); stopEngine(); return }   // the switch keeps its setting; it starts again in front
        val fm1 = fm1Input()
        if (fm1 == null && !testAnyInput) {
            // no FM-1 input listed (yet): look again shortly. With the FM-1 already plugged in at launch no device
            // callback comes, and the USB audio may show up a moment after the app starts (the iPad's retry, 2026-11-02)
            if (state != ThroughState.NoInput) Log.i(TAG, "check: no FM-1 audio input listed; retrying")
            stopEngine(); state = ThroughState.NoInput; scheduleCheck(RETRY_MS); return
        }
        if (running) return
        Log.i(TAG, "check: starting (input ${fm1?.name ?: "default"} id ${fm1?.id ?: 0}, rate ${if (testRate == 0) "its own" else testRate}, in ${if (exclusiveIn) "exclusive" else "shared"}, out ${if (exclusiveOut) "exclusive" else "shared"})")
        val r = ThroughNative.start(fm1?.id ?: 0, testRate, exclusiveIn, exclusiveOut)
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
        if (stats.restarts == 0) stats = s.copy(restarts = totalRestarts)   // (after a restart, the last full reading stays until the next poll)
        state = playingState(s)
        main.removeCallbacks(pollRunnable)
        main.postDelayed(pollRunnable, POLL_MS)
        lastPollAt = 0L
        logHandler.removeCallbacks(logRunnable)
        logHandler.postDelayed(logRunnable, 1000)
    }

    private fun poll() {
        if (!running) return
        val s = ThroughNative.stats().copy(restarts = totalRestarts)
        if (s.disconnected || !s.running) {
            // a route change, a stream error or the FM-1 gone: start again from scratch (a few times quickly, then slower).
            // Said in the log, so a loop of these can't hide (on the Pixel it once looked like "playing" with no figures).
            val why = if (s.disconnected) "${if (s.lastErrorInput) "input" else "output"} stream error ${s.lastError}" else "engine not running"
            Log.w(TAG, "restart ${totalRestarts + 1}: $why (in ${if (exclusiveIn) "exclusive" else "shared"}, out ${if (exclusiveOut) "exclusive" else "shared"})")
            // exclusive (MMAP) is the usual suspect when a stream keeps failing: after three errors on the same stream
            // within 10 s, that stream goes shared for the rest of the session (still low latency, through the mixer)
            val now = android.os.SystemClock.elapsedRealtime()
            if (s.disconnected) {
                errorTimes.addLast(now to s.lastErrorInput)
                while (errorTimes.isNotEmpty() && now - errorTimes.first().first > 10_000) errorTimes.removeFirst()
                val sameStream = errorTimes.count { it.second == s.lastErrorInput }
                if (sameStream >= 3) {
                    if (s.lastErrorInput && exclusiveIn) { exclusiveIn = false; Log.w(TAG, "input keeps failing in exclusive mode: shared from now on") }
                    if (!s.lastErrorInput && exclusiveOut) { exclusiveOut = false; Log.w(TAG, "output keeps failing in exclusive mode: shared from now on") }
                    errorTimes.clear()
                }
            }
            stopEngine(keepStats = true)
            restarts++
            totalRestarts++
            scheduleCheck(if (restarts < 5) 200 else RETRY_MS)
            return
        }
        stats = s
        restarts = 0
        state = playingState(s)
        // the main thread was busy: say so (the screen's figures lag by that much; the audio doesn't, it has its own thread)
        val now = android.os.SystemClock.uptimeMillis()
        if (lastPollAt != 0L && now - lastPollAt > 1000) Log.w(TAG, "poll ran ${now - lastPollAt} ms after the last (main thread busy)")
        lastPollAt = now
    }

    private fun playingState(s: ThroughStats): ThroughState {
        val out = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { it.id == s.outDevice }
        val type = out?.type ?: ThroughModel.TYPE_BUILTIN_SPEAKER
        return ThroughState.Playing(ThroughModel.outputName(type, out?.productName?.toString().orEmpty()), ThroughModel.kind(type))
    }

    /** keepStats: a restart keeps showing the last reading (marked with the restart count) instead of blanking. */
    private fun stopEngine(keepStats: Boolean = false) {
        main.removeCallbacks(pollRunnable)
        logHandler.removeCallbacks(logRunnable)
        if (running) { ThroughNative.stop(); running = false }
        if (!keepStats) stats = ThroughStats()
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

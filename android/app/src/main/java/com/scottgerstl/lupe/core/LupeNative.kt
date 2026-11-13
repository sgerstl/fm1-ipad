package com.scottgerstl.lupe.core

import android.os.Looper

/**
 * The JNI surface to Swift (android/core/Sources/LupeNative, android/BRIDGE.md §1–2). Hand-written on both
 * sides: the method names here and the @_cdecl names in LupeNative.swift must match.
 *
 * [load] must run on the UI thread before anything else touches Swift (BRIDGE.md §3): libdispatch binds its
 * main queue to the thread that loads it, and the main actor runs there.
 */
object LupeNative {
    @Volatile private var loaded = false
    /** Where Swift's frames go: the app's one FM1Link. */
    @Volatile var link: FM1Link? = null
    /** Lines from Swift for the debug screen (also in logcat, tag "Lupe"). */
    @Volatile var debugListener: ((String) -> Unit)? = null
    /** ViewState areas from Swift (gate 5). */
    @Volatile var stateListener: ((area: String, json: String) -> Unit)? = null

    /** Loads libLupeNative.so and hooks the main actor to the UI thread's Looper. Returns "" or the problem. */
    fun load(): String {
        check(Looper.myLooper() == Looper.getMainLooper()) { "LupeNative.load must run on the UI thread" }
        if (loaded) return ""
        System.loadLibrary("LupeNative")
        loaded = true
        return nativeInit()
    }

    // Kotlin → Swift
    @JvmStatic private external fun nativeInit(): String
    @JvmStatic external fun onOpening()
    @JvmStatic external fun onOpened(rawMode: Boolean)
    @JvmStatic external fun onLost()
    @JvmStatic external fun onBytes(bytes: ByteArray, offset: Int, count: Int, timestamp: Long)
    /** Debug: sends Skiff's version request (INFO) on the open connection. */
    @JvmStatic external fun requestVersion()
    /** Debug: gate 2's main-actor hop, inside the app; the result arrives through [debugListener]. */
    @JvmStatic external fun mainActorCheck()

    // Swift → Kotlin (looked up by name in JNI_OnLoad; keep the signatures)
    @JvmStatic fun send(frame: ByteArray) { link?.send(frame) }
    @JvmStatic fun onState(area: String, json: String) { stateListener?.invoke(area, json) }
    @JvmStatic fun onDebug(line: String) { debugListener?.invoke(line) }
}

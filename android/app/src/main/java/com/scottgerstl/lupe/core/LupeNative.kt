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
    /** Whether libLupeNative.so is loaded (false in unit tests and previews). */
    val isLoaded: Boolean get() = loaded
    /** Where Swift's frames go: the app's one FM1Link. */
    @Volatile var link: FM1Link? = null
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
    /** Starts the link: [raw] true for gate 3's raw-bytes mode (no Session), false for PhoneCore over Session. */
    @JvmStatic external fun startCore(raw: Boolean)
    /** True: only reads reach the FM-1 (the default). Takes effect for the next connection. */
    @JvmStatic external fun setReadOnly(on: Boolean)
    /** One [Intent] as JSON, on the UI thread. */
    @JvmStatic external fun intent(json: String)
    @JvmStatic external fun onOpened()
    /** The ports are open on the device Android names [name] (FM1Link.nameFor): Swift decides who may talk to it. */
    @JvmStatic external fun onOpenedNamed(name: String)
    @JvmStatic external fun onLost()
    @JvmStatic external fun onBytes(bytes: ByteArray, offset: Int, count: Int, timestamp: Long)
    /** Debug: sends Skiff's version request (INFO) on the open connection. */
    @JvmStatic external fun requestVersion()
    /** Debug: gate 2's main-actor hop, inside the app; the result arrives in [LinkLog]. */
    @JvmStatic external fun mainActorCheck()
    /** Decision 46: the FM-1's picture for the sound panel's page (Lupe's number), drawn by Skiff's own code; null: draw the app's own.
     *  8 bytes (width, height u16 LE; animated; draw µs u16 LE; 0), then RGBA. GLO's shared pages in [gloInk], the FM-1's panel surface as [surface] (0xRRGGBB). */
    @JvmStatic external fun skiffPicture(page: Int, gloInk: Int, surface: Int): ByteArray?

    // Swift → Kotlin (looked up by name in JNI_OnLoad; keep the signatures)
    @JvmStatic fun send(frame: ByteArray) { link?.send(frame) }
    @JvmStatic fun onState(area: String, json: String) {
        if (area == "firmware") FirmwareDownloader.onFirmware(json)      // a download the core is waiting for
        val l = stateListener
        if (l == null) android.util.Log.w("LupeState", "onState($area) with no listener") else l(area, json)
    }
    @JvmStatic fun onDebug(line: String) { LinkLog.add(line) }
}

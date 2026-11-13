package com.scottgerstl.lupe.core

import android.app.Application
import android.content.Context
import kotlinx.coroutines.CoroutineScope

/**
 * Starts the real core from `LupeApp.onCreate` (the UI thread, as BRIDGE.md §3 requires): loads Swift, hooks
 * the main actor, opens the FM-1 link and starts PhoneCore. Settings live in the app's own preferences
 * ("lupe"), changed from the debug screen or by adb (LinkDebugActivity's extras):
 * - `core`: "real" (default) or "fake" (P2's FakeLupeCore replaying android/fixtures/state).
 * - `mode`: "session" (default) or "raw" (gate 3: no Session, the debug screen sends INFO itself).
 * - `allowWrites`: false (default): only reads reach the FM-1 (ReadOnlyGuard). True lets Play and edits through.
 */
object LupeStartup {
    const val PREFS = "lupe"
    var link: FM1Link? = null
        private set
    var loadProblem: String = ""
        private set

    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun wantsFake(context: Context) = prefs(context).getString("core", "real") == "fake"
    fun rawMode(context: Context) = prefs(context).getString("mode", "session") == "raw"
    fun allowWrites(context: Context) = prefs(context).getBoolean("allowWrites", false)

    /** The real core. Call once, on the UI thread. */
    fun start(app: Application, scope: CoroutineScope): LupeCore {
        val core = BridgedLupeCore(scope)              // listens before Swift publishes anything
        loadProblem = LupeNative.load()
        LinkLog.add(if (loadProblem.isEmpty()) "Swift loaded; main actor hooked to the UI thread's Looper" else "MainLooper.install failed: $loadProblem")
        LupeNative.setReadOnly(!allowWrites(app))
        val l = FM1Link(app)
        LupeNative.link = l
        link = l
        LupeNative.startCore(rawMode(app))
        l.start()
        return core
    }
}

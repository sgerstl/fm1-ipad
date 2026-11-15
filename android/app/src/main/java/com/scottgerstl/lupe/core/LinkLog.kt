package com.scottgerstl.lupe.core

import android.os.Handler
import android.os.Looper
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * One log for the link, from FM1Link and from Swift (LupeNative.onDebug), kept since the app started so the
 * debug screen shows what happened before it opened. Also in logcat: `adb logcat -s LupeLog`.
 * The last JSON of each ViewState area is kept here too, for the debug screen.
 */
object LinkLog {
    private const val MAX = 800
    private val lines = ArrayList<String>()
    private val areas = LinkedHashMap<String, String>()
    private val clock = SimpleDateFormat("HH:mm:ss.SSS", Locale.ROOT)
    private val main = Handler(Looper.getMainLooper())
    /** Called on the UI thread after each change. */
    @Volatile var listener: (() -> Unit)? = null

    fun add(line: String) {
        Log.i("LupeLog", line)
        synchronized(this) {
            lines.add("${clock.format(Date())}  $line")
            if (lines.size > MAX) lines.subList(0, lines.size - MAX).clear()
        }
        main.post { listener?.invoke() }
    }

    fun area(name: String, json: String) {
        synchronized(this) { areas[name] = json }
        main.post { listener?.invoke() }
    }

    fun lines(): List<String> = synchronized(this) { lines.toList() }
    fun areas(): Map<String, String> = synchronized(this) { LinkedHashMap(areas) }
}

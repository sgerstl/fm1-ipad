package com.scottgerstl.lupe.ui.slide

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * "Slide to turn" (Scott, decision 10, 2026-11-13): values turn by sliding on the control itself, no steppers.
 * The iPad's setting, ios/FM1/Settings.swift SlideToTurn: Sideways, Up and down, Both (the first movement's
 * stronger direction decides that drag). On the phone the default is up and down.
 */
enum class SlideDirection(val key: String, val title: String) {
    Sideways("sideways", "Sideways"),
    UpDown("updown", "Up and down"),
    Both("both", "Both");

    companion object {
        fun from(key: String?) = entries.firstOrNull { it.key == key || it.name.equals(key, true) }
    }
}

/**
 * Slide direction and the Magnifier (the iPad's value loupe: a bigger copy of the value floats above the finger),
 * kept in SharedPreferences. The phone has no Settings screen yet, so for testing:
 * `adb shell am start -n com.scottgerstl.lupe/.MainActivity --es slide sideways|updown|both --ez magnifier false`
 * flips and stores them. Their switches arrive with Settings in P5.
 */
class SlideSettings(private val prefs: android.content.SharedPreferences? = null) {
    var direction by mutableStateOf(SlideDirection.from(prefs?.getString(KEY_DIRECTION, null)) ?: SlideDirection.UpDown)
        private set
    var magnifier by mutableStateOf(prefs?.getBoolean(KEY_MAGNIFIER, true) ?: true)
        private set

    fun chooseDirection(d: SlideDirection) { direction = d; prefs?.edit()?.putString(KEY_DIRECTION, d.key)?.apply() }
    fun chooseMagnifier(on: Boolean) { magnifier = on; prefs?.edit()?.putBoolean(KEY_MAGNIFIER, on)?.apply() }

    companion object {
        const val KEY_DIRECTION = "slide_direction"
        const val KEY_MAGNIFIER = "magnifier"
        fun from(context: Context) = SlideSettings(context.getSharedPreferences("lupe_settings", Context.MODE_PRIVATE))
    }
}

package com.scottgerstl.lupe

import android.database.ContentObserver
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.scottgerstl.lupe.core.FakeLupeCore
import androidx.compose.runtime.CompositionLocalProvider
import com.scottgerstl.lupe.ui.shell.LupeShell
import com.scottgerstl.lupe.ui.slide.GatedHaptics
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings
import com.scottgerstl.lupe.ui.slide.LocalSlideSettings
import com.scottgerstl.lupe.ui.slide.PhoneSettings
import com.scottgerstl.lupe.ui.slide.SlideDirection
import com.scottgerstl.lupe.ui.slide.SlideSettings
import com.scottgerstl.lupe.ui.theme.LupeTheme

class MainActivity : ComponentActivity() {
    private var reduceMotion by mutableStateOf(false)
    private val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) { reduceMotion = readReduceMotion() }
    }

    // "Remove animations" sets the animator duration scale to 0; there is no other system flag on Android.
    private fun readReduceMotion() =
        Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        // Landscape only (decision 28), and immersive: the status bar hides while Lupe runs and shows on a swipe from the edge
        androidx.core.view.WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior = androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(androidx.core.view.WindowInsetsCompat.Type.statusBars())
        }
        reduceMotion = readReduceMotion()
        contentResolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)

        val core = (application as LupeApp).core
        // adb shell am start -n com.scottgerstl.lupe/.MainActivity --es scenario lost
        intent.getStringExtra("scenario")?.let { (core as? FakeLupeCore)?.play(it) }

        // Settings arrive in P5; until then the slide direction and the Magnifier are flipped by launch extras and kept:
        // adb shell am start -n com.scottgerstl.lupe/.MainActivity --es slide sideways|updown|both --ez magnifier false
        val slide = SlideSettings.from(this)
        intent.getStringExtra("slide")?.let { SlideDirection.from(it)?.let(slide::chooseDirection) }
        if (intent.hasExtra("magnifier")) slide.chooseMagnifier(intent.getBooleanExtra("magnifier", true))

        val phone = PhoneSettings.from(this)
        setContent {
            LupeTheme(reduceMotion) {
                CompositionLocalProvider(LocalSlideSettings provides slide, LocalPhoneSettings provides phone) {
                    GatedHaptics(phone) { LupeShell(core) }
                }
            }
        }
    }

    override fun onDestroy() {
        contentResolver.unregisterContentObserver(observer)
        super.onDestroy()
    }
}

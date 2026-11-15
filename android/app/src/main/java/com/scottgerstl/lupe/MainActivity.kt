package com.scottgerstl.lupe

import androidx.compose.ui.Modifier
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
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
    // Play through the phone: Android asks for the microphone (the FM-1's USB audio counts as one)
    private val askMic = registerForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) {
        (application as LupeApp).through.permissionResult()
    }
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
        // Draw under the camera's hole punch: the content runs to the screen's left margin and ignores it (decision 29)
        window.attributes = window.attributes.apply { layoutInDisplayCutoutMode = android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS }
        // Landscape only (decision 28), and immersive: the status bar hides while Lupe runs and shows on a swipe from the edge
        androidx.core.view.WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior = androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(androidx.core.view.WindowInsetsCompat.Type.statusBars())
        }
        reduceMotion = readReduceMotion()
        contentResolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)

        val app = application as LupeApp
        val core = app.core
        // adb shell am start -n com.scottgerstl.lupe/.MainActivity --es scenario lost
        intent.getStringExtra("scenario")?.let { (core as? FakeLupeCore)?.play(it) }

        // Settings arrive in P5; until then the slide direction and the Magnifier are flipped by launch extras and kept:
        // adb shell am start -n com.scottgerstl.lupe/.MainActivity --es slide sideways|updown|both --ez magnifier false
        val slide = SlideSettings.from(this)
        intent.getStringExtra("slide")?.let { SlideDirection.from(it)?.let(slide::chooseDirection) }
        if (intent.hasExtra("magnifier")) slide.chooseMagnifier(intent.getBooleanExtra("magnifier", true))

        val phone = PhoneSettings.from(this)
        // Play through the phone (the song-name menu and Settings). adb, for the device check and the emulator:
        //   --ez through true|false · --ei throughRate 0|44100|48000 (0: the input's own) · --ez throughExclusiveIn true|false (default false) --ez throughExclusiveOut true|false (default true)
        //   --ez throughAnyInput true (the default input when no FM-1 is there: the emulator; never on a phone with its speaker on)
        val through = app.through
        through.requestPermission = { askMic.launch(android.Manifest.permission.RECORD_AUDIO) }
        applyThroughExtras(intent, cold = true)
        // The launch intro (ui/intro): a cold start only (not a rotation or a restore), and not for adb launches that ask for a scenario, so screenshot scripts
        // don't wait for it. adb: --ez intro false skips it; --ef introAt 1.2 holds it at 1.2 s (to compare frames with the iPhone's -intro-at).
        val introWanted = savedInstanceState == null && !intent.hasExtra("scenario") && intent.getBooleanExtra("intro", true)
        val introAt = if (intent.hasExtra("introAt")) intent.getFloatExtra("introAt", 0f).toDouble() else null
        // the system splash leaves at once: the intro's first frame is the same picture (the icon at the same size on the same colour)
        splashScreen.setOnExitAnimationListener { it.remove() }
        setContent {
            LupeTheme(reduceMotion) {
                // the core on screen: the one that looks for the FM-1, or the demo once the no-FM-1 card's button starts it (decision 33)
                val shown = app.core
                val demo = com.scottgerstl.lupe.ui.shell.DemoControl(canStart = shown !is FakeLupeCore, inDemo = app.inDemo, start = { app.useDemo() }, leave = { app.leaveDemo() })
                CompositionLocalProvider(LocalSlideSettings provides slide, LocalPhoneSettings provides phone, com.scottgerstl.lupe.audio.LocalAudioThrough provides through, com.scottgerstl.lupe.ui.page.LocalPictureCore provides shown, com.scottgerstl.lupe.ui.shell.LocalDemo provides demo) {
                    var intro by rememberSaveable { mutableStateOf(introWanted) }
                    Box(Modifier.fillMaxSize()) {
                        GatedHaptics(phone) { androidx.compose.runtime.key(shown) { LupeShell(shown) } }
                        if (intro) com.scottgerstl.lupe.ui.intro.LaunchIntro(reduceMotion, onDone = { intro = false }, frozenAt = introAt)
                    }
                }
            }
        }
    }

    /** Play through the phone's adb extras, on a cold start and on onNewIntent (a running app): see onCreate. */
    private fun applyThroughExtras(i: android.content.Intent, cold: Boolean) {
        val through = (application as LupeApp).through
        var changed = false
        if (i.hasExtra("throughRate")) { through.testRate = i.getIntExtra("throughRate", 0); changed = true }
        if (i.hasExtra("throughExclusiveIn")) { through.testExclusiveIn = i.getBooleanExtra("throughExclusiveIn", false); changed = true }
        if (i.hasExtra("throughExclusiveOut")) { through.testExclusiveOut = i.getBooleanExtra("throughExclusiveOut", true); changed = true }
        if (i.hasExtra("throughAnyInput")) { through.testAnyInput = i.getBooleanExtra("throughAnyInput", false); changed = true }
        if (i.hasExtra("through")) through.choose(i.getBooleanExtra("through", false))
        if (changed && !cold) through.restartForSettings()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyThroughExtras(intent, cold = false)
    }

    override fun onStart() { super.onStart(); (application as LupeApp).through.foreground(true) }
    override fun onStop() { (application as LupeApp).through.foreground(false); super.onStop() }

    override fun onDestroy() {
        contentResolver.unregisterContentObserver(observer)
        super.onDestroy()
    }
}

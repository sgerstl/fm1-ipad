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
import com.scottgerstl.lupe.ui.shell.LupeShell
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
        reduceMotion = readReduceMotion()
        contentResolver.registerContentObserver(Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE), false, observer)

        val core = (application as LupeApp).core
        // adb shell am start -n com.scottgerstl.lupe/.MainActivity --es scenario lost
        intent.getStringExtra("scenario")?.let { (core as? FakeLupeCore)?.play(it) }

        setContent { LupeTheme(reduceMotion) { LupeShell(core) } }
    }

    override fun onDestroy() {
        contentResolver.unregisterContentObserver(observer)
        super.onDestroy()
    }
}

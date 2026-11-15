package com.scottgerstl.lupe

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import com.scottgerstl.lupe.core.FakeLupeCore
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.LupeStartup
import com.scottgerstl.lupe.core.Scenario
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class LupeApp : Application() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** P1 swaps this for the real core (Swift via JNI). Screens only know [LupeCore]. */
    private val shown = androidx.compose.runtime.mutableStateOf<LupeCore?>(null)
    /** The core on screen (Compose state, so the screen follows when the demo starts or ends). Set in onCreate. */
    var core: LupeCore
        get() = shown.value!!
        private set(value) { shown.value = value }
    /** The core the app started with, to go back to when the demo is left; and whether the demo is what shows. */
    private var started: LupeCore? = null
    var inDemo by androidx.compose.runtime.mutableStateOf(false)
        private set
    private var scenarios: Map<String, Scenario> = emptyMap()
    /** Play through the phone (the FM-1's USB audio to the phone's output). One for the app: it outlives the Activity. */
    val through by lazy { com.scottgerstl.lupe.audio.AudioThrough(this, getSharedPreferences("audio", MODE_PRIVATE)) }

    /** The no-FM-1 card's "Use the demo FM-1" (decision 33): the fake core takes the screen. The real one keeps looking for the FM-1 behind it. */
    fun useDemo() { if (inDemo || core is FakeLupeCore) return; started = core; core = FakeLupeCore(scope, scenarios); inDemo = true }
    /** Song-name menu › Leave the demo: back to the core that looks for the FM-1. */
    fun leaveDemo() { val back = started ?: return; (core as? FakeLupeCore)?.send(com.scottgerstl.lupe.core.Intent.Stop); core = back; started = null; inDemo = false }

    override fun onCreate() {
        super.onCreate()
        scenarios = assets.list("state").orEmpty().filter { it.endsWith(".json") }.associate { f ->
            val name = f.removeSuffix(".json")
            name to Scenario.parse(name, assets.open("state/$f").bufferedReader().use { it.readText() })
        }
        // P1: the real core (Swift over the FM-1) unless the "core" preference asks for the fake (LupeStartup).
        core = if (LupeStartup.wantsFake(this)) FakeLupeCore(scope, scenarios) else LupeStartup.start(this, scope)
    }
}

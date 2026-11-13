package com.scottgerstl.lupe

import android.app.Application
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
    lateinit var core: LupeCore
        private set

    override fun onCreate() {
        super.onCreate()
        val scenarios = assets.list("state").orEmpty().filter { it.endsWith(".json") }.associate { f ->
            val name = f.removeSuffix(".json")
            name to Scenario.parse(name, assets.open("state/$f").bufferedReader().use { it.readText() })
        }
        // P1: the real core (Swift over the FM-1) unless the "core" preference asks for the fake (LupeStartup).
        core = if (LupeStartup.wantsFake(this)) FakeLupeCore(scope, scenarios) else LupeStartup.start(this, scope)
    }
}

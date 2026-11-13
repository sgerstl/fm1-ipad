package com.scottgerstl.lupe.core.debug

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.FM1Link
import com.scottgerstl.lupe.core.LinkLog
import com.scottgerstl.lupe.core.LupeStartup
import com.scottgerstl.lupe.core.LupeNative
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

/**
 * P1's link debug screen (developer only, not in the product UI). Shows the app's FM-1 link (LupeStartup) and its
 * log since start, every MIDI device's property strings, the latest `link` and `top` areas, and repeats gate 2's
 * main-actor check inside the app. In raw mode (no Session) it sends Skiff's version request and prints the reply.
 *
 *   adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity
 * Extras change the app's settings and restart it (LupeStartup): --es mode raw|session, --es core real|fake,
 * --ez allowWrites true|false.
 */
class LinkDebugActivity : ComponentActivity() {
    private var lines by mutableStateOf(emptyList<String>())
    private var areas by mutableStateOf(emptyMap<String, String>())
    private var linkState by mutableStateOf(FM1Link.State.None)
    private var devices by mutableStateOf(emptyList<String>())
    private var mainActor by mutableStateOf("not checked yet")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        if (applySettings()) return

        LinkLog.listener = { refresh() }
        LupeStartup.link?.onChange = { refresh() }
        refresh()
        setContent { Screen() }
    }

    /** adb extras → the app's settings; restarts the app when they changed. True when restarting. */
    private fun applySettings(): Boolean {
        val prefs = LupeStartup.prefs(this)
        val edit = prefs.edit()
        var changed = false
        intent.getStringExtra("mode")?.let { if (it != prefs.getString("mode", "session")) { edit.putString("mode", it); changed = true } }
        intent.getStringExtra("core")?.let { if (it != prefs.getString("core", "real")) { edit.putString("core", it); changed = true } }
        if (intent.hasExtra("allowWrites")) {
            val w = intent.getBooleanExtra("allowWrites", false)
            if (w != prefs.getBoolean("allowWrites", false)) { edit.putBoolean("allowWrites", w); changed = true }
        }
        if (!changed) return false
        edit.commit()
        restart()
        return true
    }

    private fun toggle(key: String, value: Any) {
        val e = LupeStartup.prefs(this).edit()
        when (value) { is Boolean -> e.putBoolean(key, value); is String -> e.putString(key, value) }
        e.commit()
        restart()
    }

    /** The settings are read once at start (LupeApp.onCreate), so a change restarts the process. */
    private fun restart() {
        startActivity(android.content.Intent.makeRestartActivityTask(componentName))
        Runtime.getRuntime().exit(0)
    }

    private fun refresh() {
        lines = LinkLog.lines()
        areas = LinkLog.areas()
        LupeStartup.link?.let { linkState = it.state; devices = it.seen }
        lines.lastOrNull { it.contains("main actor: ") }?.let { mainActor = it.substringAfter("main actor: ") }
    }

    override fun onDestroy() {
        LinkLog.listener = null
        LupeStartup.link?.onChange = null
        super.onDestroy()
    }

    @Composable
    private fun Screen() {
        val listState = rememberLazyListState()
        LaunchedEffect(lines.size) { if (lines.isNotEmpty()) listState.scrollToItem(lines.size - 1) }
        Column(
            Modifier.fillMaxSize().background(Tok.page).safeDrawingPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            val raw = LupeStartup.rawMode(this@LinkDebugActivity)
            val writes = LupeStartup.allowWrites(this@LinkDebugActivity)
            val fake = LupeStartup.wantsFake(this@LinkDebugActivity)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                BasicText("FM-1 link (debug)", style = LupeType.title, modifier = Modifier.semantics { heading() })
                BasicText(
                    if (fake) "The app runs the fake core: no FM-1 link." else "FM-1: " + when (linkState) {
                        FM1Link.State.None -> "not found. Plug it in with USB."
                        FM1Link.State.Opening -> "opening…"
                        FM1Link.State.Open -> "open"
                    },
                    style = LupeType.body,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
                BasicText("Mode: ${if (raw) "raw bytes, no Session" else "Session (the real app)"} · " +
                    (if (writes) "WRITES ALLOWED" else "read-only: writes are blocked"), style = LupeType.body)
                BasicText("Main actor: $mainActor", style = LupeType.body)
                areas.forEach { (k, v) -> BasicText("$k: $v", style = mono) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (raw) DebugButton("Send version request", Modifier.weight(1f)) { LupeNative.requestVersion() }
                DebugButton("Check main actor", Modifier.weight(1f)) { LupeNative.mainActorCheck() }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DebugButton(if (raw) "Use Session mode" else "Use raw mode", Modifier.weight(1f)) { toggle("mode", if (raw) "session" else "raw") }
                // No button turns writes on: a stray tap (another session drove this emulator's screen on
                // 2026-11-13 and hit one) must never open the FM-1 to writes. Only the adb extra does
                // (--ez allowWrites true); turning them off is one tap.
                if (writes) DebugButton("Make read-only", Modifier.weight(1f)) { toggle("allowWrites", false) }
            }
            if (devices.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    BasicText("MIDI devices Android lists", style = LupeType.label, modifier = Modifier.semantics { heading() })
                    SelectionContainer { BasicText(devices.joinToString("\n\n"), style = mono) }
                }
            }
            BasicText("Log", style = LupeType.label, modifier = Modifier.semantics { heading() })
            SelectionContainer(Modifier.weight(1f).fillMaxWidth().background(Tok.well, RoundedCornerShape(8.dp)).padding(12.dp)) {
                LazyColumn(state = listState, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    items(lines) { BasicText(it, style = mono) }
                }
            }
        }
    }

    private val mono = LupeType.small.copy(fontFamily = FontFamily.Monospace, fontSize = 12.sp, lineHeight = 16.sp)

    @Composable
    private fun DebugButton(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
        val source = remember { MutableInteractionSource() }
        val focused by source.collectIsFocusedAsState()
        val pressed by source.collectIsPressedAsState()
        val shape = RoundedCornerShape(Tok.CHICLET_RADIUS.dp)
        Box(
            modifier
                .heightIn(min = 48.dp)
                .background(if (pressed) Tok.pressed else Tok.control, shape)
                // Focus ring: text grey on the page is well over 3:1.
                .border(if (focused) 2.dp else 1.dp, if (focused) Tok.text else Tok.outline, shape)
                .clickable(interactionSource = source, indication = null, role = Role.Button, onClick = onClick)
                .padding(horizontal = 12.dp, vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) { BasicText(label, style = LupeType.key) }
    }
}

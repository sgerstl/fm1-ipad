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
import androidx.compose.runtime.mutableStateListOf
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
import com.scottgerstl.lupe.core.LupeNative
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * P1 gate 3's debug screen (developer only, not in the product UI). Opens the FM-1 through FM1Link and
 * AndroidTransport with no Session, sends Skiff's version request (INFO) and shows the reply, lists every MIDI
 * device's property strings, and repeats gate 2's main-actor check inside the app.
 *
 *   adb shell am start -n com.scottgerstl.lupe/.core.debug.LinkDebugActivity
 */
class LinkDebugActivity : ComponentActivity() {
    private val lines = mutableStateListOf<String>()
    private var linkState by mutableStateOf(FM1Link.State.None)
    private var devices by mutableStateOf(emptyList<String>())
    private var mainActor by mutableStateOf("not checked yet")
    private lateinit var link: FM1Link
    private val clock = SimpleDateFormat("HH:mm:ss.SSS", Locale.ROOT)

    private fun add(line: String) {
        lines.add("${clock.format(Date())}  $line")
        if (lines.size > 500) lines.removeRange(0, lines.size - 500)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )

        val problem = LupeNative.load()   // on the UI thread, first (BRIDGE.md §3)
        add(if (problem.isEmpty()) "Swift loaded; main actor hooked to the UI thread's Looper" else "MainLooper.install failed: $problem")

        LupeNative.debugListener = { line -> runOnUiThread {
            add(line)
            if (line.startsWith("main actor:")) mainActor = line.removePrefix("main actor: ")
        } }
        link = FM1Link(applicationContext, rawMode = true).also { l ->
            l.onLog = { add(it) }
            l.onChange = { linkState = l.state; devices = l.seen }
        }
        LupeNative.link = link
        link.start()

        setContent { Screen() }
    }

    override fun onDestroy() {
        LupeNative.debugListener = null
        super.onDestroy()
    }

    @Composable
    private fun Screen() {
        val listState = rememberLazyListState()
        LaunchedEffect(lines.size) { if (lines.isNotEmpty()) listState.animateScrollToItem(lines.size - 1) }
        Column(
            Modifier.fillMaxSize().background(Tok.page).safeDrawingPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                BasicText("FM-1 link (debug)", style = LupeType.title, modifier = Modifier.semantics { heading() })
                BasicText(
                    "FM-1: " + when (linkState) {
                        FM1Link.State.None -> "not found. Plug it in with USB."
                        FM1Link.State.Opening -> "opening…"
                        FM1Link.State.Open -> "open"
                    },
                    style = LupeType.body,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
                BasicText("Main actor: $mainActor", style = LupeType.body)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DebugButton("Send version request", Modifier.weight(1f)) { LupeNative.requestVersion() }
                DebugButton("Check main actor", Modifier.weight(1f)) { LupeNative.mainActorCheck() }
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

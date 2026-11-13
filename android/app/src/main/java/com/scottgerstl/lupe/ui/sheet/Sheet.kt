package com.scottgerstl.lupe.ui.sheet

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.ui.shell.Key
import com.scottgerstl.lupe.ui.theme.Dur
import com.scottgerstl.lupe.ui.theme.EaseIn
import com.scottgerstl.lupe.ui.theme.EaseOut
import com.scottgerstl.lupe.ui.theme.LocalReduceMotion
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok
import com.scottgerstl.lupe.ui.theme.animatedFloat
import com.scottgerstl.lupe.ui.theme.unscaled
import kotlinx.coroutines.launch
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.layout.size

enum class SheetKind { Projects, Settings }

/** Which sheet is up. The FM-1 key's menu sets it; [LupeSheetLayer] draws it. */
@Stable
class SheetHost {
    var open by mutableStateOf<SheetKind?>(null)
    /** Settings opened from the FM-1 menu's Labs row: scroll to the Labs section. */
    var toLabs by mutableStateOf(false)
    fun show(kind: SheetKind, labs: Boolean = false) { toLabs = labs; open = kind }
    fun close() { open = null }
}

val LocalSheetHost = staticCompositionLocalOf { SheetHost() }

/**
 * A sheet that rises from the bottom (board 67): a scrim that fades in, the panel that travels up in 300 ms (ease-out
 * in, 200 ms out; with Reduce Motion both only fade). Drag it down, ✕, the scrim or Back closes it. It holds a
 * title, ✕, and scrolling content, and is a pane of its own for TalkBack.
 */
@Composable
fun LupeSheet(visible: Boolean, title: String, onDismiss: () -> Unit, modifier: Modifier = Modifier, scroll: androidx.compose.foundation.ScrollState = rememberScrollState(), content: @Composable ColumnScope.() -> Unit) {
    val reduce = LocalReduceMotion.current
    val t = animatedFloat(if (visible) 1f else 0f, if (visible) Dur.PANEL else Dur.EXIT, if (visible) EaseOut else EaseIn)
    if (!visible && t.value <= 0.001f) return
    BackHandler(enabled = visible) { onDismiss() }
    val scope = rememberCoroutineScope()
    val drag = remember { Animatable(0f) }
    LaunchedEffect(visible) { if (visible) drag.snapTo(0f) }
    val density = LocalDensity.current
    BoxWithConstraints(modifier.fillMaxSize()) {
        val maxSheet = maxHeight * 0.86f
        // the scrim: what's behind is dimmed and can't be touched
        Box(
            Modifier.fillMaxSize().graphicsLayer { alpha = t.value }.background(Color.Black.copy(alpha = 0.55f))
                .pointerInput(Unit) { detectTapGestures { onDismiss() } },
        )
        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .heightIn(max = maxSheet)
                .graphicsLayer {
                    alpha = if (reduce) t.value else 1f
                    if (!reduce) translationY = (1f - t.value) * size.height.coerceAtLeast(1f) + drag.value
                }
                .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
                .background(Tok.panel)
                .pointerInput(Unit) { detectTapGestures { } }   // taps on the sheet don't reach the scrim
                .semantics { paneTitle = title; isTraversalGroup = true }
                .navigationBarsPadding(),
        ) {
            // the header: the grab handle, the title and ✕. Dragging it down closes the sheet
            Column(
                Modifier.pointerInput(Unit) {
                    detectVerticalDragGestures(
                        onVerticalDrag = { change, dy -> change.consume(); scope.launch { drag.snapTo((drag.value + dy).coerceAtLeast(0f)) } },
                        onDragEnd = {
                            scope.launch {
                                if (drag.value > 96.dp.toPx()) onDismiss() else unscaled { drag.animateTo(0f, tween(Dur.FINGER, easing = EaseOut)) }
                            }
                        },
                        onDragCancel = { scope.launch { unscaled { drag.animateTo(0f, tween(Dur.FINGER, easing = EaseOut)) } } },
                    )
                },
            ) {
                Box(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                    Box(Modifier.width(44.dp).height(5.dp).background(Tok.lifted, RoundedCornerShape(3.dp)))
                }
                Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    BasicText(title, Modifier.weight(1f).semantics { heading() }, style = LupeType.title)
                    Key(onDismiss, "Close $title", width = 48.dp, height = 40.dp) { fg ->
                        Canvas(Modifier.size(12.dp)) {
                            val w = 2.dp.toPx()
                            drawLine(fg, Offset(0f, 0f), Offset(size.width, size.height), w, StrokeCap.Round)
                            drawLine(fg, Offset(size.width, 0f), Offset(0f, size.height), w, StrokeCap.Round)
                        }
                    }
                }
            }
            Column(Modifier.weight(1f, fill = false).verticalScroll(scroll).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 24.dp), content = content)
        }
    }
}

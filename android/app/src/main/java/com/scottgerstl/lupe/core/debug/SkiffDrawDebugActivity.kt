package com.scottgerstl.lupe.core.debug

import android.graphics.Bitmap
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.core.LupeNative
import com.scottgerstl.lupe.ui.theme.Tok
import java.io.File
import java.nio.ByteBuffer

/**
 * Decision 45's spike (2026-11-15, developer only, not in the product UI): the FM-1's screen drawn by Skiff-Lupe
 * 2.5.1's own UI code in the Swift core (ios/SkiffDraw), from the session's mirror, about 30 frames a second.
 *
 *   adb -s emulator-5584 shell am start -n com.scottgerstl.lupe/.core.debug.SkiffDrawDebugActivity --ei page 0 --ei theme 0
 * page: 0 GLO › DELAY, 1 GLO › REVERB, 2 EDIT 1 (the scope), 3 HOME's scope, 4 the FM-1's own page. Each first frame
 * is also written raw to files/skiff-frame.rgba for a pixel comparison (adb exec-out run-as … cat files/skiff-frame.rgba).
 */
class SkiffDrawDebugActivity : ComponentActivity() {
    private var frame by mutableStateOf<Bitmap?>(null)
    private var drawUs by mutableStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        LupeNative.load()
        val page = intent.getIntExtra("page", 0)
        val theme = intent.getIntExtra("theme", 0)
        setContent {
            LaunchedEffect(page, theme) {
                var first = true
                var last = 0L
                while (true) {
                    val now = withFrameNanos { it }
                    if (now - last < 33_000_000L) continue
                    last = now
                    val b = LupeNative.skiffFrame(page, theme)
                    val n = 240 * 240 * 4
                    drawUs = (b[n].toInt() and 255) or ((b[n + 1].toInt() and 255) shl 8) or ((b[n + 2].toInt() and 255) shl 16)
                    if (first) { File(filesDir, "skiff-frame.rgba").writeBytes(b.copyOf(n)); first = false }
                    val bmp = Bitmap.createBitmap(240, 240, Bitmap.Config.ARGB_8888)
                    bmp.copyPixelsFromBuffer(ByteBuffer.wrap(b, 0, n))      // RGBA bytes: ARGB_8888's memory order
                    frame = bmp
                }
            }
            Column(
                Modifier.fillMaxSize().background(Tok.page).safeDrawingPadding().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                BasicText("Skiff's own drawing (spike)", style = TextStyle(color = Tok.text, fontSize = 17.sp))
                frame?.let {
                    Image(it.asImageBitmap(), contentDescription = "The FM-1's screen, drawn by Skiff's own code",
                          filterQuality = FilterQuality.None, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
                }
                BasicText("Draw: $drawUs µs a frame", style = TextStyle(color = Tok.text2, fontSize = 13.sp))
            }
        }
    }
}

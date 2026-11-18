package com.scottgerstl.lupe

import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w900dp-h400dp-land", application = android.app.Application::class)
/**
 * Documents a Robolectric limit the panel tests work around: a layer clipped to a RoundedCornerShape with uneven corners (the docked panels'
 * topStart/bottomStart) isn't hit by injected touches under Robolectric, though a uniform one is; on the device both are.
 */
class HitExperimentTest {
    @get:Rule val rule = createComposeRule()
    fun run(top: Modifier): Int {
        var under = 0
        rule.setContent { Box(Modifier.fillMaxSize()) { Box(Modifier.fillMaxSize().testTag("u").clickable { under++ }); Box(Modifier.align(Alignment.TopEnd).width(360.dp).fillMaxHeight().then(top)) } }
        rule.onNodeWithTag("u").performTouchInput { click(Offset(width - 60f, height / 2f)) }; rule.waitForIdle(); return under
    }
    @Test fun a() { org.junit.Assert.assertEquals("an overlay with a tap detector stops the tap", 0, run(Modifier.pointerInput(Unit) { detectTapGestures { } })) }
    @Test fun b() { org.junit.Assert.assertEquals("no overlay: it reaches", 1, run(Modifier)) }
    @Test fun d() { org.junit.Assert.assertEquals("Robolectric: uneven rounded clip misses (device does not)", 1, run(Modifier.graphicsLayer { shape = androidx.compose.foundation.shape.RoundedCornerShape(topStart = 24.dp, bottomStart = 24.dp); clip = true }.pointerInput(Unit) { detectTapGestures { } })) }
    @Test fun e() { org.junit.Assert.assertEquals("uniform rounded clip is hit", 0, run(Modifier.graphicsLayer { alpha = 1f; translationX = 0f; shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp); clip = true }.pointerInput(Unit) { detectTapGestures { } })) }
    @Test fun c() { org.junit.Assert.assertEquals("a moved layer still stops it", 0, run(Modifier.graphicsLayer { translationX = 0f }.pointerInput(Unit) { detectTapGestures { } })) }
}

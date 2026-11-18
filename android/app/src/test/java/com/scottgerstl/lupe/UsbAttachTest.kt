package com.scottgerstl.lupe

import android.content.Intent as AIntent
import android.hardware.usb.UsbManager
import androidx.test.core.app.ApplicationProvider
import com.scottgerstl.lupe.core.EditorState
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LinkState
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.core.PadsState
import com.scottgerstl.lupe.core.PageState
import com.scottgerstl.lupe.core.ShellState
import com.scottgerstl.lupe.core.TopState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Lupe opens when the FM-1 is plugged in (Scott, 2026-11-18). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class)
class UsbAttachTest {
    private class RecCore : LupeCore {
        val sent = mutableListOf<Intent>()
        override val link: StateFlow<LinkState> = MutableStateFlow(LinkState())
        override val top: StateFlow<TopState> = MutableStateFlow(TopState())
        override val shell: StateFlow<ShellState> = MutableStateFlow(ShellState())
        override val pads: StateFlow<PadsState> = MutableStateFlow(PadsState())
        override val editor: StateFlow<EditorState> = MutableStateFlow(EditorState())
        override val page: StateFlow<PageState> = MutableStateFlow(PageState())
        override fun send(intent: Intent) { sent += intent }
    }

    @Test fun theAttachIntentResolvesToLupesOneActivity() {
        val ctx = ApplicationProvider.getApplicationContext<android.app.Application>()
        val found = ctx.packageManager.queryIntentActivities(AIntent(UsbManager.ACTION_USB_DEVICE_ATTACHED).setPackage(ctx.packageName), 0)
        assertEquals(listOf("com.scottgerstl.lupe.MainActivity"), found.map { it.activityInfo.name })
        assertEquals(android.content.pm.ActivityInfo.LAUNCH_SINGLE_TASK, found.single().activityInfo.launchMode)
    }

    @Test fun theDeviceFilterNamesTheFm1() {
        val ctx = ApplicationProvider.getApplicationContext<android.app.Application>()
        val p = ctx.resources.getXml(R.xml.device_filter)
        var vid = -1; var pid = -1
        while (p.next() != org.xmlpull.v1.XmlPullParser.END_DOCUMENT) if (p.eventType == org.xmlpull.v1.XmlPullParser.START_TAG && p.name == "usb-device") {
            vid = p.getAttributeIntValue(null, "vendor-id", -1); pid = p.getAttributeIntValue(null, "product-id", -1)
        }
        assertEquals(0x1209, vid); assertEquals(0x0001, pid)
    }

    @Test fun eachPlugInRetriesTheSameCoreOnce() {
        val core = RecCore()
        assertTrue(onFm1Attached(AIntent(UsbManager.ACTION_USB_DEVICE_ATTACHED), core))
        assertTrue(onFm1Attached(AIntent(UsbManager.ACTION_USB_DEVICE_ATTACHED), core))
        assertFalse(onFm1Attached(AIntent(AIntent.ACTION_MAIN), core))
        assertEquals(listOf<Intent>(Intent.Retry, Intent.Retry), core.sent)
    }

    // the sleep bug (Scott, 2026-11-18): the screen turning as the phone slept relaunched the window with the attach intent it opened
    // with, and that Retry dropped a working connection
    @Test fun aRelaunchWithTheSameIntentDoesNotRetry() {
        val core = RecCore()
        assertFalse(onFm1Attached(AIntent(UsbManager.ACTION_USB_DEVICE_ATTACHED), core, relaunch = true))
        assertTrue(core.sent.isEmpty())
    }
}

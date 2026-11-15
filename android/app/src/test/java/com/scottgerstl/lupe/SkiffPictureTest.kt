package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.page.SKIFF_GLO_INK
import com.scottgerstl.lupe.ui.page.decodeSkiffPicture
import org.junit.Assert.*
import org.junit.Test

/** Decision 46: what LupeNative.skiffPicture hands Kotlin (ios/SkiffDraw via android/core/Sources/LupeNative/SkiffPictures.swift). */
class SkiffPictureTest {
    private fun bytes(w: Int, h: Int, animated: Boolean, us: Int, px: (Int) -> IntArray): ByteArray {
        val b = ByteArray(8 + w * h * 4)
        b[0] = (w and 255).toByte(); b[1] = (w shr 8).toByte(); b[2] = (h and 255).toByte(); b[3] = (h shr 8).toByte()
        b[4] = if (animated) 1 else 0; b[5] = (us and 255).toByte(); b[6] = (us shr 8).toByte()
        for (i in 0 until w * h) { val c = px(i); for (k in 0..3) b[8 + 4 * i + k] = c[k].toByte() }
        return b
    }

    @Test fun theFm1sPanelDecodesAs234By138Argb() {
        val p = decodeSkiffPicture(bytes(234, 138, false, 410) { i -> if (i == 0) intArrayOf(0, 0, 0, 0) else intArrayOf(0xFF, 0x5A, 0x36, 0xFF) })!!
        assertEquals(234, p.width); assertEquals(138, p.height); assertFalse(p.animated); assertEquals(410, p.drawMicros)
        assertEquals(0x00000000, p.argb[0])                                  // outside a rounded corner: transparent
        assertEquals(0xFFFF5A36.toInt(), p.argb[1])                          // SKIFF's track 1, RGBA → ARGB
    }

    @Test fun theSeaAndTheLfoSayTheyMove() {
        assertTrue(decodeSkiffPicture(bytes(2, 2, true, 1) { intArrayOf(1, 2, 3, 255) })!!.animated)
    }

    @Test fun nothingOrTooShortMeansTheHandDrawnPicture() {
        assertNull(decodeSkiffPicture(null))                                 // another firmware build, a page SkiffDraw doesn't draw, offline
        assertNull(decodeSkiffPicture(ByteArray(5)))
        assertNull(decodeSkiffPicture(bytes(234, 138, false, 0) { intArrayOf(0, 0, 0, 0) }.copyOf(100)))
        assertNull(decodeSkiffPicture(bytes(0, 138, false, 0) { intArrayOf(0, 0, 0, 0) }))
    }

    @Test fun glosInkIsThePanelsRaisedGrey() {
        assertEquals(0xFFC4C4CC.toInt(), (0xFF000000.toInt() or SKIFF_GLO_INK))
        assertEquals(com.scottgerstl.lupe.ui.theme.Tok.text2Raised.value, androidx.compose.ui.graphics.Color(0xFF000000.toInt() or SKIFF_GLO_INK).value)
    }
}

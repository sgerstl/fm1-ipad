package com.scottgerstl.lupe.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.ui.slide.LocalPhoneSettings

/**
 * The hybrid UI's shapes (design/hybrid-ui/tokens-proposal.json, approved as the direction for Android 2026-11-17). Not in tokens/tokens.json
 * yet: radii and shape pairs go in when Scott settles the look after the Pixel trial. No new colours: the hybrid uses Lupe's surface and text tokens.
 */
object Shape {
    val key = 8.dp        // inner corners of connected groups, app-strip keys (today's chiclet radius)
    val pad = 10.dp       // the idle, queued and pressed pad
    val panel = 14.dp     // menus, popups
    val sheet = 24.dp     // sheet top corners, docked panels
    /** A selectable thing selected squares off (shape as state): 12 at 40 tall. */
    val selected = 12.dp
    // the transport (decision 23's round keys, sized for priority; Scott 2026-11-17)
    val record = 48.dp
    val playStop = 56.dp
    // the switch: the thumb grows when on
    val switchThumbOff = 16.dp
    val switchThumbOn = 24.dp
}

/**
 * The motion table's starting values (spec §5), read from Labs (Settings › Labs › Hybrid motion; CLAUDE.md rule 3: added 2026-11-17,
 * review 2026-12-01). Graduates to tokens.json's `motion` when Scott settles it on the Pixel.
 */
class HybridMotion(
    /** Spatial spring bounce, 0..0.5 (spec: 0.25; sheets and popups 0.05 less). */
    val bounce: Float,
    /** At the finger: pad shape, hold menu, popup (spec 200). */
    val fingerMs: Int,
    /** Sheets and docked panels (spec 300). */
    val panelMs: Int,
    /** The 8-step page flip (spec 280). */
    val pageFlipMs: Int,
    /** A press squashes to this (spec 0.92). */
    val pressScale: Float,
) {
    val sheetBounce get() = (bounce - 0.05f).coerceAtLeast(0f)
}

val hybridMotion: HybridMotion
    @Composable @ReadOnlyComposable get() {
        val s = LocalPhoneSettings.current
        return HybridMotion(s.motionBounce / 100f, s.motionFingerMs, s.motionPanelMs, s.motionPageFlipMs, s.motionPressScale / 100f)
    }

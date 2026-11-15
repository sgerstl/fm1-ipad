package com.scottgerstl.lupe

import com.scottgerstl.lupe.ui.intro.IntroMath
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The launch intro's timing and geometry (ported from ios/FM1/LaunchIntro.swift): the phases add up to the prototype's 2.9 s, and the trail is drawn from age. */
class IntroMathTest {
    @Test fun thePhasesAddUpToAboutTwoPointNineSeconds() {
        assertEquals(0.42 + 0.22, IntroMath.tf, 1e-9)                     // zoom, then the power-on line
        assertEquals(0.42 + 0.22 + 1.06, IntroMath.tt, 1e-9)              // one pass in 1.06 s
        assertEquals(2.10, IntroMath.ts, 1e-9)                            // settled 0.4 s later
        assertEquals((IntroMath.tt + 0.4 * 0.35) * 0.8, IntroMath.na, 1e-9)   // the name starts about as the trace ends
        assertEquals(2.10, IntroMath.tn, 1e-9)                            // its 0.52 s fade ends before the settle does
        assertEquals(2.50, IntroMath.th, 1e-9)                            // held 0.4 s
        assertEquals(2.90, IntroMath.end, 1e-9)                           // squash 0.12, pinch 0.10, blip 0.18
        assertEquals(1.94, IntroMath.REDUCED_END, 1e-9)                   // Reduce Motion: the logo, then a crossfade
    }

    @Test fun theFigureIsTheIconsLissajous() {
        val (x, y) = IntroMath.fig(0.0)                                   // the beam's start: t = 0.31 · 2π
        val t = 0.31 * 2 * Math.PI
        assertEquals(50 + Math.sin(3 * t + 0.9 * Math.sin(2 * t)) * 28, x, 1e-9); assertEquals(50 + Math.sin(2 * t) * 28, y, 1e-9)
        val (x1, y1) = IntroMath.fig(1.0)                                 // one full pass closes the figure
        assertEquals(x, x1, 1e-9); assertEquals(y, y1, 1e-9)
    }

    @Test fun theBeamMakesOnePassThenEasesToItsRest() {
        assertEquals(0.0, IntroMath.beamU(IntroMath.tf - 0.1), 0.0)
        assertEquals(0.5, IntroMath.beamU(IntroMath.tf + 0.53), 1e-9)
        assertEquals(1.0, IntroMath.beamU(IntroMath.tt), 1e-9)
        assertEquals(1.02, IntroMath.beamU(IntroMath.ts), 1e-9)           // its rest, 0.02 on
        assertEquals(1.02, IntroMath.beamU(5.0), 1e-9)
    }

    @Test fun aBitOfTrailIsPaintedWhenTheBeamPassesAndCoolsByItsAge() {
        for (u in listOf(0.0, 0.25, 0.9, 1.0)) assertEquals(IntroMath.tf + u * IntroMath.TRACE, IntroMath.paintTime(u), 1e-9)
        for (u in listOf(1.004, 1.01, 1.02)) assertEquals(u, IntroMath.beamU(IntroMath.paintTime(u)), 1e-6)        // painted when the beam reached it, in the settle
        assertEquals(0.0, IntroMath.coolFrames(1.0, 0.5), 0.0)                                                    // not yet painted: no age
        assertEquals(30.0, IntroMath.coolFrames(1.0, 1.5), 1e-9)                                                  // half a second of tracing: 30 frames
        // the cooling slows through the settle and stops once settled: the last frame is the icon
        val settled = IntroMath.coolFrames(IntroMath.tf + 0.2, IntroMath.ts)
        assertEquals(settled, IntroMath.coolFrames(IntroMath.tf + 0.2, IntroMath.ts + 3.0), 1e-9)
        assertTrue(IntroMath.coolFrames(IntroMath.tt, IntroMath.ts) < 0.4 * 60)
    }

    @Test fun theTrailCoolsFromWhiteToDimGreyAndFades() {
        val (k0, a0) = IntroMath.cool(0.0); assertEquals(1.0, k0, 0.0); assertEquals(1.0, a0, 0.0)               // fresh: white, whole
        val c = IntroMath.mix(IntroMath.OLD, IntroMath.FRESH, IntroMath.cool(40.0).first)
        assertTrue(c.first < 80 && c.first > 70)                                                                  // nearly the dim grey after 40 frames
        assertTrue(IntroMath.cool(40.0).second < 0.12)
    }

    @Test fun easeIsCubicOutAndClamped() {
        assertEquals(0.0, IntroMath.ease(-1.0), 0.0); assertEquals(1.0, IntroMath.ease(2.0), 0.0); assertEquals(0.875, IntroMath.ease(0.5), 1e-9)
    }

    @Test fun theTrailIsSixHundredBitsAtMost() {
        assertEquals(2, IntroMath.trailSegments(0.001)); assertEquals(600, IntroMath.trailSegments(1.0)); assertEquals(612, IntroMath.trailSegments(1.02))
    }
}

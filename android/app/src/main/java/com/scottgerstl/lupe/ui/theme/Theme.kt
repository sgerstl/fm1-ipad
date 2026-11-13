package com.scottgerstl.lupe.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.scottgerstl.lupe.R

/** tokens/tokens.json v2 (the flat look). Mirrors ios/FM1/Theme.swift; change the JSON first, then these. */
object Tok {
    // surface
    val page = Color(0xFF0D0D0F)
    val well = Color(0xFF111114)
    val panel = Color(0xFF1A1A1E)
    val control = Color(0xFF26262B)
    val lifted = Color(0xFF34343B)
    val held = Color(0xFF3E3E46)
    val pressed = Color(0xFF141417)
    // chiclet
    val chicletEdge = Color(0xFF0A0A0C)
    val primaryTop = Color(0xFFEDEDF0)
    val primaryEdge = Color(0xFF8A8A92)
    val outline = Color(0xFF4A4A52) // arrange.restOutline
    // text: four greys. text3 (tertiary) is for decoration that carries no information, never for words
    // (#71717A on #1A1A1E is under 4.5:1).
    val text = Color(0xFFEDEDF0)
    val text2 = Color(0xFFA1A1AA)
    val text2Raised = Color(0xFFC4C4CC)
    val text3 = Color(0xFF71717A)
    val onColour = Color(0xFF101012)
    /**
     * REC. TOKEN GAP: tokens.json has no REC colour (iOS has Theme.recText); this is the value from the phone
     * boards (design/boards/phone-portrait.html --rec). Add it to tokens.json, then read it from there.
     */
    val rec = Color(0xFFFF4D4D)

    const val CHICLET_RADIUS = 8f   // dp
    const val CHICLET_EDGE = 2f     // dp
}

private val Barlow = FontFamily(
    Font(R.font.barlow_regular, FontWeight.Normal),
    Font(R.font.barlow_semibold, FontWeight.SemiBold),
)
private val BarlowCondensed = FontFamily(
    Font(R.font.barlowcondensed_semibold, FontWeight.SemiBold),
    Font(R.font.barlowcondensed_bold, FontWeight.Bold),
)

/** DESIGN.md "Type": Barlow for words (400 and 600 only), Barlow Condensed for numbers. */
object LupeType {
    private fun words(size: Int, weight: FontWeight, color: Color) =
        TextStyle(fontFamily = Barlow, fontSize = size.sp, fontWeight = weight, color = color, lineHeight = (size * 1.2f).sp)

    val title = words(20, FontWeight.SemiBold, Tok.text)
    val key = words(14, FontWeight.SemiBold, Tok.text)
    val body = words(15, FontWeight.Normal, Tok.text2Raised)
    val small = words(12, FontWeight.Normal, Tok.text2Raised)
    val label = words(12, FontWeight.SemiBold, Tok.text2Raised)

    /** Big numbers: the readout's bar · beat, values. Even figures. */
    val number = TextStyle(
        fontFamily = BarlowCondensed, fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = Tok.text,
        lineHeight = 22.sp, fontFeatureSettings = "tnum",
    )
}

/**
 * Android's "Remove animations" (Settings › Accessibility) sets the animator scale to 0. DESIGN.md: with
 * Reduce Motion nothing travels, arrivals and state changes cross-fade; it never means "pop".
 */
val LocalReduceMotion = compositionLocalOf { false }

@Composable
fun LupeTheme(reduceMotion: Boolean, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalReduceMotion provides reduceMotion, content = content)
}

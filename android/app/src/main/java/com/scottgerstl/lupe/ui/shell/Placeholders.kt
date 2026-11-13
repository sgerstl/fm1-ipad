package com.scottgerstl.lupe.ui.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.scottgerstl.lupe.core.BottomKind
import com.scottgerstl.lupe.core.BottomPage
import com.scottgerstl.lupe.core.Tab
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

/** What stands where a later phase's screen will go. Nothing here is the design: it says whose it is. */
@Composable
fun Placeholder(title: String, note: String, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxSize().background(Tok.well, RoundedCornerShape(12.dp)).padding(16.dp),
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        BasicText(title, style = LupeType.title.copy(textAlign = TextAlign.Center))
        BasicText(note, Modifier.padding(top = 4.dp), style = LupeType.body.copy(textAlign = TextAlign.Center))
    }
}

@Composable
fun TopPlaceholder(tab: Tab, modifier: Modifier = Modifier) = when (tab) {
    Tab.Pads -> Placeholder("Pads", "Six rows of pads and the scenes row: phase 3", modifier)
    Tab.Timeline -> Placeholder("Timeline", "Six track columns, bars running down: phase 6", modifier)
    Tab.Mix -> Placeholder("Mix", "GLO's five pages, one at a time: phase 5", modifier)
}

/** The bottom half's slot: it follows the FM-1's page (shell.bottom). */
@Composable
fun BottomPlaceholder(page: BottomPage, modifier: Modifier = Modifier) = when (page.kind) {
    BottomKind.Editor -> Placeholder("Editor", "SEQ on the FM-1: the step grid and the step panel, phase 3", modifier)
    BottomKind.Page -> Placeholder("${page.family ?: ""} · ${page.page ?: ""}", "A sound page: four controls in the FM-1's knob order, phase 4", modifier)
}

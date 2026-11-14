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
import com.scottgerstl.lupe.ui.theme.LupeType
import com.scottgerstl.lupe.ui.theme.Tok

/** An empty state: what is missing and the first thing to do about it. */
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

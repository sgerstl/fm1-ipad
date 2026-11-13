package com.scottgerstl.lupe.ui.timeline

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.scottgerstl.lupe.core.Intent
import com.scottgerstl.lupe.core.LupeCore
import com.scottgerstl.lupe.ui.sounds.LocalSoundsHost

/**
 * The Timeline's state and what a touch does. The song itself is a stand-in ([MockTimeline]) until P1's `timeline`
 * area lands; the things the shell already owns go to the core (Stop, which track is selected) and the Sounds browser.
 */
@Composable
fun rememberTimeline(core: LupeCore): Pair<TimelineUi, TimelineActions> {
    val mock = remember { MockTimeline() }
    val sounds = LocalSoundsHost.current
    val base = mock.actions
    val actions = remember(core, sounds) {
        TimelineActions(
            select = base.select, selectTrack = { core.send(Intent.TrackSelect(it)); base.selectTrack(it) },
            move = base.move, resize = base.resize, setPattern = base.setPattern, duplicate = base.duplicate, delete = base.delete,
            stop = { core.send(Intent.Stop) }, openSounds = { sounds.open(it) },
        )
    }
    return mock.ui to actions
}

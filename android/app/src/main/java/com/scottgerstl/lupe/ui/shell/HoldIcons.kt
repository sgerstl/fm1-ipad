package com.scottgerstl.lupe.ui.shell

import androidx.annotation.DrawableRes
import com.scottgerstl.lupe.R

/**
 * The icon in a hold-menu choice's disc (decision 36, Scott's pick: board 78 tile 11). Material Symbols Rounded, weight 400, one size (24 px,
 * drawn at 14 dp), each the nearest match to the SF Symbol the iPhone uses for the same choice, so the two phones stay paired. Licence and
 * source: android/THIRD_PARTY.md.
 *
 * | Choice (its title starts…)          | Material Symbol  | iPhone's SF Symbol                |
 * |-------------------------------------|------------------|-----------------------------------|
 * | Edit steps, Edit pattern            | edit             | pencil                            |
 * | Select sound, Sounds                | graphic_eq       | waveform                          |
 * | Set pattern, Pick a pattern, Patterns | grid_view      | square.grid.2x2 (.fill)           |
 * | Recycle an unused pattern           | recycling        | arrow.triangle.2.circlepath       |
 * | Put a kept pattern here             | content_paste    | doc.on.clipboard                  |
 * | Pattern NN (a list's choices)       | tag              | (a number chip)                   |
 * | New pattern                         | add_box          | plus.square                       |
 * | Rest, REST                          | pause            | pause                             |
 * | Play once more, Add a REST          | add              | plus                              |
 * | Play once less                      | remove           | minus                             |
 * | Duplicate, Duplicate after          | library_add      | plus.square.on.square             |
 * | Move earlier                        | arrow_back       | arrow.left                        |
 * | Move later                          | arrow_forward    | arrow.right                       |
 * | Clear, Delete, Erase                | delete           | trash                             |
 * | Clear N unused patterns             | delete_sweep     | trash (the several)               |
 * | Chain                               | link             | link                              |
 * | Split the chain                     | content_cut      | scissors                          |
 * | Insert before, Add a pattern        | playlist_add     | text.append                       |
 * | Passes                              | repeat           | repeat                            |
 * | Mute                                | volume_off       | speaker.slash                     |
 * | Solo                                | headphones       | headphones                        |
 * | LEVEL                               | volume_up        | speaker.wave.2                    |
 * | PAN                                 | swap_horiz       | arrow.left.and.right              |
 * | Cancel                              | close            | xmark                             |
 */
@DrawableRes
fun holdIcon(title: String): Int? {
    val t = title.trim()
    return when {
        t.startsWith("Edit") -> R.drawable.ms_edit
        t.startsWith("Select sound") || t.startsWith("Sounds") -> R.drawable.ms_graphic_eq
        t.startsWith("Recycle") -> R.drawable.ms_recycling
        t.startsWith("Put a kept pattern") -> R.drawable.ms_content_paste
        t.startsWith("Set pattern") || t.startsWith("Pick a pattern") || t == "Patterns…" -> R.drawable.ms_grid_view
        t.startsWith("Pattern ") -> R.drawable.ms_tag
        t.startsWith("New pattern") -> R.drawable.ms_add_box
        t.equals("Rest", true) -> R.drawable.ms_pause
        t.startsWith("Add a REST") || t.startsWith("Play once more") -> R.drawable.ms_add
        t.startsWith("Play once less") -> R.drawable.ms_remove
        t.startsWith("Duplicate") -> R.drawable.ms_library_add
        t.startsWith("Move earlier") -> R.drawable.ms_arrow_back
        t.startsWith("Move later") -> R.drawable.ms_arrow_forward
        t.startsWith("Clear ") && t.contains("unused") || t.startsWith("No unused") -> R.drawable.ms_delete_sweep
        t.startsWith("Clear") || t.startsWith("Delete") || t.startsWith("Erase") -> R.drawable.ms_delete
        t.startsWith("Chain") -> R.drawable.ms_link
        t.startsWith("Split") -> R.drawable.ms_content_cut
        t.startsWith("Insert before") || t.startsWith("Add a pattern") -> R.drawable.ms_playlist_add
        t.startsWith("Passes") -> R.drawable.ms_repeat
        t.startsWith("Mute") -> R.drawable.ms_volume_off
        t.startsWith("Solo") -> R.drawable.ms_headphones
        t.equals("LEVEL", true) -> R.drawable.ms_volume_up
        t.equals("PAN", true) -> R.drawable.ms_swap_horiz
        t.startsWith("Cancel") -> R.drawable.ms_close
        else -> null
    }
}

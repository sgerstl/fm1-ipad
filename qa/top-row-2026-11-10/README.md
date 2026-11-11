# One row above the Pads: before and after (2026-11-10)

Scott's direction (b) from board 47, with his changes: Launch at as a dropdown, the playback mode in the tempo popup,
and (his pick A) the Timeline's tools in the same row. His hard rule: nothing else we've refined may move.

**How:** `capture.sh before|after` launches the demo FM-1 held stopped (`-demo-stopped`), with each scene's settings
as launch arguments, and waits for two matching frames. Landscape 2752 × 2064 (the app is landscape-only on iPad, so
there's no portrait). Two `before` runs matched to the pixel. `diff.py` compares everything under the top bar with the
`before` picture moved up 52 pt and lists the bands that differ (`diff-result.txt`); red overlays are in `diff/`.

## What was compared

| Scene | Result |
|---|---|
| Pads, Half, T1 (box opens down) | **Identical** from the page's top to the editor (514 pt). Below it the editor is 52 pt taller (agreed) |
| Pads, Half, T6 (box opens up) | **Identical** down to the editor (515 pt); the editor taller |
| Pads, Half, T3 / T4 | Same direction as before: T3 opens down (it did before too), T4 opens up |
| Timeline, Half, T1 and T4 | The Timeline's top (104–162 pt: the "Tracks end at…" strip now over the ruler's middle; allowed). Lanes and the box **identical** down to the editor; the editor taller |
| Pads, Max | The row of 16 moved up 52 pt, unchanged; the editor 52 pt taller |
| Pads, full, T1 / T5 / controls shut | Rows taller (each about 8.7 pt), as agreed. Each box hangs from its pad as before (T1 down, T5 up). Shut: the new open tab under T1's pad A |
| **Pads, full, T2 (with an effect chip)** | **Changed: its box now opens down** (it opened up into the old tool row's space). Without a chip it still opens up |
| Pads with ENV (rail, and the panel's keys) | The panel unchanged (pinned to the page's top); the pads beside it moved up as above |
| Sounds panel, alone and beside ENV | The panels unchanged; the pads under them moved up |
| Mix, Mix with ENV | **Identical** below the bar (no shift: Mix had no tool row) |

**Also changed, by the editor's 52 pt at Half:** the step inspector shows its full layout (the note chip, CHORUS and
REVERB lines, "Lock knob turns to step 1") instead of its short one, and the piano roll shows two more rows.

**Not in the comparison:** menus and the waiting outlines (the scripted demo is stopped); the disconnect card (the demo
can't lose its FM-1; it overlays the page's top, so it moves up with it).

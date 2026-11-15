# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (the selected track is the same everywhere)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

The fault (Scott's Pixel, 02:13, build b698317): after a pad was picked, the Pads tab and the editor stayed on that
pad's track. Track heads tapped on the phone and tracks pressed on the FM-1 moved the FM-1, the HOME knobs and the
debug screen, but not the pads' selection or the editor. The pad pick now holds only while its track is still the
selected one.

**Setup:** FM-1 on Skiff 2.5.1 on the Pixel's USB port · this branch merged into the combined one · real core, writes
allowed (`--ez allowWrites true`).

**Back up first: no.** These checks only select tracks and pads.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Tap a pad on track 6. | The FM-1 selects track 6. The pad is selected, and the editor and HOME knobs show track 6. | No | ☐ pass ☐ fail: |
| 2 | Tap track 3's head on the phone. | The FM-1 selects track 3. The Pads tab's selection, the editor and the HOME knobs all move to track 3. | – | ☐ pass ☐ fail: |
| 3 | Tap the pad on track 6 again, then select track 5 on the FM-1 itself. | The phone's selection, editor and HOME knobs all move to track 5. | – | ☐ pass ☐ fail: |
| 4 | Select each track in turn on the FM-1. | The phone follows every time, with no track left behind. | – | ☐ pass ☐ fail: |

**Not covered here:** the read-only case on the device (tested on the Mac: a pick made while read-only gives way to the
FM-1's track too).

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".

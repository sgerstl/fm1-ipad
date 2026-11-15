# Device check: claude/scope-spike-53b5eb, 2026-11-15

Written by the session that built it (see `CLAUDE.md`, rule 2). This branch is a spike (decision 45): it doesn't change any of the app's screens. The checks below look at the spike's demo screen on the iPad and the FM-1. They read only and never write to the FM-1. Verdict: `qa/scope-spike-2026-11-15.md`.

**Setup:** FM-1 on Skiff-Lupe 2.5.1 (screen link 6) · Lupe from this branch, launched from Xcode with the launch arguments below · USB cable.
**Back up first?** No. Nothing here writes the FM-1's flash.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Launch with `-skiffdraw-spike -skiffdraw-page 0 -no-intro`. On the FM-1, press GLO until DELAY (2/5) and turn TIME, FEEDBACK and MIX. | The left of the iPad shows the FM-1's GLO › DELAY screen, the same as the FM-1's own screen pixel for pixel (header aside), with the bars following each turn within a frame or two. | – | ☐ pass ☐ fail: |
| 2 | Theme picker on the right: SKIFF, then HI-CON, then PAPER. Compare with MENU › THEME on the FM-1 set the same. | The picture changes theme as the FM-1's does. Note which theme Scott's FM-1 uses day to day. | – | ☐ pass ☐ fail: |
| 3 | Page picker: EDIT 1 (scope). Select a LOFI or other engine whose EDIT 1 has no chart, theme HI-CON, and play a held note. | A live waveform, steady on a held note, matching the FM-1's (Lupe's trace steps every 2 px). The SCOPE line reads about 25 a second. | – | ☐ pass ☐ fail: |
| 4 | Same, theme SKIFF. | The "sea" of track-coloured columns rising with the tracks' levels, as on the FM-1, though not in step with its swell. | – | ☐ pass ☐ fail: |
| 5 | While the scope shows, turn knobs in Lupe's normal app (relaunch without `-skiffdraw-spike` in another run if needed) and watch the knobs follow. | No lag you can feel compared with the scope off (SCOPE adds about 3 kB/s). | – | ☐ pass ☐ fail: |

**Not covered here:** VoiceOver (the demo is a developer tool), the iPhone layout (checked in the simulator), and Android on a real phone (only the emulator was used; the spike must not be installed on the Pixels).

**After the run:** record the results in the verdict. The branch is a spike: merge or not as decision 45 settles it.

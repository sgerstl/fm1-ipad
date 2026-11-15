# Device check: claude/android-p1-core-link-faf639, 2026-11-15 (clear a pad with Undo; set the step count)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

Two batch-list items, the core's side. P2 draws the Undo strip and the STEPS control, so each check needs P2's
screen.

- **Item 13:** clearing a pad no longer asks. For ten seconds the pad can be put back, pattern and all.
- **Item 9:** the pattern's step count can be set from the Edit tab again.

**Setup:** FM-1 on Skiff 2.5.1, stopped unless a check says otherwise. Pixel on this branch merged into the
combined one, writes allowed.

**Back up first: yes, by the rule, before checks 1–4** (a cleared pad's pattern is erased from the FM-1's flash once
the undo's time is up). Scott, 2026-11-14: "nothing on the FM-1 matters now", so he may skip it.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Pick a pad whose pattern is on no other pad. Clear it. | The pad empties at once with no question, and an Undo strip shows. The FM-1's pad is empty too. | Yes | ☐ pass ☐ fail: |
| 2 | Tap Undo within ten seconds. | The pad is back with the same number, the same notes when you open it, and the same repeat count. | Yes | ☐ pass ☐ fail: |
| 3 | Clear it again and wait more than ten seconds. Then look at SAVE › PATTERNS on the FM-1. | The strip goes, and that pattern number is empty on the FM-1 (not left as an unused pattern). | Yes | ☐ pass ☐ fail: |
| 4 | Press Play, then clear a pad that holds a pattern. | A strip: stop playback to clear a pad that holds a pattern. The pad stays. | – | ☐ pass ☐ fail: |
| 5 | Edit tab, a track with 16 steps: set STEPS to 12. | The FM-1's SEQ › PATTERN shows LENGTH 12 and the pattern loops after 12 steps. The phone shows 12. | – | ☐ pass ☐ fail: |
| 6 | On the FM-1 turn LENGTH (SEQ › PATTERN, KNOB 1) to 8. | The phone's STEPS follows to 8. | – | ☐ pass ☐ fail: |

## Added after Scott's answers on 2ea3f0c: long patterns, and the Timeline's delete

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 7 | Edit tab: set STEPS to 40. Scroll the grid to the third chunk and put a note on step 36. | The grid has three chunks (48 steps, the last eight past the end). The FM-1's NOTES page shows the note on step 36, and it plays there. | – | ☐ pass ☐ fail: |
| 8 | Play that 40-step pattern and watch the phone. | The playhead runs through all three chunks in time, with no stutter. If it stutters, send `adb logcat -s LupeLog \| grep " lag "`. | – | ☐ pass ☐ fail: |
| 9 | Stopped. On the Timeline delete a block in the middle of a track. | It goes at once with no question, the blocks after it move up, and an Undo strip shows. | Yes | ☐ pass ☐ fail: |
| 10 | Tap Undo within ten seconds. | The track is as it was: the block back in its place with its notes. | Yes | ☐ pass ☐ fail: |
| 11 | Delete the last block of a track and wait more than ten seconds. | The strip goes. On the FM-1, SAVE › PATTERNS shows that pattern's number empty. | Yes | ☐ pass ☐ fail: |

**Not covered here:**

- Undo after changing something else on the same track: a pad's clear still comes back on its own; a block's delete is refused with a reason.
- TalkBack: at the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".

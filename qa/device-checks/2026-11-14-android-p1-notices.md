# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (refusals reach the screen)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

On the Pixel, New pattern "did nothing": the FM-1 had refused it and only the log said so. The core now sends every
action it didn't carry out to the screen, with the reason and what to do. P2's strip shows it.

**Setup:** FM-1 on Skiff 2.5.1 with LUPE TEST loaded (all 64 patterns taken). Pixel on this branch merged into the
combined one, with P2's refusal strip.

**Back up first: no for checks 1–4.** Each is an action that is refused, so nothing is written. Check 3 needs writes
allowed; if a pattern number turns out to be free, New pattern will add an empty pattern to track 2's list (in
memory, not saved).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Writes off (the default). Slide any knob on the phone back and forth. | One strip: Lupe is read-only, turn on Allow writes. It doesn't stack up or flicker while you drag. | – | ☐ pass ☐ fail: |
| 2 | Writes on, stopped. On the Timeline hold the last block of a track and pick Chain. | A strip: nothing comes after it to chain into. | – | ☐ pass ☐ fail: |
| 3 | Writes on. If New pattern is still offered, pick it on track 2. | A strip: all 64 patterns are taken. Dismiss it, do it again: it shows again. | – | ☐ pass ☐ fail: |
| 4 | Writes on, playing. Delete a block on the Timeline (confirm if asked). | A strip with the FM-1's reason (stop first), and the block is still there. | – | ☐ pass ☐ fail: |

## Clear unused patterns (needs P2's action and confirm)

Scott said yes to this on 2026-11-14. It sends the FM-1's own CLEAR UNUSED: every kept pattern that no entry in any
track's list or in a saved project names, and that no track is on.

**Back up first: yes, by the rule** (it erases patterns in the FM-1's flash and can't be undone). Scott,
2026-11-14: "nothing on the FM-1 matters now", so he may skip it for LUPE TEST.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 5 | Playing, pick Clear unused patterns and confirm. | A strip: stop playback to clear unused patterns. Nothing is cleared. | – | ☐ pass ☐ fail: |
| 6 | Stopped. Note the numbers the confirm lists, then confirm. | A strip: "Cleared N unused patterns. M pattern numbers are free." On the FM-1, SAVE › PATTERNS shows those numbers empty and every pattern on a pad still there. New pattern works again if M is above 0. | Yes | ☐ pass ☐ fail: |
| 7 | Pick it again. | A strip: no pattern is unused. (Or the action is off.) | – | ☐ pass ☐ fail: |

If check 6 clears few or none on LUPE TEST, the numbers are held by other saved projects: the FM-1 counts those as
used.

**Not covered here:**

- The strip's look and its TalkBack announcement: P2's check.
- Refusals from saving projects and sounds: same path, not run here because they need a save to be attempted.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".

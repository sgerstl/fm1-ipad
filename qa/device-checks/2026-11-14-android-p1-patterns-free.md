# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (how many pattern numbers are free)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

On the FM-1 (project LUPE TEST) New pattern was refused: all 64 pattern numbers were taken. The core now tells the
phone how many numbers are free, and which kept patterns nothing uses, so the hold menu can switch New pattern off
before the tap. P2 draws that, so check 2 needs P2's menu. Nothing new is sent to the FM-1: the numbers come from
the pool the core already reads.

**Setup:** FM-1 on Skiff 2.5.1 with LUPE TEST loaded (pool full). Pixel on this branch merged into the combined one.

**Back up first: no.** Nothing is written.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | On the FM-1 open SAVE › PATTERNS and count the empty numbers and the unused ones (ACTION: CLEAR UNUSED shows its count, don't confirm). Then read the phone's pads area on the debug screen. | `patternsFree` is the FM-1's empty count (0 on LUPE TEST), and `unused` lists as many numbers as CLEAR UNUSED offers. | – | ☐ pass ☐ fail: |
| 2 | Hold a pad or an empty Timeline lane. | With no number free, New pattern (and Duplicate) is off and says why, before the tap. | – | ☐ pass ☐ fail: |

**Not covered here:**

- Clearing the unused patterns from the phone: not built. Scott decides first.
- VoiceOver and TalkBack: at the release pass.

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".

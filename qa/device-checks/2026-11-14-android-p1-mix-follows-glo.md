# Device check: claude/android-p1-core-link-faf639, 2026-11-14 (the Mix section follows the FM-1's GLO page)

Written by the session that built it (see `CLAUDE.md`, rule 2). The main session installs the build and runs it with
the **Pixel 10 Pro** and the FM-1. The branch merges to `main` only after it passes.

The fault: Scott pressed GLO five times on the FM-1 and the phone's Mix section stayed where it was. The core now
switches the section itself when the FM-1's GLO page changes. It sends nothing to do so.

**Setup:** FM-1 on Skiff 2.5.1 on the Pixel's USB port · this branch merged into the combined one, with P2's own
`mixSection` send on GLO changes removed · real core.

**Back up first: no.** These checks only change screens.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Read-only. Open Mix on the phone, then press GLO five times on the FM-1. | The phone's section steps Mixer, Delay, Reverb, Chorus, Global with the FM-1. | No | ☐ pass ☐ fail: |
| 2 | Press GLO quickly, several times in a row. | The FM-1 never jumps back a page, and the phone ends on the page the FM-1 shows. | – | ☐ pass ☐ fail: |
| 3 | Allow writes. Pick Chorus on the phone. | The FM-1 goes to GLO › CHORUS. | – | ☐ pass ☐ fail: |
| 4 | Press HOME on the FM-1, then GLO. | The phone's section goes to Mixer, the page GLO lands on. | – | ☐ pass ☐ fail: |

**After the run:** failures go on the batch list with the check number. Passes move their batch items to "On the
device".

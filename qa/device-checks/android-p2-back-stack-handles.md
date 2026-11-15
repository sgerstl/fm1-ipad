# Android P2: back goes home, the sound-page stack, picture handles (2026-11-13)

Built (Kotlin tests pass, APK builds); **not run on a screen**. Decisions 19, 20, 22 in `phone-skiff-decisions-2026-11-12.md`. The `goHome` intent is mine until P1's merge (the fake answers it by switching back to the steps); the real FM-1 needs P1's SCREEN_GOTO 127 side. Nothing here writes the FM-1's flash: no backup needed.

## Back gesture (19)

| # | Do | See |
|---|----|-----|
| 1 | Press an FM-1 sound key (ENV). Swipe back from the left edge, then the right edge | The FM-1 goes HOME and the steps come back, both times. Predictive back shows the preview first |
| 2 | On the steps (no sound page), swipe back | The app leaves as usual: the handler is only on while a sound page shows |
| 3 | On a sound page with Slide-to-turn on Sideways, slide a knob to the screen's edge | Known cost: the edge is not excluded from back there, so a slide that ends past the edge can go home. Tell me if it happens in daily use |
| 4 | Open the Sounds browser from a sound page, swipe back | The browser closes (not HOME) |

## One flexible page (decision 20c), replacing the stack prototype

The Labs stack (switch "Sound pages push up from below", the free scroll and the two-position flip) is **removed**; this section supersedes the earlier rows 5-10b. Built, not run on a screen.

When a sound page shows (a sound key on the FM-1, or the phone's own page picks), the bottom half keeps the ruler and the **step grid**, hides the dials row (HOME knobs or the step's controls), and the family keys, page row and sound page take the room under the grid. The grid glides smaller and the dials row fades out as the sound section fades in (0.3 s, nothing pops; with Remove animations they cross-fade in place).

What shows at each divider position on a 412 × 915 dp phone (body about 793 dp tall; the Pixel 7's 1080 × 2400 is 411 × 914 dp, so the same numbers):

| Divider | Bottom half | Grid | Sound page |
|---|---|---|---|
| Top only | hidden; a sound page glides the divider to split (decision 13) and HOME glides it back unless you moved it | | |
| Split | about 420 dp | rows squeezed to 36 dp (156 dp in all), number and note on one line | family keys, page row and the four controls; the picture is about 0 to 10 dp: it goes first |
| Bottom full | about 729 dp | rows 72 dp (300 dp) | family keys, page row, a picture of about 170 dp, the four controls. The automation lane is for the editor only, so it leaves while a sound page is up and returns on HOME |

| # | Do | See |
|---|----|-----|
| 5 | Press ENV on the FM-1 (split) | The dials row fades out, the grid compresses to 36 dp rows, the family keys, page row and controls fill the space under it. The ruler stays above the grid |
| 6 | Drag the divider to bottom full, then top only | Bottom full: roomy grid and a real picture. Top only: nothing of the bottom half; with a sound page showing, the divider glides to split at once |
| 7 | Press HOME on the FM-1 (or swipe back) | The sound section fades out, the grid grows back, the dials row (HOME knobs, or the step's controls if you picked one while the page was up... see below) fades in |
| 8 | With a sound page up, tap a step | It gets the white ring in the grid, the sound page stays up, the dials do not come back. Hold it and turn a knob to lock |
| 9 | Change pages (FM-1 or phone) | The section changes within itself; a picked step stays picked |
| 10 | Bottom full on the editor with an automation lane, then ENV, then HOME | The lane leaves with the dials row and returns on HOME |

### What is selected and when (decisions I had to make)

- Opening a sound page clears the picked step, so HOME shows the HOME knobs. Without this, a step picked earlier would hide them.
- A step tapped while a sound page is up is picked and stays picked through page changes inside the sound section. HOME clears it (the dials row returns as the HOME knobs), so a step you picked for a lock is not carried back.
- The grid's selection ring is the phone's pick, not the FM-1's cursor.
- The Step ⋯ menu is greyed while no step is picked, as before.
- Open: should HOME keep the pick rather than clear it? A latched Lock while a sound page is up keeps its banner in the ruler. A pattern change while a sound page is up changes the grid under it. Whether a squeezed 36 dp grid is too small to hit on a phone: it is above the 24 dp floor but under 44.
- At split with the "held" notice showing, the controls row can lose a few dp at the bottom: the picture is already gone.

## Picture handles (22): removed

Superseded by decision 25 (the phone no longer draws the FM-1's pictures, so there are no handles). Rows 11-16 are gone. The dials below the sound page's header are the way in; see `android-p2-button-block.md`.

## Pause and Pin only hold against the FM-1 (2026-11-13)

Built (tests in `FollowModelTest`), not run on a screen.

| # | Do | See |
|---|----|-----|
| 17 | Labs › Pause following on. Tap SEL, then FX on the phone's family row | Each page shows at once; no "held here" line, however fast you tap |
| 18 | Same, tap a page in the page row, a MOD route, a tile, then swipe back | All apply at once |
| 19 | Pause on: touch the bottom half, then press SEL on the FM-1 within 3 s | The page stays; a grey line "The FM-1 is on SEL · held here" fades in under the page row, never over the family keys; after 3 s the page catches up and the line fades |
| 20 | Pin on: press ENV, then LFO on the FM-1 | Held with the line. Tapping a family key on the phone still switches |

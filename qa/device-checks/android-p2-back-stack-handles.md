# Android P2: back goes home, the sound-page stack, picture handles (2026-11-13)

Built (Kotlin tests pass, APK builds); **not run on a screen**. Decisions 19, 20, 22 in `phone-skiff-decisions-2026-11-12.md`. The `goHome` intent is mine until P1's merge (the fake answers it by switching back to the steps); the real FM-1 needs P1's SCREEN_GOTO 127 side. Nothing here writes the FM-1's flash: no backup needed.

## Back gesture (19)

| # | Do | See |
|---|----|-----|
| 1 | Press an FM-1 sound key (ENV). Swipe back from the left edge, then the right edge | The FM-1 goes HOME and the steps come back, both times. Predictive back shows the preview first |
| 2 | On the steps (no sound page), swipe back | The app leaves as usual: the handler is only on while a sound page shows |
| 3 | On a sound page with Slide-to-turn on Sideways, slide a knob to the screen's edge | Known cost: the edge is not excluded from back there, so a slide that ends past the edge can go home. Tell me if it happens in daily use |
| 4 | Open the Sounds browser from a sound page, swipe back | The browser closes (not HOME) |

## The stack (20): Settings › Labs › Sound pages push up from below

Off by default; off is today's layout, unchanged.

| # | Do | See |
|---|----|-----|
| 5 | Switch it on. Press ENV on the FM-1 | The tabs, steps and ENV page are one column; it scrolls up so ENV sits where the bottom half was, with the foot of the steps just above it. No divider |
| 6 | Flick up and down starting on a knob, then on the graph, then on the page row | All of them scroll the column |
| 7 | Rest a finger on a knob for a moment, then slide | The knob turns (the Magnifier shows), the column stays still. About 0.16 s is the rest (a Labs candidate) |
| 8 | Swipe back | The column scrolls back down while the FM-1 goes HOME |
| 9 | Switch the Timeline tab on and press a sound key | The Timeline is the first block of the column |
| 10 | Switch it off | Today's divider layout is back, nothing else changed |

## Picture handles (22)

On ENV, the FX sends page, and EDIT 1's picture (ANALOG engine).

| # | Do | See |
|---|----|-----|
| 11 | ENV: slide each of the four handles (attack peak, decay corner, a sustain handle on the held line, release end) | Each turns the control of that name below it, with the same direction, step and Magnifier as the knob. The old drag-to-position is gone |
| 12 | Double tap a handle | Back to where the page opened, as the knob |
| 13 | FX sends: slide a bar | That send's control turns; the bar follows |
| 14 | EDIT 1: slide the cutoff line's handle and the peak's handle | CUTOFF and RES turn |
| 15 | Turn TalkBack on and swipe through a handle | It reads as the control (name, value, increase and decrease) |
| 16 | LFO, DRIVE, ARP, SCALE pictures | Still decoration: no handle |

Known edges: handles are 44 dp targets (the 48 dp knobs below are the roomier way in); two handles can sit close on a very short decay.

# Android P2: HOME's four sound knobs under the grid (board 70, decision 21), 2026-11-13

Built (Kotlin tests pass, APK builds); **not run on a screen**, and not against the real core: the data is the fake's ANALOG set (CUTOFF 84, RES 40, ATTACK 12, RELEASE 64) behind a **provisional** `homeKnobs` area and `setHomeKnob` intent. P1's real shapes replace them. Nothing here writes the FM-1's flash: no backup needed.

| # | Do | See |
|---|----|-----|
| 1 | Open the app on the editor (Pads tab, a pattern chosen) with no step tapped | The strip under the grid reads "Sound ANALOG · the FM-1's four knobs" over four round knobs, value in the ring, label under. No step has a white ring. The grid is the same size as when a step is picked |
| 2 | Tap step 6 | The strip becomes "Step 6 ✕", ‹ ›, NOTES · FEEL · SOUND, Lock. Step 6 has the white ring |
| 3 | Tap ✕. Then pick a step and tap that step again | Both bring the four knobs back and the white ring goes |
| 4 | With a step picked, press a sound key (ENV) on the FM-1, then HOME | After the sound page, the editor comes back with the knobs, not the step |
| 5 | With the knobs showing, slide CUTOFF (the setting's direction) | The value changes in the ring, the Magnifier floats above the finger, the ring is white while the finger is down |
| 6 | Double tap a knob after changing it | Back to the value it had when the strip appeared |
| 7 | Turn the FM-1's knob 1 on HOME | CUTOFF lights white and its value follows; the white fades about 0.6 s after the last turn *(needs P1's area; the fake only does this from a test)* |
| 8 | Switch another track on the FM-1 (a DRUM track) | The header and the four labels are that engine's (DRUM puts MORPH on knob 1) *(needs P1's area)* |
| 9 | TalkBack: swipe to a knob | It reads name and value with a range, and Increase, Decrease, Put back |
| 10 | Labs › Sound pages push up from below on: press a sound key | The editor in the stack shows the knobs, not a picked step, and the stack scrolls as before |

## Choices to check

- **The Step ⋯ key** (the ruler's step menu) is greyed while no step is picked, with "Pick a step first" for TalkBack. The board draws it live, but it would copy, paste or clear a step nobody can see.
- **Open question for Scott: does a step stay picked when the pattern changes?** I kept it (the default asked for): picking a new pad leaves the strip as it was. If the knobs should come back on a pattern change, it is one line.
- Holding a step (the lock gesture) picks it, so the lock banner and the step's controls appear as before.
- Pre-flight (design-standards) ran on the strip: tokens only (no new colours), 12 sp labels on well/page, rings 60 dp with an 84 × 88 dp target (over the 48 dp bar), Reduce Motion respected through the existing lit animation. `check-tells.sh` scans web sources only and found nothing to scan here, so that is not a pass; contrast comes from the existing text and track tokens, not newly computed; no rendered check was possible.

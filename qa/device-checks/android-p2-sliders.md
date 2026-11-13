# Device check: android-p2-sliders (claude/android-p2-shell-02c86f), 2026-11-14

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel 10 Pro; the branch merges to `main` only after it passes.

**What this is:** decision 10 (Scott, 2026-11-13): values slide on the control itself, no − / + steppers anywhere on the phone, with the Magnifier (a bigger copy of the value floats above the finger) and the iPad's "Slide to turn" setting (Sideways / Up and down / Both). It touches the **step panel** (NOTES: PITCH, MOVE, LENGTH, VELOCITY; FEEL: CHANCE, RATCHET, COND, NUDGE) and the **sound pages' four controls**.
**Setup:** the Pixel on USB or Wi-Fi adb; `./gradlew :app:installDebug` from `android/`. The phone has no Settings screen yet (P5), so the two settings are flipped, and kept, by launch extras:

```bash
adb shell am start -n com.scottgerstl.lupe/.MainActivity --es slide updown --ez magnifier true
```

`--es slide sideways|updown|both` and `--ez magnifier true|false`. Default (nothing passed, nothing kept): **up and down, Magnifier on**. For the sound pages with the FM-1 plugged in, open one with the FM-1's ENV / LFO / FX button. For the step panel without an FM-1 add `--es scenario ready` (the fake: Piano's pattern 12).
**Back up first?** No on the fake. **Yes on the real FM-1** for checks 8–9: sliding a sound-page control writes the sound's value to the FM-1's RAM (not flash), and a Save would write it; don't Save. Take a project backup from the iPad first if you like.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open the editor (fake, `--es scenario ready`). Look at the step panel, NOTES, then FEEL. | No − or + keys anywhere. Four columns across (label, value, a thin gauge along the foot, like the iPad's), each at least 84 dp tall. | – | ☐ pass ☐ fail: |
| 2 | Slide VELOCITY up and down (default: up and down). | Up raises, down lowers; the value changes under the finger and the gauge follows; a white bar shows along the column's top while it slides. A sideways drag on it does nothing. | – | ☐ pass ☐ fail: |
| 3 | While you slide, look above your finger. | The **Magnifier**: a bigger plate with the label (VELOCITY) and the value in large digits, floating above the finger and following it, never under your hand. It grows out of the finger when you start (200 ms) and shrinks back when you let go. | – | ☐ pass ☐ fail: |
| 4 | Slide a column near the top edge of the screen and near the right edge. | The Magnifier stays on screen (clamped 12 dp from the edges). | – | ☐ pass ☐ fail: |
| 5 | Slide MOVE, RATCHET and COND slowly. | A tick (haptic) on **each step** through the list: MOVE swaps the step with its neighbour and the selection follows; RATCHET 1–4; COND steps through its conditions. | – | ☐ pass ☐ fail: |
| 6 | Slide LENGTH or PITCH, then double-tap that column. | It goes back to what it was when you selected this step (with a confirming haptic). Select another step: its own start is remembered fresh. | – | ☐ pass ☐ fail: |
| 7 | Relaunch with `--es slide sideways`, then `--es slide both`. Try a sideways and an up-and-down drag on a column each time. | Sideways: only a sideways drag turns it (right raises). Both: whichever way the finger first moves for that drag decides it, up or right raises. The setting is kept after you close the app. | – | ☐ pass ☐ fail: |
| 8 | Relaunch with `--ez magnifier false` and slide any column. | No Magnifier; sliding works as before. Relaunch with `--ez magnifier true`: it's back. | – | ☐ pass ☐ fail: |
| 9 | **With the FM-1 plugged in:** open a sound page (ENV). Slide one of the four controls; double-tap it. | Its ring and number follow the slide; the Magnifier shows a ring, the label and the value above the finger; the FM-1's screen shows the same value; double tap puts it back to what it was when the page opened. No − / + appears on a tap, and the row is shorter (the 48 dp strip is gone). | Value in RAM only; don't Save | ☐ pass ☐ fail: |
| 10 | On a page, turn the FM-1's knob while your finger isn't on the screen. | The control lights as before (the FM-1's knob still lights its control 600 ms), and nothing the slide did is lost. | – | ☐ pass ☐ fail: |
| 11 | TalkBack on: swipe to a step-panel column; swipe up/down to adjust; open the actions menu. | It reads "Velocity, 100, range 1 to 127"; Increase / Decrease and "Put … back as it was" are in the actions; the Magnifier is never read. On a sound-page control: the same, with its range. | – | ☐ pass ☐ fail: |
| 12 | Remove animations on (Settings › Accessibility), repeat 3. | The Magnifier fades in and out, doesn't grow or travel in; sliding itself is unchanged. | – | ☐ pass ☐ fail: |

**Calls I made without Scott:**
- **Default on the phone is up and down** (the task said so); Magnifier on.
- **Stored in SharedPreferences** (`lupe_settings`: `slide_direction`, `magnifier`), set by `--es slide` / `--ez magnifier` launch extras until P5's Settings.
- **Sliding distances** (dp per step; Labs candidates, CLAUDE.md rule 3): PITCH 16, MOVE 22, LENGTH 16, VELOCITY 3, CHANCE 4, RATCHET 28, COND 26, NUDGE 12; sound pages as before (2 dp for 0–127, 6 for up to 64, 20 for lists). Say if any feels too fast or slow.
- **Step-panel values send changes in steps** (`StepAdjust(field, steps)` as before), never absolute values; the double tap sends the negative of the steps since the step was selected. The fake multiplies VELOCITY and CHANCE steps (4 and 5 units); the real core's units are P1's.
- **No sound-page tap-to-arm:** a tap does nothing now (it armed − / +). Double tap still reverts.

**Not covered:** whether a vertical drag on a column fights the sound page's own scroll (the pages don't scroll today), the Magnifier at 200 % text, and anything with the real FM-1 beyond 9–10 (P1's hardware tests).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device" (TalkBack: release pass).

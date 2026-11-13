# Device check: android-p3-pads-editor (claude/android-p2-shell-02c86f), 2026-11-13

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel 10 Pro; the branch merges to `main` only after it passes.

**What this is:** the Pads tab and the editor on the **fake core** (`FakeLupeCore`, provisional fixtures from board 53). Nothing here talks to the FM-1: the "FM-1's keys" and "knob turns" in the checks come from the FM-1 menu's **Fake core** section. The shell's checks (1–10 of `android-p2-shell.md`) passed on 2026-11-13; 11–13 there are still open and also cover this work.
**Setup:** Pixel on USB or Wi-Fi adb. Build and install from the worktree:

```bash
cd ~/code/fm1-ipad/.claude/worktrees/android-p2-shell-02c86f/android && ./gradlew :app:installDebug
```

Start straight on the drum kit with `adb shell am start -n com.scottgerstl.lupe/.MainActivity --es scenario drums`. The default is "ready": the demo project, Piano's pattern 12 in the editor.
**Back up first?** No. Nothing writes to the FM-1.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open Lupe and look at the Pads tab at split. Compare with board 53 (`design/boards/phone-portrait/board-53.png`). | Six rows, each with its number, M, and pads. A05 and B03, B11, B04, B12 filled in the track colour with a pass bar; A09 (muted) outlined, M lit; C14 dashed with "bar 11"; B12 has a white ring (selected). Fifth column peeks at the right edge. Store, scenes 1–7 (3 lifted, 5–7 dim), Select. The editor below shows "5 Piano · B · pattern 12 · C min" and the 4×4 grid, step 6 ringed. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 2 | Slide the pads sideways. Drag the divider to top only and back. | All six rows pan together. At top only the rows grow tall (about 110 dp) and the pads' words stay put; at split they are 40 dp. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 3 | Tap Play. Tap a pad that isn't playing (say C03 on track 2). | Play fills; the readout counts. The tapped pad goes dashed with "bar N" (the next bar), the Launch key shows "N waiting". At the bar it fills and the old pad on that row empties, all fading, none popping. Tap a dashed pad: the launch is taken back. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 4 | Stop. Tap a pad. | It takes over at once. A tap on an empty pad does nothing. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 5 | Tap M on a row, then M again. | The row's playing pad turns from filled to outlined; M lights white; back again. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 6 | Hold a pad with a pattern. | A menu opens beside your finger (to its right, or its left when there's no room): Edit steps, Select sound, Set pattern…, Clear. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 7 | In that menu choose Edit steps on another track's pad (e.g. 4 Drum Kit, A 01). | The editor changes to "4 Drum Kit · A · pattern 01", drum lanes in each step ("BD CH"), no Chord key, LANE instead of PITCH. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 8 | Hold an empty pad: New pattern. Hold a pad: Set pattern…. | New puts the next pattern number there and the empty column slides on. Set lists **only the patterns the FM-1 holds** ("Pattern 05" …, the pad's own ticked), one tap sets it; there is no − / + and no empty number to pick (Skiff refuses those). | – | ☐ pass ☐ fail: |
| 9 | Hold a pattern pad that **no other pad shares** (say T4 A 01): Clear. Wait a moment, then tap the red-outlined row. Try Clear again and tap Cancel. Then hold a pad whose pattern another pad also uses (T5 A 12 and B 12 if both are pattern 12): Clear. | Unshared: a red-outlined row says "Clear entry A on T4 Drum Kit. Pattern 01 is used nowhere else, so it's erased; can't be undone", Cancel below; a tap in the first 0.4 s does nothing. Shared: the Clear row says "Pattern 12 stays: T5 B uses it", and one tap clears the entry at once, no asking (nothing is lost). | – | ☐ pass ☐ fail: |
| 10 | Turn Select on (it lights). Tap a pad. Turn it off. | With Select on a tap picks the pad for the editor (ring) and nothing launches; off, a tap launches again. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 11 | Tap Store (it lights), then an **empty** scene (say 6). Tap Store again, then a **kept** scene (say 1). Wait a moment, then tap the red row. Repeat and tap Cancel. Tap an empty scene (7) with Store off. | The empty scene stores at once (it turns from dim to a stored look). The kept scene doesn't: a red-outlined row appears over the scenes, "Replace scene 1 with what plays now", Cancel beside it; a tap in the first 0.4 s does nothing, after that it stores and the row fades. Cancel leaves the scene as it was. Tapping scene 7 with Store off shows the "Scene 7 is empty…" strip with ✕. Tapping a kept scene relaunches what it holds. (Scott, 2026-11-14: Store over a kept scene confirms in place; the core refuses an unconfirmed store.) | – | ☐ pass ☐ fail: |
| 12 | In the editor, tap a step, then hold one for about half a second and turn nothing. | Tap rings the step (the panel says "Step N"). Holding lifts the step and the ruler blends into "Locking knob turns to step N / let go to stop". Letting go brings the ruler back. | – | ☑ pass: Scott, 2026-11-13 |
| 13 | Latch Lock (the Lock key in the step panel), then open the FM-1 key (top left, shows the project name) › Fake core › "FM-1 knob 1 up" twice. (Holding a step while opening a menu isn't possible with one hand, so latching stands in for it.) | A ◆ appears on the selected step; the SOUND tab lists "CUTOFF n locked on this step" with its own ✕, the value 4 higher per turn. With Lock off, a knob turn does nothing to the step. | – | ☑ pass: Scott, 2026-11-13 (after the sheet was corrected: the fake knob is in the FM-1 key's menu, not "Demo ⌄"; a lock is a white ◆, not a red dot) |
| 14 | Open the SOUND tab on step 6 (ready scenario). ✕ on DECAY. Then Clear all. Wait, tap the red row. | DECAY goes; CUTOFF stays. Clear all asks in place ("Clear the lock on step 6 (CUTOFF)"), Cancel under it; after 0.4 s the tap clears, the ◆ leaves the step, RESONANCE (recorded, —) stays. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 15 | Tap Lock in the panel (NOTES tab). Select another step. | Lock lights (◆ filled) and the banner says "tap Lock to stop". It stays latched across steps until you tap Lock again. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 16 | NOTES: use − and + on PITCH, MOVE, LENGTH, VELOCITY. FEEL: CHANCE, RATCHET, COND, NUDGE. | Values and the cell change; MOVE swaps the step with its neighbour and the selection follows; the cell's note and length bar update. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 16b | In the editor, select a step with a note and another note a few steps on (the fake's Piano pattern 12: step 1, next note on step 3). On NOTES, slide LENGTH up. | It grows to the limit and stops there with a tick; the column says "next note at step 3" (or "pattern ends here"); sliding back at once shrinks it, with no dead stretch to unwind. | – | ☐ pass ☐ fail: |
| 17 | Chord on. the FM-1 key (top left, shows the project name) › Fake core › "FM-1 key C4" (on a step that already has a note). Chord off, key again. | With Chord on a second key adds to the step ("+1"); off, it replaces and the cursor moves to the next step. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 18 | Step ⋯ › Copy, select another step, Step ⋯ › Paste. Then Step ⋯ › Clear step. | Pasted; Clear asks in place, naming the note and its locks. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 19 | Drag the divider to bottom full. | Tabs fade into a strip with the selected track's pads (40 dp); the grid gets taller cells; one automation lane (CUTOFF ⌄) appears under it with ◆ on locked steps; the step panel stays at the bottom. The lane picker lists the lanes. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 20 | Play with the editor showing. | The playhead (a coloured inset outline) walks the 16 steps at the tempo; the pads' pass bars grow. | – | ☑ pass: Scott, 2026-11-13 on the Pixel |
| 21 | TalkBack on: swipe through a pad, a step and the step panel; try the actions menu on a pad and a step. | Pads read "Pad: Acid, entry A, pattern 5, playing"; steps read "Step 6, C5 plus 1, has a lock, selected"; the pad actions menu has Edit steps / Select sound / New / Clear; steps have "Lock knob turns to this step". | – | ⏭ deferred to the release pass (Scott, 2026-11-13) |
| 22 | Remove animations on (Settings › Accessibility), repeat 3, 12 and 19. | Nothing slides or grows; the pad states, the lock banner and the divider cross-fade. | – | ⏭ deferred to the release pass (Scott, 2026-11-13) |

**Calls I made without Scott (for him to change or keep):**
- **Store** is a toggle: tap it, then a scene. Over a kept scene it asks first, in place, as Clear does (Scott, 2026-11-14).
- An **empty scene** is refused on the phone, with a strip, rather than asking the FM-1.
- **Steppers** (−/+) change the step's own values. Only knob turns (from the FM-1, or the phone's sound-page knobs in P4) lock a value to a step, so with the fake there is no on-phone way to lock without the FM-1 menu's "FM-1 knob" keys.
- Tapping the pad that is already **playing** does nothing in the fake. What a re-tap means (restart? queue?) is the real core's rule, not guessed here.
- The scenes row scrolls inside the board's 268 dp (seven visible); Store and Select are fixed at its ends.
- Step cells use the step's velocity for the fill (18–44 % of the track colour), as the board.
- Targets: the pads and step cells are far above 48 dp; scenes (34), Mute (28 wide), steppers (36 tall), the step panel's tabs and keys (28–32) are under the 48 aim but over the 24 floor, as the iPhone's. Each has a TalkBack way in.
- Colours: `Tok.track` is the boards' six track colours, since `tokens.json` has four. Add the six to the tokens, then read them from there.

**Not covered here:** the real FM-1 (P1's `BridgedLupeCore` and recorded fixtures come at its gate 5), the Pads' launch timing against real clock, Timeline and Mix (P5, P6), sound pages in the bottom half (P4), and the long-press feel (it uses Android's 400 ms; if it feels slow or fast, say so: Labs).

**Found on the run (2026-11-13):** at top only there is no reliable way back to the editor. The divider handle sits on the last 16 dp, right above Android's gesture bar; its 48 dp touch band is centred on it, so the lower half lies in the system's bottom gesture zone and an upward drag there is taken by Android. Nothing on screen says the editor is below either. Fix: keep a visible strip at top only ("Editor ⌃", tap to go to split), and keep the handle's touch band above the gesture zone (`WindowInsets.systemGestures`).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device" (TalkBack: release pass).

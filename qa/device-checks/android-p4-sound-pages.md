# Device check: android-p4-sound-pages (claude/android-p4-sound-pages-7e2a23), 2026-11-13

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel 10 Pro; the branch merges to `main` only after it passes. **Built overnight on Claude's recommended answers to the five open questions in `design/phone-sound-pages.md`, so every call below is provisional: anything you overrule gets reworked.**

**Setup:** no FM-1 needed for checks 1–11. The sound pages run on the fake core (`FakeLupeCore`) replaying provisional fixtures `android/fixtures/state/page-*.json`. Check 12 needs the real core (P1), which isn't wired to the `page` area yet. Build and install with the Pixel connected over USB (USB debugging on). Note the app's package is shared with P2/P3's build, so installing replaces theirs.

```bash
cd ~/code/fm1-ipad/.claude/worktrees/android-p4-sound-pages-7e2a23/android && ./gradlew :app:installDebug
```

Open a page straight away with `adb shell am start -n com.scottgerstl.lupe/.MainActivity --es scenario page-env`. The scenarios: `page-env`, `page-env-lock`, `page-lfo`, `page-edit1`, `page-drive`, `page-mod`, `page-scale`, `page-lanes`, `page-operator`, `page-arp`. Inside the app, the family row and page row switch pages (pages the fixtures don't carry come up with empty wells and no graph). `Demo ⌄` still has the old "Bottom: …" fake-core rows.
**Back up first?** No. Nothing here talks to the FM-1.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Launch `page-env`. Compare with board 55 (`design/boards/phone-portrait/board-55.png`). | Bottom half: family row (ENV lit in the track's pink), page row ENV · ENV 2 with ENV underlined, "5 Piano" in the graph's corner, the ADSR in pink with three square handles, four rings: ATTACK 12, DECAY 48, SUSTAIN 64, RELEASE 90. Controls sit at the bottom of the half. | – | ☐ pass ☐ fail: |
| 2 | On ENV, drag DECAY up and down with a finger (one finger on the ring or its number). Then tap ATTACK once, tap − and +. Then double-tap DECAY. | Drag: the ring and the number follow, about 2 dp a step, a tick at 0 and at 127. Tap: − and + appear under the value (they go after about 3.5 s). − / + move one step. Double tap puts the value back to what it was when the page opened (48). The graph follows every change. | – | ☐ pass ☐ fail: |
| 3 | Drag the three square handles on the ADSR. | Peak: ATTACK. Decay's end: DECAY and SUSTAIN. Release start: RELEASE and SUSTAIN. Only a drag that starts at a handle moves it; a drag elsewhere on the graph does nothing. | – | ☐ pass ☐ fail: |
| 4 | Tap the FX key, then DRIVE. Compare with board 59 right (`design/boards/phone-portrait-2/board-59.png`). Open `page-edit1` and compare with board 59 left. | Page row FX · DRIVE · INSERT · INSERT 2 · SLICER · DUCK scrolls sideways with a fade at the cut edge, and DRIVE stays in view. DRIVE: the curve and "TUBE" large, "drive 72 · tone 40" under it, knob 4 an empty well. TYPE shows a name, "TUBE". EDIT 1: the oscillator and filter pictures, WAVE shows SAW. | – | ☐ pass ☐ fail: |
| 5 | Launch `page-mod` and tap a few route tiles. Compare with board 60. | Eleven route tiles in three rows (LFO →, ENV →, SLOTS), each with an amount bar; the picked tile is tinted with a white outline. Knob 1 is the ring-less "ROUTE" with the route's name. (The fake doesn't update SRC, DEST or AMT when you pick; that is the real core's job.) | – | ☐ pass ☐ fail: |
| 6 | Launch `page-lanes`; tap a lane tile. Launch `page-operator`. Compare with board 62. | LANES: eight lane tiles 4 × 2, the picked one in the track's purple, knob 1 "LANE · SNARE" ring-less; the EDIT page row scrolls. OPERATOR: the card "OP 2 · RATIO" with the line that it's edited on the FM-1, four empty wells. | – | ☐ pass ☐ fail: |
| 7 | Launch `page-scale` and `page-arp`. Compare with boards 61 left and 63 left. | SCALE: a keyboard octave, C minor's notes lit, the root marked ●, "C minor · ● root" top right. ARP: the 16-step pattern in pink, "UP · 2 oct · 1/16 · gate 60%". | – | ☐ pass ☐ fail: |
| 8 | Launch `page-env-lock`. Compare with board 61 right. | The page row is replaced by a plum banner "◆ Locking to step 6 · held on the FM-1"; DECAY has a ◆ beside its label. | – | ☐ pass ☐ fail: |
| 9 | On `page-env`, drag the divider to bottom full and back to split. | At bottom full the graph takes all the extra height; the four controls stay at the same place on screen. Compare with board 63 left. | – | ☐ pass ☐ fail: |
| 10 | Launch the plain app, drag the divider to top only, then use `Demo ⌄ → Bottom: ENV page`. Then `Bottom: editor`. | The divider glides to split when the page opens (so it never hides what the FM-1 opened) and back to top only on `Bottom: editor`. If you move the divider yourself in between, it doesn't go back on its own. | – | ☐ pass ☐ fail: |
| 11 | The FM-1's knob lighting a control: nothing in the app triggers it yet (the fake has `fm1PageKnob(slot)`, no menu row). Skip until P1's core reports knob turns. | The turned control lights white, its value grows to 30, and it fades back over 600 ms after the last turn. | – | ☐ skip ☐ pass ☐ fail: |
| 12 | Turn on TalkBack. Swipe through the four controls; on one, swipe up/down to change it; open the actions menu. | Each control reads its label, then its value ("DECAY, 48"); up/down changes it; the actions offer Increase, Decrease and "Put … back to 48". An empty well is skipped. Page row keys read "ENV 2 page, tab". The lock banner is announced when it appears. | – | ☐ pass ☐ fail: |
| 13 | Turn on Remove animations and relaunch `page-env`. Change pages, open a lock. | The page row doesn't glide (it jumps to the page), the control's lit growth doesn't scale (it only changes colour), the LFO's dot stands still, and the page and banner cross-fade. | – | ☐ pass ☐ fail: |
| 14 | With the real FM-1 (P1's build, once it emits `page`): press ENV, then LFO, then FX on the FM-1. | The bottom half follows each. Until P1 records the area there is nothing to see here. | – | ☐ not yet |

**Provisional calls (all from the map's "Open questions" unless noted):**

1. The page row scrolls (FX, and EDIT on a drum track); it keeps the current page in view and fades at a cut edge.
2. A value changes by vertical drag (about 2 dp a step for a range of 64 or more, 6 dp for 16–63, 20 dp for fewer: my numbers, a Labs candidate), tap for − / + (they hide after 3.5 s), double tap to the page-open value. The page-open value is remembered by Compose per (track, page, knob), not by the core.
3. INSERT and INSERT 2 stay two pages.
4. Dense pages (OPERATOR, ALL OPS, SLICES, SOUND) are a named card with the FM-1's cursor ("OP 2 · RATIO"); no pictures.
5. The divider glides to split when the FM-1 opens a sound page at top only, and back when it returns to SEQ (unless moved). Done in Compose (`FollowFm1Divider`); the real core could do it instead.
6. Mine, not in the map: the lit fade is 600 ms starting at the last turn, 80 ms to come on (Labs candidate); the value grows to 30 by scaling 1.25×, not by changing the font size.
7. Mine: the graph panel takes the remaining height, the controls are fixed size and bottom-aligned (at split the graph is about 160 dp, a bit taller than the map's 140); there is a 48 dp strip under the values for − / + even when they're hidden, so the controls don't move when you tap.
8. Mine: the lock banner replaces the page row in place; "Not lockable" and "Keys: SCALE" use the same banner (text from the core).
9. Mine: DRIVE draws the curve and the type's name (board 59), not the iPad's output wave (the port of `driveWave` is in the file, unused).
10. Mine: the LFO graph draws two seconds of the wave at the real rate with a sweeping dot (stopped with Reduce Motion); the iPad's live restart clock and FADE aren't ported.
11. Mine: MOD's route tiles are 40-ish dp tall (under the 48 dp target; above 24 dp, WCAG 2.5.8).
12. Mine: tapping a family key sends `pickPage(family)` with no page (the FM-1's first, or its last used: the core decides).
13. TalkBack: controls expose a range (`ProgressBarRangeInfo` + `setProgress`) plus Increase / Decrease / Put back custom actions. Not listened to, only written.
14. The fixtures are hand-written to the map (not recorded from FakeSkiff), so their values, e.g. the LFO's "3.4 Hz", are mine.

**TODO graphs (pages show the panel without one):** CHORD, FOLLOW, DELAY, REVERB (Skiff 2.5), INSERT, INSERT 2, SLICER, DUCK, VOICE, the scope for engines other than ANALOG.

**Checked on the emulator by me (screenshots against the boards, 2026-11-13):** pages ENV, ENV with the lock banner, LFO, MOD, DRIVE, EDIT 1 (ANALOG), LANES, OPERATOR, SCALE and ARP drew as the boards; a vertical drag on DECAY moved 48 → 58 with the ring; a tap showed − / +. **Not checked on the emulator** (it was slow, shared with other sessions, and died once): tapping the family and page keys, the divider glide at top only, Reduce Motion, the 600 ms lit fade, the ADSR handle drag, TalkBack, and bottom full. The unit tests (`FakePagesTest`, `FixturesTest`) cover the fake's answers and the fixtures' decoding, not the screens.

**Not covered here** (needs the Pixel, the FM-1, TalkBack or P1): animation hitches (the emulator was slow and shared); the feel of the drag (the 2 dp step); the real `page` area from the core (the shapes in `core/PageState.kt` are mine, P1 has been told); font scales above 130%; keyboard focus order; contrast of the plum banner and the dim wells (computed? no: not yet measured).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

# Device check: android-p6-timeline-automation (claude/android-p2-shell-02c86f), 2026-11-14

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel 10 Pro; the branch merges to `main` only after it passes.

**What this is:** P6's screens: the Timeline tab (board 58 and board 68, time running down, decision 6) and the automation lane drawn full size (board 69, decisions 7, 10 and 16). They read P1's `timeline` and `automation` areas (100a607) and send its intents (BlockMove, BlockStretch, BlockDelete, BlockSetPattern, BlockDuplicate, AutomationLanePick, DrawLane). **On the real FM-1 these write**: reordering, stretching, deleting or setting a block changes the song's entry list (flash), and a drawn lane writes MOTION records (RAM until you save). With P1's read-only guard on they show on the phone and the FM-1 refuses them.
**Setup:** the Pixel; `./gradlew :app:installDebug` from `android/` (the main session installs). For the fake core add `--es scenario ready` (or `drums`).
**Back up first?** **Yes on the real FM-1 for checks 5–8** (they change the song), and 11–12 if you then save: take a project backup first (Lupe › Projects).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Tap Timeline. Compare with board 58 (`design/boards/phone-portrait/board-58.png`). | Six track heads (the track's colour, number, the selected one ringed), a ruler of bar numbers down the left, six columns; blocks in the track's colour at 45 % over the page with the pattern number, REST as a dashed outline. At split about 8 bars show and the song scrolls; blocks sit in their own track's column. | – | ☐ pass ☐ fail: |
| 2 | Drag the divider to top only. | The same song at about 20 bars: the whole 16-bar song and room below. | – | ☐ pass ☐ fail: |
| 3 | Drag on empty space or an unselected block, up and down. | The song scrolls (an unselected block never moves). | – | ☐ pass ☐ fail: |
| 4 | Tap a block. Tap it again. | A white ring and a grip at its foot; the second tap lets go. Tapping a track head selects that track on the FM-1. | – | ☐ pass ☐ fail: |
| 5 | Select a block and drag it up or down. | The block follows your finger along its own column (never sideways to another track) and lifts (shadow); a tick each time it passes a neighbour; on release it lands in the slot nearest to it. A track's song is a list played back to back, so this **reorders** the blocks: the ones it passed shift to make room. | **Yes** | ☐ pass ☐ fail: |
| 6 | Select a block and drag by its foot (the grip). | Its length grows and shrinks in whole **passes** (a block of 1-bar patterns grows a bar at a time), a tick each; on release the FM-1's REPS follow and the blocks below move up or down. | **Yes** | ☐ pass ☐ fail: |
| 7 | Hold a block (stopped). Compare with board 68, left. | A menu beside your finger: Pattern ⌄ (a list of the FM-1's kept patterns), PASSES with its bars (a value you slide, up and down by default, no − / +), Duplicate, Select sound, Delete…. | – | ☐ pass ☐ fail: |
| 8 | In that menu: slide BARS; pick another Pattern; Duplicate; Select sound; Delete… then wait and tap the red row. | PASSES changes the block live; the pattern number changes (if the old pattern is used nowhere else it asks first: "… is used nowhere else, so setting 12 erases it"); the copy lands after it (or nothing, when the track's 16 entries are full); Select sound opens the Sounds browser for that track; Delete asks in place naming the pattern and bars (and "used nowhere else, so it's erased" when so), Cancel under it, taps ignored for 0.4 s. | **Yes** | ☐ pass ☐ fail: |
| 9 | Press Play. Compare with board 68, right. | A white line (the playhead) runs down the song with the clock, a strip at the foot says "Stop to change the song" with ■ Stop, and editing a block does nothing while it plays. Stop clears the strip. | – | ☐ pass ☐ fail: |
| 10 | At bottom full the editor shows a lane under the grid: tap Draw. Compare with board 69. | The bottom half becomes AUTOMATION: "5 Piano · AUTOMATION", the lane picker (each lane says "3 locks", "1 lock" or "recorded"), the grid kept short, the lane large, a hint under it. Done or Back returns to the editor. | – | ☐ pass ☐ fail: |
| 11 | Drag a finger along the lane. | Each step you pass becomes a lock (◆) at the height you drew, no step skipped on a fast drag; the Magnifier floats the step and value above your finger; a white stroke follows the finger; the hint says "Drawing steps 12–15". | – | ☐ pass ☐ fail: |
| 12 | On a lane with recorded motion (the picker says "recorded"): start a stroke on a step that shows recorded data, or drag into one (a step that only holds a change from an earlier step counts). | It stops at the first such step and asks in place, over the lane: "Draw over the recorded RESONANCE?" with Cancel, taps ignored for 0.4 s; nothing is drawn for those steps yet. After yes, the next touch draws at once, through recorded steps too, and keeps drawing until you lift. Changing lane asks again. Steps with no recorded data never ask. (Decision 16; the core refuses an unconfirmed stroke over recorded steps.) | – | ☐ pass ☐ fail: |
| 13 | Tap a ◆ on the lane. | Its step is selected in the grid. | – | ☐ pass ☐ fail: |
| 14 | TalkBack on: a block's actions (Move a bar later/earlier, One bar longer/shorter, Duplicate, Delete…); the lane. | A block reads "Track 1 Acid, bars 1 to 4, pattern 05"; every drag has an action. The lane has "Lock step N higher/lower" for the first steps; the rest go through the step panel's SOUND tab. | – | ☐ pass ☐ fail: |
| 15 | Remove animations on; repeat 7 and 12. | The menus and the in-place questions fade in, nothing travels. | – | ☐ pass ☐ fail: |

**Calls I made without Scott:**
- **Only a selected block drags**, so an unselected block's drag is the page's scroll (time runs down, so scrolling and moving are both vertical). Move and stretch are also TalkBack actions ("Move one place later/earlier", "One pass longer/shorter").
- **Moving is reordering and stretching is REPS**, because that is what the FM-1's song is (P1's schema): blocks have no free position in bars.
- **At top only about 20 bars show, at split 8**; bar height is fixed, the song scrolls. The playhead doesn't auto-scroll yet.
- **PASSES in the block menu is a slide** (decision 10), one pass a step, 1 to 16.
- **Draw** is a key in the editor's lane header at bottom full; the FM-1's SEQ › AUTOMATION will open it when P1's `automation` area says so.
- **Decision 16's yes lasts for that lane** until you change lane or leave the view; each lift doesn't re-ask.
- **The Timeline menu's "Select sound"** opens the Sounds browser for that track (the pad/track target, not a block).

**Not covered:** chains (BlockChain, BlockSplit have no screen yet), BlockInsert/New (no add-a-block key yet), gaps (not drawn), pinch to zoom (board 57's idea; the time-down view has no zoom), time across (the Labs toggle exists, the layout doesn't), "Add a lane…" in the picker, and playing the song with the order locked on the real FM-1.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device" (TalkBack: release pass).

## Run on build 40c8629, real FM-1, over adb by Claude, 2026-11-13 evening

| # | Result |
|---|---|
| 1 | ✓ heads, ruler, blocks, REST dashed. ✗ the ring sits on track 1 when the FM-1's selected track is 5 or 3 (only right after tapping a head) |
| 2 | ✓ 20 bars at top only |
| 3 | n/a: both songs fit the view |
| 4 | ✓ ring + grip, second tap lets go, head tap selects on the FM-1. ✗ on a 1-bar block the grip crosses the number ("53" reads struck through) |
| 5, 6 | ☐ drags: Scott |
| 7 | ✓ items right. ✗ "PASSES · 1.00000 bars" (float format), header "BARS 2–2" for one bar |
| 8 | ✓ PASSES slides live, Pattern, Duplicate, Delete (asks, names the erase). ✗ no Magnifier seen while sliding PASSES; "5.00000 bars" in the delete question |
| 9 | ✓ playhead, "Stop to change the song" with ■ Stop, editing blocked, Stop clears. ✗ the whole timeline squashes to fit the strip (bar rows shrink while playing) |
| 10–13 | ☐ the lane is hidden when a pattern has no locks or recorded motion, so a fresh pattern offers no way into AUTOMATION. Needs a lock made on the FM-1 first: Scott |
| 14, 15 | ☐ TalkBack, Remove animations: later |

Also: the tempo popover still has −10 / −1 / +1 / +10 steppers (decision 10 says none); the readout never shows Once or Song once set.

## Fixes for the run on 40c8629 (to re-check; 2026-11-14)

| # | Fault | Fixed | Re-check |
|---|---|---|---|
| 6 | Insert, Chain, Split, New, ClearLane had no controls | The block's hold menu has **Insert before…** (REST or a kept pattern), **Chain with the next** and (on a chain) **Split the chain**; holding the empty part of a track's column after its last block opens **New pattern / Add a pattern / Add a REST**; the lane picker has **Clear this lane…**, asked in place. | Hold a block; hold the empty space under a track; open the lane picker. |
| 7 | A fresh pattern had no way into AUTOMATION | The lane area shows for every pattern: with no lanes it is a **Pick a parameter** picker (the lanes it has, plus the controls of the sound page the FM-1 is on), then Draw. **This leans on the core accepting a parameter it hasn't listed**; the automation area should list every drawable parameter. | A pattern with no locks: pick a parameter, Draw, draw. |
| 8 | "1.00000 bars", "BARS 2–2" | "1 bar", "5 bars", "½ bar"; "bar 2". | Menu headings and the Delete question. |
| 9 | The grip crossed a 1-bar block's number | A short block's grip is a small notch at its very foot. | Select a 1-bar block. |
| 10 | The head ring sat on track 1 | It rings the FM-1's selected track (the pads' selection). | Select track 3 or 5 on the FM-1. |
| 11 | Playing squashed the rows | The Stop strip overlays the foot; the rows keep their scale and the song scrolls up to clear it. | Press Play. |

## Fix for Scott's hands on the device (to re-check; 2026-11-14)

| # | Fault | Fixed | Re-check |
|---|---|---|---|
| 5, 6 | A foot drag or a body drag looked right but wasn't kept, and the blocks below didn't move | The drag's end handler read the numbers from when the gesture began (no movement yet), so it sent nothing. The drag state now lives with the track and the end reads it when the finger lifts, so BlockMove and BlockStretch go out. While you stretch, the blocks after it slide by the change in length; while you move, the ones it passes slide the other way and open a gap at the landing slot, all eased (150 ms; Reduce Motion: near-instant). | Select a block, drag its foot: the blocks below move with it, and on release the length is kept (the FM-1 reads it back). Drag a block past a neighbour: the neighbour slides out of the way, a tick as you pass, the order is kept. |

**Known:** on release the dragged block is drawn back at the core's old state until the FM-1's reply arrives (a beat), then lands; it isn't held at the drop point.

## Recheck of the fixes on build fb7a661, real FM-1, over adb by Claude, 2026-11-13 evening

- ✓ The head ring follows the FM-1's selected track (3).
- ✓ A 1-bar block's grip is a notch under the number.
- ✓ The menu reads "TRACK 1 · BAR 7" and "PASSES · 1 BAR"; Insert before… is in the block menu.
- ✓ An empty pattern shows the lane with "Pick a parameter ⌄" and Draw; the picker says to open a sound page on the FM-1 (its knobs are the parameters).
- ☐ Grip and body drags (fb7a661), drawing a lane, Chain/Split/New: Scott, by hand.

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
| 12 | On a lane with recorded motion (the picker says "recorded"): touch it. | The first touch asks in place, over the lane: "Draw over the recorded RESONANCE?" with Cancel, taps ignored for 0.4 s; it draws nothing yet. After yes, the next touch draws at once and keeps drawing until you lift. Changing lane asks again. (Decision 16.) | – | ☐ pass ☐ fail: |
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

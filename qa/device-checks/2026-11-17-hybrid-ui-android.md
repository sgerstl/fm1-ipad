# Device check: hybrid-ui-android, 2026-11-17

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the **Pixel 10 Pro** with the FM-1 (Android first: the hybrid UI is tried here before the iPhone and iPad are decided). The branch merges only after it passes.

**Setup:** FM-1 on Skiff-Lupe 2.5.1 · Lupe Android, branch `hybrid-ui-android` (built from `design-hybrid-ui`) · USB-C cable · no launch flags. Build: `cd android && ./gradlew :app:installDebug` with the Pixel attached.
**Back up first?** No. Nothing here writes the FM-1's flash. Checks 9 and 10 change levels, pans and sends live (they aren't saved unless you save the project).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open Lupe with the FM-1 linked. Look at the header. | One 56-tall row: the Song pill (name ⌄), then **Pads · Edit · Timeline · Mix** as joined pills, a gap, then **Bar ⌄** (outlined), the readout ("27·3" over "120 bpm · Song"), a round grey **Record** with a red dot, and a bigger round white **Play** at the far right, wholly inside the screen's rounded corner. No hairline under the header. | – | ☐ pass ☐ fail: |
| 2 | Tap each tab in turn. | The tapped tab becomes the white pill with dark text; its corners round out with a small spring, and the old tab squares back to grey. The page changes as before. | – | ☐ pass ☐ fail: |
| 3 | Press Play, then Stop. Arm Record. Tap Bar ⌄ and pick Beat; launch a pad while playing so something waits. | Play shows ▶ stopped and ■ playing; the key squashes a little under your thumb. Record goes red with a dark dot. The pill reads "Beat"; while a launch waits a small white number sits on it; its menu lists Loop · Bar · Beat ✓ · Now and Cancel waiting. | – | ☐ pass ☐ fail: |
| 4 | **Pads.** Play the song and watch a pad start at the bar line, then stop one. | A playing pad is a full pill in the track's colour with its pass bar and "×4"; a pad starting **springs** from a rounded card to the pill, and a stopped one goes back. A pad queued for its next pass is a lighter card with an edge in the track's colour and "Next". Nothing jumps. | – | ☐ pass ☐ fail: |
| 5 | Tap another track's head, then a scene, then Store and a scene. | Heads are pills; the selected one gets the track's tint, a coloured edge, and its number badge squares off (the others are round). Scenes sit in one dark toolbar: the current scene white and squarer, stored ones grey and round, empty ones bare. A scene key squashes and springs back when pressed. Store turns white while armed. The HOME knobs still sit at the right. | – | ☐ pass ☐ fail: |
| 6 | **Edit.** Open a melodic track's pattern (Pads › hold › Edit steps). With the panel shut, play. | All 16 steps across the width, as before; it pages along with the playhead as before (patterns longer than 16). | – | ☐ pass ☐ fail: |
| 7 | Press **ENV** on the FM-1 (or LFO) while on Edit. | The sound panel docks at the right (grey, rounded left corners) and the grid steps aside to **8 steps a page**. Under the grid: a strip of 16 small cells with "1–8" at its left, a lighter window behind the page shown, dots where notes are. A **Follow** key (white, on) appears in the bar above the grid. | – | ☐ pass ☐ fail: |
| 8 | Play with Follow on, then tap Follow off and keep playing; tap the minimap's other half; swipe the grid sideways. | Follow on: at step 9 the grid flips to 9–16 with a short spring and the label changes, and back at step 1. Follow off: the page stays put; a light cell runs along the minimap showing where the playhead is. A tap on the other half, or a swipe, turns the page. **Say how the flip feels** (Settings › Labs › Hybrid · Edit page flip tunes it). | – | ☐ pass ☐ fail: |
| 9 | **Mix.** Tap the Mix tab. Slide a strip's fader up and down; double-tap it. Tap Mute and Solo. | Sub-pages Mixer · Delay · Reverb · Chorus · Global along the top (Mixer lit). Six strips fill the width, each with a tall fader and a meter beside it moving with the sound, the dB under it, a line like "C · Rev 12%", and Mute and Solo joined. The fader follows your finger up and down (the Magnifier shows the value) and its white handle thickens while held; double tap puts it back. Mute and Solo turn white and round when on; the FM-1's levels follow. | – | ☐ pass ☐ fail: |
| 10 | Long-press a strip (not on the fader). Slide Pan, then Reverb send. Tap Select sound…. | A dark menu opens beside your finger with the track's badge and name, a Pan slider with a centre mark, a Reverb send slider, then Select sound…. The strip's values line changes as you slide; the FM-1's pan and send follow. Select sound… opens Sounds for that track. | – | ☐ pass ☐ fail: |
| 11 | Press **GLO** on the FM-1 from Pads, then press it again a few times. Then tap Delay on the phone. | GLO takes the phone to the Mix tab; each press steps Mixer → Delay → Reverb → Chorus → Global, and the lit sub-page follows. Delay shows its four dials, DELAY MODE as tiles and the FM-1's grey picture on a dark card (not the docked panel). Tapping Delay on the phone sends the FM-1 to GLO 2/5. HOME on the FM-1 puts the phone back on the tab it was on. | – | ☐ pass ☐ fail: |
| 12 | Song menu › Settings. Flip a switch; pick a Sideways / Up and down segment. Close. | The sheet rises from below the header (the header stays visible above it) with rounded top corners and a short spring, a small grey handle and a round ✕. A switch on is white with a big dark thumb; off, dark with a grey edge and a small grey thumb; the thumb grows and slides. Segments are joined pills with the chosen one white. | – | ☐ pass ☐ fail: |
| 13 | Open the Bar ⌄ menu and the Song menu. | Menus are a lighter grey card with rounder corners; the ticked row is a lighter pill with its ✓; second lines are readable grey. Each menu grows in with a small drop from its key. | – | ☐ pass ☐ fail: |
| 14 | Long-press a pad. | Replaced by check 20 (round 2: the straight menu). | – | – |
| 15 | Settings › Labs: find the five **Hybrid ·** rows (the two Hold menu · spring / speed rows are gone with the wheel) (spring bounce, at the finger, sheets and panels, Edit page flip, press squash). Set the bounce to 0, tap a tab, set it back to 25. | Bounce 0: tabs and pads change shape with no overshoot. 25: a small overshoot. Values stick after leaving Settings. | – | ☐ pass ☐ fail: |
| 16 | Turn on Android's **Remove animations** (Settings › Accessibility › Colour and motion) and repeat 2, 4 and 8. | Shapes land in place without travelling; colours still cross-fade; the 8-step page cuts and its label cross-fades. Nothing pops without a fade. | – | ☐ pass ☐ fail: |

## Round 2 (Scott's Pixel feedback, 2026-11-17: every shape-as-state change travels; the straight hold menu)

Build: the commit that adds this section. Same setup; no backup.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 17 | Tap the header tabs one after another, near and far (Pads → Mix, Mix → Edit). | **One** white pill slides from the old tab to the new: its leading edge runs ahead so it stretches, then it gathers on the new tab with a small overshoot. The labels' colours blend; no tab changes width. | – | ☐ pass ☐ fail: |
| 18 | Mix: tap through Mixer · Delay · Reverb · Chorus · Global. Settings: tap the Slide to turn and Menus open segments. | The same: the grey pill (Mix) or white pill (Settings) slides and stretches between choices; nothing jumps. | – | ☐ pass ☐ fail: |
| 19 | Tap Follow and Chord on Edit; Mute on Pads; Mute and Solo on a Mix strip. | Switching on, the white fill **grows out from the middle** of the key and settles; switching off, it shrinks back. Mute and Solo on Mix also round their inner corners as they fill. | – | ☐ pass ☐ fail: |
| 20 | (Superseded by round 4's priority tiles, checks 37–44.) Long-press a filled pad, an empty pad, a track head and a Timeline block. | A soft white disc grows under your finger; beside it a grey card slides out from the finger and grows in, its rows appearing one after another (quick). Rows have a grey icon, the label and any second line; the current choice is a lighter pill with a ✓; Set pattern… has a ›. No arc, no stalks, no darkening behind. It opens to the left of your finger (Settings › Menus open flips it) and never covers the header. | – | ☐ pass ☐ fail: |
| 21 | In that menu: tap a choice; open it again and tap outside; open it on a pad near the left edge; open a long one (the filled pad's). Pick Delete pattern. | A tap picks and the menu fades out quickly (about 120 ms). Outside closes it. Near the left edge it opens to the right instead. A long one scrolls inside the card. Delete pattern turns its row red-edged with the words naming what goes, the other rows dim; a second tap after a moment confirms. | – | ☐ pass ☐ fail: |
| 22 | Hold a track head: slide LEVEL and PAN in its menu. | The slide rows work as before inside the new card. | – | ☐ pass ☐ fail: |
| 23 | Open the Bar ⌄ menu and pick another launch point; reopen it. | The ✓'s pill grows in on the new row and shrinks away from the old. | – | ☐ pass ☐ fail: |
| 24 | Turn on Android's **Remove animations** and repeat 17, 19 and 20. | Nothing slides or grows: the tab pill fades out of the old tab and into the new; fills fade in where they stand; the menu fades in and out in place. Corner changes ease without overshoot. Nothing pops. | – | ☐ pass ☐ fail: |

## Round 2b: the drag wells (Scott, 2026-11-17: "1 · Edge tabs", "Grow, then fill")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 25 | Stopped: press a filled pad briefly, then slide it off its place. | Five solid grey tabs slide in from the screen's edges on a small spring: Cancel at the bottom, Clear steps and Delete pattern at the top, Edit on the right, Duplicate on the left. Each sits flush on its edge, square there and well rounded toward the middle. No blur, no dashes, no glow. Icons over the words on the sides, beside them top and bottom. | – | ☐ pass ☐ fail: |
| 26 | Drag the pad slowly toward Edit, then away, then onto it. | Edit **grows outward** as you near it, following your finger with no lag, and shrinks as you back off. Close enough, it fills with the pad's colour, its words and icon go dark and the icon grows, with a tick. Drop: Edit opens on that pad, and the wells slide away quicker than they came. | – | ☐ pass ☐ fail: |
| 27 | Drag to Clear steps and to Delete pattern (stopped); then play and drag toward Delete. | Hot, Clear steps and Delete fill **in the track's colour, not red** (Scott's call to keep or change: ☐ keep ☐ want red). While playing, Delete is greyed with "Stop first" in readable grey, doesn't grow and takes no drop; the layout doesn't change. | – | ☐ pass ☐ fail: |
| 28 | Drag to Cancel and to Duplicate. Turn on Remove animations and drag once more. | Cancel and Duplicate behave like Edit (grow, fill in the track's colour). With Remove animations: the wells fade in and out in place and don't grow; hot still fills. | – | ☐ pass ☐ fail: |

## Round 3 (Scott, 2026-11-17: the colour swells; shape changes must read as a transformation)

Labs › **Shape spring · stiffness / damping**, **Fast spring · stiffness**, **Squash and stretch** tune all of these on the phone (starting at M3 Expressive's 380 / 0.80, 800 and 6 %).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 29 | Play the song. Launch a pad on the next bar and watch it start; then stop a playing pad (launch an empty slot or Rest on its row). | Starting: the card **visibly turns into a pill**, its corners rounding over a moment while it bulges wider and flatter, then settles, as the colour fills. Stopping: the pill turns back into a card, narrowing and briefly taller, then settling. It should read as one shape becoming another. | – | ☐ pass ☐ fail: |
| 30 | Tap one track head, then another. | The old badge rounds back to a circle, the new one **squares off with a little squash**, as the head's tint and edge move. | – | ☐ pass ☐ fail: |
| 31 | Recall a stored scene, then another. | The new scene squares off and fills white with a bulge and settle (after its press squash); the old one rounds back. | – | ☐ pass ☐ fail: |
| 32 | Tap tabs far apart (Pads → Mix) and next door (Edit → Timeline). | The white pill **stretches and thins** as it runs, its front edge leading, then gathers to full height on the new tab with a slight overshoot. | – | ☐ pass ☐ fail: |
| 33 | Toggle Follow, Chord, a Pads Mute, a Mix Mute and Solo. | Each fill grows out with a small bulge and settles; off, it shrinks back with the reverse. | – | ☐ pass ☐ fail: |
| 34 | Drag a pad slowly toward each well. | The well **swells in colour** as you near it, from grey toward the pad's colour, getting bigger at the same time, tracking your finger with no jump; the words turn dark partway, smoothly. At the hot point it's full colour, the icon is bigger and you feel the tick. Clear steps and Delete use the track colour (Scott's call, round 3). | – | ☐ pass ☐ fail: |
| 35 | In Labs, set Shape spring · damping to 0.50, then 1.00; Squash to 0 and 12. Repeat 29. | 0.50 bounces more, 1.00 not at all; squash 0 has none, 12 a lot. Say which feels right. | – | ☐ pass ☐ fail: values: |
| 36 | Remove animations on; repeat 29, 30 and 34. | The card and the pill **cross-fade** (no squash, no travel); the badge's circle and square cross-fade; the well's colour still swells with distance (that's tracking, not motion) but it doesn't grow. | – | ☐ pass ☐ fail: |

## Round 4: the hold menu as priority tiles (Scott, 2026-11-17: "C: priority tiles")

**Tile picks to confirm** (Claude chose these from each menu's contents; tick or say what you'd swap):
- Filled pad: **Edit steps · Sound · Pattern** (the mock's) ☐ ok
- Empty pad: **New · Pattern · Rest** ☐ ok
- Track head: **Sounds · Mute · Solo** (Mute and Solo tiles turn white while on) ☐ ok
- Timeline block: **Edit steps · Pattern · Sound** ☐ ok
- Timeline lane (hold an empty stretch): **New · Pattern · Rest** ☐ ok
- Mix strip: **Sound · Mute · Solo**, with Pan and Reverb send as slide rows under them ☐ ok

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 37 | **Playing:** long-press a filled pad. | Beside your finger: three tiles (Edit steps; Sound with the sound's name; Pattern with its number), then a rounded group with Clear steps, then one row "6 more after Stop" with "Play once ±, Duplicate, Move, Delete" under it, ⏸ at the left and ⌄ at the right. No "Stop first" anywhere. It all fits, nothing scrolls, nothing touches an edge. Tiles appear first, then the rows, quickly. | – | ☐ pass ☐ fail: |
| 38 | Tap "6 more after Stop", then tap it again. | It **unfolds in place**: the six show, dimmed (they can't be tapped), and the ⌄ turns; the menu grows smoothly (it may open a second column beside it if there's no room below). Again: it folds back the same way. | – | ☐ pass ☐ fail: |
| 39 | **Stopped:** long-press the same pad. Pick Delete pattern. | Tiles, then groups: Playback (Play once more / less), Arrange (Duplicate after, Move earlier, Move later), Remove (Clear steps, Delete pattern), in two columns if they'd be taller than the screen. A pressed row grows a lighter pill. Delete asks in place (red edge, the words); a second tap confirms. | – | ☐ pass ☐ fail: |
| 40 | Long-press an empty pad. | Tiles New · Pattern · Rest, then Patterns… in a group. With the pattern pool full: the Pool group shows Recycle and Put a kept pattern here…. | – | ☐ pass ☐ fail: |
| 41 | Long-press a track head; tap the Mute tile; slide LEVEL. | Tiles Sounds (engine under it) · Mute · Solo, then LEVEL and PAN as slide rows. Mute's tile turns white with dark words, and the track mutes. | – | ☐ pass ☐ fail: |
| 42 | Stopped, on the Timeline: long-press a block, then an empty stretch of a lane. | Block: tiles Edit steps · Pattern · Sound; groups Playback (Passes…), Arrange (Duplicate, Insert before…, Move earlier / later), Remove (Delete), and Chain where it applies. Lane: tiles New · Pattern · Rest. | – | ☐ pass ☐ fail: |
| 43 | Mix: long-press a strip; slide Pan and Reverb send; tap the Sound tile. | Tiles Sound · Mute · Solo, then PAN and REVERB SEND slide rows; the strip's values line follows; Sound opens Sounds for that track. | – | ☐ pass ☐ fail: |
| 44 | Remove animations on: open a pad's menu while playing and unfold it. | The menu and the unfold fade, nothing slides or springs. | – | ☐ pass ☐ fail: |

## Round 5: Scott's build-gap mocks (2026-11-17; `build-gaps-2026-11-17/`)

Install round 4 and 5 together (the Pixel hasn't had 7836f51).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 45 | **Drums, docked.** Pads › hold the Drum Kit's pattern › Edit steps. Press EDIT on the FM-1 so the panel docks. | Lane keys down the left (KICK, SNARE, CL HAT…), the picked one white and squarer. The grid pages by 8 beside the panel, with the minimap "1–8" under it and Follow in the bar. Hits are rounded squares in the track colour; an accented hit wears a white cap; a ratcheted step shows its repeats as narrow segments. | – | ☐ pass ☐ fail: |
| 46 | Tap a few cells; hold one; play with Follow on, then off; tap the minimap's other half. | A tap places a hit (it grows in) or takes it off; a hold rings it white without changing it. Follow on: pages turn at step 9 and 1. Off: they stay; the playhead's cell lights on the minimap; a tap turns the page. | – | ☐ pass ☐ fail: |
| 47 | On EDIT › LANES (the FM-1's lanes page), tap another lane key. | The key turns white (with a small squash), the FM-1's LANE knob follows, so the docked page shows that lane's Level, Tune and Decay. (The mock's Tune · Decay · Level · Pan tiles and curve aren't built.) A press on a key still plays the lane. | – | ☐ pass ☐ fail: |
| 48 | Lanes 7–8: count the lanes on screen. | Decided (Scott, 2026-11-17): shorter rows. See check 55. | – | – |
| 49 | **Stopped,** long-press a filled pad. Compare with `2a`. | Two columns: tiles (4 apart) and Playback under them on the left; Arrange and Remove on the right. Nothing scrolls; 12 from every edge. | – | ☐ pass ☐ fail: |
| 50 | Long-press a track head; tap Mute; long-press a Mix strip and slide Pan. | Mute's tile turns white and **squares off** with a squash. The Mix strip's Pan and Reverb send fills are in the track's colour. | – | ☐ pass ☐ fail: |
| 51 | Stopped, long-press a Timeline block. Compare with `2d`. | Tiles and Passes… on the left, Arrange and Remove on the right. | – | ☐ pass ☐ fail: |
| 52 | **Live switch.** Stopped, long-press a filled pad; with the menu open, press Play on the FM-1. Then press Stop. | Play: the tiles stay put. Arrange, Remove's Delete and Playback fold away to the left. Clear steps travels across to sit under the tiles. Then "6 more after Stop" drops in last. The menu narrows toward your finger without jumping. Stop: "6 more after Stop" leaves first, Clear steps travels back, and the groups come back in. **Scott to judge: does the menu keep its place well enough?** | – | ☐ pass ☐ fail: |
| 53 | Remove animations on; repeat 52. | The two layouts cross-fade in about 150 ms; nothing slides. | – | ☐ pass ☐ fail: |
| 54 | Settings › Menus open: Left (the default) and Right. | The mocks open to the right of the finger. With Left, the menu opens to the left and flips near the edge. **Scott's call:** ☐ keep Left as the default ☐ make Right the default. | – | ☐ noted |

## Round 5b: eight drum lanes on shorter rows (Scott, 2026-11-17, `1b`)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 55 | Drum Kit on Edit with the panel docked. Count the lanes; look at a hit, an accent and a ratchet. | All eight lanes (KICK … RIM, or the kit's own names) in the height six used, no scroll. Lane keys are small (40 × 28) with their names on one line; hits are wide, short rounded squares centred in their rows; accent caps and ratchet segments still read. | – | ☐ pass ☐ fail: |
| 56 | **While playing,** tap lane keys quickly up and down the column, and tap hits on neighbouring lanes. | Each tap picks or plays the lane you meant: the touch area is the whole row, though the key is drawn smaller. **Do neighbouring lanes get mis-tapped?** ☐ never ☐ sometimes (which lanes?) ☐ often | – | ☐ pass ☐ fail: |

## Round 6: the smooth playhead and the hit bounce (Scott, 2026-11-17)

Labs › **Hit bounce · size / rise / settle** tune the bounce (starting at 112 %, 50 ms, 200 ms).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 57 | Edit a melodic pattern and play, panel shut and then docked. | The playhead **sweeps smoothly** across the grid (a light band with a white cap), not hopping step to step, and stays exactly with what you hear, bar after bar. | – | ☐ pass ☐ fail: |
| 58 | Watch the notes as it plays. | Each note gives a **small bounce as it sounds** (grows a touch, springs back); steps with no note never move. It lines up with the sound, not with where the band's edge is. | – | ☐ pass ☐ fail: |
| 59 | A busy kit: all eight lanes full, some accents and ratchets; tempo up to 180–200. Play on Edit with the panel docked. | The sweep stays smooth and in time; every hit bounces as it sounds; a ratchet bounces as one; nothing stutters. **Frame check:** after a minute of this, tell Claude, who reads the frame stats from the phone over adb (`dumpsys gfxinfo`, read-only). | – | ☐ pass ☐ fail: |
| 60 | Change tempo while playing; stop and start; turn the FM-1's direction to reverse if it has it. | The sweep follows the new tempo at once, never runs ahead of the sound, and starts clean from step 1; in reverse it sweeps backwards. | – | ☐ pass ☐ fail: |
| 61 | Remove animations on; play again. | The playhead **jumps** step to step and nothing bounces. **Scott's call:** this was decided for you; ☐ keep ☐ want the glide kept with Reduce Motion. | – | ☐ pass ☐ fail: |
| 62 | Labs: set Hit bounce · size to 100 %, then 125 %. | 100 %: no bounce. 125 %: a clear one. Say what feels right. | – | ☐ pass ☐ fail: value: |

**Not covered here** (needs a later round or Scott's call):
- TalkBack: the strip's Pan and Reverb send actions, the minimap's "Show steps 9–16" action, the tabs' selected state. Belongs to the release accessibility pass (rule 6).
- The Timeline's own hybrid changes (pill heads, connected zoom group, pass-count chips) and the Sounds and Projects sheets' row styling aren't built; they pick up only the shared keys, menus and sheet.
- The narrow-width give-way (spec 4.1) never triggers on the Pixel (it starts below 790 dp); its order is unit-tested only.
- Still open, untouched: the track thread's place, the slider's unfilled track contrast, the empty pad's edge (A11), a playing pad on a muted row (S14).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

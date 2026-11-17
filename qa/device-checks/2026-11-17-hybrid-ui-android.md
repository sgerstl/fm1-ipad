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
| 8 | Play with Follow on, then tap Follow off and keep playing; tap the minimap's other half; swipe the grid sideways. | Follow on: at step 9 the grid flips to 9–16 with a short spring and the label changes, and back at step 1. Follow off: the page stays put; a light cell runs along the minimap showing where the playhead is. A tap on the other half, or a swipe, turns the page. Say how the flip feels. | – | ☐ pass ☐ fail: |
| 9 | **Mix.** Tap the Mix tab. Slide a strip's fader up and down; double-tap it. Tap Mute and Solo. | Sub-pages Mixer · Delay · Reverb · Chorus · Global along the top (Mixer lit). Six strips fill the width, each with a tall fader and a meter beside it moving with the sound, the dB under it, a line like "C · Rev 12%", and Mute and Solo joined. The fader follows your finger up and down (the Magnifier shows the value) and its white handle thickens while held; double tap puts it back. Mute and Solo turn white and round when on; the FM-1's levels follow. | – | ☐ pass ☐ fail: |
| 10 | Long-press a strip (not on the fader). Slide Pan, then Reverb send. Tap Select sound…. | A dark menu opens beside your finger with the track's badge and name, a Pan slider with a centre mark, a Reverb send slider, then Select sound…. The strip's values line changes as you slide; the FM-1's pan and send follow. Select sound… opens Sounds for that track. | – | ☐ pass ☐ fail: |
| 11 | Press **GLO** on the FM-1 from Pads, then press it again a few times. Then tap Delay on the phone. | GLO takes the phone to the Mix tab; each press steps Mixer → Delay → Reverb → Chorus → Global, and the lit sub-page follows. Delay shows its four dials, DELAY MODE as tiles and the FM-1's grey picture on a dark card (not the docked panel). Tapping Delay on the phone sends the FM-1 to GLO 2/5. HOME on the FM-1 puts the phone back on the tab it was on. | – | ☐ pass ☐ fail: |
| 12 | Song menu › Settings. Flip a switch; pick a Sideways / Up and down segment. Close. | The sheet rises from below the header (the header stays visible above it) with rounded top corners and a short spring, a small grey handle and a round ✕. A switch on is white with a big dark thumb; off, dark with a grey edge and a small grey thumb; the thumb grows and slides. Segments are joined pills with the chosen one white. | – | ☐ pass ☐ fail: |
| 13 | Open the Bar ⌄ menu and the Song menu. | Menus are a lighter grey card with rounder corners; the ticked row is a lighter pill with its ✓; second lines are readable grey. Each menu grows in with a small drop from its key. | – | ☐ pass ☐ fail: |
| 14 | Long-press a pad. | Replaced by check 20 (round 2: the straight menu). | – | – |
| 15 | (Retired 2026-11-17: the Labs motion sliders were removed; their values are fixed.) | – | – | – |
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

The springs are fixed at M3 Expressive's 380 / 0.80 and 800, the squash at 6 % (the Labs sliders were removed 2026-11-17).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 29 | Play the song. Launch a pad on the next bar and watch it start; then stop a playing pad (launch an empty slot or Rest on its row). | Starting: the card **visibly turns into a pill**, its corners rounding over a moment while it bulges wider and flatter, then settles, as the colour fills. Stopping: the pill turns back into a card, narrowing and briefly taller, then settling. It should read as one shape becoming another. | – | ☐ pass ☐ fail: |
| 30 | Tap one track head, then another. | The old badge rounds back to a circle, the new one **squares off with a little squash**, as the head's tint and edge move. | – | ☐ pass ☐ fail: |
| 31 | Recall a stored scene, then another. | The new scene squares off and fills white with a bulge and settle (after its press squash); the old one rounds back. | – | ☐ pass ☐ fail: |
| 32 | Tap tabs far apart (Pads → Mix) and next door (Edit → Timeline). | The white pill **stretches and thins** as it runs, its front edge leading, then gathers to full height on the new tab with a slight overshoot. | – | ☐ pass ☐ fail: |
| 33 | Toggle Follow, Chord, a Pads Mute, a Mix Mute and Solo. | Each fill grows out with a small bulge and settles; off, it shrinks back with the reverse. | – | ☐ pass ☐ fail: |
| 34 | Drag a pad slowly toward each well. | The well **swells in colour** as you near it, from grey toward the pad's colour, getting bigger at the same time, tracking your finger with no jump; the words turn dark partway, smoothly. At the hot point it's full colour, the icon is bigger and you feel the tick. Clear steps and Delete use the track colour (Scott's call, round 3). | – | ☐ pass ☐ fail: |
| 35 | (Retired 2026-11-17: the spring and squash sliders left Labs; the round 3 values are fixed.) | – | – | – |
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

The bounce is fixed at 112 %, 50 ms up, 200 ms back (the Labs sliders were removed 2026-11-17).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 57 | Edit a melodic pattern and play, panel shut and then docked. | The playhead **sweeps smoothly** across the grid (a light band with a white cap), not hopping step to step, and stays exactly with what you hear, bar after bar. | – | ☐ pass ☐ fail: |
| 58 | Watch the notes as it plays. | Each note gives a **small bounce as it sounds** (grows a touch, springs back); steps with no note never move. It lines up with the sound, not with where the band's edge is. | – | ☐ pass ☐ fail: |
| 59 | A busy kit: all eight lanes full, some accents and ratchets; tempo up to 180–200. Play on Edit with the panel docked. | The sweep stays smooth and in time; every hit bounces as it sounds; a ratchet bounces as one; nothing stutters. **Frame check:** after a minute of this, tell Claude, who reads the frame stats from the phone over adb (`dumpsys gfxinfo`, read-only). | – | ☐ pass ☐ fail: |
| 60 | Change tempo while playing; stop and start; turn the FM-1's direction to reverse if it has it. | The sweep follows the new tempo at once, never runs ahead of the sound, and starts clean from step 1; in reverse it sweeps backwards. | – | ☐ pass ☐ fail: |
| 61 | Remove animations on; play again. | The playhead **jumps** step to step and nothing bounces. **Scott's call:** this was decided for you; ☐ keep ☐ want the glide kept with Reduce Motion. | – | ☐ pass ☐ fail: |
| 62 | (Retired 2026-11-17: the hit bounce sliders left Labs; 112 %, 50 ms, 200 ms are fixed.) | – | – | – |

## Round 7: small fixes (Scott, 2026-11-17: "everything seems good so far")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 63 | Song menu › Labs. | Only four switches: Pause following after a touch, Pin the sound page, Piano under the grid, Timeline: time across. No sliders. Everything moves as it did (the values are fixed at the defaults). | – | ☐ pass ☐ fail: |
| 64 | Song menu › tap the readout (the tempo menu), and anywhere else a slider shows in a menu or sheet. Start a scroll with your finger **on a slider** and drag up and down. | The label and value sit on the left, the slider on the right half. An up-and-down drag scrolls (or does nothing in a short menu) and **never changes the value**; only a clearly sideways drag on the slider moves it. Double tap still puts it back. | – | ☐ pass ☐ fail: |
| 65 | Edit with the panel docked: swipe the grid a little (about a fifth of its width) and let go; then flick it quickly a short way. | Either turns the page, and it springs the rest of the way. A tiny nudge springs back. It never skips more than one page. | – | ☐ pass ☐ fail: |
| 66 | Edit: open the step panel (Step N), then swipe it to the right. | It slides away, the same gesture as the sound panel; the grid takes the width back. | – | ☐ pass ☐ fail: |

## Round 8: the Timeline as mocked (Scott, 2026-11-17: "Let's build the timeline as mocked"; `phone-05`)

Install rounds 7 and 8 together.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 67 | Stopped, open the Timeline. Compare with `phone-05-timeline-refusal.png`. | Zoom is a joined − + pair at the top left. Heads are wider pills (badge and name); the selected track's is tinted with an edge in its colour, its badge squarer, and its lane wears the same edge. Lanes are dark rounded wells; blocks are rounded, tinted with a coloured edge; rests are dashed boxes; blocks with repeats show "×4" in a dark chip. | – | ☐ pass ☐ fail: |
| 68 | Play. Watch a block start and another stop. | The playing block **fills with its colour** (dark number), with a small squash and settle; the one that stops goes back to tinted with an edge. Its chip counts "1/4, 2/4…". The playhead is a thin line with a round knob on the ruler. | – | ☐ pass ☐ fail: |
| 69 | While playing, look at the foot of the screen; tap Stop there. Play again and tap ✕; play again and switch to Pads. | "Stop to change the song" sits in the app strip with Stop and ✕ (not on the ruler). Stop stops the song and the strip goes. ✕ dismisses it. Leaving the Timeline takes it away. | – | ☐ pass ☐ fail: |
| 70 | Stopped: tap −/+, pinch, pan, select a block and drag it along, drag its grip, long-press a block and an empty lane. | All as before: zoom, pan, reorder, passes, and the tile menus. | – | ☐ pass ☐ fail: |

## Round 9: the Edit redesign (Scott, 2026-11-17: "Build it"; `edit-redesign-2026-11-17/`)

Install rounds 7, 8 and 9 together. **Check 72 is the one only the real FM-1 can answer.**

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 71 | Edit a melodic pattern. Look at the bar over the grid; open the step panel (Step N ⌄). Compare with `1-notes-knobs-drive-step.png`. | Bar: badge and "Acid · A 01" over the scale; Chord and Lane outlined (white when on), "16 steps ⌄", Follow on 8-step pages, "Step N ⌄". Panel: "STEP N" over "F#3 · 1 note", a joined ‹ ›, ⋯; Notes · Feel · Sound joined; four tiles numbered 1–4 (PITCH, START, LENGTH, VELOCITY); "FM-1 knobs 1–4 → step N"; Lock and Clear all. | – | ☐ pass ☐ fail: |
| 72 | **The knob link, real FM-1.** With the panel on Notes, pick step 5 on the phone. Turn the FM-1's knobs 1–4. Then turn the FM-1's PRESETS encoder. Then press SEQ again for FEEL and turn its knobs. | Picking step 5 puts the FM-1 on SEQ › NOTES with its cursor on step 5. Knob 1 changes PITCH, 2 moves the note (START), 3 LENGTH, 4 VELOCITY, each showing in the matching tile. PRESETS moves the cursor, and the phone's picked step and panel follow it (the grid pages if it leaves the page). On FEEL the panel switches to Feel, and its tiles follow knobs 1 CHANCE (on into the conditions past 100), 2 RATCHET (up to 5 on the FM-1), 3 NUDGE, 4 TYPE. Opening the Feel tab on the phone sends the FM-1 to SEQ › FEEL. **If the knobs don't match those numbers, say which do what.** | – | ☐ pass ☐ fail: |
| 73 | Slide a tile sideways; scroll the panel up and down starting on a tile; tap ‹ ›; open ⋯ and Copy, then Paste on another step. | Sideways changes the value; up and down scrolls the panel and doesn't change it. ‹ › step the picked step (and the FM-1's cursor). ⋯ has Copy, Paste and Clear step with their confirms. | – | ☐ pass ☐ fail: |
| 74 | Feel tab: slide CHANCE up past 100; slide RATCHET; slide NUDGE right to the end; open Conditions ⌄. | Four numbered tiles like Notes (1 CHANCE, 2 RATCHET, 3 NUDGE, 4 TYPE greyed: the FM-1's knob 4 turns it). CHANCE climbs to 100 %, then on through the conditions ("Fill", "1st of 2"…, "4th of 4"). RATCHET 1–4 by touch (5 shows if the FM-1's knob sets it). NUDGE reaches +31 (and −32), centred at 0. Conditions ⌄ picks the same value. | – | ☐ pass ☐ fail: |
| 75 | Sound tab with a locked step: clear one lock. | Lock rows with 40-tall ✕ keys; clearing one removes it. | – | ☐ pass ☐ fail: |
| 76 | **Drag a note:** press a note and move it at once (before the hold fires) up two rows and over one step; let go. Then drag one to the grid's right edge and hold. | It lifts (a touch bigger, a shadow), a dashed ghost stays behind, a faint cell shows where it'll land and a chip reads "G#3 · step 6". Let go: it settles into place (no jump), its length and velocity kept; the panel shows that step. At the edge the 8-step grid turns its page. | – | ☐ pass ☐ fail: |
| 77 | Press a note and hold it still. | Lock mode, as before (no drag). | – | ☐ pass ☐ fail: |
| 78 | Kit: drag a hit along its lane onto an empty step, then onto a step with a hit. | Onto empty: it moves (an accent isn't carried). Onto a hit: refused with a buzz, nothing changes. | – | ☐ pass ☐ fail: |
| 79 | Kit: pick a hit (hold it) and open the step panel. | NOTES tiles 1 LANE, 2 HIT, 3 ACC (greyed: the FM-1's knob 3 turns it), 4 VELOCITY, then the FEEL tiles. Sliding LANE picks the next lane; HIT turns the hit on or off. | – | ☐ pass ☐ fail: |

## Round 10: Mix effect cards (direction C; Scott, 2026-11-17: "yes send the cards")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 80 | Mix tab: tap Effects. Compare with `1-delay-picked.png`. | Sub-tabs Mixer · Effects. Four cards: the picked one wide with its title, "Shared effect · all tracks", four numbered tiles (the FM-1's names for that page), the FM-1's picture in grey and white, and on Delay the DELAY MODE pills; three narrow cards with name, a small picture and two values ("—" for any not opened yet). | – | ☐ pass ☐ fail: |
| 81 | Tap Reverb, then Chorus, then Global, then Delay. | The tapped card squashes a little, then grows as the old one narrows, both moving together on a spring (no gap, nothing blank); the contents swap with a short overlap. The FM-1 goes to that GLO page each time. | – | ☐ pass ☐ fail: |
| 82 | On the FM-1, press GLO repeatedly from Pads. | Mixer, then Delay, Reverb, Chorus, Global as the picked card, the phone following each press. | – | ☐ pass ☐ fail: |
| 83 | With a card picked, turn the FM-1's knobs 1–4; slide a tile sideways on the phone. | The knobs move the matching tiles; a sideways slide on a tile changes it and the FM-1 follows. | – | ☐ pass ☐ fail: |
| 84 | Delay: tap Stereo, then Ping-pong. Reverb: tap a track's send chip and slide. | The mode pills move the white pill and the FM-1's DELAY MODE. The send chip opens a small menu with REVERB SEND as a slide row; the chip's number and the Mix strip's values line follow. | – | ☐ pass ☐ fail: |
| 85 | Remove animations on; pick another card. | The cards cross-fade; widths change without travelling. | – | ☐ pass ☐ fail: |

## Round 11: tab motion and press (Scott, 2026-11-17: "b and c")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 86 | Tap between the four tabs. | No sideways slide: the old page fades out quickly and the new one fades in, settling from a touch smaller; the white pill springs across; the selected track's band glides between its places. | – | ☐ pass ☐ fail: |
| 87 | Press a tab and hold, then let go; press another and slide off before letting go. | Pressed, the tab shrinks at once (before the pill moves); let go, it springs back with a little overshoot as the pill lands under it. Slid off: it springs back and nothing changes. Same feel on Mixer · Effects, Notes · Feel · Sound, the Song menu, the Bar pill and the effect cards. | – | ☐ pass ☐ fail: |
| 88 | Hold a filled pad › Edit steps. Then on the Timeline, hold a block › Edit steps. | A surface grows out of the pad (or the block): its colour fading, a coloured edge, corners rounding out to the page, while Pads fades under it; Edit's content fades in as it lands. A tap on the Edit tab itself fades through instead. | – | ☐ pass ☐ fail: |
| 90 | Mix › Effects with the real FM-1 (long names): look at the three collapsed cards and the picked card's tiles. | Every collapsed card: name, picture and values on one left edge; the pictures all at the same height (Global's bars no higher than the others); the value rows lined up along the bottom across the cards; long names cut with "…", nothing running past an edge. Tile labels too are cut inside the tile, never wrapped. | – | ☐ pass ☐ fail: |
| 89 | Remove animations on; repeat 86–88. | Tabs and Edit cross-fade; a press only brightens the key (no shrink). | – | ☐ pass ☐ fail: |

## Round 12 (Scott, 2026-11-17)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 91 | On Pads, tap the Edit tab; then tap Pads. Scroll the pads so the selected track's pad is off screen and tap Edit again. | Edit grows out of the selected track's current pad (as from its hold menu); Pads → Edit back shrinks Edit into that pad while Pads fades in. With the pad scrolled away: a plain fade-through. Timeline/Mix ↔ Edit: fade-through. **Scott: keep the shrink back?** ☐ keep ☐ drop | – | ☐ pass ☐ fail: |
| 92 | Open a sound page (ENV on the FM-1). Look at the panel's header and left edge. Tap the small bar on the left edge; open it again and swipe it away. | No close arrow. "1 of 2" (or "3 of 7") large at the header's right end; the page name on the left without a count. A short grey bar on the panel's left edge: a tap closes the panel, and the FM-1 goes back to HOME (on Mix: to GLO's page); a swipe does the same. | – | ☐ pass ☐ fail: |
| 93 | Edit: open the step panel; tap its left-edge bar. | The step panel closes (the same bar, same tap). | – | ☐ pass ☐ fail: |
| 94 | Pads: tap Store, then tap it again. | No dot. Armed: Store turns white with dark text and its corners square off a little, with a small squash; empty scenes show a clearer outline. Disarmed: back to a grey pill. Its width doesn't change. | – | ☐ pass ☐ fail: |
| 95 | Edit: tap Chord, Lane, Follow. | No dots: off, outlined pills; on, white with squarer corners (the same language as Store). **Scott: keep?** ☐ keep ☐ dots back | – | ☐ pass ☐ fail: |
| 96 | TalkBack on: find the sound panel's handle and the step panel's handle. | Each reads "Close the sound panel" / "Close the step panel" as a button; double tap closes. | – | ☐ pass ☐ fail: |

## Round 13: a swipe never edits (Scott, 2026-11-17: "I can't swipe between the pages without adding a step or a drum step")

Open the step panel or a sound page first so the grid pages by 8.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 97 | Drum track: swipe sideways starting on an **empty** cell. | The page turns. No hit appears where the finger started or anywhere it passed. | – | ☐ pass ☐ fail: |
| 98 | Drum track: swipe sideways starting **on a hit**, right away (no pause). | The page turns. The hit stays where it was, not toggled off, not moved. | – | ☐ pass ☐ fail: |
| 99 | Melodic track: repeat 97 and 98 on an empty cell and on a note. Also swipe up and down. | Sideways pages, up and down scrolls the pitches. No note is written, removed or moved. | – | ☐ pass ☐ fail: |
| 100 | A quick flick from a hit (drum) and from a note (melodic). | One page on; nothing changed in the grid. | – | ☐ pass ☐ fail: |
| 101 | Press a hit (or a note), hold still a moment (about a sixth of a second), then slide. | It lifts and drags as before (round 9); let go and it lands; the page doesn't turn under it. A plain tap still toggles; a longer still hold still locks (melodic) or picks (drum). | – | ☐ pass ☐ fail: |
| 102 | Tap a cell quickly several times while the pattern plays. | Each tap toggles once, on lift. A tap that slides a little (within a fingertip) still counts as a tap. | – | ☐ pass ☐ fail: |

## Round 13b: effect cards keep the tiles whole (Scott: "it squeezed the controls down so the values get cut off")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 103 | Mix › Effects with the real FM-1: pick Reverb. | The four tiles fill the card's height; every value and label shows in full. The right column: the picture (shorter), then the six send chips in two rows of three (dot and value). A tap on a chip opens that track's send slide. | – | ☐ pass ☐ fail: |
| 104 | Pick Delay. | Tiles whole. Under the picture: MODE with Mono · Stereo · Ping pills, all three readable; a tap changes the FM-1's mode. | – | ☐ pass ☐ fail: |
| 105 | Pick Chorus and Global. Then turn the font size up in Android settings and look again at all four. | Tiles whole, the picture fills the right column. At a large font, the tiles keep their height and scroll if they must; nothing is cut off. | – | ☐ pass ☐ fail: |

## Round 13c: Mute and Solo on Mix wait visibly (Scott: "a bounce under my finger and then a gray line around the button timing it")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 106 | Mix › Mixer, playing, Launch at = Bar: tap a track's Mute. | Under the finger: a quick squash and a springy return. The key stays unmuted while a grey line runs round it from the top left corner, down the left side first (counter-clockwise, as every launch trace in Lupe and on the iPad), closing as the bar turns over; then it goes white and round and the track drops out. | – | ☐ pass ☐ fail: |
| 107 | Same track: tap Mute again to unmute. Then set Launch at to 4 bars and repeat 106 and 107. | Unmuting: it stays white (muted) while the line runs round; it turns back only as the line closes. At 4 bars the line takes four bars to close. | – | ☐ pass ☐ fail: |
| 108 | While a line is running, tap the key again. Then try Solo the same way. Then stop and tap Mute. | Tapped again: it does what the Pads row does (the change is called off and the line goes). Solo traces the same way. Stopped: it changes at once, no line. | – | ☐ pass ☐ fail: |
| 109 | Put Pads and Mix side by side in behaviour: mute a track from the Pads row's Mute while playing, then from Mix. Then turn Remove animations on and repeat once. | Both lines are the same grey and thickness and close at the same moment. With Remove animations on: no squash, but the line still draws. | – | ☐ pass ☐ fail: |

## Round 13d: the selected ring and shape-true traces (Scott, 2026-11-17)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 110 | Stopped: tap pads one after another along a row, then on another row. | The ring on the old pad fades out while the new one fades in, together, quickly and smoothly. No flicker or flash. | – | ☐ pass ☐ fail: |
| 111 | Playing: tap a pad that isn't playing (it queues). Then let it land. | No flash of the ring on the tapped pad: it shows the launch trace only, and the old pad's ring fades out. As it lands, the trace goes and the ring fades in. | – | ☐ pass ☐ fail: |
| 112 | Mix, playing: tap an unmuted Mute (and an unsoloed Solo). | The grey line runs on the key's own edge: round at the outer end, the tighter corners at the inner end where Mute meets Solo. It doesn't cut across any corner. | – | ☐ pass ☐ fail: |
| 113 | Mix, playing: unmute a muted key. | The line runs on the white key's pill outline. As it closes and the key changes shape, there's no jump between line and key. | – | ☐ pass ☐ fail: |
| 114 | Pads, playing: recall a stored scene. Watch its key, and a queued pad's trace. | The scene's trace runs on the round key's own outline (and on the squarer one if the current scene is recalled again); the pad's trace hugs the pad's corners. | – | ☐ pass ☐ fail: |

## Round 13e: HOME goes back to where you were (Scott, 2026-11-17)

Press HOME on the FM-1 itself.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 115 | On Pads, tap the Mix tab on the phone; pick Effects and a card. Press HOME. Repeat starting from GLO on the FM-1. | Back on Pads, with a fade-through, both times. | – | ☐ pass ☐ fail: |
| 116 | On Timeline, tap Mix; press HOME. Then on Timeline, tap Edit; press HOME. | Back on Timeline both times. | – | ☐ pass ☐ fail: |
| 117 | On Pads, tap Edit; press HOME. Then press HOME again on Pads, and on Timeline. | Edit → back to Pads (shrinking into the selected pad). HOME on Pads or Timeline: the tab stays. | – | ☐ pass ☐ fail: |
| 118 | On Edit with a sound page open (ENV on the FM-1), tap the panel's handle. Then open it again and press HOME on the FM-1. | Handle: the panel closes and you stay on Edit. FM-1 HOME: the panel closes and the phone goes back to the last of Pads and Timeline. | – | ☐ pass ☐ fail: |

## Round 13f: the steps menu fits (Scott: "Shouldn't I get up to 64?")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 119 | Edit: tap "16 steps ⌄". | Two tiles on top, One fewer ("15 steps") and One more ("17 steps"); under them two rows of pills, 4 8 12 16 and 24 32 48 64, with 16 white and squarer. All on screen, beside the finger. | – | ☐ pass ☐ fail: |
| 120 | Tap 64; open the menu again; tap One fewer. | The pattern goes to 64 steps (64 now the white pill); then 63, with no pill selected. Pills shrink a little under the finger and spring back. | – | ☐ pass ☐ fail: |
| 121 | Open the step panel's Conditions list and the readout's menu. | Both fit or scroll inside the screen; nothing is cut off at the bottom. (Conditions has 12 rows: it scrolls, see the note.) | – | ☐ pass ☐ fail: |

## Round 13g: resize and long-press move (Scott, 2026-11-17)

Melodic track unless it says drum. The step panel open, so the grid pages by 8.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 122 | Press a 1-step note's right end (the two grip marks) and drag right two steps, then let go. Then drag a long note's end left. | The end follows by whole steps with a tick each, "3 steps" above it; let go and the step panel's LENGTH reads 3. Dragged left it shortens, never below 1 or past the next note. | – | ☐ pass ☐ fail: |
| 123 | Resize a note near the page's right edge, holding the finger at the grid's edge. | The grid pages on and the note keeps growing onto the next page. | – | ☐ pass ☐ fail: |
| 124 | Press a note, hold still well past a second, then move the finger. | The note lifts as soon as the hold registers (about a sixth of a second: it grows a little, with a shadow and a light tick), then follows; let go and it lands. No lock at any point. | – | ☐ pass ☐ fail: |
| 125 | Press a note, hold for about a quarter of a second, then move. | It lifts and drags (as before). | – | ☐ pass ☐ fail: |
| 126 | Swipe quickly sideways from a note's body and from its grip end. | From the body, the page turns and the note is untouched. From the grip end, it resizes (the handle has no delay). | – | ☐ pass ☐ fail: |
| 127 | Hold a note still, then lift without moving. Then use the step panel's Lock key and turn an FM-1 knob. Then drum: hold a hit and lift; hold another and slide along the lane. | A hold lifts the note; letting go without moving changes nothing (it settles back). The Lock key still locks: the knob writes a lock on the step. Drum: a held hit lifts and settles back picked, unchanged; slid, it's carried along its lane onto an empty cell. Holding a step on the FM-1 itself still shows lock. | – | ☐ pass ☐ fail: |

## Round 13h: long notes own their body (Scott: "it should select that note regardless of what step you're tapping")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 128 | Make a 3-step note. Tap its 2nd step, then its 3rd (pick another step in between). | Each tap picks the note; the step panel shows its first step. Nothing new is made and the note keeps its length. | – | ☐ pass ☐ fail: |
| 129 | With that note picked, tap its 2nd step again. | The whole note goes, not a slice of it. | – | ☐ pass ☐ fail: |
| 130 | Long-press the middle of a long note and move it two steps right and up a row. Then hold an empty cell a long time and lift. | The whole note moves, keeping its length, with the finger at the same place on it. The long hold on an empty cell writes a note, the same as a tap. | – | ☐ pass ☐ fail: |

## Round 13i: Chord with the real FM-1 (Scott: "the chord key doesn't work")

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 131 | Real FM-1 linked, a melodic track. Tap Chord (it turns white). Tap step 1's column on three other rows, then a fifth. Tap Chord off and tap another row. | Each tap adds a note to step 1, up to four; the fifth is refused with a message. With Chord off, a tap replaces the step's notes with the one tapped. The FM-1's own CHRD setting doesn't change. | – | ☐ pass ☐ fail: |

## Round 13j: the FM-1's keys light Edit (Scott, 2026-11-17)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 132 | Edit on a melodic track, stopped. Press single keys on the FM-1, then hold a chord. | Each held key's piano-edge key fills with the track colour and dips in a little, its name on it; its row glows faintly across the grid. Let go: it fades back, no snap. A chord lights every key. | – | ☐ pass ☐ fail: |
| 133 | Scroll the roll so the FM-1's octave is out of view; hold a key. Tap the marker at the edge. | A small track-coloured marker at the top (or bottom) of the piano edge, pointing to the note; the roll doesn't move by itself. A tap glides the roll to that note. | – | ☐ pass ☐ fail: |
| 134 | A drum track: hit pads on the FM-1. Then press play and watch a melodic track's Edit. | The lane key for each pad hit lights and fades. Playing: the keys also light with the sequencer's own notes (expected: the FM-1 sends them on the same channel). | – | ☐ pass ☐ fail: |

## Round 14 (Scott, 2026-11-18)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 135 | Stopped, play a phrase on the FM-1 and wait. | No strip over the page. A small chip by Record: the track's dot and the note count, scaling in once and then still. Play another phrase: the count changes. A tap opens the FREE TAKE picker. | – | ☐ pass ☐ fail: |
| 136 | Settings › Offer played phrases: Pop-up, then Off; play a phrase each time. | Pop-up: the old strip over Edit. Off: nothing at all. | – | ☐ pass ☐ fail: |
| 137 | A kit on Edit (first time on this install). Then hold a hit and let go without moving. | A one-line "Hold a hit to edit it" in the app strip, gone at the next touch. The held hit lifts, settles, and the step panel opens titled "BD · STEP 5" (its lane and step), with the tiles; the FM-1 goes to SEQ › NOTES on that step. | – | ☐ pass ☐ fail: |
| 138 | With the panel open, hold another hit; then use ‹ ›. | The panel retargets to the new hit. ‹ › step through that lane's hits, round from the last to the first. | – | ☐ pass ☐ fail: |
| 139 | Close the panel; tap Step on the kit with nothing picked. Then tap a cell; hold and slide a hit. | Step opens on the last picked hit, or the pattern's first. A tap toggles; hold and slide drags the hit along its lane. | – | ☐ pass ☐ fail: |

**Not covered here** (needs a later round or Scott's call):
- TalkBack: the strip's Pan and Reverb send actions, the minimap's "Show steps 9–16" action, the tabs' selected state. Belongs to the release accessibility pass (rule 6).
- The Sounds and Projects sheets' row styling isn't built; they pick up only the shared keys, menus and sheet.
- The narrow-width give-way (spec 4.1) never triggers on the Pixel (it starts below 790 dp); its order is unit-tested only.
- Still open, untouched: the track thread's place, the slider's unfilled track contrast, the empty pad's edge (A11), a playing pad on a muted row (S14).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

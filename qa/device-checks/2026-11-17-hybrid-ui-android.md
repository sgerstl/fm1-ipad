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
| 20 | Long-press a filled pad, an empty pad, a track head and a Timeline block. | A soft white disc grows under your finger; beside it a grey card slides out from the finger and grows in, its rows appearing one after another (quick). Rows have a grey icon, the label and any second line; the current choice is a lighter pill with a ✓; Set pattern… has a ›. No arc, no stalks, no darkening behind. It opens to the left of your finger (Settings › Menus open flips it) and never covers the header. | – | ☐ pass ☐ fail: |
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

**Not covered here** (needs a later round or Scott's call):
- TalkBack: the strip's Pan and Reverb send actions, the minimap's "Show steps 9–16" action, the tabs' selected state. Belongs to the release accessibility pass (rule 6).
- A kit (drum) track on Edit with the panel docked: its lanes still scroll under the panel, as before. 8-step pages are melodic only for now.
- The Timeline's own hybrid changes (pill heads, connected zoom group, pass-count chips) and the Sounds and Projects sheets' row styling aren't built; they pick up only the shared keys, menus and sheet.
- The narrow-width give-way (spec 4.1) never triggers on the Pixel (it starts below 790 dp); its order is unit-tested only.
- Still open, untouched: the track thread's place, Reduce Motion for a playhead glide (no glide built), the slider's unfilled track contrast, the empty pad's edge (A11), a playing pad on a muted row (S14).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

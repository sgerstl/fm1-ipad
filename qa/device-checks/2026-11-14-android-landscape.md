# Device check: claude/android-p2-shell-02c86f, 2026-11-14 — the phone in landscape (decision 28, boards 73–74)

Written by the session that built it (`CLAUDE.md`, rule 2). Scott runs it with the Pixel and the FM-1.

**Setup:** Skiff 2.5.1 on the FM-1 · Lupe Android build from this branch · USB cable · the phone lying on its side.
**Back up first?** Yes for checks 13–16 and 19 (they write steps to the FM-1's pattern). Back up in Lupe › project ⌄ › Projects…, or pick a scratch pattern.
**Note entry** uses P1's intents (`setStepNotes`, `toggleStepNote`, `toggleHit`, `playNote`; P1's aae214f). On the real FM-1 checks 13–15 and 18–19 need P1's branch merged into this one. The phone sends no `playNote` while REC is armed and playing (the FM-1 would record it).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Open Lupe, turn the phone | It stays landscape either way up; never portrait. No status bar (a swipe from the top edge shows it briefly). Nothing sits under the camera or the gesture bar | – | ☐ pass ☐ fail: |
| 2 | Look at the header | One line: project ⌄, Loop ⌄, **Pads · Edit · Timeline** as underlined words, then the readout, Record, Play at the right edge. A hairline under it | – | ☐ pass ☐ fail: |
| 3 | Tap Edit, Timeline, Pads | The white underline glides between the words; the body changes | – | ☐ pass ☐ fail: |
| 4 | Pads: tap a track head; hold it; tap its engine line | Tap selects (white ring, tinted). Hold, or the engine line, opens that track's Sounds sheet | – | ☐ pass ☐ fail: |
| 5 | Tap MUTE on a row | The key turns white with the word on it; the track mutes | – | ☐ pass ☐ fail: |
| 6 | Look at the pads and the foot | About 8 pads across, the rest by a sideways pan; Store scene and all 16 scenes in view | – | ☐ pass ☐ fail: |
| 7 | Hold a pad › Edit steps | The Edit tab opens on that pattern | – | ☐ pass ☐ fail: |
| 8 | Edit, a melodic pattern | 16 steps across in fours (wider gaps between beats); each note large; stronger fill and a taller bar for more velocity; a held note's bar runs across the steps it ties; ◆ on locked steps; the playing step outlined in the track's colour | – | ☐ pass ☐ fail: |
| 9 | With no step tapped | The dials area reads "Sound" + the engine with four round dials (HOME's knobs); the hint by the keys says "Keys play the track" | – | ☐ pass ☐ fail: |
| 10 | Tap step 6 | White ring; "Step 6 ✕", ‹ ›, NOTES · FEEL · SOUND, Lock, and four round dials PITCH MOVE LENGTH VELOCITY | – | ☐ pass ☐ fail: |
| 11 | Slide a dial; double tap it; tap FEEL; tap SOUND | Slides in the setting's direction with the Magnifier; double tap puts it back; FEEL shows CHANCE RATCHET COND NUDGE; SOUND lists the step's locks | – | ☐ pass ☐ fail: |
| 12 | Tap ✕, or the picked step again | The four sound knobs come back | – | ☐ pass ☐ fail: |
| 13 | Step picked, Chord off: tap a key on the strip | That note is written to the step and plays; the key lights in the track's colour | Yes | ☐ pass ☐ fail: |
| 14 | Chord on: tap three more keys, then one of them again | Each adds to the step (root large, the others under it in the cell; "3 of 4" in the hint); the second tap takes it off; a fifth note is refused | Yes | ☐ pass ☐ fail: |
| 15 | No step picked: tap keys; play the FM-1's own keys with a step picked | The phone's keys only play. The FM-1's keys never write the step | Yes | ☐ pass ☐ fail: |
| 16 | ‹ › at the right of the strip | The keys move an octave | – | ☐ pass ☐ fail: |
| 17 | Tap Lane | The keyboard gives way to one automation lane: pick a parameter, drag to draw (each step a lock ◆); over recorded motion it asks first, in place. Lane again brings the keys back | Yes (drawing) | ☐ pass ☐ fail: |
| 18 | Edit, a kit pattern | Lanes down, 16 steps across in fours; tap a cell: a hit goes on or off. Press a lane's name: it plays | Yes | ☐ pass ☐ fail: |
| 19 | Hold a cell | It is picked without toggling (white ring); under the grid "SD · step 5 ✕" and boxes VELOCITY CHANCE RATCHET NUDGE that slide; PITCH and DECAY show "—" (not wired yet) | Yes | ☐ pass ☐ fail: |
| 20 | Press FX on the FM-1 while on Edit | The dials area becomes "FX 1/7 FX" and the page's four dials; the keyboard stays. On MOD or LANES the tiles take the keyboard's place | – | ☐ pass ☐ fail: |
| 21 | Press FX on the FM-1 while on Pads or Timeline; press FX again | A panel the dials' width rises at the bottom right with the header and four dials (full width on a page with tiles); a page step raises it again. It rises and falls, never pops | – | ☐ pass ☐ fail: |
| 21a | Leave it alone; then turn an FM-1 knob; then touch a dial | It falls about 8 s after the last knob turn or touch; a knob turn while it's down brings it back; turning or touching keeps it up | – | ☐ pass ☐ fail: |
| 21b | Swipe down on its header; press HOME on the FM-1; swipe back | Each lowers it | – | ☐ pass ☐ fail: |
| 21c | With the FM-1 resting on a sound page: launch Lupe, unplug and replug, switch tabs | The panel does not rise by itself | – | ☐ pass ☐ fail: |
| 21d | Settings › Labs › SOUND PANEL STAYS: slide it to 12 s | The panel now stays 12 s (2 to 20; double tap puts 8 back). Added 2026-11-14, review 2026-11-28 | – | ☐ pass ☐ fail: |
| 22 | Press GLO, SAVE, SEQ, HOME on the FM-1 | GLO: the Mix sheet rises (two columns of three rows, the bus cards on its other pages). SAVE: Sounds (PRESETS, USER) or Projects (PROJECT). SEQ: the Edit tab (AUTOMATION: its lane; SONG: the Timeline). HOME: sheets close, the tab you had returns | – | ☐ pass ☐ fail: |
| 23 | project ⌄ › Mix…, Projects…, Settings | Each sheet rises and fits the short screen; drag down, ✕ or back closes it | – | ☐ pass ☐ fail: |
| 24 | Unplug the FM-1; plug it back | The lost card and page still read correctly in landscape; reconnecting opens no sheet by itself | – | ☐ pass ☐ fail: |

**Not covered here:** TalkBack, largest text and Remove animations (the release accessibility pass); the Timeline tab's own landscape layout (P4's, behind the same `TimelinePage` call; until P4's branch is merged the tab shows today's page); the FREE TAKE picker in landscape (it takes the whole body; not laid out afresh).

## What I decided, and what didn't fit

- **A sound page's tiles take the keyboard's place** on Edit (MOD, LANES, SOUND, OPERATOR): the dials area has no room for them. The brief said the keyboard stays; it does on every page without tiles.
- **A kit's panel is one row, 76 dp** (the hit's boxes, or the four sound dials with no header, or a sound page with its header beside the dials), so eight lanes keep rows of about 23 dp; six lanes get about 31. Eight lanes are a hair under the 24 dp floor in height.
- **The Lane toggle is on the keyboard's header**, so kits (no keyboard) have no lane view yet.
- **A lane name on a kit plays it while pressed**; holding it for its sound (board note 8, decision 15) isn't wired.
- **Select on Pads is gone** (the board has none): hold › Edit steps picks a pad for the editor and opens the Edit tab.
- **The keyboard's colours** use existing tokens (text2Raised for white keys, panel for black, the track's colour when on the step): there are no keyboard tokens.
- **Dials are 52 dp rings in an 84 × 74 dp target** everywhere now (HOME knobs, step dials, sound pages, the Mix buses), down from 60, to fit the panel.
- **The picked step survives a visit to another tab**; a sound page opening or closing still clears it.
- **Core cleanup:** `Tab` is now Pads, Edit, Timeline; `Divider` and `setDivider` are deleted (two lines in P1's BridgedLupeCore and the fake went with them).

## Decision 29: Scott's first hands-on (2026-11-14)

Built (tests pass, APK builds), **not run on a screen**.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 25 | Tap a track head anywhere, also with a rolling or sliding finger | The track is selected every time, and nothing else happens (no Sounds) | – | ☐ pass ☐ fail: |
| 26 | Hold a track head | A menu beside the finger: Sounds…, Mute, Solo. Solo shows a SOLO pill on the head | – | ☐ pass ☐ fail: |
| 27 | Tap a pad | It launches as before **and** becomes the selected pad, its track the selected track (Edit follows) | – | ☐ pass ☐ fail: |
| 28 | Press a MUTE key and drag down the column; tap one | Every key crossed takes the state the first one changed to, a tick for each; a tap toggles one | – | ☐ pass ☐ fail: |
| 29 | Look at the selected track on Pads | A 2 dp outline in the track's own colour runs round the whole row (head, MUTE, pads); it glides to the next row you select. The selected pad's ring is the track's colour with a dark gap inside. Nothing about a track is white | – | ☐ pass ☐ fail: |
| 30 | Start sliding a dial, then: switch tabs with the other hand; let the sound panel fall; unplug the FM-1 | The Magnifier (the value above the finger) goes away each time and the dial stops being white. Nothing stays stuck | – | ☐ pass ☐ fail: |
| 31 | Look at the header | project ⌄ and the tabs at the left; at the right Loop ⌄, the readout, Record, Play. Play sits fully inside the screen's rounded corner | – | ☐ pass ☐ fail: |
| 32 | Look at the left edge | Content starts about 16 dp from the screen's edge and runs under the camera's hole punch; nothing is held back for it. The gesture bar at the bottom is still clear | – | ☐ pass ☐ fail: |
| 33 | Go Pads → Edit → Timeline and back | Going right the old page slides out left and the new one in from the right; back, the reverse (about 0.28 s). The selected track's coloured outline travels from its Pads row to Edit's step row and fades as it lands. Calm: no bounce | – | ☐ pass ☐ fail: |
| 34 | Remove animations on, switch tabs | A short cross-fade only; nothing travels | – | ☐ pass ☐ fail: |

Chosen or left open:
- **The Timeline's rows** are P4's (`ui/timeline`): the track-colour row outline there, and the travelling outline landing on its row, need P4 to mark the row (`Modifier.selectedTrackAnchor()` is public for that). Until then, going to or from the Timeline slides without the travelling outline.
- **The corner inset** takes the radius Android reports and never goes under 24 dp (at 8 dp Play was cut off). If it is still clipped, say by how much.
- **The hole punch is ignored on whichever side it is** (the phone can lie either way up); with it on the right it would sit near Record and Play.
- **A hold on the head no longer opens Sounds directly**: Sounds… is the menu's first row.

## The waiting outline and the pass display (the iPad's LaunchTrace and TraceOutline), 2026-11-14

Built against the fake (tests pass, APK builds), **not run on a screen**. The data is P1's shapes: the `clock` area (a pulse count with its time, renewed every beat), `launchTick` on waiting entries, rows and scenes, `passTicks` and `passStartTick` on a row, `mutePending` ("none", "mute", "unmute"), `soloPending`, a scene's `waiting`. On the real FM-1 it needs P1's commit merged into this branch.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 35 | While playing (Launch at Bar), tap an idle pad | A faint outline in the track's colour round it, and a line drawn from the top left corner, down the left side first, all the way round as the bar comes; it closes as the pad lands, and never starts again | – | ☐ pass ☐ fail: |
| 36 | Watch the playing pad | Its pass count ("2/4") when it has passes, and the bar along its foot moving smoothly, not in steps | – | ☐ pass ☐ fail: |
| 37 | While playing, tap MUTE on a track | The key's outline is drawn the same way (stronger faint edge) until the mute lands at the launch point; a second tap takes the wait back | – | ☐ pass ☐ fail: |
| 38 | While playing, recall a scene | The scene key's outline is drawn the same way, in white (a scene is global), until it lands | – | ☐ pass ☐ fail: |
| 39 | Join mid-play (start Lupe while the FM-1 plays), then launch a pad | A dashed outline: there is no clock to draw from | – | ☐ pass ☐ fail: |
| 40 | Remove animations on, repeat 35 | Drawn the same: the line grows in place | – | ☐ pass ☐ fail: |

Chosen: on a MUTE key that is already white (muted), the waiting line is dark, since no track colour reads on white; otherwise it is the track's colour. A waiting solo draws its line round the track head (Pads has no solo key). The old dashed border on every waiting pad is replaced by this; dashes now mean "no clock" only.

## The Mix and Sounds sheets step with the FM-1's pages (2026-11-14)

Built (tests pass), not run on a screen.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 41 | Press GLO on the FM-1 five times, about twice a second | The Mix sheet opens on Mixer and steps Delay, Reverb, Chorus, Global with the FM-1, the selector gliding | – | ☐ pass ☐ fail: |
| 42 | Dismiss the Mix sheet, press GLO again | It comes back on the page the FM-1 is now on | – | ☐ pass ☐ fail: |
| 43 | Press SAVE on the FM-1 four times | Sounds on the presets, then its USER list, then nothing (PATTERNS), then the Projects sheet | – | ☐ pass ☐ fail: |
| 44 | Press GLO fast (as fast as you can) and watch the FM-1 | The FM-1 never jumps back a page: the phone sends nothing when the FM-1 changes GLO page (the core's mix area follows by itself; needs P1's commit) | – | ☐ pass ☐ fail: |

## Decision 30: the outline timer, Show graphics, keys left and dials right (2026-11-14)

Built; tests pass and the APK builds. **Seen on my emulator with the fake core** (Pixel-7-sized, 1080 × 2400): Pads, the Edit tab with keys left and dials right, a kit, the waiting outline on a MUTE key, and the dials sliding up over an ARP and an FM6 picture. **Not seen:** the pop-up's reveal on Pads and the Timeline, the Mix pages' pictures, anything on the real FM-1. The picture data (`page.graph`) is the shape from before decision 25, provisional until P1 sends the restored one; the fake draws pictures from the page's own values meanwhile.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 45 | While playing, tap an idle pad | The waiting outline is drawn round it as the launch point comes. (It was there before but hidden: tapping a pad selects it, and the selection ring sat exactly over the outline. The ring now steps aside while the pad waits) | – | ☐ pass ☐ fail: |
| 46 | Settings › Show graphics | A switch, on by default | – | ☐ pass ☐ fail: |
| 47 | Edit tab | The keyboard is on the left, the dials on the right | – | ☐ pass ☐ fail: |
| 48 | On a sound page in Edit, turn a knob on the FM-1, or touch a dial | The dials slide up as a raised card (about 0.3 s) over the foot of the right-hand steps, and the page's picture shows where they were. They settle back about 8 s after the last turn or touch (the Labs hold time). The dials still turn while up | – | ☐ pass ☐ fail: |
| 49 | Change page on the FM-1, or press HOME, while the picture shows | The dials come down at once | – | ☐ pass ☐ fail: |
| 50 | On Pads or the Timeline, with the pop-up up, turn a knob | The pop-up grows and the dials go up with it, the picture under them; then it settles back | – | ☐ pass ☐ fail: |
| 51 | Press GLO; step to Delay, Reverb, Chorus, Global | Each shared page shows its picture over its dials (taps, a tail, a wave, bars) | – | ☐ pass ☐ fail: |
| 52 | Show graphics off; repeat 48, 50, 51 | Nothing slides; dials and tiles only; no Mix pictures | – | ☐ pass ☐ fail: |

Chosen or left open:
- **In Edit the dials slide up over the steps** (the right half's lower part is covered while the picture shows), rather than shrinking the step row.
- **The pictures are read-only.** The handles that turned controls (decision 22) are not restored: the dials are the controls.
- **The picture is 110 dp tall** (76 on a kit). FM6's ALL OPS chart is cramped at that height: operator boxes on two rows overlap.
- **Tile pages** (MOD, LANES) have tiles, not pictures, so nothing slides there. OPERATOR and SOUND show their picture as well as their tiles.
- The SLICES card is not restored (it was words, not a picture).

## The hold menu and the track thread (the two mockups Scott approved, 2026-11-14)

Built; tests pass and the APK builds. **Seen on my emulator with the fake core:** the hold menu on a pad (the circle under the finger, the lines, the choices, Set pattern's second level with "More…"), a tap outside closing it, and the thread resting round Edit's step row. **Not seen:** the drag-onto-a-choice pick, the elastic grow-in in motion, the thread travelling, anything on the real FM-1.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 53 | Hold a pad (about a third of a second) | A filled circle in the track's colour grows exactly under your finger (64 dp, springing past its size and back), no white dot; lines run out one by one from its edge to the choices, each ending in a small node | – | ☐ pass ☐ fail: |
| 54 | Keep the finger down, slide onto a choice, let go | The choice lights (its line goes white, a tick) and is picked in the one gesture | – | ☐ pass ☐ fail: |
| 55 | Hold, let go on nothing, then tap a choice; hold again and tap outside | The menu stays for the tap; outside closes it (choices and lines fade, the circle shrinks out faster than it came) | – | ☐ pass ☐ fail: |
| 56 | Hold a pad near the right edge and near the bottom | The choices open to the left, and stay on the screen | – | ☐ pass ☐ fail: |
| 57 | Hold a pad › Clear, where nothing else uses its pattern | Clear turns into a red-outlined button naming what goes; the others dim; a quick second tap does nothing; a tap after 0.4 s clears | Yes | ☐ pass ☐ fail: |
| 58 | Hold a pad › Set pattern… | A second set of choices in the same place: the kept patterns, the current one ticked, "More…" for the rest | Yes | ☐ pass ☐ fail: |
| 59 | Hold a track head; hold an empty slot; hold a used USER slot in Sounds | The same menu: Sounds…, Mute, Solo; New pattern, Set pattern…; Erase user slot | – | ☐ pass ☐ fail: |
| 60 | Settings › Labs › HOLD MENU · SPRING and · SPEED | Spring 0 is a plain ease-out, 100 the biggest overshoot (default 60); Speed 100 is the mockup's timing (50 to 200) | – | ☐ pass ☐ fail: |
| 61 | Switch tabs | The pages slide in the tab's direction; the selected track's outline in its colour never leaves the screen: it travels from the Pads row to Edit's step row (or the Timeline lane) and lands with the incoming page. Edit's step row keeps the outline at rest | – | ☐ pass ☐ fail: |
| 62 | Settings › Labs › TAB CHANGE · MS | 380 by default, 150 to 700 | – | ☐ pass ☐ fail: |
| 63 | Remove animations on: hold a pad; switch tabs | The menu only fades in and out; the pages cross-fade and the outline cross-fades between its two places | – | ☐ pass ☐ fail: |

Chosen or left open:
- **The Mix row's hold menu is unchanged** (the old menu beside the finger): its rows are sliders (PAN, the reverb send), which the hold menu's pick-and-go choices can't be.
- **The Timeline's block menus are P4's** (`ui/timeline`): `Modifier.tapOrHoldMenu` and `HoldItem` are public for them.
- **More than six choices** go behind "More…" (six fit the screen's height at 56 dp apart).
- **TalkBack** opens the same choices from the item's long-click action, at its centre; each choice is a button.
- The Step ⋯, project, Loop and readout menus open on a tap, so they keep the plain menu.

## Sound pages: the picture from the start, the pop-up's colour, the FX pictures (Scott on ba45c85, 2026-11-14)

Built; tests pass and the APK builds. **Seen on my emulator with the fake core:** the pop-up on FX, DELAY, REVERB, INSERT (OFF), SLICER and DUCK (BY OFF) on track 1's colour, and Edit with DELAY's picture under the dials. **Not seen:** the other five track colours (contrast is computed, in a test), INSERT's other types, a kit's panel, the real FM-1. This replaces rows 48 to 50 above (the dials no longer slide up on a knob turn).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 64 | Show graphics on: press a sound key while on Pads or the Timeline | The pop-up opens with the header, the four dials and the page's picture under them, at once. A knob turn only lights its dial and keeps the pop-up up | – | ☐ pass ☐ fail: |
| 65 | Look at the pop-up on each track (yellow and lime especially) | Its surface is the track's colour, muted (35 % over the page), with a line in the full colour along its top. White text, the grey labels and the dials' coloured arcs all read clearly | – | ☐ pass ☐ fail: |
| 66 | Edit, a sound page with a picture | The picture sits under the dials from the start; the step row is about 88 dp tall instead of about 160 (number, note and a short velocity bar still show). It glides to that height and back on HOME | – | ☐ pass ☐ fail: |
| 67 | Step FX with the FM-1's FX key: FX, DELAY, REVERB, DRIVE, INSERT, SLICER, DUCK | Sends as four sliders; echoes on a beat grid; reflections and a tail (ROOM, SPRING with its coil, HALL twice as long); the drive curve; INSERT's curve and wave by TYPE, or the filter response for FILTR; the sixteen-step slicer pattern; DUCK's box | – | ☐ pass ☐ fail: |
| 68 | Show graphics off | Dials (and tiles) only, in both places; the step row keeps its full height | – | ☐ pass ☐ fail: |
| 69 | A track's EDIT key until VOICE; turn GLIDE up | Words for the mode (POLY: A VOICE A NOTE…), a grey bar (the note before), a ramp in the track's colour to a bar (the note after); the ramp gets longer with GLIDE and its time is written under it | – | ☐ pass ☐ fail: |
| 70 | An FM6 track, EDIT until ALL OPS; step ALGO through 1, 2, 16, 18 (the four-row ones) and 32 (six across), in the pop-up and on Edit | No operator box touches the one above or beside it; the numbers read. On Edit (64 dp) the boxes are small: say if they're too small to use | – | ☐ pass ☐ fail: |
| 71 | FX until DRIVE; turn DIST, change TYPE | A cycle of the wave it makes at the right of the curve, the type's name over it; CRUSH writes its bits and hold | – | ☐ pass ☐ fail: |
| 72 | LFO with Play running; turn RATE, WAVE, FADE | The wave scrolls at its real rate with a dot at now; right after Play, FADE ramps the wave in from flat | – | ☐ pass ☐ fail: |
| 73 | LFO 2: SYNC to 1/4, POLARITY to UNI; then back to LFO | Synced, the wave keeps the song's pace and the caption reads "1/4 at 120 BPM"; UNI sits above the line. The LFO page keeps what LFO 2 last showed. TRIG and ENV SYNC change nothing in the picture (see the note) | – | ☐ pass ☐ fail: |
| 74 | Reduce Motion on (Android: Remove animations), LFO page | The still two seconds from the restart, no scrolling | – | ☐ pass ☐ fail: |

Rows 69–74 (2026-11-14): seen on the emulator against the fake core only (VOICE, ALL OPS at algorithm 1 in the 110 dp pop-up, DRIVE, the LFO scrolling); not on a Pixel or a real FM-1. What the live LFO can't know yet: the FM-1 restarts a NOTE-triggered LFO on a fresh phrase and the phone isn't told, so the restart is Play (pulse 0), or when the picture first showed while stopped; TRIG therefore changes nothing here. ENV SYNC is the envelopes' setting (ATTACK, DECAY, RELEASE as note values), not the LFO's, so it doesn't change this picture either. The LFO page only knows SYNC and POLARITY after LFO 2 has been shown once for that track.

Sizes (Pixel 10 Pro and Pixel 7 are both about 411 dp tall in landscape, so the same): the pop-up is 252 dp tall with a picture (134 without); Edit's step row is about 88 dp with a picture, about 160 without. A kit keeps its one-row panel: its picture sits beside the dials where the hint text was, and gives way to tiles on a tile page.

### Which page gets which picture (Skiff 2.5.1)

FX family, checked page by page (the core's `graph` first; where it sends none, the phone now makes the picture from the page's own four knobs):

| Page | Before | Now |
|---|---|---|
| FX | sends, right | unchanged |
| DELAY | **none** | echoes on the beat grid. The bus's MIX and DELAY MODE aren't in the page area: MIX is taken as full, MODE not shown (asked P1) |
| REVERB | **none** | reflections and tail by TYPE, SIZE, DAMP, as loud as the send |
| DRIVE | the curve, right (the wave beside it is still not drawn) | unchanged |
| INSERT | **none** | by TYPE: the transfer curve and the wave for SOFT HARD FOLD FUZZ CRUSH, the sweep for PHASR FLANG CHOR, the filter response for FILTR. Its MIX (the PRESETS encoder) isn't in the page area: taken as full (asked P1) |
| SLICER | **none** | the sixteen-step pattern, GATE's depth or STUT's hatching |
| DUCK | **none** | the box only: the source track's hits aren't in the page area, so no dips can be drawn yet (asked P1) |

The other families, reported, not fixed:

| Family | Right | Missing or wrong |
|---|---|---|
| ENV | ENV, ENV 2 | – |
| LFO | LFO, LFO 2 (a two-second sweep, not the FM-1's live clock; FADE not drawn); MOD is tiles | – |
| SEL | SCALE | CHORD (the chord on the keys, or strummed), FOLLOW: no picture |
| EDIT | ANALOG's EDIT 1 and EDIT 2; FM6's OPERATOR and ALL OPS (ALL OPS is cramped at this height); DRUM-X's SOUND rows | every other engine's EDIT 1 and 2 (the iPad draws a scope); VOICE and VOICE 2; SAMPLES; SLICES (it was a card of words, not restored); LANES and LANE MIX are tiles only |
| ARP | ARP, ARP 2 | – |

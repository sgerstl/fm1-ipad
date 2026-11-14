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

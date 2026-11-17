---
component: Track head
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/PadsTrackStrip.swift  # TrackStripCard, TrackStripRow, PhonePadHead, BigTrackChip, HeadKeySurface, SoloKey, EntryTitle, SoundName/SoundNameKey, SmoothBar
  - ios/FM1/Overview.swift        # TrackChip
  - ios/FM1/TrackMenu.swift       # TrackMenuLayer, TrackMenuPress (the hold)
  - ios/FM1/PadsPage.swift        # where heads are placed; lanes(), LaneShape behind them
  - ios/FM1/ArrangeLane.swift     # the Timeline's lane heads (card or row by lane height)
  - ios/FM1/MixerPanel.swift      # the Mix strip's head (TrackStripRow)
  # Android, on branch claude/android-p1-core-link-faf639 (not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/PadsPage.kt   # RowHead, MuteColumn, the selected row's outline
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/HoldMenu.kt   # the radial hold menu the head opens
boards: [41, 43, 46, "design/boards/heads.py", "design/boards/lanes.py", "design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=11-64     # heads
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=11-155    # heads
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=8-176     # heads
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=9-26      # Track badge
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=9-61      # Track key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=12-136    # Track chip
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=11-160    # Lane
---

# Track head

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

> **Under revision (2026-11-14), phones only:** decisions 29 and 31 (vault `phone-skiff-decisions-2026-11-12.md`) make Android's head the keeper on both phones, and the iPhone's selected-row tint the keeper for selection. Build plan: vault `phone-consolidation-build-plan-2026-11-14.md`, rows "Track heads" and "Selected track". What changes:
> - **iPhone:** `PhonePadHead` (number key and speaker) is replaced by Android's head: a colour block with the number, the sound's name, the engine under it, and a MUTE key with the word on it. A tap on the head selects the track and does nothing else; a hold opens the track's menu; a swipe up or down the MUTE column paints every key it crosses to the first key's new state (decision 29). Waiting mutes get the outline timer (the iPad's `LaunchTrace`).
> - **Android:** keeps its head; adds the iPhone's selected-row tint, the track's muted colour under every square of the row (decision 31).
> - **Both:** the head's hold menu takes Android's radial styling with the iPad's full option set (decision 31); the track controls box goes, so nothing on a phone head opens it (decision 31).
> - `[open]` Decision 29's 2 dp outline round the selected row: decision 31 says it "stays for the timer" and the build plan says Android "keep the outline for the timer". Does the row outline stay beside the tint, or does only the waiting outline (the timer) remain?
> - `[open]` Solo on the phones: Android has no Solo key; Solo is in the hold menu and shows as a SOLO pill on the head. Decision 31 doesn't name Solo. Confirm.
>
> Section 1 below is what's built now.

## 1. Requirements

### Purpose and scope

The head at the start of each track's row: which track it is, what it plays, its sound, and its mute and solo. It is the way to select a track (and with it the editor and the FM-1's knobs), and a row's mute is its stop (structure map, "Pads as a grid"). One set of heads serves Pads and the Timeline (Scott, 2026-11-09, comment in `ArrangeLane.swift`), and the Half head starts each Mix strip (Scott, 2026-11-10, comment in `MixerPanel.swift`).

Where it sits: `design/structure-map.md`, "Pads as a grid" (Row heads) and "The phone with a Skiff FM-1" (Pads › Row heads).

### Anatomy

Names as in the code. Forms: **card** = `TrackStripCard` (No grid on Pads; Timeline lanes at least `cardHeads` tall), **row** = `TrackStripRow` (Half on Pads; short Timeline lanes; Mix strips), **phone** = `PhonePadHead` (iPhone landscape). Android's is `RowHead` plus `MuteColumn`.

- **badge** (`BigTrackChip`): the track number in a square of the track colour. Large on the card, small on the row and phone.
- **entry title** (`EntryTitle`): the entry the track is on, letter then pattern number, as a pad writes it. Card only.
- **plays line**: what it's on and its pass ("pass 2 of 4", "looping"). Card (without chips): the pass; row: the entry ("B · 05").
- **sound name** (`SoundName`, drawn by `SoundNameKey`): the track's sound, drawn only (no chevron, no tap of its own since 2026-11-15).
- **pass bar** (`SmoothBar`): progress through the playing pass.
- **preview line**: where a held scene would send this track ("→ B · 05 · muted"), with a dashed outline round the head.
- **effect chips** (`ChipView`, `MoreChips`): the track's ARP, CHORD, SCALE, SLICER, DUCK, FOLLOW. Card: up to three stacked, then "+N"; row: the count only.
- **Mute key** (`muteKey` on the card, inline on the row and phone; surface `HeadKeySurface`): speaker or struck speaker.
- **Solo key** (`SoloKey`): "S". Card and row only.
- **lane** (`LaneShape`, `PadsPage.lanes`): the shape behind the head and its pads; a tag behind the head joined to a band under the pads. Drawn by the page, not the head.
- **track chip** (`TrackChip`, `Overview.swift`): the small number chip used outside the heads (editor header, Mix, menus, pickers). Listed here because it shares the badge's job.

### Requirements

**Functional**
- **F1** Every track has one head per row, on Pads (No grid, Half), the Timeline and Mix. At Max on Pads there are no heads; the editor header's track menu picks the track.
- **F2** The card shows the badge, entry title, pass words (when there are no chips), sound name, pass bar while playing, preview line while a scene is held, chips, and Mute over Solo.
- **F3** The row shows the badge, sound name, what it's on (or the preview), a pass bar while playing (blank space when not, so the row doesn't jump), the chip count, Mute and Solo side by side.
- **F4** The phone shows the badge and Mute only; the name and what it plays are VoiceOver's (structure map, phone Pads: "No name; VoiceOver reads it").
- **F5** Heads keep one width at every divider position, so pads keep theirs and only get shorter (Scott, 2026-11-09; device check `2026-11-09-perform-grid-map.md` 15).
- **F6** On the Timeline, a lane at least `cardHeads` tall gets the card; shorter, the row. With a section picked, the lane head shows the section's note in the older one-line head (`legacyCompactBody`).
- **F7** On Mix without Skiff's song (older firmware), the strip shows its own name and MUTE instead of this head.

**States**
- **S1** Selected (iPad): no look of its own on the head; its lane takes the selection tint and grows into the gaps round the row (`PadsPage.lanes`). On the row form, the name turns semibold in the primary text colour.
- **S2** Selected (phone): the badge gets a ring in the text colour.
- **S3** Muted: the badge loses its fill and becomes an outline in the track colour, the number in the track colour; the Mute key is pressed in (lit, inner shadow) with the struck speaker; on the card the sound name dims.
- **S4** Mute waiting (playing): the key's icon already shows the target state and the waiting trace (`LaunchTrace`) draws round it until the launch point; light on the flat key, dark on a lit one (Scott, 2026-11-10, comment on `HeadKeySurface`).
- **S5** Solo on: the Solo key lit amber and pressed in.
- **S6** Solo waiting: the trace round Solo until the last of the mutes it staged lands (`store.soloWaiting`).
- **S7** Playing: the pass bar fills in the track colour; card and row.
- **S8** Scene held: the preview line in place of (row) or under (card) what it plays, and a dashed outline round the head; only for scenes Lupe has seen.
- **S9** No list read: the entry title shows "–", the plays line "—".
- **S10** Not on an entry: "On no entry" stopped, "Quiet" playing.
- **S11** Offline: Mute and Solo disabled. The head still selects.
- **S12** Pressed keys sink (`PressSink`).

**Behaviour**
- **B1** Tap anywhere on the head (card padding included) selects the track: the editor and the FM-1's knobs follow. No dead spot (Scott, 2026-11-09; device check `2026-11-09-perform-grid-map.md` 14).
- **B2** A tap anywhere on the head selects the track and nothing else, on the iPad as on the phones; the Sounds panel is the hold menu's Select sound, and VoiceOver's "Sounds" action (Scott, 2026-11-15: "when I go to select a track on the iPad, it always hits the sound selector panel"; it was the sound name's own tap, 2026-11-10).
- **B3** Hold the head: selects the track and opens the track menu at the finger, a fan in the track's tint (Scott, 2026-11-09: "the track header longpress should get the same treatment"). Hold time: Settings › Touch, `holdToMenu`.
- **B4** Track menu, in groups: Select sound; Record sample… (synth tracks, when the firmware has samples); Clear motion (N steps), when there is motion; Clear all pads (destructive, confirm in place); Clear pattern NN's steps (with Undo).
- **B5** Clear all pads is off when there are none, or when the list can't be rewritten (it says why, "stop first" while playing).
- **B6** Double-tap the head (iPad, Pads and Timeline): selects it and shows or hides the track controls under its selected pad (device check `2026-11-09-perform-grid-map.md` 18).
- **B7** Mute: PERFORM's mute, staged to the launch point while playing, at once while stopped. Tapped again while waiting, the waiting change is taken back.
- **B8** Solo: Lupe's, made from PERFORM's mutes; mutes every other track, and off again the mutes come back as they were.
- **B9** The card switches to the row (and back) as the divider moves, the two crossfading in one place so the change rides the divider's spring.
- **B10** Chip tapped: opens that effect's place (`TrackChips.open`); "+N" opens a menu of the rest.

**Content**
- **C1** The badge is the track number, 1 to 6, on every head.
- **C2** Plays words: "pass p of r", "looping", "On no entry", "Quiet".
- **C3** Preview words: "B · 05 · muted", "stays on B · 05", "no entry", "no entry · muted".
- **C4** Track menu title: "Track 4 · Drum Kit".
- **C5** Clear-all confirm names the count and any patterns erased: "Clear all 5 pads on T4 Drum Kit, erasing pattern 07".

**Accessibility**
- **A1** Head label: "Track n, Name". Value: what it plays, then what's next (card), or what it plays plus ", the scene would: …" (row, phone).
- **A2** Selected is a trait, not words in the label (accessibility F2, 2026-11-10; device check `2026-11-10-accessibility.md` 4).
- **A3** Mute: label "Mute track n", toggle trait, value "playing" / "muted" / "mutes …" / "unmutes …"; every row says its own track number (accessibility F8; device check `2026-11-10-accessibility.md` 3).
- **A4** Solo: label "Solo track n", toggle, value on/off, hint saying the mutes come back.
- **A5** Sound name: "Sound, Name", hint "Opens the sounds for track n".
- **A6** The hold has a non-hold way in: the "Track menu" action. The double-tap has one: "Show / Hide track controls" (accessibility F11; device check `2026-11-10-accessibility.md` 7).
- **A7** Reading order: each head, then its pads, row by row (`accessibilitySortPriority`).
- **A8** Nothing by colour alone: the number names the track, muted has the struck speaker and the outlined badge, solo the pressed-in key, waiting the trace (accessibility README, colour table).
- **A9** Targets: the card's keys and the row's (accessibility P14) and the phone's Mute are under 44 pt but over the 24 pt floor; accepted exceptions. The sound name's touch area is padded round the words.
- **A10** Reduce Motion: the lane's change shortens; the badge, keys and trace use short fades only. `[review]` Not walked with Reduce Motion on.
- **A11** `[review]` The card's hint ("Selects it: the editor and the FM-1's knobs follow") isn't on the row or phone forms (the phone says "Selects the track"). Intended?
- **A12** `[open]` Half's head clips its entry at default size ("A · R…", accessibility P10). Not fixed.

**Integration**
- **I1** Mute is `performOp(.mute(track:))`, PERFORM op 3; the row's stop. The track keeps its place and comes back in time.
- **I2** Solo is `SkiffSongStore.toggleSolo`, staging mutes on the other tracks; there's no firmware solo.
- **I3** Selecting sends the FM-1 the track select; launching a pad never does (see `pattern-pad.md` I1).
- **I4** Mute and solo state come from `store.perform` (falling back to the session's track mute); passes from the MIDI clock. Words refresh twice a second; the pass bar per frame.
- **I5** Clear all pads rewrites the list empty and needs Lupe stopped (`store.blocked`).

### Ruled out

- A "Then B" line on the card: the head stops at the tag's height, and the pads mark the next entry (code comment, `PadsTrackStrip.swift`).
- Selected as words in the head's label: a trait instead (2026-11-10, accessibility F2).
- A bold sound name on the card: "too bold" (Scott, 2026-11-09).
- Mute on Mix's strip foot: the head's Mute replaces it (Scott, 2026-11-10).
- On the phones, a tap on the head reaching Sounds: taps were landing on Sounds, so sounds moved to the hold menu (decision 29, 2026-11-14).
- On the iPad too, a tap on the sound name reaching Sounds: taps meant to select landed on it (Scott, 2026-11-15).

### Out of scope

- The pads on the row, their tint and the track controls hanging from the selected pad: see `pattern-pad.md`.
- The editor header's track key and track menu at Max: see `pattern-editor.md`.
- The scene row and held-scene recall: see `scene-row.md`. This document covers only the head's preview line (S8).
- Timeline lanes' blocks and the non-Song-tab lane head (`fullBody`, `MuteChip`): see `timeline.md`.
- The fan menu's look and motion: `Menus.swift`, `DESIGN.md`.
- SLOOP's track heads (unstaged mute): not covered here.

## 2. Design

Boards: 43 (the head H1, mute and solo; `design/boards/heads.py`), 41 (lanes; `design/boards/lanes.py`), 46 (chips on the head), `design/boards/phone-consolidation.html` rows 2 and 3 (phone keepers).

Particular to the head:
- No background of its own; the lane behind it carries the selection tint, one colour with the pad's tint and track controls (comment in `PadsPage.lanes`).
- Mute and Solo flat when off, pressed in when on, so the page stays flat (board 43).
- A muted badge keeps its number readable as an outline rather than going grey (board 43).

### Decision log

- 2026-11-09: H1, the number big top left, the entry beside it, the name under, Mute over Solo down the right (Scott, board 43).
- 2026-11-09: one set of heads for Pads and the Timeline (Scott).
- 2026-11-09: the whole head selects, padding too (Scott).
- 2026-11-10: the sound name with a chevron is the visible way into Sounds (Scott).
- 2026-11-15: the iPad's heads (Pads, Timeline, Mix strips) do as the phones': a tap selects, the hold menu has Select sound; the chevron goes (Scott).
- 2026-11-10: waiting mutes and solos get the pads' waiting trace (Scott).
- 2026-11-10: effect chips stacked between the words and the keys, three then "+N" (Scott, board 46).
- 2026-11-14: phones take Android's head; taps select, holds open menus; mutes paint (Scott, decisions 29 and 31).
- 2026-11-14: phones show selection as the track's muted colour under the row (Scott, decision 31).

## 3. Build notes

- `.android` hybrid look (branch `hybrid-ui-android`, 2026-11-17; spec 3.2): the head is a pill on `control`; selected, the track's tint with a 2 dp edge in its colour, and the 30 badge squares off from round on the spring (`TrackBadge` in `MixPage.kt`, shared with the Mix strips). Mute is a pill with the word "Mute" (spec keeps the word). The row band behind the selected row and the travelling thread are untouched (the thread's place is `[open]`, spec 7).

- `SoundName` is laid out hidden inside the head's button and drawn on top by `SoundNameKey` through an anchor preference; since 2026-11-15 it takes no touches, so the head's button gets every tap and its hold.
- `TrackMenuPress` selects the track as the hold fires, then places the menu at the press point in `AppView.space`.
- The Mute key on the row form has no countdown in its accessibility value ("mutes at the launch point"), while the card's says the countdown. The phone's `HeadKeySurface` gets no `left:` closure, so its trace has no time to draw against; checked in code only.
- `TrackMenu.swift`'s doc comment says "Sounds…" first; the item is "Select sound".
- The accessibility README's colour table (2026-11-10) still describes waiting as "dashed white edge and the countdown"; the trace replaced it the same day.
- Android differs in ways the consolidation must settle: Mute's label is "Mute ‹sound›" with no track number (the iPad added the number because two tracks can share a name, accessibility F8); the head's menu holds Sounds…, Mute, Solo, none of the iPad's clears.

### Decision log

## 4. Usage

- To select a track, use its head; a pad on another row launches without selecting (`pattern-pad.md` B5).
- A new place that lists tracks with mute should reuse `TrackStripRow` (as Mix did) rather than draw its own head.
- For a small track marker with no mute (headers, menus, pickers), use `TrackChip`, not `BigTrackChip`.

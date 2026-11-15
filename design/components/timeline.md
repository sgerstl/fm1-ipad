---
component: Timeline
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, the arrange spec and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/SkiffArrange.swift        # SkiffArrangePage: tool row, ruler and lanes, sections, keyboard, pin
  - ios/FM1/ArrangeLane.swift         # Ruler, Lane: blocks, the reps grip, hold, carry, release, open
  - ios/FM1/ArrangeBlocks.swift       # BlockView, BlockShape, ChainDividers, SongPlayhead, the REST accordion
  - ios/FM1/ArrangeCompact.swift      # LaneMarks (pass badge, next, END, waiting trace), SongModeKeys, the lane tab
  - ios/FM1/ArrangeSections.swift     # SectionBar
  - ios/FM1/ArrangeDrag.swift         # PassBar, HoldRecognizer, MoveSpot, DropSpot (a pattern from the drawer)
  - ios/FM1/ArrangeMenus.swift        # the block menu and the lane-end add menu
  - ios/SloopKit/Sources/SloopKit/SkiffSongStore.swift   # rewrites, refusals, undo, blocked(track:to:)
  - ios/SloopKit/Sources/SloopKit/SkiffSong.swift        # ListRewrite: what needs a stop
  # Android, on branch claude/android-p1-core-link-faf639 only (not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/timeline/TimelinePage.kt
  - android/app/src/main/java/com/scottgerstl/lupe/ui/timeline/TimelineView.kt
  - android/app/src/main/java/com/scottgerstl/lupe/ui/timeline/TimelineDrag.kt
  - android/app/src/main/java/com/scottgerstl/lupe/ui/timeline/TimelineModel.kt
  - android/core/Sources/PhoneCore/P6Areas.swift
  - android/core/Sources/PhoneCore/P6Intents.swift
boards: [19, 20, 48, 76, "design/boards/timeline.py", "design/boards/phone-timeline-pads.html", "design/boards/phone-consolidation.html (row 11)"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-310   # Timeline block
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-311   # Ruler
---

# Timeline

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

*The Song page's Timeline view on the iPad (`SkiffArrangePage` with `compact` set). The older full Arrange page shares the code and keeps its own look (solid blocks, an inspector, a white selected ring); it is not covered here.*

> **Under revision (2026-11-14):** the phones get a Timeline. Decision 33 picks **Android's Timeline** for both phones ("the iPhone has none"), and decision 28 put it in landscape with time running across, replacing decision 6's portrait "time down". Android has it built (branch `claude/android-p1-core-link-faf639`); the iPhone gets it new, "reusing the iPad's arrange views where they fit" (vault `phone-consolidation-build-plan-2026-11-14.md`, Timeline row), with a design pass at the iPhone's size first (same note, Order 1; board 76 draws it, its edit state not shown). Section 1 below is the iPad as built. The Android keeper as built, from its code: six rows in the Pads' order with compact heads (tap selects); about 12 bars across, pinch or − + between about 8 and 16, one finger pans, ‹ › pan without a drag; blocks in the track colour with the pattern number, REST dashed; tap selects (a white ring and a grip), a selected block drags along its row to reorder and by its grip to set REPS; hold opens the radial hold menu (Set pattern, Passes, Duplicate, Insert before, Select sound, Delete asked in place, Chain or Split); holding the lane past the last block adds; the selected row carries the 2 dp track-colour outline (decision 29); the view pages to keep the playhead in. While playing, Android refuses every change to the order with a strip on the ruler and Stop, which is stricter than the iPad (B21–B23).

## 1. Requirements

### Purpose and scope

The song as time: one lane a track, one block an entry, as wide as it plays, entries back to back. It is where a song gets ordered and repeated, and where a FREE TAKE lands to be chopped (batch list 4). On the iPad it is the Song page's other view, swapped with Pads by the top row's tabs, with the pattern editor under the divider. Where it sits: `structure-map.md`, "Tabs".

It is not a launcher (Pads is), not the pattern editor, and not a free-placement arranger: Skiff has no free placement, a gap is a REST entry (`skiff-arrange-spec.md`, Rules).

### Anatomy

Names as in the code.

- **tool row**: Undo (only after a change), the lanes-apart warning, Patterns, zoom. Its "Song · N bars" words are off on the Song tab.
- **ruler** (`Ruler`): bar numbers every four bars; also the place to drag a bar range.
- **lane** (`Lane`): one track's row: a tag behind its head joined to a band under its blocks (`LaneShape`, the Pads' lane).
- **head**: the track head drawn in the lane (see Out of scope).
- **block** (`BlockView`, `BlockShape`): one entry, or a chain of entries, on its lane.
- **chain dividers** (`ChainDividers`): a line at each part of a chain, every pass.
- **picture** (`PadThumb`): the block's pattern drawn small, where there's room.
- **marks** (`LaneMarks`): the pass badge, the next outline, END, the waiting trace.
- **pass bar** (`PassBar`): progress through the pass, under the playing block.
- **playhead** (`SongPlayhead`): one line through every lane.
- **reps grip**: the block's right edge, dragged for REPS.
- **grid view box**: on the block the editor shows, the bar the grid shows; dragged, the grid follows.
- **landing place**: a dashed outline where a carried block would land.
- **drop line** and **ghost**: where a pattern dragged from the Patterns drawer goes.
- **section** (`SectionRange`) and **section bar** (`SectionBar`): a bar range across every lane and the bar that acts on it.
- **lane end**: the empty lane after the last block; a tap there adds.
- **lane tab**: the open-controls tab on the selected lane (the track controls belong to the pattern pad's CRD, B21).

Words to retire, used for the same things elsewhere: "queued" and "staged" for waiting; "Arrange" for this view on the Song tab; "repeat count" for REPS where the user reads it (the block says ×N, menus say "Play once more").

### Requirements

**Functional**
- **F1** A block is one entry, or a chain drawn as one block across its entries. Its width is its pattern's length times REPS, in bars.
- **F2** Blocks sit back to back from bar 1; there is no free placement. A gap past the end is held by REST passes.
- **F3** Bars across: the zoom, or by default at least 8 and the song rounded up to the next four with room after it.
- **F4** Lane height follows the divider: the space above the editor shared by six lanes, never under the minimum. Tall lanes get the full head, short ones the one-line head.
- **F5** A block keeps its view when it moves (keyed by what it plays, not its entry number), so it slides to its new place instead of changing in place.
- **F6** Undo is Lupe's own: the lists before the last change. Skiff's undo covers the FM-1's own edits only (`skiff-arrange-spec.md`, Rules).
- **F7** Lanes that end on different bars show "Tracks end at bars a–b, so they loop apart" (strip under the top row on the Song tab; device check `2026-11-09-perform-grid-map.md` 57).

**States** (the Song tab's toned blocks; Scott, 2026-11-10, board 48 A)
- **S1** Resting: a tint of the track colour with a track-colour edge; the label in the light text, the count in the raised secondary.
- **S2** Playing: the solid track colour, the text in `onColour`. Other blocks stay tinted; nothing dims.
- **S3** Selected, not playing: the control grey with the track-colour outline inside and elevation 2, as the selected pad.
- **S4** Selected and playing: solid colour with the track-colour outline outside, on the lane.
- **S5** REST: a dashed outline in `restDash`, no fill, "REST" (a one-line lane shows "–").
- **S6** Linked copy (names the selected block's pattern): a dashed inner ring.
- **S7** Chain: dividers at each part, every pass; the label "05→06", the sub-line "chain ×2".
- **S8** Own sound: the top-right corner cut and a waveform mark; the sound's name in the sub-line where there's room.
- **S9** Held, or its menu open: elevation 3 with a slight grow; no playing mark while held.
- **S10** Carried: faint in its own place until it would move, then a dashed landing place where it would go; the block itself follows the finger exactly.
- **S11** Waiting: the waiting trace in the track colour round the block, closing as it lands. No countdown numbers (2026-11-10, board 48).
- **S12** Next (Play song, Play once): a faint ring; a wrap mark when next is the first block again.
- **S13** Playing pass: a badge "2/4", or the repeat mark when looping; END on the last block in Play once.
- **S14** Loop entry (SONG OFF): every block says ↻ in place of ×N, playing or stopped (Scott, 2026-11-06).
- **S15** The edited block: the grid view box over the bar the editor shows.
- **S16** Pass bar: under the playing block, filling once a pass, also on a lane that loops sooner than the song.
- **S17** Playhead: hidden when stopped; running, one line through every lane, wrapped at the song's end.
- **S18** Section: the range lit on the ruler, a bracket over it on each lane, and each track's note of what the section does there.
- **S19** Offline: no hold, no menu items, no Undo.
- **S20** Text by lane height: one line "B · 05 ×2" on short lanes; on tall wide blocks the letters, the label, the sub-line and the picture; on narrow blocks the label and count stacked.

**Behaviour**
- **B1** Tap a block: selects it, and the editor below follows it (pinned). Stopped, the track also goes to that entry (LIST op 3) so it's the pattern Skiff edits. Playing, nothing is sent (it would launch).
- **B2** Double-tap a block: opens its pattern in the editor. Playing, on an entry the track isn't on, it refuses: "Stop to open this entry's pattern: playing, the FM-1 would launch it", with Stop.
- **B3** Hold a block (still, about 0.4 s): it lifts and the lanes stop scrolling. Let go without moving: its menu at the finger. Drag: moves it. A press that moves first is a scroll.
- **B4** Block menu, in order: Edit pattern; Make unique (names the new number, or ": all 64 taken"), Duplicate after; Move earlier, Move later; Split the chain or Chain into next; Select sound; Delete entry (Delete entries on a chain).
- **B5** Select sound opens the sound panel for that entry, not a submenu (Scott, 2026-11-08).
- **B6** Move: the block goes before the first other block whose middle is past the finger; past the end, after REST passes that hold the gap. A full track (16 entries) refuses with the reason.
- **B7** The reps grip: a drag from touch-down sets REPS a pass at a time, 1 to 16, with a live "×3 · 6 bars" label; later blocks move. A tap on it is a tap on the block; held still, it lifts the block.
- **B8** Tap the lane end: the add menu at the finger: Repeat NN again, New empty pattern (": all 64 taken" when full), Rest, Pick a pattern….
- **B9** A pattern dragged from the Patterns drawer drops at the nearest pass edge, splitting a repeating entry where needed; the words say where and what moves ("Drop on T5: a new entry C at bar 13, C–E move 1 bar later").
- **B10** Drag along the ruler: a bar range across every lane. A tap on the ruler clears it.
- **B11** Section bar: "Bars 5–8", First bar and Last bar steppers, Duplicate after (the view's one primary), Clear, and for each track whose passes can't meet the range "Snap to its passes" or "Leave it out"; Cancel.
- **B12** A change that would erase a pattern nothing else uses asks first, in place at the finger (2026-11-10: no system dialog).
- **B13** Drag the grid view box: the grid follows bar by bar. A tap on it is a tap on its block.
- **B14** Double-tap a head: the track controls in or out, shared with Pads.
- **B15** A rewrite draws at once, then goes to the FM-1 one request at a time and is reconciled; a refusal puts the old state back and says why where it was tried.
- **B16** Keyboard: arrows move between blocks and across lanes at the same time, + and − set REPS, ⌥← ⌥→ move the block, Delete deletes, Return opens, Escape clears the selection or the section, ⌘Z undoes.
- **B17** A hold gives a medium haptic.
- **B18** Pads ↔ Timeline: the two slide past each other, the editor staying put (device check `2026-11-09-lupe-batch-2026-11-06.md` 19).

**The lock while playing**
- **B19** Playing, a rewrite is refused before anything is sent when it clears an entry ("Stop to rearrange: Skiff clears an entry only while stopped") or sets another pattern on the entry the track is playing ("…would launch it"). Other rewrites, REPS and sounds included, go while playing.
- **B20** Playing, on a track resting on a REST or an empty entry, a rewrite that puts a pattern there is refused ("Stop to rearrange: T n is on a rest, and Skiff would launch what goes there").
- **B21** A refusal shows on the strip under the top row, with Stop when stopping lets it through.
- **B22** `[open]` The arrange spec (2026-11-05) proposed "rearranging needs the transport stopped" except REPS ahead of the playhead and sounds, marked `[speculative: Claude]`. The iPad builds the narrower rule above; Android refuses every order change while playing. Which rule do all three keep?
- **B23** `[open]` A move or REPS change on blocks behind the playhead while playing: allowed by B19, never device-checked. Does it shift what's playing?

**Content**
- **C1** Block label: the pattern number, a chain "05→06", a REST "REST"; the count ×N or ↻.
- **C2** Spoken state words match the pad's (`pattern-pad.md` C1): playing, looping, pass p of r, next, the last.
- **C3** Refusals say why and what to do; a full track: "Play one entry more times, or chain two, to free a slot".
- **C4** Menu items that can't run say so in the item (": all 64 taken").

**Accessibility**
- **A1** Each block is a button: "T1 Drums, entry B, pattern 02, 8 times, bars 5 to 12, also on entry D", then its sound, then its playing state ("pass 2 of 4", "next, back to the start", "queued, starts at the next bar"). "1 time" reads "1 time", not "once" `[review]` (the pad says "once").
- **A2** The selected block carries the selected trait.
- **A3** Custom actions cover every gesture: Edit pattern, Play once more, Play once less, Duplicate after, Move earlier, Move later, Delete entry. The grip is hidden; its actions do its job (WCAG 2.5.7).
- **A4** The ruler is an element "Bar ruler" with a value ("bars 1 to 4 selected") and a "Select bars" action that starts a four-bar range for the steppers to move (WCAG 2.1.1; device check `2026-11-10-accessibility.md` 6).
- **A5** The lane end is a button "Add to track n".
- **A6** Lanes are containers named "Track n Name". The marks, the playhead and the pass bar are hidden; each block says its state.
- **A7** The keyboard shortcuts sit on hidden zero-size buttons, out of the VoiceOver tree and the Tab order (device check `2026-11-10-accessibility.md` 22a, 22b).
- **A8** Nothing by colour alone: playing has the solid fill, the badge and the words; selected the outline, the elevation and the trait; waiting the trace and "queued".
- **A9** Reduce Motion: no grow on a held block, no slide; the play fade follows Labs `padPlayFade`; the pass bar steps four times a second.
- **A10** `[open]` Not verified with VoiceOver on the device: 22b in `2026-11-10-accessibility.md` is unticked, and the lane tab's VoiceOver line in `2026-11-09-perform-grid-map.md` 59 was "Not tried".
- **A11** The grip draws small with a 36 pt hit area 8 pt past the edge (the arrange spec asked for 44). `[review]`

**Integration**
- **I1** Lists are LIST2 per track; every change is a rewrite (`ListRewrite`): SET, REPS, CHAIN, SOUND and CLEAR ops, patterns named before clears so a moved pattern isn't erased.
- **I2** Requests go one at a time; the store is busy while they go and every edit waits.
- **I3** SET takes only a kept pattern or a REST; an empty pattern is refused with "Make one with New empty pattern instead".
- **I4** Song mode is LIST op 6: Loop entry, Play song, Play once, in the top bar (`SongModeKeys`), not on the Timeline.
- **I5** Positions come from the counted MIDI clock; the marks read at 4 Hz, the playhead at 30 fps, the waiting trace per frame.
- **I6** FREE TAKE lands here with its block selected (batch list 4; device check `2026-11-11-skiff-2.5.1-support.md` 10).

### Ruled out

- Every block in full track colour: at rest a tint with an edge, full colour only while playing (Scott, 2026-11-10, board 48).
- Dimming what isn't playing: dropped once resting blocks were tinted (code comment, ArrangeBlocks.swift).
- Countdown numbers on a waiting block: the traced outline, as on the pads (2026-11-10, board 48).
- A white ring for the selected block on the Song tab: the Pads' track-colour outline (board 48 A).
- "Song · N bars · N tracks" beside the switch on the Song tab: it blurred into it (Scott, 2026-11-07).
- A sound submenu on the block: Select sound opens the sound panel (Scott, 2026-11-08).
- System dialogs for confirms: in place at the finger (`DESIGN.md`).
- Free placement: Skiff plays entries back to back (`skiff-arrange-spec.md`).
- Portrait "time down" for the phone's Timeline (decision 6, 2026-11-13): replaced by landscape, time across (decision 28, Scott, 2026-11-14).

### Out of scope

- Track heads in the lanes (number, name, Mute, Solo): see `track-head.md`.
- The pattern editor under the divider and its divider positions: see `pattern-editor.md`.
- The track controls box and its tab: the pattern pad's B21 (`pattern-pad.md`).
- The Patterns drawer, the sound panel, the top row (song mode, Undo's place, zoom's place), the fan menu's look (`DESIGN.md`).
- The full Arrange page and SLOOP's Timeline (sections, not entries).

## 2. Design

Boards: 19–20 (the Song tab's compact arrange), 48 (the toned-down Timeline; generator `design/boards/timeline.py`), 76 (Pads and Timeline at iPhone size, `design/boards/phone-timeline-pads.html`), row 11 of `design/boards/phone-consolidation.html`.

Motion follows `DESIGN.md`. Particular to the Timeline:
- A held block lifts and settles on a short ease-out; the reps label and the carried block follow the finger with no animation.
- Blocks slide to new places with the rearrange motion; a REST that opens grows from its left edge and closes back into it (exits quicker).
- The play colour fades in and out on Labs `padPlayFade`, as the pads.

### Decision log

- 2026-11-06: blocks say ↻ in Loop entry, not ×N, because REPS doesn't apply there (Scott).
- 2026-11-06: narrow blocks keep their count on a second line or shrink before cutting (Scott).
- 2026-11-09: the Timeline uses the Pads' heads and lanes, one set for both views (Scott).
- 2026-11-10: blocks toned down, the selected one in the Pads' language, option A of board 48 (Scott).
- 2026-11-10: the lane tab added to the shut selected lane, as on Pads (Scott: "Yes, add it").
- 2026-11-14: Android's Timeline is the keeper for both phones (decision 33, Scott).

## 3. Build notes

- `SkiffArrangePage` serves both the Song tab (`compact`) and the old Arrange page; changes for the Song tab are gated on `compact` / `toned`.
- Block drag uses a UIKit long press (`HoldRecognizer`) so it can share a touch with the lanes' scroll view; the grip uses a high-priority drag from touch-down so the scroll doesn't win.
- The track controls draw outside the lanes' scroll so they can hang over the editor; they follow the scroll by offset and stop taking touches where they pass under the heads (device check `2026-11-09-perform-grid-map.md` 60).
- Hard-coded timings not in Labs: the hold time, the lift, the lane change, the REST accordion. If Scott comments on any, it goes into Labs first (repo rule 3).
- Code issues found while writing this, not yet fixed:
  - `LaunchCountdown` (ArrangeCompact.swift) is no longer used anywhere since the trace replaced the numbers.
  - The `LaneMarks` doc comment still says "a pulsing outline and its countdown"; the code draws the trace.
  - Device check `2026-11-09-perform-grid-map.md` 37 expects the countdown capsule; 68 superseded it.
- For the iPhone port: Android's model (`TimelineView.kt`) keeps the pan and zoom as pure arithmetic with tests; Android reads a drag's numbers when it ends (its fb7a661 fix).

### Decision log

## 4. Usage

- To order and repeat a song, use the Timeline. To launch an entry live, use the pattern pad.
- A block and a pad are two faces of the same entry: keep their state words the same (C2) and change both when one changes.
- A new place that edits a track's list goes through `SkiffSongStore.rewrite` and `blocked(track:to:)`, so the lock while playing holds in one place.

---
component: Pattern pad
lifecycle: built
status:
  requirements: draft      # written 2026-11-13 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/PadsPage.swift        # pad(...) draws it; padSurface, padOutline, PadMarks, LaunchTrace, menus
  - ios/FM1/PadGrid.swift         # the layout that lets pads glide
  - ios/FM1/PadThumb.swift        # the pattern picture
  - ios/SloopKit/Sources/SloopKit/SkiffSongStore.swift   # launches
boards: [35, 36, 39, 41, 42, 46, 49, 53, "design/motion/liquid-pads.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=10-250   # No grid
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=10-304   # Half
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=10-334   # Max
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=7-148    # Phone
---

# Pattern pad

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

*Not to be confused with `Pads.swift`, which holds the FM-1's function keys (`FunctionPads`, `PadSurface`).*

## 1. Requirements

### Purpose and scope

One entry in one track's list, on the performance grid (Pads tab, Skiff): one row per track, one column per entry, so any track's entry launches without selecting that track first. The clip launcher is the reference for how it behaves, never for how it looks (`perform-grid-questions.md`). Why rows per track: performers want drums and leads side by side without switching tracks (session log, 2026-11-09).

It is not a launch-settings surface, not a scene or column launcher, and not the editor. Where it sits: `structure-map.md`, "The performance grid".

### Anatomy

Names as in the code. Layout positions: **No grid** = `.full`, **Half** = `.compact`, **Max** = `.row`, iPhone landscape = `.phone`.

- **surface** (`padSurface`): the face. Well, rest outline, filled control, or track-colour fill.
- **outline** (`padOutline`): one ring at a time, in priority order: held scene, waiting trace, selected mark, on/next.
- **letter**: the entry, A–P.
- **title**: the pattern number ("05"), "REST", or nothing when empty.
- **state line**: words saying what the pad is doing.
- **marks** (`PadMarks`): motion, play direction, own sound.
- **picture** (`PadThumbView`): the pattern drawn small.
- **pass bar** (`passBar`): progress through the current pass.
- **waiting trace** (`LaunchTrace`): the line that draws round a pad waiting to launch.
- **tint** (`selectedTint`): the selected pad's border of track colour. Part of the pad; the **track controls** that hang from it are not (see Out of scope).
- **drop outline**: a pad showing where a drag will land.
- **lifted copy**: the pad under the finger while dragging.

Words to retire, used for the same things elsewhere: "staged", "queued" and "launch" for waiting; "framed" and "pinned" for selected; "miniature" and "drawing" for the picture; "corner cut" for the own-sound mark; "full / over the editor / largest editor" and "Shut" for the layout positions.

### Requirements

**Functional**
- **F1** A pad is one list entry: a pattern, a REST, or empty.
- **F2** Columns run from A to the last entry used plus one empty, at least 8, at most 16. On the iPad they share the width; there's no sideways pan. Max shows the selected row's 16.
- **F3** Every pad keeps its identity across layout changes; nothing is rebuilt in place (`PadGrid` is a Layout, not a lazy grid).
- **F4** Pictures appear only when the row is tall enough to show them and the pool has been read while stopped (Settings › `PadPreviews`, a trial).
- **F5** `[open]` A chain drawn as one wide pad across its entries. Decided in the structure map and board 35; built as separate pads saying "Chained on". Build it, or retire the decision?

**States**
- **S1** Empty: a well in its lane, no title, no marks. State "Empty".
- **S2** Filled at rest: the raised control face. State "×N".
- **S3** REST: outline only, "REST" in place of a number. A playing REST stays outline-only.
- **S4** Playing: filled in the track colour with the pass bar at its foot. State line says the pass ("Pass 2/4", or "Playing · pass 2 of 4" where there's room) or "Looping".
- **S5** On it (stopped): the entry the track will play, ringed. State "On it".
- **S6** Waiting: the waiting trace draws counter-clockwise from the top left and closes as the launch lands, then fades as the pad lights. Dashed when the clock isn't known. Drawn from the touch, before the FM-1 answers. State "Waiting". No countdown numbers.
- **S7** The song's next (SONG ON, ONCE): a lighter ring, state "Next", on a chain's first entry only.
- **S8** Held scene: an outer ring where a held scene would send this track, only for scenes Lupe has seen.
- **S9** Selected (the editor's pad): ringed in its track colour, flat face, the tint round it.
- **S10** An empty pad with its menu open is ringed in the track colour, so it's clear which pad the choices are for (Scott, 2026-11-09).
- **S11** Marks: recorded motion, backwards, ping-pong, random, own sound. Boxed on full pads, bare after the number at Half, none on Max's smallest pads.
- **S12** Offline: no taps, no menu, no drag.
- **S13** Dragging: the source pad fades back; the lifted copy rises slightly and keeps the grab point under the finger (Scott, 2026-11-10: "the pad should stay under the finger").
- **S14** `[open]` A playing pad on a muted row. The structure map says outlined, not filled; the code has no mute state on the pad (mute shows on the head only); the liquid mockup squeezes the colour into a ring. Which?
- **S15** `[open]` The own-sound mark. Built as ♪. The structure map and board 36 say a cut top-right corner "as on the FM-1"; the batch list says "♪ and the name", and no name is shown. Which?

**Behaviour**
- **B1** Tap a filled pad while stopped: the track moves to that entry at once.
- **B2** Tap a filled pad while playing, including the one playing: it waits for the launch point. "While playing, every pad tap queues" (Scott, 2026-11-09).
- **B3** `[open]` Does a re-queued playing pad start again from step 1, or carry on? Device check `2026-11-09-perform-grid-map.md` 7, unanswered. If it carries on, a restart needs a firmware op. Also governs B4.
- **B4** Tap a waiting pad: takes the launch back by relaunching what's playing (the FM-1 has no per-track cancel).
- **B5** Tap a pad on another track's row: launches only. Selection, editor and the FM-1's knobs don't move; the row's number selects (Scott, 2026-11-09).
- **B6** Tap a pad on the selected track's row: the editor's selection goes with it, playing or not.
- **B7** Tap the selected pad while stopped: toggles the track controls (not at Max).
- **B8** Tap an empty pad: opens its menu at the pad. A tap never creates anything directly, so a stray tap mid-jam makes nothing (Scott, 2026-11-07). The same pad tapped again closes the menu.
- **B9** Several fingers: each pad touched waits to launch; one launch per track, a later touch replacing one not yet sent. No menu or drag while more than one finger is down.
- **B10** Hold: the fan menu opens at the finger in the track's tint, on any row, acting on that entry without selecting its track. The release after a hold is not a tap. Hold time: Settings › Touch, `holdToMenu`.
- **B11** Empty-pad menu: New pattern (while playing, it's also queued and the editor opens on it when it lands), Copy of the entry the track is on, Rest, Pick a pattern…, Patterns. On an empty pad past the list's end, the result goes on the first empty entry after the list; no silent gaps (Scott, 2026-11-07).
- **B12** Filled-pad menu, in order: Edit pattern, Play once more / once less (1–16; a chained entry explains its repeats instead), Make unique, Duplicate to next empty pad, Select sound, Copy to…, Move to… (off while playing), Patterns, Clear entry.
- **B13** Edit pattern selects the track, plays the entry first when stopped, and opens the editor under the pads. No trip to the Timeline (Scott, 2026-11-07). On the phone, the Edit tab.
- **B14** Drag starts after a hold and a move past `padSlideStart`, or a press of `padSlideDwell` then a slide. A move inside the dwell is a swipe and lifts nothing.
- **B15** Drop onto a filled pad on its own row: the two swap. Onto a filled pad on another row: nothing.
- **B16** Drop onto an empty pad, any row: a fan asks first. Copy here, Repeat here (own row) or Share with Tn (other row), Move here (own row only), Cancel. A REST has nothing to copy, so it only moves within its own row.
- **B17** While playing, a pattern pad still lifts (copy and share work); a move is refused at the drop with "Stop to rearrange". A REST is refused at the lift.
- **B18** `[open]` A move onto an empty pad mid-list leaves the dragged pad's old place empty. Keep the gap, or close it? (batch list, open since 2026-11-09) Android's `padMove` keeps the gap, as the iPad does today (Scott through the main session, 2026-11-15: match the iPad for now; the question stays open).
- **B19** A pattern dropped from the Patterns panel: onto an empty pad, it's taken at once (shared); onto a filled pad, a fan asks Replace / Copy here / Cancel. Nothing is replaced until a choice is picked (Scott, 2026-11-10).
- **B20** Clear entry asks in place only when the pattern is used nowhere else, Lupe is stopped, and the confirm hasn't been turned off. Otherwise it clears at once. Clearing works stopped only. **Android, 2026-11-15 (batch item 13, Scott):** no confirm at all; the pad clears at once and can be put back for ten seconds (`undoClear`), pattern included, because the core clears it in a way that keeps the pattern until the undo's time is up. Decided for all three apps; the iPad and iPhone still behave as written here until they are changed.
- **B21** The track controls hang from the selected pad at No grid and Half, open or shut as the user left them (Scott, 2026-11-09: "keep it open unless the user closes it"). Above by default, below where there's no room. They close at Max and come back after.
- **B22** A launch, a hold and a drag start each give a light haptic.

**Content**
- **C1** State words, and only these: Empty, ×N, On it, Next, Waiting, Chained on, Playing, Looping, Pass p/r, Playing · pass p of r, Playing · looping. "Next" capitalised.
- **C2** Menu titles name the track and entry ("T4 · entry C · empty", "· goes on E" past the list's end).
- **C3** The clear confirm names what goes: "Clear entry X"; "Pattern NN is used nowhere else, so it's erased with the entry. This can't be undone."
- **C4** Refusals say why and what to do: "Stop to rearrange: the FM-1 moves pads only while stopped".
- **C5** A full pool says so in the item itself (": all 64 taken").

**Accessibility**
- **A1** Each pad is a button. Label: "Track n Name, entry X" then ", empty", ", rest, once / N times" or ", pattern NN, once / N times". The track number is there because two tracks can share a name; "once", never "1 times".
- **A2** One value: the state, plus ", starts in …" while waiting, plus ", the held scene goes here".
- **A3** The selected pad carries the selected trait.
- **A4** Hints match what a tap does in that state. `[open]` The selected pad tapped while stopped toggles the controls (B7), but its hint still says "Moves the track to it".
- **A5** "Entry menu" action opens the hold menu without holding.
- **A6** Reading order: each row's head, then its pads, row by row.
- **A7** Every drag has a non-drag way in: Move to… and Copy to… (WCAG 2.5.7).
- **A8** Nothing by colour alone: playing has the bar and words, waiting the trace and "Waiting", selected the ring and the trait. `[review]` At Half, playing has the bar only.
- **A9** Targets: 44 pt at No grid; Half (42) and the phone (40) are accepted exceptions above the 24 pt floor.
- **A10** Reduce Motion: selection and controls cross-fade; the play colour fade stays (a colour change); the lifted copy doesn't grow; the waiting trace still draws (Scott's call, accessibility P13).
- **A11** `[open]` The empty pad's edge fails 3:1 (accessibility P2, 1.36:1, lower on a lane tint). Options on the table: use `laneEdge` everywhere, or a new `padEmptyEdge`. Not chosen.
- **A12** `[open]` The waiting trace's faint base ring is 1.4–2.1:1 (P7), and at Half it's the only sign at first.
- **A13** `[open]` No Dynamic Type on the grid (P1) and Increase Contrast not read (P11). Structure decisions, waiting on Scott.

**Integration**
- **I1** Launch is `ListOp.play(track:entry:)` (LIST op 3). Sending it never changes the FM-1's selected track.
- **I2** It lands at the FM-1's one LAUNCH setting: BAR and BEAT land together across tracks, LOOP at each track's own pass end, NOW as each op arrives. Launches go one at a time.
- **I3** State comes from LIST2 per track and `store.marks`; pass progress and time-to-launch are counted from the MIDI clock. No count, no bar and a dashed trace.
- **I4** A launch from the FM-1's own keys shows up to a second late (polling). Accepted.
- **I5** Skiff refuses PLAY on an empty entry, rewrites lists only while stopped, and clears only while stopped. The pad says so rather than trying.
- **I6** No per-track stop (the row's stop is its mute), no per-track cancel (B4 is the workaround), no reading a scene's contents (S8 only for scenes seen). Each would be a Skiff-Lupe firmware op; none is planned.
- **I7** iPhone landscape: same faces, states and menus, no track controls (border only), launch settings in the top bar's Launch key, the editor on the Edit tab, 8 columns in view with a pan. The menu wraps into two columns where it doesn't fit.
- **I8** `[open]` The Pixel's Select toggle (a pad tap picks for the editor and launches nothing; board 53, 2026-11-13) is decided for Android. Does it come to the iPhone or iPad?
- **I9** SLOOP has section pads, not pattern pads. They share the waiting trace and "Next", nothing else. Not covered here.

### Ruled out

- A separate Live tab: Pads became the grid instead (Scott, 2026-11-09).
- Column or scene launch from the grid: Skiff's scenes aren't columns (2026-11-09).
- Launch settings per pad or per track: the FM-1 has one LAUNCH.
- A real per-track stop op for now: the row's mute is its stop (Scott, 2026-11-09).
- A waiting pad tapped again doing nothing: it takes the launch back (2026-11-09).
- An empty pad tap that creates something directly: a menu, so stray taps make nothing (Scott, 2026-11-07).
- Countdown numbers on a waiting pad: the traced outline replaced them (Scott, 2026-11-10).
- A white ring on the selected pad: the track colour, clearer at Half (Scott, 2026-11-09).
- The selected pad shrinking inside its tint, or the selected row's pads shrinking: they keep their size and the lane grows round them (Scott, 2026-11-09 and 2026-11-10).
- A crossfade between selected pads: the old grows back as the new one shrinks, together (Scott, 2026-11-09).
- System alerts for confirms: confirm in place at the finger (`DESIGN.md`).
- A sound submenu on the pad: Select sound opens the sound panel, which names the pad (2026-11-08).
- Pads folding into their lanes on the switch to Timeline: dropped for the slide (c24843b).
- Track controls at Half shown as the border only: they show at every size but Max (dccd2ea, 2026-11-09).

### Out of scope

- Track head (number, name, Mute, Solo, sound key): `PadsTrackStrip.swift`.
- Lanes: `LaneShape`.
- Track controls box and its tab: `TrackKnobBox`, `PadTabShape`, `LaneTabShape`, `OpenControlsTab`. This document says only where it hangs (B21).
- Scene row and Store; the tool row (Launch at, Cancel waiting, Patterns); the phone's Launch key.
- Patterns panel, the editor, the sound panel, Timeline blocks (their own waiting and tint), SLOOP section pads, the disconnect card, the FM-1 function keys.

## 2. Design

Boards: 35 (the grid), 36 (held scene, own sound), 39–40 (layouts), 41 (lanes and wells), 42 (disconnected), 46 (marks), 53 (Pixel portrait). Motion: `design/motion/liquid-pads.html`.

Motion follows `DESIGN.md` (nothing pops). Particular to the pad:
- The play colour fades in and out (`padPlayFade` in Labs; Scott, 2026-11-09: "at least just like fade in… same when it stops"), skipped in the first moments after the pad appears.
- The tint travels with the pad on the divider's spring (`dividerFeel`), never separately from it (Scott, 2026-11-08).
- The tint and the controls come out from behind the lane's edge, not revealed in place (Scott, 2026-11-09: "revealed in place they looked as if they'd been sitting there").
- `[open]` The liquid mockup (2026-11-13: the play colour as liquid poured from pad to pad, mute as a ring, presets Stage-safe / Water / Honey / Mercury). Undecided: liquid or today's fade, which preset, mute as a ring (see S14), instant tint or arrival, gravity and tilt, and whether it can read inside the ~150 ms state-change budget. Nothing in the app uses it.

### Decision log

- 2026-11-07: a tap on an empty pad opens a menu, never creates, because a stray tap mid-jam must make nothing (Scott).
- 2026-11-09: rows per track, Pads becomes the grid, because performers want tracks side by side (Scott).
- 2026-11-09: the selected ring takes the track colour, not white, because it's clearer at Half (Scott).
- 2026-11-09: track controls stay open or shut as left, at every size but Max (Scott, dccd2ea).
- 2026-11-10: the waiting trace replaces countdown numbers (Scott, 4d2f711).
- 2026-11-10: the lifted copy stays under the finger where it was grabbed (Scott).
- 2026-11-10: drops from the Patterns panel ask before replacing anything (Scott).
- 2026-11-17: **the drag wells in the hybrid look** (Scott's picks: "1 · Edge tabs" and "Grow, then fill"; Figma "Drag wells · hybrid options (2026-11-17)", vault `fm1-ipad/assets/drag-wells-hybrid-2026-11-17/1-edge-tabs.png`). Decision 41's placement and behaviour stay: Cancel at the bottom, Clear steps and Delete pattern at the top (Delete greyed with "Stop first" while playing; the layout never changes), Edit right, Duplicate left, the tick and the hot zone. The glass, blur and dashed edges go: each well is a solid `held` surface flush to its edge, square on the edge side and radius 24 facing in, elevation 3, an icon (22) and the label (vertical on the sides, horizontal top and bottom). The glow goes too: a well grows outward with the pad's closeness (the tuned glow and hot distances); hot, it fills with the pad's track colour, the ink turns dark and the icon grows to 26. Clear steps and Delete fill track-coloured, not red, unless Scott says otherwise. Wells slide in on the spatial spring and out quicker; growth tracks the finger directly; the fill eases over 150 ms; Reduce Motion fades only.
- 2026-11-17 (round 3, Scott on the Pixel): **keep the track colour on Clear steps and Delete** ("keep the track colour on clear and delete is fine"), and **the colour swells with closeness** ("the color should swell as the user gets closer"): a well's fill blends from `held` toward the track colour continuously as the pad nears (the same glow and hot distances), growing as before; the ink crosses to `onColour` by computed contrast, blended so it never flips; hot is full colour, icon 26, the tick.
- 2026-11-17 (round 3): **a pad starting or stopping visibly changes shape** ("it should be clear that there is a shape transformation happening"): the card → pill change rides M3 Expressive's default spatial spring (0.8 / 380) instead of the 200 ms spring, and the pad squashes and stretches (6 % wider, 4 % shorter going into play; the reverse coming out). Spec §5, round 3; values in Labs.

## 3. Build notes

- `.android` hybrid look (branch `hybrid-ui-android`, 2026-11-17; spec 3.1): a playing pad is a full pill, every other state a 10-radius card; the shape springs (Labs › Hybrid · at the finger) and a press morphs a playing pad back toward the card; colour still eases. Queued for the next pass: `lifted` with a 2 dp edge in the track colour and "Next". Pass bar 4 tall. Pad value Barlow Condensed Bold 21; "Rest" in words. **Left as built, because their lines are `[open]`:** the empty pad's edge (A11: the spec's `primaryEdge` would answer it, if Scott adopts it), the playing pad on a muted row (S14: still the ring, and it stays a card), the own-sound mark (S15: the cut corner sits oddly on a pill).

- Layout is `PadGrid`, a Layout, so pads glide between positions; keep it that way (F3).
- Marks refresh at 4 Hz; the pass bar and the trace run per frame.
- Launches serialise one at a time and wait behind an edit (`SkiffSongStore`). Lupe's own reads go to the back of the queue (13e75ef, after pads fell behind the FM-1; device checks 70–71 passed).
- Hard-coded timings not in Labs: selection, lane and controls changes; the waiting ring in and out; the controls tab fade; the hold-release window. If Scott comments on any of them, it goes into Labs first (repo rule 3).
- Code issues found while writing this, not yet fixed:
  - The selected ring's width test (`radius < 8 ? 2 : 3`) can never pick 2, since the radius is 8 or 16.
  - The drop outline's corner is fixed at 16, while Half's pads use 8.
  - `OpenControlsTab` isn't excluded on the phone, where the controls never show. Not checked at runtime.
  - A comment at `PadsPage.swift` ~389 still says the controls show "only at full size".

### Decision log

- 2026-11-10: the stale-poll fix: one cancellable reread of a changed pattern's length, not two full reads, because pads fell behind the FM-1 (13e75ef).
- 2026-11-17: **the selected ring cross-fades cleanly** (Scott: "there's like a dithering of the outline transition"). The ring is each pad's own, two outlines: the old pad's fades out while the new one's fades in, 150 ms ease-out. Its alpha was `selected × (1 − waiting)`, two fades multiplied, so a pad tapped while playing (selected and waiting at once) flashed its ring up to a quarter and back within ~150 ms as the launch trace came in. Now one fade, target `selected and not waiting`. The waiting pad's trace follows the pad's own radius as it draws. Device checks 110–111.
- 2026-11-18: **where a recording goes** (Scott: recording from Pads "doesn't show on the pad", but Edit has it). Cause, from Skiff 2.5.1's bank.c (trk_keep, trk_name) and project.c (autosave_poll): a track records into its own working steps. A track with no pattern only gets one, and a list entry (the entry it is on if empty, else the first empty one), when the FM-1 next keeps its tracks: stopped, idle (no keys, no buttons) for about 1–2 s. Until then there is no pattern for a pad to show, while Edit shows the working steps. The core now says, per row, where those steps will be kept (`newAt`, by the same rule) and whether the track is recording (armed and playing). Pads shows that pad dashed in the track colour with "New". While recording, the pad the take goes into (the "New" one, or the pad it is on) gets a steady 2 dp edge in the record red, labelled "Rec" when new. When the FM-1 has kept it, or the recording stops on an existing pattern, that pad becomes the picked pad. Edit's title says "Lofi Piano · A new" rather than a pattern 00 until it's kept. Device checks 141–143.
- 2026-11-18 (Scott: "the two areas where you can drag pads to delete or clear, need some space between them. Maybe the delete one should be red"): **the top wells sit 24 dp apart and Delete pattern is red.** The pair keeps its 0.6-of-the-width cap, so the wells narrow, not the gap. As a well grows with closeness, the two facing sides grow at most 4 dp each, so they never come closer than 16 dp; the outer sides grow as before. Hot detection still uses the resting rects. Delete fills toward `rec` instead of the pad's track colour, blending with closeness as before (no switch at the threshold); at rest its icon draws in `rec` (3.24:1 on `held`, over WCAG 1.4.11's 3:1) and blends into the label ink as it fills; hot, the label is `onColour` on `rec` (5.81:1). While Delete is off (playing) it stays grey, no red. Clear steps keeps the track colour. Reverses the 2026-11-17 call ("not red, unless he says otherwise"). Device check 168.

## 4. Usage

- To launch any track's entry without moving the editor, use a pad on that track's row (B5). To change what the editor shows, select the row by its number.
- A new view that shows list entries should reuse this pad's face and states, not draw its own: the structure map's rule is that the grid reuses the pad face, the scene row, `store.marks` and `PadGrid`.
- Timeline blocks show the same states (waiting, playing, next) with their own shapes. Keep the words in C1 the same on both.

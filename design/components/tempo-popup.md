---
component: Tempo popup
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/TempoPanel.swift      # TempoOverlay (placement, open and close), TempoPanel (contents)
  - ios/FM1/TopBar.swift          # the readout that opens it (iPad)
  - ios/FM1/PhoneAppView.swift    # the readout that opens it (iPhone)
  - ios/FM1/ArrangeCompact.swift  # SongModeKeys (Loop entry · Play song · Play once)
  # Android (branch claude/android-p1-core-link-faf639, not on the trunk): the readout's own menu
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/Header.kt
boards: [47, "design/boards/toprow.py"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-374
---

# Tempo popup

*Opens from the top bar's readout ("12 · 3 / Song · 120 BPM"). Code name: `TempoPanel`.*

## 1. Requirements

### Purpose and scope

Sets the tempo three ways (slide, type, tap in time) and Skiff's playback mode, in a small panel that grows out of the readout. The readout shows both, so this is where they change. It does nothing while the FM-1 follows another clock, and says why.

Where it sits: `structure-map.md`, "Tabs" (the paragraph on the one row above the pages).

### Anatomy

Names as in the code.

- **overlay** (`TempoOverlay`): places the panel under the readout and runs its open and close.
- **panel** (`TempoPanel`): the contents.
- **TEMPO column**: the tempo as a column face, like every other value (`KnobControl`; see `column-face.md`).
- **Tap**: the square tap-tempo key beside it.
- **keypad**: digits, delete and **Set**, the panel's own.
- **playback keys** (`SongModeKeys`, Skiff): Loop entry · Play song · Play once, under the label "Playback".
- **song mode keys** (`SloopSongModeKeys`, SLOOP on the iPad): Loop · Song.
- **footer**: the range and how to set it.
- **problem line**: what's wrong with a typed number.
- **clock note**: following another clock.

Words to retire: "tempo popover", "BPM menu"; "song mode" for Skiff (its word is playback mode; SLOOP's stays song mode).

### Requirements

**Functional**
- **F1** The tempo is set by sliding the TEMPO column, typing on the keypad, or tapping Tap in time. Each sets the FM-1's tempo (device check `2026-11-09-lupe-batch-2026-11-06.md` 12, passed 2026-11-11).
- **F2** The range is the FM-1's own, read from it (`session.bpmRange`).
- **F3** Skiff: the playback mode is set here, one of Loop entry, Play song, Play once (Scott, 2026-11-10, board 47).
- **F4** SLOOP on the iPad: its song mode, Loop or Song, in the same place (2026-11-10).
- **F5** The tempo is re-read from the FM-1 when the panel opens.

**States**
- **S1** Closed.
- **S2** Open: the TEMPO column and Tap, the playback keys, the footer.
- **S3** Typing: the keypad shows, the column has a ring round it and shows the digits typed ("–" before any), Tap is disabled, the playback keys and footer hide.
- **S4** Typed number out of range: the problem line ("300 is outside 40–240 BPM"); the keypad stays open to fix it.
- **S5** Set disabled while nothing is typed.
- **S6** Following another clock: the column and Tap faded and disabled, the clock note in place of the footer.
- **S7** Song offline: the playback keys are disabled.
- **S8** The current playback mode is the selected key.

**Behaviour**
- **B1** A tap on the readout opens the panel under it, kept inside the screen's edges. A tap on the readout while it's open only closes it (`OutsideTouch.justClosed`).
- **B2** A slide on the column sets the tempo as any column does, with the loupe above the finger.
- **B3** A tap on the column opens the keypad. Up to three digits; delete removes the last; Set checks the range, sets the tempo and closes the keypad.
- **B4** Tap: the tempo follows the average of the last few taps; a pause starts over (`TempoPanel.tap`).
- **B5** A playback key sends the mode to the FM-1 at once.
- **B6** Closing: a touch outside, Escape, or VoiceOver's scrub. With the keypad open, Escape closes the keypad first.
- **B7** Hardware keyboard: ↑ and ↓ step the tempo by one.
- **B8** BPM LOCK on the FM-1 doesn't stop it: that only makes the FM-1's SELECT knob need GLO held (Skiff `ui_input.c`, code comment).
- **B9** iPhone: the same panel from its own readout.

**Content**
- **C1** The column reads "TEMPO", value "120 BPM".
- **C2** Footer: "40–240 BPM · slide, or tap to type", the numbers the FM-1's range.
- **C3** Clock note: "Following USB clock: the tempo comes from the other device. Set CLOCK to INT on the FM-1 to set it here."
- **C4** Playback words: Loop entry, Play song, Play once; the readout's short word Loop, Song or Once. The keys' hint says each plainly (Scott, 2026-11-06: "say it plainly"): "Loop entry: each track repeats the block it's on. Play song: each track plays its blocks in order and starts over. Play once: plays through once and stops."
- **C5** No heading: the column says TEMPO.

**Accessibility**
- **A1** The panel is a modal container labelled "Tempo": VoiceOver stays in it, and the scrub closes it (2026-11-10; device check `2026-11-10-accessibility.md` 10, part A passed 2026-11-11).
- **A2** The column hints "Slide to set it. Tap to type a number".
- **A3** Tap reads "Tap tempo", hint "Tap in time: the tempo follows the last few taps".
- **A4** Keypad keys read their digit, "Delete", "Set tempo".
- **A5** The "Playback" label is hidden; the keys carry their own label and hint.
- **A6** Escape and the hardware cancel key close it (device check `2026-11-10-accessibility.md` 22, part C passed 2026-11-11).
- **A7** Reduce Motion: it fades in and out instead of growing from the readout.
- **A8** Targets: keypad keys at least 44 pt; Tap and the column larger.
- **A9** `[review]` The disabled state while following a clock is shown by fading; the clock note says it in words. Whether the faded column still reads as disabled to VoiceOver isn't checked.

**Integration**
- **I1** Following comes from the FM-1's CLOCK / SYNC setting (USB or TRS): `session.externalClock` names the source.
- **I2** The playback mode is Skiff's song mode op (`store.send(.song(…))`), refused while the song is offline.
- **I3** SLOOP's song mode keys show only on the iPad with SLOOP's song, not in the classic layout.

### Ruled out

- Popping in: it grows out of the readout and shrinks back into it (Scott, 2026-11-06: it used to pop in).
- The system keyboard for typing: it would cover the page; the panel has its own keypad (code comment).
- The readout opening Arrange in song mode: it opens the tempo (2026-11-05, `TopBar` comment).
- The playback mode in the top bar beside Play: it moved here, its word under the tempo in the readout (2026-11-10, board 47; it had moved to the top bar 2026-11-06).
- Tempo as anything but a column: option A, the column like every other value, with Tap beside it (Scott, 2026-11-09; batch list 6, 132b623).

### Out of scope

- The readout itself (position over tempo and the playback word): the top bar.
- The column face and its slide: `column-face.md`.
- The value loupe: its own component.
- Launch at: the top bar's tools.

## 2. Design

Board 47 (`design/boards/toprow.py`): the one row above the pages, which put the playback mode under the tempo.

Motion follows `DESIGN.md`. Particular to it: it grows from the readout's middle with a short spring and shrinks back with a quicker ease; only its transform and opacity move, its one shadow on its background shape, so nothing re-blurs per frame (code comment).

### Decision log

- 2026-11-06: grows from the readout, not popping in (Scott).
- 2026-11-09: option A, the tempo as a column with a big Tap beside it (Scott, 132b623; passed on the device 2026-11-11, check 12).
- 2026-11-10: the playback mode moves here from the top bar (Scott, board 47).

## 3. Build notes

- Lupe's own keypad, not `TextField`: the system keyboard would cover the page.
- The overlay places the panel against the readout's frame (`globalFrame`); the phone's readout is narrower, and the code accepts the few points' difference in the grow anchor.
- `[open]` The phones' header is Android's (decisions 23, 29, 31). Android's readout opens its own menu: a TEMPO slide row (double tap reverts to the value on opening) and Loop · Song · Once, with no Tap and no keypad (`Header.kt`). Do the phones keep this popup, Android's menu, or one with Tap and the keypad added?

### Decision log

## 4. Usage

- Open it only from the readout: `ui.tempoAt` is the readout's corner, and the overlay grows from there.
- Another place that wants to change the tempo should send people here, not draw a second tempo control.

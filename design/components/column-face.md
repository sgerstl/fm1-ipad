---
component: Column face (the knob tile)
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, QA notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/ShapeColumns.swift    # ColumnFace, EmptyColumn, RollingText, splitUnit
  - ios/FM1/Knobs.swift           # KnobSpec, KnobControl (the touch), KnobDial, drawDial, ColumnSlidePan, HoldDrag, KnobFeel
  - ios/FM1/KnobPanel.swift       # KnobPanel, KnobPanelLayer (the big control)
  - ios/FM1/ValueLoupe.swift      # LoupeState, ValueLoupeLayer, LoupeFace (the Magnifier)
  - ios/FM1/Settings.swift        # SlideToTurn, Magnifier
  - android/app/src/main/java/com/scottgerstl/lupe/ui/page/RoundDial.kt   # the phones' round dial (branch claude/android-p2-shell-02c86f)
  - android/app/src/main/java/com/scottgerstl/lupe/ui/slide/Slide.kt      # Android's slide to turn and Magnifier
boards: [17, 18, 70, "qa/knobs-2026-11-05/README.md"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=12-126   # Column face
---

# Column face (the knob tile)

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

> **Under revision (2026-11-14):** on the phones, the sound panel shows the FM-1's four knobs as **round dials**, with the page's picture under them when Settings › Show graphics is on (decisions 21, 25, 30 and 32 in the vault's `phone-skiff-decisions-2026-11-12.md`; the build plan's iPhone row: "four dials + picture"). Android draws them with `RoundDial.kt`; the iPhone's sound panel draws column faces today. **Slide to turn defaults to Up and down on the phone** (decision 10); Android does, the iPhone's default is Sideways today. Section 1 is the iPad and today's iPhone.

## 1. Requirements

### Purpose and scope

One of the FM-1's four knobs, drawn as Skiff draws its cards (`ui_draw.c` `draw_column`): the label with the knob's number, the value large with its unit, a thin gauge in the track's colour. It turns by a slide on the tile itself, with the value magnified above the finger. Used wherever a knob's value shows: the sound panel's pages, the track controls, the Mixer's cards, the step inspector, the tempo.

The **dial** (`KnobDial`) is the same knob in a round face, on the few places that keep it (the track popover, the step panel's velocity on SLOOP, the phone's SLOOP Shape). It shares the knob's data, double tap, haptics and accessibility; its touch differs (B8).

### Anatomy

Names as in the code.

- **column** (`ColumnFace`): the tile, on the well.
- **label**: the knob's name, small capitals ("CUTOFF").
- **number badge**: the FM-1 knob it answers to, 1–4; none for 0.
- **value** (`RollingText`): the figures, in Barlow Condensed, digits that roll.
- **unit**: %, Hz, kHz, ms, s, dB, st, ct, BPM after the figures (`splitUnit`).
- **gauge**: the thin bar along the foot, from the left or from the centre.
- **hot bar**: the white bar along the top while the knob turns.
- **recording ring**: the red ring while Skiff records knob moves into this parameter.
- **empty column** (`EmptyColumn`): a slot the page doesn't use.
- **dial** (`KnobDial`): track arc, value arc, cap, needle, label, value; a **bubble** with the value while dragged.
- **big control** (`KnobPanel`): title, **arc** with its **dot** and the value inside, **typed field** with **Set**, **Back to the default**, **Cancel**, **Done**; or a **choice list**.
- **Magnifier** (`ValueLoupeLayer`, `LoupeFace`): the bigger copy above the finger.
- **knob** (`KnobSpec`): the data behind any face; **the touch** (`KnobControl`).

Words to retire: "card" (Skiff's word; Lupe's is column), "loupe" in prose (the setting is called Magnifier), "knob tile" outside this title.

### Requirements

**Functional**
- **F1** A column shows one knob's label, number, value, unit and gauge.
- **F2** A value centred on zero fills its gauge from the centre; others from the left.
- **F3** Compact columns (the track controls' narrow boxes, `compactColumns`) use fixed smaller sizes and never shrink to fit, so a value or the hot bar changing never resizes the words (Scott, 2026-11-08: "no jumpy size changes").
- **F4** A page slot with no knob shows an empty column.

**States**
- **S1** Rest: the value in the text colour, the gauge in the tint (the track colour; white for shared or global pages).
- **S2** Hot: while the knob is turned here or on the FM-1, and a moment after (Skiff's hot card), the hot bar shows and the number badge brightens. The column's own colours stay.
- **S3** Recording: the recording ring, while Skiff records knob moves (REC armed, playing, the selected track's own parameter). Not on a dim column.
- **S4** Dim (a value that doesn't turn here, such as MOD's fixed routes' SOURCE and DEST): the value in the tertiary grey, the gauge empty.
- **S5** Dead (turns, but does nothing as things stand, such as DIR while STRUM is OFF): the value in the tertiary grey; the gauge still shows.
- **S6** Value change: the changed digits roll, up or down, all landing together. Shown at once instead when the shape changes (length, sign, a name), when a change follows the last too closely, or under Reduce Motion.
- **S7** Dial: a dead value at half strength. While dragged, the bubble above it shows the value.
- **S8** Big control: a list instead of the arc when the knob picks from names. The typed field only where the value shows as a plain number. Back to the default only when the value isn't the default.
- **S9** Magnifier: shown while a column or dial is slid, if Settings › Magnifier is on. A column magnifies as hot; a dial as a small dial with its label and value.

**Behaviour**
- **B1** A column turns by a slide on it. Which way is Settings › Slide to turn: Sideways (right raises), Up and down (up raises), or Both (the first movement's stronger direction decides that slide) (Scott, 2026-11-06).
- **B2** Sideways leaves every vertical drag to the page's scroll. Up and down makes a vertical scroll wait for the column, so a panel scrolls from the gaps between columns. Over a horizontal scroll (the Mixer's cards), the column takes the slide and the scroll waits.
- **B3** A sideways slide covers the whole range in Labs `columnTravel` (Settings › Touch, "Slide for a full turn"). An up-and-down slide uses the dial's travel (`KnobControl.columnTravelUp`).
- **B4** The value moves from where it was, never jumping to the finger, clamped to the range. One finger only.
- **B5** Double tap: the parameter's default (DESC), where one is known.
- **B6** A single tap on a column only focuses it: its page becomes the active one, on the FM-1 too when linked (Scott, 2026-11-06). The tempo's column is the exception: its tap opens the keypad.
- **B7** Touching any knob makes its page the active one and the knob works at once.
- **B8** Dial: press and hold until the hold takes (a light haptic), then drag; up raises, finer the further the finger goes sideways. Moving before the hold takes leaves the touch to the page's scroll (Scott, 2026-11-05: "drag straight on" was terrible).
- **B9** Dial tap: the big control opens at the finger, kept on screen.
- **B10** A light haptic at either end of the range, and at the centre of a value centred on zero.
- **B11** Big control: drag the dot anywhere round the arc (below it, the nearer end); a double tap on the arc puts the default back; a typed whole number sets it.
- **B12** Big control: changes go to the FM-1 as they're made. Done keeps (a tap outside and Return too); Cancel puts back the value it had when it opened (Escape too).
- **B13** Choice list: a tap picks and closes.
- **B14** Magnifier: floats above the finger and follows it, kept inside the screen; grows out of the finger and shrinks back into it. It takes no touches.

**Content**
- **C1** Labels as the FM-1 shows them, in capitals; values as the device shows them (`KnobSpec.shown`).
- **C2** The big control's title is the label capitalised ("Cutoff").
- **C3** Typed-number refusals: "Type a whole number, a to b"; "v is outside a–b".

**Accessibility**
- **A1** Each knob is one element: label the name capitalised, value the spoken form (`KnobSpec.spoken`: "centre", "12 left", "muted", "70 percent").
- **A2** Adjustable: VoiceOver swipe up and down moves it by its step.
- **A3** Actions: "Open" (the big control) and "Reset to default".
- **A4** A recording column's value says "recording".
- **A5** The big control is modal, with an Escape action; its title is a header; the arc is adjustable; the current choice carries the selected trait.
- **A6** The gauge, the hot bar and the Magnifier are hidden from VoiceOver; the knob says its value.
- **A7** Hot is told by a shape (the bar), not by colour.
- **A8** Reduce Motion: the hot bar appears without easing, digits don't roll, the Magnifier only fades.
- **A9** `[open]` A column changes only by dragging for a finger; the tap only focuses (accessibility P3, High, WCAG 2.5.7). The audit's proposal (a long press or a second tap on a focused column opens the big control) isn't decided. VoiceOver is covered (A2, A3).
- **A10** `[review]` The recording ring is a red ring and a VoiceOver value; whether it reads without colour on the device.
- **A11** `[open]` No Dynamic Type on columns (accessibility P1).

**Integration**
- **I1** Defaults and named choices come from the FM-1's DESC (format 8 for names).
- **I2** Hot follows the FM-1's knob turns as well as Lupe's (`marks.key`), as Skiff's `ui.hot_t`.
- **I3** Rolling digits follow Skiff's `roll_text`: its frame count, its ease table, the ones digit first.
- **I4** Every change is sent to the FM-1 as it happens (`KnobSpec.set`).
- **I5** `[open]` The phones' Slide to turn default (decision 10: Up and down) against the iPhone's built default (Sideways). Decision 33 carries the setting into the merged Settings without naming the default.

### Ruled out

- The whole column turning white while turned: a white bar along its top instead, the column's colours kept (Scott, 2026-11-05, after trying it on the FM-1).
- Drag straight on a dial with no hold: terrible (Scott, 2026-11-05); hold, then drag.
- The press-hold-then-trace grown ring and the − / + popover (`qa/knobs-2026-11-05/README.md`).
- A stepper in the big control (Scott, 2026-11-05).
- A slider as the big control: compared with the arc and dropped (2026-11-06, `KnobPanel.swift`).
- A tap on a column opening the big control: a tap only focuses (Scott, 2026-11-06).
- − / + steppers for values on the phone: slide on the control (Scott, 2026-11-13, decision 10).

### Out of scope

- Faders (Mix's LEVEL, PAN, sends): `faders.md`.
- The keys inside the big control: `keys.md`.
- The pages that hold columns: `sound-panel.md`, `mix.md` (the Mixer's cards), `step-inspector.md`, `tempo-popup.md`, and the track controls (`TrackControls.swift`, `track-head.md`).
- The graphs above the columns (`PageGraphs.swift`, `Graphs.swift`).

## 2. Design

Canvas boards 17 and 18 (`lupe/shape.py`, 2026-11-05). Board 70 (`design/boards/phone-portrait-2.html`): the phone's four round dials. Big control shots: `qa/knobs-2026-11-05/`.

### Decision log

- 2026-11-05: columns drawn as Skiff's cards (boards 17 and 18).
- 2026-11-05: the hot column marked by a top bar, not turned white (Scott, after the FM-1).
- 2026-11-06: columns turn on a slide, sideways by default; Slide to turn adds Up and down and Both (Scott).
- 2026-11-06: the Magnifier, on by default and switchable (Scott: "my fat fingers obscure the values").
- 2026-11-13: on the phone, slide on the control with the Magnifier, up and down by default, double tap reverts; no steppers (Scott, decision 10).

## 3. Build notes

- The slide is a UIKit pan (`ColumnSlidePan`) so it can decide before the scroll view does; its delegate picks the axis from the first velocity.
- Taps are SwiftUI's own (double, then single), because in a scroll view a plain tap never reached a drag gesture's end (`qa/knobs-2026-11-05/README.md`).
- The Magnifier has its own observable state, read only by its layer, so a moving finger redraws the Magnifier and nothing else (the Mix tab's lesson).
- The Magnifier's grow-and-shrink anchor is the finger in the layer; a bottom anchor shrank it toward the screen's foot (Scott, 2026-11-06).
- Android's slide (`Slide.kt`) copies `ColumnSlidePan`'s three directions; its Magnifier grows from the finger and fades under Reduce Motion.
- Device checks: `2026-11-09-lupe-batch-2026-11-06.md` 12 (the tempo column and the Magnifier), 16 (knob 1's highlight following the FM-1); `2026-11-09-perform-grid-map.md` 67 (Slide for a full turn); `2026-11-14-android-landscape.md` 11 and 30 (Android branch: the slide, double tap, the Magnifier never outliving its gesture).
- The inventory's "dead: empty gauge" is wrong against the code: only dim empties the gauge (S4, S5).

### Decision log

## 4. Usage

- To show and change one of the FM-1's knob values, use a column through `KnobControl(column:)`, never a new face.
- A value set by a long drag on its own (a level, a pan) is a fader: `faders.md`.
- A knob that has no FM-1 knob number passes 0: no badge.

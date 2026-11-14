---
component: Keys (the chiclet family)
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code and the accessibility audit; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/Theme.swift           # Chiclet, RaisedKey, LatchedKey, SelectedKey, Elevated, Recessed, LED, keyPressed
  - ios/FM1/Controls.swift        # PressSink, SegmentedKeys, ToggleKey, IconKey, StepperKeys
  - ios/FM1/TrackChips.swift      # EffectChip, ChipView, MoreChips, ChipRow
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/Components.kt   # Key (branch claude/android-p2-shell-02c86f)
boards: [46, "tokens/tokens.json › chiclet"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=4-18     # Key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=4-23     # LED
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=12-240   # Segmented keys
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=12-153   # Effect chip
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=5-80     # Icon stand-ins (the app uses SF Symbols)
---

# Keys (the chiclet family)

*The press behaviour every key in Lupe shares. Other CRDs point here for "pressed", "latched", "disabled" and "selected" rather than restating them.*

## 1. Requirements

### Purpose and scope

The shape that says "you can press this": a flat top standing on a hard edge, which drops onto the edge under the finger. A well says the opposite: it shows you something. Elevation (a lighter surface, a soft shadow, a ring) says "selected". These three looks are Lupe's whole vocabulary for controls in the content (`Theme.swift`, "The look", 2026-11-05).

It is not the header's language on the phones: the header uses words and round keys (`phone-header.md`).

### Anatomy

Names as in the code.

- **chiclet** (`Chiclet`): the key's shape. A **top** and an **edge** (the same shape, offset below it, in the edge colour). No blur, gradient or highlight.
- **raised key** (`raisedKey()`, `RaisedKey`): a chiclet behind a label. **Primary** (`primary: true`): the one primary action in a view, its top in the text colour.
- **press** (`PressSink`): the button style that sinks a key and greys its label when disabled.
- **latched key** (`latchedKey(on)`, `LatchedKey`): a toggle that stays down while on.
- **selected key** (`selectedKey()`, `SelectedKey`): elevation 2 with its ring, for the current one of several.
- **well** (`recessed()`, `Recessed`): the darker ground for things that show, and for groups of keys.
- **LED** (`LED`): a small flat light. No glow.
- **segmented keys** (`SegmentedKeys`): one of several, as segments in a well, the chosen one raised.
- **toggle key** (`ToggleKey`): an LED and a name on a latched key.
- **icon key** (`IconKey`): a toggle as a symbol, for the top row.
- **stepper** (`StepperKeys`): − value + in a well.
- **effect chip** (`ChipView`): a capsule with a **symbol** and a **word**, on the control grey with a hairline. **More chip** (`MoreChips`): "+N", or the count alone. **Chip row** (`ChipRow`): as many chips as fit.

### Requirements

**Functional**
- **F1** Anything pressable in the content is a raised key or a chip; anything that only shows is in a well.
- **F2** One primary key per view at most.
- **F3** Corners stop at the chiclet's cap whatever radius is asked for (`Chiclet`: `min(radius, …)`); the value lives in `tokens.json › chiclet`.

**States**
- **S1** Rest: the top on its edge.
- **S2** Pressed: the key and its label drop onto the edge, the top darkens, the edge is hidden. Released, it comes back. Timings: `tokens.json › chiclet`.
- **S3** Latched on: the top sits down on its edge in the control grey, no edge showing, and stays there.
- **S4** Disabled: no top and no edge, a thin outline; the label in the tertiary grey.
- **S5** Selected: elevation 2, the selected surface, its ring and its soft shadow.
- **S6** Primary: the top in the text colour, a dark label, a lighter edge. Pressed, the top dims.
- **S7** LED lit (the given colour, the text colour by default) or unlit (the off grey).
- **S8** Segmented keys: the chosen segment raised with a semibold label; the others flat in the secondary grey; a disabled one in the tertiary grey. Nothing chosen (`selected` −1): all flat.
- **S9** Toggle key off: raised, LED unlit, regular name. On: latched, LED lit, semibold name. Disabled: the tertiary grey.
- **S10** Icon key off: the outline symbol in the secondary grey, no key behind it. On: the filled symbol in the text colour on a latched key. Disabled: the tertiary grey.
- **S11** Stepper: − disabled at the bottom of its range, + at the top; the value reads "–" when the stepper is disabled.
- **S12** Effect chip: one look; pressed, it sinks as a key does.
- **S13** More chip: "+N" for the rest; with `countOnly`, the whole list's count, no "+".

**Behaviour**
- **B1** A press sinks the key at once; release lifts it. A latched key stays down while on.
- **B2** Disabled comes from the environment (`.disabled`): the key and label change together.
- **B3** An effect chip selects its track and opens the sound panel at that effect's page; with the screen link on and following, the FM-1 goes there too.
- **B4** A chip row fits as many chips as its width allows; when more don't fit, the last place is "+N".
- **B5** The more chip lists the rest; each item opens its own panel (they can sit under different families: FX, SEL, ARP).
- **B6** A stepper key moves the value one step, clamped to the range.

**Content**
- **C1** Effect chips, and only these (Skiff, per track): ARP (its mode, "ARP UP"), CHORD (its name, "MAJ7"), SCALE (its name, with QUANTIZE on), SLICE, DUCK, FOLLOW. Each has its symbol first.
- **C2** Drum tracks show no ARP, CHORD, SCALE or FOLLOW chips.
- **C3** Spoken chip names say what the word abbreviates: "Arpeggio, up", "Chord, maj7", "Scale, minor", "Slicer, …", "Ducks under …", "Chord follow on".

**Accessibility**
- **A1** On is never told by position alone: a latched key pairs with a lit LED or a label change (`LatchedKey` comment); an icon key changes shape and brightness (outline to filled, grey to white).
- **A2** Toggle and icon keys: label the name, value "on" or "off", the toggle trait.
- **A3** Segmented keys: one container labelled with the choice's name; the chosen segment carries the selected trait.
- **A4** Stepper: one adjustable element (VoiceOver swipe up and down), its value spoken; "Lower …" and "Raise …" on the keys. A number set with taps, no drag needed (WCAG 2.5.7).
- **A5** LEDs are hidden from VoiceOver; the key they sit on says on or off.
- **A6** Effect chip: label the spoken name, hint "Opens its panel". More chip: "N more effects" (or "N effects"), its value the list, hint "Lists them; each opens its panel".
- **A7** A chip is words with a symbol, never colour alone (Scott, 2026-11-10, board 46).
- **A8** Reduce Motion: the sink isn't animated; the key drops and lifts at once. `[review]` `DESIGN.md` says Reduce Motion never means "pop"; whether a press counts is unasked.
- **A9** `[review]` A chip's touch area reaches a little past the drawn chip but stays under the 44 pt aim; neighbours sit close.
- **A10** `[open]` Disabled labels use the tertiary grey, under 4.5:1 (accessibility P9; disabled text is exempt, but some tertiary text is information).
- **A11** `[open]` Increase Contrast isn't read (accessibility P11).

**Integration**
- **I1** Effect chips come from `TrackChips.of`: the per-track effects a pad's own sound never changes (Skiff `params.c` `param_kept`). Skiff only.
- **I2** A chip opens the page by its id (`SoundPage.reached`), else the family's first page.
- **I3** `[open]` Android's `Key` draws a latched toggle in the primary look (a white top); iOS latches it down in the control grey. Decisions 31–33 don't name a keeper for keys.

### Ruled out

- The physical look the flat one was tried against: removed, flat chosen (Scott, 2026-11-06).
- Elevation at other strengths: locked at medium (Scott, 2026-11-05).
- A soft shadow on keys: a chiclet's edge is an offset shape; only panels, the selected thing and menus carry a shadow (`Theme.swift`, after panels slid at a low frame rate with one shadow per key, 2026-11-02).
- An LED on the top row's icon keys: the row's only text buttons are the tabs (2026-11-03, `IconKey` comment).
- − / + steppers on the phone: slide on the control instead (Scott, 2026-11-13, decision 10). Steppers stay on the iPad where they're used.

### Out of scope

- The knob tile and its slide: `column-face.md`.
- Faders: `faders.md`.
- The top row's tab rise and transport: `top-row.md`. The phones' round keys and words: `phone-header.md`.
- Track chips and the heads' big chips (`TrackChip`, `BigTrackChip`): `track-head.md`. Menu chips: `hold-menus.md`.
- Pads: `pattern-pad.md`.

## 2. Design

Board 46 (where the effect chips go, `design/boards/chips.py`). The key's numbers: `tokens/tokens.json › chiclet` and `Theme.swift`.

### Decision log

- 2026-11-05: the flat look, elevation as the sign of selection, locked at medium (Scott).
- 2026-11-06: flat chosen over the physical look (Scott).
- 2026-11-10: effect chips as words with a symbol first, opening the sound panel at their page (Scott, board 46).

## 3. Build notes

- The press is passed down as an environment value (`keyPressed`), set by `PressSink`, so the chiclet under the label knows it's pressed.
- `raisedKey()`'s default radius is above the cap, so every key draws at the cap (see F3).
- `MoreChips` uses SwiftUI's `Menu`, not Lupe's own menus (`Menus.swift`). `[open]` Intended?
- Android's counterpart is `Key` in `Components.kt`: the same chiclet and press timings, a touch target of at least 48 dp around a smaller drawn key.

### Decision log

## 4. Usage

- Pressable: `raisedKey()` with `PressSink()`. A toggle: `latchedKey(on)` with `PressSink(latched: on)` and an LED or a label change. One of several: `SegmentedKeys`, or `selectedKey()` for the current one.
- A key that sits on a raised surface still uses the same chiclet; don't invent a lighter key.
- A state that needs to be read at a glance (playing, waiting, muted) is not a key state: it belongs to the pad or the head.

---
component: Faders
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code and the Mixer QA notes; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/Faders.swift          # Fader (vertical, horizontal), LevelLine
  - ios/FM1/MixerPanel.swift      # the iPad's strips: LEVEL with its line, PAN, the REVERB send
  - ios/FM1/PhoneMix.swift        # the iPhone's rows: LEVEL, PAN and the send, all across
  - android/app/src/main/java/com/scottgerstl/lupe/ui/mix/MixPage.kt   # Android's LevelFader (branch claude/android-p2-shell-02c86f)
boards: ["qa/mixer-redesign-2026-11-05/README.md", "qa/mixer-meters-2026-11-06/README.md"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=12-193   # Fader (vertical)
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=12-224   # Fader (horizontal)
---

# Faders

> **Under revision (2026-11-14):** on the phones, LEVEL and PAN live in the Mix pop-up and the track head's hold menu (decision 31 in the vault's `phone-skiff-decisions-2026-11-12.md`; decision 14 had put PAN in the row's hold menu). The iPhone's Mix tab becomes the pop-up, drawn as Android's (build plan). Android's level fader turns by the Slide to turn setting with the Magnifier (`MixPage.kt` `LevelFader`); the iPad and iPhone `Fader` follows the finger. `[open]` Which fader behaviour the phones keep, and what draws LEVEL and PAN in the hold menu, isn't decided. Section 1 is the iPad and today's iPhone.

## 1. Requirements

### Purpose and scope

The Mix tab's sticky fader (Scott, 2026-11-05: simpler than the knobs' hold-then-drag): it takes the finger at once and follows it. Vertical for a track's LEVEL, with the track's level line beside it; across for PAN and the REVERB send. Where it sits: `structure-map.md`, "Tabs" (Mix).

It isn't a knob: the knobs' columns, with their slide setting and Magnifier, are `column-face.md`.

### Anatomy

Names as in the code.

- **fader** (`Fader`), **vertical** or **horizontal** (`Axis`).
- **track**: the capsule it runs in.
- **fill**: the tint, from the foot (vertical), from the left, or from the centre for a value centred on zero.
- **cap** (vertical) / **knob** (horizontal): the thing under the finger.
- **detent marks**: where the default sits (LEVEL's 0 dB): two ticks either side of a vertical track, one tick across a horizontal one.
- **readout**: the value, under a vertical fader, at the right of a horizontal one's **label**.
- **level line** (`LevelLine`): the thin meter just right of a vertical fader's cap, the track's height.

### Requirements

**Functional**
- **F1** A fader shows one value as a fill and a cap or knob on a track, with its readout.
- **F2** A vertical fader may carry a level line; a horizontal one never does.
- **F3** The mark sits at the given detent, else at the default; none when neither exists.

**States**
- **S1** Rest: the fill in the tint (the track colour), the cap or knob in the text colour.
- **S2** Muted (set by the caller): the fill in the tertiary grey; the level line dimmed.
- **S3** Held: the readout inverted (dark on the text colour), as the knobs' bubble in place.
- **S4** A vertical fader at its minimum: the readout in the tertiary grey ("OFF").
- **S5** Level line: rises with the level and falls with the meter's own fall while the track sounds; muted, it shows the notes' activity, dimmed.
- **S6** Level line under Reduce Motion: steady while the track sounds, no pulse.

**Behaviour**
- **B1** The fader takes the finger as soon as it touches; the strips don't scroll, so there's no scroll to wait out (`qa/mixer-redesign-2026-11-05/README.md`).
- **B2** One point of finger moves one point of travel, from wherever the value was. Touching the cap keeps it under the finger; touching the track moves the value from where it was, never jumping to the finger.
- **B3** A touch that barely moves is a tap: it nudges one step toward the side of the cap that was tapped (LEVEL's step is one dB).
- **B4** Double tap: the default.
- **B5** A light haptic at either end and on reaching or crossing the mark.
- **B6** Every touch tells the strip (`touched`); linked, the strips' page goes to the FM-1.
- **B7** A horizontal fader's label row takes the finger too.

**Content**
- **C1** LEVEL's readout in dB ("−3 dB"), "OFF" at the minimum.
- **C2** PAN's readout: "C", "L50", "R100". The send's: its value.
- **C3** Horizontal labels in small capitals ("PAN").

**Accessibility**
- **A1** One element: label the name capitalised, value the spoken form.
- **A2** Adjustable: VoiceOver swipe up and down moves it by its step. Action: "Reset to default".
- **A3** A finger can change it without dragging: tap to nudge, double tap for the default (WCAG 2.5.7).
- **A4** The readout and the level line are hidden from VoiceOver; the fader speaks its value (`qa/mixer-meters-2026-11-06/README.md`).
- **A5** Muted is not told by the grey fill alone: the strip's MUTE key latches with a lit LED and the word MUTE (accessibility audit, "Not colour alone").
- **A6** `[open]` The minimum's readout in the tertiary grey is information under 4.5:1 (accessibility P9).
- **A7** `[review]` The horizontal fader's touch height and how quick PAN feels across its short travel (`qa/mixer-redesign-2026-11-05/README.md`, "Not checked").

**Integration**
- **I1** LEVEL, PAN and the send are the FM-1's live track settings; a drag writes as it goes.
- **I2** The level line follows the FM-1's MIXER (`ui_graph.c` `draw_tracks`), from `TrackMeters`; it redraws only while something sounds.
- **I3** The iPhone's Mix rows use horizontal faders for all three, LEVEL included (`PhoneMix.swift`).

### Ruled out

- The knobs' hold-then-drag on the Mixer: sticky faders instead (Scott, 2026-11-05).
- A tap that jumps the value to the finger: a stray touch that jumps a fader is a loud surprise while the FM-1 plays; a tap nudges, and the double tap is the big move (the building session, `qa/mixer-redesign-2026-11-05/README.md`).

### Out of scope

- The Mixer strips' layout, MUTE keys and effect cards, and the iPhone's rows: `mix.md`.
- The Mixer's cards (DELAY, REVERB, CHORUS, GLOBAL): `mix.md`; their knobs, `column-face.md`.
- The meter's data: `TrackMeters`.

## 2. Design

No board; the look was settled in the build (`qa/mixer-redesign-2026-11-05/README.md`, `qa/mixer-meters-2026-11-06/README.md`).

### Decision log

- 2026-11-05: sticky faders, LEVEL up and down, PAN and the send across (Scott asked for simpler than the knobs).
- 2026-11-06: the level line beside LEVEL, as the FM-1's MIXER draws it.

## 3. Build notes

- While one fader drags, only its strip redraws; each strip is an Equatable view of its own values (`qa/mixer-redesign-2026-11-05/README.md`).
- The level line draws on a timeline paused while nothing sounds, so a strip's body never redraws for it.
- Device check: `2026-11-10-sloop-design-pass.md` 9 (LEVEL on SLOOP).

### Decision log

## 4. Usage

- Use a fader for a mix value on a strip that doesn't scroll. Inside a scrolling page, or for one of the FM-1's four knob values, use a column (`column-face.md`).
- Pass the muted tint from the caller; the fader doesn't know about mute.

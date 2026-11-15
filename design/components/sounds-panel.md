---
component: Sounds panel
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/PresetsPanel.swift    # PresetsPanel (the panel), EntrySoundNone (the entry banner)
  - ios/FM1/Library.swift         # LibraryPage (presets, kits, user slots), LibraryEngines (the engine list), UserSlotMore, SoundRefusalNote
  - ios/FM1/SampleSlots.swift     # SampleSlotList: the Your samples rows
  - ios/FM1/PhoneBrowse.swift     # iPhone: PhoneBrowse (the Sounds tab), PhonePresetsPopover
  - ios/FM1/AppView.swift         # where the iPad places it
  - ios/FM1/DeviceFollow.swift    # SkiffNavigator.save: SAVE's steps
  # Android (branch claude/android-p1-core-link-faf639, not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/sounds/SoundsBrowser.kt
  - android/app/src/main/java/com/scottgerstl/lupe/ui/sheet/Sheet.kt
boards: [66, "design/boards/phone-portrait-2.html", "design/boards/phone-consolidation.html (row 10)"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=17-161   # Engine row
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=17-174   # Preset key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-341   # Sheet header · Phone, "Title and actions"
---

# Sounds panel

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

*Not the sound panel (ENV, LFO…; `sound-panel.md`). This one picks which sound a track, pad or block plays. In code it's still `PresetsPanel` and `ui.presetsPanel`.*

> **Under revision (2026-11-14):** on both phones the browser is Android's **sheet**, opened from the track head's hold menu and from SAVE on the FM-1. The iPhone's Sounds tab goes (decision 33, vault `phone-skiff-decisions-2026-11-12.md`; build plan `phone-consolidation-build-plan-2026-11-14.md`, row "Sounds"). On a drum track a pad's hold menu › Select sound overrides that one pad, marked (decision 15). Android's sheet as built: engines down the left, then User and its 32 slots; presets two to a row; a tap loads at once; Save puts the track's sound in a user slot, asking in place over a used one; Done or Back closes it (`SoundsBrowser.kt`). Section 1 below is the iPad's panel and today's iPhone.

## 1. Requirements

### Purpose and scope

Picks a sound by name instead of scrolling for it on the FM-1: an engine's presets, a drum kit, one of the 32 user slots, a user sample, or a pad's or block's own sound. Tapping one loads it at once, so it's heard while choosing. It comes in from the right over the page, which stays live.

It doesn't shape the sound (the sound panel does) or record samples (the sampler). Where it sits and every way in: `structure-map.md`, "Tabs" (the paragraphs on the Sounds panel and Your samples). The iPad has no Sounds tab (Scott, 2026-11-10).

### Anatomy

Names as in the code.

- **panel** (`PresetsPanel`): the whole thing.
- **header**: the track chip, the **title** ("Choose a sound for Track 5") and **Done**.
- **entry banner** (`EntrySoundNone`): only for a pad's or block's own sound. The words, the explanation under them, and the **check**.
- **engine list** (`LibraryEngines`): "Engines", one **engine row** per engine (LED, name, count), then **User presets** and **Your samples**.
- **preset grid** (`LibraryPage`): the **grid title** and count, then **preset keys** (LED, name, detail) in three columns.
- **user slot**: one of Skiff's 32. Filled, a preset key with a **⋯** (`UserSlotMore`); empty, a dashed key.
- **sample rows** (`SampleSlotList`): the FM-1's user sample slots.
- **refusal note** (`SoundRefusalNote`): the FM-1 kept the track's sound, and why.

Words to retire: "Presets panel", "presets popover", "library" and "Browse" for this panel; "Use the track's sound" for the banner (its meaning is "this entry doesn't change the sound", batch list 2026-11-08).

### Requirements

**Functional**
- **F1** It chooses for one target: the selected track, a pad (a pattern pad's entry) or a block (a Timeline entry).
- **F2** A tap on a preset key loads it at once onto the target. SLOOP keeps the pattern, the mix and the key when a preset loads.
- **F3** The engine list shows the engines the firmware offers. For a track, every engine, an unplayable one greyed with its reason. For a pad or block, only the engines that track can take; the rest are left out, not greyed (Scott, 2026-11-09: "contextually relevant").
- **F4** A drum track shows its kits and no engine list, unless a pad's or block's sound is being chosen.
- **F5** User presets (Skiff): all 32 slots in order. A filled slot loads at a tap; its ⋯ offers Replace with Tn's sound… and Erase…. An empty slot saves the track's sound there, its name asked.
- **F6** For a pad's or block's sound, User presets offers only the filled slots it can take; saving belongs to the track's panel.
- **F7** Your samples: a synth track's own sound only, on firmware with samples. Each slot puts the track on it, ▶ hears it (Skiff), and Record…, Import file… and Clear… open the sampler. The same rows sit under the Sample engine's sets (structure map, "Your samples").

**States**
- **S1** Closed.
- **S2** Open over a page, at the right edge.
- **S3** Open beside the sound panel: it sits to the sound panel's left, so a sound can be picked and shaped at once (device check `2026-11-09-perform-grid-map.md` 54).
- **S4** Engine row browsing: the selected-key look. The track's own engine has its LED lit.
- **S5** Engine row unplayable: greyed, "not on track 5", disabled (Skiff's light tracks and GRAIN, PHYS).
- **S6** Preset key current: sunk, LED lit in the track colour, name in the heavier weight. Others raised.
- **S7** Empty user slot: dashed outline, ＋, the slot's name and "Empty". Disabled on a drum track.
- **S8** Entry banner checked: "Uses the sound already playing" in the heavier weight; the engine list and grid below are disabled and faded.
- **S9** Entry banner unchecked: the browser is live to pick one.
- **S10** Entry with its own sound: the banner names what it switches to ("This pad switches the track to Acid Bass when it starts. Check to drop it.").
- **S11** Entry banner disabled, with its reason under it: "No song yet", "The FM-1 is disconnected", or the store's refusal.
- **S12** Reading the kits: "Reading the kits from the FM-1…".
- **S13** No user presets yet (SLOOP): "No user presets yet. Save one on the FM-1: SAVE, then the USER page."
- **S14** Refused: the refusal note over the presets until dismissed or after a few seconds.
- **S15** A list cut by its box fades at the cut edge, and its scroll bar flashes when it comes up cut (Scott, 2026-11-06).

**Behaviour**
- **B1** Ways in: the track head's name ⌄ (Pads, Timeline, Mix strips), SAVE (the FM-1's or the function key), the sound panel's Sounds ⌄, a track's hold menu › Select sound, a pad's or block's Select sound (structure map).
- **B2** SAVE steps the FM-1's SAVE pages: the first press opens the panel on presets, the next on User presets, the next closes it and opens the Patterns drawer on Song, the next opens Projects (`SkiffNavigator.save`; device check `2026-11-09-perform-grid-map.md` 50).
- **B3** It closes with Done, SAVE's next press, another tab or Escape (structure map).
- **B4** The page behind doesn't dim and stays live: pads, track heads and the sound panel still answer (Scott, 2026-11-10).
- **B5** The current key stays in view as the FM-1's knob steps through sounds, scrolling the least that brings it in, and never against a scroll made by hand in the last couple of seconds (batch list 1; device check `2026-11-09-lupe-batch-2026-11-06.md` 13, passed 2026-11-11).
- **B6** Entry banner, unchecked to checked with a sound: drops the entry's own sound (sent to the FM-1, may be refused). Checked to unchecked: only opens the browser. A target change resets it.
- **B7** Erase… asks once more in place, naming the slot and its sound (`DESIGN.md`, confirm in place).
- **B8** iPhone: the track menu's Select sound opens a narrower popover from the right over a dimmed page; Done or a tap on the page beside it closes it. The Sounds tab shows the same engines and presets as the page itself.

**Content**
- **C1** Titles: "Choose a sound for Track 5", "Choose a kit for Track 4", "Choose a sound for Pad A on Track 5", "Choose a sound for entry B on Track 5" (the Timeline's word for a block; Scott, 2026-11-08).
- **C2** Preset names capitalised ("Acid Bass"); a user slot's detail is its slot name and engine ("U07 · Analog").
- **C3** Entry banner wording (Scott, 2026-11-09, 72e79a9): "Starting this pad doesn't change the track's sound: the track keeps the one it has, its own or an earlier pad's. Uncheck to give it a sound." An entry's sound carries on after it.
- **C4** Erase confirm: "Erase U07 "Name"", caption "It's removed from the FM-1 for good. Tracks playing it keep their sound."
- **C5** Counts: "128 presets", "of 32 saved", "2 recorded", "n of m slots used".

**Accessibility**
- **A1** The panel is a container labelled with its title; the title is a heading.
- **A2** Not modal: the page stays reachable. Escape and VoiceOver's scrub close it.
- **A3** Preset keys: label the name and detail; the current one has the selected trait; others hint "Loads onto track 5".
- **A4** Engine rows: "Analog, 128 presets, the track's engine", or "Grain, not on track 5"; browsing has the selected trait.
- **A5** Entry check: "Uses the sound already playing", value on or off, toggle trait, hint by state. The disabled browser hints how to open it.
- **A6** Empty slot: "U07, empty", hint "Saves track 5's sound here". ⋯: "Manage Name".
- **A7** The refusal is announced when it appears.
- **A8** Targets: keys and rows at least 44 pt; the check and ⋯ 44 pt.
- **A9** Nothing by colour alone: current has LED, sunk face, weight and trait; an unplayable engine says why.
- **A10** Reduce Motion: it fades instead of sliding; keeping the current key in view jumps.
- **A11** `[review]` iPhone popover with VoiceOver: the dimmed area is a "Close the presets" button; whether focus stays in the popover isn't checked.

**Integration**
- **I1** A pad's or block's sound is Skiff's LIST op 9; the FM-1 loads it as the entry starts, over the track's (launch.c, `EntrySoundNote`).
- **I2** Dropping an entry's sound is checked against the store (`blocked`) and refused while it can't be rewritten.
- **I3** User slots write the FM-1's flash; a sample upload stops Skiff's audio for a few seconds (batch list 3).
- **I4** Skiff 2.5.1 "Keep sends when loading a sound" (Settings) decides whether a load keeps the track's sends (device check `2026-11-11-skiff-2.5.1-support.md` 6).

### Ruled out

- A Sounds tab on the iPad: the browser is the panel, nothing lost (Scott, 2026-11-10).
- Dimming the page behind it on the iPad: the page stays live (Scott, 2026-11-10).
- Greying engines a pad or block can't take: they're left out (Scott, 2026-11-09).
- A two-way switch or a status line with Remove for a pad's sound: the banner with a check at its end (Scott, 2026-11-09, batch list).
- A sound submenu on the pad: Select sound opens this panel, whose title names the pad (2026-11-08, batch list).
- A system alert to erase a slot: confirm in place (2026-11-10).
- Phones: a Sounds tab (decision 33, 2026-11-14).

### Out of scope

- The track head's name ⌄: `PadsTrackStrip.swift`.
- The hold menus that open it: `hold-menus.md`.
- Shaping the chosen sound: `sound-panel.md`.
- The sampler, Record… and Import file…: `SamplerPanel.swift`.
- The save sound name prompt: `SkiffSaveViews.swift`.
- Projects and the Patterns drawer (SAVE's other pages).

## 2. Design

Boards: 66 (`phone-portrait-2.html`, Android's sheet), `phone-consolidation.html` row 10 (iPhone tab and Android sheet side by side). No iPad board found for this panel.

Motion follows `DESIGN.md`. Particular to it: it travels as one piece from the right and, beside the sound panel, moves with the sound panel's slide.

### Decision log

- 2026-11-08: every long press offers Select sound, which opens this panel titled for its target (Scott, batch list).
- 2026-11-09: the entry banner with a check, the wording rewritten (Scott, 72e79a9).
- 2026-11-10: the iPad's Sounds tab goes; this panel replaces it, no dimming, beside the sound panel (Scott).
- 2026-11-11: Your samples in the engine list (batch list 3, built 5f51d14, for Scott to agree).
- 2026-11-14: phones use Android's sheet, from the track head's hold menu and SAVE; no Sounds tab (decision 33).

## 3. Build notes

- Code notes found while writing this, not fixed:
  - `PresetsPanel`'s doc comment says "a tap on the page closes it"; the iPad's panel has no such close (structure map: Done, SAVE, another tab, Escape).
  - `PresetsPanel` sets `.accessibilityAction(.escape)` twice.
  - The iPhone popover doesn't take a pad's or block's target: no entry banner on the iPhone.
- `[open]` Device check `2026-11-09-perform-grid-map.md` 50 expects "Done or a tap beside it closes the panel"; the code and structure map have no tap-beside close on the iPad. Which is meant?
- `[open]` Android's sheet tile ticks track 1's sound under a track 2 title in the consolidation capture (board row 10 note). Fake-core quirk or bug: not checked.

### Decision log

## 4. Usage

- To offer a sound choice from a new place, call `ui.chooseSound(session, track:, entry:)`; it selects the track and sets the target. Don't open the panel by flag alone, or the title and banner lose their target.
- For shaping, not choosing, use the sound panel.

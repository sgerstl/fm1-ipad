---
component: Mix
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/MixerPanel.swift      # MixerPage, MixerDeviceEdge, DeviceEdge, MixerCards, MixRow, MixerStrips, MixerStrip, FlashRing
  - ios/FM1/PhoneMix.swift        # iPhone: PhoneMix, PhoneMixerRows, PhoneMixerRow
  - ios/FM1/Pads.swift            # GLO on the function keys steps the sections
  - ios/FM1/PageGraphs.swift      # DELAY, REVERB, CHORUS, GLOBAL pictures
  # Android (branch claude/android-p1-core-link-faf639, not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/mix/MixPage.kt
  - android/app/src/main/java/com/scottgerstl/lupe/ui/mix/MixModel.kt
boards: [48, 49, "design/boards/phone-skiff.html", 64, 65, "design/boards/phone-portrait-2.html", 77, "design/boards/phone-mix-pictures.html", "design/boards/fm1-screens/", "design/boards/phone-consolidation.html (row 9)"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-278   # Mix strip
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=18-285   # FX page key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-341   # Sheet header · Phone, "Tabs and close"
---

# Mix

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

*The FM-1's GLO pages: MIXER (the six tracks' strips), then the shared DELAY, REVERB, CHORUS and GLOBAL. A tab on the iPad and today's iPhone.*

> **Under revision (2026-11-14):** on both phones Mix stops being a tab and becomes a **pop-up**: GLO on the FM-1 opens it, and so does the project menu; the tabs are Pads · Edit · Timeline (decision 28). The pop-up has **no "Mix" title**; its page tabs sit **in line with the close button**, and the room goes to pictures **redrawn to look like the FM-1's** (DELAY, REVERB, CHORUS, the GLO pages; decision 31). Those pictures come from the FM-1's own drawings, in **greys and white**, since the GLO pages set every track; the per-track FX › DELAY and FX › REVERB keep the track colour (decision 34, board 77). PAN goes in the track row's hold menu and the row stays one level slider (decision 14); LEVEL and PAN live in Mix and the track head's hold menu (decision 31). The iPhone's Mix tab becomes that pop-up with the same drawing; Android drops its title and puts the tabs beside close (build plan `phone-consolidation-build-plan-2026-11-14.md`, row "Mix / GLO"). Decisions: vault `phone-skiff-decisions-2026-11-12.md`. Section 1 below is what's built: the iPad's tab and the iPhone's.

## 1. Requirements

### Purpose and scope

Levels, pans and the reverb send for all six tracks at once, and the shared effects every track sends to. It mirrors the FM-1's GLO pages, so GLO on the FM-1 lands here and steps through them, and what's picked here shows on the FM-1.

It is not where one track's sound is shaped (the sound panel) and not the track head's own controls. Where it sits: `structure-map.md`, "Tabs" (iPad) and "The phone with a Skiff FM-1" › Mix (iPhone).

### Anatomy

Names as in the code.

- **page** (`MixerPage`): the tab. The **strips panel** on top, the **effects row** under it.
- **strips** (`MixerStrips`): six **strips** (`MixerStrip`) side by side.
  - **head**: the compact track head (`TrackStripRow`) with name ⌄, what it plays, pass bar, Mute and Solo. Older firmware without Skiff's song: a **name key** and a **MUTE key** instead.
  - **level fader**: LEVEL, vertical, with the **meter** (`LevelLine`). See `faders.md`.
  - **pan fader** and **send fader** (REVERB, the only send shown), across. See `faders.md`.
- **device edge** (`MixerDeviceEdge`): the strips panel lit along its top while the FM-1 shows MIXER.
- **effects row** (`MixerCards`): the **selector** (Delay, Reverb, Chorus, Global) beside the **carousel** of effect **cards** (the sound panel's `SoundCard`; columns: `column-face.md`).
- iPhone (`PhoneMix`): the **selector** down the left (Mixer, Delay, Reverb, Chorus, Global) and one page beside it: **mixer rows** (`PhoneMixerRow`) or one card.

Words to retire: "mixer panel" and "mixer key" (the tab replaced them, 2026-11-05); "sections" for the cards in prose (the code's `mixerSection` stays).

### Requirements

**Functional**
- **F1** All six tracks' strips are in view at once on the iPad, and don't scroll, so a fader takes the finger at once.
- **F2** Each strip sets its track's LEVEL, PAN and REVERB send.
- **F3** The four shared effects are cards with their four columns, page settings and picture, as in the sound panel.
- **F4** Every track's REVERB is read when the tab opens and again every few seconds while it's up; the protocol doesn't push another track's parameters.
- **F5** The Mix tab is full width, with no left column: a strip's head selects its track (Scott, 2026-11-06).

**States**
- **S1** Selected strip: its background tinted with the track colour; others in the well.
- **S2** Muted strip: the level fader and meter in the tertiary grey.
- **S3** The FM-1 on MIXER: the device edge lit.
- **S4** Centred card: full size, the selector's word lit with the selected-key look. Neighbours smaller, partly in view.
- **S5** A card the FM-1 shows: its forward lift and badge, counted as GLO's five ("DELAY 2/5").
- **S6** The sound panel open over Mix: the strips and carousel narrow at once to make room, and widen when it closes.
- **S7** Older firmware: name key and MUTE key with LED, no Solo.
- **S8** iPhone: the lit selector key is the page on screen.

**Behaviour**
- **B1** GLO (the FM-1's or the function key) opens Mix on MIXER; pressed again, it steps MIXER, DELAY, REVERB, CHORUS, GLOBAL, round. Linked, the FM-1 shows the same page.
- **B2** Touching a strip's control shows MIXER on the FM-1.
- **B3** A tap on a selector word brings that card to the middle and, linked, its page to the FM-1.
- **B4** A swipe on the carousel lands on the card it started from or one either side, never further (Scott, 2026-11-06: "it too easily flings past the next pane"). A flick goes one on; a slow release goes to the nearest.
- **B5** The card in the middle becomes the current page once the swipe settles, and its page goes to the FM-1.
- **B6** A slide on a card's column turns the value; the carousel moves only from elsewhere on the card.
- **B7** A tap anywhere on a side card brings it to the middle; its columns work once it's there.
- **B8** A strip head: tap selects the track; its name ⌄ opens the Sounds panel; hold opens the track's menu; Mute is PERFORM's, at the launch point while playing (Scott, 2026-11-10).
- **B9** iPhone: one page at a time; the selector shows it; GLO steps them. No swipe between pages: a slide on a column turns it (structure map).

**Content**
- **C1** LEVEL reads as Skiff writes it: dB, "0 dB" at unity, "OFF" at zero. PAN: "C", "L50", "R100".
- **C2** No headings and no section list over the strips or cards: they speak for themselves, the selector says which card is in the middle (Scott, 2026-11-06).

**Accessibility**
- **A1** Each strip is a container. The head (older firmware's name key) reads "Track 3, Name", hint "Selects the track", selected trait.
- **A2** MUTE key: "Mute track 3", toggle, value "muted" or "playing". Mute and Solo on the head: the track head's.
- **A3** Faders: label, value and adjustable action per `faders.md`.
- **A4** Selector words: "Delay, shared effect 1 of 4", selected trait on the centred one.
- **A5** The strips panel has a "Show on the FM-1" action; the device edge is hidden.
- **A6** A side card's tap catcher is hidden; its card stays readable.
- **A7** Reduce Motion: the carousel's snap and the selector's change happen without the spring.
- **A8** `[review]` iPhone: VoiceOver waits for the release pass (`2026-11-10-phone-pads-edit-mix.md`, "VoiceOver").

**Integration**
- **I1** GLO's pages are Skiff's MIXER, DELAY, REVERB, CHORUS, GLOBAL (`SkiffButtonMap.MixerTab`). SLOOP has no MIXER page: touching its strips leaves the FM-1 where it is.
- **I2** Meters come from Skiff-Lupe's METER firmware build (per-track levels).
- **I3** GLO › DELAY's MODE on Skiff 2.5.1 is a page setting on the Delay card (device check `2026-11-11-skiff-2.5.1-support.md` 5).

### Ruled out

- A mixer panel at the bottom and a mixer key beside the tempo: the tab replaced them (Scott, 2026-11-05: "we might want a mixer tab").
- Dots and section names for the carousel: the selector down the left (Scott, 2026-11-06).
- Headings over the strips and cards (Scott, 2026-11-06).
- A strip's own MUTE on Skiff: the track head's Mute and Solo, for consistency (Scott, 2026-11-10).
- The iPad's Mix as it is on the phone: strips under the top bar, cards over the strips, the foot off the screen (structure map, `qa/accessibility-2026-11-10/screens/iPhone-skiff-mix.jpg`).
- Phones: a Mix tab (decision 28, 2026-11-14).
- Phones: a "Mix" title on the pop-up (decision 31, 2026-11-14).
- Phones: GLO pictures in the track colour, gradients or fades the FM-1 doesn't draw (decision 34, 2026-11-14).

### Out of scope

- The faders and meter: `faders.md`.
- The cards' columns: `column-face.md`.
- The cards themselves and the per-track FX pages: `sound-panel.md`.
- The track head (Mute, Solo, name ⌄): `PadsTrackStrip.swift`.
- The track head's hold menu (PAN on the phones): `hold-menus.md`.

## 2. Design

Boards: iPhone 48–49 (`phone-skiff.html`); Android 64–65 (`phone-portrait-2.html`); the pop-up's pictures, board 77 (`phone-mix-pictures.html`), drawn from the FM-1's own screens (`design/boards/fm1-screens/`, formulas with file and line in its NOTES.md); `phone-consolidation.html` row 9 (iPhone tab and Android sheet side by side).

Motion follows `DESIGN.md`. Particular to Mix: the carousel snaps with a short spring and a hint of bounce; the strips never move while the sound panel slides (S6).

### Decision log

- 2026-11-05: GLO's pages as a Mix tab (Scott).
- 2026-11-06: full width, no left column; no headings; the selector in place of dots; one card per swipe (Scott).
- 2026-11-06: shared pages drawn grey, their white parts kept for contrast (Scott, `PageGraph`).
- 2026-11-10: strip heads are the compact track head (Scott).
- 2026-11-10: the iPhone shows one GLO page at a time, picked down the left (Scott, boards 48–49).
- 2026-11-13: Android's PAN in the row's hold menu (decision 14).
- 2026-11-14: phones get a pop-up, not a tab (decisions 28, 31); its pictures redrawn from the FM-1's, in greys (decision 34).

## 3. Build notes

- Fixed sizes for strips and cards: with flexible stacks a value turning on a card re-measured the whole tab every frame, up to 233 ms hitches on the iPad Air (Instruments, 2026-11-06).
- All four cards are built at once, not lazily: lazy building cost 70–85 ms per swipe (Instruments, 2026-11-06).
- Each strip redraws only when its own row changes (`MixRow`, `MixerStrip` is `Equatable`).
- Device checks: `2026-11-09-lupe-batch-2026-11-06.md` 14 (meters, Reverb, a swipe lands at most one card away; no result recorded); `2026-11-09-perform-grid-map.md` 43 (strip heads; the run's 1–49 not recorded).
- Code note found while writing this, not fixed: `MixerCards`' doc comment gives the snap as a 0.4 s spring at 0.82 damping; the code uses a shorter, stiffer one.
- `[open]` Android's mixer shows level and send only (two columns of rows); the iPhone shows level, pan and send on every row. With decisions 14 and 31, which controls does the pop-up's mixer row carry?
- `[open]` Global differs: BPM and swing tiles on the iPhone, tempo, swing, master and transpose dials on Android (board row 9). Which set?
- `[open]` Does anything change on the iPad's Mix? Decision 34's grey redraw is phone-scoped in the decisions; the iPad already draws shared pages grey.

### Decision log

## 4. Usage

- To bring the user to the mix, drive `ui.mixerSection` and `ui.page` the way GLO does (`FunctionPads.press(.glo)`), so the FM-1 follows.
- A new per-track control belongs on the strip only if the FM-1's MIXER page has it; otherwise it goes in the track head's hold menu.

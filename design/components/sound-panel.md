---
component: Sound panel
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/SoundPanel.swift      # SoundPanelControl, SoundRail, SoundPanel, SoundPanelHost, SeqKey
  - ios/FM1/Sound.swift           # SoundPage, ShapeSection, SoundCard, CardHeader, RowKey, CardForward, ShapeMarks
  - ios/FM1/Pads.swift            # FunctionPads, PadSurface (the FM-1's 12 keys)
  - ios/FM1/PageGraphs.swift      # PageGraph and the per-page pictures
  - ios/FM1/Graphs.swift          # EnvelopeGraph, LFO wave
  - ios/FM1/PhoneAppView.swift    # the iPhone hosts the same panel over its Skiff tabs
  - ios/FM1/Settings.swift        # SoundButtons, Handedness
  # Android (branch claude/android-p1-core-link-faf639, not on the trunk):
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/SoundPanelModel.kt
  - android/app/src/main/java/com/scottgerstl/lupe/ui/page/SoundPage.kt
boards: [21, 22, "design/boards/panel.py", 75, "design/boards/phone-edit-panel.html", "design/boards/phone-consolidation.html (row 7)"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=17-13    # FM-1 function key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=17-19    # Sound page tab
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=17-140   # Sound card
---

# Sound panel

*Not the Sounds panel (the browser, `sounds-panel.md`). This one shapes the selected track's sound, one FM-1 button's pages at a time.*

> **Under revision (2026-11-14):** both phones take the iPad's panel rule (decision 32, vault `phone-skiff-decisions-2026-11-12.md`; build plan `phone-consolidation-build-plan-2026-11-14.md`, row "Sound panel"). A sound key, the FM-1's or the rail's, slides the panel in from the right, about a third of the width. It stays until HOME, its close arrow or another tab. The same key again steps its pages. The page beside it stays live. Android's 8 s pop-up timeout goes. Contents stay decisions 25, 27 and 30: four dials labelled with the page ("FX 1/7 FX"), tiles only where a knob picks from a list of names, and the page's picture under the dials when Settings › Show graphics is on (on by default). **Settings › Sound keys** (off by default) adds a rail down the right edge, FX SEL ENV LFO EDIT ARP; off, the FM-1 drives (decision 27). The iPhone narrows its current panel to that third, four dials plus picture, tinted; Android drops the timeout and docks the panel. Edit's docked panel: board 75. Not checked: 16 steps beside the rail at the iPhone's width (decision 32). Section 1 below is the panel as built on the iPad and iPhone today.

## 1. Requirements

### Purpose and scope

Shapes the selected track's sound without leaving the page. One FM-1 button's pages (FX, SEL, ENV, LFO, EDIT, ARP) come in from the right over Pads, the Timeline, Mix and the Sounds panel's page, as the FM-1's own screen shows them: four columns per page and the page's picture. The FM-1's buttons drive it, and it drives the FM-1 back over the screen link.

It is not the browser (the Sounds panel), not the GLO pages (Mix) and not SEQ's places (the editor). Where it sits and which FM-1 button opens what: `structure-map.md`, "Tabs" and "The FM-1's buttons".

### Anatomy

Names as in the code.

- **panel** (`SoundPanel`): the column that slides in from the right.
- **host** (`SoundPanelHost`): lays the page, the panel and the rail side by side.
- **header**: the family's name, "Tn Name · N pages", the **save sound key** (`SaveSoundKey`, Skiff) and the **close arrow**.
- **page words** (`pageChips`): the family's pages as plain words, the lit one with a line over it. Shown when there's more than one page.
- **sound row**: the track chip, the sound's name and engine, and **Sounds ⌄**.
- **cards** (`ShapeSection` with one column, `SoundCard`): one per page, or one per merged set (LFO with LFO 2, EDIT 1 with EDIT 2).
  - **card header** (`CardHeader`): LED, title, the **badge** ("On the FM-1 · 2/3") and the scope words ("all tracks", "send: this track · bus: all tracks").
  - **columns** (`ColumnFace`, see `column-face.md`): the page's four knobs, numbered 1–4.
  - **row keys** (`RowKey`): on a merged card, which row the FM-1's knobs turn.
  - **page setting** (`PageSetting`): a choice that isn't a knob (GLO › DELAY's MODE).
  - **picture** (`PageGraph`): the page drawn as Skiff draws it.
  - **forward card** (`CardForward`): the card the knobs work on, lifted and lit along its top.
- **function keys** (`FunctionPads`): the FM-1's 12 buttons in two rows at the panel's foot, in its order. Only when the rail is off.
- **rail** (`SoundRail`): FX SEL ENV LFO EDIT ARP and **SEQ** (`SeqKey`) down the side. Settings › Sound buttons.

Words to retire: "Shape" for the panel (the old tab's name), "chips" for the page words, "pads" for the function keys (the pattern pad is something else).

### Requirements

**Functional**
- **F1** The panel always shows the selected track's sound.
- **F2** It opens on one family's pages: FX, SEL, ENV, LFO, EDIT or ARP. GLO and SEQ never open it.
- **F3** A family the track's engine has no pages for opens nothing: its keys are disabled, and the FM-1's press of it does nothing in Lupe (Scott, 2026-11-06).
- **F4** Selecting a track whose engine lacks the open family's pages closes the panel. It is never empty because of a track change.
- **F5** The cards are the page's own columns in Skiff's page order. MOD, LANES, LANE MIX, SOUND, SAMPLES, OPERATOR and ALL OPS draw their own column sets; SLICES adds a note.
- **F6** Pictures exist for ENV, ENV 2, LFO, LFO 2, LFO DEST, MOD, FX, DRIVE, INSERT, INSERT 2, SLICER, DUCK, DELAY, REVERB, CHORUS, GLOBAL, VOICE, ARP, ARP 2, SCALE, CHORD, FOLLOW, and EDIT 1 where its engine has one (`PageGraph.has`). The rest have none.
- **F7** Save sound (Skiff): the header's key saves the track's sound to a user slot, its name asked.

**States**
- **S1** Closed: no panel; the page has its full width.
- **S2** Open, one page: no page words.
- **S3** Open, several pages: page words; the lit word is the FM-1's page when linked, else the one focused here.
- **S4** Forward card: the FM-1's page when linked, else the one focused here. Lifted, lit along its top, its LED on, the badge saying where it is in the FM-1's count.
- **S5** A column of the knob just turned (here or on the FM-1) is white for as long as Skiff lights it.
- **S6** Columns of a shared page (scope 1) are white, not the track colour. FX › DELAY and FX › REVERB mix the two and say so.
- **S7** Recording knob moves: the track's columns ring red.
- **S8** A merged card's row keys: the focused row's key filled, the others plain.
- **S9** Empty family: "Tn's engine has no ENV pages." (reached only when opened by a redirect; F3 stops the keys).
- **S10** Pictures don't draw while the panel slides in; they appear once it has settled.
- **S11** Function keys: active (its pages open, or its screen up) latched down and lit; usable with no pages dimmed; unusable (Skiff, no pages for this engine) flat, no edge, disabled. PLAY reads STOP while playing; REC's LED is lit while recording.
- **S12** Rail keys: open lit as the selected key; no pages flat and dim, disabled; otherwise raised.
- **S13** Flush: with no rail on the right, the panel runs to the screen's edge, square on that side.

**Behaviour**
- **B1** A family key (rail, function keys or the FM-1) opens the panel on that family's first page; linked, the FM-1 goes there too.
- **B2** The open family's key again steps to its next page, round and round, counted from the FM-1's page when linked. It never closes the panel (Scott, 2026-11-05).
- **B3** Another family's key switches the panel to that family.
- **B4** The FM-1 moving to a sound page opens the panel there, on any tab the host is on. HOME on the FM-1 closes it.
- **B5** The close arrow or Escape closes it and sends the FM-1 back to the tab's own place: HOME on Pads and the Timeline, GLO's page on Mix (Scott, 2026-11-06).
- **B6** Another tab closes it without moving the FM-1.
- **B7** The page beside the panel stays live. A tap on the page is the page's and never closes the panel (Scott, 2026-11-06).
- **B8** On Pads and the Timeline the panel lies over the page, which keeps its width (Scott, 2026-11-06). On Mix and the Sounds panel's page, the page makes room at once, not animated.
- **B9** A tap on a page word focuses that page; its card scrolls to the top and comes forward; linked, the FM-1 shows it.
- **B10** A tap on an inactive card, or a touch on one of its columns, makes it the active page, on the FM-1 too.
- **B11** A row key puts the FM-1's knobs on that row.
- **B12** MOD's route and an engine page's knob-1 pick follow the FM-1's cursor where the link carries it, and send it back when picked here.
- **B13** ENV and ENV 2's three handles drag. Each handle is its own target; a drag elsewhere on the picture scrolls the panel.
- **B14** Sounds ⌄ opens the Sounds panel for the track, to the panel's left.
- **B15** The rail sits on the playing hand's side (Settings › Handedness); the panel still comes in from the right.
- **B16** Function keys: the families do B1–B3; GLO opens Mix and then steps its sections; HOME closes the panel and takes the FM-1 home; SAVE steps the FM-1's SAVE pages (presets, user, patterns, project; see `sounds-panel.md`); SEQ steps the Song tab's places (NOTES, FEEL, PATTERN, AUTOMATION, SONG); PLAY and REC are the transport.
- **B17** SAVE held is the song layer. The release after the hold is not a press.
- **B18** The rail's SEQ closes the panel and steps the same places; from another tab it goes to the Song tab first, on NOTES.
- **B19** iPhone: the rail's keys share the height; SEQ goes to the Edit tab.

**Content**
- **C1** Header: the family as the FM-1 names it ("ENV"), then "T1 Acid · 3 pages".
- **C2** Page words are the FM-1's page titles, the engine's names for EDIT 1 and EDIT 2.
- **C3** The badge counts as the FM-1's screen counts: "On the FM-1 · 1/7". On Skiff 2.5 INSERT 2 is Lupe's row only and isn't counted.
- **C4** Values read as the FM-1 shows them (`formatValue`).

**Accessibility**
- **A1** The panel is a container labelled "Sound panel, ENV"; its header is a heading.
- **A2** Escape, the hardware cancel key and VoiceOver's scrub close it as the arrow does. The arrow reads "Close the ENV pages".
- **A3** Page words: "DELAY page", the lit one with the selected trait. The trait and the weight say it without the line.
- **A4** Card headers read as one heading, value "on the FM-1" for the forward card; each card has a "Show on the FM-1" action.
- **A5** Row keys: "LFO 2 row", hint "Puts the FM-1's knobs on this row", selected trait when focused.
- **A6** A disabled key's value says why: "No ENV pages on DRUM". Rail keys read "ENV pages", value "open" when open.
- **A7** Function keys read their names in words ("Save", "Stop" while playing, value "recording" on REC).
- **A8** Pictures with a reading: ENV ("attack, decay, sustain, release"), LFO (wave and rate), LFO DEST, MOD (adjustable route, "route n of 11"). `[review]` The other pictures; which are hidden from VoiceOver isn't checked.
- **A9** Reduce Motion: the panel fades instead of sliding; the forward card changes without the lift's ease; card scrolls jump.
- **A10** Targets: keys and the close arrow 44 pt; page words 44 pt tall with their target reaching past the first word's edge.
- **A11** Nothing by colour alone: the lit page has weight, line and trait; the forward card its LED and badge words; a disabled key loses its edge and says why.
- **A12** `[open]` The track colour was tried for the lit page word and failed contrast (code comment, `pageChips`). Colour use in the other pictures hasn't had a contrast pass.

**Integration**
- **I1** Page following runs on the screen link: the FM-1 reports its page and cursor, not its pixels. Lupe sends SCREEN_GOTO when a page is picked here.
- **I2** Skiff's pages come from DESC; Skiff 2.2's numbers, with 2.5.1's FX › DELAY and FX › REVERB translated at the wire (vault decisions, "Where it ended").
- **I3** An engine hides pages as Skiff does (`SoundPage.skiffHides`: no SCL, ENV or VOICE on the one-shot kits; no ENV on FM6).
- **I4** The FM-1's encoder pushes mark knobs through `ShapeMarks` only when the marked knob changes.

### Ruled out

- A ✕ to close: an arrow the way the panel leaves (Scott, 2026-11-06).
- Pin: the page stays live, so Pin had no job and went (Scott, 2026-11-06).
- The same key closing the panel: it steps pages, as the FM-1's does (Scott, 2026-11-05).
- The page narrowing under the panel on the Song tab: it made the timeline lurch; the panel overlays (Scott, 2026-11-06: "I thought the panel was supposed to overlay this page").
- Page words as pills: plain words that light (Scott, 2026-11-06).
- The track colour for the lit page word: 3.4:1 on the panel (code comment, `pageChips`).
- HOME on every dismiss: it left Mix and Sounds on screens that weren't theirs (Scott, 2026-11-06).
- The rail on by default: off, the page gets the width and the panel carries the 12 keys (Scott, 2026-11-08, 49f42cf).
- Phones: the 8 s pop-up timeout (decision 32, 2026-11-14).
- Phones: the sideways-scrolling page row and an always-on button block (decision 27, 2026-11-13).

### Out of scope

- The Sounds browser: `sounds-panel.md`.
- GLO's pages and the strips: `mix.md`.
- The column faces and their slide: `column-face.md`.
- SEQ's places (step inspector, PATTERN, automation): the editor.
- The value loupe, the big control: their own components.

## 2. Design

Boards: 21–22 (`design/boards/panel.py`). Phones: `phone-consolidation.html` row 7 (iPhone panel and Android pop-up side by side), board 75 (`phone-edit-panel.html`, Edit with the docked panel).

Motion follows `DESIGN.md`. Particular to the panel:
- It slides in from the right edge with the page beside it never moving on the Song tab.
- The forward card's lift and top line move together in one blend from the card before (they jumped on separate triggers, 2026-11-06).
- The lit page word's line fades with the word's weight; the word's width is held by the heavier weight, so nothing shifts (Scott, 2026-11-06).

### Decision log

- 2026-11-05: the panel on the Song tab, brought in by the FM-1's buttons or the rail (Scott, boards 21–22).
- 2026-11-05: the same key steps pages (Scott).
- 2026-11-06: the page beside stays live on every tab; Pin goes (Scott).
- 2026-11-06: user dismiss returns the FM-1 to the tab's own place (Scott).
- 2026-11-07: EDIT 1 and EDIT 2 on one card with one picture (Scott, `SoundTab.merged`).
- 2026-11-08: the rail becomes Settings › Sound buttons, off; the 12 keys at the panel's foot (Scott, 49f42cf, 2a8ef5f).
- 2026-11-08: flush to the screen edge when no rail is on the right (Scott: "anchored to the side of the screen, no gap").
- 2026-11-14: phones take the iPad's panel rule, Settings › Sound keys (decision 32).
- 2026-11-14: phones show the picture under the dials with Settings › Show graphics (decision 30, partly reversing 25).
- 2026-11-15: Android's pictures are drawn by Skiff's own code (SkiffDraw, `ios/SkiffDraw`) for GLO's four, FX › DELAY and REVERB, ENV, LFO, and EDIT (OSC, FLT, FM6, the SKIFF scope's sea), only when the FM-1 runs the Skiff-Lupe 2.5.1 build it was copied from; elsewhere the hand-drawn ones. GLO's in the panel's grey ink with white kept (decision 34), track pages in the FM-1's own colours. iOS keeps its hand-drawn pictures until Skiff's authors allow the App Store (Scott, decision 46; verdict `qa/scope-spike-2026-11-15.md`).
- 2026-11-17: **the close arrow goes; the page count takes its place** (Scott: "The count needs to be more visible… We don't need the close button. Let's get rid of that and put the numbers there"). Reverses the 2026-11-06 close arrow. "3 of 7" at the header's right end, 16 pt in the primary text colour, tabular figures; the small count under the title goes. Closing is the swipe (round 7) and, for a single tap (EN 301 549 / WCAG 2.5.1), a **grab handle** on the panel's leading edge (a 4 × 36 bar in the raised grey, a 24 × 48 touch area): a tap closes, a drag swipes. Both now do what B5 says the close arrow did: the panel shuts and the FM-1 goes back to the tab's own place (HOME, or GLO's page on Mix). TalkBack's "Close the sound panel", Back and the FM-1's HOME stay. The step panel gets the same handle; the kit's step panel loses its close key.
- 2026-11-18: **the sound panel keeps its round dials** (Scott picked "A · keep dials"; mock: vault `assets/sound-panel-controls-2026-11-18/`). A deliberate exception to the hybrid tiles: the FM-1's own round knobs turn these values, so the panel shows dials. The step panel and the effect cards use tiles. Every tab (Pads, Timeline, Edit, Mix) keeps the dials.
- 2026-11-18: **the swipe-away follows the finger** (Scott: "a little more reactive to the initiation of the swipe so that it feels more like the panel follows the finger"). Once a drag passes touch slop and is mostly sideways (1.5×, round 7's lock), the panel's x tracks the finger 1:1 from that point. Leftward it resists: a third of the finger, at most 24 dp. Let go past 35 % of its width, or flung right faster than 500 dp/s, and it leaves with the finger's speed, then closes as before (B5). Otherwise it springs back from that speed (spatial spring, small bounce; Reduce Motion: no overshoot, and it still follows the finger). The page beside it doesn't move; a drag on the grab handle is the same drag, and a tap on it still closes. One modifier (`panelSwipe`) for the sound panel and the step panel. Device checks 149–151.
- 2026-11-18: **a sound key opens its panel at once, Pause following or not** (measured with markers: FX tapped right after closing the step panel opened 1.0 s later). The core showed FX within 3–4 ms of the tap; the screen held it. Labs' Pause following was on, so a touch on Edit (closing the step panel) held the panel for 3 s; a page the phone asks for should pass straight through, but the sound keys' page pick (`PickPage`) and GLO's `ScreenGoto` weren't counted as the phone's asks. Now they are (`isPhoneAsk`). Device check 156.
- 2026-11-18: **the sound panel slides as an offset and stays built** (Scott: "Yes, fix it"). Its slide read its animated width in the shell's composition, so the shell and Edit (and Mix) recomposed and re-laid out every frame of the slide (20–30 ms frames). Now Edit and Mix are given the docked width as a target, so they lay out once when it docks or leaves; the panel reads its slide only while drawing; once shown it stays built, waiting a whole width off to the right when closed, with nothing before its moving layer that could take a touch where it rested (the touch count for Pause following moved inside, after the layer). Springs, Reduce Motion's fade, the grab handle and the swipe are unchanged. Tests: `SoundPanelDockTest` (open, close, reopen; taps reach what's under a closed panel; hidden from TalkBack when closed; Edit comes to rest after it docks and leaves). Device check 157.

## 3. Build notes

- `SoundCard` is `Equatable` and its header, badge, row keys and forward lift are views of their own, so a page change on the FM-1 redraws those and not the columns and picture (2026-11-06).
- The forward lift is a shadow on a shape behind the card, not on the content: on the content it was redrawn offscreen every time a picture changed (Reverb, 2026-11-06).
- Mix's and Sounds' room is set at once, never animated: re-laying out the strips and carousel per frame of the slide dropped frames (2026-11-06).
- Device checks: `2026-11-09-lupe-batch-2026-11-06.md` 13 (selected sound stays in view as the knob steps; passed 2026-11-11). `2026-11-11-skiff-2.5.1-support.md` 2–3 (page following both ways on 2.5.1; not recorded).
- Code notes found while writing this, not fixed:
  - `SoundPanelHost`'s doc comment says the page "makes way for the panel, never under it"; the body overlays it on the Song tab (`room = 0`).
  - `MixerPage`'s `soundPanelRoom` comment says the panel is "not yet here" on Mix; AppView hosts it there with `makesRoom: true`.
- `[open]` Decision 32's rail is FX SEL ENV LFO EDIT ARP; the iOS rail adds SEQ. Does SEQ stay on the phones' rail?
- `[open]` Decision 32 names the setting "Sound keys"; iOS and the build plan say "Sound buttons". One name.
- `[open]` With the rail off, the iPad's panel carries the 12 function keys. Decision 27 hid Android's button block. Do the phones' docked panels carry the 12 keys?
- `[open]` Show graphics exists on Android only. On the iPad the pictures are always on; does the setting come to the iPad?

### Decision log

## 4. Usage

- To shape a sound from a new place, open the panel with `SoundPanelControl.press`, never by setting `ui.soundPanel` directly: press handles the disabled family, the FM-1 and stepping.
- To pick a different sound, use the Sounds panel (Sounds ⌄), not this.
- A new page that hosts the panel wraps itself in `SoundPanelHost`; set `makesRoom` only if the page can narrow at once without animating.

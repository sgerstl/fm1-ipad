---
component: Top row (iPad)
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, the structure map and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/TopBar.swift          # TopBar (the row, the FM-1 key, songTabs, skiffTransport, ReadoutLabel, WaitingDot, TabRise)
  - ios/FM1/SongTools.swift       # SongTools, LaunchKey, CancelWaitingKey, TimelineZoom, SongStrip
  - ios/FM1/SkiffArrangeParts.swift   # RefusalLine, shown on the strip
  - ios/FM1/Controls.swift        # IconKey (Keys)
boards: [44, 47, "design/boards/toptabs.py", "design/boards/toprow.py", "qa/top-row-2026-11-10/README.md"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=21-150   # Top row · iPad
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-27    # FM-1 key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-55    # Tabs · iPad
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-70    # Launch key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-79    # Cancel waiting key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-104   # Icon key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-149   # Transport
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=14-165   # Status strip
---

# Top row (iPad)

*The iPad's row above the pages on a Skiff FM-1. The phones' header is `phone-header.md`. SLOOP draws the same row with its own tools (`SloopTools`, `SloopStrip`); not covered here.*

## 1. Requirements

### Purpose and scope

Everything above the Pads grid in one row (Scott, 2026-11-10, board 47 direction b): where you are (the FM-1 and its menu, the tabs), what launches (the tab's tools) and the transport. Under it, a strip says what needs dealing with until it's dealt with.

It is not the place for settings that are set once: those live in the FM-1 key's menu. Where it sits: `structure-map.md`, "Tabs".

### Anatomy

Names as in the code, left to right.

- **FM-1 key** (`connection`): the waiting dot, a short status, a chevron. Opens the FM-1 menu.
- **waiting dot** (`WaitingDot`): an LED, or a small spinner while Lupe waits on the FM-1.
- **tabs** (`songTabs`): Pads · Timeline · Mix as words over the **tab line**; the current one sits in a **tab rise** (`TabRise`) that grows out of the line.
- **tools** (`SongTools`): the tab's keys. Pads: **Patterns**, **Launch key** (`LaunchKey`), **Cancel waiting key** (`CancelWaitingKey`). Timeline: **Undo** (only while there's one), **Patterns**, **zoom** (`TimelineZoom`). Mix: none.
- **Keys** (`IconKey`): shows the FM-1's keyboard.
- **transport group** (`transportGroup`): **REC**, **Play** and the **readout** (`ReadoutLabel`) in one well.
- **from-the-start tag**: "Playing from the start", under Play after a hold.
- **strip** (`SongStrip`): the raised line under the row. Holds one of: the **unseen-scene line**, a **refusal** (`RefusalLine`, with its **Stop key** and **dismiss**), the **lanes-apart line**.

Words to retire for the same things: "top bar" for the row (the code's struct is `TopBar`; prose says "top row"), "connection" for the FM-1 key, "toast" for the strip.

### Requirements

**Functional**
- **F1** One row holds the FM-1 key, the tabs, the tools, Keys and the transport group, in that order.
- **F2** The tools follow the tab: Pads (on firmware that performs) shows Patterns, Launch at and Cancel waiting; the Timeline shows Undo, Patterns and the zoom; Mix shows none.
- **F3** The FM-1 key, the tabs, Keys and the transport group keep their size. Only the tools give way.
- **F4** The tools give way in a fixed order as the row narrows: the "Launch at" words go, then Patterns (and Undo) become icons, then Cancel becomes ✕ N. Cancel is never hidden.
- **F5** The strip shows at most one line, and only on the Song page.
- **F6** `[open]` The give-way order has never been seen on a narrower window (check `2026-11-09-perform-grid-map.md` 56, "Not tried").

**States**
- **S1** FM-1 key, a real FM-1 connected: the lit dot, no words.
- **S2** FM-1 key, the demo: the lit dot and "Demo".
- **S3** FM-1 key, trouble: the dot unlit and the status in words ("No FM-1", "Connecting…", "Wrong firmware", "FM-1 disconnected").
- **S4** Waiting dot: becomes a spinner only when the song store has been busy for a moment, so a quick edit never flickers it (Scott, 2026-11-09: "things pause for a second").
- **S5** Tabs: the current tab in the tab rise, its word in the primary text weight; the others flat, in the secondary grey.
- **S6** Patterns: latched (down) while the Patterns drawer is open.
- **S7** Launch key: the current launch point's word ("Loop", "Bar", "Beat", "Now"), with "Launch at" before it when there's room. Disabled offline.
- **S8** Cancel waiting key: "Cancel N waiting" while launches or mutes wait; "Cancel waiting", disabled, when none do. Disabled offline.
- **S9** Undo: shown only while the undo stack has something; disabled while the store is busy or offline.
- **S10** Zoom: the bars across between its two keys; out stops at 128 bars, in at 4.
- **S11** Keys: on (latched, filled symbol), off (outline symbol, no key), disabled while no FM-1 is connected.
- **S12** Transport group, recording: the well takes the recording tint and REC fills.
- **S13** REC and Play without a connected FM-1: dimmed and disabled.
- **S14** Play stopped: the play symbol, no key behind it. Playing: the stop symbol on a raised key.
- **S15** Play pressed: sinks as every key does (`keys.md`).
- **S16** Readout stopped: "– · –". Playing: bar · step of the selected track.
- **S17** Readout second line: the playback mode's word (Loop, Song, Once), then the tempo. Recording: "REC" or "SONG REC" in the recording text colour, and the position too.
- **S18** Strip on Pads: an unseen held scene first, else a refusal.
- **S19** Strip on the Timeline: a refusal first, else the lanes-apart line.
- **S20** Refusal: the Stop key shows only when the refusal needs a stop and Lupe is playing.

**Behaviour**
- **B1** Tap the FM-1 key: the FM-1 menu opens under the key. Groups: the status and version line; FM-1 over USB · Skiff demo · SLOOP demo (current ticked); Projects… · Play through the iPad; Install firmware… · Settings….
- **B2** Tap Pads or Timeline: the Song page shows that view; the editor stays put while the two slide past each other.
- **B3** Tap Mix: the Mix page.
- **B4** A tab that changes the page moves the FM-1's screen to match when the screen link is on and Lupe follows the FM-1 (Song: the FM-1's song screen; Mix: the mixer section's page). Pads ↔ Timeline doesn't move the FM-1.
- **B5** A tab change: the old tab sinks into the line as the new one rises, together.
- **B6** Patterns toggles the Patterns drawer.
- **B7** Tap the Launch key: a menu "Launch at" opens at the key, each point with what it means, the current one ticked. Picking one sends it to the FM-1 and the key takes it only when the FM-1 accepts.
- **B8** Cancel waiting takes back every launch and mute still waiting for the launch point. The song's own next isn't counted or cancelled.
- **B9** Undo undoes the last song edit; ⌘Z too.
- **B10** Zoom out doubles the bars across; zoom in halves them.
- **B11** Keys toggles the keyboard drawer.
- **B12** Tap REC: recording on or off.
- **B13** Tap Play: play or stop.
- **B14** Hold Play (Skiff only): plays from the start, as the FM-1's GLO + PLAY: every track from its first entry with SONG on, the patterns from their first step with it off (Scott, 2026-11-06). The tag shows under the key, a medium haptic fires, VoiceOver announces it.
- **B15** The release that ends a hold is not a tap. A finger dragged off Play is neither.
- **B16** Tap the readout: the tempo popup opens under it. The tap that closed the popup doesn't reopen it.
- **B17** The strip slides down from under the row. A refusal stays until dismissed or its Stop key is used; the unseen-scene line shows while that scene is held; the lanes-apart line while the lanes end apart.

**Content**
- **C1** Status words, only these: Demo, No FM-1, Connecting…, Wrong firmware, FM-1 disconnected. The menu's line says "Demo FM-1" or "FM-1 connected" with the version, and "· screen link" when linked.
- **C2** Launch menu: "Loop: at the end of each track's pass", "Bar: on the next bar", "Beat: on the next beat", "Now: at once".
- **C3** Cancel: "Cancel N waiting", "Cancel waiting", or ✕ and the count.
- **C4** Readout: position "bar · step"; second line "Mode · N BPM", for example "Song · 120 BPM".
- **C5** Strip lines: "Scene N: not seen yet. Recall it once and holding it shows what it does"; a refusal's own words (for example "Stop to rearrange: the FM-1 moves pads only while stopped"); the Timeline's "Tracks end at bars …, so they loop apart" with a warning symbol.
- **C6** The tag says "Playing from the start".

**Accessibility**
- **A1** FM-1 key: label is the status and version line; hint "Choose the FM-1 or a demo, install firmware, or open Settings". The spinner says "Waiting for the FM-1".
- **A2** Tabs: one container, "Pages". The current tab carries the selected trait. Hints say what each holds ("Every track's entries to launch, the scenes under them"; "Every track's entries along the bars"; "Levels, sends and the effects").
- **A3** Launch key: label "Launch at", value the point, hint naming what it governs.
- **A4** Cancel waiting: label carries the count; hint "Takes back every launch and mute still waiting for the launch point".
- **A5** Zoom: one container "Zoom, N bars across" with "Zoom out" and "Zoom in"; the bars text itself is hidden.
- **A6** Keys: label "Keys", value on or off, the toggle trait, hint "Shows the FM-1's keyboard".
- **A7** REC: label "Record", value "off", "recording" or "song recording", the toggle trait.
- **A8** Play: label "Stop", "Play the song" (song mode) or "Play". The hold has three other ways in: the VoiceOver action "Play from the start", ⇧Space, and the pointer's tooltip.
- **A9** Readout: label "Position"; value the mode, "bar n, step m" or "stopped", and the tempo; marked as updating often while playing so VoiceOver reads it when asked, not every step (`2026-11-10-accessibility.md` 11). Hint "Opens the tempo".
- **A10** Refusal: dismiss is labelled "Dismiss"; the warning symbol is hidden.
- **A11** Recording is not told by colour alone: REC fills and the readout says REC.
- **A12** Reduce Motion: the tab change and the strip's arrival cross-fade; Play's sink and the well's tint don't animate.
- **A13** `[open]` Patterns' open state (S6) isn't spoken: no value or selected trait while latched.
- **A14** `[open]` The strip's arrival posts no VoiceOver announcement, so a refusal can go unheard.
- **A15** `[open]` No Dynamic Type in the row (accessibility P1).

**Integration**
- **I1** Launch at writes the FM-1's one LAUNCH setting (`performOp(.launch)`); the key reads the store's perform state, else the session's.
- **I2** Cancel waiting is `performOp(.cancel)`. The count is launches waiting plus mutes staged (`CancelWaitingKey.count`).
- **I3** Play from the start is Skiff's; SLOOP's editor can't restart, so there the hold, the action and the shortcut are absent.
- **I4** The readout's position is the selected track's.
- **I5** The FM-1 menu's Projects… opens the Projects sheet; Play through the iPad toggles `AudioThrough`.

### Ruled out

- Three raised keys for the tabs: tried 2026-11-01 and didn't work; back to tabs (`TopBar.swift` comment).
- Song · Mix tabs with a Pads / Timeline switch: replaced by Pads · Timeline · Mix, the phone's split (Scott, 2026-11-10).
- A Sounds tab on the iPad: the Sounds panel instead (Scott, 2026-11-10; structure map).
- Launch at as four segments: one key with a menu at the finger (Scott, 2026-11-10).
- A red line under the whole row while recording: tried in the mockup and dropped (2026-11-03, `TopBar.swift` comment).
- In the FM-1 menu, the "Follow the FM-1's screen" switch (it always follows), the iPad's audio lines, the diagnostics line and the Developer submenu: cut to four things (Scott, 2026-11-06).
- The readout opening Arrange in song mode: it opens the tempo (2026-11-05).
- The strip as a toast that leaves on its own: a refusal carries a Stop key (`SongStrip` comment).
- A refusal as bare text on the page: white on black was easy to miss, so it sits on a lifted box in the neutral grey, not a track tint, which means "selected" (Scott, 2026-11-09).

### Out of scope

- The keys' look and press: `keys.md`.
- The tempo popup and its playback-mode keys: `tempo-popup.md`.
- The FM-1 menu's panel and placement: `hold-menus.md` (placed menus).
- The Patterns drawer (`PatternBin`) and the keyboard drawer. The Projects and Settings sheets: `projects-sheet.md`, `settings-sheet.md`. What the FM-1 key's trouble states lead to: `connection-states.md`.
- The waiting outlines on pads and mutes that Cancel takes back: `pattern-pad.md`, `track-head.md`.
- The phones' header: `phone-header.md`.

## 2. Design

Boards: 44 (the tab on a line, `design/boards/toptabs.py`; drawn when the tabs were Song · Mix · Sounds), 47 (everything in one row, `design/boards/toprow.py`). Before and after captures: `qa/top-row-2026-11-10/README.md`.

Particular to the row:
- The tab rise is a step lighter than the control grey, because the control grey as a thin line all but vanished on the page (board 44, `TopBar.tabGrey`).
- `[open]` `DESIGN.md` on the Android branch says "The header is chrome, not content" (no square keys in the header; Scott, 2026-11-13, board 71). It came from the phone (decision 23). The iPad's row still uses chiclet keys and the tab rise. Does the rule reach the iPad?

### Decision log

- 2026-11-09: the tabs as one tab rising from a line, the old sinking as the new rises (Scott, board 44).
- 2026-11-10: one row above the Pads, the tools following the tab; nothing else refined may move (Scott, board 47 b; `qa/top-row-2026-11-10/README.md`).
- 2026-11-10: Projects and the iPad's audio move into the FM-1 menu; the playback mode's keys go to the tempo popup, its word into the readout (Scott, board 47).
- 2026-11-06: hold Play to play from the start (Scott).

## 3. Build notes

- Play is one press gesture deciding tap or hold, not a Button with a long press beside it: whether the Button still fired on the release after a hold varied in the simulator (2026-11-06), so a hold sometimes stopped what it had just started.
- `ReadoutLabel` is its own view so the step moving redraws the readout, not the row. Its width is fixed so nothing moves when the mode word changes.
- The give-way is a `ViewThatFits` over four built rows (`SongTools.row(level)`).
- The strip is an overlay placed under the row, not part of the row's layout.
- Device checks: `2026-11-09-perform-grid-map.md` 33 (the tab line), 56 (the row, the menus), 57 (the strip), 69 (Pads · Timeline · Mix); `2026-11-10-accessibility.md` 10 (the tempo popup's focus), 11 (the readout).
- Code notes, not fixed: `TopBar` still carries the pre-Skiff layout's `tabs`, `project` and `transport`; only the Skiff and SLOOP rows use `songTabs` and `skiffTransport`.

### Decision log

## 4. Usage

- A new Song-tab tool goes into `SongTools.row` with its place in the give-way order decided first; it never pushes the transport.
- Anything that has to stay on screen until dealt with goes on the strip, not a toast.
- Settings that are set once go in the FM-1 menu, not the row.

---
component: Projects sheet
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/ProjectsSheet.swift     # the sheet, project rows, the open question, NamePrompt
  - ios/FM1/SkiffSaveViews.swift    # SkiffProjectSlots: the FM-1's four slots
  - ios/FM1/Projects.swift          # ProjectStore, ProjectFile: the iPad's projects and safety copies
  - ios/FM1/DeviceFollow.swift      # SAVE › PROJECT opens and closes it
  - ios/FM1/TopBar.swift            # the FM-1 menu's Projects…
  - android/app/src/main/java/com/scottgerstl/lupe/ui/projects/ProjectsSheet.kt   # Android (branch claude/android-p2-shell-02c86f)
boards: ["design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-317   # Project slot row
---

# Projects sheet

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

> **Under revision (2026-11-14):** the phones. Decision 33 (vault `phone-skiff-decisions-2026-11-12.md`) gives both phones Android's four-slot sheet. Android keeps its sheet; the iPhone, which has none today, gets it new (`phone-consolidation-build-plan-2026-11-14.md`, row "Projects"). Android's sheet holds only the FM-1's four slots: the playing one marked, with Save; the others Load; an empty one Save here, its name typed in place; a ⋯ with Rename and "Save the playing project here". Every confirm is a red-outlined row in place. Section 1 below is the iPad's sheet, unchanged by this.
> - `[open]` The phones get no projects kept on the phone and no safety copies. Intended, or only not yet decided?
> - `[open]` The iPhone's way in: Android opens it from the FM-1 key's menu; the iPhone's ⋯ menu moves into Android's song-name menu (decision 33, App menu).

## 1. Requirements

### Purpose and scope

Where a song is kept and brought back. On Skiff, two places side by side: the FM-1's own four project slots (SAVE › PROJECT), and projects saved on the iPad, which carry their patterns with them. Opening anything over unsaved work keeps a safety copy first, so nothing is lost by a wrong tap.

It doesn't hold sounds or samples (they stay on the FM-1) and isn't where exports go (structure map, "Exports", undecided).

Where it sits: `structure-map.md`, the SAVE row of "The FM-1's buttons", and the top row's FM-1 key.

### Anatomy

Names as in the code.

- **sheet**: a system sheet with a list. Toolbar: the **tab picker** (Projects, Safety copies) and **Done**.
- **status rows**: a **busy row** (what's happening, with progress) and a **message row** (a warning icon and what went wrong).
- **FM-1 slots** (`SkiffProjectSlots`): "On the FM-1", a **slot row** per slot: the slot label (P1–P4), the name or "Empty", "Playing now", **Load**, **Save here…** or **Save over…**; a footer.
- **iPad section**: **New project**, **Save as…**; "On this iPad" on Skiff; a footer.
- **project row**: the **open button** (name, the **On FM-1 badge**, the detail line, **section marks** on SLOOP) and the **⋯ key**.
- **safety copies**: rows like project rows, and a footer.
- **open question**: a fan at the finger asking to save or stop before opening.
- **name card** (`TextPrompt`): Lupe's own card for a name.

### Requirements

**Functional**
- **F1** Three ways in: the FM-1 menu › Projects…, SAVE's PROJECT page on the FM-1 (linked), and the SAVE key stepping PRESETS, USER, PATTERNS, PROJECT. SLOOP's top bar also has its project key.
- **F2** Projects are kept per firmware: the connected one's, or the one last connected while unplugged, each in its own folder (Files › Lupe › SLOOP or Skiff, with Projects, Safety copies and Backups).
- **F3** The FM-1 slots show only with a Skiff FM-1 connected.
- **F4** Opening a project replaces the music on the FM-1 and stops it first.
- **F5** Before anything opens over unsaved work, Lupe keeps a safety copy, and keeps only the last few (`ProjectStore.keptSafetyCopies`).

**States**
- **S1** Reading the slots: a spinner and "Reading the FM-1's projects…".
- **S2** Slot empty: "Empty" in the secondary grey; only Save here….
- **S3** Slot used: its name; Load and Save over….
- **S4** The slot the music came from: "Playing now", or "Playing now · changed since" when the music has changed.
- **S5** Busy (opening, saving, loading, backing up): the busy row; the sheet can't be swiped away; the rows' keys are off.
- **S6** Something went wrong: the message row, on either tab.
- **S7** Offline: opening, New project and Save as… are off; the footer says "Plug in the FM-1 to open or save a project. You can still rename and delete."; rename, duplicate and delete still work.
- **S8** No projects yet: one line, "No projects yet. Save what's on the FM-1 to make your first one."
- **S9** The project the FM-1 holds: the badge "On FM-1", or "On FM-1 · edited".
- **S10** Safety copies: the tab reads "Safety copies (n)" when there are any; an empty tab says "No safety copies yet."
- **S11** SLOOP: no FM-1 slots; project rows carry the section marks A–D, and their menu has Export….

**Behaviour**
- **B1** Tapping a project row opens it, at once when nothing is unsaved and nothing plays.
- **B2** With unsaved work or the song playing, the open question comes up at the finger: "Save, then open" (or "Save as new, then open"), "Open without saving", or "Stop and open"; and Cancel. No system alert.
- **B3** Opening without saving still keeps a safety copy.
- **B4** Skiff: patterns a project brings go to free places in the pool, never over another pattern. A full pool opens nothing and says how many are needed and free.
- **B5** New project: Skiff clears the music to each track's power-on sound with no patterns (the pool keeps its patterns); SLOOP clears the FM-1.
- **B6** Save as… asks for a name in the name card. On Skiff, saving stops the FM-1, and the card says so.
- **B7** A row's ⋯ key, a long press anywhere on the row, or a swipe opens its menu: Rename, Duplicate (not on a safety copy), Export… (SLOOP), Delete.
- **B8** Renaming a safety copy makes it a project.
- **B9** Delete asks in place; the iPad's copy goes for good, the FM-1's music stays.
- **B10** Load on a slot replaces the music and stops the transport. Over changes no slot holds, it asks in red, naming the slot; otherwise a plain fan with Load and Cancel.
- **B11** Save here… and Save over… ask for a name (upper case, Skiff's length). Over a used slot, the whole FM-1 is backed up to Files first; if the backup fails, the slot is left as it was.
- **B12** The name offered is the music's own name (or "PROJECT n") for its own slot or an empty one, else the slot's name.
- **B13** When the FM-1 leaves SAVE › PROJECT (the next SAVE page, DONE, any other button), the sheet closes with it; a menu or held layer on that page doesn't close it (Scott, 2026-11-07).

**Content**
- **C1** Slots footer: "Skiff keeps 4 projects on the FM-1. Loading one stops it; saving over one backs the FM-1 up to Files first."
- **C2** iPad footer (Skiff): "Saving here or opening stops the FM-1. A project keeps its patterns with it; user sounds and samples stay on the FM-1."
- **C3** Safety copies footer: "Lupe takes one before it opens something over unsaved work, and keeps the last n. Rename one to keep it as a project."
- **C4** The open question's caption names what's replaced, whether it stops, and that a safety copy is kept; "Saving makes “Project n”." when there's no project to save into.
- **C5** Detail line: "Saved <when> · n patterns" (Skiff) or "· n BPM" (SLOOP); safety copies "Taken <when>". Safety copies are named "Before opening <name>" or "Before a new project".
- **C6** Delete: "Delete “Name” from this iPad", caption "It's removed from this iPad for good. What's on the FM-1 stays as it is."
- **C7** Slot confirms: "Load Pn “Name”"; "Replace Pn?" with "Back up and replace"; "Save to Pn" with "Save project".
- **C8** Failures say what's left as it was ("P2 didn't load. Try again with the FM-1 stopped."; "The backup didn't finish, so P2 was left as it is."; "Couldn't open it: …. Nothing on the FM-1 changed.").

**Accessibility**
- **A1** A project row is one element: name, "on the FM-1" (and "edited"), the detail, and on SLOOP the filled sections; hint "Opens it on the FM-1" or "Plug in the FM-1 to open it".
- **A2** The ⋯ key is its own target, "Manage Name", so the long press and the swipe each have a visible way in.
- **A3** A slot row: "Pn, name" or "Pn, empty", plus "playing now" and "changed"; its keys stay separate.
- **A4** The section marks are hidden; their letters and the row's label carry the state without colour.
- **A5** The sheet's spoken title follows the tab ("Projects", "Safety copies").
- **A6** Confirms and names are Lupe's own, in the sheet's own layer, focused by VoiceOver (`DESIGN.md`).
- **A7** `[review]` Type is Lupe's fixed type inside a system list (accessibility P1); not checked with Larger Text.
- **A8** `[review]` The slots' Load and Save keys are the system's bordered buttons; their target size isn't checked.

**Integration**
- **I1** A Skiff project (SKF4) holds sounds, globals, the name and each track's entries; the steps are in the 64-pattern pool every project shares. An iPad project keeps the record and the patterns its entries name (`qa/skiff-projects-2026-11-06/README.md`).
- **I2** Skiff's backup commands do the moving: BACKUP_LIST (stops the transport, snapshots the music), BACKUP_GET, BACKUP_PUT. No firmware patch.
- **I3** Skiff can't be read quietly, so Lupe counts any change after an open or save as an edit and errs on the side of asking. SLOOP compares a fingerprint once stopped.
- **I4** User sounds, samples and the FM-1's settings stay on the FM-1, outside every project.
- **I5** Slots: Skiff's PROJECT load and PROJ_NAME; the slot list from `refreshSkiffProjects`.
- **I6** A project from Skiff 2.2 opens on 2.5.1 as it played (device check `2026-11-11-skiff-2.5.1-support.md` 9, result not recorded).

**Device checks.** In-place confirms and name cards in the sheet: `2026-11-09-perform-grid-map.md` 64–65, passed with checks 50–71 (batch list item 8, Scott, 2026-11-11). Folders per firmware: `2026-11-09-lupe-batch-2026-11-06.md` 20, result not recorded.

### Ruled out

- System alerts and text prompts for confirms and names: Lupe's own, at the finger (2026-11-10, `DESIGN.md`).
- A firmware patch to send a project with its patterns inside: it would only save the stop on a save to the iPad, not worth a flash (`qa/skiff-projects-2026-11-06`).
- Rename only by a long press on the row: the ⋯ key, so it works with the FM-1 unplugged and is visible (2026-11-02, `ProjectsSheet.swift`).
- The sheet staying up after the FM-1 leaves PROJECT: "as it is the modal just sits there" (Scott, 2026-11-07).

### Out of scope

- The FM-1 menu itself and its status: see `connection-states.md`.
- Saving a sound to a user slot (`SaveSound`, same file): the sound panel's.
- SAVE's PRESETS, USER and PATTERNS pages: the Sounds panel (`sounds-panel.md`) and the Patterns drawer.
- The whole-FM-1 backup and Install firmware…: `FirmwareInstall.swift`.
- Exports (MIDI, audio, a project file): structure map, "Exports", proposed.

## 2. Design

No iPad board. Phone row "Projects": `design/boards/phone-consolidation.html` (Android's sheet, board 67 in `design/boards/phone-portrait-2.html`).

Motion follows `DESIGN.md`. The sheet is the system's; confirms and the name card come from the finger.

### Decision log

- 2026-11-06: SAVE's pages in Lupe as proposed; PROJECT is the Projects sheet, with the FM-1's slots beside the iPad's projects (Scott, `SkiffSaveViews.swift`).
- 2026-11-07: the sheet follows the FM-1 out of PROJECT (Scott).
- 2026-11-10: Projects… moves into the FM-1 menu (Scott, board 47).
- 2026-11-14: both phones get Android's four-slot sheet (Scott, decision 33).

## 3. Build notes

- The sheet covers the app's root, so it carries its own menu layer (`AppMenuLayer`) and name layer (`TextPromptLayer`).
- `TopBar.skiffProjectsKey` (a folder key) is defined but not placed anywhere.
- On the iPhone, SAVE › PROJECT sets `ui.projectsOpen`, but no sheet is attached there. `[review]` Not checked at runtime.
- Android's sheet (branch `claude/android-p2-shell-02c86f`): names up to 16 letters in its field, against the iPad's upper case to Skiff's length. `[review]` Which is right for Skiff's slots.

### Decision log

- 2026-11-06: each firmware its own folder and its own words; nothing from SLOOP shows with Skiff connected, or the reverse (`qa/skiff-projects-2026-11-06`).

## 4. Usage

- Anything that replaces the FM-1's music goes through `ProjectStore.open`, so the safety copy and the stop happen.
- Anything that writes a slot names what it replaces and backs up first, as Save over… does.
- Not for sounds or samples: say so where a user might expect them in a project (the iPad footer does).

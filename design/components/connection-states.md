---
component: Connection states
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/AppView.swift            # the held page, LostCard, ConnectionState, LookingForFM1, NotOnThisFirmware, the announcements
  - ios/FM1/SkiffArrangeParts.swift  # OfflineBar over the Timeline
  - ios/FM1/TopBar.swift             # the FM-1 key's offline readings (statusLine, versionLine, WaitingDot)
  - ios/FM1/PhoneAppView.swift       # the iPhone: ConnectionState only, no held page
  - ios/SloopKit/Sources/SloopKit/Session.swift   # ConnectionStatus, the connect loop
  - ios/SloopKit/Sources/SloopKit/Driver.swift    # FirmwareDialect.detect, the version gate, FirmwareDialect.known
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/LinkStates.kt   # Android (branch claude/android-p2-shell-02c86f): LinkPage, LinkCard
boards: [42, "design/boards/disconnect.py", "design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-399   # Lost card
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-407   # Connection card
---

# Connection states

> **Under revision (2026-11-14):** the phones' No FM-1 screen. Decision 33 (vault `phone-skiff-decisions-2026-11-12.md`) picks the iPhone's card with the firmware versions and the demo button for both phones, its Skiff 2.2 text corrected to 2.5.1. Android replaces its `LinkPage` (title, line, Try again) with that card and a demo button that starts the fake core; the iPhone keeps `ConnectionState` with the corrected text (`phone-consolidation-build-plan-2026-11-14.md`, row "No FM-1"). Section 1 below is what's built until this closes.
> - `[open]` Does Android keep its lost card (`LinkCard`, option A) beside the new page? Decision 33 names only the No FM-1 screen.
> - `[open]` Does the iPhone get the held page and card (accessibility P15), or keep falling back to the full page on a loss?
> - `[open]` `ConnectionState` is shared by the iPad and the iPhone, so the 2.5.1 correction reaches the iPad too. Intended?

## 1. Requirements

### Purpose and scope

Everything Lupe shows when it isn't talking to an FM-1: never found this launch, reading it, running firmware Lupe doesn't speak, or lost after it was working. Each state says what happened and what to do, and says Lupe is still looking, so the wait never reads as stuck. A loss in the middle of work holds the page where it was rather than swapping it (board 42, option A).

Where it sits: `structure-map.md`, "The FM-1 disconnected".

### Anatomy

Names as in the code.

- **full page** (`ConnectionState`): a page of its own in place of the tabs. Title, detail, the looking line, the demo key.
- **looking line** (`LookingForFM1`): the system spinner and "Looking for the FM-1…".
- **demo key**: "Use the demo FM-1".
- **held page**: the page that was up when the FM-1 went, faded back and grey, read-only.
- **lost card** (`LostCard`): drops from under the top bar over the held page. Icon, title, body, then the looking line or a progress bar.
- **offline bar** (`OfflineBar`): a strip over the Timeline while its song is offline.
- **FM-1 key**: the top bar's first key. Its dot (`WaitingDot`), its short status words, its menu's status note.
- **not-on-this-firmware page** (`NotOnThisFirmware`): a tab's page drawn as the full page, for a feature this firmware lacks.
- **version gate** (`FirmwareDialect.detect`): the check of INFO that decides whether Lupe connects at all.

### Requirements

**Functional**
- **F1** Lupe looks for the FM-1 all the time, on its own; no state has a "Connect" or "Retry" key on the iPad.
- **F2** The held page and lost card show only after the FM-1 has been connected at least once this launch. Before that, any not-connected state is the full page.
- **F3** The version gate connects only to firmware Lupe speaks (SLOOP 2.8.4 at its protocol, or Skiff with a supported INFO); anything else is wrong firmware, and Lupe sends it nothing further.
- **F4** A Skiff without song lists (older than 2.0) connects, and the Song tab shows the not-on-this-firmware page in place of the song.

**States** (iPad unless noted)
- **S1** Searching (no FM-1 found, never connected this launch): full page, "Plug in the FM-1", the looking line, the demo key.
- **S2** Connecting (first read): full page, "Reading the FM-1…". No looking line, no demo key.
- **S3** Wrong firmware: full page, "This FM-1 runs other firmware", naming what INFO reported, its protocol, and the firmware Lupe works with. The demo key; no looking line. Lupe tries again less often than while searching.
- **S4** Lost with no page to hold (before a first connect completes, or on the iPhone): full page, "FM-1 disconnected", the reason, the looking line, the demo key.
- **S5** Held (lost after connecting): the page stays where it was, faded back and grey, touches off; the lost card drops from under the top bar: cable icon struck through in the caution colour, "FM-1 disconnected", what to do, the looking line.
- **S6** Back, reading (found again, being read): the card stays; icon, title and body blend to "Back", "Reading the FM-1. A second.", a progress bar in place of the looking line. The page stays held.
- **S7** Picked up: the card rises away and the page returns to full colour where it was.
- **S8** Offline Timeline: the offline bar sits over the Timeline's lanes, which dim, with the looking line at its end.
- **S9** FM-1 key: dot off when not connected; short words "No FM-1", "Connecting…", "Wrong firmware" or "FM-1 disconnected"; a real FM-1 connected shows the dot alone, the demo "Demo".
- **S10** iPhone: no held page. Every not-connected state, a loss included, is the full page (accessibility P15).

**Behaviour**
- **B1** The demo key switches the source to the demo FM-1 (the FM-1 menu's own choice, made from the page).
- **B2** On a loss after connecting, the page fades back and the card drops; nothing on the page changes place.
- **B3** When the FM-1 comes back, the session reads everything again; the card shows S6 until the read ends, then S7.
- **B4** A loss while reading (S6) returns the card to S5.
- **B5** The FM-1 key opens the FM-1 menu in every state: the status and version note, the source (FM-1 over USB, Skiff demo, SLOOP demo), Install firmware…, Settings….
- **B6** Wrong firmware: Install firmware… offers firmware Lupe speaks (`FirmwareInstall.swift`).

**Content**
- **C1** Full page titles, and only these: "Plug in the FM-1", "Reading the FM-1…", "This FM-1 runs other firmware", "FM-1 disconnected".
- **C2** Searching detail: "Connect it with a USB-C cable and switch it on. It has to be running SLOOP 2.8.4 or Skiff 2.2." `[open]` Lupe also speaks Skiff 2.5.1 (`FirmwareDialect.known`); the text and the FM-1 menu's note ("needs SLOOP 2.8.4 or Skiff 2.2") leave it out. Decision 33 corrects it on the phones (see the amendment).
- **C3** Wrong firmware detail: "It reports “found”, editor protocol N. Lupe works with …. Install one of those, then plug the FM-1 in again." The list comes from `FirmwareDialect.known`.
- **C4** Lost detail: the reason, then "Check the USB-C cable and that the FM-1 is switched on. Lupe picks up where it was as soon as it's back; if it's plugged in and on, unplug it and plug it in again." (Scott, 2026-11-07: a state that says to reconnect or turn it on.)
- **C5** `[open]` The lost full page's title and first sentence both say "FM-1 disconnected" when the reason is a plain disconnect. The structure map named this as a problem (2026-11-09); option A fixed it only for the held page.
- **C6** Lost card: "FM-1 disconnected" / "Plug it back in, or check it's switched on. Lupe picks up where you were: nothing here is lost." Back: "Back" / "Reading the FM-1. A second."
- **C7** Offline bar: "FM-1 disconnected" / "Check the cable and that it's switched on. This is the song as it was; editing comes back with the FM-1."
- **C8** Not on this firmware: "Update Skiff to use the Song tab", saying why and where to install (Install firmware…).

**Accessibility**
- **A1** The held page is hidden from VoiceOver as well as from touch, so it can't be pressed while read-only; the card stays readable (accessibility F6, 2026-11-10).
- **A2** The loss and the return are each announced once, without moving focus: "FM-1 disconnected. Plug it back in; nothing is lost." and "FM-1 back" (F7). The card's own blends aren't announced.
- **A3** The lost card is one element; the offline bar is one static-text element; the looking line is one element.
- **A4** The full page keeps its children separate (title, detail, the demo key as a button).
- **A5** FM-1 key: label "status, version", hint "Choose the FM-1 or a demo, install firmware, or open Settings".
- **A6** Nothing by colour alone: the icon's colour changes with words (title, body) and a different symbol.
- **A7** Reduce Motion: the card cross-fades instead of travelling.
- **A8** `[open]` Full Keyboard Access can still reach the held page (accessibility P12). The proposed fix also dims the page's controls further; Scott's call on the look.
- **A9** `[open]` Fixed type: the card and the full page don't follow Dynamic Type (accessibility P1).
- **A10** Device checks: `2026-11-10-accessibility.md` 8 (VoiceOver and the disconnect) and 19 (Reduce Motion) passed with Part A–C (batch list item 8, Scott, 2026-11-11); 23 (keyboard on the held page) is a note. The look and motion: `2026-11-09-perform-grid-map.md` 28, result not recorded.

**Integration**
- **I1** State is `DeviceSession.status`: searching, connecting, connected (version), wrongFirmware (found, protocol), lost (reason).
- **I2** Lost reasons are "FM-1 disconnected" (a loop ended) or "Lost the FM-1 while reading it" (the read failed).
- **I3** "Back, reading" is `connecting` after a connect this launch; the card reads it from the status, not a state of its own.
- **I4** The FM-1's firmware list for every message is `FirmwareDialect.known` in SloopKit. `[open]` C2 and the FM-1 key's version line carry their own copies of it, which have drifted (one origin per fact).
- **I5** A loss detaches the song store; the Timeline reads `store.offline` for the offline bar.

### Ruled out

- Option B (a page of its own) and option C (status in the top bar) for a loss mid-work: option A, the held page and the card (Scott, 2026-11-09; `AppView.swift`, board 42).
- The Song tab falling back to the old Arrange page, dimmed, and other tabs swapping to a disconnected page: both cut in (structure map, 2026-11-09).
- Editing while disconnected (interaction spec, "the song stays editable offline"): option A holds the page read-only (Scott, 2026-11-09).
- `.updatesFrequently` on the card: it changes twice, and each change is announced instead (2026-11-10, F7).

### Out of scope

- The FM-1 menu's other items, the firmware picker and its offers: `FirmwareInstall.swift`.
- Projects… from the same menu: see `projects-sheet.md`. Settings…: see `settings-sheet.md`.
- The top bar's other keys and its strip: see `top-row.md`.
- What each panel says when offline ("The FM-1 is disconnected" in the Sounds panel, `sounds-panel.md`; the sampler's "THE FM-1 ISN'T CONNECTED"): those panels' own.

## 2. Design

Board 42 (`design/boards/disconnect.py`): options A, B and C; A built. Phone row "No FM-1": `design/boards/phone-consolidation.html`.

Motion follows `DESIGN.md` (an arrival says where it comes from). The timings are in the structure map's "The FM-1 disconnected". Particular to these states:
- The card comes from under the top bar, never from the middle of the page.
- Lost and Back are one card that blends between them; it doesn't leave and return.
- The page fades and greys in place; it never moves.

### Decision log

- 2026-11-07: a lost state says to reconnect or switch the FM-1 on (Scott, `AppView.swift`, `OfflineBar`).
- 2026-11-09: option A, the page held grey and read-only with a card from under the top bar (Scott: "A").
- 2026-11-14: the phones' No FM-1 screen is the iPhone's card with the firmware versions and the demo button, 2.2 corrected to 2.5.1 (Scott, decision 33).

## 3. Build notes

- `held` in `AppView` is `everConnected` and a status of lost or connecting; the page's `allowsHitTesting`, grayscale, opacity and `accessibilityHidden` all read it.
- The card's and the page's timings are hard-coded in `AppView`, not in Labs. If Scott comments on them, they go into Labs first (repo rule 3).
- The session retries every second while searching and less often on wrong firmware (`DeviceSession.run`).
- The structure map's heading still reads "board 42: pick before building", though A is built.
- On the Timeline while held, the offline bar draws inside the greyed page under the card. `[review]` Whether that reads as saying it twice.
- Android today (branch `claude/android-p2-shell-02c86f`, `LinkStates.kt`): a full page for searching, connecting, reading, wrong firmware and a loss before the first read, with "Try again" on wrong firmware and lost; a card over the greyed page after a loss. Its wrong-firmware title is "This FM-1 isn't running Skiff".

### Decision log

- 2026-11-10: the held page hidden from VoiceOver, the loss and return announced (accessibility F6, F7).

## 4. Usage

- Any page that can't work without the FM-1 sits under the held page; it needs no disconnected state of its own while held.
- A tab whose feature this firmware lacks uses `NotOnThisFirmware`, drawn as the full page, saying how to get the feature.
- Say what to do, and say Lupe is looking (`LookingForFM1`); never a bare "Disconnected".
- Firmware names and versions in copy come from `FirmwareDialect.known`, not typed again.

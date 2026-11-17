---
component: Scene row
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/PadsPage.swift        # sceneRow, sceneKey, sceneSpoken; the phone's refusal and unseen-scene line over the scenes
  - ios/FM1/Controls.swift        # ToggleKey (Store)
  - ios/FM1/SongTools.swift       # SongStrip: the iPad's unseen-scene line and refusals under the top row
  - ios/FM1/EditorUI.swift        # previewScene
  - ios/SloopKit/Sources/SloopKit/SkiffSongStore.swift   # performOp (store, recall, the replace confirm), scenesSeen, recallWaiting
  - ios/SloopKit/Sources/SloopKit/SkiffPerform.swift     # PerformState: kept, lastScene
  - android/app/src/main/java/com/scottgerstl/lupe/ui/shell/PadsPage.kt   # on branch claude/android-p1-core-link-faf639: "Store scene" and the scenes
boards: [35, 36, 37, 40, "design/boards/live.py", "design/boards/phone-consolidation.html"]
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=11-188
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=11-201
---

# Scene row

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

> **Under revision (2026-11-14):** decision 33 keeps the iPhone's scene row on both phones: the short Store key and outlined empty scenes (vault `phone-skiff-decisions-2026-11-12.md`, decision 33; `phone-consolidation-build-plan-2026-11-14.md`, "Scenes row"). The iPhone keeps what's built, which is the iPad's row at `.phone`. Android switches from its wider "Store scene" key and empty scenes drawn as plain numbers in a well. Section 1 below describes the iPad and iPhone as built.

## 1. Requirements

### Purpose and scope

Store and the FM-1's 16 scenes, in one row under the performance grid (Pads tab, Skiff). A scene is Skiff's PERFORM scene: the entry each track is on, and its mute. The row stores what plays now into a scene, recalls a scene, and, held, previews where a scene would send each track without sending anything (Scott, 2026-11-07).

It is not a column launcher: Skiff's scenes aren't columns (2026-11-09, `structure-map.md`, "What it leaves out on purpose"). Where it sits: `structure-map.md`, "Pads as a grid", "What's on it".

### Anatomy

Names as in the code. Layout positions as in `pattern-pad.md`: **No grid** = `.full`, **Half** = `.compact`, **Max** = `.row`, iPhone landscape = `.phone`.

- **Store** (`ToggleKey`): the latching key at the row's left, with its LED and the word "Store".
- **scene key** (`sceneKey`): one of 16, numbered 1–16, scrolling across the row on the iPad and the phones (decision 50).
- **scenes scroller** (`sceneScroller`): the 16 keys at a fixed width, scrolling horizontally, faded at a clipped edge, scrolled so the last scene shows.
- **HOME knobs** (`HomeKnobsStrip`, iPad and phones): at the row's right, the selected track's four HOME controls (`session.homeKnobIDs`, per engine: on a NEON kit PITCH, TONE, DECAY, SNAP): each a small ring in the track's colour with its label and value (decision 50).
- **number**: the scene's number on the key.
- **word**: "last" or "empty" under the number, No grid only.
- **recall trace** (`LaunchTrace` on the key): the line that draws round a recalled scene waiting for the launch point.
- **preview**: what a held scene shows elsewhere (the heads' dashed line, the pads' outer ring). Drawn by those components; started here.
- **unseen line**: "Scene N: not seen yet…", shown while a scene Lupe hasn't seen is held.

### Requirements

**Functional**
- **F1** The scenes scroll across the room left by the HOME knobs (iPad, decision 50; the phones too, Scott 2026-11-15: "Phones too"; before, all 16 at once, on the phone at 34 pt), every one reachable, the last recalled or stored scrolled into view, a fade at a clipped edge (decision 50, 2026-11-15; before, all 16 at once).
- **F4** The selected track's four HOME controls at the row's right, iPad and phones (decision 50: they went with the track controls box; the phones, Scott 2026-11-15). Each turns by a slide (the app's knob gesture, Settings › Slide to turn) and the same knob's parameter on the FM-1; each follows the FM-1's own HOME knobs live and lights while the FM-1's knob turns. None on a track whose engine has no HOME table.
- **F2** No grid and Half show the row under the pads. Max has no scene row.
- **F3** A scene's contents come only from what Lupe saw when it stored or recalled that scene (`scenesSeen`). PERFORM says which scenes are kept, not what's in them. What Lupe has seen is forgotten when the FM-1 reconnects.

**States**
- **S1** Empty scene: outline only, number in the secondary text colour. Word "empty" at No grid.
- **S2** Empty scene while Store is armed: a stronger outline, so the targets read.
- **S3** Kept scene: the raised control face, number semibold.
- **S4** Last recalled or stored: the white key (elevation 2), dark number. Word "last" at No grid. One at a time, from PERFORM's last scene.
- **S5** Recall waiting (playing): the recall trace draws round the key, as the pads' waiting trace does, and closes when the last of the scene's tracks lands. Dark on the white key. It fades in and out.
- **S6** Store armed: Store is latched, its LED lit and its word semibold. Its width doesn't change, so the scenes beside it never move (Scott, 2026-11-07).
- **S7** Held (a kept scene, Store not armed): the preview shows on the heads and pads; nothing is sent. Let go, it's gone.
- **S8** Held, scene not seen yet: the unseen line shows instead of a preview. On the iPad it's on the strip under the top row; on the phone, over the scenes.
- **S9** Pressed: the key sinks (`PressSink`).
- **S10** Offline: Store and every scene key are disabled.
- **S11** At Half and on the phone the word under the number is left out; the fill says it.

**Behaviour**
- **B1** Tap Store: arms it. Tap again: disarms.
- **B2** Tap a scene with Store armed: stores what plays now into it and disarms Store. A light haptic.
- **B3** Tap a kept scene with Store armed: asks first, in place at the finger ("Replace scene N?"), because the editor's STORE overwrites without the FM-1's own dialog (`SkiffSongStore.performOp`, citing bank.c and EDITOR_PROTOCOL.md). Only the confirm stores.
- **B4** Tap a kept scene while stopped: recalls it at once. A light haptic.
- **B5** Tap a kept scene while playing: the recall waits for the FM-1's launch point (S5).
- **B6** Tap an empty scene with Store off: nothing is sent; a refusal says how to fill it (C2).
- **B7** A recall ends any solo: the scene's mutes are now the mutes.
- **B8** Hold a kept scene with Store off: previews it (S7). The hold time is Settings › Touch, `holdToMenu`. The release after a hold doesn't recall.
- **B9** The lift that ends a pull of the editor's divider is not a tap on Store or a scene.
- **B10** Each key takes touches across its whole face and a margin round it, so an empty scene's inside is hit, not only its outline (Scott, 2026-11-09: "hard to hit").
- **B11** A recall that the FM-1 answers PATTERNS FULL while a swap is still being written retries for a moment before refusing (`retryWhileSaving`).

**Content**
- **C1** The key says only its number, plus "last" or "empty" at No grid.
- **C2** The empty-scene refusal: "Scene N is empty. Tap Store, then the scene, to keep what plays now".
- **C3** The unseen line: "Scene N: not seen yet. Recall it once and holding it shows what it does".
- **C4** The replace confirm: title "Replace scene N?", caption "Scene N becomes what each track plays now, and its mute. The scene it held is gone: the FM-1 keeps no copy.", confirm "Replace scene N".
- **C5** A failed answer from the FM-1: "The FM-1 didn't answer; the scenes are as it says now".

**Accessibility**
- **A1** Store is a toggle. Label "Store"; value "on: tap a scene to store into it" when armed; hint "Then tap a scene: it keeps the entry each track is on now, and its mute". `[review]` Store sets an empty value when off over `ToggleKey`'s own "off"; which one VoiceOver reads isn't checked.
- **A2** Each scene key is a button. Label "Scene N", plus ", empty" or ", recalled or stored last".
- **A3** A kept scene's value says what it holds: each track's entry, then the muted tracks; "contents not seen yet" when unseen. This is VoiceOver's way into the preview, with no hold (device check `2026-11-10-accessibility.md` 14).
- **A4** Hints follow the state: "Stores what plays now here" (Store armed), "Recalls it at the launch point" (playing), "Recalls it" (stopped), "Empty: store into it first".
- **A5** Reading order: the heads and pads row by row, then the scenes (accessibility audit F4; phone order still to verify, audit README).
- **A6** Nothing by colour alone: last has the white key and the word or label; recall waiting has the trace; armed Store has the LED and the weight change.
- **A7** Targets: the key is the row's height (Theme / PadsPage). At No grid that meets the 44 pt aim. At Half and on the phone it's under the aim but over the 24 pt floor, with the hit margin of B10. `[review]` Not listed in audit P14 with the other exceptions.
- **A8** Reduce Motion: the recall trace still draws (as the pads', accessibility P13); its fade shortens.
- **A9** `[open]` The empty scene's outline uses the same edge colour as the empty pad, which measured 1.36:1 on pads (audit P2). Not measured on the scene row.
- **A10** `[open]` No Dynamic Type and no Increase Contrast (audit P1, P11), as on the rest of the grid.

**Integration**
- **I1** Store and recall are PERFORM ops (`PerformOp.store`, `.recall`). Recalled while playing, they land at the FM-1's one LAUNCH setting.
- **I2** Kept and last come from PERFORM, read about once a second. A store or recall on the FM-1's own keys shows up to a second late.
- **I3** The FM-1 can't report a scene's contents (EDITOR_PROTOCOL.md; `perform-grid-questions.md`, "What's in a scene"). A PERFORM read op would close the gap; none is planned.
- **I4** Solo is Lupe's, made of mutes, so a scene stored while a track is soloed keeps the soloed mutes (`SkiffSongStore`, Solo).
- **I5** iPhone landscape: the same keys at `.phone`, under the rows and the heads, with the refusal and unseen line over the scenes until dismissed.
- **I6** `[open]` With decision 33, does Android gain the hold preview and the replace confirm at the finger, or keep its in-row confirm ("Replace scene N with what plays now")? Decision 33 names only the Store key and the outlined empties.

### Ruled out

- Column launch from the grid: Skiff's scenes aren't columns (2026-11-09, structure map).
- Store changing its word or width when armed: the scenes beside it never move (Scott, 2026-11-07, code comment).
- On Android, a wider "Store scene" key and empty scenes as plain numbers: replaced by the iPhone's row (Scott, 2026-11-14, decision 33).

### Out of scope

- The preview's drawing on each track: the heads' dashed line, see `track-head.md`; the pads' outer ring, see `pattern-pad.md` (S8).
- The editor panel's tab in the scene row's line: see `pattern-editor.md`.
- Launch at and Cancel waiting (the tool row, the phone's Launch key); the strip under the top row; the fan confirm itself (`Menus.swift`).
- The Pixel's Select toggle at the end of the portrait scenes row (board 53): see `pattern-pad.md` I8.

## 2. Design

Boards: 35 (the grid, the row under it), 36 (a scene held), 37 (Half), 40 (phone), phone consolidation row 5 (`design/boards/phone-consolidation.html`). Generator: `design/boards/live.py`.

Particular to the row:
- The recall trace is the pads' waiting trace on a key, "the same pattern for… anything else that waits for the loop" (Scott, 2026-11-10, `LaunchTrace` comment). Device check `2026-11-09-perform-grid-map.md` 42, not yet seen drawn.

### Decision log

- 2026-11-07: hold a scene to see what it would do (Scott, code comment).
- 2026-11-08: the scene row shrinks to Half's height so the editor at Half has room (Scott: "the scene buttons smaller").
- 2026-11-08: Store as tall as the scene keys (batch list, 49f42cf).
- 2026-11-09: the whole key and a margin take the touch (Scott: "hard to hit").
- 2026-11-14: both phones take the iPhone's row (Scott, decision 33).
- 2026-11-15: the iPad's row gives its right end to the selected track's four HOME knobs; the scenes scroll in the rest (Scott, decision 50). The phones too, the same day (Scott: "Phones too").

## 3. Build notes

- `.android` hybrid look (branch `hybrid-ui-android`, 2026-11-17; spec 3.3): Store and the sixteen sit in one floating `panel` toolbar at radius 24, 4 inside. Store is a `lifted` pill (white while armed). The current scene is white and squares to 12; a stored one is `lifted` and round; an empty one is bare with a grey number (the outline is gone, so A9's outline contrast no longer applies there; fill and ink both carry the state). A press squashes the key (Labs › Hybrid · press squash) and it springs back. The row is 44 tall (scene keys 36). The HOME knobs (decision 50) stay at the right at their own 34 height; the agreed map's "Store and 16" doesn't mention them, so they weren't removed.

- Device checks not yet passed: `2026-11-09-perform-grid-map.md` 10 (hold a stored scene), 23 (empty scene's help line), 42 (recall trace), 57 (unseen line on the strip), 64 (Store over a kept scene, not tried); `2026-11-10-accessibility.md` 14.
- Hard-coded timing not in Labs: the recall trace's fade. If Scott comments on it, it goes into Labs first (repo rule 3).
- Code notes found while writing this:
  - The comment on `PadsPage.phoneHead` says Store is 52 on the phone; the key is fixed at the iPad's width on every layout, as the structure map says.
  - The structure map says the editor's Open key sits at the scene row's end (board 33). The built tab sits under the heads, left of Store.
  - The structure map asks for a VoiceOver action as the preview's non-hold way in; the built way is the key's value (A3).

### Decision log

## 4. Usage

- To keep what plays now: Store, then a scene. To bring it back: tap the scene. To look without changing anything: hold it.
- A new view that recalls scenes should reuse this row and `store.scenesSeen`, not draw its own (structure map: the grid reuses the scene row).

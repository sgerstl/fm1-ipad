# SLOOP design pass, 2026-11-10

Branch `sloop-design-pass` in worktree `~/code/fm1-ipad-sloop-pass`, cut from `perform-grid-map` at `48a80fb`. Nothing pushed, merged or installed on a device. Simulator only.

**In one line:** on the iPad, SLOOP now uses Skiff's tabs (Song · Mix), the sound panel, the sounds panel, track heads, the editor under the divider and fan menus. Its own model goes inside them: sections A–D as tall pads, the song order on the Timeline. The phone is mocked, not built.

- Boards **S1–S5** on the Lupe canvas, under "SLOOP in the Skiff look": <https://claude.ai/artifact/NWuJFXxWQN6wPwWo9s1xVk>. Generator: `design/boards/sloop.py`.
- Structure map: the new section "SLOOP: the same tabs, its own song" in `design/structure-map.md` (marked *proposed*: your OK first).
- Device check: `qa/device-checks/2026-11-10-sloop-design-pass.md` (for when the FM-1 is on SLOOP).
- Screenshots: `before/` (`perform-grid-map` at `48a80fb`) and `after/` (this branch), iPad 13" simulator at 1376 × 1032, phone 852 × 393.

## 1. Inventory: what SLOOP is, and where each part maps

SLOOP 2.8.4's model, read from `SloopDriver`, `Session.swift`, `Song.swift` and the old SLOOP views:

| SLOOP has | Today (old layout) | Maps to (Skiff pattern) | Built? |
|---|---|---|---|
| 4 tracks (T1–T3 synths, T4 the drum kit), **one 64-step loop each**, no pool | Sequence: piano roll / drum grid, step panel, track knobs; the track box with 64-step timelines across the top | Song › **editor** under the divider (No grid · Half · Max, the tab and carets, the track's tint). The track box becomes the **track heads** | Yes |
| The working loop vs what's stored (`tracksEdited`) | "edited · hold to save" on a section key | **The loop now** column: each track's steps, "· edited" in amber | Yes |
| **Sections A–D**: snapshots of all four tracks; play on the next bar / load when stopped; store; clear (stopped only, no copy kept) | Arrange: four section keys | Song › **Pads**: one tall pad per section across all four rows. Waiting outline while it waits for the bar, "next" for the song's next, fan menu at the finger, destructive confirm in place | Yes |
| **Song order**: up to 16 steps of section × bars; loop at the end | Arrange: blocks that wrap | Song › **Timeline**: the same blocks (all their gestures and VoiceOver actions kept); position and "Loop the song" in the tool row | Yes, as wrapping blocks (not a ruler: see Q3) |
| **Song mode** (Loop / Song), **SONG REC** | Arrange: Mode panel, SONG REC key | Loop · Song in the top bar, where Skiff's playback mode sits; SONG REC in the tool row | Yes |
| Mute per track (a parameter, immediate) | Overview row tap on Arrange | Head's speaker key (HeadKeySurface). **No waiting outline**: SLOOP's mute isn't staged | Yes |
| **No solo** | – | **No S key.** Not faked | – |
| Level, pan, mute, REV send per track; DLY, REV/CHO and the GLO pages | Shape › GLO, Sequence's track knobs | **Mix**: Skiff's MixerPage as it is, with SLOOP's GLO pages as cards | Yes |
| FX SEL ENV LFO EDIT ARP pages | Shape tab | **Sound panel** over the tab that's up | Yes (shared code) |
| Presets, user presets, kits, samples | Browse tab | **Sounds panel** from the head's sound name, SAVE, the sound panel's "Sounds" | Yes (shared code) |
| SEQ › PATTERN (length, division…) | Shape › SEQ | The editor's whole-track panel (TrackPanel), under the step panel; it scrolls at Half | Yes |
| Projects (SLOOP's backup objects) | Folder in the top bar | Unchanged | – |
| Screen link (UI / UI_GOTO, layers) | Tabs follow the FM-1 | Buttons land as on Skiff: FX…ARP the panel, GLO Mix, HOME/SEQ Song, SAVE the sounds panel, SAVE held the sections | Yes (untested on device) |
| Pattern pool, chains, scenes, per-track launch, LAUNCH quantize, Cancel waiting | – | **Left out.** SLOOP has none of them | – |

## 2. Boards

| Board | What it shows |
|---|---|
| **S1** SLOOP today → the Skiff tabs | Where Sequence, Shape, Arrange and Browse each go |
| **S2** Pads | No grid (playing, B playing, C waiting, T3 muted) and Half |
| **S3** Timeline | Half in song mode while playing (with the "stop to change" strip), and Max stopped |
| **S4** Mix and the sound panel | Mix, and FX's pages over Pads at Half |
| **S5** Phone | Pads and Timeline at 852 × 393 (mock only) |

## 3. Before / after

| Screen | Before | After |
|---|---|---|
| SLOOP Song (was Arrange) | `before/sloop-ipad-song.jpg` | `after/sloop-ipad-song-half.jpg`, `-nogrid`, `-max` |
| SLOOP Sequence | `before/sloop-ipad-sequencer.jpg` | the editor in `after/sloop-ipad-song-half.jpg` |
| SLOOP Timeline | (part of Arrange) | `after/sloop-ipad-timeline-half.jpg` |
| SLOOP Shape | `before/sloop-ipad-sound.jpg` | `after/sloop-ipad-fxpanel.jpg` (sound panel), `after/sloop-ipad-mix.jpg` (GLO) |
| SLOOP Browse | `before/sloop-ipad-library.jpg` | sounds panel (not captured: see "Not verified") |
| Section hold menu | – | `after/sloop-ipad-section-menu.jpg` |
| SLOOP with `-sloop-classic` | `before/sloop-ipad-song.jpg` | `after/sloop-ipad-classic-song.jpg` (unchanged) |
| Skiff Pads, Timeline, Mix, FX panel | `before/skiff-ipad-*.jpg` | `after/skiff-ipad-*.jpg` |
| Phone (Skiff Song, SLOOP's four tabs) | `before/*phone*.jpg` | `after/*phone*.jpg` |

**Skiff is unchanged**, compared pixel by pixel on the PNGs (`-demo-skiff -demo-stopped`): Pads, Mix and the FX panel are **pixel-identical**. The Timeline differs by at most 2/255 in 38 pixels, which is rendering noise. The phone shots differ only in the home indicator (the capture) and the SLOOP demo's running clock. **Deliberately unified:** nothing on Skiff. One change shows on SLOOP everywhere, phone and `-sloop-classic` included: the drum track's name is "Drums" where it said "Track 4" when no kit name was known.

## 4. What was built

- **`ios/FM1/SloopSong.swift`** (new, SLOOP only): `SloopSongPage` (tool row, Pads/Timeline, the editor panel with Skiff's tab, carets, three places, drag and flick, VoiceOver adjustable); `SloopPads` (heads, the loop now, section pads with waiting / next / playing / edited / song / recording states, tap with the "load over edits?" ask, the hold fan menu); `SloopHead`, `SloopLoopCell`, `SloopEditorPane`, `SloopSongModeKeys`, `BarProgress`.
- **`ui.shell`** in `EditorUI`: true for Skiff's Song tab (as before) or SLOOP on the iPad (`ui.sloopShell`). Every shared place that meant "the Song · Mix layout" reads `shell`. Everything Skiff-only (its song store, the pool, its playback mode, `SkiffNavigator`) still reads `songTab`. With SLOOP disconnected `shell == songTab`, which is why Skiff can't have changed.
- **`-sloop-classic`** keeps the old four tabs, for comparing (and a way back if needed).
- **`-section-menu B`** opens a section's hold menu at launch, for screenshots, as `-sound-panel` does.
- **Fixes found on the way:** MixerPage sent Skiff's page numbers over the screen link on SLOOP (strips touched → SLOOP's SONG page; the GLOBAL card → SLOOP's NOTES page; the lit edge watched SONG). It now uses each card's own SLOOP page and leaves the FM-1 alone for the strips. GLO on the panel's key grid opens Mix on SLOOP. SAVE pressed again closes the sounds panel and shows the sections.
- **Tests:** `SongOrder.appending(section:bars:)` (Add to the song) with 3 new tests in `SongTests.swift`. `swift test` in `ios/SloopKit`: **294 tests in 51 suites passed** (200 s; none of the known flakes failed this run). The app builds for the simulator with no errors.

## 5. Shared files touched (for planning the merge)

| File | Change |
|---|---|
| `EditorUI.swift` | `sloopShell`, `shell`, `enterShell()`; the page redirects read `shell`; `Page.sloopPadTabs` |
| `AppView.swift` | sets `sloopShell`; Song tab → `SloopSongPage` when on; Sequence and the track box hidden in the shell; SLOOP's screen-link follow (panel, GLO → Mix, SEQ → Song, SAVE layer, SAVE again) |
| `TopBar.swift` | a SLOOP branch in Skiff's one-row layout with `SloopSongModeKeys`; tabs read `shell`; Mix's FM-1 page on SLOOP |
| `Pads.swift` (FunctionPads) | HOME / SAVE / SEQ / GLO / families read `shell`; SLOOP's SEQ and GLO cases |
| `SoundPanel.swift` | follow reads `shell`; dismiss goes to `ScreenMap.of(session).home` (127 on Skiff, as before) |
| `MixerPanel.swift` | no Skiff page numbers on SLOOP (strips, cards, the lit edge, the card count) |
| `TrackMenu.swift` | one `songTab` → `shell` |
| `Entries.swift` | SLOOP's drum track named "Drums" |
| `SongPage.swift` (SLOOP's) | `lane:` mode for the Timeline (no section keys, no header, 96 pt blocks) |
| `SloopKit/Song.swift`, `SongTests.swift` | `appending(section:bars:)` and its tests |

**Merge note (superseded by round two, §9: `perform-grid-map` is now merged in):** a trial `git merge-tree` against `perform-grid-map`'s current tip (`790c2ed`) has **no conflicts**. But that branch has since moved Skiff to **one row above the pages** (board 47 b: Song · Mix and the Song tab's tools in the top row, the playback mode in the tempo panel). This branch's SLOOP top bar follows the earlier two-row Skiff layout (the bar, then Pads' tool row). After both land, SLOOP's row should follow 47 b too: Loop · Song in the tempo panel beside the playback mode's place, SONG REC and "Loop the song" in the row's Song tools. That's a follow-up once `perform-grid-map` settles. `SloopSongPage`'s divider is also a smaller copy of `SkiffSongPage`'s, kept separate so as not to edit `SongTab.swift` while it's in flux. Extracting one shared `SongSplit` is the clean-up after the merge.

## 6. Open questions for you (with my recommendation)

1. **Agree the structure map's SLOOP section?** Song · Mix on the iPad, Shape and Browse gone as tabs. *Recommend yes:* nothing is lost; every old tab's content has a place (table above).
2. **Sections as tall pads across the rows, or a grid of track × section cells?** A grid would look more like Skiff's Pads, but every cell in a column would do the same thing, because a section holds all four tracks. *Recommend tall pads* (built), with the loop now as its own column.
3. **Timeline: wrapping blocks (built) or a ruler lane (board S3)?** I reused the old order editor (drag, resize, flick-delete, its VoiceOver actions) rather than rebuild it on a ruler. On a bar ruler it would read more like Skiff's Timeline. *Recommend the ruler* as a follow-up, after you've tried this one.
4. **SYSTEM and MIDI 1–3 on Mix, or in Settings?** They're setup, not mixing, and make Mix's card list long. *Recommend Settings*, but only with your OK: it moves a SLOOP feature.
5. **The phone:** follow the phone Pads/Timeline work on the other branch (S5), or keep SLOOP's four phone tabs for now? *Recommend wait*, then do the phone in one pass for both firmwares.
6. **`-sloop-classic`:** keep it as a hidden way back for a release or two, or remove it once you've agreed? *Recommend removing it* after the device check passes.
7. **The Song view switch's VoiceOver hints** speak of "entries" and "scenes" (Skiff's words). It's shared (`SongTab.swift`), so I didn't touch it during the other branch's work. *Recommend* firmware-aware hints after the merge.
8. **Empty section pad:** I gave it a tertiary-grey outline for contrast (1.4.11). It reads a little louder than Skiff's empty pads. Taste call: keep it, or use a dashed outline as old SLOOP did?

## 7. Verified, and not verified

**Verified (simulator, iPad Pro 13" M5, iOS 26.2, the SLOOP demo FM-1):** the Song tab at No grid, Half and Max; Pads and Timeline; FX's panel over Song; Mix; the section hold menu; `-sloop-classic`; Skiff unchanged (above); SloopKit's tests; the app build; contrast computed from the tokens (below).

**Not verified:**
- **No taps were driven.** Simulator input needed your approval and you were away, so every screen was reached by launch flags. Not exercised: the divider drag and flick, tap-to-play a section, the waiting outline animating, the load-over-edits ask, the destructive confirm row, store / clear / add to the song through the UI (add is unit-tested), mute, the sounds panel from the head's name, SAVE and GLO behaviour, and the fake's answers to any of these.
- The screen link on a real FM-1: the follow rules are written from `SoundPage.tab` and `ScreenMap.sloop`, not tried.
- VoiceOver, keyboard, largest text, Reduce Motion (code paths exist; not run).
- Animation feel and hitches (the simulator can't show them).
- The phone (not changed) and the newer flash chip (other branch).

## 8. Design-standards pre-flight

1. **Right problem:** yes. The brief was to bring SLOOP into the locked Skiff direction, not a new style round. Rule zero raised one framing question, sections as pads vs a grid (Q2).
2. **Grayscale:** hierarchy holds. Playing sections are filled, stored ones grey with a band, empty ones are wells with an outline, waiting ones have the outline, and every state has a word, never colour alone.
3. **Spacing:** Skiff's measures reused (12 between columns, 4 / 12 row gaps, the 12 inset in the panel).
4. **Type:** Barlow / Barlow Condensed through `Font.lupe` / `lupeNumber`; two weights per view.
5. **Tokens:** all colours from `Theme` (no hex in `SloopSong.swift`); radii nest (12 pads, 16 outline at 4 out).
6. **States:** sections have empty, stored, loaded, playing, edited, next bar, the song's next, song and recording. Disabled: Clear while playing ("stop first"). Refusals: `songMessage` in the tool row. Loading and error states come from the shared connection and lost-FM-1 states.
7. **Contrast (computed):** primary text on control 12.9:1; secondary on page 7.6:1, on panel 6.8:1; dark text on the lit sections 4.9 (blue), 9.0, 12.1, 6.4:1; "· edited" amber 11.1:1. **Two failures found and fixed:** "empty" at 13 pt in tertiary grey was 3.9:1 (now the secondary grey); the empty pad's edge was 1.25:1 (now tertiary, 3.9:1, over 1.4.11's 3:1).
8. **Keyboard / focus:** SwiftUI buttons throughout. Not run with a keyboard.
9. **Targets / semantics / motion:** pads and the tab well over 44 pt. Half's heads use 32 pt keys in 42 pt rows (the same exception Skiff takes, over the 24 floor). Every drag has a non-drag way (tap the tab, the adjustable; menus and VoiceOver actions on blocks and sections). Reduce Motion swaps slides for fades.
10. **Taste anchor:** data-dense tool (Tufte / Few), as the rest of Lupe.
11. **Tells:** `check-tells.sh` on the five boards found **none over threshold**. On the Swift code it found no files it can scan: not a pass. Eyeball: the layout comes from the project's own Pads, not a generic grid.
12. **Behaviour defaults:** destructive friction is the in-place confirm. No toasts carry actions.
13. **Rendered check:** `check-render.mjs` is for web pages and doesn't apply to SwiftUI. The simulator screenshots were read instead; largest faults fixed in order (the tab covering T4's head, the Max label over the bar, the Timeline cut off at Half).
14. **Gold compare:** against Skiff's own Pads and Timeline (`before/skiff-ipad-*`), the project's reference. The one difference: the SLOOP pads are tall columns, not a grid (Q2). **No fresh-eye subagent review was run.**

## 9. Round two: the one row (Scott, via the Bluetooth PoC session: "Yes, update SLOOP")

`perform-grid-map` at `66a426b` merged in (`7f8ece0`, a plain merge, no rebase). It brought the one row (75dc3db, 790c2ed), Pads · Timeline · Mix (66a426b), the Pads and Timeline open tab (317d2d5, 710f7fe), Timeline option A (bf87863), the in-place confirms (18a29e4) and Settings › Touch (826e2d4). **The merge had no conflicts.** One compile fix followed: Labs' divider and flick names changed in 826e2d4, so `SloopSongPage` now reads `DividerFeel.current` and `Labs.flickSpeed`, as Skiff's Song tab does. The merge commit on its own doesn't build; `c7fe92e` does.

**SLOOP on the new tabs** (`c7fe92e`, SLOOP-side only; no Skiff code changed):

| Skiff now | SLOOP | Notes |
|---|---|---|
| One row: FM-1 key ⌄ · Pads · Timeline · Mix · the tab's tools · Keys · transport | Same row, same keys (Skiff's `songTabs` and transport reused) | SLOOP's project name and its Save key with the "edited" dot left the bar: Projects is in the FM-1 menu, as on Skiff. **Q9** |
| Pads tools: Patterns, Launch at, Cancel waiting | **SONG REC** | SLOOP has no pool, no launch quantize (a section always starts on the next bar) and no per-track cancel |
| Timeline tools: Undo, Patterns, zoom | **SONG REC, Loop the song**, "4 steps · 20 bars" (and the playing step and bar) | The order wraps rather than zooming; its own Undo (after a delete) stays in the panel's line |
| Playback mode in the tempo panel, its word in the readout | **Loop · Song in the tempo panel** ("Song mode"), "Loop" or "Song" in the readout | Fits SLOOP's model: song mode is one global setting, as Skiff's playback mode is. SONG REC and REC still take the readout's word while on |
| The strip under the row (refusals, notes) | **SloopStrip**: SLOOP's `songMessage` ("Stop the song to change its order"…) and "goes to the FM-1 when you stop", with Stop where stopping is the way out | |
| The Pads/Timeline open tab for the track controls | **Not applied.** SLOOP has no track-controls box under a pad: its whole-track knobs are in the editor beside the step panel | Nothing to open |
| Timeline option A: resting 32% tint with a track-colour edge, full colour only while playing, selected = grey with a 3 pt outline | **Applied** to SLOOP's Timeline blocks (resting, the playing step solid, the block whose menu is open selected) and to the **section pads** (stored or waiting: the tint; sounding: solid; in the tracks but stopped, loaded or edited: the selected look; empty: the well) | Contrast computed for SLOOP's four colours: light text on the tint 7.6–11.1:1; the edges 5.0–12.3:1 on the page; the 3 pt outline 3.9–9.6:1 on grey |
| In-place confirms | SLOOP already used them (section Clear, Store over a stored section). **New:** SONG REC over an existing order asks in place at its key. Before, there was no ask in the new layout; on the old Arrange page it was a system dialog | |
| Settings › Touch | Applies as is (it's app-wide). "Confirm before clearing a pad" is about a Skiff pad. SLOOP's section Clear always asks, because the FM-1 keeps no copy | **Q10** |

**Verified (simulator):**
- **Skiff is unchanged by this work.** The merged branch's build was compared with `perform-grid-map`'s own tip (built in a throwaway detached worktree, since removed). Pads at No grid and Mix are **pixel-identical**. Pads at Half, the Timeline and the FX panel differ by **1–2/255** in under 320 pixels: rendering noise. `one-row/before` vs `one-row/after`.
- The SLOOP screens in `one-row/after`: Pads at No grid, Half and Max; the Timeline; Mix; FX over Pads; the section menu; `-sloop-classic` still shows the old four tabs.
- `swift test`: **294 passed**. The app builds with no errors.

**Not verified:** the same as §7 (no taps driven, nothing on the FM-1). New this round and also untried: the tempo panel's Loop · Song (no launch flag opens the tempo panel), the SONG REC confirm, and the strip. The canvas boards S2–S4 still show the earlier two-row bar; I haven't redrawn them.

**New questions:**

9. **Projects on SLOOP.** The old bar showed the project's name and a Save key with an "edited" dot. Now, as on Skiff, Projects is in the FM-1 menu. Fine to lose the always-visible name and dot? *Recommend yes,* for parity, but SLOOP's projects are saved by hand more often than Skiff's slots, so watch for it on the device.
10. **Section Clear and "Confirm before clearing a pad".** *Recommend* SLOOP's section Clear keeps asking whatever that setting says: a section has no copy anywhere, and a Skiff pad's pattern survives in the pool.

# Lupe: structure map

Where everything lives (CLAUDE.md, rule 4). Change this first, get Scott's OK, then design the screen. Skiff on the iPad unless noted.

## Tabs

| Tab | What's on it | Panels that come in over it |
|---|---|---|
| **Song** | Pads (default; from 2026-11-09 a grid of all six tracks' entries, section below) or Timeline, switched at the top left; the pattern editor below the divider (No grid / Half / Max) | Sound panel (right), Sounds panel, Sampler (in the editor's place) |
| **Mix** | Mixer carousel: levels, sends, the FX pages | Sound panel, Sounds panel |

**One row above the pages** (Scott, 2026-11-10, board 47 direction b, built): the FM-1 key ("Demo ⌄", its menu now also Projects… and Play through the iPad), Pads · Timeline · Mix (since 2026-11-10; was Song · Mix and a Pads / Timeline switch), then the tab's tools (Pads: Patterns, Launch at ⌄, Cancel N waiting; Timeline: Undo, Patterns, zoom), then Keys, REC, Play and the readout ("Song · 120 BPM": the playback mode's word; its three keys are in the tempo popup). As the row narrows the tools give way in order: the "Launch at" words, Patterns to its icon, Cancel to ✕ N; Play, the tabs and Cancel never go. A refusal, an unseen scene or the Timeline's "Tracks end at…" shows on a strip under the row until it's dealt with. The Pads and Timeline start at the page's top (52 pt back).

**The iPad's tab bar is Song · Mix** (Scott, 2026-11-10). The Sounds tab went: its browser is the **Sounds panel** ("Choose a sound for Track N": engines, presets in three columns, kits, the 32 user slots, user samples, a pad's or block's own sound). It's the same view the tab used, so nothing was lost. It comes in from the right over Song or Mix, doesn't dim the page, and sits to the left of the sound panel (ENV, LFO…) when that's open, so a sound can be picked and shaped at once. Ways in:
- **The track head's name** with its chevron ("Acid ⌄"), on Pads, the Timeline and the Mix strips. This is the visible way in.
- SAVE (PRESETS, then USER), on the FM-1 or its key.
- The sound panel's "Sounds ⌄".
- A track's long-press menu.
- A pad's or block's "Select sound".

It closes with Done, SAVE's next press, another tab or Escape.

**The iPad's tabs are Pads · Timeline · Mix** (Scott, 2026-11-10: the phone's split). Pads and Timeline are the Song page's two views: going between them is the same slide as before, the editor staying put under them, and the tools after the tabs follow the tab. The Pads / Timeline switch went. SLOOP's top bar still has its own tabs: it follows later.

The phone (landscape) splits Song into **Pads** and **Timeline** tabs: Pads · Timeline · Mix · Sounds (decided 2026-11-08, phone only). **The phone keeps its Sounds tab** until its Song tab exists: on Skiff today its Song says "on the iPad for now", so Mix and Sounds are its working tabs.

## The FM-1's buttons

| FM-1 button | On the iPad |
|---|---|
| FX, SEL, ENV, LFO, EDIT, ARP | Open the sound panel on that button's pages; pressed again, step its pages |
| SEQ | The Song tab's places: NOTES and FEEL in the step inspector, PATTERN, AUTOMATION, SONG |
| GLO | The Mix tab; again, its next section |
| HOME | Closes the sound panel |
| ARP held (PERFORM) | Song › Pads while held, then back (2026-11-07; unchanged by the grid) |
| SAVE | PRESETS and USER: the Sounds panel over the tab that's up (2026-11-10); PATTERNS: the Song tab's Patterns drawer; PROJECT: the Projects sheet. Held: the song layer |
| PLAY, REC | The transport |

**On screen** (2026-11-08): with the sound panel open, the same 12 keys sit in two rows at its foot, in the FM-1's order. With it shut there are none; pages open from the FM-1's own keys. Settings › Sound buttons brings back the FX…SEQ rail down the side (and the panel then leaves its keys out).

## Pads as a grid: every track's entries in rows (decided 2026-11-09, mock before building)

*Scott, 2026-11-09: a pad grid with one row per track and one column per entry, so a drum and a lead pattern can be launched without changing the selected track, like a clip launcher. The same day it went from a Live tab of its own to **Pads itself becoming the grid** (Scott: "change the structure of pads to have rows like live"): one surface that launches, one scene row, four tabs on the phone. Decided: **a row's stop is its mute**; no column launch; a waiting pad tapped takes the launch back; while playing, any other pad tapped, the playing one included, is queued as the next to play. Mocked on the canvas, boards 35–40 (generator `design/boards/live.py`); no SwiftUI until Scott OKs the mock. Open questions and the protocol check: `design/perform-grid-questions.md`.*

**What changes.** The 4 × 4 of one track's entries and the track strip beside it become one grid: a row a track, its entries across. The strip's rows become the row heads, so nothing about a track is lost: what it plays, what's waiting, its mute. The firmware already allows launching any track: LIST op 3 PLAY takes any track and entry, and nothing on the FM-1 changes the selected track when it's sent.

**The cost, named:** Pads was polished (the selected pad's tab, the Emerge reveal, the 4 × 4 ↔ 2 × 8 glide). This rebuilds its layout. Reusing its pieces (the pad face, the scene row, `store.marks`, `PadGrid`) is a requirement of the build.

### What's on it

| Part | What it holds |
|---|---|
| **Tool row** | The Timeline / Pads switch, Launch at (LOOP, BAR, BEAT, NOW), Cancel waiting (only while something waits). |
| **Row heads** (left, one a track) | Number, name and colour, Mute (also the row's stop: PERFORM op 3, staged to the launch point while playing; the track keeps its place and comes back in time). The selected track is marked. **Tapping the number selects the track**, and with it the editor and the FM-1's knobs. |
| **Pads** (6 rows × the entries) | One pad an entry. **Tap: launch it** (at once stopped, at the launch point playing). On the selected track's row a tap also selects the pad for the editor, as today; **on another row it launches only** (Scott, 2026-11-09), so the selection (and the FM-1's knobs) don't jump mid-set; the row's number selects. **While playing, a tap queues the pad as the track's next, the playing pad included** (Scott, 2026-11-09): it starts again at the launch point. Tap a waiting pad: take the launch back. |
| **Scene row** (under the grid) | Store and the 16 scenes, as now. Held, the grid outlines each track's pad for that scene. The editor's Open key sits at its end (board 33). |

### The three positions (the divider)

| Position | The grid |
|---|---|
| **No grid** (editor shut) | The full grid (board 35): rows about 116 pt, as many columns as the song uses. |
| **Half** (the default) | Six lane-height rows (42 pt), exactly today's compact strip rows, with the pads running on to the right of each (board 37). The 2 × 8 block goes; the scene row (32) and the editor under it, as now. |
| **Max** | The selected track's row of 16 (64 pt), as today; the track menu in the editor's header picks the track (board 38). Six rows don't fit. |

### Editing, now that pads are small and shared

- **Hold menus** stay on every pad (any row): they act on that track's entry, without selecting it.
- **Drag to rearrange** within a row (that track's list), as now. Across rows (copying an entry to another track, which the shared pool allows) is left out for now.
- **The selected pad's track controls** keep hanging under the selected pad, as today (Scott, 2026-11-09; board 35). At No grid the box (396 × 132) covers about three of the next track's pads; tapping the pad again rolls it away, and on the bottom row it opens upward. At Half and Max, the border alone.
  - **Build note (Scott, 2026-11-09):** the box sits slightly too high today. The gap the selected pad's highlight keeps from the next pad has to carry through: the same gap between the top of the box and the bottom of the next pad. Check on the iPad at each row, the bottom row (box opening upward) included.
- **The editor** follows the selected pad, as now.

### The FM-1's buttons

- **ARP held (Skiff's PERFORM layer)** shows Song › Pads while held or locked, then goes back to where you were (the 2026-11-07 rule, unchanged).
- **The sound keys work during a performance** (Scott, 2026-11-09): ENV, LFO, FX, SEL, EDIT and ARP tapped bring the sound panel in over Pads, as now, for the selected track. Agreed (board 39, Scott 2026-11-09): at No grid the panel sits between the tool row and the scene row, so Launch at, Cancel waiting and all 16 scenes stay in reach; the row heads and the columns left of it stay live.

### What a pad shows

| State | Shown as (structure, not look) |
|---|---|
| Empty | An empty well; VoiceOver reads "empty". PLAY on an empty entry is refused (rc 1) and leaves whatever was staged, so a tap does nothing; its hold menu still offers New and Set. |
| A pattern | Its number ("05") and passes ("×4"). |
| A REST | "REST". Launching it silences the track. |
| A chain | One wide pad across its entries. A tap on any part launches from the chain's first (firmware does this). |
| An entry with a sound | Its top right corner cut, as on the FM-1. |
| **Playing** | The track colour, a pass bar, the pass ("2/4") when REPS is over 1. On a muted row: outlined, not filled. |
| **Waiting** (a launch) | A dashed outline and when it lands ("bar 11"). Reduce Motion: static. |
| **The song's next** (SONG ON and ONCE) | A thin grey outline and "next": it comes in by itself (`SongPlayback.marks` already separates it from a launch). |
| A scene held | A white outline and "S3" on each track's pad, for scenes Lupe has seen; an unseen one says so in the tool row. |

Progress and countdowns come from Lupe's own count of the MIDI clock, per track; when that isn't known, no bar.

### How many columns

Entries A to the last one any track uses, plus one empty column (so there's always somewhere to add), at least 8. More than fit: two-finger pan sideways.

### On the phone (landscape)

The Pads tab becomes the grid (board 40): four tabs as now (Pads · Timeline · Mix · Sounds). Six rows at 40, 8 columns in view, two-finger pan; row heads shrink to the number and Mute; the scenes at 34 under them. Under the 44 aim, over the 24 floor. The editor up: the selected track's row of 16, as round 4.

### What it leaves out on purpose

- No column launch: Skiff's scenes aren't columns (decided 2026-11-09).
- No per-pad launch settings: LAUNCH is one setting for the whole FM-1.

### Accessibility floor for it

Each pad is a button: "Lead, entry C, pattern 13, waiting, bar 11". Rows are groups named for the track. The scene preview gets a VoiceOver action as its non-hold way in. Every drag keeps its hold-menu way in (2.5.7). Pads at 44 pt or more at No grid; Half's 42 and the phone's 40 are the exceptions, over the 24 floor.

## The FM-1 disconnected (2026-11-09, board 42: pick before building)

*Scott, 2026-11-09: "a dedicated pattern and state" for a lost FM-1; today the Song tab falls back to the old Arrange page, dimmed, and other tabs show a page whose title and first line both say "FM-1 disconnected". Both cut in. The motion rule (`design/DESIGN.md`) applies.*

| State | When | Proposed (option A) |
|---|---|---|
| **Lost** | Connected, then the cable or power goes | The page you were on stays, faded back and grey, read-only (touches off); a card drops from under the top bar: "FM-1 disconnected", what to do, "Looking for it". |
| **Back, reading** | Found again; the session re-reads the FM-1 | The card's line blends to "Back · reading the FM-1" with a bar; the page stays held. |
| **Picked up** | Read | The card rises away; the page returns to full colour, where you were. |
| **Searching** (never connected this launch) | First launch, no FM-1 | B's full page (as today's, its text fixed), with the same entrance. |
| **Wrong firmware** | Connected, unknown firmware | B's full page, its own text. |

Motion: lost in 300 ms (page fade) and 250 ms (card down, ease-out); state blends 150 ms; picked up 200 ms (card up, ease-in) and 250 ms (page back). Reduce Motion: cross-fades only. Options B (a page of its own) and C (status in the top bar) are on the board.

## SLOOP: the same tabs, its own song (2026-11-10, proposed: Scott to agree before merging)

*From the SLOOP design pass (`qa/sloop-design-pass-2026-11-10/README.md`, boards S1 to S6). SLOOP-Lupe is SLOOP 2.8.4 plus Lupe's screen link. Until now it kept the pre-Skiff layout (Sequence · Shape · Arrange · Browse on the iPad and the phone). The aim: one product whichever firmware is on the FM-1. The tabs, the panels, the divider and the gestures are the same; what's inside the Song tab is SLOOP's own model, not Skiff's faked.*

### What SLOOP's model is (and isn't)

| | SLOOP 2.8.4 | Skiff 2.2, for comparison |
|---|---|---|
| Tracks | 4: T1 to T3 synths, T4 the drum kit (16 lanes) | 6, any engine |
| What a track plays | **One 64-step loop.** No pattern pool, no list of entries | A list of up to 16 entries from a shared pool of patterns |
| Sections | **A to D**: each a snapshot of all four tracks' loops. Played from the next bar (playing) or loaded (stopped); stored from the working loop; cleared only stopped; the FM-1 keeps no copy | Scenes: one entry and a mute per track |
| Song | **An order of up to 16 steps**, each a section and a length in bars (1 to 64); loop or stop at the end; **song mode** (PLAY plays the order, STOP brings the loop back); **SONG REC** (sections played become the order) | Each track's list, played through |
| Mute | A track parameter, immediate (not staged to a launch point) | PERFORM's, staged |
| Solo | **None** in the protocol | Lupe's, through PERFORM's mutes |
| Mixer | Per track LEVEL, PAN, MUTE and the REV send (FX page); the shared DLY, REV/CHO and the GLO pages (GLOBAL, MASTER, DRUMS, TEXTURE, SYSTEM, MIDI 1 to 3) | Skiff's MIXER, DELAY, REVERB, CHORUS, GLOBAL |
| Sounds | Presets per engine, user presets, kits on T4, user samples | The same, plus Skiff's 32 user slots |
| Screen link | UI (cmd 90) and UI_GOTO; the FM-1's page, its layer (SAVE held: the song layer 7; SEL held: 5); no cursor | SCREEN 90 with the page's cursor, SCREEN_GOTO, METER, SCOPE |
| Pass progress | Each track's step and length in LIVE | Counted from the clock |

### Tabs

| | Today | Proposed |
|---|---|---|
| iPad | Sequence · Shape · Arrange · Browse | **Pads · Timeline · Mix** in the one row, as Skiff (2026-11-10, after board 47 b and 66a426b) |
| Phone | Sequence · Shape · Arrange · Browse | Unchanged in this pass (mocked, board S6; the phone's Skiff tabs are in flux on another branch) |

Where each old tab goes:

| Old SLOOP tab | Goes to |
|---|---|
| **Sequence** (the piano roll or drum grid, the step panel, the track's knobs, the track box with 64-step timelines) | The Song tab's **editor**, under the divider (No grid · Half · Max), as Skiff's. The track box's timelines become the **track heads** on Pads. The whole-track knobs (TrackPanel) stay beside the step panel when there's room, and are reached from the head's menu when there isn't |
| **Shape** (every button's pages) | The **sound panel**, from the right over Song or Mix: FX, SEL, ENV, LFO, EDIT and ARP on the FM-1 or the rail. GLO's pages go to **Mix** |
| **Arrange** (the section keys A to D, the song order as blocks, Loop / Song, SONG REC) | The Song tab: the sections as **Pads**, the order as the **Timeline**, Loop / Song and SONG REC in the tool row |
| **Browse** (engines, presets, user presets, kits, samples) | The **sounds panel**, from the track head's name ("Acid ⌄"), SAVE, the sound panel's "Sounds ⌄" or the track's menu |

### The Song tab on SLOOP

| Part | What it holds | Skiff pattern it reuses |
|---|---|---|
| **Tools** (in the one row) | SONG REC; on the Timeline, Loop the song and where the song is. Loop · Song (song mode) in the tempo panel, its word in the readout; refusals in the strip under the row | The one row, the tempo panel, SongStrip |
| **Track heads** (left, one a track) | Number, name, the sound name with its chevron (opens the sounds panel), its chips (CHORD, ARP), where the loop is (a bar for step / length while playing), Mute. **No Solo** (SLOOP has none; not faked). Tap the number: select the track | The H1 head (board 43), the sound key, chips (board 46) |
| **The loop** (a column beside the heads) | Each track's working loop, drawn as a small picture of its 64 steps; "changes not in a section" when the tracks were edited since the last store or load | The pad face (PadThumb's look) |
| **Section pads A to D** | One tall pad a section, across all four rows (a section holds every track). Empty: a well, "empty". Stored: its colour (TE_COL, as on the FM-1). Playing: filled, with the bar's progress. Asked for: the **waiting outline** and "next bar". The song's next (song mode): a thin grey outline, "next". **Tap:** play from the next bar (playing) or load (stopped; over edited tracks it asks first, in place). **Hold:** a fan menu: Store the loop here, Add to the song, Clear (the destructive confirm in place; stopped only) | Pads' waiting outline, "next", fan menus, the destructive confirm |
| **Timeline** (the switch's other side) | The song order as one lane of blocks on a bar ruler, each block its section's colour and its bars; the playhead in song mode. Tap a block: its menu (section, bars, duplicate, delete); drag to move; drag its right edge for bars. While the song plays the order can't change (the FM-1 refuses): "Stop to change the song", with Stop | The Timeline's lanes and blocks, the stop-to-rearrange strip |
| **Editor** (under the divider) | The selected track's piano roll or drum grid, the step panel; the header names the track (no pattern number: SLOOP has none) | The editor panel, its tab and carets, the three positions |

What SLOOP's Song tab leaves out, and why: no pattern picker, pool drawer, chains, launch quantize (LOOP, BAR, BEAT, NOW), Cancel waiting, scenes or per-track launches. SLOOP has none of them. A section always starts on the next bar.

### Mix on SLOOP

The four tracks' strips (LEVEL, PAN, MUTE, the REV send), then the shared cards: DLY, REV/CHO and the GLO pages. Skiff's MixerPage, as it is. Open question: whether SYSTEM and MIDI 1 to 3 belong on Mix or in Settings.

### The FM-1's buttons on SLOOP

| FM-1 button | On the iPad |
|---|---|
| FX, SEL, ENV, LFO, EDIT, ARP | The sound panel on that button's pages, over the tab that's up |
| GLO | Mix |
| HOME, the sequencer's pages | Song (the editor) |
| SAVE (PRESETS) | The sounds panel over the tab that's up |
| SAVE held (the song layer) | Song › Pads (the sections) |
| PLAY, REC | The transport |

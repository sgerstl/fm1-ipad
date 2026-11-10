# Lupe: structure map

Where everything lives (CLAUDE.md, rule 4). Change this first, get Scott's OK, then design the screen. Skiff on the iPad unless noted.

## Tabs

| Tab | What's on it | Panels that come in over it |
|---|---|---|
| **Song** | Pads (default; from 2026-11-09 a grid of all six tracks' entries, section below) or Timeline, switched at the top left; the pattern editor below the divider (No grid / Half / Max) | Sound panel (right), Sampler (in the editor's place), Presets |
| **Mix** | Mixer carousel: levels, sends, the FX pages | Sound panel |
| **Sounds** | Engines and presets for the selected track | Sound panel |

The phone (landscape) splits Song into **Pads** and **Timeline** tabs: Pads · Timeline · Mix · Sounds (decided 2026-11-08, phone only). Section "The phone" below has what each tab holds there and what's built.

## The FM-1's buttons

| FM-1 button | On the iPad |
|---|---|
| FX, SEL, ENV, LFO, EDIT, ARP | Open the sound panel on that button's pages; pressed again, step its pages |
| SEQ | The Song tab's places: NOTES and FEEL in the step inspector, PATTERN, AUTOMATION, SONG |
| GLO | The Mix tab; again, its next section |
| HOME | Closes the sound panel |
| ARP held (PERFORM) | Song › Pads while held, then back (2026-11-07; unchanged by the grid) |
| SAVE | Save (held: the song layer) |
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

The Pads tab becomes the grid (board 40). The whole phone layout, Mix included, is in "The phone" below.

### What it leaves out on purpose

- No column launch: Skiff's scenes aren't columns (decided 2026-11-09).
- No per-pad launch settings: LAUNCH is one setting for the whole FM-1.

### Accessibility floor for it

Each pad is a button: "Lead, entry C, pattern 13, waiting, bar 11". Rows are groups named for the track. The scene preview gets a VoiceOver action as its non-hold way in. Every drag keeps its hold-menu way in (2.5.7). Pads at 44 pt or more at No grid; Half's 42 and the phone's 40 are the exceptions, over the 24 floor.

## The phone with a Skiff FM-1 (landscape, 852 × 393; agreed and built 2026-11-10, boards 46–50)

*Before this (7137fa9): Song · Mix · Sounds, the iPad's three. Song shows a card, "Arrange on Skiff is on the iPad for now"; Mix is the iPad's MixerPage as it is, which doesn't fit (strips under the top bar, the effect cards over the strips, the foot off the screen: `qa/accessibility-2026-11-10/screens/iPhone-skiff-mix.jpg`). Sounds works. SLOOP's phone tabs (Sequence · Shape · Arrange · Browse) are unchanged by this.*

About 330 pt under the 44 pt top bar, inside the side safe areas (59 each side): 734 wide. One job a tab, never the iPad's canvas shrunk.

### Tabs

| Tab | What's on it | Built in this round? |
|---|---|---|
| **Pads** | The grid (board 40; boards 46, 47). | Yes |
| **Edit** | The selected pad's pattern and its steps (below). Takes Timeline's place on the phone for now (Scott, 2026-11-10). | Yes |
| **Timeline** | The song's timeline for the phone. Not designed; **left out** until it is. When it comes, the phone has five tabs or Edit and Timeline share one. | No |
| **Mix** | One section at a time, picked down the left (below). | Yes |
| **Sounds** | As built. | — |

### Pads (board 40)

| Part | On the phone |
|---|---|
| **Row heads** | 72 wide: the number (tap: select the track; held: its menu) and Mute (34, the iPad's speaker key). No name; VoiceOver reads it. |
| **Pads** | Six rows with 4 between: 40 at the least, up to 44 where the phone has the height (44 on a 6.3-inch iPhone 17). Pads 78 wide (the iPad's small face: letter and number); 8 columns in view (7 with the rail), the rest by a pan sideways, one finger or two as the grids since 2026-11-07. Same faces, states and hold menus as the iPad's (`PadsPage` `.phone`, reused, not a second grid). |
| **Scenes** | Store (88, as the iPad's: narrower cut its word) and the 16 scenes at 34, under the rows and the heads. Held: the preview, as on the iPad. A refusal (an empty scene tapped) shows over the scenes until dismissed. |
| **Launch at, Cancel waiting** | Not on the tab (no room for the tool row). A **Launch key in the top bar**, beside REC, showing the launch point and the waiting count; tapped, Lupe's menu: Loop Bar Beat Now (the setting ticked), what waits, Cancel waiting (board 47 drew them as segments; built as a menu). |
| **The selected pad's track controls** | The border only, as at Half. |
| **The pattern editor** | On the Edit tab, not under the grid (no room). |
| **Sound panel** | Over every Skiff tab, from the right, as on the iPad: the FM-1's ENV LFO FX SEL EDIT ARP (or the rail) bring it in for the selected track. On Pads it covers the right-hand columns and the scenes under them. |

Under the 44 aim (scenes 34, Mute 34, rows 40 on the smallest phones), over the 24 floor; each has a VoiceOver way in.

### The sound buttons (Scott, 2026-11-10)

Settings › Sound buttons works on the phone too: on, the rail (FX SEL ENV LFO EDIT ARP SEQ) runs down the right of every Skiff tab, 56 wide, its seven keys sharing the height (about 40 each); the page gives up its width. Off (the default), the panel brings the FM-1's 12 keys in two rows at its foot, as on the iPad. SEQ on the phone goes to Edit.

### Edit (board 50)

*Scott, 2026-11-10: "An Edit tab", so the step panel has a way in. The SLOOP phone's Sequence tab, for Skiff.*

| Part | What it holds |
|---|---|
| **Ruler** (28 tall) | The track and pattern the editor shows: "5 Piano · B · pattern 12 · C minor · 16 steps". Then the **Step N** key and Velocity. *The pattern menu is left out for now: Skiff edits the pattern a track is on, and a pad launched on Pads changes it.* |
| **The grid** | The selected track's pattern a bar wide (the phone's piano roll, or its drum grid on a kit), two-finger pan along the pattern. It follows the selected pad: tap a pad on Pads, or another track's number, and Edit shows that. Motion lanes are left out on the phone. |
| **Step panel** | **The Step N key** slides it in from the right, 320 wide, over the grid's right side, and closes it (an ✕ on the key while it's open: the inspector's own ‹ › sit where a × would). It scrolls when it's taller than the phone. Melodic: the Skiff step inspector (NOTES: PITCH MOVE LENGTH VELOCITY; FEEL: CHANCE RATCHET COND NUDGE; Sound at this step; Lock; ‹ › for the step). Drums: the drum step panel. A step tapped in the grid selects it; the panel follows. |
| **The FM-1's SEQ** | Lands on Edit with the step panel open (NOTES, then FEEL), as on the iPad. PATTERN, AUTOMATION and SONG pages: Edit too, panel shut. |

### Mix

The iPad's Mix holds six strips across the top and the four effect cards under them. At phone height they can't share the screen, so the phone shows **one of GLO's five pages at a time**, in the FM-1's order:

| Part | What it holds |
|---|---|
| **Selector** (left, 112 wide) | Mixer · Delay · Reverb · Chorus · Global, five keys at 44. The lit one is on screen; linked, the FM-1 shows the same page. **GLO on the FM-1 steps through them** (MIXER 1/5 … GLOBAL 5/5), as it steps the iPad's sections. |
| **Mixer** | The six tracks as **six rows** (one a track, like the Pads rows): number and name (tap: select), LEVEL on a horizontal fader in the track's colour with its dB, PAN, the REVERB send (the iPad's faders, laid across), Mute. Rows 48 tall. |
| **Delay, Reverb, Chorus, Global** | That page's card, the iPad's own (its four columns and graph), filling the space. No swipe between pages: a slide on a column turns it. |

Nothing changes on the iPad's Mix.

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

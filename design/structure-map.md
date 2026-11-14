# Lupe: structure map

Where everything lives (CLAUDE.md, rule 4). Change this first, get Scott's OK, then design the screen. Skiff on the iPad unless noted.

## Tabs

| Tab | What's on it | Panels that come in over it |
|---|---|---|
| **Song** | Pads (default; from 2026-11-09 a grid of all six tracks' entries, section below) or Timeline, switched at the top left; the pattern editor below the divider (No grid / Half / Max) | Sound panel (right), Sounds panel, Sampler (in the editor's place) |
| **Mix** | Mixer carousel: levels, sends, the FX pages | Sound panel, Sounds panel |

**One row above the pages** (Scott, 2026-11-10, board 47 direction b, built): the FM-1 key ("Demo ⌄", its menu now also Projects… and Play through the iPad), Pads · Timeline · Mix (since 2026-11-10; was Song · Mix and a Pads / Timeline switch), then the tab's tools (Pads: Patterns, Launch at ⌄, Cancel N waiting; Timeline: Undo, Patterns, zoom), then Keys, REC, Play and the readout ("Song · 120 BPM": the playback mode's word; its three keys are in the tempo popup). As the row narrows the tools give way in order: the "Launch at" words, Patterns to its icon, Cancel to ✕ N; Play, the tabs and Cancel never go. A refusal, an unseen scene or the Timeline's "Tracks end at…" shows on a strip under the row until it's dealt with. The Pads and Timeline start at the page's top (52 pt back).

**The iPad has no Sounds tab** (Scott, 2026-11-10). Its browser is the **Sounds panel** ("Choose a sound for Track N": engines, presets in three columns, kits, the 32 user slots, user samples, a pad's or block's own sound). It's the same view the tab used, so nothing was lost. It comes in from the right over Song or Mix, doesn't dim the page, and sits to the left of the sound panel (ENV, LFO…) when that's open, so a sound can be picked and shaped at once. Ways in:
- **The track head's name** with its chevron ("Acid ⌄"), on Pads, the Timeline and the Mix strips. This is the visible way in.
- SAVE (PRESETS, then USER), on the FM-1 or its key.
- The sound panel's "Sounds ⌄".
- A track's long-press menu.
- A pad's or block's "Select sound".

It closes with Done, SAVE's next press, another tab or Escape.

**Your samples** (batch list 3, built 2026-11-11, for Scott to agree): the FM-1's user sample slots have their own row in the Sounds panel's engine list, under User presets (a synth track's own sound only; not for a pad's or block's sound). Skiff's USR1–3, SLOOP's SMPL1–4. Each slot is a key that puts the track on it, ▶ to hear it (Skiff only: read back from the FM-1), and under it Record…, Import file… (WAV, AIFF, M4A from Files) and Clear…. Both open the sampler, which slides up from the bottom. The same rows sit under the Sample engine's sets. The track menu keeps Record sample…, which opens the sampler in the editor's place.

**The iPad's tabs are Pads · Timeline · Mix** (Scott, 2026-11-10: the phone's split). Pads and Timeline are the Song page's two views: going between them is the same slide as before, the editor staying put under them, and the tools after the tabs follow the tab. The Pads / Timeline switch went. SLOOP's top bar still has its own tabs: it follows later.

The phone (landscape) splits Song into **Pads** and **Timeline** tabs: Pads · Timeline · Mix · Sounds (decided 2026-11-08, phone only). Section "The phone" below has what each tab holds there and what's built.

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

## The Android phone with a Skiff FM-1 (Pixel, portrait; decided 2026-11-12, boards 53–58; **retired 2026-11-14 by decision 28, see the landscape section below**)

*Boards 53–58: `design/boards/phone-portrait.html` (screenshots in `phone-portrait/`). Board 53: **Select** at the end of the scenes row is the visible way to "Edit steps" (Scott, 2026-11-13); with it on, a pad tap picks the pad for the editor and launches nothing. Board 58 (time down) picked for the Timeline, 2026-11-13.*

*Boards 59–69 (P4 sound pages, P5 Mix · Sounds · Projects · Settings, P6 Timeline editing and automation): `design/boards/phone-portrait-2.html`, screenshots in `phone-portrait-2/`, page-by-page map in `design/phone-sound-pages.md`. Drafted overnight 2026-11-13 → 14 for Scott to correct; eight open questions marked in the notes, each with a recommendation. P4 is being built on those recommendations, provisionally.*

*Scott, 2026-11-12, through the build plan deck (vault `Projects/Dev/fm1-ipad/phone-skiff-decisions-2026-11-12.md`; research in `phone-design-research-2026-11-12.md`; mockup `design/boards/phone-pixel.html`). Skiff only, portrait only for v1. Out: firmware flashing, SLOOP, Bluetooth, landscape, sample import, exports, audio through the phone, sample recording. The landscape iPhone section above stays as it is.*

**Two FM-1 screens stacked.** A top bar, then the **top half** (the play surface: what you're playing) and the **bottom half** (what the FM-1's screen shows), with the iPad's divider between them in three positions: top only · split · bottom full.

| Part | What it holds |
|---|---|
| **Top bar** | The FM-1 key ⌄ (Projects…, Settings, Labs), Launch ⌄ (Loop Bar Beat Now, what waits, Cancel), REC, Play, the readout ⌄ (tempo; Loop · Song · Once) |
| **Top half's tabs** | **Pads · Timeline · Mix.** No Sounds tab (as the iPad since 2026-11-10); Mix shows GLO's five pages one at a time |
| **Bottom half** | **Always follows the FM-1's screen**: ENV LFO FX SEL EDIT ARP open their sound page there; SEQ the editor (NOTES, FEEL, PATTERN, AUTOMATION); SEQ's SONG and GLO and ARP held change the top half instead. HOME goes back to the editor. The Sounds browser opens here (the track name ⌄, SAVE, a hold menu) |
| **Sound pages** | A family row and a page row in place of the 12 keys (the FM-1 is beside the phone), the page's graph where it has one, then four controls in the FM-1's knob order. Dense EDIT pages (operators, zones, slices, lanes) are four controls first; their pictures come later |
| **Editor** | The roll or drum grid; under it, in the strip, **the step panel** (not over the grid). **Notes go in from the FM-1's keys only**, into the selected step (Chord adds up to 4). Automation: **one lane at a time** under the grid, with a lane picker |
| **Locks** | **Holding a step** locks knob turns to it while held (the FM-1's gesture), and the step panel's **Lock** key latches the same. Long-press on a step means only this; step menus go to a visible key. Each ◆ row clears on its own, and "Clear all locks" confirms in place. Locked steps carry a ◆ in the grid (board first) |
| **Pads** | The grid as on the iPhone; **Edit steps** has a visible way in from the selected pad as well as the hold menu |
| **Timeline** | **Time down** (six track columns, bars run down the screen; Scott, 2026-11-13, board 58). Top only shows 20 bars, so a 16-bar song fits whole |

**Labs, to try on the device:** following pauses after a phone touch; pin the bottom half's page; the phone piano under the grid; the Timeline with time across (board 57).

**Android rules** (research, 2026-11-12): nothing draggable at the side edges (the back gesture); the bottom ~24 dp clear for the home gesture; edge-to-edge with insets; Back closes the newest layer (a menu, a sheet, the bottom half's page) and never stops the song; pads answer on the phone without waiting for the FM-1's echo.

## The Android phone, landscape (decision 28, 2026-11-14, boards 73–74; replaces the portrait section above)

*Scott, 2026-11-14: the phone sits on the table and does the horizontal jobs the FM-1 does clumsily; sound shaping stays on the FM-1. Locked to landscape, status bar hidden, the camera cutout and gesture bar kept clear by the window's insets. The portrait divider, split and top-only states are retired.*

| Where | What |
|---|---|
| **Header, one line** | project ⌄ (Projects…, Mix…, Settings, Labs) · Loop ⌄ (launch quantize, what waits) · tabs **Pads · Edit · Timeline** as underlined words · readout (tempo, Loop · Song · Once) · Record · Play |
| **Pads** (board 74) | six rows: a 132 dp track head (number, sound, engine ⌄; tap selects, hold or the engine line opens that track's Sounds), MUTE, the pads panning sideways; Store scene and all sixteen scenes across the foot |
| **Edit** (board 73) | the ruler; sixteen steps across in fours (a kit: lanes by steps); under them the dials area (HOME's four sound knobs, the picked step's controls under "Step N ✕", or the FM-1's sound page as header and four dials) and beside it the keyboard strip that writes the picked step (Chord adds and takes notes), or the one-lane automation view (Lane), or a sound page's tiles |
| **Timeline** | time across, as the FM-1 and the iPad (P4, `ui/timeline`) |
| **Sheets** | Mix (the FM-1's GLO, or the project menu), Sounds (a track head, a pad's menu, the FM-1's SAVE › PRESETS and USER), Projects (the menu, SAVE › PROJECT), Settings and Labs |
| **A sound page on the FM-1** | Edit: its header and four dials take the dials area. Pads and Timeline: a short panel rises over the foot. HOME on the FM-1, or the back gesture, lowers it |
| **The FM-1's keys** | FX SEL ENV LFO EDIT ARP: the sound page as above. GLO: the Mix sheet. SAVE: Sounds or Projects. SEQ: the Edit tab (AUTOMATION its lane view, SONG the Timeline). HOME: back to where the phone was |

### The combined phone design on Android (decisions 31–35, 2026-11-14; boards 76 and 77)

What moves or changes place against the landscape table above. Edit and the docked sound panel (decisions 32, 35) are P4's and are not listed here.

| What | Where it is now |
|---|---|
| **The selected track** | Its colour at 28 % over the page, under its whole row on Pads (head, MUTE, every slot) and the Timeline (head and lane). The 2 dp outline is the launch timer's only (pads, MUTE, solo, scenes). The band travels between tabs as the outline did |
| **Pads** | Slots A to H always drawn: an empty one is an outline with its letter. Pass counts ×N and the next cue stay. A waiting pad no longer writes "bar N": the outline timer says it |
| **Scenes** | A short Store key with a dot, then the sixteen: empty outlined, stored filled, the current white |
| **LEVEL and PAN** | In the track head's hold menu (slid along their rows) and in Mix. The track controls box is gone for good |
| **Hold menus** | The radial menu with the iPad's set where the core can do it. Pad: Edit steps, Select sound, Set pattern, Play once more / less, Duplicate after, Move earlier / later, Clear. Empty slot: New pattern, Rest, Pick a pattern. Track head: Sounds, LEVEL, PAN, Mute, Solo. Timeline block: adds Edit steps and Move earlier / later |
| **Hold menu, its shape** (decision 36) | A wheel, the same on both phones: five choices in view in a nearly straight column beside the finger (a shallow curve, the middle one 76 dp out), each on a 22 dp stalk from a thin rim. A drag rolls the rest along the curve, fading at its ends; small triangles past the rim's ends say there is more. It opens on the first choice. A tap picks; a drag never does. No "More…" page |
| **Mix** | A pop-up with no title: MIXER DELAY REVERB CHORUS GLOBAL as words in line with the close key. A bus page is its four dials two by two at the left (DELAY MODE under them) and the FM-1's own picture at the right, 1.7 : 1, in greys and white |
| **Settings** | The grouped sheet: FM-1 · Touch (Slide to turn, Magnifier, Handedness, Haptics) · Sound pages (Show graphics, Sound keys) · Labs |
| **Launch menu** | Loop Bar Beat Now, then a footer: Cancel waiting, or "Nothing waiting" |
| **No FM-1** | The header stays, greyed; under it a card: what to do, the firmware (Skiff 2.5.1), that Lupe is looking, and "Use the demo FM-1". The demo is left from the song-name menu |

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

## Exports (2026-11-11, proposed: Scott picks on boards 51 and 52 before any export UI is built)

Four exports (vault `export-plan.md`): the song as audio, a session as audio ("Capture"), MIDI, and a Skiff backup (the whole FM-1: Skiff has no single-project file). A Lupe project file comes later. Where they live, three options:

| Option | Export (MIDI, song audio, Skiff backup) | Capture a session | Adds to the top row |
|---|---|---|---|
| **A** (proposed) | The FM-1 key's menu › Export…, a sheet with the four rows | The FM-1 key's menu, under Export… | Nothing |
| B | Projects sheet › a project's ⋯ menu (MIDI, the project file); the Skiff backup on the FM-1 page | The FM-1 key's menu, beside Play through the iPad | Nothing |
| C | The FM-1 key's menu › Export… | A Capture key between Keys and REC (held: its menu, including Capture the song) | One key, the first to go to an icon as the row narrows |

A take in progress shows in one place (board 52): **1** the readout turns into the take's time, level and Stop (proposed); **2** a strip under the row; **3** a ring and the time on the FM-1 key. Capture never looks like the FM-1's REC: a level waveform and the word Capture, never a red dot.

Files go to `Documents/Skiff/Exports` (and `SLOOP/Exports`), then the share sheet. The FM-1's buttons don't change.

# Lupe: structure map

Where everything lives (CLAUDE.md, rule 4). Change this first, get Scott's OK, then design the screen. Skiff on the iPad unless noted.

## Tabs

| Tab | What's on it | Panels that come in over it |
|---|---|---|
| **Song** | Pads (default) or Timeline, switched at the top left; the pattern editor below the divider (No grid / Half / Max) | Sound panel (right), Sampler (in the editor's place), Presets |
| **Live** (proposed 2026-11-10) | The performance grid: all six tracks' entries as rows of pads, the scenes under them. Launching only, no editing (section below) | none |
| **Mix** | Mixer carousel: levels, sends, the FX pages | Sound panel |
| **Sounds** | Engines and presets for the selected track | Sound panel |

The phone (landscape) splits Song into **Pads** and **Timeline** tabs: Pads · Timeline · Mix · Sounds (decided 2026-11-08, phone only). With Live: Pads · Timeline · Live · Mix · Sounds, five on the phone (tight: open question 4).

## The FM-1's buttons

| FM-1 button | On the iPad |
|---|---|
| FX, SEL, ENV, LFO, EDIT, ARP | Open the sound panel on that button's pages; pressed again, step its pages |
| SEQ | The Song tab's places: NOTES and FEEL in the step inspector, PATTERN, AUTOMATION, SONG |
| GLO | The Mix tab; again, its next section |
| HOME | Closes the sound panel |
| SAVE | Save (held: the song layer) |
| PLAY, REC | The transport |

**On screen** (2026-11-08): with the sound panel open, the same 12 keys sit in two rows at its foot, in the FM-1's order. With it shut there are none; pages open from the FM-1's own keys. Settings › Sound buttons brings back the FX…SEQ rail down the side (and the panel then leaves its keys out).

## The Live tab: the performance grid (decided 2026-11-10, mock before building)

*Scott, 2026-11-10: a pad grid with one row per track and one column per entry, so a drum and a lead pattern can be launched without changing the selected track, like a clip launcher. Decided the same day: **its own tab, called Live** (Song · Live · Mix · Sounds); **Pads stays** as the one-track view that edits and launches; **a row's stop is its mute**. Mocked on the canvas, boards 35–37 (generator `design/boards/live.py`); no SwiftUI until Scott OKs the mock. Open questions and the protocol check: `design/perform-grid-questions.md`.*

**What it's for.** Pads already shows all six tracks in its strip (what each plays, what's waiting, its mute), but launches only the selected track's entries. Live covers the gap: launching on any track from one screen. The firmware already allows it: LIST op 3 PLAY takes any track and entry, and nothing on the FM-1 changes the selected track when it's sent.

### Where it lives

**Its own tab, Live**, between Song and Mix. A playing mode apart from editing: no divider and no pattern editor under it, no sound panel over it. Pads keeps the 4 × 4 for one track, with the editing (hold menus, drag, record sample, track controls). The overlap is on purpose: Pads is where you build and try an entry, Live is where you play the song.

The FM-1's buttons: none of them opens Live. Whether FX…ARP open the sound panel over Live (as over Mix) or leave it alone while you play is open question 8.

### What's on it

| Part | What it holds |
|---|---|
| **Tool row** | Launch at (LOOP, BAR, BEAT, NOW), Cancel (everything staged, shown only while something waits), the transport as on Song. |
| **Row heads** (left, one a track) | Track name and colour, its mute, which is also the row's stop (PERFORM op 3: staged to the launch point while playing; the track keeps its place and comes back in time). The selected track is marked. Tapping the head selects the track; this is the only thing on the grid that changes the selection. |
| **Pads** (6 rows × the entries) | One pad an entry. Tap: launch it (PLAY: at once stopped, at the launch point playing). |
| **Scene row** (under the grid) | The 16 scenes, as Pads has them: tap to recall, Store latched then tap to store. Held, the grid shows the scene's pads (below). |

There's no track strip: the row heads replace it.

### What a pad shows

| State | Shown as (structure, not look) |
|---|---|
| Empty | An empty well, not a button; VoiceOver reads "empty". PLAY on an empty entry is refused (rc 1) and leaves whatever was staged, so it does nothing. |
| Empty past the list's end | The same, quieter: Skiff never plays it. |
| A pattern | Its number ("05"), as Pads. |
| A REST | "REST". Launching it silences the track, so it's also the grid's per-track stop where a list has one. |
| A chain | One wide pad across its entries, boxed as the FM-1 and Timeline draw it. A tap on any part launches from the chain's first (firmware does this). |
| An entry with a sound | Its top right corner cut, as on the FM-1. |
| **Playing** | Marked, with the pass progress through its pattern and, for REPS above 1, the pass ("2/4"). |
| **Staged** (a launch waiting) | Marked differently from playing, with the countdown to the launch point. Reduce Motion: a static mark, no blinking. |
| **The song's next** (SONG ON and ONCE) | A quieter mark than a launch: it comes in by itself. Skiff stages both through the same field; Lupe already separates them (`SongPlayback.marks`). |
| Muted row | The whole row dimmed, plus the row head's mute. Not by colour alone. |
| A scene held | The pad each track would go to outlined, for scenes Lupe has seen; an unseen scene says so in the tool row, as now. |

Progress and countdowns come from Lupe's own count of the MIDI clock, per track. When that count isn't known (stopped, no Start seen, RAND between notes), the pad shows playing and staged without progress.

### How many columns

Not always 16. The grid shows entries A to the last one any track uses, plus one empty column, at least 8. Most songs use fewer than 16, so the pads stay bigger. More than fit: two-finger pan sideways (the design brief's rule: one finger plays, two fingers move the view).

### On the phone (landscape)

A fifth tab, Live. Six rows of pads at 44 pt; 8 columns in view, two-finger pan for the rest; the row heads narrow to the track number and mute. **The scene row doesn't fit under the grid** at phone height: open question 4 for where it goes.

### What it leaves out on purpose

- No column launch ("launch all of column C") in the first version: Skiff's scenes aren't columns, and two kinds of row-across launch would be confusing. Open question 3.
- No editing on the grid: no hold menus, no drag, no editor. A row head's hold could offer "Edit in Pads" (select the track, go to Song).
- No per-pad launch settings: LAUNCH is one setting for the whole FM-1.

### Accessibility floor for it

Each pad is a button: "T2, entry C, pattern 05, playing, pass 2 of 4" or "… staged, lands in 1 bar". Rows are containers named for the track. A held scene preview gets a VoiceOver action ("Show scene 3 on the grid") as its non-hold way in. No drags on the grid, so 2.5.7 has nothing to cover. Pads stay at 44 pt or more on the iPad; the phone at its 44 pt floor is why it pans instead of shrinking.

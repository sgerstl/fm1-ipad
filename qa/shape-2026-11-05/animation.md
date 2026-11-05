# Shape: what moves, from Skiff's own source

Written before building (2026-11-05). Source: `~/code/skiff-src/firmware/src`, Skiff 2.2 (screen-link branch).
One UI frame is about 15 ms (`ui_draw.c:61`: 9 frames ≈ 135 ms).

| Page | What animates | Trigger | Timing | Source |
|---|---|---|---|---|
| Every page, the four columns | The value's changed digits roll like a slot machine: up, the old digit leaves upward; down, the reverse. The ones digit moves first, and each place to the left starts one frame later. All of them finish together. | A value changes | `ROLL_FRAMES` 9 (≈135 ms), cubic ease-out `ROLL_EASE` (17 entries, no overshoot) | `ui_draw.c:58-74`, `roll_text` `:110-140` |
| Every page, the four columns | No roll: shown at once | A change within `ROLL_SNAP` (3 frames, ≈45 ms) of the last one (a fast turn), a change of length or sign, a non-digit, a name or enum, another label or unit, a page or track change, ANIM OFF | at once | `ui_draw.c:64-68`, `roll_dir` `:77-92`, `roll_note` `:94-104` |
| Every page, the four columns | The column of the knob just turned is lit ("hot"): label, value and gauge in the accent | Any knob turn on the FM-1 | `ui.hot_t = 40` frames (≈600 ms), counted down each frame | `ui_input.c:1880`, `ui_draw.c:416`, `:1457` |
| ENV, ENV 2 | The point the knob just turned moves lights white: the peak (ATTACK), the decay's end (DECAY, SUSTAIN), the release's start (SUSTAIN, RELEASE) | Knob turn (`hot_col`) | while `hot_t` runs (≈600 ms) | `ui_graph.c:173-185`, signature `:1628` |
| LFO, LFO 2 | The wave over a running 2 s window from the last restart; past 2 s the window scrolls and shows the last 2 s; a 5 px dot marks where the LFO is now | Always while the page is open; redrawn whenever the LFO has moved a pixel (216 px over 2 s, ≈9 ms) | real time, `LFO_WIN` = 2 s | `lfo_view_at` `ui_graph.c:80-104`, `graph_lfo` `:204-270`, signature `:1631` |
| LFO, LFO 2 | RATE: `0.05 × 800^(v/127)` Hz; SYNC: one cycle per note value at the tempo (4BAR … 1/32) | the parameters | exact | `tools/gen_tables.py:56-59`, `voice.c:52-70` |
| LFO, LFO 2 | Restart: TRIG NOTE starts from PHASE at a fresh phrase (a note while no voice is held); TRIG FREE keeps the phase; FADE starts again either way. SYNC + FREE lines up with the bars at PLAY | A note with nothing held; PLAY | — | `voice.c:409-420`, `:461-463`, `seq.c:1241-1243` |
| LFO, LFO 2 | S&H: one value a cycle, from a hash of the cycle number (the graph's own pick, not the sound's) | each cycle | — | `ui_graph.c:94-95` |
| LFO, LFO 2 | FADE: the wave grows from nothing over FADE's time (1 ms … 10 s) after a restart | restart | `TIME_MS_X10` | `ui_graph.c:99-100`, `gen_tables.py:48-49` |
| VOICE 2 | The voices sounding light; the one the next note takes is outlined | voices start and stop | as they change | `graph_voice2` `ui_pgraph.c:481-538`, signature `ui_graph.c:1636` |
| ARP, ARP 2 | The notes held | notes held change | as they change | signature `ui_graph.c:1641` |
| DRIVE, DELAY, REVERB, CHORUS, VOICE | Nothing moves: drawn from the values | value change | at once | `ui_pgraph.c` |
| MENU > ANIM OFF | Rolls off (the other motion, the LFO's dot, is the instrument's state, not decoration) | the setting | — | `ui_draw.c:101` |

## What Jib does with it

- **Rolling digits:** the same rule, frame for frame (9 frames of 15 ms, the same ease table, one frame later per place, the same snap rules). Reduce Motion is ANIM OFF, so the value is shown at once.
- **Hot column:** white for 600 ms after the last turn (on the FM-1 or here), as `hot_t`; while a finger drags a column here it stays white.
- **ENV handles:** the hot point is white for those 600 ms; the handles can also be dragged.
- **LFO:** the same 2 s window, at the real rate. How close it gets is in `lfo.md`.
- **Not drawn yet:** VOICE 2 (Jib doesn't know which voices sound), ARP, MOD, OPS and the engine pages. They keep their columns with no graph.

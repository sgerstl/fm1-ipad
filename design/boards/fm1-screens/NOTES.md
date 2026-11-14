# FM-1 screens: GLO pages, DELAY, REVERB, CHORUS (Skiff 2.5.1)

What the FM-1's own screen draws on these pages, so the phone's pictures can be redrawn to match. Made 2026-11-14.

## What these images are

**Real renders.** Each picture comes from Skiff 2.5.1's own UI drawing code (`firmware/src/ui*.c` at tag `v2.5.1`), run on the Mac through Skiff's own render harness (`tests/ui_render.c` on `tests/ui_test.c`'s stubs). The same code draws the FM-1's screen. Two checks:

- Skiff's own run of that harness, built from the exported tag, matched the tag's `tests/ui_golden.txt` exactly: 3738 pictures hashed, 0 changed.
- My extra parameter settings reuse the harness's scenes and change only `song.g[...]` (and the track's send for FX › DELAY/REVERB). For the default settings, my pictures match the harness's own pixel for pixel, except the battery icon in the header (x 216–236, y 7–17), which depends on which scene ran before. Ignore the battery.

The screen is **240 × 240 colour** (RGB565), not a 128 × 64 OLED. PNGs are scaled 4× (960 × 960) with nearest-neighbour.

skiff-sim wasn't used. It builds against `~/code/skiff-src`'s current checkout, which is Skiff 2.2 plus the screen-link commits, not 2.5.1. Its `screen FILE.ppm` command does dump the screen, but it would show 2.2's pages.

To regenerate: `tools/regenerate.sh` exports tag v2.5.1 to a temporary folder (the skiff-src checkout isn't touched), builds the harness plus `tools/fm1shots.c` (the parameter settings), and writes the PNGs. It doesn't rebuild the contact sheets.

## Files

- `{page}_{letter}_{settings}.png`: one screen at 4×, in the default theme (SKIFF), track 1 selected (orange), no knob just turned.
- `sheet_{page}.png`: every setting of one page side by side, at 2×.
- `themes/{THEME}_{page}_a_….png` and `themes/sheet_themes_{page}.png`: the default setting in all six themes (SKIFF, HI-CON, PAPER, CRYPT, NEON, QUARK).

**Check which theme Scott's FM-1 uses (MENU › THEME).** CRYPT, NEON and QUARK draw these graphs completely differently. CRYPT uses ASCII `# * + :` columns, NEON uses tubes and a synthwave sun, and QUARK draws calorimeter towers with a Monte-Carlo dot fill. If his unit isn't on SKIFF, that alone could explain "doesn't look anything like it". Also note: the colour follows the **selected track** (track 1 is orange, track 2 teal, and so on). It does not stay one fixed colour.

## Where the code lives (Skiff v2.5.1)

- Page table: `firmware/src/params.c:584–588`. The GLO button steps through MIXER (1/5), DELAY (2/5), REVERB (3/5), CHORUS (4/5) and GLOBAL (5/5). FX › DELAY and FX › REVERB are `params.c:550–552`.
- Dispatch: `firmware/src/ui_graph.c:2889–2905` (`graph_delay`, `graph_reverb`, `graph_chorus`, `graph_global`, each drawn from the panel's top). MIXER is `draw_tracks`, `ui_graph.c:2424–2534` (strips from `ui_graph.c:2318`).
- Drawings: `firmware/src/ui_pgraph.c` (lines below).
- Parameter ranges: `params.c:207–238`.
- Colours: `c` is the selected track's colour (`T_TRK(song.sel)`, `ui_graph.c:2745`). `ux_mix(a, b, p)` (`gfx.c:157`) blends from `a` toward `b` by `p`%, so `ux_mix(c, T_SURF, 60)` means 60% of the way to the panel's surface (darker). `T_TEXT` is white, `T_MID` mid grey, `T_DIM` dark grey, `T_LINE` the faint line colour.
- Coordinates: the graph canvas uses the same x as the screen. Canvas y 0 is screen y 76, so canvas y 0–137 is screen y 76–213. The drawable width is x 12–228.
- The pictures are static. They redraw when a value changes; nothing runs on a clock on these pages.

---

## GLO › DELAY (`delay_*.png`)

Cards: TIME, FEEDBACK, COLOR, MIX. MODE (MONO, STEREO, PING) is on the PRESETS encoder, and the foot says "PRESETS: MODE".

Drawn by `graph_delay`, `ui_pgraph.c:21–78`:

- **Beat ticks**: a 2 × 3 px `T_DIM` tick at y 123 for each beat, or each bar when TIME is longer than a beat. The number sits left-aligned on the tick, baseline y 136, in `T_DIM`; every tick is numbered up to 8, otherwise every 4th (`:26–33`).
- **The window**: `tap` = TIME in sixths of a 1/16 (`DLY_6TH`, `:18`), so 1/4 = 24, 1/8 = 12, 1/16 = 6, 8T = 8, 2BAR = 192. The window is `max(tap·4, 96)`, so short times show one bar and long times show four echoes over bars (`:23`).
- **Bars**: up to 9, at `x = 14 + i·tap·208/win`, each `w = clamp(tap·208/win − 3, 2, 13)` px wide (`:35, :41–43`). Square corners, bottoms on y 120.
  - Bar 0 is the **dry hit**: white, full height 100 px.
  - Echo 1 is `MIX·1000/127` tenths tall (× the track's send on FX › DELAY). Each next echo is the last × `FEEDBACK·230/32768` (`:73`). Bars stop below 4 px or past x 228.
  - Echo colour: `ux_mix(c, T_SURF, 15 + 50·(i−1)/6)`. Echo 1 is 15% toward the surface, echo 7 is 65% (`:72`).
- **"DRY"** label, top left (x 14, baseline 16, `T_MID`) (`:75`).
- **MODE card**, top right (`pr_card(228, 3, "MODE", …)`, `:76`): a raised box reading "PRESETS" with a small knob arc, and the mode word (STEREO, PING or MONO) in the track colour.
- **COLOR does not change the picture.** MODE changes only the card's word.

What moves: TIME spaces the bars and changes the beat or bar ruler (b, d, e). MIX sets echo 1's height. FEEDBACK sets how fast the bars fall away (a against b against c).

## GLO › REVERB (`reverb_*.png`)

Cards: TYPE (ROOM, SPRING, HALL), SIZE, DAMP. The fourth card is empty.

Drawn by `graph_reverb`, `ui_pgraph.c:82–147`:

- **Early reflections**: five white bars, 3 px wide, 6 px apart, from x 12, heights 84, 60, 72, 46 and 52 px, bottoms on y 126 (`:84, :117–124`). On FX › REVERB they are scaled by the send.
- **Tail**: one column per pixel, x 44–228 (`:125–140`). Height `h = 84·e` (`e` starts at 1, Q15), and `e` × `k` every pixel, where `k = 1 − 3/len` and `len = 40 + SIZE·144/127`, doubled for HALL (`:86`). Heights are whole pixels, so the end of the tail is a visible **staircase** that runs into the floor.
  - Each column has two bands. The **top** `dim`% of the column is dark: `dim = 20 + DAMP·60/127`, so 20% at DAMP 0 and 80% at DAMP 127 (`:87`). Its colour runs from `ux_mix(c, T_SURF, 55 → 85)` across the tail.
  - The **body** under it is bright: `ux_mix(c, T_SURF, 0 → 60)` across (`:136–137`). It starts as the full track colour at x 44 and darkens to the right.
- **Type label**, top left (x 12, baseline 17, `T_MID`): ROOM, SPRING or HALL.
- **SPRING only**: a 1 px `T_MID` coil, a sine of ±3 px around y 13, x 64–228, at 13/256 of a turn a pixel (`:141–144`).
- HALL: same shape with `len` doubled, so the tail runs off the right edge at large SIZE (d).

What moves: SIZE sets how far the tail reaches (a against b). DAMP sets how much of the tail is the dark top band (b has almost none, d is mostly band). TYPE switches the label, adds the coil, or doubles the length.

## GLO › CHORUS (`chorus_*.png`)

Cards: RATE (Hz), DEPTH, MODE (CHORUS, FLANGER, PHASER), FEEDBACK.

Drawn by `graph_chorus`, `ui_pgraph.c:172–243`, with the response in `pg_cho_resp`, `:152–170`:

- **MODE CHORUS** (a, b, c):
  - A 1 px `T_MID` horizontal at y 74, the dry (`:202`).
  - The copy: a sine around y 74, amplitude `a = DEPTH·44/127` px. Its cycles across the 216 px are `1 + RATE·5/127`, so 1 to 6 (`:174–175`). Drawn as a 3 px line (`cv_line_t … 3`) in the track colour, in 2 px segments (`:231–236`).
  - FEEDBACK above 0 adds a second, fainter sine behind it: 1 px, `T_MID`, phase-shifted by 3/16 of a turn, amplitude `a·FEEDBACK/127` (`:217–229`).
  - Caption "DRY AND ITS DRIFTING COPY", top left, `T_MID`.
- **MODE FLANGER** (d, e): a comb. `|cos|` teeth, `4 + DEPTH·6/127` of them across 216 px; FEEDBACK sharpens and raises them (`:155–161`). The curve is `y = 124 − resp·40`, a 3 px line in the track colour. Each column under it is filled down to y 124 with `ux_mix(c, T_SURF, 75)` (25% colour) (`:190–196`). A `T_LINE` dry line at y 84. Caption "THE DRY AND ITS COPY: A COMB, SWEPT".
- **MODE PHASER** (f, g): two notches, at x 66 and 150 of the 216, width `10 + DEPTH/8`; FEEDBACK adds a peak beside each (`:162–169`). Drawn and filled the same way. Caption "FOUR STAGES: TWO NOTCHES, SWEPT".

What moves: RATE sets the number of waves (a against b against c). DEPTH sets the wave height in CHORUS and the number of teeth in FLANGER (d against e). FEEDBACK adds the ghost wave in CHORUS (b), sharper teeth in FLANGER, and peaks in PHASER (g). MODE switches between the wave and the response picture.

## GLO › GLOBAL (`global_*.png`)

Cards: BPM, SWING+ (0–100%). Two cards empty.

Drawn by `graph_global`, `ui_pgraph.c:431–468`:

- **16 sixteenth-note bars**, 7 px wide, every 13 px from x 14, bottoms on y 120 (`:435–457`). Square corners.
  - Downbeats (every 4th) are 74 px tall and white.
  - 8ths are 52 px in the track colour.
  - Off 16ths are 40 px in `ux_mix(c, T_SURF, 35)`.
- Under each off 16th, a 7 × 3 px `T_DIM` dash at y 125 marks where the off step would be without swing (`:448`). The bar itself moves right by `push = SWING·13/250` px. That is at most 5 px at SWING 100 (c), so the effect is subtle.
- Beat numbers 1–4 in the medium font (`AF_M`), `T_MID`, at x 14 + 52·i, baseline 36 (`:458–462`).
- "SWING 50:50" right-aligned at x 228, baseline 16. The ratio is `50 + SWING·50/250 : 50 − SWING·50/250`, so 60:40 at 50 and 70:30 at 100 (`:463–467`).

## GLO › MIXER (`mixer_*.png`), for reference

GLO's first page. Cards: LEVEL, PAN, REVERB, MUTE of the selected track. The panel shows six strips, 36 px wide and 39 px apart (`ui_graph.c:2318–2423`). Each strip has the track number, sound name, a fader (y 52–101) with a meter beside it, the dB value, and PAN as L/C/R. The selected strip is filled with the track colour. Neither phone app draws the MIXER from PageGraphs, so this is only for comparison with their own Mixer designs.

## FX › DELAY and FX › REVERB (`fxdelay_*.png`, `fxreverb_*.png`)

New in 2.5. These are the track's send on knob 1, then the bus's own settings, drawn with the same `graph_delay` and `graph_reverb`:

- FX › DELAY's echo 1 is `MIX × SEND` (`ui_pgraph.c:25, :73`).
- FX › REVERB's reflections and tail are all scaled by SEND (`:88`). Compare fxreverb_a (send 55%) with b (100%).

## Chorus on Skiff 2.5.1: what it is

Three things share the name:

1. **GLO › CHORUS**, a page of its own on the shared chorus bus: RATE, DEPTH, MODE (CHORUS, FLANGER, PHASER), FEEDBACK. It's the 4th of GLO's five pages. This is the page drawn above. With the delay on STEREO or PING, the bus's CHORUS and FLANGER run in stereo (README 2.5).
2. **Each track's CHORUS send**: knob 2 of FX › FX (`P_CHOR`, `params.c:134, :549`), drawn as one of the four send sliders. There is **no FX › CHORUS page**. 2.5 added FX › DELAY and FX › REVERB only.
3. **An INSERT type**: FX › INSERT's TYPE list includes `CHOR` (`params.c:42`: OFF SOFT HARD FOLD FUZZ CRUSH PHASR FLANG CHOR …). It's a per-track insert drawn by `graph_insert`, separate from the bus.

---

## How the phone's current pictures differ

### iPad (`ios/FM1/PageGraphs.swift`)

The iPad ports the formulas faithfully: the delay's `DLY_6TH`, the reverb's ER heights and `len`/`dim`, `pg_cho_resp`, and the swing push. **The differences are in colour, proportion and finish, not maths.**

1. **Every GLO page is drawn grey, not in the track colour.** `PageGraphs.swift:61` uses `page.scope == 1 ? Theme.textSecondary : Theme.track[...]`, a 2026-11-06 decision. On the FM-1, DELAY, REVERB, CHORUS and GLOBAL draw in the selected track's colour. On REVERB this does the most damage: the FM-1's bright orange body under a dark band becomes grey under a lighter grey, next to white reflections. The two bands and the white reflections lose their contrast, so the picture stops reading as the same thing. **Likely the main cause of "doesn't look anything like it".**
2. **Stretched proportions.** Skiff's 240 × 140 space is stretched to the card (`Space`, `:11–22`; frame height 128 pt, `:140`). Cards sit two to a row in Shape (`Sound.swift:418`), so the drawing is several times wider than tall. The FM-1's panel is about 216 × 137 px, nearly 1.6 : 1. Everything is pulled sideways:
   - the reverb tail flattens into a long low wedge
   - the 3 px reflections become wide slabs
   - the spring coil's waves stretch out
   - chorus waves look shallow.

   I haven't measured the card width on a device, so take "several times" as an estimate from the layout code.
3. **Smooth where the FM-1 is pixel-stepped.** The reverb tail is two gradient polygons (`:602–614`), not 1 px columns with whole-pixel heights, so the FM-1's staircase at the end of the tail is lost. Delay bars have 2 pt rounded corners (`:571`) and GLOBAL bars 1.5 pt (`:1192`); the FM-1's are square.
4. **Fades by opacity, not by blending toward the panel colour.** Delay echoes, the reverb bands and the off-16ths use `.opacity()` (`:570, :613–614, :1191`). This matches the FM-1's `ux_mix` toward `T_SURF` only when the card's background is the FM-1's surface colour.
5. **Small text differences.** Delay beat numbers sit at x+4, baseline 135, `textSecondary` (`:564`); the FM-1 left-aligns them on the tick in `T_DIM`. GLOBAL's beat numbers are 13 pt semibold, close to `AF_M`.
6. **CHORUS**: the line is 2.5 pt (the FM-1's is 3 px, before the stretch). The FLANGER/PHASER fill is `opacity(0.22)` against the FM-1's 25% blend, which is close. Otherwise the same.

### Android (`android/app/.../ui/page/PageGraphs.kt`, worktree `android-p2-shell-02c86f`)

1. **GLO pages have no picture at all.** The Mix sheet's DELAY, REVERB, CHORUS and GLOBAL show dials only (`ui/mix/MixPage.kt:249`: "white because they are shared. No graph."). `GraphKind.Chorus` and `GraphKind.Global` exist (`core/PageGraph.kt`), but `hasPicture` excludes them (`PageGraphs.kt:112–118`), and there is no CHORUS or GLOBAL drawing.
2. **FX › DELAY and FX › REVERB do draw**, in the track colour, ported from the iPad (`PageGraphs.kt:514–557`). They carry the iPad's stretch, rounded corners, opacity fades and gradient tail. Three more differences:
   - FX › DELAY assumes the bus's MIX is 127 (`:694`). The FM-1 uses GLO › DELAY's MIX (default 90, so 71%), which makes Android's first echo about 40% taller than the FM-1's at defaults.
   - FX › DELAY puts the TIME text top right (`:534`) where the FM-1 has the MODE card.
   - Text baselines are 18 and 19 against the FM-1's 16 and 17, and beat numbers sit at x+4, baseline 138.
3. The picture area is 110 dp tall, at the dials' width (420 dp) or full width (`ui/shell/Body.kt:265–266`). The same stretch applies, and it's stronger on a wide phone.

### Suggested starting point for the redraw (my read, not a decision)

1. Draw the GLO graphs in the track colour, as the FM-1 does, or decide deliberately that the app differs.
2. Keep the FM-1's proportions: fix the aspect near 1.6 : 1 rather than stretching to the card.
3. Keep the reverb's two-band column look with square ends.

Points 1 and 2 alone should make REVERB recognisable. First confirm which theme the FM-1 is on.

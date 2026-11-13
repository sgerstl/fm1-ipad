# Android P2: the sound page without pictures (decision 25), 2026-11-13

Built (Kotlin tests pass, APK builds); **not run on a screen**. Nothing here writes the FM-1: no backup needed.

A sound page is: the page row (or the lock banner), a header ("FX · 1 of 6" and the track line), tiles where knob 1 picks from a list of names, the four round dials, and the button block at the bottom. The bus cards on the Mix tab follow the same rule: four dials, no graph; DELAY MODE stays a switch.

| # | Do | See |
|---|----|-----|
| 1 | Press ENV on the FM-1 | Page row, "ENV · 1 of 2", four round dials (value in the ring, label under, the FM-1's own labels and values), the button block. No picture, no panel |
| 2 | Slide a dial; double tap it; turn the FM-1's knob | Slides with the direction setting and the Magnifier; double tap goes back to where the page opened; the ring goes white while turned from the phone or the FM-1 |
| 3 | LFO page: WAVE dial (a short list) | Stays a dial |
| 4 | A long list value (GOSPEL on a WHEEL track) | Fits the ring: shrinks to 13 sp, then cut to what fits |
| 5 | MOD, LANES, SAMPLES, DRUM-X's SOUND | Tiles light the FM-1's pick and send knob 1; at bottom full they have room, at split they do not (see below) |
| 6 | A dense page (EDIT's operators, zones, slices) | The line "Set this page on the FM-1." and four empty wells |
| 7 | Mix tab, Delay, Reverb, Chorus, Global | Four white dials, no graph; DELAY MODE is the switch |

## What the steps get (412 × 915 dp; body about 793 dp; the Pixel 7's 1080 × 2400 is 411 × 914 dp, the same)

| Divider | HOME / editor | A sound page without tiles | A sound page with tiles |
|---|---|---|---|
| Split (bottom half about 420 dp) | rows about 38 dp | rows about **30 dp** (the page row, header and dials take 160 dp) | rows about 29 dp; the tiles get almost nothing (the section is only about 164 dp), so tiles want bottom full |
| Bottom full (about 729 dp) | rows about 74 dp, lane | rows about **84 dp** (348 dp grid); a gap above the dials | rows about 72 dp; tiles about 140 dp |

At split a non-tile page now gives the steps about 2 dp a row over the picture version (the picture was already squeezed to nothing there); the real gain is at bottom full. **Settled (Scott):** on a page with tiles, at split only, the "FX · 1 of 7" header line goes (the underlined page row names the page); the header stays at bottom full and on pages without tiles. The grid on such a page squeezes to 26 dp rows (116 dp), the tiles get about 44 dp (one 36 dp row, the list scrolls; MOD's three rows scroll at 36 dp each). Step numbers in the squeezed rows now sit clear of the length bar (number nudged up 4 dp, bar down to 2 dp from the edge).

Removed: pictures (ENV, LFO, DRIVE, FX, SCALE, ARP, ANALOG, FM6 operator and all-ops, DRUM-X's sheet rows), the dense cards, the picture-handle sliders, the Mix bus graphs. Kept: the page data (`graph`, `values`, `fm6`, `sheet` stay in the schema; P1 may drop them), MOD route tiles, picker tiles, DRUM-X lanes as tiles.

Pre-flight (design-standards) ran: tokens only, one dial component for the HOME knobs, the sound pages and the Mix buses; targets 84 × 88 dp; no new motion; contrast not recomputed; no rendered check.

| 8 | Split, a page with tiles (MOD, LANES) | No header line; one row of tiles shows and scrolls; the steps are rows of about 26 dp, the number clear of the length bar |
| 9 | Split, any step with a note, look at the number and its length bar | They no longer touch |

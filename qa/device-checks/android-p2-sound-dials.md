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

## The page area's new shape (P1, decision 25)

`PageState` now reads P1's shape: `title` (the header: the page's title, or a sheet's own "OPERATOR 4", "ALL OPS", "SOUND SD"), `tiles` (`kind` "routes" for MOD, "pick" for LANES, LANE MIX, SOUND and OPERATOR) and `window` (`index`, `count`, `title`, sheets only). The old `graph` (and `GraphKind`, `PageGraph`, the Fm6 and sheet types) is gone from the phone's side. Built against the fake and the sample JSON; the re-recorded fixtures and the real core have not been run.

| # | Do | See |
|---|----|-----|
| 10 | OPERATOR, ALL OPS, SOUND on the FM-1 | The header is the FM-1's ("OPERATOR 4"), with the window in grey after it ("ENV 1 · 2 of 5") and four dials for the window's controls. OPERATOR shows OP1 to OP6 as tiles; tapping one moves the FM-1's cursor (pickTile) |
| 11 | Turn the FM-1's SELECT on a sheet | The window name in the header follows. The phone has no way to change it (the link's second cursor is read-only) |
| 12 | MOD, LANES, LANE MIX | Tiles from `tiles` (routes, or the eight lane names), the pick lit |

## Decision 27: the FM-1 drives navigation, the phone follows (2026-11-13)

Built (tests pass), not run on a screen. Removed: the scrolling page row and the button block (deleted, no setting). A sound page is now the header, tiles if any, and the four dials, and the header is the only page label, always shown (it is back on tile pages at split; the tiles squeeze instead). Format: family and n/count in grey, then the FM-1's page name in text weight: "FX 1/7 FX", "FX 2/7 DELAY"; a sheet shows its own title ("OPERATOR 4") as the name, then its window. The lock banner takes a line of its own while a step is held.

What the steps get (412 × 915 dp, body about 793 dp; the Pixel 7's 1080 × 2400 is 411 × 914 dp, the same):

| Divider | HOME / editor | A sound page without tiles | A sound page with tiles |
|---|---|---|---|
| Split (bottom half about 420 dp) | rows about **58 dp** (was 38) | rows about **59 dp** (was 30) | rows about 30 dp; the tiles get about 120 dp |
| Bottom full (about 729 dp) | rows about 95 dp, with the lane | rows about 102 dp (the grid's cap) | rows about 72 dp |

Follower bug: a restart on FX opened the Sounds sheet. The follower now takes the first screen it sees after start or a reconnect as a baseline and opens nothing for it, follows only while the link is Ready, and only a screen that stays 300 ms (the link passes through screens while it reads the FM-1). I could not reproduce the exact path (it needs the real link); a test covers the baseline and the reset.

| # | Do | See |
|---|----|-----|
| 13 | Press FX on the FM-1, then FX again | The page follows; the header reads "FX 1/7 FX", then "FX 2/7 DELAY"; no page row; the dials; nothing else at the bottom |
| 14 | Restart the app with the FM-1 on FX (also on SAVE's PRESETS, on GLO) | The app comes up on the editor/sound page the FM-1 is on, with no sheet open and the Mix tab not forced; a later change on the FM-1 follows |
| 15 | MOD at split | The header shows; the tiles scroll in the space left (about 120 dp) |

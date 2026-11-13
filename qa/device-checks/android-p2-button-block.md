# Android P2: the FM-1's button block (board 72, decision 24), 2026-11-13

Built (Kotlin tests pass, APK builds); **not run on a screen**. GLO, SAVE and SEQ need P1's core side (`screenGoto`, name provisional; I've written P1 what is needed); until then the real core ignores them and the phone only opens its own place. Nothing here writes the FM-1's flash: no backup needed.

The block sits at the very bottom of the bottom half, always, on HOME too: **FX SEL ENV LFO EDIT GLO** over **HOME SAVE ARP SEQ PLAY/STOP REC**, Barlow Condensed labels, PLAY/STOP (two lines) and REC in red. The sound page no longer has its own six family keys. From the top: ruler, step grid, the HOME knobs or step controls (or the sound page), the block.

## What fits on a 412 × 915 dp phone (body about 793 dp; the Pixel 7's 1080 × 2400 is 411 × 914 dp, the same)

| Divider | HOME / editor | A sound page (FX) |
|---|---|---|
| Top only | no bottom half; a sound key glides the divider to split | |
| Split (bottom half about 420 dp) | ruler, grid with rows of about 38 dp (number and note on one line), knobs row 122, block 76 | grid squeezed to rows of about 29 dp (128 dp), page row and four controls (about 164 dp), block. **No picture** |
| Bottom full (about 729 dp) | ruler, grid with rows of about 74 dp, the automation lane, knobs row, block | grid at 72 dp rows (300 dp), page row, a picture of about 137 dp, four controls, block |

| # | Do | See |
|---|----|-----|
| 1 | Look at the bottom of the screen on HOME, no step picked | The block, HOME key lit (white, dark label), under the HOME knobs. Idle keys readable; PLAY/STOP and REC red |
| 2 | Press ENV on the FM-1; press ARP | The matching key lights as the FM-1's screen changes; the dials row gives way to the page; the block stays |
| 3 | Tap FX, then FX again | The FX page opens; the second tap steps to the next FX page |
| 4 | Tap HOME on the block; also swipe back | The FM-1 goes HOME, the sound page leaves, the knobs come back |
| 5 | Tap SEQ | The FM-1 goes to SEQ (needs P1) and the editor shows |
| 6 | Tap GLO | The Mix tab opens (FM-1 side needs P1) |
| 7 | Tap SAVE | The Projects sheet opens (FM-1 side needs P1). *Open: it should be the Sounds sheet when the FM-1's SAVE page is PRESETS or USER; that needs the core to say which* |
| 8 | Tap PLAY/STOP and REC | Same as the header's pair; REC fills red while latched |
| 9 | Drag the divider through all three positions | The grid, the dials or the sound page and the block follow; nothing overlaps; at top only the block hides with the bottom half |
| 10 | Press the FM-1's GLO or SAVE | *Open: which key lights depends on what P1's link reports; today SEQ lights (the editor shows)* |

Notes: a block key is 36 dp tall (over the 24 dp floor, under 44); the red words are `rec` (#FF4D4D) on the key face; contrast not computed fresh. Pre-flight (design-standards) ran: tokens only, existing key press and focus states, no new motion. `check-tells.sh` scans web sources only, so that is not a pass; no rendered check.

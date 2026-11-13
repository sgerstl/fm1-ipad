# Android P2: the FM-1's button block (board 72, decision 24), 2026-11-13

Built (Kotlin tests pass, APK builds); **not run on a screen**. P1's core side (`screenGoto` with its optional page, and the `fm1Screen` area, 0e34e33) is merged; the real core path has **not** been run by me. Nothing here writes the FM-1's flash: no backup needed.

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
| 5 | Tap SEQ; tap it again; again | First press: the FM-1 goes to NOTES and the editor shows. Each press steps the key's pages (NOTES, FEEL, PATTERN, AUTOMATION, SONG). AUTOMATION glides the divider to bottom full so the lane shows; SONG opens the Timeline tab |
| 6 | Tap GLO; again | The FM-1 goes to MIXER and the Mix tab opens at that section; each press steps MIXER, DELAY, REVERB, CHORUS, GLOBAL and the Mix tab follows |
| 7 | Tap SAVE; again; again; again | PRESETS and USER open the Sounds browser for the selected track; PATTERNS sends the FM-1 there and the phone shows nothing new (no place yet: open question for Scott); PROJECT opens the Projects sheet |
| 8 | Tap PLAY/STOP and REC | Same as the header's pair; REC fills red while latched |
| 9 | Drag the divider through all three positions | The grid, the dials or the sound page and the block follow; nothing overlaps; at top only the block hides with the bottom half |
| 10 | Press the FM-1's own GLO, SAVE, SEQ or HOME keys, or hold a layer (SCL) | The matching block key lights as the FM-1's screen changes; under a MENU or a held layer the key shown is the link's (none lit while a menu covers the screen) |

Notes: a block key is 36 dp tall (over the 24 dp floor, under 44); the red words are `rec` (#FF4D4D) on the key face; contrast not computed fresh. Pre-flight (design-standards) ran: tokens only, existing key press and focus states, no new motion. `check-tells.sh` scans web sources only, so that is not a pass; no rendered check.

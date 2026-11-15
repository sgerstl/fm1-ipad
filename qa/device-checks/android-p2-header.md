# Android P2: the header restyle (board 71 A with C's tabs, decision 23), 2026-11-13

Built (Kotlin tests pass, APK builds); **not run on a screen**. Nothing here writes the FM-1: no backup needed.

| # | Do | See |
|---|----|-----|
| 1 | Look at the top bar | The project and Loop are words with ⌄ (17 semibold in white; 14 in the grey), no key boxes. Record is a ring with the red dot, Play a ring with the triangle, both round. The readout is as before |
| 2 | Press and hold the project, then Loop | A soft well shows behind the word while pressed. Releasing opens the same menus as before (Projects…, Settings, Labs; Launch at, Cancel waiting) |
| 3 | Tap Record; tap Play | Record fills red with a dark dot and latches; Play fills white with a dark stop square while playing and goes back to a ring on Stop |
| 4 | Tap Timeline, Mix, Pads | Words at 17 semibold, 24 apart, the current one white with a 3 dp white underline its own width that glides to the next word in about 0.2 s. Others in grey. A thin line runs under the row |
| 5 | Settings › accessibility › Remove animations on, then switch tabs | The underline fades out under the old word and in under the new one; nothing travels |
| 6 | Drag the divider to top only and to bottom full | As before; the tabs still fade out at bottom full |
| 7 | TalkBack: swipe through the header | Project and Loop read as buttons with their names; Record is a switch (on/off); Play/Stop a button; each tab reads as a tab, selected for the showing one |
| 8 | Tap the readout, slide tempo | As before |

Pre-flight (design-standards) ran: tokens only (`outline`, `control`, `text`, `text2`, `rec`); header words are 48 dp targets and rounds 48 dp around a 40 dp circle; tab words are 36 dp tall (the row's old height), under the 44 dp touch ideal but over the 24 dp floor; focus rings on words and rounds (2 dp, text on page). Colour pairs are the existing tokens, not newly computed. `check-tells.sh` scans web sources only and found nothing here, so that is not a pass. No rendered check was possible.

Known edges: the hairline spans the content width (8 dp in from each edge), not the full screen. The tab words' left edge is the grid's.

## Readout moves left of Record and Play (decision 23b), 2026-11-13

| # | Do | See |
|---|----|-----|
| 9 | Look at the top bar | Project and Loop at the left; the readout (bar · beat over BPM) to the left of Record; Record then Play at the far right edge, Play outermost. The readout still opens tempo and the Loop · Song · Once menu |

## HOME knobs: long list values

| # | Do | See |
|---|----|-----|
| 10 | WHEEL track with a long value such as GOSPEL | The value shrinks one size at a time to fit the ring (22 down to 13 sp); if it still cannot, it is cut to the letters that fit at 13 sp, as the FM-1 does with its short forms. Never wraps or touches the ring |

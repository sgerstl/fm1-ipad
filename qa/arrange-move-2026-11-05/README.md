# Arrange on Skiff: move, delete, entries used, the hold menu (2026-11-05)

Scott's notes from trying the build on his iPad (demo Skiff), built on the iPad simulator (Look iPad, landscape) with `-demo -demo-skiff -demo-song full -page song`.

| Shot | What it shows |
|---|---|
| 01 | Entries used as 16 squares (left, kept) and as dots (right, tried). Squares match the step cells and a full track reads as one solid block; dots read as page indicators. "Full", and "n left" from 14, say it in words too |
| 02 | Holding T3's A and dragging it past the end: the others close up, a dashed place where it lands, the block under the finger, "Move A (08 ×2) to bar 12 on T3, after a REST ×7: that takes 1 more entry" |
| 03 | The same drag while the demo plays, onto the entry T1 is playing: "Stop to rearrange…" before letting go, and nothing sent |
| 04 | Stopped, T1's F dragged to the front: "Move F (04 ×4) to bar 1 on T1" |
| 05 | After letting go: F is entry A, Undo in the tool row |
| 06 | Hold and let go without moving: Jib's own menu at the finger, 52 pt rows, groups apart, Delete alone at the bottom, "Make unique: all 64 taken" saying why it's off |
| 07 | Delete entry from the inspector, on an entry whose pattern nothing else uses: asks first, as Clear does (taken with the system menu, before it was replaced; the dialog is unchanged) |

## The menu's pulse

Not reproduced. With the system menu open, 26 screenshots over 13 s while the demo played (the held block was the one playing) and 10 stopped: the lifted block, the menu and the backdrop kept the same brightness to 0.1 of 255. The likeliest cause on a real iPad is the system menu's blurred material picking up the white playhead line sweeping behind it, which the simulator's screenshots may not show. Jib's own menu is an opaque surface, and the held block drops its playing mark while it's lifted or its menu is open, so neither can pulse. Worth a look on the iPad.

## Pre-flight (design-standards)

1. Right problem: yes, each item is Scott's own note from the iPad.
2. Grayscale: the squares read by fill against empty; the menu by rows and hairlines; the move by the dashed place and the line.
3. Spacing: menu rows 52 pt, 8 pt between groups (a hairline in it), 16 pt insets; squares 7 pt with 2 pt gaps.
4. Type: 17 pt menu rows, 13 pt menu header, 11 pt semibold "Full", existing ladder; two weights.
5. Tokens: `Theme.stepEmpty` for empty squares, `look.surface(.held)` and `.selected` for the menu, track colours for used squares. No new values.
6. States: menu items disabled with a reason in the row (Make unique); move refused while playing and when full, said before letting go; busy and offline disable the menu and the Delete key; Undo only when there's something to undo.
7. Contrast: "Full" #EDEDF0 on the page about 17:1; used squares in track colours 5.5:1 or better; menu text #EDEDF0 on #3E3E46 about 10:1. Empty squares (#2A2A30) are about 1.4:1 on the page: below 3:1, so the count rests on the filled squares, the words from 14, and the accessibility label, not on the empty ones.
8. Keyboard: ⌥← ⌥→ move the selected block, ⌘Z undoes; the menu takes ↑ ↓, Return and Escape, and closing selects the block again. **Not verified**: the simulator doesn't pass key presses to the app (as before).
9. Targets: menu rows 52 pt, Delete and Undo 44 pt. VoiceOver: blocks keep their actions and gain Move earlier and Move later; the menu is modal with an Escape action, and closing puts VoiceOver focus back on the block. **Not verified** with VoiceOver running. Reduce Motion: no lift scale, no animation.
10. Taste anchor: data-dense tool. Colour stays on meaning (track colours, the squares).
11. Tells: `check-tells.sh` found no web files to scan (SwiftUI), so it isn't a pass. By eye: the menu follows canvas board 2, not a generic popover.
12. Behaviour defaults: Delete is undoable, and asks only when it would erase a pattern (severity-scaled, same as Clear); no actions in toasts.
13. Rendered check: these screenshots, read; `check-render.mjs` is for web pages, so not run.
14. Gold: not compared, no native gold reference for a menu at the finger.

Left standing: the erase dialog anchors to the top of the page, not to the Delete key (SwiftUI's confirmationDialog on the page); Delete isn't red, as red stays REC's (spec: no brand accent, red only for destruction as the primary action). Not checked: iPhone (Arrange is iPad-only), the physical look, a real FM-1, skiff-sim round trips for move (the FakeSkiff tests cover them).

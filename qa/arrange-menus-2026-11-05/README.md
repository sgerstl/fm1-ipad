# Arrange on Skiff: one menu style, a lift that holds, motion (2026-11-05)

Scott's second round of iPad notes, built on the iPad simulator (Look iPad, landscape) with `-demo -demo-skiff -demo-song full -page song`.

| Shot | What it shows |
|---|---|
| 01 | Hold a block and let go: Jib's menu at the finger, 52 pt rows |
| 02 | Set sound… from the inspector, in the same menu: none (ticked, the current choice), then an engine per row |
| 03 | An engine's presets, opened in place with a Back row |
| 04 | A tap after a lane's last block: the add menu, same style |
| 05 | Pick a pattern…: the patterns with their numbers in their track's colour |
| 06 | The inspector: its actions two by two, Delete entry last and apart under them |
| 07 | Holding the one-bar 03 block, which is nearly all REPS grip: it lifts, and its menu opens |
| 08 | A move refused while playing: the block that didn't move is selected, and says why with Stop |
| 09 | T3's A held and dragged past the end, then back (frames ~0.4 s apart): a REST opens behind it, closes again, and A settles where the finger let go |

## What was wrong, and why

- **Hold didn't always lift.** Three causes, all in the code. The REPS grip covers the block's last 28 pt and took the touch from touch-down, so a hold there never lifted, and a block under about 36 pt is all grip. The hold also gave up after 10 pt of drift, when the lane's scroll view took the touch. And a swipe that started on a block didn't scroll the lanes at all: the SwiftUI hold-then-drag gesture blocked the scroll view. Now a block's body uses UIKit's long press, which shares the touch with the scroll view (moving first scrolls, holding still lifts), and the grip runs its own 0.4 s timer, so a hold lifts anywhere on a block.
- **Blocks stayed lifted.** The lift was set when the hold was recognised, but if the scroll view then cancelled the gesture, its end never ran. That left the block lifted and the lanes not scrolling. A cancelled REPS stretch also stayed stretched. Every way out now goes through one reset (`endPress`): the long press reports ended or cancelled, and the grip's `@GestureState` press goes back to nil. A menu on an entry that's gone closes, and leaving the page drops every hold.
- **A drag cut short.** With blocks keyed by what they play (needed for the slide), the dragged block's view was replaced as the lane redrew the preview, and that cancelled its gesture. The lane now keeps its own views and lays each out where the move would put it, so the one under the finger keeps its gesture.

## Motion

The other blocks slide with SLOOP Arrange's own spring (response 0.32, damping 0.86), so the two pages move alike. It settles in about 0.45 s, under the 500 ms ceiling. A REST that fills a gap opens from its left edge with that spring, and closes into it faster (ease-in, 0.16 s). The lift is ease-out, 0.15 s. Reduce Motion: none of it (no slide, no accordion, no lift scale). The block under the finger and a REPS edge drag follow the finger exactly, without animation.

## Pre-flight (design-standards)

1. Right problem: each item is Scott's note from the iPad.
2. Grayscale: menus read by rows, hairlines and chevrons; the inspector by the primary key and Delete apart.
3. Spacing: menu rows 52 pt, 8 pt between groups; inspector keys 8 pt apart, Delete 16 pt below.
4. Type: 17 pt rows, 13 pt menu titles, the existing ladder; two weights.
5. Tokens: `look.surface(.held)` and `.selected` for menus, `Theme.disabledOutline` hairlines, track colours for pattern chips; no new values.
6. States: disabled items say why in the row ("all 64 taken"); the current sound is ticked; busy and offline disable items; refusals said on the block.
7. Contrast: menu text #EDEDF0 on #3E3E46 about 10:1; chips' dark numbers on track colours 6:1 or better; disabled rows #71717A (disabled, exempt).
8. Keyboard: menus take ↑ ↓, → into a submenu, ← back, Return, Escape. **Not verified**: the simulator doesn't pass keys to the app.
9. Targets: rows 52 pt, keys 44 pt. VoiceOver: menus are modal with an Escape action; submenu rows say "Opens a submenu"; the add area is a button with an action. **Not verified** with VoiceOver running.
10. Taste anchor: data-dense tool.
11. Tells: `check-tells.sh` has no SwiftUI files to scan, so it isn't a pass. By eye: board 2's menu, one style across the page.
12. Behaviour defaults: Delete is undoable, and asks only when it would erase a pattern; no actions in toasts.
13. Rendered check: these screenshots, read. `check-render.mjs` is for web pages, so it wasn't run.
14. Gold: not compared.

Left as they are: the erase and Clear unused questions are still SwiftUI confirmation dialogs (alerts, not menus). A menu taller than the space below the finger opens above it, so a submenu taller than its parent can move up. Not checked: the iPhone (Arrange is iPad-only), the physical look, a real FM-1, a real finger's drift and timing (Scott's iPad).

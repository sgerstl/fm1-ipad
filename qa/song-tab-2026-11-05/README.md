# The Song tab: Arrange over the pattern editor (2026-11-05)

Scott: "combining them is the only thing that makes sense… replacing the top portion of the sequence page with the
arrange behavior and then adding that movable divider." Design: canvas boards 19 and 20; the generator is kept in
`design/boards/compose.py`. Skiff only; SLOOP and the iPhone keep their pages.

## What changed

- **Tabs:** Song · Shape · Browse, and the mixer key. On Skiff, anything that asked for Sequence (HOME, SEQ, a tab,
  the FM-1's HOME) lands in Song (`EditorUI.songTab`). The old Sequence page isn't built on Skiff, so its editor
  doesn't run twice.
- **Top: Arrange's lanes, compressed** (`arrangeCompact`, `arrangeLaneHeight`). All of the block behaviour is kept:
  tap, stretch, hold menu, move, the bar-range select, the keyboard. Blocks are one line ("B · 02"); headers are
  the chip and the name. While playing, each track's playing block is bright and outlined, and the others dim to
  half. Arrange's inspector isn't there (the hold menu carries its actions).
- **The divider:** dragged, remembered across launches (`songSplit`, 40 % by default). The song keeps at least
  180 pt and the editor at least 380. VoiceOver adjusts it in 5 % steps.
- **Bottom: the selected track's pattern editor:** the step panel and Whole track on the left, the piano roll (or
  drum grid) with velocity and the motion lanes. The editor's own header goes, since the pattern header names the
  track, and its grid gets the rows.
- **The pattern header:** "Acid · pattern 02 · entry B · also on entry D", **Make unique** (LIST op 2), the
  **pattern picker** on the number (New empty pattern, LIST op 7; the patterns in use, LIST op 1; a count of the
  free ones; Show the pattern pool), and **Following the song** or **Pinned to entry B · Follow**.
- **Follow (the default):** the editor shows each track's pattern as it plays and moves on with it. The track's
  steps are read again as soon as its entry or pattern changes, as well as by the usual resync.
- **Pinning:** a block tapped is selected and pinned.
  - **Stopped:** the track goes to that entry (LIST op 3), so its pattern is the one Skiff edits.
  - **Playing:** that would launch the entry, so the editor dims and says "Entry B's pattern opens when the song
    stops", with Stop and Follow. On STOP it opens.
  - **Follow** drops the pin.
- **The pattern pool:** a drawer at the song area's right edge, from **Patterns** in the tool row or the picker. It
  stays inside the song area, so dragging a pattern into a lane works as on Arrange.

## A limit to know

Skiff's protocol edits a track's loaded pattern (TRACK_STEP). There's no way to read or write a pool pattern that
isn't loaded, so a pinned entry can't be edited while the song plays another one. Hence the "opens when the song
stops" state.

## Questions for Scott

- **The pool drawer:** at a 40 % split it shows two or three patterns at a time (it scrolls). It could instead open
  over the whole page height, over the editor. It would still be a drag source, but over the editor, not beside the
  lanes.

## Checked on the simulator (demo)

`01-following.jpg` (playing: entry A bright and outlined on each lane, the others dim; header following),
`02-pinned-while-playing.jpg` (T1's B · 02 tapped: pinned, "also on entry D", Make unique, the stop notice),
`03-pattern-drawer.jpg`. Not checked: a real FM-1 moving between entries (the demo's tracks stay on their first
entry), the drum grid in the Song tab, the iPhone (unchanged), dragging a pattern from the drawer.

## Pre-flight (design-standards)

1. Framing: Scott's decision and boards.
2. Grayscale: the bright outlined playing block against dimmed ones; the pin and Follow are labelled, not coloured.
3. Spacing: the panels keep their 16 pt; the divider is 16 pt tall with a 56 × 5 handle.
4. Type: block labels 11 pt semibold on the track colour (Theme.onColour on track colours, ≥ 6:1); header 13–15 pt.
5. Tokens: Theme throughout; the green dot is the connection green (0x30D158), as elsewhere.
6. States: following, pinned (loaded), pinned while playing (dimmed, the notice), offline (the picker off), the
   drawer open or shut.
7. Contrast: dimmed blocks at half opacity are decoration of state (the playing one is the information); their text
   stays readable as a whole, and VoiceOver says "playing now".
8. Keyboard: Arrange's keys still work in the top half. Not tested with a hardware keyboard.
9. Targets: picker, Make unique, Follow, Patterns ≥ 36 pt high; the divider's handle area is the full width, 16 pt
   (VoiceOver adjustable). Motion: the drawer slides 0.2 s (none with Reduce Motion).
10. Taste anchor: data-dense tool.
11. Tells: not scanned (Swift).
12. Behaviour defaults: Make unique and the picker act at once and Arrange's Undo covers them.
13. Rendered: iPad sim, one split. Not checked: the extremes of the divider, split view.
14. Gold: boards 19 and 20; difference: the step panel keeps its full inspector (the board shows a summary).

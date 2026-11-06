# Sound panel and Sounds tab, 2026-11-06

Scott's six items for the sound panel (ENV LFO FX SEL EDIT ARP from the right) and the Sounds tab. Checked in the iPad Air 13-inch simulator with `-demo -demo-skiff -demo-stopped`. The simulator runs portrait, so the landscape canvas is letterboxed in these shots; the layout is the same.

## 1. The Song page stays live with the panel open

- **A tap on the page never closes the panel**, on any tab. Move between blocks and patterns, edit steps, scrub the lanes: the panel stays. Closing is the arrow, the same key's HOME, Escape, or another tab.
- **The page makes way instead of being covered** (`song-panel-lfo.jpg`, against `song-closed.jpg`):
  - the lanes narrow (their bars share the narrower width; all 28 still show);
  - the editor's bar narrows to **24 pt steps** (from 50.75), so a whole bar of 16 still shows and pages by bar as before;
  - the page gives up just what that frees, about 428 pt. The panel is 430, so the pattern card meets the panel's edge with no gap, and the tool row's + key touches it.
- **Why 24 pt:** the editor's viewport is exactly one bar wide (`grid.barWidth`), and the step inspector and the 80 pt note-name column are fixed, so the step width is the only thing that can give. Pushing by the full 442 pt (panel plus gap) would make steps 23.1 pt, under WCAG 2.5.8's 24. Rows stay 46 pt tall.
- **The push is instant; only the panel slides** (the 11-06 fix kept): one layout when it opens, no animated re-layout of the lanes or the grid.
- **Where:** all in `SoundPanelHost` (`SoundPanel.swift`). The Song tab was its only host without `makesRoom`, so that mode now means "the host narrows the page and the grid" instead of "a tap catcher over the page". **No Song tab file was touched.**

## 2. Pin is gone

With the page live, Pin had no job. `SoundPanelState` loses `pinned`; `FM1App.swift` had one line that carried it across (edited).

## 3. A lit line over the active page

A 3 pt white line with a glow over the active page name, as wide as the word (the Mixer's `DeviceEdge`). The active page keeps its heavier weight, primary text colour and VoiceOver's selected trait, so the line isn't the only signal (`song-panel-lfo.jpg`, LFO lit).

New: a panel opened with none of its pages focused (the `-sound-panel` launch, or a Shape request redirected to the panel) lights its first page, so a chip is always lit.

## 4. The close button is an arrow

`arrow.right`, the way the panel leaves. Still 44 × 44 pt, Escape, and "Close the LFO pages" to VoiceOver.

## 5. The engine list shows it scrolls

Where the list is cut, its edge fades out over 56 pt (top too, once scrolled). The fade reaches past a row, so the row above the cut starts to go and the cut one shows faintly (`browse-closed.jpg`: Slice fading, User presets below). The scroll bar shows while scrolling and flashes when the list comes up. With nothing past an edge there's no fade. A 32 pt fade was tried first: it hid the cut row entirely and read as empty space.

## 6. No function pads on the Sounds tab (Skiff)

The rail beside the presets has the same keys. The engine list takes the left column's height (`browse-closed.jpg`). The presets keep four columns closed and two with the panel (`browse-panel-env.jpg`). SLOOP's Browse has no rail, so it keeps its pads.

## Mix

Unchanged apart from the arrow and the lit line (`mix-panel-fx.jpg`). It already made its own room.

## Files touched

- `ios/FM1/SoundPanel.swift`: items 1–4.
- `ios/FM1/Library.swift`: item 5.
- `ios/FM1/AppView.swift`: item 6, one line (`if !ui.songTab { FunctionPads(…) }` in the library case).
- `ios/FM1/FM1App.swift`: one line, `SoundPanelState(family:)` without `pinned`.

## Checked

- `swift test` in `ios/SloopKit`: 238 tests passed.
- The screenshots above, in the simulator.
- Design pre-flight ran: 44 pt targets kept (arrow, chips, engine rows); the page and grid at 24 pt steps meet 2.5.8's floor; state not by colour alone (weight and selected trait with the line); motion: the line fades in 150 ms, an opacity change that's fine with Reduce Motion; the panel's slide already falls back to a fade. Tokens: `Theme.text` and the existing `glow`. The tells script found no Swift files to scan (it reads web sources), so it isn't a pass. Taste anchor: data-dense tool.

## Not checked

- **skiff-sim.** The iOS simulator doesn't see the Mac's virtual MIDI port (as earlier QA notes found), so this ran against the demo Skiff.
- **Anything by touch.** I had no tap access to the simulator this round, so: moving between blocks with the panel open, the arrow and Escape closing it, the chip tap moving the line, and scrolling the engine list to watch the top fade appear. All screenshots come from launch arguments.
- **Editing at 24 pt steps:** placing notes and dragging their length grips at that width. Worth a feel on the iPad before keeping it. If it's too tight, the next lever is the step inspector or the note-name column (Song tab files).
- VoiceOver order. (The drum grid fits at 24 pt too: `song-drums-panel-fx.jpg`, T4 with FX open.)

## For Scott, on the FM-1

- The FM-1's ENV…ARP keys with the panel open on the Song tab, then working the lanes and the editor beside it.
- Note entry and length drags at 24 pt steps.
- The panel's open feels the same (instant push, sliding panel) on the iPad Air at 120 Hz.

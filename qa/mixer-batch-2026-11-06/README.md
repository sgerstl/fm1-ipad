# Scott's Mixer batch, 2026-11-06

## A column's tap focuses; no popup

- On Shape, in the sound panel and on the Mixer's cards, **a tap on a column only focuses it**: its page becomes the active one, and with the screen link the FM-1 goes there. A horizontal slide still turns it, and a double-tap still puts the default back.
- The big control (arc or slider) no longer opens from a column. **Developer › Knob tap is gone.** The dial knobs that still open the big control (the track popover's SWING, LEVEL, STEPS, PAN) use the arc.
- A column of named choices (WAVE, CHORD…) also changes by sliding now; before, a tap opened its list.
- My view on the popover: keep its tap. Those are dials, not columns, and have no slide. A tap that only focused would leave them adjustable by hold-and-drag alone, which is harder to find. Scott's call.

## Disabled function buttons do nothing

- A button with no pages for the selected track's engine is disabled: DRUM and DRUM-X have no SEL or ENV, FM6 no ENV, and the same for whatever else Skiff's page_visible hides. Its rail key and its pads show it: flat (no raised edge) and dimmed, with "No ENV pages on DRUM" for VoiceOver (`rail-disabled-on-drum.jpg`). **Pressing it does nothing**: no empty panel, no message.
- **The same button pressed on the FM-1 does nothing in Lupe either**, on any tab: no panel, no jump to Shape. The FM-1 shows what it shows.
- A panel open on a button the newly selected track has no pages for closes, rather than showing empty.
- SLOOP's drum track keeps its DrumNoPages explanation.

## Page dots under the carousel

One dot a card, the current one white and the others grey (track-neutral). They follow the swipe, and a tap on one brings its card in. Each dot is 8 pt with a 28 pt target, and VoiceOver reads "Chorus, card 3 of 4" (`panel-and-dots.jpg`).

## Frames: the panel opening and the carousel

Measured with the body counter (`-count-bodies`); the simulator can't measure frame drops. **Instruments on Scott's iPad Air M3 (120 Hz) is still needed** for frame numbers.

- **The carousel hitch: per swipe, before 6 card rebuilds and 7 graph redraws, after 1 card and 1–2 graphs.**
  - Cause 1: every Shape card read the FM-1's screen state and the focused page in its own body. So each page change, which the carousel sends as a card passes the middle, rebuilt every card's columns and redrew its graph, mid-snap.
  - Fix: those reads moved into small views of their own: the header (LED, "On the FM-1" badge), a merged card's row keys, and the lit edge and lift (`CardForward`). A page change redraws only those.
  - Cause 2: the carousel committed the section and sent the FM-1 to it while still scrolling. Now it waits for the scroll to settle (`onScrollPhaseChange`), so the page change lands after the snap.
- **The panel opening:**
  - The push used to animate the Mixer's layout: every strip and every card re-laid out on each frame of the slide, and each graph canvas redrew as its size changed. Now the push lands at once, in one layout, and **only the panel slides**.
  - The panel's graphs draw **250 ms after it opens**, their wells holding the space, so building them doesn't compete with the slide.
  - Opening it is now one pass: the panel's five cards built once, the Mixer re-laid out once.
- **The Song tab** shares the same panel and cards, so it gets the same fixes. Its page doesn't take the push, so it had no per-frame re-layout.
- Not checked: frame timings on a device, and the 120 Hz feel.

## The sound panel on Browse

- **Opening it:** the rail, the FM-1's ENV to ARP, or Browse's own pads bring in the same `SoundPanelHost` for the selected track.
- **It pushes the browse area:** four columns of presets become **two** while it's open, back to four when it closes (`browse-closed.jpg`, `browse-with-panel.jpg`). The push is instant and the panel slides, as on the Mixer.
- **Same rules as the Mixer:** disabled buttons stay disabled; repeat presses step pages with the card coming forward; ✕, HOME, Escape or another tab closes it. A tap on the presets loads a preset, as ever, and doesn't close the panel.
- The function buttons now behave the same on Song, Mixer and Browse. On Shape they keep jumping to sections.
- SLOOP's Browse is unchanged.

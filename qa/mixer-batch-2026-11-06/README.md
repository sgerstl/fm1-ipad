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

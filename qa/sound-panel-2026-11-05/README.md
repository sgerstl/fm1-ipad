# The sound panel on the Song tab, 2026-11-05

Scott's decision: **keep the Shape tab**, where the FM-1's buttons keep jumping to their sections. **On the Song tab**, ENV, LFO, FX, SEL, EDIT and ARP bring in a sound panel from the right for the selected track. The design is canvas boards 21 (the rail) and 22 (the panel open on LFO). The generator is copied into `design/boards/panel.py`.

## What's built

- **The rail:** the six buttons down the right edge, 56 pt wide, 48 pt keys, like the FM-1's keys. The open one is lit (the selected-key style), and a button with no pages for this track's engine is dimmed.
- **The panel:** 430 pt, level 3 (`.held` surface and shadow), over the song and the pattern, to the left of the rail. From the top:
  - the button and the track ("T1 Acid · 3 pages"), Pin, ✕;
  - the track's sound with **Sounds ▾**;
  - the button's Shape cards in one column: `ShapeSection`, the Shape tab's own section view, not a fork.
- **Opening and closing:**
  - a rail key, or that button on the FM-1 while the Song tab is up (the tab stays put), opens the panel;
  - another button switches it;
  - the same rail key again, HOME, ✕, Escape or a tap outside closes it;
  - **Pin** keeps it open through taps outside;
  - another tab closes it;
  - a press on the FM-1 never closes it: there, the same button steps through its pages.
- **Linked:** a rail key opens the button's first page on the FM-1 too, as the pads do. The panel's cards follow the FM-1's cursor (MOD's route, the lanes, …) and light the knob just turned.
- **Room for the rail:** the Song tab narrows its grid's step (55 to about 50.75 pt) so a bar still fits beside the rail. The arrange tool row's loop-apart warning shortens first when the row is tight.
- **Reusable:** `SoundPanelHost { page }` puts the rail beside any page and the panel over it, ready for the Mixer tab once its redesign branch (`mixer-tab`) merges. The Mixer tab's files weren't touched. The FM-1's buttons are intercepted where AppView calls SkiffNavigator, not in it.

## Checked (simulator, `-demo -demo-skiff -demo-link -page song`)

- The rail closed (`rail-closed.jpg`): the song and a full bar of the pattern fit beside it.
- `-sound-panel LFO` (`open-lfo-first-try.jpg`, taken before the narrowing): the panel's layout. In that first take the page under it still overflowed, fixed since.
- A tap on LFO opens it, with the linked fake following to LFO ("On the FM-1 · 1/3"), and a tap on the song closes it (`tap-open-then-outside.jpg`).

## Not checked

- The FM-1's own ENV to ARP presses opening the panel against the linked fake or skiff-sim. It's the same press path as the rail, reached from the screen pushes.
- Pin in use, and the panel on every engine (an engine without the button's pages says so).
- VoiceOver order, and the rail at the iPhone's size (the phone has no Song tab).
- **Sounds ▾** opens the existing presets panel over the page. A browser inside the panel, as the board shows, would mean a narrow version of PresetsPanel. SAVE › PRESETS still lands on Browse.

## Design pre-flight

Ran it. The rail keys are 48 × 44 pt, Pin and ✕ are 44 pt, and Sounds is 44 pt tall. The panel uses the existing components: selected and raised keys, the level-3 surface, Shape's cards. The type ladder is 20/15/13/12. Motion is 200 ms ease-out from the trailing edge, an opacity fade with reduced motion. Taste anchor: the data-dense tool. The panel is one column of the same cards Shape shows two to a row.

**For the polish pass:**
- The panel covers the right side of the pattern grid and the header's "Following the song" key.
- The narrower step changes the Song tab's grid even while the panel is closed.
- Sounds isn't inside the panel yet.

## On the Mixer tab (after the Mixer redesign merged)

Merged `refs/heads/claude/mixer-tab-8e519e` (dfccaf1) on Scott's "Yes, merge it", with no conflicts. Its hook is `soundPanelRoom`, the width the strips and cards make way by. The Mixer tab now sits in `SoundPanelHost(makesRoom: true)`:
- the same rail;
- the FM-1's ENV to ARP while the Mixer is up;
- the Mixer's own pads (lit for the open button).

All three bring in the panel for the selected track (a strip's name selects it), and the page makes way rather than being covered. Nothing is covered, so a tap on the Mixer is the Mixer's own (a fader). It doesn't close the panel; ✕, the same key, HOME or another tab do. GLO still lands on the Mixer and steps its sections.

At that width the strips' labels used to wrap a letter at a time: MUTE, the section names, the faders' values. They stay on one line now, and the label gives way first ("REV…"); see `mixer-closed-and-fx.jpg`.

Checked: the full package suite (219 tests); the simulator, Mixer closed and with `-sound-panel FX`. Not checked: GLO's stepping against the linked fake with the panel open; the FM-1's buttons on the Mixer against skiff-sim.

**For the polish pass:** with the panel open, the six strips are about 64 pt wide each. The names show only the chip and the REVERB label shortens to "REV…". An overlay over the cards, instead of making way, is the other choice.

# Android P2: back goes home, the sound-page stack, picture handles (2026-11-13)

Built (Kotlin tests pass, APK builds); **not run on a screen**. Decisions 19, 20, 22 in `phone-skiff-decisions-2026-11-12.md`. The `goHome` intent is mine until P1's merge (the fake answers it by switching back to the steps); the real FM-1 needs P1's SCREEN_GOTO 127 side. Nothing here writes the FM-1's flash: no backup needed.

## Back gesture (19)

| # | Do | See |
|---|----|-----|
| 1 | Press an FM-1 sound key (ENV). Swipe back from the left edge, then the right edge | The FM-1 goes HOME and the steps come back, both times. Predictive back shows the preview first |
| 2 | On the steps (no sound page), swipe back | The app leaves as usual: the handler is only on while a sound page shows |
| 3 | On a sound page with Slide-to-turn on Sideways, slide a knob to the screen's edge | Known cost: the edge is not excluded from back there, so a slide that ends past the edge can go home. Tell me if it happens in daily use |
| 4 | Open the Sounds browser from a sound page, swipe back | The browser closes (not HOME) |

## The stack, two positions (decision 20b): Settings › Labs › Sound pages push up from below

Off by default; off is today's layout, unchanged. Replaces the free scroll Scott tried. Built, not run on a screen.

**Up** is the page as it is (top half, divider, step grid, step settings strip). **Down** is the sound section (family keys, page row, sound page, the height of today's bottom half) risen until it sits directly under the step grid's bottom edge, with the strip behind it. The page behind moves up by about 313 dp on a Pixel 10 Pro (S minus the strip and its gap), which leaves the **bottom ~45 dp of the top half** in view: the scenes row (Store, 1–7, Select) and the divider band under it, then the ruler and the grid. The sound page's controls end at the bottom of the screen. At bottom full the automation lane makes the grid shorter and the shift smaller by the same amount.

| # | Do | See |
|---|----|-----|
| 5 | Switch it on. Press ENV on the FM-1 | One spring move (about 0.3 s): the sound section rises under the grid, the strip leaves, the top half goes up with only its bottom 45 dp showing. Nothing stops in between |
| 6 | Swipe down on a gap in the grid, the ruler or the family row | The section goes back down (the FM-1 goes HOME too) with one spring |
| 7 | Slide a knob up and down, or a graph handle, in either position | It turns the control; the page does not flip |
| 8 | From the steps with no sound page open, swipe up on a gap | If a sound page was open earlier this session, it comes back (the phone sends that family's key); if none was, nothing happens |
| 9 | Press other sound keys, or the page row | The section stays down |
| 10 | Switch it off | Today's layout, the sound page in the divider's bottom half |
| 10b | Remove animations on | The two positions swap with no travel |

### What stays selected (decision for Scott: "what's selected and when")

Handled:
- The grid stays under the sound page, so **a picked step stays picked** while you are down and when you come back up; the strip is that step's controls again on return. With no step picked you get the HOME knobs again.
- This is the one place the stack differs from today: without the stack, a sound page clears the pick and the knobs come back.
- Pad selection, track and pattern are untouched by flipping.
- A swipe over a step cell is not a hold: the lock gesture ignores a touch something else took.

Open:
- Whether coming up should always clear the pick (knobs back) instead of keeping it.
- A latched Lock stays latched while down (the strip is hidden); the lock banner still shows in the ruler.
- A pattern change while down.
- The FM-1 selecting a different step while down: the grid ring follows what you picked on the phone, not the FM-1's cursor.
- Swipe-up with no earlier sound page does nothing; a hint may be wanted.
- The top-half sliver is touchable (pads' scenes row); it may want to be inert.

## Picture handles (22)

On ENV, the FX sends page, and EDIT 1's picture (ANALOG engine).

| # | Do | See |
|---|----|-----|
| 11 | ENV: slide each of the four handles (attack peak, decay corner, a sustain handle on the held line, release end) | Each turns the control of that name below it, with the same direction, step and Magnifier as the knob. The old drag-to-position is gone |
| 12 | Double tap a handle | Back to where the page opened, as the knob |
| 13 | FX sends: slide a bar | That send's control turns; the bar follows |
| 14 | EDIT 1: slide the cutoff line's handle and the peak's handle | CUTOFF and RES turn |
| 15 | Turn TalkBack on and swipe through a handle | It reads as the control (name, value, increase and decrease) |
| 16 | LFO, DRIVE, ARP, SCALE pictures | Still decoration: no handle |

Known edges: handles are 44 dp targets (the 48 dp knobs below are the roomier way in); two handles can sit close on a very short decay.

## Pause and Pin only hold against the FM-1 (2026-11-13)

Built (tests in `FollowModelTest`), not run on a screen.

| # | Do | See |
|---|----|-----|
| 17 | Labs › Pause following on. Tap SEL, then FX on the phone's family row | Each page shows at once; no "held here" line, however fast you tap |
| 18 | Same, tap a page in the page row, a MOD route, a tile, then swipe back | All apply at once |
| 19 | Pause on: touch the bottom half, then press SEL on the FM-1 within 3 s | The page stays; a grey line "The FM-1 is on SEL · held here" fades in under the page row, never over the family keys; after 3 s the page catches up and the line fades |
| 20 | Pin on: press ENV, then LFO on the FM-1 | Held with the line. Tapping a family key on the phone still switches |

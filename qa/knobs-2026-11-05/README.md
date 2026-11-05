# Knobs: drag straight on, a big control on a tap (2026-11-05)

For every knob (Shape, the track panel, the step's velocity), from Scott's notes:

- **Drag straight on the knob, no hold first:** up raises, down lowers, the whole range in about 200 pt. The further the finger has gone sideways, the finer the turn: 60 pt aside halves it. Shot 04: DELAY dragged up, 35% to 70%.
- **Tap:** a big control at the finger, in Jib's own menu style (level 3, one shadow on its shape). **Developer › Knob tap** picks it:
  - **Arc** (01): about 200 pt, its dot dragged anywhere round it, the value in the middle.
  - **Slider** (02): the value large, a wide track under it.
  Both have "Back to the default" when the value isn't the default, and a number field where the value is a plain number (a value shown as %, ms or a name has none, so a raw number can't be confused with what's shown).
- **Enum parameters** (DESC's named choices: waveforms, types, modes) open a list (03), the current one ticked; picking closes it.
- **Double-tap** puts the parameter's default back (DESC's default; the track panel's SWING 0, STEPS 16, PAN 0, LEVEL from DESC).
- **Haptics:** a light tick at either end, and at the centre of a knob centred on zero.
- **VoiceOver:** every knob is adjustable (swipe up and down), with actions Open and Reset to default; the big control is modal with an Escape action, its dial or slider adjustable.
- **Reduce Motion:** nothing animates.

## What changed along the way

- The press-hold-then-trace grown ring is gone, and so is the − / + popover.
- On the iPad's Shape, an inactive page used to have a clear overlay that took the first tap (to make the page active, after a tap meant for the page kept opening a knob, 2026-11-03). It also blocked a direct drag, so it's gone. Touching a knob now makes its page active (on the FM-1 too when linked), and the knob works at once. A tap elsewhere on a page still makes it active. The phone's Shape keeps its overlay on pages peeking in at the sides: a tap there brings the page to the middle.
- In Shape's scroll view a plain tap never reached the drag gesture's end, so the taps are SwiftUI's own (double-tap, then a single tap), with the drag running alongside.

## Pre-flight (design-standards)

- Targets: knobs keep their size, the arc's dot 26 pt on a 210 pt dial, the slider's thumb 28 pt on a 44 pt-high track, keys 44 pt.
- One shadow per panel, on its shape. Tokens only (`look.surface(.held)`, `Theme.well`, the knob colours).
- **Known limit:** a quick vertical flick that starts on a knob can be taken by Shape's scroll view as a scroll, as any vertical drag in a scroll view can. A drag that starts gently turns the knob (simulator: the quick swipe scrolled, the slow drag turned). Worth feeling on the iPad.
- Not checked: the haptics (the simulator has none), VoiceOver running, the phone, a real FM-1.

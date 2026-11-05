# The whole-track controls as a popover, 2026-11-05

SWING, LEVEL, STEPS and PAN have left the foot of the Song tab's inspector. The selected track's lane header now ends in a key (sliders icon, 44 pt wide, as tall as the lane). The key opens a small popover beneath it:

- the menus' surface and shadow (MenuPanel's);
- the track chip and name;
- the four white knobs (KnobRow: hold to drag, tap for the big control with Done and Cancel);
- "Swing sets every track."

**Closing:** a tap anywhere else, Escape, another track selected, or another tab. **SEQ pressed twice** (PATTERN, on the FM-1 or its pad) opens it, where it used to flash the panel. The inspector gets the freed height. The popover is drawn under the knobs' big control, so that control opens over it.

Checked: the app builds; `-demo -demo-skiff -demo-link -page song`, closed (`closed.jpg`) and open (`open.jpg`, after a tap on the key).

Not checked: SEQ twice against the linked fake; a drag on a knob inside the popover (the KnobRow is the same component as before); VoiceOver focus moving into the popover (it's marked modal, but focus isn't moved there on opening).

Design pre-flight: ran. The key uses the selected-key colours (white when open), the target is 44 × the lane height, and the surface, knobs and type all come from existing components. There's no motion: it appears at 0 ms, as Jib's menus do.

**For the polish pass:**
- The popover is wider than the header column, so it can't line up with the key's right edge. It's held 12 pt from the window's left edge instead and runs under the first lanes. Lining up as asked would mean anchoring it to the key's left edge or making the popover narrower; it's Scott's call.
- On a 28 pt lane the key's face is 28 pt tall. It's narrow next to the name, and long names lose width to it.
- VoiceOver doesn't announce the popover when it opens.

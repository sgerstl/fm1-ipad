# The mixer panel and the FM-1's buttons (2026-11-05)

Contract: vault `Projects/Dev/fm1-ipad/skiff-arrange-spec.md`, "Lupe and the FM-1's buttons". Skiff only (the screen
link for following; the panel itself on any Skiff). SLOOP keeps its GLO and SEQ sections in Shape.

## What changed

- **No fifth tab: GLO is a mixer panel.** A bottom sheet, 45 % of the window (380 pt at least), level 1 (the panel
  surface and its shadow), sliding up over the page (a fade with Reduce Motion). Opened by the mixer key beside the
  tempo, by GLO on the left pads (again: the next tab, as GLO steps the FM-1's pages), or by GLO on the FM-1. Closed
  by its ✕, Escape, or any other button (the pads' or the FM-1's).
- **Tabs:** Mixer, Delay, Reverb, Chorus, Global. Mixer: six strips (Skiff's `mix_strip`): the number in the track's
  colour and the sound's first word, LEVEL as a fader with its dB under it (OFF at 0, Skiff's `(v − 112) / 2`), PAN
  (C, L, R as `pan_txt`), the REVERB send, MUTE; the selected track's strip tinted. Every track's REVERB is read when
  the tab opens and every 3 s while it's up (`readEveryTrack`, TRACK_PARAM: no push for another track's
  parameters). The other tabs: the page's columns over its graph (DELAY, REVERB, CHORUS as before; GLOBAL ported
  from `graph_global`).
- **GLO and SEQ leave Shape** on Skiff: Shape is ENV, LFO, FX, SEL, EDIT, ARP.
- **The button map** (`SkiffButtonMap`, SloopKit): the FM-1's page → where Jib lands, and back.

  | FM-1 | Jib |
  |---|---|
  | ENV LFO FX SCL EDIT ARP pages (0–29, 39, 40) | Shape, that section; the page's row focused (merged cards) |
  | SCL held | Shape, SEL |
  | GLO: MIXER DELAY REVERB CHORUS GLOBAL (30–34) | the mixer panel on that tab |
  | SEQ: NOTES, FEEL (41, 42) | Sequence, the step panel lit for a moment |
  | SEQ: PATTERN (43) | Sequence, the whole-track panel lit |
  | SEQ: AUTOMATION (44) | Sequence, the grid lit (the motion marks are over its steps) |
  | SEQ: SONG (45) | Arrange |
  | SAVE: PRESETS, USER (35, 36) | Browse |
  | SAVE: PATTERNS (37) | Arrange, the pattern bin lit |
  | SAVE: PROJECT (38) | the Projects sheet where the firmware has projects; Skiff 2.2 has none, so nothing |
  | HOME | Sequence |
  | a MENU, another layer held | stays |

  Back: a tab or pad here sends SCREEN_GOTO to the page it maps to (as before for the tabs), the panel's tabs too;
  closing the panel sends the FM-1 back to what Jib shows. On stock Skiff nothing follows either way.
- **The SEQ pad** (Skiff): Sequence and NOTES; pressed again, PATTERN with the whole-track panel lit.
- **`-demo-link`** gives the demo the screen link, so the map can be seen without an FM-1.

## Tests

- `SkiffButtonMapTests`: every page against the table, and each place back to its page.
- `theButtonMapBothWaysOnTheFake`: GLO pressed five times on the fake steps through the panel's tabs; SEQ to
  PATTERN; four places sent from Jib land on the fake and map back.
- `theButtonMapOnTheRealFirmware` (patched skiff-sim, `SKIFF_SIM=1 SKIFF_LINK=1`): SCREEN_GOTO to each page the map
  uses, from ENV to SONG and HOME; each screen comes back on that page and maps to the place. Passed.

## Compared with skiff-sim

`skiff-sim-mixer-global.png` against `jib-global.jpg`: GLOBAL the same (16 steps, beats white and numbered, the off
steps on their marks at SWING+ 0, "SWING 50:50"). The mixer strips: the same names (ACID PAD PULSE DRUM PIANO DRUM),
−4 dB and C on each. Differences on purpose: Jib's faders are in each track's colour (Scott: "in track colours"),
Skiff's white; Jib puts PAN, REV and MUTE on every strip, where Skiff's MIXER shows them for the selected track in
its cards. `jib-mixer-first-try-too-wide.jpg` is the first render, 48 pt wider than the window (fixed).

## Not done

- The quick mutes on the track box and the Arrange lanes (later, as asked).
- The iPhone: no mixer panel there yet, and GLO on the FM-1 doesn't open anything on the phone.
- Jib doesn't know which page the FM-1's GLO will open next when the panel was opened here; it goes by the screen.

## Pre-flight (design-standards)

1. Framing: Scott's decision, in the spec.
2. Grayscale: the selected tab's surface, the white fader caps and the ✕ carry it; the track colours identify strips.
3. Spacing: 16 pt panel padding, 12 pt between header and content, 8 pt between strips.
4. Type: 15 pt tabs (semibold selected), 13 pt strip names and keys, 15 pt dB; two weights.
5. Tokens: Theme and the Look's panel surface and shadow; no new values.
6. States: tabs selected / not; MUTE on / off (white when muted); a muted strip's fader dim; LEVEL 0 says OFF;
   no-page tabs say so ("This firmware has no … page").
7. Contrast (dark): tab labels 0xA1A1AA on the recessed well ≈ 7:1; MUTE text 0x101012 on 0xEDEDF0; dB 0xEDEDF0.
8. Keyboard: Escape closes (cancelAction on ✕). Tab order not tested.
9. Targets: tabs, ✕, MUTE and strip headers 44 pt high. VoiceOver: the panel is a container named "Mixer, <tab>",
   MUTE is a toggle with its value, the fader is adjustable with its dB. Not tested with VoiceOver. Motion: 0.25 s
   slide (a fade with Reduce Motion); the flash rings fade in 0.3 s (none with Reduce Motion).
10. Taste anchor: data-dense tool.
11. Tells: not scanned (Swift). Eyeball: a mixer reads as Skiff's own strips.
12. Behaviour defaults: no destructive actions; closing is never a loss.
13. Rendered: iPad sim, one size, the panel on Sequence. Not checked: over Shape and Arrange, split view, iPhone.
14. Gold: Skiff's screens, compared above.

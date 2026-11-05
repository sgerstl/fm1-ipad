# Tempo from the top bar (2026-11-05)

Tap the BPM readout (iPad top bar or phone bar): a panel opens under it in Jib's own menu style (level 3).
It holds the BPM large between − and + (±1; held: repeats after 0.4 s, every 0.15 s, every 0.05 s after 1.5 s), Tap tempo (the average of the last four intervals, starting over after 2 s without a tap), and a number typed in with its range. A tap outside or Escape closes it.

| Shot | What it shows |
|---|---|
| 01 | The panel, on the demo Skiff |
| 02 | + held from 120 to 130; 300 typed and Set: "300 is outside 40–240 BPM" |

## Found in the firmware sources

- **Range:** from BPM's DESC. 40–240 on both firmwares (SLOOP `params.c` `PD("BPM", F_BPM, 40, 240, 90)`; Skiff's DESC from skiff-sim). Not hard-coded.
- **The id:** BPM's DESC label on Skiff (global 0), as the driver already found it. SLOOP's `Global.bpm` (0).
- **BPM LOCK** (Skiff MENU setting id 8; not a global) only makes the FM-1's SELECT knob need GLO held to set the tempo (`ui_input.c` 2500, `ui_layer.c` 1419). The editor's SET isn't touched, so it doesn't block this. It isn't a "projects don't load their BPM" setting.
- **Following another clock:** SLOOP's global SYNC and Skiff's global CLOCK, each INT / USB / TRS, found by DESC label and values (Skiff's SYNC is an empty slot, so it isn't mistaken for it). With USB or TRS, everything in the panel is off, and it says: "Following USB clock: the tempo comes from the other device. Set CLOCK to INT on the FM-1 to set it here." The panel re-reads both values when it opens.
- **Playing:** a change goes out like any other global, writes coalesced while + is held. The counted playhead shifts the moment Jib sends it (`tempoChanged`, the same path the knob page used). On skiff-sim `--truth` (BPM 137 to 90 mid-play): 642 of 642 steps exact before, 815 of 840 (97 %) after. The misses are one track a step off from the change on, the model's known limit: Jib times the change only to a few ms.

## Pre-flight (design-standards)

- One primary-sized number (44 pt semibold), the rest on the ladder; two weights.
- Targets: − and + 52 pt, Tap tempo 52 pt high, field and Set 44 pt.
- States: − and + off at the range's ends; everything off on another clock, with the reason in words. A typed number is checked on Set and said wrong inline ("300 is outside 40–240 BPM", "Type a whole number…").
- Keyboard: ↑ ↓ ±1, Escape closes, Return in the field sets. **Not verified:** the simulator doesn't pass keys.
- VoiceOver: the number is adjustable (swipe up and down), − and + are buttons, the panel is modal with an Escape action. **Not verified** with VoiceOver running.
- Tokens: `look.surface(.held)`, `Theme.well`, the chiclets. Nothing new.
- Change: the readout used to open Arrange in SLOOP's song mode. It opens the tempo now (Arrange is a tab away).
- Left as it is: on iPad, the system's floating number pad sits over the panel, and a tap outside it (Set included) first puts it away.
- Not checked: the following-another-clock state on screen (covered by a test, not seen), the phone's panel, a real FM-1.

# The Mixer tab, redesigned, 2026-11-05

Scott wanted simpler faders than the knobs' hold-then-drag, the shared cards side by side in a carousel like the phone's Shape page, and room for the sound panel. Checked on Skiff in the iPad Air 13-inch simulator with `-demo -demo-skiff -demo-link -page mixer` (1366 × 1024), and against skiff-sim.

| | |
|---|---|
| `rest.jpg` | The tab at rest: six strips over the shared cards, the Mixer section lit in the GLO row |
| `drag.jpg` | Track 2's level fader held at -27 dB, its readout inverted |
| `sel.jpg` | Track 3 selected by its name; the Reverb card in the middle, "On the FM-1 · 3/5" |
| `global.jpg` | The last card, Global (5/5); track 1's PAN dragged to R66 |
| `skiff-sim-glo-pages.png` | Skiff's own MIXER DELAY REVERB CHORUS GLOBAL screens from skiff-sim, to compare the graphs |

## What changed

- **The page doesn't scroll.** The strips fill the top and the cards sit below, so a fader never has to wait to find out whether a touch is a scroll.
- **Sticky faders** (`Faders.swift`): LEVEL runs up and down; PAN and the REVERB send run across. A fader takes the finger as soon as it touches and follows it one point for one point, starting from wherever the finger lands. Touch the cap and it stays under your finger. Touch the track and the value moves from where it was, without jumping.
  - **A tap nudges** one step toward the side you tapped (1 dB on LEVEL). I chose a nudge over a jump because a stray touch that jumps a fader is a loud surprise while the FM-1 plays. The nudge is safe and fine-grained, and a double-tap does the big move.
  - **A double-tap** puts the default back (0 dB at Skiff's default, centre for PAN, the DESC default for the send).
  - **Light haptic ticks** at the default and at both ends.
  - **While held,** the value reads out inverted. A short line on the track marks 0 dB (or centre).
- **MUTE** is a toggle chiclet: down, with a lit dot, means muted. A muted strip's fader goes grey.
- **Track selection:** tap a strip's chip or name to select the track, as on the Song tab's lane headers. The chip fills and gets a ring, and the strip takes a tint of the track's colour.
- **Shared cards in a carousel,** using PhoneShape's paging and its values: view-aligned snapping, neighbours at 0.92 scale, a 0.4 s spring at 0.82 damping (none with Reduce Motion). A tap on a neighbour brings it to the middle. The card in the middle is the Mixer's section. Linked, the FM-1 shows its page, and GLO (on the FM-1 or its pad) brings the next card in.
- **GLO's order:** a row on the MIXER header, Mixer · Delay · Reverb · Chorus · Global, lights the current section, and a tap goes there. The cards' "On the FM-1" badge now counts as Skiff's screen does (Delay 2/5 … Global 5/5); it said 1/4 … 4/4 before.
- **The sound panel's hook:** `soundPanelRoom`, an environment value in `MixerPanel.swift`. Whoever shows the panel over the Mixer tab sets it to the panel's width, and the strips and cards move out of the way. Nothing on the tab sits on the right edge or takes a swipe from it. The panel itself isn't built here.

## Checked

- Drag, tap-nudge, PAN from its label row, MUTE, selection, carousel swipe and snap, the section row, GLO pad stepping Mixer → Delay → Reverb: all in the simulator.
- **Redraws** (`-count-bodies`): while one fader is dragged, only that strip redraws, once per value change. The rows are read once for all six, and each strip is an Equatable view of its own values. The cards ran once each, because touching a fader sends MIXER to the FM-1 and their badge changed.
- **skiff-sim** (Skiff 2.2 with the screen-link patch, `b0cf6fa`), new `MixerSimTests`, run alone:
  - `aStripsFadersReachTheFirmware`: a drag of 73 level writes in 8 ms steps on T4 (not the selected track), then PAN, MUTE and the REVERB send. The firmware ends on the last value of each, and T1 is untouched.
  - `gloStepsTheMixersPages`: GLO pressed on the sim's console steps 30 → 34 and round to 30, each placed on the Mixer's section; then SCREEN_GOTO to each card.

## Not checked

- **The app talking to skiff-sim end to end.** The iOS simulator doesn't see the Mac's virtual MIDI port, and a "Designed for iPad" build only runs from Xcode.
- A real iPad and FM-1: how the haptics feel, the fader travel (PAN covers its range in about 120 pt, so it is quick), and 120 Hz smoothness.
- VoiceOver order, a hardware keyboard and focus, the largest text sizes, and the iPhone (which reaches the Mixer only through GLO).
- With `SKIFF_LINK=1`, the older `aButtonOnTheFM1MovesJib` and `theButtonMapOnTheRealFirmware` fail here (no SCREEN push reaches the session; INFO times out). They also fail when their suite runs alone. This change doesn't touch SloopKit's sources, so it's left for a separate look.

## Design pre-flight

Ran. Grayscale: the reading order holds on weight and grey value; track colour adds which track. Spacing is on the 4/8 grid (8 within a strip, 12 between its rows, 24 between sections). Type uses the existing ladder (11 / 13 / 15, two weights). Tokens are Theme's throughout, with nothing new. Targets: the fader takes the whole strip width, PAN and the send take about 52 pt including their label row, and MUTE, names and section buttons are 44 pt. Contrast is the spec's (secondary text 6.6:1 on panel; tertiary only for the 0 dB mark and decoration). Taste anchor: data-dense tool, with colour only where it names a track. Skipped: `check-tells.sh` and `check-render.mjs` scan web UI and found nothing to scan in SwiftUI, so they're not a pass. No fresh-eye review.

Left standing:
- With Delay in the middle, the space to its left is empty, as on the phone's carousel.
- The REVERB send reads every track's value every 3 s, as before, since the protocol doesn't push other tracks' parameters.

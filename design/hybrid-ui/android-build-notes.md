# Hybrid UI on Android: what the spec met in the code (2026-11-17)

Branch `hybrid-ui-android`, cut from `design-hybrid-ui`. Built against `spec.md`; checked on the P1_Phone emulator against the fake core, **not yet on the Pixel or the FM-1** (device check: `qa/device-checks/2026-11-17-hybrid-ui-android.md`). The component CRDs carry the detail; this page is the short list of where the spec and the code parted.

## Changed from the spec, and why

- **Docked panel width stays 360, not 280.** The sound panel shows four dials in a row (decision 30/32), which need about 336. The spec's 280 assumes the 2 × 2 parameter tiles (3.7), which aren't built. On the Pixel's ~914 dp the 8-step grid still gets about 60 a step (spec: about 65).
- **No Barlow Medium.** The app ships Barlow 400 and 600 only (DESIGN.md: two weights). Everywhere the spec says Medium, the build uses Regular; "SemiBold" stays 600.
- **The waiting count rides on the Bar pill** as a small white disc. The old launch word had a second line ("2 waiting"); a pill can't hold one.
- **GLO's shared pages render in the Mix tab, not the docked panel.** The agreed map (GLO opens the Mix tab and steps its pages) supersedes decision 44 on the phone. A sub-page tap sends the FM-1 to that GLO page (`ScreenGoto`), so the phone and the FM-1 stay on the same page.
- **8-step pages are melodic only.** A kit's lanes keep scrolling under the panel (decision 35, B); the drum grid has its own scroll model and wasn't converted.
- **Follow shows only while the grid pages by 8.** With the panel shut the grid follows as built (batch item 9), so a Follow key there would do nothing.
- **The pattern bar isn't the spec's.** The ruler keeps Chord, Lane, steps, Step N and the step menu; the spec's badge, two-line title, Step ⌄ and Velocity aren't built, so beside the panel the title truncates. A follow-up, with Scott's word on which keys stay.
- **Scenes toolbar is 44 tall** (scene keys 36; spec 40–48), because the header grew from 48 to 56 and the six rows need the height. The HOME knobs stay at the toolbar's right at their own height; the agreed map says "Store and 16" but doesn't retire them.
- **Empty scenes lose their outline** (spec 3.3). Fill and ink carry the state. The empty *pad* keeps its outline colour, because A11 is `[open]`.
- **No sheet shadow.** Depth comes from the surface step.
- **Readout keeps Android's menu** (tempo slide, Playback). Which popup the phones keep is phone-header I6, still open, so the spec's tempo popup (4.6) isn't built.
- **No playhead glide.** Building it would decide its Reduce Motion behaviour, which is `[open]`; the playhead still steps.

## Not built yet (in scope, left for the next round)

- Timeline's own changes (4.4): pill heads, the connected zoom group, the "2/4" chips, the playhead's round handle.
- Sounds and Projects rows (4.6): the selected preset pill with a check, slot rows, the Primary Done.
- Settings' two-column landscape layout and the list-and-detail rail (3.8).
- The loading indicator (3.12) and the app strip's restyle (3.10).
- Row stagger in menus and sheets (spec §5), and the touch disc on the pad's hold menu (the arc wheel is unchanged).

## Labs (CLAUDE.md rule 3)

Settings › Labs › **Hybrid ·**: spring bounce (25 %), at the finger (200 ms), sheets and panels (300 ms), Edit page flip (280 ms), press squash (92 %). Added 2026-11-17, review 2026-12-01. They graduate to `tokens.json`'s `motion` when Scott settles them; the radii and shape pairs in `tokens-proposal.json` live in `ui/theme/Hybrid.kt` until he approves the look after the Pixel trial.

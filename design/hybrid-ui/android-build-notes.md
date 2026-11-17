# Hybrid UI on Android: what the spec met in the code (2026-11-17)

Branch `hybrid-ui-android`, cut from `design-hybrid-ui`. Built against `spec.md`; checked on the P1_Phone emulator against the fake core, **not yet on the Pixel or the FM-1** (device check: `qa/device-checks/2026-11-17-hybrid-ui-android.md`). The component CRDs carry the detail; this page is the short list of where the spec and the code parted.

## Changed from the spec, and why

- **Docked panel width stays 360, not 280.** The sound panel shows four dials in a row (decision 30/32), which need about 336. The spec's 280 assumes the 2 × 2 parameter tiles (3.7), which aren't built. On the Pixel's ~914 dp the 8-step grid still gets about 60 a step (spec: about 65).
- **No Barlow Medium.** The app ships Barlow 400 and 600 only (DESIGN.md: two weights). Everywhere the spec says Medium, the build uses Regular; "SemiBold" stays 600.
- **The waiting count rides on the Bar pill** as a small white disc. The old launch word had a second line ("2 waiting"); a pill can't hold one.
- **GLO's shared pages render in the Mix tab, not the docked panel.** The agreed map (GLO opens the Mix tab and steps its pages) supersedes decision 44 on the phone. A sub-page tap sends the FM-1 to that GLO page (`ScreenGoto`), so the phone and the FM-1 stay on the same page.
- **8-step pages reach kits in round 5** (`DrumGrid`). **The mock's lane panel isn't built:** the docked panel is still the FM-1's own page. On EDIT › LANES a lane key turns the page's LANE knob, so the panel follows the picked lane. The mock's Tune · Decay · Level · Pan tiles, "Lane n of 8" header and decay curve need the parameter tile (3.7) and per-lane values the core doesn't send (the FM-1's LANES page has Lane, Level, Tune and Decay; no Pan). The pattern bar's Level toggle (like melodic tracks' Velocity) isn't built either.
- **Follow shows only while the grid pages by 8.** With the panel shut the grid follows as built (batch item 9), so a Follow key there would do nothing.
- **The pattern bar isn't the spec's.** The ruler keeps Chord, Lane, steps, Step N and the step menu; the spec's badge, two-line title, Step ⌄ and Velocity aren't built, so beside the panel the title truncates. A follow-up, with Scott's word on which keys stay.
- **Scenes toolbar is 44 tall** (scene keys 36; spec 40–48), because the header grew from 48 to 56 and the six rows need the height. The HOME knobs stay at the toolbar's right at their own height; the agreed map says "Store and 16" but doesn't retire them.
- **Empty scenes lose their outline** (spec 3.3). Fill and ink carry the state. The empty *pad* keeps its outline colour, because A11 is `[open]`.
- **No sheet shadow.** Depth comes from the surface step.
- **Readout keeps Android's menu** (tempo slide, Playback). Which popup the phones keep is phone-header I6, still open, so the spec's tempo popup (4.6) isn't built.
- **The playhead sweeps (2026-11-17)** by the FM-1's clock, and hits bounce as they sound. Reduce Motion: jumps, no bounce (decided by the main session for Scott). The Timeline's playhead and the automation lane are unchanged.

## Not built yet (in scope, left for the next round)

- Sounds and Projects rows (4.6): the selected preset pill with a check, slot rows, the Primary Done.
- Settings' two-column landscape layout and the list-and-detail rail (3.8).
- The loading indicator (3.12) and the app strip's restyle (3.10).
- Row stagger in menus and sheets (spec §5), and the touch disc on the pad's hold menu (the arc wheel is unchanged).

## Labs (CLAUDE.md rule 3)

**Cleared 2026-11-17** (Scott: "let's start over with all the sliders and the motion tuning… If I want to play with something, I'll let you know and we can add the settings back in one by one"). Every Labs slider is gone and its stored value dropped (`PhoneSettings.RETIRED_TUNING`). The values are fixed at the defaults: spring bounce 25 %, at the finger 200 ms, sheets and panels 300 ms, page flip 280 ms, press 92 %, shape spring 380 / 0.80, fast spring 800, squash 6 %, hit bounce 112 % / 50 / 200 ms, tab change 380 ms, and the pad-drag distances. They graduate to `tokens.json`'s `motion` when Scott settles them; the radii and shape pairs in `tokens-proposal.json` live in `ui/theme/Hybrid.kt` until he approves the look after the Pixel trial.

## Round 5 (2026-11-17)

- **Live menu switch:** the menu's choices rebuild when the transport starts or stops (`HoldMenuState.refresh`, fed by `top.playing`), and every piece travels by key. The mock's Clear steps grows from 206 to 296 wide. Here both columns are 296, so it moves and changes height, but its width is already 296.
- **Build quirk:** one Gradle run failed in `:app:buildSwift` with "No Android NDK is installed at any of the standard locations"; the same script ran clean by hand and the retry passed. If it recurs, check the Gradle daemon's environment (`ANDROID_NDK_HOME`).

## Round 8 (2026-11-17)

- **Timeline built as mocked** (spec 4.4). The selected track keeps decision 31's band under its row as well as the new edges (the thread's place is still open). The chip says "×N" when stopped and "n/N" while playing; the mock draws "2/4" on every block.
- Recorded, not built: Mix effects direction C (effect cards, the picked one grows; vault `assets/mix-effects-2026-11-17/C-effect-cards-picked-grows.png`), after the Edit redesign; the step panel driven by the FM-1's knobs (SEQ › NOTES), being mocked.

## Round 9: the Edit redesign (2026-11-17)

- **The knob answer came from Skiff v2.5.1's source in the repo, not a live probe** (the FM-1 wasn't plugged into the Mac): NOTES knobs PITCH START LENGTH VELOCITY (a kit: LANE HIT ACC VELOCITY); FEEL knobs CHANCE RATCHET NUDGE TYPE; the PRESETS encoder moves the cursor. The iPad's SeqCursor comment ("KNOB 1 moves the cursor") describes pre-2.0. Device check 72 confirms it on the real FM-1.
- **RATCHET is 1–4** because the core keeps 0–3, but the firmware's FEEL knob turns it 1–5 (`feel_turn`). That's a core follow-up, to be checked against a probe first.
- **CHANCE and COND:** on the FM-1, CHANCE's knob runs past 100 into the trig conditions. Lupe keeps them apart (the core's separate COND), as before.
- **The panel's header follows a dragged note when it drops,** not during the drag (the core's selected step drives it, and following live would send the FM-1 a cursor change for every row crossed).
- **A carried drum hit loses its accent.** It's moved as a hit off and a hit on, since the core has no move for one hit; it lands only on an empty cell.
- **Kits aren't knob-linked yet.** They need the LANE knob mapped to the picked lane.
- **The core changed (Swift):** `Fm1ScreenArea` carries `cursor`/`cursor2` on SEQ › NOTES and FEEL, and `screenGoto` takes a `cursor`.
- **Build quirk, again:** `:app:buildSwift` failed once more with "No Android NDK is installed at any of the standard locations" when the Swift core had changed, then built clean on the next run. It looks like a transient lookup in the Swift Android SDK, since the NDK and its sysroot links are intact.
- **Feel became knob tiles** (amended the same day): 1 CHANCE (into the conditions past 100), 2 RATCHET, 3 NUDGE, 4 TYPE. TYPE is shown only, since the core has no field for it; RATCHET goes to 5 on the FM-1 but only to 4 from the phone until the core's write range is checked. Drum steps get LANE · HIT · ACC · VELOCITY (ACC shown only: there's no accent intent) and the Feel tiles.

# Component reference documents

*Started 2026-11-13 as a trial on one component (the pattern pad). Adapted from Cassie Groos's CRD at Unily ("Probabilistic isn't a dirty word…", Design Systems Collective, 2026-08-27). Notes on the source and why: `~/vaults/Panopticon/Resources/Design Research 2026-11/component-reference-documents-groos.md`.*

One file per component, `design/components/{name}.md`, from `TEMPLATE.md`. It travels with the component from "Scott asked for this" to "a session placing it needs to know how it behaves". Read it **before** changing the component, and write back to it **in the same session** as the change.

## The rule: one origin per fact

A fact is written once, where it starts. Everything else points to it or is checked against it. Lupe already has homes for most facts, so a CRD carries only what has no other home:

| Fact | Lives in | The CRD |
|---|---|---|
| Where the component sits, which tab and panel | `design/structure-map.md` | links |
| Colours, sizes, radii | `tokens/tokens.json`, `Theme` | never repeats |
| Motion numbers, type, corners, confirm-in-place: rules for every component | `design/DESIGN.md` | never repeats; states only what's particular to this one |
| Feel values (springs, delays, thresholds) | Labs (`ios/FM1/Labs.swift`) while being tuned; once settled, a motion token in `tokens/tokens.json` | refers to the token (or the Labs key while still tuning), never the number (Scott, 2026-11-14) |
| How it looks | boards and mockups on the canvas (`design/boards/`, `design/motion/`) | links the board |
| Whether it passed on the iPad | `qa/device-checks/` | cites the check by file and number |
| What changed when | git | no changelog |
| Behaviour, states, accessibility intent, edge cases, what was ruled out and why | **the CRD** | this is its job |

If two places state the same fact and could disagree, one of them is wrong to have it. Fix the duplicate, don't sync it.

## Markers

- **IDs** (`F1`, `S3`, `B12`…) mark requirements. A line with an ID is atomic and testable. A line that could be half-met is two lines.
- **`[review]`** before a requirement that no test or fake can check (feel, legibility, "reads as"). Scott checks it on the device.
- **`[open]`** before a hunch or an unanswered question. **A session that hits an `[open]` on what it's about to build stops and asks Scott.** It never fills the gap with a guess.
- An **empty section** is information. Leave it empty rather than invent content that reads as decided.

## Decision log bar

Could someone plausibly propose the opposite? Then log it: dated one line, the why, who decided. Otherwise it's a commit message. A decision that shows up across components moves into `DESIGN.md` and leaves the CRDs.

## Ready to build

Not a stored flag. A section is ready when section 1 has no `[open]` on the part being built and section 2 covers it. Work it out when asked.

## The trial, and ending it early

The trial was one component, the pattern pad, from 2026-11-13. The question was whether, with its CRD read first, the next round of device-check fixes on the pad gets shorter, and whether anything ruled out comes back. **Ended early on 2026-11-14 (Scott's call):** every user-facing component got a CRD the same day as the Figma UI kit. The question still stands, so ask it of the next Pads batch anyway.

Most of the new CRDs are `draft`, and many carry `[open]` lines. That's expected: they were written from the code and the vault on one day, not from a design round. An `[open]` still means stop and ask.

## Figma

The [Lupe UI kit](https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n) is a sketch kit reverse-engineered from the code (vault: `Projects/Dev/fm1-ipad/figma-ui-kit.md`). Each CRD lists its component sets under `figma:`, and each set's description names its CRD. Figma is never a source of behaviour or of numbers. The code and tokens are.

## Index

| CRD | What it covers |
|---|---|
| `pattern-pad.md` | One entry on the Pads grid (iPad and phone) |
| `track-head.md` | Row heads, badges, mute and solo, lanes, the track chip |
| `scene-row.md` | Store and the 16 scenes |
| `top-row.md` | The iPad's top row, its tools, transport and status strip |
| `phone-header.md` | The phone's header, app menu and launch menu |
| `keys.md` | Chiclet keys, LEDs, segmented keys, chips: the shared press behaviour |
| `column-face.md` | The knob tile, dial, big control and magnifier |
| `faders.md` | Level, pan and send faders |
| `pattern-editor.md` | The editor under the divider, piano roll, drum grid, phone Edit |
| `step-inspector.md` | The selected step's notes, columns, locks |
| `timeline.md` | The Song tab's Timeline and its blocks |
| `sound-panel.md` | The sound panel, its cards, the FM-1's 12 keys, the rail |
| `sounds-panel.md` | The sound browser (panel on the iPad, sheet on the phone) |
| `mix.md` | Mix strips, FX pages, the phone's Mix pop-up |
| `hold-menus.md` | Fan menus, placed menus, the phone's callout menu, confirm in place |
| `tempo-popup.md` | Tempo, tap and playback mode |
| `connection-states.md` | No FM-1, lost, reading, wrong firmware |
| `sampler.md` | Recording and importing samples into the FM-1's slots |
| `projects-sheet.md` | Projects on the FM-1 and on the device |
| `settings-sheet.md` | Settings and Labs |

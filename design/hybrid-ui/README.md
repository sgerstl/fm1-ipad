# Lupe hybrid UI: handoff pack (2026-11-17)

A design proposal for Lupe's next look on both phones and the iPad. It keeps Lupe's own tokens, type and track colours and takes four mechanisms from Google's Material 3 Expressive: **shape as state, size for priority, containment, and spring motion**. The look is Lupe's. Only the mechanisms come from M3.

It came out of one design session on 2026-11-17: an M3 Expressive study, then a hybrid, then phone panels and dialogs, then a v2 phone layout. The vault holds the reasoning and the full run of studies: `~/vaults/Panopticon/Projects/Dev/fm1-ipad/figma-ui-kit.md`, sections "M3 Expressive study" onwards.

## Status: what's decided and what isn't

| Item | Status | Where it's recorded |
|---|---|---|
| Phone Edit with the sound panel docked uses **8-step pages** with a 16-cell minimap | **Decided** (Scott, 2026-11-17) | `design/components/pattern-editor.md` decision log; answers that file's `[open]` on board 75 |
| **Mix returns as a phone tab** (Pads · Edit · Timeline · Mix); the Mix pop-up goes | **Decided** (Scott, 2026-11-17: "most people want it more accessible") | `design/components/mix.md` decision log; reverses decision 28 |
| The hybrid look as a whole (shape-as-state pads, pill keys, connected tabs, sheet and menu styling, motion vocabulary) | **Proposal.** Scott hasn't approved it for the app | This folder |
| Phone header: **pill tabs and a Bar pill; round Record (48) and Play/Stop (56)** | **Decided** (Scott, 2026-11-17); replaces decision 29's word tabs and launch word, keeps decision 23's round keys | `design/components/phone-header.md` decision log |
| Mix strip: **pan and reverb send in the strip's long-press menu**, values shown on the strip | **Decided** (Scott, 2026-11-17) | `design/components/mix.md` decision log |
| 8-step Edit **follows the playhead only when Follow is on** | **Decided** (Scott, 2026-11-17) | `design/components/pattern-editor.md` decision log |
| Structure changes (the phone's tabs) | **Needs the structure map agreed first** (repo `CLAUDE.md` rule 4) | `structure-map-proposal.md` |

**Before building anything from this:** get Scott's OK on `structure-map-proposal.md`. The conflicts are settled (`spec.md` §7). Any line in a component's CRD marked `[open]` still means stop and ask.

## What's here

| File | What it's for |
|---|---|
| `spec.md` | The build spec: principles, token mapping, components with every state, screens with dimensions, the motion table, accessibility and contrast, conflicts and open questions |
| `tokens-proposal.json` | Additions to `tokens/tokens.json`: radii, shape-state rules and motion starting values. Motion values go to **Labs first** (rule 3), not straight into tokens |
| `structure-map-proposal.md` | The phone section of `design/structure-map.md` as it would read, for Scott to agree |
| `screens/` | The final frames at 1x (phone 874 × 402, iPad 1376 × 1032): 15 phone (with `06b`, the Mix strip's hold menu), 4 iPad |
| `components/` | The hybrid pad's states, buttons, the parameter tile and the switch |
| `motion/` | 10 reference renders (MP4, 2x, 30 fps) for the transitions in the motion table. They were rendered before the 2026-11-17 decisions, so their headers show the older rounded-square Stop and some show three tabs. The motion itself is current |

## Figma

[Lupe UI kit](https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n), page **M3 Expressive study**, section **Handoff · Lupe hybrid UI (2026-11-17)**. The frames are numbered as in `screens/`, with the hybrid components (`Hybrid · Pad`, `Hybrid · Param tile`, `Hybrid · Button`, `Hybrid · Switch`) and the stand-in icons below. Everything is bound to the kit's **Lupe** and **Track** variables, so Dev Mode shows token names. The README's rule still stands: Figma is never the source of behaviour or numbers. When this spec and the code disagree, the code and `tokens.json` win until a decision changes them.

## Caveats

- **Frame size:** the phone frames are 874 × 402 with no safe areas, Android's way. The iPhone build must inset by its side safe areas (59 pt each side on the 6.3-inch, per the structure map), which takes about 118 pt of width. The v2 Pads and 8-step Edit were drawn with that margin to spare; check the header at 734 pt wide (`spec.md` › Phone header › Narrow widths).
- **Icons** are drawn stand-ins named for what they mean. Use SF Symbols on iOS and Material Symbols on Android.
- **Nothing here has been on a device.** Springs, step widths and the 8-step paging need the Pixel and the iPad.

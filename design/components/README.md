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
| Feel values (springs, delays, thresholds) | Labs (`ios/FM1/Labs.swift`) | names the Labs key, never the number |
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

## The trial

One component, the pattern pad, starting 2026-11-13. The question: with its CRD read first, does the next round of device-check fixes on the pad get shorter, and does anything ruled out come back? Judge after the next Pads batch has been through Scott's hands. No more CRDs until then.

# Lupe: design rules

The rules every screen and change is held to. Structure lives in `design/structure-map.md`; looks and boards on the canvas. Started 2026-11-09 with the motion rule; the rest of the project's rules (tokens in `tokens/tokens.json`, the nested-corner formula in Scott's design standards) are referenced, not copied.

## Motion: nothing pops into place (Scott, 2026-11-09)

"Nothing should ever pop into place… everything should have either an animation to communicate the movement of a UI element to a new place, or a change of state, or a transition to make things feel smooth, fluid and premium."

Every change on screen is one of three, and gets the matching motion:

| What changes | Motion | Examples in Lupe |
|---|---|---|
| **Something moves** to a new place or size | It travels there (the spring or an ease-out), keeping its identity, never a jump | Pads gliding between No grid, Half and Max; the track controls unrolling from the pad |
| **Something changes state** in place | A short fade or blend between the two looks | Play colours fading in and out; a mute waiting, then landing |
| **Something arrives or leaves** | A transition that says where it comes from: out of the finger, from an edge, a fade | The fan menu from the finger; the sampler from the right; the disconnected state (below) |

Numbers (from the design standards): about 150 ms for a state change, 200 ms for things at the finger, 300 ms for a page or panel, nothing at 500 ms or more; exits quicker than entrances; ease-out in, ease-in out. Feel values go in Labs (repo `CLAUDE.md` rule 3).

Reduce Motion: nothing travels; arrivals and state changes cross-fade (about 150 ms). It never means "pop".

A screen that changes with no motion is a bug: note it on the batch list.

## Corners

Nested corners follow one formula (outer = inner + padding; a concave turn beside a neighbour = its corner + the gap; each corner nests with what it surrounds). Full text: Scott's design standards, "Radii".

## Type: Barlow (Scott, 2026-11-09, board 45)

Lupe sets its words in **Barlow**, the face Skiff draws the FM-1's screen in, and its big numbers in **Barlow Condensed**, so Lupe reads as the instrument's companion and numbers fit tight heads. Bundled in `ios/FM1/Fonts/` under SIL OFL; `Font.lupe(size, weight)` and `Font.lupeNumber(size, weight)` in `LupeType.swift`. SF Symbols keep the system font.

| Role | Face | Size · weight |
|---|---|---|
| Pad number, entry number, values | Barlow Condensed | 23–38 bold (pads), 25 bold (head entry), values 1.1 × their size, semibold |
| Track number badge | Barlow Condensed | 0.56 × the chip, bold |
| Titles (page tabs, panels) | Barlow | 17–20 semibold |
| Instrument name, body | Barlow | 15 regular, the secondary greys |
| Small lines (passes, ×N, labels) | Barlow | 11–13 regular or medium |

Barlow runs about 7 % small against SF Pro at the same size: `LupeType.scale` takes the words up by that, so sizes written for SF Pro still read the same. Two weights a view at most, as the craft bar says; numbers in even figures (`monospacedDigit`).


## Destructive actions: confirm in place (2026-11-10)

Anything that loses work asks once more **where the finger is**, never in a system alert or confirmation dialog (Scott:
"style it like the other menus with the theme and keep it close to the button press"). In a fan menu, the item is a
`MenuItem.destructive(title:confirm:)`: tapped, its own row turns into a button outlined in `Theme.recText` whose words
name exactly what goes ("Clear all 5 pads on T4 Drum Kit, erasing pattern 07"), the row below into Cancel, the other
rows fade. The confirm ignores taps for 0.4 s, so a double tap can't go through it. Tapping away, Escape or VoiceOver's
two-finger scrub cancels; VoiceOver focuses the confirm and announces its words. Where the change can be undone instead
(a step clear, kept for Undo), Undo wins over a confirm.

## The header is chrome, not content (Scott, 2026-11-13, board 71: A with C's tabs)

The square key is the content's shape: pads, steps, values, the keys inside panels. The header never uses it, so the
two read apart at a glance.

- **Project and launch** are words with a ⌄ (Barlow 17 semibold for the project, 14 for Loop in the secondary grey), no box. They open menus.
- **Record and Play are round**, as the FM-1's buttons are: Record a ring (`outline`) with the red dot, Play filled white while playing. 40 across, 44 or more of touch.
- **The readout** (bar · beat over BPM) stays plain, **left of Record and Play**, which sit at the far right edge (Scott, 2026-11-13, after using it).
- **Tabs** (Pads · Timeline · Mix) are a left-aligned row of words, Barlow 17 semibold, 24 apart: the one showing in `text` with a 3 px white underline the width of its word, the others in `text2`. The underline glides to the new tab (about 200 ms, ease-out); with Reduce Motion it cross-fades. White, not a track colour.
- A 1 px hairline (`control`) under the tabs ends the header.

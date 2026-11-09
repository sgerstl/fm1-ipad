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

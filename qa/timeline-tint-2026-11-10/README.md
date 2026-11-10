# The Timeline toned down: board 48, option A (2026-11-10)

Scott picked A, tint at rest.

- **Resting block** (Song tab only): `SelectionTint.fill(track, percent: 32)` with a 1.5 pt track-colour edge; name `text`, count `textSecondaryRaised` (5.00:1 on lime at worst); pattern picture in `textSecondary`.
- **Playing**: full track colour (dark text, 6.13:1 at worst). The old "dim what isn't playing to 50%" is gone: the tints do that job.
- **Selected**: the Pads' treatment, flat `control` grey with a 3 pt outline in the track's colour (4.45:1 on its lane at worst); playing and selected keeps the full colour with the outline outside. The open tab is from 710f7fe.
- **Waiting**: `LaunchTrace` in the track's colour, the Pads' traced outline (the dashed white pulse and countdown capsule went).
- **REST**: dashes in `Theme.restDash` #7C7C85 (4.20:1; was `disabledOutline`, 1.98:1).
- **Pads**: `Theme.laneEdge` #7C7C85 → #8E8E96 (2.67:1 → 3.40:1 on the lime selected lane).
- The Arrange page (non-compact) keeps solid blocks.

Diff (`diff-result.txt`, before = 991c086): Timeline scenes differ only inside the lanes area (x 269–1234: the blocks); Mix identical; Pads "identical" at the diff's 24-level threshold. At zero threshold they differ by 18 levels only along the selected lane's pad edges (pads-full-t1 x 404–1080, y 104–229; pads-half-t4 the T4 row), the edge change and nothing else.

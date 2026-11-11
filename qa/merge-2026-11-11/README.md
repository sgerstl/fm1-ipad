# The merge of 2026-11-11

Scott asked to merge the open branches. Into `merge-2026-11-11` (from trunk `lupe-batch-2026-11-06`, cf796dc), with real merge commits, in order:

1. **sloop-design-pass** (82c52ef): clean (a6bd4b4). It already carried perform-grid-map at 66a426b.
2. **perform-grid-map** (7f957cf): clean (6e9d1a5). Its last five commits: the timing and write fix 13e75ef, FREE TAKE boards 49–50.
3. **claude/vibrant-grothendieck-2c3efb**, the phone branch (a0f45f2), which holds a11y-pass-2026-11-10 and claude/gracious-jackson-60c5c1: seven conflicts (61f7ad4).

Left out on purpose: flash-chips (waits for `lupe-firmware-2`), bluetooth-poc (tabled), song-grid-panel-tint (superseded).

## Conflicts and the calls made

The iPad keeps Pads · Timeline · Mix and the phone keeps Pads · Edit · Mix · Sounds.

| File | Resolution |
|---|---|
| `EditorUI.swift` | Both kept: the SLOOP shell (`sloopShell`, `shell`, `enterShell`, `padHasNoSoundsTab`, `sloopPadTabs`) and the phone's Edit tab (`phone`, `phoneSkiffTabs`). Sequence goes to Song only off the phone; entering the shell honours the phone's `-page edit`. |
| `PadsPage.swift` | The phone's layout (`.phone` rows and room, its own body, the shared modifiers moved up to `body`). The tool row stays in the top bar (board 47), so the a11y pass's `toolbar(t)` sort-priority lines are dropped (the known conflict). The system `confirmationDialog` that the phone branch kept in `body` became the in-place confirm (2026-11-10), so no system dialog came back. |
| `Menus.swift` (FanMenu) | Combined: the phone's columns (a fan wraps where it doesn't fit the height), with this branch's caption, the "Don't ask again" box and the in-place confirm. The columns' height is what's left after the caption and the box. |
| `MixerPanel.swift` | SLOOP's structure (its `if/else` and the SLOOP-only wrap) with the a11y pass's `row.levelSpec(session)` specs (the old locals are gone). |
| `AppView.swift` | Both `onChange` handlers: the SLOOP shell switch and the a11y pass's disconnect announcements. |
| `PhoneAppView.swift` | Trunk's FM-1 / Skiff demo / SLOOP demo menu, plus the phone branch's Settings… item. |
| `design/structure-map.md` | The iPad's tabs and Sounds-panel paragraphs ("The iPad's tab bar is Song · Mix" retitled "The iPad has no Sounds tab"), and the phone branch's pointer to its own "The phone" section. |

## Checks

- **Builds:** iPad (iPad Pro 13 sim) and iPhone (iPhone 17 sim), same universal target: both succeed.
- **Tests:** `swift test` in SloopKit: **299 tests in 55 suites, all pass.**
- **iPad, Skiff** (`after/`, the eight scenes of `ipad-tabs-2026-11-10`): every scene identical to perform-grid-map's tip except the bottom 5 pt, which is iOS's home indicator (`diff-ipad-skiff.txt`).
- **iPad, SLOOP** (`after/sloop-*.png`) against `sloop-design-pass-2026-11-10/one-row/after/`: the same layout (Pads with the sections, the Timeline with the order, Mix, the one-row bar). The differences are the SLOOP demo running (its clock, the notes in the editor, one track's reverb).
- **iPhone, Skiff** (`phone/`) against the phone branch's audit shots (`accessibility-2026-11-10/screens/iPhone-phone-*.jpg`): Pads · Edit · Mix · Sounds, the same Pads grid, Edit roll and Mix strips (the reference shots were taken playing).

Not checked: the iPad itself (nothing installed), VoiceOver on the merged fan, the phone's long fans with a caption (no such fan opens on the phone yet).

Nothing pushed; no branch or worktree deleted.

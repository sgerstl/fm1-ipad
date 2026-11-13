# Device check: soundpage-to-sloopkit (claude/android-p4-sound-pages-7e2a23), 2026-11-14

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; the branch merges to `main` only after it passes.

**What changed:** `SoundPage` and `SoundFamily` (the PAGES table, the connected firmware's pages, `shown`, `reached`, `page(fw:)`, `skiffHides`, `userSlot`) moved from `ios/FM1/Sound.swift` into SloopKit (`SoundPages.swift`, public) so the Android phone core can use them. **No behaviour should change.** The iPad keeps its views, `cardID` and the tab mapping (`SoundPage.tab(for:)`) as an extension in `Sound.swift`. What was checked: SloopKit builds and its tests pass (349 tests; `SkiffBacklogTests` failed once while Xcode was building in parallel and passes alone), `xcodebuild` of the FM1 scheme for the iPad simulator succeeds. The iPad's UI tests (`FM1UITests`) were not run. The simulator never showed the screens, so everything below is untested on screen.

**Setup:** Skiff on the FM-1, 2.2 for checks 1–5 and 2.5.1 for check 6 (repeat 1 and 2 on whichever you have if you only have one) · Lupe built from this branch for the iPad · cable · screen link on (the default).
**Back up first?** No. Nothing here writes the FM-1. (Check 5 turns a knob on a sound; use a throwaway track.)

Every place the iPad shows sound pages is listed, so one pass covers the move.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Sound tab. Press ENV, LFO, FX, SEL, EDIT and ARP on the FM-1 in turn, then press each one again to step through its pages. | The tab follows every press, onto the same page as the FM-1's screen. Each card shows the four knobs in the FM-1's order, empty knobs as empty, titles as before (EDIT 1 · and the engine's name). | – | ☐ pass ☐ fail: |
| 2 | Turn a knob on the FM-1 on a page of each family (ENV, LFO, FX, ARP). | The tab jumps to that page and marks the knob; the value on screen matches the FM-1's. | – | ☐ pass ☐ fail: |
| 3 | Select a DRUM track. Press FX, EDIT, ENV on the FM-1. Then a DRUM-X track and a SLICE track, EDIT. | The drum track shows the drum pages (no ENV or VOICE; ENV opens the synth pages, "DRUM TRACK" on the FM-1). EDIT shows LANES / LANE MIX on DRUM, SOUND on DRUM-X, SLICES on SLICE. | – | ☐ pass ☐ fail: |
| 4 | Select an FM6 track. EDIT, then page on to OPERATOR and ALL OPS. Select a SAMPLE track on a user set (USR1…USR3), EDIT. | FM6 shows no ENV pages and has OPERATOR and ALL OPS. The user SAMPLE track has a SAMPLES page; a built-in set doesn't. | – | ☐ pass ☐ fail: |
| 5 | Phone layout (iPhone or the iPad's compact layout) if you use it: Shape, the sound panel's page chips, the mix's sound card, the pad grid's sound drawer, track chips. Turn a knob on the FM-1; tap a page chip. | Each opens the same page as before, marks the same knob, and tapping a chip sends the FM-1 to that page. Nothing shows a page for a track that doesn't have it. | – | ☐ pass ☐ fail: |
| 6 | On Skiff 2.5.1: FX, step through its pages. Check the FM-1 counts "FX n/7" and the iPad's FX row has DELAY and REVERB with the track's SEND, and INSERT 2 only in Lupe's row. | DELAY and REVERB (SEND first), then the bus knobs; INSERT 2 isn't one of the FM-1's pages, so stepping on the FM-1 never lands on it. Pressing DELAY on the iPad sends the FM-1 to its own DELAY page. | – | ☐ pass ☐ fail: |
| 7 | Press HOME, SEQ, SAVE, GLO and hold SCL on the FM-1. | HOME and the sequencer pages show the Sequencer tab, SAVE the Library/Song tab, GLO the Mixer, SCL held the Sound tab. Same as before this branch. | – | ☐ pass ☐ fail: |

**Not covered here** (needs skiff-sim, VoiceOver or a later round): VoiceOver labels on the page cards (unchanged by this branch, release pass); the Sloop (not Skiff) firmware's page table: it is the same `SoundPage.all`, but no SLOOP unit is on hand to try it.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

# Device check: claude/scope-spike-53b5eb (decision 46, SkiffDraw on Android), 2026-11-15

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it on the Pixel with the FM-1. The branch merges only after it passes.

**Setup:** FM-1 on **Skiff-Lupe 2.5.1** (screen link 6, or 7 "take") · the Android build from this branch (`android/app/build/outputs/apk/debug/app-debug.apk`, or `./gradlew :app:installDebug` onto the Pixel) · USB · Settings › Show graphics on · FM-1 on THEME SKIFF.
**Back up first?** No. Every check only reads; nothing writes the FM-1's flash.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Press GLO on the FM-1 until DELAY (2/5). Turn TIME, FEEDBACK, MIX. | The docked panel's picture is the FM-1's own DELAY picture, bar for bar (DRY label, MODE card, beat numbers 1–4), in grey with the dry hit white. It fills the picture box's height at 1.7 : 1 with crisp pixels and sits straight on the box's dark background (no second frame). It follows each turn. | – | ☐ pass ☐ fail: |
| 2 | GLO again: REVERB, CHORUS, GLOBAL. Turn SIZE / DAMP, RATE / DEPTH, SWING. | Each picture is the FM-1's (REVERB's staircase tail, CHORUS's wave, GLOBAL's 16 bars and SWING ratio), grey and white. | – | ☐ pass ☐ fail: |
| 3 | FX › DELAY and FX › REVERB on track 1, then on track 3. | The same drawings in the track's colour (vermilion, then amber), the echoes / tail scaled by the track's send. | – | ☐ pass ☐ fail: |
| 4 | ENV, then LFO with a held key. | ENV's curve with its dots as on the FM-1. LFO's wave with the white dot moving along it at the LFO's rate (still with Reduce Motion on). | – | ☐ pass ☐ fail: |
| 5 | EDIT 1 and EDIT 2 on an ANALOG track; EDIT on an FM6 track (OPERATOR, ALL OPS). | ANALOG: the oscillator wave, then the filter curve with its Hz. FM6: the algorithm chart as the FM-1 draws it. | – | ☐ pass ☐ fail: |
| 6 | EDIT 1 on track 6 (Drum Kit, DRUM), stopped, then playing; then on a LOFI track. | The SKIFF "sea": track-coloured columns rising with each track's level, the little boat on the crest. Stopped: all columns grey and low, the boat still crossing. Playing: they rise with the music (not in step with the FM-1's own swell; that's expected). | – | ☐ pass ☐ fail: |
| 7 | Pages SkiffDraw doesn't draw: FX 1/7 (FX's send sliders), SEL › SCALE, ARP, FX › INSERT, DRUM-X's SOUND, EDIT on a SAMPLE track. | The phone's own hand-drawn pictures, as before. | – | ☐ pass ☐ fail: |
| 8 | (If a Skiff-Lupe 2.2 or plain Skiff 2.5.1 unit is to hand) connect it. | Every page shows the hand-drawn picture: the version check refuses the build. | – | ☐ pass ☐ fail: |

**Not covered here:** TalkBack (the picture keeps the old description: "DELAY: …"), the iPhone and iPad (they keep their hand-drawn pictures until Skiff's authors allow the App Store), other THEMEs (Lupe draws SKIFF with the FM-1's own track colours).

**After the run:** failures go on the batch list with the check number.

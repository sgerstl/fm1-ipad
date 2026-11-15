# Device check: claude/iphone-consolidation-6090a2, 2026-11-15 (SLOOP removed, decision 43)

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the iPad and the FM-1; the branch merges to `main` only after it passes.

**Setup:** FM-1 on Skiff-Lupe 2.2 or 2.5.1 · Lupe from this branch (its last commit) on the iPad and the iPhone · USB-C straight in.
**Back up first?** Only for check 6, which puts SLOOP on the FM-1 (outside Lupe) and Skiff-Lupe back on. Back up in Lupe first (FM-1 menu › Projects…, Save as…), and skip check 6 unless you want to see the SLOOP offer on the device.

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Plug the FM-1 into the iPad and open Lupe | It connects as before: Song · Mix, six tracks, the screen link following the FM-1's buttons | – | ☐ pass ☐ fail: |
| 2 | Tap the FM-1 key (top left) | The source group reads "FM-1 over USB" and "Demo" (no "Skiff demo" / "SLOOP demo"); pick Demo, then FM-1 over USB again | – | ☐ pass ☐ fail: |
| 3 | FM-1 menu › Projects…; open a row's ⋯ | Rows show "Saved … · n patterns"; the menu has Rename, Duplicate, Delete (no Export…); the footer talks about the pool and the FM-1 stopping | – | ☐ pass ☐ fail: |
| 4 | Select a DRUM track, open the keyboard drawer, play the white keys | The lanes sound; the black keys are silent; no "GLO > MIDI > OTHER" warning | – | ☐ pass ☐ fail: |
| 5 | Install firmware… (iPad) / FM-1 firmware… (iPhone) | The choices are the Skiff-Lupe builds and, under Back to stock, Stock V15. No SLOOP-Lupe | – | ☐ pass ☐ fail: |
| 6 | (Optional) Put SLOOP 2.8.4 on with SLOOP's own installer, then plug the FM-1 into Lupe | It doesn't connect. iPad: the card "Lupe needs Skiff-Lupe" naming SLOOP 2.8.4, with the line about OLD FORMAT and SLOOP's own backup. iPhone: the fork offer for SLOOP 2.8.4. Then install Skiff-Lupe from the card and restore your project | Yes | ☐ pass ☐ fail: |

**Not covered here:** VoiceOver on the changed cards (release pass); the simulator-only firmware demos (`-demo -demo-firmware fork-sloop` shows check 6's phone card without a device).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

## GLO's pages in the sound panel (decision 44) and the rail key

7. **GLO on the FM-1 (no flash write).** Press GLO on the FM-1: MIXER (GLO 1/5) shows the Mix tab. Press again: the sound panel slides in over the Mix tab with "GLO 2/5 DELAY", four white dials, MODE as three tiles and the grey picture under them, the panel grey, not the track's colour. Again: 3/5 REVERB, 4/5 CHORUS, 5/5 GLOBAL; again: MIXER, and the panel goes.
8. **GLO on the rail (Settings › Sound buttons on).** Tap GLO: 2/5 DELAY opens; tap again: 3/5, 4/5, 5/5, then 2/5. GLO is lit while a GLO page is docked. Song name › Shared effects… opens 2/5 too; the Mix pop-up is gone.
9. **Rail key on the FM-1's page.** Press FX on the FM-1 and step to FX 3/7, change tab in Lupe (the panel closes), then tap FX on the rail: the panel opens on FX 3/7 and the FM-1 stays on it.
10. **iPad.** Tap GLO on the iPad's rail: its sound panel opens with DELAY, REVERB, CHORUS and GLOBAL; MIXER stays in the Mix tab.

## The trunk merged in (Android combined, P1's SloopKit move)

11. **iPad HOME knobs (no flash write).** Select each track in turn: the four tiles over the track controls name the same parameters as KNOB 1–4 on the FM-1's HOME (they now come from SloopKit's table, the phones' one).

## Two iPad bugs from the trunk build (299b346)

12. **Record on a drum track with the keys open (no flash write).** Select a Drum Kit track, open the keyboard drawer, press Record: it records and plays, the kit's keys light with the lanes as they play, and Lupe doesn't crash (it did every time).
13. **The active track's pad menu toggles (iPad).** Stopped, tap the selected track's framed pad: its menu opens. Tap the same pad again: the menu closes and stays shut. A pad on another track still works as before. The iPhone's wheel opens and closes the same way.

## The iPad's track heads (Scott, after 63db236)

14. **A tap selects, a hold picks the sound (no flash write).** On Pads, tap a track head anywhere, the name included: the track selects and nothing opens. Hold a head: the track menu opens beside the finger with Select sound first; it opens the sounds panel. Same on the Timeline's lane heads and the Mix strips. The heads' names have no ⌄ now. MUTE and S keep their own taps.
15. **Press menus have a soft backing (iPad).** Hold a pad, tap the selected pad, hold a track head: behind each menu a soft black field (30 %), about 16 pt past it on every side, fades in and out with it. The page itself doesn't dim. The iPhone's wheel keeps its own arced backing.
16. **The lifted pad stays under the finger (iPad).** Stopped, hold a pad and drag it about: it stays under your finger where you grabbed it, all the way to the edge wells, and a drop lands in the well it looks to be in.

# Device check: claude/android-p2-shell-02c86f, 2026-11-14 (the combined phone design, P2's part)

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with the Pixel and the FM-1; the branch merges only after it passes. Decisions 31–35; boards 76 (Pads and Timeline) and 77 (the Mix pop-up). Edit and the docked sound panel are P4's and have their own sheet.

**Setup:** Skiff 2.5.1 on the FM-1 · Lupe (this branch) on the Pixel, landscape · USB-C cable.
**Back up first?** Yes, before rows 10–14 and 16: they change the song's list or the track's level on the FM-1 (Lupe › Projects › Save).

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | Pads: tap each track's head in turn | The track's colour, muted, runs under its whole row (head, MUTE, every slot) and glides to the next row. No outline round the row | – | ☐ pass ☐ fail: |
| 2 | Launch a pad with the launch set to Bar, while playing | The 2 dp outline still draws round the waiting pad as the bar comes, and reads against the band. The pad no longer says "bar N" | – | ☐ pass ☐ fail: |
| 3 | Pads, a track with few entries | Slots to H are drawn: empty ones an outline with their letter. Filled ones keep ×N and "next". On the selected row the empty outlines take the track's colour | – | ☐ pass ☐ fail: |
| 4 | Look at the scenes row; tap Store, then tap it again | A short "Store" key with a dot (the dot red while armed); empty scenes outlined, stored ones filled, the current white. Arming doesn't move the scenes | – | ☐ pass ☐ fail: |
| 5 | Switch Pads → Timeline → Pads | The band travels from the row to the lane and back, behind the pages; nothing flashes when it lands | – | ☐ pass ☐ fail: |
| 6 | Timeline: tap track heads | The band under the head and the lane; the lane's well fades out where the band is | – | ☐ pass ☐ fail: |
| 7 | Hold a track's head | Sounds…, LEVEL, PAN, Mute, Solo. With a right-handed setting the choices open to the left of the finger where there's room (at the left edge they open right) | – | ☐ pass ☐ fail: |
| 8 | In that menu, slide a finger along LEVEL, then along PAN | The value and the gauge follow; the FM-1's MIXER moves with it; the menu stays open. PAN's gauge grows from the middle | Yes | ☐ pass ☐ fail: |
| 9 | Hold a pad that holds a pattern (stopped) | Edit steps, Select sound, Set pattern…, Play once more, Play once less, More… (Duplicate after, Move earlier, Move later, Clear) | – | ☐ pass ☐ fail: |
| 10 | Play once more, then Play once less | The pad's ×N goes up, then down; the Timeline's block gets longer, then shorter | Yes | ☐ pass ☐ fail: |
| 11 | Duplicate after; Move later; Move earlier | A linked copy appears in the next slot; the pad swaps with its neighbour and back | Yes | ☐ pass ☐ fail: |
| 12 | The same menu while playing | Those choices are dimmed and say "Stop first" | – | ☐ pass ☐ fail: |
| 13 | Hold an empty slot: Rest | The slot becomes a REST | Yes | ☐ pass ☐ fail: |
| 14 | Timeline, hold a block: Edit steps; Move earlier / later | The Edit tab opens on that pattern; the block moves one place | Yes | ☐ pass ☐ fail: |
| 15 | GLO on the FM-1 (or song name › Mix…) | No "Mix" title: MIXER DELAY REVERB CHORUS GLOBAL in one line with the page count and ✕ at the right | – | ☐ pass ☐ fail: |
| 16 | DELAY: turn TIME, FEEDBACK, MIX; change MODE | Four dials two by two at the left, DELAY MODE under them; at the right the FM-1's picture: a white dry bar, grey echoes with square corners on a beat ruler. TIME spaces them, MIX sets the first echo, FEEDBACK how fast they fall. The mode's word top right. Hold it beside the FM-1's screen | Yes | ☐ pass ☐ fail: |
| 17 | REVERB: SIZE, DAMP, TYPE | Five white bars, then a tail that falls in visible steps; a dark band along its top that grows with DAMP; SPRING adds the coil; HALL is twice as long | Yes | ☐ pass ☐ fail: |
| 18 | CHORUS: RATE, DEPTH, FEEDBACK, MODE | CHORUS: a wave round a line, more waves with RATE, taller with DEPTH, a faint second wave with FEEDBACK. FLANGER: a comb, filled under. PHASER: two notches | Yes | ☐ pass ☐ fail: |
| 19 | GLOBAL: SWING+ | Sixteen bars, downbeats tall and white; the off sixteenths move right over their dashes; "SWING 60:40" at 50 | Yes | ☐ pass ☐ fail: |
| 20 | A track's FX key to DELAY, then REVERB, with GLO › DELAY's MIX at 90 | The same drawings in the track's colour. The first echo is lower than the dry bar by the MIX and the track's send (it was too tall before) | – | ☐ pass ☐ fail: |
| 21 | Settings | Groups: FM-1, Touch (Slide to turn, Magnifier, Handedness, Haptics), Sound pages (Show graphics, Sound keys), Labs | – | ☐ pass ☐ fail: |
| 22 | Handedness to Left-handed; hold a pad in the middle | The choices open to the right of the finger | – | ☐ pass ☐ fail: |
| 23 | Tap "Bar ⌄" with nothing waiting, then with a launch waiting | The footer reads "Nothing waiting" (dimmed), then "Cancel waiting" with the count | – | ☐ pass ☐ fail: |
| 24 | Start Lupe with the FM-1 unplugged | The header stays, greyed; a card: "Plug in the FM-1", Skiff 2.5.1, a moving bar, "Use the demo FM-1" | – | ☐ pass ☐ fail: |
| 25 | Tap Use the demo FM-1; then song name › Leave the demo | The app fills with the demo song and works; Leave the demo brings the card back | – | ☐ pass ☐ fail: |
| 26 | In the demo, plug the FM-1 in; Leave the demo | Lupe shows the real FM-1 (it kept looking while the demo ran) | – | ☐ pass ☐ fail: |

**What the building session saw on a screen:** only row 3's Pads page (the band under track 1, outlined slots A to H, the Store key and scenes), on its own emulator against the fake core. Everything else here (the Timeline's band, the hold menus and their slide rows, the Mix pop-up and its four pictures, Settings, the launch footer, the no-FM-1 card and the demo switch) was built and unit-tested but **not seen on any screen**: the emulator kept restarting under the Mac's load. Nothing was run on a Pixel or a real FM-1.

**Not covered here:** TalkBack (release pass); the largest text size; the Sound keys switch does nothing until P4's rail reads it; Make unique, Copy to another track, Move to a named pad and the Patterns pool are not in the pad menu (the core has no way to ask for them yet).

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

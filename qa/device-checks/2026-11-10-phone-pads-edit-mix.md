# Device check: claude/vibrant-grothendieck-2c3efb (phone Pads · Edit · Mix), 2026-11-10

Written by the session that built it (see `CLAUDE.md`, rule 2). Scott runs it with an iPhone, the iPad and the FM-1; the branch merges to `main` only after it passes. It's built on `claude/gracious-jackson-60c5c1` (the phone's Skiff tabs), which is on `a11y-pass-2026-11-10`, so it goes in after those, or with them.

**What changed:** the phone with a Skiff FM-1 gets the layout agreed in `design/structure-map.md` › "The phone with a Skiff FM-1" (boards 46–50):
- **Four tabs:** Pads · Edit · Mix · Sounds.
- **Pads:** the grid.
- **Edit:** the pattern and the step panel.
- **Mix:** one GLO page at a time.
- **Launch key:** in the top bar.
- **Sound panel:** comes in from the right, with Settings › Sound buttons' rail.

The iPad is meant to be unchanged.

**Setup:** FM-1 on Skiff-Lupe firmware · Lupe from this branch, on an iPhone (landscape) and on the iPad · USB cable · a song with a few entries on several tracks.
**Back up first?** No. Nothing here writes the FM-1's flash: launches, mutes, scenes, Launch at and the mixer are live settings. (If you tap Store on a scene, that keeps the scene in the FM-1's PERFORM state, as on the iPad.)

| # | Do this | You should see | Backup | Result |
|---|---|---|---|---|
| 1 | iPhone: open Lupe with the FM-1 plugged in and let it connect. | Tabs **Pads · Edit · Mix · Sounds**, Pads selected. Six rows, one per track: a number and a speaker key on the left, the pads A–H to the right, Store and scenes 1–16 along the foot. Nothing runs off the screen. | – | ☐ pass ☐ fail: |
| 2 | Stopped: tap a filled pad on another track's row, then press PLAY. Tap a different pad on that row while it plays. | The first tap puts that track on the entry; it plays. The second waits (dashed outline) and comes in at the launch point. The selected track doesn't change. | – | ☐ pass ☐ fail: |
| 3 | Tap the **Bar** key in the top bar. Pick **Beat**, then open it again and tap **Cancel waiting** while a launch is waiting. | A menu: Loop, Bar, Beat, Now (one ticked), how many wait, and Cancel waiting. The key then reads "Beat", plus "· 1 wait" while something waits. Cancel takes the waiting launch back. The FM-1's LAUNCH setting follows. | – | ☐ pass ☐ fail: |
| 4 | Tap a track's speaker key, then tap it again. Tap a track's number. | It mutes at the launch point and comes back. Tapping the number selects the track: its lane tints, and the chip at the top left shows it. | – | ☐ pass ☐ fail: |
| 5 | If the song uses more than 8 entries: drag the pads sideways with one finger, then with two. | The columns past H scroll into view. The heads and scenes stay put. A tap still launches, and a hold still opens the pad's menu. | – | ☐ pass ☐ fail: |
| 6 | Tap **Edit**. | The selected track's pattern, a bar wide. A line above reads e.g. "1 Acid · A · pattern 01 · chromatic · 16 steps". | – | ☐ pass ☐ fail: |
| 7 | Tap **Step 1**. Turn the FM-1's knobs 1–4. Tap the key again. | The step panel slides in from the right: PITCH, MOVE, LENGTH and VELOCITY, then CHANCE, RATCHET, COND and NUDGE. The key shows ✕. The knobs change the four NOTES values. Scroll it for Sound at this step and Lock. The key closes it. | – | ☐ pass ☐ fail: |
| 8 | From Pads, press **SEQ** on the FM-1. | Lupe goes to Edit with the step panel open. | – | ☐ pass ☐ fail: |
| 9 | Tap **Mix**. Move a level, a pan and a reverb send, and mute a track. | Down the left: Mixer, Delay, Reverb, Chorus, Global. Mixer shows six rows, each with a horizontal level (dB), pan, reverb and a speaker key. The FM-1's MIXER follows each change. | – | ☐ pass ☐ fail: |
| 10 | Press **GLO** on the FM-1 four times. Then tap Reverb in Lupe. | Each press steps Lupe's page: Delay, Reverb, Chorus, Global. Each shows the iPad's card filling the page, and its knobs turn its four values. Tapping Reverb shows it on the FM-1 too. | – | ☐ pass ☐ fail: |
| 11 | Press **FX** on the FM-1 while on Pads. Then press **HOME**. | The sound panel slides in from the right over the pads, with FX's pages for the selected track and the FM-1's 12 keys at its foot. HOME closes it. | – | ☐ pass ☐ fail: |
| 12 | iPhone: ⋯ › **Settings…** (new on the phone) › **Sound buttons** on. Back on the phone, tap ENV on the rail, then SEQ. | A column of keys down the right edge: FX, SEL, ENV, LFO, EDIT, ARP and SEQ, all reachable, with the top bar still in place. ENV brings its panel in. SEQ goes to Edit. | – | ☐ pass ☐ fail: |
| 13 | Hold **ARP** on the FM-1 (PERFORM) while on Mix, then let go. | Lupe shows Pads while it's held, then goes back to Mix. | – | ☐ pass ☐ fail: |
| 14 | iPhone, Pads: hold a filled pad, pick **Edit pattern**. Then tap Bar to open its menu. | Lupe goes to Edit on that pad's pattern. The Launch menu's grey title ("Launch at") reads clearly: it's a shade lighter in every menu now, on the iPad too (contrast fix). | – | ☐ pass ☐ fail: |
| 15 | iPad, same FM-1: open Lupe and tap through Song, Mix and Sounds. Open the mixer and an effect card. | As before: Song with the Pads grid and the tool row, Mix with six strips over the carousel. The rail, if it's on, looks as it did. | – | ☐ pass ☐ fail: |

**Not covered here** (needs skiff-sim, VoiceOver or a later round):
- **Known, not fixed:** a pad's hold menu (the fan of buttons) runs off the bottom of the phone, with "Select sound" half cut and more below. A follow-up.
- **Checked in the simulator only:**
  - All of the above, against the Skiff demo on the "A11y iPhone" simulator (iPhone 17, 44 pt rows).
  - The smallest phones (iPhone 16e and SE class): the rows drop to 40 there. Not checked.
- **Not checked at all:**
  - With Sound buttons off, the panel's 12 keys at its foot on the phone. The demo can't press the FM-1's FX, so this was never seen in the simulator.
  - The Settings sheet on the phone (new in its ⋯ menu): it's the iPad's sheet, a scrolling form. It opened and read well in the simulator; Sound buttons is further down it.
- **Left out on purpose:**
  - Edit's pattern menu (from the board). Edit shows the pattern the track is on.
  - Motion lanes on the phone.
  - The Timeline tab (not designed).
- **VoiceOver:** on the phone it waits for the release pass. The simulator audit's results are in `qa/accessibility-2026-11-10/README.md` › iPhone › Third run.

**After the run:** failures go on the batch list with the check number; passes move their batch items to "On the device".

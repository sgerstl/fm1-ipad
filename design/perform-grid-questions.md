# The performance grid: open questions and the protocol check

*2026-11-10. Goes with "The performance grid" in `design/structure-map.md`. Answer these before any screen design.*

## Design intake

This is a new view in an existing project, so the vault's short form applies (Q1, Q2, Q5, Q7 and influences), and the project already answers all of it:

- **Q1 What is it:** native iPad app, phone in landscape too.
- **Q2 Design system:** Lupe's own (`tokens/`, `design/brand/`, the design brief). The grid uses Lupe's pads, marks and colours; there's no direction round of three style tiles.
- **Q5 Feel / Q7 Colour:** from the brief: data-dense tool, colour means track or state only, tactile pads.
- **Influences:** you named the clip launcher. Treated as a reference for the *behaviour* (rows of clips, staged launches, scenes across), never for its look.

If you want the grid to look different from the 4 × 4 pads (a "stage mode", say), that's a direction question and the intake opens again. I'm assuming not.

## Open questions for Scott

**Answered 2026-11-10:** its own tab called Live (1); Pads stays beside it; a row's stop is its mute (2); no column launch (3); keep board 37 on the phone (4); a staged pad tapped again takes the launch back (5); the playing pad tapped restarts it (6). **Still open:** 7 and 8, neither changes the mock. **Before building 5 and 6:** a device check of whether relaunching the playing entry restarts its pattern from step 1; if not, restart needs a small firmware op.

1. ~~**Where it lives.**~~ Its own tab, Live.
2. ~~**Stopping a track.**~~ The mute. A real stop would need a firmware op (below).
3. ~~**Column launch.**~~ Left out. A launch button at the top of each column ("everything to entry C") the way a clip launcher's scenes work? It's not the same as Skiff's scenes, which hold any entry per track. Lupe could send six PLAYs, and at BAR or BEAT they land together; at LOOP each track lands at its own pass end; tracks with nothing in that column keep playing. Leave it out for now, or add it?
4. ~~**The phone.**~~ Board 37: five tabs, rows 40, scenes 34. Live makes five tabs (Pads · Timeline · Live · Mix · Sounds), and the scene row doesn't fit under six rows of pads at phone height. Options: a 2 × 8 scene sheet from a Scenes button in the tool row; the grid drops to the tracks in use; or the phone's All tracks has no scenes (One track keeps them). Which?
5. ~~**Tapping a staged pad again.**~~ Takes it back. Take the launch back (Lupe would relaunch what's playing, replacing the staged one; see 6 for what that does), or nothing? The FM-1 has no per-track cancel; Cancel takes back everything.
6. ~~**Tapping a playing pad.**~~ Restarts it (pending the device check). On a clip launcher it restarts the clip. On Skiff it stages the same entry again at the launch point, keeping the track's edits (`same` in `stage_entry`). I haven't confirmed from the source whether the swap restarts the pattern from step 1; a device check settles it. Which do you want: a restart, or nothing?
7. **The FM-1's own PERFORM layer.** The 4 × 4 mirrors its white keys. The grid has no hardware twin. Is that fine, or should All tracks follow when you hold ARP on the FM-1 (it switches to the PERFORM layer)?
8. **The FM-1's sound keys on Live.** FX…ARP open the sound panel over Song and Mix. Over Live too (shape a sound mid-set), or leave Live alone while you play?

## Protocol check: what the grid needs and what Skiff 2.2 + the screen link can do

Checked against `skiff-src` `web/EDITOR_PROTOCOL.md` ("Pool, lists, PERFORM") and `firmware/src/bank.c` (`bank_switch`, `stage_entry`, `chain_wait`) at b5a0686.

| The grid needs | Today | Gap? |
|---|---|---|
| Launch any track's entry without selecting it | LIST op 3 PLAY, track + entry. In Lupe as `ListOp.play(track:entry:)` (the brief called it `SongOp`; there's no such type). | None. |
| Each track's playing, staged entry and pattern | LIST2 reply, per track: entry on, entry staged, pattern on. | None. |
| Launches on several tracks landing together | Each PLAY takes its landing point when it's staged: BAR and BEAT land together; LOOP lands at each track's own pass end; NOW lands as each op arrives (milliseconds apart over USB). | None for v1. |
| Chains | A launch inside a chain starts from its first; at LOOP a track on a chain waits for the chain's end. | None; the grid only has to draw it. |
| Pass progress and the countdown | Not reported. Lupe counts the MIDI clock per track (`passProgress`, `ticksToLaunch`). | Known limit: no progress when the count isn't known. |
| Seeing changes made on the FM-1 | Nothing is pushed; Lupe reads LIST and PERFORM about once a second, and at once after its own ops. | A launch from the FM-1's keys shows up to a second late. Acceptable; noted. |
| **Stop one track** | No op. PLAY on an empty entry is refused and leaves the staged one. Mute (PERFORM op 3) silences without stopping. | **Gap.** A firmware op "stage a rest on track k" would be small: `stage_entry` already builds a rest (its `adv` path). Only if you want a real stop (question 2). |
| **Cancel one track's launch** | Only CANCEL, everything staged. | **Gap**, small. Workaround in question 5. A firmware op "unstage track k" would be a few lines (`launch_q[k].armed = 0`). |
| **What's in a scene** (for the held preview on the grid) | Not readable: PERFORM says which scenes are kept, not their entries. Lupe learns a scene only when it's stored or recalled from Lupe (`scenesSeen`), forgotten on reconnect. | **Gap.** A PERFORM read op returning a scene's 6 × (entry, mute) would make the preview work for every scene, including ones stored on the FM-1. Worth adding to the Skiff-Lupe patch if the preview matters. |
| Launch quantize per pad or per track | One LAUNCH for the whole FM-1. | Not needed; the map leaves it out. |

None of the gaps blocks a first version: with the mute as the stop, Cancel as the cancel and scenes previewed when seen, the grid runs on today's firmware. The three firmware ops are options for later, each a Skiff-Lupe patch with its own device check and backup.

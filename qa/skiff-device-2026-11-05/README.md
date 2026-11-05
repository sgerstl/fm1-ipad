# Skiff on the real FM-1: the keyboard, the iPad's sound, each lane's pass (2026-11-05)

Scott installed Skiff 2.2 on his FM-1 from Jib and found three things. Each was traced to Skiff's source (`~/code/skiff-src`, `db2ce89`, the 2.2 build) before fixing.

## 1. The iPad keyboard didn't play the FM-1

**Cause:** Jib's keyboard played on MIDI channel 16, which SLOOP routes to the selected track. Skiff drops it: MENU > MIDI > MIDI IN is CH1-6 by default, meaning channels 1–6 play tracks 1–6 and 7–16 are ignored (`seq.c` `midi_slot`, `midi_control.c` line 437). Skiff's AUTO CHANNEL, the setting that would play the selected track, is OFF by default.

**Fix:** on Skiff the keyboard plays on the selected track's own channel, track k on channel k + 1 (`trk_midi_ch`'s default; Jib already reads Skiff's NOTES OUT that way). This works with MIDI IN on CH1-6 or SEL. Each note-off goes out on the channel its note-on used. **Known limit:** a track moved to another channel in MENU > MIDI > T1..T6 CHANNEL isn't followed, because the editor protocol doesn't report those channels.

## 2. The iPad audio button didn't work

**What Skiff has:** a class-compliant USB audio input (UAC1, the master output, 44.1 or 48 kHz; `usb.c`, built in by `felucca.c`'s `FELUCCA_UAC 1`). Its source says iPadOS sees it. SLOOP's USB AUDIO = FULL has an equivalent, MENU > USB LEVEL: MASTER (USB follows the MASTER knob, the default) or FIXED (USB at the full level, MASTER after it; `fx.c` `fx_usb_fixed`). The editor protocol sets it with MENU_SET (73), id 10, and reads it with MENU_DESC (72).

**Cause (in Jib):** the speaker side only worked through the SLOOP driver. On Skiff, Jib never set FIXED, so the iPad's level followed the FM-1's MASTER knob (quiet, or silent, with MASTER down). The menu also stayed on "Setting the FM-1's USB AUDIO to FULL…" for good. Skiff also has no protocol command for MASTER, so Jib can't quiet its speaker the way it does on SLOOP.

**Fix:** turning on Play through the iPad sets USB LEVEL to FIXED on Skiff, through MENU_SET id 10, value 1, unless it's already FIXED. The menu then says: "USB LEVEL is FIXED: turn the FM-1's MASTER down to quiet its speaker. The iPad keeps the full level". If the FM-1 refuses, the menu says that, with the code. Confirmed on skiff-sim (Skiff's own editor code): set, read back and restored. **Not verified:** whether Scott's iPad sees the audio input at all. If the menu says "No sound from the FM-1 over USB", it's the USB audio device itself, not this setting, and that needs his iPad to look into.

## 3. No progress for lanes that loop sooner

**Cause:** not built. The only per-lane mark was a fixed 24 pt bar on the playing block, saying which entry plays and nothing about how far through it is. The song playhead line wraps at the song's end, so it says nothing about a lane that loops sooner.

**Fix:** a bar under the block each track plays, in the track's colour (shot 01, two moments a second apart). It fills once a pass, the unit an entry's REPS counts, from the clock-counted playhead: the steps into the pass plus how far into the step, over LENGTH (`CountedPlayhead.passProgress`). "Playing now" is in the block's VoiceOver label. Reduce Motion: four updates a second instead of every frame.

**What the bar can't show:** which of a block's passes is playing. LIST2 reports the entry, not the pass, so the bar spans the whole block and fills once per pass. It inherits the counted model's limits too: no Start seen (joining mid-play) means no bar, a RAND track has no bar between its notes, and the song moving to the next entry isn't modelled (the entry comes from LIST2, which Jib polls).

## Pre-flight (design-standards)

- Colour: the bar is the track's colour on the lane (5.5:1 or better), with its unfilled part at 30%. The entry is still marked by position, under its block, not by colour alone.
- Size: 3 pt high in the lane's 6 pt bottom margin. Not interactive.
- Motion: progress, not decoration; slowed with Reduce Motion.
- The audio menu's lines: what happened and what to do, and a refusal names its code.
- Not checked: the real FM-1 (Scott's to try), VoiceOver running, the iPhone (Arrange is iPad-only).

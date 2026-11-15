---
component: Sampler
lifecycle: built
status:
  requirements: draft      # written 2026-11-14 from code, notes and device checks; not yet read by Scott
  design: draft
  build-notes: draft
  usage: draft
code:
  - ios/FM1/SamplerPanel.swift     # SamplerPanel, SamplerRequest, the replace confirm, FlipFace (SLOOP)
  - ios/FM1/SampleRecorder.swift   # the microphone, the take, trim, Drive, what the slot gets
  - ios/FM1/SampleSlots.swift      # Your samples (SampleSlotList), StopsSongNote
  - ios/FM1/SongTab.swift          # the sampler in the editor's place (Skiff)
  - ios/FM1/AppView.swift          # the sampler from Your samples, over a dimmed page
  - ios/FM1/TrackMenu.swift        # Record sample…
boards: []
figma:
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-346   # Sampler REC key
  - https://www.figma.com/design/RLZwUtsJDEfLyIZGXIlM9n?node-id=19-356   # Sample slot key
---

# Sampler

> **SLOOP removed (decision 43, 2026-11-15).** Lupe speaks Skiff only; lines below about SLOOP describe what it did until then (tag `sloop-archive-2026-11-15`, `design/archive/sloop.md`).

*iPad only. The phones leave samples to the iPad (decision 25, 2026-11-13; phone scope 2026-11-12).*

## 1. Requirements

### Purpose and scope

Gets a sound into one of the FM-1's user sample slots and puts a track on it: record with the iPad's microphone or import a file, trim it, hear it as the FM-1 will have it, save it to a slot. Beside it, **Your samples** lists the slots so any one can be played on the track, heard on the iPad, refilled or cleared.

It is not a sample editor beyond trimming, and not a library: the slots live on the FM-1, and nothing on the iPad keeps a copy.

Where it sits: `structure-map.md`, the Tabs table (Sampler, in the editor's place) and "Your samples".

### Anatomy

Names as in the code.

- **sampler** (`SamplerPanel`): the panel.
- **header**: the track chip, the title, the source line, **Cancel**.
- **screen**: a well like the FM-1's screen. **top line** (what's happening, the length), **waveform**, **trim handles** (Start, End), **footer** (the format facts on the left, progress, a message or how far the take was raised on the right).
- **stops-song note** (`StopsSongNote`): the line that says Skiff's sound stops for a slot write.
- **controls**: the **REC key**, the **play key**, **Import file…**, the **input meter** (no take) or **Drive** (a take), the **slot picker** ("Slots" or "Save to" and a **slot key** per slot).
- **replace confirm**: in the controls' place. ▶ (hear what's there), the slot and its sound named, **Keep it**, **Replace**.
- **Your samples** (`SampleSlotList`): the stops-song note, then per slot a **use key** (full) or an **empty key**, ▶, then **Record…**, **Import file…**, **Clear…**, and a **problem line**.

### Requirements

**Functional**
- **F1** Two ways in. A synth track's hold menu › Record sample… opens the sampler in the editor's place. A slot's Record… or Import file… in Your samples opens it from the bottom over a dimmed page, for that slot.
- **F2** It opens on the slot asked for, or the first empty one.
- **F3** Import file… takes WAV, AIFF and M4A from Files, made mono at the slot's rate; nothing else is offered (Scott, 2026-11-08).
- **F4** Recording uses the iPad's own microphone, never the FM-1's USB input. Playing through the iPad is held off while the sampler is open, so its speaker can't feed the microphone.
- **F5** What plays on the iPad is what the FM-1 will get: the trimmed take, normalised and driven.
- **F6** Saving uploads the take, puts the track on Sample at that slot, and closes the sampler.
- **F7** Your samples sits in the Sounds panel's engine list under User presets, and under the Sample engine's sets (structure map, "Your samples"). A synth track's own sound only.
- **F8** Record sample… and the slot rows are absent or off on a drum track.

**States**
- **S1** No take: the waveform says how to start ("Tap the red key and play, or import a file. Up to N seconds."); play is off; the input meter moves with the microphone; the slot keys show what each holds and can't be tapped ("Slots").
- **S2** Recording: the REC key shows its stop square; the top line counts up against a slot's length; the waveform spans the whole slot; Import file… is off. It stops by itself at a slot's length.
- **S3** A take: the trim handles sit round the sound; bars outside them take the empty-step colour; the top line says "TAKE · SAVE IT TO A SLOT" and the trimmed length, or "… OF … · A SLOT HOLDS …" when the take is longer; Drive replaces the meter; the slot keys glow in the track colour and the label reads "Save to".
- **S4** Playing the take: the play key shows stop.
- **S5** Reading a file: "Reading the file…" in the waveform, a spinner on Import file….
- **S6** Saving: the top line says "SAVING TO slot", the footer counts "SENDING TO FM-1 n%"; the picked slot stays raised, the others go flat; Cancel and every key are off.
- **S7** Replace confirm: the controls give way to it, in place.
- **S8** Reading a slot back: ▶ spins.
- **S9** A problem in the footer, upper case: "THE FM-1 ISN'T CONNECTED", "TOO LONG FOR A SLOT: TRIM IT", "NOTHING TO SEND: RECORD A TAKE", "THE FM-1 REFUSED IT (stage rc)", "THE FM-1 DIDN'T ANSWER: TRY AGAIN", "LUPE CAN'T READ THAT FILE: WAV, AIFF OR M4A", "THAT FILE IS SILENT".
- **S10** No microphone: the waveform says "Lupe can't use the microphone. Turn it on in Settings › Lupe."
- **S11** Stops-song note (Skiff only): a plain line while stopped; while playing, a warning icon in the caution colour and the text at full strength. In the sampler it shows only with a take and no confirm up.
- **S12** Your samples, a full slot: the use key with its sound's name and size, lit (LED and latched face) while the track plays it.
- **S13** Your samples, an empty slot: a dashed key, "Empty · Record or import a sound"; no ▶, no Clear….
- **S14** SLOOP: four slots, no ▶ anywhere, no stops-song note.
- **S15** Offline: Your samples' Record…, Import file… and Clear… are off.

**Behaviour**
- **B1** A long file starts trimmed to its first slot's length of sound; the handles never sit further apart than a slot holds, or closer than a short minimum.
- **B2** When recording stops, the handles go to where the sound starts and ends.
- **B3** Drive pushes quiet parts up without raising the peak; a change while the take plays starts it again so it's heard at once.
- **B4** With a take, tapping an empty slot saves at once.
- **B5** Tapping a full slot opens the replace confirm; nothing is sent until Replace. A double tap only opens the confirm (`DESIGN.md`, confirm in place).
- **B6** ▶ in the confirm hears what the slot holds (Skiff), read once and kept for the session.
- **B7** Keep it, or VoiceOver's scrub, puts the keys back; nothing sent.
- **B8** The slot is named on the FM-1 after an imported file (the FM-1 shows its first letters), else after the slot.
- **B9** Cancel closes the sampler and lets go of the microphone; it is off while saving.
- **B10** Skiff stops the song for a write or a read-back; Lupe starts it again after. `[open]` Where the song starts again (pattern start, or where it was): device check `2026-11-11-sampler-skiff.md` 2, not yet run.
- **B11** Opened from the hold menu with the editor shut, the editor opens to Half to hold it.
- **B12** Your samples: tapping a full slot's use key puts the track on that slot.
- **B13** Your samples: ▶ reads the slot back and plays it on the iPad; one slot at a time; tapped again, stops.
- **B14** Your samples: Clear… asks in place at the finger, naming the slot and its sound; confirmed, the slot is erased.

**Content**
- **C1** Titles: "Record a sample" (microphone), "Import a sound" (a file). Source line: "Track n · <device> microphone" or the file's name.
- **C2** Footer facts: "22 kHz ONE-SHOT ROOT C4"; "RAISED n dB", or "RAISED n dB · NOISE CAME UP TOO" when it came up a lot.
- **C3** Replace confirm: "USRn holds “Name”", then "The FM-1 keeps no other copy." with "▶ hears it first." (Skiff) or, while playing, "Hearing it or replacing it stops the song; Lupe starts it again after." Buttons "Keep it" and "Replace “Name”".
- **C4** Stops-song note: stopped, "<what> stops the FM-1's sound for a few seconds."; playing, "The song is playing. <what> stops it and the FM-1's sound for a few seconds; Lupe starts it again after."
- **C5** Clear confirm: "Clear USRn “Name”", caption "Erased from the FM-1, which keeps no copy." (plus the song stopping, while playing).
- **C6** Problem lines in Your samples: "This FM-1 can't send its samples back, so they can't be heard here." / "The FM-1 didn't send it. Check the cable and try again."
- **C7** Slot names are the firmware's: Skiff's USR1–3, SLOOP's SMPL1–4.

**Accessibility**
- **A1** REC key: "Record", "Record again" or "Stop recording". Play key: "Play the take" or "Stop".
- **A2** Trim handles: "Start" and "End", value in seconds; adjustable by swipes a tenth of a second at a time.
- **A3** Waveform: "No take yet" or "Take, n seconds after trimming".
- **A4** Slot keys: "USRn, name" or "USRn, empty"; hint "Saves the take here and plays it on track n" or "Asks before replacing what's here".
- **A5** Replace: "Replace Name with your take", hint "Can't be undone". The scrub leaves the confirm as Keep it does (accessibility F17).
- **A6** From Your samples, the sampler is modal over the dimmed page and the scrub closes it (F16).
- **A7** The header is one header element; the input meter is hidden.
- **A8** Nothing by colour alone: the stops-song warning has an icon and "Warning:" in its label; a used slot has its LED, a latched face and the selected trait.
- **A9** Reduce Motion: the slots' glow holds still; the panel fades instead of moving.
- **A10** `[open]` The trim handles move only by dragging for a finger (accessibility P6). Proposed: a tap on the waveform moves the nearer handle, or nudge keys beside the handles.
- **A11** `[open]` The input level isn't read to VoiceOver; the meter is hidden and nothing replaces it.
- **A12** `[review]` VoiceOver on Your samples and the confirm: release pass (`2026-11-11-sampler-skiff.md`, "Not covered here").

**Integration**
- **I1** Skiff uses the same sample commands as SLOOP (SMP_BEGIN, WRITE, END, ERASE, INFO), with three slots, not four; user slots are SET 5–7 on Skiff. The slot count comes from SMP_INFO (batch list item 5).
- **I2** ▶ reads a slot back through Skiff's backup objects 32–34. SLOOP's sample commands only write.
- **I3** Skiff stops its transport for a sample write or read-back (`ed_flash_stop`) and its sound for a few seconds while flash is erased. SLOOP keeps playing.
- **I4** A cut upload leaves the slot empty, never half a sound. Device check `2026-11-11-sampler-skiff.md` 8, not yet run.
- **I5** Samples aren't in a project: Projects saves the music, not the slots.
- **I6** Shown only with the `.samples` capability (both drivers grant it now).
- **I7** `[open]` The iPhone draws the sampler full screen today (`PhoneAppView`, the shared track menu's Record sample…). Decision 25 leaves samples to the iPad; the consolidation plan doesn't say whether the iPhone loses it.

**Device checks.** Record sample from the hold menu: `2026-11-09-lupe-batch-2026-11-06.md` 2–4 passed (Scott, 2026-11-11). Your samples, import, replace, erase, read-back: `2026-11-11-sampler-skiff.md` 1–14, not yet run.

### Ruled out

- Drag and drop to bring a file in: Import file… only (Scott, 2026-11-08).
- A Normalize button: every upload already normalises; Drive instead (session log, 2026-11-03/04).
- A grid flip on Skiff: the sampler takes the editor's place in the same tinted panel; the pads and the strip stay put (batch list item 5, 2026-11-09).
- A system dialog before replacing a slot: in place, naming the slot's sound (2026-11-10, `DESIGN.md`).
- Samples on the phones: the iPad keeps samples (decision 25, 2026-11-13).

### Out of scope

- The track's hold menu: see `hold-menus.md`.
- The Sounds panel around Your samples (engines, presets, user sounds): see `sounds-panel.md`.
- FREE TAKE's picker, which uses the same place in the editor: `FreeTakePicker.swift`.
- SLOOP's sampler face (the grid turning over, `FlipFace` in `SloopSong.swift`).

## 2. Design

No board. Screenshots of the built slot flow: `qa/sampler-skiff-2026-11-11/`.

Motion follows `DESIGN.md`. Particular to the sampler:
- From the hold menu it comes in from the right and pushes the editor out to the left, back the other way on Cancel or a save; the pads above stay put (Scott, 2026-11-09, `SongTab.swift`).
- From Your samples it slides up from the bottom over a dimmed page.
- The slot keys glow in a slow pulse once a take waits: they're the next step (Scott, 2026-11-09).
- The replace confirm rises in the controls' place; the keys fade.

### Decision log

- 2026-11-03: direction A with C's screen: the take as one big waveform in the track's colour inside a small screen like the FM-1's (`SamplerPanel.swift`).
- 2026-11-08: after a take the slots glow and are the save keys; an empty one writes at once, a full one asks (batch list item 5, 7085285).
- 2026-11-08: Import file… takes WAV, AIFF and M4A; no drag and drop (Scott).
- 2026-11-09: the sampler comes in from the right in the editor's place (Scott).
- 2026-11-10: the replace confirm is in place, red-outlined, naming the sound.

## 3. Build notes

- The sampler holds `AudioThrough.suspended` while open; Your samples does the same while ▶ plays.
- `SampleRecorder.shape` is what Play plays and what goes to the slot, so the screen and the FM-1 agree.
- The slot keys' glow and the panel's timings are hard-coded, not in Labs.
- Code left over: `SamplerPanel`'s doc comment and `TrackMenu`'s still mention a "Use on track" key, and `canUse` is defined but unused. The batch list's item 5 says the editor "slides down and the sampler slides up"; the code and `2026-11-09-perform-grid-map.md` 13 have it come in from the right.

### Decision log

- 2026-11-09: Lupe's sample commands and format checked against Skiff's byte for byte before enabling (batch list item 5).

## 4. Usage

- To get a new sound onto a track, Record sample… from its hold menu. To manage the slots, Your samples.
- Anything else that writes a slot must say first that Skiff's sound stops (`StopsSongNote`) and ask before replacing a full slot.
- Not for drum tracks or a pad's or block's own sound.

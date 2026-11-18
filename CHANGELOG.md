# Changelog

The Android and iPad/iPhone apps are released on their own schedules and needn't share a version (Scott,
2026-11-18). `VERSION` holds the version of the next release; `tools/set-version.sh` sets it. Each app keeps its own
build number.

## iPad and iPhone (not released yet)

**Both**
- Messages follow one rule (`design/DESIGN.md` › Messages). One strip at the foot holds one message over one ongoing
  state. Refusals and Undo stay until dealt with, with no timers. Confirmations stay 4 s. Every message is announced.
- Values in the sound panel hold still while they change.
- Projects say where the music lives and where a save goes. Playing now has Save (back where it came from) and Save
  to… (this device, or one of the FM-1's four slots). Each slot can be copied to the device. A line shows how full the
  pattern pool is and how much of it only the slots hold.
- The iPhone keeps its own project files, as the iPad does.

**iPad**
- The Patterns sheet: every kept pattern, where it's used, and clearing several at once. When all 64 are taken, an empty
  pad offers Recycle an unused pattern and Put a kept pattern here.
- The sound panel's page tabs stay inside the panel on six-page families.

**iPhone**
- Undo shows after Clear all steps.
- VoiceOver hears when the FM-1 disconnects and comes back.

## Android 0.3.0 (2026-11-18)

The hybrid redesign: Lupe's tokens with M3 Expressive mechanisms (`design/hybrid-ui/`).

- Pads, Edit, Timeline and Mix are redrawn. Pads change shape to show their state; the selected track's head and badge
  square; Edit grows out of the pad you open.
- Edit is rebuilt: notes drag, resize by their right edge and lift with a long hold; the step panel follows the FM-1's
  knobs; undo and redo; the FM-1's held keys light up on the phone.
- Mix has effect cards for Delay, Reverb, Chorus and Global.
- Projects on the phone: Save (back where it came from), Save to… (the phone or one of the FM-1's four slots), Copy to
  phone, and a line for how full the pattern pool is.
- A speaker key in the header plays the FM-1 through the phone. The song menu is Projects…, Settings…, Patterns…,
  Firmware….
- Lupe opens when the FM-1 is plugged in, and reconnects after the phone sleeps.
- Dragging a pad to the top edge clears its steps or deletes its pattern; Delete is red.
- Messages follow one rule in one strip at the foot. Undo stays until the next edit. Values hold still while they change.
- Panels and tab changes run without dropped frames (a tab change drops at most three, from one 100–200 ms frame).
- Settings and Projects are cut to the essentials; Labs is gone.

## Android 0.2.1 (2026-11-16)

- The Skiff-Lupe offer on Skiff 2.6 says plainly what Skiff-Lupe adds, the screen link most of all.

## Android 0.2 (2026-11-16)

- Works with Skiff 2.6.
- The firmware cards' buttons show in full.
- An install that was cut off can be finished from the phone.

## Android 0.1 (2026-11-16)

- The first public build.

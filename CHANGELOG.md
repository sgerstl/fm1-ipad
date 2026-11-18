# Changelog

Lupe has one version for the iPad, iPhone and Android apps (from 0.3.0). It lives in `VERSION`; `tools/set-version.sh`
sets it. Each app keeps its own build number. Before 0.3.0 only the Android app was numbered.

## 0.3.0 (not released yet)

**All apps**
- Messages follow one rule (`design/DESIGN.md` › Messages). One strip at the foot holds one message over one ongoing
  state. Refusals and Undo stay until dealt with, with no timers. Confirmations stay 4 s. Every message is announced.
- Values in the sound panel hold still while they change.
- Projects say where the music lives and where a save goes. Playing now has Save (back where it came from) and Save
  to… (this device, or one of the FM-1's four slots). Each slot can be copied to the device. A line shows how full the
  pattern pool is and how much of it only the slots hold.
- The iPhone and Android keep their own project files, as the iPad does.

**iPad**
- The Patterns sheet: every kept pattern, where it's used, and clearing several at once. When all 64 are taken, an empty
  pad offers Recycle an unused pattern and Put a kept pattern here.
- The sound panel's page tabs stay inside the panel on six-page families.

**iPhone**
- Undo shows after Clear all steps.
- VoiceOver hears when the FM-1 disconnects and comes back.

**Android**
- Undo stays until the next edit instead of 6 s.
- The scene row's refusal moves into the strip, so two refusals never show at once.

## Android 0.2.1 (2026-11-16)

- The Skiff-Lupe offer on Skiff 2.6 says plainly what Skiff-Lupe adds, the screen link most of all.

## Android 0.2 (2026-11-16)

- Works with Skiff 2.6.
- The firmware cards' buttons show in full.
- An install that was cut off can be finished from the phone.

## Android 0.1 (2026-11-16)

- The first public build.

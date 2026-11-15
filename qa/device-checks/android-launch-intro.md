# Device check: the Android launch intro (claude/android-p4-sound-pages-7e2a23), 2026-11-15

Written by the session that built it (see `CLAUDE.md`, rule 2). The intro is a port of the iPhone's (`ios/FM1/LaunchIntro.swift`, prototype `design/brand/intro-prototype.html`). **It has not been seen on a screen**: the Mac was under a load average of about 50 and the emulator would not boot to a usable state, so the drawing code is checked only by its maths (IntroMathTest: the phases add to the prototype's 2.9 s, the figure, the beam, the trail's age and colour). Compare it with the iPhone build before calling it right.

**Build and install** (the main session installs): `./gradlew :app:installDebug`.

| # | Do this | You should see | Result |
|---|---|---|---|
| 1 | Swipe Lupe away, launch it from the home screen. | The system splash (the icon on #0A0A0B) hands straight over to the intro with no jump: the icon grows past the screen (0.42 s) while the room goes to black, a white line opens, one pass of the figure draws itself with its trail cooling from white to dim grey (1.06 s), the beam settles to the icon's rest, "lupe" fades in, a hold, then the picture squashes to a line, pinches to a dot and blips out as the app fades up. About 2.9 s. One soft flash only. | ☐ pass ☐ fail: |
| 2 | Launch and tap during the intro. | It goes to the app at once. | ☐ pass ☐ fail: |
| 3 | Settings › Accessibility › Remove animations on; launch. | The finished logo fades in (0.28 s), stays, and crossfades to the app (1.94 s in all). No zoom, no trace. | ☐ pass ☐ fail: |
| 4 | Rotate or switch to another app and back during the intro. | No second intro on coming back. | ☐ pass ☐ fail: |
| 5 | **Frames against the iPhone**, at 0.0, 0.2, 0.5, 1.2, 1.7, 2.1 and 2.7 s: Android `adb shell am start -n com.scottgerstl.lupe/.MainActivity --ef introAt 1.2`; iPhone the same build's launch argument `-intro-at 1.2`. Screenshot both and lay them side by side. | The same picture at each time (the scope square, the trail's length and colour, the name's fade). Differences worth writing down: line widths (Android draws in px, the iPhone in points), the trail's colour at 0.5 and 1.2 s, where the wordmark sits, the squash. | ☐ pass ☐ fail: |

**Notes.** adb launches that pass `--es scenario` skip the intro (so screenshot scripts don't wait); `--ez intro false` skips it too. It shows on a cold start only. The wordmark and the icon art are the iPhone's own PNGs, so Michroma isn't needed at run time (the wordmark is an image on both). The system splash needs Android 12 or later (minSdk is 33). The first Compose frame after the splash can come a few ms late on a cold start: if there is a visible flash of the app's own background between the splash and the intro, say so.

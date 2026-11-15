# Third-party material in the Android app

## Material Symbols Rounded (the hold menu's choice icons)

`app/src/main/res/drawable/ms_*.xml` are Google's Material Symbols, Rounded style, weight 400, grade 0, fill 0, 24 px, converted from the
SVGs at `https://fonts.gstatic.com/s/i/short-term/release/materialsymbolsrounded/<name>/default/24px.svg` (fetched 2026-11-15) to Android
vector drawables (the SVG path unchanged under a group that moves its viewBox `0 -960 960 960` to `0 0 960 960`).

Licensed under the Apache License, Version 2.0: https://www.apache.org/licenses/LICENSE-2.0 . Source: https://github.com/google/material-design-icons

Which glyph stands for which choice (and the SF Symbol the iPhone uses for the same choice) is in `ui/shell/HoldIcons.kt`.

# Lupe's icon

An FM Lissajous figure traced on a scope screen, flat and white since 2026-11-08 (it was P1 green phosphor): the carrier against its modulator, drawn as a
scope in XY mode draws it. A white-hot beam at the head, the trace behind it brightest and fading as it cools, a
soft bloom, the faint full figure, and the scope's graticule. Scott's pick, 2026-11-05; the round (Orbit, Swell, real
FM waveforms, XY, Phosphor, then the phosphor colours) is in the vault's `Projects/Dev/fm1-ipad/index.md`, "Mark".

```sh
cd design/brand
python3 lupe_icon.py                                                       # lupe-icon.svg
NODE_PATH=~/.claude/skills/design-standards/node_modules node render_icon.mjs   # lupe-icon-1024.png (needs Chrome)
cp lupe-icon-1024.png ../../ios/FM1/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

The app uses one 1024 px icon and iOS scales it down. The graticule disappears below about 60 pt, which is fine:
the trace and the beam carry the small sizes. The trace is drawn with lighten blending, so overlapping pieces never
show seams.

**Android** (2026-11-13): an adaptive icon in `android/app/src/main/res`, `mipmap-anydpi-v26/ic_launcher.xml`. The
foreground is the 1024 px art scaled to 84 of the 108 dp layer at each density (`mipmap-*/ic_launcher_foreground.png`), on a
`#0A0A0B` background that matches the art's own black, so every launcher mask crops only the scope's dark margin and the
beam's head stays inside the 66 dp safe circle. No monochrome layer yet (Android's themed icons fall back to the full colour).

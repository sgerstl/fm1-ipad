# Lupe's launch intro (2026-11-05)

Source: the approved prototype, `design/brand/intro-prototype.html` on `refs/heads/lupe-icon` (read from the branch:
not merged here, since only a merge Scott asks for in his own words is mine to make). Port: `ios/FM1/LaunchIntro.swift`.

## Timings (PLANS.full, as the prototype computes them)

| | starts | lasts |
|---|---|---|
| zoom | 0 | 0.42 s |
| power-on flash | 0.42 | 0.22 s |
| one pass of the trace | 0.64 | 1.06 s |
| settle | 1.70 | 0.40 s |
| the name | (1.70 + 0.14) × 0.8 = 1.47 | 0.52 s |
| hold | 2.10 | 0.40 s |
| squash / pinch / blip | 2.50 / 2.62 / 2.72 | 0.12 / 0.10 / 0.18 s |
| the app | 2.90 | |

That's 2.9 s, not the 3.2 s the brief estimated. The prototype's own arithmetic gives 2.9.

## How it's drawn

The same geometry: S = 0.525 × the shorter side, the scope and the name centred as one group. The same figure:
x = sin(3t + 0.9 sin 2t), y = sin 2t, beam at 0.31. Graticule, faint floor figure, beam gradient, name size, glow,
the switch-off's line at oy + 0.66 S, all as the prototype draws them.

The prototype's phosphor is a canvas it cools every animation frame (10 % toward deep green, 5.5 % fainter, scaled
by 1 − ease while settling, none after). Jib draws each bit of trail from its age in those 60-a-second frames
(`coolFrames`, `paintTime`), so a frame at time t is the same at any frame rate. The settled trail is the same
picture the prototype's `settled()` makes for Reduce Motion.

## The rules

- Every cold launch: an overlay on the app's root. The app is built and the FM-1 session starts underneath from
  the first frame, so connecting isn't delayed.
- A tap anywhere skips to the app.
- Reduce Motion: the finished logo fades in (0.28 s), holds to 1.6 s, then crossfades to the app (0.33 s).
- One flash: the power-on bloom is the only bright change, once, under 3 a second (WCAG 2.3.1).
- The launch screen (`LaunchScreen-Info.plist`, merged into the Info.plist): the icon at home-screen size (83.5 pt
  iPad, 60 pt iPhone, rounded as the home screen does) on #0A0A0B.
- `-no-intro` skips it (layout checks); `-intro-at T` holds it at T seconds (comparing frames).

## Where I left the prototype, and why

- **The zoom's first frame is the launch screen.** The brief asks that the zoom start from exactly what was tapped.
  The prototype starts from an empty dark square, 0.16 × the shorter side, on black. So the zoom starts at the home
  screen's icon size with the icon's art showing, on #0A0A0B. As it grows, the art fades out within the first third
  and the room goes to the prototype's black. From there on it is the prototype's frame.
- **The name's face:** the system's light face, as the brief says, until the wordmark is chosen.

## Checked

`frames-0.15-0.58-1.2-2.3-2.66.png`: the iPad sim held at 0.15 (the zoom), 0.58 (the bloom), 1.2 (mid-trace), 2.3
(the logo and name), 2.66 (the pinch to a line).

Not checked: the prototype and the port side by side at the same instants (the prototype runs on wall-clock time,
with no way to hold a frame), the iPhone, a real cold launch on a device (the simulator's launch screen handover),
VoiceOver (the intro is one element, "Lupe", a button that skips).

## Pre-flight (design-standards)

Motion is the subject here: one flash (2.3.1), Reduce Motion's still logo, under 5 s with no loop and a skip on a tap
(2.2.2 doesn't apply below 5 s, and the tap is there anyway). Colours are the prototype's (P1 green on #0A0A0B, the
app's #F4F4F6 for the name). The name's contrast: #F4F4F6 on #0A0A0B ≈ 18:1. Layout: centred group, the
prototype's proportions. Tokens: the intro's colours are the brand's own, kept in the file beside the prototype's
values. Nothing interactive but the tap.

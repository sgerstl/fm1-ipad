#!/usr/bin/env python3
"""Lupe's app icon: an FM Lissajous figure traced on a scope screen in P1 green phosphor.

The figure is a carrier against its modulator (x = sin(3t + 0.9 sin 2t), y = sin 2t), drawn the way a scope in XY mode
draws it: a white-hot beam at the head, the trace behind it brightest and fading exponentially as it cools from
pale green-white to deep green, a soft bloom, the faint full figure still lit, and the scope's etched graticule.
Picked by Scott on 2026-11-05 (vault: Projects/Dev/fm1-ipad/index.md, "Mark").

  python3 lupe_icon.py            -> lupe-icon.svg (full bleed, square: iOS masks the corners)
  node render_icon.mjs            -> lupe-icon-1024.png, copied into the app's AppIcon set by install.sh
"""
import math

TAU = 2 * math.pi
C_OLD, C_FRESH = (0x0E, 0x6B, 0x1E), (0xC8, 0xFF, 0xB0)      # P1: deep green behind, pale green-white at the beam
FLOOR, GLOW = "#33FF66", "#55FF88"
BG = (0x0A, 0x0A, 0x0B)
STROKE = 2.8          # in a 100-unit square; a little heavier than the canvas boards so the 29 pt icon still reads
DECAY = 2.6           # how fast the trace fades behind the beam
BEAM_AT = 0.31        # where on the figure the beam sits (fraction of the loop)


def figure(steps=2400, r=28):
    pts = [(50 + math.sin(3 * t + 0.9 * math.sin(2 * t)) * r, 50 + math.sin(2 * t) * r)
           for t in (i / steps * TAU for i in range(steps + 1))]
    j = int(BEAM_AT * (len(pts) - 1))
    return pts[j:] + pts[1:j + 1]                       # the loop, ending at the beam


def path(p):
    return "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in p)


def trail(pts, width, seg=20):
    out, n = [], len(pts)
    for i in range(0, n - 1, seg):
        pos = i / n
        a = pos ** 2.2
        op = math.exp(-DECAY * (1 - pos))
        # the fade is mixed into the colour over the screen's black and drawn with lighten: overlaps keep the brighter piece,
        # so they never add up into stripes or darken what's under them
        c = "#%02X%02X%02X" % tuple(int(BG[k] + (C_OLD[k] + (C_FRESH[k] - C_OLD[k]) * a - BG[k]) * op) for k in range(3))
        out.append(f'<path d="{path(pts[i:i + seg + 1])}" fill="none" stroke="{c}" '
                   f'stroke-width="{width * (0.55 + 0.45 * pos):.2f}" stroke-linecap="round" stroke-linejoin="round" style="mix-blend-mode:lighten"/>')
    return "".join(out)


def graticule():
    lines = "".join(f'<line x1="{x}" y1="14" x2="{x}" y2="86"/>' for x in range(14, 87, 12))
    lines += "".join(f'<line x1="14" y1="{y}" x2="86" y2="{y}"/>' for y in range(14, 87, 12))
    ticks = "".join(f'<line x1="{14 + 2.4 * k:.1f}" y1="48.8" x2="{14 + 2.4 * k:.1f}" y2="51.2"/>' for k in range(31))
    ticks += "".join(f'<line x1="48.8" y1="{14 + 2.4 * k:.1f}" x2="51.2" y2="{14 + 2.4 * k:.1f}"/>' for k in range(31))
    return (f'<g stroke="{GLOW}" stroke-opacity="0.10" stroke-width="0.35">{lines}</g>'
            f'<g stroke="{GLOW}" stroke-opacity="0.16" stroke-width="0.35">{ticks}</g>')


def svg(size=1024):
    pts = figure()
    x, y = pts[-1]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 100 100">
<defs>
  <filter id="bloom" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="1.6"/></filter>
  <radialGradient id="beam"><stop offset="0" stop-color="#FFFFFF"/><stop offset="0.18" stop-color="#FFFFFF" stop-opacity="0.95"/>
    <stop offset="0.38" stop-color="{GLOW}" stop-opacity="0.85"/><stop offset="1" stop-color="{GLOW}" stop-opacity="0"/></radialGradient>
</defs>
<rect width="100" height="100" fill="#0A0A0B"/>
{graticule()}
<path d="{path(pts)}" fill="none" stroke="{FLOOR}" stroke-opacity="0.2" stroke-width="{STROKE * 0.8:.2f}"/>
<g filter="url(#bloom)" opacity="0.9" style="mix-blend-mode:lighten">{trail(pts, STROKE * 2.2)}</g>
{trail(pts, STROKE)}
<circle cx="{x:.2f}" cy="{y:.2f}" r="11" fill="url(#beam)"/>
<circle cx="{x:.2f}" cy="{y:.2f}" r="2.4" fill="#FFFFFF"/>
</svg>'''


if __name__ == "__main__":
    open("lupe-icon.svg", "w").write(svg())
    print("wrote lupe-icon.svg")

# Board 41: track lanes in the Pads grid (Scott, 2026-11-09). Static HTML for the Lupe canvas (Design type).
# OUT=<canvas project folder> python3 lanes.py
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PAD, EMPTY, WELL, TEXT, T2, T3, ON = '#0D0D0F', '#26262B', '#2A2A30', '#111114', '#EDEDF0', '#A1A1AA', '#71717A', '#101012'
EDGE = '#0A0A0C'
def mix(a, b, k):
    A = [int(a[i:i+2], 16) for i in (1, 3, 5)]; B = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return '#' + ''.join('%02X' % round(x + (y - x) * k) for x, y in zip(A, B))
COL = {3: '#FFBF00', 4: '#9580FF', 5: '#FF6FAE', 6: '#A3E635', 1: '#FF5A36', 2: '#22C3B4'}
NAME = {1: 'Acid', 2: 'Pad', 3: 'Pulse Ld', 4: 'Drum Kit', 5: 'Usr1', 6: 'Drum Kit'}
TINT = lambda t: mix(PAGE, COL[t], 0.24)
GREY = {'bold': '#1E1E23', 'right': '#17171B', 'quiet': '#121215'}

def box(x, y, w, h, style=''):
    return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{style}"></div>'
def text(x, y, s, size, colour, weight=400, w=None):
    ws = f'width:{w}px;' if w else ''
    return f'<div style="position:absolute;left:{x}px;top:{y}px;{ws}font-size:{size}px;font-weight:{weight};color:{colour};line-height:1.15;white-space:nowrap;">{html.escape(s)}</div>'
def speaker(x, y, muted=False, colour=TEXT):
    p = '<path d="M3 9h4l5-4v14l-5-4H3z" fill="%s"/>' % colour
    p += ('<path d="M16 9l5 6M21 9l-5 6" stroke="%s" stroke-width="2" stroke-linecap="round"/>' if muted
          else '<path d="M15.5 9.5a4 4 0 0 1 0 5M18 7a7.5 7.5 0 0 1 0 10" stroke="%s" stroke-width="2" fill="none" stroke-linecap="round"/>') % colour
    return f'<svg style="position:absolute;left:{x}px;top:{y}px" width="24" height="24" viewBox="0 0 24 24" aria-hidden="true">{p}</svg>'

def tab_path(cx, cy, w, h, r, drop, tw, th, tr, turn, up):
    """PadsGrid's PadTabShape: the pad's cell (corners r), the stem down `drop`, the tab (corners tr), the inner turn."""
    H = h + drop; W = max(tw, w + turn + tr)
    pts = [('M', r, 0), ('L', w - r, 0), ('A', r, w, r), ('L', w, H - turn), ('Q', w, H, w + turn, H), ('L', W - tr, H),
           ('A', tr, W, H + tr), ('L', W, H + th - tr), ('A', tr, W - tr, H + th), ('L', tr, H + th), ('A', tr, 0, H + th - tr),
           ('L', 0, r), ('A', r, r, 0)]
    def tx(x, y): return (cx + x, cy + (h - y if up else y))
    d = ''
    for p in pts:
        if p[0] in 'ML':
            x, y = tx(p[1], p[2]); d += f'{p[0]}{x:.1f} {y:.1f} '
        elif p[0] == 'A':
            x, y = tx(p[2], p[3]); d += f'A{p[1]} {p[1]} 0 0 {0 if up else 1} {x:.1f} {y:.1f} '
        else:
            x1, y1 = tx(p[1], p[2]); x, y = tx(p[3], p[4]); d += f'Q{x1:.1f} {y1:.1f} {x:.1f} {y:.1f} '
    return d + 'Z'

def panel(px, py, title, note, rows, sel, half=False, lanes=None, selLane=True, controls=None, edge=None, selEdge=None):
    """rows: [(track, [cells])]; cell: ('on'|'p'|'e', number). lanes: a grey for the unselected rows, or None."""
    headW, gapH, cols, pw, pg = 232, 12, 5, 130, 6
    rh, rg = (42, 4) if half else (132, 8)
    W = headW + gapH + cols * pw + (cols - 1) * pg
    Hh = len(rows) * rh + (len(rows) - 1) * rg
    out = [text(px, py, title, 17, TEXT, 600), text(px, py + 24, note, 13, T2)]
    gy = py + 60
    clip_top = gy - (150 if controls == 'up' else 20)
    out.append(f'<div style="position:absolute;left:{px - 20}px;top:{clip_top}px;width:{W + 40}px;height:{Hh + (gy - clip_top) + 170}px;overflow:hidden;">')
    ox, oy = 20, gy - clip_top                                         # inside the clip
    gx = ox + headW + gapH
    # lanes first: a band each row from the head's left to past the grid's edge
    for k, (t, cells) in enumerate(rows):
        y = oy + k * (rh + rg)
        if t == sel and selLane:
            out.append(box(ox, y, W + 40, rh, f'background:{TINT(t)};border-radius:{8 if half else 16}px 0 0 {8 if half else 16}px;'))
        elif lanes:
            out.append(box(ox, y, W + 40, rh, f'background:{lanes};border-radius:{8 if half else 16}px 0 0 {8 if half else 16}px;'))
        elif t == sel:
            out.append(box(ox, y, headW, rh, f'background:{TINT(t)};border-radius:{10 if half else 12}px;'))   # today's head tint
    cellR = 8 if half else 16; border = 4 if half else 8
    sk = [k for k, (t, _) in enumerate(rows) if t == sel][0]
    sy = oy + sk * (rh + rg)

    def cell(k, t, cells, i, selected):
        y = oy + k * (rh + rg)
        onSel = t == sel and selLane
        kind, n = cells[i] if i < len(cells) else ('e', None)
        x = gx + i * (pw + pg)
        fx, fy, fw, fh, fr = (x + border, y + border, pw - 2 * border, rh - 2 * border, cellR) if selected else (x, y, pw, rh, cellR)
        if kind == 'e':
            e = (selEdge if onSel else edge) or EMPTY
            out.append(box(fx, fy, fw, fh, f'border:1px solid {e};border-radius:{fr}px;'))
        else:
            ring = f'box-shadow:inset 0 0 0 3px {COL[t]};' if selected else ('box-shadow:inset 0 0 0 2px #EDEDF0;' if kind == 'on' else f'box-shadow:0 2px 0 {EDGE};')
            out.append(box(fx, fy, fw, fh, f'background:{PAD};border-radius:{fr}px;{ring}'))
        lx, ly = fx + (8 if half else 14), fy + 12
        letter = 'ABCDE'[i]
        if half:
            out.append(text(lx, fy + fh / 2 - 8, letter, 12, T2, 600))
            if kind != 'e': out.append(text(lx + 16, fy + fh / 2 - 9, f'{n:02d}', 15, TEXT, 700))
        else:
            out.append(text(lx, ly, letter, 15, T2, 600))
            if kind == 'e':
                out.append(text(lx, ly + 24, 'Empty', 15, T2))
            else:
                out.append(text(lx, ly + 22, f'{n:02d}', 28, TEXT, 700))
                out.append(text(lx, ly + 58, 'On it' if kind == 'on' else '×1', 15, T2))

    # heads and every pad but the selected one
    for k, (t, cells) in enumerate(rows):
        y = oy + k * (rh + rg)
        hx = ox + 12
        if half:
            out.append(box(hx - 4, y + 8, 26, 26, f'background:{COL[t]};border-radius:7px;'))
            out.append(text(hx + 4, y + 13, str(t), 13, ON, 700))
            out.append(text(hx + 32, y + 13, NAME[t], 13, TEXT if t == sel else '#C4C4CC', 600 if t == sel else 400))
            out.append(box(ox + headW - 44, y + 3, 36, 36, f'background:{PAD};border-radius:8px;'))
            out.append(speaker(ox + headW - 38, y + 9))
        else:
            out.append(box(hx, y + 12, 26, 26, f'background:{COL[t]};border-radius:7px;'))
            out.append(text(hx + 8, y + 17, str(t), 13, ON, 700))
            out.append(text(hx + 36, y + 16, NAME[t], 15, TEXT, 600))
            out.append(text(hx, y + 48, f'A · {cells[0][1]:02d}', 13, '#C4C4CC'))
            out.append(box(ox + headW - 80, y + 12, 72, 52, f'background:{PAD};border-radius:8px;box-shadow:0 2px 0 {EDGE};'))
            out.append(speaker(ox + headW - 56, y + 26))
        for i in range(cols):
            if not (t == sel and i == 0):
                cell(k, t, cells, i, False)

    # the selected pad's tint and its track controls, over the pads (one colour with its lane: one shape)
    if controls:
        up = controls == 'up'
        d = tab_path(gx, sy, pw, rh, cellR + border, 8, 396, 132, 14, cellR + 8, up)
        ty = (sy - 8 - 132) if up else (sy + rh + 8)
        # the shadow from the controls' box alone, not the pad's tint (on a lane that read as a seam), then the shape
        out.append(box(gx, ty, 396, 132, f'background:{TINT(sel)};border-radius:14px;box-shadow:0 12px 28px rgba(0,0,0,0.6);'))
        out.append(f'<svg style="position:absolute;left:0;top:0;overflow:visible" width="1" height="1" aria-hidden="true"><path d="{d}" fill="{TINT(sel)}"/></svg>')
        labels = [('PITCH', '0.0'), ('TONE', '55%'), ('DECAY', '50%'), ('SNAP', '50%'), ('LEVEL', '76'), ('STEPS', '16'), ('PAN', '0')]
        for j, (lab, v) in enumerate(labels):
            r2 = j >= 4
            tx = gx + 8 + ((j - 4) if r2 else j) * 96; tyy = ty + 8 + (60 if r2 else 0)
            out.append(box(tx, tyy, 92, 56, f'background:{WELL};border-radius:6px;overflow:hidden;'))
            out.append(text(tx + 10, tyy + 7, lab, 11, T2))
            out.append(text(tx + 10, tyy + 24, v, 20, TEXT, 600))
            out.append(box(tx, tyy + 53, 92 * (0.3 + 0.1 * j), 3, f'background:{COL[sel]};'))
    else:
        out.append(box(gx, sy, pw, rh, f'background:{TINT(sel)};border-radius:{cellR + border}px;'))
    cell(sk, sel, rows[sk][1], 0, True)
    out.append('</div>')
    return ''.join(out), W, Hh

FULL = [(3, [('on', 24), ('e', 0), ('e', 0), ('e', 0), ('e', 0)]),
        (4, [('on', 36), ('p', 37), ('e', 0), ('e', 0), ('e', 0)]),
        (5, [('on', 39), ('p', 40), ('p', 41), ('e', 0), ('e', 0)]),
        (6, [('on', 34), ('p', 42), ('p', 43), ('p', 44), ('e', 0)])]
HALF = [(1, [('on', 1), ('p', 2), ('p', 3), ('p', 2), ('p', 3)]), (2, [('on', 5), ('p', 6), ('p', 7), ('e', 0), ('e', 0)]),
        (3, [('on', 24), ('e', 0), ('e', 0), ('e', 0), ('e', 0)]), (4, [('on', 36), ('p', 37), ('e', 0), ('e', 0), ('e', 0)]),
        (5, [('on', 39), ('p', 40), ('p', 41), ('e', 0), ('e', 0)]), (6, [('on', 34), ('p', 42), ('p', 43), ('p', 44), ('e', 0)])]
UP = [(3, FULL[0][1]), (5, FULL[2][1]), (6, FULL[3][1]), (4, FULL[1][1])]      # Drum Kit on the last row: controls up

CW, CH = 1000, 820
specs = [
    ('1 · Grey lanes, too bold (#1E1E23)', 'Stripes the grid: the rows read before the pads do.', FULL, dict(lanes=GREY['bold'])),
    ('2 · Grey lanes, about right (#17171B)', 'A surface step, not a line: the rows group, the pads stay on top.', FULL, dict(lanes=GREY['right'])),
    ('3 · Grey lanes, too quiet (#121215)', 'Barely there: only visible in the gaps under good light.', FULL, dict(lanes=GREY['quiet'])),
    ('4 · Selected lane only', 'One band says which track; the others stay as today.', FULL, dict(lanes=None)),
    ('5 · Selected lane meets the open controls', 'Lane, pad tint and controls one colour: one shape. Lanes 2.', FULL, dict(lanes=GREY['right'], controls='down')),
    ('6 · Controls open upward (last row)', 'The tab rises over the rows above; the lane carries on under the pad.', UP, dict(lanes=GREY['right'], controls='up')),
    ('7 · Empty-pad edges raised to 3:1', 'Today 1.36:1 on the page, 1.25 on lane 2, 1.04 on purple. Here #64646A / #76767C.', FULL, dict(lanes=GREY['right'], edge='#64646A', selEdge='#76767C')),
    ('8 · Half, grey lanes (about right)', 'Rows 42 pt: the lanes are most of what shows between pads.', HALF, dict(lanes=GREY['right'], half=True)),
    ('9 · Half, selected lane only, controls open', 'The tab hangs over three short rows, as today.', HALF, dict(lanes=None, half=True, controls='down')),
]
parts = []
for n, (title, note, rows, kw) in enumerate(specs):
    col, row = n % 3, n // 3
    px, py = 40 + col * CW, 200 + row * CH
    sel = 4
    h, _, _ = panel(px, py, title, note, rows, sel, **kw)
    parts.append(h)
BW, BH = 40 + 3 * CW, 200 + 2 * CH + 460
head = (text(40, 40, '41 · Track lanes in the Pads grid', 30, TEXT, 600)
        + text(40, 86, 'Each row a band the pads’ height, from the track head under every pad: the selected track’s in its tint, the others grey. Dark, 1:1 iPad points.', 15, T2)
        + text(40, 112, 'Measured: a grey lane is 1.04–1.17:1 against the page, a surface step, never an outline. Empty pads have no fill, so a lane shows through them; their 1 pt edge (already 1.36:1) needs raising (7).', 15, T2)
        + text(40, 138, 'Pick: an intensity (1–3), or lanes on the selected track only (4); and whether the empty-pad edge goes up (7).', 15, TEXT, 600))
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};font-family:-apple-system,\'SF Pro Text\',system-ui,sans-serif;font-variant-numeric:tabular-nums;overflow:hidden;">{head}{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe track lanes</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet><style>body{{margin:0}}</style></helmet>
{body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{BW},"height":{BH}}}}}'>
class Component extends DCLogic {{
  renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
'''
open(os.path.join(OUT, 'PadsLanes.dc.html'), 'w').write(doc)
print('PadsLanes.dc.html', BW, BH, len(doc))

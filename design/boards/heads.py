# Board 43: the track head, type, mute and solo, the carets, the Timeline/Pads toggle (Scott, 2026-11-09).
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, T3, ON, AMBER = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#C4C4CC', '#101012', '#FFB54A'
COL = {1: '#FF5A36', 2: '#22C3B4', 3: '#FFBF00', 4: '#9580FF', 5: '#FF6FAE', 6: '#A3E635'}
NAME = {1: 'Acid', 2: 'Pad', 3: 'Pulse Ld', 4: 'Drum Kit', 5: 'Piano', 6: 'Drum Kit'}
def mix(a, b, k):
    A = [int(a[i:i+2], 16) for i in (1, 3, 5)]; B = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return '#' + ''.join('%02X' % round(x + (y - x) * k) for x, y in zip(A, B))
TINT = lambda t: mix(PAGE, COL[t], 0.24)
def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{extra}">{html.escape(s)}</div>'
def speaker(x, y, muted, c):
    p = f'<path d="M3 9h4l5-4v14l-5-4H3z" fill="{c}"/>'
    p += (f'<path d="M16 9l5 6M21 9l-5 6" stroke="{c}" stroke-width="2" stroke-linecap="round"/>' if muted
          else f'<path d="M15.5 9.5a4 4 0 0 1 0 5M18 7a7.5 7.5 0 0 1 0 10" stroke="{c}" stroke-width="2" fill="none" stroke-linecap="round"/>')
    return f'<svg style="position:absolute;left:{x}px;top:{y}px" width="24" height="24" viewBox="0 0 24 24" aria-hidden="true">{p}</svg>'

def key(x, y, w, h, kind, on):
    """Mute or solo, flat: off a control grey; on pressed in (an inner shadow), mute white, solo amber."""
    inner = 'box-shadow:inset 0 2px 5px rgba(0,0,0,0.45);'
    bg = (TEXT if kind == 'm' else AMBER) if on else PAD
    o = [box(x, y, w, h, f'background:{bg};border-radius:8px;' + (inner if on else ''))]
    c = ON if on else TEXT
    if kind == 'm':
        o.append(speaker(x + w / 2 - 12, y + h / 2 - 12, on, c))
    else:
        o.append(tx(x, y + h / 2 - 11, 'S', 18, c, 700, f'width:{w}px;text-align:center;'))
    return ''.join(o)

def chip(x, y, s, t, muted, size_font):
    if muted:   # muted: the colour as an outline and the number, so a big number still says which track (Scott)
        return box(x, y, s, s, f'border:2.5px solid {COL[t]};border-radius:{s * 0.25:.0f}px;') + tx(x, y + s / 2 - size_font * 0.62, str(t), size_font, COL[t], 700, f'width:{s}px;text-align:center;')
    return box(x, y, s, s, f'background:{COL[t]};border-radius:{s * 0.25:.0f}px;') + tx(x, y + s / 2 - size_font * 0.62, str(t), size_font, ON, 700, f'width:{s}px;text-align:center;')

def lane(x, y, w, h, t, sel, tagH=None):
    c = TINT(t) if sel else PANEL
    if not tagH or tagH >= h:
        return box(x, y, w, h, f'background:{c};border-radius:16px 0 0 16px;')
    bx = x + 244
    d = (f'M{x + 19} {y} L{x + w} {y} L{x + w} {y + h} L{bx + 16} {y + h} A16 16 0 0 1 {bx} {y + h - 16} L{bx} {y + tagH + 16} '
         f'A16 16 0 0 0 {bx - 16} {y + tagH} L{x + 19} {y + tagH} A19 19 0 0 1 {x} {y + tagH - 19} L{x} {y + 19} A19 19 0 0 1 {x + 19} {y} Z')
    return f'<svg style="position:absolute;left:0;top:0;overflow:visible" width="1" height="1" aria-hidden="true"><path d="{d}" fill="{c}"/></svg>'

def pads(x, y, h, t, n=3):
    o = []
    for i in range(n):
        px = x + 244 + i * 134
        o.append(box(px, y, 128, h, f'background:{COL[t] if i == 0 else PAD};border-radius:16px;'))
        o.append(tx(px + 14, y + 12, 'ABC'[i], 15, ON if i == 0 else T2, 600))
        o.append(tx(px + 14, y + 34, f'{t * 7 + i:02d}', 26, ON if i == 0 else TEXT, 700))
    return ''.join(o)

def head_stacked(x, y, t, sel=False, muted=False, solo=False):
    """H1: number top-left, the entry it's on beside it, big; the name under; Mute over Solo down the right."""
    rh = 128
    o = [lane(x, y, 640, rh, t, sel), pads(x, y, rh, t)]
    o.append(chip(x + 12, y + 12, 44, t, muted, 22))
    o.append(tx(x + 66, y + 14, 'A · 01' if t != 2 else 'A · REST', 22, TEXT, 600, 'font-variant-numeric:tabular-nums;'))
    o.append(tx(x + 66, y + 42, 'pass 2 of 4', 12, T2))
    o.append(tx(x + 12, y + 68, NAME[t], 17, TEXT if not muted else T2, 600))
    o.append(box(x + 12, y + 96, 132, 4, f'background:#2A2A30;border-radius:2px;'))
    o.append(box(x + 12, y + 96, 70, 4, f'background:{COL[t]};border-radius:2px;'))
    o.append(tx(x + 12, y + 106, 'Then B · 02', 12, T2))
    o.append(key(x + 160, y + 12, 64, 50, 'm', muted))
    o.append(key(x + 160, y + 68, 64, 50, 's', solo))
    return ''.join(o)

def head_side(x, y, t, sel=False, muted=False, solo=False):
    """H2: the same, Mute and Solo side by side at the top right: the head's content stops at 96, the tag kept."""
    rh = 128
    o = [lane(x, y, 640, rh, t, sel, tagH=100), pads(x, y, rh, t)]
    o.append(chip(x + 12, y + 12, 44, t, muted, 22))
    o.append(tx(x + 66, y + 14, NAME[t], 17, TEXT if not muted else T2, 600))
    o.append(tx(x + 66, y + 36, 'pass 2 of 4', 12, T2))
    o.append(tx(x + 12, y + 62, 'A · 01' if t != 2 else 'A · REST', 22, TEXT, 600, 'font-variant-numeric:tabular-nums;'))
    o.append(box(x + 104, y + 74, 120, 4, f'background:#2A2A30;border-radius:2px;'))
    o.append(box(x + 104, y + 74, 60, 4, f'background:{COL[t]};border-radius:2px;'))
    o.append(key(x + 152, y + 12, 34, 44, 'm', muted))
    o.append(key(x + 190, y + 12, 34, 44, 's', solo))
    return ''.join(o)

def head_half(x, y, t, sel=False, muted=False, solo=False):
    o = [box(x, y, 640, 42, f'background:{TINT(t) if sel else PANEL};border-radius:10px 0 0 10px;')]
    o.append(chip(x + 8, y + 6, 30, t, muted, 15))
    o.append(tx(x + 46, y + 12, NAME[t], 15, TEXT if not muted else T2, 600))
    o.append(tx(x + 118, y + 12, 'A · 01', 15, T3, 600))
    o.append(key(x + 166, y + 4, 30, 34, 'm', muted)); o.append(key(x + 198, y + 4, 30, 34, 's', solo))
    for i in range(3):
        px = x + 244 + i * 134
        o.append(box(px, y, 128, 42, f'background:{COL[t] if i == 0 else PAD};border-radius:8px;'))
        o.append(tx(px + 8, y + 12, 'ABC'[i], 12, ON if i == 0 else T2, 600)); o.append(tx(px + 24, y + 11, f'{t * 7 + i:02d}', 15, ON if i == 0 else TEXT, 700))
    return ''.join(o)

parts = [tx(40, 40, '43 · The track head: type, mute and solo; the carets; Timeline / Pads as a toggle', 30, TEXT, 600),
         tx(40, 86, 'Bigger: the number (26 → 44 pt chip, 22 pt figure), the name (14 → 17 pt), the entry it’s on (13 → 22 pt). Mute and Solo flat when off, pressed in when on (an inner shadow); Solo amber, Mute white.', 15, T2),
         tx(40, 112, 'Solo: Skiff solos only on the FM-1 (GLO’s black keys); the editor protocol has no SOLO. Lupe needs a small firmware op in Skiff-Lupe (my pick), or to fake it with mutes, which the scenes would store.', 15, T2)]
# H1 and H2, three states each
cols = [(40, 'H1 · Mute over Solo (your layout)', 'The number top left, the entry it’s on beside it. The keys fill the head’s height, so the head is as tall as the row: the lane’s tag step goes (the lane is a plain band).', head_stacked),
        (760, 'H2 · Mute and Solo side by side', 'The keys at the top right, half the width each (34 pt: over the 24 floor, under the 44 aim). The head stops at 100 pt, so the lane keeps its tag.', head_side)]
for cx, t1, n1, fn in cols:
    parts.append(tx(cx, 170, t1, 20, TEXT, 600)); parts.append(tx(cx, 198, n1, 13, T2, 400, 'width:660px;white-space:normal;'))
    for k, (lab, kw, t) in enumerate([('Selected, playing', dict(sel=True), 4), ('Muted', dict(muted=True), 3), ('Soloed', dict(solo=True), 5)]):
        y = 260 + k * 160
        parts.append(tx(cx, y - 22, lab, 13, T3, 600))
        parts.append(f'<div style="position:absolute;left:{cx}px;top:{y}px;width:660px;height:130px;overflow:hidden;">{fn(0, 0, t, **kw)}</div>')
# Half
hx = 1480
parts.append(tx(hx, 170, 'Half · one line', 20, TEXT, 600)); parts.append(tx(hx, 198, 'Chip 30, name 15, the entry 15; M and S 30 × 34 side by side.', 13, T2))
for k, (kw, t) in enumerate([(dict(sel=True), 4), (dict(muted=True), 3), (dict(solo=True), 5), ({}, 6)]):
    parts.append(f'<div style="position:absolute;left:{hx}px;top:{260 + k * 50}px;width:660px;height:42px;overflow:hidden;">{head_half(0, 0, t, **kw)}</div>')
# keys close-up
kx, ky = 1480, 500
parts.append(tx(kx, ky, 'The keys, at 2×', 20, TEXT, 600))
parts.append(f'<div style="position:absolute;left:{kx}px;top:{ky + 40}px;width:600px;height:140px;transform:scale(2);transform-origin:0 0;">'
             + key(0, 0, 64, 50, 'm', False) + key(72, 0, 64, 50, 'm', True) + key(144, 0, 64, 50, 's', False) + key(216, 0, 64, 50, 's', True) + '</div>')
parts.append(tx(kx, ky + 156, 'Off: flat, the control grey (today’s dark base edge goes: it read 3D on a flat page). On: pressed in. Corners 8 inside a head whose content sits 12 in: the lane’s 19 = chip 7 + 12 still holds; the big chip’s 11 + 12 = 23 would round the tag more (kept 19: the chip sits to the side of the corner, not in it).', 13, T2, 400, 'width:600px;white-space:normal;'))
# carets
cy = 780
parts.append(tx(40, cy, 'The editor tab’s carets in the track colour', 20, TEXT, 600))
for i, t in enumerate([1, 4, 6]):
    x = 40 + i * 300
    parts.append(box(x, cy + 40, 232, 40, f'background:{TINT(t)};border-radius:12px 12px 0 0;'))
    parts.append(tx(x, cy + 46, '⌃⌃⌃', 22, COL[t], 700, 'width:232px;text-align:center;letter-spacing:2px;'))
parts.append(tx(40, cy + 96, 'Colour on its own tint is about 4–6:1 here (purple lowest): fine for a mark you also see the shape of.', 13, T2))
# toggle
tyy = 960
parts.append(tx(40, tyy, 'Timeline / Pads: from two word tabs to one icon toggle', 20, TEXT, 600))
parts.append(tx(40, tyy + 28, 'Today (left): a second row of tabs under Song · Mix · Sounds. Proposed (right): one key, two icons, the view you’re in lit; it never moves (DESIGN.md).', 13, T2))
parts.append(box(40, tyy + 70, 256, 44, f'background:{WELL};border-radius:12px;'))
parts.append(tx(62, tyy + 82, 'Timeline', 15, T2)); parts.append(box(170, tyy + 73, 120, 38, f'background:{PAD};border-radius:10px;')); parts.append(tx(208, tyy + 82, 'Pads', 15, TEXT, 600))
tg = (f'<svg style="position:absolute;left:{360 + 18}px;top:{tyy + 80}px" width="24" height="24" viewBox="0 0 24 24"><rect x="2" y="6" width="9" height="4" rx="1.5" fill="{T2}"/><rect x="12" y="6" width="10" height="4" rx="1.5" fill="{T2}"/><rect x="2" y="14" width="14" height="4" rx="1.5" fill="{T2}"/></svg>'
      f'<svg style="position:absolute;left:{360 + 70}px;top:{tyy + 80}px" width="24" height="24" viewBox="0 0 24 24"><rect x="2" y="3" width="8" height="8" rx="2" fill="{TEXT}"/><rect x="13" y="3" width="8" height="8" rx="2" fill="{TEXT}"/><rect x="2" y="13" width="8" height="8" rx="2" fill="{TEXT}"/><rect x="13" y="13" width="8" height="8" rx="2" fill="{TEXT}"/></svg>')
parts.append(box(360, tyy + 70, 104, 44, f'background:{WELL};border-radius:12px;'))
parts.append(box(412, tyy + 73, 49, 38, f'background:{PAD};border-radius:10px;'))
parts.append(tg)
parts.append(tx(480, tyy + 82, 'Timeline · Pads (VoiceOver and a hold say the names)', 13, T2))
BW, BH = 2180, 1110
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};font-family:-apple-system,\'SF Pro Text\',system-ui,sans-serif;overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe track head</title>
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
open(os.path.join(OUT, 'TrackHead.dc.html'), 'w').write(doc)
print('TrackHead.dc.html', BW, BH)

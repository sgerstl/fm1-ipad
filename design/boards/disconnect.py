# Board 42: the FM-1 disconnected (Scott, 2026-11-09). Static HTML for the Lupe canvas. OUT=<project folder>
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, ON, LANE = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#101012', '#1A1A1E'
COL = ['#FF5A36', '#22C3B4', '#FFBF00', '#9580FF', '#FF6FAE', '#A3E635']
def mix(a, b, k):
    A = [int(a[i:i+2], 16) for i in (1, 3, 5)]; B = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return '#' + ''.join('%02X' % round(x + (y - x) * k) for x, y in zip(A, B))
def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.25;{extra}">{html.escape(s)}</div>'

def screen(dim=False, top_status=None):
    """A simplified Lupe iPad screen (1376 x 1032): top bar, Song › Pads with lanes, scenes, the editor tab."""
    o = [box(0, 0, 1376, 1032, f'background:{PAGE};')]
    # top bar
    o.append(tx(28, 22, '• Demo', 15, TEXT, 600))
    o.append(box(340, 12, 256, 44, f'background:{WELL};border-radius:12px;'))
    o.append(box(343, 15, 80, 38, f'background:{PAD};border-radius:10px;box-shadow:inset 0 0 0 2px {TEXT};'))
    o.append(tx(362, 24, 'Song', 15, TEXT, 600)); o.append(tx(448, 24, 'Mix', 15, T2)); o.append(tx(512, 24, 'Sounds', 15, T2))
    if top_status:
        o.append(top_status)
    else:
        o.append(box(1180, 12, 180, 44, f'background:{WELL};border-radius:12px;'))
        o.append(tx(1250, 18, '10 · 3', 17, TEXT, 600)); o.append(tx(1250, 38, '120 BPM', 11, T2))
    # pads with lanes
    gx, gy, rh, rg, pw, pg = 268, 132, 116, 8, 128, 6
    for k in range(6):
        y = gy + k * (rh + rg)
        o.append(box(24, y, 1336, rh, f'background:{mix(PAGE, COL[k], 0.24) if k == 0 else LANE};border-radius:16px 0 0 16px;'))
        o.append(box(36, y + 12, 26, 26, f'background:{COL[k]};border-radius:7px;'))
        o.append(tx(72, y + 15, ['Acid', 'Pad', 'Pulse Ld', 'Drum Kit', 'Piano', 'Drum Kit'][k], 15, TEXT, 600))
        o.append(box(176, y + 12, 72, 52, f'background:{PAD};border-radius:8px;'))
        for i in range(8):
            x = gx + i * (pw + pg)
            filled = i < [6, 3, 4, 3, 5, 2][k]
            if filled:
                o.append(box(x, y, pw, rh, f'background:{COL[k] if i == 0 else PAD};border-radius:16px;'))
                o.append(tx(x + 14, y + 12, 'ABCDEFGH'[i], 15, ON if i == 0 else T2, 600))
                o.append(tx(x + 14, y + 34, f'{(k * 7 + i) % 60 + 1:02d}', 26, ON if i == 0 else TEXT, 700))
            else:
                o.append(box(x, y, pw, rh, f'background:{WELL};border:1px solid #2A2A30;border-radius:16px;'))
    # scenes and the editor tab
    sy = gy + 6 * (rh + rg) + 4
    o.append(box(268, sy, 88, 56, f'background:{PAD};border-radius:10px;'))
    for s in range(16):
        o.append(box(364 + s * 62, sy, 56, 56, f'border:1px solid #2A2A30;border-radius:8px;'))
    o.append(box(24, 1032 - 40, 232, 40, f'background:{mix(PAGE, COL[0], 0.24)};border-radius:12px 12px 0 0;'))
    o.append(box(24, 1032 - 12, 1336, 12, f'background:{mix(PAGE, COL[0], 0.24)};'))
    body = ''.join(o)
    if dim:
        # held, read-only: the page stays where it was, faded back and grey, no touches
        return f'<div style="position:absolute;inset:0;filter:saturate(0.15) brightness(0.45);">{body}</div>'
    return body

def cable_icon(x, y, c=TEXT):
    return (f'<svg style="position:absolute;left:{x}px;top:{y}px" width="64" height="40" viewBox="0 0 64 40" aria-hidden="true">'
            f'<rect x="2" y="10" width="24" height="20" rx="5" fill="none" stroke="{c}" stroke-width="2.5"/>'
            f'<path d="M26 20h6" stroke="{c}" stroke-width="2.5" stroke-linecap="round"/>'
            f'<path d="M40 20h22" stroke="{c}" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="3 5"/>'
            f'<rect x="34" y="14" width="8" height="12" rx="2" fill="{c}"/></svg>')

def card(x, y, title, line, state='looking', w=520):
    o = [box(x, y, w, 168, f'background:#26262B;border-radius:16px;box-shadow:0 12px 32px rgba(0,0,0,0.6);')]
    o.append(cable_icon(x + 24, y + 28, '#FFB54A' if state != 'back' else '#1ECC70'))
    o.append(tx(x + 104, y + 26, title, 22, TEXT, 600))
    o.append(tx(x + 104, y + 60, line, 15, T2, 400, f'width:{w - 128}px;white-space:normal;'))
    if state == 'looking':
        for i in range(3):
            o.append(box(x + 104 + i * 14, y + 132, 8, 8, f'background:{TEXT};border-radius:4px;opacity:{0.3 + 0.35 * i};'))
        o.append(tx(x + 152, y + 126, 'Looking for it', 13, T2))
    elif state == 'back':
        o.append(box(x + 104, y + 134, w - 128, 4, f'background:#2A2A30;border-radius:2px;'))
        o.append(box(x + 104, y + 134, (w - 128) * 0.6, 4, f'background:{TEXT};border-radius:2px;'))
    return ''.join(o)

def frame(px, py, scale, inner, title, note):
    return (tx(px, py, title, 22, TEXT, 600) + tx(px, py + 32, note, 15, T2, 400, f'width:{1376 * scale}px;white-space:normal;')
            + f'<div style="position:absolute;left:{px}px;top:{py + 100}px;width:{1376 * scale}px;height:{1032 * scale}px;overflow:hidden;border-radius:12px;box-shadow:0 0 0 1px #2A2A30;">'
            + f'<div style="position:absolute;left:0;top:0;width:1376px;height:1032px;transform:scale({scale});transform-origin:0 0;">{inner}</div></div>')

LOST = 'Plug it back in, or check it’s switched on. Lupe picks up where you were: nothing here is lost.'
A = screen(dim=True) + card(428, 96, 'FM-1 disconnected', LOST)
B = (box(0, 0, 1376, 1032, f'background:{PAGE};') + cable_icon(656, 360) + tx(0, 430, 'FM-1 disconnected', 34, TEXT, 600, 'width:1376px;text-align:center;')
     + tx(338, 484, LOST, 18, T2, 400, 'width:700px;text-align:center;white-space:normal;')
     + tx(0, 580, '• • •  Looking for it', 15, T2, 400, 'width:1376px;text-align:center;'))
strip = (box(980, 12, 380, 44, 'background:#3A2A12;border-radius:12px;box-shadow:inset 0 0 0 1.5px #FFB54A;')
         + tx(1000, 24, 'FM-1 disconnected · looking for it', 15, '#FFD9A0', 600))
C = f'<div style="position:absolute;inset:0;filter:brightness(0.55);">{screen(top_status=box(0, 0, 1, 1))}</div>' + strip

S = 0.62
parts = [tx(40, 40, '42 · The FM-1 disconnected: one pattern, one state', 30, TEXT, 600),
         tx(40, 86, 'Today: on Song the old Arrange page comes up dimmed (not the Song tab you were on); elsewhere a page titled “FM-1 disconnected” says “FM-1 disconnected.” again. Both cut in.', 15, T2),
         tx(40, 112, 'Every option keeps the rule in design/DESIGN.md: nothing pops. Pick one; the storyboard below is for A, my pick.', 15, TEXT, 600)]
fx = [40, 40 + 1376 * S + 80, 40 + 2 * (1376 * S + 80)]
parts.append(frame(fx[0], 150, S, A, 'A · Hold the page (my pick)', 'The page you were on stays put, faded back and grey, read-only. A card drops from under the top bar: what happened, what to do, that Lupe is looking. Your song stays in view.'))
parts.append(frame(fx[1], 150, S, B, 'B · A page of its own', 'The page cross-fades to a dedicated screen, the same as the first “plug it in” screen. Clear, but the song you were playing goes out of view.'))
parts.append(frame(fx[2], 150, S, C, 'C · Status in the top bar', 'The transport area turns amber, the pads fade back. The least in the way, but easy to miss mid-set, and the dimmed pads still look tappable.'))
# storyboard for A
sy = 150 + 100 + 1032 * S + 100
parts.append(tx(40, sy, 'A, frame by frame', 22, TEXT, 600))
SS = 0.4
steps = [
    ('1 · Playing', 'Connected.', screen()),
    ('2 · Lost: 0–300 ms', 'The page fades back and greys (300 ms ease-out); the card drops from under the top bar (250 ms ease-out). Touches off.', A),
    ('3 · Back: reading', 'Found again: the card’s line blends to “Back · reading the FM-1” with a bar (150 ms). The page stays held.', screen(dim=True) + card(428, 96, 'Back', 'Reading the FM-1. A second.', state='back')),
    ('4 · Picked up: 0–250 ms', 'The card rises away (200 ms ease-in); the page comes back to full colour (250 ms). Where you were, as you left it.', screen()),
]
for i, (t, n, inner) in enumerate(steps):
    x = 40 + i * (1376 * SS + 60)
    parts.append(tx(x, sy + 44, t, 17, TEXT, 600))
    parts.append(tx(x, sy + 70, n, 13, T2, 400, f'width:{1376 * SS}px;white-space:normal;'))
    parts.append(f'<div style="position:absolute;left:{x}px;top:{sy + 130}px;width:{1376 * SS}px;height:{1032 * SS}px;overflow:hidden;border-radius:10px;box-shadow:0 0 0 1px #2A2A30;"><div style="position:absolute;left:0;top:0;width:1376px;height:1032px;transform:scale({SS});transform-origin:0 0;">{inner}</div></div>')
parts.append(tx(40, sy + 130 + 1032 * SS + 30, 'Reduce Motion: nothing travels; the card and the fade cross-fade (150 ms). The other states (first launch, wrong firmware) keep B’s full page, with the same entrance.', 15, T2))
BW = int(fx[2] + 1376 * S + 40); BH = int(sy + 130 + 1032 * SS + 90)
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};font-family:-apple-system,\'SF Pro Text\',system-ui,sans-serif;overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe disconnected</title>
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
open(os.path.join(OUT, 'Disconnected.dc.html'), 'w').write(doc)
print('Disconnected.dc.html', BW, BH)

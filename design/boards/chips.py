# Board 46: where the ARP / CHORD / motion chips go (Scott, 2026-11-10: "the little chips that show a track or pattern
# has ARP, a chord, or similar"). Four placements, each with no chip, one and three, at full size and Half.
# What's whose, from Skiff's firmware (params.c param_kept, launch.c LAUNCH_TIME, motion.c):
#   per track: ARP (P_AMODE), CHORD (P_CHRD), SCALE / QUANT, SLICER, DUCK, FOLLOW: a pad's own sound never changes them;
#   per pattern: DIR (REV / PING / RAND) and its recorded MOTION (automation and locks) come in with the pattern;
#   per pad: the entry's own SOUND.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, T3, ON, AMBER = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#C4C4CC', '#101012', '#FFB54A'
COL = {1: '#FF5A36', 2: '#22C3B4', 3: '#FFBF00', 4: '#9580FF', 5: '#FF6FAE', 6: '#A3E635'}
def mix(a, b, k):
    A = [int(a[i:i+2], 16) for i in (1, 3, 5)]; B = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return '#' + ''.join('%02X' % round(x + (y - x) * k) for x, y in zip(A, B))
TINT = lambda t: mix(PAGE, COL[t], 0.24)
FONT = "font-family:'Barlow',-apple-system,system-ui,sans-serif;"
NUM = "font-family:'Barlow Condensed','Barlow',sans-serif;"
def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{FONT}{extra}">{html.escape(s)}</div>'

# a chip: words on the control grey with a hairline, the kind's glyph first (shape, not colour, says what it is)
GLYPH = {'ARP': '↗', 'CHORD': '♯', 'SCL': '◇', 'MOTION': '∿', 'DIR': '⇄', 'SOUND': '♪'}
def chip(x, y, kind, word, small=False):
    h = 18 if small else 22; f = 11 if small else 12
    s = f'{GLYPH[kind]} {word}'
    w = int(len(s) * f * 0.56) + (12 if small else 16)
    return (box(x, y, w, h, f'background:{PAD};border:1px solid #4A4A52;border-radius:{h / 2}px;')
            + tx(x, y + (h - f * 1.2) / 2, s, f, TEXT, 600, f'width:{w}px;text-align:center;')), w
CHIPS3 = [('ARP', 'ARP UP'), ('CHORD', 'MAJ7'), ('SCL', 'DOR')]
def chips(x, y, n, small=False, gap=6, vertical=False):
    o, cx, cy = [], x, y
    for kind, word in CHIPS3[:n]:
        s, w = chip(cx, cy, kind, word, small)
        o.append(s)
        if vertical: cy += (18 if small else 22) + gap
        else: cx += w + gap
    return ''.join(o)

def key(x, y, w, h, kind):
    o = [box(x, y, w, h, f'background:{PAD};border-radius:8px;')]
    if kind == 'm':
        o.append(f'<svg style="position:absolute;left:{x + w / 2 - 10}px;top:{y + h / 2 - 10}px" width="20" height="20" viewBox="0 0 24 24"><path d="M3 9h4l5-4v14l-5-4H3z" fill="{TEXT}"/><path d="M15.5 9.5a4 4 0 0 1 0 5M18 7a7.5 7.5 0 0 1 0 10" stroke="{TEXT}" stroke-width="2" fill="none" stroke-linecap="round"/></svg>')
    else:
        o.append(tx(x, y + h / 2 - 10, 'S', 16, TEXT, 700, f'width:{w}px;text-align:center;'))
    return ''.join(o)

def tchip(x, y, s, t):
    return box(x, y, s, s, f'background:{COL[t]};border-radius:{s * 0.25:.0f}px;') + tx(x, y + s / 2 - s * 0.32, str(t), s * 0.5, ON, 700, f'width:{s}px;text-align:center;{NUM}')

def head_full(x, y, t, n_chips=0, with_chips=False, h=86):
    """The full head (H1): chip, entry, name; Mute over Solo at the right. with_chips: option (a), under the name."""
    o = [tchip(x + 12, y + 8, 44, t)]
    o.append(tx(x + 64, y + 10, 'A', 15, T2, 600)); o.append(tx(x + 78, y + 4, '01', 30, TEXT, 700, NUM))
    o.append(tx(x + 12, y + 56, 'Acid' if t == 1 else 'Pulse Ld', 15, '#C8C8CF'))
    if with_chips and n_chips:
        o.append(chips(x + 64, y + 40 if n_chips else 0, 0))
        o.append(chips(x + 74 if False else x + 12, y + h - 4, 0))
    o.append(key(x + 180, y + 8, 52, 34, 'm')); o.append(key(x + 180, y + 46, 52, 34, 's'))
    return ''.join(o)

def lane_full(x, y, t, h=86, w=760, sel=True):
    return box(x, y, w, h, f'background:{TINT(t) if sel else PANEL};border-radius:19px 0 0 19px;')

def pads(x, y, h, t, n=3, marks=None):
    o = []
    for i in range(n):
        px = x + i * 134
        playing = i == 0
        o.append(box(px, y, 128, h, f'background:{COL[t] if playing else PAD};border-radius:16px;'))
        o.append(tx(px + 12, y + 10, 'ABC'[i], 13, ON if playing else T2, 600))
        o.append(tx(px + 12, y + 26, f'{t * 7 + i:02d}', 26, ON if playing else TEXT, 700, NUM))
        if marks and i < len(marks) and marks[i]:
            mx = px + 128 - 10
            for g in marks[i]:
                mx -= 22
                c = ON if playing else TEXT
                o.append(box(mx, y + 8, 20, 20, f'border:1.5px solid {c};border-radius:6px;opacity:0.85;'))
                o.append(tx(mx, y + 9, g, 12, c, 700, 'width:20px;text-align:center;'))
    return ''.join(o)

# the track controls box (TrackKnobBox): four HOME tiles, then LEVEL STEPS PAN and the close key
def ctl_box(x, y, t, extra_w=0, extra_h=0, chip_mode=None, n=0):
    W, H = 424 + extra_w, 132 + extra_h
    o = [box(x, y, W, H, f'background:{TINT(t)};border-radius:14px;')]
    names = [('CUTOFF', '355'), ('RES', '79'), ('ATTACK', '1.0'), ('RELEASE', '8.8')]
    for i, (a, v) in enumerate(names):
        o.append(box(x + 8 + i * 96, y + 8, 92, 56, f'background:{WELL};border-radius:6px;'))
        o.append(tx(x + 16 + i * 96, y + 14, a, 10, T2, 600)); o.append(tx(x + 16 + i * 96, y + 30, v, 20, TEXT, 700, NUM))
    for i, (a, v) in enumerate([('LEVEL', '81'), ('STEPS', '16'), ('PAN', '0')]):
        o.append(box(x + 8 + i * 96, y + 68, 92, 56, f'background:{WELL};border-radius:6px;'))
        o.append(tx(x + 16 + i * 96, y + 74, a, 10, T2, 600)); o.append(tx(x + 16 + i * 96, y + 90, v, 20, TEXT, 700, NUM))
    # the close key, bottom right of the tiles' block
    cx, cy = x + 8 + 3 * 96 + 92 - 30, y + 68 + 56 - 30
    o.append(box(cx, cy, 28, 28, f'background:{PAD};border:1px solid #6E6E76;border-radius:14px;'))
    o.append(tx(cx, cy + 5, '×', 15, TEXT, 700, 'width:28px;text-align:center;'))
    if chip_mode == 'side' and n:
        o.append(chips(x + 8 + 4 * 96 + 4, y + 10, n, small=True, gap=6, vertical=True))
    if chip_mode == 'side' and not n:
        o.append(tx(x + 8 + 4 * 96 + 6, y + 12, 'no ARP,', 11, T2)); o.append(tx(x + 8 + 4 * 96 + 6, y + 26, 'chord…', 11, T2))
    if chip_mode == 'row' and n:
        o.append(chips(x + 10, y + 132, n, small=False, gap=6))
    if chip_mode == 'row' and not n:
        o.append(tx(x + 12, y + 135, 'nothing applied', 12, T2))
    return ''.join(o), W, H

parts = [tx(40, 36, '46 · ARP, chord and the like: where the chips go', 30, TEXT, 600),
         tx(40, 82, 'Skiff decides it: ARP, CHORD, SCALE / QUANT, SLICER, DUCK and FOLLOW belong to the track (a pad’s own sound never changes them: params.c param_kept). DIR and the recorded MOTION come in with each pattern. A pad can carry its own SOUND.', 15, T2, 400, 'width:2300px;white-space:normal;'),
         tx(40, 106, 'So (a)–(c) are track chips; (d) is the per-pattern part, on the pad. Chips are words on the control grey with a glyph first (↗ ARP, ♯ chord, ◇ scale), never colour alone; the text is #EDEDF0 on #26262B, 12.9:1.', 15, T2, 400, 'width:2300px;white-space:normal;')]

COLS = [0, 1, 3]
CX = [40, 860, 1680]
for i, n in enumerate(COLS):
    parts.append(tx(CX[i], 150, ['No chips', 'One chip', 'Three chips'][i], 18, T3, 600))

def row_title(y, a, b):
    parts.append(tx(40, y, a, 22, TEXT, 600)); parts.append(tx(40, y + 30, b, 13, T2, 400, 'width:2300px;white-space:normal;'))

# (a) in the full head
y0 = 190
row_title(y0, '(a) In the track head, between the words and Mute / Solo',
          'Full size: a row under the entry, left of the keys (the head has about 110 pt beside the name before the keys: one chip and “+2”). Half: no room on its one line, so a count chip after the name (“3”), the words on a hold or in VoiceOver.')
for i, n in enumerate(COLS):
    x, y = CX[i], y0 + 70
    parts.append(lane_full(x, y, 1, w=760))
    parts.append(tchip(x + 12, y + 8, 44, 1)); parts.append(tx(x + 64, y + 10, 'A', 15, T2, 600)); parts.append(tx(x + 78, y + 4, '01', 30, TEXT, 700, NUM))
    parts.append(tx(x + 12, y + 58, 'Acid', 15, '#C8C8CF'))
    if n:
        parts.append(chips(x + 58, y + 58, 1, small=True))
        if n > 1:
            parts.append(box(x + 134, y + 58, 26, 18, f'background:{PAD};border:1px solid #4A4A52;border-radius:9px;') + tx(x + 134, y + 59, f'+{n - 1}', 11, TEXT, 600, 'width:26px;text-align:center;'))
    parts.append(key(x + 184, y + 8, 48, 34, 'm')); parts.append(key(x + 184, y + 46, 48, 34, 's'))
    parts.append(pads(x + 244, y, 86, 1))
    # Half
    hy = y + 106
    parts.append(box(x, hy, 760, 42, f'background:{TINT(1)};border-radius:10px 0 0 10px;'))
    parts.append(tchip(x + 8, hy + 6, 30, 1)); parts.append(tx(x + 46, hy + 11, 'Acid', 15, TEXT, 600))
    if n:
        parts.append(box(x + 86, hy + 12, 22 if n < 10 else 28, 18, f'background:{PAD};border:1px solid #4A4A52;border-radius:9px;') + tx(x + 86, hy + 13, str(n), 11, TEXT, 700, 'width:22px;text-align:center;'))
    parts.append(tx(x + 118 if n else x + 96, hy + 13, 'A 01', 12, '#C8C8CF', 400, NUM))
    parts.append(key(x + 168, hy + 4, 30, 34, 'm')); parts.append(key(x + 200, hy + 4, 30, 34, 's'))
    for k in range(3):
        px = x + 244 + k * 134
        parts.append(box(px, hy, 128, 42, f'background:{COL[1] if k == 0 else PAD};border-radius:8px;'))
        parts.append(tx(px + 8, hy + 12, 'ABC'[k], 12, ON if k == 0 else T2, 600)); parts.append(tx(px + 24, hy + 9, f'{7 + k:02d}', 17, ON if k == 0 else TEXT, 700, NUM))

# (b) beside the tiles: the box wider
y1 = 470
row_title(y1, '(b) In the track controls, the box a little wider, the chips down its right side',
          'The box grows 96 pt (one tile’s width) only while a chip is there; nothing applied, it keeps today’s width. Same at Half: the box is the same box.')
for i, n in enumerate(COLS):
    x, y = CX[i], y1 + 70
    s, W, H = ctl_box(x, y, 1, extra_w=96 if n else 0, chip_mode='side' if n else None, n=n)
    parts.append(s)

# (c) under the tiles: the box taller
y2 = 720
row_title(y2, '(c) In the track controls, the box a little taller, the chips in a row underneath',
          'The box grows 30 pt only while a chip is there; three chips fit across its 424 pt. It covers a little more of the row it hangs over (above by default). Same at Half.')
for i, n in enumerate(COLS):
    x, y = CX[i], y2 + 70
    s, W, H = ctl_box(x, y, 1, extra_h=32 if n else 0, chip_mode='row' if n else None, n=n)
    parts.append(s)

# (d) on the pad: the per-pattern part
y3 = 1010
row_title(y3, '(d) The per-pattern part, on the pad itself: a small mark in its top right corner',
          '∿ the pattern has recorded motion; ⇄ / ← / ? it plays PING, REV or RAND; ♪ the pad brings its own sound. Each a 20 pt outlined square with its glyph, dark ink on the playing pad, light on the others; at Half, the marks shrink to 14 pt glyphs after the number.')
for i, n in enumerate(COLS):
    x, y = CX[i], y3 + 70
    marks = [[], [], []] if n == 0 else ([['∿'], [], []] if n == 1 else [['∿', '⇄'], ['♪'], []])
    parts.append(pads(x, y, 104, 3, marks=marks))
    hy = y + 124
    for k in range(3):
        px = x + k * 134
        parts.append(box(px, hy, 128, 42, f'background:{COL[3] if k == 0 else PAD};border-radius:8px;'))
        parts.append(tx(px + 8, hy + 12, 'ABC'[k], 12, ON if k == 0 else T2, 600)); parts.append(tx(px + 24, hy + 9, f'{21 + k:02d}', 17, ON if k == 0 else TEXT, 700, NUM))
        gl = '' if n == 0 else (['∿', '', ''][k] if n == 1 else ['∿⇄', '♪', ''][k])
        if gl: parts.append(tx(px + 52, hy + 12, gl, 14, ON if k == 0 else TEXT, 700))

parts.append(tx(40, 1330, 'My pick: (c) for the track chips (the box keeps its width, the chips read as words, and the head stays as it is at both sizes) with (d) for the pattern’s motion and direction. (a) is the only one you see with the controls shut, but at Half it can only say a number.', 15, TEXT, 600, 'width:2300px;white-space:normal;'))
parts.append(tx(40, 1356, 'Not decided here: whether a chip taps through to its Sound page (the old Overview’s did), and which of SLICER / DUCK / FOLLOW earn a chip at all.', 14, T2, 400, 'width:2300px;white-space:normal;'))

BW, BH = 2480, 1400
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};{FONT}overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe chips</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet><style>@import url('https://fonts.googleapis.com/css2?family=Barlow:wght@400;600;700&family=Barlow+Condensed:wght@700&display=swap');body{{margin:0}}</style></helmet>
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
open(os.path.join(OUT, 'Chips.dc.html'), 'w').write(doc)
print('Chips.dc.html', BW, BH)

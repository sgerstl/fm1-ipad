# Board 48: the Timeline toned down, its selected block in the Pads' language (Scott, 2026-11-10: "we also need to tone
# down the timeline page... not every block needs to be at full track color. Also the selected state seems unpolished
# compared to what we do on the pads. I'd like them to feel similar visually, sharing the material you/star trek vibes...
# maybe mock up a couple choices first"). Today and three options, each at full size (the editor shut) and at Half, at
# 1:1, with the states drawn larger underneath and every contrast pair measured.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, T2R, T3, ON = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#C4C4CC', '#71717A', '#101012'
EDGE, EDGE_B, REST_OLD, REST_NEW, NOTE = '#7C7C85', '#8E8E96', '#4A4A52', '#7C7C85', '#FFB54A'
COL = {1: '#FF5A36', 2: '#22C3B4', 3: '#FFBF00', 4: '#9580FF', 5: '#FF6FAE', 6: '#A3E635'}
NAMES = {1: 'Acid', 2: 'Pad', 3: 'Pulse Ld', 4: 'Drum Kit', 5: 'Piano', 6: 'Drum Kit'}
FONT = "font-family:'Barlow',-apple-system,system-ui,sans-serif;"
NUM = "font-family:'Barlow Condensed','Barlow',sans-serif;"

def rgb(h): h = h.lstrip('#'); return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
def hx(c): return '#' + ''.join(f'{round(v * 255):02X}' for v in c)
def mix(a, b, k): A, B = rgb(a), rgb(b); return hx([B[i] + (A[i] - B[i]) * k for i in range(3)])
def lum(h):
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = [f(c) for c in rgb(h)]; return 0.2126 * r + 0.7152 * g + 0.0722 * b
def cr(a, b): x, y = sorted([lum(a), lum(b)], reverse=True); return (x + 0.05) / (y + 0.05)
def tint(t, k=0.24): return mix(COL[t], PAGE, k)
def worst(f): return min(f(t) for t in COL), min(COL, key=f)

def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{FONT}{extra}">{html.escape(s)}</div>'
def wrap(x, y, w, s, size, c, wt=400): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.45;{FONT}">{s}</div>'

# The demo song (as Lupe's Skiff demo has it), bars from 0: (start, end, letter, label, reps, kind)
SONG = {
    1: [(0, 3.75, 'A', '01', '×4', 'p'), (3.9, 11.5, 'B', '02', '×8', 'p'), (11.6, 12.4, 'C', '03', '×1', 'p'), (12.5, 19, 'D', '02', '×7', 'p'), (19.2, 20, 'E', '03', '×1', 'p'), (20.2, 24, 'F', '04', '×4', 'p')],
    2: [(0, 3.5, 'A', 'REST', '×4', 'r'), (3.75, 11.4, 'B', '05', '×8', 'p'), (11.6, 15.25, 'C–D', '06→07', '×2', 'p'), (15.5, 23.1, 'E', '05', '×8', 'p')],
    3: [(0, 7.5, 'A', '08', '×2', 'p'), (7.75, 11.4, 'B', '09', '×1', 'p'), (11.6, 19.2, 'C', '08', '×2', 'p'), (19.4, 23.1, 'D', 'REST', '×1', 'r')],
    4: [(0, 2.75, 'A', 'REST', '×4', 'r'), (2.9, 14.25, 'B', '10', '×16', 'p'), (14.5, 22, 'C', '11', '×8', 'p')],
    5: [(0, 7.5, 'A', 'REST', '×8', 'r'), (7.75, 11.4, 'B', '12', '×4', 'p'), (11.6, 15.25, 'C', '13', '×4', 'p'), (15.5, 19.2, 'D', '12', '×4', 'p'), (19.4, 23.1, 'E', '12', '×4', 'p')],
    6: [(0, 15.25, 'A', '14', '×16', 'p'), (15.5, 23.1, 'B', '14', '×8', 'p')],
}
SELECTED = (4, 1)                              # T4's B · 10: the selected track and block
PLAYING = {1: 1, 2: 1, 3: 0, 4: 1, 5: 1, 6: 0}  # the block each track is on, playing (the moment drawn)
WAITING = (3, 1)                                # T3's B · 09 queued, its trace two thirds round

# ---- the options -----------------------------------------------------------------------------------------------------
OPTS = {
    'today': dict(name='Today', sub='Every block in full track colour. Selected: a white 2 pt ring outside. Playing: a white ring inside, everything else at half opacity. REST: a dashed outline that fails 3:1.'),
    'A': dict(name='A · Tint at rest', sub='Resting blocks in a 32% tint of their track with a 1.5 pt track-colour edge. Full colour only while playing. Every lane keeps a little of its colour, so the song still reads by track at a glance.'),
    'B': dict(name='B · Grey at rest, like the pads', sub='Resting blocks are the pads’ grey with a track-colour cap at their start (the LCARS end cap) and a 1 pt edge. Full colour only while playing. The quietest page; the lane tags carry the track colour, as on Pads.'),
    'C': dict(name='C · Colour on your track', sub='The selected track’s blocks in a 32% tint (as A); every other track’s in the pads’ grey with a cap (as B). Playing is full colour everywhere. Your track stands out; the rest steps back.'),
}

def rest_style(opt, t):
    """How a resting pattern block looks: (fill, edge, edge width, cap colour or None, text, count)."""
    if opt == 'today': return COL[t], None, 0, None, ON, '#2A2A2E'
    tinted = opt == 'A' or (opt == 'C' and t == SELECTED[0])
    if tinted: return tint(t, 0.32), COL[t], 1.5, None, TEXT, T2R
    return PAD, EDGE_B, 1, COL[t], TEXT, T2

def carets(x, y, c, up=False, s=11):
    ch = '⌃⌃' if up else '⌄⌄'
    return tx(x, y, ch, s, c, 700, 'letter-spacing:1px;')

def trace(x, y, w, h, r, c, frac, width=3):
    per = 2 * (w + h)
    return (f'<svg style="position:absolute;left:{x}px;top:{y}px;overflow:visible" width="{w}" height="{h}">'
            f'<rect x="{width/2}" y="{width/2}" width="{w-width}" height="{h-width}" rx="{r}" fill="none" stroke="{c}" stroke-width="{width}" '
            f'stroke-dasharray="{per*frac:.0f} {per:.0f}" stroke-linecap="round"/></svg>')

def block(opt, t, x, y, w, h, letter, label, reps, kind, state, big):
    """One block. state: rest | selected | playing | waiting. big: full-size lanes (two lines) or Half (one)."""
    r = 10 if big else 7
    o = []
    is_rest = kind == 'r'
    fill, edge, ew, cap, ink, dim = rest_style(opt, t)
    if is_rest:
        dash = REST_OLD if opt == 'today' else REST_NEW
        o.append(box(x, y, w, h, f'border:1.5px dashed {dash};border-radius:{r}px;'))
        ink, dim = T2, T3 if opt == 'today' else T2
    elif state == 'playing':
        o.append(box(x, y, w, h, f'background:{COL[t]};border-radius:{r}px;'))
        if opt == 'today': o.append(box(x + 2, y + 2, w - 4, h - 4, f'border:2px solid {TEXT};border-radius:{r-2}px;'))
        ink, dim = ON, '#2A2A2E'
    elif state == 'selected':
        if opt == 'today':
            o.append(box(x, y, w, h, f'background:{COL[t]};border-radius:{r}px;'))
            o.append(box(x - 3, y - 3, w + 6, h + 6, f'border:2px solid {TEXT};border-radius:{r+3}px;'))
            ink, dim = ON, '#2A2A2E'
        else:
            # the Pads' selected pad: flat grey in its lane's tint, a 3 pt outline in the track's colour, the open tab
            o.append(box(x, y, w, h, f'background:{PAD};border:3px solid {COL[t]};border-radius:{r}px;'))
            ink, dim = TEXT, T2
    else:
        st = f'background:{fill};border-radius:{r}px;'
        if edge: st += f'border:{ew}px solid {edge};'
        o.append(box(x, y, w, h, st))
        if cap and opt != 'today':
            cw = 6 if big else 4
            o.append(box(x + (ew or 0), y + (ew or 0), cw, h - 2 * (ew or 0), f'background:{cap};border-radius:{r-1}px 0 0 {r-1}px;'))
        if opt == 'today' and state == 'rest' and PLAYING_MOMENT[0]:
            o.append(box(x, y, w, h, f'background:{PAGE};opacity:.5;border-radius:{r}px;'))
        if state == 'waiting':
            o.append(trace(x, y, w, h, r, COL[t], 0.66))
    pad = 12 if big else 8
    if cap and not is_rest and state in ('rest', 'waiting') and opt != 'today': pad += 4
    if big:
        o.append(tx(x + pad, y + 8, letter, 12, dim, 600))
        o.append(tx(x + pad, y + 24, label, 22 if not is_rest else 15, ink, 700, NUM if not is_rest else ''))
        if w > 70: o.append(tx(x + pad, y + (56 if not is_rest else 50), reps + ('  · waiting, bar 13' if state == 'waiting' and w > 160 else ''), 12, dim))
    else:
        s = f'{letter} · {label} {reps}' if w > 90 else (label if w > 30 else '')
        o.append(tx(x + pad, y + (h - 14) / 2, s, 11, ink, 600))
    if state == 'selected' and opt != 'today':
        # controls shut: the open tab under it, right-aligned, in the lane's tint with the track's carets
        tw_, th = (56, 22) if big else (44, 18)
        o.append(box(x + w - tw_, y + h, tw_, th, f'background:{tint(t)};border-radius:0 0 10px 10px;'))
        o.append(carets(x + w - tw_ + (tw_ - 22) / 2, y + h + (2 if big else 1), COL[t], s=13 if big else 11))
    return ''.join(o)

PLAYING_MOMENT = [True]

def lanes(opt, x, y, width, big):
    """The Timeline's ruler and six lanes at real size: heads on the left, the lane bands (board 41's language)."""
    head = 236 if big else 220
    lh, gap = (100, 12) if big else (34, 6)
    bars = 25
    bw = (width - head - 16) / bars
    o = []
    # ruler
    o.append(box(x + head, y, width - head - 8, 24, f'background:{PANEL};border-radius:6px;'))
    for b in range(0, bars, 4): o.append(tx(x + head + 6 + b * bw, y + 5, str(b + 1), 12, T2))
    ly = y + 24 + gap
    for t in range(1, 7):
        sel = t == SELECTED[0]
        band = tint(t) if sel else PANEL
        o.append(box(x, ly, width - 8, lh, f'background:{band};border-radius:{19 if big else 10}px;'))
        # head: number chip, name, Mute/Solo hints
        cs = 32 if big else 22
        o.append(box(x + 10, ly + (12 if big else (lh - cs) / 2), cs, cs, f'background:{COL[t]};border-radius:{8 if big else 6}px;'))
        o.append(tx(x + 10, ly + (12 if big else (lh - cs) / 2) + (5 if big else 3), str(t), 18 if big else 13, ON, 700, f'width:{cs}px;text-align:center;{NUM}'))
        o.append(tx(x + 52 if big else x + 40, ly + (16 if big else (lh - 16) / 2), NAMES[t] + ' ⌄', 15 if big else 13, TEXT if sel else '#C8C8CF', 600 if sel else 400))
        if big: o.append(tx(x + 52, ly + 40, 'A · ' + SONG[t][0][3], 13, T2))
        for k, (s, e, letter, label, reps, kind) in enumerate(SONG[t]):
            bx = x + head + s * bw + 2; w = (e - s) * bw - 4
            state = 'rest'
            if (t, k) == SELECTED: state = 'selected'
            elif (t, k) == WAITING: state = 'waiting'
            elif PLAYING.get(t) == k: state = 'playing'
            o.append(block(opt, t, bx, ly + (6 if big else 4), w, lh - (12 if big else 8), letter, label, reps, kind, state, big))
        ly += lh + gap
    return ''.join(o), ly - y

def frame(x, y, w, h, label):
    return box(x, y, w, h, f'background:{PAGE};border:1px solid #2A2A30;border-radius:18px;') + tx(x, y - 24, label, 13, T2, 600)

def states(opt, x, y):
    o = [tx(x, y, 'The states, at full size', 13, T2, 600)]
    cx = x
    items = [('Resting', 'rest', 'p', 2), ('Selected', 'selected', 'p', 4), ('Playing', 'playing', 'p', 1), ('Waiting', 'waiting', 'p', 3), ('REST', 'rest', 'r', 5), ('Empty', 'empty', '', 6)]
    for name, state, kind, t in items:
        o.append(box(cx - 10, y + 24, 210, 128, f'background:{tint(t) if state == "selected" else PANEL};border-radius:19px;'))
        if state == 'empty':
            o.append(tx(cx + 8, y + 70, 'Nothing: the lane', 12, T2))
        else:
            o.append(block(opt, t, cx, y + 34, 190, 88, 'B', 'REST' if kind == 'r' else '10', '×8', kind, state, True))
        o.append(tx(cx, y + 164, name, 13, TEXT, 600))
        cx += 222
    return ''.join(o)

def contrast(opt):
    """The pairs that matter for this option, worst track first."""
    P = []
    def add(name, f, need):
        v, t = worst(f); P.append((name, v, t, need))
    if opt == 'today':
        add('REST dashes on the lane', lambda t: cr(REST_OLD, PANEL), 3)
        add('Text on a full-colour block', lambda t: cr(ON, COL[t]), 4.5)
        add('Selected ring (white) on the lane', lambda t: cr(TEXT, PANEL), 3)
    if opt in ('A', 'C'):
        add('Tinted block’s edge on the lane', lambda t: cr(COL[t], PANEL), 3)
        add('Tinted block’s edge on its selected lane', lambda t: cr(COL[t], tint(t)), 3)
        add('Name on a 32% tint', lambda t: cr(TEXT, tint(t, .32)), 4.5)
        add('Count on a 32% tint', lambda t: cr(T2R, tint(t, .32)), 4.5)
    if opt in ('B', 'C'):
        add('Grey block’s edge on the lane', lambda t: cr(EDGE_B, PANEL), 3)
        add('Grey block’s edge on the selected lane', lambda t: cr(EDGE_B, tint(t)), 3)
        add('Cap on the grey', lambda t: cr(COL[t], PAD), 3)
        add('Name / count on the grey', lambda t: min(cr(TEXT, PAD), cr(T2, PAD)), 4.5)
    if opt != 'today':
        add('Playing: text on full colour', lambda t: cr(ON, COL[t]), 4.5)
        add('Selected: 3 pt outline on its lane', lambda t: cr(COL[t], tint(t)), 3)
        add('Waiting trace on the lane', lambda t: cr(COL[t], PANEL), 3)
        add('REST dashes on the lane', lambda t: cr(REST_NEW, PANEL), 3)
    return P

# ---- the board -------------------------------------------------------------------------------------------------------
parts = []
CW, GAP = 1376, 64
X0 = 40
cols = ['today', 'A', 'B', 'C']
BW = X0 * 2 + len(cols) * CW + (len(cols) - 1) * GAP

parts.append(tx(40, 32, '48 · The Timeline toned down, its selected block as the Pads draw theirs: today and three options', 30, TEXT, 700))
parts.append(wrap(40, 78, 2200, 'Each column at 1:1: the Timeline at full size (the editor shut), the same at Half, then each state drawn larger. The moment shown: '
              'playing, with T4 selected (its lane in its tint, the controls shut so the open tab shows under B · 10), T3’s B · 09 waiting (its outline two thirds round, as on Pads). '
              'In every option full track colour is spent only on what’s playing; selected is the Pads’ flat grey with a 3 pt outline in the track’s colour on its tinted lane. '
              'Heads and lanes unchanged (board 41). Pick one; nothing is built.', 15, T2))

Y_FULL = 190
for i, opt in enumerate(cols):
    x = X0 + i * (CW + GAP)
    o = OPTS[opt]
    parts.append(tx(x, Y_FULL, o['name'], 24, TEXT if opt != 'B' else TEXT, 700))
    parts.append(wrap(x, Y_FULL + 36, CW - 40, o['sub'], 14, T2))
    fy = Y_FULL + 130
    inner, h = lanes(opt, x + 16, fy + 16, CW - 32, True)
    parts.append(frame(x, fy, CW, h + 40, 'Full size (editor shut)'))
    parts.append(inner)
    hy = fy + h + 40 + 56
    inner2, h2 = lanes(opt, x + 16, hy + 16, CW - 32, False)
    parts.append(frame(x, hy, CW, h2 + 40, 'Half (the editor under it)'))
    parts.append(inner2)
    sy = hy + h2 + 40 + 40
    parts.append(states(opt, x + 10, sy))
    # contrast
    cy = sy + 210
    parts.append(tx(x, cy, 'Contrast, worst track', 13, T2, 600))
    for k, (name, v, t, need) in enumerate(contrast(opt)):
        ok = v >= need
        parts.append(tx(x, cy + 26 + k * 22, f'{v:4.2f}:1', 14, TEXT if ok else NOTE, 700, f'{NUM}width:58px;'))
        parts.append(tx(x + 66, cy + 27 + k * 22, f'{name} (T{t}, needs {need:g}:1){"" if ok else " · fails"}', 13, '#C8C8CF' if ok else NOTE))
    END = cy + 26 + 11 * 22

R = END + 30
parts.append(box(40, R, 1700, 330, f'background:{PANEL};border-radius:14px;'))
parts.append(tx(64, R + 20, 'My pick: B, grey at rest like the pads', 20, TEXT, 700))
parts.append(wrap(64, R + 56, 1640,
    'It makes the Timeline and Pads one system with no translation: a block at rest is a pad at rest (the same grey, the same edge), playing is full colour on both, '
    'selected is the same flat grey with the 3 pt track outline and the open tab, waiting the same trace. The track colour moves to where the eye already looks for it: '
    'the lane tag and a small cap at each block’s start, the LCARS end cap. It’s also the calmest page, so what’s playing jumps out without dimming everything else. '
    'The cost: at a glance the song reads less by colour, so finding “where does T3 come in” leans on the caps and the lane order. A keeps more colour for that; C splits it, '
    'but means a block changes look when you change track, which is the kind of jump Scott’s “nothing pops” rule argues against. '
    'One fix rides along whichever wins: REST’s dashes go from #4A4A52 (1.98:1, fails) to #7C7C85 (4.20:1). And the Pads’ own lane edge (#7C7C85) is 2.67:1 on the lime selected lane, '
    'so B’s 1 pt edge uses #8E8E96 (3.40:1 at worst) and the Pads should take it too.', 15, '#C8C8CF'))

BH = R + 370
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};{FONT}overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Timeline toned down</title>
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
open(os.path.join(OUT, 'TimelineStyle.dc.html'), 'w').write(doc)
print('TimelineStyle.dc.html', BW, BH)
for opt in cols:
    print(opt, [(n, round(v, 2)) for n, v, t, need in contrast(opt) if v < need])

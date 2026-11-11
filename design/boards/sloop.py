# Boards S1–S5: SLOOP in the Skiff look (the SLOOP design pass, 2026-11-10; qa/sloop-design-pass-2026-11-10/README.md).
# SLOOP-Lupe kept the pre-Skiff layout (Sequence · Shape · Arrange · Browse). These boards put SLOOP's own model
# (four tracks, one 64-step loop each, sections A–D, a song order of section × bars, Loop / Song mode, SONG REC) into
# the Skiff tabs and patterns: Song · Mix, track heads, pads with the waiting outline, the editor under the divider,
# the sound panel and the sounds panel. Nothing SLOOP lacks is drawn (no pattern numbers, no pool, no Solo, no
# launch quantize). Same palette and helpers as toprow.py; tokens from tokens/tokens.json.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, WELL, PANEL, CONTROL, LIFTED, HELD = '#0D0D0F', '#111114', '#1A1A1E', '#26262B', '#34343B', '#3E3E46'
TEXT, T2, T2R, T3 = '#EDEDF0', '#A1A1AA', '#C4C4CC', '#71717A'
ON = '#101012'
REC, CAUTION = '#FF2C34', '#FFB54A'
# SLOOP 2.8.4's track colours (DeviceShape.sloopColours); a section takes its track's colour, as on the FM-1 (TE_COL)
COL = ['#287CFF', '#1ECC70', '#FFC618', '#FF621A']
NAMES = ['Lead', 'Bass', 'Keys', 'Drums']
SOUNDS = ['Acid', 'Sub Bass', 'EP Soft', '808 Kit']
FONT = "font-family:'Barlow',-apple-system,system-ui,sans-serif;"
NUM = "font-family:'Barlow Condensed','Barlow',sans-serif;"

def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c=TEXT, wt=400, extra='', num=False):
    return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{NUM if num else FONT}{extra}">{html.escape(s)}</div>'
def wrap(x, y, w, s, size, c=T2R, wt=400): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.45;{FONT}">{s}</div>'
def tw(s, size): return int(len(s) * size * 0.5) + 2

def key(x, y, label, w=None, h=44, dim=False, on=False, chev=False, colour=None):
    lw = tw(label, 15)
    w = w or lw + 28 + (14 if chev else 0)
    bg = LIFTED if on else CONTROL
    ring = f'box-shadow:0 0 0 2px {TEXT};' if on else 'box-shadow:inset 0 1px 0 rgba(255,255,255,.06);'
    o = [box(x, y, w, h, f'background:{bg};border-radius:9px;{ring}')]
    o.append(tx(x + (w - lw - (14 if chev else 0)) / 2, y + (h - 18) / 2, label, 15, colour or (T3 if dim else TEXT), 600 if on else 400))
    if chev: o.append(tx(x + w - 22, y + (h - 16) / 2, '⌄', 13, T2, 700))
    return ''.join(o), w

def seg(x, y, opts, sel, h=44, caption=None):
    o, cx = [], x + 4
    cap = tw(caption, 12) + 14 if caption else 0
    ws = [tw(s, 15) + 26 for s in opts]
    w = cap + sum(ws) + 8
    o.append(box(x, y, w, h, f'background:{WELL};border-radius:10px;'))
    if caption: o.append(tx(x + 10, y + (h - 15) / 2, caption, 12, T2)); cx += cap
    for i, (s, sw) in enumerate(zip(opts, ws)):
        if i == sel: o.append(box(cx, y + 4, sw, h - 8, f'background:{LIFTED};border-radius:7px;'))
        o.append(tx(cx, y + (h - 18) / 2, s, 15, TEXT if i == sel else T2, 600 if i == sel else 400, f'width:{sw}px;text-align:center;'))
        cx += sw
    return ''.join(o), w

def tabs(cx, y, names=('Song', 'Mix'), sel=0):
    ws = [tw(n, 16) + 36 for n in names]
    w = sum(ws) + 4 * (len(names) - 1)
    x = cx - w / 2
    o = [box(x - 6, y + 41, w + 12, 3, f'background:{LIFTED};border-radius:2px;')]
    for i, (n, nw) in enumerate(zip(names, ws)):
        if i == sel: o.append(box(x, y + 2, nw, 42, f'background:{LIFTED};border-radius:9px 9px 0 0;'))
        o.append(tx(x, y + 12, n, 16, TEXT if i == sel else T2, 600 if i == sel else 400, f'width:{nw}px;text-align:center;'))
        x += nw + 4
    return ''.join(o)

def chip(x, y, t, s=44, muted=False):
    c = T3 if muted else COL[t]
    return box(x, y, s, s, f'background:{c};border-radius:{s*0.22:.0f}px;') + tx(x, y + s * 0.17, str(t + 1), s * 0.56, ON, 700, f'width:{s}px;text-align:center;', num=True)

SPEAKER = '<svg style="position:absolute;left:{x}px;top:{y}px" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 10h3l4-3v10l-4-3H4z"/>{w}</svg>'
def speaker(x, y, c=T2R, muted=False):
    w = '<path d="M16 9l5 6M21 9l-5 6"/>' if muted else '<path d="M15 9.5a3.5 3.5 0 0 1 0 5M17.5 7a7 7 0 0 1 0 10"/>'
    return SPEAKER.format(x=x, y=y, c=c, w=w)

def tint(c, pct=32):
    return f'color-mix(in srgb, {c} {pct}%, {PAGE})'

def topbar(X, Y, W, playing=True, song_mode=0, tab='pads', tools=('SONG REC',), line=None):
    """The one row above the pages (board 47 b, Pads · Timeline · Mix since 66a426b), SLOOP's: the FM-1 key with its menu
    (Projects, the iPad's audio), the three tabs, the tab's tools, Keys and the transport. Loop · Song lives in the tempo
    panel; its word is in the readout."""
    o = []
    o.append(box(X + 4, Y + 18, 8, 8, f'background:{TEXT};border-radius:4px;') + tx(X + 22, Y + 12, 'Demo', 15, TEXT, 600))
    o.append(tx(X + 72, Y + 12, '⌄', 13, T2, 700))
    names = ('Pads', 'Timeline', 'Mix')
    tabsel = {'pads': 0, 'timeline': 1, 'mix': 2}[tab]
    ws = [tw(n, 16) + 36 for n in names]
    tabs_w = sum(ws) + 8
    o.append(tabs(X + 110 + tabs_w / 2, Y - 8, names=names, sel=tabsel))
    cx = X + 110 + tabs_w + 16
    if tab != 'mix':
        for t in tools:
            k, kw = key(cx, Y, t, on=(t == 'Loop the song')); o.append(k); cx += kw + 8
        if line: o.append(tx(cx + 4, Y + 13, line, 13, T2))
    o.append(tx(X + W - 300, Y + 10, '▥', 20, T2R))      # Keys
    rx = X + W - 260
    o.append(box(rx, Y - 6, 260, 56, f'background:{WELL};border-radius:12px;'))
    o.append(box(rx + 16, Y + 14, 14, 14, f'background:{REC};border-radius:7px;'))
    o.append(box(rx + 52, Y, 44, 44, f'background:{CONTROL if playing else "transparent"};border-radius:9px;'))
    o.append(tx(rx + 52, Y + 10, '■' if playing else '▶', 18, TEXT, 700, 'width:44px;text-align:center;'))
    o.append(tx(rx + 112, Y + 0, '9 · 3', 22, TEXT, 700, num=True))
    o.append(tx(rx + 112, Y + 27, ('Song' if song_mode else 'Loop'), 12, TEXT, 600))
    o.append(tx(rx + 146, Y + 27, '· 108 BPM', 12, T2R))
    return ''.join(o)

def strip(X, Y, W, text, stop=True):
    """Under the row: a refusal or a note until it's dealt with (Skiff's SongStrip), with Stop where that's the way out."""
    w = tw(text, 15) + (110 if stop else 40)
    x = X + (W - w) / 2
    o = [box(x, Y, w, 48, f'background:{HELD};border-radius:12px;box-shadow:0 12px 28px rgba(0,0,0,.6);'),
         tx(x + 16, Y + 14, text, 15, TEXT)]
    if stop:
        k, _ = key(x + w - 86, Y + 6, 'Stop', w=78, h=36); o.append(k)
    return ''.join(o)

def thumb(x, y, w, h, t, seed=0, alpha=1):
    """A loop's 64 steps as a small picture: notes as short bars (drums: dots on lanes)."""
    o = []
    cols = 32
    cw = w / cols
    for i in range(cols):
        v = (i * 7 + t * 5 + seed * 3) % 11
        if t == 3:
            if i % 4 == 0 or v in (2, 9):
                lane = (0 if i % 8 == 0 else 2 if i % 8 == 4 else (5 if v == 2 else 7))
                o.append(box(x + i * cw + 1, y + h - (lane + 1) * h / 9, max(2, cw - 2), 3, f'background:{COL[t]};opacity:{alpha};border-radius:1px;'))
        elif v in (0, 3, 4, 8):
            ny = y + h * (0.15 + 0.7 * ((i * 13 + t * 17) % 9) / 9)
            o.append(box(x + i * cw + 1, ny, max(3, cw * (2 if v == 3 else 1) - 2), 3, f'background:{COL[t]};opacity:{alpha};border-radius:1px;'))
    return ''.join(o)

def head(x, y, w, h, t, compact=False, selected=False, muted=False, playing=True, step=0.4):
    """The H1 head (board 43), SLOOP's: number, name, sound key, chips, where the loop is, Mute (no Solo)."""
    o = []
    bg = LIFTED if selected else PANEL
    ring = f'box-shadow:0 0 0 2px {TEXT};' if selected else ''
    o.append(box(x, y, w, h, f'background:{bg};border-radius:12px;{ring}'))
    if compact:
        o.append(chip(x + 6, y + 6, t, h - 12, muted))
        o.append(tx(x + h + 4, y + 4, NAMES[t], 15, TEXT if not muted else T2, 600))
        o.append(tx(x + h + 4, y + 22, SOUNDS[t] + ' ⌄', 13, T2R))
        o.append(box(x + w - 50, y + 5, 44, h - 10, f'background:{WELL if muted else CONTROL};border-radius:8px;'))
        o.append(speaker(x + w - 38, y + (h - 20) / 2, CAUTION if muted else T2R, muted))
        return ''.join(o)
    o.append(chip(x + 12, y + 12, t, 44, muted))
    o.append(tx(x + 66, y + 12, NAMES[t], 20, TEXT if not muted else T2, 600))
    o.append(tx(x + 66, y + 38, SOUNDS[t] + '  ⌄', 15, T2R))
    if t == 0: o.append(box(x + 12, y + 66, 56, 22, f'background:{WELL};border-radius:6px;') + tx(x + 12, y + 69, 'ARP', 12, T2R, 600, 'width:56px;text-align:center;'))
    if t == 2: o.append(box(x + 12, y + 66, 64, 22, f'background:{WELL};border-radius:6px;') + tx(x + 12, y + 69, 'CHORD', 12, T2R, 600, 'width:64px;text-align:center;'))
    if playing and not muted:
        o.append(box(x + 12, y + h - 18, w - 96, 4, f'background:{WELL};border-radius:2px;'))
        o.append(box(x + 12, y + h - 18, (w - 96) * step, 4, f'background:{COL[t]};border-radius:2px;'))
        o.append(tx(x + w - 80, y + h - 24, f'{int(step*64)+1}/64' if t != 3 else f'{int(step*16)+1}/16', 12, T2))
    o.append(box(x + w - 56, y + 12, 44, 44, f'background:{WELL if muted else CONTROL};border-radius:8px;' + ('box-shadow:inset 0 2px 0 rgba(0,0,0,.4);' if muted else '')))
    o.append(speaker(x + w - 44, y + 24, CAUTION if muted else T2R, muted))
    return ''.join(o)

def loop_cell(x, y, w, h, t, compact=False, edited=False):
    o = [box(x, y, w, h, f'background:{CONTROL};border-radius:10px;')]
    o.append(thumb(x + 8, y + 6, w - 16, h - 12, t))
    return ''.join(o)

def section_pad(x, y, w, h, k, state, compact=False, bar=0.0, label=None):
    """A section: one tall pad across all four rows. state: empty | stored | playing | waiting | next"""
    o = []
    c = COL[k]
    letter = 'ABCD'[k]
    big = 30 if compact else 64
    if state == 'empty':
        o.append(box(x, y, w, h, f'background:{WELL};border-radius:12px;box-shadow:inset 0 0 0 1px {T3};'))
        o.append(tx(x + 14, y + 10, letter, big, T2, 700, num=True))
        o.append(tx(x + 14, y + (big + 14 if not compact else 46), 'empty', 13, T2))
        return ''.join(o)
    playing = state == 'playing'
    # option A (board 48 A, as Skiff's Timeline): full colour only while it sounds; at rest a 32% tint, a 1.5 pt edge
    if playing:
        o.append(box(x, y, w, h, f'background:{c};border-radius:12px;'))
    elif state == 'loaded':
        o.append(box(x, y, w, h, f'background:{CONTROL};border-radius:12px;box-shadow:inset 0 0 0 3px {c};'))
    else:
        o.append(box(x, y, w, h, f'background:{tint(c)};border-radius:12px;box-shadow:inset 0 0 0 1.5px {c};'))
    fg = ON if playing else TEXT
    o.append(tx(x + 14, y + 10, letter, big, fg, 700, num=True))
    sub = label or {'stored': 'stored', 'playing': 'playing', 'waiting': 'next bar', 'next': 'next', 'loaded': 'loaded'}[state]
    o.append(tx(x + 14, y + (big + 14 if not compact else 46), sub, 13, ON if playing else TEXT, 600 if state in ('playing', 'waiting') else 400))
    if not compact:
        for t in range(4):     # what the section holds isn't readable over the protocol: no pictures inside (S2 note)
            pass
    if playing:
        o.append(box(x + 12, y + h - 18, w - 24, 5, 'background:rgba(16,16,18,.25);border-radius:3px;'))
        o.append(box(x + 12, y + h - 18, (w - 24) * bar, 5, f'background:{ON};border-radius:3px;'))
    if state == 'waiting':
        o.append(box(x - 4, y - 4, w + 8, h + 8, f'border:2px dashed {TEXT};border-radius:16px;'))
    if state == 'next':
        o.append(box(x - 4, y - 4, w + 8, h + 8, f'border:1px solid {T2};border-radius:16px;'))
    return ''.join(o)

def note_dot(x, y, n): return box(x, y, 26, 26, f'background:{CAUTION};border-radius:13px;') + tx(x, y + 4, str(n), 14, ON, 700, 'width:26px;text-align:center;')

def editor(x, y, w, h, t=1, tab_w=237, pos='half'):
    """The editor panel under the divider: the selected track's tint, its tab with carets, the header, step panel, grid."""
    o = []
    tint = f'background:color-mix(in srgb, {COL[t]} 24%, {PAGE});'
    o.append(box(x, y, tab_w, 40, tint + 'border-radius:12px 12px 0 0;'))
    car = {'none': '⌃⌃⌃', 'half': '⌃⌄⌄', 'max': '⌄⌄⌄'}[pos]
    o.append(tx(x, y + 8, car, 18, COL[t], 700, f'width:{tab_w}px;text-align:center;letter-spacing:6px;'))
    o.append(box(x, y + 40, w, h - 40, tint + 'border-radius:0 14px 14px 14px;'))
    hy = y + 52
    o.append(chip(x + 12, hy + 8, t, 28))
    o.append(tx(x + 48, hy + 13, NAMES[t], 15, TEXT, 600))
    o.append(tx(x + 100, hy + 15, '· 64 steps · 1/16', 13, T2))
    k, kw = key(x + w - 200, hy, 'Track knobs', chev=True); o.append(k)
    gy = hy + 56
    gh = y + h - 12 - gy
    o.append(box(x + 12, gy, 296, gh, f'background:{PANEL};border-radius:12px;'))
    o.append(tx(x + 28, gy + 14, 'Step 5', 17, TEXT, 600))
    o.append(tx(x + 28, gy + 40, 'C2 · velocity 96 · gate 50%', 13, T2))
    for i, lab in enumerate(['NOTE', 'VEL', 'GATE', 'PROB']):
        o.append(box(x + 28 + i * 68, gy + 70, 60, 60, f'background:{CONTROL};border-radius:10px;') + tx(x + 28 + i * 68, gy + 78, lab, 11, T2R, 400, 'width:60px;text-align:center;'))
    gx = x + 320
    gw = w - 332
    o.append(box(gx, gy, gw, gh, f'background:{WELL};border-radius:12px;'))
    rows = max(6, int(gh / 22))
    for r in range(rows):
        o.append(box(gx, gy + r * gh / rows, gw, 1, 'background:#1C1C21;'))
    for i in range(16):
        o.append(box(gx + i * gw / 16, gy, 1, gh, f'background:{"#2A2A30" if i % 4 == 0 else "#18181C"};'))
        v = (i * 5 + 3) % 7
        if v in (0, 2, 5):
            o.append(box(gx + i * gw / 16 + 2, gy + gh * (0.2 + 0.1 * ((i * 3) % 6)), gw / 16 * (2 if v == 5 else 1) - 4, max(10, gh / rows - 4), f'background:{COL[t]};border-radius:4px;'))
    o.append(box(gx + gw * 0.31, gy, 2, gh, f'background:{TEXT};opacity:.6;'))
    return ''.join(o)

def frame(x, y, w, h, title):
    return box(x, y, w, h, f'background:{PAGE};border-radius:22px;box-shadow:0 0 0 1px #2A2A30;') + tx(x, y - 34, title, 17, T2R, 600)

def pads_screen(X, Y, layout='full', playing=True):
    """iPad landscape (1376 × 1032): the one row, heads, the loop column, sections A–D; the editor below."""
    W, H = 1376, 1032
    o = [frame(X, Y, W, H, '')]
    P = 24
    o.append(topbar(X + P, Y + P, W - 2 * P, playing=playing, song_mode=0, tab='pads'))
    top = Y + P + 64 + 16 + 20          # the page starts under the row; the columns' labels over it
    hw = 232 if layout != 'full' else 300
    lw = 150 if layout != 'full' else 200
    sx = X + P + hw + 12 + lw + 12
    sw_all = X + W - P - sx
    pw = (sw_all - 3 * 12) / 4
    if layout == 'full':
        rh, gap = 172, 12
        rows_h = 4 * rh + 3 * gap
    else:
        rh, gap = 42, 4
        rows_h = 4 * rh + 3 * gap
    for t in range(4):
        ry = top + t * (rh + gap)
        o.append(head(X + P, ry, hw, rh, t, compact=layout != 'full', selected=(t == 1), muted=(t == 2 and layout == 'full'), playing=playing, step=[0.42, 0.42, 0.42, 0.68][t]))
        o.append(loop_cell(X + P + hw + 12, ry, lw, rh, t))
    o.append(tx(X + P + hw + 12, top - 22, 'The loop now', 12, T2))   # (the amber line over it: changes not in a section)
    o.append(tx(X + P + hw + 12 + 78, top - 22, '· edited', 12, CAUTION))
    o.append(tx(sx, top - 22, 'Sections', 12, T2))
    states = ['stored', 'playing', 'waiting', 'empty']
    for k2 in range(4):
        o.append(section_pad(sx + k2 * (pw + 12), top, pw, rows_h, k2, states[k2], compact=layout != 'full', bar=0.62))
    if layout == 'full':
        ey = top + rows_h + 12
        # shut: the tab alone, all carets up (No grid)
        o.append(box(X + P, Y + H - P - 40, 237, 40, f'background:color-mix(in srgb, {COL[1]} 24%, {PAGE});border-radius:12px 12px 0 0;'))
        o.append(tx(X + P, Y + H - P - 32, '⌃⌃⌃', 18, COL[1], 700, 'width:237px;text-align:center;letter-spacing:6px;'))
        o.append(box(X + P, Y + H - P - 2, W - 2 * P, 2, f'background:color-mix(in srgb, {COL[1]} 24%, {PAGE});'))
    else:
        ey = top + rows_h + 8 + 32 + 8 - 40
        o.append(editor(X + P, ey, W - 2 * P, Y + H - P - ey, t=1, pos='half'))
    return ''.join(o)

def timeline_screen(X, Y, layout='half', song_playing=True):
    W, H = 1376, 1032
    o = [frame(X, Y, W, H, '')]
    P = 24
    o.append(topbar(X + P, Y + P, W - 2 * P, playing=song_playing, song_mode=1, tab='timeline',
                    tools=('SONG REC', 'Loop the song'), line='7 steps · 28 bars' + (' · step 3, bar 2 of 4' if song_playing else '')))
    top = Y + P + 64 + 16
    # ruler
    lx = X + P + 232 + 12
    lwid = X + W - P - lx
    bars = 28
    ppb = lwid / bars
    for b in range(bars + 1):
        if b % 4 == 0:
            o.append(tx(lx + b * ppb + 3, top, str(b + 1), 12, T2, 400, num=True))
        o.append(box(lx + b * ppb, top + 18, 1, 6 if b % 4 else 10, f'background:{T3};'))
    ly = top + 32
    lh = 120 if layout == 'half' else 64
    # the lane head: the song
    o.append(box(X + P, ly, 232, lh, f'background:{PANEL};border-radius:12px;'))
    o.append(tx(X + P + 14, ly + 12, 'Song', 20, TEXT, 600))
    o.append(tx(X + P + 14, ly + 40, 'step 3 of 7 · bar 2 of 4' if song_playing else '7 steps · loops', 13, T2R))
    order = [(0, 4), (0, 4), (1, 4), (2, 2), (1, 4), (2, 2), (3, 8)]
    cx = lx
    for i, (sec, b) in enumerate(order):
        bw = b * ppb - 4
        playing = i == 2 and song_playing
        # option A: at rest a 32% tint with a 1.5 pt edge; full colour only while it plays; the block whose menu is open,
        # flat grey with a 3 pt outline (here block 5 when stopped)
        if playing: st = f'background:{COL[sec]};border-radius:10px;'
        elif i == 4 and not song_playing: st = f'background:{CONTROL};border-radius:10px;box-shadow:inset 0 0 0 3px {COL[sec]};'
        else: st = f'background:{tint(COL[sec])};border-radius:10px;box-shadow:inset 0 0 0 1.5px {COL[sec]};'
        o.append(box(cx, ly, bw, lh, st))
        o.append(tx(cx + 10, ly + 8, 'ABCD'[sec], 30 if layout == 'half' else 22, ON if playing else TEXT, 700, num=True))
        o.append(tx(cx + 10, ly + (48 if layout == 'half' else 34), f'{b} bars', 13, ON if playing else TEXT))
        if i == 3 and song_playing:
            o.append(box(cx - 3, ly - 3, bw + 6, lh + 6, f'border:1px solid {T2};border-radius:13px;'))
            o.append(tx(cx + 10, ly + lh - 30, 'next', 12, T2R))
        cx += bw + 4
    # playhead
    if song_playing:
        phx = lx + (8 + 1.6) * ppb
        o.append(box(phx, top + 16, 2, lh + 22, f'background:{TEXT};'))
    # the section keys under the lane: drag one onto the song, or hold for Add to the song
    ky = ly + lh + 12
    o.append(tx(X + P, ky + 12, 'Add a section', 13, T2))
    for k3 in range(4):
        stored = k3 < 3
        kx = lx + k3 * 92
        o.append(box(kx, ky, 80, 40, (f'background:{tint(COL[k3])};box-shadow:inset 0 0 0 1.5px {COL[k3]};' if stored else f'background:{WELL};box-shadow:inset 0 0 0 1px {T3};') + 'border-radius:9px;'))
        o.append(tx(kx, ky + 6, 'ABCD'[k3] + ('' if stored else ' · empty'), 18 if stored else 13, TEXT if stored else T3, 700 if stored else 400, 'width:80px;text-align:center;', num=stored) if stored else tx(kx, ky + 12, 'D · empty', 13, T2, 400, 'width:80px;text-align:center;'))
    if song_playing:
        o.append(strip(X + P, Y + P + 64 + 4, W - 2 * P, 'Stop the song to change its order'))
    ey = ky + 40 + 12
    o.append(editor(X + P, ey, W - 2 * P, Y + H - P - ey, t=1, pos='half' if layout == 'half' else 'max'))
    return ''.join(o)

def mix_screen(X, Y):
    W, H = 1376, 1032
    o = [frame(X, Y, W, H, '')]
    P = 24
    o.append(topbar(X + P, Y + P, W - 2 * P, tab='mix'))
    ty = Y + P + 64 + 16
    sh = 520
    o.append(box(X + P, ty, W - 2 * P, sh, f'background:{PANEL};border-radius:16px;'))
    sw = (W - 2 * P - 32 - 3 * 8) / 4
    for t in range(4):
        sx = X + P + 16 + t * (sw + 8)
        o.append(box(sx, ty + 16, sw, sh - 32, f'background:{LIFTED if t == 1 else CONTROL};border-radius:12px;' + (f'box-shadow:0 0 0 2px {TEXT};' if t == 1 else '')))
        o.append(chip(sx + 12, ty + 28, t, 32))
        o.append(tx(sx + 52, ty + 34, NAMES[t], 17, TEXT, 600))
        fx = sx + sw / 2 - 22
        o.append(box(fx, ty + 84, 44, 300, f'background:{WELL};border-radius:10px;'))
        lvl = [0.78, 0.7, 0.62, 0.82][t]
        o.append(box(fx, ty + 84 + 300 * (1 - lvl), 44, 300 * lvl, f'background:{COL[t]};border-radius:10px;'))
        o.append(tx(sx, ty + 392, ['−2 dB', '−5 dB', '−9 dB', '0 dB'][t], 15, TEXT, 600, f'width:{sw}px;text-align:center;'))
        o.append(tx(sx + 12, ty + 424, 'PAN  C', 13, T2R))
        o.append(tx(sx + 12, ty + 446, 'REV  24', 13, T2R))
        o.append(box(sx + sw - 64, ty + 420, 52, 36, f'background:{CONTROL if t != 2 else WELL};border-radius:8px;') + tx(sx + sw - 64, ty + 429, 'Mute', 13, CAUTION if t == 2 else T2R, 600, 'width:52px;text-align:center;'))
    cy = ty + sh + 24
    titles = ['DLY', 'REV/CHO', 'MASTER', 'GLOBAL', 'DRUMS', 'TEXTURE']
    o.append(box(X + P, cy, 150, Y + H - P - cy, f'background:{PANEL};border-radius:14px;'))
    for i, tt in enumerate(titles + ['SYSTEM', 'MIDI']):
        o.append(tx(X + P + 16, cy + 14 + i * 34, tt, 14, TEXT if i == 1 else T2, 600 if i == 1 else 400))
    cw = 500
    for i, tt in enumerate(titles[:3]):
        cx = X + P + 166 + i * (cw + 16) - 516
        if cx < X + P + 166: continue
        o.append(box(max(cx, X + P + 166), cy, cw if cx >= X + P + 166 else cw - (X + P + 166 - cx), Y + H - P - cy, f'background:{PANEL};border-radius:14px;opacity:{1 if i == 1 else .55};'))
        if cx >= X + P + 166:
            o.append(tx(cx + 16, cy + 14, tt, 17, TEXT, 600))
            for j, lab in enumerate(['SIZE', 'DAMP', 'CRT', 'CDP'] if i == 1 else ['TIME', 'FDBK', 'COLR', 'MIX']):
                o.append(box(cx + 16 + j * 118, cy + 52, 108, 120, f'background:{CONTROL};border-radius:10px;') + tx(cx + 28 + j * 118, cy + 62, lab, 11, T2))
    return ''.join(o)

def panel_screen(X, Y):
    """FX pressed over Pads at Half: the sound panel from the right; the sounds panel beside it."""
    o = [pads_screen(X, Y, layout='half')]
    W, H, P = 1376, 1032, 24
    o.append(box(X, Y, W, H, 'background:transparent;'))
    pw = 430
    px = X + W - pw
    o.append(box(px, Y + 104, pw, H - 104, f'background:{HELD};border-radius:16px 0 0 16px;box-shadow:-12px 0 28px rgba(0,0,0,.6);'))
    o.append(tx(px + 20, Y + 118, 'FX', 20, TEXT, 600))
    o.append(tx(px + 56, Y + 122, 'T2 Bass · 7 pages', 12, T2R))
    o.append(box(px + 16, Y + 160, pw - 32, 52, f'background:{WELL};border-radius:10px;'))
    o.append(chip(px + 26, Y + 172, 1, 28))
    o.append(tx(px + 64, Y + 168, 'Sub Bass', 15, TEXT, 600))
    o.append(tx(px + 64, Y + 188, 'ANALOG', 12, T2R))
    k, _ = key(px + pw - 130, Y + 164, 'Sounds', chev=True, h=44); o.append(k)
    for i, tt in enumerate(['FX', 'FILTER', 'SLICER', 'INSERT', 'DLY', 'REV/CHO']):
        cy = Y + 228 + i * 112
        if cy + 100 > Y + H - 120: break
        o.append(tx(px + 16, cy, tt, 13, T2R, 600))
        for j in range(4):
            o.append(box(px + 16 + j * 100, cy + 20, 92, 80, f'background:{CONTROL};border-radius:10px;'))
    ky = Y + H - P - 100
    for i, b in enumerate(['FX', 'SEL', 'ENV', 'LFO', 'EDIT', 'ARP', 'GLO', 'SEQ', 'HOME', 'SAVE', '', '']):
        if not b: continue
        o.append(box(px + 16 + (i % 6) * 66, ky + (i // 6) * 50, 60, 44, f'background:{LIFTED if b == "FX" else CONTROL};border-radius:8px;' + (f'box-shadow:0 0 0 2px {TEXT};' if b == 'FX' else '')))
        o.append(tx(px + 16 + (i % 6) * 66, ky + (i // 6) * 50 + 13, b, 12, TEXT, 600, 'width:60px;text-align:center;'))
    return ''.join(o)

def phone_screen(X, Y, view='pads'):
    W, H = 852, 393
    o = [frame(X, Y, W, H, '')]
    P = 8
    # one 44 pt row: the four chips, the tabs, the transport, ⋯
    for t in range(4):
        cx = X + P + 50 + t * 44
        o.append(box(cx, Y + 6, 40, 44, f'background:{COL[t] if t == 1 else CONTROL};border-radius:8px;' + (f'box-shadow:0 0 0 2px {TEXT};' if t == 1 else '')))
        o.append(tx(cx, Y + 14, str(t + 1), 15, ON if t == 1 else TEXT, 600, 'width:40px;text-align:center;'))
    o.append(tabs(X + W / 2 + 20, Y + 2, names=('Pads', 'Timeline', 'Mix', 'Sounds'), sel=0 if view == 'pads' else 1))
    o.append(box(X + W - 160, Y + 6, 44, 44, f'background:{CONTROL};border-radius:8px;') + tx(X + W - 160, Y + 16, '■', 16, TEXT, 700, 'width:44px;text-align:center;'))
    o.append(tx(X + W - 108, Y + 16, '9 · 3', 18, TEXT, 700, num=True))
    o.append(tx(X + W - 36, Y + 14, '⋯', 20, TEXT, 700))
    top = Y + 58
    if view == 'pads':
        rh, gap = 40, 6
        for t in range(4):
            ry = top + t * (rh + gap)
            o.append(box(X + 50, ry, 150, rh, f'background:{LIFTED if t == 1 else PANEL};border-radius:10px;' + (f'box-shadow:0 0 0 2px {TEXT};' if t == 1 else '')))
            o.append(chip(X + 56, ry + 5, t, 30, muted=(t == 2)))
            o.append(tx(X + 92, ry + 10, NAMES[t], 14, TEXT, 600))
            o.append(box(X + 150, ry + 4, 44, 32, f'background:{WELL if t == 2 else CONTROL};border-radius:7px;') + tx(X + 150, ry + 11, 'M', 13, CAUTION if t == 2 else T2R, 600, 'width:44px;text-align:center;'))
        sx = X + 212
        sw = (X + W - 50 - sx - 3 * 8) / 4
        hh = 4 * rh + 3 * gap
        for k in range(4):
            o.append(section_pad(sx + k * (sw + 8), top, sw, hh, k, ['stored', 'playing', 'waiting', 'empty'][k], compact=True, bar=0.6))
        o.append(tx(X + 50, top + hh + 14, 'Loop · Song', 13, T2))
        s, _ = seg(X + 130, top + hh + 4, ['Loop', 'Song'], 0, h=36); o.append(s)
        k2, _ = key(X + 290, top + hh + 4, 'SONG REC', h=36); o.append(k2)
        o.append(tx(X + 410, top + hh + 14, 'Hold a section: store, add to the song, clear', 13, T2))
    else:
        lx = X + 50 + 120
        lw = X + W - 50 - lx
        ppb = lw / 28
        o.append(box(X + 50, top + 24, 112, 96, f'background:{PANEL};border-radius:10px;'))
        o.append(tx(X + 60, top + 34, 'Song', 16, TEXT, 600))
        o.append(tx(X + 60, top + 58, 'step 3 of 7', 12, T2R))
        cx = lx
        for i, (sec, b) in enumerate([(0, 4), (0, 4), (1, 4), (2, 2), (1, 4), (2, 2), (3, 8)]):
            bw = b * ppb - 3
            pl = i == 2
            o.append(box(cx, top + 24, bw, 96, f'background:{COL[sec] if pl else CONTROL};border-radius:8px;'))
            if not pl: o.append(box(cx, top + 114, bw, 6, f'background:{COL[sec]};border-radius:0 0 8px 8px;'))
            o.append(tx(cx + 6, top + 30, 'ABCD'[sec], 20, ON if pl else TEXT, 700, num=True))
            o.append(tx(cx + 6, top + 56, f'{b}', 12, ON if pl else T2R))
            cx += bw + 3
        o.append(box(lx + 9.6 * ppb, top + 16, 2, 112, f'background:{TEXT};'))
        o.append(tx(X + 50, top + 140, 'Tap a block for its menu (section, bars, duplicate, delete); hold and drag to move it.', 13, T2))
    return ''.join(o)

def legend(x, y, items, w=1300):
    o = []
    for i, (n, t) in enumerate(items):
        o.append(note_dot(x, y + i * 46, n))
        o.append(wrap(x + 40, y + i * 46 + 2, w - 40, t, 14))
    return ''.join(o)

def page(name, title, BW, BH, parts):
    body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:#16161A;color:{TEXT};{FONT}overflow:hidden;">{"".join(parts)}</div>'
    doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{html.escape(title)}</title>
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
    open(os.path.join(OUT, name), 'w').write(doc)
    print(name, BW, BH)

# ---- S1: where SLOOP's four tabs go ----
def s1():
    BW, BH = 1600, 900
    o = [tx(40, 32, 'SLOOP today → the Skiff tabs', 28, TEXT, 700),
         wrap(40, 76, 1500, 'Left: SLOOP-Lupe’s four tabs as built (iPad and phone). Right: where each one lands in Song · Mix and its panels. The arrows are the whole move; nothing SLOOP can do is dropped, and nothing it can’t do is added.', 16)]
    old = [('Sequence', 'piano roll / drum grid · step panel · track knobs · the track box with 64-step timelines'),
           ('Shape', 'every button’s pages: FX SEL ENV LFO EDIT ARP GLO SEQ'),
           ('Arrange', 'section keys A–D · the song order as blocks · Loop / Song · SONG REC'),
           ('Browse', 'engines · presets · user presets · kits on T4 · user samples')]
    new = [('Song › editor', 'under the divider: No grid · Half · Max; the track box becomes the track heads', 'Skiff: the editor panel, its tab and carets'),
           ('Sound panel  ·  Mix', 'FX SEL ENV LFO EDIT ARP over the tab that’s up; GLO’s pages on Mix', 'Skiff: the sound panel; MixerPage as it is'),
           ('Song › Pads  ·  Timeline', 'sections as tall pads (waiting outline, next); the order as one lane of blocks', 'Skiff: pads, outlines, lanes, fan menus'),
           ('Sounds panel', 'from the track head’s name “Sub Bass ⌄”, SAVE, the sound panel', 'Skiff: PresetsPanel, the same views')]
    for i, ((a, b), (c, d, e)) in enumerate(zip(old, new)):
        y = 150 + i * 170
        o.append(box(40, y, 560, 140, f'background:{PANEL};border-radius:14px;'))
        o.append(tx(64, y + 20, a, 24, TEXT, 600))
        o.append(wrap(64, y + 60, 510, b, 15, T2R))
        o.append(tx(630, y + 52, '→', 36, T2, 700))
        o.append(box(700, y, 860, 140, f'background:{LIFTED};border-radius:14px;'))
        o.append(tx(724, y + 20, c, 24, TEXT, 600))
        o.append(wrap(724, y + 58, 800, d, 15, T2R))
        o.append(wrap(724, y + 100, 800, e, 13, T2))
    o.append(wrap(40, 840, 1500, '<b style="color:#EDEDF0">Left out on purpose:</b> pattern numbers, the pool, chains, scenes, per-track launches, launch quantize and Solo. SLOOP has none of them, so none is drawn.', 15))
    page('SloopMap.dc.html', 'SLOOP map', BW, BH, o)

# ---- S2: Pads at full (No grid) and Half ----
def s2():
    BW, BH = 2952, 1520
    o = [tx(40, 30, 'Song › Pads on SLOOP: the sections, with the loop and the track heads', 28, TEXT, 700)]
    o.append(tx(40, 104, 'No grid (the editor shut), playing: B playing, C asked for, T3 muted', 17, T2R, 600))
    o.append(pads_screen(40, 140, 'full'))
    o.append(tx(1536, 104, 'Half (the default): heads as lane rows, the sections as tall pads, the editor below', 17, T2R, 600))
    o.append(pads_screen(1536, 140, 'half'))
    o.append(legend(40, 1204, [
        (1, '<b style="color:#EDEDF0">A section is one tall pad across all four rows</b>, because on SLOOP a section holds every track at once. A grid of track × section cells would suggest each track launches on its own, which SLOOP can’t do.'),
        (2, '<b style="color:#EDEDF0">Waiting:</b> the dashed outline and “next bar”, as Skiff’s launches (SLOOP always lands a section on the next bar; there is no Launch at). The song’s next, in song mode, gets the thin grey outline and “next”.'),
        (3, '<b style="color:#EDEDF0">The loop now</b> is its own column: SLOOP’s tracks play a working loop that isn’t any section until it’s stored. The amber line says the tracks have changes that aren’t in a section (loading one asks first, in place).'),
        (4, '<b style="color:#EDEDF0">Track heads</b> are Skiff’s H1: number, name, the sound key “Sub Bass ⌄” (the sounds panel), chips (ARP, CHORD), where the loop is (step of 64). Mute only: SLOOP has no solo, so none is drawn.'),
        (5, '<b style="color:#EDEDF0">Hold a section</b> for its fan menu at the finger: Store the loop here (over a stored one it asks in place), Add to the song, Clear (stopped only, the destructive confirm in its own row).'),
        (6, 'No pictures inside the section pads: what a section holds can’t be read over the protocol (only whether it’s stored). The loop column carries the pictures instead.'),
    ], w=2860))
    page('SloopPads.dc.html', 'SLOOP pads', BW, BH, o)

# ---- S3: Timeline ----
def s3():
    BW, BH = 2952, 1470
    o = [tx(40, 30, 'Song › Timeline on SLOOP: the song order as one lane', 28, TEXT, 700)]
    o.append(tx(40, 104, 'Half, song mode, playing: step 3 (B) playing, C next', 17, T2R, 600))
    o.append(timeline_screen(40, 140, 'half', True))
    o.append(tx(1536, 104, 'Max (the editor largest), stopped: the lane shrinks to 64 pt', 17, T2R, 600))
    o.append(timeline_screen(1536, 140, 'max', False))
    o.append(legend(40, 1204, [
        (1, '<b style="color:#EDEDF0">One lane, not six:</b> SLOOP’s song is one order of sections, every track following it. Blocks are as wide as their bars on one ruler, as on Skiff’s Timeline, in the section’s colour.'),
        (2, '<b style="color:#EDEDF0">Editing the order:</b> tap a block for its menu (section, bars, duplicate, delete), hold and drag to move, drag its right edge for bars; drag a section key onto the lane to add one (or its menu’s Add to the song).'),
        (3, '<b style="color:#EDEDF0">While the song plays</b> the FM-1 refuses a new order: the strip under the lane says so and carries Stop, as Skiff’s stop-to-rearrange does. Nothing is dimmed without a reason on screen.'),
        (4, '<b style="color:#EDEDF0">The one row</b> (board 47 b): Pads · Timeline · Mix, then the tab’s tools: SONG REC and “Loop the song” (the order’s own setting). Loop · Song is in the tempo panel, as Skiff’s playback mode is; the readout says which. Refusals sit in the strip under the row, with Stop. Built as wrapping blocks for now (Q3: the ruler).'),
    ], w=2860))
    page('SloopTimeline.dc.html', 'SLOOP timeline', BW, BH, o)

# ---- S4: Mix and the sound panel ----
def s4():
    BW, BH = 2952, 1380
    o = [tx(40, 30, 'Mix, and a function key’s pages over Song', 28, TEXT, 700)]
    o.append(tx(40, 104, 'Mix: four strips, then DLY, REV/CHO and the GLO pages (Skiff’s MixerPage as it is)', 17, T2R, 600))
    o.append(mix_screen(40, 140))
    o.append(tx(1536, 104, 'FX pressed on the FM-1 over Pads at Half: the sound panel from the right', 17, T2R, 600))
    o.append(panel_screen(1536, 140))
    o.append(legend(40, 1204, [
        (1, '<b style="color:#EDEDF0">Shape goes</b>: its buttons’ pages arrive on the sound panel over whichever tab is up (FX, SEL, ENV, LFO, EDIT, ARP), as on Skiff. GLO’s pages go to Mix.'),
        (2, '<b style="color:#EDEDF0">Question for Scott:</b> SYSTEM and MIDI 1–3 are setup, not mixing. Keep them at the end of Mix’s carousel (today’s Shape › GLO has them all), or move them to Settings?'),
        (3, 'The panel’s “Sounds ⌄” and the head’s “Sub Bass ⌄” open the sounds panel beside it, so a sound can be picked and shaped at once (Skiff’s non-modal panel).'),
    ], w=2860))
    page('SloopMix.dc.html', 'SLOOP mix', BW, BH, o)

# ---- S5: the phone ----
def s5():
    BW, BH = 1904, 640
    o = [tx(40, 30, 'The phone (852 × 393), where it differs: Pads · Timeline · Mix · Sounds (mock only)', 28, TEXT, 700)]
    o.append(tx(40, 104, 'Pads: heads shrink to the number, name and Mute; the sections as four tall pads', 17, T2R, 600))
    o.append(phone_screen(40, 140, 'pads'))
    o.append(tx(1012, 104, 'Timeline: the order, the editor up on its own tab as today', 17, T2R, 600))
    o.append(phone_screen(1012, 140, 'timeline'))
    o.append(wrap(40, 560, 1820, '<b style="color:#EDEDF0">Not built in this pass.</b> The phone’s Skiff tabs are being reworked on another branch (Pads · Timeline · Mix · Sounds); SLOOP’s phone should follow that work rather than run ahead of it. The phone keeps Sounds as a tab, as Skiff’s does.', 15))
    page('SloopPhone.dc.html', 'SLOOP phone', BW, BH, o)

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    s1(); s2(); s3(); s4(); s5()

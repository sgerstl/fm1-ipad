# Board 47: everything above the Pads grid in one row (Scott, 2026-11-10: "let's redesign the layout from the top of the
# pads up... it seems a bit of a mess. I'd love if we could find a way to condense it into one row. what options do we
# have?"). Today: the top bar (64) and the Pads tool row (44 + 8 under it): the first pad at 156 pt. One row: at 104.
# Three directions, each at iPad landscape (1376) and portrait (1032), real labels, real 44 pt keys.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, T3, ON, SEL = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#71717A', '#101012', '#3A3A42'
REC, NOTE = '#FF4D4D', '#FFB54A'
COL = {1: '#FF5A36', 2: '#22C3B4', 3: '#FFBF00', 4: '#9580FF', 5: '#FF6FAE', 6: '#A3E635'}
FONT = "font-family:'Barlow',-apple-system,system-ui,sans-serif;"
NUM = "font-family:'Barlow Condensed','Barlow',sans-serif;"

def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{FONT}{extra}">{html.escape(s)}</div>'
def wrap(x, y, w, s, size, c, wt=400): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.4;{FONT}">{s}</div>'
def tw(s, size): return int(len(s) * size * 0.5) + 2      # Barlow's average advance, about half the size

ICON = {   # 20 pt line icons, one stroke weight (SF-like)
    'folder': '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    'keys': '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M8 5v9M12 5v9M16 5v9"/>',
    'audio': '<path d="M4 10h3l4-3v10l-4-3H4z"/><path d="M15 9.5a3.5 3.5 0 0 1 0 5M17.5 7a7 7 0 0 1 0 10"/>',
    'list': '<path d="M5 7h10M5 12h14M5 17h8"/>',
    'grid': '<rect x="5" y="5" width="6" height="6" rx="1"/><rect x="13" y="5" width="6" height="6" rx="1"/><rect x="5" y="13" width="6" height="6" rx="1"/><rect x="13" y="13" width="6" height="6" rx="1"/>',
    'pool': '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
    'more': '<circle cx="6" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="18" cy="12" r="1.3"/>',
    'x': '<path d="M7 7l10 10M17 7L7 17"/>',
    'loop': '<path d="M17 7H8a4 4 0 0 0 0 8M7 17h9a4 4 0 0 0 0-8"/><path d="M15 4l2 3-2 3M9 14l-2 3 2 3"/>',
}
def icon(x, y, k, c=TEXT, s=20):
    return f'<svg style="position:absolute;left:{x}px;top:{y}px" width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{ICON[k]}</svg>'

def key(x, y, label, w=None, ic=None, dim=False, chev=False, h=44, latched=False):
    c = T3 if dim else TEXT
    lw = tw(label, 15) if label else 0
    w = w or ((20 + (8 if label else 0) if ic else 0) + lw + (14 if chev else 0) + 28)
    o = [box(x, y, w, h, f'background:{SEL if latched else PAD};border-radius:9px;box-shadow:inset 0 1px 0 rgba(255,255,255,.06);')]
    cx = x + 14
    if ic:
        if not label and not chev: cx = x + (w - 20) / 2
        o.append(icon(cx, y + (h - 20) / 2, ic, c)); cx += 28
    if label: o.append(tx(cx, y + (h - 18) / 2, label, 15, c)); cx += lw + 4
    if chev: o.append(tx(cx, y + (h - 16) / 2, '⌄', 13, T2, 700))
    return ''.join(o), w

def seg(x, y, opts, sel, caption=None, h=44):
    o, cx = [], x + 4
    pad_l = 0
    if caption:
        pad_l = tw(caption, 12) + 14
    ws = [tw(s, 15) + 26 for s in opts]
    w = pad_l + sum(ws) + 8
    o.append(box(x, y, w, h, f'background:{WELL};border-radius:10px;'))
    if caption: o.append(tx(x + 10, y + (h - 15) / 2, caption, 12, T2)); cx += pad_l
    for i, (s, sw) in enumerate(zip(opts, ws)):
        if i == sel: o.append(box(cx, y + 4, sw, h - 8, f'background:{SEL};border-radius:7px;'))
        o.append(tx(cx, y + (h - 18) / 2, s, 15, TEXT if i == sel else T2, 600 if i == sel else 400, f'width:{sw}px;text-align:center;'))
        cx += sw
    return ''.join(o), w

def tabs(x, y, names=('Song', 'Mix'), sel=0):
    o, cx = [], x
    ws = [tw(n, 16) + 36 for n in names]
    w = sum(ws) + 4 * (len(names) - 1)
    o.append(box(x, y + 41, w, 3, f'background:#3A3A42;border-radius:2px;'))
    for i, (n, nw) in enumerate(zip(names, ws)):
        if i == sel: o.append(box(cx, y + 2, nw, 42, f'background:{SEL};border-radius:9px 9px 0 0;'))
        o.append(tx(cx, y + 12, n, 16, TEXT if i == sel else T2, 600 if i == sel else 400, f'width:{nw}px;text-align:center;'))
        cx += nw + 4
    return ''.join(o), w

def toggle(x, y, sel=1):
    w = 2 * 44 + 8
    o = [box(x, y, w, 44, f'background:{WELL};border-radius:10px;'),
         box(x + 4 + sel * 44, y + 4, 44, 36, f'background:{SEL};border-radius:7px;')]
    o.append(icon(x + 4 + 12, y + 12, 'list', TEXT if sel == 0 else T2)); o.append(icon(x + 48 + 12, y + 12, 'grid', TEXT if sel == 1 else T2))
    return ''.join(o), w

def conn(x, y, label='Demo', chev=False, sub=None):
    lw = tw(label, 15) if label else 0
    w = 44 if not label else 14 + 8 + 10 + lw + (16 if chev else 0) + 10
    o = [box(x + (w - 8) / 2 if not label else x + 14, y + 18, 8, 8, f'background:{TEXT};border-radius:4px;')]
    if label:
        o.append(tx(x + 32, y + 12, label, 15, TEXT, 600))
        if chev: o.append(tx(x + 34 + lw, y + 13, '⌄', 13, T2, 700))
    return ''.join(o), w

def transport(x, y, mode=None):
    w = 4 + 44 + 4 + 44 + 4 + 84 + 4
    o = [box(x, y - 4, w, 52, f'background:{WELL};border-radius:12px;')]
    o.append(box(x + 4 + 15, y + 15, 14, 14, f'background:{REC};border-radius:7px;'))
    o.append(box(x + 52, y, 44, 44, f'background:{PAD};border-radius:9px;'))
    o.append(f'<svg style="position:absolute;left:{x + 64}px;top:{y + 12}px" width="20" height="20" viewBox="0 0 24 24"><path d="M7 4l13 8-13 8z" fill="{TEXT}"/></svg>')
    o.append(tx(x + 104, y + 1, '12 · 3', 20, TEXT, 700, NUM))
    o.append(tx(x + 104, y + 25, ('120 BPM · ' + mode) if mode else '120 BPM', 12, T2))
    return ''.join(o), w + (24 if mode else 0)

def cancel(x, y, n=3, compact=False):
    if compact:
        s, w = key(x, y, f'{n}', ic='x')
    else:
        s, w = key(x, y, f'Cancel {n} waiting')
    return s, w

# ---------------------------------------------------------------------------------------------------------------------
parts = []
WIDTHS = []
def row(items, x0, y, width, gap=8):
    """items: list of ('L'|'R', fn) or ('|',) group breaks. Left items from x0, right ones from the far edge."""
    left = [it for it in items if it[0] == 'L']; right = [it for it in items if it[0] == 'R']
    o, cx = [], x0
    for it in left:
        if it[1] == 'gap': cx += it[2]; continue
        s, w = it[1](cx, y); o.append(s); cx += w + gap
    used = cx - x0
    rx = x0 + width
    for it in reversed(right):
        if it[1] == 'gap': rx -= it[2]; continue
        s, w = it[1](0, y)            # measure
        rx -= w
        s, w = it[1](rx, y); o.append(s); rx -= gap
    used += x0 + width - rx
    WIDTHS.append(used)
    return ''.join(o), used

def frame(x, y, w, label, inner):
    """An iPad screen strip: the page, the bar, the start of the grid under it."""
    o = [box(x, y, w, 270, f'background:{PAGE};border:1px solid #2A2A30;border-radius:18px;overflow:hidden;')]
    o.append(tx(x, y - 26, label, 13, T2, 600))
    o.append(inner)
    return ''.join(o)

def grid_hint(x, y, w, top):
    """The first pad row, at `top` below the screen's top, to show what the grid gains."""
    o = []
    hy = y + top
    o.append(box(x + 24, hy, 236, 86, f'background:{COL[1]}3D;border-radius:19px;'))
    o.append(box(x + 36, hy + 8, 44, 44, f'background:{COL[1]};border-radius:11px;'))
    o.append(tx(x + 36, hy + 18, '1', 22, ON, 700, f'width:44px;text-align:center;{NUM}'))
    o.append(tx(x + 88, hy + 6, 'A 01', 26, TEXT, 700, NUM)); o.append(tx(x + 36, hy + 58, 'Acid ⌄', 15, '#C8C8CF'))
    px = x + 272
    for k in range(10):
        pw = 134
        if px + pw > x + w - 24: break
        o.append(box(px, hy, pw, 104, f'background:{COL[1] if k == 0 else PAD};border-radius:16px;'))
        o.append(tx(px + 10, hy + 8, 'ABCDEFGH'[k], 13, ON if k == 0 else T2, 600))
        o.append(tx(px + 10, hy + 26, ['01', '02', '03', '02', '03', '04', '', ''][k] or 'Empty', 22 if k < 6 else 13, ON if k == 0 else (TEXT if k < 6 else T3), 700 if k < 6 else 400, NUM if k < 6 else ''))
        px += pw + 6
    o.append(tx(x + w - 230, y + 248, f'first pad at {top} pt', 12, NOTE, 600, 'width:206px;text-align:right;'))
    return ''.join(o)

LW, PW = 1376, 1032
X1, X2 = 40, 40 + LW + 60
BW = X2 + PW + 40

def title(y, h1, sub):
    parts.append(tx(40, y, h1, 26, TEXT, 700)); parts.append(wrap(40, y + 38, 2300, sub, 15, T2))

parts.append(tx(40, 32, '47 · Everything above the Pads in one row: today, and three ways to get there', 30, TEXT, 700))
parts.append(wrap(40, 78, 2400, 'iPad landscape (1376 pt) on the left, portrait (1032 pt) on the right, at 1:1. Every key is 44 pt high. Under each bar, the first pad row, at the height it lands. '
              'Today it lands at <b style="color:#EDEDF0">156 pt</b>. One row puts it at <b style="color:#EDEDF0">104 pt</b>: 52 pt back for the grid, a third of a Half row more for each of the six tracks. Pick one; nothing is built.', 15, T2))

# ---- today ----
Y = 190
title(Y, 'Today: two rows', 'The top bar (64 pt), a 16 pt gap, then the Pads tool row (44 pt and 8 under it). About 1,650 pt of controls for 1,328 pt of room in landscape, so they wrap onto a second row. Portrait already crowds.')
def today(x, w, portrait=False):
    o = []
    y0 = Y + 120
    inner_w = w - 48
    s, _ = row([('L', lambda a, b: conn(a, b, 'Demo')), ('L', lambda a, b: key(a, b, '', ic='folder', w=44)), ('L', 'gap', 60 if not portrait else 8),
                ('L', lambda a, b: tabs(a, b)),
                ('R', lambda a, b: seg(a, b, ['Loop entry', 'Play song', 'Play once'], 1)), ('R', lambda a, b: key(a, b, '', ic='audio', w=44)),
                ('R', lambda a, b: key(a, b, '', ic='keys', w=44)), ('R', lambda a, b: transport(a, b))], x + 24, y0 + 10, inner_w, 10)
    o.append(s)
    y1 = y0 + 10 + 80
    s, _ = row([('L', lambda a, b: toggle(a, b)),
                ('R', lambda a, b: key(a, b, 'Patterns', ic='pool')), ('R', lambda a, b: (tx(a, b + 13, 'Launch at', 13, T2), 62)),
                ('R', lambda a, b: seg(a, b, ['Loop', 'Bar', 'Beat', 'Now'], 1)), ('R', lambda a, b: cancel(a, b))], x + 24, y1, inner_w, 10)
    o.append(s)
    return ''.join(o)
parts.append(frame(X1, Y + 110, LW, 'Landscape, today', today(X1, LW)))
parts.append(grid_hint(X1, Y + 110, LW, 152))
parts.append(frame(X2, Y + 110, PW, 'Portrait, today (the song mode runs into the tabs)', today(X2, PW, True)))
parts.append(grid_hint(X2, Y + 110, PW, 152))

# ---- inventory table ----
IY = Y + 400
parts.append(tx(40, IY, 'What’s there, and when it’s used', 20, TEXT, 700))
INV = [
    ('Connection dot (“Demo” on the demo), its menu', 'Top bar', '44', 'Glance', 'Setup: pick the FM-1 or the demo, firmware, settings'),
    ('Projects (folder)', 'Top bar', '44', 'Rare', 'Setup: load and save the FM-1’s 4 slots and the iPad’s projects'),
    ('Song · Mix tabs', 'Top bar', '44', 'Sometimes', 'Both: Mix for a level mid-set'),
    ('Song mode: Loop entry · Play song · Play once', 'Top bar', '44', 'Sometimes', 'Mostly setup. The FM-1 applies it at once, so switching to Loop entry to hold a section is a real mid-set move'),
    ('iPad audio', 'Top bar', '44', 'Never', 'Setup: hear the FM-1 through the iPad'),
    ('Keys (the keyboard drawer)', 'Top bar', '44', 'Rare', 'Writing: audition and play notes in'),
    ('REC', 'Top bar', '44', 'Rare', 'Writing: record into a pattern'),
    ('Play / Stop (hold: from the start)', 'Top bar', '44', 'Always', 'The set'),
    ('Position over tempo (12 · 3, 120 BPM)', 'Top bar', '44', 'Glance', 'The set'),
    ('Pads / Timeline', 'Tool row', '44', 'Sometimes', 'Both'),
    ('Patterns (the pool panel)', 'Tool row', '44', 'Often', 'Writing, and dragging a pattern onto a pad mid-set'),
    ('Launch at: Loop · Bar · Beat · Now', 'Tool row', '44', 'Sometimes', 'The set: matters only while playing (stopped, a pad moves the track at once)'),
    ('Cancel N waiting', 'Tool row', '44', 'At once, when needed', 'The set: only while playing (nothing waits while stopped)'),
    ('A refusal or scene line (“Stop to rearrange…” with Stop)', 'Tool row, left', 'flex', 'When it happens', 'Both. It carries an action, so it can’t be a toast that disappears'),
]
cols = [40, 520, 640, 700, 860]
heads = ['Element', 'Where today', 'Height', 'In a set', 'Set or setup']
for c, hname in zip(cols, heads): parts.append(tx(c, IY + 36, hname, 12, T2, 600))
for i, r in enumerate(INV):
    yy = IY + 60 + i * 26
    for c, v in zip(cols, r): parts.append(tx(c, yy, v, 14, TEXT if c in (40, 700) else '#C8C8CF', 600 if c == 700 else 400))
parts.append(wrap(1400, IY + 36, 1100, '<b style="color:#EDEDF0">Not up there:</b> the FM-1’s function keys (FX…SEQ) live in the sound panel’s foot, or the rail down the right when Settings › Sound buttons is on. Scenes are under the grid. The Pads/Timeline toggle sits in the heads’ column. '
              'At Half the top is the same; only the grid under it changes.<br><br><b style="color:#EDEDF0">The constraints:</b> 44 pt keys; Cancel one tap away and in the same place while playing; nothing only by gesture; the same row has to work on the phone; and it has to survive Dynamic Type (the accessibility pass found Lupe ignores it). '
              'Every direction below answers Dynamic Type, portrait and the phone the same way: the row is one <i>ViewThatFits</i> with a fixed collapse order: (1) “Launch at” loses its word, (2) Patterns becomes its icon, (3) Cancel becomes ✕ N, (4) Launch at becomes one “Bar ⌄” menu key, (5) the song mode becomes its icon. The tabs, Play and Cancel never collapse.', 14, T2))

# ---- the three directions ----
def direction(y, letter, name, sub, land, port, moved, cost, mode=None):
    title(y, f'({letter}) {name}', sub)
    parts.append(frame(X1, y + 110, LW, 'Landscape', land(X1, y + 120, LW - 48)))
    parts.append(grid_hint(X1, y + 110, LW, 100))
    parts.append(frame(X2, y + 110, PW, 'Portrait', port(X2, y + 120, PW - 48)))
    parts.append(grid_hint(X2, y + 110, PW, 100))
    parts.append(wrap(X1, y + 400, 1300, moved, 14, '#C8C8CF'))
    parts.append(wrap(X2, y + 400, 1000, cost, 14, '#C8C8CF'))

D1 = Y + 860
def a_land(x, y, w):
    s, _ = row([('L', lambda a, b: conn(a, b, 'Demo')), ('L', lambda a, b: key(a, b, '', ic='folder', w=44)), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)),
                ('L', 'gap', 12),
                ('L', lambda a, b: key(a, b, 'Play song', chev=True)), ('L', lambda a, b: seg(a, b, ['Loop', 'Bar', 'Beat', 'Now'], 1)), ('L', lambda a, b: cancel(a, b, compact=True)),
                ('R', lambda a, b: key(a, b, '', ic='pool', w=44)), ('R', lambda a, b: key(a, b, '', ic='audio', w=44)), ('R', lambda a, b: key(a, b, '', ic='keys', w=44)), ('R', lambda a, b: transport(a, b))], x + 24, y + 10, w, 8)
    return s
def a_port(x, y, w):
    s, _ = row([('L', lambda a, b: conn(a, b, '')), ('L', lambda a, b: key(a, b, '', ic='folder', w=44)), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)),
                ('L', lambda a, b: key(a, b, '', ic='loop', chev=True)), ('L', lambda a, b: key(a, b, 'Bar', chev=True)), ('L', lambda a, b: cancel(a, b, compact=True)),
                ('R', lambda a, b: key(a, b, '', ic='pool', w=44)), ('R', lambda a, b: key(a, b, '', ic='keys', w=44)), ('R', lambda a, b: transport(a, b))], x + 24, y + 10, w, 6)
    return s
direction(D1, 'a', 'Everything stays, everything shrinks',
          'Nothing leaves the row: navigation, then the set (song mode, launch, cancel), then the tools and the transport. Words give way to icons.',
          a_land, a_port,
          '<b style="color:#EDEDF0">What moved:</b> the song mode’s three keys become one “Play song ⌄” key (a menu of the three); Patterns, iPad audio and Keys are icons; Cancel is “✕ 3”. In portrait Launch at is a “Bar ⌄” menu, the song mode its icon, and iPad audio goes into the connection menu (there’s no room for it).',
          '<b style="color:#EDEDF0">One tap further:</b> the song mode (two taps: open, pick). In portrait, Launch at and iPad audio too.<br><b style="color:#EDEDF0">The cost:</b> the densest row. Six icon keys in a line read as a toolbar you have to learn; “✕ 3” is less clear than “Cancel 3 waiting” at the moment you need it most. Twelve controls in one line is the busiest of the three, the opposite of less mess. It measures 1,170 of 1,328 pt in landscape: the most room left for larger text of the three, and enough to spell out “Cancel 3 waiting” (1,254).')

D2 = D1 + 580
def b_land(x, y, w):
    s, _ = row([('L', lambda a, b: conn(a, b, 'Demo', chev=True)), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)), ('L', lambda a, b: key(a, b, 'Patterns', ic='pool')),
                ('L', 'gap', 16),
                ('L', lambda a, b: seg(a, b, ['Loop', 'Bar', 'Beat', 'Now'], 1, caption='Launch at')), ('L', lambda a, b: cancel(a, b)),
                ('R', lambda a, b: key(a, b, '', ic='keys', w=44)), ('R', lambda a, b: transport(a, b, mode='Song'))], x + 24, y + 10, w, 8)
    return s
def b_port(x, y, w):
    s, _ = row([('L', lambda a, b: conn(a, b, 'Demo', chev=True)), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)), ('L', lambda a, b: key(a, b, '', ic='pool', w=44)),
                ('L', lambda a, b: key(a, b, 'Bar', chev=True)), ('L', lambda a, b: cancel(a, b, compact=True)),
                ('R', lambda a, b: transport(a, b, mode='Song'))], x + 24, y + 10, w, 8)
    return s
direction(D2, 'b', 'The set in the row, setup behind the connection key',
          'The row keeps what a set and a writing session use; what you set once goes into the menu that already holds the FM-1 and the demo (“Demo ⌄”).',
          b_land, b_port,
          '<b style="color:#EDEDF0">What moved:</b> into the connection menu: Projects, the song mode (its three as checkable rows), iPad audio. The current song mode stays visible under the tempo (“120 BPM · Song”, “· Loop”, “· Once”). REC sits beside Play as now. Full words in landscape: Patterns, Launch at, Cancel 3 waiting. In portrait: Patterns its icon, Launch at a “Bar ⌄” menu, Cancel “✕ 3”, Keys into the menu.',
          '<b style="color:#EDEDF0">One tap further:</b> Projects, the song mode and iPad audio (open the menu, pick).<br><b style="color:#EDEDF0">The cost:</b> a mid-set switch to Loop entry is two taps, not one, from a menu that isn’t where you’d look. The connection key becomes “everything else”, which is a junk-drawer risk. It measures 1,220 of 1,328 pt in landscape (108 spare), so larger text collapses Launch at to its “Bar ⌄” menu a little sooner than in (a).')

D3 = D2 + 580
def c_land(x, y, w, playing=False):
    if playing:
        items = [('L', lambda a, b: conn(a, b, 'Demo', chev=True)), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)), ('L', lambda a, b: key(a, b, 'Patterns', ic='pool')),
                 ('L', 'gap', 16), ('L', lambda a, b: seg(a, b, ['Loop', 'Bar', 'Beat', 'Now'], 1, caption='Launch at')), ('L', lambda a, b: cancel(a, b)),
                 ('R', lambda a, b: key(a, b, '', ic='loop', chev=True)), ('R', lambda a, b: transport(a, b))]
    else:
        items = [('L', lambda a, b: conn(a, b, 'Demo', chev=True)), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)), ('L', lambda a, b: key(a, b, 'Patterns', ic='pool')),
                 ('L', 'gap', 16), ('L', lambda a, b: seg(a, b, ['Loop entry', 'Play song', 'Play once'], 1)), ('L', lambda a, b: key(a, b, '', ic='folder', w=44)),
                 ('R', lambda a, b: key(a, b, '', ic='audio', w=44)), ('R', lambda a, b: key(a, b, '', ic='keys', w=44)), ('R', lambda a, b: transport(a, b))]
    s, _ = row(items, x + 24, y + 10, w, 8)
    return s
def c_port(x, y, w, playing=False):
    if playing:
        items = [('L', lambda a, b: conn(a, b, '')), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)), ('L', lambda a, b: key(a, b, '', ic='pool', w=44)),
                 ('L', lambda a, b: seg(a, b, ['Loop', 'Bar', 'Beat', 'Now'], 1)), ('L', lambda a, b: cancel(a, b, compact=True)),
                 ('R', lambda a, b: key(a, b, '', ic='loop', chev=True)), ('R', lambda a, b: transport(a, b))]
    else:
        items = [('L', lambda a, b: conn(a, b, '')), ('L', lambda a, b: tabs(a, b)), ('L', lambda a, b: toggle(a, b)), ('L', lambda a, b: key(a, b, '', ic='pool', w=44)),
                 ('L', lambda a, b: key(a, b, 'Play song', chev=True)), ('L', lambda a, b: key(a, b, '', ic='folder', w=44)),
                 ('R', lambda a, b: key(a, b, '', ic='audio', w=44)), ('R', lambda a, b: key(a, b, '', ic='keys', w=44)), ('R', lambda a, b: transport(a, b))]
    s, _ = row(items, x + 24, y + 10, w, 8)
    return s
title(D3, '(c) The row changes with Play', 'Stopped, the middle of the row is for setting up: the song mode, Projects, iPad audio, Keys. Playing, it becomes Launch at and Cancel, which only mean anything while playing (stopped, a pad moves the track at once and nothing waits). Top: stopped. Bottom: playing.')
parts.append(frame(X1, D3 + 110, LW, 'Landscape, stopped', c_land(X1, D3 + 120, LW - 48)))
parts.append(grid_hint(X1, D3 + 110, LW, 100))
parts.append(frame(X2, D3 + 110, PW, 'Portrait, stopped', c_port(X2, D3 + 120, PW - 48)))
parts.append(grid_hint(X2, D3 + 110, PW, 100))
parts.append(frame(X1, D3 + 420, LW, 'Landscape, playing', c_land(X1, D3 + 430, LW - 48, playing=True)))
parts.append(grid_hint(X1, D3 + 420, LW, 100))
parts.append(frame(X2, D3 + 420, PW, 'Portrait, playing', c_port(X2, D3 + 430, PW - 48, playing=True)))
parts.append(grid_hint(X2, D3 + 420, PW, 100))
parts.append(wrap(X1, D3 + 710, 1300, '<b style="color:#EDEDF0">What moved:</b> nothing goes into a menu. Each half of the middle gets the whole row’s width when it’s up, so everything keeps its words in landscape. Playing, the song mode shrinks to one ↻ ⌄ key beside Play, so a mid-set Loop entry stays one tap plus a pick. The swap is a cross-fade in place (nothing pops); Play, the tabs and Patterns never move.', 14, '#C8C8CF'))
parts.append(wrap(X2, D3 + 710, 1000, '<b style="color:#EDEDF0">One tap further:</b> while playing, the song mode (a menu); iPad audio, Keys and Projects aren’t there at all until you stop.<br><b style="color:#EDEDF0">The cost:</b> the row rearranges at the moment you press Play, when your eyes are on the pads. You can’t set Launch at before you start (it only takes effect while playing, but people like to set it first). Two layouts to learn and to test.', 14, '#C8C8CF'))

# ---- recommendation ----
R = D3 + 820
parts.append(box(40, R, BW - 80, 150, f'background:{PANEL};border-radius:14px;'))
parts.append(tx(64, R + 20, 'My pick: (b), with the song mode shown under the tempo', 20, TEXT, 700))
parts.append(wrap(64, R + 56, BW - 140, 'It’s the calmest: nine controls instead of (a)’s twelve, in three groups you can read at a glance (where you are, what launches, the transport), with full words for everything a set touches (Patterns, Launch at, Cancel 3 waiting). The cuts land on things you set once (Projects, iPad audio). (a) has a little more room for larger text (158 pt spare against 108), so this isn’t a fit question; it’s about how busy the row looks. '
              'The weak spot is the song mode. It moves two taps away, so I’d show it under the tempo where you look anyway; if you switch it mid-set often, take (b) with the song mode as one “↻ Song ⌄” key beside Play (from (c)). That fits with 44 pt to spare, so larger text collapses sooner. '
              '(a) is too dense to read at a glance under pressure; (c) moves things at the worst moment. Whatever wins, a refusal (“Stop to rearrange…”, with its Stop key) shows as a strip that slides down under the row and stays until it’s dealt with, because it carries an action.', 15, '#C8C8CF'))

BH = R + 200
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};{FONT}overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe top row</title>
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
open(os.path.join(OUT, 'TopRow.dc.html'), 'w').write(doc)
print('TopRow.dc.html', BW, BH); print('widths', WIDTHS)

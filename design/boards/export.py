# Boards 51 and 52: exports in Lupe (vault export-plan.md, 2026-11-11). Mock first, Scott picks before any export UI is
# built. 51: where Export lives, A in the FM-1 key's menu, B in the Projects sheet, C a Capture key on the top row; each
# with the sheet it opens. 52: a recording in progress, 1 the readout becomes the take, 2 a strip under the row, 3 the
# FM-1 key carries it; then the take finished, its file and Share. Capture never looks like the FM-1's REC (a red dot):
# its glyph is a level waveform, its words "Capture", red stays for confirms and REC.
# The look and the helpers are board 49/50's (freetake.py): its helpers are read from it, so the two stay one style.
import os, html
HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, 'freetake.py')).read().split('# ================================ board 49')[0]
exec(_src)                                       # PAGE PANEL PAD … box tx wrap key seg topbar lanes screen strip tint cr

GREEN = '#30D158'

def wave(x, y, h=18, c=TEXT, bars=(.35, .7, 1, .55, .85, .4)):
    """Capture's glyph: a level waveform, never REC's dot."""
    o = []
    for i, k in enumerate(bars):
        bh = max(3, h * k)
        o.append(box(x + i * 4, y + (h - bh) / 2, 2.5, bh, f'background:{c};border-radius:2px;'))
    return ''.join(o)

def meter(x, y, w, level=.62, peak=.74):
    o = [box(x, y, w, 8, f'background:{WELL};border-radius:4px;')]
    o.append(box(x, y, w * level, 8, f'background:{T2R};border-radius:4px;'))
    o.append(box(x + w * peak, y - 2, 2, 12, f'background:{TEXT};border-radius:1px;'))
    return ''.join(o)

def bar(x, y, w, *, readout=None, capture_key=False, key_ring=None, menu_open=False, proj='Night Drive'):
    """Today's top row (board 47 b, built): the FM-1 key, Pads · Timeline · Mix, Patterns, Keys, REC, Play, readout."""
    o = [box(x, y, w, 64, f'background:{PAGE};')]
    kx = x + 14
    if key_ring:
        o.append(box(kx - 4, y + 8, 130, 48, f'border:2px solid {TEXT};border-radius:14px;'))
    o.append(box(kx, y + 12, 122, 40, f'background:{HELD if menu_open else PAD};border-radius:10px;'))
    o.append(box(kx + 12, y + 28, 8, 8, f'background:{GREEN};border-radius:4px;'))
    o.append(tx(kx + 28, y + 22, (key_ring or proj) + ' ⌄', 15, TEXT, 600))
    tx0 = x + 150
    for i, n in enumerate(['Pads', 'Timeline', 'Mix']):
        tw_ = tw(n, 15) + 36
        if i == 1: o.append(box(tx0, y + 10, tw_, 46, f'background:{HELD};border-radius:12px 12px 0 0;'))
        o.append(tx(tx0, y + 22, n, 15, TEXT if i == 1 else T2, 600 if i == 1 else 400, f'width:{tw_}px;text-align:center;'))
        tx0 += tw_ + 4
    o.append(box(x + 146, y + 56, tx0 - x - 142, 3, f'background:{HELD};border-radius:2px;'))
    k, kw = key(tx0 + 16, y + 10, 'Patterns'); o.append(k)
    rx = x + w - 420
    if capture_key:
        o.append(box(rx - 132, y + 10, 120, 44, f'background:{PAD};border-radius:10px;'))
        o.append(wave(rx - 118, y + 23))
        o.append(tx(rx - 88, y + 22, 'Capture', 15, TEXT))
    o.append(tx(rx, y + 22, '⌨', 18, TEXT))
    o.append(box(rx + 46, y + 18, 26, 26, 'background:#3A1214;border-radius:13px;'))
    o.append(box(rx + 55, y + 27, 8, 8, 'background:#FF2C34;border-radius:4px;'))
    o.append(tx(rx + 92, y + 20, '▶', 18, TEXT))
    if readout: o.append(readout(rx + 128, y))
    else:
        o.append(tx(rx + 128, y + 14, '9 · 1', 15, TEXT, 600)); o.append(tx(rx + 128, y + 34, 'Song · 120 BPM', 12, T2))
    return ''.join(o)

def popmenu(x, y, w, rows, title=None):
    """A fan menu beside the finger (house style): rows of 52, the chosen one lifted."""
    h = len(rows) * 52 + 16 + (34 if title else 0)
    o = [box(x, y, w, h, f'background:{HELD};border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.5);')]
    cy = y + 8
    if title:
        o.append(tx(x + 20, cy + 8, title, 12, T2R, 600)); cy += 34
    for (label, sub, hi, glyph) in rows:
        if hi: o.append(box(x + 8, cy, w - 16, 48, f'background:{PAD};border-radius:10px;box-shadow:0 0 0 2px {TEXT};'))
        gx = x + 22
        if glyph == 'wave': o.append(wave(gx, cy + 15))
        elif glyph: o.append(tx(gx, cy + 13, glyph, 16, TEXT))
        o.append(tx(x + 54, cy + 7 if sub else cy + 14, label, 15, TEXT, 600 if hi else 400))
        if sub: o.append(tx(x + 54, cy + 27, sub, 12, T2R))
        cy += 52
    return ''.join(o), h

def export_sheet(x, y, w=560, sel=1, project='Night Drive', note=None):
    """The sheet Export… opens: four rows, what each needs, the primary at the foot."""
    rows = [('wave', 'Song as audio', 'Plays it once from the top · 2:10 · WAV', 'needs the FM-1'),
            ('♪', 'MIDI for a DAW', '6 tracks · 120 BPM · Night Drive.mid', 'no FM-1 needed'),
            ('⧉', 'Skiff backup', 'The whole FM-1, for Skiff’s web editor', 'needs the FM-1 · 1–2 min'),
            ('◫', 'Lupe project', 'For another Lupe; opens on any FM-1 with Skiff', 'no FM-1 needed')]
    h = 116 + len(rows) * 76 + (64 if note else 0) + 76
    o = [box(x, y, w, h, f'background:{PANEL};border-radius:20px;box-shadow:0 14px 40px rgba(0,0,0,.55);')]
    o.append(tx(x + 24, y + 22, f'Export {project}', 20, TEXT, 600))
    o.append(tx(x + 24, y + 52, 'Saved to Files › Lupe › Skiff › Exports, then shared from there', 13, T2R))
    k, _ = key(x + w - 76, y + 16, '✕', 52); o.append(k)
    cy = y + 96
    for i, (g, t, s, need) in enumerate(rows):
        hi = i == sel
        o.append(box(x + 16, cy, w - 32, 68, f'background:{HELD if hi else PAD};border-radius:12px;' + (f'box-shadow:0 0 0 2px {TEXT};' if hi else '')))
        if g == 'wave': o.append(wave(x + 34, cy + 25))
        else: o.append(tx(x + 34, cy + 22, g, 18, TEXT))
        o.append(tx(x + 70, cy + 13, t, 15, TEXT, 600))
        o.append(tx(x + 70, cy + 37, s, 13, T2R))
        o.append(tx(x + w - 40 - tw(need, 12), cy + 15, need, 12, T2))
        cy += 76
    if note:
        o.append(wrap(x + 24, cy + 4, w - 48, note, 13, T2R)); cy += 64
    k, kw = key(x + w - 196, cy + 8, 'Export MIDI', 172, primary=True); o.append(k)
    return ''.join(o), h

def ipad(x, y, label, over='', bar_kw=None, landed=None):
    inner = bar(0, 0, 1376, **(bar_kw or {}))
    lane, lh = lanes(16, 64 + 16, 1344, landed=landed)
    inner += lane
    # the editor under the Timeline (option A, as built): a quiet stand-in
    ey = 64 + 16 + lh + 18
    inner += box(16, ey, 1344, 1032 - ey - 16, f'background:{PANEL};border-radius:14px;')
    inner += tx(40, ey + 20, 'T3 Pulse Ld · pattern 08', 15, TEXT, 600)
    for r in range(8):
        inner += box(40, ey + 60 + r * 34, 1296, 28, f'background:{WELL};border-radius:6px;')
    inner += over
    return screen(x, y, label, inner)

def caption(x, y, w, title, body, pick=False):
    o = [tx(x, y, title, 20, TEXT, 700)]
    if pick: o.append(box(x + tw(title, 20) + 26, y - 2, 96, 28, f'background:{TEXT};border-radius:8px;') +
                      tx(x + tw(title, 20) + 26, y + 3, 'my pick', 14, ON, 700, 'width:96px;text-align:center;'))
    o.append(wrap(x, y + 36, w, body, 15, '#C8C8CF'))
    return ''.join(o)

XS = [40 + i * (1376 + 64) for i in range(3)]
W = 40 * 2 + 3 * 1376 + 2 * 64

# ================================ board 51: where Export lives =========================================================
def board51():
    p = [tx(40, 32, '51 · Exports: where Export lives (A, B or C); each opens the same sheet · mock only, nothing built', 30, TEXT, 700),
         wrap(40, 78, 2600, 'Four exports (vault export-plan.md): the song as audio, a session as audio, MIDI, and a Skiff file, which is the FM-1’s '
              'whole backup, since Skiff has no single-project file. The MIDI engine is built and checked against Skiff’s firmware; the rest waits for these picks. '
              'Today’s top row, the Timeline in option A, T3 selected. Menus open beside the finger; nothing pops (the sheet rises from the menu row, 300 ms; Reduce Motion fades).', 15, T2)]
    Y = 200
    # A · the FM-1 key's menu
    m, mh = popmenu(14, 64, 330, [('Projects…', None, False, '▤'), ('Play through the iPad', 'On · Speaker', False, '♫'),
                                  ('Export…', 'MIDI, song audio, Skiff backup', True, '⇪'), ('Capture a session', 'Record what you play', False, 'wave'),
                                  ('Disconnect', None, False, '⏏')], title='FM-1 · Skiff 2.5.1')
    s, sh = export_sheet(380, 150)
    p.append(ipad(XS[0], Y, 'A · In the FM-1 key’s menu: Export… and Capture a session beside Projects…', m + s, {'menu_open': True}))
    # B · the Projects sheet
    ov = box(0, 0, 1376, 1032, f'background:{PAGE};opacity:.55;')
    px, py, pw = 240, 110, 900
    ov += box(px, py, pw, 760, f'background:{PANEL};border-radius:20px;box-shadow:0 14px 40px rgba(0,0,0,.55);')
    ov += tx(px + 24, py + 22, 'Projects', 20, TEXT, 600) + tx(px + 24, py + 52, 'On this iPad · Skiff', 13, T2R)
    names = [('Night Drive', 'saved 21:40 · 6 tracks · 14 patterns', True), ('Dub sketch', 'saved yesterday · 4 tracks', False),
             ('Demo', 'saved 9 Nov · 6 tracks', False), ('Acid test', 'saved 8 Nov · 2 tracks', False)]
    for i, (n, d, on) in enumerate(names):
        ry = py + 96 + i * 84
        ov += box(px + 16, ry, pw - 32, 76, f'background:{HELD if on else PAD};border-radius:12px;')
        ov += tx(px + 36, ry + 14, n, 17, TEXT, 600) + tx(px + 36, ry + 42, d, 13, T2R)
        k, _ = key(px + pw - 84, ry + 16, '⋯', 52); ov += k
    m2, _ = popmenu(px + pw - 360, py + 150, 340, [('Open', None, False, '↗'), ('Rename', None, False, '✎'),
                                                   ('Export MIDI', 'Night Drive.mid · no FM-1 needed', True, '♪'),
                                                   ('Share the project', 'A Lupe project file', False, '◫'),
                                                   ('Delete', None, False, '⌫')])
    ov += m2
    ov += wrap(px + 24, py + 560, pw - 48, 'Audio isn’t here: a take needs the FM-1 playing, so <b style="color:#EDEDF0">Capture</b> stays in the FM-1 key’s menu, beside Play through the iPad, and the Skiff backup stays on the FM-1 page with the install backups.', 14, T2R)
    p.append(ipad(XS[1], Y, 'B · In the Projects sheet: each project’s ⋯ menu exports it; audio stays with the FM-1', ov))
    # C · a Capture key on the top row
    m3, _ = popmenu(1376 - 420 - 140, 64, 330, [('Capture a session', 'Until you stop it', True, 'wave'),
                                                ('Capture the song', 'Once from the top · 2:10', False, '▶'),
                                                ('Settings', 'WAV · 44.1 kHz · Files › Exports', False, '⚙')])
    p.append(ipad(XS[2], Y, 'C · A Capture key on the top row (held: its menu); MIDI and Skiff in the FM-1 key’s menu', m3, {'capture_key': True}))
    # captions
    CY = Y + 1032 + 40
    p.append(caption(XS[0], CY, 1376, 'A · The FM-1 key’s menu', 'Export… sits with Projects… and Play through the iPad, where the FM-1’s own business already lives. '
             'One sheet holds all four, each saying whether it needs the FM-1. Nothing new on the top row. Capture a session is the second item, so recording is two taps.', pick=True))
    p.append(caption(XS[1], CY, 1376, 'B · The Projects sheet', 'MIDI and the project file come from a saved project, so they sit on its row and work with no FM-1. '
             'But audio can’t live there (it needs the FM-1 playing), so the exports end up in two places, and the music that isn’t saved yet needs a save first.'))
    p.append(caption(XS[2], CY, 1376, 'C · A Capture key', 'Recording becomes one tap, like REC beside it. The row is already full: on a narrow iPad the Capture key '
             'is the first to give way to an icon, and two record-like keys side by side are easy to confuse. Worth adding later if Scott records often.'))
    # the sheet's rows, and contrast
    KY = CY + 170
    p.append(tx(40, KY, 'Contrast (computed): ', 15, TEXT, 700))
    pairs = [('Body text on the sheet', cr(TEXT, PANEL), 4.5), ('Row subtitles (T2R) on a row', cr(T2R, PAD), 4.5),
             ('“needs the FM-1” (T2) on a row', cr(T2, PAD), 4.5), ('Selected row ring (text) on the sheet', cr(TEXT, PANEL), 3),
             ('Export MIDI (dark on light)', cr(ON, TEXT), 4.5)]
    for i, (n, v, need) in enumerate(pairs):
        p.append(tx(40, KY + 30 + i * 24, f'{v:5.2f}:1', 14, TEXT if v >= need else NOTE, 700, f'{NUM}width:62px;'))
        p.append(tx(110, KY + 31 + i * 24, f'{n} (needs {need:g}:1)', 13, '#C8C8CF'))
    H = KY + 30 + len(pairs) * 24 + 40
    return W, H, ''.join(p)

# ================================ board 52: a recording in progress ====================================================
def board52():
    p = [tx(40, 32, '52 · Exports: a take in progress (1, 2 or 3), and the take finished · mock only', 30, TEXT, 700),
         wrap(40, 78, 2600, 'The same take in three treatments, 0:42 into “Night Drive” played once from the top (the song as audio; a session looks the same without “of 2:10”). '
              'Capture is a level waveform and the word Capture, never REC’s red dot, which stays in the row for the FM-1’s own recording. '
              'Each state cross-fades in (150 ms) where it sits; Stop is always 44 pt and reachable with VoiceOver (“Stop capture, 42 seconds”).', 15, T2)]
    Y = 200
    # 1 · the readout becomes the take
    def take_readout(x, y):
        return (wave(x, y + 20) + tx(x + 30, y + 14, '0:42 of 2:10', 15, TEXT, 600, NUM) + meter(x + 30, y + 40, 96)
                + box(x + 146, y + 12, 80, 40, f'background:{TEXT};border-radius:10px;') + tx(x + 146, y + 23, 'Stop', 15, ON, 600, 'width:80px;text-align:center;'))
    prog = box(16 + 220, 64 + 16, (1344 - 220 - 8) * 0.32, 22, f'background:{TEXT};opacity:.14;border-radius:6px;')
    p.append(ipad(XS[0], Y, '1 · The readout becomes the take: time, level, Stop, where “Song · 120 BPM” was', prog, {'readout': take_readout}))
    # 2 · a strip under the row
    sx, sy, sw_ = 240, 72, 900
    st = box(sx, sy, sw_, 64, f'background:{HELD};border-radius:14px;box-shadow:0 6px 18px rgba(0,0,0,.35);')
    st += wave(sx + 20, sy + 23) + tx(sx + 52, sy + 12, 'Capturing the song · 0:42 of 2:10', 15, TEXT, 600)
    st += tx(sx + 52, sy + 36, 'Night Drive · song · 2026-11-11 2143.wav · 7 MB so far', 12, T2R)
    st += meter(sx + 470, sy + 28, 220)
    k, _ = key(sx + sw_ - 112, sy + 10, 'Stop', 96, primary=True); st += k
    p.append(ipad(XS[1], Y, '2 · A strip under the row, where refusals show today: name, size, level, Stop', st))
    # 3 · the FM-1 key carries it
    def key_readout(x, y):
        return tx(x, y + 14, '9 · 1', 15, TEXT, 600) + tx(x, y + 34, 'Song · 120 BPM', 12, T2)
    ruler = box(16 + 220, 64 + 16 + 18, (1344 - 220 - 8) * 0.32, 4, f'background:{TEXT};border-radius:2px;')
    ruler += box(16 + 220 + (1344 - 220 - 8) * 0.32 - 4, 64 + 16 + 14, 12, 12, f'background:{TEXT};border-radius:6px;')
    p.append(ipad(XS[2], Y, '3 · The FM-1 key carries it: a ring and the time; the song’s progress along the ruler', ruler,
                  {'key_ring': '0:42', 'readout': key_readout}))
    CY = Y + 1032 + 40
    p.append(caption(XS[0], CY, 1376, '1 · In the readout', 'Nothing moves: the readout cross-fades to the take and back. Stop sits where the eye already goes for time. '
                     'The song take also fills the ruler behind the bars. Tight on a narrow iPad: the level meter is the first to go.', pick=True))
    p.append(caption(XS[1], CY, 1376, '2 · A strip', 'The clearest: it names the file and its size, so a long session’s cost is visible. '
                     'It covers the top lanes for the whole take, which matters most in a live session, the time you most need the Pads.'))
    p.append(caption(XS[2], CY, 1376, '3 · On the FM-1 key', 'The quietest, and the take reads as the FM-1’s, which it is. Stop is in the key’s menu, '
                     'one tap further, and a ring is easy to miss while playing: a forgotten capture fills the iPad.'))
    # the take finished: the sheet comes back with the file
    FY = CY + 180
    p.append(tx(40, FY, 'The take finished (every option): kept first, then offered', 20, TEXT, 700))
    fx, fy = 40, FY + 44
    p.append(box(fx, fy, 620, 300, f'background:{PANEL};border-radius:20px;'))
    p.append(tx(fx + 24, fy + 22, 'Captured: 2:14', 20, TEXT, 600))
    p.append(tx(fx + 24, fy + 52, 'Night Drive · song · 2026-11-11 2143.wav · 23 MB', 13, T2R))
    p.append(box(fx + 24, fy + 90, 572, 72, f'background:{WELL};border-radius:10px;'))
    import math
    for i in range(110):
        a = abs(math.sin(i * .37) * .6 + math.sin(i * .11) * .4) * (0.25 if i > 100 else 1)
        p.append(box(fx + 36 + i * 5, fy + 126 - 28 * a, 3, max(2, 56 * a), f'background:{T2R};border-radius:1px;'))
    p.append(tx(fx + 24, fy + 176, 'Saved in Files › Lupe › Skiff › Exports. The 4 s tail after the song stopped is kept.', 13, T2R))
    k, _ = key(fx + 24, fy + 224, '▶  Listen', 120); p.append(k)
    k, _ = key(fx + 156, fy + 224, 'Delete', 100); p.append(k)
    k, _ = key(fx + 620 - 164, fy + 224, 'Share…', 140, primary=True); p.append(k)
    p.append(wrap(fx + 680, fy + 10, 1500, '<b style="color:#EDEDF0">Share…</b> opens the iOS share sheet beside the button (AirDrop, Files, Mail, a DAW). '
                  '<b style="color:#EDEDF0">Delete</b> confirms in place, as every destructive action does: the button turns into “Delete this 2:14 take” outlined, Cancel under it. '
                  'If the FM-1 is unplugged, or a call comes in mid-take, the file is closed and kept, and this sheet says where it stopped.', 15, '#C8C8CF'))
    pairs = [('Take time and Stop on the readout', cr(TEXT, PAGE), 4.5), ('Strip subtitle (T2R) on the strip', cr(T2R, HELD), 4.5),
             ('Stop (dark on light)', cr(ON, TEXT), 4.5), ('Level fill (T2R) against its well', cr(T2R, WELL), 3), ('Key ring (text) on the page', cr(TEXT, PAGE), 3)]
    KY = fy + 340
    p.append(tx(40, KY, 'Contrast (computed): ', 15, TEXT, 700))
    for i, (n, v, need) in enumerate(pairs):
        p.append(tx(40, KY + 30 + i * 24, f'{v:5.2f}:1', 14, TEXT if v >= need else NOTE, 700, f'{NUM}width:62px;'))
        p.append(tx(110, KY + 31 + i * 24, f'{n} (needs {need:g}:1)', 13, '#C8C8CF'))
    H = KY + 30 + len(pairs) * 24 + 40
    return W, H, ''.join(p)

def write(name, W, H, body, title):
    doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet><style>@import url('https://fonts.googleapis.com/css2?family=Barlow:wght@400;600;700&family=Barlow+Condensed:wght@700&display=swap');body{{margin:0}}</style></helmet>
<div style="position:relative;width:{W}px;height:{H}px;background:{PAGE};color:{TEXT};{FONT}overflow:hidden;">{body}</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{W},"height":{H}}}}}'>
class Component extends DCLogic {{
  renderVals() {{ return {{}}; }}
}}
</script>
</body>
</html>
'''
    open(os.path.join(OUT, name), 'w').write(doc)
    print(name, W, H)

W1, H1, b = board51(); write('ExportWhere.dc.html', W1, H1, b, 'Export placement')
W2, H2, b = board52(); write('ExportTake.dc.html', W2, H2, b, 'Export take')

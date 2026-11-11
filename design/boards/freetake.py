# Boards 49 and 50: FREE TAKE in Lupe (Skiff 2.5). Scott, 2026-11-11: "Mock it up first." With the transport stopped you
# play, pause 2.5 s, press SHIFT + SAVE; Skiff guesses the tempo (with double and half), the bars and where the 1 is, and
# shows a picker on the FM-1 (KNOB 1–4, PLAY previews, OCT+ keeps, OCT− puts the track back). 49: the flow on the iPad end
# to end (the take offered, kept, landing on the Timeline with undo) and what needs the firmware. 50: the picker in three
# forms (in the editor's place, in the track's lane, a panel), the captured notes re-gridding as the choices change.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, T2R, T3, ON = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#C4C4CC', '#71717A', '#101012'
HELD, EDGE, NOTE, REC = '#34343B', '#8E8E96', '#FFB54A', '#FF8A8D'
COL = {1: '#FF5A36', 2: '#22C3B4', 3: '#FFBF00', 4: '#9580FF', 5: '#FF6FAE', 6: '#A3E635'}
NAMES = {1: 'Acid', 2: 'Pad', 3: 'Pulse Ld', 4: 'Drum Kit', 5: 'Piano', 6: 'Drum Kit'}
FONT = "font-family:'Barlow',-apple-system,system-ui,sans-serif;"
NUM = "font-family:'Barlow Condensed','Barlow',sans-serif;"
T = 3                                            # the take lands on T3 (Pulse Ld), the selected track

def rgb(h): h = h.lstrip('#'); return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
def hx(c): return '#' + ''.join(f'{round(v * 255):02X}' for v in c)
def mix(a, b, k): A, B = rgb(a), rgb(b); return hx([B[i] + (A[i] - B[i]) * k for i in range(3)])
def lum(h):
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = [f(c) for c in rgb(h)]; return 0.2126 * r + 0.7152 * g + 0.0722 * b
def cr(a, b): x, y = sorted([lum(a), lum(b)], reverse=True); return (x + 0.05) / (y + 0.05)
def tint(t, k=0.24): return mix(COL[t], PAGE, k)

def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{FONT}{extra}">{html.escape(s)}</div>'
def wrap(x, y, w, s, size, c, wt=400): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.45;{FONT}">{s}</div>'
def tw(s, size): return int(len(s) * size * 0.5) + 2

def key(x, y, label, w=None, primary=False, dim=False, h=44, red=False, tintk=None):
    w = w or tw(label, 15) + 32
    bg = TEXT if primary else (tintk or PAD)
    fg = ON if primary else (T3 if dim else TEXT)
    st = f'background:{bg};border-radius:10px;'
    if red: st += f'border:3px solid {REC};'
    return box(x, y, w, h, st) + tx(x, y + (h - 18) / 2, label, 15, fg, 600 if primary else 400, f'width:{w}px;text-align:center;'), w

def seg(x, y, opts, sel, h=44, caps=None):
    ws = [max(tw(s, 15) + 28, 64) for s in opts]
    o = [box(x, y, sum(ws) + 8, h, f'background:{WELL};border-radius:10px;')]
    cx = x + 4
    for i, (s, w) in enumerate(zip(opts, ws)):
        if i == sel: o.append(box(cx, y + 4, w, h - 8, f'background:{HELD};border-radius:7px;'))
        o.append(tx(cx, y + (h - 18) / 2 - (5 if caps else 0), s, 15, TEXT if i == sel else T2, 600 if i == sel else 400, f'width:{w}px;text-align:center;'))
        if caps: o.append(tx(cx, y + h - 16, caps[i], 10, T2R if i == sel else T3, 400, f'width:{w}px;text-align:center;'))
        cx += w
    return ''.join(o), sum(ws) + 8

# ---- the iPad around it ------------------------------------------------------------------------------------------------

def topbar(x, y, w, tab=1, strip=None):
    o = [box(x, y, w, 64, f'background:{PAGE};')]
    o.append(tx(x + 20, y + 22, '● Demo ⌄', 15, TEXT, 600))
    tx0 = x + 130
    for i, n in enumerate(['Pads', 'Timeline', 'Mix']):
        tw_ = tw(n, 15) + 36
        if i == tab: o.append(box(tx0, y + 10, tw_, 46, f'background:{HELD};border-radius:12px 12px 0 0;'))
        o.append(tx(tx0, y + 22, n, 15, TEXT if i == tab else T2, 600 if i == tab else 400, f'width:{tw_}px;text-align:center;'))
        tx0 += tw_ + 4
    o.append(box(x + 126, y + 56, tx0 - x - 122, 3, f'background:{HELD};border-radius:2px;'))
    k, kw = key(tx0 + 16, y + 10, 'Patterns'); o.append(k)
    o.append(tx(x + w - 300, y + 22, '⌨', 18, TEXT)); o.append(box(x + w - 250, y + 18, 26, 26, f'background:#3A1214;border-radius:13px;'))
    o.append(box(x + w - 241, y + 27, 8, 8, f'background:#FF2C34;border-radius:4px;'))
    o.append(tx(x + w - 205, y + 20, '▶', 18, TEXT))
    o.append(tx(x + w - 170, y + 14, '1 · 1', 15, TEXT, 600)); o.append(tx(x + w - 170, y + 34, 'Song · 120 BPM', 12, T2))
    if strip: o.append(strip)
    return ''.join(o)

SONG = {1: [(0, 4, '01'), (4, 12, '02'), (12, 20, '02'), (20, 24, '04')], 2: [(0, 4, 'REST'), (4, 12, '05'), (12, 23, '05')],
        3: [(0, 8, '08'), (8, 12, '09'), (12, 20, '08')], 4: [(0, 3, 'REST'), (3, 14, '10'), (14, 22, '11')],
        5: [(0, 8, 'REST'), (8, 12, '12'), (12, 16, '13'), (16, 23, '12')], 6: [(0, 15, '14'), (15, 23, '14')]}

def lanes(x, y, w, lh=34, gap=6, landed=None, sel=T, dim=False):
    head = 220; bars = 25; bw = (w - head - 16) / bars
    o = [box(x + head, y, w - head - 8, 22, f'background:{PANEL};border-radius:6px;')]
    for b in range(0, bars, 4): o.append(tx(x + head + 6 + b * bw, y + 4, str(b + 1), 11, T2))
    ly = y + 22 + gap
    for t in range(1, 7):
        s = t == sel
        o.append(box(x, ly, w - 8, lh, f'background:{tint(t) if s else PANEL};border-radius:10px;'))
        o.append(box(x + 10, ly + (lh - 22) / 2, 22, 22, f'background:{COL[t]};border-radius:6px;'))
        o.append(tx(x + 10, ly + (lh - 22) / 2 + 3, str(t), 13, ON, 700, f'width:22px;text-align:center;{NUM}'))
        o.append(tx(x + 40, ly + (lh - 16) / 2, NAMES[t] + ' ⌄', 13, TEXT if s else '#C8C8CF', 600 if s else 400))
        blocks = list(SONG[t])
        if landed and t == sel: blocks = landed
        for (a, b, lab) in blocks:
            bx = x + head + a * bw + 2; bwid = (b - a) * bw - 4
            if lab == 'REST':
                o.append(box(bx, ly + 4, bwid, lh - 8, f'border:1.5px dashed #7C7C85;border-radius:7px;'))
                o.append(tx(bx + 8, ly + (lh - 14) / 2, 'REST', 11, T2, 600))
            elif lab.startswith('NEW'):
                o.append(box(bx, ly + 4, bwid, lh - 8, f'background:{PAD};border:3px solid {COL[t]};border-radius:7px;'))
                o.append(tx(bx + 8, ly + (lh - 14) / 2, lab[4:], 11, TEXT, 600))
            else:
                o.append(box(bx, ly + 4, bwid, lh - 8, f'background:{tint(t, .32)};border:1.5px solid {COL[t]};border-radius:7px;'))
                o.append(tx(bx + 8, ly + (lh - 14) / 2, lab, 11, TEXT, 600))
        ly += lh + gap
    if dim: o.append(box(x, y, w, ly - y, f'background:{PAGE};opacity:.45;'))
    return ''.join(o), ly - y

def screen(x, y, label, inner, w=1376, h=1032):
    return (box(x, y, w, h, f'background:{PAGE};border:1px solid #2A2A30;border-radius:18px;overflow:hidden;') +
            tx(x, y - 26, label, 14, T2, 600) + f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;overflow:hidden;border-radius:18px;">{inner}</div>')

def strip(x, y, w, body):
    return box(x, y, w, 56, f'background:{HELD};border-radius:14px;box-shadow:0 6px 18px rgba(0,0,0,.35);') + body

# ---- the take: the notes as played, and placed on a grid -------------------------------------------------------------
# a phrase played free: 14 notes over about 5.1 s (seconds, pitch). At 96 BPM a beat is 0.625 s.
PHRASE = [(0.02, 67), (0.33, 70), (0.64, 72), (0.95, 70), (1.27, 67), (1.58, 65), (1.88, 67), (2.52, 67),
          (2.83, 70), (3.15, 72), (3.45, 75), (3.77, 74), (4.08, 72), (4.70, 70)]

def notes_view(x, y, w, h, bpm=96, bars=2, first=0, raw=False, colour=None):
    """The captured notes in a roll. raw: as played, on a seconds axis. Else gridded: 16th lines for `bars` bars at `bpm`,
    the bar line where the 1 is (`first` notes in), each note snapped to its 16th, drawn as a step block."""
    c = colour or COL[T]
    o = [box(x, y, w, h, f'background:{WELL};border-radius:10px;')]
    lo, hi = 62, 78
    def py(p): return y + 10 + (hi - p) / (hi - lo) * (h - 34)
    if raw:
        span = 5.4
        for s in range(0, 6): o.append(box(x + 12 + s / span * (w - 24), y + 6, 1, h - 30, f'background:#2A2A30;'))
        for (t, p) in PHRASE:
            o.append(box(x + 12 + t / span * (w - 24), py(p), 10, 10, f'background:{c};border-radius:5px;'))
        o.append(tx(x + 12, y + h - 20, 'as played: 0 s', 11, T2)); o.append(tx(x + w - 70, y + h - 20, '5 s', 11, T2))
        return ''.join(o)
    steps = bars * 16
    sw = (w - 24) / steps
    beat = 60 / bpm; sixteenth = beat / 4
    t0 = PHRASE[first][0]
    for k in range(steps + 1):
        st = '#3A3A42' if k % 16 == 0 else '#24242A' if k % 4 == 0 else '#18181C'
        o.append(box(x + 12 + k * sw, y + 6, 2 if k % 16 == 0 else 1, h - 30, f'background:{st};'))
    for b in range(bars): o.append(tx(x + 16 + b * 16 * sw, y + h - 20, str(b + 1), 11, T2R, 600))
    for (t, p) in PHRASE:
        k = round((t - t0) / sixteenth)
        if 0 <= k < steps:
            o.append(box(x + 12 + k * sw + 1, py(p), max(4, sw * 2 - 2), 10, f'background:{c};border-radius:3px;'))
    # the 1: a marker you drag
    o.append(box(x + 6, y + 2, 14, 14, f'background:{TEXT};border-radius:7px;'))
    o.append(tx(x + 6, y + 2, '1', 10, ON, 700, 'width:14px;text-align:center;'))
    return ''.join(o)

# ---- the picker's controls (the same in every form) -------------------------------------------------------------------

def controls(x, y, w, bpm_sel=1, bars_sel=1, set_sel=0, compact=False, level2=True):
    o = []
    cy = y
    def row(label, help_):
        nonlocal cy
        o.append(tx(x, cy, label, 13, T2R, 600))
        if help_: o.append(tx(x + tw(label, 13) + 10, cy + 1, help_, 12, T3))
        cy += 22
    row('Tempo', 'Skiff’s guess, and half and double')
    s, sw = seg(x, cy, ['48', '96', '192'], bpm_sel, caps=['half', 'guess', 'double']); o.append(s)
    cy += 56
    row('Bars', '')
    s, sw = seg(x, cy, ['1', '2', '4', '8'], bars_sel); o.append(s)
    cy += 56
    row('Where the 1 is', 'drag the 1 on the notes, or step it')
    k, kw = key(x, cy, '◀', 52); o.append(k)
    o.append(tx(x + 62, cy + 12, 'first note', 15, TEXT))
    k, kw = key(x + 160, cy, '▶', 52); o.append(k)
    cy += 56
    row('Song tempo', 'the song’s now 120 BPM')
    s, sw = seg(x, cy, ['Set to 96', 'Keep 120'], set_sel); o.append(s)
    cy += 60
    return ''.join(o), cy - y

def actions(x, y, w, confirm=False):
    o = []
    k, kw = key(x, y, '▶  Listen', 120); o.append(k)
    k2, kw2 = key(x + 132, y, 'Put back', 116); o.append(k2)
    if confirm:
        k3, kw3 = key(x + w - 250, y, 'Replace pattern 08 on T3', 250, red=True); o.append(k3)
    else:
        k3, kw3 = key(x + w - 160, y, 'Keep it', 160, primary=True); o.append(k3)
    return ''.join(o)

# ================================ board 49: the flow ================================================================
def board49():
    parts = []
    W = 40 * 2 + 3 * 1376 + 2 * 64
    parts.append(tx(40, 32, '49 · FREE TAKE in Lupe: play stopped, keep it, land on the Timeline (the flow, and what needs the firmware) · decided 2026-11-11: form A', 30, TEXT, 700))
    parts.append(wrap(40, 78, 2400,
        'Skiff 2.5: with the transport stopped you play (the FM-1’s keys, MIDI, Lupe’s keyboard, the arp), pause 2.5 s, and SHIFT + SAVE opens its picker. '
        'Three moments on the iPad, at 1:1, T3 Pulse Ld selected, the Timeline in option A: <b style="color:#EDEDF0">1</b> the take offered, <b style="color:#EDEDF0">2</b> the picker (its three forms on board 50), '
        '<b style="color:#EDEDF0">3</b> landed, with undo. Under them, what Lupe can do with today’s screen link (level 1) and what needs a v7 in the firmware (level 2). Nothing is built.', 15, T2))
    Y = 200
    xs = [40 + i * (1376 + 64) for i in range(3)]

    # 1 · the take offered
    st = strip(xs[0] + 380, Y + 72, 616,
               box(xs[0] + 396, Y + 84, 32, 32, f'background:{COL[T]};border-radius:16px;') +
               tx(xs[0] + 396, Y + 90, '♪', 17, ON, 700, 'width:32px;text-align:center;') +
               tx(xs[0] + 440, Y + 82, 'You played 14 notes, about 96 BPM', 15, TEXT, 600) +
               tx(xs[0] + 440, Y + 102, 'for T3 Pulse Ld · offered for 30 s', 12, T2R))
    k, kw = key(xs[0] + 380 + 616 - 196, Y + 78, 'Keep that', 124, primary=True)
    k2, _ = key(xs[0] + 380 + 616 - 64, Y + 78, '✕', 52)
    inner, lh = lanes(xs[0] - xs[0] + 16, 64 + 72, 1344)
    head_mark = (box(16 + 10 - 4, 64 + 72 + 22 + 6 + 2 * 40 + 2 - 4, 30, 30, f'border:2px solid {COL[T]};border-radius:9px;'))
    roll = notes_view(16 + 220, 64 + 72 + lh + 24, 1344 - 236, 240, raw=True)
    s1 = topbar(0, 0, 1376) + f'<div style="position:absolute;left:0;top:0">{inner}{head_mark}{roll}</div>'
    s1 += tx(236, 64 + 72 + lh + 268, 'The editor shows the phrase as played, on seconds, until it’s kept or let go.', 12, T2)
    parts.append(screen(xs[0], Y, '1 · Played while stopped: the take offered (level 2; level 1’s strip says “Press SHIFT + SAVE on the FM-1”)', s1))
    parts.append(st + k + k2)
    parts.append(wrap(xs[0], Y + 1032 + 20, 1376,
        'A strip slides down under the top row (where a refusal shows), names the track and Skiff’s first guess, and stays as long as Skiff keeps the phrase (30 s); '
        '<b style="color:#EDEDF0">Keep that</b> opens the picker, ✕ lets it go. The selected track’s number is ringed: that’s where it lands. Nothing appears while you’re still playing: '
        'the strip waits for the 2.5 s pause, as Skiff does. Reduce Motion: it fades in.', 14, T2))

    # 2 · the picker (form A in place)
    edtop = 64 + 22 + 6 * 40 + 34
    inner2, lh2 = lanes(16, 64 + 12, 1344)
    pick = [box(12, edtop, 1352, 1032 - edtop - 12, f'background:{tint(T, .18)};border-radius:18px;')]
    pick.append(tx(36, edtop + 18, 'Keep that take on T3 Pulse Ld', 20, TEXT, 700))
    pick.append(tx(36, edtop + 46, 'Replaces pattern 08 there. Undo brings it back.', 13, T2R))
    pick.append(notes_view(36, edtop + 84, 860, 300, bpm=96, bars=2, first=0))
    c, ch = controls(930, edtop + 84, 400); pick.append(c)
    pick.append(actions(36, 1032 - 12 - 68, 1300))
    s2 = topbar(0, 0, 1376) + f'<div style="position:absolute;left:0;top:0">{inner2}{"".join(pick)}</div>'
    parts.append(screen(xs[1], Y, '2 · The picker, form A (level 2; B and C on board 50)', s2))
    parts.append(wrap(xs[1], Y + 1032 + 20, 1376,
        'The four choices are Skiff’s four knobs, in words. Every change re-grids the notes at once (board 50 shows it). <b style="color:#EDEDF0">Listen</b> is the FM-1’s PLAY, '
        '<b style="color:#EDEDF0">Keep it</b> its OCT+, <b style="color:#EDEDF0">Put back</b> its OCT−. Turning a knob on the FM-1 moves the same choice here, and the other way round.', 14, T2))

    # 3 · landed
    landed = [(0, 2, 'NEW 08 ×1 · the take'), (2, 4, '08 ×1'), (8, 12, '09'), (12, 20, '08')]
    inner3, lh3 = lanes(16, 64 + 72, 1344, landed=landed)
    st3 = strip(380, 64 + 8, 616,
                tx(400, 64 + 18, 'Kept: T3, 2 bars at 96 BPM · the song is 96 BPM now', 15, TEXT, 600) +
                tx(400, 64 + 38, 'pattern 08 replaced on its entries', 12, T2R))
    k3, _ = key(380 + 616 - 120, 64 + 14, 'Undo', 104)
    roll3 = notes_view(16 + 220, 64 + 72 + lh3 + 24, 1344 - 236, 240, bpm=96, bars=2)
    s3 = topbar(0, 0, 1376) + f'<div style="position:absolute;left:0;top:0">{inner3}{st3}{k3}{roll3}</div>'
    parts.append(screen(xs[2], Y, '3 · Kept: the Timeline, the new pattern selected, Undo (level 1 can do this)', s3))
    parts.append(wrap(xs[2], Y + 1032 + 20, 1376,
        'Lupe reads the pattern and the tempo again and opens the Timeline on the selected track, the kept block selected (the Pads’ outline), the editor on it (batch list item 4: '
        'captures land on the Timeline). The strip says what changed and keeps <b style="color:#EDEDF0">Undo</b> until the next edit or 30 s. Undo is Skiff’s own (SAVE held); Skiff 2.5.1 has no editor undo request (checked 2026-11-11), so until the firmware adds one the strip says “Hold SAVE on the FM-1” where Undo is drawn here. '
        'Pattern 08’s other entries change too: they name the same pattern. That’s said here, not discovered later.', 14, T2))

    # levels table
    LY = Y + 1032 + 140
    parts.append(tx(40, LY, 'What needs the firmware', 24, TEXT, 700))
    rows = [
        ('The take offered (1)', 'Yes, by Lupe’s own ear: it sees the notes over MIDI while stopped, and the 2.5 s pause. It can’t know Skiff’s guess; the strip says “Press SHIFT + SAVE on the FM-1”.', 'Skiff’s guess in the strip; Keep that starts the take from the iPad.'),
        ('Keep that (the button)', 'No: nothing in the screen link presses SHIFT + SAVE.', 'Level 3: a command to start the take.'),
        ('The picker (2)', 'Lupe knows only that the FM-1 left its page (SCREEN doesn’t report the picker, fr.on). It can say “Choose on the FM-1” and show the phrase as played.', 'SCREEN flags bit 3 (picker open, “56 01 7”), the four values (tempo guess index and the three tempos, bars, first beat, SET or KEEP), and commands to change each, Listen, Keep and Put back.'),
        ('Re-gridding the notes', 'No values to grid by.', 'From the four values and Lupe’s own record of the notes; the same arithmetic as Skiff’s (it quantises to 16ths): a preview, exact once kept.'),
        ('Landing on the Timeline (3)', 'Yes: a new pattern on the track and a tempo change are seen; Lupe re-reads both and opens the Timeline.', '(the same, and sooner: the keep is reported)'),
        ('Undo', 'SAVE held on the FM-1. Skiff 2.5.1 has no editor-protocol undo request (checked 2026-11-11: undo_step in ui.c is reached only from the panel), so the strip says “Hold SAVE on the FM-1”, no Undo key.', 'An UNDO request (a command calling undo_step), with level 2 or 3: then the strip’s Undo key.'),
    ]
    ty = LY + 44
    parts.append(tx(40, ty, 'Moment', 13, T2, 600)); parts.append(tx(420, ty, 'Level 1: today’s screen link and reads', 13, T2, 600)); parts.append(tx(1700, ty, 'Level 2: a screen link v7 (firmware)', 13, T2, 600))
    ty += 28
    for a, b, c in rows:
        parts.append(box(40, ty - 6, 3200, 1, 'background:#2A2A30;'))
        parts.append(tx(40, ty, a, 15, TEXT, 600)); parts.append(wrap(420, ty, 1220, b, 14, T2R)); parts.append(wrap(1700, ty, 1500, c, 14, T2R))
        ty += 66
    parts.append(wrap(40, ty + 10, 3100, 'Flash: the release build has about 3.2 KB left (rebase write-up, “Size”). The picker report and its commands are small (a flags bit, eight bytes, five commands), '
                 'but the captured notes themselves shouldn’t go over the link: Lupe keeps its own record from MIDI, so level 2 sends values only. Level 1 alone gives an honest guide and a good landing; '
                 'the picker on the iPad needs level 2, Keep that from the iPad level 3. <b>Decided 2026-11-11: form A (board 50).</b> The build waits for the open Lupe branches to merge and for Skiff-Lupe 2.5.1 on the device.', 14, NOTE))
    H = ty + 120
    return W, H, ''.join(parts)

# ================================ board 50: the picker's form ========================================================
def board50():
    parts = []
    W = 40 * 2 + 3 * 1376 + 2 * 64
    parts.append(tx(40, 32, '50 · The FREE TAKE picker: in the editor’s place (A, decided 2026-11-11), in the track’s lane (B), or a panel (C); the notes re-gridding live', 30, TEXT, 700))
    parts.append(wrap(40, 78, 2600,
        'Each at 1:1 with the same take on T3 Pulse Ld. Every form has the same four choices (Skiff’s knobs), the notes, Listen, Put back and Keep it, and every one keeps the Timeline in view. '
        'Under them: one form re-gridding as you change the tempo, the bars and the 1, and Keep’s in-place confirm. Pick a form; nothing is built.', 15, T2))
    Y = 190
    xs = [40 + i * (1376 + 64) for i in range(3)]
    edtop = 64 + 22 + 6 * 40 + 34

    # A · in the editor's place
    inner, lh = lanes(16, 64 + 12, 1344)
    a = [box(12, edtop, 1352, 1032 - edtop - 12, f'background:{tint(T, .18)};border-radius:18px;')]
    a.append(tx(36, edtop + 18, 'Keep that take on T3 Pulse Ld', 20, TEXT, 700))
    a.append(tx(36, edtop + 46, 'Replaces pattern 08 there. Undo brings it back.', 13, T2R))
    a.append(notes_view(36, edtop + 84, 860, 300))
    c, _ = controls(930, edtop + 84, 400); a.append(c)
    a.append(actions(36, 1032 - 12 - 68, 1300))
    parts.append(screen(xs[0], Y, 'A · In the editor’s place (where the sampler comes in) · DECIDED 2026-11-11', topbar(0, 0, 1376) + f'<div style="position:absolute;left:0;top:0">{inner}{"".join(a)}</div>'))
    parts.append(wrap(xs[0], Y + 1052, 1376, '<b style="color:#EDEDF0">For:</b> the editor’s own place and size, so nothing moves; the notes get the most room; the sampler already does this. '
                 '<b style="color:#EDEDF0">Against:</b> at No grid the editor is shut, so it opens to Half first (one slide). Controls 44 pt, all in reach of the right hand.', 14, T2))

    # B · in the track's lane
    lh_open = 360
    o = []
    ly = 64 + 12
    head = 220; bw = (1344 - head - 16) / 25
    o.append(box(16 + head, ly, 1344 - head - 8, 22, f'background:{PANEL};border-radius:6px;'))
    ly += 28
    for t in range(1, 7):
        h_ = lh_open if t == T else 34
        o.append(box(16, ly, 1336, h_, f'background:{tint(t) if t == T else PANEL};border-radius:{19 if t == T else 10}px;'))
        o.append(box(26, ly + 6, 22, 22, f'background:{COL[t]};border-radius:6px;'))
        o.append(tx(26, ly + 9, str(t), 13, ON, 700, f'width:22px;text-align:center;{NUM}'))
        o.append(tx(56, ly + 9, NAMES[t] + ' ⌄', 13, TEXT if t == T else '#C8C8CF', 600 if t == T else 400))
        if t == T:
            o.append(tx(56, ly + 40, 'Keep that take', 17, TEXT, 700))
            o.append(tx(56, ly + 64, 'replaces 08', 12, T2R))
            o.append(notes_view(16 + head, ly + 8, 700, 236))
            c, _ = controls(16 + head + 724, ly + 8, 380, compact=True); o.append(c)
            o.append(actions(16 + head, ly + h_ - 60, 1100))
        else:
            for (a_, b_, lab) in SONG[t]:
                bx = 16 + head + a_ * bw + 2; bwid = (b_ - a_) * bw - 4
                if lab == 'REST': o.append(box(bx, ly + 4, bwid, 26, 'border:1.5px dashed #7C7C85;border-radius:7px;'))
                else:
                    o.append(box(bx, ly + 4, bwid, 26, f'background:{tint(t, .32)};border:1.5px solid {COL[t]};border-radius:7px;'))
                    o.append(tx(bx + 8, ly + 10, lab, 11, TEXT, 600))
        ly += h_ + 6
    o.append(box(12, ly + 20, 1352, 1032 - ly - 32, f'background:{tint(1, .14)};border-radius:18px;'))
    o.append(tx(36, ly + 40, 'the editor, pushed down', 13, T2))
    parts.append(screen(xs[1], Y, 'B · In the track’s lane (the lane opens where the take lands)', topbar(0, 0, 1376) + f'<div style="position:absolute;left:0;top:0">{"".join(o)}</div>'))
    parts.append(wrap(xs[1], Y + 1052, 1376, '<b style="color:#EDEDF0">For:</b> it opens exactly where the take will live, in the lane’s tint: the most LCARS, and it says which track without words. '
                 '<b style="color:#EDEDF0">Against:</b> the lanes below and the editor move down to make room (a slide, but the biggest move of the three), and the notes get less room than in A.', 14, T2))

    # C · a panel
    inner3, lh3 = lanes(16, 64 + 12, 1344)
    ed = box(12, edtop, 1352, 1032 - edtop - 12, f'background:{tint(1, .14)};border-radius:18px;')
    pw = 560
    pnl = [box(1376 - pw - 12, 76, pw, 1032 - 88, f'background:{HELD};border-radius:18px;box-shadow:-8px 0 24px rgba(0,0,0,.35);')]
    px = 1376 - pw + 12
    pnl.append(tx(px, 96, 'Keep that take', 20, TEXT, 700))
    pnl.append(tx(px, 124, 'on T3 Pulse Ld · replaces pattern 08', 13, T2R))
    pnl.append(notes_view(px, 160, pw - 48, 230))
    c, _ = controls(px, 412, pw - 48); pnl.append(c)
    pnl.append(actions(px, 1032 - 12 - 68 - 12, pw - 48))
    parts.append(screen(xs[2], Y, 'C · A panel from the right (where the sound panel comes in)', topbar(0, 0, 1376) + f'<div style="position:absolute;left:0;top:0">{inner3}{ed}{"".join(pnl)}</div>'))
    parts.append(wrap(xs[2], Y + 1052, 1376, '<b style="color:#EDEDF0">For:</b> nothing under it moves; it reads as a tool you finish and close, like the sound panel. '
                 '<b style="color:#EDEDF0">Against:</b> it covers the right of the Timeline, where the take’s own block will land; the notes are the smallest of the three.', 14, T2))

    # live re-grid
    RY = Y + 1032 + 150
    parts.append(tx(40, RY, 'The notes re-grid as the choices change (form A’s notes, the same take)', 24, TEXT, 700))
    parts.append(wrap(40, RY + 36, 3000, 'The phrase as played, then placed by each choice: the bar lines, the 16ths and the notes move together on a 150 ms ease (Reduce Motion: a cross-fade). '
                 'A wrong guess shows at a glance: notes bunched on the beats at half time, spread thin at double.', 14, T2))
    gy = RY + 80
    gw, gh = 1000, 220
    cells = [('As played (seconds)', dict(raw=True)), ('96 BPM, 2 bars, 1 on the first note: Skiff’s guess', dict(bpm=96, bars=2)),
             ('192 BPM (double), 4 bars', dict(bpm=192, bars=4)), ('48 BPM (half), 1 bar', dict(bpm=48, bars=1)),
             ('96 BPM, 1 on the 8th note', dict(bpm=96, bars=2, first=7)), ('96 BPM, 4 bars: the take, then 2 bars empty', dict(bpm=96, bars=4))]
    for i, (lab, kw) in enumerate(cells):
        cx = 40 + (i % 3) * (gw + 60); cy = gy + (i // 3) * (gh + 64)
        parts.append(tx(cx, cy, lab, 14, TEXT, 600))
        parts.append(notes_view(cx, cy + 26, gw, gh, **kw))

    # confirm
    CY = gy + 2 * (gh + 64) + 40
    parts.append(tx(40, CY, 'Keep it: asked once more in place, as the Pads ask before erasing', 24, TEXT, 700))
    parts.append(wrap(40, CY + 36, 2000, 'The pattern it replaces is used nowhere else, so it would go for good without undo; Skiff’s undo (SAVE held, 6 levels in 2.5) can bring it back, but a confirm still names what goes. '
                 'If pattern 08 is used on other entries too, the line says so (“and 2 other entries”). The confirm turns Keep it into a red-outlined button where it was, with Put back beside it, as Clear entry does.', 14, T2))
    parts.append(box(40, CY + 100, 1376, 92, f'background:{tint(T, .18)};border-radius:18px;'))
    parts.append(actions(64, CY + 124, 1328, confirm=True))
    parts.append(tx(64 + 1328 - 250, CY + 172, 'Undo brings it back (SAVE held)', 12, T2R))

    # contrast
    KY = CY + 240
    parts.append(tx(40, KY, 'Contrast (worst case)', 16, TEXT, 700))
    pairs = [('Text on the picker’s tint (T3 at 18%)', cr(TEXT, tint(T, .18)), 4.5), ('Secondary text on it', cr(T2R, tint(T, .18)), 4.5),
             ('Notes (track colour) on the well', min(cr(COL[t], WELL) for t in COL), 3), ('Bar line on the well', cr('#3A3A42', WELL), 1.0),
             ('Selected choice text on the held grey', cr(TEXT, HELD), 4.5), ('Choice captions (secondary) on the well', cr(T2R, WELL), 4.5),
             ('Keep it (dark on light)', cr(ON, TEXT), 4.5), ('Confirm outline (rec text) on the tint', cr(REC, tint(T, .18)), 3)]
    for i, (n, v, need) in enumerate(pairs):
        parts.append(tx(40, KY + 30 + i * 24, f'{v:5.2f}:1', 14, TEXT if v >= need else NOTE, 700, f'{NUM}width:62px;'))
        parts.append(tx(110, KY + 31 + i * 24, n + (f' (needs {need:g}:1)' if need > 1 else ' (decoration: the beat lines carry no meaning alone)'), 13, '#C8C8CF'))
    R = KY + 30 + len(pairs) * 24 + 30
    parts.append(box(40, R, 1700, 210, f'background:{PANEL};border-radius:14px;'))
    parts.append(tx(64, R + 20, 'Decided 2026-11-11: A, in the editor’s place (my pick, and Scott’s)', 20, TEXT, 700))
    parts.append(wrap(64, R + 56, 1640,
        'It moves nothing: the picker takes the editor’s own place and size, the way the sampler already does, and the Timeline stays where it was, so the take’s block lands in view. '
        'The notes get the most room, which matters because re-gridding is how you judge the guess. B is the most LCARS and names the track without words, but it moves every lane below '
        'and the editor; C covers the right of the Timeline, where the block will land. Whichever wins, the controls are the same four, so the FM-1’s knobs and the iPad never disagree.', 15, '#C8C8CF'))
    H = R + 250
    return W, H, ''.join(parts)

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

W, H, b = board49(); write('FreeTakeFlow.dc.html', W, H, b, 'Free take flow')
W, H, b = board50(); write('FreeTakePicker.dc.html', W, H, b, 'Free take picker')

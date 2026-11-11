# Board 44: Song · Mix · Sounds as a tab on a line (Scott, 2026-11-09). Static HTML for the Lupe canvas.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, TEXT, T2 = '#0D0D0F', '#EDEDF0', '#A1A1AA'
def tx(x, y, s, size, c, wt=400, extra=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.2;white-space:nowrap;{extra}">{html.escape(s)}</div>'

TABS = [('Song', 96), ('Mix', 72), ('Sounds', 104)]
def bar(x, y, active, grey, th, scale=1.0):
    """The tabs: the active one a grey tab rising from a line `th` thick that runs under the rest and tapers off."""
    h, r, f, taper, pad = 40, 10, 6, 28, 8          # tab height, its top corners, the fillets into the line, taper, run past
    xs, cx = [], 0
    for _, w in TABS:
        xs.append((cx, cx + w)); cx += w + 4
    end = cx + pad
    ax0, ax1 = xs[active]
    base = h                                        # the line's top
    p = (f'M0 {base} '                               # the line from the left to the tab
         + (f'L{ax0 - f} {base} Q{ax0} {base} {ax0} {base - f} ' if ax0 > 0 else f'L0 {base} ')
         + f'L{ax0} {r} Q{ax0} 0 {ax0 + r} 0 L{ax1 - r} 0 Q{ax1} 0 {ax1} {r} L{ax1} {base - f} Q{ax1} {base} {ax1 + f} {base} '
         + f'L{end} {base} L{end + taper} {base + th} L0 {base + th} Z')   # the taper: the top edge runs on and down to nothing
    if ax0 == 0:
        p = (f'M0 {r} Q0 0 {r} 0 L{ax1 - r} 0 Q{ax1} 0 {ax1} {r} L{ax1} {base - f} Q{ax1} {base} {ax1 + f} {base} '
             f'L{end} {base} L{end + taper} {base + th} L0 {base + th} Z')
    o = [f'<div style="position:absolute;left:{x}px;top:{y}px;transform:scale({scale});transform-origin:0 0;">',
         f'<svg style="position:absolute;left:0;top:0;overflow:visible" width="1" height="1"><path d="{p}" fill="{grey}"/></svg>']
    for k, ((name, w), (x0, x1)) in enumerate(zip(TABS, xs)):
        on = k == active
        o.append(tx(x0, 10, name, 17, TEXT if on else T2, 600 if on else 400, f'width:{w}px;text-align:center;'))
    o.append('</div>')
    return ''.join(o)

parts = [tx(40, 40, '44 · Song · Mix · Sounds: a tab on a line', 30, TEXT, 600),
         tx(40, 86, 'The active tab grey behind its word, rising from a line that runs under the others and tapers off past Sounds, as the editor panel’s tab rises from its panel. Fillets 6 where tab meets line; tab corners 10.', 15, T2, 400, 'width:1500px;white-space:normal;'),
         tx(40, 112, 'Today: a white-ringed box round the word. Left column: the tab grey (#26262B, the control grey); right: a step lighter (#34343B), since a 2–3 pt line of #26262B on the page is 1.3:1 and nearly vanishes.', 15, T2, 400, 'width:1500px;white-space:normal;')]
y = 180
for th in (2, 3):
    parts.append(tx(40, y, f'Line {th} pt', 20, TEXT, 600))
    for ci, grey in enumerate(['#26262B', '#34343B']):
        cx = 40 + ci * 520
        parts.append(tx(cx, y + 30, f'{grey}', 13, T2))
        for k in range(3):
            parts.append(bar(cx, y + 60 + k * 70, k, grey, th))
    y += 300
parts.append(tx(1100, 180, 'At 2× (Song active, #34343B, 3 pt)', 20, TEXT, 600))
parts.append(bar(1100, 230, 0, '#34343B', 3, scale=2))
parts.append(tx(1100, 360, 'Mix active: the line runs under Song too, so the bar reads as one piece wherever the tab is.', 13, T2, 400, 'width:560px;white-space:normal;'))
parts.append(bar(1100, 400, 1, '#34343B', 3, scale=2))
parts.append(tx(1100, 540, 'Moving between tabs: the tab slides along the line to the new word (≈200 ms, ease-out), the words blend weight; nothing pops (DESIGN.md).', 13, T2, 400, 'width:560px;white-space:normal;'))
BW, BH = 1720, 820
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};font-family:-apple-system,\'SF Pro Text\',system-ui,sans-serif;overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe top tabs</title>
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
open(os.path.join(OUT, 'TopTabs.dc.html'), 'w').write(doc)
print('TopTabs.dc.html', BW, BH)

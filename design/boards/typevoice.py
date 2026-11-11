# Board 45: Lupe's type voice (Scott, 2026-11-09). Static HTML for the canvas; Google Fonts for Barlow and JetBrains Mono.
import os, html
OUT = os.environ.get('OUT', 'canvas/project')
PAGE, PANEL, PAD, WELL, TEXT, T2, T3, ON = '#0D0D0F', '#1A1A1E', '#26262B', '#111114', '#EDEDF0', '#A1A1AA', '#C4C4CC', '#101012'
ACID, ACIDT, PADC = '#FF5A36', '#4A1F17', '#22C3B4'
def box(x, y, w, h, st=''): return f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;box-sizing:border-box;{st}"></div>'
def tx(x, y, s, size, c, wt=400, fam='', extra=''):
    return f'<div style="position:absolute;left:{x}px;top:{y}px;font-size:{size}px;font-weight:{wt};color:{c};line-height:1.15;white-space:nowrap;{fam}{extra}">{html.escape(s)}</div>'

SF = "font-family:-apple-system,'SF Pro Text',system-ui,sans-serif;"
VOICES = [
    ('A · SF Pro (as built)', 'The system face, the hierarchy fixed: bold even figures for numbers, regular words. Familiar, invisible, Apple-native.',
     dict(word=SF, num=SF + 'font-variant-numeric:tabular-nums;', numw=700, title=SF, titlew=600, tabs=SF)),
    ('B · Barlow (the FM-1’s face)', 'Skiff draws its screen in Barlow: Lupe would look like the instrument’s companion. Barlow Condensed for numbers and titles makes room in tight heads.',
     dict(word="font-family:'Barlow',sans-serif;", num="font-family:'Barlow Condensed',sans-serif;font-variant-numeric:tabular-nums;", numw=600,
          title="font-family:'Barlow Condensed',sans-serif;", titlew=600, tabs="font-family:'Barlow',sans-serif;")),
    ('C · SF Pro words, mono numbers', 'Numbers in JetBrains Mono, like a hardware readout; words stay SF Pro. The most “instrument”, but mono figures run wide and can read technical.',
     dict(word=SF, num="font-family:'JetBrains Mono',monospace;", numw=700, title=SF, titlew=600, tabs=SF)),
]

def column(x0, y0, title, note, v):
    o = [tx(x0, y0, title, 22, TEXT, 600, SF), tx(x0, y0 + 32, note, 13, T2, 400, SF, 'width:620px;white-space:normal;line-height:1.4;')]
    y = y0 + 100
    # page tabs on a line
    tabs = [('Song', 96), ('Mix', 72), ('Sounds', 104)]
    cx = x0
    o.append(box(x0, y + 40, 288, 3, 'background:#34343B;border-radius:2px;'))
    o.append(box(x0, y, 96, 42, 'background:#34343B;border-radius:10px 10px 0 0;'))
    for k, (n, w) in enumerate(tabs):
        o.append(tx(cx, y + 11, n, 17, TEXT if k == 0 else T2, 600 if k == 0 else 400, v['tabs'], f'width:{w}px;text-align:center;'))
        cx += w + 4
    # a track head with its lane, and three pads
    y += 80
    o.append(f'<svg style="position:absolute;left:0;top:0;overflow:visible" width="1" height="1"><path d="M{x0+19} {y} L{x0+640} {y} L{x0+640} {y+128} L{x0+260} {y+128} A16 16 0 0 1 {x0+244} {y+112} L{x0+244} {y+116} A16 16 0 0 0 {x0+228} {y+100} L{x0+19} {y+100} A19 19 0 0 1 {x0} {y+81} L{x0} {y+19} A19 19 0 0 1 {x0+19} {y} Z" fill="{ACIDT}"/></svg>')
    o.append(box(x0 + 12, y + 12, 44, 44, f'background:{ACID};border-radius:11px;'))
    o.append(tx(x0 + 12, y + 22, '1', 22, ON, v['numw'], v['num'], 'width:44px;text-align:center;'))
    o.append(tx(x0 + 66, y + 20, 'A', 15, T2, 600, v['title']))
    o.append(tx(x0 + 82, y + 14, '01', 22, TEXT, v['numw'], v['num']))
    o.append(tx(x0 + 66, y + 42, 'pass 2 of 4', 12, T2, 400, v['word']))
    o.append(tx(x0 + 12, y + 66, 'Acid', 15, T3, 400, v['word']))
    o.append(box(x0 + 12, y + 88, 132, 4, '#2A2A30;background:#2A2A30;border-radius:2px;'))
    o.append(box(x0 + 12, y + 88, 66, 4, f'background:{ACID};border-radius:2px;'))
    o.append(box(x0 + 160, y + 12, 64, 40, f'background:{TEXT};border-radius:8px;'))
    o.append(tx(x0 + 160, y + 22, 'M', 16, ON, 700, v['word'], 'width:64px;text-align:center;'))
    o.append(box(x0 + 160, y + 58, 64, 40, f'background:{PAD};border-radius:8px;'))
    o.append(tx(x0 + 160, y + 68, 'S', 16, TEXT, 700, v['word'], 'width:64px;text-align:center;'))
    for i, (lab, num, sub, fill) in enumerate([('A', '01', 'On it', False), ('B', '02', 'Next', False), ('C', '03', '×4', False)]):
        px = x0 + 244 + i * 134
        o.append(box(px, y, 128, 128, f'background:{PAD};border-radius:16px;' + ('box-shadow:inset 0 0 0 3px ' + ACID + ';' if i == 0 else '')))
        o.append(tx(px + 14, y + 12, lab, 15, T2, 600, v['title']))
        o.append(tx(px + 14, y + 34, num, 28, TEXT, v['numw'], v['num']))
        o.append(tx(px + 14, y + 70, sub, 15, T2, 400, v['word']))
    # a knob tile and the editor header
    y += 160
    for k, (lab, val, unit) in enumerate([('CUTOFF', '355', 'Hz'), ('RES', '79', '%'), ('LEVEL', '81', '')]):
        tx0 = x0 + k * 100
        o.append(box(tx0, y, 92, 56, f'background:{WELL};border-radius:6px;'))
        o.append(tx(tx0 + 10, y + 7, lab, 11, T2, 500, v['word'], 'letter-spacing:0.04em;'))
        o.append(tx(tx0 + 10, y + 24, val, 22, TEXT, 600, v['num']))
        if unit: o.append(tx(tx0 + 10 + 13 * len(val) + 4, y + 33, unit, 11, T2, 400, v['word']))
    o.append(box(x0 + 320, y + 6, 44, 44, f'background:{ACID};border-radius:10px;'))
    o.append(tx(x0 + 320, y + 16, '1', 20, ON, v['numw'], v['num'], 'width:44px;text-align:center;'))
    o.append(tx(x0 + 374, y + 8, 'Acid', 17, TEXT, 600, v['title']))
    o.append(tx(x0 + 374, y + 32, 'pattern 01 · 16 steps', 13, T2, 400, v['word']))
    return ''.join(o)

parts = [tx(40, 40, '45 · Lupe’s type voice', 30, TEXT, 600, SF),
         tx(40, 86, 'The same piece of Lupe in three faces: the page tabs, a track head on its lane with three pads, knob tiles and the editor header. A is what’s on the iPad now.', 15, T2, 400, SF),
         tx(40, 112, 'Type is the whole app, not one screen: pick a voice here, then it’s applied everywhere at once (DESIGN.md gets the ladder).', 15, TEXT, 600, SF)]
for k, (t, n, v) in enumerate(VOICES):
    parts.append(column(40 + k * 700, 170, t, n, v))
BW, BH = 2140, 640
body = f'<div style="position:relative;width:{BW}px;height:{BH}px;background:{PAGE};color:{TEXT};overflow:hidden;">{"".join(parts)}</div>'
doc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lupe type voice</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600;700&family=Barlow+Condensed:wght@500;600;700&family=JetBrains+Mono:wght@500;700&display=swap">
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet><style>body{{margin:0}}</style><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600;700&family=Barlow+Condensed:wght@500;600;700&family=JetBrains+Mono:wght@500;700&display=swap"></helmet>
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
open(os.path.join(OUT, 'TypeVoice.dc.html'), 'w').write(doc)
print('TypeVoice.dc.html', BW, BH)

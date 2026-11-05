TR=['#FF5A36','#22C3B4','#FFBF00','#9580FF','#FF6FAE','#A3E635']
NAMES=['Drums','Bass','Keys','Pad','Lead','Perc']
P='#0D0D0F'; WELL='#111114'; PANEL='#1A1A1E'; CTRL='#26262B'; LIFT='#34343B'; T1='#EDEDF0'; T2='#A1A1AA'
def chic(label,pri=False,sm=False):
    h=32 if sm else 40
    if pri: return f'<span style="height:{h}px;padding:0 12px;border-radius:8px;background:{T1};color:#101012;font-weight:600;display:inline-flex;align-items:center;box-shadow:0 2px 0 #8A8A92;white-space:nowrap;font-size:13px">{label}</span>'
    return f'<span style="height:{h}px;padding:0 12px;border-radius:8px;background:{CTRL};color:{T1};display:inline-flex;align-items:center;box-shadow:0 2px 0 #0A0A0C;white-space:nowrap;font-size:13px">{label}</span>'
# song: per track list of (entry, pattern, bars)
SONG=[[('A','01',4),('B','02',4),('C','02',4),('D','03',4),('E','04',4)],
      [('A','REST',4),('B','05',4),('C','07',4),('D','07',4),('E','05',4)],
      [('A','08',8),('B','09',4),('C','08',8)],
      [('A','10',12),('B','11',8)],
      [('A','REST',8),('B','12',4),('C','13',4),('D','12',4)],
      [('A','14',2),('B','14',2),('C','15',2),('D','14',2),('E','14',2),('F','15',2),('G','14',2),('H','16',6)]]
BARS=20
def song(play_bar,sel_track,pinned=None,lane_h=30,width=1100,label_w=150):
    bw=(width-label_w)/BARS; out=''
    ruler=''.join(f'<span style="position:absolute;left:{label_w+i*bw+4:.0f}px;top:2px;font-size:11px;color:{T2}">{i+1}</span>' for i in range(0,BARS,4))
    out+=f'<div style="position:relative;height:18px">{ruler}</div>'
    for t in range(6):
        x=0; blocks=''
        for (e,pat,bars) in SONG[t]:
            playing = x<=play_bar<x+bars
            pin = pinned==(t,e)
            rest = pat=='REST'
            bg='transparent' if rest else TR[t]
            op='1' if (playing or pin) else '0.5'
            ring=(f'box-shadow:0 0 0 2px {T1},0 4px 12px rgba(0,0,0,.45);' if (t==sel_track and (pin or (pinned is None and playing))) else (f'box-shadow:inset 0 0 0 2px {T1};' if playing else ''))
            bord='border:1px dashed #4A4A52;' if rest else ''
            txt='#101012' if not rest else T2
            blocks+=(f'<div style="position:absolute;left:{label_w+x*bw+1:.1f}px;top:3px;width:{bars*bw-3:.1f}px;height:{lane_h-6}px;border-radius:5px;background:{bg};opacity:{op};{ring}{bord}box-sizing:border-box;'
                     f'display:flex;align-items:center;gap:6px;padding:0 6px;font-size:11px;font-weight:600;color:{txt};overflow:hidden;white-space:nowrap">{e} · {pat if not rest else "REST"}</div>')
            x+=bars
        sel=t==sel_track
        chip=f'<span style="width:22px;height:22px;border-radius:6px;background:{TR[t] if sel else CTRL};color:{"#101012" if sel else T1};font-size:11px;font-weight:600;display:flex;align-items:center;justify-content:center;{"box-shadow:0 0 0 2px "+T1 if sel else ""}">{t+1}</span>'
        out+=(f'<div style="position:relative;height:{lane_h}px"><div style="position:absolute;left:0;top:0;width:{label_w-10}px;height:{lane_h}px;display:flex;align-items:center;gap:8px">{chip}<span style="font-size:13px;{"font-weight:600" if sel else "color:"+T2}">{NAMES[t]}</span></div>'
              f'<div style="position:absolute;left:{label_w}px;right:0;top:2px;bottom:2px;background:{WELL};border-radius:5px"></div>{blocks}</div>')
    ph=f'<div aria-hidden="true" style="position:absolute;left:{label_w+play_bar*bw:.0f}px;top:0;bottom:0;width:2px;background:{T1};box-shadow:0 0 6px rgba(237,237,240,.6)"></div>'
    return f'<div style="position:relative;display:flex;flex-direction:column;gap:3px">{out}{ph}</div>'
def roll(track,width=760,rows=6,cw=None,hl=None):
    N=16; cw=cw or (width-50)/N; notes=['D5','C5','A#4','G4','F4','D#4','C4','A#3','G3','F3','D#3','C3']
    seq=[(2,0,2),(3,2,1),(5,4,2),(4,6,1),(6,8,3),(3,12,2),(5,10,1),(2,14,2),(7,7,1),(9,0,1),(9,4,1),(11,8,2),(9,12,1),(0,15,1)]
    g=''
    for r in range(rows):
        g+=f'<div style="position:absolute;left:0;top:{r*26}px;width:44px;height:26px;font-size:11px;color:{T2};display:flex;align-items:center;justify-content:flex-end">{notes[r]}</div><div style="position:absolute;left:50px;top:{r*26+1}px;width:{N*cw:.0f}px;height:24px;background:{WELL};border-radius:4px"></div>'
    for r,s,l in seq: g+=f'<div style="position:absolute;left:{50+s*cw+2:.0f}px;top:{r*26+3}px;width:{l*cw-4:.0f}px;height:20px;border-radius:4px;background:{TR[track]}"></div>'
    play=f'<div aria-hidden="true" style="position:absolute;left:{50+(hl or 0)*cw:.0f}px;top:-4px;width:{cw:.0f}px;height:{rows*26+8}px;background:rgba(237,237,240,.08);border-radius:4px"></div>' if hl is not None else ''
    nums=''.join(f'<span style="position:absolute;left:{50+i*cw:.0f}px;width:{cw:.0f}px;top:-20px;text-align:center;font-size:11px;color:{T2}">{i+1}</span>' for i in range(N))
    return f'<div style="position:relative;height:{rows*26}px;margin-top:20px">{play}{nums}{g}</div>'
def vel(track,width=760,hl=None):
    N=16; cw=(width-50)/N; v=[100,0,96,0,104,0,88,90,104,0,92,0,110,0,84,70]
    bars=''.join(f'<rect x="{50+i*cw+cw/2-3:.0f}" y="{40-x/127*34:.0f}" width="6" height="{x/127*34:.0f}" rx="2" fill="{TR[track]}"/>' for i,x in enumerate(v) if x)
    return f'<svg width="{width}" height="42" aria-hidden="true"><text x="44" y="26" fill="{T2}" font-size="11" text-anchor="end" font-family="system-ui">VEL</text>{bars}</svg>'
def lane(track,width=760):
    import math
    N=16; cw=(width-50)/N; pts=[]; cur=30; ev={0:30,4:14,9:22,13:8}
    for i in range(N+1):
        if i in ev: cur=ev[i]
        pts.append((50+i*cw,cur));
        if i<N: pts.append((50+(i+1)*cw,cur))
    d='M'+' L'.join(f'{a:.0f},{b}' for a,b in pts)
    return f'<div style="display:flex;align-items:center;gap:0"><svg width="{width}" height="40" aria-hidden="true"><text x="44" y="24" fill="{T2}" font-size="11" text-anchor="end" font-family="system-ui">CUTOFF</text><rect x="50" y="2" width="{N*cw:.0f}" height="36" rx="5" fill="{WELL}"/><path d="{d}" fill="none" stroke="{TR[track]}" stroke-width="2"/></svg></div>'
def pattern_header(track,entry,pat,shared,following=True):
    fol=(f'<span style="height:32px;padding:0 10px;border-radius:8px;background:{LIFT};box-shadow:0 0 0 2px {T1};display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600"><span style="width:8px;height:8px;border-radius:4px;background:#30D158"></span>Following the song</span>'
         if following else f'<span style="height:32px;padding:0 10px;border-radius:8px;background:{CTRL};display:inline-flex;align-items:center;gap:8px;font-size:13px"><svg width="12" height="12" viewBox="0 0 12 12" aria-hidden="true"><path d="M6 1v6M3 4h6M6 7v4" stroke="{T1}" stroke-width="1.6"/></svg>Pinned to entry {entry}</span>{chic("Follow",sm=True)}')
    sh=(f'<span style="font-size:12px;color:{T2}">also on entries {shared}</span>{chic("Make unique",sm=True)}' if shared else '')
    return (f'<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap"><span style="width:26px;height:26px;border-radius:7px;background:{TR[track]};color:#101012;font-weight:600;font-size:12px;display:flex;align-items:center;justify-content:center">{track+1}</span>'
            f'<span style="font-weight:600">{NAMES[track]}</span><span style="height:28px;padding:0 10px;border-radius:7px;background:{CTRL};display:inline-flex;align-items:center;gap:6px;font-size:13px;box-shadow:0 2px 0 #0A0A0C">pattern <b style="font-weight:600">{pat}</b> ▾</span>'
            f'<span style="font-size:13px;color:{T2}">entry {entry}</span>{sh}<span style="flex:1"></span>{fol}</div>')
def topbar():
    tabs=f'<span style="height:40px;padding:0 16px;border-radius:8px;background:{LIFT};box-shadow:0 0 0 2px {T1};display:flex;align-items:center;font-weight:600">Song</span>'+''.join(f'<span style="height:40px;padding:0 16px;display:flex;align-items:center;color:{T2}">{t}</span>' for t in ['Shape','Browse'])
    return (f'<header style="height:60px;display:flex;align-items:center;gap:16px;padding:0 24px"><span style="display:flex;align-items:center;gap:8px;font-weight:600"><span style="width:8px;height:8px;border-radius:4px;background:#30D158"></span>FM-1</span>'
            f'<nav style="display:flex;gap:4px;margin-left:180px">{tabs}</nav><span style="flex:1"></span>{chic("Mixer")}<span style="color:{T2}">9 · 03 &nbsp; 120 BPM</span>'
            f'<span style="width:40px;height:40px;border-radius:8px;background:{CTRL};display:flex;align-items:center;justify-content:center;box-shadow:0 2px 0 #0A0A0C"><span style="width:12px;height:12px;background:{T1};border-radius:2px"></span></span></header>')
STEPNOTE=True
def make_inspector():
  return f'''<section aria-label="Step 9" style="width:300px;flex-shrink:0;padding:14px;border-radius:12px;background:{PANEL};display:flex;flex-direction:column;gap:10px;box-sizing:border-box">
<div style="display:flex;justify-content:space-between;align-items:baseline"><span style="font-weight:600;font-size:17px">Step 9</span><span style="font-size:12px;color:{T2}">{"playing now" if STEPNOTE else "selected"}</span></div>
<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px">{''.join(f'<div style="padding:6px 8px;border-radius:7px;background:{WELL}"><div style="font-size:11px;color:{T2}">{l}</div><div style="font-weight:600">{v}</div></div>' for l,v in [('Pitch','C4'),('Move','9'),('Length','3'),('Velocity','104')])}</div>
<span style="font-size:12px;color:{T2}">Whole track</span>
<div style="display:flex;gap:6px">{''.join(f'<div style="flex:1;padding:6px 8px;border-radius:7px;background:{WELL}"><div style="font-size:11px;color:{T2}">{l}</div><div style="font-weight:600">{v}</div></div>' for l,v in [('Swing','16'),('Level','78'),('Steps','16'),('Pan','0')])}</div></section>'''
def page(play_bar,sel,pinned,entry,pat,shared,following,step_hl,split=0.40,title=''):
    global STEPNOTE; STEPNOTE=following
    song_h=int(1032*split)
    return f'''<div style="width:1376px;height:1032px;box-sizing:border-box;background:{P};color:{T1};font-family:-apple-system,'SF Pro Text',system-ui,sans-serif;font-size:14px;line-height:1.4;font-variant-numeric:tabular-nums;display:flex;flex-direction:column">
{topbar()}
<div style="padding:0 24px 24px;display:flex;flex-direction:column;gap:10px;flex:1;min-height:0">
<section aria-label="Song" style="padding:12px 16px;border-radius:12px;background:{PANEL};box-shadow:0 6px 16px rgba(0,0,0,.35)">{song(play_bar,sel,pinned,lane_h=max(26,int((song_h-80)/6)),width=1296)}</section>
<div role="separator" aria-label="Drag to share the space between the song and the pattern" style="height:14px;display:flex;align-items:center;justify-content:center"><span style="width:56px;height:5px;border-radius:3px;background:#4A4A52"></span></div>
<section aria-label="Pattern" style="flex:1;min-height:0;padding:14px 16px;border-radius:12px;background:{PANEL};box-shadow:0 6px 16px rgba(0,0,0,.35);display:flex;flex-direction:column;gap:12px">
{pattern_header(sel,entry,pat,shared,following)}
<div style="display:flex;gap:16px;flex:1;min-height:0">{make_inspector()}<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:8px">{roll(sel,width=930,rows=12,hl=step_hl)}{vel(sel,width=930,hl=step_hl)}{lane(sel,width=930)}</div></div>
</section></div></div>'''
def board(fname,html,w=1376,h=1032,title='Song and pattern'):
    open(f'../../../547e060a-28b7-4814-99a6-e31a875e28ac/scratchpad/songcanvas/project/{fname}','w').write(f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{title}</title><script src="./support.js"></script></head>
<body><x-dc><helmet><style>body{{margin:0}}</style></helmet>{html}</x-dc><script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":{w},"height":{h}}}}}'>
class Component extends DCLogic {{ renderVals() {{ return {{}}; }} }}
</script></body></html>''')
board('Compose.dc.html', page(8.6,1,None,'C','07','D',True,8), title='Song and pattern, following')
board('ComposePinned.dc.html', page(14.2,1,(1,'B'),'B','05','E',False,None,split=0.30), title='Song and pattern, pinned')

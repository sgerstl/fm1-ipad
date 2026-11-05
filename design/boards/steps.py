TR=['#FF5A36','#22C3B4','#FFBF00','#9580FF','#FF6FAE','#A3E635']
NAMES=['Drums','Bass','Keys','Pad','Lead','Perc']
SEL=1; COL=TR[SEL]; STEP=4   # step 5 selected (0-based 4)
P='#0D0D0F'; WELL='#111114'; PANEL='#1A1A1E'; CTRL='#26262B'; LIFT='#34343B'; T1='#EDEDF0'; T2='#A1A1AA'
def chic(label,pri=False,sm=False,on=False):
    h=36 if sm else 44
    if pri: return f'<button style="height:{h}px;padding:0 14px;border:0;border-radius:8px;background:{T1};color:#101012;font:inherit;font-weight:600;box-shadow:0 2px 0 #8A8A92;white-space:nowrap">{label}</button>'
    if on: return f'<button aria-pressed="true" style="height:{h}px;padding:0 12px;border:0;border-radius:8px;background:#141417;color:{T1};font:inherit;font-weight:600;transform:translateY(2px);white-space:nowrap">{label}</button>'
    return f'<button style="height:{h}px;padding:0 12px;border:0;border-radius:8px;background:{CTRL};color:{T1};font:inherit;box-shadow:0 2px 0 #0A0A0C;white-space:nowrap">{label}</button>'
# --- track box (compact)
rows=''
pat=[[1,0,0,0,1,0,1,0,1,0,0,0,1,0,1,1],[1,0,1,0,1,0,0,1,1,0,1,0,0,1,0,0],[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0],[1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0],[0,1,0,1,0,0,1,0,0,1,0,1,0,0,1,0],[1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1]]
for t in range(6):
    sel=t==SEL
    chip=f'<span style="width:28px;height:28px;border-radius:7px;background:{TR[t] if sel else CTRL};color:{"#101012" if sel else T1};font-weight:600;font-size:13px;display:flex;align-items:center;justify-content:center;{"box-shadow:0 0 0 2px "+T1+",0 4px 12px rgba(0,0,0,.45)" if sel else "box-shadow:0 2px 0 #0A0A0C"}">{t+1}</span>'
    cells=''.join(f'<span style="flex:1;height:14px;border-radius:3px;background:{TR[t] if pat[t][i] else "#2A2A30"};{"opacity:.55" if not sel else ""}"></span>' for i in range(16))
    mot='<span style="font-size:11px;color:#A1A1AA;margin-left:8px;display:flex;align-items:center;gap:4px"><svg width="12" height="12" viewBox="0 0 12 12" aria-hidden="true"><path d="M1 9 L4 9 L4 4 L8 4 L8 7 L11 7" fill="none" stroke="#A1A1AA" stroke-width="1.4"/></svg>motion</span>' if t in (1,4) else '<span style="width:58px"></span>'
    rows+=f'<div style="display:flex;align-items:center;gap:10px;height:26px">{chip}<span style="width:120px;font-size:13px;{"font-weight:600" if sel else "color:"+T2}">{NAMES[t]}</span><div style="flex:1;display:flex;gap:3px">{cells}</div>{mot}</div>'
trackbox=f'<section aria-label="Tracks" style="padding:12px 16px;border-radius:12px;background:{PANEL};box-shadow:0 6px 16px rgba(0,0,0,.35);display:flex;flex-direction:column;gap:6px">{rows}</section>'
# --- step grid geometry
GX=56; CW=52; N=16
def colx(i): return GX+i*CW
notes=['A#4','G4','F4','D#4','C4','A#3']
roll=[(0,1,4),(1,4,2),(3,0,1),(2,2,1),(4,8,3),(1,12,2),(3,9,1),(0,14,2),(5,6,1),(2,4,1)]
grid=''
for r,n in enumerate(notes):
    grid+=f'<div style="position:absolute;left:0;top:{r*30}px;width:48px;height:30px;font-size:11px;color:{T2};display:flex;align-items:center;justify-content:flex-end">{n}</div>'
    grid+=f'<div style="position:absolute;left:{GX}px;top:{r*30+1}px;width:{N*CW}px;height:28px;background:{WELL};border-radius:4px"></div>'
for r,s,l in roll:
    sel=s<=STEP<s+l
    grid+=f'<div style="position:absolute;left:{colx(s)+2}px;top:{r*30+3}px;width:{l*CW-4}px;height:24px;border-radius:5px;background:{COL};{"box-shadow:0 0 0 2px "+T1 if sel else ""}"></div>'
# selected column
selcol=f'<div aria-hidden="true" style="position:absolute;left:{colx(STEP)}px;top:-30px;width:{CW}px;bottom:-8px;background:rgba(237,237,240,0.07);border-radius:6px;box-shadow:inset 0 0 0 1px rgba(237,237,240,0.25)"></div>'
ruler=''.join(f'<span style="position:absolute;left:{colx(i)}px;width:{CW}px;top:-26px;text-align:center;font-size:12px;{"color:"+T1+";font-weight:600" if i==STEP else "color:"+T2}">{i+1}</span>' for i in range(N))
# velocity lane
vels=[112,0,96,0,100,0,0,88,120,0,90,0,104,0,82,0]
vel=''.join(f'<span style="position:absolute;left:{colx(i)-GX+CW/2-3}px;bottom:0;width:6px;height:{v/127*34:.0f}px;border-radius:2px;background:{COL if v else "transparent"};{"box-shadow:0 0 0 2px "+T1 if i==STEP and v else ""}"></span>' for i,v in enumerate(vels))
# automation lanes: (name, base, events {step:value}, locks {step:value}, range)
LANES=[('CUTOFF',64,{0:40,4:72,8:96,12:58},{6:120},(0,127)),
       ('REV',20,{2:50,10:20},{},(0,127)),
       ('PAN',0,{4:-30,8:30},{14:0},(-64,63)),
       ('ENV ATK',10,{},{4:60,5:60},(0,127))]
LH=56
def lane_svg(base,ev,lk,rng):
    lo,hi=rng; H=LH-12
    def y(v): return 6+(1-(v-lo)/(hi-lo))*H
    pts=[]; cur=base
    for i in range(N+1):
        if i in ev: cur=ev[i]
        x=colx(i)-GX
        pts.append((x,y(cur)))
        if i<N:
            nxt=ev.get(i+1,cur); pts.append((x+CW,y(cur)))
    d='M'+' L'.join(f'{a:.1f},{b:.1f}' for a,b in pts)
    dots=''.join(f'<circle cx="{colx(s)-GX+3:.1f}" cy="{y(v):.1f}" r="4" fill="{COL}" stroke="{P}" stroke-width="1.5"/>' for s,v in ev.items())
    locks=''.join(f'<rect x="{colx(s)-GX+CW/2-6:.1f}" y="{y(v)-6:.1f}" width="12" height="12" transform="rotate(45 {colx(s)-GX+CW/2:.1f} {y(v):.1f})" fill="{T1}" stroke="{COL}" stroke-width="2"/>' for s,v in lk.items())
    basey=y(base)
    return f'<svg width="{N*CW}" height="{LH}" viewBox="0 0 {N*CW} {LH}" aria-hidden="true" style="display:block"><line x1="0" y1="{basey:.1f}" x2="{N*CW}" y2="{basey:.1f}" stroke="{T2}" stroke-opacity=".35" stroke-dasharray="3 4"/><path d="{d}" fill="none" stroke="{COL}" stroke-width="2"/>{dots}{locks}</svg>'
def value_at(base,ev,lk,s):
    if s in lk: return lk[s],'lock'
    cur=base; src='sound'
    for i in range(s+1):
        if i in ev: cur=ev[i]; src='auto'
    return cur,src
lanes=''
for name,base,ev,lk,rng in LANES:
    v,src=value_at(base,ev,lk,STEP)
    lanes+=f'''<div style="display:flex;align-items:center;height:{LH}px">
<div style="width:{GX-8}px;margin-right:8px;font-size:11px;color:{T2};text-align:right;line-height:1.2">{name}</div>
<div style="position:relative;width:{N*CW}px;height:{LH-4}px;background:{WELL};border-radius:6px;overflow:hidden"><div aria-hidden="true" style="position:absolute;left:{colx(STEP)-GX}px;top:0;bottom:0;width:{CW}px;background:rgba(237,237,240,0.07);box-shadow:inset 1px 0 0 rgba(237,237,240,0.25),inset -1px 0 0 rgba(237,237,240,0.25)"></div><div style="position:absolute;inset:0">{lane_svg(base,ev,lk,rng)}</div></div></div>'''
# --- inspector rows: sound at step
insp_sound=''
for name,base,ev,lk,rng in LANES:
    v,src=value_at(base,ev,lk,STEP)
    mark={'lock':f'<span title="Lock" style="display:inline-block;width:9px;height:9px;transform:rotate(45deg);background:{T1};box-shadow:0 0 0 2px {COL}"></span>',
          'auto':f'<span style="display:inline-block;width:10px;height:3px;border-radius:2px;background:{COL}"></span>',
          'sound':f'<span style="display:inline-block;width:10px;height:0;border-top:2px dashed {T2}"></span>'}[src]
    word={'lock':'locked on this step','auto':'recorded','sound':'the sound’s own'}[src]
    insp_sound+=f'<div style="display:flex;align-items:center;gap:10px;height:32px"><span style="width:16px;display:flex;justify-content:center">{mark}</span><span style="width:76px;font-size:13px">{name}</span><span style="width:40px;font-weight:600;text-align:right">{v}</span><span style="font-size:12px;color:{T2}">{word}</span></div>'
def kb(n,lit=False):
    return ('<span aria-label="FM-1 knob '+str(n)+'" style="width:18px;height:18px;border-radius:9px;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;'
            +('background:'+COL+';color:#101012;box-shadow:0 0 0 3px rgba(34,195,180,0.35)' if lit else 'background:'+CTRL+';color:'+T1+';box-shadow:inset 0 0 0 1px #4A4A52')+'">'+str(n)+'</span>')
def kfield(n,label,val,sub='',lit=False):
    subh=('<span style="font-size:11px;color:'+T2+'">'+sub+'</span>') if sub else ''
    ring=';box-shadow:0 0 0 2px '+COL if lit else ''
    return '<div style="display:flex;flex-direction:column;gap:2px;padding:8px 10px;border-radius:8px;background:'+(LIFT if lit else WELL)+ring+'"><span style="display:flex;align-items:center;justify-content:space-between;font-size:11px;color:'+T2+'">'+label+kb(n,lit)+'</span><span style="font-weight:600;font-size:15px">'+val+'</span>'+subh+'</div>'
def wknob(label,val,frac,bip=False):
    import math
    R=20; c=2*math.pi*R; arc=c*0.75
    if bip:
        mid=arc/2; seg=abs(frac-0.5)*arc; start=mid if frac>=0.5 else mid-seg
        valarc=f'<circle cx="26" cy="26" r="{R}" fill="none" stroke="{T1}" stroke-width="4" stroke-dasharray="0 {start:.1f} {max(seg,1.5):.1f} {c:.1f}" transform="rotate(135 26 26)" stroke-linecap="round"/>'
    else:
        valarc=f'<circle cx="26" cy="26" r="{R}" fill="none" stroke="{T1}" stroke-width="4" stroke-dasharray="{arc*frac:.1f} {c:.1f}" transform="rotate(135 26 26)" stroke-linecap="round"/>'
    ang=135+270*frac
    knob=(f'<svg width="52" height="52" viewBox="0 0 52 52" aria-hidden="true"><circle cx="26" cy="26" r="{R}" fill="none" stroke="#2A2A30" stroke-width="4" stroke-dasharray="{arc:.1f} {c:.1f}" transform="rotate(135 26 26)" stroke-linecap="round"/>{valarc}'
          f'<circle cx="26" cy="26" r="13" fill="{CTRL}"/><line x1="26" y1="26" x2="{26+10*math.cos(math.radians(ang)):.1f}" y2="{26+10*math.sin(math.radians(ang)):.1f}" stroke="{T1}" stroke-width="2.5" stroke-linecap="round"/></svg>')
    return f'<div role="slider" aria-label="{label}" aria-valuenow="{val}" style="display:flex;flex-direction:column;align-items:center;gap:2px">{knob}<span style="font-size:11px;color:{T2};letter-spacing:.04em">{label}</span><span style="font-weight:600">{val}</span></div>'
def field(label,val,sub=''):
    subh=('<span style="font-size:11px;color:'+T2+'">'+sub+'</span>') if sub else ''
    return '<div style="display:flex;flex-direction:column;gap:2px;padding:8px 10px;border-radius:8px;background:'+WELL+'"><span style="font-size:11px;color:'+T2+'">'+label+'</span><span style="font-weight:600;font-size:15px">'+val+'</span>'+subh+'</div>'
inspector=f'''<section aria-label="Step 5" style="width:372px;flex-shrink:0;box-sizing:border-box;padding:16px;border-radius:12px;background:{PANEL};box-shadow:0 6px 16px rgba(0,0,0,.35);display:flex;flex-direction:column;gap:14px">
<div style="display:flex;align-items:baseline;justify-content:space-between"><div style="display:flex;flex-direction:column;gap:2px"><span style="font-size:12px;color:{T2}">T2 Bass · selected step</span><h2 style="margin:0;font-size:22px;font-weight:600;letter-spacing:-0.01em">Step 5</h2></div>
<div style="display:flex;gap:6px">{chic("‹",sm=True)}{chic("›",sm=True)}</div></div>
<div style="display:flex;gap:6px;flex-wrap:wrap">{''.join(f'<span style="height:30px;padding:0 10px;border-radius:7px;background:{COL};color:#101012;font-weight:600;display:flex;align-items:center">{n}</span>' for n in ['G4','D#4'])}<span style="height:30px;padding:0 10px;border-radius:7px;background:{CTRL};color:{T2};display:flex;align-items:center;font-size:13px">+ note</span></div>
<div style="display:flex;flex-direction:column;gap:6px"><span style="display:flex;align-items:center;gap:6px;font-size:12px;color:{T2}">The FM-1’s knobs on NOTES {kb(1)}{kb(2)}{kb(3)}{kb(4)}</span>
<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px">{kfield(1,"Pitch","G4","chord root")}{kfield(2,"Move","Step 5")}{kfield(3,"Length","2 steps","turning now",lit=True)}{kfield(4,"Velocity","100")}</div></div>
<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px">{field("Chance","75 %")}{field("Ratchet","×2")}{field("Condition","1 : 2")}{field("Nudge","+4")}</div>
<div style="height:1px;background:#2A2A30"></div>
<div style="display:flex;flex-direction:column;gap:2px"><div style="display:flex;align-items:center;justify-content:space-between"><span style="font-size:12px;color:{T2}">The sound at step 5</span><span style="font-size:12px;color:{T1};text-decoration:underline;text-underline-offset:3px">Clear this step’s locks</span></div>{insp_sound}</div>
<div style="margin-top:auto;display:flex;flex-direction:column;gap:8px;padding-top:12px;border-top:1px solid #2A2A30"><span style="font-size:12px;color:{T2}">Whole track · T2 Bass</span>
<div style="display:flex;justify-content:space-between;padding:0 8px">{wknob("SWING","16",0.13)}{wknob("LEVEL","78",0.61)}{wknob("STEPS","32",0.49)}{wknob("PAN","0",0.5,bip=True)}</div></div>
</section>'''
header=f'''<header style="height:64px;display:flex;align-items:center;gap:16px;padding:0 24px">
<span style="display:flex;align-items:center;gap:8px;font-weight:600"><span style="width:8px;height:8px;border-radius:4px;background:#30D158"></span>FM-1</span>
<nav style="display:flex;gap:4px;margin-left:160px"><span style="height:44px;padding:0 16px;border-radius:8px;background:{LIFT};box-shadow:0 0 0 2px {T1};display:flex;align-items:center;font-weight:600">Sequence</span>{''.join(f'<span style="height:44px;padding:0 16px;display:flex;align-items:center;color:{T2}">{t}</span>' for t in ['Shape','Arrange','Browse'])}</nav>
<span style="flex:1"></span><span style="color:{T2};font-variant-numeric:tabular-nums">1 · 05 &nbsp; 120 BPM</span>
<span style="width:44px;height:44px;border-radius:8px;background:{CTRL};box-shadow:0 2px 0 #0A0A0C;display:flex;align-items:center;justify-content:center"><span style="width:14px;height:14px;background:{T1};border-radius:2px"></span></span>
</header>'''
seqpanel=f'''<section aria-label="T2 Bass steps and motion" style="flex:1;min-width:0;padding:16px 16px 12px;border-radius:12px;background:{PANEL};box-shadow:0 6px 16px rgba(0,0,0,.35);display:flex;flex-direction:column;gap:10px">
<div style="display:flex;align-items:center;gap:10px"><span style="width:24px;height:24px;border-radius:6px;background:{COL};color:#101012;font-weight:600;font-size:12px;display:flex;align-items:center;justify-content:center">2</span><span style="font-weight:600">Bass</span><span style="color:{T2};font-size:12px">ANALOG</span><span style="color:{T2};font-size:12px;margin-left:8px">steps 1–16 of 32</span></div>
<div style="position:relative;height:{6*30}px;margin-top:26px">{selcol}{ruler}{grid}</div>
<div style="display:flex;align-items:flex-end;height:40px"><div style="width:{GX-8}px;margin-right:8px;font-size:11px;color:{T2};text-align:right">VEL</div><div style="position:relative;width:{N*CW}px;height:36px"><div aria-hidden="true" style="position:absolute;left:{colx(STEP)-GX}px;top:0;bottom:0;width:{CW}px;background:rgba(237,237,240,0.07);box-shadow:inset 1px 0 0 rgba(237,237,240,0.25),inset -1px 0 0 rgba(237,237,240,0.25)"></div>{vel}</div></div>
<div style="display:flex;align-items:center;gap:12px;margin-top:4px;padding-left:{GX}px">
<span style="font-weight:600">Motion</span>
<span style="display:flex;gap:2px" aria-label="9 of 64 records used">{''.join(f'<span style="width:4px;height:12px;border-radius:1px;background:{COL if i<9 else "#2A2A30"}"></span>' for i in range(32))}</span>
<span style="font-size:12px;color:{T2}">9 of 64 records · shared by all tracks</span>
<span style="flex:1"></span>
<span style="font-size:12px;color:{T2};display:flex;align-items:center;gap:6px"><span style="display:inline-block;width:10px;height:3px;background:{COL};border-radius:2px"></span>recorded, holds <span style="display:inline-block;width:8px;height:8px;transform:rotate(45deg);background:{T1};box-shadow:0 0 0 2px {COL};margin-left:8px"></span>&nbsp;lock, this step only</span>
{chic("+ Lane",sm=True)}</div>
{lanes}
</section>'''
html=f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Step inspector</title><script src="./support.js"></script></head>
<body><x-dc><helmet><style>body{{margin:0}}</style></helmet>
<div style="width:1376px;height:1032px;box-sizing:border-box;background:{P};color:{T1};font-family:-apple-system,'SF Pro Text',system-ui,sans-serif;font-size:14px;line-height:1.4;font-variant-numeric:tabular-nums;display:flex;flex-direction:column">
{header}
<div style="padding:0 24px 24px;display:flex;flex-direction:column;gap:16px;flex:1;min-height:0">{trackbox}
<div style="display:flex;gap:16px;flex:1;min-height:0">{inspector}{seqpanel}</div></div>
</div></x-dc><script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":1376,"height":1032}}}}'>
class Component extends DCLogic {{ renderVals() {{ return {{}}; }} }}
</script></body></html>'''
open('../songcanvas/project/Steps.dc.html','w').write(html)

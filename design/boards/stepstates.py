exec(open('steps.py').read().split("# --- track box")[0])
REC='#FF2C34'
def card(cap,body,note):
    return f'<div style="display:flex;flex-direction:column;gap:10px"><span style="font-size:12px;color:{T2}">{cap}</span><div style="padding:16px;border-radius:12px;background:{PANEL};box-shadow:0 6px 16px rgba(0,0,0,.35);display:flex;flex-direction:column;gap:12px;min-height:420px;box-sizing:border-box">{body}</div><p style="margin:0;font-size:12px;color:{T2}">{note}</p></div>'
def mini_lane(w,events,locks,highlight=None,ghost=None,dim=False):
    H=48; xs=lambda s: s*w/16
    pts=[]; cur=24
    for i in range(17):
        if i in events: cur=events[i]
        pts.append((xs(i),cur))
        if i<16: pts.append((xs(i+1),cur))
    d='M'+' L'.join(f'{a:.1f},{b:.1f}' for a,b in pts)
    hl=f'<rect x="{xs(highlight):.1f}" y="0" width="{w/16:.1f}" height="{H}" fill="rgba(237,237,240,0.08)"/>' if highlight is not None else ''
    lk=''.join(f'<rect x="{xs(s)+w/32-5:.1f}" y="{v-5}" width="10" height="10" transform="rotate(45 {xs(s)+w/32:.1f} {v})" fill="{T1}" stroke="{COL}" stroke-width="2"/>' for s,v in locks.items())
    dots=''.join('<circle cx="%.1f" cy="%s" r="3.5" fill="%s"/>'%(xs(s)+3,v,COL) for s,v in events.items())
    gh=f'<circle cx="{xs(ghost[0])+3:.1f}" cy="{ghost[1]}" r="6" fill="{COL}" stroke="{T1}" stroke-width="2"/><line x1="{xs(ghost[0])+3:.1f}" y1="{ghost[1]+8}" x2="{xs(ghost[0])+3:.1f}" y2="{H}" stroke="{T1}" stroke-dasharray="2 3"/>' if ghost else ''
    return f'<svg width="{w}" height="{H}" viewBox="0 0 {w} {H}" style="display:block;background:{WELL};border-radius:6px;{"opacity:.5" if dim else ""}" aria-hidden="true">{hl}<path d="{d}" fill="none" stroke="{COL}" stroke-width="2"/>{dots}{lk}{gh}</svg>'
W=280
# a) recording
knob=f'''<svg width="64" height="64" viewBox="0 0 64 64" aria-hidden="true"><circle cx="32" cy="32" r="26" fill="none" stroke="#2A2A30" stroke-width="5" stroke-dasharray="122 200" transform="rotate(135 32 32)"/><circle cx="32" cy="32" r="26" fill="none" stroke="{REC}" stroke-width="5" stroke-dasharray="80 200" transform="rotate(135 32 32)" stroke-linecap="round"/><circle cx="32" cy="32" r="17" fill="{CTRL}"/><line x1="32" y1="32" x2="32" y2="17" stroke="{T1}" stroke-width="3" stroke-linecap="round" transform="rotate(60 32 32)"/></svg>'''
a=f'''<div role="status" style="display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;background:rgba(255,44,52,0.14);box-shadow:inset 0 0 0 1px rgba(255,44,52,0.5)"><span style="width:10px;height:10px;border-radius:5px;background:{REC}"></span><span><b style="font-weight:600">Recording motion on T2.</b> Knob moves go onto the steps as they pass.</span></div>
<div style="display:flex;align-items:center;gap:16px">{knob}<div style="display:flex;flex-direction:column;gap:2px"><span style="font-weight:600">CUTOFF 88</span><span style="font-size:12px;color:{T2}">red ring: this knob is being recorded</span></div></div>
<div style="display:flex;flex-direction:column;gap:4px"><span style="font-size:11px;color:{T2}">CUTOFF</span>{mini_lane(W,{0:30,6:18,9:12},{},highlight=9)}</div>'''
# b) editing
menu=f'''<div role="menu" style="position:absolute;left:40px;top:150px;width:220px;padding:6px;border-radius:12px;background:#3E3E46;box-shadow:0 12px 28px rgba(0,0,0,.6);display:flex;flex-direction:column">
<span style="padding:6px 10px;font-size:12px;color:#C4C4CC">CUTOFF · step 11</span>
{''.join(f'<span role="menuitem" style="height:52px;padding:0 10px;border-radius:8px;display:flex;align-items:center;{"background:"+LIFT if i==0 else ""}">{t}</span>' for i,t in enumerate(["Lock step 11 only","Make it hold from here","Delete this change"]))}
<span style="height:1px;margin:4px 10px;background:#4A4A52"></span><span role="menuitem" style="height:52px;padding:0 10px;display:flex;align-items:center">Clear the CUTOFF lane</span></div>'''
b=f'''<div style="position:relative;display:flex;flex-direction:column;gap:6px">
<span style="font-size:11px;color:{T2};margin-bottom:22px">Drag a point up or down</span>
<div style="position:relative">{mini_lane(W,{0:30,4:20,10:14},{},ghost=(4,10))}<span style="position:absolute;left:{4*W/16-6:.0f}px;top:-26px;height:22px;padding:0 8px;border-radius:6px;background:{T1};color:#101012;font-weight:600;font-size:12px;display:flex;align-items:center">96</span></div>
<span style="font-size:11px;color:{T2};margin-top:8px">Hold a point for its menu</span>
{mini_lane(W,{0:30,4:20,10:14},{},highlight=10)}{menu}</div>'''
# c) song playing
c=f'''<div role="status" style="display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;background:{CTRL}"><svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><rect x="3" y="7" width="10" height="7" rx="1.5" fill="none" stroke="{T1}" stroke-width="1.5"/><path d="M5 7V5a3 3 0 0 1 6 0v2" fill="none" stroke="{T1}" stroke-width="1.5"/></svg><span style="flex:1">Skiff won’t edit motion while the song plays.</span>{chic("Stop",sm=True)}</div>
<div style="display:flex;flex-direction:column;gap:4px"><span style="font-size:11px;color:{T2}">CUTOFF</span>{mini_lane(W,{0:30,4:20,10:14},{6:8},dim=True)}</div>
<div style="display:flex;flex-direction:column;gap:4px"><span style="font-size:11px;color:{T2}">REV</span>{mini_lane(W,{2:28,9:36},{},dim=True)}</div>'''
# d) empty and full
d_=f'''<div style="display:flex;flex-direction:column;gap:6px;padding:12px;border-radius:10px;background:{WELL}"><span style="font-weight:600">No motion on T2 yet</span><span style="font-size:13px;color:#D4D4D8">Arm REC and play to record knob moves, or select a step and turn a knob to lock it there.</span></div>
<div style="display:flex;flex-direction:column;gap:6px;padding:12px;border-radius:10px;background:{WELL}"><div style="display:flex;align-items:center;gap:8px"><span style="display:flex;gap:2px" aria-label="64 of 64 records used">{''.join(f'<span style="width:3px;height:12px;border-radius:1px;background:{COL}"></span>' for i in range(32))}</span><span style="font-weight:600">Full: 64 of 64</span></div><span style="font-size:13px;color:#D4D4D8">All tracks share 64. New moves aren’t recorded until you delete some.</span><div>{chic("Show what uses them",sm=True)}</div></div>'''
html=f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Motion states</title><script src="./support.js"></script></head>
<body><x-dc><helmet><style>body{{margin:0}}</style></helmet>
<div style="width:1384px;height:600px;box-sizing:border-box;padding:24px;background:{P};color:{T1};font-family:-apple-system,'SF Pro Text',system-ui,sans-serif;font-size:14px;line-height:1.4;display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px;align-items:start">
{card("Recording: REC armed, playing, T2 selected",a,"Hard to miss: a red banner, red rings on the knobs being recorded, and the lane drawing as the steps pass.")}
{card("Editing a lane (song stopped)",b,"Tap an empty step to add a change; drag a point for its value; hold one for lock, hold, delete or clear.")}
{card("The song playing",c,"Skiff refuses motion edits while a song plays (MOTION rc 3), so the lanes go read-only and say why, with Stop beside it.")}
{card("Empty and full",d_,"The empty state names the two ways in; the full state counts the shared 64 and points at what uses them.")}
</div></x-dc><script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":1384,"height":600}}}}'>
class Component extends DCLogic {{ renderVals() {{ return {{}}; }} }}
</script></body></html>'''
open('../songcanvas/project/StepStates.dc.html','w').write(html)

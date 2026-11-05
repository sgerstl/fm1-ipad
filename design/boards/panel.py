import re
# reuse the Song page and the Shape cards
src_c=open('compose.py').read().split("board('Compose.dc.html'")[0]
exec(src_c)
SONGW=1220
ROLLW=860
src_s=open('shape.py').read()
src_s=src_s[:src_s.index("cards=[")]
exec(src_s.replace("TC='#FF5A36'","TC='#22C3B4'"))   # T2 Bass's teal
FAM=['ENV','LFO','FX','SEL','EDIT','ARP']
def rail(active=None, x=None):
    keys=''.join(f'<span style="height:48px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600;letter-spacing:.04em;'
                 +(f'background:{LIFT};box-shadow:0 0 0 2px {T1};color:{T1}' if f==active else f'background:{CTRL};box-shadow:0 2px 0 #0A0A0C;color:{T2}')+f'">{f}</span>' for f in FAM)
    return f'<nav aria-label="Sound pages" style="width:56px;flex-shrink:0;display:flex;flex-direction:column;gap:8px;padding:8px 6px;border-radius:12px;background:{PANEL}">{keys}</nav>'
def lfo_card():
    rows=f'''<div style="display:flex;flex-direction:column;gap:6px">
<div style="display:flex;align-items:center;gap:8px"><span style="font-size:11px;color:{T1};font-weight:600;width:44px">LFO</span><div style="display:flex;gap:4px;flex:1">{col('RATE','2.0','Hz',0.4,num=1)}{col('WAVE','TRI','',1,num=2)}{col('PHASE','0','°',0,num=3)}{col('FADE','12','',0.1,num=4)}</div></div>
<div style="display:flex;align-items:center;gap:8px;opacity:.85"><span style="font-size:11px;color:{T2};width:44px">LFO 2</span><div style="display:flex;gap:4px;flex:1">{col('SYNC','1/4','',0.4)}{col('TRIG','NOTE','',1)}{col('POLAR.','UNI','',1)}{col('ENV SYNC','OFF','',0)}</div></div></div>'''
    return card('LFO','LFO + LFO 2',[],lfo_graph()).replace('<div style="display:flex;gap:4px"></div>',rows)
def mod_card():
    return card('Mod matrix','MOD',[col('ROUTE','2','/11',0.18,num=1),col('SOURCE','LFO','',1,num=2),col('DEST','CUT','',1,num=3),col('AMOUNT','+46','%',0.86,num=4)],mod_graph())
def sound_panel(fam):
    picker=f'''<div style="display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;background:{WELL}">
<span style="width:24px;height:24px;border-radius:6px;background:#22C3B4;color:#101012;font-weight:600;font-size:12px;display:flex;align-items:center;justify-content:center">2</span>
<div style="display:flex;flex-direction:column"><span style="font-weight:600">Acid Bass</span><span style="font-size:12px;color:{T2}">ANALOG · BASS · factory</span></div><span style="flex:1"></span>{chic("Sounds ▾",sm=True)}</div>'''
    head=f'''<div style="display:flex;align-items:center;justify-content:space-between"><div style="display:flex;align-items:baseline;gap:10px"><h2 style="margin:0;font-size:20px;font-weight:600">{fam}</h2><span style="font-size:12px;color:{T2}">T2 Bass · 3 pages</span></div>
<div style="display:flex;gap:6px">{chic("Pin",sm=True)}{chic("✕",sm=True)}</div></div>'''
    return (f'<aside aria-label="Sound panel, {fam}" style="width:430px;flex-shrink:0;box-sizing:border-box;padding:16px;border-radius:12px;background:#1F1F24;box-shadow:0 12px 28px rgba(0,0,0,.6);display:flex;flex-direction:column;gap:12px;overflow:hidden">'
            f'{head}{picker}{lfo_card()}{mod_card()}</aside>')
def song_page(panel_open):
    inner=page(8.6,1,None,'C','07','D',True,8).replace('width=1296','')
    inner=inner
    inner=inner.replace('{"Mixer"}','')
    # tabs: Song · Mixer · Browse (no Shape)
    inner=inner.replace(">Song</span>"+''.join(f'<span style="height:40px;padding:0 16px;display:flex;align-items:center;color:{T2}">{t}</span>' for t in ['Shape','Browse']),
                        ">Song</span>"+''.join(f'<span style="height:40px;padding:0 16px;display:flex;align-items:center;color:{T2}">{t}</span>' for t in ['Mixer','Browse']))
    inner=inner.replace(chic("Mixer"),'')
    # wrap body: song+pattern column, then panel, then rail
    a='<div style="padding:0 24px 24px;display:flex;flex-direction:column;gap:10px;flex:1;min-height:0">'
    i=inner.index(a); j=inner.rindex('</div></div>')
    body=inner[i+len(a):j]
    col_html=f'<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:10px;position:relative">{body}</div>'
    over=(f'<div style="position:absolute;right:80px;top:0;bottom:0;display:flex">{sound_panel("LFO")}</div>' if panel_open else '')
    new=f'<div style="padding:0 24px 24px;display:flex;gap:12px;flex:1;min-height:0;position:relative">{col_html}{rail("LFO" if panel_open else None)}{over}</div></div>'
    return inner[:i]+new
for name,openp,title in [('PanelOpen.dc.html',True,'Sound panel, LFO'),('PanelClosed.dc.html',False,'Song with the sound rail')]:
    board(name, song_page(openp), title=title)

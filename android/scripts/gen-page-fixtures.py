#!/usr/bin/env python3
"""Writes android/fixtures/state/page-*.json: PROVISIONAL, hand-written `page` area scenarios for P4 (design/phone-sound-pages.md).
Each file replays link/top/shell/pads/editor (copied from drums.json) and then every page of the shown family, the shown
one last, so FakeLupeCore can learn the row and PickPage works. P1 replaces these with recordings of PhoneCore over FakeSkiff.
Run: python3 android/scripts/gen-page-fixtures.py"""
import json, os
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "fixtures", "state")
base = json.load(open(os.path.join(out, "drums.json")))["frames"]
base = [f for f in base if f["area"] != "shell"]

def c(label, value, raw=0, mn=0, mx=127, **kw):
    d = dict(label=label, value=str(value), raw=raw, min=mn, max=mx); d.update(kw); return d
def num(label, v, **kw): return c(label, v, v, **kw)
def lst(label, names, i, **kw): return c(label, names[i], i, 0, len(names) - 1, list=True, names=names, **kw)

ROWS = {
 "ENV": [(0,"ENV"),(1,"ENV 2")],
 "LFO": [(2,"LFO"),(3,"LFO 2"),(4,"MOD")],
 # Skiff 2.5.1 (the FM-1 P1 found): DELAY and REVERB follow FX. Their page numbers (41, 42) are MY stand-ins: the real ones come with P1's recording.
 "FX": [(5,"FX"),(41,"DELAY"),(42,"REVERB"),(6,"DRIVE"),(7,"INSERT"),(8,"INSERT 2"),(9,"SLICER"),(10,"DUCK")],
 "SEL": [(11,"SCALE"),(12,"CHORD"),(13,"FOLLOW")],
 "EDIT-ANALOG": [(14,"EDIT 1"),(15,"EDIT 2"),(28,"VOICE"),(29,"VOICE 2")],
 "EDIT-DRUM": [(14,"EDIT 1"),(15,"EDIT 2"),(18,"LANES"),(20,"LANE MIX"),(28,"VOICE"),(29,"VOICE 2")],
 "EDIT-FM6": [(14,"EDIT 1"),(15,"EDIT 2"),(16,"OPERATOR"),(17,"ALL OPS"),(28,"VOICE"),(29,"VOICE 2")],
 "ARP": [(39,"ARP"),(40,"ARP 2")],
}
def refs(key): return [dict(index=i, title=t) for i, t in ROWS[key]]
WAVES = ["SAW","SQR","TRI","SIN","PWM"]
LFOW = ["SIN","TRI","SAW","SQR","S&H"]
SCALES = ["CHR","MAJ","MIN","DOR","MIX","PEN","MPEN","HARM","PHRY","LYD","LOC","MEL","BLUES","WHOLE","DIMHW","DIMWH"]
SCALE_NOTES = {"MIN":[0,2,3,5,7,8,10],"MAJ":[0,2,4,5,7,9,11]}
DRIVE = ["SOFT","HARD","FOLD","CRUSH","FUZZ"]
NOTE = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
DIVS = ["1/4","1/8","1/8T","1/16","1/16T","1/32"]
ARPM = ["OFF","UP","DOWN","UP/DN","RAND"]

def page(key, family, index, track, name, controls, graph, lock=None, turned=-1, seq=0):
    p = dict(family=family, pages=refs(key), page=index, track=track, trackName=name, controls=controls, graph=graph, turned=turned, turnSeq=seq)
    if lock: p["lock"] = lock
    return p

def env(index, a, d, s, r, **kw):
    return page("ENV","ENV",index,5,"Piano",[num("ATTACK",a),num("DECAY",d),num("SUSTAIN",s),num("RELEASE",r)],
                dict(kind="env", values=[a,d,s,r]), **kw)

PAGES = {}
PAGES["ENV"] = [env(0,12,48,64,90), env(1,30,60,40,70)]
lockcontrols = lambda: [num("ATTACK",12),num("DECAY",30,locked=True),num("SUSTAIN",64),num("RELEASE",90)]
PAGES["ENV-lock"] = [page("ENV","ENV",0,5,"Piano",lockcontrols(),dict(kind="env",values=[12,30,64,90]),lock=dict(text="Locking to step 6",note="held on the FM-1")), env(1,30,60,40,70)]
PAGES["LFO"] = [
  page("LFO","LFO",2,5,"Piano",[c("RATE","3.4 Hz",80),lst("WAVE",LFOW,0),num("PHASE",0),num("FADE",0)],dict(kind="lfo",values=[80,0,0,0],caption="3.4 Hz")),
  page("LFO","LFO",3,5,"Piano",[lst("SYNC",["OFF"]+DIVS,0),lst("TRIG",["FREE","NOTE"],1),lst("POLARITY",["BI","UNI"],0),lst("ENV SYNC",["OFF","ON"],0)],dict(kind="lfo",values=[80,0,0,0],caption="3.4 Hz")),
]
routes = [dict(group="LFO",label=l,amount=a) for l,a in [("PITCH",8),("CUTOFF",62),("SHAPE",0),("AMP",30)]] \
       + [dict(group="ENV",label=l,amount=a) for l,a in [("PITCH",0),("CUTOFF",40),("SHAPE",0)]] \
       + [dict(group="SLOTS",label="1 ENV2",amount=44),dict(group="SLOTS",label="2 VEL",amount=22),dict(group="SLOTS",label="3 —",empty=True),dict(group="SLOTS",label="4 —",empty=True)]
PAGES["MOD"] = [page("LFO","LFO",4,5,"Piano",
    [c("ROUTE","LFO→CUT",1,0,10,ringless=True),c("SRC","LFO",0,fixed=True),c("DEST","CUTOFF",0,fixed=True),num("AMT",62)],
    dict(kind="mod",routes=routes,picked=1))]
fixed_ = lambda i: [c("ROUTE",routes[i]["group"]+"→"+routes[i]["label"][:3],i,0,10,ringless=True),c("SRC",routes[i]["group"],0,fixed=True),c("DEST",routes[i]["label"],0,fixed=True),num("AMT",routes[i]["amount"])]
PAGES["MOD"] = [page("LFO","LFO",4,5,"Piano",fixed_(1),dict(kind="mod",routes=routes,picked=1))]
PAGES["DRIVE"] = [
  page("FX","FX",5,1,"Acid",[num("DIST",72),num("CHORUS",20),num("DELAY",30),num("REVERB",40)],dict(kind="fx",values=[72,20,30,40])),
  # 2.5: knob 1 is the track's SEND, knobs 2 to 4 are the shared bus (no graph yet: TODO)
  page("FX","FX",41,1,"Acid",[num("SEND",30),c("TIME","1/8",2,0,5,list=True),num("FEEDBACK",40),num("COLOR",64)],dict(kind="none")),
  page("FX","FX",42,1,"Acid",[num("SEND",40),lst("TYPE",["ROOM","HALL","PLATE"],1),num("SIZE",70),num("DAMP",30)],dict(kind="none")),
  page("FX","FX",6,1,"Acid",[num("DIST",72),lst("TYPE",DRIVE,0),num("TONE",40),None],dict(kind="drive",values=[72,0,40],caption="SOFT",side="drive 72 · tone 40")),
]
PAGES["DRIVE"][1]["controls"][1] = lst("TYPE",["TUBE","HARD","FOLD","CRUSH","FUZZ"],0)
PAGES["DRIVE"][1]["graph"]["caption"] = "TUBE"
PAGES["EDIT1"] = [
  page("EDIT-ANALOG","EDIT",14,1,"Acid",[lst("WAVE",WAVES,0),num("DETUNE",22),num("MIX",64),num("NOISE",6)],dict(kind="analog",values=[0,22,64,6,70,30],caption="OSC · SAW · 2 voices",side="FILTER · 710 Hz")),
  page("EDIT-ANALOG","EDIT",15,1,"Acid",[num("CUTOFF",70),num("RESO",30),None,None],dict(kind="analog",values=[0,22,64,6,70,30],caption="OSC · SAW · 2 voices",side="FILTER · 710 Hz")),
  page("EDIT-ANALOG","EDIT",28,1,"Acid",[lst("VOICE",["MONO","POLY"],1),num("GLIDE",0),lst("GL MODE",["ALWAYS","LEGATO"],0),lst("PRIORITY",["LAST","LOW","HIGH"],0)],dict(kind="none")),
  page("EDIT-ANALOG","EDIT",29,1,"Acid",[lst("ALLOC",["ROBIN","FIRST"],0),num("DETUNE",8),num("SPREAD",20),None],dict(kind="none")),
]
PAGES["SCALE"] = [
  page("SEL","SEL",11,5,"Piano",[lst("ROOT",NOTE,0),lst("SCALE",SCALES,2),lst("QUANTIZE",["OFF","ON"],1),c("TRANSP","0",0,-24,24)],dict(kind="scale",root=0,notes=SCALE_NOTES["MIN"],side="C minor · ● root")),
  page("SEL","SEL",12,5,"Piano",[lst("CHORD",["OFF","MAJ","MIN","7TH"],0),lst("VOICING",["CLOSE","OPEN"],0),c("STRUM","0 ms",0),lst("DIR",["UP","DOWN"],0)],dict(kind="none")),   # 2.5: STRUM and DIR
  page("SEL","SEL",13,5,"Piano",[lst("FOLLOW",["OFF","1","2","3"],0),lst("MODE",["NOTE","CHORD"],0),num("NOTE",0),None],dict(kind="none")),
]
LANES = ["KICK","SNARE","CLAP","CL HAT","OP HAT","TOM","RIM","BELL"]
PAGES["LANES"] = [
  page("EDIT-DRUM","EDIT",18,4,"Drum Kit",[c("LANE","SNARE",1,0,7,list=True,ringless=True,names=LANES),num("LEVEL",100),c("TUNE","-3",61,0,127),num("DECAY",44)],dict(kind="tiles",tiles=[dict(label=l) for l in LANES],picked=1)),
  page("EDIT-DRUM","EDIT",20,4,"Drum Kit",[c("LANE","SNARE",1,0,7,list=True,ringless=True,names=LANES),num("LEVEL",100),c("PAN","C",64),None],dict(kind="tiles",tiles=[dict(label=l) for l in LANES],picked=1)),
]
PAGES["OPERATOR"] = [
  page("EDIT-FM6","EDIT",16,2,"Pad",[None]*4,dict(kind="card",title="OP 2 · RATIO")),
  page("EDIT-FM6","EDIT",17,2,"Pad",[None]*4,dict(kind="card",title="ALL OPS · OP 3 · LEVEL")),
]
PAGES["ARP"] = [
  page("ARP","ARP",39,5,"Piano",[lst("MODE",ARPM,1),lst("RATE",DIVS,3),c("OCTAVE","2",2,1,4),c("GATE","60%",76)],dict(kind="arp",values=[1,3,2,76,0,127,0,0],side="UP · 2 oct · 1/16 · gate 60%")),
  page("ARP","ARP",40,5,"Piano",[num("SWING",0),c("CHANCE","100%",127),lst("HOLD",["OFF","ON"],0),lst("ORDER",["UP","DOWN"],0)],dict(kind="arp",values=[1,3,2,76,0,127,0,0],side="UP · 2 oct · 1/16 · gate 60%")),
]

def scenario(name, lib, shown, note):
    pages = PAGES[lib]
    frames = [dict(f) for f in base]
    first = pages[shown]
    frames.append(dict(atMs=0, area="shell", state=dict(tab="pads", divider="split", bottom=dict(kind="page", family=first["family"], page=next(t for i,t in [(r["index"],r["title"]) for r in first["pages"]] if i == first["page"])))))
    order = [p for i, p in enumerate(pages) if i != shown] + [first]
    for p in order: frames.append(dict(atMs=0, area="page", state=p))
    json.dump(dict(provisional=True, note="PROVISIONAL (P4), Skiff 2.5.1 pages: hand-written by android/scripts/gen-page-fixtures.py to design/phone-sound-pages.md. " + note, frames=frames),
              open(os.path.join(out, name + ".json"), "w"), indent=1)

scenario("page-env","ENV",0,"ENV on a Piano track (board 55).")
scenario("page-env-lock","ENV-lock",0,"ENV with step 6 held and DECAY locked (board 61).")
scenario("page-lfo","LFO",0,"LFO.")
scenario("page-edit1","EDIT1",0,"EDIT 1 on an ANALOG track (board 59 left).")
scenario("page-drive","DRIVE",1,"FX > DRIVE (board 59 right).")
scenario("page-mod","MOD",0,"MOD, LFO → CUTOFF picked (board 60).")
scenario("page-scale","SCALE",0,"SEL > SCALE (board 61 left).")
scenario("page-lanes","LANES",0,"EDIT > LANES on a DRUM track (board 62 left).")
scenario("page-operator","OPERATOR",0,"EDIT > OPERATOR on an FM6 track, the dense card (board 62 right).")
scenario("page-arp","ARP",0,"ARP (board 63 left).")

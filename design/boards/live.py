import json, os
OUT = os.environ.get('OUT', 'canvas/project')  # the canvas's project folder (boards 35–37)

TEMPLATE = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>__TITLE__</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
a{color:#A1A1AA}a:hover{color:#EDEDF0}
</style>
</helmet>
<div style="position: relative; width: {{W}}px; height: {{TH}}px; background: #0D0D0F; color: #EDEDF0; font-family: -apple-system, 'SF Pro Text', system-ui, sans-serif; font-variant-numeric: tabular-nums; overflow: hidden;">
<div style="{{screen}}">
  <sc-for list="{{safe}}" as="s" hint-placeholder-count="2"><div aria-hidden="true" style="{{s.style}}"></div></sc-for>
  <div style="{{brand.style}}"><span style="font-size: 15px; font-weight: 600;">Demo</span></div>
  <nav aria-label="Pages" style="{{tabsBox}}">
    <sc-for list="{{tabs}}" as="t" hint-placeholder-count="4"><button aria-current="{{t.cur}}" style="{{t.style}}">{{t.label}}</button></sc-for>
  </nav>
  <div style="{{pos.style}}"><span style="{{pos.big}}">10 · 3</span><span style="font-size: 12px; color: #A1A1AA;">120 BPM</span></div>

  <div style="{{tool.style}}">
    <span style="{{tool.lab}}">Launch at</span>
    <div role="group" aria-label="Launch at" style="display: flex; padding: 3px; gap: 2px; border-radius: 12px; background: #111114;">
      <sc-for list="{{timing}}" as="t" hint-placeholder-count="4"><button aria-pressed="{{t.on}}" style="{{t.style}}">{{t.label}}</button></sc-for>
    </div>
    <span style="flex-grow: 1;"></span>
    <span style="{{tool.status}}">{{status}}</span>
    <button style="{{tool.cancel}}">Cancel waiting</button>
  </div>

  <sc-for list="{{letters}}" as="l" hint-placeholder-count="9"><span aria-hidden="true" style="{{l.style}}">{{l.t}}</span></sc-for>

  <sc-for list="{{rows}}" as="r" hint-placeholder-count="6">
    <div role="group" aria-label="{{r.aria}}">
      <div style="{{r.head}}">
        <span style="{{r.chip}}">{{r.n}}</span>
        <sc-if value="{{r.showName}}" hint-placeholder-val="{{ true }}"><span style="{{r.nameStyle}}">{{r.name}}</span></sc-if>
        <button aria-pressed="{{r.muted}}" aria-label="{{r.muteAria}}" style="{{r.mute}}">{{r.muteLabel}}</button>
      </div>
      <sc-for list="{{r.pads}}" as="p" hint-placeholder-count="9">
        <button aria-label="{{p.aria}}" style="{{p.style}}">
          <span style="{{p.numStyle}}">{{p.label}}</span>
          <span style="{{p.subStyle}}">{{p.sub}}</span>
          <sc-if value="{{p.pass}}" hint-placeholder-val="{{ false }}"><span style="{{p.passStyle}}">{{p.passLabel}}</span></sc-if>
          <sc-if value="{{p.badge}}" hint-placeholder-val="{{ false }}"><span style="{{p.badgeStyle}}">{{p.badgeLabel}}</span></sc-if>
          <sc-if value="{{p.bar}}" hint-placeholder-val="{{ false }}"><span style="{{p.trackStyle}}"><span style="{{p.fillStyle}}"></span></span></sc-if>
        </button>
      </sc-for>
    </div>
  </sc-for>

  <sc-if value="{{panHint}}" hint-placeholder-val="{{ false }}"><div aria-hidden="true" style="{{panStyle}}"><span style="font-size: 11px; font-weight: 600; color: #A1A1AA;">I ›</span></div></sc-if>

  <div role="group" aria-label="Scenes" style="{{sceneBox}}">
    <button style="{{storeStyle}}">Store</button>
    <sc-for list="{{scenes}}" as="s" hint-placeholder-count="16"><button aria-label="{{s.aria}}" style="{{s.style}}">{{s.label}}</button></sc-for>
  </div>
  <sc-if value="{{hint}}" hint-placeholder-val="{{ true }}"><p style="{{hintStyle}}">{{hint}}</p></sc-if>
</div>

<sc-for list="{{notes}}" as="c" hint-placeholder-count="6">
  <div aria-hidden="true" style="{{c.box}}"><span style="{{c.tag}}">{{c.n}}</span></div>
</sc-for>
<section aria-label="How to read this board" style="{{ann}}">
  <div style="{{annLeft}}">
    <span style="font-size: 22px; font-weight: 700;">{{title}}</span>
    <span style="font-size: 14px; line-height: 1.4; color: #3A3A42;">{{gist}}</span>
  </div>
  <ol style="{{annList}}">
    <sc-for list="{{notes}}" as="c" hint-placeholder-count="6">
      <li style="display: flex; gap: 10px; font-size: 14px; line-height: 1.4;"><span style="{{c.key}}">{{c.n}}</span><span>{{c.text}}</span></li>
    </sc-for>
  </ol>
</section>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":__W__,"height":__TH__}}'>
class Component extends DCLogic {
  renderVals() {
    var V = __VARIANT__;
    var COL = ['#FF5A36', '#22C3B4', '#FFBF00', '#9580FF', '#FF6FAE', '#A3E635'];
    var NAMES = ['Drums', 'Bass', 'Keys', 'Pad', 'Lead', 'Perc'];
    var L = V.L;
    // entries: [pattern, reps, state, extra]; state: play (extra [pass, of, progress]), wait (extra label), next, chain (spans 2), snd (a sound)
    var SONG = V.song;
    function px(o) { var s = ''; for (var k in o) s += k + ': ' + o[k] + '; '; return s; }
    function abs(x, y, w, h) { return 'position: absolute; left: ' + x + 'px; top: ' + y + 'px; width: ' + w + 'px; height: ' + h + 'px; box-sizing: border-box;'; }
    var colX = function (i) { return L.padX + i * (L.pw + L.pg); };
    var rowY = function (r) { return L.gridY + r * (L.rh + L.rg); };
    var rows = SONG.map(function (t, r) {
      var c = COL[r], muted = t.mute === 'muted', staged = t.mute === 'staged';
      var pads = [], i = 0;
      while (i < L.cols) {
        var e = t.e[i], y = rowY(r), x = colX(i);
        var base = 'border: 0; font: inherit; text-align: left; overflow: hidden; border-radius: 8px; display: flex; flex-direction: ' + (L.short ? 'row' : 'column') + '; align-items: ' + (L.short ? 'center' : 'flex-start') + '; justify-content: flex-start; gap: ' + (L.short ? 5 : 2) + 'px; padding: ' + L.pad + 'px;';
        if (!e) {
          pads.push({ label: '', sub: '', aria: NAMES[r] + ', entry ' + 'ABCDEFGHIJKLMNOP'[i] + ', empty', style: abs(x, y, L.pw, L.rh) + base + ' background: transparent; box-shadow: inset 0 0 0 1px #2A2A30;', numStyle: '', subStyle: '', pass: false, badge: false, bar: false });
          i++; continue;
        }
        var span = e[2] === 'chain' || e[4] === 'chain' ? 2 : 1;
        var w = span * L.pw + (span - 1) * L.pg;
        var rest = e[0] === 'REST', st = e[2], play = st === 'play', wait = st === 'wait', next = st === 'next' || e[4] === 'next', snd = e[3] === 'snd' || e[4] === 'snd' || e[5] === 'snd';
        var fill = play && !muted;
        var s = abs(x, y, w, L.rh) + base;
        if (fill) s += ' background: ' + c + '; box-shadow: 0 4px 12px rgba(0,0,0,0.45);';
        else if (play && muted) s += ' background: #26262B; box-shadow: inset 0 0 0 2px ' + c + ';';
        else if (rest) s += ' background: transparent; box-shadow: inset 0 0 0 1px #4A4A52;';
        else s += ' background: #26262B;';
        if (wait) s += ' outline: 2px dashed ' + c + '; outline-offset: -2px;';
        if (next) s += ' outline: 1px solid #A1A1AA; outline-offset: -1px;';
        if (V.held && V.held[r] === i) s += ' outline: 3px solid #EDEDF0; outline-offset: 2px;';
        if (snd) s += ' clip-path: polygon(0 0, calc(100% - ' + L.cut + 'px) 0, calc(100% - ' + L.cut + 'px) ' + L.cut + 'px, 100% ' + L.cut + 'px, 100% 100%, 0 100%);';
        var ink = fill ? '#101012' : rest ? '#A1A1AA' : '#EDEDF0', sub = fill ? '#101012' : '#A1A1AA';
        var letter = 'ABCDEFGHIJKLMNOP'[i] + (span > 1 ? '–' + 'ABCDEFGHIJKLMNOP'[i + 1] : '');
        var label = rest ? 'REST' : e[0];
        var subTxt = (span > 1 ? 'chain · ' : '') + '×' + e[1];
        var aria = NAMES[r] + ', entry ' + letter + ', ' + (rest ? 'rest' : 'pattern ' + e[0]) + (span > 1 ? ', a chain' : '') + ', ' + e[1] + (e[1] === 1 ? ' pass' : ' passes') + (snd ? ', has a sound' : '');
        var p = { label: label, sub: subTxt, numStyle: 'font-size: ' + (rest ? L.restSize : L.numSize) + 'px; font-weight: 600; color: ' + ink + '; line-height: 1;', subStyle: 'font-size: ' + L.subSize + 'px; color: ' + sub + ';', pass: false, badge: false, bar: false };
        if (play) {
          var pp = e[3] === 'snd' ? e[4] : e[3];
          if (pp[1] > 1) { p.pass = true; p.passLabel = pp[0] + '/' + pp[1]; p.passStyle = 'position: absolute; right: ' + L.pad + 'px; top: ' + L.pad + 'px; font-size: ' + L.subSize + 'px; font-weight: 600; color: ' + (fill ? '#101012' : '#EDEDF0') + ';'; }
          p.bar = true;
          p.trackStyle = 'position: absolute; left: ' + L.pad + 'px; right: ' + L.pad + 'px; bottom: ' + L.pad + 'px; height: 4px; border-radius: 2px; background: ' + (fill ? 'rgba(16,16,18,0.3)' : '#3A3A42') + ';';
          p.fillStyle = 'position: absolute; left: 0; top: 0; bottom: 0; width: ' + Math.round(pp[2] * 100) + '%; border-radius: 2px; background: ' + (fill ? '#101012' : c) + ';';
          aria += ', playing' + (pp[1] > 1 ? ', pass ' + pp[0] + ' of ' + pp[1] : '') + (muted ? ', muted' : '');
        }
        if (wait) { p.badge = true; p.badgeLabel = e[3]; p.badgeStyle = 'position: absolute; right: ' + L.pad + 'px; bottom: ' + L.pad + 'px; padding: 1px 6px; border-radius: 6px; background: #EDEDF0; color: #101012; font-size: 11px; font-weight: 600;'; aria += ', waiting, ' + e[3]; }
        if (next) { p.badge = true; p.badgeLabel = 'next'; p.badgeStyle = 'position: absolute; right: ' + L.pad + 'px; bottom: ' + L.pad + 'px; font-size: 11px; color: #A1A1AA;'; aria += ', next in the song'; }
        if (V.held && V.held[r] === i) { p.badge = true; p.badgeLabel = 'S3'; p.badgeStyle = 'position: absolute; right: ' + L.pad + 'px; bottom: ' + L.pad + 'px; padding: 1px 6px; border-radius: 6px; background: #EDEDF0; color: #101012; font-size: 11px; font-weight: 700;'; aria += ', scene 3 goes here'; }
        p.aria = aria; p.style = s;
        pads.push(p);
        i += span;
      }
      var y = rowY(r), sel = r === V.sel;
      var mute = abs(L.muteX - L.x0, L.short ? (L.rh - L.muteH) / 2 : L.rh - L.muteH - 12, L.muteW, L.muteH) + 'border: 0; border-radius: 8px; font: inherit; font-size: 13px; ';
      mute += muted ? 'background: #EDEDF0; color: #101012; font-weight: 600;' : staged ? 'background: #26262B; color: #EDEDF0; box-shadow: inset 0 0 0 2px #EDEDF0;' : 'background: #26262B; color: #C4C4CC;';
      return {
        n: r + 1, name: NAMES[r], showName: L.showName, pads: pads, muted: muted ? 'true' : 'false',
        aria: 'Track ' + (r + 1) + ', ' + NAMES[r] + (sel ? ', selected' : ''),
        muteAria: (muted ? 'Unmute ' : 'Mute ') + NAMES[r] + (staged ? ', mutes at bar 11' : ''),
        muteLabel: L.short ? (muted ? 'M' : staged ? 'M·' : 'M') : (muted ? 'Muted' : staged ? 'Mutes at 11' : 'Mute'),
        head: abs(L.x0, y, L.headW, L.rh) + 'border-radius: 10px; background: #1A1A1E; display: flex; align-items: ' + (L.short ? 'center' : 'flex-start') + '; gap: 8px; padding: ' + (L.short ? '0 6px' : '10px 12px') + ';',
        chip: 'width: 26px; height: 26px; border-radius: 7px; background: ' + c + '; color: #101012; font-weight: 700; font-size: 13px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;' + (sel ? ' box-shadow: 0 0 0 2px #0D0D0F, 0 0 0 4px #EDEDF0;' : ''),
        nameStyle: 'font-weight: 600; font-size: 15px; line-height: 26px;',
        mute: mute
      };
    });
    var letters = [];
    for (var k = 0; k < L.cols; k++) letters.push({ t: 'ABCDEFGHIJKLMNOP'[k], style: abs(colX(k), L.lettersY, L.pw, 16) + 'text-align: center; font-size: 12px; color: #A1A1AA;' });
    var tabs = V.tabs.map(function (t) { var on = t === 'Live'; return { label: t, cur: on ? 'page' : 'false', style: 'flex: 1; border: 0; border-radius: 10px; font: inherit; font-size: ' + L.tabSize + 'px; ' + (on ? 'background: #26262B; color: #EDEDF0; font-weight: 600;' : 'background: transparent; color: #A1A1AA;') }; });
    var timing = ['Loop', 'Bar', 'Beat', 'Now'].map(function (x) { var on = x === 'Bar'; return { label: x, on: on ? 'true' : 'false', style: 'height: ' + L.segH + 'px; padding: 0 ' + L.segPad + 'px; border: 0; border-radius: 10px; font: inherit; font-size: ' + L.tabSize + 'px; ' + (on ? 'background: #26262B; color: #EDEDF0; font-weight: 600;' : 'background: transparent; color: #A1A1AA;') }; });
    var scenes = [];
    var sw = (L.sceneW - L.storeW - 6 - 15 * L.sg) / 16;
    for (var s = 0; s < 16; s++) {
      var kept = s < 6, rec = s === 1, held = V.held && s === 2;
      scenes.push({ label: String(s + 1), aria: 'Scene ' + (s + 1) + (kept ? '' : ', empty') + (rec ? ', recalled last' : '') + (held ? ', held' : ''),
        style: abs(L.x0 + L.storeW + 6 + s * (sw + L.sg) - L.x0, 0, sw, L.sceneH) + 'border: 0; border-radius: 8px; font: inherit; font-size: 14px; ' + (held ? 'background: #3E3E46; color: #EDEDF0; font-weight: 700; box-shadow: 0 0 0 2px #EDEDF0, 0 12px 28px rgba(0,0,0,0.6);' : rec ? 'background: #EDEDF0; color: #101012; font-weight: 700;' : kept ? 'background: #26262B; color: #EDEDF0; font-weight: 600;' : 'background: transparent; color: #A1A1AA; box-shadow: inset 0 0 0 1px #2A2A30;') });
    }
    var notes = V.notes.map(function (n, i) {
      return { n: String(i + 1), text: n[4],
        box: abs(n[0], n[1], n[2], n[3]) + 'border: 2px dashed #5AC8FA; border-radius: 10px; pointer-events: none;',
        tag: 'position: absolute; left: -12px; top: -12px; width: 24px; height: 24px; border-radius: 12px; background: #5AC8FA; color: #0D0D0F; font-size: 13px; font-weight: 700; display: flex; align-items: center; justify-content: center;',
        key: 'width: 24px; height: 24px; flex-shrink: 0; border-radius: 12px; background: #101012; color: #EDEDF0; font-size: 13px; font-weight: 700; display: flex; align-items: center; justify-content: center;' };
    });
    var safe = (L.safe || []).map(function (q) { return { style: abs(q[0], 0, q[1], L.H) + 'background: repeating-linear-gradient(135deg, #141417 0 6px, #0D0D0F 6px 12px);' }; });
    return {
      W: L.W, TH: L.TH, screen: 'position: absolute; left: 0; top: 0; width: ' + L.W + 'px; height: ' + L.H + 'px;',
      safe: safe,
      brand: { style: abs(L.x0, L.topY, 140, L.topH) + 'display: flex; align-items: center;' },
      tabsBox: abs((L.W - L.tabsW) / 2, L.topY, L.tabsW, L.topH) + 'display: flex; gap: 4px; padding: 3px; border-radius: 12px; background: #111114;',
      tabs: tabs,
      pos: { style: abs(L.W - L.x0 - 130, L.topY, 130, L.topH) + 'display: flex; flex-direction: column; align-items: flex-end; justify-content: center;', big: 'font-size: ' + (L.short ? 15 : 17) + 'px; font-weight: 600;' },
      tool: { style: abs(L.x0, L.toolY, L.W - 2 * L.x0, L.toolH) + 'display: ' + (L.toolH ? 'flex' : 'none') + '; align-items: center; gap: 10px;', lab: 'font-size: 13px; color: #A1A1AA;', status: 'font-size: 13px; color: #A1A1AA;', cancel: 'height: 44px; padding: 0 16px; border: 0; border-radius: 10px; background: #26262B; color: #EDEDF0; font: inherit;' },
      timing: timing, status: V.status, letters: letters, rows: rows,
      panHint: !!L.pan, panStyle: L.pan ? abs(L.W - L.x0 - 18, L.gridY, 18, 6 * L.rh + 5 * L.rg) + 'display: flex; align-items: center; justify-content: center; background: linear-gradient(90deg, rgba(13,13,15,0), #0D0D0F);' : '',
      sceneBox: abs(L.x0, L.sceneY, L.sceneW, L.sceneH),
      storeStyle: abs(0, 0, L.storeW, L.sceneH) + 'border: 0; border-radius: 10px; background: #26262B; color: #EDEDF0; font: inherit; font-size: 14px;',
      scenes: scenes,
      hint: V.hint, hintStyle: abs(L.x0, L.hintY, L.W - 2 * L.x0, 40) + 'margin: 0; font-size: 13px; line-height: 1.4; color: #A1A1AA;',
      notes: notes, title: V.title, gist: V.gist,
      ann: abs(0, L.H, L.W, L.TH - L.H) + 'padding: 20px 24px; background: #EDEDF0; color: #101012; display: flex; flex-direction: ' + (L.short ? 'column' : 'row') + '; gap: ' + (L.short ? 12 : 32) + 'px;',
      annLeft: 'width: ' + (L.short ? 'auto' : '380px') + '; flex-shrink: 0; display: flex; flex-direction: column; gap: 8px;',
      annList: 'margin: 0; padding: 0; list-style: none; flex-grow: 1; display: grid; grid-template-columns: 1fr 1fr; gap: 10px 24px; align-content: start;'
    };
  }
}
</script>
</body>
</html>
'''

# ---- iPad layout
IP = dict(W=1376, H=1032, TH=1312, x0=16, topY=12, topH=44, tabsW=340, tabSize=15, toolY=72, toolH=48, segH=40, segPad=14,
          lettersY=132, gridY=152, headW=168, padX=192, cols=9, pw=124, pg=6, rh=116, rg=8, pad=10, cut=12,
          numSize=22, restSize=13, subSize=12, muteX=28, muteW=144, muteH=40, showName=True, short=False,
          sceneY=908, sceneW=1344, sceneH=52, storeW=168, sg=6, hintY=976)
IP['muteX'] = 28
# mute sits at the foot of the head: place by y offset in template (centred); push it low by using muteH and a tall head
PH = dict(W=852, H=393, TH=773, x0=59, topY=8, topH=40, tabsW=430, tabSize=13, toolY=0, toolH=0, segH=34, segPad=10,
          lettersY=-100, gridY=56, headW=72, padX=137, cols=8, pw=78, pg=4, rh=40, rg=4, pad=6, cut=8,
          numSize=15, restSize=11, subSize=11, muteX=97, muteW=34, muteH=34, showName=False, short=True,
          sceneY=322, sceneW=734, sceneH=34, storeW=52, sg=4, hintY=-100, safe=[[0, 59], [793, 59]], pan=True)

# T1..T6 data: [pattern, reps, state, extra...]
SONG_JAM = [
  {'e': [['01', 4], ['02', 4, 'play', [2, 4, 0.6]], ['02', 2], ['03', 4], ['04', 4, 'wait', 'bar 11']]},
  {'e': [['REST', 4], ['05', 1, 'play', [1, 1, 0.3]], ['07', 2, 'chain'], None, ['05', 4]]},
  {'e': [['08', 8, 'play', 'snd', [3, 8, 0.8]], ['09', 4, None, 'snd'], ['08', 8]]},
  {'e': [['10', 12, 'play', [5, 12, 0.4]], ['11', 8]], 'mute': 'staged'},
  {'e': [['REST', 8], ['12', 4, 'play', [1, 4, 0.5]], ['13', 4, 'wait', 'bar 11'], ['12', 4]]},
  {'e': [['14', 2], ['14', 2], ['15', 2], ['14', 2, 'play', [2, 2, 0.55]], ['14', 2], ['15', 2], ['14', 2], ['16', 6]], 'mute': 'muted'},
]
SONG_ON = [
  {'e': [['01', 4], ['02', 4, 'play', [4, 4, 0.85]], ['02', 2, 'next'], ['03', 4], ['04', 4]]},
  {'e': [['REST', 4], ['05', 1, 'play', [1, 1, 0.85]], ['07', 2, 'chain', None, 'next'], None, ['05', 4]]},
  {'e': [['08', 8, 'play', 'snd', [3, 8, 0.8]], ['09', 4, None, 'snd'], ['08', 8]]},
  {'e': [['10', 12, 'play', [5, 12, 0.4]], ['11', 8]]},
  {'e': [['REST', 8], ['12', 4, 'play', [4, 4, 0.85]], ['13', 4, 'next'], ['12', 4]]},
  {'e': [['14', 2], ['14', 2], ['15', 2], ['14', 2, 'play', [2, 2, 0.55]], ['14', 2, 'next'], ['15', 2], ['14', 2], ['16', 6]]},
]

def gx(L, i): return L['padX'] + i * (L['pw'] + L['pg'])
def gy(L, r): return L['gridY'] + r * (L['rh'] + L['rg'])

boards = []
L = IP
boards.append(('LiveGrid.dc.html', 'Lupe Live, playing', IP, dict(
  L=IP, song=SONG_JAM, sel=4, held=None, tabs=['Song', 'Live', 'Mix', 'Sounds'], status='2 waiting · bar 11',
  hint='Tap a pad: it plays at the launch point (now, when stopped). The selected track (Lead) doesn’t change; tap a row’s number to select it.',
  title='35 · Live: every track’s entries, launched without selecting',
  gist='Its own tab. One row a track, one column an entry, only as many columns as the song uses (here A–H, plus I empty). Play song is off: every track loops its entry. Launch-only: no editor, no hold menus.',
  notes=[
    [12, 8, 1352, 52, 'Live is a tab of its own between Song and Mix (Scott, 2026-11-10). Pads stays in Song for one track.'],
    [gx(L,1)-6, gy(L,0)-6, IP['pw']+12, IP['rh']+12, 'Playing: the track colour, a pass bar, the pass ("2/4") when REPS is over 1.'],
    [gx(L,4)-6, gy(L,0)-6, IP['pw']+12, IP['rh']+12, 'Waiting for the launch point: a dashed outline and when it lands. One a track: a second tap replaces it (the firmware’s rule).'],
    [gx(L,2)-6, gy(L,1)-6, 2*IP['pw']+IP['pg']+12, IP['rh']+12, 'A chain is one pad across its entries; a tap on it starts it from its first.'],
    [10, gy(L,3)-6, 180, 2*IP['rh']+IP['rg']+12+ (IP['rh']+IP['rg']), 'Row heads: number (tap to select the track; Lead is selected), name, Mute. Mute is the row’s stop: Pad mutes at bar 11, Perc is muted and keeps its place (outlined, not filled).'],
    [gx(L,8)-6, IP['gridY']-30, IP['pw']+12, 6*IP['rh']+5*IP['rg']+36, 'One empty column after the last used entry; columns past the screen pan with two fingers.'],
  ])))
boards.append(('LiveGridScene.dc.html', 'Lupe Live, a scene held', IP, dict(
  L=IP, song=SONG_ON, sel=4, held=[3, 2, 0, 1, 2, 7], tabs=['Song', 'Live', 'Mix', 'Sounds'], status='Scene 3 held: let go to keep the song',
  hint='Hold a scene: the grid outlines where each track would go. Let go and nothing happens; tap it to recall. Only scenes stored or recalled from Lupe can be shown (the FM-1 can’t say what’s in one).',
  title='36 · Live with Play song on, scene 3 held',
  gist='The song moves each track on by itself, so its next entry gets a quiet mark, unlike a launch’s dashed one. Holding a scene shows its pads on the grid itself, not in a strip.',
  notes=[
    [gx(L,2)-6, gy(L,0)-6, IP['pw']+12, IP['rh']+12, 'The song’s next: a thin grey outline and "next". It comes in by itself; a launch would replace it.'],
    [gx(L,3)-8, gy(L,0)-8, IP['pw']+16, IP['rh']+16, 'Scene 3 held: a white outline and "S3" on the pad each track goes to.'],
    [10, IP['sceneY']-6, 380, IP['sceneH']+12, 'Scenes: Store, then the 16. 2 was recalled last (white); 3 is held.'],
    [gx(L,0)-6, gy(L,2)-6, IP['pw']+12, IP['rh']+12, 'A pad with a sound has its top right corner cut, as on the FM-1.'],
  ])))
L = PH
boards.append(('LivePhone.dc.html', 'Lupe Live, phone', PH, dict(
  L=PH, song=SONG_JAM, sel=4, held=None, tabs=['Pads', 'Timeline', 'Live', 'Mix', 'Sounds'], status='', hint='',
  title='37 · Live on the phone (852 × 393)',
  gist='Five tabs. Six rows of pads 40 tall, 8 columns in view, the rest pan with two fingers. Launch at and Cancel waiting move to the top bar’s launch key, as in round 4.',
  notes=[
    [PH['x0']-4, 4, 734+8, 48, 'Five tabs: Pads · Timeline · Live · Mix · Sounds. Tight; the launch key isn’t drawn.'],
    [PH['x0']-4, PH['gridY']-4, 80, 6*40+5*4+8, 'Row heads shrink to the number and Mute (M).'],
    [PH['x0']-4, PH['sceneY']-4, 734+8, PH['sceneH']+8, 'The scenes do fit, at 34 pt: rows at 40 and scenes at 34 are under the 44 aim (over the 24 floor).'],
    [793-24, PH['gridY']-4, 28, 6*40+5*4+8, 'More columns to the right: two-finger pan.'],
  ])))

for fname, title, L, V in boards:
    html = TEMPLATE.replace('__TITLE__', title).replace('__W__', str(L['W'])).replace('__TH__', str(L['TH'])).replace('__VARIANT__', json.dumps(V))
    open(os.path.join(OUT, fname), 'w').write(html)
    print(fname, len(html))

import json, os
OUT = os.environ.get('OUT', 'canvas/project')  # the canvas's project folder (boards 35–40)

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
    <sc-if value="{{sw}}" hint-placeholder-val="{{ true }}"><div role="group" aria-label="Song view" style="display: flex; padding: 3px; gap: 2px; border-radius: 12px; background: #111114; margin-right: 8px;"><button style="{{swOff}}">Timeline</button><button aria-pressed="true" style="{{swOn}}">Pads</button></div></sc-if>
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
      <sc-if value="{{r.showHead}}" hint-placeholder-val="{{ true }}"><div style="{{r.head}}">
        <span style="{{r.chip}}">{{r.n}}</span>
        <sc-if value="{{r.showName}}" hint-placeholder-val="{{ true }}"><span style="{{r.nameStyle}}">{{r.name}}</span></sc-if>
        <button aria-pressed="{{r.muted}}" aria-label="{{r.muteAria}}" style="{{r.mute}}">{{r.muteLabel}}</button>
      </div></sc-if>
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

  <sc-if value="{{hasSel}}" hint-placeholder-val="{{ false }}"><div role="group" aria-label="{{sl.aria}}">
    <sc-for list="{{sl.tint}}" as="q" hint-placeholder-count="2"><div aria-hidden="true" style="{{q}}"></div></sc-for>
    <button aria-label="{{sl.faceAria}}" style="{{sl.face}}"><span style="font-size: 22px; font-weight: 600; color: #101012; line-height: 1;">12</span><span style="font-size: 12px; color: #101012;">×4</span><span style="{{sl.trk}}"><span style="{{sl.fill}}"></span></span></button>
    <sc-for list="{{sl.knobs}}" as="k" hint-placeholder-count="7"><div style="{{k.box}}"><span style="font-size: 11px; letter-spacing: 0.04em; color: #C4C4CC;">{{k.label}}</span><span style="font-size: 17px; font-weight: 600;">{{k.v}}</span><span style="{{k.track}}"><span style="{{k.fill}}"></span></span></div></sc-for>
  </div></sc-if>
  <sc-if value="{{panHint}}" hint-placeholder-val="{{ false }}"><div aria-hidden="true" style="{{panStyle}}"><span style="font-size: 11px; font-weight: 600; color: #A1A1AA;">I ›</span></div></sc-if>

  <div role="group" aria-label="Scenes" style="{{sceneBox}}">
    <button style="{{storeStyle}}">Store</button>
    <sc-for list="{{scenes}}" as="s" hint-placeholder-count="16"><button aria-label="{{s.aria}}" style="{{s.style}}">{{s.label}}</button></sc-for>
    <sc-if value="{{openKey}}" hint-placeholder-val="{{ false }}"><button aria-label="Open the editor" style="{{openStyle}}">Open ⌃</button></sc-if>
  </div>

  <sc-if value="{{hasPanel}}" hint-placeholder-val="{{ false }}">
    <aside aria-label="FX pages for T5 Lead" style="{{pn.box}}">
      <div style="display: flex; align-items: center; gap: 10px; height: 44px;">
        <h2 style="margin: 0; font-size: 20px; font-weight: 600;">FX</h2>
        <span style="font-size: 12px; color: #C4C4CC;">T5 Lead · 6 pages</span>
        <span style="flex-grow: 1;"></span>
        <button style="{{pn.key}}">Save sound</button>
        <button aria-label="Close the FX pages" style="{{pn.close}}"><svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8h10M9 4l4 4-4 4" stroke="#EDEDF0" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"></path></svg></button>
      </div>
      <div style="display: flex; height: 44px; margin-left: -12px;">
        <sc-for list="{{pn.chips}}" as="c" hint-placeholder-count="6"><button aria-pressed="{{c.on}}" style="{{c.style}}"><span style="{{c.line}}"></span>{{c.label}}</button></sc-for>
      </div>
      <div style="display: flex; align-items: center; gap: 10px; padding: 8px 12px; border-radius: 10px; background: #111114;">
        <span style="width: 26px; height: 26px; border-radius: 7px; background: #FF6FAE; color: #101012; font-weight: 700; font-size: 13px; display: flex; align-items: center; justify-content: center;">5</span>
        <span style="display: flex; flex-direction: column; gap: 2px; flex-grow: 1;"><span style="font-size: 15px; font-weight: 600;">[PRESET NAME]</span><span style="font-size: 12px; color: #C4C4CC;">[ENGINE]</span></span>
        <button style="{{pn.key}}">Sounds ▾</button>
      </div>
      <sc-for list="{{pn.cards}}" as="cd" hint-placeholder-count="2">
        <section aria-label="{{cd.title}} page" style="display: flex; flex-direction: column; gap: 8px;">
          <h3 style="{{cd.h}}">{{cd.title}}</h3>
          <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 6px;">
            <sc-for list="{{cd.cols}}" as="k" hint-placeholder-count="4">
              <div style="{{k.box}}">
                <span style="display: flex; align-items: center; justify-content: space-between; font-size: 11px; letter-spacing: 0.04em; color: #A1A1AA;">{{k.label}}<span style="{{k.badge}}">{{k.n}}</span></span>
                <span style="font-size: 22px; font-weight: 600;">{{k.v}}<span style="font-size: 11px; color: #A1A1AA; margin-left: 2px;">{{k.u}}</span></span>
                <span style="{{k.track}}"><span style="{{k.fill}}"></span></span>
              </div>
            </sc-for>
          </div>
        </section>
      </sc-for>
      <span style="flex-grow: 1;"></span>
      <div role="group" aria-label="The FM-1's buttons" style="display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 6px;">
        <sc-for list="{{pn.keys}}" as="b" hint-placeholder-count="12"><button aria-pressed="{{b.on}}" style="{{b.style}}">{{b.label}}</button></sc-for>
      </div>
    </aside>
  </sc-if>
  <sc-if value="{{hasEd}}" hint-placeholder-val="{{ false }}">
    <section aria-label="The pattern editor" style="{{ed.box}}">
      <div style="{{ed.tab}}"><span style="width: 18px; height: 18px; border-radius: 5px; background: #FF6FAE;"></span><span style="font-size: 13px; font-weight: 600;">Lead · B · pattern 12</span><span style="font-size: 12px; color: #A1A1AA;">{{ed.pos}}</span></div>
      <sc-for list="{{ed.cells}}" as="c" hint-placeholder-count="64"><span aria-hidden="true" style="{{c}}"></span></sc-for>
      <span style="{{ed.lab}}">The editor, as today (boards 32–34)</span>
    </section>
  </sc-if>
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
    var idx = V.only != null ? [V.only] : [0, 1, 2, 3, 4, 5];
    var rows = idx.map(function (r, k) { var t = SONG[r];
      var c = COL[r], muted = t.mute === 'muted', staged = t.mute === 'staged';
      var pads = [], i = 0;
      while (i < L.cols) {
        var e = t.e[i], y = rowY(k), x = colX(i);
        var base = 'border: 0; font: inherit; text-align: left; overflow: hidden; border-radius: 8px; display: flex; flex-direction: ' + (L.padRow ? 'row' : 'column') + '; align-items: ' + (L.padRow ? 'center' : 'flex-start') + '; justify-content: flex-start; gap: ' + (L.padRow ? 5 : 2) + 'px; padding: ' + L.pad + 'px;';
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
      var y = rowY(k), sel = r === V.sel;
      var mw = L.muteW;
      var mute = abs(L.muteX - L.x0, L.compactHead ? (L.rh - L.muteH) / 2 : L.rh - L.muteH - 12, mw, L.muteH) + 'border: 0; border-radius: 8px; font: inherit; font-size: 13px; ';
      mute += muted ? 'background: #EDEDF0; color: #101012; font-weight: 600;' : staged ? 'background: #26262B; color: #EDEDF0; box-shadow: inset 0 0 0 2px #EDEDF0;' : 'background: #26262B; color: #C4C4CC;';
      return {
        n: r + 1, name: NAMES[r], showName: L.showName, pads: pads, showHead: L.headW > 0,
        muted: muted ? 'true' : 'false',
        aria: 'Track ' + (r + 1) + ', ' + NAMES[r] + (sel ? ', selected' : ''),
        muteAria: (muted ? 'Unmute ' : 'Mute ') + NAMES[r] + (staged ? ', mutes at bar 11' : ''),
        muteLabel: L.short ? (muted ? 'M' : staged ? 'M·' : 'M') : (muted ? 'Muted' : staged ? 'Mutes at 11' : 'Mute'),
        head: abs(L.x0, y, L.headW, L.rh) + 'border-radius: 10px; background: #1A1A1E; display: flex; align-items: ' + (L.compactHead ? 'center' : 'flex-start') + '; gap: 8px; padding: ' + (L.compactHead ? '0 8px' : '10px 12px') + ';',
        chip: 'width: 26px; height: 26px; border-radius: 7px; background: ' + c + '; color: #101012; font-weight: 700; font-size: 13px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;' + (sel ? ' box-shadow: 0 0 0 2px #0D0D0F, 0 0 0 4px #EDEDF0;' : ''),
        nameStyle: 'font-weight: 600; font-size: 15px; line-height: 26px;',
        mute: mute
      };
    });
    var letters = [];
    for (var k = 0; k < L.cols; k++) letters.push({ t: 'ABCDEFGHIJKLMNOP'[k], style: abs(colX(k), L.lettersY, L.pw, 16) + 'text-align: center; font-size: 12px; color: #A1A1AA;' });
    var tabs = V.tabs.map(function (t) { var on = t === V.cur; return { label: t, cur: on ? 'page' : 'false', style: 'flex: 1; border: 0; border-radius: 10px; font: inherit; font-size: ' + L.tabSize + 'px; ' + (on ? 'background: #26262B; color: #EDEDF0; font-weight: 600;' : 'background: transparent; color: #A1A1AA;') }; });
    var timing = ['Loop', 'Bar', 'Beat', 'Now'].map(function (x) { var on = x === 'Bar'; return { label: x, on: on ? 'true' : 'false', style: 'height: ' + L.segH + 'px; padding: 0 ' + L.segPad + 'px; border: 0; border-radius: 10px; font: inherit; font-size: ' + L.tabSize + 'px; ' + (on ? 'background: #26262B; color: #EDEDF0; font-weight: 600;' : 'background: transparent; color: #A1A1AA;') }; });
    var scenes = [];
    var openW = V.openKey ? 96 : 0;
    var sw = (L.sceneW - L.storeW - 6 - 15 * L.sg - (openW ? openW + 6 : 0)) / 16;
    for (var s = 0; s < 16; s++) {
      var kept = s < 6, rec = s === 1, held = V.held && s === 2;
      scenes.push({ label: String(s + 1), aria: 'Scene ' + (s + 1) + (kept ? '' : ', empty') + (rec ? ', recalled last' : '') + (held ? ', held' : ''),
        style: abs(L.x0 + L.storeW + 6 + s * (sw + L.sg) - L.x0, 0, sw, L.sceneH) + 'border: 0; border-radius: 8px; font: inherit; font-size: 14px; ' + (held ? 'background: #3E3E46; color: #EDEDF0; font-weight: 700; box-shadow: 0 0 0 2px #EDEDF0, 0 12px 28px rgba(0,0,0,0.6);' : rec ? 'background: #EDEDF0; color: #101012; font-weight: 700;' : kept ? 'background: #26262B; color: #EDEDF0; font-weight: 600;' : 'background: transparent; color: #A1A1AA; box-shadow: inset 0 0 0 1px #2A2A30;') });
    }

    var pn = null;
    if (V.panel) {
      var P = V.panel;
      var key = 'height: 44px; padding: 0 12px; border: 0; border-radius: 8px; background: #26262B; color: #EDEDF0; font: inherit; font-size: 13px; font-weight: 600; box-shadow: 0 2px 0 #0A0A0C;';
      pn = {
        box: abs(P.x, P.y, 430, P.h) + 'padding: 16px; border-radius: 12px; background: #1A1A1E; box-shadow: 0 6px 16px rgba(0,0,0,0.35), -1px 0 0 #26262B; display: flex; flex-direction: column; gap: 12px;',
        key: key, close: 'width: 44px; height: 44px; border: 0; border-radius: 8px; background: #26262B; box-shadow: 0 2px 0 #0A0A0C; display: flex; align-items: center; justify-content: center;',
        chips: ['FX', 'DRIVE', 'INSERT', 'INSERT 2', 'SLICER', 'DUCK'].map(function (c, i) { var on = i === 0; return { label: c, on: on ? 'true' : 'false',
          style: 'position: relative; height: 44px; padding: 0 12px; border: 0; background: transparent; font: inherit; font-size: 13px; letter-spacing: 0.03em; ' + (on ? 'color: #EDEDF0; font-weight: 600; text-shadow: 0 0 6px rgba(237,237,240,0.55);' : 'color: #C4C4CC;'),
          line: on ? 'position: absolute; left: 12px; right: 12px; top: 8px; height: 3px; border-radius: 1.5px; background: #EDEDF0;' : 'display: none;' }; }),
        cards: P.cards.map(function (cd, ci) { return { title: cd[0], h: 'margin: 0; font-size: 13px; font-weight: 600; letter-spacing: 0.04em; color: ' + (ci === 0 ? '#EDEDF0' : '#A1A1AA') + ';', cols: cd[1].map(function (k, ki) {
          var hot = ci === 0 && ki === 3;
          return { label: k[0], n: k[0] ? String(ki + 1) : '', v: k[1], u: k[2], box: 'position: relative; overflow: hidden; height: 76px; box-sizing: border-box; padding: 8px 10px 0; border-radius: 6px; background: #111114; display: flex; flex-direction: column; gap: 1px;' + (k[0] ? '' : ' visibility: hidden;'),
            badge: 'width: 18px; height: 18px; border-radius: 9px; background: #26262B; color: ' + (hot ? '#EDEDF0' : '#A1A1AA') + '; font-size: 11px; font-weight: 700; display: flex; align-items: center; justify-content: center;',
            track: 'position: absolute; left: 0; right: 0; bottom: 0; height: 3px; background: #2A2A30;' + (hot ? ' box-shadow: 0 -73px 0 0 #EDEDF0;' : ''),
            fill: 'position: absolute; left: 0; top: 0; bottom: 0; width: ' + Math.round(k[3] * 100) + '%; background: #FF6FAE;' }; }) }; }),
        keys: ['FX', 'SEL', 'ENV', 'LFO', 'EDIT', 'GLO', 'HOME', 'SAVE', 'ARP', 'SEQ', 'PLAY', 'REC'].map(function (b) { var on = b === 'FX'; return { label: b, on: on ? 'true' : 'false',
          style: 'height: 44px; border: 0; border-radius: 8px; font: inherit; font-size: 12px; font-weight: 600; letter-spacing: 0.04em; ' + (on ? 'background: #EDEDF0; color: #101012;' : 'background: #26262B; color: #C4C4CC; box-shadow: 0 2px 0 #0A0A0C;') }; })
      };
    }
    var ed = null;
    if (V.editor) {
      var E = V.editor, cells = [], ex = L.x0, ew = L.W - 2 * L.x0, gx0 = ex + 16, gy0 = E.y + 56, cw = (ew - 32 - 15 * 4) / 16, nr = Math.max(3, Math.floor((E.h - 72) / 40));
      var NOTES = [[0, 2], [2, 4], [4, 1], [6, 3], [8, 2], [10, 5], [12, 1], [14, 3]];
      for (var rr = 0; rr < nr; rr++) for (var cc = 0; cc < 16; cc++) {
        var on = NOTES.some(function (n) { return n[0] === cc && n[1] % nr === rr; });
        cells.push(abs(gx0 + cc * (cw + 4), gy0 + rr * 40, cw, 36) + 'border-radius: 6px; background: ' + (on ? '#FF6FAE' : cc % 4 === 0 ? '#2A2A30' : '#222227') + ';');
      }
      ed = { box: abs(0, 0, L.W, L.H) + 'pointer-events: none;', pos: E.pos,
        tab: abs(ex, E.y, 360, 44) + 'display: flex; align-items: center; gap: 8px; padding: 0 12px; border-radius: 12px 12px 0 0; background: #2A1F27; pointer-events: auto;',
        cells: [abs(ex, E.y + 40, ew, E.h - 40) + 'border-radius: 0 12px 12px 12px; background: #2A1F27;'].concat(cells),
        lab: abs(ex + ew - 300, E.y + 12, 284, 20) + 'text-align: right; font-size: 12px; color: #C4C4CC;' };
    }
    var sl = null;
    if (V.selPad != null) {
      var sr = V.sel, sk = idx.indexOf(sr), fx = colX(V.selPad), fy = rowY(sk), B = 6, tw = 4 * 92 + 3 * 4 + 16, th = 132, tint = V.tint;
      var kb = [];
      var labs = [['TONE', '64', 0.5], ['FOLD', '22', 0.17], ['ATK', '8 ms', 0.1], ['REL', '320 ms', 0.45], ['LEVEL', '96', 0.75], ['STEPS', '16', 1], ['PAN', 'C', 0.5]];
      labs.forEach(function (q, n) {
        var row2 = n >= 4, w2 = (tw - 16 - 2 * 4) / 3;
        var x = fx + 8 + (row2 ? (n - 4) * (w2 + 4) : n * 96), y = fy + L.rh + 8 + (row2 ? 60 : 0), w = row2 ? w2 : 92;
        kb.push({ label: q[0], v: q[1], box: abs(x, y, w, 56) + 'overflow: hidden; padding: 6px 10px 0; border-radius: 6px; background: #111114; display: flex; flex-direction: column; gap: 1px;',
          track: 'position: absolute; left: 0; right: 0; bottom: 0; height: 3px; background: #2A2A30;',
          fill: 'position: absolute; left: 0; top: 0; bottom: 0; width: ' + Math.round(q[2] * 100) + '%; background: ' + COL[sr] + ';' });
      });
      sl = { aria: NAMES[sr] + ' entry B selected, its track controls under it',
        tint: [abs(fx, fy, L.pw, L.rh + 2) + 'border-radius: 12px 12px 0 0; background: ' + tint + ';',
               abs(fx, fy + L.rh, tw, th) + 'border-radius: 0 12px 12px 12px; background: ' + tint + '; box-shadow: 0 10px 24px rgba(0,0,0,0.5);'],
        faceAria: NAMES[sr] + ', entry B, pattern 12, playing, selected',
        face: abs(fx + B, fy + B, L.pw - 2 * B, L.rh - 2 * B) + 'border: 0; font: inherit; text-align: left; border-radius: 8px; background: ' + COL[sr] + '; display: flex; flex-direction: column; gap: 2px; padding: ' + (L.pad - 2) + 'px;',
        trk: 'position: absolute; left: ' + (L.pad - 2) + 'px; right: ' + (L.pad - 2) + 'px; bottom: ' + (L.pad - 2) + 'px; height: 4px; border-radius: 2px; background: rgba(16,16,18,0.3);',
        fill: 'position: absolute; left: 0; top: 0; bottom: 0; width: 50%; border-radius: 2px; background: #101012;',
        knobs: kb };
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
      hasSel: !!sl, sl: sl || {}, hasPanel: !!pn, pn: pn || {}, hasEd: !!ed, ed: ed || {},
      sw: !!V.sw, swOn: 'height: ' + L.segH + 'px; padding: 0 14px; border: 0; border-radius: 10px; background: #26262B; color: #EDEDF0; font: inherit; font-size: ' + L.tabSize + 'px; font-weight: 600;', swOff: 'height: ' + L.segH + 'px; padding: 0 14px; border: 0; border-radius: 10px; background: transparent; color: #A1A1AA; font: inherit; font-size: ' + L.tabSize + 'px;',
      openKey: !!V.openKey, openStyle: abs(L.sceneW - openW, 0, openW, L.sceneH) + 'border: 0; border-radius: 10px; background: #26262B; color: #EDEDF0; font: inherit; font-size: 14px; font-weight: 600;',
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

# ---- layouts
IP = dict(W=1376, H=1032, TH=1312, x0=16, topY=12, topH=44, tabsW=256, tabSize=15, toolY=72, toolH=48, segH=40, segPad=14,
          lettersY=132, gridY=152, headW=168, padX=192, cols=9, pw=124, pg=6, rh=116, rg=8, pad=10, cut=12,
          numSize=22, restSize=13, subSize=12, muteX=28, muteW=144, muteH=40, showName=True, short=False, padRow=False, compactHead=False,
          sceneY=908, sceneW=1344, sceneH=52, storeW=168, sg=6, hintY=976)
IPH = dict(IP, lettersY=124, gridY=144, headW=232, padX=256, pw=117, rh=42, rg=4, pad=8, cut=8, numSize=15, restSize=11,
           padRow=True, compactHead=True, muteX=16+232-8-80, muteW=80, muteH=32, sceneY=144+6*42+5*4+8, sceneH=32, storeW=232, sg=4, hintY=-100)
IPM = dict(IP, lettersY=124, gridY=144, headW=0, padX=16, cols=16, pw=78, rh=64, pg=6, pad=8, cut=8, numSize=18,
           sceneY=-300, hintY=-100)
PH = dict(W=852, H=393, TH=773, x0=59, topY=8, topH=40, tabsW=360, tabSize=13, toolY=0, toolH=0, segH=34, segPad=10,
          lettersY=-100, gridY=56, headW=72, padX=137, cols=8, pw=78, pg=4, rh=40, rg=4, pad=6, cut=8,
          numSize=15, restSize=11, subSize=11, muteX=97, muteW=34, muteH=34, showName=False, short=True, padRow=True, compactHead=True,
          sceneY=322, sceneW=734, sceneH=34, storeW=52, sg=4, hintY=-100, safe=[[0, 59], [793, 59]], pan=True)

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
# Max: the selected track (Lead) with all 16 entries' places
def gx(L, i): return L['padX'] + i * (L['pw'] + L['pg'])
def gy(L, r): return L['gridY'] + r * (L['rh'] + L['rg'])
SONG_TABS = ['Song', 'Mix', 'Sounds']
COMMON = dict(sel=4, held=None, tabs=SONG_TABS, cur='Song', sw=True, status='2 waiting · bar 11')

boards = []
L = IP
boards.append(('PadsGrid.dc.html', 'Lupe Pads grid, No grid', IP, dict(COMMON, L=IP, song=SONG_JAM, selPad=1, tint='#472535', openKey=True,
  hint='Tap a pad: it plays at the launch point (now, when stopped). On Lead’s row (selected) a tap also picks the pad for the editor; on another row it only launches. Tap a row’s number to select that track.',
  title='35 · Pads as a grid: No grid (the editor shut)',
  gist='Song › Pads, rebuilt: one row a track, one column an entry, as many columns as the song uses (A–H, plus I empty). The track strip is gone; its rows are the row heads. Play song is off: every track loops its entry.',
  notes=[
    [gx(L,1)-6, gy(L,0)-6, IP['pw']+12, IP['rh']+12, 'Playing: the track colour, a pass bar, the pass ("2/4") when REPS is over 1.'],
    [gx(L,4)-6, gy(L,0)-6, IP['pw']+12, IP['rh']+12, 'Waiting for the launch point: dashed, and when it lands. Tap it again to take it back.'],
    [gx(L,2)-6, gy(L,1)-6, 2*IP['pw']+IP['pg']+12, IP['rh']+12, 'A chain is one pad across its entries; a tap starts it from its first.'],
    [10, gy(L,3)-6, 180, 3*IP['rh']+2*IP['rg']+12, 'Row heads: number (tap to select), name, Mute (the row’s stop). Lead is selected. Perc is muted.'],
    [gx(L,1)-6, gy(L,4)-6, 4*92+3*4+16+12, IP['rh']+132+12, 'The selected pad (Lead · B) keeps its track controls hanging under it, as today (board 32): HOME’s four, LEVEL, STEPS, PAN. Here it covers Perc’s B–D; tap the pad again to roll it away. Border only at Half and Max (2026-11-10, question 9).'],
    [gx(L,8)-6, IP['gridY']-30, IP['pw']+12, 6*IP['rh']+5*IP['rg']+36, 'One empty column after the last used entry, so there’s always room to add; further columns pan with two fingers.'],
    [10, IP['sceneY']-6, 1356, IP['sceneH']+12, 'Store, the 16 scenes, and Open for the editor at the end (as board 33).'],
  ])))
boards.append(('PadsGridScene.dc.html', 'Lupe Pads grid, a scene held', IP, dict(COMMON, L=IP, song=SONG_ON, held=[3, 2, 0, 1, 2, 7], openKey=True,
  status='Scene 3 held: let go to keep the song',
  hint='Hold a scene: the grid outlines where each track would go. Let go and nothing happens; tap it to recall. Only scenes stored or recalled from Lupe can be shown (the FM-1 can’t say what’s in one).',
  title='36 · Pads grid with Play song on, scene 3 held',
  gist='The song moves each track on by itself, so its next entry gets a quiet mark, unlike a launch’s dashed one. Holding a scene shows its pads on the grid itself.',
  notes=[
    [gx(L,2)-6, gy(L,0)-6, IP['pw']+12, IP['rh']+12, 'The song’s next: a thin grey outline and "next". It comes in by itself; a launch would replace it.'],
    [gx(L,3)-8, gy(L,0)-8, IP['pw']+16, IP['rh']+16, 'Scene 3 held: a white outline and "S3" on the pad each track goes to.'],
    [10, IP['sceneY']-6, 420, IP['sceneH']+12, 'Scene 2 was recalled last (white); 3 is held.'],
    [gx(L,0)-6, gy(L,2)-6, IP['pw']+12, IP['rh']+12, 'A pad with a sound has its top right corner cut, as on the FM-1.'],
  ])))
L = IPH
boards.append(('PadsGridHalf.dc.html', 'Lupe Pads grid, Half', IPH, dict(COMMON, L=IPH, song=SONG_JAM, editor=dict(y=IPH['sceneY']+IPH['sceneH']+12, h=1032-16-(IPH['sceneY']+IPH['sceneH']+12), pos='16 steps · Half'),
  title='37 · Pads grid at Half (the default): the strip’s rows become the pads’ rows',
  gist='At Half the strip already showed six 42 pt rows. Now the pads run on to the right of each, so the 2 × 8 block goes. Scenes at 32 and the editor under them, as now.',
  notes=[
    [10, IPH['gridY']-6, IPH['headW']+12, 6*IPH['rh']+5*IPH['rg']+12, 'Row heads at the strip’s compact size (232 wide, 42 tall): number, name, Mute.'],
    [gx(L,0)-6, IPH['gridY']-6, 9*IPH['pw']+8*IPH['pg']+12, 6*IPH['rh']+5*IPH['rg']+12, 'Pads 117 × 42: number and passes on one line, the pass bar along the foot. 42 is under the 44 aim, as the strip rows are today.'],
    [10, IPH['sceneY']-6, 1356, IPH['sceneH']+12, 'Store and the scenes at 32, as Half has them now.'],
    [10, IPH['sceneY']+IPH['sceneH']+6, 1356, 1032-16-(IPH['sceneY']+IPH['sceneH']+6), 'The editor follows the selected pad (Lead · B), as now. Drawn simply here; boards 32–34 hold its real look.'],
  ])))
L = IPM
boards.append(('PadsGridMax.dc.html', 'Lupe Pads grid, Max', IPM, dict(COMMON, L=IPM, song=SONG_JAM, only=4, status='1 waiting · bar 11', editor=dict(y=IPM['gridY']+IPM['rh']+12, h=1032-16-(IPM['gridY']+IPM['rh']+12), pos='16 steps · Max'),
  title='38 · Pads grid at Max: the selected track’s row of 16, as today',
  gist='Six rows don’t fit over the largest editor, so Max keeps today’s layout: the selected track’s 16 entries in one row, the track picked in the editor’s header menu, no scenes.',
  notes=[
    [10, IPM['gridY']-30, 1356, IPM['rh']+36, 'Lead’s row only, A–P (today’s row of 16 small keys). Other tracks launch from No grid or Half, or from the FM-1.'],
    [10, IPM['gridY']+IPM['rh']+6, 1356, 400, 'The editor, with room for chords and motion (board 34).'],
  ])))
L = IP
PX, PY, PHh = 1376-16-430, 128, 908-128-12
boards.append(('PadsGridPanel.dc.html', 'Lupe Pads grid, FX panel open', IP, dict(COMMON, L=IP, song=SONG_JAM, openKey=True,
  panel=dict(x=PX, y=PY, h=PHh, cards=[
    ['FX', [['DIST', '18', '%', 0.18], ['CHORUS', '0', '%', 0.0], ['DELAY', '35', '%', 0.35], ['REVERB', '42', '%', 0.42]]],
    ['DRIVE', [['DIST', '18', '%', 0.18], ['TYPE', 'SOFT', '', 0.0], ['TONE', '0', '', 0.5], ['', '', '', 0]]],
  ]),
  hint='FX pressed on the FM-1 (or its key here): the panel comes in over the grid for the selected track. Rows A–E, the row heads, Launch at and every scene stay live.',
  title='39 · Pads grid with FX pressed: the sound panel over it',
  gist='The sound keys work mid-set (Scott, 2026-11-10). The panel is today’s, 430 pt, for the selected track (Lead). Proposed: at No grid it sits between the tool row and the scene row so neither is covered.',
  notes=[
    [PX-6, PY-6, 442, PHh+12, 'The sound panel as now: FX’s pages as words (FX lit), the track’s sound, the pages as cards, the FM-1’s 12 keys at the foot. REVERB is being turned (lit top).'],
    [10, gy(L,4)-6, 180, IP['rh']+12, 'It edits the selected track. Tap another row’s number to shape that one; the panel follows.'],
    [gx(L,0)-6, IP['gridY']-6, 5*IP['pw']+4*IP['pg']+12, 6*IP['rh']+5*IP['rg']+12, 'Columns A–E stay playable beside it; the ones under it come back when it closes, or with a two-finger pan.'],
    [10, IP['sceneY']-6, 1356, IP['sceneH']+12, 'The panel stops above the scenes and below the tool row, so all 16 scenes, Launch at and Cancel waiting stay in reach (question 11).'],
  ])))
L = PH
boards.append(('PadsPhone.dc.html', 'Lupe Pads grid, phone', PH, dict(L=PH, song=SONG_JAM, sel=4, held=None, tabs=['Pads', 'Timeline', 'Mix', 'Sounds'], cur='Pads', status='', hint='',
  title='40 · Pads grid on the phone (852 × 393)',
  gist='The phone’s Pads tab becomes the grid; still four tabs. Six rows 40 tall, 8 columns in view, the rest pan with two fingers. Launch at and Cancel waiting stay on the top bar’s launch key (round 4).',
  notes=[
    [PH['x0']-4, 4, 734+8, 48, 'Four tabs, as now: Pads · Timeline · Mix · Sounds. The launch key isn’t drawn.'],
    [PH['x0']-4, PH['gridY']-4, 80, 6*40+5*4+8, 'Row heads shrink to the number and Mute (M).'],
    [PH['x0']-4, PH['sceneY']-4, 734+8, PH['sceneH']+8, 'The scenes fit at 34 pt; rows at 40 and scenes at 34 are under the 44 aim, over the 24 floor.'],
    [793-24, PH['gridY']-4, 28, 6*40+5*4+8, 'More columns to the right: two-finger pan.'],
  ])))

for fname, title, L, V in boards:
    html = TEMPLATE.replace('__TITLE__', title).replace('__W__', str(L['W'])).replace('__TH__', str(L['TH'])).replace('__VARIANT__', json.dumps(V))
    open(os.path.join(OUT, fname), 'w').write(html)
    print(fname, len(html))

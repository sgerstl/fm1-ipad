// Shared helpers for the phone portrait boards (phone-portrait.html, boards 53–58; phone-portrait-2.html, 59 on).
const COL = ['#FF5A36', '#22C3B4', '#FFBF00', '#9580FF', '#FF6FAE', '#A3E635'];
const NAMES = ['Acid', 'Pad', 'Pulse Ld', 'Drum Kit', 'Piano', 'Perc Kit'];
const L = 'ABCDEFGHIJKLMNOP';
const W = 412, H = 915;
const SEL = 4;               // track 5, Piano
const el = (cls, x, y, w, h, style = '', html = '', attrs = '') =>
  `<div class="abs ${cls}" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;${style}" ${attrs}>${html}</div>`;
const disc = (n, x, y) => `<div class="num" style="left:${x}px;top:${y}px">${n}</div>`;
const mix = (hex, a) => `color-mix(in srgb, ${hex} ${a}%, #0D0D0F)`;

// ---------------------------------------------------------------- data
// each track's list of entries: pattern number, 'R' for a REST, null empty
const ENT = [
  ['05', '07', null, null, null],
  ['02', '03', '03', null, null],
  ['R', '11', '14', null, null],
  ['01', '04', '06', null, null],
  ['12', '12', '15', null, null],
  ['09', '10', null, null, null],
];
const PLAY = [0, 1, 1, 1, 1, 0];      // the playing entry per track
const WAIT = [null, null, 2, null, null, null];
const MUTED = [false, false, false, false, false, true];
const SELPAD = 1;                     // Piano's B, pattern 12

// pattern 12, C minor: a note per step or null; c = extra chord notes; l = length in steps; v = velocity
const STEPS = [
  { n: 'C4', l: 2, v: 100 }, null, { n: 'D#4', l: 1, v: 88 }, null,
  { n: 'G4', l: 1, v: 96 }, { n: 'C5', c: 1, l: 3, v: 100 }, null, null,
  { n: 'A#3', l: 2, v: 72 }, null, { n: 'G4', l: 1, v: 110 }, { n: 'F4', l: 1, v: 64 },
  { n: 'D#4', c: 2, l: 2, v: 92 }, null, { n: 'D4', l: 1, v: 80 }, null,
];
const LOCKS = new Set([2, 5, 10]);
const SELSTEP = 5, NOWSTEP = 9;

// the song, in bars per track (16 bars), for the Timeline boards
const SONG = [
  [['05', 4], ['05', 4], ['07', 8]],
  [['02', 8], ['03', 8]],
  [['R', 4], ['11', 4], ['11', 4], ['14', 4]],
  [['01', 4], ['04', 4], ['04', 4], ['06', 4]],
  [['R', 8], ['12', 8]],
  [['09', 8], ['10', 8]],
];
const NOWBAR = 9.5;  // bar 10, beat 3 (0-based bars)

// ---------------------------------------------------------------- chrome
function statusBar() {
  return el('', 24, 12, 60, 18, 'font-size:14px;color:var(--text2r)', '10:24')
    + el('', 200, 14, 12, 12, 'border-radius:6px;background:#000;box-shadow:0 0 0 2px #1A1A1E')
    + el('', 340, 12, 50, 18, 'font-size:13px;color:var(--text2r);text-align:right', '84%');
}
function gestureBar() { return el('', 166, 899, 80, 4, 'border-radius:2px;background:#5A5A62'); }

function topBar(o = {}) {
  let h = '';
  h += el('key', 8, 44, 80, 44, 'gap:4px;font-size:14px', 'Demo <span style="color:var(--text2)">⌄</span>');
  h += el('key', 96, 44, 96, 44, 'flex-direction:column;gap:0;line-height:1.1',
    `<span style="font-size:14px">Bar ⌄</span><span style="font-size:12px;color:var(--text2r);font-weight:400">1 waiting</span>`);
  h += el('key', 244, 44, 44, 44, '', `<span style="width:14px;height:14px;border-radius:7px;background:var(--rec)" aria-label="Record"></span>`);
  h += el('key', 296, 44, 44, 44, o.playing === false ? '' : 'background:#EDEDF0;color:#101012', '<span style="font-size:16px">▶</span>');
  h += el('', 348, 44, 56, 44, 'display:flex;flex-direction:column;align-items:flex-end;justify-content:center;line-height:1.05',
    `<span class="cond" style="font-size:22px">10·3</span><span style="font-size:12px;color:var(--text2r)">120 BPM</span>`);
  return h;
}

function tabs(y, cur) {
  const names = ['Pads', 'Timeline', 'Mix'];
  let h = el('rec', 8, y, 396, 36, 'padding:3px');
  const w = (396 - 6 - 4) / 3;
  names.forEach((t, i) => {
    const on = t === cur;
    h += el(on ? 'key' : '', 11 + i * (w + 2), y + 3, w, 30,
      on ? 'font-size:14px' : 'display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600;color:var(--text2)', t);
  });
  return h;
}

function divider(y) {
  return el('', 0, y, W, 16, 'display:flex;align-items:center;justify-content:center', '<span style="width:44px;height:5px;border-radius:3px;background:var(--lifted)"></span>',
    'role="separator" aria-label="Divider: top only, split, bottom full"');
}

// ---------------------------------------------------------------- pads
function padFace(t, i, x, y, w, h) {
  const e = ENT[t][i];
  if (!e) return el('', x, y, w, h, 'border-radius:8px;background:var(--well)');
  const playing = PLAY[t] === i, waiting = WAIT[t] === i, muted = MUTED[t];
  const sel = t === SEL && i === SELPAD;
  let st = 'border-radius:8px;display:flex;align-items:center;gap:6px;padding:0 8px;';
  let fg = 'var(--text)';
  if (playing && !muted) { st += `background:${COL[t]};`; fg = '#101012'; }
  else if (playing && muted) st += `background:var(--control);box-shadow:inset 0 0 0 2px ${COL[t]};`;
  else if (waiting) st += `background:var(--control);outline:2px dashed ${COL[t]};outline-offset:-2px;`;
  else st += 'background:var(--control);';
  if (sel) st += 'box-shadow:0 0 0 2px #EDEDF0;';
  const label = e === 'R' ? `<span style="font-size:12px;font-weight:600;color:${fg}">REST</span>` :
    `<span style="font-size:12px;font-weight:600;color:${playing && !muted ? '#101012' : 'var(--text2r)'}">${L[i]}</span><span class="cond" style="font-size:20px;color:${fg}">${e}</span>`;
  let extra = '';
  if (waiting && h >= 36) extra = `<span style="margin-left:auto;font-size:12px;color:var(--text2r)">bar 11</span>`;
  let bar = '';
  if (playing && !muted) bar = el('', x + 6, y + h - 6, (w - 12) * 0.6, 3, 'border-radius:2px;background:rgba(16,16,18,.55)');
  return el('', x, y, w, h, st, label + extra) + bar;
}

// the Pads grid in the top half: row heads (number, mute), pads panning sideways, then the scenes row
function pads(y0, h0, o = {}) {
  let h = '';
  const scenesH = 34, gap = 4;
  const rh = Math.floor((h0 - scenesH - 8 - 5 * gap) / 6);
  for (let t = 0; t < 6; t++) {
    const y = y0 + t * (rh + gap);
    h += el('', 8, y, 28, rh, `border-radius:8px;background:${COL[t]};display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600;color:#101012;${t === SEL ? 'box-shadow:0 0 0 2px #EDEDF0;' : ''}`,
      String(t + 1), `aria-label="Track ${t + 1}, ${NAMES[t]}"`);
    h += el('', 40, y, 28, rh, `border-radius:8px;background:${MUTED[t] ? '#EDEDF0' : 'var(--control)'};display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600;color:${MUTED[t] ? '#101012' : 'var(--text2)'}`,
      'M', `aria-label="Mute ${NAMES[t]}"`);
    // pads: clipped to x 72..404 so the fifth column hints at the pan
    let row = '';
    for (let i = 0; i < 5; i++) row += padFace(t, i, i * 82, 0, 78, rh);
    h += el('', 72, y, 332, rh, 'overflow:hidden', `<div style="position:relative;width:410px;height:${rh}px">${row}</div>`);
  }
  // scenes
  const ys = y0 + h0 - scenesH;
  h += el('key', 8, ys, 56, scenesH, 'font-size:13px', 'Store');
  for (let s = 0; s < 7; s++)
    h += el('', 68 + s * 38, ys, 34, scenesH, `border-radius:8px;background:${s === 2 ? 'var(--lifted)' : s < 4 ? 'var(--control)' : 'var(--well)'};display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:600;color:${s < 4 ? 'var(--text)' : 'var(--text2)'}`, String(s + 1));
  const on = o.select;
  h += el('key', 340, ys, 64, scenesH, on ? 'background:#EDEDF0;color:#101012;font-size:13px' : 'font-size:13px', 'Select', `aria-pressed="${!!on}"`);
  return h;
}

// bottom-full: only the selected track's row stays up top
function padsStrip(y0) {
  let h = el('', 8, y0, 28, 40, `border-radius:8px;background:${COL[SEL]};display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600;color:#101012;box-shadow:0 0 0 2px #EDEDF0`, '5');
  let row = '';
  for (let i = 0; i < 5; i++) row += padFace(SEL, i, i * 82, 0, 78, 40);
  h += el('', 40, y0, 364, 40, 'overflow:hidden', `<div style="position:relative;width:410px;height:40px">${row}</div>`);
  return h;
}

// ---------------------------------------------------------------- editor
function ruler(y, o = {}) {
  let h = el('', 8, y, 250, 32, 'display:flex;align-items:center;gap:6px;font-size:14px;white-space:nowrap',
    `<span style="width:10px;height:10px;border-radius:5px;background:${COL[SEL]}"></span><span style="font-weight:600">5 Piano</span><span style="color:var(--text2r)">· B · pattern 12 · C min</span>`);
  if (o.lockBanner) {
    h = el('', 8, y, 396, 32, `border-radius:8px;background:${mix(COL[SEL], 30)};display:flex;align-items:center;gap:8px;padding:0 12px;font-size:14px;font-weight:600`,
      `<span class="dia" style="position:static;background:${COL[SEL]}"></span>Locking knob turns to step 6<span style="margin-left:auto;font-weight:400;color:var(--text2r)">let go to stop</span>`);
    return h;
  }
  h += el('key', 268, y, 66, 32, o.chord ? 'background:#EDEDF0;color:#101012' : '', 'Chord', `aria-pressed="${!!o.chord}"`);
  h += el('key', 340, y, 64, 32, '', 'Step ⋯', 'aria-label="Step menu"');
  return h;
}

function stepCell(i, x, y, w, h, o = {}) {
  const s = STEPS[i];
  const sel = i === SELSTEP && !o.noSel, now = i === NOWSTEP, held = o.held === i;
  let st = 'border-radius:8px;';
  st += s ? `background:${mix(COL[SEL], 18 + Math.round((s.v / 127) * 26))};` : 'background:var(--empty);';
  if (sel || held) st += `box-shadow:0 0 0 2px #EDEDF0;`;
  if (held) st += 'transform:translateY(-2px);';
  if (now) st += `outline:2px solid ${COL[SEL]};outline-offset:-2px;`;
  let inner = `<span class="abs" style="left:8px;top:6px;font-size:12px;color:${s ? 'var(--text2r)' : 'var(--text2)'}">${i + 1}</span>`;
  if (LOCKS.has(i) && o.marks !== false) inner += `<span class="dia" style="right:9px;top:9px;background:#EDEDF0" aria-label="locked"></span>`;
  if (s) {
    inner += `<span class="abs cond" style="left:8px;top:${h / 2 - 10}px;font-size:${h > 80 ? 26 : 20}px;color:var(--text)">${s.n}${s.c ? `<span style="font-family:Barlow;font-size:12px;color:var(--text2r);margin-left:4px">+${s.c}</span>` : ''}</span>`;
    inner += `<span class="abs" style="left:8px;bottom:7px;height:3px;width:${Math.min(s.l, 4) * ((w - 16) / 4)}px;border-radius:2px;background:${COL[SEL]}"></span>`;
  }
  return el('', x, y, w, h, st, inner, `aria-label="Step ${i + 1}${s ? ', ' + s.n : ', empty'}"`);
}

function grid(y0, h0, o = {}) {
  let h = '';
  const gap = 4, cw = (396 - 3 * gap) / 4, ch = Math.floor((h0 - 3 * gap) / 4);
  for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++)
    h += stepCell(r * 4 + c, 8 + c * (cw + gap), y0 + r * (ch + gap), cw, ch, o);
  return h;
}

function stepper(x, y, label, value, o = {}) {
  let h = el('lab', x, y, 96, 14, '', label);
  h += el('cond', x, y + 16, 96, 28, `font-size:24px;color:var(--text);${o.locked ? '' : ''}`, value);
  h += el('key', x, y + 48, 46, 36, 'font-size:18px', '−', `aria-label="${label} down"`);
  h += el('key', x + 50, y + 48, 46, 36, 'font-size:18px', '+', `aria-label="${label} up"`);
  return h;
}

// the step panel, in the strip under the grid
function stepPanel(y, o = {}) {
  const tab = o.ptab || 'notes';
  let h = el('', 0, y - 4, W, 1, 'background:var(--control)');
  h += el('', 8, y, 80, 28, 'display:flex;align-items:center;gap:4px;font-size:14px;font-weight:600', 'Step 6');
  h += el('key', 70, y, 28, 28, 'font-size:14px', '‹', 'aria-label="Previous step"');
  h += el('key', 102, y, 28, 28, 'font-size:14px', '›', 'aria-label="Next step"');
  // tabs NOTES FEEL SOUND
  h += el('rec', 140, y, 186, 28, 'padding:2px');
  ['NOTES', 'FEEL', 'SOUND'].forEach((t, i) => {
    const on = t.toLowerCase() === tab;
    h += el(on ? 'key' : 'lab', 142 + i * 61, y + 2, 59, 24, on ? 'font-size:12px;font-family:\'Barlow Condensed\';letter-spacing:.04em' : 'display:flex;align-items:center;justify-content:center', t);
  });
  if (tab === 'sound') {
    const confirm = o.confirm;
    h += el('key', 332, y, 72, 28, confirm ? 'background:var(--lifted);color:var(--text3)' : 'font-size:13px', 'Clear all');
    const rows = [
      ['◆', 'CUTOFF', '84', true], ['◆', 'DECAY', '30', true], ['—', 'RESONANCE', '40', false],
    ];
    if (confirm) {
      h += el('', 8, y + 36, 396, 40, 'border-radius:8px;box-shadow:inset 0 0 0 2px var(--rec);display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600;color:var(--text)',
        'Clear both locks on step 6 (CUTOFF, DECAY)');
      h += el('key', 8, y + 82, 396, 36, 'font-size:14px', 'Cancel');
      return h;
    }
    rows.forEach((r, i) => {
      const yy = y + 34 + i * 30;
      h += el('', 8, yy, 300, 28, 'display:flex;align-items:center;gap:8px;font-size:14px',
        `${r[3] ? `<span class="dia" style="position:static;background:${COL[SEL]}"></span>` : '<span style="width:8px;color:var(--text2)">—</span>'}<span style="color:var(--text)">${r[1]}</span><span class="cond" style="font-size:18px">${r[2]}</span><span style="font-size:12px;color:var(--text2r)">${r[3] ? 'locked on this step' : 'recorded'}</span>`);
      if (r[3]) h += el('key', 360, yy, 44, 28, 'font-size:14px', '✕', `aria-label="Clear the ${r[1]} lock"`);
    });
    return h;
  }
  h += el('key', 332, y, 72, 28, o.locking ? `background:#EDEDF0;color:#101012;font-size:13px` : 'font-size:13px',
    `${o.locking ? '◆' : '◇'} Lock`, `aria-pressed="${!!o.locking}"`);
  const yy = y + 36;
  h += stepper(8, yy, 'PITCH', 'C5 D#5');
  h += stepper(108, yy, 'MOVE', '6');
  h += stepper(208, yy, 'LENGTH', '3');
  h += stepper(308, yy, 'VELOCITY', '100');
  return h;
}

// one automation lane, for bottom-full
function autoLane(y, h0) {
  let h = el('', 8, y, 140, 28, 'display:flex;align-items:center;gap:6px;font-size:14px', '<span style="font-weight:600">CUTOFF</span><span style="color:var(--text2)">⌄</span>');
  h += el('', 220, y, 184, 28, 'display:flex;align-items:center;justify-content:flex-end;font-size:12px;color:var(--text2r)', '1 of 3 lanes · ◆ = a lock');
  const gy = y + 34, gh = h0 - 34;
  h += el('', 8, gy, 396, gh, 'border-radius:8px;background:var(--well)');
  // a line through 16 steps, diamonds on locked steps
  const vals = [40, 42, 84, 60, 58, 84, 70, 66, 50, 48, 92, 80, 70, 64, 52, 44];
  const pts = vals.map((v, i) => `${8 + 12 + i * 23.4},${gy + gh - 10 - (v / 100) * (gh - 20)}`).join(' ');
  h += `<svg class="abs" style="left:0;top:0;pointer-events:none" width="${W}" height="${H}" aria-hidden="true"><polyline points="${pts}" fill="none" stroke="${COL[SEL]}" stroke-width="2.5"/></svg>`;
  vals.forEach((v, i) => { if (LOCKS.has(i)) h += `<span class="dia" style="left:${8 + 12 + i * 23.4 - 4}px;top:${gy + gh - 10 - (v / 100) * (gh - 20) - 4}px;background:#EDEDF0"></span>`; });
  return h;
}

function editor(y0, h0, o = {}) {
  let h = ruler(y0, o);
  const panelH = 122, autoH = o.auto ? 150 : 0;
  const gy = y0 + 40, gh = h0 - 40 - panelH - 12 - (autoH ? autoH + 12 : 0);
  h += grid(gy, gh, o);
  if (autoH) h += autoLane(gy + gh + 12, autoH);
  h += stepPanel(y0 + h0 - panelH, o);
  return h;
}

// ---------------------------------------------------------------- sound page
function knob(x, y, label, v, o = {}) {
  const r = 28, c = 2 * Math.PI * r, frac = v / 127, arc = c * 0.75;
  const ring = o.moving ? '#EDEDF0' : COL[SEL];
  let h = `<svg class="abs" style="left:${x + 16}px;top:${y}px" width="64" height="64" viewBox="0 0 64 64" aria-hidden="true">
    <circle cx="32" cy="32" r="${r}" fill="none" stroke="#26262B" stroke-width="6" stroke-dasharray="${arc} ${c}" transform="rotate(135 32 32)" stroke-linecap="round"/>
    <circle cx="32" cy="32" r="${r}" fill="none" stroke="${ring}" stroke-width="6" stroke-dasharray="${arc * frac} ${c}" transform="rotate(135 32 32)" stroke-linecap="round"/></svg>`;
  h += el('lab', x, y + 70, 96, 14, `text-align:center;${o.moving ? 'color:var(--text)' : ''}`, label);
  h += el('cond', x, y + 86, 96, 30, `text-align:center;font-size:${o.moving ? 30 : 24}px;color:var(--text)`, String(v));
  return h;
}

function soundPage(y0, h0, o = {}) {
  let h = '';
  const fam = ['ENV', 'LFO', 'FX', 'SEL', 'EDIT', 'ARP'];
  fam.forEach((f, i) => {
    const on = f === 'ENV';
    h += el(on ? '' : 'key', 8 + i * 67, y0, 63, 36, on ? `border-radius:8px;background:${COL[SEL]};color:#101012;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:600` : '', f, `aria-pressed="${on}"`);
  });
  const pages = ['ENV', 'ENV 2'];   // (2026-11-14) ENV DEST isn't a page on Skiff 2.x: MOD's routes
  let x = 8;
  pages.forEach((p, i) => {
    const w = p.length * 9 + 20;
    h += el('', x, y0 + 46, w, 30, `display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600;${i === 0 ? 'color:var(--text);border-bottom:2px solid #EDEDF0' : 'color:var(--text2)'}`, p);
    x += w + 8;
  });
  h += el('', 250, y0 + 46, 154, 30, 'display:flex;align-items:center;justify-content:flex-end;gap:6px;font-size:12px;color:var(--text2r)',
    `<span style="width:8px;height:8px;border-radius:4px;background:${COL[SEL]}"></span>5 Piano · 1 of 2`);
  // graph
  const gy = y0 + 88, gh = 140;
  h += el('', 8, gy, 396, gh, 'border-radius:10px;background:var(--panel)');
  h += `<svg class="abs" style="left:8px;top:${gy}px" width="396" height="${gh}" viewBox="0 0 396 ${gh}" aria-label="Envelope: attack, decay, sustain, release">
    <path d="M16 ${gh - 16} L66 18 L150 66 L300 66 L380 ${gh - 16}" fill="none" stroke="${COL[SEL]}" stroke-width="3" stroke-linejoin="round"/>
    <path d="M66 18 L150 66" fill="none" stroke="#EDEDF0" stroke-width="3"/></svg>`;
  const ky = gy + gh + 24;
  h += knob(8, ky, 'ATTACK', 12);
  h += knob(108, ky, 'DECAY', 48, { moving: true });
  h += knob(208, ky, 'SUSTAIN', 64);
  h += knob(308, ky, 'RELEASE', 90);
  h += el('', 8, ky + 132, 396, 20, 'font-size:12px;color:var(--text2r);text-align:center', 'Knob 2 turning on the FM-1: DECAY lights and its value grows');
  return h;
}

// ---------------------------------------------------------------- timeline
function timelineAcross(y0, h0, first, count) {
  let h = '';
  const headW = 36, x0 = 8 + headW + 4, bw = (404 - x0) / count;
  // ruler
  for (let b = 0; b < count; b++)
    h += el('', x0 + b * bw, y0, bw, 20, `font-size:12px;color:${first + b + 1 > 16 ? 'var(--text2)' : 'var(--text2r)'};border-left:1px solid var(--control);padding-left:4px`, String(first + b + 1));
  const ly = y0 + 24, lh = Math.floor((h0 - 24 - 5 * 4) / 6);
  for (let t = 0; t < 6; t++) {
    const y = ly + t * (lh + 4);
    h += el('', 8, y, headW, lh, `border-radius:8px;background:${COL[t]};display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600;color:#101012;${t === SEL ? 'box-shadow:0 0 0 2px #EDEDF0' : ''}`, String(t + 1));
    h += el('', x0, y, 404 - x0, lh, 'border-radius:6px;background:var(--well)');
    let at = 0;
    SONG[t].forEach(([p, bars]) => {
      const s = Math.max(at, first), e = Math.min(at + bars, first + count);
      if (e > s) {
        const bx = x0 + (s - first) * bw + 1, w = (e - s) * bw - 3;
        const rest = p === 'R';
        h += el('', bx, y + 2, w, lh - 4, rest ? `border-radius:6px;outline:1.5px dashed var(--outline);outline-offset:-2px;display:flex;align-items:center;padding:0 6px;font-size:12px;color:var(--text2r)` :
          `border-radius:6px;background:${mix(COL[t], 55)};display:flex;align-items:${lh > 60 ? 'flex-start' : 'center'};padding:${lh > 60 ? '6px' : '0 6px'};overflow:hidden`,
          rest ? 'REST' : `<span class="cond" style="font-size:18px;color:var(--text)">${p}</span>`);
      }
      at += bars;
    });
  }
  const px = x0 + (NOWBAR - first) * bw;
  h += el('', px, y0, 2, h0, 'background:#EDEDF0', '', 'aria-label="Playhead, bar 10 beat 3"');
  return h;
}

function timelineDown(y0, h0, first, count) {
  let h = '';
  const numW = 28, x0 = 8 + numW + 4, cw = (404 - x0 - 5 * 4) / 6;
  for (let t = 0; t < 6; t++)
    h += el('', x0 + t * (cw + 4), y0, cw, 28, `border-radius:8px;background:${COL[t]};display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600;color:#101012;${t === SEL ? 'box-shadow:0 0 0 2px #EDEDF0' : ''}`, String(t + 1));
  const by = y0 + 34, bh = (h0 - 34) / count;
  for (let b = 0; b < count; b++)
    h += el('', 8, by + b * bh, numW, bh, `font-size:12px;color:${first + b + 1 > 16 ? 'var(--text2)' : 'var(--text2r)'};border-top:1px solid var(--control);padding-top:2px`, String(first + b + 1));
  for (let t = 0; t < 6; t++) {
    const x = x0 + t * (cw + 4);
    h += el('', x, by, cw, h0 - 34, 'border-radius:6px;background:var(--well)');
    let at = 0;
    SONG[t].forEach(([p, bars]) => {
      const s = Math.max(at, first), e = Math.min(at + bars, first + count);
      if (e > s) {
        const yy = by + (s - first) * bh + 1, hh = (e - s) * bh - 3, rest = p === 'R';
        h += el('', x + 2, yy, cw - 4, hh, rest ? 'border-radius:6px;outline:1.5px dashed var(--outline);outline-offset:-2px;display:flex;justify-content:center;padding-top:6px;font-size:12px;color:var(--text2r)' :
          `border-radius:6px;background:${mix(COL[t], 45)};display:flex;justify-content:center;padding-top:4px;overflow:hidden`,
          rest ? 'REST' : `<span class="cond" style="font-size:18px;color:var(--text)">${p}</span>`);
      }
      at += bars;
    });
  }
  const py = by + (NOWBAR - first) * bh;
  h += el('', 8, py, 396, 2, 'background:#EDEDF0', '', 'aria-label="Playhead, bar 10 beat 3"');
  return h;
}

// ---------------------------------------------------------------- phone layouts
// split: tabs 96–132, top content 140–442, divider 446–462, bottom 466–883
// top only: content 140–863, divider 867–883
// bottom full: selected row 96–136, divider 140–156, bottom 160–883
function phone(o) {
  let h = statusBar() + topBar(o) + gestureBar();
  const mode = o.mode || 'split';
  if (mode === 'split') {
    h += tabs(96, o.tab || 'Pads');
    h += topHalf(o, 140, 302);
    h += divider(446);
    h += bottomHalf(o, 466, 417);
  } else if (mode === 'top') {
    h += tabs(96, o.tab || 'Pads');
    h += topHalf(o, 140, 723);
    h += divider(867);
  } else {
    h += padsStrip(96);
    h += divider(140);
    h += bottomHalf(o, 160, 723);
  }
  return `<div class="screen" role="img" aria-label="${o.label || 'Phone board'}">${h}${(o.discs || []).map(d => disc(...d)).join('')}</div>`;
}
function topHalf(o, y, h) {
  if ((o.tab || 'Pads') === 'Pads') return pads(y, h, o);
  if (o.tab === 'Timeline') return o.down ? timelineDown(y, h, o.first ?? 6, o.count ?? 8) : timelineAcross(y, h, o.first ?? 6, o.count ?? 8);
  return '';
}
function bottomHalf(o, y, h) {
  if (o.bottom === 'sound') return soundPage(y, h, o);
  return editor(y, h, o);
}

// ---------------------------------------------------------------- boards
const B = [];
function board(n, title, phones, notes) {
  B.push(`<section class="board"><h2>Board ${n} · ${title}</h2><div class="phones">${phones.map(p =>
    `<div>${p.cap ? `<p class="cap">${p.cap}</p>` : ''}${phone(p)}</div>`).join('')}</div><div class="ann"><ol>${notes.map(n => `<li>${n}</li>`).join('')}</ol></div></section>`);
}

// Concept "Hybrid" for Ignaroth's four forms: the preview sheets of the approved art (user,
// 2026-10-29: "Ja, so einbauen"). The art itself is production code now: tools/hell_dungeon/
// drake_hybrid.js draws the rig parts (export_rigs.js) and the drake atlases (export_monsters.js);
// this file only re-exports it and keeps the concept's checks and preview sheets, so they can be
// regenerated from the production art.
//
// Usage: node tools/hell_dungeon/concepts/hybrid.js [repo_root]
//   writes production/qa/evidence/drake-concepts/hybrid_{lineup,form4,ingame,ingame_form3,
//   ingame_zoom,ingame_zoom_form3,ingame_zoom_form12,parts4,rig1..rig4,poses34,poses12}.png and
//   prints the rig check (parts, pivots, points, hit px, edges); --quick writes only the lineup and
//   the form 4 sheet.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const DH = require('../drake_hybrid.js');
const { encodePng } = require('../monster_sheet.js');
const ER = require('../export_rigs.js');
const { renderRig, parts, compose, posed, farWingRight, fit, FORM, SEAMLESS, FLIPBOOK } = DH;
const K = '#222222';

// ---------- source-side check of the rig contract ----------
const BASE_IDS = ['body', 'neck', 'head', 'jaw', 'arm', 'leg_far', 'leg_near', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_5', 'tail_flame'];
const EXPECT = { 1: BASE_IDS, 2: BASE_IDS, 3: BASE_IDS.concat(['wing_far', 'wing_near', 'throat', 'horns']), 4: BASE_IDS.concat(['wing_far', 'wing_near', 'throat', 'horns', 'crystal_1', 'crystal_2', 'crystal_3', 'mouth_flame']) };
const POINTS = { mouth: 'jaw', throat_at: 'neck', hand: 'arm', tail_tip: 'tail_5', core: 'body' };
function checkForm(p) {
  const r = parts(p, 0), W = r.w, H = r.h, problems = [], byId = Object.fromEntries(r.parts.map(e => [e.id, e]));
  const ids = r.parts.map(e => e.id).sort(), want = EXPECT[p].slice().sort();
  if (JSON.stringify(ids) !== JSON.stringify(want)) problems.push(`parts [${ids}] != [${want}]`);
  const near = (id, at) => { let best = Infinity; const im = byId[id].img; for (let i = 0; i < W * H; i++) if (im.px[i] && im.px[i] !== K) best = Math.min(best, Math.hypot(i % W + .5 - at[0], Math.floor(i / W) + .5 - at[1])); return best; };
  for (const e of r.parts) {
    const j = r.joints[e.id];
    if (!j) { problems.push(`${e.id}: no joint`); continue; }
    const flame = FLIPBOOK.has(e.id), d = near(e.id, j);
    if (d > (flame ? 6 : 2.5)) problems.push(`${e.id}: pivot ${d.toFixed(1)} px from its part`);
    const par = ER.PARENT[e.id];
    if (par && byId[par] && !flame) { const dp = near(par, j); if (dp > 3) problems.push(`${e.id}: pivot ${dp.toFixed(1)} px from parent ${par}`); }
    for (let f = 0; f < (flame ? 4 : 1); f++) {
      const im = f ? parts(p, f).parts.find(q => q.id === e.id).img.px : e.img.px;
      let edge = null;
      for (let x = 0; x < W && !edge; x++) if (im[x]) edge = 'row 0';
      for (let y = 0; y < H && !edge; y++) if (im[y * W]) edge = 'column 0';
      for (let y = 0; y < H && !edge; y++) if (im[y * W + W - 1]) edge = `column ${W - 1}`;
      if (edge) { problems.push(`${e.id}${flame ? ' frame ' + f : ''}: touches ${edge}`); break; }
    }
  }
  for (const name in POINTS) { const at = r.joints[name]; if (!at) problems.push(`point ${name} missing`); else if (byId[POINTS[name]] && near(POINTS[name], at) > 3) problems.push(`point ${name} ${near(POINTS[name], at).toFixed(1)} px from ${POINTS[name]}`); }
  const form = ER.FORMS[p], sev = Object.keys(form.cut);
  for (const g in form.groups) for (const m of form.groups[g].parts) if (!sev.includes(m)) sev.push(m);
  const vis = Object.fromEntries(r.parts.map(e => [e.id, 0]));
  for (let i = 0; i < W * H; i++) { let owner = null, z = -Infinity; for (const e of r.parts) if (e.img.px[i] && e.z > z) { owner = e.id; z = e.z; } if (owner) vis[owner]++; }
  for (const id of sev) if ((vis[id] || 0) < 20) problems.push(`${id}: only ${vis[id]} px can be hit (20)`);
  for (const id of FLIPBOOK) if (byId[id]) { const set = new Set([0, 1, 2, 3].map(f => parts(p, f).parts.find(e => e.id === id).img.px.join())); if (set.size < 3) problems.push(`${id}: ${set.size} distinct frames`); }
  const footRow = ['leg_far', 'leg_near'].map(id => { const im = byId[id].img.px; let y1 = -1; for (let i = 0; i < W * H; i++) if (im[i]) y1 = Math.max(y1, Math.floor(i / W)); return y1; });
  if (Math.max(...footRow) !== H - 1) problems.push(`feet end on row ${Math.max(...footRow)}, frame bottom ${H - 1}`);
  return { problems, visible: sev.map(id => `${id} ${vis[id]}`).join(', '), vis };
}
/** The form as export_rigs.js's buildForm would build it (images RGBA, rig entry), for ER.preview. */
function buildRig(p) {
  const r = parts(p, 0), form = ER.FORMS[p], W = r.w, H = r.h, J = r.joints;
  const rgba = px => { const d = new Uint8Array(W * H * 4); px.forEach((c, i) => { if (c) d.set([...hex(c).slice(0, 3), 255], i * 4); }); return d; };
  const images = {}, list = [];
  for (const e of r.parts) {
    images[e.id] = FLIPBOOK.has(e.id) ? [0, 1, 2, 3].map(f => rgba(parts(p, f).parts.find(q => q.id === e.id).img.px)) : [rgba(e.img.px)];
    const entry = { id: e.id, pivot: J[e.id].map(v => Math.round(v * 10) / 10), parent: ER.PARENT[e.id], z: e.z, hp: form.hp[e.id] || 0 };
    const cut = form.cut[e.id];
    if (!cut) entry.unbreakable = true; else Object.assign(entry, cut);
    list.push(entry);
  }
  const box = (img) => { let x0 = W, y0 = H, x1 = -1, y1 = -1; for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (img[(y * W + x) * 4 + 3]) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } return { x0, y0, x1, y1 }; };
  let gy = -1, gx0 = W, gx1 = -1, sx0 = W, sx1 = -1;
  for (const l of ['leg_far', 'leg_near']) gy = Math.max(gy, box(images[l][0]).y1);
  for (const l of ['leg_far', 'leg_near']) for (let x = 0; x < W; x++) if (images[l][0][(gy * W + x) * 4 + 3]) { gx0 = Math.min(gx0, x); gx1 = Math.max(gx1, x); }
  for (const pt of ['body', 'leg_far', 'leg_near']) { const b = box(images[pt][0]); sx0 = Math.min(sx0, b.x0); sx1 = Math.max(sx1, b.x1); }
  const r1 = v => Math.round(v * 10) / 10;
  const rig = {
    family: 'drake', variant: String(p), size: [W, H], scale: 2.5, ground: [r1((gx0 + gx1 + 1) / 2), gy], width: Math.round((sx1 - sx0 + 1) * .85),
    material: form.material, parts: list, groups: form.groups,
    points: { mouth: { part: 'jaw', at: J.mouth.map(r1) }, throat: { part: 'neck', at: J.throat_at.map(r1) }, hand: { part: 'arm', at: J.hand.map(r1) }, tail_tip: { part: 'tail_5', at: J.tail_tip.map(r1) }, core: { part: 'body', at: J.core.map(r1) } },
  };
  return { id: 'drache' + p, def: { name: 'Ignaroth · ' + FORM[p].name.toUpperCase() + ' (HYBRID)' }, rig, images, W, H };
}

// ---------- images ----------
const hex = c => [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16), 255];
function Canvas(w, h, bg) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); for (let i = 0; i < w * h; i++) this.d.set(bg, i * 4); }
Canvas.prototype.px = function (x, y, c) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d.set(c, (y * this.w + x) * 4); };
Canvas.prototype.rect = function (x, y, w, h, c) { for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, c); };
Canvas.prototype.shade = function (x, y, k) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4; for (let j = 0; j < 3; j++) this.d[i + j] = Math.round(this.d[i + j] * k); };
Canvas.prototype.tint = function (x, y, c, a) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4; for (let j = 0; j < 3; j++) this.d[i + j] = Math.round(this.d[i + j] * (1 - a) + c[j] * a); };
/** Colour-string pixels (w x h) at x, y, k output px per source px (any real k, nearest), optionally mirrored. */
Canvas.prototype.sprite = function (px, w, h, x, y, k, flip) {
  const W = Math.round(w * k), H = Math.round(h * k);
  for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
    const sx = Math.min(w - 1, Math.floor(xx / k)), sy = Math.min(h - 1, Math.floor(yy / k)), c = px[sy * w + (flip ? w - 1 - sx : sx)];
    if (c) this.px(x + xx, y + yy, hex(c));
  }
};
Canvas.prototype.rgba = function (img, x, y, k, flip) {
  const W = Math.round(img.w * k), H = Math.round(img.h * k);
  for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
    const sx = Math.min(img.w - 1, Math.floor(xx / k)), sy = Math.min(img.h - 1, Math.floor(yy / k)), i = (sy * img.w + (flip ? img.w - 1 - sx : sx)) * 4;
    if (img.rgba[i + 3] > 0) this.px(x + xx, y + yy, img.rgba.subarray(i, i + 4));
  }
};
// A soft ground shadow: two rings around a dark core, in blocks of k px.
Canvas.prototype.shadow = function (cx, cy, rx, ry, k) {
  for (let y = Math.floor(-ry); y <= Math.ceil(ry); y++) for (let x = Math.floor(-rx); x <= Math.ceil(rx); x++) {
    const d = (x / rx) ** 2 + (y / ry) ** 2;
    if (d > 1) continue;
    const ring = d < .5 ? .42 : d < .8 ? .58 : .74;
    for (let yy = 0; yy < k; yy++) for (let xx = 0; xx < k; xx++) this.shade(Math.round(cx + x * k + xx), Math.round(cy + y * k + yy), ring);
  }
};
// A warm (or violet) glow on the floor under the dragon: the core's light, in blocks of k px.
Canvas.prototype.floorGlow = function (cx, cy, rx, ry, k, col) {
  for (let y = Math.floor(-ry); y <= Math.ceil(ry); y++) for (let x = Math.floor(-rx); x <= Math.ceil(rx); x++) {
    const d = (x / rx) ** 2 + (y / ry) ** 2;
    if (d > 1) continue;
    const a = d < .35 ? .26 : d < .7 ? .17 : .09;
    for (let yy = 0; yy < k; yy++) for (let xx = 0; xx < k; xx++) this.tint(Math.round(cx + x * k + xx), Math.round(cy + y * k + yy), col, a);
  }
};
// The same in screen px for a non-integer zoom: two solid tones, no block rounding (no dither).
Canvas.prototype.shadowPx = function (cx, cy, rx, ry) {
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
    const d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2;
    if (d <= 1) this.shade(x, y, d < .5 ? .5 : .68);
  }
};
Canvas.prototype.glowPx = function (cx, cy, rx, ry, col) {
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
    const d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2;
    if (d <= 1) this.tint(x, y, col, d < .45 ? .22 : .12);
  }
};
const FONT = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111', F: '111100110100100',
  G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010', K: '101101110101101', L: '100100100100111',
  M: '101111111101101', N: '110101101101101', O: '010101101101010', P: '110101110100100', Q: '010101101110011', R: '110101110101101',
  S: '011100010001110', T: '111010010010010', U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101',
  Y: '101101010010010', Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111', 9: '111101111001110',
  ' ': '000000000000000', '.': '000000000000010', ':': '000010000010000', '-': '000000111000000', '/': '001001010100100', '(': '001010010010001', ')': '100010010010100', '=': '000111000111000', ',': '000000000010100', x: '000101010101000', '_': '000000000000111', '+': '000010111010000',
};
Canvas.prototype.text = function (x, y, str, c, k) {
  k = k || 2;
  for (const ch of String(str)) { const g = FONT[ch] || FONT[ch.toUpperCase()] || FONT[' ']; for (let i = 0; i < 15; i++) if (g[i] === '1') this.rect(x + (i % 3) * k, y + Math.floor(i / 3) * k, k, k, c); x += 4 * k; }
};
const textW = (str, k) => String(str).length * 4 * k;

function decodePng(buf) {
  let pos = 8, w = 0, h = 0, type = 0, pal = null, trns = null;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), kind = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); type = data[9]; if (data[8] !== 8) throw new Error('bit depth'); }
    else if (kind === 'PLTE') pal = data; else if (kind === 'tRNS') trns = data; else if (kind === 'IDAT') idat.push(data); else if (kind === 'IEND') break;
    pos += 12 + len;
  }
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[type], stride = w * ch, raw = zlib.inflateSync(Buffer.concat(idat)), px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[y * stride + x - ch] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = x >= ch && y ? px[(y - 1) * stride + x - ch] : 0;
      let val = line[x];
      if (f === 1) val += a; else if (f === 2) val += b; else if (f === 3) val += (a + b) >> 1;
      else if (f === 4) { const q = a + b - c, pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c); val += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      px[y * stride + x] = val & 255;
    }
  }
  const rgba = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    const s = i * ch;
    if (type === 6) rgba.set(px.subarray(s, s + 4), i * 4);
    else if (type === 2) rgba.set([px[s], px[s + 1], px[s + 2], 255], i * 4);
    else if (type === 0) rgba.set([px[s], px[s], px[s], 255], i * 4);
    else if (type === 4) rgba.set([px[s], px[s], px[s], px[s + 1]], i * 4);
    else { const k = px[s]; rgba.set([pal[k * 3], pal[k * 3 + 1], pal[k * 3 + 2], trns && k < trns.length ? trns[k] : 255], i * 4); }
  }
  return { w, h, rgba };
}

// ---------- the preview sheets ----------
const BG = [36, 24, 28, 255], BG2 = [48, 32, 36, 255], TXT = [236, 226, 214, 255], DIM = [160, 140, 140, 255], ACC = [238, 142, 46, 255];
const HERO_H = 28 * 3;
const GLOWCOL = { 1: [238, 142, 46], 2: [238, 142, 46], 3: [238, 142, 46], 4: [194, 120, 208] };
function footing(p) {
  const r = parts(p, 0), W = r.w, H = r.h;
  let x0 = W, x1 = -1;
  for (const id of ['body', 'leg_near', 'leg_far']) { const im = r.parts.find(e => e.id === id).img.px; for (let i = 0; i < W * H; i++) if (im[i] && im[i] !== K) { x0 = Math.min(x0, i % W); x1 = Math.max(x1, i % W); } }
  return { cx: (x0 + x1 + 1) / 2, half: (x1 - x0 + 1) / 2 };
}
function heightPx(p) { const c = compose(p, 0); let y0 = c.h; for (let i = 0; i < c.px.length; i++) if (c.px[i]) { y0 = Math.floor(i / c.w); break; } return c.h - y0; }

function lineup(knight, file) {
  const K2 = 2, gap = 34, top = 34, label = 48;
  const forms = [1, 2, 3, 4], ws = forms.map(p => FORM[p].W * K2 + 40);
  const maxH = Math.max(...forms.map(p => FORM[p].H)) * K2;
  const W = ws.reduce((a, b) => a + b, 0) + gap * (forms.length + 1), H = top + maxH + label + 40;
  const c = new Canvas(W, H, BG);
  const base = top + maxH;
  c.rect(0, base - 2, W, H - base + 2, BG2);
  c.text(gap, 10, 'IGNAROTH  KONZEPT HYBRID (MONUMENTAL + KNOCHEN-INFERNO)  -  ALLE FORMEN IM SPIEL-MASSSTAB (1 QUELLPIXEL = 5 WELT-PX, HIER X0.4)', TXT, 2);
  let x = gap;
  forms.forEach((p, i) => {
    const F = FORM[p], img = compose(p, 1), ft = footing(p), kx = x, dx = x + 40;
    c.shadow(dx + ft.cx * K2, base - 1, ft.half * 1.05, 3.2, K2);
    c.sprite(img.px, img.w, img.h, dx, base - F.H * K2, K2);
    c.shadow(kx + 10, base - 1, 6, 1.6, 1);
    c.rgba(knight, kx, base - Math.round(knight.h * 1.2), 1.2);
    const hp = heightPx(p) * 5 / HERO_H;
    c.text(x, base + 10, `${p}  ${F.name.toUpperCase()}`, TXT, 2);
    c.text(x, base + 26, `${F.W}x${F.H} PX = ${hp.toFixed(1)}x HELD`, DIM, 2);
    x += ws[i] + gap;
  });
  fs.writeFileSync(file, encodePng(W, H, c.d));
}

function bigSheet(knight, file) {
  const k = 5, pad = 30, top = 40, f4 = FORM[4], f3 = FORM[3], kw = 48, kgap = 30;
  const W = pad * 3 + f4.W * k + f3.W * k + 2 * (kgap + kw), H = top + f4.H * k + 70;
  const c = new Canvas(W, H, BG), base = top + f4.H * k;
  c.rect(0, base, W, H - base, BG2);
  c.text(pad, 12, 'HYBRID  -  FORM 4 OBSIDIANFORM UND FORM 3 GLUTDRACHE  -  1 QUELLPIXEL = 5 PX (WELT-MASSSTAB), RITTER X3', TXT, 2);
  const draw = (p, x) => {
    const F = FORM[p], img = compose(p, 1), ft = footing(p);
    c.floorGlow(x + ft.cx * k, base - 2, ft.half * .9, 3, k, GLOWCOL[p]);
    c.shadow(x + ft.cx * k, base - 2, ft.half * 1.1, 3.4, k);
    c.sprite(img.px, img.w, img.h, x, base - F.H * k, k);
    const kx = x + F.W * k + kgap;
    c.shadow(kx + 24, base - 2, 8, 2.4, 3);
    c.rgba(knight, kx, base - knight.h * 3, 3);
    c.text(x, base + 14, `${p}  ${F.name.toUpperCase()}  ${F.W}x${F.H}`, TXT, 3);
    return kx + kw;
  };
  const x3 = draw(4, pad);
  draw(3, x3 + pad);
  fs.writeFileSync(file, encodePng(W, H, c.d));
}

// The in-game mock in world px: the floor of the real room screenshot (a clean 4 x 3 tile block,
// enlarged 2x: the screenshots run at about half world scale), the dragon at 5 world px per source
// px facing the knight (x3) on the left, the game's red vignette.
function ingame(knight, shot, file, p) {
  const W = 1280, H = 720, c = new Canvas(W, H, [0, 0, 0, 255]);
  const cx0 = 470, cy0 = 412, cw = 272, chh = 204;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const sx = cx0 + Math.floor(x / 2) % cw, sy = cy0 + Math.floor(y / 2) % chh, i = (sy * shot.w + sx) * 4;
    c.px(x, y, [shot.rgba[i], shot.rgba[i + 1], shot.rgba[i + 2], 255]);
  }
  const F = FORM[p], img = compose(p, 1), ft = footing(p), k = 5;
  const gx = Math.round(W / 2 + (p === 4 ? 90 : 120)), gy = 662, x0 = Math.round(gx - (F.W - ft.cx) * k);
  c.floorGlow(gx, gy - 4, ft.half * .95, 3.2, k, GLOWCOL[p]);
  c.shadow(gx, gy - 4, ft.half * 1.1, 3.4, k);
  c.sprite(img.px, img.w, img.h, x0, gy - F.H * k, k, true);
  const kx = 250, ky = 676;
  c.shadow(kx + 24, ky - 2, 8, 2.4, 3);
  c.rgba(knight, kx, ky - knight.h * 3, 3);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const d = Math.hypot((x - 640) / 640, (y - 360) / 360); if (d > .75) c.tint(x, y, [120, 10, 16], Math.min(.45, (d - .75) * .9)); }
  const label = `HYBRID ${F.name.toUpperCase()}  -  1 QUELLPIXEL = 5 WELT-PX, RITTER X3  -  1280x720 WELT-PX, BODEN AUS 01-KAMPFRAUM-ETAGE5`;
  c.rect(16, 16, textW(label, 2) + 16, 26, [14, 8, 10, 255]);
  c.text(24, 22, label, TXT, 2);
  fs.writeFileSync(file, encodePng(W, H, c.d));
}
// The same in the real room screenshot at its own zoom (~0.5: 2.5 screen px per source px), facing
// the hero (who stands at about 635, 370 in the shot). spots: [[form, foot x, foot y], ...].
function ingameZoom(shot, file, spots, label) {
  const c = new Canvas(shot.w, shot.h, [0, 0, 0, 255]);
  c.d.set(shot.rgba);
  for (const [p, gx, gy] of spots) {
    const F = FORM[p], img = compose(p, 1), ft = footing(p), k = 2.5, x0 = Math.round(gx - (F.W - ft.cx) * k);
    c.glowPx(gx, gy - 2, ft.half * 2.4, 8, GLOWCOL[p]);
    c.shadowPx(gx, gy - 2, ft.half * 2.75, 8.5);
    c.sprite(img.px, img.w, img.h, x0, gy - Math.round(F.H * k), k, true);
  }
  c.rect(0, 700, 1280, 20, [14, 12, 12, 255]);
  c.text(8, 704, label, [250, 203, 62, 255], 2);
  fs.writeFileSync(file, encodePng(c.w, c.h, c.d));
}

// ---------- pose frames: the rig driven like src/rig/rig_poses.gd drake() (drake_hybrid.js posed) ----------
// The tail whip of rig_poses.gd's _drake_chain at its widest (every segment at its peak; the real
// chain lags, so this is the worst case for the joints), plus clips at their extremes.
function chain(amp0, grow, sign) { const o = {}; for (let i = 0; i < 5; i++) o['tail_' + (i + 1)] = { rot: sign * (amp0 + grow * i) }; return o; }
const POSES = {
  'RUHE': {},
  'SCHWANZ +': Object.assign(chain(.06, .012, 1), { neck: { rot: .06 }, head: { rot: .065 }, jaw: { rot: .06 } }),
  'SCHWANZ -': Object.assign(chain(.06, .012, -1), { neck: { rot: -.06 }, head: { rot: -.065 } }),
  'BISS': Object.assign(chain(.05, .01, -1), { tail_1: { rot: -.03 }, neck: { rot: .14 }, head: { rot: .12 }, jaw: { rot: .5 }, arm: { rot: .26 }, wing_far: { rot: -.07 }, wing_near: { rot: .07 } }),
  // the wing beat at its top: both wings up. The near wing spreads left of its pivot, so up is a
  // clockwise turn; a far wing that spreads right of its pivot (form 4's, beside the head) needs the
  // opposite turn (posesSheet flips it; rig_poses.gd turns both wings the same way today)
  'FLUG': Object.assign(chain(.04, .012, 1), { tail_1: { rot: .19 }, leg_far: { rot: -.5, dy: -1 }, leg_near: { rot: -.6, dy: -1.2 }, arm: { rot: -.55 }, neck: { rot: .1 }, wing_far: { rot: .55 }, wing_near: { rot: .55 }, jaw: { rot: .2 } }),
};
function posesSheet(file, forms) {
  const k = 3, pad = 22, names = Object.keys(POSES), gap = 16, top = 34, rowsH = forms.map(p => (FORM[p].H + pad * 2) * k + 30);
  const colW = Math.max(...forms.map(p => (FORM[p].W + pad * 2) * k));
  const W = gap + names.length * (colW + gap), H = top + rowsH.reduce((a, b) => a + b, 0) + 10;
  const c = new Canvas(W, H, BG);
  c.text(gap, 12, 'HYBRID  -  POSEN AUS DEN RIG-TEILEN (WIE RIG_POSES.GD: DREHUNG UM DEN PIVOT, KINDER ERBEN)  -  GELENKE OHNE LUECKEN?', TXT, 2);
  let y = top;
  forms.forEach((p, ri) => {
    names.forEach((n, i) => {
      const pose = Object.assign({}, POSES[n]);
      if (pose.wing_far && farWingRight(p)) pose.wing_far = { rot: -pose.wing_far.rot };
      const img = posed(p, pose, 1, pad), x = gap + i * (colW + gap);
      c.rect(x, y, img.w * k, img.h * k, [44, 30, 34, 255]);
      c.sprite(img.px, img.w, img.h, x, y, k);
      c.text(x + 6, y + img.h * k + 6, p + '  ' + n + (pose.wing_far && farWingRight(p) && n === 'FLUG' ? '  (FERNER FLUEGEL GEGENLAEUFIG)' : ''), ACC, 2);
    });
    y += rowsH[ri];
  });
  fs.writeFileSync(file, encodePng(W, H, c.d));
}

// Every form-4 part rendered isolated: an exploded view (each part pushed away from its parent's
// pivot, pivots cyan, points green, severable parts framed orange or red) and one cell per part
// (cropped, own outline, pivot, z, parent, the px a hit can land on).
function partsSheet(file) {
  const p = 4, r = parts(p, 1), W = r.w, H = r.h, chk = checkForm(p), form = ER.FORMS[p];
  const byId = Object.fromEntries(r.parts.map(e => [e.id, e]));
  const off = {};
  const offset = id => {
    if (off[id]) return off[id];
    const par = ER.PARENT[id];
    if (!par || !byId[par]) return (off[id] = [0, 0]);
    const po = offset(par), a = r.joints[par], b = r.joints[id];
    let dx = b[0] - a[0], dy = b[1] - a[1];
    const l = Math.hypot(dx, dy) || 1, push = Math.min(24, 8 + l * .45);
    if (l < 1) { dx = 0; dy = -1; }
    return (off[id] = [po[0] + dx / (l || 1) * push, po[1] + dy / (l || 1) * push]);
  };
  for (const e of r.parts) offset(e.id);
  const ex = Object.values(off), mx = Math.max(...ex.map(o => Math.abs(o[0]))), my = Math.max(...ex.map(o => Math.abs(o[1])));
  const k = 4, EW = Math.ceil(W + mx * 2 + 6), EH = Math.ceil(H + my * 2 + 6);
  // cells
  const boxes = r.parts.map(e => { let x0 = W, y0 = H, x1 = -1, y1 = -1; e.img.px.forEach((c, i) => { if (c) { const x = i % W, y = Math.floor(i / W); x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } }); return { x0, y0, x1, y1 }; });
  const ck = 3, cellW = 250, cols = 7, cellH = 230, rows = Math.ceil(r.parts.length / cols);
  const CW = Math.max(EW * k + 40, cols * (cellW + 10) + 20), CH = 40 + EH * k + 30 + rows * (cellH + 10) + 20;
  const c = new Canvas(CW, CH, [30, 26, 32, 255]);
  c.text(16, 12, 'HYBRID FORM 4 OBSIDIANFORM  -  ALLE RIG-TEILE ISOLIERT GERENDERT (EIGENE KONTUR)   TUERKIS = PIVOT, GRUEN = PUNKT, ORANGE = ABTRENNBAR, ROT = SPERRT', TXT, 2);
  const panel = [52, 44, 54, 255], cyan = [90, 230, 220, 255], green = [140, 255, 120, 255], orange = [240, 180, 60, 255], red = [230, 70, 60, 255];
  const mark = (x, y, col, sz) => { sz = sz || 4; c.rect(x - sz, y, sz * 2 + 1, 1, col); c.rect(x, y - sz, 1, sz * 2 + 1, col); c.rect(x - 1, y - 1, 3, 3, col); };
  const ox = 20, oy = 36;
  c.rect(ox, oy, EW * k, EH * k, panel);
  const cx = (EW - W) / 2, cy = (EH - H) / 2;
  for (const e of r.parts) c.sprite(e.img.px, W, H, Math.round(ox + (cx + off[e.id][0]) * k), Math.round(oy + (cy + off[e.id][1]) * k), k);
  const frame = (e, x, y, kk, col) => {
    const on = (xx, yy) => xx >= 0 && yy >= 0 && xx < W && yy < H && e.img.px[yy * W + xx];
    for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
      if (!on(xx, yy)) continue;
      const X0 = x + xx * kk, Y0 = y + yy * kk;
      if (!on(xx - 1, yy)) c.rect(X0 - 2, Y0, 2, kk, col);
      if (!on(xx + 1, yy)) c.rect(X0 + kk, Y0, 2, kk, col);
      if (!on(xx, yy - 1)) c.rect(X0, Y0 - 2, kk, 2, col);
      if (!on(xx, yy + 1)) c.rect(X0, Y0 + kk, kk, 2, col);
    }
  };
  for (const e of r.parts) { const cut = form.cut[e.id]; if (cut) frame(e, Math.round(ox + (cx + off[e.id][0]) * k), Math.round(oy + (cy + off[e.id][1]) * k), k, cut.disables ? red : orange); }
  for (const e of r.parts) { const j = r.joints[e.id], o = off[e.id]; mark(Math.round(ox + (cx + o[0] + j[0]) * k), Math.round(oy + (cy + o[1] + j[1]) * k), cyan); }
  for (const name in POINTS) { const j = r.joints[name], o = off[POINTS[name]]; mark(Math.round(ox + (cx + o[0] + j[0]) * k), Math.round(oy + (cy + o[1] + j[1]) * k), green, 3); }
  // cells
  const top2 = oy + EH * k + 24;
  r.parts.forEach((e, n) => {
    const b = boxes[n], col = n % cols, row = Math.floor(n / cols), x = 20 + col * (cellW + 10), y = top2 + row * (cellH + 10);
    c.rect(x, y, cellW, cellH, panel);
    const bw = b.x1 - b.x0 + 1, bh = b.y1 - b.y0 + 1, kk = Math.max(1, Math.min(ck * 2, Math.floor(Math.min((cellW - 16) / (bw + 6), (cellH - 46) / (bh + 6)))));
    const px0 = x + Math.round((cellW - bw * kk) / 2) - b.x0 * kk, py0 = y + 8 + Math.round((cellH - 46 - bh * kk) / 2) - b.y0 * kk;
    c.sprite(e.img.px, W, H, px0, py0, kk);
    const cut = form.cut[e.id];
    if (cut) frame(e, px0, py0, kk, cut.disables ? red : orange);
    const j = r.joints[e.id];
    mark(Math.round(px0 + j[0] * kk), Math.round(py0 + j[1] * kk), cyan);
    for (const name in POINTS) if (POINTS[name] === e.id) { const q = r.joints[name]; mark(Math.round(px0 + q[0] * kk), Math.round(py0 + q[1] * kk), green, 3); }
    c.text(x + 6, y + cellH - 34, `${e.id.toUpperCase()}  Z${e.z}  X${kk}`, cut ? (cut.disables ? red : orange) : TXT, 2);
    c.text(x + 6, y + cellH - 18, `AN ${ER.PARENT[e.id] || '-'}  TREFFER ${chk.vis[e.id]} PX`.toUpperCase(), DIM, 2);
  });
  fs.writeFileSync(file, encodePng(CW, CH, c.d));
}

function main() {
  const root = process.argv.slice(2).find(a => !a.startsWith('--')) || path.join(__dirname, '..', '..', '..');
  const out = path.join(root, 'production', 'qa', 'evidence', 'drake-concepts');
  fs.mkdirSync(out, { recursive: true });
  for (const p of [1, 2, 3, 4]) {
    const r = checkForm(p);
    console.log(`drache${p} ${FORM[p].name}: frame ${FORM[p].W}x${FORM[p].H}, ${heightPx(p)} px tall = ${(heightPx(p) * 5 / HERO_H).toFixed(2)}x hero, hit px: ${r.visible}${r.problems.length ? '\n  PROBLEM ' + r.problems.join('\n  PROBLEM ') : ', contract ok'}`);
  }
  const knight = decodePng(fs.readFileSync(path.join(root, 'assets', 'sprites', '0x72', 'knight_m_idle_anim_f0.png')));
  const shot = decodePng(fs.readFileSync(path.join(root, 'production', 'qa', 'evidence', 'hell-monsters', '01-kampfraum-etage5.png')));
  if (process.argv.includes('--quick')) { bigSheet(knight, path.join(out, 'hybrid_form4.png')); lineup(knight, path.join(out, 'hybrid_lineup.png')); return; }
  lineup(knight, path.join(out, 'hybrid_lineup.png'));
  bigSheet(knight, path.join(out, 'hybrid_form4.png'));
  ingame(knight, shot, path.join(out, 'hybrid_ingame.png'), 4);
  ingame(knight, shot, path.join(out, 'hybrid_ingame_form3.png'), 3);
  ingameZoom(shot, path.join(out, 'hybrid_ingame_zoom.png'), [[4, 905, 655]], 'HYBRID OBSIDIANFORM IM ECHTEN RAUM-SCREENSHOT (ZOOM CA. 0.5 = 2.5 BILDSCHIRM-PX PRO QUELLPIXEL)');
  ingameZoom(shot, path.join(out, 'hybrid_ingame_zoom_form3.png'), [[3, 900, 640]], 'HYBRID GLUTDRACHE IM ECHTEN RAUM-SCREENSHOT (ZOOM CA. 0.5 = 2.5 BILDSCHIRM-PX PRO QUELLPIXEL)');
  ingameZoom(shot, path.join(out, 'hybrid_ingame_zoom_form12.png'), [[1, 600, 610], [2, 1060, 600]], 'HYBRID SALAMANDER (LINKS) UND JUNGDRACHE (RECHTS) IM ECHTEN RAUM-SCREENSHOT (ZOOM CA. 0.5)');
  posesSheet(path.join(out, 'hybrid_poses34.png'), [4, 3]);
  posesSheet(path.join(out, 'hybrid_poses12.png'), [2, 1]);
  partsSheet(path.join(out, 'hybrid_parts4.png'));
  for (const p of [1, 2, 3, 4]) ER.preview(buildRig(p), path.join(out, `hybrid_rig${p}.png`));
  console.log('wrote', out);
}

module.exports = { renderRig, compose, parts, posed, POSES, checkForm, fit, buildRig, FORM, SEAMLESS, decodePng, farWingRight };
if (require.main === module) main();

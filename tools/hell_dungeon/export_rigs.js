// Exports Ignaroth's four forms (drache1..4) as part rigs for the Godot game:
//   assets/sprites/hell/rigs/<id>/<part>.png       one full-frame PNG per part, 1 px per source px
//   assets/sprites/hell/rigs/<id>/<part>_0..3.png  flipbook parts (the flames), 4 frames
//   assets/data/hell_rigs.json                     parts, pivots, parents, z, HP weights, effects
// Every part is drawn by drake_hybrid.js (the approved "Hybrid" art) in its rest pose, isolated
// (only the draw calls tagged with that part, with its own outline). Pivots and points come from
// its joints; the part ids, parents and layers are drake_hybrid.js's PARENT and Z.
// The drake atlases (assets/sprites/hell/monsters/drache1..4.png) are posed from the same parts:
// node tools/hell_dungeon/export_monsters.js --only drache1,drache2,drache3,drache4
// Usage: node tools/hell_dungeon/export_rigs.js [repo_root] [--preview]
//   --preview also writes production/qa/evidence/hell-rigs/preview_drache<N>.png (4x or more: rest pose,
//   exploded view with pivots, one label row per part).
//   Part files of a form that the rig no longer lists (renamed or removed parts) are deleted.
// Check: node tools/hell_dungeon/export_rigs.js [repo_root] --check
//   writes nothing; checks hell_rigs.json and its PNGs on disk against the data contract (see
//   checkRigs) and prints "HELL_RIGS checked=N failures=M", exit code 1 on a failure.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const HM = require('./hell_monsters.js');
const DH = require('./drake_hybrid.js');
const { encodePng } = require('./monster_sheet.js');

const args = process.argv.slice(2);
const root = args.find(a => !a.startsWith('--')) || path.join(__dirname, '..', '..');
const PREVIEW = args.includes('--preview');
const CHECK = args.includes('--check');
const RES_DIR = 'res://assets/sprites/hell/rigs';
const outDir = path.join(root, 'assets', 'sprites', 'hell', 'rigs');

// ---------- rig layout (the same ids for the same body part in every form) ----------
// PARENT and Z (back to front) live with the art in drake_hybrid.js; SEAMLESS lists the joints
// without a seam (where these neighbours overlap, neither draws its outline over the other, so the
// neck grows out of the chest and the tail reads as one tail at rest); FLIPBOOK the 4-frame flames.
const { PARENT, Z, SEAMLESS, FLIPBOOK } = DH;
const LABEL = {
  body: 'Rumpf', neck: 'Hals', head: 'Kopf', jaw: 'Kiefer', arm: 'Vorderklaue', leg_far: 'Linkes Bein', leg_near: 'Rechtes Bein',
  tail_1: 'Schwanzwurzel', tail_2: 'Schwanz', tail_3: 'Schwanz', tail_4: 'Schwanz', tail_5: 'Schwanzspitze', tail_flame: 'Schwanzflamme',
  wing_far: 'Linker Flügel', wing_near: 'Rechter Flügel', throat: 'Kehle', horns: 'Hörner',
  crystal_1: 'Leerenkristall', crystal_2: 'Leerenkristall', crystal_3: 'Leerenkristall', mouth_flame: 'Maulflamme',
};
const WINGS = ['wing_far', 'wing_near'];
const TAIL_REST = ['tail_3', 'tail_4', 'tail_5', 'tail_flame'];

// Per form: the HP weight of every part (severable ones carry their effect, the rest is
// unbreakable; hp 0 = decorative, never hit) and the rig groups. Totals: forms 1-2 100 with
// three severable parts of 15, form 3 100 with 50 severable, form 4 120 with 7 x 10 severable.
const FORMS = {
  1: {
    material: 'ember',
    hp: { body: 22, head: 8, neck: 5, jaw: 15, arm: 15, leg_far: 4, leg_near: 4, tail_1: 4, tail_2: 15, tail_3: 3, tail_4: 2, tail_5: 2, tail_flame: 1 },
    cut: {
      jaw: { disables: ['spucke'] },
      arm: { weakens: { graben: { ring: 0.5 } } },
      tail_2: { weakens: { huschen: { speed: 0.6 }, satz: { radius: 0.6 } }, alsoDetach: TAIL_REST },
    },
    groups: {},
  },
  2: {
    material: 'ember',
    hp: { body: 22, head: 8, neck: 5, jaw: 15, arm: 15, leg_far: 4, leg_near: 4, tail_1: 4, tail_2: 15, tail_3: 3, tail_4: 2, tail_5: 2, tail_flame: 1 },
    cut: {
      jaw: { weakens: { salve: { count: 0.34 } } },
      tail_2: { disables: ['schwanz'], alsoDetach: TAIL_REST },
      arm: { weakens: { lavabruch: { ring: 0.5, lava: 0 } } },
    },
    groups: {},
  },
  3: {
    material: 'ember',
    hp: { body: 18, head: 7, neck: 5, jaw: 4, arm: 3, leg_far: 3, leg_near: 3, tail_1: 2, tail_2: 2, tail_3: 1, tail_4: 1, tail_5: 1, tail_flame: 0,
      wing_far: 12, wing_near: 12, throat: 14, horns: 12 },
    cut: {
      wing_far: { group: 'wings', weakens: { bombenflug: { duration: 0.5 } } },
      wing_near: { group: 'wings', weakens: { bombenflug: { duration: 0.5 } } },
      throat: { exposed: 'atem', disables: ['atem'] },
      horns: { weakens: { faecher: { count: 0.43 } } },
    },
    groups: { wings: { parts: ['wing_far', 'wing_near'], disables: ['bombenflug'] } },
  },
  4: {
    material: 'obsidian',
    hp: { body: 19, head: 7, neck: 5, jaw: 4, arm: 3, leg_far: 3, leg_near: 3, tail_1: 2, tail_2: 1, tail_3: 1, tail_4: 1, tail_5: 1, tail_flame: 0,
      wing_far: 10, wing_near: 10, throat: 10, horns: 10, crystal_1: 10, crystal_2: 10, crystal_3: 10, mouth_flame: 0 },
    cut: {
      crystal_1: { group: 'crystals', weakens: { strahlen: { beams: 0.667 } } },
      crystal_2: { group: 'crystals', weakens: { strahlen: { beams: 0.667 } } },
      crystal_3: { group: 'crystals', weakens: { strahlen: { beams: 0.667 } } },
      wing_far: { group: 'wings', weakens: { leerenregen: { duration: 0.5 } } },
      wing_near: { group: 'wings', weakens: { leerenregen: { duration: 0.5 } } },
      throat: { exposed: 'atem', disables: ['atem'] },
      horns: { weakens: { echos: { forms: 0.34 } } },
    },
    groups: {
      wings: { parts: ['wing_far', 'wing_near'], disables: ['leerenregen'] },
      crystals: { parts: ['crystal_1', 'crystal_2', 'crystal_3'], disables: ['strahlen'] },
    },
  },
};
// The world scale on top of RigLibrary.PIXEL_SCALE (2): 5 world px per source px, the hell's draw scale.
const SCALE = 2.5;

// ---------- helpers ----------
const round1 = v => Math.round(v * 10) / 10;
function toRgba(r) {
  const data = new Uint8Array(r.w * r.h * 4);
  r.px.forEach((c, i) => { if (c) { const [R, G, B] = HM.hexToRgb(c); data.set([R, G, B, 255], i * 4); } });
  return data;
}
const opaque = (img, w, x, y) => img[(y * w + x) * 4 + 3] > 0;
function bounds(img, w, h) {
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (opaque(img, w, x, y)) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  return x1 < 0 ? null : { x0, y0, x1, y1 };
}

/** Builds one form: the part images (RGBA, frame-sized) and its hell_rigs.json entry. */
function buildForm(p) {
  const id = 'drache' + p, def = HM.DEFS[id], form = FORMS[p];
  const all = DH.renderRig(p, null, 0), J = all.joints, W = all.w, H = all.h;
  const ids = all.tags.filter(t => PARENT[t] !== undefined);
  const unknown = all.tags.filter(t => PARENT[t] === undefined);
  if (unknown.length) throw new Error(id + ': untagged parts ' + unknown.join(', '));
  ids.sort((a, b) => Z[a] - Z[b] || ids.indexOf(a) - ids.indexOf(b));
  const images = {}, parts = [], solid = {};
  for (const part of ids) solid[part] = DH.renderRig(p, part, 0).solid;
  for (const part of ids) {
    const frames = FLIPBOOK.has(part) ? [0, 1, 2, 3] : [0];
    const near = SEAMLESS.filter(pair => pair.includes(part)).map(pair => solid[pair[0] === part ? pair[1] : pair[0]]).filter(Boolean);
    const skip = near.length ? i => near.some(m => m[i]) : undefined;
    images[part] = frames.map(f => toRgba(DH.renderRig(p, part, f, skip)));
    if (!J[part]) throw new Error(id + ': no joint for ' + part);
    const entry = { id: part };
    if (frames.length > 1) entry.frames = frames.map(f => `${RES_DIR}/${id}/${part}_${f}.png`);
    else entry.img = `${RES_DIR}/${id}/${part}.png`;
    Object.assign(entry, { pivot: J[part].map(round1), parent: PARENT[part], z: Z[part], hp: form.hp[part] || 0, label: LABEL[part] });
    const cut = form.cut[part];
    if (!cut) entry.unbreakable = true;
    else {
      if (cut.disables) entry.disables = cut.disables;
      if (cut.weakens) entry.weakens = cut.weakens;
      if (cut.alsoDetach) entry.alsoDetach = cut.alsoDetach;
      if (cut.exposed) entry.exposed = cut.exposed;
      if (cut.group) entry.group = cut.group;
    }
    // wings: the turn that lifts them (flap) and how far they may turn before covering the head
    // (swing [lo, hi] rad); rig_poses.gd turns them by flap and keeps them inside swing
    if (WINGS.includes(part)) Object.assign(entry, DH.wingRange(p, part));
    parts.push(entry);
  }
  // Feet: the lowest row of both legs; the anchor sits in the middle of that row's pixels.
  let gy = -1, gx0 = W, gx1 = -1;
  for (const leg of ['leg_far', 'leg_near']) { const b = bounds(images[leg][0], W, H); gy = Math.max(gy, b.y1); }
  for (const leg of ['leg_far', 'leg_near']) for (let x = 0; x < W; x++) if (opaque(images[leg][0], W, x, gy)) { gx0 = Math.min(gx0, x); gx1 = Math.max(gx1, x); }
  // Shadow: as wide as the chest with both legs, a little narrower than that span.
  let sx0 = W, sx1 = -1;
  for (const part of ['body', 'leg_far', 'leg_near']) { const b = bounds(images[part][0], W, H); sx0 = Math.min(sx0, b.x0); sx1 = Math.max(sx1, b.x1); }
  const rig = {
    family: 'drake', variant: String(p), size: [W, H], scale: SCALE,
    ground: [round1((gx0 + gx1 + 1) / 2), gy], width: Math.round((sx1 - sx0 + 1) * .85),
    material: form.material, parts, groups: form.groups,
    points: {
      mouth: { part: 'jaw', at: J.mouth.map(round1) },
      throat: { part: 'neck', at: J.throat_at.map(round1) },
      hand: { part: 'arm', at: J.hand.map(round1) },
      tail_tip: { part: 'tail_5', at: J.tail_tip.map(round1) },
      core: { part: 'body', at: J.core.map(round1) },
    },
  };
  return { id, def, rig, images, W, H };
}

// ---------- preview (4x): rest pose, exploded view, label rows ----------
const FONT = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111', F: '111100110100100',
  G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010', K: '101101110101101', L: '100100100100111',
  M: '101111111101101', N: '110101101101101', O: '010101101101010', P: '110101110100100', Q: '010101101110011', R: '110101110101101',
  S: '011100010001110', T: '111010010010010', U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101',
  Y: '101101010010010', Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111', 9: '111101111001110',
  ' ': '000000000000000', '.': '000000000000010', ':': '000010000010000', '-': '000000111000000', _: '000000000000111', '%': '101001010100101',
  '/': '001001010100100', '+': '000010111010000', '(': '001010010010001', ')': '100010010010100', '=': '000111000111000', ',': '000000000010100',
  '>': '100010001010100', '*': '101010101000000', '[': '011010010010011', ']': '110010010010110',
};
function Canvas(w, h, bg) {
  this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) this.d.set(bg, i * 4);
}
Canvas.prototype.px = function (x, y, c) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d.set(c, (y * this.w + x) * 4); };
Canvas.prototype.rect = function (x, y, w, h, c) { for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, c); };
Canvas.prototype.text = function (x, y, str, c, k) {
  k = k || 2;
  for (const ch of String(str).toUpperCase()) {
    const g = FONT[ch] || FONT['*'];
    for (let i = 0; i < 15; i++) if (g[i] === '1') this.rect(x + (i % 3) * k, y + Math.floor(i / 3) * k, k, k, c);
    x += 4 * k;
  }
};
Canvas.prototype.image = function (img, w, h, x, y, k) {
  for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) {
    const i = (yy * w + xx) * 4;
    if (img[i + 3]) this.rect(x + xx * k, y + yy * k, k, k, img.subarray(i, i + 4));
  }
};
// A 2 px line just outside the part's silhouette.
Canvas.prototype.outline = function (img, w, h, x, y, k, c) {
  const on = (xx, yy) => xx >= 0 && yy >= 0 && xx < w && yy < h && opaque(img, w, xx, yy);
  for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) {
    if (!on(xx, yy)) continue;
    const X = x + xx * k, Y = y + yy * k;
    if (!on(xx - 1, yy)) this.rect(X - 2, Y - 2, 2, k + 4, c);
    if (!on(xx + 1, yy)) this.rect(X + k, Y - 2, 2, k + 4, c);
    if (!on(xx, yy - 1)) this.rect(X - 2, Y - 2, k + 4, 2, c);
    if (!on(xx, yy + 1)) this.rect(X - 2, Y + k, k + 4, 2, c);
  }
};
const RGB = { bg: [38, 33, 40, 255], panel: [58, 50, 60, 255], ground: [90, 78, 88, 255], text: [236, 226, 214, 255], dim: [150, 140, 150, 255],
  off: [230, 70, 60, 255], weak: [240, 180, 60, 255], pivot: [90, 230, 220, 255], point: [140, 255, 120, 255] };

function effectText(e) {
  const out = [];
  if (e.disables) out.push('SPERRT ' + e.disables.join(','));
  if (e.weakens) for (const a in e.weakens) for (const k in e.weakens[a]) out.push(`${a}.${k} X${e.weakens[a][k]}`);
  if (e.group) out.push('GRUPPE ' + e.group);
  if (e.exposed) out.push('NUR BEI ' + e.exposed);
  if (e.alsoDetach) out.push('+ ' + e.alsoDetach.join(','));
  if (e.flap) out.push(`FLAP ${e.flap} SWING ${e.swing[0]}..${e.swing[1]}`);
  return out.join('  ');
}

function preview(form, file) {
  const { id, def, rig, images, W, H } = form, K = Math.max(4, Math.ceil(240 / W)), total = rig.parts.reduce((s, e) => s + e.hp, 0);
  const byId = Object.fromEntries(rig.parts.map(e => [e.id, e]));
  // exploded offsets: each part moves away from its parent along parent pivot -> own pivot
  const off = {};
  const offset = e => {
    if (off[e.id]) return off[e.id];
    if (!e.parent) return (off[e.id] = [0, 0]);
    const par = byId[e.parent], po = offset(par);
    let dx = e.pivot[0] - par.pivot[0], dy = e.pivot[1] - par.pivot[1];
    const l = Math.hypot(dx, dy) || 1, push = Math.min(6, 2 + l * .25) * (W / 40);
    return (off[e.id] = [po[0] + dx / l * push, po[1] + dy / l * push]);
  };
  rig.parts.forEach(offset);
  const ex = Object.values(off), mx = Math.max(...ex.map(o => Math.abs(o[0]))), my = Math.max(...ex.map(o => Math.abs(o[1])));
  const EW = Math.ceil(W + mx * 2 + 4), EH = Math.ceil(H + my * 2 + 4);
  const lines = [
    [`IGNAROTH ${id}  ${def.name.split('·')[1] ? def.name.split('·')[1].trim() : ''}  FRAME ${W}X${H} AT ${K}X  RIG SCALE ${rig.scale}  MATERIAL ${rig.material}  TOTAL HP ${total}`, RGB.text],
    [`LEFT: REST POSE FROM PARTS   RIGHT: EXPLODED, CYAN = PIVOT, GREEN = POINT, RED = SPERRT, ORANGE = SCHWAECHT`, RGB.dim],
  ];
  for (const e of rig.parts) {
    const share = e.hp ? ` ${(e.hp / total * 100).toFixed(1)}%` : '';
    const col = e.unbreakable ? RGB.dim : e.disables ? RGB.off : RGB.weak;
    lines.push([`${e.id.padEnd(11)} LAYER ${String(e.z).padEnd(3)} ${(e.parent || '-').padEnd(9)} HP ${String(e.hp).padEnd(3)}${share.padEnd(7)} ${e.unbreakable ? (e.hp ? 'UNZERBRECHLICH' : 'DEKO') : effectText(e)}`, col]);
  }
  for (const g in rig.groups) lines.push([`GRUPPE ${g}: ${rig.groups[g].parts.join(',')} ALLE WEG = SPERRT ${rig.groups[g].disables.join(',')}`, RGB.off]);
  const textW = Math.max(...lines.map(l => l[0].length)) * 8 + 24;
  const pw = W * K + 16, ew = EW * K + 16, top = 12;
  const CW = Math.max(pw + ew + 24, textW), CH = top + Math.max(H, EH) * K + 24 + lines.length * 14 + 12;
  const c = new Canvas(CW, CH, RGB.bg);
  // rest pose
  c.rect(8, top, W * K, H * K, RGB.panel);
  c.rect(8, top + (rig.ground[1] + 1) * K, W * K, 2, RGB.ground);
  for (const e of rig.parts) c.image(images[e.id][0], W, H, 8, top, K);
  // exploded
  const ox = pw + 16, oy = top, cx = (EW - W) / 2, cy = (EH - H) / 2;
  c.rect(ox, oy, EW * K, EH * K, RGB.panel);
  const at = e => [Math.round(ox + (cx + off[e.id][0]) * K), Math.round(oy + (cy + off[e.id][1]) * K)];
  for (const e of rig.parts) c.image(images[e.id][0], W, H, ...at(e), K);
  for (const e of rig.parts) if (!e.unbreakable) c.outline(images[e.id][0], W, H, ...at(e), K, e.disables ? RGB.off : RGB.weak);
  const mark = (x, y, col) => { c.rect(x - 4, y, 9, 1, col); c.rect(x, y - 4, 1, 9, col); c.rect(x - 1, y - 1, 3, 3, col); };
  for (const e of rig.parts) { const o = off[e.id]; mark(Math.round(ox + (cx + o[0] + e.pivot[0]) * K), Math.round(oy + (cy + o[1] + e.pivot[1]) * K), RGB.pivot); }
  for (const name in rig.points) { const pt = rig.points[name], o = off[pt.part]; mark(Math.round(ox + (cx + o[0] + pt.at[0]) * K), Math.round(oy + (cy + o[1] + pt.at[1]) * K), RGB.point); }
  let ty = top + Math.max(H, EH) * K + 18;
  for (const [str, col] of lines) { c.text(10, ty, str, col, 2); ty += 14; }
  fs.writeFileSync(file, encodePng(CW, CH, c.d));
}

// ---------- check (--check): the files on disk against the data contract ----------
// The part ids every form must have (BOSS-03: the same id for the same body part in every form).
const BASE_IDS = ['body', 'neck', 'head', 'jaw', 'arm', 'leg_far', 'leg_near', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_5', 'tail_flame'];
const EXPECT = {
  drache1: BASE_IDS, drache2: BASE_IDS,
  drache3: BASE_IDS.concat(['wing_far', 'wing_near', 'throat', 'horns']),
  drache4: BASE_IDS.concat(['wing_far', 'wing_near', 'throat', 'horns', 'crystal_1', 'crystal_2', 'crystal_3', 'mouth_flame']),
};
const MATERIAL = { drache1: 'ember', drache2: 'ember', drache3: 'ember', drache4: 'obsidian' };
const POINTS = { mouth: 'jaw', throat: 'neck', hand: 'arm', tail_tip: 'tail_5', core: 'body' };
// A severable part needs this many source px where it is the part a hit lands on (the highest
// layer with a pixel there, as RigLibrary.part_at decides) in the rest pose: 20 px = 500 world px
// at 5 world px per source px. The smallest targets are the salamander's (form 1): its 1-2 px thin
// tail shows 28 px beside the legs, 20 of them tail_2 (the cut part); more would leave the chain
// tail_3..5 with almost no pixels. Its jaw shows 22 px.
const MIN_VISIBLE = 20;
// A flipbook needs this many different frames to flicker.
const MIN_DISTINCT_FRAMES = 3;

/** Decodes an 8-bit PNG (grey, RGB, RGBA, grey+alpha or palette) to { w, h, rgba }. */
function decodePng(buf) {
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error('not a PNG');
  let pos = 8, w = 0, h = 0, depth = 0, type = 0, pal = null, trns = null;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), kind = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); depth = data[8]; type = data[9]; }
    else if (kind === 'PLTE') pal = data;
    else if (kind === 'tRNS') trns = data;
    else if (kind === 'IDAT') idat.push(data);
    else if (kind === 'IEND') break;
    pos += 12 + len;
  }
  if (depth !== 8) throw new Error('bit depth ' + depth + ' not supported');
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[type], stride = w * ch, raw = zlib.inflateSync(Buffer.concat(idat));
  const px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[y * stride + x - ch] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = x >= ch && y ? px[(y - 1) * stride + x - ch] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      px[y * stride + x] = v & 255;
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
/** Distance from a point (source px, continuous) to the nearest opaque pixel centre, or Infinity. */
function nearest(img, at) {
  let best = Infinity;
  for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) if (img.rgba[(y * img.w + x) * 4 + 3] > 0) best = Math.min(best, Math.hypot(x + .5 - at[0], y + .5 - at[1]));
  return best;
}
/** The union of several frame images (a flipbook's hit image, as in RigLibrary). */
function union(imgs) {
  const out = { w: imgs[0].w, h: imgs[0].h, rgba: new Uint8Array(imgs[0].rgba.length) };
  for (const im of imgs) for (let i = 3; i < im.rgba.length; i += 4) if (im.rgba[i]) out.rgba.set(im.rgba.subarray(i - 3, i + 1), i - 3);
  return out;
}
const opaqueCount = img => { let n = 0; for (let i = 3; i < img.rgba.length; i += 4) if (img.rgba[i]) n++; return n; };
/** The edges an image touches: "row 0", "column 0", "column W-1" (the bottom row holds the feet). */
function edgesTouched(img) {
  const out = [], on = (x, y) => img.rgba[(y * img.w + x) * 4 + 3] > 0;
  for (let x = 0; x < img.w; x++) if (on(x, 0)) { out.push('row 0'); break; }
  for (let y = 0; y < img.h; y++) if (on(0, y)) { out.push('column 0'); break; }
  for (let y = 0; y < img.h; y++) if (on(img.w - 1, y)) { out.push(`column ${img.w - 1}`); break; }
  return out;
}
/** Per part id: the number of pixels where it is the part a hit lands on (highest z, the first listed on a tie). */
function visiblePixels(parts, img, W, H) {
  const count = Object.fromEntries(parts.map(p => [p.id, 0]));
  for (let i = 0; i < W * H; i++) {
    let owner = null, z = -Infinity;
    for (const p of parts) if (img[p.id] && img[p.id].rgba[i * 4 + 3] > 0 && p.z > z) { owner = p.id; z = p.z; }
    if (owner) count[owner]++;
  }
  return count;
}

/**
 * Checks assets/data/hell_rigs.json and its part PNGs under repoRoot against the hell rig data
 * contract: images exist, are frame-sized, not empty and not cut by the frame (no opaque pixel on
 * row 0, column 0 or the last column); flipbooks have 4 frames, at least 3 of them different;
 * parents, pivots, points and the ground are sane; HP weights are fair (each severable part 8-20 %
 * of the form, all severable together <= 60 %, the body the largest unbreakable share); every
 * severable part has an effect and at least MIN_VISIBLE px a hit can land on; every
 * disables/weakens/exposed/group attack id exists for that form in assets/data/hell_monsters.json;
 * alsoDetach parts and group members exist with hp >= 1. Returns { checked, problems, notes, lines }.
 */
function checkRigs(repoRoot) {
  const rigs = JSON.parse(fs.readFileSync(path.join(repoRoot, 'assets', 'data', 'hell_rigs.json'), 'utf8'));
  const monsters = JSON.parse(fs.readFileSync(path.join(repoRoot, 'assets', 'data', 'hell_monsters.json'), 'utf8'));
  const resPath = res => path.join(repoRoot, res.replace(/^res:\/\//, ''));
  let checked = 0;
  const problems = [], notes = [], lines = [];
  const check = (ok, msg) => { checked++; if (!ok) problems.push(msg); return ok; };

  for (const id of Object.keys(EXPECT)) {
    const rig = rigs.rigs && rigs.rigs[id];
    if (!check(!!rig, `${id}: missing in hell_rigs.json`)) continue;
    const def = monsters.defs[id], attacks = Object.fromEntries(((def && def.stats && def.stats.attacks) || []).map(a => [a.id, a]));
    const [W, H] = rig.size || [0, 0];
    check(rig.family === 'drake', `${id}: family ${rig.family}, expected drake`);
    check(rig.variant === id.slice(-1), `${id}: variant ${rig.variant}, expected "${id.slice(-1)}"`);
    check(rig.scale === SCALE, `${id}: scale ${rig.scale}, expected ${SCALE} (5 world px per source px)`);
    check(rig.material === MATERIAL[id], `${id}: material ${rig.material}, expected ${MATERIAL[id]}`);
    check(W > 0 && H > 0, `${id}: size ${rig.size}`);
    const parts = rig.parts || [], byId = Object.fromEntries(parts.map(p => [p.id, p]));
    check(parts.length === new Set(parts.map(p => p.id)).size, `${id}: duplicate part ids`);
    const ids = parts.map(p => p.id).sort(), want = EXPECT[id].slice().sort();
    check(JSON.stringify(ids) === JSON.stringify(want), `${id}: parts [${ids}] differ from the contract [${want}]`);
    // images: frame-sized, not empty, not cut by the frame; flipbooks that flicker
    const img = {};
    for (const p of parts) {
      const files = p.frames || [p.img];
      check(!!p.img !== !!p.frames, `${id}.${p.id}: needs exactly one of img or frames`);
      if (p.frames) check(p.frames.length === 4, `${id}.${p.id}: flipbook has ${p.frames.length} frames, expected 4`);
      const loaded = [];
      for (const f of files) {
        const file = resPath(String(f));
        if (!check(fs.existsSync(file), `${id}.${p.id}: missing ${f}`)) continue;
        const im = decodePng(fs.readFileSync(file));
        check(im.w === W && im.h === H, `${id}.${p.id}: ${f} is ${im.w}x${im.h}, frame is ${W}x${H}`);
        check(opaqueCount(im) > 0, `${id}.${p.id}: ${f} is empty`);
        const cut = edgesTouched(im);
        check(!cut.length, `${id}.${p.id}: ${f} has opaque pixels on ${cut.join(', ')} (cut by the frame)`);
        loaded.push(im);
      }
      if (p.frames && loaded.length) {
        const distinct = new Set(loaded.map(im => Buffer.from(im.rgba).toString('base64'))).size;
        check(distinct >= MIN_DISTINCT_FRAMES, `${id}.${p.id}: only ${distinct} different flipbook frames, at least ${MIN_DISTINCT_FRAMES}`);
      }
      if (loaded.length) img[p.id] = union(loaded);
    }
    // hierarchy, pivots, layers
    const roots = parts.filter(p => p.parent === null);
    check(roots.length === 1 && roots[0].id === 'body', `${id}: the root must be body alone (got ${roots.map(p => p.id)})`);
    for (const p of parts) {
      check(p.parent === null || !!byId[p.parent], `${id}.${p.id}: parent ${p.parent} does not exist`);
      const seen = new Set();
      let q = p;
      while (q && q.parent !== null && !seen.has(q.id)) { seen.add(q.id); q = byId[q.parent]; }
      check(!q || q.parent === null, `${id}.${p.id}: parent chain loops`);
      const [px, py] = p.pivot || [];
      check(Number.isFinite(px) && Number.isFinite(py) && px >= 0 && py >= 0 && px <= W && py <= H, `${id}.${p.id}: pivot ${p.pivot} outside the ${W}x${H} frame`);
      check(Number.isInteger(p.z), `${id}.${p.id}: z ${p.z} is not an integer`);
      check(typeof p.label === 'string' && p.label.length > 0, `${id}.${p.id}: no label`);
      const flame = !!p.frames;
      if (img[p.id]) { const d = nearest(img[p.id], p.pivot); check(d <= (flame ? 6 : 2.5), `${id}.${p.id}: pivot ${p.pivot} is ${d.toFixed(1)} px from the part`); }
      if (p.parent && img[p.parent] && !flame) { const d = nearest(img[p.parent], p.pivot); check(d <= 3, `${id}.${p.id}: pivot ${p.pivot} is ${d.toFixed(1)} px from its parent ${p.parent}`); }
      if (p.disables !== undefined) check(Array.isArray(p.disables), `${id}.${p.id}: disables must be an array`);
    }
    // HP weights (PART-05)
    const total = parts.reduce((s, p) => s + (p.hp || 0), 0);
    const severable = parts.filter(p => p.hp > 0 && !p.unbreakable), sevSum = severable.reduce((s, p) => s + p.hp, 0);
    check(total > 0, `${id}: total HP weight is 0`);
    for (const p of severable) check(p.hp / total >= .08 - 1e-9 && p.hp / total <= .20 + 1e-9, `${id}.${p.id}: ${(p.hp / total * 100).toFixed(1)} % of the form, expected 8-20 %`);
    check(sevSum / total <= .60 + 1e-9, `${id}: severable parts hold ${(sevSum / total * 100).toFixed(1)} %, at most 60 %`);
    const unbreakable = parts.filter(p => p.unbreakable).sort((a, b) => b.hp - a.hp);
    check(unbreakable.length && unbreakable[0].id === 'body', `${id}: body must hold the largest unbreakable share (largest is ${unbreakable[0] && unbreakable[0].id})`);
    for (const p of parts) {
      check(p.hp >= 0, `${id}.${p.id}: negative hp`);
      check(!!p.unbreakable !== severable.includes(p) || p.hp === 0, `${id}.${p.id}: must be either unbreakable or severable`);
      if (p.hp === 0) check(!!p.unbreakable, `${id}.${p.id}: decorative parts (hp 0) must be unbreakable`);
    }
    // a hit must be able to land on every severable part (its own pixels in front of the others)
    const visible = visiblePixels(parts, img, W, H);
    for (const p of severable) check(visible[p.id] >= MIN_VISIBLE, `${id}.${p.id}: ${visible[p.id]} px can be hit, at least ${MIN_VISIBLE}`);
    // effects (PART-01): every severable part does something, every attack id exists
    const groups = rig.groups || {};
    for (const p of severable) {
      const inGroup = p.group && groups[p.group] && (groups[p.group].disables || []).length;
      check((p.disables && p.disables.length) || (p.weakens && Object.keys(p.weakens).length) || inGroup, `${id}.${p.id}: severable without an effect`);
    }
    for (const p of parts) {
      for (const a of p.disables || []) check(!!attacks[a], `${id}.${p.id}: disables unknown attack ${a}`);
      for (const a in p.weakens || {}) {
        if (!check(!!attacks[a], `${id}.${p.id}: weakens unknown attack ${a}`)) continue;
        for (const k in p.weakens[a]) {
          const factor = p.weakens[a][k];
          check(typeof factor === 'number' && factor >= 0 && factor <= .7 + 1e-9, `${id}.${p.id}: ${a}.${k} x${factor}, a loss must cut at least 30 %`);
          if (!(k in attacks[a])) notes.push(`${id}.${p.id}: ${a}.${k} is not in the attack's data in hell_monsters.json (the game's default applies)`);
        }
      }
      if (p.exposed) check(!!attacks[p.exposed], `${id}.${p.id}: exposed by unknown attack ${p.exposed}`);
      for (const x of p.alsoDetach || []) {
        if (!check(!!byId[x], `${id}.${p.id}: alsoDetach ${x} does not exist`)) continue;
        check(byId[x].hp >= 1, `${id}.${p.id}: alsoDetach ${x} needs hp >= 1 to leave the body`);
        let q = byId[x];
        while (q && q.parent && q.parent !== p.id) q = byId[q.parent];
        check(q && q.parent === p.id, `${id}.${p.id}: alsoDetach ${x} does not hang below ${p.id}`);
      }
      if (p.group) check(!!groups[p.group] && groups[p.group].parts.includes(p.id), `${id}.${p.id}: group ${p.group} does not list it`);
    }
    for (const g in groups) {
      for (const m of groups[g].parts || []) {
        if (!check(!!byId[m] && byId[m].group === g, `${id}: group ${g} member ${m} missing or not tagged`)) continue;
        // RigLibrary only lists parts with hp > 0 as losable: a member with hp 0 would keep the group alive forever
        check(byId[m].hp >= 1, `${id}: group ${g} member ${m} needs hp >= 1 to be lost`);
      }
      for (const a of groups[g].disables || []) check(!!attacks[a], `${id}: group ${g} disables unknown attack ${a}`);
    }
    // wings: flap +-1 matching the side their membrane spreads to, swing [lo <= 0 <= hi] within +-pi
    for (const p of parts) {
      const wing = WINGS.includes(p.id);
      if (!wing && p.flap === undefined && p.swing === undefined) continue;
      if (!check(wing, `${id}.${p.id}: flap/swing are wing fields`)) continue;
      check(p.flap === 1 || p.flap === -1, `${id}.${p.id}: flap ${p.flap}, expected 1 or -1`);
      const s = p.swing;
      if (!check(Array.isArray(s) && s.length === 2 && s.every(Number.isFinite), `${id}.${p.id}: swing ${JSON.stringify(s)} is not [lo, hi]`)) continue;
      check(s[0] >= -Math.PI && s[0] <= 0 && s[1] >= 0 && s[1] <= Math.PI, `${id}.${p.id}: swing [${s}] must hold 0 within +-pi`);
      if (img[p.id]) {
        let sx = 0, n = 0;
        for (let i = 0; i < W * H; i++) if (img[p.id].rgba[i * 4 + 3]) { sx += i % W + .5; n++; }
        check((sx / n > p.pivot[0] + 8) === (p.flap === -1), `${id}.${p.id}: flap ${p.flap} but the membrane's middle lies ${(sx / n - p.pivot[0]).toFixed(1)} px from the pivot`);
      }
    }
    // points, ground, width
    for (const name in POINTS) {
      const pt = (rig.points || {})[name];
      if (!check(!!pt, `${id}: point ${name} missing`)) continue;
      check(pt.part === POINTS[name], `${id}: point ${name} on ${pt.part}, expected ${POINTS[name]}`);
      check(pt.at[0] >= 0 && pt.at[1] >= 0 && pt.at[0] <= W && pt.at[1] <= H, `${id}: point ${name} ${pt.at} outside the frame`);
      if (img[pt.part]) { const d = nearest(img[pt.part], pt.at); check(d <= 3, `${id}: point ${name} ${pt.at} is ${d.toFixed(1)} px from ${pt.part}`); }
    }
    const [gx, gy] = rig.ground || [];
    check(gx >= 0 && gx <= W && gy >= 0 && gy < H, `${id}: ground ${rig.ground} outside the frame`);
    if (img.leg_far && img.leg_near) { const d = Math.min(nearest(img.leg_far, [gx, gy + .5]), nearest(img.leg_near, [gx, gy + .5])); check(d <= 2, `${id}: ground ${rig.ground} is ${d.toFixed(1)} px from the feet`); }
    check(rig.width > 0 && rig.width <= W, `${id}: width ${rig.width}`);
    lines.push(`${id}: ${parts.length} parts, ${W}x${H}, total ${total}, severable ${severable.map(p => `${p.id} ${p.hp} (${visible[p.id]} px)`).join(', ')} (${(sevSum / total * 100).toFixed(1)} %)`);
  }
  return { checked, problems, notes, lines };
}

// ---------- main ----------
module.exports = { buildForm, preview, checkRigs, FORMS, PARENT, Z };
if (require.main === module) main();
function main() {
  if (CHECK) {
    const r = checkRigs(root);
    for (const l of r.lines) console.log(l);
    for (const n of r.notes) console.log('note: ' + n);
    for (const p of r.problems) console.log('PROBLEM: ' + p);
    console.log(`HELL_RIGS checked=${r.checked} failures=${r.problems.length}`);
    process.exit(r.problems.length ? 1 : 0);
  }
  const data = {
    _note: 'Generated by tools/hell_dungeon/export_rigs.js from drake_hybrid.js (drake rest pose, one PNG per part); do not edit by hand. Coordinates are source px in the full frame, facing right.',
    rigs: {},
  };
  const previewDir = path.join(root, 'production', 'qa', 'evidence', 'hell-rigs');
  for (const p of [1, 2, 3, 4]) {
    const form = buildForm(p), dir = path.join(outDir, form.id);
    fs.mkdirSync(dir, { recursive: true });
    // part files of this form that the rig no longer lists (a renamed or removed part, a part
    // that switched between one image and a flipbook) go, with Godot's .import files
    const keep = new Set();
    for (const e of form.rig.parts) for (const f of e.frames || [e.img]) keep.add(path.basename(f));
    for (const name of fs.readdirSync(dir)) {
      const png = name.endsWith('.png.import') ? name.slice(0, -'.import'.length) : name;
      if (png.endsWith('.png') && !keep.has(png)) { fs.unlinkSync(path.join(dir, name)); console.log('removed stale', path.join(form.id, name)); }
    }
    for (const e of form.rig.parts) {
      const frames = form.images[e.id];
      if (frames.length > 1) frames.forEach((img, f) => fs.writeFileSync(path.join(dir, `${e.id}_${f}.png`), encodePng(form.W, form.H, img)));
      else fs.writeFileSync(path.join(dir, `${e.id}.png`), encodePng(form.W, form.H, frames[0]));
    }
    data.rigs[form.id] = form.rig;
    if (PREVIEW) { fs.mkdirSync(previewDir, { recursive: true }); preview(form, path.join(previewDir, `preview_${form.id}.png`)); }
    console.log(form.id, form.rig.parts.length, 'parts ->', dir);
  }
  fs.mkdirSync(path.join(root, 'assets', 'data'), { recursive: true });
  fs.writeFileSync(path.join(root, 'assets', 'data', 'hell_rigs.json'), JSON.stringify(data, null, 1) + '\n');
  console.log('rigs -> assets/data/hell_rigs.json' + (PREVIEW ? ', previews -> ' + previewDir : ''));
}

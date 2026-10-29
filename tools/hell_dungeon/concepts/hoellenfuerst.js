// Concept "Höllenfürst" for Ignaroth (all four forms), a preview only: nothing here is wired into
// the game. A hulking, low-slung brute: massive shoulders and forelimbs, chest close to the ground,
// the head lowered and thrust forward with burning eyes, a crown of horns that grows each form,
// cracked armour plates with lava (form 4: violet and gold) glowing through, smoke and embers
// rising from the back, a short heavy tail that ends in a spiked club from form 3 on.
//
// Same palettes as hell_monsters.js DRAKE (hide/belly/fire/horn/claw/wingMat/coreMat/tuskMat per
// form), widened to 4-5 tones per material with a few derived shades (DERIVED below) for depth:
// the far limbs and the far wing use a darker, cooler ramp, the near side a warmer one, every mass
// is shaded from a height field (light from the top left like the 0x72 pack) with a warm rim from
// the lava below (form 4: void violet).
//
// Rig compatible: every draw call is tagged with the part ids of export_rigs.js (P.part) and every
// pivot and point is recorded (P.joint), so a part renders isolated with its own outline. The
// previews here are composed exactly like the rig export does it: each part rendered alone, outlines
// skipped on the SEAMLESS joints, stacked by the rig's Z order.
//
// Usage: node tools/hell_dungeon/concepts/hoellenfuerst.js [repo_root]
//   writes production/qa/evidence/drake-concepts/hoellenfuerst_{lineup,form4,ingame,ingame_form3,parts4}.png
//   and prints frame sizes and a small rig check (pivots, frame edges, visible px of severable parts).
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const HM = require('../hell_monsters.js');
const { Painter, hexToRgb } = HM;

const ROOT = process.argv[2] || path.join(__dirname, '..', '..', '..');
const OUT = path.join(ROOT, 'production', 'qa', 'evidence', 'drake-concepts');
const KEY = 'hoellenfuerst';

// ---------- palette: hell_monsters.js colours (0x72 DungeonTileset II) ----------
const K = '#222222', BLK = '#0e0c0c', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a';
const RED = '#da4e38', CRIM = '#9f294e', MAROON = '#62232f', PLUM = '#38262d', PURP = '#5f2d56', MAG = '#993970';
const PINK = '#dc4a7b', LILAC = '#f0b3dd', VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579';
const YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025', BROWN = '#8f4029';
const MUD = '#775c55', STONE = '#483b3a', COAL = '#3b3332', SOOT = '#302c2b', NEARBLK = '#2b2929';
const FIRE = [WHITE, YEL, ORA, RED, CRIM];
const VOIDFIRE = [LILAC, VIO, VIOD, PURP, INDIGO];
// DERIVED: darker / cooler steps of the palette above, only for depth (deep shadow, far side, sheen)
const EMBDK = '#4f201d';   // below BROWN (form 1 hide shadow)
const EMBFAR = '#6b2d24';  // BROWN pulled towards MAROON (form 1 far side)
const PLUMDK = '#26181f';  // below PLUM (forms 2-3 deep shadow, far side)
const CRIMFAR = '#7d2440'; // between MAROON and CRIM (far side mid tone)
const OBSDK = '#1b1719';   // below SOOT (obsidian deep shadow)
const OBSFAR = '#25212b';  // cool obsidian (far side)
const OBSHI = '#8f7d93';   // violet sheen on obsidian (glass highlight)
const BONEDK = '#5a4744';  // charred horn root, between STONE and MUD

// Materials per form, 5 tones each, dark -> light (index 2 is the base tone).
const PAL = {
  1: { hide: [MAROON, EMBDK, BROWN, BORA, ORA], far: [PLUM, MAROON, EMBDK, EMBFAR, BROWN], plate: [PLUM, MAROON, EMBDK, BROWN, BORA],
    belly: [BROWN, BORA, ORA, YEL, WHITE], rim: YEL, rimFar: ORA, horn: [BONEDK, MUD, TAN, BONE, WHITE], claw: [BONEDK, TAN, BONE, WHITE, WHITE],
    crack: [RED, ORA, YEL, WHITE], halo: BORA, fire: FIRE, smoke: [COAL, STONE], ember: [ORA, YEL], eye: [ORA, YEL, WHITE], mouth: [PLUM, MAROON, CRIM] },
  2: { hide: [PLUM, MAROON, CRIM, RED, ORA], far: [PLUMDK, PLUM, MAROON, CRIMFAR, CRIM], plate: [PLUMDK, PLUM, MAROON, CRIM, RED],
    belly: [BROWN, BORA, ORA, YEL, WHITE], rim: ORA, rimFar: RED, horn: [BONEDK, MUD, TAN, BONE, WHITE], claw: [BONEDK, TAN, BONE, WHITE, WHITE],
    crack: [RED, ORA, YEL, WHITE], halo: RED, fire: FIRE, smoke: [COAL, STONE], ember: [ORA, YEL], eye: [ORA, YEL, WHITE], mouth: [PLUMDK, PLUM, MAROON] },
  3: { hide: [PLUMDK, PLUM, MAROON, CRIM, RED], far: [PLUMDK, PLUMDK, PLUM, MAROON, CRIMFAR], plate: [PLUMDK, PLUMDK, PLUM, MAROON, CRIM],
    belly: [BROWN, BORA, ORA, YEL, WHITE], rim: ORA, rimFar: RED, horn: [BONEDK, MUD, TAN, BONE, WHITE], claw: [BONEDK, TAN, BONE, WHITE, WHITE],
    wing: [PLUMDK, PLUM, MAROON, CRIM, RED], wingFar: [PLUMDK, PLUMDK, PLUM, MAROON, CRIMFAR], wingRim: RED, wingBone: [PLUMDK, PLUM, MAROON, CRIM, RED],
    crack: [RED, ORA, YEL, WHITE], halo: CRIM, fire: FIRE, smoke: [COAL, STONE], ember: [ORA, YEL], eye: [ORA, YEL, WHITE], mouth: [PLUMDK, PLUM, MAROON],
    gland: [MAROON, CRIM, BORA, ORA, YEL] },
  4: { hide: [OBSDK, SOOT, COAL, STONE, OBSHI], far: [BLK, OBSDK, OBSFAR, SOOT, COAL], plate: [BLK, OBSDK, NEARBLK, COAL, OBSHI],
    belly: [INDIGO, PURP, MAG, VIO, LILAC], rim: VIOD, rimFar: INDIGO, horn: [BROWN, BORA, ORA, YEL, WHITE], claw: [BROWN, BORA, ORA, YEL, WHITE],
    wing: [OBSDK, INDIGO, PURP, MAG, VIO], wingFar: [BLK, OBSDK, INDIGO, PURP, MAG], wingRim: VIO, wingBone: [OBSDK, SOOT, STONE, MUD, OBSHI],
    crack: [VIOD, VIO, LILAC, WHITE], crack2: [BORA, ORA, YEL, WHITE], halo: PURP, fire: VOIDFIRE, smoke: [OBSDK, SOOT], ember: [VIO, YEL],
    eye: [ORA, YEL, WHITE], mouth: [BLK, OBSDK, PURP], gland: [PURP, MAG, PINK, LILAC, WHITE], crystal: [INDIGO, VIOD, VIO, LILAC, WHITE] },
};
// One step darker for every ramp colour (cast shadows inside a part).
const DARKER = {};
for (const p in PAL) for (const k in PAL[p]) { const r = PAL[p][k]; if (Array.isArray(r)) for (let i = r.length - 1; i > 0; i--) if (!DARKER[r[i]] && r[i] !== r[i - 1]) DARKER[r[i]] = r[i - 1]; }

// ---------- the four forms: size and proportions ----------
// s: source px per design unit (horizontal), hb: vertical factor of the body, hump: height of the
// shoulder hump (the salamander is flat), hs: head size, tail: tail length, ws: wing size,
// crown: 0 warts, 1 horn nubs, 2 horn crown, 3 golden crown; spikes: dorsal spike size class.
const FORMS = {
  1: { name: 'Salamander', s: 1.3, hb: .86, hump: .5, hs: 1.15, tail: 1.02, crown: 0, wings: false, club: false, spikes: 0, plates: false, tusks: false, crystals: false },
  2: { name: 'Jungdrache', s: 1.42, hb: .95, hump: .85, hs: 1.22, tail: 1.0, crown: 1, wings: false, club: false, spikes: 1, plates: true, tusks: true, crystals: false },
  3: { name: 'Glutdrache', s: 1.45, hb: 1, hump: 1, hs: 1.3, tail: .95, ws: .76, crown: 2, wings: true, club: true, spikes: 2, plates: true, tusks: true, crystals: false },
  4: { name: 'Obsidianform', s: 1.64, hb: 1.04, hump: 1.08, hs: 1.36, tail: .9, ws: .9, crown: 3, wings: true, club: true, spikes: 3, plates: true, tusks: true, crystals: true },
};
// The rig layout of export_rigs.js (same ids, parents, Z order, seamless joints, flipbooks).
const PARENT = {
  body: null, neck: 'body', head: 'neck', jaw: 'head', arm: 'body', leg_far: 'body', leg_near: 'body',
  tail_1: 'body', tail_2: 'tail_1', tail_3: 'tail_2', tail_4: 'tail_3', tail_5: 'tail_4', tail_flame: 'tail_5',
  wing_far: 'body', wing_near: 'body', throat: 'neck', horns: 'head',
  crystal_1: 'body', crystal_2: 'body', crystal_3: 'body', mouth_flame: 'jaw',
};
const Z = {
  wing_far: 1, tail_5: 2, tail_4: 3, tail_3: 4, tail_1: 5, tail_2: 6, tail_flame: 7, leg_far: 8, body: 10,
  leg_near: 11, wing_near: 12, neck: 13, crystal_1: 14, crystal_2: 14, crystal_3: 14, arm: 15, throat: 16, jaw: 17, head: 18,
  horns: 19, mouth_flame: 20,
};
const FLIPBOOK = new Set(['tail_flame', 'mouth_flame']);
const SEAMLESS = [['body', 'neck'], ['neck', 'head'], ['body', 'tail_1'], ['tail_1', 'tail_2'], ['tail_2', 'tail_3'], ['tail_3', 'tail_4'], ['tail_4', 'tail_5']];
const EXPECT = {
  1: ['body', 'neck', 'head', 'jaw', 'arm', 'leg_far', 'leg_near', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_5', 'tail_flame'],
  2: ['body', 'neck', 'head', 'jaw', 'arm', 'leg_far', 'leg_near', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_5', 'tail_flame'],
  3: ['body', 'neck', 'head', 'jaw', 'arm', 'leg_far', 'leg_near', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_5', 'tail_flame', 'wing_far', 'wing_near', 'throat', 'horns'],
  4: ['body', 'neck', 'head', 'jaw', 'arm', 'leg_far', 'leg_near', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_5', 'tail_flame', 'wing_far', 'wing_near', 'throat', 'horns', 'crystal_1', 'crystal_2', 'crystal_3', 'mouth_flame'],
};
// Severable parts per form (export_rigs.js FORMS[p].cut): a hit needs MIN_VISIBLE px of each.
const SEVERABLE = { 1: ['jaw', 'arm', 'tail_2'], 2: ['jaw', 'tail_2', 'arm'], 3: ['wing_far', 'wing_near', 'throat', 'horns'], 4: ['crystal_1', 'crystal_2', 'crystal_3', 'wing_far', 'wing_near', 'throat', 'horns'] };
const MIN_VISIBLE = 20;

// ---------- shapes: { f(x, y) inside test at pixel centres, box [x0, y0, x1, y1] } ----------
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const lerp2 = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t)];
function ell(cx, cy, rx, ry, ang) {
  const c = Math.cos(ang || 0), sn = Math.sin(ang || 0), r = Math.max(rx, ry);
  return { f: (x, y) => { const u = (x - cx) * c + (y - cy) * sn, v = (y - cy) * c - (x - cx) * sn; return (u / rx) ** 2 + (v / ry) ** 2 <= 1; }, box: [cx - r, cy - r, cx + r, cy + r] };
}
// A capsule from a to b whose radius runs from ra to rb.
function cap(a, b, ra, rb) {
  const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy || 1, r = Math.max(ra, rb);
  return { f: (x, y) => { const t = clamp(((x - a[0]) * dx + (y - a[1]) * dy) / l2, 0, 1); return Math.hypot(x - a[0] - dx * t, y - a[1] - dy * t) <= ra + (rb - ra) * t; },
    box: [Math.min(a[0], b[0]) - r, Math.min(a[1], b[1]) - r, Math.max(a[0], b[0]) + r, Math.max(a[1], b[1]) + r] };
}
function poly(pts) {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  return { f: (x, y) => { let c = false; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) { const [xi, yi] = pts[i], [xj, yj] = pts[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c; } return c; },
    box: [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)] };
}
// A smooth closed outline through pts (Catmull-Rom, n samples per span), as a polygon shape.
function blob(pts, n) {
  n = n || 6;
  const out = [], L = pts.length;
  for (let i = 0; i < L; i++) {
    const p0 = pts[(i - 1 + L) % L], p1 = pts[i], p2 = pts[(i + 1) % L], p3 = pts[(i + 2) % L];
    for (let k = 0; k < n; k++) {
      const t = k / n, t2 = t * t, t3 = t2 * t;
      out.push([0, 1].map(j => .5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)));
    }
  }
  return poly(out);
}
function union(...sh) {
  sh = sh.filter(Boolean);
  return { f: (x, y) => sh.some(s => s.f(x, y)), box: [Math.min(...sh.map(s => s.box[0])), Math.min(...sh.map(s => s.box[1])), Math.max(...sh.map(s => s.box[2])), Math.max(...sh.map(s => s.box[3]))] };
}
const minus = (a, ...b) => ({ f: (x, y) => a.f(x, y) && !b.some(s => s.f(x, y)), box: a.box });
const clip = (a, test) => ({ f: (x, y) => a.f(x, y) && test(x, y), box: a.box });
// A tapered tube along a polyline (radius r0 -> r1), as one shape.
function tube(pts, r0, r1) {
  const sh = [];
  for (let i = 0; i < pts.length - 1; i++) sh.push(cap(pts[i], pts[i + 1], lerp(r0, r1, i / (pts.length - 1)), lerp(r0, r1, (i + 1) / (pts.length - 1))));
  return union(...sh);
}
// Points on a cubic bezier.
function bez(p0, p1, p2, p3, n) {
  const out = [];
  for (let i = 0; i <= n; i++) { const t = i / n, u = 1 - t; out.push([u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0], u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]]); }
  return out;
}
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// ---------- volume shading ----------
const norm3 = (x, y, z) => { const l = Math.hypot(x, y, z) || 1; return [x / l, y / l, z / l]; };
const KEY_L = norm3(-.55, -.78, .42), RIM_L = norm3(.18, 1, -.05);
// Fills a shape from a height field (distance to its edge, a round profile), lit from the top left;
// edges that face down get the rim colour (lava light from below). opt: rim, rimW, ink (outline
// where this shape lies over earlier pixels of the same part), cast (darkens earlier pixels below
// right of the shape), flat (larger = flatter), bias [x, y] (tilts the normals), lift (tone offset),
// tex (function(x, y, tone) -> tone), ground (no pixel below this row).
function vol(P, shape, ramp, opt) {
  if (!P.keep()) return;
  opt = opt || {};
  const x0 = Math.floor(shape.box[0]) - 2, y0 = Math.floor(shape.box[1]) - 2, x1 = Math.ceil(shape.box[2]) + 2, y1 = Math.ceil(shape.box[3]) + 2;
  const gw = x1 - x0 + 1, gh = y1 - y0 + 1, n = gw * gh, gy = P.ground == null ? 1e9 : P.ground;
  const inn = new Uint8Array(n), d = new Float32Array(n);
  for (let y = 0; y < gh; y++) for (let x = 0; x < gw; x++) if (y0 + y <= gy && shape.f(x0 + x + .5, y0 + y + .5)) inn[y * gw + x] = 1;
  for (let i = 0; i < n; i++) d[i] = inn[i] ? 1e9 : 0;
  const D = Math.SQRT2;
  for (let y = 1; y < gh - 1; y++) for (let x = 1; x < gw - 1; x++) { const i = y * gw + x; if (!inn[i]) continue; d[i] = Math.min(d[i], d[i - 1] + 1, d[i - gw] + 1, d[i - gw - 1] + D, d[i - gw + 1] + D); }
  for (let y = gh - 2; y > 0; y--) for (let x = gw - 2; x > 0; x--) { const i = y * gw + x; if (!inn[i]) continue; d[i] = Math.min(d[i], d[i + 1] + 1, d[i + gw] + 1, d[i + gw + 1] + D, d[i + gw - 1] + D); }
  let R = 1;
  for (let i = 0; i < n; i++) if (inn[i]) R = Math.max(R, d[i]);
  R = Math.max(1, R * (opt.round || .7));
  if (opt.R) R = Math.min(R, opt.R);
  const H = i => { if (!inn[i]) return 0; const t = Math.min(1, d[i] / R); return R * Math.sqrt(1 - (1 - t) * (1 - t)); };
  const flat = opt.flat || 1, bias = opt.bias || [0, 0], last = ramp.length - 1, cast = [];
  for (let y = 1; y < gh - 1; y++) for (let x = 1; x < gw - 1; x++) {
    const i = y * gw + x;
    if (!inn[i]) continue;
    const nv = norm3(-(H(i + 1) - H(i - 1)) / 2 + bias[0], -(H(i + gw) - H(i - gw)) / 2 + bias[1], flat);
    const diff = nv[0] * KEY_L[0] + nv[1] * KEY_L[1] + nv[2] * KEY_L[2];
    let tone = diff < -.3 ? 0 : diff < .2 ? 1 : diff < .64 ? 2 : diff < .86 ? 3 : 4;
    if (ramp.length === 4) tone = Math.min(3, Math.round(tone * .75));
    tone = clamp(tone + (opt.lift || 0), 0, last);
    const X = x0 + x, Y = y0 + y;
    if (opt.tex) tone = clamp(opt.tex(X, Y, tone, d[i]), 0, last);
    let c = ramp[tone];
    const rimDot = nv[0] * RIM_L[0] + nv[1] * RIM_L[1] + nv[2] * RIM_L[2];
    if (opt.rim && d[i] <= (opt.rimW || 1.5) && rimDot > (opt.rimT || .42)) c = opt.rim;
    if (opt.ink) {
      const edge = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => !inn[i + dx + dy * gw] && P.inside(X + dx, Y + dy) && P.solid[(Y + dy) * P.w + X + dx]);
      if (edge) c = opt.ink === true ? ramp[0] : opt.ink;
    }
    if (opt.cast) for (const [dx, dy] of opt.cast === true ? [[1, 1]] : opt.cast) { const j = i + dx + dy * gw; if (!inn[j]) cast.push([X + dx, Y + dy]); }
    P.dot(X, Y, c);
  }
  for (const [X, Y] of cast) { if (!P.inside(X, Y)) continue; const k = Y * P.w + X, c = P.solid[k]; if (c && DARKER[c]) P.solid[k] = DARKER[c]; }
}
// A glowing crack along pts: drawn only over pixels of this part, white-hot in the middle of its
// length, cooler towards the ends; halo tints the pixels next to it.
function crack(P, pts, pal, halo) {
  if (!P.keep()) return;
  const px = [];
  for (let i = 0; i < pts.length - 1; i++) {
    let [x0, y0] = pts[i].map(Math.round), [x1, y1] = pts[i + 1].map(Math.round);
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    for (;;) { px.push([x0, y0]); if (x0 === x1 && y0 === y1) break; const e2 = 2 * err; if (e2 >= dy) { err += dy; x0 += sx; } if (e2 <= dx) { err += dx; y0 += sy; } }
  }
  const seen = new Set(), on = [];
  px.forEach(([x, y], k) => { const key = x + ',' + y; if (seen.has(key) || !P.inside(x, y) || !P.solid[y * P.w + x]) return; seen.add(key); on.push([x, y, k / Math.max(1, px.length - 1)]); });
  if (halo) for (const [x, y] of on) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const X = x + dx, Y = y + dy; if (P.inside(X, Y) && P.solid[Y * P.w + X] && !seen.has(X + ',' + Y)) P.solid[Y * P.w + X] = halo; }
  for (const [x, y, u] of on) { const m = 1 - Math.abs(u - .5) * 2; P.dot(x, y, m > .7 ? pal[3] : m > .4 ? pal[2] : m > .15 ? pal[1] : pal[0]); }
}
// A jagged crack path: a random walk from (x, y) heading ang, length len px, with one branch.
function jag(x, y, ang, len, seed) {
  const r = rng(seed), pts = [[x, y]];
  let a = ang, cx = x, cy = y;
  for (let l = 0; l < len; l += 2) { a += (r() - .5) * 1.3; cx += Math.cos(a) * 2; cy += Math.sin(a) * 2; pts.push([cx, cy]); }
  return pts;
}

// ---------- the dragon ----------
// Draws form p in its rest pose on painter P (frame f drives the flames). The ground is the
// painter's bottom row; ox is the x of the design origin (between hips and shoulders).
function hoellenfuerst(P, p, f, ox) {
  const F = FORMS[p], C = PAL[p], s = F.s, sy = s * F.hb, G = P.h - 1;
  P.ground = G;
  const big = p >= 3, obs = p === 4, hk = F.hump;
  // the hump: everything above v = -24 is stretched by hk (the salamander is flat-backed)
  const hv = v => (v < -24 ? -24 + (v + 24) * hk : v);
  const X = u => ox + u * s, Y = v => G + hv(v) * sy, pt = (u, v) => [X(u), Y(v)];
  const B = (pts, n) => blob(pts.map(q => pt(...q)), n);
  // scale texture: a staggered pattern of darker scale edges on the mid tones
  const tex = (seed, amt) => (x, y, tone) => {
    const row = Math.floor(y / 2), col = Math.floor((x + (row % 2) * 2) / 4);
    if (tone >= 1 && tone <= 3 && y % 2 === 0 && (x + (row % 2) * 2) % 4 === 0 && ((col * 7 + row * 3 + seed) % 5) < amt) return tone - 1;
    return tone;
  };
  const spike = (b, ang, L, r, ramp, cast) => vol(P, cap(b, [b[0] + Math.cos(ang) * L, b[1] + Math.sin(ang) * L], Math.max(1, r), .3), ramp || C.horn, { ink: true, cast: cast ? true : undefined, rim: C.rim, rimT: .7 });

  // --- skeleton (design units; up is negative) ---
  const torsoPts = [[-21, -14.5], [-17.5, -20.5], [-10, -23.2], [-3, -25.2], [1.5, -30], [6, -33.5], [11, -31.5], [15.5, -26], [18, -18], [16.5, -10.5], [10, -7.5], [2, -8.6], [-6, -8.4], [-14, -9.2], [-19.5, -10.8]];
  const torso = B(torsoPts, 8);
  const contour = x => { let top = null, bot = null; for (let y = 0; y < P.h; y++) if (torso.f(x + .5, y + .5)) { if (top === null) top = y; bot = y; } return [top, bot]; };
  const far = [3.2, -2.6];   // far limbs: up and a little forward (the body is turned slightly towards us)
  const tl = F.tail;
  const tailPts = [[-17, -15.5], [-23.5, -12], [-28.5 * tl, -7.5], [-32 * tl - 1, -4.6], [-35.5 * tl - 1.5, -3.2], [-39.5 * tl - 1.5, -3.6], [-42.5 * tl - 1.5, -5.6]];
  const tailR = [6, 5.1, 4.3, 3.6, 3, 2.5, 2.2];
  const hs = F.hs, headC = [24 + (hs - 1) * 5, -15.5 + (1 - hk) * 3];
  const H = (u, v) => [X(headC[0]) + u * hs * s, G + hv(headC[1]) * sy + v * hs * s];  // head-local units
  const HB = (pts, n) => blob(pts.map(q => H(...q)), n);
  const HS = r => r * hs * s;

  // ===== wing_far (Z 1): raised higher, darker and cooler =====
  if (F.wings) {
    const root = [X(.5 + far[0]), Y(-28.5) + far[1] * s];
    P.part('wing_far').joint('wing_far', root[0], root[1] + 1.5);
    wing(P, root, s * F.ws, .1, C.wingFar, C.wingFar, C.rimFar, C, true, obs);
  }

  // ===== tail (Z 2-7): five parts, thick and short, sweeping down to the floor =====
  {
    const seg = [[0, 1], [1, 3], [3, 4], [4, 5], [5, 6]];
    const tp = tailPts.map(q => pt(...q)), k1 = p === 1 ? .8 : 1;
    seg.forEach(([a, b], k) => {
      const id = 'tail_' + (k + 1);
      P.part(id).joint(id, tp[a][0], tp[a][1]);
      const pts = tp.slice(a, b + 1), rr = tailR.slice(a, b + 1).map(r => r * s * k1);
      vol(P, union(...pts.slice(0, -1).map((q, i) => cap(q, pts[i + 1], rr[i], rr[i + 1]))), C.hide, { rim: C.rim, rimT: .5, tex: tex(k, 2) });
      for (let i = 0; i < pts.length - 1; i++) {
        const m = lerp2(pts[i], pts[i + 1], .5), r = lerp(rr[i], rr[i + 1], .5), top = [m[0], m[1] - r + 1];
        if (F.spikes) spike(top, -2.1, r * (F.spikes >= 2 ? 1.25 : .9), r * .36, C.horn);
        else P.dot(top[0], top[1] + 1, C.crack[2]).dot(top[0] + 1, top[1] + 1, C.crack[1]);
      }
      if (k < 3) { const m = lerp2(pts[0], pts[pts.length - 1], .5), r = rr[0]; crack(P, jag(m[0] + r * .4, m[1] - r * .55, 2.0, r * 1.2, 31 + k * 7 + p), C.crack, C.halo); }
    });
    const end = tp[6], rEnd = tailR[6] * s;
    if (F.club) {
      // the club: a knot of armour with spikes, part of tail_5; it burns (tail_flame)
      P.part('tail_5');
      const cr = rEnd * (obs ? 2.3 : 2.05), cc = [end[0] - cr * .3, end[1] - cr * .15];
      vol(P, blob([[-1.1, .1], [-.7, -.8], [.2, -.95], [1, -.4], [1.05, .5], [.2, .95], [-.8, .7]].map(([u, v]) => [cc[0] + u * cr, cc[1] + v * cr])), C.plate, { rim: C.rim, ink: true, round: .9 });
      for (const [a, len] of obs ? [[-2.65, 1.2], [-2, 1.05], [-1.3, 1.05], [-.55, .8], [2.75, .8], [3.45, .65]] : [[-2.5, 1.05], [-1.75, .95], [-1, .9], [2.8, .75]]) {
        const b = [cc[0] + Math.cos(a) * cr * .82, cc[1] + Math.sin(a) * cr * .75];
        spike(b, a, cr * len, cr * .3, C.horn);
      }
      crack(P, jag(cc[0] + cr * .5, cc[1] - cr * .2, 2.6, cr * 1.6, 77 + p), C.crack, C.halo);
      P.joint('tail_tip', cc[0], cc[1]);
      P.part('tail_flame').joint('tail_flame', cc[0], cc[1] - cr * .6);
      P.flame(cc[0] - cr * .9, cc[1] - cr * .3, Math.round(cr * 1.8), Math.round(cr * (obs ? 2.6 : 2.3)), { seed: 3, pal: C.fire, front: true, lean: -2 });
    } else {
      P.joint('tail_tip', end[0], end[1]);
      P.part('tail_flame').joint('tail_flame', end[0], end[1] - 1);
      const fw = p === 1 ? 6 : 7, fh = p === 1 ? 10 : 12;
      P.flame(end[0] - fw / 2, end[1] + 1, fw, fh, { seed: 3, pal: C.fire, front: true, lean: -2 });
    }
  }

  // limbs: o = offset of the far side (design units), ramp/rim per side, k = size
  const hindLeg = (o, ramp, rim, k) => {
    const q = (u, v) => [X(u + o[0]), Y(v) + o[1] * s], g = G + o[1] * s * .5;
    const hp = q(-12, -16), knee = q(-7.6, -8.4), ank = [q(-13.2, 0)[0], g - 3.2 * sy * k], foot = [q(-10.4, 0)[0], g - 1.5 * sy * k];
    vol(P, cap(knee, ank, 3.4 * s * k, 2.5 * s * k), ramp, { rim, tex: tex(5, 2) });
    vol(P, ell(foot[0], foot[1], 4.4 * s * k, 1.9 * sy * k), ramp, { rim, ink: true });
    for (let t = 0; t < 3; t++) { const b = [foot[0] + (1.5 + t * 1.15) * s * k, foot[1] + .2 * sy]; vol(P, cap(b, [b[0] + 2 * s * k, Math.min(g, b[1] + 1.6 * sy * k)], Math.max(.8, .8 * s * k), .3), C.claw, { ink: true }); }
    // the haunch: a heavy thigh that narrows to the knee
    vol(P, blob([q(-19, -17), q(-14.5, -22), q(-8.5, -20.5), q(-5.5, -14), q(-6, -8.5), q(-9.5, -6.4), q(-14, -9), q(-18.5, -12)]), ramp, { rim, rimT: .5, ink: true, tex: tex(9, 2) });
    crack(P, jag(...q(-15, -17.5), 1.0, 9 * s * k, 50 + p + (k < 1 ? 10 : 0)), C.crack, C.halo);
    return hp;
  };
  const foreLeg = (o, ramp, rim, k) => {
    const q = (u, v) => [X(u + o[0]), Y(v) + o[1] * s], g = G + o[1] * s * .5;
    const s0 = q(6, -27), elbow = q(3.6, -11.5), wrist = [q(9, 0)[0], g - 3 * sy * k], paw = [q(11, 0)[0], g - 1.7 * sy * k];
    vol(P, union(cap(elbow, wrist, 4.4 * s * k, 3.2 * s * k), ell(elbow[0] + 1.8 * s * k, elbow[1] + 2.6 * sy * k, 3.6 * s * k, 4.4 * sy * k, -.55)), ramp, { rim, rimT: .5, tex: tex(3, 2) });
    vol(P, ell(paw[0], paw[1], 5 * s * k, 2.3 * sy * k), ramp, { rim, ink: true });
    for (let t = 0; t < 4; t++) { const b = [paw[0] + (-.5 + t * 1.45) * s * k, paw[1] + .5 * sy]; vol(P, cap(b, [b[0] + 2.4 * s * k, Math.min(g, b[1] + 1.9 * sy * k)], Math.max(.9, 1 * s * k), .3), C.claw, { ink: true }); }
    // the upper arm: a slab of muscle from the shoulder back down to the elbow
    vol(P, blob([q(1, -27), q(6.5, -29.5), q(12, -26.5), q(13.4, -19), q(9.5, -11.6), q(4.8, -8.8), q(.6, -12), q(-.6, -20)]), ramp, { rim, rimT: .5, ink: true, tex: tex(7, 2) });
    crack(P, jag(...q(9.5, -24), 1.85, 10 * s * k, 60 + p + (k < 1 ? 5 : 0)), C.crack, C.halo);
    return { s0, paw, elbow };
  };

  // ===== leg_far (Z 8): the far hind leg, darker and cooler =====
  P.part('leg_far');
  { const hp = hindLeg(far, C.far, C.rimFar, .95); P.joint('leg_far', hp[0], hp[1]); }

  // ===== body (Z 10): far foreleg, torso, belly, plates; smoke and embers =====
  P.part('body').joint('body', X(-5), Y(-15));
  foreLeg(far, C.far, C.rimFar, .93);
  vol(P, torso, C.hide, { rim: C.rim, rimT: .5, tex: tex(1, 2), ink: true });
  {
    // belly: the underside from the chest back to the haunch, warm, in bands
    const bel = clip(torso, (x, y) => { const [, bot] = contour(Math.floor(x)); return bot !== null && y > bot - 4.2 * sy; });
    vol(P, bel, C.belly, { ink: C.belly[0], flat: 1.6, lift: -1, tex: (x, y, t) => ((Math.round((x - ox) / s) % 3) === 0 ? Math.max(0, t - 1) : t) });
  }
  // back armour: plates from the hips up to the hump, the front plate over the one behind it
  {
    const us = p === 1 ? [-17, -11, -5, 1, 7, 12] : [-17, -11, -5, .5, 6, 11.5];
    us.forEach((u, i) => {
      const x = X(u), [top] = contour(Math.round(x));
      if (top === null) return;
      const gr = .6 + .4 * (i / (us.length - 1));   // plates grow towards the shoulders
      if (!F.plates) {
        // salamander: low glowing warts instead of plates
        vol(P, ell(x, top + 1.4 * sy, 2.4 * s * gr, 1.6 * sy), C.plate, { ink: true, cast: true, round: 1 });
        P.dot(x, top + .9 * sy, C.crack[2]).dot(x + 1, top + .9 * sy, C.crack[1]);
        return;
      }
      const ta = contour(Math.round(x + 3))[0], tb = contour(Math.round(x - 3))[0];
      const sl = ta === null || tb === null ? 0 : clamp((ta - tb) / 6, -1.2, 1.2);
      const w = 7.4 * s * gr, hh = 5 * sy * gr, up = 1.5 * s * gr;
      const pl = blob([[x - w * .66, top + hh * .45 - sl * w * .6], [x - w * .8, top - up * .6 - sl * w * .75], [x - w * .1, top - up - sl * w * .1], [x + w * .45, top - up * .3 + sl * w * .45], [x + w * .5, top + hh * .5 + sl * w * .5], [x - w * .05, top + hh]], 4);
      vol(P, pl, C.plate, { ink: K, cast: [[1, 1], [0, 1]], flat: 1.5, bias: [0, -.5], rim: C.rim, rimT: .75, round: 1 });
      if (i % 2 === 0 || obs) crack(P, jag(x + w * .15, top - up * .3, 1.75 + (i % 3) * .3, hh * 1.2, 11 + i * 13 + p), C.crack, C.halo);
      if (F.spikes) spike([x - w * .2, top - up * .7 - sl * w * .2], -2.05, (F.spikes === 1 ? 2.6 : F.spikes === 2 ? 4.6 : 5.6) * s * gr, .95 * s * gr, C.horn, true);
    });
  }
  {
    // cracks over the flank; form 4: the void core shows through a split in the chest
    const cc = pt(13, -16);
    crack(P, jag(cc[0] - 1 * s, cc[1] - 3.5 * sy, 1.3, 9 * s, 90 + p), C.crack, C.halo);
    crack(P, jag(X(-7), Y(-21), .65, 12 * s, 95 + p), C.crack, C.halo);
    if (obs) {
      vol(P, ell(cc[0], cc[1], 2.2 * s, 3.4 * sy, .3), [INDIGO, VIOD, VIO, LILAC, WHITE], { flat: .8 });
      crack(P, jag(cc[0], cc[1] - 1 * sy, -1.1, 6 * s, 101), C.crack2, null);
      P.glow(cc[0], cc[1] - .4 * sy, WHITE).glow(cc[0], cc[1] + .6 * sy, LILAC);
    }
    P.joint('core', cc[0], cc[1]);
  }
  {
    // smoke and embers rising from the back (no outline, front layer of the body)
    const r = rng(7 + p), n = p + 1;
    for (let k = 0; k < n; k++) {
      const u = lerp(-15, 5, (k + .5) / n), x = X(u), [top] = contour(Math.round(x));
      if (top === null) continue;
      let cx = x, cy = top - (F.plates ? 2.5 * s : 1);
      const hgt = (6 + r() * 5) * s * .7;
      for (let j = 0; j < hgt; j++) {
        cx += Math.sin(j * .45 + k * 2) * .6 - .3; cy -= 1;
        const wd = 1 + Math.floor(j / 5);
        if ((j + k) % 4 === 3 && j > 2) continue;
        for (let w = 0; w < Math.min(wd, 3); w++) if (r() < .6) P.glow(cx + w - (wd >> 1), cy, j < hgt * .45 ? C.smoke[1] : C.smoke[0]);
      }
      for (let e = 0; e < 2; e++) P.glow(x + (r() - .5) * 7 * s, top - (3 + r() * 8) * s, C.ember[(e + k) % 2]);
    }
  }

  // ===== leg_near (Z 11) =====
  P.part('leg_near');
  { const hp = hindLeg([0, 0], C.hide, C.rim, 1); P.joint('leg_near', hp[0], hp[1]); }

  // ===== wing_near (Z 12): raised over the back like a mantle =====
  if (F.wings) {
    const root = [X(-1), Y(-27)];
    P.part('wing_near').joint('wing_near', root[0], root[1] + 1.5);
    wing(P, root, s * F.ws, -.24, C.wing, C.wingBone, C.wingRim, C, false, obs);
  }

  // ===== neck (Z 13): short and thick, thrust forward and down =====
  const nb = pt(12, -25), ne = H(-4.4, -.4);
  const nmid = [lerp(nb[0], ne[0], .5) + .4 * s, lerp(nb[1], ne[1], .5) - 1.2 * s];
  {
    P.part('neck').joint('neck', nb[0], nb[1]);
    const neck = union(cap(nb, nmid, 6.6 * s, 5.8 * s), cap(nmid, ne, 5.8 * s, 4.8 * s * hs));
    vol(P, neck, C.hide, { rim: C.rim, rimT: .5, tex: tex(4, 2) });
    const dl = Math.hypot(ne[0] - nb[0], ne[1] - nb[1]);
    const under = clip(neck, (x, y) => (y - nb[1]) * (ne[0] - nb[0]) - (x - nb[0]) * (ne[1] - nb[1]) > 3 * s * dl);
    vol(P, under, C.belly, { ink: C.belly[0], lift: -1, tex: (x, y, t) => ((x + y) % 3 === 0 ? Math.max(0, t - 1) : t) });
    for (let i = 0; i < 3; i++) {
      const m = lerp2(nb, ne, .1 + i * .3), top = [m[0] - .3 * s, m[1] - (6 - i * .5) * s];
      if (F.plates) vol(P, ell(top[0], top[1] + 1.7 * s, 3 * s, 2 * s, -.45), C.plate, { ink: K, cast: true, bias: [0, -.5], round: 1 });
      else vol(P, ell(top[0], top[1] + 1.9 * s, 1.7 * s, 1.2 * s), C.plate, { ink: true, round: 1 });
      if (F.spikes === 1) spike(top, -2.15, 2.2 * s, .8 * s, C.horn);
    }
    crack(P, jag(nmid[0] + 1 * s, nmid[1] - 2.5 * s, 1.1, 6 * s, 120 + p), C.crack, C.halo);
    P.joint('head', ne[0], ne[1]);
  }

  // ===== crystal_1..3 (Z 14, form 4): void crystals growing out of the hump =====
  if (F.crystals) {
    [[-1, -31, 16, 5.8, .18], [-8, -27.5, 13, 5, .52], [5, -33.5, 10.5, 4.4, -.18]].forEach(([u, v, len, wd, lean], i) => {
      const id = 'crystal_' + (i + 1), b = pt(u, v), dir = -Math.PI / 2 - lean, dx = Math.cos(dir), dy = Math.sin(dir), nx = -dy, ny = dx;
      const L = len * s * .62, W = wd * s * .34, at = (l, w) => [b[0] + dx * L * l + nx * W * w, b[1] + dy * L * l + ny * W * w];
      P.part(id).joint(id, b[0], b[1]);
      vol(P, poly([at(-.15, -.8), at(.62, -1), at(1, 0), at(.62, 1), at(-.15, .8)]), C.crystal, { flat: 2 });
      vol(P, poly([at(-.1, .05), at(.62, .12), at(.96, 0), at(.62, .95), at(-.1, .7)]), [INDIGO, INDIGO, VIOD, VIOD, VIO], { flat: 3, ink: INDIGO });
      P.dot(...at(.2, -.4), WHITE).dot(...at(.45, -.45), LILAC);
      const g = at(.86, -.1);
      P.glow(g[0], g[1], WHITE).glow(g[0] - dx * 2, g[1] - dy * 2, LILAC).glow(g[0] + dx * 2, g[1] + dy * 2, VIO);
    });
  }

  // ===== arm (Z 15): the near foreleg, a pillar of muscle with a spiked shoulder plate =====
  P.part('arm');
  {
    const { s0, paw } = foreLeg([0, 0], C.hide, C.rim, 1);
    P.joint('arm', s0[0], s0[1] + 2).joint('hand', paw[0] + 4 * s, paw[1]);
    if (p >= 2) {
      // shoulder plate (pauldron) on top of the arm: it overlaps the neck
      const c = pt(7.2, -25.5), w = (big ? 9 : 7.6) * s, h = (big ? 6 : 5) * sy;
      vol(P, blob([[c[0] - w * .6, c[1] + h * .45], [c[0] - w * .55, c[1] - h * .4], [c[0] + w * .05, c[1] - h * .8], [c[0] + w * .55, c[1] - h * .3], [c[0] + w * .55, c[1] + h * .45], [c[0], c[1] + h * .75]], 4), C.plate, { ink: K, cast: [[1, 1], [0, 1], [1, 2]], bias: [0, -.35], flat: 1.4, rim: C.rim, rimT: .7, round: 1 });
      crack(P, jag(c[0] + w * .05, c[1] - h * .55, 1.7, h * 1.2, 140 + p), C.crack, C.halo);
      if (F.spikes >= 2) spike([c[0] - .2 * w, c[1] - h * .55], -2.15, (obs ? 6.6 : 5.4) * s, 1.2 * s, C.horn, true);
      else spike([c[0] - .2 * w, c[1] - h * .5], -2.1, 2.6 * s, .9 * s, C.horn, true);
    }
  }

  // ===== throat (Z 16, forms 3 and 4): the fire gland under the neck =====
  const gl = lerp2(nb, ne, .62);
  gl[0] += 1.2 * s; gl[1] += 4.6 * s;
  P.part('neck').joint('throat_at', gl[0], gl[1]);
  if (big) {
    P.part('throat').joint('throat', gl[0], gl[1]);
    const ang = Math.atan2(ne[1] - nb[1], ne[0] - nb[0]);
    vol(P, ell(gl[0], gl[1], 3.8 * s, 2.5 * s, ang), C.gland, { flat: 1, rim: obs ? LILAC : YEL, rimT: .3, round: 1 });
    for (const k of [-1, 0, 1]) { const c = [gl[0] + Math.cos(ang) * k * 1.8 * s, gl[1] + Math.sin(ang) * k * 1.8 * s]; crack(P, [[c[0] + .5 * s, c[1] - 1.8 * s], [c[0] - .3 * s, c[1] + 1.6 * s]], obs ? [MAG, PINK, LILAC, WHITE] : [BORA, ORA, YEL, WHITE], null); }
    if (obs) P.glow(gl[0], gl[1], WHITE).glow(gl[0] + 1, gl[1], LILAC);
  }

  // ===== jaw (Z 17): a heavy underslung jaw, open, the throat fire glowing inside =====
  const hinge = H(-3.6, 1.2), op = p === 1 ? 1.2 : big ? 2.3 : 1.9;
  {
    P.part('jaw').joint('jaw', hinge[0], hinge[1]);
    // the inside of the mouth rides on the jaw (hidden behind the snout until the jaw drops)
    vol(P, poly([H(-3.4, -.4), H(10, .2), H(10.2, 2.6 + op), H(-3.4, 3.2)]), C.mouth, { flat: 2 });
    const fire = C.fire;
    vol(P, poly([H(-2.6, 1.2), H(4, 1.4), H(7.5, 2 + op * .6), H(4, 2.8 + op * .5), H(-2.6, 2.8)]), [fire[3], fire[2], fire[2], fire[1], fire[0]], { flat: 1.2, round: 1 });
    const jaw = HB([[-4.6, 1.2], [0, 2.4 + op * .3], [6, 2.6 + op * .75], [10.4, 2.7 + op], [10.6, 4.4 + op], [6.5, 6 + op * .7], [.5, 6.6 + op * .25], [-4, 4.8]], 5);
    vol(P, jaw, C.hide, { rim: C.rim, rimW: 2, rimT: .3, tex: tex(12, 2) });
    for (let k = 0; k < (big ? 6 : 4); k++) { const q = H(.8 + k * 1.65, 2.4 + op * (.3 + k * .12)); P.dot(q[0], q[1] - 1, WHITE).dot(q[0], q[1] - 2, k % 2 ? BONE : WHITE); if (big && k % 2 === 0) P.dot(q[0], q[1] - 3, BONE); }
    if (F.tusks) spike(H(8, 2.7 + op), -1.45, (big ? 4.8 : 3.4) * hs * s, .9 * s, C.claw);
    if (p >= 2) for (const [u, L] of [[1, 1], [4, .75]].slice(0, big ? 2 : 1)) spike(H(u, 6.2 + op * .3), 2.25, L * (obs ? 3.6 : 2.8) * s, .75 * s, C.horn);
    P.joint('mouth', ...H(10, 2.4 + op * .5));
  }

  // ===== head (Z 18): low and heavy, armoured brow, burning eyes =====
  P.part('head');
  {
    const skull = HB([[-5.6, -1.6], [-4.2, -4.8], [0, -5.8], [5, -4.8], [9, -3.2], [11.2, -1.6], [11.2, 1.1], [6, 2.6], [0, 2.8], [-4.4, 2]], 5);
    vol(P, skull, C.hide, { rim: C.rim, rimT: .45, tex: tex(13, 2) });
    for (let k = 0; k < (big ? 6 : 5); k++) { const q = H(.6 + k * 1.75, 2.5); P.dot(q[0], q[1] + 1, WHITE); P.dot(q[0], q[1] + 2, k % 2 ? BONE : WHITE); if (big && k % 2 === 1) P.dot(q[0], q[1] + 3, BONE); }
    // the heavy brow ridge, a cheek plate and nose plates (armour)
    vol(P, blob([H(-4, -5.6), H(3.2, -6.3), H(7, -4), H(6.4, -2.4), H(2, -2.6), H(-3, -3.2)], 4), C.plate, { ink: K, cast: [[0, 1], [1, 1], [0, 2]], bias: [0, -.5], rim: C.rim, rimT: .8, round: 1 });
    vol(P, blob([H(-6, -1.8), H(-1.6, -1), H(.2, 1.6), H(-4, 2.6)], 4), C.plate, { ink: K, cast: true, round: 1 });
    if (p >= 2) vol(P, blob([H(7.2, -4.2), H(10.2, -2.8), H(9.8, -1.9), H(7, -3)], 3), C.plate, { ink: K, round: 1 });
    crack(P, jag(...H(-3.6, -.9), .45, 5 * s * hs, 150 + p), C.crack, C.halo);
    const ns = H(10.2, -1.4);
    P.dot(ns[0], ns[1], K).dot(ns[0] - 1, ns[1], C.hide[0]);
    for (let j = 1; j < 5 + p; j++) if (j % 2) P.glow(ns[0] + Math.round(Math.sin(j) * .8), ns[1] - j - 1, j < 4 ? C.smoke[1] : C.smoke[0]);
    // the eye: a deep socket under the brow, a burning slit with a flame trail
    const ey = H(3.2, -1.7);
    vol(P, ell(ey[0], ey[1], HS(2.3), HS(1.2)), [BLK, BLK, C.mouth[0], C.mouth[0], C.mouth[1]], { flat: 3, round: 1 });
    P.glow(ey[0] - 1, ey[1], C.eye[0]).glow(ey[0], ey[1], C.eye[1]).glow(ey[0] + 1, ey[1], C.eye[2]).glow(ey[0] + 2, ey[1], C.eye[2]).glow(ey[0] + 3, ey[1], C.eye[1]);
    P.glow(ey[0], ey[1] + 1, C.eye[0]).glow(ey[0] + 1, ey[1] + 1, C.eye[1]).glow(ey[0] + 2, ey[1] + 1, C.eye[0]);
    for (let j = 1; j <= p + 2; j++) P.glow(ey[0] - 1 - j, ey[1] - Math.floor(j * .55), j < 2 ? C.eye[1] : j < 4 ? C.eye[0] : (obs ? VIO : RED));
    // form 2 grows horn nubs on the head (its rig has no horns part), form 1 bony warts
    if (p === 2) for (const [u, v, a, L] of [[-1.6, -5.4, -2.3, 3.8], [-4.2, -3.9, -2.7, 3.4], [1.6, -5.8, -1.85, 2.8]]) {
      const b = H(u, v);
      vol(P, cap(b, [b[0] + Math.cos(a) * L * s, b[1] + Math.sin(a) * L * s], 1.35 * s, .35 * s), C.horn, { ink: true, cast: true, rim: C.rim, rimT: .7 });
    }
    if (p === 1) for (const [u, v] of [[-2.4, -5.2], [0, -5.7], [2.4, -5.4]]) { const b = H(u, v); vol(P, ell(b[0], b[1], 1.3 * s, 1 * s), C.plate, { ink: true, round: 1 }); P.dot(b[0], b[1] - .5, C.crack[2]); }
  }

  // ===== horns (Z 19, forms 3 and 4): the crown =====
  if (F.crown >= 2) {
    const k = obs ? 1.2 : 1, base = H(-1.6, -4.8);
    P.part('horns').joint('horns', base[0], base[1] + 1);
    const horn = (pts, r0, ramp) => {
      const c = bez(...pts, 12);
      vol(P, tube(c, r0, .3), ramp, { ink: true, cast: true, rim: C.rim, rimT: .6 });
      for (let i = 2; i < 11; i += 3) { const q = c[i], nx = c[i + 1][1] - c[i - 1][1], ny = -(c[i + 1][0] - c[i - 1][0]), l = Math.hypot(nx, ny) || 1, rr = lerp(r0, .3, i / 12) * .8; crack(P, [[q[0] - nx / l * rr, q[1] - ny / l * rr], [q[0] + nx / l * rr, q[1] + ny / l * rr]], [ramp[1], ramp[1], ramp[1], ramp[1]], null); }
    };
    const darker = C.horn.map((c, i) => C.horn[Math.max(0, i - 1)]);
    // two great horns sweep back from the skull and rise at their tips (the far one behind,
    // darker); spikes fan back below them; form 4 adds a third great horn in the middle
    const great = (dx, dy, ramp, sc, len) => horn([H(-.8 + dx, -4.6 + dy), H(-.2 * len + dx, -10.5 * k * sc + dy), H(-1.8 * k * len + dx, -15.5 * k * sc + dy), H(-5.8 * k * len + dx, -18.5 * k * sc + dy)], 1.4 * k * s, ramp);
    great(2.4, -.7, darker, .9, .9);
    if (obs) great(-2.6, .9, C.horn, .66, .8);
    for (const [u, v, a, L, r] of [[-5, -2.6, -2.95, 7.5, 1.15], [-5.4, .4, -3.1, 6.2, 1]]) {
      const b = H(u, v), t = [b[0] + Math.cos(a) * L * k * s, b[1] + Math.sin(a) * L * k * s], m = [lerp(b[0], t[0], .5), lerp(b[1], t[1], .5) - 1 * s];
      horn([b, m, m, t], r * k * s, C.horn);
    }
    great(0, 0, C.horn, 1, 1);
    for (const [u, L] of [[4, 3.6], [6, 2.4]]) spike(H(u, -4.6), -1.3, L * k * s, .85 * s, C.horn, true);
  }

  // ===== mouth_flame (Z 20, form 4): void fire licking from both mouth corners =====
  if (obs) {
    const mc = H(.2, 3);
    P.part('mouth_flame').joint('mouth_flame', mc[0], mc[1] + 1);
    P.flame(mc[0] - 1.2 * s, mc[1] + 1, Math.round(2.6 * s), Math.round(5.4 * s), { seed: 11, pal: C.fire, front: true, dir: 1, lean: -3, sparks: false });
    P.flame(mc[0] + 5.5 * s, mc[1] + 1.5 + op * s * .5, Math.round(2.2 * s), Math.round(4.4 * s), { seed: 17, pal: C.fire, front: true, dir: 1, lean: -2, sparks: false });
  }
}

// A wing raised over the back: the arm bone climbs to the elbow and forward to the wrist (the
// front peak, with a claw), the fingers fan back from the wrist, the first one up to the top tip;
// the membrane between them hangs in smooth scallops and glows at its trailing edge.
function wing(P, root, s, rot, ramp, boneRamp, rim, C, farSide, torn) {
  const c = Math.cos(rot), sn = Math.sin(rot), at = (u, v) => [root[0] + (u * c - v * sn) * s, root[1] + (u * sn + v * c) * s];
  const el = at(-5, -14), wr = at(5.5, -23), tips = [at(-7, -32), at(-22, -28), at(-31, -15.5), at(-28, -2)], back = at(-13, 3);
  // scallops: the trailing edge between two finger tips sags towards the wrist in an arc
  const scallop = (a, b, depth) => { const out = []; for (let i = 1; i < 6; i++) { const t = i / 6, m = lerp2(a, b, t), k = Math.sin(t * Math.PI) * depth; out.push(lerp2(m, wr, k)); } return out; };
  const edge = [root, wr, tips[0], ...scallop(tips[0], tips[1], .2), tips[1], ...scallop(tips[1], tips[2], .22), tips[2], ...scallop(tips[2], tips[3], .2), tips[3], ...scallop(tips[3], back, .12), back];
  let mem = poly(edge);
  if (torn) mem = minus(mem, ell(...lerp2(lerp2(tips[1], tips[2], .5), wr, .3), 1.3 * s, 1 * s), ell(...lerp2(lerp2(tips[2], tips[3], .45), wr, .26), 1 * s, 1.3 * s));
  // the membrane is darker near the arm and lighter (lit through by the fire) towards its edge
  const span = Math.hypot(tips[2][0] - wr[0], tips[2][1] - wr[1]);
  vol(P, mem, ramp, { flat: 2.6, rim, rimW: 1.5, rimT: .25, tex: (x, y, t) => { const d = Math.hypot(x - wr[0], y - wr[1]) / span; return t + (d > .82 ? 1 : d < .35 ? -1 : 0); } });
  for (let i = 0; i < 3; i++) { const nt = lerp2(lerp2(tips[i], tips[i + 1], .5), wr, .22); crack(P, [lerp2(wr, nt, .3), lerp2(wr, nt, .9)], [ramp[0], ramp[0], ramp[0], ramp[0]], null); }
  for (const t of tips) vol(P, cap(wr, t, Math.max(1, .95 * s), .55), boneRamp, { ink: true, rim, rimT: .7 });
  vol(P, tube([root, el, wr], 2.8 * s, 1.9 * s), boneRamp, { ink: true, rim, rimT: .6 });
  // claws: at the wrist and the elbow (form 4: gold tusks, one more on the leading finger)
  const claw = (b, ang, L, r) => vol(P, cap(b, [b[0] + Math.cos(ang + rot) * L * s, b[1] + Math.sin(ang + rot) * L * s], Math.max(1, r * s), .3), C.claw, { ink: true, cast: true });
  claw(wr, -1.0, torn ? 6.5 : 4.8, torn ? 1.25 : 1);
  claw(el, -2.5, torn ? 4.5 : 3, .95);
  if (torn) claw(lerp2(wr, tips[0], .5), -2.2, 3.2, .8);
  if (!farSide) crack(P, jag(...lerp2(root, el, .55), -2.0, 5 * s, 300), C.crack, null);
}

// ---------- layout, isolated parts and the rig-style composite ----------
const cache = {};
// Frame size per form: drawn once on a large canvas, then cut to the drawing plus a margin.
function layout(p) {
  if (cache['L' + p]) return cache['L' + p];
  const big = new Painter(420, 300, 0, null);
  hoellenfuerst(big, p, 0, 220);
  let x0 = 1e9, y0 = 1e9, x1 = -1;
  for (let f = 0; f < 4; f++) {
    const q = new Painter(420, 300, f, null);
    hoellenfuerst(q, p, f, 220);
    const px = q.finish();
    for (let y = 0; y < q.h; y++) for (let x = 0; x < q.w; x++) if (px[y * q.w + x]) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); }
  }
  const m = 2, W = x1 - x0 + 1 + 2 * m, Hh = 300 - y0 + m;
  return (cache['L' + p] = { W, H: Hh, ox: 220 - x0 + m });
}
// Renders form p: part = one part id (isolated with its own outline) or null for everything.
function renderPart(p, part, frame, skip) {
  const L = layout(p), P = new Painter(L.W, L.H, frame || 0, part == null ? null : part);
  hoellenfuerst(P, p, frame || 0, L.ox);
  return { w: L.W, h: L.H, px: P.finish(skip), solid: P.solid.map(Boolean), joints: P.joints, tags: P.tags };
}
// Composes the parts like export_rigs.js: back to front by Z, no outline on the seamless joints.
function compose(p, frame) {
  const all = renderPart(p, null, 0), w = all.w, h = all.h;
  const ids = all.tags.filter(t => Z[t] !== undefined);
  ids.sort((a, b) => Z[a] - Z[b] || ids.indexOf(a) - ids.indexOf(b));
  const solid = {}, layers = {};
  for (const id of ids) solid[id] = renderPart(p, id, 0).solid;
  const out = new Array(w * h).fill(null), owner = new Array(w * h).fill(null);
  for (const id of ids) {
    const near = SEAMLESS.filter(pr => pr.includes(id)).map(pr => solid[pr[0] === id ? pr[1] : pr[0]]).filter(Boolean);
    const skip = near.length ? i => near.some(m => m[i]) : undefined;
    const img = renderPart(p, id, FLIPBOOK.has(id) ? frame || 0 : 0, skip);
    layers[id] = img;
    img.px.forEach((c, i) => { if (c) { out[i] = c; owner[i] = id; } });
  }
  return { w, h, px: out, owner, joints: all.joints, tags: all.tags, ids, layers };
}
// A small version of export_rigs.js checkRigs for the concept: parts, frame edges, pivots, flipbooks
// and the visible pixels of the severable parts.
function rigCheck(p) {
  const comp = compose(p, 0), problems = [], J = comp.joints, w = comp.w, h = comp.h;
  const ids = comp.ids.slice().sort(), want = EXPECT[p].slice().sort();
  if (JSON.stringify(ids) !== JSON.stringify(want)) problems.push(`parts [${ids}] differ from [${want}]`);
  const near = (img, pv) => { let best = 1e9; img.px.forEach((c, i) => { if (c && c !== K) { const x = i % w + .5, y = Math.floor(i / w) + .5; best = Math.min(best, Math.hypot(x - pv[0], y - pv[1])); } }); return best; };
  for (const id of comp.ids) {
    const img = comp.layers[id];
    if (!J[id]) { problems.push(id + ': no joint'); continue; }
    let edge = false;
    img.px.forEach((c, i) => { if (c && (i < w || i % w === 0 || i % w === w - 1)) edge = true; });
    if (edge) problems.push(id + ': touches the frame edge');
    const d = near(img, J[id]), lim = FLIPBOOK.has(id) ? 6 : 2.5;
    if (d > lim) problems.push(`${id}: pivot ${d.toFixed(1)} px from the part`);
    if (PARENT[id] && !FLIPBOOK.has(id)) { const dp = near(comp.layers[PARENT[id]], J[id]); if (dp > 3) problems.push(`${id}: pivot ${dp.toFixed(1)} px from parent ${PARENT[id]}`); }
    if (FLIPBOOK.has(id)) { const fr = new Set([0, 1, 2, 3].map(f => renderPart(p, id, f).px.join())); if (fr.size < 3) problems.push(id + ': flipbook has ' + fr.size + ' distinct frames'); }
  }
  for (const k of ['mouth', 'throat_at', 'hand', 'tail_tip', 'core']) if (!J[k]) problems.push('point ' + k + ' missing');
  const vis = {};
  for (const id of SEVERABLE[p]) vis[id] = comp.owner.filter(o => o === id).length;
  for (const id in vis) if (vis[id] < MIN_VISIBLE) problems.push(`${id}: only ${vis[id]} px visible`);
  const all = renderPart(p, null, 0); let top = h; all.solid.forEach((v, i) => { if (v) top = Math.min(top, Math.floor(i / w)); });
  return { problems, vis, size: [w, h], bodyH: h - top };
}

// ---------- PNG ----------
function crc32(buf) { let c, crc = 0xffffffff; for (let n = 0; n < buf.length; n++) { c = (crc ^ buf[n]) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = (crc >>> 8) ^ c; } return (crc ^ 0xffffffff) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4), crc = Buffer.alloc(4), td = Buffer.concat([Buffer.from(type, 'ascii'), data]); len.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, crc]); }
function encodePng(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function decodePng(buf) {
  let pos = 8, w = 0, h = 0, depth = 0, type = 0, pal = null, trns = null;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), kind = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); depth = data[8]; type = data[9]; }
    else if (kind === 'PLTE') pal = data; else if (kind === 'tRNS') trns = data; else if (kind === 'IDAT') idat.push(data); else if (kind === 'IEND') break;
    pos += 12 + len;
  }
  if (depth !== 8) throw new Error('bit depth ' + depth);
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[type], stride = w * ch, raw = zlib.inflateSync(Buffer.concat(idat)), px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const ft = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[y * stride + x - ch] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = x >= ch && y ? px[(y - 1) * stride + x - ch] : 0;
      let v = line[x];
      if (ft === 1) v += a; else if (ft === 2) v += b; else if (ft === 3) v += (a + b) >> 1;
      else if (ft === 4) { const q = a + b - c, pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
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

// ---------- canvas for the sheets ----------
const FONT = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111', F: '111100110100100',
  G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010', K: '101101110101101', L: '100100100100111',
  M: '101111111101101', N: '110101101101101', O: '010101101101010', P: '110101110100100', Q: '010101101110011', R: '110101110101101',
  S: '011100010001110', T: '111010010010010', U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101',
  Y: '101101010010010', Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111', 9: '111101111001110',
  ' ': '000000000000000', '.': '000000000000010', ':': '000010000010000', '-': '000000111000000', '/': '001001010100100', 'X': '101101010101101',
  '(': '001010010010001', ')': '100010010010100', ',': '000000000010100', '=': '000111000111000', '+': '000010111010000',
};
function Canvas(w, h, bg) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); for (let i = 0; i < w * h; i++) this.d.set(bg, i * 4); }
Canvas.prototype.px = function (x, y, c) { x = Math.round(x); y = Math.round(y); if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d.set(c, (y * this.w + x) * 4); };
Canvas.prototype.get = function (x, y) { const i = (y * this.w + x) * 4; return [this.d[i], this.d[i + 1], this.d[i + 2], 255]; };
Canvas.prototype.rect = function (x, y, w, h, c) { for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, c); };
Canvas.prototype.text = function (x, y, str, c, k) {
  k = k || 2;
  for (const ch of String(str).toUpperCase().replace(/Ü/g, 'UE').replace(/Ö/g, 'OE').replace(/Ä/g, 'AE')) {
    const g = FONT[ch] || FONT[' '];
    for (let i = 0; i < 15; i++) if (g[i] === '1') this.rect(x + (i % 3) * k, y + Math.floor(i / 3) * k, k, k, c);
    x += 4 * k;
  }
};
// Draws a colour-string image (w x h) at (x, y), each source px as k x k.
Canvas.prototype.sprite = function (px, w, h, x, y, k) { for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) { const c = px[yy * w + xx]; if (c) this.rect(Math.round(x + xx * k), Math.round(y + yy * k), Math.ceil(k), Math.ceil(k), [...hexToRgb(c), 255]); } };
// Draws an RGBA image scaled by k (nearest neighbour, k may be fractional).
Canvas.prototype.rgba = function (img, x, y, k) {
  const W = Math.round(img.w * k), H = Math.round(img.h * k);
  for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) { const sx = Math.floor(xx / k), sy = Math.floor(yy / k), i = (sy * img.w + sx) * 4; if (img.rgba[i + 3] > 127) this.px(x + xx, y + yy, [img.rgba[i], img.rgba[i + 1], img.rgba[i + 2], 255]); }
};
// A soft ground shadow: darkens what is below, strongest in the middle (preview only; the game
// draws its own shadow under the rig).
Canvas.prototype.shadow = function (cx, cy, rx, ry) {
  for (let y = Math.floor(cy - ry); y <= cy + ry; y++) for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
    const q = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2;
    if (q > 1 || x < 0 || y < 0 || x >= this.w || y >= this.h) continue;
    const k = q < .35 ? .45 : q < .7 ? .6 : .78, i = (y * this.w + x) * 4;
    this.d[i] = this.d[i] * k; this.d[i + 1] = this.d[i + 1] * k; this.d[i + 2] = this.d[i + 2] * k;
  }
};
Canvas.prototype.save = function (file) { fs.writeFileSync(file, encodePng(this.w, this.h, this.d)); console.log('wrote', path.relative(ROOT, file), this.w + 'x' + this.h); };

// The span of the feet on the ground row (for the shadow).
function footprint(comp) {
  let x0 = comp.w, x1 = -1;
  for (let y = comp.h - 4; y < comp.h; y++) for (let x = 0; x < comp.w; x++) if (comp.px[y * comp.w + x]) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); }
  return [x0, x1];
}

// ---------- the sheets ----------
function knight() { return decodePng(fs.readFileSync(path.join(ROOT, 'assets', 'sprites', '0x72', 'knight_m_idle_anim_f0.png'))); }
function floorTile() {
  const shot = decodePng(fs.readFileSync(path.join(ROOT, 'production', 'qa', 'evidence', 'hell-monsters', '01-kampfraum-etage5.png')));
  return shot;
}

function lineup(comps) {
  // same in-game scale for all: 1 source px = 5 world px; the sheet shows 0.4 x world -> 2 px.
  const k = 2, kn = knight(), knK = 3 * .4, gap = 34, top = 40, label = 30;
  const Hmax = Math.max(...comps.map(c => c.h)) * k;
  const W = comps.reduce((s, c) => s + c.w * k + kn.w * knK + gap * 2, gap);
  const Hh = top + Hmax + label + 26;
  const cv = new Canvas(Math.round(W), Hh, [33, 27, 33, 255]);
  // hell floor: dark stone with a faint lava tint towards the bottom
  for (let y = 0; y < Hh; y++) for (let x = 0; x < cv.w; x++) { const n = ((x * 13 + y * 7) % 23 === 0) ? 6 : 0; cv.px(x, y, [33 + n + (y > top + Hmax ? 6 : 0), 27 + n, 33 + n, 255]); }
  cv.text(gap, 12, 'IGNAROTH - HOELLENFUERST   GLEICHER MASSSTAB WIE IM SPIEL (0.4X)   RITTER 0X72 ZUM VERGLEICH', [236, 226, 214, 255], 2);
  let x = gap;
  const ground = top + Hmax;
  comps.forEach((c, i) => {
    const kx = x, dx = x + kn.w * knK + gap * .6;
    const [f0, f1] = footprint(c);
    cv.shadow(dx + (f0 + f1) / 2 * k, ground - 2, (f1 - f0) * k * .55, 7 + i * 2);
    cv.shadow(kx + kn.w * knK / 2, ground - 1, kn.w * knK * .6, 3);
    cv.sprite(c.px, c.w, c.h, dx, ground - c.h * k, k);
    cv.rgba(kn, Math.round(kx), Math.round(ground - kn.h * knK), knK);
    const hx = (c.bodyH * 5 / 84).toFixed(1);
    cv.text(dx, ground + 10, `${i + 1} ${FORMS[i + 1].name}`, [250, 203, 62, 255], 2);
    cv.text(dx, ground + 26, `FRAME ${c.w}X${c.h}  HOEHE ${hx}X RITTER`, [170, 160, 170, 255], 1);
    x = dx + c.w * k + gap;
  });
  cv.save(path.join(OUT, KEY + '_lineup.png'));
}

function form4Sheet(c4, c3) {
  const k4 = 5, k3 = 5, pad = 30, top = 44;
  const W = pad + c4.w * k4 + pad + c3.w * k3 + pad, Hh = top + Math.max(c4.h * k4, c3.h * k3) + 50;
  const cv = new Canvas(W, Hh, [30, 25, 31, 255]);
  cv.text(pad, 14, 'IGNAROTH HOELLENFUERST  FORM 4 OBSIDIANFORM UND FORM 3 GLUTDRACHE  (1 PX = 5 PX)', [236, 226, 214, 255], 2);
  const g = top + Math.max(c4.h * k4, c3.h * k3);
  [[c4, k4, pad], [c3, k3, pad + c4.w * k4 + pad]].forEach(([c, k, x], i) => {
    const [f0, f1] = footprint(c);
    cv.shadow(x + (f0 + f1) / 2 * k, g - 4, (f1 - f0) * k * .55, 18);
    cv.sprite(c.px, c.w, c.h, x, g - c.h * k, k);
    cv.text(x, g + 14, i ? `3 GLUTDRACHE ${c.w}X${c.h}` : `4 OBSIDIANFORM ${c.w}X${c.h}`, [250, 203, 62, 255], 3);
  });
  cv.save(path.join(OUT, KEY + '_form4.png'));
}

function ingame(c) {
  const shot = floorTile(), W = 1280, Hh = 720, cv = new Canvas(W, Hh, [20, 16, 20, 255]);
  // tile a clean floor patch of the Feuerhof screenshot (4 x 4 tiles of 48 px) and keep its lava river
  // mirror tiling hides the seams: every other copy of the patch is flipped
  const mir = (v, n) => { const q = Math.floor(v / n), r = v % n; return q % 2 ? n - 1 - r : r; };
  const tx = 468, ty = 388, tw = 150, th = 104;
  for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) { const i = ((ty + mir(y, th)) * shot.w + tx + mir(x, tw)) * 4; cv.px(x, y, [shot.rgba[i], shot.rgba[i + 1], shot.rgba[i + 2], 255]); }
  for (let y = 0; y < Hh; y++) for (let x = 0; x < 113; x++) { const i = ((150 + mir(y, 490)) * shot.w + 345 + x) * 4; cv.px(x + 30, y, [shot.rgba[i], shot.rgba[i + 1], shot.rgba[i + 2], 255]); }
  const k = 5, gx = Math.round(W / 2 - c.w * k / 2 + 90), gy = Math.min(Hh - 70, Math.round(Hh / 2 + c.h * k / 2));
  const [f0, f1] = footprint(c);
  cv.shadow(gx + (f0 + f1) / 2 * k, gy - 6, (f1 - f0) * k * .58, 34);
  cv.sprite(c.px, c.w, c.h, gx, gy - c.h * k, k);
  const kn = knight(), kx = 215, ky = 600;
  cv.shadow(kx + 24, ky + 82, 22, 6);
  cv.rgba(kn, kx, ky, 3);
  cv.text(20, 20, 'MOCK: IGNAROTH FORM ' + c.form + ' IM KAMPFRAUM, WELTMASSSTAB 5, RITTER X3', [236, 226, 214, 255], 2);
  cv.save(path.join(OUT, KEY + '_ingame' + (c.suffix || '') + '.png'));
}

// The parts sheet: every part of form 4 on its own (the rig view), to show the split.
function partsSheet(p) {
  const comp = compose(p, 0), k = 3, cols = 6, cw = comp.w * k + 12, ch = comp.h * k + 26;
  const rows = Math.ceil(comp.ids.length / cols), cv = new Canvas(cols * cw + 12, rows * ch + 40, [36, 31, 38, 255]);
  cv.text(12, 12, `FORM ${p} RIG-TEILE EINZELN (ISOLIERT GERENDERT, PIVOT = TUERKIS)`, [236, 226, 214, 255], 2);
  comp.ids.forEach((id, n) => {
    const x = 12 + (n % cols) * cw, y = 36 + Math.floor(n / cols) * ch, img = comp.layers[id];
    cv.rect(x - 2, y - 2, comp.w * k + 4, comp.h * k + 4, [52, 46, 54, 255]);
    cv.sprite(img.px, comp.w, comp.h, x, y, k);
    const j = comp.joints[id]; if (j) cv.rect(Math.round(x + j[0] * k) - 2, Math.round(y + j[1] * k) - 2, 5, 5, [90, 230, 220, 255]);
    cv.text(x, y + comp.h * k + 6, `${id} Z${Z[id]}`, [250, 203, 62, 255], 2);
  });
  cv.save(path.join(OUT, `${KEY}_parts${p}.png`));
}

if (require.main === module) {
  fs.mkdirSync(OUT, { recursive: true });
  const comps = [1, 2, 3, 4].map(p => { const c = compose(p, 1), all = renderPart(p, null, 0); let top = c.h; all.solid.forEach((v, i) => { if (v) top = Math.min(top, Math.floor(i / c.w)); }); return Object.assign(c, { form: p, bodyH: c.h - top }); });
  for (const p of [1, 2, 3, 4]) {
    const r = rigCheck(p);
    console.log(`form ${p} ${FORMS[p].name}: frame ${r.size[0]}x${r.size[1]}, solid height ${r.bodyH} px = ${(r.bodyH * 5 / 84).toFixed(2)}x knight  visible ${JSON.stringify(r.vis)}  ${r.problems.length ? 'PROBLEMS ' + r.problems.join('; ') : 'rig ok'}`);
  }
  lineup(comps);
  form4Sheet(comps[3], comps[2]);
  ingame(comps[3]);
  ingame(Object.assign({}, comps[2], { suffix: '_form3' }));
  partsSheet(4);
}
module.exports = { hoellenfuerst, renderPart, compose, rigCheck, layout, FORMS, PAL, Canvas, footprint };

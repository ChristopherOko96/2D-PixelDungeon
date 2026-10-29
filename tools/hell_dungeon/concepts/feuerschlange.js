// Ignaroth concept "Feuerschlange" (preview only, not wired into the game):
// a long, sinuous predator. An S-curved neck rises high and the head hangs over the hero,
// spines and frills run along neck, back and tail, the wings (forms 3 and 4) hang half
// spread like a torn cape, the whip tail ends in a flame, the limbs are thin and clawed.
//
// Same four forms and palettes as hell_monsters.js (DRAKE): 1 salamander, 2 young drake,
// 3 glow drake, 4 obsidian form. Depth: every mass is shaded as a volume (5 tones from the
// form's ramp, key light top left, rim light from the lava below), far limbs and the far
// wing use a darker, cooler ramp, masses overlap (shoulder over neck, wing over body).
//
// Rig contract: every draw call is tagged with the rig part ids of export_rigs.js (PARENT, Z)
// and every pivot and point is recorded as a joint, so each part renders isolated. The
// previews are composed from the isolated parts in Z order, the way the game draws the rig.
//
// Usage: node tools/hell_dungeon/concepts/feuerschlange.js [repo_root]
//   writes production/qa/evidence/drake-concepts/feuerschlange_{lineup,form4,ingame,ingame_zoom}.png
//   and prints a rig check per form (parts, joints, pivot distances, visible pixels).
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const HM = require('../hell_monsters.js');
const { Painter, hexToRgb } = HM;
const { encodePng } = require('../monster_sheet.js');
const RIG = require('../export_rigs.js'); // PARENT, Z, FORMS; requiring it runs nothing

// ---------- palette (hell_monsters.js, 0x72 DungeonTileset II) ----------
const K = '#222222', BLK = '#0e0c0c', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a';
const RED = '#da4e38', CRIM = '#9f294e', MAROON = '#62232f', PLUM = '#38262d', PURP = '#5f2d56', MAG = '#993970';
const PINK = '#dc4a7b', LILAC = '#f0b3dd', VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579';
const YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025', BROWN = '#8f4029';
const MUD = '#775c55', STONE = '#483b3a', COAL = '#3b3332', SOOT = '#302c2b', NEARBLK = '#2b2929';
const FIRE = [WHITE, YEL, ORA, RED, CRIM];
const VOIDFIRE = [LILAC, VIO, VIOD, PURP, INDIGO];
// Derived shades (mixes of two palette colours) for the far side: darker and cooler.
function mix(a, b, t) {
  const A = hexToRgb(a), B = hexToRgb(b);
  return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join('');
}
const DUSK = mix(PLUM, INDIGO, .3);       // far crimson hide, deepest wing tone
const EMBERDK = mix(MAROON, PLUM, .5);    // far side of the red forms
const OBSFAR = mix(NEARBLK, INDIGO, .18); // far obsidian
const OBSFAR2 = mix(SOOT, INDIGO, .22);
const VOIDDK = mix(INDIGO, BLK, .45);     // deepest void membrane
const OBSGLOSS = mix(STONE, VIO, .45);    // obsidian's glossy highlight, the void fire mirrored in it

// ---------- the four forms ----------
// Ramps have five tones: [deep, shadow, base, light, highlight]. s scales the whole skeleton
// (base units: form 4 at s = 1); legK, riseK, neckK, headK, tailK change the proportions.
const FS = [null,
  { name: 'SALAMANDER', s: .5, legK: .45, riseK: .3, neckK: .9, headK: 1.4, tailK: 1.15, bodyK: .9, arm: 'plant', wings: false, horns: 0,
    hide: [MAROON, BROWN, BORA, ORA, YEL], far: [PLUM, MAROON, BROWN, BORA, BORA], belly: [BORA, ORA, YEL, WHITE, WHITE],
    horn: [MUD, TAN, BONE, WHITE, WHITE], rim: YEL, fire: FIRE, spots: [YEL, ORA], seam: null, flame: 10, mouth: MAROON, spine: [MAROON, BROWN, BORA, ORA, YEL], eye: [YEL, WHITE, WHITE], bias: -.22, bellyMax: 2 },
  { name: 'JUNGDRACHE', s: .53, legK: .75, riseK: .7, neckK: 1, headK: 1.15, tailK: 1.1, bodyK: .95, arm: 'plant', wings: false, horns: 1,
    hide: [MAROON, CRIM, RED, ORA, YEL], far: [PLUM, MAROON, CRIM, RED, RED], belly: [BROWN, BORA, ORA, YEL, WHITE],
    horn: [MUD, TAN, BONE, WHITE, WHITE], rim: ORA, fire: FIRE, scars: ORA, seam: null, flame: 9, mouth: MAROON, spine: [MUD, TAN, BONE, WHITE, WHITE], eye: [YEL, WHITE, WHITE], bias: -.12 },
  { name: 'GLUTDRACHE', s: .66, legK: 1.12, riseK: 1, neckK: 1, headK: 1.14, tailK: 1, bodyK: 1.1, arm: 'raise', wings: true, horns: 2,
    hide: [PLUM, MAROON, CRIM, RED, ORA], far: [DUSK, PLUM, EMBERDK, MAROON, CRIM], belly: [BROWN, BORA, ORA, YEL, WHITE],
    horn: [MUD, TAN, BONE, WHITE, WHITE], rim: ORA, fire: FIRE, scars: ORA, seam: YEL, flame: 12, mouth: MAROON, spine: [MUD, TAN, BONE, WHITE, WHITE], eye: [ORA, YEL, WHITE],
    wing: [DUSK, PLUM, MAROON, CRIM, RED], wingFar: [BLK, DUSK, PLUM, EMBERDK, MAROON], ember: [ORA, YEL], cracks: [ORA, YEL], throat: [MAROON, CRIM, BORA, ORA, YEL], bias: -.1 },
  { name: 'OBSIDIANFORM', s: .84, legK: 1.12, riseK: 1, neckK: 1.02, headK: 1.14, tailK: 1, bodyK: 1.15, arm: 'raise', wings: true, horns: 3,
    hide: [BLK, NEARBLK, COAL, STONE, OBSGLOSS], far: [BLK, BLK, OBSFAR, OBSFAR2, COAL], belly: [INDIGO, PURP, MAG, VIO, LILAC],
    horn: [BROWN, BORA, YEL, WHITE, WHITE], rim: VIOD, fire: VOIDFIRE, seam: VIO, flame: 15, mouth: PURP, crystals: true, spine: [BLK, NEARBLK, STONE, MUD, YEL], eye: [ORA, YEL, WHITE], bias: -.08,
    wing: [VOIDDK, INDIGO, PURP, MAG, VIO], wingFar: [BLK, VOIDDK, INDIGO, PURP, MAG], ember: [VIO, LILAC], cracks: [VIOD, VIO], throat: [PURP, MAG, PINK, LILAC, WHITE],
    core: [INDIGO, VIOD, VIO, LILAC, WHITE] },
];
// The rig part of each of the ten tail steps (as DRAKE_TAIL_PART in hell_monsters.js).
const TAIL_PART = [0, 1, 1, 2, 2, 2, 2, 3, 4, 5, 5];

// ---------- shapes: { box: [x0, y0, x1, y1], in(x, y) } in frame px (continuous) ----------
const ell = (cx, cy, rx, ry, ang) => {
  const c = Math.cos(ang || 0), sn = Math.sin(ang || 0), r = Math.max(rx, ry);
  return { box: [cx - r, cy - r, cx + r, cy + r], in: (x, y) => { const u = (x - cx) * c + (y - cy) * sn, v = (y - cy) * c - (x - cx) * sn; return (u / rx) ** 2 + (v / ry) ** 2 <= 1; } };
};
const poly = pts => {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  return { box: [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)], in: (x, y) => {
    let c = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const [xi, yi] = pts[i], [xj, yj] = pts[j];
      if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
    }
    return c;
  } };
};
// A tube along dense samples [x, y, r].
const tube = smp => {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y, r] of smp) { x0 = Math.min(x0, x - r); y0 = Math.min(y0, y - r); x1 = Math.max(x1, x + r); y1 = Math.max(y1, y + r); }
  return { box: [x0, y0, x1, y1], in: (x, y) => { for (const [sx, sy, r] of smp) if ((x - sx) ** 2 + (y - sy) ** 2 <= r * r) return true; return false; } };
};
const uni = (...ss) => { ss = ss.filter(Boolean); return { box: [Math.min(...ss.map(s => s.box[0])), Math.min(...ss.map(s => s.box[1])), Math.max(...ss.map(s => s.box[2])), Math.max(...ss.map(s => s.box[3]))], in: (x, y) => ss.some(s => s.in(x, y)) }; };
const sub = (a, ...bs) => ({ box: a.box, in: (x, y) => a.in(x, y) && !bs.some(b => b.in(x, y)) });
const inter = (a, b) => ({ box: a.box, in: (x, y) => a.in(x, y) && b.in(x, y) });

// Catmull-Rom through control points [x, y, r], sampled about every `step` px: [[x, y, r, tx, ty]].
function spline(ctrl, step) {
  step = step || .5;
  const P = [ctrl[0], ...ctrl, ctrl[ctrl.length - 1]], out = [];
  for (let i = 1; i < P.length - 2; i++) {
    const [p0, p1, p2, p3] = [P[i - 1], P[i], P[i + 1], P[i + 2]];
    const n = Math.max(2, Math.ceil(Math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / step));
    for (let k = 0; k < n; k++) {
      const t = k / n, t2 = t * t, t3 = t2 * t;
      const f = (a, b, c, d) => .5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
      out.push([f(p0[0], p1[0], p2[0], p3[0]), f(p0[1], p1[1], p2[1], p3[1]), p1[2] + (p2[2] - p1[2]) * t]);
    }
  }
  const last = ctrl[ctrl.length - 1]; out.push([last[0], last[1], last[2]]);
  for (let i = 0; i < out.length; i++) {
    const a = out[Math.max(0, i - 1)], b = out[Math.min(out.length - 1, i + 1)], l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    out[i][3] = (b[0] - a[0]) / l; out[i][4] = (b[1] - a[1]) / l;
  }
  return out;
}

// ---------- volume shading ----------
const LIGHT = (() => { const v = [-.5, -.7, .62], l = Math.hypot(...v); return v.map(c => c / l); })();
const RIMD = (() => { const v = [.25, 1], l = Math.hypot(...v); return v.map(c => c / l); })();
const KEY = (x, y) => (y + 4096) * 16384 + (x + 4096);
const N8 = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
const N4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const hash = (x, y, s) => { const v = Math.sin(x * 12.9898 + y * 78.233 + (s || 0) * 37.719) * 43758.5453; return v - Math.floor(v); };
function raster(shape) {
  const [bx0, by0, bx1, by1] = shape.box, pts = [], has = new Set();
  for (let y = Math.floor(by0) - 1; y <= Math.ceil(by1) + 1; y++) for (let x = Math.floor(bx0) - 1; x <= Math.ceil(bx1) + 1; x++) if (shape.in(x + .5, y + .5)) { pts.push([x, y]); has.add(KEY(x, y)); }
  return { pts, has };
}
// Per pixel of the mask: distance to the nearest outside pixel and the outward direction.
function edt(m) {
  const outs = [], seen = new Set();
  for (const [x, y] of m.pts) for (const [dx, dy] of N8) { const k = KEY(x + dx, y + dy); if (!m.has.has(k) && !seen.has(k)) { seen.add(k); outs.push([x + dx, y + dy]); } }
  const info = new Map(); let maxd = 1;
  for (const [x, y] of m.pts) {
    let best = Infinity, bx = 0, by = 0;
    for (const [qx, qy] of outs) { const d = (qx - x) ** 2 + (qy - y) ** 2; if (d < best) { best = d; bx = qx - x; by = qy - y; } }
    const d = Math.sqrt(best); info.set(KEY(x, y), [d, bx / d, by / d]); maxd = Math.max(maxd, d);
  }
  return { info, maxd };
}
// Shades `shape` as a rounded volume with a five-tone ramp. Options:
//   light: a larger shape whose silhouette drives the normals (so a part blends into its
//          neighbour without a dark ring), clip: paint only inside this shape,
//   R: profile radius, bias: brighter (+) / darker (-), shift: ramp steps, max: highest tone,
//   rim: rim colour on lower edges, contour: colour where the shape lies over this part's
//   earlier pixels (false: none), scales: scale texture, tex(x, y, idx) -> idx.
function vol(P, shape, ramp, o) {
  if (!P.keep()) return;
  o = o || {};
  const lightShape = o.light ? uni(o.light, shape) : shape;
  const m = raster(lightShape), paintShape = o.clip ? inter(shape, o.clip) : shape;
  const paint = (o.light || o.clip) ? raster(paintShape) : m;
  if (!paint.pts.length) return;
  const { info, maxd } = edt(m), R = o.R || Math.max(1.5, maxd - .5);
  const contour = o.contour === undefined ? K : o.contour, rim = o.rim;
  const out = [];
  for (const [x, y] of paint.pts) {
    const [d, ox, oy] = info.get(KEY(x, y)) || [1, 0, 1];
    const t = Math.max(0, Math.min(1, 1 - (d - 1) / R)), nz = Math.sqrt(Math.max(0, 1 - t * t));
    const I = ox * t * LIGHT[0] + oy * t * LIGHT[1] + nz * LIGHT[2] + (o.bias || 0);
    let idx = I > .93 ? 4 : I > .72 ? 3 : I > .25 ? 2 : I > -.25 ? 1 : 0;
    if (o.scales && idx >= 1 && idx <= 3 && d > 2 && (y % 4) === 0 && ((x + (Math.floor(y / 4) % 2) * 3) % 6) === 0) idx--;
    if (o.tex) idx = o.tex(x, y, idx, d);
    idx = Math.max(0, Math.min(o.max == null ? ramp.length - 1 : o.max, idx + (o.shift || 0)));
    let c = ramp[idx];
    if (rim && d < 1.6 && ox * RIMD[0] + oy * RIMD[1] > .62) c = rim;
    if (contour) for (const [dx, dy] of N4) {
      const qx = x + dx, qy = y + dy;
      if (!paint.has.has(KEY(qx, qy)) && P.inside(qx, qy) && P.solid[qy * P.w + qx]) { c = contour; break; }
    }
    out.push([x, y, c]);
  }
  for (const [x, y, c] of out) P.dot(x, y, c);
}
// Flat fill (2 tones by own edge: light on top-left, shadow on bottom-right).
function flat(P, shape, c, o) {
  if (!P.keep()) return;
  const m = raster(shape);
  for (const [x, y] of m.pts) P.dot(x, y, typeof c === 'function' ? c(x, y, m) : c);
}
// A tapered, curved spike/horn: tube from the base (r0) to a point.
function spike(P, ctrl, ramp, o) { vol(P, tube(spline(ctrl, .35)), ramp, Object.assign({ contour: ramp[0], R: 1.6 }, o)); }

// A glowing crack (lava or void fire under the hide): a jagged walk over this part's own pixels,
// at least one pixel inside its edge. cols: [glow, core].
function crack(P, x, y, ang, len, cols, seed) {
  if (!P.keep() || !cols) return;
  const on = (px, py) => { px = Math.round(px); py = Math.round(py); if (!P.inside(px, py) || !P.solid[py * P.w + px]) return false; return N4.every(([dx, dy]) => P.inside(px + dx, py + dy) && P.solid[(py + dy) * P.w + px + dx]); };
  for (let i = 0; i < len; i++) {
    ang += (hash(i, seed, 3) - .5) * 1.3;
    x += Math.cos(ang); y += Math.sin(ang);
    if (on(x, y)) P.dot(x, y, i % 3 === 1 ? cols[1] : cols[0]);
    if (hash(i, seed, 8) > .86 && i > 2) crack(P, x, y, ang + (hash(i, seed) > .5 ? 1 : -1), Math.round(len * .35), cols, seed + 17 + i);
  }
}

// ---------- the dragon ----------
// draw(P, p, frame, place): place = { ox } shifts the skeleton (hip x); the feet stand on the
// bottom row of the frame. Every coordinate below is in base units (form 4 at s = 1) relative
// to the hip column and the ground line, mapped by X() and Y().
function draw(P, p, frame, place) {
  const o = FS[p], s = o.s, foot = P.h - 1, ox = place.ox;
  const X = x => ox + x * s, Y = y => foot + y * s, pt = (x, y) => [X(x), Y(y)];
  const legH = 30 * o.legK, hip = [0, -legH], chest = [26, -legH - 15 * o.riseK], bk = o.bodyK;
  const hide = o.hide, far = o.far, horn = o.horn;
  const rim = o.rim, scales = p >= 3;
  // ---- skeleton ----
  const NB = [chest[0] + 2, chest[1] - 9];
  const neckCtl = [[0, 0, 7.4], [7, -10, 6.6], [2, -22, 5.8], [5, -33, 5.3], [14, -40, 5.1], [24, -39, 5]].map(([x, y, r]) => [X(NB[0] + x * o.neckK), Y(NB[1] + y * o.neckK), r * s * bk]);
  const neck = spline(neckCtl, .4);
  const HJ = [neck[neck.length - 1][0], neck[neck.length - 1][1]], ha = .74, hk = o.headK * s;
  const hu = [Math.cos(ha), Math.sin(ha)], hv = [-Math.sin(ha), Math.cos(ha)];
  const H = (u, v) => [HJ[0] + (u * hu[0] + v * hv[0]) * hk, HJ[1] + (u * hu[1] + v * hv[1]) * hk];
  const torsoCtl = [[hip[0] - 5, hip[1] + 1, 10.5], [12, (hip[1] + chest[1]) / 2 - 1, 12.5], [chest[0], chest[1], 13.5], [chest[0] + 5, chest[1] + 3, 10]].map(([x, y, r]) => [X(x), Y(y), r * s * bk]);
  const torsoS = spline(torsoCtl, .5), torso = tube(torsoS);
  const tdir = [(chest[0] - hip[0]), (chest[1] - hip[1])], tl = Math.hypot(...tdir); tdir[0] /= tl; tdir[1] /= tl;
  const dors = [tdir[1], -tdir[0]]; // dorsal normal of the torso (up and back)
  const WR = [chest[0] - 14, chest[1] - 6];

  // ---- far wing (behind everything) ----
  if (o.wings) {
    const r = [WR[0] + 6, WR[1] - 3];
    P.part('wing_far').joint('wing_far', X(r[0]) + .5, Y(r[1]) + .5);
    wing(P, o, s, X, Y, r, { E: [-2, -34], W: [-9, -54], T: [[-42, -57], [-58, -42], [-62, -21], [-50, -4]], B: [-12, 2] }, o.wingFar, true);
  }
  // ---- tail: ten steps in five rig parts, one shading for the whole tail ----
  const tk = o.tailK;
  const tailCtl = [[-4, hip[1] + 2, 9], [-16, hip[1] * .55 - 4, 7.4], [-30, -6, 6], [-44, -4.5, 4.8], [-57, -8, 3.8], [-67, -5.5, 2.9], [-75, -10, 2.1], [-79, -18, 1.4]]
    .map(([x, y, r], i) => [X(i ? x * tk : x), Y(Math.min(y, -r * .9)), r * s * bk]);
  const tail = spline(tailCtl, .4), tailAll = tube(tail);
  const tailStep = [0];
  { let acc = 0; const len = [0]; for (let i = 1; i < tail.length; i++) { acc += Math.hypot(tail[i][0] - tail[i - 1][0], tail[i][1] - tail[i - 1][1]); len.push(acc); } for (let k = 1; k <= 10; k++) tailStep.push(len.findIndex(l => l >= acc * k / 10)); tailStep[10] = tail.length - 1; }
  const tailPart = id => {
    const ks = []; for (let k = 1; k <= 10; k++) if (TAIL_PART[k] === id) ks.push(k);
    return [tailStep[ks[0] - 1], tailStep[ks[ks.length - 1]]];
  };
  for (const id of [5, 4, 3, 1, 2]) {
    const [i0, i1] = tailPart(id), name = 'tail_' + id, smp = tail.slice(i0, i1 + 1);
    P.part(name).joint(name, tail[i0][0] + .5, tail[i0][1] + .5);
    vol(P, tube(smp), hide, { light: tailAll, rim, contour: false, scales, bias: o.bias || 0 });
    const tb = tube(smp.map(([x, y, r, tx, ty]) => { const vn = ty < 0 ? [ty, -tx] : [-ty, tx]; const n = vn[1] > 0 ? vn : [-vn[0], -vn[1]]; return [x + n[0] * r * .6, y + n[1] * r * .6, r * .55]; }));
    vol(P, tube(smp), o.belly, { light: tailAll, clip: inter(tb, tube(smp)), contour: false, max: 2, bias: (o.bias || 0) + .1,
      tex: (x, y, idx) => (Math.round(x * .5) % Math.max(2, Math.round(3 * s + 1))) === 0 ? 0 : idx });
    if (id === 1 || id === 2) crack(P, smp[2][0], smp[2][1] - 1, Math.PI, Math.round(smp.length * .25), o.cracks, 40 + id);
    // spines along the top of the tail, shrinking towards the tip
    for (let i = i0 + 5; i < i1; i += Math.max(5, Math.round(9 * s))) {
      const [x, y, rr, tx, ty] = tail[i], dn = [ty, -tx];
      if (dn[1] > 0) { dn[0] = -dn[0]; dn[1] = -dn[1]; }
      const h = rr * (p >= 3 ? 1 : .8) + 1.2, bx = x + dn[0] * rr * .85, by = y + dn[1] * rr * .85;
      if (rr < 1.2) continue;
      spike(P, [[bx + tx * rr * .3, by + ty * rr * .3, Math.max(.7, rr * .26)], [bx - tx * h * .55 + dn[0] * h * .75, by - ty * h * .55 + dn[1] * h * .75, .35]], o.spine, { rim: null });
    }
    if (o.spots) for (let i = i0 + 6; i < i1; i += 14) { const [x, y, rr] = tail[i]; if (rr > 1.5) P.dot(x - .5, y - rr * .45, hash(i, id) > .5 ? o.spots[0] : o.spots[1]); }
  }
  const tip = tail[tail.length - 1];
  P.part('tail_5').joint('tail_tip', tip[0] + .5, tip[1] + .5);
  P.part('tail_flame').joint('tail_flame', tip[0] + .5, tip[1] + .5);
  P.flame(tip[0] - Math.round(o.flame * .25), tip[1] + 1, Math.max(4, Math.round(o.flame * .55)), o.flame, { seed: 3, pal: o.fire, front: true });

  // ---- legs (far, then body, then near) ----
  const leg = (dx, dy, ramp, isFar) => {
    const hx = hip[0] + dx, hy = hip[1] + dy, L = legH;
    const knee = [hx + 9, hy + L * .45], hock = [hx + 2.5, -L * .2 - 1], toe = [hx + 12, -.6];
    P.joint(P.tag, X(hx) + .5, Y(hy) + .5);
    const thigh = ell(X(hx + 1.5), Y(hy + L * .12), (7.5 + L * .05) * s * bk, (L * .32 + 4) * s * bk, -.45);
    const shin = tube(spline([[X(knee[0]), Y(knee[1]), 3.8 * s], [X(hock[0]), Y(hock[1]), 2.4 * s]], .4));
    const meta = tube(spline([[X(hock[0]), Y(hock[1]), 2.2 * s], [X(toe[0] - 3), Y(toe[1] - .8), 1.7 * s], [X(toe[0]), Y(toe[1]), 1.5 * s]], .4));
    const opt = { rim: isFar ? null : rim, scales, bias: (o.bias || 0) + (isFar ? -.12 : .1) };
    vol(P, uni(shin, meta), ramp, Object.assign({}, opt, { contour: false }));
    vol(P, thigh, ramp, Object.assign({}, opt, { contour: ramp[0] }));
    // claws forward and a spur at the hock
    const cl = Math.max(1.2, 3.2 * s);
    for (let t = -1; t <= 1; t++) spike(P, [[X(toe[0] + t * 1.6), Y(-.8), .9 * s + .3], [X(toe[0] + t * 1.6) + cl, Y(-.2), .35]], isFar ? [horn[0], horn[0], horn[1], horn[1], horn[2]] : horn);
    spike(P, [[X(hock[0] - .5), Y(hock[1]), 1.1 * s + .2], [X(hock[0] - 4.5), Y(hock[1] + 2.5), .35]], horn, { shift: isFar ? -1 : 0 });
  };
  P.part('leg_far');
  leg(7, -2.5, far, true);

  // ---- body ----
  P.part('body').joint('body', X(hip[0]) + .5, Y(hip[1]) + .5).joint('core', X(chest[0] + 2) + .5, Y(chest[1] + 2) + .5);
  const chestE = ell(X(chest[0] + 1), Y(chest[1] + 1), 12.5 * s * bk, 14.5 * s * bk, -.5);
  const bodyShape = uni(torso, chestE);
  vol(P, bodyShape, hide, { rim, scales, contour: false, bias: o.bias || 0 });
  // the belly: plates on the ventral side, lit by the same normals
  const vent = [-dors[0], -dors[1]];
  const bellyS = tube(torsoS.map(([x, y, r]) => [x + vent[0] * r * .62, y + vent[1] * r * .62, r * .7]));
  vol(P, bodyShape, o.belly, { clip: uni(bellyS, ell(X(chest[0] + 6), Y(chest[1] + 3), 6 * s * bk, 11 * s * bk, -.4)), rim, contour: hide[0], max: o.bellyMax || 3,
    tex: (x, y, idx) => (Math.round((x - X(0)) * tdir[0] * .5 + (y - Y(0)) * tdir[1] * .5 + 1000) % Math.max(2, Math.round(2.6 * s * 1.4))) === 0 ? 0 : idx });
  if (o.seam && P.keep()) for (let k = 0; k < 5; k++) { const u = .3 + k * .15, x = X(hip[0] + (chest[0] - hip[0]) * u) + vent[0] * 9 * s, y = Y(hip[1] + (chest[1] - hip[1]) * u) + vent[1] * 9 * s; P.glow(x, y, k % 2 ? o.seam : o.belly[3]); }
  // spines along the back, from the shoulders to the hip
  for (let k = 0; k < (p >= 3 ? 7 : 5); k++) {
    const u = .95 - k * (p >= 3 ? .14 : .2), sp = torsoS[Math.round(u * (torsoS.length - 1))], rr = sp[2];
    const bx = sp[0] + dors[0] * rr * .82, by = sp[1] + dors[1] * rr * .82, h = (p >= 3 ? 7.5 : 4.5) * s * (1 - k * .06) + 1;
    spike(P, [[bx + tdir[0] * 1.2 * s, by + tdir[1] * 1.2 * s, 1.1 * s + .3], [bx + dors[0] * h * .6 - tdir[0] * h * .3, by + dors[1] * h * .6 - tdir[1] * h * .3, .6 * s + .2], [bx + dors[0] * h - tdir[0] * h * .7, by + dors[1] * h - tdir[1] * h * .7, .35]], o.spine);
  }
  if (o.scars && P.keep()) for (const [a, b, c, d] of [[8, -4, 11, -1], [14, -8, 16, -5], [4, 2, 7, 4]]) { const x0 = X(hip[0] + a), y0 = Y(hip[1] + b), x1 = X(hip[0] + c), y1 = Y(hip[1] + d), n = Math.ceil(Math.hypot(x1 - x0, y1 - y0)); for (let i = 0; i <= n; i++) P.dot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, i % 3 === 1 ? YEL : o.scars); }
  if (o.spots && P.keep()) for (const [a, b] of [[4, -6], [10, -9], [16, -7], [21, -11], [-2, -4]]) { const x = X(hip[0] + a), y = Y(hip[1] + b); P.dot(x, y, o.spots[0]).dot(x + 1, y, o.spots[1]); }
  if (o.core) { const c = [X(chest[0] + 4), Y(chest[1] + 1)]; vol(P, ell(c[0], c[1], 2.6 * s, 3 * s, -.4), o.core, { contour: PURP, bias: .25 }); P.glow(c[0] - .5, c[1] - 1, WHITE).glow(c[0] + .5, c[1], frame % 4 < 2 ? LILAC : WHITE); }

  crack(P, X(hip[0] + 4), Y(hip[1] - 2), -.4, Math.round(16 * s + 4), o.cracks, 1);
  crack(P, X(chest[0] - 8), Y(chest[1] + 1), 2.2, Math.round(12 * s + 3), o.cracks, 2);
  crack(P, X(hip[0] + 14), Y(hip[1] + 6), .3, Math.round(10 * s + 3), o.cracks, 3);
  P.part('leg_near');
  leg(-1, 0, hide, false);
  crack(P, X(hip[0] + 1), Y(hip[1] + 2), 1.6, Math.round(12 * s + 3), o.cracks, 5);

  // ---- near wing (in front of body and legs, behind the neck) ----
  if (o.wings) {
    P.part('wing_near').joint('wing_near', X(WR[0]) + .5, Y(WR[1]) + .5);
    wing(P, o, s, X, Y, WR, { E: [-11, -30], W: [-23, -48], T: [[-60, -46], [-76, -24], [-74, 0], [-58, 19]], B: [-24, 7] }, o.wing, false);
  }

  // ---- neck: S-curve, frill along the back, belly plates along the front ----
  const nd = i => [neck[i][3], neck[i][4]], nDors = i => { const [tx, ty] = nd(i); return [ty, -tx]; };
  const throatI = Math.round(neck.length * .2);
  const gland = (() => { const [x, y, r] = neck[throatI], [dx, dy] = nDors(throatI); return [x - dx * r * .72, y - dy * r * .72]; })();
  P.part('neck').joint('neck', neck[0][0] + .5, neck[0][1] + .5).joint('head', HJ[0] + .5, HJ[1] + .5).joint('throat_at', gland[0] + .5, gland[1] + .5);
  const neckShape = tube(neck);
  // frill membrane between the spines (forms 3, 4), behind the neck
  const spines = [];
  for (let i = 6; i < neck.length - 4; i += Math.max(4, Math.round(9 * s))) {
    const [x, y, r] = neck[i], [dx, dy] = nDors(i), [tx, ty] = nd(i), h = (p >= 3 ? 7 : 4) * s + 1.5;
    spines.push([[x + dx * r * .8, y + dy * r * .8, Math.max(.7, 1 * s)], [x + dx * (r + h * .55) - tx * h * .6, y + dy * (r + h * .55) - ty * h * .6, .35]]);
  }
  if (p >= 3 && spines.length > 1) {
    const edge = spines.map(sp => sp[1]), base = spines.map(sp => sp[0]).reverse();
    const sag = edge.flatMap((e, i) => i ? [[(e[0] + edge[i - 1][0]) / 2 + (base[base.length - i][0] - e[0]) * .25, (e[1] + edge[i - 1][1]) / 2 + (base[base.length - i][1] - e[1]) * .25], e] : [e]);
    vol(P, poly([...sag.map(q => [q[0], q[1]]), ...base.map(q => [q[0], q[1]])]), o.wing, { contour: false, R: 2, shift: -1, max: 1 });
  }
  vol(P, neckShape, hide, { light: uni(neckShape, torso), rim, contour: false, scales, bias: o.bias || 0 });
  const nBelly = tube(neck.map(([x, y, r, tx, ty]) => [x - ty * r * .62, y + tx * r * .62, r * .5]));
  vol(P, neckShape, o.belly, { clip: inter(nBelly, neckShape), light: uni(neckShape, torso), rim, contour: hide[0], max: 3,
    tex: (x, y, idx) => { let best = 0, bd = Infinity; for (let i = 0; i < neck.length; i += 2) { const d = (neck[i][0] - x - .5) ** 2 + (neck[i][1] - y - .5) ** 2; if (d < bd) { bd = d; best = i; } } return best % Math.max(5, Math.round(7 * s)) < 2 ? 0 : idx; } });
  for (const sp of spines) spike(P, sp, o.spine);
  { const i = Math.round(neck.length * .45), [x, y] = neck[i]; crack(P, x, y, -1.4, Math.round(10 * s + 3), o.cracks, 7); }

  // ---- void crystals on the shoulders (form 4), in front of the wings ----
  if (o.crystals) {
    [[.84, 17, 6.6, .12], [.68, 15, 6, .3], [.52, 12.5, 5.4, .5]].forEach(([u, len, wd, lean], i) => {
      const id = 'crystal_' + (i + 1), sp = torsoS[Math.round(u * (torsoS.length - 1))], rr = sp[2];
      const bx = sp[0] + dors[0] * rr * .55, by = sp[1] + dors[1] * rr * .55;
      const a = -Math.PI / 2 - lean, dx = Math.cos(a), dy = Math.sin(a), nx = -dy, ny = dx, L = len * s, W = wd * s / 2;
      const at = (l, w) => [bx + dx * L * l + nx * W * w, by + dy * L * l + ny * W * w];
      P.part(id).joint(id, bx, by);
      vol(P, poly([at(-.05, -.75), at(.62, -1), at(1, 0), at(.62, 1), at(-.05, .75)]), [INDIGO, VIOD, VIO, LILAC, WHITE], { contour: INDIGO, bias: .15, R: 2.5 });
      flat(P, poly([at(0, .1), at(.62, .15), at(.97, 0), at(.62, .95), at(0, .7)]), (x, y) => hash(x, y, i) > .8 ? VIOD : INDIGO);
      if (P.keep()) { const g = at(.82, -.1), h = at(.5, -.45); P.glow(g[0], g[1], WHITE).glow(h[0], h[1], LILAC).glow(g[0] - dx, g[1] - dy, LILAC); }
    });
  }

  // ---- arm: thin, long hooked claws ----
  const SH = [chest[0] + 5, chest[1] + 2];
  let EL, WRs, claws;
  if (o.arm === 'raise') {
    EL = [SH[0] + 4, SH[1] + 12]; WRs = [EL[0] + 13, EL[1] - 6];
    claws = [[3, 5, 6.5, 8.5], [4.5, 2.5, 8.5, 5], [5, -.5, 9.5, 1.5]].map(([a, b, c, d]) => [[WRs[0] + 1.5, WRs[1] + .5], [WRs[0] + a, WRs[1] + b], [WRs[0] + c, WRs[1] + d]]);
  } else {
    EL = [SH[0] - 3, SH[1] + (-SH[1]) * .5]; WRs = [SH[0] + 5, -3.2];
    claws = [[3, .5, 6.5, 2.4], [3.8, -1.2, 7.4, 1.2], [2.4, 1.6, 5.2, 3]].map(([a, b, c, d]) => [[WRs[0] + 1, WRs[1]], [WRs[0] + a, WRs[1] + b], [WRs[0] + c, WRs[1] + d]]);
  }
  const hand = claws[0][2];
  P.part('arm').joint('arm', X(SH[0]) + .5, Y(SH[1]) + .5).joint('hand', X(hand[0]) + .5, Y(hand[1]) + .5);
  {
    const up = tube(spline([[X(SH[0]), Y(SH[1]), 3.6 * s * bk], [X(EL[0]), Y(EL[1]), 2.4 * s]], .4));
    const lo = tube(spline([[X(EL[0]), Y(EL[1]), 2.3 * s], [X(WRs[0]), Y(WRs[1]), 1.7 * s]], .4));
    const sh = ell(X(SH[0]), Y(SH[1] + 1), 5 * s * bk, 6.5 * s * bk, -.3);
    vol(P, uni(lo, ell(X(WRs[0] + .5), Y(WRs[1]), 2.3 * s, 1.9 * s, -.3)), hide, { rim, contour: hide[0] });
    vol(P, uni(sh, up), hide, { rim, scales, contour: K, bias: o.bias || 0 });
    for (const c of claws) spike(P, [[X(c[0][0]), Y(c[0][1]), Math.max(.8, 1.1 * s)], [X(c[1][0]), Y(c[1][1]), Math.max(.6, .75 * s)], [X(c[2][0]), Y(c[2][1]), .35]], horn);
    spike(P, [[X(EL[0]), Y(EL[1]), 1.2 * s], [X(EL[0] - 4), Y(EL[1] + 2), .35]], horn);
  }

  // ---- throat gland on the front of the neck (forms 3, 4) ----
  if (o.throat) {
    const [tx, ty] = nd(throatI), ang = Math.atan2(ty, tx);
    P.part('throat').joint('throat', gland[0] + .5, gland[1] + .5);
    vol(P, ell(gland[0], gland[1], 3.6 * s + .6, 2 * s + .6, ang), o.throat, { contour: o.throat[0], bias: -.15, R: 2, max: 2 });
    if (P.keep()) for (const k of [-1, 0, 1]) { const c = [gland[0] + tx * k * 2 * s, gland[1] + ty * k * 2 * s]; P.dot(c[0], c[1], o.throat[3]).dot(c[0] + ty * .9, c[1] - tx * .9, o.throat[2]); }
    if (p === 4 && P.keep()) P.glow(gland[0], gland[1], WHITE);
  }

  // ---- jaw (behind the head): lower jaw, glowing inside of the mouth, lower fangs ----
  const open = .27, hinge = H(3, 4.4), jc = Math.cos(open), js = Math.sin(open);
  const J = (u, v) => { const du = u - 3, dv = v - 4.4, ru = du * jc - dv * js, rv = du * js + dv * jc; return H(3 + ru, 4.4 + rv); };
  const skullRamp = p === 4 ? [BLK, NEARBLK, COAL, STONE, MUD] : hide, teeth = [TAN, BONE, WHITE, WHITE, WHITE];
  P.part('jaw').joint('jaw', hinge[0] + .5, hinge[1] + .5).joint('mouth', ...J(24, 3.4).map(v => v + .5));
  {
    vol(P, poly([H(4, 1.4), H(28, 1.6), J(28, 3.8), J(5, 5)]), [BLK, o.mouth, o.mouth, o.mouth, o.mouth], { contour: false, R: 1 });
    if (P.keep()) for (let u = 6; u < 25; u += 1.5) { const q = J(u, 3.2 + (u < 12 ? .8 : 0)); P.dot(q[0], q[1], u % 3 < 1.5 ? (p === 4 ? VIO : ORA) : (p === 4 ? MAG : RED)); }
    vol(P, poly([J(1, 3.6), J(10, 4), J(26, 3.7), J(28.5, 4.6), J(25, 7), J(13, 8.8), J(3, 8.4)]), skullRamp, { contour: false, rim, bias: (o.bias || 0) - .05 });
    for (const [u, l] of (p <= 2 ? [[21, 2.6]] : [[14, 2], [20.5, 2.8], [25.5, 1.8]])) { const b = J(u, 3.9), t = J(u + .5, 3.9 - l); spike(P, [[b[0], b[1], .8], [t[0], t[1], .3]], teeth, { contour: false }); }
    if (p >= 2) { const b = J(17, 8.2), t = J(13, 11.5); spike(P, [[b[0], b[1], 1.2 * hk], [t[0], t[1], .35]], horn); }
  }

  // ---- head: long skull looking down, a lit snout bridge, heavy brow over a burning eye ----
  P.part('head');
  {
    const skull = uni(ell(...H(6, -1), 8.6 * hk, 7.2 * hk, ha), poly([H(8, -7), H(19, -5.6), H(27.5, -3.6), H(30, -1.4), H(29.5, 1.6), H(24, 2.9), H(12, 3.6), H(2, 4.8)]));
    // cheek frill: three spikes back along the jaw line
    for (const [u, v, l, w] of [[1, 3.4, 8, 1.5], [-.5, .5, 9.5, 1.7], [.5, -2.8, 7.5, 1.4]]) {
      const b = H(u, v), t = H(u - l, v + l * .28), m = H(u - l * .5, v + l * .06);
      spike(P, [[b[0], b[1], w * hk], [m[0], m[1], w * .55 * hk], [t[0], t[1], .35]], o.spine);
    }
    vol(P, skull, skullRamp, { rim, contour: false, bias: (o.bias || 0) - .04 });
    // the bridge of the snout: a lit top plane (the head is turned a little towards the viewer)
    vol(P, poly([H(9, -6.8), H(19, -5.4), H(27.5, -3.5), H(29.3, -1.9), H(27, -2.1), H(18.5, -3.6), H(10, -4.6)]), skullRamp, { contour: false, bias: .28, R: 1.5 });
    // heavy brow ridge, its shadow falls on the eye
    vol(P, poly([H(1, -8), H(9, -9.6), H(17, -7.6), H(18.5, -5.2), H(14.5, -4.4), H(8, -5.2), H(2, -4.4)]), skullRamp, { contour: skullRamp[0], bias: .12 });
    flat(P, poly([H(10, -4.6), H(17, -4.4), H(16.4, -2.1), H(10.4, -2.7)]), BLK);
    for (const [u, l] of (p <= 2 ? [[19, 3.6], [26, 2.2]] : [[14, 2], [20, 3.8], [25, 2.4], [28.4, 1.5]])) { const b = H(u, 2.6), t = H(u - .3, 2.6 + l); spike(P, [[b[0], b[1], u === 20 ? 1 : .8], [t[0], t[1], .3]], teeth, { contour: false }); }
    if (P.keep()) {
      const n = H(27.4, -1.6); P.dot(n[0], n[1], BLK);
      if (o.seam) for (const [a, b] of [[3, -1], [4.5, 0], [6, .6], [7, 2]]) { const q = H(a, b); P.dot(q[0], q[1], o.seam); }
      if (o.scars) for (const [a, b] of [[20, -2], [21.5, -1], [23, 0]]) { const q = H(a, b); P.dot(q[0], q[1], o.scars); }
    }
  }
  // ---- horns: nubs (form 2), big swept-back horns (forms 3, 4) ----
  if (o.horns === 1) for (const [u, v, l] of [[2.5, -6, 4.5], [7, -7.6, 3.6]]) { const b = H(u, v), m = H(u - l * .6, v - l * .8), t = H(u - l * 1.3, v - l * 1.1); spike(P, [[b[0], b[1], 1.6 * hk], [m[0], m[1], .9 * hk], [t[0], t[1], .35]], horn); }
  if (o.horns >= 2) {
    P.part('horns').joint('horns', ...H(1, -5.4).map(v => v + .5));
    const L = o.horns === 3 ? 1.15 : 1;
    const hornPath = (u0, v0, k) => [[u0, v0, 2.6], [u0 - 7 * k * L, v0 - 6 * k, 2.2], [u0 - 15 * k * L, v0 - 8 * k, 1.7], [u0 - 23 * k * L, v0 - 6 * k, 1.1], [u0 - 28 * k * L, v0 - 1 * k, .35]];
    // the far horn first (darker, further forward), then the near one
    spike(P, hornPath(4.5, -7.6, .8).map(([u, v, r]) => [...H(u, v), r * hk]), horn, { shift: -1, contour: horn[0] });
    const near = hornPath(.5, -5.6, 1);
    spike(P, near.map(([u, v, r]) => [...H(u, v), r * hk]), horn, { contour: horn[0] });
    // growth rings on the near horn
    if (P.keep()) for (const t of [.2, .36, .52, .68]) { const i = Math.floor(t * 4), f = t * 4 - i, q = [near[i][0] + (near[i + 1][0] - near[i][0]) * f, near[i][1] + (near[i + 1][1] - near[i][1]) * f], w = near[i][2] * (1 - f) + near[i + 1][2] * f, c = H(q[0], q[1]), d = H(q[0] + .5, q[1] + w * .9); P.dot(c[0], c[1], horn[1]).dot(d[0], d[1], horn[0]); }
    // two brow spikes above the eye
    for (const [u, l] of [[9, 2.6], [13, 2]]) { const b = H(u, -8.6), t = H(u - l * 1.5, -8.6 - l); spike(P, [[b[0], b[1], .8 * hk], [t[0], t[1], .35]], o.spine); }
  }
  // ---- the eye on top: a burning slit under the brow ----
  P.part('head');
  if (P.keep()) {
    const eye = o.eye;
    if (p <= 2) {
      const [ex, ey] = H(13, -3.4).map(Math.round);
      for (const [dx, dy] of [[-1, 0], [2, 0], [0, -1], [1, -1], [0, 1], [1, 1]]) P.glow(ex + dx, ey + dy, BLK);
      P.glow(ex, ey, eye[0]).glow(ex + 1, ey, eye[1]);
    } else P.glow(...H(11.6, -3.6), eye[0]).glow(...H(13.1, -3.6), eye[1]).glow(...H(14.6, -3.4), eye[2]).glow(...H(13.6, -2.7), eye[0]);
    if (p >= 3) P.glow(...H(16, -3.1), eye[1]);
  }
  // ---- mouth flames (form 4): void fire dripping from both mouth corners ----
  if (p === 4) {
    const m1 = J(7, 4.8), m2 = J(18, 4.4);
    P.part('mouth_flame').joint('mouth_flame', m1[0] + .5, m1[1] + 1.5);
    P.flame(m1[0] - 1.5, m1[1] + 1, Math.round(2.6 * s), Math.round(5.5 * s), { seed: 11, pal: o.fire, front: true, dir: 1, lean: -2, sparks: false });
    P.flame(m2[0] - 1, m2[1] + 1, Math.round(2 * s), Math.round(4 * s), { seed: 17, pal: o.fire, front: true, dir: 1, lean: -1, sparks: false });
  }
}

// A torn, cape-like wing. g (base units, relative to the root r): E elbow, W wrist (the
// highest point), T four finger tips (leading to trailing), B where the membrane meets the flank.
// Panels between the fingers are shaded as folds (lit near the leading finger), the trailing
// edge is torn, has holes and smoulders (ember colours).
function wing(P, o, s, X, Y, r, g, ramp, isFar) {
  if (!P.keep()) return;
  const at = q => [X(r[0] + q[0]), Y(r[1] + q[1])];
  const R0 = at([0, 0]), E = at(g.E), W = at(g.W), T = g.T.map(at), B = at(g.B);
  const notch = (a, b, k) => [(a[0] + b[0]) / 2 * (1 - k) + W[0] * k, (a[1] + b[1]) / 2 * (1 - k) + W[1] * k];
  const edge = [T[0], notch(T[0], T[1], .2), T[1], notch(T[1], T[2], .24), T[2], notch(T[2], T[3], .22), T[3], notch(T[3], B, .1)];
  let memb = poly([R0, E, W, ...edge, B]);
  // tears: V cuts along the trailing edge and a few holes
  const cuts = [], holes = [];
  for (let i = 0; i < edge.length - 1; i++) {
    const a = edge[i], b = edge[i + 1];
    for (const f of [.3, .65]) {
      const hsh = hash(i, f * 10, isFar ? 7 : 3);
      if (hsh < .35) continue;
      const m = [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f], to = [W[0] - m[0], W[1] - m[1]], l = Math.hypot(...to);
      const d = (2 + hsh * 4) * s + 1, w = (1 + hsh) * s + .6, dir = [to[0] / l, to[1] / l], n = [-dir[1], dir[0]];
      cuts.push(poly([[m[0] + n[0] * w - dir[0], m[1] + n[1] * w - dir[1]], [m[0] - n[0] * w - dir[0], m[1] - n[1] * w - dir[1]], [m[0] + dir[0] * d, m[1] + dir[1] * d]]));
    }
  }
  for (const [i, f, k] of [[1, .55, .7], [2, .4, .55], [3, .6, .75]]) {
    const a = T[i - 1], b = T[i], m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], c = [m[0] + (W[0] - m[0]) * (1 - k), m[1] + (W[1] - m[1]) * (1 - k)];
    holes.push(ell(c[0], c[1], (1.4 + f) * s + .4, (1 + f) * s + .4, hash(i, 2) * 3));
  }
  memb = sub(memb, ...cuts, ...holes);
  const m = raster(memb), info = edt(m).info;
  const rays = [...T, B].map(q => Math.atan2(q[1] - W[1], q[0] - W[0]));
  const ember = o.ember;
  for (const [x, y] of m.pts) {
    const a = Math.atan2(y + .5 - W[1], x + .5 - W[0]);
    let panel = rays.length - 1, f = .5;
    for (let i = 0; i < rays.length - 1; i++) {
      const hi = rays[i], lo = rays[i + 1];
      if (a <= hi + .02 && a >= lo - .02) { panel = i; f = (hi - a) / Math.max(.01, hi - lo); break; }
    }
    if (a < rays[rays.length - 1]) { panel = rays.length - 1; f = .5; }
    const dist = Math.hypot(x + .5 - W[0], y + .5 - W[1]), maxL = Math.hypot(T[1][0] - W[0], T[1][1] - W[1]);
    let idx = [2, 2, 1, 1, 1][panel] + (f < .16 ? 1 : f > .78 ? -1 : 0) - (dist > maxL * .8 ? 1 : 0) + (dist < maxL * .3 ? 1 : 0);
    idx = Math.max(0, Math.min(3, idx));
    let c = ramp[idx];
    const [d, ox, oy] = info.get(KEY(x, y));
    if (d < 1.5 && ember && oy > .2 && dist > maxL * .45 && hash(x, y, 5) > (isFar ? .75 : .45)) c = hash(x, y, 9) > .7 ? ember[1] : ember[0];
    else if (d < 1.5 && oy > .5) c = ramp[0];
    P.dot(x, y, c);
  }
  // veins from the wrist into each panel
  for (let i = 0; i < T.length; i++) {
    const a = T[i], b = i + 1 < T.length ? T[i + 1] : B, mid = notch(a, b, .35);
    const n = Math.ceil(Math.hypot(mid[0] - W[0], mid[1] - W[1]));
    for (let k = 4; k < n; k += 1) { const x = W[0] + (mid[0] - W[0]) * k / n, y = W[1] + (mid[1] - W[1]) * k / n; if (m.has.has(KEY(Math.round(x - .5), Math.round(y - .5))) && k % 4 !== 3) P.dot(x - .5, y - .5, ramp[Math.max(0, (isFar ? 0 : 1))]); }
  }
  // bones: the arm (hide), the fingers (thin), a hooked thumb claw and knuckle spikes
  const hide = isFar ? o.far : o.hide, horn = o.horn;
  vol(P, tube(spline([[R0[0], R0[1], 3.4 * s], [E[0], E[1], 2.8 * s], [W[0], W[1], 2.2 * s]], .4)), hide, { contour: hide[0], rim: isFar ? null : o.rim, bias: isFar ? -.1 : 0 });
  for (let i = 0; i < T.length; i++) {
    const c = [(W[0] + T[i][0]) / 2 + (i - 1.5) * 1.2 * s, (W[1] + T[i][1]) / 2 - 1.5 * s];
    vol(P, tube(spline([[W[0], W[1], 1.5 * s], [c[0], c[1], 1 * s + .2], [T[i][0], T[i][1], .5]], .4)), hide, { contour: false, R: 1.2, shift: -1 });
  }
  spike(P, [[W[0], W[1], 1.6 * s], [W[0] + 1 * s, W[1] - 4.5 * s, .9 * s], [W[0] + 3.4 * s, W[1] - 6.5 * s, .35]], horn, { shift: isFar ? -1 : 0 });
  spike(P, [[E[0], E[1], 1.4 * s], [E[0] - 1.5 * s, E[1] - 3.8 * s, .35]], horn, { shift: isFar ? -1 : 0 });
}

// ---------- rendering (frame sized to the dragon) ----------
const LAYOUT = {};
// Measures the dragon on a large canvas and returns { W, H, ox } with a 2 px margin.
function layout(p) {
  if (LAYOUT[p]) return LAYOUT[p];
  const big = 400, H = 220, P = new Painter(big, H, 0);
  draw(P, p, 0, { ox: 200 });
  let x0 = big, x1 = -1, y0 = H, y1 = -1;
  const mark = (x, y) => { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); };
  for (let f = 0; f < 4; f++) {
    const Q = new Painter(big, H, f); draw(Q, p, f, { ox: 200 });
    Q.finish().forEach((c, i) => { if (c) mark(i % big, Math.floor(i / big)); });
  }
  const m = 2;
  return (LAYOUT[p] = { W: x1 - x0 + 1 + 2 * m, H: H - y0 + m, ox: 200 - x0 + m });
}
// One form, one part (null = all) and one flame frame: { w, h, px, solid, joints, tags }.
function renderPart(p, part, frame, skip) {
  const L = layout(p), P = new Painter(L.W, L.H, frame || 0, part == null ? null : part);
  draw(P, p, frame || 0, { ox: L.ox });
  return { w: L.W, h: L.H, px: P.finish(skip), solid: P.solid.map(Boolean), joints: P.joints, tags: P.tags };
}
const SEAMLESS = [['body', 'neck'], ['neck', 'head'], ['body', 'tail_1'], ['tail_1', 'tail_2'], ['tail_2', 'tail_3'], ['tail_3', 'tail_4'], ['tail_4', 'tail_5']];
// The rig look: every part rendered isolated with its own outline (no seam on SEAMLESS joints),
// stacked in Z order. Returns { w, h, px, parts: { id: px }, joints, ids }.
function composite(p, frame) {
  const all = renderPart(p, null, frame), ids = all.tags.filter(t => RIG.PARENT[t] !== undefined);
  const unknown = all.tags.filter(t => RIG.PARENT[t] === undefined);
  if (unknown.length) throw new Error('drache' + p + ': unknown parts ' + unknown.join(', '));
  ids.sort((a, b) => RIG.Z[a] - RIG.Z[b] || ids.indexOf(a) - ids.indexOf(b));
  const solid = {}, parts = {};
  for (const id of ids) solid[id] = renderPart(p, id, 0).solid;
  const px = new Array(all.w * all.h).fill(null);
  for (const id of ids) {
    const near = SEAMLESS.filter(pr => pr.includes(id)).map(pr => solid[pr[0] === id ? pr[1] : pr[0]]).filter(Boolean);
    const skip = near.length ? i => near.some(m => m[i]) : undefined;
    const r = renderPart(p, id, frame, skip);
    parts[id] = r.px;
    r.px.forEach((c, i) => { if (c) px[i] = c; });
  }
  return { w: all.w, h: all.h, px, parts, joints: all.joints, ids };
}

// ---------- rig check (the data contract of export_rigs.js checkRigs, the parts that the art decides) ----------
function rigCheck(p) {
  const c = composite(p, 0), W = c.w, H = c.h, J = c.joints, problems = [];
  const near = (px, at) => { let best = Infinity; px.forEach((col, i) => { if (col) best = Math.min(best, Math.hypot(i % W + .5 - at[0], Math.floor(i / W) + .5 - at[1])); }); return best; };
  const flip = new Set(['tail_flame', 'mouth_flame']);
  const union = id => { if (!flip.has(id)) return c.parts[id]; const u = new Array(W * H).fill(null); for (let f = 0; f < 4; f++) renderPart(p, id, f).px.forEach((col, i) => { if (col) u[i] = col; }); return u; };
  for (const id of c.ids) {
    if (!J[id]) { problems.push(id + ': no joint'); continue; }
    const d = near(union(id), J[id]); if (d > (flip.has(id) ? 6 : 2.5)) problems.push(`${id}: pivot ${d.toFixed(1)} px from the part`);
    const par = RIG.PARENT[id]; if (par && c.parts[par] && !flip.has(id)) { const dp = near(c.parts[par], J[id]); if (dp > 3) problems.push(`${id}: pivot ${dp.toFixed(1)} px from parent ${par}`); }
  }
  const pts = { mouth: 'jaw', throat_at: 'neck', hand: 'arm', tail_tip: 'tail_5', core: 'body' };
  for (const k in pts) { if (!J[k]) { problems.push('point ' + k + ' missing'); continue; } const d = near(c.parts[pts[k]], J[k]); if (d > 3) problems.push(`point ${k} ${d.toFixed(1)} px from ${pts[k]}`); }
  const visible = {}; for (const id of c.ids) visible[id] = 0;
  for (let i = 0; i < W * H; i++) { let owner = null; for (const id of c.ids) if (c.parts[id][i]) owner = id; if (owner) visible[owner]++; }
  const sev = Object.keys(RIG.FORMS[p].cut);
  for (const id of sev) if (!(visible[id] >= 20)) problems.push(`${id}: ${visible[id] || 0} px can be hit, at least 20`);
  const expected = Object.keys(RIG.FORMS[p].hp), missing = expected.filter(id => !c.ids.includes(id));
  if (missing.length) problems.push('missing parts ' + missing.join(', '));
  // the feet stand on the bottom row
  const bottom = ['leg_far', 'leg_near'].every(id => c.parts[id].slice((H - 1) * W).some(Boolean));
  if (!bottom) problems.push('feet not on the bottom row');
  return { W, H, ids: c.ids, joints: Object.keys(J), visible, sev, problems };
}

// ---------- PNG / canvas ----------
function decodePng(buf) {
  let pos = 8, w = 0, h = 0, type = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), kind = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); type = data[9]; } else if (kind === 'IDAT') idat.push(data); else if (kind === 'IEND') break;
    pos += 12 + len;
  }
  const ch = { 0: 1, 2: 3, 4: 2, 6: 4 }[type], stride = w * ch, raw = zlib.inflateSync(Buffer.concat(idat)), px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[y * stride + x - ch] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = x >= ch && y ? px[(y - 1) * stride + x - ch] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const q = a + b - c, pa = Math.abs(q - a), pb = Math.abs(q - b), pc = Math.abs(q - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      px[y * stride + x] = v & 255;
    }
  }
  const rgba = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) { const s = i * ch; if (type === 6) rgba.set(px.subarray(s, s + 4), i * 4); else if (type === 2) rgba.set([px[s], px[s + 1], px[s + 2], 255], i * 4); else rgba.set([px[s], px[s], px[s], type === 4 ? px[s + 1] : 255], i * 4); }
  return { w, h, rgba };
}
const FONT = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111', F: '111100110100100',
  G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010', K: '101101110101101', L: '100100100100111',
  M: '101111111101101', N: '110101101101101', O: '010101101101010', P: '110101110100100', Q: '010101101110011', R: '110101110101101',
  S: '011100010001110', T: '111010010010010', U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101',
  Y: '101101010010010', Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111', 9: '111101111001110',
  ' ': '000000000000000', '.': '000000000000010', ':': '000010000010000', '-': '000000111000000', '/': '001001010100100', '=': '000111000111000',
  ',': '000000000010100', '(': '001010010010001', ')': '100010010010100', '*': '101010101000000', x: '000101010101000',
};
class Canvas {
  constructor(w, h, bg) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); for (let i = 0; i < w * h; i++) this.d.set(bg, i * 4); }
  px(x, y, c) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d.set(c, (y * this.w + x) * 4); }
  get(x, y) { const i = (y * this.w + x) * 4; return [this.d[i], this.d[i + 1], this.d[i + 2]]; }
  blend(x, y, c, a) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4; for (let k = 0; k < 3; k++) this.d[i + k] = Math.round(this.d[i + k] * (1 - a) + c[k] * a); }
  rect(x, y, w, h, c) { for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, c); }
  text(x, y, str, c, k) {
    k = k || 2;
    for (const ch0 of String(str)) { const ch = FONT[ch0] ? ch0 : ch0.toUpperCase(); const g = FONT[ch] || FONT['*']; for (let i = 0; i < 15; i++) if (g[i] === '1') this.rect(x + (i % 3) * k, y + Math.floor(i / 3) * k, k, k, c); x += 4 * k; }
  }
  // Draws a colour array (w x h, hex or null) at (x, y), each source px k output px (k may be fractional), optionally mirrored.
  sprite(px, w, h, x, y, k, flip) {
    const W = Math.round(w * k), Hh = Math.round(h * k);
    for (let yy = 0; yy < Hh; yy++) for (let xx = 0; xx < W; xx++) {
      const sx = Math.min(w - 1, Math.floor(xx / k)), sy = Math.min(h - 1, Math.floor(yy / k)), c = px[sy * w + (flip ? w - 1 - sx : sx)];
      if (c) this.px(x + xx, y + yy, typeof c === 'string' ? [...hexToRgb(c), 255] : c);
    }
  }
  // A soft ground shadow (the game draws its own below every rig).
  shadow(cx, cy, rx, ry, a) {
    for (let y = Math.floor(cy - ry); y <= cy + ry; y++) for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
      const d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2; if (d <= 1) this.blend(x, y, [8, 4, 6], a * Math.min(1, (1 - d) * 2.2));
    }
  }
  png() { return encodePng(this.w, this.h, this.d); }
}
const rgbaToPx = img => { const out = []; for (let i = 0; i < img.w * img.h; i++) out.push(img.rgba[i * 4 + 3] > 0 ? [img.rgba[i * 4], img.rgba[i * 4 + 1], img.rgba[i * 4 + 2], 255] : null); return out; };

// ---------- previews ----------
function main() {
  const root = process.argv.slice(2).find(a => !a.startsWith('--')) || path.join(__dirname, '..', '..', '..');
  const out = path.join(root, 'production', 'qa', 'evidence', 'drake-concepts');
  fs.mkdirSync(out, { recursive: true });
  const knight = decodePng(fs.readFileSync(path.join(root, 'assets', 'sprites', '0x72', 'knight_m_idle_anim_f0.png')));
  const kpx = rgbaToPx(knight);
  const forms = [1, 2, 3, 4].map(p => ({ p, c: composite(p, 0), chk: rigCheck(p) }));
  for (const { p, chk } of forms) {
    console.log(`drache${p} ${FS[p].name}: ${chk.W}x${chk.H} source px (${chk.W * 5}x${chk.H * 5} world px, ${(chk.H * 5 / 84).toFixed(1)}x hero height), ${chk.ids.length} parts`);
    console.log('  parts: ' + chk.ids.join(' '));
    console.log('  joints: ' + chk.joints.join(' '));
    console.log('  severable visible px: ' + chk.sev.map(id => `${id} ${chk.visible[id]}`).join(', '));
    console.log('  rig check: ' + (chk.problems.length ? 'PROBLEMS ' + chk.problems.join('; ') : 'ok'));
  }
  const bgFloor = [43, 33, 38, 255], gridC = [35, 26, 31], crackC = [110, 34, 40];
  // floor of the lineups: dark hell stone with a faint tile grid (world tiles of ~128 px)
  const floor = (cv, y0, tile) => {
    for (let y = y0; y < cv.h; y++) for (let x = 0; x < cv.w; x++) {
      if (x % tile === 0 || (y - y0) % tile === 0) cv.px(x, y, [...gridC, 255]);
      else if (hash(Math.floor(x / 3), Math.floor(y / 3), 4) > .985) cv.px(x, y, [...crackC, 255]);
    }
  };
  // 1. lineup: same in-game scale (1 source px = 2 output px = 0.4 x world), knight next to each
  {
    const k = 2, kk = 3 * .4, gap = 14, pad = 24, labelH = 34, top = 40;
    const kw = Math.round(16 * kk), kh = Math.round(28 * kk);
    const widths = forms.map(f => f.c.w * k + gap + kw + pad);
    const Hmax = Math.max(...forms.map(f => f.c.h * k));
    const W = widths.reduce((a, b) => a + b, pad), Hc = top + Hmax + 26 + labelH;
    const cv = new Canvas(W, Hc, bgFloor), ground = top + Hmax;
    floor(cv, ground - 70, 51);
    cv.rect(0, 0, W, top - 6, [26, 20, 24, 255]);
    cv.text(10, 10, 'IGNAROTH - KONZEPT FEUERSCHLANGE - ALLE FORMEN IM SPIELMASSSTAB (1 PX = 2 PX, RITTER x3 DANEBEN)', [238, 142, 46, 255], 2);
    let x = pad;
    forms.forEach(({ p, c }) => {
      const dx = x, dy = ground - c.h * k;
      cv.shadow(dx + c.w * k * .48, ground - 2, c.w * k * .36, 7 + p * 2, .55);
      cv.sprite(c.px, c.w, c.h, dx, dy, k);
      const kx = dx + c.w * k + gap, ky = ground - kh;
      cv.shadow(kx + kw / 2, ground - 1, kw * .55, 3, .5);
      cv.sprite(kpx, 16, 28, kx, ky, kk);
      cv.rect(dx, ground + 8, c.w * k + gap + kw, 2, [98, 35, 47, 255]);
      cv.text(dx, ground + 16, `${p} ${FS[p].name}`, [250, 203, 62, 255], 2);
      cv.text(dx, ground + 32, `${c.w}x${c.h} PX - ${(c.h * 5 / 84).toFixed(1)}x HELD`, [211, 191, 169, 255], 2);
      x += widths[p - 1];
    });
    fs.writeFileSync(path.join(out, 'feuerschlange_lineup.png'), cv.png());
  }
  // 2. form 4 large (1 source px = 5 output px = world size), form 3 next to it, knight x3
  {
    const k = 5, f3 = forms[2].c, f4 = forms[3].c, kw = 48, kh = 84, pad = 30, top = 44;
    const W = pad + f4.w * k + 40 + kw + 60 + f3.w * k + 40 + kw + pad, Hc = top + f4.h * k + 70;
    const cv = new Canvas(W, Hc, bgFloor), ground = top + f4.h * k;
    floor(cv, ground - 160, 128);
    cv.rect(0, 0, W, top - 8, [26, 20, 24, 255]);
    cv.text(12, 10, 'FEUERSCHLANGE - FORM 4 OBSIDIANFORM UND FORM 3 GLUTDRACHE - WELTGROESSE (1 PX = 5 PX), RITTER x3', [238, 142, 46, 255], 3);
    let x = pad;
    for (const [p, c] of [[4, f4], [3, f3]]) {
      cv.shadow(x + c.w * k * .48, ground - 4, c.w * k * .34, 18, .6);
      cv.sprite(c.px, c.w, c.h, x, ground - c.h * k, k);
      const kx = x + c.w * k + 40;
      cv.shadow(kx + kw / 2, ground - 2, 30, 6, .5);
      cv.sprite(kpx, 16, 28, kx, ground - kh, 3);
      cv.text(x, ground + 18, `${p} ${FS[p].name} ${c.w}x${c.h}`, [250, 203, 62, 255], 3);
      x = kx + kw + 60;
    }
    fs.writeFileSync(path.join(out, 'feuerschlange_form4.png'), cv.png());
  }
  // 3. in-game mock, world scale: 1280 x 720 world px, floor from the real room (01-kampfraum-etage5),
  //    tiles enlarged 2x (the screenshots run at about half world scale: form 3 is ~2.5 screen px per source px)
  const shot = decodePng(fs.readFileSync(path.join(root, 'production', 'qa', 'evidence', 'hell-monsters', '01-kampfraum-etage5.png')));
  {
    const cv = new Canvas(1280, 720, [0, 0, 0, 255]);
    const cx0 = 470, cy0 = 412, cw = 272, chh = 204; // a clean floor block of the screenshot (4 x 3 tiles)
    for (let y = 0; y < 720; y++) for (let x = 0; x < 1280; x++) {
      const sx = cx0 + Math.floor(x / 2) % cw, sy = cy0 + Math.floor(y / 2) % chh, i = (sy * shot.w + sx) * 4;
      cv.px(x, y, [shot.rgba[i], shot.rgba[i + 1], shot.rgba[i + 2], 255]);
    }
    const c = forms[3].c, k = 5, dx = Math.round(640 - c.w * k * .5) + 60, ground = 650;
    cv.shadow(dx + c.w * k * .52, ground - 6, c.w * k * .3, 24, .6);
    cv.sprite(c.px, c.w, c.h, dx, ground - c.h * k, k, true); // mirrored: faces the hero on the left, as the game turns it
    const kx = 250, ky = 612;
    cv.shadow(kx + 24, ky + 82, 30, 7, .55);
    cv.sprite(kpx, 16, 28, kx, ky, 3);
    // a red vignette like the game's
    for (let y = 0; y < 720; y++) for (let x = 0; x < 1280; x++) { const d = Math.hypot((x - 640) / 640, (y - 360) / 360); if (d > .75) cv.blend(x, y, [120, 10, 16], Math.min(.45, (d - .75) * .9)); }
    cv.rect(0, 0, 1280, 30, [14, 12, 12, 255]);
    cv.text(10, 8, 'MOCK IN WELTGROESSE: OBSIDIANFORM x5, RITTER x3, 1280x720 WELT-PX', [250, 203, 62, 255], 3);
    fs.writeFileSync(path.join(out, 'feuerschlange_ingame.png'), cv.png());
  }
  // 4. the same in the real room screenshot at the screenshots' own zoom (about 0.5: 2.5 screen px per source px)
  {
    const cv = new Canvas(shot.w, shot.h, [0, 0, 0, 255]);
    cv.d.set(shot.rgba);
    const c = forms[3].c, k = 2.5, dx = 700, ground = 560;
    cv.shadow(dx + c.w * k * .52, ground - 3, c.w * k * .3, 12, .6);
    cv.sprite(c.px, c.w, c.h, dx, ground - Math.round(c.h * k), k, true);
    cv.rect(0, 700, 1280, 20, [14, 12, 12, 255]);
    cv.text(8, 704, 'MOCK IM ECHTEN RAUM-SCREENSHOT (ZOOM CA. 0.5 WIE DIE BOSS-SCREENSHOTS)', [250, 203, 62, 255], 2);
    fs.writeFileSync(path.join(out, 'feuerschlange_ingame_zoom.png'), cv.png());
  }
  console.log('written to ' + out);
}

module.exports = { draw, layout, renderPart, composite, rigCheck, FS };
if (require.main === module) main();

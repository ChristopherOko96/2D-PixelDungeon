// Concept "monumental": Ignaroth's four forms as colossal 3/4-view bosses. The body turns toward
// the viewer, the near wing spreads wide across the frame, the far wing rises behind the head,
// the head turns down toward the hero. Not wired into the game: this file only draws previews.
//
// Drawing model: every rig part is sculpted from volumes (ellipsoids, tapered tubes along
// splines, flat wing panels) into a small z-buffer, then lit (key light top left, lava rim from
// below, a cool back rim) and quantised to 4-5 tone ramps of the 0x72 palette (plus a few deeper
// shades derived from it). The Painter from hell_monsters.js does the rest exactly as for the
// real rig: part tags (P.part), pivots (P.joint), flames (P.flame), the 1 px #222222 outline
// (P.finish). renderRig(p, part, frame, skip) has the same contract as HM.renderDrakeRig, so
// export_rigs.js could switch to it later; compose() stacks the isolated parts by the rig's
// layers (export_rigs.js Z) like the game does.
//
// Usage: node tools/hell_dungeon/concepts/monumental.js [repo_root]
//   writes production/qa/evidence/drake-concepts/monumental_{lineup,form4,ingame}.png and prints
//   a source-side check of the rig contract (parts, pivots, visible hit pixels, frame edges).
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const HM = require('../hell_monsters.js');
const { encodePng } = require('../monster_sheet.js');
const ER = require('../export_rigs.js');

// ---------- palette: 0x72 DungeonTileset II colours (as in hell_monsters.js) ----------
const K = '#222222', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a';
const RED = '#da4e38', CRIM = '#9f294e', MAROON = '#62232f', PLUM = '#38262d', PURP = '#5f2d56', MAG = '#993970';
const PINK = '#dc4a7b', LILAC = '#f0b3dd', VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579';
const YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025', BROWN = '#8f4029';
const MUD = '#775c55', STONE = '#483b3a', COAL = '#3b3332', SOOT = '#302c2b';
// deeper steps derived from palette colours (core shadows and the far side only)
const GLOSS = '#8c7b8e'; // obsidian's glassy streak: MUD lifted toward the void fire's LILAC
const BROWN0 = '#5c2a22', CRIM0 = '#4a1a26', PLUM0 = '#26151c', SOOT0 = '#171315', INDIGO0 = '#231b42', PURP0 = '#2c1832';
const FIRE = [WHITE, YEL, ORA, RED, CRIM];
const VOIDFIRE = [LILAC, VIO, VIOD, PURP, INDIGO];

// ---------- light ----------
const nrm = (x, y, z) => { const l = Math.hypot(x, y, z) || 1; return [x / l, y / l, z / l]; };
const L = nrm(-.55, -.7, .45);            // key light: top left, grazing, so the forms turn
const HV = nrm(L[0], L[1], L[2] + 1);      // half vector for the glassy highlights
const SL = (() => { const l = Math.hypot(L[0], L[1]); return [L[0] / l, L[1] / l]; })();

// ---------- sculpt: volumes into a z-buffer, then lit and quantised ----------
// Coordinates are units of the form's skeleton; T maps them to source px (ox + x*s, oy + y*s).
function Sculpt(P, T) { this.P = P; this.T = T; this.m = new Map(); }
const S_ = Sculpt.prototype;
S_.put = function (x, y, z, n, mat, tex) {
  if (x < 0 || y < 0 || x >= this.P.w || y >= this.P.h) return;
  const k = y * this.P.w + x, c = this.m.get(k);
  if (!c || z >= c.z) this.m.set(k, { x, y, z, nx: n[0], ny: n[1], nz: n[2], mat, tex: tex || {} });
};
// A rotated ellipsoid (rx, ry in units, ang radians); z: base depth, dz: bulge (default min radius).
S_.ell = function (c, r, mat, o) {
  if (!this.P.keep()) return this;
  o = o || {};
  const { s, ox, oy } = this.T, cx = ox + c[0] * s, cy = oy + c[1] * s, rx = Math.max(.8, r[0] * s), ry = Math.max(.8, r[1] * s);
  const ang = o.ang || 0, co = Math.cos(ang), si = Math.sin(ang), R = Math.max(rx, ry), z0 = (o.z || 0) * s, dz = (o.dz != null ? o.dz * s : Math.min(rx, ry));
  for (let y = Math.floor(cy - R) - 1; y <= Math.ceil(cy + R) + 1; y++) for (let x = Math.floor(cx - R) - 1; x <= Math.ceil(cx + R) + 1; x++) {
    const px = x + .5 - cx, py = y + .5 - cy, u = px * co + py * si, v = -px * si + py * co, q = (u / rx) ** 2 + (v / ry) ** 2;
    if (q > 1) continue;
    const nz = Math.sqrt(1 - q), nu = u / rx, nv = v / ry, tilt = o.tilt || [0, 0];
    this.put(x, y, z0 + nz * dz, nrm(nu * co - nv * si + tilt[0], nu * si + nv * co + tilt[1], nz), mat, { u: nu, v: nv });
  }
  return this;
};
// Catmull-Rom through [x, y, r, z] points (every component interpolated).
function spline(pts, steps) {
  if (pts.length < 3) return pts;
  const out = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)];
    for (let k = 0; k < steps; k++) {
      const t = k / steps, t2 = t * t, t3 = t2 * t;
      out.push(p1.map((_, j) => .5 * ((2 * p1[j]) + (-(p0[j] ?? p1[j]) + (p2[j] ?? p1[j])) * t + (2 * (p0[j] ?? p1[j]) - 5 * p1[j] + 4 * (p2[j] ?? p1[j]) - (p3[j] ?? p1[j])) * t2 + (-(p0[j] ?? p1[j]) + 3 * p1[j] - 3 * (p2[j] ?? p1[j]) + (p3[j] ?? p1[j])) * t3)));
    }
  }
  out.push(pts[pts.length - 1]);
  return out;
}
// A tapered tube through [x, y, r, z] points (units). o.smooth: spline it; o.minR: thinnest px radius.
S_.tube = function (pts, mat, o) {
  if (!this.P.keep()) return this;
  o = o || {};
  const { s, ox, oy } = this.T, minR = o.minR != null ? o.minR : .55;
  const src = o.smooth === false ? pts : spline(pts, o.steps || 5);
  const q = src.map(p => [ox + p[0] * s, oy + p[1] * s, Math.max(minR, (p[2] || 1) * s), (p[3] || 0) * s + (o.z || 0) * s]);
  const len = [0];
  for (let i = 1; i < q.length; i++) len.push(len[i - 1] + Math.hypot(q[i][0] - q[i - 1][0], q[i][1] - q[i - 1][1]));
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of q) { x0 = Math.min(x0, p[0] - p[2]); y0 = Math.min(y0, p[1] - p[2]); x1 = Math.max(x1, p[0] + p[2]); y1 = Math.max(y1, p[1] + p[2]); }
  const dzk = o.dz != null ? o.dz : 1;
  for (let y = Math.floor(y0) - 1; y <= Math.ceil(y1) + 1; y++) for (let x = Math.floor(x0) - 1; x <= Math.ceil(x1) + 1; x++) {
    const px = x + .5, py = y + .5;
    let best = null;
    for (let i = 0; i < q.length - 1; i++) {
      const a = q[i], b = q[i + 1], dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy || 1e-6;
      const t = Math.max(0, Math.min(1, ((px - a[0]) * dx + (py - a[1]) * dy) / l2));
      const cx = a[0] + dx * t, cy = a[1] + dy * t, r = a[2] + (b[2] - a[2]) * t, d = Math.hypot(px - cx, py - cy);
      if (d > r) continue;
      const h = Math.sqrt(Math.max(0, r * r - d * d)), z = a[3] + (b[3] - a[3]) * t + h * dzk;
      if (!best || z > best.z) {
        const l = Math.sqrt(l2), side = ((px - cx) * dy - (py - cy) * dx) / l / r;
        best = { z, n: nrm((px - cx) / r, (py - cy) / r, h / r + .05), tex: { along: len[i] + l * t, side, t: (i + t) / (q.length - 1) } };
      }
    }
    if (best) this.put(x, y, best.z, best.n, mat, best.tex);
  }
  return this;
};
// A flat polygon (wing panels, crystal facets) with one normal; tex(x, y) adds texture coordinates.
S_.flat = function (pts, mat, n, o) {
  if (!this.P.keep()) return this;
  o = o || {};
  const { s, ox, oy } = this.T, q = pts.map(p => [ox + p[0] * s, oy + p[1] * s]), nn = nrm(...n);
  const xs = q.map(p => p[0]), ys = q.map(p => p[1]);
  const inside = (x, y) => { let c = false; for (let i = 0, j = q.length - 1; i < q.length; j = i++) { const [xi, yi] = q[i], [xj, yj] = q[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c; } return c; };
  for (let y = Math.floor(Math.min(...ys)); y <= Math.ceil(Math.max(...ys)); y++) for (let x = Math.floor(Math.min(...xs)); x <= Math.ceil(Math.max(...xs)); x++) {
    if (!inside(x + .5, y + .5)) continue;
    this.put(x, y, (o.z || 0) * s, nn, mat, o.tex ? o.tex(x + .5, y + .5) : {});
  }
  return this;
};
// Repaints the already sculpted pixels within hw units of a polyline (a band on the surface:
// belly plates, the dorsal stripe) with another material; keeps their normals.
S_.band = function (pts, mat, o) {
  if (!this.P.keep()) return this;
  o = o || {};
  const { s, ox, oy } = this.T, src = spline(pts, 5), q = src.map(p => [ox + p[0] * s, oy + p[1] * s, p[2] * s]);
  const len = [0];
  for (let i = 1; i < q.length; i++) len.push(len[i - 1] + Math.hypot(q[i][0] - q[i - 1][0], q[i][1] - q[i - 1][1]));
  for (const c of this.m.values()) {
    if (o.only && !o.only.includes(c.mat)) continue;
    const px = c.x + .5, py = c.y + .5;
    for (let i = 0; i < q.length - 1; i++) {
      const a = q[i], b = q[i + 1], dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy || 1e-6;
      const t = Math.max(0, Math.min(1, ((px - a[0]) * dx + (py - a[1]) * dy) / l2));
      const d = Math.hypot(px - a[0] - dx * t, py - a[1] - dy * t), hw = a[2] + (b[2] - a[2]) * t;
      if (d <= hw) { c.mat = mat; c.tex = Object.assign({}, c.tex, { along: len[i] + Math.sqrt(l2) * t, off: d / hw }); break; }
    }
  }
  return this;
};
// Removes sculpted pixels in a circle (units): torn membrane.
S_.cut = function (c, r) {
  const { s, ox, oy } = this.T, cx = ox + c[0] * s, cy = oy + c[1] * s, R = r * s;
  for (const [k, v] of this.m) if (Math.hypot(v.x + .5 - cx, v.y + .5 - cy) <= R) this.m.delete(k);
  return this;
};
S_.has = function (x, y) { return x >= 0 && y >= 0 && x < this.P.w && y < this.P.h && this.m.has(y * this.P.w + x); };
S_.cell = function (x, y) { return this.has(x, y) ? this.m.get(y * this.P.w + x) : null; };
// Lights every sculpted pixel and stamps it into the Painter under the current part tag.
S_.flush = function () {
  if (!this.P.keep()) return this;
  const w = this.P.w, m = this.m;
  this.colour = new Map();
  for (const [k, c] of m) {
    let M = c.mat;
    if (M.pick) M = M.pick(c) || M;
    const ramp = M.ramp, n = ramp.length, amb = M.amb != null ? M.amb : .14;
    const d = c.nx * L[0] + c.ny * L[1] + c.nz * L[2];
    const v = amb + (1 - amb) * Math.pow(Math.max(0, d), M.gamma || 1) * (M.gain || 1);
    let i = Math.min(n - 1, Math.floor(v * n));
    // self shadow: a higher volume of this part between the pixel and the light
    let shadow = false;
    for (let t = 2; t <= 6 && !shadow; t++) { const q = m.get(Math.round(c.y - SL[1] * t) * w + Math.round(c.x - SL[0] * t)); if (q && q.mat !== M && q.z > c.z + t * .8 + 2) shadow = true; }
    // contact occlusion: right next to a much higher volume
    let occ = false;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const q = m.get((c.y + dy) * w + c.x + dx); if (q && q.z > c.z + 3.5) occ = true; }
    if (shadow) i -= 1;
    if (occ) i -= 1;
    i += M.shift || 0;
    if (M.tone) i += M.tone(c, i, n) || 0;
    i = Math.max(0, Math.min(n - 1, i));
    const top = i === n - 1;
    let col = ramp[i];
    const open = (dx, dy) => !m.has((c.y + dy) * w + c.x + dx) || c.y + dy >= this.P.h;
    // backlit membrane / glowing edge
    if (M.edge && (open(1, 0) || open(-1, 0) || open(0, 1) || open(0, -1))) col = M.edge;
    // lava light from below on the lower silhouette, cool rim on the back edge
    else if (M.rim && c.ny > .5 && c.nz < .75 && open(0, 1)) col = typeof M.rim === 'number' ? ramp[Math.min(n - 1, i + M.rim)] : M.rim;
    else if (M.rim2 && c.nz < .75 && ((c.nx < -.45 && c.ny < -.05 && open(-1, 0)) || (c.ny < -.72 && c.nx < .3 && open(0, -1)))) col = typeof M.rim2 === 'number' ? ramp[Math.min(n - 1, i + M.rim2)] : M.rim2;
    // glassy highlight: only inside the lightest tone, a thin streak
    if (M.spec && top && c.nx * HV[0] + c.ny * HV[1] + c.nz * HV[2] > M.specT) col = M.spec;
    this.colour.set(k, col);
    this.P.dot(c.x, c.y, col);
  }
  return this;
};
// Paints over this part's own pixels only (after flush): cracks, veins, plates.
S_.dot = function (x, y, col) { x = Math.round(x); y = Math.round(y); if (this.has(x, y)) this.P.dot(x, y, col); return this; };
S_.line = function (a, b, col, o) {
  o = o || {};
  const { s, ox, oy } = this.T, x0 = ox + a[0] * s, y0 = oy + a[1] * s, x1 = ox + b[0] * s, y1 = oy + b[1] * s;
  const n = Math.max(1, Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))));
  for (let i = 0; i <= n; i++) { const x = Math.round(x0 + (x1 - x0) * i / n), y = Math.round(y0 + (y1 - y0) * i / n); if (!o.inner || this.inner(x, y)) this.dot(x, y, typeof col === 'function' ? col(i, n) : col); }
  return this;
};
S_.inner = function (x, y) { return this.has(x, y) && this.has(x + 1, y) && this.has(x - 1, y) && this.has(x, y + 1) && this.has(x, y - 1); };

// Deterministic random numbers (cracks, scale breaks).
function rng(seed) { let s = (seed * 2654435761) >>> 0 || 1; return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296); }
// Glowing fissures over this part's interior: short random walks with a hot core.
function cracks(S, seed, n, len, col, o) {
  if (!S.P.keep()) return;
  o = o || {};
  // o.cols: start only on pixels lit with one of these colours (fissures glow in the shadows)
  const col0 = k => S.colour && S.colour.get(k), ok = c => !o.cols || o.cols.has(col0(c.y * S.P.w + c.x));
  const R = rng(seed), cells = [...S.m.values()].filter(c => S.inner(c.x, c.y) && ok(c) && (!o.mats || o.mats.includes(c.mat)));
  for (let k = 0; k < n && cells.length; k++) {
    const c0 = cells[Math.floor(R() * cells.length)];
    let x = c0.x, y = c0.y, ang = R() * Math.PI * 2;
    const L0 = Math.round(len * (.6 + R() * .6));
    for (let i = 0; i < L0; i++) {
      if (!S.inner(x, y)) break;
      const hot = i > 1 && i < L0 - 2 && (i % 4 === 2);
      S.P.dot(x, y, hot ? col[1] : col[0]);
      if (hot && col[2] && R() < .5) S.P.dot(x, y, col[2]);
      ang += (R() - .5) * 1.3;
      const nx = x + Math.round(Math.cos(ang)), ny = y + Math.round(Math.sin(ang));
      if (nx === x && ny === y) { x += 1; continue; }
      x = nx; y = ny;
    }
  }
}

// ---------- the four forms ----------
// Units: form 4's skeleton (1 unit = 1 source px at s = 1), origin on the ground below the hip,
// y negative upwards. 3/4 view: the body turns toward the viewer (down right), so the far limbs sit
// up and right of the near ones, the snout and the tail are foreshortened. Forms 3 and 4 share the
// adult skeleton; 2 is a stockier wingless juvenile; 1 is a slim rearing salamander. The frame
// (W x H) is fitted around the drawing (fit()).
const ADULT = {
  // the trunk: one tapered volume from the rump to the chest, a pectoral bulge facing the viewer
  torso: [[-17, -41, 8.5], [-7, -41, 13.5], [6, -46, 15.5], [18, -55, 16], [26, -63, 12.5]],
  bulge: [[25, -53], [13, 14.5], -.45],
  farShoulder: [[31, -66], [9, 8], -.3],
  ventral: [[33, -66, 5], [35, -56, 7.5], [30, -44, 8], [19, -34, 7], [6, -28, 5]],
  spine: [[-21, -47], [-15, -52], [-9, -56], [-3, -59]],
  neck: [[23, -63, 10.5], [31, -74, 9], [40, -83, 8], [49, -88, 7.4], [57, -86, 6.8]],
  neckVentral: [[33, -64, 4.4], [40, -73, 4.6], [48, -79, 3.8], [55, -80, 3]],
  // head turned down toward the hero: short foreshortened snout, heavy brow, cheek muscle
  skull: [[61, -85], [8.4, 7], .3], snout: [[64, -83, 6.6], [70.5, -79, 5.6], [76, -75, 4.4], [79, -72.5, 3.4]],
  ridge: [[60, -89, 2.4], [67, -86, 2.1], [74, -80.5, 1.6], [78, -76.5, 1.1]],
  brow: [[56, -90, 2.8], [62.5, -90.5, 3], [68.5, -86.5, 2]],
  cheekMass: [[58.5, -79], [6, 4.6], .55],
  eye: [66.5, -84.5], eyeFar: [72, -87.5], nostril: [77.5, -76],
  cheek: [[[54, -81, 2.2], [47, -80, 1.2], [43, -80, .4]], [[56, -77, 2], [50, -73, 1.1], [47, -71, .4]]],
  fangs: [[.45, 4], [.85, 3]],
  jaw: { hinge: [59, -78], pts: [[58, -78, 4.8], [65, -70.5, 3.8], [72, -63.5, 2.7], [75.5, -61, 1.8]], mouth: [[60, -79.5], [79, -74], [74.5, -62.5], [61, -71]] },
  // devil horns: back, then up
  horns: [
    [[59, -89, 3.6], [53, -94, 3], [46, -97.5, 2.4], [40.5, -101, 1.8], [37.5, -104, 1.1], [37, -105.5, .45]],
    [[65, -91, 2.8], [62, -97, 2.3], [57.5, -100.5, 1.7], [53.5, -103, 1], [52, -104, .4]],
  ],
  crest: [[[56, -88, 1.6], [51, -91, .9], [48, -91.5, .4]]],
  arm: { upper: [[11, -63, 7.6], [16, -54, 6.4], [20, -46, 5.4]], pts: [[19, -46, 5.2], [26, -42.5, 4.6], [32, -41, 4]], hand: [[35, -40], [4.8, 4], .3],
    claws: [[[37, -38, 1.6], [41.5, -35, 1.1], [43, -30.5, .45]], [[34, -36.5, 1.5], [37, -32.5, 1], [37, -28.5, .4]], [[39.5, -40.5, 1.4], [44.5, -39.5, .9], [46.5, -36, .35]]] },
  farArm: { pts: [[32, -61, 5.4], [41, -50, 4.4], [49, -46.5, 3.3]], claws: [[[51, -46, 1.2], [55, -43.5, .8], [56, -39.5, .3]], [[49.5, -44, 1.1], [51.5, -40.5, .7], [51, -37, .3]]] },
  legNear: { upper: [[-9, -36, 11.5], [-3, -26, 10], [6, -16, 6.6]], pts: [[6, -16, 6.4], [-4, -6.5, 4.8], [4, -2.4, 3.8]],
    toes: [[[5, -2.4, 2.5], [11, -1.6, 2], [14.5, -.6, .55]], [[3, -1.8, 2.4], [7, .5, 1.7], [9, 1, .5]], [[-.5, -1.6, 2.2], [-.5, 1, 1.4], [-2, 1.1, .5]]], spur: [[-6, -8, 2], [-10.5, -5, .5]] },
  legFar: { upper: [[13, -39, 8.5], [19, -31, 7.4], [27, -23, 5.2]], pts: [[27, -23, 5], [19, -13, 4], [26, -7.2, 3.4]],
    toes: [[[27, -7.2, 2.1], [32, -6.6, 1.5], [35, -6, .45]], [[26, -6.8, 2], [29, -4.8, 1.3], [30.5, -4.4, .45]]], spur: null },
  // the ten tail steps (eleven points): it recedes into the depth (up and left) and curls
  tail: [[-12, -34, 9.5], [-21, -27, 8.6], [-30, -21, 7.4], [-39, -17, 6.2], [-47, -15, 5.2], [-54, -15.5, 4.4], [-59, -18, 3.6], [-62, -22.5, 2.9], [-63, -28, 2.3], [-61.5, -33, 1.8], [-58.5, -36.5, 1.2]],
  wingNear: { root: [4, -61], elbow: [-15, -90], wrist: [-34, -98], tips: [[-58, -97], [-61, -77], [-53, -58], [-37, -46]], trail: [-8, -43], r: [4.6, 3.6, 2.7],
    tears: [[[-47, -63], 2.4], [[-56, -82], 1.7], [[-29, -50], 1.8]] },
  wingFar: { root: [27, -70], elbow: [40, -93], wrist: [53, -99], tips: [[73, -101], [79, -91], [75, -81]], trail: [40, -77], r: [3.6, 2.8, 2.1] },
  throat: [[44.5, -77.5], [6.4, 3.2], -.8],
  crystals: [{ base: [8, -63], tip: [4, -94], w: 7.6 }, { base: [1, -59], tip: [-8, -85], w: 6.4 }, { base: [14, -66], tip: [16, -89], w: 5.6 }],
  core: [30, -58],
  tailFlame: [10, 24],
};
// Juvenile: no wings, horn nubs, a shorter thicker neck, a bigger head on the same body.
const JUVENILE = Object.assign({}, ADULT, {
  torso: [[-17, -39, 8.5], [-7, -39, 13.5], [6, -43, 15], [17, -51, 15.5], [24, -58, 12.5]],
  bulge: [[21, -49], [12, 13], -.4],
  farShoulder: [[29, -61], [9, 8], -.3],
  ventral: [[31, -61, 5], [33, -51, 7.5], [29, -40, 8], [18, -31, 7], [6, -26, 5]],
  spine: [[-18, -46], [-11, -51], [-4, -55], [3, -58]],
  neck: [[22, -59, 10.8], [30, -69, 9.6], [38, -76, 8.8], [45, -78, 8.2]],
  neckVentral: [[31, -60, 4.4], [37, -69, 4.4], [44, -72, 3.6]],
  skull: [[51, -78], [10, 8.6], .3], snout: [[54, -77, 7.6], [61, -73, 6.6], [67, -68.5, 5.2], [70, -66, 4]],
  ridge: [[50, -84, 2.8], [58, -80.5, 2.4], [65, -74.5, 1.8], [68.5, -70.5, 1.2]],
  brow: [[45, -84.5, 3.2], [52.5, -85, 3.2], [59.5, -81, 2.2]],
  cheekMass: [[48.5, -72], [6.6, 5.2], .5],
  eye: [57, -78.5], eyeFar: [63, -81.5], nostril: [68.5, -69.5],
  cheek: [[[44, -75, 2.6], [38, -73, 1.4], [34, -72, .45]]],
  fangs: [[.5, 3.6], [.85, 2.8]],
  jaw: { hinge: [48, -71], pts: [[47, -72, 5.6], [55, -64, 4.4], [62, -57.5, 3], [65, -55.5, 2]], mouth: [[49, -73], [70, -67.5], [64.5, -56.5], [50, -65]] },
  horns: null,
  nubs: [[[47, -84, 3], [43, -89, 2.1], [40, -91.5, .7]], [[53, -85.5, 2.5], [51, -90.5, 1.7], [48.5, -93, .6]]],
  crest: [[[44, -81, 1.8], [39, -84, 1], [36, -84, .4]]],
  arm: { upper: [[10, -59, 7.8], [15, -50, 6.6], [18, -42, 5.8]], pts: [[18, -42, 5.6], [25, -38.5, 5], [31, -37, 4.2]], hand: [[34.5, -36], [5, 4.2], .3],
    claws: [[[37, -34, 1.7], [42, -31, 1.1], [43.5, -26, .5]], [[34, -32.5, 1.6], [37, -28, 1], [36.5, -24, .45]], [[40, -36.5, 1.5], [45, -35.5, .9], [47, -32, .4]]] },
  farArm: { pts: [[30, -56, 5.6], [39, -45, 4.6], [47, -42, 3.4]], claws: [[[49, -41.5, 1.3], [53, -39, .8], [54, -35, .35]]] },
  wingNear: null, wingFar: null, throat: null, crystals: null,
  tail: [[-12, -32, 9.5], [-21, -25, 8.6], [-30, -19, 7.4], [-39, -15, 6.2], [-47, -13, 5.2], [-54, -13.5, 4.4], [-59, -16, 3.6], [-62, -20.5, 2.9], [-63, -26, 2.3], [-61.5, -31, 1.8], [-58.5, -34.5, 1.3]],
  tailFlame: [10, 21],
});
// Salamander: slim, smooth, low hips, a long tail, a broad flat head, a fire crest along the back.
const SALAMANDER = Object.assign({}, ADULT, {
  torso: [[-15, -33, 7], [-6, -33, 11], [6, -39, 12], [16, -47, 12], [23, -54, 9.5]],
  bulge: [[19, -47], [9.5, 10.5], -.5],
  farShoulder: [[27, -57], [7, 6.5], -.3],
  ventral: [[28, -59, 4.5], [30, -49, 6], [26, -39, 6.5], [17, -30, 5.5], [7, -25, 4]],
  spine: [],
  neck: [[21, -55, 8.6], [28, -65, 7.8], [35, -72, 7.4], [41, -74, 7.2]],
  neckVentral: [[29, -57, 3.4], [35, -66, 3.6], [41, -70, 3]],
  skull: [[47, -75], [10.4, 7.4], .2], snout: [[50, -75, 7], [57, -72, 6.4], [62.5, -68.5, 5], [65, -66.5, 3.8]],
  ridge: [[46, -80.5, 2.4], [54, -78, 2.2], [61, -73, 1.6]],
  brow: [[42, -80, 2.6], [49.5, -81, 2.6], [55, -78, 1.8]],
  cheekMass: [[44, -69], [6.6, 5], .4],
  eye: [53, -76.5], eyeFar: [59, -79], nostril: [63.5, -69.5],
  cheek: [], fangs: [[.6, 2.4]],
  jaw: { hinge: [41, -70], pts: [[41, -71, 5.8], [50, -64.5, 5], [59, -59.5, 3.6], [62, -58, 2.4]], mouth: [[42, -72], [65, -67], [61.5, -59], [43, -65]] },
  horns: null, nubs: null, crest: [],
  arm: { upper: [[9, -58, 7], [14, -50, 6], [19, -42, 4.6]], pts: [[19, -42, 4.4], [25, -39, 3.8], [29, -38, 3.4]], hand: [[31.5, -37.5], [4, 3.4], .3],
    claws: [[[33, -36, 1.4], [36.5, -33.5, .9], [37.5, -30, .4]], [[31, -35, 1.3], [33, -31.5, .8], [32.5, -28.5, .35]], [[35, -38, 1.2], [39, -37.5, .7], [40.5, -34.5, .3]]] },
  farArm: { pts: [[27, -52, 4.2], [35, -42, 3.4], [42, -40, 2.6]], claws: [[[44, -39.5, 1.1], [47, -37.5, .7], [48, -34.5, .3]]] },
  legNear: { upper: [[-7, -29, 9], [-2, -21, 8], [6, -13.5, 5.2]], pts: [[6, -13.5, 5], [-3, -6, 3.8], [4, -2, 3.2]],
    toes: [[[5, -2, 2.1], [10.5, -1.4, 1.6], [13.5, -.5, .5]], [[3.5, -1.6, 2], [7, .5, 1.4], [8.5, 1, .45]], [[.5, -1.5, 1.8], [.5, 1, 1.2], [-1, 1.1, .45]]], spur: null },
  legFar: { upper: [[11, -33, 7], [16, -26, 6], [23, -18, 4.4]], pts: [[23, -18, 4.2], [15, -10, 3.4], [22, -6, 2.8]],
    toes: [[[23, -6, 1.8], [27.5, -5.4, 1.3], [30, -5, .4]], [[22, -5.6, 1.7], [24.5, -3.8, 1.1], [25.5, -3.4, .4]]], spur: null },
  tail: [[-11, -28, 8.4], [-21, -22, 7.6], [-31, -17, 6.6], [-41, -13.5, 5.6], [-51, -12, 4.8], [-60, -12.5, 4], [-67, -15, 3.3], [-71, -19.5, 2.7], [-72.5, -25, 2.1], [-71, -30.5, 1.6], [-67.5, -34, 1.2]],
  wingNear: null, wingFar: null, throat: null, crystals: null,
  core: [24, -50],
  tailFlame: [11, 22],
});

// The head, jaw and horns scaled around the head pivot (the neck's end).
function scaleHead(G, k) {
  const c = G.neck[G.neck.length - 1];
  const pt = q => [c[0] + (q[0] - c[0]) * k, c[1] + (q[1] - c[1]) * k].concat(q.length > 2 ? [q[2] * k] : []);
  const ell = e => [pt(e[0]), e[1].map(r => r * k), e[2]];
  const out = Object.assign({}, G, { skull: ell(G.skull), cheekMass: ell(G.cheekMass), eye: pt(G.eye), eyeFar: pt(G.eyeFar), nostril: pt(G.nostril) });
  for (const key of ['snout', 'ridge', 'brow']) out[key] = G[key].map(pt);
  for (const key of ['cheek', 'crest', 'horns', 'nubs']) out[key] = G[key] ? G[key].map(a => a.map(pt)) : G[key];
  out.jaw = { hinge: pt(G.jaw.hinge), pts: G.jaw.pts.map(pt), mouth: G.jaw.mouth.map(pt) };
  return out;
}
const FORM = {
  1: {
    name: 'Salamander', G: SALAMANDER, s: .45,
    hide: [BROWN0, BROWN, BORA, ORA, YEL], hideFar: [PLUM0, BROWN0, BROWN, BORA], belly: [BORA, ORA, YEL, WHITE],
    bone: [MUD, TAN, BONE, WHITE], rim: 2, rim2: 1, spots: [YEL, WHITE], crack: null, crackN: 0,
    mouth: [PLUM0, MAROON, CRIM, ORA, YEL], eye: [ORA, YEL, WHITE], fire: FIRE, scales: false,
  },
  2: {
    name: 'Jungdrache', G: JUVENILE, s: .58,
    hide: [CRIM0, MAROON, CRIM, RED, ORA], hideFar: [PLUM0, CRIM0, MAROON, CRIM], belly: [BROWN, BORA, ORA, YEL],
    bone: [MUD, TAN, BONE, WHITE], rim: 2, rim2: 1, crack: [ORA, YEL, WHITE], crackN: 3, crackParts: 0,
    mouth: [PLUM0, MAROON, CRIM, ORA, YEL], eye: [ORA, YEL, WHITE], fire: FIRE, scales: true,
  },
  3: {
    name: 'Glutdrache', G: scaleHead(ADULT, 1.12), s: .76,
    hide: [PLUM0, PLUM, MAROON, CRIM, RED], hideFar: [PLUM0, PLUM0, PLUM, MAROON], belly: [BROWN, BORA, ORA, YEL],
    bone: [MUD, TAN, BONE, WHITE], rim: 2, rim2: 1, crack: [ORA, YEL, WHITE], crackN: 7, crackParts: 1, bellyGlow: .45,
    wing: [PLUM0, PLUM, MAROON, CRIM], wingFar: [PLUM0, PLUM0, PLUM, MAROON], wingEdge: RED, wingEdgeFar: CRIM, vein: CRIM, veinFar: MAROON,
    gland: [MAROON, CRIM, BORA, ORA], mouth: [PLUM0, MAROON, CRIM, ORA, YEL], eye: [ORA, YEL, WHITE], fire: FIRE, scales: true,
  },
  4: {
    name: 'Obsidianform', G: scaleHead(ADULT, 1.14), s: 1,
    hide: [SOOT0, SOOT, COAL, STONE, MUD], hideFar: [SOOT0, SOOT0, SOOT, COAL], belly: [PURP0, PURP, MAG, MAG],
    bone: [BROWN, BORA, YEL, WHITE], rim: CRIM, rim2: VIOD, gamma: 1.6, gloss: GLOSS, crack: [VIOD, VIO, LILAC], crackN: 11, crackParts: 2,
    wing: [INDIGO0, INDIGO, PURP, MAG], wingFar: [SOOT0, INDIGO0, INDIGO, PURP], wingEdge: VIO, wingEdgeFar: VIOD, vein: VIOD, veinFar: INDIGO,
    gland: [PURP, MAG, PINK, LILAC], mouth: [PURP0, PURP, MAG, VIO, LILAC], eye: [VIO, LILAC, WHITE], eyeHalo: MAG, fire: VOIDFIRE, scales: true,
    crystal: [INDIGO, VIOD, VIO, LILAC, WHITE], tusks: true,
  },
};
// The rig part of each of the ten tail steps (1-10), as in hell_monsters.js DRAKE_TAIL_PART.
const TAIL_PART = [0, 1, 1, 2, 2, 2, 2, 3, 4, 5, 5];

// Scale rows on lit hide: a wavy darker seam every 3 px, staggered (reads as overlapping scales).
function scaleTone(c, i, n) {
  if (i < 2 || i >= n - 1) return 0;
  const band = Math.floor(c.y / 3), sx = (c.x + (band % 2) * 2) % 4, sy = c.y % 3;
  return (sy === 2 && (sx === 1 || sx === 2)) ? -1 : 0;
}
// Belly plates: a seam every 3 px along the band, the band's edge a step darker.
const plateTone = (c) => ((c.tex.along || 0) % 3 < 1 ? -1 : 0) + ((c.tex.off || 0) > .82 ? -1 : 0);

function looks(p) {
  const F = FORM[p];
  const mk = (ramp, o) => Object.assign({ ramp }, o || {});
  const hide = mk(F.hide, { rim: F.rim, rim2: F.rim2, tone: F.scales ? scaleTone : null, gamma: F.gamma || 1.2, amb: .12, spec: F.gloss, specT: .975 });
  const hideFar = mk(F.hideFar, { rim: typeof F.rim2 === 'number' ? 1 : F.rim2, amb: .1, gamma: F.gamma || 1.2 });
  const belly = mk(F.belly, { rim: typeof F.rim === 'number' ? 1 : F.rim, tone: plateTone, amb: F.bellyGlow || .3 });
  const bone = mk(F.bone, { amb: .2, spec: F.bone[3], specT: .95 });
  const boneFar = mk(F.bone.slice(0, 3), { amb: .08 });
  return { F, hide, hideFar, belly, bone, boneFar };
}

/**
 * Draws form p (1-4) in its rest pose into Painter P, every draw call tagged with its rig part and
 * every pivot and point recorded (same ids as hell_monsters.js drake()). ox: the x of the skeleton's
 * origin in source px (fit() measures it; the origin row is the frame's bottom row).
 */
function drawDrake(P, p, ox) {
  const F = FORM[p], G = F.G, s = F.s, oy = P.h - 1;
  const T = { s, ox, oy }, X = (x, y) => [ox + x * s, oy + y * s];
  const LK = looks(p), f = P.f;
  const J = (name, at) => { const [x, y] = X(at[0], at[1]); P.joint(name, x, y); };
  const sculpt = (name, fn) => { P.part(name); const S = new Sculpt(P, T); fn(S); return S; };
  const v = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  const dark = S => new Set(S.P.keep() ? [LK.hide.ramp[0], LK.hide.ramp[1], LK.hide.ramp[2]] : []);

  // ----- far wing (behind everything) -----
  if (G.wingFar) {
    const S = sculpt('wing_far', S => wing(S, G.wingFar, { membrane: { ramp: F.wingFar, amb: .12, edge: F.wingEdgeFar }, bone: LK.hideFar, claw: LK.boneFar, tusks: F.tusks, far: true }));
    J('wing_far', G.wingFar.root);
    S.flush(); wingVeins(S, G.wingFar, F.veinFar);
  }

  // ----- tail: ten steps in five parts, then the flame -----
  const tailDense = spline(G.tail, 4);
  for (let part = 1; part <= 5; part++) {
    const steps = []; for (let k = 1; k <= 10; k++) if (TAIL_PART[k] === part) steps.push(k);
    const a = (steps[0] - 1) * 4, b = steps[steps.length - 1] * 4, seg = tailDense.slice(a, b + 1);
    const S = sculpt('tail_' + part, S => {
      S.tube(seg, LK.hide, { smooth: false, minR: .7 });
      // the underside plates face the viewer on the near side of the curl
      S.band(seg.map(q => [q[0] + .15 * q[2], q[1] + .6 * q[2], q[2] * .45]), LK.belly, { only: [LK.hide] });
      if (p >= 2) for (let i = 2; i < seg.length - 1; i += (p >= 3 ? 3 : 4)) {
        const q = seg[i], q2 = seg[Math.min(seg.length - 1, i + 1)], dx = q2[0] - q[0], dy = q2[1] - q[1], l = Math.hypot(dx, dy) || 1, nx = dy / l, ny = -dx / l;
        const top = [q[0] + nx * q[2] * .8, q[1] + ny * q[2] * .8], h = Math.max(1.4, q[2] * (p >= 3 ? 1 : .65));
        S.tube([[top[0], top[1], Math.max(.7, q[2] * .34), 2], [top[0] + nx * h - dx / l * h * .7, top[1] + ny * h - dy / l * h * .7, .35, 2]], LK.bone, { smooth: false, z: q[2] });
      }
    });
    const [jx, jy] = X(G.tail[steps[0] - 1][0], G.tail[steps[0] - 1][1]);
    P.joint('tail_' + part, jx + .5, jy + .5);
    S.flush();
    if (F.crack && F.crackParts && part <= 2) cracks(S, 50 + part, 1, 5, F.crack, { cols: dark(S) });
    if (F.spots && part <= 2) spots(S, 60 + part, F.spots, 1);
  }
  const tip = G.tail[10], [tx, ty] = X(tip[0], tip[1]);
  P.joint('tail_tip', tx + .5, ty + .5);
  P.part('tail_flame').joint('tail_flame', tx + .5, ty + .5);
  const fw = Math.max(4, Math.round(G.tailFlame[0] * s)), fh = Math.max(6, Math.round(G.tailFlame[1] * s));
  P.flame(tx - Math.round(fw / 2) + 1, ty + 1, fw, fh, { seed: 3, pal: F.fire, front: true, lean: -1 });
  P.flame(tx - Math.round(fw / 4), ty, Math.max(2, Math.round(fw / 2)), Math.round(fh * .62), { seed: 8, pal: F.fire, front: true, sparks: false });

  // ----- far hind leg -----
  sculpt('leg_far', S => leg(S, G.legFar, LK.hideFar, LK.boneFar)).flush();
  J('leg_far', [G.legFar.upper[0][0], G.legFar.upper[0][1] + 1]);

  // ----- body: far arm and far shoulder behind, the trunk, the pectoral bulge -----
  const B = sculpt('body', S => {
    if (G.farArm) { S.tube(G.farArm.pts.map(q => [q[0], q[1], q[2], -12]), LK.hideFar, { smooth: false }); for (const cl of G.farArm.claws) S.tube(cl.map(q => [q[0], q[1], q[2], -10]), LK.boneFar); }
    if (G.farShoulder) S.ell(G.farShoulder[0], G.farShoulder[1], LK.hideFar, { ang: G.farShoulder[2], z: -8 });
    S.tube(G.torso, LK.hide, { steps: 6 });
    S.ell(G.bulge[0], G.bulge[1], LK.hide, { ang: G.bulge[2], z: 6, dz: 7 });
    S.band(G.ventral, LK.belly, { only: [LK.hide] });
    // dorsal spikes along the spine, behind the wing
    for (const [x, y] of G.spine) S.tube([[x, y, 2.4, 14], [x - 5, y - 6, .5, 14]], LK.bone, { smooth: false });
  });
  J('body', G.torso[1]);
  J('core', G.core);
  B.flush();
  if (F.crack) cracks(B, 7, F.crackN, 7, F.crack, { cols: dark(B) });
  if (F.spots) spots(B, 9, F.spots, 4);
  if (p === 1) dorsalFire(P, G, X, s, F);
  if (p === 4) { const [cx, cy] = X(G.core[0], G.core[1]); voidCore(P, B, cx, cy, s, f); }

  // ----- near hind leg -----
  const LN = sculpt('leg_near', S => leg(S, G.legNear, LK.hide, LK.bone));
  J('leg_near', [G.legNear.upper[0][0] + 1, G.legNear.upper[0][1] + 1]);
  LN.flush();
  if (F.crack && F.crackParts) cracks(LN, 21, F.crackParts, 5, F.crack, { cols: dark(LN) });
  if (F.spots) spots(LN, 23, F.spots, 2);

  // ----- near wing: spread wide across the frame, torn at the trailing edge -----
  if (G.wingNear) {
    const S = sculpt('wing_near', S => {
      wing(S, G.wingNear, { membrane: { ramp: F.wing, amb: .16, edge: F.wingEdge }, bone: LK.hide, claw: LK.bone, tusks: F.tusks });
      for (const [c, r] of G.wingNear.tears || []) S.cut(c, r);
    });
    J('wing_near', G.wingNear.root);
    S.flush(); wingVeins(S, G.wingNear, F.vein);
  }

  // ----- neck: rises from the chest, plates on its throat side, spikes along the top -----
  const nk = G.neck, N0 = nk[0], NE = nk[nk.length - 1];
  const NS = sculpt('neck', S => {
    S.tube(nk, LK.hide, { steps: 6 });
    S.band(G.neckVentral, LK.belly, { only: [LK.hide] });
    const dense = spline(nk, 4);
    if (p >= 2) for (let i = 3; i < dense.length - 3; i += (p >= 3 ? 3 : 4)) {
      const q = dense[i], q2 = dense[i + 1], dx = q2[0] - q[0], dy = q2[1] - q[1], l = Math.hypot(dx, dy) || 1, nx = dy / l, ny = -dx / l;
      const top = [q[0] + nx * q[2] * .78, q[1] + ny * q[2] * .78], h = q[2] * (p >= 3 ? .7 : .5);
      S.tube([[top[0], top[1], Math.max(.8, q[2] * .26), 3], [top[0] + nx * h - dx / l * h * .8, top[1] + ny * h - dy / l * h * .8, .35, 3]], LK.bone, { smooth: false, z: q[2] });
    }
  });
  J('neck', [N0[0], N0[1]]); J('head', [NE[0], NE[1]]);
  J('throat_at', G.throat ? G.throat[0] : v(G.neckVentral[1], G.neckVentral[2], .4));
  NS.flush();
  if (F.crack && F.crackParts > 1) cracks(NS, 31, 2, 5, F.crack, { cols: dark(NS) });
  if (F.spots) spots(NS, 33, F.spots, 1);

  // ----- void crystals (form 4): three shards from the upper back, in front of the wing root -----
  if (G.crystals && F.crystal) G.crystals.forEach((cr, i) => {
    const id = 'crystal_' + (i + 1);
    const S = sculpt(id, S => crystal(S, cr, F.crystal));
    J(id, cr.base);
    S.flush();
    const t = v(cr.base, cr.tip, .8), [gx, gy] = X(t[0], t[1]);
    P.glow(gx, gy, WHITE).glow(gx, gy + 1, LILAC).glow(gx - 1, gy + 1, VIO);
  });

  // ----- near arm: the shoulder mass overlaps the neck base and the wing root -----
  const A = G.arm;
  const AS = sculpt('arm', S => {
    S.tube(A.upper.map(q => [q[0], q[1], q[2], 10]), LK.hide, { dz: .8 });
    S.tube(A.pts.map(q => [q[0], q[1], q[2], 8]), LK.hide, { smooth: false });
    S.ell(A.hand[0], A.hand[1], LK.hide, { ang: A.hand[2], z: 9 });
    for (const cl of A.claws) S.tube(cl.map(q => [q[0], q[1], q[2], 10]), LK.bone);
  });
  J('arm', [A.upper[0][0] + 2, A.upper[0][1] + 3]);
  J('hand', A.hand[0]);
  AS.flush();
  if (F.crack && F.crackParts > 1) cracks(AS, 41, 2, 5, F.crack, { cols: dark(AS) });
  if (F.spots) spots(AS, 43, F.spots, 1);

  // ----- throat gland (forms 3, 4): the weak spot on the front of the neck -----
  if (G.throat && F.gland) {
    const S = sculpt('throat', S => S.ell(G.throat[0], G.throat[1], { ramp: F.gland, amb: .3, rim: F.gland[3] }, { ang: G.throat[2], z: 12 }));
    J('throat', G.throat[0]);
    S.flush();
    const [gx, gy] = X(G.throat[0][0], G.throat[0][1]), sk = p === 4 ? PLUM : MAROON;
    for (const k of [-1, 1]) for (let j = -1; j <= 1; j++) S.dot(gx + k * 2 * s + j, gy + k * 1.5 * s + j * .6, sk);
    if (p === 4) for (let k = -2; k <= 2; k++) S.dot(gx + k * .6 * s, gy - k * .75 * s, k === 0 ? WHITE : LILAC);
  }

  // ----- jaw: hangs open, the glowing inside of the mouth rides on it -----
  const JW = G.jaw;
  const JS = sculpt('jaw', S => {
    const a = X(JW.hinge[0], JW.hinge[1]), mo = v(JW.mouth[1], JW.mouth[2], .5), b = X(mo[0], mo[1]), L0 = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    S.flat(JW.mouth, { ramp: F.mouth, amb: .2, tone: (c) => (c.tex.d < .3 ? 2 : c.tex.d < .5 ? 1 : c.tex.d < .75 ? 0 : -1) }, [0, 0, 1], {
      z: -2, tex: (x, y) => ({ d: Math.hypot(x - a[0], y - a[1]) / L0 }) });
    S.tube(JW.pts.map(q => [q[0], q[1], q[2], 4]), LK.hide, { smooth: true });
  });
  J('jaw', JW.hinge);
  J('mouth', v(JW.mouth[1], JW.mouth[2], .5));
  JS.flush();
  // lower teeth stand on the jaw's top edge
  {
    const n = p >= 3 ? 5 : p === 2 ? 4 : 3, a = JW.pts[0], b = JW.pts[JW.pts.length - 1], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), ux = dy / l, uy = -dx / l;
    for (let k = 1; k <= n; k++) {
      const t = .3 + k / (n + 1) * .65, q = v(a, b, t), r = (a[2] + (b[2] - a[2]) * t) * s, [x, y] = X(q[0], q[1]);
      const tx = x + ux * (r + .3), ty = y + uy * (r + .3);
      JS.P.dot(tx, ty, WHITE);
      if (k === n - 1 && p >= 2) JS.P.dot(tx, ty - 1, WHITE).dot(tx, ty - 2, BONE);
    }
  }

  // ----- head: skull, snout turned toward the hero, top ridge, heavy brow, cheek muscle -----
  const HS = sculpt('head', S => {
    S.ell(G.skull[0], G.skull[1], LK.hide, { ang: G.skull[2], z: 6 });
    S.ell(G.cheekMass[0], G.cheekMass[1], LK.hide, { ang: G.cheekMass[2], z: 9, dz: 4 });
    S.tube(G.snout.map(q => [q[0], q[1], q[2], 6]), LK.hide);
    S.tube(G.ridge.map(q => [q[0], q[1], q[2], 11]), LK.hide, { dz: .7 });
    S.tube(G.brow.map(q => [q[0], q[1], q[2], 12]), LK.hide, { dz: .8 });
    for (const sp of G.cheek) S.tube(sp.map(q => [q[0], q[1], q[2], 6]), LK.bone);
    if (G.nubs) for (const nb of G.nubs) S.tube(nb.map(q => [q[0], q[1], q[2], 8]), LK.bone);
    for (const cr of G.crest || []) S.tube(cr.map(q => [q[0], q[1], q[2], 9]), LK.bone);
  });
  HS.flush();
  {
    // upper teeth along the snout's lower edge, two fangs hanging over the jaw
    const a = G.snout[0], b = G.snout[G.snout.length - 1], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), ux = -dy / l, uy = dx / l;
    const edge = t => { const q = v(a, b, t), r = (a[2] + (b[2] - a[2]) * t) * s, [x, y] = X(q[0], q[1]); return [x + ux * (r - .3), y + uy * (r - .3)]; };
    const n = p >= 3 ? 6 : p === 2 ? 5 : 3;
    for (let k = 1; k <= n; k++) { const [x, y] = edge(.12 + k / (n + 1) * .84); HS.P.dot(x, y + 1, WHITE); }
    for (const [t, len] of G.fangs) { const [x, y] = edge(t), m = Math.max(2, Math.round(len * Math.max(.6, s))); for (let i = 0; i < m; i++) HS.P.dot(x, y + 1 + i, i < m - 1 ? WHITE : BONE); }
    const [nx, ny] = X(G.nostril[0], G.nostril[1]); HS.dot(nx, ny, K).dot(nx + 1, ny, K);
    if (F.crack) HS.dot(nx, ny - 1, F.crack[0]);
  }
  // eyes: a glowing slit in the brow's shadow, the far eye a glint past the snout ridge
  {
    const [ex, ey] = X(G.eye[0], G.eye[1]), e = F.eye, big = p >= 3;
    const px = big
      ? [[-4, -2, e[0]], [-3, -2, e[1]], [-3, -1, e[1]], [-2, -1, e[2]], [-1, -1, e[1]], [-1, 0, e[2]], [0, 0, e[2]], [1, 0, e[2]], [2, 0, e[1]], [3, 1, e[1]], [4, 1, e[0]], [-2, 0, e[0]], [0, 1, e[1]], [1, 1, e[1]], [2, 1, e[0]], [-4, -1, F.eyeHalo || RED], [-1, 1, F.eyeHalo || RED], [3, 2, F.eyeHalo || RED]]
      : [[-2, -1, e[0]], [-1, 0, e[1]], [0, 0, e[2]], [1, 0, e[1]], [2, 1, e[0]]];
    for (const [dx, dy, c] of px) P.glow(ex + dx, ey + dy, c);
    const [fx, fy] = X(G.eyeFar[0], G.eyeFar[1]);
    P.glow(fx - 1, fy, e[0]).glow(fx, fy, e[1]).glow(fx + 1, fy - (big ? 1 : 0), e[0]);
  }
  if (F.crack && p >= 3) cracks(HS, 71, 2, 5, F.crack, { cols: dark(HS) });

  // ----- horns (forms 3, 4): devil horns, the near one in front, the far one behind -----
  if (G.horns) {
    const S = sculpt('horns', S => {
      S.tube(G.horns[1].map(q => [q[0], q[1], q[2], 2]), LK.boneFar, { steps: 6 });
      S.tube(G.horns[0].map(q => [q[0], q[1], q[2], 12]), LK.bone, { steps: 6 });
    });
    J('horns', [G.horns[0][0][0] + 1, G.horns[0][0][1] + 1]);
    S.flush();
    // growth rings on the near horn
    const dense = spline(G.horns[0], 6);
    for (let i = 4; i < dense.length - 8; i += 4) {
      const q = dense[i], q2 = dense[i + 1], dx = q2[0] - q[0], dy = q2[1] - q[1], l = Math.hypot(dx, dy) || 1;
      S.line([q[0] + dy / l * q[2] * .9, q[1] - dx / l * q[2] * .9], [q[0] - dy / l * q[2] * .2, q[1] + dx / l * q[2] * .2], FORM[p].bone[0]);
    }
  }

  // ----- mouth flames (form 4): void fire licking from the maw -----
  if (p === 4) {
    const c1 = v(JW.mouth[0], JW.mouth[3], .5), [mx, my] = X(c1[0] + 3, c1[1] + 1);
    P.part('mouth_flame').joint('mouth_flame', mx + .5, my + .5);
    P.flame(mx - 2, my + 1, 4, 8, { seed: 11, pal: F.fire, front: true, lean: -3, sparks: false });
    const c2 = v(JW.mouth[1], JW.mouth[2], .5), [nx, ny] = X(c2[0], c2[1]);
    P.flame(nx - 3, ny + 2, 5, 9, { seed: 17, pal: F.fire, front: true, lean: -2, sparks: true });
    P.flame(nx - 5, ny + 4, 3, 7, { seed: 23, pal: F.fire, front: true, dir: 1, lean: -1, sparks: false });
  }
}

// A leg: thigh mass, digitigrade limb (hip, knee, hock, ball), toes ending in claws.
function leg(S, g, hide, claw) {
  S.tube(g.upper.map(q => [q[0], q[1], q[2], 6]), hide, { dz: .8 });
  S.tube(g.pts.map(q => [q[0], q[1], q[2], 4]), hide, { smooth: false });
  if (g.spur) S.tube(g.spur.map(q => [q[0], q[1], q[2], 3]), claw, { smooth: false });
  for (const t of g.toes) {
    const n = t.length;
    S.tube(t.slice(0, n - 1).map(q => [q[0], q[1], q[2], 5]), hide, { smooth: false });
    S.tube([[...t[n - 2].slice(0, 2), t[n - 2][2] * .62, 6], [...t[n - 1].slice(0, 2), t[n - 1][2], 6]], claw, { smooth: false });
  }
}
// A wing: membrane panels between the finger bones (alternating normals read as pleats), the
// arm and finger bones on top, a thumb claw at the wrist, gold tusks on form 4.
function wing(S, w, o) {
  const { root, elbow, wrist, tips, trail } = w;
  const sagEdge = (a, b, k) => { const out = []; for (let i = 1; i < 4; i++) { const t = i / 4, sag = Math.sin(Math.PI * t) * k, x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t; out.push([x + (wrist[0] - x) * sag, y + (wrist[1] - y) * sag]); } return out; };
  const bones = [[root, elbow], [elbow, wrist], ...tips.map(t => [wrist, t])];
  const { s, ox, oy } = S.T, B = bones.map(([a, b]) => [[ox + a[0] * s, oy + a[1] * s], [ox + b[0] * s, oy + b[1] * s]]);
  const boneDist = (x, y) => { let best = Infinity; for (const [a, b] of B) { const dx = b[0] - a[0], dy = b[1] - a[1], t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy || 1))); best = Math.min(best, Math.hypot(x - a[0] - dx * t, y - a[1] - dy * t)); } return best; };
  const mem = Object.assign({}, o.membrane, { tone: (c) => { const d = c.tex.d / Math.max(1, s * 4); return d < .5 ? 1 : d > 2.2 ? -1 : 0; } });
  const normals = o.far ? [[-.2, -.3, .93], [.35, .1, .93], [-.1, -.2, .97], [.3, .25, .9]] : [[-.45, -.4, .8], [.3, .05, .95], [-.35, -.3, .88], [.35, .15, .92], [-.1, -.1, .99]];
  const panels = [];
  for (let i = 0; i < tips.length - 1; i++) panels.push([wrist, tips[i], ...sagEdge(tips[i], tips[i + 1], .26), tips[i + 1]]);
  panels.push([wrist, tips[tips.length - 1], ...sagEdge(tips[tips.length - 1], trail, .16), trail, root, elbow]);
  // the leading membrane between shoulder, elbow and wrist
  panels.push([root, elbow, wrist, v2(elbow, wrist, .5, 0, 3), v2(root, elbow, .5, 3, 1)]);
  panels.forEach((poly, i) => S.flat(poly, mem, normals[i % normals.length], { z: 0, tex: (x, y) => ({ d: boneDist(x, y) }) }));
  const [r0, r1, r2] = w.r;
  S.tube([[...root, r0, 4], [...elbow, r1, 4]], o.bone, { smooth: false });
  S.tube([[...elbow, r1, 4], [...wrist, r2, 4]], o.bone, { smooth: false });
  tips.forEach((t, i) => S.tube([[...wrist, r2 * .8, 3], [...v2(wrist, t, .5, 0, 0), r2 * .55, 3], [...t, .4, 3]], o.bone, { smooth: false }));
  // wrist knuckle and thumb claw
  S.ell(wrist, [r2 * 1.3, r2 * 1.2], o.bone, { z: 5 });
  S.tube([[wrist[0] - 1, wrist[1] - 1, r2 * .8, 6], [wrist[0] + 1.5, wrist[1] - 5, .5, 6]], o.claw, { smooth: false });
  if (o.tusks) for (const [a, b, len] of [[elbow, wrist, 6], [root, elbow, 5], [elbow, wrist, 4.5]].map((q, i) => [q[0], q[1], q[2], i])) {
    const at = len > 5 ? a : v2(a, b, .55, 0, 0), dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), nx = dy / l, ny = -dx / l;
    S.tube([[at[0], at[1], 1.6, 7], [at[0] + nx * len * .6 - dx / l * len * .3, at[1] + ny * len * .6 - dy / l * len * .3, 1, 7], [at[0] + nx * len - dx / l * len * .75, at[1] + ny * len - dy / l * len * .75, .4, 7]], o.claw);
  }
}
const v2 = (a, b, t, dx, dy) => [a[0] + (b[0] - a[0]) * t + dx, a[1] + (b[1] - a[1]) * t + dy];
// Veins: thin lines from the wrist into each membrane panel.
function wingVeins(S, w, col) {
  if (!S.P.keep() || !col) return;
  const { wrist, tips, trail } = w;
  const ends = [];
  for (let i = 0; i < tips.length - 1; i++) ends.push(v2(v2(tips[i], tips[i + 1], .5, 0, 0), wrist, .2, 0, 0));
  ends.push(v2(v2(tips[tips.length - 1], trail, .5, 0, 0), wrist, .15, 0, 0));
  for (const e of ends) {
    const mid = v2(wrist, e, .5, (e[1] - wrist[1]) * .06, -(e[0] - wrist[0]) * .06);
    S.line(v2(wrist, mid, .25, 0, 0), mid, col, { inner: true }).line(mid, v2(mid, e, .85, 0, 0), col, { inner: true });
  }
}
// A void crystal: two facets (lit and shaded), a bright ridge.
function crystal(S, cr, ramp) {
  const { base, tip, w } = cr, dx = tip[0] - base[0], dy = tip[1] - base[1], l = Math.hypot(dx, dy), ux = dx / l, uy = dy / l, nx = -uy, ny = ux;
  const at = (t, k) => [base[0] + dx * t + nx * w * .5 * k, base[1] + dy * t + ny * w * .5 * k];
  // lit facet violet with a lilac top, shaded facet indigo; the ridge between them burns white
  const lit = { ramp: [ramp[1], ramp[1], ramp[2], ramp[2]], amb: .2, tone: c => (c.tex.k > .7 ? 1 : c.tex.k < .35 ? -1 : 0) };
  const dark = { ramp: [ramp[0], ramp[0], ramp[0], ramp[1]], amb: .1 };
  const kt = (x, y) => { const { s, ox, oy } = S.T, bx = ox + base[0] * s, by = oy + base[1] * s; return { k: ((x - bx) * ux + (y - by) * uy) / (l * s) }; };
  S.flat([at(-.05, -.75), at(.62, -1), at(1, 0), at(.6, .05), at(0, .05)], lit, [-.6, -.4, .7], { z: 2, tex: kt });
  S.flat([at(0, .05), at(.6, .05), at(1, 0), at(.6, 1), at(-.05, .7)], dark, [.6, .2, .78], { z: 2 });
  S.tube([[...at(.3, -.05), .5, 4], [...at(.9, -.02), .5, 4]], { ramp: [ramp[3], ramp[4]], amb: .9 }, { smooth: false });
}
// Glowing salamander spots (form 1): a hot centre in a small ring.
function spots(S, seed, col, n) {
  if (!S.P.keep()) return;
  const R = rng(seed), cells = [...S.m.values()].filter(c => S.inner(c.x, c.y) && S.inner(c.x + 1, c.y) && S.inner(c.x, c.y + 1));
  for (let k = 0; k < n && cells.length; k++) {
    const c = cells[Math.floor(R() * cells.length)];
    S.P.dot(c.x, c.y, col[1]); S.P.dot(c.x + 1, c.y, col[0]); S.P.dot(c.x, c.y + 1, col[0]);
  }
}
// The salamander's fire crest: small flames standing on its back (behind its own body pixels).
function dorsalFire(P, G, X, s, F) {
  const pts = [[-14, -40], [-7, -47], [0, -53], [7, -56], [13, -58]];
  pts.forEach(([x, y], i) => { const [px, py] = X(x, y); P.flame(px - 1, py + 2, 3, 5 + (i % 2) * 2, { seed: 30 + i * 7, pal: F.fire, sparks: i % 2 === 0 }); });
}
// Form 4's void core on the chest: a gem with a white-hot centre.
function voidCore(P, B, cx, cy, s, f) {
  const r = Math.round(2.6 * s);
  for (let y = -r - 1; y <= r + 1; y++) for (let x = -r; x <= r; x++) {
    const d = Math.abs(x) / r + Math.abs(y) / (r + 1);
    if (d > 1) continue;
    B.dot(cx + x, cy + y, d > .8 ? INDIGO : x + y < -1 ? (d < .45 ? LILAC : VIO) : d < .4 ? VIO : VIOD);
  }
  P.glow(cx, cy, f % 4 < 2 ? WHITE : LILAC);
}

// ---------- rig contract (same as HM.renderDrakeRig) ----------
/** Form p (1-4): part = a part id renders only that part (its own outline), null all of them. */
function renderRig(p, part, frame, skip) {
  const F = fit(p), P = new HM.Painter(F.W, F.H, frame || 0, part == null ? null : part);
  drawDrake(P, p, F.ox);
  return { w: F.W, h: F.H, px: P.finish(skip), solid: P.solid.map(Boolean), joints: P.joints, tags: P.tags };
}
// The frame: drawn once on a large canvas (all four flame frames), then cropped to the drawing with
// 2 px to spare on the left, right and top (the outline and one free column, so no part touches
// row 0, column 0 or the last column); the feet stay on the bottom row.
function fit(p) {
  const F = FORM[p];
  if (F.W) return F;
  const BW = 420, BH = 280, O = 210;
  let x0 = BW, x1 = -1, y0 = BH;
  for (let f = 0; f < 4; f++) {
    const P = new HM.Painter(BW, BH, f, null);
    drawDrake(P, p, O);
    const px = P.finish();
    for (let i = 0; i < px.length; i++) if (px[i]) { const x = i % BW, y = Math.floor(i / BW); x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); }
  }
  F.ox = O - x0 + 1; F.W = x1 - x0 + 3; F.H = BH - y0 + 1;
  return F;
}
// Copied from export_rigs.js (not exported there): joints without a seam.
const SEAMLESS = [['body', 'neck'], ['neck', 'head'], ['body', 'tail_1'], ['tail_1', 'tail_2'], ['tail_2', 'tail_3'], ['tail_3', 'tail_4'], ['tail_4', 'tail_5']];
const FLIPBOOK = new Set(['tail_flame', 'mouth_flame']);
const cache = new Map();
/** Every part isolated (with the export's seam rule), sorted by the rig's layers. */
function parts(p, frame) {
  const key = p + ':' + (frame || 0);
  if (cache.has(key)) return cache.get(key);
  const all = renderRig(p, null, 0), ids = all.tags.filter(t => ER.Z[t] !== undefined).sort((a, b) => ER.Z[a] - ER.Z[b]);
  const solid = {};
  for (const id of ids) solid[id] = renderRig(p, id, 0).solid;
  const out = ids.map(id => {
    const near = SEAMLESS.filter(pr => pr.includes(id)).map(pr => solid[pr[0] === id ? pr[1] : pr[0]]).filter(Boolean);
    const skip = near.length ? i => near.some(m => m[i]) : undefined;
    return { id, z: ER.Z[id], img: renderRig(p, id, FLIPBOOK.has(id) ? frame || 0 : 0, skip) };
  });
  const res = { parts: out, joints: all.joints, w: all.w, h: all.h, tags: all.tags };
  cache.set(key, res);
  return res;
}
/** The rest pose as the game stacks it: { w, h, px (colour strings or null) }. */
function compose(p, frame) {
  const r = parts(p, frame), px = new Array(r.w * r.h).fill(null);
  for (const e of r.parts) e.img.px.forEach((c, i) => { if (c) px[i] = c; });
  return { w: r.w, h: r.h, px };
}

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
    const im = e.img.px;
    for (let x = 0; x < W; x++) if (im[x]) { problems.push(`${e.id}: touches row 0`); break; }
    for (let y = 0; y < H; y++) if (im[y * W]) { problems.push(`${e.id}: touches column 0`); break; }
    for (let y = 0; y < H; y++) if (im[y * W + W - 1]) { problems.push(`${e.id}: touches column ${W - 1}`); break; }
  }
  for (const name in POINTS) { const at = r.joints[name]; if (!at) problems.push(`point ${name} missing`); else if (byId[POINTS[name]] && near(POINTS[name], at) > 3) problems.push(`point ${name} ${near(POINTS[name], at).toFixed(1)} px from ${POINTS[name]}`); }
  // pixels a hit lands on (highest layer), for every part the current rig can sever
  const form = ER.FORMS[p], sev = Object.keys(form.cut);
  for (const g in form.groups) for (const m of form.groups[g].parts) if (!sev.includes(m)) sev.push(m);
  const vis = Object.fromEntries(r.parts.map(e => [e.id, 0]));
  for (let i = 0; i < W * H; i++) { let owner = null, z = -Infinity; for (const e of r.parts) if (e.img.px[i] && e.z > z) { owner = e.id; z = e.z; } if (owner) vis[owner]++; }
  for (const id of sev) if ((vis[id] || 0) < 20) problems.push(`${id}: only ${vis[id]} px can be hit (20)`);
  // flipbooks flicker
  for (const id of FLIPBOOK) if (byId[id]) { const set = new Set([0, 1, 2, 3].map(f => parts(p, f).parts.find(e => e.id === id).img.px.join())); if (set.size < 3) problems.push(`${id}: ${set.size} distinct frames`); }
  // feet on the bottom row
  const footRow = ['leg_far', 'leg_near'].map(id => { const im = byId[id].img.px; let y1 = -1; for (let i = 0; i < W * H; i++) if (im[i]) y1 = Math.max(y1, Math.floor(i / W)); return y1; });
  if (Math.max(...footRow) !== H - 1) problems.push(`feet end on row ${Math.max(...footRow)}, frame bottom ${H - 1}`);
  return { problems, visible: sev.map(id => `${id} ${vis[id]}`).join(', ') };
}

// ---------- images ----------
const hex = c => [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16), 255];
function Canvas(w, h, bg) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); for (let i = 0; i < w * h; i++) this.d.set(bg, i * 4); }
Canvas.prototype.px = function (x, y, c) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d.set(c, (y * this.w + x) * 4); };
Canvas.prototype.rect = function (x, y, w, h, c) { for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, c); };
// darkens (multiplies) a pixel: shadows
Canvas.prototype.shade = function (x, y, k) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4; for (let j = 0; j < 3; j++) this.d[i + j] = Math.round(this.d[i + j] * k); };
Canvas.prototype.tint = function (x, y, c, a) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4; for (let j = 0; j < 3; j++) this.d[i + j] = Math.round(this.d[i + j] * (1 - a) + c[j] * a); };
/** Draws colour-string pixels (w x h) at x, y, k output px per source px, optionally mirrored. */
Canvas.prototype.sprite = function (px, w, h, x, y, k, flip) {
  for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) { const c = px[yy * w + (flip ? w - 1 - xx : xx)]; if (c) this.rect(x + xx * k, y + yy * k, k, k, hex(c)); }
};
/** RGBA image scaled by a real factor (nearest neighbour). */
Canvas.prototype.rgba = function (img, x, y, k, flip) {
  const W = Math.round(img.w * k), H = Math.round(img.h * k);
  for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
    const sx = Math.min(img.w - 1, Math.floor(xx / k)), sy = Math.min(img.h - 1, Math.floor(yy / k)), i = (sy * img.w + (flip ? img.w - 1 - sx : sx)) * 4;
    if (img.rgba[i + 3] > 0) this.px(x + xx, y + yy, img.rgba.subarray(i, i + 4));
  }
};
// A soft ground shadow: two dithered rings around a dark core, in blocks of k px.
Canvas.prototype.shadow = function (cx, cy, rx, ry, k) {
  for (let y = Math.floor(-ry); y <= Math.ceil(ry); y++) for (let x = Math.floor(-rx); x <= Math.ceil(rx); x++) {
    const d = (x / rx) ** 2 + (y / ry) ** 2;
    if (d > 1) continue;
    const ring = d < .55 ? .45 : d < .8 ? .6 : ((x + y) & 1) ? .72 : 1;
    if (ring < 1) for (let yy = 0; yy < k; yy++) for (let xx = 0; xx < k; xx++) this.shade(Math.round(cx + x * k + xx), Math.round(cy + y * k + yy), ring);
  }
};
const FONT = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111', F: '111100110100100',
  G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010', K: '101101110101101', L: '100100100100111',
  M: '101111111101101', N: '110101101101101', O: '010101101101010', P: '110101110100100', Q: '010101101110011', R: '110101110101101',
  S: '011100010001110', T: '111010010010010', U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101',
  Y: '101101010010010', Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111', 9: '111101111001110',
  ' ': '000000000000000', '.': '000000000000010', ':': '000010000010000', '-': '000000111000000', '/': '001001010100100', '(': '001010010010001', ')': '100010010010100', '=': '000111000111000', ',': '000000000010100', x: '000101010101000',
};
Canvas.prototype.text = function (x, y, str, c, k) {
  k = k || 2;
  for (const ch of String(str)) { const g = FONT[ch] || FONT[ch.toUpperCase()] || FONT[' ']; for (let i = 0; i < 15; i++) if (g[i] === '1') this.rect(x + (i % 3) * k, y + Math.floor(i / 3) * k, k, k, c); x += 4 * k; }
};
const textW = (str, k) => String(str).length * 4 * k;

/** Decodes an 8-bit RGBA/RGB/palette PNG to { w, h, rgba } (the knight and the floor tiles). */
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

// ---------- the three preview sheets ----------
const BG = [36, 24, 28, 255], BG2 = [48, 32, 36, 255], TXT = [236, 226, 214, 255], DIM = [160, 140, 140, 255], ACC = [238, 142, 46, 255];
const HERO_H = 28 * 3; // the 0x72 knight's height in world px
// ground row of a composed form: its feet's centre (for the shadow and the knight's baseline)
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
  c.text(gap, 10, 'IGNAROTH  KONZEPT MONUMENTAL  -  ALLE FORMEN IM SPIEL-MASSSTAB (1 QUELLPIXEL = 5 WELT-PX, HIER X0.4)', TXT, 2);
  let x = gap;
  forms.forEach((p, i) => {
    const F = FORM[p], img = compose(p, 1), ft = footing(p), kx = x, dx = x + 40;
    c.shadow(dx + ft.cx * K2, base - 1, ft.half * 1.05, 3.2, K2);
    c.sprite(img.px, img.w, img.h, dx, base - F.H * K2, K2);
    // the knight (x3 in the world, then the same x0.4)
    c.shadow(kx + 10, base - 1, 6, 1.6, 1);
    c.rgba(knight, kx, base - Math.round(knight.h * 1.2), 1.2);
    const hp = heightPx(p) * 5 / HERO_H;
    c.text(x, base + 10, `${p}  ${F.name.toUpperCase()}`, TXT, 2);
    c.text(x, base + 26, `${F.W}x${F.H} PX = ${hp.toFixed(1)}x HELD`, DIM, 2);
    x += ws[i] + gap;
  });
  fs.writeFileSync(file, encodePng(W, H, c.d));
}

function bigSheet(file) {
  const k = 5, pad = 30, top = 40, f4 = FORM[4], f3 = FORM[3];
  const W = pad * 3 + f4.W * k + f3.W * k, H = top + f4.H * k + 70;
  const c = new Canvas(W, H, BG), base = top + f4.H * k;
  c.rect(0, base, W, H - base, BG2);
  c.text(pad, 12, 'FORM 4 OBSIDIANFORM UND FORM 3 GLUTDRACHE  -  1 QUELLPIXEL = 5 PX (WELT-MASSSTAB)', TXT, 2);
  const draw = (p, x) => { const F = FORM[p], img = compose(p, 1), ft = footing(p); c.shadow(x + ft.cx * k, base - 2, ft.half * 1.1, 3.4, k); c.sprite(img.px, img.w, img.h, x, base - F.H * k, k); c.text(x, base + 14, `${p}  ${F.name.toUpperCase()}  ${F.W}x${F.H}`, TXT, 3); };
  draw(4, pad);
  draw(3, pad * 2 + f4.W * k);
  fs.writeFileSync(file, encodePng(W, H, c.d));
}

function ingame(knight, tiles, file, p) {
  const W = 1280, H = 720, c = new Canvas(W, H, [20, 12, 14, 255]);
  // floor: the hell's own 96 px tiles (2 x 2 slabs of 48 world px), mostly plain, a few cracked
  const pick = (tx, ty) => { const r = (Math.imul(tx + 7, 73856093) ^ Math.imul(ty + 3, 19349663)) >>> 0; return tiles[(r >>> 7) % tiles.length]; };
  for (let ty = 0; ty * 96 < H; ty++) for (let tx = 0; tx * 96 < W; tx++) c.rgba(pick(tx, ty), tx * 96 - 40, ty * 96 - 30, 1);
  // lava light and darkness at the edges, like the game's vignette
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const d = Math.hypot((x - W / 2) / W, (y - H / 2) / H); if (d > .32) c.tint(x, y, [80, 10, 16], Math.min(.55, (d - .32) * 1.6)); }
  const F = FORM[p], img = compose(p, 1), ft = footing(p), k = 5;
  // the dragon faces the knight (the game mirrors it toward its target)
  const gx = Math.round(W / 2 + 70), gy = 650, x0 = Math.round(gx - (F.W - ft.cx) * k);
  c.shadow(gx, gy - 4, ft.half * 1.1, 3.4, k);
  c.sprite(img.px, img.w, img.h, x0, gy - F.H * k, k, true);
  // the knight: x3, front left, a few tiles in front of the claws
  const kx = 250, ky = 676;
  c.shadow(kx + 24, ky - 2, 8, 2.4, 3);
  c.rgba(knight, kx, ky - knight.h * 3, 3);
  c.rect(16, 16, textW(`IGNAROTH ${F.name.toUpperCase()}  -  1 QUELLPIXEL = 5 WELT-PX, RITTER X3  -  BILD = 1280x720 WELT-PX`, 2) + 16, 26, [14, 8, 10, 255]);
  c.text(24, 22, `IGNAROTH ${F.name.toUpperCase()}  -  1 QUELLPIXEL = 5 WELT-PX, RITTER X3  -  BILD = 1280x720 WELT-PX`, TXT, 2);
  fs.writeFileSync(file, encodePng(W, H, c.d));
}

function main() {
  const root = process.argv.slice(2).find(a => !a.startsWith('--')) || path.join(__dirname, '..', '..', '..');
  const out = path.join(root, 'production', 'qa', 'evidence', 'drake-concepts');
  fs.mkdirSync(out, { recursive: true });
  for (const p of [1, 2, 3, 4]) {
    const r = checkForm(p);
    console.log(`drache${p} ${FORM[p].name}: ${FORM[p].W}x${FORM[p].H}, ${heightPx(p)} px tall = ${(heightPx(p) * 5 / HERO_H).toFixed(2)}x hero, hit px: ${r.visible}${r.problems.length ? '\n  ' + r.problems.join('\n  ') : ', contract ok'}`);
  }
  const knight = decodePng(fs.readFileSync(path.join(root, 'assets', 'sprites', '0x72', 'knight_m_idle_anim_f0.png')));
  const tiles = ['00', '00', '00', '00', '00', '00', '00', '01', '04', '11', '03'].map(n => decodePng(fs.readFileSync(path.join(root, 'assets', 'sprites', 'hell', `floor_${n}.png`))));
  lineup(knight, path.join(out, 'monumental_lineup.png'));
  bigSheet(path.join(out, 'monumental_form4.png'));
  ingame(knight, tiles, path.join(out, 'monumental_ingame.png'), 4);
  console.log('wrote', out);
}

module.exports = { renderRig, compose, parts, checkForm, fit, FORM, SEAMLESS, decodePng };
if (require.main === module) main();

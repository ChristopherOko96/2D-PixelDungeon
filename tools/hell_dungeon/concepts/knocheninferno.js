// Ignaroth concept "Knochen-Inferno" (preview only, not wired into the game).
// A horror dragon: partly skeletal, ribs open over a burning core (form 4: a void core), bone
// plates along the spine, a skull-like head with deep glowing sockets and long fangs, torn and
// burned wing membranes with holes (forms 3 and 4), lava drool and drips. The same creature in all
// four forms: form 1 shows hints of bone (skull mask, spine nubs, glowing rib cracks), form 4 the
// full horror in obsidian, gold and void fire.
//
// Drawn with hell_monsters.js's Painter (0x72 palette, 1 px #222222 outline from finish()), but
// with volume shading: every body mass is an ellipsoid, tapered capsule or bevelled plate whose
// pseudo normal picks one of five tones (key light top left), plus a rim light from the lava floor
// below (form 4: violet void light) and glossy glints on obsidian. Far limbs and the far wing use
// a darker, cooler ramp; the far side also sits a little higher (3/4 depth cue).
//
// Rig compatibility: every draw call is tagged with the rig part ids of export_rigs.js (body, neck,
// head, jaw, arm, leg_far, leg_near, tail_1..tail_5, tail_flame; forms 3/4 wing_far, wing_near,
// throat, horns; form 4 crystal_1..3, mouth_flame) and every pivot and point is recorded with
// P.joint (the same names drake() records: core, head, throat_at, mouth, hand, tail_tip). Parts
// are drawn from their own shapes only, so renderRig(p, part) renders one part isolated.
//
// Usage: node tools/hell_dungeon/concepts/knocheninferno.js [out_dir]
//   writes <out_dir>/knocheninferno_lineup.png, _form4.png, _ingame.png and _rig1..4.png
//   (default out_dir: production/qa/evidence/drake-concepts). Writes nothing else.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const HM = require('../hell_monsters.js');
const ER = require('../export_rigs.js');
const { Painter } = HM;

// ---------- palette (0x72 DungeonTileset II, the constants of hell_monsters.js) ----------
const K = '#222222', BLK = '#0e0c0c', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a';
const RED = '#da4e38', CRIM = '#9f294e', MAROON = '#62232f', PLUM = '#38262d', PURP = '#5f2d56', MAG = '#993970';
const PINK = '#dc4a7b', LILAC = '#f0b3dd', VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579';
const YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025', BROWN = '#8f4029';
const MUD = '#775c55', STONE = '#483b3a', COAL = '#3b3332', SOOT = '#302c2b', NEARBLK = '#2b2929';
// derived shades: one step darker than a palette colour, for the fifth (deepest) tone
const DBROWN = '#5a281c', DWINE = '#24151b', DVOID = '#1d1631', OBSFAR = '#28233a';
const FIRE = [WHITE, YEL, ORA, RED, CRIM];
const VOIDFIRE = [LILAC, VIO, VIOD, PURP, INDIGO];

// materials: r = five tones dark -> light, rim = lava/void rim light [soft, hot], spec = glint
const BONE5 = { r: [STONE, MUD, TAN, BONE, WHITE], rim: [ORA, YEL] };
const BONE5F = { r: [SOOT, STONE, MUD, TAN, BONE], rim: [BORA, ORA] };
const GOLD5 = { r: [BROWN, BORA, ORA, YEL, WHITE], spec: WHITE };
const GOLD5F = { r: [DBROWN, BROWN, BORA, ORA, YEL] };
// obsidian: mostly near black, hard top-left highlights, violet void light from below, rare glints
const OBS5 = { r: [BLK, NEARBLK, COAL, STONE, MUD], rim: [VIOD, VIO], bias: -.2 };
const OBS5W = { r: [DVOID, INDIGO, VIOD, VIOD, VIO] };
const OBS5F = { r: [BLK, DVOID, OBSFAR, NEARBLK, COAL], rim: [INDIGO, VIOD], bias: -.1 };

// Per form: scale s (source px per unit), body proportions, and materials. The unit skeleton is
// form 4's (about 100 units tall with the wings); the other forms scale and reshape it.
const STYLE = {
  1: {
    name: 'SALAMANDER', s: .64, leg: .6, torso: .92, rise: .45, neckLen: 14, neckAng: -.5, head: 1.3, headAng: .08, tail: 1.2, arm: .85,
    wing: 0, horn: 0, bone: 1, open: .5, cav: 0, ribs: 0, fireSize: 9,
    hide: { r: [DBROWN, BROWN, BORA, ORA, YEL], rim: [YEL, WHITE], bias: -.14 }, far: { r: [PLUM, MAROON, BROWN, BROWN, BORA], rim: [BORA, ORA] },
    belly: { r: [BORA, ORA, YEL, YEL, WHITE], rim: [YEL, WHITE] }, bone5: BONE5, bone5f: BONE5F, claw: BONE5, spikeMat: BONE5,
    fire: FIRE, core: [WHITE, YEL, ORA, RED, CRIM, MAROON], crack: [RED, ORA, YEL], eye: [ORA, YEL, WHITE], mouth: [MAROON, RED, ORA],
  },
  2: {
    name: 'JUNGDRACHE', s: .64, leg: .8, torso: 1, rise: .75, neckLen: 19, neckAng: -.72, head: 1.2, headAng: .16, tail: 1.1, arm: .92,
    wing: 0, horn: 1, bone: 2, open: .8, cav: .62, ribs: 2, fireSize: 9,
    hide: { r: [PLUM, MAROON, CRIM, RED, ORA], rim: [ORA, YEL] }, far: { r: [DWINE, PLUM, MAROON, CRIM, CRIM], rim: [BORA, ORA] },
    belly: { r: [BROWN, BORA, ORA, YEL, YEL], rim: [YEL, WHITE] }, bone5: BONE5, bone5f: BONE5F, claw: BONE5, spikeMat: BONE5,
    fire: FIRE, core: [WHITE, YEL, ORA, RED, CRIM, MAROON], crack: [ORA, YEL, YEL], eye: [ORA, YEL, WHITE], mouth: [MAROON, RED, ORA],
  },
  3: {
    name: 'GLUTDRACHE', s: .68, leg: .95, torso: 1.04, rise: 1, neckLen: 24, neckAng: -.74, head: 1.12, headAng: .28, tail: 1, arm: 1,
    wing: 1, horn: 2, bone: 3, open: 1.6, cav: 1, ribs: 3, fireSize: 11, ribMat: { r: [STONE, MUD, TAN, BONE, WHITE] },
    hide: { r: [DWINE, PLUM, MAROON, CRIM, RED], rim: [ORA, YEL] }, far: { r: [BLK, DWINE, PLUM, MAROON, MAROON], rim: [CRIM, RED] },
    belly: { r: [BROWN, BORA, ORA, YEL, YEL], rim: [YEL, WHITE] }, bone5: BONE5, bone5f: BONE5F, claw: BONE5, spikeMat: BONE5,
    mem: { r: [DWINE, PLUM, MAROON, CRIM, RED] }, memFar: { r: [DWINE, DWINE, PLUM, MAROON, MAROON] }, burn: [RED, ORA, YEL], wingBone: BONE5, wingBoneF: BONE5F,
    throat: { r: [MAROON, CRIM, BORA, ORA, YEL] }, fire: FIRE, core: [WHITE, YEL, ORA, RED, CRIM, MAROON], crack: [ORA, YEL, YEL],
    eye: [ORA, YEL, WHITE], mouth: [MAROON, RED, ORA],
  },
  4: {
    name: 'OBSIDIANFORM', s: .86, leg: .95, torso: 1.1, rise: 1, neckLen: 26, neckAng: -.72, head: 1.16, headAng: .3, tail: 1, arm: 1.08,
    wing: 1.1, horn: 3, bone: 4, open: 1.8, cav: 1.08, ribs: 3, fireSize: 14, ribMat: { r: [BLK, NEARBLK, COAL, STONE, BORA] },
    hide: OBS5, far: OBS5F, belly: { r: [DVOID, INDIGO, PURP, MAG, VIO], rim: [VIO, LILAC] }, bone5: OBS5, bone5f: OBS5F,
    claw: GOLD5, spikeMat: GOLD5, mem: { r: [DVOID, INDIGO, PURP, MAG, VIO] }, memFar: { r: [DVOID, DVOID, INDIGO, PURP, PURP] },
    burn: [MAG, VIO, LILAC], wingBone: OBS5, wingBoneF: OBS5W, throat: { r: [INDIGO, PURP, MAG, PINK, LILAC] },
    fire: VOIDFIRE, core: [WHITE, LILAC, VIO, VIOD, PURP, INDIGO], crack: [VIOD, VIO, LILAC], eye: [VIO, LILAC, WHITE], mouth: [DVOID, PURP, VIO],
  },
};
// The rest pose of the rig: no bob, no stride, wings at rest, the jaw at its rest gap.
const REST = { bob: 0, stride: 0, wingLift: 0, mouth: 0, headX: 0, headY: 0, tail: 0, crouch: 0 };
// The rig part of each of the ten tail steps (as in hell_monsters.js): root 2, tail_2 4, then 1, 1, 2.
const TAIL_PART = [0, 1, 1, 2, 2, 2, 2, 3, 4, 5, 5];

// ---------- volume shading on top of the Painter ----------
const norm3 = (x, y, z) => { const l = Math.hypot(x, y, z) || 1; return [x / l, y / l, z / l]; };
const dot3 = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const KEY = norm3(-.62, -.74, .62), RIMD = norm3(.28, .92, -.12), HALF = norm3(KEY[0], KEY[1], KEY[2] + 1);
const hash = (x, y, k) => ((((x * 73856093) ^ (y * 19349663) ^ ((k || 0) * 83492791)) >>> 0) % 1000) / 1000;
const lerp = (a, b, t) => a + (b - a) * t;
const lerp2 = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t)];

function owner(P) { if (!P._own) P._own = new Array(P.w * P.h).fill(null); return P._own; }
function put(P, x, y, c) {
  if (!P.keep() || !P.inside(x, y) || !c) return;
  P.solid[y * P.w + x] = c; owner(P)[y * P.w + x] = P.tag;
}
function shade(n, mat, o) {
  const d = dot3(n, KEY) + (o.bias || 0) + (mat.bias || 0);
  let i = d < -.2 ? 0 : d < .18 ? 1 : d < .5 ? 2 : d < .79 ? 3 : 4;
  if (o.far) i = Math.max(0, i - 1);
  if (o.top != null) i = Math.min(i, o.top);
  let c = mat.r[i];
  if (mat.rim && !o.noRim) { const r = dot3(n, RIMD); if (r > (o.rimAt || .6)) c = r > .84 ? mat.rim[1] : mat.rim[0]; }
  if (mat.spec && !o.noSpec && dot3(n, HALF) > .993) c = mat.spec;
  return c;
}
// Fills every pixel whose centre passes test(x, y) -> normal | null. mat: a material or a colour.
// o.contour: colour for the edge where the shape lies over earlier pixels of the same part (an
// inner outline that separates overlapping masses); o.cfn(x, y, n, c): per-pixel colour override.
function fill(P, x0, y0, x1, y1, test, mat, o) {
  o = o || {};
  if (!P.keep()) return;
  x0 = Math.max(0, Math.floor(x0) - 1); y0 = Math.max(0, Math.floor(y0) - 1);
  x1 = Math.min(P.w - 1, Math.ceil(x1) + 1); y1 = Math.min(P.h - 1, Math.ceil(y1) + 1);
  const pts = [], inS = new Set(), O = owner(P);
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) { const n = test(x + .5, y + .5); if (n) { pts.push([x, y, n]); inS.add(y * P.w + x); } }
  for (const [x, y, n] of pts) {
    let c = !mat ? null : typeof mat === 'string' ? mat : shade(n, mat, o);
    if (o.contour) {
      const edge = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
        const xx = x + dx, yy = y + dy; if (!P.inside(xx, yy)) return false;
        const j = yy * P.w + xx; return !inS.has(j) && P.solid[j] && O[j] === P.tag;
      });
      if (edge) c = o.contour;
    }
    if (o.cfn) c = o.cfn(x, y, n, c) || c;
    put(P, x, y, c);
  }
}
// An ellipsoid turned by ang.
function blob(P, cx, cy, rx, ry, ang, mat, o) {
  const c = Math.cos(ang || 0), s = Math.sin(ang || 0), r = Math.max(rx, ry);
  fill(P, cx - r, cy - r, cx + r, cy + r, (x, y) => {
    const dx = x - cx, dy = y - cy, u = (dx * c + dy * s) / rx, v = (-dx * s + dy * c) / ry, q = u * u + v * v;
    return q > 1 ? null : norm3(u * c - v * s, u * s + v * c, Math.sqrt(1 - q) * ((o && o.flat) || 1));
  }, mat, o);
}
// A tapered capsule from a (radius ra) to b (radius rb), shaded as a cylinder.
function limb(P, a, ra, b, rb, mat, o) {
  const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy || 1, R = Math.max(ra, rb);
  fill(P, Math.min(a[0], b[0]) - R, Math.min(a[1], b[1]) - R, Math.max(a[0], b[0]) + R, Math.max(a[1], b[1]) + R, (x, y) => {
    const t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / l2)), qx = a[0] + dx * t, qy = a[1] + dy * t, r = ra + (rb - ra) * t;
    const ex = x - qx, ey = y - qy, d = Math.hypot(ex, ey);
    return d > r ? null : norm3(ex / r, ey / r, Math.sqrt(Math.max(0, 1 - (d / r) ** 2)));
  }, mat, o);
}
// A chain of capsules through pts, the radius going from r0 to r1.
function chain(P, pts, r0, r1, mat, o) {
  const n = pts.length - 1;
  for (let i = 0; i < n; i++) limb(P, pts[i], lerp(r0, r1, i / n), pts[i + 1], lerp(r0, r1, (i + 1) / n), mat, o);
}
function inPoly(pts, x, y) {
  let c = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
// Distance from (x, y) to the polygon outline and the outward normal of the nearest edge.
function edgeOf(pts, x, y) {
  let best = Infinity, nx = 0, ny = 0;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [ax, ay] = pts[j], [bx, by] = pts[i], dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1;
    const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / l2)), qx = ax + dx * t, qy = ay + dy * t, d = Math.hypot(x - qx, y - qy);
    if (d < best) { best = d; nx = x - qx; ny = y - qy; }
  }
  const l = Math.hypot(nx, ny) || 1;
  return { d: best, nx: -nx / l, ny: -ny / l };
}
// A plate with bevelled edges: flat in the middle, rounding off over bw px at its outline.
function plate(P, pts, bw, mat, o) {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  fill(P, Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys), (x, y) => {
    if (!inPoly(pts, x, y)) return null;
    const e = edgeOf(pts, x, y), k = Math.max(0, 1 - e.d / bw);
    return norm3(e.nx * k * 1.3 + ((o && o.tilt) || [0, 0])[0], e.ny * k * 1.3 + ((o && o.tilt) || [0, 0])[1], 1 - k * .5);
  }, mat, o);
}
// A cone-like spike from a base (two points) to a tip, lit on the side facing the key light.
function spike(P, b0, b1, tip, mat, o) {
  const mx = (b0[0] + b1[0]) / 2, my = (b0[1] + b1[1]) / 2, ax = tip[0] - mx, ay = tip[1] - my, al = Math.hypot(ax, ay) || 1;
  const px = -ay / al, py = ax / al, hw = Math.max(.5, Math.hypot(b1[0] - b0[0], b1[1] - b0[1]) / 2), pts = [b0, b1, tip];
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  fill(P, Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys), (x, y) => {
    if (!inPoly(pts, x, y)) return null;
    const rx = x - mx, ry = y - my, along = Math.max(0, Math.min(1, (rx * ax + ry * ay) / (al * al))), w = Math.max(.35, hw * (1 - along));
    const u = Math.max(-1, Math.min(1, (rx * px + ry * py) / w));
    return norm3(u * px - ax / al * .35, u * py - ay / al * .35, Math.sqrt(1 - u * u * .8));
  }, mat, o);
}
// A curved horn or claw: a chain that tapers to a point. Draws at least one pixel at the tip.
function horn(P, pts, r0, mat, o) { chain(P, pts, r0, .45, mat, o); }
// A hairline crack of glowing colours, walking from a with a deterministic wobble. It only paints
// over pixels the current part already has, so it never leaves the silhouette.
function crack(P, a, ang, len, cols, seed) {
  let x = a[0], y = a[1];
  const on = (px, py, c) => { px = Math.round(px); py = Math.round(py); if (P.inside(px, py) && P.solid[py * P.w + px] && owner(P)[py * P.w + px] === P.tag) put(P, px, py, c); };
  for (let i = 0; i < len; i++) {
    ang += (hash(i, seed, 7) - .5) * 1.1;
    x += Math.cos(ang); y += Math.sin(ang);
    on(x, y, cols[i < len * .3 || i > len * .8 ? 0 : hash(i, seed, 3) < .5 ? 1 : 2]);
    if (hash(i, seed, 9) < .18) on(x + Math.cos(ang + 1.4) * 1.2, y + Math.sin(ang + 1.4) * 1.2, cols[0]);
  }
}
// Drips hanging from (x, y): glowing pixels downwards plus one falling droplet.
function drip(P, x, y, len, cols) {
  x = Math.round(x); y = Math.round(y);
  for (let j = 0; j < len; j++) P.glow(x, y + j, cols[Math.min(cols.length - 1, j === 0 ? 2 : j < len - 1 ? 1 : 0)]);
  P.glow(x, y + len + 1, cols[0]);
}

// ---------- the wing: raised, torn and burned, finger bones exposed ----------
function wing(P, st, s, root, elbow, wrist, tips, attach, far, seed) {
  const mem = far ? st.memFar : st.mem, arm = far ? st.far : st.hide, bone = far ? st.wingBoneF : st.wingBone;
  // the torn trailing edge: notches between the finger tips, ragged teeth on every edge
  const poly = [root, elbow, wrist, tips[0]];
  const holes = [];
  for (let i = 0; i < tips.length; i++) {
    const a = tips[i], b = i + 1 < tips.length ? tips[i + 1] : attach, deep = i + 1 < tips.length ? .3 : .12;
    const mid = lerp2(lerp2(a, b, .5), wrist, deep);
    for (const [t, from, to] of [[.35, a, mid], [.7, a, mid], [.35, mid, b], [.7, mid, b]]) {
      const pt = lerp2(from, to, t), j = (hash(i, Math.round(t * 10), seed) - .5) * 2.4 * s;
      poly.push([pt[0] + j, pt[1] + j * .6]);
      if (t === .7 && to === mid) poly.push(mid);
    }
    poly.push(b);
    // one or two burned holes per panel
    if (i + 1 < tips.length) {
      const c = lerp2(wrist, lerp2(a, b, .5), .5 + hash(i, 1, seed) * .15), w = Math.hypot(a[0] - b[0], a[1] - b[1]);
      holes.push([c[0], c[1], Math.max(1.2, w * (.1 + hash(i, 2, seed) * .06))]);
      if (i === 1 || i === 2) { const c2 = lerp2(wrist, lerp2(a, b, .5), .78); holes.push([c2[0], c2[1], Math.max(.9, w * .07)]); }
    }
  }
  poly.push(root);
  // shading references: the bones plus one fold from the elbow to the trailing edge, which splits
  // the wide inner panel
  const bones = [[root, elbow], [elbow, wrist]].concat(tips.map(t => [wrist, t]), [[elbow, lerp2(attach, tips[tips.length - 1], .45)]]);
  const dseg = (x, y, a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy || 1, t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / l2)); return Math.hypot(x - a[0] - dx * t, y - a[1] - dy * t); };
  const inHole = (x, y, grow) => holes.some(([hx, hy, r]) => Math.hypot((x - hx) * 1.1, y - hy) <= r + grow + (hash(Math.round(x), Math.round(y), seed) - .5) * .9);
  const xs = poly.map(p => p[0]), ys = poly.map(p => p[1]);
  fill(P, Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys), (x, y) => (inPoly(poly, x, y) && !inHole(x, y, 0) ? [0, 0, 1] : null), mem, {
    cfn: (px, py) => {
      const x = px + .5, y = py + .5, ds = bones.map(([a, b]) => dseg(x, y, a, b)).sort((a, b) => a - b), de = edgeOf(poly, x, y).d;
      if (inHole(x, y, 1.1)) return hash(px, py, seed + 1) < .55 ? st.burn[0] : st.burn[1];
      if (de < 1.2) return hash(px, py, seed + 2) < .22 ? st.burn[0] : mem.r[0];
      // each panel sags between two bones: taut and lit beside a bone, deep in its middle,
      // the lower panels glow through from the lava below
      const t = ds[0] / (ds[0] + ds[1] + .001), lower = (y - Math.min(...ys)) / (Math.max(...ys) - Math.min(...ys));
      let i = ds[0] < 1.1 ? 3 : t < .2 ? 3 : t < .36 ? 2 : 1;
      if (far) i = Math.max(1, i - 1);
      if (!far && lower > .7 && i === 1) i = 2;
      if (!far && lower > .82 && t > .3 && hash(px, py, seed + 3) < .35) i = 4;
      return mem.r[i];
    },
  });
  // arm bones over the membrane, finger bones exposed
  limb(P, root, 3.4 * s, elbow, 2.5 * s, arm, { far });
  limb(P, elbow, 2.6 * s, wrist, 1.9 * s, arm, { far });
  tips.forEach((t, i) => { const m = lerp2(wrist, t, .5), bend = (i - 1) * .9 * s; horn(P, [wrist, [m[0] + bend, m[1] - bend], t], 1.25 * s, bone, { far }); });
  // the wrist talon and the knuckle spikes
  spike(P, [wrist[0] - 1.6 * s, wrist[1] + .5], [wrist[0] + 1.6 * s, wrist[1] + .5], [wrist[0] + 3 * s, wrist[1] - 6 * s], far ? (st.claw === GOLD5 ? GOLD5F : BONE5F) : st.claw, {});
  spike(P, [elbow[0] - 1.4 * s, elbow[1]], [elbow[0] + 1.4 * s, elbow[1]], [elbow[0] - 2.5 * s, elbow[1] - 4.5 * s], far ? BONE5F : st.bone5, { far });
  if (st.horn === 3) for (const t of [.35, .7]) { const b = lerp2(elbow, wrist, t); spike(P, [b[0] - 1.2 * s, b[1]], [b[0] + 1.2 * s, b[1] + .5], [b[0] + 2.5 * s, b[1] - 4 * s], far ? GOLD5F : GOLD5, {}); }
}

// ---------- the dragon ----------
// P: a Painter of the form's frame (layout(p)); p: form 1-4; q: pose (REST for the rig); L: layout.
function drawKnochen(P, p, q, L) {
  q = Object.assign({}, REST, q || {});
  const st = STYLE[p], s = st.s, tr = st.torso, rs = st.rise, lg = st.leg;
  const X = (x, y) => [L.ox + x * s, L.gy + y * s];
  const hide = st.hide, farM = st.far;
  // skeleton in units (ground y = 0, hip above x = 0, facing right)
  const legH = 38 * lg, hipY = -legH + q.bob + q.crouch;
  const pelvis = [-3 * tr, hipY - 3 * tr], pelvisR = [12.5 * tr, 11 * tr];
  // a hunched predator: the barrel chest low and forward, a heavy shoulder hump, the neck arching
  // forward so the skull looms over the hero
  const chest = [21 * tr, hipY - 11 * tr * rs - 2], chestR = [20 * tr, 15.5 * tr], chestAng = -.3 * rs;
  const hump = [chest[0] - 1 * tr, chest[1] - 11 * tr * (.4 + rs * .6)], humpR = [13.5 * tr, 10 * tr];
  const nb = [chest[0] + 14 * tr, chest[1] - 8 * tr * (.3 + rs * .7)];
  const nd = [Math.cos(st.neckAng), Math.sin(st.neckAng)], npv = [-nd[1], nd[0]];
  const ne = [nb[0] + nd[0] * st.neckLen + q.headX, nb[1] + nd[1] * st.neckLen + q.headY];
  const nm = [lerp(nb[0], ne[0], .5) - npv[0] * 4, lerp(nb[1], ne[1], .5) - npv[1] * 4];
  const neckR = [9.5 * tr, 6.8 * tr * Math.min(1.1, st.head)];
  // ---------- far wing (behind everything): raised higher than the near one, a V of wings ----------
  const W = st.wing, lift = q.wingLift;
  const wroot = [hump[0] - 8 * tr, hump[1] - 2 * tr];
  if (W) {
    const r = [hump[0] - 2 * tr, hump[1] - 6 * tr];
    const el = [r[0] + 3 * W, r[1] - 21 * W + lift * 6], wr = [el[0] - 6 * W, el[1] - 15 * W + lift * 8];
    const tips = [[wr[0] - 15 * W, wr[1] - 7 * W], [wr[0] - 28 * W, wr[1]], [wr[0] - 35 * W, wr[1] + 13 * W], [wr[0] - 31 * W, wr[1] + 26 * W]];
    P.part('wing_far').joint('wing_far', ...X(...r));
    wing(P, st, s, X(...r), X(...el), X(...wr), tips.map(t => X(...t)), X(r[0] - 14 * W, r[1] + 5 * W), true, 11);
  }
  // ---------- tail: ten steps in five rig parts, skeletal towards the tip from form 3 ----------
  const tl = 62 * st.tail * tr, troot = [pelvis[0] - 7 * tr, pelvis[1] + 2 * tr];
  const tr0 = 8 * tr, tR = u => Math.max(.7, tr0 * (1 - .82 * u));
  const tailPt = u => {
    const e = 1 - (1 - Math.min(1, u / .78)) ** 2, curl = Math.max(0, (u - .8) / .2);
    return [troot[0] - tl * u + curl * curl * 4 * tr, lerp(troot[1], -(tR(u) + .6), e) - 13 * tr * curl ** 1.5 + Math.sin(u * 2.4) * q.tail * u * 2];
  };
  let prev = tailPt(0);
  for (let k = 1; k <= 10; k++) {
    if (TAIL_PART[k] !== TAIL_PART[k - 1]) { const id = 'tail_' + TAIL_PART[k]; P.part(id).joint(id, ...X(...prev)); }
    const u0 = (k - 1) / 10, u1 = k / 10, pt = tailPt(u1), skel = st.bone >= 3 && k >= 8;
    if (skel) {
      // the burned-off tip: vertebrae on a thin sinew
      limb(P, X(...prev), tR(u0) * .45 * s, X(...pt), tR(u1) * .45 * s, farM, {});
      for (const t of [.25, .75]) { const v = lerp2(prev, pt, t); blob(P, ...X(...v), Math.max(1.1, tR(lerp(u0, u1, t)) * .75 * s), Math.max(1, tR(lerp(u0, u1, t)) * .65 * s), 0, st.bone5, {}); }
    } else {
      limb(P, X(...prev), tR(u0) * s, X(...pt), tR(u1) * s, hide, {});
      if (st.bone >= 3 && (k === 3 || k === 5)) crack(P, X(prev[0], prev[1] + tR(u0) * .2), Math.atan2(pt[1] - prev[1], pt[0] - prev[0]), Math.round(10 * s), st.crack, 60 + k);
    }
    // dorsal spikes on top of every other step
    if (st.bone >= 2 && k % 2 === 1 && k < 10) {
      const m = lerp2(prev, pt, .5), dx = pt[0] - prev[0], dy = pt[1] - prev[1], l = Math.hypot(dx, dy) || 1, ux = dx / l, uy = dy / l, nx = uy, ny = -ux;
      const up = ny < 0 ? 1 : -1, r = tR(lerp(u0, u1, .5)), h = (st.bone >= 3 ? 5 : 3.5) * tr * (1 - u1 * .55);
      const b = [m[0] + nx * up * r * .7, m[1] + ny * up * r * .7];
      spike(P, X(b[0] - ux * r * .5, b[1] - uy * r * .5), X(b[0] + ux * r * .5, b[1] + uy * r * .5), X(b[0] + nx * up * h - ux * h * .6, b[1] + ny * up * h - uy * h * .6), st.spikeMat, {});
    } else if (st.bone === 1 && k % 2 === 1 && k < 9) { const m = lerp2(prev, pt, .5); spike(P, X(m[0] - 1, m[1] - tR(u1) * .8), X(m[0] + 1, m[1] - tR(u1) * .8), X(m[0] - 1.5, m[1] - tR(u1) - 2.2), st.spikeMat, {}); }
    prev = pt;
  }
  P.joint('tail_tip', ...X(...prev));
  P.part('tail_flame').joint('tail_flame', ...X(...prev));
  const tf = st.fireSize, tip = X(...prev);
  P.flame(tip[0] - Math.round(tf * .3), tip[1] + 1, Math.max(4, Math.round(tf * .6)), tf, { seed: 3, pal: st.fire, front: true });
  // ---------- legs: digitigrade, massive thighs; the far one darker, cooler and set back ----------
  const clawM = st.claw;
  const leg = (dx, dy, mat, far, stp) => {
    const sh = [dx, dy], fwd = stp * 3, up = Math.max(0, stp) * 2;
    const hip = [sh[0], hipY + sh[1]], th = [hip[0] + 3 * tr, hip[1] + 4 * lg], knee = [hip[0] + 11 * lg + fwd * .5, -legH * .5 + sh[1] - up];
    const hock = [hip[0] + 1 * lg + fwd, -legH * .2 + sh[1] - up * .8], ball = [hip[0] + 9 * lg + fwd, -1.7 + sh[1] - up * .6];
    P.joint(P.tag, ...X(...hip));
    const o = { far };
    limb(P, X(...knee), 4.4 * tr * s, X(...hock), 3 * tr * s, mat, o);
    limb(P, X(...hock), 3.1 * tr * s, X(...ball), 2.4 * tr * s, mat, o);
    blob(P, ...X(...th), 8.6 * tr * s, 14 * lg * s, .55, mat, o);
    // veins of lava (form 3) or void fire (form 4) through the thigh and shin
    if (st.bone >= 3 && !far) { crack(P, X(th[0] - 2, th[1] - 6 * lg), 1.4, Math.round(16 * s), st.crack, 51); crack(P, X(knee[0] - 1, knee[1] + 1), 2.2, Math.round(9 * s), st.crack, 52); }
    if (st.bone >= 3) spike(P, X(knee[0] - 1.5, knee[1] - 1.5), X(knee[0] + 1.5, knee[1] + 1), X(knee[0] + 4 * tr, knee[1] - 3.5 * tr), far ? BONE5F : (p === 4 ? GOLD5 : BONE5), {});
    // heel spur and the toes with long claws
    if (st.bone >= 2) spike(P, X(hock[0] - 1, hock[1] - 2), X(hock[0] + 1.5, hock[1] + 1.5), X(hock[0] - 5 * tr, hock[1] + 1), far ? BONE5F : st.bone5, o);
    for (let t = 0; t < 3; t++) {
      const tb = [ball[0] + t * 1.2 - 1, ball[1] + .4], tt = [tb[0] + 5 * tr + t * .8, -1.6 + sh[1] - up * .5];
      limb(P, X(...tb), 1.9 * tr * s, X(...tt), 1.5 * tr * s, mat, o);
      horn(P, [X(...tt), X(tt[0] + 2.6 * tr, tt[1] + .2), X(tt[0] + 4 * tr, tt[1] + 1.6 + sh[1] * -0)], 1.2 * s, far ? (clawM === GOLD5 ? GOLD5F : BONE5F) : clawM, {});
    }
  };
  P.part('leg_far');
  leg(6 * tr, -3 * lg, farM, true, -q.stride);
  // ---------- body: pelvis, barrel chest, shoulder hump, the open ribcage over the core ----------
  P.part('body').joint('body', ...X(0, hipY));
  const cav = [chest[0] - .5 * tr, chest[1] + 1.5 * tr], cavR = [10 * tr * st.cav, 9 * tr * st.cav];
  P.joint('core', ...X(cav[0] + (st.cav ? 0 : 3 * tr), cav[1]));
  blob(P, ...X(...pelvis), pelvisR[0] * s, pelvisR[1] * s, -.2, hide, {});
  blob(P, ...X(...chest), chestR[0] * s, chestR[1] * s, chestAng, hide, {});
  blob(P, ...X(...hump), humpR[0] * s, humpR[1] * s, -.3, hide, { contour: hide.r[0] });
  // belly plates along the front and underside of the chest
  const bel = [chest[0] + 8 * tr, chest[1] + 8.5 * tr];
  blob(P, ...X(...bel), 8 * tr * s, 5.2 * tr * s, -.5 * rs, st.belly, { cfn: (x, y, n, c) => ((Math.round((x - y * .55) / Math.max(2, 2.6 * s)) % 2 === 0 && n[2] < .93) ? st.belly.r[0] : c) });
  // the spine: bone plates from the hump down to the pelvis
  const sp0 = [hump[0] + 4 * tr, hump[1] - humpR[1] + 1], sp1 = [pelvis[0] - 6 * tr, pelvis[1] - pelvisR[1] + 2], spc = [chest[0] - 9 * tr, hump[1] - humpR[1] - 1];
  const nSp = st.bone >= 3 ? 6 : st.bone === 2 ? 5 : 4;
  for (let i = 0; i < nSp; i++) {
    const t = i / (nSp - 1), b = [lerp(lerp(sp0[0], spc[0], t), lerp(spc[0], sp1[0], t), t), lerp(lerp(sp0[1], spc[1], t), lerp(spc[1], sp1[1], t), t)];
    const h = (st.bone >= 3 ? 9 : st.bone === 2 ? 6.5 : 3.6) * tr * (1 - t * .45), w = (st.bone >= 3 ? 2.6 : 1.8) * tr;
    spike(P, X(b[0] - w, b[1] + 1.5), X(b[0] + w, b[1] + 1.5), X(b[0] - h * .55, b[1] - h), st.spikeMat, {});
  }
  if (st.ribs) {
    // torn hide around the cavity, the core glowing inside, ribs arching over it
    const C = X(...cav), rx = cavR[0] * s, ry = cavR[1] * s, ca = Math.cos(chestAng), sa = Math.sin(chestAng);
    const ell = (x, y, grow) => { const dx = x - C[0], dy = y - C[1], u = (dx * ca + dy * sa) / (rx + grow), v = (-dx * sa + dy * ca) / (ry + grow); return u * u + v * v; };
    fill(P, C[0] - rx - 3, C[1] - ry - 3, C[0] + rx + 3, C[1] + ry + 3, (x, y) => (ell(x, y, 1.6 + (hash(Math.floor(x), Math.floor(y), 5) - .5) * 1.4) <= 1 ? [0, 0, 1] : null), null, {
      cfn: (px, py) => {
        const x = px + .5, y = py + .5, q2 = ell(x, y, 0);
        if (q2 > 1) return hash(px, py, 6) < .3 ? st.crack[0] : hide.r[0];
        const d = Math.sqrt(ell(x, y + ry * .2, 0)), co = st.core;
        return d < .3 ? co[0] : d < .5 ? co[1] : d < .68 ? co[2] : d < .84 ? co[3] : d < .96 ? co[4] : co[5];
      },
    });
    // ribs: backlit against the core, a dark seam on their shadow side
    const n = st.ribs, ribM = st.ribMat || st.bone5;
    for (let i = 0; i < n; i++) {
      const t = n > 1 ? i / (n - 1) : .5, x0 = cav[0] - cavR[0] * .72 + t * cavR[0] * 1.25;
      // each rib bows forward like a sickle: down from the spine, out, then back to the sternum
      const top = [x0 - 2.2 * tr, cav[1] - cavR[1] * 1.2], m1 = [x0 + 1.6 * tr, cav[1] - cavR[1] * .45], m2 = [x0 + 2.8 * tr, cav[1] + cavR[1] * .35], bot = [x0 + .6 * tr + t * 1.2 * tr, cav[1] + cavR[1] * 1.12];
      // (dark obsidian ribs need no seam against the void glow: it would eat them)
      chain(P, [X(...top), X(...m1), X(...m2), X(...bot)], 1.8 * tr * s, 1.15 * tr * s, ribM, { contour: p === 4 ? null : BLK, noSpec: true });
    }
    // molten drips from the bottom of the cavity
    for (const [dx, len] of [[-.3, 3], [.25, 5], [.6, 2]]) drip(P, C[0] + dx * rx, C[1] + ry * .95, Math.round(len * s + 1), [st.core[3], st.core[2], st.core[1]]);
  } else {
    // form 1: no open ribcage yet: three rib ends break through the flank over a glowing crack
    for (let i = 0; i < 3; i++) {
      const x0 = chest[0] - 5 * tr + i * 4.6 * tr, top = [x0, chest[1] - 6 * tr], bot = [x0 + 2.5 * tr, chest[1] + 3 * tr];
      crack(P, X(top[0] + .8, top[1] + 1), 1.2, Math.round(9 * s * tr + 2), st.crack, 20 + i);
      chain(P, [X(...top), X(x0 + 1.8 * tr, chest[1] - 1.5 * tr), X(...bot)], 1.25 * tr * s, .9 * tr * s, BONE5, { contour: DBROWN, noRim: true });
    }
  }
  // scars and glowing cracks over the hide
  if (st.bone >= 2) for (const [x, y, a, l, sd] of [[-8, -4, .7, 7, 31], [6, -10, 1.1, 6, 32], [-2, 6, .2, 6, 33]]) crack(P, X(chest[0] + x * tr, chest[1] + y * tr), a, Math.round(l * s), st.crack, sd);
  if (p === 4) for (const [x, y, a, l, sd] of [[-6, -2, 2.2, 8, 41], [0, -4, -.4, 6, 42]]) crack(P, X(pelvis[0] + x, pelvis[1] + y), a, Math.round(l * s), st.crack, sd);
  // ---------- near leg ----------
  P.part('leg_near');
  leg(0, 0, hide, false, q.stride);
  // ---------- near wing (in front of the body, behind neck and arm) ----------
  if (W) {
    const r = wroot, el = [r[0] - 13 * W, r[1] - 13 * W + lift * 6], wr = [el[0] - 12 * W, el[1] - 14 * W + lift * 9];
    const tips = [[wr[0] - 22 * W, wr[1] - 3 * W], [wr[0] - 37 * W, wr[1] + 9 * W], [wr[0] - 41 * W, wr[1] + 26 * W], [wr[0] - 31 * W, wr[1] + 40 * W]];
    P.part('wing_near').joint('wing_near', ...X(...r));
    wing(P, st, s, X(...r), X(...el), X(...wr), tips.map(t => X(...t)), X(r[0] - 17 * W, r[1] + 10 * W), false, 5);
  }
  // ---------- neck: plated, spined, the throat gland on its front ----------
  P.part('neck').joint('neck', ...X(...nb)).joint('head', ...X(...ne));
  const gl = [lerp(nb[0], ne[0], .42) + npv[0] * neckR[0] * .55, lerp(nb[1], ne[1], .42) + npv[1] * neckR[0] * .55];
  P.joint('throat_at', ...X(...gl));
  chain(P, [X(...nb), X(...nm), X(...ne)], neckR[0] * s, neckR[1] * s, hide, {});
  if (st.bone >= 3) crack(P, X(nb[0] - npv[0] * 3, nb[1] - npv[1] * 3), st.neckAng, Math.round(st.neckLen * .8 * s), st.crack, 71);
  // ventral plates down the front of the neck
  for (let i = 0; i < 4; i++) {
    const t = .15 + i * .2, c = [lerp(nb[0], ne[0], t) + npv[0] * lerp(neckR[0], neckR[1], t) * .55, lerp(nb[1], ne[1], t) + npv[1] * lerp(neckR[0], neckR[1], t) * .55];
    blob(P, ...X(...c), 2.6 * tr * s, 2 * tr * s, Math.atan2(nd[1], nd[0]) + Math.PI / 2, st.belly, { contour: st.belly.r[0] });
  }
  for (let i = 0; i < 3; i++) {
    const t = .2 + i * .3, b = [lerp(nb[0], ne[0], t) - npv[0] * lerp(neckR[0], neckR[1], t) * .8, lerp(nb[1], ne[1], t) - npv[1] * lerp(neckR[0], neckR[1], t) * .8];
    const h = (st.bone >= 3 ? 6 : st.bone === 2 ? 4.5 : 2.8) * tr;
    spike(P, X(b[0] - nd[0] * 1.8, b[1] - nd[1] * 1.8), X(b[0] + nd[0] * 1.8, b[1] + nd[1] * 1.8), X(b[0] - npv[0] * h - nd[0] * h * .7, b[1] - npv[1] * h - nd[1] * h * .7), st.spikeMat, {});
  }
  // ---------- form 4: three void crystals grow from the shoulders, in front of the wings ----------
  if (p === 4) {
    [[-2, .5, 15, 6.5, .2], [4.5, .2, 12.5, 5.6, .42], [9.5, 2, 10, 4.8, .62]].forEach(([bx, by, len, wd, lean], i) => {
      const id = 'crystal_' + (i + 1), base = [hump[0] - 3 + bx, hump[1] - humpR[1] * .55 + by];
      const dir = -Math.PI / 2 - lean, dx = Math.cos(dir), dy = Math.sin(dir), nx = -dy, ny = dx;
      const at = (l, w) => X(base[0] + dx * len * l + nx * wd / 2 * w, base[1] + dy * len * l + ny * wd / 2 * w);
      P.part(id).joint(id, ...X(...base));
      plate(P, [at(-.08, -.75), at(.62, -1), at(1, 0), at(.62, 1), at(-.08, .75)], 2.2, { r: [INDIGO, VIOD, VIO, VIO, LILAC] }, { tilt: [-.3, -.2] });
      plate(P, [at(.02, .05), at(.62, .1), at(.95, 0), at(.62, .95), at(.02, .68)], 1.2, { r: [DVOID, INDIGO, VIOD, VIOD, VIOD] }, {});
      limb(P, at(.12, -.45), .5, at(.7, -.42), .5, LILAC, {});
      const g = at(.86, -.1); P.glow(...g, WHITE); P.glow(g[0] - dx * 2, g[1] - dy * 2, LILAC);
    });
  }
  // ---------- arm: a long forearm with digging claws ----------
  // the arm hangs from the front of the chest: elbow back, the hand forward, long hooked claws
  const am = st.arm, ar = [chest[0] + 14 * tr, chest[1] + 2.5 * tr], ae = [ar[0] - 1 * am, ar[1] + 12 * am], aw = [ae[0] + 10 * am + q.mouth * 3, ae[1] + 3 * am];
  P.part('arm').joint('arm', ...X(...ar)).joint('hand', ...X(aw[0] + 3 * am, aw[1] + 2 * am));
  blob(P, ...X(ar[0] - .5, ar[1] + 2), 5.6 * tr * s, 7 * tr * s, .3, hide, {});
  limb(P, X(...ar), 4 * tr * s, X(...ae), 3 * tr * s, hide, { contour: hide.r[0] });
  limb(P, X(...ae), 3.2 * tr * s, X(...aw), 2.4 * tr * s, hide, { contour: hide.r[0] });
  if (st.bone >= 2) spike(P, X(ae[0] - 1.5, ae[1] - 1), X(ae[0] + 1, ae[1] + 1.5), X(ae[0] - 4.5 * tr, ae[1] + 2.5 * tr), st.bone5, {});
  blob(P, ...X(aw[0] + .5, aw[1] + .5), 3 * tr * s, 2.6 * tr * s, 0, hide, {});
  for (let t = 0; t < 3; t++) { const b = [aw[0] + 1.5 + t * .5, aw[1] - 1 + t * 1.5], L0 = (p === 1 ? 6.5 : 6.2) * am; horn(P, [X(...b), X(b[0] + L0 * .55, b[1] + .2), X(b[0] + L0 * .85, b[1] + L0 * .45), X(b[0] + L0 * .75, b[1] + L0 * .8)], 1.4 * s, clawM, {}); }
  // ---------- throat gland (forms 3 and 4) ----------
  if (st.throat) {
    const ang = Math.atan2(nd[1], nd[0]), G = X(...gl);
    P.part('throat').joint('throat', ...X(gl[0] + npv[0] * 1.5, gl[1] + npv[1] * 1.5));
    blob(P, ...G, 3.9 * tr * s, 2.7 * tr * s, ang, st.throat, {});
    for (const k of [-1, 0, 1]) { const c = [G[0] + Math.cos(ang) * k * 2.2 * s, G[1] + Math.sin(ang) * k * 2.2 * s]; limb(P, [c[0] - npv[0] * 2.2 * s, c[1] - npv[1] * 2.2 * s], .5, [c[0] + npv[0] * 1.6 * s, c[1] + npv[1] * 1.6 * s], .5, st.throat.r[0], {}); }
    P.glow(G[0] + npv[0] * s, G[1] + npv[1] * s, st.throat.r[4]);
  }
  // ---------- head: the skull (head part) and the lower jaw (jaw part) ----------
  const hs = s * st.head, ha = st.headAng + q.headY * .02, hc = Math.cos(ha), hsn = Math.sin(ha), HJ = X(...ne);
  const H = (x, y) => [HJ[0] + (x * hc - y * hsn) * hs, HJ[1] + (x * hsn + y * hc) * hs];
  const open = st.open + q.mouth * 3;
  const hinge = [3, 3.2], jr = Math.atan2(open, 26);
  const J = (x, y) => { const dx = x - hinge[0], dy = y - hinge[1], c = Math.cos(jr), sn = Math.sin(jr); return H(hinge[0] + dx * c - dy * sn, hinge[1] + dx * sn + dy * c + .4); };
  P.part('jaw').joint('jaw', ...H(...hinge)).joint('mouth', ...J(26, 5));
  // the inside of the mouth: dark, the throat burning at its back
  plate(P, [J(3, 2.6), J(27, 3.2), J(27, 5.2), J(5, 6)], 1, null, { cfn: (x, y) => { const m = H(9, 3.5), d = Math.hypot(x - m[0], y - m[1]) / hs; return d < 3 ? st.mouth[2] : d < 7 ? st.mouth[1] : st.mouth[0]; } });
  plate(P, [J(1.5, 3.6), J(11, 4.6), J(28.5, 5.6), J(29, 7.4), J(23, 9.6), J(8, 9.4), J(0, 6.8)], 1.8, hide, {});
  limb(P, J(6, 8.6), .55 * hs, J(24, 8.4), .5 * hs, st.bone5, {});
  // lower fangs pointing up, lava drool
  for (const [x, l] of [[12.5, 3.2], [21, 4.6], [27, 3.4]]) spike(P, J(x - 1, 5.4), J(x + 1, 5.4), J(x + .3, 5.4 - l), BONE5, {});
  if (p >= 2) { const d0 = J(17, 9.5), d1 = J(26, 8); drip(P, d0[0], d0[1], Math.round(2 + 2.5 * s), [st.fire[3], st.fire[2], st.fire[1]]); drip(P, d1[0], d1[1], Math.round(1 + 2 * s), [st.fire[3], st.fire[2], st.fire[1]]); }
  P.part('head');
  // back of the skull, cheek, upper jaw
  blob(P, ...H(4, -3), 8.6 * hs, 7.4 * hs, ha, hide, {});
  blob(P, ...H(6.5, 1.2), 7 * hs, 4.6 * hs, ha, hide, { contour: hide.r[0] });
  plate(P, [H(6, -9), H(16, -8.4), H(26, -5.4), H(30.5, -2.6), H(31, 1.4), H(25, 3.4), H(9, 4)], 2.4 * hs, hide, {});
  // exposed skull: snout plate, brow ridge, cheekbone (bone ramp; obsidian in form 4)
  const skull = st.bone5;
  if (st.bone >= 1) plate(P, [H(13, -8.2), H(25, -5.6), H(30.2, -2.6), H(27, -2.3), H(15, -4.8)], 1.5 * hs, skull, {});
  limb(P, H(1.5, -8.5), 2.7 * hs, H(15.5, -7.4), 2 * hs, p === 4 ? GOLD5 : skull, { contour: skull.r[0] });
  if (st.bone >= 2) limb(P, H(5, 1.4), 1.5 * hs, H(17, 1.8), 1.1 * hs, p === 4 ? GOLD5 : skull, {});
  // nostril, the deep eye socket under the brow
  { const nn = H(27.5, -2.6); put(P, Math.round(nn[0]), Math.round(nn[1]), BLK); }
  blob(P, ...H(12.3, -3.9), 3.3 * hs, 2.4 * hs, ha - .15, BLK, {});
  // upper fangs hanging over the lower jaw, the big canine at the front
  for (const [x, l, w] of [[11, 2.8, 1], [15.5, 3.6, 1.1], [20, 3, 1], [25, 6.4, 1.5], [29, 3.6, 1]]) spike(P, H(x - w, 3.1), H(x + w, 3.1), H(x + .4, 3.1 + l), BONE5, {});
  // back-of-skull spikes (the frill)
  for (const [bx, by, tx, ty, w] of [[1, -6, -8, -9, 1.7], [-.5, -1, -9.5, .5, 1.5], [1, 4, -6, 8.5, 1.2]]) spike(P, H(bx, by - w), H(bx, by + w), H(tx, ty), p === 4 ? GOLD5 : st.spikeMat, {});
  if (st.horn === 1) {
    // horn nubs (form 2)
    spike(P, H(1.5, -9), H(5, -9.6), H(-2.5, -15.5), BONE5F, {});
    spike(P, H(4, -9.2), H(8, -9.8), H(.5, -17), BONE5, {});
  }
  if (st.horn === 0) for (const [x, y] of [[4, -10.6], [8, -10.4]]) blob(P, ...H(x, y), 1.2 * hs, 1 * hs, 0, BONE5, {});
  // the eye: a glowing pupil deep in the socket, with a faint glow around it
  const E = H(13, -3.9), eye = st.eye;
  P.glow(E[0], E[1], eye[2]).glow(E[0] - 1, E[1], eye[1]).glow(E[0] + 1, E[1], eye[1]);
  if (s * st.head > .75) P.glow(E[0], E[1] + 1, eye[0]).glow(E[0], E[1] - 1, eye[0]);
  // ---------- horns (forms 3 and 4): swept back, then up and forward like a demon's ----------
  if (st.horn >= 2) {
    const g = st.horn === 3, hm = g ? GOLD5 : BONE5, hmf = g ? GOLD5F : BONE5F;
    P.part('horns').joint('horns', ...H(3, -8));
    horn(P, [H(5.5, -8.4), H(-1, -14.5), H(-5.5, -21), H(-4, -27.5), H(.5, -30.5)], 2.5 * hs, hmf, { far: true });
    horn(P, [H(2.5, -7.6), H(-5, -13), H(-10.5, -19), H(-10, -26.5), H(-5.5, -31)], 3.1 * hs, hm, { contour: hm.r[0] });
    if (g) {
      // the crown: a lower horn pair sweeping back past the neck, spikes on the brow
      horn(P, [H(.5, -1), H(-7, -2), H(-14, .5), H(-18.5, 5)], 2.1 * hs, hm, { contour: hm.r[0] });
      for (const [x, l] of [[8, 4.6], [12, 3.4]]) spike(P, H(x - 1.2, -9.4), H(x + 1.2, -9.4), H(x - 2.2, -9.4 - l), hm, {});
    }
  }
  // ---------- form 4: void fire spills from both mouth corners ----------
  if (p === 4) {
    const m = J(8, 5.6), m2 = J(13, 6.4);
    P.part('mouth_flame').joint('mouth_flame', ...m);
    P.flame(m[0] - 1, m[1] + 1, Math.round(2 * s + 1), Math.round(4 * s), { seed: 11, pal: st.fire, front: true, dir: 1, lean: -2, sparks: false });
    P.flame(m2[0], m2[1] + 1, Math.round(1.6 * s + 1), Math.round(3 * s), { seed: 17, pal: st.fire, front: true, dir: 1, lean: -1, sparks: false });
  }
}

// ---------- frame layout and rendering ----------
const LAYOUT = {};
// Fits the frame around the dragon: measures all four flame frames in a big scratch painter, then
// places the dragon so its feet stand on row H - 2 (one row left for the outline).
function layout(p) {
  if (LAYOUT[p]) return LAYOUT[p];
  const big = { ox: 220, gy: 300 };
  let x0 = Infinity, y0 = Infinity, x1 = -1;
  for (let f = 0; f < 4; f++) {
    const P = new Painter(460, 320, f, null);
    drawKnochen(P, p, REST, big);
    const px = P.finish();
    for (let i = 0; i < px.length; i++) if (px[i]) { const x = i % 460, y = (i / 460) | 0; x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); }
  }
  const m = 1, W = x1 - x0 + 1 + 2 * m, H = big.gy - y0 + 1 + m + 1;
  return (LAYOUT[p] = { W, H, ox: big.ox - x0 + m, gy: H - 2 });
}
/** Form p (1-4) in its rest pose. part: one rig part id renders only that part (with its own
 *  outline), null all of them. skip(i): no outline at pixel i (seamless joints). */
function renderRig(p, part, frame, skip) {
  const L = layout(p), P = new Painter(L.W, L.H, frame || 0, part == null ? null : part);
  drawKnochen(P, p, REST, L);
  return { w: L.W, h: L.H, px: P.finish(skip), solid: P.solid.map(Boolean), joints: P.joints, tags: P.tags };
}
const SEAMLESS = [['body', 'neck'], ['neck', 'head'], ['body', 'tail_1'], ['tail_1', 'tail_2'], ['tail_2', 'tail_3'], ['tail_3', 'tail_4'], ['tail_4', 'tail_5']];
const FLIPBOOK = new Set(['tail_flame', 'mouth_flame']);
const hex = c => [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
function toRgba(r) { const d = new Uint8Array(r.w * r.h * 4); r.px.forEach((c, i) => { if (c) d.set([...hex(c), 255], i * 4); }); return d; }
/** Builds the part rig like export_rigs.js's buildForm: images per part (isolated, own outline,
 *  seamless joints) and the rig entry (pivots, parents, z, HP from export_rigs FORMS). */
function buildRig(p) {
  const id = 'drache' + p, form = ER.FORMS[p], all = renderRig(p, null, 0), J = all.joints, W = all.w, H = all.h;
  const unknown = all.tags.filter(t => ER.PARENT[t] === undefined);
  if (unknown.length) throw new Error(id + ': untagged parts ' + unknown.join(', '));
  const ids = all.tags.slice().sort((a, b) => ER.Z[a] - ER.Z[b] || all.tags.indexOf(a) - all.tags.indexOf(b));
  const solid = {}, images = {}, parts = [];
  for (const part of ids) solid[part] = renderRig(p, part, 0).solid;
  for (const part of ids) {
    const near = SEAMLESS.filter(pr => pr.includes(part)).map(pr => solid[pr[0] === part ? pr[1] : pr[0]]).filter(Boolean);
    const skip = near.length ? i => near.some(m => m[i]) : undefined;
    images[part] = (FLIPBOOK.has(part) ? [0, 1, 2, 3] : [0]).map(f => toRgba(renderRig(p, part, f, skip)));
    if (!J[part]) throw new Error(id + ': no joint for ' + part);
    const entry = { id: part, pivot: J[part].map(v => Math.round(v * 10) / 10), parent: ER.PARENT[part], z: ER.Z[part], hp: form.hp[part] || 0 };
    const cut = form.cut[part];
    if (!cut) entry.unbreakable = true; else Object.assign(entry, cut);
    parts.push(entry);
  }
  const bounds = img => { let x0 = W, y0 = H, x1 = -1, y1 = -1; for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (img[(y * W + x) * 4 + 3]) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } return { x0, y0, x1, y1 }; };
  let gy = -1, gx0 = W, gx1 = -1, sx0 = W, sx1 = -1;
  for (const l of ['leg_far', 'leg_near']) gy = Math.max(gy, bounds(images[l][0]).y1);
  for (const l of ['leg_far', 'leg_near']) for (let x = 0; x < W; x++) if (images[l][0][(gy * W + x) * 4 + 3]) { gx0 = Math.min(gx0, x); gx1 = Math.max(gx1, x); }
  for (const pt of ['body', 'leg_far', 'leg_near']) { const b = bounds(images[pt][0]); sx0 = Math.min(sx0, b.x0); sx1 = Math.max(sx1, b.x1); }
  const r1 = v => Math.round(v * 10) / 10;
  const rig = {
    family: 'drake', variant: String(p), size: [W, H], scale: 2.5, ground: [r1((gx0 + gx1 + 1) / 2), gy], width: Math.round((sx1 - sx0 + 1) * .85),
    material: p === 4 ? 'obsidian' : 'ember', parts, groups: form.groups,
    points: { mouth: { part: 'jaw', at: J.mouth.map(r1) }, throat: { part: 'neck', at: J.throat_at.map(r1) }, hand: { part: 'arm', at: J.hand.map(r1) }, tail_tip: { part: 'tail_5', at: J.tail_tip.map(r1) }, core: { part: 'body', at: J.core.map(r1) } },
  };
  return { id, def: { name: 'Ignaroth · ' + STYLE[p].name + ' (Knochen-Inferno)' }, rig, images, W, H };
}
/** The rest pose composed from the parts in z order, as the game layers them. */
function compose(form, frame) {
  const { W, H, rig, images } = form, out = new Uint8Array(W * H * 4);
  for (const e of rig.parts) {
    const fr = images[e.id], img = fr[Math.min(fr.length - 1, frame || 0)];
    for (let i = 0; i < W * H; i++) if (img[i * 4 + 3]) out.set(img.subarray(i * 4, i * 4 + 4), i * 4);
  }
  return out;
}
/** Observations on the rig contract (export_rigs.js --check rules): parts cut by the frame, points
 *  far from their part, the ground far from the feet, top-layer pixels per severable part. */
function rigNotes(form) {
  const { W, H, rig, images } = form, notes = [], has = (img, x, y) => x >= 0 && y >= 0 && x < W && y < H && img[(y * W + x) * 4 + 3] > 0;
  const near = (img, at) => { let d = Infinity; for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (has(img, x, y)) d = Math.min(d, Math.hypot(x + .5 - at[0], y + .5 - at[1])); return d; };
  for (const e of rig.parts) {
    const img = images[e.id][0];
    for (let x = 0; x < W; x++) if (has(img, x, 0)) { notes.push(`${e.id} on row 0`); break; }
    for (let y = 0; y < H; y++) if (has(img, 0, y) || has(img, W - 1, y)) { notes.push(`${e.id} on the side column`); break; }
  }
  for (const n in rig.points) { const pt = rig.points[n], d = near(images[pt.part][0], pt.at); if (d > 3) notes.push(`point ${n} ${d.toFixed(1)} px from ${pt.part}`); }
  const vis = Object.fromEntries(rig.parts.map(e => [e.id, 0]));
  for (let i = 0; i < W * H; i++) { let o = null, z = -1; for (const e of rig.parts) if (images[e.id][0][i * 4 + 3] && e.z > z) { o = e.id; z = e.z; } if (o) vis[o]++; }
  const sev = rig.parts.filter(e => !e.unbreakable && e.hp > 0).map(e => `${e.id} ${vis[e.id]}px`);
  return { notes, severable: sev };
}

// ---------- PNG in/out and a tiny canvas ----------
function crc32(buf) { let c, crc = 0xffffffff; for (let n = 0; n < buf.length; n++) { c = (crc ^ buf[n]) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = (crc >>> 8) ^ c; } return (crc ^ 0xffffffff) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type, 'ascii'), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, crc]); }
function encodePng(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
function decodePng(buf) {
  let pos = 8, w = 0, h = 0, type = 0, pal = null, trns = null; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), kind = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (kind === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); type = data[9]; if (data[8] !== 8) throw new Error('bit depth'); }
    else if (kind === 'PLTE') pal = data; else if (kind === 'tRNS') trns = data; else if (kind === 'IDAT') idat.push(data); else if (kind === 'IEND') break;
    pos += 12 + len;
  }
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[type], stride = w * ch, raw = zlib.inflateSync(Buffer.concat(idat)), px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[y * stride + x - ch] : 0, b = y ? px[(y - 1) * stride + x] : 0, c = x >= ch && y ? px[(y - 1) * stride + x - ch] : 0;
      let v = raw[y * (stride + 1) + 1 + x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      px[y * stride + x] = v & 255;
    }
  }
  const rgba = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    const s = i * ch;
    if (type === 6) rgba.set(px.subarray(s, s + 4), i * 4); else if (type === 2) rgba.set([px[s], px[s + 1], px[s + 2], 255], i * 4);
    else if (type === 0) rgba.set([px[s], px[s], px[s], 255], i * 4); else if (type === 4) rgba.set([px[s], px[s], px[s], px[s + 1]], i * 4);
    else { const k = px[s]; rgba.set([pal[k * 3], pal[k * 3 + 1], pal[k * 3 + 2], trns && k < trns.length ? trns[k] : 255], i * 4); }
  }
  return { w, h, rgba };
}
const FONT = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111', F: '111100110100100',
  G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010', K: '101101110101101', L: '100100100100111',
  M: '101111111101101', N: '110101101101101', O: '010101101101010', P: '110101110100100', Q: '010101101110011', R: '110101110101101',
  S: '011100010001110', T: '111010010010010', U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101',
  Y: '101101010010010', Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111', 9: '111101111001110',
  ' ': '000000000000000', '.': '000000000000010', ':': '000010000010000', '-': '000000111000000', '/': '001001010100100', 'x': '000101010101000',
  '(': '001010010010001', ')': '100010010010100', '=': '000111000111000', ',': '000000000010100', '+': '000010111010000',
};
class Canvas {
  constructor(w, h, bg) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); for (let i = 0; i < w * h; i++) this.d.set([bg[0], bg[1], bg[2], 255], i * 4); }
  px(x, y, c, a) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4;
    if (a == null || a >= 1) { this.d[i] = c[0]; this.d[i + 1] = c[1]; this.d[i + 2] = c[2]; this.d[i + 3] = 255; return; }
    for (let k = 0; k < 3; k++) this.d[i + k] = Math.round(this.d[i + k] * (1 - a) + c[k] * a);
  }
  rect(x, y, w, h, c, a) { for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.px(xx, yy, c, a); }
  text(x, y, str, c, k) { k = k || 2; for (const ch of String(str)) { const g = FONT[ch] || FONT[ch.toUpperCase()] || FONT[' ']; for (let i = 0; i < 15; i++) if (g[i] === '1') this.rect(x + (i % 3) * k, y + Math.floor(i / 3) * k, k, k, c); x += 4 * k; } }
  // nearest-neighbour blit, any positive scale
  image(img, w, h, x, y, k) {
    const W = Math.round(w * k), Hh = Math.round(h * k);
    for (let yy = 0; yy < Hh; yy++) for (let xx = 0; xx < W; xx++) {
      const sx = Math.min(w - 1, Math.floor(xx / k)), sy = Math.min(h - 1, Math.floor(yy / k)), i = (sy * w + sx) * 4;
      if (img[i + 3] > 0) this.px(x + xx, y + yy, [img[i], img[i + 1], img[i + 2]], img[i + 3] / 255);
    }
  }
  // a soft pixel shadow: two nested ellipses in source-pixel blocks of size k
  shadow(cx, cy, rx, ry, k) {
    for (let yy = -ry - 1; yy <= ry + 1; yy++) for (let xx = -rx - 1; xx <= rx + 1; xx++) {
      const q = ((xx + .5) / rx) ** 2 + ((yy + .5) / ry) ** 2;
      if (q <= 1.15) this.rect(Math.round(cx + xx * k), Math.round(cy + yy * k), k, k, [10, 6, 8], q <= .55 ? .5 : q <= 1 ? .36 : .18);
    }
  }
}

// ---------- the preview sheets ----------
function main() {
  const repo = path.join(__dirname, '..', '..', '..');
  const outDir = process.argv[2] || path.join(repo, 'production', 'qa', 'evidence', 'drake-concepts');
  fs.mkdirSync(outDir, { recursive: true });
  const knight = decodePng(fs.readFileSync(path.join(repo, 'assets', 'sprites', '0x72', 'knight_m_idle_anim_f0.png')));
  const forms = [1, 2, 3, 4].map(buildRig);
  const FLOOR = [44, 32, 36], TEXT = [236, 226, 214], DIM = [170, 150, 150], HERO_H = 84;
  const topOf = f => { const img = compose(f, 0); for (let y = 0; y < f.H; y++) for (let x = 0; x < f.W; x++) if (img[(y * f.W + x) * 4 + 3]) return y; return 0; };
  const info = forms.map(f => ({ f, top: topOf(f), img: compose(f, 0) }));
  // 1. lineup: same in-game scale (source px x 2 = 0.4 x world), the knight beside each form
  {
    const k = 2, kk = 3 * .4, gap = 36, kw = Math.round(16 * kk);
    const tall = Math.max(...info.map(i => (i.f.rig.ground[1] - i.top + 1) * k));
    const W = info.reduce((a, i) => a + i.f.W * k + kw + 10 + gap, gap), base = 24 + tall + 10, H = base + 70;
    const c = new Canvas(W, H, FLOOR);
    for (let y = base + 2; y < H - 48; y += 6) c.rect(0, y, W, 1, [52, 38, 42]);
    let x = gap;
    c.text(gap, 8, 'IGNAROTH KONZEPT KNOCHEN-INFERNO   ALLE FORMEN IM SPIELMASSSTAB 0.4X   RITTER 0X72 DANEBEN', TEXT, 2);
    for (const { f, img } of info) {
      const gy = f.rig.ground[1], y0 = base - (gy + 1) * k;
      c.shadow(x + f.rig.ground[0] * k, base - 1, Math.round(f.rig.width / 2), Math.max(2, Math.round(f.rig.width * .11)), k);
      c.image(img, f.W, f.H, x, y0, k);
      const hx = x + f.W * k + 10;
      c.shadow(hx + kw / 2, base - 1, 5, 2, 2);
      c.image(knight.rgba, 16, 28, hx, base - Math.round(28 * kk), kk);
      const heightW = (gy - topOf(f) + 1) * 5, p = +f.rig.variant;
      c.text(x, base + 12, `${p} ${STYLE[p].name}`, TEXT, 2);
      c.text(x, base + 26, `FRAME ${f.W}x${f.H}  HOEHE ${(heightW / HERO_H).toFixed(1)}x RITTER`, DIM, 2);
      x += f.W * k + kw + 10 + gap;
    }
    fs.writeFileSync(path.join(outDir, 'knocheninferno_lineup.png'), encodePng(W, H, c.d));
  }
  // 2. form 4 large (source px x 5 = world size) with form 3 beside it
  {
    const k = 5, f4 = info[3], f3 = info[2], gap = 40;
    const W = gap + f4.f.W * k + gap + f3.f.W * k + gap, base = 30 + f4.f.H * k, H = base + 50;
    const c = new Canvas(W, H, FLOOR);
    let x = gap;
    for (const { f, img } of [f4, f3]) {
      c.shadow(x + f.rig.ground[0] * k, base - 3, Math.round(f.rig.width / 2), Math.max(2, Math.round(f.rig.width * .11)), k);
      c.image(img, f.W, f.H, x, base - (f.rig.ground[1] + 1) * k, k);
      c.text(x, base + 14, `${f.rig.variant} ${STYLE[+f.rig.variant].name}  ${f.W}x${f.H} SOURCE PX  X5`, TEXT, 3);
      x += f.W * k + gap;
    }
    fs.writeFileSync(path.join(outDir, 'knocheninferno_form4.png'), encodePng(W, H, c.d));
  }
  // 3. in-game mock: the floor from the floor-5 screenshot, form 4 at world scale, the knight at x3
  {
    const shot = decodePng(fs.readFileSync(path.join(repo, 'production', 'qa', 'evidence', 'hell-monsters', '01-kampfraum-etage5.png')));
    const c = new Canvas(1280, 720, FLOOR);
    // a clean floor patch (tile aligned, 4 x 3 tiles of 48 px) repeated over the screen
    // the hell floor tiles at world scale (96 world px each; the screenshot shows the world zoomed
    // out, its tiles are ~68 px), mostly plain stone with some glowing cracks, picked by a hash
    const tiles = {};
    for (const t of [0, 1, 2, 3, 4, 7, 8, 9, 10, 11]) tiles[t] = decodePng(fs.readFileSync(path.join(repo, 'assets', 'sprites', 'hell', `floor_${String(t).padStart(2, '0')}.png`)));
    const pick = [0, 0, 1, 4, 10, 11, 0, 1, 4, 10, 11, 2, 3, 7, 8, 9];
    for (let ty = 0; ty < 8; ty++) for (let tx = 0; tx < 14; tx++) {
      const t = tiles[pick[Math.floor(hash(tx, ty, 77) * pick.length)]];
      for (let y = 0; y < 96; y++) for (let x = 0; x < 96; x++) { const i = (y * 96 + x) * 4; c.px(tx * 96 + x - 16, ty * 96 + y - 24, [t.rgba[i], t.rgba[i + 1], t.rgba[i + 2]]); }
    }
    // the screenshot's look: a warm red edge light (sampled from its corner) over the floor
    const edge = [shot.rgba[(700 * shot.w + 20) * 4], shot.rgba[(700 * shot.w + 20) * 4 + 1], shot.rgba[(700 * shot.w + 20) * 4 + 2]];
    for (let y = 0; y < 720; y++) for (let x = 0; x < 1280; x++) { const e = Math.max(Math.abs(x - 640) / 640, Math.abs(y - 360) / 360); if (e > .6) c.px(x, y, [Math.max(edge[0], 110), 14, 18], Math.min(.55, (e - .6) * 1.2)); }
    const f = info[3].f, k = 5, gx = 700, gy = 610;
    c.shadow(gx, gy - 2, Math.round(f.rig.width / 2), Math.round(f.rig.width * .11), k);
    c.image(info[3].img, f.W, f.H, gx - Math.round(f.rig.ground[0] * k), gy - (f.rig.ground[1] + 1) * k, k);
    const hx = 300, hy = 680;
    c.shadow(hx + 24, hy - 2, 7, 2, 3);
    c.image(knight.rgba, 16, 28, hx, hy - 84, 3);
    c.text(20, 20, 'MOCK: OBSIDIANFORM X5 WELT-PX, RITTER X3   (KONZEPT KNOCHEN-INFERNO, NICHT VERDRAHTET)', [250, 230, 210], 2);
    fs.writeFileSync(path.join(outDir, 'knocheninferno_ingame.png'), encodePng(1280, 720, c.d));
  }
  // 4. the part rigs in export_rigs.js's own preview format (rest pose from parts, exploded view)
  for (const f of forms) {
    for (const e of f.rig.parts) e.label = e.id;
    ER.preview(f, path.join(outDir, `knocheninferno_rig${f.rig.variant}.png`));
  }
  for (const f of forms) {
    const r = rigNotes(f), top = info.find(i => i.f === f).top;
    console.log(`${f.id}: frame ${f.W}x${f.H}, height ${((f.rig.ground[1] - top + 1) * 5 / HERO_H).toFixed(2)}x knight, parts ${f.rig.parts.length}, severable ${r.severable.join(', ') || '-'}${r.notes.length ? ', NOTES: ' + r.notes.join('; ') : ''}`);
  }
  console.log('wrote', outDir);
}

module.exports = { drawKnochen, renderRig, buildRig, compose, layout, STYLE, REST, decodePng, encodePng };
if (require.main === module) main();

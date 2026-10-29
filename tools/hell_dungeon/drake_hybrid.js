// Ignaroth's production art (forms 1-4, drache1..4): the approved concept "Hybrid" (user, 2026-10-29:
// "Ja, so einbauen"; previews in production/qa/evidence/drake-concepts/hybrid_*.png).
// The pose, 3/4 view, scale and looming head-down stance of "monumental" (the body turns toward the
// viewer, the near wing spreads wide, the head drops toward the hero) with the hell layer of
// "knocheninferno": an open ribcage over a glowing core on the flank, a skull head in every form
// (bone mask, a hot eye in a sunk socket, long fangs, lava or void drool), burned wing membranes
// with lopsided rips and bare finger bones, a higher S-curved neck, a faceted throat gem in a bezel
// (forms 3, 4), a burning spiked tail club (forms 3, 4), a growing horn crown, a dark lava-stone
// salamander (form 1), wing buds on form 2's back. Form 3's far wing rises up and back behind the
// shoulders; form 4's fans out right of the head (its membrane lies right of its pivot, so its flap
// turns the other way: farWingRight).
//
// Drawing model: every rig part is sculpted from volumes into a small z-buffer, lit (key light top
// left), quantised to 4-5 tone ramps of the 0x72 palette (plus a few derived deeper shades), then
// stamped into hell_monsters.js's Painter: part tags (P.part), pivots and points (P.joint), flames
// (P.flame), the 1 px #222222 outline (P.finish).
//
// Users:
//   export_rigs.js      renderRig/parts: one PNG per rig part + hell_rigs.json (the game's part rig)
//   hell_monsters.js    sheetFrame/sheetLayout: the drache1..4 atlases (idle, run, attack, cast, fly;
//                       death is derived from idle), drawn from the same parts, so every place that
//                       shows a drake sheet (intro, echoes, transformation, bestiary) shows this art
//   concepts/hybrid.js  the concept previews (lineup, in-game mock-ups, pose sheets)
// UMD like hell_monsters.js: in the browser preview it is window.DrakeHybrid and needs
// window.HellMonsters loaded first.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('./hell_monsters.js'));
  else root.DrakeHybrid = factory(root.HellMonsters);
})(typeof self !== 'undefined' ? self : this, function (HM) {
  'use strict';

  // ---------- palette: 0x72 DungeonTileset II colours (the constants of hell_monsters.js) ----------
  const K = '#222222', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a';
  const RED = '#da4e38', CRIM = '#9f294e', MAROON = '#62232f', PLUM = '#38262d', PURP = '#5f2d56', MAG = '#993970';
  const PINK = '#dc4a7b', LILAC = '#f0b3dd', VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579';
  const YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025', BROWN = '#8f4029';
  const MUD = '#775c55', STONE = '#483b3a', COAL = '#3b3332', SOOT = '#302c2b';
  // derived steps (deeper shadows, the far side, the obsidian sheen), each one step from a palette colour
  const GLOSS = '#8c7b8e';  // obsidian's glassy streak: MUD lifted toward LILAC
  const BROWN0 = '#5c2a22', CRIM0 = '#4a1a26', PLUM0 = '#26151c', SOOT0 = '#171315', INDIGO0 = '#231b42', PURP0 = '#2c1832';
  const PIT = '#0e0a0c';    // the eye socket and the nasal pit: deeper than SOOT0
  const FIRE = [WHITE, YEL, ORA, RED, CRIM];
  const VOIDFIRE = [LILAC, VIO, VIOD, PURP, INDIGO];

  // ---------- light ----------
  const nrm = (x, y, z) => { const l = Math.hypot(x, y, z) || 1; return [x / l, y / l, z / l]; };
  const L = nrm(-.55, -.7, .45);
  const HV = nrm(L[0], L[1], L[2] + 1);
  const SL = (() => { const l = Math.hypot(L[0], L[1]); return [L[0] / l, L[1] / l]; })();
  const hash = (x, y, k) => ((((x * 73856093) ^ (y * 19349663) ^ ((k || 0) * 83492791)) >>> 0) % 1000) / 1000;

  // ---------- sculpt: volumes into a z-buffer, then lit and quantised (monumental's engine) ----------
  function Sculpt(P, T) { this.P = P; this.T = T; this.m = new Map(); }
  const S_ = Sculpt.prototype;
  S_.put = function (x, y, z, n, mat, tex) {
    if (x < 0 || y < 0 || x >= this.P.w || y >= this.P.h) return;
    const k = y * this.P.w + x, c = this.m.get(k);
    // two volumes of one material meeting at almost the same depth blend their normals (no checker
    // where they interleave); otherwise the nearer one wins
    if (c && c.mat === mat && Math.abs(z - c.z) < 2.5) {
      // weight of the farther surface: 1/2 where both meet, 0 once they are 2.5 px apart (continuous)
      const t = .5 * (1 - Math.abs(z - c.z) / 2.5), hi = z >= c.z ? n : [c.nx, c.ny, c.nz], lo = z >= c.z ? [c.nx, c.ny, c.nz] : n;
      const b = nrm(hi[0] * (1 - t) + lo[0] * t, hi[1] * (1 - t) + lo[1] * t, hi[2] * (1 - t) + lo[2] * t);
      if (z >= c.z) { c.z = z; c.tex = tex || {}; }
      c.nx = b[0]; c.ny = b[1]; c.nz = b[2];
      return;
    }
    if (!c || z >= c.z) this.m.set(k, { x, y, z, nx: n[0], ny: n[1], nz: n[2], mat, tex: tex || {} });
  };
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
      const cand = [];
      for (let i = 0; i < q.length - 1; i++) {
        const a = q[i], b = q[i + 1], dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy || 1e-6;
        const t = Math.max(0, Math.min(1, ((px - a[0]) * dx + (py - a[1]) * dy) / l2));
        const cx = a[0] + dx * t, cy = a[1] + dy * t, r = a[2] + (b[2] - a[2]) * t, d = Math.hypot(px - cx, py - cy);
        if (d > r) continue;
        const h = Math.sqrt(Math.max(0, r * r - d * d)), z = a[3] + (b[3] - a[3]) * t + h * dzk, n = [(px - cx) / r, (py - cy) / r, h / r + .05];
        cand.push([z, n]);
        if (!best || z > best.z) {
          const l = Math.sqrt(l2), side = ((px - cx) * dy - (py - cy) * dx) / l / r;
          best = { z, n, tex: { along: len[i] + l * t, side, t: (i + t) / (q.length - 1) } };
        }
      }
      if (best) {
        // a smooth union: the segments' normals blend by how close their depth is to the top one, so
        // the joints between spline segments show no faceting or checker
        let sx = 0, sy = 0, sz = 0;
        for (const [z, n] of cand) { const wgt = Math.exp((z - best.z) / .7); sx += n[0] * wgt; sy += n[1] * wgt; sz += n[2] * wgt; }
        this.put(x, y, best.z, nrm(sx, sy, sz), mat, best.tex);
      }
    }
    return this;
  };
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
  S_.cut = function (c, r) {
    const { s, ox, oy } = this.T, cx = ox + c[0] * s, cy = oy + c[1] * s, R = r * s;
    for (const [k, v] of this.m) if (Math.hypot(v.x + .5 - cx, v.y + .5 - cy) <= R) this.m.delete(k);
    return this;
  };
  // A burned-through tear with a ragged, lopsided edge: h = [centre, radius, seed, angle, stretch]
  // (units, radians). The 2nd and 3rd harmonics with random phases keep it asymmetric (no rune or eye
  // shapes), the stretch pulls it into a rip along the angle. ragDist: px past the edge.
  const ragR = (h, a) => { const sd = h[2] || 0; return h[1] * (1 + .3 * Math.sin(2 * a + sd) + .22 * Math.sin(3 * a + 2.1 * sd) + .12 * Math.sin(5 * a + .7 * sd)); };
  S_.ragDist = function (h, x, y) {
    const { s, ox, oy } = this.T, dx = x - (ox + h[0][0] * s), dy = y - (oy + h[0][1] * s);
    const an = h[3] || 0, el = h[4] || 1, u = (dx * Math.cos(an) + dy * Math.sin(an)) / el, w = -dx * Math.sin(an) + dy * Math.cos(an);
    return Math.hypot(u, w) - ragR(h, Math.atan2(w, u)) * s;
  };
  // cut pixels are remembered as holes: the membrane's lit edge stops there (the burn ring paints them)
  S_.cutRag = function (h) {
    this.holes = this.holes || new Set();
    for (const [k, v] of this.m) if (this.ragDist(h, v.x + .5, v.y + .5) <= 0) { this.m.delete(k); this.holes.add(k); }
    return this;
  };
  S_.has = function (x, y) { return x >= 0 && y >= 0 && x < this.P.w && y < this.P.h && this.m.has(y * this.P.w + x); };
  // Lights every sculpted pixel and stamps it into the Painter under the current part tag. The ground
  // light (rim) and the back rim (rim2) fall only where the whole dragon's silhouette ends (P.sil, the
  // composed rest pose), so a part lying over another one gets no coloured seam line there.
  S_.flush = function () {
    if (!this.P.keep()) return this;
    const w = this.P.w, m = this.m, sil = this.P.sil;
    this.colour = new Map();
    for (const [k, c] of m) {
      let M = c.mat;
      const ramp = M.ramp, n = ramp.length, amb = M.amb != null ? M.amb : .14;
      const d = c.nx * L[0] + c.ny * L[1] + c.nz * L[2];
      const v = amb + (1 - amb) * Math.pow(Math.max(0, d), M.gamma || 1) * (M.gain || 1);
      let i = Math.min(n - 1, Math.floor(v * n));
      let shadow = false;
      for (let t = 2; t <= 6 && !shadow && !M.flatShade; t++) { const q = m.get(Math.round(c.y - SL[1] * t) * w + Math.round(c.x - SL[0] * t)); if (q && q.mat !== M && q.z > c.z + t * .8 + 2) shadow = true; }
      let occ = false;
      if (!M.flatShade) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const q = m.get((c.y + dy) * w + c.x + dx); if (q && q.z > c.z + 3.5) occ = true; }
      if (shadow) i -= 1;
      if (occ && !M.occCol) i -= 1;
      i += M.shift || 0;
      if (M.tone) i += M.tone(c, i, n) || 0;
      i = Math.max(0, Math.min(n - 1, i));
      const top = i === n - 1;
      let col = ramp[i];
      const holes = this.holes, open = (dx, dy) => { const kk = (c.y + dy) * w + c.x + dx; return (!m.has(kk) && !(holes && holes.has(kk))) || c.y + dy >= this.P.h; };
      const outer = (dx, dy, k) => { for (let j = 1; j <= (k || 1); j++) { const x = c.x + dx * j, y = c.y + dy * j; if (!(!sil || x < 0 || y < 0 || x >= w || y >= this.P.h || !sil[y * w + x])) return false; } return true; };
      if (occ && M.occCol) col = M.occCol;
      if (M.edgeL && open(-1, 0) && !open(0, -1)) col = M.edgeL;
      else if (M.edgeTop && (open(0, -1) || (open(-1, 0) && (c.ny < 0 || M.edgeLeft)))) col = M.edgeTop;
      else if (M.edge && (open(1, 0) || open(-1, 0) || open(0, 1) || open(0, -1))) col = M.edge;
      else if (M.rim && c.ny > .4 && c.nz < .8 && open(0, 1) && outer(0, 1, 3)) col = typeof M.rim === 'number' ? ramp[Math.min(n - 1, i + M.rim)] : M.rim;
      else if (M.rim2 && c.nz < .75 && ((c.nx < -.45 && c.ny < -.05 && open(-1, 0) && outer(-1, 0)) || (c.ny < -.72 && c.nx < .3 && open(0, -1) && outer(0, -1)))) col = typeof M.rim2 === 'number' ? ramp[Math.min(n - 1, i + M.rim2)] : M.rim2;
      if (M.spec && top && c.nx * HV[0] + c.ny * HV[1] + c.nz * HV[2] > M.specT) col = M.spec;
      this.colour.set(k, col);
      this.P.dot(c.x, c.y, col);
    }
    return this;
  };
  S_.dot = function (x, y, col) { x = Math.round(x); y = Math.round(y); if (this.has(x, y)) this.P.dot(x, y, col); return this; };
  S_.line = function (a, b, col, o) {
    o = o || {};
    const { s, ox, oy } = this.T, x0 = ox + a[0] * s, y0 = oy + a[1] * s, x1 = ox + b[0] * s, y1 = oy + b[1] * s;
    const n = Math.max(1, Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))));
    for (let i = 0; i <= n; i++) { const x = Math.round(x0 + (x1 - x0) * i / n), y = Math.round(y0 + (y1 - y0) * i / n); if (!o.inner || this.inner(x, y)) this.dot(x, y, typeof col === 'function' ? col(i, n) : col); }
    return this;
  };
  S_.inner = function (x, y) { return this.has(x, y) && this.has(x + 1, y) && this.has(x - 1, y) && this.has(x, y + 1) && this.has(x, y - 1); };

  function rng(seed) { let s = (seed * 2654435761) >>> 0 || 1; return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296); }
  // A few glowing seams over this part's shadowed interior: random walks with a hot core.
  function cracks(S, seed, n, len, col, o) {
    if (!S.P.keep()) return;
    o = o || {};
    const col0 = k => S.colour && S.colour.get(k), ok = c => !o.cols || o.cols.has(col0(c.y * S.P.w + c.x));
    const R = rng(seed), cells = [...S.m.values()].filter(c => S.inner(c.x, c.y) && ok(c) && (!o.mats || o.mats.includes(c.mat)));
    for (let k = 0; k < n && cells.length; k++) {
      const c0 = cells[Math.floor(R() * cells.length)];
      let x = c0.x, y = c0.y, ang = o.ang != null ? o.ang + (R() - .5) * .8 : R() * Math.PI * 2;
      const L0 = Math.round(len * (.7 + R() * .5));
      for (let i = 0; i < L0; i++) {
        if (!S.inner(x, y)) break;
        const hot = i > 1 && i < L0 - 2 && (i % 3 === 1);
        S.P.dot(x, y, hot ? col[1] : col[0]);
        if (hot && col[2] && R() < .45) S.P.dot(x, y, col[2]);
        ang += (R() - .5) * 1.1;
        const nx = x + Math.round(Math.cos(ang)), ny = y + Math.round(Math.sin(ang));
        if (nx === x && ny === y) { x += 1; continue; }
        x = nx; y = ny;
      }
    }
  }

  // ---------- the skeletons ----------
  // Units: form 4's skeleton (1 unit = 1 source px at s = 1), origin on the ground below the hip, y up
  // is negative. 3/4 view: the body turns toward the viewer (down right), the far limbs sit up and right.
  // Monumental's skeletons with: the near arm moved to the front of the chest (the flank stays free
  // for the ribcage), the near wing's root a little further back, a higher S-neck (the head rises
  // and drops onto the hero), the far wing raised so its edge stands clear above the head.
  const MONU_ADULT = {
    skull: [[61, -85], [8.4, 7], .3], snout: [[64, -83, 6.6], [70.5, -79, 5.6], [76, -75, 4.4], [79, -72.5, 3.4]],
    ridge: [[60, -89, 2.6], [67, -86, 2.3], [74, -80.5, 1.7], [78, -76.5, 1.2]],
    brow: [[55.5, -90, 3], [62.5, -91, 3.2], [69, -87, 2.2]],
    cheekMass: [[58.5, -79], [6, 4.6], .55],
    eye: [66, -84.5], eyeFar: [72, -87.5], nostril: [77.5, -76],
    cheek: [[[54, -81, 2.2], [47, -80, 1.2], [43, -80, .4]], [[56, -77, 2], [50, -73, 1.1], [47, -71, .4]]],
    cheekbone: [[60, -81.5, 1.5], [65, -80, 1.3], [70, -78.5, 1]],
    // the skull mask: a bone plate over brow and snout (its top plane lit, its side plane in half
    // light), the eye socket and the nasal pit sunk into it
    maskTop: [[54, -92.5], [61, -95], [67.5, -92], [73.5, -86], [78.5, -80.5], [81.5, -76], [79.5, -75], [75.5, -78.5], [70, -83.5], [64, -88], [57, -89.5]],
    maskSide: [[57, -89.5], [64, -88], [70, -83.5], [75.5, -78.5], [79.5, -75], [80, -73], [76.5, -73.5], [71.5, -77], [66, -79.5], [60.5, -79.5], [55.5, -81], [54, -85.5]],
    jaw: { hinge: [59, -78], pts: [[58, -78, 4.8], [65, -70.5, 3.8], [72, -63.5, 2.7], [75.5, -61, 1.8]], mouth: [[60, -79.5], [79, -74], [74.5, -62.5], [61, -71]] },
    horns: [
      [[59, -89, 3.8], [53, -94.5, 3.1], [46, -98.5, 2.5], [40.5, -102.5, 1.9], [37.5, -106, 1.1], [37.5, -108, .45]],
      [[65, -91, 2.9], [62, -97.5, 2.4], [57.5, -101.5, 1.8], [53.5, -104.5, 1.1], [52, -106, .4]],
    ],
    crown: [[[63, -92, 1.5], [64.5, -96.5, .9], [65, -99, .4]], [[67.5, -89.5, 1.3], [70, -93.5, .8], [71, -95.5, .35]], [[56.5, -91.5, 1.4], [56, -96, .8], [55, -98.5, .35]]],
    crest: [[[56, -88, 1.6], [51, -91, .9], [48, -91.5, .4]]],
  };
  const NECK_END_M = [57, -86];
  // shifts every head feature (head, jaw, horns) by d
  function shiftHead(H, d) {
    const pt = q => [q[0] + d[0], q[1] + d[1]].concat(q.slice(2));
    const out = {};
    for (const k in H) {
      const v = H[k];
      if (k === 'jaw') out.jaw = { hinge: pt(v.hinge), pts: v.pts.map(pt), mouth: v.mouth.map(pt) };
      else if (['skull', 'cheekMass'].includes(k)) out[k] = [pt(v[0]), v[1], v[2]];
      else if (['eye', 'eyeFar', 'nostril'].includes(k)) out[k] = pt(v);
      else if (['snout', 'ridge', 'brow', 'cheekbone', 'maskTop', 'maskSide'].includes(k)) out[k] = v ? v.map(pt) : v;
      else if (v) out[k] = v.map(a => a.map(pt));
      else out[k] = v;
    }
    return out;
  }
  // the lower-front (throat) side of a neck spline: plates and the gem sit here
  function neckFront(neck, k, rk) {
    const d = spline(neck, 3), out = [];
    for (let i = 0; i < d.length; i += 3) {
      const a = d[Math.max(0, i - 1)], b = d[Math.min(d.length - 1, i + 1)], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1;
      out.push([d[i][0] - dy / l * d[i][2] * k, d[i][1] + dx / l * d[i][2] * k, d[i][2] * rk]);
    }
    return out;
  }
  const NECK_A = [[23, -63, 10.6], [29.5, -75, 9.4], [36.5, -87, 8.4], [45, -94.5, 7.6], [54, -95, 7]];
  const ADULT = Object.assign({
    torso: [[-17, -41, 8.5], [-7, -41, 13.5], [6, -46, 15.5], [18, -55, 16], [26, -63, 12.5]],
    bulge: [[26, -54], [12, 13.5], -.45],
    farShoulder: [[32, -66], [9, 8], -.3],
    ventral: [[34, -64, 5], [35.5, -55, 7], [31, -44, 7.5], [20, -35, 6.5], [7, -29, 4.6]],
    spine: [[-22, -47], [-16, -52.5], [-10, -57], [-4, -60.5], [2, -63.5]],
    neck: NECK_A,
    // the open ribcage on the flank (forms 3, 4): centre, radii, angle
    cavity: { c: [7, -51.5], r: [11, 8.8], ang: -.28, ribs: 4, ribR: 1 },
    arm: { upper: [[25, -58.5, 6.8], [28, -50, 6], [29, -42, 5.2]], pts: [[29, -42, 5], [34, -38.5, 4.4], [39, -37, 3.8]], hand: [[42, -36.5], [4.8, 4], .3],
      claws: [[[44, -34.5, 1.7], [48.5, -31.5, 1.2], [50, -26.5, .45]], [[41, -33, 1.6], [44, -29, 1.1], [44, -24.5, .4]], [[46.5, -37, 1.5], [51.5, -36, 1], [53.5, -32, .35]]],
      spur: [[26.5, -46, 1.6], [22, -42.5, .4]] },
    farArm: { pts: [[34, -61, 5.4], [43, -50, 4.4], [51, -46.5, 3.3]], claws: [[[53, -46, 1.2], [57, -43.5, .8], [58, -39.5, .3]], [[51.5, -44, 1.1], [53.5, -40.5, .7], [53, -37, .3]]] },
    legNear: { thigh: [[-7, -31], [11.5, 13.5], .5], upper: [[-8, -36, 10], [-3, -26, 8.6], [5, -16.5, 5.8]], pts: [[5, -16.5, 5], [-4, -7, 3.8], [4, -2.6, 3.2]],
      toes: [[[5, -2.4, 2.5], [11, -1.6, 2], [14.5, -.6, .55]], [[3, -1.8, 2.4], [7, .5, 1.7], [9, 1, .5]], [[-.5, -1.6, 2.2], [-.5, 1, 1.4], [-2, 1.1, .5]]],
      spur: [[-5.5, -8, 2], [-10.5, -5, .5]], knee: [[5.5, -17, 2], [10, -21, .4]] },
    legFar: { thigh: [[15, -35], [8.5, 10], .5], upper: [[14, -39, 7.6], [19, -31, 6.4], [26, -23, 4.4]], pts: [[26, -23, 4.2], [19, -13, 3.4], [26, -7.2, 2.9]],
      toes: [[[27, -7.2, 2.1], [32, -6.6, 1.5], [35, -6, .45]], [[26, -6.8, 2], [29, -4.8, 1.3], [30.5, -4.4, .45]]], spur: null, knee: null },
    tail: [[-12, -34, 9.5], [-21, -27, 8.6], [-30, -21, 7.4], [-39, -17, 6.2], [-47, -15, 5.2], [-54, -15.5, 4.4], [-59, -18, 3.6], [-62, -22.5, 2.9], [-63, -28, 2.3], [-61.5, -33, 1.8], [-58.5, -36.5, 1.2]],
    wingNear: { root: [-3, -62], elbow: [-18, -91], wrist: [-37, -99], tips: [[-60, -98], [-63, -78], [-55, -59], [-40, -47]], trail: [-16, -45], r: [4.6, 3.6, 2.7],
      // burned-through rips: [centre, radius, seed, angle, stretch]; the 2nd and 4th break the trailing edge
      burns: [[[-49, -87], 3.2, 1.3, 2.75, 1.9], [[-54, -73], 3, 4.2, 2.2, 1.6], [[-31, -63], 2.9, 2.6, -.7, 1.5], [[-27.5, -48], 2.6, 5.7, .3, 1.7]] },
    // form 4: the far wing's arm runs hidden behind the neck and skull, the wrist surfaces right of
    // the skull (clear of the crown) and three fingers fan the membrane up and right of the head
    wingFar: { root: [29, -72], elbow: [50, -92], wrist: [81, -97], tips: [[86, -125], [104, -121], [113, -103]], trail: [94, -90], r: [4.6, 3.6, 2.5], lit: 0 },
    throat: [[38.6, -77.8], [5, 3.4], -1.08],
    crystals: [{ base: [1, -61.5], tip: [-4, -95], w: 7.8 }, { base: [-6.5, -57], tip: [-17, -84], w: 6.4 }, { base: [8.5, -65], tip: [11, -91], w: 5.8 }],
    tailFlame: [10, 24],
    club: { r: [3.8, 3.2], spikes: [[-150, 6], [175, 6.5], [135, 5.5], [-105, 5], [-40, 4.5], [55, 4]] },
  }, shiftHead(MONU_ADULT, [NECK_A[4][0] - NECK_END_M[0], NECK_A[4][1] - NECK_END_M[1]]));
  ADULT.neckVentral = neckFront(ADULT.neck, .55, .42).slice(1);

  // Juvenile (form 2): no wings, horn stubs, a shorter thicker neck, a bigger head, a small rib cavity.
  const MONU_JUV = {
    skull: [[51, -78], [10, 8.6], .3], snout: [[54, -77, 7.6], [61, -73, 6.6], [67, -68.5, 5.2], [70, -66, 4]],
    ridge: [[50, -84, 3], [58, -80.5, 2.6], [65, -74.5, 1.9], [68.5, -70.5, 1.3]],
    brow: [[45, -84.5, 3.4], [52.5, -85.5, 3.4], [59.5, -81.5, 2.3]],
    cheekMass: [[48.5, -72], [6.6, 5.2], .5],
    eye: [56.5, -78.5], eyeFar: [63, -81.5], nostril: [68.5, -69.5],
    cheek: [[[44, -75, 2.6], [38, -73, 1.4], [34, -72, .45]]],
    cheekbone: [[50, -74.5, 1.6], [55.5, -73.5, 1.4], [61, -72, 1]],
    jaw: { hinge: [48, -71], pts: [[47, -72, 5.6], [55, -64, 4.4], [62, -57.5, 3], [65, -55.5, 2]], mouth: [[49, -73], [70, -67.5], [64.5, -56.5], [50, -65]] },
    horns: null,
    nubs: [[[47, -84, 3.2], [43, -89.5, 2.2], [40, -92.5, .7]], [[53, -85.5, 2.6], [51, -91, 1.8], [48.5, -94, .6]]],
    crest: [[[44, -81, 1.8], [39, -84, 1], [36, -84, .4]]],
  };
  const NECK_J = [[22, -59, 10.8], [29, -70, 9.6], [36.5, -78.5, 8.8], [44, -81, 8.2]];
  const JUVENILE = Object.assign({}, ADULT, {
    torso: [[-17, -39, 8.5], [-7, -39, 13.5], [6, -43, 15], [17, -51, 15.5], [24, -58, 12.5]],
    bulge: [[22, -50], [11, 12.5], -.4],
    farShoulder: [[29, -61], [9, 8], -.3],
    ventral: [[31, -61, 5], [33, -51, 7.5], [29, -40, 8], [18, -31, 7], [6, -26, 5]],
    spine: [[-18, -46], [-11, -51], [-4, -55], [3, -58]],
    // wing buds: a bone arm and two finger stubs with a scrap of membrane on the back (part of the
    // body), the wings form 3 unfolds
    wingStub: { root: [-1, -57], elbow: [-8, -71], tips: [[-20, -74.5], [-17, -63.5]] },
    neck: NECK_J,
    cavity: { c: [5.5, -48.5], r: [8.2, 6.8], ang: -.3, ribs: 3, ribR: 1.05 },
    arm: { upper: [[21, -55, 7], [24, -46.5, 6.2], [25, -39.5, 5.6]], pts: [[25, -39.5, 5.4], [31, -36.5, 4.8], [36, -35, 4.2]], hand: [[39.5, -34], [5, 4.2], .3],
      claws: [[[42, -32, 1.7], [47, -29, 1.1], [48.5, -24, .5]], [[39, -30.5, 1.6], [42, -26, 1], [41.5, -22, .45]], [[45, -34.5, 1.5], [50, -33.5, .9], [52, -30, .4]]],
      spur: [[22.5, -43, 1.7], [18, -40, .45]] },
    farArm: { pts: [[33, -56, 5.6], [42, -45, 4.6], [50, -42, 3.4]], claws: [[[52, -41.5, 1.3], [56, -39, .8], [57, -35, .35]]] },
    legNear: Object.assign({}, ADULT.legNear, { knee: null }),
    wingNear: null, wingFar: null, throat: null, crystals: null, club: null,
    tail: [[-12, -32, 9.5], [-21, -25, 8.6], [-30, -19, 7.4], [-39, -15, 6.2], [-47, -13, 5.2], [-54, -13.5, 4.4], [-59, -16, 3.6], [-62, -20.5, 2.9], [-63, -26, 2.3], [-61.5, -31, 1.8], [-58.5, -34.5, 1.3]],
    tailFlame: [10, 21],
  }, shiftHead(MONU_JUV, [NECK_J[3][0] - 45, NECK_J[3][1] + 78]));
  JUVENILE.neckVentral = neckFront(JUVENILE.neck, .55, .42).slice(1);

  // Salamander (form 1): slim, low hips, a long tail, a broad flat head with a bone mask, rib tips.
  const SALAMANDER = Object.assign({}, ADULT, {
    torso: [[-15, -33, 7], [-6, -33, 11], [6, -39, 12], [16, -47, 12], [23, -54, 9.5]],
    bulge: [[19, -47], [9.5, 10.5], -.5],
    farShoulder: [[27, -57], [7, 6.5], -.3],
    ventral: [[28, -59, 4.5], [30, -49, 6], [26, -39, 6.5], [17, -30, 5.5], [7, -25, 4]],
    spine: [[-12, -39], [-6, -43], [0, -46.5], [6, -49]],
    neck: [[21, -55, 8.6], [28, -65, 7.8], [35, -72, 7.4], [41, -74, 7.2]],
    skull: [[47, -75], [10.4, 7.4], .2], snout: [[50, -75, 7], [57, -72, 6.4], [62.5, -68.5, 5], [65, -66.5, 3.8]],
    ridge: [[46, -80.5, 2.8], [54, -78, 2.5], [61, -73, 1.8]],
    brow: [[42, -80.5, 2.9], [49.5, -81.5, 2.9], [55, -78, 2]],
    cheekMass: [[44, -69], [6.6, 5], .4],
    eye: [52.5, -76.5], eyeFar: [59, -79], nostril: [63.5, -69.5],
    cheek: [], cheekbone: [[46, -70.5, 1.6], [52, -70, 1.4], [57, -68.5, 1]],
    jaw: { hinge: [41, -70], pts: [[41, -71, 5.8], [50, -64.5, 5], [59, -59.5, 3.6], [62, -58, 2.4]], mouth: [[42, -72], [65, -67], [61.5, -59], [43, -65]] },
    horns: null, nubs: null, crest: [], crown: null,
    warts: [[44, -82.5, 1.7], [49.5, -83.5, 1.5], [39.5, -80, 1.4]],
    // a narrow glowing tear on the flank with three rib ends across it
    cavity: { c: [5, -43.5], r: [7.4, 4], ang: -.4, ribs: 3, ribR: 1.25 },
    arm: { upper: [[16, -51, 6.6], [20, -44, 5.6], [23, -37.5, 4.6]], pts: [[23, -37.5, 4.4], [28.5, -35, 3.8], [32.5, -34, 3.4]], hand: [[35, -33.5], [4, 3.4], .3],
      claws: [[[36.5, -32, 1.4], [40, -29.5, .9], [41, -26, .4]], [[34.5, -31, 1.3], [36.5, -27.5, .8], [36, -24.5, .35]], [[38.5, -34, 1.2], [42.5, -33.5, .7], [44, -30.5, .3]]], spur: null },
    farArm: { pts: [[29, -51, 4.2], [37, -42, 3.4], [44, -40, 2.6]], claws: [[[46, -39.5, 1.1], [49, -37.5, .7], [50, -34.5, .3]]] },
    legNear: { thigh: [[-5, -26], [9, 10.5], .5], upper: [[-7, -29, 8], [-2, -21, 7], [6, -13.5, 4.6]], pts: [[6, -13.5, 4.4], [-3, -6, 3.4], [4, -2, 3]],
      toes: [[[5, -2, 2.1], [10.5, -1.4, 1.6], [13.5, -.5, .5]], [[3.5, -1.6, 2], [7, .5, 1.4], [8.5, 1, .45]], [[.5, -1.5, 1.8], [.5, 1, 1.2], [-1, 1.1, .45]]], spur: null, knee: null },
    legFar: { thigh: [[12, -29], [7, 8], .5], upper: [[11, -33, 6.4], [16, -26, 5.4], [23, -18, 4]], pts: [[23, -18, 3.8], [15, -10, 3.1], [22, -6, 2.6]],
      toes: [[[23, -6, 1.8], [27.5, -5.4, 1.3], [30, -5, .4]], [[22, -5.6, 1.7], [24.5, -3.8, 1.1], [25.5, -3.4, .4]]], spur: null, knee: null },
    tail: [[-11, -28, 8.4], [-21, -22, 7.6], [-31, -17, 6.6], [-41, -13.5, 5.6], [-51, -12, 4.8], [-60, -12.5, 4], [-67, -15, 3.3], [-71, -19.5, 2.7], [-72.5, -25, 2.1], [-71, -30.5, 1.6], [-67.5, -34, 1.2]],
    wingNear: null, wingFar: null, throat: null, crystals: null, club: null,
    tailFlame: [11, 22],
  });
  SALAMANDER.neckVentral = neckFront(SALAMANDER.neck, .55, .42).slice(1);

  // The adult skull mask carried onto the younger heads: the similarity that takes the adult's eye and
  // snout tip onto theirs (so the bone plate sits the same way on every skull).
  function mapMask(pts, a0, a1, b0, b1) {
    const ax = a1[0] - a0[0], ay = a1[1] - a0[1], bx = b1[0] - b0[0], by = b1[1] - b0[1], d = ax * ax + ay * ay;
    const re = (bx * ax + by * ay) / d, im = (by * ax - bx * ay) / d;
    return pts.map(([x, y]) => { const u = x - a0[0], w = y - a0[1]; return [b0[0] + u * re - w * im, b0[1] + u * im + w * re]; });
  }
  for (const [G, H] of [[SALAMANDER, SALAMANDER], [JUVENILE, JUVENILE]]) {
    const a0 = MONU_ADULT.eye, a1 = MONU_ADULT.snout[MONU_ADULT.snout.length - 1], b0 = H.eye, b1 = H.snout[H.snout.length - 1];
    G.maskTop = mapMask(MONU_ADULT.maskTop, a0, a1, b0, b1);
    G.maskSide = mapMask(MONU_ADULT.maskSide, a0, a1, b0, b1);
  }

  // The head, jaw, horns and crown scaled around the head pivot (the neck's end).
  function scaleHead(G, k) {
    const c = G.neck[G.neck.length - 1];
    const pt = q => [c[0] + (q[0] - c[0]) * k, c[1] + (q[1] - c[1]) * k].concat(q.length > 2 ? [q[2] * k] : []);
    const ell = e => [pt(e[0]), e[1].map(r => r * k), e[2]];
    const out = Object.assign({}, G, { skull: ell(G.skull), cheekMass: ell(G.cheekMass), eye: pt(G.eye), eyeFar: pt(G.eyeFar), nostril: pt(G.nostril) });
    for (const key of ['snout', 'ridge', 'brow', 'cheekbone', 'maskTop', 'maskSide']) out[key] = G[key] ? G[key].map(pt) : G[key];
    for (const key of ['cheek', 'crest', 'horns', 'nubs', 'crown']) out[key] = G[key] ? G[key].map(a => a.map(pt)) : G[key];
    out.jaw = { hinge: pt(G.jaw.hinge), pts: G.jaw.pts.map(pt), mouth: G.jaw.mouth.map(pt) };
    return out;
  }

  // ---------- the four forms: the DRAKE palettes of hell_monsters.js, widened to 4-5 tones ----------
  const BONE4 = [MUD, TAN, BONE, WHITE], GOLD4 = [BROWN, BORA, YEL, WHITE];
  const FORM = {
    1: {
      name: 'Salamander', G: SALAMANDER, s: .52, spineK: .55,
      // dark lava stone (COAL, STONE, a derived deep brown, the DRAKE brown on the lit planes): the
      // glowing cracks and the magma belly are the bright parts; the ground light only on the outline
      hide: [COAL, STONE, BROWN0, BROWN], hideFar: [SOOT, COAL, STONE, BROWN0], occ: SOOT0, belly: [BROWN0, BROWN, BORA, ORA],
      bone: BONE4, skull: BONE4, brow: BONE4, mask: [MUD, TAN, TAN, BONE], rim: BORA, bellyRim: ORA, rim2: 1, gamma: 1.2, spots: [YEL, ORA], crack: [ORA, YEL, WHITE], crackN: 7, crackParts: 2, coreSeams: 2,
      mouth: [PLUM0, MAROON, CRIM, ORA, YEL], eye: [ORA, YEL, WHITE], socket: PIT, fire: FIRE, scales: false, drool: [RED, ORA, YEL],
      fangs: [[.5, 3.6]],
      core: [WHITE, YEL, ORA, RED], rib: { ramp: [TAN, BONE, WHITE, WHITE], amb: .3 }, coreRing: [BROWN0, RED],
    },
    2: {
      name: 'Jungdrache', G: JUVENILE, s: .63, spineK: .8,
      hide: [CRIM0, MAROON, CRIM, RED, ORA], hideFar: [PLUM0, CRIM0, MAROON, CRIM], belly: [BROWN, BORA, ORA, YEL],
      bone: BONE4, skull: BONE4, brow: BONE4, mask: [MUD, TAN, TAN, BONE], rim: 2, rim2: 1, gamma: 1.2, crack: [ORA, YEL, WHITE], crackN: 3, crackParts: 0, bellyGlow: .4, occ: PLUM0, stub: { mem: [CRIM0, MAROON], edge: RED },
      mouth: [PLUM0, MAROON, CRIM, ORA, YEL], eye: [ORA, YEL, WHITE], socket: PIT, fire: FIRE, scales: true, drool: [RED, ORA, YEL],
      fangs: [[.42, 4.6], [.82, 3]],
      core: [WHITE, YEL, ORA, RED], rib: { ramp: [MUD, TAN, BONE, WHITE], amb: .25 }, coreRing: [CRIM0, RED],
    },
    3: {
      name: 'Glutdrache', G: scaleHead(ADULT, 1.2), s: .76,
      // PLUM is the deepest body tone; PLUM0 (the floor's own value) only for 1 px contact shadows
      hide: [PLUM, MAROON, CRIM, RED], hideFar: [PLUM, PLUM, MAROON, CRIM], occ: PLUM0, belly: [BROWN, BORA, ORA, YEL],
      bone: [STONE, MUD, TAN, BONE], skull: BONE4, brow: BONE4, mask: [MUD, TAN, TAN, BONE], rim: BORA, bellyRim: ORA, rim2: 1, gamma: 1.15, crack: [ORA, YEL, WHITE], crackN: 2, crackParts: 1, coreSeams: 3, bellyGlow: .5, noBelly: true,
      wing: [PLUM, MAROON, MAROON, CRIM], wingEdge: RED, vein: CRIM,
      // the far wing rises up and back behind the shoulders (a V with the near wing), well clear of the skull
      wingFarG: { root: [18, -66], elbow: [15, -95], wrist: [4, -111], tips: [[-6, -124], [-20, -119], [-27, -105]], trail: [-12, -88], r: [3.6, 2.8, 2.2], cols: ['lit', 'base', 'lit'], trailRoot: true, clawDir: [2, -5] },
      farWing: { lit: CRIM0, base: PLUM0, edge: RED, bone: MAROON, finger: MUD, claw: TAN },
      burn: [ORA, YEL], burnK: 1.3, finger: { ramp: [MUD, TAN, BONE, WHITE], amb: .2 },
      gland: [MAROON, BORA, ORA, YEL, WHITE], bezel: [MUD, TAN, BONE], mouth: [PLUM0, MAROON, CRIM, ORA, YEL], eye: [YEL, WHITE, WHITE], eyeHalo: RED, socket: PIT, fire: FIRE, scales: true,
      drool: [RED, ORA, YEL], fangs: [[.38, 5.8], [.78, 4]],
      core: [WHITE, YEL, ORA, RED], rib: { ramp: [STONE, MUD, TAN, BONE], amb: .2 }, ribs: 3, ribK: 1.15, coreRing: [PLUM0, RED],
      club: BONE4,
    },
    4: {
      name: 'Obsidianform', G: scaleHead(ADULT, 1.22), s: 1,
      // SOOT0 only for contact shadows; the claw arm and the far leg are COAL volumes with a STONE plane
      hide: [SOOT, COAL, COAL, STONE, MUD], hideFar: [SOOT, SOOT, COAL, COAL], occ: SOOT0, limb: [COAL, COAL, STONE, STONE, MUD], limbFar: [SOOT, COAL, COAL, STONE],
      belly: [PURP0, PURP, MAG, VIO],
      bone: GOLD4, skull: [COAL, STONE, MUD, GLOSS], brow: GOLD4, browK: .62, mask: [MUD, GLOSS, GLOSS, BONE], rim: VIOD, rimFar: INDIGO, rim2: 1, gamma: 1, gloss: GLOSS,
      crack: [VIOD, VIO, LILAC], crackN: 0, crackParts: 0, coreSeams: 4, bellyGlow: .45, noBelly: true,
      wing: [INDIGO0, INDIGO, PURP, MAG], wingEdge: VIO, vein: VIOD,
      farWing: { lit: INDIGO, base: INDIGO0, edge: VIO, bone: COAL, finger: STONE, claw: BORA },
      burn: [VIO, LILAC], finger: { ramp: [SOOT, STONE, MUD, GLOSS], amb: .2 },
      gland: [PURP, MAG, PINK, LILAC, WHITE], bezel: [COAL, STONE, YEL], mouth: [PURP0, PURP, MAG, VIO, LILAC], eye: [VIO, LILAC, WHITE], eyeHalo: MAG, socket: PIT, fire: VOIDFIRE, scales: false,
      crystal: [INDIGO, VIOD, VIO, LILAC, WHITE], tusks: true, drool: [VIOD, VIO, LILAC], fangs: [[.38, 7], [.78, 4.6]],
      core: [WHITE, LILAC, VIO, VIOD], rib: { ramp: [SOOT, COAL, STONE], amb: .15, edgeL: BORA }, ribs: 3, ribK: 1.45, coreRing: [PURP0, VIOD],
      club: GOLD4, crownOn: true,
    },
  };
  const TAIL_PART = [0, 1, 1, 2, 2, 2, 2, 3, 4, 5, 5];

  function scaleTone(c, i, n) {
    if (i < 2 || i >= n - 1) return 0;
    const band = Math.floor(c.y / 4), sx = (c.x + (band % 2) * 3) % 6, sy = c.y % 4;
    return (sy === 3 && sx >= 1 && sx <= 3) ? -1 : 0;
  }
  const plateTone = (c) => ((c.tex.along || 0) % 3 < 1 ? -1 : 0) + ((c.tex.off || 0) > .82 ? -1 : 0);

  function looks(p) {
    const F = FORM[p];
    const mk = (ramp, o) => Object.assign({ ramp }, o || {});
    const hide = mk(F.hide, { rim: F.rim, rim2: F.rim2, tone: F.scales ? scaleTone : null, gamma: F.gamma || 1.2, amb: .12, spec: F.gloss, specT: .975, occCol: F.occ });
    const hideFar = mk(F.hideFar, { rim: F.rimFar || (typeof F.rim === 'number' ? 1 : F.rim), amb: .1, gamma: F.gamma || 1.2, occCol: F.occ });
    const limb = F.limb ? mk(F.limb, { rim: F.rim, rim2: F.rim2, gamma: F.gamma || 1.2, amb: .12, occCol: F.occ }) : hide;
    const limbFar = F.limbFar ? mk(F.limbFar, { rim: F.rimFar || F.rim, amb: .1, gamma: F.gamma || 1.2, occCol: F.occ }) : hideFar;
    const belly = mk(F.belly, { rim: F.bellyRim || (typeof F.rim === 'number' ? 1 : F.rim), tone: plateTone, amb: F.bellyGlow || .3 });
    const mask = F.mask ? mk(F.mask, { amb: .2, gamma: 1 }) : null;
    const bone = mk(F.bone, { amb: .2, spec: F.bone[3], specT: .95 });
    const boneFar = mk(F.bone.slice(0, 3), { amb: .08 });
    const skull = mk(F.skull, { amb: .22, rim2: p === 4 ? GLOSS : null, spec: p === 4 ? GLOSS : F.skull[3], specT: .95 });
    const brow = mk(F.brow, { amb: .2, spec: F.brow[3], specT: .95 });
    return { F, hide, hideFar, limb, limbFar, belly, bone, boneFar, skull, brow, mask };
  }

  /**
   * Draws form p (1-4) in its rest pose into Painter P, every draw call tagged with its rig part and
   * every pivot and point recorded (same ids as hell_monsters.js drake()). ox: the x of the skeleton's
   * origin in source px (the origin row is the frame's bottom row).
   */
  function drawDrake(P, p, ox) {
    const F = FORM[p], G = F.G, s = F.s, oy = P.h - 1;
    const T = { s, ox, oy }, X = (x, y) => [ox + x * s, oy + y * s];
    const LK = looks(p), f = P.f;
    const J = (name, at) => { const [x, y] = X(at[0], at[1]); P.joint(name, x, y); };
    const sculpt = (name, fn) => { P.part(name); const S = new Sculpt(P, T); fn(S); return S; };
    const v = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
    const dark = S => new Set(S.P.keep() ? [LK.hide.ramp[0], LK.hide.ramp[1], LK.hide.ramp[2]] : []);

    // ----- far wing (behind everything): cooler and darker, a few broad flat planes, bare finger
    // bones from one wrist, a single lit edge along the top -----
    const WF = F.wingFarG || G.wingFar;
    if (WF) {
      const S = sculpt('wing_far', S => farWing(S, WF, F.farWing));
      J('wing_far', WF.root);
      S.flush();
    }

    // ----- tail: ten steps in five parts, a spiked club on the tip (forms 3, 4), then the flame -----
    const tailDense = spline(G.tail, 4);
    for (let part = 1; part <= 5; part++) {
      const steps = []; for (let k = 1; k <= 10; k++) if (TAIL_PART[k] === part) steps.push(k);
      const a = (steps[0] - 1) * 4, b = steps[steps.length - 1] * 4, seg = tailDense.slice(a, b + 1);
      const S = sculpt('tail_' + part, S => {
        S.tube(seg, LK.hide, { smooth: false, minR: .7 });
        S.band(seg.map(q => [q[0] + .15 * q[2], q[1] + .6 * q[2], q[2] * .45]), LK.belly, { only: [LK.hide] });
        if (p >= 2) for (let i = 2; i < seg.length - 1; i += (p >= 3 ? 3 : 4)) {
          const q = seg[i], q2 = seg[Math.min(seg.length - 1, i + 1)], dx = q2[0] - q[0], dy = q2[1] - q[1], l = Math.hypot(dx, dy) || 1, sg = dx > 0 ? 1 : -1, nx = dy / l * sg, ny = -dx / l * sg;
          const top = [q[0] + nx * q[2] * .8, q[1] + ny * q[2] * .8], h = Math.max(1.4, q[2] * (p >= 3 ? .9 : .65));
          S.tube([[top[0], top[1], Math.max(.7, q[2] * .34), 2], [top[0] + nx * h - dx / l * h * .7, top[1] + ny * h - dy / l * h * .7, .35, 2]], LK.bone, { smooth: false, z: q[2] });
        }
        if (part === 5 && G.club && F.club) club(S, G, F, LK);
      });
      const [jx, jy] = X(G.tail[steps[0] - 1][0], G.tail[steps[0] - 1][1]);
      P.joint('tail_' + part, jx + .5, jy + .5);
      S.flush();
      if (F.crack && F.crackParts && part <= 2) cracks(S, 50 + part, 1, 6, F.crack, { cols: dark(S) });
      if (F.spots && part <= 2) spots(S, 60 + part, F.spots, 1);
    }
    const tip = G.tail[10], [tx, ty] = X(tip[0], tip[1]);
    P.joint('tail_tip', tx + .5, ty + .5);
    P.part('tail_flame').joint('tail_flame', tx + .5, ty + .5);
    const fw = Math.max(4, Math.round(G.tailFlame[0] * s)), fh = Math.max(6, Math.round(G.tailFlame[1] * s));
    P.flame(tx - Math.round(fw / 2) + 1, ty + 1, fw, fh, { seed: 3, pal: F.fire, front: true, lean: -1 });
    P.flame(tx - Math.round(fw / 4), ty, Math.max(2, Math.round(fw / 2)), Math.round(fh * .62), { seed: 8, pal: F.fire, front: true, sparks: false });

    // ----- far hind leg -----
    sculpt('leg_far', S => leg(S, G.legFar, LK.limbFar, LK.boneFar)).flush();
    J('leg_far', [G.legFar.upper[0][0], G.legFar.upper[0][1] + 1]);

    // ----- body: far arm and far shoulder behind, the trunk, the pectoral bulge, the ribcage -----
    const B = sculpt('body', S => {
      if (G.farArm) { S.tube(G.farArm.pts.map(q => [q[0], q[1], q[2], -12]), LK.limbFar, { smooth: false }); for (const cl of G.farArm.claws) S.tube(cl.map(q => [q[0], q[1], q[2], -10]), LK.boneFar); }
      if (G.farShoulder) S.ell(G.farShoulder[0], G.farShoulder[1], LK.hideFar, { ang: G.farShoulder[2], z: -8 });
      S.tube(G.torso, LK.hide, { steps: 6 });
      S.ell(G.bulge[0], G.bulge[1], LK.hide, { ang: G.bulge[2], z: 6, dz: 7 });
      if (!F.noBelly) S.band(G.ventral, LK.belly, { only: [LK.hide] });
      const sk = F.spineK || 1;
      if (G.wingStub && F.stub) {
        const w = G.wingStub;
        S.flat([w.root, w.elbow, w.tips[0], v(w.tips[0], w.tips[1], .5).map((q, i) => q + (i ? -1.2 : 1.6)), w.tips[1]], { ramp: F.stub.mem, amb: .3, edgeTop: F.stub.edge }, [-.3, -.5, .8], { z: 15 });
        S.tube([[...w.root, 2.2, 16], [...w.elbow, 1.6, 16]], LK.bone, { smooth: false });
        for (const t of w.tips) S.tube([[...w.elbow, 1.3, 17], [...t, .45, 17]], LK.bone, { smooth: false });
      }
      for (const [x, y] of G.spine) S.tube([[x, y, 2.5 * Math.max(.8, sk), 14], [x - 5.5 * sk, y - 7 * sk, .5, 14]], LK.bone, { smooth: false });
    });
    J('body', G.torso[1]);
    B.flush();
    if (F.crack) cracks(B, 7, F.crackN, 9, F.crack, { cols: dark(B) });
    if (F.spots) spots(B, 9, F.spots, 3);
    if (G.cavity && F.core) ribcage(P, B, G, F, T, X, s, f);
    J('core', G.cavity.c);

    // ----- near hind leg -----
    const LN = sculpt('leg_near', S => leg(S, G.legNear, LK.hide, LK.bone));
    J('leg_near', [G.legNear.upper[0][0] + 1, G.legNear.upper[0][1] + 1]);
    LN.flush();
    if (F.crack && F.crackParts) cracks(LN, 21, F.crackParts, 7, F.crack, { cols: dark(LN) });
    if (F.spots) spots(LN, 23, F.spots, 2);

    // ----- near wing: spread wide, torn and burned, finger bones bare -----
    if (G.wingNear) {
      // the rips scale up in the smaller form 3, so they still read as holes (the outline eats 1 px)
      const burnsN = (G.wingNear.burns || []).map(h => [h[0], h[1] * (F.burnK || 1)].concat(h.slice(2)));
      const S = sculpt('wing_near', S => {
        wing(S, G.wingNear, { membrane: { ramp: F.wing, amb: .16, edge: F.wingEdge }, bone: LK.hide, finger: F.finger, claw: LK.bone, tusks: F.tusks });
        for (const h of burnsN) S.cutRag(h);
      });
      J('wing_near', G.wingNear.root);
      S.flush(); wingVeins(S, G.wingNear, F.vein); burnRings(S, burnsN, F.burn);
    }

    // ----- neck: the S-curve rises from the chest, plates on its throat side, spikes along the top -----
    const nk = G.neck, N0 = nk[0], NE = nk[nk.length - 1];
    const NS = sculpt('neck', S => {
      S.tube(nk, LK.hide, { steps: 6 });
      S.band(G.neckVentral, LK.belly, { only: [LK.hide] });
      const dense = spline(nk, 4);
      if (p >= 2) for (let i = 3; i < dense.length - 3; i += (p >= 3 ? 3 : 4)) {
        const q = dense[i], q2 = dense[i + 1], dx = q2[0] - q[0], dy = q2[1] - q[1], l = Math.hypot(dx, dy) || 1, nx = dy / l, ny = -dx / l;
        const top = [q[0] + nx * q[2] * .78, q[1] + ny * q[2] * .78], h = q[2] * (p >= 3 ? .75 : .5);
        S.tube([[top[0], top[1], Math.max(.8, q[2] * .26), 3], [top[0] + nx * h - dx / l * h * .8, top[1] + ny * h - dy / l * h * .8, .35, 3]], LK.bone, { smooth: false, z: q[2] });
      }
    });
    J('neck', [N0[0], N0[1]]); J('head', [NE[0], NE[1]]);
    J('throat_at', G.throat ? G.throat[0] : v(G.neckVentral[1], G.neckVentral[2], .4));
    NS.flush();
    if (F.crack && F.crackParts > 1) cracks(NS, 31, 1, 7, F.crack, { cols: dark(NS) });
    if (F.spots) spots(NS, 33, F.spots, 1);

    // ----- void crystals (form 4): three tall shards from the upper back -----
    if (G.crystals && F.crystal) G.crystals.forEach((cr, i) => {
      const id = 'crystal_' + (i + 1);
      const S = sculpt(id, S => crystal(S, cr, F.crystal));
      J(id, cr.base);
      S.flush();
      const t = v(cr.base, cr.tip, .8), [gx, gy] = X(t[0], t[1]);
      P.glow(gx, gy, WHITE).glow(gx, gy + 1, LILAC).glow(gx - 1, gy + 1, VIO);
    });

    // ----- near arm: hangs from the front of the chest, claws reaching for the hero -----
    const A = G.arm;
    const AS = sculpt('arm', S => {
      S.tube(A.upper.map(q => [q[0], q[1], q[2], 10]), LK.limb, { dz: .8 });
      S.tube(A.pts.map(q => [q[0], q[1], q[2], 8]), LK.limb, { smooth: false });
      S.ell(A.hand[0], A.hand[1], LK.limb, { ang: A.hand[2], z: 9 });
      for (const cl of A.claws) S.tube(cl.map(q => [q[0], q[1], q[2], 10]), LK.bone);
      if (A.spur && p >= 2) S.tube(A.spur.map(q => [q[0], q[1], q[2], 11]), LK.bone, { smooth: false });
    });
    J('arm', [A.upper[0][0] + 1, A.upper[0][1] + 2]);
    J('hand', A.hand[0]);
    AS.flush();
    if (F.crack && F.crackParts > 1) cracks(AS, 41, 1, 7, F.crack, { cols: dark(AS) });
    if (F.spots) spots(AS, 43, F.spots, 1);

    // ----- throat gem (forms 3, 4): the weak spot, a faceted glowing gland on the neck's front -----
    if (G.throat && F.gland) {
      const g = F.gland;
      // a bezel collar (its lit upper rim gold or bone), the gem in two flat facets split by one dark
      // facet line, a 2 px highlight on the lit facet
      const S = sculpt('throat', S => {
        S.ell(G.throat[0], [G.throat[1][0] + 1.3, G.throat[1][1] + 1.3], { ramp: F.bezel.slice(0, 2), amb: .3, edgeTop: F.bezel[2], edgeLeft: true }, { ang: G.throat[2], z: 11 });
        S.ell(G.throat[0], G.throat[1], { ramp: [g[1], g[2]], amb: 0, gain: 1e-9, flatShade: true, tone: c => (c.tex.u * .55 + c.tex.v * .85 < -.05 ? 1 : 0) }, { ang: G.throat[2], z: 13 });
      });
      J('throat', G.throat[0]);
      S.flush();
      const [gx, gy] = X(G.throat[0][0], G.throat[0][1]), ca = Math.cos(G.throat[2]), sa = Math.sin(G.throat[2]), rx = G.throat[1][0] * s;
      // the facet line runs across the gem's long axis
      for (let k = -Math.floor(rx * .8); k <= Math.floor(rx * .8); k++) S.dot(gx + ca * k + sa * .5, gy + sa * k - ca * .5 + 1, g[0]);
      P.glow(gx - Math.round(rx * .35), gy - 1, g[4]).glow(gx - Math.round(rx * .35) + 1, gy - 1, g[3]);
    }

    // ----- jaw: hangs open, the glowing inside of the mouth rides on it, drool drips from it -----
    const JW = G.jaw;
    const JS = sculpt('jaw', S => {
      const a = X(JW.hinge[0], JW.hinge[1]), mo = v(JW.mouth[1], JW.mouth[2], .5), b = X(mo[0], mo[1]), L0 = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
      S.flat(JW.mouth, { ramp: F.mouth, amb: .2, tone: (c) => (c.tex.d < .3 ? 2 : c.tex.d < .5 ? 1 : c.tex.d < .75 ? 0 : -1) }, [0, 0, 1], {
        z: -2, tex: (x, y) => ({ d: Math.hypot(x - a[0], y - a[1]) / L0 }) });
      S.tube(JW.pts.map(q => [q[0], q[1], q[2], 4]), LK.hide, { smooth: true });
      // the jaw bone shows along its lower edge (a skull's mandible)
      const n = JW.pts.length;
      S.tube(JW.pts.slice(0, n - 1).map(q => [q[0] + .3 * q[2] * .2, q[1] + q[2] * .55, q[2] * .32, 6]), LK.skull, { smooth: true });
    });
    J('jaw', JW.hinge);
    J('mouth', v(JW.mouth[1], JW.mouth[2], .5));
    JS.flush();
    {
      // lower teeth stand on the jaw's top edge, the front ones long tusks
      const n = p >= 3 ? 5 : p === 2 ? 4 : 3, a = JW.pts[0], b = JW.pts[JW.pts.length - 1], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), ux = dy / l, uy = -dx / l;
      for (let k = 1; k <= n; k++) {
        const t = .3 + k / (n + 1) * .65, q = v(a, b, t), r = (a[2] + (b[2] - a[2]) * t) * s, [x, y] = X(q[0], q[1]);
        const tx = x + ux * (r + .3), ty = y + uy * (r + .3);
        JS.P.dot(tx, ty, WHITE);
        if (k === n - 1 && p >= 2) { JS.P.dot(tx, ty - 1, WHITE).dot(tx, ty - 2, BONE); if (p >= 3) JS.P.dot(tx, ty - 3, BONE); }
        if (k === 2 && p >= 3) JS.P.dot(tx, ty - 1, BONE);
      }
      // drool: lava or void hanging from the jaw's lower edge
      if (F.drool) {
        const d0 = v(a, b, .5), d1 = v(a, b, .82), r0 = (a[2] + (b[2] - a[2]) * .5) * s, r1 = (a[2] + (b[2] - a[2]) * .82) * s;
        const [x0, y0] = X(d0[0], d0[1]), [x1, y1] = X(d1[0], d1[1]);
        drip(JS.P, x0 - ux * r0, y0 - uy * r0 + 1, Math.round(2 + 3 * s), F.drool);
        if (p >= 2) drip(JS.P, x1 - ux * r1, y1 - uy * r1 + 1, Math.round(1 + 2 * s), F.drool);
      }
    }

    // ----- head: skull, a bone mask over snout and brow, cheek bone, a black socket with a hot eye -----
    const HS = sculpt('head', S => {
      S.ell(G.skull[0], G.skull[1], LK.hide, { ang: G.skull[2], z: 6 });
      S.ell(G.cheekMass[0], G.cheekMass[1], LK.hide, { ang: G.cheekMass[2], z: 9, dz: 4 });
      S.tube(G.snout.map(q => [q[0], q[1], q[2], 6]), LK.hide);
      if (G.maskTop && F.mask) {
        S.flat(G.maskTop, LK.mask, [-.25, -.85, .46], { z: 16 });
        S.flat(G.maskSide, LK.mask, [.35, .05, .94], { z: 16 });
      } else S.tube(G.ridge.map(q => [q[0], q[1] - q[2] * .2, q[2] * .78, 11]), LK.skull, { dz: .7 });
      const bk = F.browK || 1, bz = G.maskTop && F.mask ? 17 : 12;
      if (bk < 1) S.tube(G.brow.map(q => [q[0], q[1] + q[2] * .4, q[2] * .9, bz - 2]), LK.hide, { dz: .8 });
      S.tube(G.brow.map(q => [q[0], q[1] - q[2] * (1 - bk) * .5, q[2] * bk, bz]), LK.brow, { dz: .8 });
      if (G.cheekbone) S.tube(G.cheekbone.map(q => [q[0], q[1] + (p === 4 ? .6 : 0), q[2] * (p === 4 ? .7 : 1), p === 4 ? 17 : 12]), p === 4 ? LK.brow : LK.skull, { dz: .7 });
      for (const sp of G.cheek || []) S.tube(sp.map(q => [q[0], q[1], q[2], 6]), LK.bone);
      if (G.nubs) for (const nb of G.nubs) S.tube(nb.map(q => [q[0], q[1], q[2], 8]), LK.bone);
      if (G.warts) for (const w of G.warts) S.ell([w[0], w[1]], [w[2], w[2] * .85], LK.bone, { z: 10 });
      for (const cr of G.crest || []) S.tube(cr.map(q => [q[0], q[1], q[2], 9]), LK.bone);
    });
    HS.flush();
    // the socket: a black pit under the brow; the nasal pit
    {
      // tilted like a scowl: the inner (snout side) corner lower, its bottom edge one tone lighter
      const [ex, ey] = X(G.eye[0], G.eye[1]), rx = Math.max(2.2, 4 * s), ry = Math.max(1.3, 2.6 * s), a = .38, ca = Math.cos(a), sa = Math.sin(a);
      for (let y = Math.floor(ey - ry - 2); y <= Math.ceil(ey + ry + 2); y++) for (let x = Math.floor(ex - rx - 2); x <= Math.ceil(ex + rx + 2); x++) {
        const dx = x + .5 - ex, dy = y + .5 - ey, u = (dx * ca + dy * sa) / rx, w = (-dx * sa + dy * ca) / ry, q = u * u + w * w;
        if (q <= 1) HS.dot(x, y, F.socket);
        else if (q <= 1.6 && w > .2) HS.dot(x, y, F.hide[0]);
      }
      const [nx, ny] = X(G.nostril[0], G.nostril[1]);
      HS.dot(nx, ny, PIT).dot(nx + 1, ny, PIT).dot(nx, ny + 1, p >= 3 ? PIT : K);
      if (F.crack) HS.dot(nx - 1, ny, F.crack[0]);
    }
    {
      // upper teeth along the snout's lower edge, long fangs hanging over the jaw, drool from their tips
      const a = G.snout[0], b = G.snout[G.snout.length - 1], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), ux = -dy / l, uy = dx / l;
      const edge = t => { const q = v(a, b, t), r = (a[2] + (b[2] - a[2]) * t) * s, [x, y] = X(q[0], q[1]); return [x + ux * (r - .3), y + uy * (r - .3)]; };
      const n = p >= 3 ? 6 : p === 2 ? 5 : 3;
      for (let k = 1; k <= n; k++) { const [x, y] = edge(.12 + k / (n + 1) * .84); HS.P.dot(x, y + 1, WHITE); }
      F.fangs.forEach(([t, len], i) => {
        const [x, y] = edge(t), m = Math.max(2, Math.round(len * Math.max(.62, s)));
        for (let j = 0; j < m; j++) { HS.P.dot(x, y + 1 + j, j < m - 1 ? WHITE : BONE); if (i === 0 && p >= 3 && j < m - 2) HS.P.dot(x + 1, y + 1 + j, j < m - 3 ? BONE : TAN); }
        if (i === 0 && F.drool && p >= 2) drip(HS.P, x, y + 1 + m, Math.round(1 + 2 * s), F.drool);
      });
    }
    // the eye: a glowing slit deep in the socket, the far eye a glint past the snout ridge
    {
      const [ex, ey] = X(G.eye[0], G.eye[1]), e = F.eye, big = p >= 3;
      const px = p === 4
        ? [[0, 0, WHITE], [1, 0, WHITE], [0, 1, LILAC], [1, 1, LILAC], [-1, 0, VIO], [-1, 1, VIO], [2, 0, VIO], [2, 1, VIOD], [0, -1, VIO], [1, -1, VIO], [0, 2, VIOD], [1, 2, VIOD], [-2, 0, MAG], [3, 1, MAG]]
        : big
        ? [[-3, -1, e[0]], [-2, -1, e[1]], [-1, -1, e[1]], [-1, 0, e[1]], [0, 0, e[2]], [1, 0, e[2]], [2, 0, e[1]], [3, 1, e[0]], [0, 1, e[1]], [1, 1, e[1]], [-2, 0, e[0]], [-4, -1, F.eyeHalo], [2, 1, F.eyeHalo]]
        : p === 2 ? [[-2, -1, e[0]], [-1, 0, e[1]], [0, 0, e[2]], [1, 0, e[1]], [2, 1, e[0]], [0, 1, e[0]]]
          : [[-1, 0, e[1]], [0, 0, e[2]], [1, 0, e[1]]];
      for (const [dx, dy, c] of px) P.glow(ex + dx, ey + dy, c);
      const [fx, fy] = X(G.eyeFar[0], G.eyeFar[1]);
      P.glow(fx - 1, fy, e[0]).glow(fx, fy, e[1]);
      if (big) P.glow(fx + 1, fy - 1, e[0]);
    }
    if (F.crack && p >= 3) cracks(HS, 71, 1, 6, F.crack, { cols: dark(HS) });

    // ----- horns (forms 3, 4): devil horns; form 4 adds a gold crown of spikes on the brow -----
    if (G.horns) {
      const S = sculpt('horns', S => {
        S.tube(G.horns[1].map(q => [q[0], q[1], q[2], 2]), LK.boneFar, { steps: 6 });
        S.tube(G.horns[0].map(q => [q[0], q[1], q[2], 12]), LK.bone, { steps: 6 });
        if (F.crownOn && G.crown) for (const c of G.crown) S.tube(c.map(q => [q[0], q[1], q[2], 13]), LK.bone, { smooth: false });
      });
      J('horns', [G.horns[0][0][0] + 1, G.horns[0][0][1] + 1]);
      S.flush();
      const dense = spline(G.horns[0], 6);
      for (let i = 4; i < dense.length - 8; i += 4) {
        const q = dense[i], q2 = dense[i + 1], dx = q2[0] - q[0], dy = q2[1] - q[1], l = Math.hypot(dx, dy) || 1;
        S.line([q[0] + dy / l * q[2] * .9, q[1] - dx / l * q[2] * .9], [q[0] - dy / l * q[2] * .2, q[1] + dx / l * q[2] * .2], F.bone[0]);
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

  // A drip of glowing liquid hanging from (x, y), cols [dark, mid, hot]: one unbroken strand.
  function drip(P, x, y, len, cols) {
    x = Math.round(x); y = Math.round(y);
    for (let j = 0; j < len; j++) P.glow(x, y + j, j === 0 ? cols[2] : j < len - 1 ? cols[1] : cols[0]);
  }

  // The open ribcage: torn hide around a cavity, the core glowing inside (a white-hot heart that
  // fills most of it, so the light shows between the ribs), dark ribs that bow down from the spine over
  // it (sculpted and lit like everything else, form 4's obsidian with a gold lit edge), a one-step
  // darker cast shadow on the glow right of every rib, a clean torn lip (lit on its lower side, where
  // the core's light hits it), molten drips from the lower lip, seams running out of the lip.
  function ribcage(P, B, G, F, T, X, s, f) {
    if (!P.keep()) return;
    const cav = G.cavity, [cx, cy] = X(cav.c[0], cav.c[1]), rx = cav.r[0] * s, ry = cav.r[1] * s, ca = Math.cos(cav.ang), sa = Math.sin(cav.ang);
    const q = (x, y, g) => { const dx = x - cx, dy = y - cy, u = (dx * ca + dy * sa) / (rx + g), w = (-dx * sa + dy * ca) / (ry + g); return u * u + w * w; };
    const co = F.core, band = d => (d < .46 ? 0 : d < .66 ? 1 : d < .84 ? 2 : 3);
    const inCav = new Map();
    for (let y = Math.floor(cy - ry - 4); y <= Math.ceil(cy + ry + 4); y++) for (let x = Math.floor(cx - rx - 4); x <= Math.ceil(cx + rx + 4); x++) {
      if (!B.has(x, y)) continue;
      const q0 = q(x + .5, y + .5, 0), jag = (hash(x, y, 5) - .5) * 1.2;
      if (q0 <= 1) {
        const i = band(Math.sqrt(q(x + .5 + rx * .1, y + .5 + ry * .12, 0)));
        inCav.set(y * P.w + x, i);
        B.dot(x, y, co[i]);
      } else if (q(x + .5, y + .5, 1.3 + jag) <= 1) {
        // the lip: lit by the core on its lower inner rim, charred elsewhere
        const lower = (-(x + .5 - cx) * sa + (y + .5 - cy) * ca) > ry * .35, inner = q(x + .5, y + .5, .9) <= 1;
        B.dot(x, y, lower && inner ? F.coreRing[1] : F.coreRing[0]);
      }
    }
    const n = F.ribs || cav.ribs, R = new Sculpt(P, T), mat = F.rib;
    for (let i = 0; i < n; i++) {
      // ")"-bowed: from the spine (up, back) out toward the viewer and down to the sternum
      const t = n > 1 ? i / (n - 1) : .5, x0 = cav.c[0] - cav.r[0] * .62 + t * cav.r[0] * 1.22, c1 = cav.c[1];
      const lean = .42 - t * .1, rr = cav.ribR * (F.ribK || 1);
      R.tube([[x0 - cav.r[0] * lean, c1 - cav.r[1] * 1.28, rr * 1.15, 16], [x0 - cav.r[0] * .02, c1 - cav.r[1] * .55, rr * 1.05, 17],
        [x0 + cav.r[0] * .16, c1 + cav.r[1] * .25, rr * .95, 17], [x0 + cav.r[0] * (.02 + t * .08), c1 + cav.r[1] * 1.18, rr * .8, 16]], mat, { steps: 5, minR: .62 });
    }
    R.flush();
    const shadow = [];
    for (const c of R.m.values()) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const x = c.x + dx, y = c.y + dy, k = y * P.w + x;
      if (R.has(x, y) || !B.has(x, y)) continue;
      if (!inCav.has(k)) shadow.push([x, y, F.coreRing[0]]);
      else if (dx === 1) shadow.push([x, y, co[Math.min(3, inCav.get(k) + 1)]]);
    }
    for (const [x, y, c] of shadow) P.dot(x, y, c);
    // molten drips from the lower lip
    for (const [dx, len] of [[-.35, 2], [.15, 3], [.5, 2]]) drip(P, cx + dx * rx, cy + ry * .98 + 1, Math.round(len * s + 1), [co[3], co[2], co[1]]);
    // a few deliberate seams run out of the lip into the hide (the glow leaking through cracks)
    if (F.crack && F.coreSeams) {
      const R2 = rng(77);
      for (let k = 0; k < F.coreSeams; k++) {
        const an = cav.ang + Math.PI * (.25 + k * 1.9 / F.coreSeams) + (R2() - .5) * .4;
        let x = cx + Math.cos(an) * (rx + 1.6), y = cy + Math.sin(an) * (ry + 1.6), dir = an;
        const len = 3 + Math.floor(R2() * 3);
        for (let j = 0; j < len; j++) {
          const xi = Math.round(x), yi = Math.round(y);
          if (!B.inner(xi, yi) || inCav.has(yi * P.w + xi)) break;
          P.dot(xi, yi, j < 2 ? F.crack[1] : F.crack[0]);
          dir += (R2() - .5) * .7; x += Math.cos(dir); y += Math.sin(dir);
        }
      }
    }
  }
  // The spiked club at the tail tip (forms 3, 4).
  function club(S, G, F, LK) {
    const t = G.tail, a = t[9], b = t[10], c = [b[0] + (b[0] - a[0]) * -.15, b[1] + (b[1] - a[1]) * -.15], r = G.club.r;
    S.ell(c, r, LK.hide, { z: 3 });
    for (const [deg, len] of G.club.spikes) {
      const an = deg * Math.PI / 180, ux = Math.cos(an), uy = Math.sin(an), base = [c[0] + ux * r[0] * .7, c[1] + uy * r[1] * .7];
      S.tube([[base[0], base[1], 1.3, 5], [base[0] + ux * len * .55, base[1] + uy * len * .55, .8, 5], [base[0] + ux * len, base[1] + uy * len, .35, 5]], LK.bone, { smooth: false });
    }
  }

  function leg(S, g, hide, claw) {
    if (g.thigh) S.ell(g.thigh[0], g.thigh[1], hide, { ang: g.thigh[2], z: 7, dz: 6 });
    S.tube(g.upper.map(q => [q[0], q[1], q[2], 6]), hide, { dz: .8 });
    S.tube(g.pts.map(q => [q[0], q[1], q[2], 4]), hide, { smooth: false });
    if (g.spur) S.tube(g.spur.map(q => [q[0], q[1], q[2], 3]), claw, { smooth: false });
    if (g.knee) S.tube(g.knee.map(q => [q[0], q[1], q[2], 12]), claw, { smooth: false });
    for (const t of g.toes) {
      const n = t.length;
      S.tube(t.slice(0, n - 1).map(q => [q[0], q[1], q[2], 5]), hide, { smooth: false });
      S.tube([[...t[n - 2].slice(0, 2), t[n - 2][2] * .62, 6], [...t[n - 1].slice(0, 2), t[n - 1][2], 6]], claw, { smooth: false });
    }
  }
  // A wing: membrane panels between the finger bones (alternating normals read as pleats), the arm
  // bones in hide, the bare finger bones on top, a thumb claw, gold tusks in form 4.
  function wing(S, w, o) {
    const { root, elbow, wrist, tips, trail } = w;
    const sagEdge = (a, b, k) => { const out = []; for (let i = 1; i < 4; i++) { const t = i / 4, sag = Math.sin(Math.PI * t) * k, x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t; out.push([x + (wrist[0] - x) * sag, y + (wrist[1] - y) * sag]); } return out; };
    const bones = [[root, elbow], [elbow, wrist], ...tips.map(t => [wrist, t])];
    const { s, ox, oy } = S.T, B = bones.map(([a, b]) => [[ox + a[0] * s, oy + a[1] * s], [ox + b[0] * s, oy + b[1] * s]]);
    const boneDist = (x, y) => { let best = Infinity; for (const [a, b] of B) { const dx = b[0] - a[0], dy = b[1] - a[1], t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy || 1))); best = Math.min(best, Math.hypot(x - a[0] - dx * t, y - a[1] - dy * t)); } return best; };
    const mem = Object.assign({}, o.membrane, { tone: (c) => { const d = c.tex.d / Math.max(1, s * 4); return d < .5 ? 1 : d > 2.2 ? -1 : 0; } });
    const normals = o.far ? [[-.2, -.3, .93], [.35, .1, .93], [-.1, -.2, .97], [.3, .25, .9], [-.15, -.2, .96]] : [[-.45, -.4, .8], [.3, .05, .95], [-.35, -.3, .88], [.35, .15, .92], [-.1, -.1, .99]];
    const panels = [];
    for (let i = 0; i < tips.length - 1; i++) panels.push([wrist, tips[i], ...sagEdge(tips[i], tips[i + 1], .26), tips[i + 1]]);
    panels.push([wrist, tips[tips.length - 1], ...sagEdge(tips[tips.length - 1], trail, .16), trail, root, elbow]);
    panels.push([root, elbow, wrist, v2(elbow, wrist, .5, 0, 3), v2(root, elbow, .5, 3, 1)]);
    panels.forEach((poly, i) => S.flat(poly, mem, normals[i % normals.length], { z: 0, tex: (x, y) => ({ d: boneDist(x, y) }) }));
    const [r0, r1, r2] = w.r;
    S.tube([[...root, r0, 4], [...elbow, r1, 4]], o.bone, { smooth: false });
    S.tube([[...elbow, r1, 4], [...wrist, r2, 4]], o.bone, { smooth: false });
    const fin = o.finger || o.bone;
    tips.forEach((t, i) => {
      const m = v2(wrist, t, .5, (i - 1) * .8, -(i - 1) * .4);
      S.tube([[...wrist, r2 * .8, 3], [...m, r2 * .55, 3], [...t, .4, 3]], fin, { smooth: false });
      // a knuckle on each finger
      S.ell(m, [r2 * .62, r2 * .62], fin, { z: 4 });
    });
    S.ell(wrist, [r2 * 1.3, r2 * 1.2], o.bone, { z: 5 });
    S.tube([[wrist[0] - 1, wrist[1] - 1, r2 * .8, 6], [wrist[0] + 1.5, wrist[1] - 5.5, .5, 6]], o.claw, { smooth: false });
    S.tube([[elbow[0], elbow[1], r1 * .7, 6], [elbow[0] - 2.5, elbow[1] - 5, .45, 6]], o.claw, { smooth: false });
    if (o.tusks) for (const [a, b, len] of [[elbow, wrist, 6], [root, elbow, 5], [elbow, wrist, 4.5]]) {
      const at = len > 5 ? a : v2(a, b, .55, 0, 0), dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy), nx = dy / l, ny = -dx / l;
      S.tube([[at[0], at[1], 1.6, 7], [at[0] + nx * len * .6 - dx / l * len * .3, at[1] + ny * len * .6 - dy / l * len * .3, 1, 7], [at[0] + nx * len - dx / l * len * .75, at[1] + ny * len - dy / l * len * .75, .4, 7]], o.claw);
    }
  }
  // The far wing: two or three broad flat membrane planes (one lit, the rest in shade) between bare
  // finger bones that radiate from one wrist joint, the arm bones behind them; one lit edge runs along
  // the top of the whole wing (the planes, bones and fingers share it), no veins, pleats or holes.
  // w.panels: which finger gaps carry membrane (default all); w.lit: the lit plane's index.
  function farWing(S, w, o) {
    const { root, elbow, wrist, tips, trail } = w, n = tips.length;
    const sagEdge = (a, b, k) => { const out = []; for (let i = 1; i < 4; i++) { const t = i / 4, sag = Math.sin(Math.PI * t) * k, x = a[0] + (b[0] - a[0]) * t, y = a[1] + (b[1] - a[1]) * t; out.push([x + (wrist[0] - x) * sag, y + (wrist[1] - y) * sag]); } return out; };
    const mat = (ramp) => ({ ramp, flatShade: true, edgeTop: o.edge, amb: 1 });
    const planes = [];
    if (w.armPanel) planes.push([elbow, wrist, tips[0], ...sagEdge(tips[0], w.armPanel, .1), w.armPanel]);
    for (let i = 0; i < n - 1; i++) planes.push([wrist, tips[i], ...sagEdge(tips[i], tips[i + 1], .24), tips[i + 1]]);
    planes.push([wrist, tips[n - 1], ...sagEdge(tips[n - 1], trail, .14), trail, ...(w.trailRoot ? [root, elbow] : [])]);
    planes.forEach((poly, i) => S.flat(poly, mat([(w.cols || [])[i] === 'base' ? o.base : (w.cols || [])[i] === 'lit' || i === (w.lit || 0) ? o.lit : o.base]), [-.3, -.4, .87], { z: 0 }));
    const [r0, r1, r2] = w.r, bone = mat([o.bone]), fin = mat([o.finger]);
    S.tube([[...root, r0, 4], [...elbow, r1, 4]], bone, { smooth: false });
    S.tube([[...elbow, r1, 4], [...wrist, r2, 4]], bone, { smooth: false });
    tips.forEach(t => S.tube([[...wrist, r2 * .72, 3], [...v2(wrist, t, .55, 0, 0), r2 * .5, 3], [...t, .4, 3]], fin, { smooth: false }));
    S.ell(wrist, [r2 * 1.15, r2 * 1.05], bone, { z: 5 });
    if (o.claw) S.tube([[wrist[0], wrist[1] - .5, r2 * .7, 6], [wrist[0] + (w.clawDir || [1.5, -5])[0], wrist[1] + (w.clawDir || [1.5, -5])[1], .4, 6]], mat([o.claw]), { smooth: false });
  }
  const v2 = (a, b, t, dx, dy) => [a[0] + (b[0] - a[0]) * t + dx, a[1] + (b[1] - a[1]) * t + dy];
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
  // Burned-through rips: only the lower lip of each hole glows (a 1 px ember rim where the hole lies
  // right above the membrane, hottest under the hole's middle); the rest of the lip stays charred, and
  // the hole itself shows whatever lies behind the wing. cols: [ember, hottest].
  function burnRings(S, holes, cols) {
    if (!S.P.keep() || !holes || !S.holes) return;
    const w = S.P.w, H = S.holes;
    for (const c of S.m.values()) {
      if (!c.mat.edge) continue;
      const above = H.has((c.y - 1) * w + c.x);
      if (!above) continue;
      const hot = above && H.has((c.y - 2) * w + c.x) && H.has((c.y - 1) * w + c.x - 1) && H.has((c.y - 1) * w + c.x + 1);
      S.P.dot(c.x, c.y, hot ? cols[1] : cols[0]);
    }
  }
  function crystal(S, cr, ramp) {
    const { base, tip, w } = cr, dx = tip[0] - base[0], dy = tip[1] - base[1], l = Math.hypot(dx, dy), ux = dx / l, uy = dy / l, nx = -uy, ny = ux;
    const at = (t, k) => [base[0] + dx * t + nx * w * .5 * k, base[1] + dy * t + ny * w * .5 * k];
    const lit = { ramp: [ramp[1], ramp[1], ramp[2], ramp[2]], amb: .2, tone: c => (c.tex.k > .7 ? 1 : c.tex.k < .35 ? -1 : 0) };
    const dark = { ramp: [ramp[0], ramp[0], ramp[0], ramp[1]], amb: .1 };
    const kt = (x, y) => { const { s, ox, oy } = S.T, bx = ox + base[0] * s, by = oy + base[1] * s; return { k: ((x - bx) * ux + (y - by) * uy) / (l * s) }; };
    S.flat([at(-.05, -.75), at(.62, -1), at(1, 0), at(.6, .05), at(0, .05)], lit, [-.6, -.4, .7], { z: 2, tex: kt });
    S.flat([at(0, .05), at(.6, .05), at(1, 0), at(.6, 1), at(-.05, .7)], dark, [.6, .2, .78], { z: 2 });
    S.tube([[...at(.3, -.05), .5, 4], [...at(.9, -.02), .5, 4]], { ramp: [ramp[3], ramp[4]], amb: .9 }, { smooth: false });
  }
  function spots(S, seed, col, n) {
    if (!S.P.keep()) return;
    const R = rng(seed), cells = [...S.m.values()].filter(c => S.inner(c.x, c.y) && S.inner(c.x + 1, c.y) && S.inner(c.x, c.y + 1));
    for (let k = 0; k < n && cells.length; k++) {
      const c = cells[Math.floor(R() * cells.length)];
      S.P.dot(c.x, c.y, col[1]); S.P.dot(c.x + 1, c.y, col[0]); S.P.dot(c.x, c.y + 1, col[0]);
    }
  }

  // ---------- rig layout (the same ids for the same body part in every form) ----------
  // Every part's parent (body is the root): a child turns about its own pivot inside its parent's
  // frame, so it adds its parent's turn.
  const PARENT = {
    body: null, neck: 'body', head: 'neck', jaw: 'head', arm: 'body', leg_far: 'body', leg_near: 'body',
    tail_1: 'body', tail_2: 'tail_1', tail_3: 'tail_2', tail_4: 'tail_3', tail_5: 'tail_4', tail_flame: 'tail_5',
    wing_far: 'body', wing_near: 'body', throat: 'neck', horns: 'head',
    crystal_1: 'body', crystal_2: 'body', crystal_3: 'body', mouth_flame: 'jaw',
  };
  // Back to front, as the game stacks them. tail_2 is the highest tail part, so the joints it shares
  // with tail_1 and tail_3 are hit as tail_2 (a hit there cuts the tail in forms 1 and 2). The neck
  // lies in front of the body and the near wing (no seam on the chest: body/neck is SEAMLESS), behind
  // the arm and the throat gem; the jaw sits behind the head (the snout hides the inside of the mouth
  // until the jaw drops).
  const Z = {
    wing_far: 1, tail_5: 2, tail_4: 3, tail_3: 4, tail_1: 5, tail_2: 6, tail_flame: 7, leg_far: 8, body: 10,
    leg_near: 11, wing_near: 12, neck: 13, crystal_1: 14, crystal_2: 14, crystal_3: 14, arm: 15, throat: 16, jaw: 17, head: 18,
    horns: 19, mouth_flame: 20,
  };

  // ---------- rig contract (same as HM.renderDrakeRig) ----------
  const SIL = {};
  // the composed silhouette of form p's rest pose (all parts), for the outer-silhouette lighting
  function silhouette(p) {
    if (SIL[p]) return SIL[p];
    const F = fit(p), P = new HM.Painter(F.W, F.H, 0, null);
    drawDrake(P, p, F.ox);
    return (SIL[p] = P.solid.map(Boolean));
  }
  /** Form p (1-4): part = a part id renders only that part (its own outline), null all of them. */
  function renderRig(p, part, frame, skip) {
    const F = fit(p), sil = silhouette(p), P = new HM.Painter(F.W, F.H, frame || 0, part == null ? null : part);
    P.sil = sil;
    drawDrake(P, p, F.ox);
    return { w: F.W, h: F.H, px: P.finish(skip), solid: P.solid.map(Boolean), joints: P.joints, tags: P.tags };
  }
  // The frame: drawn once on a large canvas (all four flame frames), then cropped to the drawing with
  // 2 px to spare on the left, right and top (the outline and one free column); the feet stay on the
  // bottom row.
  function fit(p) {
    const F = FORM[p];
    if (F.W) return F;
    const BW = 440, BH = 300, O = 220;
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
  const SEAMLESS = [['body', 'neck'], ['neck', 'head'], ['body', 'tail_1'], ['tail_1', 'tail_2'], ['tail_2', 'tail_3'], ['tail_3', 'tail_4'], ['tail_4', 'tail_5']];
  const FLIPBOOK = new Set(['tail_flame', 'mouth_flame']);
  const cache = new Map();
  /** Every part isolated (with the export's seam rule), sorted by the rig's layers. */
  function parts(p, frame) {
    const key = p + ':' + (frame || 0);
    if (cache.has(key)) return cache.get(key);
    const all = renderRig(p, null, 0), ids = all.tags.filter(t => Z[t] !== undefined).sort((a, b) => Z[a] - Z[b]);
    const solid = {};
    for (const id of ids) solid[id] = renderRig(p, id, 0).solid;
    const out = ids.map(id => {
      const near = SEAMLESS.filter(pr => pr.includes(id)).map(pr => solid[pr[0] === id ? pr[1] : pr[0]]).filter(Boolean);
      const skip = near.length ? i => near.some(m => m[i]) : undefined;
      return { id, z: Z[id], img: renderRig(p, id, FLIPBOOK.has(id) ? frame || 0 : 0, skip) };
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

  // ---------- posing: the rig driven like src/rig/rig_poses.gd drake() ----------
  // Every part is turned (and shifted) about its own pivot inside its parent's frame (PARENT), so a
  // child adds its parent's turn; the parts are stacked by Z and sampled nearest neighbour, as the
  // game's RigRenderer does. pose: { id: { rot, dx, dy } } (rot in radians, positive = clockwise on
  // screen; dx, dy in source px). Parts listed in pose.hide are left out.
  const mul = (A, B) => [A[0] * B[0] + A[1] * B[3], A[0] * B[1] + A[1] * B[4], A[0] * B[2] + A[1] * B[5] + A[2], A[3] * B[0] + A[4] * B[3], A[3] * B[1] + A[4] * B[4], A[3] * B[2] + A[4] * B[5] + A[5]];
  /** Form p posed: { w, h, px } of the frame grown by pad px on every side (the rest frame sits at pad, pad). */
  function posed(p, pose, frame, pad) {
    const r = parts(p, frame || 0), W = r.w, H = r.h, J = r.joints, byId = Object.fromEntries(r.parts.map(e => [e.id, e])), T = {};
    const get = id => {
      if (T[id]) return T[id];
      const par = PARENT[id], base = par && byId[par] ? get(par) : [1, 0, 0, 0, 1, 0];
      const q = pose[id] || {}, rot = q.rot || 0, c = Math.cos(rot), sn = Math.sin(rot), [px, py] = J[id];
      return (T[id] = mul(base, [c, -sn, px + (q.dx || 0) - (c * px - sn * py), sn, c, py + (q.dy || 0) - (sn * px + c * py)]));
    };
    const OW = W + pad * 2, OH = H + pad * 2, out = new Array(OW * OH).fill(null), hide = pose.hide || [];
    for (const e of r.parts) {
      if (hide.includes(e.id)) continue;
      const M = get(e.id), det = M[0] * M[4] - M[1] * M[3];
      const inv = [M[4] / det, -M[1] / det, (M[1] * M[5] - M[4] * M[2]) / det, -M[3] / det, M[0] / det, (M[3] * M[2] - M[0] * M[5]) / det];
      for (let y = 0; y < OH; y++) for (let x = 0; x < OW; x++) {
        const wx = x - pad + .5, wy = y - pad + .5, sx = Math.floor(inv[0] * wx + inv[1] * wy + inv[2]), sy = Math.floor(inv[3] * wx + inv[4] * wy + inv[5]);
        if (sx < 0 || sy < 0 || sx >= W || sy >= H) continue;
        const col = e.img.px[sy * W + sx];
        if (col) out[y * OW + x] = col;
      }
    }
    return { w: OW, h: OH, px: out };
  }
  /** True when form p's far wing spreads right of its pivot (form 4: beside the head): its flap turns the other way. */
  function farWingRight(p) {
    const r = parts(p, 0), e = r.parts.find(q => q.id === 'wing_far');
    if (!e) return false;
    let sx = 0, n = 0;
    e.img.px.forEach((c, i) => { if (c) { sx += i % r.w; n++; } });
    return sx / n > r.joints.wing_far[0] + 8;
  }
  // A wing may turn about its pivot until it would cover more of the head (head, horns, jaw at
  // rest) than it does at rest: by this many of its pixels (at least WING_COVER_MIN) ...
  const WING_COVER = 0.01, WING_COVER_MIN = 4;
  // ... and never more than this far (rad) either way.
  const WING_TURN_MAX = 1.2;
  // The head and wing rules of src/rig/rig_poses.gd, mirrored for the sheets: DRAKE_NECK_UNDER_WING,
  // DRAKE_WING_REAR, DRAKE_WING_HEAD_REAR, DRAKE_WING_TOUCH, DRAKE_FLIP_BEAT (see there).
  const NECK_UNDER_WING = 0.3, WING_REAR = 1.0, WING_HEAD_REAR = 0.25, WING_TOUCH = 0.1, FLIP_BEAT = 0.2;
  const WING_CACHE = {};
  /**
   * The flap and swing range of wing `id` of form p (hell_rigs.json part fields "flap", "swing"):
   * flap = 1 when its membrane spreads left of its pivot (a clockwise turn lifts it), -1 when it
   * spreads right of it (form 4's far wing, beside the head: lifting is the opposite turn); swing =
   * [lo, hi], the turns (rad, positive = clockwise) up to which it covers no more of the head than
   * at rest (in steps of 0.01 rad, at most WING_TURN_MAX). null for a part the form lacks.
   */
  function wingRange(p, id) {
    const key = p + ':' + id;
    if (key in WING_CACHE) return WING_CACHE[key];
    const r = parts(p, 0), e = r.parts.find(q => q.id === id);
    if (!e) return (WING_CACHE[key] = null);
    const W = r.w, H = r.h, [jx, jy] = r.joints[id], head = new Uint8Array(W * H), px = [];
    for (const q of r.parts) if (q.id === 'head' || q.id === 'horns' || q.id === 'jaw') q.img.px.forEach((c, i) => { if (c) head[i] = 1; });
    e.img.px.forEach((c, i) => { if (c) px.push([i % W + .5, Math.floor(i / W) + .5]); });
    const cover = th => {
      const c = Math.cos(th), s = Math.sin(th);
      let n = 0;
      for (const [x, y] of px) {
        const dx = x - jx, dy = y - jy, X = Math.floor(jx + c * dx - s * dy), Y = Math.floor(jy + s * dx + c * dy);
        if (X >= 0 && Y >= 0 && X < W && Y < H && head[Y * W + X]) n++;
      }
      return n;
    };
    const most = cover(0) + Math.max(WING_COVER_MIN, Math.round(px.length * WING_COVER));
    const reach = dir => { let ok = 0; for (let k = 1; k * .01 <= WING_TURN_MAX + 1e-9; k++) { if (cover(dir * k * .01) > most) break; ok = k; } return Math.round(dir * ok) / 100; };
    const mean = px.reduce((s, q) => s + q[0], 0) / px.length;
    return (WING_CACHE[key] = { flap: mean > jx + 8 ? -1 : 1, swing: [reach(-1), reach(1)] });
  }
  /** A turn kept inside [lo, hi]: unchanged up to 60 % of a limit, then easing into it (rig_poses.gd _drake_limit). */
  function limitTurn(x, lo, hi) {
    const ease = (v, lim) => { if (lim <= 0) return 0; const knee = .6 * lim; return v <= knee ? v : knee + (lim - knee) * Math.tanh((v - knee) / (lim - knee)); };
    return x > 0 ? ease(x, hi) : x < 0 ? -ease(-x, -lo) : 0;
  }
  /** The feet: [x, y] in the rest frame, x the middle of the lowest row of both legs, y that row. */
  function ground(p) {
    const r = parts(p, 0), W = r.w, H = r.h, legs = r.parts.filter(e => e.id === 'leg_far' || e.id === 'leg_near');
    let gy = -1, x0 = W, x1 = -1;
    for (const e of legs) e.img.px.forEach((c, i) => { if (c) gy = Math.max(gy, Math.floor(i / W)); });
    for (const e of legs) for (let x = 0; x < W; x++) if (e.img.px[gy * W + x]) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); }
    return [(x0 + x1 + 1) / 2, gy];
  }

  /** The lowest pixel centre (y, source px) of part id of form p turned by rot about its pivot. */
  function footDrop(p, id, rot) {
    const r = parts(p, 0), e = r.parts.find(q => q.id === id), [px, py] = r.joints[id], c = Math.cos(rot), s = Math.sin(rot);
    let low = -Infinity;
    e.img.px.forEach((col, i) => { if (col) { const x = i % r.w + .5, y = Math.floor(i / r.w) + .5; low = Math.max(low, py + (x - px) * s + (y - py) * c); } });
    return low;
  }

  // ---------- sprite sheets: hell_monsters.json's atlas rows, posed from the rig parts ----------
  // One 8-frame loop per row, simple per-row motion on the rig's own joints (the game's part rig
  // animates far more; the atlas serves the places that draw a whole frame: intro, echoes,
  // transformation, the browser bestiary, and the game until the rig takes over). Every row keeps
  // the feet on the floor: the frame is cropped so the ground row is its bottom row and the feet's
  // middle (ground x) its horizontal centre, like every other hell monster's frame.
  // KNOWN GAP: a row is one 8-frame loop (0.6-0.9 s in the game), so every part repeats on that
  // one period; phases and a second harmonic on the tail and jaw keep their peaks apart, but the
  // void_lord feel of unrelated periods (ANIM-01/06) only exists in the part rig
  // (src/rig/rig_poses.gd), which the game draws once DrakeRigHost is wired into hell_monsters.gd.
  const SHEET_ANIMS = ['idle', 'run', 'attack', 'cast', 'fly'];
  const SHEET_FRAMES = 8;
  const SHEET_PAD = 40;
  /**
   * The lift (rad, flap 1 sense) of wing id of form p beating amp each way at phase value s (-1..1),
   * as rig_poses.gd _drake_beat: a wing resting against the head (room toward it < WING_TOUCH)
   * only lifts off it, one with a little room beats from that limit up to amp.
   */
  function wingBeat(p, id, amp, s) {
    const w = wingRange(p, id);
    if (!w) return amp * s;
    let room = w.flap > 0 ? -w.swing[0] : w.swing[1];
    room = room < WING_TOUCH ? 0 : room;
    return room >= amp ? amp * s : .5 * (amp + room) * s + .5 * (amp - room);
  }
  /** The pose of sheet frame f of anim for form p: { pose, frame } (frame = the flames' flipbook frame). */
  function sheetPose(p, anim, f) {
    const t = (f % SHEET_FRAMES) / SHEET_FRAMES * Math.PI * 2, pose = {}, r = parts(p, 0), J = r.joints, G = ground(p);
    const add = (id, k, v) => { if (!J[id]) return; pose[id] = pose[id] || {}; pose[id][k] = (pose[id][k] || 0) + v; };
    // lift > 0 raises a wing (turned by its flap sign at the end, see wingRange)
    const wings = (near, far) => { add('wing_near', 'rot', near); add('wing_far', 'rot', far); };
    // a breath or beat of amp each way, phases ph (near, far), through wingBeat
    const beatWings = (amp, phNear, phFar) => wings(wingBeat(p, 'wing_near', amp, Math.sin(t + phNear)), wingBeat(p, 'wing_far', amp, Math.sin(t + phFar)));
    // the tail whip, with a second harmonic (a third of the amplitude) that bends each segment's
    // curve differently, so the segments do not peak in the frames the body and neck do
    const chain = (amp0, grow, lag, phase) => { for (let i = 0; i < 5; i++) add('tail_' + (i + 1), 'rot', (amp0 + grow * i) * (Math.sin(t - i * lag + phase) + .33 * Math.sin(2 * t - i * lag * 1.7 + phase + 1))); };
    // a hind leg turned about the hip with its lowest pixel kept on its rest row (lift px above it): the
    // claws tip with the turn, so the drop is measured on the leg's own pixels; the body's dy is undone
    const leg = (id, rot, lift, bodyDy) => { add(id, 'rot', rot); add(id, 'dy', -bodyDy + footDrop(p, id, 0) - footDrop(p, id, rot) - lift); };
    let frame = f % 4;
    if (anim === 'run') {
      const b = -.8 * Math.cos(t) ** 2;
      add('body', 'dy', b);
      leg('leg_far', -.3 * Math.sin(t), 1.2 * Math.max(0, Math.cos(t)), b);
      leg('leg_near', .3 * Math.sin(t), 1.2 * Math.max(0, -Math.cos(t)), b);
      add('arm', 'rot', .2 * Math.cos(t - Math.PI));
      add('neck', 'rot', .035 * Math.sin(2 * t));
      add('head', 'rot', .04 * Math.sin(2 * t - .8));
      chain(.06, .014, .6, .4);
      wings(-.1 + .03 * Math.sin(2 * t), -.1 + .03 * Math.sin(2 * t + .5));
    } else if (anim === 'attack') {
      // spit/bite: the head pulls back, then lunges with the jaw open
      const k = [0, -.4, -.8, .6, 1.2, 1, .6, .2][f % 8], c = Math.max(0, -k), s = Math.max(0, k);
      add('neck', 'rot', -.15 * c + .2 * s);
      add('head', 'rot', -.2 * c + .26 * s);
      add('jaw', 'rot', .12 * c + .36 * s);
      add('body', 'dx', -1 * c + 1.2 * s);
      add('leg_far', 'dx', 1 * c - 1.2 * s);
      add('leg_near', 'dx', 1 * c - 1.2 * s);
      add('arm', 'rot', -.12 * c + .18 * s);
      add('tail_1', 'rot', .04 * c - .03 * s);
      chain(.03, .008, .6, 0);
      wings(.12 * c - .08 * s, .12 * c - .08 * s);
      frame = (f * 2) % 4;
    } else if (anim === 'cast') {
      const k = [0, .3, .7, 1, 1, 1, .7, .3][f % 8];
      if (p <= 2) {
        // crouch low and spit fire from the ground
        add('body', 'dy', 1.2 * k);
        add('leg_far', 'dy', -1.2 * k);
        add('leg_near', 'dy', -1.2 * k);
        add('neck', 'rot', .12 * k);
        add('head', 'rot', .08 * k);
        add('jaw', 'rot', .32 * k);
        add('arm', 'rot', .15 * k);
      } else {
        // rear the head, open the maw, raise the wings
        add('neck', 'rot', -.2 * k);
        add('head', 'rot', -.16 * k);
        add('jaw', 'rot', .42 * k);
        add('arm', 'rot', -.2 * k);
        wings(.4 * k, .4 * k);
      }
      chain(.035, .01, .6, 0);
      add('tail_1', 'rot', .05 * k);
    } else if (anim === 'fly') {
      // airborne: legs and claw tucked, wings beating, the tail streaming
      const b = -1.2 * Math.sin(t - .8);
      add('body', 'dy', b);
      add('leg_far', 'rot', -.5); add('leg_far', 'dy', -1);
      add('leg_near', 'rot', -.6); add('leg_near', 'dy', -1.2);
      add('arm', 'rot', -.55);
      add('neck', 'rot', .08);
      add('head', 'rot', -.04);
      add('tail_1', 'rot', .15);
      chain(.04, .012, .6, 1);
      // the far wing a little later (rig_poses.gd DRAKE_FLIP_BEAT for a flap -1 wing)
      beatWings(.55, .35, wingRange(p, 'wing_far') && wingRange(p, 'wing_far').flap < 0 ? FLIP_BEAT : 0);
      add('jaw', 'rot', .1);
    } else {
      // idle: the body bobs (feet planted), neck and head sway one after the other, the tail whips
      const b = -Math.sin(t);
      add('body', 'dy', b);
      leg('leg_far', 0, 0, b);
      leg('leg_near', 0, 0, b);
      add('neck', 'rot', .05 * Math.sin(t - .4));
      add('head', 'rot', .05 * Math.sin(t - 1.2));
      add('jaw', 'rot', .04 * (1 + .7 * Math.sin(t + 1.3) + .3 * Math.sin(2 * t + 2.2)));
      add('arm', 'rot', .08 * Math.sin(t + 1));
      chain(.05, .012, .6, 0);
      beatWings(.06, .5, 1.2);
    }
    for (let i = 1; i <= 3; i++) add('crystal_' + i, 'dy', -.7 * Math.sin(t + 1.1 * i));
    // as rig_poses.gd: under a wing fanned out above the head (flap -1) the neck hands most of a
    // backward turn to the head (NECK_UNDER_WING), so the head is not lifted into the wing
    const far = wingRange(p, 'wing_far');
    if (far && far.flap < 0 && pose.neck && pose.neck.rot < 0) {
      const back = pose.neck.rot;
      pose.neck.rot = back * NECK_UNDER_WING;
      add('head', 'rot', back * (1 - NECK_UNDER_WING));
    }
    // wings as rig_poses.gd _drake_wings turns them: by their flap sign (both lift together), none
    // past its swing range, and the limit on the head's side recedes as the head rears (all of the
    // neck's backward turn, WING_HEAD_REAR of the head's for a wing above the head, all of it for one
    // behind the head)
    const neckBack = Math.min(0, (pose.neck || {}).rot || 0), headBack = Math.min(0, (pose.head || {}).rot || 0);
    for (const id of ['wing_far', 'wing_near']) {
      const w = wingRange(p, id);
      if (!w || !pose[id]) continue;
      let rot = limitTurn(w.flap * (pose[id].rot || 0), w.swing[0], w.swing[1]);
      const rear = WING_REAR * neckBack + (w.flap < 0 ? WING_HEAD_REAR : 1) * headBack;
      if (w.swing[1] < -w.swing[0]) rot = Math.min(rot, Math.max(w.swing[0], w.swing[1] + rear));
      pose[id].rot = rot;
    }
    return { pose, frame };
  }
  const SHEET = {};
  /**
   * Form p's sheet frame: { W, H, x0, y0 } where x0, y0 place it in posed() coordinates (pad
   * SHEET_PAD): the union of every row's frames, the feet's middle at W / 2 and the ground row the
   * bottom row (anything below it is cut and counted in `below`).
   */
  function sheetLayout(p) {
    if (SHEET[p]) return SHEET[p];
    const G = ground(p), gx = G[0] + SHEET_PAD, gy = G[1] + SHEET_PAD;
    let x0 = Infinity, x1 = -1, y0 = Infinity, below = 0;
    const frames = {};
    for (const anim of SHEET_ANIMS) {
      if (anim === 'fly' && p < 3) continue;
      frames[anim] = [];
      for (let f = 0; f < SHEET_FRAMES; f++) {
        const s = sheetPose(p, anim, f), img = posed(p, s.pose, s.frame, SHEET_PAD);
        frames[anim].push(img);
        img.px.forEach((c, i) => {
          if (!c) return;
          const x = i % img.w, y = Math.floor(i / img.w);
          x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y);
          if (y > gy) below++;
        });
      }
    }
    // one free column on each side of the widest frame; W / 2 lands exactly on the feet's middle
    const half = Math.max(gx - x0, x1 + 1 - gx) + 1, left = Math.floor(gx - half), W = Math.round(2 * (gx - left)), top = y0 - 1;
    return (SHEET[p] = { W, H: gy - top + 1, x0: left, y0: top, ground: [gx - left, gy - top], below, frames });
  }
  /** Sheet frame f of anim for form p: { w, h, px } (colour strings or null), facing right, feet on the bottom row. */
  function sheetFrame(p, anim, f) {
    const L = sheetLayout(p), list = L.frames[anim] || L.frames.idle, img = list[f % list.length], px = new Array(L.W * L.H).fill(null);
    for (let y = 0; y < L.H; y++) for (let x = 0; x < L.W; x++) {
      const sx = x + L.x0, sy = y + L.y0;
      if (sx >= 0 && sy >= 0 && sx < img.w && sy < img.h) px[y * L.W + x] = img.px[sy * img.w + sx];
    }
    return { w: L.W, h: L.H, px };
  }

  return { renderRig, parts, compose, fit, posed, farWingRight, ground, sheetPose, sheetLayout, sheetFrame, drawDrake,
    wingRange, limitTurn, FORM, PARENT, Z, SEAMLESS, FLIPBOOK, SHEET_ANIMS, SHEET_FRAMES };
});

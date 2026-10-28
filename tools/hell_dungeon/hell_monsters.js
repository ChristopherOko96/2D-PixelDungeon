// Hell monsters drawn as small pixel programs in the 0x72 DungeonTileset II style:
// only colours of the pack's 37-colour palette, a 1 px #222222 outline, light from
// the top left, two or three tones per material, flames that loop over 4 frames.
// Every monster is a draw(P, anim, frame) function; render() turns one frame into
// RGBA pixels. The browser preview and a later Godot sheet export use the same code.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.HellMonsters = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // ---------- palette (0x72 DungeonTileset II, extended palette) ----------
  const K = '#222222', BLK = '#0e0c0c', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a';
  const RED = '#da4e38', CRIM = '#9f294e', MAROON = '#62232f', PLUM = '#38262d', PURP = '#5f2d56', MAG = '#993970';
  const PINK = '#dc4a7b', ROSE = '#f78697', LILAC = '#f0b3dd', VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579', BLUV = '#5956bd';
  const SLATE = '#314152', STEEL = '#417089', SKY = '#5698cc', TEAL = '#3c9f9c', CYAN = '#72d6ce', GTEAL = '#49a790';
  const GREEN = '#4ba747', DGREEN = '#3d734f', LIME = '#97da3f', YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025', BROWN = '#8f4029';
  const SKIN = '#fccba3', MUD = '#775c55', STONE = '#483b3a', COAL = '#3b3332', SOOT = '#302c2b', NEARBLK = '#2b2929';

  // materials: [shadow, base, light]
  const M = {
    bone: [TAN, BONE, WHITE], skin: [CRIM, RED, ROSE], dskin: [MAROON, CRIM, RED], coal: [NEARBLK, COAL, STONE],
    hound: [SOOT, COAL, MUD], obsid: [SOOT, STONE, MUD], lava: [BORA, ORA, YEL], ember: [CRIM, RED, ORA],
    crust: [BROWN, BORA, ORA], robe: [PLUM, PURP, MAG], robeR: [MAROON, CRIM, RED], ghost: [INDIGO, VIOD, VIO],
    pale: [VIOD, LILAC, WHITE], armour: [BROWN, BORA, YEL], soul: [DGREEN, GREEN, LIME], iron: [NEARBLK, COAL, MUD], steel: [SLATE, STEEL, SKY],
    gold: [BORA, YEL, WHITE], wing: [PLUM, MAROON, CRIM], wingV: [INDIGO, PURP, MAG], hair: [SOOT, COAL, STONE],
  };
  const FIRE = [WHITE, YEL, ORA, RED, CRIM];
  const SOULFIRE = [WHITE, LIME, GREEN, DGREEN, DGREEN];
  const VOIDFIRE = [LILAC, VIO, VIOD, PURP, INDIGO];

  // ---------- painter ----------
  function Painter(w, h, frame) {
    this.w = w; this.h = h; this.f = frame || 0;
    this.solid = new Array(w * h).fill(null);
    this.back = []; this.front = [];
  }
  const P = Painter.prototype;
  P.inside = function (x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; };
  P.dot = function (x, y, c) { x = Math.round(x); y = Math.round(y); if (this.inside(x, y)) this.solid[y * this.w + x] = c; return this; };
  P.clear = function (x, y) { x = Math.round(x); y = Math.round(y); if (this.inside(x, y)) this.solid[y * this.w + x] = null; return this; };
  // Stamps a shape given by inside(px, py) over the box; shades by the shape's own edges.
  P.shape = function (x0, y0, x1, y1, inside, mat, opt) {
    opt = opt || {};
    x0 = Math.floor(x0) - 1; y0 = Math.floor(y0) - 1; x1 = Math.ceil(x1) + 1; y1 = Math.ceil(y1) + 1;
    const pts = [];
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (inside(x + .5, y + .5)) pts.push([x, y]);
    const has = new Set(pts.map(([x, y]) => x + ',' + y));
    const inn = (x, y) => has.has(x + ',' + y);
    for (const [x, y] of pts) {
      let c;
      if (typeof mat === 'string') c = mat;
      else {
        const up = inn(x, y - 1), dn = inn(x, y + 1), lf = inn(x - 1, y), rt = inn(x + 1, y);
        c = mat[1];
        if (!dn) c = mat[0]; else if (!up) c = mat[2]; else if (!rt) c = mat[0]; else if (!lf && !opt.noLeftLight) c = mat[2];
        if (opt.edge && (!dn || !up || !lf || !rt)) c = opt.edge;
      }
      this.dot(x, y, c);
    }
    return this;
  };
  P.ell = function (cx, cy, rx, ry, mat, opt) {
    return this.shape(cx - rx, cy - ry, cx + rx, cy + ry, (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1, mat, opt);
  };
  P.rect = function (x, y, w, h, mat, opt) { return this.shape(x, y, x + w, y + h, (px, py) => px >= x && px < x + w && py >= y && py < y + h, mat, opt); };
  P.poly = function (pts, mat, opt) {
    const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
    const inside = (x, y) => {
      let c = false;
      for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        const [xi, yi] = pts[i], [xj, yj] = pts[j];
        if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
      }
      return c;
    };
    return this.shape(Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys), inside, mat, opt);
  };
  P.line = function (x0, y0, x1, y1, mat, thick, opt) {
    const r = (thick || 1) / 2 + .01;
    const inside = (x, y) => {
      const dx = x1 - x0, dy = y1 - y0, l2 = dx * dx + dy * dy || 1;
      const t = Math.max(0, Math.min(1, ((x - x0 - .5) * dx + (y - y0 - .5) * dy) / l2));
      return Math.hypot(x - .5 - (x0 + t * dx), y - .5 - (y0 + t * dy)) <= r;
    };
    return this.shape(Math.min(x0, x1) - r, Math.min(y0, y1) - r, Math.max(x0, x1) + r, Math.max(y0, y1) + r, inside, mat, opt);
  };
  // Mirrors everything drawn so far in the solid layer around the centre column (x = w / 2).
  P.mirror = function () {
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w / 2; x++) {
      const a = y * this.w + x, b = y * this.w + (this.w - 1 - x);
      if (this.solid[a] && !this.solid[b]) this.solid[b] = this.solid[a];
    }
    return this;
  };
  // A flame of width w rising h pixels above its base row; loops over the 4 frames.
  P.flame = function (x0, base, w, h, opt) {
    opt = opt || {};
    x0 = Math.round(x0); base = Math.round(base); w = Math.max(1, Math.round(w)); h = Math.max(1, Math.round(h));
    const pal = opt.pal || FIRE, layer = opt.front ? this.front : this.back, seed = opt.seed || 0;
    const ph = (this.f % 4) / 4 * Math.PI * 2, dir = opt.dir || -1, lean = opt.lean || 0;
    for (let i = 0; i < w; i++) {
      const u = w > 1 ? i / (w - 1) : .5, taper = 1 - Math.pow(Math.abs(u - .5) * 2, 1.6) * .75;
      const n = .5 + .3 * Math.sin(i * 1.9 + seed + ph) + .2 * Math.sin(i * .7 - seed * 1.3 + ph * 2);
      const hh = Math.max(1, Math.round(h * taper * (.68 + .32 * n)));
      for (let j = 0; j < hh; j++) {
        const fr = j / hh, core = Math.abs(u - .5) < (w > 8 ? .1 : .22) && fr < (h > 6 ? .14 : .3);
        const c = core ? pal[0] : fr < .3 ? pal[1] : fr < .62 ? pal[2] : fr < .86 ? pal[3] : pal[4];
        const xx = Math.round(x0 + i + lean * j / Math.max(1, h)), yy = base + dir * j;
        layer.push([xx, yy, c]);
      }
      if (opt.sparks !== false && ((i * 7 + this.f * 3 + seed) % 11) === 0) layer.push([Math.round(x0 + i + lean), base + dir * (hh + 2), pal[2]]);
    }
    return this;
  };
  P.glow = function (x, y, c) { this.front.push([Math.round(x), Math.round(y), c]); return this; };
  P.finish = function () {
    const w = this.w, h = this.h, out = new Array(w * h).fill(null);
    for (const [x, y, c] of this.back) if (this.inside(x, y)) out[y * w + x] = c;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      if (this.solid[y * w + x]) continue;
      const n = (xx, yy) => xx >= 0 && yy >= 0 && xx < w && yy < h && this.solid[yy * w + xx];
      if (n(x - 1, y) || n(x + 1, y) || n(x, y - 1) || n(x, y + 1)) out[y * w + x] = K;
    }
    for (let i = 0; i < w * h; i++) if (this.solid[i]) out[i] = this.solid[i];
    for (const [x, y, c] of this.front) if (this.inside(x, y)) out[y * w + x] = c;
    return out;
  };

  // ---------- shared pieces ----------
  const cyc = (f, list) => list[f % list.length];

  // A hound seen from the side (facing right): stocky body, short strong legs,
  // a burning mane along the back and glowing ember ribs. heads: 1 or 3 (boss).
  function houndBody(P, a, f, o) {
    const run = a === 'run', atk = a === 'attack' || a === 'cast', ox = o.x, big = o.heads > 1;
    const lift = atk ? cyc(f, [1, -3, -2, 0]) : run ? cyc(f, [0, -1, 0, -1]) : 0;
    const by = (big ? 17 : 11) + lift, len = big ? 11 : 7.5, bh = big ? 6 : 4.4, foot = P.h - 2;
    const sw = run ? cyc(f, [-2, 0, 2, 0]) : atk ? cyc(f, [2, -2, -3, 0]) : 0;
    const bx = ox + (big ? 18 : 12);
    const leg = (hx, dx, mat) => { P.line(hx, by + 1, hx + dx, foot, mat, big ? 4 : 3); P.rect(hx + dx - 2, foot, 4, 1, mat); P.dot(hx + dx + 2, foot, mat[0] || mat); };
    leg(bx - len + 3, -sw, M.coal); leg(bx + len - 3, sw, M.coal);
    // tail with a burning tip
    P.line(bx - len + 1, by - 1, bx - len - 3, by - 5 + lift, M.hound, 2);
    P.flame(bx - len - 5, by - 5 + lift, 4, 5, { seed: 9 });
    P.ell(bx, by, len, bh, M.hound);
    P.ell(bx + len - 2, by - 1, big ? 5 : 3.6, bh + 1, M.hound);
    for (let k = -2; k <= 2; k++) P.dot(bx + k * 2, by + 1, k % 2 ? MAROON : CRIM).dot(bx + k * 2, by + 2, MAROON);
    leg(bx - len + 5, sw, M.hound); leg(bx + len - 4, -sw, M.hound);
    // mane: flames sitting on the back line
    P.flame(bx - len + 2, by - bh + 1, Math.round(len * 1.6), big ? 9 : 6, { seed: 4, lean: run || atk ? -3 : -1, front: true });
    const heads = big ? [[0, -6], [3, 0], [0, 6]] : [[0, 0]];
    heads.forEach(([dx, dy], i) => {
      const hx = bx + len + 1 + dx, hy = by - (big ? 5 : 3) + dy + (atk ? cyc(f + i, [1, 0, -1, 0]) : 0);
      const jaw = atk ? cyc(f + i, [0, 1, 2, 1]) : 0;
      P.ell(hx, hy, big ? 4.5 : 4, big ? 3.8 : 3.4, M.hound);
      P.poly([[hx - 3, hy - 2], [hx - 2, hy - 7], [hx + 1, hy - 2]], M.hound);
      P.rect(hx + 2, hy - 1, 5, 3, M.hound);
      P.rect(hx + 2, hy + 2 + jaw, 5, 1, M.coal);
      if (jaw) P.rect(hx + 3, hy + 2, 4, jaw, CRIM);
      P.dot(hx + 3, hy + 2, WHITE).dot(hx + 5, hy + 2, WHITE).dot(hx + 4, hy + 2 + jaw, WHITE).dot(hx + 6, hy + 2 + jaw, WHITE);
      P.dot(hx, hy - 1, YEL).dot(hx + 1, hy - 1, ORA).dot(hx + 7, hy - 1, K);
      if (atk && f >= 1) P.flame(hx + 7, hy + 1, 3, 3, { seed: 1 + i, front: true, dir: 1, sparks: false });
    });
  }

  // ---------- Ignaroth, the glow dragon (floors 3, 6, 9, 10) ----------
  // Stands on two legs in every phase (side view, facing right). 1 salamander with a
  // spark on the tail, 2 horns, teeth, longer claws, 3 adult with big horns and two
  // wings, 4 obsidian form: gold horns, claws, wing tusks, spikes along tail and back
  // (half hidden between the wings), small flames at both mouth corners.
  const DRAKE = [null,
    { s: .98, hide: [BROWN, BORA, ORA], belly: [ORA, YEL, WHITE], fire: FIRE, horn: M.bone, claw: M.bone },
    { s: 1.15, hide: [CRIM, RED, ORA], belly: [BORA, ORA, YEL], fire: FIRE, horn: M.bone, claw: M.bone, scars: true },
    { s: 1.45, hide: [MAROON, CRIM, RED], belly: [BORA, ORA, YEL], fire: FIRE, horn: M.bone, claw: M.bone, scars: true, wingMat: [PLUM, MAROON, CRIM] },
    { s: 1.95, hide: [SOOT, COAL, STONE], belly: [PURP, MAG, VIO], fire: VOIDFIRE, horn: M.gold, claw: M.gold, coreMat: M.ghost, wingMat: [INDIGO, PURP, MAG], tuskMat: M.gold, scars: true },
  ];
  // Pose for one frame: every motion is a sine over the 8-frame loop, so loops are seamless.
  function drakePose(p, a, f) {
    const t = (f % 8) / 8 * Math.PI * 2, o = { bob: Math.sin(t) * .55, stride: 0, wingLift: Math.sin(t) * .06, mouth: 0, headX: 0, headY: 0, tail: Math.sin(t), crouch: 0, fly: false };
    if (a === 'run') { o.stride = Math.sin(t); o.bob = -Math.abs(Math.cos(t)) * .9; o.headY = Math.cos(t * 2) * .25; o.wingLift = -.15; }
    if (a === 'attack') { const k = [0, -.4, -.8, .6, 1.2, 1, .6, .2][f % 8]; o.headX = k * 1.4; o.headY = -Math.min(0, k) * .8; o.mouth = Math.max(0, k); o.bob = -k * .3; o.wingLift = -k * .25; }
    if (a === 'cast') {
      const k = [0, .3, .7, 1, 1, 1, .7, .3][f % 8];
      if (p <= 2) { o.crouch = k * 1.6; o.headY = k * 1.2; o.headX = k * .5; o.mouth = k * .4; }
      else { o.headY = -k * 1.4; o.headX = -k * .4; o.mouth = k; o.wingLift = -k * .55; o.bob = -k * .4; }
    }
    if (a === 'fly') { o.fly = true; o.wingLift = Math.sin(t) * .75; o.bob = -Math.sin(t) * .8; o.headY = -.4; o.tail = Math.sin(t + 1) * 1.4; }
    return o;
  }
  function drakeWing(P, sx, sy, span, mat, boneMat, s, lift, tusks, tuskMat) {
    // lift: -1 wings up, +1 wings down (flap); the elbow follows part of the way
    const el = [sx - span * .2, sy - span * .8 + lift * span * .28];
    const tips = [[sx - span * .95, sy - span * .62 + lift * span * .62], [sx - span * 1.08, sy - span * .2 + lift * span * .5], [sx - span * .82, sy + span * .1 + lift * span * .36], [sx - span * .45, sy + span * .12 + lift * span * .2]];
    const notch = (a, b) => [(a[0] + b[0]) / 2 * .62 + el[0] * .38, (a[1] + b[1]) / 2 * .62 + el[1] * .38 + span * .06];
    P.poly([[sx, sy], el, tips[0], notch(tips[0], tips[1]), tips[1], notch(tips[1], tips[2]), tips[2], notch(tips[2], tips[3]), tips[3], [sx - span * .05, sy + 3 * s]], mat);
    P.line(sx, sy, el[0], el[1], boneMat, Math.max(2, 1.4 * s));
    for (const tp of tips) P.line(el[0], el[1], tp[0], tp[1], boneMat, 1);
    P.poly([[el[0] - 1, el[1]], [el[0] + 1.5, el[1]], [el[0] + 1, el[1] - 2 * s]], M.bone);
    if (tusks) { const t0 = tips[0]; for (const [x, y, len] of [[el[0], el[1], 4.2], [(el[0] + t0[0]) / 2, (el[1] + t0[1]) / 2 - 1, 2.8]]) { P.line(x, y, x + .8 * s, y - len * .55 * s, tuskMat, Math.max(1.5, 1.1 * s)); P.line(x + .8 * s, y - len * .55 * s, x + 2.2 * s, y - len * s, tuskMat, 1); } }
  }
  function drake(P, p, a, f) {
    const o = DRAKE[p], q = drakePose(p, a, f), s = o.s, foot = P.h - 1, cx = P.w * (p >= 3 ? .45 : .46);
    const hide = o.hide, dark = [hide[0], hide[0], hide[1]], claw = o.claw, pal = o.fire;
    const clawLen = [0, 1, 1.8, 2.2, 2.6][p], up = (q.bob - q.crouch * .6) * s + (q.fly ? -3 * s : 0);
    const hipX = cx - 1 * s, hipY = foot - 8 * s + up + q.crouch * s;
    const torso = [cx + 1 * s, foot - 13 * s + up + q.crouch * .8 * s], chestR = [4.4 * s, 6 * s];
    const head = [cx + 5.5 * s + q.headX * s, foot - 21 * s + up + q.headY * s + q.crouch * s];
    let nearWing = null;
    if (p >= 3) {
      const span = (p === 4 ? 24 : 19) * s * .8, sx = cx - 1.5 * s, sy = foot - 17.5 * s + up;
      drakeWing(P, sx + 2.5 * s, sy - 2.5 * s, span * .92, [o.wingMat[0], o.wingMat[0], o.wingMat[1]], dark, s, q.wingLift * 1.1, p === 4, o.tuskMat);
      nearWing = () => drakeWing(P, sx, sy, span, o.wingMat, hide, s, q.wingLift, p === 4, o.tuskMat);
    }
    // tail from the hip back towards the ground, sweeping with the pose
    const tl = (p === 1 ? 11 : 13) * s;
    let prev = [hipX - 1 * s, hipY + 1 * s];
    for (let k = 1; k <= 10; k++) {
      const u = k / 10, pt = [hipX - 1 * s - tl * u, hipY + 1 * s + u * (q.fly ? 2 : 5) * s - Math.sin(u * Math.PI) * 1.5 * s + Math.sin(u * 2.4) * q.tail * .9 * s * u];
      P.line(prev[0], prev[1], pt[0], pt[1], hide, Math.max(1, 3 * s * (1 - u * .85)));
      if (p === 4 && k % 2 === 1) { const th = 3 * s * (1 - u * .85), top = pt[1] - th / 2, h = (4.2 - k * .38) * s, b = Math.max(1, (1.6 - k * .12) * s); P.poly([[pt[0] - b, top + 1], [pt[0] + b, top + 1], [pt[0] - b * 1.4, top - h * .55], [pt[0] - b * 1.8, top - h]], o.horn); }
      prev = pt;
    }
    const tf = [0, 3, 5, 8, 13][p];
    P.flame(prev[0] - Math.round(tf / 3), prev[1] + 1, Math.max(2, Math.round(tf * .55)), tf, { seed: 3, pal, front: true });
    if (p === 1) P.glow(prev[0] - 1, prev[1] - 4, YEL).glow(prev[0] + 1, prev[1] - 5, ORA);
    // digitigrade legs with claws; in flight they tuck back
    const leg = (dx, mat, st) => {
      const hx = hipX + dx;
      P.ell(hx + .5 * s, hipY + .5 * s, 2.8 * s, 3.2 * s, mat);
      if (q.fly) { const kx = hx - 1 * s, ky = hipY + 4 * s, fx = hx - 4 * s, fy = hipY + 5.5 * s; P.line(hx, hipY + 1.5 * s, kx, ky, mat, Math.max(2, 2.2 * s)); P.line(kx, ky, fx, fy, mat, Math.max(1.5, 1.5 * s)); for (let t = 0; t < 3; t++) P.line(fx, fy, fx - clawLen - 1, fy + t - 1, claw, 1); return; }
      const fwd = st * 2.4 * s, lift = Math.max(0, st) * 1.4 * s;
      const kx = hx + 2.6 * s + fwd * .5, ky = foot - 5 * s - lift, ax = hx - .3 * s + fwd, ay = foot - 1.6 * s - lift * .8, fy = foot - .5 - lift * .7;
      P.line(hx + .5 * s, hipY + 1.5 * s, kx, ky, mat, Math.max(2, 2.4 * s));
      P.line(kx, ky, ax, ay, mat, Math.max(1.5, 1.8 * s));
      P.line(ax, ay, ax + 3.2 * s, fy, mat, Math.max(1.5, 1.6 * s));
      for (let t = 0; t < 3; t++) P.line(ax + (1.6 + t * .9) * s, fy, ax + (1.6 + t * .9) * s + clawLen, fy, claw, 1);
      P.line(ax - .2 * s, fy, ax - .2 * s - clawLen * .6, fy, claw, 1);
    };
    leg(1.6 * s, dark, -q.stride);
    P.ell(torso[0], torso[1], chestR[0], chestR[1], hide);
    P.ell(torso[0] + 1.6 * s, torso[1] + .8 * s, chestR[0] * .55, chestR[1] * .8, o.belly);
    for (let k = -2; k <= 3; k++) P.line(torso[0] + .6 * s, torso[1] + k * 1.6 * s, torso[0] + 2.8 * s, torso[1] + k * 1.6 * s, o.belly[0], 1);
    if (o.scars) for (const [x0, y0] of [[-2, -3], [-1, -1], [-2.5, 1]]) P.line(torso[0] + x0 * s, torso[1] + y0 * s, torso[0] + (x0 + 1.5) * s, torso[1] + (y0 + 1) * s, ORA, 1);
    if (p === 4) { P.ell(torso[0] + 1.6 * s, torso[1] - .8 * s, 1.4 * s, 1.4 * s, o.coreMat); P.glow(torso[0] + 1.6 * s, torso[1] - .8 * s, f % 4 < 2 ? WHITE : LILAC); }
    leg(-.2 * s, hide, q.stride);
    if (p >= 2) { const n = p >= 3 ? 5 : 3; for (let k = 0; k < n; k++) { const u = k / Math.max(1, n - 1), x = torso[0] - chestR[0] * .7 + u * 2 * s, y = torso[1] - chestR[1] * .2 - u * chestR[1] * .65; P.poly([[x - 1.2 * s, y + .6 * s], [x + .8 * s, y - .4 * s], [x - 2 * s - (p >= 3 ? s : 0), y - 1.2 * s]], p === 4 ? M.gold : M.bone); } }
    // back horns sit between the two wings: the near wing hides most of them
    if (p === 4) for (let k = 0; k < 4; k++) { const u = k / 3, ang = -1.35 - u * 1.1, x = torso[0] - .5 * s + Math.cos(ang) * chestR[0] * 1.02, y = torso[1] + Math.sin(ang) * chestR[1] * 1.02, h = (4.6 - k * .8) * s, tx = x - h * .55, ty = y - h * .85; P.line(x, y, (x + tx) / 2, (y + ty) / 2, o.horn, Math.max(1.5, (1.3 - k * .15) * s)); P.line((x + tx) / 2, (y + ty) / 2, tx, ty, o.horn, 1); }
    if (nearWing) nearWing();
    // arms with clawed hands; they reach forward when attacking
    const reach = q.mouth * 1.2 * s, sh = [torso[0] + 2.4 * s, torso[1] - 3.5 * s], el = [sh[0] + 2.2 * s + reach * .4, sh[1] + 3 * s], hand = [el[0] + 2.4 * s + reach, el[1] - 1.6 * s - reach * .3];
    P.line(sh[0], sh[1], el[0], el[1], hide, Math.max(1.5, 1.8 * s)); P.line(el[0], el[1], hand[0], hand[1], hide, Math.max(1.5, 1.5 * s));
    for (let t = -1; t <= 1; t++) P.line(hand[0], hand[1], hand[0] + clawLen * .9 + .5, hand[1] + t * 1.1 + clawLen * .35, claw, 1);
    // neck and head
    P.line(torso[0] + .8 * s, torso[1] - chestR[1] * .7, head[0] - 1 * s, head[1] + 1 * s, hide, Math.max(2.5, 3 * s));
    const hr = [0, 2.8, 3, 3.3, 3.5][p] * s, snout = [0, 4, 4.4, 5.6, 6][p] * s, maw = [0, 1.4, 1.8, 2.4, 2.6][p] * s;
    P.ell(head[0], head[1], hr, hr * .85, hide);
    P.poly([[head[0] + hr * .3, head[1] - hr * .55], [head[0] + hr + snout, head[1] - hr * .1], [head[0] + hr + snout, head[1] + hr * .3], [head[0] + hr * .3, head[1] + hr * .45]], hide);
    const open = (p >= 3 ? 1.1 : p === 2 ? .5 : 0) * s + q.mouth * (p === 1 ? 1.2 : 1.8) * s;
    P.poly([[head[0] - hr * .2, head[1] + hr * .45], [head[0] + hr + snout * .9, head[1] + hr * .45 + open], [head[0] + hr + snout * .85, head[1] + hr * .45 + maw * .6 + open], [head[0] - hr * .2, head[1] + hr * .45 + maw * .7]], dark);
    if (open > .5) P.poly([[head[0] + hr * .4, head[1] + hr * .45], [head[0] + hr + snout * .95, head[1] + hr * .32], [head[0] + hr + snout * .9, head[1] + hr * .45 + open]], MAROON);
    if (p >= 2) { const n = p >= 3 ? 5 : 3; for (let t = 0; t < n; t++) { const x = head[0] + hr * .6 + t * (snout + hr * .3) / n; P.dot(x, head[1] + hr * .45, WHITE); if (p >= 3 || open > 1) P.dot(x + 1, head[1] + hr * .45 + open, WHITE); } }
    P.dot(head[0] + hr + snout - 1, head[1] - hr * .05, K);
    P.line(head[0] - hr * .4, head[1] - hr * .55, head[0] + hr * .7, head[1] - hr * .45, hide[0], 1);
    // horns: nubs in phase 2, big swept-back horns in 3 and 4
    if (p === 2) for (const dx of [0, -1.2]) P.poly([[head[0] + dx * s - .8 * s, head[1] - hr * .6], [head[0] + dx * s + .6 * s, head[1] - hr * .7], [head[0] + dx * s - 1.4 * s, head[1] - hr - 1.8 * s]], o.horn);
    if (p >= 3) {
      const L = p === 4 ? 10 : 8.5;
      for (const [dx, k, th] of [[0, 1, 1.4], [-1.4, .75, 1]]) {
        const pts = [[head[0] + dx * s, head[1] - hr * .6], [head[0] + (dx - 2.2 * k) * s, head[1] - hr - 2.6 * k * s], [head[0] + (dx - 5 * k) * s, head[1] - hr - 4 * k * s], [head[0] + (dx - L * k) * s, head[1] - hr - 3.4 * k * s]];
        for (let i = 0; i < 3; i++) P.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], o.horn, Math.max(1, th * s * (1 - i * .28)));
      }
      P.poly([[head[0] - hr * .8, head[1] + hr * .1], [head[0] - hr * 1.6, head[1] + hr * .6], [head[0] - hr * .6, head[1] + hr * .55]], o.horn);
    }
    // eye: a glowing slit, drawn on top so flames never hide it
    const ex = head[0] + hr * .7, ey = head[1] - hr * .12, eye = p === 4 ? [ORA, YEL, WHITE] : [ORA, YEL, YEL];
    P.glow(ex - 1, ey, eye[0]).glow(ex, ey, eye[1]).glow(ex + 1, ey, eye[2]);
    if (p >= 3) P.glow(ex, ey + 1, eye[0]);
    // the final form burns at both mouth corners all the time
    if (p === 4) {
      const mx = head[0] + hr * .45, my = head[1] + hr * .5;
      P.flame(mx - .5 * s, my + 1, Math.round(1.8 * s), Math.round(3.2 * s), { seed: 11, pal, front: true, dir: 1, lean: -2, sparks: false });
      P.flame(mx + 2.6 * s, my + 1.5, Math.round(1.6 * s), Math.round(2.6 * s), { seed: 17, pal, front: true, dir: 1, lean: -1, sparks: false });
      P.glow(ex - 1, ey, eye[0]).glow(ex, ey, eye[1]).glow(ex + 1, ey, eye[2]);
    }
    if (q.mouth > .6 && a === 'attack') P.flame(head[0] + hr + snout - 1, head[1] + hr * .5 + open * .5, Math.round(2 + p), Math.round(2 + p), { seed: 5, front: true, pal, lean: 3, sparks: false });
  }

  // ---------- monsters ----------
  const DEFS = {};

  DEFS.glutschaedel = {
    name: 'Glutschädel', w: 18, h: 24, scale: 3.4, kind: 'mob', role: 'Flieger',
    desc: 'Ein brennender Totenkopf. Schwirrt unruhig, stürzt sich dann blitzschnell beißend auf dich.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', bob = atk ? 0 : cyc(f, [0, -1, -1, 0]), y = 13 + bob, lean = atk ? -4 : a === 'run' ? -2 : 0;
      // a wreath of fire around the top half, rising well above the skull
      P.flame(2, y + 1, 15, atk ? 16 : 14, { seed: 2, lean });
      P.ell(9, y + 1, 5.5, 4.6, M.bone);
      P.rect(6, y + 4, 7, 2, M.bone);
      // deep sockets with a burning pupil
      P.rect(5, y, 3, 3, K).rect(11, y, 3, 3, K);
      P.dot(6, y + 1, YEL).dot(12, y + 1, YEL).dot(6, y, ORA).dot(12, y, ORA);
      P.dot(9, y + 3, K).dot(8, y + 4, K).dot(10, y + 4, K);
      const open = atk ? cyc(f, [1, 3, 3, 1]) : 0;
      P.rect(6, y + 6, 7, 1, K);
      for (let x = 6; x <= 12; x += 2) P.dot(x, y + 5, WHITE);
      if (open) { P.rect(6, y + 6, 7, open, MAROON); P.dot(9, y + 6 + open - 1, ORA); }
      P.rect(7, y + 6 + open, 5, 2, M.bone);
      for (let x = 7; x <= 11; x += 2) P.dot(x, y + 6 + open, WHITE);
      if (atk) P.flame(4, y + 3, 11, 4, { seed: 7, front: true, dir: 1, lean: 0, sparks: false, pal: [YEL, ORA, RED, CRIM, CRIM] });
    },
  };

  DEFS.hoellenhund = {
    name: 'Höllenhund', w: 31, h: 20, scale: 3.4, kind: 'mob', role: 'Jäger',
    desc: 'Rußschwarzer Hund mit Flammenmähne. Umkreist dich, setzt dann zum Sprung an und beißt.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      houndBody(P, a, f, { x: 0, y: 0, heads: 1 });
    },
  };

  DEFS.glutimp = {
    name: 'Glutimp', w: 18, h: 20, scale: 3.4, kind: 'mob', role: 'Werfer',
    desc: 'Kleiner geflügelter Teufel. Hält Abstand und wirft Feuerbälle in hohem Bogen.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const bob = cyc(f, [0, -1, -1, 0]), atk = a === 'attack';
      const flap = cyc(f, [0, 2, 3, 1]), y = 7 + bob;
      P.poly([[6, y + 4], [1, y - 1 + flap], [0, y + 5 + flap], [3, y + 8]], M.wing);
      P.poly([[12, y + 4], [17, y - 1 + flap], [18, y + 5 + flap], [15, y + 8]], M.wing);
      P.line(9, y + 8, 14, y + 10, M.dskin, 1); P.dot(15, y + 9, CRIM).dot(15, y + 10, CRIM);
      P.ell(9, y + 7, 3.5, 3.6, M.skin);
      const lg = a === 'run' ? cyc(f, [0, 1, 0, -1]) : 0;
      P.rect(7, y + 10 + lg, 2, 2, M.dskin); P.rect(10, y + 10 - lg, 2, 2, M.dskin);
      P.ell(9, y + 1, 4.5, 3.8, M.skin);
      P.poly([[5, y - 1], [4, y - 5], [7, y - 2]], M.bone); P.poly([[13, y - 1], [14, y - 5], [11, y - 2]], M.bone);
      P.rect(6, y, 2, 2, WHITE).rect(11, y, 2, 2, WHITE).dot(7, y + 1, K).dot(11, y + 1, K);
      P.rect(7, y + 3, 5, 1, K); P.dot(7, y + 3, WHITE).dot(9, y + 3, WHITE).dot(11, y + 3, WHITE);
      const ax = atk ? cyc(f, [13, 13, 15, 14]) : 13, ay = atk ? cyc(f, [y + 5, y - 2, y - 3, y + 4]) : y + 6;
      P.line(11, y + 5, ax, ay, M.skin, 1);
      if (atk && f < 3) { P.flame(ax - 2, ay - 3, 5, 4, { seed: 3, front: true }); P.glow(ax - 1, ay - 2, YEL).glow(ax, ay - 2, WHITE).glow(ax, ay - 1, YEL).glow(ax - 1, ay - 1, ORA); }
    },
  };

  DEFS.brandskelett = {
    name: 'Brandskelett', w: 22, h: 27, scale: 3.4, kind: 'mob', role: 'Krieger',
    desc: 'Ein Skelett, das innerlich brennt. Schwingt ein glühendes Schwert in weitem Bogen.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const run = a === 'run', atk = a === 'attack', bob = run ? cyc(f, [0, -1, 0, -1]) : cyc(f, [0, 0, 1, 1]) * 0;
      const sw = run ? cyc(f, [-2, 0, 2, 0]) : 0, x = 9, top = 3 + bob;
      P.flame(x - 4, top + 4, 9, 8, { seed: 5 });
      P.line(x - 1, 18, x - 2 - sw, 25, M.bone, 1); P.line(x + 1, 18, x + 2 + sw, 25, M.bone, 1);
      P.rect(x - 3 - sw, 25, 3, 1, M.bone).rect(x + 1 + sw, 25, 3, 1, M.bone);
      P.rect(x - 2, 16 + bob, 5, 2, M.bone);
      P.line(x, 11 + bob, x, 16 + bob, M.bone, 1);
      for (let k = 0; k < 3; k++) P.line(x - 3 + (k === 2 ? 1 : 0), 11 + bob + k * 2, x + 3 - (k === 2 ? 1 : 0), 11 + bob + k * 2, M.bone, 1);
      for (let k = 0; k < 2; k++) P.dot(x - 1 + k * 2, 12 + bob + k * 2, cyc(f + k, [ORA, YEL, ORA, RED]));
      P.line(x - 4, 11 + bob, x - 5, 16 + bob, M.bone, 1);
      P.ell(x, top + 4, 3.8, 3.4, M.bone);
      P.rect(x - 2, top + 6, 5, 2, M.bone);
      P.rect(x - 3, top + 3, 2, 2, K).rect(x + 1, top + 3, 2, 2, K);
      P.dot(x - 2, top + 4, ORA).dot(x + 2, top + 4, ORA).dot(x - 1, top + 7, K).dot(x + 1, top + 7, K);
      P.flame(x - 3, top + 1, 7, 3, { seed: 9, front: true, sparks: false });
      // sword: [hand x, hand y, tip x, tip y] per attack frame
      const S = atk ? cyc(f, [[x + 2, top + 2, x - 4, top - 2], [x + 5, top + 8, x + 12, top + 2], [x + 5, 15, x + 12, 22], [x + 4, 15, x + 10, 9]]) : [x + 4, 15 + bob, x + 10, 9 + bob];
      P.line(x + 3, 11 + bob, S[0], S[1], M.bone, 1);
      P.line(S[0], S[1], S[2], S[3], M.ember, 2);
      P.dot(S[0], S[1], M.iron[2]);
      P.flame(Math.min(S[0], S[2]), Math.min(S[1], S[3]) + 1, Math.abs(S[2] - S[0]) + 1, 3, { seed: 2, front: true, sparks: false });
      if (atk && (f === 1 || f === 2)) for (let k = 0; k < 6; k++) P.glow(x + 6 + k * 1.4, top + 3 + k * 2.5 + (f === 2 ? 4 : 0), k % 2 ? ORA : YEL);
    },
  };

  DEFS.magmaschleim = {
    name: 'Magmaschleim', w: 22, h: 18, scale: 3.4, kind: 'mob', role: 'Hüpfer',
    desc: 'Ein Klumpen flüssiger Schlacke. Hüpft auf dich zu und hinterlässt kurz brennende Lachen.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', run = a === 'run';
      let rx = 8, ry = 5, lift = 0;
      if (atk) [rx, ry, lift] = cyc(f, [[10, 4, 0], [7, 7, 3], [8, 6, 5], [11, 3.6, 0]]);
      else if (run) [rx, ry, lift] = cyc(f, [[8.5, 4.6, 0], [7.5, 5.6, 2], [8, 5, 3], [9, 4.4, 0]]);
      else [rx, ry] = cyc(f, [[8, 5], [8.4, 4.7], [8, 5], [7.6, 5.3]]);
      const cx = 11, cy = 16 - ry - lift;
      P.ell(cx, cy, rx, ry, M.crust);
      P.ell(cx - 1, cy + .5, rx - 1.5, ry - 1.3, M.lava, { noLeftLight: true });
      for (const [dx, dy] of [[-5, -2], [3, -3], [6, 0], [-7, 1], [0, -4]]) P.dot(cx + dx, cy + dy, BROWN);
      P.dot(cx - 3, cy - ry + 1, YEL).dot(cx - 2, cy - ry + 1, WHITE);
      for (const dx of [-5, 1, 6]) P.dot(cx + dx, cy + ry, ORA).dot(cx + dx, cy + ry + 1, BORA);
      P.rect(cx - 4, cy, 2, 2, WHITE).rect(cx + 2, cy, 2, 2, WHITE).dot(cx - 3, cy + 1, K).dot(cx + 2, cy + 1, K);
      P.line(cx - 2, cy + 3, cx + 2, cy + 3, BROWN, 1);
      for (let k = 0; k < 3; k++) P.glow(cx - 5 + k * 5, cy - ry - 1 - ((f + k * 2) % 4), k === 1 ? WHITE : YEL);
      if (lift === 0) { P.dot(cx - rx, 16, ORA); P.dot(cx + rx, 16, ORA); }
      if (atk && f === 3) for (let k = -12; k <= 12; k += 3) P.glow(cx + k, 17, cyc(k + 12, [YEL, ORA, RED]));
    },
  };

  DEFS.aschenpriester = {
    name: 'Aschenpriester', w: 20, h: 30, scale: 3.4, kind: 'mob', role: 'Beschwörer',
    desc: 'Ein Nekromant der Hölle mit Schädelstab. Ruft Glutschädel herbei und schickt suchende Seelenflammen.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const run = a === 'run', atk = a === 'attack', cast = a === 'cast', x = 9, bob = cyc(f, [0, 0, -1, -1]);
      const hem = run ? cyc(f, [1, 0, -1, 0]) : 0, lift = atk || cast ? cyc(f, [0, -2, -3, -1]) : 0;
      // staff with a skull and green soulfire
      const sx = 16, st = 6 + bob + lift;
      P.line(sx, st, sx, 28, M.iron, 1);
      P.poly([[x - 4, 10 + bob], [x + 4, 10 + bob], [x + 7 + hem, 28], [x - 7 + hem, 28]], M.robe);
      for (let k = -6; k <= 6; k += 3) P.dot(x + k + hem, 28, K).dot(x + k + 1 + hem, 27, CRIM);
      P.line(x - 6 + hem, 26, x + 6 + hem, 26, CRIM, 1);
      P.line(x, 12 + bob, x, 25, PLUM, 1);
      P.rect(x - 3, 16 + bob, 7, 1, M.gold);
      P.poly([[x, 1 + bob], [x - 5, 8 + bob], [x - 4, 13 + bob], [x + 4, 13 + bob], [x + 5, 8 + bob]], M.robe);
      P.ell(x, 9 + bob, 2.6, 2.6, BLK, { flat: true });
      P.dot(x - 1, 9 + bob, LIME).dot(x + 1, 9 + bob, LIME);
      P.line(x + 3, 12 + bob, sx - 1, 15 + bob + lift, M.robe, 2);
      P.dot(sx - 1, 15 + bob + lift, BONE);
      P.ell(sx, st - 1, 2, 1.8, M.bone); P.dot(sx - 1, st - 1, K).dot(sx + 1, st - 1, K);
      P.flame(sx - 2, st - 2, 5, cast ? 9 : atk ? 7 : 5, { seed: 4, pal: SOULFIRE, front: true });
      if (cast) { P.line(x - 3, 12 + bob, x - 7, 9 + bob, M.robe, 2); P.flame(x - 9, 9 + bob, 4, 5, { seed: 8, pal: SOULFIRE, front: true }); }
      else P.line(x - 3, 12 + bob, x - 5, 17 + bob, M.robe, 2);
    },
  };

  DEFS.kettenschinder = {
    name: 'Kettenschinder', w: 34, h: 32, scale: 3.4, kind: 'mob', role: 'Brecher',
    desc: 'Massiger Kerkerteufel mit Stachelkugel an der Kette. Langsam, zäh, und seine Kugel kreist weit.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const run = a === 'run', atk = a === 'attack', cx = 15, bob = run ? cyc(f, [0, -1, 0, -1]) : cyc(f, [0, 0, 1, 1]);
      const lg = run ? cyc(f, [1, 0, -1, 0]) : 0;
      // ball on its chain: hangs by the right fist, circles the body when attacking
      const fist = [cx + 10, 22 + bob];
      const ball = atk ? cyc(f, [[cx + 16, 12], [cx + 4, 4], [cx - 12, 14], [cx + 14, 28]]) : [cx + 13 + cyc(f, [0, 1, 0, -1]), 28];
      const drawChain = () => { const n = 6; for (let k = 1; k < n; k++) P.dot(fist[0] + (ball[0] - fist[0]) * k / n, fist[1] + (ball[1] - fist[1]) * k / n, k % 2 ? SKY : STEEL); };
      const drawBall = () => { P.ell(ball[0], ball[1], 3.4, 3.4, M.iron); for (const [dx, dy] of [[0, -5], [4, -3], [5, 0], [4, 3], [0, 5], [-4, 3], [-5, 0], [-4, -3]]) P.dot(ball[0] + dx, ball[1] + dy, BONE); };
      const behind = atk && f === 1;
      if (behind) { drawChain(); drawBall(); }
      P.rect(cx - 6, 24 + lg, 5, 7 - lg, M.dskin); P.rect(cx + 2, 24 - lg, 5, 7 + lg, M.dskin);
      P.rect(cx - 7, 30, 6, 1, M.iron).rect(cx + 2, 30, 6, 1, M.iron);
      P.ell(cx, 18 + bob, 9, 8, M.dskin);
      P.ell(cx - 3, 15 + bob, 3.2, 2.4, M.skin); P.ell(cx + 3, 15 + bob, 3.2, 2.4, M.skin);
      for (const yy of [19, 21]) { P.dot(cx - 2, yy + bob, MAROON).dot(cx + 2, yy + bob, MAROON); }
      P.line(cx, 18 + bob, cx, 22 + bob, MAROON, 1);
      P.rect(cx - 5, 23 + bob, 11, 3, MAROON);
      P.line(cx - 7, 13 + bob, cx + 7, 22 + bob, BROWN, 1);
      for (const sd of [-1, 1]) P.ell(cx + sd * 9, 13 + bob, 4, 3.4, M.dskin);
      P.line(cx - 10, 14 + bob, cx - 11, 22 + bob, M.dskin, 4); P.ell(cx - 11, 23 + bob, 2.5, 2.5, M.dskin);
      P.line(cx + 10, 14 + bob, fist[0], fist[1] - 1, M.dskin, 4); P.ell(fist[0], fist[1], 2.5, 2.5, M.dskin);
      P.rect(cx - 12, 20 + bob, 3, 2, M.iron).rect(fist[0] - 1, fist[1] - 3, 3, 2, M.iron);
      P.rect(cx - 4, 10 + bob, 9, 3, M.iron); P.dot(cx, 13 + bob, SKY);
      P.ell(cx, 7 + bob, 3.6, 3.4, M.dskin);
      for (const sd of [-1, 1]) P.poly([[cx + sd * 2, 5 + bob], [cx + sd * 7, 1 + bob], [cx + sd * 9, -1 + bob + 3], [cx + sd * 8, 4 + bob], [cx + sd * 4, 7 + bob]], M.bone);
      P.dot(cx - 2, 7 + bob, YEL).dot(cx + 2, 7 + bob, YEL);
      P.rect(cx - 2, 9 + bob, 5, 1, K); P.dot(cx - 2, 8 + bob, WHITE).dot(cx + 2, 8 + bob, WHITE);
      if (!behind) { drawChain(); drawBall(); }
      if (atk) for (let k = 0; k < 4; k++) P.glow(ball[0] - (ball[0] - cx) * .15 * k, ball[1] - (ball[1] - 18) * .15 * k, k ? ORA : YEL);
    },
  };

  DEFS.peingeist = {
    name: 'Peingeist', w: 24, h: 28, scale: 3.4, kind: 'mob', role: 'Geist',
    desc: 'Ein gequälter Geist in Ketten. Verschwindet, taucht neben dir auf und schleudert Leerenblitze.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', cx = 12, bob = cyc(f, [0, -1, -2, -1]), y = 3 + bob;
      P.flame(cx - 6, y + 19, 13, 6, { seed: 7, dir: 1, pal: VOIDFIRE, sparks: false });
      P.poly([[cx - 5, y + 8], [cx + 5, y + 8], [cx + 8, y + 19], [cx + 6, y + 22], [cx + 3, y + 19], [cx, y + 23], [cx - 3, y + 19], [cx - 6, y + 22], [cx - 8, y + 19]], M.ghost);
      const reach = atk ? cyc(f, [2, 5, 6, 3]) : cyc(f, [0, 1, 0, -1]);
      for (const sd of [-1, 1]) {
        const hx = cx + sd * (8 + reach), hy = y + 13 - (atk ? reach : 0);
        P.line(cx + sd * 4, y + 10, hx, hy, M.pale, 1);
        P.dot(hx + sd, hy - 1, WHITE).dot(hx + sd, hy + 1, WHITE).dot(hx + sd * 2, hy, WHITE);
        P.rect(cx + sd * 6 - 1 + (sd > 0 ? 0 : 0), y + 11, 2, 2, M.iron);
        P.dot(cx + sd * 7, y + 14, SLATE).dot(cx + sd * 7, y + 16, STEEL).dot(cx + sd * 6, y + 18, SLATE);
      }
      P.ell(cx, y + 6, 4.4, 4.8, M.ghost);
      P.ell(cx, y + 7, 2.8, 3.2, BLK, { flat: true });
      P.dot(cx - 1, y + 6, atk ? WHITE : LILAC).dot(cx + 1, y + 6, atk ? WHITE : LILAC);
      if (atk) { P.rect(cx - 1, y + 8, 3, 2, VIO); P.flame(cx - 1, y + 2, 3, 3, { seed: 3, pal: VOIDFIRE, front: true, sparks: false }); }
    },
  };

  // ---------- floor bosses ----------
  DEFS.glutwaechter = {
    name: 'Glutwächter', w: 40, h: 42, scale: 4.2, kind: 'boss', floor: 1, role: 'Boss · Etage 1',
    desc: 'Ein Golem aus Obsidian, durch dessen Risse Lava pulsiert. Hämmert Schockwellen in den Boden und wirft glühende Brocken.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', cast = a === 'cast', run = a === 'run', cx = 20;
      const bob = run ? cyc(f, [0, -1, 0, -1]) : 0, lg = run ? cyc(f, [1, 0, -1, 0]) : 0, pulse = cyc(f, [ORA, YEL, ORA, RED]);
      P.rect(cx - 9, 30, 6, 11 - lg, M.obsid); P.rect(cx + 3, 30, 6, 11 + lg - 1, M.obsid);
      P.dot(cx - 6, 34, pulse).dot(cx + 6, 36, pulse);
      P.poly([[cx - 12, 12 + bob], [cx + 12, 12 + bob], [cx + 10, 31], [cx - 10, 31]], M.obsid);
      for (const seg of [[[-6, 14], [-2, 20], [-5, 27]], [[5, 15], [2, 22], [6, 28]], [[-1, 25], [1, 30]]]) {
        for (let k = 0; k < seg.length - 1; k++) P.line(cx + seg[k][0], seg[k][1] + bob, cx + seg[k + 1][0], seg[k + 1][1] + bob, k % 2 ? ORA : pulse, 1);
      }
      P.ell(cx, 20 + bob, 3, 3, M.lava); P.dot(cx, 19 + bob, WHITE);
      P.rect(cx - 4, 5 + bob, 8, 8, M.obsid);
      P.rect(cx - 3, 8 + bob, 6, 1, pulse); P.dot(cx - 2, 8 + bob, WHITE).dot(cx + 1, 8 + bob, WHITE);
      // fists: rise for the slam, low for the throw
      const fy = atk ? cyc(f, [22, 4, 8, 34]) : cast ? cyc(f, [22, 14, 10, 16]) : 26 + bob;
      for (const sd of [-1, 1]) {
        const sx = cx + sd * 13, fx = cx + sd * (atk && f >= 1 && f <= 2 ? 10 : 16);
        P.ell(sx, 13 + bob, 5, 4.5, M.obsid);
        P.flame(sx - 3, 10 + bob, 7, 5, { seed: 2 + sd });
        P.line(sx, 15 + bob, fx, fy - 2, M.obsid, 5);
        P.ell(fx, fy, 4.2, 4, M.obsid);
        P.dot(fx - 2, fy - 2, pulse).dot(fx, fy - 3, pulse).dot(fx + 2, fy - 2, pulse);
      }
      if (cast && f >= 1) { P.ell(cx + 16, fy - 6, 3, 3, M.lava); P.flame(cx + 13, fy - 7, 7, 5, { seed: 5, front: true }); }
      if (atk && f === 3) for (let k = -18; k <= 18; k += 2) P.glow(cx + k, 41, k % 4 ? ORA : YEL);
    },
  };

  DEFS.dreischlund = {
    name: 'Dreischlund', w: 46, h: 32, scale: 4.2, kind: 'boss', floor: 2, role: 'Boss · Etage 2',
    desc: 'Der dreiköpfige Höllenhund. Speit mit allen drei Mäulern Feuer im Fächer und springt quer durch den Raum.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) { houndBody(P, a, f, { x: 0, y: 0, heads: 3 }); },
  };

  DEFS.kesselbrut = {
    name: 'Kesselbrut', w: 40, h: 40, scale: 4.2, kind: 'boss', floor: 4, role: 'Boss · Etage 4',
    desc: 'Ein aufgedunsener Dämon, der aus einem Lavakessel wächst. Spuckt Lava im Bogen und brütet Magmaschleime aus.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', cast = a === 'cast', cx = 20, bob = cyc(f, [0, 0, -1, -1]);
      for (const dx of [-10, 0, 10]) P.rect(cx + dx - 2, 36, 4, 3, M.iron);
      P.ell(cx, 30, 15, 8, M.iron);
      for (const dx of [-9, -3, 3, 9]) P.line(cx + dx, 26, cx + dx, 36, COAL, 1);
      const sw = cyc(f, [0, 1, 0, -1]);
      P.ell(cx, 18 + bob, 10 + (cast ? 1 : 0), 10, M.dskin);
      P.ell(cx + 1, 21 + bob, 6.5, 6, M.skin);
      for (const [dx, dy] of [[-4, 21], [4, 23], [0, 26]]) P.dot(cx + dx, dy + bob, MAROON);
      const ay = cast ? -8 : 0;
      for (const sd of [-1, 1]) { P.line(cx + sd * 9, 16 + bob, cx + sd * 15, 24 + ay, M.dskin, 3); P.ell(cx + sd * 15, 25 + ay, 2, 2, M.dskin); }
      P.rect(cx - 16, 23, 32, 3, M.iron);
      P.ell(cx, 24, 13, 1.6, M.lava, { flat: true });
      for (let k = 0; k < 4; k++) P.glow(cx - 9 + k * 6, 23 - ((f + k) % 4), cyc(k + f, [YEL, ORA, WHITE, ORA]));
      for (const sd of [-1, 1]) P.poly([[cx + sd * 4, 10 + bob], [cx + sd * 7, 4 + bob], [cx + sd * 6, 10 + bob]], M.bone);
      for (const [ex, ey] of [[-5, 13], [0, 11], [5, 13]]) { P.rect(cx + ex - 1, ey + bob, 3, 2, WHITE); P.dot(cx + ex, ey + 1 + bob, K); }
      const mo = atk ? cyc(f, [1, 3, 4, 2]) : 1;
      P.rect(cx - 5, 17 + bob, 11, mo + 1, K);
      for (let k = -4; k <= 4; k += 2) P.dot(cx + k, 17 + bob, WHITE);
      if (atk) { P.rect(cx - 3, 18 + bob, 7, mo - 1, MAROON); if (f >= 1) P.flame(cx - 3, 18 + bob + mo, 7, 5 + f, { seed: 1, dir: 1, front: true, pal: [WHITE, YEL, ORA, BORA, RED] }); }
      P.dot(cx - 8 + sw, 29, ORA).dot(cx + 9, 31, ORA);
    },
  };

  DEFS.seelenhirte = {
    name: 'Seelenhirte', w: 36, h: 48, scale: 4.2, kind: 'boss', floor: 5, role: 'Boss · Etage 5',
    desc: 'Ein Lich mit Geweih, der verlorene Seelen hütet. Seine Laterne treibt Seelen in Spiralen und ruft Aschenpriester.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', cast = a === 'cast', cx = 16, bob = cyc(f, [0, -1, -1, 0]);
      const lift = atk || cast ? cyc(f, [0, -3, -4, -2]) : 0;
      for (let k = 0; k < 5; k++) { const t = k / 5 * Math.PI * 2 + f * Math.PI / 8; P.glow(cx + Math.cos(t) * 15, 24 + Math.sin(t) * 7, k % 2 ? LIME : GREEN); P.glow(cx + Math.cos(t) * 15, 23 + Math.sin(t) * 7, WHITE); }
      const robe = [NEARBLK, COAL, STONE];
      P.poly([[cx - 5, 14 + bob], [cx + 5, 14 + bob], [cx + 10, 46], [cx + 7, 44], [cx + 4, 47], [cx + 1, 44], [cx - 2, 47], [cx - 5, 44], [cx - 8, 47], [cx - 10, 46]], robe);
      P.line(cx - 9, 44, cx + 9, 44, DGREEN, 1);
      P.line(cx, 16 + bob, cx, 42, GREEN, 1);
      for (const sd of [-1, 1]) P.ell(cx + sd * 5, 15 + bob, 3, 2.5, robe);
      // crook with a lantern
      const sx = cx + 12, st = 4 + bob + lift;
      P.line(sx, st + 2, sx, 46, M.iron, 1);
      P.line(sx, st + 2, sx - 1, st - 1, M.iron, 1); P.line(sx - 1, st - 1, sx - 4, st - 1, M.iron, 1); P.line(sx - 4, st - 1, sx - 5, st + 2, M.iron, 1);
      P.line(sx - 5, st + 3, sx - 5, st + 5, SLATE, 1);
      P.rect(sx - 7, st + 6, 5, 5, M.iron); P.rect(sx - 6, st + 7, 3, 3, LIME);
      P.flame(sx - 7, st + 6, 5, cast ? 8 : 4, { seed: 3, pal: SOULFIRE, front: true });
      P.line(cx + 5, 17 + bob, sx - 1, 24 + bob + lift, M.pale, 1);
      const la = cast ? -9 : 0;
      P.line(cx - 5, 17 + bob, cx - 9, 26 + bob + la, M.pale, 1);
      if (cast) P.flame(cx - 12, 17 + bob, 6, 7, { seed: 9, pal: SOULFIRE, front: true });
      // antlered skull
      const hy = 9 + bob;
      for (const sd of [-1, 1]) {
        P.line(cx + sd * 2, hy - 3, cx + sd * 6, hy - 9, M.bone, 1); P.line(cx + sd * 6, hy - 9, cx + sd * 9, hy - 10, M.bone, 1);
        P.line(cx + sd * 4, hy - 6, cx + sd * 8, hy - 5, M.bone, 1); P.line(cx + sd * 6, hy - 9, cx + sd * 6, hy - 12, M.bone, 1);
      }
      P.ell(cx, hy, 3.6, 3.8, M.bone);
      P.rect(cx - 2, hy + 2, 5, 2, M.bone);
      P.rect(cx - 3, hy - 1, 2, 2, K).rect(cx + 1, hy - 1, 2, 2, K); P.dot(cx - 2, hy, LIME).dot(cx + 2, hy, LIME);
      P.dot(cx - 1, hy + 3, K).dot(cx + 1, hy + 3, K);
      P.poly([[cx - 6, hy - 2], [cx + 6, hy - 2], [cx + 7, hy + 6], [cx - 7, hy + 6]], robe);
      P.ell(cx, hy, 3.6, 3.8, M.bone);
      P.rect(cx - 3, hy - 1, 2, 2, K).rect(cx + 1, hy - 1, 2, 2, K); P.dot(cx - 2, hy, LIME).dot(cx + 2, hy, LIME);
      P.rect(cx - 2, hy + 2, 5, 1, K); P.dot(cx - 1, hy + 2, BONE).dot(cx + 1, hy + 2, BONE);
    },
  };

  DEFS.kerkermeister = {
    name: 'Kerkermeister', w: 44, h: 44, scale: 4.2, kind: 'boss', floor: 7, role: 'Boss · Etage 7',
    desc: 'Der Henker der Hölle mit Kapuze und Fleischerbeil. Zieht dich mit Hakenketten heran und spaltet den Boden.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', cast = a === 'cast', run = a === 'run', cx = 20, bob = run ? cyc(f, [0, -1, 0, -1]) : cyc(f, [0, 0, 1, 1]);
      const lg = run ? cyc(f, [1, 0, -1, 0]) : 0;
      // cleaver: hand position and blade direction per frame
      const H = atk ? cyc(f, [[cx + 12, 20], [cx + 6, 4], [cx + 4, 2], [cx + 14, 30]]) : [cx + 13, 26 + bob];
      const up = atk && (f === 1 || f === 2);
      if (up) drawCleaver(P, H, true);
      P.rect(cx - 7, 31, 6, 12 - lg, M.dskin); P.rect(cx + 1, 31, 6, 12 + lg - 1, M.dskin);
      P.rect(cx - 8, 39 - lg, 8, 4, M.iron); P.rect(cx, 39, 8, 4, M.iron);
      P.rect(cx - 9, 28, 18, 5, BROWN);
      for (const k of [-6, 0, 6]) { P.dot(cx + k, 33, SKY).dot(cx + k, 35, STEEL).dot(cx + k, 37, SKY); P.dot(cx + k + 1, 38, BONE).dot(cx + k + 1, 39, BONE); }
      P.poly([[cx - 11, 12 + bob], [cx + 11, 12 + bob], [cx + 8, 29], [cx - 8, 29]], M.skin);
      P.line(cx - 10, 13 + bob, cx + 7, 28, BROWN, 2);
      P.ell(cx - 3, 18 + bob, 3, 2.4, M.skin); P.ell(cx + 3, 18 + bob, 3, 2.4, M.skin);
      for (const sd of [-1, 1]) P.ell(cx + sd * 11, 14 + bob, 4.5, 4, M.skin);
      const lh = cast ? [cx - 20, 14 + bob] : [cx - 14, 26 + bob];
      P.line(cx - 12, 15 + bob, lh[0], lh[1], M.skin, 4); P.ell(lh[0], lh[1], 2.5, 2.5, M.skin); P.rect(lh[0] - 1, lh[1] - 4, 3, 2, M.iron);
      if (cast) { for (let k = 1; k < 9; k++) P.dot(lh[0] - k * 2 + 4, lh[1] - 1 + (k % 2), k % 2 ? SKY : STEEL); P.poly([[1, lh[1] - 3], [4, lh[1] - 1], [2, lh[1] + 2]], M.steel); }
      else for (let k = 1; k < 6; k++) P.dot(lh[0] - (k % 2), lh[1] + 2 + k * 2, k % 2 ? SKY : STEEL);
      P.line(cx + 12, 15 + bob, H[0], H[1], M.skin, 4); P.ell(H[0], H[1], 2.5, 2.5, M.skin);
      // hood with eye holes
      P.poly([[cx, -1 + bob], [cx - 7, 7 + bob], [cx - 7, 13 + bob], [cx + 7, 13 + bob], [cx + 7, 7 + bob]], [NEARBLK, COAL, STONE]);
      P.rect(cx - 4, 6 + bob, 3, 2, K).rect(cx + 1, 6 + bob, 3, 2, K); P.dot(cx - 3, 6 + bob, RED).dot(cx + 2, 6 + bob, RED);
      if (!up) drawCleaver(P, H, false);
      if (atk && f === 3) for (let k = -16; k <= 16; k += 2) P.glow(cx + 14 + k * .3, 42 - Math.abs(k) * .2, k % 4 ? ORA : YEL);
    },
  };
  function drawCleaver(P, H, up) {
    const [hx, hy] = H;
    if (up) {
      P.line(hx, hy + 6, hx, hy - 3, BROWN, 2);
      P.poly([[hx - 1, hy - 3], [hx - 1, hy - 13], [hx + 10, hy - 15], [hx + 12, hy - 4], [hx + 2, hy - 2]], M.steel);
      P.line(hx + 10, hy - 15, hx + 12, hy - 4, WHITE, 1); P.dot(hx + 11, hy - 8, CRIM).dot(hx + 12, hy - 6, CRIM); P.dot(hx + 2, hy - 10, K);
    } else {
      P.line(hx, hy - 3, hx, hy + 5, BROWN, 2);
      P.poly([[hx + 1, hy + 4], [hx + 12, hy + 3], [hx + 14, hy + 15], [hx + 3, hy + 15], [hx + 1, hy + 11]], M.steel);
      P.line(hx + 4, hy + 15, hx + 14, hy + 15, WHITE, 1); P.dot(hx + 8, hy + 15, CRIM).dot(hx + 11, hy + 15, CRIM); P.dot(hx + 5, hy + 6, K);
    }
  }

  DEFS.klagender_hueter = {
    name: 'Klagender Hüter', w: 46, h: 46, scale: 4.2, kind: 'boss', floor: 8, role: 'Boss · Etage 8',
    desc: 'Eine riesige Klagegestalt in Ketten. Ihr Schrei verlangsamt, und aus dem Boden greifen Geisterhände.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const atk = a === 'attack', cast = a === 'cast', cx = 23, bob = cyc(f, [0, -1, -2, -1]), y = 4 + bob;
      P.flame(cx - 10, y + 33, 21, 9, { seed: 4, dir: 1, pal: VOIDFIRE, sparks: false });
      P.poly([[cx - 8, y + 14], [cx + 8, y + 14], [cx + 12, y + 32], [cx + 8, y + 36], [cx + 4, y + 33], [cx, y + 38], [cx - 4, y + 33], [cx - 8, y + 36], [cx - 12, y + 32]], M.wingV);
      for (const k of [-6, 0, 6]) P.line(cx + k * .6, y + 16, cx + k, y + 33, INDIGO, 1);
      const wide = atk || cast ? cyc(f, [2, 5, 6, 4]) : cyc(f, [0, 1, 1, 0]);
      for (const sd of [-1, 1]) {
        const hx = cx + sd * (17 + wide), hy = y + (cast ? 6 : 18) - wide;
        P.line(cx + sd * 7, y + 16, hx, hy, M.pale, 2);
        for (let k = -1; k <= 1; k++) P.line(hx, hy, hx + sd * 3, hy + k * 2 - 1, WHITE, 1);
        P.rect(cx + sd * 12 - 1 + (sd < 0 ? -1 : 0), y + 15 - Math.round(wide / 2), 3, 3, M.iron);
        for (let k = 1; k < 5; k++) P.dot(cx + sd * 12, y + 18 + k * 2 - Math.round(wide / 2), k % 2 ? SKY : STEEL);
      }
      // long hair framing a hollow face
      P.poly([[cx - 6, y + 1], [cx + 6, y + 1], [cx + 11, y + 24], [cx + 7, y + 19], [cx + 4, y + 26], [cx, y + 17], [cx - 4, y + 26], [cx - 7, y + 19], [cx - 11, y + 24]], M.ghost);
      P.ell(cx, y + 6, 6, 6.2, M.ghost);
      P.ell(cx, y + 9, 3.6, 5, M.pale);
      P.rect(cx - 3, y + 6, 2, 4, BLK).rect(cx + 2, y + 6, 2, 4, BLK);
      P.dot(cx - 2, y + 7, CYAN).dot(cx + 2, y + 7, CYAN);
      P.dot(cx - 3, y + 11, CYAN).dot(cx - 3, y + 13, CYAN).dot(cx + 3, y + 12, CYAN);
      const mo = atk ? cyc(f, [2, 4, 5, 3]) : 2;
      P.ell(cx, y + 11 + mo / 2, 1.6, mo / 2 + .6, K, { flat: true });
      if (atk && f >= 1) for (let r = 7; r <= 13; r += 3) for (let k = -3; k <= 3; k++) P.glow(cx + k * r * .28, y + 12 + mo + r - Math.abs(k) * .8 + f, (r + k) % 2 ? CYAN : WHITE);
    },
  };

  // ---------- Ignaroth, one dragon in four phases (floors 3, 6, 9, 10) ----------
  const drakeDef = (p, w, h, name, role, desc) => ({ name, w, h, scale: 5, kind: 'lord', floor: [0, 3, 6, 9, 10][p], phase: p, role, desc,
    anims: Object.assign({ idle: 8, run: 8, attack: 8, cast: 8 }, p >= 3 ? { fly: 8 } : {}), draw(P, a, f) { drake(P, p, a, f); } });
  DEFS.drache1 = drakeDef(1, 34, 30, 'Ignaroth · Salamander', 'Boss · Etage 3 · Phase I',
    'Ein flinker Glutsalamander auf zwei Beinen, schon größer als du, mit einem Funken am Schwanz. Springt, spuckt, huscht und gräbt sich ein. Bei 0 LP stirbt er nicht: Er verwandelt sich und verschwindet im Boden.');
  DEFS.drache2 = drakeDef(2, 40, 36, 'Ignaroth · Jungdrache', 'Boss · Etage 6 · Phase II',
    'Hörner, Zähne, längere Krallen und eine größere Schwanzflamme. Noch flügellos, aber schneller und härter: Doppelsprünge, Feuersalven, Schwanzwirbel, Lavaausbrüche aus dem Boden.');
  DEFS.drache3 = drakeDef(3, 70, 62, 'Ignaroth · Glutdrache', 'Boss · Etage 9 · Phase III',
    'Ausgewachsen mit großen Hörnern, großem Maul und zwei Schwingen. Fliegt ein, greift aus der Luft an und ist dort unverwundbar. Feuerfächer, schwenkender Feueratem, Feuerringe und Bombenflüge.');
  DEFS.drache4 = drakeDef(4, 100, 80, 'Ignaroth · Obsidianform', 'Endboss · Etage 10 · Phase IV',
    'Die ultimative Form aus Obsidian und Gold mit Leerenfeuer. Ruft die Geister seiner drei früheren Formen zurück, die neben ihm kämpfen. Drehende Leerenstrahlen, Leerenregen aus der Luft, Sternringe. Erst hier stirbt er.');

  // ---------- behaviour and attacks ----------
  // ai: chase (runs at you), hover (flies in loops), keep (holds distance), hop (moves in jumps),
  // drift (floats slowly), skirmish (darts in and out). hp is for floor 1 before the floor's toughness factor; bosses use the
  // floor's boss HP times hpMul. r = hit radius in world px. Attack kinds the preview runs:
  // dash, lob, bolt, homing, ring, spiral, slam, swing, summon, teleport, trail, meteors,
  // chain, scream, hands, beam, breath, burrow, flight, sweep, echoes. repeat = chained uses. every = seconds between uses, range = max distance.
  const A = (id, name, kind, every, o) => Object.assign({ id, name, kind, every }, o || {});
  const STATS = {
    glutschaedel: { hp: 3, speed: 170, r: 26, ai: 'hover', attacks: [A('biss', 'Sturzbiss', 'dash', 2.6, { range: 420, speed: 820, desc: 'Zielt kurz, dann rast er beißend auf dich zu.' })] },
    hoellenhund: { hp: 5, speed: 205, r: 30, ai: 'chase', attacks: [A('sprung', 'Hetzsprung', 'dash', 3.2, { range: 480, speed: 900, desc: 'Duckt sich, springt dich an und beißt.' }), A('glut', 'Glutatem', 'breath', 5, { range: 260, count: 7, desc: 'Kurzer Feuerstoß aus dem Maul.' })] },
    glutimp: { hp: 3, speed: 150, r: 24, ai: 'keep', keep: 380, attacks: [A('feuerball', 'Feuerball', 'lob', 2.4, { range: 700, radius: 64, desc: 'Wirft einen Feuerball im Bogen; die Landestelle glüht vorher auf.' })] },
    brandskelett: { hp: 6, speed: 130, r: 28, ai: 'chase', attacks: [A('hieb', 'Glutklinge', 'swing', 1.8, { range: 150, radius: 150, arc: 2.2, desc: 'Weiter Schwerthieb vor sich.' })] },
    magmaschleim: { hp: 7, speed: 120, r: 30, ai: 'hop', attacks: [A('sprung', 'Lavasprung', 'slam', 2.2, { range: 260, radius: 110, desc: 'Springt dich an; beim Aufprall spritzt Lava im Kreis.' }), A('spur', 'Schlackenspur', 'trail', 0, { desc: 'Wo er landet, brennt der Boden kurz.' })] },
    aschenpriester: { hp: 6, speed: 100, r: 26, ai: 'keep', keep: 460, attacks: [A('seele', 'Seelenflamme', 'homing', 3, { range: 800, speed: 260, desc: 'Eine grüne Flamme, die dir langsam folgt.' }), A('ruf', 'Schädelruf', 'summon', 8, { mobs: ['glutschaedel', 'glutschaedel'], max: 3, desc: 'Ruft zwei Glutschädel herbei.' })] },
    kettenschinder: { hp: 16, speed: 85, r: 38, ai: 'chase', attacks: [A('kreis', 'Kugelkreis', 'swing', 3.4, { range: 200, radius: 190, arc: 6.3, desc: 'Lässt die Stachelkugel einmal rundum kreisen.' }), A('wurf', 'Kettenwurf', 'chain', 6, { range: 520, speed: 700, desc: 'Schleudert die Kugel und zieht dich heran.' })] },
    peingeist: { hp: 5, speed: 90, r: 26, ai: 'drift', attacks: [A('sprung', 'Leerensprung', 'teleport', 4.5, { range: 900, desc: 'Verschwindet und taucht neben dir auf.' }), A('blitz', 'Leerenblitz', 'bolt', 2.6, { range: 700, speed: 520, count: 3, spread: .35, desc: 'Drei violette Blitze im Fächer.' })] },

    glutwaechter: { hpMul: 1, speed: 80, r: 72, ai: 'chase', adds: ['magmaschleim', 'glutschaedel'], attacks: [A('stampfer', 'Glutstampfer', 'slam', 3.6, { range: 360, radius: 300, desc: 'Hebt die Fäuste und hämmert eine Schockwelle aus.' }), A('brocken', 'Glutbrocken', 'lob', 3, { range: 900, count: 3, radius: 80, desc: 'Wirft drei glühende Brocken.' }), A('kern', 'Kernbruch', 'ring', 7, { count: 14, speed: 300, desc: 'Sein Kern platzt auf: ein Ring aus Lava.' })] },
    dreischlund: { hpMul: 1, speed: 140, r: 70, ai: 'chase', adds: ['hoellenhund'], attacks: [A('atem', 'Dreifacher Glutatem', 'breath', 3.2, { range: 420, count: 15, heads: 3, desc: 'Alle drei Köpfe speien Feuer im Fächer.' }), A('satz', 'Höllensatz', 'dash', 4.2, { range: 700, speed: 980, desc: 'Springt mit Warnlinie quer durch den Raum.' }), A('rudel', 'Rudelruf', 'summon', 9, { mobs: ['hoellenhund', 'hoellenhund'], max: 4, desc: 'Heult zwei Höllenhunde herbei.' })] },
    kesselbrut: { hpMul: 1, speed: 45, r: 74, ai: 'drift', adds: ['magmaschleim'], attacks: [A('spucke', 'Lavaspucke', 'lob', 2.2, { range: 900, count: 4, radius: 80, desc: 'Spuckt Lava in hohen Bögen.' }), A('brut', 'Brut', 'summon', 7, { mobs: ['magmaschleim', 'magmaschleim'], max: 5, desc: 'Brütet Magmaschleime aus.' }), A('ueberkochen', 'Überkochen', 'ring', 6, { count: 18, speed: 240, desc: 'Der Kessel kocht über: Ring aus Lava.' })] },
    seelenhirte: { hpMul: 1, speed: 70, r: 64, ai: 'keep', keep: 420, adds: ['aschenpriester', 'peingeist'], attacks: [A('spirale', 'Seelenspirale', 'spiral', 6, { duration: 3, rate: .09, arms: 3, speed: 280, desc: 'Drei Arme aus Seelenflammen drehen sich aus der Laterne.' }), A('herde', 'Seelenherde', 'homing', 3.4, { range: 900, speed: 230, count: 3, desc: 'Drei suchende Seelen.' }), A('ruf', 'Hirtenruf', 'summon', 11, { mobs: ['aschenpriester', 'peingeist'], max: 3, desc: 'Ruft Aschenpriester und Peingeist.' })] },
    kerkermeister: { hpMul: 1, speed: 105, r: 72, ai: 'chase', adds: ['kettenschinder', 'brandskelett'], attacks: [A('haken', 'Hakenkette', 'chain', 4, { range: 700, speed: 760, desc: 'Wirft eine Hakenkette und zieht dich heran.' }), A('spalter', 'Bodenspalter', 'slam', 3.4, { range: 300, radius: 260, line: true, desc: 'Das Beil spaltet den Boden in einer Linie.' }), A('kerker', 'Kerkerruf', 'summon', 12, { mobs: ['kettenschinder'], max: 2, desc: 'Ruft einen Kettenschinder.' })] },
    klagender_hueter: { hpMul: 1, speed: 70, r: 70, ai: 'drift', adds: ['peingeist'], attacks: [A('schrei', 'Klageschrei', 'scream', 5, { range: 520, arc: 1.2, desc: 'Ein Schrei im Kegel: Schaden und 2 s verlangsamt.' }), A('haende', 'Grabeshände', 'hands', 4, { count: 5, radius: 70, desc: 'Geisterhände greifen aus dem Boden unter dir.' }), A('tränen', 'Tränenregen', 'ring', 3, { count: 20, speed: 220, desc: 'Ein Ring aus Seelentränen.' })] },
    // Ignaroth. Phase 1 is small and quick: spit, pounce, dash, burrow. From phase 3 on he flies
    // (cannot be hit in the air) and fights from range; phase 4 calls back his earlier forms.
    drache1: { hpMul: 1, speed: 235, r: 44, ai: 'skirmish', intro: 'burrow', attacks: [A('spucke', 'Glutspucke', 'bolt', 1.7, { range: 760, speed: 600, count: 1, desc: 'Spuckt schnelle Feuerbälle.' }), A('satz', 'Sprungangriff', 'slam', 3.3, { range: 560, radius: 140, leap: true, desc: 'Springt dich an; beim Aufprall glüht der Boden.' }), A('huschen', 'Huschen', 'dash', 2.4, { range: 480, speed: 1050, desc: 'Blitzschneller Dash mit Biss.' }), A('graben', 'Eingraben', 'burrow', 7.5, { ring: 10, radius: 150, desc: 'Gräbt sich ein, wühlt unter dir hindurch und bricht mit einem Glutring hervor.' })] },
    drache2: { hpMul: 1, speed: 215, r: 54, ai: 'skirmish', intro: 'burrow', attacks: [A('salve', 'Feuersalve', 'bolt', 2.2, { range: 800, speed: 640, count: 3, spread: .32, desc: 'Drei Feuerbälle im Fächer.' }), A('doppelsatz', 'Doppelsprung', 'slam', 3.6, { range: 620, radius: 170, leap: true, repeat: 2, desc: 'Zwei Sprungangriffe direkt hintereinander.' }), A('hatz', 'Hetzjagd', 'dash', 3, { range: 520, speed: 1100, repeat: 2, desc: 'Zwei Dashs hintereinander.' }), A('schwanz', 'Schwanzwirbel', 'swing', 4, { range: 220, radius: 210, arc: 6.3, desc: 'Dreht sich und fegt mit dem brennenden Schwanz rundum.' }), A('lavabruch', 'Lavabruch', 'burrow', 7, { ring: 16, radius: 180, lava: true, desc: 'Bricht unter dir hervor und lässt Lava zurück.' })] },
    drache3: { hpMul: 1, speed: 150, r: 86, ai: 'chase', intro: 'flyin', attacks: [A('faecher', 'Feuerfächer', 'bolt', 2.6, { range: 900, speed: 540, count: 7, spread: 1.05, desc: 'Sieben Feuerbälle im weiten Fächer.' }), A('atem', 'Glutatem', 'sweep', 5.4, { duration: 1.7, arc: 1.6, rate: .035, speed: 520, desc: 'Schwenkt einen Feuerstrahl in breitem Bogen über die Arena.' }), A('kreise', 'Feuerkreise', 'ring', 4.4, { count: 18, speed: 300, waves: 2, desc: 'Zwei versetzte Feuerringe.' }), A('bombenflug', 'Bombenflug', 'flight', 11, { duration: 4.2, drop: .5, radius: 95, desc: 'Steigt auf, ist in der Luft unverwundbar, wirft Feuerbomben auf dich und landet mit einer Schockwelle.' })] },
    drache4: { hpMul: 1, speed: 140, r: 112, ai: 'chase', intro: 'flyin', attacks: [A('echos', 'Echos der Glut', 'echoes', 17, { first: 4, life: 10, desc: 'Ruft die Geister seiner drei früheren Formen. Salamander, Jungdrache und Glutdrache kämpfen als violette Echos mit.' }), A('strahlen', 'Leerenstrahlen', 'beam', 9, { duration: 3.6, beams: 3, turn: 1.0, desc: 'Drei Strahlen aus Leerenfeuer drehen sich durch die Arena.' }), A('leerenregen', 'Leerenregen', 'flight', 12, { duration: 4.6, drop: .38, radius: 105, void: true, desc: 'Fliegt auf und lässt Leerenfeuer regnen; in der Luft unverwundbar.' }), A('sterne', 'Sternringe', 'ring', 4.2, { count: 20, speed: 290, waves: 3, void: true, desc: 'Drei versetzte Ringe aus Leerenfeuer.' }), A('atem', 'Leerenatem', 'sweep', 6, { duration: 1.9, arc: 1.8, rate: .03, speed: 560, void: true, desc: 'Ein schwenkender Strahl aus violettem Feuer.' })] },
  };
  for (const id in STATS) DEFS[id].stats = STATS[id];

  // Which monsters each floor sends, and its boss. Deeper floors mix in the later kinds.
  const FLOORS = {
    1: { mobs: ['glutschaedel', 'brandskelett', 'magmaschleim'], boss: 'glutwaechter' },
    2: { mobs: ['glutschaedel', 'brandskelett', 'hoellenhund', 'magmaschleim'], boss: 'dreischlund' },
    3: { mobs: ['brandskelett', 'hoellenhund', 'glutimp', 'glutschaedel'], boss: 'drache1' },
    4: { mobs: ['glutimp', 'magmaschleim', 'hoellenhund', 'aschenpriester'], boss: 'kesselbrut' },
    5: { mobs: ['aschenpriester', 'glutimp', 'brandskelett', 'peingeist'], boss: 'seelenhirte' },
    6: { mobs: ['hoellenhund', 'glutimp', 'aschenpriester', 'kettenschinder'], boss: 'drache2' },
    7: { mobs: ['kettenschinder', 'brandskelett', 'peingeist', 'glutimp'], boss: 'kerkermeister' },
    8: { mobs: ['peingeist', 'aschenpriester', 'hoellenhund', 'kettenschinder'], boss: 'klagender_hueter' },
    9: { mobs: ['kettenschinder', 'peingeist', 'aschenpriester', 'hoellenhund', 'glutimp'], boss: 'drache3' },
    10: { mobs: ['kettenschinder', 'peingeist', 'hoellenhund', 'aschenpriester', 'glutimp', 'brandskelett'], boss: 'drache4' },
  };

  // ---------- rendering ----------
  function frameCount(def, anim) { return anim === 'death' ? 6 : (def.anims[anim] || 4); }
  // Returns { w, h, px: array of colour strings or null } for one frame.
  function renderColors(id, anim, frame) {
    const def = DEFS[id];
    if (anim === 'death') return deathColors(def, renderColors(id, 'idle', 0), frame);
    const p = new Painter(def.w, def.h, frame);
    def.draw(p, anim, frame);
    return { w: def.w, h: def.h, px: p.finish() };
  }
  // Death: the body cools and crumbles from the top into embers and ash.
  function deathColors(def, base, frame) {
    const { w, h } = base, out = new Array(w * h).fill(null), k = frame / 5;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const c = base.px[y * w + x]; if (!c) continue;
      const r = ((x * 73856093) ^ (y * 19349663)) % 997 / 997, gone = r < k * 1.15 - (y / h) * .35;
      if (gone) continue;
      const fall = Math.floor(k * k * 6 * (1 - y / h) + (r < k ? 1 : 0)), yy = Math.min(h - 1, y + fall);
      const hot = r < k * 1.6 && c !== K;
      out[yy * w + x] = hot ? (r < k * .7 ? ORA : r < k * 1.2 ? RED : CRIM) : c;
    }
    return { w, h, px: out };
  }
  function hexToRgb(c) { return [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)]; }
  function render(id, anim, frame) {
    const r = renderColors(id, anim, frame), data = new Uint8ClampedArray(r.w * r.h * 4);
    r.px.forEach((c, i) => { if (c) { const [R, G, B] = hexToRgb(c); data.set([R, G, B, 255], i * 4); } });
    return { w: r.w, h: r.h, data };
  }
  return { DEFS, FLOORS, render, frameCount, ANIMS: ['idle', 'run', 'attack', 'cast', 'fly', 'death'] };
});

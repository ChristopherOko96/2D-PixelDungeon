// Crypt monsters (Story 1, Krypta der Verdammten) for the Hell-Dungeon runtime.
// Same interface as tools/hell_dungeon/hell_monsters.js (DEFS, FLOORS, render, frameCount, ANIMS),
// so the hell preview's AI and attack code runs them unchanged. The figures are the crypt's own
// 0x72 actors (skeletons, necromancer, zombies, mimic) and the Leerenrufer, painted from
// krypta_pix.js; attacks add weapons, glows and poses on top. The pixel painter mirrors the hell
// one: a 1 px #222222 outline around everything solid, flames and glows outside the outline.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('./krypta_pix.js'));
  else root.HellMonsters = factory(root.KRYPTA_PIX);
})(typeof self !== 'undefined' ? self : this, function (PIX) {
  'use strict';

  // ---------- palette (0x72 DungeonTileset II) ----------
  const K = '#222222', WHITE = '#fdf7ed', BONE = '#d3bfa9', TAN = '#aa8d7a', MUD = '#775c55', STONE = '#483b3a';
  const GREEN = '#4ba747', DGREEN = '#3d734f', LIME = '#97da3f', CYAN = '#72d6ce', STEEL = '#417089', SKY = '#5698cc';
  const VIO = '#c278d0', VIOD = '#8156aa', INDIGO = '#473579', LILAC = '#f0b3dd', YEL = '#facb3e', ORA = '#ee8e2e', BORA = '#c56025';
  const RED = '#da4e38', CRIM = '#9f294e';
  const SOULFIRE = [WHITE, LIME, GREEN, DGREEN, DGREEN];
  const VOIDFIRE = [LILAC, VIO, VIOD, INDIGO, INDIGO];
  const FROSTFIRE = [WHITE, '#c8f4ff', CYAN, SKY, STEEL];
  const GOLDFIRE = [WHITE, YEL, ORA, BORA, BORA];

  // ---------- painter (as in hell_monsters.js) ----------
  function Painter(w, h, frame) { this.w = w; this.h = h; this.f = frame || 0; this.solid = new Array(w * h).fill(null); this.back = []; this.front = []; }
  const P = Painter.prototype;
  P.inside = function (x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; };
  P.dot = function (x, y, c) { x = Math.round(x); y = Math.round(y); if (this.inside(x, y)) this.solid[y * this.w + x] = c; return this; };
  P.glow = function (x, y, c) { this.front.push([Math.round(x), Math.round(y), c]); return this; };
  P.flame = function (x0, base, w, h, opt) {
    opt = opt || {};
    x0 = Math.round(x0); base = Math.round(base); w = Math.max(1, Math.round(w)); h = Math.max(1, Math.round(h));
    const pal = opt.pal || SOULFIRE, layer = opt.front ? this.front : this.back, seed = opt.seed || 0;
    const ph = (this.f % 4) / 4 * Math.PI * 2, lean = opt.lean || 0;
    for (let i = 0; i < w; i++) {
      const u = w > 1 ? i / (w - 1) : .5, taper = 1 - Math.pow(Math.abs(u - .5) * 2, 1.6) * .75;
      const n = .5 + .3 * Math.sin(i * 1.9 + seed + ph) + .2 * Math.sin(i * .7 - seed * 1.3 + ph * 2);
      const hh = Math.max(1, Math.round(h * taper * (.68 + .32 * n)));
      for (let j = 0; j < hh; j++) {
        const fr = j / hh, core = Math.abs(u - .5) < (w > 8 ? .1 : .22) && fr < (h > 6 ? .14 : .3);
        const c = core ? pal[0] : fr < .3 ? pal[1] : fr < .62 ? pal[2] : fr < .86 ? pal[3] : pal[4];
        layer.push([Math.round(x0 + i + lean * j / Math.max(1, h)), base - j, c]);
      }
    }
    return this;
  };
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
  // Stamps a packed frame. Near-black outline pixels are left out: finish() draws the outline.
  // o: k (integer upscale), flip, map (colour -> colour), rot (radians around pivot px, py), skip (keep dark pixels when false).
  P.sprite = function (name, x, y, o) {
    o = o || {};
    const s = PIX[name], k = o.k || 1, map = o.map || {};
    const cos = Math.cos(o.rot || 0), sin = Math.sin(o.rot || 0), px = o.px ?? s.w / 2, py = o.py ?? s.h;
    for (let sy = 0; sy < s.h; sy++) for (let sx = 0; sx < s.w; sx++) {
      const ch = s.px[sy * s.w + sx]; if (ch === '.') continue;
      let c = s.pal[CH.indexOf(ch)];
      if (o.skip !== false && (c === K || c === '#000000')) continue;
      c = map[c] || c;
      const fx = o.flip ? s.w - 1 - sx : sx;
      for (let a = 0; a < k; a++) for (let b = 0; b < k; b++) {
        let dx = fx * k + b - px * k, dy = sy * k + a - py * k;
        if (o.rot) { const rx = dx * cos - dy * sin, ry = dx * sin + dy * cos; dx = rx; dy = ry; }
        this.dot(x + dx, y + dy, c);
      }
    }
    return this;
  };
  const CH = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&()*+,-/:;<=>?@[]^_{|}~';
  const cyc = (f, list) => list[f % list.length];
  const sparkle = (P, cx, cy, r, n, pal, seed) => { for (let i = 0; i < n; i++) { const a = (i / n) * 6.283 + P.f * .7 + seed, rr = r * (.6 + .4 * Math.sin(i * 2.3 + P.f)); P.glow(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * .8, pal[i % 3]); } };

  // A standing figure: idle/run frames of a 0x72 actor, feet on the bottom row, a weapon in the
  // front hand. o: base (frame name stem), run, frames, k (upscale), weapon, map, hand [x, y] in
  // source pixels, grip (weapon angle at rest), cast (glow palette).
  function figure(P, a, f, o) {
    const k = o.k || 1, src = PIX[(a === 'run' && o.run ? o.run : o.base) + (o.frames ? f % o.frames : '')] || PIX[o.base], ground = P.h - 1;
    const atk = a === 'attack', cast = a === 'cast';
    const lean = atk ? cyc(f, [0, 1, 2, 1]) * k : 0, hop = o.bob ? cyc(f, [0, -1, -1, 0]) * k : 0;
    const x = Math.round((P.w - src.w * k) / 2) + lean, y = ground - src.h * k + 1 + hop;
    const name = (a === 'run' && o.run ? o.run : o.base) + (o.frames ? f % o.frames : '');
    P.sprite(PIX[name] ? name : o.base, x, y, { k, map: o.map, px: 0, py: 0 });
    if (o.weapon) {
      const [hx, hy] = o.hand || [12, 11];
      const swing = atk ? cyc(f, o.swing || [-.7, .2, 1.4, 2.0]) : cast ? -.5 : (o.grip ?? .35) + (a === 'run' ? cyc(f, [0, .12, 0, -.12]) : 0);
      const ws = PIX['weapon_' + o.weapon];
      P.sprite('weapon_' + o.weapon, x + hx * k, y + hy * k, { k: o.wk || k, rot: swing, px: ws.w / 2, py: ws.h - 3, map: o.wmap });
    }
    if (cast && o.cast) sparkle(P, x + (o.hand ? o.hand[0] : 12) * k, y + (o.hand ? o.hand[1] : 10) * k - 2 * k, 4 * k, 9, o.cast, 0);
    if (o.eyes) for (const [ex, ey] of o.eyes) P.glow(x + ex * k, y + ey * k, o.eyeC || LIME);
    return { x, y, k };
  }

  // ---------- recolours ----------
  const FROST = { '#4ba747': '#b6cbcf', '#97da3f': '#fdf7ed', '#775c55': '#417089', '#aa8d7a': '#72d6ce', '#483b3a': '#2a2a3a' };
  const BONEMAP = { '#4ba747': '#8a8a8a', '#97da3f': '#c9c9c9', '#775c55': '#aa8d7a', '#aa8d7a': '#fdf7ed', '#483b3a': '#5f2d56', '#333333': '#3d2140' };
  const MODER = { '#4ba747': '#3d734f', '#97da3f': '#4ba747', '#aa8d7a': '#97da3f' };
  const GUARD = { '#fdf7ed': '#d3bfa9', '#d3bfa9': '#aa8d7a' };
  const ARCHIVE = { '#62232f': '#314152', '#9f294e': '#417089', '#da4e38': '#5698cc' };

  // ---------- monsters ----------
  const DEFS = {};
  DEFS.skelett = {
    name: 'Skelett', w: 26, h: 24, scale: 5, kind: 'mob', role: 'Nahkämpfer', shot: 'bone',
    desc: 'Klappernder Gruftwächter mit rostigem Schwert. Stürmt heran und schlägt weit aus.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'skelet_idle_anim_f', run: 'skelet_run_anim_f', frames: 4, weapon: 'rusty_sword', hand: [12, 11] }); },
  };
  DEFS.skelettschuetze = {
    name: 'Skelettschütze', w: 26, h: 26, scale: 5, kind: 'mob', role: 'Fernkämpfer', shot: 'bone',
    desc: 'Hält Abstand und schießt Knochenpfeile, ab und zu eine Salve aus drei Pfeilen.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'skelet_idle_anim_f', run: 'skelet_run_anim_f', frames: 4, weapon: 'bow', hand: [12, 10], grip: .15, swing: [1.2, 1.4, 1.57, 1.57], wmap: { '#8f4029': '#5f2d56' } }); },
  };
  DEFS.skelettwache = {
    name: 'Skelettwache', w: 26, h: 24, scale: 5.4, kind: 'mob', role: 'Schildträger', shot: 'bone',
    desc: 'Vergilbtes Skelett mit Streitkolben. Rammt dich mit dem Schild und wirft Knochen.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const r = figure(P, a, f, { base: 'skelet_idle_anim_f', run: 'skelet_run_anim_f', frames: 4, map: GUARD, weapon: 'mace', hand: [12, 11] });
      // a round shield on the off hand
      for (let y = -3; y <= 3; y++) for (let x = -2; x <= 2; x++) if (x * x / 6 + y * y / 10 <= 1) P.dot(r.x + 4 + x, r.y + 10 + y, Math.abs(x) + Math.abs(y) < 2 ? '#8a8a8a' : MUD);
    },
  };
  DEFS.nekromant = {
    name: 'Nekromant', w: 24, h: 30, scale: 4.4, kind: 'mob', role: 'Beschwörer', shot: 'soul',
    desc: 'Hält Abstand, schickt suchende Seelenflammen und ruft Skelette aus dem Boden.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'necromancer_idle_anim_f', run: 'necromancer_run_anim_f', frames: 4, weapon: 'green_magic_staff', hand: [12, 14], grip: .1, swing: [-.2, -.5, -.3, 0], cast: SOULFIRE }); },
  };
  DEFS.zombie = {
    name: 'Kleiner Zombie', w: 22, h: 22, scale: 5, kind: 'mob', role: 'Springer', shot: 'poison', pool: true,
    desc: 'Hüpft unruhig, springt dich an und spuckt Moder, der eine Giftlache hinterlässt.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'tiny_zombie_idle_anim_f', run: 'tiny_zombie_run_anim_f', frames: 4 }); if (a === 'attack' && f > 1) for (let i = 0; i < 4; i++) P.glow(16 + i, 12 + (i % 2), LIME); },
  };
  DEFS.eiszombie = {
    name: 'Eiszombie', w: 22, h: 22, scale: 5, kind: 'mob', role: 'Frost', shot: 'frost',
    desc: 'Taut nie auf. Haucht einen kurzen Froststoß, der dich verlangsamt.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      figure(P, a, f, { base: 'ice_zombie_anim_f0', bob: true });
      if (a === 'attack') for (let i = 0; i < 6; i++) P.glow(15 + i + (f % 2), 9 + ((i * 3 + f) % 4) - 1, i % 2 ? CYAN : WHITE);
    },
  };
  DEFS.leerenbomber = {
    name: 'Leerenbomber', w: 22, h: 24, scale: 4.4, kind: 'mob', role: 'Springer', shot: 'void',
    desc: 'Springt durch die Leere neben dich und platzt in einer violetten Welle.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const s = PIX['void_bomber_f' + (f * 2 % 8)], x = Math.round((P.w - s.w) / 2), y = P.h - s.h;
      P.sprite('void_bomber_f' + (f * 2 % 8), x, y, { px: 0, py: 0 });
      if (a === 'attack' || a === 'cast') sparkle(P, x + s.w / 2, y + s.h / 2, 7 + f, 10, VOIDFIRE, 1);
    },
  };
  DEFS.mimik = {
    name: 'Mimik', w: 20, h: 20, scale: 4.6, kind: 'mob', role: 'Lauerer', shot: 'gold',
    desc: 'Sieht aus wie eine Truhe. Hüpft heran, beißt zu und spuckt Münzen im Kreis.',
    anims: { idle: 4, run: 4, attack: 4 },
    draw(P, a, f) {
      const fr = a === 'attack' ? cyc(f, [1, 2, 2, 1]) : a === 'run' ? cyc(f, [0, 1, 0, 1]) : cyc(f, [0, 0, 0, 1]);
      const hop = a === 'run' ? cyc(f, [0, -2, -3, -1]) : 0;
      P.sprite('chest_mimic_open_anim_f' + fr, 2, P.h - 16 + hop, { px: 0, py: 0 });
    },
  };

  // ---------- bosses: drawn at twice the pixel density, with their own extras ----------
  DEFS.knochenwaechter = {
    name: 'Knochenwächter', w: 48, h: 46, scale: 4.2, kind: 'boss', floor: 1, role: 'Boss · Etage 1', shot: 'bone',
    desc: 'Der Wächter der Vorhalle: ein riesiges Skelett mit Kronreif und Ritterschwert.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const r = figure(P, a, f, { base: 'skelet_idle_anim_f', run: 'skelet_run_anim_f', frames: 4, k: 2, weapon: 'knight_sword', wk: 2, hand: [12, 11], map: GUARD, eyes: [[6, 6], [9, 6]], eyeC: ORA, cast: GOLDFIRE });
      for (let i = 0; i < 9; i++) P.dot(r.x + 8 + i, r.y + 1 - (i % 3 === 1 ? 2 : 0), i % 3 === 1 ? YEL : ORA);
    },
  };
  DEFS.grabmutter = {
    name: 'Grabmutter', w: 44, h: 40, scale: 4.2, kind: 'boss', floor: 2, role: 'Boss · Etage 2', shot: 'poison', pool: true,
    desc: 'Aufgedunsene Mutter aller Grabzombies. Springt, spuckt Moder und brütet Zombies aus.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      figure(P, a, f, { base: 'tiny_zombie_idle_anim_f', run: 'tiny_zombie_run_anim_f', frames: 4, k: 2, cast: SOULFIRE, hand: [8, 10] });
      for (let i = 0; i < 5; i++) P.glow(12 + i * 5, P.h - 6 - (i % 2) * 3 - (P.f % 2), LIME);
    },
  };
  DEFS.moderkoloss = {
    name: 'Moderkoloss', w: 44, h: 42, scale: 4.6, kind: 'boss', floor: 3, role: 'Zwischenboss · Etage 3', shot: 'poison', pool: true,
    desc: 'Ein Berg aus Moderfleisch. Faulatem, Giftklumpen, Sturmlauf und Erdbeben, dazu Madenbrut.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'big_zombie_idle_anim_f0', bob: true, map: MODER, cast: SOULFIRE, hand: [24, 20], eyes: [[19, 9], [22, 9]], eyeC: LIME }); if (a === 'attack') P.flame(30, 14, 6, 6 + f * 2, { pal: SOULFIRE, front: true, lean: 6 }); },
  };
  DEFS.nekromantenfuerst = {
    name: 'Nekromantenfürst', w: 44, h: 54, scale: 4.2, kind: 'boss', floor: 4, role: 'Boss · Etage 4', shot: 'soul',
    desc: 'Herr der Kapelle. Seelenspiralen, suchende Seelen, Knochenkreise und ganze Skelettlegionen.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const r = figure(P, a, f, { base: 'necromancer_idle_anim_f', run: 'necromancer_run_anim_f', frames: 4, k: 2, weapon: 'green_magic_staff', wk: 2, hand: [12, 14], grip: .1, swing: [-.2, -.5, -.3, 0], cast: SOULFIRE });
      P.flame(r.x + 11, r.y + 2, 10, 7, { pal: SOULFIRE, seed: 3 });
    },
  };
  DEFS.truhenfresser = {
    name: 'Truhenfresser', w: 40, h: 38, scale: 4.2, kind: 'boss', floor: 5, role: 'Boss · Etage 5', shot: 'gold',
    desc: 'Die älteste Mimik der Gruft. Beißt doppelt, speit Münzschwälle und ruft ihre Brut.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const fr = a === 'attack' || a === 'cast' ? cyc(f, [1, 2, 2, 1]) : a === 'run' ? cyc(f, [0, 1, 0, 1]) : cyc(f, [0, 0, 0, 1]);
      P.sprite('chest_mimic_open_anim_f' + fr, 4, P.h - 32 + (a === 'run' ? cyc(f, [0, -3, -4, -1]) : 0), { k: 2, px: 0, py: 0 });
      if (a === 'cast') sparkle(P, 20, 18, 14, 10, GOLDFIRE, 2);
    },
  };
  DEFS.frostleiche = {
    name: 'Frostleiche', w: 44, h: 42, scale: 4.6, kind: 'boss', floor: 6, role: 'Zwischenboss · Etage 6', shot: 'frost',
    desc: 'Gefrorener Koloss. Eissplitter, Frostnova, Hagel, Eisgleiten und erweckte Eiszombies.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'big_zombie_idle_anim_f0', bob: true, map: FROST, cast: FROSTFIRE, hand: [24, 20], eyes: [[19, 9], [22, 9]], eyeC: WHITE }); sparkle(P, 22, 22, 18, a === 'cast' ? 12 : 4, FROSTFIRE, 4); },
  };
  DEFS.archivar = {
    name: 'Der Archivar', w: 44, h: 54, scale: 4.2, kind: 'boss', floor: 7, role: 'Boss · Etage 7', shot: 'frost',
    desc: 'Hüter des Reliquienarchivs. Bannfluch, Grabeshände, ein Sturm aus Seiten und seine Schützen.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'necromancer_idle_anim_f', run: 'necromancer_run_anim_f', frames: 4, k: 2, map: ARCHIVE, weapon: 'red_magic_staff', wk: 2, hand: [12, 14], grip: .1, swing: [-.2, -.5, -.3, 0], cast: FROSTFIRE }); },
  };
  DEFS.leerenbrut = {
    name: 'Leerenbrut', w: 40, h: 44, scale: 4.2, kind: 'boss', floor: 8, role: 'Boss · Etage 8', shot: 'void',
    desc: 'Eine pulsierende Brutblase der Leere. Springt, blitzt, implodiert und gebiert Bomber.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const n = 'void_bomber_f' + (f * 2 % 8), s = PIX[n];
      P.sprite(n, Math.round((P.w - s.w * 2) / 2), P.h - s.h * 2, { k: 2, px: 0, py: 0 });
      sparkle(P, P.w / 2, P.h / 2, 12 + (a === 'cast' ? f * 2 : 0), a === 'idle' ? 6 : 14, VOIDFIRE, 5);
    },
  };
  DEFS.knochenkoloss = {
    name: 'Knochenkoloss', w: 44, h: 42, scale: 4.8, kind: 'boss', floor: 9, role: 'Zwischenboss · Etage 9', shot: 'bone',
    desc: 'Aus tausend Knochen getürmt. Knochenspeere, Spitzenlinien, Wirbel, Schädelhagel und die Legion.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) { figure(P, a, f, { base: 'big_zombie_idle_anim_f0', bob: true, map: BONEMAP, weapon: 'big_hammer', hand: [26, 20], cast: VOIDFIRE, eyes: [[19, 9], [22, 9]], eyeC: VIO }); },
  };
  DEFS.leerenrufer = {
    name: 'Leerenrufer', w: 48, h: 50, scale: 5, kind: 'boss', floor: 10, role: 'Endboss · Etage 10', shot: 'void',
    desc: 'Der Herr der Krypta. Leerenrisse, Seelenfessel, Schattenschritt, Spiralen, Knochenkreise und der Doppelstrahl.',
    anims: { idle: 4, run: 4, attack: 4, cast: 4 },
    draw(P, a, f) {
      const n = 'void_body_f' + ((f * 2 + (a === 'attack' ? 1 : 0)) % 8), s = PIX[n], x = Math.round((P.w - s.w) / 2), y = P.h - s.h;
      P.sprite(n, x, y, { px: 0, py: 0, skip: false, map: { '#222222': '#2a1d3a', '#ffffff': VIO } });
      for (const [ex, ey] of [[19, 14], [24, 14], [21, 18]]) P.glow(x + ex, y + ey, a === 'attack' ? WHITE : LILAC);
      if (a === 'cast' || a === 'attack') sparkle(P, P.w / 2, P.h * .45, 16 + f * 2, 14, VOIDFIRE, 6);
    },
  };

  // AI and attacks for the hell runtime (see hell_monsters.js for the kinds). Numbers follow the
  // crypt's own moves (docs/BOSS-FAEHIGKEITEN.de.md) where the hell runtime has a matching kind.
  const A = (id, name, kind, every, o) => Object.assign({ id, name, kind, every }, o || {});
  const STATS = {
    skelett: { hp: 5, speed: 140, r: 26, ai: 'chase', attacks: [A('hieb', 'Schwerthieb', 'swing', 1.8, { range: 140, radius: 140, arc: 2.0, desc: 'Weiter Hieb vor sich.' }), A('sprung', 'Ausfallsprung', 'dash', 4.2, { range: 380, speed: 760, desc: 'Springt mit erhobenem Schwert auf dich zu.' })] },
    skelettschuetze: { hp: 3, speed: 120, r: 24, ai: 'keep', keep: 420, attacks: [A('pfeil', 'Knochenpfeil', 'bolt', 2.2, { range: 800, speed: 700, count: 1, desc: 'Ein schneller Pfeil.' }), A('salve', 'Pfeilsalve', 'bolt', 6, { range: 800, speed: 640, count: 3, spread: .3, desc: 'Drei Pfeile im Fächer.' })] },
    skelettwache: { hp: 9, speed: 95, r: 30, ai: 'chase', attacks: [A('schild', 'Schildstoß', 'dash', 3.4, { range: 300, speed: 700, desc: 'Rammt dich mit dem Schild.' }), A('wurf', 'Knochenwurf', 'lob', 3.6, { range: 600, radius: 60, desc: 'Wirft einen Knochen im Bogen.' })] },
    nekromant: { hp: 6, speed: 95, r: 26, ai: 'keep', keep: 460, attacks: [A('fluch', 'Seelenfluch', 'homing', 3.2, { range: 800, speed: 240, desc: 'Eine grüne Seele, die dir folgt.' }), A('ruf', 'Knochenruf', 'summon', 9, { mobs: ['skelett', 'skelett'], max: 3, desc: 'Ruft zwei Skelette aus dem Boden.' })] },
    zombie: { hp: 4, speed: 150, r: 24, ai: 'hop', attacks: [A('sprung', 'Anspringen', 'dash', 2.8, { range: 360, speed: 820, desc: 'Springt dich an.' }), A('spucke', 'Moderspucke', 'lob', 4, { range: 520, radius: 56, desc: 'Spuckt Moder; wo er landet, bleibt eine Giftlache.' })] },
    eiszombie: { hp: 7, speed: 110, r: 26, ai: 'chase', attacks: [A('atem', 'Frostatem', 'breath', 4.5, { range: 240, count: 7, desc: 'Kurzer Froststoß aus dem Maul.' })] },
    leerenbomber: { hp: 3, speed: 190, r: 24, ai: 'skirmish', attacks: [A('sprung', 'Leerensprung', 'teleport', 4, { range: 800, desc: 'Verschwindet und taucht neben dir auf.' }), A('platzen', 'Leerenwelle', 'slam', 3, { range: 200, radius: 120, desc: 'Platzt in einer violetten Welle.' })] },
    mimik: { hp: 8, speed: 130, r: 26, ai: 'hop', attacks: [A('biss', 'Truhenbiss', 'dash', 2.4, { range: 300, speed: 900, desc: 'Schnappt blitzschnell zu.' }), A('muenzen', 'Münzspucke', 'ring', 8, { count: 8, speed: 260, desc: 'Spuckt einen Kreis aus Münzen.' })] },

    knochenwaechter: { hpMul: 1, speed: 85, r: 64, ai: 'chase', adds: ['skelett', 'skelettschuetze'], attacks: [A('stampfer', 'Schwertstampfer', 'slam', 3.6, { range: 340, radius: 280, desc: 'Rammt das Schwert in den Boden: Schockwelle.' }), A('wurf', 'Knochenwurf', 'lob', 3, { range: 900, count: 3, radius: 70, desc: 'Wirft drei Knochen im Bogen.' }), A('legion', 'Knochenlegion', 'summon', 9, { mobs: ['skelett', 'skelett'], max: 4, desc: 'Ruft zwei Skelette.' })] },
    grabmutter: { hpMul: 1, speed: 95, r: 64, ai: 'hop', adds: ['zombie'], attacks: [A('satz', 'Grabsprung', 'slam', 3.2, { range: 560, radius: 160, leap: true, desc: 'Springt dich an; der Aufprall schleudert Moder.' }), A('spucke', 'Moderschwall', 'lob', 2.4, { range: 900, count: 4, radius: 70, desc: 'Spuckt Moder in hohen Bögen.' }), A('brut', 'Zombiebrut', 'summon', 7, { mobs: ['zombie', 'zombie'], max: 5, desc: 'Brütet zwei kleine Zombies aus.' })] },
    moderkoloss: { hpMul: 1, speed: 90, r: 74, ai: 'chase', adds: ['zombie'], attacks: [A('atem', 'Faulatem', 'breath', 3.4, { range: 380, count: 13, desc: 'Giftkegel nach vorn (M1).' }), A('klumpen', 'Moderklumpen', 'lob', 3, { range: 900, count: 3, radius: 80, desc: 'Drei Klumpen im Bogen, Giftlachen am Boden (M2).' }), A('sturm', 'Sturmlauf', 'dash', 5, { range: 700, speed: 950, desc: 'Warnlinie, dann rennt er quer durch den Raum (M3).' }), A('beben', 'Erdbeben', 'slam', 4, { range: 320, radius: 280, line: true, desc: 'Eine Linie aus Erdstößen (M4).' }), A('maden', 'Madenbrut', 'summon', 10, { mobs: ['zombie', 'zombie', 'zombie'], max: 4, desc: 'Ruft drei kleine Zombies (M5).' }), A('regen', 'Fleischregen', 'ring', 7, { count: 16, speed: 250, desc: 'Ein Ring aus Brocken (M7).' })] },
    nekromantenfuerst: { hpMul: 1, speed: 75, r: 60, ai: 'keep', keep: 440, adds: ['nekromant', 'skelett'], attacks: [A('spirale', 'Seelenspirale', 'spiral', 6, { duration: 3, rate: .09, arms: 3, speed: 260, desc: 'Drei Arme aus Seelenflammen drehen sich aus ihm heraus.' }), A('herde', 'Seelenherde', 'homing', 3.4, { range: 900, speed: 230, count: 3, desc: 'Drei suchende Seelen.' }), A('kreis', 'Knochenkreis', 'ring', 5, { count: 18, speed: 260, desc: 'Ein Ring aus Knochenspitzen.' }), A('schritt', 'Schattenschritt', 'teleport', 7, { range: 900, desc: 'Verschwindet und taucht an anderer Stelle auf.' }), A('legion', 'Legion', 'summon', 11, { mobs: ['skelett', 'skelettwache'], max: 4, desc: 'Ruft Skelett und Skelettwache.' })] },
    truhenfresser: { hpMul: 1, speed: 120, r: 60, ai: 'hop', adds: ['mimik'], attacks: [A('biss', 'Doppelbiss', 'dash', 2.8, { range: 600, speed: 1000, repeat: 2, desc: 'Zwei schnelle Bisse hintereinander.' }), A('schwall', 'Münzschwall', 'breath', 4, { range: 380, count: 11, desc: 'Speit Münzen im Fächer.' }), A('sprung', 'Deckelsprung', 'slam', 3.6, { range: 520, radius: 180, leap: true, desc: 'Springt dich an.' }), A('ruf', 'Mimikruf', 'summon', 10, { mobs: ['mimik'], max: 3, desc: 'Eine Truhe im Raum erwacht.' })] },
    frostleiche: { hpMul: 1, speed: 80, r: 74, ai: 'chase', adds: ['eiszombie'], attacks: [A('splitter', 'Eissplitter', 'bolt', 2.4, { range: 800, speed: 560, count: 5, spread: .5, desc: 'Fächer aus fünf Eisspitzen (F1).' }), A('nova', 'Frostnova', 'ring', 4.5, { count: 16, speed: 280, desc: 'Eisring um sie herum (F2).' }), A('hagel', 'Hagel', 'meteors', 6, { count: 5, radius: 80, desc: 'Markierte Kreise, dann fallen Eisbrocken (F4).' }), A('gleiten', 'Eisgleiten', 'dash', 5, { range: 640, speed: 900, desc: 'Rutscht auf dich zu (F5).' }), A('erweckung', 'Frosterweckung', 'summon', 10, { mobs: ['eiszombie', 'eiszombie'], max: 4, desc: 'Zwei Eiszombies steigen aus dem Boden (F7).' })] },
    archivar: { hpMul: 1, speed: 70, r: 60, ai: 'drift', adds: ['nekromant', 'skelettschuetze'], attacks: [A('bann', 'Bannfluch', 'scream', 5, { range: 520, arc: 1.2, desc: 'Ein Fluch im Kegel: Schaden und 2 s verlangsamt.' }), A('haende', 'Grabeshände', 'hands', 4, { count: 5, radius: 70, desc: 'Hände greifen aus dem Boden unter dir.' }), A('seiten', 'Seitensturm', 'bolt', 2.6, { range: 800, speed: 520, count: 5, spread: .8, desc: 'Fünf verfluchte Seiten im Fächer.' }), A('ruf', 'Archivruf', 'summon', 11, { mobs: ['skelettschuetze', 'nekromant'], max: 3, desc: 'Ruft Schütze und Nekromant.' })] },
    leerenbrut: { hpMul: 1, speed: 70, r: 60, ai: 'drift', adds: ['leerenbomber'], attacks: [A('sprung', 'Leerensprung', 'teleport', 5, { range: 900, desc: 'Verschwindet und taucht neben dir auf.' }), A('blitz', 'Leerenblitze', 'bolt', 2.2, { range: 800, speed: 520, count: 3, spread: .35, desc: 'Drei violette Blitze im Fächer.' }), A('implosion', 'Implosion', 'slam', 4, { range: 320, radius: 240, desc: 'Fällt in sich zusammen und stößt eine Welle aus.' }), A('brut', 'Bomberbrut', 'summon', 8, { mobs: ['leerenbomber', 'leerenbomber'], max: 4, desc: 'Gebiert zwei Leerenbomber.' })] },
    knochenkoloss: { hpMul: 1, speed: 95, r: 76, ai: 'chase', adds: ['skelett', 'skelettwache'], attacks: [A('speere', 'Knochenspeere', 'bolt', 2.4, { range: 900, speed: 760, count: 3, spread: .25, desc: 'Wirft drei Speere (K1).' }), A('linie', 'Spitzenlinie', 'slam', 3.6, { range: 360, radius: 300, line: true, desc: 'Knochenspitzen brechen in einer Linie hervor (K2).' }), A('wirbel', 'Knochenwirbel', 'swing', 4, { range: 220, radius: 220, arc: 6.3, desc: 'Dreht sich mit ausgestrecktem Arm (K3).' }), A('hagel', 'Schädelhagel', 'lob', 4.5, { range: 900, count: 4, radius: 60, desc: 'Vier Schädel im Bogen (K4).' }), A('legion', 'Knochenlegion', 'summon', 11, { mobs: ['skelett', 'skelett', 'skelettwache'], max: 4, desc: 'Ruft drei Skelette (K7).' })] },
    leerenrufer: { hpMul: 1, speed: 80, r: 90, ai: 'drift', adds: ['leerenbomber', 'nekromant'], attacks: [A('riss', 'Leerenriss', 'hands', 3.4, { count: 4, radius: 80, desc: 'Unter dir öffnet sich die Leere (L1).' }), A('fessel', 'Seelenfessel', 'chain', 5, { range: 700, speed: 700, desc: 'Eine Seelenkette zieht dich zu ihm (L2).' }), A('schritt', 'Schattenschritt', 'teleport', 7, { range: 900, desc: 'Er löst sich auf und erscheint woanders (L3).' }), A('spirale', 'Leerenspirale', 'spiral', 9, { duration: 4, rate: .09, arms: 3, speed: 260, desc: 'Drei Arme aus Seelenschädeln (L4).' }), A('kreis', 'Knochenkreis', 'ring', 6, { count: 22, speed: 260, desc: 'Ein Ring aus Knochenspitzen (L5).' }), A('strahl', 'Doppelstrahl', 'beam', 10, { duration: 3.4, beams: 2, turn: .6, desc: 'Zwei Leerenstrahlen drehen sich durch die Arena (L7).' })] },
  };
  for (const id in STATS) DEFS[id].stats = STATS[id];

  // Which monsters each floor sends, and its boss. Deeper floors mix in the later kinds.
  const FLOORS = {
    1: { mobs: ['skelett', 'skelettschuetze', 'zombie'], boss: 'knochenwaechter' },
    2: { mobs: ['skelett', 'zombie', 'skelettwache', 'skelettschuetze'], boss: 'grabmutter' },
    3: { mobs: ['zombie', 'skelettwache', 'nekromant', 'skelett'], boss: 'moderkoloss' },
    4: { mobs: ['nekromant', 'skelettschuetze', 'skelettwache', 'mimik'], boss: 'nekromantenfuerst' },
    5: { mobs: ['mimik', 'zombie', 'nekromant', 'skelett'], boss: 'truhenfresser' },
    6: { mobs: ['eiszombie', 'skelettwache', 'nekromant', 'skelettschuetze'], boss: 'frostleiche' },
    7: { mobs: ['nekromant', 'eiszombie', 'skelettschuetze', 'mimik'], boss: 'archivar' },
    8: { mobs: ['leerenbomber', 'nekromant', 'eiszombie', 'skelettwache'], boss: 'leerenbrut' },
    9: { mobs: ['skelettwache', 'leerenbomber', 'nekromant', 'skelettschuetze', 'eiszombie'], boss: 'knochenkoloss' },
    10: { mobs: ['leerenbomber', 'nekromant', 'skelettwache', 'eiszombie', 'skelettschuetze', 'mimik'], boss: 'leerenrufer' },
  };

  // ---------- rendering ----------
  function frameCount(def, anim) { return anim === 'death' ? 6 : (def.anims[anim] || 4); }
  function renderColors(id, anim, frame) {
    const def = DEFS[id];
    if (anim === 'death') return deathColors(def, renderColors(id, 'idle', 0), frame);
    const p = new Painter(def.w, def.h, frame);
    def.draw(p, anim, frame);
    return { w: def.w, h: def.h, px: p.finish() };
  }
  // Death: the body falls apart into bone dust from the top; a soul light flickers out.
  function deathColors(def, base, frame) {
    const { w, h } = base, out = new Array(w * h).fill(null), k = frame / 5;
    const glow = { soul: LIME, void: VIO, frost: CYAN, poison: LIME, gold: YEL, bone: WHITE }[def.shot] || WHITE;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const c = base.px[y * w + x]; if (!c) continue;
      const r = ((x * 73856093) ^ (y * 19349663)) % 997 / 997, gone = r < k * 1.15 - (y / h) * .35;
      if (gone) continue;
      const fall = Math.floor(k * k * 6 * (1 - y / h) + (r < k ? 1 : 0)), yy = Math.min(h - 1, y + fall);
      out[yy * w + x] = r < k * 1.4 && c !== K ? (r < k * .5 ? glow : r < k ? BONE : TAN) : c;
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

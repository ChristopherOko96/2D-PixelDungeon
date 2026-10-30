// Exports the Frostgruft's enemies as the crypt's part rigs (assets/data/rigs.json),
// so they move like the crypt's and the Hell's figures: legs walk, heads bob,
// weapons swing, a slime wobbles, a whirl swirls, and they fall apart or melt
// when they die (src/rig/rig_poses.gd, drawn by src/hell/frost_rigs.gd).
// The figures stay the ones in assets/sprites/frost (the brother's picks): the
// 0x72 ones reuse the crypt's rigs with the Frostgruft's ice colours as a
// recolour map (the ramp of tools/frost_dungeon/build_frost_skin.py), the
// others are cut from the frost sprites at their art size:
//   assets/sprites/frost/rigs/<rig>.png   one art-size image per figure (the sprite shrunk back by its x3 / x4)
// Poses move in art pixels, so every rig image has one pixel per art pixel; the
// scale (1.5, Hrimgar 2) brings them back to the size the frost sprites have.
// Usage (repo root): node tools/frost_dungeon/export_frost_rigs.js
'use strict';
const fs = require('fs');
const path = require('path');

const root = process.argv[2] || path.join(__dirname, '..', '..');
const H = require(path.join(root, 'tools/hell_dungeon/concepts/hybrid.js'));
const { encodePng } = require(path.join(root, 'tools/hell_dungeon/monster_sheet.js'));
const FROST = path.join(root, 'assets/sprites/frost');
const OUT = path.join(FROST, 'rigs');
const SRC72 = path.join(root, 'assets/sprites/0x72');
const RES = 'res://assets/sprites/frost/rigs/';
const RIGS = path.join(root, 'assets/data/rigs.json');

// The frost skin's ramps and glow (tools/frost_dungeon/build_frost_skin.py RAMPS, GLOW).
const RAMPS = {
  ice: ['#0a1430', '#163063', '#2b5ea3', '#4f93d6', '#8cc8f2', '#d2f1ff', '#ffffff'],
  deep: ['#060a24', '#0f1d4e', '#1d3b8a', '#2f63c4', '#58a0ea', '#9fd8ff', '#e6f8ff'],
};
const GLOW = { ice: '#7ff6ff', deep: '#ffffff' };

function load(file) {
  const i = H.decodePng(fs.readFileSync(file));
  return { w: i.w || i.width, h: i.h || i.height, d: i.rgba || i.data };
}

// The sprite shrunk back to art size: every k-th pixel (the skin enlarged with nearest).
function shrink(img, k) {
  const w = img.w / k, h = img.h / k, d = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const s = ((y * k) * img.w + x * k) * 4;
    d.set(img.d.subarray(s, s + 4), (y * w + x) * 4);
  }
  return { w, h, d };
}

function save(name, img) {
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, name + '.png'), encodePng(img.w, img.h, img.d));
  return RES + name + '.png';
}

const hex = (r, g, b) => '#' + [r, g, b].map(v => v.toString(16).padStart(2, '0')).join('');

// What build_frost_skin.py recolor() turns each colour of a 0x72 image into.
function rampMap(file, ramp, glow = true) {
  const img = load(file), rp = RAMPS[ramp], map = {};
  for (let i = 0; i < img.d.length; i += 4) {
    if (!img.d[i + 3]) continue;
    const [r, g, b] = [img.d[i], img.d[i + 1], img.d[i + 2]];
    const key = hex(r, g, b);
    if (map[key]) continue;
    if (glow && Math.max(r, g, b) - Math.min(r, g, b) > 70 && (g > r + 40 || (r > g + 60 && r > b + 60))) { map[key] = GLOW[ramp]; continue; }
    const l = (0.3 * r + 0.59 * g + 0.11 * b) / 255;
    map[key] = l < 0.12 ? rp[0] : rp[Math.min(rp.length - 1, Math.round(l * 1.15 * (rp.length - 1)))];
  }
  return map;
}

const clone = (o) => JSON.parse(JSON.stringify(o));
const part = (id, rects, pivot, parent, z, label, extra = {}) => Object.assign({ id, rects, pivot, parent, z, hp: 2, label }, extra);

const data = JSON.parse(fs.readFileSync(RIGS, 'utf8'));
const rigs = {};
const scales = {};

// --- the 0x72 figures: the crypt's rigs in the Frostgruft's ice -------------------------
rigs.frost_zombie = clone(data.rigs.ice_zombie);
rigs.frost_skeleton = clone(data.rigs.skel_archer);
rigs.frost_skeleton.recolor = rampMap(path.join(SRC72, 'skelet_idle_anim_f0.png'), 'ice');
for (const it of rigs.frost_skeleton.items) if (it.img === 'bow') it.recolor = rampMap(path.join(SRC72, 'weapon_bow.png'), 'ice');
rigs.frost_necro = clone(data.rigs.necro);
rigs.frost_necro.recolor = rampMap(path.join(SRC72, 'necromancer_anim_f0.png'), 'deep');
for (const it of rigs.frost_necro.items) if (it.img === 'red_staff') it.recolor = rampMap(path.join(SRC72, 'weapon_red_magic_staff.png'), 'deep');
rigs.frost_leiche = clone(data.rigs.big_zombie);
rigs.frost_leiche.recolor = rampMap(path.join(SRC72, 'big_zombie_idle_anim_f0.png'), 'ice');
for (const id of ['frost_zombie', 'frost_skeleton', 'frost_necro', 'frost_leiche']) rigs[id].material = 'frost';
Object.assign(scales, { frost_zombie: 1.5, frost_skeleton: 1.5, frost_necro: 1.5, frost_leiche: 1.5 });

// --- the frost skin's own figures, cut at art size --------------------------------------
const images = {};
images.frost_imp = save('frost_imp', shrink(load(path.join(FROST, 'mob_frost_imp_f0.png')), 3));
images.frost_knight = save('frost_knight', shrink(load(path.join(FROST, 'mob_ice_knight_f0.png')), 3));
images.frost_commander = save('frost_commander', shrink(load(path.join(FROST, 'mob_frost_commander.png')), 3));

// Frostkobold (Superdark's horned kobold): head with horns and the upper teeth, the jaw on the body
rigs.frost_imp = {
  img: 'frost_imp', family: 'skeleton', material: 'frost', ground: [8, 31], width: 10,
  parts: [
    part('leg_l', [[3, 29, 6, 31]], [5, 29], null, 1, 'Linkes Bein'),
    part('leg_r', [[7, 29, 12, 31]], [10, 29], null, 1, 'Rechtes Bein'),
    part('torso', [[3, 27, 12, 28]], [8, 28], null, 2, 'Leib', { alsoDetach: ['leg_l', 'leg_r'] }),
    part('skull', [[0, 0, 15, 26]], [8, 27], 'torso', 3, 'Kopf', { vital: true }),
  ],
  items: [],
};
// The weapons the humanoids hold: the 0x72 blades, already in steel blue (grip and tip in the weapon's pixels)
images.regular_sword = 'res://assets/sprites/0x72/weapon_regular_sword.png';
images.anime_sword = 'res://assets/sprites/0x72/weapon_anime_sword.png';
// Eisritter (Superdark's knight): the whole helm is the head, the block on the left his shield
// (a part the guard's moves push), a real sword in his right hand
rigs.frost_knight = {
  img: 'frost_knight', family: 'skeleton', variant: 'guard', item_parts: true, material: 'frost', ground: [8, 31], width: 10,
  parts: [
    part('shield', [[0, 21, 6, 26]], [4, 23], 'torso', 4, 'Schild'),
    part('leg_l', [[3, 29, 6, 31]], [5, 29], null, 1, 'Linkes Bein'),
    part('leg_r', [[9, 29, 13, 31]], [11, 29], null, 1, 'Rechtes Bein'),
    part('torso', [[7, 21, 15, 28], [3, 27, 13, 28]], [8, 28], null, 2, 'Rumpf', { alsoDetach: ['leg_l', 'leg_r'] }),
    part('skull', [[3, 13, 13, 20]], [8, 21], 'torso', 3, 'Helm', { vital: true }),
  ],
  items: [
    { id: 'weapon', img: 'regular_sword', grip: [4.5, 18], hand: [13.5, 24], parent: 'torso', rest: 0.6, z: 5, tip: [4.5, 1], hp: 1, label: 'Schwert', disables: 'attack' },
  ],
};
// Frostkommandant (Superdark's big knight): helm and cloaked body, a broadsword in his right hand
// that he swings like the crypt's armed figures (biped: coil, strike, back)
rigs.frost_commander = {
  img: 'frost_commander', family: 'biped', material: 'frost', ground: [15, 31], width: 26,
  parts: [
    part('head', [[11, 3, 22, 10]], [16, 11], 'body', 3, 'Helm'),
    part('body', [[0, 11, 28, 31]], [15, 31], null, 2, 'Rumpf', { vital: true }),
  ],
  items: [
    { id: 'weapon', img: 'anime_sword', grip: [5.5, 26.5], hand: [25, 21], parent: 'body', rest: 0.3, z: 4, tip: [5, 1], hp: 1, label: 'Breitschwert', disables: 'attack' },
  ],
};
Object.assign(scales, { frost_imp: 1.5, frost_knight: 1.5, frost_commander: 1.5 });

// Eisschleim in three sizes: a jelly body whose top lags behind its base
for (let i = 0; i < 3; i++) {
  const img = shrink(load(path.join(FROST, `mob_ice_slime_${i}.png`)), 3);
  const id = `frost_slime_${i}`;
  images[id] = save(id, img);
  const split = Math.round(img.h * 0.55), cx = Math.floor(img.w / 2);
  rigs[id] = {
    img: id, family: 'slime', material: 'frost', ground: [cx, img.h - 1], width: img.w - 4,
    parts: [
      part('top', [[0, 0, img.w - 1, split]], [cx, split + 1], 'base', 2, 'Haube'),
      part('base', [[0, split + 1, img.w - 1, img.h - 1]], [cx, img.h - 1], null, 1, 'Leib', { vital: true }),
    ],
    items: [],
  };
  scales[id] = 1.5;
}
// Frostwirbel: three bands of the whirl, the top and the tail swaying round the middle
{
  const img = shrink(load(path.join(FROST, 'mob_frost_whirl_0.png')), 3);
  images.frost_whirl = save('frost_whirl', img);
  rigs.frost_whirl = {
    img: 'frost_whirl', family: 'spirit', material: 'frost', ground: [12, img.h - 1], width: 18,
    parts: [
      part('top', [[0, 0, img.w - 1, 10]], [12, 11], 'mid', 3, 'Krone', { sway: [0, 0.07, 1.0, 0] }),
      part('tail', [[0, 22, img.w - 1, img.h - 1]], [12, 22], 'mid', 1, 'Schweif', { sway: [0, 0.2, 1.0, -1.3] }),
      part('mid', [[0, 11, img.w - 1, 21]], [12, 16], null, 2, 'Wirbel', { vital: true }),
    ],
    items: [],
  };
  scales.frost_whirl = 1.5;
}
// Eiskristall: the crown of spikes and the roots sway a little round the floating body
{
  const img = shrink(load(path.join(FROST, 'mob_ice_crystal_0.png')), 3);
  images.frost_crystal = save('frost_crystal', img);
  rigs.frost_crystal = {
    img: 'frost_crystal', family: 'spirit', material: 'frost', ground: [8, img.h - 1], width: 12,
    parts: [
      part('crown', [[0, 0, img.w - 1, 11]], [8, 12], 'body', 3, 'Spitzen', { sway: [0, 0.04, 1.6, 0] }),
      part('roots', [[0, 30, img.w - 1, img.h - 1]], [8, 30], 'body', 1, 'Wurzeln', { sway: [0, 0.06, 1.6, 1.0] }),
      part('body', [[0, 12, img.w - 1, 29]], [8, 22], null, 2, 'Kristall', { vital: true }),
    ],
    items: [],
  };
  scales.frost_crystal = 1.5;
}
// Hrimgar: the Glutwächter's golem cut (the same Superdark golem, two rows lower in the frost frame), per phase
for (const ph of ['p1', 'p2', 'p3']) {
  const id = `frost_golem_${ph}`;
  images[id] = save(id, shrink(load(path.join(FROST, `boss_golem_${ph}_f0.png`)), 4));
  const rig = clone(data.rigs.glutwaechter);
  rig.img = id;
  rig.material = 'frost';
  delete rig.burn;
  delete rig.slash;
  rig.ground = [rig.ground[0], rig.ground[1] + 2];
  for (const p of rig.parts) {
    p.rects = p.rects.map(r => [r[0], r[1] + 2, r[2], r[3] + 2]);
    p.pivot = [p.pivot[0], p.pivot[1] + 2];
    if (p.id === 'kern') { p.label = 'Gletscherkern'; delete p.disables; }
  }
  rigs[id] = rig;
  scales[id] = 2;
}

Object.assign(data.images, images);
for (const [id, rig] of Object.entries(rigs)) { data.rigs[id] = rig; data.scales[id] = scales[id]; }
fs.writeFileSync(RIGS, JSON.stringify(data, null, 1) + '\n');
console.log('rigs.json +', Object.keys(rigs).join(', '));

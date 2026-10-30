// Exports the Hell's small monsters as part rigs, like the crypt's skeletons
// (assets/data/rigs.json): every body part moves on its own curve, a weapon or
// a head can be cut off, and the figure falls apart when it dies.
//   assets/sprites/hell/rigs/<id>/<part>.png       one full-frame PNG per part (idle frame 0)
//   assets/sprites/hell/rigs/<id>/<part>_0..3.png  flipbook parts (flames), 4 frames
//   assets/data/hell_rigs.json                     merged into "rigs" (Ignaroth's forms stay)
// The parts are the draw calls hell_monsters.js tags with P.part(name); pivots
// and points are its P.joint(name, x, y). MOBS below says which family of
// src/rig/rig_poses.gd moves it, the parents, layers, HP weights and what a cut does.
// Usage: node tools/hell_dungeon/export_mob_rigs.js [repo_root] [--only id,id]
'use strict';
const fs = require('fs');
const path = require('path');
const HM = require('./hell_monsters.js');
const { encodePng } = require('./monster_sheet.js');

const args = process.argv.slice(2);
const root = args.find(a => !a.startsWith('--') && !a.includes(',') && fs.existsSync(a)) || path.join(__dirname, '..', '..');
const onlyArg = args.indexOf('--only');
const ONLY = onlyArg >= 0 ? args[onlyArg + 1].split(',') : null;
const RES_DIR = 'res://assets/sprites/hell/rigs';
const SCALE = 1.7; // x RigLibrary.PIXEL_SCALE 2 = 3.4 world px per source px, the atlas scale

// family: RigPoses family; parts: [id, parent, z, hp, label, cut?]; flip: flipbook parts;
// points: name -> part (the point's joint is the P.joint of that name)
const MOBS = {
  brandskelett: {
    family: 'skeleton', variant: 'sword', material: 'bone',
    parts: [
      ['flame_back', 'torso', 0, 0, 'Glut'],
      ['leg_l', null, 1, 2, 'Linkes Bein'],
      ['leg_r', null, 1, 2, 'Rechtes Bein'],
      ['torso', null, 2, 4, 'Rumpf', { alsoDetach: ['leg_l', 'leg_r'], unbreakable: true }],
      ['skull', 'torso', 3, 3, 'Schädel', { vital: true }],
      ['flame_head', 'skull', 4, 0, 'Flamme'],
      ['weapon', 'torso', 5, 2, 'Glutklinge', { disables: ['hieb'] }],
    ],
    flip: ['flame_back', 'flame_head'],
    points: { hand: 'weapon', core: 'skull' },
  },
};

const round1 = v => Math.round(v * 10) / 10;
function rgba(px) {
  const data = new Uint8Array(px.length * 4);
  px.forEach((c, i) => { if (c) { const [R, G, B] = HM.hexToRgb(c); data.set([R, G, B, 255], i * 4); } });
  return data;
}
function render(def, part, frame) {
  const p = new HM.Painter(def.w, def.h, frame, part);
  def.draw(p, 'idle', frame);
  return { px: p.finish(), joints: p.joints, tags: p.tags };
}
function lowest(px, w, h) {
  let gy = -1, x0 = w, x1 = -1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (px[y * w + x]) gy = Math.max(gy, y);
  for (let x = 0; x < w; x++) if (px[gy * w + x]) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); }
  return { gy, x0, x1 };
}

function build(id, cfg) {
  const def = HM.DEFS[id], W = def.w, H = def.h;
  const all = render(def, null, 0), J = all.joints;
  const known = new Set(cfg.parts.map(p => p[0]));
  const untagged = all.tags.filter(t => !known.has(t));
  if (untagged.length) throw new Error(id + ': tags without a rig part ' + untagged.join(', '));
  const parts = [], images = {};
  for (const [part, parent, z, hp, label, cut] of cfg.parts) {
    if (!J[part]) throw new Error(id + ': no joint for ' + part);
    const frames = cfg.flip.includes(part) ? [0, 1, 2, 3] : [0];
    images[part] = frames.map(f => rgba(render(def, part, f).px));
    const entry = { id: part };
    if (frames.length > 1) entry.frames = frames.map(f => `${RES_DIR}/${id}/${part}_${f}.png`);
    else entry.img = `${RES_DIR}/${id}/${part}.png`;
    Object.assign(entry, { pivot: J[part].map(round1), parent, z, hp, label });
    if (!cut || cut.unbreakable) entry.unbreakable = true;
    if (cut) for (const k of ['disables', 'weakens', 'alsoDetach', 'vital']) if (cut[k] !== undefined) entry[k] = cut[k];
    parts.push(entry);
  }
  // feet: the lowest opaque row of the whole idle figure; the shadow is that row's span plus a bit
  const g = lowest(all.px, W, H);
  const points = {};
  for (const [name, part] of Object.entries(cfg.points || {})) if (J[name]) points[name] = { part, at: J[name].map(round1) };
  const rig = {
    family: cfg.family, variant: cfg.variant, size: [W, H], scale: SCALE,
    ground: [round1((g.x0 + g.x1 + 1) / 2), g.gy], width: Math.max(6, Math.round((g.x1 - g.x0 + 1) * 1.4)),
    material: cfg.material, parts, groups: {}, points,
  };
  return { rig, images, W, H };
}

const rigFile = path.join(root, 'assets', 'data', 'hell_rigs.json');
const data = JSON.parse(fs.readFileSync(rigFile, 'utf8'));
for (const id of Object.keys(MOBS)) {
  if (ONLY && !ONLY.includes(id)) continue;
  const { rig, images, W, H } = build(id, MOBS[id]);
  const dir = path.join(root, 'assets', 'sprites', 'hell', 'rigs', id);
  fs.mkdirSync(dir, { recursive: true });
  for (const e of rig.parts) {
    const frames = images[e.id];
    if (frames.length > 1) frames.forEach((img, f) => fs.writeFileSync(path.join(dir, `${e.id}_${f}.png`), encodePng(W, H, img)));
    else fs.writeFileSync(path.join(dir, `${e.id}.png`), encodePng(W, H, frames[0]));
  }
  data.rigs[id] = rig;
  console.log(id, rig.parts.length, 'parts, ground', rig.ground.join(','), '->', dir);
}
fs.writeFileSync(rigFile, JSON.stringify(data, null, 1) + '\n');
console.log('rigs -> assets/data/hell_rigs.json');

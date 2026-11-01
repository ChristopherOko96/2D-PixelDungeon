// Builds assets/data/story_rigs.json: part rigs for the story figures that still drew as a
// flipbook or a plain sprite, the way krypta_boss_rigs.json was built (rigs.json format,
// loaded by src/rig/rig_library.gd after the Krypta bosses):
//   krypta_leerenbomber, krypta_mimik, krypta_leerenrufer  painted by krypta_monsters.js at art
//       size (idle frame 0; the Mimik's teeth frame, like the Truhenfresser), so a def's "rig"
//       copies them at def.scale (src/hell/drake_rig_host.gd adopt_looks)
//   frost_snowman      cut from assets/sprites/frost/mob_snowman_f0.png shrunk back by its x3
//       (frost_theme.json rigs: mob_snowman_f), scale 1.5 like the other frost cuts
//   necro_hero         the necromancer hero's 0x72 sprite with his Knochenstab as the held item
//       (src/hero/story_hero.gd CLASS_RIGS)
//   krypta_knochenkoloss  rigs.json's bone_colossus with the big hammer the crypt painter gives
//       him, held in the arm's hand (it swings with the arm and comes loose when he falls)
//   skel_archer_short, frost_skeleton_short  the skeleton archers of rigs.json with a bow cut to
//       the 16 px skeleton's size: the 0x72 bow (25 px) is sized for the 28 px heroes and
//       reached from above the skull to 10 px under the feet
// Every rect is inclusive [x0, y0, x1, y1]; an opaque pixel belongs to the first part whose
// rect holds it. Usage (repo root): node tools/krypta_dungeon/export_story_rigs.js
'use strict';
const fs = require('fs');
const path = require('path');

const root = process.argv[2] || path.join(__dirname, '..', '..');
const KM = require('./krypta_monsters.js');
const H = require(path.join(root, 'tools/hell_dungeon/concepts/hybrid.js'));
const RIGS = JSON.parse(fs.readFileSync(path.join(root, 'assets/data/rigs.json'), 'utf8'));
const OUT = path.join(root, 'assets/data/story_rigs.json');
// palette keys: one character per colour (rig_library _pixels reads row[x]); the frost cut has
// more than 62 shades, so Latin letters from U+00C0 follow the ASCII ones
const CH = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789' + Array.from({ length: 400 }, (_, i) => String.fromCharCode(0xC0 + i)).join('');

// {palette, rows} of a w x h frame; get(x, y) -> '#rrggbb' or null.
function art(w, h, get) {
  const palette = {}, key = {}, rows = [];
  for (let y = 0; y < h; y++) {
    let row = '';
    for (let x = 0; x < w; x++) {
      const c = get(x, y);
      if (!c) { row += '.'; continue; }
      if (!(c in key)) { key[c] = CH[Object.keys(key).length]; palette[key[c]] = c; }
      row += key[c];
    }
    rows.push(row);
  }
  return { palette, rows };
}
const hex = (d, i) => '#' + [0, 1, 2].map(k => d[i + k].toString(16).padStart(2, '0')).join('');

// A crypt monster's frame as the game's atlas paints it (krypta_monsters.js render).
function painted(id, anim, frame) {
  const r = KM.render(id, anim, frame);
  return art(r.w, r.h, (x, y) => r.data[(y * r.w + x) * 4 + 3] ? hex(r.data, (y * r.w + x) * 4) : null);
}

// A PNG shrunk back to art size (every k-th pixel; the frost skin enlarged with nearest).
function cut(file, k) {
  const img = H.decodePng(fs.readFileSync(path.join(root, file)));
  const w = img.w || img.width, d = img.rgba || img.data, h = img.h || img.height;
  return art(w / k, h / k, (x, y) => { const i = ((y * k) * w + x * k) * 4; return d[i + 3] > 127 ? hex(d, i) : null; });
}

const part = (id, rects, pivot, parent, z, hp, label, extra) => Object.assign({ id, rects, pivot, parent, z, hp, label }, extra || {});

// The skeleton's bow: 13 px (the skeleton stands 14), the 0x72 bow's wood and outline; the
// string column (x 7, #d3bfa9) is taken out by rig_library _remove_bow_string, the renderer
// draws the drawn string itself.
const SHORT_BOW = {
  palette: { A: '#222222', W: '#8f4029', S: '#d3bfa9' },
  rows: [
    '........AA..',
    '.......SWWA.',
    '.......S.WWA',
    '.......S..WA',
    '.......S..WA',
    '.......S..WA',
    '.......S..WA',
    '.......S..WA',
    '.......S..WA',
    '.......S..WA',
    '.......S.WWA',
    '.......SWWA.',
    '........AA..',
  ],
};
// grip: the bow's middle on its wood, hand: in front of the ribs, so it spans skull to feet
function shortBow(name) {
  const rig = JSON.parse(JSON.stringify(RIGS.rigs[name]));
  // bow: false keeps the painted string; the renderer's drawn string is sized for the 25 px 0x72 bow
  for (const item of rig.items) if (item.id === 'weapon') Object.assign(item, { img: 'kb_bow_short', bow: false, grip: [10.5, 6.5], hand: [12, 10], tip: [7.5, 6.5] });
  return rig;
}

// The Knochenkoloss (Krypta floor 9): bone_colossus plus the 0x72 big hammer of krypta_monsters.js
// (grip 3 px above the handle's end, like the painter), head tilted back off the face
function colossus() {
  const rig = JSON.parse(JSON.stringify(RIGS.rigs.bone_colossus));
  rig.items = [{ id: 'weapon', img: 'big_hammer', grip: [5, 34], hand: [8.5, 25], parent: 'arm', rest: -0.35, z: 5, tip: [5, 4], hp: 20, label: 'Knochenhammer', disables: 'attack' }];
  return rig;
}

const data = {
  _note: 'Generated by tools/krypta_dungeon/export_story_rigs.js; do not edit by hand. Part rigs of the story figures that drew as a flipbook or sprite (Krypta: Leerenbomber, Mimik, Leerenrufer; Frostgruft: Schneemann; the necromancer hero) and the skeleton archers with a bow of their size. Same format as rigs.json (see krypta_boss_rigs.json _note); loaded by src/rig/rig_library.gd after krypta_boss_rigs.json and may use rigs.json image keys (skelet, bow).',
  images: {
    necro_hero: 'res://assets/sprites/0x72/necromancer_idle_anim_f0.png',
    staff_necro: 'res://assets/sprites/items/staff_necro.png',
    big_hammer: 'res://assets/sprites/0x72/weapon_big_hammer.png',
  },
  pixel_art: {
    kb_leerenbomber: painted('leerenbomber', 'idle', 0),
    kb_mimik: painted('mimik', 'attack', 0),
    kb_leerenrufer: painted('leerenrufer', 'idle', 0),
    frost_snowman: cut('assets/sprites/frost/mob_snowman_f0.png', 3),
    kb_bow_short: SHORT_BOW,
  },
  scales: { frost_snowman: 1.5, frost_skeleton_short: RIGS.scales.frost_skeleton || 1.5 },
  rigs: {
    // a void skull on a stalk and two stubby feet; the family swells it on the fuse and bursts
    krypta_leerenbomber: {
      img: 'kb_leerenbomber', family: 'bomber', ground: [11, 23], width: 8,
      parts: [
        part('skull', [[5, 9, 16, 17]], [11, 18], 'core', 3, 2, 'Schädel', { vital: true }),
        part('core', [[8, 18, 13, 21]], [11, 21], null, 2, 1, 'Leerenkern'),
        part('legs', [[5, 22, 16, 23]], [11, 22], null, 1, 1, 'Beinchen'),
      ],
      items: [],
      points: { mouth: { part: 'skull', at: [11, 14] }, core: { part: 'core', at: [11, 19] } },
    },
    // the Truhenfresser's cut on the 0x72 mimic: the lid lifts about its back hinge
    krypta_mimik: {
      img: 'kb_mimik', family: 'mimic', ground: [10, 19], width: 8,
      parts: [
        part('tongue', [[8, 13, 9, 13]], [9, 13], 'teeth', 4, 1, 'Zunge'),
        part('teeth', [[2, 11, 17, 14]], [10, 11], 'box', 3, 2, 'Zahnreihe'),
        part('lid', [[2, 5, 17, 10]], [3, 10], 'box', 2, 2, 'Deckel'),
        part('box', [[2, 15, 17, 19]], [10, 19], null, 1, 4, 'Truhenleib', { vital: true }),
      ],
      items: [],
      points: { mouth: { part: 'teeth', at: [10, 12] }, core: { part: 'teeth', at: [10, 12] } },
    },
    // the void lord's ids (rig_poses.gd void_lord): the hood is "eye" (the face with its three
    // lights), the robe "core"; the wisp hands are the claws, lost first on death
    krypta_leerenrufer: {
      img: 'kb_leerenrufer', family: 'void', ground: [24, 49], width: 22,
      parts: [
        part('claw_l', [[8, 33, 12, 38]], [13, 34], 'core', 4, 3, 'Linke Hand'),
        part('claw_r', [[35, 20, 42, 25], [35, 35, 42, 40]], [33, 30], 'core', 4, 3, 'Rechte Hand'),
        part('eye', [[12, 8, 40, 27]], [24, 28], 'core', 3, 6, 'Kapuze'),
        part('core', [[0, 28, 47, 49]], [24, 49], null, 2, 14, 'Leerenleib', { vital: true }),
      ],
      items: [],
      points: { mouth: { part: 'eye', at: [23, 23] }, core: { part: 'core', at: [24, 36] } },
    },
    // three snow balls, hat and carrot on the head, twig arms on the middle ball
    frost_snowman: {
      img: 'frost_snowman', family: 'biped', ground: [17, 64], width: 14, material: 'flesh',
      parts: [
        part('head', [[9, 27, 25, 43]], [17, 43], 'body', 3, 3, 'Kopf', { vital: true }),
        part('body', [[9, 44, 24, 51]], [17, 51], 'base', 2, 3, 'Bauch'),
        part('arm_l', [[0, 40, 16, 48]], [9, 45], 'body', 1, 1, 'Linker Zweig'),
        part('arm_r', [[17, 40, 33, 48]], [24, 45], 'body', 4, 1, 'Rechter Zweig'),
        part('base', [[0, 49, 33, 65]], [17, 64], null, 1, 4, 'Fuß'),
      ],
      items: [],
    },
    // like the wizard: robe, head, the hood's tip as "hat", the Knochenstab in the front hand
    necro_hero: {
      img: 'necro_hero', family: 'hero', attack: 'staff', ground: [7, 22], width: 11,
      parts: [
        part('robe', [[0, 19, 15, 22]], [7, 22], null, 1, 0, 'Kutte'),
        part('hat', [[0, 8, 15, 10]], [7, 11], 'head', 3, 0, 'Kapuze'),
        part('head', [[0, 11, 15, 18]], [7, 19], 'robe', 2, 0, 'Kopf'),
      ],
      items: [{ id: 'weapon', img: 'staff_necro', grip: [3.5, 18], hand: [13, 17], parent: 'robe', rest: 0.1, z: 4, tip: [3.5, 3] }],
    },
    krypta_knochenkoloss: colossus(),
    skel_archer_short: shortBow('skel_archer'),
    frost_skeleton_short: shortBow('frost_skeleton'),
  },
};
fs.writeFileSync(OUT, JSON.stringify(data, null, 1) + '\n');
console.log(Object.keys(data.rigs).length, 'rigs ->', OUT);

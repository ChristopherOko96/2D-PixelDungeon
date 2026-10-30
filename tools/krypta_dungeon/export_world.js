// Writes the crypt world pack (floors, names, wording, dressing tables) for the Godot port:
// assets/data/krypta_world.json. Run after changing krypta_floors.js.
// Usage (repo root): node tools/krypta_dungeon/export_world.js
'use strict';
const fs = require('fs');
const path = require('path');
const KF = require('./krypta_floors.js');
const out = path.resolve(__dirname, '..', '..', 'assets', 'data', 'krypta_world.json');
const pack = Object.assign({ _note: 'Story 1 Krypta der Verdammten: the world pack for the world kit generator (src/world_kit/world_core.gd, src/world_kit/world_pack.gd). Written by tools/krypta_dungeon/export_world.js from krypta_floors.js; the browser preview reads the same values. floors: per floor title, ring (circle), boss, size of the slot grid (gc x gr), critical path length, hazard shares (lava = mire, river, spikes, vents, holes, pits), loop share, soul bowls (fire), shooters, final. names/suffixes: room name parts per ring. words: hell wording -> crypt wording. gate_banner: banner colour per floor (red when missing). foot: furniture footprints [solid width, depth, cells]. mimic_fight / mimic_treasure: share of chests that are mimics.', schema: 1 }, KF.PACK);
fs.writeFileSync(out, JSON.stringify(pack, null, 1) + '\n');
console.log('wrote', path.relative(process.cwd(), out));

// Writes the hell world pack (floors, names, wording, dressing tables) for the Godot port:
// assets/data/hell_world.json. Run after changing hell_world.js.
// Usage (repo root): node tools/hell_dungeon/export_world.js
'use strict';
const fs = require('fs');
const path = require('path');
const HW = require('./hell_world.js');
const out = path.resolve(__dirname, '..', '..', 'assets', 'data', 'hell_world.json');
const pack = Object.assign({ _note: 'Story 3 Der Hell-Dungeon: the world pack for the world kit generator (src/world_kit/world_core.gd, src/world_kit/world_pack.gd). Written by tools/hell_dungeon/export_world.js from hell_world.js; the browser preview reads the same values. floors: per floor title, ring (circle), boss, size of the slot grid (gc x gr), critical path length, hazard shares (lava, river, spikes, vents, holes, pits), loop share, fire bowls (fire), shooters, final; two / twoSide: share of 2-slot fight rooms on the path and in side branches, trimLarge: corner cut of 3-slot rooms. names/suffixes: room name parts per ring. words: generator wording -> hell wording. gate_banner: banner colour per floor (the hell red when missing). blue / blue_props: floor 10 blue fire. foot: furniture footprints [solid width, depth, cells]. mimic_fight / mimic_treasure: share of chests that are mimics.', schema: 1 }, HW.PACK);
fs.writeFileSync(out, JSON.stringify(pack, null, 1) + '\n');
console.log('wrote', path.relative(process.cwd(), out));

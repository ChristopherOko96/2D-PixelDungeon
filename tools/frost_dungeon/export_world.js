// Writes the frost world pack (floors, names, wording, dressing tables) for the Godot port:
// assets/data/frost_world.json. Run after changing frost_world.js.
// Usage (repo root): node tools/frost_dungeon/export_world.js
'use strict';
const fs = require('fs');
const path = require('path');
const FW = require('./frost_world.js');
const out = path.resolve(__dirname, '..', '..', 'assets', 'data', 'frost_world.json');
const pack = Object.assign({ _note: 'Story 2 Die Frostgruft: the world pack for the world kit generator (src/world_kit/world_core.gd, src/world_kit/world_pack.gd). Written by tools/frost_dungeon/export_world.js from frost_world.js; the browser preview reads the same values. floors: per floor title, ring (circle), boss, size of the slot grid (gc x gr), critical path length, hazard shares (lava = glaze ice, river, spikes, vents, holes, pits), loop share, frost flames (fire), shooters, final. names/suffixes: room name parts per ring. words: generator wording -> frost wording. gate_banner: banner colour per floor (red when missing). blue / blue_props: floor 10 blue fire. foot: furniture footprints [solid width, depth, cells]. mimic_fight / mimic_treasure: 0, the Frostgruft has no mimics.', schema: 1 }, FW.PACK);
fs.writeFileSync(out, JSON.stringify(pack, null, 1) + '\n');
console.log('wrote', path.relative(process.cwd(), out));

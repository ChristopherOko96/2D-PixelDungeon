// Writes the cheapest Schatz way of every jump puzzle room (solver.js) for replay.gd, which plays them in
// the real game. Default target: Godot's user:// folder of this project (user://jump_steps.json).
//   node tools/krypta_dungeon/jump_puzzles/steps.js [file]
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const solver = require('./solver');

const DIR = path.resolve(__dirname, '../../../assets/data/world_rooms/krypta');
const project = JSON.parse(JSON.stringify(fs.readFileSync(path.resolve(__dirname, '../../../project.godot'), 'utf8').match(/config\/name="([^"]+)"/)[1]));
const userDir = process.platform === 'win32' ? path.join(process.env.APPDATA, 'Godot/app_userdata', project) : path.join(os.homedir(), '.local/share/godot/app_userdata', project);
const target = process.argv[2] || path.join(userDir, 'jump_steps.json');
const out = {};
for (const f of fs.readdirSync(DIR).filter((f) => /^k_sprung.*\.json$/.test(f)).sort()) {
  const room = JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8'));
  const h = solver.analyze(room).chests.find((c) => c.loot === 'hoard' && c.reached);
  if (h) out[f.replace('.json', '')] = { chest: h.at.split(',').map(Number), steps: h.steps };
  else console.log(`${f}: kein erreichbarer Schatz`);
}
fs.writeFileSync(target, JSON.stringify(out, null, 1));
console.log(`${Object.keys(out).length} Wege nach ${target}`);

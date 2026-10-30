// Writes reference floors of the JS world kit for the Godot parity test
// (tests/world_kit_parity_test.gd): for a few run numbers all ten floors of a world, reduced to what
// the runtime reads. Usage (repo root):
//   node tools/world_kit/dump_floors.js <skin manifest.json> [out=tests/data/world_kit_reference.json] [pack module]
// The pack module defaults to the crypt; the hell: node tools/world_kit/dump_floors.js
//   assets/sprites/hell/manifest.json tests/data/world_kit_reference_hell.json tools/hell_dungeon/hell_world.js
'use strict';
const fs = require('fs');
const path = require('path');
const core = require('./world_core.js');
const KF = require(process.argv[4] ? path.resolve(process.argv[4]) : '../krypta_dungeon/krypta_floors.js');

const root = path.resolve(__dirname, '..', '..');
const man = JSON.parse(fs.readFileSync(path.resolve(process.argv[2]), 'utf8'));
const out = path.resolve(root, process.argv[3] || 'tests/data/world_kit_reference.json');
const SIZES = {}; for (const [k, v] of Object.entries(man)) SIZES[k] = [v.w, v.h];
const r1 = v => Math.round(v * 10) / 10;
const RUNS = [12345, 987654321];

const floors = [];
for (const run of RUNS) for (let n = 1; n <= 10; n++) {
  const W = KF.dress(core.buildFloor(n, SIZES, KF.forRun(run)));
  floors.push({
    run, n, seed: W.seed, cols: W.COLS, rows: W.ROWS,
    grid: Array.from(W.grid).join(''),
    tiles: W.tileAt.join(','),
    rooms: W.rooms.map(r => [r.id, r.type, r.gtype, r.bx, r.by, r.bw, r.bh, r.name]),
    doors: W.doors.map(d => [d.a.index, d.b.index, d.kind, d.key || '', d.group || '', d.x0, d.y0]),
    groups: W.groups,
    ents: W.ents.map(e => [e.type, r1(e.x), r1(e.y), e.room]),
    props: W.props.map(p => [p.name, r1(p.x), r1(p.y)]),
    decals: W.decals.map(d => [d.name, r1(d.x), r1(d.y)]),
    wall: W.wallDecor.map(w => [w.name, r1(w.x), r1(w.y)]),
    lights: W.lights.map(l => [r1(l.x), r1(l.y), l.c]),
  });
}
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify({ runs: RUNS, floors }));
console.log('wrote', floors.length, 'floors ->', path.relative(root, out), (fs.statSync(out).size / 1e6).toFixed(2), 'MB');

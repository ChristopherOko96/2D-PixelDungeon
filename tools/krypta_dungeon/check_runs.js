// Builds many random crypt runs (10 floors each) and checks every floor against the dungeon rules.
// Prints what failed and how often; exit code 1 if any floor broke a rule.
// Usage (repo root): node tools/krypta_dungeon/check_runs.js <skin manifest.json> [runs=200] [first run number] [pack module]
// The pack module defaults to the crypt; the hell: tools/hell_dungeon/hell_world.js.
'use strict';
const path = require('path');
const HC = require('../world_kit/world_core.js');
const KF = require(process.argv[5] ? path.resolve(process.argv[5]) : './krypta_floors.js');

const man = require(path.resolve(process.argv[2]));
const RUNS = +(process.argv[3] || 200), FIRST = +(process.argv[4] || 1);
const SIZES = {}; for (const [k, v] of Object.entries(man)) SIZES[k] = [v.w, v.h];

// Every rule a generated floor must keep. Returns the broken ones.
function rules(W, n) {
  const bad = [], byType = t => W.rooms.filter(r => r.type === t);
  if (byType('start').length !== 1) bad.push('one start room');
  if (byType('boss').length !== 1) bad.push('one boss room');
  if (byType('portal').length !== 1) bad.push('one stairs room after the boss');
  const boss = byType('boss')[0];
  if (boss && boss.name.indexOf(KF.FLOORS[n].boss.name) < 0) bad.push('fixed boss of the floor');
  const q = HC.criticalRooms(W);
  if (!q.need) bad.push('boss reachable with the keys of the floor');
  else if (q.need.length >= W.rooms.length) bad.push('quickest path skips some rooms');
  // every room reachable once all keys are held, puzzles solved and secret walls broken
  const adj = new Map(W.rooms.map(r => [r.index, []]));
  for (const d of W.doors) { adj.get(d.a.index).push(d.b.index); adj.get(d.b.index).push(d.a.index); }
  const seen = new Set([byType('start')[0].index]), todo = [...seen];
  while (todo.length) for (const nb of adj.get(todo.pop())) if (!seen.has(nb)) { seen.add(nb); todo.push(nb); }
  if (seen.size !== W.rooms.length) bad.push('every room connected');
  // each locked door has its key somewhere on the floor
  const keys = new Set(W.rooms.filter(r => r.drop).map(r => r.drop).concat(W.ents.filter(e => e.type === 'key').map(e => e.key)));
  for (const d of W.doors) if (d.kind === 'lock' && !keys.has(d.key)) bad.push('key ' + d.key + ' exists');
  // each puzzle door has its pieces
  for (const d of W.doors) if (d.kind === 'puzzle' && !W.ents.some(e => e.group === d.group)) bad.push('puzzle pieces for ' + d.group);
  // every bridge spans the whole river and lands on floor on both banks
  for (const d of W.decals) {
    if (!d.name.startsWith('bridge')) continue;
    const x0 = Math.round((d.x - (d.w - 20) / 2) / 96), x1 = Math.round((d.x + (d.w - 20) / 2) / 96) - 1;
    const y0 = Math.round((d.y - (d.h - 18) / 2) / 96), y1 = Math.round((d.y + (d.h - 18) / 2) / 96) - 1;
    const g = (x, y) => W.grid[y * W.COLS + x];
    const ends = d.name === 'bridge_h' ? [[x0 - 1, y0], [x0 - 1, y1], [x1 + 1, y0], [x1 + 1, y1]] : [[x0, y0 - 1], [x1, y0 - 1], [x0, y1 + 1], [x1, y1 + 1]];
    if (ends.some(([x, y]) => g(x, y) !== 1)) noBank++;
    if ((d.name === 'bridge_h' ? y1 - y0 : x1 - x0) > 1) bad.push('bridge at most two cells wide');
  }
  if (!W.doors.some(d => d.kind === 'secret')) noSecret++;
  // world kit rules
  for (const r of W.rooms) {
    if (r.type === 'combat' && r.slots.length < 2) bad.push('fight rooms medium or large');
    if (r.slots.length === 1 && !['start', 'key', 'treasure', 'secret', 'portal', 'stairs'].includes(r.type)) bad.push('small rooms only for keys, vaults, hidden rooms, stairs');
    if (r.type === 'stairs' && (n < 2 || !W.ents.some(e => e.type === 'stairs' && e.room === r.index) || !W.doors.some(d => d.b === r && d.kind === 'secret' && d.group === 'stiege' && W.ents.some(e => e.type === 'lever' && e.room === d.a.index) && !W.ents.some(e => e.type === 'skullheap' && W.doors[e.door] === d)))) bad.push('stairs hidden behind a wall opened by an unlit torch, from floor 2 on');
  }
  const keyRooms = byType('key');
  if (keyRooms.length !== 1) bad.push('one key room');
  else {
    const k = keyRooms[0], here = t => W.ents.filter(e => e.room === k.index && e.type === t);
    if (k.slots.length !== 1) bad.push('key room is small');
    if (!here('key').some(e => e.key === 'C')) bad.push('boss key lies in the key room');
    if (!here('shop').length || !W.props.some(p => p.name === 'shop_table' && W.roomAt[Math.floor(p.y / 96 - .3) * W.COLS + Math.floor(p.x / 96)] === k.index)) bad.push('shop table beside the key');
    const well = here('well')[0];
    if (!well || Math.floor(well.y / 96 - .6) !== k.by) bad.push('mana fountain against the north wall');
  }
  if (W.rooms.some(r => r.drop === 'C')) bad.push('boss key only in the key room');
  { const k = byType('key')[0], kd = k && W.doors.filter(d => d.a === k || d.b === k);
    if (!k || kd.length !== 1 || kd[0].dir !== 'h' || kd[0].x0 !== k.bx + k.bw || kd[0].y1 !== k.by + k.bh - 1) bad.push('key room entered from the bottom right'); }
  for (const r of W.rooms) if (HC.blockedWays(W, r).length) { bad.push('no way blocked by mire, pits or furniture'); break; }
  const shelves = W.props.filter(p => p.name === 'shelf');
  if (shelves.length !== 2 || shelves.some(p => W.rooms[W.roomAt[Math.floor(p.y / 96 - .3) * W.COLS + Math.floor(p.x / 96)]].gtype !== 'key')) bad.push('bookshelves only beside the shop');
  if (W.ents.some(e => e.type === 'crate' && W.rooms[e.room].gtype === 'key')) bad.push('nothing breakable in the key room');
  { const k = byType('key')[0], cells = k ? HC.cellsOf(W, k) : [];
    if (!k || !W.ents.some(e => e.type === 'npc' && e.room === k.index) || new Set(cells.map(([x, y]) => W.tileAt[y * W.COLS + x])).size !== 1) bad.push('tidy key room: merchant behind the shop, one floor slab');
    if (k && W.decals.some(d => !/^(rug_red|mat|rug_square)$/.test(d.name) && W.roomAt[Math.floor(d.y / 96) * W.COLS + Math.floor(d.x / 96)] === k.index)) bad.push('nothing lying around in the key room');
    if (k && (!W.decals.some(d => d.name === 'rug_red' && W.roomAt[Math.floor(d.y / 96) * W.COLS + Math.floor(d.x / 96)] === k.index) || W.wallDecor.filter(w => /banner/.test(w.name) && Math.floor(w.x / 96) >= k.bx && Math.floor(w.x / 96) < k.bx + k.bw && Math.abs(w.y + 68 - k.by * 96) < 20).length < 2)) bad.push('key room with rug and two banners'); }
  const bossDoors = W.doors.filter(d => d.a === boss || d.b === boss);
  const gate = bossDoors.find(d => d.kind === 'lock' && d.key === 'C');
  if (!gate || bossDoors.filter(d => d.kind !== 'boss').length !== 1) bad.push('boss door opens only with the boss key');
  else {
    const outer = gate.a === boss ? gate.b : gate.a;
    if (gate.dir !== 'v' || outer.by < boss.by) bad.push('boss entered from below');
    const near = (name, dx) => W.wallDecor.filter(w => w.name === name && Math.abs(w.x - gate.cx) < dx * 96 && Math.abs(w.y - (gate.y1 + 1) * 96) < 100).length;
    const banner = { 1: 'blue', 2: 'green', 4: 'purple', 5: 'gold', 7: 'teal', 8: 'pink' }[n], torch = n === 10 ? 'wall_torch_blue' : 'wall_torch_hook';
    if (near(banner ? 'boss_banner_' + banner : 'boss_banner', 2.6) !== 2 || near(torch, 3.8) < 2 || !W.decals.some(d => d.name === 'carpet' && Math.abs(d.x - gate.cx) < 2)) bad.push('boss gate with two banners (floor colour), two torches and a carpet');
  }
  const seq = W.groups.seq, plates = W.ents.filter(e => e.type === 'plate' && e.group === 'seq');
  if (!seq || plates.length < 4 || plates.length > 6 || plates.length !== seq.count || plates.map(e => e.order).sort().join('') !== seq.sequence.slice().sort().join('')) bad.push('four to six pressure plates with a fixed order');
  else {
    const d = W.doors.find(x => x.group === 'seq');
    if (!d || !((d.kind === 'puzzle' && d.b.gtype === 'pvault') || (d.kind === 'secret' && d.b.gtype === 'hidden'))) bad.push('plates open a giant vault or a hidden room');
    const s = seq.sequence.join(''), up = seq.sequence.slice().sort().join('');
    if (s === up || s === up.split('').reverse().join('') || (seq.count === 4 && ['1243', '2431', '4312', '3124', '1342', '3421', '4213', '2134'].includes(s))) bad.push('plate order not plain or round the square');
    plateOrders.add(seq.sequence.join(''));
    for (const e of plates) { const g = W.grid[Math.floor(e.y / 96) * W.COLS + Math.floor(e.x / 96)]; if (g !== 1) bad.push('plates on plain floor'); }
  }
  return bad;
}

const fails = {}, shapes = new Set(), plateOrders = new Set();
let floors = 0, worst = 0, broken = 0, noSecret = 0, noBank = 0;
for (let run = FIRST; run < FIRST + RUNS; run++) {
  const opts = KF.forRun(run);
  for (let n = 1; n <= 10; n++) {
    const t = Date.now();
    let bad;
    try {
      const W = KF.dress(HC.buildFloor(n, SIZES, opts));
      bad = rules(W, n);
      shapes.add(n + ':' + W.rooms.map(r => r.slots.join(';')).join('|'));
    } catch (e) { bad = ['generator: ' + e.message]; }
    worst = Math.max(worst, Date.now() - t); floors++;
    if (bad.length) broken++;
    for (const b of bad) { fails[b] = fails[b] || []; if (fails[b].length < 5) fails[b].push('run ' + run + ' E' + n); }
  }
}
console.log(`${RUNS} runs, ${floors} floors, ${shapes.size} different layouts, slowest floor ${worst} ms, ${broken} floors broke a rule, ${noSecret} without a secret room (allowed), ${noBank} bridges without floor on both banks, ${plateOrders.size} different plate orders`);
for (const [rule, where] of Object.entries(fails)) console.log('  FAIL', rule, '->', where.join(', '));
process.exit(broken ? 1 : 0);

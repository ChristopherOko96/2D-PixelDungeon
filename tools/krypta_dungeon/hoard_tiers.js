// Rates every puzzle room of the Krypta (role jump: jump puzzles and labyrinths) and writes the tier of its
// Schatz chest (loot.tier, src/world_kit/room_contents.gd, world_room_contents.json hoard.tiers). Only the
// tier is touched: the rest of each file stays as the Weltbauer saved it.
//
//   node tools/krypta_dungeon/hoard_tiers.js            (shows the rating, writes nothing)
//   node tools/krypta_dungeon/hoard_tiers.js --write
//
// Jump puzzle: score = throws + hurts on the cheapest way to the Schatz (solver.js) + 3 per riddle group
// (plates, levers, fire bowls) + 0.5 per plate + 3 per key on the way. Labyrinth: score = dead ends +
// half the shortest way from a door to the heart. The tier comes from the thresholds below; a room may
// pin its tier with "hoard_tier" at the top of its file (the Weltbauer keeps unknown keys).
'use strict';
const fs = require('fs');
const path = require('path');
const solver = require('./jump_puzzles/solver');

const DIR = path.resolve(__dirname, '../../assets/data/world_rooms/krypta');
const JUMP = [12, 21];   // score from which tier 2, tier 3 start
const MAZE = [0, 31];    // a labyrinth is at least tier 2; from this score tier 3

function tierOf(score, cut) { return score >= cut[1] ? 3 : score >= cut[0] ? 2 : 1; }

/** Dead ends and the shortest way door -> heart chest of a labyrinth, on its free floor. */
function mazeScore(room) {
  const W = room.width, H = room.height;
  const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? '0' : room.cells[y][x]);
  const open = (x, y) => at(x, y) !== '0' && at(x, y) !== '4';
  const zone = new Set();
  for (const [x0, y, x1] of room.maze_zone || []) for (let x = x0; x <= x1; x++) zone.add(x + ',' + y);
  let dead = 0;
  for (const k of zone) {
    const [x, y] = k.split(',').map(Number);
    if (!open(x, y)) continue;
    const n = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([dx, dy]) => open(x + dx, y + dy)).length;
    if (n === 1) dead++;
  }
  const hoard = room.objects.find((o) => o.kind === 'chest' && (o.loot || {}).type === 'hoard');
  const goal = [Math.floor(hoard.x / 96), Math.floor(hoard.y / 96)];
  // breadth first from every walkway cell (outside the zone) to a cell next to the heart chest
  const dist = new Map();
  const q = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (open(x, y) && !zone.has(x + ',' + y)) { dist.set(x + ',' + y, 0); q.push([x, y]); }
  let way = 0;
  while (q.length) {
    const [x, y] = q.shift();
    const d = dist.get(x + ',' + y);
    if (Math.abs(x - goal[0]) + Math.abs(y - goal[1]) === 1) { way = d; break; }
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const a = x + dx, b = y + dy;
      if (!open(a, b) || dist.has(a + ',' + b) || (a === goal[0] && b === goal[1])) continue;
      dist.set(a + ',' + b, d + 1);
      q.push([a, b]);
    }
  }
  return { score: dead + way / 2, note: `${dead} Sackgassen, Weg ${way}` };
}

function jumpScore(room) {
  const rep = solver.analyze(room);
  const h = rep.chests.filter((c) => c.loot === 'hoard' && c.reached).sort((a, b) => b.throws - a.throws)[0];
  if (!h) return { score: 0, note: 'Schatz nicht erreichbar' };
  const groups = new Set(room.objects.filter((o) => ['plate', 'lever', 'brazier'].includes(o.kind)).map((o) => o.group)).size;
  const plates = room.objects.filter((o) => o.kind === 'plate').length;
  const keys = room.objects.filter((o) => o.kind === 'chest' && (o.loot || {}).type === 'key').length;
  const score = h.throws + h.hurts + 3 * groups + 0.5 * plates + 3 * keys;
  return { score, note: `${h.throws} Würfe, ${h.hurts} Treffer, ${groups} Gruppen, ${plates} Platten, ${keys} Schlüssel` };
}

/** Writes `tier` into every Schatz chest of the file's text, keeping its layout. */
function withTier(text, tier) {
  return text.replace(/("type":\s*"hoard")(,(\s*)"tier":\s*[\d.]+)?/g, (m, a, b, c) => {
    const indent = (text.slice(0, text.indexOf(m)).match(/\n([\t ]*)[^\n]*$/) || [, '\t\t\t\t'])[1];
    return `${a},\n${indent}"tier": ${tier}`;
  });
}

if (require.main === module) {
  const write = process.argv.includes('--write');
  for (const f of fs.readdirSync(DIR).filter((f) => f.endsWith('.json')).sort()) {
    const text = fs.readFileSync(path.join(DIR, f), 'utf8');
    const room = JSON.parse(text);
    if (room.role !== 'jump') continue;
    if (!room.objects.some((o) => o.kind === 'chest' && (o.loot || {}).type === 'hoard')) { console.log(`${f}: KEINE Schatztruhe`); continue; }
    const r = room.maze ? mazeScore(room) : jumpScore(room);
    const tier = room.hoard_tier || tierOf(r.score, room.maze ? MAZE : JUMP);
    console.log(`${f.padEnd(34)} Stufe ${tier}  (${r.score.toFixed(1)} Punkte: ${r.note})`);
    if (write) fs.writeFileSync(path.join(DIR, f), withTier(text, tier));
  }
}
module.exports = { mazeScore, jumpScore, withTier };

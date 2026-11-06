// Goes through every room file of a world that the floors use and reports what a player would trip
// over: two pieces on one spot, a piece in a wall or over a pit, a solid piece in a doorway, a chest,
// lever or Inschrift nobody can stand next to, doors that need the puzzle to reach each other.
// It reports observations, it never edits a room.
//
//   node tools/krypta_dungeon/room_audit.js [world] [--all]     (world: krypta; --all also lists clean rooms)
'use strict';
const fs = require('fs');
const path = require('path');
const { areas } = require('./jump_puzzles/free_ways');

const C = 96;
const world = process.argv.slice(2).find((a) => !a.startsWith('--')) || 'krypta';
const DIR = path.resolve(__dirname, '../../assets/data/world_rooms', world);

/** The cell a piece stands in (its foot, the way the Weltbauer draws it). */
function cellOf(o) { return [Math.floor(o.x / C), Math.floor((o.y - 1) / C)]; }

const FLAT = (o) => o.kind === 'prop' && (o.wall_decor || o.decal || o.block === false || o.layer === 'floor');
const ON_WALL = new Set(['gate', 'secret', 'lever', 'light']);
const NEEDS_ROOM = new Set(['chest', 'lever', 'tablet', 'brazier']);

function audit(room) {
  const out = [];
  const W = room.width, H = room.height;
  const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? '0' : room.cells[y][x]);
  const spots = new Map();
  const solid = new Set();
  const gateCells = new Set();
  for (const o of room.objects) if (o.kind === 'gate' || o.kind === 'secret') {
    const a = [Math.floor(o.x / C), Math.floor(o.y / C)];
    const b = o.dir === 'h' ? [a[0], a[1] + 1] : [a[0] + 1, a[1]];
    gateCells.add(a.join(',')); gateCells.add(b.join(','));
  }
  for (const o of room.objects) {
    if (o.kind === 'gate' || o.kind === 'secret' || o.kind === 'light' || FLAT(o)) continue;
    const [x, y] = cellOf(o);
    const k = x + ',' + y;
    const c = at(x, y);
    const name = o.kind === 'prop' ? o.asset : o.kind;
    // a piece pushed against the wall below a floor row (its foot at most 0.6 cell in) stands at that wall
    const atWall = o.kind === 'prop' && c === '0' && at(x, y - 1) !== '0' && o.y - y * C <= 0.6 * C;
    if (c === '0' && !ON_WALL.has(o.kind) && !gateCells.has(k) && !atWall) out.push(`${name} bei ${k} steht in der Wand`);
    if (c === '4' && o.kind !== 'launch' && !(o.kind === 'prop' && o.block === false)) out.push(`${name} bei ${k} steht über einer Grube`);
    if (!spots.has(k)) spots.set(k, []);
    spots.get(k).push(name);
    if (o.kind === 'chest' || o.kind === 'tablet' || o.kind === 'brazier' || (o.kind === 'prop' && o.block)) solid.add(k);
  }
  // the hero's start is only a mark for trying the room alone; a shop's counter carries its trader
  for (const [k, all] of spots) {
    const list = all.filter((n) => n !== 'start' || all.some((m) => ['launch', 'plate', 'chest', 'tablet'].includes(m)));
    if (list.length === 2 && list.includes('shop_table') && list.includes('raw')) continue;
    if (list.length > 1) out.push(`${list.join(' + ')} liegen aufeinander bei ${k}`);
  }
  // doorways: the first open cells inside each port must stay free of solid pieces
  for (const p of room.ports || []) {
    const [x, y] = p.cell;
    const along = ['east', 'west'].includes(p.side) ? [[x, y], [x, y + 1]] : [[x, y], [x + 1, y]];
    const inward = { north: [0, 1], south: [0, -1], west: [1, 0], east: [-1, 0] }[p.side];
    for (const [ax, ay] of along) for (let s = 0; s <= 3; s++) {
      const c = [ax + inward[0] * s, ay + inward[1] * s];
      if (at(...c) === '0') continue;
      if (solid.has(c.join(','))) out.push(`Tür ${p.side} ${p.cell}: ${spots.get(c.join(',')).join(' + ')} versperrt den Eingang bei ${c}`);
      break;
    }
  }
  // a chest, lever, stone or fire bowl needs a cell beside it to stand on
  for (const o of room.objects) {
    if (!NEEDS_ROOM.has(o.kind)) continue;
    const [x, y] = cellOf(o);
    const free = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
      const c = at(x + dx, y + dy);
      return c !== '0' && c !== '4' && !solid.has((x + dx) + ',' + (y + dy));
    });
    if (!free) out.push(`${o.kind} bei ${x},${y} hat kein freies Feld daneben`);
  }
  if (!['boss'].includes(room.role)) {
    const a = areas(room);
    if (!a.one) out.push(`Türen nicht frei verbunden: ${a.doors.map((d) => `${d.port}=${d.area === undefined ? '-' : d.area}`).join(' ')}`);
  }
  return out;
}

module.exports = { audit };

if (require.main === module) {
  let bad = 0;
  for (const f of fs.readdirSync(DIR).filter((f) => f.endsWith('.json')).sort()) {
    const room = JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8'));
    if (!room.in_floors) continue;
    const found = audit(room);
    if (found.length) { bad++; console.log(`${f}:`); for (const s of found) console.log('   ' + s); }
    else if (process.argv.includes('--all')) console.log(`${f}: in Ordnung`);
  }
  console.log(bad ? `${bad} Räume mit Befunden` : 'Alle Räume in Ordnung');
  process.exit(bad ? 1 : 0);
}

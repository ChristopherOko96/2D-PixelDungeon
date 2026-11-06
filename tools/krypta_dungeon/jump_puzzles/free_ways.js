// Shows a room's free walking areas (no throws, no Moder, no plates, nothing solved) as letters on its
// map, and which door belongs to which area. One area holding every door means the puzzle is optional.
//   node tools/krypta_dungeon/jump_puzzles/free_ways.js assets/data/world_rooms/krypta/<id>.json
'use strict';
const fs = require('fs');
const { prepare } = require('./solver');
function areas(room) {
  const P = prepare(room);
  const s0 = { solved: [], on: [], next: {}, keys: [], unlocked: [], lit: [], taken: [] };
  const solver = require('./solver');
  const kind = solver.cellKind;
  const comp = new Map();
  let n = 0;
  const ck = (x, y) => x + ',' + y;
  const free = (x, y) => kind(P, s0, x, y) === 'walk' && !P.plateAt.has(P.key(x, y));
  for (let y = 0; y < P.H; y++) for (let x = 0; x < P.W; x++) {
    if (comp.has(ck(x, y)) || !free(x, y)) continue;
    const id = n++;
    const todo = [[x, y]];
    comp.set(ck(x, y), id);
    while (todo.length) {
      const [cx, cy] = todo.pop();
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const a = cx + dx, b = cy + dy;
        if (comp.has(ck(a, b)) || !free(a, b)) continue;
        comp.set(ck(a, b), id);
        todo.push([a, b]);
      }
    }
  }
  const doors = P.portCells.map((pc) => ({ port: `${pc.port.side} ${pc.port.cell}`, area: pc.cells.map((c) => comp.get(ck(...c))).find((v) => v !== undefined) }));
  const map = [];
  for (let y = 0; y < P.H; y++) {
    let row = '';
    for (let x = 0; x < P.W; x++) {
      const c = comp.get(ck(x, y));
      row += c === undefined ? ({ 0: '#', 1: ',', 2: '~', 3: '=', 4: 'o' })[P.at(x, y)] : String.fromCharCode(65 + (c % 26));
    }
    map.push(String(y).padStart(2) + ' ' + row);
  }
  const set = new Set(doors.map((d) => d.area));
  return { doors, map, one: set.size === 1 && !set.has(undefined) };
}
module.exports = { areas };
if (require.main === module) {
  for (const f of process.argv.slice(2)) {
    const r = areas(JSON.parse(fs.readFileSync(f, 'utf8')));
    console.log(f.split(/[\/]/).pop(), r.one ? 'alle Türen frei verbunden' : 'NICHT frei verbunden');
    console.log(r.doors.map((d) => `${d.port}=${d.area === undefined ? '-' : String.fromCharCode(65 + d.area % 26)}`).join('  '));
    if (process.argv.includes('--map') || !r.one) console.log(r.map.join('\n'));
  }
}

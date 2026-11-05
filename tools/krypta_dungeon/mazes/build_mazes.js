// Builds the Krypta's labyrinth rooms (assets/data/world_rooms/krypta/k_labyrinth_*.json) as real mazes.
//
// A walkway along the room's outer edges joins every door, so a hero may pass by. Two gaps in its inner
// wall lead into the maze, each with an Inschrift that tells the choice. Inside: one-cell corridors over
// the whole rest of the room, grown so that many short ways end blind, a few small chambers, and in the
// middle the treasure chamber. Bones and skulls lie everywhere; the dead ends hold vases, crates and
// chests, many with one of the floor's own monsters hidden inside (it comes out in that very corridor).
// The maze part is the room's "maze_zone": inside it the game turns dark and the view closes in
// (hell_game.gd maze darkness), and the map shows it as one block.
//
//   node tools/krypta_dungeon/mazes/build_mazes.js                  (check every maze, write nothing)
//   node tools/krypta_dungeon/mazes/build_mazes.js k_labyrinth_la --write
//
// It writes only the rooms named, and only with --write: once written, a room is the user's to change in
// the Weltbauer, and running this again over it overwrites those changes.

'use strict';
const fs = require('fs');
const path = require('path');
const { decorate, prop, rng } = require('../jump_puzzles/build');
const solver = require('../jump_puzzles/solver');

const ROOT = path.resolve(__dirname, '../../..');
const DIR = path.join(ROOT, 'assets/data/world_rooms/krypta');
const C = 96;
const PITCH = [17, 14];
const SLOT = [14, 11];

const TEXT = 'Vor dir liegt der Irrgarten der Verlorenen.\n'
  + 'Geh außen herum und lass ihn hinter dir, oder tritt ein.\n'
  + 'Drinnen wird es dunkel, und viele Gänge enden blind.\n'
  + 'Zerschlage nicht jede Vase, öffne nicht jede Truhe:\n'
  + 'Manches darin wartet nur auf dich.\n'
  + 'Im Herzen des Irrgartens liegt ein Schatz, der jeden Schritt lohnt.';

// per maze: title, the walkway (lines of cells: ['row', y, x0, x1] or ['col', x, y0, y1]), the doors on it,
// where the two ways in are (cells of the walkway they open from, and the way inward), and the chambers
const MAZES = {
  k_labyrinth_la: {
    title: 'Labyrinth: Knochenirrgarten (Winkel)', chambers: 4, hidden: 12,
    walk: [['row', 1, 1, 29], ['col', 1, 1, 23], ['col', 29, 1, 6], ['row', 23, 1, 7]],
    ports: [['north', 6, 0], ['north', 23, 0], ['west', 0, 5], ['west', 0, 19], ['east', 30, 5], ['south', 6, 24]],
    gates: [[[15, 1], [0, 1]], [[1, 15], [1, 0]]],
  },
  k_labyrinth_la_gs: {
    title: 'Labyrinth: Gruft der Verirrten (Winkel)', chambers: 4, hidden: 12,
    walk: [['row', 1, 1, 29], ['col', 29, 1, 23], ['col', 1, 1, 6], ['row', 23, 23, 29]],
    ports: [['north', 6, 0], ['north', 23, 0], ['east', 30, 5], ['east', 30, 19], ['west', 0, 5], ['south', 23, 24]],
    gates: [[[15, 1], [0, 1]], [[29, 15], [-1, 0]]],
  },
  k_labyrinth_lc: {
    title: 'Labyrinth: Totengassen (Winkel)', chambers: 4, hidden: 12,
    walk: [['col', 1, 1, 23], ['row', 23, 1, 29], ['row', 1, 1, 7], ['col', 29, 18, 23]],
    ports: [['west', 0, 5], ['west', 0, 19], ['south', 6, 24], ['south', 23, 24], ['north', 6, 0], ['east', 30, 19]],
    gates: [[[1, 9], [1, 0]], [[15, 23], [0, -1]]],
  },
  k_labyrinth_lc_gs: {
    title: 'Labyrinth: Modergänge (Winkel)', chambers: 4, hidden: 12,
    walk: [['col', 29, 1, 23], ['row', 23, 1, 29], ['row', 1, 23, 29], ['col', 1, 18, 23]],
    ports: [['east', 30, 5], ['east', 30, 19], ['south', 6, 24], ['south', 23, 24], ['north', 23, 0], ['west', 0, 19]],
    gates: [[[29, 9], [-1, 0]], [[15, 23], [0, -1]]],
  },
  k_labyrinth_lang: {
    title: 'Labyrinth: Knochengang (lang)', chambers: 3, hidden: 11,
    walk: [['row', 1, 1, 46], ['col', 1, 1, 6], ['col', 46, 1, 6]],
    ports: [['north', 6, 0], ['north', 23, 0], ['north', 40, 0], ['west', 0, 5], ['east', 47, 5]],
    gates: [[[11, 1], [0, 1]], [[37, 1], [0, 1]]],
  },
  k_labyrinth_turm: {
    title: 'Labyrinth: Schacht der Verirrten (Turm)', chambers: 2, hidden: 10,
    walk: [['col', 1, 1, 37], ['row', 1, 1, 7], ['row', 37, 1, 7]],
    ports: [['west', 0, 5], ['west', 0, 19], ['west', 0, 33], ['north', 6, 0], ['south', 6, 38]],
    gates: [[[1, 11], [1, 0]], [[1, 27], [1, 0]]],
  },
};

const BONES = ['bone_a', 'bone_b', 'bone_c', 'bone_d', 'bone_e', 'bone_f', 'bone_g', 'bones_scatter', 'bones_t', 'skull_pile_t', 'skull_pile_t', 'rubble'];
const STAINS = ['blood_a', 'blood_c', 'moss_a', 'moss_b', 'moss_c', 'grate_a'];

function footprint(slots) {
  const set = new Set();
  const has = (sx, sy) => slots.some(([a, b]) => a === sx && b === sy);
  const fill = (x0, y0, x1, y1) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set.add(x + ',' + y); };
  for (const [sx, sy] of slots) {
    const x0 = sx * PITCH[0], y0 = sy * PITCH[1];
    fill(x0, y0, x0 + SLOT[0] - 1, y0 + SLOT[1] - 1);
    if (has(sx + 1, sy)) fill(x0 + SLOT[0], y0, x0 + PITCH[0] - 1, y0 + SLOT[1] - 1);
    if (has(sx, sy + 1)) fill(x0, y0 + SLOT[1], x0 + SLOT[0] - 1, y0 + PITCH[1] - 1);
  }
  return set;
}

function build(id, old) {
  const cfg = MAZES[id];
  const r = rng(id + ':maze2');
  const W = old.width, H = old.height;
  const foot = footprint(old.slots);
  const key = (x, y) => x + ',' + y;
  const inside = (x, y) => { for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (!foot.has(key(x + dx, y + dy))) return false; return true; };
  const g = Array.from({ length: H }, () => Array(W).fill('#'));
  const open = (x, y) => { g[y][x] = '.'; };
  // 1. the walkway
  const walk = new Set();
  for (const [kind, a, b0, b1] of cfg.walk) for (let b = b0; b <= b1; b++) { const [x, y] = kind === 'row' ? [b, a] : [a, b]; walk.add(key(x, y)); open(x, y); }
  const nearWalk = (x, y) => { for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (walk.has(key(x + dx, y + dy))) return true; return false; };
  // 2. the maze over the nodes off the walkway: grown from random places of its edge, so many short side
  // ways end blind (a perfect maze: one way between any two places)
  const isNode = (x, y) => x % 2 === 1 && y % 2 === 1 && inside(x, y) && !nearWalk(x, y);
  const nodes = [];
  for (let y = 1; y < H; y += 2) for (let x = 1; x < W; x += 2) if (isNode(x, y)) nodes.push([x, y]);
  const cx0 = nodes.reduce((s, n) => s + n[0], 0) / nodes.length, cy0 = nodes.reduce((s, n) => s + n[1], 0) / nodes.length;
  // the heart: the node nearest the middle with room for a 3 x 3 chamber
  const heart = nodes.filter(([x, y]) => [-2, 0, 2].every((d) => isNode(x + d, y) && isNode(x, y + d)))
    .sort((a, b) => Math.hypot(a[0] - cx0, a[1] - cy0) - Math.hypot(b[0] - cx0, b[1] - cy0))[0] || nodes[0];
  const seen = new Set([key(...heart)]);
  const stack = [heart];
  open(...heart);
  while (stack.length) {
    const pick = r() < 0.45 ? stack.length - 1 : Math.floor(r() * stack.length);
    const [x, y] = stack[pick];
    const next = [[2, 0], [-2, 0], [0, 2], [0, -2]].map(([dx, dy]) => [x + dx, y + dy, dx, dy]).filter(([nx, ny]) => isNode(nx, ny) && !seen.has(key(nx, ny)));
    if (!next.length) { stack.splice(pick, 1); continue; }
    const [nx, ny, dx, dy] = next[Math.floor(r() * next.length)];
    open(x + dx / 2, y + dy / 2);
    open(nx, ny);
    seen.add(key(nx, ny));
    stack.push([nx, ny]);
  }
  const lone = nodes.filter((n) => !seen.has(key(...n)));
  if (lone.length) throw new Error(`${id}: ${lone.length} Knoten ohne Weg`);
  // 3. the treasure chamber in the heart and a few small chambers where a fight has room
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) open(heart[0] + dx, heart[1] + dy);
  const chambers = [];
  for (let tries = 0; chambers.length < cfg.chambers && tries < 500; tries++) {
    const [cx, cy] = nodes[Math.floor(r() * nodes.length)];
    const fits = [-1, 0, 1].every((dy) => [-1, 0, 1].every((dx) => inside(cx + dx, cy + dy) && !nearWalk(cx + dx, cy + dy)));
    if (!fits || Math.abs(cx - heart[0]) + Math.abs(cy - heart[1]) < 8 || chambers.some(([ax, ay]) => Math.abs(ax - cx) + Math.abs(ay - cy) < 8)) continue;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) open(cx + dx, cy + dy);
    chambers.push([cx, cy]);
  }
  // 4. the two ways in, where the way to the heart is longest: a gap through the walkway's inner wall
  // onto a corridor, a niche beside each for the Inschrift
  const far = new Map([[key(...heart), 0]]);
  const q0 = [heart];
  while (q0.length) {
    const [x, y] = q0.shift();
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (g[ny] && g[ny][nx] === '.' && !walk.has(key(nx, ny)) && !far.has(key(nx, ny))) { far.set(key(nx, ny), far.get(key(x, y)) + 1); q0.push([nx, ny]); }
    }
  }
  const gaps = [];
  for (const k of walk) {
    const [wx, wy] = k.split(',').map(Number);
    for (const [ix, iy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const wall = [wx + ix, wy + iy], room = [wx + 2 * ix, wy + 2 * iy];
      if (!g[room[1]] || g[wall[1]][wall[0]] !== '#' || g[room[1]][room[0]] !== '.' || walk.has(key(...room)) || !far.has(key(...room))) continue;
      const side = ix === 0 ? [1, 0] : [0, 1];
      const niche = [wall[0] + side[0], wall[1] + side[1]];
      if (g[niche[1]][niche[0]] !== '#' || !walk.has(key(niche[0] - ix, niche[1] - iy))) continue;
      gaps.push({ wall, niche, d: far.get(key(...room)) });
    }
  }
  gaps.sort((p, q) => q.d - p.d);
  const chosen = [];
  for (const gp of gaps) if (chosen.length < 2 && chosen.every((c) => Math.abs(c.wall[0] - gp.wall[0]) + Math.abs(c.wall[1] - gp.wall[1]) >= 12)) chosen.push(gp);
  if (chosen.length < 2) throw new Error(id + ': keine zwei Eingänge gefunden');
  const entries = chosen.map((c) => c.wall);
  const niches = chosen.map((c) => c.niche);
  for (const c of entries) open(...c);
  // 5. the doors stay on the walkway
  const doorCells = [];
  for (const [side, x, y] of cfg.ports) {
    const cells = { west: [[1, y], [1, y + 1]], east: [[W - 2, y], [W - 2, y + 1]], north: [[x, 1], [x + 1, 1]], south: [[x, H - 2], [x + 1, H - 2]] }[side];
    for (const [px, py] of cells) { if (!walk.has(key(px, py))) throw new Error(`${id}: Tür ${side} ${x},${y} liegt nicht am Rundgang (${px},${py})`); doorCells.push([px, py]); }
  }
  // 6. ways from the heart: distance of every maze cell, the dead ends
  const dist = new Map([[key(...heart), 0]]);
  const queue = [heart];
  while (queue.length) {
    const [x, y] = queue.shift();
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (g[ny] && g[ny][nx] === '.' && !walk.has(key(nx, ny)) && !dist.has(key(nx, ny))) { dist.set(key(nx, ny), dist.get(key(x, y)) + 1); queue.push([nx, ny]); }
    }
  }
  const mazeCells = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (g[y][x] === '.' && !walk.has(key(x, y))) mazeCells.push([x, y]);
  const ways = (x, y) => [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([dx, dy]) => g[y + dy] && g[y + dy][x + dx] === '.').length;
  const isEntry = (x, y) => entries.some(([a, b]) => Math.abs(a - x) + Math.abs(b - y) <= 2);
  const deadEnds = mazeCells.filter(([x, y]) => ways(x, y) === 1 && !isEntry(x, y));
  // 7. what lies in the maze
  const objects = [];
  const used = new Set();
  const flat = (asset, x, y, s = {}) => prop(asset, x, y, { flat: true, block: false, dx: Math.round((r() - 0.5) * 50), dy: Math.round((r() - 0.5) * 40), flip: r() < 0.5, ...s });
  const [hx, hy] = heart;
  const chest = (x, y, loot, extra = {}) => ({ kind: 'chest', loot: { type: loot }, x: (x + 0.5) * C, y: (y + 0.75) * C, ...extra });
  objects.push(chest(hx, hy - 1, 'hoard'));
  objects.push(chest(hx - 1, hy - 1, 'random', { mimic: 'no' }), chest(hx + 1, hy - 1, 'random', { mimic: 'no' }));
  objects.push({ kind: 'heart', x: (hx + 0.5) * C, y: (hy + 1.5) * C });
  for (const [dx, dy] of [[-1, 1], [1, 1]]) objects.push(prop('brazier_pillar', hx + dx, hy + dy));
  objects.push(prop('rune_big', hx, hy, { flat: true, block: false, decal: { dy: 45, w: 0, h: 0, a: 0.9 } }));
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) used.add(key(hx + dx, hy + dy));
  let hidden = 0;
  const soft = [];
  for (const [x, y] of deadEnds) {
    if (used.has(key(x, y))) continue;
    const v = r();
    used.add(key(x, y));
    if (v < 0.38) { const m = r() < 0.75; hidden += m ? 1 : 0; objects.push(prop(r() < 0.5 ? 'urn_a' : 'urn_b', x, y, { loot: { type: 'random' }, ...(m ? { enemies: ['random'] } : {}) })); }
    else if (v < 0.54) { hidden += 2; objects.push(prop('crate_a', x, y, { loot: { type: 'random' }, enemies: ['random', 'random'] })); }
    else if (v < 0.66) { const m = r() < 0.5; hidden += m ? 1 : 0; objects.push(chest(x, y, 'random', { mimic: 'random', mimic_mob: r() < 0.5 ? 'mimik' : 'truhenfresser', ...(m ? { enemies: ['random'] } : {}) })); }
    else if (v < 0.78) { soft.push([objects.length, x, y]); objects.push(prop(r() < 0.5 ? 'skull_pile' : 'coal_skulls', x, y, { flip: r() < 0.5 })); }
    else if (v < 0.82) { soft.push([objects.length, x, y]); objects.push({ kind: 'gem', x: (x + 0.5) * C, y: (y + 0.5) * C }); }
    else { soft.push([objects.length, x, y]); objects.push(prop('bones_scatter', x, y, { flat: true, block: false })); }
  }
  // never too few: quiet dead ends become vases with one of the dead inside until the maze holds its share
  while (hidden < cfg.hidden && soft.length) {
    const [i, x, y] = soft.splice(Math.floor(r() * soft.length), 1)[0];
    objects[i] = prop(r() < 0.5 ? 'urn_a' : 'urn_b', x, y, { loot: { type: 'random' }, enemies: ['random'] });
    hidden += 1;
  }
  // vases along the corridors too, against walls where they block no way (a cell with one wall gap)
  for (const [x, y] of mazeCells) {
    if (used.has(key(x, y)) || ways(x, y) !== 2 || r() > 0.06) continue;
    const straight = (g[y][x - 1] === '.' && g[y][x + 1] === '.') || (g[y - 1] && g[y - 1][x] === '.' && g[y + 1] && g[y + 1][x] === '.');
    if (straight) continue;
    // a corner cell: a piece in it would close the way, so it only gets bones
    used.add(key(x, y));
    objects.push(flat('skull_pile_t', x, y));
  }
  for (const [cx, cy] of chambers) {
    for (const [dx, dy] of [[-1, -1], [1, 1]]) {
      if (used.has(key(cx + dx, cy + dy)) || ways(cx + dx, cy + dy) > 2) continue;
      objects.push(prop(r() < 0.5 ? 'urn_b' : 'crate_a', cx + dx, cy + dy, { loot: { type: 'random' }, ...(r() < 0.6 ? { enemies: ['random'] } : {}) }));
      used.add(key(cx + dx, cy + dy));
    }
  }
  for (const [x, y] of mazeCells) {
    if (used.has(key(x, y))) continue;
    if (r() < 0.45) objects.push(flat(BONES[Math.floor(r() * BONES.length)], x, y));
    if (r() < 0.18) objects.push(flat(BONES[Math.floor(r() * BONES.length)], x, y));
    if (r() < 0.12) objects.push(prop(STAINS[Math.floor(r() * STAINS.length)], x, y, { flat: true, block: false, decal: { dy: 45, w: 0, h: 0, a: 0.9 } }));
  }
  // the walkway: a few bones, the Inschrift in its niche at each way in
  for (const k of walk) { const [x, y] = k.split(',').map(Number); if (r() < 0.12) objects.push(flat(BONES[Math.floor(r() * BONES.length)], x, y)); }
  for (const [nx, ny] of niches) { open(nx, ny); objects.push({ kind: 'tablet', text: TEXT, x: (nx + 0.5) * C, y: (ny + 0.75) * C }); }
  const [sx, sy] = doorCells[0];
  objects.push({ kind: 'start', x: (sx + 0.5) * C, y: (sy + 0.75) * C });
  // 8. the maze zone (dark, closed on the map): every cell off the walkway, as row runs
  const zone = [];
  for (let y = 0; y < H; y++) {
    let x0 = -1;
    for (let x = 0; x <= W; x++) {
      const inZone = x < W && foot.has(key(x, y)) && !walk.has(key(x, y)) && !niches.some(([a, b]) => a === x && b === y) && x > 0 && y > 0 && x < W - 1 && y < H - 1 && !nearWalk(x, y);
      if (inZone && x0 < 0) x0 = x;
      if (!inZone && x0 >= 0) { zone.push([x0, y, x - 1, y]); x0 = -1; }
    }
  }
  const cells = g.map((row) => row.map((c) => (c === '.' ? '1' : '0')).join(''));
  const ports = cfg.ports.map(([side, x, y]) => ({ side, cell: [x, y] }));
  const plan = { file: id, ports: cfg.ports, bare: () => false };
  const walls = decorate(plan, cells, new Set(), objects).filter((o) => o.wall_decor);
  return {
    room: { schema_version: 1, id, title: cfg.title, world: 'krypta', role: 'jump', in_floors: true, slots: old.slots, width: W, height: H,
      cells, tiles: {}, areas: {}, ports, auto_mobs: 0, maze: true, maze_zone: zone, objects: [...walls, ...objects], kind_label: 'Labyrinth', spawn_mode: 'manual' },
    stats: { cells: mazeCells.length, deadEnds: deadEnds.length, chambers: chambers.length, hidden, heart: chosen.map((c) => c.d + 1), longest: 0 },
  };
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const write = args.includes('--write');
  const names = args.filter((a) => !a.startsWith('--'));
  let bad = 0;
  for (const id of Object.keys(MAZES)) {
    if (names.length && !names.includes(id)) continue;
    const file = path.join(DIR, id + '.json');
    const old = JSON.parse(fs.readFileSync(file, 'utf8'));
    const { room, stats } = build(id, old);
    const report = solver.analyze(room);
    console.log(`== ${id} (${room.title}): ${stats.cells} Gangfelder, ${stats.deadEnds} Sackgassen, ${stats.chambers} Kammern, ${stats.hidden} versteckte Gegner, Weg vom Eingang zur Mitte ${stats.heart.join(' / ')} Felder; Türen frei verbunden: ${report.ports.every((p) => p.linked) ? 'ja' : 'NEIN'}`);
    for (const p of report.problems) console.log('PROBLEM: ' + p);
    bad += report.problems.length;
    if (args.includes('--map')) console.log(room.cells.map((row, i) => String(i).padStart(2) + ' ' + row.replace(/0/g, '#').replace(/1/g, '.')).join('\n'));
    if (write && names.includes(id)) {
      fs.copyFileSync(file, file + '.bak');
      fs.writeFileSync(file, JSON.stringify(room, null, '\t') + '\n');
      console.log('geschrieben: ' + path.relative(ROOT, file));
    }
  }
  process.exit(bad ? 1 : 0);
}

module.exports = { build, MAZES };

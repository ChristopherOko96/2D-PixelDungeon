// The Frostgruft's puzzle rooms (role "jump": big rooms without a fight). Each has a hall the floor's doors
// open into, joined by a free way (every puzzle stays optional), an inscription on a pillar and a rune at
// the entrance of the puzzle, the puzzle itself and its treasure behind a gate or a crevasse. Candidates are
// drawn from a seed and kept only when the solver (../puzzles/solvers.js) finds them solvable and hard
// enough; the way it found is kept as the room's steps for the replay in the real game.
'use strict';
const S = require('../puzzles/solvers.js');
const R = require('./room.js');
const { Room, WALL, FLOOR, LIQUID, BRIDGE, PIT, C } = R;

// ---------- the frames: hall, entrance, puzzle zone ----------

/** An angled room: the hall in the arm of the doors, the puzzle in the other arm (16 x 9). */
function angled(id, title, shape, kind) {
  const b = new Room(`f_${id}_${shape}`, title, 'jump', shape);
  b.extra = { kind_label: kind };
  const tall = shape === 'lc';
  // the hall: the left arm, 12 wide
  b.rect(1, 1, 12, 23, FLOOR);
  const zy = tall ? 15 : 1;
  const zone = { x: 14, y: zy, w: 16, h: 9 };
  b.rect(zone.x, zone.y, zone.w, zone.h, FLOOR);
  const ey = zy + 4;
  b.set(13, ey, FLOOR);
  b.port('north', 5, 0);
  b.port('west', 0, tall ? 4 : 13);
  b.port('south', 5, 24);
  return { b, zone, entry: [14, ey], door: [13, ey], hall: { x: 1, y: 1, w: 12, h: 23 } };
}

/** A long room: the hall along the top (2 rows), the puzzle below it (46 x 6). */
function long(id, title, kind) {
  const b = new Room(`f_${id}_b3`, title, 'jump', 'b3');
  b.extra = { kind_label: kind };
  b.rect(1, 1, 46, 2, FLOOR);
  b.port('west', 0, 1);
  b.port('east', 47, 1);
  b.port('north', 23, 0);
  return { b, zone: { x: 1, y: 4, w: 46, h: 6 }, hall: { x: 1, y: 1, w: 46, h: 2 } };
}

/** A tower: the hall along the left (2 wide), the puzzle right of it (9 x 37). */
function tower(id, title, kind) {
  const b = new Room(`f_${id}_h3`, title, 'jump', 'h3');
  b.extra = { kind_label: kind };
  b.rect(1, 1, 2, 37, FLOOR);
  b.port('north', 1, 0);
  b.port('south', 1, 38);
  b.port('west', 0, 18);
  return { b, zone: { x: 4, y: 1, w: 9, h: 37 }, hall: { x: 1, y: 1, w: 2, h: 37 } };
}

/** The cells of a rect as keys. */
function cellsOf(z) { const s = new Set(); for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) s.add(S.key(x, y)); return s; }

/** Dresses the hall: snow, pillars, wall pictures, kept off `zone`. */
function dressHall(b, zone, theme) {
  b.wallDress(R.WALLS[theme || 'ice'], gatesOf(b));
  b.snow(0.05, zone);
  b.scatter(theme || 'ice', zone, 3.6);
  b.start();
}

function gatesOf(b) { return b.objects.filter(o => o.kind === 'gate').map(o => [o.x / C + 1, o.y / C + 1]); }

/** The grid of a room for the solvers: '#' where nothing passes. */
function gridOf(b, keepSolid = true) {
  const g = new S.Grid(b.w, b.h);
  const solid = keepSolid ? R.solidAt(b) : new Set();
  for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
    const c = b.at(x, y);
    g.set(x, y, c === WALL || solid.has(S.key(x, y)) ? '#' : c === PIT ? 'o' : '.');
  }
  return g;
}

/** A chest nook behind a gate: floor `nook`, the gate over cells (gx, gy) in a wall, the Schatz in it. */
function nook(b, n, gate, tier, chestAt) {
  b.rect(n.x, n.y, n.w, n.h, FLOOR);
  b.gate(gate[0], gate[1], gate[2], 'A', { style: 'portcullis' });
  b.hoard(chestAt[0], chestAt[1], tier);
}

/** A rock or spire that fills its whole cell in a puzzle: nobody stands in it, as the solver thinks. */
function rock(b, ch, x, y) { b.prop(R.GLYPH[ch][0], x + 0.5, y + 1 - 4 / C, [80, 88], { flip: b.rnd() < 0.5 }); }

const shuffle = (a, rnd) => { for (let k = a.length - 1; k > 0; k--) { const j = Math.floor(rnd() * (k + 1)); [a[k], a[j]] = [a[j], a[k]]; } return a; };

// ---------- Eisblöcke ----------

/** Blocks slide over f.play; the crevasse cells f.band keep the treasure (f.goal) apart. */
function blocks(f, seed, want) {
  const { b } = f;
  const rnd = S.random(seed);
  const z = f.play;
  for (let tries = 0; tries < 5000; tries++) {
    const g = gridOf(b, false);
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) g.set(x, y, '.');
    for (const c of f.band) g.set(c[0], c[1], 'o');
    for (const c of f.beyond) g.set(c[0], c[1], '.');
    const free = [];
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) if (Math.abs(x - f.entry[0]) + Math.abs(y - f.entry[1]) > 1) free.push([x, y]);
    shuffle(free, rnd);
    const [lo, spread] = want.rocks || [0.12, 0.08];
    const rocks = free.slice(0, Math.floor(free.length * (lo + rnd() * spread)));
    for (const [x, y] of rocks) g.set(x, y, '#');
    const bl = free.slice(rocks.length, rocks.length + want.blocks).map(c => c.slice());
    const res = S.solveBlocks(g, bl, f.entry, f.goal, 150000);
    // the solver's way is the shortest: between min and most pushes
    if (!res || res.length < want.min || (want.most && res.length > want.most)) continue;
    for (const c of f.band) b.set(c[0], c[1], PIT);
    for (const [x, y] of rocks) rock(b, ['X', 'k', 'R', 'h'][Math.floor(rnd() * 4)], x, y);
    for (const [x, y] of bl) b.piece('ice_block', x, y);
    b.hoard(f.chest[0], f.chest[1], res.length >= want.hard ? 3 : 2);
    return { pushes: res.pushes, length: res.length };
  }
  throw new Error(b.id + ': no block puzzle found');
}

// ---------- Schneeball ----------

/** Snowballs grow on deep snow; two crevasse cells in a tunnel need two big balls. */
function balls(f, seed, want) {
  const { b, zone, vertical } = f;
  const rnd = S.random(seed);
  for (let tries = 0; tries < 6000; tries++) {
    const g = gridOf(b, false);
    const z = f.play;
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) g.set(x, y, '.');
    // the tunnel with its crevasse cells and the treasure behind
    for (const c of f.pits) g.set(c[0], c[1], 'o');
    for (const c of f.beyond) g.set(c[0], c[1], '.');
    const free = [];
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) if (!(x === f.entry[0] && y === f.entry[1])) free.push([x, y]);
    shuffle(free, rnd);
    let k = 0;
    const rocks = free.slice(k, k += Math.floor(free.length * (0.10 + rnd() * 0.08)));
    const snow = free.slice(k, k += want.snow);
    const bl = free.slice(k, k += want.balls).map(c => [c[0], c[1], 1]);
    for (const [x, y] of rocks) g.set(x, y, '#');
    for (const [x, y] of snow) g.set(x, y, '*');
    const res = S.solveBalls(g, bl, f.entry, f.goal, { most: 250000 });
    if (!res || res.length < want.min) continue;
    for (const c of f.pits) b.set(c[0], c[1], PIT);
    for (const [x, y] of rocks) rock(b, ['X', 'k', 'g', 'h'][Math.floor(rnd() * 4)], x, y);
    for (const [x, y] of snow) b.piece('deep_snow', x, y);
    for (const [x, y] of bl) b.piece('snowball', x, y, { size: 1 });
    return { pushes: res.pushes, length: res.length };
  }
  throw new Error(b.id + ': no snowball puzzle found');
}

// ---------- Glut tragen ----------

/** Cold bowls round the zone, walls between, cold fog: only relays bring the ember far enough. */
function ember(f, seed, want) {
  const { b, zone } = f;
  const rnd = S.random(seed);
  for (let tries = 0; tries < 6000; tries++) {
    const g = gridOf(b, false);
    for (let y = zone.y; y < zone.y + zone.h; y++) for (let x = zone.x; x < zone.x + zone.w; x++) g.set(x, y, '.');
    for (const c of f.blocked || []) g.set(c[0], c[1], '#');
    // inner walls: straight runs with a gap
    const walls = [];
    for (let k = 0; k < want.walls; k++) {
      const across = rnd() < 0.5;
      const len = 3 + Math.floor(rnd() * (across ? zone.w - 3 : zone.h - 3));
      const x0 = zone.x + 1 + Math.floor(rnd() * (zone.w - 2)), y0 = zone.y + 1 + Math.floor(rnd() * (zone.h - 2));
      for (let i = 0; i < len; i++) { const x = across ? x0 + i : x0, y = across ? y0 : y0 + i; if (x < zone.x + zone.w && y < zone.y + zone.h) walls.push([x, y]); }
    }
    for (const [x, y] of walls) if (!(x === f.entry[0] && y === f.entry[1])) g.set(x, y, '#');
    const free = [];
    for (let y = zone.y; y < zone.y + zone.h; y++) for (let x = zone.x; x < zone.x + zone.w; x++) if (g.at(x, y) === '.' && Math.hypot(x - f.entry[0], y - f.entry[1]) > 1.5) free.push([x, y]);
    if (free.length < 30) continue;
    shuffle(free, rnd);
    const source = f.source || free.pop();
    const bowls = [];
    for (const c of free) { if (bowls.length >= want.bowls) break; if (bowls.every(o => Math.abs(o[0] - c[0]) + Math.abs(o[1] - c[1]) > 4) && Math.abs(c[0] - source[0]) + Math.abs(c[1] - source[1]) > 6) bowls.push(c); }
    if (bowls.length < want.bowls) continue;
    const fogs = [];
    for (const c of free) if (fogs.length < want.fog && !bowls.some(o => o[0] === c[0] && o[1] === c[1]) && rnd() < 0.5) {
      for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) if (g.at(c[0] + dx, c[1] + dy) === '.') { g.set(c[0] + dx, c[1] + dy, 'f'); fogs.push([c[0] + dx, c[1] + dy]); }
    }
    // the hero must reach every bowl's side from the entrance
    const solid = new Set([S.key(source[0], source[1]), ...bowls.map(o => S.key(o[0], o[1]))]);
    const open = S.reach(f.entry, (x, y) => g.at(x, y) !== '#' && !solid.has(S.key(x, y)));
    if (![source, ...bowls].every(o => S.D4.some(([dx, dy]) => open.has(S.key(o[0] + dx, o[1] + dy))))) continue;
    const res = S.solveEmber(g, source, bowls, want.steps, want.fogCost);
    if (!res || res.depth < want.depth) continue;
    // not one bowl may be reached straight from the hearth when the rule says they need relays
    const direct = bowls.filter(o => S.emberCost(g, source, o, solid, want.fogCost) <= want.steps).length;
    if (direct > want.direct) continue;
    const legs = emberLegs(g, source, bowls, res, solid, want, f.entry);
    if (!legs) continue;
    for (const [x, y] of walls) if (g.at(x, y) === '#') b.set(x, y, WALL);
    for (const [x, y] of fogs) b.piece('cold_fog', x, y);
    b.piece('ember_source', source[0], source[1]);
    for (const [x, y] of bowls) b.thing('brazier', x + 0.5, y + 0.75, { group: 'A', cold: true });
    return { source, bowls, legs, order: res.order, depth: res.depth };
  }
  throw new Error(b.id + ': no ember puzzle found');
}

/**
 * The legs of the ember's way as the game plays them (frost_puzzles.gd interactables): each leg starts on a
 * cell where the thing to take ember from is the nearest piece to use, and ends on a cell where its bowl is
 * the nearest (carrying, lit bowls and the hearth offer nothing). [{path, cost}] or null.
 */
function emberLegs(g, source, bowls, res, solid, want, entry) {
  const me = c => [c[0] * C + 48, c[1] * C + 38];
  const bowlAt = c => [c[0] * C + 48, c[1] * C + 42];
  const hearthAt = c => [c[0] * C + 48, c[1] * C + 58];
  const dist = (a, q) => Math.hypot(a[0] - q[0], a[1] - q[1]);
  const ok = (x, y) => g.at(x, y) !== '#' && !solid.has(S.key(x, y));
  const around = c => S.D4.map(([dx, dy]) => [c[0] + dx, c[1] + dy]).filter(n => ok(n[0], n[1]));
  const lit = new Set();
  // the cell beside `at` (a piece at point `p`, reach r) where it is nearer than every one of `rivals` ([point, reach])
  const spot = (at, p, r, rivals) => around(at).filter(c => {
    const d = dist(me(c), p);
    return d < r && rivals.every(([q, rr]) => dist(me(c), q) >= rr || dist(me(c), q) > d + 10);
  });
  const out = [];
  let from = source;
  for (let i = 0; i < res.order.length; i++) {
    const bi = res.order[i];
    const leg = res.legs[i];
    const fromBowl = leg.from === 'source' ? -1 : leg.from;
    const fromAt = fromBowl < 0 ? source : bowls[fromBowl];
    // taking: the hearth and lit bowls offer ember, unlit bowls their note; all are rivals but the giver
    const rivalsTake = [[hearthAt(source), 120], ...bowls.map(o => [bowlAt(o), 150])].filter(([q]) => !(q[0] === (fromBowl < 0 ? hearthAt(source) : bowlAt(fromAt))[0] && q[1] === (fromBowl < 0 ? hearthAt(source) : bowlAt(fromAt))[1]));
    const starts = spot(fromAt, fromBowl < 0 ? hearthAt(source) : bowlAt(fromAt), fromBowl < 0 ? 120 : 150, rivalsTake);
    // laying: only the unlit bowls offer anything
    const rivalsLay = bowls.filter((o, k) => k !== bi && !lit.has(k)).map(o => [bowlAt(o), 150]);
    const ends = spot(bowls[bi], bowlAt(bowls[bi]), 150, rivalsLay);
    let best = null;
    for (const s of starts) for (const e of ends) {
      const path = cheapest(g, s, e, ok, want.fogCost);
      if (path && path.cost <= want.steps && (!best || path.cost < best.cost)) best = path;
    }
    if (!best) return null;
    out.push({ from: leg.from, to: bi, cost: best.cost, path: best.cells });
    lit.add(bi);
    from = bowls[bi];
  }
  return out;
}

/** The cheapest walk from a to b (fog costs fogCost): {cells, cost} or null. */
function cheapest(g, a, b, ok, fogCost) {
  const best = new Map([[S.key(a[0], a[1]), { cost: 0, prev: null }]]);
  const todo = [[0, a]];
  while (todo.length) {
    todo.sort((p, q) => p[0] - q[0]);
    const [c, at] = todo.shift();
    if (at[0] === b[0] && at[1] === b[1]) {
      const cells = [];
      let k = S.key(at[0], at[1]);
      let cur = at;
      while (cur) { cells.unshift(cur); const e = best.get(S.key(cur[0], cur[1])); cur = e.prev; }
      return { cells, cost: c };
    }
    if (best.get(S.key(at[0], at[1])).cost < c) continue;
    for (const [dx, dy] of S.D4) {
      const n = [at[0] + dx, at[1] + dy];
      if (!ok(n[0], n[1])) continue;
      const nc = c + (g.at(n[0], n[1]) === 'f' ? fogCost : 1);
      const k = S.key(n[0], n[1]);
      if (!best.has(k) || best.get(k).cost > nc) { best.set(k, { cost: nc, prev: at }); todo.push([nc, n]); }
    }
  }
  return null;
}

// ---------- Lichtprismen ----------

/** Aurora light over prisms: the light's way is laid first (turns.min..max prisms), decoys go round it;
 * kept when only that one way of the light lights the seal. */
function prisms(f, seed, want) {
  const { b, zone } = f;
  const rnd = S.random(seed);
  const inZone = (x, y) => x >= zone.x && y >= zone.y && x < zone.x + zone.w && y < zone.y + zone.h && !(f.blocked || []).some(c => c[0] === x && c[1] === y);
  for (let tries = 0; tries < 30000; tries++) {
    // the way: from a source, straight runs, a prism at each turn, the seal at the end
    const cells = [];
    for (let y = zone.y; y < zone.y + zone.h; y++) for (let x = zone.x; x < zone.x + zone.w; x++) if (inZone(x, y) && Math.hypot(x - f.entry[0], y - f.entry[1]) > 1.5) cells.push([x, y]);
    const source = cells[Math.floor(rnd() * cells.length)];
    const dirs = Object.entries(S.DIRS);
    let [dname, d] = dirs[Math.floor(rnd() * 4)];
    const used = new Set([S.key(source[0], source[1])]);
    const path = [];
    const turns = [];
    let at = source.slice();
    let ok = true;
    const want_turns = want.turns + Math.floor(rnd() * 3);
    for (let t = 0; t <= want_turns && ok; t++) {
      const run = 2 + Math.floor(rnd() * 4);
      for (let k = 0; k < run; k++) {
        const n = [at[0] + d[0], at[1] + d[1]];
        if (!inZone(n[0], n[1]) || used.has(S.key(n[0], n[1]))) { ok = k >= 1; break; }
        at = n; used.add(S.key(n[0], n[1])); path.push(n);
      }
      if (!ok) break;
      if (t === want_turns) break;
      // turn here: a prism on the cell we stand on
      const turn = rnd() < 0.5 ? 0 : 1;
      turns.push({ at: at.slice(), turn });
      d = S.reflect(d, turn);
    }
    if (!ok || turns.length < want.turns || path.length < 3) continue;
    const seal = path[path.length - 1];
    if (turns.some(t => t.at[0] === seal[0] && t.at[1] === seal[1])) continue;
    const g = gridOf(b, false);
    for (let y = zone.y; y < zone.y + zone.h; y++) for (let x = zone.x; x < zone.x + zone.w; x++) g.set(x, y, inZone(x, y) ? '.' : '#');
    // rocks off the way, decoy prisms beside it
    const off = cells.filter(c => !used.has(S.key(c[0], c[1])) && Math.hypot(c[0] - f.entry[0], c[1] - f.entry[1]) > 1.5);
    shuffle(off, rnd);
    let k = 0;
    const rocks = off.slice(k, k += Math.floor(off.length * want.rocks));
    for (const [x, y] of rocks) g.set(x, y, '#');
    const near = off.slice(k).filter(c => path.some(p => Math.abs(p[0] - c[0]) + Math.abs(p[1] - c[1]) <= 2));
    const decoys = near.slice(0, want.prisms - turns.length);
    g.set(source[0], source[1], '#');
    const pc = [...turns.map(t => t.at), ...decoys];
    const seals = new Set([S.key(seal[0], seal[1])]);
    const sols = S.solvePrisms(g, [{ at: source, d: S.DIRS[dname] }], pc, seals);
    if (sols.length !== 1 || sols[0].used < want.turns) continue;
    const solid = new Set([S.key(source[0], source[1]), S.key(seal[0], seal[1]), ...pc.map(c => S.key(c[0], c[1]))]);
    const open = S.reach(f.entry, (x, y) => g.at(x, y) !== '#' && !solid.has(S.key(x, y)));
    if (!pc.every(c => S.D4.some(([dx, dy]) => open.has(S.key(c[0] + dx, c[1] + dy))))) continue;
    for (const [x, y] of rocks) rock(b, ['F', 'f', 'j', 'X'][Math.floor(rnd() * 4)], x, y);
    b.piece('beam_source', source[0], source[1], { dir: dname });
    b.piece('beam_seal', seal[0], seal[1], { group: 'A' });
    const right = sols[0].set;
    const start = {};
    pc.forEach((c, i) => { const r = right[S.key(c[0], c[1])]; const s = i < turns.length ? (i === 0 || rnd() < 0.75 ? 1 - r : r) : (rnd() < 0.5 ? 1 : 0); start[S.key(c[0], c[1])] = s; b.piece('prism', c[0], c[1], { turn: s, fixed: false }); });
    const turn = pc.filter(c => sols[0].touched.includes(S.key(c[0], c[1])) && start[S.key(c[0], c[1])] !== right[S.key(c[0], c[1])]);
    return { turn, used: sols[0].used, prisms: pc.length };
  }
  throw new Error(b.id + ': no prism puzzle found');
}

// ---------- Kristallglocken ----------

/** The crystals stand side by side in one row from f.row ([x, y]) to the east, their notes shuffled: the
 * hero tries them one by one to find which sings which note of the statue's song. */
function bells(f, seed, want) {
  const { b } = f;
  const rnd = S.random(seed);
  const notes = shuffle(Array.from({ length: want.crystals }, (_, i) => i + 1), rnd);
  // never all in order: the row must be listened to
  if (notes.every((n, i) => n === i + 1)) notes.reverse();
  const crystals = notes.map((n, i) => [f.row[0] + i, f.row[1]]);
  crystals.forEach((c, i) => b.piece('crystal', c[0], c[1], { group: 'A', note: notes[i] }));
  // a melody that uses at least want.length - 1 crystals and never just runs along the row
  const pos = n => notes.indexOf(n);
  let melody = [];
  for (let tries = 0; tries < 1000; tries++) {
    melody = [];
    while (melody.length < want.length) { const n = 1 + Math.floor(rnd() * want.crystals); if (melody[melody.length - 1] !== n) melody.push(n); }
    const at = melody.map(pos);
    const runs = at.every((p, i) => i === 0 || p > at[i - 1]) || at.every((p, i) => i === 0 || p < at[i - 1]);
    if (new Set(melody).size >= want.length - 1 && !runs) break;
  }
  b.piece('bell_statue', f.statue[0], f.statue[1], { group: 'A', melody: melody.join(','), glow: false });
  b.piece('bell_plate', f.plate[0], f.plate[1], { group: 'A' });
  return { crystals: crystals.map((c, i) => ({ at: c, note: notes[i] })), melody };
}

// ---------- Eisgang ----------

/** A field of thin ice: every plate as often as it holds, from the start to the goal; one way only.
 * The way is laid first (a random Hamilton path over the field cut from start to goal, then side trips
 * into dead ends whose first plate must hold two), the cells it never takes become rocks; kept when the
 * solver walks it by the rules. */
function iceWalk(f, seed, want) {
  const { b } = f;
  const rnd = S.random(seed);
  const z = f.field;
  const inside = (x, y) => x >= z.x && y >= z.y && x < z.x + z.w && y < z.y + z.h;
  const total = z.w * z.h;
  const goalNext = c => Math.abs(c[0] - f.goal[0]) + Math.abs(c[1] - f.goal[1]) === 1;
  // a long path from the start to a cell beside the goal: a random Hamilton path over the whole field
  // (backbite moves on a snake), cut between the cell beside the start and the cell beside the goal
  const sNext = S.D4.map(([dx, dy]) => [f.from[0] + dx, f.from[1] + dy]).find(c => inside(c[0], c[1]));
  const tNext = S.D4.map(([dx, dy]) => [f.goal[0] + dx, f.goal[1] + dy]).find(c => inside(c[0], c[1]));
  let snake = [];
  for (let y = 0; y < z.h; y++) for (let i = 0; i < z.w; i++) snake.push([z.x + (y % 2 ? z.w - 1 - i : i), z.y + y]);
  const longPath = () => {
    for (let m = 0; m < 400; m++) {
      const head = rnd() < 0.5;
      if (!head) snake.reverse();
      const e = snake[0];
      const nb = S.D4.map(([dx, dy]) => [e[0] + dx, e[1] + dy]).filter(c => inside(c[0], c[1]) && !(c[0] === snake[1][0] && c[1] === snake[1][1]));
      if (!nb.length) continue;
      const q = nb[Math.floor(rnd() * nb.length)];
      const j = snake.findIndex(c => c[0] === q[0] && c[1] === q[1]);
      snake = [...snake.slice(0, j).reverse(), ...snake.slice(j)];
    }
    const a = snake.findIndex(c => c[0] === sNext[0] && c[1] === sNext[1]);
    const t = snake.findIndex(c => c[0] === tNext[0] && c[1] === tNext[1]);
    const part = a < t ? snake.slice(a, t + 1) : snake.slice(t, a + 1).reverse();
    return part.length >= total * want.cover ? part.map(c => c.slice()) : null;
  };
  for (let tries = 0; tries < 4000; tries++) {
    const way = longPath();
    if (!way) continue;
    const on = new Set(way.map(c => S.key(c[0], c[1])));
    // side trips: from a plate of the way into a free cell and back; that plate holds two
    let trips = 0;
    for (let k = 0; k < 40 && trips < want.twice; k++) {
      const i = 1 + Math.floor(rnd() * (way.length - 2));
      const p = way[i];
      if (way.filter(c => c[0] === p[0] && c[1] === p[1]).length > 1) continue;
      const nooks = S.D4.map(([dx, dy]) => [p[0] + dx, p[1] + dy]).filter(c => inside(c[0], c[1]) && !on.has(S.key(c[0], c[1])));
      if (!nooks.length) continue;
      const n = nooks[Math.floor(rnd() * nooks.length)];
      way.splice(i + 1, 0, n, p.slice());
      on.add(S.key(n[0], n[1]));
      trips++;
    }
    if (trips < want.twice) continue;
    const used = new Map();
    for (const c of way) used.set(S.key(c[0], c[1]), (used.get(S.key(c[0], c[1])) || 0) + 1);
    const g = new S.Grid(b.w, b.h);
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) g.set(x, y, used.has(S.key(x, y)) ? (used.get(S.key(x, y)) === 2 ? 'I' : 'i') : '#');
    g.set(f.from[0], f.from[1], '.');
    g.set(f.goal[0], f.goal[1], '.');
    // the solver must walk it by the game's rules (a full field has many ways: every plate still has to break)
    const res = S.solveIceWalk(g, f.from, f.goal, 1, want.most || 150000);
    if (res.paths.length < 1) continue;
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) {
      const c = g.at(x, y);
      if (c === 'i' || c === 'I') b.piece('thin_ice', x, y, { holds: c === 'I' ? 2 : 1, group: 'A' });
      else rock(b, ['F', 'f', 'X', 'k'][Math.floor(rnd() * 4)], x, y);
    }
    b.piece('ice_goal', f.goal[0], f.goal[1], { group: 'A' });
    return { path: res.paths[0], cells: used.size, twice: trips, tries };
  }
  throw new Error(b.id + ': no ice walk found');
}

// ---------- Brüchiges Eis und das Frostherz ----------

/** Thin ice with crevasses between the start and the heart's island; the way there and back must differ. */
function frostHeart(f, seed, want) {
  const { b } = f;
  const rnd = S.random(seed);
  const z = f.field;
  const inside = (x, y) => x >= z.x && y >= z.y && x < z.x + z.w && y < z.y + z.h;
  for (let tries = 0; tries < 4000; tries++) {
    // two random ways from the start side to the island, as cell lists
    const wander = (from, to, avoid) => {
      const path = [from];
      const seen = new Set([S.key(from[0], from[1])]);
      let at = from;
      for (let n = 0; n < 400; n++) {
        if (Math.abs(at[0] - to[0]) + Math.abs(at[1] - to[1]) === 1) { path.push(to); return path; }
        const opts = S.D4.map(([dx, dy]) => [at[0] + dx, at[1] + dy]).filter(c => inside(c[0], c[1]) && !seen.has(S.key(c[0], c[1])) && !(avoid && avoid.has(S.key(c[0], c[1])) && rnd() < 0.85));
        if (!opts.length) return null;
        opts.sort((p, q) => (Math.abs(p[0] - to[0]) + Math.abs(p[1] - to[1])) - (Math.abs(q[0] - to[0]) + Math.abs(q[1] - to[1])));
        at = rnd() < 0.55 ? opts[0] : opts[Math.floor(rnd() * opts.length)];
        seen.add(S.key(at[0], at[1]));
        path.push(at);
      }
      return null;
    };
    const out = wander(f.from, f.island, null);
    if (!out) continue;
    const used1 = new Set(out.slice(1, -1).map(c => S.key(c[0], c[1])));
    const back = wander(f.island, f.back, used1);
    if (!back) continue;
    const count = new Map();
    for (const c of [...out.slice(1, -1), ...back.slice(1, -1)]) count.set(S.key(c[0], c[1]), (count.get(S.key(c[0], c[1])) || 0) + 1);
    if ([...count.values()].some(v => v > 2)) continue;
    if (out.length + back.length < want.min) continue;
    const twice = [...count.values()].filter(v => v === 2).length;
    if (twice < want.crossings) continue;
    // the rest: crevasses mostly, some ice that holds once as false ways
    for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) {
      const k = S.key(x, y);
      if (count.has(k)) b.piece('thin_ice', x, y, { holds: count.get(k) });
      else if (rnd() < want.decoys) b.piece('thin_ice', x, y, { holds: rnd() < 0.2 ? 2 : 1 });
      else b.set(x, y, PIT);
    }
    return { out, back, twice, length: out.length + back.length };
  }
  throw new Error(b.id + ': no frost heart puzzle found');
}

// ---------- Spiegelgeist ----------

function mirror(f, seed, want) {
  const { b } = f;
  const rnd = S.random(seed);
  const H = f.hero, G = f.ghost;
  for (let tries = 0; tries < 20000; tries++) {
    const wall = new Set();
    const put = (z, share) => { for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x; x < z.x + z.w; x++) if (rnd() < share) wall.add(S.key(x, y)); };
    put(H, want.walls);
    put(G, want.walls);
    const inH = (x, y) => x >= H.x && y >= H.y && x < H.x + H.w && y < H.y + H.h;
    const inG = (x, y) => x >= G.x && y >= G.y && x < G.x + G.w && y < G.y + G.h;
    wall.delete(S.key(f.start[0], f.start[1]));
    for (const c of f.keep || []) wall.delete(S.key(c[0], c[1]));
    const heroOk = (x, y) => inH(x, y) && !wall.has(S.key(x, y));
    const ghostOk = (x, y) => inG(x, y) && !wall.has(S.key(x, y));
    const hcells = [], gcells = [];
    for (let y = H.y; y < H.y + H.h; y++) for (let x = H.x; x < H.x + H.w; x++) if (heroOk(x, y)) hcells.push([x, y]);
    for (let y = G.y; y < G.y + G.h; y++) for (let x = G.x; x < G.x + G.w; x++) if (ghostOk(x, y)) gcells.push([x, y]);
    const hr = S.reach(f.start, heroOk);
    const pick = (list, ok) => { const l = list.filter(ok); return l.length ? l[Math.floor(rnd() * l.length)] : null; };
    const far = want.far || 8;
    const hp = pick(hcells, c => hr.has(S.key(c[0], c[1])) && Math.abs(c[0] - f.start[0]) + Math.abs(c[1] - f.start[1]) > far);
    const gh = pick(gcells, () => true);
    if (!hp || !gh) continue;
    const gr = S.reach(gh, ghostOk);
    const gp = pick(gcells, c => gr.has(S.key(c[0], c[1])) && Math.abs(c[0] - gh[0]) + Math.abs(c[1] - gh[1]) > far);
    if (!gp) continue;
    const res = S.solveMirror(heroOk, ghostOk, f.start, gh, hp, gp, 400000);
    if (!res || res.length < want.min) continue;
    // the plain way to the hero's plate must not already bring the ghost home
    const plain = S.walk(f.start, hp, heroOk);
    if (!plain || plain.length - 1 + 6 > res.length) continue;
    for (const k of wall) { const [x, y] = k.split(',').map(Number); rock(b, inH(x, y) ? ['F', 'f', 'X', 'k'][Math.floor(rnd() * 4)] : ['g', 'h', 'f', 'j'][Math.floor(rnd() * 4)], x, y); }
    b.piece('mirror_ghost', gh[0], gh[1], { group: 'A', show: res.path.map(c => [c[0] - gh[0], c[1] - gh[1]]) });
    b.piece('ghost_plate', hp[0], hp[1], { group: 'A', who: 'hero' });
    b.piece('ghost_plate', gp[0], gp[1], { group: 'A', who: 'ghost' });
    return { path: res.path, ghost: res.ghost, length: res.length, hp, gp, gh };
  }
  throw new Error(b.id + ': no mirror puzzle found');
}

module.exports = { angled, long, tower, cellsOf, dressHall, gridOf, nook, blocks, balls, ember, prisms, bells, iceWalk, frostHeart, mirror };

// The Frostgruft's puzzle rules as the game plays them (src/world_kit/frost_puzzles.gd), on a grid of
// letters, with a solver for each puzzle. The room builder (tools/frost_dungeon/rooms/build_frost_rooms.js)
// draws candidates, keeps those the solver finds hard enough and writes the way into the room file
// (show for the mirror) and into user://frost_steps.json for the replay in the real game.
// Grid letters: '#' wall or something solid, '.' floor, 'o' crevasse (pit), 'i' thin ice holding 1,
// 'I' thin ice holding 2, '*' deep snow, 'f' cold fog. Cells are [x, y].
'use strict';

const D4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const DIRS = { e: [1, 0], w: [-1, 0], s: [0, 1], n: [0, -1] };
const key = (x, y) => x + ',' + y;

/** A seeded random of a text (the same as the Krypta builder's). */
function random(text) {
  let h = 2166136261;
  for (const ch of text) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); }
  return () => {
    h |= 0; h = (h + 0x6D2B79F5) | 0;
    let t = Math.imul(h ^ (h >>> 15), 1 | h);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

class Grid {
  constructor(w, h, fill = '#') { this.w = w; this.h = h; this.c = Array.from({ length: h }, () => Array(w).fill(fill)); }
  at(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h ? this.c[y][x] : '#'; }
  set(x, y, v) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.c[y][x] = v; }
  clone() { const g = new Grid(this.w, this.h); g.c = this.c.map(r => r.slice()); return g; }
  text() { return this.c.map(r => r.join('')).join('\n'); }
}

/** Cells the hero reaches from `from` walking over `ok` cells (Set of keys). */
function reach(from, ok) {
  const seen = new Set([key(from[0], from[1])]);
  const todo = [from];
  while (todo.length) {
    const [x, y] = todo.pop();
    for (const [dx, dy] of D4) {
      const k = key(x + dx, y + dy);
      if (!seen.has(k) && ok(x + dx, y + dy)) { seen.add(k); todo.push([x + dx, y + dy]); }
    }
  }
  return seen;
}

/** The shortest walk from a to b over `ok` cells, as cells (a first), or null. */
function walk(a, b, ok) {
  const prev = new Map([[key(a[0], a[1]), null]]);
  const todo = [a];
  while (todo.length) {
    const c = todo.shift();
    if (c[0] === b[0] && c[1] === b[1]) {
      const out = [];
      let k = key(c[0], c[1]), at = c;
      while (at) { out.unshift(at); at = prev.get(key(at[0], at[1])); }
      return out;
    }
    for (const [dx, dy] of D4) {
      const n = [c[0] + dx, c[1] + dy];
      const k = key(n[0], n[1]);
      if (!prev.has(k) && ok(n[0], n[1])) { prev.set(k, c); todo.push(n); }
    }
  }
  return null;
}

// ---------- Eisblöcke: blocks slide until stopped, fill crevasses ----------

/**
 * Pushes of ice blocks until the hero reaches `goal`. g: Grid of '#', '.', 'o'; blocks: [[x, y]];
 * hero: [x, y]. {pushes: [[x, y, dir]] (block cell, direction), length} or null.
 */
function solveBlocks(g, blocks, hero, goal, most = 400000) {
  const enc = (bl, filled, h) => bl.map(b => key(b[0], b[1])).sort().join(';') + '|' + [...filled].sort().join(';') + '|' + h;
  const start = { bl: blocks.map(b => b.slice()), filled: new Set(), hero };
  const free = (s, x, y) => { const c = g.at(x, y); if (c === '#') return false; if (c === 'o' && !s.filled.has(key(x, y))) return false; return !s.bl.some(b => b[0] === x && b[1] === y); };
  const canon = s => { const r = reach(s.hero, (x, y) => free(s, x, y)); let best = null; for (const k of r) if (best === null || k < best) best = k; return { r, best }; };
  const first = canon(start);
  const seen = new Map([[enc(start.bl, start.filled, first.best), null]]);
  const todo = [{ s: start, r: first.r, id: enc(start.bl, start.filled, first.best) }];
  let n = 0;
  while (todo.length && n++ < most) {
    const { s, r, id } = todo.shift();
    if (r.has(key(goal[0], goal[1]))) {
      const out = [];
      let at = id;
      while (seen.get(at)) { const p = seen.get(at); out.unshift(p.move); at = p.from; }
      return { pushes: out, length: out.length };
    }
    s.bl.forEach((b, i) => {
      for (const [d, [dx, dy]] of Object.entries(DIRS)) {
        if (!r.has(key(b[0] - dx, b[1] - dy))) continue;
        const others = s.bl.filter((_, j) => j !== i);
        const t = { bl: others, filled: s.filled, hero: null };
        let x = b[0], y = b[1], fill = false;
        for (;;) {
          const nx = x + dx, ny = y + dy, c = g.at(nx, ny);
          if (c === '#' || others.some(o => o[0] === nx && o[1] === ny)) break;
          if (c === 'o' && !s.filled.has(key(nx, ny))) { x = nx; y = ny; fill = true; break; }
          x = nx; y = ny;
        }
        if (x === b[0] && y === b[1]) continue;
        const nb = fill ? others.map(o => o.slice()) : [...others.map(o => o.slice()), [x, y]];
        const nf = new Set(s.filled); if (fill) nf.add(key(x, y));
        const ns = { bl: nb, filled: nf, hero: [b[0], b[1]] };
        const c2 = canon(ns);
        const nid = enc(nb, nf, c2.best);
        if (seen.has(nid)) continue;
        seen.set(nid, { from: id, move: [b[0], b[1], d] });
        todo.push({ s: ns, r: c2.r, id: nid });
      }
    });
  }
  return null;
}

// ---------- Schneeball: rolls a cell per push, grows on deep snow, fills from size `fill` ----------

/**
 * g: Grid of '#', '.', 'o', '*' (deep snow); balls: [[x, y, size]]; the hero wins when every crevasse
 * in `need` (keys) is filled and he reaches `goal`. {pushes: [[x, y, dir]], length} or null.
 */
function solveBalls(g, balls, hero, goal, opts = {}) {
  const most = opts.most || 600000, maxSize = opts.max || 3, fillSize = opts.fill || 3;
  const enc = (s, best) => s.b.map(b => b.join(',')).sort().join(';') + '|' + [...s.snow].sort().join(';') + '|' + [...s.filled].sort().join(';') + '|' + best;
  const snow0 = new Set();
  for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) if (g.at(x, y) === '*') snow0.add(key(x, y));
  const start = { b: balls.map(b => b.slice()), snow: snow0, filled: new Set(), hero };
  const free = (s, x, y) => { const c = g.at(x, y); if (c === '#') return false; if (c === 'o' && !s.filled.has(key(x, y))) return false; return !s.b.some(b => b[0] === x && b[1] === y); };
  const canon = s => { const r = reach(s.hero, (x, y) => free(s, x, y)); let best = null; for (const k of r) if (best === null || k < best) best = k; return { r, best }; };
  const c0 = canon(start);
  const id0 = enc(start, c0.best);
  const seen = new Map([[id0, null]]);
  const todo = [{ s: start, r: c0.r, id: id0 }];
  let n = 0;
  while (todo.length && n++ < most) {
    const { s, r, id } = todo.shift();
    if (r.has(key(goal[0], goal[1]))) {
      const out = [];
      let at = id;
      while (seen.get(at)) { const p = seen.get(at); out.unshift(p.move); at = p.from; }
      return { pushes: out, length: out.length };
    }
    s.b.forEach((b, i) => {
      for (const [d, [dx, dy]] of Object.entries(DIRS)) {
        if (!r.has(key(b[0] - dx, b[1] - dy))) continue;
        const nx = b[0] + dx, ny = b[1] + dy, c = g.at(nx, ny);
        const others = s.b.filter((_, j) => j !== i);
        if (c === '#' || others.some(o => o[0] === nx && o[1] === ny)) continue;
        const ns = { b: others.map(o => o.slice()), snow: new Set(s.snow), filled: new Set(s.filled), hero: [b[0], b[1]] };
        if (c === 'o' && !s.filled.has(key(nx, ny))) {
          if (b[2] >= fillSize) ns.filled.add(key(nx, ny));
          // a small ball is lost: no use going on from there (the rune would reset it)
          else continue;
        } else {
          let size = b[2];
          if (ns.snow.has(key(nx, ny))) { ns.snow.delete(key(nx, ny)); size = Math.min(maxSize, size + 1); }
          ns.b.push([nx, ny, size]);
        }
        const c2 = canon(ns);
        const nid = enc(ns, c2.best);
        if (seen.has(nid)) continue;
        seen.set(nid, { from: id, move: [b[0], b[1], d] });
        todo.push({ s: ns, r: c2.r, id: nid });
      }
    });
  }
  return null;
}

// ---------- Glut tragen: ember lasts `steps`, fog costs `fog` ----------

/**
 * g: Grid of '#', '.', 'f' (cold fog); source: [x, y] (the hearth's cell, solid); bowls: [[x, y]] (solid).
 * The hero takes ember next to a lit thing and walks to a cell next to a bowl. {order: [bowl index],
 * legs: [{from, to, cost, path}], depth} or null when not every bowl can be lit.
 */
function solveEmber(g, source, bowls, steps = 14, fog = 2) {
  const solid = new Set([key(source[0], source[1]), ...bowls.map(b => key(b[0], b[1]))]);
  const ok = (x, y) => g.at(x, y) !== '#' && !solid.has(key(x, y));
  const beside = c => D4.map(([dx, dy]) => [c[0] + dx, c[1] + dy]).filter(n => ok(n[0], n[1]));
  // cheapest cost from any cell next to `from` to every cell (Dijkstra, the cost of entering a cell)
  const costs = from => {
    const best = new Map();
    const todo = [];
    for (const n of beside(from)) { best.set(key(n[0], n[1]), { cost: 0, prev: null, at: n }); todo.push([0, n]); }
    while (todo.length) {
      todo.sort((a, b) => a[0] - b[0]);
      const [c, at] = todo.shift();
      if (best.get(key(at[0], at[1])).cost < c) continue;
      for (const [dx, dy] of D4) {
        const n = [at[0] + dx, at[1] + dy];
        if (!ok(n[0], n[1])) continue;
        const nc = c + (g.at(n[0], n[1]) === 'f' ? fog : 1);
        const k = key(n[0], n[1]);
        if (!best.has(k) || best.get(k).cost > nc) { best.set(k, { cost: nc, prev: at, at: n }); todo.push([nc, n]); }
      }
    }
    return best;
  };
  const lit = [source];
  const level = [0];
  const order = [], legs = [];
  const left = bowls.map((b, i) => i);
  let grew = true;
  while (left.length && grew) {
    grew = false;
    let pick = null;
    for (let li = 0; li < lit.length && !pick; li++) {
      const map = costs(lit[li]);
      for (const bi of left) {
        let bestEnd = null;
        for (const n of beside(bowls[bi])) { const e = map.get(key(n[0], n[1])); if (e && (!bestEnd || e.cost < bestEnd.cost)) bestEnd = e; }
        if (bestEnd && bestEnd.cost <= steps) {
          const path = [];
          let at = bestEnd.at, cur = bestEnd;
          while (cur) { path.unshift(cur.at); cur = cur.prev ? map.get(key(cur.prev[0], cur.prev[1])) : null; }
          pick = { bi, li, cost: bestEnd.cost, path };
          break;
        }
      }
    }
    if (pick) {
      left.splice(left.indexOf(pick.bi), 1);
      lit.push(bowls[pick.bi]);
      level.push(level[pick.li] + 1);
      order.push(pick.bi);
      legs.push({ from: pick.li === 0 ? 'source' : order[pick.li - 1], to: pick.bi, cost: pick.cost, path: pick.path });
      grew = true;
    }
  }
  if (left.length) return null;
  return { order, legs, depth: Math.max(...level) };
}

/** The cheapest ember cost from cells next to a to cells next to b (Infinity when none). */
function emberCost(g, a, b, solid, fog = 2) {
  const ok = (x, y) => g.at(x, y) !== '#' && !solid.has(key(x, y));
  const best = new Map();
  const todo = [];
  for (const [dx, dy] of D4) { const n = [a[0] + dx, a[1] + dy]; if (ok(n[0], n[1])) { best.set(key(n[0], n[1]), 0); todo.push([0, n]); } }
  while (todo.length) {
    todo.sort((p, q) => p[0] - q[0]);
    const [c, at] = todo.shift();
    for (const [dx, dy] of D4) {
      const n = [at[0] + dx, at[1] + dy];
      if (!ok(n[0], n[1])) continue;
      const nc = c + (g.at(n[0], n[1]) === 'f' ? fog : 1);
      if (!best.has(key(n[0], n[1])) || best.get(key(n[0], n[1])) > nc) { best.set(key(n[0], n[1]), nc); todo.push([nc, n]); }
    }
  }
  let out = Infinity;
  for (const [dx, dy] of D4) { const k = key(b[0] + dx, b[1] + dy); if (best.has(k)) out = Math.min(out, best.get(k)); }
  return out;
}

// ---------- Lichtprismen ----------

function reflect(d, turn) { return turn === 0 ? [-d[1], -d[0]] : [d[1], d[0]]; }

/** The light from source cell s along d over g ('#' stops, 'P' stops) with prisms {key: turn}; the seal key it hits or null. */
function traceLight(g, s, d, prisms, seals, most = 600) {
  let x = s[0], y = s[1], dx = d[0], dy = d[1];
  const turns = [];
  const seen = new Set();
  for (let k = 0; k < most; k++) {
    x += dx; y += dy;
    const c = g.at(x, y);
    if (c === '#') return { seal: null, turns };
    const kk = key(x, y);
    if (seals.has(kk)) return { seal: kk, turns };
    if (kk in prisms) {
      const sk = kk + ':' + dx + ',' + dy;
      if (seen.has(sk)) return { seal: null, turns };
      seen.add(sk);
      [dx, dy] = reflect([dx, dy], prisms[kk]);
      turns.push(kk);
    }
  }
  return { seal: null, turns };
}

/**
 * The ways of the light that light all seals: [{set: {key: turn}, used, touched}], one per different way
 * (prisms the light never meets do not make another way).
 */
function solvePrisms(g, sources, prismCells, seals, fixed = {}) {
  const ways = new Map();
  const n = prismCells.length;
  for (let m = 0; m < (1 << n); m++) {
    const set = Object.assign({}, fixed);
    prismCells.forEach((c, i) => { set[key(c[0], c[1])] = (m >> i) & 1; });
    const lit = new Set();
    const touched = [];
    for (const s of sources) { const r = traceLight(g, s.at, s.d, set, seals); if (r.seal) lit.add(r.seal); touched.push(...r.turns); }
    if (lit.size !== seals.size) continue;
    const sig = touched.map(k => k + '=' + set[k]).sort().join(';');
    if (!ways.has(sig)) ways.set(sig, { set, used: touched.length, touched });
  }
  return [...ways.values()];
}

// ---------- Eisgang: every thin ice exactly as often as it holds ----------

/**
 * g: Grid with 'i' (holds 1), 'I' (holds 2), '#' and '.' (firm). From `from` (firm, outside) over the
 * ice to `goal` (firm) so that every ice breaks; firm cells other than from and goal are not entered.
 * {paths: up to `want` ways as cell lists} (stops after `most` tries).
 */
function solveIceWalk(g, from, goal, want = 2, most = 4000000) {
  const left = new Map();
  for (let y = 0; y < g.h; y++) for (let x = 0; x < g.w; x++) { const c = g.at(x, y); if (c === 'i') left.set(key(x, y), 1); if (c === 'I') left.set(key(x, y), 2); }
  let total = 0; for (const v of left.values()) total += v;
  const paths = [];
  const path = [from];
  let tries = 0;
  // the ice still to break must hang together with where we are (else no way covers it)
  const together = at => {
    const open = [...left.entries()].filter(([, v]) => v > 0).map(([k]) => k);
    if (!open.length) return true;
    const seen = new Set();
    const todo = [];
    for (const [dx, dy] of D4) { const k = key(at[0] + dx, at[1] + dy); if (left.get(k) > 0) { seen.add(k); todo.push(k.split(',').map(Number)); } }
    while (todo.length) { const [x, y] = todo.pop(); for (const [dx, dy] of D4) { const k = key(x + dx, y + dy); if (left.get(k) > 0 && !seen.has(k)) { seen.add(k); todo.push([x + dx, y + dy]); } } }
    return seen.size === open.length;
  };
  const goalNear = () => D4.some(([dx, dy]) => left.has(key(goal[0] + dx, goal[1] + dy)));
  const step = (at, remaining) => {
    if (paths.length >= want || ++tries > most) return;
    for (const [dx, dy] of D4) {
      const n = [at[0] + dx, at[1] + dy];
      const k = key(n[0], n[1]);
      if (n[0] === goal[0] && n[1] === goal[1]) {
        if (remaining === 0) { paths.push([...path, n]); if (paths.length >= want) return; }
        continue;
      }
      if (!(left.get(k) > 0)) continue;
      // leaving `at` breaks it one more step: done by the caller; entering n is allowed while it holds
      left.set(k, left.get(k) - 1);
      path.push(n);
      if (together(n) || remaining - 1 === 0) step(n, remaining - 1);
      path.pop();
      left.set(k, left.get(k) + 1);
    }
  };
  if (!goalNear()) return { paths, tries };
  // entering a cell uses one of its steps (each step on means one step off later)
  step(from, total);
  return { paths, tries };
}

// ---------- Spiegelgeist ----------

/**
 * Hero and ghost on one grid: the ghost steps the hero's step mirrored left-right where it is free.
 * heroOk / ghostOk: (x, y) -> bool. {path: hero cells, ghost: ghost cells, length} shortest, or null.
 */
function solveMirror(heroOk, ghostOk, hero, ghost, heroGoal, ghostGoal, most = 2000000) {
  const id = (h, g) => h[0] + ',' + h[1] + '|' + g[0] + ',' + g[1];
  const prev = new Map([[id(hero, ghost), null]]);
  const todo = [[hero, ghost]];
  let n = 0;
  while (todo.length && n++ < most) {
    const [h, g] = todo.shift();
    if (h[0] === heroGoal[0] && h[1] === heroGoal[1] && g[0] === ghostGoal[0] && g[1] === ghostGoal[1]) {
      const path = [], gp = [];
      let at = [h, g];
      while (at) { path.unshift(at[0]); gp.unshift(at[1]); at = prev.get(id(at[0], at[1])); }
      return { path, ghost: gp, length: path.length - 1 };
    }
    for (const [dx, dy] of D4) {
      const nh = [h[0] + dx, h[1] + dy];
      if (!heroOk(nh[0], nh[1])) continue;
      let ng = [g[0], g[1]];
      if (dx !== 0) { const t = [g[0] - dx, g[1]]; if (ghostOk(t[0], t[1])) ng = t; }
      if (dy !== 0) { const t = [g[0], g[1] + dy]; if (ghostOk(t[0], t[1])) ng = t; }
      const k = id(nh, ng);
      if (prev.has(k)) continue;
      prev.set(k, [h, g]);
      todo.push([nh, ng]);
    }
  }
  return null;
}

module.exports = { D4, DIRS, key, random, Grid, reach, walk, solveBlocks, solveBalls, solveEmber, emberCost, reflect, traceLight, solvePrisms, solveIceWalk, solveMirror };

// Plays a Weltbauer jump puzzle room (assets/data/world_rooms/<world>/<id>.json) the way the game does
// (src/hell/launch_pads.gd, hell_game.gd _update_hazards and act, hell_rules.gd step_sequence) on the cell
// grid, and reports what a designer must know: can the doors reach each other without the puzzle, is the
// reward reachable and by which way, can every reachable place get back to a door, does a pad chain throw
// forever. It reports observations, it never edits a room.
//
//   node tools/krypta_dungeon/jump_puzzles/solver.js assets/data/world_rooms/krypta/k_sprung_kammern.json
//
// Model (one cell = 96 px):
// - walking: 4 neighbours over floor, bridge, Moder (hurts), spikes and vents (hurt in their beat);
//   never into a pit; walls, closed gates, hidden walls and solid pieces block;
// - an awake pad is entered only by being thrown: stepping on it throws (cells x dir); a blocked landing
//   gives way back towards the pad; landing on an awake pad throws on; landing in a pit costs life and puts
//   the hero back on the pad that threw him;
// - a plate is pressed when the hero steps or lands on it; an ordered group resets on a wrong plate;
// - chests, levers, fire bowls, locked gates and skull heaps work from a neighbouring cell.

'use strict';
const fs = require('fs');

const CELL = 96;
const STEP = { n: [0, -1], e: [1, 0], s: [0, 1], w: [-1, 0] };
const KEYS = ['A', 'B', 'C'];

function cellOf(x, y) { return [Math.floor(x / CELL), Math.floor(y / CELL)]; }

/** The room's pieces sorted into what the search needs. */
function prepare(room) {
  const W = room.width, H = room.height;
  const base = room.cells.map((r) => r.split(''));
  const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? '0' : base[y][x]);
  const key = (x, y) => y * W + x;
  const solid = new Set();
  const groups = {};
  const group = (id) => (groups[id] = groups[id] || { id, plates: [], seq: false, levers: [], braziers: [], heaps: [], doors: [], wakes: [], openers: [] });
  const pads = [], plates = [], chests = [], levers = [], braziers = [], doors = [], heaps = [], keys = [], tablets = [];
  const hurts = new Set();
  const notes = [];
  for (const o of room.objects) {
    const [cx, cy] = cellOf(o.x, o.y);
    switch (o.kind) {
      case 'launch': {
        const p = { i: pads.length, cx, cy, dir: o.dir || 'n', cells: o.cells || 4, wake: o.wake || '' };
        pads.push(p);
        if (p.wake) group(p.wake).wakes.push(p.i);
        break;
      }
      case 'plate': {
        const p = { i: plates.length, cx, cy, group: o.group || 'A', order: o.order || 0, enemies: o.enemies || [] };
        plates.push(p);
        const g = group(p.group);
        g.plates.push(p.i);
        if (p.order > 0) g.seq = true;
        break;
      }
      case 'chest':
        chests.push({ i: chests.length, cx, cy, loot: (o.loot || {}).type || 'gold', key: (o.loot || {}).id, mimic: o.mimic || 'no', enemies: o.enemies || [] });
        solid.add(key(cx, cy));
        break;
      case 'enemy':
        if (['mimik', 'truhenfresser'].includes(o.mob)) {
          chests.push({ i: chests.length, cx, cy, loot: 'none', mimic: 'yes', enemies: [] });
          solid.add(key(cx, cy));
        } else notes.push(`Gegner ${o.mob} bei ${cx},${cy}`);
        break;
      case 'lever': levers.push({ cx, cy, group: o.group || 'A' }); group(o.group || 'A').levers.push(levers.length - 1); break;
      case 'brazier': braziers.push({ i: braziers.length, cx, cy, group: o.group || 'A' }); group(o.group || 'A').braziers.push(braziers.length - 1); solid.add(key(cx, cy)); break;
      case 'skullheap': heaps.push({ cx, cy, group: o.group || 'A' }); group(o.group || 'A').heaps.push(heaps.length - 1); break;
      case 'key': keys.push({ i: keys.length, cx, cy, key: o.key || 'A' }); break;
      case 'spikes': case 'vent': hurts.add(key(cx, cy)); break;
      case 'tablet': tablets.push({ cx, cy, text: o.text || '' }); solid.add(key(cx, cy)); break;
      case 'gate': case 'secret': {
        const a = cellOf(o.x, o.y);
        const b = o.dir === 'h' ? [a[0], a[1] + 1] : [a[0] + 1, a[1]];
        const closes = o.kind === 'secret' || !['open', 'arch', 'passage', 'boss_arch', 'stairs', 'demon_fall'].includes(o.style || '');
        const d = { i: doors.length, kind: o.kind, cells: [a, b], dir: o.dir || 'v', group: o.group || 'A', lock: o.lock || '', closes };
        doors.push(d);
        if (closes && !d.lock) group(d.group).doors.push(d.i);
        break;
      }
      case 'prop':
        if (o.block && !o.wall_decor && !o.decal) solid.add(key(...cellOf(o.x, o.y - 1)));
        if (o.opens) group(o.opens).openers.push({ cx, cy });
        break;
      case 'raw':
        if (o.ent && ['vault', 'crate', 'shop', 'seal'].includes(o.ent.type)) solid.add(key(cx, cy));
        break;
    }
  }
  // gates dig through walls behind them (world_gates.gd dug): open ground on both sides, at most 8
  const dug = new Set();
  for (const d of doors) {
    if (d.kind !== 'gate') continue;
    const across = d.dir === 'h' ? [1, 0] : [0, 1];
    for (const [kx, ky] of d.cells) {
      const through = [[kx, ky]];
      let ends = 0;
      for (const s of [1, -1]) {
        let x = kx + across[0] * s, y = ky + across[1] * s;
        const run = [];
        while (run.length < 8 && at(x, y) === '0' && x > 0 && y > 0 && x < W - 1 && y < H - 1) { run.push([x, y]); x += across[0] * s; y += across[1] * s; }
        if (at(x, y) !== '0') { ends++; through.push(...run); }
      }
      if (ends === 2) for (const [x, y] of through) dug.add(key(x, y));
    }
  }
  const doorAt = new Map();
  for (const d of doors) for (const [x, y] of d.cells) doorAt.set(key(x, y), d.i);
  const padAt = new Map(pads.map((p) => [key(p.cx, p.cy), p.i]));
  const plateAt = new Map(plates.map((p) => [key(p.cx, p.cy), p.i]));
  const keyAt = new Map(keys.map((k) => [key(k.cx, k.cy), k.i]));
  const gids = Object.keys(groups).sort();
  // the doors' inside cells
  const portCells = [];
  for (const p of room.ports || []) {
    const [x, y] = p.cell;
    const along = ['east', 'west'].includes(p.side) ? [[x, y], [x, y + 1]] : [[x, y], [x + 1, y]];
    const inward = { north: [0, 1], south: [0, -1], west: [1, 0], east: [-1, 0] }[p.side];
    const inside = [];
    for (const [ax, ay] of along) {
      for (let k = 0; k <= 3; k++) {
        const c = [ax + inward[0] * k, ay + inward[1] * k];
        if (at(...c) !== '0') { inside.push(c); break; }
      }
    }
    portCells.push({ port: p, cells: inside });
  }
  const start = room.objects.find((o) => o.kind === 'start');
  return { room, W, H, at, key, solid, groups, gids, pads, plates, chests, levers, braziers, doors, heaps, keys, tablets, hurts, dug, doorAt, padAt, plateAt, keyAt, portCells, notes,
    start: start ? cellOf(start.x, start.y - 6) : null };
}

/** The changing part of the world: solved groups, plates on, the ordered groups' next, keys, gates unlocked, bowls lit. */
function freshState(P) {
  return { solved: [], on: [], next: {}, keys: [], unlocked: [], lit: [], taken: [] };
}
const sk = (s) => JSON.stringify([s.solved, s.on, s.next, s.keys, s.unlocked, s.lit, s.taken]);
const clone = (s) => ({ solved: [...s.solved], on: [...s.on], next: { ...s.next }, keys: [...s.keys], unlocked: [...s.unlocked], lit: [...s.lit], taken: [...s.taken] });
const add = (arr, v) => { if (!arr.includes(v)) { arr.push(v); arr.sort(); } };

function solve(P, s, gid) {
  if (s.solved.includes(gid)) return;
  add(s.solved, gid);
}

/** What stands in cell x, y in state s: 'wall', 'pit', 'pad', 'walk', 'hurt'. */
function cellKind(P, s, x, y) {
  const k = P.key(x, y);
  const di = P.doorAt.get(k);
  if (di !== undefined) {
    const d = P.doors[di];
    if (!d.closes) return 'walk';
    if (d.kind === 'secret') return s.solved.includes(d.group) ? 'walk' : 'wall';
    if (d.lock) return s.unlocked.includes(d.i) ? 'walk' : 'wall';
    return s.solved.includes(d.group) ? 'walk' : 'wall';
  }
  const c = P.at(x, y);
  if (c === '0' && !P.dug.has(k)) return 'wall';
  if (P.solid.has(k)) return 'wall';
  if (c === '4') return 'pit';
  const pi = P.padAt.get(k);
  if (pi !== undefined && awake(P, s, P.pads[pi])) return 'pad';
  if (c === '2' || P.hurts.has(k)) return 'hurt';
  return 'walk';
}
const awake = (P, s, pad) => !pad.wake || s.solved.includes(pad.wake);

/** Steps on a plate or a key: the new state and what happened. */
function stepOn(P, s, x, y) {
  const k = P.key(x, y);
  const events = [];
  const pi = P.plateAt.get(k);
  if (pi !== undefined) {
    const p = P.plates[pi];
    const g = P.groups[p.group];
    if (!s.solved.includes(p.group) && !s.on.includes(pi)) {
      s = clone(s);
      if (!g.seq) {
        add(s.on, pi);
        events.push(`Platte ${p.group} gedrückt`);
        if (g.plates.every((q) => s.on.includes(q))) { solve(P, s, p.group); events.push(`Gruppe ${p.group} gelöst`); }
      } else {
        const next = s.next[p.group] || 1;
        if (p.order === next) {
          add(s.on, pi);
          s.next[p.group] = next + 1;
          events.push(`Platte ${p.group}${p.order} richtig`);
          if (g.plates.every((q) => s.on.includes(q))) { solve(P, s, p.group); events.push(`Gruppe ${p.group} gelöst`); }
        } else {
          s.on = s.on.filter((q) => P.plates[q].group !== p.group);
          s.next[p.group] = 1;
          events.push(`FALSCH: Platte ${p.group}${p.order}` + (p.enemies.length ? ` (Strafe: ${p.enemies.join(', ')})` : ''));
        }
      }
    }
  }
  const ki = P.keyAt.get(k);
  if (ki !== undefined && !s.taken.includes('k' + ki)) {
    s = clone(s);
    add(s.taken, 'k' + ki);
    add(s.keys, P.keys[ki].key);
    events.push(`Schlüssel ${P.keys[ki].key}`);
  }
  return { s, events };
}

/** Where a throw from pad `p` ends: a cell, how many throws, what it passed. */
function throwFrom(P, s, p, seen = []) {
  if (seen.includes(p.i)) return { loop: [...seen, p.i] };
  const [dx, dy] = STEP[p.dir];
  let tx = p.cx + dx * p.cells, ty = p.cy + dy * p.cells;
  // a blocked spot gives way back along the path
  while ((tx !== p.cx || ty !== p.cy) && cellKind(P, s, tx, ty) === 'wall') { tx -= dx; ty -= dy; }
  const kind = cellKind(P, s, tx, ty);
  const chain = [...seen, p.i];
  if (kind === 'pad' && !(tx === p.cx && ty === p.cy)) return throwFrom(P, s, P.pads[P.padAt.get(P.key(tx, ty))], chain);
  if (kind === 'pit') return { chain, pit: [tx, ty], back: p };
  return { chain, land: [tx, ty], hurt: kind === 'hurt', short: tx !== p.cx + dx * p.cells || ty !== p.cy + dy * p.cells };
}

/** Everything the hero can do in one move from cell c in state s: [{cell, s, how, hurt, throws}]. */
function moves(P, c, s) {
  const out = [];
  const [x, y] = c;
  for (const [dx, dy] of Object.values(STEP)) {
    const nx = x + dx, ny = y + dy;
    const kind = cellKind(P, s, nx, ny);
    if (kind === 'wall' || kind === 'pit') continue;
    if (kind === 'pad') {
      const p = P.pads[P.padAt.get(P.key(nx, ny))];
      const t = throwFrom(P, s, p);
      if (t.loop) { out.push({ loop: t.loop }); continue; }
      if (t.pit) { out.push({ cell: [t.back.cx, t.back.cy], s, how: `Wurf ${t.chain.map((i) => padName(P, i)).join(' > ')} in die Grube bei ${t.pit}`, pit: true, throws: t.chain.length }); continue; }
      const r = stepOn(P, s, ...t.land);
      out.push({ cell: t.land, s: r.s, how: `Wurf ${t.chain.map((i) => padName(P, i)).join(' > ')} landet ${t.land}${t.hurt ? ' im Moder' : ''}${t.short ? ' (kürzer, Mauer)' : ''}` + (r.events.length ? ': ' + r.events.join(', ') : ''), hurt: t.hurt, throws: t.chain.length, events: r.events });
      continue;
    }
    const r = stepOn(P, s, nx, ny);
    out.push({ cell: [nx, ny], s: r.s, how: r.events.length ? `geht nach ${nx},${ny}: ${r.events.join(', ')}` : '', hurt: kind === 'hurt', walk: true, events: r.events });
  }
  // what works from a neighbouring cell
  const near = (cx, cy) => Math.abs(cx - x) + Math.abs(cy - y) === 1 || (cx === x && cy === y);
  for (const l of P.levers) {
    if (near(l.cx, l.cy) && !s.solved.includes(l.group)) { const n = clone(s); solve(P, n, l.group); out.push({ cell: c, s: n, how: `Fackel ${l.group} entzündet`, events: ['Fackel'] }); }
  }
  for (const h of P.heaps) {
    if (near(h.cx, h.cy) && !s.solved.includes(h.group)) { const n = clone(s); solve(P, n, h.group); out.push({ cell: c, s: n, how: `Schädelhaufen ${h.group} zerschlagen`, events: ['Haufen'] }); }
  }
  for (const gid of P.gids) {
    for (const o of P.groups[gid].openers) {
      if (near(o.cx, o.cy) && !s.solved.includes(gid)) { const n = clone(s); solve(P, n, gid); out.push({ cell: c, s: n, how: `Teil zerschlagen: öffnet ${gid}`, events: ['Teil'] }); }
    }
  }
  for (const b of P.braziers) {
    if (near(b.cx, b.cy) && !s.lit.includes(b.i)) {
      const n = clone(s);
      add(n.lit, b.i);
      const g = P.groups[b.group];
      const ev = [`Feuerschale ${b.group} entzündet`];
      if (g.braziers.every((i) => n.lit.includes(i))) { solve(P, n, b.group); ev.push(`Gruppe ${b.group} gelöst`); }
      out.push({ cell: c, s: n, how: ev.join(', '), events: ev });
    }
  }
  for (const d of P.doors) {
    if (!d.lock || s.unlocked.includes(d.i) || !s.keys.includes(d.lock)) continue;
    if (d.cells.some(([dx, dy]) => Math.abs(dx - x) + Math.abs(dy - y) <= 2)) {
      const n = clone(s);
      n.keys = n.keys.filter((k) => k !== d.lock);
      add(n.unlocked, d.i);
      out.push({ cell: c, s: n, how: `Tor mit Schlüssel ${d.lock} geöffnet`, events: ['Schloss'] });
    }
  }
  // only a chest that gives a key changes the world; the others are noted by the search (chestsNear)
  for (const ch of P.chests) {
    if (!near(ch.cx, ch.cy) || ch.loot !== 'key' || ch.mimic !== 'no' || s.taken.includes('c' + ch.i)) continue;
    const n = clone(s);
    add(n.taken, 'c' + ch.i);
    add(n.keys, ch.key || 'A');
    out.push({ cell: c, s: n, how: `Truhe bei ${ch.cx},${ch.cy} gibt Schlüssel ${ch.key || 'A'}`, events: ['Truhe'] });
  }
  return out;
}

/** The chests the hero can open from cell c. */
function chestsNear(P, c) {
  return P.chests.filter((ch) => Math.abs(ch.cx - c[0]) + Math.abs(ch.cy - c[1]) === 1);
}

function padName(P, i) { const p = P.pads[i]; return `${p.cx},${p.cy}${p.dir}${p.cells}`; }

/** The whole search: every reachable (cell, state), the way to each, and the reports. */
function analyze(room, opts = {}) {
  const P = prepare(room);
  const report = { id: room.id, title: room.title, problems: [], notes: [...P.notes] };
  const starts = [];
  if (P.start) starts.push(P.start);
  for (const pc of P.portCells) for (const c of pc.cells) starts.push(c);
  if (!starts.length) { report.problems.push('Kein Start und keine Türstelle.'); return report; }
  // 1. the doors without the puzzle: walking only, no Moder, no throws, nothing solved
  const s0 = freshState(P);
  const calm = new Set();
  const todo = [starts[0]];
  const ck = (c) => c[0] + ',' + c[1];
  calm.add(ck(starts[0]));
  while (todo.length) {
    const c = todo.pop();
    for (const [dx, dy] of Object.values(STEP)) {
      const n = [c[0] + dx, c[1] + dy];
      if (calm.has(ck(n)) || cellKind(P, s0, ...n) !== 'walk' || P.plateAt.has(P.key(...n))) continue;
      calm.add(ck(n));
      todo.push(n);
    }
  }
  report.ports = P.portCells.map((pc) => ({ port: `${pc.port.side} ${pc.port.cell}`, linked: pc.cells.length > 0 && pc.cells.some((c) => calm.has(ck(c))), inside: pc.cells.length > 0 }));
  for (const p of report.ports) {
    if (!p.inside) report.problems.push(`Türstelle ${p.port} hat keinen Boden dahinter.`);
    else if (!p.linked) report.problems.push(`Türstelle ${p.port} ist ohne Rätsel nicht vom Start erreichbar.`);
  }
  if (P.start && !calm.has(ck(P.start))) report.problems.push('Start steht nicht im freien Bereich.');
  report.calm = calm.size;
  // 2. everything reachable
  const nodes = new Map();
  const key = (c, s) => ck(c) + '|' + sk(s);
  const queue = [];
  const begin = (c) => { const k = key(c, s0); if (!nodes.has(k)) { nodes.set(k, { c, s: s0, prev: null, how: 'Start', throws: 0, hurts: 0, k }); queue.push(k); } };
  begin(starts[0]);
  const loops = new Set();
  const edges = new Map();
  // 0-1 search: a step that hurts costs 1, so every way found hurts the least possible
  const front = [];
  const usedPads = new Set();
  const opened = new Map();
  let cut = false;
  const done = new Set();
  while ((front.length || queue.length) && !cut) {
    const k = front.length ? front.pop() : queue.shift();
    if (done.has(k)) continue;
    done.add(k);
    const node = nodes.get(k);
    for (const ch of chestsNear(P, node.c)) {
      const best = opened.get(ch.i);
      if (!best || node.hurts < best.hurts || (node.hurts === best.hurts && node.throws < best.throws)) opened.set(ch.i, node);
    }
    const out = [];
    for (const m of moves(P, node.c, node.s)) {
      if (m.loop) { loops.add(m.loop.map((i) => padName(P, i)).join(' > ')); continue; }
      const used = /Wurf (.*?) (landet|in die)/.exec(m.how || '');
      if (used) for (const p of used[1].split(' > ')) usedPads.add(p);
      const nk = key(m.cell, m.s);
      out.push(nk);
      const wrong = (m.events || []).some((e) => e.startsWith('FALSCH'));
      const cost = m.hurt || m.pit || wrong ? 1 : 0;
      const old = nodes.get(nk);
      const hurts = node.hurts + cost, throws = node.throws + (m.throws || 0);
      if (!old || (!done.has(nk) && (hurts < old.hurts || (hurts === old.hurts && throws < old.throws)))) {
        nodes.set(nk, { c: m.cell, s: m.s, prev: k, how: m.how, throws, hurts, k: nk });
        if (cost) queue.push(nk); else front.push(nk);
      }
    }
    edges.set(k, out);
    if (nodes.size > (opts.limit || 400000)) { report.problems.push('Zu viele Zustände, Suche abgebrochen.'); cut = true; }
  }
  for (const l of loops) report.problems.push(`Endlosschleife der Sprungplatten: ${l}`);
  report.states = nodes.size;
  // 3. the way back: every reached place must reach a door cell (or the start)
  const goal = new Set(starts.map(ck));
  const back = new Map();
  for (const [k, outs] of edges) for (const o of outs) { if (!back.has(o)) back.set(o, []); back.get(o).push(k); }
  const good = new Set();
  const stack = [];
  for (const [k, n] of nodes) if (goal.has(ck(n.c))) { good.add(k); stack.push(k); }
  while (stack.length) { const k = stack.pop(); for (const p of back.get(k) || []) if (!good.has(p)) { good.add(p); stack.push(p); } }
  const stuck = new Map();
  for (const [k, n] of nodes) if (!good.has(k)) stuck.set(ck(n.c), n);
  for (const [c, n] of stuck) report.problems.push(`Kein Weg zurück von ${c} (nach: ${n.how}).`);
  // 4. the rewards: the way to every chest, fewest hurts first, then fewest throws
  report.chests = [];
  for (const ch of P.chests) {
    const best = opened.get(ch.i) || null;
    report.chests.push({ at: `${ch.cx},${ch.cy}`, loot: ch.loot, mimic: ch.mimic, enemies: ch.enemies, reached: !!best, throws: best ? best.throws : null, hurts: best ? best.hurts : null, way: best ? wayTo(nodes, best) : [], steps: best ? steps(nodes, best) : [] });
  }
  const hoards = report.chests.filter((c) => c.loot === 'hoard');
  if (!hoards.length) report.problems.push('Keine Schatztruhe im Raum.');
  for (const h of hoards) if (!h.reached) report.problems.push(`Schatztruhe ${h.at} ist nicht erreichbar.`);
  // 5. pads never used, groups never solved
  const solvedAny = new Set();
  for (const [, n] of nodes) for (const g of n.s.solved) solvedAny.add(g);
  report.unusedPads = P.pads.map((p, i) => padName(P, i)).filter((n) => !usedPads.has(n));
  report.unsolved = P.gids.filter((g) => !solvedAny.has(g));
  report.pads = P.pads.length;
  report.tablets = P.tablets.map((t) => t.text);
  return report;
}

function wayTo(nodes, n) {
  return steps(nodes, n).map((s) => s.how);
}

/** The way to node n as steps a replay can act out: {how, from, to} cells, without plain walking. */
function steps(nodes, n) {
  const out = [];
  const end = n;
  while (n) {
    const prev = n.prev ? nodes.get(n.prev) : null;
    if (n.how && n.how !== 'Start') out.push({ how: n.how, from: prev ? prev.c : n.c, to: n.c });
    n = prev;
  }
  out.reverse();
  out.push({ how: 'Truhe öffnen', from: end.c, to: end.c });
  return out;
}

function print(report) {
  return printLines(report);
}

function printLines(report) {
  const lines = [`== ${report.id} (${report.title})`];
  lines.push(`Türen frei verbunden: ${report.ports.map((p) => `${p.port}:${p.linked ? 'ja' : 'NEIN'}`).join(', ')}`);
  lines.push(`Zustände ${report.states}, Platten ${report.pads}, nie benutzte Sprungplatten: ${report.unusedPads.length ? report.unusedPads.join(' ') : 'keine'}, nie gelöste Gruppen: ${report.unsolved.join(' ') || 'keine'}`);
  for (const c of report.chests) {
    lines.push(`Truhe ${c.at} ${c.loot}${c.mimic !== 'no' ? ' Mimik ' + c.mimic : ''}: ${c.reached ? `erreichbar, ${c.throws} Würfe, ${c.hurts} Fehler oder Treffer` : 'NICHT erreichbar'}`);
    if (c.loot === 'hoard' && c.reached) for (const w of c.way) lines.push('    ' + w);
  }
  for (const p of report.problems) lines.push('PROBLEM: ' + p);
  for (const n of report.notes) lines.push('Hinweis: ' + n);
  return lines.join('\n');
}

module.exports = { analyze, print, prepare, cellKind };

if (require.main === module) {
  let bad = 0;
  for (const f of process.argv.slice(2)) {
    const r = analyze(JSON.parse(fs.readFileSync(f, 'utf8')));
    console.log(print(r));
    bad += r.problems.length;
  }
  process.exit(bad ? 1 : 0);
}

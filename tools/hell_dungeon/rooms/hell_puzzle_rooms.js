// The hell's puzzle rooms (role "jump", docs/HOELLE-RAETSEL.de.md): eight riddles, each in five tiers
// (Beuteordnung, docs/BEUTEORDNUNG.de.md 3). Every room has a hall the floor's doors open into (a free way
// joins them, the puzzle stays optional), a rune and an inscription at the puzzle's entrance, the puzzle in
// its zone and the Schatz at the zone's far end. A riddle is laid out along a "lane" (u along the zone from
// the entrance to the Schatz, v across it) and placed into the frame of the room's shape. Riddles with
// switches (chain bridges, valves, chain shields) are drawn from a seed and kept only when the solver below
// finds them solvable with at least the tier's number of moves; timed riddles (vents, flood, eyes) and the
// blood paths are made solvable by their construction.
'use strict';
const S = require('../../frost_dungeon/puzzles/solvers.js');
const R = require('./room.js');
const { Room, check, WALL, FLOOR, C, MIRROR } = R;

// ---------- frames ----------
// tier -> frame: 1 angled (la), 2 angled (lc), 3 tower part, 4 long, 5 tower whole
const FRAME_OF = { 1: 'la', 2: 'lc', 3: 'h3', 4: 'b3', 5: 'h3' };

/** The room and its lane: to(u, v) -> room cell, dir(local dir) -> room dir, L x Wd, the entrance cell of the
 *  zone (u 0) and the door between hall and zone. */
function frame(id, title, shape, tier) {
  const b = new Room(`h_${id}`, title, 'jump', shape);
  b.extra = { kind_label: 'Höllenrätsel' };
  if (shape === 'la' || shape === 'lc') {
    const tall = shape === 'lc';
    b.rect(1, 1, 12, 23, FLOOR);
    const zy = tall ? 15 : 1;
    const ev = 4;
    b.port('north', 5, 0);
    b.port('west', 0, tall ? 4 : 13);
    b.port('south', 5, 24);
    return { b, L: 16, Wd: 9, ev, gv: 4, to: (u, v) => [14 + u, zy + v], dir: d => d, door: [13, zy + ev], hall: { x: 1, y: 1, w: 12, h: 23 }, tier };
  }
  if (shape === 'b3') {
    b.rect(1, 1, 46, 2, FLOOR);
    b.port('west', 0, 1);
    b.port('east', 47, 1);
    b.port('north', 23, 0);
    return { b, L: 46, Wd: 6, ev: 0, gv: 3, to: (u, v) => [1 + u, 4 + v], dir: d => d, door: [1, 3], hall: { x: 1, y: 1, w: 46, h: 2 }, tier, entryFromTop: true };
  }
  // tower: u runs down, v runs right; tier 3 uses the upper 26 cells, tier 5 all 37
  b.rect(1, 1, 2, 37, FLOOR);
  b.port('north', 1, 0);
  b.port('south', 1, 38);
  b.port('west', 0, 18);
  const L = tier === 3 ? 26 : 37;
  const turn = { e: 's', s: 'e', w: 'n', n: 'w' };
  return { b, L, Wd: 9, ev: 0, gv: 4, to: (u, v) => [4 + v, 1 + u], dir: d => turn[d], door: [3, 1], hall: { x: 1, y: 1, w: 2, h: 37 }, tier, tower: true };
}

/** Opens the zone: lane cells floor (local walls stay wall), the door into it. */
function openZone(f, walls) {
  const { b } = f;
  for (let u = 0; u < f.L; u++) for (let v = 0; v < f.Wd; v++) {
    const [x, y] = f.to(u, v);
    b.set(x, y, walls.has(u + ',' + v) ? WALL : FLOOR);
  }
  b.set(f.door[0], f.door[1], FLOOR);
}

/** A piece at lane cell (u, v); `dir` fields turn with the frame. */
function put(f, kind, u, v, extra = {}) {
  const [x, y] = f.to(u, v);
  const e = Object.assign({ group: 'A' }, extra);
  if (e.dir) e.dir = f.dir(e.dir);
  f.b.piece(kind, x, y, e);
}

/** The rune and the inscription beside the door in the hall, the Schatz at the lane's far end. */
function finish(f, text, tier, goal, extra = {}) {
  const { b } = f;
  const [dx, dy] = f.door;
  const rune = f.tower || f.entryFromTop ? [dx + (f.tower ? -1 : 0), dy + (f.tower ? 1 : -1)] : [dx - 1, dy];
  b.piece('hell_rune', rune[0], rune[1], { group: 'A' });
  const tab = f.tower ? [1, 3] : f.entryFromTop ? [dx + 2, 1] : [dx - 1, dy - 2];
  b.tablet(tab[0], tab[1], text);
  const [cx, cy] = f.to(goal[0], goal[1]);
  // the Schatz: its tier is the riddle's (loot.tier 1-5, the Beuteordnung), never a Mimik
  b.thing('chest', cx + 0.5, cy + 0.85, { loot: { type: 'hoard', tier }, mimic: 'no' });
  const zone = new Set();
  for (let u = 0; u < f.L; u++) for (let v = 0; v < f.Wd; v++) { const [x, y] = f.to(u, v); zone.add(S.key(x, y)); }
  b.checkOpts = { skip: o => zone.has(S.key(Math.floor(o.x / C), Math.floor((o.y - 10) / C))) || (o.kind === 'chest' && o.loot && o.loot.type === 'hoard') };
  b.wallDress(R.WALLS.chains);
  b.snow(0.04, zone);
  b.scatter('hall', zone, 3.6);
  b.start();
  b.extra.info = extra.info || '';
  check(b);
  return b;
}

// ---------- the solver of switch riddles ----------
// pieces: [{kind, u, v, nr, sets, label, wet, dir, always, up, down, open}] in lane cells
function solveSwitches(L, Wd, walls, pieces, entry, goal, most = 60000) {
  const at = new Map();
  for (const p of pieces) { const k = p.u + ',' + p.v; if (!at.has(k)) at.set(k, []); at.get(k).push(p); }
  const solidKinds = ['hell_winch', 'hell_valve', 'hell_shield'];
  const nrs = [...new Set(pieces.filter(p => p.kind === 'hell_bridge' || p.kind === 'hell_shield').map(p => p.nr))].sort((a, b) => a - b);
  const labels = [...new Set(pieces.filter(p => p.kind === 'hell_valve').map(p => p.label))].sort();
  const bit = { };
  nrs.forEach((n, i) => { bit['n' + n] = i; });
  labels.forEach((l, i) => { bit['l' + l] = nrs.length + i; });
  // state bits: bridge/shield nr flipped from its start; valve open
  let start = 0;
  for (const l of labels) if (pieces.some(p => p.kind === 'hell_valve' && p.label === l && p.open)) start |= 1 << bit['l' + l];
  const flipped = (s, nr) => (s >> bit['n' + nr]) & 1;
  const open = (s, l) => !!((s >> bit['l' + l]) & 1);
  const wetOf = (wet, s) => {
    if (!wet || !wet.trim()) return true;
    return wet.split('|').some(term => term.split('&').every(lit => { const t = lit.trim(); const neg = t.startsWith('!'); return open(s, t.replace('!', '')) !== neg; }));
  };
  const inLane = (u, v) => u >= 0 && v >= 0 && u < L && v < Wd && !walls.has(u + ',' + v);
  const solid = (u, v) => (at.get(u + ',' + v) || []).some(p => solidKinds.includes(p.kind));
  const coverAt = (s, u, v) => {
    if (!inLane(u, v)) return true;
    for (const p of at.get(u + ',' + v) || []) {
      if (p.kind === 'hell_shield') return !!(p.down ^ flipped(s, p.nr));
      if (solidKinds.includes(p.kind)) return true;
    }
    return false;
  };
  const eyes = pieces.filter(p => p.kind === 'hell_eye');
  const DV = { n: [0, -1], e: [1, 0], s: [0, 1], w: [-1, 0] };
  const hotCells = s => {
    const hot = new Set();
    for (const [k, list] of at) {
      const br = list.find(p => p.kind === 'hell_bridge');
      const ch = list.find(p => p.kind === 'hell_channel');
      const up = br ? !!(br.up ^ flipped(s, br.nr)) : true;
      if (ch && wetOf(ch.wet, s) && up) hot.add(k);
      if (!ch && br && up) hot.add(k);
    }
    for (const e of eyes) {
      // lane dirs: 'e' = +u, 's' = +v
      const d = DV[e.dir];
      let u = e.u + d[0], v = e.v + d[1];
      for (let i = 0; i < 64 && !coverAt(s, u, v); i++) { hot.add(u + ',' + v); u += d[0]; v += d[1]; }
    }
    return hot;
  };
  const switches = pieces.filter(p => p.kind === 'hell_winch' || p.kind === 'hell_valve');
  const apply = (s, p) => {
    if (p.kind === 'hell_valve') return s ^ (1 << bit['l' + p.label]);
    let t = s;
    for (const n of p.sets) if (bit['n' + n] !== undefined) t ^= 1 << bit['n' + n];
    return t;
  };
  const regionOf = (s, from) => {
    const hot = hotCells(s);
    const ok = (u, v) => inLane(u, v) && !solid(u, v) && !hot.has(u + ',' + v);
    if (!ok(from[0], from[1])) return null;
    return S.reach(from, ok);
  };
  const near = (reg, p) => [[0, 1], [1, 0], [0, -1], [-1, 0]].some(([du, dv]) => reg.has(S.key(p.u + du, p.v + dv)));
  const goalIn = reg => [[0, 0], [0, 1], [1, 0], [0, -1], [-1, 0]].some(([du, dv]) => reg.has(S.key(goal[0] + du, goal[1] + dv)));
  const first = regionOf(start, entry);
  if (!first) return null;
  const canon = reg => { let m = null; for (const k of reg) if (m === null || k < m) m = k; return m; };
  const seen = new Map([[start + '|' + canon(first), null]]);
  const todo = [{ s: start, reg: first, id: start + '|' + canon(first), moves: [] }];
  let n = 0;
  while (todo.length && n++ < most) {
    const cur = todo.shift();
    if (goalIn(cur.reg)) return { moves: cur.moves, start };
    for (const p of switches) {
      if (!near(cur.reg, p)) continue;
      const s2 = apply(cur.s, p);
      // the hero stays where he stood: a cell of the old region next to the switch that is still safe
      const stand = [[0, 1], [1, 0], [0, -1], [-1, 0]].map(([du, dv]) => [p.u + du, p.v + dv]).find(c => cur.reg.has(S.key(c[0], c[1])));
      const reg2 = regionOf(s2, stand);
      if (!reg2) continue;
      const id = s2 + '|' + canon(reg2);
      if (seen.has(id)) continue;
      seen.set(id, true);
      todo.push({ s: s2, reg: reg2, id, moves: cur.moves.concat([[p.kind, p.u, p.v]]) });
    }
  }
  return null;
}

// ---------- the eight riddles ----------
const TEXT = {
  ketten: 'Jede Kette zieht an mehr als einer Last.\nWer eine Brücke senkt, hebt vielleicht die nächste.\nErst wenn der Schacht geschlossen ist, trägt er dich.\nDie Rune setzt alle Ketten zurück.',
  takt: 'Die Erde atmet Feuer.\nSie holt Luft, bevor sie brennt.\nGeh, wenn sie ausatmet, und steh, wenn sie Luft holt.',
  flut: 'Der Schlund atmet Glut.\nAtmet er aus, steigt das Feuer, atmet er ein, sinkt es.\nZähl seinen Atem und spring von Stein zu Stein.',
  blut: 'Drei Wege führen zum Schatz, und jeder will Blut.\nWer wenig gibt, bekommt wenig.\nWer viel gibt, dem öffnet sich die Truhe weit.\nDie Schale vor dem Schatz zählt jeden Tropfen. Wer nicht zahlen will, geht vorüber.',
  schleuse: 'Das Feuer kennt nur einen Weg: den, den man ihm baut.\nDreh die Rinnen, bis das Maul die Schmiede erreicht.\nÖffne die Schleuse erst, wenn jede Rinne zur nächsten führt.',
  augen: 'Sie schlafen nie zugleich.\nZähl ihre Lider, nicht deine Schritte.\nDer Schatten einer Säule ist dein Freund.',
  werk: 'Das Feuer hat mehrere Betten und nur wenige Hände, die es lenken.\nWas du hier öffnest, verschließt du dort.\nGeh zurück, wenn der Weg nach vorn brennt.',
  wacht: 'Eine Kette, zwei Lasten.\nWas dich verbirgt, nimmt dir vielleicht den Weg.\nWas dir den Weg gibt, verrät dich vielleicht.',
};
const NAME = { ketten: 'Kettenbrücken', takt: 'Flammentakt', flut: 'Lavaflut', blut: 'Blutpreis', schleuse: 'Lavaschleusen', augen: 'Dämonenaugen', werk: 'Schleusenwerk', wacht: 'Kettenwacht' };
const shuffle = (a, rnd) => { for (let k = a.length - 1; k > 0; k--) { const j = Math.floor(rnd() * (k + 1)); [a[k], a[j]] = [a[j], a[k]]; } return a; };

/** Bands across the lane at even spacing: [u0 of each band] for `n` bands of `thick` cells. */
function bands(L, n, thick) { const gap = (L - 2 - n * thick) / (n + 1); const out = []; for (let i = 0; i < n; i++) out.push(Math.round(1 + gap * (i + 1) + thick * i)); return out; }

/** Kettenbrücken: lava shafts across the lane; over each one a single way of chain bridges one behind the
 *  other, all of which must hang down at once; every winch moves several bridges (Lights Out). */
function ketten(f, rnd) {
  const t = f.tier;
  const nB = [3, 4, 5, 6, 7][t - 1], nW = [3, 4, 4, 5, 6][t - 1], nShaft = [1, 1, 2, 2, 3][t - 1], need = [2, 2, 3, 3, 4][t - 1];
  for (let tries = 0; tries < 6000; tries++) {
    const pieces = [];
    const walls = new Set();
    // segments per shaft: each at least 1 (2 where there are enough), the rest at random
    const per = Array(nShaft).fill(1);
    for (let k = nShaft; k < nB; k++) per[Math.floor(rnd() * nShaft)]++;
    const thick = per.reduce((x, y) => x + y, 0);
    const gap = (f.L - 2 - thick) / (nShaft + 1);
    if (gap < 2) continue;
    let nr = 1;
    let u = 1;
    const shafts = [];
    per.forEach((k, i) => {
      u = Math.round(1 + gap * (i + 1) + per.slice(0, i).reduce((x, y) => x + y, 0));
      const vc = 1 + Math.floor(rnd() * (f.Wd - 2));
      for (let du = 0; du < k; du++) for (let v = 0; v < f.Wd; v++) {
        if (v === vc) pieces.push({ kind: 'hell_bridge', u: u + du, v, nr: nr + du, up: true });
        else pieces.push({ kind: 'hell_channel', u: u + du, v, wet: '' });
      }
      shafts.push([u, k]);
      nr += k;
    });
    // winches: in the stretch before each shaft (the later ones need the earlier shafts crossed)
    const winches = [];
    for (let k = 0; k < nW; k++) {
      const si = k < nShaft ? k : Math.floor(rnd() * nShaft);
      const a0 = si === 0 ? 0 : shafts[si - 1][0] + shafts[si - 1][1];
      const z0 = shafts[si][0] - 1;
      const uw = a0 + Math.floor(rnd() * Math.max(1, z0 - a0));
      const vw = Math.floor(rnd() * f.Wd);
      if ((uw === 0 && vw === f.ev) || winches.some(w => w.u === uw && w.v === vw)) { k--; if (winches.length > 40) break; continue; }
      const size = Math.min(nB, 1 + Math.floor(rnd() * 3));
      const sets = shuffle([...Array(nB).keys()].map(i => i + 1), rnd).slice(0, size).sort((p, q) => p - q);
      // no winch lowers a whole shaft's way by itself: every crossing takes two winches or more
      let first = 1;
      if (per.some(n => { const whole = [...Array(n).keys()].map(i => first + i); first += n; return whole.every(x => sets.includes(x)); })) { k--; continue; }
      winches.push({ kind: 'hell_winch', u: uw, v: vw, sets });
    }
    const all = pieces.concat(winches);
    const goal = [f.L - 1, f.gv];
    const res = solveSwitches(f.L, f.Wd, walls, all, [0, f.ev], goal);
    if (!res || res.moves.length < need) continue;
    return { pieces: all, walls, goal, moves: res.moves.length };
  }
  throw new Error(`${f.b.id}: no Kettenbrücken found`);
}

/** Schleusenwerk: lava channels across the lane, valves deciding which run full, a chain bridge over one. */
function werk(f, rnd) {
  const t = f.tier;
  const nCh = [2, 3, 3, 4, 4][t - 1], labels = ['A', 'B', 'C'].slice(0, [2, 2, 3, 3, 3][t - 1]), nBr = [0, 1, 1, 1, 2][t - 1], need = [2, 3, 4, 5, 6][t - 1];
  const lits = labels.flatMap(l => [l, '!' + l]);
  for (let tries = 0; tries < 6000; tries++) {
    const pieces = [];
    const walls = new Set();
    const chs = bands(f.L, nCh, 1);
    const formulas = chs.map(() => {
      const a = lits[Math.floor(rnd() * lits.length)];
      if (rnd() < 0.45) { let b2 = lits[Math.floor(rnd() * lits.length)]; if (b2.replace('!', '') === a.replace('!', '')) b2 = lits[(lits.indexOf(b2) + 2) % lits.length]; return a + (rnd() < 0.6 ? '|' : '&') + b2; }
      return a;
    });
    const bridged = shuffle([...chs.keys()], rnd).slice(0, nBr);
    let nr = 1;
    chs.forEach((u0, i) => {
      const bv = bridged.includes(i) ? 1 + Math.floor(rnd() * (f.Wd - 2)) : -1;
      for (let v = 0; v < f.Wd; v++) {
        pieces.push({ kind: 'hell_channel', u: u0, v, wet: formulas[i] });
        if (v === bv) pieces.push({ kind: 'hell_bridge', u: u0, v, nr, up: true });
      }
      if (bv >= 0) nr++;
    });
    // valves and winches in the stretches between channels
    const stretch = i => [i === 0 ? 0 : chs[i - 1] + 1, (i < chs.length ? chs[i] : f.L) - 1];
    const used = new Set([0 + ',' + f.ev]);
    const placeIn = (si) => { const [a, z] = stretch(si); for (let k = 0; k < 40; k++) { const u = a + Math.floor(rnd() * Math.max(1, z - a + 1)); const v = Math.floor(rnd() * f.Wd); if (u >= f.L - 1 || used.has(u + ',' + v)) continue; used.add(u + ',' + v); return [u, v]; } return null; };
    let bad = false;
    for (const l of labels) { const c = placeIn(Math.floor(rnd() * Math.min(chs.length, 2))); if (!c) { bad = true; break; } pieces.push({ kind: 'hell_valve', u: c[0], v: c[1], label: l, open: false }); }
    for (let k = 1; k < nr; k++) { const c = placeIn(Math.floor(rnd() * chs.length)); if (!c) { bad = true; break; } pieces.push({ kind: 'hell_winch', u: c[0], v: c[1], sets: [k] }); }
    if (bad) continue;
    const goal = [f.L - 1, f.gv];
    const res = solveSwitches(f.L, f.Wd, walls, pieces, [0, f.ev], goal);
    if (!res || res.moves.length < need) continue;
    return { pieces, walls, goal, moves: res.moves.length };
  }
  throw new Error(`${f.b.id}: no Schleusenwerk found`);
}

/** Kettenwacht: rows seen by demon eyes that never sleep, chain shields that hide you, chain bridges over
 *  shafts; one chain moves a shield and a bridge at once. */
function wacht(f, rnd) {
  const t = f.tier;
  const nRows = [1, 2, 2, 3, 3][t - 1], nShaft = [1, 1, 2, 2, 2][t - 1], nChain = [2, 2, 3, 3, 4][t - 1], need = [2, 3, 3, 4, 5][t - 1];
  for (let tries = 0; tries < 6000; tries++) {
    const pieces = [];
    const walls = new Set();
    const lanesU = bands(f.L, nRows + nShaft, 2);
    const kinds = shuffle(Array(nRows).fill('row').concat(Array(nShaft).fill('shaft')), rnd);
    let bad = false;
    const nrsUsed = [];
    lanesU.forEach((u0, i) => {
      const nrOf = 1 + Math.floor(rnd() * nChain);
      nrsUsed.push(nrOf);
      if (kinds[i] === 'row') {
        // an eye in the side wall looks across the lane (v); a shield next to it hides the rest when down
        const side = rnd() < 0.5;
        const u = u0;
        pieces.push({ kind: 'hell_eye', u, v: side ? -1 : f.Wd, dir: side ? 's' : 'n', always: true });
        pieces.push({ kind: 'hell_shield', u, v: side ? 0 : f.Wd - 1, nr: nrOf, down: false });
      } else {
        const bv = 1 + Math.floor(rnd() * (f.Wd - 2));
        for (let v = 0; v < f.Wd; v++) for (let du = 0; du < 2; du++) {
          if (v === bv) pieces.push({ kind: 'hell_bridge', u: u0 + du, v, nr: nrOf, up: false });
          else pieces.push({ kind: 'hell_channel', u: u0 + du, v, wet: '' });
        }
      }
    });
    if (bad) continue;
    // winches: each chain number one winch (some two), spread over the stretches
    const used = new Set([0 + ',' + f.ev]);
    for (let n = 1; n <= nChain; n++) {
      const count = rnd() < 0.35 ? 2 : 1;
      for (let k = 0; k < count; k++) {
        for (let tryw = 0; tryw < 40; tryw++) {
          const si = Math.floor(rnd() * lanesU.length);
          const a = si === 0 ? 0 : lanesU[si - 1] + 2, z = lanesU[si] - 1;
          const u = a + Math.floor(rnd() * Math.max(1, z - a)), v = Math.floor(rnd() * f.Wd);
          if (used.has(u + ',' + v) || u >= f.L - 1) continue;
          if (pieces.some(p => p.u === u && p.v === v)) continue;
          used.add(u + ',' + v);
          pieces.push({ kind: 'hell_winch', u, v, sets: [n] });
          break;
        }
      }
    }
    const goal = [f.L - 1, f.gv];
    const res = solveSwitches(f.L, f.Wd, walls, pieces, [0, f.ev], goal);
    if (!res || res.moves.length < need) continue;
    return { pieces, walls, goal, moves: res.moves.length };
  }
  throw new Error(`${f.b.id}: no Kettenwacht found`);
}

/** Flammentakt: the lane full of vents in waves, a few pillars; tier 1 a slow wave, higher tiers longer
 *  and with more pillars to walk round. */
function takt(f, rnd) {
  const t = f.tier;
  const period = [4, 3, 3, 3, 3][t - 1], pillars = [0, 0.02, 0.04, 0.06, 0.08][t - 1];
  const pieces = [];
  const walls = new Set();
  for (let u = 1; u < f.L - 1; u++) for (let v = 0; v < f.Wd; v++) {
    if (rnd() < pillars && u > 2 && u < f.L - 3) { walls.add(u + ',' + v); continue; }
    pieces.push({ kind: 'hell_vent', u, v, period });
  }
  return { pieces, walls, goal: [f.L - 1, f.gv], moves: 0 };
}

/** Lavaflut: flood floor with basalt stones, a chain of them from the entrance to the Schatz no farther
 *  apart than one ebb lets you run (gap cells), and stones that lead nowhere. */
function flut(f, rnd) {
  const t = f.tier;
  const gap = [3, 4, 4, 5, 5][t - 1], decoys = [2, 3, 4, 6, 8][t - 1];
  const pieces = [];
  const walls = new Set();
  const stones = [];
  let at = [0, f.ev];
  while (at[0] < f.L - 1 - gap) {
    const du = Math.max(2, gap - Math.floor(rnd() * 2));
    const dv = Math.floor(rnd() * 5) - 2;
    at = [Math.min(f.L - 2, at[0] + du), Math.max(0, Math.min(f.Wd - 1, at[1] + dv))];
    stones.push(at.slice());
  }
  for (let k = 0; k < decoys; k++) stones.push([2 + Math.floor(rnd() * (f.L - 4)), Math.floor(rnd() * f.Wd)]);
  const isStone = (u, v) => stones.some(s => s[0] === u && s[1] === v);
  for (let u = 1; u < f.L - 1; u++) for (let v = 0; v < f.Wd; v++) {
    if (isStone(u, v)) pieces.push({ kind: 'hell_stone', u, v });
    else pieces.push({ kind: 'hell_flood', u, v });
  }
  return { pieces, walls, goal: [f.L - 1, f.gv], moves: stones.length };
}

/** Dämonenaugen: rows seen in turn by eyes in the side walls, pillars to hide behind. */
function augen(f, rnd) {
  const t = f.tier;
  const open = [2, 2, 2, 3, 3][t - 1], closed = [3, 2, 2, 2, 2][t - 1], every = [3, 3, 2, 2, 2][t - 1];
  const pieces = [];
  const walls = new Set();
  let k = 0;
  for (let u = 2; u < f.L - 2; u += every) {
    const side = k % 2 === 0;
    pieces.push({ kind: 'hell_eye', u, v: side ? -1 : f.Wd, dir: side ? 's' : 'n', open, closed, off: Math.floor(rnd() * (open + closed)) });
    // a pillar somewhere in the row (cover), sometimes none
    if (rnd() < 0.7) walls.add(u + ',' + (1 + Math.floor(rnd() * (f.Wd - 2))));
    k++;
  }
  return { pieces, walls, goal: [f.L - 1, f.gv], moves: k };
}

/** Blutpreis: three ways from the entrance to the Schatz between walls, their thorns costing 2, 3 and 4
 *  hearts (the Beuteordnung's blood paths); higher tiers add bends and blood gates. */
function blut(f, rnd) {
  const t = f.tier;
  const walls = new Set();
  const pieces = [];
  const lanes = f.Wd >= 9 ? [1, 4, 7] : [0, 2, 4];
  // walls between the ways, open at both ends (entrance stretch u 0-1, Schatz stretch the last two)
  for (let u = 2; u < f.L - 2; u++) for (let v = 0; v < f.Wd; v++) if (!lanes.includes(v)) walls.add(u + ',' + v);
  const costs = shuffle([2, 3, 4], rnd);
  lanes.forEach((v, i) => {
    const n = costs[i];
    const span = f.L - 6;
    const gates = t >= 3 && n >= 3 ? 1 : 0;
    const thorns = n - gates;
    const spots = shuffle([...Array(span).keys()].map(k => k + 3), rnd).slice(0, thorns + gates).sort((a, b) => a - b);
    spots.forEach((u, k) => pieces.push(k < gates ? { kind: 'hell_blood_gate', u, v } : { kind: 'hell_thorns', u, v }));
  });
  // the blood bowl beside the Schatz
  pieces.push({ kind: 'hell_blood_bowl', u: f.L - 1, v: f.gv === 0 ? 1 : f.gv - 1 });
  return { pieces, walls, goal: [f.L - 1, f.gv], moves: 3, info: 'Blutpreis: drei Wege, 2, 3 oder 4 Herzen; je mehr Blut, desto höher die Truhe.' };
}

/** Lavaschleusen: a grid of turning channels between the demon mouth and the forge; the Schatz waits
 *  behind a gate the forge melts. */
function schleuse(f, rnd) {
  const t = f.tier;
  const gw = Math.min([3, 4, 5, 6, 7][t - 1], f.Wd), gh = Math.min([3, 4, 5, 7, 9][t - 1], f.L - 6), minWay = [4, 6, 9, 12, 16][t - 1];
  const u0 = Math.floor((f.L - gh) / 2), v0 = Math.floor((f.Wd - gw) / 2);
  for (let tries = 0; tries < 3000; tries++) {
    // a random self-avoiding way from the grid's top edge cell (entered from the mouth above) to its bottom
    const sv = Math.floor(rnd() * gw), ev2 = Math.floor(rnd() * gw);
    const way = [[0, sv]];
    const seen = new Set(['0,' + sv]);
    let ok = false;
    for (let step = 0; step < 200; step++) {
      const [a, c] = way[way.length - 1];
      if (a === gh - 1 && c === ev2) { ok = true; break; }
      const opts = [[1, 0], [0, 1], [0, -1], [-1, 0]].map(([da, dc]) => [a + da, c + dc]).filter(([x, y]) => x >= 0 && y >= 0 && x < gh && y < gw && !seen.has(x + ',' + y));
      if (!opts.length) break;
      const pick = opts[Math.floor(rnd() * opts.length)];
      way.push(pick); seen.add(pick[0] + ',' + pick[1]);
    }
    if (!ok || way.length < minWay) continue;
    // directions in lane terms: along u = 's' ... the pipe openings use n/e/s/w of the ROOM, so build them
    // from the room cells of the way
    const cells = [[u0 - 1, v0 + sv]].concat(way.map(([a, c]) => [u0 + a, v0 + c])).concat([[u0 + gh, v0 + ev2]]);
    const roomOf = c => f.to(c[0], c[1]);
    const dirIdx = (p, q) => { const [x1, y1] = roomOf(p), [x2, y2] = roomOf(q); return x2 > x1 ? 1 : x2 < x1 ? 3 : y2 > y1 ? 2 : 0; };
    const pieces = [];
    const onWay = new Map();
    for (let i = 1; i < cells.length - 1; i++) {
      const o = [dirIdx(cells[i], cells[i - 1]), dirIdx(cells[i], cells[i + 1])].sort((a, b) => a - b);
      let shape = 'I', rot = 0;
      if (o[0] === 1 && o[1] === 3) rot = 0; else if (o[0] === 0 && o[1] === 2) rot = 1;
      else { shape = 'L'; rot = [[0, 1], [1, 2], [2, 3], [0, 3]].findIndex(p => p[0] === o[0] && p[1] === o[1]); }
      onWay.set(cells[i][0] + ',' + cells[i][1], { shape, rot });
    }
    for (let a = 0; a < gh; a++) for (let c = 0; c < gw; c++) {
      const u = u0 + a, v = v0 + c;
      const w = onWay.get(u + ',' + v);
      const shape = w ? w.shape : (rnd() < 0.5 ? 'I' : 'L');
      const n = shape === 'I' ? 2 : 4;
      const rot = w ? (w.rot + 1 + Math.floor(rnd() * (n - 1))) % n : Math.floor(rnd() * n);
      pieces.push({ kind: 'hell_pipe', u, v, shape, rot, want: w ? w.rot : -1 });
    }
    const mouth = cells[0], forge = cells[cells.length - 1];
    const walls = new Set();
    pieces.push({ kind: 'hell_spout', u: mouth[0], v: mouth[1], dir: f.tower ? 'e' : 'e' });
    pieces.push({ kind: 'hell_forge', u: forge[0], v: forge[1] });
    // the mouth must face the first pipe: its room direction
    pieces[pieces.length - 2].roomDir = ['n', 'e', 's', 'w'][dirIdx(mouth, cells[1])];
    pieces.push({ kind: 'hell_sluice', u: 0, v: f.ev === 0 ? 1 : f.ev - 1 });
    return { pieces, walls, goal: [f.L - 1, f.gv], moves: way.length, gate: true };
  }
  throw new Error(`${f.b.id}: no Lavaschleusen found`);
}

const MAKERS = { ketten, takt, flut, blut, schleuse, augen, werk, wacht };

/** One riddle room: kind, tier, shape (frame), drawn from seed `seed`. */
function riddleRoom(kind, tier, shape) {
  const id = `${kind}_s${tier}_${shape}`;
  const f = frame(id, `Rätsel: ${NAME[kind]} (Stufe ${tier})`, shape, tier);
  const rnd = S.random('hell_' + id);
  const r = MAKERS[kind](f, rnd);
  // the zone: a gate row before the Schatz when the riddle opens a gate (Lavaschleusen)
  const walls = new Set(r.walls);
  if (r.gate) for (let v = 0; v < f.Wd; v++) walls.add((f.L - 2) + ',' + v);
  openZone(f, walls);
  if (r.gate) {
    // the gate over two wall cells of that row, in the room's terms
    const [gx, gy] = f.to(f.L - 2, Math.max(0, f.gv - 1));
    const [hx, hy] = f.to(f.L - 2, Math.max(0, f.gv - 1) + 1);
    const dir = gx === hx ? 'h' : 'v';
    f.b.gate(Math.min(gx, hx), Math.min(gy, hy), dir, 'A', { style: 'portcullis' });
  }
  for (const p of r.pieces) {
    const extra = {};
    for (const k of ['nr', 'sets', 'label', 'wet', 'dir', 'always', 'up', 'down', 'open', 'closed', 'off', 'period', 'shape', 'rot']) if (p[k] !== undefined) extra[k] = p[k];
    if (p.kind === 'hell_spout') extra.dir = p.roomDir;
    if (p.kind === 'hell_eye') {
      // an eye sits in the wall cell beside the lane, looking in: its dir is in lane terms ('s' = +v)
      extra.dir = f.dir(p.dir === 's' ? 's' : 'n');
      const [x, y] = f.to(p.u, p.v);
      f.b.piece('hell_eye', x, y, Object.assign({ group: 'A' }, extra));
      continue;
    }
    const keepDir = extra.dir;
    delete extra.dir;
    put(f, p.kind, p.u, p.v, extra);
    if (keepDir !== undefined) f.b.objects[f.b.objects.length - 1].dir = keepDir;
  }
  const b = finish(f, TEXT[kind], tier, r.goal, { info: r.info || `${NAME[kind]}, Stufe ${tier}: ${r.moves ? r.moves + ' Schritte im Löser' : ''}` });
  b.steps = [{ kind, tier, moves: r.moves }];
  return b;
}

function puzzles(errors) {
  const out = [];
  for (const kind of Object.keys(MAKERS)) for (let tier = 1; tier <= 5; tier++) {
    const shape = FRAME_OF[tier];
    try {
      const b = riddleRoom(kind, tier, shape);
      out.push(b);
      if (MIRROR[shape]) { const q = b.mirrored(b.id.replace(/_(la|lc)$/, '_' + MIRROR[shape]), MIRROR[shape]); out.push(q); }
    } catch (e) { errors.push(e.message); }
  }
  return out;
}

// ---------- the price rooms (docs/BEUTEORDNUNG.de.md 6): small rooms the floor offers as treasure rooms ----------
const PRICE_TEXT = {
  opferstein: 'Der Stein will Blut, ein Opfer nach dem anderen.\nJedes kostet zwei Treffer deines Lebens und gibt mehr als das letzte:\nGold, ein Stück, ein besseres Stück, zuletzt ein Stück und ein Lebensherz.\nHör auf, wann du willst. Der Stein tötet nie, aber der Wächter wartet.',
  pakt: 'Drei Altäre, drei Angebote. Nur einen Pakt gewährt die Hölle.\nDer Preis: zwei Treffer deiner Lebensgrenze, für immer.\nLinks ein episches Stück deiner Klasse, in der Mitte zwei Dämonensegen,\nrechts drei Runen und ein Aufwertungsstein. Wer nicht zahlen will, geht.',
  grube: 'Die Grube gibt, was du ihr abringst.\nRuf eine Welle nach der anderen, bis zu fünf.\nNach jeder Welle steigt der Schatz eine Stufe. Nimm ihn, wann du willst.',
};
function priceRoom(id, title, make) {
  const b = new Room('h_' + id, title, 'treasure', 'e');
  b.rect(1, 1, R.SW - 2, R.SH - 2, FLOOR);
  make(b);
  b.findPorts(); b.clearPorts();
  b.wallDress(R.WALLS.boss);
  b.snow(0.05);
  b.start([b.w / 2, b.h - 3]);
  check(b);
  return b;
}
function specials(errors) {
  const out = [];
  const tries = [
    () => priceRoom('opferstein', 'Preisraum: Opferstein', b => { b.piece('hell_sacrifice', 6, 4, { group: 'P' }); b.tablet(3, 2, PRICE_TEXT.opferstein); b.prop('brazier_demon', 9.5, 2.8, [56, 28]); }),
    () => priceRoom('teufelspakt', 'Preisraum: Teufelspakt', b => { for (const [k, x] of [[0, 3], [1, 6], [2, 9]]) b.piece('hell_pact', x, 3, { group: 'P', offer: k }); b.tablet(6, 6, PRICE_TEXT.pakt); }),
    () => priceRoom('opfergrube', 'Preisraum: Opfergrube', b => { b.piece('hell_pit_altar', 6, 3, { group: 'P' }); b.tablet(2, 2, PRICE_TEXT.grube); b.decal('rune_big', 6.5, 5.5); }),
  ];
  for (const f of tries) { try { out.push(f()); } catch (e) { errors.push(e.message); } }
  return out;
}

module.exports = { puzzles, specials, solveSwitches, frame, FRAME_OF };

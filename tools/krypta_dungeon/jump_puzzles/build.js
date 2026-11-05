// Builds the Krypta's jump puzzle rooms from the drawn plans in ./rooms/*.js and checks each with
// solver.js. It writes ONLY the rooms named on the command line, and only with --write:
//
//   node tools/krypta_dungeon/jump_puzzles/build.js                     (check every plan, write nothing)
//   node tools/krypta_dungeon/jump_puzzles/build.js k_sprung_kammern --write
//
// The files are the Weltbauer's (docs/WELTBAUER.de.md): once written, a room is the user's to change in
// the Weltbauer. Running this again over a named room overwrites those changes, so name rooms with care.
//
// A plan: { file, title, ports: [[side, x, y, use?]], map: [rows], marks: {char: spec | [spec]},
// mirror_of?: plan file, texts?: {from: to} for the mirrored tablets }.
// Map: '#' wall, '.' floor, '~' Moder, 'o' pit, '=' bridge; any other char is a mark on floor (or on
// spec.on). Specs: {pad: dir, to: mark | n: cells, wake}, {plate: group, order, enemies}, {chest: loot
// type, amount, id, mimic, mimic_mob, enemies}, {tablet: text}, {lever: group}, {brazier: group},
// {key: id}, {spikes: phase}, {gate: group, dir, lock, style}, {secret: group, dir}, {prop: asset, ...},
// {heart}, {gem}, {start}, {land} (a pad's target, plain floor), {deco: false} (keep the cell bare).

'use strict';
const fs = require('fs');
const path = require('path');
const solver = require('./solver');

const ROOT = path.resolve(__dirname, '../../..');
const DIR = path.join(ROOT, 'assets/data/world_rooms/krypta');
const C = 96;
const TERRAIN = { '#': '0', '.': '1', '~': '2', '=': '3', 'o': '4' };
const STEP = { n: [0, -1], e: [1, 0], s: [0, 1], w: [-1, 0] };

function rng(seedText) {
  let h = 2166136261;
  for (const ch of seedText) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return () => { h = Math.imul(h ^ (h >>> 15), 2246822507); h = Math.imul(h ^ (h >>> 13), 3266489909); h ^= h >>> 16; return (h >>> 0) / 4294967296; };
}

/** Where each mark char stands: char -> [[x, y]]. */
function marksOf(plan) {
  const out = {};
  plan.map.forEach((row, y) => [...row].forEach((ch, x) => { if (!TERRAIN[ch]) (out[ch] = out[ch] || []).push([x, y]); }));
  return out;
}

const specsOf = (plan, ch) => { const s = plan.marks[ch]; if (s === undefined) throw new Error(`${plan.file}: Zeichen '${ch}' hat keine Angabe`); return Array.isArray(s) ? s : [s]; };

/** A plan to the Weltbauer's room record. */
function build(plan) {
  const H = plan.map.length, W = plan.map[0].length;
  plan.map.forEach((r, i) => { if (r.length !== W) throw new Error(`${plan.file}: Zeile ${i} hat ${r.length} statt ${W} Zeichen`); });
  const where = marksOf(plan);
  const cells = plan.map.map((row) => [...row].map((ch) => {
    if (TERRAIN[ch]) return TERRAIN[ch];
    const sp = specsOf(plan, ch);
    const on = sp.find((s) => s.on)?.on || (sp.some((s) => s.gate || s.secret) ? '#' : '.');
    return TERRAIN[on];
  }).join(''));
  const objects = [];
  const center = (x, y, low = 0.5) => ({ x: (x + 0.5) * C, y: (y + low) * C });
  const bare = new Set();
  for (const ch of Object.keys(where)) {
    for (const [x, y] of where[ch]) {
      bare.add(x + ',' + y);
      for (const s of specsOf(plan, ch)) {
        if (s.pad) {
          let n = s.n;
          if (s.to) {
            const t = where[s.to];
            if (!t) throw new Error(`${plan.file}: Ziel '${s.to}' fehlt`);
            const [dx, dy] = STEP[s.pad];
            const hit = t.find(([tx, ty]) => (dx ? ty === y && Math.sign(tx - x) === dx : tx === x && Math.sign(ty - y) === dy));
            if (!hit) throw new Error(`${plan.file}: Platte '${ch}' bei ${x},${y} sieht '${s.to}' nicht in Richtung ${s.pad}`);
            n = Math.abs(hit[0] - x) + Math.abs(hit[1] - y);
          }
          if (!(n >= 1 && n <= 16)) throw new Error(`${plan.file}: Platte '${ch}' bei ${x},${y} wirft ${n} Felder`);
          const o = { kind: 'launch', dir: s.pad, cells: n, ...center(x, y) };
          if (s.wake) o.wake = s.wake;
          objects.push(o);
        } else if (s.plate) {
          const o = { kind: 'plate', group: s.plate, order: s.order || 0, ...center(x, y) };
          if (s.enemies) o.enemies = s.enemies;
          objects.push(o);
        } else if (s.chest) {
          const loot = { type: s.chest };
          if (s.amount) loot.amount = s.amount;
          if (s.id) loot.id = s.id;
          const o = { kind: 'chest', loot, ...center(x, y, 0.75) };
          if (s.mimic) o.mimic = s.mimic;
          if (s.mimic_mob) o.mimic_mob = s.mimic_mob;
          if (s.enemies) o.enemies = s.enemies;
          objects.push(o);
        } else if (s.tablet !== undefined) objects.push({ kind: 'tablet', text: s.tablet, ...center(x, y, 0.75) });
        else if (s.lever) objects.push({ kind: 'lever', group: s.lever, ...center(x, y, 0.3) });
        else if (s.brazier) objects.push({ kind: 'brazier', group: s.brazier, ...center(x, y, 0.75) });
        else if (s.key) objects.push({ kind: 'key', key: s.key, ...center(x, y) });
        else if (s.spikes !== undefined) objects.push({ kind: 'spikes', phase: s.spikes, ...center(x, y) });
        else if (s.gate) objects.push({ kind: 'gate', dir: s.dir, group: s.gate, lock: s.lock || '', ...(s.style ? { style: s.style } : {}), x: x * C, y: y * C });
        else if (s.secret) objects.push({ kind: 'secret', dir: s.dir, group: s.secret, x: x * C, y: y * C });
        else if (s.prop) objects.push(prop(s.prop, x, y, s));
        else if (s.heart) objects.push({ kind: 'heart', ...center(x, y) });
        else if (s.gem) objects.push({ kind: 'gem', ...center(x, y) });
        else if (s.start) objects.push({ kind: 'start', ...center(x, y, 0.75) });
        else if (s.enemy) objects.push({ kind: 'enemy', mob: s.enemy, ...center(x, y, 0.75) });
      }
    }
  }
  const room = {
    schema_version: 1, id: plan.file, title: plan.title, world: 'krypta', role: 'jump', in_floors: true,
    slots: plan.slots, width: W, height: H, cells, tiles: {}, areas: {},
    ports: plan.ports.map(([side, x, y, use]) => (use ? { side, cell: [x, y], use } : { side, cell: [x, y] })),
    auto_mobs: 0, objects: [...decorate(plan, cells, bare, objects), ...objects], kind_label: 'Sprungrätsel', spawn_mode: 'manual',
  };
  return room;
}

const PROP_LOOK = {
  // foot sizes as the Weltbauer stores them (world_editor.json asset defaults)
  statue_angel: [60, 28], statue_monk: [60, 28], skull_obelisk: [60, 28], gargoyle: [73, 34], obelisk: [56, 24],
  brazier_low: [57, 26], brazier_floor: [60, 28], brazier_pillar: [50, 26], candelabra: [40, 20], torch_pillar: [40, 22],
  rune_pillar_a: [44, 24], rune_pillar_d: [44, 24], skull_pile: [76, 26], skull_heap: [90, 34], coal_skulls: [80, 28],
  urn_a: [29, 16], urn_b: [29, 16], crate_a: [48, 22], barrel_a: [40, 20], bench: [90, 24], cage_small: [60, 28],
  spire_big: [60, 28], spire_big_b: [56, 28], boulders: [80, 30], moss_ruin: [70, 28], altar: [90, 34],
};

/** A placed picture: blocking pieces need their foot; flat ones lie on the floor. */
function prop(asset, x, y, s = {}) {
  const flat = s.flat || false;
  const o = { kind: 'prop', asset, x: (x + 0.5) * C + (s.dx || 0), y: (y + (flat ? 0.5 : 0.8)) * C + (s.dy || 0), flip: !!s.flip,
    layer: s.layer || (flat ? 'floor' : 'normal'), block: s.block !== undefined ? s.block : !flat, scale: s.scale || 1, foot: PROP_LOOK[asset] || [60, 30] };
  for (const k of ['loot', 'enemies', 'opens', 'scale_w', 'scale_h', 'decal']) if (s[k] !== undefined) o[k] = s[k];
  return o;
}

const WALL_DECOR = ['wall_torch_hook', 'chain_swag', 'shackle_skull', 'wall_torch_hook', 'wall_skull_a', 'chain_long', 'wall_torch_hook', 'cage_hang', 'wall_skull_b', 'banner_2'];
const SCATTER = ['bone_a', 'bone_b', 'bone_c', 'bone_d', 'bone_e', 'bone_f', 'bone_g', 'bones_scatter', 'rubble', 'coal'];
const DECALS = ['moss_a', 'moss_b', 'moss_c', 'blood_a', 'blood_c', 'grate_a', 'rune_small'];

/** The room's dressing: things on the north walls, bones and moss on the floor, never on a mark. */
function decorate(plan, cells, bare, objects) {
  const r = rng(plan.file);
  const H = cells.length, W = cells[0].length;
  const at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? '0' : cells[y][x]);
  const out = [];
  const gateCells = new Set();
  for (const o of objects) if (o.kind === 'gate' || o.kind === 'secret') {
    const a = [Math.floor(o.x / C), Math.floor(o.y / C)];
    for (const c of [a, o.dir === 'h' ? [a[0], a[1] + 1] : [a[0] + 1, a[1]]]) for (let dx = -1; dx <= 1; dx++) gateCells.add((c[0] + dx) + ',' + c[1]), gateCells.add(c[0] + ',' + (c[1] + 1));
  }
  const portCells = new Set();
  for (const [side, x, y] of plan.ports) for (let d = -1; d <= 2; d++) portCells.add(side === 'north' || side === 'south' ? (x + d) + ',' + (y + (side === 'north' ? 1 : -1)) : x + ',' + (y + d));
  let run = 0;
  for (let y = 1; y < H; y++) {
    run = 0;
    for (let x = 1; x < W - 1; x++) {
      const face = at(x, y - 1) === '0' && at(x, y) !== '0' && at(x, y) !== '4';
      if (!face || gateCells.has(x + ',' + (y - 1)) || gateCells.has(x + ',' + y) || portCells.has(x + ',' + y)) { run = 0; continue; }
      run++;
      if (run % 3 === 2 && r() < 0.85) {
        const asset = WALL_DECOR[Math.floor(r() * WALL_DECOR.length)];
        out.push({ kind: 'prop', asset, x: (x + 0.5) * C, y: y * C + 6, flip: r() < 0.5, layer: 'floor', block: false, scale: 1, foot: [60, 30], wall_decor: true });
      }
    }
  }
  for (let y = 1; y < H - 1; y++) {
    for (let x = 1; x < W - 1; x++) {
      if (bare.has(x + ',' + y) || at(x, y) !== '1' || plan.bare?.(x, y)) continue;
      const v = r();
      if (v < 0.075) {
        out.push({ kind: 'prop', asset: SCATTER[Math.floor(r() * SCATTER.length)], x: Math.round((x + 0.2 + r() * 0.6) * C * 10) / 10, y: Math.round((y + 0.3 + r() * 0.5) * C * 10) / 10, flip: r() < 0.5, layer: 'floor', block: false, scale: 1, foot: [60, 30] });
      } else if (v < 0.11) {
        out.push({ kind: 'prop', asset: DECALS[Math.floor(r() * DECALS.length)], x: (x + 0.5) * C, y: (y + 0.95) * C, flip: false, layer: 'floor', block: false, scale: 1, foot: [60, 30], decal: { dy: 45, w: 0, h: 0, a: 0.95 } });
      }
    }
  }
  return out;
}

/** The mirror image of a plan, left to right: pads turn round, gates keep their two cells. */
function mirrored(plan, base) {
  const W = base.map[0].length;
  const flipDir = { e: 'w', w: 'e', n: 'n', s: 's' };
  const marks = {};
  const shift = {};
  for (const [ch, sp] of Object.entries(base.marks)) {
    const list = (Array.isArray(sp) ? sp : [sp]).map((s) => {
      const t = { ...s };
      if (t.pad) t.pad = flipDir[t.pad];
      if (t.flip !== undefined || t.prop) t.flip = !t.flip;
      if (t.tablet && plan.texts) for (const [a, b] of Object.entries(plan.texts)) t.tablet = t.tablet.split(a).join(b);
      if ((t.gate || t.secret) && t.dir === 'v') shift[ch] = true;
      return t;
    });
    marks[ch] = Array.isArray(sp) ? list : list[0];
  }
  let map = base.map.map((row) => [...row].reverse().join(''));
  // a gate across a wall above or below stands on its left cell: one to the left after the turn
  map = map.map((row, y) => {
    const a = [...row];
    for (let x = 0; x < W; x++) if (shift[a[x]] && x > 0 && base.map[y][W - 1 - x] === a[x]) { const ch = a[x]; a[x] = '#'; a[x - 1] = ch; }
    return a.join('');
  });
  const ports = base.ports.map(([side, x, y, use]) => side === 'east' ? ['west', W - 1 - x, y, use] : side === 'west' ? ['east', W - 1 - x, y, use] : [side, W - 2 - x, y, use]);
  return { ...base, ...plan, map, marks, ports, slots: plan.slots || base.slots, bare: undefined };
}

function ascii(room) {
  const g = room.cells.map((r) => [...r].map((c) => ({ 0: '#', 1: '.', 2: '~', 3: '=', 4: 'o' })[c]));
  const arrows = { n: '^', s: 'v', e: '>', w: '<' };
  for (const o of room.objects) {
    if (o.kind === 'prop' && (o.wall_decor || !o.block)) continue;
    const x = Math.floor(o.x / C), y = Math.floor((o.y - 1) / C);
    const ch = { launch: arrows[o.dir], plate: o.group, chest: o.loot && o.loot.type === 'hoard' ? '$' : 'C', tablet: 'T', lever: 'L', brazier: 'B', key: 'K', spikes: 'x', gate: 'G', secret: 'S', start: '@', prop: 'p', enemy: 'E', heart: 'h', gem: 'g' }[o.kind] || '?';
    if (g[y] && g[y][x] !== undefined) g[y][x] = ch;
  }
  return g.map((r, i) => String(i).padStart(2) + ' ' + r.join('')).join('\n');
}

function plans() {
  const dir = path.join(__dirname, 'rooms');
  const all = {};
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.js')).sort()) {
    const p = require(path.join(dir, f));
    for (const plan of Array.isArray(p) ? p : [p]) all[plan.file] = plan;
  }
  for (const plan of Object.values(all)) if (plan.mirror_of) Object.assign(plan, mirrored(plan, all[plan.mirror_of]));
  return all;
}

module.exports = { build, plans, ascii, decorate, prop, rng };

if (require.main === module) {
  const args = process.argv.slice(2);
  const write = args.includes('--write');
  const names = args.filter((a) => !a.startsWith('--'));
  const all = plans();
  let bad = 0;
  const steps = {};
  for (const plan of Object.values(all)) {
    if (names.length && !names.includes(plan.file)) continue;
    const room = build(plan);
    const report = solver.analyze(room);
    const hoard = report.chests.find((c) => c.loot === 'hoard' && c.reached);
    if (hoard) steps[plan.file] = { chest: hoard.at.split(',').map(Number), steps: hoard.steps };
    if (args.includes('--map')) console.log(ascii(room));
    console.log(solver.print(report));
    bad += report.problems.length;
    if (write && names.includes(plan.file)) {
      const file = path.join(DIR, plan.file + '.json');
      if (fs.existsSync(file)) fs.copyFileSync(file, file + '.bak');
      fs.writeFileSync(file, JSON.stringify(room, null, '	') + '\n');
      console.log('geschrieben: ' + path.relative(ROOT, file));
    }
  }
  if (write && !names.length) console.log('Nichts geschrieben: --write braucht Raumnamen.');
  // --steps=<file>: the Schatz ways as JSON for the in-game replay (replay_jump_puzzles.gd)
  const out = args.find((a) => a.startsWith('--steps='));
  if (out) fs.writeFileSync(out.slice(8), JSON.stringify(steps, null, 1));
  process.exit(bad ? 1 : 0);
}

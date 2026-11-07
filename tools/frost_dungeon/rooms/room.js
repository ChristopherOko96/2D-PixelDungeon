// A Frostgruft room file under construction: the Krypta builder's room (tools/krypta_dungeon/
// build_room_library.js) for world "frost", with the frost set's pictures and the puzzle pieces of
// src/world_kit/frost_puzzles.gd. Cells: '0' wall, '1' floor, '2' glaze ice (liquid), '3' bridge, '4' crevasse.
'use strict';
const fs = require('fs');
const path = require('path');
const S = require('../puzzles/solvers.js');

const ROOT = path.resolve(__dirname, '..', '..', '..');
const SIZES = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets', 'sprites', 'frost_hd', 'manifest.json'), 'utf8'));
const C = 96;
const SW = 14, SH = 11, GX = 3, GY = 3, PX = SW + GX, PY = SH + GY;
const WALL = '0', FLOOR = '1', LIQUID = '2', BRIDGE = '3', PIT = '4';
const SHAPES = {
  b2: [[0, 0], [1, 0]], h2: [[0, 0], [0, 1]], b3: [[0, 0], [1, 0], [2, 0]], h3: [[0, 0], [0, 1], [0, 2]],
  la: [[0, 0], [1, 0], [0, 1]], lb: [[0, 0], [1, 0], [1, 1]], lc: [[0, 0], [0, 1], [1, 1]], ld: [[1, 0], [0, 1], [1, 1]],
  q: [[0, 0], [1, 0], [0, 1], [1, 1]], e: [[0, 0]],
};
const MIRROR = { la: 'lb', lc: 'ld' };
/** The ground painted on a firm snowfield of an ice lake (map letter '_'). */
const FIRM_GROUND = 'floor_00';
// what stands on a letter of a map: picture, foot [width, depth]
const GLYPH = {
  P: ['rune_pillar_a', [50, 28]], Q: ['rune_pillar_c', [50, 28]], O: ['obelisk', [46, 28]], D: ['rune_pillar_d', [40, 24]],
  A: ['statue_angel', [50, 26]], M: ['statue_monk', [40, 24]], G: ['gargoyle', [66, 30]],
  W: ['brazier_blue', [56, 28]], b: ['bowl_blue', [56, 28]], B: ['brazier_pillar', [56, 30]], u: ['torch_pillar_blue', [40, 26]], t: ['torch_pillar', [40, 26]], i: ['candelabra', [26, 18]],
  g: ['glacier_a', [80, 32]], h: ['glacier_b', [70, 30]], N: ['snowman', [52, 26]], F: ['spire_big', [60, 28]], f: ['spire_mid', [44, 24]], j: ['spire_t', [50, 26]],
  k: ['boulders', [60, 28]], X: ['rocks_a', [60, 28]], R: ['rocks_b', [56, 26]], n: ['moss_ruin', [66, 30]],
  S: ['skull_heap', [90, 34]], s: ['skull_pile', [76, 26]], z: ['cage_small', [46, 24]], J: ['spike_block', [70, 30]],
  T: ['table_a', [104, 30]], U: ['table_b', [110, 30]], V: ['table_c', [140, 30]], E: ['bench', [120, 30]], L: ['crate_pile', [80, 34]], Z: ['sacks_b', [90, 26]], Y: ['sacks_a', [64, 26]],
  a: ['altar', [110, 50]], H: ['hanging_brazier', [80, 34]],
};
const WALLS = {
  ice: ['wall_torch_blue', 'wall_torch_blue', 'chain_swag', 'banner_1', 'banner_3', 'wall_v_glow_blue'],
  guard: ['wall_torch_blue', 'wall_torch_hook', 'banner_2', 'banner_5', 'chain_hook', 'wall_brazier'],
  hall: ['banner_1', 'banner_a', 'banner_b', 'wall_torch_blue', 'wall_torch_hook', 'icon_scroll'],
  chains: ['chain_swag', 'chain_swag_b', 'shackle_a', 'cage_hang', 'wall_torch_blue', 'chain_hang'],
  bones: ['wall_skull_a', 'wall_skull_b', 'shackle_skull', 'wall_torch_blue', 'chain_long'],
  boss: ['wall_torch_blue', 'banner_2', 'chain_swag', 'wall_skull_a', 'icon_demon_big', 'wall_brazier'],
  quiet: ['wall_torch_blue', 'chain_long', 'wall_v_glow_blue'],
};
const SCATTER = {
  ice: ['glacier_a', 'glacier_b', 'spire_mid', 'boulders', 'brazier_blue'],
  guard: ['crate_pile', 'sacks_a', 'sacks_b', 'table_a', 'brazier_blue', 'snowman'],
  hall: ['candelabra', 'statue_monk', 'torch_pillar_blue', 'bowl_blue'],
  chains: ['cage_small', 'spike_block', 'skull_pile', 'brazier_low'],
  bones: ['skull_heap', 'skull_pile', 'rocks_a', 'glacier_b', 'bowl_blue'],
  quiet: ['glacier_b', 'rocks_a', 'boulders'],
};
const BONES = ['bone_a', 'bone_b', 'bone_c', 'bone_d', 'bones_scatter', 'rubble'];
const BREAK = ['barrel_a', 'barrel_b', 'barrel_c', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'crate_a', 'crate_b', 'crate_c'];
const SNOW = ['snow_a', 'snow_b', 'snow_c', 'snow_d'];
const r1 = v => Math.round(v * 10) / 10;

class Room {
  constructor(id, title, role, shape) {
    this.id = id; this.title = title; this.role = role; this.shape = shape;
    this.slots = SHAPES[shape];
    this.w = Math.max(...this.slots.map(s => s[0] + 1)) * PX - GX;
    this.h = Math.max(...this.slots.map(s => s[1] + 1)) * PY - GY;
    this.cells = Array.from({ length: this.h }, () => Array(this.w).fill(WALL));
    this.objects = []; this.ports = []; this.rnd = S.random(id); this.extra = {};
    this.fixedPorts = false;
  }
  has(c, r) { return this.slots.some(s => s[0] === c && s[1] === r); }
  at(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h ? this.cells[y][x] : WALL; }
  set(x, y, v) { if (x > 0 && y > 0 && x < this.w - 1 && y < this.h - 1) this.cells[y][x] = v; }
  rect(x, y, w, h, v) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.set(i, j, v); }
  prop(name, cx, cy, foot, o = {}) {
    this.objects.push({ kind: 'prop', asset: name, x: r1(cx * C), y: r1(cy * C), flip: !!o.flip, layer: o.low ? 'floor' : 'normal', block: !!foot, scale: o.scale || 1, foot: foot || [60, 30] });
  }
  glyph(ch, x, y, o = {}) { const g = GLYPH[ch]; this.prop(g[0], x + 0.5, y + 0.86, g[1], Object.assign({ flip: this.rnd() < 0.5 }, o)); }
  wall(name, cx, row, o = {}) {
    this.objects.push({ kind: 'prop', asset: name, x: r1(cx * C), y: row * C + (o.dy === undefined ? 6 : o.dy), flip: !!o.flip, layer: 'floor', block: false, scale: 1, foot: [60, 30], wall_decor: true });
  }
  decal(name, cx, cy, o = {}) {
    const half = (SIZES[name] ? SIZES[name].h : 48) / 2;
    this.objects.push({ kind: 'prop', asset: name, x: r1(cx * C), y: Math.round(cy * C + half), flip: false, layer: 'floor', block: false, scale: 1, foot: [60, 30], decal: { dy: half, w: o.w || 0, h: o.h || 0, a: o.a === undefined ? 1 : o.a } });
  }
  thing(kind, cx, cy, extra = {}) { this.objects.push(Object.assign({ kind, x: r1(cx * C), y: r1(cy * C) }, extra)); }
  /** A Frostgruft puzzle piece in its cell (frost_puzzles.gd, one cell each). */
  piece(kind, x, y, extra = {}) { this.thing(kind, x + 0.5, y + 0.5, extra); }
  raw(type, cx, cy, ent = {}) { this.objects.push({ kind: 'raw', x: r1(cx * C), y: r1(cy * C), ent: Object.assign({ type }, ent) }); }
  crate(x, y) {
    const look = BREAK[Math.floor(this.rnd() * BREAK.length)];
    this.raw('crate', x + 0.5, y + 0.85, { look, hp: look.startsWith('crate') ? 2 : 1, drop: 'random' });
  }
  chest(x, y, loot = { type: 'auto' }) { this.thing('chest', x + 0.5, y + 0.85, { loot }); }
  // `tier` is given on the old scale 1-3; the Beuteordnung's five tiers (docs/BEUTEORDNUNG.de.md 3) are one higher
  hoard(x, y, tier) { this.thing('chest', x + 0.5, y + 0.85, { loot: { type: 'hoard', tier: Math.min(5, tier + 1) }, mimic: 'no' }); }
  tablet(x, y, text) { this.thing('tablet', x + 0.5, y + 0.85, { text }); }
  /** A gate over wall cells (x, y) and the next one: dir 'v' in a wall running sideways, 'h' in one running up and down. */
  gate(x, y, dir, group, extra = {}) { this.objects.push(Object.assign({ kind: 'gate', x: x * C, y: y * C, dir, group, lock: '' }, extra)); }
  port(side, x, y, use) { const p = { side, cell: [x, y] }; if (use) p.use = use; this.ports.push(p); this.fixedPorts = true; }

  /** Draws a map: its letters at cell (ox + column, oy + row). */
  draw(m) {
    const ox = m.at[0], oy = m.at[1];
    m.map.forEach((row, j) => {
      for (let i = 0; i < row.length; i++) {
        const ch = row[i], x = ox + i, y = oy + j;
        if (ch === ' ') continue;
        this.set(x, y, ch === '~' ? LIQUID : ch === '=' ? BRIDGE : ch === 'o' ? PIT : FLOOR);
        // a firm snowfield in an ice lake: painted ground (an area brush) where nobody slides
        if (ch === '_') { this.extra.areas = this.extra.areas || {}; this.extra.areas[x + ',' + y] = m.firm || FIRM_GROUND; continue; }
        if (GLYPH[ch]) this.glyph(ch, x, y);
        else if (ch === 'c') this.crate(x, y);
        else if (ch === 'C') this.chest(x, y);
        else if (ch === 'p') this.thing('plate', x + 0.5, y + 0.5, { group: 'seq', order: 0 });
        else if (ch === 'x') this.thing('spikes', x + 0.5, y + 0.5, { phase: (x + y) % 2 });
        else if (ch === 'v') this.thing('vent', x + 0.5, y + 0.5, { offset: r1(this.rnd() * 3) });
        else if (ch === '$') this.thing('gem', x + 0.5, y + 0.85);
        else if (ch === '+') this.thing('heart', x + 0.5, y + 0.85);
        else if (ch === '@') this.thing('start', x + 0.5, y + 0.7);
        else if (ch === '%') this.raw('vault', x + 0.5, y + 0.85, { tier: 4 });
        else if (ch === '&') this.thing('portal', x + 0.5, y + 0.85);
        else if (ch === '#') this.raw('stairs', x + 0.5, y + 0.85, {});
        else if (ch === 'w') this.thing('well', x + 0.5, y + 0.85);
      }
    });
    for (const d of m.decals || []) this.decal(d[0], ox + d[1], oy + d[2], { w: d[3], h: d[4], a: d[5] });
    for (const w of m.walls || []) this.wall(w[0], ox + w[1], oy + w[2], { dy: w[3], flip: w[4] });
  }
  /** The door spots from the shape: on each open side of each slot the two wall cells nearest its middle. */
  findPorts() {
    if (this.fixedPorts) return;
    this.ports = [];
    const pair = (a, b) => (this.at(a[0], a[1]) !== WALL) && (this.at(b[0], b[1]) !== WALL);
    const near = (lo, hi, mid) => { const out = []; for (let k = lo; k < hi; k++) out.push(k); return out.sort((p, q) => Math.abs(p - mid) - Math.abs(q - mid)); };
    for (const [c, r] of this.slots) {
      const x0 = c * PX, y0 = r * PY;
      const xs = near(x0 + 1, x0 + SW - 2, x0 + 6), ys = near(y0 + 1, y0 + SH - 2, y0 + 5);
      const add = (side, cell) => this.ports.push({ side, cell });
      if (!this.has(c, r - 1)) { let done = false; for (const x of xs) { for (let y = y0 + 1; y < y0 + SH && !done; y++) if (pair([x, y], [x + 1, y]) && this.at(x, y - 1) === WALL && this.at(x + 1, y - 1) === WALL) { add('north', [x, y - 1]); done = true; } if (done) break; } }
      if (!this.has(c, r + 1)) { let done = false; for (const x of xs) { for (let y = Math.min(this.h - 2, y0 + SH - 2 + GY); y >= y0 && !done; y--) if (pair([x, y], [x + 1, y]) && this.at(x, y + 1) === WALL && this.at(x + 1, y + 1) === WALL && Math.floor((y + 1) / PY) === r) { add('south', [x, y + 1]); done = true; } if (done) break; } }
      if (!this.has(c - 1, r)) { let done = false; for (const y of ys) { for (let x = x0 + 1; x < x0 + SW && !done; x++) if (pair([x, y], [x, y + 1]) && this.at(x - 1, y) === WALL && this.at(x - 1, y + 1) === WALL) { add('west', [x - 1, y]); done = true; } if (done) break; } }
      if (!this.has(c + 1, r)) { let done = false; for (const y of ys) { for (let x = Math.min(this.w - 2, x0 + SW - 2 + GX); x >= x0 && !done; x--) if (pair([x, y], [x, y + 1]) && this.at(x + 1, y) === WALL && this.at(x + 1, y + 1) === WALL && Math.floor((x + 1) / PX) === c) { add('east', [x + 1, y]); done = true; } if (done) break; } }
    }
    const want = this.slots.reduce((n, [c, r]) => n + [[0, -1], [1, 0], [0, 1], [-1, 0]].filter(d => !this.has(c + d[0], r + d[1])).length, 0);
    if (this.ports.length !== want) throw new Error(`${this.id}: found ${this.ports.length} of ${want} door spots: ${JSON.stringify(this.ports)}`);
  }
  inner(p) { return p.side === 'north' ? [p.cell[0], p.cell[1] + 1] : p.side === 'south' ? [p.cell[0], p.cell[1] - 1] : p.side === 'west' ? [p.cell[0] + 1, p.cell[1]] : [p.cell[0] - 1, p.cell[1]]; }
  /** Keeps every door's way in clear: floor two wide and two deep, nothing standing on it. */
  clearPorts() {
    for (const p of this.ports) {
      const [x, y] = p.cell;
      for (let k = 1; k <= 2; k++) for (let t = 0; t < 2; t++) {
        const c = p.side === 'north' ? [x + t, y + k] : p.side === 'south' ? [x + t, y - k] : p.side === 'west' ? [x + k, y + t] : [x - k, y + t];
        if (this.at(c[0], c[1]) !== BRIDGE) this.set(c[0], c[1], FLOOR);
        this.objects = this.objects.filter(o => !(Math.floor(o.x / C) === c[0] && Math.floor((o.y - 8) / C) === c[1] && (o.block || ['raw', 'chest', 'spikes', 'vent', 'tablet'].includes(o.kind) || o.kind.startsWith('frost'))));
      }
    }
  }
  nearPort(x, y, d) {
    return this.ports.some(p => {
      const side = p.side === 'east' || p.side === 'west';
      return Math.hypot(x + 0.5 - (side ? p.cell[0] + 0.5 : p.cell[0] + 1), y + 0.5 - (side ? p.cell[1] + 1 : p.cell[1] + 0.5)) < d;
    });
  }
  /** Pictures on the north walls, kept off door spots and gates. */
  wallDress(names, keepOff = []) {
    for (let y = 1; y < this.h - 1; y++) {
      let x = 1;
      while (x < this.w - 1) {
        if (this.at(x, y) !== WALL && this.at(x, y - 1) === WALL) {
          let e = x;
          while (this.at(e + 1, y) !== WALL && this.at(e + 1, y - 1) === WALL) e++;
          for (let k = x + 1.5; k < e; k += 2.8) {
            if (this.nearPort(k, y, 3.1) || keepOff.some(c => Math.hypot(c[0] - k, c[1] - y) < 2.5)) continue;
            this.wall(names[Math.floor(this.rnd() * names.length)], k, y, { flip: this.rnd() < 0.5 });
          }
          x = e + 1;
        } else x++;
      }
    }
  }
  /** Loose bones and stones on the floor, kept out of `zone` (a Set of cell keys). */
  bones(share, zone) {
    const free = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) if (this.at(x, y) === FLOOR && !(zone && zone.has(S.key(x, y)))) free.push([x, y]);
    const n = Math.floor(free.length * share);
    for (let k = 0; k < n; k++) {
      const c = free[Math.floor(this.rnd() * free.length)];
      this.prop(BONES[Math.floor(this.rnd() * BONES.length)], c[0] + 0.2 + this.rnd() * 0.6, c[1] + 0.4 + this.rnd() * 0.5, null, { low: true, flip: this.rnd() < 0.5 });
    }
  }
  /** Snow lying on the floor: soft patches, more along the walls. */
  snow(share, zone) {
    const spots = [];
    for (let y = 1; y < this.h - 1; y++) for (let x = 1; x < this.w - 1; x++) {
      if (this.at(x, y) !== FLOOR || (zone && zone.has(S.key(x, y)))) continue;
      const edge = this.at(x - 1, y) === WALL || this.at(x + 1, y) === WALL || this.at(x, y - 1) === WALL || this.at(x, y + 1) === WALL;
      if (this.rnd() < share * (edge ? 2.2 : 0.7)) spots.push([x, y]);
    }
    for (const [x, y] of spots) this.decal(SNOW[Math.floor(this.rnd() * SNOW.length)], x + 0.5, y + 0.5, { a: 0.92 });
  }
  /** Fills what stayed empty along the walls with the set's things, never near a door; checks each one. */
  scatter(theme, zone, every = 3.3) {
    const set = SCATTER[theme] || SCATTER.ice;
    const taken = this.objects.filter(o => o.block || ['raw', 'chest', 'plate', 'spikes', 'vent', 'tablet', 'gate'].includes(o.kind) || o.kind.startsWith('frost'));
    const edge = [];
    for (let y = 1; y < this.h - 1; y++) for (let x = 1; x < this.w - 1; x++) {
      if (this.at(x, y) !== FLOOR || this.nearPort(x, y, 3.4) || (zone && zone.has(S.key(x, y)))) continue;
      if (this.at(x - 1, y) === WALL || this.at(x + 1, y) === WALL || this.at(x, y - 1) === WALL || this.at(x, y + 1) === WALL) edge.push([x, y]);
    }
    for (let k = edge.length - 1; k > 0; k--) { const j = Math.floor(this.rnd() * (k + 1)); [edge[k], edge[j]] = [edge[j], edge[k]]; }
    const far = (x, y, d) => !taken.some(o => Math.hypot(o.x / C - x - 0.5, o.y / C - y - 0.8) < d);
    for (const [x, y] of edge) {
      if (!far(x, y, every)) continue;
      const name = set[Math.floor(this.rnd() * set.length)];
      const g = Object.values(GLYPH).find(v => v[0] === name);
      this.prop(name, x + 0.5, y + 0.86, g ? g[1] : [60, 28], { flip: this.rnd() < 0.5 });
      try { check(this); } catch (e) { this.objects.pop(); continue; }
      taken.push(this.objects[this.objects.length - 1]);
    }
  }
  start(at) {
    const taken = new Set();
    for (const o of this.objects) if (o.block || ['raw', 'chest', 'plate', 'spikes', 'vent', 'tablet'].includes(o.kind) || o.kind.startsWith('frost') || ['thin_ice', 'ice_block', 'snowball', 'prism', 'crystal'].includes(o.kind)) taken.add(Math.floor(o.x / C) + ',' + Math.floor((o.y - 8) / C));
    const tx = at ? at[0] : this.w / 2, ty = at ? at[1] : this.h / 2;
    const spots = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.at(x, y) !== FLOOR || taken.has(x + ',' + y)) continue;
      spots.push([x, y, Math.hypot(x + 0.5 - tx, y + 0.5 - ty)]);
    }
    spots.sort((p, q) => p[2] - q[2]);
    for (const [x, y] of spots) {
      this.thing('start', x + 0.5, y + 0.7);
      try { check(this); return; } catch (e) { this.objects.pop(); }
    }
    throw new Error(this.id + ': no place for the start');
  }
  /** The same room in a mirror, left to right: another shape of slots. */
  mirrored(id, shape) {
    const b = new Room(id, this.title, this.role, shape);
    b.extra = JSON.parse(JSON.stringify(this.extra));
    if (b.extra.areas) b.extra.areas = Object.fromEntries(Object.entries(b.extra.areas).map(([k, v]) => { const [x, y] = k.split(',').map(Number); return [(this.w - 1 - x) + ',' + y, v]; }));
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) b.cells[y][this.w - 1 - x] = this.cells[y][x];
    b.objects = this.objects.map(o => {
      const q = JSON.parse(JSON.stringify(o));
      if (q.kind === 'gate' || q.kind === 'secret') q.x = (this.w - 1 - Math.round(o.x / C) - (o.dir === 'h' ? 0 : 1)) * C;
      else q.x = r1(this.w * C - o.x);
      if (q.kind === 'prop' && !q.decal) q.flip = !q.flip;
      if (q.kind === 'beam_source') q.dir = { e: 'w', w: 'e' }[q.dir] || q.dir;
      if (q.kind === 'prism') q.turn = 1 - (q.turn || 0);
      if (q.kind === 'mirror_ghost' && q.show) q.show = q.show.map(p => [-p[0], p[1]]);
      return q;
    });
    b.fixedPorts = this.fixedPorts;
    b.ports = this.ports.map(p => {
      const side = { east: 'west', west: 'east' }[p.side] || p.side;
      const x = side === 'north' || side === 'south' ? this.w - 2 - p.cell[0] : this.w - 1 - p.cell[0];
      const q = { side, cell: [x, p.cell[1]] };
      if (p.use) q.use = p.use;
      return q;
    });
    b.steps = this.steps ? JSON.parse(JSON.stringify(this.steps)) : null;
    if (b.steps) b.steps = mirrorSteps(b.steps, this.w);
    return b;
  }
  json() {
    return Object.assign({ schema_version: 1, id: this.id, title: this.title, world: 'frost', role: this.role, in_floors: true, slots: this.slots, width: this.w, height: this.h,
      cells: this.cells.map(r => r.join('')), tiles: {}, areas: {}, ports: this.ports, auto_mobs: 0, objects: this.objects }, this.extra);
  }
}

/** The steps of a puzzle's way seen in the mirror. */
function mirrorSteps(steps, w) {
  const mx = c => [w - 1 - c[0], c[1]];
  const md = d => ({ e: 'w', w: 'e' }[d] || d);
  return steps.map(s => {
    const q = Object.assign({}, s);
    if (s.walk) q.walk = s.walk.map(mx);
    for (const k of ['at', 'use', 'push', 'chest', 'show']) if (s[k]) q[k] = mx(s[k]);
    if (s.dir) q.dir = md(s.dir);
    return q;
  });
}

// ---------- checks: nothing cut off ----------
const SOLID_PIECES = ['ice_block', 'snowball', 'prism', 'beam_source', 'beam_seal', 'crystal', 'bell_statue', 'ember_source', 'core_altar', 'mirror_lever'];
function solidAt(b) {
  const out = new Set();
  for (const o of b.objects) {
    if (SOLID_PIECES.includes(o.kind) || (o.kind === 'brazier')) { out.add(Math.floor(o.x / C) + ',' + Math.floor((o.y - 8) / C)); continue; }
    if (o.kind === 'tablet') { out.add(Math.floor(o.x / C) + ',' + Math.floor((o.y - 10) / C)); continue; }
    if (!o.block) continue;
    const l = o.x - o.foot[0] / 2, t = o.y - o.foot[1], r = o.x + o.foot[0] / 2, d = o.y;
    for (let y = Math.floor(t / C) - 1; y <= Math.floor(d / C) + 1; y++) for (let x = Math.floor(l / C) - 1; x <= Math.floor(r / C) + 1; x++)
      if (l < x * C + 76 && r > x * C + 20 && t < y * C + 92 && d > y * C + 40) out.add(x + ',' + y);
  }
  return out;
}
/** Every door reaches every other over plain ground (no thin ice, no crevasse, no puzzle piece); what is to be taken lies within reach. */
function check(b, opts = b.checkOpts || {}) {
  const solid = solidAt(b);
  const ice = new Set(b.objects.filter(o => o.kind === 'thin_ice').map(o => Math.floor(o.x / C) + ',' + Math.floor(o.y / C)));
  const walk = (x, y) => (b.at(x, y) === FLOOR || b.at(x, y) === BRIDGE || b.at(x, y) === LIQUID) && !solid.has(x + ',' + y) && !ice.has(x + ',' + y);
  const inner = b.ports.map(p => b.inner(p));
  for (const c of inner) if (!walk(c[0], c[1])) throw new Error(`${b.id}: door way blocked at ${c}`);
  if (!inner.length) throw new Error(`${b.id}: no door spot`);
  const main = S.reach(inner[0], walk);
  for (const c of inner) if (!main.has(S.key(c[0], c[1]))) throw new Error(`${b.id}: door at ${c} cannot be reached without the puzzle`);
  for (const o of b.objects) {
    if (opts.skip && opts.skip(o)) continue;
    if (['plate', 'chest', 'start', 'portal', 'gem', 'heart', 'well', 'tablet', 'frost_rune'].includes(o.kind) || (o.kind === 'raw' && o.ent.type !== 'crate')) {
      const x = Math.floor(o.x / C), y = Math.floor((o.y - 10) / C);
      if (![[x, y], [x, y + 1], [x - 1, y], [x + 1, y], [x, y - 1]].some(c => main.has(S.key(c[0], c[1])))) throw new Error(`${b.id}: ${o.kind} at ${x},${y} cannot be reached`);
    }
  }
  if (b.role === 'boss') { const x = Math.floor(b.w / 2), y = Math.floor(b.h / 2) + 1; if (!main.has(S.key(x, y))) throw new Error(`${b.id}: the boss's place is not free`); }
  return main;
}

module.exports = { Room, check, solidAt, mirrorSteps, C, SW, SH, GX, GY, PX, PY, WALL, FLOOR, LIQUID, BRIDGE, PIT, SHAPES, MIRROR, GLYPH, WALLS, SCATTER, SNOW, SIZES, ROOT, r1 };

// Builds the crypt's room files for the Weltbauer: assets/data/world_rooms/krypta/k_*.json (all but the
// key chamber, tools/world_kit/export_key_room.gd cuts that one out of a generated floor). Fight rooms
// and small rooms are drawn by hand as maps (room_maps.js); the big jump puzzles and mazes are built
// here. The files are ordinary Weltbauer rooms, so they can be redesigned there.
// Running this again OVERWRITES those files, redesigned ones too: pass names to rebuild only those.
// Usage (repo root): node tools/krypta_dungeon/build_room_library.js [id ...]
'use strict';
const fs = require('fs');
const path = require('path');
const MAPS = require('./room_maps.js');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'assets', 'data', 'world_rooms', 'krypta');
const SIZES = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets', 'sprites', 'krypta', 'manifest.json'), 'utf8'));
const C = 96;
const SW = 14, SH = 11, GX = 3, GY = 3, PX = SW + GX, PY = SH + GY;
const WALL = '0', FLOOR = '1', LIQUID = '2', BRIDGE = '3', PIT = '4';
const SHAPES = {
  b2: [[0, 0], [1, 0]], h2: [[0, 0], [0, 1]], b3: [[0, 0], [1, 0], [2, 0]], h3: [[0, 0], [0, 1], [0, 2]],
  la: [[0, 0], [1, 0], [0, 1]], lb: [[0, 0], [1, 0], [1, 1]], lc: [[0, 0], [0, 1], [1, 1]], ld: [[1, 0], [0, 1], [1, 1]],
  q: [[0, 0], [1, 0], [0, 1], [1, 1]], e: [[0, 0]],
};
const MIRROR = { la: 'lb', lc: 'ld' };
// what stands on a map's letter: name, foot [width, depth] when it blocks
const GLYPH = {
  P: ['rune_pillar_a', [50, 28]], Q: ['rune_pillar_c', [50, 28]], O: ['obelisk', [46, 28]], D: ['rune_pillar_d', [40, 24]], K: ['skull_obelisk', [46, 28]],
  A: ['statue_angel', [50, 26]], M: ['statue_monk', [40, 24]], G: ['gargoyle', [66, 30]],
  b: ['brazier_bowl', [56, 30]], B: ['brazier_pillar', [56, 30]], d: ['brazier_demon', [50, 28]], f: ['brazier_floor', [56, 28]], l: ['brazier_low', [56, 28]], r: ['brazier_rune', [50, 28]],
  t: ['torch_pillar', [40, 26]], u: ['torch_pillar_blue', [40, 26]], W: ['brazier_blue', [56, 28]], i: ['candelabra', [26, 18]], y: ['torch_b', [26, 18]], H: ['hanging_brazier', [80, 34]],
  g: ['spire_big', [60, 28]], h: ['rocks_lava', [40, 22]], j: ['spire_big_b', [56, 28]], R: ['spires_lava', [66, 30]], n: ['moss_ruin', [66, 30]], m: ['moss_rubble_a', [70, 28]], N: ['spire_big_t', [66, 30]], k: ['boulders', [60, 28]], X: ['rocks_a', [60, 28]],
  S: ['skull_heap', [90, 34]], s: ['skull_pile', [76, 26]], e: ['coal_skulls', [80, 28]], z: ['cage_small', [46, 24]], J: ['spike_block', [70, 30]],
  T: ['table_a', [104, 30]], U: ['table_b', [110, 30]], V: ['table_c', [140, 30]], E: ['bench', [120, 30]], L: ['crate_pile', [80, 34]], Z: ['sacks_b', [90, 26]], Y: ['sacks_a', [64, 26]],
  a: ['altar', [110, 50]],
};
// what fills the empty places of a room, by its set
const SCATTER = {
  guard: ['crate_pile', 'sacks_a', 'sacks_b', 'table_a', 'brazier_floor'],
  chapel: ['candelabra', 'statue_monk', 'torch_b', 'brazier_bowl'],
  chains: ['cage_small', 'spike_block', 'skull_pile', 'brazier_low'],
  bones: ['skull_heap', 'skull_pile', 'coal_skulls', 'rocks_lava', 'brazier_low_b'],
  moss: ['moss_ruin', 'moss_rubble_a', 'spire_big_b', 'boulders', 'spires_lava', 'brazier_floor'],
  ritual: ['brazier_rune', 'rune_pillar_d', 'obelisk', 'torch_pillar_blue'],
  torch: ['brazier_floor', 'rocks_a', 'skull_pile', 'brazier_low'],
};
const BONES = ['bone_a', 'bone_b', 'bone_c', 'bone_d', 'bone_e', 'bone_f', 'bone_g', 'bones_scatter', 'rubble', 'coal'];
const BREAK = ['barrel_a', 'barrel_b', 'barrel_c', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'crate_a', 'crate_b', 'crate_c'];

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
const r1 = v => Math.round(v * 10) / 10;

class Room {
  constructor(id, title, role, shape) {
    this.id = id; this.title = title; this.role = role; this.shape = shape;
    this.slots = SHAPES[shape];
    this.w = Math.max(...this.slots.map(s => s[0] + 1)) * PX - GX;
    this.h = Math.max(...this.slots.map(s => s[1] + 1)) * PY - GY;
    this.cells = Array.from({ length: this.h }, () => Array(this.w).fill(WALL));
    this.objects = []; this.ports = []; this.rnd = random(id); this.extra = {};
  }
  has(c, r) { return this.slots.some(s => s[0] === c && s[1] === r); }
  at(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h ? this.cells[y][x] : WALL; }
  set(x, y, v) { if (x > 0 && y > 0 && x < this.w - 1 && y < this.h - 1) this.cells[y][x] = v; }
  rect(x, y, w, h, v) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.set(i, j, v); }
  prop(name, cx, cy, foot, o = {}) {
    this.objects.push({ kind: 'prop', asset: name, x: r1(cx * C), y: r1(cy * C), flip: !!o.flip, layer: o.low ? 'floor' : 'normal', block: !!foot, scale: 1, foot: foot || [60, 30] });
  }
  wall(name, cx, row, o = {}) {
    this.objects.push({ kind: 'prop', asset: name, x: r1(cx * C), y: row * C + (o.dy === undefined ? 6 : o.dy), flip: !!o.flip, layer: 'floor', block: false, scale: 1, foot: [60, 30], wall_decor: true });
  }
  decal(name, cx, cy, o = {}) {
    const half = (SIZES[name] ? SIZES[name].h : 48) / 2;
    this.objects.push({ kind: 'prop', asset: name, x: r1(cx * C), y: Math.round(cy * C + half), flip: false, layer: 'floor', block: false, scale: 1, foot: [60, 30], decal: { dy: half, w: o.w || 0, h: o.h || 0, a: o.a === undefined ? 1 : o.a } });
  }
  thing(kind, cx, cy, extra = {}) { this.objects.push(Object.assign({ kind, x: r1(cx * C), y: r1(cy * C) }, extra)); }
  raw(type, cx, cy, ent = {}) { this.objects.push({ kind: 'raw', x: r1(cx * C), y: r1(cy * C), ent: Object.assign({ type }, ent) }); }
  crate(x, y) {
    const look = BREAK[Math.floor(this.rnd() * BREAK.length)];
    this.raw('crate', x + 0.5, y + 0.85, { look, hp: look.startsWith('crate') ? 2 : 1, drop: 'random' });
  }
  pad(x, y, dir, cells) { this.thing('launch', x + 0.5, y + 0.5, { dir, cells }); }
  spikes(x, y, w, h) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (this.at(x + i, y + j) === FLOOR) this.thing('spikes', x + i + 0.5, y + j + 0.5, { phase: (i + j) % 2 }); }
  chest(x, y, heart) { this.thing('chest', x + 0.5, y + 0.85, { loot: heart ? { type: 'auto', heart: true } : { type: 'auto' } }); }

  /** Draws a map: its letters at cell (ox + column, oy + row). */
  draw(m) {
    const ox = m.at[0], oy = m.at[1];
    let jump = 0;
    m.map.forEach((row, j) => {
      for (let i = 0; i < row.length; i++) {
        const ch = row[i], x = ox + i, y = oy + j;
        if (ch === ' ') continue;
        this.set(x, y, ch === '~' ? LIQUID : ch === '=' ? BRIDGE : ch === 'o' ? PIT : FLOOR);
        const g = GLYPH[ch];
        if (g) this.prop(g[0], x + 0.5, y + 0.86, g[1], { flip: this.rnd() < 0.5 });
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
        else if ('^>_<'.includes(ch)) { this.pad(x, y, { '^': 'n', '>': 'e', '_': 's', '<': 'w' }[ch], (m.jumps || [])[jump++] || 4); }
      }
    });
    for (const d of m.decals || []) this.decal(d[0], ox + d[1], oy + d[2], { w: d[3], h: d[4], a: d[5] });
    for (const w of m.walls || []) this.wall(w[0], ox + w[1], oy + w[2], { dy: w[3], flip: w[4] });
  }
  /** Finds the door spots from the shape: on each open side of each slot the two wall cells nearest its middle. */
  findPorts() {
    this.ports = [];
    const pair = (a, b) => (this.at(a[0], a[1]) !== WALL) && (this.at(b[0], b[1]) !== WALL);
    const near = (lo, hi, mid) => { const out = []; for (let k = lo; k < hi; k++) out.push(k); return out.sort((p, q) => Math.abs(p - mid) - Math.abs(q - mid)); };
    for (const [c, r] of this.slots) {
      const x0 = c * PX, y0 = r * PY;
      const xs = near(x0 + 1, x0 + SW - 2, x0 + 6), ys = near(y0 + 1, y0 + SH - 2, y0 + 5);
      const add = (side, cell) => this.ports.push({ side, cell });
      if (!this.has(c, r - 1)) { let done = false; for (const x of xs) { for (let y = y0 + 1; y < y0 + SH && !done; y++) if (pair([x, y], [x + 1, y]) && !pair([x, y - 1], [x + 1, y - 1]) && this.at(x, y - 1) === WALL && this.at(x + 1, y - 1) === WALL) { add('north', [x, y - 1]); done = true; } if (done) break; } }
      if (!this.has(c, r + 1)) { let done = false; for (const x of xs) { for (let y = Math.min(this.h - 2, y0 + SH - 2 + GY); y >= y0 && !done; y--) if (pair([x, y], [x + 1, y]) && this.at(x, y + 1) === WALL && this.at(x + 1, y + 1) === WALL && Math.floor((y + 1) / PY) === r) { add('south', [x, y + 1]); done = true; } if (done) break; } }
      if (!this.has(c - 1, r)) { let done = false; for (const y of ys) { for (let x = x0 + 1; x < x0 + SW && !done; x++) if (pair([x, y], [x, y + 1]) && this.at(x - 1, y) === WALL && this.at(x - 1, y + 1) === WALL) { add('west', [x - 1, y]); done = true; } if (done) break; } }
      if (!this.has(c + 1, r)) { let done = false; for (const y of ys) { for (let x = Math.min(this.w - 2, x0 + SW - 2 + GX); x >= x0 && !done; x--) if (pair([x, y], [x, y + 1]) && this.at(x + 1, y) === WALL && this.at(x + 1, y + 1) === WALL && Math.floor((x + 1) / PX) === c) { add('east', [x + 1, y]); done = true; } if (done) break; } }
    }
    const want = this.slots.reduce((n, [c, r]) => n + [[0, -1], [1, 0], [0, 1], [-1, 0]].filter(d => !this.has(c + d[0], r + d[1])).length, 0);
    if (this.ports.length !== want) throw new Error(`${this.id}: found ${this.ports.length} of ${want} door spots: ${JSON.stringify(this.ports)}`);
  }
  /** Keeps every door's way in clear: floor two wide and two deep, nothing standing on it. */
  clearPorts() {
    for (const p of this.ports) {
      const [x, y] = p.cell;
      for (let k = 1; k <= 2; k++) for (let t = 0; t < 2; t++) {
        const c = p.side === 'north' ? [x + t, y + k] : p.side === 'south' ? [x + t, y - k] : p.side === 'west' ? [x + k, y + t] : [x - k, y + t];
        if (this.at(c[0], c[1]) !== BRIDGE) this.set(c[0], c[1], FLOOR);
        this.objects = this.objects.filter(o => !(Math.floor(o.x / C) === c[0] && Math.floor((o.y - 8) / C) === c[1] && (o.block || o.kind === 'raw' || o.kind === 'chest' || o.kind === 'spikes' || o.kind === 'vent' || o.kind === 'launch')));
      }
    }
  }
  nearPort(x, y, d) {
    return this.ports.some(p => {
      const side = p.side === 'east' || p.side === 'west';
      return Math.hypot(x + 0.5 - (side ? p.cell[0] + 0.5 : p.cell[0] + 1), y + 0.5 - (side ? p.cell[1] + 1 : p.cell[1] + 0.5)) < d;
    });
  }
  /** Pictures on the north walls, in a set's mix, kept off the door spots. */
  wallDress(names) {
    for (let y = 1; y < this.h - 1; y++) {
      let x = 1;
      while (x < this.w - 1) {
        if (this.at(x, y) !== WALL && this.at(x, y - 1) === WALL) {
          let e = x;
          while (this.at(e + 1, y) !== WALL && this.at(e + 1, y - 1) === WALL) e++;
          for (let k = x + 1.5; k < e; k += 2.8) {
            if (this.nearPort(k, y, 3.1)) continue;
            this.wall(names[Math.floor(this.rnd() * names.length)], k, y, { flip: this.rnd() < 0.5 });
          }
          x = e + 1;
        } else x++;
      }
    }
  }
  /** Loose bones and rubble on the floor. */
  bones(share) {
    const free = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) if (this.at(x, y) === FLOOR) free.push([x, y]);
    const n = Math.floor(free.length * share);
    for (let k = 0; k < n; k++) {
      const c = free[Math.floor(this.rnd() * free.length)];
      this.prop(BONES[Math.floor(this.rnd() * BONES.length)], c[0] + 0.2 + this.rnd() * 0.6, c[1] + 0.4 + this.rnd() * 0.5, null, { low: true, flip: this.rnd() < 0.5 });
    }
  }
  /** Fills what stayed empty: the set's things along the walls and marks on the floor, never near a door or a pad. */
  scatter(theme) {
    const set = SCATTER[theme] || SCATTER.torch;
    const taken = this.objects.filter(o => o.block || ['raw', 'chest', 'plate', 'launch', 'spikes', 'vent'].includes(o.kind));
    const edge = [], floor = [];
    for (let y = 1; y < this.h - 1; y++) for (let x = 1; x < this.w - 1; x++) {
      if (this.at(x, y) !== FLOOR || this.nearPort(x, y, 3.4)) continue;
      floor.push([x, y]);
      if (this.at(x - 1, y) === WALL || this.at(x + 1, y) === WALL || this.at(x, y - 1) === WALL || this.at(x, y + 1) === WALL) edge.push([x, y]);
    }
    const far = (x, y, d) => !taken.some(o => Math.hypot(o.x / C - x - 0.5, o.y / C - y - 0.8) < d);
    for (let k = edge.length - 1; k > 0; k--) { const j = Math.floor(this.rnd() * (k + 1)); [edge[k], edge[j]] = [edge[j], edge[k]]; }
    for (const [x, y] of edge) {
      if (!far(x, y, 3.3)) continue;
      const name = set[Math.floor(this.rnd() * set.length)];
      const g = Object.values(GLYPH).find(v => v[0] === name);
      this.prop(name, x + 0.5, y + 0.86, g ? g[1] : [60, 28], { flip: this.rnd() < 0.5 });
      // whatever closes a way stays out
      try { check(this); } catch (e) { this.objects.pop(); continue; }
      taken.push(this.objects[this.objects.length - 1]);
    }
    const marks = ['moss_a', 'moss_b', 'moss_c', 'blood_a', 'blood_c', 'grate', 'rune_small', 'grate_a', 'grate_b'];
    const n = Math.floor(floor.length / 28);
    for (let k = 0; k < n; k++) {
      const c = floor[Math.floor(this.rnd() * floor.length)];
      this.decal(marks[Math.floor(this.rnd() * marks.length)], c[0] + 0.5, c[1] + 0.5, { a: 0.95 });
    }
  }
  start(at) {
    const taken = new Set();
    for (const o of this.objects) if (o.block || ['raw', 'chest', 'plate', 'spikes', 'launch', 'vent'].includes(o.kind)) taken.add(Math.floor(o.x / C) + ',' + Math.floor((o.y - 8) / C));
    const tx = at ? at[0] : this.w / 2, ty = at ? at[1] : this.h / 2;
    const spots = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.at(x, y) !== FLOOR || taken.has(x + ',' + y)) continue;
      spots.push([x, y, Math.hypot(x + 0.5 - tx, y + 0.5 - ty)]);
    }
    spots.sort((p, q) => p[2] - q[2]);
    // the nearest spot to the middle that the doors can reach
    for (const [x, y] of spots) {
      this.thing('start', x + 0.5, y + 0.7);
      try { check(this); return; } catch (e) { this.objects.pop(); }
    }
    throw new Error(this.id + ': no place for the start');
  }
  /** The same room seen in a mirror: another shape of slots. */
  mirrored(id, shape) {
    const b = new Room(id, this.title.replace(/\(.*\)/, ''), this.role, shape);
    b.title = this.title;
    b.extra = this.extra;
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) b.cells[y][this.w - 1 - x] = this.cells[y][x];
    b.objects = this.objects.map(o => {
      const q = JSON.parse(JSON.stringify(o));
      q.x = r1(this.w * C - o.x);
      if (q.kind === 'prop' && !q.decal) q.flip = !q.flip;
      if (q.kind === 'launch') q.dir = { e: 'w', w: 'e' }[q.dir] || q.dir;
      return q;
    });
    return b;
  }
  json() {
    return Object.assign({ schema_version: 1, id: this.id, title: this.title, world: 'krypta', role: this.role, in_floors: true, slots: this.slots, width: this.w, height: this.h,
      cells: this.cells.map(r => r.join('')), tiles: {}, areas: {}, ports: this.ports, auto_mobs: 0, objects: this.objects }, this.extra);
  }
}

// ---------- the drawn rooms ----------
const WALLS = MAPS.WALLS;
function drawn(m) {
  const b = new Room(`k_${m.id}`, m.title, m.role, m.shape);
  b.draw(m);
  return finish(b, m);
}
function finish(b, m) {
  b.findPorts();
  b.clearPorts();
  if (m.walltheme) b.wallDress(WALLS[m.walltheme]);
  if (m.walltheme) b.scatter(m.walltheme);
  if (m.bones) b.bones(m.bones);
  if (!b.objects.some(o => o.kind === 'start')) b.start();
  return b;
}
function drawnAll() {
  const out = [];
  for (const m of MAPS.ROOMS) {
    const b = drawn(m);
    out.push(b);
    if (MIRROR[m.shape]) {
      const q = b.mirrored(b.id + '_gs', MIRROR[m.shape]);
      q.findPorts();
      out.push(q);
    }
  }
  return out;
}

// ---------- the big jump puzzles ----------
function jumpRoom(id, title, shape, kind, make, theme) {
  const b = new Room(`k_${id}`, title, 'jump', shape);
  b.extra = { kind_label: kind };
  make(b);
  b.findPorts();
  b.clearPorts();
  b.wallDress(WALLS[theme || 'torch']);
  if (b.extra.kind_label !== 'Labyrinth') b.scatter(theme || 'torch');
  b.bones(0.03);
  b.start();
  const out = [b];
  if (MIRROR[shape]) { const q = b.mirrored(b.id + '_gs', MIRROR[shape]); q.findPorts(); out.push(q); }
  return out;
}
/** A walled chamber, floor inside. */
function chamber(b, x, y, w, h) { b.rect(x - 1, y - 1, w + 2, h + 2, WALL); b.rect(x, y, w, h, FLOOR); }
function jumps() {
  const out = [];
  // long: four walled chambers beside one hall; each has its pad, only some pay
  out.push(...jumpRoom('sprung_kammern', 'Sprung: Vier Kammern (lang)', 'b3', 'Sprungrätsel', b => {
    b.rect(1, 1, 46, 9, FLOOR);
    chamber(b, 10, 1, 10, 2); chamber(b, 27, 1, 10, 2); chamber(b, 10, 8, 10, 2); chamber(b, 27, 8, 10, 2);
    b.pad(13, 5, 'n', 3); b.pad(30, 5, 'n', 3); b.pad(16, 5, 's', 3); b.pad(33, 5, 's', 3);
    b.chest(15, 1, true); b.pad(11, 2, 's', 3); b.prop('candelabra', 17.5, 1.9, [26, 18]); b.prop('candelabra', 19.5, 1.9, [26, 18]);
    b.spikes(28, 1, 8, 2); b.pad(36, 2, 's', 3);
    b.rect(11, 8, 8, 2, LIQUID); b.rect(15, 8, 3, 2, FLOOR); b.pad(17, 8, 'n', 3);
    b.thing('gem', 15.5, 8.85); b.pad(28, 8, 'n', 3); b.chest(35, 9);
    b.prop('skull_heap', 30.5, 8.86, [90, 34]);
    for (const [n, x, y] of [['torch_pillar', 3, 2.9], ['torch_pillar', 44, 2.9], ['rune_pillar_a', 8.5, 8.9], ['rune_pillar_a', 38.5, 8.9], ['rune_pillar_c', 25.5, 8.9]]) b.prop(n, x + 0.5, y, [40, 26]);
    b.decal('rug_blue', 23.5, 5.5, { w: 180, h: 300 });
  }));
  // long: pits between three stone islands; jump from stone to stone, wrong pads end in the pit
  out.push(...jumpRoom('sprung_grubensteg', 'Sprung: Grubensteg (lang)', 'b3', 'Sprungrätsel', b => {
    b.rect(1, 1, 46, 9, FLOOR);
    b.rect(10, 1, 11, 9, PIT); b.rect(27, 1, 11, 9, PIT);
    b.rect(14, 5, 3, 2, FLOOR); b.rect(31, 5, 3, 2, FLOOR);
    b.rect(14, 2, 3, 1, FLOOR); b.chest(15, 2);
    // the right way east and back, and the short ones that fall in
    b.pad(9, 6, 'e', 6); b.pad(16, 6, 'e', 6); b.pad(26, 6, 'e', 6); b.pad(33, 6, 'e', 6);
    b.pad(21, 5, 'w', 6); b.pad(14, 5, 'w', 6); b.pad(38, 5, 'w', 6); b.pad(31, 5, 'w', 6);
    b.pad(9, 3, 'e', 4); b.pad(26, 3, 'e', 3); b.pad(21, 8, 'w', 3); b.pad(38, 8, 'w', 4);
    b.pad(15, 5, 'n', 3); b.pad(14, 2, 's', 3);
    for (const [n, x, y] of [['brazier_pillar', 4, 2.9], ['brazier_pillar', 44, 2.9], ['skull_heap', 3, 8.9], ['skull_heap', 44, 8.9], ['statue_angel', 23.5, 2.9], ['statue_angel', 25, 2.9]]) b.prop(n, x + 0.5, y, [50, 26]);
    b.decal('rune_big', 24, 7);
  }));
  // tower: three halls with walls between; only pads cross them, some throw short or into the spikes
  out.push(...jumpRoom('sprung_stufen', 'Sprung: Stufenturm (Turm)', 'h3', 'Sprungrätsel', b => {
    b.rect(1, 1, 12, 37, FLOOR);
    b.rect(1, 10, 12, 5, WALL); b.rect(1, 24, 12, 5, WALL);
    b.rect(5, 10, 4, 5, WALL);
    b.pad(3, 9, 's', 6); b.pad(10, 9, 's', 3); b.pad(10, 15, 'n', 6); b.pad(3, 15, 'n', 3);
    b.pad(3, 23, 's', 6); b.pad(10, 23, 's', 6); b.pad(3, 29, 'n', 6); b.pad(10, 29, 'n', 6);
    b.spikes(2, 30, 4, 3); b.spikes(7, 16, 5, 2);
    b.chest(11, 36, true); b.prop('statue_monk', 2.5, 36.86, [40, 24]);
    b.prop('brazier_demon', 2.5, 2.9, [50, 28]); b.prop('brazier_demon', 11.5, 2.9, [50, 28]);
    b.prop('rune_pillar_c', 2.5, 19.9, [50, 28]); b.prop('rune_pillar_c', 11.5, 19.9, [50, 28]);
    b.decal('rune_big', 7, 19.5); b.decal('rug_red', 7, 5.5, { w: 170, h: 420 });
    b.thing('gem', 7.5, 34.85);
  }, 'chains'));
  // tower: a lake with stepping stones
  out.push(...jumpRoom('sprung_moderschacht', 'Sprung: Moderschacht (Turm)', 'h3', 'Sprungrätsel', b => {
    b.rect(1, 1, 12, 37, FLOOR);
    b.rect(1, 9, 12, 7, PIT); b.rect(1, 23, 12, 7, LIQUID);
    b.rect(6, 11, 2, 2, FLOOR); b.rect(2, 12, 2, 2, FLOOR); b.rect(10, 12, 2, 2, FLOOR);
    b.rect(5, 25, 4, 3, FLOOR); b.chest(6, 26);
    b.pad(6, 8, 's', 4); b.pad(7, 12, 's', 4); b.pad(6, 16, 'n', 4); b.pad(6, 11, 'n', 4);
    b.pad(2, 8, 's', 2); b.pad(11, 8, 's', 7); b.pad(2, 13, 's', 3); b.pad(11, 13, 'n', 5);
    b.pad(5, 22, 's', 4); b.pad(8, 27, 'n', 6); b.pad(2, 22, 's', 3); b.pad(11, 22, 's', 8);
    b.pad(6, 27, 's', 4); b.pad(7, 30, 'n', 4);
    for (const [n, x, y] of [['spires_lava', 2, 20.9], ['moss_ruin', 11, 19.9], ['moss_rubble_a', 3, 31.9], ['spire_big_b', 10, 31.9], ['spire_big', 3, 3.9], ['spire_big', 11, 3.9]]) b.prop(n, x + 0.5, y, [56, 28]);
  }, 'moss'));
  // the big angled rooms
  const ang = (shape, tall) => {
    const H = tall ? { x: 1, y: 15 } : { x: 1, y: 1 };
    const base = b => { b.rect(1, 1, 12, 23, FLOOR); b.rect(H.x, H.y, 29, 9, FLOOR); };
    const list = [];
    const up = tall ? 15 : 1;
    list.push(...jumpRoom('sprung_gitter_' + shape, 'Sprung: Eisenhalle (Winkel)', shape, 'Sprungrätsel', b => {
      base(b);
      // three chambers in the long arm, one behind the other in reach of three pads
      chamber(b, 15, up, 6, 2); chamber(b, 15, up + 7, 5, 2); chamber(b, 26, up + 7, 3, 2);
      b.pad(17, up + 4, 'n', 3); b.pad(27, up + 5, 's', 3); b.pad(17, up + 5, 's', 3);
      b.chest(18, up, true); b.pad(15, up + 1, 's', 3); b.prop('candelabra', 20.5, up + 0.9, [26, 18]);
      b.spikes(15, up + 7, 5, 2); b.pad(19, up + 7, 'n', 3);
      b.chest(28, up + 8); b.pad(26, up + 8, 'n', 4); b.spikes(26, up + 7, 3, 1);
      // the short arm: a pillared way
      const low = tall ? 3 : 13;
      for (const y of [low, low + 5]) { b.prop('rune_pillar_a', 3.5, y + 0.9, [50, 28]); b.prop('rune_pillar_a', 10.5, y + 0.9, [50, 28]); }
      b.prop('torch_pillar', 13.5, up + 0.9, [40, 26]); b.prop('torch_pillar', 28.5, up + 0.9, [40, 26]);
      b.decal('rune_plate', 7, tall ? 6 : 17);
    }, 'chains'));
    list.push(...jumpRoom('sprung_grubenring_' + shape, 'Sprung: Grubenring (Winkel)', shape, 'Sprungrätsel', b => {
      base(b);
      // an island in a ring of pits: four pads, one lands on it, the others beside it
      b.rect(14, up + 1, 14, 7, PIT); b.rect(19, up + 3, 4, 3, FLOOR);
      b.chest(20, up + 3, true); b.pad(22, up + 5, 'w', 9);
      b.pad(13, up + 4, 'e', 7); b.pad(13, up + 1, 'e', 7); b.pad(13, up + 7, 'e', 4); b.pad(28, up + 4, 'w', 3);
      b.rect(28, up, 2, 9, FLOOR);
      const low = tall ? 2 : 11;
      b.rect(2, low + 3, 4, 3, LIQUID); b.rect(8, low + 3, 4, 3, LIQUID);
      b.prop('spires_lava', 2.5, low + 2.9, [56, 28]); b.prop('rocks_lava', 11.5, low + 2.9, [40, 22]);
      b.prop('skull_heap', 2.5, low + 8.9, [90, 34]); b.prop('coal_skulls', 11.5, low + 8.9, [80, 28]);
      b.decal('rune_big', 21, up + 1, { a: 0 });
    }, 'moss'));
    list.push(...jumpRoom('sprung_moderbecken_' + shape, 'Sprung: Moderbecken (Winkel)', shape, 'Sprungrätsel', b => {
      base(b);
      b.rect(14, up + 1, 13, 7, LIQUID); b.rect(17, up + 2, 3, 2, FLOOR); b.rect(23, up + 5, 3, 2, FLOOR);
      b.chest(18, up + 2); b.chest(24, up + 5, true);
      b.pad(13, up + 3, 'e', 5); b.pad(17, up + 3, 'e', 7); b.pad(25, up + 6, 'n', 5); b.pad(19, up + 3, 'w', 6); b.pad(23, up + 6, 'n', 4);
      b.pad(13, up + 6, 'e', 3);
      const low = tall ? 3 : 13;
      b.prop('moss_ruin', 3.5, low + 0.9, [66, 30]); b.prop('spire_big_b', 10.5, low + 0.9, [56, 28]); b.prop('moss_rubble_a', 3.5, low + 6.9, [70, 28]); b.prop('moss_rubble_b', 10.5, low + 6.9, [70, 28]);
    }, 'moss'));
    return list;
  };
  out.push(...ang('la', false), ...ang('lc', true));
  return out;
}

// ---------- the mazes ----------
function maze(b, x0, y0, w, h, rnd) {
  // cells two wide with one wall between, dug by a walk that never crosses itself
  const nx = Math.floor((w + 1) / 3), ny = Math.floor((h + 1) / 3);
  b.rect(x0, y0, w, h, WALL);
  const seen = new Set();
  const dig = (i, j) => b.rect(x0 + i * 3, y0 + j * 3, 2, 2, FLOOR);
  const stack = [[0, 0]];
  seen.add('0,0'); dig(0, 0);
  while (stack.length) {
    const [i, j] = stack[stack.length - 1];
    const opts = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(d => { const a = i + d[0], c = j + d[1]; return a >= 0 && c >= 0 && a < nx && c < ny && !seen.has(a + ',' + c); });
    if (!opts.length) { stack.pop(); continue; }
    const d = opts[Math.floor(rnd() * opts.length)];
    const a = i + d[0], c = j + d[1];
    if (d[0]) b.rect(x0 + Math.min(i, a) * 3 + 2, y0 + j * 3, 1, 2, FLOOR);
    else b.rect(x0 + i * 3, y0 + Math.min(j, c) * 3 + 2, 2, 1, FLOOR);
    dig(a, c); seen.add(a + ',' + c); stack.push([a, c]);
  }
  return { nx, ny };
}
function mazes() {
  const out = [];
  const ways = (b, x, y, w, h) => { // a ring round the maze, so every door reaches it
    b.rect(x, y, w, 1, FLOOR); b.rect(x, y + h - 1, w, 1, FLOOR); b.rect(x, y, 1, h, FLOOR); b.rect(x + w - 1, y, 1, h, FLOOR);
  };
  out.push(...jumpRoom('labyrinth_lang', 'Labyrinth: Knochengang (lang)', 'b3', 'Labyrinth', b => {
    b.rect(1, 1, 46, 9, FLOOR);
    const r = random('lang');
    maze(b, 3, 2, 44 - 1, 8 - 1, r); ways(b, 1, 1, 46, 9); b.rect(2, 1, 44, 1, FLOOR); b.rect(1, 9, 46, 1, FLOOR);
    b.rect(23, 4, 2, 2, FLOOR); b.chest(23, 4, true);
    b.wall('wall_torch_hook', 8.5, 1); b.wall('wall_torch_hook', 38.5, 1);
  }, 'bones'));
  out.push(...jumpRoom('labyrinth_turm', 'Labyrinth: Schacht (Turm)', 'h3', 'Labyrinth', b => {
    b.rect(1, 1, 12, 37, FLOOR);
    const r = random('turm');
    maze(b, 2, 3, 11 - 1, 33, r); ways(b, 1, 1, 12, 37); b.rect(1, 1, 12, 2, FLOOR); b.rect(1, 36, 12, 2, FLOOR);
    b.rect(5, 18, 2, 2, FLOOR); b.chest(5, 18, true);
  }, 'bones'));
  for (const shape of ['la', 'lc']) {
    const tall = shape === 'lc';
    out.push(...jumpRoom('labyrinth_' + shape, 'Labyrinth: Irrgarten (Winkel)', shape, 'Labyrinth', b => {
      b.rect(1, 1, 12, 23, FLOOR); b.rect(1, tall ? 15 : 1, 29, 9, FLOOR);
      const r = random(shape);
      const up = tall ? 15 : 1;
      maze(b, 14, up + 1, 14, 7, r); ways(b, 13, up, 17, 9);
      maze(b, 2, tall ? 3 : 11, 10, 10, r); ways(b, 1, tall ? 1 : 10, 12, tall ? 14 : 14);
      b.rect(20, up + 3, 2, 2, FLOOR); b.chest(20, up + 3, true); b.rect(5, tall ? 7 : 15, 2, 2, FLOOR); b.thing('gem', 5.5, (tall ? 7 : 15) + 0.85);
    }, 'bones'));
  }
  return out;
}

// ---------- the boss rooms, as large as ever ----------
function bosses() {
  const out = [];
  const add = (id, title, shape, make) => {
    const b = new Room(`k_boss_${id}`, title, 'boss', shape);
    for (const [c, r] of b.slots) {
      const x0 = c * PX, y0 = r * PY;
      b.rect(x0 + 1, y0 + 1, SW - 2, SH - 2, FLOOR);
      if (b.has(c + 1, r)) b.rect(x0 + SW - 1, y0 + 1, GX + 2, SH - 2, FLOOR);
      if (b.has(c, r + 1)) b.rect(x0 + 1, y0 + SH - 1, SW - 2, GY + 2, FLOOR);
      if (b.has(c + 1, r) && b.has(c, r + 1) && b.has(c + 1, r + 1)) b.rect(x0 + SW - 1, y0 + SH - 1, GX + 2, GY + 2, FLOOR);
    }
    const mx = b.w / 2, my = b.h / 2;
    make(b, mx, my);
    b.decal('rune_big', mx, my); b.decal('rune_plate', mx - 3.5, my); b.decal('rune_plate', mx + 3.5, my);
    b.findPorts(); b.clearPorts();
    b.wallDress(WALLS.boss);
    b.bones(0.02);
    b.start([mx, my + 3]);
    out.push(b);
  };
  const ring = (b, mx, my, n, dx, dy) => { for (const [i, j] of [[-dx, -dy], [dx, -dy], [-dx, dy], [dx, dy]]) if (b.at(Math.floor(mx + i), Math.floor(my + j)) === FLOOR) b.prop(n, mx + i, my + j + 0.8, [50, 28]); };
  add('arena', 'Hort: Arena (groß)', 'q', (b, mx, my) => {
    b.rect(1, 1, 3, 3, WALL); b.rect(b.w - 4, 1, 3, 3, WALL); b.rect(1, b.h - 4, 3, 3, WALL); b.rect(b.w - 4, b.h - 4, 3, 3, WALL);
    b.rect(2, Math.floor(my) - 3, 3, 6, LIQUID); b.rect(b.w - 5, Math.floor(my) - 3, 3, 6, LIQUID);
    ring(b, mx, my, 'brazier_demon', 6, 5); b.prop('skull_heap', 6, 3, [90, 34]); b.prop('skull_heap', b.w - 6, 3, [90, 34]);
    b.prop('gargoyle', 5.5, 21.9, [66, 30]); b.prop('gargoyle', b.w - 5.5, 21.9, [66, 30]);
  });
  add('saeulenring', 'Hort: Säulenring (groß)', 'q', (b, mx, my) => {
    for (let k = 0; k < 8; k++) { const a = k / 8 * Math.PI * 2 + Math.PI / 8; b.prop('rune_pillar_a', mx + Math.cos(a) * 9, my + Math.sin(a) * 6.2, [50, 28]); }
    for (const [x, y] of [[3, 3], [b.w - 3, 3], [3, b.h - 3], [b.w - 3, b.h - 3]]) b.prop('brazier_pillar', x, y, [56, 30]);
    b.decal('carpet', mx, my + 6, { w: 150, h: 300 });
  });
  add('moderthron', 'Hort: Moderthron (groß)', 'q', (b, mx, my) => {
    b.rect(3, 3, 7, 5, LIQUID); b.rect(b.w - 10, 3, 7, 5, LIQUID); b.rect(3, b.h - 8, 7, 5, LIQUID); b.rect(b.w - 10, b.h - 8, 7, 5, LIQUID);
    b.prop('spires_lava', 10.5, 7, [56, 28]); b.prop('spires_lava', b.w - 10.5, 7, [56, 28], { flip: true }); ring(b, mx, my, 'brazier_demon', 6, 5);
  });
  add('kreuzgewoelbe', 'Hort: Kreuzgewölbe (groß)', 'q', (b, mx, my) => {
    for (const [x, y] of [[mx - 8, my - 6], [mx + 6, my - 6], [mx - 8, my + 4], [mx + 6, my + 4]]) b.rect(Math.floor(x), Math.floor(y), 2, 2, WALL);
    ring(b, mx, my, 'brazier_pillar', 5, 4); b.prop('statue_angel', 3, 4, [50, 26]); b.prop('statue_angel', b.w - 3, 4, [50, 26], { flip: true });
  });
  add('halle_b', 'Hort: Halle (breit)', 'b2', (b, mx, my) => { ring(b, mx, my, 'brazier_demon', 6, 3); b.prop('skull_heap', 4, 2.9, [90, 34]); b.prop('skull_heap', b.w - 4, 2.9, [90, 34]); });
  add('becken_b', 'Hort: Becken (breit)', 'b2', (b, mx, my) => { b.rect(2, 3, 3, 6, LIQUID); b.rect(b.w - 5, 3, 3, 6, LIQUID); ring(b, mx, my, 'brazier_pillar', 6, 3); });
  add('halle_h', 'Hort: Halle (hoch)', 'h2', (b, mx, my) => { ring(b, mx, my, 'brazier_demon', 3.5, 8); b.prop('statue_angel', 3, 11.9, [50, 26]); b.prop('statue_angel', 11, 11.9, [50, 26], { flip: true }); });
  add('becken_h', 'Hort: Becken (hoch)', 'h2', (b, mx, my) => { b.rect(2, 4, 3, 5, LIQUID); b.rect(b.w - 5, 4, 3, 5, LIQUID); ring(b, mx, my, 'brazier_pillar', 3.5, 8); });
  add('kammer', 'Hort: Kammer (klein)', 'e', b => { b.prop('brazier_demon', 3.6, 3.4, [50, 28]); b.prop('brazier_demon', 10.4, 3.4, [50, 28]); });
  add('kammer_saeulen', 'Hort: Säulenkammer (klein)', 'e', b => { for (const [i, j] of [[3, 3.2], [11, 3.2], [3, 8.8], [11, 8.8]]) b.prop('rune_pillar_d', i, j, [40, 24]); });
  return out;
}

// ---------- the checks: nothing cut off, no way back missing ----------
function solidAt(b) {
  const out = new Set();
  for (const o of b.objects) {
    if (!o.block) continue;
    const l = o.x - o.foot[0] / 2, t = o.y - o.foot[1], r = o.x + o.foot[0] / 2, d = o.y;
    for (let y = Math.floor(t / C) - 1; y <= Math.floor(d / C) + 1; y++) for (let x = Math.floor(l / C) - 1; x <= Math.floor(r / C) + 1; x++)
      if (l < x * C + 76 && r > x * C + 20 && t < y * C + 92 && d > y * C + 40) out.add(x + ',' + y);
  }
  return out;
}
function check(b) {
  const solid = solidAt(b);
  const pits = c => b.at(c[0], c[1]) === PIT;
  const walk = (x, y) => (b.at(x, y) === FLOOR || b.at(x, y) === BRIDGE) && !solid.has(x + ',' + y);
  const inner = b.ports.map(p => p.side === 'north' ? [p.cell[0], p.cell[1] + 1] : p.side === 'south' ? [p.cell[0], p.cell[1] - 1] : p.side === 'west' ? [p.cell[0] + 1, p.cell[1]] : [p.cell[0] - 1, p.cell[1]]);
  for (const c of inner) if (!walk(c[0], c[1])) throw new Error(`${b.id}: door way blocked at ${c}`);
  // parts of the floor one can walk within
  const part = new Map();
  let parts = 0;
  for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
    if (!walk(x, y) || part.has(x + ',' + y)) continue;
    const todo = [[x, y]]; part.set(x + ',' + y, parts);
    while (todo.length) {
      const [i, j] = todo.pop();
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (walk(i + dx, j + dy) && !part.has((i + dx) + ',' + (j + dy))) { part.set((i + dx) + ',' + (j + dy), parts); todo.push([i + dx, j + dy]); }
    }
    parts++;
  }
  // throws: where each pad lands; a wall or a solid gives way back along the path, a pit or the mire is a trap
  const out = Array.from({ length: parts }, () => new Set());
  const traps = [];
  const pads = b.objects.filter(o => o.kind === 'launch');
  for (const o of pads) {
    const x = Math.floor(o.x / C), y = Math.floor(o.y / C);
    const d = { n: [0, -1], e: [1, 0], s: [0, 1], w: [-1, 0] }[o.dir];
    const from = part.get(x + ',' + y);
    if (from === undefined) throw new Error(`${b.id}: pad at ${x},${y} stands in nothing walkable`);
    let k = o.cells, land = null;
    while (k > 0) { const c = [x + d[0] * k, y + d[1] * k]; if (b.at(c[0], c[1]) !== WALL && !solid.has(c.join(','))) { land = c; break; } k--; }
    if (!land) continue;
    const to = part.get(land.join(','));
    if (pits(land) || b.at(land[0], land[1]) === LIQUID) traps.push(o);
    else if (to !== undefined) out[from].add(to);
  }
  const reach = from => { const seen = new Set([from]); const todo = [from]; while (todo.length) for (const n of out[todo.pop()]) if (!seen.has(n)) { seen.add(n); todo.push(n); } return seen; };
  const main = reach(part.get(inner[0].join(',')));
  for (const c of inner) if (!main.has(part.get(c.join(',')))) throw new Error(`${b.id}: door at ${c} cannot be reached`);
  for (const p of main) if (!reach(p).has(part.get(inner[0].join(',')))) throw new Error(`${b.id}: stuck in part ${p}: no way back from there`);
  for (const o of b.objects) {
    if (['plate', 'chest', 'start', 'portal', 'gem', 'heart'].includes(o.kind) || (o.kind === 'raw' && o.ent.type !== 'crate')) {
      const x = Math.floor(o.x / C), y = Math.floor((o.y - 10) / C);
      if (![[x, y], [x, y + 1], [x - 1, y], [x + 1, y], [x, y - 1]].some(c => main.has(part.get(c.join(','))))) throw new Error(`${b.id}: ${o.kind} at ${x},${y} cannot be reached`);
    }
  }
  if (b.role === 'jump' && pads.length && !(traps.length || b.objects.some(o => o.kind === 'spikes'))) throw new Error(`${b.id}: a jump puzzle needs traps`);
  if (b.role === 'boss') { const x = Math.floor(b.w / 2), y = Math.floor(b.h / 2) + 1; if (!main.has(part.get(x + ',' + y))) throw new Error(`${b.id}: the boss's place is not free`); }
}

const only = process.argv.slice(2);
const rooms = [...drawnAll(), ...jumps(), ...mazes(), ...bosses()];
let wrote = 0;
const errors = [];
for (const b of rooms) {
  try { check(b); } catch (e) { errors.push(e.message); continue; }
  if (only.length && !only.includes(b.id)) continue;
  fs.writeFileSync(path.join(OUT, b.id + '.json'), JSON.stringify(b.json(), null, '\t') + '\n');
  wrote++;
}
const by = {};
for (const b of rooms) { const k = b.role + ' ' + b.shape; by[k] = (by[k] || 0) + 1; }
console.log(`rooms ${rooms.length}, wrote ${wrote}`);
console.log(Object.entries(by).map(([k, v]) => k + ':' + v).join('  '));
if (errors.length) { console.log('PROBLEMS\n' + errors.join('\n')); process.exitCode = 1; }

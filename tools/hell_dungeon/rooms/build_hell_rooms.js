// Builds the hell's room files for the Weltbauer: assets/data/world_rooms/hell/h_*.json (docs/HOELLE-RAETSEL.de.md).
// Fight rooms and small rooms come from maps.js, the key chamber is the Krypta's own (same layout, the hell
// set's pictures), the boss rooms (the boss never stands in lava) and the puzzle rooms (hell_puzzle_rooms.js,
// eight riddles in five tiers, each checked by its solver) are built here.
// Running this again OVERWRITES those files, redesigned ones too: pass names to rebuild only those.
// Usage (repo root): node tools/hell_dungeon/rooms/build_hell_rooms.js [id ...]
//   HELL_ROOMS_OUT=<dir> writes elsewhere (to compare with the Weltbauer's edits first).
'use strict';
const fs = require('fs');
const path = require('path');
const R = require('./room.js');
const MAPS = require('./maps.js');
const H = require('./hell_puzzle_rooms.js');
const { Room, check, FLOOR, LIQUID, PIT, WALL, MIRROR } = R;

const OUT = process.env.HELL_ROOMS_OUT || path.join(R.ROOT, 'assets', 'data', 'world_rooms', 'hell');

// ---------- the drawn rooms ----------
function drawn(m) {
  const b = new Room(`h_${m.id}`, m.title, m.role, m.shape);
  b.draw(m);
  b.findPorts();
  b.clearPorts();
  if (m.walltheme) { b.wallDress(R.WALLS[m.walltheme]); b.scatter(m.walltheme); }
  b.snow(m.snow || 0.04);
  if (!b.objects.some(o => o.kind === 'start')) b.start();
  return b;
}
function drawnAll() {
  const out = [];
  for (const m of MAPS.ROOMS) {
    const b = drawn(m);
    out.push(b);
    if (MIRROR[m.shape]) { const q = b.mirrored(b.id + '_gs', MIRROR[m.shape]); q.fixedPorts = false; q.findPorts(); out.push(q); }
  }
  return out;
}

// ---------- the key chamber: the Krypta's, in the hell ----------
function keyRoom() {
  const k = JSON.parse(fs.readFileSync(path.join(R.ROOT, 'assets', 'data', 'world_rooms', 'krypta', 'k_schluesselkammer.json'), 'utf8'));
  k.id = 'h_schluesselkammer';
  k.world = 'hell';
  return { id: k.id, role: 'key', shape: 'e', json: () => k };
}

// ---------- the boss rooms: the middle (where the boss rises) is always firm ground ----------
function bosses() {
  const out = [];
  const add = (id, title, shape, make) => {
    const b = new Room(`h_boss_${id}`, title, 'boss', shape);
    for (const [c, r] of b.slots) {
      const x0 = c * R.PX, y0 = r * R.PY;
      b.rect(x0 + 1, y0 + 1, R.SW - 2, R.SH - 2, FLOOR);
      if (b.has(c + 1, r)) b.rect(x0 + R.SW - 1, y0 + 1, R.GX + 2, R.SH - 2, FLOOR);
      if (b.has(c, r + 1)) b.rect(x0 + 1, y0 + R.SH - 1, R.SW - 2, R.GY + 2, FLOOR);
      if (b.has(c + 1, r) && b.has(c, r + 1) && b.has(c + 1, r + 1)) b.rect(x0 + R.SW - 1, y0 + R.SH - 1, R.GX + 2, R.GY + 2, FLOOR);
    }
    const mx = b.w / 2, my = b.h / 2;
    make(b, mx, my);
    // the boss's place: a firm 5 x 5 in the middle, never lava or chasm
    b.rect(Math.floor(mx) - 2, Math.floor(my) - 2, 5, 5, FLOOR);
    b.decal('rune_big', mx, my);
    b.findPorts(); b.clearPorts();
    b.wallDress(R.WALLS.boss);
    b.snow(0.04);
    b.start([mx, my + 3]);
    out.push(b);
  };
  const ring = (b, mx, my, n, dx, dy) => { for (const [i, j] of [[-dx, -dy], [dx, -dy], [-dx, dy], [dx, dy]]) if (b.at(Math.floor(mx + i), Math.floor(my + j)) === FLOOR) b.prop(n, mx + i, my + j + 0.8, [50, 28]); };
  add('glutthron', 'Hort: Glutthron (groß)', 'q', (b, mx, my) => {
    for (let k = 0; k < 8; k++) { const a = k / 8 * Math.PI * 2 + Math.PI / 8; b.prop(k % 2 ? 'rune_pillar_c' : 'spire_big', mx + Math.cos(a) * 9.5, my + Math.sin(a) * 6.5, [54, 28]); }
    for (const [x, y] of [[3, 3], [b.w - 3, 3], [3, b.h - 3], [b.w - 3, b.h - 3]]) b.prop('brazier_demon', x, y, [56, 30]);
    b.rect(Math.floor(mx) - 2, 2, 5, 2, LIQUID);
    b.decal('rug_red', mx, my + 6, { w: 150, h: 300 });
  });
  add('lavasee', 'Hort: Lavasee (groß)', 'q', (b, mx, my) => {
    // a lava ring round the boss's island, wide ways over it (non-lava bosses must not stand in it)
    b.rect(Math.floor(mx) - 8, Math.floor(my) - 5, 17, 11, LIQUID);
    b.rect(Math.floor(mx) - 3, Math.floor(my) - 2, 7, 5, FLOOR);
    b.rect(Math.floor(mx) - 1, Math.floor(my) - 5, 3, 11, FLOOR);
    b.rect(Math.floor(mx) - 8, Math.floor(my), 17, 2, FLOOR);
    for (const [x, y] of [[4, 4], [b.w - 4, 4], [4, b.h - 4], [b.w - 4, b.h - 4]]) b.prop('rocks_lava', x, y, [80, 32]);
    ring(b, mx, my, 'torch_pillar', 11, 7);
  });
  add('kesselhalle', 'Hort: Kesselhalle (groß)', 'q', (b, mx, my) => {
    for (const [x, y] of [[mx - 8, my - 6], [mx + 6, my - 6], [mx - 8, my + 4], [mx + 6, my + 4]]) b.rect(Math.floor(x), Math.floor(y), 2, 2, WALL);
    ring(b, mx, my, 'brazier_demon', 5, 4);
    b.prop('gargoyle', 3, 4, [66, 30]); b.prop('gargoyle', b.w - 3, 4, [66, 30], { flip: true });
  });
  add('schlundarena', 'Hort: Schlundarena (groß)', 'q', (b, mx, my) => {
    b.rect(2, Math.floor(my) - 3, 3, 6, PIT); b.rect(b.w - 5, Math.floor(my) - 3, 3, 6, PIT);
    ring(b, mx, my, 'spire_big', 6, 5); b.prop('spires_lava', 6, 3, [70, 30]); b.prop('spires_lava', b.w - 6, 3, [70, 30], { flip: true });
  });
  add('kerker_b', 'Hort: Kerkerhalle (breit)', 'b2', (b, mx, my) => { ring(b, mx, my, 'brazier_demon', 6, 3); b.prop('cage_small', 4, 2.9, [46, 24]); b.prop('skull_heap', b.w - 4, 2.9, [90, 34]); });
  add('glutbecken_b', 'Hort: Glutbecken (breit)', 'b2', (b, mx, my) => { b.rect(2, 3, 3, 6, LIQUID); b.rect(b.w - 5, 3, 3, 6, LIQUID); ring(b, mx, my, 'rune_pillar_c', 6, 3); });
  add('klagehalle_h', 'Hort: Klagehalle (hoch)', 'h2', (b, mx, my) => { ring(b, mx, my, 'brazier_demon', 3.5, 8); b.prop('statue_monk', 3, 11.9, [40, 24]); b.prop('statue_monk', 11, 11.9, [40, 24], { flip: true }); });
  add('glutbecken_h', 'Hort: Glutbecken (hoch)', 'h2', (b, mx, my) => { b.rect(2, 4, 3, 5, LIQUID); b.rect(b.w - 5, 4, 3, 5, LIQUID); ring(b, mx, my, 'rune_pillar_c', 3.5, 8); });
  add('brandkammer', 'Hort: Brandkammer (klein)', 'e', b => { b.prop('brazier_demon', 3.6, 3.4, [50, 28]); b.prop('brazier_demon', 10.4, 3.4, [50, 28]); });
  add('kammer_saeulen', 'Hort: Säulenkammer (klein)', 'e', b => { for (const [i, j] of [[3, 3.2], [11, 3.2], [3, 8.8], [11, 8.8]]) b.prop('rune_pillar_d', i, j, [40, 24]); });
  return out;
}

// ---------- write ----------
const only = process.argv.slice(2);
const errors = [];
const rooms = [];
for (const part of [drawnAll, bosses, () => H.puzzles(errors), () => H.specials(errors)]) {
  try { rooms.push(...part()); } catch (e) { errors.push(e.stack || e.message); }
}
rooms.push(keyRoom());
fs.mkdirSync(OUT, { recursive: true });
let wrote = 0;
const steps = {};
for (const b of rooms) {
  if (b.json === Room.prototype.json) { try { if (b.role !== 'jump') check(b); } catch (e) { errors.push(e.message); continue; } }
  if (b.steps) steps[b.id] = { steps: b.steps, w: b.w, h: b.h };
  if (only.length && !only.includes(b.id)) continue;
  fs.writeFileSync(path.join(OUT, b.id + '.json'), JSON.stringify(b.json(), null, '\t') + '\n');
  wrote++;
}
const STEPS = process.env.HELL_STEPS_OUT || path.join(R.ROOT, 'tools', 'hell_dungeon', 'rooms', 'steps.json');
fs.writeFileSync(STEPS, JSON.stringify(steps, null, 1) + '\n');
const by = {};
for (const b of rooms) { const k = b.role + ' ' + b.shape; by[k] = (by[k] || 0) + 1; }
console.log(`rooms ${rooms.length}, wrote ${wrote}`);
console.log(Object.entries(by).map(([k, v]) => k + ':' + v).join('  '));
if (errors.length) { console.log('PROBLEMS\n' + errors.join('\n')); process.exitCode = 1; }

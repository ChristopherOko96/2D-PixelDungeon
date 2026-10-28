// Bakes all ten hell floors from hell_core.js into assets/data/hell_floors.json.
// Usage (repo root): node tools/hell_dungeon/bake_floors.js
// The browser preview runs the same core, so both always show the same floors.
'use strict';
const fs = require('fs');
const path = require('path');
const core = require('./hell_core.js');

const root = path.resolve(__dirname, '..', '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'assets/sprites/hell/manifest.json'), 'utf8'));
const SIZES = {};
for (const [k, v] of Object.entries(manifest)) SIZES[k] = [v.w, v.h];

const r1 = v => Math.round(v * 10) / 10;
const TILE_NAMES = ['floor_00', 'floor_01', 'floor_02', 'floor_03', 'floor_04', 'floor_05', 'floor_06', 'floor_07', 'floor_08', 'floor_09', 'floor_10', 'floor_11'];

function bake(n) {
  const W = core.buildFloor(n, SIZES);
  const quick = core.criticalRooms(W);
  const roomIndex = r => r.index;
  return {
    n, title: W.title, circle: W.circle, final: W.final,
    theme: { dark: W.theme.dark, grade: W.theme.grade, vignette: W.theme.vignette, embers: W.theme.embers, hot: W.theme.hot, wall_glow: W.theme.wallGlow, circle: W.theme.circle },
    boss: W.boss, diff: W.diff,
    cols: W.COLS, rows: W.ROWS, cell: core.C,
    // one character per cell: 0 void, 1 floor, 2 lava, 3 bridge
    grid: Array.from(W.grid).join(''),
    holes: Array.from(W.holeAt).join(''),
    // floor tile per cell as a base-36 digit into tile_names
    tile_names: TILE_NAMES,
    tiles: W.tileAt.map(t => (TILE_NAMES.indexOf(t) < 0 ? 0 : TILE_NAMES.indexOf(t)).toString(36)).join(''),
    room_at: Array.from(W.roomAt),
    quick: quick.need ? quick.need.length : -1,
    rooms: W.rooms.map(r => ({
      index: r.index, id: r.id, name: r.name, kind: r.kind, type: r.type, icon: r.icon || '', icon_key: r.iconKey || '',
      bx: r.bx, by: r.by, bw: r.bw, bh: r.bh, mobs: r.mobs || 0, drop: r.drop || '', reward: r.reward || null,
      spawn: r.spawn || null, cleared: !!r.cleared, info: r.info || '', on_path: !!r.onPath,
    })),
    doors: W.doors.map(d => ({
      a: roomIndex(d.a), b: roomIndex(d.b), kind: d.kind, key: d.key || '', group: d.group || '', hidden: !!d.hidden, dir: d.dir,
      cells: d.cells, x0: d.x0, y0: d.y0, x1: d.x1, y1: d.y1, cx: d.cx, cy: d.cy, crack_x: d.crackX, crack_y: d.crackY,
    })),
    groups: W.groups,
    props: W.props.map(p => ({ name: p.name || '', x: r1(p.x), y: r1(p.y), flip: !!p.flip, low: p.layer === 'low', solid: p.solid ? p.solid.map(r1) : null })),
    decals: W.decals.map(d => ({ name: d.name, x: r1(d.x), y: r1(d.y), w: d.w || 0, h: d.h || 0, a: d.a ?? 1 })),
    wall_decor: W.wallDecor.map(w => ({ name: w.name, x: r1(w.x), y: r1(w.y), flip: !!w.flip })),
    ents: W.ents.map(e => {
      const o = { type: e.type, x: r1(e.x), y: r1(e.y), room: e.room };
      for (const k of ['key', 'group', 'order', 'offset', 'phase', 'magic', 'loot']) if (e[k] !== undefined) o[k] = e[k];
      return o;
    }),
    lights: W.lights.map(l => ({ x: r1(l.x), y: r1(l.y), r: l.r, c: l.c })),
  };
}

const floors = [];
for (let n = 1; n <= 10; n++) floors.push(bake(n));
const out = path.join(root, 'assets/data/hell_floors.json');
fs.writeFileSync(out, JSON.stringify({ schema: 1, source: 'tools/hell_dungeon/hell_core.js', floors }));
console.log('baked', floors.length, 'floors ->', path.relative(root, out), (fs.statSync(out).size / 1e6).toFixed(2), 'MB');
for (const f of floors) console.log(`  E${f.n} ${f.title}: ${f.rooms.length} rooms, quickest ${f.quick}, ${f.props.length} props, ${f.ents.length} entities`);

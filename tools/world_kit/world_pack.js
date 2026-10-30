// World kit packs: what a world brings on top of the shared generator (tools/world_kit/world_core.js).
// A pack is plain data (floors, names, wording, dressing tables, colours); make(PACK) gives the
// functions every world runs: dress(W) after buildFloor, the run seeds (forRun, floorSeed, newRun).
// The crypt (tools/krypta_dungeon/krypta_floors.js) and the hell (tools/hell_dungeon/hell_world.js)
// are packs. The Godot port is src/world_kit/world_pack.gd, reading the pack from assets/data.
//
// PACK keys: floors, circles, names, suffixes (generator input); words ([hell wording, world
// wording] pairs, longest first); theme_flag (a theme key set true); light ({dark, vignette}
// factors, null keeps the hell's); gate_banner (banner colour per floor, red when missing); blue
// (rgb of the faint blue fire) and blue_props (props whose light turns that blue); foot, wall_set,
// break_set (furniture and breakables); mimic_fight, mimic_treasure (share of chests that bite).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.WorldPack = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';
  function make(PACK) {
    const wording = text => (PACK.words || []).reduce((t, [a, b]) => t.split(a).join(b), text || '');
    // The hell generator lays a bridge on every path cell inside a river; where the path bends or runs
    // along the river that gives staggered or long pieces. Each connected bridge becomes one straight
    // crossing, two cells wide, across the full river, where both banks are floor; the rest of the
    // piece turns back into mire. One decal covers the crossing.
    function straightenBridges(W) {
      const C = 96, idx = (x, y) => y * W.COLS + x, seen = new Set(), boxes = [];
      for (let i = 0; i < W.grid.length; i++) {
        if (W.grid[i] !== 3 || seen.has(i)) continue;
        const todo = [i]; seen.add(i);
        let x0 = Infinity, y0 = Infinity, x1 = -1, y1 = -1;
        while (todo.length) {
          const k = todo.pop(), x = k % W.COLS, y = (k / W.COLS) | 0;
          x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
          for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const n = idx(x + dx, y + dy); if (W.grid[n] === 3 && !seen.has(n)) { seen.add(n); todo.push(n); } }
        }
        boxes.push([x0, y0, x1, y1]);
      }
      const inBox = (d, [x0, y0, x1, y1]) => d.x >= x0 * C && d.x <= (x1 + 1) * C && d.y >= y0 * C && d.y <= (y1 + 1) * C;
      const water = (x, y) => W.grid[idx(x, y)] === 2 || W.grid[idx(x, y)] === 3;
      for (const b of boxes) {
        const old = W.decals.filter(d => d.name.startsWith('bridge') && inBox(d, b));
        if (!old.length) continue;
        const across = old[0].name === 'bridge_h';   // walked left-right over a river running top-down
        // the river's full width at this spot, measured across from the piece
        let [x0, y0, x1, y1] = b;
        if (across) { while (water(x0 - 1, y0)) x0--; while (water(x1 + 1, y0)) x1++; } else { while (water(x0, y0 - 1)) y0--; while (water(x0, y1 + 1)) y1++; }
        // two cells along the river where both banks are floor, nearest the middle of the piece
        const a0 = across ? y0 : x0, a1 = across ? y1 : x1, mid = (a0 + a1) / 2;
        const bank = (s) => [s, s + 1].every(t => across ? W.grid[idx(x0 - 1, t)] === 1 && W.grid[idx(x1 + 1, t)] === 1 : W.grid[idx(t, y0 - 1)] === 1 && W.grid[idx(t, y1 + 1)] === 1);
        let best = null;
        for (let s = a0 - 1; s <= a1; s++) if (bank(s) && (best === null || Math.abs(s + .5 - mid) < Math.abs(best + .5 - mid))) best = s;
        if (best === null) best = Math.max(a0, Math.min(a1 - 1, Math.round(mid - .5)));
        const keep = (x, y) => (across ? y : x) === best || (across ? y : x) === best + 1;
        for (let y = b[1]; y <= b[3]; y++) for (let x = b[0]; x <= b[2]; x++) if (W.grid[idx(x, y)] === 3 && !keep(x, y)) W.grid[idx(x, y)] = 2;
        const bx0 = across ? x0 : best, bx1 = across ? x1 : best + 1, by0 = across ? best : y0, by1 = across ? best + 1 : y1;
        for (let y = by0; y <= by1; y++) for (let x = bx0; x <= bx1; x++) if (water(x, y)) { W.grid[idx(x, y)] = 3; W.occupied.add(idx(x, y)); }
        W.decals = W.decals.filter(d => !old.includes(d));
        W.decals.push({ name: old[0].name, x: (bx0 + bx1 + 1) / 2 * C, y: (by0 + by1 + 1) / 2 * C, w: (bx1 - bx0 + 1) * C + 20, h: (by1 - by0 + 1) * C + 18 });
      }
      W.lavaCells = [];
      for (let i = 0; i < W.grid.length; i++) if (W.grid[i] === 2) W.lavaCells.push([i % W.COLS, (i / W.COLS) | 0]);
    }
    function dress(W) {
      straightenBridges(W);
      for (const r of W.rooms) { r.name = wording(r.name); r.kind = wording(r.kind); r.info = wording(r.info); }
      for (const g of Object.values(W.groups)) if (g.label) g.label = wording(g.label);
      if (PACK.theme_flag) W.theme[PACK.theme_flag] = true;
      // a world lighter or darker than the hell
      if (PACK.light) { W.theme.dark *= PACK.light.dark; W.theme.vignette *= PACK.light.vignette; }
      bossGate(W);
      decorate(W);
      blueLight(W);
      // last: mire, pits, furniture and fountain never block a way (world kit rule)
      const core = (typeof self !== 'undefined' && self.WorldCore) || (typeof require === 'function' && require('../world_kit/world_core.js'));
      core.clearWays(W);
      return W;
    }
    // Banners: red on floors 3, 6, 9 and 10, another colour on every other floor; every banner of a
    // floor (boss gate and rooms) has the floor's colour. Floor 10 burns blue at the gate and in the
    // boss room.
    function bossGate(W) {
      const colour = PACK.gate_banner[W.n], floorBanner = colour ? 'boss_banner_' + colour : 'boss_banner';
      for (const w of W.wallDecor) if (w.name === 'boss_banner' || /^banner_/.test(w.name)) w.name = floorBanner;
      if (W.n !== 10) return;
      const C = 96, gateRoom = W.rooms.find(r => r.gate), boss = W.rooms.find(r => r.type === 'boss');
      const nearGate = (x, y) => gateRoom && Math.abs(x - gateRoom.gate.cx) < 4 * C && Math.abs(y - (gateRoom.gate.y1 + 1) * C) < 2 * C;
      const inBoss = (x, y) => x >= boss.bx * C - C && x <= (boss.bx + boss.bw + 1) * C && y >= boss.by * C - C && y <= (boss.by + boss.bh + 1) * C;
      for (const w of W.wallDecor) if (w.name === 'wall_torch_hook' && (nearGate(w.x, w.y + 70) || inBoss(w.x, w.y))) w.name = 'wall_torch_blue';
      for (const p of W.props) if (inBoss(p.x, p.y) && /^brazier/.test(p.name)) p.name = 'brazier_blue';
      for (const l of W.lights) if (nearGate(l.x, l.y) || inBoss(l.x, l.y)) l.c = PACK.blue;
      // a ring of blue fire bowls around the final arena
      const idx = (x, y) => y * W.COLS + x, cx = boss.bx + boss.bw / 2, cy = boss.by + boss.bh / 2;
      for (let k = 0; k < 8; k++) {
        const a = k / 8 * Math.PI * 2 + Math.PI / 8, x = Math.floor(cx + Math.cos(a) * boss.bw * .36), y = Math.floor(cy + Math.sin(a) * boss.bh * .36);
        if (W.roomAt[idx(x, y)] !== boss.index || W.grid[idx(x, y)] !== 1 || W.occupied.has(idx(x, y))) continue;
        const px = (x + .5) * C, py = (y + .9) * C;
        W.props.push({ name: 'brazier_blue', x: px, y: py, flip: false, layer: 'obj', solid: [px - 30, py - 30, px + 30, py] });
        W.occupied.add(idx(x, y));
        W.lights.push({ x: px, y: py - 70, r: 330, c: PACK.blue, f: k });
      }
    }
    // every blue fire bowl of the world gives the same faint blue
    function blueLight(W) {
      for (const p of W.props) if (PACK.blue_props.includes(p.name)) for (const l of W.lights) if (Math.abs(l.x - p.x) < 2 && l.y < p.y) l.c = PACK.blue;
    }

    // The world's dressing on top of the core's: now and then blood and moss on the floor, furniture against
    // the north walls, breakable urns, barrels and crates along the walls (rune stones, a heart, or
    // undead from crates), and chests in fight rooms that may be mimics.
    function decorate(W) {
      const C = 96, idx = (x, y) => y * W.COLS + x;
      let a = (W.seed * 7 + 13) | 0;
      const rnd = () => { a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
      const pick = list => list[Math.floor(rnd() * list.length)];
      const inRoom = (r, x, y) => W.roomAt[idx(x, y)] === r.index;
      const nearDoor = (r, x, y, d) => r.doors.some(dd => Math.hypot((x + .5) * C - dd.cx, (y + .5) * C - dd.cy) < d * C);
      const free = (r, x, y) => inRoom(r, x, y) && W.grid[idx(x, y)] === 1 && !W.occupied.has(idx(x, y)) && !W.reserved.has(idx(x, y));
      const solidNear = (x, y, d) => W.props.some(p => p.solid && Math.hypot(p.x - (x + .5) * C, p.y - (y + .9) * C) < d * C) || W.ents.some(e => (e.type === 'crate' || e.type === 'chest') && Math.hypot(e.x - (x + .5) * C, e.y - (y + .85) * C) < d * C);
      const take = (x, y) => W.occupied.add(idx(x, y));
      const prop = (name, x, y, flip) => {
        const f = PACK.foot[name], px = (x + (f[2] === 2 ? 1 : .5)) * C, py = (y + .92) * C;
        W.props.push({ name, x: px, y: py, flip, layer: 'obj', solid: [px - f[0] / 2, py - f[1], px + f[0] / 2, py] });
        for (let k = 0; k < f[2]; k++) take(x + k, y);
        if (name === 'candelabra') W.lights.push({ x: px, y: py - 100, r: 210, c: '255,190,110', f: x });
      };
      const ent = (o, r, x, y) => { o.x = (x + .5) * C; o.y = (y + .85) * C; o.room = r.index; W.ents.push(o); take(x, y); return o; };
      const breakable = (r, x, y) => {
        const look = pick(PACK.break_set), v = rnd(), crate = look.startsWith('crate');
        ent({ type: 'crate', look, hp: crate ? 2 : 1, drop: crate && v > .72 ? 'undead' : v < .45 ? 'none' : v < .85 ? 'gem' : 'heart' }, r, x, y);
      };
      const blood = .005 + W.n * .0012;
      for (const r of W.rooms) {
        // floor: now and then blood (a little more on deeper floors) or moss
        for (const [x, y] of r.cells) {
          if (W.grid[idx(x, y)] !== 1 || W.reserved.has(idx(x, y))) continue;
          const edge = !inRoom(r, x - 1, y) || !inRoom(r, x + 1, y) || !inRoom(r, x, y - 1) || !inRoom(r, x, y + 1), v = rnd();
          if (v < blood) W.decals.push({ name: pick(['blood_a', 'blood_b', 'blood_c', 'blood_d', 'blood_e', 'blood_f']), x: (x + .5) * C, y: (y + .5) * C, a: .92 });
          else if (v < blood + (edge ? .045 : .01)) W.decals.push({ name: pick(['moss_a', 'moss_b', 'moss_c']), x: (x + .5) * C, y: (y + .5) * C, a: .95 });
        }
        if (!['combat', 'start', 'treasure', 'portal'].includes(r.type) || r.gtype === 'key') continue;
        const big = r.slots.length;
        // furniture against the north wall
        const north = r.cells.filter(([x, y]) => free(r, x, y) && !inRoom(r, x, y - 1) && !nearDoor(r, x, y, 2.6));
        for (let k = 0, n = Math.round(big * 1.1 + rnd()); k < n && north.length; k++) {
          const [x, y] = north.splice(Math.floor(rnd() * north.length), 1)[0], name = pick(PACK.wall_set);
          if (!free(r, x, y) || solidNear(x, y, 1.6)) continue;
          if (PACK.foot[name][2] === 2 && !(free(r, x + 1, y) && !inRoom(r, x + 1, y - 1))) continue;
          prop(name, x, y, rnd() < .5);
        }
        // breakable urns, barrels and crates along the walls
        const edge = r.cells.filter(([x, y]) => free(r, x, y) && (!inRoom(r, x - 1, y) || !inRoom(r, x + 1, y) || !inRoom(r, x, y + 1) || !inRoom(r, x, y - 1)) && !nearDoor(r, x, y, 2.6));
        for (let k = 0, n = Math.round(big * 1.4 + rnd() * 2); k < n && edge.length; k++) {
          const [x, y] = edge.splice(Math.floor(rnd() * edge.length), 1)[0];
          if (!free(r, x, y) || solidNear(x, y, 1.3)) continue;
          breakable(r, x, y);
        }
        // a chest in some fight rooms: six in ten are mimics, the rest hold a little
        if (r.type === 'combat' && !r.seq && rnd() < .35) {
          const spots = r.cells.filter(([x, y]) => free(r, x, y) && free(r, x, y + 1) && !nearDoor(r, x, y, 3) && !solidNear(x, y, 1.5));
          if (spots.length) {
            const [x, y] = spots[Math.floor(rnd() * spots.length)];
            ent(rnd() < PACK.mimic_fight ? { type: 'chest', mimic: true, loot: { gems: 0 } } : { type: 'chest', loot: { gems: 1 + Math.floor(rnd() * 2) } }, r, x, y);
          }
        }
      }
      // treasure chests (loot room, hidden rooms behind skull heaps) bite rarely
      for (const e of W.ents) if (e.type === 'chest' && !e.mimic && ['treasure', 'secret'].includes(W.rooms[e.room].gtype) && rnd() < PACK.mimic_treasure) e.mimic = true;
    }
    // A run: one random number decides all ten floors. Each floor's layout seed is derived from it,
    // so the same run number always rebuilds the same world (save games, bug reports), while a new
    // run number gives new layouts. Titles, bosses and difficulty stay fixed per floor.
    function floorSeed(run, n) {
      let h = (Math.imul(run >>> 0, 2654435761) ^ Math.imul(n, 40503)) >>> 0;
      h = Math.imul(h ^ (h >>> 16), 2246822507) >>> 0; h = Math.imul(h ^ (h >>> 13), 3266489909) >>> 0;
      return ((h ^ (h >>> 16)) >>> 0) % 2147483647 || 1;
    }
    function forRun(run) {
      const floors = PACK.floors.map(P => P && Object.assign({}, P, { seed: floorSeed(run, P.n) }));
      return { floors, circles: PACK.circles, names: PACK.names, suffixes: PACK.suffixes };
    }
    const newRun = () => (Math.random() * 2147483646 + 1) >>> 0;
    return { FLOORS: PACK.floors, CIRCLES: PACK.circles, NAMES: PACK.names, SUFFIXES: PACK.suffixes, PACK, wording, dress, floorSeed, forRun, newRun,
      opts: { floors: PACK.floors, circles: PACK.circles, names: PACK.names, suffixes: PACK.suffixes } };
  }
  return { make };
});

// The ten crypt floors (Story 1, Krypta der Verdammten) on the world kit generator.
// Runs on the shared world kit generator (tools/world_kit/world_core.js); only the
// floor values, names and wording are the crypt's. Poison mire takes the place of lava, grave-gas
// vents the place of fire vents, soul bowls the place of fire bowls.
// Use: WorldCore.buildFloor(n, sizes, KryptaFloors.forRun(run)), then KryptaFloors.dress(W).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.KryptaFloors = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';
  // Floor titles are the crypt's ten floors from assets/data/dungeon_rooms.json.
  const FLOORS = [
    null,
    { n: 1, title: 'Vorhalle der Verdammten', circle: 0, seed: 31101, gc: 7, gr: 6, path: 13, rooms: 22, lava: .12, spikes: .2, vents: .15, holes: .45, pits: .3, loops: .35, mainLock: true, fire: 3, seq: false, boss: { name: 'Knochenwächter', hp: 46, summon: 4, ring: 0 } },
    { n: 2, title: 'Knochengalerien', circle: 0, seed: 31202, gc: 7, gr: 6, path: 13, rooms: 22, lava: .15, spikes: .25, vents: .2, holes: .45, pits: .35, loops: .35, mainLock: true, fire: 3, seq: true, boss: { name: 'Grabmutter', hp: 60, summon: 4, ring: 0 } },
    { n: 3, title: 'Sarkophaghof', circle: 0, seed: 31303, gc: 7, gr: 6, path: 14, rooms: 23, lava: .25, spikes: .25, vents: .25, holes: .45, pits: .35, loops: .35, mainLock: true, fire: 0, seq: true, boss: { name: 'Moderkoloss', hp: 90, summon: 3.6, ring: 3.4, mini: true } },
    { n: 4, title: 'Kapelle der verlorenen Seelen', circle: 1, seed: 31404, gc: 8, gr: 6, path: 15, rooms: 25, lava: .25, river: .2, spikes: .25, vents: .35, holes: .35, pits: .25, loops: .3, mainLock: true, fire: 4, seq: false, shooters: true, boss: { name: 'Nekromantenfürst', hp: 105, summon: 3.6, ring: 3.2 } },
    { n: 5, title: 'Verschlungene Katakomben', circle: 1, seed: 31505, gc: 8, gr: 6, path: 16, rooms: 26, lava: .35, river: .3, spikes: .3, vents: .4, holes: .4, pits: .3, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Truhenfresser', hp: 120, summon: 3.4, ring: 3.0 } },
    { n: 6, title: 'Garten der Graburnen', circle: 1, seed: 31606, gc: 8, gr: 6, path: 16, rooms: 26, lava: .5, river: .45, spikes: .3, vents: .45, holes: .3, pits: .25, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Frostleiche', hp: 160, summon: 3.2, ring: 2.6, mini: true } },
    { n: 7, title: 'Reliquienarchiv', circle: 2, seed: 31707, gc: 8, gr: 7, path: 17, rooms: 28, lava: .3, river: .25, spikes: .45, vents: .4, holes: .5, pits: .4, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Der Archivar', hp: 175, summon: 3.0, ring: 2.6 } },
    { n: 8, title: 'Grab der Namenlosen', circle: 2, seed: 31808, gc: 8, gr: 7, path: 18, rooms: 29, lava: .4, river: .3, spikes: .5, vents: .45, holes: .5, pits: .5, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Leerenbrut', hp: 190, summon: 2.8, ring: 2.4 } },
    { n: 9, title: 'Trauerhallen', circle: 2, seed: 31909, gc: 8, gr: 7, path: 18, rooms: 30, lava: .45, river: .35, spikes: .55, vents: .5, holes: .5, pits: .5, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Knochenkoloss', hp: 240, summon: 2.6, ring: 2.0, mini: true } },
    { n: 10, title: 'Thron der Verdammten', circle: 3, seed: 32010, gc: 8, gr: 7, path: 18, rooms: 30, lava: .6, river: .5, spikes: .55, vents: .6, holes: .45, pits: .45, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, final: true, boss: { name: 'Leerenrufer', hp: 340, summon: 2.4, ring: 1.6, final: true } },
  ];
  const CIRCLES = ['Ring I · Obere Gruft', 'Ring II · Katakomben', 'Ring III · Tiefe Grablege', 'Ring IV · Thron der Leere'];
  const NAMES = [['Gebein', 'Staub', 'Grab', 'Gruft', 'Moder', 'Knochen', 'Schädel', 'Kerzen'], ['Urnen', 'Sarg', 'Kapellen', 'Moder', 'Seelen', 'Gebet', 'Asche', 'Weihe'],
    ['Reliquien', 'Trauer', 'Ketten', 'Runen', 'Totenwacht', 'Gebein', 'Grabes', 'Klage'], ['Leeren', 'Thron', 'Schatten', 'Seelen', 'Verdammnis', 'Abgrund', 'Nacht', 'Fluch']];
  const SUFFIXES = ['halle', 'kammer', 'gang', 'grube', 'kreuz', 'gruft', 'galerie', 'nische', 'pforte', 'kapelle', 'krypta', 'stiege', 'saal', 'hof', 'gewölbe', 'zelle'];
  // Hell wording in the core's room texts and group labels, in crypt terms (longest first).
  const WORDS = [
    ['Glutschlüssel', 'Bronzeschlüssel'], ['Knochenschlüssel', 'Silberschlüssel'], ['Dämonenschlüssel', 'Goldschlüssel'],
    ['Feuerschalen', 'Seelenschalen'], ['Feuerschale', 'Seelenschale'], ['Runenplatten', 'Grabplatten'], ['Feuerplatte', 'Weiheplatte'],
    ['Portalkammer', 'Abstiegskammer'], ['Portal zur nächsten Etage', 'Treppe hinab zur nächsten Etage'],
    ['Herzschrein', 'Weiheschrein'], ['Lavagraben', 'Modergraben'], ['Lava', 'Moder'], ['Glutschlote', 'Grabgasschlote'], ['Glutschlot', 'Grabgasschlot'],
    ['Hort: ', 'Gruft: '], ['Der Hüter der Etage wartet.', 'Der Herr dieser Etage wartet.'],
  ];
  const crypt = text => WORDS.reduce((t, [a, b]) => t.split(a).join(b), text || '');
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
    for (const r of W.rooms) { r.name = crypt(r.name); r.kind = crypt(r.kind); r.info = crypt(r.info); }
    for (const g of Object.values(W.groups)) if (g.label) g.label = crypt(g.label);
    W.theme.crypt = true;
    // a touch lighter than the hell
    W.theme.dark *= .86; W.theme.vignette *= .85;
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
  const GATE_BANNER = { 1: 'blue', 2: 'green', 4: 'purple', 5: 'gold', 7: 'teal', 8: 'pink' };
  // blue fire lights the room like any fire, with only a breath of blue in it
  const BLUE = '190,205,245';
  function bossGate(W) {
    const colour = GATE_BANNER[W.n], floorBanner = colour ? 'boss_banner_' + colour : 'boss_banner';
    for (const w of W.wallDecor) if (w.name === 'boss_banner' || /^banner_/.test(w.name)) w.name = floorBanner;
    if (W.n !== 10) return;
    const C = 96, gateRoom = W.rooms.find(r => r.gate), boss = W.rooms.find(r => r.type === 'boss');
    const nearGate = (x, y) => gateRoom && Math.abs(x - gateRoom.gate.cx) < 4 * C && Math.abs(y - (gateRoom.gate.y1 + 1) * C) < 2 * C;
    const inBoss = (x, y) => x >= boss.bx * C - C && x <= (boss.bx + boss.bw + 1) * C && y >= boss.by * C - C && y <= (boss.by + boss.bh + 1) * C;
    for (const w of W.wallDecor) if (w.name === 'wall_torch_hook' && (nearGate(w.x, w.y + 70) || inBoss(w.x, w.y))) w.name = 'wall_torch_blue';
    for (const p of W.props) if (inBoss(p.x, p.y) && /^brazier/.test(p.name)) p.name = 'brazier_blue';
    for (const l of W.lights) if (nearGate(l.x, l.y) || inBoss(l.x, l.y)) l.c = BLUE;
    // a ring of blue fire bowls around the final arena
    const idx = (x, y) => y * W.COLS + x, cx = boss.bx + boss.bw / 2, cy = boss.by + boss.bh / 2;
    for (let k = 0; k < 8; k++) {
      const a = k / 8 * Math.PI * 2 + Math.PI / 8, x = Math.floor(cx + Math.cos(a) * boss.bw * .36), y = Math.floor(cy + Math.sin(a) * boss.bh * .36);
      if (W.roomAt[idx(x, y)] !== boss.index || W.grid[idx(x, y)] !== 1 || W.occupied.has(idx(x, y))) continue;
      const px = (x + .5) * C, py = (y + .9) * C;
      W.props.push({ name: 'brazier_blue', x: px, y: py, flip: false, layer: 'obj', solid: [px - 30, py - 30, px + 30, py] });
      W.occupied.add(idx(x, y));
      W.lights.push({ x: px, y: py - 70, r: 330, c: BLUE, f: k });
    }
  }
  // every blue fire bowl in the crypt gives the same faint blue
  function blueLight(W) {
    for (const p of W.props) if (/^(brazier_bowl|brazier_blue|bowl_blue)$/.test(p.name)) for (const l of W.lights) if (Math.abs(l.x - p.x) < 2 && l.y < p.y) l.c = BLUE;
  }

  // Crypt dressing on top of the core's: now and then blood and moss on the floor, furniture against
  // the north walls, breakable urns, barrels and crates along the walls (rune stones, a heart, or
  // undead from crates), and chests in fight rooms that may be mimics.
  const FOOT = {   // name: [solid width, solid depth, cells wide]
    table_a: [104, 30, 2], table_b: [110, 30, 2], table_c: [140, 30, 2], candelabra: [30, 20, 1], crate_pile: [80, 34, 1],
    sacks_b: [90, 26, 1], moss_rubble_a: [70, 30, 1], moss_rubble_b: [80, 28, 1], moss_ruin: [70, 34, 1],
  };
  const WALL_SET = ['table_a', 'table_b', 'table_c', 'candelabra', 'crate_pile', 'moss_ruin', 'sacks_b', 'candelabra', 'moss_rubble_a', 'moss_rubble_b'];
  const BREAK_SET = ['barrel_a', 'barrel_b', 'barrel_c', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'crate_a', 'crate_b', 'crate_c'];
  // chests: in a fight room six in ten bite; a treasure chest bites rarely
  const MIMIC_FIGHT = .6, MIMIC_TREASURE = .15;
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
      const f = FOOT[name], px = (x + (f[2] === 2 ? 1 : .5)) * C, py = (y + .92) * C;
      W.props.push({ name, x: px, y: py, flip, layer: 'obj', solid: [px - f[0] / 2, py - f[1], px + f[0] / 2, py] });
      for (let k = 0; k < f[2]; k++) take(x + k, y);
      if (name === 'candelabra') W.lights.push({ x: px, y: py - 100, r: 210, c: '255,190,110', f: x });
    };
    const ent = (o, r, x, y) => { o.x = (x + .5) * C; o.y = (y + .85) * C; o.room = r.index; W.ents.push(o); take(x, y); return o; };
    const breakable = (r, x, y) => {
      const look = pick(BREAK_SET), v = rnd(), crate = look.startsWith('crate');
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
        const [x, y] = north.splice(Math.floor(rnd() * north.length), 1)[0], name = pick(WALL_SET);
        if (!free(r, x, y) || solidNear(x, y, 1.6)) continue;
        if (FOOT[name][2] === 2 && !(free(r, x + 1, y) && !inRoom(r, x + 1, y - 1))) continue;
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
          ent(rnd() < MIMIC_FIGHT ? { type: 'chest', mimic: true, loot: { gems: 0 } } : { type: 'chest', loot: { gems: 1 + Math.floor(rnd() * 2) } }, r, x, y);
        }
      }
    }
    // treasure chests (loot room, hidden rooms behind skull heaps) bite rarely
    for (const e of W.ents) if (e.type === 'chest' && !e.mimic && ['treasure', 'secret'].includes(W.rooms[e.room].gtype) && rnd() < MIMIC_TREASURE) e.mimic = true;
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
    const floors = FLOORS.map(P => P && Object.assign({}, P, { seed: floorSeed(run, P.n) }));
    return { floors, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES };
  }
  const newRun = () => (Math.random() * 2147483646 + 1) >>> 0;
  // the pack as plain data (the Godot port reads it from assets/data/krypta_world.json, see export_world.js)
  const PACK = { floors: FLOORS, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES, words: WORDS, gate_banner: GATE_BANNER, blue: BLUE, foot: FOOT, wall_set: WALL_SET, break_set: BREAK_SET, mimic_fight: MIMIC_FIGHT, mimic_treasure: MIMIC_TREASURE };
  return { FLOORS, CIRCLES, NAMES, SUFFIXES, PACK, crypt, dress, floorSeed, forRun, newRun, opts: { floors: FLOORS, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES } };
});

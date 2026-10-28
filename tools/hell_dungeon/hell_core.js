/* Hell-Dungeon floor core: floor data, seeded generator and dressing rules.
 * Pure data in, pure data out: buildFloor(n, sizes) returns everything the
 * browser preview and the Godot bake need. No drawing, no DOM.
 */
(function (root) {
'use strict';
const C = 96, SW = 14, SH = 11;

// ---------- floor parameters: deeper = harder and more hellish ----------
const CIRCLES = ['Kreis I · Aschenvorhof', 'Kreis II · Lavaschlund', 'Kreis III · Kettenkerker', 'Kreis IV · Höllenthron'];
const FLOORS = [
  null,
  { n: 1, title: 'Aschenvorhof', circle: 0, handmade: true, boss: { name: 'Glutwächter', hp: 46, summon: 4, ring: 0 } },
  { n: 2, title: 'Rußgalerien', circle: 0, seed: 7101, gc: 7, gr: 6, path: 13, rooms: 22, lava: .25, spikes: .2, vents: .25, holes: .45, pits: .3, loops: .35, mainLock: true, fire: 3, seq: false, boss: { name: 'Dreischlund', hp: 60, summon: 4, ring: 0 } },
  { n: 3, title: 'Schwefelpforte', circle: 0, seed: 7303, gc: 7, gr: 6, path: 14, rooms: 23, lava: .3, spikes: .25, vents: .3, holes: .45, pits: .35, loops: .35, mainLock: true, fire: 0, seq: true, boss: { name: 'Ignaroth · Salamander', hp: 90, summon: 3.6, ring: 3.4, mini: true } },
  { n: 4, title: 'Glutkessel', circle: 1, seed: 8404, gc: 8, gr: 6, path: 15, rooms: 25, lava: .55, river: .45, spikes: .25, vents: .45, holes: .35, pits: .2, loops: .3, mainLock: true, fire: 4, seq: false, shooters: true, boss: { name: 'Kesselbrut', hp: 105, summon: 3.6, ring: 3.2 } },
  { n: 5, title: 'Schlackenstrom', circle: 1, seed: 8505, gc: 8, gr: 6, path: 16, rooms: 26, lava: .6, river: .55, spikes: .3, vents: .5, holes: .35, pits: .2, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Seelenhirte', hp: 120, summon: 3.4, ring: 3.0 } },
  { n: 6, title: 'Feuerschlund', circle: 1, seed: 8606, gc: 8, gr: 6, path: 16, rooms: 26, lava: .7, river: .6, spikes: .3, vents: .55, holes: .3, pits: .25, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Ignaroth · Jungdrache', hp: 160, summon: 3.2, ring: 2.6, mini: true } },
  { n: 7, title: 'Kettenzwinger', circle: 2, seed: 9707, gc: 8, gr: 7, path: 17, rooms: 28, lava: .4, river: .3, spikes: .5, vents: .4, holes: .5, pits: .45, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Kerkermeister', hp: 175, summon: 3.0, ring: 2.6 } },
  { n: 8, title: 'Klagegruben', circle: 2, seed: 9808, gc: 8, gr: 7, path: 18, rooms: 29, lava: .45, river: .35, spikes: .55, vents: .45, holes: .5, pits: .5, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Klagender Hüter', hp: 190, summon: 2.8, ring: 2.4 } },
  { n: 9, title: 'Blutrunen', circle: 2, seed: 9909, gc: 8, gr: 7, path: 18, rooms: 30, lava: .55, river: .4, spikes: .6, vents: .5, holes: .5, pits: .5, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Ignaroth · Glutdrache', hp: 240, summon: 2.6, ring: 2.0, mini: true } },
  { n: 10, title: 'Thron der Tiefe', circle: 3, seed: 11010, gc: 8, gr: 7, path: 18, rooms: 30, lava: .75, river: .6, spikes: .55, vents: .6, holes: .45, pits: .45, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, final: true, boss: { name: 'Ignaroth · Obsidianform', hp: 340, summon: 2.4, ring: 1.6, final: true } },
];
// look per floor: darkness, red grade, ember density, hot floor share
function themeFor(n) {
  const t = (n - 1) / 9;
  return { dark: .6 + t * .2, grade: t * .16, vignette: .25 + t * .45, embers: 2 + Math.round(t * 5), hot: .18 + t * .4, wallGlow: t, circle: FLOORS[n].circle };
}
function difficultyFor(n) { return { hp: 1 + (n - 1) * .16, speed: 1 + (n - 1) * .04, extra: Math.floor((n - 1) / 3), shooters: !!FLOORS[n].shooters }; }

// ---------- floor 1: the approved handmade layout ----------
const F1 = {
  gc: 7, gr: 6,
  rooms: [
    { id: 'start', name: 'Aschentreppe', kind: 'Eingang', type: 'start', slots: [[0, 5]], shape: 'oct', cut: 3, icon: 'icon_door', info: 'Ankunft. Die Treppe nach oben ist versiegelt.', f: [['wall', 'door_stairs', 6, 0, -26], ['decal', 'rune_big', 6, 4.6], ['keep', 4, 3, 4, 4], ['spawn', 6, 5.6]] },
    { id: 'c1', name: 'Aschengang', kind: 'Kampfraum', type: 'combat', slots: [[1, 5], [2, 5]], holes: [[6, 3, 3, 3], [17, 3, 3, 3]], mobs: 5, info: 'Lange Halle mit zwei Mauerblöcken und Lavabecken.', f: [['lava', 11, 6, 4, 2], ['prop', 'spires_lava', 10.6, 7.9], ['prop', 'spire_small', 15.4, 6.2], ['wall', 'cage_hang', 7.5, 6, 0], ['wall', 'cage_hang', 18.5, 6, 0]] },
    { id: 'c2', name: 'Schlackenkreuz', kind: 'Kampfraum', type: 'combat', slots: [[1, 4]], shape: 'cross', mobs: 4, info: 'Kreuzförmig, zwei Glutschlote in den Seitenarmen.', f: [['vent', 1.5, 4.5, 0], ['vent', 10.5, 4.5, 1.5], ['decal', 'rune_small', 6, 4.5]] },
    { id: 'c3', name: 'Säulenhalle', kind: 'Kampfraum', type: 'combat', slots: [[1, 3], [2, 3]], mobs: 6, info: 'Sieben Runensäulen als Deckung.', f: [['prop', 'rune_pillar_a', 4.5, 2.7], ['prop', 'rune_pillar_a', 9.5, 2.7], ['prop', 'rune_pillar_a', 16.5, 2.7], ['prop', 'rune_pillar_a', 21.5, 2.7], ['prop', 'rune_pillar_a', 9.5, 7.7], ['prop', 'rune_pillar_a', 16.5, 7.7], ['prop', 'rune_pillar_a', 21.5, 7.7], ['tile', 'floor_06', 7, 4], ['tile', 'floor_06', 12, 4], ['tile', 'floor_06', 13, 4], ['tile', 'floor_06', 19, 4], ['lava', 1, 1, 2, 2], ['lava', 23, 6, 2, 2], ['decal', 'rune_big', 13, 4.5]] },
    { id: 'cs1', name: 'Knochengrube', kind: 'Kampfraum · Schlüssel', type: 'combat', slots: [[0, 3], [0, 4]], shape: 'oct', cut: 3, mobs: 6, drop: 'A', info: 'Der Sieg lässt den Glutschlüssel fallen.', f: [['pit', 3, 7], ['pit', 8, 10], ['pit', 3, 13], ['pit', 8, 16], ['prop', 'skull_pile', 6, 17.6], ['prop', 'coal_skulls', 2.5, 10.6]] },
    { id: 'p1', name: 'Feuerschalen-Kammer', kind: 'Kampf · Rätsel', type: 'combat', slots: [[3, 3]], shape: 'oct', cut: 3, mobs: 4, icon: 'icon_scroll', info: 'Vier erloschene Schalen. Alle entzünden öffnet das Südtor.', f: [['brazier', 2.5, 2.7, 'p1'], ['brazier', 9.5, 2.7, 'p1'], ['brazier', 2.5, 7.4, 'p1'], ['brazier', 9.5, 7.4, 'p1'], ['decal', 'rune_big', 6, 4.5], ['keep', 4, 3, 4, 3]] },
    { id: 'c4', name: 'Glutkanal', kind: 'Kampfraum', type: 'combat', slots: [[3, 4], [4, 4], [3, 5]], mobs: 7, info: 'L-förmig, hinter dem Lavaband im Südarm liegt eine Bonusecke.', f: [['lava', 0, 13, 5, 2], ['lava', 7, 13, 5, 2], ['bridge', 5, 13, 2, 2, 'v'], ['heart', 2.5, 17.6], ['gem', 8.5, 17.2], ['gem', 9.5, 18.0], ['gem', 7.6, 18.2], ['prop', 'spires_lava', .7, 12.7], ['prop', 'spire_big', 11.4, 12.8], ['prop', 'brazier_floor', 6, 19.6], ['lava', 22, 6, 3, 2], ['decal', 'rune_small', 19.5, 4.5]] },
    { id: 'c5', name: 'Stachelkreuz', kind: 'Kampfraum', type: 'combat', slots: [[5, 3], [5, 4]], mobs: 6, info: 'Stachelfeld im Wechseltakt, Runensteine dahinter. Die Ostwand ist rissig.', f: [['spikes', 2, 3, 9, 7], ['gem', 3.5, 1.6], ['gem', 6, 1.6], ['gem', 8.5, 1.6], ['vent', 1.5, 12.5, .4], ['vent', 10.5, 18.5, 1.9], ['keep', 0, 0, 12, 9]] },
    { id: 'sec', name: 'Vergessene Gruft', kind: 'Geheimraum', type: 'secret', slots: [[6, 4]], shape: 'oct', cut: 4, icon: 'rune_gem', info: 'Truhe, Runensteine und ein Herz.', f: [['chest', 8, 3.1, 8, false, true], ['gem', 2.6, 6.4], ['gem', 3.6, 7.2], ['heart', 8.8, 6.4], ['decal', 'demon_head', 6, 4.6]] },
    { id: 't1', name: 'Lavatresor', kind: 'Schatzraum', type: 'treasure', slots: [[5, 5]], icon: 'icon_chest', info: 'Truhe auf einer Insel im Lavagraben.', f: [['lava', 3, 2, 2, 1], ['lava', 7, 2, 2, 1], ['bridge', 5, 2, 2, 1, 'v'], ['lava', 3, 3, 1, 4], ['lava', 8, 3, 1, 4], ['lava', 4, 6, 4, 1], ['chest', 6, 5, 10, true]] },
    { id: 'c6', name: 'Kettenhalle', kind: 'Kampfraum', type: 'combat', slots: [[4, 2], [4, 3]], holes: [[4, 6, 4, 8]], mobs: 6, info: 'Hohe Halle mit Mauerkern, man kann ihn umrunden.', f: [['wall', 'cage_hang', 5, 14, 0], ['wall', 'chain_hang', 6.6, 14, 0], ['wall', 'cage_hang', 2, 0, 2], ['wall', 'hanging_brazier', 9.4, 0, 4]] },
    { id: 'c10', name: 'Ofenkammer', kind: 'Kampfraum', type: 'combat', slots: [[5, 2]], shape: 'oct', cut: 3, mobs: 4, reward: { heart: true, gems: 2 }, info: 'Seitenraum mit Belohnung.', f: [['vent', 6, 4.5, 1], ['prop', 'coal_skulls', 3.2, 2.6], ['prop', 'coal_skulls', 8.8, 7.4]] },
    { id: 'c7', name: 'Ascheallee', kind: 'Kampfraum', type: 'combat', slots: [[2, 2], [3, 2]], mobs: 5, info: 'Ein Lavastrom teilt die Halle.', f: [['lava', 12, 0, 2, 4], ['lava', 12, 6, 2, 3], ['bridge', 12, 4, 2, 2, 'h'], ['prop', 'spires_lava', 11.4, 2.4], ['prop', 'spire_big_t', 14.7, 7.9], ['prop', 'rocks_lava', 14.5, 1.4]] },
    { id: 'c8', name: 'Schädelkreuzung', kind: 'Kampfraum', type: 'combat', slots: [[1, 1], [2, 1], [1, 2]], mobs: 7, info: 'L-förmiger Knoten mit vier Ausgängen.', f: [['prop', 'rune_pillar_c', 16.5, 2.7], ['prop', 'rune_pillar_c', 22.5, 2.7], ['prop', 'rune_pillar_c', 22.5, 6.6], ['prop', 'skull_obelisk', 3, 17.6], ['prop', 'skull_obelisk', 9, 17.6, true], ['decal', 'rune_plate', 6, 13.5]] },
    { id: 'cs2', name: 'Käfiggruft', kind: 'Kampfraum · Schlüssel', type: 'combat', slots: [[0, 2]], shape: 'cross', mobs: 5, drop: 'B', info: 'Der Sieg lässt den Knochenschlüssel fallen.', f: [['pit', 5, 1], ['pit', 6, 7], ['vent', 2, 4.5, .8]] },
    { id: 'p2', name: 'Runenkammer', kind: 'Kampf · Rätsel', type: 'combat', slots: [[0, 1]], shape: 'oct', cut: 3, mobs: 3, icon: 'icon_scroll', info: 'Vier Runenplatten betreten öffnet den Opferschatz.', f: [['plate', 3.5, 2.5, 'p2'], ['plate', 8.5, 2.5, 'p2'], ['plate', 3.5, 6.5, 'p2'], ['plate', 8.5, 6.5, 'p2']] },
    { id: 't2', name: 'Opferschatz', kind: 'Schatzraum', type: 'treasure', slots: [[0, 0]], shape: 'oct', cut: 3, icon: 'icon_chest', info: 'Belohnung für das Runenrätsel.', f: [['chest', 6, 4, 6], ['prop', 'brazier_pillar', 4, 3.6], ['prop', 'brazier_pillar', 8, 3.6]] },
    { id: 'c9', name: 'Brandgalerie', kind: 'Kampfraum', type: 'combat', slots: [[2, 0], [3, 0]], holes: [[8, 3, 2, 3], [16, 3, 2, 3]], mobs: 6, info: 'Galerie mit zwei Mauerpfeilern vor dem Thron.', f: [['decal', 'rune_plate', 4.5, 4.5], ['decal', 'rune_plate', 21.5, 4.5], ['decal', 'rune_big', 13, 4.5]] },
    { id: 'k2', name: 'Knochenaltar', kind: 'Schlüsselraum', type: 'key', slots: [[1, 0]], icon: 'key', iconKey: 'C', info: 'Der Dämonenschlüssel liegt vor dem Altar.', f: [['prop', 'altar', 6, 2.4], ['prop', 'brazier_low', 2.9, 2.4], ['prop', 'brazier_low', 9.1, 2.4], ['key', 'C', 6, 3.95], ['decal', 'rune_small', 6, 6]] },
    { id: 'sh', name: 'Runenschrein', kind: 'Kampf · Schrein', type: 'combat', slots: [[3, 1]], shape: 'oct', cut: 3, mobs: 2, icon: 'heart', info: 'Ein Herz auf der Feuerplatte heilt.', f: [['decal', 'fire_plate', 6, 4.9], ['heart', 6, 5], ['prop', 'rune_pillar_c', 3.5, 3.4], ['prop', 'rune_pillar_c', 8.5, 3.4], ['prop', 'rune_pillar_b', 3.5, 7.4], ['prop', 'rune_pillar_b', 8.5, 7.4]] },
    { id: 'boss', name: 'Thron des Glutwächters', kind: 'Endkampf', type: 'boss', slots: [[4, 0], [5, 0], [4, 1], [5, 1]], shape: 'oct', cut: 6, mobs: 4, icon: 'icon_demon_big', info: 'Arena mit Lavarändern.', f: [['lava', 1, 7, 3, 6], ['lava', 22, 7, 3, 6], ['prop', 'brazier_demon', 7, 5], ['prop', 'brazier_demon', 19, 5], ['prop', 'brazier_demon', 7, 15.6], ['prop', 'brazier_demon', 19, 15.6], ['decal', 'rune_big', 13, 10.2], ['decal', 'rune_plate', 9.6, 10.2], ['decal', 'rune_plate', 16.4, 10.2], ['decal', 'rune_small', 13, 7.2], ['decal', 'rune_small', 13, 13.2], ['wall', 'demon_lintel', 13, 0, -36], ['prop', 'skull_obelisk', 10.2, 1.8], ['prop', 'skull_obelisk', 15.8, 1.8, true], ['keep', 9, 6, 8, 8]] },
    { id: 'pk', name: 'Portalkammer', kind: 'Schatzkammer', type: 'portal', slots: [[6, 0]], icon: 'portal', info: 'Belohnung und Portal zur nächsten Etage.', f: [['portal', 6, 2.75], ['prop', 'brazier_pillar', 3.7, 2.6], ['prop', 'brazier_pillar', 8.3, 2.6], ['chest', 9.2, 7, 12, true], ['decal', 'rune_big', 6, 5.6]] },
  ],
  doors: [['start', 'c1'], ['c1', 'c2'], ['c2', 'c3'], ['c3', 'cs1'], ['c3', 'p1'], ['p1', 'c4', 'puzzle', 'p1'], ['c4', 'c5'], ['c5', 'sec', 'secret'],
    ['c5', 't1', 'lock', 'B'], ['c4', 'c6'], ['c6', 'c7', 'lock', 'A'], ['c6', 'c10'], ['c7', 'c8'], ['c8', 'cs2'], ['c8', 'p2'],
    ['p2', 't2', 'puzzle', 'p2'], ['c8', 'c9'], ['c9', 'k2'], ['c9', 'sh'], ['c9', 'boss', 'lock', 'C'], ['boss', 'pk', 'boss']],
  groups: { p1: { kind: 'braziers', label: 'Feuerschalen' }, p2: { kind: 'plates', label: 'Runenplatten' } },
};

// ---------- seeded generator for floors 2-10 ----------
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const NAME_A = [['Asche', 'Ruß', 'Schwefel', 'Glut', 'Brand', 'Knochen', 'Schädel', 'Rauch'], ['Schlacken', 'Lava', 'Glut', 'Feuer', 'Magma', 'Brand', 'Kessel', 'Funken'], ['Ketten', 'Klage', 'Blut', 'Runen', 'Qual', 'Kerker', 'Eisen', 'Schmerz'], ['Höllen', 'Blut', 'Feuer', 'Dämonen', 'Seelen', 'Thron', 'Verdammnis', 'Abgrund']];
const NAME_B = ['halle', 'kammer', 'gang', 'grube', 'kreuz', 'gruft', 'galerie', 'schlund', 'pforte', 'zwinger', 'esse', 'kessel', 'saal', 'hof', 'nische', 'stiege'];

function generate(P) {
  const rnd = mulberry32(P.seed);
  for (let attempt = 0; attempt < 400; attempt++) { const res = tryGenerate(P, rnd); if (res) return res; }
  throw new Error('floor ' + P.n + ': no layout found');
}
function tryGenerate(P, rnd) {
  const pick = a => a[Math.floor(rnd() * a.length)];
  const key = (c, r) => c + ',' + r, inside = (c, r) => c >= 0 && r >= 0 && c < P.gc && r < P.gr;
  const occ = new Map();
  const N4 = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  const free = (c, r) => inside(c, r) && !occ.has(key(c, r));
  // 1. winding critical path of slots
  const edges = []; for (let c = 0; c < P.gc; c++) for (let r = 0; r < P.gr; r++) if (c === 0 || r === P.gr - 1) edges.push([c, r]);
  const path = [pick(edges)]; occ.set(key(...path[0]), 'path');
  let dir = null;
  while (path.length < P.path) {
    const [c, r] = path[path.length - 1];
    const opts = N4.filter(([dx, dy]) => free(c + dx, r + dy)).map(([dx, dy]) => {
      const nc = c + dx, nr = r + dy, onward = N4.filter(([ex, ey]) => free(nc + ex, nr + ey) && !(nc + ex === c && nr + ey === r)).length;
      const turn = dir && (dir[0] !== dx || dir[1] !== dy) ? 1.9 : 1;
      return { d: [dx, dy], w: onward ? turn * (1 + onward * .3) : .05 };
    });
    if (!opts.length) return null;
    let t = rnd() * opts.reduce((s, o) => s + o.w, 0), ch = opts[0];
    for (const o of opts) { t -= o.w; if (t <= 0) { ch = o; break; } }
    dir = ch.d; path.push([c + dir[0], r + dir[1]]); occ.set(key(c + dir[0], r + dir[1]), 'path');
  }
  // 2. chunk the path into rooms
  const rooms = [], doors = [];
  const mk = (slots, type, extra = {}) => { const room = Object.assign({ id: 'r' + rooms.length, slots, type, children: [] }, extra); rooms.push(room); for (const s of slots) occ.set(key(...s), room.id); return room; };
  const start = mk([path[0]], 'start', { onPath: true, depth: 0 });
  let i = 1, prev = start;
  const bossAt = path.length - 1;
  while (i < bossAt) {
    const roll = rnd(); let size = roll < .45 ? 1 : roll < .8 ? 2 : 3; size = Math.min(size, bossAt - i);
    const room = mk(path.slice(i, i + size), 'combat', { onPath: true, parent: prev, depth: prev.depth + 1 });
    doors.push({ a: prev, b: room, sa: path[i - 1], sb: path[i], kind: 'open' }); prev.children.push(room);
    prev = room; i += size;
  }
  // boss: try a 2x2 block around the last path slot, else 2 slots, else 1
  const last = path[bossAt]; let bossSlots = [last];
  occ.delete(key(...last));
  for (const [ox, oy] of [[0, 0], [-1, 0], [0, -1], [-1, -1]]) {
    const sq = [[last[0] + ox, last[1] + oy], [last[0] + ox + 1, last[1] + oy], [last[0] + ox, last[1] + oy + 1], [last[0] + ox + 1, last[1] + oy + 1]];
    if (sq.every(([c, r]) => (c === last[0] && r === last[1]) || free(c, r)) && sq.every(([c, r]) => inside(c, r))) { bossSlots = sq; break; }
  }
  if (bossSlots.length === 1) { const nb = N4.map(([dx, dy]) => [last[0] + dx, last[1] + dy]).find(([c, r]) => free(c, r)); if (nb) bossSlots = [last, nb]; }
  const boss = mk(bossSlots, 'boss', { onPath: true, parent: prev, depth: prev.depth + 1 });
  doors.push({ a: prev, b: boss, sa: path[bossAt - 1], sb: last, kind: 'open' }); prev.children.push(boss);
  // portal room next to the boss
  let portalSlot = null, portalFrom = null;
  for (const s of bossSlots) for (const [dx, dy] of N4) if (!portalSlot && free(s[0] + dx, s[1] + dy)) { portalSlot = [s[0] + dx, s[1] + dy]; portalFrom = s; }
  if (!portalSlot) return null;
  const portal = mk([portalSlot], 'portal', { parent: boss, depth: boss.depth + 1 });
  doors.push({ a: boss, b: portal, sa: portalFrom, sb: portalSlot, kind: 'boss' }); boss.children.push(portal);
  // 3. side branches until the floor is full
  const attachable = () => rooms.filter(r => r.type === 'combat' || r.type === 'start');
  let guard = 0;
  while (rooms.length < P.rooms && guard++ < 300) {
    const pool = attachable(), from = pool[Math.floor(rnd() * pool.length)];
    const cands = [];
    for (const s of from.slots) for (const [dx, dy] of N4) if (free(s[0] + dx, s[1] + dy)) cands.push([s, [s[0] + dx, s[1] + dy], [dx, dy]]);
    if (!cands.length) continue;
    const [sa, sb, d] = pick(cands);
    const slots = [sb];
    if (rnd() < .35 && free(sb[0] + d[0], sb[1] + d[1])) slots.push([sb[0] + d[0], sb[1] + d[1]]);
    const room = mk(slots, 'combat', { parent: from, depth: from.depth + 1 });
    doors.push({ a: from, b: room, sa, sb, kind: 'open' }); from.children.push(room);
  }
  if (rooms.length < P.rooms * .85) return null;
  // 4. special rooms on optional dead ends
  const optional = rooms.filter(r => !r.onPath && r.type === 'combat');
  const deadEnds = optional.filter(r => !r.children.length);
  const take = (list, fn) => { const c = list.filter(fn); if (!c.length) return null; const r = c[Math.floor(rnd() * c.length)]; list.splice(list.indexOf(r), 1); return r; };
  const doorTo = r => doors.find(d => d.b === r);
  const groups = {};
  if (P.fire) {
    const vault = take(deadEnds, r => r.slots.length === 1); if (!vault) return null;
    vault.type = 'vault'; doorTo(vault).kind = 'puzzle'; doorTo(vault).group = 'feuer';
    groups.feuer = { kind: 'braziers', label: 'Feuerschalen', spread: true };
  }
  const treasure = take(deadEnds, () => true); if (!treasure) return null;
  treasure.type = 'treasure'; doorTo(treasure).kind = 'lock'; doorTo(treasure).key = 'B';
  const keyRoom = take(deadEnds, r => !isBehind(r, treasure)) || take(optional.filter(r => r.type === 'combat' && r.children.length === 0 && r !== treasure), () => true);
  if (!keyRoom) return null;
  keyRoom.type = 'key'; keyRoom.keyItem = 'B';
  const shrine = take(deadEnds, () => true); if (shrine) shrine.type = 'shrine';
  for (const r of deadEnds) if (rnd() < .45) r.reward = rnd() < .5 ? { heart: true, gems: 1 } : { gems: 3 };
  // main-path lock: key A dropped in a branch hanging off the path before the lock
  if (P.mainLock) {
    const pathRooms = rooms.filter(r => r.onPath && r.type === 'combat');
    const lockIdx = Math.floor(pathRooms.length * .55);
    const lockRoom = pathRooms[lockIdx];
    const before = new Set(pathRooms.slice(0, lockIdx).concat([start]));
    const branch = rooms.filter(r => r.type === 'combat' && !r.onPath && before.has(rootOnPath(r)) && !r.drop);
    if (lockRoom && branch.length) {
      const holder = branch[Math.floor(rnd() * branch.length)]; holder.drop = 'A';
      const d = doorTo(lockRoom); d.kind = 'lock'; d.key = 'A';
    }
  }
  // boss key C behind the path: a key altar room off the path, or the last path room drops it
  if (P.n >= 2) {
    const d = doorTo(boss); d.kind = 'lock'; d.key = 'C';
    const near = rooms.filter(r => r.type === 'combat' && !r.drop && !isBehindLock(r, doors, boss) && r.depth >= boss.depth - 4 && r !== boss.parent);
    const holder = near.length ? near[Math.floor(rnd() * near.length)] : boss.parent;
    holder.drop = holder.drop || 'C'; if (holder.drop !== 'C') return null;
  }
  // sequence plates: a combat room on the path; solving reveals a secret room
  let seqRoom = null;
  if (P.seq) {
    seqRoom = rooms.filter(r => r.onPath && r.type === 'combat' && r.slots.length === 1 && !r.drop)[0];
    if (!seqRoom) seqRoom = rooms.filter(r => r.type === 'combat' && r.slots.length === 1 && !r.drop)[0];
    if (seqRoom) { seqRoom.seq = true; groups.seq = { kind: 'sequence', label: 'Druckplatten', reward: 'chest' }; }
  }
  // spread fire braziers: plain combat rooms only, chosen after all special rooms are fixed
  if (P.fire) {
    const vault = rooms.find(r => r.type === 'vault');
    const holders = rooms.filter(r => r.type === 'combat' && r !== vault.parent && !r.seq).sort(() => rnd() - .5).slice(0, P.fire);
    if (holders.length < P.fire) return null;
    holders.forEach(h => { h.fireBrazier = true; });
  }
  // secret room in any free slot touching a normal room
  const secretCands = [];
  for (const r of rooms) if (r.type === 'combat' || r.type === 'start') for (const s of r.slots) for (const [dx, dy] of N4) if (free(s[0] + dx, s[1] + dy)) secretCands.push([r, s, [s[0] + dx, s[1] + dy]]);
  if (secretCands.length) {
    const [from, sa, sb] = secretCands[Math.floor(rnd() * secretCands.length)];
    const sec = mk([sb], 'secret', { parent: from, depth: from.depth + 1 });
    const dd = { a: from, b: sec, sa, sb, kind: 'secret' };
    doors.push(dd); from.children.push(sec);
  }
  // 5. loops between neighbouring rooms with the same gate signature
  const sig = r => { const out = []; let cur = r; while (cur.parent) { const d = doorTo(cur); if (d.kind !== 'open') out.push(doors.indexOf(d)); cur = cur.parent; } return out.sort().join(','); };
  const plain = new Set(['combat', 'start']);
  for (const [k, id] of occ) {
    const [c, r] = k.split(',').map(Number);
    for (const [dx, dy] of [[1, 0], [0, 1]]) {
      const ok = occ.get(key(c + dx, r + dy)); if (!ok || ok === id) continue;
      const A = rooms.find(x => x.id === id), B = rooms.find(x => x.id === ok);
      if (!plain.has(A.type) || !plain.has(B.type)) continue;
      if (doors.some(d => (d.a === A && d.b === B) || (d.a === B && d.b === A))) continue;
      if (sig(A) !== sig(B) || rnd() > P.loops) continue;
      doors.push({ a: A, b: B, sa: [c, r], sb: [c + dx, r + dy], kind: 'open', loop: true });
    }
  }
  return { rooms, doors, groups };
}
function isBehind(r, target) { let cur = r; while (cur) { if (cur === target) return true; cur = cur.parent; } return false; }
function rootOnPath(r) { let cur = r; while (cur && !cur.onPath) cur = cur.parent; return cur; }
function isBehindLock(r, doors, boss) { let cur = r; while (cur.parent) { const d = doors.find(x => x.b === cur); if (d && d.kind === 'lock' && d.key !== 'A') return true; if (cur === boss) return true; cur = cur.parent; } return false; }

// turn a generated layout into room records with names, shapes and features
function describe(P, gen, rnd) {
  const circle = P.circle, A = NAME_A[circle], used = new Set();
  const nameOf = () => { for (let k = 0; k < 50; k++) { const n = A[Math.floor(rnd() * A.length)] + NAME_B[Math.floor(rnd() * NAME_B.length)]; const cap = n[0].toUpperCase() + n.slice(1); if (!used.has(cap)) { used.add(cap); return cap; } } return 'Kammer'; };
  const special = {
    start: ['Abstieg zur ' + P.n + '. Etage', 'Eingang', 'icon_door'], boss: ['Hort: ' + P.boss.name, P.boss.final ? 'Letzter Kampf' : P.boss.mini ? 'Zwischenboss' : 'Endkampf', 'icon_demon_big'],
    portal: ['Portalkammer', 'Schatzkammer', 'portal'], vault: ['Riesentresor', 'Tresorraum', 'icon_chest'], treasure: ['Beutekammer', 'Schatzraum', 'icon_chest'],
    key: ['Schlüsselschrein', 'Schlüsselraum', 'key'], shrine: ['Herzschrein', 'Kampf · Schrein', 'heart'], secret: ['Verborgene Gruft', 'Geheimraum', 'rune_gem'],
  };
  const rooms = gen.rooms.map(g => {
    const sp = special[g.type];
    const r = { id: g.id, slots: g.slots, type: g.type === 'shrine' ? 'combat' : (g.type === 'vault' ? 'treasure' : g.type), gtype: g.type, onPath: !!g.onPath };
    r.name = sp ? sp[0] : nameOf(); r.kind = sp ? sp[1] : (g.drop ? 'Kampfraum · Schlüssel' : 'Kampfraum'); if (sp) r.icon = sp[2];
    if (g.type === 'key') r.iconKey = g.keyItem;
    if (g.drop) r.drop = g.drop;
    if (g.reward) r.reward = g.reward;
    if (g.seq) { r.seq = true; r.icon = 'icon_scroll'; r.kind = 'Kampf · Rätsel'; }
    if (g.fireBrazier) r.fireBrazier = true;
    const n = g.slots.length;
    if (g.type === 'boss') { r.shape = 'oct'; r.cut = n === 4 ? 6 : 4; }
    else if (g.type === 'start' || g.type === 'secret' || g.type === 'vault') { r.shape = 'oct'; r.cut = g.type === 'secret' ? 4 : 3; }
    else if (n === 1) { const v = rnd(); r.shape = v < .4 ? 'rect' : v < .72 ? 'oct' : 'cross'; r.cut = 3; }
    else r.shape = 'rect';
    if (r.type === 'combat') r.mobs = Math.min(9, 2 + n * 2 + Math.floor(rnd() * 2)) + (g.type === 'shrine' ? -2 : 0);
    if (r.type === 'boss') r.mobs = 3;
    r.info = infoFor(r, g);
    return r;
  });
  const doors = gen.doors.map(d => { const o = [d.a.id, d.b.id, d.kind]; if (d.kind === 'lock') o.push(d.key); if (d.kind === 'puzzle' || d.group) o.push(d.group); if (d.hidden) o.hidden = true; o.slots = [d.sa, d.sb]; return o; });
  return { gc: P.gc, gr: P.gr, rooms, doors, groups: gen.groups, generated: true };
}
function infoFor(r, g) {
  if (g.type === 'start') return 'Ankunft auf dieser Etage.';
  if (g.type === 'boss') return 'Verschlossen mit dem Dämonenschlüssel. Der Hüter der Etage wartet.';
  if (g.type === 'portal') return 'Belohnung und Portal zur nächsten Etage.';
  if (g.type === 'vault') return 'Gittertor: öffnet sich, wenn alle Feuerschalen der Etage brennen. Riesentresor mit Herzcontainer.';
  if (g.type === 'treasure') return 'Mit dem Knochenschlüssel zu öffnen.';
  if (g.type === 'key') return 'Der Knochenschlüssel liegt vor dem Altar.';
  if (g.type === 'shrine') return 'Ein Herz auf der Feuerplatte heilt.';
  if (g.type === 'secret') return 'Hinter einem Schädelhaufen verborgen.';
  const bits = [];
  if (g.drop === 'A') bits.push('Lässt den Glutschlüssel fallen.');
  if (g.drop === 'C') bits.push('Lässt den Dämonenschlüssel fallen.');
  if (g.seq) bits.push('Druckplatten in der gezeigten Reihenfolge betreten lässt eine Belohnungstruhe erscheinen.');
  if (g.fireBrazier) bits.push('Eine erloschene Feuerschale steht hier.');
  if (g.reward) bits.push('Belohnung nach dem Sieg.');
  return bits.join(' ') || 'Kampfraum.';
}

// ---------- world building (shared by both floors kinds) ----------
const SOLID = {
  rune_pillar_a: [74, 40], rune_pillar_b: [62, 36], rune_pillar_c: [66, 38], rune_pillar_d: [56, 34], obelisk: [62, 34],
  brazier_pillar: [58, 32], brazier_rune: [52, 30], brazier_demon: [64, 34], brazier_bowl: [56, 30], brazier_low: [60, 30], brazier_low_b: [60, 30], brazier_floor: [60, 30],
  altar: [182, 64], skull_obelisk: [70, 34], skull_heap: [92, 40], coal_skulls: [72, 30], skull_pile: [70, 30],
  spire_big: [80, 40], spire_big_b: [70, 36], spire_mid: [48, 28], spires_lava: [56, 30], spire_t: [56, 30], spire_big_t: [74, 36], spires_t: [60, 26],
  rocks_lava: [48, 28], rocks_dark: [36, 24], boulders: [56, 28], rocks_a: [56, 28], cage_small: [36, 18], spire_small: [40, 22],
};
const LIGHT = {
  brazier_pillar: [300, '255,140,60'], brazier_rune: [280, '255,140,60'], brazier_demon: [300, '255,110,50'], brazier_bowl: [280, '255,140,60'],
  brazier_low: [220, '255,140,60'], brazier_low_b: [220, '255,140,60'], brazier_floor: [230, '255,140,60'], hanging_brazier: [260, '255,140,60'],
  wall_torch_hook: [230, '255,150,70'], wall_brazier: [240, '255,150,70'],
  altar: [220, '255,90,60'], skull_obelisk: [170, '255,80,60'], fire_plate: [170, '255,120,50'], rune_pillar_a: [130, '255,70,50'], rune_pillar_c: [120, '255,70,50'], obelisk: [110, '255,70,50'],
};
const BONES = ['bone_a', 'bone_b', 'bone_c', 'bone_d', 'bone_e', 'bone_f', 'bone_g', 'bones_scatter', 'rubble', 'coal', 'rocks_b', 'skull_pile_t', 'bones_t'];
const CLUTTER = [['skull_pile', 'spires_t', 'spire_mid', 'rocks_a', 'coal_skulls', 'boulders', 'cage_small', 'spire_big_b', 'skull_pile'],
  ['spires_lava', 'spire_big', 'spire_big_t', 'rocks_lava', 'coal_skulls', 'spire_mid', 'boulders', 'spires_t', 'skull_pile'],
  ['cage_small', 'skull_pile', 'skull_obelisk', 'skull_pile', 'rune_pillar_d', 'spire_mid', 'coal_skulls', 'boulders', 'cage_small'],
  ['skull_obelisk', 'spire_big', 'skull_pile', 'spires_lava', 'brazier_demon', 'rocks_lava', 'skull_pile', 'spire_big_t', 'cage_small']];
const BRAZIERS = ['brazier_bowl', 'brazier_pillar', 'brazier_rune', 'brazier_low', 'brazier_low_b', 'brazier_floor', 'brazier_demon'];
const BANNERS = ['banner_1', 'banner_2', 'banner_3', 'banner_4', 'banner_5'];
const KEY_NAMES = { A: 'Glutschlüssel', B: 'Knochenschlüssel', C: 'Dämonenschlüssel' };

function hash(x, y, s = 0) { let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }

function buildFloor(n, SIZES) {
  const P = FLOORS[n], theme = themeFor(n);
  const plan = P.handmade ? JSON.parse(JSON.stringify(F1)) : describe(P, generate(P), mulberry32(P.seed + 99));
  const GC = plan.gc, GR = plan.gr, COLS = GC * SW, ROWS = GR * SH;
  const W = { n, title: P.title, circle: CIRCLES[P.circle], theme, boss: P.boss, diff: difficultyFor(n), final: !!P.final, COLS, ROWS, C, SW, SH,
    grid: new Uint8Array(COLS * ROWS), roomAt: new Int16Array(COLS * ROWS).fill(-1), holeAt: new Uint8Array(COLS * ROWS), tileAt: new Array(COLS * ROWS),
    rooms: plan.rooms, doors: [], props: [], decals: [], wallDecor: [], ents: [], lights: [], groups: plan.groups || {}, occupied: new Set() };
  const idx = (x, y) => y * COLS + x, inGrid = (x, y) => x >= 0 && y >= 0 && x < COLS && y < ROWS;
  const cell = (x, y) => inGrid(x, y) ? W.grid[idx(x, y)] : 0;
  const byId = {};
  W.rooms.forEach((r, i) => {
    r.index = i; byId[r.id] = r; r.doors = [];
    const cs = r.slots.map(s => s[0]), rs = r.slots.map(s => s[1]);
    r.sc = Math.min(...cs); r.sr = Math.min(...rs); r.bx = r.sc * SW + 1; r.by = r.sr * SH + 1;
    r.bw = (Math.max(...cs) - r.sc + 1) * SW - 2; r.bh = (Math.max(...rs) - r.sr + 1) * SH - 2;
    r.cleared = r.type !== 'combat' && r.type !== 'boss';
  });
  const setCell = (r, x, y, v) => { const i = idx(x, y); if (v) { W.grid[i] = 1; W.roomAt[i] = r.index; W.holeAt[i] = 0; } else { W.grid[i] = 0; W.roomAt[i] = -1; } };
  // carve rooms
  for (const r of W.rooms) {
    const has = (c, rr) => r.slots.some(s => s[0] === c && s[1] === rr);
    for (const [c, rr] of r.slots) {
      for (let y = rr * SH + 1; y <= rr * SH + 9; y++) for (let x = c * SW + 1; x <= c * SW + 12; x++) setCell(r, x, y, true);
      if (has(c + 1, rr)) for (let y = rr * SH + 1; y <= rr * SH + 9; y++) for (let x = c * SW + 13; x <= c * SW + 14; x++) setCell(r, x, y, true);
      if (has(c, rr + 1)) for (let y = rr * SH + 10; y <= rr * SH + 11; y++) for (let x = c * SW + 1; x <= c * SW + 12; x++) setCell(r, x, y, true);
      if (has(c + 1, rr) && has(c, rr + 1) && has(c + 1, rr + 1)) for (let y = rr * SH + 10; y <= rr * SH + 11; y++) for (let x = c * SW + 13; x <= c * SW + 14; x++) setCell(r, x, y, true);
    }
    const { bx, by, bw, bh } = r;
    if (r.shape === 'oct') { for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) if (Math.min(x, bw - 1 - x) + Math.min(y, bh - 1 - y) < r.cut) setCell(r, bx + x, by + y, false); }
    else if (r.shape === 'cross') { const cw = Math.round(bw * .28), ch = Math.round(bh * .3); for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) if ((x < cw || x >= bw - cw) && (y < ch || y >= bh - ch)) setCell(r, bx + x, by + y, false); }
    for (const [hx, hy, hw, hh] of r.holes || []) for (let y = hy; y < hy + hh; y++) for (let x = hx; x < hx + hw; x++) { setCell(r, bx + x, by + y, false); W.holeAt[idx(bx + x, by + y)] = 1; }
  }
  // doors
  for (const spec of plan.doors) {
    const [a, b, kind = 'open', extra] = spec;
    const A = byId[a], B = byId[b];
    let pair = spec.slots || null;
    if (!pair) for (const sa of A.slots) for (const sb of B.slots) if (!pair && Math.abs(sa[0] - sb[0]) + Math.abs(sa[1] - sb[1]) === 1) pair = [sa, sb];
    const [sa, sb] = pair, d = { a: A, b: B, kind, cells: [], unlocked: false, broken: false, hidden: !!spec.hidden };
    if (kind === 'lock') d.key = extra; if (kind === 'puzzle') d.group = extra; if (kind === 'secret' && extra) d.group = extra;
    if (sa[1] === sb[1]) {
      const l = Math.min(sa[0], sb[0]), y0 = sa[1] * SH + 5; d.dir = 'h';
      for (const x of [l * SW + 13, l * SW + 14]) for (const y of [y0, y0 + 1]) d.cells.push([x, y]);
      const left = sa[0] === l ? A : B, right = left === A ? B : A;
      for (const y of [y0, y0 + 1]) { for (const x of [l * SW + 11, l * SW + 12]) setCell(left, x, y, true); for (const x of [l * SW + 15, l * SW + 16]) setCell(right, x, y, true); }
    } else {
      const t = Math.min(sa[1], sb[1]), x0 = sa[0] * SW + 6; d.dir = 'v';
      for (const y of [t * SH + 10, t * SH + 11]) for (const x of [x0, x0 + 1]) d.cells.push([x, y]);
      const top = sa[1] === t ? A : B, bottom = top === A ? B : A;
      for (const x of [x0, x0 + 1]) { for (const y of [t * SH + 8, t * SH + 9]) setCell(top, x, y, true); for (const y of [t * SH + 12, t * SH + 13]) setCell(bottom, x, y, true); }
    }
    for (const [x, y] of d.cells) W.grid[idx(x, y)] = kind === 'secret' ? 0 : 1;
    const xs = d.cells.map(c => c[0]), ys = d.cells.map(c => c[1]);
    d.x0 = Math.min(...xs); d.y0 = Math.min(...ys); d.x1 = Math.max(...xs); d.y1 = Math.max(...ys);
    d.cx = (d.x0 + d.x1 + 1) / 2 * C; d.cy = (d.y0 + d.y1 + 1) / 2 * C;
    d.crackX = d.dir === 'h' ? (A.bx < d.x0 ? d.x0 * C + 31 : (d.x1 + 1) * C - 31) : d.cx;
    d.crackY = d.dir === 'v' ? (A.by < d.y0 ? d.y0 * C + 37 : (d.y1 + 1) * C - 37) : d.cy;
    A.doors.push(d); B.doors.push(d); W.doors.push(d);
  }
  // floor tiles: deeper floors show more embers and cracks
  const hot = theme.hot;
  for (let i = 0; i < W.grid.length; i++) {
    const x = i % COLS, y = (i / COLS) | 0, h = hash(x, y, 3 + n);
    if (W.roomAt[i] < 0) { W.tileAt[i] = h < .5 ? 'floor_10' : h < .8 ? 'floor_11' : 'floor_01'; continue; }
    const cold = 1 - hot;
    W.tileAt[i] = h < cold * .5 ? 'floor_00' : h < cold * .7 ? 'floor_04' : h < cold * .85 ? 'floor_01' : h < cold ? 'floor_10' : h < cold + hot * .25 ? 'floor_02' : h < cold + hot * .45 ? 'floor_03' : h < cold + hot * .65 ? 'floor_07' : h < cold + hot * .85 ? 'floor_08' : 'floor_09';
  }
  // per-room features
  const rnd = mulberry32((P.seed || 1) + 4242);
  for (const r of W.rooms) {
    r.cells = cellsOf(W, r);
    if (P.handmade) runFeatures(W, r, r.f || [], SIZES);
    else { planLanes(W, r); generateFeatures(W, P, r, rnd, SIZES); }
  }
  placeSkullHeaps(W, SIZES);
  if (n >= 4) placeSeals(W, P, mulberry32((P.seed || 1) + 777), SIZES);
  for (const r of W.rooms) autoDress(W, r, SIZES);
  for (const r of W.rooms) r.cells = cellsOf(W, r);
  W.lavaCells = []; for (let i = 0; i < W.grid.length; i++) if (W.grid[i] === 2) W.lavaCells.push([i % COLS, (i / COLS) | 0]);
  W.byId = byId;
  return W;
}
// Every secret wall gets a breakable skull heap in front of it, inside the room it is found from.
function placeSkullHeaps(W, SIZES) {
  for (const d of W.doors) {
    if (d.kind !== 'secret') continue;
    const r = d.a, H = helpers(W, r, SIZES);
    let cx, cy;
    if (d.dir === 'h') { const x = r.bx < d.x0 ? d.x0 - 1 : d.x1 + 1; cx = x + .5 - r.bx; cy = d.y0 + 1.35 - r.by; }
    else { const y = r.by < d.y0 ? d.y0 - 1 : d.y1 + 1; cx = d.x0 + 1 - r.bx; cy = y + .8 - r.by; }
    H.ent({ type: 'skullheap', cx, cy, hp: 3, door: W.doors.indexOf(d) });
  }
}
// Demon seals from floor 4 on: 3 per floor (4 from floor 7), one per room, mostly in side rooms.
function placeSeals(W, P, rnd, SIZES) {
  const want = W.n >= 7 ? 4 : 3, idx = (x, y) => y * W.COLS + x;
  const rooms = W.rooms.filter(r => r.type === 'combat' && !r.seq && r.cells.length > 40);
  const side = rooms.filter(r => !r.onPath).sort(() => rnd() - .5), path = rooms.filter(r => r.onPath).sort(() => rnd() - .5);
  const pick = side.slice(0, want - 1).concat(path.slice(0, 1));
  while (pick.length < want && side.length + path.length > pick.length) { const more = side.concat(path).find(r => !pick.includes(r)); if (!more) break; pick.push(more); }
  for (const r of pick) {
    const H = helpers(W, r, SIZES);
    const free = r.cells.filter(([x, y]) => W.grid[idx(x, y)] === 1 && !W.occupied.has(idx(x, y)) && !nearDoor(W, r, x + .5, y + .5, 3)
      && [[1, 0], [-1, 0], [0, 1], [0, -1]].every(([dx, dy]) => W.roomAt[idx(x + dx, y + dy)] === r.index && W.grid[idx(x + dx, y + dy)] === 1));
    if (!free.length) continue;
    const [x, y] = free[Math.floor(rnd() * free.length)];
    H.ent({ type: 'seal', cx: x + .5 - r.bx, cy: y + .8 - r.by, hp: 8 });
    r.seal = true;
  }
}
function cellsOf(W, r) { const out = []; for (let y = r.by; y < r.by + r.bh; y++) for (let x = r.bx; x < r.bx + r.bw; x++) if (W.roomAt[y * W.COLS + x] === r.index) out.push([x, y]); return out; }
function nearDoor(W, r, x, y, dist) { return r.doors.some(d => Math.hypot(x * C - d.cx, y * C - d.cy) < dist * C); }

function helpers(W, r, SIZES) {
  const X = cx => (r.bx + cx) * C, Y = cy => (r.by + cy) * C, idx = (x, y) => y * W.COLS + x;
  const H = {
    prop(name, cx, cy, o = {}) {
      const p = { name, x: X(cx), y: Y(cy), flip: !!o.flip, layer: o.layer || 'obj' };
      const s = o.solid === false ? null : (o.solid || SOLID[name]);
      if (s) { p.solid = [p.x - s[0] / 2, p.y - s[1], p.x + s[0] / 2, p.y]; W.occupied.add(idx(Math.floor(r.bx + cx), Math.floor(r.by + cy - .2))); }
      W.props.push(p);
      const l = LIGHT[name]; if (l && !o.unlit) W.lights.push({ x: p.x, y: p.y - SIZES[name][1] * .72, r: l[0], c: l[1], f: hash(cx * 7, cy * 9) * 6 });
      return p;
    },
    decal(name, cx, cy, a = 1) { W.decals.push({ name, x: X(cx), y: Y(cy), a }); const l = LIGHT[name]; if (l) W.lights.push({ x: X(cx), y: Y(cy), r: l[0], c: l[1], f: 1 }); },
    wall(name, cx, cy = 0, dy = 6, flip = false) {
      const w = { name, x: X(cx), y: Y(cy) - 74 + dy, flip }; W.wallDecor.push(w);
      const l = LIGHT[name]; if (l) W.lights.push({ x: w.x, y: w.y + 40, r: l[0], c: l[1], f: hash(cx, 5) * 6 });
    },
    tile(name, x, y) { W.tileAt[idx(r.bx + x, r.by + y)] = name; },
    lava(x, y, w, h) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) { W.grid[idx(r.bx + i, r.by + j)] = 2; W.occupied.add(idx(r.bx + i, r.by + j)); } },
    bridge(x, y, w, h, dir) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) { W.grid[idx(r.bx + i, r.by + j)] = 3; W.occupied.add(idx(r.bx + i, r.by + j)); } W.decals.push({ name: dir === 'h' ? 'bridge_h' : 'bridge_v', x: X(x + w / 2), y: Y(y + h / 2), w: w * C + 20, h: h * C + 18 }); },
    // a pit is walkable: the hero falls in (loses a heart, back to the start room), enemies walk over it
    pit(x, y) { W.decals.push({ name: 'pit', x: X(x + .5), y: Y(y + .5) }); H.ent({ type: 'pit', cx: x + .5, cy: y + .5 }); },
    ent(o) { o.x = X(o.cx); o.y = Y(o.cy); o.room = r.index; W.ents.push(o); W.occupied.add(idx(Math.floor(r.bx + o.cx), Math.floor(r.by + o.cy - .2))); return o; },
    keep(x, y, w, h) { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) W.occupied.add(idx(r.bx + i, r.by + j)); },
  };
  return H;
}
function runFeatures(W, r, list, SIZES) {
  const H = helpers(W, r, SIZES);
  for (const f of list) {
    const [k, a, b, c, d, e, g] = f;
    switch (k) {
      case 'prop': H.prop(a, b, c, { flip: d }); break;
      case 'decal': H.decal(a, b, c, d ?? 1); break;
      case 'wall': H.wall(a, b, c, d ?? 6, e); break;
      case 'tile': H.tile(a, b, c); break;
      case 'lava': H.lava(a, b, c, d); break;
      case 'bridge': H.bridge(a, b, c, d, e); break;
      case 'pit': H.pit(a, b); break;
      case 'keep': H.keep(a, b, c, d); break;
      case 'vent': H.ent({ type: 'vent', cx: a, cy: b, offset: c }); break;
      case 'spikes': for (let y = b; y <= d; y++) for (let x = a; x <= c; x++) H.ent({ type: 'spikes', phase: (x + y) % 2, cx: x + .5, cy: y + .5 }); break;
      case 'gem': H.ent({ type: 'gem', cx: a, cy: b }); break;
      case 'heart': H.ent({ type: 'heart', cx: a, cy: b }); break;
      case 'chest': H.ent({ type: 'chest', cx: a, cy: b, loot: { gems: c, heart: !!d }, magic: !!e }); break;
      case 'vault': H.ent({ type: 'vault', cx: a, cy: b }); break;
      case 'key': H.ent({ type: 'key', key: a, cx: b, cy: c }); break;
      case 'brazier': H.ent({ type: 'brazier', cx: a, cy: b, group: c, lit: false }); break;
      case 'plate': H.ent({ type: 'plate', cx: a, cy: b, group: c, order: d || 0, on: false }); break;
      case 'portal': H.ent({ type: 'portal', cx: a, cy: b }); break;
      case 'spawn': r.spawn = [a, b]; break;
    }
  }
}

// lanes: shortest walks from every door into the room centre stay free of lava and solids
function planLanes(W, r) {
  const idx = (x, y) => y * W.COLS + x, inRoom = (x, y) => W.roomAt[idx(x, y)] === r.index;
  const set = new Set(r.cells.map(([x, y]) => idx(x, y)));
  let best = null, bd = 1e9; const tx = r.bx + r.bw / 2, ty = r.by + r.bh / 2;
  for (const [x, y] of r.cells) { const d = Math.hypot(x + .5 - tx, y + .5 - ty); if (d < bd) { bd = d; best = [x, y]; } }
  r.center = best; r.lanes = new Set();
  const entries = r.doors.map(d => { let e = null, ed = 1e9; for (const [x, y] of r.cells) { const dd = Math.hypot((x + .5) * C - d.cx, (y + .5) * C - d.cy); if (dd < ed) { ed = dd; e = [x, y]; } } return e; });
  for (const e of entries) {
    const prev = new Map([[idx(...e), -1]]), q = [e];
    while (q.length) { const [x, y] = q.shift(); if (x === best[0] && y === best[1]) break; for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const k = idx(x + dx, y + dy); if (set.has(k) && !prev.has(k)) { prev.set(k, idx(x, y)); q.push([x + dx, y + dy]); } } }
    let k = idx(...best); while (k !== -1 && k !== undefined) { r.lanes.add(k); const x = k % W.COLS, y = (k / W.COLS) | 0; if (inRoom(x + 1, y)) r.lanes.add(idx(x + 1, y)); if (inRoom(x, y + 1)) r.lanes.add(idx(x, y + 1)); k = prev.get(k); }
    for (let dy = -1; dy <= 2; dy++) for (let dx = -1; dx <= 2; dx++) if (inRoom(e[0] + dx, e[1] + dy)) r.lanes.add(idx(e[0] + dx, e[1] + dy));
  }
  for (const k of r.lanes) W.occupied.add(k);
}
function roomConnected(W, r) {
  const idx = (x, y) => y * W.COLS + x, cells = cellsOf(W, r).filter(([x, y]) => W.grid[idx(x, y)] !== 0);
  if (!cells.length) return false;
  const set = new Set(cells.map(([x, y]) => idx(x, y))), seen = new Set([idx(...cells[0])]), q = [cells[0]];
  while (q.length) { const [x, y] = q.pop(); for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const k = idx(x + dx, y + dy); if (set.has(k) && !seen.has(k)) { seen.add(k); q.push([x + dx, y + dy]); } } }
  return seen.size === set.size;
}
function generateFeatures(W, P, r, rnd, SIZES) {
  const H = helpers(W, r, SIZES), idx = (x, y) => y * W.COLS + x;
  const local = r.cells.map(([x, y]) => [x - r.bx, y - r.by]);
  const freeL = (x, y) => { const gx = r.bx + x, gy = r.by + y; return W.roomAt[idx(gx, gy)] === r.index && W.grid[idx(gx, gy)] === 1 && !W.occupied.has(idx(gx, gy)); };
  const rectFree = (x, y, w, h, margin = 0) => { for (let j = y - margin; j < y + h + margin; j++) for (let i = x - margin; i < x + w + margin; i++) if (!freeL(i, j)) return false; return true; };
  const tryRect = (w, h, margin, n = 40) => { for (let k = 0; k < n; k++) { const [x, y] = local[Math.floor(rnd() * local.length)]; if (rectFree(x, y, w, h, margin)) return [x, y]; } return null; };
  const [cx, cy] = [r.center[0] - r.bx, r.center[1] - r.by];
  const big = r.slots.length >= 2;
  const g = r.gtype;
  // special room content
  if (g === 'start') { H.wall('door_stairs', cx + .5, 0, -26); r.spawn = [cx + .5, cy + .9]; H.decal('rune_big', cx + .5, cy + .5); return; }
  if (g === 'portal') { H.ent({ type: 'portal', cx: cx + .5, cy: Math.max(2.75, cy - 1.2) }); H.ent({ type: 'chest', cx: cx + 2.6, cy: cy + 2.2, loot: { gems: 8 + P.n, heart: true } }); H.prop('brazier_pillar', cx - 1.8, Math.max(2.6, cy - 1.3)); H.decal('rune_big', cx + .5, cy + 1.2); return; }
  if (g === 'vault') {
    H.ent({ type: 'vault', cx: cx + .5, cy: cy + 1.0 });
    H.lava(Math.max(1, cx - 3), cy + 3, 2, 1); H.lava(cx + 3, cy + 3, 2, 1);
    for (const [ox, oy] of [[-3, -2], [3.9, -2], [-3, 2.6], [3.9, 2.6]]) if (freeL(Math.floor(cx + ox), Math.floor(cy + oy))) H.prop('rune_pillar_c', cx + ox, cy + oy);
    H.decal('rune_big', cx + .5, cy + .4); return;
  }
  if (g === 'treasure') { H.ent({ type: 'chest', cx: cx + .5, cy: cy + .9, loot: { gems: 6 + P.n, heart: true } }); H.prop('brazier_bowl', cx - 1.5, cy + .7); H.prop('brazier_bowl', cx + 2.5, cy + .7); return; }
  if (g === 'key') { H.prop('altar', cx + .5, 2.4); H.ent({ type: 'key', key: 'B', cx: cx + .5, cy: 3.95 }); H.decal('rune_small', cx + .5, cy + 1.5); return; }
  if (g === 'secret') { H.ent({ type: 'chest', cx: cx + .5, cy: cy + .9, loot: { gems: 6 + P.n }, magic: true }); H.ent({ type: 'gem', cx: cx - 2, cy: cy + 2 }); H.ent({ type: 'gem', cx: cx + 3, cy: cy + 2.2 }); H.ent({ type: 'heart', cx: cx + .5, cy: cy + 3 }); return; }
  if (g === 'shrine') { H.decal('fire_plate', cx + .5, cy + .9); H.ent({ type: 'heart', cx: cx + .5, cy: cy + 1.0 }); }
  if (g === 'boss') {
    const w = r.bw, h = r.bh;
    if (w >= 20) { H.lava(1, Math.floor(h / 2) - 3, 3, 6); H.lava(w - 4, Math.floor(h / 2) - 3, 3, 6); }
    for (const [ox, oy] of [[-6, -4], [6, -4], [-6, 5], [6, 5]]) if (freeL(Math.floor(cx + ox), Math.floor(cy + oy))) H.prop('brazier_demon', cx + .5 + ox, cy + oy + .8);
    H.decal('rune_big', cx + .5, cy + .5); H.decal('rune_plate', cx - 3, cy + .5); H.decal('rune_plate', cx + 4, cy + .5);
    if (P.final) { H.prop('altar', cx + .5, 2.5); H.decal('rune_small', cx + .5, cy + 3.5); }
    return;
  }
  // puzzles
  if (r.seq) {
    const spots = [[-2, -2], [3, -2], [-2, 3], [3, 3], [.5, .5]].map(([ox, oy]) => [cx + ox, cy + oy]);
    const order = [1, 2, 3, 4, 5].sort(() => rnd() - .5);
    spots.forEach(([x, y], k) => H.ent({ type: 'plate', cx: x, cy: y, group: 'seq', order: order[k], on: false }));
  }
  if (r.fireBrazier) {
    const edge = local.filter(([x, y]) => freeL(x, y) && (!freeL(x, y - 1) || !freeL(x - 1, y) || !freeL(x + 1, y)) && !nearDoor(W, r, r.bx + x + .5, r.by + y + .5, 3));
    const spot = edge.length ? edge[Math.floor(rnd() * edge.length)] : [cx + 2, cy];
    H.ent({ type: 'brazier', cx: spot[0] + .5, cy: spot[1] + .75, group: 'feuer', lit: false });
  }
  // terrain features, densest in big rooms and on deep floors
  if (big && rnd() < P.holes) {
    for (let k = 0; k < 6; k++) {
      const hw = 2 + Math.floor(rnd() * 3), hh = 2 + Math.floor(rnd() * 2), spot = tryRect(hw, hh, 1, 30);
      if (!spot) continue;
      const before = spot.map(v => v);
      for (let j = 0; j < hh; j++) for (let i = 0; i < hw; i++) { const gi = idx(r.bx + before[0] + i, r.by + before[1] + j); W.grid[gi] = 0; W.roomAt[gi] = -1; W.holeAt[gi] = 1; }
      if (!roomConnected(W, r)) { for (let j = 0; j < hh; j++) for (let i = 0; i < hw; i++) { const gi = idx(r.bx + before[0] + i, r.by + before[1] + j); W.grid[gi] = 1; W.roomAt[gi] = r.index; W.holeAt[gi] = 0; } }
      else { r.holes = (r.holes || []).concat([[...before, hw, hh]]); if (rnd() < .5) H.wall('cage_hang', before[0] + hw / 2, before[1] + hh, 0); }
      if ((r.holes || []).length >= (r.slots.length >= 3 ? 2 : 1)) break;
    }
    r.cells = cellsOf(W, r);
  }
  const lavaBudget = Math.round((P.lava * (big ? 2.4 : 1.2)) + rnd() * .8);
  for (let k = 0; k < lavaBudget; k++) {
    const lw = 2 + Math.floor(rnd() * 3), lh = 1 + Math.floor(rnd() * 2), spot = tryRect(lw, lh, 0);
    if (spot) { H.lava(spot[0], spot[1], lw, lh); if (rnd() < .7) { const sx = spot[0] + (rnd() < .5 ? -.3 : lw + .3); if (freeL(Math.floor(sx), spot[1] + lh - 1)) H.prop(rnd() < .5 ? 'spires_lava' : 'rocks_lava', sx + .5, spot[1] + lh - .2); } }
  }
  if (P.river && big && rnd() < P.river) riverAcross(W, r, H, rnd);
  if (rnd() < P.spikes * (big ? 1.4 : 1)) {
    const fw = 3 + Math.floor(rnd() * 3), fh = 2 + Math.floor(rnd() * 2);
    let spot = null; for (let k = 0; k < 40 && !spot; k++) { const [x, y] = local[Math.floor(rnd() * local.length)]; let ok = true; for (let j = y; j < y + fh && ok; j++) for (let i = x; i < x + fw && ok; i++) { const gx = r.bx + i, gy = r.by + j; if (W.roomAt[idx(gx, gy)] !== r.index || W.grid[idx(gx, gy)] !== 1) ok = false; } if (ok) spot = [x, y]; }
    if (spot) for (let j = 0; j < fh; j++) for (let i = 0; i < fw; i++) H.ent({ type: 'spikes', phase: (i + j) % 2, cx: spot[0] + i + .5, cy: spot[1] + j + .5 });
  }
  const vents = rnd() < P.vents ? 1 + (big && rnd() < .5 ? 1 : 0) : 0;
  for (let k = 0; k < vents; k++) { const spot = tryRect(1, 1, 0); if (spot) H.ent({ type: 'vent', cx: spot[0] + .5, cy: spot[1] + .5, offset: rnd() * 3 }); }
  if (rnd() < P.pits) for (let k = 0; k < 1 + Math.floor(rnd() * 3); k++) { const spot = tryRect(1, 1, 1); if (spot) H.pit(spot[0], spot[1]); }
  if (rnd() < .45) { const pl = ['rune_pillar_a', 'rune_pillar_c', 'rune_pillar_b', 'obelisk'][P.circle % 4]; for (const [ox, oy] of [[-3, -2], [4, -2], [-3, 3], [4, 3]]) { const x = Math.floor(cx + ox), y = Math.floor(cy + oy); if (freeL(x, y) && freeL(x, y - 1)) H.prop(pl, x + .5, y + .75); } }
  if (rnd() < .5) H.decal(['rune_big', 'rune_small', 'rune_plate', 'grate'][Math.floor(rnd() * 4)], cx + .5, cy + .5);
}
function riverAcross(W, r, H, rnd) {
  const idx = (x, y) => y * W.COLS + x, vertical = r.bw > r.bh;
  const span = vertical ? r.bw : r.bh, len = vertical ? r.bh : r.bw;
  for (let k = 0; k < 10; k++) {
    const at = 3 + Math.floor(rnd() * (span - 7));
    const band = []; let ok = true;
    for (let t = 0; t < len; t++) for (let w = 0; w < 2; w++) {
      const x = vertical ? at + w : t, y = vertical ? t : at + w, gx = r.bx + x, gy = r.by + y;
      if (W.roomAt[idx(gx, gy)] !== r.index) continue;
      if (W.grid[idx(gx, gy)] !== 1) { ok = false; break; }
      band.push([x, y, r.lanes.has(idx(gx, gy))]);
    }
    if (!ok || band.length < len) continue;
    // lane cells crossing the band become bridges, the rest lava
    for (const [x, y, lane] of band) { if (lane) H.bridge(x, y, 1, 1, vertical ? 'h' : 'v'); else H.lava(x, y, 1, 1); }
    mergeBridges(W, r, vertical);
    return true;
  }
  return false;
}
function mergeBridges(W, r, vertical) {
  // replace the per-cell bridge decals of this room with one decal per connected bridge run
  const X = cx => (r.bx + cx) * C, Y = cy => (r.by + cy) * C, idx = (x, y) => y * W.COLS + x;
  W.decals = W.decals.filter(d => !(d.name.startsWith('bridge') && d.w === C + 20 && d.h === C + 18 && W.roomAt[idx(Math.floor(d.x / C), Math.floor(d.y / C))] === r.index));
  const seen = new Set();
  for (const [gx, gy] of cellsOf(W, r)) {
    const k = idx(gx, gy); if (W.grid[k] !== 3 || seen.has(k)) continue;
    let x1 = gx, y1 = gy; while (W.grid[idx(x1 + 1, gy)] === 3) x1++; while (W.grid[idx(gx, y1 + 1)] === 3) y1++;
    for (let y = gy; y <= y1; y++) for (let x = gx; x <= x1; x++) seen.add(idx(x, y));
    const w = x1 - gx + 1, h = y1 - gy + 1;
    W.decals.push({ name: vertical ? 'bridge_h' : 'bridge_v', x: (gx + w / 2) * C, y: (gy + h / 2) * C, w: w * C + 20, h: h * C + 18 });
  }
}

// shared rules: banners beside north doors, wall decor, corner braziers, clutter, bones
function autoDress(W, r, SIZES) {
  const H = helpers(W, r, SIZES), idx = (x, y) => y * W.COLS + x, rnd = (k, s) => hash(r.index * 31 + k, s, 7 + W.n);
  const walk = t => t === 1 || t === 2 || t === 3, cell = (x, y) => W.grid[idx(x, y)];
  const inRoom = (x, y) => W.roomAt[idx(x, y)] === r.index;
  const free = (x, y) => inRoom(x, y) && cell(x, y) === 1 && !W.occupied.has(idx(x, y));
  const circle = FLOORS[W.n].circle;
  const banner = BANNERS[(r.index + W.n) % BANNERS.length];
  for (const d of r.doors) {
    if (d.dir === 'v' && inRoom(d.x0, d.y1 + 1)) {
      const lx = d.cx / C - r.bx, ly = d.y1 + 1 - r.by;
      for (const s of [-1.9, 1.9]) if (inRoom(Math.floor(r.bx + lx + s), r.by + ly) && !inRoom(Math.floor(r.bx + lx + s), r.by + ly - 1)) H.wall(banner, lx + s, ly, 6, s > 0);
    }
  }
  const chains = circle >= 2 ? .28 : .1;
  for (let y = r.by; y < r.by + r.bh; y++) {
    let x = r.bx;
    while (x < r.bx + r.bw) {
      if (inRoom(x, y) && !walk(cell(x, y - 1))) {
        let e = x; while (inRoom(e + 1, y) && !walk(cell(e + 1, y - 1))) e++;
        for (let k = x + 1.5; k < e; k += 3.4) {
          if (nearDoor(W, r, k, y, 2.8)) continue;
          const v = rnd(k * 3 | 0, y);
          const n = v < .42 - chains / 2 ? 'wall_torch_hook' : v < .6 ? 'chain_swag' : v < .6 + chains ? 'cage_hang' : v < .8 ? (v < .7 ? 'shackle_skull' : 'shackle_a') : v < .92 ? BANNERS[(k * 7 | 0) % 5] : 'wall_brazier';
          H.wall(n, k - r.bx, y - r.by, n === 'cage_hang' ? 2 : 6, v > .5);
        }
        x = e + 1;
      } else x++;
    }
  }
  const cells = cellsOf(W, r), corners = [];
  for (const [x, y] of cells) {
    const n = !inRoom(x, y - 1), s = !inRoom(x, y + 1), w = !inRoom(x - 1, y), e = !inRoom(x + 1, y);
    if ((n || s) && (w || e) && free(x, y) && !nearDoor(W, r, x + .5, y + .5, 2.6)) corners.push([x, y]);
  }
  const want = Math.min(6, 2 + Math.floor(r.slots.length * 1.5));
  for (let k = 0, placed = 0; k < corners.length && placed < want; k++) {
    const [x, y] = corners[(k * 7 + r.index) % corners.length];
    if (!free(x, y)) continue;
    if (W.props.some(p => p.name && BRAZIERS.includes(p.name) && Math.hypot(p.x - (x + .5) * C, p.y - (y + .9) * C) < 3 * C)) continue;
    H.prop(BRAZIERS[(r.index + placed + circle) % (circle >= 3 ? 7 : 4) + (circle >= 3 ? 0 : 0)], x + .5 - r.bx, y + .88 - r.by); placed++;
  }
  const edge = cells.filter(([x, y]) => free(x, y) && (!inRoom(x - 1, y) || !inRoom(x + 1, y) || !inRoom(x, y - 1) || !inRoom(x, y + 1)) && !nearDoor(W, r, x + .5, y + .5, 2.6));
  const nClutter = Math.floor(edge.length / (9 - circle));
  const clutter = CLUTTER[circle];
  for (let k = 0; k < nClutter; k++) {
    const [x, y] = edge[Math.floor(rnd(k, 11) * edge.length)];
    if (!free(x, y) || W.props.some(p => p.solid && Math.hypot(p.x - (x + .5) * C, p.y - (y + .8) * C) < 1.6 * C)) continue;
    const lavaNear = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => cell(x + dx, y + dy) === 2);
    H.prop(lavaNear ? 'spires_lava' : clutter[Math.floor(rnd(k, 12) * clutter.length)], x + .5 - r.bx, y + .82 - r.by, { flip: rnd(k, 13) < .5 });
  }
  const floor = cells.filter(([x, y]) => inRoom(x, y) && cell(x, y) === 1 && !W.props.some(p => p.solid && p.solid[0] < (x + 1) * C && p.solid[2] > x * C && p.solid[1] < (y + 1) * C && p.solid[3] > y * C));
  const nBones = Math.floor(floor.length / (8 - circle));
  for (let k = 0; k < nBones; k++) {
    const [x, y] = floor[Math.floor(rnd(k, 21) * floor.length)];
    H.prop(BONES[Math.floor(rnd(k, 22) * BONES.length)], x + .2 + rnd(k, 23) * .6 - r.bx, y + .4 + rnd(k, 24) * .5 - r.by, { solid: false, layer: 'low', flip: rnd(k, 25) < .5 });
  }
}

// quickest way to the boss: rooms that must be entered, keys included
function criticalRooms(W) {
  const adj = new Map(W.rooms.map(r => [r.index, []]));
  for (const d of W.doors) { adj.get(d.a.index).push([d.b.index, d]); adj.get(d.b.index).push([d.a.index, d]); }
  const start = W.rooms.find(r => r.type === 'start').index, boss = W.rooms.find(r => r.type === 'boss').index;
  // a puzzle door counts as open, but the rooms holding its puzzle pieces join the route
  const pieces = g => [...new Set(W.ents.filter(e => e.group === g).map(e => e.room))];
  const passable = (d, keys) => d.kind === 'open' || d.kind === 'boss' || d.kind === 'puzzle' || (d.kind === 'lock' && keys.has(d.key));
  const keyRooms = {}; for (const r of W.rooms) { if (r.drop) keyRooms[r.drop] = r.index; }
  for (const e of W.ents) if (e.type === 'key') keyRooms[e.key] = e.room;
  const bfs = (from, to, keys) => { const prev = new Map([[from, -1]]), q = [from]; while (q.length) { const c = q.shift(); if (c === to) break; for (const [nb, d] of adj.get(c)) if (!prev.has(nb) && passable(d, keys)) { prev.set(nb, c); q.push(nb); } } if (!prev.has(to)) return null; const out = []; let c = to; while (c !== -1) { out.push(c); c = prev.get(c); } return out; };
  const keys = new Set(), need = new Set([start]);
  for (let round = 0; round < 4; round++) {
    const p = bfs(start, boss, keys);
    if (p) {
      p.forEach(i => need.add(i));
      for (let k = 0; k + 1 < p.length; k++) for (const [nb, d] of adj.get(p[k + 1])) if (nb === p[k] && d.kind === 'puzzle') for (const room of pieces(d.group)) { const pp = bfs(start, room, keys); if (pp) pp.forEach(i => need.add(i)); }
      return { need: [...need], total: W.rooms.length };
    }
    for (const k of ['A', 'C', 'B']) if (!keys.has(k) && keyRooms[k] !== undefined) { const kp = bfs(start, keyRooms[k], keys); if (kp) { kp.forEach(i => need.add(i)); keys.add(k); } }
  }
  return { need: null, total: W.rooms.length };
}

const api = { C, SW, SH, FLOORS, CIRCLES, KEY_NAMES, buildFloor, criticalRooms, hash, themeFor, difficultyFor, cellsOf };
if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.HellCore = api;
})(typeof window !== 'undefined' ? window : globalThis);

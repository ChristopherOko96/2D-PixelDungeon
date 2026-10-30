// The ten hell floors (Story 3, Der Hell-Dungeon) as a world kit pack: every floor is built anew
// from the run number on the shared generator (tools/world_kit/world_core.js) and dressed by the
// shared pack functions (tools/world_kit/world_pack.js). Titles, bosses, hazards and difficulty
// are the hell's ten floors as before (tools/hell_dungeon/hell_core.js); floor 1 is generated too,
// with the handmade floor's character (Aschenvorhof, Glutwächter, little lava, no plates rush).
// The skin is the hell's own (assets/sprites/hell), plus the pieces the world kit needs beyond
// the hell sheets (tools/hell_dungeon/build_hell_extras.py).
//
// Hell rooms: fight rooms lean medium (P.two, P.twoSide: mostly 2 slots) and the few 3-slot
// rooms lose their corners (P.trimLarge), so they stay a little smaller than the crypt's large
// halls. Key room, vaults, loot room, hidden rooms, stairs and the portal room stay small.
// Use: WorldCore.buildFloor(n, sizes, HellWorld.forRun(run)), then HellWorld.dress(W).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('../world_kit/world_pack.js'));
  else root.HellWorld = factory(root.WorldPack);
})(typeof self !== 'undefined' ? self : this, function (WorldPack) {
  'use strict';
  // room sizes of every hell floor (see above)
  const SIZE = { two: .8, twoSide: .8, trimLarge: 2 };
  const FLOORS = [
    null,
    { n: 1, title: 'Aschenvorhof', circle: 0, seed: 7001, gc: 7, gr: 6, path: 13, rooms: 22, lava: .2, spikes: .2, vents: .25, holes: .45, pits: .3, loops: .35, mainLock: true, fire: 3, seq: false, boss: { name: 'Glutwächter', hp: 46, summon: 4, ring: 0 } },
    { n: 2, title: 'Rußgalerien', circle: 0, seed: 7101, gc: 7, gr: 6, path: 13, rooms: 22, lava: .25, spikes: .2, vents: .25, holes: .45, pits: .3, loops: .35, mainLock: true, fire: 3, seq: false, boss: { name: 'Dreischlund', hp: 60, summon: 4, ring: 0 } },
    { n: 3, title: 'Schwefelpforte', circle: 0, seed: 7303, gc: 7, gr: 6, path: 14, rooms: 23, lava: .3, spikes: .25, vents: .3, holes: .45, pits: .35, loops: .35, mainLock: true, fire: 0, seq: true, boss: { name: 'Ignaroth · Salamander', hp: 90, summon: 3.6, ring: 3.4, mini: true } },
    { n: 4, title: 'Glutkessel', circle: 1, seed: 8404, gc: 8, gr: 6, path: 15, rooms: 25, lava: .55, river: .45, spikes: .25, vents: .45, holes: .35, pits: .2, loops: .3, mainLock: true, fire: 4, seq: false, shooters: true, boss: { name: 'Kesselbrut', hp: 105, summon: 3.6, ring: 3.2 } },
    { n: 5, title: 'Schlackenstrom', circle: 1, seed: 8505, gc: 8, gr: 6, path: 16, rooms: 26, lava: .6, river: .55, spikes: .3, vents: .5, holes: .35, pits: .2, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Seelenhirte', hp: 120, summon: 3.4, ring: 3.0 } },
    { n: 6, title: 'Feuerschlund', circle: 1, seed: 8606, gc: 8, gr: 6, path: 16, rooms: 26, lava: .7, river: .6, spikes: .3, vents: .55, holes: .3, pits: .25, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Ignaroth · Jungdrache', hp: 160, summon: 3.2, ring: 2.6, mini: true } },
    { n: 7, title: 'Kettenzwinger', circle: 2, seed: 9707, gc: 8, gr: 7, path: 17, rooms: 28, lava: .4, river: .3, spikes: .5, vents: .4, holes: .5, pits: .45, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Kerkermeister', hp: 175, summon: 3.0, ring: 2.6 } },
    { n: 8, title: 'Klagegruben', circle: 2, seed: 9808, gc: 8, gr: 7, path: 18, rooms: 29, lava: .45, river: .35, spikes: .55, vents: .45, holes: .5, pits: .5, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Klagender Hüter', hp: 190, summon: 2.8, ring: 2.4 } },
    { n: 9, title: 'Blutrunen', circle: 2, seed: 9909, gc: 8, gr: 7, path: 18, rooms: 30, lava: .55, river: .4, spikes: .6, vents: .5, holes: .5, pits: .5, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Ignaroth · Glutdrache', hp: 240, summon: 2.6, ring: 2.0, mini: true } },
    { n: 10, title: 'Thron der Tiefe', circle: 3, seed: 11010, gc: 8, gr: 7, path: 18, rooms: 30, lava: .75, river: .6, spikes: .55, vents: .6, holes: .45, pits: .45, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, final: true, boss: { name: 'Ignaroth · Obsidianform', hp: 340, summon: 2.4, ring: 1.6, final: true } },
  ].map(P => P && Object.assign({}, P, SIZE));
  const CIRCLES = ['Kreis I · Aschenvorhof', 'Kreis II · Lavaschlund', 'Kreis III · Kettenkerker', 'Kreis IV · Höllenthron'];
  const NAMES = [['Asche', 'Ruß', 'Schwefel', 'Glut', 'Brand', 'Knochen', 'Schädel', 'Rauch'], ['Schlacken', 'Lava', 'Glut', 'Feuer', 'Magma', 'Brand', 'Kessel', 'Funken'],
    ['Ketten', 'Klage', 'Blut', 'Runen', 'Qual', 'Kerker', 'Eisen', 'Schmerz'], ['Höllen', 'Blut', 'Feuer', 'Dämonen', 'Seelen', 'Thron', 'Verdammnis', 'Abgrund']];
  const SUFFIXES = ['halle', 'kammer', 'gang', 'grube', 'kreuz', 'gruft', 'galerie', 'schlund', 'pforte', 'zwinger', 'esse', 'kessel', 'saal', 'hof', 'nische', 'stiege'];
  // the generator speaks hell already; only the key room's old altar text is brought up to date
  const WORDS = [['Daneben ein Altar (später ein Laden) und ein Manabrunnen', 'Daneben der Laden und ein Manabrunnen']];
  // banners in the floor colour: red on floors 3, 6, 9 and 10 (the hell's own banner), else these
  const GATE_BANNER = { 1: 'blue', 2: 'green', 4: 'purple', 5: 'gold', 7: 'teal', 8: 'pink' };
  // floor 10 burns blue at the gate and in the boss room: like any fire, with a breath of blue
  const BLUE = '190,205,245';
  const BLUE_PROPS = ['brazier_blue', 'bowl_blue'];
  // furniture against the north walls: supplies and broken masonry in hell stone, now and then a
  // candelabra or a charred table (sparse, the hell keeps its spires, skulls and braziers)
  const FOOT = {   // name: [solid width, solid depth, cells wide]
    table_b: [110, 30, 2], candelabra: [30, 20, 1], crate_pile: [80, 34, 1], sacks_b: [90, 26, 1],
    moss_rubble_a: [70, 30, 1], moss_rubble_b: [80, 28, 1], moss_ruin: [70, 34, 1],
  };
  const WALL_SET = ['crate_pile', 'moss_ruin', 'sacks_b', 'candelabra', 'moss_rubble_a', 'moss_rubble_b', 'crate_pile', 'table_b'];
  // breakable urns, barrels and crates along the walls (rune stones, a heart, or demons from crates)
  const BREAK_SET = ['barrel_a', 'barrel_b', 'barrel_c', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'crate_a', 'crate_b', 'crate_c'];
  // chests: in a fight room six in ten bite; a treasure chest bites rarely
  const MIMIC_FIGHT = .6, MIMIC_TREASURE = .15;
  // the pack as plain data (the Godot port reads it from assets/data/hell_world.json, see export_world.js)
  const PACK = { floors: FLOORS, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES, words: WORDS, theme_flag: null, light: null, gate_banner: GATE_BANNER, blue: BLUE, blue_props: BLUE_PROPS, foot: FOOT, wall_set: WALL_SET, break_set: BREAK_SET, mimic_fight: MIMIC_FIGHT, mimic_treasure: MIMIC_TREASURE };
  return WorldPack.make(PACK);
});

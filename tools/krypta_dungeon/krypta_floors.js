// The ten crypt floors (Story 1, Krypta der Verdammten) as a world kit pack.
// Runs on the shared world kit generator (tools/world_kit/world_core.js) and the shared pack
// functions (tools/world_kit/world_pack.js); only the floor values, names, wording and dressing
// tables are the crypt's. Poison mire takes the place of lava, grave-gas vents the place of fire
// vents, soul bowls the place of fire bowls.
// Use: WorldCore.buildFloor(n, sizes, KryptaFloors.forRun(run)), then KryptaFloors.dress(W).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('../world_kit/world_pack.js'));
  else root.KryptaFloors = factory(root.WorldPack);
})(typeof self !== 'undefined' ? self : this, function (WorldPack) {
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
  const GATE_BANNER = { 1: 'blue', 2: 'green', 4: 'purple', 5: 'gold', 7: 'teal', 8: 'pink' };
  // blue fire lights the room like any fire, with only a breath of blue in it
  const BLUE = '190,205,245';
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
  // the soul bowls are the crypt's blue fire bowls
  const BLUE_PROPS = ['brazier_bowl', 'brazier_blue', 'bowl_blue'];
  // a touch lighter than the hell
  const LIGHT = { dark: .86, vignette: .85 };
  // the pack as plain data (the Godot port reads it from assets/data/krypta_world.json, see export_world.js)
  const PACK = { floors: FLOORS, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES, words: WORDS, theme_flag: 'crypt', light: LIGHT, gate_banner: GATE_BANNER, blue: BLUE, blue_props: BLUE_PROPS, foot: FOOT, wall_set: WALL_SET, break_set: BREAK_SET, mimic_fight: MIMIC_FIGHT, mimic_treasure: MIMIC_TREASURE };
  const world = WorldPack.make(PACK);
  return Object.assign(world, { crypt: world.wording });
});

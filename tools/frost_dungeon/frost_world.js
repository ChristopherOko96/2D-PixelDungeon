// The ten Frostgruft floors (Story 2) as a world kit pack: every floor is built anew from the run
// number on the shared generator (tools/world_kit/world_core.js) and dressed by the shared pack
// functions (tools/world_kit/world_pack.js). Titles, bosses, hazards and difficulty are the
// Frostgruft's ten floors as before (bake_frost_floors.js); glaze ice takes the place of lava,
// frost flames the place of fire bowls, ice crystals the place of skull heaps. No mimic chests:
// the Frostgruft has no mimic among its monsters. Room sizes follow the world kit (fight rooms
// medium or large; key room, vaults, loot room, hidden rooms, stairs and descent small).
// The skins are assets/sprites/frost (pixel) and assets/sprites/frost_hd (HD), plus the world kit
// pieces (tools/frost_dungeon/build_frost_extras.py).
// Use: WorldCore.buildFloor(n, sizes, FrostWorld.forRun(run)), then FrostWorld.dress(W).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('../world_kit/world_pack.js'));
  else root.FrostWorld = factory(root.WorldPack);
})(typeof self !== 'undefined' ? self : this, function (WorldPack) {
  'use strict';
  const FLOORS = [
    null,
    { n: 1, title: 'Frostpforte', circle: 0, seed: 21101, gc: 7, gr: 6, path: 13, rooms: 22, lava: .15, spikes: .1, vents: .1, holes: .45, pits: .25, loops: .35, mainLock: true, fire: 3, seq: false, boss: { name: 'Großer Eisschleim', hp: 46, summon: 4, ring: 0 } },
    { n: 2, title: 'Eiskeller', circle: 0, seed: 21202, gc: 7, gr: 6, path: 13, rooms: 22, lava: .2, spikes: .15, vents: .15, holes: .45, pits: .3, loops: .35, mainLock: true, fire: 3, seq: true, boss: { name: 'Kobold-Rudelführer', hp: 60, summon: 4, ring: 0 } },
    { n: 3, title: 'Gruft des Nekromanten', circle: 0, seed: 21303, gc: 7, gr: 6, path: 14, rooms: 23, lava: .2, spikes: .2, vents: .2, holes: .45, pits: .3, loops: .35, mainLock: true, fire: 0, seq: true, boss: { name: 'Frostnekromant', hp: 90, summon: 3.6, ring: 3.4, mini: true } },
    { n: 4, title: 'Kristallgänge', circle: 1, seed: 21404, gc: 8, gr: 6, path: 15, rooms: 25, lava: .3, river: .25, spikes: .2, vents: .3, holes: .35, pits: .2, loops: .3, mainLock: true, fire: 4, seq: false, shooters: true, boss: { name: 'Frostwirbel-Zwillinge', hp: 105, summon: 3.6, ring: 3.2 } },
    { n: 5, title: 'Gefrorener See', circle: 1, seed: 21505, gc: 8, gr: 6, path: 16, rooms: 26, lava: .55, river: .55, spikes: .2, vents: .3, holes: .35, pits: .2, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Kristallwächter', hp: 120, summon: 3.4, ring: 3.0 } },
    { n: 6, title: 'Halle der Frostleiche', circle: 1, seed: 21606, gc: 8, gr: 6, path: 16, rooms: 26, lava: .4, river: .35, spikes: .3, vents: .35, holes: .3, pits: .25, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Frostleiche', hp: 160, summon: 3.2, ring: 2.6, mini: true } },
    { n: 7, title: 'Schneesturmgalerie', circle: 2, seed: 21707, gc: 8, gr: 7, path: 17, rooms: 28, lava: .3, river: .25, spikes: .4, vents: .45, holes: .5, pits: .4, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Eisritter-Garde', hp: 175, summon: 3.0, ring: 2.6 } },
    { n: 8, title: 'Gletscherspalten', circle: 2, seed: 21808, gc: 8, gr: 7, path: 18, rooms: 29, lava: .35, river: .3, spikes: .5, vents: .4, holes: .5, pits: .55, loops: .3, mainLock: true, fire: 3, seq: true, shooters: true, boss: { name: 'Sturmkristall', hp: 190, summon: 2.8, ring: 2.4 } },
    { n: 9, title: 'Kaserne des Kommandanten', circle: 2, seed: 21909, gc: 8, gr: 7, path: 18, rooms: 30, lava: .35, river: .3, spikes: .5, vents: .45, holes: .5, pits: .45, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, boss: { name: 'Frostkommandant', hp: 240, summon: 2.6, ring: 2.0, mini: true } },
    { n: 10, title: 'Thron des Gletscherkolosses', circle: 3, seed: 22010, gc: 8, gr: 7, path: 18, rooms: 30, lava: .45, river: .4, spikes: .5, vents: .5, holes: .45, pits: .4, loops: .3, mainLock: true, fire: 4, seq: true, shooters: true, final: true, boss: { name: 'Hrimgar, der Gletscherkoloss', hp: 340, summon: 2.4, ring: 1.6, final: true } },
  ];
  const CIRCLES = ['Abschnitt I · Frostpforte', 'Abschnitt II · Gefrorene Tiefe', 'Abschnitt III · Gletscherherz', 'Abschnitt IV · Thron des Winters'];
  const NAMES = [['Reif', 'Frost', 'Schnee', 'Eis', 'Firn', 'Hagel', 'Kälte', 'Raureif'], ['Gletscher', 'Eis', 'Schollen', 'Kristall', 'Spiegel', 'Nebel', 'Frost', 'Tiefen'],
    ['Sturm', 'Splitter', 'Kristall', 'Wächter', 'Ritter', 'Winter', 'Hagel', 'Frost'], ['Thron', 'Gletscher', 'Winter', 'Kristall', 'Sturm', 'Schnee', 'Eis', 'Firn']];
  const SUFFIXES = ['halle', 'kammer', 'gang', 'grube', 'kreuz', 'gruft', 'galerie', 'spalte', 'pforte', 'kerker', 'nische', 'saal', 'hof', 'stiege', 'krypta', 'kluft'];
  // The generator's hell wording in frost terms (the baked floors' list, applied in order; the key
  // room's old altar sentence first, before 'Altar' turns into 'Brunnen').
  const WORDS = [
    ['Daneben ein Altar (später ein Laden) und ein Manabrunnen', 'Daneben der Laden und ein Manabrunnen'],
    ['Glutschlüssel', 'Goldschlüssel'], ['Knochenschlüssel', 'Eisschlüssel'], ['Dämonenschlüssel', 'Kristallschlüssel'],
    ['Feuerschalen', 'Frostflammen'], ['Feuerschale', 'Frostflamme'], ['Runenplatten', 'Eisplatten'], ['Feuerplatte', 'Brunnenplatte'],
    ['Schädelhaufen', 'Eiskristall'], ['Riesentresor', 'Frosttresor'], ['Portalkammer', 'Treppenkammer'], ['Portal zur nächsten Etage', 'Treppe zur nächsten Etage'],
    ['Herzschrein', 'Brunnenkammer'], ['Knochenaltar', 'Schlüsselkammer'], ['Altar', 'Brunnen'], ['Lavagraben', 'Eiswasser'], ['Lava', 'Eiswasser'],
  ];
  // banners in the floor colour: red on floors 3, 6, 9 and 10, else these (world kit rule)
  const GATE_BANNER = { 1: 'blue', 2: 'green', 4: 'purple', 5: 'gold', 7: 'teal', 8: 'pink' };
  // floor 10 burns blue at the gate and in the boss room
  const BLUE = '190,205,245';
  const BLUE_PROPS = ['brazier_blue', 'bowl_blue'];
  // furniture against the north walls and breakables along them: the world kit's set, frozen
  const FOOT = {   // name: [solid width, solid depth, cells wide]
    table_a: [104, 30, 2], table_b: [110, 30, 2], table_c: [140, 30, 2], candelabra: [30, 20, 1], crate_pile: [80, 34, 1],
    sacks_b: [90, 26, 1], moss_rubble_a: [70, 30, 1], moss_rubble_b: [80, 28, 1], moss_ruin: [70, 34, 1],
    snowman: [52, 26, 1], glacier_a: [86, 34, 1], glacier_b: [70, 30, 1],
  };
  // Snow (world_pack.js winter): far fewer bones and stone heaps (the core lays them as props), no
  // ash patches (the hell's moss), snow fields on the floor (melting around fire and light), a
  // snowman or a glacier in some fight rooms.
  const WINTER = {
    thin_decals: { keep: 0, names: ['moss_a', 'moss_b', 'moss_c'] },
    thin_props: { keep: .15, names: ['bone_a', 'bone_b', 'bone_c', 'bone_d', 'bone_e', 'bone_f', 'bone_g', 'bones_scatter', 'bones_t', 'rubble', 'coal', 'rocks_b', 'skull_pile_t',
      'skull_pile', 'spires_t', 'spire_mid', 'rocks_a', 'coal_skulls', 'boulders', 'cage_small', 'spire_big_b', 'rocks_lava', 'spires_lava', 'spire_big', 'spire_big_t', 'rocks_dark', 'spire_small'] },
    snow: ['snow_a', 'snow_b', 'snow_c', 'snow_d'], size: 168, seed_cells: 9, melt: 1.7,
    snowman: .35, glacier: .45, glaciers: ['glacier_a', 'glacier_b'],
  };
  const WALL_SET = ['table_a', 'table_b', 'table_c', 'candelabra', 'crate_pile', 'moss_ruin', 'sacks_b', 'candelabra', 'moss_rubble_a', 'moss_rubble_b'];
  const BREAK_SET = ['barrel_a', 'barrel_b', 'barrel_c', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'crate_a', 'crate_b', 'crate_c'];
  // no mimics in the Frostgruft
  const MIMIC_FIGHT = 0, MIMIC_TREASURE = 0;
  // the pack as plain data (the Godot port reads it from assets/data/frost_world.json, see export_world.js)
  const PACK = { floors: FLOORS, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES, words: WORDS, theme_flag: 'frost', light: null, gate_banner: GATE_BANNER, blue: BLUE, blue_props: BLUE_PROPS, foot: FOOT, wall_set: WALL_SET, break_set: BREAK_SET, mimic_fight: MIMIC_FIGHT, mimic_treasure: MIMIC_TREASURE, winter: WINTER };
  return WorldPack.make(PACK);
});

// Bakes the ten Frostgruft floors (Story 2) into assets/data/frost_floors.json.
// Same generator and schema as the Hell-Dungeon (tools/hell_dungeon), with frost
// floor parameters, names and texts. Sprite sizes come from assets/sprites/frost.
// Usage (repo root): node tools/frost_dungeon/bake_frost_floors.js
'use strict';
const fs = require('fs');
const path = require('path');
const { bake, sizesFrom, root } = require('../hell_dungeon/bake_floors.js');

// Open ice water replaces lava: lower shares, frost vents instead of fire vents.
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

// Hell wording in the core's room texts and group labels, in frost terms.
const WORDS = [
  ['Glutschlüssel', 'Goldschlüssel'], ['Knochenschlüssel', 'Eisschlüssel'], ['Dämonenschlüssel', 'Kristallschlüssel'],
  ['Feuerschalen', 'Frostflammen'], ['Feuerschale', 'Frostflamme'], ['Runenplatten', 'Eisplatten'], ['Feuerplatte', 'Brunnenplatte'],
  ['Schädelhaufen', 'Eiskristall'], ['Riesentresor', 'Frosttresor'], ['Portalkammer', 'Treppenkammer'], ['Portal zur nächsten Etage', 'Treppe zur nächsten Etage'],
  ['Herzschrein', 'Brunnenkammer'], ['Knochenaltar', 'Schlüsselkammer'], ['Altar', 'Brunnen'], ['Lavagraben', 'Eiswasser'], ['Lava', 'Eiswasser'],
];
const frost = text => WORDS.reduce((t, [a, b]) => t.split(a).join(b), text);

const SIZES = sizesFrom('assets/sprites/frost/manifest.json');
const floors = [];
for (let n = 1; n <= 10; n++) {
  const f = bake(n, SIZES, { floors: FLOORS, circles: CIRCLES, names: NAMES, suffixes: SUFFIXES });
  for (const r of f.rooms) { r.name = frost(r.name); r.kind = frost(r.kind); r.info = frost(r.info); }
  for (const g of Object.values(f.groups)) if (g.label) g.label = frost(g.label);
  f.theme.frost = true;
  floors.push(f);
}
const out = path.join(root, 'assets/data/frost_floors.json');
fs.writeFileSync(out, JSON.stringify({ schema: 1, source: 'tools/frost_dungeon/bake_frost_floors.js', sprites: 'res://assets/sprites/frost/', floors }));
console.log('baked', floors.length, 'frost floors ->', path.relative(root, out), (fs.statSync(out).size / 1e6).toFixed(2), 'MB');
for (const f of floors) console.log(`  E${f.n} ${f.title}: ${f.rooms.length} rooms, quickest ${f.quick}, ${f.props.length} props, ${f.ents.length} entities, boss ${f.boss.name}`);

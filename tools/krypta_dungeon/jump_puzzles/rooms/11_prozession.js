// Die Prozession: along the north wall of the walkway five guardians stand in a row, from evening
// (west) to morning (east): skull, angel, demon, monk, rune pillar. Down in the gorge the same five
// guard five plates, in another order. Landing on a pillar steps its plate, so the hero must find the
// way through the pads that visits them in the order of the procession, over the plain stones.
// Route: B1 > Schädel 1 > A2 > Engel 2 > B1 > Schädel (lit) > B3 > Dämon 3 > B3 > Mönch 4 > Rune 5.
const { sheet, network } = require('../canvas');

const s = sheet(48, 11);
const marks = {};
s.fill(1, 1, 46, 2, '.');     // the walkway with the procession
s.fill(1, 3, 7, 9, '.');      // west hall, its ledge at column 8
s.fill(8, 4, 8, 9, '.');
s.fill(9, 4, 38, 9, 'o');     // the gorge
s.fill(39, 3, 40, 9, '.');    // east ledge
s.fill(42, 4, 46, 9, '.');    // the vault behind gate A
network(s, marks, {
  W5: [8, 5], W8: [8, 8], E5: [39, 5], E8: [39, 8],
  A1: [13, 5, { plate: 'A', order: 2 }], A2: [20, 5], A3: [27, 5, { plate: 'A', order: 4, enemies: ['random'] }], A4: [34, 5, { plate: 'A', order: 5, enemies: ['random'] }],
  B1: [13, 8], B2: [20, 8, { plate: 'A', order: 1 }], B3: [27, 8], B4: [34, 8, { plate: 'A', order: 3, enemies: ['random'] }],
}, [
  ['W8', 'B1'], ['W5', 'A1'],
  ['B1', 'B2'], ['B1', 'A1'],
  ['A1', 'A2'], ['A1', 'B1'],
  ['A2', 'A3'], ['A2', 'B2'], ['A2', 'A1'],
  ['B2', 'B3'], ['B2', 'A2'],
  ['B3', 'B4'], ['B3', 'A3'],
  ['B4', 'A4'], ['B4', 'E8'], ['B4', 'B3'],
  ['A3', 'A4'], ['A3', 'B3'],
  ['A4', 'E5'], ['A4', 'B4'],
]);
s.put([
  // the procession on the walkway, west to east, and the same guardians in the gorge
  [10, 1, 'k'], [15, 1, 'e'], [20, 1, 'd'], [30, 1, 'm'], [35, 1, 'r'],
  [20, 9, 'k'], [13, 4, 'e'], [34, 9, 'd'], [27, 4, 'm'], [34, 4, 'r'],
  [3, 5, '@'], [6, 4, 'T'], [2, 4, 'b'], [2, 9, 'b'], [6, 9, 'q'],
  [41, 6, 'G'], [44, 6, '$'], [43, 4, 'f'], [46, 4, 'f'], [43, 9, 'c'], [46, 9, 'c'],
  [45, 1, 'M'], [26, 2, 'u'], [12, 2, 'v'], [39, 9, 'w'],
]);
Object.assign(marks, {
  '@': { start: true },
  'T': { tablet: 'Die Wächter ziehen an der Nordmauer entlang,\nvom Abend zum Morgen.\nIn dieser Folge sollst du sie in der Schlucht besuchen.\nWer die Prozession stört, weckt die Toten.' },
  'k': { prop: 'skull_obelisk' }, 'e': { prop: 'statue_angel' }, 'd': { prop: 'gargoyle' }, 'm': { prop: 'statue_monk' }, 'r': { prop: 'rune_pillar_a' },
  'b': { prop: 'brazier_low' }, 'q': { prop: 'candelabra' }, 'f': { prop: 'brazier_pillar' }, 'c': { prop: 'candelabra' },
  'G': { gate: 'A', dir: 'h' },
  '$': { chest: 'hoard' },
  'M': { chest: 'random', mimic: 'random', mimic_mob: 'truhenfresser' },
  'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
  'v': { prop: 'urn_a', loot: { type: 'random' } },
  'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random'] },
});

module.exports = {
  file: 'k_sprung_grubensteg',
  title: 'Sprung: Die Prozession (lang)',
  slots: [[0, 0], [1, 0], [2, 0]],
  ports: [['north', 6, 0], ['west', 0, 5], ['south', 6, 10], ['north', 23, 0], ['north', 40, 0]],
  map: s.rows(),
  marks,
  bare: (x, y) => x === 8 || x === 39 || x === 40,
};

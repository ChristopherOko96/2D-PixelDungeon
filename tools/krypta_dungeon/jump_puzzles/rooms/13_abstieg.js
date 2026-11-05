// Der Abstieg: a shaft of pits with six plates on three levels, two on each. The pads run sideways and
// down, never up. The stone at the top says to read the shaft as the old scribes wrote: line by line,
// but every line turns back (first level left to right, the second right to left, the third left to
// right again). A wrong plate wakes the dead and a hero who went down wrongly climbs the stair at the
// side to try again. Solved, the vault at the foot of the shaft opens.
// Route: top > 1 (left) > 2 (right) > 3 (right) > 4 (left) > 5 (left) > 6 (right) > bottom ledge.
const { sheet, network } = require('../canvas');

const s = sheet(14, 39);
const marks = {};
s.fill(1, 1, 2, 37, '.');     // the stair at the side, the doors' way
s.fill(1, 1, 12, 2, '.');     // the top ledge
s.fill(3, 3, 12, 30, 'o');    // the shaft
s.fill(3, 3, 3, 30, '#');     // a wall between the stair and the shaft
s.fill(3, 31, 12, 32, '.');   // the bottom ledge, open to the stair
s.fill(4, 34, 12, 37, '.');   // the vault behind gate A
network(s, marks, {
  T5: [5, 2], T10: [10, 2],
  a: [5, 8, { plate: 'A', order: 1 }], b: [10, 8, { plate: 'A', order: 2 }],
  d: [5, 18, { plate: 'A', order: 4, enemies: ['random'] }], c: [10, 18, { plate: 'A', order: 3 }],
  e: [5, 28, { plate: 'A', order: 5, enemies: ['random'] }], f: [10, 28, { plate: 'A', order: 6, enemies: ['random', 'random'] }],
  B5: [5, 31], B10: [10, 31],
}, [
  ['T5', 'a'], ['T10', 'b'],
  ['a', 'b'], ['b', 'a'],
  ['a', 'd'], ['b', 'c'],
  ['c', 'd'], ['d', 'c'],
  ['c', 'f'], ['d', 'e'],
  ['e', 'f'], ['f', 'e'],
  ['e', 'B5'], ['f', 'B10'],
]);
s.put([
  [3, 34, 'G'],
  [8, 36, '$'], [5, 34, 'f'], [11, 34, 'f'], [5, 37, 'c'], [11, 37, 'c'],
  [7, 1, 'T'], [11, 1, 'b'], [2, 4, '@'], [1, 12, 'k'], [2, 26, 'k'], [12, 32, 'M'], [1, 35, 'u'], [2, 18, 'v'], [4, 32, 'w'],
]);
Object.assign(marks, {
  'T': { tablet: 'Lies den Schacht, wie die alten Schreiber schrieben:\nZeile um Zeile, von oben nach unten,\ndoch jede Zeile kehrt um.\nWer falsch liest, weckt die Toten.' },
  'G': { gate: 'A', dir: 'h' },
  '$': { chest: 'hoard' },
  'f': { prop: 'brazier_pillar' }, 'c': { prop: 'candelabra' }, 'b': { prop: 'brazier_low' }, 'k': { prop: 'skull_pile' },
  '@': { start: true },
  'M': { chest: 'random', mimic: 'random', mimic_mob: 'truhenfresser' },
  'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
  'v': { prop: 'urn_a', loot: { type: 'random' } },
  'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random'] },
});

module.exports = {
  file: 'k_sprung_moderschacht',
  title: 'Sprung: Der Abstieg (Turm)',
  slots: [[0, 0], [0, 1], [0, 2]],
  ports: [['north', 6, 0], ['west', 0, 5], ['west', 0, 19], ['west', 0, 33]],
  map: s.rows(),
  marks,
  bare: (x, y) => y <= 2 || (y >= 31 && y <= 32),
};

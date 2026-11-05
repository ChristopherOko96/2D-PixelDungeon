// Die Schleusen: a pit field where most pads lie dark. Each solved step wakes some of them, and the
// hero must remember where the dark ones were:
//   plate A on the near pillar P wakes the way from I1 to I2;
//   the fire bowl B on I2 wakes the ways to I3 and to I4;
//   plate C on I4, the island of the biting chest, wakes the way from I3 to I5;
//   I5 holds key A, which opens the vault by the hall of the doors.
// A Moder pool by the ledge takes the careless.
const { sheet, network } = require('../canvas');

const s = sheet(31, 25);
const marks = {};
s.fill(1, 1, 7, 9, '.');      // hall of the doors and the ledge (column 7)
s.fill(1, 10, 3, 23, '.');    // west strip
s.fill(1, 19, 12, 23, '.');   // lower hall
s.fill(5, 11, 12, 17, '.');   // vault behind the locked gate
s.fill(8, 1, 29, 9, 'o');
s.fill(8, 5, 13, 6, '~');     // the Moder pool by the ledge
s.fill(19, 7, 22, 9, '.');    // I4, the island of the biting chest
s.fill(26, 7, 28, 9, '.');    // I5
network(s, marks, {
  L3: [7, 3], L7: [7, 7], L8: [7, 8],
  P: [12, 7, { plate: 'A' }],
  I1: [12, 3], I2: [20, 3], I3: [27, 3],
  I4: [20, 8], I5: [27, 8],
  pool: [12, 6, { land: true, on: '~' }],
}, [
  ['L7', 'P'], ['P', 'L7'],
  ['L3', 'I1'], ['I1', 'L3'], ['I1', 'pool'],
  ['I1', 'I2', { wake: 'A' }], ['I2', 'I1'],
  ['I2', 'I3', { wake: 'B' }], ['I2', 'I4', { wake: 'B' }], ['I3', 'I2'],
  ['I4', 'L8'],
  ['I3', 'I5', { wake: 'C' }], ['I5', 'I4'],
]);
s.put([
  [3, 4, '@'], [5, 2, 'T'], [2, 1, 'b'], [2, 9, 'b'], [6, 9, 'q'],
  [20, 2, 'B'],
  [21, 8, 'C'], [19, 7, 'M'], [22, 7, 'r'], [22, 9, 'w'], [19, 9, 'w'],
  [28, 8, 'K'], [26, 7, 'q'], [28, 9, 'v'],
  [4, 13, 'G'], [8, 14, '$'], [6, 12, 'f'], [11, 12, 'f'], [6, 16, 'c'], [11, 16, 'c'], [10, 11, 'v'],
  [2, 22, 'm'], [9, 20, 'u'], [11, 23, 'w'], [12, 20, 'k'],
]);
Object.assign(marks, {
  '@': { start: true },
  'T': { tablet: 'Die Schleusen schlafen.\nJedes gelöste Siegel weckt einen Teil des Weges.\nMerke dir, wo die dunklen Platten liegen.' },
  'B': { brazier: 'B' },
  'C': { plate: 'C' },
  'K': { chest: 'key', id: 'A' },
  'M': { chest: 'random', mimic: 'yes', mimic_mob: 'truhenfresser' },
  'r': { chest: 'random' },
  'G': { gate: 'A', dir: 'h', lock: 'A' },
  '$': { chest: 'hoard' },
  'b': { prop: 'brazier_low' }, 'q': { prop: 'candelabra' }, 'f': { prop: 'brazier_pillar' }, 'c': { prop: 'candelabra' }, 'k': { prop: 'skull_obelisk' },
  'm': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
  'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
  'v': { prop: 'urn_a', loot: { type: 'random' } },
  'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random'] },
});

module.exports = {
  file: 'k_sprung_moderbecken_la',
  title: 'Sprung: Die Schleusen (Winkel)',
  slots: [[0, 0], [1, 0], [0, 1]],
  ports: [['north', 6, 0], ['west', 0, 5], ['south', 6, 24], ['west', 0, 19], ['east', 13, 19]],
  map: s.rows(),
  marks,
  bare: (x, y) => x === 7,
};

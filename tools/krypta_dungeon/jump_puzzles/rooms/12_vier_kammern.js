// Vier Kammern: four sealed chambers under the walkway, each with its own lock, each waking the pad
// that throws over the wall into the next:
//   I   the fire bowl on the pillar in the pit (a throw across, a throw back) wakes the pad to II;
//   II  three plates beside light, sky and death, in the order of a small riddle (sky, light, death);
//   III the dead torch stands on an island in the Moder, reached by a chain of two throws: lit, it opens
//       the hidden wall at the end of the bridge into IV, the vault.
// Every chamber has a pad back up to the walkway, so a hero who gives up is never shut in.
const { sheet } = require('../canvas');

const s = sheet(48, 11);
s.fill(1, 1, 46, 2, '.');     // walkway
s.fill(1, 3, 4, 9, '.');      // west hall
s.fill(6, 4, 8, 9, '.');      // chamber I: a ledge and the pit
s.fill(9, 4, 14, 9, 'o');
s.fill(16, 4, 24, 9, '.');    // chamber II
s.fill(26, 4, 27, 9, '.');    // chamber III: a ledge and the Moder
s.fill(28, 4, 34, 9, '~');
s.fill(30, 4, 31, 5, '.');    // the torch island
s.fill(31, 6, 34, 6, '=');    // the bridge to the hidden wall
s.fill(36, 4, 41, 9, '.');    // chamber IV, the vault
s.fill(43, 3, 46, 9, '.');    // east hall
s.put([
  [4, 7, 'a'], [7, 7, 'k'],               // west hall > I
  [8, 7, 'b'], [11, 7, 'B'], [12, 7, 'F'], [10, 7, 'c'], // I: across to the bowl and back
  [8, 5, 'p'], [7, 4, 'u'],               // I > II (asleep), I > walkway
  [17, 5, 'L'], [24, 6, 'P'], [20, 4, 'U'], // II: landing, > III (asleep), > walkway
  [18, 5, '1'], [21, 8, '2'], [23, 5, '3'], [18, 4, 'l'], [21, 9, 'h'], [23, 4, 't'], [17, 9, 'T'],
  [27, 6, 'K'], [27, 7, 'J'], [28, 7, 'd'], [31, 7, 'e'], [31, 5, 'I'], [30, 5, 'f'], [31, 4, 'D'], [27, 4, 'g'],
  [35, 6, 'S'], [36, 4, 'h2'],
]);
// 'h2' is not one char: put the vault's way up by hand
s.set(36, 4, 'V');
s.put([
  [38, 7, '$'], [37, 9, 'C'], [40, 9, 'C'], [41, 4, 'f2'],
]);
s.set(41, 4, 'Z');
s.put([[2, 4, 'W'], [3, 3, '@'], [44, 4, 'b2'], [44, 9, 'b3'], [46, 8, 'M'], [10, 2, 'u2'], [33, 2, 'v'], [45, 2, 'w']]);
s.set(44, 4, 'Y'); s.set(44, 9, 'Y'); s.set(10, 2, 'y');

const marks = {
  'a': { pad: 'e', to: 'k' }, 'k': { land: true },
  'b': { pad: 'e', to: 'B' }, 'B': { land: true }, 'F': { brazier: 'B' }, 'c': { pad: 'w', to: 'k' },
  'p': { pad: 'e', to: 'L', wake: 'B' }, 'u': { pad: 'n', n: 3 },
  'L': { land: true }, 'P': { pad: 'e', to: 'K', wake: 'C' }, 'U': { pad: 'n', n: 3 },
  '1': { plate: 'C', order: 2, enemies: ['random'] }, '2': { plate: 'C', order: 1 }, '3': { plate: 'C', order: 3, enemies: ['random'] },
  'l': { prop: 'candelabra' }, 'h': { prop: 'statue_angel' }, 't': { prop: 'skull_pile' },
  'T': { tablet: 'Licht, Himmel, Tod.\nDer Tod kommt nicht zuerst.\nDer Himmel geht dem Licht voran.\nDas Licht ist nicht das Letzte.' },
  'K': { land: true }, 'J': { land: true }, 'd': { pad: 'e', to: 'e' }, 'e': { pad: 'n', to: 'I' }, 'I': { land: true },
  'f': { pad: 'w', n: 3 }, 'D': { lever: 'D' }, 'g': { pad: 'n', n: 3 },
  'S': { secret: 'D', dir: 'h' },
  'V': { pad: 'n', n: 3 },
  '$': { chest: 'hoard' }, 'C': { prop: 'candelabra' }, 'Z': { prop: 'brazier_pillar' },
  'W': { tablet: 'Vier Kammern, vier Schlösser.\nJedes geöffnete weckt den Sprung in die nächste.' },
  '@': { start: true },
  'Y': { prop: 'brazier_low' },
  'M': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
  'y': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
  'v': { prop: 'urn_a', loot: { type: 'random' } },
  'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random', 'random'] },
};

module.exports = {
  file: 'k_sprung_kammern',
  title: 'Sprung: Vier Kammern (lang)',
  slots: [[0, 0], [1, 0], [2, 0]],
  ports: [['north', 6, 0], ['west', 0, 5], ['north', 23, 0], ['north', 40, 0], ['east', 47, 5]],
  map: s.rows(),
  marks,
};

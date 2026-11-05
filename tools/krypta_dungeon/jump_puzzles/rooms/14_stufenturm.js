// Der Stufenturm: three trials on top of each other, each waking the pad to the next.
//   Below: a bridge of spikes that rise in turn leads up to the fire bowl. Burning, it wakes the pad up.
//   Middle: three plates beside skull, angel and monk, stepped in the order of the riddle (skull,
//   angel, monk). Solved, the pad to the top wakes. A pad over the wall lets a hero give up here.
//   Top: two chests, one always lies, one never. The right one holds the Schatz, the left one bites.
// The stair at the east side joins all doors without any trial.
const { sheet } = require('../canvas');

const s = sheet(14, 39);
s.fill(11, 1, 12, 37, '.');   // the stair
s.fill(1, 1, 12, 2, '.');     // top hall
s.fill(1, 36, 12, 37, '.');   // bottom hall
s.fill(2, 4, 8, 8, '.');      // top: the chests' island
s.fill(1, 9, 9, 12, 'o');
s.fill(1, 14, 9, 23, 'o');    // middle: the plate platform in pits
s.fill(2, 15, 8, 22, '.');
s.fill(1, 25, 9, 28, '.');    // below: the fire bowl's platform
s.fill(1, 29, 9, 35, 'o');
s.fill(5, 29, 5, 35, '.');    // the spike bridge
s.put([
  [5, 25, 'p'], [5, 21, 'L'], [5, 15, 'q'], [5, 8, 'K'], [5, 4, 'r'], [8, 22, 'x'],
  [2, 26, 'B'], [8, 26, 'b'],
  [3, 17, '1'], [5, 19, '2'], [7, 17, '3'], [3, 16, 'k'], [5, 20, 'e'], [7, 16, 'm'], [2, 21, 'T'],
  [3, 5, 'C'], [7, 5, 'D'], [3, 6, 'U'], [7, 6, 'V'], [5, 7, 'W'],
  [3, 36, '@'], [2, 37, 'X'], [9, 37, 'c'], [1, 1, 'c'], [12, 12, 'u'], [11, 28, 'v'], [12, 20, 'w'],
]);
for (let y = 29; y <= 35; y++) s.set(5, y, y % 2 ? 'y' : 'z');

module.exports = {
  file: 'k_sprung_stufen',
  title: 'Sprung: Der Stufenturm (Turm)',
  slots: [[0, 0], [0, 1], [0, 2]],
  ports: [['north', 6, 0], ['east', 13, 5], ['east', 13, 19], ['east', 13, 33], ['south', 6, 38]],
  map: s.rows(),
  marks: {
    'p': { pad: 'n', to: 'L', wake: 'B' },
    'L': { land: true },
    'q': { pad: 'n', to: 'K', wake: 'C' },
    'K': { land: true },
    'r': { pad: 'n', n: 3 },
    'x': { pad: 'e', n: 3 },
    'B': { brazier: 'B' },
    'b': { prop: 'brazier_low' },
    'y': { spikes: 0 }, 'z': { spikes: 1 },
    '1': { plate: 'C', order: 1 }, '2': { plate: 'C', order: 2, enemies: ['random'] }, '3': { plate: 'C', order: 3, enemies: ['random'] },
    'k': { prop: 'skull_obelisk' }, 'e': { prop: 'statue_angel' }, 'm': { prop: 'statue_monk' },
    'T': { tablet: 'Schädel, Engel, Mönch.\nDer Engel schweigt, bis der Schädel gesprochen hat.\nDer Mönch hat das letzte Wort.' },
    'C': { chest: 'random', mimic: 'yes', mimic_mob: 'truhenfresser' },
    'D': { chest: 'hoard' },
    'U': { tablet: 'Der Schatz liegt in der anderen Truhe.' },
    'V': { tablet: 'Wir beide sagen die Wahrheit.' },
    'W': { tablet: 'Eine der beiden Truhen lügt immer,\ndie andere nie.' },
    '@': { start: true },
    'X': { tablet: 'Drei Stufen bis zum Schatz.\nGlut, Ordnung, Wahrheit.' },
    'c': { prop: 'candelabra' },
    'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
    'v': { prop: 'urn_a', loot: { type: 'random' } },
    'w': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
  },
};

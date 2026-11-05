// Die vier Wächter: four plates on pillars over a pit field, each beside a statue (monk, skull, demon,
// angel). The stone in the hall gives the order as a riddle (Mönch, Schädel, Dämon, Engel). The pads
// between the pillars allow many orders: the hero must solve the riddle and find a route that lands on
// the pillars in that order, passing round the wrong ones by the plain stones X and Y. A wrong plate
// resets the order, the demon's and the angel's let out the dead. Solved, the vault opens.
//
// Route: ledge > X > Mönch 1 > Schädel 2 > Y > Dämon 3 > Mönch (already lit) > X > Engel 4.
const { sheet } = require('../canvas');

const s = sheet(31, 25);
// the hall of the doors: top left, a corridor down, the lower hall
s.fill(1, 1, 8, 9, '.');
s.fill(9, 2, 10, 8, '.');
s.fill(1, 10, 3, 23, '.');
s.fill(1, 19, 12, 23, '.');
// the pit field and its pillars
s.fill(11, 1, 29, 9, 'o');
// the vault behind gate A
s.fill(5, 11, 12, 17, '.');
s.put([
  [10, 2, 'l'], [10, 7, 'l'],
  [11, 2, 'p'], [13, 2, 'P'], [14, 2, 'X'], [15, 2, 'j'], [20, 2, 'J'], [21, 2, '1'], [22, 2, 'K'], [27, 2, 'Q'], [28, 2, '3'],
  [14, 3, 't'], [21, 3, 'W'], [28, 3, 'y'], [28, 6, 'C'],
  [11, 7, 'q'], [13, 7, 'H'], [14, 7, '4'], [20, 7, 'z'], [21, 7, '2'], [22, 7, 'B'], [27, 7, 'F'], [28, 7, 'Y'],
  [21, 1, 'm'], [28, 1, 'd'], [14, 8, 'e'], [21, 8, 'k'],
  // hall: start, the riddle stone, braziers; nothing on the ledge
  [4, 5, '@'], [7, 4, 'T'], [2, 2, 'b'], [2, 8, 'b'], [5, 9, 'n'], [8, 1, 'n'],
  // vault
  [4, 13, 'G'], [8, 14, '$'], [6, 12, 'f'], [11, 12, 'f'], [6, 16, 'c'], [11, 16, 'c'], [7, 11, 'r'], [10, 11, 'r'],
  // lower hall: a chest that may bite, pieces that hide the dead
  [2, 22, 'M'], [10, 20, 'u'], [11, 21, 'v'], [12, 23, 'w'], [4, 23, 'h'], [9, 23, 'h'],
]);

module.exports = {
  file: 'k_sprung_grubenring_la',
  title: 'Sprung: Die vier Wächter (Winkel)',
  slots: [[0, 0], [1, 0], [0, 1]],
  ports: [['north', 6, 0], ['west', 0, 5], ['south', 6, 24], ['west', 0, 19], ['east', 13, 19]],
  map: s.rows(),
  bare: (x, y) => x >= 9 && x <= 10,
  marks: {
    '@': { start: true },
    'T': { tablet: 'Vier Wächter, ein Weg.\nDer Mönch betet zuerst.\nDer Engel folgt nie direkt auf den Mönch.\nDer Schädel spricht vor dem Dämon.\nDer Dämon ist nicht der Letzte.\nWer falsch tritt, weckt die Toten.' },
    'l': { land: true },
    'X': { land: true },
    'Y': { land: true },
    'p': { pad: 'e', to: 'X' },
    'P': { pad: 'w', to: 'l' },
    'j': { pad: 'e', to: '1' },
    'J': { pad: 'w', to: 'X' },
    'K': { pad: 'e', to: '3' },
    'Q': { pad: 'w', to: '1' },
    't': { pad: 's', to: '4' },
    'W': { pad: 's', to: '2' },
    'y': { pad: 's', to: 'Y' },
    'C': { pad: 'n', to: '3' },
    'q': { pad: 'e', to: '4' },
    'H': { pad: 'w', to: 'l' },
    'z': { pad: 'w', to: '4' },
    'B': { pad: 'e', to: 'Y' },
    'F': { pad: 'w', to: '2' },
    '1': { plate: 'A', order: 1 },
    '2': { plate: 'A', order: 2 },
    '3': { plate: 'A', order: 3, enemies: ['random'] },
    '4': { plate: 'A', order: 4, enemies: ['random', 'random'] },
    'm': { prop: 'statue_monk' },
    'k': { prop: 'skull_obelisk' },
    'd': { prop: 'gargoyle' },
    'e': { prop: 'statue_angel' },
    'b': { prop: 'brazier_low' },
    'n': { prop: 'candelabra' },
    'f': { prop: 'brazier_pillar' },
    'c': { prop: 'candelabra' },
    'r': { prop: 'rune_big', flat: true, decal: { dy: 45, w: 0, h: 0, a: 0.9 } },
    'h': { prop: 'bench' },
    'G': { gate: 'A', dir: 'h' },
    '$': { chest: 'hoard' },
    'M': { chest: 'random', mimic: 'random', mimic_mob: 'truhenfresser' },
    'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
    'v': { prop: 'urn_a', loot: { type: 'random' } },
    'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random', 'random'] },
  },
};

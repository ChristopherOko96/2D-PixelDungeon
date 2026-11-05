// Drei Truhen, eine Wahrheit: a short way of throws over the pit field leads to an island with three
// chests. Under each stands an inscription, and the stone in the hall says that only one of the three
// tells the truth. Only the left chest holds the Schatz; the other two are Truhenfresser. The way there
// has false turns: one throws into the Moder pool, two throw the hero out onto the walkway. The last pad
// to the island sleeps until the plate B on the side stone is stepped: that way throws out to the walkway,
// so the hero must go round once more.
//
// Logic: treasure left -> only the middle stone is true. Middle or right would make two stones true.
const { sheet } = require('../canvas');

const s = sheet(31, 25);
s.fill(1, 1, 9, 9, '.');      // hall of the doors and the ledge
s.fill(10, 1, 29, 2, '.');    // walkway north
s.fill(28, 1, 29, 23, '.');   // walkway east
s.fill(18, 22, 29, 23, '.');  // walkway south
s.fill(10, 4, 26, 9, 'o');
s.fill(18, 10, 26, 20, 'o');
s.fill(10, 8, 14, 9, '~');    // the Moder pool by the ledge
s.fill(19, 16, 25, 19, '.');  // the island
s.put([
  [10, 6, 'a'], [14, 6, 'C'], [15, 6, 'b'], [14, 7, 'c'], [14, 9, 'm'],
  [19, 6, 'D'], [19, 7, 'd'], [20, 6, 'e'], [24, 6, 'B'], [24, 5, 'f'], [24, 2, 'x'], [25, 6, 'K'], [19, 5, 'g'],
  [19, 11, 'E'], [20, 11, 'h'], [19, 12, 'i'], [19, 15, 'z'],
  [24, 11, 'F'], [24, 12, 'j'], [25, 11, 'k'], [28, 11, 'x'], [24, 17, 'I'],
  [20, 16, '1'], [22, 16, '2'], [24, 16, '3'], [20, 18, 'T'], [22, 18, 'U'], [24, 18, 'V'],
  [25, 19, 'r'], [28, 19, 'x'], [19, 19, 'u'], [19, 17, 'n'],
  [5, 3, 'W'], [3, 5, '@'], [2, 1, 'q'], [8, 1, 'q'], [2, 8, 'q'],
  [12, 1, 'v'], [16, 1, 'v'], [29, 9, 'w'], [29, 14, 'v'], [21, 23, 'w'], [27, 23, 'y'],
]);

module.exports = {
  file: 'k_sprung_grubenring_la_gs',
  title: 'Sprung: Drei Truhen (Winkel)',
  slots: [[0, 0], [1, 0], [1, 1]],
  ports: [['north', 6, 0], ['west', 0, 5], ['south', 6, 10], ['north', 23, 0], ['east', 30, 5], ['east', 30, 19], ['south', 23, 24]],
  map: s.rows(),
  bare: (x, y) => x === 9 && y >= 4,
  marks: {
    '@': { start: true },
    'W': { tablet: 'Auf der Insel warten drei Truhen.\nZwei davon haben Zähne.\nUnter jeder steht eine Inschrift,\naber nur eine von ihnen spricht die Wahrheit.' },
    'T': { tablet: 'In mir liegt der Schatz nicht.' },
    'U': { tablet: 'In mir liegt der Schatz nicht.' },
    'V': { tablet: 'Der Schatz liegt in der mittleren Truhe.' },
    '1': { chest: 'hoard' },
    '2': { chest: 'random', mimic: 'yes', mimic_mob: 'truhenfresser' },
    '3': { chest: 'random', mimic: 'yes', mimic_mob: 'truhenfresser' },
    'C': { land: true }, 'D': { land: true }, 'E': { land: true }, 'F': { land: true }, 'I': { land: true }, 'x': { land: true }, 'm': { land: true, on: '~' }, 'z': { land: true, on: 'o' },
    'a': { pad: 'e', to: 'C' },
    'b': { pad: 'e', to: 'D' },
    'c': { pad: 's', to: 'm' },
    'd': { pad: 's', to: 'E' },
    'e': { pad: 'e', to: 'B' },
    'B': { plate: 'B' },
    'K': { prop: 'skull_obelisk' },
    'f': { pad: 'n', to: 'x' },
    'g': { pad: 'n', n: 3 },
    'h': { pad: 'e', to: 'F' },
    'i': { pad: 's', to: 'z' },
    'j': { pad: 's', to: 'I', wake: 'B' },
    'k': { pad: 'e', to: 'x' },
    'r': { pad: 'e', to: 'x' },
    'q': { prop: 'brazier_low' },
    'u': { prop: 'candelabra' },
    'n': { prop: 'skull_pile' },
    'v': { prop: 'urn_b', loot: { type: 'random' } },
    'w': { prop: 'urn_a', loot: { type: 'random' }, enemies: ['random'] },
    'y': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
  },
};

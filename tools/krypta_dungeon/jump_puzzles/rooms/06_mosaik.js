// Das Mosaik: in the hall of the doors the floor shows a picture of nine tiles, four of them burning
// runes. Far away, behind a one way of throws, lie nine plates in the same picture. The four that match
// the runes open the vault; the five others are traps that wake the dead. From the plate field the
// picture cannot be seen: the hero has to keep it in mind (or walk the long way round to look again).
const { sheet, network } = require('../canvas');

// the picture: [column, row] of the four true tiles in the 3 x 3
const TRUE = [[1, 0], [0, 1], [2, 2], [1, 2]];

const s = sheet(31, 25);
const marks = {};
s.fill(1, 1, 10, 9, '.');     // hall of the doors with the mosaic, ledge at column 10
s.fill(11, 1, 29, 2, '.');    // walkway north
s.fill(28, 1, 29, 23, '.');   // walkway east
s.fill(18, 22, 29, 23, '.');  // walkway south
s.fill(11, 4, 26, 9, 'o');
s.fill(18, 10, 26, 20, 'o');
s.fill(11, 7, 16, 9, '~');    // a Moder bed for the careless, wading back to the ledge hurts
s.fill(18, 13, 22, 19, '.');  // the plate field
s.fill(24, 13, 26, 19, '.');  // the vault
s.fill(23, 12, 27, 12, '#').fill(23, 20, 27, 20, '#').fill(23, 13, 23, 19, '#');
// the mosaic and the plates: 3 x 3 with a gap between
const isTrue = (c, r) => TRUE.some(([a, b]) => a === c && b === r);
for (let r = 0; r < 3; r++) {
  for (let c = 0; c < 3; c++) {
    s.set(3 + c * 2, 3 + r * 2, isTrue(c, r) ? 'R' : 'r');
    s.set(18 + c * 2, 14 + r * 2, isTrue(c, r) ? 'A' : 'F');
  }
}
network(s, marks, {
  L: [10, 6], S1: [16, 6], S2: [21, 6], S3: [25, 6], F0: [21, 13],
  bog: [16, 8, { land: true, on: '~' }], out1: [25, 2], out2: [21, 2],
}, [
  ['L', 'S1'], ['S1', 'bog'], ['S1', 'S2'],
  ['S2', 'F0'], ['S2', 'S3'], ['S2', 'out2'], ['S3', 'out1'],
]);
// the field's way out over the wall to the south walkway, the vault's to the east walkway
s.put([[18, 19, 'x'], [26, 16, 'y']]);
Object.assign(marks, {
  'x': { pad: 's', n: 3 },
  'y': { pad: 'e', n: 2 },
  'R': { prop: 'rune_big', flat: true, decal: { dy: 45, w: 0, h: 0, a: 1 } },
  'r': { prop: 'grate_a', flat: true, decal: { dy: 34, w: 0, h: 0, a: 0.95 } },
  'A': { plate: 'A' },
  'F': { plate: 'F', order: 9, enemies: ['random'] },
});
s.put([
  [2, 1, 'b'], [9, 1, 'b'], [2, 9, 'b'], [9, 9, 'q'], [1, 2, '@'], [8, 3, 'T'],
  [23, 15, 'G'], [25, 16, '$'], [24, 13, 'f'], [26, 13, 'f'], [24, 19, 'c'],
  [12, 1, 'v'], [16, 1, 'v'], [29, 9, 'w'], [29, 14, 'v'], [21, 23, 'w'], [27, 23, 'm'],
]);
Object.assign(marks, {
  '@': { start: true },
  'T': { tablet: 'Das Bild zu deinen Füßen ist der Schlüssel.\nWas hier brennt, trägt dich dort.\nWas hier schweigt, weckt dort die Toten.' },
  'G': { gate: 'A', dir: 'h' },
  '$': { chest: 'hoard' },
  'b': { prop: 'brazier_low' }, 'q': { prop: 'candelabra' }, 'f': { prop: 'brazier_pillar' }, 'c': { prop: 'candelabra' },
  'v': { prop: 'urn_b', loot: { type: 'random' } },
  'w': { prop: 'urn_a', loot: { type: 'random' }, enemies: ['random'] },
  'm': { chest: 'random', mimic: 'random', mimic_mob: 'truhenfresser' },
});

module.exports = {
  file: 'k_sprung_moderbecken_la_gs',
  title: 'Sprung: Das Mosaik (Winkel)',
  slots: [[0, 0], [1, 0], [1, 1]],
  ports: [['north', 6, 0], ['west', 0, 5], ['south', 6, 10], ['north', 23, 0], ['east', 30, 5], ['east', 30, 19], ['south', 23, 24]],
  map: s.rows(),
  marks,
  bare: (x, y) => (x >= 2 && x <= 8 && y >= 2 && y <= 8) || (x >= 18 && x <= 22 && y >= 13 && y <= 19) || x === 10,
};

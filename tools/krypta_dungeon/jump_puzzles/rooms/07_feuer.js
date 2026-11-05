// Feuer der Ahnen: a shaft of pits with four fire bowls on four pillars. All four burning open the
// vault. The pads run one way only and several pillars lead astray: into the Moder bed, onto the ash
// island where a chest bites, or back to the ledge. The hero has to find the one round that reaches all
// four bowls, the stone says only that the fire walks against the sun (or with it, in the mirrored room,
// whose ways run the other way round).
const { sheet, network } = require('../canvas');

function plan({ file, title, slots, mirror }) {
  const W = 31;
  const X = (x) => (mirror ? W - 1 - x : x);
  const s = sheet(W, 25);
  const fill = (x0, y0, x1, y1, ch) => s.fill(Math.min(X(x0), X(x1)), y0, Math.max(X(x0), X(x1)), y1, ch);
  const put = (x, y, ch) => s.set(X(x), y, ch);
  const marks = {};
  fill(1, 1, 12, 12, 'o');      // the shaft
  fill(1, 13, 12, 18, '.');     // ledge and hall of the doors
  fill(1, 19, 29, 23, '.');     // walkway
  fill(23, 15, 24, 18, '.');    // up to the north door of the right part
  fill(15, 15, 21, 17, '.');    // vault behind gate A (in its south wall)
  fill(1, 5, 3, 7, '~');        // the Moder bed on the west side of the shaft
  fill(7, 1, 12, 1, '.');       // the ash island along the top
  const at = (x, y) => [X(x), y];
  network(s, marks, {
    L1: at(2, 13), L2: at(9, 13), Lx: at(12, 13),
    a: at(2, 9), b: at(2, 3), c: at(9, 3), d: at(9, 9),
    bog: [...at(2, 6), { land: true, on: '~' }], ash: at(9, 1), ashEnd: at(12, 1),
  }, [
    ['L1', 'a'], ['L2', 'd'],
    ['a', 'b'], ['a', 'd'],
    ['b', 'c'], ['b', 'bog'], ['bog', 'a'],
    ['c', 'd'], ['c', 'ash'],
    ['d', 'L2'], ['d', 'a'],
    ['ashEnd', 'Lx'],
  ]);
  // bowls beside the four pillars, on cells of their own
  for (const [x, y] of [[1, 9], [1, 3], [10, 3], [10, 9]]) put(x, y, 'B');
  put(3, 16, '@'); put(6, 14, 'T'); put(1, 17, 'b'); put(12, 17, 'b');
  put(18, 18, 'G'); put(18, 16, '$'); put(15, 15, 'f'); put(21, 15, 'f'); put(16, 17, 'c'); put(20, 17, 'c');
  put(8, 1, 'M');
  put(27, 21, 'm'); put(5, 22, 'u'); put(14, 20, 'v'); put(29, 23, 'w'); put(9, 23, 'k'); put(20, 23, 'k');
  // the round a > b > c > d runs clockwise (with the sun), mirrored against it
  Object.assign(marks, {
    '@': { start: true },
    'T': { tablet: `Vier Schalen, ein Kreis.\nDas Feuer wandert ${mirror ? 'gegen' : 'mit'} der Sonne\nund kehrt nie um.\nWer abkommt, wird nass oder gebissen.` },
    'B': { brazier: 'A' },
    'G': { gate: 'A', dir: 'v' },
    '$': { chest: 'hoard' },
    'M': { chest: 'random', mimic: 'yes', mimic_mob: 'truhenfresser' },
    'b': { prop: 'brazier_low' }, 'f': { prop: 'brazier_pillar' }, 'c': { prop: 'candelabra' }, 'k': { prop: 'skull_obelisk' },
    'm': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
    'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
    'v': { prop: 'urn_a', loot: { type: 'random' } },
    'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random', 'random'] },
  });
  const side = (p) => (mirror ? { east: 'west', west: 'east' }[p] || p : p);
  const px = (sd, x) => (!mirror ? x : sd === 'east' || sd === 'west' ? W - 1 - x : W - 2 - x);
  const ports = [['south', 6, 24], ['west', 0, 19], ['north', 23, 14], ['south', 23, 24], ['east', 30, 19]].map(([sd, x, y]) => [side(sd), px(sd, x), y]);
  return { file, title, slots, ports, map: s.rows(), marks, bare: (x, y) => y === 13 };
}

module.exports = [
  plan({ file: 'k_sprung_moderbecken_lc', title: 'Sprung: Feuer der Ahnen (Winkel)', slots: [[0, 0], [0, 1], [1, 1]], mirror: false }),
  plan({ file: 'k_sprung_moderbecken_lc_gs', title: 'Sprung: Feuer der Ahnen (Winkel)', slots: [[1, 0], [0, 1], [1, 1]], mirror: true }),
];

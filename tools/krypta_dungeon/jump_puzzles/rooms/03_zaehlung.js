// Die Zählung der Toten: five plates on pillars over a pit field, each with a heap of skulls beside it,
// one to five. The stone at the ledge says to step them from the lonely skull to the fivefold. Landing
// on a pillar steps its plate, so the hero must find a way through the pads that lands on the pillars
// in that order, over the plain stones Y and X and back over the ledge when the way runs out. A wrong
// plate resets the order; the fourth and fifth let out the dead.
//
// The mirrored room (Winkel the other way round) counts the skulls differently, so it has its own way.
const { sheet, network } = require('../canvas');

const TEXT = 'Die Toten liegen nicht gleich.\nZähle die Schädel an jeder Platte\nund tritt sie vom einsamen bis zum fünffachen.\nWer sich verzählt, weckt sie.';

function plan({ file, title, slots, mirror, counts }) {
  const W = 31;
  const X = (x) => (mirror ? W - 1 - x : x);
  const s = sheet(W, 25);
  const fill = (x0, y0, x1, y1, ch) => s.fill(Math.min(X(x0), X(x1)), y0, Math.max(X(x0), X(x1)), y1, ch);
  const marks = {};
  // the doors' halls: top, the west strip, the bottom, the ledge
  fill(1, 1, 12, 6, '.');
  fill(1, 7, 3, 23, '.');
  fill(1, 20, 12, 23, '.');
  fill(11, 15, 13, 23, '.');
  // the vault behind gate A
  fill(5, 8, 12, 13, '.');
  // the pit field
  fill(14, 15, 29, 23, 'o');
  const at = (x, y) => [X(x), y];
  const n = network(s, marks, {
    L1: [...at(13, 16)], L2: [...at(13, 19)], L3: [...at(13, 22)],
    a: [...at(17, 16), { plate: 'A', order: counts.a, ...(counts.a >= 4 ? { enemies: ['random'] } : {}) }],
    b: [...at(23, 16), { plate: 'A', order: counts.b, ...(counts.b >= 4 ? { enemies: ['random'] } : {}) }],
    c: [...at(28, 16), { plate: 'A', order: counts.c, ...(counts.c >= 4 ? { enemies: ['random'] } : {}) }],
    d: [...at(17, 22), { plate: 'A', order: counts.d, ...(counts.d >= 4 ? { enemies: ['random'] } : {}) }],
    e: [...at(23, 22), { plate: 'A', order: counts.e, ...(counts.e >= 4 ? { enemies: ['random'] } : {}) }],
    Y: [...at(28, 19)], Xs: [...at(28, 22)],
  }, [
    ['L1', 'a'], ['L3', 'd'], ['L2', 'Y'],
    ['a', 'b'], ['a', 'd'],
    ['b', 'c'], ['b', 'e'], ['b', 'a'],
    ['c', 'b'], ['c', 'Y'],
    ['d', 'e'], ['d', 'a'], ['d', 'L3'],
    ['e', 'Xs'], ['e', 'b'], ['e', 'd'],
    ['Xs', 'Y'], ['Xs', 'e'],
    ['Y', 'c'], ['Y', 'Xs'], ['Y', 'L2'],
  ]);
  // the skull heaps: a cell beside each plate, as many skulls as its number
  const heap = { a: [17, 15], b: [23, 15], c: [28, 15], d: [17, 23], e: [23, 23] };
  for (const [k, [x, y]] of Object.entries(heap)) {
    const sk = String.fromCharCode(0x2000 + k.charCodeAt(0));
    s.set(X(x), y, sk);
    marks[sk] = skulls(counts[k]);
  }
  const put = (x, y, ch) => s.set(X(x), y, ch);
  put(4, 3, '@'); put(12, 17, 'T');
  put(2, 1, 'b'); put(11, 1, 'b'); put(2, 6, 'q'); put(11, 6, 'q');
  put(4, 10, mirror ? 'g' : 'G');
  put(8, 10, '$'); put(6, 9, 'f'); put(11, 9, 'f'); put(6, 12, 'c'); put(11, 12, 'c');
  put(2, 22, 'M'); put(9, 21, 'u'); put(10, 23, 'v'); put(12, 20, 'w'); put(5, 23, 'k'); put(11, 23, 'k');
  Object.assign(marks, {
    '@': { start: true },
    'T': { tablet: TEXT },
    'b': { prop: 'brazier_low' }, 'q': { prop: 'candelabra' }, 'f': { prop: 'brazier_pillar' }, 'c': { prop: 'candelabra' },
    'k': { prop: 'skull_obelisk' },
    'G': { gate: 'A', dir: 'h' }, 'g': { gate: 'A', dir: 'h' },
    '$': { chest: 'hoard' },
    'M': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
    'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
    'v': { prop: 'urn_a', loot: { type: 'random' } },
    'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random', 'random'] },
  });
  const side = (p) => (mirror ? { east: 'west', west: 'east' }[p] || p : p);
  const px = (sideName, x) => (!mirror ? x : sideName === 'east' || sideName === 'west' ? W - 1 - x : W - 2 - x);
  const ports = [['north', 6, 0], ['west', 0, 5], ['east', 13, 5], ['south', 6, 24], ['west', 0, 19]].map(([sd, x, y]) => [side(sd), px(sd, x), y]);
  return { file, title, slots, ports, map: s.rows(), marks, bare: (x, y) => X(x) >= 11 && X(x) <= 13 && y >= 15 };
}

/** n small skulls lying in one cell, spread so they can be counted. */
function skulls(n) {
  const spots = [[0, 0], [-26, -14], [26, -14], [-26, 16], [26, 16]];
  return spots.slice(0, n).map(([dx, dy]) => ({ prop: 'skull_pile_t', flat: true, block: false, dx, dy, scale: 0.7 }));
}

module.exports = [
  plan({ file: 'k_sprung_grubenring_lc', title: 'Sprung: Die Zählung der Toten (Winkel)', slots: [[0, 0], [0, 1], [1, 1]], mirror: false, counts: { a: 3, b: 5, c: 1, d: 4, e: 2 } }),
  plan({ file: 'k_sprung_grubenring_lc_gs', title: 'Sprung: Die Zählung der Toten (Winkel)', slots: [[1, 0], [0, 1], [1, 1]], mirror: true, counts: { a: 3, b: 5, c: 2, d: 1, e: 4 } }),
];

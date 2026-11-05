// Der Kerkermeister: key A lies on a far pillar of the pit field, behind a strip of spikes that rise in
// turn. Back in the hall two doors want key A, and the key breaks in the lock: behind one door lies key B
// for the vault, behind the other only a Truhenfresser. An inscription stands at each door, and a
// little logic tells which one to trust. The wrong door costs the Schatz.
//
// Room: left door "Hinter dieser Tür liegt kein Schlüssel.", right door "Genau eine dieser beiden
// Inschriften lügt." Either way the left one lies: key B is behind the left door.
// Mirrored: left (after the turn) "Hinter der anderen Tür liegt der Schlüssel.", right "Beide Inschriften
// lügen." The right one cannot be true, so the left one is: key B is behind the right door.
const { sheet, network } = require('../canvas');

function plan({ file, title, slots, mirror }) {
  const W = 31;
  const X = (x) => (mirror ? W - 1 - x : x);
  const s = sheet(W, 25);
  const fill = (x0, y0, x1, y1, ch) => s.fill(Math.min(X(x0), X(x1)), y0, Math.max(X(x0), X(x1)), y1, ch);
  const put = (x, y, ch) => s.set(X(x), y, ch);
  const marks = {};
  fill(1, 1, 12, 6, '.');       // hall of the doors
  fill(6, 7, 8, 18, '.');       // the corridor of the two doors
  fill(1, 8, 4, 12, '.');       // west cell
  fill(10, 8, 12, 12, '.');     // east cell
  fill(1, 19, 13, 23, '.');     // lower hall and ledge
  fill(1, 14, 4, 17, '.');      // the vault (gate B from the corridor)
  fill(14, 15, 29, 23, 'o');    // the pit field
  fill(22, 21, 27, 21, '.');    // the spike strip
  fill(28, 20, 29, 22, '.');    // the key pillar
  fill(11, 15, 13, 18, '.');    // the upper ledge, joined to the lower one
  const at = (x, y) => [X(x), y];
  network(s, marks, {
    L1: at(13, 21), L2: at(13, 16),
    S1: at(18, 21), S2: at(18, 16), S3: at(23, 16), T4: at(28, 16),
    strip: at(22, 21), KP: at(28, 21),
  }, [
    ['L1', 'S1'], ['S1', 'S2'], ['S1', 'strip'],
    ['S2', 'L2'], ['S2', 'S3'],
    ['KP', 'T4'], ['T4', 'L2'],
  ]);
  // spikes in turn along the strip; S3 throws onto its middle
  for (let x = 23; x <= 27; x++) put(x, 21, x % 2 ? 'x' : 'y');
  put(23, 17, 'q');
  marks.q = { pad: 's', n: 4 };
  put(29, 21, 'K');
  put(5, 9, 'G'); put(9, 9, 'H'); put(5, 15, 'J');
  put(6, 12, 'T'); put(8, 12, 'U'); put(7, 3, 'V');
  put(2, 10, 'k'); put(11, 10, 'm'); put(3, 9, 'z'); put(12, 11, 'z');
  put(2, 16, '$'); put(1, 14, 'f'); put(4, 14, 'f');
  put(3, 3, '@'); put(2, 1, 'b'); put(11, 1, 'b'); put(1, 6, 'c'); put(12, 6, 'c');
  put(2, 22, 'M'); put(9, 21, 'u'); put(5, 23, 'w'); put(10, 23, 'p');
  const left = mirror ? 'Hinter der anderen Tür liegt der Schlüssel.' : 'Hinter dieser Tür liegt kein Schlüssel.';
  const right = mirror ? 'Beide Inschriften lügen.' : 'Genau eine dieser beiden Inschriften lügt.';
  Object.assign(marks, {
    '@': { start: true },
    'x': { spikes: 0 }, 'y': { spikes: 1 },
    'K': { key: 'A' },
    'G': { gate: 'W', dir: 'h', lock: 'A' }, 'H': { gate: 'E', dir: 'h', lock: 'A' }, 'J': { gate: 'B', dir: 'h', lock: 'B' },
    'T': { tablet: mirror ? right : left }, 'U': { tablet: mirror ? left : right },
    'V': { tablet: 'Der Kerkermeister hat einen Schlüssel verloren.\nEr liegt jenseits der Stacheln.\nZwei Türen wollen ihn, und er bricht im Schloss:\nHinter einer liegt der zweite Schlüssel, hinter der anderen nur Zähne.\nLies die Inschriften an den Türen.' },
    'k': { chest: 'key', id: 'B' },
    'm': { chest: 'random', mimic: 'yes', mimic_mob: 'truhenfresser' },
    'z': { prop: 'skull_pile' },
    '$': { chest: 'hoard' },
    'f': { prop: 'brazier_pillar' }, 'b': { prop: 'brazier_low' }, 'c': { prop: 'candelabra' },
    'M': { chest: 'random', mimic: 'random', mimic_mob: 'mimik' },
    'u': { prop: 'urn_b', loot: { type: 'random' }, enemies: ['random'] },
    'w': { prop: 'crate_a', loot: { type: 'random' }, enemies: ['random', 'random'] },
    'p': { prop: 'urn_a', loot: { type: 'random' } },
  });
  const side = (p) => (mirror ? { east: 'west', west: 'east' }[p] || p : p);
  const px = (sd, x) => (!mirror ? x : sd === 'east' || sd === 'west' ? W - 1 - x : W - 2 - x);
  const ports = [['north', 6, 0], ['west', 0, 5], ['east', 13, 5], ['south', 6, 24], ['west', 0, 19]].map(([sd, x, y]) => [side(sd), px(sd, x), y]);
  return { file, title, slots, ports, map: s.rows(), marks, bare: (x, y) => X(x) >= 11 && X(x) <= 13 && y >= 15 };
}

module.exports = [
  plan({ file: 'k_sprung_gitter_lc', title: 'Sprung: Der Kerkermeister (Winkel)', slots: [[0, 0], [0, 1], [1, 1]], mirror: false }),
  plan({ file: 'k_sprung_gitter_lc_gs', title: 'Sprung: Der Kerkermeister (Winkel)', slots: [[1, 0], [0, 1], [1, 1]], mirror: true }),
];

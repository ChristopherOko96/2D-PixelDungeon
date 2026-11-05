// A drawing sheet for a room plan: fill rectangles with terrain, set marks by cell, read the rows.
// Cells are [x, y] with 0, 0 top left; rectangles include both corners.
'use strict';

function sheet(width, height, ground = '#') {
  const g = Array.from({ length: height }, () => Array(width).fill(ground));
  const api = {
    width, height,
    fill(x0, y0, x1, y1, ch) { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) g[y][x] = ch; return api; },
    set(x, y, ch) { if (y < 0 || y >= height || x < 0 || x >= width) throw new Error(`Feld ${x},${y} liegt außerhalb`); g[y][x] = ch; return api; },
    put(list) { for (const [x, y, ch] of list) api.set(x, y, ch); return api; },
    get(x, y) { return g[y][x]; },
    rows() { return g.map((r) => r.join('')); },
  };
  return api;
}

let fresh = 0x100;
/** A mark char no plan uses by hand. */
function mark() { return String.fromCharCode(fresh++); }

/**
 * Pillars and the pads between them. `nodes`: {name: [x, y, spec]} (spec defaults to a plain landing);
 * `links`: [[from, to, extra]] where from and to share a row or a column. Each link puts a pad on the
 * cell next to `from` towards `to`, throwing exactly onto `to`. Returns the node chars by name.
 */
function network(s, marks, nodes, links) {
  const chars = {};
  for (const [name, [x, y, spec]] of Object.entries(nodes)) {
    const ch = mark();
    chars[name] = { ch, x, y };
    s.set(x, y, ch);
    marks[ch] = spec || { land: true };
  }
  for (const [from, to, extra] of links) {
    const a = chars[from], b = chars[to];
    if (!a || !b) throw new Error(`Verbindung ${from} > ${to}: unbekannte Insel`);
    let dir;
    if (a.y === b.y) dir = b.x > a.x ? 'e' : 'w';
    else if (a.x === b.x) dir = b.y > a.y ? 's' : 'n';
    else throw new Error(`Verbindung ${from} > ${to} liegt nicht in einer Reihe`);
    const step = { e: [1, 0], w: [-1, 0], s: [0, 1], n: [0, -1] }[dir];
    const px = a.x + step[0], py = a.y + step[1];
    const here = s.get(px, py);
    if (!['o', '.', '~', '#'].includes(here)) throw new Error(`Verbindung ${from} > ${to}: Feld ${px},${py} ist schon belegt (${here})`);
    const ch = mark();
    s.set(px, py, ch);
    marks[ch] = { pad: dir, to: b.ch, ...(extra || {}) };
  }
  return chars;
}

module.exports = { sheet, network, mark };

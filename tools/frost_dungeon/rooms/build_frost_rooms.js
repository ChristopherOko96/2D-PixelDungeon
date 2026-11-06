// Builds the Frostgruft's room files for the Weltbauer: assets/data/world_rooms/frost/f_*.json. Fight
// rooms and small rooms are drawn by hand (maps.js), the key chamber is the Krypta's own (same layout,
// the frost set's pictures), the boss rooms and the big puzzle rooms are built here. Every puzzle is
// drawn from its seed and checked by its solver; the ways found go to tools/frost_dungeon/puzzles/steps.json
// for the replay in the real game (tools/frost_dungeon/puzzles/replay.gd).
// Running this again OVERWRITES those files, redesigned ones too: pass names to rebuild only those.
// Usage (repo root): node tools/frost_dungeon/rooms/build_frost_rooms.js [id ...]
'use strict';
const fs = require('fs');
const path = require('path');
const R = require('./room.js');
const P = require('./puzzle_rooms.js');
const S = require('../puzzles/solvers.js');
const MAPS = require('./maps.js');
const { Room, check, WALL, FLOOR, LIQUID, BRIDGE, PIT, C, MIRROR } = R;

const OUT = process.env.FROST_ROOMS_OUT || path.join(R.ROOT, 'assets', 'data', 'world_rooms', 'frost');
const STEPS = process.env.FROST_STEPS_OUT || path.join(R.ROOT, 'tools', 'frost_dungeon', 'puzzles', 'steps.json');

// ---------- the drawn rooms ----------
function drawn(m) {
  const b = new Room(`f_${m.id}`, m.title, m.role, m.shape);
  b.draw(m);
  b.findPorts();
  b.clearPorts();
  if (m.walltheme) { b.wallDress(R.WALLS[m.walltheme]); b.scatter(m.walltheme); }
  // an ice lake: the whole room is ice where everyone slides hard, only its snowfields stand firm
  // fewer enemies than its open ground would bring: a fight on ice is hard enough (m.auto_mobs)
  if (m.auto_mobs) b.extra.auto_mobs = m.auto_mobs;
  if (m.ice_lake) { b.extra.ice_lake = true; b.extra.info = 'Ein Eissee: alle rutschen, du und die Gegner. Nur auf den Schneefeldern steht man fest.'; }
  else b.snow(m.snow || 0.04);
  if (!b.objects.some(o => o.kind === 'start')) b.start();
  return b;
}
function drawnAll() {
  const out = [];
  for (const m of MAPS.ROOMS) {
    const b = drawn(m);
    out.push(b);
    if (MIRROR[m.shape]) { const q = b.mirrored(b.id + '_gs', MIRROR[m.shape]); q.fixedPorts = false; q.findPorts(); out.push(q); }
  }
  return out;
}

// ---------- the key chamber: the Krypta's, in frost ----------
function keyRoom() {
  const k = JSON.parse(fs.readFileSync(path.join(R.ROOT, 'assets', 'data', 'world_rooms', 'krypta', 'k_schluesselkammer.json'), 'utf8'));
  k.id = 'f_schluesselkammer';
  k.world = 'frost';
  return { id: k.id, role: 'key', shape: 'e', json: () => k };
}

// ---------- the boss rooms ----------
function bosses() {
  const out = [];
  const add = (id, title, shape, make) => {
    const b = new Room(`f_boss_${id}`, title, 'boss', shape);
    for (const [c, r] of b.slots) {
      const x0 = c * R.PX, y0 = r * R.PY;
      b.rect(x0 + 1, y0 + 1, R.SW - 2, R.SH - 2, FLOOR);
      if (b.has(c + 1, r)) b.rect(x0 + R.SW - 1, y0 + 1, R.GX + 2, R.SH - 2, FLOOR);
      if (b.has(c, r + 1)) b.rect(x0 + 1, y0 + R.SH - 1, R.SW - 2, R.GY + 2, FLOOR);
      if (b.has(c + 1, r) && b.has(c, r + 1) && b.has(c + 1, r + 1)) b.rect(x0 + R.SW - 1, y0 + R.SH - 1, R.GX + 2, R.GY + 2, FLOOR);
    }
    const mx = b.w / 2, my = b.h / 2;
    make(b, mx, my);
    b.decal('rune_big', mx, my);
    b.findPorts(); b.clearPorts();
    b.wallDress(R.WALLS.boss);
    b.snow(0.04);
    b.start([mx, my + 3]);
    out.push(b);
  };
  const ring = (b, mx, my, n, dx, dy) => { for (const [i, j] of [[-dx, -dy], [dx, -dy], [-dx, dy], [dx, dy]]) if (b.at(Math.floor(mx + i), Math.floor(my + j)) === FLOOR) b.prop(n, mx + i, my + j + 0.8, [50, 28]); };
  add('gletscherthron', 'Hort: Thron des Gletscherherzens (groß)', 'q', (b, mx, my) => {
    for (let k = 0; k < 8; k++) { const a = k / 8 * Math.PI * 2 + Math.PI / 8; b.prop(k % 2 ? 'rune_pillar_c' : 'spire_big', mx + Math.cos(a) * 9.5, my + Math.sin(a) * 6.5, [54, 28]); }
    for (const [x, y] of [[3, 3], [b.w - 3, 3], [3, b.h - 3], [b.w - 3, b.h - 3]]) b.prop('brazier_blue', x, y, [56, 30]);
    b.rect(Math.floor(mx) - 2, 2, 5, 2, LIQUID);
    b.decal('rug_blue', mx, my + 6, { w: 150, h: 300 });
  });
  add('eissee', 'Hort: Gefrorener See (groß)', 'q', (b, mx, my) => {
    b.rect(Math.floor(mx) - 7, Math.floor(my) - 4, 15, 9, LIQUID);
    b.rect(Math.floor(mx) - 2, Math.floor(my) - 1, 5, 3, FLOOR);
    for (const [x, y] of [[4, 4], [b.w - 4, 4], [4, b.h - 4], [b.w - 4, b.h - 4]]) b.prop('glacier_a', x, y, [80, 32]);
    ring(b, mx, my, 'torch_pillar_blue', 10, 7);
  });
  add('kristallhalle', 'Hort: Kristallhalle (groß)', 'q', (b, mx, my) => {
    for (const [x, y] of [[mx - 8, my - 6], [mx + 6, my - 6], [mx - 8, my + 4], [mx + 6, my + 4]]) b.rect(Math.floor(x), Math.floor(y), 2, 2, WALL);
    ring(b, mx, my, 'brazier_blue', 5, 4);
    b.prop('statue_angel', 3, 4, [50, 26]); b.prop('statue_angel', b.w - 3, 4, [50, 26], { flip: true });
  });
  add('kluftarena', 'Hort: Kluftarena (groß)', 'q', (b, mx, my) => {
    b.rect(2, Math.floor(my) - 3, 3, 6, PIT); b.rect(b.w - 5, Math.floor(my) - 3, 3, 6, PIT);
    ring(b, mx, my, 'spire_big', 6, 5); b.prop('glacier_b', 6, 3, [70, 30]); b.prop('glacier_b', b.w - 6, 3, [70, 30], { flip: true });
  });
  add('halle_b', 'Hort: Eishalle (breit)', 'b2', (b, mx, my) => { ring(b, mx, my, 'brazier_blue', 6, 3); b.prop('glacier_a', 4, 2.9, [80, 32]); b.prop('glacier_b', b.w - 4, 2.9, [70, 30]); });
  add('see_b', 'Hort: Eisbecken (breit)', 'b2', (b, mx, my) => { b.rect(2, 3, 3, 6, LIQUID); b.rect(b.w - 5, 3, 3, 6, LIQUID); ring(b, mx, my, 'rune_pillar_c', 6, 3); });
  add('halle_h', 'Hort: Eishalle (hoch)', 'h2', (b, mx, my) => { ring(b, mx, my, 'brazier_blue', 3.5, 8); b.prop('statue_angel', 3, 11.9, [50, 26]); b.prop('statue_angel', 11, 11.9, [50, 26], { flip: true }); });
  add('see_h', 'Hort: Eisbecken (hoch)', 'h2', (b, mx, my) => { b.rect(2, 4, 3, 5, LIQUID); b.rect(b.w - 5, 4, 3, 5, LIQUID); ring(b, mx, my, 'rune_pillar_c', 3.5, 8); });
  add('kammer', 'Hort: Frostkammer (klein)', 'e', b => { b.prop('brazier_blue', 3.6, 3.4, [50, 28]); b.prop('brazier_blue', 10.4, 3.4, [50, 28]); });
  add('kammer_saeulen', 'Hort: Säulenkammer (klein)', 'e', b => { for (const [i, j] of [[3, 3.2], [11, 3.2], [3, 8.8], [11, 8.8]]) b.prop('rune_pillar_d', i, j, [40, 24]); });
  return out;
}

// ---------- the puzzle rooms ----------
const TEXT = {
  blocks: 'Eis gleitet, bis es stößt.\nWas in die Spalte fällt, wird zur Brücke.\nDie Rune setzt alles zurück.',
  balls: 'Nur wer wächst, füllt die Tiefe.\nTiefschnee macht den Ball größer, aber jeder Schnee nur einmal.\nDie Rune setzt alles zurück.',
  ember: 'Die Schalen sind kalt.\nTrag die Glut vom Herd, sie stirbt nach wenigen Schritten,\nim Nebel noch schneller. Brennende Schalen geben neue.',
  prisms: 'Lenke das Polarlicht auf das Siegel.\nJedes Prisma kennt zwei Wege.\nNicht jedes Prisma braucht das Licht.',
  bells: 'Die Statue singt ein Lied.\nJeder Kristall der Reihe singt einen Ton, probier sie aus.\nDann tritt auf die Platte und schlag sie in seiner Folge an.',
  ice: 'Jede Platte trägt nur, was sie tragen kann.\nDie dunklen tragen einen Schritt, die hellen zwei.\nBreche jede, ehe du das Ziel betrittst. Wer fällt, beginnt von vorn.',
  heart: 'Hol das Frostherz von der Insel\nund bring es zum Altar.\nDas Eis trägt dich nicht zweimal denselben Weg.',
  mirror: 'Dein Spiegelbild geht, wie du gehst,\nnur links und rechts vertauscht.\nStellt euch beide auf eure Platten.\nDie Rune ruft das Bild zurück.',
};
const steps = {};
// the whole polar sky (the user's own pick in the Weltbauer for f_prismen_ld): night, rime, aurora,
// diamond dust and ice fog together, for the rooms of light and sound
const FULL_SKY = ['diamond', 'fog', 'rime', 'night', 'aurora'];

/** A cell next to piece cell `t` the hero can stand on, from where `t` is the nearest of `others`. */
function useCell(b, t, others, open) {
  const me = c => [c[0] * C + 48, c[1] * C + 48 - 10];
  const at = c => [c[0] * C + 48, c[1] * C + 48 + 10];
  const dist = (a, q) => Math.hypot(a[0] - q[0], a[1] - q[1]);
  let best = null;
  for (const [dx, dy] of [[0, 1], [-1, 0], [1, 0], [0, -1]]) {
    const c = [t[0] + dx, t[1] + dy];
    if (!open.has(S.key(c[0], c[1]))) continue;
    const d = dist(me(c), at(t));
    if (d > 135) continue;
    const near = others.filter(o => !(o[0] === t[0] && o[1] === t[1])).map(o => dist(me(c), at(o)));
    if (near.some(n => n < d + 12)) continue;
    if (!best || d < best.d) best = { c, d };
  }
  if (!best) throw new Error(`${b.id}: no place to use the piece at ${t}`);
  return best.c;
}

/** Plain cells the hero can stand on in room b (puzzle pieces, walls and props kept out). */
function openCells(b, extraSolid = []) {
  const solid = R.solidAt(b);
  for (const c of extraSolid) solid.add(S.key(c[0], c[1]));
  const out = new Set();
  for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) if ([FLOOR, BRIDGE, LIQUID].includes(b.at(x, y)) && !solid.has(S.key(x, y))) out.add(S.key(x, y));
  return out;
}

/** The entrance of an angled room's puzzle: rune and inscription in the hall beside the door. */
function entrance(f, text) {
  const { b } = f;
  const [dx, dy] = f.door;
  b.piece('frost_rune', dx - 1, dy);
  b.tablet(dx - 1, dy - 2, text);
}

/** A nook in the zone's corner behind gate A, the Schatz inside: cells kept from the puzzle. */
function cornerNook(f, tier) {
  const { b, zone } = f;
  const top = zone.y === 1;
  const ny = top ? zone.y : zone.y + zone.h - 2;
  const wy = top ? zone.y + 2 : zone.y + zone.h - 3;
  for (let x = zone.x + zone.w - 4; x < zone.x + zone.w; x++) b.set(x, wy, WALL);
  for (let y = Math.min(ny, wy); y <= Math.max(ny + 1, wy); y++) b.set(zone.x + zone.w - 4, y, WALL);
  P.nook(b, { x: zone.x + zone.w - 3, y: ny, w: 3, h: 2 }, [zone.x + zone.w - 3, wy, 'v'], tier, [zone.x + zone.w - 2, ny]);
  const blocked = [];
  for (let y = Math.min(ny, wy); y <= Math.max(ny + 1, wy); y++) for (let x = zone.x + zone.w - 4; x < zone.x + zone.w; x++) blocked.push([x, y]);
  // the gate's way out stays free
  const out = [zone.x + zone.w - 3, top ? wy + 1 : wy - 1];
  const out2 = [zone.x + zone.w - 2, top ? wy + 1 : wy - 1];
  blocked.push(out, out2);
  return { blocked, chest: [zone.x + zone.w - 2, ny], inside: [zone.x + zone.w - 3, ny] };
}

function finishPuzzle(f, kind, list, extra = {}) {
  const { b } = f;
  const zone = P.cellsOf(f.zone);
  b.checkOpts = { skip: o => zone.has(S.key(Math.floor(o.x / C), Math.floor((o.y - 10) / C))) || (o.kind === 'chest' && o.loot && o.loot.type === 'hoard') };
  P.dressHall(b, zone, f.theme);
  b.extra.info = extra.info || '';
  if (extra.weather) b.extra.weather = extra.weather;
  if (extra.weather_extra) b.extra.weather_extra = extra.weather_extra;
  check(b);
  b.steps = list;
  return b;
}

function anglesOf(make) {
  const out = [];
  for (const shape of ['la', 'lc']) {
    const b = make(shape);
    if (!b) continue;
    out.push(b);
    const q = b.mirrored(b.id.replace(/_(la|lc)$/, '_' + MIRROR[shape]), MIRROR[shape]);
    out.push(q);
  }
  return out;
}

function prismRoom(shape) {
  const f = P.angled('prismen', 'Rätsel: Polarlichtprismen (Winkel)', shape, 'Frosträtsel');
  f.theme = 'hall';
  entrance(f, TEXT.prisms);
  const n = cornerNook(f, 3);
  f.blocked = n.blocked;
  const res = P.prisms(f, f.b.id, { prisms: 11, turns: 6, rocks: 0.1 });
  const open = openCells(f.b);
  const all = f.b.objects.filter(o => o.kind === 'prism').map(o => [Math.floor(o.x / C), Math.floor(o.y / C)]);
  const list = res.turn.map(c => ({ use: useCell(f.b, c, all, open), what: 'Prisma drehen' }));
  list.push({ chest: n.inside });
  return finishPuzzle(f, 'prisms', list, { info: 'Kein Kampf. Lenke das Polarlicht mit den Prismen auf das Siegel.', weather_extra: FULL_SKY });
}

function emberRoom(shape) {
  const f = P.angled('glut', 'Rätsel: Glut tragen (Winkel)', shape, 'Frosträtsel');
  f.theme = 'quiet';
  entrance(f, TEXT.ember);
  const n = cornerNook(f, 2);
  f.blocked = n.blocked;
  const res = P.ember(f, f.b.id, { bowls: 4, walls: 5, fog: 10, steps: 14, fogCost: 2, depth: 3, direct: 1 });
  return finishPuzzle(f, 'ember', emberSteps(res, n.inside), { info: 'Kein Kampf. Trag die Glut vom Herd zu den kalten Schalen.', weather: 'snow' });
}

function emberSteps(res, inside) {
  const list = [];
  const lit = [res.source];
  for (const leg of res.legs) {
    list.push({ use: leg.path[0], what: 'Glut nehmen' });
    list.push({ walk: leg.path });
    list.push({ use: leg.path[leg.path.length - 1], what: 'Glut in die Schale legen' });
  }
  list.push({ chest: inside });
  return list;
}

function bellRoom(shape) {
  const f = P.angled('glocken', 'Rätsel: Kristallglocken (Winkel)', shape, 'Frosträtsel');
  f.theme = 'hall';
  entrance(f, TEXT.bells);
  const n = cornerNook(f, 2);
  f.blocked = n.blocked;
  const [ex, ey] = f.entry;
  // the statue at the head of one row of crystals, the plate below; the hero strikes from the row beneath
  f.statue = [ex + 1, ey - 2];
  f.plate = [ex + 1, ey + 2];
  f.row = [ex + 3, ey - 2];
  f.blocked.push(f.statue, f.plate);
  const res = P.bells(f, f.b.id, { crystals: 5, length: 5 });
  const open = openCells(f.b);
  const pieces = [...res.crystals.map(c => c.at), f.statue];
  const list = [{ use: useCell(f.b, f.statue, pieces, open), what: 'Der Statue lauschen' }, { at: f.plate }];
  for (const note of res.melody) {
    const c = res.crystals.find(q => q.note === note).at;
    const u = useCell(f.b, c, pieces, open);
    if (u[0] === f.plate[0] && u[1] === f.plate[1]) throw new Error(f.b.id + ': a crystal is struck from the plate');
    list.push({ use: u, what: 'Kristall' });
  }
  list.push({ chest: n.inside });
  return finishPuzzle(f, 'bells', list, { info: 'Kein Kampf. Hör der Statue zu und schlag ihre Melodie nach.', weather_extra: FULL_SKY });
}

function blockRoom(shape) {
  if (shape !== 'la') return null;
  const f = P.angled('eisbloecke', 'Rätsel: Eisblöcke (Winkel)', shape, 'Frosträtsel');
  f.theme = 'ice';
  entrance(f, TEXT.blocks);
  const z = f.zone;
  const far = z.x + z.w - 1;
  f.play = { x: z.x, y: z.y, w: z.w - 5, h: z.h };
  f.band = []; f.beyond = [];
  for (let y = z.y; y < z.y + z.h; y++) { f.band.push([far - 4, y], [far - 3, y]); for (const x of [far - 2, far - 1, far]) f.beyond.push([x, y]); }
  f.goal = [far - 1, z.y + 4];
  f.chest = [far - 1, z.y + 1];
  const res = P.blocks(f, f.b.id, { blocks: 4, min: 8, hard: 11 });
  const list = res.pushes.map(([x, y, d]) => ({ push: [x - S.DIRS[d][0], y - S.DIRS[d][1]], dir: d }));
  list.push({ chest: [f.chest[0], f.chest[1] + 1] });
  return finishPuzzle(f, 'blocks', list, { info: 'Kein Kampf. Schieb die Eisblöcke in die Spalte.', weather_extra: ['fog'] });
}

function heartRoom(shape) {
  if (shape !== 'lc') return null;
  const f = P.angled('frostherz', 'Rätsel: Brüchiges Eis (Winkel)', shape, 'Frosträtsel');
  f.theme = 'ice';
  const z = f.zone;
  const [ex, ey] = f.entry;
  // the start column and the heart's island
  f.field = { x: z.x + 1, y: z.y, w: z.w - 4, h: z.h };
  f.from = [ex, ey - 1];
  f.back = [ex, ey + 1];
  f.island = [z.x + z.w - 3, ey];
  for (let y = z.y; y < z.y + z.h; y++) f.b.set(z.x, y, FLOOR);
  for (let y = ey - 1; y <= ey + 1; y++) for (let x = z.x + z.w - 3; x < z.x + z.w; x++) f.b.set(x, y, FLOOR);
  for (let y = z.y; y < z.y + z.h; y++) for (let x = z.x + z.w - 3; x < z.x + z.w; x++) if (Math.abs(y - ey) > 1) f.b.set(x, y, WALL);
  const res = P.frostHeart(f, f.b.id, { min: 34, crossings: 2, decoys: 0.32 });
  f.b.piece('frost_core', z.x + z.w - 2, ey);
  // the altar, rune and inscription in the hall; the Schatz in a nook of the hall behind gate A
  const [dx, dy] = f.door;
  f.b.piece('frost_rune', dx - 1, dy);
  f.b.tablet(dx - 4, dy - 2, TEXT.heart);
  f.b.piece('core_altar', dx - 2, dy - 2, { group: 'A' });
  for (let x = 9; x <= 12; x++) f.b.set(x, 20, WALL);
  for (let y = 21; y <= 23; y++) f.b.set(9, y, WALL);
  P.nook(f.b, { x: 10, y: 21, w: 3, h: 3 }, [10, 20, 'v'], 3, [11, 22]);
  const list = [{ at: [dx - 1, dy] }, { walk: [[dx - 1, dy], [dx, dy], [ex, ey], ...res.out] }, { use: f.island, what: 'Frostherz nehmen' }, { walk: [...res.back, [ex, ey], [dx, dy], [dx - 1, dy]] }];
  const open = openCells(f.b);
  list.push({ use: useCell(f.b, [dx - 2, dy - 2], [[dx - 2, dy - 2]], open), what: 'Frostherz einsetzen' });
  list.push({ chest: [10, 22] });
  return finishPuzzle(f, 'heart', list, { info: 'Kein Kampf. Hol das Frostherz über das brüchige Eis.', weather: 'snow', weather_extra: ['rime'] });
}

function longRooms() {
  const out = [];
  // the mirror ghost
  {
    const f = P.long('spiegelgeist', 'Rätsel: Spiegelgeist (lang)', 'Frosträtsel');
    const { b } = f;
    // small enough that hero, ghost and both fields stay on one screen (the game zooms out here:
    // world_frost_puzzles.json ghost.zoom), 9 x 6 cells each side by side
    b.rect(13, 4, 9, 6, FLOOR); b.rect(26, 4, 9, 6, FLOOR);
    b.set(13, 3, FLOOR);
    b.piece('frost_rune', 13, 4);
    b.tablet(11, 1, TEXT.mirror);
    b.piece('mirror_lever', 16, 1, { group: 'A' });
    P.nook(b, { x: 23, y: 5, w: 2, h: 3 }, [22, 6, 'h'], 3, [23, 6]);
    f.hero = { x: 13, y: 4, w: 9, h: 6 };
    f.ghost = { x: 26, y: 4, w: 9, h: 6 };
    f.start = [13, 4];
    f.keep = [[21, 6], [21, 7]];
    const res = P.mirror(f, b.id, { walls: 0.22, min: 18, far: 6 });
    f.zone = { x: 13, y: 4, w: 22, h: 6 };
    const open = openCells(b);
    const lever = [16, 1];
    const list = [{ at: [13, 4] }, { use: [13, 4], what: 'Rune' }, { show: useCell(b, lever, [lever], open) }, { at: [13, 4] }, { use: [13, 4], what: 'Rune' }, { walk: res.path }, { chest: [24, 6] }];
    out.push(finishPuzzle(f, 'mirror', list, { info: 'Kein Kampf. Führe dein Spiegelbild auf seine Platte.', weather_extra: ['fog', 'diamond'] }));
  }
  // the ice walk
  {
    const f = P.long('eisgang', 'Rätsel: Eisgang (lang)', 'Frosträtsel');
    const { b } = f;
    f.field = { x: 14, y: 4, w: 10, h: 6 };
    b.rect(14, 4, 10, 6, FLOOR);
    b.set(13, 3, FLOOR); b.set(13, 4, FLOOR);
    b.set(24, 8, FLOOR);
    b.piece('frost_rune', 13, 4);
    b.tablet(11, 1, TEXT.ice);
    P.nook(b, { x: 26, y: 7, w: 3, h: 3 }, [25, 8, 'h'], 3, [27, 8]);
    f.from = [13, 4];
    f.goal = [24, 8];
    const res = P.iceWalk(f, b.id, { wild: 1.5, cover: 0.8, twice: 4, most: 150000 });
    f.zone = { x: 13, y: 4, w: 16, h: 6 };
    out.push(finishPuzzle(f, 'ice', [{ at: [13, 4] }, { walk: res.path }, { chest: [26, 8] }], { info: 'Kein Kampf. Betritt jede Eisplatte so oft, wie sie trägt.', weather: 'snow' }));
  }
  // the frost heart over a long lake of thin ice
  {
    const f = P.long('eissee', 'Rätsel: Brüchiger See (lang)', 'Frosträtsel');
    const { b } = f;
    b.rect(7, 4, 1, 6, FLOOR);
    b.rect(39, 5, 3, 4, FLOOR);
    b.set(7, 3, FLOOR);
    f.field = { x: 8, y: 4, w: 31, h: 6 };
    f.from = [7, 5]; f.back = [7, 8]; f.island = [39, 6];
    const res = P.frostHeart(f, b.id, { min: 70, crossings: 3, decoys: 0.3 });
    b.piece('frost_core', 41, 6);
    b.piece('frost_rune', 7, 4);
    b.tablet(9, 1, TEXT.heart);
    b.piece('core_altar', 7, 9, { group: 'A' });
    P.nook(b, { x: 2, y: 5, w: 4, h: 4 }, [6, 6, 'h'], 3, [3, 6]);
    f.zone = { x: 2, y: 4, w: 45, h: 6 };
    const open = openCells(b);
    const list = [{ at: [7, 4] }, { walk: [[7, 4], ...res.out] }, { use: [40, 6], what: 'Frostherz nehmen' }, { walk: [[39, 6], ...res.back.slice(1)] }, { use: useCell(b, [7, 9], [[7, 9]], open), what: 'Frostherz einsetzen' }, { chest: [4, 6] }];
    out.push(finishPuzzle(f, 'heart', list, { info: 'Kein Kampf. Hol das Frostherz über den brüchigen See.', weather: 'blizzard' }));
  }
  return out;
}

function towerRooms() {
  const out = [];
  // the snowballs
  {
    const f = P.tower('schneeball', 'Rätsel: Schneeballspalte (Turm)', 'Frosträtsel');
    const { b } = f;
    f.play = { x: 4, y: 14, w: 9, h: 14 };
    b.rect(4, 14, 9, 14, FLOOR);
    b.set(3, 20, FLOOR);
    f.pits = [[8, 28], [8, 29]];
    f.beyond = [[8, 30]];
    b.set(8, 28, FLOOR); b.set(8, 29, FLOOR);
    b.rect(5, 30, 7, 4, FLOOR);
    b.hoard(9, 32, 3);
    f.entry = [4, 20];
    f.goal = [8, 30];
    b.piece('frost_rune', 2, 20);
    b.tablet(1, 23, TEXT.balls);
    const res = P.balls(f, b.id, { balls: 2, snow: 5, min: 16 });
    f.zone = { x: 4, y: 14, w: 9, h: 20 };
    const list = res.pushes.map(([x, y, d]) => ({ push: [x - S.DIRS[d][0], y - S.DIRS[d][1]], dir: d }));
    list.push({ chest: [8, 32] });
    out.push(finishPuzzle(f, 'balls', list, { info: 'Kein Kampf. Roll große Schneebälle in die Spalte.', weather: 'snow' }));
  }
  // the ember, a whole tower of it
  {
    const f = P.tower('glutturm', 'Rätsel: Glutturm (Turm)', 'Frosträtsel');
    const { b } = f;
    b.rect(4, 5, 9, 33, FLOOR);
    b.set(3, 20, FLOOR);
    f.zone = { x: 4, y: 5, w: 9, h: 33 };
    f.entry = [4, 20];
    b.piece('frost_rune', 2, 20);
    b.tablet(1, 23, TEXT.ember);
    // the nook at the top, behind gate A
    b.rect(5, 1, 7, 3, FLOOR);
    b.gate(7, 4, 'v', 'A', { style: 'portcullis' });
    b.hoard(9, 2, 3);
    f.blocked = [[7, 5], [8, 5]];
    const res = P.ember(f, b.id, { bowls: 5, walls: 9, fog: 14, steps: 14, fogCost: 2, depth: 3, direct: 1 });
    out.push(finishPuzzle(f, 'ember', emberSteps(res, [8, 2]), { info: 'Kein Kampf. Trag die Glut durch den Turm.', weather_extra: ['night'] }));
  }
  // the ice blocks, falling south
  {
    const f = P.tower('eisrutsche', 'Rätsel: Eisrutsche (Turm)', 'Frosträtsel');
    const { b } = f;
    // easier than it was (the user could not solve the old one): a short field, three blocks, few
    // rocks; still two crevasse rows, so two blocks must go down the same column
    b.rect(4, 17, 9, 21, FLOOR);
    b.set(3, 20, FLOOR);
    f.entry = [4, 20];
    f.play = { x: 4, y: 17, w: 9, h: 13 };
    f.band = []; f.beyond = [];
    for (let x = 4; x <= 12; x++) { f.band.push([x, 30], [x, 31]); for (const y of [32, 33, 34, 35, 36, 37]) f.beyond.push([x, y]); }
    f.goal = [8, 33];
    f.chest = [8, 36];
    b.piece('frost_rune', 2, 20);
    b.tablet(1, 23, TEXT.blocks);
    const res = P.blocks(f, b.id, { blocks: 3, min: 4, most: 6, hard: 6, rocks: [0.07, 0.04] });
    f.zone = { x: 4, y: 17, w: 9, h: 21 };
    const list = res.pushes.map(([x, y, d]) => ({ push: [x - S.DIRS[d][0], y - S.DIRS[d][1]], dir: d }));
    list.push({ chest: [8, 35] });
    out.push(finishPuzzle(f, 'blocks', list, { info: 'Kein Kampf. Schieb die Eisblöcke in die Spalte.', weather: 'hail' }));
  }
  return out;
}

function puzzles() {
  const out = [];
  for (const make of [() => anglesOf(prismRoom), () => anglesOf(emberRoom), () => anglesOf(bellRoom), () => anglesOf(blockRoom), () => anglesOf(heartRoom), longRooms, towerRooms]) {
    const t0 = Date.now();
    try { const got = make(); out.push(...got); console.error('built', got.map(b => b.id).join(' '), (Date.now() - t0) + ' ms'); } catch (e) { errors.push(e.message); console.error('failed', e.message, (Date.now() - t0) + ' ms'); }
  }
  return out;
}

// ---------- write ----------
const only = process.argv.slice(2);
const errors = [];
let rooms = [];
for (const part of [drawnAll, bosses, puzzles]) {
  try { rooms.push(...part()); } catch (e) { errors.push(e.message); }
}
rooms.push(keyRoom());
fs.mkdirSync(OUT, { recursive: true });
let wrote = 0;
for (const b of rooms) {
  if (b.json === Room.prototype.json) { try { if (b.role !== 'jump') check(b); } catch (e) { errors.push(e.message); continue; } }
  if (b.steps) steps[b.id] = { steps: b.steps, w: b.w, h: b.h };
  if (only.length && !only.includes(b.id)) continue;
  fs.writeFileSync(path.join(OUT, b.id + '.json'), JSON.stringify(b.json(), null, '\t') + '\n');
  wrote++;
}
let old = {};
try { old = JSON.parse(fs.readFileSync(STEPS, 'utf8')); } catch (e) { old = {}; }
fs.writeFileSync(STEPS, JSON.stringify(Object.assign(old, steps), null, 1) + '\n');
const by = {};
for (const b of rooms) { const k = b.role + ' ' + b.shape; by[k] = (by[k] || 0) + 1; }
console.log(`rooms ${rooms.length}, wrote ${wrote}`);
console.log(Object.entries(by).map(([k, v]) => k + ':' + v).join('  '));
if (errors.length) { console.log('PROBLEMS\n' + errors.join('\n')); process.exitCode = 1; }

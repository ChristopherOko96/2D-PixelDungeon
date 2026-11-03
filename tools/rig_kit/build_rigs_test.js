// Unit test of the rig build (build_rigs.js, rig_check.js) on a fake checkout in the OS temp
// folder: steps in order, hand merges and clashes, declared reads and writes, drift, and every
// kind of data problem the check names. Touches nothing in the repo.
// Usage: node tools/rig_kit/build_rigs_test.js   prints "RIG_KIT_TEST checked=N failures=M"
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const Build = require('./build_rigs.js');
const RigCheck = require('./rig_check.js');

let checked = 0;
const failures = [];
function check(condition, description) {
  checked++;
  if (!condition) { failures.push(description); console.log('RIG_KIT_TEST_FAIL: ' + description); }
}
function throws(fn, pattern, description) {
  try { fn(); } catch (err) { check(pattern.test(err.message), `${description} (${err.message})`); return; }
  check(false, `${description} (no error)`);
}

const ART = { dot: { palette: { A: '#ffffff' }, rows: ['AA', 'AA'] } };
const part = (id, parent = null, extra = {}) => Object.assign({ id, rects: [[0, 0, 1, 1]], pivot: [1, 1], parent, z: 1, hp: 1, label: id }, extra);
const rig = (parts, items = []) => ({ img: 'dot', family: '', ground: [1, 1], width: 2, parts, items });

// A fake checkout: one manifest, two generators, a hand source, a monster table.
function fakeRoot(sources, generators) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'rig_kit_test_'));
  const put = (rel, text) => { const file = path.join(root, rel); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, text); };
  put('assets/data/rig_manifest.json', JSON.stringify({
    sources,
    check: { legacy_actions: ['beam'], references: [{ file: 'res://assets/data/monsters.json', map: 'defs', rig: 'rig', attacks: 'stats.attacks', world: 'W' }] },
  }));
  put('assets/data/monsters.json', JSON.stringify({ defs: { m1: { rig: 'a1', stats: { attacks: [{ id: 'hieb' }] } } } }));
  put('assets/data/actions.json', JSON.stringify({ categories: ['attack'], kind_category: { swing: 'attack' } }));
  put('hand/h.json', JSON.stringify({ _note: 'hand', rigs: { h1: rig([part('body')]) } }));
  for (const [rel, body] of Object.entries(generators)) put(rel, body);
  return root;
}
const GEN_A = `module.exports.rigKit = (ctx) => ({
  data: { _note: 'gen a', pixel_art: ${JSON.stringify(ART)}, scales: { a1: 2 }, rigs: { a1: ${JSON.stringify(rig([part('torso', null, { rects: [[0, 1, 1, 1]] }), part('head', 'torso', { rects: [[0, 0, 1, 0]], disables: 'attack' })], [Object.assign(part('weapon', 'torso', { disables: ['hieb'] }), { img: 'dot', grip: [0, 0], hand: [1, 1] })]))} } },
  files: [{ file: require('path').join(ctx.root, 'out', 'x.png'), png: Buffer.from('png-bytes') }],
});`;
const GEN_B = `module.exports.rigKit = (ctx) => ({ data: { rigs: { b1: ctx.read('res://assets/data/a.json').rigs.a1 } } });`;
const SOURCES = [
  { path: 'res://assets/data/a.json', format: 'crypt', slot: 'path', required: true, steps: [{ generator: 'gen/a.js', writes: ['res://out/'] }, { hand: 'hand/h.json' }] },
  { path: 'res://assets/data/b.json', format: 'crypt', slot: 'story_path', steps: [{ generator: 'gen/b.js', reads: ['res://assets/data/a.json'] }] },
  { path: 'res://assets/data/actions.json', format: 'actions', slot: 'actions_path', steps: [] },
];
const roots = [];
const make = (sources = SOURCES, generators = { 'gen/a.js': GEN_A, 'gen/b.js': GEN_B }) => { const r = fakeRoot(sources, generators); roots.push(r); return r; };

// --- steps in order, write, no drift, drift after a hand edit, CRLF ---
{
  const root = make();
  const result = Build.build(root);
  const a = result.entries[0], b = result.entries[1];
  check(Object.keys(a.data.rigs).join(',') === 'a1,h1', 'the hand source adds its rig after the generator\'s');
  check(a.data._note === 'gen a', 'a hand source merged into a file keeps its own _note');
  check(JSON.stringify(b.data.rigs.b1) === JSON.stringify(a.data.rigs.a1), 'a step reads a file built before it');
  check(!result.entries[2].built && result.entries[2].data.categories[0] === 'attack', 'a file without steps is read from disk');
  check(a.text === JSON.stringify(a.data, null, 1) + '\n', 'a built file is JSON with one-space indent and a final newline');
  const report = RigCheck.validate(root, result.manifest, result.entries);
  check(report.problems.length === 0, 'clean fake data passes the check: ' + report.problems.join('; '));
  check(Build.compare(root, result.entries).drift.length === 3, 'before the first build both files and the PNG are missing');
  const written = Build.write(root, result.entries);
  check(written.length === 3 && fs.existsSync(path.join(root, 'out', 'x.png')), 'the build writes both files and the PNG');
  check(Build.write(root, Build.build(root).entries).length === 0, 'a second build writes nothing');
  check(Build.compare(root, Build.build(root).entries).drift.length === 0, 'a fresh build has no drift');
  const file = path.join(root, 'assets', 'data', 'a.json');
  fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(/\n/g, '\r\n'));
  const crlf = Build.compare(root, Build.build(root).entries);
  check(crlf.drift.length === 0 && crlf.notes.some((n) => n.includes('CRLF')), 'CRLF on disk with the same content is a note, not drift');
  check(Build.write(root, Build.build(root).entries).length === 0, 'a CRLF file with the same content is not rewritten');
  const edited = JSON.parse(fs.readFileSync(file, 'utf8'));
  edited.rigs.a1.width = 9;
  fs.writeFileSync(file, JSON.stringify(edited, null, 1) + '\n');
  const drift = Build.compare(root, Build.build(root).entries).drift;
  check(drift.length === 1 && drift[0].includes('/rigs/a1/width'), 'a hand edit of a built file is drift at its path: ' + drift.join('; '));
  fs.writeFileSync(path.join(root, 'out', 'x.png'), 'other');
  check(Build.compare(root, Build.build(root).entries).drift.some((d) => d.includes('x.png')), 'a changed PNG is drift');
}

// --- the build refuses clashes, undeclared reads and writes elsewhere ---
{
  const clash = { 'gen/a.js': GEN_A, 'gen/b.js': GEN_B, 'gen/c.js': "module.exports.rigKit = (ctx) => { ctx.data.rigs.a1.width = 5; return { data: ctx.data }; };" };
  const withC = JSON.parse(JSON.stringify(SOURCES));
  withC[0].steps.push({ generator: 'gen/c.js' });
  throws(() => Build.build(make(withC, clash)), /changed rig "a1"/, 'a generator that changes an earlier step\'s rig is a clash');
  const twice = JSON.parse(JSON.stringify(SOURCES));
  twice[0].steps.push({ hand: 'hand/h.json' });
  throws(() => Build.build(make(twice)), /rig "h1" is already built/, 'a hand rig built twice is an error');
  const noReads = JSON.parse(JSON.stringify(SOURCES));
  delete noReads[1].steps[0].reads;
  throws(() => Build.build(make(noReads)), /without declaring it in "reads"/, 'a read the manifest does not declare is an error');
  const noWrites = JSON.parse(JSON.stringify(SOURCES));
  delete noWrites[0].steps[0].writes;
  throws(() => Build.build(make(noWrites)), /outside its "writes" folders/, 'a PNG outside the declared folders is an error');
  throws(() => Build.mergeHand({ images: { k: 'a' } }, { images: { k: 'b' } }, 'h'), /images\.k differs/, 'an image key with another value is an error');
  check(Build.mergeHand({ images: { k: 'a' } }, { images: { k: 'a' } }, 'h').images.k === 'a', 'the same image key twice is fine');
}

// --- every kind of data problem is named ---
{
  const root = make();
  const result = Build.build(root);
  const problems = (mutate) => {
    const entries = JSON.parse(JSON.stringify(result.entries.map((e) => ({ source: e.source, data: e.data }))));
    mutate(entries[0].data, entries);
    return RigCheck.validate(root, result.manifest, entries).problems.join(' | ');
  };
  check(/parent "nope" is no part/.test(problems((d) => { d.rigs.a1.parts[1].parent = 'nope'; })), 'an unknown parent is named');
  check(/id "torso" twice/.test(problems((d) => { d.rigs.a1.parts[1].id = 'torso'; })), 'a part id twice is named');
  check(/parent chain loops/.test(problems((d) => { d.rigs.a1.parts[0].parent = 'head'; })), 'a parent loop is named');
  check(/disables "fluch" is no attack of its wearers/.test(problems((d) => { d.rigs.a1.parts[1].disables = 'fluch'; })), 'a disables name no wearer attacks with is named');
  check(problems((d) => { d.rigs.a1.parts[1].disables = 'beam'; }) === '', 'a legacy rig action is known');
  check(/weakens "satz"/.test(problems((d) => { d.rigs.a1.parts[1].weakens = { satz: { speed: 0.5 } }; })), 'a weakens key no wearer attacks with is named');
  check(/img "ghost" is no image/.test(problems((d) => { d.rigs.a1.img = 'ghost'; })), 'an unknown image key is named');
  check(/scales.zz: no rig/.test(problems((d) => { d.scales.zz = 2; })), 'a scale of no rig is named');
  check(/item scale 9/.test(problems((d) => { d.rigs.a1.items[0].scale = 9; })), 'an item scale RigLibrary would clamp is named');
  check(/hold no opaque pixel/.test(problems((d) => { d.rigs.a1.parts[1].rects = [[5, 5, 6, 6]]; })), 'a part without pixels is named');
  check(/point "mouth" names no part/.test(problems((d) => { d.rigs.a1.points = { mouth: { part: 'jaw', at: [0, 0] } }; })), 'a point on no part is named');
  check(/its rig "a1" does not exist/.test(problems((d) => { delete d.rigs.a1; delete d.scales.a1; })), 'a monster whose rig is gone is named');
  check(/RigLibrary skips this one/.test(problems((d, entries) => { entries.push({ source: { path: 'res://assets/data/l.json', format: 'layered' }, data: { rigs: { a1: { parts: [{ id: 'body', img: 'res://assets/data/a.json', hp: 1 }] } } } }); })), 'a layered rig named like a crypt rig is named');
}

for (const root of roots) fs.rmSync(root, { recursive: true, force: true });
console.log(`RIG_KIT_TEST checked=${checked} failures=${failures.length}`);
process.exitCode = failures.length ? 1 : 0;

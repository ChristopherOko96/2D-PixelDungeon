// The one rig build: every rig file the game loads, built in the order of
// assets/data/rig_manifest.json from its generators and hand sources.
//   node tools/rig_kit/build_rigs.js                   builds every file in memory, validates it and
//        writes the files (and the generators' PNGs) that differ; nothing is written on a failure
//   node tools/rig_kit/build_rigs.js --check           writes nothing: validates (tools/rig_kit/rig_check.js)
//        and names every file on disk that differs from its build (drift), exit code 1 on either
//   node tools/rig_kit/build_rigs.js --with-variants   rigs.json with the review page's variant candidates
//        (production/art-proof/0x72-style VARIANTS; only after the user approved them)
// A step is a generator (a node module whose rigKit(ctx) returns { data, files, notes }) or a
// hand source (tools/rig_kit/hand_rigs/*.json). README (German): tools/rig_kit/README.md.
'use strict';
const fs = require('fs');
const path = require('path');
const RigCheck = require('./rig_check.js');

const ROOT = path.resolve(__dirname, '..', '..');
const MANIFEST = 'res://assets/data/rig_manifest.json';
// The sections of a crypt file a hand source adds to (anything else it may only set once).
const SECTIONS = ['images', 'pixel_art', 'scales', 'rigs'];

const copy = (value) => JSON.parse(JSON.stringify(value));

/** The absolute path of a res:// path or a path relative to the repo root. */
function abs(root, file) {
  return path.join(root, String(file).replace(/^res:\/\//, ''));
}

/** The repo-relative spelling of an absolute path, with forward slashes. */
function rel(root, file) {
  return path.relative(root, file).split(path.sep).join('/');
}

/** True when `file` lies inside folder `dir` (both absolute). */
function inside(dir, file) {
  const r = path.relative(dir, file);
  return r !== '' && !r.startsWith('..') && !path.isAbsolute(r);
}

/** The parsed manifest at `file` (res:// or repo-relative). */
function readManifest(root, file = MANIFEST) {
  const text = fs.readFileSync(abs(root, file), 'utf8');
  try {
    return JSON.parse(text);
  } catch (err) {
    throw new Error(`${file}: ${err.message}`);
  }
}

/**
 * Adds the hand source `hand` to `data` (null: the source becomes the file). Its images,
 * pixel_art, scales and rigs are added; a rig an earlier step built, or an image, art or scale
 * key with another value, is an error; other keys may be set once. The source's own notes
 * (keys starting with "_") stay in the source when it is merged into an earlier step's file.
 */
function mergeHand(data, hand, label) {
  if (!hand || typeof hand !== 'object' || Array.isArray(hand)) throw new Error(`${label}: not a JSON object`);
  if (!data) return copy(hand);
  for (const [key, value] of Object.entries(hand)) {
    if (key.startsWith('_')) continue;
    if (!SECTIONS.includes(key)) {
      if (key in data) throw new Error(`${label}: "${key}" is already built by an earlier step`);
      data[key] = copy(value);
      continue;
    }
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${label}: "${key}" is not an object`);
    data[key] = data[key] || {};
    for (const [name, entry] of Object.entries(value)) {
      if (key === 'rigs' && name in data.rigs) throw new Error(`${label}: rig "${name}" is already built by an earlier step`);
      if (name in data[key] && JSON.stringify(data[key][name]) !== JSON.stringify(entry)) throw new Error(`${label}: ${key}.${name} differs from an earlier step's`);
      data[key][name] = copy(entry);
    }
  }
  return data;
}

/**
 * Runs the generator step `step` on `data` (the file as built so far, or null). The generator may
 * add rigs but never drop or change a rig an earlier step built (a name clash).
 */
function runGenerator(root, step, data, ctx) {
  const file = abs(root, step.generator);
  if (!fs.existsSync(file)) throw new Error(`${step.generator}: no such generator`);
  const mod = require(file);
  if (typeof mod.rigKit !== 'function') throw new Error(`${step.generator}: exports no rigKit(ctx)`);
  const before = {};
  if (data && data.rigs) for (const [name, rig] of Object.entries(data.rigs)) before[name] = JSON.stringify(rig);
  const result = mod.rigKit({ root, data, read: ctx.read(step), options: ctx.options, step });
  if (!result || !result.data || typeof result.data !== 'object') throw new Error(`${step.generator}: rigKit returned no data`);
  for (const [name, json] of Object.entries(before)) {
    const now = result.data.rigs ? result.data.rigs[name] : undefined;
    if (now === undefined) throw new Error(`${step.generator} dropped rig "${name}" of an earlier step`);
    if (JSON.stringify(now) !== json) throw new Error(`${step.generator} changed rig "${name}" of an earlier step (a name clash?)`);
  }
  return { data: result.data, files: result.files || [], notes: result.notes || [] };
}

/**
 * Builds every file of the manifest in memory, in its order. Returns { manifest, entries }:
 * one entry per source { source, built, text, data, files, notes }; a source without steps is
 * read from disk (built false). `options.withVariants` passes the review page's variants on.
 */
function build(root = ROOT, options = {}) {
  const manifest = readManifest(root, options.manifest || MANIFEST);
  const entries = [];
  const done = {};
  const ctx = {
    options,
    // a step's view of the files built before it: only the ones its "reads" declare
    read: (step) => (file) => {
      if (!(step.reads || []).includes(file)) throw new Error(`${step.generator}: reads ${file} without declaring it in "reads"`);
      if (!(file in done)) throw new Error(`${step.generator}: ${file} is not built before it (manifest order)`);
      return copy(done[file]);
    },
  };
  for (const source of manifest.sources || []) {
    const steps = source.steps || [];
    const entry = { source, built: steps.length > 0, text: null, data: null, files: [], notes: [] };
    if (!entry.built) {
      const file = abs(root, source.path);
      entry.text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null;
      entry.data = entry.text === null ? null : JSON.parse(entry.text);
    } else {
      let data = null;
      for (const step of steps) {
        if (step.hand) {
          const text = fs.readFileSync(abs(root, step.hand), 'utf8');
          if (step.copy) {
            if (steps.length !== 1) throw new Error(`${source.path}: a copied hand source (${step.hand}) must be the file's only step`);
            entry.text = text;
          }
          data = mergeHand(data, JSON.parse(text), step.hand);
        } else if (step.generator) {
          const result = runGenerator(root, step, data, ctx);
          for (const f of result.files) {
            if (!(step.writes || []).some((dir) => inside(abs(root, dir), f.file))) throw new Error(`${step.generator}: writes ${rel(root, f.file)} outside its "writes" folders`);
          }
          data = result.data;
          entry.files.push(...result.files);
          entry.notes.push(...result.notes);
        } else throw new Error(`${source.path}: a step names neither a generator nor a hand source`);
      }
      entry.data = data;
      if (entry.text === null) entry.text = JSON.stringify(data, null, 1) + '\n';
    }
    if (entry.data) done[source.path] = entry.data;
    entries.push(entry);
  }
  return { manifest, entries };
}

/** The first line where texts `a` and `b` differ (1-based), or 0. */
function firstDiffLine(a, b) {
  const la = a.split('\n'), lb = b.split('\n');
  for (let i = 0; i < Math.max(la.length, lb.length); i++) if (la[i] !== lb[i]) return i + 1;
  return 0;
}

/** Deep comparison that ignores key order: the paths (at most `limit`) where `a` and `b` differ. */
function differences(a, b, at = '', found = [], limit = 8) {
  if (found.length >= limit) return found;
  const kind = (v) => (v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v);
  if (kind(a) !== kind(b)) { found.push(at || '/'); return found; }
  if (kind(a) !== 'object' && kind(a) !== 'array') { if (a !== b) found.push(at || '/'); return found; }
  for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) {
    if (!(key in a) || !(key in b)) { found.push(`${at}/${key} (${key in a ? 'only in the build' : 'only on disk'})`); continue; }
    differences(a[key], b[key], `${at}/${key}`, found, limit);
    if (found.length >= limit) break;
  }
  return found;
}

/** Text with CRLF turned into LF (git's core.autocrlf may check a JSON file out either way). */
const lf = (text) => text.replace(/\r\n/g, '\n');

/** The PNG decoder the exporters use; null when the file cannot be decoded. */
function pixels(root, buffer) {
  try {
    const H = require(path.join(root, 'tools', 'hell_dungeon', 'concepts', 'hybrid.js'));
    const image = H.decodePng(buffer);
    return { w: image.w, h: image.h, rgba: Buffer.from(image.rgba) };
  } catch (err) {
    return null;
  }
}

/**
 * Compares every built file and PNG with the disk. Returns { drift: [line], notes: [line], same }:
 * a JSON file differs when its text (CRLF read as LF) does; a PNG when its pixels do (bytes
 * alone: a note).
 */
function compare(root, entries) {
  const drift = [], notes = [];
  let same = 0;
  for (const entry of entries) {
    if (!entry.built) continue;
    const file = abs(root, entry.source.path), name = rel(root, file);
    const hint = entry.source.steps.map((s) => s.generator || s.hand).join(' + ');
    const disk = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null;
    if (disk === null) drift.push(`${name}: missing (built by ${hint})`);
    else if (lf(disk) === lf(entry.text)) {
      same++;
      if (disk !== entry.text) notes.push(`${name}: CRLF on disk, LF in the build (same content)`);
    } else {
      let what = `first different line ${firstDiffLine(lf(disk), lf(entry.text))}`;
      try {
        const paths = differences(entry.data, JSON.parse(disk));
        what = paths.length ? `${what}; differs at ${paths.join(', ')}` : `${what}; same data, other key order or formatting`;
      } catch (err) {
        what = `${what}; the file on disk is no valid JSON`;
      }
      drift.push(`${name}: differs from its build (${hint}): ${what}. Edit the generator or hand source, not this file`);
    }
    for (const f of entry.files) {
      const png = rel(root, f.file);
      if (!fs.existsSync(f.file)) { drift.push(`${png}: missing (written by the build)`); continue; }
      const bytes = fs.readFileSync(f.file);
      if (Buffer.compare(bytes, f.png) === 0) { same++; continue; }
      const a = pixels(root, bytes), b = pixels(root, f.png);
      if (a && b && a.w === b.w && a.h === b.h && Buffer.compare(a.rgba, b.rgba) === 0) { same++; notes.push(`${png}: other PNG bytes, same pixels`); continue; }
      drift.push(`${png}: its pixels differ from the build`);
    }
  }
  return { drift, notes, same };
}

/** Writes every built file and PNG that differs from the disk (a CRLF file stays CRLF). */
function write(root, entries) {
  const written = [];
  for (const entry of entries) {
    if (!entry.built) continue;
    const file = abs(root, entry.source.path);
    const disk = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null;
    if (disk === null || lf(disk) !== lf(entry.text)) {
      const text = disk !== null && disk.includes('\r\n') ? lf(entry.text).replace(/\n/g, '\r\n') : entry.text;
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, text);
      written.push(rel(root, file));
    }
    for (const f of entry.files) {
      if (fs.existsSync(f.file) && Buffer.compare(fs.readFileSync(f.file), f.png) === 0) continue;
      fs.mkdirSync(path.dirname(f.file), { recursive: true });
      fs.writeFileSync(f.file, f.png);
      written.push(rel(root, f.file));
    }
  }
  return written;
}

/**
 * Runs the build with command line `argv` (--check, --with-variants) and prints its report;
 * returns the exit code (0 ok, 1 a failure, drift or an error).
 */
function main(argv = process.argv.slice(2), root = ROOT) {
  const checkOnly = argv.includes('--check');
  let result;
  try {
    result = build(root, { withVariants: argv.includes('--with-variants') });
  } catch (err) {
    console.log(`RIG_BUILD error: ${err.message}`);
    return 1;
  }
  const report = RigCheck.validate(root, result.manifest, result.entries);
  for (const line of report.lines) console.log(line);
  for (const entry of result.entries) for (const note of entry.notes) console.log(`note: ${rel(root, abs(root, entry.source.path))}: ${note}`);
  for (const note of report.notes) console.log(`note: ${note}`);
  for (const problem of report.problems) console.log(`PROBLEM: ${problem}`);
  if (checkOnly) {
    const cmp = compare(root, result.entries);
    for (const note of cmp.notes) console.log(`note: ${note}`);
    for (const line of cmp.drift) console.log(`DRIFT: ${line}`);
    console.log(`RIG_BUILD check: ${cmp.same} files equal their build, ${cmp.drift.length} differ`);
    console.log(`RIG_BUILD checked=${report.checked} failures=${report.problems.length} drift=${cmp.drift.length}`);
    return report.problems.length || cmp.drift.length ? 1 : 0;
  }
  if (report.problems.length) {
    console.log(`RIG_BUILD checked=${report.checked} failures=${report.problems.length}: nothing written`);
    return 1;
  }
  const written = write(root, result.entries);
  for (const file of written) console.log(`wrote ${file}`);
  console.log(`RIG_BUILD checked=${report.checked} failures=0, ${written.length} files written, the rest unchanged`);
  return 0;
}

module.exports = { build, compare, write, main, mergeHand, readManifest, abs, rel, MANIFEST };

if (require.main === module) process.exitCode = main();

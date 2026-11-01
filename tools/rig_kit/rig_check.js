// The data checks of the rig build (node tools/rig_kit/build_rigs.js --check): the rig files as
// RigLibrary (src/rig/rig_library.gd) loads them, in the order of assets/data/rig_manifest.json.
//   - every part and item id is unique in its rig, every parent, alsoDetach, group member and
//     point names a part of it, no parent chain loops;
//   - every image key a rig or item names was loaded by then (images / pixel_art of this or an
//     earlier crypt file), every image path, layered part file and flipbook frame exists, every
//     rect-cut part owns at least one opaque pixel of its frame;
//   - every scale is a positive number of a rig of the same file, item scales stay in 0.1 .. 4;
//   - an item's "held" block (the hero's weapon) names a known style, a hand and art shares;
//   - every disables and weakens name is known: a rig action (rig_actions.json categories, the
//     manifest's legacy_actions) or an attack id of the monsters that wear the rig;
//   - every rig a monster, companion or hero table names exists (check.references);
//   - a layered rig never shares its name with a crypt rig (RigLibrary would skip it).
// Prints nothing itself; build_rigs.js prints the report.
'use strict';
const fs = require('fs');
const path = require('path');

// RigLibrary clamps an item's scale to this range (rig_library.gd _build_rig).
const ITEM_SCALE = [0.1, 4];
// The styles src/hero/hero_look.gd moves held art by (an item's "held" block, src/rig_kit/rig_held.gd).
const HELD_STYLES = ['sword', 'bow', 'staff'];
// The flipbook figures a crypt file may carry beside "rigs" (rig_library.gd _load_crypt).
const EXTRAS = ['void', 'bomber', 'mimic'];
// RigLibrary counts a pixel as part of a figure from this alpha on (0.5 of 255).
const OPAQUE = 128;

const abs = (root, file) => path.join(root, String(file).replace(/^res:\/\//, ''));
const short = (file) => String(file).replace(/^res:\/\/assets\/data\//, '').replace(/^res:\/\//, '');

/** The value at dot path `at` inside `value` (undefined when a step is missing). */
function dig(value, at) {
  let node = value;
  for (const key of String(at || '').split('.').filter(Boolean)) node = node && typeof node === 'object' ? node[key] : undefined;
  return node;
}

/**
 * An item's "held" block (src/rig_kit/rig_held.gd): a style hero_look knows, the hand as an
 * [x, y] pair of figure px, grip and tip as [x, y] shares of the held art, a positive scale.
 * `ok(condition, message)` counts and collects like the other checks.
 */
function heldBlock(at, held, ok) {
  const pair = (v) => Array.isArray(v) && v.length === 2 && v.every((n) => typeof n === 'number' && isFinite(n));
  if (!ok(held !== null && typeof held === 'object' && !Array.isArray(held), `${at}: not an object`)) return;
  ok(HELD_STYLES.includes(String(held.style)), `${at}: style "${held.style}" is none of ${HELD_STYLES.join(', ')}`);
  ok(pair(held.hand), `${at}: hand is no [x, y] pair of figure px`);
  for (const key of ['grip', 'tip']) {
    if (held[key] !== undefined) ok(pair(held[key]) && held[key].every((n) => n >= 0 && n <= 1), `${at}: ${key} is no [x, y] share of the art (0 .. 1)`);
  }
  if (held.scale !== undefined) ok(typeof held.scale === 'number' && held.scale > 0, `${at}: scale ${held.scale} is no positive number`);
}

/** disables as a list: the crypt's single string, an array of ids, or nothing. */
function names(value) {
  if (Array.isArray(value)) return value.filter((v) => v !== null && String(v) !== '').map(String);
  return value === undefined || value === null || String(value) === '' ? [] : [String(value)];
}

/**
 * The wearers of rigs named by the manifest's check.references: [{ world, id, rig, attacks,
 * optional, from }]; `problems` collects tables that cannot be read.
 */
function wearers(root, manifest, problems) {
  const result = [];
  for (const ref of (manifest.check || {}).references || []) {
    if (ref.code) {
      const file = abs(root, ref.code);
      const text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
      const match = text.match(new RegExp(`const\\s+${ref.const}\\s*:?=\\s*(\\{[^}\\n]*\\})`));
      let table = null;
      try { table = match ? JSON.parse(match[1]) : null; } catch (err) { table = null; }
      if (!table) { problems.push(`${short(ref.code)}: no one-line const ${ref.const} Dictionary to read`); continue; }
      for (const [id, rig] of Object.entries(table)) result.push({ world: ref.world, id, rig: String(rig), attacks: [], optional: !!ref.optional, from: `${short(ref.code)} ${ref.const}` });
      continue;
    }
    const file = abs(root, ref.file);
    let data = null;
    try { data = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (err) { data = null; }
    const map = data ? dig(data, ref.map) : undefined;
    if (!map || typeof map !== 'object') { problems.push(`${short(ref.file)}: no table "${ref.map}" to read`); continue; }
    for (const [key, entry] of Object.entries(map)) {
      if (key.startsWith('_')) continue;
      const rig = ref.rig === '@key' ? key : ref.rig === '@value' ? entry : entry && typeof entry === 'object' ? entry[ref.rig] : undefined;
      if (typeof rig !== 'string' || rig === '') continue; // no rig: the wearer draws its sprite
      const list = ref.attacks ? dig(entry, ref.attacks) : [];
      const attacks = Array.isArray(list) ? list.map((a) => String(a && a.id)).filter((a) => a !== 'undefined') : [];
      result.push({ world: ref.world, id: key, rig, attacks, optional: !!ref.optional, from: `${short(ref.file)} ${ref.map}` });
    }
  }
  return result;
}

/** A decoded PNG ({ w, h, rgba }) or null; cached per path. */
function decoder(root) {
  const cache = {};
  let H = null;
  return (file) => {
    if (file in cache) return cache[file];
    let image = null;
    try {
      H = H || require(path.join(root, 'tools', 'hell_dungeon', 'concepts', 'hybrid.js'));
      const raw = H.decodePng(fs.readFileSync(file));
      image = { w: raw.w, h: raw.h, rgba: raw.rgba };
    } catch (err) {
      image = null;
    }
    cache[file] = image;
    return image;
  };
}

/** A pixel_art frame ({ palette, rows }) as { w, h, alpha(x, y) }. */
function artImage(art) {
  const rows = (art && art.rows) || [];
  const palette = (art && art.palette) || {};
  return { w: rows.length ? String(rows[0]).length : 0, h: rows.length, alpha: (x, y) => (palette[String(rows[y])[x]] !== undefined ? 255 : 0) };
}

/**
 * Checks the rig files of `entries` (build_rigs.js build(): { source, data }) in load order.
 * Returns { checked, problems: [line], notes: [line], lines: [line] }.
 */
function validate(root, manifest, entries) {
  const problems = [], notes = [], lines = [];
  let checked = 0;
  const ok = (condition, message) => { checked++; if (!condition) problems.push(message); return !!condition; };
  const exists = (res) => fs.existsSync(abs(root, res));
  const png = decoder(root);

  const actionsEntry = entries.find((e) => e.source.format === 'actions');
  const actions = (actionsEntry && actionsEntry.data) || {};
  const categories = new Set(Array.isArray(actions.categories) ? actions.categories.map(String) : []);
  const legacy = new Set(((manifest.check || {}).legacy_actions || []).map(String));
  const users = wearers(root, manifest, problems);
  const byRig = {};
  for (const u of users) (byRig[u.rig] = byRig[u.rig] || []).push(u);
  const anyAttack = new Set(users.flatMap((u) => u.attacks));
  // parts known to own no pixel ({rig: [part ids]}), noted instead of failed
  const emptyParts = Object.fromEntries(Object.entries((manifest.check || {}).known_empty_parts || {}).filter(([k]) => !k.startsWith('_')));

  // a disables or weakens name of part `what` of rig `rig`
  const known = (where, rig, kind, list) => {
    const worn = (byRig[rig] || []).filter((u) => u.attacks.length);
    const theirs = new Set(worn.flatMap((u) => u.attacks));
    for (const name of list) {
      if (kind === 'disables' && (categories.has(name) || legacy.has(name))) { ok(true, ''); continue; }
      if (worn.length) ok(theirs.has(name), `${where}: ${kind} "${name}" is no attack of its wearers (${worn.map((u) => `${u.world} ${u.id}: ${u.attacks.join(',')}`).join('; ')})${kind === 'disables' ? ` and no rig action (${[...categories, ...legacy].join(', ')})` : ''}`);
      else ok(anyAttack.has(name), `${where}: ${kind} "${name}" is no rig action (${[...categories, ...legacy].join(', ')}) and no attack id of any story monster`);
    }
  };
  // ids, parents, alsoDetach, points of one rig; returns the part ids
  const structure = (where, parts, items, points) => {
    const ids = new Set();
    for (const p of parts.concat(items)) {
      const id = p && p.id !== undefined && p.id !== null ? String(p.id) : '';
      ok(id !== '', `${where}: a part or item without an id`);
      ok(!ids.has(id), `${where}: id "${id}" twice`);
      ids.add(id);
    }
    const partIds = new Set(parts.map((p) => String(p.id)));
    const parentOf = {};
    for (const p of parts.concat(items)) {
      const parent = p.parent === undefined || p.parent === null ? '' : String(p.parent);
      ok(parent === '' || partIds.has(parent), `${where}.${p.id}: parent "${parent}" is no part of the rig`);
      if (parent !== '') parentOf[String(p.id)] = parent;
      for (const other of p.alsoDetach || []) ok(ids.has(String(other)), `${where}.${p.id}: alsoDetach "${other}" is no part of the rig`);
    }
    for (const id of partIds) {
      let at = id, steps = 0;
      while (parentOf[at] !== undefined && steps <= partIds.size) { at = parentOf[at]; steps++; }
      ok(steps <= partIds.size, `${where}.${id}: its parent chain loops`);
    }
    for (const [name, point] of Object.entries(points || {})) ok(point && ids.has(String(point.part)), `${where}: point "${name}" names no part (${point && point.part})`);
    return ids;
  };

  const images = {}, art = {};
  const crypt = {}, layered = {};
  for (const entry of entries) {
    const { source, data } = entry;
    const file = short(source.path);
    if (!ok(data && typeof data === 'object', `${file}: missing or no JSON object`)) continue;
    if (source.format === 'actions') {
      const kinds = actions.kind_category || {};
      for (const [kind, value] of Object.entries(kinds)) ok(value === '' || categories.has(String(value)), `${file}: kind_category.${kind} "${value}" is no category`);
      for (const [id, table] of Object.entries(actions.needs || {})) for (const [attack, value] of Object.entries(table || {})) for (const n of names(value)) ok(categories.has(n), `${file}: needs.${id}.${attack} "${n}" is no category`);
      lines.push(`${file}: ${categories.size} categories, ${Object.keys(kinds).length} attack kinds`);
      continue;
    }
    const rigs = data.rigs && typeof data.rigs === 'object' ? data.rigs : {};
    if (source.format === 'crypt') {
      Object.assign(images, data.images || {});
      Object.assign(art, data.pixel_art || {});
      for (const [key, res] of Object.entries(data.images || {})) ok(exists(res), `${file} images.${key}: ${res} does not exist`);
      for (const [name, value] of Object.entries(data.scales || {})) {
        ok(name in rigs || (EXTRAS.includes(name) && name in data), `${file} scales.${name}: no rig of this file has that name`);
        ok(typeof value === 'number' && value > 0, `${file} scales.${name}: ${value} is no positive number`);
      }
      const frame = (key) => {
        if (key in art) return artImage(art[key]);
        if (!(key in images)) return null;
        const image = png(abs(root, images[key]));
        return image ? { w: image.w, h: image.h, alpha: (x, y) => image.rgba[(y * image.w + x) * 4 + 3] } : null;
      };
      for (const [name, rig] of Object.entries(rigs)) {
        const where = `${file} ${name}`;
        if (crypt[name]) notes.push(`${where}: replaces the rig of ${crypt[name]} (a later crypt file wins)`);
        crypt[name] = file;
        const parts = Array.isArray(rig.parts) ? rig.parts : [];
        const items = Array.isArray(rig.items) ? rig.items : [];
        ok(parts.length > 0, `${where}: no parts`);
        ok(String(rig.img) in images || String(rig.img) in art, `${where}: img "${rig.img}" is no image or pixel_art key loaded by then`);
        structure(where, parts, items, rig.points);
        for (const item of items) {
          ok(String(item.img) in images || String(item.img) in art, `${where}.${item.id}: img "${item.img}" is no image or pixel_art key loaded by then`);
          if (item.scale !== undefined) ok(typeof item.scale === 'number' && item.scale >= ITEM_SCALE[0] && item.scale <= ITEM_SCALE[1], `${where}.${item.id}: item scale ${item.scale} is outside ${ITEM_SCALE.join(' .. ')} (RigLibrary clamps it)`);
          if (item.held !== undefined) heldBlock(`${where}.${item.id}.held`, item.held, ok);
        }
        for (const p of parts.concat(items)) {
          known(`${where}.${p.id}`, name, 'disables', names(p.disables));
          known(`${where}.${p.id}`, name, 'weakens', Object.keys(p.weakens || {}));
        }
        // every part owns pixels: an opaque pixel belongs to the first part whose rect holds it
        const image = frame(String(rig.img));
        if (!image) { notes.push(`${where}: frame "${rig.img}" not decoded, pixel check skipped`); continue; }
        const owned = parts.map(() => 0);
        for (let y = 0; y < image.h; y++) for (let x = 0; x < image.w; x++) {
          if (image.alpha(x, y) < OPAQUE) continue;
          const index = parts.findIndex((p) => (p.rects || []).some((r) => x >= r[0] && x <= r[2] && y >= r[1] && y <= r[3]));
          if (index >= 0) owned[index]++;
        }
        const allowed = (emptyParts[name] || []).map(String);
        parts.forEach((p, i) => {
          const listed = allowed.includes(String(p.id));
          if (listed && owned[i] === 0) notes.push(`${where}.${p.id}: owns no pixel (check.known_empty_parts)`);
          else if (listed) notes.push(`${where}.${p.id}: owns ${owned[i]} pixels now, take it out of check.known_empty_parts`);
          else ok(owned[i] > 0, `${where}.${p.id}: its rects hold no opaque pixel of "${rig.img}" (${image.w}x${image.h}); an earlier part's rects may cover it`);
        });
      }
      for (const extra of EXTRAS) {
        if (!(extra in data)) continue;
        const def = data[extra] || {};
        crypt[extra] = file;
        for (const res of def.frames || []) ok(exists(res), `${file} ${extra}: frame ${res} does not exist`);
        for (const [id, spec] of Object.entries(def.parts || {})) known(`${file} ${extra}.${id}`, extra, 'disables', names(spec && spec.disables));
      }
      lines.push(`${file}: ${Object.keys(rigs).length} rigs${EXTRAS.some((x) => x in data) ? ' + ' + EXTRAS.filter((x) => x in data).join(', ') : ''}`);
    } else if (source.format === 'layered') {
      for (const [name, rig] of Object.entries(rigs)) {
        const where = `${file} ${name}`;
        ok(!crypt[name], `${where}: ${crypt[name]} has a crypt rig of that name, RigLibrary skips this one`);
        layered[name] = file;
        const parts = Array.isArray(rig.parts) ? rig.parts : [];
        ok(parts.length > 0, `${where}: no parts`);
        ok(rig.scale === undefined || (typeof rig.scale === 'number' && rig.scale > 0), `${where}: scale ${rig.scale} is no positive number`);
        structure(where, parts, [], rig.points);
        const hp = Object.fromEntries(parts.map((p) => [String(p.id), Number(p.hp) || 0]));
        for (const p of parts) {
          const files = Array.isArray(p.frames) && p.frames.length ? p.frames : [p.img];
          for (const res of files) ok(res && exists(res), `${where}.${p.id}: part file ${res} does not exist`);
          known(`${where}.${p.id}`, name, 'disables', names(p.disables));
          known(`${where}.${p.id}`, name, 'weakens', Object.keys(p.weakens || {}));
        }
        for (const [group, spec] of Object.entries(rig.groups || {})) {
          for (const member of (spec && spec.parts) || []) ok((hp[String(member)] || 0) > 0, `${where}: group "${group}" member "${member}" is no part with hp (it could never be lost)`);
          known(`${where} group ${group}`, name, 'disables', names(spec && spec.disables));
        }
      }
      lines.push(`${file}: ${Object.keys(rigs).length} layered rigs`);
    } else ok(false, `${file}: unknown format "${source.format}"`);
  }

  // every rig a table names exists
  const worlds = {};
  for (const u of users) {
    const there = crypt[u.rig] || layered[u.rig];
    worlds[u.world] = worlds[u.world] || { named: 0, missing: 0 };
    worlds[u.world].named++;
    if (u.optional && !there) { worlds[u.world].missing++; notes.push(`${u.world} ${u.id} (${u.from}): no rig "${u.rig}", it draws its sprite`); continue; }
    ok(there, `${u.world} ${u.id} (${u.from}): its rig "${u.rig}" does not exist`);
  }
  for (const [world, count] of Object.entries(worlds)) lines.push(`wearers ${world}: ${count.named} name a rig${count.missing ? `, ${count.missing} without one (sprite)` : ''}`);
  for (const nb of manifest.not_built || []) notes.push(`not built: ${nb.generator}: ${nb.why}`);
  return { checked, problems, notes, lines };
}

module.exports = { validate, wearers, names, dig };

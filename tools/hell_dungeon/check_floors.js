// Builds every floor in node and reports layout facts: rooms, quickest path, puzzles.
const core = require(process.argv[2]);
const man = require(process.argv[3]);
const SIZES = {}; for (const [k, v] of Object.entries(man)) SIZES[k] = [v.w, v.h];
for (let n = 1; n <= 10; n++) {
  const t = Date.now(); const W = core.buildFloor(n, SIZES); const cr = core.criticalRooms(W);
  const types = {}; for (const r of W.rooms) types[r.gtype || r.type] = (types[r.gtype || r.type] || 0) + 1;
  const ents = {}; for (const e of W.ents) ents[e.type] = (ents[e.type] || 0) + 1;
  const kinds = {}; for (const d of W.doors) kinds[d.kind + (d.key || '') + (d.group ? ':' + d.group : '')] = (kinds[d.kind + (d.key || '') + (d.group ? ':' + d.group : '')] || 0) + 1;
  console.log(`E${n} ${W.title}: ${W.rooms.length} rooms, quickest ${cr.need ? cr.need.length : 'UNREACHABLE'}/${cr.total}, ${Date.now() - t}ms`);
  console.log('   types', JSON.stringify(types)); console.log('   doors', JSON.stringify(kinds)); console.log('   ents', JSON.stringify(ents), 'props', W.props.length);
}

const fs=require('fs'),crypto=require('crypto');
const dest='production/qa/evidence/ranger-fields';
const hash=path=>({path,bytes:fs.statSync(path).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')});
const suites=['ranger_fields_test','ranger_vfx_test','archer_rework_test','forest_traps_rework_test','talent_combat_test','element_reactions_test','marksman_rig_test','talent_defense_test','ranger_story_fields_test'];
const checks=suites.map(n=>{
 const path=`Logs/ranger-final-${n}.log`,s=fs.readFileSync(path,'utf8'),m=[...s.matchAll(/checked=(\d+) failures=(\d+)/g)].pop();
 if(!m||+m[2]||s.includes('SCRIPT ERROR'))throw Error(`Unpassed ${path}`);
 return {...hash(path),checks:+m[1],failures:+m[2]};
});
const networkPath='Logs/archer-rework/20261103-173713-6be32ecf/summary.json';
const network=JSON.parse(fs.readFileSync(networkPath,'utf8').replace(/^\uFEFF/,''));
if(!network.passed||network.results.length!==2||network.results.some(r=>!r.passed||!r.wide_wall))throw Error('Network incomplete');
const capture='Logs/ranger-capture.log',cap=fs.readFileSync(capture,'utf8');
if(!cap.includes('RANGER_CAPTURE images=8 native=1280x720')||cap.includes('SCRIPT ERROR'))throw Error('Capture incomplete');
const parse='Logs/ranger-check.log',p=fs.readFileSync(parse,'utf8');
if(!p.includes('[OK] Import and parse check completed')||p.includes('SCRIPT ERROR'))throw Error('Project check incomplete');
const images=fs.readdirSync(dest).filter(n=>/^\d\d-.*\.png$/.test(n)).sort().map(n=>`${dest}/${n}`);
if(images.length!==8)throw Error('Expected eight retained views');
for(const path of images){const b=fs.readFileSync(path);if(b.readUInt32BE(16)!==1280||b.readUInt32BE(20)!==720)throw Error(`Wrong size ${path}`);}
const sources=['assets/data/talents.json','assets/data/debug_forest_lab.json','assets/data/vfx_talents.json','src/combat/marksman_combat.gd','src/combat/talent_combat.gd','src/combat/elements.gd','src/vfx/marksman_art.gd','src/vfx/talent_fx.gd','src/rig/forest_trap_rig.gd','src/session_protocol.gd','tests/ranger_fields_test.gd','tests/ranger_vfx_test.gd','tests/ranger_story_fields_test.gd','tests/archer_network_peer.gd','tests/talent_combat_test.gd','scripts/apply_ranger_fields_data.cjs','scripts/apply_archer_rework_data.cjs','scripts/capture_ranger_fields.gd','scripts/receipt_ranger_fields.cjs','docs/WALDLAEUFER-FELDER.de.md','docs/SCHUETZE-FALLEN-REWORK.de.md',`${dest}/README.md`];
const result={date:'2026-11-03',branch:'codex/port-0x72-onto-main',base:'7ca463de8fab9db47d594ea9e4987b5e6fe372ab',protocol:4,rules:27,total_checks:checks.reduce((n,c)=>n+c.checks,0),checks,network:{...hash(networkPath),result:network},capture:hash(capture),parse:hash(parse),red_before_fix:[hash('Logs/ranger-fields-red.log'),hash('Logs/ranger-vfx-wall-red.log')],images:images.map(hash),sources:sources.map(hash),scope:'Focused host rules, native fragment/wall geometry and particle timing, actual Hell/Frost media integration, two real local ENet processes, eight real renderer training captures; not campaign/LAN/WAN/performance or user art acceptance.',remaining:'Known fixture exit diagnostics (ObjectDB/resources; multi-world DummyTexture). New changes are local, no commit/push for this request.'};
fs.writeFileSync(`${dest}/receipt.json`,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({checks:result.total_checks,network:network.passed,images:images.length}));

const fs=require('fs'),crypto=require('crypto');
const dest='production/qa/evidence/archer-rework';
const names=['archer-rework-final','archer-all-talents','archer-talent_defense_test','archer-necro_soul_attacks_test','archer-perk_combat_test','archer-marksman_rig_test'];
const hash=path=>({path,bytes:fs.statSync(path).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')});
const checks=names.map(name=>{
 const path=`Logs/${name}.log`,text=fs.readFileSync(path,'utf8');
 const m=[...text.matchAll(/checked=(\d+) failures=(\d+)/g)].pop();
 if(!m||+m[2]||text.includes('SCRIPT ERROR'))throw Error(`Unpassed suite ${path}`);
 return {...hash(path),checks:+m[1],failures:+m[2]};
});
const netPath='Logs/archer-rework/20261103-135355-360eaf95/summary.json';
const network=JSON.parse(fs.readFileSync(netPath,'utf8'));
if(!network.passed||network.results.length!==2||network.results.some(r=>!r.passed))throw Error('Network incomplete');
const gpu=fs.readFileSync('Logs/archer-capture.log','utf8');
if(gpu.includes('SCRIPT ERROR')||!gpu.includes('images=6 native=1280x720'))throw Error('GPU capture incomplete');
const images=fs.readdirSync(dest).filter(p=>/^\d\d-.*\.png$/.test(p)).sort().map(p=>`${dest}/${p}`);
if(images.length!==6)throw Error('Expected six native captures');
for(const path of images){const b=fs.readFileSync(path);if(b.readUInt32BE(16)!==1280||b.readUInt32BE(20)!==720)throw Error(`Wrong capture size ${path}`);}
const sources=[
 'assets/data/talents.json','assets/data/marksman_rig.json','assets/sprites/0x72/weapon_arrow.png',
 'src/combat/marksman_combat.gd','src/combat/talent_charges.gd','src/combat/soul_charge.gd','src/combat/talent_combat.gd','src/perk_combat.gd','src/vfx/marksman_art.gd','src/vfx/talent_fx.gd','src/rig/forest_trap_rig.gd','src/hero/hero_look.gd','src/ui/talent_bar.gd','src/session_protocol.gd',
 'tests/archer_rework_test.gd','tests/marksman_rig_test.gd','tests/archer_network_peer.gd','tests/archer_network_smoke.ps1','tests/talent_combat_test.gd','tests/talent_defense_test.gd','tests/necro_soul_attacks_test.gd',
 'scripts/apply_archer_rework_data.cjs','scripts/capture_archer_rework.gd','scripts/receipt_archer_rework.cjs','docs/SCHUETZE-FALLEN-REWORK.de.md','docs/KRIEGER-KONZEPT.de.md',`${dest}/README.md`
];
const result={date:'2026-11-03',branch:'codex/port-0x72-onto-main',rules:25,protocol:4,total_checks:checks.reduce((s,c)=>s+c.checks,0),checks,network:{...hash(netPath),result:network},gpu_log:hash('Logs/archer-capture.log'),images:images.map(hash),sources:sources.map(hash),scope:'Focused host tests, controlled native GPU fixtures and two real local ENet processes. Warrior is concept only. No LAN/WAN/performance/campaign or art acceptance.'};
fs.writeFileSync(`${dest}/receipt.json`,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({checks:result.total_checks,network:network.passed,images:images.length}));

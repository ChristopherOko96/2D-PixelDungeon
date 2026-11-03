const fs=require('fs'), crypto=require('crypto');
const dest='production/qa/evidence/necro-forest-rework';
const suites=['necro-forest-green','forest-traps-green','forest-worms-green','forest-necro-art','forest-lab','necro-forest-lab-regression','necro-forest-blood-cycle','necro-forest-giant','necro-forest-talents','necro-forest-defense','forest-floor-snapshot'];
const checks=suites.map(name=>{
 const text=fs.readFileSync(`Logs/${name}.log`,'utf8');
 const match=[...text.matchAll(/checked=(\d+) failures=(\d+)/g)].pop();
 if(!match || +match[2] || text.includes('SCRIPT ERROR')) throw Error(`Unpassed suite: ${name}`);
 return {log:`Logs/${name}.log`,checks:+match[1],failures:+match[2]};
});
const network=group=>{
 const folder=`Logs/${group}`;
 for(const name of fs.readdirSync(folder).sort().reverse()) {
  const p=`${folder}/${name}/summary.json`;
  if(fs.existsSync(p)) {const d=JSON.parse(fs.readFileSync(p,'utf8'));if(d.passed) return {path:p,result:d};}
 }
 throw Error(`No successful network receipt: ${group}`);
};
const sources=[
 'src/combat/forest_summons.gd','src/combat/talent_combat.gd','src/combat/curse_monster_host.gd','src/combat/necromancer_branches.gd','src/combat/companion_targets.gd','src/combat/boss_moves.gd','src/vfx/necro_art.gd','src/vfx/talent_fx.gd','src/vfx/companion_rigs.gd','src/vfx/particles.gd','src/rig/forest_trap_rig.gd','src/ui/talent_icons.gd','src/debug/necro_lab_game.gd','src/debug/necro_lab_panel.gd','src/debug/necro_lab_art.gd','src/session_protocol.gd',
 'assets/data/talents.json','assets/data/necromancer_rules.json','assets/data/necro_spell_rigs.json','assets/data/companion_rigs.json','assets/data/forest_trap_rig.json','assets/data/debug_forest_lab.json','assets/data/debug_necro_lab.json','assets/sprites/companions/forest_worms/poison.png','assets/sprites/companions/forest_worms/fire.png','assets/sprites/companions/forest_worms/source/poison.png','assets/sprites/companions/forest_worms/source/fire.png',
 'scripts/import_forest_worms.gd','scripts/apply_necro_forest_data.cjs','scripts/capture_necro_forest.gd','scripts/run_forest_lab.gd','scripts/Dev.ps1','Waldmeister-Testraum.cmd'
];
const images=fs.readdirSync(dest).filter(p=>/^\d\d-.*\.png$/.test(p)).sort().map(p=>`${dest}/${p}`);
sources.push('src/vfx/fx_sprites.gd','tests/forest_worms_network_peer.gd','tests/forest_worms_network_smoke.ps1','tests/forest_worms_test.gd','tests/necro_forest_rework_test.gd','tests/forest_necro_art_test.gd','tests/forest_traps_rework_test.gd','tests/pool_floor_snapshot_test.gd');
if(images.length!==10) throw Error('Expected ten native GPU photos');
const gpu=fs.readFileSync('Logs/necro-forest-capture.log','utf8');
if(gpu.includes('SCRIPT ERROR') || !gpu.includes('images=10 native=1280x720')) throw Error('GPU capture incomplete');
const hashes=[...sources,...images].map(path=>({path,bytes:fs.statSync(path).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')}));
const result={date:'2026-11-03',branch:'codex/port-0x72-onto-main',rules:24,protocol:4,checks,total_checks:checks.reduce((s,v)=>s+v.checks,0),network:{necromancer:network('necro-blood'),worms:network('forest-worms')},gpu_log:'Logs/necro-forest-capture.log',hashes,art_approval:'Ja, beide so übernehmen',scope:'Focused tests and controlled GPU/native ENet loopback fixtures; no campaign, LAN, WAN or FPS acceptance.'};
fs.writeFileSync(`${dest}/receipt.json`,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({checks:result.total_checks,network:result.network.necromancer.path,worm_network:result.network.worms.path,images:images.length}));

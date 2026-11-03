const fs=require('fs'),crypto=require('crypto');
const dest='production/qa/evidence/rig-audit';
const hash=path=>({path,bytes:fs.statSync(path).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')});
const names=['talent_combat_test','archer_rework_test','cutout_coverage_test','crypt_enemy_ai_test','crypt_enemy_integration_test','hero_weapon_rig_test','rig_manifest_test','soul_ring_shape_test','element_exposure_test','talent_defense_test','perk_combat_test','rig_story_integration_test','hell_talents_test','pool_field_test','necro_soul_attacks_test','forest_worms_test','necro_forest_rework_test','curse_monster_evolution_test','guardian_beam_adhesion_test','soul_guardian_commands_test','attack_fx_test'];
const extra=['necro_pool_absorption_test','mage_neutral_feedback_test','story_clock_test','story_clock_integration_test'];
const checked=names.map(n=>`Logs/rig-audit-${['talent_combat_test','archer_rework_test'].includes(n)?'':'final-'}${n}.log`).concat(extra.map(n=>`Logs/rig-audit-${n}.log`)).map(path=>{
 const text=fs.readFileSync(path,'utf8'); const m=[...text.matchAll(/checked=(\d+) failures=(\d+)/g)].pop();
 if(!m||+m[2]||text.includes('SCRIPT ERROR'))throw Error(`Unpassed suite ${path}`);
 return {...hash(path),checks:+m[1],failures:+m[2]};
});
const buildPath='Logs/rig-audit-build-check.log',build=fs.readFileSync(buildPath,'utf8');
if(!build.includes('checked=2547 failures=0 drift=0'))throw Error('Rig build has drift');
const overlapPath='Logs/rig-audit-final-pool_consumption_overlap_test.log',overlap=fs.readFileSync(overlapPath,'utf8');
if(overlap.includes('false')||overlap.includes('SCRIPT ERROR'))throw Error('Pool overlap regression');
const networks=['Logs/archer-rework/20261103-161502-a2945bfd/summary.json','Logs/forest-worms/20261103-160125-f24eec28/summary.json'].map(path=>{
 const result=JSON.parse(fs.readFileSync(path,'utf8').replace(/^\uFEFF/,''));
 if(!result.passed||result.results.length!==2||result.results.some(r=>!r.passed))throw Error(`Network incomplete ${path}`);
 return {...hash(path),result};
});
const captures=[['Logs/rig-audit-gpu.log','images=10 native=1280x720'],['Logs/rig-audit-live-necro.log','images=10 native=1280x720'],['Logs/rig-audit-live-archer.log','images=6 native=1280x720']].map(([path,tag])=>{
 const text=fs.readFileSync(path,'utf8');if(text.includes('SCRIPT ERROR')||!text.includes(tag))throw Error(`Capture incomplete ${path}`);return hash(path);
});
const images=fs.readdirSync(dest).filter(p=>/^(effects|monsters|native)-.*\.png$/.test(p)).map(p=>`${dest}/${p}`).concat(['live-necro','live-archer'].flatMap(d=>fs.readdirSync(`${dest}/${d}`).filter(p=>/^\d\d-.*\.png$/.test(p)).map(p=>`${dest}/${d}/${p}`))).sort();
if(images.length!==26)throw Error('Expected 26 native captures');
for(const path of images){const b=fs.readFileSync(path);if(b.readUInt32BE(16)!==1280||b.readUInt32BE(20)!==720)throw Error(`Wrong size ${path}`);}
const sources=['assets/data/cutout_motion.json','assets/data/rig_manifest.json','assets/data/rigs.json','assets/data/hell_rigs.json','assets/data/companion_rigs.json','assets/data/krypta_boss_rigs.json','assets/data/vfx_pools.json','src/data/balance.json','src/rig/cutout_motion.gd','src/rig/rig_library.gd','src/rig/rig_poses.gd','src/rig/rig_renderer.gd','src/vfx/sheet_art.gd','src/vfx/fx_sprites.gd','src/vfx/attack_fx.gd','src/vfx/boss_fx.gd','src/vfx/talent_fx.gd','src/vfx/companion_rigs.gd','src/dungeon_view.gd','src/physics_kit/pool_field.gd','src/physics_kit/element_exposure.gd','src/hell/story_exposure_host.gd','src/hero/hero_look.gd','src/hero/story_hero.gd','src/session_protocol.gd','tools/rig_kit/curse_companions.js','tools/rig_kit/hand_rigs/hell_0x72.json','tools/rig_kit/hand_rigs/companion_rigs.json','tools/rig_kit/hand_rigs/krypta_boss_rigs.json','tests/cutout_coverage_test.gd','tests/rig_story_integration_test.gd','scripts/capture_rig_audit.gd','scripts/capture_rig_game.gd','scripts/capture_rig_archer.gd','scripts/receipt_rig_audit.cjs','docs/RIG-ANIMATIONEN-AUDIT.de.md',`${dest}/README.md`];
const result={date:'2026-11-03',branch:'codex/port-0x72-onto-main',publication:'origin/codex_v2',merged_upstream:'65a15a4a4f54ab16242dbee210d96b349ec4cbea',protocol:4,rules:26,total_checks:checked.reduce((s,c)=>s+c.checks,0),checked,build:{...hash(buildPath),checks:2547,failures:0,drift:0},overlap:hash(overlapPath),networks,captures,images:images.map(hash),sources:sources.map(hash),scope:'Focused rules/integration, real renderer fixtures, two real local ENet processes; no LAN/WAN/performance/campaign or art acceptance.',remaining:'Fixture exit diagnostics: ObjectDB/resources; multi-world fixtures also DummyTexture. Not memory-clean acceptance. Earlier cold-start timeouts retained in Logs.'};
fs.writeFileSync(`${dest}/receipt.json`,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({checks:result.total_checks,build:2547,networks:networks.length,images:images.length}));

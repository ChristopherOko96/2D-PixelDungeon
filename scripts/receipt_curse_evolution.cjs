// Reproducible receipt from the actual GPU originals; PNG bytes stay unchanged.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),apng=require('./necro_original_apng.cjs');
const root=path.resolve(__dirname,'..'),rel='production/qa/evidence/curse-evolution',folder=path.join(root,rel);
fs.mkdirSync(folder,{recursive:true});
const clips=[['curse_1','knochenball',27],['curse_wave','fluchwelle',30],['curse_brood','fluchbrut',110]];
for(const [id,name,moment] of clips){
 const source=path.join(root,'production/qa/evidence/necromancer-catalog-hq',id);
 fs.copyFileSync(path.join(source,'frame-'+String(moment).padStart(3,'0')+'.png'),path.join(folder,name+'.png'));
 const frames=fs.readdirSync(source).filter(n=>/^frame-\d+.png$/.test(n)).length;
 apng(source,frames,30,path.join(root,'output/necromancer-catalog',name+'-original.png'));
}
fs.copyFileSync(path.join(root,'Logs/necro-blood/20261102-203800-fdf0ec56/summary.json'),path.join(folder,'network-summary.json'));
const files=['assets/data/talents.json','assets/data/necromancer_rules.json','src/combat/curse_monster_host.gd','src/combat/necromancer_branches.gd','src/combat/talent_combat.gd','src/combat/soul_projectiles.gd','src/rig/curse_monster_rig.gd','src/rig/bone_ball_rig.gd','src/rig/rig_renderer.gd','src/vfx/companion_rigs.gd','src/vfx/necro_art.gd','src/vfx/talent_fx.gd','src/session_protocol.gd','tests/curse_monster_evolution_test.gd','tests/curse_monster_rig_test.gd','tests/necro_branches_story_test.gd','tests/necro_blood_network_peer.gd','tests/talent_combat_test.gd','scripts/capture_necromancer_catalog.gd','scripts/build_necromancer_original.cjs','output/necromancer-catalog/original-browser-review.json','production/qa/evidence/necromancer-catalog-hq/catalog.json',...clips.flatMap(([,name])=>[rel+'/'+name+'.png','output/necromancer-catalog/'+name+'-original.png'])];
fs.writeFileSync(path.join(folder,'source-hashes.json'),JSON.stringify({scope:'Host rules, real rigs, H/F integration, two local ENet peers and original GPU captures. No LAN/campaign/performance acceptance.',files:files.map(file=>({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')}))},null,2));
console.log('CURSE_EVOLUTION_RECEIPT files='+files.length);

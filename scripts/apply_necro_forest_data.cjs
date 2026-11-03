// Repeatable tuning migration; source values and units documented in the guide.
const fs = require('fs');
const edit = (name, fn) => { const p = `assets/data/${name}.json`; const d = JSON.parse(fs.readFileSync(p, 'utf8')); fn(d); fs.writeFileSync(p, JSON.stringify(d, null, 1)+'\n'); };
edit('talents', d => {
 for (const cls of ['mage','swordsman','necromancer']) d.defense[cls] = {type:'dodge',name:'Ausweichschritt',icon:'dash',charges:1,recharge:4,dist_m:3,iframes:0.25,text:'Shift: 3 m in Laufrichtung ausweichen, 0,25 s unverwundbar. Eine Ladung, 4 s Abklingzeit. Wände stoppen den Dash.'};
 Object.assign(d.talents.curse_3,{type:'curse_aura',radius_m:6,text:'Verflucht alle sichtbaren Gegner in 6 m um dich für 8/10/12 s: +10/15/20 % Schaden von dir. Kleine Fluchgeister steigen an jedem Ziel auf; die Mausposition spielt keine Rolle.'});
 d.talents.curse_14.text='Ruft sofort einen Fluchkoloss für 12 s aus einer großen Giftgrube (5 m, 8 s). Seine Treffer verfluchen Gegner. 5: Knochenwelle mit Schaden und Fluch. 6: echte Leichen als kleine Fluchmonster. Tote in der Grube explodieren; verbraucht bis zu 3 eigene Giftpfützen.';
 Object.assign(d.pet.abilities.curse_wave,{name:'Knochenwelle',type:'bone_wave',icon:'spikes',dmg:0.9,text:'Taste 5: nach 0,65 s eine Knochenwelle in 8 m. 90 % Schaden, Schwächung, Verwundbarkeit und Verfall. Mauern stoppen Treffer.'});
 d.talents.curse_6.text='Knochenball verursacht +15/30/45 % Schaden.';
 d.talents.curse_1.icon='skull';
 Object.assign(d.talents.curse_1,{text:'Knochen sammeln sich 0,65 s an der Hand zu einem Energiekern. Kugel mit Knochenspur; zerplatzt beim ersten Gegner oder an einer Wand. 100/115/130 % Schaden, Fluch, Verfall und kleine Giftpfütze.',mark_time:4,mark_pct:10});
 d.talents.soul_3.ring_expand=1;
 d.classes.archer.specs.find(s=>s.id==='beast').name='Waldmeister';
 Object.assign(d.talents.beast_6,{name:'Dornenköder',icon:'trap',type:'trap',dmg:[0.6,0.8,1],radius_m:2,root:[1,1.4,1.8],arm_s:0.5,cost:18,cd:9,text:'Legt einen Dornenköder. Nach 0,5 s scharf: 60/80/100 % Schaden in 2 m und 1/1,4/1,8 s Fessel. Mauern schützen; höchstens zwei Fallen.'});
 delete d.talents.beast_6.fan; delete d.talents.beast_6.style;
 Object.assign(d.talents.beast_7,{name:'Glutdruckfalle',icon:'bomb',type:'trap',dmg:[1,1.2,1.4],radius_m:3.5,arm_s:0.5,cost:25,cd:16,text:'Nach 0,5 s scharfe Druckfalle: 100/120/140 % Schaden in 3,5 m. Hinterlässt 5 s ein echtes Feuerfeld (20 % Schaden pro Sekunde).',ground_pool:{style:'fire',radius_m:3.5,time:5,dps:0.2,status:'burn'}});
 delete d.talents.beast_7.buff; delete d.talents.beast_7.attack_speed_pct;
 Object.assign(d.talents.beast_11,{name:'Wurzelgrund',icon:'spikes',type:'zone',radius_m:3.5,time:6,every:1,dmg:[0.2,0.25,0.3],status:'poison',slow:0.45,slow_time:1.2,fx:'poison',cost:24,cd:16,text:'Giftiger Wurzelgrund in 3,5 m für 6 s: 20/25/30 % Schaden pro Sekunde, Gift und 45 % Verlangsamung. Dein Begleiter hält Gegner im Jagdgebiet.'});
 delete d.talents.beast_11.dist_m;
 Object.assign(d.talents.beast_14,{name:'Urwürmer',type:'forest_worms',time:15,icon:'wolf',text:'Ruft Giftschlund und Glutschlund für 15 s. Beide jagen selbstständig und spucken große Gift- beziehungsweise Feuerfelder (3 m Radius, 5 s). Dein dauerhafter Begleiter bleibt. Maximal drei Felder je Wurm, die ältesten vergehen.',stages:[{name:'Zähe Schuppen',text:'Die Würmer erhalten 25 % mehr Leben.',set:{worm_hp_pct:25}},{name:'Wilde Brut',text:'25 % stärkere Felder.',set:{worm_pool_pct:25}}]});
 d.pet.forest_worms={hp:18,every:2.6,flight_s:0.45,pool_radius_m:3,pool_time:5,pool_dps:0.2,max_pools:3};
 d.talents.beast_14.icon='worms';
 for(const [kind,mat] of [['poison_worm','poison'],['fire_worm','fire']]) d.pet.kinds[kind]={rig:kind,portrait:`res://assets/sprites/companions/forest_worms/${mat}.png`,tempo:0.8,hp:1,dmg:1,every:1,speed:0.9,ranged:true,range_m:7,abilities:[]};
});
edit('necromancer_rules', d => {d.curse.ultimate_monster.on_hit_curse={time:6,pct:15};});
edit('necro_spell_rigs', d => {
 d.images.forest_orb='res://assets/sprites/fx/spell_orb.png';
 d.rigs.forest_spit={img:'forest_orb',family:'necro_spell',ground:[8,8],width:16,parts:[{id:'core',rects:[[0,0,15,15]],pivot:[8,8],parent:null,z:1,hp:1}],items:[]};
 d.motion.curse_spirit={count:3,rise_s:2.6,rise_px:42,spread_px:22,sway_px:2.5,scale:0.36};
 d.motion.bone_ball={charge_particles:12,core_scale:1.2,trail_count:8,trail_spacing:6,burst_count:18,burst_reach:2.1};
});
edit('companion_rigs', d => {
 for(const [kind,mat] of [['poison_worm','poison'],['fire_worm','fire']]) {
  d.images[kind]=`res://assets/sprites/companions/forest_worms/${mat}.png`;
  d.rigs[kind]={img:kind,family:'forest_worm',material:'blood',ground:[16,39],width:30,parts:[
   {id:'jaw',rects:[[18,21,31,24]],pivot:[19,22],parent:'head',z:7,hp:2,label:'Kiefer',disables:'attack'},
   {id:'head',rects:[[14,0,31,23]],pivot:[20,21],parent:'body',z:6,hp:4,label:'Kopf',vital:true},
   {id:'body',rects:[[7,14,22,27]],pivot:[16,27],parent:null,z:5,hp:5,label:'Rumpf',vital:true},
   {id:'segment_1',rects:[[7,26,22,30]],pivot:[16,28],parent:'body',z:4,hp:2,label:'Segment 1'},
   {id:'segment_2',rects:[[5,29,20,34]],pivot:[13,31],parent:'segment_1',z:3,hp:2,label:'Segment 2'},
   {id:'segment_3',rects:[[4,33,17,38]],pivot:[10,35],parent:'segment_2',z:2,hp:1,label:'Segment 3'},
   {id:'segment_4',rects:[[3,35,13,39]],pivot:[7,37],parent:'segment_3',z:1,hp:1,label:'Segment 4'},
   {id:'tail',rects:[[0,0,31,39]],pivot:[4,37],parent:'segment_4',z:0,hp:1,label:'Schwanz'}],items:[]};
 }
});
const lab=JSON.parse(fs.readFileSync('assets/data/debug_necro_lab.json','utf8'));
lab.labels.hint=lab.labels.hint.replace('Shift Schutz','Shift Dash');
fs.writeFileSync('assets/data/debug_necro_lab.json',JSON.stringify(lab,null,1)+'\n');
Object.assign(lab,{class_id:'archer',title:'WALDMEISTER · KAMPFLABOR',profile_path:'user://forest_lab_profile.json',default_spec:'beast',actions:['group','dummy','clear','souls','reset'],specs:{
 beast:{name:'WALD',color:'7cc23a',ultimate:'beast_14',kits:[{name:'Begleiter & Fallen',bar:['beast_1','beast_3','beast_6','beast_7']},{name:'Jagdgebiet',bar:['beast_1','beast_6','beast_7','beast_11']}]},
 trapper:{name:'FALLEN',color:'7cc23a',ultimate:'trapper_14',kits:[{name:'Gift & Dornen',bar:['trapper_1','trapper_3','trapper_5','trapper_7']},{name:'Netz & Rückzug',bar:['trapper_1','trapper_9','trapper_11','trapper_5']}]},
 sniper:{name:'FERN',color:'d6a536',ultimate:'sniper_14',kits:[{name:'Präzision',bar:['sniper_1','sniper_3','sniper_5','sniper_7']},{name:'Fernkampf',bar:['sniper_1','sniper_5','sniper_9','sniper_11']}]}
}});
lab.labels.souls='Ausdauer +';
fs.writeFileSync('assets/data/debug_forest_lab.json',JSON.stringify(lab,null,1)+'\n');

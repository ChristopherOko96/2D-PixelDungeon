const fs=require('fs');
// Explicit archer follow-up. Idempotent; does not touch any other class.
const path='assets/data/talents.json',d=JSON.parse(fs.readFileSync(path,'utf8'));
Object.assign(d.talents.sniper_14,{length_m:96,width_m:2.4,wall_radius:4,flight_s:0.28,impact_s:0.65,text:'R halten: Himmelsspeer bis 1,5 s aufladen. Ein 2,4 m breiter Pfeil durchbohrt den Raum bis zur ersten Wand und zerspringt dort. 350 bis 700 % Schaden, garantiert kritisch. Normale Gegner werden mitgerissen und 1 bis 2 s angepinnt; Bosse erhalten nur Schaden. 50 Ausdauer plus bis zu 25 fürs Laden.'});
Object.assign(d.talents.trapper_7,{name:'Giftfalle',type:'trap',dmg:[0,0,0],radius_m:3,trigger_m:1.3,visual_spread:2.4,charges:3,arm_s:0.5,fx:'poison',cloud:{time:6,every:1,dmg:[0.2,0.25,0.3],radius_m:3,gas_radius_m:2.25,status:'poison'},text:'Giftfalle: nach 0,5 s scharf. Ein Gegner löst eine echte Giftpfütze mit Giftwolke in 3 m aus, 6 s lang jede Sekunde 20/25/30 % Schaden und Gift. Drei Ladungen, eine lädt in 14 s nach.'});
delete d.talents.trapper_7.time;delete d.talents.trapper_7.every;
Object.assign(d.talents.trapper_11,{name:'Rankensog',type:'zone',icon:'trap',radius_m:5,time:1.5,every:0.5,dmg:[0.15,0.2,0.25],pull_mps:4.5,look:'ranger_pull',reach_m:7,slow:0.35,slow_time:0.6,text:'Rankensog am Zielort: zieht sichtbare normale Gegner in 5 m für 1,5 s zusammen. Alle 0,5 s 15/20/25 % Schaden und kurz 35 % langsamer. Wände stoppen den Sog; Bosse werden nicht bewegt. 20 Ausdauer, 14 s Abklingzeit.'});
delete d.talents.trapper_11.dist_m;delete d.talents.trapper_11.fx;
fs.writeFileSync(path,JSON.stringify(d,null,1)+'\n');
const vp='assets/data/vfx_talents.json',v=JSON.parse(fs.readFileSync(vp,'utf8'));
v.ranger={_note:'2026-11-03: native joint-solved arrow width follows authoritative r. flight_share is derived from host flight_s/span; debris seconds, speeds in art pixels/s, kick in art pixels, kick_rate in 1/s. Lure draws the existing trap tooth parts and moves existing particle matter, without another puddle.',arrow:{trail_count:8,trail_spacing:8,flight_share:0.3,width_share:0.82,min_scale:1.4,fragment_speed:48,fragment_kick:9,fragment_kick_rate:32,fragment_lift:18,fragment_gravity:46,fragment_spin:7,chip_count:24,spark_count:12},lure:{speed:1.4,turns:0.22,min_radius:0.12,part_scale:0.6,well_pull:180,well_swirl:24,mote_rate:18}};
fs.writeFileSync(vp,JSON.stringify(v,null,'\t')+'\n');
const labPath='assets/data/debug_forest_lab.json',lab=JSON.parse(fs.readFileSync(labPath,'utf8'));
lab.specs.trapper.kits[1].name='Netz & Rankensog';
fs.writeFileSync(labPath,JSON.stringify(lab,null,1)+'\n');

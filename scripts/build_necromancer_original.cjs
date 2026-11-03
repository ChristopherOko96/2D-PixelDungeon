const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/necromancer-catalog');
fs.mkdirSync(path.join(out,'original-stills'),{recursive:true});
const destination='C:/Users/Lea/.codex/visualizations/2026/10/31/01a191c2-5745-7013-8b0a-6f36505aea86/nekromant-original.html';
const old=fs.readFileSync('C:/Users/Lea/.codex/visualizations/2026/10/31/01a191c2-5745-7013-8b0a-6f36505aea86/nekromant-angriffe.html','utf8');
const data=JSON.parse(old.match(/<script type="application\/json" id="necro-catalog-data">([\s\S]*?)<\/script>/)[1]);
const talents=JSON.parse(fs.readFileSync(path.join(root,'assets/data/talents.json')));
data.clips.find(c=>c.id==='guardian_beam').text=talents.talents.soul_14.commands[0].text;
Object.assign(data.clips.find(c=>c.id==='curse_1'),{name:talents.talents.curse_1.name,text:talents.talents.curse_1.text});
for(const id of ['curse_wave','curse_brood']){
 const ability=talents.pet.abilities[id];
 data.clips.push({id,spec:'curse',name:ability.name,text:ability.text,stats:'Taste '+(id==='curse_wave'?'5':'6')+' · '+ability.cd+' s Abklingzeit',extra:true,variant:false,common:false});
}
const hq=JSON.parse(fs.readFileSync(path.join(root,'production/qa/evidence/necromancer-catalog-hq/catalog.json'),'utf8'));
if(hq.fps!==30||hq.width!==640||hq.cases.length!==40)throw Error('Expected all HQ originals');
const moments={soul_1:18,curse_1:18,curse_wave:30,curse_brood:70,minion_3:15,soul_9:60,soul_9_tap:14,soul_7:42,guardian_beam:28,guardian_wave:15,minion_14_stage_3:90,curse_14:90,curse_14_stage_2:90,curse_14_stage_3:90};
for(const clip of data.clips){
 if(clip.id==='curse_14'||clip.id.startsWith('curse_14_stage_')){
  const stage=hq.cases.find(c=>c.id===clip.id).stage;
  clip.text=talents.talents.curse_14.text+' '+talents.talents.curse_14.stages.slice(0,stage).map(s=>s.text).join(' ');
 }
 delete clip.icon;delete clip.start;delete clip.end;
 const frame=moments[clip.id]||30;
 clip.posterFrame=frame;
 const image=fs.readFileSync(path.join(root,'production/qa/evidence/necromancer-catalog-hq',clip.id,'frame-'+String(frame).padStart(3,'0')+'.png'));
 fs.writeFileSync(path.join(out,'original-stills',clip.id+'.png'),image);
 clip.still='data:image/png;base64,'+image.toString('base64');
}
const template=fs.readFileSync(path.join(out,'nekromant-original.template.html'),'utf8');
const render=value=>template.replace('__DATA__',()=>JSON.stringify(value).replace(/</g,'\\u003c'));
const fragment=render(data);if(Buffer.byteLength(fragment)>=1000000)throw Error('Original stills too large: '+Buffer.byteLength(fragment));
fs.writeFileSync(destination,fragment);
const playerData={...data,frameRoot:'../../production/qa/evidence/necromancer-catalog-hq/',clips:data.clips.map(c=>({...c,still:'original-stills/'+c.id+'.png',frames:hq.cases.find(a=>a.id===c.id).frames}))};
const wrapper=fs.readFileSync(path.join(out,'original-wrapper.html'),'utf8');
fs.writeFileSync(path.join(out,'nekromant-original.html'),wrapper.replace('__FRAGMENT__',()=>render(playerData)));
fs.writeFileSync(path.join(out,'original-inline-preview.html'),wrapper.replace('__FRAGMENT__',()=>fragment));
console.log(JSON.stringify({inline:destination,bytes:Buffer.byteLength(fragment),clips:data.clips.length,frames:hq.cases.reduce((n,c)=>n+c.frames,0),player:path.join(out,'nekromant-original.html')}));

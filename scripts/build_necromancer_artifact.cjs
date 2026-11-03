const fs=require('fs'),path=require('path');
const compactStill=require('./necro_catalog_stills.cjs');
const root=path.resolve(__dirname,'..'),source=path.join(root,'production/qa/evidence/necromancer-catalog'),out=path.join(root,'output/necromancer-catalog');
const catalog=JSON.parse(fs.readFileSync(path.join(source,'catalog.json'))),t=catalog.talents;
const timing=JSON.parse(fs.readFileSync(path.join(out,'video-timing.json')));
// MediaRecorder omits duration. Add the standard WebM Info.Duration element;
// no codec bytes, keyframe offsets or cluster-relative positions are changed.
let video=fs.readFileSync(path.join(out,'catalog-raw.webm'));
function vint(buf,pos,id=false){let length=1,mask=128;while(!(buf[pos]&mask)){length++;mask>>=1;}let value=id?buf[pos]:buf[pos]&(~mask);for(let i=1;i<length;i++)value=value*256+buf[pos+i];return {length,value};}
function size(value,length){const b=Buffer.alloc(length);for(let i=length-1;i>=0;i--){b[i]=value%256;value=Math.floor(value/256);}b[0]|=1<<(8-length);return b;}
let pos=0,info;
while(pos<video.length){const id=vint(video,pos,true),s=vint(video,pos+id.length),start=pos+id.length+s.length;if(id.value===0x18538067){pos=start;break;}pos=start+s.value;}
while(pos<video.length){const id=vint(video,pos,true),s=vint(video,pos+id.length),start=pos+id.length+s.length;if(id.value===0x1549a966){info={pos,id,s,start,end:start+s.value};break;}pos=start+s.value;}
if(!info)throw Error('WebM Info not found');
const duration=Buffer.alloc(11);duration.set([0x44,0x89,0x88]);duration.writeDoubleBE(timing.duration*1000,3);
video=Buffer.concat([video.subarray(0,info.pos+info.id.length),size(info.s.value+duration.length,info.s.length),video.subarray(info.start,info.end),duration,video.subarray(info.end)]);
fs.writeFileSync(path.join(out,'catalog.webm'),video);
const special={
 basic:{name:'Standardangriff · Stabgeschoss',text:'Kostenloser normaler Nekromantenangriff mit dem Stab.',stats:'Linke Maustaste · keine Seelenkosten',common:true},
 defense:{...t.defense.necromancer,stats:'Shift halten · 2 Treffer · 8 s bei Bruch',common:true},
 archer_death:{name:'Knochenschützen · Leichenexplosion',text:'Tod oder Ablauf nach 15 Sekunden löst pro Bogenschütze genau eine Explosion aus. Die Aufnahme zeigt den kontrollierten Todesauslöser.',stats:'Automatischer Auslöser · 1,8 m · 60 % Begleiter-Grundschaden'},
 curse_death:{name:'Todesfluch · Weiterflug',text:'Ein am Blutstrahl gestorbener Gegner setzt einen eigenständigen Fluchgeist frei. Er verfolgt einen weiteren sichtbaren Gegner, verursacht Schaden und hinterlässt einen Fluch.',stats:'Automatischer Auslöser · bis 5 m · Wände stoppen den Flug'}
};
for(const key of ['shield_bash','bone_shout','bone_stomp','bone_whirl'])special[key]={...t.pet.abilities[key],stats:(['shield_bash','bone_stomp'].includes(key)?'Taste 5':'Taste 6')+' · '+t.pet.abilities[key].cd+' s Abklingzeit'};
for(const [key,i] of [['guardian_beam',0],['guardian_wave',1]])special[key]={...t.talents.soul_14.commands[i],stats:'Taste '+(i+5)+' · '+t.talents.soul_14.commands[i].cd+' s Abklingzeit'};
const uri=file=>'data:image/png;base64,'+fs.readFileSync(file).toString('base64');
const clips=catalog.cases.map(c=>{
 const ability=t.talents[c.talent||c.id],s=special[c.id],variant=!!c.talent&&c.id!==c.talent;
 const upgrade=ability?.stages?.[c.stage-1];
 let name=s?.name||ability.name,text=s?.text||ability.text;
 if(c.stage>0){name+=' · Stufe '+(c.stage+1)+' ('+upgrade.name+')';text+=' '+ability.stages.slice(0,c.stage).map(a=>a.text).join(' ');}
 if(c.id==='soul_9')name+=' · voll geladen';if(c.id==='soul_9_tap')name+=' · kurz geladen';
 let stats=s?.stats||('Rang '+c.rank+' · '+ability.cost+' Seelen · '+ability.cd+' s Abklingzeit');
 if(c.id==='soul_9')stats+=' · bis zu 20 zusätzliche Seelen';
 const iconFile=path.join(source,c.id,'icon.png');
 return {id:c.id,spec:c.spec,name,text,stats,extra:!!s&&!s.common,variant,common:!!s?.common,icon:fs.existsSync(iconFile)?uri(iconFile):null,still:'data:image/png;base64,'+compactStill(path.join(source,c.id,'frame-015.png')).toString('base64'),...timing.clips.find(v=>v.id===c.id)};
});
const data={clips,specs:t.classes.necromancer.specs.map(s=>({id:s.id,name:s.name})),passives:Object.values(t.talents).filter(a=>a.class==='necromancer'&&a.kind==='passive').map(a=>({spec:a.spec,name:a.name,text:a.text}))};
if(clips.length!==38||data.passives.length!==21)throw Error('Incomplete gallery');
const alphabet=Array.from({length:94},(_,i)=>String.fromCharCode(i+33)).filter(c=>!'"\'<>\\`'.includes(c)).slice(0,85).join('');
let encoded='';for(let i=0;i<video.length;i+=4){let value=0;for(let n=0;n<4;n++)value=value*256+(video[i+n]||0);let group='';for(let n=0;n<5;n++){group=alphabet[value%85]+group;value=Math.floor(value/85);}encoded+=group;}
let html=fs.readFileSync(path.join(out,'nekromant-angriffe.template.html'),'utf8').replace('__VIDEO__',()=>JSON.stringify({alphabet,length:video.length,text:encoded})).replace('__DATA__',()=>JSON.stringify(data).replace(/</g,'\\u003c'));
if(Buffer.byteLength(html)>=1000000)throw Error('Fragment exceeds 1 MB: '+Buffer.byteLength(html));
const final='C:/Users/Lea/.codex/visualizations/2026/10/31/01a191c2-5745-7013-8b0a-6f36505aea86/nekromant-angriffe.html';
fs.writeFileSync(final,html);
// Standalone inspection wrapper only; inline delivery remains a fragment.
const preview='<!doctype html><meta charset="utf-8"><style>:root{--font-size-base:14px;--foreground:#ecebea;--background:#171719;--border:#555}body{background:var(--background);color:var(--foreground);font:14px system-ui;margin:20px;max-width:736px}button,select{font:inherit;padding:8px}h2,h3,p{margin:0}strong{font-weight:500}.nav{display:flex;gap:8px}.viz-controls{display:flex;flex-wrap:wrap;gap:8px;align-items:center}</style>'+html;
fs.writeFileSync(path.join(out,'preview.html'),preview);
console.log(JSON.stringify({path:final,bytes:Buffer.byteLength(html),clips:clips.length,passives:data.passives.length,videoBytes:video.length}));

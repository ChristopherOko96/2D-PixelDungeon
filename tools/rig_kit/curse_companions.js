'use strict';
const fs=require('fs'),path=require('path');
/** The approved curse-spirit layers as actual named combat rigs; no new images. */
function rigKit(ctx){
 const read=p=>JSON.parse(fs.readFileSync(path.join(ctx.root,p),'utf8'));
 const source=read('assets/data/curse_spirit_rig.json').rigs.curse_spirit;
 const rule=read('assets/data/necromancer_rules.json').curse.ultimate_monster;
 const rigs={};
 for(const [id,scale]of [['curse_colossus',rule.art_scale],['curse_spawn',rule.brood.art_scale]]){
  const rig=JSON.parse(JSON.stringify(source));
  Object.assign(rig,{family:'curse_monster',ground:[16,40],size:[32,40],width:32,scale:2*scale});
  for(const part of rig.parts){part.vital=['head','core'].includes(part.id);part.hp=part.id==='core'?3:1;}
  rigs[id]=rig;
 }
 const data=ctx.data?JSON.parse(JSON.stringify(ctx.data)):{rigs:{}};
 Object.assign(data.rigs,rigs);
 return {data,files:[],notes:['Approved curse cutouts registered as normal companion rigs.']};
}
module.exports={rigKit};

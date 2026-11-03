// Lossless APNG packaging of untouched GPU PNG frames; no palette or scaling.
const fs=require('fs'),path=require('path');
const table=Array.from({length:256},(_,n)=>{for(let i=0;i<8;i++)n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
function chunk(tag,data){const kind=Buffer.from(tag),size=Buffer.alloc(4),tail=Buffer.alloc(4);size.writeUInt32BE(data.length);let crc=0xffffffff;for(const b of Buffer.concat([kind,data]))crc=table[(crc^b)&255]^(crc>>>8);tail.writeUInt32BE((crc^0xffffffff)>>>0);return Buffer.concat([size,kind,data,tail]);}
function chunks(buffer){let pos=8,list=[];while(pos<buffer.length){const n=buffer.readUInt32BE(pos),type=buffer.toString('ascii',pos+4,pos+8);list.push({type,data:buffer.subarray(pos+8,pos+8+n)});pos+=n+12;}return list;}
module.exports=function(folder,count,fps,destination){
 const first=fs.readFileSync(path.join(folder,'frame-000.png')),header=chunks(first).find(c=>c.type==='IHDR').data;
 const w=header.readUInt32BE(0),h=header.readUInt32BE(4),animation=Buffer.alloc(8);animation.writeUInt32BE(count);animation.writeUInt32BE(0,4);
 const output=[first.subarray(0,8),chunk('IHDR',header),chunk('acTL',animation)];let sequence=0;
 for(let n=0;n<count;n++){
  const control=Buffer.alloc(26);control.writeUInt32BE(sequence++,0);control.writeUInt32BE(w,4);control.writeUInt32BE(h,8);control.writeUInt16BE(1,20);control.writeUInt16BE(fps,22);control[24]=0;control[25]=0;output.push(chunk('fcTL',control));
  const png=fs.readFileSync(path.join(folder,'frame-'+String(n).padStart(3,'0')+'.png'));
  for(const part of chunks(png).filter(c=>c.type==='IDAT')){if(n===0)output.push(chunk('IDAT',part.data));else{const prefix=Buffer.alloc(4);prefix.writeUInt32BE(sequence++);output.push(chunk('fdAT',Buffer.concat([prefix,part.data])));}}
 }
 output.push(chunk('IEND',Buffer.alloc(0)));const file=Buffer.concat(output);fs.writeFileSync(destination,file);return {width:w,height:h,frames:count,fps,bytes:file.length};
};

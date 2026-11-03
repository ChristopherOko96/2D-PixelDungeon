// Compact indexed stills preserve source pixel positions; video stays separate.
const fs=require('fs'),zlib=require('zlib');
const crcTable=Array.from({length:256},(_,n)=>{for(let k=0;k<8;k++)n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
function chunk(type,data){const kind=Buffer.from(type),len=Buffer.alloc(4);len.writeUInt32BE(data.length);let crc=0xffffffff;for(const b of Buffer.concat([kind,data]))crc=crcTable[(crc^b)&255]^(crc>>>8);const tail=Buffer.alloc(4);tail.writeUInt32BE((crc^0xffffffff)>>>0);return Buffer.concat([len,kind,data,tail]);}
module.exports=function(file){
 const png=fs.readFileSync(file),w=png.readUInt32BE(16),h=png.readUInt32BE(20),channels=png[25]===6?4:3,parts=[];let p=8;
 while(p<png.length){const n=png.readUInt32BE(p),tag=png.toString('ascii',p+4,p+8);if(tag==='IDAT')parts.push(png.subarray(p+8,p+8+n));p+=n+12;}
 const raw=zlib.inflateSync(Buffer.concat(parts)),pixels=Buffer.alloc(w*h*channels),stride=w*channels;
 function paeth(a,b,c){const v=a+b-c,pa=Math.abs(v-a),pb=Math.abs(v-b),pc=Math.abs(v-c);return pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
 for(let y=0;y<h;y++){const filter=raw[y*(stride+1)];for(let x=0;x<stride;x++){const i=y*stride+x,a=x>=channels?pixels[i-channels]:0,b=y?pixels[i-stride]:0,c=y&&x>=channels?pixels[i-stride-channels]:0;pixels[i]=(raw[y*(stride+1)+1+x]+(filter===1?a:filter===2?b:filter===3?Math.floor((a+b)/2):filter===4?paeth(a,b,c):0))&255;}}
 const counts=new Map();for(let i=0;i<pixels.length;i+=channels){const key=(pixels[i]>>4)*256+(pixels[i+1]>>4)*16+(pixels[i+2]>>4);counts.set(key,(counts.get(key)||0)+1);}
 const colors=[...counts].sort((a,b)=>b[1]-a[1]).slice(0,64).map(([k])=>[(k>>8)*17,((k>>4)&15)*17,(k&15)*17]);
 const lookup=new Map();for(const [k]of counts){const rgb=[(k>>8)*17,((k>>4)&15)*17,(k&15)*17];let best=0,d=Infinity;colors.forEach((c,i)=>{const distance=c.reduce((s,v,j)=>s+(v-rgb[j])**2,0);if(distance<d){best=i;d=distance;}});lookup.set(k,best);}
 const scan=Buffer.alloc((w+1)*h);for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=(y*w+x)*channels,key=(pixels[i]>>4)*256+(pixels[i+1]>>4)*16+(pixels[i+2]>>4);scan[y*(w+1)+x+1]=lookup.get(key);}
 const head=Buffer.alloc(13);head.writeUInt32BE(w);head.writeUInt32BE(h,4);head[8]=8;head[9]=3;
 return Buffer.concat([png.subarray(0,8),chunk('IHDR',head),chunk('PLTE',Buffer.from(colors.flat())),chunk('IDAT',zlib.deflateSync(scan,{level:9})),chunk('IEND',Buffer.alloc(0))]);
};

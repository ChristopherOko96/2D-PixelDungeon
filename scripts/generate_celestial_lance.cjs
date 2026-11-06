// Code-authored hard-alpha pixel art. Original generated arrow remains untouched.
const fs = require('fs');
const zlib = require('zlib');
const rows = [
'.....W.....',
'.....W.....',
'....GWG....',
'....GWG....',
'...GCWCG...',
'...GCWCG...',
'..GCCWCCG..',
'..GCWWWCG..',
'.GCCWWWWCG.',
'.GCWWWWCCG.',
'GCCWWWWWCCG',
'AGCCWWWCCGA',
'.AGCWWWCGA.',
'..AGCWCGA..',
'...AGWGA...',
'....GWG....',
'....GCG....',
'....GWG....',
'....GWG....',
'....GWG....',
'...AGWGA...',
'..GCCWCCG..',
'...AGWGA...',
'....GWG....',
'....GWG....',
'....GWG....',
'....GCG....',
'....GWG....',
'....GWG....',
'....GCG....',
'G...GWG...G',
'CG..GWG..GC',
'GCG.GWG.GCG',
'.GCGGWGGCG.',
'..GCWWWCG..',
'...GCWCG...',
'..GCGWGCG..',
'.GC.GWG.CG.',
'GC..GWG..CG',
'G....W....G',
'.....C.....'
];
// Inset shoulders below the diamond; no wooden shaft or feathers.
const palette={'.':[0,0,0,0],A:[139,83,37,255],G:[231,165,60,255],C:[255,222,123,255],W:[255,255,231,255]};
if(rows.length!==41||rows.some(r=>r.length!==11)) throw Error('Invalid lance grid '+rows.map(r=>r.length));
function crc(b){let c=0xffffffff;for(const v of b){c^=v;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
function chunk(type,data){const t=Buffer.from(type);const b=Buffer.alloc(12+data.length);b.writeUInt32BE(data.length);t.copy(b,4);data.copy(b,8);b.writeUInt32BE(crc(Buffer.concat([t,data])),8+data.length);return b;}
const head=Buffer.alloc(13);head.writeUInt32BE(11);head.writeUInt32BE(41,4);head[8]=8;head[9]=6;
const raw=Buffer.concat(rows.map(r=>Buffer.from([0,...[...r].flatMap(c=>palette[c])])));
fs.writeFileSync('assets/sprites/marksman/celestial_lance.png',Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',head),chunk('IDAT',zlib.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]));
console.log('Celestial lance: 11x41, five colors, hard alpha');

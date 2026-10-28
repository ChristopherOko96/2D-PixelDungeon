// Writes a review sheet of every hell monster: one row per monster, its animations
// side by side, each frame scaled up with nearest neighbour.
// Usage: node tools/hell_dungeon/monster_sheet.js <out.png> [scale] [ids,comma,separated]
'use strict';
const fs = require('fs');
const zlib = require('zlib');
const HM = require('./hell_monsters.js');

function crcTable() {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
}
const CRC = crcTable();
function crc(buf) { let c = 0xffffffff; for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]), c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, c]);
}
/** Encodes RGBA pixels (Uint8 array, w*h*4) as a PNG buffer. */
function encodePng(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

if (require.main === module) {
  const out = process.argv[2], S = +(process.argv[3] || 5);
  const ids = process.argv[4] ? process.argv[4].split(',') : Object.keys(HM.DEFS);
  const rows = ids.map(id => {
    const def = HM.DEFS[id], frames = [];
    const only = process.env.ANIMS ? process.env.ANIMS.split(',') : HM.ANIMS;
    for (const a of only) if (a === 'death' || def.anims[a]) for (let f = 0; f < HM.frameCount(def, a); f++) frames.push(HM.render(id, a, f));
    return { def, frames };
  });
  const W = Math.max(...rows.map(r => r.frames.reduce((s, f) => s + f.w * S + 6, 8)));
  const H = rows.reduce((s, r) => s + r.def.h * S + 10, 8);
  const img = new Uint8Array(W * H * 4);
  for (let i = 0; i < W * H; i++) img.set([46, 40, 48, 255], i * 4);
  let y = 6;
  for (const r of rows) {
    let x = 6;
    for (const f of r.frames) {
      for (let yy = 0; yy < f.h * S; yy++) for (let xx = 0; xx < f.w * S; xx++) {
        const s = ((yy / S | 0) * f.w + (xx / S | 0)) * 4;
        if (f.data[s + 3]) img.set(f.data.subarray(s, s + 4), ((y + yy) * W + x + xx) * 4);
      }
      x += f.w * S + 6;
    }
    y += r.def.h * S + 10;
  }
  fs.writeFileSync(out, encodePng(W, H, img));
  console.log('sheet', W, 'x', H, '->', out);
}
module.exports = { encodePng };

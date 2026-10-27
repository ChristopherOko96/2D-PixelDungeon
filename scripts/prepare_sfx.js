// Cuts the game's sound effects from the user's sound folder into short mono
// variants (assets/audio/sfx/<event>_<n>.wav) as listed in assets/data/audio_sfx.json.
// The source folder is only read. Pixel Combat files (*_HY_PC.wav) hold six
// takes every 4 s; each take is found by its level, trimmed, faded and
// normalised. 96 kHz sources become 48 kHz, others keep their rate; all
// outputs are 16-bit mono PCM.
// Usage: node scripts/prepare_sfx.js "<sound folder>"
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const source = process.argv[2];
if (!source || !fs.existsSync(source)) { console.error("usage: node scripts/prepare_sfx.js <sound folder>"); process.exit(1); }
const manifest = JSON.parse(fs.readFileSync(path.join(root, "assets", "data", "audio_sfx.json"), "utf8"));
const out = path.join(root, manifest.output.replace("res://", ""));
fs.mkdirSync(out, { recursive: true });

const THRESHOLD_DB = -54;    // a 10 ms window louder than this counts as sound
const GAP_SECONDS = 0.25;    // silence longer than this separates two takes
const PAD_BEFORE = 0.004;    // keep a few ms before the attack
const TAIL = 0.06;           // keep this much after the last audible window
const FADE_IN = 0.002;
const FADE_OUT = 0.03;
const PEAK = Math.pow(10, -1 / 20); // normalise to -1 dBFS

function readWav(file) {
  const b = fs.readFileSync(file);
  if (b.toString("ascii", 0, 4) !== "RIFF" || b.toString("ascii", 8, 12) !== "WAVE") throw new Error("not a WAV: " + file);
  let p = 12, fmt = null, data = null;
  while (p + 8 <= b.length) {
    const id = b.toString("ascii", p, p + 4), size = b.readUInt32LE(p + 4);
    if (id === "fmt ") fmt = { tag: b.readUInt16LE(p + 8), ch: b.readUInt16LE(p + 10), rate: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22) };
    if (id === "data") data = { off: p + 8, size: Math.min(size, b.length - p - 8) };
    p += 8 + size + (size & 1);
  }
  if (!fmt || !data) throw new Error("no fmt/data chunk: " + file);
  const bytes = fmt.bits / 8, frames = Math.floor(data.size / (bytes * fmt.ch));
  const mono = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    let sum = 0;
    for (let c = 0; c < fmt.ch; c++) {
      const o = data.off + (i * fmt.ch + c) * bytes;
      let v;
      if (fmt.tag === 3 && fmt.bits === 32) v = b.readFloatLE(o);
      else if (fmt.bits === 16) v = b.readInt16LE(o) / 32768;
      else if (fmt.bits === 24) v = b.readIntLE(o, 3) / 8388608;
      else if (fmt.bits === 32) v = b.readInt32LE(o) / 2147483648;
      else if (fmt.bits === 8) v = (b[o] - 128) / 128;
      else throw new Error(`unsupported ${fmt.bits}-bit: ${file}`);
      sum += v;
    }
    mono[i] = sum / fmt.ch;
  }
  return { rate: fmt.rate, samples: mono };
}

// Halves the rate with a short low-pass (1-2-1 kernel) against aliasing.
function halve(samples) {
  const result = new Float32Array(Math.floor(samples.length / 2));
  for (let i = 0; i < result.length; i++) {
    const a = samples[2 * i - 1] ?? samples[0], b = samples[2 * i], c = samples[2 * i + 1] ?? samples[2 * i];
    result[i] = 0.25 * a + 0.5 * b + 0.25 * c;
  }
  return result;
}

function takes(samples, rate) {
  const win = Math.max(1, Math.floor(rate * 0.01)), threshold = Math.pow(10, THRESHOLD_DB / 20), gap = Math.ceil(GAP_SECONDS * 100);
  const found = []; let start = -1, last = -1;
  for (let w = 0; w * win < samples.length; w++) {
    let peak = 0;
    for (let i = w * win; i < Math.min(samples.length, (w + 1) * win); i++) peak = Math.max(peak, Math.abs(samples[i]));
    if (peak > threshold) { if (start < 0) start = w; last = w; }
    else if (start >= 0 && w - last > gap) { found.push([start * win, (last + 1) * win]); start = -1; }
  }
  if (start >= 0) found.push([start * win, (last + 1) * win]);
  return found;
}

function cut(samples, rate, [from, to], maxSeconds) {
  let a = Math.max(0, from - Math.floor(PAD_BEFORE * rate));
  let z = Math.min(samples.length, to + Math.floor(TAIL * rate));
  if (maxSeconds) z = Math.min(z, a + Math.floor(maxSeconds * rate));
  const piece = samples.slice(a, z);
  const fadeIn = Math.floor(FADE_IN * rate), fadeOut = Math.min(piece.length, Math.floor(FADE_OUT * rate));
  for (let i = 0; i < fadeIn && i < piece.length; i++) piece[i] *= i / fadeIn;
  for (let i = 0; i < fadeOut; i++) piece[piece.length - 1 - i] *= i / fadeOut;
  let peak = 0;
  for (const v of piece) peak = Math.max(peak, Math.abs(v));
  if (peak > 0) for (let i = 0; i < piece.length; i++) piece[i] *= PEAK / peak;
  return piece;
}

function writeWav(file, samples, rate) {
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), i * 2);
  const header = Buffer.alloc(44);
  header.write("RIFF", 0); header.writeUInt32LE(36 + data.length, 4); header.write("WAVE", 8);
  header.write("fmt ", 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
  header.writeUInt32LE(rate, 24); header.writeUInt32LE(rate * 2, 28); header.writeUInt16LE(2, 32); header.writeUInt16LE(16, 34);
  header.write("data", 36); header.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([header, data]));
}

let written = 0, bytes = 0;
for (const [event, spec] of Object.entries(manifest.events)) {
  const file = path.join(source, ...spec.src.split("/"));
  let { rate, samples } = readWav(file);
  if (rate >= 88200) { samples = halve(samples); rate = Math.floor(rate / 2); }
  const found = takes(samples, rate);
  const wanted = Math.min(spec.variants || 1, found.length);
  if (!wanted) throw new Error("no audible take in " + spec.src);
  for (const old of fs.readdirSync(out).filter((f) => f.startsWith(event + "_") && /_\d+\.wav$/.test(f) && f.slice(0, f.lastIndexOf("_")) === event)) fs.unlinkSync(path.join(out, old));
  const lengths = [];
  for (let n = 0; n < wanted; n++) {
    const piece = cut(samples, rate, found[n], spec.max_seconds);
    const target = path.join(out, `${event}_${n}.wav`);
    writeWav(target, piece, rate);
    written++; bytes += 44 + piece.length * 2; lengths.push((piece.length / rate).toFixed(2));
  }
  console.log(`${event.padEnd(14)} ${wanted}x ${rate} Hz  ${lengths.join(" ")} s  <- ${spec.src}`);
}
console.log(`SFX_DONE files=${written} size=${(bytes / 1024 / 1024).toFixed(2)} MB`);

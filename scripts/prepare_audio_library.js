// Copies the downloaded CC0 sound packs and music into the game and measures
// every file, so the mix can level them (assets/data/audio_library.json):
//   node scripts/prepare_audio_library.js <downloads folder>
// The downloads folder holds one sub-folder per pack as fetched on 2026-10-28
// (see assets/audio/library/CREDITS.md). Files are copied as they are (OGG);
// WAV sources are converted to OGG. For each file ffmpeg measures the mean and
// peak level; gain_db brings the mean to the target without letting the peak
// pass -1 dBFS. The recordings already in assets/audio/sfx (pack "pixel_combat")
// are measured in place. Needs ffmpeg and ffprobe on the PATH.
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const DOWNLOADS = process.argv[2];
if (!DOWNLOADS || !fs.existsSync(DOWNLOADS)) {
  console.error("usage: node scripts/prepare_audio_library.js <downloads folder>");
  process.exit(1);
}
const LIBRARY = path.join(ROOT, "assets/audio/library");
const MUSIC = path.join(ROOT, "assets/audio/music");
const SFX_TARGET_MEAN = -20;
const MUSIC_TARGET_MEAN = -20;
const PEAK_CEILING = -1;

const PACKS = [
  { id: "kenney_impact", name: "Kenney Impact Sounds", author: "Kenney (kenney.nl)", url: "https://kenney.nl/assets/impact-sounds", via: "https://github.com/Boyquotes/kenney-impact-sounds-for-godot", glob: "kenney_impact/x", match: /\.ogg$/i },
  { id: "kenney_rpg", name: "50 RPG sound effects", author: "Kenney (kenney.nl)", url: "https://opengameart.org/content/50-rpg-sound-effects", glob: "kenney_rpg/x", match: /\.ogg$/i },
  { id: "bones", name: "Bones rattle (from blukotek, CC0) and Bones 2", author: "congusbongus; AntumDeluge", url: "https://opengameart.org/content/bones-rattle ; https://opengameart.org/content/bones-2", glob: "bones_rattle/x", extra: "bones_2", match: /\.(ogg|wav)$/i, prefix: "bones_rattle_" },
  { id: "creatures_1", name: "80 CC0 creature SFX", author: "rubberduck", url: "https://opengameart.org/content/80-cc0-creature-sfx", glob: "creatures_1/x", match: /\.ogg$/i },
  { id: "creatures_2", name: "80 CC0 creature SFX #2", author: "rubberduck", url: "https://opengameart.org/content/80-cc0-creture-sfx-2", glob: "creatures_2/x", match: /\.ogg$/i },
];

const TRACKS = [
  { id: "dungeon_ambience", name: "Dungeon Ambience", author: "yd", url: "https://opengameart.org/content/dungeon-ambience", file: "music_dungeon_ambience/dungeon002_0.ogg" },
  { id: "dungeon_wind_drips", name: "Loopable Dungeon Ambience", author: "JaggedStone", url: "https://opengameart.org/content/loopable-dungeon-ambience", file: "music_loopable_ambience/dungeon_ambient_1_0.ogg" },
  { id: "heavy_dungeon", name: "Heavy Dungeon (160 BPM)", author: "MintoDog", url: "https://opengameart.org/node/181405", file: "music_heavy_dungeon/heavy_dungeon_bpm160_0.ogg" },
  { id: "heavy_boss_battle_1", name: "Heavy Boss Battle 1 (200 BPM)", author: "MintoDog", url: "https://opengameart.org/node/183631", file: "music_heavy_boss_1/heavy_boss_battle_1_bpm200_0.ogg" },
  { id: "determined_pursuit", name: "Determined Pursuit (epic orchestra loop)", author: "Emma_MA", url: "https://opengameart.org/content/determined-pursuit-epic-orchestra-loop", file: "music_determined_pursuit/determined_pursuit_loop.wav" },
];

function walk(folder) {
  const out = [];
  for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
    const full = path.join(folder, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

function clean(name) {
  return name.toLowerCase().replace(/[^a-z0-9_.-]+/g, "_");
}

function levels(buffer) {
  const text = buffer.toString();
  const mean = parseFloat((text.match(/mean_volume:\s*(-?[\d.]+)/) || [0, -30])[1]);
  const peak = parseFloat((text.match(/max_volume:\s*(-?[\d.]+)/) || [0, 0])[1]);
  return { mean, peak };
}

function gainFor(m, target) {
  let gain = target - m.mean;
  gain = Math.min(gain, PEAK_CEILING - m.peak);
  return Math.round(Math.max(-18, Math.min(18, gain)) * 10) / 10;
}

// Mean and peak level (dBFS) and length in seconds of an audio file.
function volumedetect(file) {
  const seconds = parseFloat(execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file]).toString().trim());
  const result = spawnSync("ffmpeg", ["-hide_banner", "-nostats", "-i", file, "-af", "volumedetect", "-f", "null", "-"]);
  return { seconds: Math.round(seconds * 1000) / 1000, ...levels(Buffer.concat([result.stdout || Buffer.alloc(0), result.stderr || Buffer.alloc(0)])) };
}

function toRes(file) {
  return "res://" + path.relative(ROOT, file).split(path.sep).join("/");
}

const library = { packs: {}, music: {} };
fs.mkdirSync(LIBRARY, { recursive: true });
fs.mkdirSync(MUSIC, { recursive: true });

for (const pack of PACKS) {
  const target = path.join(LIBRARY, pack.id);
  fs.mkdirSync(target, { recursive: true });
  const sources = walk(path.join(DOWNLOADS, pack.glob)).filter((f) => pack.match.test(f));
  if (pack.extra) sources.push(...walk(path.join(DOWNLOADS, pack.extra)).filter((f) => pack.match.test(f)));
  const files = [];
  for (const source of sources.sort()) {
    let base = clean(path.basename(source));
    if (pack.prefix && /^\d+\.ogg$/.test(base)) base = pack.prefix + base;
    let destination = path.join(target, base.replace(/\.wav$/, ".ogg"));
    if (/\.wav$/i.test(source)) execFileSync("ffmpeg", ["-y", "-hide_banner", "-loglevel", "error", "-i", source, "-c:a", "libvorbis", "-q:a", "6", destination]);
    else fs.copyFileSync(source, destination);
    const m = volumedetect(destination);
    files.push({ path: toRes(destination), name: path.basename(destination, ".ogg"), seconds: m.seconds, mean_db: m.mean, peak_db: m.peak, gain_db: gainFor(m, SFX_TARGET_MEAN) });
  }
  library.packs[pack.id] = { name: pack.name, author: pack.author, url: pack.url, via: pack.via || "", license: "CC0 1.0", files };
  console.log(`${pack.id}: ${files.length} files`);
}

// The recordings of the earlier sound pass, measured where they are.
const old = [];
for (const file of fs.readdirSync(path.join(ROOT, "assets/audio/sfx")).filter((f) => f.endsWith(".wav")).sort()) {
  const full = path.join(ROOT, "assets/audio/sfx", file);
  const m = volumedetect(full);
  old.push({ path: toRes(full), name: path.basename(file, ".wav"), seconds: m.seconds, mean_db: m.mean, peak_db: m.peak, gain_db: gainFor(m, SFX_TARGET_MEAN) });
}
library.packs.pixel_combat = { name: "Pixel Combat recordings (first sound pass)", author: "unknown pack, see assets/audio/sfx/license_note.md", url: "", via: "", license: "unknown", files: old };
console.log(`pixel_combat: ${old.length} files`);

for (const track of TRACKS) {
  const source = path.join(DOWNLOADS, track.file);
  const destination = path.join(MUSIC, track.id + ".ogg");
  if (/\.wav$/i.test(source)) execFileSync("ffmpeg", ["-y", "-hide_banner", "-loglevel", "error", "-i", source, "-c:a", "libvorbis", "-q:a", "5", destination]);
  else fs.copyFileSync(source, destination);
  const m = volumedetect(destination);
  library.music[track.id] = { name: track.name, author: track.author, url: track.url, license: "CC0 1.0", path: toRes(destination), seconds: m.seconds, mean_db: m.mean, peak_db: m.peak, gain_db: gainFor(m, MUSIC_TARGET_MEAN) };
  console.log(`music ${track.id}: ${m.seconds}s mean ${m.mean} peak ${m.peak}`);
}

const note = "Sound library (scripts/prepare_audio_library.js): every pack with its source, licence and files. seconds = length; mean_db / peak_db = measured level in dBFS; gain_db levels the file to a mean of " + SFX_TARGET_MEAN + " dBFS without its peak passing " + PEAK_CEILING + " dBFS. The sound table (audio_sfx.json) and the music table (audio_music.json) pick files from here; the Klangwerkstatt lists them.";
fs.writeFileSync(path.join(ROOT, "assets/data/audio_library.json"), JSON.stringify({ _note: note, schema_version: 1, ...library }, null, 1) + "\n");

const credits = ["# Sound library — sources and licences", "", "Fetched on 2026-10-28 by `scripts/prepare_audio_library.js`. All packs below are", "CC0 1.0 (public domain dedication): free to use, change and share, also", "commercially, without attribution. Credit is given here anyway.", ""];
for (const pack of PACKS) credits.push(`- **${pack.name}** by ${pack.author}: ${pack.url}${pack.via ? ` (copy used: ${pack.via})` : ""} -> \`assets/audio/library/${pack.id}/\``);
credits.push("", "## Music", "");
for (const track of TRACKS) credits.push(`- **${track.name}** by ${track.author}: ${track.url} -> \`assets/audio/music/${track.id}.ogg\``);
credits.push("", "The recordings in `assets/audio/sfx/` come from the first sound pass; their licence is unknown (see `assets/audio/sfx/license_note.md`).", "");
fs.writeFileSync(path.join(LIBRARY, "CREDITS.md"), credits.join("\n"));
console.log("done");

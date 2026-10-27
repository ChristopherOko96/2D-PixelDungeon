// Style proof: builds out/stilprobe.html from review.template.html by embedding
// the original sprites, the rendered room and its prop/floor data as data URIs.
// Usage: node build_review.js <0x72 frames dir> <seed> <room>
const fs = require("fs");
const path = require("path");

const [frames, seed, roomNumber] = process.argv.slice(2);
const here = __dirname;
const out = path.join(here, "out");
const png = (file) => "data:image/png;base64," + fs.readFileSync(file).toString("base64");
const frame = (name) => png(path.join(frames, name + ".png"));

const assets = {
  knight: frame("knight_m_idle_anim_f0"),
  skelet: frame("skelet_idle_anim_f0"),
  necro: frame("necromancer_anim_f0"),
  zombie: frame("big_zombie_idle_anim_f0"),
  knight_sword: frame("weapon_knight_sword"),
  rusty_sword: frame("weapon_rusty_sword"),
  red_staff: frame("weapon_red_magic_staff"),
  floor_1: frame("floor_1"),
  wall_mid: frame("wall_mid"),
  wall_top_mid: frame("wall_top_mid"),
  wall_outer_mid_left: frame("wall_outer_mid_left"),
  wall_banner_red: frame("wall_banner_red"),
  skull: frame("skull"),
  crate: frame("crate"),
  room: png(path.join(out, "room.png")),
};
for (let i = 0; i < 8; i++) {
  assets[`wall_torch_${i}`] = png(path.join(out, "props", `wall_torch_f${i}.png`));
  assets[`candle_column_${i}`] = png(path.join(out, "props", `candle_column_f${i}.png`));
}

const props = JSON.parse(fs.readFileSync(path.join(out, "room_props.json"), "utf8"));
const meta = { seed: Number(seed), room: Number(roomNumber), template: process.argv[5] || "crypt_03" };
const room = { ...props, meta };

let html = fs.readFileSync(path.join(here, "review.template.html"), "utf8");
html = html.replace("/*__ASSETS__*/", "const ASSETS = " + JSON.stringify(assets) + ";");
html = html.replace("/*__ROOM__*/", "const ROOM = " + JSON.stringify(room) + ";");
fs.writeFileSync(path.join(out, "stilprobe.html"), html);
console.log("BUILT", path.join(out, "stilprobe.html"), Math.round(html.length / 1024) + " KB");

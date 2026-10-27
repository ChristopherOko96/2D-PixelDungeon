// Complete-set review: builds out/gesamtsatz.html from full.template.html by
// embedding original sprites, the Schläfer and Leerenrufer sprites, all ten
// rendered rooms and their prop/floor data. Usage: node build_full.js <0x72 frames dir>
const fs = require("fs");
const path = require("path");

const frames = process.argv[2];
const here = __dirname, out = path.join(here, "out");
const png = (file) => "data:image/png;base64," + fs.readFileSync(file).toString("base64");
const frame = (name) => png(path.join(frames, name + ".png"));

const assets = {
  knight: frame("knight_m_idle_anim_f0"), elf: frame("elf_f_idle_anim_f0"), wizard: frame("wizzard_m_idle_anim_f0"), lizard: frame("lizard_m_idle_anim_f0"),
  skelet: frame("skelet_idle_anim_f0"), necro: frame("necromancer_anim_f0"), tiny_zombie: frame("tiny_zombie_idle_anim_f0"), ice_zombie: frame("ice_zombie_anim_f0"),
  big_zombie: frame("big_zombie_idle_anim_f0"), ogre: frame("ogre_idle_anim_f0"), big_demon: frame("big_demon_idle_anim_f0"),
  goblin: frame("goblin_idle_anim_f0"), imp: frame("imp_idle_anim_f0"), chort: frame("chort_idle_anim_f0"), wogol: frame("wogol_idle_anim_f0"),
  masked_orc: frame("masked_orc_idle_anim_f0"), orc_warrior: frame("orc_warrior_idle_anim_f0"), orc_shaman: frame("orc_shaman_idle_anim_f0"),
  muddy: frame("muddy_anim_f0"), swampy: frame("swampy_anim_f0"), slug: frame("slug_anim_f0"), tiny_slug: frame("tiny_slug_anim_f0"),
  knight_sword: frame("weapon_knight_sword"), rusty_sword: frame("weapon_rusty_sword"), red_staff: frame("weapon_red_magic_staff"), green_staff: frame("weapon_green_magic_staff"),
  bow: frame("weapon_bow"), arrow: frame("weapon_arrow"), knife: frame("weapon_knife"), spear: frame("weapon_spear"), axe: frame("weapon_axe"),
  big_hammer: frame("weapon_big_hammer"), cleaver: frame("weapon_cleaver"), mace: frame("weapon_mace"),
  floor_1: frame("floor_1"), wall_mid: frame("wall_mid"), wall_top_mid: frame("wall_top_mid"),
  wall_banner_red: frame("wall_banner_red"), wall_banner_blue: frame("wall_banner_blue"), wall_banner_green: frame("wall_banner_green"),
  skull: frame("skull"), crate: frame("crate"), column: frame("column"), floor_stairs: frame("floor_stairs"),
  doors_leaf_closed: frame("doors_leaf_closed"), doors_leaf_open: frame("doors_leaf_open"),
  sleeper_mantle: png(path.join(out, "sleeper", "sleeper_mantle.png")), sleeper_fin: png(path.join(out, "sleeper", "sleeper_fin_left.png")),
};
for (let i = 0; i < 8; i++) {
  assets[`wall_torch_${i}`] = png(path.join(out, "props", `wall_torch_f${i}.png`));
  assets[`candle_column_${i}`] = png(path.join(out, "props", `candle_column_f${i}.png`));
}
for (let i = 0; i < 3; i++) { assets[`chest_${i}`] = frame(`chest_full_open_anim_f${i}`); assets[`fountain_${i}`] = frame(`wall_fountain_mid_red_anim_f${i}`); }
for (let i = 0; i < 4; i++) assets[`spikes_${i}`] = frame(`floor_spikes_anim_f${i}`);
// Leerenrufer body frames (cut from the user's sheet by make_void.gd).
for (let i = 0; i < 8; i++) assets[`void_body_${i}`] = png(path.join(out, "void", `void_body_f${i}.png`));

const rooms = {};
for (let i = 1; i <= 10; i++) {
  assets[`room_${i}`] = png(path.join(out, "rooms", `room_${i}.png`));
  rooms[i] = JSON.parse(fs.readFileSync(path.join(out, "rooms", `room_${i}_props.json`), "utf8"));
}
const sleeper = JSON.parse(fs.readFileSync(path.join(here, "sleeper.json"), "utf8"));

let html = fs.readFileSync(path.join(here, "full.template.html"), "utf8");
html = html.replace("/*__ASSETS__*/", "const ASSETS = " + JSON.stringify(assets) + ";");
html = html.replace("/*__ROOMS__*/", "const ROOMS = " + JSON.stringify(rooms) + ";");
html = html.replace("/*__SLEEPER__*/", "const SLEEPER = " + JSON.stringify(sleeper) + ";");
const voidBoss = JSON.parse(fs.readFileSync(path.join(here, "void.json"), "utf8"));
html = html.replace("/*__VOID__*/", "const VOID = " + JSON.stringify(voidBoss) + ";");
fs.writeFileSync(path.join(out, "gesamtsatz.html"), html);
console.log("BUILT gesamtsatz.html", Math.round(html.length / 1024) + " KB");

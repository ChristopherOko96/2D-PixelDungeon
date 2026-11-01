// Exports the approved part rigs from full.template.html (DEFS, SHIELD) and
// void.json into the game's data file assets/data/rigs.json, so the game and
// the review page split every figure the same way.
// Usage (from the repo root or anywhere):
//   node production/art-proof/0x72-style/export_rigs.js            runs the one rig build (node tools/rig_kit/build_rigs.js):
//        assets/data/rigs.json starts with this page's rigs, then come the rigs other steps add
//   node production/art-proof/0x72-style/export_rigs.js --check    the same as node tools/rig_kit/build_rigs.js --check
//   node production/art-proof/0x72-style/export_rigs.js --variants writes the variant candidates (VARIANTS in
//        the template) to production/qa/evidence/0x72-variants/rigs_variants.json, for the proofs only
//   node production/art-proof/0x72-style/export_rigs.js --with-variants  builds rigs.json WITH the variants
//        (only after the user approved them, AGENTS.md proof gate)
// The rig build requires this file and takes its rigs through rigKit(); then it writes nothing itself.
// Game-side edits made after the first export live here or in the template
// (bossParts), so a new export keeps them: the bosses' unbreakable parts
// (commit 3a29399), the void core's unbreakable flag and the Mimik (ae50f83),
// and the skeleton sword's item scale 0.6 (DEFS in the template). The rigs
// other tools merge into rigs.json (frost_*, the hell's 0x72 figures such as
// brandskelett and kettenschinder with their own item scales) are not built
// here: the rig build adds them after these (tools/rig_kit/hand_rigs/hell_0x72.json,
// tools/frost_dungeon/export_frost_rigs.js), so no run of this file drops them.
const fs = require("fs");
const path = require("path");

const here = __dirname, root = path.resolve(here, "..", "..", "..");
const template = fs.readFileSync(path.join(here, "full.template.html"), "utf8");
const start = template.indexOf("const SHIELD");
const end = template.indexOf("// Later worlds");
if (start < 0 || end < 0) throw new Error("rig definitions not found in the template");
const { SHIELD, DEFS, bossParts, GAME_BOSSES, ICE_STAFF, VARIANTS, VARIANT_ROSTER } = new Function(template.slice(start, end) +
  "\nreturn { SHIELD, DEFS, bossParts, GAME_BOSSES, ICE_STAFF, VARIANTS, VARIANT_ROSTER };")();
const voidData = JSON.parse(fs.readFileSync(path.join(here, "void.json"), "utf8"));
const args = process.argv.slice(2);
const RIGS_PATH = path.join(root, "assets", "data", "rigs.json");
const VARIANTS_PATH = path.join(root, "production", "qa", "evidence", "0x72-variants", "rigs_variants.json");

const S = "res://assets/sprites/0x72/";
const images = {
  knight: S + "knight_m_idle_anim_f0.png", elf: S + "elf_f_idle_anim_f0.png", wizard: S + "wizzard_m_idle_anim_f0.png",
  skelet: S + "skelet_idle_anim_f0.png", necro: S + "necromancer_anim_f0.png", tiny_zombie: S + "tiny_zombie_idle_anim_f0.png",
  ice_zombie: S + "ice_zombie_anim_f0.png", big_zombie: S + "big_zombie_idle_anim_f0.png",
  knight_sword: S + "weapon_knight_sword.png", rusty_sword: S + "weapon_rusty_sword.png", knife: S + "weapon_knife.png",
  red_staff: S + "weapon_red_magic_staff.png", green_staff: S + "weapon_green_magic_staff.png", bow: S + "weapon_bow.png", arrow: S + "weapon_arrow.png",
};
// Source frames of the variants (0x72 v1.7, CC0, copied unchanged). The pack
// names the zombie's frames f1/f2/f3/f10; only f10 stands on two legs.
const variantImages = {
  zombie: S + "zombie_anim_f10.png", masked_orc: S + "masked_orc_idle_anim_f0.png", doc: S + "doc_idle_anim_f0.png",
  goblin: S + "goblin_idle_anim_f0.png", orc_shaman: S + "orc_shaman_idle_anim_f0.png", ogre: S + "ogre_idle_anim_f0.png",
  big_demon: S + "big_demon_idle_anim_f0.png", elf_m: S + "elf_m_idle_anim_f0.png", chort: S + "chort_idle_anim_f0.png",
  wogol: S + "wogol_idle_anim_f0.png", orc_warrior: S + "orc_warrior_idle_anim_f0.png", pumpkin: S + "pumpkin_dude_idle_anim_f0.png",
  spear: S + "weapon_spear.png", waraxe: S + "weapon_waraxe.png",
};
const copy = (value) => JSON.parse(JSON.stringify(value));

const rigs = {};
for (const [name, def] of Object.entries(DEFS)) {
  if (name === "lizard") continue; // later class, preview only
  rigs[name] = copy(GAME_BOSSES.includes(name) ? bossParts(def) : def);
}
// How each hero figure holds the weapon its hero carries in play (a game-side
// edit; the page draws the DEFS items): the weapon item's "held" block, read by
// src/rig_kit/rig_held.gd, the art moved by its style in src/hero/hero_look.gd.
// hand: the shoulder in figure px on the item's parent, 0.45 of the 28 px frame
// above the feet (where the story worlds always held the weapon); grip and tip:
// shares of the held art; staff: side (figure px from the shoulder toward the
// facing side) and length (figure px). See src/rig_kit/rig_held.gd for every key.
const HERO_HELD = {
  knight: { style: "sword", hand: [8, 14.4], grip: [0.5, 0.9], tip: [0.5, 0], rest: 0, scale: 1 },
  elf: { style: "bow", hand: [7, 14.4], grip: [0.5, 0.5], rest: 0, scale: 1 },
  wizard: { style: "staff", hand: [8, 14.4], side: [5, 0], length: 18, grip: [0.5, 0.35], tip: [0.5, 0.1111111111111111], rest: 0, scale: 1 },
};
for (const [name, held] of Object.entries(HERO_HELD)) {
  const weapon = ((rigs[name] && rigs[name].items) || []).find((item) => item.id === "weapon");
  if (!weapon) throw new Error(`export_rigs.js: the hero rig ${name} has no weapon item to hold its weapon`);
  weapon.held = copy(held);
}
const out = {
  _note: "Generated by production/art-proof/0x72-style/export_rigs.js from the approved review page. Rects are inclusive [x0,y0,x1,y1] on the source frame; each opaque pixel belongs to the first part whose rect contains it. Part hp values are weights: the game scales them so the parts sum to the enemy's HP. An item's optional scale (default 1) draws it that much smaller than its sprite, snapped so one item pixel is a whole number of world px (src/rig/rig_library.gd item_factor): skeleton 0.6 brings the rusty sword (21 px) to the body's height (14 px), one sword pixel = 3 world px at the Krypta's 5; brandskelett 0.75 and kettenschinder 0.65 do the same at 4 and 4.8 world px per source px.",
  images,
  pixel_art: { shield: { palette: SHIELD.palette, rows: SHIELD.rows } },
  // Size factor on top of the 2x pixel scale (user, 2026-10-28: bosses 3x).
  scales: { void: 3, big_zombie: 3, frost_corpse: 3, bone_colossus: 3 },
  rigs,
  void: {
    frames: [0, 1, 2, 3, 4, 5, 6, 7].map((i) => `res://assets/sprites/void/void_body_f${i}.png`),
    frame: voidData.frame, palette: voidData.palette, claw_left: voidData.claw_left, claw_pivot: voidData.claw_pivot,
    claw_tip: voidData.claw_tip, shoulder_left: voidData.shoulder_left, eye: voidData.eye, skull: voidData.skull,
    // The core never breaks: only the total HP kills the Leerenrufer (3a29399).
    parts: { core: { hp: 90, label: "Leerenkern", unbreakable: true }, eye: { hp: 20, label: "Leerenauge", disables: "beam", regrow: 12, exposed: "beam" },
      claw_l: { hp: 15, label: "Hintere Klaue", disables: "summon", regrow: 8 }, claw_r: { hp: 15, label: "Vordere Klaue", disables: "cast", regrow: 8 } },
  },
  bomber: {
    frames: [0, 1, 2, 3, 4, 5, 6, 7].map((i) => `res://assets/sprites/void/void_bomber_f${i}.png`),
    fps: voidData.bomber.fps, ground: [8, 15], width: 8,
    parts: { skull: { hp: 1, label: "Schädel", vital: true } },
  },
  // Added with the Dungeon-Werkstatt (ae50f83), not from the review page.
  mimic: {
    _note: "Mimik: a 0x72 chest that bites (chest_mimic_open_anim). frames: 0 closed (same as a normal chest), 1 teeth, 2 open mouth. The pose (rig_poses.gd mimic) hops and chomps.",
    frames: [0, 1, 2].map((i) => `res://assets/sprites/0x72/chest_mimic_open_anim_f${i}.png`),
    fps: 8, ground: [8, 15], width: 8,
    parts: { body: { hp: 1, label: "Truhe", vital: true } },
  },
};

// Size factors of the variants (crypt default 1, brutes 3; Frostgruft and
// Hell-Dungeon proposals so the hit areas match their drawn size).
const variantScales = Object.fromEntries(Object.entries(VARIANT_ROSTER).filter(([, r]) => r.scale).map(([name, r]) => [name, r.scale]));
function withVariants(base) {
  const result = copy(base);
  Object.assign(result.images, variantImages);
  result.pixel_art.ice_staff = { palette: ICE_STAFF.palette, rows: ICE_STAFF.rows };
  Object.assign(result.scales, variantScales);
  for (const [name, def] of Object.entries(VARIANTS)) {
    if (result.rigs[name]) throw new Error(`variant ${name} clashes with an existing rig`);
    result.rigs[name] = copy(def);
  }
  return result;
}

// Deep comparison with key order; returns the paths that differ.
function differences(a, b, at = "", found = []) {
  if (typeof a !== typeof b || Array.isArray(a) !== Array.isArray(b) || (a === null) !== (b === null)) { found.push(at || "/"); return found; }
  if (a === null || typeof a !== "object") { if (a !== b) found.push(at || "/"); return found; }
  const ka = Object.keys(a), kb = Object.keys(b);
  if (!Array.isArray(a) && ka.join(",") !== kb.join(",")) found.push(`${at}/{keys: ${ka.join(",")} vs ${kb.join(",")}}`);
  for (const key of new Set([...ka, ...kb])) {
    if (!(key in a) || !(key in b)) { if (Array.isArray(a)) found.push(`${at}/${key}`); continue; }
    differences(a[key], b[key], `${at}/${key}`, found);
  }
  return found;
}

/**
 * The rig build's first step of rigs.json (tools/rig_kit/build_rigs.js, assets/data/rig_manifest.json):
 * this page's rigs, with the variants too when ctx.options.withVariants. Nothing written.
 */
function rigKit(ctx) {
  if (ctx.data) throw new Error("export_rigs.js: this page's rigs start rigs.json (make them its first step)");
  return { data: ctx.options && ctx.options.withVariants ? withVariants(out) : copy(out), files: [] };
}

module.exports = { out, withVariants, differences, rigKit };

if (require.main !== module) {
  // required by the rig build: it takes the rigs through rigKit()
} else if (args.includes("--variants")) {
  // Variants only (plus every image key), so a test can load them next to rigs.json.
  const candidates = withVariants({ ...out, rigs: {} });
  delete candidates.void; delete candidates.bomber; delete candidates.mimic;
  candidates._note = "CANDIDATES, not in the game: 0x72 enemy and boss variants for the proofs (production/qa/evidence/0x72-variants). Generated by production/art-proof/0x72-style/export_rigs.js --variants from VARIANTS in full.template.html; same schema as assets/data/rigs.json.";
  candidates.scales = variantScales;
  candidates.roster = VARIANT_ROSTER;
  fs.mkdirSync(path.dirname(VARIANTS_PATH), { recursive: true });
  fs.writeFileSync(VARIANTS_PATH, JSON.stringify(candidates, null, 1) + "\n");
  console.log("VARIANTS", Object.keys(VARIANTS).join(","));
} else {
  // rigs.json holds more than this page (the Hölle's hand rigs, the Frostgruft's cuts at
  // RIGS_PATH): the one rig build writes or checks it whole, this page's rigs first
  const build = require(path.join(root, "tools", "rig_kit", "build_rigs.js"));
  process.exitCode = build.main(args.filter((a) => a === "--check" || a === "--with-variants"));
}

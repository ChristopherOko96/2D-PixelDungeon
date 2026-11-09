extends Node2D
const CutoutMotion=preload("res://src/rig/cutout_motion.gd")
## Hell-Dungeon mode (single player): plays the ten baked hell floors from
## assets/data/hell_floors.json. Combat rooms lock until every enemy is down,
## colour keys open their own gates, spread fire braziers open the vault,
## sequence plates conjure a reward chest, a skull heap shot three times opens
## a secret corridor, demon seals bless the hero or release demons, pits throw
## the hero back to the start, the floor-9 boss grants the clone skill (Q), and
## the portal leads one floor deeper.
## The hero is a placeholder. Without a theme of their own enemies, monsters, bosses
## and Ignaroth run in hell_monsters.gd; values come from hell_balance.json and
## hell_monsters.json.

const FloorData = preload("res://src/hell/hell_floor_data.gd")
const Walls = preload("res://src/hell/hell_walls.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
const Monsters = preload("res://src/hell/hell_monsters.gd")
const RoomContents = preload("res://src/world_kit/room_contents.gd")
const DrakeRigHost = preload("res://src/hell/drake_rig_host.gd")
const FrostRigs = preload("res://src/hell/frost_rigs.gd")
const FrostFx = preload("res://src/hell/frost_fx.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
const Gas = preload("res://src/vfx/gas.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")
const StoryElements = preload("res://src/hell/story_elements.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const MobRules = preload("res://src/hell/mob_rules.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const SubKit = preload("res://src/hell/sub_kit.gd")
const StoryFeel = preload("res://src/hero/story_feel.gd")
const StorySound = preload("res://src/hero/story_sound.gd")
const FrostCombat = preload("res://src/hell/frost_combat.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentRules = preload("res://src/progress/talent_rules.gd")
const SoulDrops = preload("res://src/progress/soul_drops.gd")
const HellTalents = preload("res://src/hell/hell_talents.gd")
const FrostHud = preload("res://src/hell/frost_hud.gd")
## How far a gate's front picture stands below its cells.
const GATE_FOOT := 8.0
const HEART := "res://assets/sprites/0x72/ui_heart_%s.png"
const Sfx = preload("res://src/vfx/sfx.gd")
const Music = preload("res://src/audio/music.gd")
const SaveStore = preload("res://src/save/save_store.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const StoryHero = preload("res://src/hero/story_hero.gd")
const MageBolt = preload("res://src/vfx/mage_bolt.gd")
const ShotLooks = preload("res://src/vfx/shot_looks.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
## The crypt's darkness and bloom in this world (src/hero/story_glow.gd).
const StoryGlow = preload("res://src/hero/story_glow.gd")
const Darkness = preload("res://src/vfx/darkness.gd")
const Snowstorm = preload("res://src/vfx/snowstorm.gd")
const FireAnim = preload("res://src/vfx/fire_anim.gd")
const GoldLoot = preload("res://src/hell/gold_loot.gd")
const LoadingScreen = preload("res://src/ui/loading_screen.gd")
const FrostSnow = preload("res://src/hero/frost_snow.gd")
const StorySave = preload("res://src/save/story_save.gd")
const RewardRules = preload("res://src/progress/reward_rules.gd")
const StoryProgress = preload("res://src/progress/story_progress.gd")
## The crypt's pause menu, in its story mode (overview, quest, map, controls, display, save).
const PauseMenu = preload("res://src/pause_menu.gd")
## The pause page's controls in groups: a blank line between groups, each
## group's header in capitals on its first line, then "Aktion: Taste" lines
## (story_controls adds the card line when the run hands out cards).
const STORY_CONTROLS := "BEWEGEN\nLaufen: WASD\nAusweichen / Block: Shift\n\nKAMPF\nAngreifen: Linksklick / Pfeile\nFähigkeiten: 1 2 3 4\nUltimate: R\nBegleiter: 5 6\nAuto an / aus: Rechtsklick auf 5 6\nWaffe / Relikt: T\nKlon: Q\nSchnelltrank: H trinken · G werfen\nRüstungskraft: F\n\nWELT\nBenutzen: E / Leertaste\nLicht: L\n\nFENSTER\nMenü: Esc\nInventar: I\nTalente: K\nLauf-Talente: B\nKarte: M\nStatus: C oder Tab\nNeuer Lauf: E nach dem Tod"
const DARKNESS_SHADER := preload("res://assets/shaders/canvas_vfx_darkness.gdshader")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const SkillBar = preload("res://src/ui/skill_bar.gd")
const TalentScreenScript = preload("res://src/ui/talent_screen.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const GraphicsSettings = preload("res://src/core/graphics_settings.gd")
const RunTree = preload("res://src/progress/run_tree.gd")
const RunTreeView = preload("res://src/ui/run_tree_view.gd")
const StoryItems = preload("res://src/hero/story_items.gd")
const InventoryPanel = preload("res://src/ui/inventory_panel.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
## The camera's lead, fight framing, zoom breathing, punch and kick (src/hell/story_camera.gd).
const StoryCamera = preload("res://src/hell/story_camera.gd")
const StoryPresentation = preload("res://src/hell/story_presentation.gd")
var presentation := StoryPresentation.new()
var _camera_written := Vector2.INF
## The world kit (src/world_kit): a world with theme.world_pack builds every floor live from the
## run number instead of reading baked floors (Story 1 the crypt, Story 3 the hell).
const WorldPack = preload("res://src/world_kit/world_pack.gd")
const WorldRoomWorld = preload("res://src/world_editor/world_room_world.gd")
const WorldRoomData = preload("res://src/world_editor/world_room_data.gd")
const WorldTerrain = preload("res://src/world_editor/world_terrain.gd")
const LaunchPads = preload("res://src/hell/launch_pads.gd")
const FrostPuzzles = preload("res://src/world_kit/frost_puzzles.gd")
const HellPuzzles = preload("res://src/world_kit/hell_puzzles.gd")
const RoomWeather = preload("res://src/world_kit/room_weather.gd")
const StoryWreck = preload("res://src/hell/story_wreck.gd")
const StoryMotionHost = preload("res://src/hell/story_motion_host.gd")
const StoryExposureHost = preload("res://src/hell/story_exposure_host.gd")
const FixedStepClock = preload("res://src/physics_kit/fixed_step_clock.gd")
const StoryEnemyIndex = preload("res://src/physics_kit/story_enemy_index.gd")
var _mob_space := StoryEnemyIndex.new(C)
const CustomStoryData = preload("res://src/custom/custom_story_data.gd")
const CustomStoryWorld = preload("res://src/custom/custom_story_world.gd")
const BALANCE_PATH := "res://assets/data/hell_balance.json"
const HERO := "res://assets/sprites/0x72/%s_%s_anim_f%d.png"
const WEAPON := "res://assets/sprites/0x72/%s.png"
const MENU_SCENE := "res://src/main.tscn"
const C := 96.0
const CHUNK := Vector2i(14, 11)
## The hell look and wording. A theme file (theme_path, e.g. assets/data/frost_theme.json)
## overrides any top-level key; colours are "#rrggbb" or [r, g, b(, a)] (above 1 brightens).
const THEME_DEFAULT := {
	# hell look in the 0x72 pixel style (scripts/make_hell_skin.gd); the first painted set is assets/sprites/hell/
	"floors": "res://assets/data/hell_floors.json", "sprites": "res://assets/sprites/hell_0x72/", "balance": BALANCE_PATH,
	"pixel": true, "pixel_tiles": true, "hero_scale": 3.0, "key_in_chest": false, "placeholder_note": true,
	# graphics sets for the Pixel / HD switch (src/core/graphics_settings.gd): keys that replace the ones above;
	# a theme file names its own sets (or none: then its one look stays)
	"skins": {
		"pixel": {"sprites": "res://assets/sprites/hell_0x72/", "pixel": true, "pixel_tiles": true, "hero_scale": 3.0},
		"hd": {"sprites": "res://assets/sprites/hell/", "pixel": false, "pixel_tiles": false, "hero_scale": 3.6}},
	"liquid": {"hurt": true, "slow": -1.0, "slide": false, "grip": 1.0},
	"keys": {
		"A": {"name": "Glutschlüssel", "hint": "fällt in einem Seitenraum vor dem Tor.", "color": "#ff8a3c", "tint": [1, 1, 1], "sprite": "key"},
		"B": {"name": "Knochenschlüssel", "hint": "liegt auf einem Altar oder fällt in einem Seitenraum.", "color": "#e8dccb", "tint": [1.55, 1.5, 1.4], "sprite": "key"},
		"C": {"name": "Dämonenschlüssel", "hint": "fällt in einem Kampfraum nahe dem Bosstor.", "color": "#b07cff", "tint": [0.75, 0.5, 1.7], "sprite": "key"}},
	"words": [],
	"colors": {"ink": "#f1e4d8", "accent": "#ff6b2c", "gold": "#ffd2a8", "sub": [1, 0.6, 0.35], "warn": "#ff6b4a", "prompt_key": "#ffb36b",
		"shot_glow": [1, 0.55, 0.2, 0.45], "shot_core": [1, 0.95, 0.75], "eshot_glow": [0.8, 0.1, 0.08, 0.5], "eshot_core": [1, 0.75, 0.7],
		"ember": "#ffb347", "ember_big": "#ff7a2a", "ember_gold": "#ffe28a", "shade": [0.05, 0.01, 0.02], "shade_grade": [0.32, 0, 0],
		"grade": [0.55, 0.04, 0.0], "vignette": [0.35, 0, 0], "vignette_glow": [0.4, 0, 0], "boss_back": "#3a1210", "boss_bar": "#e8432a",
		"map_here": "#7a2e1c", "map_cleared": "#3d262a", "map_seen": "#5a1f1a", "map_edge_seen": "#9a6a5c", "map_edge": "#6d4c52", "door": "#7a5552",
		"mob_gross": [0.9, 0.6, 0.5], "mob_spucker": [0.75, 0.55, 1.6], "mob_boss": [1.2, 0.55, 0.45], "mob_boss_final": [0.6, 0.45, 1.6]},
}

## Floor to open first; set before the node enters the tree (debug starts).
@export var start_floor := 1
## Debug start right inside the boss room of start_floor; the fight begins at once.
@export var start_at_boss := false
## Theme JSON over THEME_DEFAULT; empty keeps the hell look.
@export var theme_path := ""
## A user-authored story uses this runtime and the selected current world's assets.
@export var custom_story: Dictionary = {}
## Nonempty tests this unsaved module directly; it has no normal save slots.
@export var custom_preview_room: String = ""
## A Weltbauer room to play instead of a generated floor; world_room_path: its file, read anew by F9.
@export var world_room: Dictionary = {}
@export var world_room_path: String = ""
## A run started from an unsaved editor draft returns to that draft, not just its list.
@export var custom_return_to_editor: bool = false
## Tests may redirect all Custom files to their own disposable directory.
var custom_storage_root: String = ""
var _custom_load_failed: bool = false

## Story gameplay advances in fixed ticks; drawing still follows display frames.
var _simulation_clock: FixedStepClock = FixedStepClock.new()
## A floor load or paused frame is deliberately excluded from the next time sample.
var _skip_simulation_delta: bool = true
## Hero class from theme.classes (menu choice); empty takes theme.default_class.
@export var class_id := ""
## A loaded save (src/save/story_save.gd): set before the node enters the tree to continue on its floor.
var resume: Dictionary = {}
## A hero who finished the story before this one (src/progress/story_progress.gd): set before the node enters
## the tree, the run starts on floor 1 with everything that hero carried (docs/BEUTEORDNUNG.de.md 1.2).
var carry_hero: Dictionary = {}
## A debug run (main menu DEBUG, STORY (DEBUG) and the level choice): no save slots, no story progress.
var debug_run := false
## Debug Testraum (src/debug/story_testraum.gd): its settings, set before the node enters
## the tree. Non-empty: floor 1 becomes one test room with the debug panel under the
## mini-map and the Testraum's own profile file; empty plays the story.
var testraum: Dictionary = {}
const TESTRAUM_SCRIPT := "res://src/debug/story_testraum.gd"
## Debug Testraum input hooks (src/debug/story_testraum.gd): mouse_taken while
## one of its floor tools is armed or the mouse is over its panel (the left
## button never attacks then); keys_taken while its search field is typed in
## (no walking, no arrow-key attacks).
var mouse_taken := false
var keys_taken := false
## Debug Testraum hook (src/debug/story_testraum_tools.gd damage numbers):
## called with each hit of the hero's weapon (monster, damage, crit).
var on_hero_hit := Callable()
## The save record of the floor start (written into a slot from the pause menu).
var floor_save: Dictionary = {}
var saves := SaveStore.new()
var pause_menu: Control
## The crypt's hero look, shots and sword feel (src/hero/story_hero.gd).
var story_hero: RefCounted
var _resuming := false
## The save slot this run writes its floor starts to (0: none yet; set by saving or loading).
var run_slot := 0
## Item system 2 in this world: the bag, four equipment slots, finds (src/hero/story_items.gd).
var story_items: Node
## The shared inventory window (key I) and a potion armed for throwing (-1: none).
var inventory_panel: Control
var throw_slot := -1

var theme: Dictionary = {}
var key_name: Dictionary = {}
var key_hint: Dictionary = {}
var key_color: Dictionary = {}
var key_tint: Dictionary = {}
var key_sprite: Dictionary = {}
var ink := Color.WHITE
var accent := Color.WHITE
var gold := Color.WHITE
## The chosen class (theme.classes entry) and its weapon; empty in hell.
var hero: Dictionary = {}
var weapon: Dictionary = {}
var weapon_tex: Texture2D
var arrow_tex: Texture2D
## The sword's last swing for drawing: angle, time left.
var swing := {"a": 0.0, "t": 0.0}

var balance: Dictionary = {}
var floors_raw: Array = []
## The world pack of a generated world (theme.world_pack); null for baked floors.
var world: RefCounted
## The Sprungplatten of the floor (src/hell/launch_pads.gd).
var launch_pads: RefCounted
## The Frostgruft's puzzle pieces (src/world_kit/frost_puzzles.gd).
var frost_puzzles: RefCounted
## The hell's puzzle pieces (src/world_kit/hell_puzzles.gd).
var hell_puzzles: RefCounted
## The weather of the hero's room, drawn over the picture (src/world_kit/room_weather.gd).
var room_weather: RefCounted = RoomWeather.new()
## Floor choice of the hidden stairs (key 1-9), open while not empty.
var stairs_pick: Dictionary = {}
var tex: Dictionary = {}
var hero_frames: Dictionary = {}
var W: Dictionary = {}
## The graphics set in use ("pixel" / "hd", src/core/graphics_settings.gd).
var graphics := "pixel"
## Where the graphics choice is stored (tests use their own file).
var graphics_path := GraphicsSettings.SETTINGS_PATH
var walls: Dictionary = {}
var state: Dictionary = {}
var player: Dictionary = {}
var mobs: Array = []
var shots: Array = []
var eshots: Array = []
var embers: Array = []
## Sloshes of the lava pools owed (hell_balance.json monsters.feel.lava slosh_rate).
## The world's gas layer (src/vfx/gas.gd): poison clouds, breath, fumes.
var gas: RefCounted = null
## What the hero stands in right now (src/combat/element_rules.gd, _step_elements):
## the medium's rule ({} on firm floor), its style, the gas rule and material, and
## the ticks of their hurt.
var hero_medium: Dictionary = {}
var hero_medium_style := ""
var hero_gas: Dictionary = {}
var hero_gas_mat := ""
var _medium_tick := 0.0
var _gas_tick := 0.0
## The motion kit of this world (motion_kit(); src/physics_kit/motion_kit.gd).
var _motion: MotionKit = null
## The element exposure of this world (exposure(); src/physics_kit/element_exposure.gd).
var _exposure: ElementExposure = null
## The view inside gas (element_rules.json vision; src/hero/story_glow.gd frame
## darkens the world outside it): k = how closed it is 0..1, r = world px it
## keeps open round the hero, goal = what the gas asks for, probe = s to the
## next measurement of the cloud's reach.
var vision := {"k": 0.0, "r": 0.0, "goal": 0.0, "probe": 0.0, "mat": ""}
## The element reactions of this world (src/hell/story_elements.gd: fire on poison, water, ice).
var story_elements: RefCounted = null
var lava_slosh := 0.0
## Bubbles on the lava floor ({p, t, T, big}; _bubble_lava) and the spawn carry.
var lava_bubbles: Array = []
var lava_bubble_due := 0.0
## Telegraphed boss areas: icicle targets, chill fields, landing marks, safe circles.
var zones: Array = []
## Class skills (hero_skills.json, scaled) and their running parts: a held skill,
## a dash, short effects, the level-up flash, gravity walls and bars.
var skills: Array = []
var hold: Dictionary = {}
var dash: Dictionary = {}
## How dark the labyrinth around the hero is now (0 outside a maze zone, 1 deep inside; world_maze.json).
var maze_dark := 0.0
const MAZE_PATH := "res://assets/data/world_maze.json"
var fx: Array = []
var levelfx: Dictionary = {}
var gwalls: Array = []
var gbars: Array = []
var bar_drag: Dictionary = {}
## Fixed aim point for skills instead of the mouse (tests, debug); null = mouse.
var aim_at: Variant = null
var relic_tex: Texture2D
## Relic summons and timed relic blows (rock lifts, rock spikes, meteors, quakes).
var allies: Array = []
## Talent trees and soul crystals (theme.talents, src/hell/meta_store.gd); empty without talents.
var meta_data: Dictionary = {}
var meta: Dictionary = {}
## Where the soul crystals are saved (tests use their own file).
var meta_path := MetaStore.SAVE_PATH
## The shared lasting profile (src/progress/profile.gd): EXP, gold, soul shards.
var profile_data: Dictionary = {}
var profile: Dictionary = {}
var profile_path := Profile.default_path()
## Identifies this run in boss completion ids, so a restart never repeats one.
var _run_uid := ""
## What the last floor brought, for the floor banner.
var _floor_reward := ""
## The shared talent trees in this map (src/hell/hell_talents.gd); null without a profile.
var talents: HellTalents
## The run's subclass kit (src/hell/sub_kit.gd); empty for the standard subclass.
var sub_kit: Dictionary = {}
## The crypt's game feel (src/hero/story_feel.gd running src/vfx/feedback.gd); null in a world without theme.feel.
var feel: StoryFeel
## The crypt's sound routing next to the feel (src/hero/story_sound.gd); null without theme.feel.
var sound: StorySound
var pending: Array = []
## Hearts of the HUD (0x72 full, half, empty).
var hearts: Dictionary = {}
var sfx: Node
var music: Node
var _music_state := ""
var breakables: Array = []
## The breakables by the cells (C px) their boxes touch, Vector2i cell -> [breakable, ...]
## (_index_breakables, made in load_floor): box_blocked tests only the ones there. Only
## read afterwards (worker threads shaping pools ask box_blocked too).
var _breakable_grid: Dictionary = {}
## The breakables list the grid was made from and its size then: for another list, or one
## grown since (a test adds a crate), box_blocked looks through all of them as before.
var _breakable_grid_of: Array = []
var _breakable_grid_n := -1
## Nothing in a cell (the grids' default; read only).
const _NOTHING: Array = []
## Light destruction: wall wear and smashable props (src/hell/story_wreck.gd); with the feel only.
var wreck: RefCounted
var pits: Array = []
var clone: Dictionary = {}
var solid_grid: Dictionary = {}
var door_at: Dictionary = {}
var minimap: Array = []
var camera: Camera2D
## Drives the camera each frame (src/hell/story_camera.gd, assets/data/story_camera.json).
var cam_rig: RefCounted
## The options file the camera and the pause read (probes point it at a test file).
var settings_path := GraphicsSettings.SETTINGS_PATH
var _shake_was := 0.0
var actors: Layer
## The crypt's darkness (src/vfx/darkness.gd); src/hero/story_glow.gd lights it.
var dark: Node2D
## The light snowstorm over the whole screen of a world with theme "snowstorm" (src/vfx/snowstorm.gd); null elsewhere.
var snowstorm: Node2D
## The burning fires and the flowing fountain water of the loaded set (src/vfx/fire_anim.gd).
var fire_anim := FireAnim.new()
## The gold in the world: thrown coins and bags, the magnet, the rising '+N' (src/hell/gold_loot.gd).
var gold_loot: GoldLoot
## The loading screen in front of the world while one shows (src/ui/loading_screen.gd); the world
## waits behind it. Off in test runs and debug jumps unless loading_forced says otherwise.
var loading_screen: LoadingScreen
## True: loading screens also in a script run (their own test and captures).
var loading_forced := false
## The variant of the next screens (captures); empty: rolled.
var loading_variant := ""
## The hints shown so far in this game, so none comes twice before its pool has been through.
var _hints_seen: Array = []
var _no_loading_once := false
var _leaving := false
## Footprints in the snow and sliding on glaze ice in a world with theme "snow" (src/hero/frost_snow.gd); null elsewhere.
var frost_snow: RefCounted
## The crypt's bloom over the darkness and the darkness's lights (src/hero/story_glow.gd).
var story_glow: StoryGlow
## Additive layer for attack glows and enemy shots of the hell monsters (under the
## darkness, like the crypt's bullets; their bloom is story_glow's).
var glow: Layer
var hostile_shots: Layer
## The hell monsters (hell_monsters.gd); null in a themed world with its own enemies.
var monsters: Monsters
## Ignaroth's part rig (src/hell/drake_rig_host.gd): body parts, part hits, rig drawing; null without monsters.
var drake_rig: DrakeRigHost
## The Frostgruft's enemies as the crypt's part rigs (src/hell/frost_rigs.gd, theme.rigs); null elsewhere.
var frost_rigs: FrostRigs
## The Frostgruft's attacks on the pixel grid with their feel and knockback (src/hell/frost_fx.gd, theme.vfx); null elsewhere.
var frost_fx: FrostFx
## The Hell's lava puddles as physics pools on the floor (src/vfx/pool_paint.gd,
## drawn in src/hero/story_feel.gd's floor layer); null without monsters.
var pools: RefCounted
var hud: Hud
## The talent menu opened mid-run with K; the world stands still while it is open.
var run_talents: Control
## The result panel's real buttons (mouse, pad) and what the last HUD frame drew:
## the panel's rectangle and the main button's label ("" = no buttons).
var result_ui: Control
var result_main: Button
var result_menu: Button
var _result_rect := Rect2()
var _result_label := ""
## True while a window (pause, map, inventory, talents, status) covers the HUD.
var _windows := false
var _chunk_nodes: Array = []
var _vignette: GradientTexture2D


## One drawing layer of the world; the game draws into it by kind.
## Named time totals for the story bench (scripts/bench_story.gd): two clock reads per part,
## nothing in the game reads them.
const PerfMarks = preload("res://src/debug/perf_marks.gd")


class Layer extends Node2D:
	var game: Node
	var kind := ""
	var area := Rect2()
	func _draw() -> void:
		game.draw_layer(self)


## Screen-space HUD: hearts, keys, banners, prompts, minimap and big map.
class Hud extends Control:
	var game: Node
	func _draw() -> void:
		game.draw_hud(self)


func _ready() -> void:
	# the story worlds keep the corner free: the map is on M and in the pause (ui_hud_style.json story_minimap)
	HudKit.map_corner = HudKit.rule("story_minimap", 0.0) > 0.0
	if not _configure_custom_story():
		return
	# the Testraum points the profile and soul-crystal files at its own before they load
	if not testraum.is_empty():
		var testraum_script: Variant = load(TESTRAUM_SCRIPT)
		testraum_script.prepare(self)
	_load_theme()
	balance = JSON.parse_string(FileAccess.get_file_as_string(theme.balance))
	launch_pads = LaunchPads.new(self)
	frost_puzzles = FrostPuzzles.new(self)
	hell_puzzles = HellPuzzles.new(self)
	if not world_room.is_empty():
		world = WorldRoomWorld.new(world_room)
		floors_raw = []
		floors_raw.resize(1)
	elif not custom_story.is_empty():
		world = CustomStoryWorld.new(custom_story, custom_preview_room)
		floors_raw = []
		floors_raw.resize(world.floor_count())
	elif theme.has("world_pack"):
		# a generated world: floors are built when entered (load_floor); only their number is known
		# world_sizes: the sprite sizes the generator reads (lights over props); a world with two graphics
		# sets names one, so both build the same floor from the same run number
		world = WorldPack.new(str(theme.world_pack), str(theme.get("world_sizes", str(theme.sprites) + "manifest.json")))
		floors_raw = []
		floors_raw.resize(world.floor_count())
	else:
		floors_raw = FloorData.load_all(theme.floors)
	_load_textures()
	var classes: Dictionary = theme.get("classes", {})
	if not classes.has(class_id):
		class_id = str(theme.get("default_class", ""))
	hero = classes.get(class_id, {})
	weapon = hero.get("weapon", {})
	if not weapon.is_empty():
		# 0x72 weapons by name; drawn ones by their path under assets/sprites (the necromancer's sceptre)
		weapon_tex = SubKit.weapon_texture(str(weapon.sprite))
		arrow_tex = load(WEAPON % "weapon_arrow")
	for kind in ["idle", "run"]:
		var frames: Array = []
		for f in range(4):
			frames.append(load(HERO % [hero.get("sprite", "knight_m"), kind, f]))
		hero_frames[kind] = frames
	# The theme's class skills stay loaded: a non-empty list marks a world with
	# levels, run tree and HUD. They are never cast or shown any more; keys 1-4
	# cast the learned talents (user decision 29.10.2026).
	skills = HeroKit.load_skills(self, class_id)
	if theme.has("feel"):
		feel = StoryFeel.new(self, theme.feel)
		# the rigs' falling chips and dust land in the world's particles (physics plan R18)
		RigFx.world_ref = weakref(feel.feedback.particles)
		RigFx.world_scale = float(feel.scale)
		sound = StorySound.new(self)
		wreck = StoryWreck.new(self)
	for k in ["full", "half", "empty"]:
		hearts[k] = load(HEART % k)
	# only the real game uses the player's lasting progress file; test and capture scripts
	# (their own SceneTree script) use their own meta_path or none
	var meta_allowed: bool = meta_path != MetaStore.SAVE_PATH or get_tree().get_script() == null
	if theme.has("talents") and FileAccess.file_exists(str(theme.talents)) and meta_allowed:
		meta_data = JSON.parse_string(FileAccess.get_file_as_string(str(theme.talents)))
		# The old soul crystals and subclass trees are replaced by the shared
		# talent trees (docs/TALENTE-SEELENSPLITTER.de.md): every class plays
		# its standard subclass here, and bought crystals lapse.
		meta = MetaStore.fresh(meta_data)
	profile_data = Profile.data()
	if not profile_data.is_empty(): profile = Profile.load_profile(profile_data, profile_path)
	_run_uid = "%d-%d" % [Time.get_unix_time_from_system(), randi()]
	if not (theme.get("sounds", {}) as Dictionary).is_empty():
		sfx = Sfx.new()
		add_child(sfx)
	if theme.get("music", false):
		music = Music.new()
		add_child(music)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if theme.pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * float(balance.view.base_width) / float(balance.view.width)
	add_child(camera)
	camera.make_current()
	cam_rig = StoryCamera.new()
	cam_rig.read_options(settings_path)
	if not theme.has("mobs"):
		monsters = Monsters.new(self, balance.monsters)
		pools = PoolPaint.new(PIXEL_WORLD, _floor_open)
		gas = Gas.new(PIXEL_WORLD, _floor_open)
		# drops of the puddles fly in the feel's particles (crypt units, x scale), blasts ring them
		if feel != null:
			pools.particles = feel.feedback.particles
			pools.to_particles = 1.0 / feel.scale
			# the lava tiles are hot floor: liquid on them hisses and crusts (drawing only); the
			# Krypta's Moder is cold (D3)
			pools.hot = func(p: Vector2) -> bool: return _floor_mat() == "lava" and feel.feedback.particles.sinks(p / feel.scale)
		# Ignaroth's part rig: tuning from balance.monsters.rigs (DrakeRigHost.DEFAULTS fill gaps)
		drake_rig = DrakeRigHost.new(balance.monsters, RigLibrary.shared())
		# figures that wear the crypt's part rigs (Story 1: krypta_monsters.json "rig")
		drake_rig.adopt_looks(monsters.defs)
		monsters.rig_host = drake_rig
	elif theme.has("rigs"):
		frost_rigs = FrostRigs.new(self, theme.rigs)
	if theme.has("vfx") and monsters == null:
		frost_fx = FrostFx.new(self, theme.vfx)
	actors = _layer("actors", 10)
	glow = _layer("glow", 11)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	story_hero = StoryHero.new(self)
	# the crypt's darkness and, over it, its bloom (src/hero/story_glow.gd)
	dark = Darkness.new()
	dark.z_index = 30
	add_child(dark)
	story_glow = StoryGlow.new(self)
	hostile_shots = _layer("hostile_shots", dark.z_index + 2)
	# the element reactions, the same in every story world (src/hell/story_elements.gd)
	story_elements = StoryElements.new(self)
	if theme.has("snow"):
		frost_snow = FrostSnow.new(self, theme.snow)
	# Ignaroth's rig hands its glow record (atlas box + rig points) to the bloom like hell_monsters.gd _mark()
	if drake_rig != null:
		drake_rig.glow_mark = story_glow.mark
	# soft red rim for deeper floors: clear centre, opaque white edge, tinted when drawn
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 1))
	ramp.add_point(0.55, Color(1, 1, 1, 0))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = ramp
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 1.05)
	_vignette.width = 256
	_vignette.height = 144
	var ui := CanvasLayer.new()
	# layer 2: the HUD and every window sit over the snowstorm (layer 1), which sits over the world
	ui.layer = 2
	add_child(ui)
	gold_loot = GoldLoot.new(self)
	# a world with a snowstorm (theme "snowstorm", the Frostgruft): snow over the world, under HUD and menus
	if theme.has("snowstorm"):
		var storm_layer := CanvasLayer.new()
		storm_layer.layer = 1
		add_child(storm_layer)
		snowstorm = Snowstorm.new()
		storm_layer.add_child(snowstorm)
		snowstorm.configure(theme.snowstorm)
	hud = Hud.new()
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	_build_result_buttons(ui)
	pause_menu = PauseMenu.new()
	pause_menu.theme = CryptUI.create_theme()
	ui.add_child(pause_menu)
	pause_menu.use_story_mode(story_controls(CardKit.offers_cards(self)))
	pause_menu.save_rows = func() -> Array: return saves.summaries(StorySave.mode(self))
	pause_menu.set_save_enabled(custom_preview_room.is_empty() and world_room.is_empty())
	pause_menu.story_map_draw = func(canvas: Control) -> void: _draw_map(canvas, canvas.size, true, true)
	pause_menu.resume_pressed.connect(func() -> void: pause_menu.visible = false)
	pause_menu.save_requested.connect(save_slot)
	pause_menu.leave_pressed.connect(_return_to_menu)
	pause_menu.display_mode_requested.connect(_toggle_fullscreen)
	# the pause's Talente / Inventar pages open the run's own windows; its options reach the camera
	pause_menu.talents_requested.connect(open_run_talents)
	# from the pause the character window comes back to the pause when it closes, and the run stays paused
	pause_menu.inventory_requested.connect(func() -> void:
		if inventory_panel != null and heroic():
			_open_character(true))
	pause_menu.option_changed.connect(func(key: String, value: Variant) -> void: cam_rig.set_option(key, value))
	if pause_menu.options_panel != null: pause_menu.options_panel.setup(settings_path)
	pause_menu.graphics_mode_requested.connect(func() -> void:
		apply_graphics(GraphicsSettings.other(graphics))
		pause_menu.set_graphics_state(GraphicsSettings.note(theme, graphics), graphics))
	if not resume.is_empty():
		# a loaded save: the floor starts with the carried values of that save
		state = (resume.get("keep", {}) as Dictionary).duplicate(true)
		run_slot = int(resume.get("slot", 0))
		_resuming = true
		load_floor(clampi(int(resume.get("floor", 1)), 1, floors_raw.size()), true)
		_resuming = false
		if _custom_load_failed: return
		_start_items(ui)
		return
	if not carry_hero.is_empty():
		# the hero of the story before: floor 1 of this world with all it carried, one chapter deeper
		state = (carry_hero.get("keep", {}) as Dictionary).duplicate(true)
		state.chapters_done = int(carry_hero.get("done", 1))
		state.run_id = _new_run_id()
		state.world_run = 0
		state.relic_floor = 0
		_resuming = true
		load_floor(1, true)
		_resuming = false
		if _custom_load_failed: return
		_start_items(ui)
		_toast("Dein Held geht weiter: Kapitel %d, Tiefe %d." % [int(state.chapters_done) + 1, depth()])
		return
	load_floor(clampi(start_floor, 1, floors_raw.size()), false)
	if _custom_load_failed: return
	_start_items(ui)
	if not custom_preview_room.is_empty():
		_start_custom_preview()
	if not world_room.is_empty():
		_start_world_room()
	if not testraum.is_empty():
		# one test room without the story; its panel mounts in the HUD layer
		var testraum_room: Variant = load(TESTRAUM_SCRIPT)
		testraum_room.mount(self, ui)
		return
	if start_at_boss:
		enter_boss_room()


## A selected combat module is playable immediately, after its start position exists.
func _start_custom_preview() -> void:
	if W.get("rooms", []).is_empty(): return
	var selected: Dictionary = W.rooms[0]
	var role := str(selected.get("preview_role", "start"))
	if role not in ["combat", "boss"]: return
	selected.type = role
	selected.cleared = false
	if role == "boss":
		for ent: Dictionary in W.ents:
			if ent.type == "portal": ent.active = false
	_start_fight(selected)


## A Weltbauer room in play: its placed monsters wake at once at their spots, its random ones
## through the usual fight; either way the gates fall until they are beaten.
func _start_world_room() -> void:
	var r: Dictionary = W.rooms[0]
	var placed: Array = r.get("placed_mobs", [])
	if placed.is_empty() and int(r.mobs) <= 0:
		return
	if placed.is_empty():
		_start_fight(r)
		return
	r.fight = true
	r.cleared = false
	for m: Dictionary in placed:
		var at := Vector2(float(m.x), float(m.y))
		if monsters != null and (monsters.defs as Dictionary).has(str(m.mob)):
			monsters.spawn(0, at, str(m.mob))
		elif theme.has("mobs") and (theme.mobs as Dictionary).has(str(m.mob)):
			_spawn_mob(0, at, str(m.mob))
	if mobs.is_empty():
		r.fight = false
		r.cleared = true
		return
	_toast("Die Gitter fallen. Besiege alle Gegner.")
	_sound("fight_start")


## Enemies come out of a chest or a broken piece of a Weltbauer room: at most max_enemies, each a kind of
## this world or "random" for one of the floor's. The room locks until they are beaten.
func release_room_enemies(ids: Array, at: Vector2, room: int) -> void:
	if room < 0 or room >= W.rooms.size():
		return
	var count := 0
	for id: Variant in ids.slice(0, int(RoomContents.cfg().get("max_enemies", 2))):
		var kind := _floor_enemy() if str(id) == "random" else str(id)
		# out in the very corridor of the piece, never in or behind a wall
		var spot := corridor_spot(room, at, count)
		if monsters != null and (monsters.defs as Dictionary).has(kind):
			var m: Dictionary = monsters.spawn(room, spot, kind)
			# in a labyrinth it chases only what it sees (hell_monsters.gd sight)
			if W.rooms[room].has("maze_zone"):
				m.sight = float(maze_cfg().get("monster_sight_cells", 6)) * C
			count += 1
		elif theme.has("mobs") and (theme.mobs as Dictionary).has(kind):
			_spawn_mob(room, spot, kind)
			count += 1
	if count == 0:
		return
	var r: Dictionary = W.rooms[room]
	r.fight = true
	r.cleared = false
	_toast("Gegner brechen hervor! Die Gitter fallen.")


## One of the floor's plain monsters; no chest monster, which would show itself without its chest.
func _floor_enemy() -> String:
	var roster: Array = []
	if monsters != null:
		roster = ((monsters.floors as Dictionary).get(str(state.floor), {}) as Dictionary).get("mobs", [])
	elif theme.has("mobs"):
		roster = (theme.mobs as Dictionary).keys()
	roster = roster.filter(func(id: Variant) -> bool: return not RoomContents.is_chest_mob(str(id)))
	return str(roster[randi() % roster.size()]) if not roster.is_empty() else ""


## What a chest or a smashed prop holds in a Weltbauer room: {type, id, amount}.
func world_room_drop(loot: Dictionary, at: Vector2, room: int) -> void:
	match str(loot.get("type", "none")):
		"random":
			match RoomContents.piece_drop(randf()):
				"gold": gold_loot.spew(at, int((RoomContents.cfg().get("random_piece", {}) as Dictionary).get("gold_amount", 3)))
				"heart": _drop("heart", room, at)
			if story_items != null: story_items.loot("crate", at)
		"gold": gold_loot.spew(at, int(loot.get("amount", 1)))
		"heart": _drop("heart", room, at)
		"key": _drop("key", room, at, {"key": str(loot.get("id", "A"))})
		"potion":
			if story_items != null: story_items.give(story_items.inventory.make_stack("potion", str(loot.get("id", "")), int(loot.get("amount", 1))), at)
		"crystal", "stone":
			if story_items != null: story_items.give(story_items.inventory.make_stack(str(loot.type), "", int(loot.get("amount", 1))), at)
		"weapon":
			if story_items != null: story_items.give(story_items.inventory.make_weapon(str(loot.get("id", "")), true, ""), at)


## A prop broke (src/hell/story_wreck.gd): what the Weltbauer put in it comes out, what it opens opens.
func world_room_smashed(p: Dictionary, at: Vector2) -> bool:
	var exact: bool = p.has("loot") or p.has("opens") or p.has("enemies")
	var room := _room_at_world(at.x, at.y)
	if p.has("loot"):
		world_room_drop(p.loot, at, maxi(room, 0))
	if p.has("enemies"):
		release_room_enemies(p.enemies, at, room)
	if str(p.get("opens", "")) != "" and W.groups.has(str(p.opens)) and not W.groups[str(p.opens)].solved:
		_solve_group(str(p.opens))
	return exact


## Selects the real story theme and isolates user content, slots and progression.
## Resumes use the embedded room revision, never a changed file with the same id.
func _configure_custom_story() -> bool:
	if not world_room_path.is_empty():
		world_room = WorldRoomData.load_file(world_room_path)
	if not world_room.is_empty():
		var room_problems := WorldRoomData.problems(world_room)
		if not room_problems.is_empty():
			_return_to_menu.call_deferred("Der Raum ist noch nicht spielbar: " + room_problems[0])
			return false
		theme_path = str(WorldRoomData.WORLDS[str(world_room.world)].theme)
		var as_story := {"id": "weltbauer_" + str(world_room.id)}
		saves = SaveStore.new(StorySave.custom_saves_dir(as_story, true, custom_storage_root))
		var hero_profile := profile_path
		profile_path = StorySave.custom_profile_path(as_story, true, custom_storage_root)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_path.get_base_dir()))
		Profile.save_profile(Profile.load_profile(Profile.data(), hero_profile), profile_path)
		meta_path = profile_path.trim_suffix(".json") + ".meta.cfg"
		return true
	if resume.get("custom_story") is Dictionary and not (resume.custom_story as Dictionary).is_empty():
		custom_story = (resume.custom_story as Dictionary).duplicate(true)
		custom_preview_room = str(resume.get("custom_preview_room", ""))
	if custom_story.is_empty(): return true
	var problems: Array[String] = CustomStoryData.validate(custom_story, custom_preview_room.is_empty())
	if not problems.is_empty():
		_return_to_menu.call_deferred("Die eigene Geschichte ist noch nicht spielbar: " + problems[0])
		return false
	var themes := {"krypta": "res://assets/data/krypta_theme.json", "frost": "res://assets/data/frost_theme.json", "hell": "res://assets/data/hell_theme.json"}
	theme_path = str(themes.get(str(custom_story.get("world", "krypta")), themes.krypta))
	var preview := not custom_preview_room.is_empty()
	saves = SaveStore.new(StorySave.custom_saves_dir(custom_story, preview, custom_storage_root))
	var source_profile := profile_path
	profile_path = StorySave.custom_profile_path(custom_story, preview, custom_storage_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_path.get_base_dir()))
	# Familiar learned talents are copied once, then all Custom progress stays separate.
	# A room preview gets a fresh copy each time and cannot earn into the main profile.
	if preview or not FileAccess.file_exists(profile_path):
		var copy := Profile.load_profile(Profile.data(), source_profile)
		Profile.save_profile(copy, profile_path)
	meta_path = profile_path.trim_suffix(".json") + ".meta.cfg"
	return true


## Returns to the Custom list/editor after a user run, or the usual title screen.
func _return_to_menu(error: String = "") -> void:
	if not custom_story.is_empty():
		get_tree().set_meta("custom_story_return", {"story_id": str(custom_story.get("id", "")),
			"edit": custom_return_to_editor or not custom_preview_room.is_empty() or not error.is_empty(), "room_id": custom_preview_room,
			"story": custom_story.duplicate(true), "error": error})
	if _leaving:
		return
	_leaving = true
	if loading_screen != null:
		loading_screen.queue_free()
	# the parade on the way back (src/ui/loading_screen.gd), while the menu loads in the background
	loading_screen = LoadingScreen.new()
	loading_screen.finished.connect(func(scene: PackedScene) -> void:
		if scene != null:
			get_tree().change_scene_to_packed(scene)
		else:
			get_tree().change_scene_to_file(MENU_SCENE))
	add_child(loading_screen)
	loading_screen.start_menu(MENU_SCENE)


## Item system 2 for a class hero (src/hero/story_items.gd): the bag and its window (I).
func _start_items(ui: CanvasLayer) -> void:
	if not heroic():
		return
	story_items = StoryItems.new(self)
	add_child(story_items)
	story_items.start(absi(hash(str(state.get("run_id", "")))) % 1000000)
	inventory_panel = InventoryPanel.new()
	ui.add_child(inventory_panel)
	inventory_panel.acted.connect(func(action: String, value: int) -> void: story_items.act(action, value))
	inventory_panel.throw_armed.connect(func(slot: int) -> void:
		# a throw goes to the world, not back to the pause
		_character_from_pause = false
		throw_slot = slot)
	inventory_panel.closed.connect(func() -> void:
		if _character_from_pause:
			_character_from_pause = false
			open_pause())
	inventory_panel.quick_chosen.connect(func(slot: int) -> void: story_items.set_quick(slot))
	# the bag's notes join the one message channel; its chip shows only when it matters
	inventory_panel.noted.connect(_toast)
	inventory_panel.auto_hide_chip = true
	inventory_panel.set_view(story_items.view())


## THEME_DEFAULT with the theme file's keys on top, then the key and colour lookups.
func _load_theme() -> void:
	theme = THEME_DEFAULT.duplicate(true)
	if theme_path != "" and FileAccess.file_exists(theme_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(theme_path))
		if parsed is Dictionary and parsed.has("hero_from"):
			# shared hero systems (classes, leveling, skills, relics, cards) from another theme
			var shared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(parsed.hero_from)))
			for k: String in parsed.get("hero_keys", []):
				if shared.has(k):
					theme[k] = (shared[k] as Variant)
		if parsed is Dictionary:
			# a world with its own sprites names its own graphics sets (none: its one look stays,
			# no hell sets); a theme without own sprites (the hell's) keeps the hell sets
			if parsed.has("skins") or parsed.has("sprites"):
				theme.skins = parsed.get("skins", {})
			for k: String in parsed:
				if k == "skins":
					continue
				if parsed[k] is Dictionary and theme.get(k) is Dictionary:
					(theme[k] as Dictionary).merge(parsed[k], true)
				else:
					theme[k] = parsed[k]
	# the chosen Pixel / HD set (src/core/graphics_settings.gd)
	graphics = GraphicsSettings.mode(graphics_path)
	theme.merge(GraphicsSettings.skin(theme, graphics), true)
	for k: String in theme.keys:
		var spec: Dictionary = theme.keys[k]
		key_name[k] = spec.name
		key_hint[k] = spec.hint
		key_color[k] = _color(spec.color)
		key_tint[k] = _color(spec.tint)
		key_sprite[k] = spec.sprite
	ink = col("ink")
	accent = col("accent")
	gold = col("gold")


static func _color(v: Variant) -> Color:
	if v is String:
		return Color(v)
	var a: Array = v
	return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)


## Plays the sound the theme maps to a game event (theme.sounds); silent without
## sounds. `category` overrides the event's mix group (assets/data/audio_mix.json).
## With the feel, the crypt's feedback.gd plays the combat moments itself and
## src/hero/story_sound.gd drops what it would play twice.
func _sound(event: String, category := "") -> void:
	if sound != null and sound.theme_event(event, category): return
	var name := str(theme.get("sounds", {}).get(event, ""))
	if name != "" and (sound == null or sound.keep_event(event)):
		_play_sfx(name, category)


## Plays an audio_sfx.json event directly (skills name their own). While the
## hero acts (as_hero) it plays at the hero's mix level, like the crypt's skill casts.
func _sound_raw(name: String, category := "") -> void:
	if sound != null:
		if not sound.keep_raw(name):
			return
		if category == "":
			category = sound.raw_category()
	_play_sfx(name, category)


func _play_sfx(name: String, category := "") -> void:
	if sfx != null and name != "" and sfx.has_effect(name):
		sfx.play(name, 0.08, category)


## Runs `action` (a kit's call) with its direct sounds counted as `who`'s
## (src/hero/story_sound.gd source: "hero", "moves", "kit"); returns its result.
func as_source(who: String, action: Callable) -> Variant:
	if sound == null:
		return action.call()
	var was := sound.source
	sound.source = who
	var out: Variant = action.call()
	sound.source = was
	return out


## End of a floor: character EXP and gold into the shared profile, and a soul
## shard roll when a real floor boss fell (mini-bosses never drop shards).
## Solo game, so this machine rolls; the rules are the same as in the crypt.
func _bank_crystals() -> void:
	# loot still lying on the floor goes with the hero, not lost with the floor
	gold_loot.collect_all()
	if profile.is_empty(): return
	var state_class := Profile.class_state(profile, class_id)
	var gained := TalentRules.add_exp(profile_data, state_class, int(profile_data.exp.floor) + (int(profile_data.exp.boss) if W.final else int(profile_data.exp.miniboss)))
	add_gold(int(profile_data.gold.per_floor) + (int(profile_data.gold.per_boss) if W.final else 0))
	_floor_reward = "+%d Gold" % (int(profile_data.gold.per_floor) + (int(profile_data.gold.per_boss) if W.final else 0))
	if gained > 0: _floor_reward += "  ·  Heldenstufe %d, neuer Talentpunkt" % int(state_class.level)
	if W.final:
		var difficulty := str(profile.get("difficulty", "normal"))
		var fight := {"present": true, "seconds": float(state.get("floor_time", 60.0)), "damage_share": 1.0}
		var result := SoulDrops.resolve(profile_data, profile, "hell_final_%d" % int(state.floor), difficulty, "%s:%d" % [_run_uid, int(state.floor)],
			int(state_class.level), SoulDrops.boss_level(profile_data, int(state.floor), difficulty), fight, randf())
		_floor_reward += "  ·  +%d SEELENSPLITTER" % int(result.count) if bool(result.shard) else ""
	Profile.save_profile(profile, profile_path)
	if talents != null: talents.save()


## The weapon damage the hero's multiples are measured against.
func base_damage() -> float:
	return maxf(0.01, float(weapon.get("damage", 1.0)))


## A dash ended (charge with shockwave card, hammer leap): its landing blow.
func on_dash_land(what: String) -> void:
	if sound != null: sound.hero("dash_land")
	if what == "shockwave":
		var s: Dictionary = theme.cards.swordsman.filter(func(c: Dictionary) -> bool: return c.id == "shockwave")[0]
		RelicKit._area(self, Vector2(player.x, player.y), float(s.radius), float(s.damage), 0.0)
		for m: Dictionary in mobs:
			if Vector2(player.x, player.y).distance_to(m.p) < float(s.radius) + m.r:
				m.stun = maxf(float(m.get("stun", 0.0)), float(s.stun))
		# effect hook: with the feel the crypt's shockwave (hero_skills.gd: a stone burst of its radius)
		if feel != null:
			story_hero.skill_fx.event("burst", [story_hero.skill_fx.ground(Vector2(player.x, player.y))], {"radius": float(s.radius) / feel.scale, "color": "stone", "time": 0.3, "length": 0.3})
		else:
			fx.append({"kind": "quake", "p": Vector2(player.x, player.y), "r": float(s.radius), "t": 0.35, "max": 0.35})
		return
	RelicKit.land(self, what)
	SubKit.land(self, what)


## The relic's look: the wielded one, else the run's (for its shrine).
func _relic_texture() -> void:
	var item := str(state.relic) if str(state.relic) != "" else str(state.get("relic_item", ""))
	relic_tex = tex.get(str(theme.get(item, {}).get("sprite", "")), null) if item != "" else null


## True while the hero wields a found relic instead of the class skills (gravity staff).
## True in a world with the hero systems (levels, run tree B, bag, skill bar):
## the theme has leveling rules. This used to read "the class has skills", but
## no class has standard skills any more (user decision 29.10.2026).
func heroic() -> bool:
	return not (theme.get("leveling", {}) as Dictionary).is_empty()


func relic_on() -> bool:
	return bool(state.get("relic_on", false)) and str(state.get("relic", "")) != ""


## A theme colour by name.
func col(name: String) -> Color:
	return _color(theme.colors[name])


## The theme's wording: hell phrases swapped for the theme's own (theme.words pairs).
func say(text: String) -> String:
	for pair: Array in theme.words:
		text = text.replace(pair[0], pair[1])
	return text


## Loads the world's sprite set (theme.sprites and its manifest) into tex.
func _load_textures() -> void:
	tex.clear()
	var sprites: String = theme.sprites
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sprites + "manifest.json"))
	for n: String in names:
		tex[n] = load(sprites + n + ".png")
	# textures the hero systems draw that this world's sprite set lacks (theme.extra_sprites)
	var extra: Dictionary = theme.get("extra_sprites", {})
	for n: String in extra.get("names", []):
		if not tex.has(n):
			tex[n] = load(str(extra.dir) + n + ".png")
	# the set's fires and fountains get their moving pictures (a pixel set keeps its 3 px grid)
	# a Weltbauer room also uses pictures from outside this set (world_room_world.gd fill_textures)
	if world != null and world.has_method("fill_textures"):
		world.fill_textures(tex, theme)
	fire_anim.build(tex, 3 if bool(theme.get("pixel", false)) else 1)


## Switches to the Pixel or HD set at once (pause menu, main menu option) and
## stores the choice. False when this world has no set for `mode`: the choice is
## stored all the same and shows in the worlds that have it.
func apply_graphics(mode: String) -> bool:
	GraphicsSettings.store(mode, graphics_path)
	graphics = mode
	if not GraphicsSettings.has(theme, mode):
		return false
	theme.merge(GraphicsSettings.skin(theme, mode), true)
	_load_textures()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if theme.pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	# the hero's look and effects follow the new hero size
	story_hero.dispose()
	story_hero = StoryHero.new(self)
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).queue_redraw()
	return true


func _layer(kind: String, z: int, area := Rect2()) -> Layer:
	var l := Layer.new()
	l.game = self
	l.kind = kind
	l.area = area
	l.z_index = z
	add_child(l)
	return l


# ---------- floors ----------

## Builds floor n (1-10). With carry the hero keeps hearts, rune stones, seal
## blessings and the paused clone skill.
func load_floor(n: int, carry: bool) -> void:
	presentation.reset()
	_custom_load_failed = false
	# A generated floor can take much longer than a frame. Neither that loading time
	# nor the old floor's remaining catch-up ticks belongs to the new floor.
	_simulation_clock.reset()
	_skip_simulation_delta = true
	# a generated world keeps its run number from floor to floor (and in saves); a fresh run rolls one
	var world_run := 0
	if world != null:
		world_run = int(state.get("world_run", 0)) if carry and not state.is_empty() else 0
		if world_run == 0:
			world_run = WorldPack.new_run()
		var raw: Dictionary = world.build_raw(n, world_run)
		if raw.is_empty():
			_custom_load_failed = true
			var problem := str(world.get("error_message")) if not custom_story.is_empty() else "Keine gültige Etage erzeugt."
			_return_to_menu.call_deferred(problem)
			return
		W = FloorData.prepare(raw)
	else:
		W = FloorData.prepare(floors_raw[n - 1])
	stairs_pick = {}
	if theme.key_in_chest:
		# keys on the floor (key rooms) wait in a chest instead; dropped keys stay drops
		for e: Dictionary in W.ents:
			if e.type == "key":
				e.type = "chest"
				e.loot = {"gems": 0, "key": e.key}
				e.magic = false
	walls = Walls.build(W.grid, W.cols, W.rows, C, W.get("doorways", []))
	_index_solids()
	if frost_snow != null:
		frost_snow.reset()
	if launch_pads != null:
		launch_pads.reset()
	# the floor's loose finds lie there as gold (the world's "gem" finds: one gold each)
	if gold_loot != null:
		gold_loot.reset()
		for e: Dictionary in W.ents:
			if e.type == "gem":
				gold_loot.place(Vector2(e.x, e.y), 1)
				e.taken = true
	minimap = []
	for r: Dictionary in W.rooms:
		minimap.append(_minimap_shape(r))
	for node: Node in _chunk_nodes:
		node.queue_free()
	_chunk_nodes = []
	for cy in range(0, W.rows, CHUNK.y):
		for cx in range(0, W.cols, CHUNK.x):
			var area := Rect2(cx * C, cy * C, CHUNK.x * C, CHUNK.y * C)
			_chunk_nodes.append(_layer("back", 0, area))
			_chunk_nodes.append(_layer("front", 20, area))
			# in the snow: the walls' contact seams and snow lips over the walls, under the actors, and
			# the lips at the back of front walls over those (src/hero/frost_wall_snow.gd)
			if frost_snow != null:
				for spec: Array in [["snow_ao", 1], ["snow_lip", 2], ["snow_front", 21]]:
					var snow_layer := _layer(spec[0], spec[1], area)
					snow_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					_chunk_nodes.append(snow_layer)
	var start := _room_of_type("start")
	var talent: Dictionary = MetaStore.run_bonus(meta_data, meta, class_id) if not meta.is_empty() else {}
	if not carry or state.is_empty() or _resuming:
		SubKit.apply(self, talent)
	var start_hp := int(hero.get("hp", balance.player.hp)) + int(talent.get("hearts", 0))
	var keep := {"hp": start_hp, "max_hp": start_hp, "gems": 0, "gold": 0, "dmg": float(weapon.get("damage", 1.0)),
		"rate": float(weapon.get("cooldown", balance.shot.cooldown)), "speed_mul": 1.0, "range": float(weapon.get("life", balance.shot.life)), "buffs": [],
		"skill": {"owned": false, "active": false, "left": float(balance.clone.duration)},
		"level": 1, "exp": 0, "skill_cd": {}, "relic": "", "relic_on": false, "upgrades": {}, "offer": [], "cards_due": 0,
		"relic_floor": 0, "relic_item": "", "talent": talent, "crystals_run": 0, "run_id": _new_run_id(), "world_run": world_run, "chapters_done": 0}
	if carry and not state.is_empty():
		keep = {"hp": state.hp, "max_hp": state.max_hp, "gems": state.gems, "gold": int(state.get("gold", 0)), "dmg": state.dmg, "rate": state.rate,
			"speed_mul": state.speed_mul, "range": state.range, "buffs": state.buffs, "skill": state.skill,
			"level": state.level, "exp": state.exp, "skill_cd": {}, "relic": state.relic, "relic_on": state.relic_on, "upgrades": state.upgrades,
			"offer": state.offer, "cards_due": state.cards_due, "relic_floor": state.relic_floor, "relic_item": state.relic_item,
			"talent": state.talent, "crystals_run": state.crystals_run, "run_id": str(state.get("run_id", _new_run_id())), "items": state.get("items", {}),
			"world_run": world_run, "chapters_done": int(state.get("chapters_done", 0))}
		keep.skill.active = false
	state = {"floor": n, "keys": {"A": false, "B": false, "C": false}, "used": {"A": false, "B": false, "C": false},
		"visited": {start.index: true}, "room": start.index, "banner": {"text": W.title, "sub": "Etage %d · %s" % [n, W.circle], "t": 0.0},
		"toasts": [], "inv": 0.0, "dead": 0.0, "map": false, "light": state.get("light", true), "t": 0.0, "won": false, "won_t": 0.0,
		"cool": 0.0, "flash": 0.0, "chill": 0.0, "storm": false, "rage": 0.0, "boss_dead": false, "stealth": 0.0, "blades": {},
		"shake": 0.0, "white": 0.0, "slow": 0.0, "pull": null}
	state.merge(keep)
	# the phoenix master skill lifts the hero once per floor
	state.phoenix_life = str(state.talent.get("master", "")) == "phoenix"
	# a new run, or the first floor of a hero carried over from the story before: this world picks its relic
	if not carry or (n == 1 and not carry_hero.is_empty() and int(state.get("relic_floor", 0)) == 0):
		RelicKit.choose_run(self)
	if feel != null:
		feel.reset()
	RelicKit.place(self)
	floor_save = StorySave.capture(self)
	# a run that sits in a save slot keeps that slot at its newest floor start
	if run_slot > 0:
		saves.write(StorySave.mode(self), run_slot, floor_save)
	_relic_texture()
	mobs = []
	_mob_space.clear()
	shots = []
	eshots = []
	zones = []
	if story_elements != null: story_elements.reset()
	if monsters != null:
		monsters.reset()
		drake_rig.reset()
	if frost_rigs != null:
		frost_rigs.reset()
	if frost_fx != null:
		frost_fx.reset()
	if pools != null:
		pools.clear()
		if gas != null: gas.clear()
	allies = []
	pending = []
	hold = {}
	dash = {}
	fx = []
	gwalls = []
	gbars = []
	embers = []
	clone = {}
	breakables = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "seal" or e.type == "skullheap" or e.type == "crate")
	_index_breakables()
	pits = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "pit")
	frost_puzzles.setup()
	hell_puzzles.setup()
	for e: Dictionary in breakables:
		e.max_hp = int(e.hp)
	if wreck != null:
		wreck.reset()
	_respawn()
	camera.position = Vector2(player.x, player.y)
	if not profile.is_empty() and (talents == null or not carry):
		if talents != null:
			talents.release()
		talents = HellTalents.new()
		talents.bind(self, profile, profile_path, class_id)
	_show_loading()


## The way to floor n on foot: its screen first, so the wait for the floor (about a second for a
## generated one) already happens behind it. The screen's clock counts that wait as well.
func _enter_floor(n: int, carry: bool) -> void:
	if _loading_allowed():
		_open_loading(n)
		# two frames: the first is the one in which the screen gets drawn
		await get_tree().process_frame
		await get_tree().process_frame
	load_floor(n, carry)


## Screens come in the game, not in tests, the test room, a custom room preview or a debug start at
## the boss.
func _loading_allowed() -> bool:
	if _leaving or start_at_boss or not testraum.is_empty() or not custom_preview_room.is_empty() or not world_room.is_empty():
		return false
	return loading_forced or Engine.get_main_loop().get_script() == null


## The end of load_floor: the screen, or the floor's name on the one already open.
func _show_loading() -> void:
	var skip := _no_loading_once
	_no_loading_once = false
	if skip or not _loading_allowed():
		return
	if loading_screen == null:
		_open_loading(int(state.floor))
	var floor_title := str(W.get("title", ""))
	if floor_title != "":
		loading_screen.floor_line = "Etage %d · %s" % [int(state.floor), floor_title]


## A screen of floor n, in its world's look, with its title and the hero being played.
func _open_loading(n: int) -> void:
	if loading_screen != null:
		loading_screen.queue_free()
	loading_screen = LoadingScreen.new()
	loading_screen.finished.connect(func(_scene: PackedScene) -> void: loading_screen = null)
	add_child(loading_screen)
	loading_screen.start_story({"world": StorySave.mode(self), "title": str(custom_story.get("title", "")).to_upper() if not custom_story.is_empty() else "",
		"floor_line": "Etage %d" % n,
		"hero": str(hero.get("sprite", "knight_m")), "class_id": class_id, "tile": tex.get("floor_01"), "wall": tex.get("wall_h"), "seen": _hints_seen, "variant": loading_variant})


## The talents refer back to themselves (src/hell/hell_talents.gd release):
## let them go with this game. Before that, the pools wait for the shapes their
## worker threads still work out: those ask this game's floor (_floor_open), so
## a world freed in the middle (back to the menu) would crash.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	# every pool painter of this world: the floor's, the talents' and the boss/potion pools
	var painters: Array = [pools]
	if talents != null and talents.fx != null:
		painters.append(talents.fx.pools)
	if feel != null and feel.boss_fx != null:
		painters.append(feel.boss_fx.pools)
	for painter: Variant in painters:
		if painter != null:
			painter.clear()
	if talents != null:
		talents.release()


## Debug jump: puts the hero inside the boss room, two cells past the gate it
## is reached through, with that gate open. The fight starts on the next frame.
func enter_boss_room() -> void:
	var boss := _room_of_type("boss")
	var gate: Dictionary = {}
	for i: int in boss.doors:
		var d: Dictionary = W.doors[i]
		if d.kind != "boss" and d.kind != "secret":
			gate = d
			if d.kind == "lock":
				break
	if gate.get("kind", "") == "lock":
		gate.unlocked = true
		state.used[gate.key] = true
	var at := Vector2((boss.bx + boss.bw / 2.0) * C, (boss.by + boss.bh / 2.0) * C)
	if not gate.is_empty():
		var door := Vector2(gate.cx, gate.cy)
		var best := INF
		for c: Vector2i in boss.cells:
			var p := Vector2((c.x + 0.5) * C, (c.y + 0.8) * C)
			var score := absf(p.distance_to(door) - 2.5 * C)
			if W.grid[c.y * W.cols + c.x] == 1 and score < best and _fully_inside(boss, p.x, p.y) and not box_blocked(_player_box(p.x, p.y).grow(48)):
				best = score
				at = p
	player.x = at.x
	player.y = at.y
	state.room = boss.index
	state.visited[boss.index] = true
	state.banner = {"text": boss.name, "sub": str(boss.get("kind", "")), "t": 0.0}
	# the goals the jump finished (key, gate) stay quiet
	FrostHud.hush(self)
	camera.position = Vector2(player.x, player.y)


func _room_of_type(kind: String) -> Dictionary:
	for r: Dictionary in W.rooms:
		if r.type == kind:
			return r
	return W.rooms[0]


func _respawn() -> void:
	if sound != null: sound.hero("respawn")
	var s := _room_of_type("start")
	var spawn: Array = s.spawn if s.spawn != null else [s.bw / 2.0, s.bh / 2.0]
	player = {"x": (s.bx + float(spawn[0])) * C, "y": (s.by + float(spawn[1])) * C, "face": 1.0, "anim": 0.0, "moving": false, "vel": Vector2.ZERO, "aim": Vector2.RIGHT}


func _index_solids() -> void:
	solid_grid = {}
	for p: Dictionary in W.props:
		if p.solid != null:
			_add_solid(Rect2(p.solid[0], p.solid[1], p.solid[2] - p.solid[0], p.solid[3] - p.solid[1]))
	for e: Dictionary in W.ents:
		match e.type:
			"chest": _add_solid(Rect2(e.x - 40, e.y - 32, 80, 32))
			"vault": _add_solid(Rect2(e.x - 70, e.y - 50, 140, 50))
			"portal": _add_solid(Rect2(e.x - 72, e.y - 40, 144, 40))
			"brazier": _add_solid(Rect2(e.x - 28, e.y - 30, 56, 30))
			"well": _add_solid(Rect2(e.x - 56, e.y - 44, 112, 44))
			"stairs": _add_solid(Rect2(e.x - 70, e.y - 60, 140, 50))
	door_at = {}
	for d: Dictionary in W.doors:
		for c: Vector2i in d.cells:
			door_at[c.y * W.cols + c.x] = d.index


func _add_solid(r: Rect2) -> void:
	for cy in range(int(floor(r.position.y / C)), int(floor(r.end.y / C)) + 1):
		for cx in range(int(floor(r.position.x / C)), int(floor(r.end.x / C)) + 1):
			var k: int = cy * W.cols + cx
			if not solid_grid.has(k):
				solid_grid[k] = []
			solid_grid[k].append(r)


func _minimap_shape(r: Dictionary) -> Dictionary:
	# fill as row runs (few rects per room), outline as cell edges for one multiline call
	var rects: Array[Rect2] = []
	var edges := PackedVector2Array()
	var cols: int = W.cols
	# a labyrinth shows as one block: its corridors are for the hero to find
	var own := {}
	for c: Vector2i in r.cells:
		own[c] = true
	for run_cells: Array in r.get("maze_zone", []):
		for x in range(int(run_cells[0]), int(run_cells[2]) + 1):
			own[Vector2i(x, int(run_cells[1]))] = true
	var cells: Array = own.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var run := Rect2()
	for c: Vector2i in cells:
		if run.size.x > 0.0 and int(run.position.y) == c.y and int(run.end.x) == c.x:
			run.size.x += 1.0
		else:
			if run.size.x > 0.0:
				rects.append(run)
			run = Rect2(c.x, c.y, 1, 1)
	if run.size.x > 0.0:
		rects.append(run)
	for c: Vector2i in cells:
		for side: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n := c + side
			var outside: bool = not own.has(n)
			if not outside:
				continue
			var a := Vector2(c.x + (1 if side.x > 0 else 0), c.y + (1 if side.y > 0 else 0))
			var b := a + (Vector2(1, 0) if side.y != 0 else Vector2(0, 1))
			edges.append(a)
			edges.append(b)
	return {"rects": rects, "edges": edges}


# ---------- queries ----------

func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W.cols or y >= W.rows:
		return 0
	return W.grid[y * W.cols + x]


## True at world place `p` in a room of nothing but ice (frost_world.json ice_rooms, theme ice_room).
func ice_room_at(p: Vector2) -> bool:
	var room := _room_at_world(p.x, p.y)
	if room < 0 or room >= (W.rooms as Array).size() or not bool(W.rooms[room].get("ice", false)):
		return false
	# an ice lake (a Weltbauer room with ice_lake): its painted ground (area brush) is a firm snowfield
	if bool(W.rooms[room].get("ice_lake", false)):
		var cell := int(floor((p.y) / C)) * int(W.cols) + int(floor(p.x / C))
		return not (W.get("areas", {}) as Dictionary).has(cell)
	return true


## The footing at world place `p` in a room of nothing but ice (theme ice_room): grip, or mob_grip for
## a monster; an ice lake takes it harder (lake_grip, lake_mob_grip).
func ice_room_grip(p: Vector2, mob: bool) -> float:
	var room := _room_at_world(p.x, p.y)
	var lake := room >= 0 and room < (W.rooms as Array).size() and bool(W.rooms[room].get("ice_lake", false))
	var ice: Dictionary = theme.ice_room
	if lake:
		return float(ice.get("lake_mob_grip" if mob else "lake_grip", ice.mob_grip if mob else ice.grip))
	return float(ice.mob_grip if mob else ice.grip)


## World px per art pixel (the floor tiles' 16 px art drawn x3 at 48 px).
const PIXEL_WORLD := 3.0
## WAHN (madness_rules.json madness) on a themed world's enemies: the mad one
## whose turn runs now (its shots scatter: _enemy_shot) and the enemy it turned
## on ({} for none; its shots then hurt enemies: _themed_mad_shot).
var _mad_mob: Dictionary = {}
var _mad_prey: Dictionary = {}


## Shadow welling up at world point `p` (src/vfx/particles.gd shadow: a pool of
## ink with tendrils reaching out and drawing back), `reach` crypt px: the mark
## of a shadow skill (the Schattenläufer, the shadow dagger). Nothing without
## the feel.
func shadow_at(p: Vector2, branches: int = 5, reach: float = 34.0) -> void:
	if feel == null or feel.get("feedback") == null:
		return
	feel.feedback.particles.shadow(p / feel.scale, branches, reach)


## A cloud of smoke at world point `p`, `r` world px wide, for `length` s
## (src/vfx/gas.gd: it spreads, flows round walls, is parted by whoever walks
## through it); nothing without the world's gas layer.
func smoke_at(p: Vector2, r: float, length: float) -> void:
	if gas == null:
		return
	gas.emit("smoke:%d" % Time.get_ticks_msec(), "smoke", p, r, length, float(state.t))


## Floor a pool may cover: walkable cells outside the solid props.
func _floor_open(p: Vector2) -> bool:
	if not _walkable(_cell(int(floor(p.x / C)), int(floor(p.y / C)))):
		return false
	return not box_blocked(Rect2(p - Vector2(1, 1), Vector2(2, 2)))


func _walkable(t: int) -> bool:
	return t == 1 or t == 2 or t == 3


func _door_closed(d: Dictionary) -> bool:
	return Rules.door_closed(d, W.rooms, W.groups, state.boss_dead)


func _cell_blocked(cx: int, cy: int, avoid_lava: bool) -> bool:
	var t := _cell(cx, cy)
	if not _walkable(t) or (avoid_lava and t == 2):
		return true
	var k := cy * int(W.cols) + cx
	return door_at.has(k) and _door_closed(W.doors[door_at[k]])


## True when an axis-aligned box (world pixels) touches a wall, closed gate or solid prop.
func box_blocked(box: Rect2, avoid_lava := false) -> bool:
	for cy in range(int(floor(box.position.y / C)), int(floor((box.end.y - 1.0) / C)) + 1):
		for cx in range(int(floor(box.position.x / C)), int(floor((box.end.x - 1.0) / C)) + 1):
			if _cell_blocked(cx, cy, avoid_lava):
				return true
			for s: Rect2 in solid_grid.get(cy * int(W.cols) + cx, _NOTHING):
				if s.intersects(box):
					return true
	# the Frostgruft's blocks, balls, prisms and crystals stand in their cells
	if frost_puzzles != null and frost_puzzles.box_blocked(box):
		return true
	# the hell's winches, valves, shields and gates (hell_puzzles.gd)
	if hell_puzzles != null and hell_puzzles.box_blocked(box):
		return true
	# the breakables: only those filed under a cell the box touches (each one the box
	# overlaps shares a point with it, and that point's cell lists it); the same test
	var filed := (_breakable_grid_n == breakables.size() and is_same(_breakable_grid_of, breakables)
			and box.size.x >= 0.0 and box.size.y >= 0.0 and is_finite(box.position.x) and is_finite(box.position.y)
			and is_finite(box.size.x) and is_finite(box.size.y))
	if filed:
		var x0 := int(floor(box.position.x / C))
		var x1 := int(floor(box.end.x / C))
		var y0 := int(floor(box.position.y / C))
		var y1 := int(floor(box.end.y / C))
		if (x1 - x0 + 1) * (y1 - y0 + 1) <= 16:
			for cy in range(y0, y1 + 1):
				for cx in range(x0, x1 + 1):
					for e: Dictionary in _breakable_grid.get(Vector2i(cx, cy), _NOTHING):
						if not e.get("broken", false) and _breakable_box(e).intersects(box):
							return true
			return false
	for e: Dictionary in breakables:
		if not e.get("broken", false) and _breakable_box(e).intersects(box):
			return true
	return false


## Files every breakable under each cell (C px) its box touches, edges included
## (box_blocked asks this grid). The breakables do not move; one that breaks stays
## filed (box_blocked skips it as before).
func _index_breakables() -> void:
	var grid := {}
	for e: Dictionary in breakables:
		var b := _breakable_box(e)
		for cy in range(int(floor(b.position.y / C)), int(floor(b.end.y / C)) + 1):
			for cx in range(int(floor(b.position.x / C)), int(floor(b.end.x / C)) + 1):
				var cell := Vector2i(cx, cy)
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(e)
	_breakable_grid = grid
	_breakable_grid_of = breakables
	_breakable_grid_n = breakables.size()


func _breakable_box(e: Dictionary) -> Rect2:
	if e.type == "crate":
		return Rect2(e.x - 30.0, e.y - 30.0, 60.0, 30.0)
	var hw := 42.0 if e.type == "seal" else 48.0
	return Rect2(e.x - hw, e.y - 40.0, hw * 2.0, 40.0)


# ---------- what the Frostgruft's puzzles ask of the game (src/world_kit/frost_puzzles.gd) ----------

## The cell the hero's feet stand in.
func player_cell() -> Vector2i:
	return Vector2i(int(floor(float(player.x) / C)), int(floor((float(player.y) - 6.0) / C)))


## Puts the hero at world place p, standing still.
func place_player(p: Vector2) -> void:
	player.x = p.x
	player.y = p.y
	player.vel = Vector2.ZERO


## The grid value of cell (x, y): 0 wall, 1 floor, 2 liquid, 3 bridge.
func cell(x: int, y: int) -> int:
	return _cell(x, y)


## The room index of cell c, -1 outside every room.
func room_at_cell(c: Vector2i) -> int:
	return _room_at_world((c.x + 0.5) * C, (c.y + 0.5) * C)


## The hero's box at x, y.
func player_box(x: float, y: float) -> Rect2:
	return _player_box(x, y)


## A movement key pair as -1, 0 or 1 (0 while keys are taken by a window).
func input_axis(neg: Key, pos: Key) -> float:
	return _axis(neg, pos)


func toast(text: String) -> void:
	_toast(text)


func solve_group(group: String) -> void:
	_solve_group(group)


func light_brazier(e: Dictionary) -> void:
	_light_brazier(e)


func fall_into_pit() -> void:
	_fall_into_pit()


## The crevasse at cell c is ground now: nobody falls there.
func pit_filled(c: Vector2i) -> void:
	var k := c.y * int(W.cols) + c.x
	(W.get("pit_cells", {}) as Dictionary).erase(k)
	for e: Dictionary in pits:
		if int(floor(float(e.x) / C)) == c.x and int(floor(float(e.y) / C)) == c.y:
			e.filled = true
	pits = pits.filter(func(e: Dictionary) -> bool: return not e.get("filled", false))
	for node: Layer in _chunk_nodes:
		node.queue_redraw()


## The crevasse at cell c opens again (the puzzle room was reset).
func pit_restored(c: Vector2i) -> void:
	for e: Dictionary in W.ents:
		if e.type == "pit" and e.get("filled", false) and int(floor(float(e.x) / C)) == c.x and int(floor(float(e.y) / C)) == c.y:
			e.filled = false
			pits.append(e)
			W.pit_cells[c.y * int(W.cols) + c.x] = true
	for node: Layer in _chunk_nodes:
		node.queue_redraw()


## A puzzle piece's moment: chips, snow, a flash, its sound.
func puzzle_effect(kind: String, at: Vector2) -> void:
	match kind:
		"ice_break", "lost":
			_sound("secret")
			if frost_fx != null:
				frost_fx.shatter(at, 12, 30.0, Vector2.UP, 140.0)
			elif feel != null:
				feel.spawn("dust", at, 1.0)
		"slide", "snow", "fill":
			if frost_fx != null:
				frost_fx.kick(at, 10)
			if kind == "fill":
				_sound("plate")
		"plate", "prism":
			_sound("plate")
		"ember":
			_burst(at, 10)
		"ember_out":
			_sound("plate_wrong")


func _player_box(x: float, y: float) -> Rect2:
	var hw := float(balance.player.half_width)
	var h := float(balance.player.height)
	return Rect2(x - hw, y - h, hw * 2.0, h)


func _room_at_world(x: float, y: float) -> int:
	var cx := int(floor(x / C))
	var cy := int(floor(y / C))
	if cx < 0 or cy < 0 or cx >= W.cols or cy >= W.rows:
		return -1
	return W.room_at[cy * W.cols + cx]


## A spot of free floor in room `room` between min_d and max_d px from `near` (no wall, prop or
## liquid under a 60 x 30 px foot); `near` when none is found. The worlds without hell monsters
## (the Frostgruft) place their spawns with it, as hell_monsters.gd free_spot does.
## The labyrinth values (assets/data/world_maze.json).
func maze_cfg() -> Dictionary:
	return DataCache.load_dict(MAZE_PATH)


## True while the hero stands in the dark part of his room (its maze_zone, row runs of cells).
func in_maze() -> bool:
	if W.is_empty() or state.is_empty() or int(state.room) < 0 or int(state.room) >= (W.rooms as Array).size():
		return false
	var zone: Array = (W.rooms[state.room] as Dictionary).get("maze_zone", [])
	if zone.is_empty():
		return false
	var cx := int(floor(player.x / C))
	var cy := int(floor((player.y - 6.0) / C))
	for run: Array in zone:
		if cy == int(run[1]) and cx >= int(run[0]) and cx <= int(run[2]):
			return true
	return false


## True when nothing but open ground lies on the straight line from a to b (walls block it).
func clear_line(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 16.0)
	for k in range(1, steps):
		var p := a.lerp(b, float(k) / float(steps))
		if _cell(int(floor(p.x / C)), int(floor(p.y / C))) == 0:
			return false
	return true


## Where the `k`-th enemy let out at `at` stands: on free ground of room `room` reached from `at` along
## the floor (never through a wall), nearest first, within world_maze.json spawn_cells; the old free
## spot around `at` when the piece stands somewhere open.
func corridor_spot(room: int, at: Vector2, k: int) -> Vector2:
	var start := Vector2i(int(floor(at.x / C)), int(floor((at.y - 10.0) / C)))
	var reach := int(maze_cfg().get("spawn_cells", 3))
	var seen := {start: 0}
	var order: Array[Vector2i] = []
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if int(seen[c]) >= reach:
			continue
		for n: Vector2i in [c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
			if seen.has(n) or _cell(n.x, n.y) != 1 or _room_at_world((n.x + 0.5) * C, (n.y + 0.5) * C) != room:
				continue
			seen[n] = int(seen[c]) + 1
			var p := Vector2((n.x + 0.5) * C, (n.y + 0.7) * C)
			if pit_at(p):
				continue
			todo.append(n)
			if not box_blocked(Rect2(p.x - 30, p.y - 30, 60, 30), true):
				order.append(n)
	if order.is_empty():
		return free_floor(room, at, 70.0, 200.0)
	var c := order[k % order.size()]
	return Vector2((c.x + 0.5) * C, (c.y + 0.7) * C)


func free_floor(room: int, near: Vector2, min_d: float, max_d: float) -> Vector2:
	for k in range(40):
		var p := near + Vector2.from_angle(randf() * TAU) * randf_range(min_d, max_d)
		if _room_at_world(p.x, p.y) == room and _cell(int(floor(p.x / C)), int(floor(p.y / C))) == 1 \
				and not box_blocked(Rect2(p.x - 30, p.y - 30, 60, 30), true) and not pit_at(p):
			return p
	return near


## True when world point `p` lies in a pit cell: an enemy let out there would stand over the hole.
func pit_at(p: Vector2) -> bool:
	var cx := int(floor(p.x / C))
	var cy := int(floor(p.y / C))
	for e: Dictionary in pits:
		if int(floor(float(e.x) / C)) == cx and int(floor(float(e.y) / C)) == cy:
			return true
	return false


func _near_door(r: Dictionary, p: Vector2, dist: float) -> bool:
	for i: int in r.doors:
		var d: Dictionary = W.doors[i]
		if p.distance_to(Vector2(d.cx, d.cy)) < dist * C:
			return true
	return false


## K: the talent menu over the run; a changed build counts at once.
## Free talent points: x the hero's (Heldenstufe, K), y the run's (Laufstufe, LAUF tab).
func _talent_points() -> Vector2i:
	var hero_points: int = talents.free_points() if talents != null else 0
	var run_points := 0
	if heroic():
		run_points = _run_points_left()
	return Vector2i(hero_points, run_points)


## The run talent points still to spend; within one HUD drawing worked out once (draw_hud).
var _hud_open := false
var _hud_run_points := -1


func _run_points_left() -> int:
	var drawing := _hud_open
	if drawing and _hud_run_points >= 0:
		return _hud_run_points
	var n: int = RunTree.points_left(CardKit.tree(self), CardKit.ranks(self), int(state.level))
	if drawing:
		_hud_run_points = n
	return n


## K (or the pause's Talente) opens the talent window; B opens it on the LAUF tab.
func open_run_talents(on_run_page := false) -> void:
	if sound != null: sound.at("talent_open", Vector2.INF)
	# one window at a time: the talents replace the character window, never stack on it
	if inventory_panel != null and inventory_panel.open:
		_character_from_pause = false
		inventory_panel.set_open(false)
	if run_talents == null:
		run_talents = TalentScreenScript.new()
		pause_menu.get_parent().add_child(run_talents)
		run_talents.profile_changed.connect(func() -> void: talents.tc.set_build(1, Profile.build_of(profile, class_id), true))
	# one talent window: the hero's talents and, mid-run, the run tree as its LAUF tab
	var page := {"title": "LAUF", "draw": _draw_run_page, "click": _click_run_page} if heroic() else {}
	run_talents.open(Profile.data(), profile, profile_path, class_id, true, page)
	if on_run_page and not page.is_empty():
		run_talents.show_run_page()


var _run_page_rect := Rect2()


## Draws the run tree inside the talent screen's LAUF tab (`rect`: its content area).
func _draw_run_page(canvas: CanvasItem, rect: Rect2) -> void:
	_run_page_rect = rect
	canvas.draw_set_transform(rect.position)
	RunTreeView.draw(canvas, FONT, rect.size, CardKit.tree(self), CardKit.ranks(self), int(state.level),
		{"title": str(hero.get("name", class_id)), "mouse": canvas.get_local_mouse_position() - rect.position, "embedded": true})
	canvas.draw_set_transform(Vector2.ZERO)


## A click on the LAUF tab spends a run point on the node under it.
func _click_run_page(at: Vector2) -> bool:
	var picked := RunTreeView.hit(_run_page_rect.size, CardKit.tree(self), at - _run_page_rect.position)
	if picked == "":
		return false
	CardKit.take_node(self, picked)
	return true


## The pause page's controls (STORY_CONTROLS), with the card line only when the
## run hands out level-up cards.
static func story_controls(cards: bool) -> String:
	if not cards:
		return STORY_CONTROLS
	return STORY_CONTROLS.replace("\n\nWELT", "\nKarte wählen: 7 8 9 oder Klick\n\nWELT")


## The result panel's buttons (mouse, pad): the main one (NEUER LAUF / WEITER,
## the same as E) with the focus, HAUPTMENÜ beside it; _sync_overlays places them.
func _build_result_buttons(ui: CanvasLayer) -> void:
	result_ui = Control.new()
	result_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_ui.theme = CryptUI.create_theme()
	result_ui.visible = false
	ui.add_child(result_ui)
	result_main = Button.new()
	result_main.pressed.connect(act)
	result_menu = Button.new()
	result_menu.text = "ZUR WERKSTATT" if not custom_preview_room.is_empty() else ("CUSTOM-STORYS" if not custom_story.is_empty() else "HAUPTMENÜ")
	result_menu.pressed.connect(_return_to_menu)
	for button: Button in [result_main, result_menu]:
		button.add_theme_font_size_override("font_size", int(HudStyle.size("font_body")))
		result_ui.add_child(button)
	result_main.focus_neighbor_right = result_menu.get_path()
	result_menu.focus_neighbor_left = result_main.get_path()


## Applies what the last HUD frame decided to the real controls: the result
## buttons under the result panel (hidden under the pause), the inventory chip
## off while a window or a result is up.
func _sync_overlays() -> void:
	if inventory_panel != null:
		inventory_panel.chip_blocked = _windows or _result_rect.size.x > 0.0
	if result_ui == null:
		return
	if _result_rect.size.x <= 0.0 or _result_label == "" or (pause_menu != null and pause_menu.visible):
		result_ui.visible = false
		return
	var row := HudKit.result_button_row(_result_rect)
	var gap := 12.0
	var main_w := floorf((row.size.x - gap) * 0.6)
	result_main.text = _result_label
	result_main.position = row.position
	result_main.size = Vector2(main_w, row.size.y)
	result_menu.position = row.position + Vector2(main_w + gap, 0.0)
	result_menu.size = Vector2(row.size.x - main_w - gap, row.size.y)
	if not result_ui.visible:
		result_ui.visible = true
		result_main.grab_focus()


## True when the character & inventory window was opened from the pause menu
## (it returns there when it closes).
var _character_from_pause := false


## Opens the one character & inventory window (C, Tab, I or the pause's
## Inventar page): the hero's numbers left, the bag right. Nothing else stays
## open under it; the solo run pauses while it shows (_simulation_paused).
func _open_character(from_pause := false) -> void:
	if inventory_panel == null:
		return
	state.status = false
	state.map = false
	state.tree_open = false
	_character_from_pause = from_pause
	inventory_panel.set_character_view(FrostHud.status_sheet(self))
	inventory_panel.set_open(true)


## C, Tab and I: the same window opens, and the same keys close it.
func _toggle_character() -> void:
	if inventory_panel == null or not heroic():
		return
	if inventory_panel.open:
		inventory_panel.set_open(false)
	else:
		_open_character()


## True while a window covers the HUD: pause, talent menu (K), the character &
## inventory window (C, Tab, I), run talents (B) or the big map (M).
func _window_open() -> bool:
	return (pause_menu != null and pause_menu.visible) or (run_talents != null and run_talents.visible) \
		or (inventory_panel != null and inventory_panel.open) or bool(state.get("tree_open", false)) \
		or bool(state.get("status", false)) or bool(state.get("map", false))


## Esc: closes the topmost open window (pause, inventory, run talents, status,
## map) and says so; false when none was open (then Esc opens the pause).
func _close_top_window() -> bool:
	if pause_menu != null and pause_menu.visible:
		pause_menu.visible = false
	elif inventory_panel != null and inventory_panel.open:
		inventory_panel.set_open(false)
	elif bool(state.get("tree_open", false)):
		state.tree_open = false
	elif bool(state.get("status", false)):
		state.status = false
	elif bool(state.get("map", false)):
		state.map = false
	else:
		return false
	return true


## True for a companion at full life with nothing cooling down (its bar steps back).
func _pet_idle(pet: Dictionary) -> bool:
	if pet.is_empty() or not bool(pet.get("alive", false)):
		return false
	if float(pet.get("hp", 0.0)) < float(pet.get("hp_max", 1.0)):
		return false
	for ability: Dictionary in pet.get("abilities", []):
		if float(ability.get("cd", 0.0)) > 0.0:
			return false
	return true


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	# F9 in a Weltbauer room: its file again, as just saved, from the start
	if not world_room_path.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		new_run()
		get_viewport().set_input_as_handled()
		return
	# while paused only Esc counts (it closes the menu again)
	if pause_menu != null and pause_menu.visible and not (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		return
	if run_talents != null and run_talents.visible: return
	# a broken seal's blessing cards (balance package D1): 1 / 2 or a click takes one, Esc leaves
	# both; nothing else reaches the waiting world
	if CardKit.seal_open(self) and not (pause_menu != null and pause_menu.visible):
		var picked_seal := -1
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			picked_seal = FrostHud.seal_card_at(self, event.position, get_viewport_rect().size)
		CardKit.seal_input(self, event, picked_seal)
		get_viewport().set_input_as_handled()
		return
	# K: the talent menu mid-run, in every world (user decision 30.10.2026)
	if talents != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		open_run_talents()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pause_menu != null and not _window_open() \
			and HudKit.menu_rect(get_viewport_rect().size).has_point(event.position):
		open_pause()
		get_viewport().set_input_as_handled()
		return
	# the talent chip under it: the talents, on the LAUF tab when only run points are free
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and talents != null and not _window_open() \
			and HudKit.talent_rect(get_viewport_rect().size).has_point(event.position):
		var points := _talent_points()
		open_run_talents(points.x == 0 and points.y > 0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and throw_slot >= 0 and story_items != null:
		# an armed potion goes where the click lands
		story_items.act("inv_throw", throw_slot, get_global_mouse_position())
		throw_slot = -1
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and state.get("tree_open", false):
		# a click in the open talent tree spends a point there, never fires
		var picked_node := RunTreeView.hit(get_viewport_rect().size, CardKit.tree(self), event.position)
		if picked_node != "":
			CardKit.take_node(self, picked_node)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not (state.get("offer", []) as Array).is_empty():
		var picked := FrostHud.card_at(self, get_viewport().get_mouse_position(), get_viewport_rect().size)
		if picked >= 0:
			CardKit.choose(self, picked)
			get_viewport().set_input_as_handled()
			return
	# a right-click on a companion icon of the skill bar toggles its auto-cast
	if talents != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var pet_slot: int = talents.pet_slot_at(get_viewport_rect().size, hud.get_local_mouse_position() if hud != null else get_viewport().get_mouse_position())
		if pet_slot >= 0:
			talents.toggle_pet(pet_slot)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and relic_on() and RelicKit.wielded(self).has("ball"):
		# the gravity bar: drag with the right mouse, release to set it
		if event.pressed:
			bar_drag = {"a": get_global_mouse_position()}
		elif not bar_drag.is_empty():
			as_source("hero", func() -> void: HeroKit.gravity_bar(self, bar_drag.a, get_global_mouse_position()))
			bar_drag = {}
		return
	if not (event is InputEventKey) or event.echo:
		return
	# the character & inventory window holds the paused run: only its own keys and the
	# run talents (B, which replace it) pass; no skill or potion fires from behind it
	if inventory_panel != null and inventory_panel.open and event.pressed \
			and event.keycode not in [KEY_C, KEY_TAB, KEY_I, KEY_ESCAPE, KEY_B]:
		return
	if not stairs_pick.is_empty() and event.pressed:
		# the floor choice of the hidden stairs takes the number keys; Esc or E closes it
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			choose_stairs(int(event.keycode - KEY_0))
		elif event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE]:
			stairs_pick = {}
		get_viewport().set_input_as_handled()
		return
	var skill_keys := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4"}
	# 1-4: the learned talents, R: the ultimate, the same keys in every map;
	# there are no standard class skills (user decision 29.10.2026). A wielded
	# relic keeps its own abilities on 1-4.
	if talents != null and event.pressed and skill_keys.has(event.keycode) and not relic_on():
		talents.press(int(skill_keys[event.keycode]) - 1)
		return
	if talents != null and event.pressed and event.keycode == KEY_R:
		talents.press(-1)
		return
	# 5 and 6: the permanent companion's abilities, in every world
	if talents != null and event.pressed and event.keycode in [KEY_5, KEY_6]:
		talents.press_pet(event.keycode - KEY_5)
		return
	if relic_on() and skill_keys.has(event.keycode):
		var key: String = skill_keys[event.keycode]
		if event.pressed:
			if not FrostCombat.can_cast(self, key):
				return
		skill_key(key, event.pressed)
		return
	var card_keys := {KEY_7: 0, KEY_8: 1, KEY_9: 2}
	if event.pressed and card_keys.has(event.keycode) and not (state.get("offer", []) as Array).is_empty():
		CardKit.choose(self, card_keys[event.keycode])
		return
	if not event.pressed:
		return
	match event.keycode:
		KEY_E, KEY_SPACE, KEY_ENTER:
			act()
		KEY_Q:
			use_skill()
		KEY_F:
			# F: the worn armour's ability (src/hero/armor_powers.gd), aimed at the mouse
			if story_items != null and heroic() and not relic_on():
				as_source("hero", func() -> void: story_items.press_power(get_global_mouse_position()))
		KEY_H:
			# H drinks the quick potion, G throws it at the mouse (src/hero/story_items.gd quick_slot)
			if story_items != null and heroic() and not event.echo:
				as_source("hero", func() -> void: story_items.drink_quick())
		KEY_G:
			if story_items != null and heroic() and not event.echo:
				as_source("hero", func() -> void: story_items.throw_quick(get_global_mouse_position()))
		KEY_M:
			state.map = not state.map
		KEY_L:
			state.light = not state.light
		KEY_ESCAPE:
			# Esc closes the topmost window first (inventory, run talents, status, map), only then opens the pause
			if not _close_top_window():
				open_pause()
		KEY_T:
			if str(state.relic) != "":
				state.relic_on = not state.relic_on
				_relic_texture()
				_toast(("%s in der Hand." % theme[state.relic].name) if state.relic_on else ("%s in der Hand." % weapon.get("name", "Waffe")))
		KEY_5:
			if heroic() and FrostCombat.can_cast(self, "5") and not SubKit.master(self):
				as_source("hero", func() -> void: HeroKit.master_press(self))
		KEY_C, KEY_TAB, KEY_I:
			_toggle_character()
		KEY_B:
			# the run talent tree (docs/LAUF-DESIGN.de.md); the world waits while it is open (_process)
			if heroic():
				open_run_talents(true)
		KEY_PAGEUP:
			# debug: one level up
			if heroic():
				HeroKit.gain(self, HeroKit.need(theme.leveling, int(state.level)) - int(state.exp))
		_:
			var k: int = event.keycode
			if heroic() and k >= KEY_F1 and k <= KEY_F10:
				# debug floor jumps keep the hero's progress where 1-4 are skills
				_no_loading_once = true
				load_floor(k - KEY_F1 + 1, true)
			elif not heroic() and k >= KEY_0 and k <= KEY_9:
				_no_loading_once = true
				load_floor(10 if k == KEY_0 else k - KEY_0, false)


## A skill key (1-4) pressed or released: the relic's, the subclass's or the
## class skill; their sounds play at the hero's mix level (as_source "hero").
func skill_key(key: String, pressed: bool) -> void:
	as_source("hero", _skill_key_now.bind(key, pressed))


func _skill_key_now(key: String, pressed: bool) -> void:
	if pressed:
		if not RelicKit.press(self, key) and not SubKit.press(self, key):
			HeroKit.press(self, key)
	elif not RelicKit.release(self, key):
		HeroKit.release(self, key)


func _axis(neg: Key, pos: Key) -> float:
	if keys_taken:
		return 0.0
	return (1.0 if Input.is_physical_key_pressed(pos) else 0.0) - (1.0 if Input.is_physical_key_pressed(neg) else 0.0)


# ---------- gameplay ----------

## The one message channel: one toast on screen at a time, the rest wait their
## turn (ui_hud_style.json "rules": toast_time each, toast_queue waiting); the
## same text twice is not queued. The sound plays when a toast shows. Finds
## close together join one toast ("3 Funde: ...", InventoryPanel.finds_line):
## the last one in the queue while it waits or shows for under toast_merge s.
func _toast(text: String) -> void:
	var said := say(text)
	var queue: Array = state.get("toasts", [])
	var found := InventoryPanel.found_name(said)
	if not found.is_empty() and not queue.is_empty():
		var last: Dictionary = queue[queue.size() - 1]
		if last.has("finds") and float(last.get("age", 0.0)) <= HudKit.rule("toast_merge", 0.6):
			(last.finds as Array).append(found)
			last.text = InventoryPanel.finds_line(last.finds)
			last.t = maxf(float(last.t), HudKit.rule("toast_time", 2.0))
			state.toasts = queue
			return
	for t: Dictionary in queue:
		if str(t.text) == said:
			return
	if queue.is_empty() and sound != null: sound.at("toast", Vector2.INF)
	var entry := {"text": said, "t": HudKit.rule("toast_time", 2.0)}
	if not found.is_empty(): entry.finds = [found]
	queue.append(entry)
	# too many waiting: the oldest waiting one goes, never the one on screen
	while queue.size() > 1 + int(HudKit.rule("toast_queue", 3.0)):
		queue.remove_at(1)
	state.toasts = queue


## Costs the hero n half hearts unless he is still invulnerable from the last hit
## (`from`: where the blow came from, when known: the crypt's blood splats away from it;
## `by`: the monster striking or shooting, when known: a perfect block lets it reel;
## `shot`: the projectile that hit, when it was one: a perfect block or roll breaks it,
## and its shooter reels only in melee reach).
func _hurt(why: String, n := 1, from := Vector2.ZERO, by: Dictionary = {}, shot: Dictionary = {}) -> void:
	if state.inv > 0.0 or state.dead > 0.0 or launch_pads.flying():
		return
	if SubKit.guard(self):
		return
	# Shift in time (balance package B3, src/hell/hero_kit.gd perfect_defense): the block holds
	# without losing a charge and the attacker reels, or the roll readies the counter shot
	if HeroKit.perfect_defense(self, from, by, shot):
		return
	if story_items != null and story_items.consume_shield(from):
		state.inv = float(balance.player.invulnerable)
		return
	# the Beuteordnung: a hit is worth more the deeper the hero is (1, 2, 3 LP ...)
	n *= hit_scale()
	if story_items != null:
		n += story_items.extra_damage()
	state.inv = float(balance.player.invulnerable)
	# Talents: difficulty, reductions, shields, the counter (the same in every map).
	if talents != null:
		n = talents.incoming(n, from)
		if n <= 0: return
	_lose_hp(n, why, from)


## Damage over time (poison and burn of the Frostgruft's conditions,
## src/hell/hero_fx.gd): lands through the short invulnerability after a hit,
## but not while dying.
func dot_hurt(n: int, why: String) -> void:
	if state.dead > 0.0 or state.won:
		return
	_lose_hp(n, why)


## Damage over time in half hearts, fractional (lava, poison, burn, gas:
## element_rules.json hurt per second): collects in state.dot and takes a half
## heart whenever a whole one is owed, quietly (a short flash and the hurt
## sound, no punch); the life bar shows hp minus the debt draining (hp_f).
## Lands through the invulnerability after a hit, not while dying.
func dot_hurt_f(amount: float, why: String) -> void:
	if amount <= 0.0 or state.dead > 0.0 or state.won or int(state.hp) <= 0:
		return
	state.dot = float(state.get("dot", 0.0)) + amount * hit_scale()
	while float(state.dot) >= 1.0 and int(state.hp) > 0:
		state.dot = float(state.dot) - 1.0
		_lose_hp(1, why, Vector2.ZERO, true)
	if int(state.hp) <= 0:
		state.dot = 0.0


## The life the bar shows: the half hearts left minus what the damage over
## time already owes (src/ui/hud_kit.gd hero_panel hp_f).
func hp_f() -> float:
	return maxf(0.0, float(state.hp) - float(state.get("dot", 0.0)))


## Takes n half hearts: the flash, the hurt sounds, the feel; the phoenix or
## death at zero. `soft`: a tick of damage over time, shown without the punch.
func _lose_hp(n: int, why: String, from := Vector2.ZERO, soft := false) -> void:
	state.hp = maxi(0, state.hp - n)
	if not soft and from != Vector2.ZERO:
		camera_kick(Vector2(player.x, player.y) - from, "hero_hit")
	if soft:
		state.flash = maxf(float(state.get("flash", 0.0)), 0.12)
		if sound == null or not sound.dot_tick(why): _sound("hurt")
	elif feel != null:
		# the crypt's hurt: punch with its groan layer (feedback.gd), once; like the crypt
		# no red wash over the whole screen (the hero's flash, blood, shake and hitstop show it)
		feel.on_hurt(from)
		if sound != null and n >= 2: sound.hero("vo_hurt_heavy")
	else:
		state.flash = 0.25
		_sound("hurt")
		_sound("hurt_voice")
	if state.hp == 0 and state.get("phoenix_life", false):
		state.phoenix_life = false
		state.hp = maxi(2, state.max_hp / 2)
		state.inv = 2.0
		# effect hook: with the feel the crypt's revive marker (src/hero/story_feel.gd perk)
		if feel != null:
			feel.hero_perk("revive")
		else:
			_burst(Vector2(player.x, player.y - 40), 70, true)
		_sound("level_up")
		_toast("Der Phönix trägt dich zurück ins Leben!")
		return
	if state.hp == 0:
		state.dead = 1.8
		_gold_lost()
		if sound != null: sound.hero("vo_death")
		state.death_why = why
		_toast("Gestorben: %s." % why)


func _interactables() -> Array:
	var out: Array = []
	for e: Dictionary in W.ents:
		match e.type:
			"chest":
				if e.get("state", "") != "empty":
					out.append({"e": e, "label": "Beute nehmen" if e.get("state", "") == "open" else "Truhe öffnen", "p": Vector2(e.x, e.y - 20), "r": 120.0})
			"vault":
				if not e.get("opened", false):
					out.append({"e": e, "label": "Riesentresor öffnen", "p": Vector2(e.x, e.y - 30), "r": 170.0})
			"portal":
				var label := "Portal erloschen"
				if e.get("active", false):
					label = "Die Hölle verlassen" if W.final else "Portal zu Etage %d" % (state.floor + 1)
				out.append({"e": e, "label": label, "p": Vector2(e.x, e.y - 20), "r": 230.0})
			"brazier":
				# a cold bowl of the Frostgruft takes carried ember (frost_puzzles.gd)
				if not e.get("lit", false) and not e.get("cold", false):
					out.append({"e": e, "label": "Erst die Gegner besiegen" if W.rooms[e.room].fight else "Feuerschale entzünden", "p": Vector2(e.x, e.y - 30), "r": 115.0})
			# the world kit's key room, hidden stairs and their trigger
			"well":
				var fills: String = talents.resource_name() if talents != null else ""
				fills = ("%s und Abklingzeiten" % fills) if fills != "" else "Kräfte"
				out.append({"e": e, "label": "Brunnen: versiegt" if e.get("used", false) else "Brunnen: %s ganz auffüllen (einmal)" % fills, "p": Vector2(e.x, e.y - 30), "r": 150.0})
			"shop":
				out.append({"e": e, "label": "Händler: der Laden öffnet später", "p": Vector2(e.x, e.y - 30), "r": 150.0})
			"stairs":
				out.append({"e": e, "label": "Treppe: in eine frühere Etage hinab", "p": Vector2(e.x, e.y - 30), "r": 170.0})
			"lever":
				if not e.get("lit", false):
					out.append({"e": e, "label": "Erloschene Fackel anzünden", "p": Vector2(e.x, e.y - 20), "r": 115.0})
			"relic":
				if not e.get("taken", false):
					var label := "Versiegelt: die vier Platten in ihrer Reihenfolge betreten"
					if RelicKit.relic_free(self, e):
						label = (("Reliktruhe öffnen: %s" if e.get("chest", false) else "%s nehmen") % theme[e.item].name) if HeroKit.can_wield(self, e.item) else "Dieses Relikt gehört einer anderen Klasse"
					out.append({"e": e, "label": label, "p": Vector2(e.x, e.y - 30), "r": 150.0})
	for d: Dictionary in W.doors:
		var p := Vector2(d.cx, d.cy)
		if d.kind == "lock" and not d.unlocked:
			out.append({"e": d, "label": ("%s benutzen" if bool(state.keys.get(d.key, false)) else "Verschlossen: %s fehlt") % key_label(d.key), "p": p, "r": 190.0})
		elif d.kind == "puzzle" and _door_closed(d) and not W.rooms[d.a].fight and not W.rooms[d.b].fight:
			var g: Dictionary = W.groups[d.group]
			var label := "Gittertor: alle Feuerschalen der Etage entzünden" if g.get("spread", false) else ("Rätseltor: alle Feuerschalen entzünden" if g.kind == "braziers" else "Rätseltor: alle Runenplatten betreten")
			# a Frostgruft puzzle (frost_puzzles.gd): its own riddle opens it
			if g.kind == "frost":
				label = "Rätseltor: öffnet sich, wenn das Rätsel dieses Raums gelöst ist"
			if g.kind == "sequence" and g.has("count"):
				label = "Gittertor: die %d Druckplatten in der richtigen Reihenfolge betreten" % int(g.count)
			out.append({"e": d, "label": label, "p": p, "r": 190.0})
		elif d.kind == "boss" and _door_closed(d):
			out.append({"e": d, "label": "Versiegelt bis %s fällt" % W.boss.name, "p": p, "r": 190.0})
	out.append_array(frost_puzzles.interactables())
	out.append_array(hell_puzzles.interactables())
	return out


## The text of the Inschrift the hero stands at (within world_room_contents.json tablet.reach of
## its stone), "" when none is near. The HUD shows it while he stays there.
func inscription() -> String:
	var reach := float((RoomContents.cfg().get("tablet", {}) as Dictionary).get("reach", 150.0))
	var me := Vector2(player.x, player.y - 20.0)
	var best := ""
	var stone: Dictionary = {}
	for e: Dictionary in W.ents:
		if e.type == "tablet" and me.distance_to(Vector2(e.x, e.y - 20.0)) < reach:
			reach = me.distance_to(Vector2(e.x, e.y - 20.0))
			best = str(e.get("text", ""))
			stone = e
	# the Beuteordnung's fixed line: what the Schatz of this room pays (docs/BEUTEORDNUNG.de.md 7)
	if not stone.is_empty():
		for c: Dictionary in W.ents:
			if c.type == "chest" and c.has("hoard_tier") and not c.get("secret_find", false) and int(c.get("room", -1)) == int(stone.get("room", -2)):
				best += ("
" if not best.is_empty() else "") + RewardRules.reward_line(depth(), int(state.floor), int(c.hoard_tier))
				break
	return best


func _nearest() -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	var me := Vector2(player.x, player.y - 20)
	for it: Dictionary in _interactables():
		var dd := me.distance_to(it.p)
		if dd < it.r and dd < bd:
			bd = dd
			best = it
	return best


## A new run id (saves of this run carry it; the run's end deletes them).
func _new_run_id() -> String:
	return "%s-%d-%d" % [StorySave.mode(self), int(Time.get_unix_time_from_system()), randi() % 100000]


## Ends the run (docs/LAUF-DESIGN.de.md): `won` after the zone's final guardian,
## otherwise by death. The run's saves are deleted (saving only pauses a run);
## soul crystals already banked stay. The result panel waits for E (new run).
func end_run(won: bool) -> void:
	presentation.reset()
	if not (state.get("over", {}) as Dictionary).is_empty():
		return
	# a won run's saves are done with; a lost run keeps them: the character dies with its gold,
	# but a game saved earlier can be loaded again with the gold it had then
	if won:
		saves.erase_run(StorySave.mode(self), str(state.get("run_id", "")))
	run_slot = 0
	_story_progress(won)
	state.over = {"won": won, "why": str(state.get("death_why", "")), "floor": int(state.floor), "title": str(W.get("title", "")),
		"level": int(state.get("level", 1)), "crystals": int(state.get("crystals_run", 0))}
	mobs = []
	_mob_space.clear()
	eshots = []
	zones = []
	hold = {}
	dash = {}
	# a lost run already sounded the crypt's defeat when the hero fell (story_sound.gd phase "dead")
	if won or feel == null:
		_sound("run_won" if won else "hurt_voice")


## The result panel's rows for an ended run.
func run_result(over: Dictionary) -> Dictionary:
	var won := bool(over.get("won", false))
	var zone := str(theme.get("zone_name", "FROSTGRUFT" if StorySave.mode(self) == "frost" else "HÖLLE"))
	# both levels side by side, each with what becomes of it: the Laufstufe ends
	# with the run, the Heldenstufe (the profile's) stays
	var lines: Array = [["ZONE", zone], ["ERREICHT", "ETAGE %d · %s" % [int(over.floor), str(over.title).to_upper()]],
		["LAUFSTUFE", "%d · ENDET MIT DEM LAUF" % int(over.level)]]
	if not profile.is_empty():
		lines.append(["HELDENSTUFE", "%d · BLEIBT" % int(Profile.class_state(profile, class_id).level)])
	if not won and str(over.why) != "":
		lines.append(["URSACHE", str(over.why).to_upper()])
	# the profile keeps level, gold and soul shards (docs/TALENTE-SEELENSPLITTER.de.md)
	var note := ""
	if not profile.is_empty():
		# the character's gold stays with a win and is gone with a death; rune stones and shards stay
		var gold_note := ("%d GOLD VERLOREN" % int(state.get("gold_lost", 0))) if not won else ("%d GOLD" % gold_count())
		note = "%s · %d RUNENSTEINE · %d SEELENSPLITTER" % [gold_note, int(profile.get("runes", 0)), int(profile.shards.have)]
	return {"title": say("Die Hölle ist bezwungen").to_upper() if won else "LAUF BEENDET", "tone": "win" if won else "loss",
		"lines": lines, "note": note, "hints": ("E · WEITER IN STORY %d   ESC · MENÜ" % int(_next_story().get("number", 0))) if won and not _next_story().is_empty() and (_story_run() or debug_run) else "E · NEUER LAUF   ESC · MENÜ"}


## A new run of this zone from its first floor: the same scene and class, fresh.
func new_run() -> void:
	# a won story with a next one: the hero goes on there (docs/BEUTEORDNUNG.de.md 1.2)
	var next := _next_story()
	if bool((state.get("over", {}) as Dictionary).get("won", false)) and not next.is_empty() and ResourceLoader.exists(str(next.get("scene", ""))):
		var progress := StoryProgress.load_progress()
		var hero_next := StoryProgress.waiting(progress, class_id, int(next.number))
		if not hero_next.is_empty() or debug_run:
			var onward: Node = (load(str(next.scene)) as PackedScene).instantiate()
			onward.class_id = class_id
			onward.graphics_path = graphics_path
			onward.meta_path = meta_path
			onward.debug_run = debug_run
			onward.carry_hero = hero_next if not debug_run else {"done": int(state.get("chapters_done", 0)) + 1, "keep": _carry_keep(int(state.get("chapters_done", 0)) + 1)}
			var tree_next := get_tree()
			tree_next.root.add_child(onward)
			if tree_next.current_scene == self:
				tree_next.current_scene = onward
			queue_free()
			return
	var scene: Node = (load(scene_file_path) as PackedScene).instantiate()
	scene.class_id = class_id
	scene.debug_run = debug_run
	scene.graphics_path = graphics_path
	scene.meta_path = meta_path
	if not custom_story.is_empty():
		scene.custom_story = custom_story.duplicate(true)
		scene.custom_preview_room = custom_preview_room
		scene.custom_return_to_editor = custom_return_to_editor
		scene.custom_storage_root = custom_storage_root
		scene.profile_path = profile_path
		scene.settings_path = settings_path
	if not world_room.is_empty():
		scene.world_room = world_room
		scene.world_room_path = world_room_path
		scene.custom_storage_root = custom_storage_root
		scene.settings_path = settings_path
	var tree := get_tree()
	tree.root.add_child(scene)
	if tree.current_scene == self:
		tree.current_scene = scene
	queue_free()


## The stories of the main menu (assets/data/story_campaigns.json), playable ones only.
func _stories() -> Array:
	var data: Dictionary = DataCache.load_dict("res://assets/data/story_campaigns.json")
	return (data.get("stories", []) as Array).filter(func(s: Dictionary) -> bool: return bool(s.get("playable", false)) and s.has("scene"))


## This scene's story number (1 Krypta, 2 Frostgruft, 3 Hölle); 0 when it is none of them.
func story_number() -> int:
	for s: Dictionary in _stories():
		if str(s.scene) == scene_file_path:
			return int(s.get("number", 0))
	return 0


## The story after this one ({} for the last).
func _next_story() -> Dictionary:
	var me := story_number()
	for s: Dictionary in _stories():
		if int(s.get("number", 0)) == me + 1:
			return s
	return {}


## True for a real story run: the menu's story, not a debug, custom, Weltbauer or Testraum run.
func _story_run() -> bool:
	return not debug_run and custom_story.is_empty() and world_room.is_empty() and testraum.is_empty() \
		and custom_preview_room.is_empty() and story_number() > 0


## What a hero who just finished this story takes along: everything the run carries, the world's run
## number reset, `done` chapters finished.
func _carry_keep(done: int) -> Dictionary:
	var keep: Dictionary = (StorySave.capture(self).get("keep", {}) as Dictionary).duplicate(true)
	keep.chapters_done = done
	keep.world_run = 0
	keep.relic_floor = 0
	return keep


## The run ended: a win opens the next story and keeps the hero for it; a death loses the hero.
func _story_progress(won: bool) -> void:
	if not _story_run():
		return
	var progress := StoryProgress.load_progress()
	var stories := _stories()
	var last := 0
	for s: Dictionary in stories: last = maxi(last, int(s.get("number", 0)))
	if won:
		var done := int(state.get("chapters_done", 0)) + 1
		StoryProgress.on_win(progress, class_id, story_number(), _carry_keep(done), done, last, str(W.get("title", "")))
	else:
		StoryProgress.drop_hero(progress, class_id)
	StoryProgress.save_progress(progress)


## Uses whatever stands next to the hero (E / Space / Enter).
func act() -> void:
	if not (state.get("over", {}) as Dictionary).is_empty():
		new_run()
		return
	if state.dead > 0.0:
		return
	if state.won:
		_enter_floor(state.floor + 1, true)
		return
	var n := _nearest()
	if n.is_empty():
		return
	var e: Dictionary = n.e
	if e.has("type") and frost_puzzles.use(e):
		return
	if e.has("type") and hell_puzzles.use(e):
		return
	if e.has("type"):
		match e.type:
			"relic":
				if not RelicKit.relic_free(self, e) or not HeroKit.can_wield(self, e.item):
					_sound("no_cooldown")
					return
				e.taken = true
				state.relic = e.item
				state.relic_on = true
				_relic_texture()
				# effect hook: with the feel the crypt's pickup (loot_taken: its sheet and chime)
				if feel != null:
					feel.fx_event("loot_taken", Vector2(e.x, e.y - 40))
				else:
					_burst(Vector2(e.x, e.y - 50), 60, true)
					_sound("relic")
				var names: Array = (theme[e.item].skills as Array).map(func(s: Dictionary) -> String: return "%s (%s, ab Stufe %d)" % [s.short, s.key, int(s.unlock)])
				# a message, not a room banner (banners only for new rooms and floors)
				_toast("%s: %s · T wechselt" % [str(theme[e.item].name), " · ".join(PackedStringArray(names))])
			"chest":
				if e.get("mimic", false):
					_wake_mimic(e)
					return
				# effect hook: with the feel a chest opens like the crypt's (chest_open: splinters, the
				# pickup sheet and its sound) and its loot is taken like the crypt's (loot_taken)
				if feel == null:
					_sound("chest")
				if e.has("give"):
					world_room_drop(e.give, Vector2(e.x, e.y + 40.0), int(e.room))
				if e.has("enemies"):
					release_room_enemies(e.enemies, Vector2(e.x, e.y), int(e.room))
					e.erase("enemies")
				if e.loot.has("key"):
					e.state = "empty"
					state.keys[e.loot.key] = true
					if feel != null:
						feel.fx_event("chest_open", Vector2(e.x, e.y - 30))
					else:
						_burst(Vector2(e.x, e.y - 40), 30, true)
					_toast("Truhe geöffnet: %s genommen!" % key_label(e.loot.key))
				elif e.get("state", "") == "":
					# the gold flies out at once; a heart stays inside to be taken
					e.state = "open" if e.loot.get("heart", false) else "empty"
					if feel != null:
						feel.fx_event("chest_open", Vector2(e.x, e.y - 30))
					if e.has("hoard_tier"):
						_open_hoard(e)
						return
					gold_loot.spew(Vector2(e.x, e.y - 10), int(e.loot.gems))
					if not e.has("exact"):
						gold_loot.roll_rune("chest", Vector2(e.x, e.y - 10))
					_toast("Truhe geöffnet: %d Gold%s" % [e.loot.gems, " und ein Herz" if e.loot.get("heart", false) else ""])
					if e.has("hoard"):
						# the Schatz of a solved puzzle: every one of its item rolls, and the vault's rune chance
						_toast("Ein Schatz! Die Truhe ist randvoll.")
						# its heart containers raise the life cap at once (room_contents.gd hoard tiers)
						if int(e.get("hoard_hearts", 0)) > 0:
							var max_before := int(state.max_hp)
							state.max_hp = Rules.raised_max_hp(state, 2 * int(e.hoard_hearts), int(balance.player.max_hp_cap))
							state.hp = mini(int(state.max_hp), int(state.hp) + int(state.max_hp) - max_before)
							if int(state.max_hp) > max_before:
								_toast("+%d Herz%s: Deine Lebensgrenze steigt!" % [(int(state.max_hp) - max_before) / 2, "" if int(state.max_hp) - max_before <= 2 else "en"])
								if feel != null:
									feel.hero_perk("heal")
						gold_loot.roll_rune(str((RoomContents.cfg().get("hoard", {}) as Dictionary).get("rune", "vault")), Vector2(e.x, e.y - 10))
						if story_items != null:
							var k := 0
							for source: Variant in e.hoard:
								story_items.loot(str(source), Vector2(e.x - 60.0 + 60.0 * (k % 3), e.y + 40.0 + 30.0 * (k / 3)))
								k += 1
					elif story_items != null and not e.has("exact"):
						story_items.loot("chest", Vector2(e.x, e.y + 40))
				else:
					e.state = "empty"
					if feel != null:
						feel.fx_event("loot_taken", Vector2(e.x, e.y - 30))
					if e.loot.get("heart", false):
						state.hp = mini(state.max_hp, state.hp + RewardRules.heal(depth()))
						if feel != null:
							feel.hero_perk("heal")
			"vault":
				e.opened = true
				# the Schatztresor of the Beuteordnung (docs/BEUTEORDNUNG.de.md 5): double gold of loot value
				# depth + 4, a rune, a piece rare or better, a life heart like tier 3 and a heal heart
				var tier := int(e.get("tier", 4))
				var vault := RewardRules.special("vault")
				var vw := depth() + int(vault.get("value_add", 4))
				var gems: int = RewardRules.gold(vw) * int(vault.get("gold_mul", 2))
				gold_loot.spew(Vector2(e.x, e.y - 20), gems)
				gold_loot.spew_runes(Vector2(e.x, e.y - 20), int(vault.get("rune", 1)))
				var gained := gain_life(RewardRules.puzzle_life(depth(), int(vault.get("life_tier", 3))))
				for i in range(int(vault.get("heal", 1))):
					_drop("heart", int(e.get("room", state.room)), Vector2(e.x - 40.0 + 80.0 * i, e.y + 90.0))
				# effect hook: with the feel the vault opens like the crypt's chests (chest_open)
				if feel != null:
					feel.fx_event("chest_open", Vector2(e.x, e.y - 60), {"r": 24.0})
					feel.hero_perk("heal")
				else:
					_burst(Vector2(e.x, e.y - 60), 60 + maxi(0, tier - 4) * 10, true)
				_toast(Rules.vault_note(gained, gems))
				if story_items != null:
					story_items.reward_item(Vector2(e.x, e.y + 60), str(vault.get("min_rarity", "rare")), false, false)
			"portal":
				if e.get("active", false):
					_sound("stairs")
					_bank_crystals()
					if W.final:
						end_run(true)
						return
					state.won = true
					state.won_t = 0.0
					# the clone waits with its time left until Q on the next floor
					state.skill.active = false
					clone = {}
				else:
					_toast("Das Portal erwacht erst, wenn %s fällt." % W.boss.name)
			"brazier":
				if W.rooms[e.room].fight:
					_toast("Erst alle Gegner im Raum besiegen.")
					return
				_light_brazier(e)
			"well":
				# the mana fountain, once: the class's resource full (Mana, Ausdauer, Zorn) and every
				# cooldown reset, the skills' and the talents' (src/hell/hell_talents.gd refill)
				if e.get("used", false):
					_toast("Der Brunnen ist versiegt.")
					return
				e.used = true
				state.skill_cd = {}
				var res_name := ""
				if talents != null and talents.refill():
					res_name = talents.resource_name()
				_burst(Vector2(e.x, e.y - 70), 36)
				_sound("relic")
				_toast(("%s vollständig aufgefüllt, alle Abklingzeiten zurückgesetzt. Der Brunnen versiegt." % res_name) if res_name != "" else "Kräfte vollständig aufgefüllt. Der Brunnen versiegt.")
			"shop":
				_toast("Der Händler nickt. Sein Laden öffnet bald.")
			"stairs":
				_open_stairs()
			"lever":
				# the extinguished torch: lit, it opens the hidden wall of the stairs somewhere in the room
				e.lit = true
				W.lights.append({"x": e.x, "y": e.wy + 40, "r": 230, "c": "255,150,70"})
				_burst(Vector2(e.x, e.wy + 30), 14)
				_solve_group(e.group)
		return
	if e.kind == "lock":
		if bool(state.keys.get(e.key, false)):
			state.keys[e.key] = false
			state.used[e.key] = true
			e.unlocked = true
			_sound("gate_open")
			_toast("Das Tor öffnet sich.")
		else:
			_sound("gate_locked")
			_toast("%s %s" % [key_label(e.key), str(key_hint.get(e.key, key_hint.get(str(e.key).right(1), "")))])


## The floor key whose look key k takes: k itself (A, B, C), or the letter of a room's own key ("15A").
func key_letter(k: Variant) -> String:
	var id := str(k)
	return id if key_sprite.has(id) or not key_sprite.has(id.right(1)) else id.right(1)


## The name of key `k`: a floor key A, B or C, or a room's own key ("4A": key A of room 4 of a floor,
## room_floor.gd own_key) by its letter.
func key_label(k: String) -> String:
	return str(key_name.get(k, key_name.get(k.right(1), "Schlüssel")))


func _open_secret(d: Dictionary) -> void:
	d.broken = true
	# a wall gives way like the crypt's: a wall_break fx event per broken cell, as src/game.gd
	# walls_broken sends them (rubble, dust, a shake and its sound through feedback.gd)
	if feel != null:
		for c: Vector2i in d.cells:
			feel.fx_event("wall_break", Vector2((c.x + 0.5) * C, (c.y + 0.5) * C))
	else:
		_sound("secret")
	for c: Vector2i in d.cells:
		W.grid[c.y * W.cols + c.x] = 1
	# the opened cells are floor for the crypt's rubble and marks now (like the crypt's new layout)
	if feel != null:
		feel.open_cells(d.cells)
	walls = Walls.build(W.grid, W.cols, W.rows, C, W.get("doorways", []))
	if frost_snow != null:
		frost_snow.walls_changed()
	for node: Layer in _chunk_nodes:
		node.queue_redraw()


func _solve_group(group: String) -> void:
	var g: Dictionary = W.groups[group]
	g.solved = true
	_sound("puzzle_solved")
	if g.get("reward", "") == "relic":
		for e: Dictionary in W.ents:
			if e.type == "relic" and e.seal == group:
				# effect hook: with the feel the crypt's golden level-up sheet (silent: puzzle_solved sounds)
				if feel != null:
					feel.spawn("level_up", Vector2(e.x, e.y - 20), 1.2)
				else:
					_burst(Vector2(e.x, e.y - 50), 50, true)
		_toast("Das Gravitationssiegel bricht. Ein Stab liegt frei!")
		return
	# the pads that slept for this group wake with a flash
	var woke := 0
	for e: Dictionary in W.ents:
		if e.type == "launch" and str(e.get("wake", "")) == group:
			woke += 1
			if feel != null:
				feel.spawn("level_up", Vector2(e.x, e.y), 0.6)
			else:
				_burst(Vector2(e.x, e.y - 20), 16, true)
	if woke > 0 and not W.doors.any(func(d: Dictionary) -> bool: return str(d.get("group", "")) == group):
		_toast("Ein Beben geht durch den Raum: %s." % ("eine Sprungplatte erwacht" if woke == 1 else "%d Sprungplatten erwachen" % woke))
		return
	var opened := false
	for d: Dictionary in W.doors:
		if d.kind == "secret" and d.group == group:
			_open_secret(d)
			opened = true
	if opened:
		_toast("Die Fackel flammt auf. Irgendwo im Raum knirscht Stein: ein verborgener Gang ist offen." if g.kind == "lever" else "Ein verborgener Gang öffnet sich. Ein Geheimraum ist erreichbar.")
	elif g.get("reward", "") == "chest":
		var at: Dictionary = {}
		for e: Dictionary in W.ents:
			if e.get("group", "") == group and (at.is_empty() or int(e.get("order", 0)) == 5):
				at = e
		var loot := {"gems": int(balance.sequence_chest.gems_base) + state.floor, "heart": bool(balance.sequence_chest.heart)}
		var chest := {"type": "chest", "x": at.x, "y": at.y + 10.0, "room": at.room, "loot": loot, "magic": true}
		W.ents.append(chest)
		_add_solid(Rect2(chest.x - 40, chest.y - 32, 80, 32))
		# effect hook: with the feel the reward chest rises from the crypt's dust (enemy_spawn) in a golden sheet
		if feel != null:
			feel.fx_event("enemy_spawn", Vector2(chest.x, chest.y - 10))
			feel.spawn("level_up", Vector2(chest.x, chest.y), 1.2)
		else:
			_burst(Vector2(at.x, at.y - 40), 40, true)
		_toast("Die Platten glühen auf. Eine Belohnungstruhe erscheint!")
	elif g.kind == "braziers":
		_toast("Alle Feuerschalen brennen. Das Gitter zum Riesentresor hebt sich!" if g.get("spread", false) else "Alle Schalen brennen. Das Tor hebt sich.")
	else:
		_toast("Alle Runen leuchten. Das Tor öffnet sich.")


## Fires the class weapon towards `dir`; `to_cursor`: `dir` reaches from the staff to the
## point the mouse shows, where the mage's shot bursts (MageBolt.aim).
func _fire(dir: Vector2, to_cursor := false) -> void:
	if state.cool > 0.0 or dir == Vector2.ZERO or not hold.is_empty() or not FrostCombat.can_attack(self):
		return
	_attack(dir, dir.length() if to_cursor else -1.0)
	if state.cool > 0.0:
		state.cool *= FrostCombat.rate(self) * (talents.interval_scale() if talents != null else 1.0)


## One attack of the class weapon (or the relic) towards `dir`. The mage's shot bursts
## `reach` px out (the mouse's distance; -1: at the end of its flight).
func _attack(dir: Vector2, reach := -1.0) -> void:
	if talents != null and (talents.tc.runtime(1).has("soul_charge") or talents.tc.runtime(1).has("soul_leap")): return
	state.cool = float(state.rate) * HeroKit.rate_scale(self) * CardKit.rate_mult(self)
	player.aim = dir.normalized()
	if absf(dir.x) > 0.01:
		player.face = signf(dir.x)
	if as_source("hero", func() -> bool: return RelicKit.attack(self, dir.normalized()) or SubKit.attack(self, dir.normalized())):
		return
	# the class weapon: with the feel the crypt's feedback.gd sounds each swing and shot (story_hero counts them)
	if weapon.get("type", "") == "melee":
		_swing(dir.normalized())
		if feel == null:
			_sound("swing")
		return
	var v := dir.normalized() * float(weapon.get("speed", balance.shot.speed))
	var bolt := {"p": Vector2(player.x, player.y - 40), "v": v, "t": float(state.range), "kind": str(weapon.get("shot", "")), "splash": float(weapon.get("splash", 0.0)), "hits": []}
	# the mage's left-click follows his element (src/vfx/mage_bolt.gd, mage_bolts.json): fire the small
	# fireball that bursts where it strikes (user wish 30.10.2026), frost an icicle, void a void orb,
	# before any talent a plain arcane bolt
	if class_id == "mage" and str(weapon.get("shot", "")) == "magic":
		# The user's standard auto-hit stays neutral; fireball is a learned talent.
		MageBolt.arm(self, bolt, "")
	# a perfect roll's counter (src/hell/hero_kit.gd arm_counter): this shot hits harder
	HeroKit.arm_counter(self, bolt)
	# the mage's shot bursts on the floor where the mouse points, within its flight (user wish
	# 02.11.2026): unless an enemy or a wall stops it first
	if class_id == "mage" and str(weapon.get("shot", "")) == "magic":
		var flight := (bolt.v as Vector2).length() * float(bolt.t)
		MageBolt.aim(bolt, MageBolt.land_reach(reach if reach >= 0.0 else flight, flight))
	shots.append(bolt)
	story_hero.on_shot()
	if feel == null:
		_sound("shot_arrow" if weapon.get("shot", "") == "arrow" else "shot_magic")


## Sword: hits every enemy and breakable within reach whose direction lies inside the arc.
## The hero steps into it; Rage throws bodies and swings again the other way (mirrored).
func _swing(dir: Vector2, mirrored := false) -> void:
	story_hero.on_swing(dir, mirrored)
	var from := Vector2(player.x, player.y - 40)
	var reach := float(weapon.reach)
	var half := float(weapon.arc) / 2.0
	swing = {"a": dir.angle(), "t": 0.16}
	# effect hook: the blade meeting a wall in front clangs like the crypt's (perk_combat.gd: metal wall hit)
	if feel != null:
		feel.swing_wall(from, dir, reach)
	for m: Dictionary in mobs:
		var to: Vector2 = m.p - Vector2(0, m.cy) - from
		# Ignaroth's rig: the blade's arc must meet a part where it is drawn; that part takes the hit (src/hell/drake_rig_host.gd)
		var rigged: bool = drake_rig != null and drake_rig.has_rig(m)
		if _hittable(m) and (drake_rig.swing_hits(m, from, dir, reach, half) if rigged else to.length() < reach + m.r and absf(angle_difference(dir.angle(), to.angle())) <= half):
			if _damage_mob(m, dir * 600.0):
				story_hero.rage_throw(m, dir)
	for e: Dictionary in breakables:
		var to := Vector2(e.x, e.y - 40) - from
		if not e.get("broken", false) and to.length() < reach + 40.0 and absf(angle_difference(dir.angle(), to.angle())) <= half:
			_hit_breakable(e, Vector2(e.x, e.y - 40))
	if wreck != null:
		wreck.swing(from, dir, reach, half)


## Deals the hero's damage (times mult, e.g. a skill's multiple); a shield bearer
## facing the hit blocks it (returns false).
func _damage_mob(m: Dictionary, push: Vector2, mult := 1.0) -> bool:
	# Ignaroth's rig: the part a shot, blade or blast aimed at, taken out here so a refused hit leaves none behind
	var rig_part: String = drake_rig.take_aim(m) if drake_rig != null else ""
	# no skill, swing or blast reaches a hell monster that cannot be hit (flying, burrowed, transforming)
	if monsters != null and monsters.immune(m):
		return false
	var def: Dictionary = m.def
	var arc := float(def.shield_arc) if def.get("behavior", "") == "shield" else float(m.get("kit", {}).get("shield_arc", 0.0))
	if arc > 0.0 and push != Vector2.ZERO and MobRules.shield_blocks(m.face, push, arc):
		# with the feel the block is the crypt's alone (its sparks, flash and sound: feedback.gd)
		if feel != null:
			feel.on_block(m)
		else:
			_burst(m.p - Vector2(0, m.cy), 6, true)
			_sound("block")
		return false
	var factor := BossKit.damage_factor(self, m) if m.has("kit") else 1.0
	if factor <= 0.0:
		return false
	var item_crit: float = story_items.crit_mult() if story_items != null else 1.0
	var crit: float = HeroKit.crit(self) * item_crit
	var dealt: float = float(state.dmg) * factor * mult * crit * CardKit.damage_mult(self) * SubKit.factor(self, m) * FrostCombat.hit_factor(self, m)
	if talents != null: dealt = talents.basic_hit(m, dealt)
	# Ignaroth's rig: the aimed part takes it (unaimed hits land on the body); all of it counts against m.hp (src/hell/drake_rig_host.gd)
	if drake_rig != null:
		drake_rig.damage(m, dealt, rig_part)
	else:
		m.hp -= dealt
	if on_hero_hit.is_valid():
		on_hero_hit.call(m, dealt, crit > 1.0)
	if story_items != null and mult > 0.0:
		story_items.on_hit(m)
	# with the feel the hit sounds in the monster's crypt material (feedback.gd via FrostCombat.after_hit)
	if feel == null:
		_sound("hit_" + str(def.get("material", "void")))
	m.hit = 0.12
	# kit bosses stand firm: no knockback
	# the blow's push adds to what pushes it already, less on a heavier body (its radius over
	# push.mass_ref_r, squared; physics plan R23/F44, decision D5), at most push.max px/s
	if m.has("kit"):
		m.k = Vector2.ZERO
	else:
		var pcfg: Dictionary = motion_kit().cfg.get("push", {})
		var mass := body_mass(m)
		var now: Vector2 = m.get("k") if m.get("k") is Vector2 else Vector2.ZERO
		m.k = (now + push * (0.05 if m.kind == "boss" else 0.25) / mass).limit_length(float(pcfg.get("max", 1000.0)))
	FrostCombat.after_hit(self, m, push, crit > 1.0)
	if sound != null: sound.mob_hurt(m)
	if feel != null:
		# effect hooks: a critical hit's gold ring (the crypt's crit marker); a charge (hero_kit.gd
		# _update_dash: its push and multiple) striking through is the crypt's charge_hit
		if crit > 1.0:
			feel.mob_perk("crit", m)
		if not dash.is_empty() and float(dash.get("mult", 0.0)) > 0.0 and is_equal_approx(mult, float(dash.mult)) and push.is_equal_approx((dash.dir as Vector2) * 500.0):
			story_hero.skill_fx.event("charge_hit", [story_hero.skill_fx.body(m.p - Vector2(0, m.cy))], {"time": 0.25, "length": 0.25})
	return true


## True when an enemy can take a hit now: grown in, not faded out, and (hell monsters)
## not arriving, flying, burrowed, transforming or dying.
func _hittable(m: Dictionary) -> bool:
	return m.spawn <= 0.0 and float(m.get("alpha", 1.0)) > 0.5 and (monsters == null or not monsters.immune(m))


## An enemy kind's values: the theme's own kinds first (theme.mobs), else hell_balance.json.
func _mob_def(kind: String) -> Dictionary:
	var themed: Dictionary = theme.get("mobs", {})
	return themed[kind] if themed.has(kind) else balance.mobs[kind]


func _spawn_mob(room: int, pos: Vector2, kind: String) -> void:
	if sound != null: sound.at("enemy_spawn", pos)
	var def := _mob_def(kind)
	var diff: Dictionary = W.diff
	var hp: float = (float(W.boss.hp) if kind == "boss" else round(float(def.hp) * float(diff.hp))) * monster_hp_scale()
	var scale := float(def.get("scale", 1.0))
	if kind == "boss" and (W.boss.get("mini", false) or W.final):
		scale *= 1.25 if W.final else 1.05
	# themed look: the kind's sprite, or the floor's guardian (theme.bosses) for the boss
	var look: Dictionary = theme.get("bosses", {}).get(str(state.floor), {}) if kind == "boss" else (def if def.has("sprite") else {})
	var draw_scale := float(look.get("scale", 1.0))
	var cy := 30.0 * scale
	if look.has("sprite") and tex.has(MobRules.frame_name(look, 0)):
		cy = (tex[MobRules.frame_name(look, 0)] as Texture2D).get_height() * draw_scale * 0.5
	mobs.append({"room": room, "kind": kind, "p": pos, "hp": hp, "max": hp, "sp": float(def.speed) * float(diff.speed),
		"s": scale, "r": float(def.radius), "seed": randf() * 9.0, "k": Vector2.ZERO, "hit": 0.0, "spawn": 0.5,
		"summon": 2.5, "shoot": 1.0 + randf() * 2.0, "ring_t": float(W.boss.get("ring", 0.0)), "spin": 0.0,
		"def": def, "look": look, "ds": draw_scale, "cy": cy, "face": Vector2.RIGHT,
		"dash": 0.0, "dash_t": float(def.get("dash_every", 0.0)) * randf(), "dash_dir": Vector2.ZERO})
	var kits: Dictionary = theme.get("boss_kits", {})
	if kind == "boss" and kits.has(str(state.floor)):
		var m: Dictionary = mobs[mobs.size() - 1]
		BossKit.setup(m, kits[str(state.floor)], hp)
		var first := MobRules.frame_name(m.look, 0)
		if tex.has(first):
			m.cy = (tex[first] as Texture2D).get_height() * float(m.look.get("scale", 1.0)) * 0.5
			m.ds = float(m.look.get("scale", 1.0))
	mob_moved(mobs.back())


func _start_fight(r: Dictionary) -> void:
	r.fight = true
	# a room file's own monsters stand where they were placed (world_room_floor: placed_mobs)
	if not (r.get("placed_mobs", []) as Array).is_empty() and world_room.is_empty():
		for m: Dictionary in r.placed_mobs:
			var at := Vector2(float(m.x), float(m.y))
			if monsters != null and (monsters.defs as Dictionary).has(str(m.mob)):
				monsters.spawn(int(r.index), at, str(m.mob))
			elif theme.has("mobs") and (theme.mobs as Dictionary).has(str(m.mob)):
				_spawn_mob(int(r.index), at, str(m.mob))
		# a set enemy this world does not know must not leave the gates shut for good: then by chance
		if not mobs.is_empty():
			_toast("Die Gitter fallen. Besiege alle Gegner.")
			_sound("fight_start")
			return
	var me := Vector2(player.x, player.y)
	var cells: Array = []
	for c: Vector2i in r.cells:
		var p := Vector2((c.x + 0.5) * C, (c.y + 0.7) * C)
		if W.grid[c.y * W.cols + c.x] == 1 and p.distance_to(me) > 4.5 * C and not _near_door(r, p, 2.0) and solid_grid.get(c.y * W.cols + c.x, []).is_empty():
			cells.append(p)
	cells.shuffle()
	# Authored encounter markers lead; valid fallback cells still prevent empty encounters.
	if r.has("spawn_cells"):
		var authored: Array = []
		for cell: Array in r.spawn_cells:
			var point := Vector2((float(cell[0]) + 0.5) * C, (float(cell[1]) + 0.7) * C)
			if _room_at_world(point.x, point.y) == int(r.index) and not box_blocked(Rect2(point - Vector2(28, 20), Vector2(56, 24)), true) \
					and point.distance_to(me) > C * 1.5 and not _near_door(r, point, 1.0):
				authored.append(point)
		for point: Vector2 in cells:
			if not authored.has(point): authored.append(point)
		cells = authored
	# with the feel every fight locks its doors and a guardian's arrival stings once (feedback.gd boss_intro), like the crypt
	if monsters != null:
		monsters.populate(r, cells)
		_sound("boss_intro" if r.type == "boss" and feel == null else "fight_start")
		return
	var count: int = int(r.mobs if r.mobs > 0 else 3) + int(W.diff.extra)
	var rolls: Array = []
	for k in range(count):
		rolls.append(randf())
	var themed := MobRules.pick_kinds(theme.get("roster", []), state.floor, rolls)
	for k in range(mini(count, cells.size())):
		var kind := "glut"
		if not themed.is_empty():
			kind = themed[k]
		elif W.diff.get("shooters", false) and k % 4 == 1:
			kind = "spucker"
		elif k % 3 == 2:
			kind = "gross"
		_spawn_mob(r.index, cells[k], kind)
	if r.type == "boss":
		_spawn_mob(r.index, Vector2((r.bx + r.bw / 2.0) * C, (r.by + r.bh / 2.0 + 1.0) * C), "boss")
		_toast("%s erwacht. Die Tore sind verriegelt." % W.boss.name)
		_sound("boss_intro" if feel == null else "fight_start")
	else:
		_toast("Die Gitter fallen. Besiege alle Gegner.")
		_sound("fight_start")


func _clear_room(r: Dictionary, at: Vector2) -> void:
	r.fight = false
	r.cleared = true
	# a room cleared a second time (seal demons) gives no second key or reward
	var again: bool = r.get("rewarded", false)
	r.rewarded = true
	# with the feel the crypt's room-clear sting comes from feedback.gd (phase combat -> reward) and a
	# guardian's fall from its boss_kill; like the crypt only the last guardian (the crypt's void boss)
	# and the mini guardians (its minibosses) add the victory tune
	if r.type == "boss":
		if feel == null or W.final or W.boss.get("mini", false):
			_sound("boss_dead")
	elif feel == null:
		_sound("room_clear")
	# every mimic woken here pays once (rare+, items.json drops.mimic) where it fell; not gated on
	# `again`: a chest opened after the room was cleared wakes its mimic in a rewarded room
	if story_items != null:
		for mimic: Dictionary in r.get("mimic_loot", []):
			story_items.loot("mimic", mimic.get("p", at))
	# what the chest was set to hold (a key, say) is not lost with the chest
	for mimic: Dictionary in r.get("mimic_loot", []):
		for held: Dictionary in mimic.get("chest_holds", []):
			world_room_drop(held, mimic.get("p", at), int(r.index))
	r.mimic_loot = []
	if r.drop != "" and not again:
		_drop("key", r.index, at, {"key": r.drop})
		_toast("Raum gesäubert. %s gefallen!" % key_name[r.drop])
	elif r.type == "boss":
		state.boss_dead = true
		RelicKit.drop(self, at)
		# the Beuteordnung (docs/BEUTEORDNUNG.de.md 5): a guardian leaves a piece (epic deeper down) and a
		# life heart; the final guardian its one legendary piece and two rune stones
		if story_items != null:
			if W.final:
				# its two rune stones come with its fall (loot_runes.json final)
				story_items.final_drop(at)
			else:
				story_items.guardian_drop(at, bool(W.boss.get("mini", false)))
		if not W.final:
			drop_life_heart(RewardRules.guardian_life(), int(r.index), at + Vector2(0, 60))
		eshots = []
		zones = []
		state.storm = false
		for e: Dictionary in W.ents:
			if e.type == "portal":
				e.active = true
		if state.floor == int(balance.clone.floor) and not state.skill.owned:
			state.skill = {"owned": true, "active": false, "left": float(balance.clone.duration)}
			_toast("Neuer Skill: Klon rufen (Q) – 2 Minuten Kampfgefährte.")
		else:
			_toast("%s fällt. Die Portalkammer ist offen." % W.boss.name)
	else:
		_toast("Raum gesäubert. Die Gitter heben sich.")
	if again:
		return
	if r.reward != null:
		if r.reward.get("heart", false):
			_drop("heart", r.index, at)
		gold_loot.spew(at, int(r.reward.get("gems", 0)))
	elif randf() < float(balance.drops.heart):
		_drop("heart", r.index, at)
	elif randf() < float(balance.drops.gem):
		_drop("gem", r.index, at)


func _drop(kind: String, room: int, at: Vector2, extra := {}) -> void:
	# gold is thrown out as coins (src/hell/gold_loot.gd), the rest lies as a pickup
	if kind == "gem":
		gold_loot.spew(at, 1)
		return
	if sound != null: sound.at("drop_" + kind, at)
	var e := {"type": kind, "x": at.x + randf_range(-30, 30), "y": at.y + randf_range(-20, 20), "room": room}
	# a key must be taken, or the floor cannot be finished: it lies on free floor of its room even
	# when the last monster fell over a pit, in the Moder or against a wall
	if kind == "key":
		var safe := _free_drop_spot(room, Vector2(e.x, e.y))
		e.x = safe.x
		e.y = safe.y
	e.merge(extra)
	W.ents.append(e)


## `p` when the hero can stand there in room `room` (no wall, pit, Moder or solid piece, and clear of the
## fall pits by their reach and a step more), else the middle of the nearest cell of that room where he can.
func _free_drop_spot(room: int, p: Vector2) -> Vector2:
	var reach := Vector2(float(balance.pit.reach_x), float(balance.pit.reach_y)) + Vector2(24.0, 24.0)
	var fits := func(q: Vector2) -> bool:
		for e: Dictionary in pits:
			if absf(q.x - float(e.x)) < reach.x and absf(q.y - 8.0 - float(e.y)) < reach.y:
				return false
		return _room_at_world(q.x, q.y) == room and not box_blocked(Rect2(q.x - 22.0, q.y - 12.0, 44.0, 24.0), true)
	if fits.call(p):
		return p
	var best := p
	var bd := INF
	if room >= 0 and room < W.rooms.size():
		for c: Vector2i in W.rooms[room].cells:
			var q := Vector2((c.x + 0.5) * C, (c.y + 0.5) * C)
			var d := q.distance_squared_to(p)
			if d < bd and fits.call(q):
				bd = d
				best = q
	return best


## The character's gold: the run's own (a new character starts with 0), carried from floor to
## floor and kept in its saved games (src/save/story_save.gd CARRIED); gone when it dies or is
## left unsaved. The round shop will take it.
## The Schatz of a solved puzzle or a found room (docs/BEUTEORDNUNG.de.md 3, 4): gold by loot value, heal
## hearts and a life heart lying before it, the rune chance, its guaranteed pieces (the best one may turn
## legendary by the map), plain chest rolls and stones. `hoard_shift` (blood price paths) moves the tier,
## `legendary_twice` gives the map a second chance, `no_legendary` keeps it out.
func _open_hoard(e: Dictionary) -> void:
	var t := depth()
	var floor_number := int(state.floor)
	var tier_n := clampi(int(e.hoard_tier) + int(e.get("hoard_shift", 0)), 1, 5)
	var spec := RewardRules.tier(tier_n)
	var w := RewardRules.value(t, tier_n)
	var at := Vector2(e.x, e.y)
	gold_loot.spew(at - Vector2(0, 10), RewardRules.gold(w))
	for i in range(int(spec.get("heal", 1))):
		_drop("heart", int(e.get("room", state.room)), at + Vector2(-50.0 + 50.0 * i, 70.0))
	drop_life_heart(RewardRules.puzzle_life(t, tier_n), int(e.get("room", state.room)), at + Vector2(0, 110))
	if story_items != null and story_items.inventory.roll01() < float(spec.get("rune", 0.0)):
		gold_loot.spew_runes(at - Vector2(0, 10), 1)
	var leg := RewardRules.legendary(floor_number, tier_n) if not e.get("no_legendary", false) else {"p": 0.0, "sure": false}
	var minimum := RewardRules.min_rarity(w)
	var got: Array = []
	if story_items != null:
		var k := 0
		for i in range(int(spec.get("guaranteed", 1))):
			var rarity := RewardRules.rarity_up(minimum) if bool(spec.get("up_one", false)) and i == 0 else minimum
			var lp := float(leg.p) if i == 0 else (float(leg.p) if e.get("legendary_twice", false) and i == 1 else 0.0)
			got.append(story_items.reward_item(_hoard_spot(e, k), rarity, i < int(spec.get("own", 0)), bool(spec.get("clean", false)), lp, bool(leg.sure)))
			k += 1
		for i in range(int(spec.get("extra", 0))):
			story_items.loot("chest", _hoard_spot(e, k))
			k += 1
		for kind: Variant in spec.get("stones", []):
			story_items.reward_stack(_hoard_spot(e, k), str(kind))
			k += 1
	var note := "Schatz der Stufe %d: %d Gold" % [tier_n, RewardRules.gold(w)]
	if "legendary" in got:
		note = "Ein legendäres Stück! " + note
		_sound("level_up")
	_toast(note)
	if feel != null:
		feel.hero_perk("heal")


## Where the k-th find of a Schatz lands: rows of three before the chest.
func _hoard_spot(e: Dictionary, k: int) -> Vector2:
	return Vector2(e.x - 60.0 + 60.0 * (k % 3), e.y + 40.0 + 30.0 * floorf(k / 3.0))


## Depth of this floor (docs/BEUTEORDNUNG.de.md 1.4): floor + 10 x the chapters this hero already finished.
func depth() -> int:
	return RewardRules.depth(int(state.get("floor", 1)), int(state.get("chapters_done", 0)))


## Monster and boss HP factor: the difficulty's (talents) times the chapter hardness of a carried hero.
func monster_hp_scale() -> float:
	return (talents.hp_scale() if talents != null else 1.0) * RewardRules.chapter_hp(int(state.get("chapters_done", 0)))


## LP one hit is worth here (every blow, shot, trap and flame on the hero counts this many times).
func hit_scale() -> int:
	return RewardRules.dmg(depth())


## The life cap here (20 hits); gear hearts sit on top as before.
func life_cap() -> int:
	return RewardRules.cap(depth())


## A life heart worth `lp`: the cap rises by it (up to life_cap) and the hero heals the same.
func gain_life(lp: int) -> int:
	var before := int(state.max_hp)
	state.max_hp = maxi(before, mini(life_cap(), before + lp))
	state.hp = mini(int(state.max_hp), int(state.hp) + lp)
	return int(state.max_hp) - before


## Drops a life heart worth `lp` at `at` in room `room` (golden, always taken).
func drop_life_heart(lp: int, room: int, at: Vector2) -> void:
	if lp <= 0:
		return
	_drop("life_heart", room, at, {"value": lp})


func gold_count() -> int:
	return int(state.get("gold", 0))


## The account's rune stones (they pay the talent reset; every character shares them).
func rune_count() -> int:
	return int(profile.get("runes", 0))


## Gold taken (src/hell/gold_loot.gd, a kill, a floor): to the character.
func add_gold(n: int) -> void:
	state.gold = maxi(0, int(state.get("gold", 0)) + n)


## A rune stone taken (src/hell/gold_loot.gd): to the account, saved at once (they are rare,
## and leaving for the menu right after must not lose them).
func add_runes(n: int) -> void:
	if profile.is_empty():
		return
	Profile.add_runes(profile, n)
	Profile.save_profile(profile, profile_path)


## The hero fell: the character's gold is gone at once, and so is the gold still lying on the
## floor (its saved games keep the gold they had). The profile is saved now (rune stones, EXP).
func _gold_lost() -> void:
	state.gold_lost = int(state.get("gold", 0))
	state.gold = 0
	gold_loot.reset()
	if not profile.is_empty():
		Profile.save_profile(profile, profile_path)


## Leaving the world (the menu, a closed window): the profile's last seconds (EXP, rune stones,
## talents) are saved, not lost with the scene.
func _exit_tree() -> void:
	HudKit.map_corner = true
	presentation.reset()
	if talents != null:
		talents.save()
	elif not profile.is_empty():
		Profile.save_profile(profile, profile_path)


func _enemy_shot(from: Vector2, dir: Vector2, speed: float, by: Dictionary = {}) -> void:
	# WAHN: a mad enemy's shots scatter (a boss's less); a turned one's hurt the enemies they meet
	if not _mad_mob.is_empty():
		dir = ElementRules.scatter(dir.normalized(), _mad_mob.kind == "boss", randf())
	# "by": its shooter (B3: a perfect block lets it reel only in melee reach)
	eshots.append({"p": from, "v": dir.normalized() * speed, "t": float(balance.enemy_shot.life), "by": by})
	if not _mad_prey.is_empty():
		eshots[-1].mad = _mad_mob


func _burst(at: Vector2, n: int, gold := false) -> void:
	# effect hook: with the feel a level-up is the crypt's (its sheet, pillar, ring and bloom:
	# src/hero/story_feel.gd), so hero_kit.gd _level_up's gold embers (raised as levelfx starts) stay out
	if feel != null and gold and not levelfx.is_empty() and float(levelfx.t) == 0.0 and at.is_equal_approx(Vector2(player.x, player.y - 50)):
		return
	if gold and sound != null: sound.at("gold_burst", at)
	for k in range(n):
		embers.append({"p": at, "v": Vector2(randf_range(-150, 150), randf_range(-210, 90)), "t": randf_range(0.35, 0.85), "big": n > 20, "gold": gold})


# ---------- seals, skull heaps, pits and the clone ----------

## A fire bowl `e` catches fire: its light, its burst, the puzzle's progress (by hand with E, or
## by a fire shot that hits it directly: fire_hits_brazier).
func _light_brazier(e: Dictionary) -> void:
	e.lit = true
	e.lit_at = float(state.t)
	W.lights.append({"x": e.x, "y": e.y - 70, "r": 280, "c": "255,140,60"})
	# glow hook: the bowl catches fire in a crypt burst (its bloom and light: src/hero/story_glow.gd)
	if feel != null:
		feel.spawn("frost_burst" if bool(W.theme.get("frost", false)) else "fire_burst", Vector2(e.x, e.y - 70), 0.8)
	var prog := Rules.group_progress(W.ents, e.group)
	if prog.x == prog.y:
		_solve_group(e.group)
	else:
		_toast("Feuerschale %d von %d entzündet." % [prog.x, prog.y])


## A fire shot struck `at` (physics plan R21, decision D7): an unlit fire bowl it hit directly
## catches fire as if lit by hand, never in a fight, and only the one it hit (one blast never
## lights a whole puzzle out of order).
func fire_hits_brazier(at: Vector2) -> void:
	for e: Dictionary in W.ents:
		if e.type != "brazier" or e.get("lit", false) or e.get("cold", false): continue
		if not Rect2(e.x - 36, e.y - 44, 72, 54).has_point(at): continue
		if W.rooms[e.room].fight: return
		_light_brazier(e)
		return


func _hit_breakable(e: Dictionary, at: Vector2) -> void:
	if sound != null and str(e.get("type", "")) != "skullheap": sound.at("breakable_hit", at)
	e.hit = 0.15
	# effect hook: with the feel a blow chips stone like the crypt's chests take a hit (a small burst sheet;
	# the heap or seal shakes like skill_fx.gd draw_chest: _draw_breakable)
	if feel != null:
		feel.spawn("stone_burst", at, 0.8)
	else:
		_burst(at, 8)
	# skulls clack like the crypt's bone; the crypt has no fx event for a blow on a heap (its crates break
	# at once), so only this clack is the world's own; the heap's fall is the crypt's wall_break (_open_secret)
	if feel != null and e.type == "skullheap":
		_play_sfx("hit_bone")
	if not Rules.hit_breakable(e):
		return
	if wreck != null:
		wreck.smash_ent(e, at)
	# its fall: the crypt's stone burst where it stood (silent: the wall_break, blessing or demons sound)
	if feel != null:
		feel.spawn("stone_burst", Vector2(e.x, e.y - 30), 1.6)
	else:
		_burst(Vector2(e.x, e.y - 40), 40)
	if e.type == "crate":
		_break_crate(e)
	elif e.type == "skullheap":
		_open_secret(W.doors[int(e.door)])
		_toast("Der Schädelhaufen zerfällt. Ein versteckter Gang öffnet sich!")
	else:
		_break_seal(e)
		if story_items != null:
			story_items.loot("crate", Vector2(e.x, e.y + 30))


## A broken seal is a real choice (balance package D1): two blessings on cards, one safe price
## shown on them, no hidden roll (src/hell/card_kit.gd seal_offer, src/hell/frost_hud.gd
## seal_cards); the world waits until one is taken or both are left (_process).
func _break_seal(e: Dictionary) -> void:
	if sound != null: sound.at("seal_break", Vector2(e.x, e.y))
	CardKit.seal_offer(self, e)


## A broken urn, barrel or crate (world kit): nothing, gold, a heart, or (crates only)
## undead that lock the room.
func _break_crate(e: Dictionary) -> void:
	if sound == null or not sound.theme_event("crate_break"): _sound("hit_bone")
	# now and then a rune stone was hidden inside (src/hell/gold_loot.gd)
	gold_loot.roll_rune("breakable", Vector2(e.x, e.y - 10))
	match str(e.get("drop", "none")):
		"gem":
			gold_loot.spew(Vector2(e.x, e.y - 10), 2)
			_toast("Zerbrochen: Gold.")
		"heart":
			_drop("heart", e.room, Vector2(e.x, e.y + 4))
			_toast("Zerbrochen: ein Herz.")
		"undead":
			var r: Dictionary = W.rooms[e.room]
			r.fight = true
			r.cleared = false
			for k in range(2):
				# crates stand at the walls: the undead climb out onto free floor, never into the wall
				if monsters != null:
					monsters.spawn(r.index, monsters.free_spot(r.index, Vector2(e.x, e.y + 60.0), 70.0, 200.0), String(balance.monsters.seal_demon))
				else:
					_spawn_mob(r.index, free_floor(r.index, Vector2(e.x, e.y + 60.0), 70.0, 200.0), String(balance.seal.demon_kind))
			_toast("Aus der Kiste kriechen Untote! Die Gitter fallen.")
		_:
			_toast("Zerbrochen. Nichts darin.")
	if e.has("enemies"):
		release_room_enemies(e.enemies, Vector2(e.x, e.y + 60.0), int(e.room))


## A chest that was a mimic: it wakes on opening, the room locks and the fight is on.
func _wake_mimic(e: Dictionary) -> void:
	if sound != null: sound.at("mimic_spring", Vector2(e.x, e.y))
	e.state = "empty"
	e.taken = true
	var r: Dictionary = W.rooms[e.room]
	r.fight = true
	r.cleared = false
	# the chest is gone (its solid too, or the mimic would stand stuck inside it)
	for i in range(W.ents.size()):
		if is_same(W.ents[i], e):
			W.ents.remove_at(i)
			break
	_index_solids()
	var plain := str(theme.get("mimic_kind", "mimik"))
	var kind := str(e.get("mimic_mob", plain))
	if monsters != null and monsters.defs.has(kind):
		var m: Dictionary = monsters.spawn(r.index, monsters.free_spot(r.index, Vector2(e.x, e.y), 0.0, 60.0), kind)
		m.spawn = 0.0
		# waking only reveals it (a jump, dust): its bite comes later and with its windup (mimic_bite.json)
		monsters.reveal_mimic(m)
		# a beaten mimic pays once (R2 of the gameplay review): _clear_room drops drops.mimic where it fell
		var owed: Array = r.get("mimic_loot", [])
		m.chest_holds = RoomContents.drops_of(e)
		owed.append(m)
		r.mimic_loot = owed
	else:
		for held: Dictionary in RoomContents.drops_of(e):
			world_room_drop(held, Vector2(e.x, e.y + 40.0), int(e.room))
	if e.has("enemies"):
		release_room_enemies(e.enemies, Vector2(e.x, e.y), int(e.room))
	_burst(Vector2(e.x, e.y - 40), 30, true)
	state.shake = 0.4
	_sound("boss_intro")
	var who: String = "Ein Mimik" if kind == plain or monsters == null or not monsters.defs.has(kind) else str(monsters.defs[kind].get("name", kind))
	_toast("Die Truhe hat Zähne! %s greift an. Die Gitter fallen." % who)


## The hidden stairs: a choice of every earlier floor (keys 1-9, Esc closes). The world is rolled
## anew from there; hearts, stones, levels and items stay (they carry like a portal).
## A mimic of a room's roster in a world with dormant mimics: it waits as a plain chest (not a
## monster of the fight) until someone opens it (_wake_mimic).
func place_dormant_mimic(room: int, at: Vector2) -> void:
	var e := {"type": "chest", "mimic": true, "loot": {"gems": 0}, "x": at.x, "y": at.y, "room": room}
	W.ents.append(e)
	_add_solid(Rect2(e.x - 40, e.y - 32, 80, 32))


func _open_stairs() -> void:
	if int(state.floor) <= 1:
		_toast("Die Treppe führt nirgendwohin.")
		return
	stairs_pick = {"floors": range(1, int(state.floor))}
	_sound("stairs")


## Takes the hidden stairs down to floor n of a new world.
func choose_stairs(n: int) -> void:
	if sound != null: sound.at("stairs_pick", Vector2.INF)
	if stairs_pick.is_empty() or n < 1 or n >= int(state.floor):
		return
	stairs_pick = {}
	state.world_run = WorldPack.new_run()
	await _enter_floor(n, true)
	_toast("Eine neue Welt: zurück auf Etage %d." % n)


func _fall_into_pit() -> void:
	if sound != null: sound.hero("pit_fall")
	# in a Frostgruft puzzle room a fall puts the hero back on firm ground (frost_puzzles.gd)
	if frost_puzzles.puzzle_room(int(state.room)) and not frost_puzzles.fall_hurts() and frost_puzzles.catch_fall():
		if feel != null:
			feel.spawn("dust", Vector2(player.x, player.y), 1.2)
		return
	state.hp = maxi(0, state.hp - int(balance.pit.damage))
	# the fall hurts like a hit: the crypt's hurt (feedback.gd: flash, blood, shake, hitstop), dust
	# rising from the pit, no red wash over the screen (the crypt has none)
	if feel != null:
		feel.on_hurt()
		feel.spawn("dust", Vector2(player.x, player.y), 1.6)
	else:
		state.flash = 0.4
		_burst(Vector2(player.x, player.y - 30), 24)
	if state.hp == 0:
		state.dead = 1.8
		_gold_lost()
		state.death_why = "in eine Grube gestürzt"
		_toast("In die Grube gestürzt.")
		return
	# in a jump puzzle a wrong throw costs the fall, not the way back: on the pad again
	if str(W.rooms[state.room].get("type", "")) == "jump" and launch_pads.back_on_pad():
		_toast("Falscher Sprung.")
		return
	# a pit wave the fall broke off is not survived (src/world_kit/hell_puzzles.gd abort_waves)
	if hell_puzzles != null:
		hell_puzzles.abort_waves()
	for r: Dictionary in W.rooms:
		if r.fight:
			r.fight = false
			mobs = mobs.filter(func(m: Dictionary) -> bool: return m.room != r.index)
	prepare_mob_queries()
	eshots = []
	zones = []
	state.storm = false
	if story_elements != null: story_elements.reset()
	if monsters != null:
		monsters.reset()
		drake_rig.reset()
	if frost_rigs != null:
		frost_rigs.reset()
	if frost_fx != null:
		frost_fx.reset()
	if pools != null:
		pools.clear()
		if gas != null: gas.clear()
	state.pull = null
	_respawn()
	state.inv = 1.2
	var s := _room_of_type("start")
	state.room = s.index
	camera.position = Vector2(player.x, player.y)
	state.banner = {"text": s.name, "sub": "Aus der Grube zurück zum Start", "t": 0.0}
	_toast("In die Grube gestürzt: −1 Herz, zurück im Startraum.")


## Calls the clone (Q). Once started it runs until its time is spent.
func use_skill() -> void:
	match Rules.start_skill(state.skill):
		"none":
			_toast("Noch kein Skill. Besiege den Boss auf Etage %d." % int(balance.clone.floor))
		"running":
			_toast("Der Klon kämpft bereits und lässt sich nicht abbrechen.")
		"spent":
			_toast("Der Klon ist aufgebraucht.")
		"started":
			clone = {"p": Vector2(player.x - 60, player.y + 20), "cool": 0.0, "seed": randf() * 9.0}
			# effect hook: with the feel the clone appears like the crypt's (inventory.gd clone seal: cleanse at the clone)
			if feel != null:
				feel.fx_event("cleanse", clone.p - Vector2(0, 30))
			else:
				_burst(Vector2(player.x, player.y - 40), 30, true)
			_toast("Klon gerufen: %d Sekunden." % ceili(state.skill.left))


func _update_clone(dt: float) -> void:
	if not state.skill.active or clone.is_empty():
		return
	if Rules.tick_skill(state.skill, dt):
		# effect hook: with the feel it fades like the crypt's blink (violet burst, no sound)
		if feel != null:
			feel.fx_event("blink", clone.p - Vector2(0, 30))
		else:
			_burst(clone.p - Vector2(0, 40), 30)
		clone = {}
		_toast("Der Klon zerfällt. Zeit abgelaufen.")
		return
	# follows behind the hero, weaving to dodge; enemies never target it
	var cfg: Dictionary = balance.clone
	var weave := sin(state.t * 5.0 + clone.seed) * float(cfg.weave)
	var target_p := Vector2(player.x - player.face * float(cfg.follow), player.y + 26.0 + weave)
	clone.p = clone.p.lerp(target_p, 1.0 - pow(0.004, dt))
	clone.cool -= dt
	var best: Dictionary = {}
	var bd := float(cfg.range)
	for m: Dictionary in mobs:
		if _hittable(m) and m.p.distance_to(clone.p) < bd:
			bd = m.p.distance_to(clone.p)
			best = m
	if not best.is_empty() and clone.cool <= 0.0:
		clone.cool = float(cfg.fire_every)
		var from: Vector2 = clone.p - Vector2(0, 40)
		var aim: Vector2 = best.p - Vector2(0, best.cy) - from
		shots.append({"p": from, "v": aim.normalized() * float(balance.shot.speed), "t": float(state.range)})


## Writes the floor-start state into save slot 1..3 of this world; true on success.
func save_slot(slot: int) -> bool:
	if not custom_preview_room.is_empty() or debug_run: return false
	if sound != null: sound.at("save_ok", Vector2.INF)
	var ok := not floor_save.is_empty() and saves.write(StorySave.mode(self), slot, floor_save)
	if ok:
		run_slot = slot
	if pause_menu != null:
		pause_menu.refresh_save(("Gespeichert in Platz %d: Beginn von Etage %d." % [slot, int(floor_save.floor)]) if ok else "Speichern fehlgeschlagen.")
	return ok


## Esc: the shared pause menu (the world stands still), centred on the screen, on its overview.
func open_pause() -> void:
	if sound != null: sound.at("pause_open", Vector2.INF)
	var screen := get_viewport().get_visible_rect().size
	var origin := ((screen - Vector2(1280, 720)) / 2.0).floor()
	pause_menu.position = origin
	pause_menu.set_canvas_size(screen, origin)
	pause_menu.set_display_state(get_window().mode == Window.MODE_FULLSCREEN, screen)
	pause_menu.set_graphics_state(GraphicsSettings.note(theme, graphics), graphics)
	pause_menu.set_story_state(pause_info())
	pause_menu.set_shards(int(profile.get("shards", {}).get("have", 0)) if not profile.is_empty() else 0)
	pause_menu.select_section("overview")
	pause_menu.visible = true
	# the focus sits on the open section (Etage), not a second highlight on Weiterspielen
	pause_menu.focus_section()


## The pause pages' text: where the hero is, how the run stands, the floor's goals.
func pause_info() -> Dictionary:
	var hero_name: String = str(sub_kit.name).to_upper() if not sub_kit.is_empty() else str(hero.get("name", "Held"))
	var held: String = str(RelicKit.wielded(self).name) if relic_on() else str(weapon.get("name", ""))
	var keys: Array = []
	for k: String in ["A", "B", "C"]:
		if state.keys[k]: keys.append(str(key_name[k]))
	var blessings: Array = (state.buffs as Array).map(func(b: String) -> String: return b.get_slice(":", 0))
	var lines: Array = [
		"Etage %d · %s" % [state.floor, W.title], str(W.circle), "",
		"%s · LAUFSTUFE %d · %s" % [hero_name, int(state.get("level", 1)), held],
		"LP: %d / %d" % [HudKit.life_shown(int(state.hp), hp_f()), int(state.max_hp)],
		"Gold: %d · Runensteine: %d" % [gold_count(), rune_count()],
		"Schlüssel: %s" % (", ".join(PackedStringArray(keys)) if not keys.is_empty() else "keiner"),
		"Segen: %s" % (", ".join(PackedStringArray(blessings)) if not blessings.is_empty() else "keiner"),
		"", "Räume besucht: %d von %d" % [state.visited.size(), W.rooms.size()],
	]
	if str(state.relic) != "":
		lines.insert(5, "Relikt: %s" % theme[state.relic].name)
	return {"overview": say("\n".join(PackedStringArray(lines))), "quests": FrostHud.goals(self), "quest_title": "ETAGE %d" % int(state.floor),
		"reactions": story_elements.discovered() if story_elements != null else []}


func _toggle_fullscreen() -> void:
	var full := get_window().mode == Window.MODE_FULLSCREEN
	get_window().mode = Window.MODE_WINDOWED if full else Window.MODE_FULLSCREEN
	pause_menu.set_display_state(not full, get_viewport().get_visible_rect().size)


func _process(delta: float) -> void:
	_sync_overlays()
	if _simulation_paused():
		presentation.reset()
		_simulation_clock.reset()
		_skip_simulation_delta = true
		if talents != null: talents.tc.runtime(1).erase("soul_charge")
		hud.queue_redraw()
		return
	# Several gameplay ticks may be due after a slow picture. Keep all elapsed
	# time, with a bounded amount of catch-up work per picture (no 50-ms clip).
	_simulation_clock.begin_frame(0.0 if _skip_simulation_delta else delta)
	_skip_simulation_delta = false
	while _simulation_clock.take_step():
		presentation.begin_tick(player, mobs)
		_step_simulation(_simulation_clock.step_seconds)
		# A seal may open a blocking choice during a tick. Do not let later ticks
		# attack through that modal. Floor loads reset the clock inside load_floor.
		if _simulation_paused():
			presentation.reset()
			_simulation_clock.reset()
			_skip_simulation_delta = true
			break
	presentation.frame(_simulation_clock.pending_seconds, _simulation_clock.step_seconds)
	# Presentation work only once per rendered frame, never once per catch-up tick.
	if inventory_panel != null and story_items != null:
		inventory_panel.set_view(story_items.view())
		inventory_panel.quick = story_items.quick_slot()
		# the character column follows what the bag changed (equipping alters the numbers)
		if inventory_panel.open:
			inventory_panel.set_character_view(FrostHud.status_sheet(self))
	if not _simulation_paused() and not _simulation_frozen() and not bool(state.get("won", false)) \
			and float(state.get("dead", 0.0)) <= 0.0 and (state.get("over", {}) as Dictionary).is_empty():
		_update_camera(delta)
	actors.queue_redraw()
	glow.queue_redraw()
	hostile_shots.visible = not eshots.is_empty()
	if hostile_shots.visible: hostile_shots.queue_redraw()
	# the darkness's lights and the bloom, after the actors (their glowing parts follow the drawn bodies)
	PerfMarks.begin()
	story_glow.frame()
	PerfMarks.add("glow.frame")
	hud.queue_redraw()


## Menus that intentionally suspend gameplay also suspend the clock (no debt on resume).
func _simulation_paused() -> bool:
	# the character & inventory window pauses too, like the talents: reading and equipping is
	# management, not a fight (docs/MENUE-UX-REVIEW.de.md); the story worlds are solo
	return (pause_menu != null and pause_menu.visible) or (run_talents != null and run_talents.visible) \
		or (inventory_panel != null and inventory_panel.open) \
		or bool(state.get("tree_open", false)) or CardKit.seal_open(self) or loading_screen != null or _leaving


## A hitstop consumes scheduled time without advancing the combat simulation.
func _simulation_frozen() -> bool:
	return (feel != null and feel.frozen()) or (drake_rig != null and drake_rig.frozen())


## One fixed tick, including intentional hitstop. Every world uses this same path.
func _step_simulation(dt: float) -> void:
	# a kill or a hurt holds the picture for a moment, as in the crypt (hitstop, src/hero/story_feel.gd)
	if feel != null and feel.frozen():
		feel.freeze(dt)
	elif drake_rig != null and drake_rig.frozen():
		# a severed part holds the picture without the feel too (src/hell/drake_rig_host.gd hold)
		drake_rig.freeze(dt)
	else:
		_update(dt)


func _update(dt: float) -> void:
	PerfMarks.begin()
	state.t += dt
	story_hero.update(dt)
	if story_items != null:
		story_items.update(dt)
	for k in ["inv", "flash", "cool", "chill", "slow"]:
		state[k] = maxf(0.0, state[k] - dt)
	state.shake = maxf(0.0, state.shake - dt * 30.0)
	state.white = maxf(0.0, state.white - dt * 1.6)
	# one toast at a time: only the one on screen runs down, then the next one shows
	var queue: Array = state.toasts
	if not queue.is_empty():
		queue[0].t = float(queue[0].t) - dt
		queue[0].age = float(queue[0].get("age", 0.0)) + dt
		if float(queue[0].t) <= 0.0:
			queue.pop_front()
			if not queue.is_empty() and sound != null: sound.at("toast", Vector2.INF)
	state.banner.t += dt
	if state.won:
		state.won_t += dt
		return
	if not (state.get("over", {}) as Dictionary).is_empty():
		_update_music()
		return
	if state.dead > 0.0:
		# the crypt keeps reacting while the hero falls: the killing blow, the defeat sting, the menu music
		if feel != null:
			feel.update(dt)
		# and the world goes on moving with nothing hurting anyone any more (decision D8): the gas
		# drifts, the frost world's waves and knocks age, bodies and their debris fall and settle
		_step_gas(dt)
		# the enemies' shots fly on and break on the walls (_hurt spares the fallen hero)
		if monsters != null: monsters.update_shots(dt)
		if frost_fx != null: frost_fx.update(dt)
		if frost_rigs != null: frost_rigs.frame(dt)
		if drake_rig != null and monsters != null: drake_rig.frame(mobs, monsters.corpses, dt)
		_update_music()
		state.dead -= dt
		if state.dead <= 0.0:
			# a dungeon crawler: death ends the run (docs/LAUF-DESIGN.de.md)
			end_run(false)
			state.inv = 1.2
			state.room = _room_of_type("start").index
		return
	swing.t = maxf(0.0, swing.t - dt)
	PerfMarks.add("u.hero+items")
	if talents != null: talents.update(dt)
	PerfMarks.add("u.talents")
	# the kits' direct sounds by who acts (src/hero/story_sound.gd): the hero's skills, relics and allies, the enemy moves
	as_source("hero", _update_hero_kits.bind(dt))
	as_source("moves", func() -> void: FrostCombat.update(self, dt))
	PerfMarks.add("u.kits+moves")
	_update_matter_blockers()
	_wall_fire_matter()
	PerfMarks.add("u.blockers+torches")
	# the snowstorm's wind is the world's (D12, F58): screen px/s over the camera zoom are world
	# px/s; light particles and the gas drift with it
	if snowstorm != null and snowstorm.has_method("follow"): snowstorm.follow(camera.position, camera.zoom.x)
	if snowstorm != null and feel != null:
		var w: Vector2 = snowstorm.wind() / maxf(0.1, camera.zoom.x)
		feel.feedback.particles.wind = w / float(feel.scale)
		if gas != null and gas.get("gas_field") != null: gas.gas_field.wind = w
	if feel != null:
		feel.update(dt)
	PerfMarks.add("u.feel")
	if not (state.get("offer", []) as Array).is_empty():
		state.offer_t = float(state.get("offer_t", 0.0)) + dt
	_update_music()
	_update_player(dt)
	PerfMarks.add("u.player")
	if state.dead > 0.0:
		return
	_update_clone(dt)
	_update_shots(dt)
	PerfMarks.add("u.shots")
	# effect hook: Rage-thrown bodies that slam into a wall (story_hero.check_slam, here and in
	# hell_monsters.gd) leave the crypt's wall slam instead of the relics' violet quake ring
	var slams := _slams_before()
	_update_mobs(dt)
	PerfMarks.add("u.mobs")
	# the Frostgruft's figures: what each one does now goes to its rig
	if frost_rigs != null:
		frost_rigs.frame(dt)
	# the attacks' frost waves and flashes age, the hero slides along his knockback
	if frost_fx != null:
		frost_fx.update(dt)
	# Ignaroth's rig: stagger/landing timers, the closing throat, debris; then the cuts' hitstop and sound
	if drake_rig != null:
		drake_rig.frame(mobs, monsters.corpses, dt)
		_route_rig_events()
	_slams_after(slams)
	PerfMarks.add("u.rigs")
	_update_zones(dt)
	_update_hazards(dt)
	frost_puzzles.update(dt)
	hell_puzzles.update(dt)
	if frost_snow != null:
		frost_snow.update(dt)
	gold_loot.update(dt)
	_update_rooms()
	PerfMarks.add("u.zones+world")
	_update_embers(dt)
	PerfMarks.add("u.embers+elements")
	if wreck != null:
		wreck.update(dt)
	PerfMarks.add("u.wreck")


## The hero's skills, relic and subclass per frame (their allies and timed blows).
func _update_hero_kits(dt: float) -> void:
	HeroKit.update(self, dt)
	RelicKit.update(self, dt)
	SubKit.update(self, dt)


## Effect hook (with the feel): the Rage-thrown bodies flying before the monsters move, with their push.
func _slams_before() -> Dictionary:
	if feel == null:
		return {}
	var flying: Array = []
	for m: Dictionary in mobs:
		if m.has("slam"):
			flying.append([m, m.k])
	return {"flying": flying, "fx": fx.size()}


## Effect hook: a thrown body that slammed into a wall this frame left story_hero.check_slam's
## quake at it; that becomes the crypt's wall_slam (skill_fx.gd: dust, a hit spark, crack rays).
func _slams_after(slams: Dictionary) -> void:
	if slams.is_empty():
		return
	for pair: Array in slams.flying:
		var m: Dictionary = pair[0]
		if m.has("slam"):
			continue
		for i in range(fx.size() - 1, maxi(0, int(slams.fx)) - 1, -1):
			var f: Dictionary = fx[i]
			if str(f.get("kind", "")) == "quake" and (f.p as Vector2).is_equal_approx(m.p):
				fx.remove_at(i)
				var push: Vector2 = pair[1]
				story_hero.skill_fx.event("wall_slam", [story_hero.skill_fx.ground(m.p)], {"angle": push.angle(), "time": 0.4, "length": 0.4})
				if wreck != null:
					wreck.hit_line(m.p, m.p + push.normalized() * 110.0, "slam", 1)
				break


## The crypt's music states (src/audio/music.gd decide, through story_sound.gd):
## boss while a guardian lives, combat while the hero's room fights, explore,
## the menu theme once the hero fell or the run is lost.
func _update_music() -> void:
	if music == null:
		return
	var want := StorySound.music_state(self)
	if want != _music_state:
		_music_state = want
		music.request(want)


## This world's motion kit (src/physics_kit/motion_kit.gd) on its host
## (src/hell/story_motion_host.gd), made on first use: the hero's walk, the
## Frostgruft monsters' push and slide, the skid of his boots.
func motion_kit() -> MotionKit:
	if _motion == null:
		_motion = MotionKit.new(StoryMotionHost.new(self))
	return _motion


## A body's mass for pushes (physics plan R23/F44, decision D5): its radius
## over the median radius of this world's monsters (bosses and kit bosses left
## out), squared, within physics_motion.json push.mass [min, max];
## push.mass_ref_r while there is none to measure. Measured again when the
## number of monsters changes.
var _mass_ref := Vector2(-1.0, 28.0)


func body_mass(m: Dictionary) -> float:
	var pcfg: Dictionary = motion_kit().cfg.get("push", {})
	var heavy: Array = pcfg.get("mass", [0.4, 4.0])
	if int(_mass_ref.x) != mobs.size():
		var radii: Array = []
		for o: Dictionary in mobs:
			if str(o.get("kind", "")) != "boss" and not o.has("kit") and not bool(o.get("boss", false)):
				radii.append(float(o.get("r", 28.0)))
		radii.sort()
		_mass_ref = Vector2(float(mobs.size()), float(radii[radii.size() / 2]) if not radii.is_empty() else float(pcfg.get("mass_ref_r", 28.0)))
	return clampf(pow(float(m.get("r", 28.0)) / maxf(1.0, _mass_ref.y), 2.0), float(heavy[0]), float(heavy[1]))


## The element exposure of this world (src/physics_kit/element_exposure.gd on
## its adapter src/hell/story_exposure_host.gd), made on first use: what pools
## and gas do to the hero (_step_elements), the Frostgruft's enemies
## (_step_mob_medium) and the hell monsters (hell_monsters.gd _step_medium).
func exposure() -> ElementExposure:
	if _exposure == null:
		_exposure = ElementExposure.new(StoryExposureHost.new(self))
	return _exposure


func _update_player(dt: float) -> void:
	# thrown by a Sprungplatte: in the air until he lands, nothing on the floor touches him
	if launch_pads.flying():
		player.anim += dt * 5.0
		launch_pads.step(dt)
		return
	# the mirror shows its way: the hero is walked (src/world_kit/frost_puzzles.gd)
	if frost_puzzles.showing():
		frost_puzzles.drive(dt)
		return
	var move := Vector2(_axis(KEY_A, KEY_D), _axis(KEY_W, KEY_S))
	# WAHN: mad, he walks and aims mirrored (src/hell/hero_fx.gd inverted)
	var mirror := -1.0 if FrostCombat.HeroFx.inverted(self) else 1.0
	move *= mirror
	if not dash.is_empty():
		move = Vector2.ZERO
	var here := _cell(int(floor(player.x / C)), int(floor((player.y - 6.0) / C)))
	var liquid: Dictionary = theme.liquid
	var slow: float = float(balance.player.lava_slow) if float(liquid.slow) < 0.0 else float(liquid.slow)
	var chill := float(theme.get("chill_speed", 1.0)) if state.chill > 0.0 else 1.0
	# the element physics (src/combat/element_rules.gd, _step_elements): a pool or gas the hero
	# stands in slows him (lava, poison, void, frost mist) and ice or blood takes his footing
	var medium_slow := float(hero_medium.get("slow", 1.0)) * float(hero_gas.get("slow", 1.0))
	var speed := float(hero.get("speed", balance.player.speed)) * float(state.speed_mul) * chill * HeroKit.move_scale(self) * CardKit.speed_mult(self) * (slow if here == 2 else 1.0) * (0.5 if state.slow > 0.0 else 1.0) * FrostCombat.move_scale(self) * medium_slow
	player.moving = move != Vector2.ZERO and speed > 0.0
	var want := move.normalized() * speed if player.moving else Vector2.ZERO
	# grip = share of the old speed left after one second: glaze ice tiles (theme liquid), a pool
	# of ice or blood (its rule), the slip condition; firm floor takes the wanted speed at once
	# (grips: physics_motion.json grip; the walk itself: MotionKit.step_hero, src/physics_kit/motion_kit.gd)
	var mover := motion_kit()
	var grip := MotionKit.FIRM
	if ice_room_at(Vector2(player.x, player.y - 6.0)):
		grip = ice_room_grip(Vector2(player.x, player.y - 6.0), false)
	elif here == 2 and liquid.slide:
		grip = float(liquid.grip)
	elif bool(hero_medium.get("slide", false)):
		grip = float(hero_medium.get("grip", mover.grip("medium")))
	elif feel != null and FrostCombat.HeroFx.slip(self) > 0.0:
		grip = mover.grip("slip")
	# the void pulls towards its heart
	var pull := ElementRules.pull(hero_medium, Vector2(player.x, player.y), Vector2(hero_medium.get("centre", Vector2(player.x, player.y))))
	mover.step_hero(want, grip, pull, dt)
	if absf(move.x) > 0.0:
		player.face = signf(move.x)
	player.anim += dt * (10.0 if player.moving else 5.0)
	var aim := Vector2(_axis(KEY_LEFT, KEY_RIGHT), _axis(KEY_UP, KEY_DOWN)) * mirror
	if aim != Vector2.ZERO:
		_fire(aim)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not mouse_taken and not state.get("tree_open", false) and throw_slot < 0 and (inventory_panel == null or not inventory_panel.open):
		_fire((HeroKit.target(self) - Vector2(player.x, player.y - 40)) * mirror, true)
	# a drunk fire or ice potion's after-effect keeps the lava off (story_items.gd immune)
	if here == 2 and liquid.hurt and not (story_items != null and story_items.immune("lava")):
		_hurt("in der Lava verbrannt")
	for e: Dictionary in pits:
		if absf(player.x - e.x) < float(balance.pit.reach_x) and absf(player.y - 8.0 - e.y) < float(balance.pit.reach_y):
			_fall_into_pit()
			return


func _update_shots(dt: float) -> void:
	if not shots.is_empty(): prepare_mob_queries()
	for s: Dictionary in shots:
		var alchemy_from: Vector2 = s.p
		s.p += s.v * dt
		s.t -= dt
		# the mage's shot reaches the point the mouse showed (MageBolt.aim): it stops there; still
		# alive (t > 0) after the checks below, nothing struck it, and it bursts on the floor
		var landed := false
		if s.has("left"):
			s.left = float(s.left) - (s.v as Vector2).length() * dt
			if float(s.left) <= 0.0 or float(s.t) <= 0.0:
				s.p = s.land
				s.t = maxf(float(s.t), 0.001)
				landed = true
		var struck: Dictionary = {}
		for e: Dictionary in breakables:
			if not e.get("broken", false) and absf(s.p.x - e.x) < 50.0 and s.p.y > e.y - 90.0 and s.p.y < e.y + 10.0:
				struck = e
		if not struck.is_empty():
			s.t = 0.0
			if wreck != null:
				wreck.hit_dir = s.v
			_hit_breakable(struck, s.p)
			continue
		# the hero's fire shot that strikes an unlit fire bowl lights it (decision D7)
		if str(s.get("kind", "")) in ["pyro", "fireball"]:
			for e: Dictionary in W.ents:
				if e.type == "brazier" and not e.get("lit", false) and not e.get("cold", false) and Rect2(e.x - 36, e.y - 44, 72, 54).has_point(s.p):
					s.t = 0.0
					fire_hits_brazier(s.p)
					break
		# a smashable prop in the shot's way shatters (src/hell/story_wreck.gd)
		if wreck != null and wreck.shot(s):
			continue
		var c := Vector2i(int(floor(s.p.x / C)), int(floor(s.p.y / C)))
		var hit_solid := false
		for r: Rect2 in solid_grid.get(c.y * int(W.cols) + c.x, []):
			if r.grow_individual(0, 50, 0, 0).has_point(s.p):
				hit_solid = true
		if _cell_blocked(c.x, c.y, false) or hit_solid:
			s.t = 0.0
			# effect hook: with the feel the crypt's wall hit (chips, a crack, sparks or the shot's splash)
			if feel != null:
				feel.wall_hit((s.p as Vector2) - (s.v as Vector2) * dt, s.p, StoryFeel.shot_wall_style(s), 1)
			else:
				_burst(s.p, 5)
			# owner 1: the hero's own fire, so its element reactions are his (story_elements.gd _reacted)
			if s.get("kind", "") == "pyro" and talents != null: talents.tc.show_effect("explosion", s.p, 34.0, {"fx": "fire", "life": 0.5, "owner": 1, "wrecked": true})
			MageBolt.burst(self, s, {})
			continue
		MageBolt.fly(self, s, dt)
		if str(s.get("kind","")) == "arrow" and talents != null:
			talents.tc.alchemist.arrow(talents.tc,1,alchemy_from,s.p)
		if s.get("kind", "") == "gravity":
			# the gravity ball drags enemies towards itself while it flies
			var ball: Dictionary = RelicKit.wielded(self).get("ball", theme.gravity_staff.ball)
			for m: Dictionary in mob_candidates(s.p,float(ball.pull_radius)):
				var to: Vector2 = s.p - m.p
				if m.spawn <= 0.0 and not m.has("kit") and m.kind != "boss" and to.length() < float(ball.pull_radius) and to.length() > 10.0:
					var step: Vector2 = to.normalized() * float(ball.pull) * dt
					if not box_blocked(Rect2(m.p.x + step.x - m.r * 0.7, m.p.y + step.y - m.r * 0.7, m.r * 1.4, m.r * 0.7), true):
						m.p += step
						mob_moved(m)
		var big := float(s.get("big", 1.0))
		for m: Dictionary in mob_segment_candidates(s.p-s.v*dt,s.p,12.0*big):
			# Ignaroth's rig: the shot must cross a part where it is drawn; the part takes the hit (src/hell/drake_rig_host.gd)
			var rigged: bool = drake_rig != null and drake_rig.has_rig(m)
			if _hittable(m) and not (s.get("hits", []) as Array).has(m) and (drake_rig.shot_hits(m, s.p - s.v * dt, s.p, 12.0 * big) if rigged else s.p.distance_to(m.p - Vector2(0, m.cy)) < m.r + 12.0 * big):
				# with the feel the hit is the crypt's alone (sparks, hit spark, drops: feedback.gd)
				if feel == null:
					_burst(s.p, 6)
				var mult := float(s.get("mult", 1.0))
				# the mage's icicle shatters (its chill slows), his void orb implodes (src/vfx/mage_bolt.gd)
				MageBolt.burst(self, s, m)
				if s.get("pierce", false):
					# piercing shots (blade wave, ballista, arrow fist) go on through everyone
					s.hits.append(m)
					if _damage_mob(m, s.v, mult) and s.has("fx"):
						SubKit.hit(self, m, s.fx)
					if s.get("push", false) and not m.has("kit"):
						m.k = (s.v as Vector2) * 0.6
					if s.has("slow"):
						HeroKit.slow_mob(self, m, float(s.slow), float(s.slow_time))
					continue
				s.t = 0.0
				var splash: float = s.get("splash", 0.0)
				if splash <= 0.0 and not s.has("burst"):
					if _damage_mob(m, s.v, mult) and s.has("fx"):
						SubKit.hit(self, m, s.fx)
					break
				_explode(s, m)
				break
		if landed and s.t > 0.0:
			_land_shot(s)
		if s.t <= 0.0 and s.has("burst") and not s.get("done", false):
			_explode(s, {})
	shots = shots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)
	if monsters != null:
		monsters.update_shots(dt)
		return
	var me := Vector2(player.x, player.y - 34)
	for s: Dictionary in eshots:
		HeroKit.catch_shot(self, s, dt)
		if s.has("home"):
			s.v = (s.v as Vector2).lerp((me - s.p).normalized() * float(s.home), 1.0 - pow(0.08, dt))
		if s.has("back") and s.t < float(s.back) and s.has("home_to"):
			var owner: Dictionary = s.home_to
			s.v = ((owner.p - Vector2(0, owner.cy)) - s.p).normalized() * (s.v as Vector2).length()
		s.p += s.v * dt
		s.t -= dt
		# WAHN: a turned enemy's shot hurts the enemies it meets (not its shooter)
		if s.has("mad") and _themed_mad_shot(s):
			continue
		if not s.get("fist", false) and _cell_blocked(int(floor(s.p.x / C)), int(floor(s.p.y / C)), false):
			s.t = 0.0
			# a bone arrow splinters on the wall instead (src/vfx/shot_looks.gd)
			if ShotLooks.impact(self, s, true):
				pass
			# the frost world's shard breaks on the wall into ice chips and rime (src/hell/frost_fx.gd)
			elif frost_fx != null and str(s.get("style", "ice")) in ["ice", "frost"]:
				if wreck != null:
					wreck.hit_line((s.p as Vector2) - (s.v as Vector2) * dt, s.p, "ice")
				frost_fx.shatter((s.p as Vector2) - (s.v as Vector2) * dt, 8, 14.0, -(s.v as Vector2).normalized(), 160.0)
			# effect hook: with the feel the crypt's wall hit in the shot's style
			elif feel != null:
				feel.wall_hit((s.p as Vector2) - (s.v as Vector2) * dt, s.p, feel.enemy_wall_style(s))
			else:
				_burst(s.p, 4)
		elif s.p.distance_to(me) < float(balance.enemy_shot.hit_radius) * (1.6 if s.get("fist", false) else 1.0):
			s.t = 0.0 if not s.get("fist", false) else s.t
			if s.has("chill"):
				state.chill = maxf(state.chill, float(s.chill))
			if s.has("dmg"):
				FrostCombat.FrostMoves.shot_hit(self, s)
			else:
				var before := int(state.hp)
				_hurt("von Feuer getroffen", 1, s.p, s.get("by", {}), s)
				# a guardian's plain shot pushes the hero back and bursts into ice on him
				if frost_fx != null and int(state.hp) < before:
					frost_fx.hit_hero((s.p as Vector2) - (s.v as Vector2).normalized() * 40.0, "fist" if s.get("fist", false) else "shot", "small" if s.get("fist", false) else "tiny")
					if not ShotLooks.impact(self, s, false):
						frost_fx.shatter(s.p, 8, 14.0, (s.v as Vector2).normalized(), 120.0)
				elif frost_fx != null and HeroKit.perfect_now(self):
					# met by a perfect block or roll: the shot breaks off it, back the way it came
					frost_fx.shatter(s.p, 8, 14.0, -(s.v as Vector2).normalized(), 120.0)
		if s.t <= 0.0 and s.has("end_pool"):
			FrostCombat.FrostMoves.shot_end(self, s)
	eshots = eshots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)


## Particles low over the floor are drawn between the y-sorted actors (decision D11; story_feel's
## over layer then draws only the high ones).
var depth_bands := true
## What stood solid when the particles' blockers were last made (gates closed, crates whole).
var _blocker_sig := ""


## Closed gates, solid props and whole crates and urns stop the particles too (physics plan R16):
## their 32 px particle cells, made anew only when a gate opens or closes, a prop is added or a
## crate breaks (a cheap signature each frame).
func _update_matter_blockers() -> void:
	if feel == null or W.is_empty(): return
	var whole := 0
	for e: Dictionary in breakables:
		if not e.get("broken", false): whole += 1
	var shut := 0
	for k: int in door_at:
		if _door_closed(W.doors[door_at[k]]): shut += 1
	var sig := "%d:%d:%d:%s" % [whole, shut, solid_grid.size(), str(W.get("index", 0))]
	if sig == _blocker_sig: return
	_blocker_sig = sig
	var s := float(feel.scale)
	var cells := {}
	var mark := func(r: Rect2) -> void:
		var mid := r.get_center() / s
		cells[Vector2i(floori(mid.x / 32.0), floori(mid.y / 32.0))] = true
	for key: int in solid_grid:
		for r: Rect2 in solid_grid[key]: mark.call(r)
	for e: Dictionary in breakables:
		if not e.get("broken", false): mark.call(_breakable_box(e))
	for k: int in door_at:
		if not _door_closed(W.doors[door_at[k]]): continue
		var cx := k % int(W.cols)
		var cy := k / int(W.cols)
		var gate := Rect2(cx * C, cy * C, C, C)
		var a := (gate.position / s / 32.0).floor()
		var b := (gate.end / s / 32.0).ceil()
		for y in range(int(a.y), int(b.y)):
			for x in range(int(a.x), int(b.x)):
				cells[Vector2i(x, y)] = true
	feel.feedback.particles.blocked_cells = cells


## Wading keys handed to the Frostgruft's figures (m.wk; _update_mobs).
var _wade_serial := 0


## Refresh once before a phase that may move bodies or query many projectiles.
func prepare_mob_queries() -> void:
	_mob_space.rebuild(mobs)


## Keep current phase candidates and the combat position alias live after a move.
func mob_moved(m: Dictionary) -> void:
	if m.has("pos"): m.pos = m.p
	_mob_space.upsert(m)


## Remove a despawned body before any further queries in this phase.
func mob_removed(m: Dictionary) -> void:
	_mob_space.remove(m)


## Ordered conservative candidates; callers retain their exact hit predicates.
func mob_candidates(at: Vector2, radius: float, adaptive := false) -> Array:
	return _mob_space.near_adaptive(at, radius) if adaptive else _mob_space.near(at,radius)


## Dense-body hint permits full-list talent queries without another index rebuild.
func mob_queries_dense() -> bool:
	return _mob_space.prefers_full_scan()


## Includes bodies anywhere along a fast shot's swept path and raised centre.
func mob_segment_candidates(from: Vector2, to: Vector2, padding: float) -> Array:
	return _mob_space.swept(from,to,padding)


func _update_mobs(dt: float) -> void:
	if monsters != null:
		monsters.update(dt)
		if pools != null:
			pools.sync(monsters.pool_entries(), float(state.t))
			# the hero and the monsters wade through the puddles (src/vfx/pool_paint.gd wade)
			pools.wade("hero", Vector2(float(player.x), float(player.y)), bool(player.get("moving", false)), float(state.t))
			for m: Dictionary in mobs:
				# a monster's steps show by its moving point (wade sees it move)
				if m.has("id"): pools.wade("m" + str(m.id), Vector2(m.p), false, float(state.t))
		return
	prepare_mob_queries()
	# the Frostgruft wades too: the hero and its figures through the talents' pools (physics plan
	# R26/F55; its figures get a stable wading key at their first step)
	var layer := _pool_layer()
	if layer != null and layer.has_method("wade"):
		layer.wade("hero", Vector2(float(player.x), float(player.y)), bool(player.get("moving", false)), float(state.t))
		for m: Dictionary in mobs:
			if not m.has("wk"):
				_wade_serial += 1
				m.wk = _wade_serial
			layer.wade("m%d" % int(m.wk), Vector2(m.p), false, float(state.t))
	var me := Vector2(player.x, player.y)
	var hidden := float(state.get("stealth", 0.0)) > 0.0
	for m: Dictionary in mobs:
		if m.spawn > 0.0:
			m.spawn -= dt
			continue
		m.hit = maxf(0.0, m.hit - dt)
		var env := _step_mob_medium(m,dt)
		if preload("res://src/combat/enemy_sight.gd").blocked(m):
			HeroKit.tick_mob(self,m,dt)
			m.erase("tell")
			if m.has("busy"): m.busy = {}
			if m.has("dash"): m.dash = 0.0
			m.sv = Vector2.ZERO
			# External force remains physical; no sight-driven walking or tracking.
			var blinded_step: Dictionary = motion_kit().step_body(m.p,Vector2.ZERO,Vector2.ZERO,MotionKit.FIRM,Vector2.ZERO,m.k,dt,motion_kit().host.mob_solid(m.r*0.7,m.kind!="boss"))
			m.p = blinded_step.p
			m.k = blinded_step.push
			continue
		if hidden and m.kind != "boss":
			# hidden hero: they stop, look about and turn their backs now and then
			m.face = Vector2(cos(state.t * 1.5 + m.seed), sin(state.t * 1.5 + m.seed))
			continue
		# taunting allies (bone colossus, great bear) draw enemies away from the hero
		var goal := SubKit.chase(self, m, me)
		if talents != null: goal = talents.chase_goal(m, goal)
		# WAHN (madness_rules.json madness): a mad one staggers, scatters its shots and may turn on another
		m.mad_t = maxf(0.0, float(m.get("mad_t", 0.0)) - dt)
		m.mad_cd = maxf(0.0, float(m.get("mad_cd", 0.0)) - dt)
		var prey := _themed_mad_victim(m, dt)
		if not prey.is_empty():
			goal = prey.p
		_mad_mob = m if float(m.mad_t) > 0.0 else {}
		_mad_prey = prey
		var to: Vector2 = goal - m.p
		var d := maxf(to.length(), 1.0)
		var dir := to / d
		var def: Dictionary = m.def
		var beh: String = def.get("behavior", "")
		m.face = dir
		var wob := sin(state.t * 3.0 + m.seed) * 0.7
		var shy: bool = (m.kind == "spucker" or beh == "shooter") and d < float(def.get("keep_away", 0.0))
		var away := -1.0 if shy else 1.0
		var v: Vector2 = (dir * away + Vector2(-dir.y, dir.x) * wob) * m.sp
		match beh:
			"turret":
				v = Vector2.ZERO
			"dasher":
				# runs like the others, now and then a straight dash at the hero: it holds still for its
				# windup first, its aim fixed once aim_lock of it has run (frost_moves.gd basic_tell, tokens)
				m.dash_t -= dt
				if m.dash > 0.0:
					m.dash -= dt
					v = m.dash_dir * float(def.dash_speed)
				else:
					var lunge: Vector2 = FrostCombat.FrostMoves.basic_tell(self, m, "dash", goal, dt, m.dash_t <= 0.0)
					if lunge.is_finite():
						m.dash_t = float(def.dash_every)
						m.dash = float(def.dash_time)
						m.dash_dir = (lunge - m.p).normalized() if lunge.distance_to(m.p) > 1.0 else dir
						if sound != null:
							sound.on_attack(m, "dasher")
			"puller":
				if d < float(def.pull_radius):
					# axis by axis against the walls (MotionKit.move_hero)
					motion_kit().move_hero(-dir * float(def.pull) * dt)
		for o: Dictionary in mob_candidates(m.p,float(m.r)):
			if not is_same(o,m):
				var off: Vector2 = m.p - o.p
				var od := off.length()
				if od > 0.0 and od < m.r + o.r:
					v += off / od * 120.0
		if float(m.mad_t) > 0.0 and m.kind != "boss":
			v += ElementRules.wobble(m, dir, dt, randf()) * PIXEL_WORLD / 2.0
		if m.get("hold", false) or m.get("mv_hold", false) or m.has("tell"):
			v = Vector2.ZERO
		v *= HeroKit.tick_mob(self, m, dt)
		# the element physics (src/combat/element_rules.gd): the pool or gas it stands in, and on the
		# world's glaze ice tiles (theme liquid slide) it keeps its momentum like the hero, unless it
		# is a creature of frost, sure-footed on its own ice
		if not m.has("tags"):
			m.tags = ElementRules.tags(str(m.kind), str(def.get("shot", "")), str(def.get("material", "")), ["frost"] if def.has("chill") else [])
		var mover := motion_kit()
		var grip := MotionKit.FIRM
		# a room of nothing but ice takes everybody's footing, the creatures of frost too; not the flyers'
		if float(m.get("alt", 0.0)) <= 0.0 and ice_room_at(m.p - Vector2(0.0, 6.0)):
			grip = ice_room_grip(m.p - Vector2(0.0, 6.0), true)
		elif bool(theme.liquid.get("slide", false)) and _cell(int(floor(m.p.x / C)), int(floor((m.p.y - 6.0) / C))) == 2 and not "frost" in m.tags:
			grip = float(theme.liquid.get("grip", mover.grip("glaze")))
		elif bool(env.get("slide", false)):
			grip = float(env.get("grip", mover.grip("medium")))
		elif not "frost" in m.tags and float(m.get("alt", 0.0)) <= 0.0 and FrostCombat.FrostMoves.ice_under(self, m.p):
			# a move's ice patch is Glatteis under the monsters too (its rule: element_rules.json mediums.ice; physics plan R26)
			grip = float(ElementRules.medium("ice").get("grip", mover.grip("medium")))
		# sliding (no firm footing): the snow layer scratches skid marks for it (src/hero/frost_snow.gd)
		m.slid = grip < MotionKit.FIRM
		var pull := ElementRules.pull(env, m.p, env.get("centre", m.p)) if env.has("pull") else Vector2.ZERO
		var moved_from: Vector2 = m.p
		var rr: float = m.r * 0.7
		var avoid: bool = m.kind != "boss"
		# slide, pull and the decaying push (m.k), axis by axis against the walls (MotionKit.step_body)
		var step: Dictionary = mover.step_body(m.p, m.get("sv", v), v, grip, pull, m.k, dt, mover.host.mob_solid(rr, avoid))
		v = step.v
		m.sv = step.vel
		m.k = step.push
		m.k_in = step.push_in
		m.p = step.p
		mob_moved(m)
		if m.has("slam"):
			as_source("hero", func() -> void: story_hero.check_slam(m, moved_from, dt))
		# reeling from a perfect block (HeroKit.stagger) its touch hurts nobody
		if d < m.r + 22.0 and goal == me and float(m.get("reel", 0.0)) <= 0.0:
			var who: String = ("von %s erwischt" % def.name) if def.has("name") else "von Glutlingen verbrannt"
			var was_inv := float(state.inv)
			_hurt("von %s erschlagen" % W.boss.name if m.kind == "boss" else who, 1, m.p, m)
			# a touch that landed shoves the hero back here too: a dasher's or the Golem's charge
			# harder (frost_theme.json vfx.knock; physics plan F39)
			if frost_fx != null and float(state.inv) > was_inv and not HeroKit.perfect_now(self):
				var busy: Variant = m.get("busy", {})
				var charging := float(m.get("dash", 0.0)) > 0.0 or (busy is Dictionary and str((busy as Dictionary).get("do", "")) == "charge")
				frost_fx.hit_hero(m.p, "dash" if charging else "contact", "small", m.kind == "boss")
			if def.has("chill") and not HeroKit.perfect_now(self):
				state.chill = float(def.chill)
		if not prey.is_empty() and d < m.r + float(prey.r) * 0.5 + 22.0:
			_themed_mad_strike(m, prey, true)
		if m.kind == "spucker" or beh == "shooter":
			m.shoot -= dt
			# it winds up first and shoots where the hero stood once aim_lock of the windup had run
			# (frost_moves.gd basic_tell, the attack tokens)
			var shot_at: Vector2 = FrostCombat.FrostMoves.basic_tell(self, m, "bolt", goal, dt, m.shoot <= 0.0)
			if shot_at.is_finite():
				m.shoot = float(def.fire_every)
				_enemy_shot(m.p - Vector2(0, 40), shot_at - m.p - Vector2(0, 30), float(def.get("shot_speed", balance.enemy_shot.speed)), m)
				# the Frost-Skelett shoots bone arrows (src/vfx/shot_looks.gd, shot_looks.json)
				ShotLooks.tag(eshots[-1], str(m.kind))
				# the crypt's attack sound of its kind (story_sound.gd), else the theme's
				if sound != null:
					sound.on_attack(m, "shooter")
				else:
					_sound("enemy_shot")
		elif beh == "turret":
			m.shoot -= dt
			# a fan winds up like a shot (frost_moves.gd basic_tell)
			var fan_at: Vector2 = FrostCombat.FrostMoves.basic_tell(self, m, "bolt", goal, dt, m.shoot <= 0.0)
			if fan_at.is_finite():
				m.shoot = float(def.fire_every)
				var fan := int(def.fan)
				var base: float = (fan_at - m.p).angle() if fan_at.distance_to(m.p) > 1.0 else dir.angle()
				for k in range(fan):
					var a: float = base + (float(k) / maxf(1.0, fan - 1.0) - 0.5) * float(def.spread)
					_enemy_shot(m.p - Vector2(0, m.cy), Vector2(cos(a), sin(a)), float(def.shot_speed), m)
				if sound != null:
					sound.on_attack(m, "turret", fan)
		elif m.kind == "boss" and m.has("kit"):
			# the kit's attacks sound through the crypt's windup and attack routing (story_sound.gd)
			as_source("kit", func() -> void: BossKit.update(self, m, dt))
		elif m.kind == "boss":
			m.summon -= dt
			var adds := 0
			for o: Dictionary in mobs:
				if o.room == m.room and o.kind != "boss":
					adds += 1
			if m.summon <= 0.0 and adds < int(balance.mobs.boss.max_adds):
				m.summon = float(W.boss.summon)
				var adds_kinds: Array = theme.get("boss_adds", ["glut", "spucker" if W.final else "glut"])
				_spawn_mob(m.room, m.p + Vector2(-100, 30), adds_kinds[0])
				_spawn_mob(m.room, m.p + Vector2(100, 30), adds_kinds[1 % adds_kinds.size()])
			if float(W.boss.get("ring", 0.0)) > 0.0:
				m.ring_t -= dt
				if m.ring_t <= 0.0:
					m.ring_t = float(W.boss.ring)
					m.spin += 0.3
					var n := 16 if W.final else 10
					for k in range(n):
						var a: float = m.spin + float(k) / n * TAU
						_enemy_shot(m.p - Vector2(0, 70), Vector2(cos(a), sin(a)), float(balance.enemy_shot.ring_speed), m)
	_mad_mob = {}
	_mad_prey = {}
	for m: Dictionary in mobs.duplicate():
		if m.hp > 0.0 or (m.has("kit") and BossKit.next_phase(self, m)):
			continue
		# with the feel the kill is the crypt's alone (burst in its material, pool, sheet: feedback.gd)
		if feel == null:
			_burst(m.p - Vector2(0, 30), 70 if m.kind == "boss" else 16)
		mobs.erase(m)
		mob_removed(m)
		# with the feel the kill sounds in the crypt material (feedback.gd via FrostCombat.after_kill)
		if feel == null:
			_sound("kill_" + str((m.def as Dictionary).get("material", "void")))
		if sound != null: sound.mob_died(m)
		HeroKit.gain(self, HeroKit.exp_for(self, m))
		SubKit.on_kill(self, m)
		if talents != null: talents.killed(m)
		FrostCombat.after_kill(self, m)
		# a splitting enemy (e.g. ice slime) leaves smaller ones behind
		var kids := MobRules.split_children(m.def)
		for i in range(kids.size()):
			var a: float = TAU * float(i) / kids.size() + float(m.seed)
			_spawn_mob(m.room, m.p + Vector2(cos(a), sin(a)) * 40.0, kids[i])
			mobs[mobs.size() - 1].spawn = 0.15
		var rest := mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room)
		if rest.is_empty():
			_clear_room(W.rooms[m.room], m.p)


## Boss areas: icicles strike at the end of their warning, chill fields slow while
## stood in, telegraph and safe marks just fade (the boss reads them).
func _update_zones(dt: float) -> void:
	var me := Vector2(player.x, player.y)
	for z: Dictionary in zones:
		z.t -= dt
		var inside := me.distance_to(z.p) < float(z.r)
		match z.kind:
			"icicle":
				if z.t <= 0.0:
					_burst(z.p, 14)
					if inside:
						_hurt("von einem Eiszapfen getroffen")
			"chill":
				if inside:
					state.chill = maxf(state.chill, 0.3)
	zones = zones.filter(func(z: Dictionary) -> bool: return z.t > 0.0)


## A bursting hero shot (magic splash, fireball, arrow fist): everyone in the radius
## takes the burst multiple; fire sets them burning, the fist slows.
func _explode(s: Dictionary, first: Dictionary) -> void:
	s.done = true
	s.t = 0.0
	var radius := float(s.get("burst", s.get("splash", 0.0)))
	var mult := float(s.get("burst_mult", s.get("mult", 1.0)))
	for o: Dictionary in mobs:
		# Ignaroth's rig: the blast must reach a drawn part; the nearest one takes it (src/hell/drake_rig_host.gd)
		var rigged: bool = drake_rig != null and drake_rig.has_rig(o)
		if _hittable(o) and (drake_rig.blast_hits(o, s.p, radius) if rigged else s.p.distance_to(o.p - Vector2(0, o.cy)) < radius + o.r):
			_damage_mob(o, (o.p - s.p).normalized() * 500.0, mult)
			if s.has("burn"):
				HeroKit.burn_mob(o, float(s.burn), float(s.burn_time))
			if s.has("slow"):
				HeroKit.slow_mob(self, o, float(s.slow), float(s.slow_time))
	if wreck != null:
		wreck.blast(s.p, radius, "blast", true)
	# effect hook: with the feel the mage's splash is the crypt's area perk (perk_events blast:
	# feedback.gd's magic burst in the staff's glow, its sound, the gold ring), not the world's circle
	if feel != null and str(s.get("kind", "")) == "magic":
		feel.perk("blast", s.p)
		return
	fx.append({"kind": "blast", "p": s.p, "r": radius, "t": 0.3, "max": 0.3, "gravity": s.get("kind", "") in ["gravity", "rock"], "shot": s.get("kind", "")})
	if s.get("kind", "") == "pyro" and talents != null: talents.tc.show_effect("explosion", s.p, radius * 0.45, {"fx": "fire", "life": 0.55, "owner": 1, "wrecked": true})
	if int(s.get("split", 0)) > 0:
		RelicKit.split_rock(self, s)
	_burst(s.p, 18)
	_sound("blast")


## The mage's shot `s` reached the point the mouse showed (MageBolt.aim) and struck nothing on
## the way: it bursts there on the floor as on an enemy. The fireball and the arcane bolt in
## their splash (the fire's explosion sets off what lies there, story_elements.gd), the icicle
## and the void orb in their own burst, their frost and void touching the floor (MageBolt.touch).
func _land_shot(s: Dictionary) -> void:
	s.t = 0.0
	if float(s.get("splash", 0.0)) > 0.0 or s.has("burst"):
		_explode(s, {})
	MageBolt.burst(self, s, {}, true)
	MageBolt.touch(self, s)


## Where the mage's left-click would burst now: the mouse (mirrored while he is mad), held
## within the shot's flight (MageBolt.land_reach); INF when no mark shows (another class,
## a window open, a potion being thrown, the hero down).
func mage_mark() -> Vector2:
	if class_id != "mage" or str(weapon.get("shot", "")) != "magic" or int(state.get("hp", 0)) <= 0 or throw_slot >= 0 \
			or state.get("tree_open", false) or _window_open():
		return Vector2.INF
	var from := Vector2(player.x, player.y - 40)
	var to: Vector2 = (HeroKit.target(self) - from) * (-1.0 if FrostCombat.HeroFx.inverted(self) else 1.0)
	if to.length() < 1.0:
		return Vector2.INF
	var flight := float(weapon.get("speed", balance.shot.speed)) * float(MageBolt.spec(MageBolt.element(self)).get("speed_mult", 1.0)) * float(state.range)
	return from + to.normalized() * MageBolt.land_reach(to.length(), flight)


func _update_hazards(dt: float) -> void:
	var me := Vector2(player.x, player.y)
	var cr: Dictionary = W.rooms[state.room]
	var hz: Dictionary = balance.hazards
	for e: Dictionary in W.ents:
		# the timers count down first: the branches below skip the rest of the loop with `continue`,
		# which left a wrongly stepped plate red and locked for good. A wrong plate stays marked
		# while the hero still stands on it, then clears and can be stepped again.
		if e.get("wrong", 0.0) > 0.0 and not (e.type == "plate" and absf(me.x - e.x) <= 44 and absf(me.y - 10 - e.y) <= 44):
			e.wrong = maxf(0.0, e.wrong - dt)
		if e.get("hit", 0.0) > 0.0:
			e.hit = maxf(0.0, e.hit - dt)
		match e.type:
			"launch":
				# a sleeping pad waits for its group (a plate, lever or fire bowl of its room)
				if dash.is_empty() and LaunchPads.awake(e, W.groups):
					launch_pads.update_pad(e, me, dt)
			"spikes":
				e.up = int(state.t / float(hz.spike_period)) % 2 == int(e.phase)
				# the spikes shoot up and sink back over 0.08 s instead of popping (physics plan R21);
				# shooting up they puff dust off the plate
				var rise := move_toward(float(e.get("rise", 1.0 if e.up else 0.0)), 1.0 if e.up else 0.0, dt / 0.08)
				if rise >= 1.0 and float(e.get("rise", 1.0)) < 1.0 and feel != null:
					if tex.has("ice_crack"):
						# the Frostgruft's ice trap: shards and snow burst off as the ice breaks through
						feel.feedback.particles.shatter(Vector2(e.x, e.y - 6.0) / float(feel.scale), 6, Vector2.ZERO, 90.0)
					else:
						feel.feedback.particles.dust_flat(Vector2(e.x, e.y) / float(feel.scale), 10.0, 6)
				elif rise < 1.0 and float(e.get("rise", 0.0)) >= 1.0 and feel != null and tex.has("ice_crack"):
					# sinking back it crumbles: a few chips fall off
					feel.feedback.particles.shatter(Vector2(e.x, e.y - 6.0) / float(feel.scale), 3, Vector2.ZERO, 50.0)
				e.rise = rise
				if e.up and absf(me.x - e.x) < 42 and absf(me.y - 12 - e.y) < 40:
					_hurt("von Stacheln getroffen")
			"vent":
				e.burst = fmod(state.t + float(e.offset), float(hz.vent_period)) < float(hz.vent_burst)
				if e.burst and me.distance_to(Vector2(e.x, e.y)) < float(hz.vent_radius):
					_hurt("vom Glutschlot verbrannt")
				# its matter, per second, not per frame (physics plan R21/F53): the Hölle's vent throws
				# real flames that rise and smoke, the Krypta's Moder vent breathes green fumes
				if e.burst:
					e.vent_due = float(e.get("vent_due", 0.0)) + dt * 36.0
					while float(e.vent_due) >= 1.0:
						e.vent_due = float(e.vent_due) - 1.0
						_vent_matter(e)
			"plate":
				if launch_pads.flying() or e.get("on", false) or absf(me.x - e.x) > 44 or absf(me.y - 10 - e.y) > 44:
					continue
				var g: Dictionary = W.groups[e.group]
				if g.solved:
					continue
				if g.kind == "sequence":
					if cr.fight or e.get("wrong", 0.0) > 0.0:
						continue
					var res := Rules.step_sequence(W.ents, W.groups, e)
					# a plate is part of the world: its click stays off the menu bus
					_sound("plate_wrong" if res == "wrong" else "plate", "world" if feel != null else "")
					if res == "solved":
						_solve_group(e.group)
					elif res == "right":
						var p := Rules.group_progress(W.ents, e.group)
						_toast("Platte %d von %d richtig." % [p.x, p.y])
					elif res == "wrong":
						e.wrong = 0.8
						# a trap plate: its number is never due (higher than its group has plates)
						if int(e.order) > int(g.get("count", 99)):
							_toast("Eine Fallenplatte!")
						else:
							_toast("Falsche Reihenfolge. Die Platten erlöschen.")
						# a guarded plate lets its enemies out, once
						if e.has("enemies"):
							release_room_enemies(e.enemies, Vector2(e.x, e.y), int(e.room))
							e.erase("enemies")
				else:
					e.on = true
					var p := Rules.group_progress(W.ents, e.group)
					if p.x == p.y:
						_solve_group(e.group)
					else:
						_toast("Runenplatte %d von %d aktiviert." % [p.x, p.y])
			"key", "heart", "gem", "life_heart":
				if e.get("taken", false) or me.distance_to(Vector2(e.x, e.y)) > 52:
					continue
				if e.type == "heart" and state.hp >= state.max_hp:
					continue
				e.taken = true
				if e.type == "key":
					state.keys[e.key] = true
					# with the feel the key is a crypt pickup like the others (loot_taken below)
					if feel == null:
						_sound("key")
					_toast("%s aufgehoben." % key_label(e.key))
				elif e.type == "life_heart":
					var grown := gain_life(int(e.get("value", 2)))
					if feel != null:
						feel.hero_perk("heal")
					_toast("Lebensherz: +%d LP Lebensgrenze" % grown if grown > 0 else "Lebensherz: +%d LP geheilt (Lebensgrenze voll)" % int(e.get("value", 2)))
				elif e.type == "heart":
					state.hp = mini(state.max_hp, state.hp + RewardRules.heal(depth()))
					# effect hook: the crypt's heal marker over the hero
					if feel != null:
						feel.hero_perk("heal")
					_toast("+1 Herz")
				# the crypt's pickup: its loot_taken fx event (the pickup sheet and its chime through feedback.gd)
				if feel != null:
					feel.fx_event("loot_taken", Vector2(e.x, e.y))


func _update_rooms() -> void:
	var ri := _room_at_world(player.x, player.y - 12.0)
	if ri >= 0 and ri != state.room:
		state.room = ri
		# the room banner only the first time a room is entered
		if not state.visited.has(ri):
			state.banner = {"text": W.rooms[ri].name, "sub": W.rooms[ri].kind, "t": 0.0}
		state.visited[ri] = true
	var r: Dictionary = W.rooms[state.room]
	if r.cleared or r.fight:
		return
	if _fully_inside(r, player.x, player.y):
		_start_fight(r)


## True when the hero at x, y stands inside room r with a margin on every side
## (the point where a fight starts and the gates may close behind them).
func _fully_inside(r: Dictionary, x: float, y: float) -> bool:
	var hw := float(balance.player.half_width) + 40.0
	for o: Vector2 in [Vector2(-hw, -60), Vector2(hw, -60), Vector2(-hw, 30), Vector2(hw, 30)]:
		if _room_at_world(x + o.x, y + o.y) != r.index:
			return false
	return true


func _update_embers(dt: float) -> void:
	if state.light:
		for k in range(int(W.theme.embers)):
			var x := camera.position.x + randf_range(-900, 900)
			var y := camera.position.y + randf_range(-500, 500)
			if _cell(int(floor(x / C)), int(floor(y / C))) == 2:
				embers.append({"p": Vector2(x, y), "v": Vector2(randf_range(-10, 10), randf_range(-90, -40)), "t": randf_range(1.2, 2.2), "big": false, "gold": false})
	for p: Dictionary in embers:
		p.p += p.v * dt
		# a shockwave or a scream blew it along (hell_monsters.gd _blow_front); the push dies away
		if p.has("push"):
			p.p += (p.push as Vector2) * dt
			p.push = (p.push as Vector2) * maxf(0.0, 1.0 - 3.5 * dt)
		p.t -= dt
	embers = embers.filter(func(p: Dictionary) -> bool: return p.t > 0.0)
	if embers.size() > 360:
		embers = embers.slice(embers.size() - 360)
	_slosh_lava(dt)
	_bubble_lava(dt)
	_step_gas(dt)
	_step_elements(dt)


## The pool layer the hero and the monsters stand in: the world's own (the
## hell's and the crypt's puddles) or the talents' (the Frostgruft draws its
## pools there); null without one.
func _pool_layer() -> RefCounted:
	if pools != null:
		return pools
	if talents != null and talents.fx != null:
		return talents.fx.pools
	return null


## The element physics on the hero: the world's ElementExposure (exposure(),
## src/physics_kit/element_exposure.gd) lets the pool he stands in and the gas
## he breathes act on him (half hearts drained per second, his conditions, a
## douse, the combos; a drunk potion wards him, the Leerenmagier is exempt
## from the void). Kept here for the rest of the world: hero_medium (his
## footing and pull, _update_player), hero_gas, their style and material, the
## view closing inside gas (vision: src/hero/story_glow.gd), his madness clock
## and the ice chips his boots scratch up. The lava and ice TILES of a world
## keep their theme.liquid rule in _update_player; this is the pools' and clouds'.
func _step_elements(dt: float) -> void:
	vision.goal = 0.0
	# the pools' gameplay field runs on this clock, never the drawing's (src/physics_kit/pool_field.gd
	# via the layer's advance): a pool a worker shaped counts from its moment in every world
	var layer: RefCounted = _pool_layer()
	if layer != null and layer.has_method("advance"):
		layer.advance(float(state.t))
	if story_elements != null:
		story_elements.update(dt)
	var met: Dictionary = exposure().step(player, dt)
	hero_medium = met.medium
	hero_medium_style = met.style
	hero_gas = met.gas
	hero_gas_mat = met.gas_mat
	# dead, or burning he set the poison he stepped in off: nothing else this frame
	if met.skipped or met.ignited == "pool":
		_ease_vision(dt)
		return
	# sliding fast over ice the boots scratch it: ice chips spray behind (the Frostgruft's
	# snow layer does this on its tiles; this is the pools' ice in every world)
	# (how fast and how often: physics_motion.json skid, MotionKit.skid)
	if (bool(hero_medium.get("slide", false)) or ice_room_at(Vector2(player.x, player.y - 6.0))) and monsters != null and motion_kit().skid((player.vel as Vector2).length(), dt):
		var back: Vector2 = -(player.vel as Vector2).normalized()
		monsters._pixel_burst(Vector2(player.x, player.y) + back * 10.0, 2, monsters.PX_COL.frost, 90.0, 160.0, 0.5)
	# WAHN (madness_rules.json madness): a void pool drives him mad after madness.hero_delay s, his
	# controls invert until hero_after s after he left it (src/hell/hero_fx.gd mad_step: state.mad,
	# state.mad_warn). The void pools he can step in that are his own are the Leerenmagier's: immune.
	FrostCombat.HeroFx.mad_step(self, bool(met.maddening) and not _void_mind(), dt)
	if not hero_gas.is_empty():
		vision.goal = float(met.vision)
		vision.mat = hero_gas_mat
	_ease_vision(dt)


## The element physics on a themed world's enemy (the Frostgruft's, theme.mobs):
## the same ElementExposure as the hero and the hell monsters (exposure();
## hell_monsters.gd _step_medium), combos and the burrowed/airborne guard
## included. A gas that blinds holds its shot back (m.shoot). Returns the
## medium's rule ({} on firm floor) for the movement (slide, pull).
func _step_mob_medium(m: Dictionary, dt: float) -> Dictionary:
	preload("res://src/combat/enemy_sight.gd").step(m,dt)
	var met: Dictionary = exposure().step(m, dt)
	if float(met.blind) > 0.0:
		m.shoot = maxf(float(m.get("shoot", 0.0)), float(met.blind))
	return met.medium


## The middle of the nearest puddle zone of `style` round `at` (the hell's own
## puddles; `at` itself when none is known).
func _pool_centre(at: Vector2, style: String) -> Vector2:
	var best := at
	var best_d := INF
	if monsters != null:
		for z: Dictionary in monsters.zones:
			if str(z.kind) != "puddle" or ElementRules.material(str(z.get("st", "lava"))) != ElementRules.material(style):
				continue
			var d: float = at.distance_squared_to(z.p)
			if d < best_d:
				best_d = d
				best = z.p
	elif _pool_layer() != null and _pool_layer().get("pool_field") != null:
		# no monster runtime (the Frostgruft): its pools lie in the talents' layer (physics plan R26)
		return _pool_layer().pool_field.centre(at, style)
	return best


## The view inside gas closes in and opens again (element_rules.json vision):
## its reach is the cloud's reach round the hero, measured probe_hz times a
## second along eight rays, between min_radius and max_radius (world px).
func _ease_vision(dt: float) -> void:
	var rules := ElementRules.vision()
	var goal := float(vision.goal)
	var rate := dt / maxf(0.05, float(rules.get("fade_in", 0.35)) if goal > float(vision.k) else float(rules.get("fade_out", 0.55)))
	vision.k = move_toward(float(vision.k), goal, rate)
	if goal <= 0.0 and float(vision.k) <= 0.0:
		vision.r = 0.0
		return
	vision.probe = float(vision.probe) - dt
	if goal > 0.0 and gas != null and float(vision.probe) <= 0.0:
		vision.probe = 1.0 / maxf(1.0, float(rules.get("probe_hz", 8)))
		var feet := Vector2(player.x, player.y)
		var reach: float = gas.extent(feet, str(vision.mat), float(rules.get("thin", 0.12)), float(rules.get("step", 12)) * PIXEL_WORLD / 2.0, float(rules.get("max_radius", 420)) * PIXEL_WORLD / 2.0)
		var lo := float(rules.get("min_radius", 70)) * PIXEL_WORLD / 2.0
		var hi := float(rules.get("max_radius", 420)) * PIXEL_WORLD / 2.0
		var want := clampf(reach + lo * 0.5, lo, hi)
		vision.r = want if float(vision.r) <= 0.0 else lerpf(float(vision.r), want, 0.5)


## Now and then a lava pool in view sloshes over its rim onto the floor
## (hell_balance.json monsters.feel.lava "slosh_rate" per second): a few drops
## of lava as glowing pixels that lie there as embers and cool to soot
## (hell_monsters.gd lava_splash). Only where a lava cell borders the floor.
func _slosh_lava(dt: float) -> void:
	if monsters == null or not theme.liquid.get("hurt", false) or _floor_mat() != "lava":
		return
	var spec: Dictionary = (balance.monsters.get("feel", {}) as Dictionary).get("lava", {})
	lava_slosh += float(spec.get("slosh_rate", 0.0)) * dt
	while lava_slosh >= 1.0:
		lava_slosh -= 1.0
		for attempt in range(10):
			var cx := int(floor((camera.position.x + randf_range(-900, 900)) / C))
			var cy := int(floor((camera.position.y + randf_range(-500, 500)) / C))
			var t := _cell(cx, cy)
			if t != 2 and t != 3:
				continue
			var outs: Array = []
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _cell(cx + d.x, cy + d.y) == 1:
					outs.append(d)
			if outs.is_empty():
				continue
			var dir := Vector2(outs[randi() % outs.size()] as Vector2i)
			var at := Vector2((cx + 0.5) * C, (cy + 0.5) * C) + dir * C * 0.4 + dir.orthogonal() * randf_range(-0.4, 0.4) * C
			var drops: Array = spec.get("drops", [3, 6])
			monsters.lava_splash(at, dir, randi_range(int(drops[0]), int(drops[1])))
			break


## The gas runs on; the hero and the monsters part it as they walk through.
func _step_gas(dt: float) -> void:
	if gas == null:
		if talents != null and feel != null:
			# the Frostgruft has no puddle layer: its gas is made here for the talents
			gas = Gas.new(PIXEL_WORLD, _floor_open)
			# blasts in the feel's particles blow it away too
			feel.feedback.particles.add_liquid(gas, feel.scale)
		else:
			return
	gas.step(dt, float(state.t))
	gas.part(Vector2(float(player.x), float(player.y)), 22.0, dt)
	for m: Dictionary in mobs:
		gas.part(Vector2(m.p), 18.0, dt)


## Bubbles on the lava floor in view (hell_balance.json monsters.feel.lava
## "bubble_rate" per second, at most "bubbles" at once): each swells for a
## moment, bursts and spits a few glowing drops in arcs (the feel's particles,
## "glut": they lie down as embers and cool to soot, or sink into the lava).
## What the world's liquid floor (tiles 2 and 3) is made of: theme.liquid.material, else lava
## where it hurts and ice where it slides (physics plan R10, decision D3: the Krypta's Moder is
## cold poison sludge, not lava).
func _floor_mat() -> String:
	var liquid: Dictionary = theme.get("liquid", {})
	return str(liquid.get("material", "lava" if bool(liquid.get("hurt", false)) else ("ice" if bool(liquid.get("slide", false)) else "")))


## One bit of a bursting vent's matter: flames rising off a lava vent (fire), green fumes and
## smoke off the Krypta's Moder vent, the old ember squares without the particles.
func _vent_matter(e: Dictionary) -> void:
	if feel == null:
		embers.append({"p": Vector2(e.x + randf_range(-20, 20), e.y - 10), "v": Vector2(randf_range(-20, 20), randf_range(-280, -160)), "t": 0.8, "big": true, "gold": false})
		return
	var P: RefCounted = feel.feedback.particles
	var at := Vector2(e.x + randf_range(-16, 16), e.y - 10) / float(feel.scale)
	if _floor_mat() == "moder":
		var green: Array = PoolPaint.settings().get("materials", {}).get("poison", {}).get("ramp", {}).values()
		var cols: Array = []
		for hex: Variant in green.slice(0, 3): cols.append(Color(str(hex)))
		P.motes(at, 1, cols, 30.0, 4.0)
		if randf() < 0.25: P.smoke(at, 1, 4.0)
	else:
		P.flames(at, 1, [], 3.0, 2.0, Vector2(randf_range(-10, 10), -30))


func _bubble_lava(dt: float) -> void:
	if not bool((theme.get("liquid", {}) as Dictionary).get("hurt", false)):
		return
	# lava bubbles glow and spit glowing drops; the Moder bubbles olive and spits sludge drops
	var hot := _floor_mat() == "lava"
	var spec: Dictionary = (balance.monsters.get("feel", {}) as Dictionary).get("lava", {}) if balance.has("monsters") else {}
	for b: Dictionary in lava_bubbles:
		var before := float(b.t)
		b.t = before + dt
		if before < float(b.T) * 0.7 and float(b.t) >= float(b.T) * 0.7 and feel != null:
			var ramp: Dictionary = PoolPaint.settings().get("materials", {}).get("lava" if hot else "poison", {}).get("ramp", {})
			for i in range(1 + int(b.big)):
				var drop: Dictionary = feel.feedback.particles.emit(Vector2(b.p) / feel.scale, Vector2.from_angle(randf() * TAU) * randf_range(15.0, 45.0), Color(str(ramp.get("hi", "facb3e"))),
					1.5, "glut" if hot else "drop", 2.0, 2.0, randf_range(60.0, 110.0), 1.5)
				if hot:
					drop.ember_life = randf_range(0.8, 1.4)
					drop.soot = 0.5
	lava_bubbles = lava_bubbles.filter(func(b: Dictionary) -> bool: return float(b.t) < float(b.T))
	lava_bubble_due += float(spec.get("bubble_rate", 9.0)) * dt
	while lava_bubble_due >= 1.0:
		lava_bubble_due -= 1.0
		if lava_bubbles.size() >= int(spec.get("bubbles", 24)):
			break
		for attempt in range(8):
			var at := camera.position + Vector2(randf_range(-520, 520), randf_range(-300, 300))
			var t := _cell(int(floor(at.x / C)), int(floor(at.y / C)))
			if t != 2 and t != 3:
				continue
			lava_bubbles.append({"p": (at / PIXEL_WORLD).floor() * PIXEL_WORLD, "t": 0.0, "T": randf_range(0.45, 0.75), "big": randi() % 2})
			break


## The lava floor's bubbles (art cells of the world's 3 px grid): a dome that
## swells with a lit top, then bursts into a ring of bright cells.
func _draw_lava_bubbles(l: CanvasItem) -> void:
	if lava_bubbles.is_empty():
		return
	var ramp: Dictionary = PoolPaint.settings().get("materials", {}).get("lava" if _floor_mat() == "lava" else "poison", {}).get("ramp", {})
	var spec := Color(str(ramp.get("spec", "fdf7ed")))
	var hi := Color(str(ramp.get("hi", "facb3e")))
	var lite := Color(str(ramp.get("lite", "ee8e2e")))
	var shade := Color(str(ramp.get("shade", "4f343c")))
	var px := PIXEL_WORLD
	for b: Dictionary in lava_bubbles:
		var k := float(b.t) / float(b.T)
		var c: Vector2 = b.p
		if k < 0.7:
			var r := int(round((2.0 + float(b.big)) * k / 0.7))
			# a dark rim round the dome first: it reads against the bright, busy lava
			for y in range(-r - 1, 1):
				for x in range(-r - 1, r + 2):
					if Vector2(x, y).length() <= float(r) + 1.3:
						l.draw_rect(Rect2(c + Vector2(x, y) * px, Vector2(px, px)), shade)
			for y in range(-r, 1):
				for x in range(-r, r + 1):
					if Vector2(x, y).length() > float(r) + 0.3:
						continue
					var col := lite
					if y == -r: col = hi
					if y == -r and x == -1: col = spec
					l.draw_rect(Rect2(c + Vector2(x, y) * px, Vector2(px, px)), col)
			l.draw_rect(Rect2(c + Vector2(-r - 1, 1) * px, Vector2((2 * r + 3) * px, px)), shade)
		else:
			var s := (k - 0.7) / 0.3
			var reach := 1.0 + 2.5 * s
			for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(0.7, -0.7)]:
				l.draw_rect(Rect2(c + (d * reach).round() * px, Vector2(px, px)), spec if s < 0.5 else hi)


## Rendered feet shared by the hero's body, weapon, guard, light and camera.
func render_hero_position() -> Vector2:
	return presentation.hero_position(player)


## Rendered enemy feet; collision, aiming and damage retain authoritative p/pos.
func render_mob_position(mob: Dictionary) -> Vector2:
	return presentation.mob_position(mob)


func _update_camera(dt: float) -> void:
	var r: Dictionary = W.rooms[state.room]
	# External jumps are detected against the last written camera, never against
	# a rounded presentation centre. Otherwise pixel snapping can reset follow.
	if not _camera_written.is_finite() or not camera.position.is_equal_approx(_camera_written):
		presentation.reset()
		cam_rig.reset(Vector2(player.x, player.y - 40))
	presentation.teleport_distance = float(cam_rig.cfg.get("presentation", {}).get("teleport_distance", 192.0))
	var hero := render_hero_position() - Vector2(0, 40)
	var viewport := get_viewport()
	var base_zoom := float(balance.view.base_width) / float(balance.view.width)
	var fixed_pixel_zoom := bool(theme.get("pixel", true)) and bool(cam_rig.cfg.get("pixel", {}).get("fixed_zoom", true))
	# canvas_items/expand can expose more world on wide or tall windows. Use
	# that actual view for framing, clamping and culling instead of assuming 16:9.
	var view := viewport.get_visible_rect().size / base_zoom
	# a mirror room of the Frostgruft (src/world_kit/frost_puzzles.gd): the camera zooms out and looks
	# between hero and ghost, so both and both their fields stay on screen
	view_far = frost_puzzles.view_zoom(dt, fixed_pixel_zoom) if frost_puzzles != null else 1.0
	var ghost: Dictionary = frost_puzzles.room_ghost() if frost_puzzles != null else {}
	if not ghost.is_empty():
		hero = hero.lerp(Vector2(float(ghost.x), float(ghost.y) - 30.0), 0.5)
	view /= view_far
	var bounds := Rect2()
	if _room_at_world(player.x, player.y - 12.0) >= 0:
		var lo := Vector2(r.bx * C - 70, r.by * C - 110)
		var hi := Vector2((r.bx + r.bw) * C + 70, (r.by + r.bh) * C + 80)
		bounds = Rect2(lo, hi - lo)
	var foes := _camera_foes()
	# a big jump of the shake (a slam, a blast, a heavy hit) also shoves the view away from the fight
	var shake := float(state.shake)
	if shake - _shake_was >= 10.0 and not foes.is_empty():
		cam_rig.kick(hero - (foes[0] as Vector2), "slam")
	_shake_was = shake
	var aim := get_global_mouse_position() if heroic() and not _window_open() else Vector2.INF
	cam_rig.step(dt, {"hero": hero, "aim": aim, "foes": foes, "boss": _camera_boss, "bounds": bounds,
		"view": view, "shake": shake, "t": float(state.t), "pixel": bool(theme.get("pixel", true))})
	camera.position = cam_rig.position
	camera.zoom = Vector2.ONE * base_zoom * float(cam_rig.zoom)
	# Darkness still fades in pixel mode; only non-pixel cameras animate scale.
	# A multiplier after the rig must not bypass the pixel zoom lock.
	maze_dark = move_toward(maze_dark, 1.0 if in_maze() else 0.0, dt * float(maze_cfg().get("fade", 2.5)))
	if not fixed_pixel_zoom:
		camera.zoom *= lerpf(1.0, float(maze_cfg().get("zoom", 1.2)), maze_dark)
	camera.zoom *= view_far
	# view_shift: the view sits lower so the skill bar covers none of the fight
	camera.offset = cam_rig.offset + cam_rig.view_shift
	if bool(theme.get("pixel", true)) and bool(cam_rig.cfg.get("pixel", {}).get("snap_translation", true)):
		camera.offset = StoryPresentation.pixel_center(camera.position + camera.offset, camera.zoom,
			viewport.get_visible_rect().size, viewport.get_stretch_transform()) - camera.position
	_camera_written = camera.position
	# Keep drawing, darkness and mouse conversion on this same frame's transform.
	camera.force_update_scroll()


var _camera_boss := false
## The camera's extra zoom of the room (below 1 = farther out: a Frostgruft mirror room).
var view_far := 1.0


## The live foes of the fight the hero is in (their middles), the boss first.
func _camera_foes() -> Array:
	var out: Array = []
	_camera_boss = false
	var r: Dictionary = W.rooms[state.room]
	if not bool(r.get("fight", false)):
		return out
	for m: Dictionary in mobs:
		if int(m.get("room", -1)) != int(state.room) or float(m.get("hp", 0.0)) <= 0.0 or bool(m.get("remove", false)) or m.get("dying") != null:
			continue
		var at: Vector2 = render_mob_position(m) - Vector2(0, float(m.get("cy", 20.0)))
		if bool(m.get("boss", false)) or str(m.get("kind", "")) == "boss":
			_camera_boss = true
			out.push_front(at)
		else:
			out.append(at)
	return out


## Zooms the camera in for a moment (an ultimate: "ultimate", a heavy blow: "heavy").
func camera_punch(kind := "ultimate") -> void:
	if cam_rig != null: cam_rig.punch(kind)


## Shoves the view along `dir` (assets/data/story_camera.json kick names or px).
func camera_kick(dir: Vector2, px: Variant = "hero_hit") -> void:
	if cam_rig != null: cam_rig.kick(dir, px)


# ---------- world drawing ----------

## Draws one layer: static chunks (back/front), live actors, or the monsters' attack
## shapes (the darkness and the bloom over it: src/hero/story_glow.gd).
func draw_layer(l: Layer) -> void:
	PerfMarks.begin()
	_draw_layer_kind(l)
	PerfMarks.add("d." + (l.kind if not l.kind in ["back", "front"] else "chunks"))


func _draw_layer_kind(l: Layer) -> void:
	match l.kind:
		"back": _draw_back(l)
		"front": _draw_front(l)
		# the wall snow layers; a set with snow in its drawings (theme baked_snow) needs none
		"snow_ao", "snow_lip", "snow_front":
			# the floor's cold grade under the wall snow (src/hero/frost_snow.gd draw_grade)
			if l.kind == "snow_ao":
				frost_snow.draw_grade(l, l.area)
			if not frost_snow.baked():
				frost_snow.walls.draw(l, l.area, l.kind.trim_prefix("snow_"))
		"actors": _draw_actors(l)
		"hostile_shots": _draw_hostile_shots(l)
		"glow":
			if monsters != null:
				monsters.draw_fx(l)
			if talents != null:
				talents.draw_glow(l, float(state.t))
			# the warm light breathing over the lava and fire puddles (src/vfx/pool_paint.gd)
			if pools != null:
				pools.draw_glow(l, 1.0, float(state.t))


func _draw_hostile_shots(layer: Layer) -> void:
	if eshots.is_empty(): return
	var view := _view_rect().grow(48.0)
	PixelPaint.clip = _floor_open
	for shot: Dictionary in eshots:
		var point: Vector2 = shot.p
		if not view.has_point(point): continue
		var extent := clampf(float(shot.get("size", 10.0)), 6.0, 22.0)
		if ShotLooks.is_arrow(shot): extent = 5.0
		elif bool(shot.get("fist", false)): extent = 22.0
		elif bool(shot.get("small", false)): extent = 7.0
		ShotLooks.draw_hostile_cue(layer, point, shot.get("v", Vector2.ZERO), extent, PIXEL_WORLD)
	PixelPaint.clip = Callable()


func _tex(ci: CanvasItem, name: String, pos: Vector2, flip := false, tint := Color.WHITE, scale := 1.0, scale_y := -1.0) -> void:
	# a fire or a fountain: its picture of the moment (src/vfx/fire_anim.gd)
	var t: Texture2D = fire_anim.frame(name, pos, float(state.get("t", 0.0))) if fire_anim.has(name) else tex.get(name)
	if t == null:
		return
	var size := t.get_size() * Vector2(scale, scale_y if scale_y >= 0.0 else scale)
	if flip:
		ci.draw_set_transform(pos + Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(Vector2.ZERO, size), false, tint)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(t, Rect2(pos, size), false, tint)


func _strip(ci: CanvasItem, w: Dictionary, area: Rect2) -> void:
	var wh: Texture2D = tex.wall_h
	var x0: float = maxf(w.x0, area.position.x)
	var x1: float = minf(w.x1, area.end.x)
	# a set with snow in its drawings (theme baked_snow): only the wall cells whose foot touches a
	# snow floor cell wear the snowy wall; the others (abyss, ice, thaw, a doorway) the bare one
	var bare: Texture2D = tex.get("wall_h_bare")
	var by_cell: bool = bare != null and frost_snow != null and frost_snow.baked()
	var x := x0
	while x < x1:
		var t := wh
		var cell_end := x1
		if by_cell:
			var cx := int(floor(x / C))
			cell_end = minf(x1, (cx + 1) * C)
			if not frost_snow.snow.has(int(floor((w.y + 75.0) / C)) * int(W.cols) + cx):
				t = bare
		var off := fmod(x - w.x0, t.get_width())
		var sw := minf(t.get_width() - off, cell_end - x)
		ci.draw_texture_rect_region(t, Rect2(x, w.y, sw, t.get_height()), Rect2(off, 0, sw, t.get_height()))
		x += sw


## Draws a bridge 1:1 for pixel skins: the planks repeat along its run, its far rail
## sits on the rect's far edge. Returns false when the texture is too narrow (then it stretches).
func _tile_bridge(ci: CanvasItem, t: Texture2D, r: Rect2, rails_on_x: bool, tint: Color) -> bool:
	var ts := t.get_size()
	var rail := 12.0
	var run := r.size.y if rails_on_x else r.size.x
	var across := r.size.x if rails_on_x else r.size.y
	var step_len := ts.y if rails_on_x else ts.x
	var tex_across := ts.x if rails_on_x else ts.y
	if tex_across < across or across <= rail * 2.0:
		return false
	var body := across - rail
	var a := 0.0
	while a < run:
		var step := minf(step_len, run - a)
		for part: Array in [[0.0, 0.0, body], [body, tex_across - rail, rail]]:
			if rails_on_x:
				ci.draw_texture_rect_region(t, Rect2(r.position + Vector2(part[0], a), Vector2(part[2], step)), Rect2(part[1], 0, part[2], step), tint)
			else:
				ci.draw_texture_rect_region(t, Rect2(r.position + Vector2(a, part[0]), Vector2(step, part[2])), Rect2(0, part[1], step, part[2]), tint)
		a += step
	return true


func _draw_back(l: Layer) -> void:
	var a := l.area
	var cols: int = W.cols
	var x0 := int(a.position.x / C)
	var y0 := int(a.position.y / C)
	var lava: Texture2D = tex.lava_00
	var hole_tint := Color(0.75, 0.68, 0.7)
	# pixel skins (theme.pixel_tiles) draw liquid and rims 1:1, so every pixel keeps its size
	var tiles_1to1: bool = theme.get("pixel_tiles", false)
	for y in range(y0, mini(y0 + CHUNK.y, W.rows)):
		for x in range(x0, mini(x0 + CHUNK.x, cols)):
			var i := y * cols + x
			var t: int = W.grid[i]
			var r := Rect2(x * C, y * C, C + 0.5, C + 0.5)
			if t == 0:
				if W.holes[i] == 1:
					# a skin with its own wall-top tile fills wall islands with it
					if tex.has("wall_top"):
						l.draw_texture(tex.wall_top, r.position)
					else:
						l.draw_texture_rect(tex.wall_v, r, true, hole_tint)
				continue
			# a room of nothing but ice is floored with the world's ice tile
			if t == 2 or t == 3 or (t == 1 and W.room_at[i] >= 0 and bool(W.rooms[W.room_at[i]].get("ice", false))):
				var lt: Texture2D = tex.lava_01 if (x * 7 + y * 13) % 10 > 6 else lava
				if tiles_1to1:
					l.draw_texture(lt, r.position)
				else:
					l.draw_texture_rect_region(lt, r, Rect2(14, 14, 68, 68))
			else:
				l.draw_texture(tex[W.tile_names[W.tiles[i]]], Vector2(x * C, y * C))
	var rim: Texture2D = tex.lava_edge_top
	# the Hölle's lava: a ragged crust of pixels along its edge instead of the
	# straight stone frame (src/vfx/pool_paint.gd lava_rim; drawing only)
	var crust := PoolPaint.crusts(str(theme.sprites))
	for y in range(y0, mini(y0 + CHUNK.y, W.rows)):
		for x in range(x0, mini(x0 + CHUNK.x, cols)):
			var t := _cell(x, y)
			if (t != 2 and t != 3) or crust:
				continue
			for side: Array in [[Vector2i(0, -1), Vector2(x * C, y * C), 0.0], [Vector2i(0, 1), Vector2(x * C + C, y * C + C), PI], [Vector2i(-1, 0), Vector2(x * C, y * C + C), -PI / 2], [Vector2i(1, 0), Vector2(x * C + C, y * C), PI / 2]]:
				var n := _cell(x + side[0].x, y + side[0].y)
				if n == 1 or n == 0:
					l.draw_set_transform(side[1], side[2])
					if tiles_1to1:
						l.draw_texture_rect_region(rim, Rect2(0, -18, C, 36), Rect2(0, 0, C, 36))
					else:
						l.draw_texture_rect_region(rim, Rect2(-2, -18, 50, 36), Rect2(0, 0, 48, 36))
						l.draw_texture_rect_region(rim, Rect2(46, -18, 52, 36), Rect2(6, 0, 48, 36))
					l.draw_set_transform(Vector2.ZERO)
	if crust:
		# built once per chunk and sprite set, kept on the chunk's layer
		var made: Dictionary = l.get_meta("lava_crust", {})
		if str(made.get("sprites", "")) != str(theme.sprites):
			made = PoolPaint.lava_rim(_cell, x0, y0, CHUNK.x, CHUNK.y, C, PIXEL_WORLD)
			made.sprites = str(theme.sprites)
			l.set_meta("lava_crust", made)
		if made.has("tex"):
			l.draw_texture_rect(made.tex, made.rect, false)
	_draw_world_ground(l, x0, y0)
	for d: Dictionary in W.decals:
		if not a.has_point(Vector2(d.x, d.y)):
			continue
		var t: Texture2D = tex[d.name]
		var size := (Vector2(d.w, d.h) if float(d.w) > 0.0 else t.get_size()) * Vector2(float(d.get("sx", 1.0)), float(d.get("sy", 1.0)))
		var rect := Rect2(Vector2(d.x, d.y) - size / 2.0, size)
		if tiles_1to1 and str(d.name).begins_with("bridge") and _tile_bridge(l, t, rect, d.name == "bridge_h", Color(1, 1, 1, float(d.a))):
			continue
		l.draw_texture_rect(t, rect, false, Color(1, 1, 1, float(d.a)))
	for w: Dictionary in walls.north:
		if w.y + 74.0 >= a.position.y and w.y + 74.0 < a.end.y and w.x1 > a.position.x and w.x0 < a.end.x:
			# the wall's shade on the floor; in the snow (frost_snow) snow drifts lie at its foot instead
			if frost_snow == null:
				l.draw_rect(Rect2(maxf(w.x0, a.position.x), w.y + 74.0, minf(w.x1, a.end.x) - maxf(w.x0, a.position.x), 40.0), Color(0, 0, 0, 0.35))
			_strip(l, w, a)
	var wv: Texture2D = tex.wall_v
	for s: Dictionary in walls.side:
		if s.glow:
			if a.has_point(Vector2(s.x + 31, s.y)):
				var g: Texture2D = tex.wall_v_glow
				_tex(l, "wall_v_glow", Vector2(s.x + 31 - g.get_width() / 2.0, s.y - g.get_height() / 2.0), s.flip)
			continue
		if s.x + 31 < a.position.x or s.x + 31 >= a.end.x:
			continue
		var yy: float = maxf(s.y0, a.position.y)
		var y_end: float = minf(s.y1, a.end.y)
		while yy < y_end:
			var off := fmod(yy - s.y0, wv.get_height())
			var sh := minf(wv.get_height() - off, y_end - yy)
			if s.flip:
				l.draw_set_transform(Vector2(s.x + wv.get_width(), yy), 0.0, Vector2(-1, 1))
				l.draw_texture_rect_region(wv, Rect2(0, 0, wv.get_width(), sh), Rect2(0, off, wv.get_width(), sh))
				l.draw_set_transform(Vector2.ZERO)
			else:
				l.draw_texture_rect_region(wv, Rect2(s.x, yy, wv.get_width(), sh), Rect2(0, off, wv.get_width(), sh))
			yy += sh
	for p: Vector2 in walls.posts:
		if a.has_point(p - Vector2(0, 1)):
			var g: Texture2D = tex.wall_h_glowpost
			l.draw_texture(g, p - Vector2(g.get_width() / 2.0, g.get_height()))
	for c: Vector2 in walls.caps:
		if a.has_point(c):
			l.draw_texture(tex.corner_cap, c - Vector2(38, 38))
	for w: Dictionary in W.wall_decor:
		# burning wall decor moves: drawn every frame with the actors (_draw_wall_fires)
		if a.has_point(Vector2(w.x, w.y + 74)) and not fire_anim.has(w.name):
			var t: Texture2D = tex[w.name]
			var sx := float(w.get("sx", 1.0))
			_tex(l, w.name, Vector2(w.x - t.get_width() * sx / 2.0, w.y), w.flip, Color.WHITE, sx, float(w.get("sy", 1.0)))


## The lit wall fires (torches, wall braziers) near the view throw real embers and a wisp of
## smoke from their flame tips (src/vfx/fire_anim.gd tips; vfx_particles.json wall_fire;
## physics plan R21): they rise, drift with the wind and the embers sink and go out on the floor.
var _wall_fire_due: Dictionary = {}


func _wall_fire_matter() -> void:
	if feel == null or fire_anim == null or not fire_anim.has_method("tips"):
		return
	var P = feel.feedback.particles
	var spec: Dictionary = P._data.get("wall_fire", {})
	if spec.is_empty():
		return
	var now := float(state.t)
	var view := _view_rect().grow(40)
	var s := 1.0 / float(feel.scale)
	var cols: Array = spec.get("colors", ["#ffb04a"])
	var smoke := Color(str(spec.get("smoke", "#3a3438")))
	var base := float(spec.get("base", 74))
	var i := 0
	for w: Dictionary in W.wall_decor:
		i += 1
		if not fire_anim.has(w.name) or not view.has_point(Vector2(w.x, w.y + base)):
			continue
		var t: Texture2D = tex.get(w.name)
		if t == null:
			continue
		var j := 0
		for tip: Vector2 in fire_anim.tips(w.name):
			j += 1
			var q := Vector2(w.x - t.get_width() / 2.0 + (t.get_width() - tip.x if bool(w.get("flip", false)) else tip.x), w.y + tip.y)
			var key := i * 16 + j
			var last: Vector3 = _wall_fire_due.get(key, Vector3(now, 0.0, 0.0))
			var step := clampf(now - last.x, 0.0, 0.1)
			var embers := last.y + step * float(spec.get("embers_per_s", 1.4))
			var smokes := last.z + step * float(spec.get("smoke_per_s", 0.7))
			var high := maxf(0.0, w.y + base - q.y) * s
			for k in range(P.room(int(embers))):
				P.emit(q * s, Vector2(randf_range(-10.0, 10.0), 0.0) * s, Color(str(cols[randi() % cols.size()])), randf_range(0.6, 1.3), "ember", 2.0, high, randf_range(25.0, 50.0) * s, 2.0)
			for k in range(P.room(int(smokes))):
				P.emit((q - Vector2(0, 4)) * s, Vector2(randf_range(-4.0, 4.0), 0.0) * s, Color(smoke, 0.55), randf_range(1.0, 1.8), "smoke", 3.0, high + 4.0 * s, randf_range(12.0, 22.0) * s, 2.0)
			_wall_fire_due[key] = Vector3(now, embers - floorf(embers), smokes - floorf(smokes))


## The burning wall decor (torches, wall braziers) in `view`, every frame and behind everyone
## standing in the room, so their flames move (src/vfx/fire_anim.gd).
func _draw_wall_fires(l: CanvasItem, view: Rect2) -> void:
	_draw_launch_shadow(l)
	for w: Dictionary in W.wall_decor:
		if fire_anim.has(w.name) and view.has_point(Vector2(w.x, w.y + 74)):
			var t: Texture2D = tex[w.name]
			var sx := float(w.get("sx", 1.0))
			_tex(l, w.name, Vector2(w.x - t.get_width() * sx / 2.0, w.y), w.flip, Color.WHITE, sx, float(w.get("sy", 1.0)))


func _draw_front(l: Layer) -> void:
	for w: Dictionary in walls.south:
		if w.y - 1.0 >= l.area.position.y and w.y - 1.0 < l.area.end.y and w.x1 > l.area.position.x and w.x0 < l.area.end.x:
			_strip(l, w, l.area)


func _view_rect() -> Rect2:
	# Use the final zoom, including special rooms, and the expanded viewport.
	# Otherwise visible effects/actors can disappear at ultrawide window edges.
	var size := get_viewport().get_visible_rect().size / camera.zoom
	return Rect2(camera.position + camera.offset - size / 2.0, size)


func _draw_actors(l: Layer) -> void:
	var view := _view_rect().grow(220)
	var t: float = state.t
	FrostCombat.draw_under(self, l, t)
	# the lava floor bubbling (under everything standing on the floor)
	_draw_lava_bubbles(l)
	_draw_wall_fires(l, view)
	# the gold on the floor and in the air, under everyone standing
	gold_loot.draw(l, view)
	PerfMarks.add("da.under")
	# footprints in the snow and skid marks on the ice, under everyone (src/hero/frost_snow.gd)
	if frost_snow != null:
		frost_snow.draw_ground(l, view)
		frost_snow.draw_floor(l, view)
		frost_snow.draw_chips(l)
	if talents != null: talents.draw_world(l, t)
	# enemy weapons over the hero from in front pass behind him (src/hero/story_hero.gd guard)
	if story_hero != null:
		story_hero.guard(l)
	# Ignaroth's severed parts lie on the floor under everyone (src/hell/drake_rig_host.gd)
	if drake_rig != null:
		drake_rig.draw_under(l)
	if frost_rigs != null:
		frost_rigs.draw_under(l)
	_draw_zones(l, t)
	for e: Dictionary in W.ents:
		if not view.has_point(Vector2(e.x, e.y)):
			continue
		match e.type:
			"spikes":
				var up: bool = e.get("up", false)
				if tex.has("ice_crack"):
					_draw_ice_trap(l, e, up)
					continue
				var im: Texture2D = tex.spike_trap
				var rise := float(e.get("rise", 1.0 if up else 0.0))
				var size := im.get_size() - Vector2(0, roundf(16.0 * (1.0 - rise)))
				l.draw_texture_rect(im, Rect2(Vector2(e.x, e.y + roundf(8.0 * (1.0 - rise))) - im.get_size() / 2.0, size), false, Color(1, 1, 1, lerpf(0.3, 1.0, rise)))
			"vent":
				if tex.has("ice_crack"):
					# the Frostgruft's ice geyser: a small crack in the snow that erupts in an ice avalanche
					var hz: Dictionary = balance.hazards
					var since := fmod(float(state.t) + float(e.offset), float(hz.vent_period))
					_draw_ice_burst(l, Vector2(e.x, e.y), since if e.get("burst", false) else -1.0, 0.85)
					continue
				l.draw_texture(tex.vent, Vector2(e.x, e.y) - tex.vent.get_size() / 2.0)
			"plate":
				_draw_plate(l, e, t)
			"launch":
				var woke := LaunchPads.awake(e, W.groups)
				WorldTerrain.draw_pad(l, Vector2(e.x, e.y), str(e.dir), t, float(e.get("press", 0.0)), tex.get("rune_plate"), WorldTerrain.config().pad, bool(e.get("armed", true)) and woke)
				if woke:
					launch_pads.draw_preview(l, e, Vector2(player.x, player.y))
				else:
					# asleep: a dark, cold stone without its arc
					l.draw_rect(Rect2(e.x - 40.0, e.y - 40.0, 80.0, 80.0), Color(0.02, 0.03, 0.05, 0.55))
	frost_puzzles.draw_under(l, view, t)
	hell_puzzles.draw_under(l, view, t)
	if monsters != null:
		monsters.draw_warnings(l)
	var list: Array = []
	for p: Dictionary in W.props:
		if p.name != "" and view.has_point(Vector2(p.x, p.y)):
			list.append([p.y - (200.0 if p.low else 0.0) + float(p.get("z", 0.0)), "prop", p])
	for e: Dictionary in W.ents:
		if view.has_point(Vector2(e.x, e.y)) and e.type in ["chest", "vault", "portal", "brazier", "key", "heart", "gem", "life_heart", "relic", "well", "npc", "stairs"] and not e.get("taken", false):
			list.append([e.y - (60.0 if e.type == "stairs" else 0.0), "ent", e])
		elif e.type == "lever" and view.has_point(Vector2(e.x, e.y)):
			list.append([float(e.wy), "ent", e])
	# an opened boss gate stays as a wide arch over the doorway
	for d: Dictionary in W.doors:
		if d.get("boss_gate", false) and tex.has("boss_arch") and view.has_point(Vector2(d.cx, d.cy)) and not _door_closed(d):
			list.append([float(d.y0) * C, "arch", d])
		# a Weltbauer gate may leave a picture when open
		elif d.has("pictures") and view.has_point(Vector2(d.cx, d.cy)) and not _door_closed(d):
			var left: String = str(d.pictures.open_side if d.dir == "h" else d.pictures.open_front)
			if left != "":
				list.append([_gate_depth(d), "passage", {"name": left, "gate": d}])
	# a Weltbauer room's open passages: the hero walks under them
	for p: Dictionary in W.get("passages", []):
		if view.has_point(Vector2(p.cx, p.cy)):
			list.append([_gate_depth(p), "passage", {"name": str(p.pictures.side if p.dir == "h" else p.pictures.front), "gate": p}])
	for e: Dictionary in breakables:
		if view.has_point(Vector2(e.x, e.y)):
			list.append([e.y - (200.0 if e.get("broken", false) else 0.0), "breakable", e])
	frost_puzzles.sort_into(list, view)
	hell_puzzles.sort_into(list, view)
	if not clone.is_empty():
		list.append([clone.p.y, "clone", clone])
	for d: Dictionary in W.doors:
		# a portcullis falls shut in gate_fall s and is drawn up again in gate_rise s (physics plan
		# R21): it is drawn while it moves too; gameplay blocks at once as before
		var shut := _door_closed(d)
		var was := float(d.get("drop", 1.0 if shut else 0.0))
		var drop := move_toward(was, 1.0 if shut else 0.0, get_process_delta_time() / (0.18 if shut else 0.35))
		if drop >= 1.0 and was < 1.0 and feel != null and view.has_point(Vector2(d.cx, d.cy)):
			# it slams down: dust and grit off the floor, a jolt
			feel.feedback.particles.dust_flat(Vector2(d.cx, d.cy + 40.0) / float(feel.scale), 24.0, 14)
			feel.feedback.particles.chips(Vector2(d.cx, d.cy + 40.0) / float(feel.scale), 5, Vector2.UP, [Color("6a5e4c"), Color("3a3328")])
		d.drop = drop
		if d.kind != "secret" and view.has_point(Vector2(d.cx, d.cy)) and drop > 0.0:
			list.append([d.cy + 60.0, "gate", d])
	for m: Dictionary in mobs:
		if view.grow(300 if monsters != null else 0).has_point(m.p):
			list.append([render_mob_position(m).y, "mob", m])
	# felled monsters without a death animation fall and fade like the crypt's (src/hero/story_feel.gd)
	if feel != null:
		for m: Dictionary in feel.fallen():
			if view.has_point(m.p):
				list.append([m.p.y, "mob", m])
	if monsters != null:
		for c: Dictionary in monsters.corpses:
			if view.has_point(c.p):
				list.append([c.p.y, "corpse", c])
	list.append([render_hero_position().y, "hero", player])
	list.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	# depth bands (decision D11): the particles low over the floor are drawn between the actors by
	# their floor point, so what lies behind a monster, a pillar or the hero is hidden by it
	var bands: RefCounted = feel.feedback.particles if feel != null and depth_bands else null
	if bands != null: bands.begin_bands()
	for item: Array in list:
		if bands != null:
			l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * float(feel.scale))
			bands.draw_band(l, float(item[0]) / float(feel.scale))
			l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The shallow depression belongs behind the object. Foreground snow is fitted to the real
		# lower silhouette (baked into substantial props, drawn here only for tiny loose items).
		if frost_snow != null and item[1] in ["prop", "ent", "breakable"]:
			frost_snow.draw_foot_under(l, item[1], item[2])
		match item[1]:
			"prop":
				var p: Dictionary = item[2]
				# a Weltbauer prop may have its own pictures in turn and its own size
				var shown: String = p.name if not p.has("frames") else str(p.frames[int(t * float(p.fps) + float(p.x) * 0.013) % (p.frames as Array).size()])
				var im: Texture2D = tex[shown]
				var ps := float(p.get("scale", 1.0))
				var sx := ps * float(p.get("sx", 1.0))
				var sy := ps * float(p.get("sy", 1.0))
				_tex(l, shown, Vector2(p.x - im.get_width() * sx / 2.0, p.y - im.get_height() * sy), p.flip, Color.WHITE, sx, sy)
			"ent": _draw_ent(l, item[2], t)
			"frost": frost_puzzles.draw_piece(l, item[2], t)
			"hellp": hell_puzzles.draw_piece(l, item[2], t)
			"gate": _draw_gate(l, item[2], t)
			"passage": _draw_gate_picture(l, item[2].gate, str(item[2].name), Color.WHITE, 1.0)
			"arch":
				var arch: Texture2D = tex.boss_arch
				l.draw_texture(arch, Vector2(item[2].cx - arch.get_width() / 2.0, (item[2].y1 + 1) * C + 6 - arch.get_height()))
			"mob":
				if monsters != null:
					monsters.draw_mob(l, item[2])
				else:
					_draw_mob(l, item[2], t)
			"corpse": monsters.draw_corpse(l, item[2])
			"breakable": _draw_breakable(l, item[2], t)
			"clone": _draw_clone(l, t)
			"hero": _draw_hero(l, t)
		# Tiny loose items alone need a runtime foreground accent.
		if frost_snow != null and item[1] in ["prop", "ent", "breakable"]:
			frost_snow.draw_foot_over(l, item[1], item[2])
	if bands != null:
		l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * float(feel.scale))
		bands.draw_band(l, INF)
		l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a hero covered by an enemy in front of him keeps a thin light and dark ring (src/hero/story_hero.gd)
	if story_hero != null:
		story_hero.draw_cover(l)
	# the cuts' chips, embers and flashes over the actors
	if drake_rig != null:
		drake_rig.draw_over(l)
	if frost_rigs != null:
		frost_rigs.draw_over(l)
	# the monsters' pixel lasers in their own colours over the actors (their glow is the bloom)
	if monsters != null:
		monsters.draw_lasers(l)
	_draw_skill_fx(l, t)
	# the talents' events and auras over the actors (src/hell/hell_talents.gd)
	if talents != null: talents.draw_over(l, t)
	# the rising '+N' of gold taken and of slain enemies (src/hell/gold_loot.gd)
	gold_loot.draw_pops(l, FONT)
	RelicKit.draw(self, l, t)
	# what waits behind the doors into side rooms and the boss room (room_sign)
	_draw_room_signs(l, t)
	SubKit.draw(self, l, t)
	# effect hook: with the feel the hero's conditions are the crypt's (boss_fx.gd on the feel's layer)
	if feel == null:
		FrostCombat.draw_over(self, l, t)
	# the frost world's ice shards, hail, armour and impact flashes on the pixel grid (src/hell/frost_fx.gd)
	elif frost_fx != null:
		FrostCombat.FrostMoves.draw_over(self, l, t)
	# the mage's mark where his shot will burst (user wish 02.11.2026; src/vfx/mage_bolt.gd)
	var mark := mage_mark()
	if mark.is_finite():
		MageBolt.draw_mark(l, mark, MageBolt.element(self), t)
	for s: Dictionary in shots:
		if SubKit.draw_shot(self, l, s, t):
			continue
		# the mage's icicle and void orb on the pixel grid (src/vfx/mage_bolt.gd)
		if MageBolt.draw(l, s, t):
			continue
		# the hero's arrows and spells: the crypt's look (src/hero/story_hero.gd)
		if story_hero.handles_shot(s):
			continue
		if s.get("kind", "") == "gravity":
			var sp := sin(t * 14.0)
			l.draw_circle(s.p, 26.0, Color(0.35, 0.2, 0.8, 0.35))
			l.draw_circle(s.p, 14.0, Color(0.08, 0.02, 0.18, 0.95))
			l.draw_arc(s.p, 22.0 + sp * 3.0, t * 6.0, t * 6.0 + 4.0, 16, Color(0.75, 0.6, 1.0, 0.9), 3.0)
			continue
		if s.get("kind", "") == "rock":
			var rock: Texture2D = tex.rock_throw
			CutoutMotion.sprite(l,rock,"meteor",Rect2(Vector2(s.p)-rock.get_size(),rock.get_size()*2),t,Color.WHITE,t*8,Vector2(s.p))
			continue
		if s.get("kind", "") == "shard":
			l.draw_circle(s.p, 9.0, Color(0.75, 0.6, 1.0, 0.8))
			continue
		if s.get("kind", "") == "fireball":
			l.draw_circle(s.p, 22.0, Color(1.0, 0.45, 0.15, 0.5))
			l.draw_circle(s.p, 11.0, Color(1.0, 0.9, 0.6))
			continue
		if s.get("kind", "") == "wave":
			var wa := (s.v as Vector2).angle()
			l.draw_arc(s.p, 60.0, wa - 1.1, wa + 1.1, 18, Color(col("shot_core"), 0.85), 10.0)
			continue
		if s.get("kind", "") == "arrow" and arrow_tex != null:
			var asz := arrow_tex.get_size() * float(theme.get("weapon_scale", theme.hero_scale))
			asz *= float(s.get("big", 1.0))
			CutoutMotion.sprite(l,arrow_tex,"hail_arrow",Rect2(Vector2(s.p)-asz*0.5,asz),t,Color.WHITE,(s.v as Vector2).angle()+PI/2,Vector2(s.p))
			continue
		if MageBolt.glow(l, s):
			continue
		if s.get("kind", "") == "pyro":
			l.draw_circle(s.p, 26.0, Color(1.0, 0.45, 0.12, 0.25))
			continue
		var big := (1.5 if s.get("kind", "") == "magic" else 1.0) * float(s.get("big", 1.0))
		l.draw_circle(s.p, 16.0 * big, col("shot_glow"))
		l.draw_circle(s.p, 8.0 * big, col("shot_core"))
	# hell monster shots glow on the additive layer instead
	for s: Dictionary in (eshots if monsters == null and frost_fx == null else []):
		if FrostCombat.FrostMoves.draw_shot(l, s, t):
			continue
		var r := 30.0 if s.get("fist", false) else 15.0
		l.draw_circle(s.p, r, col("eshot_glow"))
		l.draw_circle(s.p, r * 0.47, col("eshot_core"))
	for p: Dictionary in embers:
		var c := col("ember_gold") if p.gold else (col("ember_big") if p.big else col("ember"))
		c.a = minf(1.0, p.t * 2.0)
		var s := 9.0 if p.big else 5.0
		l.draw_rect(Rect2(p.p - Vector2(s, s) / 2.0, Vector2(s, s)), c)


## Boss areas on the floor and the warning line of a coming charge.
func _draw_zones(l: Layer, t: float) -> void:
	for z: Dictionary in zones:
		# the hero's caltrops: the crypt's look (src/hero/story_skill_fx.gd)
		if story_hero.handles_zone(z):
			continue
		var k: float = 1.0 - float(z.t) / maxf(0.01, float(z.max))
		match z.kind:
			"icicle":
				l.draw_circle(z.p, float(z.r), Color(0.75, 0.9, 1.0, 0.12 + 0.3 * k))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 32, Color(0.85, 0.95, 1.0, 0.9), 3.0)
				l.draw_circle(z.p, float(z.r) * k, Color(1, 1, 1, 0.25))
			"chill":
				l.draw_circle(z.p, float(z.r), Color(0.3, 0.6, 1.0, 0.22))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 32, Color(0.5, 0.8, 1.0, 0.6), 2.0)
			"telegraph":
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 40, Color(1, 1, 1, 0.4 + 0.5 * k), 4.0)
			"caltrop":
				for i in range(7):
					var q: Vector2 = z.p + Vector2(cos(i * 2.4), sin(i * 2.4)) * float(z.r) * (0.3 + 0.1 * i)
					l.draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color(0.8, 0.85, 0.95, 0.8))
			"safe":
				l.draw_circle(z.p, float(z.r), Color(0.5, 1.0, 0.85, 0.18 + 0.12 * sin(t * 8.0)))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 40, Color(0.6, 1.0, 0.9, 0.95), 4.0)
	for m: Dictionary in mobs:
		var b: Dictionary = m.get("busy", {})
		if str(b.get("do", "")) == "charge" and float(b.e) < float(b.windup):
			var from: Vector2 = m.p - Vector2(0, 10)
			l.draw_line(from, from + (b.dir as Vector2) * float(b.speed) * float(b.time), Color(1, 0.4, 0.5, 0.35 + 0.4 * sin(t * 20.0)), 18.0)


## Skill effects in the world: whirl and blast rings, lightning, blink trails, the
## photon beam, the ballista charge, gravity walls and bars, enemy health and level-up.
func _draw_skill_fx(l: Layer, t: float) -> void:
	for f: Dictionary in fx:
		# whirl, chain lightning, blink and fire/frost bursts: the crypt's look (src/hero/story_skill_fx.gd)
		if story_hero.handles_fx(f):
			continue
		var k: float = float(f.t) / maxf(0.01, float(f.max))
		match f.kind:
			"whirl":
				l.draw_arc(f.p, float(f.r) * (1.1 - k * 0.3), 0.0, TAU, 40, Color(col("shot_core"), k), 10.0)
			"blast":
				var bc := Color(0.6, 0.4, 1.0, 0.5 * k) if f.get("gravity", false) else Color(1.0, 0.7, 0.4, 0.45 * k)
				l.draw_circle(f.p, float(f.r) * (1.2 - k * 0.4), bc)
			"bolt":
				var a: Vector2 = f.p
				var b: Vector2 = f.q
				var pts := PackedVector2Array([a])
				for i in range(1, 6):
					pts.append(a.lerp(b, i / 6.0) + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
				pts.append(b)
				l.draw_polyline(pts, Color(0.7, 0.85, 1.0, k), 4.0)
			"blink":
				l.draw_line(f.p, f.q, Color(0.6, 0.4, 1.0, 0.6 * k), 18.0)
	if story_hero.handles_hold(str(hold.get("id", ""))):
		pass # the Photoneneis and the drawn ballista: the crypt's look (src/hero/story_skill_fx.gd)
	elif str(hold.get("id", "")) == "photon":
		var s := HeroKit._skill(self, "photon")
		var me := Vector2(player.x, player.y - 40)
		var dir := Vector2(cos(float(hold.angle)), sin(float(hold.angle)))
		l.draw_line(me, me + dir * float(s.length), Color(1.0, 0.6, 0.3, 0.45), float(s.width))
		l.draw_line(me, me + dir * float(s.length), Color(0.8, 0.95, 1.0, 0.9), float(s.width) * 0.35)
	elif str(hold.get("id", "")) == "ballista":
		var share := clampf(float(hold.t) / float(HeroKit._skill(self, "ballista").charge), 0.0, 1.0)
		l.draw_arc(Vector2(player.x, player.y - 40), 60.0, -PI / 2.0, -PI / 2.0 + TAU * share, 32, Color(col("shot_core"), 0.9), 6.0)
	for w: Dictionary in gwalls:
		var wa := clampf(float(w.t) / 0.4, 0.0, 1.0)
		# gravity walls glow violet, the frost mage's ice walls pale blue
		var ice: bool = w.get("ice", false)
		l.draw_line(w.a, w.b, Color(0.55, 0.8, 1.0, 0.6 * wa) if ice else Color(0.3, 0.15, 0.7, 0.55 * wa), float(w.w))
		l.draw_line(w.a, w.b, Color(0.9, 0.97, 1.0, 0.9 * wa) if ice else Color(0.75, 0.6, 1.0, 0.9 * wa), 4.0)
		for i in range(6):
			var q: Vector2 = (w.a as Vector2).lerp(w.b, fmod(t * 0.4 + i / 6.0, 1.0))
			l.draw_circle(q, 5.0, Color(0.95, 1.0, 1.0, 0.8 * wa) if ice else Color(0.85, 0.75, 1.0, 0.8 * wa))
	for b: Dictionary in gbars:
		var ba := clampf(float(b.t) / 0.4, 0.0, 1.0)
		l.draw_line(b.a, b.b, Color(0.5, 0.85, 1.0, 0.35 * ba), float(b.w))
		l.draw_line(b.a, b.b, Color(0.85, 0.75, 1.0, 0.95 * ba), 3.0)
	if not bar_drag.is_empty():
		var cfg: Dictionary = theme.gravity_staff.bar
		var to: Vector2 = get_global_mouse_position()
		if (to - bar_drag.a).length() > float(cfg.max_length):
			to = bar_drag.a + (to - bar_drag.a).normalized() * float(cfg.max_length)
		l.draw_dashed_line(bar_drag.a, to, Color(0.85, 0.75, 1.0, 0.8), 3.0, 14.0)
	for m: Dictionary in mobs:
		# health over every hurt enemy (the guardian has its bar at the top)
		if m.kind != "boss" and m.spawn <= 0.0 and m.hp < m.max:
			var w := 64.0
			var at: Vector2 = m.p - Vector2(w / 2.0, m.cy * 2.0 + 18.0)
			l.draw_rect(Rect2(at - Vector2(2, 2), Vector2(w + 4, 10)), Color(0.02, 0.03, 0.08, 0.85))
			# tinted by the damage over time that runs on it (ui_hud_style.json mob_bar_<burn|poison|bleed>)
			var dot := HeroKit.dot_kind(m)
			l.draw_rect(Rect2(at, Vector2(w * clampf(m.hp / m.max, 0.0, 1.0), 6)), HudStyle.color("mob_bar" if dot.is_empty() else "mob_bar_" + dot))
	# with the feel the level-up is the crypt's (src/hero/story_feel.gd), not these rings
	if not levelfx.is_empty() and feel == null:
		var lt: float = levelfx.t
		var c := Vector2(player.x, player.y - 40)
		l.draw_arc(c, 40.0 + lt * 260.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.6, maxf(0.0, 1.0 - lt / 1.4)), 8.0)
		l.draw_arc(c, 20.0 + lt * 160.0, 0.0, TAU, 48, Color(col("shot_core"), maxf(0.0, 1.0 - lt / 1.0)), 5.0)


func _draw_plate(l: Layer, e: Dictionary, t: float) -> void:
	var im: Texture2D = tex.rune_plate
	var r := Rect2(Vector2(e.x, e.y) - im.get_size() / 2.0, im.get_size())
	var g: Dictionary = W.groups[e.group]
	l.draw_texture_rect(im, r, false)
	var glow := 0.0
	if e.get("on", false):
		glow = 0.55 + 0.2 * sin(t * 5.0)
	elif g.kind == "sequence" and theme.get("plate_hint", true) and not g.solved and e.room == state.room and not W.rooms[state.room].fight:
		var parts := Rules.group_progress(W.ents, e.group).y
		var cyc := fmod(t, parts * 0.75 + 1.4) / 0.75
		if int(cyc) + 1 == int(e.order):
			glow = 0.9
	if e.get("wrong", 0.0) > 0.0:
		l.draw_rect(r, Color(1, 0.12, 0.08, 0.4))
	if glow > 0.0:
		l.draw_texture_rect(im, r, false, Color(1.8, 1.2, 0.8, glow))
	else:
		l.draw_rect(r.grow(-6), Color(0, 0, 0, 0.45))


func _draw_ent(l: Layer, e: Dictionary, t: float) -> void:
	match e.type:
		"relic":
			# the staff floats over its seal; sealed it lies dark, freed it glows and turns
			var free := RelicKit.relic_free(self, e)
			if e.get("chest", false):
				# the boss's relic chest: a golden chest, the relic floating over it
				var ch: Texture2D = tex.chest_gold
				l.draw_texture(ch, Vector2(e.x - ch.get_width() / 2.0, e.y - ch.get_height()))
			if relic_tex == null:
				return
			var k := float(theme.get("weapon_scale", 2.0)) * 1.6
			var size := relic_tex.get_size() * k
			var c := Vector2(e.x, e.y - 40 + (sin(t * 2.0) * 8.0 if free else 0.0))
			l.draw_circle(Vector2(e.x, e.y), 70.0, Color(0.45, 0.3, 1.0, 0.18 + (0.12 * sin(t * 4.0) if free else 0.0)))
			l.draw_arc(Vector2(e.x, e.y), 70.0, 0.0, TAU, 40, Color(0.7, 0.55, 1.0, 0.8 if free else 0.35), 3.0)
			l.draw_set_transform(c, 0.35 + (sin(t) * 0.15 if free else 0.0))
			l.draw_texture_rect(relic_tex, Rect2(-size / 2.0, size), false, _color(theme[e.item].tint) if free else Color(0.35, 0.3, 0.5))
			l.draw_set_transform(Vector2.ZERO)
		"chest":
			var n := "chest_closed"
			if e.get("state", "") == "open":
				n = "chest_open" if e.get("magic", false) else "chest_gold"
			elif e.get("state", "") == "empty":
				n = "chest_empty"
			var im: Texture2D = tex[n]
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
		"vault":
			# a theme may name its own closed and opened vault chest (the crypt: golden, shining until opened)
			var im: Texture2D = tex.get(str(theme.get("vault_open", "chest_empty")), tex.chest_empty) if e.get("opened", false) else tex.get(str(theme.get("vault_closed", "chest_gold")), tex.chest_gold)
			var size := im.get_size() * 1.9
			if not e.get("opened", false):
				var c := Vector2(e.x, e.y - size.y * 0.55)
				for k in range(10):
					var ang := t * 0.5 + k * TAU / 10.0
					var tip := c + Vector2(cos(ang), sin(ang)) * 250.0
					var side := Vector2(-sin(ang), cos(ang)) * 30.0
					l.draw_colored_polygon(PackedVector2Array([c - side * 0.3, tip - side, tip + side, c + side * 0.3]), Color(1, 0.72, 0.22, 0.2))
				if randf() < 0.3:
					embers.append({"p": Vector2(e.x + randf_range(-70, 70), e.y - randf() * 120), "v": Vector2(0, -30), "t": 0.9, "big": false, "gold": true})
			l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y), size), false)
			if theme.has("vault_closed") and not e.get("opened", false):
				l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y), size), false, Color(1.6, 1.4, 0.8, 0.22 + 0.16 * sin(t * 4.0)))
		"well":
			var im: Texture2D = tex.fountain
			# its water flows while it holds its power (src/vfx/fire_anim.gd), a dried-up one stands still
			var at := Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height())
			if e.get("used", false):
				l.draw_texture(im, at, Color(0.45, 0.45, 0.5))
			else:
				_tex(l, "fountain", at)
			if not e.get("used", false):
				l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()), Color(1.2, 1.4, 1.8, 0.12 + 0.1 * sin(t * 3.0)))
		"npc":
			# the merchant behind the shop table: always the same figure, idle only
			var frame: Texture2D = tex.get("npc_idle_f%d" % (int(t * 6.0) % 4))
			if frame != null:
				var size := frame.get_size() * float(theme.get("hero_scale", 3.0))
				l.draw_texture_rect(frame, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y + 6), size), false)
		"stairs":
			var im: Texture2D = tex.stairs_down
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height() + 10))
		"lever":
			var im: Texture2D = tex.wall_torch_hook if e.get("lit", false) else tex.torch_dead
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.wy))
		"portal":
			var im: Texture2D = tex.portal if e.get("active", false) else tex.portal_dark
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
		"brazier":
			var im: Texture2D = tex.brazier_bowl
			if e.get("lit", false):
				_tex(l, "brazier_bowl", Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
			else:
				var cut := 46.0
				l.draw_texture_rect_region(im, Rect2(e.x - im.get_width() / 2.0, e.y - im.get_height() + cut, im.get_width(), im.get_height() - cut), Rect2(0, cut, im.get_width(), im.get_height() - cut))
		"life_heart":
			# the golden heart of the Beuteordnung: raises the life cap
			var im_life: Texture2D = tex["heart"]
			var life_size := im_life.get_size() * 0.85
			var life_bob := sin(t * 3.0 + e.x) * 6.0
			l.draw_texture_rect(im_life, Rect2(Vector2(e.x - life_size.x / 2.0, e.y - life_size.y - 10 + life_bob), life_size), false, Color(1.0, 0.82, 0.25))
		"key", "heart", "gem":
			var name: String = "rune_gem" if e.type == "gem" else (key_sprite[key_letter(e.key)] if e.type == "key" else e.type)
			var im: Texture2D = tex[name]
			var s := 0.9 if e.type == "key" else (0.55 if e.type == "gem" else 0.7)
			var bob := sin(t * 3.0 + e.x) * 6.0
			var size := im.get_size() * s
			l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y - 10 + bob), size), false, key_tint.get(e.get("key", ""), Color.WHITE))


## Where a gate sorts among the actors: whoever stands before its foot walks over it.
func _gate_depth(d: Dictionary) -> float:
	return float(d.cy) if d.dir == "h" else float(d.cy) + C * 0.5 + GATE_FOOT


## One gate picture: a side view round the doorway's middle, a front view on its foot.
func _draw_gate_picture(l: CanvasItem, d: Dictionary, name: String, tint: Color, drop: float) -> void:
	var im: Texture2D = tex.get(name)
	if im == null:
		return
	if d.dir == "h":
		l.draw_set_transform(Vector2(float(d.cx) + float(d.get("art_dx", 0.0)), d.cy))
		_draw_sliding(l, im, Rect2(-im.get_size() / 2.0, im.get_size()), tint, drop)
	else:
		var size: Vector2 = im.get_size() * float(d.get("art_scale", 1.0))
		l.draw_set_transform(Vector2(d.cx, d.cy + C * 0.5 + GATE_FOOT))
		_draw_falling(l, im, Rect2(Vector2(-size.x / 2.0, -size.y), size), tint, drop)
	l.draw_set_transform(Vector2.ZERO)


## A stone slab shuts from both ends and meets in the middle (drop 0..1, eased in).
func _draw_sliding(l: CanvasItem, im: Texture2D, rect: Rect2, tint: Color, drop: float) -> void:
	if drop >= 1.0:
		l.draw_texture_rect(im, rect, false, tint)
		return
	var part := drop * drop * 0.5
	var from := float(im.get_height()) * part
	var mid := float(im.get_height()) * 0.5
	var shown := rect.size.y * part
	var w := float(im.get_width())
	l.draw_texture_rect_region(im, Rect2(rect.position, Vector2(rect.size.x, shown)), Rect2(0.0, mid - from, w, from), tint)
	l.draw_texture_rect_region(im, Rect2(rect.position.x, rect.end.y - shown, rect.size.x, shown), Rect2(0.0, mid, w, from), tint)


## Only the part of a gate that has come down shows (it falls from the top: drop 0..1, eased in).
func _draw_falling(l: CanvasItem, im: Texture2D, rect: Rect2, tint: Color, drop: float) -> void:
	if drop >= 1.0:
		l.draw_texture_rect(im, rect, false, tint)
		return
	var part := drop * drop
	var from := float(im.get_height()) * part
	l.draw_texture_rect_region(im, Rect2(rect.position, Vector2(rect.size.x, rect.size.y * part)), Rect2(0.0, float(im.get_height()) - from, float(im.get_width()), from), tint)


## A generated floor's side gate leans away from the side with more room in its doorway.
func _side_gate_flip(d: Dictionary) -> bool:
	var left := _walkable(_cell(int(d.x0) - 1, int(d.y0)))
	var right := _walkable(_cell(int(d.x0) + 1, int(d.y0)))
	if left != right:
		return left
	return float(d.cx) > float(W.cols) * C * 0.5


func _draw_gate(l: Layer, d: Dictionary, t: float) -> void:
	if d.get("boss_gate", false) and tex.has("boss_gate"):
		# the dressed boss gate stands in the wall below the boss room, facing the hero
		var gate: Texture2D = tex.boss_gate_blue if W.n == 10 and tex.has("boss_gate_blue") else tex.boss_gate
		var bottom: float = (d.y1 + 1) * C + 8
		var fight: bool = W.rooms[d.a].fight or W.rooms[d.b].fight
		l.draw_texture(gate, Vector2(d.cx - gate.get_width() / 2.0, bottom - gate.get_height()))
		if fight:
			l.draw_texture(gate, Vector2(d.cx - gate.get_width() / 2.0, bottom - gate.get_height()), Color(1.6, 0.6, 0.5, 0.25 + 0.15 * sin(t * 5.0)))
		else:
			l.draw_texture_rect(tex[key_sprite[key_letter(d.key)]], Rect2(d.cx - 15, bottom - gate.get_height() * 0.52, 30, 56), false, key_tint[key_letter(d.key)])
		return
	var fight: bool = W.rooms[d.a].fight or W.rooms[d.b].fight
	var tint := Color.WHITE
	if fight or d.kind == "boss":
		tint = Color(1.0 + 0.4 * (0.5 + 0.5 * sin(t * 5.0)), 0.75, 0.7)
	var drop := float(d.get("drop", 1.0))
	if d.has("pictures"):
		_draw_gate_picture(l, d, str(d.pictures.side if d.dir == "h" else d.pictures.front), tint, drop)
	elif d.dir == "h" and tex.has("side_slab"):
		_draw_gate_picture(l, d, "side_slab", tint, drop)
	else:
		var im: Texture2D = tex.portcullis
		l.draw_set_transform(Vector2(d.cx, d.cy), PI / 2 if d.dir == "h" else 0.0)
		_draw_falling(l, im, Rect2(-im.get_size() / 2.0, im.get_size()), tint, drop)
		l.draw_set_transform(Vector2.ZERO)
	if not fight and d.kind == "lock":
		l.draw_texture_rect(tex[key_sprite[key_letter(d.key)]], Rect2(d.cx - 15, d.cy - 30, 30, 56), false, key_tint[key_letter(d.key)])
	elif not fight and d.kind == "puzzle":
		var icon: Texture2D = tex.brazier_bowl if W.groups[d.group].kind == "braziers" else tex.icon_scroll
		l.draw_texture_rect(icon, Rect2(d.cx - 22, d.cy - 30, 44, 44 * icon.get_height() / icon.get_width()), false)


## Room signs (proposal D2): assets/data/room_preview.json, read once (_room_signs).
var _room_signs_cfg: Dictionary = {}


## The room-sign settings (assets/data/room_preview.json).
func _room_signs() -> Dictionary:
	if _room_signs_cfg.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/room_preview.json"))
		_room_signs_cfg = data if data is Dictionary else {"order": [], "icons": {}}
	return _room_signs_cfg


## What waits in room `r` (proposal D2): the texture of its sign, "" for
## nothing; the first kind of room_preview.json order the room still holds:
## the guardian not yet beaten, the shop, a found secret room not yet
## entered, a chest or vault not emptied, a seal not broken, a fire bowl not
## lit, a heart lying there or paid by its fight. Rooms behind a secret wall
## not yet broken are never asked (known_rooms and _draw_room_signs skip them).
func room_sign(r: Dictionary) -> String:
	var cfg := _room_signs()
	var room := int(r.index)
	var held := {}
	if str(r.get("type", "")) == "boss" and not bool(r.get("cleared", false)):
		held.boss = true
	if str(r.get("gtype", "")) == "key":
		held.shop = true
	if str(r.get("type", "")) == "secret" and not state.visited.has(room):
		held.secret = true
	var reward: Variant = r.get("reward")
	if reward is Dictionary and bool(reward.get("heart", false)) and not bool(r.get("cleared", false)):
		held.heart = true
	for e: Dictionary in W.ents:
		if int(e.get("room", -1)) != room or e.get("taken", false):
			continue
		match str(e.type):
			"chest":
				if str(e.get("state", "")) != "empty": held.chest = true
			"vault":
				if not e.get("opened", false): held.chest = true
			"brazier":
				if not e.get("lit", false): held.brazier = true
			"heart":
				held.heart = true
	for e: Dictionary in breakables:
		if int(e.get("room", -1)) == room and str(e.type) == "seal" and not e.get("broken", false):
			held.seal = true
	var icons: Dictionary = cfg.get("icons", {})
	for kind: Variant in cfg.get("order", []):
		var key := str(icons.get(kind, ""))
		if held.has(str(kind)) and tex.has(key):
			return key
	return ""


## The room door `d` leads into as the hero sees it: the far side from the
## room he stands in, else the side not visited yet; -1 when both sides are
## visited or both unknown.
func _sign_side(d: Dictionary) -> int:
	var a := int(d.a)
	var b := int(d.b)
	var here := int(state.room)
	if here == a:
		return b
	if here == b:
		return a
	var seen_a: bool = state.visited.has(a)
	var seen_b: bool = state.visited.has(b)
	if seen_a == seen_b:
		return -1
	return b if seen_a else a


## Over every door in view into a side room (off the shortest way) or the
## boss room, seen from a room the hero stands in or has visited: a small
## plate with the sign of what waits there (room_sign), bobbing by whole art
## pixels; faint far from the hero, clear near him (room_preview.json door).
## Secret walls not yet broken show none.
func _draw_room_signs(l: Layer, t: float) -> void:
	var cfg: Dictionary = _room_signs().get("door", {})
	if cfg.is_empty():
		return
	var view := _view_rect().grow(120)
	var me := Vector2(player.x, player.y)
	var art := PIXEL_WORLD
	for d: Dictionary in W.doors:
		if (str(d.kind) == "secret" and not d.get("broken", false)) or not view.has_point(Vector2(d.cx, d.cy)):
			continue
		var far := _sign_side(d)
		if far < 0:
			continue
		var r: Dictionary = W.rooms[far]
		if str(r.get("type", "")) != "boss" and bool(r.get("on_path", false)):
			continue
		var key := room_sign(r)
		if key == "":
			continue
		var im: Texture2D = tex[key]
		var side := float(cfg.get("size", 33.0))
		var sz := Vector2(side, side * im.get_height() / im.get_width()) if im.get_width() >= im.get_height() else Vector2(side * im.get_width() / im.get_height(), side)
		var top := float(d.cy) - float(cfg.get("lift", 96.0))
		if d.get("boss_gate", false) and tex.has("boss_gate"):
			top = minf(top, (float(d.y1) + 1.0) * C + 8.0 - float(tex.boss_gate.get_height()) - float(cfg.get("gate_lift", 24.0)))
		# whole art pixels: the plate bobs by the grid, never between pixels
		var bob := roundf(sin(t * float(cfg.get("bob_rate", 2.2)) + float(d.cx) * 0.013) * float(cfg.get("bob", 3.0)) / art) * art
		var mid := Vector2(float(d.cx), top + bob)
		var near := clampf(1.0 - me.distance_to(Vector2(d.cx, d.cy)) / maxf(1.0, float(cfg.get("near", 700.0))), 0.0, 1.0)
		var alpha := lerpf(float(cfg.get("alpha_far", 0.55)), float(cfg.get("alpha_near", 0.95)), near)
		var half := ((Vector2(side, side) * 0.5 + Vector2.ONE * float(cfg.get("pad", 6.0))) / art).ceil() * art
		var box := Rect2(((mid - half) / art).round() * art, half * 2.0)
		# the plate: a dark fill and a thin rim with its corners cut, on the art grid, no overlaps
		var rim := Color(str(cfg.get("rim", "9c8a7e")), alpha * 0.8)
		l.draw_rect(box.grow(-art), Color(str(cfg.get("plate", "1a1012")), float(cfg.get("plate_alpha", 0.72)) * alpha))
		l.draw_rect(Rect2(box.position.x + art, box.position.y, box.size.x - art * 2.0, art), rim)
		l.draw_rect(Rect2(box.position.x + art, box.end.y - art, box.size.x - art * 2.0, art), rim)
		l.draw_rect(Rect2(box.position.x, box.position.y + art, art, box.size.y - art * 2.0), rim)
		l.draw_rect(Rect2(box.end.x - art, box.position.y + art, art, box.size.y - art * 2.0), rim)
		l.draw_texture_rect(im, Rect2((box.get_center() - sz * 0.5).round(), sz), false, Color(1, 1, 1, alpha))


func _draw_mob(l: Layer, m: Dictionary, t: float) -> void:
	if (m.look as Dictionary).has("sprite"):
		_draw_mob_sprite(l, m, t)
		return
	var im: Texture2D = tex.fire_orb
	var s: float = m.s * (1.0 - m.spawn * 1.6 if m.spawn > 0.0 else 1.0)
	if s <= 0.0:
		return
	var tint := Color.WHITE
	match m.kind:
		"gross": tint = col("mob_gross")
		"spucker": tint = col("mob_spucker")
		"boss": tint = col("mob_boss_final") if W.final else col("mob_boss")
	if m.hit > 0.0:
		tint = Color(3, 3, 3)
	var bob := sin(t * 6.0 + m.seed) * 6.0
	var size := im.get_size() * s
	var at := render_mob_position(m)
	l.draw_texture_rect(im, Rect2(at - Vector2(size.x / 2.0, size.y + 14 - bob), size), false, tint)
	if m.kind == "boss":
		var icon: Texture2D = tex.icon_demon_big if W.final else tex.icon_demon
		var k := s / 2.7
		l.draw_texture_rect(icon, Rect2(at.x - 46 * k, at.y - size.y - 4 + bob, 92 * k, 96 * k), false)


## A themed enemy: its animated skin sprite, turned towards the hero, grown in while spawning.
func _draw_mob_sprite(l: Layer, m: Dictionary, t: float) -> void:
	var look: Dictionary = m.look
	var grow: float = 1.0 - m.spawn * 1.6 if m.spawn > 0.0 else 1.0
	if grow <= 0.0:
		return
	var im: Texture2D = tex.get(MobRules.frame_name(look, int(t * float(look.get("fps", 8)) + m.seed)))
	if im == null:
		return
	# the crypt's pose (src/hero/story_feel.gd): squash, lean, hop, flash, the fall of a felled monster
	var pose: Dictionary = FrostCombat.FrostMoves.white_hit(m, feel.pose(m)) if feel != null else {}
	var size := im.get_size() * float(m.ds) * grow * (pose.get("scale", Vector2.ONE) as Vector2)
	var tint := Color(1.6, 1.8, 2.2) if m.dash > 0.0 else _color(m.get("tint", [1, 1, 1]))
	if pose.is_empty():
		tint = Color(3, 3, 3) if m.hit > 0.0 else tint
	else:
		tint.a *= float(pose.alpha)
	if float(m.get("inv", 0.0)) > 0.0:
		tint.a = 0.45 + 0.35 * sin(t * 30.0)
	var feet: Vector2 = render_mob_position(m) + (pose.get("offset", Vector2.ZERO) as Vector2)
	# glow hook (src/hero/story_glow.gd): where the body is drawn this frame, so its glowing parts follow it
	story_glow.mark(m, {"foot": feet, "size": size, "src": im.get_size(), "face": -1.0 if (m.face as Vector2).x < 0.0 else 1.0,
		"lean": float(pose.get("lean", 0.0)), "alpha": tint.a})
	# the Frostgruft's figures move as the crypt's part rigs (src/hell/frost_rigs.gd); without one the sprite stays
	if frost_rigs != null and frost_rigs.draw(l, m, feet, float(m.ds) * grow, tint, pose):
		return
	l.draw_set_transform(feet, float(pose.get("lean", 0.0)), Vector2(-1.0 if (m.face as Vector2).x < 0.0 else 1.0, 1.0))
	l.draw_texture_rect(im, Rect2(Vector2(-size.x / 2.0, -size.y), size), false, tint)
	# the crypt's hit flash: the silhouette in the flash colour (red hit, white kill)
	if float(pose.get("flash", 0.0)) > 0.0:
		l.draw_texture_rect(feel.mask(im), Rect2(Vector2(-size.x / 2.0, -size.y), size), false, StoryFeel.flash_color(pose, tint.a))
	l.draw_set_transform(Vector2.ZERO)


func _draw_breakable(l: Layer, e: Dictionary, t: float) -> void:
	if e.type == "crate":
		# urns, barrels and crates: their own sprite, gone once broken
		if e.get("broken", false):
			return
		var ci: Texture2D = tex[e.look]
		var shake_c := randf_range(-4, 4) if e.get("hit", 0.0) > 0.0 else 0.0
		l.draw_texture(ci, Vector2(e.x - ci.get_width() / 2.0 + shake_c, e.y - ci.get_height()), Color(2.2, 2.2, 2.2) if e.get("hit", 0.0) > 0.0 else Color.WHITE)
		return
	if e.get("broken", false):
		var rb: Texture2D = tex.rubble
		l.draw_texture(rb, Vector2(e.x - rb.get_width() / 2.0, e.y - rb.get_height()))
		return
	var seal: bool = e.type == "seal"
	var im: Texture2D = tex.demon_plate if seal else tex.skull_heap
	var size := im.get_size() * (1.15 if seal else 1.0)
	var shake := randf_range(-4, 4) if e.get("hit", 0.0) > 0.0 else 0.0
	var flash := Color(2.4, 2.4, 2.4) if e.get("hit", 0.0) > 0.0 else Color.WHITE
	if feel != null:
		# effect hook: a hit shakes it like the crypt's chests (skill_fx.gd draw_chest: 3 crypt px, 60 rad/s,
		# gone after 0.25 s), no white flash
		shake = StoryFeel.hit_shake(0.15 - float(e.get("hit", 0.0)), float(e.get("hit", 0.0)) > 0.0) * feel.scale
		flash = Color.WHITE
	var r := Rect2(Vector2(e.x - size.x / 2.0 + shake, e.y - size.y), size)
	l.draw_texture_rect(im, r, false, flash)
	if not seal:
		return
	l.draw_texture_rect(im, r, false, Color(1.6, 0.5, 0.3, 0.25 + 0.2 * sin(t * 4.0 + e.x)))
	var dmg: float = 1.0 - float(e.hp) / float(e.max_hp)
	if dmg > 0.0:
		var ink := Color(0.06, 0.02, 0.02, 0.9)
		l.draw_line(Vector2(e.x - 30, e.y - size.y * 0.3), Vector2(e.x - 30 + 60 * dmg, e.y - size.y * 0.3 - 20 * dmg), ink, 3.0)
		l.draw_line(Vector2(e.x + 10, e.y - size.y * 0.8), Vector2(e.x + 10 - 30 * dmg, e.y - size.y * 0.8 + 40 * dmg), ink, 3.0)


func _draw_clone(l: Layer, t: float) -> void:
	var im: Texture2D = hero_frames.run[int(t * 10.0) % 4]
	var size := im.get_size() * float(theme.hero_scale)
	var pos: Vector2 = clone.p - Vector2(0, size.y - 6)
	var tint := Color(0.45, 1.25, 1.7, 0.55 + 0.2 * sin(t * 8.0))
	if player.face < 0:
		l.draw_set_transform(pos + Vector2(size.x / 2.0, 0), 0.0, Vector2(-1, 1))
		l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false, tint)
		l.draw_set_transform(Vector2.ZERO)
	else:
		l.draw_texture_rect(im, Rect2(pos - Vector2(size.x / 2.0, 0), size), false, tint)


## A snowman (prop "snowman", the Frostgruft's mimic) wakes as the snow monster (theme mob
## "snowman"): the snowman is gone, a burst of snow, the room locks and the fight is on.
func wake_snowman(p: Dictionary) -> void:
	var at := Vector2(p.x, p.y)
	W.props.erase(p)
	_index_solids()
	var room := _room_at_world(at.x, at.y)
	if room < 0 or not theme.get("mobs", {}).has("snowman"):
		return
	var r: Dictionary = W.rooms[room]
	r.fight = true
	r.cleared = false
	_spawn_mob(room, at, "snowman")
	for i in range(24):
		frost_snow.chips.append({"p": at + Vector2(randf_range(-30, 30), randf_range(-90, -10)), "v": Vector2(randf_range(-220, 220), randf_range(-380, -120)), "t": 0.0})
	state.shake = maxf(float(state.shake), 9.0)
	if sound == null or not sound.theme_event("snowman_wake"): _sound("hit_bone")
	_toast("Der Schneemann erwacht! Die Gitter fallen.")


## The Frostgruft's trap (tex ice_crack / ice_burst): a thin crack in the ice at rest; when it fires
## an ice burst shoots up out of it (quick rise, then it stands and shimmers until it sinks back).
func _draw_ice_trap(l: Layer, e: Dictionary, up: bool) -> void:
	var period := float(balance.hazards.spike_period)
	# down it sinks back into its crack over 0.08 s (e.rise) instead of vanishing (physics plan R21)
	_draw_ice_burst(l, Vector2(e.x, e.y), fmod(float(state.t), period) if up else -1.0, 0.55, float(e.get("rise", 0.0)))


## A crack in the snow (tex ice_crack) and, `since` s after it broke open (negative: closed), the
## ice bursting up out of it (tex ice_burst): a quick rise, then it stands and shimmers. `scale`
## sizes it (the ice geysers erupt bigger than the spike traps).
func _draw_ice_burst(l: Layer, at: Vector2, since: float, scale: float, sink := 0.0) -> void:
	var crack: Texture2D = tex.ice_crack
	l.draw_texture_rect(crack, Rect2(at - crack.get_size() * scale / 2.0, crack.get_size() * scale), false)
	# closed: what still stands of it while it sinks (`sink` 1..0), else nothing
	var rise := clampf(since / 0.12, 0.0, 1.0) if since >= 0.0 else clampf(sink, 0.0, 1.0)
	if rise <= 0.0:
		return
	var burst: Texture2D = tex.ice_burst
	var size := burst.get_size() * scale * Vector2(1.0, rise)
	var shimmer := 0.85 + 0.15 * sin(float(state.t) * 18.0 + at.x)
	l.draw_texture_rect(burst, Rect2(Vector2(at.x - size.x / 2.0, at.y + 8.0 - size.y), size), false, Color(1.0, 1.0, 1.0, shimmer))


func _draw_hero(l: Layer, t: float) -> void:
	# thrown by a Sprungplatte: drawn up in the air, all of it, over his shadow on the floor
	var air: float = launch_pads.lift()
	if air > 0.0:
		player.y -= air
		_draw_hero_body(l, t)
		player.y += air
		return
	_draw_hero_body(l, t)


## The hero's shadow far below him while he flies.
func _draw_launch_shadow(l: CanvasItem) -> void:
	var air: float = launch_pads.lift()
	if air > 0.0:
		var r := clampf(30.0 - air * 0.08, 14.0, 30.0)
		l.draw_set_transform(Vector2(player.x, player.y), 0.0, Vector2(1.0, 0.45))
		l.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.42))
		l.draw_set_transform(Vector2.ZERO)


## The Weltbauer's ground of chunk (x0, y0): area brushes and pits that grow together.
func _draw_world_ground(l: Layer, x0: int, y0: int) -> void:
	var areas: Dictionary = W.get("areas", {})
	var holes: Dictionary = W.get("pit_cells", {})
	if areas.is_empty() and holes.is_empty():
		return
	var cfg := WorldTerrain.config()
	var cols: int = W.cols
	var art := float(cfg.art_px)
	var look: Dictionary = cfg.pit.get(StorySave.mode(self), cfg.pit.krypta)
	for y in range(y0, mini(y0 + CHUNK.y, W.rows)):
		for x in range(x0, mini(x0 + CHUNK.x, cols)):
			var i := y * cols + x
			var at := Vector2(x, y) * C
			if areas.has(i):
				var same := func(c: Vector2i) -> bool: return str(areas.get(c.y * cols + c.x, "")) == str(areas[i])
				WorldTerrain.draw_area(l, tex.get(str(areas[i])), Vector2i(x, y), at, C, same, cfg.area, art)
			if holes.has(i):
				var same_pit := func(c: Vector2i) -> bool: return holes.has(c.y * cols + c.x)
				WorldTerrain.draw_pit(l, Vector2i(x, y), at, C, same_pit, look, art)


func _draw_hero_body(l: Layer, t: float) -> void:
	# effect hook: with the feel the crypt's invulnerability look (45 % blink and the hit frame,
	# src/hero/story_feel.gd invulnerable_look) instead of vanishing; its conditions are boss_fx.gd's (no tint)
	var blink: Dictionary = StoryFeel.invulnerable_look(t) if feel != null and state.inv > 0.0 and state.dead <= 0.0 else {}
	if feel == null and state.inv > 0.0 and int(t * 20.0) % 2 == 1:
		return
	# subclass look: its hero and colour, the ogre of the beast form, faint while hidden
	var look := SubKit.look(self)
	if feel != null:
		look.tint.a *= float(blink.get("alpha", 1.0))
	var slide: bool = frost_snow != null and frost_snow.sliding()
	var frames: Array = look.frames["run" if player.moving and not slide else "idle"]
	var im: Texture2D = frames[int(player.anim) % 4]
	if bool(blink.get("hit", false)):
		im = feel.hit_frame(im)
	# the crypt's spring, lean and flash on the hero (src/hero/story_feel.gd)
	var pose: Dictionary = feel.hero_pose() if feel != null else {}
	var size := im.get_size() * float(theme.hero_scale) * float(look.scale) * (pose.get("scale", Vector2.ONE) as Vector2)
	# the crypt's hero look (src/hero/story_hero.gd) faces the aim; relics keep their own pose
	var shared: bool = story_hero != null and not relic_on()
	var face: float = story_hero.face(t) if shared else float(player.face)
	var body := func(feet: Vector2, alpha: float) -> void:
		var pos := Vector2(feet.x, feet.y - size.y + 6)
		var tint: Color = look.tint
		tint.a *= alpha
		var lean: float = float(pose.get("lean", 0.0)) + (float(frost_snow.slide_lean()) if frost_snow != null else 0.0)
		l.draw_set_transform(Vector2(pos.x, feet.y + 6.0), lean, Vector2(-1.0 if face < 0 else 1.0, 1.0))
		l.draw_texture_rect(im, Rect2(Vector2(-size.x / 2.0, -size.y), size), false, tint)
		if float(pose.get("flash", 0.0)) > 0.0:
			l.draw_texture_rect(feel.mask(im), Rect2(Vector2(-size.x / 2.0, -size.y), size), false, StoryFeel.flash_color(pose, tint.a))
		l.draw_set_transform(Vector2.ZERO)
	if shared:
		# the class figure as the crypt's part rig (src/hero/story_hero.gd), else this frame
		story_hero.draw_hero(l, t, size.y * 0.45, body, look)
		return
	body.call(render_hero_position(), 1.0)
	_draw_weapon(l, size)


## The hero once more at `feet`, facing the other way, at `alpha` and tinted `tint`: the Frostgruft's
## mirror ghost (src/world_kit/frost_puzzles.gd) wears the figure of whoever plays, his class, his
## subclass form and his element's colours. False when nothing could be drawn.
func draw_mirror_hero(l: CanvasItem, feet: Vector2, t: float, alpha: float, tint: Color) -> bool:
	var look := SubKit.look(self)
	if story_hero != null and not relic_on() and story_hero.draw_mirror(l, feet, -float(story_hero.face(t)), alpha, look, tint):
		return true
	var frames: Array = (look.get("frames", {}) as Dictionary).get("run" if player.moving else "idle", [])
	if frames.is_empty():
		return false
	var im: Texture2D = frames[int(player.anim) % frames.size()]
	var size := im.get_size() * float(theme.hero_scale) * float(look.scale)
	var own: Color = look.tint
	l.draw_set_transform(Vector2(feet.x, feet.y + 6.0), 0.0, Vector2(1.0 if float(player.face) < 0 else -1.0, 1.0))
	l.draw_texture_rect(im, Rect2(Vector2(-size.x / 2.0, -size.y), size), false, Color(own.r * tint.r, own.g * tint.g, own.b * tint.b, own.a * alpha))
	l.draw_set_transform(Vector2.ZERO)
	return true


## The class weapon in the hero's hand: bow and staff held upright, the sword
## swept through its arc while a swing lasts; the gravity staff glows violet.
func _draw_weapon(l: Layer, hero_size: Vector2) -> void:
	var feet := render_hero_position()
	if relic_on() and relic_tex != null:
		var rel := RelicKit.wielded(self)
		var rk := float(theme.get("weapon_scale", 2.0))
		var rsz := relic_tex.get_size() * rk
		var rhand := Vector2(feet.x + float(player.face) * hero_size.x * 0.32, feet.y - hero_size.y * 0.38)
		var tilt := 0.0
		if rel.has("attack") and swing.t > 0.0:
			# the hammer comes down through its arc
			tilt = float(swing.a) + PI / 2.0 + float(rel.attack.arc) * (0.5 - swing.t / 0.22)
			l.draw_set_transform(Vector2(feet.x, feet.y - 40), tilt)
			l.draw_texture_rect(relic_tex, Rect2(Vector2(-rsz.x / 2.0, -rsz.y - 10.0), rsz), false, _color(rel.tint))
			l.draw_set_transform(Vector2.ZERO)
			return
		l.draw_set_transform(rhand, 0.0, Vector2(float(player.face), 1))
		l.draw_texture_rect(relic_tex, Rect2(Vector2(-rsz.x / 2.0, -rsz.y * 0.7), rsz), false, _color(rel.tint))
		l.draw_set_transform(Vector2.ZERO)
		return
	if weapon_tex == null:
		return
	var k := float(theme.get("weapon_scale", theme.hero_scale))
	var wsz := weapon_tex.get_size() * k
	var hand := Vector2(feet.x + float(player.face) * hero_size.x * 0.32, feet.y - hero_size.y * 0.38)
	if weapon.type == "melee" and swing.t > 0.0:
		var a: float = swing.a + float(weapon.arc) * (0.5 - swing.t / 0.16)
		var tip := Vector2(cos(a), sin(a))
		l.draw_line(Vector2(feet.x, feet.y - 40) + tip * 30.0, Vector2(feet.x, feet.y - 40) + tip * float(weapon.reach), Color(col("shot_core"), 0.5), 6.0)
		l.draw_set_transform(Vector2(feet.x, feet.y - 40), a + PI / 2.0)
		l.draw_texture_rect(weapon_tex, Rect2(Vector2(-wsz.x / 2.0, -wsz.y - 12.0), wsz), false)
		l.draw_set_transform(Vector2.ZERO)
		return
	var tilt := 0.35 * float(player.face) if weapon.type == "melee" else 0.0
	l.draw_set_transform(hand, tilt, Vector2(float(player.face), 1))
	l.draw_texture_rect(weapon_tex, Rect2(Vector2(-wsz.x / 2.0, -wsz.y * 0.7), wsz), false)
	l.draw_set_transform(Vector2.ZERO)


# ---------- HUD ----------

## Draws the HUD into the screen-space control.
func draw_hud(h: Control) -> void:
	# what several panels read is worked out once in this drawing (talents hud_state, run points),
	# only while it draws
	_hud_open = true
	_hud_run_points = -1
	if talents != null:
		talents.hud_begin()
	_draw_hud(h)
	_hud_open = false
	if talents != null:
		talents.hud_end()


func _draw_hud(h: Control) -> void:
	var size := h.size
	var th: Dictionary = W.theme
	if float(th.grade) > 0.0:
		var grade := col("grade")
		grade.a = float(th.grade) * 0.45
		h.draw_rect(Rect2(Vector2.ZERO, size), grade)
	var vig := col("vignette") + col("vignette_glow") * float(th.wall_glow)
	vig.a = float(th.vignette)
	h.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, vig)
	if state.flash > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.08, 0.08, state.flash))
	if state.white > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.925, 0.82, minf(1.0, state.white)))
	# blindness darkens the view around the hero, under the HUD panels
	FrostCombat.draw_hud(self, h, size)
	# a labyrinth: dark beyond what the hero sees, walls stop the view
	if maze_dark > 0.0:
		_draw_maze_dark(h, size)
	# from outside a labyrinth stays dark: its corridors are found inside, never read from the door
	if maze_dark < 1.0:
		_draw_maze_cover(h, size)
	# the room's weather of the Weltbauer (src/world_kit/room_weather.gd), then what the hero carries
	room_weather.draw(h, size, self)
	frost_puzzles.draw_hud(h, size)
	hell_puzzles.draw_hud(h, size)
	# the life shown, for the status sheet too (src/hell/frost_hud.gd reads state.hp_f)
	state.hp_f = hp_f()
	_windows = _window_open()
	_result_rect = Rect2()
	_result_label = ""
	# the big map (M) is a window of its own: no HUD panels, chips or toasts under it
	if state.map:
		_draw_map(h, size, true)
		FrostHud.track(self)
		_draw_result(h, size)
		return
	var left_edge := _draw_hero_strip(h)
	# no help line at the bottom: controls and goals live in the pause menu (Esc)
	if heroic():
		_draw_skill_bar(h, size)
	var boss_mob: Dictionary = {}
	for m: Dictionary in mobs:
		if m.kind == "boss":
			boss_mob = m
	# the room banner (new rooms and floors only) sits below the guardian's bar while it stands
	FrostHud.banner(self, h, size, 96.0 if boss_mob.is_empty() else 112.0)
	if not boss_mob.is_empty():
		_draw_boss_bar(h, size, boss_mob, left_edge)
	_draw_floor_panel(h, size, not boss_mob.is_empty())
	# element reactions: their pixel sign and name over the reaction point (src/hell/story_elements.gd)
	if story_elements != null and not _windows:
		story_elements.draw_hud(h, size, FONT)
	# chips, prompt and the toast only while no window and no result panel covers the HUD
	var result_up: bool = state.won or not (state.get("over", {}) as Dictionary).is_empty() or not stairs_pick.is_empty() or CardKit.seal_open(self)
	if not _windows and not result_up:
		var chip_hot := HudKit.menu_rect(size).has_point(h.get_local_mouse_position())
		HudKit.menu_chip(h, FONT, size, "ESC · MENÜ", 1.0 if chip_hot else HudKit.rule("menu_chip_alpha", 0.5), chip_hot)
		if talents != null:
			var points := _talent_points()
			var talent_hot := HudKit.talent_rect(size).has_point(h.get_local_mouse_position())
			HudKit.talent_chip(h, FONT, size, points.x + points.y, HudKit.rule("menu_chip_alpha", 0.5), talent_hot, float(state.t))
		var n := _nearest()
		if not n.is_empty() and state.dead <= 0.0 and not state.won:
			HudKit.prompt(h, FONT, _to_screen(n.p, size) - Vector2(0, 70), "E", say(n.label), size)
		elif state.dead <= 0.0:
			# a demon seal near the hero says before the first blow what it offers and costs (D1)
			FrostHud.seal_hint(self, h, size)
		# an Inschrift near the hero is read out above him while he stays (a puzzle's riddle)
		var words := inscription()
		if words != "" and state.dead <= 0.0:
			HudKit.inscription(h, FONT, size, "INSCHRIFT", words)
		_draw_toast(h, size)
	if theme.placeholder_note:
		_text(h, "Figur: Platzhalter" if monsters != null else "Figur und Gegner: Platzhalter", Vector2(20, size.y - 14), 16, Color(ink, 0.45))
	if state.dead > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0, 0, 0.55))
	# the goal list sits in the pause menu now; finished goals still ring and show a note
	FrostHud.track(self)
	# the run talent tree window (B), the same in every world; the world waits while it is open
	if state.get("tree_open", false) and heroic():
		RunTreeView.draw(h, FONT, size, CardKit.tree(self), CardKit.ranks(self), int(state.level), {"title": str(hero.get("name", class_id)), "mouse": h.get_local_mouse_position()})
	# a broken seal's two blessings and their price; the world waits (balance package D1)
	FrostHud.seal_cards(self, h, size)
	_draw_result(h, size)


## The hero strip top left, the same in every world (src/ui/hud_kit.gd): the
## name and LP (no "P1 ·": the story worlds are solo), the life bar with the
## Stufe beside it, the EXP line, the resource row (a key only once found, rune
## stones, braziers; it fades after a quiet while and comes back with the next
## change), clone, blessings, conditions; the companion bar under it (stepped
## back while it needs nothing). Returns the right edge of both.
func _draw_hero_strip(h: Control) -> float:
	var resources: Array = []
	for k in ["A", "B", "C"]:
		if state.keys[k]:
			resources.append({"icon": tex[key_sprite[k]], "tint": key_tint[k]})
	var fire := Rules.group_progress(W.ents, "feuer")
	if fire.y > 0:
		resources.append({"icon": tex.brazier_bowl, "text": "%d/%d" % [fire.x, fire.y], "dim": fire.x >= fire.y})
	# gold and rune stones join the row that fades: shown when they change, always in the character window (C)
	resources.append({"icon": gold_loot.coin(float(state.t)), "text": str(gold_count()), "ink": Color(1.0, 0.84, 0.3)})
	resources.append({"icon": gold_loot.rune(), "text": str(rune_count()), "ink": Color(0.62, 0.86, 1.0)})
	var sig := "%s%s%s|%d|%d|%d" % [state.keys["A"], state.keys["B"], state.keys["C"], fire.x, gold_count(), rune_count()]
	if str(state.get("res_sig", "")) != sig:
		state.res_sig = sig
		state.res_t = float(state.t)
	var quiet := float(state.t) - float(state.res_t) - HudKit.rule("resource_hold", 4.0)
	var res_alpha := 1.0 - clampf(quiet / maxf(0.05, HudKit.rule("resource_fade", 0.5)), 0.0, 1.0)
	# the hero's conditions (poison, slow, sealed skills ...) first, each in its colour: this row is
	# the only place that names them, so they never give way (HudKit._status_row drops from the end)
	var status: Array = FrostCombat.status_lines(self)
	var sk: Dictionary = state.skill
	if sk.owned:
		var clock := "%d:%02d" % [int(sk.left) / 60, int(sk.left) % 60]
		var label := ("KLON AKTIV · " + clock) if sk.active else (("Q · KLON RUFEN · " + clock) if sk.left > 0.0 else "KLON AUFGEBRAUCHT")
		status.append({"text": label, "color": HudStyle.color("accent") if sk.active else (HudStyle.color("text_dim") if sk.left > 0.0 else HudStyle.color("text_muted"))})
	if not (state.buffs as Array).is_empty():
		var names: Array = (state.buffs as Array).map(func(b: String) -> String: return b.get_slice(":", 0))
		# the blessings last, with a short form for a crowded row
		status.append({"text": "SEGEN · " + ", ".join(PackedStringArray(names)).to_upper(), "short": "SEGEN ×%d" % names.size(), "color": HudStyle.color("text_dim")})
	var leveled := heroic()
	var need := maxf(1.0, float(HeroKit.need(theme.leveling, int(state.level)))) if leveled else 1.0
	var margin := HudStyle.size("margin")
	var hero_rect := HudKit.hero_panel(h, FONT, Vector2(margin, margin), {"title": str(hero.get("name", class_id)).to_upper(),
		"level_label": "STUFE", "hp_unit": "LP", "fixed_rows": true, "compact": true,
		"points": _run_points_left() if leveled else 0,
		"hp": int(state.hp), "hp_f": float(state.hp_f), "max_hp": int(state.max_hp), "hearts": hearts, "level": int(state.level) if leveled else -1,
		"exp": float(state.exp) / need if leveled else -1.0, "resources": resources, "resource_alpha": res_alpha, "status": status,
		"low": int(state.hp) <= 2 and int(state.hp) > 0, "clock": float(state.t)})
	var edge := hero_rect.end.x
	# the purse rides in the strip's fading resource row (no panel of its own)
	var bottom := hero_rect.end.y
	if talents != null:
		var pet: Dictionary = talents.hud_state().get("pet", {})
		var pet_rect := HudKit.pet_panel(h, FONT, Vector2(hero_rect.position.x, hero_rect.end.y + 6.0), hero_rect.size.x, pet, float(state.t),
			HudKit.rule("pet_idle_alpha", 0.6) if _pet_idle(pet) else 1.0)
		edge = maxf(edge, pet_rect.end.x)
		bottom = maxf(bottom, pet_rect.end.y)
	# the inventory window opens below this column, never over it (src/ui/inventory_panel.gd fit_below)
	if inventory_panel != null:
		inventory_panel.fit_below(bottom + HudStyle.size("inventory_gap"))
	return edge


## The purse under the hero panel, always shown in every world: the turning coin with the
## character's gold (lost when it dies) and the rune stone with the account's stones (they pay
## the talent reset). Returns its rect.
func _draw_purse(h: Control, origin: Vector2, width: float) -> Rect2:
	var pad := HudStyle.size("pad")
	var body := int(HudStyle.size("font_body"))
	var rect := Rect2(origin, Vector2(width, body + pad * 2.0))
	HudStyle.panel(h, rect)
	var y := rect.get_center().y
	var x := rect.position.x + pad
	for item: Array in [[gold_loot.coin(float(state.t)), str(gold_count()), Color(1.0, 0.84, 0.3)], [gold_loot.rune(), str(rune_count()), Color(0.62, 0.86, 1.0)]]:
		var icon: Texture2D = item[0]
		if icon != null:
			var s := float(body + 2) / maxf(1.0, icon.get_size().y)
			var size := icon.get_size() * s
			h.draw_texture_rect(icon, Rect2(Vector2(x, y - size.y / 2.0), size), false)
			x += size.x + 6.0
		HudStyle.text(h, FONT, Vector2(x, y + floorf(body * 0.5) - 1.0), str(item[1]), body, item[2])
		x += HudStyle.width(FONT, str(item[1]), body) + 22.0
	return rect


## The guardian's bar, the same in every world (src/ui/hud_kit.gd), between the
## hero strip (`left`) and the floor panel; no "WÄCHTER DER ETAGE" while the
## room banner still names the place.
func _draw_boss_bar(h: Control, size: Vector2, boss_mob: Dictionary, left: float) -> void:
	var bars: int = boss_mob.phase_hp.size() if boss_mob.has("kit") else 1
	var phase_i: int = int(boss_mob.phase) if boss_mob.has("kit") else 0
	var segments: Array = []
	for i in range(bars):
		# spent bars empty, the current one draining, later ones full
		segments.append(0.0 if i < phase_i else (1.0 if i > phase_i else clampf(boss_mob.hp / boss_mob.max, 0.0, 1.0)))
	var pname := str(BossKit.phase(boss_mob).get("name", "")) if boss_mob.has("kit") else ""
	var title: String = str(W.boss.name) + (" · " + pname if pname != "" else "")
	if monsters != null:
		title = monsters.boss_label(boss_mob)
	var total := 0.0
	var left_hp := maxf(0.0, boss_mob.hp)
	if boss_mob.has("kit"):
		for i in range(bars):
			total += float(boss_mob.phase_hp[i])
			if i > phase_i:
				left_hp += float(boss_mob.phase_hp[i])
	else:
		total = boss_mob.max
	HudKit.boss_bar(h, FONT, size, {"name": title.to_upper(), "tag": "" if FrostHud.banner_up(self) else "WÄCHTER DER ETAGE", "segments": segments,
		"ratio": clampf(left_hp / maxf(1.0, total), 0.0, 1.0), "flash": 1.0 if float(boss_mob.get("inv", 0.0)) > 0.0 else 0.0,
		"value": "%d %%" % int(ceil(left_hp / maxf(1.0, total) * 100.0)), "left": left, "right": HudKit.floor_rect(size).position.x})


## The floor panel top right: the floor, one line (the place, or "VERRIEGELT ·
## n" in red while a fight holds the gates), the mini-map; it steps back
## outside fights.
func _draw_floor_panel(h: Control, size: Vector2, boss_up: bool) -> void:
	var cr: Dictionary = W.rooms[state.room]
	var locked := 0
	if cr.fight:
		for m: Dictionary in mobs:
			if m.room == cr.index:
				locked += 1
	# no mini-map in the corner (ui_hud_style.json story_minimap): only a locked room says so, as a chip
	# under the menu chips; the map itself is on M and in the pause
	if not HudKit.map_corner:
		if cr.fight and not boss_up:
			var under := HudKit.talent_rect(size) if talents != null else HudKit.menu_rect(size)
			var chip := Rect2(under.position.x, under.end.y + 4.0, under.size.x, under.size.y)
			HudStyle.panel(h, chip)
			HudStyle.text(h, FONT, Vector2(chip.get_center().x, chip.get_center().y + 5.0), "VERRIEGELT · %d" % locked, int(HudStyle.size("font_small")), HudStyle.color("danger"), 1)
		return
	var map_area := HudKit.floor_panel(h, FONT, size, {"title": "ETAGE %d" % int(state.floor), "subtitle": str(W.title).to_upper(),
		"tag": ("VERRIEGELT · %d" % locked) if cr.fight else "", "tag_color": HudStyle.color("danger")})
	_draw_map(h, size, false, false, map_area)
	if not cr.fight and not boss_up:
		HudKit.dim(h, HudKit.floor_rect(size), HudKit.rule("floor_calm_alpha", 0.7))


## The one toast on screen: bottom left above the skill bar's row, clear of the
## hero and the resource bar, fading in and out.
## The labyrinth's dark (maze_dark): from the hero rays run over the floor until a wall stops them
## (or sight_cells); beyond the rays everything is black, and towards their end the light fades out.
## Walls hide the corridors behind them, so the hero sees only the way he stands in.
func _draw_maze_dark(h: Control, size: Vector2) -> void:
	var cfg := maze_cfg()
	var eye := Vector2(player.x, player.y - 30.0)
	var reach := float(cfg.get("sight_cells", 4.2)) * C
	var soft := float(cfg.get("soft_from", 0.5))
	var rays := int(cfg.get("rays", 180))
	var black := Color(0.0, 0.0, 0.0, float(cfg.get("dark", 0.96)) * maze_dark)
	var clear := Color(black, 0.0)
	var far_px := size.length()
	var near_pts: Array[Vector2] = []
	var hit_pts: Array[Vector2] = []
	var far_pts: Array[Vector2] = []
	var centre := _to_screen(eye, size)
	for k in range(rays + 1):
		var dir := Vector2.from_angle(TAU * float(k) / float(rays))
		var d := 0.0
		while d < reach:
			var p := eye + dir * d
			if _cell(int(floor(p.x / C)), int(floor(p.y / C))) == 0:
				# a wall: its face is still seen
				d = minf(d + 40.0, reach)
				break
			d += 12.0
		var hit := _to_screen(eye + dir * minf(d, reach), size)
		hit_pts.append(hit)
		near_pts.append(centre + (hit - centre) * soft)
		far_pts.append(centre + dir * far_px)
	for k in range(rays):
		h.draw_polygon(PackedVector2Array([hit_pts[k], hit_pts[k + 1], far_pts[k + 1], far_pts[k]]), PackedColorArray([black, black, black, black]))
		h.draw_polygon(PackedVector2Array([near_pts[k], near_pts[k + 1], hit_pts[k + 1], hit_pts[k]]), PackedColorArray([clear, clear, black, black]))


## How dark a labyrinth zone is seen from outside it now: the unseen's dark while the
## hero is out, fading to 0 as he steps in (maze_dark rises).
func maze_cover_alpha() -> float:
	var cfg := maze_cfg()
	return float(cfg.get("dark", 0.96)) * float(cfg.get("outside_cover", 1.0)) * (1.0 - maze_dark)


## Every labyrinth zone on screen, seen from outside it, as dark as the unseen inside
## (world_maze.json dark, outside_cover): its corridors and inner walls cannot be read
## through the door or across the room. The cover fades while the hero steps in and the
## ray light of _draw_maze_dark takes over (maze_dark), so nothing is lit twice.
func _draw_maze_cover(h: Control, size: Vector2) -> void:
	var cfg := maze_cfg()
	var alpha := maze_cover_alpha()
	if alpha <= 0.0:
		return
	var black := Color(0.0, 0.0, 0.0, alpha)
	var view := _view_rect()
	# a wall's face stands up into the row above it; the top row covers that much too
	var lift := float(cfg.get("cover_lift_cells", 0.5)) * C
	for r: Dictionary in W.rooms:
		var zone: Array = r.get("maze_zone", [])
		if zone.is_empty():
			continue
		var top := INF
		for run: Array in zone:
			top = minf(top, float(run[1]))
		for run: Array in zone:
			var rect := Rect2(float(run[0]) * C, float(run[1]) * C, (float(run[2]) - float(run[0]) + 1.0) * C, C)
			if is_equal_approx(float(run[1]), top):
				rect = rect.grow_side(SIDE_TOP, lift)
			if not rect.intersects(view):
				continue
			var a := _to_screen(rect.position, size)
			var b := _to_screen(rect.end, size)
			# whole screen pixels and a 1 px overlap: no seams between the rows
			h.draw_rect(Rect2(a.floor(), (b - a).ceil() + Vector2(0.0, 1.0)), black)


func _draw_toast(h: Control, size: Vector2) -> void:
	var queue: Array = state.toasts
	if queue.is_empty():
		return
	var tt: Dictionary = queue[0]
	var a := clampf(float(tt.get("age", 0.0)) / maxf(0.01, HudKit.rule("toast_in", 0.12)), 0.0, 1.0) \
		* clampf(float(tt.t) / maxf(0.05, HudKit.rule("toast_fade", 0.25)), 0.0, 1.0)
	var bottom := (SkillBar.top(size, false) - 34.0) if heroic() else size.y - 24.0
	HudKit.toast_at(h, FONT, Vector2(HudStyle.size("margin"), bottom), str(tt.text), a, HudKit.rule("toast_max_width", 620.0))


## Floor won, run over, the hidden stairs: the result panel every world shares
## (src/ui/hud_kit.gd). The first two get real buttons (_sync_overlays); E and
## Esc work as before.
func _draw_result(h: Control, size: Vector2) -> void:
	var over: Dictionary = state.get("over", {})
	if not over.is_empty():
		var data := run_result(over)
		data["buttons"] = 2
		_result_rect = HudKit.result_panel(h, FONT, size, data)
		_result_label = "NEUER LAUF  (E)"
	elif state.won:
		_result_rect = HudKit.result_panel(h, FONT, size, {"title": "ETAGE %d GESCHAFFT" % int(state.floor), "tone": "floor", "buttons": 2,
			"lines": [["RÄUME ERKUNDET", "%d / %d" % [state.visited.size(), W.rooms.size()]], ["GOLD", str(gold_count())], ["RUNENSTEINE", str(rune_count())],
				["LP", "%d / %d" % [HudKit.life_shown(int(state.hp), float(state.hp_f)), int(state.max_hp)]], ["LAUFSTUFE", str(int(state.level))]],
			"note": _floor_reward})
		_result_label = "WEITER  (E)"
	elif not stairs_pick.is_empty():
		# the hidden stairs: every earlier floor, in a new world
		var lines: Array = []
		for fn: int in stairs_pick.floors:
			lines.append(["TASTE %d" % fn, "ETAGE %d · %s" % [fn, str(world.pack.floors[fn].title).to_upper() if world != null else ""]])
		HudKit.result_panel(h, FONT, size, {"title": "VERGESSENE STIEGE", "tone": "floor", "lines": lines,
			"note": "Die Welt wird neu gewürfelt. LP, Laufstufe und Gegenstände bleiben.", "hints": "1-%d · ETAGE WÄHLEN   E · BLEIBEN" % (stairs_pick.floors as Array).size()})


## The skill bar at the bottom: one slot per key with icon, key, cooldown shade
## and the level it opens at, in the slim bar every world shares (src/ui/skill_bar.gd);
## with the gravity staff the slots show the staff's three abilities instead.
func _draw_skill_bar(h: Control, size: Vector2) -> void:
	if not (state.get("offer", []) as Array).is_empty():
		FrostHud.cards(self, h, size)
	# the slim bar shared with the crypt (src/ui/skill_bar.gd), with the crypt's skill icons
	var slots: Array = []
	var none := Color(0, 0, 0, 0)
	if relic_on():
		var rel := RelicKit.wielded(self)
		var atk: Dictionary = rel.get("ball", rel.get("attack", {}))
		slots = [{"key": "LMB", "name": atk.get("short", atk.get("name", "")), "cd": float(state.cool), "max": float(atk.get("cooldown", 1.0)), "icon": relic_tex}]
		for s: Dictionary in rel.skills:
			slots.append({"key": str(s.key), "name": str(s.short), "cd": float(state.skill_cd.get(str(s.id), 0.0)), "max": float(s.cooldown),
				"locked": int(state.level) < int(s.unlock), "unlock": int(s.unlock), "icon": relic_tex})
	elif talents != null:
		slots = talents.skill_slots()
		# F: the worn armour's ability, right of SH (src/hero/story_items.gd power_slots)
		if story_items != null:
			slots.append_array(story_items.power_slots())
	else:
		var held := str(hold.get("id", ""))
		for s: Dictionary in skills:
			var id := str(s.id)
			var running := (id == "rage" and float(state.get("rage", 0.0)) > 0.0) or (id == held)
			slots.append({"key": str(s.key), "name": str(s.get("short", s.name)), "cd": float(state.skill_cd.get(str(s.key), 0.0)), "max": float(s.cooldown),
				"locked": not HeroKit.unlocked(self, s), "unlock": int(s.unlock), "icon": SkillIcons.for_id(class_id, id),
				"active": (HudStyle.color("danger") if id in ["rage", "photon"] else HudStyle.color("accent")) if running else none,
				"charge": clampf(float(hold.get("t", 0.0)) / maxf(0.1, float(s.get("charge", 1.0))), 0.0, 1.0) if id == "ballista" and held == id else -1.0,
				"ultimate": int(s.unlock) >= 10})
	var master := str(state.get("talent", {}).get("master", ""))
	if master != "":
		var mname := master
		for t: Array in meta_data.classes[class_id].subs[state.talent.sub].tiers:
			for n: Dictionary in t:
				if str(n.get("master", "")) == master:
					mname = str(n.name)
		slots.append({"key": "5", "name": mname, "cd": float(state.skill_cd.get("5", 0.0)), "max": float(theme.get("master_cooldown", 45.0)),
			"icon": SkillIcons.for_id(class_id, master), "ultimate": true})
	# H / G: the quick potion, its own group after the skills (src/hero/story_items.gd quick_slots)
	if story_items != null and heroic():
		slots.append_array(story_items.quick_slots())
	# level and EXP sit with the hearts at the top (draw_hud), as in every world
	SkillBar.draw(h, FONT, size, slots, float(state.t), {"mouse": h.get_local_mouse_position()})
	# the resource line above the skill bar (talents on 1-4 and R), the same in every map
	if talents != null: talents.draw_hud(h, size, SkillBar.top(size, false) - 14.0)



func _text(h: CanvasItem, text: String, pos: Vector2, font_size: int, color: Color, center_width := -1.0) -> void:
	if center_width > 0.0:
		h.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, center_width, font_size, color)
	else:
		h.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _to_screen(world: Vector2, screen: Vector2) -> Vector2:
	# the camera's offset (shake, kick, the skill bar's view shift) is in world px
	return (world - camera.position - camera.offset) * camera.zoom + screen / 2.0


func _door_color(d: Dictionary) -> Color:
	if W.rooms[d.a].fight or W.rooms[d.b].fight:
		return Color("#d8382a")
	if d.kind == "lock" and not d.unlocked:
		# a room's own key ("15A", room_floor.gd own_key) takes the colour of its letter
		return key_color[key_letter(d.key)]
	if d.kind == "puzzle" and _door_closed(d):
		return Color("#f2c14e")
	if d.kind == "boss" and _door_closed(d):
		return Color("#d8382a")
	return col("door")


## The minimap, or the big map over the screen (M). `framed`: the big map inside
## another frame (the pause menu's map page), without backdrop, title and legend.
func _draw_map(h: Control, screen: Vector2, big: bool, framed := false, area := Rect2()) -> void:
	var known := Rules.known_rooms(W.doors, state.visited)
	var pad := Vector2(16, 16) if framed else Vector2(60, 110)
	var s: float = minf((screen.x - pad.x) / W.cols, (screen.y - pad.y) / W.rows) if big else minf(250.0 / W.cols, 170.0 / W.rows)
	var mw: float = W.cols * s
	var mh: float = W.rows * s
	var origin := Vector2((screen.x - mw) / 2.0, (screen.y - mh) / 2.0 + (0.0 if framed else 10.0)) if big else Vector2(screen.x - mw - 16.0, 16.0)
	var in_panel := not big and area.size.x > 0.0
	if in_panel:
		# the small map fills the floor panel's map area (src/ui/hud_kit.gd)
		s = minf(area.size.x / W.cols, area.size.y / W.rows)
		mw = W.cols * s
		mh = W.rows * s
		origin = area.position + (area.size - Vector2(mw, mh)) / 2.0
	if big and not framed:
		h.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.03, 0.01, 0.02, 0.93))
		_text(h, "%s · Etage %d" % [W.title, state.floor], Vector2(0, 40), 32, gold, screen.x)
	elif not big and not in_panel:
		h.draw_rect(Rect2(origin - Vector2(8, 8), Vector2(mw, mh) + Vector2(16, 16)), Color(0.04, 0.02, 0.02, 0.8))
	h.draw_set_transform(origin, 0.0, Vector2(s, s))
	for d: Dictionary in W.doors:
		if not (known.has(d.a) and known.has(d.b)) or (d.kind == "secret" and not d.broken):
			continue
		var hx := 0.5 if d.dir == "h" else 0.0
		var vy := 0.5 if d.dir == "v" else 0.0
		h.draw_rect(Rect2(d.x0 - hx, d.y0 - vy, d.x1 - d.x0 + 1 + hx * 2, d.y1 - d.y0 + 1 + vy * 2), _door_color(d))
		for c: Array in d.get("corridor", []):
			h.draw_rect(Rect2(float(c[0]), float(c[1]), 1.0, 1.0), col("map_seen"))
	for r: Dictionary in W.rooms:
		if not known.has(r.index):
			continue
		var seen: bool = state.visited.has(r.index)
		var here: bool = r.index == state.room
		var fill := col("map_here") if here else (col("map_cleared") if seen and r.cleared else (col("map_seen") if seen else Color(0.18, 0.11, 0.13, 0.45)))
		for rect: Rect2 in minimap[r.index].rects:
			h.draw_rect(rect, fill)
		h.draw_multiline(minimap[r.index].edges, accent if here else (col("map_edge_seen") if seen else col("map_edge")), (2.4 if here else 1.2) / s)
	h.draw_set_transform(Vector2.ZERO)
	var isz := maxf(24.0, s * 4.5) if big else 13.0
	for r: Dictionary in W.rooms:
		if not known.has(r.index):
			continue
		var seen: bool = state.visited.has(r.index)
		var icon: String = r.icon
		if icon == "" and seen:
			for e: Dictionary in W.ents:
				if e.type == "brazier" and e.room == r.index and not e.get("lit", false):
					icon = "brazier_bowl"
			for e: Dictionary in breakables:
				if icon == "" and e.room == r.index and not e.get("broken", false):
					icon = "demon_plate" if e.type == "seal" else "skull_heap"
		# a known room not yet entered shows what waits in it (side rooms and the boss: room_sign)
		if not seen:
			icon = room_sign(r) if r.type == "boss" or not bool(r.get("on_path", false)) else ""
		if icon == "":
			continue
		var im: Texture2D = tex[key_sprite[r.icon_key] if icon == "key" and key_sprite.has(r.icon_key) else icon]
		var c := origin + Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0) * s
		var sz := Vector2(isz, isz * im.get_height() / im.get_width())
		var tint: Color = key_tint.get(r.icon_key, Color.WHITE) if icon == "key" else Color.WHITE
		if not seen:
			tint.a = float(_room_signs().get("map", {}).get("alpha", 0.8))
		h.draw_texture_rect(im, Rect2(c - sz / 2.0, sz), false, tint)
		var room_w: float = r.bw * s
		if big and (seen or r.type == "boss") and FONT.get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < room_w:
			_text(h, r.name, Vector2(c.x - room_w / 2.0, c.y + isz * 0.9), 16, ink, room_w)
	if big and not framed:
		_text(h, "Heller Raum: besucht · Rote Tür: verriegelt · Farbige Tür: Schlüssel · Gelbe Tür: Rätsel · M / Esc schließt", Vector2(0, screen.y - 12), 16, Color("#b89c8e"), screen.x)
	h.draw_circle(origin + Vector2(player.x, player.y - 20) / C * s, 6.0 if big else 3.0, Color("#fff1c2"))


## Routes the events of Ignaroth's rig (src/hell/drake_rig_host.gd): a severed
## part holds the picture (the feel's hitstop, else the rig's own hold), sounds
## its own break (the first of e.sounds that sfx has), shakes the view and
## bursts at the wound. Debris, wound glow, flash and the stagger pose are the
## rig view's own.
func _route_rig_events() -> void:
	for e: Dictionary in drake_rig.take_events():
		match str(e.name):
			DrakeRigHost.EVENT_SEVER:
				if feel != null:
					feel.feedback.hitstop = maxf(feel.feedback.hitstop, float(e.hitstop))
				else:
					drake_rig.hold(float(e.hitstop))
				if bool(e.get("own_sound", false)):
					for name: Variant in e.get("sounds", []):
						if sfx != null and sfx.has_effect(str(name)):
							_play_sfx(str(name))
							break
				state.shake = maxf(float(state.shake), float(e.shake))
				_burst(e.at, 14)
			DrakeRigHost.EVENT_CANCEL:
				# the attack fizzles where it was gathering
				_burst(e.at, 8)


# ---------- WAHN (madness_rules.json madness) ----------

## True when the story hero is the Leerenmagier (madness.immune_class with
## immune_spec as main specialisation): the spec with the most points in the
## talent build he plays with (src/combat/talent_combat.gd runtime ranks), else
## the one of his saved profile (src/hero/element_skin.gd main_spec).
func _void_mind() -> bool:
	var spec := ""
	if talents != null and talents.get("tc") != null:
		var ranks: Dictionary = talents.tc.runtime(1).get("ranks", {})
		var points := {}
		for talent: String in ranks:
			var own := talent.get_slice("_", 0)
			points[own] = int(points.get(own, 0)) + int(ranks[talent])
		var best := 0
		for own: String in points:
			if int(points[own]) > best:
				best = int(points[own])
				spec = own
	if spec.is_empty():
		spec = preload("res://src/hero/element_skin.gd").main_spec(profile, class_id)
	return ElementRules.void_mind(class_id, spec)


## A themed world's enemy `m` turned on another ({} for none). Mad and without
## one, it rolls madness.turn_chance every madness.decide s (these enemies
## have no attack decision of their own) and takes the nearest other enemy of
## its room; it lets go after one blow or shot landed on it, when the victim
## fell or after turn_hold s. Bosses never turn (their shots only scatter).
func _themed_mad_victim(m: Dictionary, dt: float) -> Dictionary:
	if float(m.get("mad_t", 0.0)) <= 0.0 or m.kind == "boss":
		m.erase("mad_on")
		return {}
	var M := ElementRules.madness()
	var on: Dictionary = m.get("mad_on", {})
	if not on.is_empty():
		m.mad_hold = float(m.get("mad_hold", 0.0)) - dt
		if on.hp <= 0.0 or float(m.mad_hold) <= 0.0 or bool(m.get("mad_done", false)) or not mobs.any(func(o: Dictionary) -> bool: return is_same(o, on)):
			on = {}
	if on.is_empty():
		m.mad_on = {}
		m.mad_done = false
		m.mad_roll_t = float(m.get("mad_roll_t", 0.0)) - dt
		if float(m.mad_roll_t) <= 0.0:
			m.mad_roll_t = float(M.get("decide", 1.0))
			if randf() < float(M.get("turn_chance", 0.3)):
				on = ElementRules.nearest_other(m, mobs, "p", func(o: Dictionary) -> bool: return o.room == m.room and o.hp > 0.0 and float(o.get("spawn", 0.0)) <= 0.0, PIXEL_WORLD / 2.0)
				if not on.is_empty():
					m.mad_on = on
					m.mad_hold = float(M.get("turn_hold", 3.0))
					m.mad_turns = int(m.get("mad_turns", 0)) + 1
	return on


## A mad themed enemy's blow or shot landing on another enemy:
## madness.story_hits hero hits (a boss takes half); a body blow (`body`) at
## most every madness.mad_cd s. It is its one attack on the victim (mad_done).
func _themed_mad_strike(attacker: Dictionary, victim: Dictionary, body: bool) -> void:
	if victim.is_empty() or victim.hp <= 0.0:
		return
	var M := ElementRules.madness()
	if body:
		if float(attacker.get("mad_cd", 0.0)) > 0.0:
			return
		attacker.mad_cd = float(M.get("mad_cd", 0.6))
	var hurt := float(M.get("story_hits", 1.0)) * (0.5 if victim.kind == "boss" else 1.0) * float(state.dmg)
	victim.hp -= hurt
	victim.mad_taken = float(victim.get("mad_taken", 0.0)) + hurt
	victim.hit = 0.12
	attacker.mad_hits = int(attacker.get("mad_hits", 0)) + 1
	attacker.mad_done = true
	if feel != null:
		feel.on_hit(victim, (Vector2(victim.p) - Vector2(attacker.p)).normalized(), false)


## A turned themed enemy's shot meeting another enemy (not its shooter): it
## hurts it and is spent; true when it hit.
func _themed_mad_shot(s: Dictionary) -> bool:
	var shooter: Dictionary = s.mad
	for o: Dictionary in mobs:
		if is_same(o, shooter) or o.hp <= 0.0 or float(o.get("spawn", 0.0)) > 0.0:
			continue
		if (s.p as Vector2).distance_to(Vector2(o.p) - Vector2(0, float(o.get("cy", 30.0)))) < float(o.r) * 0.6 + 18.0:
			s.t = 0.0
			_themed_mad_strike(shooter, o, false)
			return true
	return false

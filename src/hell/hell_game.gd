extends Node2D
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
const DrakeRigHost = preload("res://src/hell/drake_rig_host.gd")
const FrostRigs = preload("res://src/hell/frost_rigs.gd")
const FrostFx = preload("res://src/hell/frost_fx.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
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
const HEART := "res://assets/sprites/0x72/ui_heart_%s.png"
const Sfx = preload("res://src/vfx/sfx.gd")
const Music = preload("res://src/audio/music.gd")
const SaveStore = preload("res://src/save/save_store.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const StoryHero = preload("res://src/hero/story_hero.gd")
## The crypt's darkness and bloom in this world (src/hero/story_glow.gd).
const StoryGlow = preload("res://src/hero/story_glow.gd")
const Darkness = preload("res://src/vfx/darkness.gd")
const Snowstorm = preload("res://src/vfx/snowstorm.gd")
const FrostSnow = preload("res://src/hero/frost_snow.gd")
const StorySave = preload("res://src/save/story_save.gd")
## The crypt's pause menu, in its story mode (overview, quest, map, controls, display, save).
const PauseMenu = preload("res://src/pause_menu.gd")
const STORY_CONTROLS := "Bewegen: WASD\nAngreifen: Linksklick oder Pfeiltasten\nTalente: Shift + 1 2 3 4, Ultimate: R\nFähigkeiten: 1 2 3 4 · Meisterfähigkeit: 5\nKarte wählen: 7 8 9 oder Klick\nAktion (Tür, Truhe, Schale): E oder Leertaste\nRelikt / Waffe wechseln: T · Klon: Q\nKarte: M · Licht: L · Status: C oder Tab\nLauf-Talente: B\nNach dem Tod: E neuer Lauf\nMenü öffnen / schließen: Esc"
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const SkillBar = preload("res://src/ui/skill_bar.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const GraphicsSettings = preload("res://src/core/graphics_settings.gd")
const RunTree = preload("res://src/progress/run_tree.gd")
const RunTreeView = preload("res://src/ui/run_tree_view.gd")
const StoryItems = preload("res://src/hero/story_items.gd")
const InventoryPanel = preload("res://src/ui/inventory_panel.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
## The world kit (src/world_kit): a world with theme.world_pack builds every floor live from the
## run number instead of reading baked floors (Story 1 the crypt, Story 3 the hell).
const WorldPack = preload("res://src/world_kit/world_pack.gd")
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
## Hero class from theme.classes (menu choice); empty takes theme.default_class.
@export var class_id := ""
## A loaded save (src/save/story_save.gd): set before the node enters the tree to continue on its floor.
var resume: Dictionary = {}
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
var lava_slosh := 0.0
## Telegraphed boss areas: icicle targets, chill fields, landing marks, safe circles.
var zones: Array = []
## Class skills (hero_skills.json, scaled) and their running parts: a held skill,
## a dash, short effects, the level-up flash, gravity walls and bars.
var skills: Array = []
var hold: Dictionary = {}
var dash: Dictionary = {}
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
var pits: Array = []
var clone: Dictionary = {}
var solid_grid: Dictionary = {}
var door_at: Dictionary = {}
var minimap: Array = []
var camera: Camera2D
var actors: Layer
## The crypt's darkness (src/vfx/darkness.gd); src/hero/story_glow.gd lights it.
var dark: Node2D
## The light snowstorm over the whole screen of a world with theme "snowstorm" (src/vfx/snowstorm.gd); null elsewhere.
var snowstorm: Node2D
## Footprints in the snow and sliding on glaze ice in a world with theme "snow" (src/hero/frost_snow.gd); null elsewhere.
var frost_snow: RefCounted
## The crypt's bloom over the darkness and the darkness's lights (src/hero/story_glow.gd).
var story_glow: StoryGlow
## Additive layer for attack glows and enemy shots of the hell monsters (under the
## darkness, like the crypt's bullets; their bloom is story_glow's).
var glow: Layer
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
var _chunk_nodes: Array = []
var _vignette: GradientTexture2D


## One drawing layer of the world; the game draws into it by kind.
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
	_load_theme()
	balance = JSON.parse_string(FileAccess.get_file_as_string(theme.balance))
	if theme.has("world_pack"):
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
		weapon_tex = load(WEAPON % weapon.sprite)
		arrow_tex = load(WEAPON % "weapon_arrow")
	for kind in ["idle", "run"]:
		var frames: Array = []
		for f in range(4):
			frames.append(load(HERO % [hero.get("sprite", "knight_m"), kind, f]))
		hero_frames[kind] = frames
	skills = HeroKit.load_skills(self, class_id)
	if theme.has("feel"):
		feel = StoryFeel.new(self, theme.feel)
		sound = StorySound.new(self)
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
	if not theme.has("mobs"):
		monsters = Monsters.new(self, balance.monsters)
		pools = PoolPaint.new(PIXEL_WORLD, _floor_open)
		# Ignaroth's part rig: tuning from balance.monsters.rigs (DrakeRigHost.DEFAULTS fill gaps)
		drake_rig = DrakeRigHost.new(balance.monsters, RigLibrary.shared())
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
	add_child(ui)
	# a world with a snowstorm (theme "snowstorm", the Frostgruft): light snow over everything, HUD and menus too
	if theme.has("snowstorm"):
		var storm_layer := CanvasLayer.new()
		storm_layer.layer = 90
		add_child(storm_layer)
		snowstorm = Snowstorm.new()
		storm_layer.add_child(snowstorm)
		snowstorm.configure(theme.snowstorm)
	hud = Hud.new()
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.theme = CryptUI.create_theme()
	ui.add_child(pause_menu)
	pause_menu.use_story_mode(STORY_CONTROLS)
	pause_menu.save_rows = func() -> Array: return saves.summaries(StorySave.mode(self))
	pause_menu.set_save_enabled(true)
	pause_menu.story_map_draw = func(canvas: Control) -> void: _draw_map(canvas, canvas.size, true, true)
	pause_menu.resume_pressed.connect(func() -> void: pause_menu.visible = false)
	pause_menu.save_requested.connect(save_slot)
	pause_menu.leave_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	pause_menu.display_mode_requested.connect(_toggle_fullscreen)
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
		_start_items(ui)
		return
	load_floor(clampi(start_floor, 1, floors_raw.size()), false)
	_start_items(ui)
	if start_at_boss:
		enter_boss_room()


## Item system 2 for a class hero (src/hero/story_items.gd): the bag and its window (I).
func _start_items(ui: CanvasLayer) -> void:
	if skills.is_empty():
		return
	story_items = StoryItems.new(self)
	add_child(story_items)
	story_items.start(absi(hash(str(state.get("run_id", "")))) % 1000000)
	inventory_panel = InventoryPanel.new()
	ui.add_child(inventory_panel)
	inventory_panel.acted.connect(func(action: String, value: int) -> void: story_items.act(action, value))
	inventory_panel.throw_armed.connect(func(slot: int) -> void: throw_slot = slot)
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
	if profile.is_empty(): return
	var state_class := Profile.class_state(profile, class_id)
	var gained := TalentRules.add_exp(profile_data, state_class, int(profile_data.exp.floor) + (int(profile_data.exp.boss) if W.final else int(profile_data.exp.miniboss)))
	profile.gold = int(profile.gold) + int(profile_data.gold.per_floor) + (int(profile_data.gold.per_boss) if W.final else 0)
	_floor_reward = "+%d Gold" % (int(profile_data.gold.per_floor) + (int(profile_data.gold.per_boss) if W.final else 0))
	if gained > 0: _floor_reward += "  ·  Level %d, neuer Talentpunkt" % int(state_class.level)
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
	# a generated world keeps its run number from floor to floor (and in saves); a fresh run rolls one
	var world_run := 0
	if world != null:
		world_run = int(state.get("world_run", 0)) if carry and not state.is_empty() else 0
		if world_run == 0:
			world_run = WorldPack.new_run()
		W = FloorData.prepare(world.build_raw(n, world_run))
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
	walls = Walls.build(W.grid, W.cols, W.rows, C)
	_index_solids()
	if frost_snow != null:
		frost_snow.reset()
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
	var keep := {"hp": start_hp, "max_hp": start_hp, "gems": 0, "dmg": float(weapon.get("damage", 1.0)),
		"rate": float(weapon.get("cooldown", balance.shot.cooldown)), "speed_mul": 1.0, "range": float(weapon.get("life", balance.shot.life)), "buffs": [],
		"skill": {"owned": false, "active": false, "left": float(balance.clone.duration)},
		"level": 1, "exp": 0, "skill_cd": {}, "relic": "", "relic_on": false, "upgrades": {}, "offer": [], "cards_due": 0,
		"relic_floor": 0, "relic_item": "", "talent": talent, "crystals_run": 0, "run_id": _new_run_id(), "world_run": world_run}
	if carry and not state.is_empty():
		keep = {"hp": state.hp, "max_hp": state.max_hp, "gems": state.gems, "dmg": state.dmg, "rate": state.rate,
			"speed_mul": state.speed_mul, "range": state.range, "buffs": state.buffs, "skill": state.skill,
			"level": state.level, "exp": state.exp, "skill_cd": {}, "relic": state.relic, "relic_on": state.relic_on, "upgrades": state.upgrades,
			"offer": state.offer, "cards_due": state.cards_due, "relic_floor": state.relic_floor, "relic_item": state.relic_item,
			"talent": state.talent, "crystals_run": state.crystals_run, "run_id": str(state.get("run_id", _new_run_id())), "items": state.get("items", {}),
			"world_run": world_run}
		keep.skill.active = false
	state = {"floor": n, "keys": {"A": false, "B": false, "C": false}, "used": {"A": false, "B": false, "C": false},
		"visited": {start.index: true}, "room": start.index, "banner": {"text": W.title, "sub": "Etage %d · %s" % [n, W.circle], "t": 0.0},
		"toasts": [], "inv": 0.0, "dead": 0.0, "map": false, "light": state.get("light", true), "t": 0.0, "won": false, "won_t": 0.0,
		"cool": 0.0, "flash": 0.0, "chill": 0.0, "storm": false, "rage": 0.0, "boss_dead": false, "stealth": 0.0, "blades": {},
		"shake": 0.0, "white": 0.0, "slow": 0.0, "pull": null}
	state.merge(keep)
	# the phoenix master skill lifts the hero once per floor
	state.phoenix_life = str(state.talent.get("master", "")) == "phoenix"
	if not carry:
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
	shots = []
	eshots = []
	zones = []
	if monsters != null:
		monsters.reset()
		drake_rig.reset()
	if frost_rigs != null:
		frost_rigs.reset()
	if frost_fx != null:
		frost_fx.reset()
	if pools != null:
		pools.clear()
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
	pits = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "pit")
	for e: Dictionary in breakables:
		e.max_hp = int(e.hp)
	_respawn()
	camera.position = Vector2(player.x, player.y)
	if not profile.is_empty() and (talents == null or not carry):
		talents = HellTalents.new()
		talents.bind(self, profile, profile_path, class_id)


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
	state.banner = {"text": boss.name, "sub": "Debug-Start beim Boss", "t": 0.0}
	camera.position = Vector2(player.x, player.y)


func _room_of_type(kind: String) -> Dictionary:
	for r: Dictionary in W.rooms:
		if r.type == kind:
			return r
	return W.rooms[0]


func _respawn() -> void:
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
	var run := Rect2()
	for c: Vector2i in r.cells:
		if run.size.x > 0.0 and int(run.position.y) == c.y and int(run.end.x) == c.x:
			run.size.x += 1.0
		else:
			if run.size.x > 0.0:
				rects.append(run)
			run = Rect2(c.x, c.y, 1, 1)
	if run.size.x > 0.0:
		rects.append(run)
	for c: Vector2i in r.cells:
		for side: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n := c + side
			var outside: bool = n.x < 0 or n.y < 0 or n.x >= cols or n.y >= W.rows or W.room_at[n.y * cols + n.x] != r.index
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


## World px per art pixel (the floor tiles' 16 px art drawn x3 at 48 px).
const PIXEL_WORLD := 3.0


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
			for s: Rect2 in solid_grid.get(cy * int(W.cols) + cx, []):
				if s.intersects(box):
					return true
	for e: Dictionary in breakables:
		if not e.get("broken", false) and _breakable_box(e).intersects(box):
			return true
	return false


func _breakable_box(e: Dictionary) -> Rect2:
	if e.type == "crate":
		return Rect2(e.x - 30.0, e.y - 30.0, 60.0, 30.0)
	var hw := 42.0 if e.type == "seal" else 48.0
	return Rect2(e.x - hw, e.y - 40.0, hw * 2.0, 40.0)


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
func free_floor(room: int, near: Vector2, min_d: float, max_d: float) -> Vector2:
	for k in range(40):
		var p := near + Vector2.from_angle(randf() * TAU) * randf_range(min_d, max_d)
		if _room_at_world(p.x, p.y) == room and _cell(int(floor(p.x / C)), int(floor(p.y / C))) == 1 \
				and not box_blocked(Rect2(p.x - 30, p.y - 30, 60, 30), true):
			return p
	return near


func _near_door(r: Dictionary, p: Vector2, dist: float) -> bool:
	for i: int in r.doors:
		var d: Dictionary = W.doors[i]
		if p.distance_to(Vector2(d.cx, d.cy)) < dist * C:
			return true
	return false


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	# while paused only Esc counts (it closes the menu again)
	if pause_menu != null and pause_menu.visible and not (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pause_menu != null and not state.map \
			and HudKit.menu_rect(get_viewport_rect().size).has_point(event.position):
		open_pause()
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
	if not stairs_pick.is_empty() and event.pressed:
		# the floor choice of the hidden stairs takes the number keys; Esc or E closes it
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			choose_stairs(int(event.keycode - KEY_0))
		elif event.keycode in [KEY_ESCAPE, KEY_E, KEY_SPACE]:
			stairs_pick = {}
		get_viewport().set_input_as_handled()
		return
	var skill_keys := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4"}
	# Shift + 1-4: the talent bar, R: the ultimate (the same keys in every map).
	if talents != null and event.pressed and skill_keys.has(event.keycode) and event.shift_pressed:
		talents.press(int(skill_keys[event.keycode]) - 1)
		return
	if talents != null and event.pressed and event.keycode == KEY_R:
		talents.press(-1)
		return
	if not skills.is_empty() and skill_keys.has(event.keycode):
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
		KEY_M:
			state.map = not state.map
		KEY_L:
			state.light = not state.light
		KEY_ESCAPE:
			if pause_menu.visible:
				pause_menu.visible = false
			else:
				open_pause()
		KEY_T:
			if str(state.relic) != "":
				state.relic_on = not state.relic_on
				_relic_texture()
				_toast(("%s in der Hand." % theme[state.relic].name) if state.relic_on else ("%s in der Hand." % weapon.get("name", "Waffe")))
		KEY_5:
			if not skills.is_empty() and FrostCombat.can_cast(self, "5") and not SubKit.master(self):
				as_source("hero", func() -> void: HeroKit.master_press(self))
		KEY_C, KEY_TAB:
			state.status = not state.get("status", false)
		KEY_I:
			if inventory_panel != null and not skills.is_empty():
				inventory_panel.set_open(not inventory_panel.open)
		KEY_B:
			# the run talent tree (docs/LAUF-DESIGN.de.md); the world keeps running
			if not skills.is_empty():
				state.tree_open = not state.get("tree_open", false)
		KEY_PAGEUP:
			# debug: one level up
			if not skills.is_empty():
				HeroKit.gain(self, HeroKit.need(theme.leveling, int(state.level)) - int(state.exp))
		_:
			var k: int = event.keycode
			if not skills.is_empty() and k >= KEY_F1 and k <= KEY_F10:
				# debug floor jumps keep the hero's progress where 1-4 are skills
				load_floor(k - KEY_F1 + 1, true)
			elif skills.is_empty() and k >= KEY_0 and k <= KEY_9:
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
	return (1.0 if Input.is_physical_key_pressed(pos) else 0.0) - (1.0 if Input.is_physical_key_pressed(neg) else 0.0)


# ---------- gameplay ----------

func _toast(text: String) -> void:
	state.toasts.append({"text": say(text), "t": 3.6})
	if state.toasts.size() > 3:
		state.toasts.pop_front()


## Costs the hero n half hearts unless he is still invulnerable from the last hit
## (`from`: where the blow came from, when known: the crypt's blood splats away from it).
func _hurt(why: String, n := 1, from := Vector2.ZERO) -> void:
	if state.inv > 0.0 or state.dead > 0.0:
		return
	if SubKit.guard(self):
		return
	if story_items != null and story_items.consume_shield():
		state.inv = float(balance.player.invulnerable)
		return
	if story_items != null:
		n += story_items.extra_damage()
	state.inv = float(balance.player.invulnerable)
	# Talents: difficulty, reductions, shields, the counter (the same in every map).
	if talents != null:
		n = talents.incoming(n)
		if n <= 0: return
	_lose_hp(n, why, from)


## Damage over time (poison and burn of the Frostgruft's conditions,
## src/hell/hero_fx.gd): lands through the short invulnerability after a hit,
## but not while dying.
func dot_hurt(n: int, why: String) -> void:
	if state.dead > 0.0 or state.won:
		return
	_lose_hp(n, why)


## Takes n half hearts: the flash, the hurt sounds, the feel; the phoenix or death at zero.
func _lose_hp(n: int, why: String, from := Vector2.ZERO) -> void:
	state.hp = maxi(0, state.hp - n)
	if feel != null:
		# the crypt's hurt: punch with its groan layer (feedback.gd), once; like the crypt
		# no red wash over the whole screen (the hero's flash, blood, shake and hitstop show it)
		feel.on_hurt(from)
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
				if not e.get("lit", false):
					out.append({"e": e, "label": "Erst die Gegner besiegen" if W.rooms[e.room].fight else "Feuerschale entzünden", "p": Vector2(e.x, e.y - 30), "r": 115.0})
			# the world kit's key room, hidden stairs and their trigger
			"well":
				out.append({"e": e, "label": "Manabrunnen: versiegt" if e.get("used", false) else "Manabrunnen: Kräfte ganz auffüllen (einmal)", "p": Vector2(e.x, e.y - 30), "r": 150.0})
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
			out.append({"e": d, "label": ("%s benutzen" if state.keys[d.key] else "Verschlossen: %s fehlt") % key_name[d.key], "p": p, "r": 190.0})
		elif d.kind == "puzzle" and _door_closed(d) and not W.rooms[d.a].fight and not W.rooms[d.b].fight:
			var g: Dictionary = W.groups[d.group]
			var label := "Gittertor: alle Feuerschalen der Etage entzünden" if g.get("spread", false) else ("Rätseltor: alle Feuerschalen entzünden" if g.kind == "braziers" else "Rätseltor: alle Runenplatten betreten")
			if g.kind == "sequence" and g.has("count"):
				label = "Gittertor: die %d Druckplatten in der richtigen Reihenfolge betreten" % int(g.count)
			out.append({"e": d, "label": label, "p": p, "r": 190.0})
		elif d.kind == "boss" and _door_closed(d):
			out.append({"e": d, "label": "Versiegelt bis %s fällt" % W.boss.name, "p": p, "r": 190.0})
	return out


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
	if not (state.get("over", {}) as Dictionary).is_empty():
		return
	saves.erase_run(StorySave.mode(self), str(state.get("run_id", "")))
	run_slot = 0
	state.over = {"won": won, "why": str(state.get("death_why", "")), "floor": int(state.floor), "title": str(W.get("title", "")),
		"level": int(state.get("level", 1)), "crystals": int(state.get("crystals_run", 0))}
	mobs = []
	eshots = []
	zones = []
	hold = {}
	dash = {}
	# a lost run already sounded the crypt's defeat when the hero fell (story_sound.gd phase "dead")
	if won or feel == null:
		_sound("level_up" if won else "hurt_voice")


## The result panel's rows for an ended run.
func run_result(over: Dictionary) -> Dictionary:
	var won := bool(over.get("won", false))
	var zone := str(theme.get("zone_name", "FROSTGRUFT" if StorySave.mode(self) == "frost" else "HÖLLE"))
	var lines: Array = [["ZONE", zone], ["ERREICHT", "ETAGE %d · %s" % [int(over.floor), str(over.title).to_upper()]], ["LEVEL", str(int(over.level))]]
	if not won and str(over.why) != "":
		lines.append(["URSACHE", str(over.why).to_upper()])
	# the profile keeps level, gold and soul shards (docs/TALENTE-SEELENSPLITTER.de.md)
	var note := ""
	if not profile.is_empty():
		note = "PROFIL: LEVEL %d · %d GOLD · %d SEELENSPLITTER" % [int(Profile.class_state(profile, class_id).level), int(profile.gold), int(profile.shards.have)]
	return {"title": say("Die Hölle ist bezwungen").to_upper() if won else "LAUF BEENDET", "tone": "win" if won else "loss",
		"lines": lines, "note": note, "hints": "E · NEUER LAUF   ESC · MENÜ"}


## A new run of this zone from its first floor: the same scene and class, fresh.
func new_run() -> void:
	var scene: Node = (load(scene_file_path) as PackedScene).instantiate()
	scene.class_id = class_id
	scene.graphics_path = graphics_path
	scene.meta_path = meta_path
	var tree := get_tree()
	tree.root.add_child(scene)
	if tree.current_scene == self:
		tree.current_scene = scene
	queue_free()


## Uses whatever stands next to the hero (E / Space / Enter).
func act() -> void:
	if not (state.get("over", {}) as Dictionary).is_empty():
		new_run()
		return
	if state.dead > 0.0:
		return
	if state.won:
		load_floor(state.floor + 1, true)
		return
	var n := _nearest()
	if n.is_empty():
		return
	var e: Dictionary = n.e
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
				var names: Array = (theme[e.item].skills as Array).map(func(s: Dictionary) -> String: return "%s (%s, ab LV %d)" % [s.short, s.key, int(s.unlock)])
				state.banner = {"text": str(theme[e.item].name), "sub": " · ".join(PackedStringArray(names)) + " · T wechselt", "t": 0.0}
			"chest":
				if e.get("mimic", false):
					_wake_mimic(e)
					return
				# effect hook: with the feel a chest opens like the crypt's (chest_open: splinters, the
				# pickup sheet and its sound) and its loot is taken like the crypt's (loot_taken)
				if feel == null:
					_sound("chest")
				if e.loot.has("key"):
					e.state = "empty"
					state.keys[e.loot.key] = true
					if feel != null:
						feel.fx_event("chest_open", Vector2(e.x, e.y - 30))
					else:
						_burst(Vector2(e.x, e.y - 40), 30, true)
					_toast("Truhe geöffnet: %s genommen!" % key_name[e.loot.key])
				elif e.get("state", "") == "":
					e.state = "open"
					if feel != null:
						feel.fx_event("chest_open", Vector2(e.x, e.y - 30))
					_toast("Truhe geöffnet: %d Runensteine%s" % [e.loot.gems, " und ein Herz" if e.loot.get("heart", false) else ""])
					if story_items != null:
						story_items.loot("chest", Vector2(e.x, e.y + 40))
				else:
					e.state = "empty"
					state.gems += int(e.loot.gems)
					if feel != null:
						feel.fx_event("loot_taken", Vector2(e.x, e.y - 30))
					if e.loot.get("heart", false):
						state.hp = mini(state.max_hp, state.hp + 2)
						if feel != null:
							feel.hero_perk("heal")
			"vault":
				e.opened = true
				# a plate vault pays more the more plates guarded it (tier = plate count, 4 = base)
				var tier := int(e.get("tier", 4))
				var hearts := int(balance.vault.heart_containers) + (1 if tier >= 6 else 0)
				var gems: int = roundi((int(balance.vault.gems_base) + state.floor * int(balance.vault.gems_per_floor)) * (1.0 + (tier - 4) * 0.5))
				state.gems += gems
				state.max_hp = mini(int(balance.player.max_hp_cap), state.max_hp + 2 * hearts)
				state.hp = state.max_hp
				# effect hook: with the feel the vault opens like the crypt's chests (chest_open)
				if feel != null:
					feel.fx_event("chest_open", Vector2(e.x, e.y - 60), {"r": 24.0})
					feel.hero_perk("heal")
				else:
					_burst(Vector2(e.x, e.y - 60), 60 + maxi(0, tier - 4) * 10, true)
				_toast("Riesentresor! +%d Herzcontainer, volle Gesundheit, +%d Runensteine" % [hearts, gems])
				if story_items != null:
					story_items.loot("gold_crate", Vector2(e.x, e.y + 60))
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
			"well":
				# the mana fountain, once: until mana comes to the story worlds it refills the skills
				if e.get("used", false):
					_toast("Der Brunnen ist versiegt.")
					return
				e.used = true
				state.skill_cd = {}
				_burst(Vector2(e.x, e.y - 70), 36)
				_sound("relic")
				_toast("Kräfte vollständig aufgefüllt. Der Brunnen versiegt.")
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
		if state.keys[e.key]:
			state.keys[e.key] = false
			state.used[e.key] = true
			e.unlocked = true
			_sound("gate_open")
			_toast("Das Tor öffnet sich.")
		else:
			_sound("gate_locked")
			_toast("%s %s" % [key_name[e.key], key_hint[e.key]])


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
	walls = Walls.build(W.grid, W.cols, W.rows, C)
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


func _fire(dir: Vector2) -> void:
	if state.cool > 0.0 or dir == Vector2.ZERO or not hold.is_empty() or not FrostCombat.can_attack(self):
		return
	_attack(dir)
	if state.cool > 0.0:
		state.cool *= FrostCombat.rate(self) * (talents.interval_scale() if talents != null else 1.0)


## One attack of the class weapon (or the relic) towards `dir`.
func _attack(dir: Vector2) -> void:
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
	shots.append({"p": Vector2(player.x, player.y - 40), "v": v, "t": float(state.range), "kind": str(weapon.get("shot", "")), "splash": float(weapon.get("splash", 0.0)), "hits": []})
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
	if story_items != null and mult > 0.0:
		story_items.on_hit(m)
	# with the feel the hit sounds in the monster's crypt material (feedback.gd via FrostCombat.after_hit)
	if feel == null:
		_sound("hit_" + str(def.get("material", "void")))
	m.hit = 0.12
	# kit bosses stand firm: no knockback
	m.k = Vector2.ZERO if m.has("kit") else push * (0.05 if m.kind == "boss" else 0.25)
	FrostCombat.after_hit(self, m, push, crit > 1.0)
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
	var def := _mob_def(kind)
	var diff: Dictionary = W.diff
	var hp: float = (float(W.boss.hp) if kind == "boss" else round(float(def.hp) * float(diff.hp))) * (talents.hp_scale() if talents != null else 1.0)
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


func _start_fight(r: Dictionary) -> void:
	r.fight = true
	var me := Vector2(player.x, player.y)
	var cells: Array = []
	for c: Vector2i in r.cells:
		var p := Vector2((c.x + 0.5) * C, (c.y + 0.7) * C)
		if W.grid[c.y * W.cols + c.x] == 1 and p.distance_to(me) > 4.5 * C and not _near_door(r, p, 2.0) and solid_grid.get(c.y * W.cols + c.x, []).is_empty():
			cells.append(p)
	cells.shuffle()
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
	if r.drop != "" and not again:
		_drop("key", r.index, at, {"key": r.drop})
		_toast("Raum gesäubert. %s gefallen!" % key_name[r.drop])
	elif r.type == "boss":
		state.boss_dead = true
		RelicKit.drop(self, at)
		# a mini guardian leaves a rare piece, a floor guardian its loot (the last one nothing)
		if story_items != null and not W.final:
			if W.boss.get("mini", false):
				story_items.guardian_drop(at)
			else:
				story_items.loot("mimic", at)
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
		for k in range(int(r.reward.get("gems", 0))):
			_drop("gem", r.index, at)
	elif randf() < float(balance.drops.heart):
		_drop("heart", r.index, at)
	elif randf() < float(balance.drops.gem):
		_drop("gem", r.index, at)


func _drop(kind: String, room: int, at: Vector2, extra := {}) -> void:
	var e := {"type": kind, "x": at.x + randf_range(-30, 30), "y": at.y + randf_range(-20, 20), "room": room}
	e.merge(extra)
	W.ents.append(e)


func _enemy_shot(from: Vector2, dir: Vector2, speed: float) -> void:
	eshots.append({"p": from, "v": dir.normalized() * speed, "t": float(balance.enemy_shot.life)})


func _burst(at: Vector2, n: int, gold := false) -> void:
	# effect hook: with the feel a level-up is the crypt's (its sheet, pillar, ring and bloom:
	# src/hero/story_feel.gd), so hero_kit.gd _level_up's gold embers (raised as levelfx starts) stay out
	if feel != null and gold and not levelfx.is_empty() and float(levelfx.t) == 0.0 and at.is_equal_approx(Vector2(player.x, player.y - 50)):
		return
	for k in range(n):
		embers.append({"p": at, "v": Vector2(randf_range(-150, 150), randf_range(-210, 90)), "t": randf_range(0.35, 0.85), "big": n > 20, "gold": gold})


# ---------- seals, skull heaps, pits and the clone ----------

func _hit_breakable(e: Dictionary, at: Vector2) -> void:
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


## A broken seal blesses the hero (bless_chance) or releases demons that lock the room again.
func _break_seal(e: Dictionary) -> void:
	var cfg: Dictionary = balance.seal
	if randf() < float(cfg.bless_chance):
		var id: String = Rules.BLESSINGS[randi() % Rules.BLESSINGS.size()]
		var text := Rules.apply_blessing(state, id, balance.blessings, int(balance.player.max_hp_cap))
		# effect hook: with the feel a blessing shines like the crypt's cleanse (golden burst, sheet, chime)
		if feel != null:
			feel.fx_event("cleanse", Vector2(e.x, e.y - 40))
		else:
			_burst(Vector2(e.x, e.y - 60), 50, true)
		_toast("Das Siegel bricht: %s!" % text)
		return
	var r: Dictionary = W.rooms[e.room]
	r.fight = true
	r.cleared = false
	# effect hook: released demons flare dark like the crypt's curse
	if feel != null:
		feel.fx_event("curse", Vector2(e.x, e.y - 40))
	var n := int(cfg.demons)
	for k in range(n):
		var at := Vector2(e.x + (k - (n - 1) / 2.0) * 90.0, e.y + 60.0 + (50.0 if k == 1 else 0.0))
		if monsters != null:
			monsters.spawn(r.index, at, String(balance.monsters.seal_demon))
		else:
			_spawn_mob(r.index, at, String(cfg.demon_kind))
	_toast("Das Siegel bricht: drei Dämonen springen heraus! Die Gitter fallen.")


## A broken urn, barrel or crate (world kit): nothing, rune stones, a heart, or (crates only)
## undead that lock the room.
func _break_crate(e: Dictionary) -> void:
	_sound("hit_bone")
	match str(e.get("drop", "none")):
		"gem":
			_drop("gem", e.room, Vector2(e.x - 14, e.y))
			_drop("gem", e.room, Vector2(e.x + 16, e.y + 8))
			_toast("Zerbrochen: Runensteine.")
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


## A chest that was a mimic: it wakes on opening, the room locks and the fight is on.
func _wake_mimic(e: Dictionary) -> void:
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
	var kind := str(theme.get("mimic_kind", "mimik"))
	if monsters != null and monsters.defs.has(kind):
		var m: Dictionary = monsters.spawn(r.index, monsters.free_spot(r.index, Vector2(e.x, e.y), 0.0, 60.0), kind)
		m.spawn = 0.0
	_burst(Vector2(e.x, e.y - 40), 30, true)
	state.shake = 0.4
	_sound("boss_intro")
	_toast("Die Truhe hat Zähne! Ein Mimik greift an. Die Gitter fallen.")


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
	if stairs_pick.is_empty() or n < 1 or n >= int(state.floor):
		return
	stairs_pick = {}
	state.world_run = WorldPack.new_run()
	load_floor(n, true)
	_toast("Eine neue Welt: zurück auf Etage %d." % n)


func _fall_into_pit() -> void:
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
		state.death_why = "in eine Grube gestürzt"
		_toast("In die Grube gestürzt.")
		return
	for r: Dictionary in W.rooms:
		if r.fight:
			r.fight = false
			mobs = mobs.filter(func(m: Dictionary) -> bool: return m.room != r.index)
	eshots = []
	zones = []
	state.storm = false
	if monsters != null:
		monsters.reset()
		drake_rig.reset()
	if frost_rigs != null:
		frost_rigs.reset()
	if frost_fx != null:
		frost_fx.reset()
	if pools != null:
		pools.clear()
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
	var ok := not floor_save.is_empty() and saves.write(StorySave.mode(self), slot, floor_save)
	if ok:
		run_slot = slot
	if pause_menu != null:
		pause_menu.refresh_save(("Gespeichert in Platz %d: Beginn von Etage %d." % [slot, int(floor_save.floor)]) if ok else "Speichern fehlgeschlagen.")
	return ok


## Esc: the shared pause menu (the world stands still), centred on the screen, on its overview.
func open_pause() -> void:
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
	pause_menu.resume_button.grab_focus()


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
		"%s · LV %d · %s" % [hero_name, int(state.get("level", 1)), held],
		"Leben: %s von %d Herzen" % [str(int(state.hp) / 2) + (",5" if int(state.hp) % 2 == 1 else ""), int(state.max_hp) / 2],
		"Runensteine: %d" % int(state.gems),
		"Schlüssel: %s" % (", ".join(PackedStringArray(keys)) if not keys.is_empty() else "keiner"),
		"Segen: %s" % (", ".join(PackedStringArray(blessings)) if not blessings.is_empty() else "keiner"),
		"", "Räume besucht: %d von %d" % [state.visited.size(), W.rooms.size()],
	]
	if str(state.relic) != "":
		lines.insert(5, "Relikt: %s" % theme[state.relic].name)
	return {"overview": say("\n".join(PackedStringArray(lines))), "quests": FrostHud.goals(self), "quest_title": "ETAGE %d" % int(state.floor)}


func _toggle_fullscreen() -> void:
	var full := get_window().mode == Window.MODE_FULLSCREEN
	get_window().mode = Window.MODE_WINDOWED if full else Window.MODE_FULLSCREEN
	pause_menu.set_display_state(not full, get_viewport().get_visible_rect().size)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	# the world stands still while the pause menu is open
	if pause_menu != null and pause_menu.visible:
		hud.queue_redraw()
		return
	# a kill or a hurt holds the picture for a moment, as in the crypt (hitstop, src/hero/story_feel.gd)
	if feel != null and feel.frozen():
		feel.freeze(dt)
	elif drake_rig != null and drake_rig.frozen():
		# a severed part holds the picture without the feel too (src/hell/drake_rig_host.gd hold)
		drake_rig.freeze(dt)
	else:
		_update(dt)
	actors.queue_redraw()
	glow.queue_redraw()
	# the darkness's lights and the bloom, after the actors (their glowing parts follow the drawn bodies)
	story_glow.frame()
	hud.queue_redraw()


func _update(dt: float) -> void:
	state.t += dt
	story_hero.update(dt)
	if story_items != null:
		story_items.update(dt)
		if inventory_panel != null:
			inventory_panel.set_view(story_items.view())
	for k in ["inv", "flash", "cool", "chill", "slow"]:
		state[k] = maxf(0.0, state[k] - dt)
	state.shake = maxf(0.0, state.shake - dt * 30.0)
	state.white = maxf(0.0, state.white - dt * 1.6)
	for t: Dictionary in state.toasts:
		t.t -= dt
	state.toasts = state.toasts.filter(func(t: Dictionary) -> bool: return t.t > 0.0)
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
		_update_music()
		state.dead -= dt
		if state.dead <= 0.0:
			# a dungeon crawler: death ends the run (docs/LAUF-DESIGN.de.md)
			end_run(false)
			state.inv = 1.2
			state.room = _room_of_type("start").index
		return
	swing.t = maxf(0.0, swing.t - dt)
	if talents != null: talents.update(dt)
	# the kits' direct sounds by who acts (src/hero/story_sound.gd): the hero's skills, relics and allies, the enemy moves
	as_source("hero", _update_hero_kits.bind(dt))
	as_source("moves", func() -> void: FrostCombat.update(self, dt))
	if feel != null:
		feel.update(dt)
	if not (state.get("offer", []) as Array).is_empty():
		state.offer_t = float(state.get("offer_t", 0.0)) + dt
	_update_music()
	_update_player(dt)
	if state.dead > 0.0:
		return
	_update_clone(dt)
	_update_shots(dt)
	# effect hook: Rage-thrown bodies that slam into a wall (story_hero.check_slam, here and in
	# hell_monsters.gd) leave the crypt's wall slam instead of the relics' violet quake ring
	var slams := _slams_before()
	_update_mobs(dt)
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
	_update_zones(dt)
	_update_hazards(dt)
	if frost_snow != null:
		frost_snow.update(dt)
	_update_rooms()
	_update_embers(dt)
	_update_camera(dt)


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


func _update_player(dt: float) -> void:
	var move := Vector2(_axis(KEY_A, KEY_D), _axis(KEY_W, KEY_S))
	if not dash.is_empty():
		move = Vector2.ZERO
	var here := _cell(int(floor(player.x / C)), int(floor((player.y - 6.0) / C)))
	var liquid: Dictionary = theme.liquid
	var slow: float = float(balance.player.lava_slow) if float(liquid.slow) < 0.0 else float(liquid.slow)
	var chill := float(theme.get("chill_speed", 1.0)) if state.chill > 0.0 else 1.0
	var speed := float(hero.get("speed", balance.player.speed)) * float(state.speed_mul) * chill * HeroKit.move_scale(self) * CardKit.speed_mult(self) * (slow if here == 2 else 1.0) * (0.5 if state.slow > 0.0 else 1.0) * FrostCombat.move_scale(self)
	player.moving = move != Vector2.ZERO and speed > 0.0
	var want := move.normalized() * speed if player.moving else Vector2.ZERO
	if feel != null and FrostCombat.HeroFx.slip(self) > 0.0:
		player.vel = (player.vel as Vector2).lerp(want, 1.0 - pow(0.08, dt))
	elif here == 2 and liquid.slide:
		# glaze ice: the hero keeps sliding; grip = share of the old speed left after one second
		player.vel = (player.vel as Vector2).lerp(want, 1.0 - pow(float(liquid.grip), dt))
	else:
		player.vel = want
	var v: Vector2 = player.vel * dt
	if v != Vector2.ZERO:
		if not box_blocked(_player_box(player.x + v.x, player.y)):
			player.x += v.x
		else:
			player.vel.x = 0.0
		if not box_blocked(_player_box(player.x, player.y + v.y)):
			player.y += v.y
		else:
			player.vel.y = 0.0
	if absf(move.x) > 0.0:
		player.face = signf(move.x)
	player.anim += dt * (10.0 if player.moving else 5.0)
	var aim := Vector2(_axis(KEY_LEFT, KEY_RIGHT), _axis(KEY_UP, KEY_DOWN))
	if aim != Vector2.ZERO:
		_fire(aim)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not state.get("tree_open", false) and throw_slot < 0 and (inventory_panel == null or not inventory_panel.open):
		_fire(get_global_mouse_position() - Vector2(player.x, player.y - 40))
	if here == 2 and liquid.hurt:
		_hurt("in der Lava verbrannt")
	for e: Dictionary in pits:
		if absf(player.x - e.x) < float(balance.pit.reach_x) and absf(player.y - 8.0 - e.y) < float(balance.pit.reach_y):
			_fall_into_pit()
			return


func _update_shots(dt: float) -> void:
	for s: Dictionary in shots:
		s.p += s.v * dt
		s.t -= dt
		var struck: Dictionary = {}
		for e: Dictionary in breakables:
			if not e.get("broken", false) and absf(s.p.x - e.x) < 50.0 and s.p.y > e.y - 90.0 and s.p.y < e.y + 10.0:
				struck = e
		if not struck.is_empty():
			s.t = 0.0
			_hit_breakable(struck, s.p)
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
			continue
		if s.get("kind", "") == "gravity":
			# the gravity ball drags enemies towards itself while it flies
			var ball: Dictionary = RelicKit.wielded(self).get("ball", theme.gravity_staff.ball)
			for m: Dictionary in mobs:
				var to: Vector2 = s.p - m.p
				if m.spawn <= 0.0 and not m.has("kit") and m.kind != "boss" and to.length() < float(ball.pull_radius) and to.length() > 10.0:
					var step: Vector2 = to.normalized() * float(ball.pull) * dt
					if not box_blocked(Rect2(m.p.x + step.x - m.r * 0.7, m.p.y + step.y - m.r * 0.7, m.r * 1.4, m.r * 0.7), true):
						m.p += step
		var big := float(s.get("big", 1.0))
		for m: Dictionary in mobs:
			# Ignaroth's rig: the shot must cross a part where it is drawn; the part takes the hit (src/hell/drake_rig_host.gd)
			var rigged: bool = drake_rig != null and drake_rig.has_rig(m)
			if _hittable(m) and not (s.get("hits", []) as Array).has(m) and (drake_rig.shot_hits(m, s.p - s.v * dt, s.p, 12.0 * big) if rigged else s.p.distance_to(m.p - Vector2(0, m.cy)) < m.r + 12.0 * big):
				# with the feel the hit is the crypt's alone (sparks, hit spark, drops: feedback.gd)
				if feel == null:
					_burst(s.p, 6)
				var mult := float(s.get("mult", 1.0))
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
		if not s.get("fist", false) and _cell_blocked(int(floor(s.p.x / C)), int(floor(s.p.y / C)), false):
			s.t = 0.0
			# the frost world's shard breaks on the wall into ice chips and rime (src/hell/frost_fx.gd)
			if frost_fx != null and str(s.get("style", "ice")) in ["ice", "frost"]:
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
				_hurt("von Feuer getroffen", 1, s.p)
				# a guardian's plain shot pushes the hero back and bursts into ice on him
				if frost_fx != null and int(state.hp) < before:
					frost_fx.hit_hero((s.p as Vector2) - (s.v as Vector2).normalized() * 40.0, "fist" if s.get("fist", false) else "shot", "small" if s.get("fist", false) else "tiny")
					frost_fx.shatter(s.p, 8, 14.0, (s.v as Vector2).normalized(), 120.0)
		if s.t <= 0.0 and s.has("end_pool"):
			FrostCombat.FrostMoves.shot_end(self, s)
	eshots = eshots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)


func _update_mobs(dt: float) -> void:
	if monsters != null:
		monsters.update(dt)
		if pools != null:
			pools.sync(monsters.pool_entries(), float(state.t))
		return
	var me := Vector2(player.x, player.y)
	var hidden := float(state.get("stealth", 0.0)) > 0.0
	for m: Dictionary in mobs:
		if m.spawn > 0.0:
			m.spawn -= dt
			continue
		m.hit = maxf(0.0, m.hit - dt)
		if hidden and m.kind != "boss":
			# hidden hero: they stop, look about and turn their backs now and then
			m.face = Vector2(cos(state.t * 1.5 + m.seed), sin(state.t * 1.5 + m.seed))
			continue
		# taunting allies (bone colossus, great bear) draw enemies away from the hero
		var goal := SubKit.chase(self, m, me)
		if talents != null: goal = talents.chase_goal(m, goal)
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
				# runs like the others, now and then a straight dash at the hero
				m.dash_t -= dt
				if m.dash > 0.0:
					m.dash -= dt
					v = m.dash_dir * float(def.dash_speed)
				elif m.dash_t <= 0.0:
					m.dash_t = float(def.dash_every)
					m.dash = float(def.dash_time)
					m.dash_dir = dir
					if sound != null:
						sound.on_attack(m, "dasher")
			"puller":
				if d < float(def.pull_radius):
					var pull: Vector2 = -dir * float(def.pull) * dt
					if not box_blocked(_player_box(player.x + pull.x, player.y)):
						player.x += pull.x
					if not box_blocked(_player_box(player.x, player.y + pull.y)):
						player.y += pull.y
		for o: Dictionary in mobs:
			if o != m:
				var off: Vector2 = m.p - o.p
				var od := off.length()
				if od > 0.0 and od < m.r + o.r:
					v += off / od * 120.0
		if m.get("hold", false) or m.get("mv_hold", false):
			v = Vector2.ZERO
		v *= HeroKit.tick_mob(self, m, dt)
		v += m.k
		m.k *= 0.86
		var moved_from: Vector2 = m.p
		var rr: float = m.r * 0.7
		var avoid: bool = m.kind != "boss"
		var nx: Vector2 = m.p + Vector2(v.x * dt, 0)
		if not box_blocked(Rect2(nx.x - rr, nx.y - rr, rr * 2, rr), avoid) and not HeroKit.wall_blocks(self, nx, rr):
			m.p = nx
		var ny: Vector2 = m.p + Vector2(0, v.y * dt)
		if not box_blocked(Rect2(ny.x - rr, ny.y - rr, rr * 2, rr), avoid) and not HeroKit.wall_blocks(self, ny, rr):
			m.p = ny
		if m.has("slam"):
			as_source("hero", func() -> void: story_hero.check_slam(m, moved_from, dt))
		if d < m.r + 22.0 and goal == me:
			var who: String = ("von %s erwischt" % def.name) if def.has("name") else "von Glutlingen verbrannt"
			_hurt("von %s erschlagen" % W.boss.name if m.kind == "boss" else who, 1, m.p)
			if def.has("chill"):
				state.chill = float(def.chill)
		if m.kind == "spucker" or beh == "shooter":
			m.shoot -= dt
			if m.shoot <= 0.0:
				m.shoot = float(def.fire_every)
				_enemy_shot(m.p - Vector2(0, 40), to - Vector2(0, 30), float(def.get("shot_speed", balance.enemy_shot.speed)))
				# the crypt's attack sound of its kind (story_sound.gd), else the theme's
				if sound != null:
					sound.on_attack(m, "shooter")
				else:
					_sound("enemy_shot")
		elif beh == "turret":
			m.shoot -= dt
			if m.shoot <= 0.0:
				m.shoot = float(def.fire_every)
				var fan := int(def.fan)
				for k in range(fan):
					var a: float = dir.angle() + (float(k) / maxf(1.0, fan - 1.0) - 0.5) * float(def.spread)
					_enemy_shot(m.p - Vector2(0, m.cy), Vector2(cos(a), sin(a)), float(def.shot_speed))
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
						_enemy_shot(m.p - Vector2(0, 70), Vector2(cos(a), sin(a)), float(balance.enemy_shot.ring_speed))
	for m: Dictionary in mobs.duplicate():
		if m.hp > 0.0 or (m.has("kit") and BossKit.next_phase(self, m)):
			continue
		# with the feel the kill is the crypt's alone (burst in its material, pool, sheet: feedback.gd)
		if feel == null:
			_burst(m.p - Vector2(0, 30), 70 if m.kind == "boss" else 16)
		mobs.erase(m)
		# with the feel the kill sounds in the crypt material (feedback.gd via FrostCombat.after_kill)
		if feel == null:
			_sound("kill_" + str((m.def as Dictionary).get("material", "void")))
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
	# effect hook: with the feel the mage's splash is the crypt's area perk (perk_events blast:
	# feedback.gd's magic burst in the staff's glow, its sound, the gold ring), not the world's circle
	if feel != null and str(s.get("kind", "")) == "magic":
		feel.perk("blast", s.p)
		return
	fx.append({"kind": "blast", "p": s.p, "r": radius, "t": 0.3, "max": 0.3, "gravity": s.get("kind", "") in ["gravity", "rock"], "shot": s.get("kind", "")})
	if int(s.get("split", 0)) > 0:
		RelicKit.split_rock(self, s)
	_burst(s.p, 18)
	_sound("blast")


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
			"spikes":
				e.up = int(state.t / float(hz.spike_period)) % 2 == int(e.phase)
				if e.up and absf(me.x - e.x) < 42 and absf(me.y - 12 - e.y) < 40:
					_hurt("von Stacheln getroffen")
			"vent":
				e.burst = fmod(state.t + float(e.offset), float(hz.vent_period)) < float(hz.vent_burst)
				if e.burst and me.distance_to(Vector2(e.x, e.y)) < float(hz.vent_radius):
					_hurt("vom Glutschlot verbrannt")
				if e.burst and randf() < 0.6:
					embers.append({"p": Vector2(e.x + randf_range(-20, 20), e.y - 10), "v": Vector2(randf_range(-20, 20), randf_range(-280, -160)), "t": 0.8, "big": true, "gold": false})
			"plate":
				if e.get("on", false) or absf(me.x - e.x) > 44 or absf(me.y - 10 - e.y) > 44:
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
						_toast("Falsche Reihenfolge. Die Platten erlöschen.")
				else:
					e.on = true
					var p := Rules.group_progress(W.ents, e.group)
					if p.x == p.y:
						_solve_group(e.group)
					else:
						_toast("Runenplatte %d von %d aktiviert." % [p.x, p.y])
			"key", "heart", "gem":
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
					_toast("%s aufgehoben." % key_name[e.key])
				elif e.type == "heart":
					state.hp = mini(state.max_hp, state.hp + 2)
					# effect hook: the crypt's heal marker over the hero
					if feel != null:
						feel.hero_perk("heal")
					_toast("+1 Herz")
				else:
					state.gems += 1
				# the crypt's pickup: its loot_taken fx event (the pickup sheet and its chime through feedback.gd)
				if feel != null:
					feel.fx_event("loot_taken", Vector2(e.x, e.y))


func _update_rooms() -> void:
	var ri := _room_at_world(player.x, player.y - 12.0)
	if ri >= 0 and ri != state.room:
		state.room = ri
		state.visited[ri] = true
		state.banner = {"text": W.rooms[ri].name, "sub": W.rooms[ri].kind, "t": 0.0}
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


## Now and then a lava pool in view sloshes over its rim onto the floor
## (hell_balance.json monsters.feel.lava "slosh_rate" per second): a few drops
## of lava as glowing pixels that lie there as embers and cool to soot
## (hell_monsters.gd lava_splash). Only where a lava cell borders the floor.
func _slosh_lava(dt: float) -> void:
	if monsters == null or not theme.liquid.get("hurt", false):
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


func _update_camera(dt: float) -> void:
	var r: Dictionary = W.rooms[state.room]
	var target := Vector2(player.x, player.y - 40)
	var view := Vector2(float(balance.view.width), float(balance.view.width) * 9.0 / 16.0)
	if _room_at_world(player.x, player.y - 12.0) >= 0:
		var lo := Vector2(r.bx * C - 70, r.by * C - 110)
		var hi := Vector2((r.bx + r.bw) * C + 70, (r.by + r.bh) * C + 80)
		for axis in [0, 1]:
			if hi[axis] - lo[axis] <= view[axis]:
				target[axis] = (lo[axis] + hi[axis]) / 2.0
			else:
				target[axis] = clampf(target[axis], lo[axis] + view[axis] / 2.0, hi[axis] - view[axis] / 2.0)
	camera.position = camera.position.lerp(target, 1.0 - pow(0.0015, dt))
	# the shake: layered sines at uneven rates (smooth, self-ending as state.shake decays),
	# never a fresh random offset per frame, which buzzes (game feel: trauma shake)
	var st := float(state.t) * 30.0
	camera.offset = Vector2(0.6 * sin(st * 1.7 + 1.3) + 0.4 * sin(st * 3.1 + 2.6), 0.6 * sin(st * 2.3 + 4.1) + 0.4 * sin(st * 3.7 + 0.7)) * state.shake


# ---------- world drawing ----------

## Draws one layer: static chunks (back/front), live actors, or the monsters' attack
## shapes (the darkness and the bloom over it: src/hero/story_glow.gd).
func draw_layer(l: Layer) -> void:
	match l.kind:
		"back": _draw_back(l)
		"front": _draw_front(l)
		# the wall snow layers; a set with snow in its drawings (theme baked_snow) needs none
		"snow_ao", "snow_lip", "snow_front":
			if not frost_snow.baked():
				frost_snow.walls.draw(l, l.area, l.kind.trim_prefix("snow_"))
		"actors": _draw_actors(l)
		"glow":
			if monsters != null:
				monsters.draw_fx(l)


func _tex(ci: CanvasItem, name: String, pos: Vector2, flip := false, tint := Color.WHITE, scale := 1.0) -> void:
	var t: Texture2D = tex.get(name)
	if t == null:
		return
	var size := t.get_size() * scale
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
			if t == 2 or t == 3:
				var lt: Texture2D = tex.lava_01 if (x * 7 + y * 13) % 10 > 6 else lava
				if tiles_1to1:
					l.draw_texture(lt, r.position)
				else:
					l.draw_texture_rect_region(lt, r, Rect2(14, 14, 68, 68))
			else:
				l.draw_texture(tex[W.tile_names[W.tiles[i]]], Vector2(x * C, y * C))
	var rim: Texture2D = tex.lava_edge_top
	for y in range(y0, mini(y0 + CHUNK.y, W.rows)):
		for x in range(x0, mini(x0 + CHUNK.x, cols)):
			var t := _cell(x, y)
			if t != 2 and t != 3:
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
	for d: Dictionary in W.decals:
		if not a.has_point(Vector2(d.x, d.y)):
			continue
		var t: Texture2D = tex[d.name]
		var size := Vector2(d.w, d.h) if float(d.w) > 0.0 else t.get_size()
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
		if a.has_point(Vector2(w.x, w.y + 74)):
			var t: Texture2D = tex[w.name]
			_tex(l, w.name, Vector2(w.x - t.get_width() / 2.0, w.y), w.flip)


func _draw_front(l: Layer) -> void:
	for w: Dictionary in walls.south:
		if w.y - 1.0 >= l.area.position.y and w.y - 1.0 < l.area.end.y and w.x1 > l.area.position.x and w.x0 < l.area.end.x:
			_strip(l, w, l.area)


func _view_rect() -> Rect2:
	var size := Vector2(float(balance.view.width), float(balance.view.width) * 9.0 / 16.0)
	return Rect2(camera.position - size / 2.0, size)


func _draw_actors(l: Layer) -> void:
	var view := _view_rect().grow(220)
	var t: float = state.t
	FrostCombat.draw_under(self, l, t)
	# footprints in the snow and skid marks on the ice, under everyone (src/hero/frost_snow.gd)
	if frost_snow != null:
		frost_snow.draw_ground(l, view)
		frost_snow.draw_floor(l, view)
		frost_snow.draw_chips(l)
	if talents != null: talents.draw_world(l, t)
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
				var size := im.get_size() - Vector2(0, 0 if up else 16)
				l.draw_texture_rect(im, Rect2(Vector2(e.x, e.y + (0 if up else 8)) - im.get_size() / 2.0, size), false, Color(1, 1, 1, 1.0 if up else 0.3))
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
	if monsters != null:
		monsters.draw_warnings(l)
	var list: Array = []
	for p: Dictionary in W.props:
		if p.name != "" and view.has_point(Vector2(p.x, p.y)):
			list.append([p.y - (200.0 if p.low else 0.0), "prop", p])
	for e: Dictionary in W.ents:
		if view.has_point(Vector2(e.x, e.y)) and e.type in ["chest", "vault", "portal", "brazier", "key", "heart", "gem", "relic", "well", "npc", "stairs"] and not e.get("taken", false):
			list.append([e.y - (60.0 if e.type == "stairs" else 0.0), "ent", e])
		elif e.type == "lever" and view.has_point(Vector2(e.x, e.y)):
			list.append([float(e.wy), "ent", e])
	# an opened boss gate stays as a wide arch over the doorway
	for d: Dictionary in W.doors:
		if d.get("boss_gate", false) and tex.has("boss_arch") and view.has_point(Vector2(d.cx, d.cy)) and not _door_closed(d):
			list.append([float(d.y0) * C, "arch", d])
	for e: Dictionary in breakables:
		if view.has_point(Vector2(e.x, e.y)):
			list.append([e.y - (200.0 if e.get("broken", false) else 0.0), "breakable", e])
	if not clone.is_empty():
		list.append([clone.p.y, "clone", clone])
	for d: Dictionary in W.doors:
		if d.kind != "secret" and view.has_point(Vector2(d.cx, d.cy)) and _door_closed(d):
			list.append([d.cy + 60.0, "gate", d])
	for m: Dictionary in mobs:
		if view.grow(300 if monsters != null else 0).has_point(m.p):
			list.append([m.p.y, "mob", m])
	# felled monsters without a death animation fall and fade like the crypt's (src/hero/story_feel.gd)
	if feel != null:
		for m: Dictionary in feel.fallen():
			if view.has_point(m.p):
				list.append([m.p.y, "mob", m])
	if monsters != null:
		for c: Dictionary in monsters.corpses:
			if view.has_point(c.p):
				list.append([c.p.y, "corpse", c])
	list.append([player.y, "hero", player])
	list.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for item: Array in list:
		# The shallow depression belongs behind the object. Foreground snow is fitted to the real
		# lower silhouette (baked into substantial props, drawn here only for tiny loose items).
		if frost_snow != null and item[1] in ["prop", "ent", "breakable"]:
			frost_snow.draw_foot_under(l, item[1], item[2])
		match item[1]:
			"prop":
				var p: Dictionary = item[2]
				var im: Texture2D = tex[p.name]
				_tex(l, p.name, Vector2(p.x - im.get_width() / 2.0, p.y - im.get_height()), p.flip)
			"ent": _draw_ent(l, item[2], t)
			"gate": _draw_gate(l, item[2], t)
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
	# the cuts' chips, embers and flashes over the actors
	if drake_rig != null:
		drake_rig.draw_over(l)
	if frost_rigs != null:
		frost_rigs.draw_over(l)
	# the monsters' pixel lasers in their own colours over the actors (their glow is the bloom)
	if monsters != null:
		monsters.draw_lasers(l)
	_draw_skill_fx(l, t)
	RelicKit.draw(self, l, t)
	SubKit.draw(self, l, t)
	# effect hook: with the feel the hero's conditions are the crypt's (boss_fx.gd on the feel's layer)
	if feel == null:
		FrostCombat.draw_over(self, l, t)
	# the frost world's ice shards, hail, armour and impact flashes on the pixel grid (src/hell/frost_fx.gd)
	elif frost_fx != null:
		FrostCombat.FrostMoves.draw_over(self, l, t)
	for s: Dictionary in shots:
		if SubKit.draw_shot(self, l, s, t):
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
			l.draw_set_transform(s.p, t * 8.0)
			l.draw_texture_rect(rock, Rect2(-rock.get_size(), rock.get_size() * 2.0), false)
			l.draw_set_transform(Vector2.ZERO)
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
			l.draw_set_transform(s.p, (s.v as Vector2).angle() + PI / 2.0)
			l.draw_texture_rect(arrow_tex, Rect2(-asz / 2.0, asz), false)
			l.draw_set_transform(Vector2.ZERO)
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
			l.draw_rect(Rect2(at, Vector2(w * clampf(m.hp / m.max, 0.0, 1.0), 6)), Color("#ff5d73") if float(m.get("burn_t", 0.0)) <= 0.0 else Color("#ffaa55"))
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
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()), Color(0.45, 0.45, 0.5) if e.get("used", false) else Color.WHITE)
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
				l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
			else:
				var cut := 46.0
				l.draw_texture_rect_region(im, Rect2(e.x - im.get_width() / 2.0, e.y - im.get_height() + cut, im.get_width(), im.get_height() - cut), Rect2(0, cut, im.get_width(), im.get_height() - cut))
		"key", "heart", "gem":
			var name: String = "rune_gem" if e.type == "gem" else (key_sprite[e.key] if e.type == "key" else e.type)
			var im: Texture2D = tex[name]
			var s := 0.9 if e.type == "key" else (0.55 if e.type == "gem" else 0.7)
			var bob := sin(t * 3.0 + e.x) * 6.0
			var size := im.get_size() * s
			l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y - 10 + bob), size), false, key_tint.get(e.get("key", ""), Color.WHITE))


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
			l.draw_texture_rect(tex[key_sprite[d.key]], Rect2(d.cx - 15, bottom - gate.get_height() * 0.52, 30, 56), false, key_tint[d.key])
		return
	var im: Texture2D = tex.portcullis
	l.draw_set_transform(Vector2(d.cx, d.cy), PI / 2 if d.dir == "h" else 0.0)
	var fight: bool = W.rooms[d.a].fight or W.rooms[d.b].fight
	var tint := Color.WHITE
	if fight or d.kind == "boss":
		tint = Color(1.0 + 0.4 * (0.5 + 0.5 * sin(t * 5.0)), 0.75, 0.7)
	l.draw_texture(im, -im.get_size() / 2.0, tint)
	l.draw_set_transform(Vector2.ZERO)
	if not fight and d.kind == "lock":
		l.draw_texture_rect(tex[key_sprite[d.key]], Rect2(d.cx - 15, d.cy - 30, 30, 56), false, key_tint[d.key])
	elif not fight and d.kind == "puzzle":
		var icon: Texture2D = tex.brazier_bowl if W.groups[d.group].kind == "braziers" else tex.icon_scroll
		l.draw_texture_rect(icon, Rect2(d.cx - 22, d.cy - 30, 44, 44 * icon.get_height() / icon.get_width()), false)


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
	l.draw_texture_rect(im, Rect2(m.p - Vector2(size.x / 2.0, size.y + 14 - bob), size), false, tint)
	if m.kind == "boss":
		var icon: Texture2D = tex.icon_demon_big if W.final else tex.icon_demon
		var k := s / 2.7
		l.draw_texture_rect(icon, Rect2(m.p.x - 46 * k, m.p.y - size.y - 4 + bob, 92 * k, 96 * k), false)


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
	var pose: Dictionary = feel.pose(m) if feel != null else {}
	var size := im.get_size() * float(m.ds) * grow * (pose.get("scale", Vector2.ONE) as Vector2)
	var tint := Color(1.6, 1.8, 2.2) if m.dash > 0.0 else _color(m.get("tint", [1, 1, 1]))
	if pose.is_empty():
		tint = Color(3, 3, 3) if m.hit > 0.0 else tint
	else:
		tint.a *= float(pose.alpha)
	if float(m.get("inv", 0.0)) > 0.0:
		tint.a = 0.45 + 0.35 * sin(t * 30.0)
	var feet: Vector2 = m.p + (pose.get("offset", Vector2.ZERO) as Vector2)
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
	_sound("hit_bone")
	_toast("Der Schneemann erwacht! Die Gitter fallen.")


## The Frostgruft's trap (tex ice_crack / ice_burst): a thin crack in the ice at rest; when it fires
## an ice burst shoots up out of it (quick rise, then it stands and shimmers until it sinks back).
func _draw_ice_trap(l: Layer, e: Dictionary, up: bool) -> void:
	var period := float(balance.hazards.spike_period)
	_draw_ice_burst(l, Vector2(e.x, e.y), fmod(float(state.t), period) if up else -1.0, 0.55)


## A crack in the snow (tex ice_crack) and, `since` s after it broke open (negative: closed), the
## ice bursting up out of it (tex ice_burst): a quick rise, then it stands and shimmers. `scale`
## sizes it (the ice geysers erupt bigger than the spike traps).
func _draw_ice_burst(l: Layer, at: Vector2, since: float, scale: float) -> void:
	var crack: Texture2D = tex.ice_crack
	l.draw_texture_rect(crack, Rect2(at - crack.get_size() * scale / 2.0, crack.get_size() * scale), false)
	if since < 0.0:
		return
	var rise := clampf(since / 0.12, 0.0, 1.0)
	var burst: Texture2D = tex.ice_burst
	var size := burst.get_size() * scale * Vector2(1.0, rise)
	var shimmer := 0.85 + 0.15 * sin(float(state.t) * 18.0 + at.x)
	l.draw_texture_rect(burst, Rect2(Vector2(at.x - size.x / 2.0, at.y + 8.0 - size.y), size), false, Color(1.0, 1.0, 1.0, shimmer))


func _draw_hero(l: Layer, t: float) -> void:
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
	body.call(Vector2(player.x, player.y), 1.0)
	_draw_weapon(l, size)


## The class weapon in the hero's hand: bow and staff held upright, the sword
## swept through its arc while a swing lasts; the gravity staff glows violet.
func _draw_weapon(l: Layer, hero_size: Vector2) -> void:
	if relic_on() and relic_tex != null:
		var rel := RelicKit.wielded(self)
		var rk := float(theme.get("weapon_scale", 2.0))
		var rsz := relic_tex.get_size() * rk
		var rhand := Vector2(player.x + float(player.face) * hero_size.x * 0.32, player.y - hero_size.y * 0.38)
		var tilt := 0.0
		if rel.has("attack") and swing.t > 0.0:
			# the hammer comes down through its arc
			tilt = float(swing.a) + PI / 2.0 + float(rel.attack.arc) * (0.5 - swing.t / 0.22)
			l.draw_set_transform(Vector2(player.x, player.y - 40), tilt)
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
	var hand := Vector2(player.x + float(player.face) * hero_size.x * 0.32, player.y - hero_size.y * 0.38)
	if weapon.type == "melee" and swing.t > 0.0:
		var a: float = swing.a + float(weapon.arc) * (0.5 - swing.t / 0.16)
		var tip := Vector2(cos(a), sin(a))
		l.draw_line(Vector2(player.x, player.y - 40) + tip * 30.0, Vector2(player.x, player.y - 40) + tip * float(weapon.reach), Color(col("shot_core"), 0.5), 6.0)
		l.draw_set_transform(Vector2(player.x, player.y - 40), a + PI / 2.0)
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
	# the hero strip top left, the same in every world (src/ui/hud_kit.gd): hearts
	# with the level beside them, the EXP line, keys, rune stones, braziers, clone, blessings
	var resources: Array = []
	for k in ["A", "B", "C"]:
		resources.append({"icon": tex[key_sprite[k]], "tint": key_tint[k], "dim": not state.keys[k]})
	resources.append({"icon": tex.rune_gem, "text": str(int(state.gems))})
	var fire := Rules.group_progress(W.ents, "feuer")
	if fire.y > 0:
		resources.append({"icon": tex.brazier_bowl, "text": "%d/%d" % [fire.x, fire.y], "dim": fire.x >= fire.y})
	var status: Array = []
	var sk: Dictionary = state.skill
	if sk.owned:
		var clock := "%d:%02d" % [int(sk.left) / 60, int(sk.left) % 60]
		var label := ("KLON AKTIV · " + clock) if sk.active else (("Q · KLON RUFEN · " + clock) if sk.left > 0.0 else "KLON AUFGEBRAUCHT")
		status.append({"text": label, "color": HudStyle.color("accent") if sk.active else (HudStyle.color("text_dim") if sk.left > 0.0 else HudStyle.color("text_muted"))})
	if not (state.buffs as Array).is_empty():
		var names: Array = (state.buffs as Array).map(func(b: String) -> String: return b.get_slice(":", 0))
		status.append({"text": "SEGEN · " + ", ".join(PackedStringArray(names)).to_upper(), "color": HudStyle.color("text_dim")})
	# the Frostgruft's conditions on the hero (poison, slow ...), each in its colour
	status.append_array(FrostCombat.status_lines(self))
	var leveled := not skills.is_empty()
	var need := maxf(1.0, float(HeroKit.need(theme.leveling, int(state.level)))) if leveled else 1.0
	HudKit.hero_panel(h, FONT, Vector2(HudStyle.size("margin"), HudStyle.size("margin")), {"title": "P1 · " + str(hero.get("name", class_id)).to_upper(),
		"points": RunTree.points_left(CardKit.tree(self), CardKit.ranks(self), int(state.level)) if leveled else 0,
		"hp": int(state.hp), "max_hp": int(state.max_hp), "hearts": hearts, "level": int(state.level) if leveled else -1,
		"exp": float(state.exp) / need if leveled else -1.0, "resources": resources, "status": status,
		"low": int(state.hp) <= 2 and int(state.hp) > 0, "clock": float(state.t)})
	# no help line at the bottom: controls and goals live in the pause menu (Esc)
	if not skills.is_empty():
		_draw_skill_bar(h, size)
	var boss_mob: Dictionary = {}
	for m: Dictionary in mobs:
		if m.kind == "boss":
			boss_mob = m
	# the banner moves below the guardian's bar while it stands
	var b: Dictionary = state.banner
	var ba := clampf(b.t / 0.4, 0.0, 1.0) if b.t < 2.6 else maxf(0.0, 1.0 - (b.t - 2.6) / 0.8)
	var banner_y := 96.0 if boss_mob.is_empty() else 112.0
	FrostHud.banner(self, h, size, banner_y)
	if not boss_mob.is_empty():
		# the guardian's bar at the top centre, the same in every world (src/ui/hud_kit.gd)
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
		HudKit.boss_bar(h, FONT, size, {"name": title.to_upper(), "tag": "WÄCHTER DER ETAGE", "segments": segments,
			"ratio": clampf(left_hp / maxf(1.0, total), 0.0, 1.0), "flash": 1.0 if float(boss_mob.get("inv", 0.0)) > 0.0 else 0.0,
			"value": "%d %%" % int(ceil(left_hp / maxf(1.0, total) * 100.0))})
	# the floor panel top right: floor, its name, the fight state; the mini-map inside it
	var cr: Dictionary = W.rooms[state.room]
	var locked := 0
	if cr.fight:
		for m: Dictionary in mobs:
			if m.room == cr.index:
				locked += 1
	var map_area := HudKit.floor_panel(h, FONT, size, {"title": "ETAGE %d" % int(state.floor), "subtitle": str(W.title).to_upper(),
		"tag": ("VERRIEGELT · %d" % locked) if cr.fight else "ERKUNDEN", "tag_color": HudStyle.color("danger") if cr.fight else HudStyle.color("text_dim")})
	HudKit.menu_chip(h, FONT, size, "ESC · MENÜ", 1.0, HudKit.menu_rect(size).has_point(h.get_local_mouse_position()))
	var n := _nearest()
	if not n.is_empty() and state.dead <= 0.0 and not state.won:
		HudKit.prompt(h, FONT, _to_screen(n.p, size) - Vector2(0, 70), "E", say(n.label))
	var toasts: Array = state.toasts
	for i in range(toasts.size()):
		var tt: Dictionary = toasts[i]
		# hints stack above the skill bar, the same in every world (src/ui/hud_kit.gd)
		var bottom := SkillBar.top(size, false) - 28.0 if not skills.is_empty() else size.y - 40.0
		HudKit.toast(h, FONT, size, bottom - (toasts.size() - 1 - i) * 40.0, str(tt.text), minf(1.0, tt.t * 2.0))
	if theme.placeholder_note:
		_text(h, "Figur: Platzhalter" if monsters != null else "Figur und Gegner: Platzhalter", Vector2(20, size.y - 14), 16, Color(ink, 0.45))
	if state.dead > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0, 0, 0.55))
	_draw_map(h, size, state.map, false, map_area)
	# the goal list sits in the pause menu now; finished goals still ring and show a note
	FrostHud.track(self)
	if theme.get("styled_hud", false) and not state.map and not state.won:
		if state.get("status", false):
			FrostHud.status(self, h, size)
	# the run talent tree window (B), the same in every world
	if state.get("tree_open", false) and not skills.is_empty():
		RunTreeView.draw(h, FONT, size, CardKit.tree(self), CardKit.ranks(self), int(state.level), {"title": str(hero.get("name", class_id)), "mouse": h.get_local_mouse_position()})
	# floor won, run over: the result panel every world shares (src/ui/hud_kit.gd)
	var over: Dictionary = state.get("over", {})
	if not over.is_empty():
		HudKit.result_panel(h, FONT, size, run_result(over))
	elif state.won:
		var note := _floor_reward
		HudKit.result_panel(h, FONT, size, {"title": "ETAGE %d GESCHAFFT" % int(state.floor), "tone": "floor",
			"lines": [["RÄUME ERKUNDET", "%d / %d" % [state.visited.size(), W.rooms.size()]], [say("RUNENSTEINE"), str(int(state.gems))],
				["HERZEN", "%d" % (int(state.max_hp) / 2)], ["LEVEL", str(int(state.level))]],
			"note": note, "hints": "E · WEITER ZU ETAGE %d" % (int(state.floor) + 1)})
	elif not stairs_pick.is_empty():
		# the hidden stairs: every earlier floor, in a new world
		var lines: Array = []
		for fn: int in stairs_pick.floors:
			lines.append(["TASTE %d" % fn, "ETAGE %d · %s" % [fn, str(world.pack.floors[fn].title).to_upper() if world != null else ""]])
		HudKit.result_panel(h, FONT, size, {"title": "VERGESSENE STIEGE", "tone": "floor", "lines": lines,
			"note": "Die Welt wird neu gewürfelt. Herzen, Steine, Level und Gegenstände bleiben.", "hints": "1-%d · ETAGE WÄHLEN   E · BLEIBEN" % (stairs_pick.floors as Array).size()})


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
	# level and EXP sit with the hearts at the top (draw_hud), as in every world
	SkillBar.draw(h, FONT, size, slots, float(state.t), {"mouse": h.get_local_mouse_position()})
	# the talent bar (Shift + 1-4, R) above the skill bar, the same in every map
	if talents != null: talents.draw_hud(h, size, SkillBar.top(size, false) - 74.0)



func _text(h: CanvasItem, text: String, pos: Vector2, font_size: int, color: Color, center_width := -1.0) -> void:
	if center_width > 0.0:
		h.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, center_width, font_size, color)
	else:
		h.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _to_screen(world: Vector2, screen: Vector2) -> Vector2:
	return (world - camera.position) * camera.zoom + screen / 2.0


func _door_color(d: Dictionary) -> Color:
	if W.rooms[d.a].fight or W.rooms[d.b].fight:
		return Color("#d8382a")
	if d.kind == "lock" and not d.unlocked:
		return key_color[d.key]
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
		if icon == "" or (not seen and r.type != "boss"):
			continue
		var im: Texture2D = tex[key_sprite[r.icon_key] if icon == "key" and key_sprite.has(r.icon_key) else icon]
		var c := origin + Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0) * s
		var sz := Vector2(isz, isz * im.get_height() / im.get_width())
		h.draw_texture_rect(im, Rect2(c - sz / 2.0, sz), false, key_tint.get(r.icon_key, Color.WHITE))
		var room_w: float = r.bw * s
		if big and FONT.get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < room_w:
			_text(h, r.name, Vector2(c.x - room_w / 2.0, c.y + isz * 0.9), 16, ink, room_w)
	if big and not framed:
		_text(h, "Hell: besucht · Türen rot: verriegelt · farbig: Schlüssel · gelb: Rätsel · M schließt", Vector2(0, screen.y - 12), 16, Color("#b89c8e"), screen.x)
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

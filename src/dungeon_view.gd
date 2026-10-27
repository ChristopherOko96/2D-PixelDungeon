extends Node2D
## Pixel chamber presentation for Basement Run. Receives authoritative state;
## owns no combat, movement, rewards, or networking decisions.

const ROOM_SIZE := Vector2(896, 480)
const INK := Color("#10101c")
const GOLD := Color("#efc76a")
const MUTED := Color("#77728b")
const PLAYER_COLORS := [
	Color("#72dcc8"), Color("#edb563"), Color("#bc91de"), Color("#ed8a91")
]
# Room shell from 0x72 DungeonTileset II: 16 px tiles drawn at 2x on the 32 px grid.
const FLOOR_TILES := [
	preload("res://assets/sprites/0x72/floor_1.png"), preload("res://assets/sprites/0x72/floor_2.png"),
	preload("res://assets/sprites/0x72/floor_3.png"), preload("res://assets/sprites/0x72/floor_4.png"),
	preload("res://assets/sprites/0x72/floor_5.png"), preload("res://assets/sprites/0x72/floor_6.png"),
	preload("res://assets/sprites/0x72/floor_7.png"), preload("res://assets/sprites/0x72/floor_8.png")
]
const WALL_FACE := preload("res://assets/sprites/0x72/wall_mid.png")
const WALL_FACE_HOLES := [preload("res://assets/sprites/0x72/wall_hole_1.png"), preload("res://assets/sprites/0x72/wall_hole_2.png")]
# Only the bottom 4 source rows are drawn: the lit top edge of a wall seen from above.
const WALL_CAP := preload("res://assets/sprites/0x72/wall_top_mid.png")
# Vertical wall edges; the 5 px strip sits on the left / right of the 16 px tile.
const EDGE_STRIP_LEFT := preload("res://assets/sprites/0x72/wall_edge_mid_left.png")
const EDGE_STRIP_RIGHT := preload("res://assets/sprites/0x72/wall_edge_mid_right.png")
const DOOR_CLOSED := preload("res://assets/sprites/0x72/doors_leaf_closed.png")
const DOOR_OPEN := preload("res://assets/sprites/0x72/doors_leaf_open.png")
# Wall torch from Dungeon Tileset II Extended, 16 x 24 px per frame.
const TORCH_FRAMES := [
	preload("res://assets/sprites/0x72_extended/wall_torch_anim_f0.png"), preload("res://assets/sprites/0x72_extended/wall_torch_anim_f1.png"),
	preload("res://assets/sprites/0x72_extended/wall_torch_anim_f2.png"), preload("res://assets/sprites/0x72_extended/wall_torch_anim_f3.png"),
	preload("res://assets/sprites/0x72_extended/wall_torch_anim_f4.png"), preload("res://assets/sprites/0x72_extended/wall_torch_anim_f5.png"),
	preload("res://assets/sprites/0x72_extended/wall_torch_anim_f6.png"), preload("res://assets/sprites/0x72_extended/wall_torch_anim_f7.png")
]
const TORCH_X := [104.0, 296.0, 600.0, 792.0]
## 0x72 wall banners; each floor theme names its colour (balance.themes).
const BANNERS := {"red": preload("res://assets/sprites/0x72/wall_banner_red.png"), "blue": preload("res://assets/sprites/0x72/wall_banner_blue.png"),
	"green": preload("res://assets/sprites/0x72/wall_banner_green.png"), "yellow": preload("res://assets/sprites/0x72/wall_banner_yellow.png")}
const BANNER_X := [200.0, 696.0]
const CRACK_GLOW := Color("#ff5a20")
const MOSS_DARK := Color("#4f7a2e")
const MOSS_LIGHT := Color("#7fa848")
const GOLD_INLAY := Color("#e8c152")
const COBWEB := Color("#c8d4e4")
## The visible world area, matching game.gd's WORLD_SIZE.
const VIEW_SIZE := Vector2(896, 480)
## Tile codes of big floor maps (floor_map_generator.gd).
const FloorMap = preload("res://src/dungeon/floor_map_generator.gd")
# Top of a wall, the dark mass behind its lit edges.
const WALL_TOP := Color("#1a1621")
# Door marker for an ordinary room; boss and treasure rooms get their own colour.
const DOOR_PLAIN := Color("#796171")
const BAR := Color("#aa8d7a")
const BAR_LIGHT := Color("#d3bfa9")
const BAR_INK := Color("#222222")

# 0x72 DungeonTileset II characters (16 px wide), drawn at an integer 2x scale.
# Index matches PLAYER_COLORS, so each player colour keeps its own hero.
const HERO_SPRITES := ["knight_m", "elf_f", "wizzard_m", "lizard_m"]
# Hero class -> sprite; players without a class fall back to their colour.
const CLASS_SPRITES := {"swordsman": "knight_m", "archer": "elf_f", "mage": "wizzard_m"}
# Weapon id -> 0x72 sprite (drawn blade-up in the art).
const WEAPON_SPRITES := {"sword": "weapon_regular_sword", "greatsword": "weapon_lavish_sword", "bow": "weapon_bow", "longbow": "weapon_bow_2",
	"staff": "weapon_green_magic_staff", "firestaff": "weapon_red_magic_staff"}
const ARROW_TEXTURE := preload("res://assets/sprites/0x72/weapon_arrow.png")
# Goblins and orcs: one standing figure each, cut by scripts/slice_orc_sheets.py;
# they move through the feedback layer's poses (breath, hop, windup, turn).
const ORC_ROOT := "res://assets/sprites/orcs/"
## Kinds drawn from full 5-row sheets (kind -> [folder under assets/sprites,
## sheet, pixel scale]). Idle and run come from 0x72 models (the bosses add
## pixel parts to them); attack, hit and death are derived from those frames.
const SHEET_KINDS := {"shooter": ["orcs_0x72", "orc_shaman", 2.0], "o_brute": ["orcs_0x72", "orc_warrior", 2.0],
	"o_berserker": ["orcs_0x72", "masked_orc", 2.0], "o_chieftain": ["orcs_0x72", "ogre", 2.0],
	"seraph": ["bosses_0x72", "seraph", 3.0], "rot_king": ["bosses_0x72", "rot_king", 2.0], "hell_prince": ["bosses_0x72", "hell_prince", 2.0],
	"ogre_warchief": ["bosses_0x72", "ogre_warchief", 2.0], "winged_chort": ["bosses_0x72", "winged_chort", 3.0],
	"soul_caller": ["bosses_0x72", "soul_caller", 3.0], "crystal_wogol": ["bosses_0x72", "crystal_wogol", 3.0],
	"golden_angel": ["bosses_0x72", "golden_angel", 3.0]}
## The four demon mini-bosses: standing figures with derived frames, drawn
## like the orcs (scripts/slice_nebenbosse_sheet.py, animate_orc_figures.py).
const NEBENBOSS_ROOT := "res://assets/sprites/nebenbosse/"
## Room props from the same sheet: wall hangings, floor decoration, lava, portal.
const PROP_ROOT := "res://assets/sprites/props/"
const CHEST_CLOSED := preload("res://assets/sprites/0x72/chest_full_open_anim_f0.png")
const CHEST_OPEN := preload("res://assets/sprites/0x72/chest_full_open_anim_f2.png")
const ENEMY_SPRITES := {"chaser": "goblin", "shooter": "orc_shaman", "boss": "big_demon", "imp": "imp", "skelet": "skelet", "necromancer": "necromancer", "tiny_zombie": "tiny_zombie",
	"chort": "chort", "wogol": "wogol", "doc": "doc", "pumpkin_dude": "pumpkin_dude", "big_zombie": "big_zombie", "angel": "angel"}
# The stone golem (floor 2 boss) has its own frame sets, cut from its sheet by
# scripts/slice_golem_sheet.py and listed in its manifest.
const GOLEM_ROOT := "res://assets/sprites/golem/"
const GOLEM_FEET := 33.0
# The infernal creatures (endless floors) and their boss Molgrax, cut from their
# sheets by scripts/slice_infernal_sheets.py.
const INFERNAL_ROOT := "res://assets/sprites/infernal/"
# Which frames a creature shows while its attack is active.
const INFERNAL_ACTIVE := {"glutling": "attack", "schattling": "attack", "funkenball": "attack", "stachelwaechter": "attack",
	"leerenpriester": "attack", "krabbenteufel": "attack", "fackelteufel": "attack"}
# Burst frames per hazard kind: [frame set, animation, scale].
const HAZARD_BURSTS := {"quake": ["golem", "quake_burst", 0.55], "blast": ["golem", "blast", 0.63], "thorns": ["golem", "thorns", 0.63],
	"fire": ["glutling", "fire_patch", 0.7], "lava": ["fackelteufel", "flame_pillar", 0.8], "flame": ["fackelteufel", "flame_pillar", 0.9],
	"blood": ["blutqualle", "blood_pillar", 0.9], "spike": ["krabbenteufel", "spikes", 0.7], "void": ["schattling", "void_cloud", 0.8]}
const HAZARD_COLORS := {"quake": Color("#7fe8e0"), "fire": Color("#ff8a3c"), "lava": Color("#ff6a2a"), "flame": Color("#ff9a3c"),
	"blood": Color("#d8484f"), "spike": Color("#b8a89a"), "void": Color("#a77be8")}
const SPRITE_ROOT := "res://assets/sprites/0x72/"
const FRAMES_PER_SECOND := 8.0
const Feedback = preload("res://src/vfx/feedback.gd")
const Sfx = preload("res://src/vfx/sfx.gd")
const MAX_SHAKE_PIXELS := 9.0
const FIRE := Color("#ff7a3c")
const BEAM := Color("#ff5a4a")
const WARN := Color("#ff4a4a")
# EXP orb colours by size: small, medium, large.
const ORB_COLORS := [Color("#5fe3c0"), Color("#6fb7ff"), Color("#e08cff")]

var _snapshot: Dictionary = {}
var _local_peer: int = 1
var _clock: float = 0.0
# name -> {"idle": [Texture2D x4], "run": [Texture2D x4], "hit": Texture2D or null}
var _sprites: Dictionary = {}
# Texture -> white silhouette of it, for hit flashes without a per-sprite shader.
var _flash_textures: Dictionary = {}
# Golem animation name -> Array[Texture2D].
var _golem: Dictionary = {}
# Infernal creature -> {animation -> Array[Texture2D]}.
var _infernal: Dictionary = {}
var _weapon_textures: Dictionary = {}
var _orcs: Dictionary = {}
# Goblin/orc -> {animation -> Array[Texture2D]} built by scripts/animate_orc_figures.py.
var _orc_frames: Dictionary = {}
var _props: Dictionary = {}
var _feedback := Feedback.new()
var _base_position := Vector2.ZERO
var _shake_rng := RandomNumberGenerator.new()
## 0 turns screen shake off (player option), 1 is full strength.
var shake_scale := 1.0
# Fog of war: the room it belongs to, the cells already seen there, and this
# frame's light sources (living heroes).
var _fog_room := ""
var _fog_seen: Dictionary = {}
var _fog_lights: Array[Vector2] = []
var _lit_arenas: Array[Rect2] = []
## Big maps: top-left world pixel of the visible 896 x 480 view (zero in rooms).
## The shared camera follows the party's middle and stops at the map's edges.
var camera_origin := Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_position = position
	for name: String in HERO_SPRITES + ENEMY_SPRITES.values():
		var entry := {"idle": [], "run": [], "hit": null}
		for state: String in ["idle", "run"]:
			for frame: int in range(4):
				var texture: Texture2D = load("%s%s_%s_anim_f%d.png" % [SPRITE_ROOT, name, state, frame])
				entry[state].append(texture)
				_flash_textures[texture] = _silhouette(texture)
		var hit_path := "%s%s_hit_anim_f0.png" % [SPRITE_ROOT, name]
		if ResourceLoader.exists(hit_path):
			entry.hit = load(hit_path)
			_flash_textures[entry.hit] = _silhouette(entry.hit)
		_sprites[name] = entry
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLEM_ROOT + "manifest.json"))
	if manifest is Dictionary:
		for animation: String in manifest:
			var frames: Array = []
			for frame in range(int(manifest[animation].frames)):
				frames.append(load("%s%s_f%d.png" % [GOLEM_ROOT, animation, frame]))
			_golem[animation] = frames
	var infernal: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFERNAL_ROOT + "manifest.json"))
	if infernal is Dictionary:
		for creature: String in infernal:
			var sets := {}
			for animation: String in infernal[creature]:
				var frames: Array = []
				for frame in range(int(infernal[creature][animation].frames)):
					frames.append(load("%s%s/%s_f%d.png" % [INFERNAL_ROOT, creature, animation, frame]))
				sets[animation] = frames
			_infernal[creature] = sets
	for root: String in [ORC_ROOT, NEBENBOSS_ROOT]:
		var orcs: Variant = JSON.parse_string(FileAccess.get_file_as_string(root + "manifest.json"))
		if orcs is Dictionary:
			for name: String in orcs: _orcs[name] = load(root + name + ".png")
		var orc_frames: Variant = JSON.parse_string(FileAccess.get_file_as_string(root + "frames/frames.json"))
		if orc_frames is Dictionary:
			for name: String in orc_frames:
				var sets := {}
				for animation: String in orc_frames[name]:
					var list: Array = []
					for frame in range(int(orc_frames[name][animation])):
						list.append(load("%sframes/%s_%s_f%d.png" % [root, name, animation, frame]))
					sets[animation] = list
				_orc_frames[name] = sets
	var manifests := {}
	for kind: String in SHEET_KINDS:
		var folder: String = "res://assets/sprites/%s/" % SHEET_KINDS[kind][0]
		var sheet: String = SHEET_KINDS[kind][1]
		if not manifests.has(folder):
			manifests[folder] = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json"))
		var sheets: Variant = manifests[folder]
		if not (sheets is Dictionary and sheets.has(sheet)):
			continue
		var anims := {}
		for row: Array in sheets[sheet].rows:
			var list: Array = []
			for frame in range(int(row[1])):
				list.append(load("%sframes/%s_%s_anim_f%d.png" % [folder, sheet, row[0], frame]))
			anims[row[0]] = list
		_orc_frames[kind] = {"idle": anims.idle, "walk": anims.run, "windup": anims.attack.slice(0, 2),
			"strike": anims.attack.slice(2, 4), "hit": anims.hit, "death": anims.death}
		_orcs[kind] = anims.idle[0]
	var props: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROP_ROOT + "manifest.json"))
	if props is Dictionary:
		for name: String in props: _props[name] = load(PROP_ROOT + name + ".png")
	for weapon_id: String in WEAPON_SPRITES:
		_weapon_textures[weapon_id] = load("%s%s.png" % [SPRITE_ROOT, WEAPON_SPRITES[weapon_id]])
	var sfx := Sfx.new()
	add_child(sfx)
	_feedback.sfx = sfx


## Updates the displayed snapshot. Coordinates are local to the 896 × 480 room.
## During hitstop the shown frame is held; feedback still sees every snapshot.
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	_local_peer = local_peer
	_feedback.observe(snapshot, local_peer)
	if _feedback.hitstop <= 0.0 or snapshot.is_empty():
		_snapshot = snapshot
	queue_redraw()


func _process(delta: float) -> void:
	if _feedback.hitstop <= 0.0:
		_clock += delta
	_feedback.update(delta)
	# Shake grows with the square of trauma; whole pixels keep the art crisp.
	var strength: float = _feedback.shake * _feedback.shake * MAX_SHAKE_PIXELS * shake_scale
	camera_origin = _camera_origin()
	position = _base_position - camera_origin + Vector2(_shake_rng.randf_range(-1, 1), _shake_rng.randf_range(-1, 1)).round() * roundf(strength)
	queue_redraw()


## The shared camera: centred on the living heroes (all heroes when none
## lives), clamped to the map, on whole pixels. Rooms never scroll.
func _camera_origin() -> Vector2:
	var layout: Dictionary = _room_layout()
	if not layout.has("tiles"):
		return Vector2.ZERO
	var points: Array[Vector2] = []
	var players: Dictionary = _snapshot.get("players", {})
	for peer_key: Variant in players:
		if int(players[peer_key].get("hp", 0)) > 0: points.append(_position(players[peer_key]))
	if points.is_empty():
		for peer_key: Variant in players: points.append(_position(players[peer_key]))
	if points.is_empty():
		return camera_origin
	var centre := Vector2.ZERO
	for point: Vector2 in points: centre += point
	centre /= float(points.size())
	var world := Vector2(float(layout.width), float(layout.height)) * float(layout.tile_size)
	return (centre - VIEW_SIZE * 0.5).clamp(Vector2.ZERO, (world - VIEW_SIZE).max(Vector2.ZERO)).round()


func _silhouette(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha: float = image.get_pixel(x, y).a
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	if _room_layout().has("tiles"):
		_draw_map()
	else:
		_draw_floor()
		_draw_lava()
		_draw_walls()
		_draw_obstacles()
		_draw_props()
		for index: int in range(TORCH_X.size()):
			_draw_torch(TORCH_X[index], index * 1.7)
	var phase: String = str(_snapshot.get("phase", "lobby"))
	if phase == "reward" or phase == "victory":
		_draw_pedestal(phase == "victory")
	_draw_portal()
	_feedback.particles.draw_stains(self)
	_draw_orbs()
	_draw_loot()
	var players: Dictionary = _snapshot.get("players", {})
	_fog_lights.clear()
	_lit_arenas.clear()
	var layout: Dictionary = _room_layout()
	for peer_key: Variant in players:
		if int(players[peer_key].get("hp", 0)) > 0:
			_fog_lights.append(_position(players[peer_key]))
			if layout.has("tiles"):
				var index: int = FloorMap.room_at(layout, _position(players[peer_key]))
				if index >= 0 and str(layout.rooms[index].kind) in ["boss", "miniboss"]:
					var floor_rect: Array = layout.rooms[index].floor
					_lit_arenas.append(Rect2(float(floor_rect[0]) * 32.0, float(floor_rect[1]) * 32.0, float(floor_rect[2]) * 32.0, float(floor_rect[3]) * 32.0).grow(32.0))
	# Enemies in the dark are not drawn at all; their floor warnings still are.
	var enemies: Array = []
	for enemy_value: Variant in _snapshot.get("enemies", []):
		if not _fog_active() or _light_at(_position(enemy_value)) > 0.15:
			enemies.append(enemy_value)
	for enemy_value: Variant in _snapshot.get("enemies", []):
		_draw_boss_floor(enemy_value)
		_draw_mob_telegraph(enemy_value)
	_draw_hazards(false)
	for enemy_value: Variant in enemies:
		var enemy: Dictionary = enemy_value
		if float(enemy.get("dying_p", -1.0)) < 0.5:
			# A jumping boss leaves a shrinking shadow on the floor below it.
			var air: float = float(enemy.get("air", 0.0))
			var shadow: float = 30.0 if str(enemy.get("kind", "")) == "golem" else 25.0 if bool(enemy.get("boss", false)) else 14.0
			_draw_shadow(_position(enemy), shadow * (1.0 - 0.55 * air))
	_draw_ghosts()
	for peer_key: Variant in players:
		var player: Dictionary = players[peer_key]
		_draw_shadow(_position(player), 14.0)
	for enemy_value: Variant in enemies:
		_draw_enemy(enemy_value)
	for peer_key: Variant in players:
		_draw_player(players[peer_key], int(peer_key))
	var bullets: Array = _snapshot.get("bullets", [])
	for bullet_value: Variant in bullets:
		_draw_bullet(bullet_value)
	for enemy_value: Variant in enemies:
		_draw_boss_overlay(enemy_value)
	_draw_hazards(true)
	_feedback.particles.draw_particles(self)
	_draw_motes()
	_draw_fog()


## Fog of war runs in ordinary rooms; boss and mini-boss arenas stay lit.
func _fog_active() -> bool:
	var layout: Dictionary = _room_layout()
	return not _snapshot.get("fog", {}).is_empty() and not layout.is_empty() and not str(layout.get("kind", "")) in ["boss", "miniboss"]


## 0 (dark) to 1 (lit): full light within the heroes' light radius, fading out
## over `fade` pixels beyond it. On a big map a boss or mini-boss arena with a
## hero inside is lit completely.
func _light_at(point: Vector2) -> float:
	var fog: Dictionary = _snapshot.get("fog", {})
	for arena: Rect2 in _lit_arenas:
		if arena.has_point(point): return 1.0
	var light := 0.0
	for source: Vector2 in _fog_lights:
		light = maxf(light, 1.0 - clampf((point.distance_to(source) - float(fog.light_radius)) / float(fog.fade), 0.0, 1.0))
	return light


## Darkness over the room in `fog.cell` squares: lit around each living hero,
## dimmed where the party has already been this visit, nearly black elsewhere.
func _draw_fog() -> void:
	if not _fog_active():
		return
	var fog: Dictionary = _snapshot.get("fog", {})
	var room_id: String = str(_room_layout().get("id", ""))
	if room_id != _fog_room:
		_fog_room = room_id
		_fog_seen.clear()
	var cell: float = float(fog.cell)
	# Only the cells in view; on a big map the memory covers the whole floor.
	for row: int in range(floori(camera_origin.y / cell), ceili((camera_origin.y + VIEW_SIZE.y) / cell)):
		for column: int in range(floori(camera_origin.x / cell), ceili((camera_origin.x + VIEW_SIZE.x) / cell)):
			var light: float = _light_at(Vector2((column + 0.5) * cell, (row + 0.5) * cell))
			var key: int = row * 1000 + column
			if light > 0.5:
				_fog_seen[key] = true
			var alpha: float = (float(fog.memory_alpha) if _fog_seen.has(key) else float(fog.dark_alpha)) * (1.0 - light)
			if alpha > 0.01:
				draw_rect(Rect2(column * cell, row * cell, cell, cell), Color(0.02, 0.015, 0.04, alpha))


## Lava pools of the room: a glowing, breathing pool with embers rising.
func _draw_lava() -> void:
	for value: Variant in _room_layout().get("lava", []):
		var pool: Dictionary = value
		var point := Vector2(float(pool.get("x", 0.0)), float(pool.get("y", 0.0)))
		var radius: float = float(pool.get("r", 16.0))
		var glow: float = 0.5 + 0.5 * sin(_clock * 2.4 + point.x * 0.05)
		draw_circle(point, radius + 10.0, Color(1.0, 0.35, 0.1, 0.08 + 0.06 * glow))
		var texture: Texture2D = _props.get(str(pool.get("n", "lava_m")))
		if texture != null:
			var size := Vector2(texture.get_width(), texture.get_height()) * 1.5
			draw_texture_rect(texture, Rect2(point - size * 0.5, size), false, Color(1.0, 0.9 + 0.1 * glow, 0.9 + 0.1 * glow))
		for k in range(3):
			var rise: float = fmod(_clock * 0.8 + k * 0.33 + point.y * 0.01, 1.0)
			var drift: float = sin(_clock * 3.0 + k * 2.0) * radius * 0.4
			_box(point.x + drift + (k - 1) * radius * 0.4, point.y - rise * 26.0, 2, 2, Color(1.0, 0.7, 0.3, 1.0 - rise))


## Scenery: hangings sit on the top wall, the rest stands on the floor with a
## shadow. The crystals and the lit cage glow softly.
func _draw_props() -> void:
	for value: Variant in _room_layout().get("props", []):
		var prop: Dictionary = value
		var texture: Texture2D = _props.get(str(prop.get("n", "")))
		if texture == null:
			continue
		var point := Vector2(float(prop.get("x", 0.0)), float(prop.get("y", 0.0)))
		var size := Vector2(texture.get_width(), texture.get_height())
		var name: String = str(prop.get("n", ""))
		if name in ["crystal", "crystals", "spire", "cage_lit", "cauldron", "altar"]:
			var tint := Color(0.7, 0.35, 1.0) if name.begins_with("crystal") else Color(1.0, 0.4, 0.15)
			draw_circle(point + Vector2(0, -size.y * 0.4) if not bool(prop.get("wall", false)) else point + Vector2(0, size.y * 0.6), size.x * 0.6, Color(tint, 0.07 + 0.04 * sin(_clock * 2.0 + point.x)))
		if bool(prop.get("wall", false)):
			# Hangings sway a little on their chains.
			var sway: float = sin(_clock * 1.3 + point.x) * 0.03
			draw_set_transform(point + Vector2(0, -6), sway, Vector2.ONE)
			draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, 0), size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_box(point.x - size.x * 0.4, point.y - 3, size.x * 0.8, 5, Color(0.05, 0.04, 0.09, 0.45))
			draw_texture_rect(texture, Rect2(point - Vector2(size.x * 0.5, size.y), size), false)


## The portal to the next floor after an endless boss: it opens, pulses and
## pulls motes into its middle.
func _draw_portal() -> void:
	var gate: Dictionary = _snapshot.get("portal", {})
	if gate.is_empty() or not _props.has("portal"):
		return
	var point := Vector2(float(gate.get("x", 448.0)), float(gate.get("y", 112.0)))
	var texture: Texture2D = _props.portal
	var pulse: float = 1.0 + 0.04 * sin(_clock * 3.0)
	var size := Vector2(texture.get_width(), texture.get_height()) * pulse
	draw_circle(point, size.x * 0.62, Color(0.55, 0.25, 0.95, 0.12 + 0.05 * sin(_clock * 2.0)))
	draw_texture_rect(texture, Rect2(point - size * 0.5, size), false)
	for k in range(8):
		var t: float = fmod(_clock * 0.7 + k / 8.0, 1.0)
		var angle: float = k * TAU / 8.0 + _clock * 1.5
		var mote: Vector2 = point + Vector2.RIGHT.rotated(angle) * size.x * 0.75 * (1.0 - t)
		_box(mote.x, mote.y, 3, 3, Color(0.85, 0.6, 1.0, t))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, point + Vector2(-60, size.y * 0.5 + 16), "PORTAL", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color("#d6b3ff", 0.6 + 0.3 * sin(_clock * 4.0)))


func _box(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), width, height), color)


func _position(entity: Dictionary) -> Vector2:
	return Vector2(float(entity.get("x", 448.0)), float(entity.get("y", 240.0)))


func _room_layout() -> Dictionary:
	var layout: Variant = _snapshot.get("room_layout", {})
	return layout if layout is Dictionary else {}


## Seeded per room, so the cracked tiles stay put while the room is shown.
func _tile_hash(column: int, row: int) -> int:
	var room_seed: int = int(_snapshot.get("seed", 0)) + str(_room_layout().get("template_id", "")).hash() % 997
	return absi(hash([column, row, room_seed]))


## The floor's look sent with the room: tile tints, banner colour and detail.
func _theme() -> Dictionary:
	var theme: Variant = _room_layout().get("theme", {})
	return theme if theme is Dictionary else {}


func _theme_color(key: String) -> Color:
	var value: String = str(_theme().get(key, ""))
	return Color(value) if value.is_valid_html_color() else Color.WHITE


## 0x72 floor tinted by the floor's theme, with about one cracked or stained
## tile in twelve, then the theme's detail on top: glowing lava cracks (hell),
## moss (orc camp), cobwebs (crypt) or gold inlays (heaven temple).
func _draw_floor() -> void:
	var tint: Color = _theme_color("floor")
	for row: int in range(15):
		for column: int in range(28):
			var tile_hash: int = _tile_hash(column, row)
			var texture: Texture2D = FLOOR_TILES[0] if tile_hash % 12 != 0 else FLOOR_TILES[1 + tile_hash / 12 % 7]
			draw_texture_rect(texture, Rect2(column * 32, row * 32, 32, 32), false, tint)
	var detail: String = str(_theme().get("detail", ""))
	for row: int in range(1, 15):
		for column: int in range(1, 27):
			_draw_floor_detail(column, row, detail)


## One floor tile's theme detail: glowing lava cracks, moss, cobwebs or gold.
func _draw_floor_detail(column: int, row: int, detail: String) -> void:
	var tile_hash: int = _tile_hash(column, row + 100)
	var origin := Vector2(column * 32, row * 32)
	match detail:
		"cracks":
			if tile_hash % 4 == 0:
				# A jagged glowing crack across the tile, breathing with the lava.
				var glow: float = 0.55 + 0.45 * sin(_clock * 2.0 + float(tile_hash % 17))
				var y: float = 6.0 + float(tile_hash % 20)
				for step: int in range(8):
					y = clampf(y + float((tile_hash >> step) % 3) * 2.0 - 2.0, 2.0, 28.0)
					_box(origin.x + step * 4, origin.y + y, 4, 2, Color(CRACK_GLOW, 0.55 + 0.35 * glow))
				draw_circle(origin + Vector2(16, 16), 12.0, Color(CRACK_GLOW, 0.05 * glow))
		"moss":
			if tile_hash % 5 == 0:
				for k: int in range(6):
					var spot := Vector2(float((tile_hash >> (k * 3)) % 26), float((tile_hash >> (k * 3 + 2)) % 26))
					_box(origin.x + spot.x, origin.y + spot.y, 4, 2, MOSS_DARK if k % 2 == 0 else MOSS_LIGHT)
		"cobweb":
			if tile_hash % 11 == 0:
				for k: int in range(5):
					_box(origin.x + k * 3, origin.y + k * 3, 2, 1, Color(COBWEB, 0.5))
					_box(origin.x + 12 - k * 3, origin.y + k * 3, 2, 1, Color(COBWEB, 0.35))
		"gold":
			if (column + row) % 4 == 0:
				_box(origin.x + 14, origin.y + 12, 4, 8, Color(GOLD_INLAY, 0.8))
				_box(origin.x + 12, origin.y + 14, 8, 4, Color(GOLD_INLAY, 0.8))
				_box(origin.x + 15, origin.y + 15, 2, 2, Color("#fff4c8"))


## A big floor map, only the tiles in view: themed floor with details, then
## walls assembled from 0x72 parts around every walkable tile: a brick face
## with its lit top edge where floor lies below, a dark top with lit edges
## elsewhere, and wall torches and banners on the rooms' north walls.
func _draw_map() -> void:
	var layout: Dictionary = _room_layout()
	var first: Vector2i = Vector2i(floori(camera_origin.x / 32.0) - 1, floori(camera_origin.y / 32.0) - 1)
	var last: Vector2i = Vector2i(ceili((camera_origin.x + VIEW_SIZE.x) / 32.0) + 1, ceili((camera_origin.y + VIEW_SIZE.y) / 32.0) + 1)
	var floor_tint: Color = _theme_color("floor")
	var wall_tint: Color = _theme_color("wall")
	var detail: String = str(_theme().get("detail", ""))
	for row: int in range(first.y, last.y):
		for column: int in range(first.x, last.x):
			if not FloorMap.walkable(FloorMap.tile_at(layout, column, row)):
				continue
			var tile_hash: int = _tile_hash(column, row)
			var texture: Texture2D = FLOOR_TILES[0] if tile_hash % 12 != 0 else FLOOR_TILES[1 + tile_hash / 12 % 7]
			draw_texture_rect(texture, Rect2(column * 32, row * 32, 32, 32), false, floor_tint)
			_draw_floor_detail(column, row, detail)
	for row: int in range(first.y, last.y):
		for column: int in range(first.x, last.x):
			if FloorMap.walkable(FloorMap.tile_at(layout, column, row)):
				continue
			var open_below: bool = FloorMap.walkable(FloorMap.tile_at(layout, column, row + 1))
			var open_above: bool = FloorMap.walkable(FloorMap.tile_at(layout, column, row - 1))
			var open_left: bool = FloorMap.walkable(FloorMap.tile_at(layout, column - 1, row))
			var open_right: bool = FloorMap.walkable(FloorMap.tile_at(layout, column + 1, row))
			if not (open_below or open_above or open_left or open_right):
				# Outer corners: fill them dark so walls close without notches.
				for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
					if FloorMap.walkable(FloorMap.tile_at(layout, column + corner.x, row + corner.y)):
						draw_rect(Rect2(column * 32, row * 32, 32, 32), WALL_TOP)
						break
				continue
			var x: float = column * 32
			var y: float = row * 32
			draw_rect(Rect2(x, y, 32, 32), WALL_TOP)
			if open_below:
				var tile_hash: int = _tile_hash(column, row + 40)
				var face: Texture2D = WALL_FACE if tile_hash % 9 != 0 else WALL_FACE_HOLES[tile_hash % 2]
				draw_texture_rect(face, Rect2(x, y + 8, 32, 24), false, wall_tint)
				_draw_tile_part(WALL_CAP, Vector2(x, y), 32, 8, 12, wall_tint)
			elif open_above:
				_draw_tile_part(WALL_CAP, Vector2(x, y), 32, 8, 12, wall_tint)
				_draw_tile_part(WALL_FACE, Vector2(x, y + 8), 32, 24, 0, wall_tint)
			if open_left and not open_below:
				draw_texture_rect_region(EDGE_STRIP_LEFT, Rect2(x, y, 10, 32), Rect2(0, 0, 5, 16), wall_tint)
			if open_right and not open_below:
				draw_texture_rect_region(EDGE_STRIP_RIGHT, Rect2(x + 22, y, 10, 32), Rect2(11, 0, 5, 16), wall_tint)
	var banner: Texture2D = BANNERS.get(str(_theme().get("banner", "")))
	var view := Rect2(camera_origin - Vector2(64, 64), VIEW_SIZE + Vector2(128, 128))
	for map_room: Variant in layout.get("rooms", []):
		var rect: Array = map_room.rect
		var wall_y: float = float(rect[1]) * 32.0
		for k: int in range(1, int(rect[2]) / 5):
			var column: int = int(rect[0]) + k * 5
			if FloorMap.tile_at(layout, column, int(rect[1])) != FloorMap.SOLID or not FloorMap.walkable(FloorMap.tile_at(layout, column, int(rect[1]) + 1)):
				continue
			var x: float = column * 32 + 16
			if not view.has_point(Vector2(x, wall_y)):
				continue
			if k % 2 == 1:
				_draw_torch(x, float(column) * 0.7, wall_y - 8.0)
			elif banner != null:
				draw_texture_rect(banner, Rect2(x - 16, wall_y + 8, 32, 32), false)


## Cover is a free-standing block of the same wall: a dark top ringed by lit
## edges above a brick face. Everything stays inside the collision footprint,
## so cover never disguises a walkable edge.
## Cutouts that shape the room (cross, steps, corridors) are drawn the same way,
## as large blocks of wall, tinted like the room's walls.
func _draw_obstacles() -> void:
	var obstacles: Array = _room_layout().get("obstacles", [])
	var tint: Color = _theme_color("wall")
	for value: Variant in obstacles:
		var footprint: Rect2 = _obstacle_rect(value)
		if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
			continue
		_box(footprint.position.x + 4, footprint.end.y, footprint.size.x - 8, 4, Color(0.05, 0.04, 0.09, 0.5))
		var face: float = minf(32.0, footprint.size.y - 8.0)
		var top := Rect2(footprint.position, Vector2(footprint.size.x, footprint.size.y - face))
		draw_rect(top, WALL_TOP)
		for column: int in range(int(ceilf(footprint.size.x / 32.0))):
			var x: float = footprint.position.x + column * 32
			var width: float = minf(32.0, footprint.end.x - x)
			_draw_tile_part(WALL_CAP, Vector2(x, top.position.y), width, 8.0, 12.0, tint)
			# Faces shorter than a tile keep their lower rows, where the floor meets the bricks.
			draw_texture_rect_region(WALL_FACE, Rect2(x, top.end.y, width, face), Rect2(0, 16.0 - face * 0.5, width * 0.5, face * 0.5), tint)
		for row: int in range(int(ceilf(top.size.y / 32.0))):
			var y: float = top.position.y + row * 32
			var height: float = minf(32.0, top.end.y - y)
			draw_texture_rect_region(EDGE_STRIP_LEFT, Rect2(footprint.position.x, y, 10, height), Rect2(0, 0, 5, height * 0.5), tint)
			draw_texture_rect_region(EDGE_STRIP_RIGHT, Rect2(footprint.end.x - 10, y, 10, height), Rect2(11, 0, 5, height * 0.5), tint)


## Draws a horizontal band of a 16 px tile at 2x: `rows` screen pixels tall,
## starting at source row `source_row`.
func _draw_tile_part(texture: Texture2D, point: Vector2, width: float, rows: float, source_row: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(texture, Rect2(point, Vector2(width, rows)), Rect2(0, source_row, width * 0.5, rows * 0.5), tint)


func _obstacle_rect(value: Variant) -> Rect2:
	if value is Array and value.size() == 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if value is Dictionary:
		return Rect2(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("w", 0)), float(value.get("h", 0)))
	return Rect2()


## Wall faces on the top and bottom, lit edges down both sides, all from the
## 0x72 set; the dark wall tops fill whatever lies outside the edges.
func _draw_walls() -> void:
	var tint: Color = _theme_color("wall")
	for column: int in range(28):
		var x: float = column * 32
		var tile_hash: int = _tile_hash(column, 40)
		var face: Texture2D = WALL_FACE if tile_hash % 9 != 0 else WALL_FACE_HOLES[tile_hash % 2]
		_draw_tile_part(WALL_CAP, Vector2(x, 0), 32, 8, 12, tint)
		draw_texture_rect(face, Rect2(x, 8, 32, 32), false, tint)
		_draw_tile_part(WALL_CAP, Vector2(x, 448), 32, 8, 12, tint)
		_draw_tile_part(WALL_FACE, Vector2(x, 456), 32, 24, 0, tint)
	_box(0, 0, 14, 480, WALL_TOP)
	_box(882, 0, 14, 480, WALL_TOP)
	for row: int in range(15):
		draw_texture_rect(EDGE_STRIP_RIGHT, Rect2(-8, row * 32, 32, 32), false, tint)
		draw_texture_rect(EDGE_STRIP_LEFT, Rect2(872, row * 32, 32, 32), false, tint)
	var banner: Texture2D = BANNERS.get(str(_theme().get("banner", "")))
	if banner != null:
		for x: float in BANNER_X:
			draw_texture_rect(banner, Rect2(x - 16, 8, 32, 32), false)
	_draw_doors()


## Doorways to neighbouring rooms. The north wall gets a real door that is shut
## while the host keeps the room locked; the other walls open onto the floor
## and close with iron bars. A boss or treasure room beyond tints the door once
## it is on the map.
func _draw_doors() -> void:
	var doors: Variant = _room_layout().get("doors", {})
	if not doors is Dictionary:
		return
	var open: bool = bool(_snapshot.get("doors_open", false))
	for side: Variant in doors:
		var frame: Color = _door_frame(str(doors[side]))
		var tint: Color = Color.WHITE if frame == DOOR_PLAIN else Color.WHITE.lerp(frame, 0.55)
		if side == "north":
			draw_rect(Rect2(422, -8, 52, 48), Color("#100d14"))
			draw_texture_rect(DOOR_OPEN if open else DOOR_CLOSED, Rect2(416, -16, 64, 64), false, tint)
			continue
		var opening: Rect2
		match side:
			"south": opening = Rect2(416, 448, 64, 32)
			"west": opening = Rect2(0, 208, 24, 80)
			"east": opening = Rect2(872, 208, 24, 80)
			_: continue
		# The floor runs on through the gap; lit edges frame it.
		for row: int in range(int(ceilf(opening.size.y / 32.0))):
			for column: int in range(int(ceilf(opening.size.x / 32.0))):
				var point: Vector2 = opening.position + Vector2(column * 32, row * 32)
				var size := Vector2(minf(32.0, opening.end.x - point.x), minf(32.0, opening.end.y - point.y))
				draw_texture_rect_region(FLOOR_TILES[0], Rect2(point, size), Rect2(Vector2.ZERO, size * 0.5), _theme_color("floor"))
		if side == "south":
			draw_texture_rect(EDGE_STRIP_RIGHT, Rect2(opening.position.x - 32, 448, 32, 32), false)
			draw_texture_rect(EDGE_STRIP_LEFT, Rect2(opening.end.x, 448, 32, 32), false)
			_box(opening.position.x, opening.position.y, opening.size.x, 3, frame)
		else:
			_draw_tile_part(WALL_CAP, Vector2(opening.position.x, opening.position.y - 8), opening.size.x, 8, 12)
			_draw_tile_part(WALL_CAP, Vector2(opening.position.x, opening.end.y), opening.size.x, 8, 12)
			_box(opening.end.x - 3 if side == "west" else opening.position.x, opening.position.y, 3, opening.size.y, frame)
		if not open:
			if side == "south":
				for x: int in range(int(opening.position.x) + 6, int(opening.end.x) - 4, 12):
					_draw_bar(Rect2(x, opening.position.y, 6, opening.size.y))
			else:
				for y: int in range(int(opening.position.y) + 6, int(opening.end.y) - 4, 12):
					_draw_bar(Rect2(opening.position.x, y, opening.size.x, 6))


## One iron bar in the 0x72 wall palette: dark outline, stone fill, lit edge.
func _draw_bar(bar: Rect2) -> void:
	draw_rect(bar, BAR_INK)
	draw_rect(bar.grow(-1), BAR)
	if bar.size.x < bar.size.y:
		_box(bar.position.x + 1, bar.position.y + 1, 1, bar.size.y - 2, BAR_LIGHT)
	else:
		_box(bar.position.x + 1, bar.position.y + 1, bar.size.x - 2, 1, BAR_LIGHT)


func _door_frame(room_id: String) -> Color:
	for value: Variant in _snapshot.get("floor_map", []):
		if value is Dictionary and str(value.get("id", "")) == room_id:
			match str(value.get("kind", "")):
				"boss": return Color("#b84a4f")
				"treasure": return GOLD
	return Color("#796171")


## A burning wall torch on the top wall face, with a soft flickering glow.
## A wall torch at `x`; `top` shifts it down from the room's top wall (big maps).
func _draw_torch(x: float, offset: float, top: float = 0.0) -> void:
	var flicker: float = sin(_clock * 7.0 + offset)
	draw_circle(Vector2(x, 26 + top), 44.0, Color(0.98, 0.46, 0.24, 0.05 + 0.015 * flicker))
	draw_circle(Vector2(x, 26 + top), 24.0, Color(0.98, 0.5, 0.26, 0.07 + 0.02 * flicker))
	var frame: int = int(_clock * FRAMES_PER_SECOND + offset * 3.0) % TORCH_FRAMES.size()
	draw_texture_rect(TORCH_FRAMES[frame], Rect2(x - 16, -4 + top, 32, 48), false)


func _draw_shadow(point: Vector2, half_width: float) -> void:
	_box(point.x - half_width, point.y + 13, half_width * 2, 7, Color(0.05, 0.04, 0.09, 0.55))
	_box(point.x - half_width + 4, point.y + 19, half_width * 2 - 8, 3, Color(0.05, 0.04, 0.09, 0.25))


func _player_color(player: Dictionary, peer_id: int) -> Color:
	var fallback: Color = PLAYER_COLORS[absi(peer_id - 1) % PLAYER_COLORS.size()]
	var value: Variant = player.get("color", fallback)
	if typeof(value) == TYPE_COLOR:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.from_string(str(value), fallback)
	if typeof(value) == TYPE_INT:
		return PLAYER_COLORS[absi(int(value)) % PLAYER_COLORS.size()]
	return fallback


func _draw_player(player: Dictionary, peer_id: int) -> void:
	var point: Vector2 = _position(player).round()
	var color: Color = _player_color(player, peer_id)
	var hp: float = float(player.get("hp", 1))
	if hp <= 0:
		_box(point.x - 11, point.y + 2, 22, 9, INK)
		_box(point.x - 8, point.y + 3, 16, 5, color.darkened(0.6))
		_box(point.x - 4, point.y - 8, 8, 3, MUTED)
		_box(point.x - 1, point.y - 11, 3, 10, MUTED)
		return
	if peer_id == _local_peer:
		var ring_color := Color(0.45, 0.91, 0.81, 0.7)
		draw_rect(Rect2(point.x - 20, point.y + 8, 40, 15), ring_color, false, 2.0)
		_box(point.x - 4, point.y - 24, 8, 3, color)
		_box(point.x - 2, point.y - 21, 4, 3, color)
	# Optional aim vector; no input is sampled by the presentation layer.
	var aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0)))
	if aim.length_squared() < 0.01:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	# Heroes run while moving in any direction and face where they aim (Isaac-style);
	# while invulnerable they show the hit frame and blink.
	var hero: Dictionary = _sprites[CLASS_SPRITES.get(str(player.get("class", "")), HERO_SPRITES[_sprite_index(color)])]
	var hurt: bool = bool(player.get("hurt", false))
	var texture: Texture2D = _frame(hero, bool(player.get("moving", false)), peer_id)
	var pose: Dictionary = _feedback.pose("p%d" % peer_id, player, _clock)
	var level_up: float = float(pose.get("level_up", 0.0))
	if level_up > 0.0:
		# Level-up: a golden pillar of light behind the hero.
		var width: float = 30.0 * (0.4 + 0.6 * level_up)
		draw_rect(Rect2(point.x - width * 0.5, point.y - 150, width, 168), Color(1.0, 0.85, 0.4, 0.28 * level_up))
		draw_rect(Rect2(point.x - width * 0.2, point.y - 150, width * 0.4, 168), Color(1.0, 0.97, 0.8, 0.45 * level_up))
	if hurt:
		if hero.hit != null and fmod(_clock, 0.24) < 0.12: texture = hero.hit
		pose.alpha *= 0.45 if fmod(_clock, 0.16) < 0.08 else 1.0
	_draw_sprite(texture, point, -1.0 if aim.x < -0.1 else 1.0, 16.0, pose)
	_draw_weapon(player, point, aim, pose)
	var boost: float = float(pose.get("boost", 0.0))
	if boost > 0.0:
		var font: Font = ThemeDB.fallback_font
		var lift: float = (1.0 - boost) * 30.0
		var text: String = str(player.get("boost_text", ""))
		draw_string(font, point + Vector2(-70, -40 - lift) + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(INK, minf(1.0, boost * 2.0)))
		draw_string(font, point + Vector2(-70, -40 - lift), text, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(Color("#7be38a"), minf(1.0, boost * 2.0)))
	if level_up > 0.0:
		var rise: float = (1.0 - level_up) * 26.0
		var font: Font = ThemeDB.fallback_font
		draw_string(font, point + Vector2(-42, -44 - rise) + Vector2(1, 1), "LEVEL UP!", HORIZONTAL_ALIGNMENT_CENTER, 84, 15, Color(INK, minf(1.0, level_up * 2.0)))
		draw_string(font, point + Vector2(-42, -44 - rise), "LEVEL UP!", HORIZONTAL_ALIGNMENT_CENTER, 84, 15, Color(GOLD, minf(1.0, level_up * 2.0)))
	if bool(player.get("ready", false)):
		_box(point.x + 15, point.y - 22, 8, 3, color)
		_box(point.x + 18, point.y - 25, 3, 9, color)


func _sprite_index(color: Color) -> int:
	var best_index: int = 0
	var closest: float = INF
	for index: int in range(PLAYER_COLORS.size()):
		var candidate: Color = PLAYER_COLORS[index]
		var distance: float = absf(color.r - candidate.r) + absf(color.g - candidate.g) + absf(color.b - candidate.b)
		if distance < closest:
			closest = distance
			best_index = index
	return best_index


func _draw_enemy(enemy: Dictionary) -> void:
	var kind: String = str(enemy.get("kind", "chaser"))
	if kind == "golem" and not _golem.is_empty():
		_draw_golem(enemy)
		return
	if _infernal.has(kind):
		_draw_infernal(enemy)
		return
	if _orcs.has(kind):
		_draw_orc(enemy)
		return
	var point: Vector2 = _position(enemy).round()
	var is_boss: bool = bool(enemy.get("boss", false))
	var sprite_name: String = ENEMY_SPRITES.get(kind, ENEMY_SPRITES.boss if is_boss else "goblin")
	var pixel_scale := 2.0
	var sprite: Dictionary = _sprites[sprite_name]
	var id: int = int(enemy.get("id", 0))
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	var texture: Texture2D = _frame(sprite, bool(enemy.get("moving", false)) and not dying, id * 3)
	var feet: float = 24.0 if is_boss else 16.0
	_draw_sprite(texture, point, float(enemy.get("face", -1.0)), feet, _feedback.pose("e%d" % id, enemy, _clock), pixel_scale)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	# Bosses show their health in the HUD's top bar instead.
	if not dying and hp < max_hp and not is_boss:
		var bar_width: float = 48.0 if is_boss else 26.0
		var bar_y: float = point.y + feet - float(texture.get_height()) * pixel_scale - 8.0
		_box(point.x - bar_width / 2.0 - 2, bar_y - 2, bar_width + 4, 7, INK)
		_box(point.x - bar_width / 2.0, bar_y, bar_width, 3, Color("#5e354d"))
		_box(point.x - bar_width / 2.0, bar_y, floorf(bar_width * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a"))


## Current idle or run frame; `phase` desynchronises actors that started together.
func _frame(sprite: Dictionary, moving: bool, phase: int) -> Texture2D:
	var frames: Array = sprite.run if moving else sprite.idle
	return frames[(int(_clock * FRAMES_PER_SECOND) + absi(phase)) % frames.size()]


## Draws a 0x72 frame at 2x, standing with its feet `feet` px below `point` and
## mirrored when `face` is negative (the source art faces right). `pose` comes
## from the feedback layer: squash & stretch and lean pivot on the feet, so
## deformation never lifts an actor off the floor; the flash is a white
## silhouette drawn over the frame in the flash colour.
func _draw_sprite(texture: Texture2D, point: Vector2, face: float, feet: float, pose: Dictionary, pixel_scale: float = 2.0) -> void:
	var size := Vector2(texture.get_width(), texture.get_height()) * pixel_scale
	var scale: Vector2 = pose.get("scale", Vector2.ONE)
	var alpha: float = float(pose.get("alpha", 1.0))
	var anchor: Vector2 = point + Vector2(0, feet) + Vector2(pose.get("offset", Vector2.ZERO))
	draw_set_transform(anchor, float(pose.get("lean", 0.0)), Vector2((-1.0 if face < 0.0 else 1.0) * scale.x, scale.y))
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	var tint: Color = pose.get("tint", Color.WHITE)
	draw_texture_rect(texture, rect, false, Color(tint, alpha))
	var flash: float = float(pose.get("flash", 0.0))
	if flash > 0.0 and not _flash_textures.has(texture):
		# Golem frames are many and large: make their silhouettes on first use.
		_flash_textures[texture] = _silhouette(texture)
	if flash > 0.0 and _flash_textures.has(texture):
		var color: Color = pose.get("flash_color", Color.WHITE)
		draw_texture_rect(_flash_textures[texture], rect, false, Color(color, flash * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bullet(bullet: Dictionary) -> void:
	var point: Vector2 = _position(bullet).round()
	var kind: String = str(bullet.get("k", ""))
	if not kind.is_empty():
		_draw_special_bullet(kind, point, float(bullet.get("a", 0.0)))
		return
	var owner: int = int(bullet.get("owner", 1))
	var color: Color = Color("#f3ce7d") if owner > 0 else Color("#f19791")
	_box(point.x - 6, point.y - 6, 12, 12, Color(color, 0.12))
	_box(point.x - 4, point.y - 4, 8, 8, INK)
	_box(point.x - 3, point.y - 3, 6, 6, color)
	_box(point.x - 2, point.y - 2, 3, 3, Color("#fff6dc"))


func _draw_pedestal(victory: bool) -> void:
	var center := Vector2(448, 240)
	var pulse: float = 0.08 + 0.03 * sin(_clock * 2.5)
	draw_rect(Rect2(384, 176, 128, 128), Color(0.95, 0.75, 0.35, pulse))
	draw_rect(Rect2(400, 192, 96, 96), GOLD.darkened(0.4), false, 2.0)
	_draw_shadow(center + Vector2(0, 13), 24)
	_box(424, 252, 48, 12, INK)
	_box(427, 250, 42, 10, Color("#796171"))
	_box(431, 238, 34, 16, Color("#5f4c61"))
	_box(427, 235, 42, 7, Color("#bc926f"))
	_box(430, 235, 36, 3, GOLD)
	var bob: float = floorf(sin(_clock * 2.6) * 4.0)
	var gem_center: Vector2 = center + Vector2(0, -26 + bob)
	var gem_outline := PackedVector2Array([
		gem_center + Vector2(0, -19), gem_center + Vector2(16, 0),
		gem_center + Vector2(0, 20), gem_center + Vector2(-16, 0)
	])
	draw_colored_polygon(gem_outline, INK)
	var gem := PackedVector2Array([
		gem_center + Vector2(0, -15), gem_center + Vector2(12, 0),
		gem_center + Vector2(0, 15), gem_center + Vector2(-12, 0)
	])
	draw_colored_polygon(gem, GOLD if victory else Color("#92e0c4"))
	draw_line(gem_center + Vector2(0, -11), gem_center + Vector2(0, 11), Color("#fff1b4"), 3.0)
	for index: int in range(4):
		var x: float = 412.0 + float(index * 24)
		_box(x, 278, 8, 3, GOLD.darkened(0.1))
		_box(x + 3, 274, 2, 11, GOLD.darkened(0.1))


func _draw_motes() -> void:
	for index: int in range(12):
		var x: float = float(105 + (index * 157) % 680)
		var y: float = 75.0 + fmod(float(index * 59) - _clock * 7.0 + 720.0, 330.0)
		var alpha: float = 0.14 + 0.08 * sin(_clock * 1.5 + float(index))
		# Motes float in the view, so on a big map they travel with the camera.
		_box(camera_origin.x + x, camera_origin.y + y, 2, 2, Color(0.94, 0.76, 0.59, alpha))



## EXP orbs: bobbing pixel crystals with a soft glow and an occasional twinkle;
## size and colour grow with the orb's value.
func _draw_orbs() -> void:
	for value: Variant in _snapshot.get("orbs", []):
		var orb: Dictionary = value
		var point: Vector2 = _position(orb).round()
		var worth: int = int(orb.get("v", 1))
		var tier: int = 0 if worth < 4 else 1 if worth < 9 else 2
		var radius: float = [3.0, 4.0, 6.0][tier]
		var color: Color = ORB_COLORS[tier]
		var id: int = int(orb.get("id", 0))
		var center: Vector2 = point + Vector2(0, roundf(sin(_clock * 5.0 + id * 1.7) * 2.0) - 5.0)
		_box(point.x - radius, point.y + 2, radius * 2.0, 2, Color(0.05, 0.04, 0.09, 0.45))
		draw_circle(center, radius * 2.6, Color(color, 0.13 + 0.05 * sin(_clock * 6.0 + id)))
		draw_colored_polygon(_diamond(center, radius + 1.5), INK)
		draw_colored_polygon(_diamond(center, radius), color)
		_box(center.x - 1, center.y - radius + 1, 2, 2, Color("#f4fffb"))
		if fmod(_clock * 1.3 + id * 0.37, 1.0) < 0.12:
			_box(center.x - radius - 3, center.y, radius * 2.0 + 6, 1, Color(1, 1, 1, 0.8))
			_box(center.x, center.y - radius - 3, 1, radius * 2.0 + 6, Color(1, 1, 1, 0.8))


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])


## Fading red copies of the charging boss (motion trail).
func _draw_ghosts() -> void:
	var sprite: Dictionary = _sprites[ENEMY_SPRITES.boss]
	var texture: Texture2D = sprite.run[0]
	for ghost: Dictionary in _feedback.ghosts:
		var fade: float = clampf(float(ghost.life) / 0.22, 0.0, 1.0)
		_draw_sprite(_flash_textures[texture], Vector2(ghost.pos).round(), float(ghost.face), 24.0, {"alpha": 0.45 * fade, "tint": Color("#ff6a5c"), "scale": Vector2(1.2, 0.88)})


## Floor telegraphs under the actors: the charge lane, the jump's landing zone
## and the warning ripples before the rings.
func _draw_boss_floor(enemy: Dictionary) -> void:
	if not bool(enemy.get("boss", false)) or float(enemy.get("dying_p", -1.0)) >= 0.0:
		return
	var move: String = str(enemy.get("move", ""))
	var attack: String = str(enemy.get("attack", ""))
	var p: float = float(enemy.get("attack_p", 0.0))
	var point: Vector2 = _position(enemy)
	match move:
		"charge":
			if attack != "windup":
				return
			var aim := Vector2(float(enemy.get("aim_x", -1.0)), float(enemy.get("aim_y", 0.0))).normalized()
			var side: Vector2 = aim.orthogonal() * 24.0
			var start: Vector2 = point + Vector2(0, 10)
			var finish: Vector2 = start + aim * 430.0
			var alpha: float = 0.1 + 0.22 * p
			# The lane blinks once the aim is locked: the last moment to step aside.
			if p > 0.68 and fmod(_clock, 0.1) < 0.05:
				alpha += 0.15
			draw_colored_polygon(PackedVector2Array([start + side, finish + side, finish - side, start - side]), Color(WARN, alpha))
			for k in range(6):
				var along: float = 40.0 + fmod(_clock * 220.0 + k * 70.0, 390.0)
				var tip: Vector2 = start + aim * along
				draw_line(tip - aim * 10.0 + aim.orthogonal() * 10.0, tip, Color(WARN, 0.5 * p + 0.2), 3.0)
				draw_line(tip - aim * 10.0 - aim.orthogonal() * 10.0, tip, Color(WARN, 0.5 * p + 0.2), 3.0)
		"slam":
			if attack != "windup" and attack != "active":
				return
			var target := Vector2(float(enemy.get("tx", point.x)), float(enemy.get("ty", point.y))) + Vector2(0, 14)
			var reach: float = float(enemy.get("reach", 78.0))
			var progress: float = p * 0.3 if attack == "windup" else 0.3 + 0.7 * p
			draw_circle(target, reach, Color(WARN, 0.08 + 0.2 * progress))
			draw_arc(target, reach, 0.0, TAU, 48, Color(WARN, 0.6), 2.0)
			# The inner ring closes on the outline exactly when the boss lands.
			draw_arc(target, maxf(4.0, reach * (1.0 - progress)), 0.0, TAU, 40, Color("#ffd2a0", 0.7), 2.0)
			draw_line(target - Vector2(10, 0), target + Vector2(10, 0), Color(WARN, 0.7), 2.0)
			draw_line(target - Vector2(0, 10), target + Vector2(0, 10), Color(WARN, 0.7), 2.0)
		"rings":
			if attack != "windup":
				return
			for k in range(2):
				var radius: float = 30.0 + 70.0 * fmod(p * 1.6 + k * 0.5, 1.0)
				draw_arc(point + Vector2(0, 10), radius, 0.0, TAU, 40, Color("#f19791", 0.5 * (1.0 - radius / 100.0) + 0.1), 2.0)


## Effects drawn over the actors: the volley's glowing mouth and aim fan, and
## the ultimate beam (darkened room, flickering warning line, then the beam).
func _draw_boss_overlay(enemy: Dictionary) -> void:
	if not bool(enemy.get("boss", false)) or float(enemy.get("dying_p", -1.0)) >= 0.0:
		return
	var move: String = str(enemy.get("move", ""))
	var attack: String = str(enemy.get("attack", ""))
	var p: float = float(enemy.get("attack_p", 0.0))
	var mouth := Vector2(float(enemy.get("ox", 0.0)), float(enemy.get("oy", 0.0)))
	match move:
		"volley":
			if attack != "windup":
				return
			draw_circle(mouth, 3.0 + 9.0 * p, Color(FIRE, 0.25 + 0.4 * p))
			draw_circle(mouth, 2.0 + 4.0 * p, Color("#ffe2a8", 0.6 * p))
			if p > 0.55:
				var aim := Vector2(float(enemy.get("aim_x", -1.0)), float(enemy.get("aim_y", 0.0))).normalized()
				for k in range(-1, 2):
					var ray: Vector2 = aim.rotated(k * 0.42)
					draw_line(mouth, mouth + ray * 120.0, Color(FIRE, 0.25 * (p - 0.55) / 0.45), 2.0)
		"beam":
			var end := Vector2(float(enemy.get("bx", mouth.x)), float(enemy.get("by", mouth.y)))
			if attack == "windup":
				draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color(0.02, 0.0, 0.04, 0.3 * p))
				var blink: bool = p > 0.75 and fmod(_clock, 0.08) < 0.04
				draw_line(mouth, end, Color(WARN, 0.25 + 0.5 * p + (0.25 if blink else 0.0)), 1.0 + 4.0 * p)
				draw_circle(mouth, 4.0 + 12.0 * p, Color("#ffb070", 0.3 + 0.5 * p))
				draw_circle(mouth, 2.0 + 5.0 * p, Color(1, 1, 1, 0.8 * p))
			elif attack == "active":
				draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color(0.02, 0.0, 0.04, 0.32))
				var wobble: float = sin(_clock * 50.0) * 3.0
				# Full width until the last 15 %, then it narrows and dies out.
				var width: float = 30.0 * (1.0 - smoothstep(0.85, 1.0, p)) + wobble
				draw_line(mouth, end, Color(BEAM, 0.3), width * 1.7)
				draw_line(mouth, end, BEAM, width)
				draw_line(mouth, end, Color("#ffd2a0"), width * 0.55)
				draw_line(mouth, end, Color.WHITE, width * 0.25)
				draw_circle(end, width * 0.75, Color("#ffd2a0", 0.8))
				draw_circle(mouth, width * 0.42, Color.WHITE)



## The stone golem: each move plays its own frames from the sheet, picked by
## phase and progress, so the axe is raised in the windup, swings on the active
## frame and the body crumbles in the death frames. Facing flips the frames.
func _draw_golem(enemy: Dictionary) -> void:
	var point: Vector2 = _position(enemy).round()
	var move: String = str(enemy.get("move", ""))
	var attack: String = str(enemy.get("attack", ""))
	var p: float = float(enemy.get("attack_p", 0.0))
	var dying: float = float(enemy.get("dying_p", -1.0))
	var texture: Texture2D
	if dying >= 0.0:
		texture = _golem_frame("death", dying)
	elif attack == "windup" or attack == "active" or attack == "recovery":
		texture = _golem_move_frame(move, attack, p)
	elif bool(enemy.get("axe_out", false)):
		texture = _golem.unarmed[0]
	elif bool(enemy.get("moving", false)):
		texture = _golem_loop("walk", 9.0, int(enemy.get("id", 0)))
	else:
		texture = _golem_loop("idle", 6.0, int(enemy.get("id", 0)))
	var pose: Dictionary = _feedback.pose("e%d" % int(enemy.get("id", 0)), enemy, _clock)
	_draw_sprite(texture, point, float(enemy.get("face", -1.0)), GOLEM_FEET, pose, 1.0)


func _golem_move_frame(move: String, attack: String, p: float) -> Texture2D:
	match move:
		"cleave":
			# Frames 0-7 raise the axe, 8-11 swing it through.
			if attack == "windup": return _golem_range("cleave", 0, 7, p)
			if attack == "active": return _golem_range("cleave", 8, 11, p)
			return _golem_range("cleave", 11, 11, p)
		"barrage":
			if attack == "windup": return _golem_range("barrage", 0, 3, p)
			if attack == "active": return _golem_loop("barrage", 12.0, 0, 4)
		"quake":
			if attack == "windup": return _golem_range("quake", 0, 4, p)
			return _golem_range("quake", 5, 6, p)
		"axe":
			if attack == "windup": return _golem_range("cleave", 0, 5, p)
			if attack == "active": return _golem.unarmed[0]
			return _golem.catch[0]
		"boulder":
			if attack == "windup": return _golem_range("barrage", 0, 3, p)
			if attack == "active": return _golem.throw[0]
		"channel":
			return _golem_loop("channel", 12.0, 0)
		"thorns":
			return _golem_loop("rage", 10.0, 0)
	return _golem_loop("idle", 6.0, 0)


## Frame `first`..`last` of an animation by progress 0..1.
func _golem_range(animation: String, first: int, last: int, progress: float) -> Texture2D:
	var frames: Array = _golem[animation]
	var index: int = first + mini(int(progress * float(last - first + 1)), last - first)
	return frames[clampi(index, 0, frames.size() - 1)]


func _golem_frame(animation: String, progress: float) -> Texture2D:
	return _golem_range(animation, 0, _golem[animation].size() - 1, progress)


func _golem_loop(animation: String, fps: float, phase: int, first: int = 0) -> Texture2D:
	var frames: Array = _golem[animation]
	var count: int = frames.size() - first
	return frames[first + (int(_clock * fps) + absi(phase)) % count]


## Attack telegraphs by pattern: the dash lane, the cleave cone and the pound
## ring (mobs and mini-bosses), plus the necromancer's summoning circle.
func _draw_mob_telegraph(enemy: Dictionary) -> void:
	if str(enemy.get("attack", "")) != "windup" or float(enemy.get("dying_p", -1.0)) >= 0.0:
		return
	var point: Vector2 = _position(enemy)
	var p: float = float(enemy.get("attack_p", 0.0))
	var aim := Vector2(float(enemy.get("aim_x", 1.0)), float(enemy.get("aim_y", 0.0))).normalized()
	var blink: float = 0.2 if p > 0.7 and fmod(_clock, 0.1) < 0.05 else 0.0
	var mini: bool = str(enemy.get("kind", "")).begins_with("n_")
	# The big bosses draw their own telegraphs.
	var pattern: String = str(enemy.get("pattern", "")) if mini or not bool(enemy.get("boss", false)) else ""
	match pattern:
		"dash":
			var width: float = float(enemy.get("radius", 12.0)) * 0.9 if mini else 10.0
			draw_line(point + Vector2(0, 8), point + Vector2(0, 8) + aim * (220.0 if mini else 140.0), Color(WARN, 0.15 + 0.35 * p + blink), width)
		"cleave":
			var reach: float = 90.0 if mini else 72.0
			var cone := PackedVector2Array([point])
			for k in range(9):
				cone.append(point + aim.rotated(-1.0 + 2.0 * k / 8.0) * reach)
			draw_colored_polygon(cone, Color(WARN, 0.08 + 0.22 * p + blink))
		"pound":
			draw_arc(point + Vector2(0, 8), 60.0, 0.0, TAU, 40, Color(WARN, 0.25 + 0.45 * p + blink), 2.0)
			draw_circle(point + Vector2(0, 8), 60.0 * p, Color(WARN, 0.1))
	match str(enemy.get("kind", "")):
		"necromancer":
			draw_arc(point + Vector2(0, 12), 16.0 + 14.0 * p, 0.0, TAU, 24, Color("#a77be8", 0.3 + 0.5 * p), 2.0)
			draw_arc(point + Vector2(0, 12), 30.0 - 10.0 * p, _clock * 3.0, _clock * 3.0 + PI, 12, Color("#d6b3ff", 0.6 * p), 2.0)


## Floor hazards. `over` false draws the warnings on the floor; true draws the
## eruptions, the flying boulder and the spinning axe above the actors.
func _draw_hazards(over: bool) -> void:
	for value: Variant in _snapshot.get("hazards", []):
		var hazard: Dictionary = value
		var point := Vector2(float(hazard.get("x", 0.0)), float(hazard.get("y", 0.0)))
		var kind: String = str(hazard.get("k", ""))
		var state: String = str(hazard.get("s", ""))
		var p: float = float(hazard.get("p", 0.0))
		var radius: float = float(hazard.get("r", 30.0))
		if not over:
			if state == "warn":
				var color: Color = HAZARD_COLORS.get(kind, Color("#9be05a"))
				draw_circle(point, radius, Color(color, 0.08 + 0.22 * p))
				draw_arc(point, radius, 0.0, TAU, 28, Color(color, 0.5 + 0.4 * p), 2.0)
				draw_arc(point, maxf(3.0, radius * (1.0 - p)), 0.0, TAU, 20, Color(1, 1, 1, 0.5 * p), 1.5)
			elif state == "armed" and _orcs.has("trap"):
				var trap: Texture2D = _orcs.trap
				draw_texture_rect(trap, Rect2(point - Vector2(trap.get_width(), trap.get_height()) * 0.5, Vector2(trap.get_width(), trap.get_height())), false)
			elif state == "fly":
				var goal := Vector2(float(hazard.get("gx", point.x)), float(hazard.get("gy", point.y)))
				draw_circle(goal, radius, Color(WARN, 0.06 + 0.2 * p))
				draw_arc(goal, radius, 0.0, TAU, 32, Color(WARN, 0.6), 2.0)
				draw_arc(goal, maxf(4.0, radius * (1.0 - p)), 0.0, TAU, 28, Color("#ffd2a0", 0.7), 2.0)
				# Shadow of the boulder on the floor along its path.
				_box(point.x - 10, point.y + 4, 20, 5, Color(0.05, 0.04, 0.09, 0.4))
			continue
		match state:
			"burst":
				if kind == "trap" and _orcs.has("trap"):
					# Snapped shut: the trap jumps and flashes.
					var trap: Texture2D = _orcs.trap
					var jump: float = sin(minf(p * 4.0, 1.0) * PI) * 4.0
					draw_texture_rect(trap, Rect2(point - Vector2(trap.get_width() * 0.5, trap.get_height() * 0.5 + jump), Vector2(trap.get_width(), trap.get_height())), false, Color(1.4, 1.0, 1.0))
					continue
				if kind in ["arcane", "fire_burst"]:
					var color: Color = Color("#7ff0a0") if kind == "arcane" else Color("#ff9a3c")
					draw_circle(point, radius * (0.4 + 0.6 * p), Color(color, 0.25 * (1.0 - p)))
					draw_arc(point, radius * (0.4 + 0.6 * p), 0.0, TAU, 24, Color(color, 1.0 - p), 3.0)
					continue
				var spec: Array = HAZARD_BURSTS.get(kind, HAZARD_BURSTS.thorns)
				var source: Dictionary = _golem if spec[0] == "golem" else _infernal.get(spec[0], {})
				var frames: Array = source.get(spec[1], [])
				if not frames.is_empty():
					var texture: Texture2D = frames[mini(int(p * frames.size()), frames.size() - 1)]
					var size := Vector2(texture.get_width(), texture.get_height()) * float(spec[2])
					# Bursts rise out of the floor: a quick grow, then fade.
					var grow: float = 0.6 + 0.4 * smoothstep(0.0, 0.25, p)
					size *= Vector2(1.0, grow)
					draw_texture_rect(texture, Rect2(point - Vector2(size.x * 0.5, size.y * (0.5 if kind == "blast" else 0.85)), size), false, Color(1, 1, 1, 1.0 - smoothstep(0.6, 1.0, p)))
			"fly" when kind == "bomb":
				# A lit bomb lobbed in an arc, fuse sparking.
				var top: Vector2 = point - Vector2(0, sin(PI * p) * 60.0)
				draw_circle(top, 7.0, INK)
				draw_circle(top, 6.0, Color("#2a2a32"))
				_box(top.x - 2, top.y - 3, 2, 2, Color("#8a8a96"))
				draw_circle(top + Vector2(3, -8), 2.0 + sin(_clock * 40.0), Color("#ffc23c"))
			"fly":
				# The boulder arcs through the air and turns green before it lands.
				var lift: float = sin(PI * p) * 70.0
				var frames: Array = _golem.get("boulder", [])
				if not frames.is_empty():
					var texture: Texture2D = frames[mini(int(p * frames.size()), frames.size() - 1)]
					var size := Vector2(texture.get_width(), texture.get_height()) * 0.8
					draw_set_transform(point - Vector2(0, lift), _clock * 8.0, Vector2.ONE)
					draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"out", "back":
				var spin: Array = _golem.get("axe_spin", [])
				if not spin.is_empty():
					var texture: Texture2D = spin[0]
					var size := Vector2(texture.get_width(), texture.get_height()) * 0.7
					draw_circle(point, 20.0, Color("#7fe8e0", 0.15))
					draw_set_transform(point, _clock * 18.0, Vector2.ONE)
					draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_special_bullet(kind: String, point: Vector2, angle: float) -> void:
	match kind:
		"arrow":
			var size := Vector2(ARROW_TEXTURE.get_width(), ARROW_TEXTURE.get_height()) * 1.6
			draw_set_transform(point, angle + PI * 0.5, Vector2.ONE)
			draw_texture_rect(ARROW_TEXTURE, Rect2(-size * 0.5, size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		"magic", "firemagic", "shard":
			var core: Color = Color("#7ff0a0") if kind != "firemagic" else Color("#ff9a3c")
			var radius: float = 3.0 if kind == "shard" else 6.0 + sin(_clock * 20.0)
			draw_circle(point, radius * 2.2, Color(core, 0.2))
			draw_circle(point, radius, core)
			draw_circle(point, radius * 0.45, Color.WHITE)
			return
		"orc_arrow":
			var size := Vector2(ARROW_TEXTURE.get_width(), ARROW_TEXTURE.get_height()) * 1.4
			draw_set_transform(point, angle + PI * 0.5, Vector2.ONE)
			draw_texture_rect(ARROW_TEXTURE, Rect2(-size * 0.5, size), false, Color(1.0, 0.75, 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		"spear":
			var along := Vector2.RIGHT.rotated(angle)
			draw_line(point - along * 16.0, point + along * 6.0, INK, 4.0)
			draw_line(point - along * 16.0, point + along * 6.0, Color("#8a5a32"), 2.0)
			draw_colored_polygon(PackedVector2Array([point + along * 12.0, point + along * 4.0 + along.orthogonal() * 4.0, point + along * 4.0 - along.orthogonal() * 4.0]), Color("#d8dce6"))
			return
		"flail":
			_box(point.x - 4, point.y - 4, 8, 8, INK)
			_box(point.x - 3, point.y - 3, 6, 6, Color("#6a6a74"))
			_box(point.x - 1, point.y - 5, 2, 10, Color("#9a9aa4"))
			_box(point.x - 5, point.y - 1, 10, 2, Color("#9a9aa4"))
			return
		"wave":
			var along := Vector2.RIGHT.rotated(angle)
			draw_arc(point - along * 8.0, 18.0, angle - 1.0, angle + 1.0, 12, Color("#bff6ff", 0.9), 4.0)
			draw_arc(point - along * 10.0, 18.0, angle - 0.8, angle + 0.8, 10, Color.WHITE, 2.0)
			return
	var sprite: Array = []
	match kind:
		"fireball": sprite = ["fackelteufel", "fireball", 0.5]
		"bigfire": sprite = ["molgrax", "fireball", 0.45]
		"flame": sprite = ["fackelteufel", "fireball", 0.32]
		"void": sprite = ["schattling", "void_orb", 0.6]
	if not sprite.is_empty() and _infernal.has(sprite[0]):
		var texture: Texture2D = _infernal[sprite[0]][sprite[1]][0]
		var size := Vector2(texture.get_width(), texture.get_height()) * float(sprite[2])
		# The art flies to the right with its tail behind; turn it along the flight.
		draw_set_transform(point, angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.8, -size.y * 0.5), size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match kind:
		"slash":
			var frames: Array = _golem.get("slash", [])
			if not frames.is_empty():
				var texture: Texture2D = frames[0]
				var size := Vector2(texture.get_width(), texture.get_height()) * 0.55
				draw_set_transform(point, angle, Vector2.ONE)
				draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				return
		"rock":
			var frames: Array = _golem.get("spike", [])
			if not frames.is_empty():
				var texture: Texture2D = frames[0]
				var size := Vector2(texture.get_width(), texture.get_height()) * 0.45
				draw_set_transform(point, _clock * 10.0, Vector2.ONE)
				draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				return
		"bolt":
			draw_circle(point, 8.0, Color("#9be05a", 0.25))
			_box(point.x - 4, point.y - 4, 8, 8, INK)
			_box(point.x - 3, point.y - 3, 6, 6, Color("#9be05a"))
			_box(point.x - 1, point.y - 2, 2, 2, Color("#eaffd0"))
			return
		"bone":
			var along := Vector2.RIGHT.rotated(angle + _clock * 12.0) * 5.0
			draw_line(point - along, point + along, INK, 5.0)
			draw_line(point - along, point + along, Color("#e8e2d0"), 3.0)
			return
	_box(point.x - 3, point.y - 3, 6, 6, Color("#f19791"))



## Infernal creatures: idle frames while standing or walking (faster when
## moving), the attack frames while an attack is active, the hurt frame right
## after a hit and the death frames while dying. Molgrax picks per move.
func _draw_infernal(enemy: Dictionary) -> void:
	var kind: String = str(enemy.get("kind", ""))
	var frames: Dictionary = _infernal[kind]
	var point: Vector2 = _position(enemy).round()
	var attack: String = str(enemy.get("attack", ""))
	var p: float = float(enemy.get("attack_p", 0.0))
	var dying: float = float(enemy.get("dying_p", -1.0))
	var id: int = int(enemy.get("id", 0))
	var texture: Texture2D
	if dying >= 0.0:
		texture = _pick(frames.death, dying)
	elif kind == "molgrax":
		texture = _molgrax_frame(frames, str(enemy.get("move", "")), attack, p, bool(enemy.get("moving", false)), id)
	elif (attack == "active" or attack == "recovery") and frames.has(INFERNAL_ACTIVE.get(kind, "")):
		texture = _pick(frames[INFERNAL_ACTIVE[kind]], p if attack == "active" else 1.0)
	elif attack == "windup" and kind == "stachelwaechter":
		texture = frames.claw[0]
	elif bool(enemy.get("hit", false)) and frames.has("hurt"):
		texture = frames.hurt[0]
	else:
		var idle: Array = frames.idle
		var fps: float = 11.0 if bool(enemy.get("moving", false)) else 6.0
		texture = idle[(int(_clock * fps) + id) % idle.size()]
	var feet: float = 33.0 if kind == "molgrax" else 15.0
	_draw_sprite(texture, point, float(enemy.get("face", -1.0)), feet, _feedback.pose("e%d" % id, enemy, _clock), 1.0)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	if dying < 0.0 and hp < max_hp and kind != "molgrax":
		var bar_y: float = point.y + feet - float(texture.get_height()) - 6.0
		_box(point.x - 15, bar_y - 2, 30, 7, INK)
		_box(point.x - 13, bar_y, 26, 3, Color("#5e354d"))
		_box(point.x - 13, bar_y, floorf(26.0 * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a"))


func _molgrax_frame(frames: Dictionary, move: String, attack: String, p: float, moving: bool, id: int) -> Texture2D:
	if attack.is_empty():
		var loop: Array = frames.walk if moving else frames.idle
		return loop[(int(_clock * (10.0 if moving else 6.0)) + id) % loop.size()]
	match move:
		"swipe":
			if attack == "windup": return _pick_range(frames.swipe, 0, 3, p)
			if attack == "active": return _pick_range(frames.swipe, 4, 6, p)
			return frames.swipe[6]
		"fireball":
			if attack == "windup": return _pick_range(frames.throw, 0, 2, p)
			return _pick_range(frames.throw, 3, 5, fmod(_clock * 3.0, 1.0))
		"slam":
			if attack == "windup": return _pick_range(frames.slam, 0, 4, p)
			if attack == "active": return _pick_range(frames.slam, 5, 7, p)
			return _pick_range(frames.slam, 7, 9, p)
		"eruption":
			if attack == "windup": return _pick_range(frames.eruption, 0, 4, p)
			return _pick_range(frames.eruption, 5, 7, fmod(_clock * 2.0, 1.0))
		"void":
			if attack == "windup": return _pick_range(frames.void, 0, 3, p)
			return _pick_range(frames.void, 4, 10, p)
		"inferno":
			if attack == "recovery": return _pick(frames.stagger, p)
			return frames.rage[int(_clock * 10.0) % frames.rage.size()]
	return frames.idle[0]


func _pick(frames: Array, progress: float) -> Texture2D:
	return frames[clampi(int(progress * frames.size()), 0, frames.size() - 1)]


func _pick_range(frames: Array, first: int, last: int, progress: float) -> Texture2D:
	return frames[clampi(first + mini(int(progress * float(last - first + 1)), last - first), 0, frames.size() - 1)]



## The held weapon at the hero's hand, pointing where they aim. A sword sweeps
## through its arc while a swing is shown, with a pale crescent trailing it.
func _draw_weapon(player: Dictionary, point: Vector2, aim: Vector2, pose: Dictionary) -> void:
	var weapons: Array = player.get("weapons", [])
	var weapon_id: String = str(weapons[clampi(int(player.get("weapon_index", 0)), 0, weapons.size() - 1)]) if not weapons.is_empty() else ""
	var hand: Vector2 = point + aim * 10.0 + Vector2(0, 2)
	if not _weapon_textures.has(weapon_id):
		draw_line(hand, hand + aim * 10.0, INK, 7.0)
		draw_line(hand, hand + aim * 10.0, Color("#c3b3ad"), 3.0)
		return
	var texture: Texture2D = _weapon_textures[weapon_id]
	var angle: float = aim.angle()
	var swing: float = float(pose.get("swing", 0.0))
	var melee: bool = weapon_id in ["sword", "greatsword"]
	if melee and swing > 0.0:
		var swing_angle: float = float(player.get("swing_a", angle))
		var arc: float = minf(float(player.get("swing_arc", 2.0)), TAU)
		var progress: float = 1.0 - swing
		angle = swing_angle - arc * 0.5 + arc * ease(progress, 0.4)
		var reach: float = float(player.get("reach", 60.0))
		var from: float = swing_angle - arc * 0.5
		draw_arc(point, reach * 0.85, from, angle, 24, Color("#eaf8ff", 0.55 * swing), 10.0 * swing + 2.0)
		draw_arc(point, reach * 0.85, from, angle, 24, Color.WHITE, 2.0)
		hand = point + Vector2.RIGHT.rotated(angle) * 12.0 + Vector2(0, 2)
	var size := Vector2(texture.get_width(), texture.get_height()) * 2.0
	# The art points up; turn it along the aim. Swords are held by the grip,
	# bows and staffs in the middle.
	draw_set_transform(hand, angle + PI * 0.5, Vector2.ONE)
	draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y * (0.9 if melee else 0.5)), size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Chests in a cleared room: a closed one glints until a hero walks into it.
func _draw_loot() -> void:
	for value: Variant in _snapshot.get("loot", []):
		var chest: Dictionary = value
		var point: Vector2 = _position(chest).round()
		var open: bool = bool(chest.get("open", false))
		var texture: Texture2D = CHEST_OPEN if open else CHEST_CLOSED
		var size := Vector2(texture.get_width(), texture.get_height()) * 2.0
		_box(point.x - 14, point.y + 12, 28, 5, Color(0.05, 0.04, 0.09, 0.45))
		if not open:
			draw_circle(point, 22.0, Color(1.0, 0.85, 0.45, 0.1 + 0.05 * sin(_clock * 4.0)))
			if fmod(_clock * 0.9 + float(chest.get("id", 0)) * 0.3, 1.0) < 0.1:
				_box(point.x + 8, point.y - 14, 2, 6, Color(1, 1, 1, 0.9))
				_box(point.x + 6, point.y - 12, 6, 2, Color(1, 1, 1, 0.9))
		draw_texture_rect(texture, Rect2(point - Vector2(size.x * 0.5, size.y * 0.6), size), false)


func _draw_orc(enemy: Dictionary) -> void:
	var kind: String = str(enemy.get("kind", ""))
	var texture: Texture2D = _orcs[kind]
	var point: Vector2 = _position(enemy).round()
	var id: int = int(enemy.get("id", 0))
	# Frames: breathing while standing, stepping while walking, leaning back to
	# wind up and lunging on the strike.
	var sets: Dictionary = _orc_frames.get(kind, {})
	var attack: String = str(enemy.get("attack", ""))
	# Sheet kinds are 16 px art drawn at their own scale and bring hit and death frames.
	var pixel_scale: float = float(SHEET_KINDS[kind][2]) if SHEET_KINDS.has(kind) else 1.0
	if sets.has("death") and float(enemy.get("dying_p", -1.0)) >= 0.0:
		texture = _pick(sets.death, float(enemy.dying_p) / 0.7)
	elif not sets.is_empty() and float(enemy.get("dying_p", -1.0)) < 0.0:
		if sets.has("hit") and bool(enemy.get("hit", false)): texture = sets.hit[int(_clock * 12.0) % sets.hit.size()]
		elif attack == "windup": texture = _pick(sets.windup, float(enemy.get("attack_p", 0.0)))
		elif attack == "active": texture = sets.strike[0]
		elif attack == "recovery": texture = sets.strike[1]
		elif bool(enemy.get("moving", false)) or bool(enemy.get("dash", false)): texture = sets.walk[(int(_clock * 10.0) + id) % sets.walk.size()]
		else: texture = sets.idle[(int(_clock * 5.0) + id) % sets.idle.size()]
	var pose: Dictionary = _feedback.pose("e%d" % id, enemy, _clock)
	var elite: bool = bool(enemy.get("elite", false))
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	if elite and not dying:
		draw_circle(point + Vector2(0, 8), float(enemy.get("radius", 14.0)) + 8.0, Color(0.9, 0.15, 0.1, 0.16 + 0.06 * sin(_clock * 6.0)))
		pose.scale = Vector2(pose.scale) * 1.2
	if bool(enemy.get("raging", false)) and not dying:
		draw_circle(point, float(enemy.get("radius", 14.0)) + 4.0, Color(1.0, 0.2, 0.1, 0.22))
	if bool(enemy.get("hasted", false)) and not dying:
		_box(point.x - 10 + roundf(sin(_clock * 30.0 + id) * 8.0), point.y + 10, 3, 3, Color("#ffd76a"))
	var feet: float = float(enemy.get("radius", 12.0)) * 0.6 + 6.0
	_draw_sprite(texture, point, float(enemy.get("face", -1.0)), feet, pose, pixel_scale)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	if not dying and hp < max_hp and not bool(enemy.get("boss", false)):
		var bar_y: float = point.y + feet - float(texture.get_height()) * pixel_scale * float(Vector2(pose.scale).y) - 6.0
		_box(point.x - 15, bar_y - 2, 30, 7, INK)
		_box(point.x - 13, bar_y, 26, 3, Color("#5e354d"))
		_box(point.x - 13, bar_y, floorf(26.0 * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a") if not elite else Color("#ff5a3a"))

extends Node2D
## Pixel chamber presentation for Basement Run. Receives authoritative state;
## owns no combat, movement, rewards, or networking decisions.

const ROOM_SIZE := Vector2(896, 480)
const INK := Color("#10101c")
const GROUT := Color("#242334")
const STONE := Color("#363348")
const STONE_LIGHT := Color("#454058")
const STONE_DARK := Color("#2c293e")
const GOLD := Color("#efc76a")
const MUTED := Color("#77728b")
const PLAYER_COLORS := [
	Color("#72dcc8"), Color("#edb563"), Color("#bc91de"), Color("#ed8a91")
]
const TORCH_TEXTURE := preload("res://assets/sprites/torch.png")
const FLOOR_TEXTURE := preload("res://assets/sprites/floor_stone.png")

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
const CHEST_CLOSED := preload("res://assets/sprites/0x72/chest_full_open_anim_f0.png")
const CHEST_OPEN := preload("res://assets/sprites/0x72/chest_full_open_anim_f2.png")
const ENEMY_SPRITES := {"chaser": "goblin", "shooter": "orc_shaman", "boss": "big_demon", "imp": "imp", "skelet": "skelet", "necromancer": "necromancer", "tiny_zombie": "tiny_zombie"}
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
var _feedback := Feedback.new()
var _base_position := Vector2.ZERO
var _shake_rng := RandomNumberGenerator.new()
## 0 turns screen shake off (player option), 1 is full strength.
var shake_scale := 1.0


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
	var orcs: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORC_ROOT + "manifest.json"))
	if orcs is Dictionary:
		for name: String in orcs: _orcs[name] = load(ORC_ROOT + name + ".png")
	var orc_frames: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORC_ROOT + "frames/frames.json"))
	if orc_frames is Dictionary:
		for name: String in orc_frames:
			var sets := {}
			for animation: String in orc_frames[name]:
				var list: Array = []
				for frame in range(int(orc_frames[name][animation])):
					list.append(load("%sframes/%s_%s_f%d.png" % [ORC_ROOT, name, animation, frame]))
				sets[animation] = list
			_orc_frames[name] = sets
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
	position = _base_position + Vector2(_shake_rng.randf_range(-1, 1), _shake_rng.randf_range(-1, 1)).round() * roundf(strength)
	queue_redraw()


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
	_draw_floor()
	_draw_chamber_details()
	_draw_walls()
	_draw_obstacles()
	_draw_brazier(Vector2(72, 78), 0.0)
	_draw_brazier(Vector2(824, 78), 1.8)
	_draw_brazier(Vector2(72, 402), 2.5)
	_draw_brazier(Vector2(824, 402), 0.8)
	var phase: String = str(_snapshot.get("phase", "lobby"))
	if phase == "reward" or phase == "victory":
		_draw_pedestal(phase == "victory")
	_feedback.particles.draw_stains(self)
	_draw_orbs()
	_draw_loot()
	var enemies: Array = _snapshot.get("enemies", [])
	var players: Dictionary = _snapshot.get("players", {})
	for enemy_value: Variant in enemies:
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


func _box(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), width, height), color)


func _position(entity: Dictionary) -> Vector2:
	return Vector2(float(entity.get("x", 448.0)), float(entity.get("y", 240.0)))


func _room_layout() -> Dictionary:
	var layout: Variant = _snapshot.get("room_layout", {})
	return layout if layout is Dictionary else {}


func _room_accent() -> Color:
	var fallback := Color("#ab856b")
	var value: Variant = _room_layout().get("accent_color", fallback)
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, fallback)
	return fallback


func _draw_floor() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), GROUT)
	var room_seed: int = int(_snapshot.get("seed", 0)) + str(_room_layout().get("template_id", "")).hash() % 997
	for row: int in range(15):
		for column: int in range(28):
			var tile_hash: int = absi(column * 73 + row * 137 + room_seed % 997)
			var modulation := Color.WHITE
			if tile_hash % 7 < 2:
				modulation = Color(0.84, 0.84, 0.88)
			elif tile_hash % 11 == 0:
				modulation = Color(1.08, 1.03, 1.07)
			var x: float = float(column * 32)
			var y: float = float(row * 32)
			draw_texture_rect(FLOOR_TEXTURE, Rect2(x, y, 32, 32), false, modulation)
			if tile_hash % 9 == 0:
				_box(x + 8, y + 10, 7, 2, Color("#50485e"))
				_box(x + 15, y + 12, 2, 5, Color("#252334"))
			if tile_hash % 13 == 0:
				_box(x + 23, y + 23, 3, 2, Color("#55485c"))
	# A worn inset border gives the chamber a deliberate architectural shape.
	draw_rect(Rect2(47, 47, 802, 386), Color("#6b566b"), false, 2.0)
	draw_rect(Rect2(52, 52, 792, 376), Color("#282637"), false, 2.0)
	var accent: Color = _room_accent()
	for x: int in range(96, 816, 64):
		_box(x, 46, 6, 4, accent)
		_box(x, 430, 6, 4, accent)


func _draw_chamber_details() -> void:
	var center := Vector2(448, 240)
	var accent: Color = _room_accent().darkened(0.4)
	var outline := PackedVector2Array([
		center + Vector2(-54, -72), center + Vector2(54, -72),
		center + Vector2(72, -54), center + Vector2(72, 54),
		center + Vector2(54, 72), center + Vector2(-54, 72),
		center + Vector2(-72, 54), center + Vector2(-72, -54),
		center + Vector2(-54, -72)
	])
	draw_polyline(outline, Color("#514456"), 3.0)
	draw_rect(Rect2(405, 197, 86, 86), Color("#4c4051"), false, 2.0)
	draw_line(Vector2(421, 240), Vector2(475, 240), accent, 3.0)
	draw_line(Vector2(448, 213), Vector2(448, 267), accent, 3.0)
	for point: Vector2 in [Vector2(124, 131), Vector2(749, 345), Vector2(153, 365), Vector2(732, 108)]:
		_box(point.x, point.y + 4, 16, 5, Color("#222130"))
		_box(point.x + 2, point.y, 6, 6, Color("#625366"))
		_box(point.x + 12, point.y + 5, 4, 3, Color("#7d666d"))
	# Loose bones and a broken chain: small, restrained floor storytelling.
	_box(682, 385, 24, 3, Color("#b2a18c"))
	_box(681, 382, 4, 8, Color("#c4b19b"))
	_box(704, 382, 4, 8, Color("#c4b19b"))
	for index: int in range(4):
		draw_rect(Rect2(181 + index * 8, 100 + index * 3, 8, 5), Color("#80717d"), false, 1.0)


func _draw_obstacles() -> void:
	var obstacles: Array = _room_layout().get("obstacles", [])
	var accent: Color = _room_accent()
	for value: Variant in obstacles:
		var footprint: Rect2 = _obstacle_rect(value)
		if footprint.size.x <= 0.0 or footprint.size.y <= 0.0:
			continue
		_box(footprint.position.x + 4, footprint.end.y, footprint.size.x - 8, 4, Color(0.05, 0.04, 0.09, 0.5))
		_box(footprint.position.x + 8, footprint.end.y + 4, footprint.size.x - 16, 2, Color(0.05, 0.04, 0.09, 0.22))
		# The solid masonry occupies the exact authoritative collision footprint.
		# Cap highlights stay inside it, so cover never disguises a walkable edge.
		draw_rect(footprint, INK)
		draw_rect(Rect2(footprint.position + Vector2(2, 2), footprint.size - Vector2(4, 4)), STONE_DARK)
		for row: int in range(int(ceilf(footprint.size.y / 32.0))):
			for column: int in range(int(ceilf(footprint.size.x / 32.0))):
				var point: Vector2 = footprint.position + Vector2(column * 32, row * 32)
				var tile_size := Vector2(minf(32.0, footprint.end.x - point.x), minf(32.0, footprint.end.y - point.y))
				draw_rect(Rect2(point + Vector2(2, 2), tile_size - Vector2(4, 4)), STONE)
				_box(point.x + 3, point.y + 3, tile_size.x - 6, 3, STONE_LIGHT)
				_box(point.x + 3, point.y + tile_size.y - 6, tile_size.x - 6, 3, STONE_DARK)
		# A broad dark lower face and a restrained colored cap separate solid cover
		# from the textured floor without competing with players or projectiles.
		_box(footprint.position.x + 2, footprint.end.y - 10, footprint.size.x - 4, 8, Color("#242131"))
		_box(footprint.position.x + 3, footprint.position.y + 3, footprint.size.x - 6, 3, accent.darkened(0.16))
		_box(footprint.position.x + 3, footprint.position.y + 6, 3, footprint.size.y - 18, STONE_LIGHT)
		_box(footprint.end.x - 6, footprint.position.y + 6, 3, footprint.size.y - 18, STONE_DARK)


func _obstacle_rect(value: Variant) -> Rect2:
	if value is Array and value.size() == 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if value is Dictionary:
		return Rect2(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("w", 0)), float(value.get("h", 0)))
	return Rect2()


func _draw_walls() -> void:
	_box(0, 0, 896, 40, INK)
	_box(0, 448, 896, 32, INK)
	_box(0, 0, 24, 480, INK)
	_box(872, 0, 24, 480, INK)
	for column: int in range(14):
		var x: float = float(column * 64)
		_box(x + 2, 3, 61, 18, Color("#575064"))
		_box(x + 3, 4, 59, 3, Color("#726477"))
		_box(x + 2, 23, 61, 10, Color("#3a334b"))
		_box(x + 3, 449, 59, 15, Color("#51475c"))
		_box(x + 4, 449, 57, 3, Color("#766373"))
	for row: int in range(14):
		var y: float = float(row * 32 + 16)
		_box(3, y + 1, 16, 29, Color("#484054"))
		_box(4, y + 2, 3, 27, Color("#63556c"))
		_box(876, y + 1, 16, 29, Color("#484054"))
		_box(877, y + 2, 3, 27, Color("#63556c"))
	_draw_doors()
	# Corner stone caps sit in front of the masonry.
	for point: Vector2 in [Vector2(18, 30), Vector2(850, 30), Vector2(18, 420), Vector2(850, 420)]:
		_box(point.x, point.y, 28, 28, Color("#252233"))
		_box(point.x + 2, point.y + 2, 24, 19, Color("#65546c"))
		_box(point.x + 4, point.y + 3, 20, 3, Color("#8c7183"))
		_box(point.x + 7, point.y + 9, 10, 7, Color("#493e55"))


## Recessed doorways on every wall that leads to a neighbouring room. Bars close
## them while the host keeps the room locked; the frame shows what lies beyond
## once that room is on the map (red for the boss, gold for treasure).
func _draw_doors() -> void:
	var doors: Variant = _room_layout().get("doors", {})
	if not doors is Dictionary:
		return
	var open: bool = bool(_snapshot.get("doors_open", false))
	for side: Variant in doors:
		var frame: Color = _door_frame(str(doors[side]))
		var vertical: bool = side == "north" or side == "south"
		# Each doorway is drawn in its own frame: x/y along the wall, depth inward.
		var opening: Rect2
		match side:
			"north": opening = Rect2(408, 0, 80, 40)
			"south": opening = Rect2(408, 444, 80, 36)
			"west": opening = Rect2(0, 208, 28, 80)
			"east": opening = Rect2(868, 208, 28, 80)
			_: continue
		draw_rect(opening, Color("#161522"))
		if vertical:
			_box(opening.position.x - 6, opening.position.y, 8, opening.size.y + 2, frame)
			_box(opening.end.x - 2, opening.position.y, 8, opening.size.y + 2, frame)
			for step: int in range(3):
				var y: float = opening.position.y + 18 + step * 9 if side == "north" else opening.end.y - 22 - step * 9
				_box(opening.position.x + 6, y, opening.size.x - 12, 4, Color("#3d354a").lerp(Color("#645267"), step / 2.0))
		else:
			_box(opening.position.x, opening.position.y - 6, opening.size.x + 2, 8, frame)
			_box(opening.position.x, opening.end.y - 2, opening.size.x + 2, 8, frame)
		if not open:
			if vertical:
				for x: int in range(int(opening.position.x) + 12, int(opening.end.x) - 6, 12):
					_box(x, opening.position.y, 4, opening.size.y - 4, Color("#776277"))
				_box(opening.position.x + 5, opening.position.y + opening.size.y * 0.35, opening.size.x - 9, 4, Color("#9e7a80"))
			else:
				for y: int in range(int(opening.position.y) + 12, int(opening.end.y) - 6, 12):
					_box(opening.position.x, y, opening.size.x, 4, Color("#776277"))
				_box(opening.position.x + opening.size.x * 0.4, opening.position.y + 5, 4, opening.size.y - 9, Color("#9e7a80"))


func _door_frame(room_id: String) -> Color:
	for value: Variant in _snapshot.get("floor_map", []):
		if value is Dictionary and str(value.get("id", "")) == room_id:
			match str(value.get("kind", "")):
				"boss": return Color("#b84a4f")
				"treasure": return GOLD
	return Color("#796171")


func _draw_brazier(point: Vector2, offset: float) -> void:
	var flicker: float = sin(_clock * 7.0 + offset)
	var glow := Color(0.98, 0.46, 0.24, 0.055 + 0.015 * flicker)
	_box(point.x - 36, point.y - 36, 72, 72, glow)
	_box(point.x - 24, point.y - 24, 48, 48, glow)
	draw_texture_rect(TORCH_TEXTURE, Rect2(point - Vector2(16, 20), Vector2(32, 32)), false, Color(1.0 + flicker * 0.06, 1.0, 1.0))
	_box(point.x + 10, point.y - 22 - floorf(fmod(_clock * 10.0 + offset * 4.0, 14.0)), 2, 3, Color("#edac68"))


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
	if str(enemy.get("kind", "")) == "golem" and not _golem.is_empty():
		_draw_golem(enemy)
		return
	if _infernal.has(str(enemy.get("kind", ""))):
		_draw_infernal(enemy)
		return
	if _orcs.has(str(enemy.get("kind", ""))):
		_draw_orc(enemy)
		return
	var point: Vector2 = _position(enemy).round()
	var is_boss: bool = bool(enemy.get("boss", false))
	var kind: String = "boss" if is_boss else str(enemy.get("kind", "chaser"))
	var sprite: Dictionary = _sprites[ENEMY_SPRITES.get(kind, "goblin")]
	var id: int = int(enemy.get("id", 0))
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	var texture: Texture2D = _frame(sprite, bool(enemy.get("moving", false)) and not dying, id * 3)
	var feet: float = 24.0 if is_boss else 16.0
	_draw_sprite(texture, point, float(enemy.get("face", -1.0)), feet, _feedback.pose("e%d" % id, enemy, _clock))
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	# Bosses show their health in the HUD's top bar instead.
	if not dying and hp < max_hp and not is_boss:
		var bar_width: float = 48.0 if is_boss else 26.0
		var bar_y: float = point.y + feet - float(texture.get_height() * 2) - 8.0
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
		_box(x, y, 2, 2, Color(0.94, 0.76, 0.59, alpha))



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


## Mob telegraphs: the imp's dash lane and the necromancer's summoning circle.
func _draw_mob_telegraph(enemy: Dictionary) -> void:
	if str(enemy.get("attack", "")) != "windup" or float(enemy.get("dying_p", -1.0)) >= 0.0:
		return
	var point: Vector2 = _position(enemy)
	var p: float = float(enemy.get("attack_p", 0.0))
	match str(enemy.get("kind", "")):
		"imp":
			var aim := Vector2(float(enemy.get("aim_x", 1.0)), float(enemy.get("aim_y", 0.0))).normalized()
			var alpha: float = 0.15 + 0.35 * p + (0.2 if p > 0.7 and fmod(_clock, 0.1) < 0.05 else 0.0)
			draw_line(point + Vector2(0, 8), point + Vector2(0, 8) + aim * 140.0, Color(WARN, alpha), 10.0)
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
	if not sets.is_empty() and float(enemy.get("dying_p", -1.0)) < 0.0:
		if attack == "windup": texture = _pick(sets.windup, float(enemy.get("attack_p", 0.0)))
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
	_draw_sprite(texture, point, float(enemy.get("face", -1.0)), feet, pose, 1.0)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	if not dying and hp < max_hp and not bool(enemy.get("boss", false)):
		var bar_y: float = point.y + feet - float(texture.get_height()) * float(Vector2(pose.scale).y) - 6.0
		_box(point.x - 15, bar_y - 2, 30, 7, INK)
		_box(point.x - 13, bar_y, 26, 3, Color("#5e354d"))
		_box(point.x - 13, bar_y, floorf(26.0 * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a") if not elite else Color("#ff5a3a"))

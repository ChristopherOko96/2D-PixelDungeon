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
const ENEMY_SPRITES := {"chaser": "goblin", "shooter": "orc_shaman", "boss": "big_demon"}
const SPRITE_ROOT := "res://assets/sprites/0x72/"
const FRAMES_PER_SECOND := 8.0
const Feedback = preload("res://src/vfx/feedback.gd")
const Sfx = preload("res://src/vfx/sfx.gd")
const MAX_SHAKE_PIXELS := 9.0

var _snapshot: Dictionary = {}
var _local_peer: int = 1
var _clock: float = 0.0
# name -> {"idle": [Texture2D x4], "run": [Texture2D x4], "hit": Texture2D or null}
var _sprites: Dictionary = {}
# Texture -> white silhouette of it, for hit flashes without a per-sprite shader.
var _flash_textures: Dictionary = {}
var _feedback := Feedback.new()
var _base_position := Vector2.ZERO
var _shake_rng := RandomNumberGenerator.new()


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
	var strength: float = _feedback.shake * _feedback.shake * MAX_SHAKE_PIXELS
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
	var enemies: Array = _snapshot.get("enemies", [])
	var players: Dictionary = _snapshot.get("players", {})
	for enemy_value: Variant in enemies:
		var enemy: Dictionary = enemy_value
		if float(enemy.get("dying_p", -1.0)) < 0.5:
			_draw_shadow(_position(enemy), 25.0 if bool(enemy.get("boss", false)) else 14.0)
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
	var hero: Dictionary = _sprites[HERO_SPRITES[_sprite_index(color)]]
	var hurt: bool = bool(player.get("hurt", false))
	var texture: Texture2D = _frame(hero, bool(player.get("moving", false)), peer_id)
	var pose: Dictionary = _feedback.pose("p%d" % peer_id, player, _clock)
	if hurt:
		if hero.hit != null and fmod(_clock, 0.24) < 0.12: texture = hero.hit
		pose.alpha *= 0.45 if fmod(_clock, 0.16) < 0.08 else 1.0
	_draw_sprite(texture, point, -1.0 if aim.x < -0.1 else 1.0, 16.0, pose)
	var hand: Vector2 = point + aim * 11.0 + Vector2(0, 3)
	draw_line(hand, hand + aim * 10.0, INK, 7.0)
	draw_line(hand, hand + aim * 10.0, Color("#c3b3ad"), 3.0)
	_box(hand.x - 3, hand.y - 3, 6, 6, Color("#e6b997"))
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
	if not dying and (hp < max_hp or is_boss):
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
func _draw_sprite(texture: Texture2D, point: Vector2, face: float, feet: float, pose: Dictionary) -> void:
	var size := Vector2(texture.get_width(), texture.get_height()) * 2.0
	var scale: Vector2 = pose.get("scale", Vector2.ONE)
	var alpha: float = float(pose.get("alpha", 1.0))
	var anchor: Vector2 = point + Vector2(0, feet) + Vector2(pose.get("offset", Vector2.ZERO))
	draw_set_transform(anchor, float(pose.get("lean", 0.0)), Vector2((-1.0 if face < 0.0 else 1.0) * scale.x, scale.y))
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
	var flash: float = float(pose.get("flash", 0.0))
	if flash > 0.0 and _flash_textures.has(texture):
		var color: Color = pose.get("flash_color", Color.WHITE)
		draw_texture_rect(_flash_textures[texture], rect, false, Color(color, flash * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bullet(bullet: Dictionary) -> void:
	var point: Vector2 = _position(bullet).round()
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

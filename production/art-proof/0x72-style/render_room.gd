extends SceneTree
## Style proof (not wired into the game): renders a REAL room from the game's
## dungeon generator with original 0x72 DungeonTileset II tiles at native 16 px
## per cell. Floor/structure cells come from the generator; each wall cell's
## role uses the same 8-neighbour rule as crypt_generator._wall_role, and only
## the drawing maps roles to 0x72 pieces. Usage:
##   godot --headless --path . -s res://production/art-proof/0x72-style/render_room.gd -- <0x72 frames dir> <seed> <room 1..10> <out.png>

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const T := 16
const VOID := Color("13111c")

var frames := ""
var _cache: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	frames = args[0]
	var seed_value := int(args[1])
	var room_number := int(args[2])
	var out_path := args[3]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var rooms: Array[Dictionary] = Dungeon.generate(seed_value, 10, config)
	var room: Dictionary = rooms[clampi(room_number - 1, 0, rooms.size() - 1)]
	animated.template = str(room.get("template_id", ""))
	animated.boss = bool(room.get("boss", false))
	var image := render(room, seed_value)
	image.save_png(out_path)
	# Animated props (torches, candle columns) are listed for the preview overlay.
	var overlay := FileAccess.open(out_path.get_basename() + "_props.json", FileAccess.WRITE)
	overlay.store_string(JSON.stringify(animated))
	overlay.close()
	print("ROOM_RENDERED %s %dx%d cells=%d template=%s torches=%d candles=%d" % [out_path, image.get_width(), image.get_height(), room.painted_tiles.size(), room.get("template_id", ""), animated.torches.size(), animated.candles.size()])
	quit()

var animated := {"torches": [], "candles": [], "floor": [], "players": [], "enemies": [], "doors": [], "stairs": [], "template": "", "boss": false}

func tile(name: String) -> Image:
	if not _cache.has(name):
		var image := Image.load_from_file(frames.path_join(name + ".png"))
		image.convert(Image.FORMAT_RGBA8)
		_cache[name] = image
	return _cache[name]

func stamp(target: Image, name: String, cell: Vector2i, offset: Vector2i = Vector2i.ZERO) -> void:
	var source := tile(name)
	target.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), cell * T + offset)

## Same rule as crypt_generator._wall_role (floor = walkable cells).
static func wall_role(p: Vector2i, f: Dictionary) -> String:
	var n: bool = f.has(p + Vector2i.UP)
	var e: bool = f.has(p + Vector2i.RIGHT)
	var s: bool = f.has(p + Vector2i.DOWN)
	var w: bool = f.has(p + Vector2i.LEFT)
	if n and w: return "inner_nw"
	if n and e: return "inner_ne"
	if s and w: return "inner_sw"
	if s and e: return "inner_se"
	if s: return "north"
	if n: return "south"
	if e: return "west"
	if w: return "east"
	if f.has(p + Vector2i(1, 1)): return "outer_nw"
	if f.has(p + Vector2i(-1, 1)): return "outer_ne"
	if f.has(p + Vector2i(1, -1)): return "outer_sw"
	return "outer_se"

func render(room: Dictionary, seed_value: int) -> Image:
	var size := Vector2i(int(room.world_size[0]) / 32, int(room.world_size[1]) / 32)
	var image := Image.create(size.x * T, size.y * T, false, Image.FORMAT_RGBA8)
	image.fill(VOID)
	var floor: Dictionary = {}
	var walls: Dictionary = {}
	for cell: Dictionary in room.painted_tiles:
		var p := Vector2i(int(cell.x), int(cell.y))
		if str(cell.layer) == "floor": floor[p] = true
		elif bool(cell.solid): walls[p] = true
	for exit: Dictionary in room.get("exits", []):
		var r: Array = exit.rect
		floor[Vector2i(int(r[0]) / 32, int(r[1]) / 32)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# 1) Floor: mostly plain stone; cracked/variant tiles stay rare so rooms read calm.
	for p: Vector2i in floor:
		var roll := rng.randf()
		var name := "floor_1" if roll < 0.86 else "floor_%d" % rng.randi_range(2, 8)
		stamp(image, name, p)
	# 2) Walls from components (all original 0x72 pieces):
	#    face  = brick front (wall_mid) with its cap in the cell above, where floor
	#            lies north or south of the wall;
	#    left  = top strip on the cell's left side (wall_outer_mid_right), floor west;
	#    right = top strip on the cell's right side (wall_outer_mid_left), floor east.
	#    Corner cells (floor only diagonal) inherit components from neighbours so
	#    face rows and strips meet without gaps.
	var parts: Dictionary = {}
	for p: Vector2i in walls:
		parts[p] = {"face": floor.has(p + Vector2i.UP) or floor.has(p + Vector2i.DOWN),
			"left": floor.has(p + Vector2i.LEFT), "right": floor.has(p + Vector2i.RIGHT)}
	for p: Vector2i in walls:
		var own: Dictionary = parts[p]
		if own.face or own.left or own.right: continue
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if parts.has(p + side) and parts[p + side].face: own.face = true
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
			if parts.has(p + side):
				if parts[p + side].left: own.left = true
				if parts[p + side].right: own.right = true
	var caps: Array[Vector2i] = []
	for p: Vector2i in walls:
		var own: Dictionary = parts[p]
		if own.face:
			stamp(image, "wall_mid", p)
			caps.append(p + Vector2i.UP)
		if own.left: stamp(image, "wall_outer_mid_right", p)
		if own.right: stamp(image, "wall_outer_mid_left", p)
	for cap: Vector2i in caps:
		stamp(image, "wall_top_mid", cap)
	_decorate(image, room, floor, walls, rng)
	# Walkable cells and spawns for the preview's wandering actors.
	for p: Vector2i in floor: animated.floor.append([p.x, p.y])
	for point in room.get("player_spawns", []): animated.players.append([Vector2(point).x / 2.0, Vector2(point).y / 2.0])
	for point in room.get("enemy_spawns", []): animated.enemies.append([Vector2(point).x / 2.0, Vector2(point).y / 2.0])
	return image

## Scenery only (no collision), after main's decor rules: wall dressing on
## north-facing faces, sparse floor clutter along walls, nothing on exits,
## spawns or the room centre. Torches/candles go to the animated overlay list.
func _decorate(image: Image, room: Dictionary, floor: Dictionary, walls: Dictionary, rng: RandomNumberGenerator) -> void:
	var keep_clear: Array[Vector2] = []
	for exit: Dictionary in room.get("exits", []):
		keep_clear.append(Vector2(float(exit.rect[0]) + 16.0, float(exit.rect[1]) + 16.0) / 32.0)
	for point in room.get("player_spawns", []) + room.get("enemy_spawns", []):
		keep_clear.append(Vector2(point) / 32.0)
	var clear := func(p: Vector2i, radius: float) -> bool:
		for other: Vector2 in keep_clear:
			if Vector2(p).distance_to(other) < radius: return false
		return true
	# North-facing faces (floor directly south) in reading order.
	var faces: Array[Vector2i] = []
	for p: Vector2i in walls:
		if floor.has(p + Vector2i.DOWN) and not floor.has(p + Vector2i.UP): faces.append(p)
	faces.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var banners := ["wall_banner_red", "wall_banner_blue", "wall_banner_green", "wall_banner_yellow"]
	var banner: String = banners[rng.randi_range(0, banners.size() - 1)]
	for p: Vector2i in faces:
		if not clear.call(p, 2.5): continue
		if posmod(p.x, 6) == 2:
			animated.torches.append([p.x * T, p.y * T - 8])
		elif posmod(p.x, 6) == 5 and rng.randf() < 0.7:
			stamp(image, banner, p)
		elif rng.randf() < 0.08:
			stamp(image, "wall_hole_1" if rng.randf() < 0.5 else "wall_hole_2", p)
	# Floor clutter: skulls and crates next to walls, away from the centre.
	var centre := Vector2(int(room.world_size[0]) / 64.0, int(room.world_size[1]) / 64.0)
	for p: Vector2i in floor:
		var by_wall := walls.has(p + Vector2i.UP) or walls.has(p + Vector2i.LEFT) or walls.has(p + Vector2i.RIGHT)
		if not by_wall or not clear.call(p, 3.0) or Vector2(p).distance_to(centre) < 6.0: continue
		var roll := rng.randf()
		if roll < 0.035: stamp(image, "skull", p)
		elif roll < 0.05: stamp(image, "crate", p)
	# The generator's fire positions become animated candle columns.
	for point in room.get("brazier_spawns", []):
		var cell := Vector2i(Vector2(point) / 32.0)
		animated.candles.append([cell.x * T, cell.y * T - 8])
	# Exits: 0x72 has front-facing doors only, so side doorways are wall gaps
	# flanked by candle columns; interior stairs use the original stair tile.
	for exit: Dictionary in room.get("exits", []):
		var cell := Vector2i(int(exit.rect[0]) / 32, int(exit.rect[1]) / 32)
		if str(exit.kind) == "stairs":
			stamp(image, "floor_stairs", cell)
			animated.stairs.append([cell.x * T, cell.y * T])
			continue
		var inward := 1 if str(exit.side) == "west" else -1 if str(exit.side) == "east" else 0
		if inward != 0:
			animated.candles.append([(cell.x + inward) * T, (cell.y - 1) * T - 8])
			animated.candles.append([(cell.x + inward) * T, (cell.y + 1) * T - 8])
		animated.doors.append([cell.x * T, cell.y * T, str(exit.side)])

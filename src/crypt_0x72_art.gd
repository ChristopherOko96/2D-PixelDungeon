extends RefCounted
## 0x72 crypt rooms for live runs. Bakes a generator room into one texture of
## original DungeonTileset II tiles (16 px per 32 px cell, drawn at 2x) with
## the rules of the approved review rooms R1-R10
## (production/art-proof/0x72-style/render_room.gd): mostly plain floor, brick
## fronts with caps where floor lies north or south, side strips where floor
## lies west or east, banners/holes on north faces, sparse skulls and crates
## by the walls, stairs. Wall torches and candle columns are animated on top.
## Presentation only: collision and exits come from the layout.

const T := 16
const SCALE := 2.0
const TILES := "res://assets/sprites/0x72/"
const PROPS := "res://assets/sprites/crypt_props/"
## Behind an open gate: steps down (the way on, deeper) or up (the way back).
const STAIRWELL_DOWN := preload("res://assets/sprites/fx/stairwell_down.png")
const STAIRWELL_UP := preload("res://assets/sprites/fx/stairwell_up.png")
## Outside the rooms: the dark grey of the reference map.
const VOID := Color("232223")
const FRAMES := 8
const FPS := 10.0

var texture: Texture2D
## Top-left corners (world px) of the animated 16x24 props, drawn at 2x.
var torches: Array[Vector2] = []
var candles: Array[Vector2] = []
## Wall fountains (lava): wall cell top-left in world px.
var fountains: Array[Vector2] = []
## Arched doors on north/south exits and barred side exits: {pos, side, kind}.
var doors: Array[Dictionary] = []
var world_size := Vector2.ZERO
var _tiles: Dictionary = {}
var _torch_frames: Array[Texture2D] = []
var _candle_frames: Array[Texture2D] = []
var _fountain_mid: Array[Texture2D] = []
var _fountain_basin: Array[Texture2D] = []
var _pieces: Dictionary = {}


func _init() -> void:
	for i in range(FRAMES):
		_torch_frames.append(load(PROPS + "wall_torch_f%d.png" % i))
		_candle_frames.append(load(PROPS + "candle_column_f%d.png" % i))
	for i in range(3):
		_fountain_mid.append(load(TILES + "wall_fountain_mid_red_anim_f%d.png" % i))
		_fountain_basin.append(load(TILES + "wall_fountain_basin_red_anim_f%d.png" % i))
	for name: String in ["wall_fountain_top_1", "doors_frame_left", "doors_frame_right", "doors_frame_top", "doors_leaf_closed", "doors_leaf_open"]:
		_pieces[name] = load(TILES + name + ".png")


func _tile(name: String) -> Image:
	if not _tiles.has(name):
		var source: Texture2D = load(TILES + name + ".png")
		var image := source.get_image().duplicate()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_tiles[name] = image
	return _tiles[name]


func _stamp(target: Image, name: String, cell: Vector2i, offset: Vector2i = Vector2i.ZERO) -> void:
	var source := _tile(name)
	target.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), cell * T + offset)


## Bakes `room` (a generator layout with painted_tiles and exits).
func bake(room: Dictionary, seed_value: int) -> void:
	torches.clear()
	candles.clear()
	fountains.clear()
	doors.clear()
	var dimensions: Array = room.get("world_size", [1280, 720])
	world_size = Vector2(float(dimensions[0]), float(dimensions[1]))
	var size := Vector2i(int(world_size.x) / 32, int(world_size.y) / 32)
	var image := Image.create(maxi(1, size.x * T), maxi(1, size.y * T), false, Image.FORMAT_RGBA8)
	image.fill(VOID)
	var floor_cells: Dictionary = {}
	var walls: Dictionary = {}
	for cell: Dictionary in room.get("painted_tiles", []):
		var p := Vector2i(int(cell.x), int(cell.y))
		if str(cell.get("layer", "")) == "floor": floor_cells[p] = true
		elif bool(cell.get("solid", false)): walls[p] = true
	for exit: Dictionary in room.get("exits", []):
		var rect: Array = exit.rect
		floor_cells[Vector2i(int(rect[0]) / 32, int(rect[1]) / 32)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for p: Vector2i in floor_cells:
		var roll := rng.randf()
		_stamp(image, "floor_1" if roll < 0.94 else "floor_%d" % rng.randi_range(2, 8), p)
	# Single obstacle cells become round columns (3 tiles tall, base on the cell).
	var columns: Array[Vector2i] = []
	for p: Vector2i in walls.keys():
		var alone := true
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if walls.has(p + side) or not floor_cells.has(p + side): alone = false
		if alone:
			columns.append(p)
			walls.erase(p)
			_stamp(image, "floor_1", p)
	# Wall pieces: face (brick front + cap above), left/right strips; corner
	# cells inherit pieces from their neighbours so rows and strips meet.
	var parts: Dictionary = {}
	for p: Vector2i in walls:
		parts[p] = {"face": floor_cells.has(p + Vector2i.UP) or floor_cells.has(p + Vector2i.DOWN), "left": floor_cells.has(p + Vector2i.LEFT), "right": floor_cells.has(p + Vector2i.RIGHT)}
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
			_stamp(image, "wall_mid", p)
			caps.append(p + Vector2i.UP)
		if own.left: _stamp(image, "wall_outer_mid_right", p)
		if own.right: _stamp(image, "wall_outer_mid_left", p)
	for cap: Vector2i in caps: _stamp(image, "wall_top_mid", cap)
	for p: Vector2i in columns: _stamp(image, "column", p, Vector2i(0, -2 * T))
	_decorate(image, room, floor_cells, walls, rng)
	texture = ImageTexture.create_from_image(image)


func _decorate(image: Image, room: Dictionary, floor_cells: Dictionary, walls: Dictionary, rng: RandomNumberGenerator) -> void:
	var keep_clear: Array[Vector2] = []
	for exit: Dictionary in room.get("exits", []):
		keep_clear.append(Vector2(float(exit.rect[0]) + 16.0, float(exit.rect[1]) + 16.0) / 32.0)
	for point: Variant in room.get("player_spawns", []) + room.get("enemy_spawns", []):
		keep_clear.append(Vector2(point) / 32.0)
	var clear := func(p: Vector2i, radius: float) -> bool:
		for other: Vector2 in keep_clear:
			if Vector2(p).distance_to(other) < radius: return false
		return true
	var faces: Array[Vector2i] = []
	for p: Vector2i in walls:
		if floor_cells.has(p + Vector2i.DOWN) and not floor_cells.has(p + Vector2i.UP): faces.append(p)
	faces.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var banners := ["wall_banner_red", "wall_banner_blue", "wall_banner_green", "wall_banner_yellow"]
	var banner: String = banners[rng.randi_range(0, banners.size() - 1)]
	# North walls, as on the reference map: a torch every 6 cells, banners in
	# pairs between them, now and then a lava fountain or a broken brick.
	var fountain_left := 1 + rng.randi_range(0, 1)
	for p: Vector2i in faces:
		if not clear.call(p, 3.1): continue
		var step := posmod(p.x, 6)
		if step == 2: torches.append(Vector2(p.x * T, p.y * T - 8) * SCALE)
		elif (step == 4 or step == 5) and rng.randf() < 0.85: _stamp(image, banner, p)
		elif step == 0 and fountain_left > 0 and floor_cells.has(p + Vector2i(0, 2)) and rng.randf() < 0.35:
			fountains.append(Vector2(p * T) * SCALE)
			fountain_left -= 1
		elif rng.randf() < 0.08: _stamp(image, "wall_hole_1" if rng.randf() < 0.5 else "wall_hole_2", p)
	var centre := world_size / 64.0
	for p: Vector2i in floor_cells:
		var by_wall: bool = walls.has(p + Vector2i.UP) or walls.has(p + Vector2i.LEFT) or walls.has(p + Vector2i.RIGHT)
		if not by_wall or not clear.call(p, 3.0) or Vector2(p).distance_to(centre) < 6.0: continue
		var roll := rng.randf()
		if roll < 0.035: _stamp(image, "skull", p)
	for point: Variant in room.get("brazier_spawns", []):
		var cell := Vector2i(Vector2(point) / 32.0)
		candles.append(Vector2(cell.x * T, cell.y * T - 8) * SCALE)
	for exit: Dictionary in room.get("exits", []):
		var cell := Vector2i(int(exit.rect[0]) / 32, int(exit.rect[1]) / 32)
		if str(exit.get("kind", "")) == "stairs":
			_stamp(image, "floor_stairs", cell)
			continue
		var side := str(exit.get("side", ""))
		if exit.has("door_cell"):
			# A gate set into a north wall: the arch covers the two wall cells
			# (face and cap row); torches flank it; the onward gate is marked.
			var gate := Vector2i(int(exit.door_cell[0]), int(exit.door_cell[1]))
			doors.append({"pos": Vector2(gate.x * T, (gate.y - 1) * T) * SCALE, "side": side, "kind": "arch", "forward": bool(exit.get("forward", false))})
			continue
		var inward := 1 if side == "west" else -1 if side == "east" else 0
		if inward != 0:
			candles.append(Vector2((cell.x + inward) * T, (cell.y - 1) * T - 8) * SCALE)
			candles.append(Vector2((cell.x + inward) * T, (cell.y + 1) * T - 8) * SCALE)
			doors.append({"pos": Vector2(cell * T) * SCALE, "side": side, "kind": "bars"})
		else:
			# North/south: an arched 0x72 door centred on the exit cell.
			doors.append({"pos": Vector2(cell.x * T - 8, (cell.y - 1) * T) * SCALE, "side": side, "kind": "arch"})


## Draws the baked room at 2x.
func draw_room(canvas: CanvasItem) -> void:
	if texture == null: return
	canvas.draw_rect(Rect2(Vector2.ZERO, world_size), VOID)
	canvas.draw_texture_rect(texture, Rect2(Vector2.ZERO, world_size), false)


## Animated torches and candle columns (10 fps), drawn over the floor.
## Doors are closed (arch) or barred (side exits) while `locked` (combat).
func draw_props(canvas: CanvasItem, clock: float, locked: bool = false) -> void:
	var frame := int(floor(clock * FPS))
	for point: Vector2 in torches: canvas.draw_texture_rect(_torch_frames[frame % FRAMES], Rect2(point, Vector2(16, 24) * SCALE), false)
	for point: Vector2 in candles: canvas.draw_texture_rect(_candle_frames[(frame + 3) % FRAMES], Rect2(point, Vector2(16, 24) * SCALE), false)
	var slow := int(floor(clock * 6.0)) % 3
	var cell := Vector2(T, T) * SCALE
	for point: Vector2 in fountains:
		canvas.draw_texture_rect(_pieces.wall_fountain_top_1, Rect2(point - Vector2(0, cell.y), cell), false)
		canvas.draw_texture_rect(_fountain_mid[slow], Rect2(point, cell), false)
		canvas.draw_texture_rect(_fountain_basin[slow], Rect2(point + Vector2(0, cell.y), cell), false)
	for door: Dictionary in doors:
		var at: Vector2 = door.pos
		if str(door.kind) == "arch":
			if not locked: canvas.draw_texture_rect(STAIRWELL_DOWN if bool(door.get("forward", false)) else STAIRWELL_UP, Rect2(at, cell * 2.0), false)
			canvas.draw_texture_rect(_pieces.doors_leaf_closed if locked else _pieces.doors_leaf_open, Rect2(at, cell * 2.0), false)
			canvas.draw_texture_rect(_pieces.doors_frame_left, Rect2(at - Vector2(cell.x, 0), Vector2(cell.x, cell.y * 2.0)), false)
			canvas.draw_texture_rect(_pieces.doors_frame_right, Rect2(at + Vector2(cell.x * 2.0, 0), Vector2(cell.x, cell.y * 2.0)), false)
			canvas.draw_texture_rect(_pieces.doors_frame_top, Rect2(at - Vector2(0, cell.y), Vector2(cell.x * 2.0, cell.y)), false)
			if bool(door.get("forward", false)) and not locked:
				# The way on: a pulsing gold chevron above the open gate.
				var pulse := 0.5 + 0.5 * sin(clock * 4.0)
				var tip := at + Vector2(cell.x, -cell.y * 1.4 - pulse * 4.0)
				for row in range(3):
					canvas.draw_rect(Rect2(tip + Vector2(-10 + row * 4, row * 4), Vector2(20 - row * 8, 4)), Color(0.98, 0.8, 0.35, 0.6 + 0.4 * pulse))
				canvas.draw_circle(at + Vector2(cell.x, cell.y), 34.0, Color(1.0, 0.8, 0.4, 0.06 + 0.05 * pulse))
		elif locked:
			# Iron bars across a side doorway while the room is fought in.
			for i in range(4):
				var x := at.x + 4.0 + i * 8.0
				canvas.draw_rect(Rect2(x, at.y - 6.0, 4.0, cell.y + 12.0), Color("222222"))
				canvas.draw_rect(Rect2(x + 1.0, at.y - 6.0, 2.0, cell.y + 12.0), Color("77728b"))
			canvas.draw_rect(Rect2(at.x, at.y + 4.0, cell.x, 4.0), Color("222222"))


## Light points (world px) of torches and candle flames for the dark crypt.
func light_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in torches: result.append(point + Vector2(16, 20))
	for point: Vector2 in candles: result.append(point + Vector2(16, 12))
	for point: Vector2 in fountains: result.append(point + Vector2(16, 40))
	return result

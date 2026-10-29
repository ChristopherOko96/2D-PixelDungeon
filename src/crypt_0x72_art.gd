extends RefCounted
## 0x72 crypt rooms for live runs. Bakes a generator room into one texture of
## original DungeonTileset II tiles (16 px per 32 px cell, drawn at 2x) with
## the rules of the approved review rooms R1-R10
## (production/art-proof/0x72-style/render_room.gd): mostly plain floor, brick
## fronts with caps where floor lies north or south, side strips where floor
## lies west or east, banners/holes on north faces, sparse skulls and crates
## by the walls, stairs. Wall torches and candle columns are animated on top.
## Decor the author placed in the Dungeon-Werkstatt (`decor_areas`: floor
## styles and carpets, `decor`: wall pieces and objects, see decor_catalog.gd)
## is drawn too; with `auto_decor` false the room shows only that decor.
## Presentation only: collision and exits come from the layout.

const Decor = preload("res://src/dungeon/decor_catalog.gd")
const CryptAtmosphere = preload("res://src/vfx/crypt_atmosphere.gd")
const T := 16
const SCALE := 2.0
const TILES := "res://assets/sprites/0x72/"
const PROPS := "res://assets/sprites/crypt_props/"
const DECOR := "res://assets/sprites/decor/"
## Behind an open gate: steps down (the way on, deeper) or up (the way back).
const STAIRWELL_DOWN := preload("res://assets/sprites/fx/stairwell_down.png")
const STAIRWELL_UP := preload("res://assets/sprites/fx/stairwell_up.png")
## Outside the rooms: the dark grey of the reference map.
const VOID := Color("232223")
const FRAMES := 8
const FPS := 10.0
## Size (art px) a torch or candle column covers; drawn at SCALE.
const PROP_SIZE := Vector2(16, 24)
## The drawn part of a candle column frame (art px); the rest is empty. It
## must match PROP_SIZE, or the column is squashed and loses pixel rows.
const CANDLE_REGION := Rect2(0, 0, 16, 24)

var texture: Texture2D
## Top-left corners (world px) of the animated 16x24 props, drawn at 2x.
var torches: Array[Vector2] = []
var candles: Array[Vector2] = []
## Wall fountains: wall cell top-left in world px; `fountain_colors` holds
## "red" (lava, gives light) or "blue" (water) for each.
var fountains: Array[Vector2] = []
var fountain_colors: Array[String] = []
## Open fires on the floor (cell top-left, world px), animated, give light.
var flames: Array[Vector2] = []
## Light shafts from the ceiling: the lit floor spot (cell centre, world px).
var shafts: Array[Vector2] = []
## How far up (px) a shaft reaches and how wide it lands.
const SHAFT_HEIGHT := 230.0
const SHAFT_FOOT := 34.0
## Arched doors on north/south exits and barred side exits: {pos, side, kind}.
var doors: Array[Dictionary] = []
## What the bake decorated by itself, as decor entries [x, y, id, variant]:
## the editor turns it into the room's own decor when the author starts
## decorating, so nothing jumps away.
var auto_items: Array = []
var world_size := Vector2.ZERO
var _tiles: Dictionary = {}
var _torch_frames: Array[Texture2D] = []
var _candle_frames: Array[Texture2D] = []
var _fire_frames: Array[Texture2D] = []
var _fountain_mid: Dictionary = {"red": [], "blue": []}
var _fountain_basin: Dictionary = {"red": [], "blue": []}
var _pieces: Dictionary = {}
## Theme of a themed endless floor (layout.floor_theme): floor and wall tints,
## banner colour and floor detail; white and empty elsewhere.
var _floor_tint := Color.WHITE
var _wall_tint := Color.WHITE
const DETAIL_COLORS := {"crack": Color("#ff5a20"), "moss_dark": Color("#4f7a2e"), "moss_light": Color("#7fa848"),
	"gold": Color("#e8c152"), "gold_light": Color("#fff4c8"), "cobweb": Color("#c8d4e4")}
const BANNER_NAMES := ["red", "blue", "green", "yellow"]


func _init() -> void:
	for i in range(FRAMES):
		_torch_frames.append(load(PROPS + "wall_torch_f%d.png" % i))
		_candle_frames.append(load(PROPS + "candle_column_f%d.png" % i))
		_fire_frames.append(load(DECOR + "fire_f%d.png" % i))
	for color: String in ["red", "blue"]:
		for i in range(3):
			_fountain_mid[color].append(load(TILES + "wall_fountain_mid_%s_anim_f%d.png" % [color, i]))
			_fountain_basin[color].append(load(TILES + "wall_fountain_basin_%s_anim_f%d.png" % [color, i]))
	for name: String in ["wall_fountain_top_1", "doors_frame_left", "doors_frame_right", "doors_frame_top", "doors_leaf_closed", "doors_leaf_open"]:
		_pieces[name] = load(TILES + name + ".png")


## Repaints the flames: wall torches, candle columns and (with `floor_fires`)
## open floor fires use their frames with `mapping` ("rrggbb" -> Color, see
## src/vfx/crypt_atmosphere.gd) applied. Same frames, same pixels, new colours.
func use_flame_colors(mapping: Dictionary, floor_fires: bool) -> void:
	if mapping.is_empty(): return
	for i in range(FRAMES):
		_torch_frames[i] = CryptAtmosphere.flame_texture(PROPS + "wall_torch_f%d.png" % i, mapping)
		_candle_frames[i] = CryptAtmosphere.flame_texture(PROPS + "candle_column_f%d.png" % i, mapping)
		if floor_fires: _fire_frames[i] = CryptAtmosphere.flame_texture(DECOR + "fire_f%d.png" % i, mapping)


func _tile(name: String) -> Image:
	if not _tiles.has(name):
		var source: Texture2D = load(TILES + name + ".png")
		var image := source.get_image().duplicate()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_tiles[name] = image
	return _tiles[name]


func _stamp(target: Image, name: String, cell: Vector2i, offset: Vector2i = Vector2i.ZERO, tint: Color = Color.WHITE) -> void:
	var source := _tile(name) if tint == Color.WHITE else _tinted(name, tint)
	target.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), cell * T + offset)


## A tile multiplied by `tint` (cached per tile and colour; tiles are tiny).
func _tinted(name: String, tint: Color) -> Image:
	var key := "%s@%s" % [name, tint.to_html()]
	if not _tiles.has(key):
		var image: Image = _tile(name).duplicate()
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				image.set_pixel(x, y, image.get_pixel(x, y) * Color(tint.r, tint.g, tint.b, 1.0))
		_tiles[key] = image
	return _tiles[key]


static func _theme_color(theme: Dictionary, key: String) -> Color:
	var value := str(theme.get(key, ""))
	return Color(value) if value.is_valid_html_color() else Color.WHITE


## Bakes `room` (a generator layout with painted_tiles and exits).
func bake(room: Dictionary, seed_value: int) -> void:
	torches.clear()
	candles.clear()
	fountains.clear()
	fountain_colors.clear()
	flames.clear()
	shafts.clear()
	doors.clear()
	auto_items.clear()
	var theme: Dictionary = room.get("floor_theme", {})
	_floor_tint = _theme_color(theme, "floor")
	_wall_tint = _theme_color(theme, "wall")
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
		_stamp(image, "floor_1" if roll < 0.94 else "floor_%d" % rng.randi_range(2, 8), p, Vector2i.ZERO, _floor_tint)
	_paint_areas(image, room, floor_cells)
	# Single obstacle cells become round columns (3 tiles tall, base on the cell).
	var columns: Array[Vector2i] = []
	for p: Vector2i in walls.keys():
		var alone := true
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if walls.has(p + side) or not floor_cells.has(p + side): alone = false
		if alone:
			columns.append(p)
			walls.erase(p)
			_stamp(image, "floor_1", p, Vector2i.ZERO, _floor_tint)
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
			_stamp(image, "wall_mid", p, Vector2i.ZERO, _wall_tint)
			caps.append(p + Vector2i.UP)
		if own.left: _stamp(image, "wall_outer_mid_right", p, Vector2i.ZERO, _wall_tint)
		if own.right: _stamp(image, "wall_outer_mid_left", p, Vector2i.ZERO, _wall_tint)
	for cap: Vector2i in caps: _stamp(image, "wall_top_mid", cap, Vector2i.ZERO, _wall_tint)
	for p: Vector2i in columns: _stamp(image, "column", p, Vector2i(0, -2 * T))
	_paint_detail(image, str(theme.get("detail", "")), floor_cells)
	_decorate(image, room, floor_cells, walls, rng)
	_place_decor(image, room, floor_cells)
	texture = ImageTexture.create_from_image(image)


## The theme's floor detail painted onto the floor at 1x (16 px tiles): lava
## cracks (hell), moss (orc camp), cobwebs (crypt) or gold inlays (heaven).
func _paint_detail(image: Image, detail: String, floor_cells: Dictionary) -> void:
	if detail.is_empty(): return
	for p: Vector2i in floor_cells:
		var cell_hash: int = absi(hash(p * 7 + Vector2i(13, 101)))
		var origin := p * T
		match detail:
			"cracks":
				if cell_hash % 4 != 0: continue
				var y: int = 3 + cell_hash % 10
				for step in range(8):
					y = clampi(y + (cell_hash >> step) % 3 - 1, 1, 14)
					image.fill_rect(Rect2i(origin.x + step * 2, origin.y + y, 2, 1), DETAIL_COLORS.crack)
			"moss":
				if cell_hash % 5 != 0: continue
				for k in range(6):
					var spot := Vector2i((cell_hash >> (k * 3)) % 13, (cell_hash >> (k * 3 + 2)) % 13)
					image.fill_rect(Rect2i(origin + spot, Vector2i(2, 1)), DETAIL_COLORS.moss_dark if k % 2 == 0 else DETAIL_COLORS.moss_light)
			"cobweb":
				if cell_hash % 11 != 0: continue
				for k in range(5):
					image.set_pixelv(origin + Vector2i(k * 2, k * 2), image.get_pixelv(origin + Vector2i(k * 2, k * 2)).lerp(DETAIL_COLORS.cobweb, 0.5))
					image.set_pixelv(origin + Vector2i(8 - k * 2, k * 2), image.get_pixelv(origin + Vector2i(8 - k * 2, k * 2)).lerp(DETAIL_COLORS.cobweb, 0.35))
			"gold":
				if (p.x + p.y) % 4 != 0: continue
				image.fill_rect(Rect2i(origin + Vector2i(7, 6), Vector2i(2, 4)), DETAIL_COLORS.gold)
				image.fill_rect(Rect2i(origin + Vector2i(6, 7), Vector2i(4, 2)), DETAIL_COLORS.gold)
				image.set_pixelv(origin + Vector2i(7, 7), DETAIL_COLORS.gold_light)


## Floor styles replace the floor tile; carpets lie on top and frame
## themselves (each cell looks at its four neighbours of the same carpet).
func _paint_areas(image: Image, room: Dictionary, floor_cells: Dictionary) -> void:
	var carpets: Dictionary = {}
	for entry: Variant in room.get("decor_areas", []):
		if not entry is Array or entry.size() < 3: continue
		var p := Vector2i(int(entry[0]), int(entry[1]))
		var id := str(entry[2])
		if not floor_cells.has(p): continue
		match Decor.kind(id):
			"floor":
				var tile := Decor.image(Decor.tile_path(id, int(entry[3]) if entry.size() > 3 else 0))
				if tile != null: image.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), p * T)
			"carpet": carpets[p] = id
	for p: Vector2i in carpets:
		var id: String = carpets[p]
		var same := func(q: Vector2i) -> bool: return str(carpets.get(q, "")) == id
		var cell := Decor.carpet_cell(Decor.image(Decor.tile_path(id)), same.call(p + Vector2i.UP), same.call(p + Vector2i.RIGHT), same.call(p + Vector2i.DOWN), same.call(p + Vector2i.LEFT))
		image.blend_rect(cell, Rect2i(0, 0, T, T), p * T)


## The author's wall pieces and objects, top rows first so lower pieces
## overlap the ones behind them. Animated pieces join the torch, fountain and
## fire lists. A piece whose spot is gone (floor changed) is skipped.
func _place_decor(image: Image, room: Dictionary, floor_cells: Dictionary) -> void:
	var entries: Array = room.get("decor", []).filter(func(entry: Variant) -> bool: return entry is Array and entry.size() >= 3)
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0])))
	for entry: Array in entries:
		var id := str(entry[2])
		var item := Decor.item(id)
		if item.is_empty() or Decor.is_area(id): continue
		var p := Vector2i(int(entry[0]), int(entry[1]))
		var variant := int(entry[3]) if entry.size() > 3 else 0
		if str(item.kind) == "wall":
			if not Decor.wall_spot(floor_cells, p): continue
		elif not floor_cells.has(p): continue
		match str(item.get("draw", "stamp")):
			"torch": torches.append(Vector2(p.x * T, p.y * T - 8) * SCALE)
			"fountain":
				fountains.append(Vector2(p * T) * SCALE)
				fountain_colors.append(str(item.get("color", "red")))
			"fire": flames.append(Vector2(p * T) * SCALE)
			"shaft": shafts.append(Vector2(p * T) * SCALE + Vector2(16, 16))
			_:
				var tile := Decor.image(Decor.tile_path(id, variant))
				if tile != null: image.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), p * T + Decor.offset(id))
				if item.has("below"):
					var under := Decor.image(Decor.SPRITES + str(item.below) + ".png")
					if under != null: image.blend_rect(under, Rect2i(Vector2i.ZERO, under.get_size()), (p + Vector2i.DOWN) * T)


func _decorate(image: Image, room: Dictionary, floor_cells: Dictionary, walls: Dictionary, rng: RandomNumberGenerator) -> void:
	# Without auto decor only the gameplay pieces follow (candles, gates, stairs).
	var auto := bool(room.get("auto_decor", true))
	var taken: Dictionary = {}
	for entry: Variant in room.get("decor", []):
		if entry is Array and entry.size() >= 3: taken[Vector2i(int(entry[0]), int(entry[1]))] = true
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
	var choice := rng.randi_range(0, banners.size() - 1)
	# A themed floor flies its own colour (balance of themed_monsters.json).
	var themed: int = BANNER_NAMES.find(str(room.get("floor_theme", {}).get("banner", "")))
	if themed >= 0: choice = themed
	var banner: String = banners[choice]
	# North walls, as on the reference map: a torch every 6 cells, banners in
	# pairs between them, now and then a lava fountain or a broken brick.
	var fountain_left := 1 + rng.randi_range(0, 1)
	for p: Vector2i in faces:
		if not auto: break
		if not clear.call(p, 3.1) or taken.has(p): continue
		var step := posmod(p.x, 6)
		if step == 2:
			torches.append(Vector2(p.x * T, p.y * T - 8) * SCALE)
			auto_items.append([p.x, p.y, "wall_torch", 0])
		elif (step == 4 or step == 5) and rng.randf() < 0.85:
			_stamp(image, banner, p)
			auto_items.append([p.x, p.y, "banner", choice])
		elif step == 0 and fountain_left > 0 and floor_cells.has(p + Vector2i(0, 2)) and not taken.has(p + Vector2i.DOWN) and rng.randf() < 0.35:
			fountains.append(Vector2(p * T) * SCALE)
			fountain_colors.append("red")
			auto_items.append([p.x, p.y, "fountain_lava", 0])
			fountain_left -= 1
		elif rng.randf() < 0.08:
			var hole := 0 if rng.randf() < 0.5 else 1
			_stamp(image, "wall_hole_%d" % (hole + 1), p)
			auto_items.append([p.x, p.y, "wall_hole", hole])
	var centre := world_size / 64.0
	for p: Vector2i in floor_cells:
		if not auto: break
		var by_wall: bool = walls.has(p + Vector2i.UP) or walls.has(p + Vector2i.LEFT) or walls.has(p + Vector2i.RIGHT)
		if not by_wall or not clear.call(p, 3.0) or Vector2(p).distance_to(centre) < 6.0 or taken.has(p): continue
		var roll := rng.randf()
		if roll < 0.035:
			_stamp(image, "skull", p)
			auto_items.append([p.x, p.y, "skull", 0])
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
	for point: Vector2 in torches: canvas.draw_texture_rect(_torch_frames[frame % FRAMES], Rect2(point, PROP_SIZE * SCALE), false)
	# The candle frames are 16x32 with 8 empty rows below the column: only the
	# top 16x24 is drawn, so every pixel row stays whole at 2x.
	for point: Vector2 in candles: canvas.draw_texture_rect_region(_candle_frames[(frame + 3) % FRAMES], Rect2(point, PROP_SIZE * SCALE), CANDLE_REGION)
	for index in range(flames.size()): canvas.draw_texture_rect(_fire_frames[(frame + index * 3) % FRAMES], Rect2(flames[index], Vector2(T, T) * SCALE), false)
	for index in range(shafts.size()): draw_shaft(canvas, shafts[index], clock + float(index) * 1.7)
	var slow := int(floor(clock * 6.0)) % 3
	var cell := Vector2(T, T) * SCALE
	for index in range(fountains.size()):
		var point := fountains[index]
		var color := fountain_colors[index] if index < fountain_colors.size() else "red"
		canvas.draw_texture_rect(_pieces.wall_fountain_top_1, Rect2(point - Vector2(0, cell.y), cell), false)
		canvas.draw_texture_rect(_fountain_mid[color][slow], Rect2(point, cell), false)
		canvas.draw_texture_rect(_fountain_basin[color][slow], Rect2(point + Vector2(0, cell.y), cell), false)
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


## A beam of light from the ceiling onto `foot`: a warm cone that sways
## slowly, a pool of light on the floor and dust drifting down through it.
func draw_shaft(canvas: CanvasItem, foot: Vector2, clock: float) -> void:
	var warm := Color(1.0, 0.93, 0.7)
	var top := foot + Vector2(7.0 * sin(clock * 0.6), -SHAFT_HEIGHT)
	canvas.draw_polygon(PackedVector2Array([top + Vector2(-12, 0), top + Vector2(12, 0), foot + Vector2(SHAFT_FOOT, 4), foot + Vector2(-SHAFT_FOOT, 4)]),
		PackedColorArray([Color(warm, 0.0), Color(warm, 0.0), Color(warm, 0.2), Color(warm, 0.2)]))
	canvas.draw_polygon(PackedVector2Array([top + Vector2(-5, 0), top + Vector2(5, 0), foot + Vector2(14, 2), foot + Vector2(-14, 2)]),
		PackedColorArray([Color(warm, 0.0), Color(warm, 0.0), Color(warm, 0.16), Color(warm, 0.16)]))
	canvas.draw_set_transform(foot + Vector2(0, 4), 0.0, Vector2(1.0, 0.36))
	canvas.draw_circle(Vector2.ZERO, SHAFT_FOOT + 4.0, Color(warm, 0.12))
	canvas.draw_circle(Vector2.ZERO, SHAFT_FOOT * 0.6, Color(warm, 0.12))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for index in range(18):
		var fall := fposmod(clock * 0.07 + float(index) * 0.1379, 1.0)
		var along := top.lerp(foot, fall)
		var half := lerpf(12.0, SHAFT_FOOT, fall)
		var x := along.x + sin(clock * 0.9 + float(index) * 2.3) * half * 0.8
		var alpha := clampf(sin(fall * PI) * (0.45 + 0.45 * sin(clock * 4.0 + float(index) * 1.7)), 0.0, 1.0)
		canvas.draw_rect(Rect2(Vector2(x, along.y).round(), Vector2(2, 2)), Color(1.0, 0.97, 0.85, alpha))


## Light points (world px) of torches and candle flames for the dark crypt.
func light_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in torches: result.append(point + Vector2(16, 20))
	for point: Vector2 in candles: result.append(point + Vector2(16, 12))
	for point: Vector2 in flames: result.append(point + Vector2(16, 14))
	for index in range(fountains.size()):
		if index >= fountain_colors.size() or fountain_colors[index] == "red": result.append(fountains[index] + Vector2(16, 40))
	return result

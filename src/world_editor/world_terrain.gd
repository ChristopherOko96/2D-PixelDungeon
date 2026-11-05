extends RefCounted
## The Weltbauer's ground that grows together, drawn the same in the editor and in the game: pit
## cells side by side form one hole, an area brush one surface, with an edge only where the shape
## ends. Walls and liquid edges come from the game's own builders (hell_walls.gd, pool_paint.gd).
## Colours: assets/data/world_terrain.json.

const DATA_PATH := "res://assets/data/world_terrain.json"
const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## The look values from the data file.
static func config() -> Dictionary:
	return DataCache.load_dict(DATA_PATH)


## A stable 0..1 number for a spot, so edges look the same every time they are drawn.
static func noise(x: int, y: int, k: int = 0) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## One pit cell at `at` (its top left, world px). `same` (Vector2i) -> bool tells which cells are pit.
static func draw_pit(ci: CanvasItem, cell: Vector2i, at: Vector2, size: float, same: Callable, look: Dictionary, art: float) -> void:
	ci.draw_rect(Rect2(at, Vector2.ONE * (size + 0.5)), Color(str(look.void)))
	var face := float(look.face_px)
	var rim := float(look.rim_px)
	var grain := float(look.grain)
	var steps := int(size / art)
	var face_color := Color(str(look.face))
	var rim_color := Color(str(look.rim))
	# the far wall of the hole, seen under its north edge, with a ragged lower line
	if not same.call(cell + Vector2i(0, -1)):
		for k in range(steps):
			var drop := face + roundf(noise(cell.x * steps + k, cell.y, 1) * 2.0) * art
			ci.draw_rect(Rect2(at + Vector2(k * art, 0.0), Vector2(art + 0.5, drop)), face_color)
	# the lit lip where the floor breaks off, only on outer edges
	for side: Vector2i in SIDES:
		if same.call(cell + side):
			continue
		for k in range(steps):
			var width := rim
			if noise(cell.x * steps + k, cell.y * steps + side.x * 3 + side.y * 5, 2) < grain:
				width += art
			var rect := Rect2()
			match side:
				Vector2i(0, -1): rect = Rect2(at + Vector2(k * art, 0.0), Vector2(art + 0.5, width))
				Vector2i(0, 1): rect = Rect2(at + Vector2(k * art, size - width), Vector2(art + 0.5, width))
				Vector2i(-1, 0): rect = Rect2(at + Vector2(0.0, k * art), Vector2(width, art + 0.5))
				_: rect = Rect2(at + Vector2(size - width, k * art), Vector2(width, art + 0.5))
			ci.draw_rect(rect, rim_color)


## One cell of an area brush: `tile` keeps running across cells by world place; `same` tells which
## cells carry the same tile, and only the shape's outer edge is shaded.
static func draw_area(ci: CanvasItem, tile: Texture2D, cell: Vector2i, at: Vector2, size: float, same: Callable, look: Dictionary, art: float) -> void:
	if tile == null:
		return
	var ts := tile.get_size()
	var y := 0.0
	while y < size:
		var src_y := fposmod(at.y + y, ts.y)
		var part_h := minf(ts.y - src_y, size - y)
		var x := 0.0
		while x < size:
			var src_x := fposmod(at.x + x, ts.x)
			var part_w := minf(ts.x - src_x, size - x)
			ci.draw_texture_rect_region(tile, Rect2(at + Vector2(x, y), Vector2(part_w, part_h)), Rect2(src_x, src_y, part_w, part_h))
			x += part_w
		y += part_h
	var edge := Color(str(look.edge))
	var depth := float(look.edge_px)
	var grain := float(look.grain)
	var steps := int(size / art)
	for side: Vector2i in SIDES:
		if same.call(cell + side):
			continue
		for k in range(steps):
			var width := depth * (0.5 + 0.5 * noise(cell.x * steps + k, cell.y * steps + side.x * 7 + side.y * 11, 3))
			if noise(k, cell.x + cell.y, 4) < grain:
				width += art
			width = roundf(width / art) * art
			var rect := Rect2()
			match side:
				Vector2i(0, -1): rect = Rect2(at + Vector2(k * art, 0.0), Vector2(art, width))
				Vector2i(0, 1): rect = Rect2(at + Vector2(k * art, size - width), Vector2(art, width))
				Vector2i(-1, 0): rect = Rect2(at + Vector2(0.0, k * art), Vector2(width, art))
				_: rect = Rect2(at + Vector2(size - width, k * art), Vector2(width, art))
			ci.draw_rect(rect, edge)


## A Sprungplatte: the world's plate (`base`, may be null) with chevrons running in its direction.
## `press` 0..1 sinks it, `armed` false dims it. `t` = time in seconds.
static func draw_pad(ci: CanvasItem, center: Vector2, dir: String, t: float, press: float, base: Texture2D, look: Dictionary, armed: bool = true) -> void:
	var size := Vector2(84.0, 84.0)
	if base != null:
		size = base.get_size()
	var rect := Rect2(center - size * 0.5 + Vector2(0.0, press * 3.0), size)
	if base != null:
		ci.draw_texture_rect(base, rect, false, Color(str(look.base)))
	else:
		ci.draw_rect(rect, Color("2a2c33"))
	ci.draw_rect(rect.grow(-size.x * 0.14), Color(0.03, 0.05, 0.08, 0.82))
	var way: Vector2 = Vector2({"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}.get(dir, Vector2i(0, -1)))
	var across := Vector2(-way.y, way.x)
	var idle := Color(str(look.idle))
	var live := Color(str(look.live))
	var unit := roundf(size.x / 28.0)
	var arm := size.x * 0.2
	for k in range(3):
		var phase := fposmod(t * 1.6 - k * 0.33, 1.0)
		var heat := pow(phase, 3.0)
		var color := idle.lerp(live, heat)
		if not armed:
			color = color.darkened(0.55)
		var tip := rect.get_center() + way * (size.x * (0.2 - k * 0.2))
		var m := int(arm / unit)
		for j in range(-m, m + 1):
			var spot := tip + across * (j * unit) - way * (absi(j) * unit)
			ci.draw_rect(Rect2((spot - Vector2.ONE * unit).round(), Vector2.ONE * unit * 2.0), color)

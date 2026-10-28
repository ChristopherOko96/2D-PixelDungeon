extends RefCounted
## Breaks inner dungeon walls (ultimate abilities). A wall cell is inner when it
## divides floor from floor: walking one or two cells left/right (or up/down)
## from it reaches floor on both sides through wall only. Outer walls have void
## behind them and never qualify, nor do cells near a door or the stairs. A
## broken cell becomes floor in painted_tiles (the 0x72 room image is baked
## from it) and the collision is rebuilt: the void mask of crypt rooms is
## recomputed, single-cell obstacles of classic rooms are removed. The layout
## is changed in place, so the hole stays when the party comes back; the caller
## bumps the layout revision for clients.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const CELL := 32.0
## Cells closer than this to a door or stairs stay intact.
const EXIT_CLEARANCE := 48.0
## Thickest divider (in cells) that can break.
const MAX_THICKNESS := 2


## Breaks every inner wall cell whose centre lies within `radius` of `point`.
## Returns the centres (world px) of the broken cells.
static func break_circle(layout: Dictionary, point: Vector2, radius: float) -> Array[Vector2]:
	var broken: Array[Vector2] = []
	if not layout.get("painted_tiles") is Array: return broken
	var grid := _grid(layout)
	var reach := int(ceil(radius / CELL)) + 1
	var center := Vector2i(int(floor(point.x / CELL)), int(floor(point.y / CELL)))
	var cells: Array[Vector2i] = []
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			var cell := Vector2i(x, y)
			if (Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5).distance_to(point) > radius + CELL * 0.5: continue
			if inner(layout, cell, grid): cells.append(cell)
	if cells.is_empty(): return broken
	for cell: Vector2i in cells:
		_paint_floor(layout, cell)
		_remove_cell_obstacle(layout, cell)
		broken.append(Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5)
	if layout.get("void_obstacles") is Array:
		# Crypt rooms collide against the void mask: rebuild it from the new floor.
		var old_void: Array = layout.void_obstacles
		for rect: Variant in old_void: _remove_rect(layout, "obstacles", rect)
		layout.void_obstacles = Dungeon._void_rectangles(layout)
		layout.obstacles.append_array(layout.void_obstacles)
	return broken


## True when `cell` is a breakable inner wall of `layout`.
static func inner(layout: Dictionary, cell: Vector2i, grid: Dictionary = {}) -> bool:
	if grid.is_empty(): grid = _grid(layout)
	if str(grid.get(cell, "")) != "wall": return false
	var bounds := _bounds(layout)
	var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
	if bounds.has_area() and not bounds.encloses(rect): return false
	for exit: Dictionary in layout.get("exits", []):
		var area := Rect2(float(exit.rect[0]), float(exit.rect[1]), float(exit.rect[2]), float(exit.rect[3]))
		if area.grow(EXIT_CLEARANCE).intersects(rect): return false
	for axis: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if _floor_within(grid, cell, axis) and _floor_within(grid, cell, -axis): return true
	return false


## Floor within MAX_THICKNESS cells along `step`, crossing only wall.
static func _floor_within(grid: Dictionary, cell: Vector2i, step: Vector2i) -> bool:
	var probe := cell
	for i in range(MAX_THICKNESS):
		probe += step
		var kind := str(grid.get(probe, ""))
		if kind == "floor": return true
		if kind != "wall": return false
	return false


## Cell kinds: "floor" or "wall" (solid painted cell without floor).
static func _grid(layout: Dictionary) -> Dictionary:
	var grid := {}
	for entry: Dictionary in layout.get("painted_tiles", []):
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if str(entry.get("layer", "")) == "floor" and not bool(entry.get("solid", false)): grid[cell] = "floor"
	for entry: Dictionary in layout.get("painted_tiles", []):
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if bool(entry.get("solid", false)): grid[cell] = "wall"
	return grid


static func _bounds(layout: Dictionary) -> Rect2:
	var data: Variant = layout.get("play_bounds")
	if data is Array and data.size() == 4: return Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))
	return Rect2()


static func _remove_cell_obstacle(layout: Dictionary, cell: Vector2i) -> void:
	var rect := [float(cell.x) * CELL, float(cell.y) * CELL, CELL, CELL]
	for key: String in ["obstacles", "tile_obstacles", "visual_obstacles"]: _remove_rect(layout, key, rect)


static func _remove_rect(layout: Dictionary, key: String, rect_data: Variant) -> void:
	if not layout.get(key) is Array: return
	var list: Array = layout[key]
	for index in range(list.size() - 1, -1, -1):
		if _same(list[index], rect_data):
			list.remove_at(index)
			return


static func _same(a: Variant, b: Variant) -> bool:
	if not a is Array or not b is Array or a.size() != 4 or b.size() != 4: return false
	for index in range(4):
		if not is_equal_approx(float(a[index]), float(b[index])): return false
	return true


static func _paint_floor(layout: Dictionary, cell: Vector2i) -> void:
	var tiles: Array = layout.painted_tiles
	var has_floor := false
	for index in range(tiles.size() - 1, -1, -1):
		var entry: Dictionary = tiles[index]
		if int(entry.get("x", -1)) != cell.x or int(entry.get("y", -1)) != cell.y: continue
		if bool(entry.get("solid", false)): tiles.remove_at(index)
		elif str(entry.get("layer", "")) == "floor": has_floor = true
	if not has_floor: tiles.append({"x": cell.x, "y": cell.y, "layer": "floor", "solid": false})

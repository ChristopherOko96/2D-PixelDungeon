extends RefCounted
## Read-only cell-center occupancy for the editor. It never changes collision,
## authored tiles or snapshots, and deliberately applies no actor-radius margin.

const TILE_SIZE := 32.0
const MAX_COLUMNS := 64
const MAX_ROWS := 48

## Classifies each canvas cell as walkable, wall or void. The returned dictionary
## uses Vector2i keys and {kind:String, blocked:bool, reason:String} values.
## Physical obstacles remain authoritative; generated void retains its own kind.
static func classify(layout: Dictionary) -> Dictionary:
	var dimensions: Variant = layout.get("world_size",[])
	if not _numbers(dimensions,2): return {}
	var world := Vector2(float(dimensions[0]),float(dimensions[1]))
	if world.x <= 0 or world.y <= 0 or world.x > MAX_COLUMNS*TILE_SIZE or world.y > MAX_ROWS*TILE_SIZE: return {}
	var columns := int(ceilf(world.x/TILE_SIZE))
	var rows := int(ceilf(world.y/TILE_SIZE))
	var values: Variant = layout.get("play_bounds",[0,0,world.x,world.y])
	if not _numbers(values,4): return {}
	var bounds := Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
	var freeform: bool = layout.get("layout_mode","") == "freeform"
	var floor_cells := {}
	var solid_cells := {}
	var overrides := {}
	var manual: Variant = layout.get("collision_overrides",[])
	if manual is Array:
		for value: Variant in manual:
			if not value is Dictionary or not _integer(value.get("x")) or not _integer(value.get("y")) or not value.get("blocked") is bool: continue
			if float(value.x) < 0 or float(value.y) < 0 or float(value.x) >= columns or float(value.y) >= rows: continue
			overrides[Vector2i(int(value.x),int(value.y))] = bool(value.blocked)
	var painted: Variant = layout.get("painted_tiles",[])
	if painted is Array:
		for value: Variant in painted:
			if not value is Dictionary: continue
			if not _integer(value.get("x")) or not _integer(value.get("y")): continue
			# Check original numbers before narrowing into Vector2i coordinates.
			if float(value.x) < 0 or float(value.y) < 0 or float(value.x) >= columns or float(value.y) >= rows: continue
			var cell := Vector2i(int(value.x),int(value.y))
			var solid: bool = value.get("solid",false) is bool and value.get("solid",false)
			var layer := str(value.get("layer","structure" if solid else "floor"))
			if layer == "floor": floor_cells[cell] = true
			if solid: solid_cells[cell] = true
	var void_rectangles := _rectangles(layout.get("void_obstacles",[]))
	var void_rect_set := {}
	for rect: Rect2 in void_rectangles: void_rect_set[rect] = true
	var wall_rectangles: Array[Rect2] = []
	for rect: Rect2 in _rectangles(layout.get("obstacles",[])):
		if not void_rect_set.has(rect): wall_rectangles.append(rect)
	var void_cells := _rectangle_cells(void_rectangles,columns,rows)
	var wall_cells := _rectangle_cells(wall_rectangles,columns,rows)
	var result := {}
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x,y)
			var center := (Vector2(cell)+Vector2.ONE*0.5)*TILE_SIZE
			if center.x > world.x or center.y > world.y or not _contains_closed(bounds,center):
				result[cell] = _state("void",true,"Außerhalb der Raumfläche")
			elif overrides.has(cell):
				result[cell] = _state("wall",true,"Manuell blockiert") if overrides[cell] else _state("walkable",false,"Manuell begehbar")
			elif solid_cells.has(cell) or wall_cells.has(cell):
				result[cell] = _state("wall",true,"Blockierende Wand")
			elif void_cells.has(cell) or (freeform and not floor_cells.has(cell)):
				result[cell] = _state("void",true,"Leere Fläche / kein Boden")
			else:
				result[cell] = _state("walkable",false,"Begehbarer Boden")
	return result

static func _state(kind: String, blocked: bool, reason: String) -> Dictionary:
	return {"kind":kind,"blocked":blocked,"reason":reason}

static func _rectangles(value: Variant) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not value is Array: return result
	for entry: Variant in value:
		if not _numbers(entry,4) or float(entry[2]) <= 0 or float(entry[3]) <= 0: continue
		result.append(Rect2(float(entry[0]),float(entry[1]),float(entry[2]),float(entry[3])))
	return result

static func _rectangle_cells(rectangles: Array[Rect2], columns: int, rows: int) -> Dictionary:
	var result := {}
	for rect: Rect2 in rectangles:
		# Cell centers on a closed AABB edge are blocked, like segment_blocked().
		var minimum_x := maxi(0,int(ceilf((rect.position.x-TILE_SIZE*0.5)/TILE_SIZE)))
		var maximum_x := mini(columns-1,int(floorf((rect.end.x-TILE_SIZE*0.5)/TILE_SIZE)))
		var minimum_y := maxi(0,int(ceilf((rect.position.y-TILE_SIZE*0.5)/TILE_SIZE)))
		var maximum_y := mini(rows-1,int(floorf((rect.end.y-TILE_SIZE*0.5)/TILE_SIZE)))
		for y in range(minimum_y,maximum_y+1):
			for x in range(minimum_x,maximum_x+1): result[Vector2i(x,y)] = true
	return result

static func _contains_closed(rect: Rect2, point: Vector2) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and floorf(float(value)) == float(value)

static func _numbers(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size: return false
	for number: Variant in value:
		if not _number(number): return false
	return true

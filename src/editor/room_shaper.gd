extends RefCounted
## Layout suggestions for the Dungeon-Werkstatt (button GRUNDRISS), numbers in
## assets/data/dungeon_shapes.json. Two styles:
## - "labyrinth": a chain of chambers from west to east (now and then north or
##   south), joined by straight corridors two cells wide; side chambers off the
##   path are dead ends with a chest; sometimes a loop saves the walk back.
## - "throne": a small antechamber in the south, a corridor north into a great
##   symmetric hall with a pair of side niches; the throne spot lies under the
##   hall's north wall, the stairs down right behind it.
## Pure data in, data out (cells are Vector2i), so it is testable without UI;
## the editor checks every suggestion with the game's own rules.

const DATA_PATH := "res://assets/data/dungeon_shapes.json"
const NONE := Vector2i(-1, -1)


## The catalog of styles (loaded on demand).
static func settings() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## The room size a style needs: the current size when it is big enough,
## otherwise the style's own size.
static func room_size(style: String, current: Vector2i, data: Dictionary = {}) -> Vector2i:
	if data.is_empty(): data = settings()
	var spec: Dictionary = data.get("styles", {}).get(style, {})
	var low: Array = spec.get("min_room", [12, 10])
	var wanted: Array = spec.get("room", low)
	if current.x >= int(low[0]) and current.y >= int(low[1]): return current
	return Vector2i(maxi(current.x, int(wanted[0])), maxi(current.y, int(wanted[1])))


## One suggestion for a room of `size` cells: {floor (cell -> true),
## chambers: Array[Rect2i], main: Array[int] (chambers on the path, in order),
## side: Array[int] (dead ends), corridors: Array[Rect2i], start, enemies,
## chests, stairs (NONE outside throne rooms), throne (NONE outside throne rooms)}.
static func suggest(style: String, size: Vector2i, seed_value: int, data: Dictionary = {}) -> Dictionary:
	if data.is_empty(): data = settings()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spec: Dictionary = data.get("styles", {}).get(style, {})
	var width := maxi(2, int(data.get("corridor_width", 2)))
	if style == "throne": return _throne(spec, size, width, rng)
	return _labyrinth(spec, size, width, rng)


# --- Labyrinth ----------------------------------------------------------------------

static func _labyrinth(spec: Dictionary, size: Vector2i, width: int, rng: RandomNumberGenerator) -> Dictionary:
	var inner := Rect2i(2, 2, size.x - 4, size.y - 4)
	var chambers: Array[Rect2i] = []
	var corridors: Array[Rect2i] = []
	var main: Array[int] = []
	var side: Array[int] = []
	var first := _chamber_size(spec, rng, false)
	chambers.append(Rect2i(inner.position.x + rng.randi_range(0, 2), rng.randi_range(inner.position.y, maxi(inner.position.y, inner.end.y - first.y)), first.x, first.y))
	main.append(0)
	var wanted := _between(spec.get("chambers", [3, 5]), rng)
	var weights: Dictionary = spec.get("turn_weights", {"east": 4.0, "north": 1.5, "south": 1.5})
	var last := Vector2i.ZERO
	# Pacing: small and large chambers take turns along the path (every
	# `large_every`-th one is large); a large one that does not fit falls back to small.
	var every := maxi(1, int(spec.get("large_every", 2)))
	while main.size() < wanted:
		var placed := false
		var want_large := main.size() % every == every - 1 or every == 1
		for attempt in range(40):
			var direction := _direction(weights, last, rng)
			var large := want_large and attempt < 30
			var link := _attach(chambers[main.back()], direction, _chamber_size(spec, rng, large), _between(spec.get("corridor", [3, 7]), rng), width, inner, chambers, corridors, rng)
			if link.is_empty(): continue
			chambers.append(link.room)
			corridors.append(link.corridor)
			main.append(chambers.size() - 1)
			last = direction
			placed = true
			break
		if not placed: break
	# Side chambers off the path: dead ends, each with a chest.
	for index in range(_between(spec.get("side_rooms", [1, 2]), rng)):
		for attempt in range(40):
			var host: int = main[rng.randi_range(mini(1, main.size() - 1), main.size() - 1)]
			var direction: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT][rng.randi_range(0, 3)]
			var link := _attach(chambers[host], direction, _chamber_size(spec, rng, false), rng.randi_range(2, 5), width, inner, chambers, corridors, rng)
			if link.is_empty(): continue
			chambers.append(link.room)
			corridors.append(link.corridor)
			side.append(chambers.size() - 1)
			break
	# A loop between two chambers of the path that are two steps apart.
	if main.size() >= 3 and rng.randf() < float(spec.get("loop_chance", 0.3)):
		var at := rng.randi_range(0, main.size() - 3)
		for vertical_first: bool in [rng.randf() < 0.5, true, false]:
			var path := _elbow(chambers[main[at]], chambers[main[at + 2]], width, vertical_first)
			if _clear_of(path, chambers, [main[at], main[at + 2]], inner):
				corridors.append_array(path)
				break
	var result := _cells(size, chambers, corridors)
	var entry: Rect2i = chambers[main[0]]
	result.start = Vector2i(entry.position.x + mini(2, entry.size.x - 1), entry.position.y + entry.size.y / 2)
	result.enemies = []
	for index: int in main.slice(1):
		if chambers[index].size.x >= 9: result.enemies.append(chambers[index].get_center())
	if result.enemies.is_empty() and main.size() > 1: result.enemies.append(chambers[main.back()].get_center())
	result.chests = side.map(func(index: int) -> Vector2i: return chambers[index].get_center())
	result.chambers = chambers
	result.main = main
	result.side = side
	result.corridors = corridors
	result.stairs = NONE
	result.throne = NONE
	return result


static func _chamber_size(spec: Dictionary, rng: RandomNumberGenerator, large: bool) -> Vector2i:
	var bounds: Array = spec.get("large" if large else "small", [5, 4, 7, 6])
	return Vector2i(rng.randi_range(int(bounds[0]), int(bounds[2])), rng.randi_range(int(bounds[1]), int(bounds[3])))


static func _between(bounds: Array, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(int(bounds[0]), int(bounds[1]))


## Mostly east (the way through), sometimes north or south; never straight back.
static func _direction(weights: Dictionary, last: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var options := {Vector2i.RIGHT: float(weights.get("east", 4.0)), Vector2i.UP: float(weights.get("north", 1.5)), Vector2i.DOWN: float(weights.get("south", 1.5))}
	if last != Vector2i.ZERO: options.erase(-last)
	var total := 0.0
	for weight: float in options.values(): total += weight
	var roll := rng.randf() * total
	for direction: Vector2i in options:
		roll -= float(options[direction])
		if roll <= 0.0: return direction
	return Vector2i.RIGHT


## A new chamber `room_size` beside `from` in `direction`, joined by a straight
## corridor `length` long and `width` wide that enters both chambers with a
## cell of wall to spare. {} when it does not fit or touches other floor.
static func _attach(from: Rect2i, direction: Vector2i, room_size: Vector2i, length: int, width: int, inner: Rect2i, chambers: Array[Rect2i], corridors: Array[Rect2i], rng: RandomNumberGenerator) -> Dictionary:
	var room := Rect2i(Vector2i.ZERO, room_size)
	var corridor := Rect2i()
	if direction.x != 0:
		var low := from.position.y + 1
		var high := from.end.y - 1 - width
		if high < low or room_size.y - 1 - width < 1: return {}
		var row := rng.randi_range(low, high)
		room.position.y = rng.randi_range(row - (room_size.y - 1 - width), row - 1)
		room.position.x = from.end.x + length if direction.x > 0 else from.position.x - length - room_size.x
		corridor = Rect2i(from.end.x if direction.x > 0 else from.position.x - length, row, length, width)
	else:
		var low := from.position.x + 1
		var high := from.end.x - 1 - width
		if high < low or room_size.x - 1 - width < 1: return {}
		var column := rng.randi_range(low, high)
		room.position.x = rng.randi_range(column - (room_size.x - 1 - width), column - 1)
		room.position.y = from.end.y + length if direction.y > 0 else from.position.y - length - room_size.y
		corridor = Rect2i(column, from.end.y if direction.y > 0 else from.position.y - length, width, length)
	if not inner.encloses(room) or not inner.encloses(corridor): return {}
	for other: Rect2i in chambers:
		if other.grow(2).intersects(room): return {}
		if other != from and other.grow(1).intersects(corridor): return {}
	for other: Rect2i in corridors:
		if other.grow(1).intersects(room) or other.grow(1).intersects(corridor): return {}
	return {"room": room, "corridor": corridor}


## An L-shaped corridor from the middle of `a` to the middle of `b`.
static func _elbow(a: Rect2i, b: Rect2i, width: int, vertical_first: bool) -> Array[Rect2i]:
	var from := a.get_center()
	var to := b.get_center()
	var corner := Vector2i(from.x, to.y) if vertical_first else Vector2i(to.x, from.y)
	var parts: Array[Rect2i] = []
	for pair: Array in [[from, corner], [corner, to]]:
		var p: Vector2i = pair[0]
		var q: Vector2i = pair[1]
		parts.append(Rect2i(mini(p.x, q.x), mini(p.y, q.y), absi(q.x - p.x) + width, absi(q.y - p.y) + width))
	return parts


static func _clear_of(path: Array[Rect2i], chambers: Array[Rect2i], allowed: Array, inner: Rect2i) -> bool:
	for part: Rect2i in path:
		if not inner.encloses(part): return false
		for index in range(chambers.size()):
			if index in allowed: continue
			if chambers[index].grow(1).intersects(part): return false
	return true


# --- Throne hall --------------------------------------------------------------------

static func _throne(spec: Dictionary, size: Vector2i, width: int, rng: RandomNumberGenerator) -> Dictionary:
	var hall_bounds: Array = spec.get("hall", [20, 13, 28, 17])
	var ante_size: Array = spec.get("antechamber", [11, 6])
	var alcove: Array = spec.get("alcove", [3, 4])
	var with_alcoves: bool = bool(spec.get("alcoves", true))
	var length := _between(spec.get("corridor", [4, 6]), rng)
	var centre := size.x / 2
	# Odd widths keep a middle column, so the hall mirrors around the throne.
	var side_room := int(alcove[0]) if with_alcoves else 0
	var hall_width := clampi(size.x - 6 - 2 * side_room, int(hall_bounds[0]), int(hall_bounds[2]))
	if hall_width % 2 == 0: hall_width -= 1
	var ante := Vector2i(int(ante_size[0]) | 1, int(ante_size[1]))
	var hall_height := clampi(size.y - 4 - length - ante.y, int(hall_bounds[1]), int(hall_bounds[3]))
	var hall := Rect2i(centre - hall_width / 2, 2, hall_width, hall_height)
	var corridor_width := width + 1 if width % 2 == 0 else width
	var corridor := Rect2i(centre - corridor_width / 2, hall.end.y, corridor_width, length)
	var antechamber := Rect2i(centre - ante.x / 2, corridor.end.y, ante.x, ante.y)
	var chambers: Array[Rect2i] = [antechamber, hall]
	var corridors: Array[Rect2i] = [corridor]
	if with_alcoves:
		var top := hall.position.y + hall.size.y / 2 - int(alcove[1]) / 2
		chambers.append(Rect2i(hall.position.x - int(alcove[0]), top, int(alcove[0]), int(alcove[1])))
		chambers.append(Rect2i(hall.end.x, top, int(alcove[0]), int(alcove[1])))
	var result := _cells(size, chambers, corridors)
	result.start = antechamber.get_center()
	result.throne = Vector2i(centre, hall.position.y + 3)
	result.stairs = Vector2i(centre, hall.position.y + 1)
	result.enemies = [result.throne]
	result.chests = []
	result.chambers = chambers
	result.main = [0, 1]
	result.side = []
	result.corridors = corridors
	return result


## Floor cells of the chambers and corridors, inside the paintable area.
static func _cells(size: Vector2i, chambers: Array[Rect2i], corridors: Array[Rect2i]) -> Dictionary:
	var floor_cells := {}
	for rect: Rect2i in chambers + corridors:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if x >= 1 and y >= 1 and x <= size.x - 2 and y <= size.y - 2: floor_cells[Vector2i(x, y)] = true
	return {"floor": floor_cells}

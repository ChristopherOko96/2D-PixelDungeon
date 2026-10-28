extends RefCounted
## One room being edited in the Dungeon-Werkstatt. The author paints floor
## cells and sets markers (player start, enemies, chests, torches, boss
## stairs); walls, gates, spawn points and the generator's fields follow
## automatically (`to_template`). Undo and redo keep whole snapshots.
## Testable without UI. Rules come from the generator (dungeon_generator.gd):
## sizes 12-64 x 10-48 cells, a free border for the walls, gates on north
## walls, 4 player and at least 5 enemy spawn points, a stairs spot in boss rooms.
## Decor (floor styles, carpets, wall pieces, objects; see decor_catalog.gd)
## is placed by rules: wall pieces on walls with floor below, objects on
## floor; solid objects never block a gate, the start or split the floor, and
## they reach the game as obstacles_tiles.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const RoomPool = preload("res://src/editor/room_pool.gd")
const Decor = preload("res://src/dungeon/decor_catalog.gd")
const CELL := 32
const NONE := Vector2i(-1, -1)
const MIN_SIZE := Vector2i(12, 10)
const MAX_SIZE := Vector2i(64, 48)
const MAX_TORCHES := 16
const MIN_ENEMIES := 5
const UNDO_LIMIT := 80
const MAX_DECOR := 2048
const SIDES := ["north", "east", "south", "west"]
const STEPS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const AROUND := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

## The room as stored (the generator's template); fields the editor does not
## know stay as they are.
var room: Dictionary = {}
var size := Vector2i(40, 26)
## Floor cells (Vector2i -> true); walls are derived.
var floor_cells: Dictionary = {}
var start := NONE
var enemies: Array[Vector2i] = []
var chests: Array[Vector2i] = []
## Chest spots that always hold a Mimik (a chest that bites; template mimic_spawns).
var mimics: Array[Vector2i] = []
var torches: Array[Vector2i] = []
var stairs := NONE
## True when the shape came from a crypt recipe that varies per run; the
## first change of the shape fixes it as painted.
var from_recipe := false
## Wall pieces and objects: cell -> [id, variant] (one per cell).
var decor: Dictionary = {}
## Painted areas: cell -> [id, variant]; a floor style and a carpet may share a cell.
var floor_styles: Dictionary = {}
var carpets: Dictionary = {}
## True while the game decorates the room by itself (torches, banners,
## skulls); the author's first decor piece adopts that decor and turns it off.
var auto_decor := true
var dirty := false
var _undo: Array = []
var _redo: Array = []
## Obstacles stored with the room that are not solid decor (kept as they are).
var _other_obstacles: Array = []
var _gates: Array = []
var _gates_known := false
var _batch := false


## A new empty room of `cells` with a floor in the middle.
static func blank(id: String, title: String, cells: Vector2i = Vector2i(40, 26)) -> RefCounted:
	var doc = load("res://src/editor/room_doc.gd").new()
	doc.room = {"id": id, "title": title, "boss": false, "theme": "amber", "room_theme": "entrance", "layout_mode": "freeform", "crypt_profile": true,
		"obstacles_tiles": [], "floors": [1, 10], "decoration_enabled": true, "encounter": {"enemy_spacing": 80, "max_enemies": 7, "min_enemies": 5, "spawn_min_distance": 288}}
	doc.size = Vector2i(clampi(cells.x, MIN_SIZE.x, MAX_SIZE.x), clampi(cells.y, MIN_SIZE.y, MAX_SIZE.y))
	doc.fill_rect(Vector2i(4, 4), doc.size - Vector2i(5, 5), true, false)
	doc.start = Vector2i(6, doc.size.y / 2)
	doc.dirty = true
	return doc


## Loads a stored room (template).
static func from_template(template: Dictionary) -> RefCounted:
	var doc = load("res://src/editor/room_doc.gd").new()
	doc.room = template.duplicate(true)
	var world: Array = template.get("world_size", [1280, 832])
	doc.size = Vector2i(int(float(world[0]) / CELL), int(float(world[1]) / CELL))
	for cell: Dictionary in template.get("painted_tiles", []):
		if str(cell.get("layer", "")) == "floor" and not bool(cell.get("solid", false)): doc.floor_cells[Vector2i(int(cell.x), int(cell.y))] = true
	var spawns: Array = template.get("player_spawns", [])
	if not spawns.is_empty():
		var centre := Vector2.ZERO
		for point: Array in spawns: centre += Vector2(float(point[0]), float(point[1]))
		doc.start = _cell_of(centre / float(spawns.size()))
	for point: Array in template.get("enemy_spawns", []): doc.enemies.append(_cell_of(Vector2(float(point[0]), float(point[1]))))
	for point: Array in template.get("brazier_spawns", []): doc.torches.append(_cell_of(Vector2(float(point[0]), float(point[1]))))
	for cell: Array in template.get("chest_spawns", []): doc.chests.append(Vector2i(int(cell[0]), int(cell[1])))
	for cell: Array in template.get("mimic_spawns", []): doc.mimics.append(Vector2i(int(cell[0]), int(cell[1])))
	if template.has("stairs_spawn"): doc.stairs = _cell_of(Vector2(float(template.stairs_spawn[0]), float(template.stairs_spawn[1])))
	doc.from_recipe = template.has("crypt_recipe")
	for entry: Variant in template.get("decor", []):
		if entry is Array and entry.size() >= 3: doc.decor[Vector2i(int(entry[0]), int(entry[1]))] = [str(entry[2]), int(entry[3]) if entry.size() > 3 else 0]
	for entry: Variant in template.get("decor_areas", []):
		if not entry is Array or entry.size() < 3: continue
		var layer: Dictionary = doc.carpets if Decor.kind(str(entry[2])) == "carpet" else doc.floor_styles
		layer[Vector2i(int(entry[0]), int(entry[1]))] = [str(entry[2]), int(entry[3]) if entry.size() > 3 else 0]
	doc.auto_decor = bool(template.get("auto_decor", true))
	for value: Variant in template.get("obstacles_tiles", []):
		var rect: Array = value
		var cell := Vector2i(int(rect[0]), int(rect[1]))
		var solid_decor: bool = int(rect[2]) == 1 and int(rect[3]) == 1 and doc.decor.has(cell) and Decor.is_solid(str(doc.decor[cell][0]))
		if not solid_decor: doc._other_obstacles.append(rect.duplicate())
	return doc


static func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))


# --- Editing ----------------------------------------------------------------------

## Remembers the state before a change (one stroke = one undo step).
func begin_change() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_LIMIT: _undo.pop_front()
	_redo.clear()
	_gates_known = false


func undo() -> bool:
	if _undo.is_empty(): return false
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	return true


func redo() -> bool:
	if _redo.is_empty(): return false
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	return true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


## True when floor may lie on `cell` (one free border for the walls).
func paintable(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.y >= 1 and cell.x <= size.x - 2 and cell.y <= size.y - 2


## Paints (or erases) floor in a square brush of `radius` cells around `cell`.
func brush(cell: Vector2i, radius: int, erase: bool) -> void:
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			_set_floor(Vector2i(x, y), not erase)


## Fills (or clears) the rectangle between two corner cells.
func fill_rect(a: Vector2i, b: Vector2i, fill: bool, mark: bool = true) -> void:
	var low := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var high := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			_set_floor(Vector2i(x, y), fill)
	if mark: dirty = true


func _set_floor(cell: Vector2i, on: bool) -> void:
	if on and not paintable(cell): return
	if on == floor_cells.has(cell): return
	if on:
		floor_cells[cell] = true
		# A wall piece on this cell loses its wall.
		decor.erase(cell)
	else:
		floor_cells.erase(cell)
		# Markers and decor never float over a hole.
		enemies.erase(cell)
		chests.erase(cell)
		mimics.erase(cell)
		torches.erase(cell)
		if start == cell: start = NONE
		if stairs == cell: stairs = NONE
		decor.erase(cell)
		floor_styles.erase(cell)
		carpets.erase(cell)
		# The piece on the wall above loses the floor below it.
		if decor.has(cell + Vector2i.UP) and Decor.kind(str(decor[cell + Vector2i.UP][0])) == "wall": decor.erase(cell + Vector2i.UP)
	from_recipe = false
	dirty = true
	_gates_known = false


## Sets or removes a marker on a floor cell. `kind`: "start", "enemy",
## "chest", "torch", "stairs". Removing clears whatever marker lies there.
## Returns false when the cell is not floor.
func set_marker(kind: String, cell: Vector2i, remove: bool = false) -> bool:
	if remove:
		var found := enemies.has(cell) or chests.has(cell) or mimics.has(cell) or torches.has(cell) or start == cell or stairs == cell
		mimics.erase(cell)
		enemies.erase(cell)
		chests.erase(cell)
		torches.erase(cell)
		if start == cell: start = NONE
		if stairs == cell: stairs = NONE
		if found: dirty = true
		return found
	if not floor_cells.has(cell) or solid_at(cell): return false
	if kind in ["start", "enemy"] and _solid_near(cell): return false
	match kind:
		"start": start = cell
		"stairs": stairs = cell
		"enemy":
			if not enemies.has(cell): enemies.append(cell)
		"chest":
			# A second click turns a chest into a Mimik and back.
			if mimics.has(cell):
				mimics.erase(cell)
				chests.append(cell)
			elif chests.has(cell):
				chests.erase(cell)
				mimics.append(cell)
			else: chests.append(cell)
		"torch":
			if not torches.has(cell) and torches.size() < MAX_TORCHES: torches.append(cell)
	dirty = true
	_gates_known = false
	return true


# --- Decor ------------------------------------------------------------------------

## True when a solid decor piece stands on `cell`.
func solid_at(cell: Vector2i) -> bool:
	return decor.has(cell) and Decor.is_solid(str(decor[cell][0]))


## True when a solid piece stands on `cell` or one of its eight neighbours.
func _solid_near(cell: Vector2i) -> bool:
	if solid_at(cell): return true
	for offset: Vector2i in AROUND:
		if solid_at(cell + offset): return true
	return false


## What lies on `cell`, topmost first: an object or wall piece, else a carpet,
## else a floor style. {} when nothing. {id, variant, layer}.
func decor_at(cell: Vector2i) -> Dictionary:
	for pair: Array in [[decor, "piece"], [carpets, "carpet"], [floor_styles, "floor"]]:
		var layer: Dictionary = pair[0]
		if layer.has(cell): return {"id": str(layer[cell][0]), "variant": int(layer[cell][1]), "layer": pair[1]}
	return {}


## Why piece `id` cannot go on `cell` (German, for the hint line), or "" when
## it can. `moving` is the cell a piece is being moved away from.
func decor_problem(id: String, cell: Vector2i, moving: Vector2i = NONE) -> String:
	var item := Decor.item(id)
	if item.is_empty(): return "UNBEKANNTES TEIL"
	if Decor.is_area(id): return "" if floor_cells.has(cell) else "NUR AUF BODEN"
	if decor.has(cell) and cell != moving: return "PLATZ BESETZT"
	if decor.size() >= MAX_DECOR and moving == NONE: return "ZU VIELE TEILE"
	var hangs_below: bool = str(item.get("draw", "")) == "fountain" or item.has("below")
	if str(item.kind) == "wall":
		if not Decor.wall_spot(floor_cells, cell): return "NUR AN WAND ÜBER BODEN"
		for gate: Vector2i in gate_spots():
			if cell.y == gate.y and cell.x >= gate.x - 1 and cell.x <= gate.x + 2: return "HIER KOMMT EIN TOR HIN"
		if hangs_below and decor.has(cell + Vector2i.DOWN) and cell + Vector2i.DOWN != moving: return "UNTEN IST BESETZT"
		return ""
	if not floor_cells.has(cell): return "NUR AUF BODEN"
	var above: Vector2i = cell + Vector2i.UP
	if decor.has(above) and above != moving:
		var over := Decor.item(str(decor[above][0]))
		if str(over.get("draw", "")) == "fountain" or over.has("below"): return "PLATZ BESETZT"
	if not Decor.is_solid(id): return ""
	if cell == start or cell == stairs or enemies.has(cell) or chests.has(cell) or mimics.has(cell) or torches.has(cell): return "HIER LIEGT EINE MARKIERUNG"
	if start != NONE and absi(cell.x - start.x) <= 1 and absi(cell.y - start.y) <= 1: return "VERSPERRT DEN START"
	# Big enemies need a free ring around their first spot.
	for enemy: Vector2i in enemies:
		if absi(cell.x - enemy.x) <= 1 and absi(cell.y - enemy.y) <= 1: return "ZU NAH AN EINEM GEGNER"
	for gate: Vector2i in gate_spots():
		if cell.x >= gate.x - 1 and cell.x <= gate.x + 2 and cell.y >= gate.y + 1 and cell.y <= gate.y + 2: return "VERSPERRT DAS TOR"
	if _splits(cell, moving): return "TEILT DEN RAUM"
	return ""


## Places piece `id` on `cell` (call begin_change first). Returns the
## problem text, "" when placed. The first piece in a room adopts the game's
## own decor (`adopt`) so nothing it showed disappears.
func place_decor(id: String, cell: Vector2i, variant: int = 0, adopted: Array = []) -> String:
	var problem := decor_problem(id, cell)
	if not problem.is_empty(): return problem
	if auto_decor: adopt(adopted)
	if not decor_problem(id, cell).is_empty(): return decor_problem(id, cell)
	decor[cell] = [id, posmod(variant, Decor.variants(id))]
	_decor_changed()
	return ""


## Removes the piece on `cell` (wall piece or object). True when one was there.
func remove_decor(cell: Vector2i) -> bool:
	if not decor.has(cell): return false
	decor.erase(cell)
	_decor_changed()
	return true


## Moves the piece on `from` to `to`. Returns the problem text, "" when moved.
func move_decor(from: Vector2i, to: Vector2i) -> String:
	if not decor.has(from): return "HIER IST NICHTS"
	if from == to: return ""
	var piece: Array = decor[from]
	var problem := decor_problem(str(piece[0]), to, from)
	if not problem.is_empty(): return problem
	decor.erase(from)
	decor[to] = piece
	_decor_changed()
	return ""


## Next variant of the piece on `cell` (banner colour, sign...). True when changed.
func cycle_variant(cell: Vector2i) -> bool:
	var pick := decor_at(cell)
	if pick.is_empty() or Decor.variants(pick.id) < 2: return false
	var layer: Dictionary = {"piece": decor, "carpet": carpets, "floor": floor_styles}[pick.layer]
	layer[cell] = [pick.id, (int(pick.variant) + 1) % Decor.variants(pick.id)]
	_decor_changed()
	return true


## Paints (or with `erase` removes) floor style or carpet `id` on the cells of
## a square brush. Each painted cell takes `variant` or, with `random`, a
## random one. Erasing removes whatever lies on that layer.
func paint_area(id: String, cell: Vector2i, radius: int, erase: bool, variant: int = 0, random: bool = false, rng: RandomNumberGenerator = null) -> int:
	return _paint_cells(id, _square(cell, cell, radius), erase, variant, random, rng)


## Like `paint_area` for the rectangle between two corner cells.
func paint_area_rect(id: String, a: Vector2i, b: Vector2i, erase: bool, variant: int = 0, random: bool = false, rng: RandomNumberGenerator = null) -> int:
	return _paint_cells(id, _square(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), Vector2i(maxi(a.x, b.x), maxi(a.y, b.y)), 0), erase, variant, random, rng)


func _square(low: Vector2i, high: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(low.y - radius, high.y + radius + 1):
		for x in range(low.x - radius, high.x + radius + 1): cells.append(Vector2i(x, y))
	return cells


func _paint_cells(id: String, cells: Array[Vector2i], erase: bool, variant: int, random: bool, rng: RandomNumberGenerator) -> int:
	if not Decor.is_area(id): return 0
	var layer: Dictionary = carpets if Decor.kind(id) == "carpet" else floor_styles
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = hash(cells)
	var changed := 0
	for cell: Vector2i in cells:
		if erase:
			if layer.erase(cell): changed += 1
		elif floor_cells.has(cell):
			var value := [id, Decor.pick_variant(id, variant, random, rng)]
			if layer.get(cell, []) != value:
				layer[cell] = value
				changed += 1
	if changed > 0: _decor_changed()
	return changed


## Turns the game's own decor (`items`: [x, y, id, variant] as the crypt
## renderer reports them) into the room's decor and switches auto decor off.
func adopt(items: Array) -> void:
	auto_decor = false
	for entry: Variant in items:
		if not entry is Array or entry.size() < 3: continue
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		var id := str(entry[2])
		if Decor.item(id).is_empty() or decor.has(cell): continue
		if str(Decor.item(id).kind) == "wall" and not Decor.wall_spot(floor_cells, cell): continue
		if str(Decor.item(id).kind) == "object" and not floor_cells.has(cell): continue
		decor[cell] = [id, int(entry[3]) if entry.size() > 3 else 0]
	_decor_changed()


## Removes every decor piece and area; the game's own decor stays off.
func clear_decor() -> void:
	decor.clear()
	floor_styles.clear()
	carpets.clear()
	auto_decor = false
	_decor_changed()


## Switches the game's own decor on or off. Off adopts it first (`items`),
## so the pieces stay and can be moved; on keeps the author's pieces too.
func set_auto_decor(on: bool, items: Array = []) -> void:
	if on == auto_decor: return
	if on: auto_decor = true
	else: adopt(items)
	_decor_changed()


func _decor_changed() -> void:
	# Decor is tied to the painted walls: a recipe room keeps this shape now.
	from_recipe = false
	dirty = true
	if not _batch: _gates_known = false


## Many pieces at once (the decor suggestion): the gates are worked out once
## at the start instead of after every piece. Pair with `end_batch`.
func begin_batch() -> void:
	gate_spots()
	_batch = true


func end_batch() -> void:
	_batch = false
	_gates_known = false


## Replaces the room with a layout suggestion (room_shaper.gd): floor, start,
## enemy and chest spots, the stairs in a boss room; decor and other markers
## are cleared and the game decorates by itself again. Call begin_change first.
func apply_shape(shape: Dictionary, cells: Vector2i) -> void:
	size = Vector2i(clampi(cells.x, MIN_SIZE.x, MAX_SIZE.x), clampi(cells.y, MIN_SIZE.y, MAX_SIZE.y))
	floor_cells = Dictionary(shape.get("floor", {})).duplicate()
	start = shape.get("start", NONE)
	enemies.assign(shape.get("enemies", []))
	chests.assign(shape.get("chests", []))
	mimics.clear()
	torches.clear()
	stairs = shape.get("stairs", NONE) if role() == "boss" else NONE
	decor.clear()
	floor_styles.clear()
	carpets.clear()
	auto_decor = true
	from_recipe = false
	dirty = true
	_gates_known = false


## Cells of the gates the game would set now (cached between changes).
func gate_spots() -> Array:
	if not _gates_known:
		_gates = gate_cells()
		_gates_known = true
	return _gates


## True when a solid piece on `cell` would cut the floor in two (`moving`
## stays free: the piece leaves it).
func _splits(cell: Vector2i, moving: Vector2i = NONE) -> bool:
	var blocked := {cell: true}
	for other: Vector2i in decor:
		if other != moving and Decor.is_solid(str(decor[other][0])): blocked[other] = true
	var first := NONE
	for candidate: Vector2i in floor_cells:
		if not blocked.has(candidate):
			first = candidate
			break
	if first == NONE: return true
	var seen := {first: true}
	var queue: Array[Vector2i] = [first]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next: Vector2i = at + step
			if floor_cells.has(next) and not blocked.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var free := 0
	for candidate: Vector2i in floor_cells:
		if not blocked.has(candidate): free += 1
	return seen.size() != free


## Changes the room's size (cells); floor outside the new edge is dropped.
func resize(cells: Vector2i) -> void:
	size = Vector2i(clampi(cells.x, MIN_SIZE.x, MAX_SIZE.x), clampi(cells.y, MIN_SIZE.y, MAX_SIZE.y))
	for cell: Vector2i in floor_cells.keys():
		if not paintable(cell): _set_floor(cell, false)
	for cell: Vector2i in decor.keys():
		if cell.x >= size.x or cell.y >= size.y: decor.erase(cell)
	dirty = true
	_gates_known = false


## Room role ("entrance", "normal", "boss") and floor range.
func role() -> String:
	return RoomPool.role(room)


func set_role(value: String) -> void:
	RoomPool.set_role(room, value)
	dirty = true


func set_floors(first: int, last: int) -> void:
	room.floors = [mini(first, last), maxi(first, last)]
	dirty = true


func set_title(value: String) -> void:
	room.title = value.strip_edges()
	dirty = true


# --- Output -----------------------------------------------------------------------

## Wall cells: every free cell touching the floor (also diagonally).
func walls() -> Dictionary:
	var result := {}
	for cell: Vector2i in floor_cells:
		for offset: Vector2i in AROUND:
			var next: Vector2i = cell + offset
			if not floor_cells.has(next): result[next] = true
	return result


## The room in the generator's template format: floor and walls, spawn points
## (4 around the start, at least 5 enemy points), torches, chests, stairs and
## one door per side the generator can use.
func to_template() -> Dictionary:
	var result := room.duplicate(true)
	if not from_recipe: result.erase("crypt_recipe")
	var theme := str(result.get("theme", "amber"))
	if theme not in Dungeon.THEMES: theme = "amber"
	result.theme = theme
	result.layout_mode = "freeform"
	result.crypt_profile = true
	result.world_size = [size.x * CELL, size.y * CELL]
	result.play_bounds = [0, 0, size.x * CELL, size.y * CELL]
	_markers_into(result)
	_decor_into(result)
	# A recipe room whose shape was not touched keeps its floor and doors: the
	# game reshapes it per run, the stored cells are only one example.
	if from_recipe: return _plain(result)
	var tiles: Array = []
	var ordered := floor_cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in ordered: tiles.append({"x": cell.x, "y": cell.y, "layer": "floor", "tile": theme + "_017", "solid": false, "rotation": 0})
	var wall_list := walls().keys()
	wall_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in wall_list: tiles.append({"x": cell.x, "y": cell.y, "layer": "structure", "tile": theme + "_002", "solid": true, "rotation": 0, "crypt_wall": true})
	result.painted_tiles = tiles
	result.authored_doors = _doors(result)
	return _plain(result)


## Plain JSON data, exactly as the file will hold it (keys set with `a.b = c`
## are StringNames in Godot; the session check and the file want Strings).
static func _plain(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


## Spawn points, torches, chests and stairs from the markers.
func _markers_into(result: Dictionary) -> void:
	result.player_spawns = _player_points()
	result.enemy_spawns = _enemy_points()
	result.brazier_spawns = torches.map(func(cell: Vector2i) -> Array: return _centre(cell))
	result.chest_spawns = chests.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y])
	if mimics.is_empty(): result.erase("mimic_spawns")
	else: result.mimic_spawns = mimics.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y])
	if start != NONE: result.reward_spawn = _centre(start)
	if stairs != NONE and role() == "boss": result.stairs_spawn = _centre(stairs)
	else: result.erase("stairs_spawn")


## Decor lists, the auto-decor switch and the obstacles of solid pieces.
## Keys stay out of the file while they hold their defaults.
func _decor_into(result: Dictionary) -> void:
	var pieces: Array = []
	var solid: Array = []
	for cell: Vector2i in _sorted(decor.keys()):
		pieces.append([cell.x, cell.y, str(decor[cell][0]), int(decor[cell][1])])
		if Decor.is_solid(str(decor[cell][0])): solid.append([cell.x, cell.y, 1, 1])
	var areas: Array = []
	for layer: Dictionary in [floor_styles, carpets]:
		for cell: Vector2i in _sorted(layer.keys()): areas.append([cell.x, cell.y, str(layer[cell][0]), int(layer[cell][1])])
	for pair: Array in [["decor", pieces], ["decor_areas", areas]]:
		if Array(pair[1]).is_empty(): result.erase(pair[0])
		else: result[pair[0]] = pair[1]
	if auto_decor: result.erase("auto_decor")
	else: result.auto_decor = false
	result.obstacles_tiles = _other_obstacles.duplicate(true) + solid


static func _sorted(cells: Array) -> Array:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


func _centre(cell: Vector2i) -> Array:
	return [float(cell.x * CELL + CELL / 2), float(cell.y * CELL + CELL / 2)]


## Four player points: the start and its open neighbours (two cells apart).
func _player_points() -> Array:
	var base := start if start != NONE else _any_floor()
	var points: Array = [_centre(base)]
	for offset: Vector2i in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(1, 0), Vector2i(0, 1)]:
		if points.size() >= 4: break
		if _open(base + offset): points.append(_centre(base + offset))
	while points.size() < 4: points.append(_centre(base))
	return points


## The author's enemy points, completed to five with open spots far from the start.
func _enemy_points() -> Array:
	var points: Array = []
	for cell: Vector2i in enemies: points.append(_centre(cell))
	if points.size() >= MIN_ENEMIES: return points
	var base := start if start != NONE else _any_floor()
	var candidates := floor_cells.keys().filter(func(cell: Vector2i) -> bool: return _open(cell) and not enemies.has(cell))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - base).length_squared() > Vector2(b - base).length_squared())
	var taken: Array[Vector2i] = enemies.duplicate()
	for cell: Vector2i in candidates:
		if points.size() >= MIN_ENEMIES: break
		if taken.any(func(other: Vector2i) -> bool: return Vector2(other - cell).length() < 4.0): continue
		taken.append(cell)
		points.append(_centre(cell))
	return points


## A cell with floor all around (room for a big actor).
func _open(cell: Vector2i) -> bool:
	if not floor_cells.has(cell) or solid_at(cell): return false
	for offset: Vector2i in AROUND:
		if not floor_cells.has(cell + offset) or solid_at(cell + offset): return false
	return true


func _any_floor() -> Vector2i:
	for cell: Vector2i in floor_cells:
		if _open(cell): return cell
	return floor_cells.keys()[0] if not floor_cells.is_empty() else Vector2i(2, 2)


## One door per side the generator can reach: the floor cell furthest towards
## that side whose door has a free approach and four arrival spots.
func _doors(template: Dictionary) -> Array:
	var config := {"tile_size": CELL, "generator_version": Dungeon.GENERATOR_VERSION, "world_size": template.world_size, "play_bounds": template.play_bounds}
	var layout := Dungeon._make_layout(template, config)
	var result: Array = []
	for side: String in SIDES:
		var candidates := floor_cells.keys()
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _towards(a, side) > _towards(b, side))
		for cell: Vector2i in candidates.slice(0, 40):
			var door := {"x": cell.x, "y": cell.y, "side": side, "tile": "items_002", "rotation": 0}
			if not Dungeon._make_authored_door(door, 1, layout).is_empty():
				result.append(door)
				break
	return result


func _towards(cell: Vector2i, side: String) -> float:
	var middle := Vector2(size) * 0.5
	match side:
		"north": return -cell.y * 100.0 - absf(cell.x - middle.x)
		"south": return cell.y * 100.0 - absf(cell.x - middle.x)
		"west": return -cell.x * 100.0 - absf(cell.y - middle.y)
		_: return cell.x * 100.0 - absf(cell.y - middle.y)


# --- Checks -----------------------------------------------------------------------

## The checklist shown beside the room: [{ok, text}] in German. `config` is
## the dungeon library (for the generator's own validation of this room).
func checks(config: Dictionary) -> Array:
	var result: Array = []
	var template := to_template()
	result.append({"ok": floor_cells.size() >= 60, "text": "Boden: %d Felder" % floor_cells.size()})
	result.append({"ok": start != NONE, "text": "Spielerstart gesetzt" if start != NONE else "Spielerstart fehlt (4 START)"})
	result.append({"ok": _connected(), "text": "Boden hängt zusammen" if _connected() else "Boden ist getrennt"})
	var gates := gate_cells(template)
	var needed := 1 if role() != "normal" else 2
	result.append({"ok": gates.size() >= needed, "text": "Tore möglich: %d (mind. %d)" % [gates.size(), needed]})
	result.append({"ok": true, "text": "Gegner: %d gesetzt%s" % [enemies.size(), "" if enemies.size() >= MIN_ENEMIES else ", Rest ergänzt das Spiel"]})
	if role() == "boss": result.append({"ok": stairs != NONE, "text": "Treppe gesetzt" if stairs != NONE else "Treppe fehlt (8 TREPPE)"})
	result.append({"ok": true, "text": "Truhen: %d%s%s" % [chests.size(), "" if not chests.is_empty() else " (Spiel wählt selbst)", ", Mimiks: %d" % mimics.size() if not mimics.is_empty() else ""]})
	var solid := decor.keys().filter(func(cell: Vector2i) -> bool: return solid_at(cell)).size()
	var pieces := decor.size() + floor_styles.size() + carpets.size()
	result.append({"ok": true, "text": "Deko: Spiel schmückt selbst" if auto_decor and pieces == 0 else "Deko: %d Teile, %d im Weg" % [decor.size(), solid] + (" + Zufall" if auto_decor else "")})
	var problems := generator_problems(config, template)
	result.append({"ok": problems.is_empty(), "text": "Spiel akzeptiert den Raum" if problems.is_empty() else "Spiel: " + str(problems[0])})
	return result


## True when every check passes.
func ready_to_play(config: Dictionary) -> bool:
	return checks(config).all(func(check: Dictionary) -> bool: return bool(check.ok))


## Wall cells where the game can set a gate (two wall cells of a north wall
## with floor below), one per side as the generator would pick them.
func gate_cells(template: Dictionary = {}) -> Array:
	if template.is_empty(): template = to_template()
	if start == NONE or floor_cells.is_empty(): return []
	var config := {"tile_size": CELL, "generator_version": Dungeon.GENERATOR_VERSION, "world_size": template.world_size, "play_bounds": template.play_bounds}
	var layout := Dungeon._make_layout(template, config)
	layout.exits = []
	var cells: Array = []
	for side: String in SIDES:
		var gate := Dungeon._crypt_wall_door(side, 1, layout)
		if gate.is_empty(): continue
		var cell := Vector2i(int(gate.door_cell[0]), int(gate.door_cell[1]))
		if cells.has(cell): continue
		cells.append(cell)
		layout.exits.append(gate)
	return cells


func _connected() -> bool:
	if floor_cells.is_empty(): return false
	var first: Vector2i = start if floor_cells.has(start) else floor_cells.keys()[0]
	var seen := {first: true}
	var queue: Array[Vector2i] = [first]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if floor_cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == floor_cells.size()


## The generator's own complaints about this room (German or English text).
func generator_problems(config: Dictionary, template: Dictionary = {}) -> Array:
	if template.is_empty(): template = to_template()
	var single := config.duplicate()
	single.templates = [template]
	var label := str(template.get("id", ""))
	var problems: Array = []
	for error: String in Dungeon.validate_config(single):
		if error.contains(label): problems.append(_german(error.replace("Template %s " % label, "").replace(label + ": ", "")))
	return problems


## The generator's English messages the author can run into, in German.
const GERMAN := {
	"has a spawn without actor clearance": "Ein Startplatz steht zu dicht an Wand oder Möbeln",
	"has disconnected floor or unreachable spawns": "Große Gegner kommen nicht überall hin (Gänge 2 Felder breit, Möbel mit Abstand)",
	"reward_spawn is blocked": "Der Start ist versperrt",
	"stairs_spawn is blocked": "Die Treppe ist versperrt",
	"fire is inside a wall": "Eine Kerze steht in Wand oder Möbeln",
	"has invalid decor": "Die Deko-Daten sind beschädigt",
	"obstacles must be positive tile rectangles within play_bounds": "Hindernisse liegen außerhalb des Raums",
}


static func _german(text: String) -> String:
	return str(GERMAN.get(text, text))


# --- Snapshots --------------------------------------------------------------------

func _snapshot() -> Dictionary:
	return {"size": size, "floor": floor_cells.duplicate(), "start": start, "enemies": enemies.duplicate(), "chests": chests.duplicate(), "mimics": mimics.duplicate(),
		"torches": torches.duplicate(), "stairs": stairs, "room": room.duplicate(true), "from_recipe": from_recipe,
		"decor": decor.duplicate(true), "floor_styles": floor_styles.duplicate(true), "carpets": carpets.duplicate(true), "auto_decor": auto_decor}


func _restore(state: Dictionary) -> void:
	size = state.size
	floor_cells = state.floor
	start = state.start
	enemies.assign(state.enemies)
	chests.assign(state.chests)
	mimics.assign(state.mimics)
	torches.assign(state.torches)
	stairs = state.stairs
	room = state.room
	from_recipe = state.from_recipe
	decor = state.decor
	floor_styles = state.floor_styles
	carpets = state.carpets
	auto_decor = state.auto_decor
	dirty = true
	_gates_known = false

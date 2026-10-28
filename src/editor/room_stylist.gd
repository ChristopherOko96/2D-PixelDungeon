extends RefCounted
## Decor suggestion for the Dungeon-Werkstatt (button DEKORIEREN), rules and
## numbers in assets/data/dungeon_styling.json. The room is read as chambers
## (floor at least `chamber_depth` cells from a wall, plus its rim) and
## corridors (the rest). Then, chamber by chamber:
## - a carpet runner along the long axis, centred (the biggest chamber red);
## - columns in mirrored pairs along the long walls;
## - fires in the corners of big chambers;
## - the north wall in a symmetric rhythm: torch, banner, torch, the middle
##   stressed by a fountain or a banner pair;
## - crates, cabinets and skulls in corners; dead ends look abandoned;
## - corridors get torches at a steady interval and a few skulls and cracks.
## In a boss room the biggest chamber becomes a throne hall: a carpet from its
## entrance to the throne spot, column rows, fires beside the throne, a light
## shaft on it and the far wall dressed symmetrically.
## Every piece goes through RoomDoc.place_decor, so the editor's rules hold.

const Decor = preload("res://src/dungeon/decor_catalog.gd")
const DATA_PATH := "res://assets/data/dungeon_styling.json"
const NONE := Vector2i(-1, -1)
const AROUND := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const STEPS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func settings() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Decorates `doc` from scratch (its old decor goes; call begin_change first).
## Returns {chambers, carpets, pairs, pieces}.
static func style(doc: RefCounted, seed_value: int, data: Dictionary = {}) -> Dictionary:
	if data.is_empty(): data = settings()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	doc.clear_decor()
	doc.begin_batch()
	var map := analyse(doc.floor_cells, doc.start, int(data.get("chamber_depth", 2)))
	var chambers: Array = map.chambers
	var order: Array = range(chambers.size())
	order.sort_custom(func(a: int, b: int) -> bool: return int(chambers[a].area) > int(chambers[b].area))
	var report := {"chambers": chambers.size(), "carpets": 0, "pairs": 0, "pieces": 0}
	var throne_room: bool = doc.role() == "boss" and not order.is_empty()
	if throne_room: _throne(doc, chambers[order[0]], data, rng, report)
	var carpet: Dictionary = data.get("carpet", {})
	var carpets_left := int(carpet.get("max_chambers", 3)) - (1 if throne_room else 0)
	for rank in range(order.size()):
		var chamber: Dictionary = chambers[order[rank]]
		if throne_room and rank == 0: continue
		if bool(chamber.dead_end):
			_dead_end(doc, chamber, data.get("dead_end", {}), rng)
			continue
		if carpets_left > 0 and _carpet(doc, chamber, carpet, str(carpet.get("main" if rank == 0 else "other", "carpet_red")), report): carpets_left -= 1
		_columns(doc, chamber, data.get("columns", {}), report)
		_corner_fires(doc, chamber, data.get("corner_fires", {}), report)
		_north_wall(doc, chamber, data.get("north_wall", {}), rng, report)
		_clutter(doc, chamber, data.get("clutter", {}), rng)
	_corridors(doc, map, data.get("corridor", {}), rng)
	doc.end_batch()
	report.pieces = doc.decor.size() + doc.carpets.size() + doc.floor_styles.size()
	return report


# --- Reading the room ---------------------------------------------------------------

## Chambers and corridors of a floor: {chambers: [{rect, cells, area,
## thickness, horizontal, start, openings, dead_end}], corridor: cell -> true}.
static func analyse(floor_cells: Dictionary, start: Vector2i, depth_needed: int = 2) -> Dictionary:
	var ordered: Array = floor_cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	# Distance to the nearest wall (8 neighbours), counted from the rim inwards.
	var depth := {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in ordered:
		for offset: Vector2i in AROUND:
			if not floor_cells.has(cell + offset):
				depth[cell] = 1
				queue.append(cell)
				break
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for offset: Vector2i in AROUND:
			var next: Vector2i = cell + offset
			if floor_cells.has(next) and not depth.has(next):
				depth[next] = int(depth[cell]) + 1
				queue.append(next)
	# Open areas become chambers; their rim joins them. One-cell-wide open lines
	# (the middle of a 3-wide corridor) are corridor, so they do not merge chambers.
	var open := {}
	for cell: Vector2i in ordered:
		if int(depth.get(cell, 0)) >= depth_needed: open[cell] = true
	var core := {}
	for cell: Vector2i in open:
		if (open.has(cell + Vector2i.LEFT) or open.has(cell + Vector2i.RIGHT)) and (open.has(cell + Vector2i.UP) or open.has(cell + Vector2i.DOWN)): core[cell] = true
	var owner := {}
	var groups: Array = []
	for cell: Vector2i in ordered:
		if not core.has(cell) or owner.has(cell): continue
		var group := {cell: true}
		var stack: Array[Vector2i] = [cell]
		owner[cell] = groups.size()
		while not stack.is_empty():
			var at: Vector2i = stack.pop_back()
			for step: Vector2i in STEPS:
				var next: Vector2i = at + step
				if owner.has(next) or not core.has(next): continue
				owner[next] = groups.size()
				group[next] = true
				stack.append(next)
		groups.append(group)
	for index in range(groups.size()):
		for cell: Vector2i in groups[index].keys():
			for offset: Vector2i in AROUND:
				var next: Vector2i = cell + offset
				if floor_cells.has(next) and not owner.has(next):
					owner[next] = index
					groups[index][next] = true
	var corridor := {}
	for cell: Vector2i in ordered:
		if not owner.has(cell): corridor[cell] = true
	var chambers: Array = []
	for index in range(groups.size()):
		var cells: Dictionary = groups[index]
		var low := Vector2i(1 << 20, 1 << 20)
		var high := Vector2i(-1, -1)
		for cell: Vector2i in cells:
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		var rect := Rect2i(low, high - low + Vector2i.ONE)
		var openings := _openings(cells, corridor, owner, index)
		chambers.append({"rect": rect, "cells": cells, "area": cells.size(), "thickness": mini(rect.size.x, rect.size.y), "horizontal": rect.size.x >= rect.size.y,
			"start": cells.has(start), "openings": openings, "dead_end": openings <= 1 and not cells.has(start) and cells.size() < 60})
	return {"chambers": chambers, "corridor": corridor}


## How many separate ways lead out of a chamber (corridor groups or other
## chambers touching it).
static func _openings(cells: Dictionary, corridor: Dictionary, owner: Dictionary, index: int) -> int:
	var touching := {}
	var neighbours := {}
	for cell: Vector2i in cells:
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if corridor.has(next): touching[next] = true
			elif owner.has(next) and int(owner[next]) != index: neighbours[int(owner[next])] = true
	var groups := 0
	var seen := {}
	for cell: Vector2i in touching:
		if seen.has(cell): continue
		groups += 1
		var stack: Array[Vector2i] = [cell]
		seen[cell] = true
		while not stack.is_empty():
			var at: Vector2i = stack.pop_back()
			for offset: Vector2i in AROUND:
				var next: Vector2i = at + offset
				if touching.has(next) and not seen.has(next):
					seen[next] = true
					stack.append(next)
	return groups + neighbours.size()


# --- Placing ------------------------------------------------------------------------

static func _put(doc: RefCounted, id: String, cell: Vector2i, variant: int = 0) -> bool:
	return doc.place_decor(id, cell, variant).is_empty()


## A piece and its mirror image, both or neither (symmetry).
static func _pair(doc: RefCounted, id: String, a: Vector2i, b: Vector2i, variant: int = 0) -> bool:
	if a == b: return _put(doc, id, a, variant)
	if not doc.decor_problem(id, a).is_empty() or not doc.decor_problem(id, b).is_empty(): return false
	if not _put(doc, id, a, variant): return false
	if _put(doc, id, b, variant): return true
	doc.remove_decor(a)
	return false


## A runner along the chamber's long axis, centred, width matching the
## chamber's parity so it sits exactly in the middle.
static func _carpet(doc: RefCounted, chamber: Dictionary, spec: Dictionary, id: String, report: Dictionary) -> bool:
	if int(chamber.area) < int(spec.get("min_area", 30)) or int(chamber.thickness) < int(spec.get("min_thickness", 5)): return false
	var rect: Rect2i = chamber.rect
	var thick := int(chamber.thickness)
	var width := (1 if thick % 2 == 1 else 2) + (2 if thick >= int(spec.get("wide_from", 9)) else 0)
	var margin := int(spec.get("margin", 1))
	var a := Vector2i.ZERO
	var b := Vector2i.ZERO
	if bool(chamber.horizontal):
		var top := rect.position.y + (rect.size.y - width) / 2
		a = Vector2i(rect.position.x + margin, top)
		b = Vector2i(rect.end.x - 1 - margin, top + width - 1)
	else:
		var left := rect.position.x + (rect.size.x - width) / 2
		a = Vector2i(left, rect.position.y + margin)
		b = Vector2i(left + width - 1, rect.end.y - 1 - margin)
	var painted: int = doc.paint_area_rect(id, a, b, false)
	if painted > 0: report.carpets = int(report.carpets) + 1
	return painted > 0


## Evenly spaced positions from `first` to `last`, centred in that span.
static func _spaced(first: int, last: int, spacing: int) -> Array[int]:
	var result: Array[int] = []
	if last < first or spacing <= 0: return result
	var count := (last - first) / spacing + 1
	var shift := (last - first - (count - 1) * spacing) / 2
	for index in range(count): result.append(first + shift + index * spacing)
	return result


## Columns in mirrored pairs along both long walls.
static func _columns(doc: RefCounted, chamber: Dictionary, spec: Dictionary, report: Dictionary) -> void:
	if int(chamber.thickness) < int(spec.get("min_thickness", 8)): return
	var rect: Rect2i = chamber.rect
	var inset := int(spec.get("inset", 2))
	var from_end := int(spec.get("from_end", 2))
	var id := str(spec.get("id", "column"))
	if bool(chamber.horizontal):
		for x: int in _spaced(rect.position.x + from_end, rect.end.x - 1 - from_end, int(spec.get("spacing", 4))):
			if _pair(doc, id, Vector2i(x, rect.position.y + inset), Vector2i(x, rect.end.y - 1 - inset)): report.pairs = int(report.pairs) + 1
	else:
		for y: int in _spaced(rect.position.y + from_end, rect.end.y - 1 - from_end, int(spec.get("spacing", 4))):
			if _pair(doc, id, Vector2i(rect.position.x + inset, y), Vector2i(rect.end.x - 1 - inset, y)): report.pairs = int(report.pairs) + 1


## Fires in the four corners of a big chamber (mirrored both ways).
static func _corner_fires(doc: RefCounted, chamber: Dictionary, spec: Dictionary, report: Dictionary) -> void:
	if int(chamber.area) < int(spec.get("min_area", 70)): return
	var rect: Rect2i = chamber.rect
	var inset := int(spec.get("inset", 1))
	var left := rect.position.x + inset
	var right := rect.end.x - 1 - inset
	for y: int in [rect.position.y + inset, rect.end.y - 1 - inset]:
		if _pair(doc, str(spec.get("id", "fire")), Vector2i(left, y), Vector2i(right, y)): report.pairs = int(report.pairs) + 1


## The north wall above a chamber: the middle stressed (a fountain on an odd
## wall, a banner pair on an even one), then outwards torch, banner, torch...
static func _north_wall(doc: RefCounted, chamber: Dictionary, spec: Dictionary, rng: RandomNumberGenerator, report: Dictionary) -> void:
	var rect: Rect2i = chamber.rect
	var row := rect.position.y - 1
	var left := rect.position.x
	var right := rect.end.x - 1
	var faces := 0
	for x in range(left, right + 1):
		if Decor.wall_spot(doc.floor_cells, Vector2i(x, row)) and chamber.cells.has(Vector2i(x, row + 1)): faces += 1
	if faces < 3: return
	var banner := str(spec.get("banner", "banner"))
	var torch := str(spec.get("torch", "wall_torch"))
	var colour := rng.randi_range(0, Decor.variants(banner) - 1)
	var every := maxi(2, int(spec.get("torch_every", 4)))
	var middle := (left + right) / 2
	var odd := (left + right) % 2 == 0
	if rect.size.x >= int(spec.get("centre_min_width", 9)):
		if odd:
			if not _put(doc, str(spec.get("centre", "fountain_lava")), Vector2i(middle, row)): _put(doc, banner, Vector2i(middle, row), colour)
		else: _pair(doc, banner, Vector2i(middle, row), Vector2i(middle + 1, row), colour)
	for x in range(middle - 1, left - 1, -1):
		var distance := middle - x
		var mirror := left + right - x
		if distance % every == every / 2:
			if _pair(doc, torch, Vector2i(x, row), Vector2i(mirror, row)): report.pairs = int(report.pairs) + 1
		elif distance % every == 0:
			if _pair(doc, banner, Vector2i(x, row), Vector2i(mirror, row), colour): report.pairs = int(report.pairs) + 1


## Crates and cabinets in some corners, a few skulls (asymmetry where nobody walks).
static func _clutter(doc: RefCounted, chamber: Dictionary, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var rect: Rect2i = chamber.rect
	var props: Array = spec.get("corner_props", ["crate"])
	for corner: Vector2i in [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]:
		if rng.randf() < float(spec.get("corner_chance", 0.45)): _put(doc, str(props[rng.randi_range(0, props.size() - 1)]), corner)
	var chance := float(spec.get("skull_chance", 0.015))
	var cells: Array = chamber.cells.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		if doc.carpets.has(cell): continue
		if rng.randf() < chance: _put(doc, "skull", cell, rng.randi_range(0, 1))


## A dead end looks old: cracked and mossy floor, crates in corners, skulls.
static func _dead_end(doc: RefCounted, chamber: Dictionary, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var floors: Array = spec.get("floors", ["floor_cracks"])
	var cells: Array = chamber.cells.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		if rng.randf() < float(spec.get("floor_share", 0.45)): doc.paint_area(str(floors[rng.randi_range(0, floors.size() - 1)]), cell, 0, false, 0, true, rng)
	var rect: Rect2i = chamber.rect
	var props: Array = spec.get("props", ["crate"])
	var corners: Array = [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]
	for index in range(2):
		_put(doc, str(props[rng.randi_range(0, props.size() - 1)]), corners[rng.randi_range(0, corners.size() - 1)])
	var skulls: Array = spec.get("skulls", [1, 3])
	for index in range(rng.randi_range(int(skulls[0]), int(skulls[1]))):
		_put(doc, "skull", cells[rng.randi_range(0, cells.size() - 1)], rng.randi_range(0, 1))


## Corridors: a torch on the north wall every few cells, a few skulls and cracks.
static func _corridors(doc: RefCounted, map: Dictionary, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var corridor: Dictionary = map.corridor
	var faces: Array = []
	for cell: Vector2i in corridor:
		if Decor.wall_spot(doc.floor_cells, cell + Vector2i.UP): faces.append(cell + Vector2i.UP)
	faces.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var every := maxi(2, int(spec.get("torch_every", 5)))
	var run_start := NONE
	var previous := NONE
	for face: Vector2i in faces:
		if previous == NONE or face.y != previous.y or face.x != previous.x + 1: run_start = face
		previous = face
		if (face.x - run_start.x) % every == every / 2: _put(doc, str(spec.get("torch", "wall_torch")), face)
	var ordered: Array = corridor.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in ordered:
		var roll := rng.randf()
		if roll < float(spec.get("skull_chance", 0.06)): _put(doc, "skull", cell, rng.randi_range(0, 1))
		elif roll < float(spec.get("skull_chance", 0.06)) + float(spec.get("crack_chance", 0.12)): doc.paint_area("floor_cracks", cell, 0, false, 0, true, rng)


# --- Throne hall --------------------------------------------------------------------

## The throne hall: seen from its entrance, a carpet runs along the middle to
## the throne spot near the far wall; column rows flank it; fires stand beside
## the throne and a light shaft falls on it; the far wall is dressed symmetrically.
static func _throne(doc: RefCounted, hall: Dictionary, data: Dictionary, rng: RandomNumberGenerator, report: Dictionary) -> void:
	var spec: Dictionary = data.get("throne", {})
	var frame := _frame(doc, hall)
	var length := int(frame.length)
	var half := int(frame.half)
	var even: bool = frame.even
	var throne_at := length - 1 - int(spec.get("throne_from_wall", 3))
	if throne_at < 3: return
	var cell := func(along: int, across: int) -> Vector2i: return Vector2i(frame.origin) + Vector2i(frame.along) * along + Vector2i(frame.across) * across
	var mirror := func(across: int) -> int: return 1 - across if even else -across
	# The carpet from the entrance to the throne (3 wide, 2 on an even hall).
	var low := 0 if even else -1
	var high := 1
	doc.paint_area_rect(str(spec.get("carpet", "carpet_red")), cell.call(0, low), cell.call(throne_at, high), false)
	report.carpets = int(report.carpets) + 1
	# Column rows: an inner pair beside the carpet when there is room, an outer pair near the walls.
	var rows: Array[int] = [half - 2]
	if half - 2 - (high + 3) >= 3: rows.append(high + 3)
	for along: int in _spaced(2, throne_at - 1, int(spec.get("column_spacing", 3))):
		for across: int in rows:
			if _pair(doc, str(spec.get("column", "column")), cell.call(along, across), cell.call(along, mirror.call(across))): report.pairs = int(report.pairs) + 1
	# Fires beside the throne, the light shaft on it.
	var beside := int(spec.get("fires_beside", 3))
	_pair(doc, str(spec.get("fire", "fire")), cell.call(throne_at, beside), cell.call(throne_at, mirror.call(beside)))
	_put(doc, str(spec.get("shaft", "light_shaft")), cell.call(throne_at, 0))
	# The far wall (wall pieces hang only on north walls).
	if Vector2i(frame.along) == Vector2i.UP:
		var wall: Dictionary = {"banner": str(spec.get("banner", "banner")), "torch": str(spec.get("torch", "wall_torch")), "centre": str(spec.get("centre", "fountain_lava")), "torch_every": 4, "centre_min_width": 3}
		_north_wall(doc, hall, wall, rng, report)
	else:
		_north_wall(doc, hall, data.get("north_wall", {}), rng, report)
	_corner_fires(doc, hall, data.get("corner_fires", {}), report)


## The hall seen from its entrance: origin (entrance end, on the middle
## line), unit steps `along` (towards the far end) and `across`, the length
## along, the half width across and whether the width is even.
static func _frame(doc: RefCounted, hall: Dictionary) -> Dictionary:
	var rect: Rect2i = hall.rect
	var entry := _entrance(doc, hall)
	var centre := Vector2(rect.position) + Vector2(rect.size - Vector2i.ONE) * 0.5
	var away := centre - Vector2(entry)
	var along := Vector2i.UP
	if absf(away.x) > absf(away.y): along = Vector2i.RIGHT if away.x > 0.0 else Vector2i.LEFT
	else: along = Vector2i.DOWN if away.y > 0.0 else Vector2i.UP
	var vertical := along.x == 0
	var across := Vector2i.RIGHT if vertical else Vector2i.DOWN
	var middle := (rect.position.x + (rect.size.x - 1) / 2) if vertical else (rect.position.y + (rect.size.y - 1) / 2)
	var origin := Vector2i.ZERO
	match along:
		Vector2i.UP: origin = Vector2i(middle, rect.end.y - 1)
		Vector2i.DOWN: origin = Vector2i(middle, rect.position.y)
		Vector2i.RIGHT: origin = Vector2i(rect.position.x, middle)
		_: origin = Vector2i(rect.end.x - 1, middle)
	# Measured on the floor itself: niches halfway up do not widen the hall.
	var cells: Dictionary = hall.cells
	var length := 0
	while cells.has(origin + along * length): length += 1
	var probe := origin + along * mini(2, maxi(0, length - 1))
	var plus := 0
	while cells.has(probe + across * (plus + 1)): plus += 1
	var minus := 0
	while cells.has(probe - across * (minus + 1)): minus += 1
	var width := plus + minus + 1
	return {"origin": origin, "along": along, "across": across, "length": length, "half": width / 2, "even": width % 2 == 0}


## Where the way from the start first reaches the hall (the start itself
## when it lies in the hall).
static func _entrance(doc: RefCounted, hall: Dictionary) -> Vector2i:
	var cells: Dictionary = hall.cells
	var start: Vector2i = doc.start
	if start == NONE or not doc.floor_cells.has(start): return Vector2i(Rect2i(hall.rect).get_center().x, Rect2i(hall.rect).end.y - 1)
	if cells.has(start): return start
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		for step: Vector2i in STEPS:
			var next: Vector2i = at + step
			if seen.has(next) or not doc.floor_cells.has(next): continue
			if cells.has(next): return next
			seen[next] = true
			queue.append(next)
	return Vector2i(Rect2i(hall.rect).get_center().x, Rect2i(hall.rect).end.y - 1)

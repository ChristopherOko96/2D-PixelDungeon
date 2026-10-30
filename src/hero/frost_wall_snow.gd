extends RefCounted
## The snow at the walls of a snowy world (theme "snow", the Frostgruft; src/hero/frost_snow.gd
## owns it): every wall that rises out of a snow field stands in the snow
## (production/epics/main-port/story-012-snow-wall-integration.md).
##
## Each contact edge between a snow floor cell and a wall gets a contact seam (a narrow blue-grey
## shade at the wall's foot) and a snow lip banked against the wall, covering its lowest pixels.
## The pieces (assets/sprites/frost*/snow_wall_*, drawn by tools/frost_dungeon/wall_snow.py, their
## anchors and counts in assets/data/frost_wall_snow.json) each cover half a cell edge; they join
## at every half boundary with a join (0 a break, 1 a mound, 2 a big mound) picked from the boundary's world
## position, so the halves meeting there agree and long walls never show one sprite repeated.
##
## contacts() reads the cell grid once per floor (and again when a secret wall opens or a fire
## bowl thaws its snow): it classifies every contact edge by its neighbours, the four direct ones
## and the diagonals for the corners: "run" (the lip goes on along the wall), "inner" (an inner
## corner, the lip turns along the other wall), "outer" (the wall's corner, the lip wraps round it)
## or "end" (a doorway, the stairs door, ice, thaw: the lip runs out). place() turns the contacts
## into pieces, kept per drawing chunk; draw() only draws them. Doorways (no snow) and the abyss
## side of every wall never get snow: only snow cells have contacts, and a lip lies on its cell's
## side of the wall.
## Presentation only: no collision, no navigation, nothing in the game state or the save.

const DATA_PATH := "res://assets/data/frost_wall_snow.json"
## theme "wall_snow" keys of the same name override these: seam = strength of the contact seams
## (0..1, their alpha), lip = strength of the lips (0..1), breaks = share of half boundaries where
## the lip dips to a break and the seam shows (side_breaks the same at side walls, where the snow
## lies in loose mounds rather than a band), sink = px the north lips sit further up the wall
## face, scale = whole-number size of the pieces (1 = as drawn), seed = added to the floor's seed
## for another arrangement, south = lips at the back of front walls too.
const DEFAULTS := {"seam": 1.0, "lip": 1.0, "breaks": 0.38, "side_breaks": 0.6, "sink": 0.0, "scale": 1, "seed": 0, "south": true}
## Wall decor whose foot stays free of snow (the stairs door in a north wall); wide decor hanging
## well past the wall's foot (banners) keeps it free too, so it hangs in front of the snow (narrow
## things, a torch's ring, may stand in the lip).
const KEEP_FREE := ["door_stairs"]

var g: Node
var cfg: Dictionary = DEFAULTS.duplicate(true)
var data: Dictionary = {}
## Pieces per drawing chunk: Vector2i chunk -> {"ao": [[name, origin]], "lip": [...], "front": [...]}.
var chunks: Dictionary = {}
## The floor's contact edges (contacts()), kept for the tests and the debug views.
var edges: Array = []


func _init(game: Node, theme_block: Dictionary) -> void:
	g = game
	for k: String in theme_block:
		if DEFAULTS.has(k):
			cfg[k] = theme_block[k]
	if FileAccess.file_exists(DATA_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## Builds the cache for the current floor from its grid and snow cells (snow: index -> true).
func build(snow: Dictionary) -> void:
	var W: Dictionary = g.W
	var sizes := {}
	for w: Dictionary in W.get("wall_decor", []):
		var t: Texture2D = g.tex.get(w.name)
		if t != null:
			sizes[w.name] = t.get_size()
	var blocked := blocked_north(W, g.C, KEEP_FREE, sizes)
	edges = contacts(W.grid, int(W.cols), int(W.rows), snow, blocked, door_cells(W))
	chunks = {}
	if data.is_empty():
		return
	var seed := floor_seed(W) + int(cfg.seed)
	for e: Dictionary in edges:
		for p: Array in place(e, float(g.C), seed):
			if p[0] == "front" and not bool(cfg.south):
				continue
			var key := Vector2i(int(e.x) / g.CHUNK.x, int(e.y) / g.CHUNK.y)
			if not chunks.has(key):
				chunks[key] = {"ao": [], "lip": [], "front": []}
			chunks[key][p[0]].append([p[1], p[2]])


## The floor's own number for the arrangement: the same floor (its number and its generated name)
## always gets the same snow.
static func floor_seed(W: Dictionary) -> int:
	return int(W.get("n", 0)) * 7919 + (str(W.get("title", "")).hash() & 0xFFFFF)


## The doorway cells (index) of the floor's doors.
static func door_cells(W: Dictionary) -> Dictionary:
	var out := {}
	var cols := int(W.cols)
	for d: Dictionary in W.get("doors", []):
		for c: Variant in d.get("cells", []):
			var v := Vector2i(c) if c is Vector2i else Vector2i(int(c[0]), int(c[1]))
			out[v.y * cols + v.x] = true
	return out


## The cells (index) whose north wall carries decor that keeps its foot free: the named decor
## (the stairs door) and any decor wider than 56 px reaching more than 24 px below the wall's
## foot: the cells under
## the decor's width, in the floor row at the wall's foot. sizes: px per decor name (without one a
## decor counts 1.5 cells wide and not hanging).
static func blocked_north(W: Dictionary, cell: float, names: Array, sizes: Dictionary = {}) -> Dictionary:
	var out := {}
	var cols := int(W.cols)
	for w: Dictionary in W.get("wall_decor", []):
		var y := int(round((float(w.y) + 74.0) / cell))
		var size: Vector2 = sizes.get(w.name, Vector2(cell * 1.5, 0.0))
		var hangs := size.x > 56.0 and float(w.y) + size.y > y * cell + 24.0
		if not (str(w.name) in names) and not hangs:
			continue
		var half := size.x / 2.0 + 6.0
		for x in range(int(floor((float(w.x) - half) / cell)), int(floor((float(w.x) + half) / cell)) + 1):
			if x >= 0 and x < cols:
				out[y * cols + x] = true
	return out


## Every contact edge between a snow cell and a wall: {"side": "n" (wall above) / "w" (left) /
## "e" (right) / "s" (below), "x", "y" (the snow cell), "a", "b" (the edge's caps at its start and
## end: left/right for n and s, top/bottom for w and e: "run", "inner", "outer", "end")}.
## grid: 0 wall or void, 1 floor, 2 ice, 3 other liquid; snow: index -> true for snow cells;
## blocked: indices whose north wall keeps its foot free; doors: doorway cells. A snow cell next to
## a doorway (its eight neighbours) stands in the door's frame: its side walls get no lip and its
## north lip runs out instead of piling into the corner, so the jambs and the opening stay clear.
static func contacts(grid: PackedByteArray, cols: int, rows: int, snow: Dictionary, blocked: Dictionary, doors: Dictionary = {}) -> Array:
	var wall := func(x: int, y: int) -> bool: return x < 0 or y < 0 or x >= cols or y >= rows or grid[y * cols + x] == 0
	var on := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < cols and y < rows and snow.has(y * cols + x)
	# a snow cell with a north lip (a wall above, its foot not kept free)
	var north := func(x: int, y: int) -> bool: return on.call(x, y) and wall.call(x, y - 1) and not blocked.has(y * cols + x)
	var framed := func(x: int, y: int) -> bool:
		for k in range(9):
			var nx := x + k % 3 - 1
			var ny := y + k / 3 - 1
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows and doors.has(ny * cols + nx):
				return true
		return false
	var out: Array = []
	for i: int in snow:
		var x := i % cols
		var y := i / cols
		var in_frame: bool = framed.call(x, y)
		if north.call(x, y):
			var caps := [_cap_h(wall, on, north, x, y, -1, -1), _cap_h(wall, on, north, x, y, 1, -1)]
			if in_frame:
				caps = caps.map(func(c: String) -> String: return "end" if c == "inner" else c)
			out.append({"side": "n", "x": x, "y": y, "a": caps[0], "b": caps[1]})
		if wall.call(x, y + 1):
			out.append({"side": "s", "x": x, "y": y, "a": _cap_h(wall, on, Callable(), x, y, -1, 1), "b": _cap_h(wall, on, Callable(), x, y, 1, 1)})
		for dx: int in [-1, 1]:
			if wall.call(x + dx, y) and not in_frame:
				out.append({"side": "w" if dx < 0 else "e", "x": x, "y": y, "a": _cap_v(wall, on, north, x, y, dx, -1), "b": _cap_v(wall, on, north, x, y, dx, 1)})
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return [p.y, p.x, p.side] < [q.y, q.x, q.side])
	return out


## The cap of a north (dy -1) or south (dy 1) edge towards dx.
static func _cap_h(wall: Callable, on: Callable, north: Callable, x: int, y: int, dx: int, dy: int) -> String:
	var nx := x + dx
	if wall.call(nx, y):
		return "inner" if dy < 0 else "end"
	if dy < 0:
		if north.call(nx, y):
			return "run"
		if on.call(nx, y) and on.call(nx, y - 1):
			return "outer"
		return "end"
	return "run" if on.call(nx, y) and wall.call(nx, y + 1) else "end"


## The cap of a side edge (wall towards dx) at its top (dy -1) or bottom (dy 1).
static func _cap_v(wall: Callable, on: Callable, north: Callable, x: int, y: int, dx: int, dy: int) -> String:
	var ny := y + dy
	if wall.call(x, ny):
		# an inner corner with a north wall: the corner piece carries the lip; with a front wall it runs out
		return "inner" if dy < 0 and north.call(x, y) else "end"
	if on.call(x, ny) and wall.call(x + dx, ny):
		return "run"
	# the wall's corner below: the north lip of the cell beside the corner wraps round it
	if dy > 0 and on.call(x, ny) and north.call(x + dx, ny):
		return "outer"
	return "end"


## The pieces of one contact edge: [layer ("ao", "lip", "front"), sprite name, origin (world px)].
func place(e: Dictionary, C: float, seed: int) -> Array:
	var out: Array = []
	var x := int(e.x)
	var y := int(e.y)
	var half := C / 2.0
	var special: bool = e.a != "run" or e.b != "run"
	match str(e.side):
		"n":
			var o := Vector2(x * C, y * C - float(cfg.sink))
			var j := [join(Vector2(x * C, y * C), "h", seed), 1 if special else join(Vector2(x * C + half, y * C), "h", seed), join(Vector2((x + 1) * C, y * C), "h", seed)]
			for h in [0, 1]:
				var cap: String = e.a if h == 0 else e.b
				var at := o + Vector2(h * half, 0)
				var lr := "l" if h == 0 else "r"
				match cap:
					"run": out.append(["lip", "snow_wall_lip_h_%d%d_%d" % [j[h], j[h + 1], variant(at, "lip_h", seed)], at])
					"end": out.append(["lip", "snow_wall_lip_h_end_" + lr, at])
					"inner": out.append(["lip", "snow_wall_corner_inner_" + lr, o + Vector2(h * C, 0)])
					"outer": out.append(["lip", "snow_wall_corner_outer_" + lr, o + Vector2(h * C, 0)])
				var seam := "snow_wall_ao_h_end_" + lr if cap == "end" else "snow_wall_ao_h_%02d" % (variant(at, "ao_h", seed) % _count("seams", "ao_h"))
				out.append(["ao", seam, Vector2(x * C + h * half, y * C)])
		"w", "e":
			var kind := "left" if e.side == "w" else "right"
			var ex := x * C if e.side == "w" else (x + 1) * C
			# side lips meet their end and corner pieces with a break (loose mounds, no closed white edge)
			var j := [join(Vector2(ex, y * C), kind, seed), 0 if special else join(Vector2(ex, y * C + half), kind, seed), join(Vector2(ex, (y + 1) * C), kind, seed)]
			for h in [0, 1]:
				var cap: String = e.a if h == 0 else e.b
				var at := Vector2(ex, y * C + h * half)
				var tb := "t" if h == 0 else "b"
				if cap == "run":
					out.append(["lip", "snow_wall_lip_%s_%d%d_%d" % [kind, j[h], j[h + 1], variant(at, "lip_" + kind, seed)], at])
				elif cap == "end" or (cap == "inner" and h == 1) or (cap == "outer" and h == 0):
					out.append(["lip", "snow_wall_lip_%s_end_%s" % [kind, tb], at])
				# inner at the top and outer at the bottom: the north edge's corner piece carries the lip
				if cap != "end":
					out.append(["ao", "snow_wall_ao_%s_%02d" % [kind, variant(at, "ao_" + kind, seed) % _count("seams", "ao_" + kind)], at])
		"s":
			var j := [join(Vector2(x * C, (y + 1) * C), "s", seed), 1 if special else join(Vector2(x * C + half, (y + 1) * C), "s", seed), join(Vector2((x + 1) * C, (y + 1) * C), "s", seed)]
			for h in [0, 1]:
				var cap: String = e.a if h == 0 else e.b
				var at := Vector2(x * C + h * half, (y + 1) * C)
				if cap == "run":
					out.append(["front", "snow_wall_lip_s_%d%d_%d" % [j[h], j[h + 1], variant(at, "lip_s", seed)], at])
				else:
					out.append(["front", "snow_wall_lip_s_end_" + ("l" if h == 0 else "r"), at])
	return out


## The join at a half boundary (world px) of a wall kind: 0 a break, 1 a mound (share cfg.breaks breaks).
func join(at: Vector2, kind: String, seed: int) -> int:
	var share := float(cfg.side_breaks) if kind == "left" or kind == "right" else float(cfg.breaks)
	if _hash(at, kind, seed) < share:
		return 0
	# a mound: of the kind's mound joins (north walls: middle and big) one picked from the same spot
	var n := int(data.get("joins", {}).get(kind, 2))
	return 1 + int(_hash(at, kind + "^", seed) * 9973.0) % maxi(1, n - 1)


## Which run piece of a kind lies at a half's origin.
func variant(at: Vector2, kind: String, seed: int) -> int:
	var n := _count("per_join", kind) if data.get("per_join", {}).has(kind) else 4
	return int(_hash(at, kind + "#", seed) * 9973.0) % maxi(1, n)


func _count(group: String, kind: String) -> int:
	return maxi(1, int(data.get(group, {}).get(kind, 1)))


static func _hash(at: Vector2, kind: String, seed: int) -> float:
	var v := int(at.x) * 374761393 + int(at.y) * 668265263 + (kind.hash() & 0xFFFF) * 2246822519 + seed * 3266489917
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xFFFF) / 65535.0


## Draws one chunk's pieces of a layer: "ao" (the seams, over the walls, under the lips), "lip"
## (the lips, under the actors) or "front" (the lips at the back of front walls, over them).
func draw(l: CanvasItem, area: Rect2, layer: String) -> void:
	var key := Vector2i(int(round(area.position.x / g.C)) / g.CHUNK.x, int(round(area.position.y / g.C)) / g.CHUNK.y)
	var bucket: Dictionary = chunks.get(key, {})
	var tint := Color(1, 1, 1, float(cfg.seam) if layer == "ao" else float(cfg.lip))
	var sc := maxi(1, int(cfg.scale))
	var anchors: Dictionary = data.get("anchors", {})
	for p: Array in bucket.get(layer, []):
		var t: Texture2D = g.tex.get(p[0])
		if t == null:
			continue
		var an: Array = anchors.get(p[0], [0, 0])
		var o: Vector2 = p[1]
		l.draw_texture_rect(t, Rect2(o - Vector2(an[0], an[1]) * sc, t.get_size() * sc), false, tint)

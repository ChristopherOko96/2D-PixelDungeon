extends RefCounted
## Ready rooms to start from: the world generator builds a floor and one of its rooms (a key chamber,
## a boss room ...) is cut out as an editable Weltbauer room, with its floor, pieces and traps.

const Data = preload("res://src/world_editor/world_room_data.gd")
const WorldPack = preload("res://src/world_kit/world_pack.gd")
const Art = preload("res://src/world_editor/world_art.gd")
const C := 96.0
const RUNS := [4242, 1717, 90210]
const SIMPLE_ENTS := ["plate", "lever", "brazier", "spikes", "vent", "key", "heart", "gem", "well", "portal", "chest"]


## A room of generator kind `gtype` in `world`, {} when no floor tried has one. `title` names it.
static func make(world: String, gtype: String, title: String) -> Dictionary:
	var info: Dictionary = Data.WORLDS[world]
	var theme: Dictionary = Art.load_theme(world)
	var pack := WorldPack.new(str(info.pack), str(theme.get("world_sizes", str(theme.get("sprites", "")) + "manifest.json")))
	for run: int in RUNS:
		for n in range(1, pack.floor_count() + 1):
			var raw: Dictionary = pack.build_generated(n, run)
			for r: Dictionary in raw.get("rooms", []):
				if str(r.get("gtype", "")) == gtype or str(r.get("type", "")) == gtype:
					return from_floor(raw, int(r.index), world, title)
	return {}


## Cuts room `index` out of a floor in the generator's raw form.
static func from_floor(raw: Dictionary, index: int, world: String, title: String) -> Dictionary:
	var cols := int(raw.cols)
	var rows := int(raw.rows)
	var at: Array = raw.room_at
	var lo := Vector2i(cols, rows)
	var hi := Vector2i(-1, -1)
	for i in range(at.size()):
		if int(at[i]) == index:
			lo = lo.min(Vector2i(i % cols, i / cols))
			hi = hi.max(Vector2i(i % cols, i / cols))
	lo -= Vector2i.ONE
	hi += Vector2i.ONE
	var size := hi - lo + Vector2i.ONE
	var room := Data.fresh(world, title, size.clamp(Data.MIN_SIZE, Data.MAX_SIZE))
	var grid := str(raw.grid)
	var hole_kinds := {}
	for e: Dictionary in raw.ents:
		if str(e.get("type", "")) == "pit":
			hole_kinds[int(floor(float(e.y) / C)) * cols + int(floor(float(e.x) / C))] = true
	var cell_rows: Array = []
	for y in range(int(room.height)):
		var row := ""
		for x in range(int(room.width)):
			var i := (y + lo.y) * cols + x + lo.x
			var inside: bool = x + lo.x < cols and y + lo.y < rows and int(at[i]) == index
			row += (Data.PIT if hole_kinds.has(i) else grid[i]) if inside else Data.WALL
		cell_rows.append(row)
	room.cells = cell_rows
	var origin := Vector2(lo) * C
	var objects: Array = []
	var in_room := func(x: float, y: float) -> bool:
		var cx := int(floor(x / C))
		var cy := int(floor(y / C))
		return cx >= 0 and cy >= 0 and cx < cols and cy < rows and int(at[cy * cols + cx]) == index
	for p: Dictionary in raw.props:
		if str(p.get("name", "")) == "" or not in_room.call(float(p.x), float(p.y) - 8.0):
			continue
		var o := {"kind": "prop", "asset": str(p.name), "x": float(p.x) - origin.x, "y": float(p.y) - origin.y, "flip": bool(p.get("flip", false)),
			"layer": "floor" if bool(p.get("low", false)) else "normal", "block": p.get("solid") != null, "scale": 1.0, "foot": [60, 30]}
		if p.get("solid") != null:
			o.foot = [float(p.solid[2]) - float(p.solid[0]), float(p.solid[3]) - float(p.solid[1])]
		objects.append(o)
	for d: Dictionary in raw.decals:
		if str(d.name) == "pit" or not in_room.call(float(d.x), float(d.y)):
			continue
		var t: Texture2D = _sized(str(d.name), str(world))
		var half := (t.get_height() * 0.5) if t != null else 24.0
		objects.append({"kind": "prop", "asset": str(d.name), "x": float(d.x) - origin.x, "y": float(d.y) + half - origin.y, "flip": false, "layer": "floor", "block": false, "scale": 1.0, "foot": [60, 30],
			"decal": {"dy": half, "w": float(d.get("w", 0)), "h": float(d.get("h", 0)), "a": float(d.get("a", 1.0))}})
	for w: Dictionary in raw.wall_decor:
		var foot_y := float(w.y) + 74.0
		if not in_room.call(float(w.x), foot_y + 10.0):
			continue
		objects.append({"kind": "prop", "asset": str(w.name), "x": float(w.x) - origin.x, "y": foot_y - origin.y, "flip": bool(w.get("flip", false)), "layer": "floor", "block": false, "scale": 1.0, "foot": [60, 30], "wall_decor": true})
	for e: Dictionary in raw.ents:
		if int(e.get("room", -1)) != index or str(e.type) == "pit":
			continue
		objects.append(_object_of(e, origin))
	var start := Vector2(float(room.width), float(room.height)) * C * 0.5
	var spawn: Variant = null
	for r: Dictionary in raw.rooms:
		if int(r.index) == index:
			spawn = r.get("spawn")
			room.auto_mobs = int(r.get("mobs", 0))
			room.role = _role_of(str(r.get("gtype", "")))
			if spawn is Array:
				start = (Vector2(float(r.bx), float(r.by)) + Vector2(float(spawn[0]), float(spawn[1]))) * C - origin
	objects.append({"kind": "start", "x": start.x, "y": start.y})
	room.objects = objects
	room.ports = _ports(raw, index, lo)
	var lights: Array = []
	for l: Dictionary in raw.lights:
		if in_room.call(float(l.x), float(l.y) + 60.0):
			lights.append({"x": float(l.x) - origin.x, "y": float(l.y) - origin.y, "r": l.r, "c": l.c})
	room.lights = lights
	_clear_start(room)
	return room


static func _sized(name: String, world: String) -> Texture2D:
	var theme: Dictionary = Art.load_theme(world)
	var path := str(theme.get("sprites", "")) + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


static func _role_of(gtype: String) -> String:
	match gtype:
		"key": return "key"
		"boss": return "boss"
		"portal": return "portal"
		"start": return "start"
		"vault", "pvault", "treasure", "shrine": return "treasure"
		"hidden": return "secret"
	return "combat"


## A piece of the generator as a Weltbauer object; what has no own part stays as it was ("raw").
static func _object_of(e: Dictionary, origin: Vector2) -> Dictionary:
	var kind := str(e.type)
	var x := float(e.x) - origin.x
	var y := float(e.y) - origin.y
	if kind not in SIMPLE_ENTS:
		var raw_copy: Dictionary = e.duplicate(true)
		raw_copy.erase("door")
		return {"kind": "raw", "x": x, "y": y, "ent": raw_copy}
	var o := {"kind": kind, "x": x, "y": y}
	match kind:
		"plate":
			o.group = str(e.get("group", "A"))
			o.order = int(e.get("order", 0))
		"lever", "brazier":
			o.group = str(e.get("group", "A"))
		"spikes":
			o.phase = int(e.get("phase", 0))
		"vent":
			o.offset = float(e.get("offset", 0.0))
		"key":
			o.key = str(e.get("key", "A"))
		"chest":
			var loot: Dictionary = e.get("loot", {})
			if loot.has("key"):
				o.loot = {"type": "key", "id": str(loot.key)}
			elif bool(loot.get("heart", false)):
				o.loot = {"type": "heart"}
			else:
				o.loot = {"type": "gold", "amount": int(loot.get("gems", 6))}
	return o


## The room's doors in the floor become its door spots, for joining rooms later.
static func _ports(raw: Dictionary, index: int, lo: Vector2i) -> Array:
	var out: Array = []
	for d: Dictionary in raw.doors:
		if int(d.a) != index and int(d.b) != index:
			continue
		var c: Array = d.cells[0]
		var cell := Vector2i(int(c[0]) - lo.x, int(c[1]) - lo.y)
		var side := "north"
		if str(d.get("dir", "v")) == "h":
			side = "east" if cell.x > 1 else "west"
		elif cell.y > 1:
			side = "south"
		out.append({"side": side, "cell": [cell.x, cell.y], "dir": str(d.get("dir", "v"))})
	return out


## The hero must stand on floor even when the generator's spot lies on a piece.
static func _clear_start(room: Dictionary) -> void:
	for o: Dictionary in room.objects:
		if str(o.kind) != "start":
			continue
		var c := Vector2i(int(float(o.x) / C), int((float(o.y) - 6.0) / C))
		if Data.cell_at(room, c.x, c.y) in [Data.FLOOR, Data.BRIDGE]:
			return
		for y in range(int(room.height)):
			for x in range(int(room.width)):
				if Data.cell_at(room, x, y) == Data.FLOOR:
					o.x = (x + 0.5) * C
					o.y = (y + 0.7) * C
					return

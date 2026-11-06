extends RefCounted
## Turns one Weltbauer room into the floor data the story game plays (the raw schema of
## hell_floor_data.gd), so the real heroes, monsters, walls and effects run in it. hell_game.gd uses
## it in place of the world generator: floor_count, build_raw, error_message like WorldPack.

const Data = preload("res://src/world_editor/world_room_data.gd")
const Terrain = preload("res://src/world_editor/world_terrain.gd")
const WorldPack = preload("res://src/world_kit/world_pack.gd")
const Gates = preload("res://src/world_editor/world_gates.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const Contents = preload("res://src/world_kit/room_contents.gd")
const FrostPuzzles = preload("res://src/world_kit/frost_puzzles.gd")
const C := 96.0
## Free cells round the room in the floor's grid, so the outer walls have room to stand.
const MARGIN := 2
## Sort offsets of the layers: "floor" lies under everyone, "front" stands over everyone.
const LAYER_Z := {"floor": -1000000.0, "normal": 0.0, "front": 1000000.0}
const FLOOR_NAMES := ["floor_00", "floor_01", "floor_02", "floor_03", "floor_04"]
## Generator pieces a single room can hold as they are.
const RAW_KINDS := ["shop", "npc", "seal", "crate", "vault"]
## World px per art pixel of the Pixel sets.
const PIXEL_GRID := 3
## The pictures already cut to the Pixel grid, by source file.
static var _pixelated: Dictionary = {}

var room: Dictionary = {}
var pack: Dictionary = {}
var error_message: String = ""


func _init(record: Dictionary) -> void:
	room = record
	pack = DataCache.load_dict(str(Data.WORLDS.get(str(room.get("world", "")), Data.WORLDS.krypta).pack))


## A room is one floor.
func floor_count() -> int:
	return 1


## A texture by asset name: "@res://x.png" a file, "@res://x.png#i/n" picture i of a strip of n.
static func load_asset(name: String) -> Texture2D:
	if not name.begins_with("@"):
		return null
	var path := name.substr(1)
	var strip := path.find("#")
	if strip < 0:
		return load(path) if ResourceLoader.exists(path) else null
	var base: Texture2D = load(path.left(strip)) if ResourceLoader.exists(path.left(strip)) else null
	if base == null:
		return null
	var parts := path.substr(strip + 1).split("/")
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	var w := float(base.get_width()) / maxf(1.0, float(parts[1]))
	atlas.region = Rect2(float(parts[0]) * w, 0.0, w, base.get_height())
	return atlas


## True while `theme` shows its Pixel set (the merged skin's sprites are the Pixel ones).
static func pixel_mode(theme: Dictionary) -> bool:
	var skins: Dictionary = theme.get("skins", {})
	return skins.has("pixel") and str(theme.get("sprites", "")) == str(skins.pixel.get("sprites", ""))


## `name` in the shown graphics set when it has one: a picture only the other set has comes from
## there, and in Pixel view an HD-only picture is cut to the Pixel set's grid, so every room shows
## in both views. A file of either set's folder is taken from the shown set the same way.
static func resolve(name: String, theme: Dictionary) -> Texture2D:
	var skins: Dictionary = theme.get("skins", {})
	var shown := str(theme.get("sprites", ""))
	var pixel := pixel_mode(theme)
	var plain := name
	if name.begins_with("@"):
		plain = ""
		for skin: Dictionary in skins.values():
			var folder := str(skin.get("sprites", ""))
			if folder != "" and name.begins_with("@" + folder) and not name.contains("#"):
				plain = name.trim_prefix("@" + folder).trim_suffix(".png")
		if plain == "":
			return load_asset(name)
	if ResourceLoader.exists(shown + plain + ".png"):
		return load(shown + plain + ".png")
	for skin: Dictionary in skins.values():
		var path := str(skin.get("sprites", "")) + plain + ".png"
		if ResourceLoader.exists(path):
			return pixelated(load(path)) if pixel else load(path)
	return load_asset(name)


## A picture cut to the Pixel sets' grid (3 world px per art pixel), its size unchanged.
static func pixelated(source: Texture2D) -> Texture2D:
	if source == null or _pixelated.has(source.resource_path):
		return _pixelated.get(source.resource_path if source != null else "", null)
	var image := source.get_image()
	if image == null:
		return source
	if image.is_compressed():
		image.decompress()
	var w := image.get_width()
	var h := image.get_height()
	image.resize(maxi(1, w / PIXEL_GRID), maxi(1, h / PIXEL_GRID), Image.INTERPOLATE_NEAREST)
	image.resize(w, h, Image.INTERPOLATE_NEAREST)
	var made := ImageTexture.create_from_image(image)
	_pixelated[source.resource_path] = made
	return made


## Adds what the room uses from outside the shown set to `tex`, in both graphics views (resolve).
func fill_textures(tex: Dictionary, theme: Dictionary) -> void:
	var names := {}
	for o: Dictionary in room.get("objects", []):
		for n: Variant in o.get("frames", [o.get("asset", "")]):
			names[str(n)] = true
		if str(o.kind) == "gate":
			for side: bool in [false, true]:
				names[Gates.picture(o, side)] = true
				names[Gates.picture(o, side, true)] = true
	for v: Variant in (room.get("areas", {}) as Dictionary).values():
		names[str(v)] = true
	for v: Variant in (room.get("tiles", {}) as Dictionary).values():
		names[str(v)] = true
	fill_names(names, tex, theme)


## Adds the named pictures to `tex` in both graphics views (resolve).
static func fill_names(names: Dictionary, tex: Dictionary, theme: Dictionary) -> void:
	for name: String in names:
		if name == "" or tex.has(name):
			continue
		var t: Texture2D = resolve(name, theme)
		if t != null:
			tex[name] = t


## The floor of this room. n and run only feed the world's look.
func build_raw(n: int, run: int) -> Dictionary:
	var trouble := Data.problems(room)
	if not trouble.is_empty():
		error_message = trouble[0]
		return {}
	error_message = ""
	var w := int(room.width)
	var h := int(room.height)
	var cols := w + MARGIN * 2
	var rows := h + MARGIN * 2
	var offset := Vector2(MARGIN, MARGIN) * C
	var grid := PackedInt32Array()
	grid.resize(cols * rows)
	var room_at: Array = []
	room_at.resize(cols * rows)
	room_at.fill(-1)
	var tile_names: Array = FLOOR_NAMES.duplicate()
	var tile_text := ""
	var pit_cells := {}
	for y in range(rows):
		for x in range(cols):
			var cell := Data.cell_at(room, x - MARGIN, y - MARGIN)
			var i := y * cols + x
			var value := 0
			match cell:
				Data.FLOOR: value = 1
				Data.LIQUID: value = 2
				Data.BRIDGE: value = 3
				Data.PIT:
					value = 1
					pit_cells[i] = true
			grid[i] = value
			if value != 0:
				room_at[i] = 0
			var tile: int = (x * 7 + y * 3) % FLOOR_NAMES.size()
			var own := str((room.get("tiles", {}) as Dictionary).get("%d,%d" % [x - MARGIN, y - MARGIN], ""))
			if own != "":
				if not tile_names.has(own):
					tile_names.append(own)
				tile = tile_names.find(own)
			tile_text += String.num_int64(tile, 36) if tile < 36 else "0"
	var areas := {}
	for spot: String in (room.get("areas", {}) as Dictionary):
		var at := spot.split(",")
		areas[(int(at[1]) + MARGIN) * cols + int(at[0]) + MARGIN] = str(room.areas[spot])
	var props: Array = []
	var ents: Array = []
	var doors: Array = []
	var lights: Array = []
	var groups := _groups()
	var start := Vector2(w * 0.5, h * 0.5)
	var enemies: Array = []
	var light_cfg: Dictionary = Terrain.config().get("lights", {})
	var light_color := str((light_cfg.get("colors", {}) as Dictionary).get(str(room.world), "255,170,80"))
	var door_of_group := {}
	var decals: Array = RoomFloor.bridge_decals(room, Vector2i(MARGIN, MARGIN))
	var wall_decor: Array = []
	var passages: Array = []
	for l: Dictionary in room.get("lights", []):
		lights.append({"x": float(l.x) + offset.x, "y": float(l.y) + offset.y, "r": l.r, "c": l.c})
	# what the gates dig is ground, as the editor shows it
	for c: Vector2i in Gates.dug(room):
		var at := (c.y + MARGIN) * cols + c.x + MARGIN
		grid[at] = 1
		room_at[at] = 0
	# gates and secret walls first: what opens them refers to their index
	for o: Dictionary in room.objects:
		if str(o.kind) == "gate" and not Gates.closes(o):
			passages.append(_passage(o))
		elif str(o.kind) in ["gate", "secret"]:
			var d := _door(o, cols)
			d.index = doors.size()
			doors.append(d)
			door_of_group[str(o.get("group", "A"))] = int(d.index)
			if str(o.kind) == "secret":
				for c: Array in d.cells:
					var i := int(c[1]) * cols + int(c[0])
					room_at[i] = 0
					grid[i] = 0
	for o: Dictionary in room.objects:
		var x := float(o.x) + offset.x
		var y := float(o.y) + offset.y
		var kind := str(o.kind)
		match kind:
			"start":
				start = Vector2(float(o.x) / C, float(o.y) / C)
			"prop":
				if o.has("decal"):
					var flat := Data.stretch(o)
					decals.append({"name": str(o.asset), "x": x, "y": y - float(o.decal.get("dy", 0.0)), "w": o.decal.get("w", 0), "h": o.decal.get("h", 0), "a": o.decal.get("a", 1.0), "sx": flat.x, "sy": flat.y})
					continue
				if bool(o.get("wall_decor", false)):
					var hung := Data.stretch(o)
					wall_decor.append({"name": str(o.asset), "x": x, "y": y - 74.0, "flip": bool(o.get("flip", false)), "sx": hung.x, "sy": hung.y})
					if _lit(str(o.asset), light_cfg):
						lights.append({"x": x, "y": y - 34.0, "r": int(light_cfg.get("radius", 240)), "c": light_color})
					continue
				var p := _prop(o, x, y)
				props.append(p)
				if _lit(str(o.asset), light_cfg):
					lights.append({"x": x, "y": y - float(light_cfg.get("height", 50)), "r": int(light_cfg.get("radius", 240)), "c": light_color})
			"enemy":
				if Contents.is_chest_mob(str(o.get("mob", ""))):
					var hiding := Contents.hiding_chest(str(o.mob), x, y)
					hiding.room = 0
					ents.append(hiding)
				else:
					enemies.append({"x": x, "y": y, "mob": str(o.get("mob", ""))})
			# a generator's piece without an own part in the Weltbauer (a template's shop, seal, vault)
			"raw":
				var e: Dictionary = (o.ent as Dictionary).duplicate(true)
				if str(e.get("type", "")) in RAW_KINDS:
					e.x = x
					e.y = y
					e.room = 0
					if str(e.get("drop", "")) == "random":
						e.drop = RoomFloor.crate_drop(str(e.get("look", "")), randf())
					ents.append(e)
			"tablet":
				var e := ent_of(o, x, y)
				e.room = 0
				ents.append(e)
				props.append(_prop(Contents.tablet_prop(o), x, y))
			"skullheap":
				var e := ent_of(o, x, y)
				if door_of_group.has(str(o.get("group", "A"))):
					e.door = door_of_group[str(o.get("group", "A"))]
					ents.append(e)
			_:
				var e := ent_of(o, x, y)
				if not e.is_empty():
					e.room = 0
					if kind == "chest":
						Contents.finish_chest(e, o, n, randf)
					ents.append(e)
	for i in range(pit_cells.size()):
		var at: int = pit_cells.keys()[i]
		ents.append({"type": "pit", "x": (at % cols + 0.5) * C, "y": (at / cols + 0.5) * C, "room": 0})
	var grid_text := ""
	for v: int in grid:
		grid_text += str(v)
	var floor_def: Dictionary = (pack.floors as Array)[clampi(n, 1, (pack.floors as Array).size() - 1)]
	var lighting: Dictionary = pack.get("light", {}) if pack.get("light") is Dictionary else {}
	var look := {"dark": 0.6 * float(lighting.get("dark", 1.0)), "grade": 0.0, "vignette": 0.25 * float(lighting.get("vignette", 1.0)),
		"embers": 2, "hot": 0.0, "wall_glow": 0.0, "circle": 0}
	match str(room.world):
		"krypta": look.crypt = true
		"frost": look.frost = true
	# by chance only the count counts, by hand only the placed ones
	var by_hand := Data.spawn_mode(room) == "manual"
	if not by_hand:
		enemies = []
	var title := str(room.get("title", "Raum"))
	# a labyrinth's dark part, in the floor's cells (room_floor.gd maze_zone)
	var zone: Array = RoomFloor.maze_zone(room, Vector2i(MARGIN, MARGIN)) if bool(room.get("maze", false)) else []
	var kind_name := str(Data.ROLES.get(str(room.get("role", "combat")), "Raum")).to_upper()
	return {"n": n, "title": title, "circle": str(Data.WORLDS[str(room.world)].name), "final": false,
		"seed": WorldPack.floor_seed(run, n), "run": run, "cell": int(C), "cols": cols, "rows": rows, "theme": look,
		"boss": (floor_def.boss as Dictionary).duplicate(true), "diff": {"hp": 1.0, "speed": 1.0, "extra": 0, "shooters": false},
		"grid": grid_text, "holes": _holes(grid, cols, rows), "tiles": tile_text, "tile_names": tile_names, "room_at": room_at, "quick": -1,
		"rooms": [{"index": 0, "id": str(room.id), "name": title, "kind": kind_name, "type": "start", "gtype": "start", "icon": "", "icon_key": "",
			"bx": MARGIN, "by": MARGIN, "bw": w, "bh": h, "mobs": 0 if by_hand else int(room.get("auto_mobs", 0)), "spawn": [start.x, start.y], "drop": "", "reward": null,
			"cleared": true, "info": title, "on_path": true, "seq": false, "tidy": true, "placed_mobs": enemies, "maze_zone": zone,
			"weather": str(room.get("weather", "")), "weather_extra": room.get("weather_extra", []),
			"ice": bool(room.get("ice_lake", false)), "ice_lake": bool(room.get("ice_lake", false))}],
		"doors": doors, "groups": groups, "ents": ents, "props": props, "decals": decals, "wall_decor": wall_decor, "lights": lights,
		"areas": areas, "pit_cells": pit_cells, "passages": passages, "doorways": _doorways()}


## The thing on the floor a placed part stands for, at world place x, y; {} when it is none.
static func ent_of(o: Dictionary, x: float, y: float) -> Dictionary:
	var kind := str(o.kind)
	match kind:
		"chest":
			var loot: Dictionary = o.get("loot", {"type": "gold", "amount": 6})
			var type := str(loot.get("type", "none"))
			# "auto": what a floor pays here; a room tried on its own holds a little gold
			var e := {"type": "chest", "x": x, "y": y, "state": "", "magic": false, "exact": true,
				"loot": {"gems": 6 if type == "auto" else (int(loot.get("amount", 0)) if type == "gold" else 0), "heart": type == "heart"}}
			if type == "key":
				e.loot = {"gems": 0, "key": str(loot.get("id", "A"))}
			elif type not in ["gold", "heart", "none", "auto", "random"]:
				e.give = loot
			return e
		"plate":
			var plate := {"type": "plate", "x": x, "y": y, "group": str(o.get("group", "A")), "order": int(o.get("order", 0)), "on": false}
			# stepped in the wrong order it lets them out (once)
			var out := Contents.enemies_of(o)
			if not out.is_empty():
				plate.enemies = out
			return plate
		"lever":
			return {"type": "lever", "x": x, "y": y, "wy": y - 98.0, "group": str(o.get("group", "A")), "lit": false}
		"brazier":
			var bowl := {"type": "brazier", "x": x, "y": y, "group": str(o.get("group", "A")), "lit": false}
			# a cold bowl of the Frostgruft is lit only by carried ember (frost_puzzles.gd)
			if bool(o.get("cold", false)):
				bowl.cold = true
			return bowl
		"launch":
			var pad := {"type": "launch", "x": x, "y": y, "dir": str(o.get("dir", "n")), "cells": int(o.get("cells", 4))}
			# a pad that sleeps until this group is solved (launch_pads.gd awake)
			if str(o.get("wake", "")) != "":
				pad.wake = str(o.wake)
			return pad
		"tablet":
			return {"type": "tablet", "x": x, "y": y, "text": str(o.get("text", ""))}
		"spikes":
			return {"type": "spikes", "x": x, "y": y, "phase": int(o.get("phase", 0))}
		"vent":
			return {"type": "vent", "x": x, "y": y, "offset": float(o.get("offset", 0.0))}
		"key":
			return {"type": "key", "x": x, "y": y, "key": str(o.get("key", "A"))}
		"heart", "gem":
			return {"type": kind, "x": x, "y": y}
		"well":
			return {"type": kind, "x": x, "y": y, "used": false}
		"portal":
			return {"type": kind, "x": x, "y": y, "active": true}
		"skullheap":
			return {"type": "skullheap", "x": x, "y": y, "room": 0, "hp": int(o.get("hp", 3))}
	# the Frostgruft's puzzle pieces keep their settings as they are (src/world_kit/frost_puzzles.gd)
	if FrostPuzzles.KINDS.has(kind):
		var piece := o.duplicate(true)
		piece.erase("kind")
		piece.type = kind
		piece.x = x
		piece.y = y
		return piece
	return {}


## The groups the placed triggers make: what kind each one is follows from its pieces.
func _groups() -> Dictionary:
	var out := {}
	for o: Dictionary in room.objects:
		var kind := str(o.kind)
		var opens := str(o.get("opens", "")) if kind == "prop" else ""
		var frost := FrostPuzzles.KINDS.has(kind) and str(o.get("group", "")) != ""
		if kind not in ["plate", "lever", "brazier", "gate", "secret", "skullheap"] and opens == "" and not frost:
			continue
		if kind == "gate" and not Gates.closes(o):
			continue
		var id := opens if opens != "" else str(o.get("group", "A"))
		if not out.has(id):
			out[id] = {"kind": "plates"}
		match kind:
			"plate":
				if int(o.get("order", 0)) > 0:
					out[id].kind = "sequence"
					out[id].count = int(out[id].get("count", 0)) + 1
			"lever": out[id].kind = "lever"
			"brazier": out[id].kind = "braziers"
			_:
				if frost and str(out[id].kind) == "plates":
					out[id].kind = "frost"
	return out


func _door(o: Dictionary, cols: int) -> Dictionary:
	var travel := str(o.get("dir", "v"))
	var a := Vector2i(int(float(o.x) / C), int(float(o.y) / C)) + Vector2i(MARGIN, MARGIN)
	var b := a + (Vector2i(0, 1) if travel == "h" else Vector2i(1, 0))
	var middle := (Vector2(a + b) * 0.5 + Vector2(0.5, 0.5)) * C
	var lock := str(o.get("lock", ""))
	var kind := "secret" if str(o.kind) == "secret" else ("lock" if lock != "" else "puzzle")
	var look: Dictionary = _gate_look(o) if str(o.kind) == "gate" else {}
	return look.merged({"a": 0, "b": 0, "kind": kind, "key": lock, "group": str(o.get("group", "A")), "hidden": kind == "secret", "dir": travel,
		"cells": [[a.x, a.y], [b.x, b.y]], "x0": a.x, "y0": a.y, "x1": b.x, "y1": b.y, "cx": middle.x, "cy": middle.y,
		"crack_x": middle.x, "crack_y": middle.y, "boss_gate": false})


## The gates' places in the floor's grid, for the wall builder.
func _doorways() -> Array:
	var out: Array = []
	for way: Dictionary in Gates.doorways(room):
		var shifted: Array = []
		for c: Vector2i in way.cells:
			shifted.append(c + Vector2i(MARGIN, MARGIN))
		out.append({"cells": shifted, "dir": way.dir})
	return out


## An open passage: dug by Gates.dug, only its picture stands there.
func _passage(o: Dictionary) -> Dictionary:
	var m := Gates.middle(o) + Vector2(MARGIN, MARGIN) * C
	return _gate_look(o).merged({"cx": m.x, "cy": m.y, "dir": str(o.get("dir", "v"))})


## What the game draws for a gate: its pictures, in the shown set's names.
func _gate_look(o: Dictionary) -> Dictionary:
	return {"pictures": {"front": Gates.picture(o, false), "side": Gates.picture(o, true), "open_front": Gates.picture(o, false, true), "open_side": Gates.picture(o, true, true)},
		"art_scale": float(Gates.style_of(o).get("scale", 1.0)), "art_dx": Gates.side_shift(room, o)}


func _prop(o: Dictionary, x: float, y: float) -> Dictionary:
	return prop_of(o, x, y)


## The raw prop of a placed part at world place x, y.
static func prop_of(o: Dictionary, x: float, y: float) -> Dictionary:
	var solid: Variant = null
	if bool(o.get("block", false)):
		var foot: Array = o.get("foot", [60, 30])
		solid = [x - float(foot[0]) * 0.5, y - float(foot[1]), x + float(foot[0]) * 0.5, y]
	var size := Data.stretch(o)
	var p := {"name": str(o.asset), "x": x, "y": y, "flip": bool(o.get("flip", false)), "low": false, "solid": solid,
		"z": float(LAYER_Z.get(str(o.get("layer", "normal")), 0.0)), "sx": size.x, "sy": size.y}
	if o.has("frames"):
		p.frames = o.frames
		p.fps = float(o.get("fps", 8.0))
	for key: String in ["loot", "opens", "enemies"]:
		if o.has(key):
			p[key] = o[key]
	return p


static func _lit(name: String, cfg: Dictionary) -> bool:
	var low := name.to_lower()
	for word: Variant in cfg.get("match", []):
		if low.contains(str(word)):
			return true
	return false


## Wall cells cut off from the outside show their top ("1"); the outside stays dark ("0").
static func _holes(grid: PackedInt32Array, cols: int, rows: int) -> String:
	var outside := {0: true}
	var todo: Array = [0]
	while not todo.is_empty():
		var i: int = todo.pop_back()
		var x := i % cols
		var y := i / cols
		for n: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var k := n.y * cols + n.x
			if grid[k] == 0 and not outside.has(k):
				outside[k] = true
				todo.append(k)
	var text := ""
	for i in range(grid.size()):
		text += "1" if grid[i] == 0 and not outside.has(i) else "0"
	return text

extends RefCounted
## The gates of a Weltbauer room, one truth for the editor and the game: where a gate may stand, which
## way it lies (from the wall it stands in), what it digs out of the wall and which pictures it shows.
## A gate's x, y is the corner of its first cell; it stands on two cells side by side. A "v" gate lies in
## a wall running left and right (the way leads up and down), an "h" gate in one running up and down.
## Styles and pictures: assets/data/world_gates.json. Testable without UI.

const Data = preload("res://src/world_editor/world_room_data.gd")
const CONFIG := "res://assets/data/world_gates.json"
const DEFAULT_STYLE := "portcullis"
const CELL := 96.0
## How far (in cells) a click may lie from the wall it means.
const REACH := 2.2


static func config() -> Dictionary:
	return DataCache.load_dict(CONFIG)


## The style's data of a gate; an old gate without one is the portcullis.
static func style_of(o: Dictionary) -> Dictionary:
	var styles: Dictionary = config().styles
	return styles.get(str(o.get("style", DEFAULT_STYLE)), styles[DEFAULT_STYLE])


## False for an open passage, which is only dug and dressed.
static func closes(o: Dictionary) -> bool:
	return str(o.kind) == "gate" and bool(style_of(o).get("closes", true))


## The styles to choose from in `world`: id -> label.
static func labels_for(world: String) -> Dictionary:
	var out := {}
	var styles: Dictionary = config().styles
	for id: String in styles:
		if world in (styles[id] as Dictionary).get("worlds", [world]):
			out[id] = str(styles[id].label)
	return out


## The asset name of a gate's picture: in a wall running up and down the stone slab (shut or slid
## open), else the style's own, what stays for `open` ("" when nothing stays). A gate from a set of
## its own (set_folder) takes it from there.
static func picture(o: Dictionary, side: bool, open: bool = false) -> String:
	var style := style_of(o)
	var name := ""
	if side:
		name = str(config().open_side_picture if open or not bool(style.get("closes", true)) else config().side_picture)
	else:
		name = str(style.get("open_front" if open else "front", ""))
	if name == "" or name.begins_with("@") or str(o.get("set_folder", "")) == "":
		return name
	return "@%s%s.png" % [str(o.set_folder), name]


## The gate's own two cells.
static func cells(o: Dictionary) -> Array[Vector2i]:
	var a := Vector2i(int(float(o.x) / CELL), int(float(o.y) / CELL))
	return [a, a + (Vector2i(0, 1) if str(o.get("dir", "v")) == "h" else Vector2i(1, 0))]


## The middle of the gate's two cells in room px.
static func middle(o: Dictionary) -> Vector2:
	var c := cells(o)
	return (Vector2(c[0] + c[1]) * 0.5 + Vector2(0.5, 0.5)) * CELL


## Where a gate lands for a click at `p`: the nearest two wall cells side by side with open ground on
## one side, and the lie that wall gives it. {"x", "y", "dir", "ok"}; ok false: no wall near.
## `moving` is a gate being moved: its own place counts as free.
static func spot(room: Dictionary, p: Vector2, moving: Dictionary = {}) -> Dictionary:
	var taken := _gate_cells(room, moving)
	var c := Vector2i((p / CELL).floor())
	var best := {}
	var best_d := REACH * CELL
	var near := int(ceil(REACH)) + 1
	for y in range(c.y - near, c.y + near + 1):
		for x in range(c.x - near, c.x + near + 1):
			for lie: String in ["v", "h"]:
				var o := {"x": x * CELL, "y": y * CELL, "dir": lie}
				if not _fits(room, o, taken):
					continue
				var d := middle(o).distance_to(p)
				if d < best_d:
					best_d = d
					best = o
	if best.is_empty():
		return {"x": roundf(p.x / CELL) * CELL, "y": roundf(p.y / CELL) * CELL, "dir": str(moving.get("dir", "v")), "ok": false}
	best.ok = true
	return best


static func _gate_cells(room: Dictionary, moving: Dictionary) -> Dictionary:
	var out := {}
	for o: Dictionary in room.objects:
		if str(o.kind) in ["gate", "secret"] and not is_same(o, moving):
			for k: Vector2i in cells(o):
				out[k] = true
	return out


static func _fits(room: Dictionary, o: Dictionary, taken: Dictionary) -> bool:
	var two := cells(o)
	var across := Vector2i(1, 0) if str(o.dir) == "h" else Vector2i(0, 1)
	var open_before := true
	var open_after := true
	for k: Vector2i in two:
		if Data.cell_at(room, k.x, k.y) != Data.WALL or taken.has(k):
			return false
		if k.x < 0 or k.y < 0 or k.x >= int(room.width) or k.y >= int(room.height):
			return false
		open_before = open_before and Data.cell_at(room, k.x - across.x, k.y - across.y) != Data.WALL
		open_after = open_after and Data.cell_at(room, k.x + across.x, k.y + across.y) != Data.WALL
	return open_before or open_after


## The gates as the wall builder wants them (hell_walls.gd): the wall runs on past them.
static func doorways(room: Dictionary) -> Array:
	var out: Array = []
	for o: Dictionary in room.objects:
		if str(o.kind) == "gate":
			out.append({"cells": cells(o), "dir": str(o.get("dir", "v"))})
	return out


## The cells that become ground because a gate leads somewhere: Vector2i -> true. Only with ground on
## both sides of the wall (at most tunnel_cells away) is there a way through, then the wall between
## is dug. A gate with nothing behind it stands in the wall and digs nothing. Secret walls stay wall.
static func dug(room: Dictionary) -> Dictionary:
	var out := {}
	var most := int(config().tunnel_cells)
	for o: Dictionary in room.objects:
		if str(o.kind) != "gate":
			continue
		var across := Vector2i(1, 0) if str(o.get("dir", "v")) == "h" else Vector2i(0, 1)
		for k: Vector2i in cells(o):
			var through: Array[Vector2i] = [k]
			var open_ends := 0
			for way: Vector2i in [across, -across]:
				var at := k + way
				var run: Array[Vector2i] = []
				while run.size() < most and Data.cell_at(room, at.x, at.y) == Data.WALL and _inside(room, at):
					run.append(at)
					at += way
				if _inside(room, at) and Data.cell_at(room, at.x, at.y) != Data.WALL:
					open_ends += 1
					through.append_array(run)
			if open_ends == 2:
				for r: Vector2i in through:
					out[r] = true
	return out


static func _inside(room: Dictionary, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < int(room.width) and c.y < int(room.height)


## How far a side gate's slab stands off its doorway's middle: in an outer wall it lies in the wall
## column beside the room, between two rooms in the middle.
static func side_shift(room: Dictionary, o: Dictionary) -> float:
	if str(o.get("dir", "v")) != "h":
		return 0.0
	var a := cells(o)[0]
	var left := Data.cell_at(room, a.x - 1, a.y) != Data.WALL
	var right := Data.cell_at(room, a.x + 1, a.y) != Data.WALL
	if left == right:
		return 0.0
	return float(config().wall_shift) * (-1.0 if left else 1.0)


## What a picture means: {style, side} when it shows a gate, else {}.
## `name` is a set picture's plain name, or "@path" for a file.
static func style_of_picture(name: String) -> Dictionary:
	var named: Dictionary = config().picture_labels
	if named.has(name):
		return {"style": str(named[name].style), "side": true, "label": str(named[name].label)}
	var styles: Dictionary = config().styles
	for id: String in styles:
		var style: Dictionary = styles[id]
		if str(style.front) == name:
			return {"style": id, "side": false, "label": str(style.label)}
	return {}


## Old rooms hold gate pictures as loose pieces: they become gates where a wall is near.
static func adopt_pieces(room: Dictionary) -> void:
	if not room.has("objects"):
		return
	for o: Dictionary in room.objects:
		if str(o.get("kind", "")) != "prop":
			continue
		var meant := style_of_picture(str(o.get("asset", "")))
		if meant.is_empty() or str(o.get("asset", "")).begins_with("door_stairs"):
			continue
		var at := spot(room, Vector2(float(o.x), float(o.y) - CELL * 0.5))
		if not bool(at.ok):
			continue
		o.clear()
		o.merge({"kind": "gate", "style": meant.style, "x": at.x, "y": at.y, "dir": at.dir, "group": "A", "lock": ""})

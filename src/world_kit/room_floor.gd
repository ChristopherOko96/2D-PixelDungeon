extends RefCounted
## A floor built from room files. The world kit's plan (world_core.gd generate, describe) still decides
## which rooms there are, how they hang together, where keys and locks go. Each room of the plan is
## then a file of the Weltbauer (assets/data/world_rooms/<world>/, marked in_floors), so every room can
## be redesigned there. Every room keeps its own walls and gates; a short corridor joins two gates.
##
## A room file says which slots of the plan's grid it covers (slots) and where a door may stand (ports).
## Only those doors exist: a file goes where the plan's doors can lie on its spots, moved along the wall
## two rooms share if need be. A spot marked "in" or "out" is used that way when any file allows it.
## A slot is slot_size cells; slot_gap cells lie between two slots for the corridor. What depends on the
## plan is put in here and not stored: the floor's plates, soul bowls, seals, loot and the boss gate's
## dressing. All sizes: pack key room_library. Same run number, same floor.

const Core = preload("res://src/world_kit/world_core.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const Gates = preload("res://src/world_editor/world_gates.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const Contents = preload("res://src/world_kit/room_contents.gd")
const C := 96.0
## How often a new plan is tried when the room files do not fit one.
const ATTEMPTS := 60
const ROLE_OF := {"jump": "jump", "start": "start", "combat": "combat", "shrine": "combat", "boss": "boss", "portal": "portal", "key": "key",
	"treasure": "treasure", "vault": "vault", "pvault": "vault", "secret": "secret", "hidden": "secret", "stairs": "stairs"}
const SIDES := {"north": Vector2i(0, -1), "east": Vector2i(1, 0), "south": Vector2i(0, 1), "west": Vector2i(-1, 0)}
const OPPOSITE := {"north": "south", "east": "west", "south": "north", "west": "east"}
## Which of a room's six plates in reading order a floor of 4 or 5 plates uses.
const PLATE_PICK := {4: [0, 2, 3, 5], 5: [0, 1, 2, 3, 5], 6: [0, 1, 2, 3, 4, 5]}
## The loaded room files per world and folder.
static var _cache: Dictionary = {}


## The room files of `world` that floors may use.
static func library(world: String, base: String = Data.DIR) -> Array:
	var key := base + "/" + world
	if not _cache.has(key):
		_cache[key] = Data.list_rooms(world, base).filter(func(t: Dictionary) -> bool:
			return bool(t.get("in_floors", false)) and Data.problems(t).is_empty() and Data.floor_size_fits(t))
	return _cache[key]


## Forgets the loaded room files (after saving one in a running test).
static func forget() -> void:
	_cache.clear()


## Adds every picture the room files of `world` use to `tex`.
static func fill_textures(world: String, tex: Dictionary, theme: Dictionary) -> void:
	var names := {}
	for t: Dictionary in library(world):
		for o: Dictionary in t.objects:
			if o.has("asset"):
				names[str(o.asset)] = true
			for n: Variant in o.get("frames", []):
				names[str(n)] = true
			if str(o.kind) == "gate":
				for side: bool in [false, true]:
					names[Gates.picture(o, side)] = true
					names[Gates.picture(o, side, true)] = true
		for key: String in ["areas", "tiles"]:
			for v: Variant in (t.get(key, {}) as Dictionary).values():
				names[str(v)] = true
	RoomWorld.fill_names(names, tex, theme)


## Floor n of a run on `pack` (a WorldPack) as the generator's world data, {} when no plan fits the files.
static func build(n: int, run: int, pack: RefCounted) -> Dictionary:
	var cfg: Dictionary = pack.pack.room_library
	var files := library(str(cfg.world), str(cfg.get("folder", Data.DIR)))
	if files.is_empty():
		return {}
	var opts: Dictionary = pack.for_run(run)
	var P: Dictionary = opts.floors[n]
	var floor_seed := int(P.seed)
	for attempt in range(ATTEMPTS):
		P.seed = floor_seed + attempt * 7919
		var plan := Core.describe(P, Core.generate(P), Core.Rng.new(int(P.seed) + 99), opts.names, opts.suffixes)
		var picks := _pick_files(plan, files, cfg, Core.Rng.new(int(P.seed) + 31))
		if picks.is_empty():
			continue
		P.seed = floor_seed
		var W := _assemble(n, P, plan, picks, cfg, opts, pack)
		if not W.is_empty():
			return W
	return {}


## The file of each room of the plan: rooms.size() files by room id, {} when one has none that fits.
## Files are not repeated on a floor while others fit. Puzzle and riddle rooms choose first, their doors
## are the few set by hand; the plan's doors move to suit them.
static func _pick_files(plan: Dictionary, files: Array, cfg: Dictionary, rnd: Core.Rng) -> Dictionary:
	var by_id := {}
	for r: Dictionary in plan.rooms:
		by_id[r.id] = r
	var ctx := {"plan": plan, "files": files, "cfg": cfg, "rnd": rnd, "by_id": by_id, "picks": {}, "used": {},
		"entries": _entry_doors(plan), "before_boss": _room_before_boss(plan)}
	_choose_jump_rooms(ctx)
	var riddle_first: Array = (plan.rooms as Array).filter(func(r: Dictionary) -> bool: return r.get("seq", false))
	riddle_first.append_array((plan.rooms as Array).filter(func(r: Dictionary) -> bool: return not r.get("seq", false)))
	for r: Dictionary in riddle_first:
		if ctx.picks.has(r.id):
			continue
		var fits := _fitting(r, str(ROLE_OF.get(str(r.gtype), "combat")), ctx)
		if fits.is_empty():
			return {}
		_take(r, fits, ctx)
	return ctx.picks


## Some fight rooms of three slots become big rooms without a fight: jump puzzles and mazes, when one has
## door spots for this place. Never one the floor's plan needs a fight or a piece in (a key's drop, plates,
## a soul bowl, the boss gate, a shrine).
static func _choose_jump_rooms(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var left := int(cfg.get("jump_rooms", 2))
	for r: Dictionary in ctx.plan.rooms:
		if left <= 0:
			return
		var free: bool = str(r.gtype) == "combat" and (r.slots as Array).size() == 3 and not r.has("drop") and not r.has("reward") and not r.get("seq", false) and not r.get("fireBrazier", false) and str(r.id) != str(ctx.before_boss)
		if not free or ctx.rnd.next() >= float(cfg.get("jump_share", 0.6)):
			continue
		var fits := _fitting(r, "jump", ctx)
		if fits.is_empty():
			continue
		r.gtype = "jump"
		r.type = "jump"
		r.mobs = 0
		left -= 1
		_take(r, fits, ctx)


## The files of `role` that fit room `r` here, each with where its doors go: [{file, doors, cost}].
static func _fitting(r: Dictionary, role: String, ctx: Dictionary) -> Array:
	var out: Array = []
	var shape := _shape_of(r.slots)
	var at := _low_corner(r.slots)
	for t: Dictionary in ctx.files:
		if str(t.get("role", "")) != role or _shape_of(t.get("slots", [[0, 0]])) != shape:
			continue
		if r.get("seq", false) and _plates_of(t).size() < 6:
			continue
		var placed := _place_doors(t, r, at, ctx)
		if placed.is_empty() and (role == "jump" or r.get("seq", false)):
			placed = _rerouted(t, r, at, ctx)
		if placed.is_empty():
			continue
		if str(r.id) == str(ctx.before_boss) and not _takes_boss_gate(t, _port_needs(ctx.plan)[r.id], at, ctx.cfg):
			continue
		placed.file = t
		out.append(placed)
	return out


## Gives room `r` one of the fitting files: one used the way its doors are marked if any is, one not yet
## on this floor if any is. The plan's doors move to the file's spots.
static func _take(r: Dictionary, fits: Array, ctx: Dictionary) -> void:
	var best: int = fits.map(func(f: Dictionary) -> int: return int(f.cost)).min()
	var right := fits.filter(func(f: Dictionary) -> bool: return int(f.cost) == best)
	var fresh := right.filter(func(f: Dictionary) -> bool: return not ctx.used.has(f.file.id))
	var pool: Array = fresh if not fresh.is_empty() else right
	var chosen: Dictionary = pool[int(floor(ctx.rnd.next() * pool.size()))]
	ctx.used[chosen.file.id] = true
	ctx.picks[r.id] = chosen.file
	if chosen.has("route"):
		ctx.plan.doors = chosen.route.doors
		ctx.entries = chosen.route.entries
		for m: Dictionary in chosen.route.moves:
			ctx.by_id[m.id].slots = [m.slot]
	for c: Dictionary in chosen.doors:
		c.door.slots = c.slots
		c.door["port_" + str(r.id)] = c.port


## Where the doors of room `r` lie on file `t`, the fewest used against their mark: {doors, cost}, {} when
## not every door finds a spot.
static func _place_doors(t: Dictionary, r: Dictionary, at: Vector2i, ctx: Dictionary) -> Dictionary:
	var doors: Array = (ctx.plan.doors as Array).filter(func(d: Dictionary) -> bool: return d.a == r.id or d.b == r.id)
	var best := {"cost": -1, "doors": []}
	_try_doors(t, r, at, doors, 0, {}, [], 0, best, ctx)
	return best if int(best.cost) >= 0 else {}


## Tries the door number `i` and those after it on every spot left; `best` holds the best way so far.
static func _try_doors(t: Dictionary, r: Dictionary, at: Vector2i, doors: Array, i: int, taken: Dictionary, chosen: Array, cost: int, best: Dictionary, ctx: Dictionary) -> void:
	if int(best.cost) == 0 or (int(best.cost) > 0 and cost >= int(best.cost)):
		return
	if i == doors.size():
		best.cost = cost
		best.doors = chosen.duplicate()
		return
	var d: Dictionary = doors[i]
	var mine := 0 if d.a == r.id else 1
	var entry: bool = is_same(ctx.entries.get(r.id), d)
	for slots: Array in _door_options(d, ctx):
		var side: String = _door_sides({"slots": slots})[mine]
		var slot := Vector2i(int(slots[mine][0]), int(slots[mine][1])) - at
		var key := [slot, side]
		if taken.has(key):
			continue
		taken[key] = true
		for p: Dictionary in _ports_on(t, slot, side, ctx.cfg):
			var wrong := 1 if str(p.get("use", "")) == ("out" if entry else "in") else 0
			chosen.append({"door": d, "slots": slots, "port": p})
			_try_doors(t, r, at, doors, i + 1, taken, chosen, cost + wrong, best, ctx)
			chosen.pop_back()
		taken.erase(key)


## The way of the plan that gives room `r` just the doors of file `t`, a puzzle or riddle room set by hand:
## a free door of the room goes to the spots of the file, what hung on it is joined up elsewhere between
## rooms behind the same locks. A locked door stays; the chamber behind it moves to a spot when it has to.
## {doors, cost, route}, {} when it cannot be done.
static func _rerouted(t: Dictionary, r: Dictionary, at: Vector2i, ctx: Dictionary) -> Dictionary:
	var plan: Dictionary = ctx.plan
	var locks := _lock_paths(plan)
	var room_at := {}
	for x: Dictionary in plan.rooms:
		for s: Array in x.slots:
			room_at[Vector2i(int(s[0]), int(s[1]))] = str(x.id)
	var pitch := _pitch(ctx.cfg)
	var spots: Array = []
	for p: Dictionary in t.get("ports", []):
		var slot := at + Vector2i(int(p.cell[0]) / pitch.x, int(p.cell[1]) / pitch.y)
		spots.append({"port": p, "slot": slot, "out": slot + (SIDES[str(p.side)] as Vector2i), "free": true})
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.port.get("use", "")) == "in" and str(b.port.get("use", "")) != "in")
	var doors: Array = []
	var moves: Array = []
	for d: Dictionary in plan.doors:
		if d.a != r.id and d.b != r.id:
			doors.append(d)
		elif str(d.kind) != "open":
			var kept := _kept_door(d, r, spots, room_at, moves, ctx)
			if kept.is_empty():
				return {}
			doors.append(kept)
	var joined := {}
	for s: Dictionary in spots:
		var other: String = str(room_at.get(s.out, ""))
		if not s.free or other == "" or joined.has(other) or locks.get(other) != locks.get(str(r.id)) or not _may_get_door(ctx.by_id[other], ctx):
			continue
		joined[other] = true
		s.free = false
		doors.append({"a": r.id, "b": other, "kind": "open", "slots": [[s.slot.x, s.slot.y], [s.out.x, s.out.y]]})
	var way := {"rooms": plan.rooms, "doors": doors, "gc": plan.get("gc", 0), "gr": plan.get("gr", 0)}
	if not _join_up(way, r, room_at, locks, ctx):
		return {}
	var trial: Dictionary = ctx.duplicate()
	trial.plan = way
	trial.entries = _entry_doors(way)
	var placed := _place_doors(t, r, at, trial)
	if placed.is_empty():
		return {}
	placed.route = {"doors": doors, "entries": trial.entries, "moves": moves}
	return placed


## A copy of locked door `d` of room `r` for its new way. Where no spot of the file takes it, the chamber
## behind it moves out to a free slot before one. {} when neither works.
static func _kept_door(d: Dictionary, r: Dictionary, spots: Array, room_at: Dictionary, moves: Array, ctx: Dictionary) -> Dictionary:
	var mine := 0 if d.a == r.id else 1
	var kept := d.duplicate(true)
	for slots: Array in _door_options(d, ctx):
		var side: String = _door_sides({"slots": slots})[mine]
		for s: Dictionary in spots:
			if s.free and str(s.port.side) == side and s.slot == Vector2i(int(slots[mine][0]), int(slots[mine][1])):
				s.free = false
				kept.slots = slots
				return kept
	var other_id := str(d.b if mine == 0 else d.a)
	var other: Dictionary = ctx.by_id[other_id]
	var door_count := (ctx.plan.doors as Array).filter(func(x: Dictionary) -> bool: return x.a == other_id or x.b == other_id).size()
	if door_count != 1 or (other.slots as Array).size() != 1 or ctx.picks.has(other_id) or str(ROLE_OF.get(str(other.gtype), "combat")) in ["boss", "key"]:
		return {}
	for s: Dictionary in spots:
		var out: Vector2i = s.out
		if not s.free or room_at.has(out) or out.x < 0 or out.y < 0 or out.x >= int(ctx.plan.get("gc", 0)) or out.y >= int(ctx.plan.get("gr", 0)):
			continue
		s.free = false
		room_at.erase(Vector2i(int(other.slots[0][0]), int(other.slots[0][1])))
		room_at[out] = other_id
		moves.append({"id": other_id, "slot": [out.x, out.y]})
		kept.slots = [[s.slot.x, s.slot.y], [out.x, out.y]] if mine == 0 else [[out.x, out.y], [s.slot.x, s.slot.y]]
		return kept
	return {}


## True when `room` may take on one more door: a plain room that has not chosen its file yet.
static func _may_get_door(room: Dictionary, ctx: Dictionary) -> bool:
	return not ctx.picks.has(room.id) and str(room.gtype) in ["combat", "shrine", "start"]


## Joins what the way cut off to the rest by new doors between plain rooms behind the same locks, none
## through room `r`. False when a room stays out of reach.
static func _join_up(way: Dictionary, r: Dictionary, room_at: Dictionary, locks: Dictionary, ctx: Dictionary) -> bool:
	while true:
		var reached := _entry_doors(way)
		for x: Dictionary in way.rooms:
			if str(x.gtype) == "start":
				reached[x.id] = true
		if reached.size() == (way.rooms as Array).size():
			return true
		var added := false
		for x: Dictionary in way.rooms:
			if added or reached.has(x.id) or x.id == r.id or not _may_get_door(x, ctx):
				continue
			for s: Array in x.slots:
				for step: Vector2i in SIDES.values():
					var there := Vector2i(int(s[0]), int(s[1])) + step
					var other: String = str(room_at.get(there, ""))
					if added or other == "" or other == str(r.id) or not reached.has(other):
						continue
					if locks.get(other) == locks.get(str(x.id)) and _may_get_door(ctx.by_id[other], ctx):
						way.doors.append({"a": other, "b": x.id, "kind": "open", "slots": [[there.x, there.y], [int(s[0]), int(s[1])]]})
						added = true
		if not added:
			return false
	return false


## room id -> the locked doors on the way to it from the start room, as one text.
static func _lock_paths(plan: Dictionary) -> Dictionary:
	var out := {}
	var todo: Array = []
	for r: Dictionary in plan.rooms:
		if str(r.gtype) == "start":
			out[str(r.id)] = ""
			todo.append(str(r.id))
	while not todo.is_empty():
		var here: String = todo.pop_front()
		for i in range((plan.doors as Array).size()):
			var d: Dictionary = plan.doors[i]
			if str(d.a) != here and str(d.b) != here:
				continue
			var there: String = str(d.b) if str(d.a) == here else str(d.a)
			if not out.has(there):
				out[there] = str(out[here]) + ("" if str(d.kind) == "open" else "%d," % i)
				todo.append(there)
	return out


## Where door `d` may lie: where the plan put it, then every other pair of slots its two rooms share a
## wall on. A door stays put when a room at it has chosen already or is the boss's or the key chamber's.
static func _door_options(d: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = [d.slots]
	var a: Dictionary = ctx.by_id[d.a]
	var b: Dictionary = ctx.by_id[d.b]
	if ctx.picks.has(d.a) or ctx.picks.has(d.b) or str(d.kind) == "boss":
		return out
	for room: Dictionary in [a, b]:
		if str(ROLE_OF.get(str(room.gtype), "combat")) in ["boss", "key"]:
			return out
	for sa: Array in a.slots:
		for sb: Array in b.slots:
			if absi(int(sa[0]) - int(sb[0])) + absi(int(sa[1]) - int(sb[1])) == 1 and str([sa, sb]) != str(d.slots):
				out.append([sa, sb])
	return out


## room id -> the door the plan enters it by: the one nearest the start room.
static func _entry_doors(plan: Dictionary) -> Dictionary:
	var out := {}
	var todo: Array = []
	var seen := {}
	for r: Dictionary in plan.rooms:
		if str(r.gtype) == "start":
			todo.append(str(r.id))
			seen[str(r.id)] = true
	while not todo.is_empty():
		var here: String = todo.pop_front()
		for d: Dictionary in plan.doors:
			if str(d.a) != here and str(d.b) != here:
				continue
			var there: String = str(d.b) if str(d.a) == here else str(d.a)
			if not seen.has(there):
				seen[there] = true
				out[there] = d
				todo.append(there)
	return out


## room id -> the doors it needs as [slot, side], from the plan.
static func _port_needs(plan: Dictionary) -> Dictionary:
	var out := {}
	for d: Dictionary in plan.doors:
		var sides := _door_sides(d)
		for k in range(2):
			var id: String = d.a if k == 0 else d.b
			if not out.has(id):
				out[id] = []
			out[id].append([d.slots[k], sides[k]])
	return out


## The sides of a door's two rooms it leaves through: [side in a, side in b].
static func _door_sides(d: Dictionary) -> Array:
	var sa: Array = d.slots[0]
	var sb: Array = d.slots[1]
	if int(sb[0]) > int(sa[0]): return ["east", "west"]
	if int(sb[0]) < int(sa[0]): return ["west", "east"]
	if int(sb[1]) > int(sa[1]): return ["south", "north"]
	return ["north", "south"]


## The id of the room in front of the boss gate.
static func _room_before_boss(plan: Dictionary) -> String:
	for d: Dictionary in plan.doors:
		if str(d.kind) == "lock" and str(d.get("extra", "")) == "C":
			return str(d.a)
	return ""


static func _shape_of(slots: Array) -> String:
	var lo := _low_corner(slots)
	var parts: Array = []
	for s: Array in slots:
		parts.append("%d,%d" % [int(s[0]) - lo.x, int(s[1]) - lo.y])
	parts.sort()
	return ";".join(parts)


static func _low_corner(slots: Array) -> Vector2i:
	var lo := Vector2i(1 << 30, 1 << 30)
	for s: Array in slots:
		lo = lo.min(Vector2i(int(s[0]), int(s[1])))
	return lo


static func _pitch(cfg: Dictionary) -> Vector2i:
	return Vector2i(int(cfg.slot_size[0]) + int(cfg.slot_gap[0]), int(cfg.slot_size[1]) + int(cfg.slot_gap[1]))


## The port of file `t` on `side` of its slot `slot` (relative to the file), {} when it has none.
static func _port_of(t: Dictionary, slot: Vector2i, side: String, cfg: Dictionary) -> Dictionary:
	var pitch := _pitch(cfg)
	for p: Dictionary in t.get("ports", []):
		if str(p.get("side", "")) != side:
			continue
		if Vector2i(int(p.cell[0]) / pitch.x, int(p.cell[1]) / pitch.y) == slot:
			return p
	return {}


## Every port of file `t` on `side` of its slot `slot`.
static func _ports_on(t: Dictionary, slot: Vector2i, side: String, cfg: Dictionary) -> Array:
	var pitch := _pitch(cfg)
	return (t.get("ports", []) as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("side", "")) == side and Vector2i(int(p.cell[0]) / pitch.x, int(p.cell[1]) / pitch.y) == slot)


## True when the wall round the north door can hold the boss gate's banners, torches and carpet.
static func _takes_boss_gate(t: Dictionary, wanted: Array, at: Vector2i, cfg: Dictionary) -> bool:
	var reach := int(cfg.get("boss_gate_reach", 4))
	var depth := int(cfg.get("boss_gate_depth", 3))
	for w: Array in wanted:
		if str(w[1]) != "north":
			continue
		var p := _port_of(t, Vector2i(int(w[0][0]), int(w[0][1])) - at, "north", cfg)
		var x := int(p.cell[0])
		var y := int(p.cell[1])
		for i in range(x - reach + 1, x + reach + 1):
			if Data.cell_at(t, i, y) != Data.WALL:
				return false
			for j in range(1, depth + 1):
				if Data.cell_at(t, i, y + j) != Data.FLOOR:
					return false
	return true


## The plates a file holds for the floor's sequence, in reading order.
static func _plates_of(t: Dictionary) -> Array:
	var plates: Array = (t.objects as Array).filter(func(o: Dictionary) -> bool:
		return str(o.kind) == "plate" and str(o.get("group", "")) == "seq")
	plates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.y) < float(b.y) - 1.0 or (absf(float(a.y) - float(b.y)) <= 1.0 and float(a.x) < float(b.x)))
	return plates


static func _assemble(n: int, P: Dictionary, plan: Dictionary, picks: Dictionary, cfg: Dictionary, opts: Dictionary, pack: RefCounted) -> Dictionary:
	var theme := Core.theme_for(n, P)
	var pitch := _pitch(cfg)
	var margin := int(cfg.get("margin", 3))
	var cols := int(plan.gc) * pitch.x + margin * 2
	var rows := int(plan.gr) * pitch.y + margin * 2
	var count := cols * rows
	var grid := PackedByteArray()
	grid.resize(count)
	var room_at := PackedInt32Array()
	room_at.resize(count)
	room_at.fill(-1)
	var hole_at := PackedByteArray()
	hole_at.resize(count)
	var tile_at: Array = []
	tile_at.resize(count)
	var W := {"n": n, "seed": int(P.seed) if int(P.seed) != 0 else 1, "title": P.title, "circle": opts.circles[int(P.circle)], "theme": theme, "boss": P.boss,
		"diff": Core.difficulty_for(n, P, opts.get("diff", {}) if opts.get("diff") is Dictionary else {}), "final": bool(P.get("final", false)), "COLS": cols, "ROWS": rows,
		"grid": grid, "roomAt": room_at, "holeAt": hole_at, "tileAt": tile_at, "rooms": plan.rooms, "doors": [], "props": [], "decals": [], "wallDecor": [], "ents": [],
		"lights": [], "groups": plan.groups, "occupied": {}, "reserved": {}, "sizes": pack.sizes, "tile_names": Core.TILE_NAMES.duplicate(), "areas": {}, "pit_cells": {}, "passages": [], "doorways": []}
	for i in range(count):
		tile_at[i] = Core.floor_tile(i % cols, i / cols, n, theme.hot, false)
	var rnd := Core.Rng.new(int(W.seed) + 4242)
	var by_id := {}
	for i in range(W.rooms.size()):
		var r: Dictionary = W.rooms[i]
		var t: Dictionary = picks[r.id]
		var lo := _low_corner(r.slots)
		r.index = i
		r.doors = []
		r.file = t
		r.sc = lo.x
		r.sr = lo.y
		r.origin = Vector2i(margin, margin) + lo * pitch
		_box_of_floor(r, t)
		r.cleared = r.type != "combat" and r.type != "boss"
		if str(r.gtype) == "jump":
			r.kind = str(t.get("kind_label", "Sprungrätsel"))
			r.info = "Kein Kampf. Sieh dir an, wohin die Platten werfen, bevor du sie betrittst."
		by_id[r.id] = r
		_stamp_cells(W, r, t)
	for spec: Dictionary in plan.doors:
		if not _join(W, by_id[spec.a], by_id[spec.b], spec, cfg):
			return {}
	var gate: Dictionary = {}
	for d: Dictionary in W.doors:
		if d.kind == "lock" and d.get("key", "") == "C" and (d.a.type == "boss" or d.b.type == "boss"):
			gate = d
			break
	if gate.is_empty():
		return {}
	(gate.b if gate.a.type == "boss" else gate.a).gate = gate
	for r: Dictionary in W.rooms:
		r.cells = Core.cells_of(W, r)
		_stamp_objects(W, r, r.file, P, pack, rnd)
		Core._plan_lanes(W, r)
		if r.has("gate"):
			_clear_gate_approach(W, r)
			Core._reserve_gate(W, r)
		_plan_pieces(W, P, r, rnd)
	for r: Dictionary in W.rooms:
		if r.has("gate"):
			Core._dress_boss_gate(W, r)
		_door_banners(W, r)
	Core._place_skull_heaps(W, pack.sizes)
	if n >= 4:
		Core._place_seals(W, P, Core.Rng.new(int(W.seed) + 777), pack.sizes)
	Core._place_levers(W, Core.Rng.new(int(W.seed) + 515))
	_grime(W, Core.Rng.new(Core.f32(float(W.seed) * 7 + 13)))
	for r: Dictionary in W.rooms:
		r.cells = Core.cells_of(W, r)
	W.byId = by_id
	return W


## The room's box on the floor: as tight as its floor, a file may use only part of its slots.
static func _box_of_floor(r: Dictionary, t: Dictionary) -> void:
	var lo := Vector2i(int(t.width), int(t.height))
	var hi := Vector2i(-1, -1)
	var dug := Gates.dug(t)
	for y in range(int(t.height)):
		for x in range(int(t.width)):
			if Data.cell_at(t, x, y) != Data.WALL or dug.has(Vector2i(x, y)):
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	r.bx = int(r.origin.x) + lo.x
	r.by = int(r.origin.y) + lo.y
	r.bw = hi.x - lo.x + 1
	r.bh = hi.y - lo.y + 1


## The file's cells on the floor: ground, mire, bridges, pits, tiles and the wall blocks inside the room.
static func _stamp_cells(W: Dictionary, r: Dictionary, t: Dictionary) -> void:
	var cols: int = W.COLS
	var o: Vector2i = r.origin
	var w := int(t.width)
	var h := int(t.height)
	var dug := Gates.dug(t)
	var outside := _outside_walls(t)
	var own_tile := str(t.get("floor_tile", ""))
	for y in range(h):
		for x in range(w):
			var i := (o.y + y) * cols + o.x + x
			var cell := Data.cell_at(t, x, y)
			if dug.has(Vector2i(x, y)):
				cell = Data.FLOOR
			if cell == Data.WALL:
				W.holeAt[i] = 0 if outside.has(Vector2i(x, y)) else 1
				continue
			W.roomAt[i] = r.index
			match cell:
				Data.FLOOR:
					W.grid[i] = 1
				Data.LIQUID:
					W.grid[i] = 2
					W.occupied[i] = true
				Data.BRIDGE:
					W.grid[i] = 3
					W.occupied[i] = true
				Data.PIT:
					W.grid[i] = 1
					W.pit_cells[i] = true
					W.occupied[i] = true
					W.decals.append({"name": "pit", "x": (o.x + x + 0.5) * C, "y": (o.y + y + 0.5) * C})
					W.ents.append({"type": "pit", "x": (o.x + x + 0.5) * C, "y": (o.y + y + 0.5) * C, "room": int(r.index)})
			W.tileAt[i] = own_tile if own_tile != "" else Core.floor_tile(o.x + x, o.y + y, int(W.n), float(W.theme.hot), true)
	for spot: String in (t.get("tiles", {}) as Dictionary):
		var at := spot.split(",")
		var name := str(t.tiles[spot])
		if not (W.tile_names as Array).has(name):
			W.tile_names.append(name)
		W.tileAt[(o.y + int(at[1])) * cols + o.x + int(at[0])] = name
	for spot: String in (t.get("areas", {}) as Dictionary):
		var at := spot.split(",")
		W.areas[(o.y + int(at[1])) * cols + o.x + int(at[0])] = str(t.areas[spot])
	W.decals.append_array(bridge_decals(t, o))


## The wall cells of a file connected to its border: all others are blocks inside the room.
static func _outside_walls(t: Dictionary) -> Dictionary:
	var w := int(t.width)
	var h := int(t.height)
	var out := {}
	var todo: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if (x == 0 or y == 0 or x == w - 1 or y == h - 1) and Data.cell_at(t, x, y) == Data.WALL:
				out[Vector2i(x, y)] = true
				todo.append(Vector2i(x, y))
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for side: Vector2i in SIDES.values():
			var n := c + side
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and not out.has(n) and Data.cell_at(t, n.x, n.y) == Data.WALL:
				out[n] = true
				todo.append(n)
	return out


## One bridge picture per run of bridge cells of file `t`, lying the long way; `o` is the file's corner.
static func bridge_decals(t: Dictionary, o: Vector2i) -> Array:
	var out: Array = []
	var seen := {}
	for y in range(int(t.height)):
		for x in range(int(t.width)):
			if Data.cell_at(t, x, y) != Data.BRIDGE or seen.has(Vector2i(x, y)):
				continue
			var x1 := x
			var y1 := y
			while Data.cell_at(t, x1 + 1, y) == Data.BRIDGE:
				x1 += 1
			while Data.cell_at(t, x, y1 + 1) == Data.BRIDGE:
				y1 += 1
			for j in range(y, y1 + 1):
				for i in range(x, x1 + 1):
					seen[Vector2i(i, j)] = true
			var w := x1 - x + 1
			var h := y1 - y + 1
			out.append({"name": "bridge_h" if w >= h else "bridge_v", "x": (o.x + x + w / 2.0) * C, "y": (o.y + y + h / 2.0) * C, "w": w * C + 20, "h": h * C + 18, "a": 1.0})
	return out


## The file's parts on the floor. A file's own gates and secret walls belong to its room; their groups
## get the room's number, so two rooms never share one.
static func _stamp_objects(W: Dictionary, r: Dictionary, t: Dictionary, P: Dictionary, pack: RefCounted, rnd: Core.Rng) -> void:
	var o: Vector2i = r.origin
	var off := Vector2(o) * C
	var light_cfg: Dictionary = RoomWorld.Terrain.config().get("lights", {})
	var door_of_group := {}
	_own_gates(W, r, t, door_of_group)
	var placed: Array = []
	for a: Dictionary in t.objects:
		var x := float(a.x) + off.x
		var y := float(a.y) + off.y
		var kind := str(a.kind)
		match kind:
			"start":
				if str(r.gtype) == "start":
					r.spawn = [float(a.x) / C + o.x - int(r.bx), float(a.y) / C + o.y - int(r.by)]
			"prop":
				_stamp_prop(W, a, x, y, light_cfg)
			"enemy":
				if Contents.is_chest_mob(str(a.get("mob", ""))):
					var hiding := Contents.hiding_chest(str(a.mob), x, y)
					hiding.room = int(r.index)
					_put(W, hiding)
				else:
					placed.append({"x": x, "y": y, "mob": str(a.get("mob", ""))})
			"raw":
				var e: Dictionary = (a.ent as Dictionary).duplicate(true)
				e.x = x
				e.y = y
				e.room = int(r.index)
				if str(e.type) == "vault":
					e.tier = _tier(W, r)
				if str(e.get("drop", "")) == "random":
					e.drop = crate_drop(str(e.get("look", "")), rnd.next())
				_put(W, e)
			"chest":
				_stamp_chest(W, r, a, x, y, P, pack, rnd)
			"plate":
				if str(a.get("group", "")) != "seq":
					_put_own(W, r, a, x, y, door_of_group)
			"gate", "secret":
				pass
			"tablet":
				_put_own(W, r, a, x, y, door_of_group)
				_stamp_prop(W, Contents.tablet_prop(a), x, y, light_cfg)
			_:
				_put_own(W, r, a, x, y, door_of_group)
	_set_enemies(r, t, placed)
	for l: Dictionary in t.get("lights", []):
		W.lights.append({"x": float(l.x) + off.x, "y": float(l.y) + off.y, "r": l.r, "c": l.c})
	if str(t.get("floor_tile", "")) != "" and str(r.gtype) == "key":
		r.tidy = true
	if str(r.gtype) == "key":
		for c: Array in r.cells:
			W.reserved[int(c[1]) * int(W.COLS) + int(c[0])] = true


## The room's enemies by the file's choice. By chance: the plan's number, or the file's own count. By
## hand: those set; none set makes a room without a fight. The boss stays the floor's, and a room whose
## fight pays a key or reward keeps its fight, else the floor could not be finished.
static func _set_enemies(r: Dictionary, t: Dictionary, placed: Array) -> void:
	if str(r.type) not in ["combat", "boss"]:
		return
	if Data.spawn_mode(t) != "manual" or str(r.type) == "boss":
		if int(t.get("auto_mobs", 0)) > 0:
			r.mobs = int(t.auto_mobs)
		return
	if not placed.is_empty():
		r.placed_mobs = placed
	elif not r.has("drop") and not r.has("reward") and str(r.gtype) != "shrine":
		r.mobs = 0
		r.cleared = true


## The key id a room's own key and lock use on a floor. A jump puzzle's keys belong to its room ("4A"),
## so they never open the floor's gates A, B and C or count as the floor's keys; every other room's keys
## are the floor's.
static func own_key(r: Dictionary, k: String) -> String:
	return "%d%s" % [int(r.index), k] if str(r.get("gtype", "")) == "jump" and k != "" else k


static func _put(W: Dictionary, e: Dictionary) -> void:
	W.ents.append(e)
	W.occupied[int(floor((float(e.y) - 19.0) / C)) * int(W.COLS) + int(floor(float(e.x) / C))] = true


static func _put_own(W: Dictionary, r: Dictionary, a: Dictionary, x: float, y: float, door_of_group: Dictionary) -> void:
	var e := RoomWorld.ent_of(a, x, y)
	if e.is_empty():
		return
	e.room = int(r.index)
	if e.has("group"):
		e.group = "%d_%s" % [int(r.index), str(e.group)]
	if e.has("wake"):
		e.wake = "%d_%s" % [int(r.index), str(e.wake)]
	if str(e.type) == "key":
		e.key = own_key(r, str(e.key))
	if str(e.type) == "portal":
		e.erase("active")
	if str(e.type) == "skullheap":
		if not door_of_group.has(str(a.get("group", "A"))):
			return
		e.door = door_of_group[str(a.get("group", "A"))]
	_put(W, e)


static func _stamp_prop(W: Dictionary, a: Dictionary, x: float, y: float, light_cfg: Dictionary) -> void:
	var name := str(a.asset)
	var flame: Variant = Core.LIGHT.get(name)
	if bool(a.get("wall_decor", false)):
		var hung := Data.stretch(a)
		var w := {"name": name, "x": x, "y": y - 74.0, "flip": bool(a.get("flip", false)), "sx": hung.x, "sy": hung.y}
		W.wallDecor.append(w)
		if flame != null:
			W.lights.append({"x": x, "y": float(w.y) + 40.0, "r": flame[0], "c": flame[1]})
		return
	if a.has("decal"):
		var d: Dictionary = a.decal
		var flat := Data.stretch(a)
		W.decals.append({"name": name, "x": x, "y": y - float(d.get("dy", 0.0)), "w": d.get("w", 0), "h": d.get("h", 0), "a": d.get("a", 1.0), "sx": flat.x, "sy": flat.y})
		if flame != null:
			W.lights.append({"x": x, "y": y - float(d.get("dy", 0.0)), "r": flame[0], "c": flame[1]})
		return
	var raw := RoomWorld.prop_of(a, x, y)
	var p := {"name": name, "x": x, "y": y, "flip": raw.flip, "layer": "low" if str(a.get("layer", "normal")) == "floor" else "obj"}
	for k: String in Core.OPTIONAL_PROP:
		if raw.has(k):
			p[k] = raw[k]
	if raw.solid != null:
		p.solid = raw.solid
		W.occupied[int(floor((y - 19.0) / C)) * int(W.COLS) + int(floor(x / C))] = true
	W.props.append(p)
	if flame != null:
		var size: Array = (W.sizes as Dictionary).get(name, [64, 64])
		W.lights.append({"x": x, "y": y - float(size[1]) * 0.72, "r": flame[0], "c": flame[1]})
	elif RoomWorld._lit(name, light_cfg):
		W.lights.append({"x": x, "y": y - float(light_cfg.get("height", 50)), "r": int(light_cfg.get("radius", 240)), "c": str((light_cfg.get("colors", {}) as Dictionary).get("krypta", "255,170,80"))})


## A chest with loot "auto" pays what the floor pays in such a room; in a fight room it is there only
## now and then and may bite. Any other chest holds what its file says, or with loot "random" what the
## floor chooses. Its Mimik setting and enemies (room_contents.gd) go over either.
static func _stamp_chest(W: Dictionary, r: Dictionary, a: Dictionary, x: float, y: float, P: Dictionary, pack: RefCounted, rnd: Core.Rng) -> void:
	var loot: Dictionary = a.get("loot", {})
	var e := {"type": "chest", "x": x, "y": y, "room": int(r.index)}
	if str(loot.get("type", "")) != "auto":
		e = RoomWorld.ent_of(a, x, y)
		e.room = int(r.index)
		if (e.loot as Dictionary).has("key"):
			e.loot.key = own_key(r, str(e.loot.key))
		Contents.finish_chest(e, a, int(P.n), rnd.next)
		_put(W, e)
		return
	var n := int(P.n)
	var cfg: Dictionary = pack.pack
	match str(r.gtype):
		"portal":
			e.loot = {"gems": 8 + n, "heart": true}
		"jump":
			e.loot = {"gems": 4 + n, "heart": bool(loot.get("heart", false))}
		"treasure":
			e.loot = {"gems": 6 + n, "heart": true}
			e.mimic = rnd.next() < float(cfg.mimic_treasure)
		"secret", "hidden":
			var tier := _tier(W, r)
			e.loot = {"gems": Core.jround((6 + n) * (1 + (tier - 4) * 0.5)), "heart": tier >= 5}
			e.magic = true
			e.mimic = str(r.gtype) == "secret" and rnd.next() < float(cfg.mimic_treasure)
		_:
			if r.get("seq", false) or rnd.next() >= float(cfg.room_library.get("chest_share", 0.35)):
				return
			if rnd.next() < float(cfg.mimic_fight):
				e.mimic = true
				e.loot = {"gems": 0}
			else:
				e.loot = {"gems": 1 + int(floor(rnd.next() * 2))}
	if not e.get("mimic", true):
		e.erase("mimic")
	Contents.finish_chest(e, a, int(P.n), rnd.next)
	_put(W, e)


## What a crate or urn with drop "random" holds, for `v` from 0 to 1.
static func crate_drop(look: String, v: float) -> String:
	if look.begins_with("crate") and v > 0.72:
		return "undead"
	return "none" if v < 0.45 else ("gem" if v < 0.85 else "heart")


## What guards the plate room pays by: its plate count, else 4.
static func _tier(W: Dictionary, r: Dictionary) -> int:
	return int((W.groups.get("seq", {}) as Dictionary).get("count", 4)) if str(r.gtype) in ["pvault", "hidden"] else 4


## The file's own gates and secret walls, as doors from the room to itself.
static func _own_gates(W: Dictionary, r: Dictionary, t: Dictionary, door_of_group: Dictionary) -> void:
	var o: Vector2i = r.origin
	var own := RoomWorld.new(t)._groups()
	for id: String in own:
		# the plates of group seq are the floor's, see _plan_pieces
		if id != "seq":
			W.groups["%d_%s" % [int(r.index), id]] = own[id]
	for a: Dictionary in t.objects:
		var kind := str(a.kind)
		if kind not in ["gate", "secret"]:
			continue
		var two := Gates.cells(a)
		var cells: Array[Vector2i] = [two[0] + o, two[1] + o]
		var travel := str(a.get("dir", "v"))
		if kind == "gate":
			W.doorways.append({"cells": cells, "dir": travel})
		if kind == "gate" and not Gates.closes(a):
			var m := Gates.middle(a) + Vector2(o) * C
			W.passages.append(_look(a, t).merged({"cx": m.x, "cy": m.y, "dir": travel}))
			continue
		var lock := str(a.get("lock", ""))
		var door_kind := "secret" if kind == "secret" else ("lock" if lock != "" else "puzzle")
		var d := _door_record(r, r, door_kind, cells, travel)
		if door_kind == "lock":
			d.key = own_key(r, lock)
		elif door_kind == "puzzle" or own.has(str(a.get("group", "A"))):
			d.group = "%d_%s" % [int(r.index), str(a.get("group", "A"))]
		if kind == "gate":
			d.merge(_look(a, t))
		for c: Vector2i in cells:
			W.grid[c.y * int(W.COLS) + c.x] = 0 if door_kind == "secret" else 1
		door_of_group[str(a.get("group", "A"))] = W.doors.size()
		W.doors.append(d)
		r.doors.append(d)


## What the game draws for gate `a`: its pictures.
static func _look(a: Dictionary, t: Dictionary) -> Dictionary:
	return {"pictures": {"front": Gates.picture(a, false), "side": Gates.picture(a, true), "open_front": Gates.picture(a, false, true), "open_side": Gates.picture(a, true, true)},
		"art_scale": float(Gates.style_of(a).get("scale", 1.0)), "art_dx": Gates.side_shift(t, a) if not t.is_empty() else 0.0}


static func _door_record(a: Dictionary, b: Dictionary, kind: String, cells: Array[Vector2i], travel: String) -> Dictionary:
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[cells.size() - 1]
	var inside: Dictionary = a
	var d := {"a": a, "b": b, "kind": kind, "cells": cells.map(func(c: Vector2i) -> Array: return [c.x, c.y]), "unlocked": false, "broken": false, "hidden": false, "dir": travel,
		"x0": lo.x, "y0": lo.y, "x1": hi.x, "y1": hi.y, "cx": (lo.x + hi.x + 1) / 2.0 * C, "cy": (lo.y + hi.y + 1) / 2.0 * C}
	d.crackX = ((lo.x * C + 31.0) if int(inside.bx) < lo.x else ((hi.x + 1) * C - 31.0)) if travel == "h" else d.cx
	d.crackY = ((lo.y * C + 37.0) if int(inside.by) < lo.y else ((hi.y + 1) * C - 37.0)) if travel == "v" else d.cy
	return d


## Joins two rooms: a gate in each room's wall and a corridor between. The first room's gate is the
## door the plan means (lock, puzzle, secret, boss seal); the second only closes for a fight.
static func _join(W: Dictionary, A: Dictionary, B: Dictionary, spec: Dictionary, cfg: Dictionary) -> bool:
	var sides := _door_sides(spec)
	var at_a := Vector2i(int(spec.slots[0][0]), int(spec.slots[0][1])) - Vector2i(int(A.sc), int(A.sr))
	var at_b := Vector2i(int(spec.slots[1][0]), int(spec.slots[1][1])) - Vector2i(int(B.sc), int(B.sr))
	var pa: Dictionary = spec.get("port_" + str(A.id), _port_of(A.file, at_a, sides[0], cfg))
	var pb: Dictionary = spec.get("port_" + str(B.id), _port_of(B.file, at_b, sides[1], cfg))
	if pa.is_empty() or pb.is_empty():
		return false
	var travel := "h" if str(sides[0]) in ["east", "west"] else "v"
	var ca := _gate_cells(A, pa, travel)
	var cb := _gate_cells(B, pb, travel)
	var way := _corridor(ca, cb, travel)
	var cols: int = W.COLS
	var own := {}
	for c: Vector2i in way:
		own[c] = true
	for c: Vector2i in ca + cb:
		own[c] = true
	for c: Vector2i in way:
		var i := c.y * cols + c.x
		if int(W.grid[i]) != 0 or int(W.roomAt[i]) >= 0:
			return false
		# a corridor touches nothing but its own gates: no way round a lock
		for side: Vector2i in SIDES.values():
			var n: Vector2i = c + side
			if not own.has(n) and (int(W.grid[n.y * cols + n.x]) != 0 or int(W.roomAt[n.y * cols + n.x]) >= 0):
				return false
	for c: Vector2i in way:
		W.grid[c.y * cols + c.x] = 1
	var kind := str(spec.kind)
	var near := _door_record(A, B, kind, ca, travel)
	if kind == "lock":
		near.key = spec.extra
	if kind == "puzzle" or (kind == "secret" and spec.get("extra") != null):
		near.group = spec.extra
	var far := _door_record(A, B, "open", cb, travel)
	far.far_end = true
	near.corridor = way.map(func(c: Vector2i) -> Array: return [c.x, c.y])
	var style := {"kind": "gate", "style": str(cfg.get("gate_style", "portcullis"))}
	for d: Dictionary in [near, far]:
		d.merge(_look(style, {}))
		var cells: Array[Vector2i] = ca if is_same(d, near) else cb
		for c: Vector2i in cells:
			W.grid[c.y * cols + c.x] = 0 if str(d.kind) == "secret" else 1
		if str(d.kind) != "secret":
			W.doorways.append({"cells": cells, "dir": travel})
		W.doors.append(d)
	A.doors.append(near)
	B.doors.append(far)
	return true


## A port's two cells on the floor.
static func _gate_cells(r: Dictionary, p: Dictionary, travel: String) -> Array[Vector2i]:
	var c := Vector2i(int(p.cell[0]), int(p.cell[1])) + (r.origin as Vector2i)
	return [c, c + (Vector2i(0, 1) if travel == "h" else Vector2i(1, 0))]


## The cells of the two-wide way between two gates: straight when they face each other, else with one
## bend right behind the first gate.
static func _corridor(a: Array[Vector2i], b: Array[Vector2i], travel: String) -> Array[Vector2i]:
	var out := {}
	if travel == "h":
		var left := a if a[0].x < b[0].x else b
		var right := b if a[0].x < b[0].x else a
		var leg := left[0].x + 1
		for k: int in [0, 1]:
			for x in range(left[0].x + 1, leg + 2):
				out[Vector2i(x, left[k].y)] = true
			for x in range(leg, right[0].x):
				out[Vector2i(x, right[k].y)] = true
		for y in range(mini(left[0].y, right[0].y), maxi(left[1].y, right[1].y) + 1):
			out[Vector2i(leg, y)] = true
			out[Vector2i(leg + 1, y)] = true
	else:
		var top := a if a[0].y < b[0].y else b
		var bottom := b if a[0].y < b[0].y else a
		var leg := top[0].y + 1
		for k: int in [0, 1]:
			for y in range(top[0].y + 1, leg + 2):
				out[Vector2i(top[k].x, y)] = true
			for y in range(leg, bottom[0].y):
				out[Vector2i(bottom[k].x, y)] = true
		for x in range(mini(top[0].x, bottom[0].x), maxi(top[1].x, bottom[1].x) + 1):
			out[Vector2i(x, leg)] = true
			out[Vector2i(x, leg + 1)] = true
	var cells: Array[Vector2i] = []
	cells.assign(out.keys())
	return cells


## The boss gate's approach belongs to its dressing: what the file has standing there goes.
static func _clear_gate_approach(W: Dictionary, r: Dictionary) -> void:
	var d: Dictionary = r.gate
	var gx: float = float(d.cx) / C
	var top: int = int(d.y1) + 1
	var box := Rect2((gx - 4.6) * C, top * C - 2.0 * C, 9.2 * C, 6.0 * C)
	var outside := func(p: Dictionary) -> bool: return not box.has_point(Vector2(float(p.x), float(p.y)))
	W.props = (W.props as Array).filter(outside)
	W.wallDecor = (W.wallDecor as Array).filter(func(w: Dictionary) -> bool: return not box.has_point(Vector2(float(w.x), float(w.y) + 74.0)))
	W.decals = (W.decals as Array).filter(func(p: Dictionary) -> bool: return str(p.name) == "pit" or outside.call(p))
	W.ents = (W.ents as Array).filter(func(e: Dictionary) -> bool: return int(e.room) != int(r.index) or outside.call(e))


## Banners beside each north door of the room, as on generated floors (the boss gate has its own).
static func _door_banners(W: Dictionary, r: Dictionary) -> void:
	var cols: int = W.COLS
	var banner: String = Core.BANNERS[(int(r.index) + int(W.n)) % Core.BANNERS.size()]
	for d: Dictionary in r.doors:
		if (r.has("gate") and is_same(d, r.gate)) or str(d.dir) != "v" or is_same(d.a, d.b):
			continue
		var y := int(d.y1) + 1
		if Core._room_at(W, y * cols + int(d.x0)) != int(r.index):
			continue
		for s: float in [-1.9, 1.9]:
			var x: float = float(d.cx) / C + s
			var i := int(floor(x))
			if Core._room_at(W, y * cols + i) == int(r.index) and Core._room_at(W, (y - 1) * cols + i) != int(r.index):
				W.wallDecor.append({"name": banner, "x": x * C, "y": y * C - 68.0, "flip": s > 0.0})


## What the plan puts into a room: the floor's plates, a soul bowl, a shrine's heart, the final altar.
static func _plan_pieces(W: Dictionary, P: Dictionary, r: Dictionary, rnd: Core.Rng) -> void:
	var t: Dictionary = r.file
	var o: Vector2i = r.origin
	var cols: int = W.COLS
	if r.get("seq", false):
		var seq: Array = W.groups.seq.sequence
		var plates := _plates_of(t)
		var chosen: Array = PLATE_PICK[seq.size()].map(func(k: int) -> Dictionary: return plates[k])
		for k in range(chosen.size()):
			var p: Dictionary = chosen[k]
			var x := float(p.x) + o.x * C
			var y := float(p.y) + o.y * C
			W.ents.append({"type": "plate", "x": x, "y": y, "room": int(r.index), "group": "seq", "pos": k + 1, "order": seq.find(k + 1) + 1, "on": false})
			var cx := int(floor(x / C))
			var cy := int(floor(y / C))
			for j in range(-1, 2):
				for i in range(-1, 2):
					W.occupied[(cy + j) * cols + cx + i] = true
					W.reserved[(cy + j) * cols + cx + i] = true
	var cx: float = float(r.center[0]) - int(r.bx)
	var cy: float = float(r.center[1]) - int(r.by)
	if str(r.gtype) == "shrine":
		Core.decal(W, r, "fire_plate", cx + 0.5, cy + 0.9)
		Core.ent(W, r, {"type": "heart", "cx": cx + 0.5, "cy": cy + 1.0})
	if r.get("fireBrazier", false):
		var edge: Array = (r.cells as Array).filter(func(c: Array) -> bool:
			var k: int = int(c[1]) * cols + int(c[0])
			return Core._grid(W, k) == 1 and not W.occupied.has(k) and (Core._room_at(W, k - cols) != int(r.index) or Core._room_at(W, k - 1) != int(r.index) or Core._room_at(W, k + 1) != int(r.index)) \
				and not Core.near_door(r, c[0] + 0.5, c[1] + 0.5, 3) and not _beside_use(W, r, c))
		var spot: Array = edge[int(floor(rnd.next() * edge.size()))] if not edge.is_empty() else [int(r.center[0]) + 2, int(r.center[1])]
		Core.ent(W, r, {"type": "brazier", "cx": int(spot[0]) - int(r.bx) + 0.5, "cy": int(spot[1]) - int(r.by) + 0.75, "group": "feuer", "lit": false})
	if str(r.gtype) == "boss" and P.get("final", false):
		Core.prop(W, r, W.sizes, "altar", cx + 0.5, 2.5)


## True when a thing to use stands within two cells of cell `c`: a soul bowl there could wall it in.
static func _beside_use(W: Dictionary, r: Dictionary, c: Array) -> bool:
	for e: Dictionary in W.ents:
		if int(e.room) == int(r.index) and Core.USE.has(str(e.type)) and Vector2(float(e.x), float(e.y) - 10.0).distance_to(Vector2(float(c[0]) + 0.5, float(c[1]) + 0.5) * C) < 2.0 * C:
			return true
	return false


## Now and then blood and moss on free floor; deeper floors a little more blood.
static func _grime(W: Dictionary, rnd: Core.Rng) -> void:
	var cols: int = W.COLS
	var blood := 0.005 + int(W.n) * 0.0012
	var pick := func(list: Array) -> Variant: return list[int(floor(rnd.next() * list.size()))]
	for r: Dictionary in W.rooms:
		for c: Array in r.cells:
			var k: int = int(c[1]) * cols + int(c[0])
			if Core._grid(W, k) != 1 or W.reserved.has(k):
				continue
			var v := rnd.next()
			if v < blood:
				W.decals.append({"name": pick.call(["blood_a", "blood_b", "blood_c", "blood_d", "blood_e", "blood_f"]), "x": (c[0] + 0.5) * C, "y": (c[1] + 0.5) * C, "a": 0.92})
			elif v < blood + 0.012:
				W.decals.append({"name": pick.call(["moss_a", "moss_b", "moss_c"]), "x": (c[0] + 0.5) * C, "y": (c[1] + 0.5) * C, "a": 0.95})

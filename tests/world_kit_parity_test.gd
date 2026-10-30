extends SceneTree
## The world kit in Godot builds exactly the floors of the browser preview: for the run numbers in
## tests/data/world_kit_reference.json (the crypt), world_kit_reference_hell.json (the hell) and
## world_kit_reference_frost.json (the Frostgruft),
## written by tools/world_kit/dump_floors.js from the JS generator and packs,
## src/world_kit/world_core.gd with src/world_kit/world_pack.gd must give the same
## grid, rooms, doors, entities, props, decals, wall decor and lights. Also checks the 32-bit
## helpers against known JS values.

const Core = preload("res://src/world_kit/world_core.gd")
const Pack = preload("res://src/world_kit/world_pack.gd")
## [reference floors, world pack, sprite manifest] per world
const WORLDS := [
	["res://tests/data/world_kit_reference.json", "res://assets/data/krypta_world.json", "res://assets/sprites/krypta/manifest.json"],
	["res://tests/data/world_kit_reference_hell.json", "res://assets/data/hell_world.json", "res://assets/sprites/hell/manifest.json"],
	["res://tests/data/world_kit_reference_frost.json", "res://assets/data/frost_world.json", "res://assets/sprites/frost_hd/manifest.json"],
]
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("WORLD_KIT_PARITY_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# mulberry32(1): first values of the JS generator
	var rng := Core.Rng.new(1)
	check(absf(rng.next() - 0.6270739405881613) < 1e-12, "mulberry32(1) first value")
	check(absf(Core.hash3(3, 4, 5) - 0.5985523597337306) < 1e-12, "hash(3, 4, 5)")
	check(absf(Core.hash3(7.35, 12.6, 9) - 0.43380333785898983) < 1e-12, "hash(7.35, 12.6, 9) with fractions")
	for world: Array in WORLDS:
		_check_world(world[0], world[1], world[2])
	print("WORLD_KIT_PARITY checked=%d failed=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _check_world(reference: String, pack_path: String, manifest: String) -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(reference))
	var pack := Pack.new(pack_path, manifest)
	var world := pack_path.get_file().get_basename()
	for f: Dictionary in ref.floors:
		var tag := "%s run %d E%d" % [world, int(f.run), int(f.n)]
		var W := Core.build_floor(int(f.n), pack.sizes, pack.for_run(int(f.run)))
		pack.dress(W)
		check(int(W.seed) == int(f.seed), tag + " seed %d vs %d" % [int(W.seed), int(f.seed)])
		var grid := ""
		for v: int in W.grid:
			grid += str(v)
		check(grid == f.grid, tag + " grid")
		check(",".join(W.tileAt) == f.tiles, tag + " floor tiles")
		_same_list(tag + " rooms", W.rooms.map(func(r: Dictionary) -> Array: return [r.id, r.type, r.gtype, r.bx, r.by, r.bw, r.bh, r.name]), f.rooms)
		_same_list(tag + " doors", W.doors.map(func(d: Dictionary) -> Array: return [d.a.index, d.b.index, d.kind, d.get("key", ""), d.get("group", ""), d.x0, d.y0]), f.doors)
		check(_groups_equal(W.groups, f.groups), tag + " groups")
		_same_list(tag + " entities", W.ents.map(func(e: Dictionary) -> Array: return [e.type, Core._r1(e.x), Core._r1(e.y), e.room]), f.ents)
		_same_list(tag + " props", W.props.map(func(p: Dictionary) -> Array: return [p.name, Core._r1(p.x), Core._r1(p.y)]), f.props)
		_same_list(tag + " decals", W.decals.map(func(d: Dictionary) -> Array: return [d.name, Core._r1(d.x), Core._r1(d.y)]), f.decals)
		_same_list(tag + " wall decor", W.wallDecor.map(func(w: Dictionary) -> Array: return [w.name, Core._r1(w.x), Core._r1(w.y)]), f.wall)
		_same_list(tag + " lights", W.lights.map(func(l: Dictionary) -> Array: return [Core._r1(l.x), Core._r1(l.y), l.c]), f.lights)


func _same_list(tag: String, mine: Array, theirs: Array) -> void:
	if mine.size() != theirs.size():
		check(false, "%s: %d vs %d" % [tag, mine.size(), theirs.size()])
		for i in range(mini(mine.size(), theirs.size())):
			if not _same(mine[i], theirs[i]):
				printerr("  first difference at ", i, ": ", mine[i], " vs ", theirs[i])
				break
		return
	for i in range(mine.size()):
		if not _same(mine[i], theirs[i]):
			check(false, "%s #%d: %s vs %s" % [tag, i, str(mine[i]), str(theirs[i])])
			return
	check(true, tag)


func _same(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _same(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.051
	return str(a) == str(b)


func _groups_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: String in a:
		if not b.has(k):
			return false
		for f: String in a[k]:
			if not _same(a[k][f], b[k].get(f)) and str(a[k][f]) != str(b[k].get(f)):
				return false
	return true



extends RefCounted
## A world on the world kit (Story 1 the crypt, Story 3 the hell): the GDScript port of
## tools/world_kit/world_pack.js. Floors, names, wording, dressing tables and colours come from the
## world's pack JSON (assets/data/krypta_world.json, assets/data/hell_world.json, written from the JS
## by tools/krypta_dungeon/export_world.js and tools/hell_dungeon/export_world.js).
##
## A run: one run number decides all ten floors; each floor's layout seed is derived from it, so
## the same run number always rebuilds the same world (saves), a new one gives new layouts.

const Core = preload("res://src/world_kit/world_core.gd")
const PACK_PATH := "res://assets/data/krypta_world.json"
const C := 96.0

var pack: Dictionary = {}
var sizes: Dictionary = {}


## pack_path: the world pack JSON; sprite_manifest: the skin's manifest.json (sprite sizes).
func _init(pack_path: String = PACK_PATH, sprite_manifest: String = "") -> void:
	pack = JSON.parse_string(FileAccess.get_file_as_string(pack_path))
	if sprite_manifest != "" and FileAccess.file_exists(sprite_manifest):
		var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sprite_manifest))
		for k: String in man:
			sizes[k] = [int(man[k].w), int(man[k].h)]


## Number of floors of the world.
func floor_count() -> int:
	return pack.floors.size() - 1


## A new random run number (1 .. 2^31-1).
static func new_run() -> int:
	return randi_range(1, 2147483646)


## The layout seed of floor n in a run (same as floorSeed in the JS).
static func floor_seed(run: int, n: int) -> int:
	var h := Core.i32(Core.imul(Core.i32(run), Core.i32(2654435761)) ^ Core.imul(n, 40503)) & 0xFFFFFFFF
	h = Core.imul(Core.i32(h ^ (h >> 16)), Core.i32(2246822507)) & 0xFFFFFFFF
	h = Core.imul(Core.i32(h ^ (h >> 13)), Core.i32(3266489909)) & 0xFFFFFFFF
	var v := ((h ^ (h >> 16)) & 0xFFFFFFFF) % 2147483647
	return v if v != 0 else 1


## The generator options of a run: the pack's floors with their run seeds.
func for_run(run: int) -> Dictionary:
	var floors: Array = []
	for P: Variant in pack.floors:
		if P == null:
			floors.append(null)
			continue
		var f: Dictionary = (P as Dictionary).duplicate(true)
		f.n = int(f.n)
		f.seed = floor_seed(run, int(f.n))
		floors.append(f)
	return {"floors": floors, "circles": pack.circles, "names": pack.names, "suffixes": pack.suffixes}


## Floor n of a run, dressed, in the runtime schema (src/hell/hell_floor_data.gd).
func build_raw(n: int, run: int) -> Dictionary:
	var W := Core.build_floor(n, sizes, for_run(run))
	dress(W)
	var raw := Core.to_raw(W)
	raw.run = run
	return raw


## The generator's wording in the world's terms (pack.words, longest first).
func wording(text: String) -> String:
	for pair: Array in pack.get("words", []):
		text = text.replace(pair[0], pair[1])
	return text


## The world's touches on a built floor (the dress() of the JS).
func dress(W: Dictionary) -> Dictionary:
	_straighten_bridges(W)
	for r: Dictionary in W.rooms:
		r.name = wording(r.name)
		r.kind = wording(r.kind)
		r.info = wording(r.get("info", ""))
	for g: Dictionary in W.groups.values():
		if g.has("label"):
			g.label = wording(g.label)
	if pack.get("theme_flag") != null:
		W.theme[str(pack.theme_flag)] = true
	# a world lighter or darker than the hell
	if pack.get("light") != null:
		W.theme.dark = float(W.theme.dark) * float(pack.light.dark)
		W.theme.vignette = float(W.theme.vignette) * float(pack.light.vignette)
	_boss_gate(W)
	_decorate(W)
	if pack.get("winter") != null:
		_winter(W)
	_tidy(W)
	_blue_light(W)
	# last: mire, pits, furniture and fountain never block a way (world kit rule)
	Core.clear_ways(W)
	return W


## Each connected bridge becomes one straight crossing, two cells wide, across the full river,
## where both banks are floor; the rest of the piece turns back into mire.
func _straighten_bridges(W: Dictionary) -> void:
	var cols: int = W.COLS
	var g := func(x: int, y: int) -> int: return Core._grid(W, y * cols + x)
	var seen := {}
	var boxes: Array = []
	for i in range(W.grid.size()):
		if W.grid[i] != 3 or seen.has(i):
			continue
		var todo: Array = [i]
		seen[i] = true
		var x0 := 1 << 30
		var y0 := 1 << 30
		var x1 := -1
		var y1 := -1
		while not todo.is_empty():
			var k: int = todo.pop_back()
			var x := k % cols
			var y := k / cols
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
			for nd: Array in Core.N4:
				var nb: int = (y + nd[1]) * cols + x + nd[0]
				if Core._grid(W, nb) == 3 and not seen.has(nb):
					seen[nb] = true
					todo.append(nb)
		boxes.append([x0, y0, x1, y1])
	var in_box := func(d: Dictionary, b: Array) -> bool:
		return float(d.x) >= b[0] * C and float(d.x) <= (b[2] + 1) * C and float(d.y) >= b[1] * C and float(d.y) <= (b[3] + 1) * C
	var water := func(x: int, y: int) -> bool: return g.call(x, y) == 2 or g.call(x, y) == 3
	for b: Array in boxes:
		var old: Array = W.decals.filter(func(d: Dictionary) -> bool: return str(d.name).begins_with("bridge") and in_box.call(d, b))
		if old.is_empty():
			continue
		var across: bool = old[0].name == "bridge_h"
		var x0: int = b[0]
		var y0: int = b[1]
		var x1: int = b[2]
		var y1: int = b[3]
		if across:
			while water.call(x0 - 1, y0):
				x0 -= 1
			while water.call(x1 + 1, y0):
				x1 += 1
		else:
			while water.call(x0, y0 - 1):
				y0 -= 1
			while water.call(x0, y1 + 1):
				y1 += 1
		var a0 := y0 if across else x0
		var a1 := y1 if across else x1
		var mid := (a0 + a1) / 2.0
		var bank := func(s: int) -> bool:
			for t in [s, s + 1]:
				if across:
					if not (g.call(x0 - 1, t) == 1 and g.call(x1 + 1, t) == 1):
						return false
				elif not (g.call(t, y0 - 1) == 1 and g.call(t, y1 + 1) == 1):
					return false
			return true
		var best: Variant = null
		for s in range(a0 - 1, a1 + 1):
			if bank.call(s) and (best == null or absf(s + 0.5 - mid) < absf(int(best) + 0.5 - mid)):
				best = s
		if best == null:
			best = maxi(a0, mini(a1 - 1, Core.jround(mid - 0.5)))
		var bi: int = best
		for y in range(b[1], b[3] + 1):
			for x in range(b[0], b[2] + 1):
				var along := y if across else x
				if g.call(x, y) == 3 and along != bi and along != bi + 1:
					W.grid[y * cols + x] = 2
		var bx0 := x0 if across else bi
		var bx1 := x1 if across else bi + 1
		var by0 := bi if across else y0
		var by1 := bi + 1 if across else y1
		for y in range(by0, by1 + 1):
			for x in range(bx0, bx1 + 1):
				if water.call(x, y):
					W.grid[y * cols + x] = 3
					W.occupied[y * cols + x] = true
		W.decals = W.decals.filter(func(d: Dictionary) -> bool: return Core.index_of(old, d) < 0)
		W.decals.append({"name": old[0].name, "x": (bx0 + bx1 + 1) / 2.0 * C, "y": (by0 + by1 + 1) / 2.0 * C, "w": (bx1 - bx0 + 1) * C + 20, "h": (by1 - by0 + 1) * C + 18})


## Banners in the floor's colour (boss gate and rooms); floor 10 burns blue at the gate and in the
## boss room, with a ring of blue fire bowls around the final arena.
func _boss_gate(W: Dictionary) -> void:
	var colour := str(pack.gate_banner.get(str(W.n), ""))
	var floor_banner := "boss_banner_" + colour if colour != "" else "boss_banner"
	for w: Dictionary in W.wallDecor:
		if w.name == "boss_banner" or str(w.name).begins_with("banner_"):
			w.name = floor_banner
	if int(W.n) != 10:
		return
	var blue: String = pack.blue
	var gate_room: Variant = null
	var boss: Dictionary = {}
	for r: Dictionary in W.rooms:
		if r.has("gate") and gate_room == null:
			gate_room = r
		if r.type == "boss" and boss.is_empty():
			boss = r
	var near_gate := func(x: float, y: float) -> bool:
		return gate_room != null and absf(x - float(gate_room.gate.cx)) < 4 * C and absf(y - (int(gate_room.gate.y1) + 1) * C) < 2 * C
	var in_boss := func(x: float, y: float) -> bool:
		return x >= int(boss.bx) * C - C and x <= (int(boss.bx) + int(boss.bw) + 1) * C and y >= int(boss.by) * C - C and y <= (int(boss.by) + int(boss.bh) + 1) * C
	for w: Dictionary in W.wallDecor:
		if w.name == "wall_torch_hook" and (near_gate.call(float(w.x), float(w.y) + 70) or in_boss.call(float(w.x), float(w.y))):
			w.name = "wall_torch_blue"
	for p: Dictionary in W.props:
		if in_boss.call(float(p.x), float(p.y)) and str(p.name).begins_with("brazier"):
			p.name = "brazier_blue"
	for l: Dictionary in W.lights:
		if near_gate.call(float(l.x), float(l.y)) or in_boss.call(float(l.x), float(l.y)):
			l.c = blue
	var cols: int = W.COLS
	var cx: float = int(boss.bx) + int(boss.bw) / 2.0
	var cy: float = int(boss.by) + int(boss.bh) / 2.0
	for k in range(8):
		var a := k / 8.0 * PI * 2 + PI / 8
		var x := int(floor(cx + cos(a) * int(boss.bw) * 0.36))
		var y := int(floor(cy + sin(a) * int(boss.bh) * 0.36))
		var i := y * cols + x
		if Core._room_at(W, i) != int(boss.index) or Core._grid(W, i) != 1 or W.occupied.has(i):
			continue
		var px := (x + 0.5) * C
		var py := (y + 0.9) * C
		W.props.append({"name": "brazier_blue", "x": px, "y": py, "flip": false, "layer": "obj", "solid": [px - 30, py - 30, px + 30, py]})
		W.occupied[i] = true
		W.lights.append({"x": px, "y": py - 70, "r": 330, "c": blue, "f": k})


## Decoration props the tidy rule may take away (the JS TIDY).
const TIDY := ["skull_pile", "spires_t", "spire_mid", "rocks_a", "rocks_b", "coal_skulls", "boulders", "cage_small", "spire_big", "spire_big_b",
	"spire_big_t", "spires_lava", "rocks_lava", "rocks_dark", "spire_small", "spire_t", "skull_obelisk", "rune_pillar_a", "rune_pillar_b", "rune_pillar_c",
	"rune_pillar_d", "obelisk", "bone_a", "bone_b", "bone_c", "bone_d", "bone_e", "bone_f", "bone_g", "bones_scatter", "bones_t", "rubble", "coal",
	"skull_pile_t", "brazier_bowl", "brazier_pillar", "brazier_rune", "brazier_low", "brazier_low_b", "brazier_floor", "brazier_demon",
	"table_a", "table_b", "table_c", "candelabra", "crate_pile", "sacks_b", "moss_rubble_a", "moss_rubble_b", "moss_ruin", "snowman", "glacier_a", "glacier_b"]
## Feet of the things on the floor [width, depth] (the JS ENT_FOOT).
const ENT_FOOT := {"chest": [80, 32], "crate": [60, 30], "brazier": [56, 30], "vault": [140, 50], "well": [112, 44], "stairs": [140, 50], "plate": [84, 84],
	"spikes": [96, 96], "vent": [96, 96], "key": [40, 30], "heart": [40, 30], "gem": [40, 30], "skullheap": [92, 40], "seal": [70, 40], "npc": [40, 30],
	"portal": [144, 40], "shop": [150, 44]}


## Nothing overlaps (world kit rule, the JS tidy()): a decoration prop whose lower part reaches into
## a wall, whose foot sits on the edge of a south wall, or whose foot overlaps another prop's foot
## or a thing on the floor is taken away, its light with it; key rooms and the boss gate's approach
## keep their furniture.
func _tidy(W: Dictionary) -> void:
	var cols: int = W.COLS
	var sizes: Dictionary = W.get("sizes", {})
	var size_of := func(name: String) -> Array: return sizes.get(name, [64, 64])
	var hit := func(a: Array, b: Array) -> bool: return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]
	var foot := func(p: Dictionary) -> Array:
		var s: Array = size_of.call(str(p.name))
		var w := float(s[0]) * 0.84
		var h := minf(float(s[1]) * 0.45, 60.0)
		return [float(p.x) - w / 2, float(p.y) - h, float(p.x) + w / 2, float(p.y)]
	var cell_of := func(p: Dictionary) -> int: return int(floor((float(p.y) - 8) / C)) * cols + int(floor(float(p.x) / C))
	var spared := func(p: Dictionary) -> bool:
		var ri := Core._room_at(W, cell_of.call(p))
		return not (str(p.name) in TIDY) or ri < 0 or W.rooms[ri].gtype == "key" or W.reserved.has(cell_of.call(p))
	var in_wall := func(p: Dictionary) -> bool:
		var s: Array = size_of.call(str(p.name))
		var ri := Core._room_at(W, cell_of.call(p))
		var x0 := float(p.x) - float(s[0]) * 0.42
		var x1 := float(p.x) + float(s[0]) * 0.42
		var y0 := float(p.y) - float(s[1]) * 0.6
		var y1 := float(p.y) + 0.25 * C
		for y in range(int(floor(y0 / C)), int(floor(y1 / C)) + 1):
			for x in range(int(floor(x0 / C)), int(floor(x1 / C)) + 1):
				var k := y * cols + x
				if Core._grid(W, k) == 0 or Core._room_at(W, k) != ri:
					return true
		return false
	var taken: Array = []
	for e: Dictionary in W.ents:
		if ENT_FOOT.has(str(e.type)):
			var f: Array = ENT_FOOT[str(e.type)]
			taken.append([float(e.x) - float(f[0]) / 2, float(e.y) - float(f[1]), float(e.x) + float(f[0]) / 2, float(e.y)])
	for d: Dictionary in W.decals:
		if d.name == "pit":
			taken.append([float(d.x) - C / 2, float(d.y) - C / 2, float(d.x) + C / 2, float(d.y) + C / 2])
	for p: Dictionary in W.props:
		if spared.call(p):
			taken.append(foot.call(p))
	var gone: Array = []
	for p: Dictionary in W.props:
		if spared.call(p):
			continue
		var f: Array = foot.call(p)
		var clash: bool = in_wall.call(p)
		if not clash:
			for t: Array in taken:
				if hit.call(f, t):
					clash = true
					break
		if clash:
			gone.append(p)
		else:
			taken.append(f)
	if gone.is_empty():
		return
	W.lights = W.lights.filter(func(l: Dictionary) -> bool:
		for p: Dictionary in gone:
			if absf(float(l.x) - float(p.x)) < 2 and float(l.y) < float(p.y):
				return false
		return true)
	W.props = W.props.filter(func(p: Dictionary) -> bool: return Core.index_of(gone, p) < 0)


## A snowy world (pack.winter, the JS winter()): the floor itself is snow; fewer bones and stone
## heaps, the snow melted to the stone floor around every burning prop, here and there a snowman or
## a glacier.
func _winter(W: Dictionary) -> void:
	var cols: int = W.COLS
	var P: Dictionary = pack.winter
	var rnd := Core.Rng.new(Core.f32(float(W.seed) * 11 + 5))
	var pick := func(list: Array) -> Variant: return list[int(floor(rnd.next() * list.size()))]
	# fewer bones and heaps
	var thin_d: Dictionary = P.thin_decals
	var thin_p: Dictionary = P.thin_props
	W.decals = W.decals.filter(func(d: Dictionary) -> bool: return not (str(d.name) in thin_d.names) or rnd.next() < float(thin_d.keep))
	W.props = W.props.filter(func(p: Dictionary) -> bool: return not (str(p.name) in thin_p.names) or rnd.next() < float(thin_p.keep))
	# fire melts the snow around it down to the stone floor
	for p: Dictionary in W.props.duplicate():
		if str(p.name) in P.thaw_props:
			W.decals.append({"name": pick.call(P.thaw), "x": float(p.x), "y": float(p.y) - 24, "w": P.thaw_size, "h": P.thaw_size, "a": 1})
	for r: Dictionary in W.rooms:
		var cells: Array = r.cells.filter(func(c: Array) -> bool:
			var k: int = c[1] * cols + c[0]
			return Core._grid(W, k) == 1 and not W.reserved.has(k))
		if cells.is_empty():
			continue
		# a snowman or a glacier in some fight rooms, on free floor away from the doors
		if r.type != "combat":
			continue
		for pair: Array in [["snowman", P.snowman], [pick.call(P.glaciers), P.glacier]]:
			if rnd.next() >= float(pair[1]):
				continue
			var spots: Array = cells.filter(func(c: Array) -> bool:
				if W.occupied.has(c[1] * cols + c[0]):
					return false
				for d: Dictionary in r.doors:
					if Core._hyp((c[0] + 0.5) * C - float(d.cx), (c[1] + 0.5) * C - float(d.cy)) < 3 * C:
						return false
				for p: Dictionary in W.props:
					if p.has("solid") and p.solid != null and Core._hyp(float(p.x) - (c[0] + 0.5) * C, float(p.y) - (c[1] + 0.9) * C) < 1.6 * C:
						return false
				return true)
			if spots.is_empty():
				continue
			var c: Array = spots[int(floor(rnd.next() * spots.size()))]
			var name: String = pair[0]
			var f: Array = pack.foot[name]
			var px: float = (c[0] + 0.5) * C
			var py: float = (c[1] + 0.92) * C
			W.props.append({"name": name, "x": px, "y": py, "flip": rnd.next() < 0.5, "layer": "obj", "solid": [px - float(f[0]) / 2, py - float(f[1]), px + float(f[0]) / 2, py]})
			W.occupied[c[1] * cols + c[0]] = true


## Every blue fire bowl of the world (pack.blue_props) gives the same faint blue.
func _blue_light(W: Dictionary) -> void:
	for p: Dictionary in W.props:
		if p.name in pack.blue_props:
			for l: Dictionary in W.lights:
				if absf(float(l.x) - float(p.x)) < 2 and float(l.y) < float(p.y):
					l.c = pack.blue


## Now and then blood and moss on the floor, furniture against the north walls, breakable urns,
## barrels and crates along the walls, and chests in fight rooms that may be mimics.
func _decorate(W: Dictionary) -> void:
	var cols: int = W.COLS
	var rnd := Core.Rng.new(Core.f32(float(W.seed) * 7 + 13))
	var pick := func(list: Array) -> Variant: return list[int(floor(rnd.next() * list.size()))]
	var foot: Dictionary = pack.foot
	var in_room := func(r: Dictionary, x: int, y: int) -> bool: return Core._room_at(W, y * cols + x) == int(r.index)
	var near := func(r: Dictionary, x: int, y: int, d: float) -> bool:
		for dd: Dictionary in r.doors:
			if Core._hyp((x + 0.5) * C - float(dd.cx), (y + 0.5) * C - float(dd.cy)) < d * C:
				return true
		return false
	var free := func(r: Dictionary, x: int, y: int) -> bool:
		var k := y * cols + x
		return in_room.call(r, x, y) and Core._grid(W, k) == 1 and not W.occupied.has(k) and not W.reserved.has(k)
	var solid_near := func(x: int, y: int, d: float) -> bool:
		for p: Dictionary in W.props:
			if p.has("solid") and Core._hyp(float(p.x) - (x + 0.5) * C, float(p.y) - (y + 0.9) * C) < d * C:
				return true
		for e: Dictionary in W.ents:
			if (e.type == "crate" or e.type == "chest") and Core._hyp(float(e.x) - (x + 0.5) * C, float(e.y) - (y + 0.85) * C) < d * C:
				return true
		return false
	var put := func(name: String, x: int, y: int, flip: bool) -> void:
		var f: Array = foot[name]
		var px: float = (x + (1.0 if int(f[2]) == 2 else 0.5)) * C
		var py: float = (y + 0.92) * C
		W.props.append({"name": name, "x": px, "y": py, "flip": flip, "layer": "obj", "solid": [px - float(f[0]) / 2, py - float(f[1]), px + float(f[0]) / 2, py]})
		for k in range(int(f[2])):
			W.occupied[y * cols + x + k] = true
		if name == "candelabra":
			W.lights.append({"x": px, "y": py - 100, "r": 210, "c": "255,190,110", "f": x})
	var place := func(o: Dictionary, r: Dictionary, x: int, y: int) -> Dictionary:
		o.x = (x + 0.5) * C
		o.y = (y + 0.85) * C
		o.room = int(r.index)
		W.ents.append(o)
		W.occupied[y * cols + x] = true
		return o
	var blood := 0.005 + int(W.n) * 0.0012
	for r: Dictionary in W.rooms:
		# floor: now and then blood (a little more on deeper floors) or moss
		for c: Array in r.cells:
			var k: int = c[1] * cols + c[0]
			if Core._grid(W, k) != 1 or W.reserved.has(k):
				continue
			var edge: bool = not in_room.call(r, c[0] - 1, c[1]) or not in_room.call(r, c[0] + 1, c[1]) or not in_room.call(r, c[0], c[1] - 1) or not in_room.call(r, c[0], c[1] + 1)
			var v := rnd.next()
			if v < blood:
				W.decals.append({"name": pick.call(["blood_a", "blood_b", "blood_c", "blood_d", "blood_e", "blood_f"]), "x": (c[0] + 0.5) * C, "y": (c[1] + 0.5) * C, "a": 0.92})
			elif v < blood + (0.045 if edge else 0.01):
				W.decals.append({"name": pick.call(["moss_a", "moss_b", "moss_c"]), "x": (c[0] + 0.5) * C, "y": (c[1] + 0.5) * C, "a": 0.95})
		if not (r.type in ["combat", "start", "treasure", "portal"]) or r.gtype == "key":
			continue
		var big: int = r.slots.size()
		# furniture against the north wall
		var north: Array = r.cells.filter(func(c: Array) -> bool: return free.call(r, c[0], c[1]) and not in_room.call(r, c[0], c[1] - 1) and not near.call(r, c[0], c[1], 2.6))
		var n := Core.jround(big * 1.1 + rnd.next())
		var k := 0
		while k < n and not north.is_empty():
			k += 1
			var c: Array = north.pop_at(int(floor(rnd.next() * north.size())))
			var name: String = pick.call(pack.wall_set)
			if not free.call(r, c[0], c[1]) or solid_near.call(c[0], c[1], 1.6):
				continue
			if int(foot[name][2]) == 2 and not (free.call(r, c[0] + 1, c[1]) and not in_room.call(r, c[0] + 1, c[1] - 1)):
				continue
			put.call(name, c[0], c[1], rnd.next() < 0.5)
		# breakable urns, barrels and crates along the walls
		var edges: Array = r.cells.filter(func(c: Array) -> bool:
			return free.call(r, c[0], c[1]) and (not in_room.call(r, c[0] - 1, c[1]) or not in_room.call(r, c[0] + 1, c[1]) or not in_room.call(r, c[0], c[1] + 1) or not in_room.call(r, c[0], c[1] - 1)) \
				and not near.call(r, c[0], c[1], 2.6))
		n = Core.jround(big * 1.4 + rnd.next() * 2)
		k = 0
		while k < n and not edges.is_empty():
			k += 1
			var c: Array = edges.pop_at(int(floor(rnd.next() * edges.size())))
			if not free.call(r, c[0], c[1]) or solid_near.call(c[0], c[1], 1.3):
				continue
			var look: String = pick.call(pack.break_set)
			var v := rnd.next()
			var crate := look.begins_with("crate")
			var drop := "undead" if crate and v > 0.72 else ("none" if v < 0.45 else ("gem" if v < 0.85 else "heart"))
			place.call({"type": "crate", "look": look, "hp": 2 if crate else 1, "drop": drop}, r, c[0], c[1])
		# a chest in some fight rooms: six in ten are mimics, the rest hold a little
		if r.type == "combat" and not r.get("seq", false) and rnd.next() < 0.35:
			var spots: Array = r.cells.filter(func(c: Array) -> bool:
				return free.call(r, c[0], c[1]) and free.call(r, c[0], c[1] + 1) and not near.call(r, c[0], c[1], 3) and not solid_near.call(c[0], c[1], 1.5))
			if not spots.is_empty():
				var c: Array = spots[int(floor(rnd.next() * spots.size()))]
				var o := {"type": "chest", "mimic": true, "loot": {"gems": 0}} if rnd.next() < float(pack.mimic_fight) else {"type": "chest", "loot": {"gems": 1 + int(floor(rnd.next() * 2))}}
				place.call(o, r, c[0], c[1])
	# treasure chests (loot room, hidden rooms behind skull heaps) bite rarely
	for e: Dictionary in W.ents:
		if e.type == "chest" and not e.get("mimic", false) and W.rooms[int(e.room)].gtype in ["treasure", "secret"] and rnd.next() < float(pack.mimic_treasure):
			e.mimic = true

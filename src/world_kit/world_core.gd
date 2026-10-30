extends RefCounted
## World kit floor core: the shared generator every story world runs on. A GDScript port of
## tools/world_kit/world_core.js (the browser preview runs the JS); both build the same floor from
## the same seed (tests/world_kit_parity_test.gd). A world brings its own floors, names and
## dressing (e.g. src/world_kit/world_pack.gd); build_floor() returns the floor as plain
## dictionaries, to_raw() turns it into the floor schema src/hell/hell_floor_data.gd reads.
##
## Fixed rules on every floor, whatever the seed (docs/WELT-BAUKASTEN.de.md):
##  - fight rooms are medium or large (2-3 slots); small rooms only for the start, the key room,
##    vaults, treasure, hidden rooms, the hidden stairs and the stairs down;
##  - the boss door opens only with the boss key from the key room (shop, mana fountain);
##  - the boss room is entered from below through a dressed gate, the key room from the bottom right;
##  - four to six pressure plates in a fixed order open a giant vault or a hidden passage;
##  - no way is ever blocked by mire, pits or furniture (clear_ways).
##
## Rooms, doors and entities are Dictionaries that point at each other (a door's "a"/"b" are the
## room dictionaries), as in the JS. Identity checks therefore use is_same(), never ==.

const C := 96.0
const SW := 14
const SH := 11
const N4 := [[1, 0], [-1, 0], [0, 1], [0, -1]]

const SOLID := {
	"rune_pillar_a": [74, 40], "rune_pillar_b": [62, 36], "rune_pillar_c": [66, 38], "rune_pillar_d": [56, 34], "obelisk": [62, 34],
	"brazier_pillar": [58, 32], "brazier_rune": [52, 30], "brazier_demon": [64, 34], "brazier_bowl": [56, 30], "brazier_low": [60, 30], "brazier_low_b": [60, 30], "brazier_floor": [60, 30],
	"altar": [124, 56], "shop_table": [150, 44], "skull_obelisk": [70, 34], "skull_heap": [92, 40], "coal_skulls": [72, 30], "skull_pile": [70, 30],
	"spire_big": [80, 40], "spire_big_b": [70, 36], "spire_mid": [48, 28], "spires_lava": [56, 30], "spire_t": [56, 30], "spire_big_t": [74, 36], "spires_t": [60, 26],
	"rocks_lava": [48, 28], "rocks_dark": [36, 24], "boulders": [56, 28], "rocks_a": [56, 28], "cage_small": [36, 18], "spire_small": [40, 22],
}
const LIGHT := {
	"brazier_pillar": [300, "255,140,60"], "brazier_rune": [280, "255,140,60"], "brazier_demon": [300, "255,110,50"], "brazier_bowl": [280, "255,140,60"],
	"brazier_low": [220, "255,140,60"], "brazier_low_b": [220, "255,140,60"], "brazier_floor": [230, "255,140,60"], "hanging_brazier": [260, "255,140,60"],
	"wall_torch_hook": [230, "255,150,70"], "wall_brazier": [240, "255,150,70"],
	"altar": [220, "255,90,60"], "skull_obelisk": [170, "255,80,60"], "fire_plate": [170, "255,120,50"], "rune_pillar_a": [130, "255,70,50"], "rune_pillar_c": [120, "255,70,50"], "obelisk": [110, "255,70,50"],
}
const BONES := ["bone_a", "bone_b", "bone_c", "bone_d", "bone_e", "bone_f", "bone_g", "bones_scatter", "rubble", "coal", "rocks_b", "skull_pile_t", "bones_t"]
const CLUTTER := [["skull_pile", "spires_t", "spire_mid", "rocks_a", "coal_skulls", "boulders", "cage_small", "spire_big_b", "skull_pile"],
	["spires_lava", "spire_big", "spire_big_t", "rocks_lava", "coal_skulls", "spire_mid", "boulders", "spires_t", "skull_pile"],
	["cage_small", "skull_pile", "skull_obelisk", "skull_pile", "rune_pillar_d", "spire_mid", "coal_skulls", "boulders", "cage_small"],
	["skull_obelisk", "spire_big", "skull_pile", "spires_lava", "brazier_demon", "rocks_lava", "skull_pile", "spire_big_t", "cage_small"]]
const BRAZIERS := ["brazier_bowl", "brazier_pillar", "brazier_rune", "brazier_low", "brazier_low_b", "brazier_floor", "brazier_demon"]
const BANNERS := ["banner_1", "banner_2", "banner_3", "banner_4", "banner_5"]
const TILE_NAMES := ["floor_00", "floor_01", "floor_02", "floor_03", "floor_04", "floor_05", "floor_06", "floor_07", "floor_08", "floor_09", "floor_10", "floor_11"]
## Entities the hero must reach, and entities that stand in the way (1: three cells wide).
const USE := ["lever", "key", "chest", "stairs", "shop", "well", "portal", "vault", "brazier", "plate", "heart", "gem", "skullheap", "seal"]
const BLOCKS := {"well": 1, "chest": 0, "vault": 1, "portal": 1, "brazier": 0, "stairs": 1, "crate": 0, "seal": 0, "skullheap": 0}


# ---------- 32-bit integer helpers (JS number semantics) ----------

## Wraps an integer to a signed 32-bit value (JS `| 0` on an integer).
static func i32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


## JS ToInt32 of a double: truncate, then modulo 2^32.
static func f32(v: float) -> int:
	var t := v - fmod(v, 1.0)
	var m := fposmod(t, 4294967296.0)
	if m >= 2147483648.0:
		m -= 4294967296.0
	return int(m)


## JS `x >>> n` for an int32 x.
static func ushr(v: int, n: int) -> int:
	return (v & 0xFFFFFFFF) >> n


## Math.imul.
static func imul(a: int, b: int) -> int:
	return i32(i32(a) * i32(b))


## JS Math.round (halves go up).
static func jround(v: float) -> int:
	return int(floor(v + 0.5))


## The seeded generator of the JS (mulberry32).
class Rng:
	var a := 0
	func _init(seed_value: int) -> void:
		a = _w(seed_value)
	static func _w(v: int) -> int:
		v &= 0xFFFFFFFF
		return v - 0x100000000 if v >= 0x80000000 else v
	static func _u(v: int, n: int) -> int:
		return (v & 0xFFFFFFFF) >> n
	static func _mul(x: int, y: int) -> int:
		return _w(_w(x) * _w(y))
	## Next number in [0, 1).
	func next() -> float:
		a = _w(a + 0x6D2B79F5)
		var t := _mul(a ^ _u(a, 15), 1 | a)
		t = _w(_w(t + _mul(t ^ _u(t, 7), 61 | t)) ^ t)
		return float((t ^ _u(t, 14)) & 0xFFFFFFFF) / 4294967296.0


## Hash of a cell (the JS hash(x, y, s)), in [0, 1).
static func hash3(x: float, y: float, s: float = 0.0) -> float:
	var h := f32(x * 374761393.0 + y * 668265263.0 + s * 2147483647.0)
	var hd := float(i32(h ^ ushr(h, 13))) * 1274126177.0
	var h2 := f32(hd)
	return float((h2 ^ ushr(h2, 16)) & 0xFFFFFFFF) / 4294967296.0


## Seeded Fisher-Yates, in place (as shuffle() in the JS).
static func shuffle(a: Array, rnd: Rng) -> Array:
	for k in range(a.size() - 1, 0, -1):
		var j := int(floor(rnd.next() * (k + 1)))
		var tmp: Variant = a[k]
		a[k] = a[j]
		a[j] = tmp
	return a


## Index of a dictionary by identity (Array.find compares dictionaries by value).
static func index_of(list: Array, item: Variant) -> int:
	for i in range(list.size()):
		if is_same(list[i], item):
			return i
	return -1


static func _has_same(list: Array, item: Variant) -> bool:
	return index_of(list, item) >= 0


# ---------- floor look and difficulty ----------

## Look per floor: darkness, grade, ember density, hot floor share.
static func theme_for(n: int, P: Dictionary) -> Dictionary:
	var t := (n - 1) / 9.0
	return {"dark": 0.6 + t * 0.2, "grade": t * 0.16, "vignette": 0.25 + t * 0.45, "embers": 2 + jround(t * 5), "hot": 0.18 + t * 0.4, "wallGlow": t, "circle": int(P.circle)}


static func difficulty_for(n: int, P: Dictionary) -> Dictionary:
	return {"hp": 1 + (n - 1) * 0.16, "speed": 1 + (n - 1) * 0.04, "extra": int(floor((n - 1) / 3.0)), "shooters": bool(P.get("shooters", false))}


# ---------- slot layout ----------

static func generate(P: Dictionary) -> Dictionary:
	var rnd := Rng.new(int(P.seed))
	for attempt in range(400):
		var res := _try_generate(P, rnd)
		if not res.is_empty():
			return res
	push_error("floor %d: no layout found" % int(P.n))
	return {}


static func _key(c: int, r: int) -> String:
	return "%d,%d" % [c, r]


static func _try_generate(P: Dictionary, rnd: Rng) -> Dictionary:
	var gc := int(P.gc)
	var gr := int(P.gr)
	var occ := {}
	var inside := func(c: int, r: int) -> bool: return c >= 0 and r >= 0 and c < gc and r < gr
	var free := func(c: int, r: int) -> bool: return inside.call(c, r) and not occ.has(_key(c, r))
	var pick := func(a: Array) -> Variant: return a[int(floor(rnd.next() * a.size()))]
	# 1. winding critical path of slots; its last step goes up, so the boss is entered from below
	var edges: Array = []
	for c in range(gc):
		for r in range(gr):
			if c == 0 or r == gr - 1:
				edges.append([c, r])
	var path: Array = [pick.call(edges)]
	occ[_key(path[0][0], path[0][1])] = "path"
	var dir: Variant = null
	while path.size() < int(P.path):
		var c: int = path[-1][0]
		var r: int = path[-1][1]
		var last := path.size() == int(P.path) - 1
		var opts: Array = []
		for d: Array in N4:
			var dx: int = d[0]
			var dy: int = d[1]
			if not (free.call(c + dx, r + dy) and (not last or dy == -1)):
				continue
			var nc := c + dx
			var nr := r + dy
			var onward := 0
			for e: Array in N4:
				if free.call(nc + e[0], nr + e[1]) and not (nc + e[0] == c and nr + e[1] == r):
					onward += 1
			var turn := 1.9 if dir != null and (dir[0] != dx or dir[1] != dy) else 1.0
			opts.append({"d": [dx, dy], "w": turn * (1 + onward * 0.3) if onward else 0.05})
		if opts.is_empty():
			return {}
		var total := 0.0
		for o: Dictionary in opts:
			total += o.w
		var t := rnd.next() * total
		var ch: Dictionary = opts[0]
		for o: Dictionary in opts:
			t -= o.w
			if t <= 0:
				ch = o
				break
		dir = ch.d
		path.append([c + dir[0], r + dir[1]])
		occ[_key(c + dir[0], r + dir[1])] = "path"
	# 2. chunk the path into fight rooms of 2 or 3 slots (never a single slot); P.two is the share of
	# 2-slot rooms (P.twoSide in the side branches), P.trimLarge cuts the corners of 3-slot rooms
	var rooms: Array = []
	var doors: Array = []
	var mk := func(slots: Array, type: String, extra: Dictionary) -> Dictionary:
		var room := {"id": "r%d" % rooms.size(), "slots": slots, "type": type, "children": []}
		room.merge(extra, true)
		rooms.append(room)
		for s: Array in slots:
			occ[_key(s[0], s[1])] = room.id
		return room
	var start: Dictionary = mk.call([path[0]], "start", {"onPath": true, "depth": 0})
	var i := 1
	var prev := start
	var boss_at := path.size() - 1
	while i < boss_at:
		var left := boss_at - i
		var size := left if left <= 3 else (2 if left == 4 else (2 if rnd.next() < float(P.get("two", 0.55)) else 3))
		var room: Dictionary = mk.call(path.slice(i, i + size), "combat", {"onPath": true, "parent": prev, "depth": int(prev.depth) + 1})
		doors.append({"a": prev, "b": room, "sa": path[i - 1], "sb": path[i], "kind": "open"})
		prev.children.append(room)
		prev = room
		i += size
	# boss: try a 2x2 block around the last path slot, else 2 slots, else 1
	var last_slot: Array = path[boss_at]
	var boss_slots: Array = [last_slot]
	occ.erase(_key(last_slot[0], last_slot[1]))
	for o: Array in [[0, 0], [-1, 0], [0, -1], [-1, -1]]:
		var sq: Array = [[last_slot[0] + o[0], last_slot[1] + o[1]], [last_slot[0] + o[0] + 1, last_slot[1] + o[1]], [last_slot[0] + o[0], last_slot[1] + o[1] + 1], [last_slot[0] + o[0] + 1, last_slot[1] + o[1] + 1]]
		var ok := true
		for s: Array in sq:
			if not ((s[0] == last_slot[0] and s[1] == last_slot[1]) or free.call(s[0], s[1])):
				ok = false
		for s: Array in sq:
			if not inside.call(s[0], s[1]):
				ok = false
		if ok:
			boss_slots = sq
			break
	if boss_slots.size() == 1:
		for d: Array in N4:
			var nb := [last_slot[0] + d[0], last_slot[1] + d[1]]
			if free.call(nb[0], nb[1]):
				boss_slots = [last_slot, nb]
				break
	var boss: Dictionary = mk.call(boss_slots, "boss", {"onPath": true, "parent": prev, "depth": int(prev.depth) + 1})
	doors.append({"a": prev, "b": boss, "sa": path[boss_at - 1], "sb": last_slot, "kind": "open"})
	prev.children.append(boss)
	# portal room next to the boss
	var portal_slot: Variant = null
	var portal_from: Variant = null
	for s: Array in boss_slots:
		for d: Array in N4:
			if portal_slot == null and free.call(s[0] + d[0], s[1] + d[1]):
				portal_slot = [s[0] + d[0], s[1] + d[1]]
				portal_from = s
	if portal_slot == null:
		return {}
	var portal: Dictionary = mk.call([portal_slot], "portal", {"parent": boss, "depth": int(boss.depth) + 1})
	doors.append({"a": boss, "b": portal, "sa": portal_from, "sb": portal_slot, "kind": "boss"})
	boss.children.append(portal)
	# 3. side branches until the floor is full: fight rooms of 2 or 3 slots
	var target := jround(gc * gr * 0.7)
	var used := 0
	for r0: Dictionary in rooms:
		used += r0.slots.size()
	var guard := 0
	while used < target and guard < 400:
		guard += 1
		var pool := rooms.filter(func(x: Dictionary) -> bool: return x.type == "combat" or x.type == "start")
		var from: Dictionary = pool[int(floor(rnd.next() * pool.size()))]
		var cands: Array = []
		for s: Array in from.slots:
			for d: Array in N4:
				if free.call(s[0] + d[0], s[1] + d[1]):
					cands.append([s, [s[0] + d[0], s[1] + d[1]], d])
		if cands.is_empty():
			continue
		var cd: Array = pick.call(cands)
		var sa: Array = cd[0]
		var sb: Array = cd[1]
		var dd: Array = cd[2]
		var slots: Array = [sb]
		var want := 2 if rnd.next() < float(P.get("twoSide", 0.6)) else 3
		while slots.size() < want:
			var c2: int = slots[-1][0]
			var r2: int = slots[-1][1]
			var o2: Array = []
			for d: Array in N4:
				var mine := false
				for s: Array in slots:
					if s[0] == c2 + d[0] and s[1] == r2 + d[1]:
						mine = true
				if free.call(c2 + d[0], r2 + d[1]) and not mine:
					o2.append(d)
			var nxt: Variant = null
			for o: Array in o2:
				if o[0] == dd[0] and o[1] == dd[1]:
					nxt = o
					break
			if nxt == null and not o2.is_empty():
				nxt = o2[int(floor(rnd.next() * o2.size()))]
			if nxt == null:
				break
			slots.append([c2 + nxt[0], r2 + nxt[1]])
		if slots.size() < 2:
			continue
		var room: Dictionary = mk.call(slots, "combat", {"parent": from, "depth": int(from.depth) + 1})
		doors.append({"a": from, "b": room, "sa": sa, "sb": sb, "kind": "open"})
		from.children.append(room)
		used += slots.size()
	if used < target * 0.9:
		return {}
	var door_to := func(r: Dictionary) -> Dictionary:
		for d: Dictionary in doors:
			if is_same(d.b, r):
				return d
		return {}
	var groups := {}
	# 4. locks and keys. Main-path lock: key A dropped in a room before the lock.
	if P.get("mainLock", false):
		var path_rooms := rooms.filter(func(x: Dictionary) -> bool: return x.get("onPath", false) and x.type == "combat")
		var lock_idx := maxi(1, int(floor(path_rooms.size() * 0.55)))
		var lock_room: Variant = path_rooms[lock_idx] if lock_idx < path_rooms.size() else null
		var before: Array = path_rooms.slice(0, lock_idx)
		before.append(start)
		var branch := rooms.filter(func(x: Dictionary) -> bool: return x.type == "combat" and not x.get("onPath", false) and _has_same(before, _root_on_path(x)))
		var holders: Array = branch if not branch.is_empty() else path_rooms.slice(0, lock_idx)
		if lock_room != null and not holders.is_empty():
			holders[int(floor(rnd.next() * holders.size()))].drop = "A"
			var d: Dictionary = door_to.call(lock_room)
			d.kind = "lock"
			d.key = "A"
	# the boss door opens only with key C
	var boss_door: Dictionary = door_to.call(boss)
	boss_door.kind = "lock"
	boss_door.key = "C"
	# small rooms hang on a fight room through a free neighbour slot; they are always dead ends
	var fights := func() -> Array: return rooms.filter(func(x: Dictionary) -> bool: return x.type == "combat" and not is_same(x, boss))
	var hang := func(type: String, ok: Callable, weight: Callable, dirs: Array) -> Dictionary:
		var cands: Array = []
		for r: Dictionary in fights.call():
			if not ok.call(r):
				continue
			for s: Array in r.slots:
				for d: Array in dirs:
					if free.call(s[0] + d[0], s[1] + d[1]):
						cands.append([r, s, [s[0] + d[0], s[1] + d[1]], weight.call(r)])
		if cands.is_empty():
			return {}
		var total := 0.0
		for c: Array in cands:
			total += c[3]
		var t := rnd.next() * total
		var ch: Array = cands[0]
		for c: Array in cands:
			t -= c[3]
			if t <= 0:
				ch = c
				break
		var from: Dictionary = ch[0]
		var room: Dictionary = mk.call([ch[2]], type, {"parent": from, "depth": int(from.depth) + 1})
		doors.append({"a": from, "b": room, "sa": ch[1], "sb": ch[2], "kind": "open"})
		from.children.append(room)
		return room
	var any := func(_r: Dictionary) -> bool: return true
	var one := func(_r: Dictionary) -> float: return 1.0
	# key room with the boss key, the shop and the mana fountain; entered from the bottom right:
	# it sits left of its fight room and the door is the lowest opening of its right wall
	var key_room: Dictionary = hang.call("key", func(r: Dictionary) -> bool: return int(r.depth) >= 2,
		func(r: Dictionary) -> float: return (1.0 if r.get("onPath", false) else 3.0) * (1 + int(r.depth) * 0.3), [[-1, 0]])
	if key_room.is_empty():
		return {}
	key_room.keyItem = "C"
	door_to.call(key_room).off = 8
	# pressure plates: a straight fight room; solving opens a giant vault or a hidden passage
	var straight := func(r: Dictionary) -> bool:
		var col := true
		var row := true
		for s: Array in r.slots:
			if s[0] != r.slots[0][0]:
				col = false
			if s[1] != r.slots[0][1]:
				row = false
		return col or row
	var hidden := rnd.next() < 0.5
	var plate_target: Dictionary = hang.call("hidden" if hidden else "pvault", func(r: Dictionary) -> bool: return straight.call(r) and not r.has("drop"), one, N4)
	if plate_target.is_empty():
		return {}
	plate_target.parent.seq = true
	var pd: Dictionary = door_to.call(plate_target)
	pd.kind = "secret" if hidden else "puzzle"
	pd.group = "seq"
	# 4 to 6 plates; the order is never the plain reading order, its reverse, or (with four) a walk
	# around the square
	var count := 4 + int(floor(rnd.next() * 3))
	var round_walks := ["1243", "2431", "4312", "3124", "1342", "3421", "4213", "2134"]
	var reading: Array = []
	for k in range(count):
		reading.append(k + 1)
	var rev := reading.duplicate()
	rev.reverse()
	var banned := [_join(reading), _join(rev)]
	if count == 4:
		banned.append_array(round_walks)
	var order: Array = []
	while true:
		order = reading.duplicate()
		for k in range(count - 1, 0, -1):
			var j := int(floor(rnd.next() * (k + 1)))
			var tmp: Variant = order[k]
			order[k] = order[j]
			order[j] = tmp
		if not banned.has(_join(order)):
			break
	groups.seq = {"kind": "sequence", "label": "Druckplatten", "sequence": order, "count": count, "opens": "hidden" if hidden else "vault"}
	# treasure behind lock B, key B dropped by a fight room
	var treasure: Dictionary = hang.call("treasure", any, one, N4)
	if treasure.is_empty():
		return {}
	var td: Dictionary = door_to.call(treasure)
	td.kind = "lock"
	td.key = "B"
	var b_holders: Array = fights.call().filter(func(r: Dictionary) -> bool: return not r.has("drop") and not is_same(r, treasure.parent))
	if b_holders.is_empty():
		return {}
	b_holders[int(floor(rnd.next() * b_holders.size()))].drop = "B"
	# soul-bowl vault: all bowls of the floor lit open it
	if int(P.get("fire", 0)) > 0:
		var vault: Dictionary = hang.call("vault", func(r: Dictionary) -> bool: return not r.get("seq", false), one, N4)
		if vault.is_empty():
			return {}
		var vd: Dictionary = door_to.call(vault)
		vd.kind = "puzzle"
		vd.group = "feuer"
		groups.feuer = {"kind": "braziers", "label": "Feuerschalen", "spread": true}
		var hold := shuffle(fights.call().filter(func(r: Dictionary) -> bool: return not is_same(r, vault.parent) and not r.get("seq", false)), rnd).slice(0, int(P.fire))
		if hold.size() < int(P.fire):
			return {}
		for h: Dictionary in hold:
			h.fireBrazier = true
	# now and then a hidden room behind a breakable skull heap
	if rnd.next() < float(P.get("secret", 0.6)):
		var sec: Dictionary = hang.call("secret", any, one, N4)
		if not sec.is_empty():
			door_to.call(sec).kind = "secret"
	# the jackpot stairs: from floor 2 on, sometimes a hidden stairway back to an earlier floor,
	# behind a plain wall opened by lighting the one extinguished torch in the room before it
	if int(P.n) >= 2 and rnd.next() < float(P.get("stairs", 0.5)):
		var st: Dictionary = hang.call("stairs", func(r: Dictionary) -> bool: return int(r.depth) >= 2, one, N4)
		if not st.is_empty():
			var sd: Dictionary = door_to.call(st)
			sd.kind = "secret"
			sd.group = "stiege"
			groups.stiege = {"kind": "lever", "label": "Erloschene Fackel"}
	# shrine and rewards on fight rooms at branch ends
	var ends: Array = fights.call().filter(func(r: Dictionary) -> bool:
		if r.get("onPath", false):
			return false
		for c: Dictionary in r.children:
			if c.type == "combat":
				return false
		return true)
	var shrine: Variant = null
	for r: Dictionary in ends:
		if not r.get("seq", false) and not r.has("drop"):
			shrine = r
			break
	if shrine != null:
		shrine.type = "shrine"
	for r: Dictionary in ends:
		if not is_same(r, shrine) and rnd.next() < 0.45:
			r.reward = {"heart": true, "gems": 1} if rnd.next() < 0.5 else {"gems": 3}
	# 5. loops between neighbouring rooms with the same gate signature
	var sig := func(r: Dictionary) -> String:
		var out: Array = []
		var cur := r
		while cur.has("parent"):
			var d: Dictionary = door_to.call(cur)
			if d.kind != "open":
				out.append(str(index_of(doors, d)))
			cur = cur.parent
		out.sort()
		return ",".join(out)
	var by_id := {}
	for r: Dictionary in rooms:
		by_id[r.id] = r
	for k: String in occ.keys():
		var id: String = occ[k]
		var parts := k.split(",")
		var c := int(parts[0])
		var r := int(parts[1])
		for d: Array in [[1, 0], [0, 1]]:
			var ok: Variant = occ.get(_key(c + d[0], r + d[1]))
			if ok == null or ok == id:
				continue
			var A: Dictionary = by_id[id]
			var B: Dictionary = by_id[ok]
			if not (A.type in ["combat", "start"]) or not (B.type in ["combat", "start"]):
				continue
			var linked := false
			for dd2: Dictionary in doors:
				if (is_same(dd2.a, A) and is_same(dd2.b, B)) or (is_same(dd2.a, B) and is_same(dd2.b, A)):
					linked = true
			if linked:
				continue
			if sig.call(A) != sig.call(B) or rnd.next() > float(P.loops):
				continue
			doors.append({"a": A, "b": B, "sa": [c, r], "sb": [c + d[0], r + d[1]], "kind": "open", "loop": true})
	return {"rooms": rooms, "doors": doors, "groups": groups}


static func _join(a: Array) -> String:
	var s := ""
	for v: Variant in a:
		s += str(v)
	return s


static func _root_on_path(r: Dictionary) -> Variant:
	var cur: Variant = r
	while cur != null and not cur.get("onPath", false):
		cur = cur.get("parent")
	return cur


# ---------- room records ----------

## Turns a generated layout into room records with names, shapes and info texts.
static func describe(P: Dictionary, gen: Dictionary, rnd: Rng, names: Array, suffixes: Array) -> Dictionary:
	var A: Array = names[int(P.circle)]
	var used := {}
	var name_of := func() -> String:
		for k in range(50):
			var n: String = str(A[int(floor(rnd.next() * A.size()))]) + str(suffixes[int(floor(rnd.next() * suffixes.size()))])
			var cap := n.substr(0, 1).to_upper() + n.substr(1)
			if not used.has(cap):
				used[cap] = true
				return cap
		return "Kammer"
	var boss: Dictionary = P.boss
	var special := {
		"start": ["Abstieg zur %d. Etage" % int(P.n), "Eingang", "icon_door"],
		"boss": ["Hort: " + str(boss.name), "Letzter Kampf" if boss.get("final", false) else ("Zwischenboss" if boss.get("mini", false) else "Endkampf"), "icon_demon_big"],
		"portal": ["Portalkammer", "Schatzkammer", "portal"], "vault": ["Feuerschalen-Tresor", "Tresorraum", "icon_chest"], "pvault": ["Riesentresor", "Tresorraum", "icon_chest"],
		"treasure": ["Beutekammer", "Schatzraum", "icon_chest"], "key": ["Schlüsselkammer", "Schlüsselraum · Laden · Brunnen", "key"], "shrine": ["Herzschrein", "Kampf · Schrein", "heart"],
		"secret": ["Verborgene Gruft", "Geheimraum", "rune_gem"], "hidden": ["Versteckte Kammer", "Geheimraum · Druckplatten", "rune_gem"],
		"stairs": ["Vergessene Stiege", "Geheimraum · Treppe", "icon_door"],
	}
	var type_of := {"shrine": "combat", "vault": "treasure", "pvault": "treasure", "hidden": "secret"}
	var rooms: Array = []
	for g: Dictionary in gen.rooms:
		var sp: Variant = special.get(g.type)
		var r := {"id": g.id, "slots": g.slots, "type": type_of.get(g.type, g.type), "gtype": g.type, "onPath": g.get("onPath", false)}
		r.name = sp[0] if sp != null else name_of.call()
		r.kind = sp[1] if sp != null else ("Kampfraum · Schlüssel" if g.has("drop") else "Kampfraum")
		if sp != null:
			r.icon = sp[2]
		if g.type == "key":
			r.iconKey = g.keyItem
		if g.has("drop"):
			r.drop = g.drop
		if g.has("reward"):
			r.reward = g.reward
		if g.get("seq", false):
			r.seq = true
			r.icon = "icon_scroll"
			r.kind = "Kampf · Rätsel"
		if g.get("fireBrazier", false):
			r.fireBrazier = true
		var n: int = g.slots.size()
		if g.type == "boss":
			r.shape = "oct"
			r.cut = 6 if n == 4 else 4
		elif g.type in ["start", "secret", "hidden", "vault", "pvault", "stairs"]:
			r.shape = "oct"
			r.cut = 4 if g.type == "secret" or g.type == "hidden" else 3
		elif n == 1:
			r.shape = "rect"
		elif n >= 3 and P.has("trimLarge"):
			r.shape = "oct"
			r.cut = int(P.trimLarge)
		else:
			r.shape = "oct" if n == 2 and rnd.next() < 0.25 else "rect"
			r.cut = 2
		if r.type == "combat":
			r.mobs = mini(9, 2 + n * 2 + int(floor(rnd.next() * 2))) + (-2 if g.type == "shrine" else 0)
		if r.type == "boss":
			r.mobs = 3
		r.info = _info_for(g)
		rooms.append(r)
	var doors: Array = []
	for d: Dictionary in gen.doors:
		var o := {"a": d.a.id, "b": d.b.id, "kind": d.kind, "slots": [d.sa, d.sb]}
		if d.kind == "lock":
			o.extra = d.key
		if d.kind == "puzzle" or d.has("group"):
			o.extra = d.get("group")
		if d.has("off"):
			o.off = d.off
		doors.append(o)
	return {"gc": int(P.gc), "gr": int(P.gr), "rooms": rooms, "doors": doors, "groups": gen.groups}


static func _info_for(g: Dictionary) -> String:
	match str(g.type):
		"start": return "Ankunft auf dieser Etage."
		"boss": return "Prunktor im Süden, verschlossen mit dem Dämonenschlüssel. Der Hüter der Etage wartet."
		"portal": return "Belohnung und Portal zur nächsten Etage."
		"vault": return "Gittertor: öffnet sich, wenn alle Feuerschalen der Etage brennen. Riesentresor mit Herzcontainer."
		"treasure": return "Mit dem Knochenschlüssel zu öffnen. Ein Kampfraum lässt ihn fallen."
		"key": return "Der Dämonenschlüssel für das Bosstor liegt in der Mitte. Daneben ein Altar (später ein Laden) und ein Manabrunnen, der einmal Mana voll auffüllt."
		"pvault": return "Gittertor: öffnet sich, wenn die vier Druckplatten nebenan in der richtigen Reihenfolge betreten sind."
		"hidden": return "Verborgener Gang: öffnet sich, wenn die vier Druckplatten nebenan in der richtigen Reihenfolge betreten sind."
		"shrine": return "Ein Herz auf der Feuerplatte heilt."
		"secret": return "Hinter einem Schädelhaufen verborgen."
		"stairs": return "Hinter einer Wand verborgen; eine erloschene Fackel im Raum davor öffnet sie. Eine Treppe zurück in eine frühere Etage nach Wahl, neu gewürfelt."
	var bits: Array = []
	if g.get("drop", "") == "A":
		bits.append("Lässt den Glutschlüssel fallen.")
	if g.get("drop", "") == "B":
		bits.append("Lässt den Knochenschlüssel fallen.")
	if g.get("seq", false):
		bits.append("Vier Druckplatten: in der richtigen Reihenfolge betreten. Jede richtige leuchtet, eine falsche löscht alle.")
	if g.get("fireBrazier", false):
		bits.append("Eine erloschene Feuerschale steht hier.")
	if g.has("reward"):
		bits.append("Belohnung nach dem Sieg.")
	return " ".join(bits) if not bits.is_empty() else "Kampfraum."


# ---------- the floor ----------

## Builds floor n of a world. opts: floors (index = floor number, [0] unused), circles, names,
## suffixes. sizes: sprite name -> [w, h] (lights sit at a share of the sprite height).
static func build_floor(n: int, sizes: Dictionary, opts: Dictionary) -> Dictionary:
	var P: Dictionary = opts.floors[n]
	var theme := theme_for(n, P)
	var plan := describe(P, generate(P), Rng.new(int(P.seed) + 99), opts.names, opts.suffixes)
	var GC: int = plan.gc
	var GR: int = plan.gr
	var COLS := GC * SW
	var ROWS := GR * SH
	var count := COLS * ROWS
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
		"diff": difficulty_for(n, P), "final": bool(P.get("final", false)), "COLS": COLS, "ROWS": ROWS,
		"grid": grid, "roomAt": room_at, "holeAt": hole_at, "tileAt": tile_at,
		"rooms": plan.rooms, "doors": [], "props": [], "decals": [], "wallDecor": [], "ents": [], "lights": [], "groups": plan.groups, "occupied": {}, "reserved": {}}
	var by_id := {}
	for i in range(W.rooms.size()):
		var r: Dictionary = W.rooms[i]
		r.index = i
		by_id[r.id] = r
		r.doors = []
		var cs: Array = r.slots.map(func(s: Array) -> int: return s[0])
		var rs: Array = r.slots.map(func(s: Array) -> int: return s[1])
		r.sc = cs.min()
		r.sr = rs.min()
		r.bx = int(r.sc) * SW + 1
		r.by = int(r.sr) * SH + 1
		r.bw = (int(cs.max()) - int(r.sc) + 1) * SW - 2
		r.bh = (int(rs.max()) - int(r.sr) + 1) * SH - 2
		r.cleared = r.type != "combat" and r.type != "boss"
	var set_cell := func(r: Dictionary, x: int, y: int, v: bool) -> void:
		var i := y * COLS + x
		if v:
			W.grid[i] = 1
			W.roomAt[i] = r.index
			W.holeAt[i] = 0
		else:
			W.grid[i] = 0
			W.roomAt[i] = -1
	# carve rooms
	for r: Dictionary in W.rooms:
		var has := func(c: int, rr: int) -> bool:
			for s: Array in r.slots:
				if s[0] == c and s[1] == rr:
					return true
			return false
		for s: Array in r.slots:
			var c: int = s[0]
			var rr: int = s[1]
			for y in range(rr * SH + 1, rr * SH + 10):
				for x in range(c * SW + 1, c * SW + 13):
					set_cell.call(r, x, y, true)
			if has.call(c + 1, rr):
				for y in range(rr * SH + 1, rr * SH + 10):
					for x in range(c * SW + 13, c * SW + 15):
						set_cell.call(r, x, y, true)
			if has.call(c, rr + 1):
				for y in range(rr * SH + 10, rr * SH + 12):
					for x in range(c * SW + 1, c * SW + 13):
						set_cell.call(r, x, y, true)
			if has.call(c + 1, rr) and has.call(c, rr + 1) and has.call(c + 1, rr + 1):
				for y in range(rr * SH + 10, rr * SH + 12):
					for x in range(c * SW + 13, c * SW + 15):
						set_cell.call(r, x, y, true)
		var bx: int = r.bx
		var by: int = r.by
		var bw: int = r.bw
		var bh: int = r.bh
		if r.shape == "oct":
			for y in range(bh):
				for x in range(bw):
					if mini(x, bw - 1 - x) + mini(y, bh - 1 - y) < int(r.cut):
						set_cell.call(r, bx + x, by + y, false)
	# doors
	for spec: Dictionary in plan.doors:
		var A: Dictionary = by_id[spec.a]
		var B: Dictionary = by_id[spec.b]
		var sa: Array = spec.slots[0]
		var sb: Array = spec.slots[1]
		var kind: String = spec.kind
		var d := {"a": A, "b": B, "kind": kind, "cells": [], "unlocked": false, "broken": false, "hidden": false}
		if kind == "lock":
			d.key = spec.extra
		if kind == "puzzle":
			d.group = spec.extra
		if kind == "secret" and spec.get("extra") != null:
			d.group = spec.extra
		if sa[1] == sb[1]:
			var l := mini(sa[0], sb[0])
			var y0: int = int(sa[1]) * SH + int(spec.get("off", 5))
			d.dir = "h"
			for x in [l * SW + 13, l * SW + 14]:
				for y in [y0, y0 + 1]:
					d.cells.append([x, y])
			var left: Dictionary = A if sa[0] == l else B
			var right: Dictionary = B if is_same(left, A) else A
			for y in [y0, y0 + 1]:
				for x in [l * SW + 11, l * SW + 12]:
					set_cell.call(left, x, y, true)
				for x in [l * SW + 15, l * SW + 16]:
					set_cell.call(right, x, y, true)
		else:
			var t := mini(sa[1], sb[1])
			var x0: int = int(sa[0]) * SW + int(spec.get("off", 6))
			d.dir = "v"
			for y in [t * SH + 10, t * SH + 11]:
				for x in [x0, x0 + 1]:
					d.cells.append([x, y])
			var top: Dictionary = A if sa[1] == t else B
			var bottom: Dictionary = B if is_same(top, A) else A
			for x in [x0, x0 + 1]:
				for y in [t * SH + 8, t * SH + 9]:
					set_cell.call(top, x, y, true)
				for y in [t * SH + 12, t * SH + 13]:
					set_cell.call(bottom, x, y, true)
		for cl: Array in d.cells:
			W.grid[int(cl[1]) * COLS + int(cl[0])] = 0 if kind == "secret" else 1
		var xs: Array = d.cells.map(func(cl: Array) -> int: return cl[0])
		var ys: Array = d.cells.map(func(cl: Array) -> int: return cl[1])
		d.x0 = xs.min()
		d.y0 = ys.min()
		d.x1 = xs.max()
		d.y1 = ys.max()
		d.cx = (int(d.x0) + int(d.x1) + 1) / 2.0 * C
		d.cy = (int(d.y0) + int(d.y1) + 1) / 2.0 * C
		d.crackX = ((int(d.x0) * C + 31) if int(A.bx) < int(d.x0) else ((int(d.x1) + 1) * C - 31)) if d.dir == "h" else d.cx
		d.crackY = ((int(d.y0) * C + 37) if int(A.by) < int(d.y0) else ((int(d.y1) + 1) * C - 37)) if d.dir == "v" else d.cy
		A.doors.append(d)
		B.doors.append(d)
		W.doors.append(d)
	# floor tiles: deeper floors show more cracks
	var hot: float = theme.hot
	for i in range(count):
		var x := i % COLS
		var y := i / COLS
		var h := hash3(x, y, 3 + n)
		if W.roomAt[i] < 0:
			W.tileAt[i] = "floor_10" if h < 0.5 else ("floor_11" if h < 0.8 else "floor_01")
			continue
		var cold := 1.0 - hot
		var tn := "floor_09"
		if h < cold * 0.5: tn = "floor_00"
		elif h < cold * 0.7: tn = "floor_04"
		elif h < cold * 0.85: tn = "floor_01"
		elif h < cold: tn = "floor_10"
		elif h < cold + hot * 0.25: tn = "floor_02"
		elif h < cold + hot * 0.45: tn = "floor_03"
		elif h < cold + hot * 0.65: tn = "floor_07"
		elif h < cold + hot * 0.85: tn = "floor_08"
		W.tileAt[i] = tn
	# per-room features
	var rnd := Rng.new(int(W.seed) + 4242)
	var gate: Variant = null
	for d: Dictionary in W.doors:
		if d.kind == "lock" and d.get("key", "") == "C" and (d.a.type == "boss" or d.b.type == "boss"):
			gate = d
			break
	if gate != null:
		(gate.b if gate.a.type == "boss" else gate.a).gate = gate
	for r: Dictionary in W.rooms:
		r.cells = cells_of(W, r)
		_plan_lanes(W, r)
		if r.has("gate"):
			_reserve_gate(W, r)
		_generate_features(W, P, r, rnd, sizes)
	for r: Dictionary in W.rooms:
		if r.has("gate"):
			_dress_boss_gate(W, r)
	_place_skull_heaps(W, sizes)
	if n >= 4:
		_place_seals(W, P, Rng.new(int(W.seed) + 777), sizes)
	for r: Dictionary in W.rooms:
		_auto_dress(W, r, sizes)
	_place_levers(W, Rng.new(int(W.seed) + 515))
	for r: Dictionary in W.rooms:
		r.cells = cells_of(W, r)
	W.byId = by_id
	return W


static func cells_of(W: Dictionary, r: Dictionary) -> Array:
	var out: Array = []
	for y in range(int(r.by), int(r.by) + int(r.bh)):
		for x in range(int(r.bx), int(r.bx) + int(r.bw)):
			if W.roomAt[y * int(W.COLS) + x] == int(r.index):
				out.append([x, y])
	return out


static func near_door(r: Dictionary, x: float, y: float, dist: float) -> bool:
	for d: Dictionary in r.doors:
		if Vector2(x * C - float(d.cx), y * C - float(d.cy)).length() < dist * C:
			return true
	return false


static func _hyp(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


# ---------- placing things (the helpers of the JS) ----------

static func _idx(W: Dictionary, x: int, y: int) -> int:
	return y * int(W.COLS) + x


static func _grid(W: Dictionary, i: int) -> int:
	return int(W.grid[i]) if i >= 0 and i < W.grid.size() else -99


static func _room_at(W: Dictionary, i: int) -> int:
	return int(W.roomAt[i]) if i >= 0 and i < W.roomAt.size() else -99


static func prop(W: Dictionary, r: Dictionary, sizes: Dictionary, name: String, cx: float, cy: float, o: Dictionary = {}) -> Dictionary:
	var p := {"name": name, "x": (int(r.bx) + cx) * C, "y": (int(r.by) + cy) * C, "flip": bool(o.get("flip", false)), "layer": o.get("layer", "obj")}
	var s: Variant = null if o.get("solid") is bool and o.solid == false else o.get("solid", SOLID.get(name))
	if s != null:
		p.solid = [p.x - s[0] / 2.0, p.y - s[1], p.x + s[0] / 2.0, p.y]
		W.occupied[_idx(W, int(floor(int(r.bx) + cx)), int(floor(int(r.by) + cy - 0.2)))] = true
	W.props.append(p)
	var l: Variant = LIGHT.get(name)
	if l != null and not o.get("unlit", false):
		W.lights.append({"x": p.x, "y": p.y - float(sizes[name][1]) * 0.72, "r": l[0], "c": l[1], "f": hash3(cx * 7, cy * 9) * 6})
	return p


static func decal(W: Dictionary, r: Dictionary, name: String, cx: float, cy: float, a: float = 1.0) -> void:
	W.decals.append({"name": name, "x": (int(r.bx) + cx) * C, "y": (int(r.by) + cy) * C, "a": a})
	var l: Variant = LIGHT.get(name)
	if l != null:
		W.lights.append({"x": (int(r.bx) + cx) * C, "y": (int(r.by) + cy) * C, "r": l[0], "c": l[1], "f": 1})


static func wall(W: Dictionary, r: Dictionary, name: String, cx: float, cy: float = 0.0, dy: float = 6.0, flip := false) -> void:
	var w := {"name": name, "x": (int(r.bx) + cx) * C, "y": (int(r.by) + cy) * C - 74 + dy, "flip": flip}
	W.wallDecor.append(w)
	var l: Variant = LIGHT.get(name)
	if l != null:
		W.lights.append({"x": w.x, "y": w.y + 40, "r": l[0], "c": l[1], "f": hash3(cx, 5) * 6})


static func ent(W: Dictionary, r: Dictionary, o: Dictionary) -> Dictionary:
	o.x = (int(r.bx) + float(o.cx)) * C
	o.y = (int(r.by) + float(o.cy)) * C
	o.room = int(r.index)
	W.ents.append(o)
	W.occupied[_idx(W, int(floor(int(r.bx) + float(o.cx))), int(floor(int(r.by) + float(o.cy) - 0.2)))] = true
	return o


static func lava(W: Dictionary, r: Dictionary, x: int, y: int, w: int, h: int) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			var k := _idx(W, int(r.bx) + i, int(r.by) + j)
			W.grid[k] = 2
			W.occupied[k] = true


static func bridge(W: Dictionary, r: Dictionary, x: int, y: int, w: int, h: int, dir: String) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			var k := _idx(W, int(r.bx) + i, int(r.by) + j)
			W.grid[k] = 3
			W.occupied[k] = true
	W.decals.append({"name": "bridge_h" if dir == "h" else "bridge_v", "x": (int(r.bx) + x + w / 2.0) * C, "y": (int(r.by) + y + h / 2.0) * C, "w": w * C + 20, "h": h * C + 18})


static func pit(W: Dictionary, r: Dictionary, x: int, y: int) -> void:
	W.decals.append({"name": "pit", "x": (int(r.bx) + x + 0.5) * C, "y": (int(r.by) + y + 0.5) * C})
	ent(W, r, {"type": "pit", "cx": x + 0.5, "cy": y + 0.5})


# ---------- features ----------

## Lanes: shortest walks from every door into the room centre stay free of mire and solids.
static func _plan_lanes(W: Dictionary, r: Dictionary) -> void:
	var cols: int = W.COLS
	var in_room := func(x: int, y: int) -> bool: return _room_at(W, y * cols + x) == int(r.index)
	var cellset := {}
	for c: Array in r.cells:
		cellset[c[1] * cols + c[0]] = true
	var best: Array = []
	var bd := 1e9
	var tx: float = int(r.bx) + int(r.bw) / 2.0
	var ty: float = int(r.by) + int(r.bh) / 2.0
	for c: Array in r.cells:
		var d := _hyp(c[0] + 0.5 - tx, c[1] + 0.5 - ty)
		if d < bd:
			bd = d
			best = c
	r.center = best
	var lanes := {}
	for d: Dictionary in r.doors:
		var e: Array = []
		var ed := 1e9
		for c: Array in r.cells:
			var dd := _hyp((c[0] + 0.5) * C - float(d.cx), (c[1] + 0.5) * C - float(d.cy))
			if dd < ed:
				ed = dd
				e = c
		var prev := {e[1] * cols + e[0]: -1}
		var q: Array = [e]
		var qi := 0
		while qi < q.size():
			var cur: Array = q[qi]
			qi += 1
			if cur[0] == best[0] and cur[1] == best[1]:
				break
			for nd: Array in N4:
				var k: int = (cur[1] + nd[1]) * cols + cur[0] + nd[0]
				if cellset.has(k) and not prev.has(k):
					prev[k] = cur[1] * cols + cur[0]
					q.append([cur[0] + nd[0], cur[1] + nd[1]])
		var k2: Variant = best[1] * cols + best[0]
		while k2 != null and k2 != -1:
			lanes[k2] = true
			var x: int = int(k2) % cols
			var y: int = int(k2) / cols
			if in_room.call(x + 1, y):
				lanes[y * cols + x + 1] = true
			if in_room.call(x, y + 1):
				lanes[(y + 1) * cols + x] = true
			k2 = prev.get(k2)
		for dy in range(-1, 3):
			for dx in range(-1, 3):
				if in_room.call(e[0] + dx, e[1] + dy):
					lanes[(e[1] + dy) * cols + e[0] + dx] = true
	r.lanes = lanes
	for k: int in lanes:
		W.occupied[k] = true


static func _room_connected(W: Dictionary, r: Dictionary) -> bool:
	var cols: int = W.COLS
	var cells := cells_of(W, r).filter(func(c: Array) -> bool: return W.grid[c[1] * cols + c[0]] != 0)
	if cells.is_empty():
		return false
	var cellset := {}
	for c: Array in cells:
		cellset[c[1] * cols + c[0]] = true
	var seen := {cells[0][1] * cols + cells[0][0]: true}
	var q: Array = [cells[0]]
	while not q.is_empty():
		var cur: Array = q.pop_back()
		for nd: Array in N4:
			var k: int = (cur[1] + nd[1]) * cols + cur[0] + nd[0]
			if cellset.has(k) and not seen.has(k):
				seen[k] = true
				q.append([cur[0] + nd[0], cur[1] + nd[1]])
	return seen.size() == cellset.size()


static func _generate_features(W: Dictionary, P: Dictionary, r: Dictionary, rnd: Rng, sizes: Dictionary) -> void:
	var cols: int = W.COLS
	var bx: int = r.bx
	var by: int = r.by
	var local: Array = r.cells.map(func(c: Array) -> Array: return [c[0] - bx, c[1] - by])
	var free_l := func(x: int, y: int) -> bool:
		var k := (by + y) * cols + bx + x
		return _room_at(W, k) == int(r.index) and _grid(W, k) == 1 and not W.occupied.has(k)
	var rect_free := func(x: int, y: int, w: int, h: int, margin: int) -> bool:
		for j in range(y - margin, y + h + margin):
			for i in range(x - margin, x + w + margin):
				if not free_l.call(i, j):
					return false
		return true
	var try_rect := func(w: int, h: int, margin: int, n: int) -> Variant:
		for k in range(n):
			var c: Array = local[int(floor(rnd.next() * local.size()))]
			if rect_free.call(c[0], c[1], w, h, margin):
				return c
		return null
	var cx: int = int(r.center[0]) - bx
	var cy: int = int(r.center[1]) - by
	var big: bool = r.slots.size() >= 2
	var g: String = r.gtype
	# special room content
	if g == "start":
		wall(W, r, "door_stairs", cx + 0.5, 0, -26)
		r.spawn = [cx + 0.5, cy + 0.9]
		decal(W, r, "rune_big", cx + 0.5, cy + 0.5)
		return
	if g == "portal":
		ent(W, r, {"type": "portal", "cx": cx + 0.5, "cy": maxf(2.75, cy - 1.2)})
		ent(W, r, {"type": "chest", "cx": cx + 2.6, "cy": cy + 2.2, "loot": {"gems": 8 + int(P.n), "heart": true}})
		prop(W, r, sizes, "brazier_pillar", cx - 1.8, maxf(2.6, cy - 1.3))
		decal(W, r, "rune_big", cx + 0.5, cy + 1.2)
		return
	# the plate vault pays more the more plates guard it (tier = plate count)
	var tier: int = int(W.groups.seq.count) if g == "pvault" or g == "hidden" else 4
	if g == "vault" or g == "pvault":
		ent(W, r, {"type": "vault", "cx": cx + 0.5, "cy": cy + 1.0, "tier": tier})
		lava(W, r, maxi(1, cx - 3), cy + 3, 2, 1)
		lava(W, r, cx + 3, cy + 3, 2, 1)
		for o: Array in [[-3, -2], [3.9, -2], [-3, 2.6], [3.9, 2.6]]:
			if free_l.call(int(floor(cx + o[0])), int(floor(cy + o[1]))):
				prop(W, r, sizes, "rune_pillar_c", cx + o[0], cy + o[1])
		decal(W, r, "rune_big", cx + 0.5, cy + 0.4)
		return
	if g == "treasure":
		ent(W, r, {"type": "chest", "cx": cx + 0.5, "cy": cy + 0.9, "loot": {"gems": 6 + int(P.n), "heart": true}})
		prop(W, r, sizes, "brazier_bowl", cx - 1.5, cy + 0.7)
		prop(W, r, sizes, "brazier_bowl", cx + 2.5, cy + 0.7)
		return
	# key room: every one looks the same (see the JS for the layout)
	if g == "key":
		for c: Array in r.cells:
			W.tileAt[c[1] * cols + c[0]] = "floor_00"
		r.tidy = true
		var rug := func(name: String, x: float, y: float, rw: float, rh: float) -> void:
			W.decals.append({"name": name, "x": (bx + x) * C, "y": (by + y) * C, "w": rw, "h": rh})
		prop(W, r, sizes, "shelf", 0.75, 1.45, {"solid": [62, 30]})
		prop(W, r, sizes, "shelf", 3.95, 1.45, {"solid": [62, 30], "flip": true})
		ent(W, r, {"type": "npc", "cx": 2.35, "cy": 1.75})
		prop(W, r, sizes, "shop_table", 2.35, 2.6, {"solid": [150, 40]})
		ent(W, r, {"type": "shop", "cx": 2.35, "cy": 2.7})
		rug.call("mat", 2.35, 3.45, 170, 112)
		W.lights.append({"x": (bx + 2.35) * C, "y": (by + 1.6) * C, "r": 300, "c": "255,200,140", "f": 2})
		wall(W, r, "banner_1", 5.2, 0, 6, false)
		wall(W, r, "banner_1", 6.8, 0, 6, true)
		var well := ent(W, r, {"type": "well", "cx": 9.2, "cy": 1.55})
		W.lights.append({"x": well.x, "y": float(well.y) - 80, "r": 260, "c": "190,205,245", "f": 1})
		prop(W, r, sizes, "statue_angel", 7.95, 1.6, {"solid": [50, 26], "flip": false})
		prop(W, r, sizes, "statue_angel", 10.45, 1.6, {"solid": [50, 26], "flip": true})
		rug.call("rug_square", 9.2, 2.4, 112, 124)
		ent(W, r, {"type": "key", "key": r.get("iconKey", "C"), "cx": 6, "cy": 5})
		rug.call("rug_red", 6, 5.6, 250, 460)
		for s: int in [-1, 1]:
			prop(W, r, sizes, "candelabra", 6 + s * 1.75, 4.4, {"solid": [26, 18]})
			W.lights.append({"x": (bx + 6 + s * 1.75) * C, "y": (by + 4.4) * C - 100, "r": 260, "c": "255,195,120", "f": 2 + s})
			prop(W, r, sizes, "bench", 6 + s * 2.45, 7, {"solid": [120, 30]})
		prop(W, r, sizes, "statue_monk", 0.9, 8.9, {"solid": [40, 24]})
		W.lights.append({"x": (bx + 6) * C, "y": (by + 4.5) * C, "r": 640, "c": "255,215,170", "f": 0})
		for c: Array in r.cells:
			W.reserved[c[1] * cols + c[0]] = true
		return
	# stairs back up to an earlier floor, chosen when used
	if g == "stairs":
		decal(W, r, "rune_big", cx + 0.5, cy + 1.6)
		ent(W, r, {"type": "stairs", "cx": cx + 0.5, "cy": cy + 0.9})
		return
	if g == "secret" or g == "hidden":
		ent(W, r, {"type": "chest", "cx": cx + 0.5, "cy": cy + 0.9, "loot": {"gems": jround((6 + int(P.n)) * (1 + (tier - 4) * 0.5)), "heart": tier >= 5}, "magic": true})
		ent(W, r, {"type": "gem", "cx": cx - 2, "cy": cy + 2})
		ent(W, r, {"type": "gem", "cx": cx + 3, "cy": cy + 2.2})
		ent(W, r, {"type": "heart", "cx": cx + 0.5, "cy": cy + 3})
		return
	if g == "shrine":
		decal(W, r, "fire_plate", cx + 0.5, cy + 0.9)
		ent(W, r, {"type": "heart", "cx": cx + 0.5, "cy": cy + 1.0})
	if g == "boss":
		var w: int = r.bw
		var h: int = r.bh
		if w >= 20:
			lava(W, r, 1, int(floor(h / 2.0)) - 3, 3, 6)
			lava(W, r, w - 4, int(floor(h / 2.0)) - 3, 3, 6)
		for o: Array in [[-6, -4], [6, -4], [-6, 5], [6, 5]]:
			if free_l.call(int(floor(cx + o[0])), int(floor(cy + o[1]))):
				prop(W, r, sizes, "brazier_demon", cx + 0.5 + o[0], cy + o[1] + 0.8)
		decal(W, r, "rune_big", cx + 0.5, cy + 0.5)
		decal(W, r, "rune_plate", cx - 3, cy + 0.5)
		decal(W, r, "rune_plate", cx + 4, cy + 0.5)
		if P.get("final", false):
			prop(W, r, sizes, "altar", cx + 0.5, 2.5)
			decal(W, r, "rune_small", cx + 0.5, cy + 3.5)
		return
	# pressure plates in reading order: four as a square, five with one in the middle, six as two
	# rows of three; the floor's sequence gives each plate its step
	if r.get("seq", false):
		var seq: Array = W.groups.seq.sequence
		var wide: bool = int(r.bw) > int(r.bh)
		var layout := {
			4: [[-2.5, -1.5], [3.5, -1.5], [-2.5, 2.5], [3.5, 2.5]],
			5: [[-2.5, -1.5], [3.5, -1.5], [0.5, 0.5], [-2.5, 2.5], [3.5, 2.5]],
			6: [[-4.5, -1.5], [0.5, -1.5], [5.5, -1.5], [-4.5, 2.5], [0.5, 2.5], [5.5, 2.5]] if wide else [[-3, -1.5], [0.5, -1.5], [4, -1.5], [-3, 2.5], [0.5, 2.5], [4, 2.5]],
		}
		var spots: Array = layout[seq.size()]
		for k in range(spots.size()):
			var x: float = cx + float(spots[k][0])
			var y: float = cy + float(spots[k][1])
			ent(W, r, {"type": "plate", "cx": x, "cy": y, "group": "seq", "pos": k + 1, "order": seq.find(k + 1) + 1, "on": false})
			for j in range(-1, 2):
				for i in range(-1, 2):
					var k2 := (by + int(floor(y)) + j) * cols + bx + int(floor(x)) + i
					W.occupied[k2] = true
					W.reserved[k2] = true
	if r.get("fireBrazier", false):
		var edge := local.filter(func(c: Array) -> bool:
			return free_l.call(c[0], c[1]) and (not free_l.call(c[0], c[1] - 1) or not free_l.call(c[0] - 1, c[1]) or not free_l.call(c[0] + 1, c[1])) \
				and not near_door(r, bx + c[0] + 0.5, by + c[1] + 0.5, 3))
		var spot: Array = edge[int(floor(rnd.next() * edge.size()))] if not edge.is_empty() else [cx + 2, cy]
		ent(W, r, {"type": "brazier", "cx": spot[0] + 0.5, "cy": spot[1] + 0.75, "group": "feuer", "lit": false})
	# terrain features, densest in big rooms and on deep floors
	if big and rnd.next() < float(P.holes):
		for k in range(6):
			var hw := 2 + int(floor(rnd.next() * 3))
			var hh := 2 + int(floor(rnd.next() * 2))
			var spot: Variant = try_rect.call(hw, hh, 1, 30)
			if spot == null:
				continue
			var before: Array = spot
			for j in range(hh):
				for i in range(hw):
					var gi := (by + int(before[1]) + j) * cols + bx + int(before[0]) + i
					W.grid[gi] = 0
					W.roomAt[gi] = -1
					W.holeAt[gi] = 1
			if not _room_connected(W, r):
				for j in range(hh):
					for i in range(hw):
						var gi := (by + int(before[1]) + j) * cols + bx + int(before[0]) + i
						W.grid[gi] = 1
						W.roomAt[gi] = r.index
						W.holeAt[gi] = 0
			else:
				var holes: Array = r.get("holes", [])
				holes.append([before[0], before[1], hw, hh])
				r.holes = holes
				if rnd.next() < 0.5:
					wall(W, r, "cage_hang", int(before[0]) + hw / 2.0, int(before[1]) + hh, 0)
			if r.get("holes", []).size() >= (2 if r.slots.size() >= 3 else 1):
				break
		r.cells = cells_of(W, r)
	var lava_budget := jround(float(P.lava) * (2.4 if big else 1.2) + rnd.next() * 0.8)
	for k in range(lava_budget):
		var lw := 2 + int(floor(rnd.next() * 3))
		var lh := 1 + int(floor(rnd.next() * 2))
		var spot: Variant = try_rect.call(lw, lh, 0, 40)
		if spot != null:
			lava(W, r, spot[0], spot[1], lw, lh)
			if rnd.next() < 0.7:
				var sx: float = int(spot[0]) + (-0.3 if rnd.next() < 0.5 else lw + 0.3)
				if free_l.call(int(floor(sx)), int(spot[1]) + lh - 1):
					prop(W, r, sizes, "spires_lava" if rnd.next() < 0.5 else "rocks_lava", sx + 0.5, int(spot[1]) + lh - 0.2)
	if float(P.get("river", 0)) > 0 and big and not r.has("gate") and not r.get("seq", false) and rnd.next() < float(P.river):
		_river_across(W, r, rnd)
	if rnd.next() < float(P.spikes) * (1.4 if big else 1.0):
		var fw := 3 + int(floor(rnd.next() * 3))
		var fh := 2 + int(floor(rnd.next() * 2))
		var spot: Variant = null
		var k := 0
		while k < 40 and spot == null:
			k += 1
			var c: Array = local[int(floor(rnd.next() * local.size()))]
			var ok := true
			for j in range(c[1], c[1] + fh):
				for i in range(c[0], c[0] + fw):
					var gi := (by + j) * cols + bx + i
					if _room_at(W, gi) != int(r.index) or _grid(W, gi) != 1 or W.reserved.has(gi):
						ok = false
						break
				if not ok:
					break
			if ok:
				spot = c
		if spot != null:
			for j in range(fh):
				for i in range(fw):
					ent(W, r, {"type": "spikes", "phase": (i + j) % 2, "cx": int(spot[0]) + i + 0.5, "cy": int(spot[1]) + j + 0.5})
	var vents := (1 + (1 if big and rnd.next() < 0.5 else 0)) if rnd.next() < float(P.vents) else 0
	for k in range(vents):
		var spot: Variant = try_rect.call(1, 1, 0, 40)
		if spot != null:
			ent(W, r, {"type": "vent", "cx": int(spot[0]) + 0.5, "cy": int(spot[1]) + 0.5, "offset": rnd.next() * 3})
	if rnd.next() < float(P.pits):
		# as in the JS, the loop bound draws a new number on every pass
		var k := 0
		while k < 1 + int(floor(rnd.next() * 3)):
			var spot: Variant = try_rect.call(1, 1, 1, 40)
			if spot != null:
				pit(W, r, spot[0], spot[1])
			k += 1
	if rnd.next() < 0.45:
		var pl: String = ["rune_pillar_a", "rune_pillar_c", "rune_pillar_b", "obelisk"][int(P.circle) % 4]
		for o: Array in [[-3, -2], [4, -2], [-3, 3], [4, 3]]:
			var x := int(floor(cx + o[0]))
			var y := int(floor(cy + o[1]))
			if free_l.call(x, y) and free_l.call(x, y - 1):
				prop(W, r, sizes, pl, x + 0.5, y + 0.75)
	if rnd.next() < 0.5 and not r.get("seq", false):
		decal(W, r, ["rune_big", "rune_small", "rune_plate", "grate"][int(floor(rnd.next() * 4))], cx + 0.5, cy + 0.5)


## A mire band across a big room; lane cells crossing it become bridges.
## True when an entity of the room stands on cell (x, y) (its foot cell, as the way checks read it).
static func _ent_on(W: Dictionary, room: int, x: int, y: int) -> bool:
	for e: Dictionary in W.ents:
		if int(e.room) == room and int(floor(float(e.x) / C)) == x and int(floor((float(e.y) - 10) / C)) == y:
			return true
	return false


static func _river_across(W: Dictionary, r: Dictionary, rnd: Rng) -> bool:
	var cols: int = W.COLS
	var vertical: bool = int(r.bw) > int(r.bh)
	var span: int = r.bw if vertical else r.bh
	var length: int = r.bh if vertical else r.bw
	for k in range(10):
		var at := 3 + int(floor(rnd.next() * (span - 7)))
		var band: Array = []
		var ok := true
		for t in range(length):
			for w in range(2):
				var x := at + w if vertical else t
				var y := t if vertical else at + w
				var gi := (int(r.by) + y) * cols + int(r.bx) + x
				if _room_at(W, gi) != int(r.index):
					continue
				# never over a thing already standing there (a fire bowl in the river could not be reached)
				if _grid(W, gi) != 1 or _ent_on(W, int(r.index), int(r.bx) + x, int(r.by) + y):
					ok = false
					break
				band.append([x, y, r.lanes.has(gi)])
			if not ok:
				break
		if not ok or band.size() < length:
			continue
		for b: Array in band:
			if b[2]:
				bridge(W, r, b[0], b[1], 1, 1, "h" if vertical else "v")
			else:
				lava(W, r, b[0], b[1], 1, 1)
		_merge_bridges(W, r, vertical)
		return true
	return false


static func _merge_bridges(W: Dictionary, r: Dictionary, vertical: bool) -> void:
	var cols: int = W.COLS
	W.decals = W.decals.filter(func(d: Dictionary) -> bool:
		return not (str(d.name).begins_with("bridge") and float(d.get("w", 0)) == C + 20 and float(d.get("h", 0)) == C + 18 \
			and _room_at(W, int(floor(float(d.y) / C)) * cols + int(floor(float(d.x) / C))) == int(r.index)))
	var seen := {}
	for c: Array in cells_of(W, r):
		var gx: int = c[0]
		var gy: int = c[1]
		var k := gy * cols + gx
		if _grid(W, k) != 3 or seen.has(k):
			continue
		var x1 := gx
		var y1 := gy
		while _grid(W, gy * cols + x1 + 1) == 3:
			x1 += 1
		while _grid(W, (y1 + 1) * cols + gx) == 3:
			y1 += 1
		for y in range(gy, y1 + 1):
			for x in range(gx, x1 + 1):
				seen[y * cols + x] = true
		var w := x1 - gx + 1
		var h := y1 - gy + 1
		W.decals.append({"name": "bridge_h" if vertical else "bridge_v", "x": (gx + w / 2.0) * C, "y": (gy + h / 2.0) * C, "w": w * C + 20, "h": h * C + 18})


## Every secret wall without a trigger of its own gets a breakable skull heap in front of it.
static func _place_skull_heaps(W: Dictionary, _sizes: Dictionary) -> void:
	for d: Dictionary in W.doors:
		if d.kind != "secret" or d.has("group"):
			continue
		var r: Dictionary = d.a
		var cx := 0.0
		var cy := 0.0
		if d.dir == "h":
			var x: int = int(d.x0) - 1 if int(r.bx) < int(d.x0) else int(d.x1) + 1
			cx = x + 0.5 - int(r.bx)
			cy = int(d.y0) + 1.35 - int(r.by)
		else:
			var y: int = int(d.y0) - 1 if int(r.by) < int(d.y0) else int(d.y1) + 1
			cx = int(d.x0) + 1 - int(r.bx)
			cy = y + 0.8 - int(r.by)
		ent(W, r, {"type": "skullheap", "cx": cx, "cy": cy, "hp": 3, "door": index_of(W.doors, d)})


## Seals from floor 4 on: 3 per floor (4 from floor 7), one per room, mostly in side rooms.
static func _place_seals(W: Dictionary, _P: Dictionary, rnd: Rng, _sizes: Dictionary) -> void:
	var want := 4 if int(W.n) >= 7 else 3
	var cols: int = W.COLS
	var rooms: Array = W.rooms.filter(func(r: Dictionary) -> bool: return r.type == "combat" and not r.get("seq", false) and r.cells.size() > 40)
	var side := shuffle(rooms.filter(func(r: Dictionary) -> bool: return not r.get("onPath", false)), rnd)
	var path := shuffle(rooms.filter(func(r: Dictionary) -> bool: return r.get("onPath", false)), rnd)
	var picks: Array = side.slice(0, want - 1)
	picks.append_array(path.slice(0, 1))
	while picks.size() < want and side.size() + path.size() > picks.size():
		var more: Variant = null
		for r: Dictionary in side + path:
			if not _has_same(picks, r):
				more = r
				break
		if more == null:
			break
		picks.append(more)
	for r: Dictionary in picks:
		var free: Array = r.cells.filter(func(c: Array) -> bool:
			var k: int = c[1] * cols + c[0]
			if _grid(W, k) != 1 or W.occupied.has(k) or near_door(r, c[0] + 0.5, c[1] + 0.5, 3):
				return false
			for nd: Array in N4:
				var k2: int = (c[1] + nd[1]) * cols + c[0] + nd[0]
				if _room_at(W, k2) != int(r.index) or _grid(W, k2) != 1:
					return false
			return true)
		if free.is_empty():
			continue
		var c: Array = free[int(floor(rnd.next() * free.size()))]
		ent(W, r, {"type": "seal", "cx": c[0] + 0.5 - int(r.bx), "cy": c[1] + 0.8 - int(r.by), "hp": 8})
		r.seal = true


## The boss gate's approach (carpet and the cells beside it) stays free of hazards and clutter.
static func _reserve_gate(W: Dictionary, r: Dictionary) -> void:
	var d: Dictionary = r.gate
	var gx: float = float(d.cx) / C
	var top: int = int(d.y1) + 1
	for y in range(top, top + 4):
		for x in range(int(floor(gx - 4)), int(ceil(gx + 4))):
			var k := y * int(W.COLS) + x
			if _room_at(W, k) == int(r.index):
				W.occupied[k] = true
				W.reserved[k] = true


## Two banners right beside the boss gate, two torches further out, a short carpet in front.
static func _dress_boss_gate(W: Dictionary, r: Dictionary) -> void:
	var d: Dictionary = r.gate
	var gx: float = float(d.cx) / C
	var top: int = int(d.y1) + 1
	var cols: int = W.COLS
	var on_wall := func(x: float) -> bool: return _room_at(W, top * cols + int(floor(x))) == int(r.index) and _grid(W, (top - 1) * cols + int(floor(x))) == 0
	for pair: Array in [["boss_banner", 1.85], ["wall_torch_hook", 3.05]]:
		for side: int in [-1, 1]:
			var x: float = gx + float(pair[1]) * side
			if not on_wall.call(x):
				continue
			var w := {"name": pair[0], "x": x * C, "y": top * C - 68, "flip": side > 0}
			W.wallDecor.append(w)
			var l: Variant = LIGHT.get(pair[0])
			if l != null:
				W.lights.append({"x": w.x, "y": float(w.y) + 40, "r": float(l[0]) * 1.2, "c": l[1], "f": side * 2})
	W.decals.append({"name": "carpet", "x": d.cx, "y": top * C + 118, "w": 116, "h": 236})


## The trigger of the hidden stairs: the one extinguished torch on a north wall of the room in
## front of the hidden wall, away from its doors, from that wall and from the boss gate.
static func _place_levers(W: Dictionary, rnd: Rng) -> void:
	var cols: int = W.COLS
	for d: Dictionary in W.doors:
		if d.get("group", "") != "stiege":
			continue
		var r: Dictionary = d.a
		var spots := cells_of(W, r).filter(func(c: Array) -> bool:
			var k: int = c[1] * cols + c[0]
			return _grid(W, k) == 1 and _grid(W, k - cols) == 0 and _room_at(W, k - cols) < 0 \
				and not near_door(r, c[0] + 0.5, c[1] + 0.5, 2.6) and _hyp((c[0] + 0.5) * C - float(d.cx), (c[1] + 0.5) * C - float(d.cy)) > 4 * C \
				and not (r.has("gate") and absf((c[0] + 0.5) * C - float(r.gate.cx)) < 5.5 * C))
		var pool: Array = spots if not spots.is_empty() else cells_of(W, r).filter(func(c: Array) -> bool:
			var k: int = c[1] * cols + c[0]
			return _grid(W, k) == 1 and _grid(W, k - cols) == 0 and not near_door(r, c[0] + 0.5, c[1] + 0.5, 2))
		if pool.is_empty():
			continue
		var c: Array = pool[int(floor(rnd.next() * pool.size()))]
		var lx: float = (c[0] + 0.5) * C
		W.wallDecor = W.wallDecor.filter(func(w: Dictionary) -> bool: return not (absf(float(w.x) - lx) < 1.6 * C and absf(float(w.y) - (c[1] * C - 68)) < C))
		W.ents.append({"type": "lever", "group": "stiege", "x": lx, "y": c[1] * C + 30, "wy": c[1] * C - 68, "room": int(r.index), "lit": false})


## Shared dressing: banners beside north doors, wall decor, corner braziers, clutter, bones.
static func _auto_dress(W: Dictionary, r: Dictionary, sizes: Dictionary) -> void:
	var cols: int = W.COLS
	var n: int = W.n
	var ri: int = r.index
	var rh := func(k: float, s: float) -> float: return hash3(ri * 31 + k, s, 7 + n)
	var walk := func(t: int) -> bool: return t == 1 or t == 2 or t == 3
	var cell := func(x: int, y: int) -> int: return _grid(W, y * cols + x)
	var in_room := func(x: int, y: int) -> bool: return _room_at(W, y * cols + x) == ri
	var free := func(x: int, y: int) -> bool: return in_room.call(x, y) and cell.call(x, y) == 1 and not W.occupied.has(y * cols + x)
	var circle: int = W.theme.circle
	var banner: String = BANNERS[(ri + n) % BANNERS.size()]
	var bx: int = r.bx
	var by: int = r.by
	for d: Dictionary in r.doors:
		if r.has("gate") and is_same(d, r.gate):
			continue
		if d.dir == "v" and in_room.call(int(d.x0), int(d.y1) + 1):
			var lx: float = float(d.cx) / C - bx
			var ly: int = int(d.y1) + 1 - by
			for s: float in [-1.9, 1.9]:
				if in_room.call(int(floor(bx + lx + s)), by + ly) and not in_room.call(int(floor(bx + lx + s)), by + ly - 1):
					wall(W, r, banner, lx + s, ly, 6, s > 0)
	var chains := 0.28 if circle >= 2 else 0.1
	for y in range(by, by + int(r.bh)):
		var x := bx
		while x < bx + int(r.bw):
			if in_room.call(x, y) and not walk.call(cell.call(x, y - 1)):
				var e := x
				while in_room.call(e + 1, y) and not walk.call(cell.call(e + 1, y - 1)):
					e += 1
				var k := x + 1.5
				while k < e:
					var skip := near_door(r, k, y, 2.8) or (r.has("gate") and absf(k - float(r.gate.cx) / C) < 4.6 and y <= int(r.gate.y1) + 2)
					if not skip:
						var v: float = rh.call(float(int(k * 3)), y)
						if r.get("tidy", false):
							# the tidy key room: torches only, none on the north wall
							if y != by:
								wall(W, r, "wall_torch_hook", k - bx, y - by, 6, v > 0.5)
						else:
							var nm := "wall_brazier"
							if v < 0.42 - chains / 2: nm = "wall_torch_hook"
							elif v < 0.6: nm = "chain_swag"
							elif v < 0.6 + chains: nm = "cage_hang"
							elif v < 0.8: nm = "shackle_skull" if v < 0.7 else "shackle_a"
							elif v < 0.92: nm = BANNERS[int(k * 7) % 5]
							wall(W, r, nm, k - bx, y - by, 2 if nm == "cage_hang" else 6, v > 0.5)
					k += 3.4
				x = e + 1
			else:
				x += 1
	if r.get("tidy", false):
		return
	var cells := cells_of(W, r)
	var corners: Array = []
	for c: Array in cells:
		var no: bool = not in_room.call(c[0], c[1] - 1)
		var so: bool = not in_room.call(c[0], c[1] + 1)
		var we: bool = not in_room.call(c[0] - 1, c[1])
		var ea: bool = not in_room.call(c[0] + 1, c[1])
		if (no or so) and (we or ea) and free.call(c[0], c[1]) and not near_door(r, c[0] + 0.5, c[1] + 0.5, 2.6):
			corners.append(c)
	var want := mini(6, 2 + int(floor(r.slots.size() * 1.5)))
	var placed := 0
	for k in range(corners.size()):
		if placed >= want:
			break
		var c: Array = corners[(k * 7 + ri) % corners.size()]
		if not free.call(c[0], c[1]):
			continue
		var near_fire := false
		for p: Dictionary in W.props:
			if BRAZIERS.has(p.name) and _hyp(float(p.x) - (c[0] + 0.5) * C, float(p.y) - (c[1] + 0.9) * C) < 3 * C:
				near_fire = true
				break
		if near_fire:
			continue
		prop(W, r, sizes, BRAZIERS[(ri + placed + circle) % (7 if circle >= 3 else 4)], c[0] + 0.5 - bx, c[1] + 0.88 - by)
		placed += 1
	var edge := cells.filter(func(c: Array) -> bool:
		return free.call(c[0], c[1]) and (not in_room.call(c[0] - 1, c[1]) or not in_room.call(c[0] + 1, c[1]) or not in_room.call(c[0], c[1] - 1) or not in_room.call(c[0], c[1] + 1)) \
			and not near_door(r, c[0] + 0.5, c[1] + 0.5, 2.6))
	var n_clutter := int(floor(edge.size() / float(9 - circle)))
	var clutter: Array = CLUTTER[circle]
	for k in range(n_clutter):
		var c: Array = edge[int(floor(rh.call(k, 11) * edge.size()))]
		if not free.call(c[0], c[1]):
			continue
		var blocked := false
		for p: Dictionary in W.props:
			if p.has("solid") and _hyp(float(p.x) - (c[0] + 0.5) * C, float(p.y) - (c[1] + 0.8) * C) < 1.6 * C:
				blocked = true
				break
		if blocked:
			continue
		var lava_near := false
		for nd: Array in N4:
			if cell.call(c[0] + nd[0], c[1] + nd[1]) == 2:
				lava_near = true
		prop(W, r, sizes, "spires_lava" if lava_near else clutter[int(floor(rh.call(k, 12) * clutter.size()))], c[0] + 0.5 - bx, c[1] + 0.82 - by, {"flip": rh.call(k, 13) < 0.5})
	var floor_cells := cells.filter(func(c: Array) -> bool:
		if not in_room.call(c[0], c[1]) or cell.call(c[0], c[1]) != 1 or W.reserved.has(c[1] * cols + c[0]):
			return false
		for p: Dictionary in W.props:
			if p.has("solid") and p.solid[0] < (c[0] + 1) * C and p.solid[2] > c[0] * C and p.solid[1] < (c[1] + 1) * C and p.solid[3] > c[1] * C:
				return false
		return true)
	var n_bones := int(floor(floor_cells.size() / float(8 - circle)))
	for k in range(n_bones):
		var c: Array = floor_cells[int(floor(rh.call(k, 21) * floor_cells.size()))]
		prop(W, r, sizes, BONES[int(floor(rh.call(k, 22) * BONES.size()))], c[0] + 0.2 + rh.call(k, 23) * 0.6 - bx, c[1] + 0.4 + rh.call(k, 24) * 0.5 - by,
			{"solid": false, "layer": "low", "flip": rh.call(k, 25) < 0.5})


# ---------- no way is ever blocked ----------

static func _way_map(W: Dictionary, r: Dictionary) -> Dictionary:
	var cols: int = W.COLS
	var cost := {}
	var fix := {}
	for c: Array in cells_of(W, r):
		var k: int = c[1] * cols + c[0]
		var g := _grid(W, k)
		if g == 1 or g == 3:
			cost[k] = 0
		elif g == 2:
			cost[k] = 1
			fix[k] = {"lava": true}
	for p: Dictionary in W.props:
		if not p.has("solid"):
			continue
		var b: Array = p.solid
		for k: int in cost.keys():
			var x := k % cols
			var y := k / cols
			if b[0] < x * C + 76 and b[2] > x * C + 20 and b[1] < y * C + 92 and b[3] > y * C + 40:
				cost[k] = 1
				var f: Dictionary = fix.get(k, {})
				var ps: Array = f.get("props", [])
				ps.append(p)
				f.props = ps
				fix[k] = f
	for e: Dictionary in W.ents:
		if int(e.room) != int(r.index):
			continue
		var x := int(floor(float(e.x) / C))
		var y := int(floor((float(e.y) - 10) / C))
		if e.type == "pit" or BLOCKS.has(e.type):
			var span: Array = [0] if e.type == "pit" else ([-1, 0, 1] if int(BLOCKS[e.type]) != 0 else [0])
			var keep: bool = USE.has(e.type) and e.type != "seal" and e.type != "skullheap"
			for dx: int in span:
				var k := y * cols + x + dx
				if not cost.has(k):
					continue
				cost[k] = maxi(int(cost[k]), 50 if keep else 1)
				var f: Dictionary = fix.get(k, {})
				var es: Array = f.get("ents", [])
				es.append(e)
				f.ents = es
				fix[k] = f
	return {"cost": cost, "fix": fix}


static func _room_targets(W: Dictionary, r: Dictionary) -> Array:
	var cols: int = W.COLS
	var out: Array = []
	var cells := cells_of(W, r)
	for d: Dictionary in r.doors:
		var best := -1
		var bd := 1e9
		for c: Array in cells:
			var dd := _hyp((c[0] + 0.5) * C - float(d.cx), (c[1] + 0.5) * C - float(d.cy))
			if dd < bd:
				bd = dd
				best = c[1] * cols + c[0]
		if best >= 0:
			out.append({"k": best, "near": false})
	for e: Dictionary in W.ents:
		if int(e.room) == int(r.index) and USE.has(e.type):
			out.append({"k": int(floor((float(e.y) - 10) / C)) * cols + int(floor(float(e.x) / C)), "near": true, "e": e})
	return out


static func _way_from(W: Dictionary, cost: Dictionary, from: int) -> Dictionary:
	var cols: int = W.COLS
	var dist := {from: 0}
	var prev := {}
	var open := {from: true}
	while not open.is_empty():
		var k: Variant = null
		for o: int in open:
			if k == null or dist[o] < dist[k]:
				k = o
		open.erase(k)
		var x: int = int(k) % cols
		var y: int = int(k) / cols
		for nd: Array in N4:
			var nb: int = (y + nd[1]) * cols + x + nd[0]
			if not cost.has(nb):
				continue
			var ndist: int = int(dist[k]) + int(cost[nb])
			if not dist.has(nb) or ndist < int(dist[nb]):
				dist[nb] = ndist
				prev[nb] = k
				open[nb] = true
	return {"dist": dist, "prev": prev}


## The targets of a room (doors, things to use) that cannot be reached over free cells.
static func blocked_ways(W: Dictionary, r: Dictionary) -> Array:
	var map := _way_map(W, r)
	var T := _room_targets(W, r)
	if T.is_empty():
		return []
	var cost: Dictionary = map.cost
	var cols: int = W.COLS
	var start: Dictionary = T[0]
	for t: Dictionary in T:
		if not t.near and int(cost.get(t.k, -1)) == 0:
			start = t
			break
	var dist: Dictionary = _way_from(W, cost, start.k).dist
	var out: Array = []
	for t: Dictionary in T:
		var ok := false
		if t.near:
			for k: int in [t.k, t.k + 1, t.k - 1, t.k + cols, t.k - cols]:
				if dist.get(k, -1) == 0 and int(cost.get(k, -1)) == 0:
					ok = true
		else:
			ok = dist.get(t.k, -1) == 0
		if not ok:
			out.append(t)
	return out


## Makes every room passable: mire on the cheapest way becomes a bridge, pits and breakables on it
## go, furniture on it is taken out. Run after all dressing.
static func clear_ways(W: Dictionary) -> Dictionary:
	var cols: int = W.COLS
	for r: Dictionary in W.rooms:
		for round in range(12):
			var bad := blocked_ways(W, r)
			if bad.is_empty():
				break
			var map := _way_map(W, r)
			var cost: Dictionary = map.cost
			var T := _room_targets(W, r)
			var start: Dictionary = T[0]
			for t: Dictionary in T:
				if not t.near and int(cost.get(t.k, -1)) == 0:
					start = t
					break
			var prev: Dictionary = _way_from(W, cost, start.k).prev
			var t: Dictionary = bad[0]
			var k: Variant = null
			if t.near:
				for c: int in [t.k + cols, t.k, t.k - 1, t.k + 1, t.k - cols]:
					if prev.has(c) or c == int(start.k):
						k = c
						break
			else:
				k = t.k
			if k == null:
				if t.has("e") and t.e.type != "key":
					var i := index_of(W.ents, t.e)
					W.ents.remove_at(i if i >= 0 else W.ents.size() - 1)
				continue
			var path: Array = []
			while k != null:
				path.append(k)
				k = prev.get(k)
			for i in range(path.size()):
				var c: int = path[i]
				var f: Variant = map.fix.get(c)
				if f == null or int(cost[c]) == 0:
					continue
				if f.get("lava", false):
					W.grid[c] = 3
					var nb: Variant = path[i + 1] if i + 1 < path.size() else (path[i - 1] if i > 0 else null)
					var across: bool = nb != null and absi(int(nb) - c) == 1
					W.decals.append({"name": "bridge_h" if across else "bridge_v", "x": (c % cols + 0.5) * C, "y": (c / cols + 0.5) * C, "w": C + 20, "h": C + 18})
				for p: Dictionary in f.get("props", []):
					var i2 := index_of(W.props, p)
					if i2 >= 0:
						W.props.remove_at(i2)
				for e: Dictionary in f.get("ents", []):
					if USE.has(e.type) and e.type != "seal" and e.type != "skullheap":
						continue
					var i2 := index_of(W.ents, e)
					if i2 >= 0:
						W.ents.remove_at(i2)
					if e.type == "pit":
						W.decals = W.decals.filter(func(d: Dictionary) -> bool: return not (d.name == "pit" and absf(float(d.x) - float(e.x)) < 2 and absf(float(d.y) - float(e.y)) < 2))
	return W


# ---------- quickest way to the boss ----------

## Rooms that must be entered on the quickest way to the boss, keys included (null: none).
static func critical_rooms(W: Dictionary) -> Variant:
	var adj := {}
	for r: Dictionary in W.rooms:
		adj[int(r.index)] = []
	for d: Dictionary in W.doors:
		adj[int(d.a.index)].append([int(d.b.index), d])
		adj[int(d.b.index)].append([int(d.a.index), d])
	var start := -1
	var boss := -1
	for r: Dictionary in W.rooms:
		if r.type == "start" and start < 0:
			start = r.index
		if r.type == "boss" and boss < 0:
			boss = r.index
	var pieces := func(g: String) -> Array:
		var out: Array = []
		for e: Dictionary in W.ents:
			if e.get("group", "") == g and not out.has(int(e.room)):
				out.append(int(e.room))
		return out
	var passable := func(d: Dictionary, keys: Dictionary) -> bool:
		return d.kind == "open" or d.kind == "boss" or d.kind == "puzzle" or (d.kind == "lock" and keys.has(d.key))
	var key_rooms := {}
	for r: Dictionary in W.rooms:
		if r.has("drop"):
			key_rooms[r.drop] = int(r.index)
	for e: Dictionary in W.ents:
		if e.type == "key":
			key_rooms[e.key] = int(e.room)
	var bfs := func(from: int, to: int, keys: Dictionary) -> Variant:
		var prev := {from: -1}
		var q: Array = [from]
		var qi := 0
		while qi < q.size():
			var c: int = q[qi]
			qi += 1
			if c == to:
				break
			for pair: Array in adj[c]:
				if not prev.has(pair[0]) and passable.call(pair[1], keys):
					prev[pair[0]] = c
					q.append(pair[0])
		if not prev.has(to):
			return null
		var out: Array = []
		var c := to
		while c != -1:
			out.append(c)
			c = prev[c]
		return out
	var keys := {}
	var need := {start: true}
	for round in range(4):
		var p: Variant = bfs.call(start, boss, keys)
		if p != null:
			for i: int in p:
				need[i] = true
			for k in range(p.size() - 1):
				for pair: Array in adj[p[k + 1]]:
					if pair[0] == p[k] and pair[1].kind == "puzzle":
						for room: int in pieces.call(pair[1].group):
							var pp: Variant = bfs.call(start, room, keys)
							if pp != null:
								for i: int in pp:
									need[i] = true
			return need.keys()
		for k: String in ["A", "C", "B"]:
			if not keys.has(k) and key_rooms.has(k):
				var kp: Variant = bfs.call(start, key_rooms[k], keys)
				if kp != null:
					for i: int in kp:
						need[i] = true
					keys[k] = true
	return null


# ---------- the floor schema of the runtime ----------

static func _r1(v: float) -> float:
	return jround(v * 10) / 10.0


## The floor in the schema of tools/hell_dungeon/bake_floors.js (src/hell/hell_floor_data.gd).
static func to_raw(W: Dictionary) -> Dictionary:
	var cols: int = W.COLS
	var count: int = W.grid.size()
	var grid := PackedByteArray()
	grid.resize(count)
	var holes := PackedByteArray()
	holes.resize(count)
	var tiles := PackedByteArray()
	tiles.resize(count)
	for i in range(count):
		grid[i] = 48 + int(W.grid[i])
		holes[i] = 48 + int(W.holeAt[i])
		var t := TILE_NAMES.find(str(W.tileAt[i]))
		t = maxi(t, 0)
		tiles[i] = (48 + t) if t < 10 else (87 + t)
	var quick: Variant = critical_rooms(W)
	var rooms: Array = []
	for r: Dictionary in W.rooms:
		rooms.append({"index": r.index, "id": r.id, "name": r.name, "kind": r.kind, "type": r.type, "gtype": r.gtype, "icon": r.get("icon", ""), "icon_key": r.get("iconKey", ""),
			"bx": r.bx, "by": r.by, "bw": r.bw, "bh": r.bh, "mobs": r.get("mobs", 0), "drop": r.get("drop", ""), "reward": r.get("reward"),
			"spawn": r.get("spawn"), "cleared": r.cleared, "info": r.get("info", ""), "on_path": r.get("onPath", false), "seq": r.get("seq", false), "tidy": r.get("tidy", false)})
	var doors: Array = []
	for d: Dictionary in W.doors:
		doors.append({"a": int(d.a.index), "b": int(d.b.index), "kind": d.kind, "key": d.get("key", ""), "group": d.get("group", ""), "hidden": d.get("hidden", false), "dir": d.dir,
			"cells": d.cells, "x0": d.x0, "y0": d.y0, "x1": d.x1, "y1": d.y1, "cx": d.cx, "cy": d.cy, "crack_x": d.crackX, "crack_y": d.crackY,
			"boss_gate": d.kind == "lock" and d.get("key", "") == "C" and d.dir == "v" and (d.a.type == "boss" or d.b.type == "boss")})
	var props: Array = []
	for p: Dictionary in W.props:
		props.append({"name": p.get("name", ""), "x": _r1(p.x), "y": _r1(p.y), "flip": p.get("flip", false), "low": p.get("layer", "obj") == "low",
			"solid": (p.solid as Array).map(func(v: float) -> float: return _r1(v)) if p.has("solid") else null})
	var decals: Array = []
	for d: Dictionary in W.decals:
		decals.append({"name": d.name, "x": _r1(d.x), "y": _r1(d.y), "w": d.get("w", 0), "h": d.get("h", 0), "a": d.get("a", 1.0)})
	var wall_decor: Array = []
	for w: Dictionary in W.wallDecor:
		wall_decor.append({"name": w.name, "x": _r1(w.x), "y": _r1(w.y), "flip": w.get("flip", false)})
	var ents: Array = []
	for e: Dictionary in W.ents:
		var o := {"type": e.type, "x": _r1(e.x), "y": _r1(e.y), "room": e.room}
		for k: String in e:
			if not (k in ["type", "x", "y", "room", "cx", "cy"]):
				o[k] = e[k]
		if o.has("wy"):
			o.wy = _r1(o.wy)
		ents.append(o)
	var lights: Array = []
	for l: Dictionary in W.lights:
		lights.append({"x": _r1(l.x), "y": _r1(l.y), "r": l.r, "c": l.c})
	var th: Dictionary = W.theme
	return {"n": W.n, "title": W.title, "circle": W.circle, "final": W.final, "seed": W.seed,
		"theme": {"dark": th.dark, "grade": th.grade, "vignette": th.vignette, "embers": th.embers, "hot": th.hot, "wall_glow": th.wallGlow, "circle": th.circle},
		"boss": W.boss, "diff": W.diff, "cols": cols, "rows": W.ROWS, "cell": int(C),
		"grid": grid.get_string_from_ascii(), "holes": holes.get_string_from_ascii(), "tile_names": TILE_NAMES, "tiles": tiles.get_string_from_ascii(),
		"room_at": Array(W.roomAt), "quick": quick.size() if quick != null else -1,
		"rooms": rooms, "doors": doors, "groups": W.groups, "props": props, "decals": decals, "wall_decor": wall_decor, "ents": ents, "lights": lights}

extends RefCounted
## Pure room and puzzle rules of the hell floors: when a door is shut, how far a
## puzzle group is, the order rule of sequence plates, and which rooms the
## player knows. Works on the dictionaries made by hell_floor_data.gd.


## True when the door blocks the way right now.
static func door_closed(door: Dictionary, rooms: Array, groups: Dictionary, boss_dead: bool) -> bool:
	var kind: String = door.kind
	if kind == "secret":
		return not door.broken
	if rooms[door.a].fight or rooms[door.b].fight:
		return true
	if kind == "lock":
		return not door.unlocked
	if kind == "puzzle":
		return not (groups.get(door.group, {}) as Dictionary).get("solved", false)
	if kind == "boss":
		return not boss_dead
	return false


## Returns Vector2i(done, total) for the pieces (braziers or plates) of a group.
static func group_progress(ents: Array, group: String) -> Vector2i:
	var done := 0
	var total := 0
	for e: Dictionary in ents:
		if e.get("group", "") == group:
			total += 1
			if e.get("lit", false) or e.get("on", false):
				done += 1
	return Vector2i(done, total)


## Steps on a sequence plate. Returns "right", "solved", "wrong" or "ignored".
## A wrong plate switches every plate of the group off again.
static func step_sequence(ents: Array, groups: Dictionary, plate: Dictionary) -> String:
	var group: String = plate.get("group", "")
	var g: Dictionary = groups.get(group, {})
	if g.is_empty() or g.get("solved", false) or plate.get("on", false):
		return "ignored"
	if int(plate.order) == int(g.next):
		plate.on = true
		g.next = int(g.next) + 1
		var p := group_progress(ents, group)
		if p.x == p.y:
			g.solved = true
			return "solved"
		return "right"
	for e: Dictionary in ents:
		if e.get("group", "") == group:
			e.on = false
	g.next = 1
	return "wrong"


## Rooms shown on the map: every visited room and its neighbours behind any
## door except a secret wall that is still closed.
static func known_rooms(doors: Array, visited: Dictionary) -> Dictionary:
	var known := visited.duplicate()
	for d: Dictionary in doors:
		if d.kind == "secret" and not d.broken:
			continue
		if visited.has(d.a):
			known[d.b] = true
		if visited.has(d.b):
			known[d.a] = true
	return known

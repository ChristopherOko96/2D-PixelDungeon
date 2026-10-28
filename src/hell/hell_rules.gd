extends RefCounted
## Pure room and puzzle rules of the hell floors: when a door is shut, how far a
## puzzle group is, the order rule of sequence plates, which rooms the
## player knows, seal blessings, breakable seals and skull heaps, and the clone
## clock. Works on the dictionaries made by hell_floor_data.gd.


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


## Blessings a broken demon seal can grant, in roll order.
const BLESSINGS := ["dmg", "rate", "speed", "range", "heart"]
const BLESSING_TEXT := {
	"dmg": "Höllenfeuer: +1 Schaden",
	"rate": "Schnellfeuer: 15 % schneller schießen",
	"speed": "Glutläufer: 10 % schneller laufen",
	"range": "Weitschuss: 25 % mehr Reichweite",
	"heart": "Herzcontainer: +1 Herz",
}


## Applies one blessing to the hero state (dmg, rate, speed_mul, range, hp,
## max_hp, buffs) with the values of hell_balance.json "blessings"; max_cap
## limits heart containers. Returns the blessing's text.
static func apply_blessing(hero: Dictionary, id: String, cfg: Dictionary, max_cap: int) -> String:
	match id:
		"dmg":
			hero.dmg = float(hero.dmg) + float(cfg.dmg)
		"rate":
			hero.rate = maxf(float(cfg.rate_min), float(hero.rate) * float(cfg.rate_mul))
		"speed":
			hero.speed_mul = float(hero.speed_mul) * float(cfg.speed_mul)
		"range":
			hero.range = float(hero.range) * float(cfg.range_mul)
		"heart":
			hero.max_hp = mini(max_cap, int(hero.max_hp) + int(cfg.heart))
			hero.hp = mini(int(hero.max_hp), int(hero.hp) + int(cfg.heart))
	var text: String = BLESSING_TEXT[id]
	(hero.buffs as Array).append(text)
	return text


## One hit on a seal or skull heap. Returns true when this hit breaks it.
static func hit_breakable(e: Dictionary) -> bool:
	if e.get("broken", false):
		return false
	e.hp = int(e.hp) - 1
	if int(e.hp) > 0:
		return false
	e.broken = true
	return true


## Starts the clone skill: "started", "none" (not owned), "running" (cannot be
## stopped) or "spent" (no time left).
static func start_skill(skill: Dictionary) -> String:
	if not skill.get("owned", false):
		return "none"
	if skill.get("active", false):
		return "running"
	if float(skill.get("left", 0.0)) <= 0.0:
		return "spent"
	skill.active = true
	return "started"


## Runs the clone's clock. Returns true when the time ran out on this tick.
static func tick_skill(skill: Dictionary, dt: float) -> bool:
	if not skill.get("active", false):
		return false
	skill.left = maxf(0.0, float(skill.left) - dt)
	if float(skill.left) > 0.0:
		return false
	skill.active = false
	return true

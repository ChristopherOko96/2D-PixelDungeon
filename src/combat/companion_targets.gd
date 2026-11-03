extends RefCounted
## Autonomous companion combat: acquire around the companion, retain a living
## target regardless of owner distance, continue on local survivors, then follow.
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Profile = preload("res://src/progress/profile.gd")
static var _story_config: Dictionary = {}

## Owner commands can switch to a local visible target, never recall a pet to
## a distant fight. A locked target may move out of sight: movement routes to it.
static func pick(tc: RefCounted, actor: Dictionary, rt: Dictionary, prefer_field: bool = false) -> Dictionary:
	var config: Dictionary = actor.get("info", tc.data.pet)
	var radius := float(config.get("acquire_range_m", tc.data.pet.acquire_range_m)) * float(tc.data.meter_px)
	var living: Array = tc._living().filter(func(e: Dictionary)->bool:return not bool(e.get("asleep",false)) and float(e.get("spawn",0))<=0)
	for enemy: Dictionary in living:
		if tc._eid(enemy) == int(actor.get("target", -1)):
			actor.engaged = true
			return enemy
	var nearby: Array = living.filter(func(e: Dictionary) -> bool: return (bool(actor.get("engaged",false)) or Vector2(e.pos).distance_to(actor.pos) <= radius) and _reachable(tc, actor, e))
	for enemy: Dictionary in nearby:
		if tc._eid(enemy) == int(rt.get("hero_target", -1)):
			actor.engaged = true
			return enemy
	var best := {}
	var distance := INF
	if prefer_field:
		for enemy: Dictionary in nearby:
			var in_field: bool = tc.zones.any(func(z: Dictionary) -> bool: return (str(z.get("talent", "")) == "soul_11" or str(z.get("look", "")) in ["souls", "souls_ring", "souls_trail"]) and float(z.get("delay", 0.0)) <= 0.0 and int(z.owner) == int(actor.owner) and float(z.time) > 0.0 and tc._in_zone(z, enemy))
			var gap := Vector2(enemy.pos).distance_squared_to(actor.pos)
			if in_field and gap < distance:
				distance = gap
				best = enemy
	if not best.is_empty():
		actor.engaged = true
		return best
	for enemy: Dictionary in nearby:
		var gap := Vector2(enemy.pos).distance_squared_to(actor.pos)
		if gap < distance:
			distance = gap
			best = enemy
	actor.engaged = not best.is_empty()
	return best

static func _route(tc: RefCounted, from: Vector2, to: Vector2, radius: float) -> PackedVector2Array:
	if tc.game.has_method("talent_path"): return tc.game.talent_path(from, to, radius)
	return Dungeon.find_path(from, to, radius, tc.game.current_layout)

static func _reachable(tc: RefCounted, actor: Dictionary, enemy: Dictionary) -> bool:
	if not tc._blocked(actor.pos, enemy.pos, 1.0): return true
	var key: int = tc._eid(enemy)
	var clock := float(actor.get("acquire_clock", actor.get("age", 0.0)))
	var cache: Dictionary = actor.get("acquire_paths", {})
	var old: Dictionary = cache.get(key, {})
	if not old.is_empty() and clock < float(old.until) and Vector2(old.from).distance_to(actor.pos) < 16 and Vector2(old.to).distance_to(enemy.pos) < 16: return bool(old.reachable)
	var found := not _route(tc, actor.pos, enemy.pos, float(actor.get("info", {}).get("body_radius", tc.data.pet.radius))).is_empty()
	cache[key] = {"from": Vector2(actor.pos), "to": Vector2(enemy.pos), "until": clock + 0.5, "reachable": found}
	if cache.size() > 16: cache.erase(cache.keys()[0])
	actor.acquire_paths = cache
	return found

## Cached native navigation and the story adapter's swept collision. This never
## teleports a fighting companion or grants damage through walls.
static func follow(tc: RefCounted, actor: Dictionary, goal: Vector2, delta: float, config: Dictionary, speed: float, radius: float) -> void:
	var target := goal
	actor.route_wait = float(actor.get("route_wait", 0.0)) - delta
	if tc._blocked(actor.pos, goal, radius):
		if float(actor.route_wait) <= 0.0 or Vector2(actor.get("route_goal", goal)).distance_to(goal) > float(config.route_retarget):
			actor.route = _route(tc, actor.pos, goal, radius)
			actor.route_goal = goal
			actor.route_wait = float(config.route_every)
		var route: PackedVector2Array = actor.get("route", PackedVector2Array())
		while not route.is_empty() and Vector2(actor.pos).distance_to(route[0]) < float(config.route_near): route.remove_at(0)
		actor.route = route
		if route.is_empty(): return
		target = route[0]
	else: actor.route = PackedVector2Array()
	actor.pos = tc._move(actor.pos, (target - Vector2(actor.pos)).limit_length(speed * delta), radius)

## Same retention rule for legacy story/relic allies. References stay local and
## are discarded when their mob dies/leaves; no story ally state is sent by RPC.
static func story_pick(g: Node, ally: Dictionary) -> Dictionary:
	var locked: Dictionary = ally.get("target_enemy", {})
	for enemy: Dictionary in g.mobs:
		if is_same(enemy, locked) and float(enemy.get("hp", 0.0)) > 0.0:
			ally.engaged = true
			return enemy
	if _story_config.is_empty(): _story_config = Profile.data()
	var distance := INF if bool(ally.get("engaged",false)) else pow(float(_story_config.pet.acquire_range_m) * float(_story_config.meter_px), 2.0)
	var best := {}
	for enemy: Dictionary in g.mobs:
		if float(enemy.get("hp", 0.0)) <= 0.0 or float(enemy.get("spawn", 0.0)) > 0.0: continue
		var gap := Vector2(enemy.p).distance_squared_to(ally.p)
		if gap > distance: continue
		if not story_visible(g, ally.p, enemy.p):
			if g.get("talents") == null: continue
			ally.pos = ally.p
			if not _reachable(g.talents.tc, ally, {"id": int(enemy.get("tid", -1)), "pos": enemy.p}): continue
		distance = gap
		best = enemy
	ally.target_enemy = best
	ally.engaged = not best.is_empty()
	return best

## Legacy relic/subclass allies use the same cached wall-aware pursuit.
static func story_follow(g: Node, ally: Dictionary, goal: Vector2, speed: float, delta: float, radius: float) -> void:
	if g.get("talents") != null:
		ally.pos = ally.p
		ally.acquire_clock = float(ally.get("acquire_clock", 0.0)) + delta
		follow(g.talents.tc, ally, goal, delta, g.talents.data.pet, speed, radius)
		ally.p = ally.pos
		return
	var step := (goal - Vector2(ally.p)).limit_length(speed * delta)
	var next: Vector2 = Vector2(ally.p) + step
	if not g.box_blocked(Rect2(next - Vector2(radius, radius), Vector2(radius * 2, radius)), true): ally.p = next

## Prevents legacy allies from striking/shooting through a wall too.
static func story_visible(g: Node, from: Vector2, to: Vector2) -> bool:
	if g.get("talents") != null: return not g.talents.talent_blocked(from, to, 1.0)
	var steps := maxi(1, ceili(from.distance_to(to) / 8.0))
	for n in range(steps + 1):
		var p := from.lerp(to, float(n) / steps)
		if g.box_blocked(Rect2(p - Vector2.ONE, Vector2.ONE * 2.0), true): return false
	return true

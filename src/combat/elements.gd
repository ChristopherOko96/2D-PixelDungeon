extends RefCounted
## Element reactions that work in the game, not only in the drawing (user
## decision 2026-10-30: all four of the proposed reactions; values in
## src/data/balance.json "element"). The pools are boss_moves' pool zones
## (water, poison, blood, lava, ...); the gas clouds live here.
##   Fire + poison (a pool or a cloud): it explodes, hurts the enemies around
##     it and sets off poison next to it; the poison is used up.
##   Frost + water: Glatteis. Enemies on it slow down and slide; it does not
##     conduct lightning; fire thaws it back to water.
##   Fire or lava + water: the water boils into steam that scalds the enemies
##     in it and blinds them (they cannot shoot).
##   Water + lava: the lava crusts over and is harmless for crust_time s; the
##     water steams away.
## Lightning into a liquid is boss_moves.electrify. Every reaction spares the
## heroes. The clients see them through fx events ("element", do: explode,
## freeze, thaw, steam, crust), the pools' snapshot (crust "cr", charge "ch")
## and the gas clouds (snapshot()).

const PoolPaint = preload("res://src/vfx/pool_paint.gd")

var game: Node
## Gas clouds: {id, mat, pos, radius, timer, length, owner, tick}.
var clouds: Array = []
var _next_id := 1
var _contact_wait := 0.0


func bind(owner: Node) -> void:
	game = owner


## A new room: no clouds left over.
func reset() -> void:
	clouds.clear()


func _rules() -> Dictionary:
	return game.balance.get("element", {})


## A gas cloud of `mat` (vfx_gas.json: poison, smoke, frost, void, steam) at
## `at`, for `time` s. A frost cloud freezes the water under it.
func add_gas(mat: String, at: Vector2, radius: float, time: float, owner := 0) -> Dictionary:
	var cloud := {"id": _next_id, "mat": mat, "pos": at, "radius": radius, "timer": time, "length": time, "owner": owner, "tick": 0.0}
	_next_id += 1
	clouds.append(cloud)
	if mat == "frost": frost_at(at, radius, owner)
	return cloud


## Fire at `at` reaching `radius` (a fireball's burst, burning ground, a fire
## talent, a fire strike, the Testraum's Feuerstoß).
func fire_at(at: Vector2, radius: float, owner := 0) -> void:
	_fire(at, radius, owner, 0)


func _fire(at: Vector2, radius: float, owner: int, depth: int) -> void:
	for zone: Dictionary in _pools_at(at, radius):
		var style := str(zone.style)
		if style == "poison":
			_explode(Vector2(zone.pos), float(zone.radius), owner, depth)
			zone.timer = 0.0
		elif _is_water(style):
			if float(zone.get("frozen", 0.0)) > 0.0:
				zone.frozen = 0.0
				game.add_fx("element", Vector2(zone.pos), float(zone.radius), {"do": "thaw"})
			else:
				_boil(zone, owner)
	for cloud: Dictionary in clouds.duplicate():
		if str(cloud.mat) == "poison" and clouds.has(cloud) and Vector2(cloud.pos).distance_to(at) <= float(cloud.radius) + radius:
			clouds.erase(cloud)
			_explode(Vector2(cloud.pos), float(cloud.radius), owner, depth)


## Frost at `at` reaching `radius`: the water there freezes to Glatteis.
func frost_at(at: Vector2, radius: float, owner := 0) -> void:
	var rules := _rules()
	for zone: Dictionary in _pools_at(at, radius):
		if not _is_water(str(zone.style)): continue
		if float(zone.get("frozen", 0.0)) <= 0.0:
			game.add_fx("element", Vector2(zone.pos), float(zone.radius), {"do": "freeze"})
		zone.frozen = float(rules.get("ice_time", 8.0))
		zone.charge = 0.0
		zone.ice_owner = owner


## Poison going off at `at`: damage to every enemy within the poison's reach
## plus explode_reach, then fire there sets off the next poison.
func _explode(at: Vector2, radius: float, owner: int, depth: int) -> void:
	var rules := _rules()
	var reach := radius + float(rules.get("explode_reach", 20.0))
	for enemy: Dictionary in game.enemies.duplicate():
		if float(enemy.hp) <= 0 or Vector2(enemy.pos).distance_to(at) > reach + float(enemy.radius): continue
		game._damage_enemy(enemy, float(rules.get("explode_damage", 8.0)), (Vector2(enemy.pos) - at).normalized(), owner)
	game.add_fx("element", at, reach, {"do": "explode"})
	if depth < int(rules.get("explode_chain", 6)):
		_fire(at, reach, owner, depth + 1)


## Water boiling: the pool goes, a steam cloud rises where it lay.
func _boil(zone: Dictionary, owner: int) -> void:
	var rules := _rules()
	zone.timer = 0.0
	add_gas("steam", Vector2(zone.pos), float(zone.radius) * float(rules.get("steam_scale", 1.3)), float(rules.get("steam_time", 5.0)), owner)
	game.add_fx("element", Vector2(zone.pos), float(zone.radius), {"do": "steam"})


## Once per host tick in fights: the clouds age and act, Glatteis and crust
## run down, water and lava meet.
func update(delta: float) -> void:
	var rules := _rules()
	for index in range(clouds.size() - 1, -1, -1):
		var cloud: Dictionary = clouds[index]
		cloud.timer = float(cloud.timer) - delta
		if float(cloud.timer) <= 0.0:
			clouds.remove_at(index)
			continue
		cloud.tick = float(cloud.tick) - delta
		var due := float(cloud.tick) <= 0.0
		if due: cloud.tick = 1.0
		match str(cloud.mat):
			"steam":
				for enemy: Dictionary in _enemies_in(Vector2(cloud.pos), float(cloud.radius)):
					enemy.shot_timer = maxf(float(enemy.get("shot_timer", 0.0)), float(rules.get("steam_blind", 0.4)))
					if due: game._damage_enemy(enemy, float(rules.get("steam_damage", 1.0)), Vector2.ZERO, int(cloud.owner), true, false)
			"frost":
				if due: frost_at(Vector2(cloud.pos), float(cloud.radius), int(cloud.owner))
	for zone: Dictionary in game.boss_moves.zones:
		if str(zone.kind) != "pool": continue
		if float(zone.get("crust", 0.0)) > 0.0: zone.crust = float(zone.crust) - delta
		if float(zone.get("frozen", 0.0)) > 0.0:
			zone.frozen = float(zone.frozen) - delta
			_glatteis(zone, rules)
	_contact_wait -= delta
	if _contact_wait <= 0.0:
		_contact_wait = 0.2
		_lava_meets_water()


## Enemies on Glatteis: slowed, and they slide on along their way.
func _glatteis(zone: Dictionary, rules: Dictionary) -> void:
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) <= 0 or not game.boss_moves._in_pool(zone, Vector2(enemy.pos), float(enemy.radius)): continue
		var power := float(rules.get("ice_slow", 0.4)) * (0.5 if bool(enemy.get("boss", false)) else 1.0)
		game.perk_combat._status(enemy, "slow", power, 0.3, int(zone.get("ice_owner", 0)))
		var way: Vector2 = enemy.get("direction", Vector2.ZERO)
		if way.length() > 0.1 and Vector2(enemy.get("knockback", Vector2.ZERO)).length() < 10.0:
			enemy.knockback = way.normalized() * float(rules.get("ice_slide", 40.0))


## Lava and (unfrozen) water touching: the lava crusts, the water boils away.
func _lava_meets_water() -> void:
	var lavas: Array = []
	var waters: Array = []
	for zone: Dictionary in game.boss_moves.zones:
		if str(zone.kind) != "pool" or float(zone.timer) <= 0.0: continue
		if str(zone.style) == "lava": lavas.append(zone)
		elif _is_water(str(zone.style)) and float(zone.get("frozen", 0.0)) <= 0.0: waters.append(zone)
	for lava: Dictionary in lavas:
		for water: Dictionary in waters:
			if float(water.timer) <= 0.0 or not _overlap(lava, water): continue
			lava.crust = float(_rules().get("crust_time", 4.0))
			game.add_fx("element", Vector2(lava.pos).lerp(Vector2(water.pos), 0.5), float(lava.radius), {"do": "crust"})
			_boil(water, int(water.get("hostile", 0)))


## True when two pools touch (their cells, one cell apart at most).
func _overlap(a: Dictionary, b: Dictionary) -> bool:
	if Vector2(a.pos).distance_to(b.pos) > (float(a.radius) + float(b.radius)) * 2.0 + 8.0: return false
	if not a.has("cells") or not b.has("cells"):
		return Vector2(a.pos).distance_to(b.pos) <= float(a.radius) + float(b.radius)
	var other: Dictionary = b.cells
	for q: Vector2i in a.cells:
		for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if other.has(q + d): return true
	return false


## Live pool zones a circle at `at` of `radius` reaches.
func _pools_at(at: Vector2, radius: float) -> Array:
	var found: Array = []
	for zone: Dictionary in game.boss_moves.zones:
		if str(zone.kind) == "pool" and float(zone.timer) > 0.0 and game.boss_moves._touches(zone, at, radius):
			found.append(zone)
	return found


## Liquids that are water for the reactions (vfx_pools.json style liquid, not poison).
func _is_water(style: String) -> bool:
	var materials: Dictionary = PoolPaint.settings().get("materials", {})
	return style != "poison" and materials.has(style) and str(materials[style].get("style", "liquid")) == "liquid"


func _enemies_in(at: Vector2, radius: float) -> Array:
	return game.enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.hp) > 0 and Vector2(enemy.pos).distance_to(at) <= radius + float(enemy.radius) * 0.5)


## The clouds for the clients' gas layer (src/vfx/gas.gd sync).
func snapshot() -> Array:
	var result: Array = []
	for cloud: Dictionary in clouds:
		result.append({"id": int(cloud.id), "k": "gas", "st": str(cloud.mat), "x": Vector2(cloud.pos).x, "y": Vector2(cloud.pos).y, "r": float(cloud.radius),
			"p": clampf(1.0 - float(cloud.timer) / maxf(float(cloud.length), 0.01), 0.0, 1.0), "L": float(cloud.length), "d": 1.0})
	return result

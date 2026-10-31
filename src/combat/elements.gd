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
const ElementRules = preload("res://src/combat/element_rules.gd")

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


## The reaction values: element_rules.json's, the crypt's own balance.json "element" over them.
func _rules() -> Dictionary:
	return ElementRules.reactions(game.balance.get("element", {}))


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
			# used up first: the blast's own fire must not find this pool again
			zone.timer = 0.0
			_explode(Vector2(zone.pos), float(zone.radius), owner, depth)
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


## A shot of fire flying at `at`: poison gas it flies through goes off (the
## fumes catch); the pools under it are untouched (it is in the air).
func fire_passes(at: Vector2, owner := 0) -> void:
	for cloud: Dictionary in clouds.duplicate():
		if str(cloud.mat) == "poison" and clouds.has(cloud) and Vector2(cloud.pos).distance_to(at) <= float(cloud.radius) * 0.85:
			clouds.erase(cloud)
			_explode(Vector2(cloud.pos), float(cloud.radius), owner, 0)


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
		# what breathing the gas does, to monsters and heroes alike (src/combat/element_rules.gd):
		# steam scalds and blinds the shots, poison poisons, void seals the skills, frost chills
		var rule := ElementRules.gas(str(cloud.mat))
		if not rule.is_empty():
			for enemy: Dictionary in _enemies_in(Vector2(cloud.pos), float(cloud.radius)):
				# a burning one sets poison gas off, a wet one freezes in frost mist (whatever its element)
				combo_enemy(enemy, str(cloud.mat), Vector2(enemy.pos))
				if not clouds.has(cloud): break
				if ElementRules.immune(enemy_tags(enemy), rule): continue
				if rule.has("blind_shots"): enemy.shot_timer = maxf(float(enemy.get("shot_timer", 0.0)), float(rule.blind_shots))
				if due and rule.has("enemy_hurt"):
					game._damage_enemy(enemy, float(rule.enemy_hurt) * (0.5 if bool(enemy.get("boss", false)) else 1.0), Vector2.ZERO, int(cloud.owner), true, false)
				_status_enemy(enemy, rule, int(cloud.owner))
			if not clouds.has(cloud): continue
			for id: int in game.players:
				var player: Dictionary = game.players[id]
				if int(player.hp) <= 0 or Vector2(player.pos).distance_to(cloud.pos) > float(cloud.radius): continue
				combo_player(id, player, str(cloud.mat))
				if not clouds.has(cloud): break
				if rule.has("hurt"): dot_f(id, player, float(rule.hurt) * delta, str(cloud.mat))
				condition_player(player, rule)
			if not clouds.has(cloud): continue
		match str(cloud.mat):
			"frost":
				if due: frost_at(Vector2(cloud.pos), float(cloud.radius), int(cloud.owner))
	for zone: Dictionary in game.boss_moves.zones:
		if str(zone.kind) != "pool": continue
		if float(zone.get("crust", 0.0)) > 0.0: zone.crust = float(zone.crust) - delta
		if float(zone.get("frozen", 0.0)) > 0.0:
			zone.frozen = float(zone.frozen) - delta
			_glatteis(zone, rules)
	_void_swallows(delta)
	_contact_wait -= delta
	if _contact_wait <= 0.0:
		_contact_wait = 0.2
		_lava_meets_water()


## Fractional damage over time on a hero (half hearts; element_rules.json hurt
## per second): collects in the player's dot_acc and lands whole points through
## game.dot_player; the HUD shows hp minus the debt draining (game.gd hp_f).
func dot_f(id: int, player: Dictionary, amount: float, mat: String) -> void:
	if amount <= 0.0 or int(player.hp) <= 0: return
	# the crypt hero has few hearts next to the story worlds' (balance.json element.hero_dot_scale)
	player.dot_acc = float(player.get("dot_acc", 0.0)) + amount * float(game.balance.get("element", {}).get("hero_dot_scale", 1.0))
	while float(player.dot_acc) >= 1.0 and int(player.hp) > 0:
		player.dot_acc = float(player.dot_acc) - 1.0
		game.dot_player(id, 1, mat)
	if int(player.hp) <= 0: player.dot_acc = 0.0


## The void eats what lies near it (element_rules.json swallow; user decision
## 2026-10-31): a void pool, an active vortex or a pulling talent zone (the
## Singularität) drains the other pools within reach x its radius and draws the
## gas clouds in, shrinking them until they are gone.
func _void_swallows(delta: float) -> void:
	var S: Dictionary = ElementRules.data().get("swallow", {})
	if S.is_empty(): return
	var mouths: Array = []
	for zone: Dictionary in game.boss_moves.zones:
		if str(zone.kind) == "pool" and ElementRules.material(str(zone.style)) == "void" and float(zone.timer) > 0.0:
			mouths.append([Vector2(zone.pos), float(zone.radius)])
		elif str(zone.kind) == "vortex":
			# a boss's vortex and the Testraum's Strudel (its warn phase is the whirl itself)
			mouths.append([Vector2(zone.pos), float(zone.radius)])
	for zone: Dictionary in game.talent_combat.zones:
		if float(zone.get("pull", 0.0)) > 0.0:
			mouths.append([Vector2(zone.pos), float(zone.r)])
	if mouths.is_empty(): return
	var reach_k := float(S.get("reach", 1.6))
	var drain := float(S.get("time", 0.7))
	var pull := float(S.get("pull", 170.0))
	var shrink := float(S.get("cloud_shrink", 28.0))
	for mouth: Array in mouths:
		var at: Vector2 = mouth[0]
		var reach: float = float(mouth[1]) * reach_k
		for zone: Dictionary in game.boss_moves.zones:
			if str(zone.kind) != "pool" or ElementRules.material(str(zone.style)) == "void": continue
			if Vector2(zone.pos).distance_to(at) <= reach + float(zone.radius) and float(zone.timer) > drain:
				zone.timer = drain
		for cloud: Dictionary in clouds:
			if str(cloud.mat) == "void": continue
			var off: Vector2 = at - Vector2(cloud.pos)
			if off.length() > reach + float(cloud.radius): continue
			cloud.pos = Vector2(cloud.pos) + off.limit_length(pull * delta)
			cloud.radius = float(cloud.radius) - shrink * delta
			if float(cloud.radius) < 10.0: cloud.timer = 0.0


## The element tags of an enemy (src/combat/element_rules.gd tags), from the
## words of its kind; kept on it.
static func enemy_tags(enemy: Dictionary) -> Array:
	if not enemy.has("tags"):
		enemy.tags = ElementRules.tags(str(enemy.get("kind", "")))
	return enemy.tags


## The conditions a medium or gas rule puts on an enemy (burn, poison, slow)
## and what it takes away (water douses its burning).
func _status_enemy(enemy: Dictionary, rule: Dictionary, owner: int) -> void:
	var status: Dictionary = rule.get("status", {})
	for kind: String in status:
		var spec: Array = status[kind]
		match kind:
			"burn", "poison", "wet": game.perk_combat._status(enemy, kind, float(spec[0]), float(spec[1]), owner)
			"slow": game.perk_combat._status(enemy, "slow", 1.0 - float(spec[0]), float(spec[1]), owner)
	if bool(rule.get("douse", false)) and enemy.has("statuses"):
		(enemy.statuses as Dictionary).erase("burn")


## What a creature's own condition does with the medium it meets
## (element_rules.json combos): a burning one sets poison off, a wet one
## freezes solid in frost. `burning` / `wet` are the creature's conditions,
## `mat` the medium's material; returns "explode" / "freeze" / "".
static func combo(burning: bool, wet: bool, mat: String) -> String:
	var combos: Dictionary = ElementRules.data().get("combos", {})
	if burning and mat == "poison" and bool(combos.get("burn_ignites_poison", true)): return "explode"
	if wet and mat in ["frost", "ice"] and float(combos.get("freeze_wet", 0.0)) > 0.0: return "freeze"
	return ""


## The combos on an enemy standing in `mat` (a pool's or cloud's material).
func combo_enemy(enemy: Dictionary, mat: String, at: Vector2) -> void:
	var statuses: Dictionary = enemy.get("statuses", {})
	var combos: Dictionary = ElementRules.data().get("combos", {})
	match combo(statuses.has("burn"), statuses.has("wet"), mat):
		"explode": fire_at(Vector2(enemy.pos), float(combos.get("explode_r", 30.0)), 0)
		"freeze":
			if not bool(enemy.get("boss", false)) and not statuses.has("freeze"):
				game.perk_combat._status(enemy, "freeze", 1.0, float(combos.get("freeze_wet", 0.7)), 0)
				game.add_fx("zone_burst", at, float(enemy.radius) + 10.0, {"style": "ice"})


## The combos on a hero standing in `mat`.
func combo_player(id: int, player: Dictionary, mat: String) -> void:
	var effects: Dictionary = player.get("effects", {})
	var combos: Dictionary = ElementRules.data().get("combos", {})
	match combo(effects.has("burn"), effects.has("wet"), mat):
		"explode": fire_at(Vector2(player.pos), float(combos.get("explode_r", 30.0)), id)
		"freeze":
			if not effects.has("freeze"):
				game.player_effects.apply(player, "freeze", float(combos.get("freeze_wet", 0.7)), 1.0)
				game.add_fx("zone_burst", Vector2(player.pos), 24.0, {"style": "ice"})


## The conditions a medium or gas rule puts on a hero (its status table: burn,
## poison, slip with the medium's grip, silence, wet) and what it takes away.
func condition_player(player: Dictionary, rule: Dictionary) -> void:
	var status: Dictionary = rule.get("status", {})
	for kind: String in status:
		var spec: Array = status[kind]
		var value := float(spec[0])
		if kind == "slip": value = float(rule.get("grip", 0.0067))
		game.player_effects.apply(player, kind, float(spec[1]), value)
	if bool(rule.get("douse", false)):
		game.player_effects.clear(player, "burn")


## Enemies on Glatteis: slowed, and they slide on along their way. Heroes on it
## keep their momentum like on any ice (element_rules.json ice).
func _glatteis(zone: Dictionary, rules: Dictionary) -> void:
	var ice := ElementRules.medium("ice")
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if int(player.hp) > 0 and game.boss_moves._in_pool(zone, Vector2(player.pos), 0.0):
			condition_player(player, ice)
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

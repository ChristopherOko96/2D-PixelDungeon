extends RefCounted
## Element reactions in the story worlds (src/hell/hell_game.gd: Hölle,
## Frostgruft, Krypta), the same ones the crypt game has in
## src/combat/elements.gd, on the hell runtime's own things: the puddle zones
## of the monsters (hell_monsters.gd zones kind "puddle", st the liquid), the
## gas clouds (src/vfx/gas.gd) and the pool layer that draws them
## (src/vfx/pool_paint.gd). Values: assets/data/element_rules.json reactions,
## the world's balance "element" block over them.
##   Fire or lava on poison (a puddle or a cloud): it explodes, hurts the
##     monsters round it (hero hits), and sets off poison next to it; the
##     poison is used up.
##   Fire or lava on water: it boils into steam (a cloud that scalds and blinds,
##     element_rules.json gases); on frozen water it thaws the ice.
##   Frost on water: Glatteis; whoever stands on it slides (element_rules.json ice).
##   Water touching lava: the lava crusts over and is harmless for crust_time s;
##     the water steams away.
## Every reaction spares the hero (the fire was his, or he was lucky). Called
## by the monsters' attacks landing in their element (hell_monsters.gd _react)
## and the talents' fire and frost (src/combat/talent_combat.gd _element via
## src/hell/hell_talents.gd elements).

const ElementRules = preload("res://src/combat/element_rules.gd")

var g: Node
var _contact := 0.0
var _steam_serial := 0
var _gulp := 0.0
var _mote_acc := 0.0


func _init(game: Node) -> void:
	g = game


## The reaction values (the world's balance "element" over element_rules.json).
func rules() -> Dictionary:
	return ElementRules.reactions(g.balance.get("element", {}))


## An attack of `element` landing at `at` reaching `r` (world px): fire and
## lava burn, frost freezes, water douses; other elements react with nothing.
func touch(element: String, at: Vector2, r: float) -> void:
	match ElementRules.material(element):
		"fire", "lava":
			fire_at(at, r)
		"ice":
			frost_at(at, r)
		"water":
			water_at(at, r)


## Fire at `at` reaching `r`: poison explodes, water boils, ice thaws.
func fire_at(at: Vector2, r: float, depth := 0) -> void:
	var R := rules()
	for z: Dictionary in _puddles(at, r):
		match ElementRules.material(str(z.get("st", "lava"))):
			"poison":
				_end(z)
				_explode(z.p, float(z.r), depth)
			"water":
				if bool(z.get("frozen", false)):
					# fire on Glatteis: the ice thaws back to water
					z.frozen = false
					_pools_call("thaw_near", [z.p, float(z.r) * 1.2])
					g.monsters._burst_in(z.p - Vector2(0, 10), 8, "frost")
				else:
					_boil(z)
	var gas: RefCounted = g.get("gas")
	if gas != null:
		for c: Dictionary in gas.clouds_of("poison", float(g.state.t)):
			if Vector2(c.at).distance_to(at) <= float(c.r) + r:
				gas.end_cloud(str(c.key), float(g.state.t))
				_explode(c.at, float(c.r), depth)
	if R.is_empty():
		push_warning("element_rules.json has no reactions")


## A shot of fire flying at `p`: poison gas it flies through goes off (the
## fumes catch); water and poison pools under it are untouched (it is in the air).
func fire_passes(p: Vector2) -> void:
	var gas: RefCounted = g.get("gas")
	if gas == null:
		return
	for c: Dictionary in gas.clouds_of("poison", float(g.state.t)):
		if Vector2(c.at).distance_to(p) <= float(c.r) * 0.85:
			gas.end_cloud(str(c.key), float(g.state.t))
			_explode(c.at, float(c.r), 0)


## Frost at `at` reaching `r`: the water lying there freezes to Glatteis
## (drawn by the pool layer, read as ice by the rules).
func frost_at(at: Vector2, r: float) -> void:
	var froze := false
	for z: Dictionary in _puddles(at, r):
		if ElementRules.material(str(z.get("st", "lava"))) == "water" and not bool(z.get("frozen", false)):
			z.frozen = true
			froze = true
			# the water snaps shut: a crack of ice, rime thrown up, a short jolt
			g.monsters._burst_in(z.p - Vector2(0, 8), 14, "frost")
			g.monsters._impact(z.p, "small")
	# steam in the frost condenses: it falls as water where the cloud hung
	var gas: RefCounted = g.get("gas")
	if gas != null:
		var R := rules()
		for c: Dictionary in gas.clouds_of("steam", float(g.state.t)):
			if Vector2(c.at).distance_to(at) <= float(c.r) + r:
				gas.end_cloud(str(c.key), float(g.state.t))
				g.monsters._zone({"kind": "puddle", "p": c.at, "r": float(c.r) * float(R.get("rain_scale", 0.7)), "T": 8.0, "dmg": 0, "m": {"id": "regen", "def": {"name": "Regen"}, "boss": false}, "st": "water"})
				g.monsters._burst_in(c.at - Vector2(0, 20), 12, "frost")
	if froze:
		_pools_call("freeze_near", [at, r])


## Water at `at` reaching `r`: lava there crusts over, fire puddles go out.
func water_at(at: Vector2, r: float) -> void:
	var R := rules()
	for z: Dictionary in _puddles(at, r):
		match ElementRules.material(str(z.get("st", "lava"))):
			"lava":
				z.crust = float(R.get("crust_time", 4.0))
			"fire":
				_end(z)


## Once a frame: crusts run down, lava and water meet.
func update(dt: float) -> void:
	# the Frostgruft has no monster runtime (its mobs are the theme's): only the
	# void's pull on the gas works there, the puddle zones are the hell monsters'
	_void_swallows(dt)
	if g.monsters == null:
		return
	for z: Dictionary in g.monsters.zones:
		if str(z.kind) == "puddle" and float(z.get("crust", 0.0)) > 0.0:
			z.crust = float(z.crust) - dt
	_contact -= dt
	if _contact <= 0.0:
		_contact = 0.2
		_lava_meets_water()
		_floor_meets_puddles()


## The void eats what lies near it (element_rules.json swallow; user decision
## 2026-10-31): a void puddle or a pulling talent zone (the Singularität)
## drains the other puddles within reach x its radius (their matter streams as
## motes into the mouth) and sucks the gas clouds in until they are gone; the
## mouth gulps now and then.
func _void_swallows(dt: float) -> void:
	var S: Dictionary = ElementRules.data().get("swallow", {})
	if S.is_empty():
		return
	var zones: Array = g.monsters.zones if g.monsters != null else []
	var mouths: Array = []
	for z: Dictionary in zones:
		if str(z.kind) == "puddle" and float(z.t) < float(z.T) and ElementRules.material(str(z.get("st", "lava"))) == "void":
			mouths.append([Vector2(z.p), float(z.r)])
	var talents: Variant = g.get("talents")
	if talents != null and talents.get("tc") != null:
		for z: Dictionary in talents.tc.zones:
			if float(z.get("pull", 0.0)) > 0.0:
				mouths.append([Vector2(z.pos), float(z.r)])
	if mouths.is_empty():
		return
	var now := float(g.state.t)
	var reach_k := float(S.get("reach", 1.6))
	var drain := float(S.get("time", 0.7))
	var motes := float(S.get("motes", 9.0))
	var gas: RefCounted = g.get("gas")
	_gulp -= dt
	for mouth: Array in mouths:
		var at: Vector2 = mouth[0]
		var reach: float = float(mouth[1]) * reach_k
		var fed := false
		for z: Dictionary in zones:
			if str(z.kind) != "puddle" or float(z.t) >= float(z.T):
				continue
			var mat := ElementRules.material(str(z.get("st", "lava")))
			if mat == "void" or Vector2(z.p).distance_to(at) > reach + float(z.r):
				continue
			# it drains: its life ends in drain s, its matter streams as motes to the mouth
			if float(z.T) - float(z.t) > drain:
				z.T = float(z.t) + drain
			fed = true
			_mote_acc += motes * dt
			var cols: Array = g.monsters.PX_COL.get("frost" if mat == "ice" else mat, g.monsters.PX_COL.void)
			while _mote_acc >= 1.0:
				_mote_acc -= 1.0
				var from: Vector2 = Vector2(z.p) + Vector2.from_angle(randf() * TAU) * float(z.r) * randf()
				var span := at - from
				var T := clampf(span.length() / 180.0, 0.25, 1.2)
				g.monsters.pfx.append({"p": from, "v": span / T, "z": 6.0, "vz": 0.0, "fly": true, "t": 0.0, "T": T, "c": cols[randi() % cols.size()], "s": 1})
		if gas != null and gas.suck(at, reach, float(S.get("pull", 170.0)), float(S.get("thin", 1.3)), dt, now):
			fed = true
		if fed and _gulp <= 0.0 and g.monsters != null:
			_gulp = float(S.get("gulp", 0.35))
			g.monsters._pixel_burst(at - Vector2(0, 8), 3, g.monsters.PX_COL.void, 70.0, 140.0, 0.4)


## A puddle lying on the world's own liquid floor (tile 2: the hell's lava,
## the Frostgruft's glaze ice): poison on lava goes off, water on lava boils,
## water on ice freezes.
func _floor_meets_puddles() -> void:
	var liquid: Dictionary = g.theme.get("liquid", {})
	var hot := bool(liquid.get("hurt", false))
	var icy := bool(liquid.get("slide", false))
	if not hot and not icy:
		return
	for z: Dictionary in g.monsters.zones.duplicate():
		if str(z.kind) != "puddle" or float(z.t) >= float(z.T):
			continue
		if g._cell(int(floor(float(z.p.x) / g.C)), int(floor(float(z.p.y) / g.C))) != 2:
			continue
		match ElementRules.material(str(z.get("st", "lava"))):
			"poison":
				if hot:
					_end(z)
					_explode(z.p, float(z.r), 0)
			"water":
				if hot and not bool(z.get("frozen", false)):
					_boil(z)
				elif icy and not bool(z.get("frozen", false)):
					z.frozen = true
					_pools_call("freeze_near", [z.p, float(z.r) * 1.2])


## True when the lava at `at` is crusted over (harmless): a crusted lava
## puddle lies there.
func crusted(at: Vector2) -> bool:
	if g.monsters == null:
		return false
	for z: Dictionary in g.monsters.zones:
		if str(z.kind) == "puddle" and float(z.get("crust", 0.0)) > 0.0 and ElementRules.material(str(z.get("st", "lava"))) == "lava" and at.distance_to(z.p) <= float(z.r) * 1.3:
			return true
	return false


## Poison going off at `at`: hero hits to every monster within its reach plus
## explode_reach, the floor cracked, a burst in poison green; the next poison
## next to it goes off too, up to explode_chain times.
func _explode(at: Vector2, r: float, depth: int) -> void:
	var R := rules()
	var scale: float = g.PIXEL_WORLD / 2.0
	var reach := r + float(R.get("explode_reach", 20.0)) * scale
	var hits := float(R.get("explode_hits", 2.5))
	for m: Dictionary in g.mobs:
		if m.hp <= 0.0 or m.p.distance_to(at) > reach + float(m.r):
			continue
		# the blast is fire and shrapnel: a creature of poison is not spared
		m.hp -= hits * float(g.state.dmg) * (0.5 if m.boss else 1.0)
		m.hit = 0.12
		m.k = (m.p - at).normalized() * 160.0
		if g.get("feel") != null:
			g.feel.on_hit(m, m.p - at, false)
	g.monsters._burst_in(at - Vector2(0, 10), 44, "poison")
	g.monsters._crack_floor(at, reach * 0.6, 4, true)
	g.monsters._impact(at, "large")
	g._sound("blast")
	if g.get("feel") != null:
		g.feel.feedback.particles.kick(at / g.feel.scale, reach / g.feel.scale, 1.0)
	if depth < int(R.get("explode_chain", 6)):
		fire_at(at, reach, depth + 1)


## Water boiling: the puddle goes, a steam cloud rises where it lay.
func _boil(z: Dictionary) -> void:
	var R := rules()
	_end(z)
	var gas: RefCounted = g.get("gas")
	if gas != null:
		_steam_serial += 1
		gas.emit("steam:%d" % _steam_serial, "steam", z.p, float(z.r) * float(R.get("steam_scale", 1.3)), float(R.get("steam_time", 5.0)), float(g.state.t))
	g.monsters._burst_in(z.p - Vector2(0, 10), 10, "frost")
	g.monsters._impact(z.p, "small")


## Lava and (unfrozen) water touching: the lava crusts, the water boils away.
func _lava_meets_water() -> void:
	var R := rules()
	var lavas: Array = []
	var waters: Array = []
	for z: Dictionary in g.monsters.zones:
		if str(z.kind) != "puddle" or float(z.t) >= float(z.T):
			continue
		match ElementRules.material(str(z.get("st", "lava"))):
			"lava":
				lavas.append(z)
			"water":
				if not bool(z.get("frozen", false)):
					waters.append(z)
	for lava: Dictionary in lavas:
		for water: Dictionary in waters:
			if float(water.t) >= float(water.T) or Vector2(lava.p).distance_to(water.p) > float(lava.r) + float(water.r):
				continue
			lava.crust = float(R.get("crust_time", 4.0))
			_boil(water)


## The live puddle zones a circle at `at` of `r` reaches.
func _puddles(at: Vector2, r: float) -> Array:
	var out: Array = []
	if g.monsters == null:
		return out
	for z: Dictionary in g.monsters.zones:
		if str(z.kind) == "puddle" and float(z.t) < float(z.T) and at.distance_to(z.p) <= float(z.r) + r:
			out.append(z)
	return out


## Ends a puddle zone now (the monsters' zone loop drops it).
func _end(z: Dictionary) -> void:
	z.t = float(z.T)


func _pools_call(method: String, args: Array) -> void:
	var layer: RefCounted = g._pool_layer() if g.has_method("_pool_layer") else null
	if layer != null and layer.has_method(method):
		layer.callv(method, args)

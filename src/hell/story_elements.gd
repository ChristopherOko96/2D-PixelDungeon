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
##   Lightning into a liquid that conducts (water, poison, blood; Glatteis
##     insulates): the puddle is charged for charge_time s, and every
##     charge_tick s each monster standing in it takes charge_hits hero hits
##     and is stunned charge_stun s (lightning_at; the hero is spared, the
##     lightning is his). The pool crackles while it holds the charge.
##   A shockwave blows the gas away, rings the liquid and throws the monsters
##     back (wave_at); a quake cracks the floor and the ice, knocks rock up and
##     stuns whoever stands in it (quake_at); holy light burns the undead and
##     void creatures and heals the hero standing in it (holy_at). Their values
##     come from the caller (`spec`), the charge's defaults are
##     src/data/balance.json element's (debug Testraum: debug_story_testraum.json
##     elements.kraft).
## Every reaction spares the hero (the fire was his, or he was lucky). Called
## by the monsters' attacks landing in their element (hell_monsters.gd _react)
## and the talents' fire and frost (src/combat/talent_combat.gd _element via
## src/hell/hell_talents.gd elements).

const ElementRules = preload("res://src/combat/element_rules.gd")
const PixelBolt = preload("res://src/vfx/pixel_bolt.gd")
## The liquids that carry lightning (vfx_pools.json style liquid), unless the caller names its own.
const CONDUCTS := ["water", "poison", "blood"]

var g: Node
var _contact := 0.0
var _steam_serial := 0
var _gulp := 0.0
var _mote_acc := 0.0
## Gas cloud keys a hero's void already counted into his Gefüge (each cloud once).
var _eaten_gas := {}
var owned_puddles: Array = []
var _pool_serial := 0

## A new floor/run discards the fallback's authoritative media as monster.reset does.
func reset() -> void:
	owned_puddles.clear()
	_eaten_gas.clear()
	var layer: RefCounted = g._pool_layer()
	if layer != null: layer.sync([], float(g.state.get("t", 0)), "story_media")

## Frost has no monster-zone runtime; real media share the ordinary zone schema.
func media() -> Array:
	return g.monsters.zones if g.monsters != null else owned_puddles

## Creates real material with existing pool rendering and reactions in every theme.
func add_pool(spec: Dictionary) -> void:
	if g.monsters != null:
		g.monsters._zone(spec)
		return
	_pool_serial += 1
	var z := {"id": _pool_serial, "t": 0.0, "tele": 0.0, "done": false, "kind": "puddle", "dmg": 0}
	z.merge(spec, true)
	owned_puddles.append(z)

## Own friendly liquid is safe; an overlapping hostile pool still takes precedence.
func safe_medium(at: Vector2, material: String) -> bool:
	var friendly := false
	for z: Dictionary in media():
		if str(z.get("kind", "")) != "puddle" or float(z.t) >= float(z.T) or ElementRules.material(str(z.get("st", ""))) != ElementRules.material(material) or Vector2(z.p).distance_to(at) > float(z.r): continue
		if not bool(z.get("friend", false)): return false
		friendly = true
	return friendly

## Friendly talent clouds never hide a hostile cloud of the same material.
func safe_gas(at: Vector2, mat: String) -> bool:
	if g.gas == null: return false
	var friendly := false
	for cloud: Dictionary in g.gas.clouds_of(mat, float(g.state.t)):
		if Vector2(cloud.at).distance_to(at) > float(cloud.r): continue
		if not str(cloud.key).begins_with("fx:necro:"): return false
		friendly = true
	return friendly

func _burst(at: Vector2, count: int, element: String) -> void:
	if g.monsters != null: g.monsters._burst_in(at, count, element)
	elif g.has_method("_burst"): g._burst(at, count, true)

func _impact(at: Vector2, size: String) -> void:
	if g.monsters != null: g.monsters._impact(at, size)


func _init(game: Node) -> void:
	g = game


## The reaction values (the world's balance "element" over element_rules.json).
func rules() -> Dictionary:
	return ElementRules.reactions(g.balance.get("element", {}))


## Shared talent gas hook; existing gas renderer/physics owns the cloud.
func add_gas(mat: String, at: Vector2, radius: float, time: float, _owner := 0) -> Dictionary:
	if g.gas == null: return {}
	_steam_serial += 1
	g.gas.emit("necro:%d" % _steam_serial, mat, at, radius, time, float(g.state.t))
	return {"mat": mat, "pos": at, "radius": radius}


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
		"void":
			void_at(at, r)


## Fire at `at` reaching `r`: poison explodes, water boils, ice thaws. The
## third argument is the caster (talent_combat.gd _element passes its owner),
## unused here: a chain of explosions runs through _fire_at with its depth.
func fire_at(at: Vector2, r: float, _owner := 0) -> void:
	_fire_at(at, r, 0)


func _fire_at(at: Vector2, r: float, depth: int) -> void:
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
					if g.sound != null: g.sound.at("react_thaw", Vector2(z.p))
					_pools_call("thaw_near", [z.p, float(z.r) * 1.2])
					_burst(z.p - Vector2(0, 10), 8, "frost")
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
			if g.sound != null: g.sound.at("react_ignite", Vector2(c.at))
			_explode(c.at, float(c.r), 0)


## Frost at `at` reaching `r`: the water lying there freezes to Glatteis
## (drawn by the pool layer, read as ice by the rules).
func frost_at(at: Vector2, r: float, _owner := 0) -> void:
	var froze := false
	for z: Dictionary in _puddles(at, r):
		if ElementRules.material(str(z.get("st", "lava"))) == "water" and not bool(z.get("frozen", false)):
			z.frozen = true
			froze = true
			if g.sound != null: g.sound.at("react_freeze", Vector2(z.p))
			# the water snaps shut: a crack of ice, rime thrown up, a short jolt
			_burst(z.p - Vector2(0, 8), 14, "frost")
			_impact(z.p, "small")
	# steam in the frost condenses: it falls as water where the cloud hung
	var gas: RefCounted = g.get("gas")
	if gas != null:
		var R := rules()
		for c: Dictionary in gas.clouds_of("steam", float(g.state.t)):
			if Vector2(c.at).distance_to(at) <= float(c.r) + r:
				gas.end_cloud(str(c.key), float(g.state.t))
				add_pool({"kind": "puddle", "p": c.at, "r": float(c.r) * float(R.get("rain_scale", 0.7)), "T": 8.0, "dmg": 0, "m": {"id": "regen", "def": {"name": "Regen"}, "boss": false}, "st": "water"})
				_burst(c.at - Vector2(0, 20), 12, "frost")
	if froze:
		_pools_call("freeze_near", [at, r])


## Water at `at` reaching `r`: lava there crusts over, fire puddles go out.
func water_at(at: Vector2, r: float, _owner := 0) -> void:
	var R := rules()
	for z: Dictionary in _puddles(at, r):
		match ElementRules.material(str(z.get("st", "lava"))):
			"lava":
				z.crust = float(R.get("crust_time", 4.0))
				if g.sound != null: g.sound.at("react_crust", Vector2(z.p))
			"fire":
				_end(z)
				if g.sound != null: g.sound.at("react_douse", Vector2(z.p))


## Once a frame: crusts run down, lava and water meet.
func update(dt: float) -> void:
	if g.monsters == null:
		for z: Dictionary in owned_puddles: z.t = float(z.t) + dt
		owned_puddles = owned_puddles.filter(func(z: Dictionary) -> bool: return float(z.t) < float(z.T))
		var entries: Array = []
		for z: Dictionary in owned_puddles:
			entries.append({"id": int(z.id), "k": "pool", "st": str(z.get("st", "blood")), "x": z.p.x, "y": z.p.y, "r": float(z.r), "p": float(z.t) / maxf(0.01, float(z.T)), "L": float(z.T)})
		var layer: RefCounted = g._pool_layer()
		if layer != null: layer.sync(entries, float(g.state.t), "story_media")
	# Frost uses owned_puddles; Hell uses the existing monster-zone lifetime loop.
	_void_swallows(dt)
	for z: Dictionary in media():
		if str(z.kind) == "puddle" and float(z.get("crust", 0.0)) > 0.0:
			z.crust = float(z.crust) - dt
	_step_charges(dt)
	_contact -= dt
	if _contact <= 0.0:
		_contact = 0.2
		_lava_meets_water()
		_floor_meets_puddles()


## A void spell landing at `at` reaching `r` (world px): the puddles there
## (not void) drain away within swallow.time s, their matter streaming as motes
## into the hit, and the gas there is gulped in (a strong short pull). Returns
## what it ate for the caster's Arkanes Gefüge ({element: units}; each puddle
## or cloud once, nothing for `owner` 0; his own Gefüge drops it leaves alone).
func void_at(at: Vector2, r: float, owner := 0) -> Dictionary:
	if g.sound != null: g.sound.at("void_swallow", at)
	var S: Dictionary = ElementRules.data().get("swallow", {})
	var reach := r * float(S.get("reach", 1.6))
	var drain := float(S.get("time", 0.7))
	var ate := {}
	if g.monsters == null:
		for z: Dictionary in _puddles(at, reach):
			if str(z.get("st", "")) == "void" or (owner > 0 and int(z.get("fed_by", 0)) == owner): continue
			z.T = minf(float(z.T), float(z.t) + drain)
			_eat(ate, z, str(z.get("st", "")), float(z.r), owner)
	if g.monsters != null:
		for z: Dictionary in media():
			if str(z.kind) != "puddle" or float(z.t) >= float(z.T): continue
			var mat := ElementRules.material(str(z.get("st", "lava")))
			if mat == "void" or Vector2(z.p).distance_to(at) > reach + float(z.r): continue
			if owner > 0 and int(z.get("fed_by", 0)) == owner: continue
			if float(z.T) - float(z.t) > drain:
				z.T = float(z.t) + drain
			_eat(ate, z, "ice" if bool(z.get("frozen", false)) else mat, float(z.r), owner)
			var cols: Array = g.monsters.PX_COL.get("frost" if mat == "ice" else mat, g.monsters.PX_COL.void)
			for k in range(6):
				var from: Vector2 = Vector2(z.p) + Vector2.from_angle(randf() * TAU) * float(z.r) * randf()
				var T := clampf(from.distance_to(at) / 220.0, 0.2, 0.9)
				g.monsters.pfx.append({"p": from, "v": (at - from) / T, "z": 6.0, "vz": 0.0, "fly": true, "t": 0.0, "T": T, "c": cols[randi() % cols.size()], "s": 1})
	var gas: RefCounted = g.get("gas")
	if gas != null:
		_eat_gas(ate, at, reach, owner)
		gas.suck(at, reach, float(S.get("pull", 170.0)) * 3.0, float(S.get("thin", 1.3)) * 2.0, 0.3, float(g.state.t))
	return ate


## The void eats what lies near it (element_rules.json swallow; user decision
## 2026-10-31): a void puddle or a talent mouth (the Singularität's pull,
## Raumsprung's rift) drains the other puddles within reach x its radius (their
## matter streams as motes into the mouth) and sucks the gas clouds in until
## they are gone; the mouth gulps now and then. A mouth of the Leerenmagier
## (his void puddle: owner, his talent zone) feeds what it eats into his
## Arkanes Gefüge (src/hell/hell_talents.gd feed_all), each thing once; his own
## Gefüge drops (fed_by) it leaves alone. A monster's void feeds nobody.
func _void_swallows(dt: float) -> void:
	var S: Dictionary = ElementRules.data().get("swallow", {})
	if S.is_empty():
		return
	var zones: Array = media()
	var mouths: Array = []
	for z: Dictionary in zones:
		if str(z.kind) == "puddle" and float(z.t) < float(z.T) and ElementRules.material(str(z.get("st", "lava"))) == "void":
			mouths.append([Vector2(z.p), float(z.r), int(z.get("owner", 0))])
	var talents: Variant = g.get("talents")
	if talents != null and talents.get("tc") != null:
		for z: Dictionary in talents.tc.zones:
			if float(z.get("pull", 0.0)) > 0.0 or bool(z.get("mouth", false)):
				mouths.append([Vector2(z.pos), float(z.r), int(z.get("owner", 0))])
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
		var owner: int = int(mouth[2])
		var ate := {}
		var fed := false
		for z: Dictionary in zones:
			if str(z.kind) != "puddle" or float(z.t) >= float(z.T):
				continue
			var mat := ElementRules.material(str(z.get("st", "lava")))
			if mat == "void" or Vector2(z.p).distance_to(at) > reach + float(z.r):
				continue
			if owner > 0 and int(z.get("fed_by", 0)) == owner:
				continue
			# it drains: its life ends in drain s, its matter streams as motes to the mouth
			if float(z.T) - float(z.t) > drain:
				z.T = float(z.t) + drain
			fed = true
			_eat(ate, z, "ice" if bool(z.get("frozen", false)) else mat, float(z.r), owner)
			if g.monsters == null: continue
			_mote_acc += motes * dt
			var cols: Array = g.monsters.PX_COL.get("frost" if mat == "ice" else mat, g.monsters.PX_COL.void)
			while _mote_acc >= 1.0:
				_mote_acc -= 1.0
				var from: Vector2 = Vector2(z.p) + Vector2.from_angle(randf() * TAU) * float(z.r) * randf()
				var span := at - from
				var T := clampf(span.length() / 180.0, 0.25, 1.2)
				g.monsters.pfx.append({"p": from, "v": span / T, "z": 6.0, "vz": 0.0, "fly": true, "t": 0.0, "T": T, "c": cols[randi() % cols.size()], "s": 1})
		_eat_gas(ate, at, reach, owner)
		if gas != null and gas.suck(at, reach, float(S.get("pull", 170.0)), float(S.get("thin", 1.3)), dt, now):
			fed = true
		_feed(owner, ate, at)
		if fed and _gulp <= 0.0 and g.monsters != null:
			_gulp = float(S.get("gulp", 0.35))
			g.monsters._pixel_burst(at - Vector2(0, 8), 3, g.monsters.PX_COL.void, 70.0, 140.0, 0.4)


## Counts a puddle a mouth of hero `owner` ate into `ate` ({element: units},
## src/combat/talent_combat.gd swallow_value through the world's talents):
## each puddle once, its radius in crypt px (the world's art px over 2).
func _eat(ate: Dictionary, z: Dictionary, mat: String, r: float, owner: int) -> void:
	if owner <= 0 or bool(z.get("eaten", false)):
		return
	z.eaten = true
	_count(ate, mat, "pool", r / maxf(0.01, float(g.PIXEL_WORLD) / 2.0))


## Counts the gas clouds within `reach` of `at` a mouth of hero `owner` gulps
## (each cloud once; the materials of element_rules.json gefuege.gas).
func _eat_gas(ate: Dictionary, at: Vector2, reach: float, owner: int) -> void:
	var gas: RefCounted = g.get("gas")
	if owner <= 0 or gas == null:
		return
	var now := float(g.state.t)
	var mats: Array = ElementRules.data().get("gefuege", {}).get("gas", [])
	for mat: Variant in mats:
		for c: Dictionary in gas.clouds_of(str(mat), now):
			if _eaten_gas.has(str(c.key)) or Vector2(c.at).distance_to(at) > reach + float(c.r):
				continue
			_eaten_gas[str(c.key)] = true
			_count(ate, str(mat), "gas", float(c.r))


## Adds what one swallowed thing is worth to `ate` (the world's talents know the Gefüge's rules).
func _count(ate: Dictionary, mat: String, kind: String, r: float) -> void:
	var talents: Variant = g.get("talents")
	if talents == null or not talents.has_method("swallow_value"):
		return
	var got: Array = talents.swallow_value(mat, kind, r)
	if int(got[1]) > 0:
		ate[str(got[0])] = int(ate.get(str(got[0]), 0)) + int(got[1])


## Hands what a mouth of hero `owner` ate to the world's talents (src/hell/hell_talents.gd feed_all).
func _feed(owner: int, ate: Dictionary, at: Vector2) -> void:
	var talents: Variant = g.get("talents")
	if owner > 0 and not ate.is_empty() and talents != null and talents.has_method("feed_all"):
		talents.feed_all(owner, ate, at)


## A puddle lying on the world's own liquid floor (tile 2: the hell's lava,
## the Frostgruft's glaze ice): poison on lava goes off, water on lava boils,
## water on ice freezes.
func _floor_meets_puddles() -> void:
	var liquid: Dictionary = g.theme.get("liquid", {})
	var hot := bool(liquid.get("hurt", false))
	var icy := bool(liquid.get("slide", false))
	if not hot and not icy:
		return
	for z: Dictionary in media().duplicate():
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
					if g.sound != null: g.sound.at("floor_meets", Vector2(z.p), {"set": "freeze"})


## True when the lava at `at` is crusted over (harmless): a crusted lava
## puddle lies there.
func crusted(at: Vector2) -> bool:
	for z: Dictionary in media():
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
	_burst(at - Vector2(0, 10), 44, "poison")
	if g.monsters != null: g.monsters._crack_floor(at, reach * 0.6, 4, true)
	_impact(at, "large")
	if g.sound != null and g.sound.real(): g.sound.at("react_explode", at, {"fallback": ["blast"], "delay": 0.08 * depth, "pitch": 1.0 - 0.04 * depth})
	else: g._sound("blast")
	if g.get("feel") != null:
		g.feel.feedback.particles.kick(at / g.feel.scale, reach / g.feel.scale, 1.0)
	if depth < int(R.get("explode_chain", 6)):
		_fire_at(at, reach, depth + 1)


## Water boiling: the puddle goes, a steam cloud rises where it lay.
func _boil(z: Dictionary) -> void:
	if g.sound != null: g.sound.at("react_boil", Vector2(z.get("p", Vector2.INF)))
	var R := rules()
	_end(z)
	var gas: RefCounted = g.get("gas")
	if gas != null:
		_steam_serial += 1
		gas.emit("steam:%d" % _steam_serial, "steam", z.p, float(z.r) * float(R.get("steam_scale", 1.3)), float(R.get("steam_time", 5.0)), float(g.state.t))
	_burst(z.p - Vector2(0, 10), 10, "frost")
	_impact(z.p, "small")


## Lava and (unfrozen) water touching: the lava crusts, the water boils away.
func _lava_meets_water() -> void:
	var R := rules()
	var lavas: Array = []
	var waters: Array = []
	for z: Dictionary in media():
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
			if g.sound != null: g.sound.at("react_crust", Vector2(lava.p))
			_boil(water)


## The live puddle zones a circle at `at` of `r` reaches.
func _puddles(at: Vector2, r: float) -> Array:
	var out: Array = []
	for z: Dictionary in media():
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


# ---------- lightning, force and light ----------

## The values of a charged puddle: src/data/balance.json element's charge
## block in the story's units (charge_hits: hero hits per tick, as
## explode_hits; boss_share of damage and stun for bosses), the world's
## balance "element" over them, the caller's `spec` over those.
func _charge_rules(spec: Dictionary) -> Dictionary:
	var C := {"charge_time": 3.0, "charge_tick": 0.5, "charge_hits": 0.5, "charge_stun": 0.35, "boss_share": 0.5, "conducts": CONDUCTS}
	var R := rules()
	for key: String in C.keys():
		if R.has(key):
			C[key] = R[key]
	C.merge(spec, true)
	return C


## Lightning striking at `at` reaching `r` (world px): every live puddle there
## of a liquid that conducts (not frozen: Glatteis insulates) is charged for
## charge_time s (its pool crackles all over, src/vfx/pool_paint.gd
## charge_pool; a strike again renews it). Sparks fly off it and arcs creep
## over the liquid at the strike (pool_paint electrify). Returns how many
## puddles it charged.
func lightning_at(at: Vector2, r: float, spec: Dictionary = {}) -> int:
	if g.sound != null: g.sound.at("react_charge", at)
	var C := _charge_rules(spec)
	var conducts: Array = C.conducts
	var now := float(g.state.t)
	var n := 0
	var P := _particles()
	for z: Dictionary in _puddles(at, r):
		var st := str(z.get("st", "lava"))
		if bool(z.get("frozen", false)) or not (st in conducts or ElementRules.material(st) in conducts):
			continue
		if float(z.get("charge", 0.0)) <= 0.0:
			z.charge_tick = 0.0
		z.charge = float(C.charge_time)
		z.charge_rules = C
		n += 1
		_pools_call("charge_pool", [int(z.get("id", -1)), now + float(C.charge_time)])
		if P != null:
			PixelBolt.sparks(P, Vector2(z.p) / _pscale(), 10)
	if n > 0:
		_pools_call("electrify", [at, maxf(r, 24.0)])
	return n


## The charged puddles (lightning_at): every charge_tick s each monster
## standing in one takes charge_hits hero hits and is stunned charge_stun s
## (bosses boss_share), sparks jumping off it (m.zap_t: when it was struck);
## the hero is spared. Frost on the water ends the charge.
func _step_charges(dt: float) -> void:
	for z: Dictionary in media():
		if str(z.kind) != "puddle" or float(z.get("charge", 0.0)) <= 0.0:
			continue
		if float(z.t) >= float(z.T) or bool(z.get("frozen", false)):
			z.charge = 0.0
			continue
		z.charge = float(z.charge) - dt
		z.charge_tick = float(z.get("charge_tick", 0.0)) - dt
		if float(z.charge_tick) > 0.0:
			continue
		var C: Dictionary = z.get("charge_rules", {})
		if C.is_empty():
			C = _charge_rules({})
		z.charge_tick = float(C.charge_tick)
		var zapped := false
		var P := _particles()
		for m: Dictionary in g.mobs:
			if not _stands_in(z, m):
				continue
			hurt_mob(m, float(C.charge_hits), "lightning", Vector2(m.p), float(C.boss_share))
			stun_mob(m, float(C.charge_stun), float(C.boss_share))
			m.zap_t = float(g.state.t)
			zapped = true
			if g.sound != null: g.sound.at("charge_zap", Vector2(m.p))
			if P != null:
				PixelBolt.sparks(P, Vector2(m.p) / _pscale(), 5)
		if zapped:
			_pools_call("electrify", [z.p, float(z.r)])


## True when monster `m` stands in puddle `z` on its feet (not flying, not
## burrowed): on the drawn pool where the pool layer has it, else in its circle.
func _stands_in(z: Dictionary, m: Dictionary) -> bool:
	if float(m.hp) <= 0.0 or bool(m.get("burrowed", false)) or float(m.get("alt", 0.0)) > 20.0:
		return false
	var d := Vector2(m.p).distance_to(z.p)
	var layer: RefCounted = g._pool_layer() if g.has_method("_pool_layer") else null
	if layer != null and layer.has_method("covers"):
		return d <= float(z.r) * 1.6 + float(m.get("r", 0.0)) and bool(layer.covers(Vector2(m.p), str(z.get("st", ""))))
	return d <= float(z.r) + float(m.get("r", 0.0)) * 0.3


## Hurts monster `m` by `hits` hero hits (x state.dmg) of element `el` coming
## from `from` (bosses take `boss_share`): rigged figures through their parts
## (src/hell/drake_rig_host.gd damage, the part nearest `from`), the hit flash
## and the feel's hit. m.last_el / last_el_t name the element for readouts
## (the debug Testraum's damage numbers). Returns the damage dealt (0 for a
## monster that cannot be hit now).
func hurt_mob(m: Dictionary, hits: float, el: String, from: Vector2, boss_share := 0.5) -> float:
	if float(m.hp) <= 0.0 or hits <= 0.0 or not bool(g._hittable(m)):
		return 0.0
	var boss := bool(m.get("boss", false)) or str(m.get("kind", "")) == "boss"
	var amount := hits * float(g.state.dmg) * (boss_share if boss else 1.0)
	var rig: Variant = g.get("drake_rig")
	if rig != null:
		if rig.has_rig(m):
			rig.aim_at(m, from)
		rig.damage(m, amount)
	else:
		m.hp = float(m.hp) - amount
	m.hit = 0.12
	m.last_el = el
	m.last_el_t = float(g.state.t)
	if g.get("feel") != null:
		g.feel.on_hit(m, Vector2(m.p) - from, false)
	return amount


## Stuns monster `m` for `time` s (bosses `boss_share` of it; kit bosses
## stand through it, src/hell/hero_kit.gd tick_mob).
func stun_mob(m: Dictionary, time: float, boss_share := 0.5) -> void:
	if float(m.hp) <= 0.0 or time <= 0.0:
		return
	var boss := bool(m.get("boss", false)) or str(m.get("kind", "")) == "boss"
	m.stun = maxf(float(m.get("stun", 0.0)), time * (boss_share if boss else 1.0))


## A shockwave at `at` reaching `r` (world px): the gas there is blown away
## and thinned (src/vfx/gas.gd impulse, spec.gas its strength), the liquid
## rings and ice cracks (_ripple_ring), loose particles are kicked out, and
## every monster in it on its feet is thrown back by spec.push px/s (less
## with distance; kit bosses stand, bosses boss_share) taking spec.hits hero
## hits. Returns how many monsters it reached.
func wave_at(at: Vector2, r: float, spec: Dictionary = {}) -> int:
	if g.sound != null: g.sound.at("react_wave", at)
	var gas: RefCounted = g.get("gas")
	if gas != null:
		gas.impulse(at, r, float(spec.get("gas", 1.0)))
	_ripple_ring(at, r, float(spec.get("ripple", 1.0)), int(spec.get("rings", 6)))
	_kick(at, r, float(spec.get("kick", 1.0)))
	var share := float(spec.get("boss_share", 0.5))
	var n := 0
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0 or float(m.get("alt", 0.0)) > 20.0:
			continue
		var off: Vector2 = Vector2(m.p) - at
		var d := off.length()
		if d > r + float(m.get("r", 0.0)):
			continue
		var fall := clampf(1.0 - d / maxf(1.0, r), 0.3, 1.0)
		hurt_mob(m, float(spec.get("hits", 0.0)) * fall, "wave", at, share)
		if not m.has("kit"):
			var boss := bool(m.get("boss", false)) or str(m.get("kind", "")) == "boss"
			m.k = (off / d if d > 1.0 else Vector2.RIGHT) * float(spec.get("push", 520.0)) * fall * (share if boss else 1.0)
		n += 1
	if g.monsters != null:
		_impact(at, "small")
	return n


## A quake at `at` reaching `r` (world px): the floor cracks
## (hell_monsters.gd _crack_floor, the particles' floor_crack), rock chunks
## are knocked up and fall back (_pixel_burst, rubble, dust), ice cracks and
## the liquid rings, the gas shudders, and every monster on its feet in it is
## stunned spec.stun s (bosses boss_share) taking spec.hits hero hits.
## Returns how many monsters it stunned.
func quake_at(at: Vector2, r: float, spec: Dictionary = {}) -> int:
	var debris := int(spec.get("debris", 26))
	if g.monsters != null:
		g.monsters._crack_floor(at, r * 0.6, int(spec.get("cracks", 6)), true)
		g.monsters._pixel_burst(at, debris, g.monsters.CHUNK_COL, float(spec.get("debris_speed", 90.0)), float(spec.get("debris_up", 230.0)), 1.1, 2)
		_impact(at, "large")
	var P := _particles()
	if P != null:
		var s := _pscale()
		P.floor_crack(at / s, r * 0.5 / s, 4)
		P.rubble(at / s, int(float(debris) * 0.5), Vector2.ZERO, 150.0)
		P.dust_flat(at / s, r * 0.7 / s, 18)
	_ripple_ring(at, r, float(spec.get("ripple", 1.4)), int(spec.get("rings", 8)))
	var gas: RefCounted = g.get("gas")
	if gas != null:
		gas.impulse(at, r * 0.6, float(spec.get("gas", 0.4)))
	var share := float(spec.get("boss_share", 0.5))
	var n := 0
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0 or float(m.get("alt", 0.0)) > 20.0 or bool(m.get("burrowed", false)):
			continue
		if Vector2(m.p).distance_to(at) > r + float(m.get("r", 0.0)):
			continue
		hurt_mob(m, float(spec.get("hits", 0.0)), "quake", at, share)
		stun_mob(m, float(spec.get("stun", 1.2)), share)
		n += 1
	if g.sound != null and g.sound.real(): g.sound.at("react_quake", at, {"fallback": ["blast"]})
	else: g._sound("blast")
	return n


## Holy light at `at` reaching `r` (world px): undead and void creatures in
## it (_undead) take spec.hits hero hits (bosses boss_share) and are pushed
## out of it a little; the hero standing in it heals spec.heal (half hearts);
## light motes rise (the particles' holy). Returns {hurt: monsters hurt,
## healed: half hearts}.
func holy_at(at: Vector2, r: float, spec: Dictionary = {}) -> Dictionary:
	if g.sound != null: g.sound.at("react_holy", at)
	var P := _particles()
	if P != null:
		P.holy(at / _pscale(), int(spec.get("motes", 28)), r / _pscale())
	var share := float(spec.get("boss_share", 0.5))
	var hurt := 0
	for m: Dictionary in g.mobs:
		if float(m.hp) <= 0.0 or Vector2(m.p).distance_to(at) > r + float(m.get("r", 0.0)) or not _undead(m, spec):
			continue
		if hurt_mob(m, float(spec.get("hits", 2.0)), "holy", at, share) > 0.0:
			hurt += 1
			if not m.has("kit"):
				m.k = (Vector2(m.p) - at).normalized() * float(spec.get("push", 140.0))
	var healed := 0
	var st: Dictionary = g.state
	if float(st.get("dead", 0.0)) <= 0.0 and Vector2(float(g.player.x), float(g.player.y)).distance_to(at) <= r + float(spec.get("hero_reach", 20.0)):
		var before := int(st.hp)
		st.hp = mini(int(st.max_hp), before + int(spec.get("heal", 2)))
		healed = int(st.hp) - before
	return {"hurt": hurt, "healed": healed}


## True for an undead or void creature: one of spec.tags among its element
## tags (hell_monsters.gd mob_tags), or one of spec.words in its id or name.
func _undead(m: Dictionary, spec: Dictionary) -> bool:
	if g.monsters != null and m.has("cds"):
		var tags: Array = g.monsters.mob_tags(m)
		for t: Variant in spec.get("tags", []):
			if t in tags:
				return true
	var def: Dictionary = m.get("def", {})
	var name := (str(m.get("id", m.get("kind", ""))) + " " + str(def.get("name", ""))).to_lower()
	for w: Variant in spec.get("words", []):
		if name.contains(str(w)):
			return true
	return false


## A blow at `at` reaching `r` rings the liquid round it: at its middle and on
## `rings` points of a ring (src/vfx/pool_paint.gd ripple: water rings, ice
## cracks), and the gas there ripples (src/vfx/gas.gd ripple_near).
func _ripple_ring(at: Vector2, r: float, strength: float, rings: int) -> void:
	_pools_call("ripple_near", [at, r * 0.4, strength])
	for k in range(rings):
		_pools_call("ripple", [at + Vector2.from_angle(TAU * float(k) / float(maxi(1, rings))) * r * 0.6, strength * 0.7])
	var gas: RefCounted = g.get("gas")
	if gas != null:
		gas.ripple_near(at, r, strength)


## Loose particles kicked away from `at` (the crypt particles of the feel).
func _kick(at: Vector2, r: float, strength: float) -> void:
	var P := _particles()
	if P != null:
		P.kick(at / _pscale(), r / _pscale(), strength)


## The crypt particles of the feel (src/vfx/particles.gd: their px are world
## px over feel.scale), null without the feel.
func _particles() -> RefCounted:
	return g.feel.feedback.particles if g.get("feel") != null else null


func _pscale() -> float:
	return float(g.feel.scale) if g.get("feel") != null else 1.0

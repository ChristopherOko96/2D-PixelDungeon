class_name ElementExposure
extends RefCounted
## What standing in a pool or breathing a gas does to a creature (BAUPLAN
## M1c), the same for the hero and every monster in every world:
## - the pool under its feet that counts (ElementRules.top) hurts it, puts its
##   conditions on (burn, poison, slow, wet, slip, silence, WAHN), douses its
##   burning (water), and gives the movement its footing and pull back;
## - a gas cloud thick enough round it does the same, blinds its shots and
##   closes its view;
## - its own condition meets the material (element_rules.json combos): a
##   burning creature sets poison off, a wet one freezes solid in frost;
## - a creature of that element is spared (its tags), so is a dead, burrowed or
##   airborne one, crusted lava burns nobody, and the host may exempt or ward
##   a creature (the Leerenmagier in his void, a drunk potion).
## The rules are assets/data/element_rules.json (mediums, gases, combos and the
## "exposure" block: gas sampling, hurt modes per profile); src/combat/element_rules.gd
## reads them. The kit reaches the game only through its host
## (src/physics_kit/exposure_host.gd, the contract; the story worlds' adapter is
## src/hell/story_exposure_host.gd). It never reads or writes a creature itself.
##
## [codeblock]
## var exposure := ElementExposure.new(my_host)
## # every frame, for every creature (the hero included):
## var res := exposure.step(m, dt)
## m.env = res.medium            # its footing and pull for the movement
## m.blind = maxf(m.blind, res.blind)
## [/codeblock]

const ElementRules := preload("res://src/combat/element_rules.gd")
## The host contract (extend it in a game adapter).
const Host := preload("res://src/physics_kit/exposure_host.gd")
## The timer key of a pool's hurt tick (ExposureHost.timer).
const POOL_TICK := "env_tick"
## The timer key of a gas's hurt tick.
const GAS_TICK := "gas_tick"

## The game's side (extends src/physics_kit/exposure_host.gd).
var host: RefCounted = null
## element_rules.json "exposure" (shared, read-only).
var cfg: Dictionary = {}
## element_rules.json "combos" (shared, read-only).
var combos: Dictionary = {}


## A kit for `the_host`. `rules` replaces element_rules.json's "exposure" and
## "combos" blocks when it holds them (tests); the mediums and gases always
## come from ElementRules.
func _init(the_host: RefCounted = null, rules: Dictionary = {}) -> void:
	host = the_host if the_host != null else Host.new()
	var table: Dictionary = ElementRules.data()
	cfg = rules.get("exposure", table.get("exposure", {}))
	combos = rules.get("combos", table.get("combos", {}))


## A blank result: firm floor, clean air.
static func blank() -> Dictionary:
	return {"medium": {}, "style": "", "gas": {}, "gas_mat": "", "blind": 0.0, "vision": 0.0, "maddening": false, "ignited": "", "skipped": false}


## The profile `name` of the exposure block (its hurt mode, gas sampling,
## combos); the "monster" one for a name the data does not know.
func profile_of(name: String) -> Dictionary:
	var profiles: Dictionary = cfg
	if profiles.has(name) and profiles[name] is Dictionary:
		return profiles[name]
	return profiles.get("monster", {})


## How far round its feet a creature of profile `prof` breathes the gas (world
## px): gas_body (crypt px x world_scale when gas_body_crypt_px) + gas_pad.
func gas_radius(prof: Dictionary) -> float:
	var body := float(prof.get("gas_body", 18.0))
	if bool(prof.get("gas_body_crypt_px", false)):
		body *= float(host.world_scale())
	return body + float(prof.get("gas_pad", 24.0))


## One frame of the element physics on `actor` (dt s). Returns what it met:
## - medium: the pool's rule as it acts on the actor ({} on firm floor, or when
##   it is spared), a private copy carrying "centre" when it pulls: the
##   movement reads slow, slide, grip and pull from it;
## - style: the pool style that counts ("" for none, or crusted lava);
## - gas: the gas rule it breathes ({}; the shared rule, do not write into it)
##   and gas_mat its material ("" for clean air);
## - blind: s it cannot shoot (the gas's blind_shots, 0 for none);
## - vision: how far the gas closes its view (0..1);
## - maddening: the pool carries the void's madness (a host with its own
##   madness clock, the hero's, runs it from this);
## - ignited: "pool" or "gas" when its burning set that poison off ("" none);
## - skipped: nothing was looked at (dead, burrowed or in the air).
func step(actor: Variant, dt: float) -> Dictionary:
	var out := blank()
	if not host.actor_alive(actor) or host.actor_burrowed(actor) or float(host.actor_altitude(actor)) > float(cfg.get("air_above", 20.0)):
		out.skipped = true
		return out
	var prof := profile_of(str(host.profile(actor)))
	var at: Vector2 = host.actor_at(actor)
	var tags: Array = host.actor_tags(actor)
	var under: Array = host.pools_under(at)
	if not under.is_empty():
		var style := ElementRules.top(under)
		var mat := ElementRules.material(style)
		# a burning creature sets the poison it stands in off, whatever its own element
		if combo(actor, mat):
			out.ignited = "pool"
			return out
		out.style = style
		var rule := ElementRules.medium(style)
		# crusted lava (water met it) is cool stone for a while: nothing there
		if mat == "lava" and host.lava_crusted(at):
			out.style = ""
		elif not rule.is_empty() and not host.exempt(actor, mat) and not ElementRules.immune(tags, rule):
			var medium: Dictionary = rule.duplicate()
			# the void pulls towards the middle of its pool
			if rule.has("pull"):
				medium.centre = host.pool_centre(at, style)
			out.medium = medium
			out.maddening = (rule.get("status", {}) as Dictionary).has("mad")
			_harm(actor, prof, rule, style, POOL_TICK, dt)
	# it parts the gas round itself: what it breathes is the cloud at arm's length
	var cloud: Dictionary = host.gas_around(at, gas_radius(prof), int(prof.get("gas_samples", 4)))
	if float(cloud.get("d", 0.0)) >= ElementRules.dense_from():
		var mat := str(cloud.get("mat", ""))
		if combo(actor, mat):
			out.ignited = "gas"
			return out
		out.gas_mat = mat
		var rule := ElementRules.gas(mat)
		if not rule.is_empty() and not host.exempt(actor, mat) and not ElementRules.immune(tags, rule):
			out.gas = rule
			out.blind = float(rule.get("blind_shots", 0.0))
			out.vision = float(rule.get("vision", 0.0))
			_harm(actor, prof, rule, mat, GAS_TICK, dt)
	return out


## What the actor's own condition does with `material`, the one it meets
## (element_rules.json combos): burning, it sets poison off (true: the host
## ignited it, the pool or cloud is gone); wet, frost (the profile's
## freeze_on) freezes it solid for combos.freeze_wet s, never a boss.
func combo(actor: Variant, material: String) -> bool:
	if material == "poison" and bool(combos.get("burn_ignites_poison", true)) and host.has_status(actor, "burn"):
		if host.ignite(host.actor_at(actor), float(combos.get("explode_r", 30.0)) * float(host.world_scale())):
			return true
	var freeze := float(combos.get("freeze_wet", 0.0))
	if freeze <= 0.0 or not host.has_status(actor, "wet"):
		return false
	var prof := profile_of(str(host.profile(actor)))
	if material in (prof.get("freeze_on", ["frost"]) as Array) and not host.actor_boss(actor) and not host.has_status(actor, "freeze"):
		host.set_status(actor, "freeze", 1.0, freeze)
		host.clear_status(actor, "wet")
		host.show_combo(actor, "freeze")
	return false


## What a medium or gas `rule` does to the actor (`what`: its pool style or gas
## material): its hurt (on the rule's tick for a ticked profile, continuously
## otherwise), its conditions, its dousing; none of it while the host wards
## the actor against `what`.
func _harm(actor: Variant, prof: Dictionary, rule: Dictionary, what: String, tick_key: String, dt: float) -> void:
	if host.warded(actor, what):
		return
	var key := str(prof.get("hurt_key", "enemy_hurt"))
	var why := str(rule.get("why", str(prof.get("why", "%s")) % what))
	if rule.has(key):
		if bool(prof.get("ticked", true)):
			var left := float(host.timer(actor, tick_key)) - dt
			if left <= 0.0:
				var tick := float(rule.get("tick", 1.0))
				host.set_timer(actor, tick_key, tick)
				var boss := float(prof.get("boss_hurt", 1.0)) if host.actor_boss(actor) else 1.0
				host.hurt(actor, float(rule[key]) * tick * boss, why)
			else:
				host.set_timer(actor, tick_key, left)
		else:
			host.hurt(actor, float(rule[key]) * dt, why)
	var status: Dictionary = rule.get("status", {})
	var own_clock: Array = prof.get("own_clock", [])
	var dots: Array = prof.get("dot_kinds", ["burn", "poison"])
	for kind: String in status:
		if kind in own_clock or host.warded(actor, kind):
			continue
		var spec: Array = status[kind]
		var value := float(spec[0]) * (float(prof.get("dot_scale", 1.0)) if kind in dots else 1.0)
		host.set_status(actor, kind, value, float(spec[1]))
	if bool(rule.get("douse", false)):
		host.clear_status(actor, "burn")

extends "res://src/physics_kit/exposure_host.gd"
## The story worlds' side of ElementExposure (src/physics_kit/element_exposure.gd):
## the adapter between the kit's host contract (src/physics_kit/exposure_host.gd)
## and the world (src/hell/hell_game.gd). One adapter serves all three worlds
## and every creature in them:
## - the hero is g.player (feet x, y); his conditions are FrostCombat.HeroFx
##   (src/hell/hero_fx.gd), his hurt drains through g.dot_hurt_f, a drunk
##   potion wards him (src/hero/story_items.gd immune), the Leerenmagier is
##   exempt from the void (g._void_mind);
## - the Krypta's and the Hölle's monsters are src/hell/hell_monsters.gd
##   dictionaries (tags from its mob_tags), the Frostgruft's are hell_game's
##   themed mobs (theme.mobs; tags set in hell_game _update_mobs); both keep
##   their conditions in their own fields (fire_t, wet_t, stun, ...) through
##   src/hell/hero_kit.gd;
## - the pools are g._pool_layer() (src/vfx/pool_paint.gd materials_at), the
##   gas g.gas (src/vfx/gas.gd around), the reactions g.story_elements
##   (src/hell/story_elements.gd: crusted lava, fire on poison).
## hell_game.gd owns the one kit of a world (exposure()); the kit holds this
## host, never the other way round. Only this file reaches into the world.

const HeroKit = preload("res://src/hell/hero_kit.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")

## The world (src/hell/hell_game.gd).
var g: Node
## element_rules.json exposure.story: the feedback values of this adapter.
var look: Dictionary = {}
## The hero's tick clocks (his profile drains continuously; kept for a ticked one).
var _hero_timers: Dictionary = {}


func _init(game: Node) -> void:
	g = game
	look = (ElementRules.data().get("exposure", {}) as Dictionary).get("story", {})


## True when `actor` is the hero (his player dictionary).
func is_hero(actor: Variant) -> bool:
	return actor is Dictionary and is_same(actor, g.player)


# ---------- the world ----------

func pools_under(at: Vector2) -> Array:
	var layer: RefCounted = g._pool_layer()
	return layer.materials_at(at) if layer != null else []


## Existing friendly Necromancer fields spare their owner; hostile overlaps win.
func pool_exempt(actor: Variant, material: String) -> bool:
	return exempt(actor,material) or (is_hero(actor) and g.story_elements!=null and g.story_elements.safe_medium(actor_at(actor),material))


## Friendly talent gas is safe independently of any liquid under the hero.
func gas_exempt(actor: Variant, material: String) -> bool:
	return exempt(actor,material) or (is_hero(actor) and g.story_elements!=null and g.story_elements.safe_gas(actor_at(actor),material))


func gas_around(at: Vector2, radius: float, samples: int) -> Dictionary:
	var gas: RefCounted = g.get("gas")
	return gas.around(at, radius, samples) if gas != null else {"mat": "", "d": 0.0}


func pool_centre(at: Vector2, style: String) -> Vector2:
	return g._pool_centre(at, style)


func lava_crusted(at: Vector2) -> bool:
	return g.story_elements != null and bool(g.story_elements.crusted(at))


func ignite(at: Vector2, radius: float) -> bool:
	if g.story_elements == null:
		return false
	g.story_elements.fire_at(at, radius)
	return true


func world_scale() -> float:
	return float(g.PIXEL_WORLD) / 2.0


# ---------- the actor ----------

func profile(actor: Variant) -> String:
	return "hero" if is_hero(actor) else "monster"


func actor_at(actor: Variant) -> Vector2:
	if is_hero(actor):
		return Vector2(float(g.player.x), float(g.player.y))
	return actor.p


func actor_alive(actor: Variant) -> bool:
	if is_hero(actor):
		return not g.state.is_empty() and float(g.state.dead) <= 0.0
	return float(actor.hp) > 0.0


func actor_burrowed(actor: Variant) -> bool:
	return not is_hero(actor) and bool(actor.get("burrowed", false))


func actor_altitude(actor: Variant) -> float:
	return 0.0 if is_hero(actor) else float(actor.get("alt", 0.0))


## A hell monster carries boss, a Frostgruft one is of kind "boss".
func actor_boss(actor: Variant) -> bool:
	return not is_hero(actor) and (bool(actor.get("boss", false)) or str(actor.get("kind", "")) == "boss")


func actor_tags(actor: Variant) -> Array:
	if is_hero(actor):
		return []
	if g.monsters != null:
		return g.monsters.mob_tags(actor)
	return actor.get("tags", [])


func exempt(actor: Variant, material: String) -> bool:
	return is_hero(actor) and material == "void" and bool(g._void_mind())


func warded(actor: Variant, what: String) -> bool:
	return is_hero(actor) and g.story_items != null and bool(g.story_items.immune(what))


## The hero's conditions need the world's feel (a bare test world has none).
func has_status(actor: Variant, kind: String) -> bool:
	if is_hero(actor):
		return g.feel != null and HeroFx.has(g, kind)
	match kind:
		# on fire (lava, fire, a burn), not merely poisoned: burn_t is every damage over time
		"burn": return float(actor.get("fire_t", 0.0)) > 0.0
		"wet": return float(actor.get("wet_t", 0.0)) > 0.0
		"freeze": return float(actor.get("stun", 0.0)) > 0.0
	return false


func set_status(actor: Variant, kind: String, value: float, seconds: float) -> void:
	if is_hero(actor):
		if g.feel != null:
			HeroFx.apply(g, kind, seconds, value)
		return
	var m: Dictionary = actor
	match kind:
		"burn":
			HeroKit.burn_mob(m, value, seconds)
			if float(m.get("wet_t", 0.0)) <= 0.0:
				m.fire_t = maxf(float(m.get("fire_t", 0.0)), seconds)
		"poison":
			# its own damage over time: wet does not stop it, water does not wash it off
			HeroKit.poison_mob(m, value, seconds)
		"slow":
			HeroKit.slow_mob(g, m, 1.0 - value, seconds)
		"wet":
			m.wet_t = maxf(float(m.get("wet_t", 0.0)), seconds)
		"mad":
			ElementRules.madden(m, seconds, actor_tags(m))
		"freeze":
			m.stun = seconds


func clear_status(actor: Variant, kind: String) -> void:
	if is_hero(actor):
		if g.feel == null:
			return
		HeroFx.clear(g, kind)
		if kind == "burn":
			g.state.burn = 0.0
		return
	match kind:
		"burn":
			actor.burn_t = 0.0
			actor.fire_t = 0.0
		"wet":
			actor.wet_t = 0.0


func hurt(actor: Variant, amount: float, why: String) -> void:
	if is_hero(actor):
		g.dot_hurt_f(amount, why)
		return
	actor.hp -= amount * float(g.state.dmg)
	actor.hit = float(look.get("hit_flash", 0.12))
	if g.feel != null:
		g.feel.on_hit(actor, Vector2.ZERO, false)


func timer(actor: Variant, key: String) -> float:
	if is_hero(actor):
		return float(_hero_timers.get(key, 0.0))
	return float(actor.get(key, 0.0))


func set_timer(actor: Variant, key: String, seconds: float) -> void:
	if is_hero(actor):
		_hero_timers[key] = seconds
	else:
		actor[key] = seconds


## Frozen solid: frost pixels burst off it (the Hölle's and the Krypta's
## monster pixels; the Frostgruft's ice chips, it has no monster runtime).
func show_combo(actor: Variant, combo: String) -> void:
	if combo != "freeze":
		return
	var bursts: Dictionary = look.get("freeze_burst", {})
	if is_hero(actor):
		if g.monsters != null:
			g.monsters._burst_in(actor_at(actor) - Vector2(0, float(look.get("hero_chest", 40.0))), int(bursts.get("hero", 12)), "frost")
		return
	var at: Vector2 = actor.p - Vector2(0, float(actor.get("cy", 0.0)))
	if g.monsters != null:
		g.monsters._burst_in(at, int(bursts.get("monster", 10)), "frost")
	elif g.get("frost_fx") != null:
		g.frost_fx.shatter(at, int(bursts.get("monster", 10)), float(actor.get("r", 0.0)))

## Steam/smoke occludes monster vision independently from heat/poison resistance.
func blind_sight(actor: Variant, seconds: float) -> void:
	if not is_hero(actor): preload("res://src/combat/enemy_sight.gd").expose(actor,seconds)

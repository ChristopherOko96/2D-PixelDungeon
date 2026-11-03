extends RefCounted
## The host contract of ElementExposure (src/physics_kit/element_exposure.gd):
## what the exposure kit asks of a game to let pools and gas act on its
## creatures, and nothing more. A game extends this file in an adapter of its
## own (the story worlds: src/hell/story_exposure_host.gd) and gives it to
## ElementExposure.new(host). Every method has a neutral default, so an empty
## host is a world without pools or gas whose creatures feel nothing.
##
## An "actor" is whatever handle the game uses for a creature (the story
## worlds pass their monster dictionaries and the hero's player dictionary).
## The kit never reads or writes it itself: it hands it back to these methods.
## Positions are world px. A "style" is a pool's own look name (frost, flesh,
## lava, ...); a "material" is what the rules make of it (ElementRules.material:
## frost is ice, flesh is blood).
##
## [codeblock]
## extends "res://src/physics_kit/exposure_host.gd"
## var lava := Rect2(0, 0, 100, 100)
## func pools_under(at: Vector2) -> Array: return ["lava"] if lava.has_point(at) else []
## func actor_at(actor: Variant) -> Vector2: return actor.p
## func actor_alive(actor: Variant) -> bool: return actor.hp > 0.0
## func hurt(actor: Variant, amount: float, _why: String) -> void: actor.hp -= amount
## [/codeblock]


# ---------- the world ----------

## The pool styles lying under `at` (any order; [] on firm floor).
func pools_under(_at: Vector2) -> Array:
	return []


## The gas round `at`: the thickest cloud on a ring of `radius` px through
## `samples` points and at `at` itself: {"mat": material ("" none), "d": 0..1}.
func gas_around(_at: Vector2, _radius: float, _samples: int) -> Dictionary:
	return {"mat": "", "d": 0.0}


## Where a pull of the pool `style` at `at` draws to (the void: the middle of
## its puddle); `at` itself when the game knows no better.
func pool_centre(at: Vector2, _style: String) -> Vector2:
	return at


## True when the lava at `at` is crusted over (water met it): cool stone for a
## while, nothing burns there.
func lava_crusted(_at: Vector2) -> bool:
	return false


## Sets poison off with fire at `at` reaching `radius` px (a burning creature
## walked into poison). True when the world did (the pool or cloud is gone and
## the kit stops looking at it this frame); false without reactions.
func ignite(_at: Vector2, _radius: float) -> bool:
	return false


## World px per crypt px: the rules' radii (combos.explode_r, a profile's
## gas_body in crypt px) are crypt px and are scaled by this.
func world_scale() -> float:
	return 1.0


# ---------- the actor ----------

## Which profile of element_rules.json exposure the actor follows ("hero",
## "monster", or a game's own): how it breathes gas and how its hurt lands.
func profile(_actor: Variant) -> String:
	return "monster"


## The actor's feet (world px).
func actor_at(_actor: Variant) -> Vector2:
	return Vector2.ZERO


## True while the actor lives (a dead one feels nothing).
func actor_alive(_actor: Variant) -> bool:
	return false


## True while the actor is under the floor (burrowed): no pool or gas reaches it.
func actor_burrowed(_actor: Variant) -> bool:
	return false


## The actor's height above its feet (world px); above exposure.air_above it is
## in the air and no pool or gas reaches it.
func actor_altitude(_actor: Variant) -> float:
	return 0.0


## True for a boss: its hurt is the profile's boss_hurt share, wet never freezes it.
func actor_boss(_actor: Variant) -> bool:
	return false


## The actor's element tags (ElementRules.tags: undead, poison, frost, void,
## fire, hell, ...). A rule whose immune list holds one of them spares it.
func actor_tags(_actor: Variant) -> Array:
	return []


## True when the actor feels nothing at all of `material` there, not even its
## footing or pull (the Leerenmagier in the void).
func exempt(_actor: Variant, _material: String) -> bool:
	return false


## Pool-specific ownership protection; ordinary wards remain shared by default.
func pool_exempt(actor: Variant, material: String) -> bool:
	return exempt(actor,material)


## Gas protection is independent: friendly liquid never hides a hostile cloud.
func gas_exempt(actor: Variant, material: String) -> bool:
	return exempt(actor,material)


## True when nothing of `what` (a pool style, a gas material or a condition
## kind) hurts the actor or puts its condition on, though its footing still
## acts (a drunk potion's after-effect).
func warded(_actor: Variant, _what: String) -> bool:
	return false


## True while the actor has condition `kind`: "burn" (on fire), "wet",
## "freeze" (frozen solid or stunned), or a game's own kind.
func has_status(_actor: Variant, _kind: String) -> bool:
	return false


## Puts condition `kind` on the actor for `seconds` with `value`, the stronger
## and longer holding: "burn" / "poison" = damage per second in the actor's
## own unit (the kit scaled it: half hearts for the hero, hero hits for a
## monster), "slow" = share of its speed it keeps, "freeze" = frozen solid,
## "mad" = WAHN; "wet", "slip", "silence" and others as the rules name them.
## A host ignores the kinds its creatures do not have.
func set_status(_actor: Variant, _kind: String, _value: float, _seconds: float) -> void:
	pass


## Takes condition `kind` off the actor ("burn": water douses it; "wet": it froze).
func clear_status(_actor: Variant, _kind: String) -> void:
	pass


## The actor loses `amount` (the hero: half hearts, fractional, drained
## smoothly; a monster: hero hits, the host multiplies by its hero's damage)
## and shows it. `why` is what the hero reads when it kills him.
func hurt(_actor: Variant, _amount: float, _why: String) -> void:
	pass


## The seconds left on the actor's timer `key` (the kit's tick clocks:
## "env_tick" for the pool, "gas_tick" for the gas); 0 for a new one.
func timer(_actor: Variant, _key: String) -> float:
	return 0.0


## Keeps `seconds` on the actor's timer `key`.
func set_timer(_actor: Variant, _key: String, _seconds: float) -> void:
	pass


## A combination of the actor's own condition with what it met went off and is
## worth showing: "freeze" (wet, frost froze it solid).
func show_combo(_actor: Variant, _combo: String) -> void:
	pass

class_name MadnessRules
extends RefCounted
## The void's mind (assets/data/madness_rules.json), kept apart from the
## element physics (src/combat/element_rules.gd, BAUPLAN M1c):
## - WAHN (madness): a creature standing in a void pool or gas, or hit by a
##   void spell, goes mad: its shots scatter, it staggers sideways and may turn
##   on the nearest other creature; the hero's controls invert after a while
##   inside (hero_mad_step);
## - the Leerenmagier (void_mind) is immune to it;
## - the Leerenmagier's Arkanes Gefüge data (gefuege), read by the talent
##   runtime (src/combat/talent_combat.gd) and the story reactions
##   (src/hell/story_elements.gd).
## Pure rules: no node, no drawing. The worlds call these with their own
## creatures (crypt: src/game.gd; story: src/hell/hell_game.gd,
## src/hell/hell_monsters.gd). src/combat/element_rules.gd keeps forwarders
## under the old names for its callers.
##
## [codeblock]
## if MadnessRules.madden(m, 1.5, tags): print("mad for 1.5 s")
## var aim := MadnessRules.scatter(aim, false, randf())
## var cap := int(MadnessRules.gefuege().get("cap", 30))
## [/codeblock]

const PATH := "res://assets/data/madness_rules.json"


## The whole table (shared and read-only: DataCache).
static func data() -> Dictionary:
	return DataCache.load_dict(PATH)


## The madness values (aim_scatter, turn_chance, wobble, hero_delay, ...).
static func madness() -> Dictionary:
	return data().get("madness", {})


## The Leerenmagier's Arkanes Gefüge data (spec, cap, elements, land, ...).
static func gefuege() -> Dictionary:
	return data().get("gefuege", {})


## A status rule that drives a creature mad for `seconds` (for void spells:
## crypt `game.elements._status_enemy(enemy, MadnessRules.mad_rule(2.0), owner)`).
static func mad_rule(seconds: float) -> Dictionary:
	return {"status": {"mad": [1.0, seconds]}}


## True when a creature with `tags` cannot go mad (madness.immune_tags: the void's own).
static func mad_immune(tags: Array) -> bool:
	for tag: Variant in madness().get("immune_tags", ["void"]):
		if str(tag) in tags:
			return true
	return false


## Story worlds: drives monster `m` mad for `seconds` (its `mad_t` field) unless
## its `tags` are immune; true when it took. The crypt keeps it as the enemy
## status "mad" (src/combat/elements.gd _status_enemy).
static func madden(m: Dictionary, seconds: float, tags: Array) -> bool:
	if seconds <= 0.0 or mad_immune(tags):
		return false
	m.mad_t = maxf(float(m.get("mad_t", 0.0)), seconds)
	return true


## A mad creature's aim: `dir` turned by a random share of madness.aim_scatter
## (bosses and minibosses by boss_scale of it). `roll` is a random 0..1.
static func scatter(dir: Vector2, big: bool, roll: float) -> Vector2:
	var M := madness()
	var spread := float(M.get("aim_scatter", 0.55)) * (float(M.get("boss_scale", 0.5)) if big else 1.0)
	return dir.rotated((roll * 2.0 - 1.0) * spread)


## A mad creature's stagger (px/s, crypt px; the story worlds scale it by their
## art px): a sidestep across `forward`, a new random one every
## madness.wobble_step s. Keeps its state on `actor` (mad_side, mad_side_t).
static func wobble(actor: Dictionary, forward: Vector2, dt: float, roll: float) -> Vector2:
	var M := madness()
	actor.mad_side_t = float(actor.get("mad_side_t", 0.0)) - dt
	if float(actor.mad_side_t) <= 0.0:
		actor.mad_side_t = float(M.get("wobble_step", 0.35)) * (0.6 + roll * 0.8)
		actor.mad_side = roll * 2.0 - 1.0
	var across := forward.orthogonal().normalized() if forward.length_squared() > 0.0001 else Vector2.RIGHT
	return across * float(actor.get("mad_side", 0.0)) * float(M.get("wobble", 46.0))


## The nearest other living creature to `actor` within madness.turn_reach px
## ({} for none). `others` are dictionaries, `pos_key` their position field
## ("pos" crypt, "p" story), `alive` a Callable(other) -> bool.
static func nearest_other(actor: Dictionary, others: Array, pos_key: String, alive: Callable, reach_scale := 1.0) -> Dictionary:
	var best: Dictionary = {}
	var best_d := pow(float(madness().get("turn_reach", 420.0)) * reach_scale, 2.0)
	var at: Vector2 = actor[pos_key]
	for other: Dictionary in others:
		if is_same(other, actor) or not alive.call(other):
			continue
		var d := at.distance_squared_to(other[pos_key])
		if d < best_d:
			best_d = d
			best = other
	return best


## The hero's madness clock on `holder` (a crypt player or the story state):
## `inside` = he stands in a maddening void pool this frame. mad_in counts the
## time inside (it ebbs twice as fast outside, so a pool's ragged rim does not
## restart it); mad_warn = 0..1 over madness.hero_delay; mad = s of inverted
## controls left (held at hero_after inside, counting down after leaving).
static func hero_mad_step(holder: Dictionary, inside: bool, dt: float) -> void:
	var M := madness()
	var delay := maxf(0.01, float(M.get("hero_delay", 1.0)))
	var mad_in := float(holder.get("mad_in", 0.0))
	holder.mad = float(holder.get("mad", 0.0))
	mad_in = mad_in + dt if inside else maxf(0.0, mad_in - dt * 2.0)
	holder.mad_in = mad_in
	holder.mad_warn = clampf(mad_in / delay, 0.0, 1.0) if inside or float(holder.get("mad", 0.0)) <= 0.0 else 1.0
	if inside and mad_in >= delay:
		holder.mad = float(M.get("hero_after", 0.5))
	elif not inside:
		holder.mad = maxf(0.0, float(holder.get("mad", 0.0)) - dt)
	if not inside and float(holder.mad) <= 0.0 and mad_in <= 0.0:
		holder.mad_warn = 0.0


## True when a hero of `class_id` whose main specialisation is `spec` (or
## whose bar `talents` hold one of that spec, `spec_of` a Callable(talent) ->
## String) is the Leerenmagier: madness.immune_class + immune_spec.
static func void_mind(class_id: String, spec: String, talents: Array = [], spec_of: Callable = Callable()) -> bool:
	var M := madness()
	if class_id != str(M.get("immune_class", "mage")):
		return false
	var want := str(M.get("immune_spec", "arcane"))
	if spec == want:
		return true
	if spec.is_empty():
		for talent: Variant in talents:
			var own := str(spec_of.call(str(talent))) if spec_of.is_valid() else ""
			if own == want or str(talent).begins_with(want + "_"):
				return true
	return false

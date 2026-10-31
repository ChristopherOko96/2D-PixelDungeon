extends RefCounted
## The element physics every world obeys (assets/data/element_rules.json),
## read by the crypt game (src/game.gd, src/combat/elements.gd,
## src/combat/boss_moves.gd) and the story worlds (src/hell/hell_game.gd,
## src/hell/hell_monsters.gd) alike, so a hero and a monster standing in the
## same lava, ice, poison or steam feel the same thing in every chapter:
## - a medium (a pool or a floor of lava, fire, water, ice, poison, blood,
##   void): hurts on a tick, slows, slides (ice keeps the momentum), puts a
##   condition on (burn, poison, wet, slip, silence), pulls (void), douses a
##   burning creature (water), conducts lightning;
## - a gas (steam, smoke, poison, void, frost): the same, and it closes the
##   view: inside it only the cloud itself stays visible (vision);
## - only a creature of that element is spared: its tags (undead, poison,
##   frost, void, fire, hell) come from the words of its id and its def.
## Pure rules: no node, no drawing. The runtimes ask medium() / gas() and
## apply what they say with their own hurt, status and movement code.

const PATH := "res://assets/data/element_rules.json"

static var _data: Dictionary = {}


## The whole table, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {"mediums": {}, "gases": {}, "vision": {}, "reactions": {}}
	return _data


## The material a pool style is for the rules (frost pools are ice, flesh is blood).
static func material(style: String) -> String:
	var aliases: Dictionary = data().get("aliases", {})
	return str(aliases.get(style, style))


## The rules of standing in `style` ({} for firm ground or an unknown liquid).
static func medium(style: String) -> Dictionary:
	return data().get("mediums", {}).get(material(style), {})


## The rules of standing in gas `mat` ({} for none).
static func gas(mat: String) -> Dictionary:
	return data().get("gases", {}).get(mat, {})


## Which pool counts where several lie under one point: the first of `styles`
## in the priority list ("" when none is known).
static func top(styles: Array) -> String:
	for mat: String in data().get("priority", []):
		for style: String in styles:
			if material(style) == mat:
				return style
	return str(styles[0]) if not styles.is_empty() else ""


## The view rules inside gas.
static func vision() -> Dictionary:
	return data().get("vision", {})


## The reaction values (the crypt's balance.json "element" wins over them there).
static func reactions(over: Dictionary = {}) -> Dictionary:
	var out: Dictionary = (data().get("reactions", {}) as Dictionary).duplicate()
	out.merge(over, true)
	return out


## From what thickness a gas cloud counts as standing in it.
static func dense_from() -> float:
	return float(data().get("dense_from", 0.35))


## True when a creature with `tags` feels nothing of `rule`.
static func immune(tags: Array, rule: Dictionary) -> bool:
	for tag: String in rule.get("immune", []):
		if tag in tags:
			return true
	return false


## The element tags of a creature: from the words of its id or kind (actor_tags),
## its own shot element (`shot`: a figure shooting poison is of poison) and its
## material (`material`: bone is undead). `extra` adds a world's own (the hell's
## monsters are of fire and lava).
static func tags(id: String, shot := "", material_name := "", extra: Array = []) -> Array:
	var out: Array = []
	var low := id.to_lower()
	var words: Dictionary = data().get("actor_tags", {})
	for word: String in words:
		if low.find(word) >= 0:
			for tag: String in words[word]:
				if not tag in out:
					out.append(tag)
	if shot != "" and not shot in out:
		out.append(shot)
	for tag: String in data().get("material_tags", {}).get(material_name, []):
		if not tag in out:
			out.append(tag)
	for tag: String in extra:
		if not tag in out:
			out.append(tag)
	return out


## Movement on slippery ground: the old velocity gives way to the wanted one
## slowly; `grip` = share of the momentum left after one second (0.015 glaze
## ice, 0.35 blood, 1 firm ground: the wanted velocity at once).
static func slide(velocity: Vector2, wanted: Vector2, grip: float, dt: float) -> Vector2:
	if grip >= 1.0:
		return wanted
	return velocity.lerp(wanted, 1.0 - pow(maxf(grip, 0.0001), dt))


## The pull of a medium towards `centre` on something at `at` (px/s; 0 without).
static func pull(rule: Dictionary, at: Vector2, centre: Vector2) -> Vector2:
	var strength := float(rule.get("pull", 0.0))
	if strength <= 0.0 or at.distance_squared_to(centre) < 1.0:
		return Vector2.ZERO
	return (centre - at).normalized() * strength


# ---------- WAHN: the void drives minds mad (element_rules.json "madness") ----------

## The madness values (aim_scatter, turn_chance, wobble, hero_delay, ...).
static func madness() -> Dictionary:
	return data().get("madness", {})


## A status rule that drives a creature mad for `seconds` (for void spells:
## crypt `game.elements._status_enemy(enemy, ElementRules.mad_rule(2.0), owner)`).
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

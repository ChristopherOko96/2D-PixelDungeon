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

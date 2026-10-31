extends RefCounted
## Timed conditions on heroes, kept on the host (player.effects = {kind:
## {time, value}}): slow (speed share), poison and burn (damage per second),
## freeze (no moving, attacking or casting), slip (ice: movement keeps its
## momentum), blind (the view darkens), silence (skills sealed), weak (attacks
## come slower). Boss moves, curses and potions put them on; the game asks
## move_scale / can_act / attack_scale / slip / skills_sealed. Damage over
## time ignores the short invulnerability after a hit but lands only once a
## second. Clients see the kinds (`kinds`) and draw them.

const DOTS := ["poison", "burn"]

var game: Node


func bind(owner: Node) -> void:
	game = owner


## Puts `kind` on a hero for `time` seconds; the stronger value and the longer
## time win when it is already there.
func apply(player: Dictionary, kind: String, time: float, value: float = 0.0) -> void:
	if int(player.get("hp", 0)) <= 0 or time <= 0.0: return
	if not player.has("effects"): player.effects = {}
	# a wet hero cannot be set burning (assets/data/element_rules.json combos wet_blocks_burn)
	if kind == "burn" and player.effects.has("wet"): return
	var current: Dictionary = player.effects.get(kind, {})
	var stronger: float = maxf(value, float(current.get("value", 0.0))) if kind != "slow" else (minf(value, float(current.get("value", 1.0))) if not current.is_empty() else value)
	player.effects[kind] = {"time": maxf(time, float(current.get("time", 0.0))), "value": stronger, "tick": float(current.get("tick", 1.0))}


## An effect dictionary from data ({slow: [share, s], poison: [dps, s], freeze: s, ...}).
func apply_spec(player: Dictionary, spec: Dictionary) -> void:
	for kind: String in spec:
		var value: Variant = spec[kind]
		if kind == "pull": continue
		if value is Array and value.size() >= 2: apply(player, kind, float(value[1]), float(value[0]))
		elif value is float or value is int: apply(player, kind, float(value), 1.0)


func has(player: Dictionary, kind: String) -> bool:
	return player.get("effects", {}).has(kind)


func clear(player: Dictionary, kind: String = "") -> void:
	if not player.has("effects"): return
	if kind.is_empty(): player.effects.clear()
	else: player.effects.erase(kind)


## Counts down every hero's effects and deals damage over time.
func step(delta: float) -> void:
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if not player.has("effects") or player.effects.is_empty(): continue
		if int(player.hp) <= 0:
			player.effects.clear()
			continue
		for kind: String in player.effects.keys():
			var entry: Dictionary = player.effects[kind]
			entry.time = float(entry.time) - delta
			if kind in DOTS:
				# continuous: the value is half hearts per second, collected into whole points (elements.gd dot_f)
				game.elements.dot_f(id, player, float(entry.value) * delta, kind)
			elif kind == "regen":
				# Healing over time: half a heart every `value` seconds.
				entry.tick = float(entry.get("tick", float(entry.value))) - delta
				if float(entry.tick) <= 0.0:
					entry.tick = maxf(0.5, float(entry.value))
					player.hp = mini(int(player.max_hp), int(player.hp) + 1)
			if float(entry.time) <= 0.0: player.effects.erase(kind)


## Share of the normal walking speed (frozen: none; haste speeds up).
func move_scale(player: Dictionary) -> float:
	var effects: Dictionary = player.get("effects", {})
	if effects.has("freeze"): return 0.0
	var scale: float = float(effects.slow.value) if effects.has("slow") else 1.0
	if effects.has("haste"): scale *= float(effects.haste.value)
	return scale


## Damage factor (strength potion).
func damage_scale(player: Dictionary) -> float:
	var effects: Dictionary = player.get("effects", {})
	return float(effects.strength.value) if effects.has("strength") else 1.0


## False while frozen: no attacks, no skills.
func can_act(player: Dictionary) -> bool:
	return not player.get("effects", {}).has("freeze")


## Factor on the time between attacks (weak: slower).
func attack_scale(player: Dictionary) -> float:
	var effects: Dictionary = player.get("effects", {})
	return 1.0 + float(effects.weak.value) if effects.has("weak") else 1.0


## How much movement keeps its momentum per frame on ice (0 = full grip). The
## effect's value is the ground's grip (share of the momentum left after one
## second, element_rules.json); a slip without one is glaze ice.
func slip(player: Dictionary) -> float:
	var effects: Dictionary = player.get("effects", {})
	if not effects.has("slip"): return 0.0
	var grip := float(effects.slip.get("value", 1.0))
	return 0.92 if grip >= 1.0 or grip <= 0.0 else pow(grip, 1.0 / 60.0)


func skills_sealed(player: Dictionary) -> bool:
	return player.get("effects", {}).has("silence")


## The kinds on a hero, for clients.
func kinds(player: Dictionary) -> Array:
	return Array(player.get("effects", {}).keys())

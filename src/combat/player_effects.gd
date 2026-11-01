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
const ElementRules = preload("res://src/combat/element_rules.gd")
const ElementSkin = preload("res://src/hero/element_skin.gd")

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


## Counts down every hero's effects, deals damage over time and runs the
## madness clock (WAHN: touch_mad, madness_rules.gd hero_mad_step).
func step(delta: float) -> void:
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		_step_mad(id, player, delta)
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


# ---------- WAHN (madness_rules.json madness) ----------

## Marks a hero as standing in a maddening void pool this frame (the pools of
## monsters and bosses: src/combat/elements.gd condition_player; a hero's own
## pool never reaches him, boss_moves.gd _pool_tick).
func touch_mad(player: Dictionary) -> void:
	player.mad_touch = true


## True while a hero's controls are inverted: movement and aim mirrored (game.gd _mad_command).
func inverted(player: Dictionary) -> bool:
	return float(player.get("mad", 0.0)) > 0.0


## The madness clock of one hero: after madness.hero_delay s inside his controls
## invert, hero_after s after leaving they come back. player.mad = s of
## inversion left, player.mad_warn = 0..1 while it creeps in (for the visuals).
## The Leerenmagier (void_mind) never goes mad.
func _step_mad(id: int, player: Dictionary, delta: float) -> void:
	var inside: bool = bool(player.get("mad_touch", false)) and int(player.get("hp", 0)) > 0
	player.mad_touch = false
	if inside:
		player.mind_check = float(player.get("mind_check", 0.0)) - delta
		if float(player.mind_check) <= 0.0 or not player.has("void_mind"):
			player.mind_check = 1.0
			player.void_mind = void_mind(id, player)
		if bool(player.void_mind): inside = false
	if not inside and float(player.get("mad", 0.0)) <= 0.0 and float(player.get("mad_in", 0.0)) <= 0.0:
		player.mad_warn = 0.0
		return
	ElementRules.hero_mad_step(player, inside, delta)


## True when hero `id` is the Leerenmagier (madness.immune_class with
## immune_spec as main specialisation by his build's ranks, or such talents on
## his bar / as his ultimate).
func void_mind(id: int, player: Dictionary) -> bool:
	var class_id := str(player.get("class_id", ""))
	if class_id != str(ElementRules.madness().get("immune_class", "mage")): return false
	var spec := ""
	if game.get("progress") != null and game.progress.has_method("build_for"):
		var build: Dictionary = game.progress.build_for(id, class_id)
		spec = ElementSkin.main_spec({"classes": {class_id: {"ranks": build.get("ranks", {})}}}, class_id)
	var bar: Array = []
	if game.get("talent_combat") != null:
		var rt: Dictionary = game.talent_combat.runtimes.get(id, {})
		if not rt.is_empty(): bar = Array(rt.get("bar", [])) + [str(rt.get("ultimate", ""))]
	var infos: Dictionary = ElementSkin.talents().get("talents", {})
	return ElementRules.void_mind(class_id, spec, bar, func(talent: String) -> String: return str(infos.get(talent, {}).get("spec", "")))

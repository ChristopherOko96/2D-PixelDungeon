extends RefCounted
## Timed conditions on the hero of the Frostgruft, as Story 1 keeps them
## (src/combat/player_effects.gd): state.effects = {kind: {time, value, tick}}.
## slow (speed share), poison and burn (half hearts per second), freeze (no
## moving, attacking or casting), slip (ice: movement keeps its momentum),
## blind (the view darkens), silence (skills sealed), weak (attacks come
## slower); from potions also strength, haste, regen and shield. Boss moves,
## curses and potions put them on. Damage over time ignores the short
## invulnerability after a hit but lands only once a second.

const DOTS := ["poison", "burn"]
## Colours of the condition icons and the hero's tint.
const LOOK := {"slow": Color(0.6, 0.85, 1.0), "freeze": Color(0.7, 0.95, 1.0), "poison": Color(0.55, 0.95, 0.35), "burn": Color(1.0, 0.55, 0.2),
	"slip": Color(0.8, 0.95, 1.0), "blind": Color(0.35, 0.3, 0.45), "silence": Color(0.75, 0.6, 1.0), "weak": Color(0.7, 0.65, 0.6),
	"strength": Color(1.0, 0.4, 0.3), "haste": Color(1.0, 0.9, 0.4), "regen": Color(0.5, 1.0, 0.55), "shield": Color(1.0, 0.85, 0.4),
	"wet": Color(0.55, 0.75, 1.0)}
const NAMES := {"slow": "LANGSAM", "freeze": "GEFROREN", "poison": "GIFT", "burn": "BRAND", "slip": "GLATT", "blind": "BLIND", "silence": "STUMM",
	"weak": "SCHWACH", "strength": "STÄRKE", "haste": "EILE", "regen": "ERHOLUNG", "shield": "SCHUTZ", "wet": "NASS"}


static func _all(g: Node) -> Dictionary:
	if not g.state.has("effects"):
		g.state.effects = {}
	return g.state.effects


## Puts `kind` on the hero for `time` seconds; the stronger value and the
## longer time win when it is already there (slow: the lower share).
static func apply(g: Node, kind: String, time: float, value := 0.0) -> void:
	if int(g.state.get("hp", 0)) <= 0 or time <= 0.0:
		return
	var all := _all(g)
	# a wet hero cannot be set burning (element_rules.json combos wet_blocks_burn)
	if kind == "burn" and all.has("wet"):
		return
	var cur: Dictionary = all.get(kind, {})
	var stronger: float = maxf(value, float(cur.get("value", 0.0))) if kind != "slow" else (minf(value, float(cur.get("value", 1.0))) if not cur.is_empty() else value)
	all[kind] = {"time": maxf(time, float(cur.get("time", 0.0))), "value": stronger, "tick": float(cur.get("tick", 1.0))}


## An effect dictionary from data ({slow: [share, s], poison: [dps, s], freeze: s, ...}).
static func apply_spec(g: Node, spec: Dictionary) -> void:
	for kind: String in spec:
		var v: Variant = spec[kind]
		if kind == "pull":
			continue
		if v is Array and (v as Array).size() >= 2:
			apply(g, kind, float(v[1]), float(v[0]))
		elif v is float or v is int:
			apply(g, kind, float(v), 1.0)


static func has(g: Node, kind: String) -> bool:
	return _all(g).has(kind)


static func clear(g: Node, kind := "") -> void:
	if kind == "":
		_all(g).clear()
	else:
		_all(g).erase(kind)


## Counts down, deals damage over time, heals with regen.
static func step(g: Node, dt: float) -> void:
	var all := _all(g)
	if int(g.state.hp) <= 0:
		all.clear()
		return
	for kind: String in all.keys():
		var e: Dictionary = all[kind]
		e.time = float(e.time) - dt
		if kind in DOTS:
			# continuous: the value is half hearts per second, drained onto the life bar (hell_game.gd dot_hurt_f)
			g.dot_hurt_f(float(e.value) * dt, "an Gift gestorben" if kind == "poison" else "verbrannt")
		elif kind == "regen":
			e.tick = float(e.get("tick", float(e.value))) - dt
			if float(e.tick) <= 0.0:
				e.tick = maxf(0.5, float(e.value))
				g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + 1)
		if float(e.time) <= 0.0:
			all.erase(kind)


## Share of the normal walking speed (frozen: none; haste speeds up).
static func move_scale(g: Node) -> float:
	var all := _all(g)
	if all.has("freeze"):
		return 0.0
	var s: float = float(all.slow.value) if all.has("slow") else 1.0
	if all.has("haste"):
		s *= float(all.haste.value)
	return s


## Damage factor (strength potion).
static func damage_scale(g: Node) -> float:
	var all := _all(g)
	return float(all.strength.value) if all.has("strength") else 1.0


## False while frozen: no attacks, no skills.
static func can_act(g: Node) -> bool:
	return not _all(g).has("freeze")


## Factor on the time between attacks (weak: slower).
static func attack_scale(g: Node) -> float:
	var all := _all(g)
	return 1.0 + float(all.weak.value) if all.has("weak") else 1.0


## How much movement keeps its momentum (0 = full grip).
static func slip(g: Node) -> float:
	return 0.92 if _all(g).has("slip") else 0.0


static func skills_sealed(g: Node) -> bool:
	return _all(g).has("silence")


## The hero's look under the conditions (frozen in ice, poisoned green ...).
static func tint(g: Node) -> Color:
	var all := _all(g)
	for kind: String in ["freeze", "poison", "burn", "slow"]:
		if all.has(kind):
			return Color(1, 1, 1).lerp(LOOK[kind], 0.45)
	return Color.WHITE


## Conditions on the hero in the world: an ice block, bubbles, flames, flakes.
static func draw(g: Node, l: CanvasItem, t: float) -> void:
	var all := _all(g)
	var at := Vector2(g.player.x, g.player.y - 40)
	if all.has("freeze"):
		l.draw_rect(Rect2(at - Vector2(40, 50), Vector2(80, 100)), Color(0.7, 0.92, 1.0, 0.35))
		l.draw_rect(Rect2(at - Vector2(40, 50), Vector2(80, 100)), Color(0.9, 0.98, 1.0, 0.8), false, 3.0)
	for i in range(4):
		var q := at + Vector2(cos(t * 2.0 + i * 1.6) * 30.0, -fmod(t * 50.0 + i * 23.0, 70.0) + 30.0)
		if all.has("poison"):
			l.draw_circle(q, 5.0, Color(LOOK.poison, 0.8))
		if all.has("burn"):
			l.draw_circle(q + Vector2(6, 0), 6.0, Color(LOOK.burn, 0.75))
		if all.has("slow") or all.has("slip"):
			l.draw_circle(q + Vector2(-6, 8), 3.5, Color(0.95, 0.98, 1.0, 0.8))
		if all.has("wet"):
			# drops running off him and falling
			var drop := at + Vector2(cos(t * 3.0 + i * 2.1) * 18.0, fmod(t * 90.0 + i * 31.0, 60.0) - 20.0)
			l.draw_rect(Rect2(drop, Vector2(2, 5)), Color(LOOK.wet, 0.85))
	if all.has("shield"):
		l.draw_arc(at, 66.0, 0.0, TAU, 32, Color(LOOK.shield, 0.8), 4.0)


## The active conditions as a row of labelled chips (HUD, screen space).
static func draw_hud(g: Node, h: CanvasItem, pos: Vector2, font: Font) -> void:
	var x := pos.x
	for kind: String in _all(g):
		var e: Dictionary = _all(g)[kind]
		var text := "%s %d" % [NAMES.get(kind, kind.to_upper()), ceili(float(e.time))]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
		h.draw_rect(Rect2(Vector2(x, pos.y), Vector2(w, 20)), Color(0.05, 0.07, 0.12, 0.8))
		h.draw_rect(Rect2(Vector2(x, pos.y), Vector2(w, 20)), LOOK.get(kind, Color.WHITE), false, 2.0)
		h.draw_string(font, Vector2(x + 7, pos.y + 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LOOK.get(kind, Color.WHITE))
		x += w + 6.0

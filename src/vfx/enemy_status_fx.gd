extends RefCounted
## Host-confirmed enemy conditions emit cosmetic matter through the shared solver.
## Observe never emits; update owns time. No status, damage or liquid data is written.
const PATH := "res://assets/data/enemy_status_fx.json"
static var _settings: Dictionary = {}
var actors: Dictionary = {}
var _cursor := 0

## Cached presentation schema (crypt pixel units).
static func settings() -> Dictionary:
	if _settings.is_empty(): _settings = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _settings

## Clear rate remainders and identities on room/run changes.
func clear() -> void:
	actors.clear()
	_cursor = 0

## Normalize replicated status names or live dictionaries without mutating either.
static func active(enemy: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if float(enemy.get("hp", 1)) <= 0 or float(enemy.get("dying_p", -1)) >= 0: return out
	var raw: Variant = enemy.get("statuses", [])
	for kind: String in settings().styles:
		var on := false
		if raw is Array: on = raw.has(kind)
		elif raw is Dictionary and raw.has(kind):
			var value: Variant = raw[kind]
			on = float(value.get("time", 0)) > 0 if value is Dictionary else bool(value)
		if on: out.append(kind)
	return out

## Translate story timer fields; stun/bleed never masquerade as frost/fire.
static func story_statuses(mob: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if float(mob.get("hp", 0)) <= 0: return out
	if float(mob.get("fire_t", 0)) > 0 or (float(mob.get("burn_t", 0)) > 0 and float(mob.get("wet_t", 0)) <= 0): out.append("burn")
	if float(mob.get("poison_t", 0)) > 0: out.append("poison")
	if float(mob.get("wet_t", 0)) > 0: out.append("wet")
	if float(mob.get("frozen", 0)) > 0: out.append("freeze")
	return out

## Reconcile current enemies, preserving only still-active status rate remainders.
func observe(enemies: Array) -> void:
	var seen: Dictionary = {}
	for enemy: Dictionary in enemies:
		var kinds := active(enemy)
		if kinds.is_empty(): continue
		var id := int(enemy.get("id", -1))
		if id < 0: continue
		var old: Dictionary = actors.get(id, {})
		var carry: Dictionary = {}
		for kind: String in kinds: carry[kind] = float(old.get("carry", {}).get(kind, 0.0))
		actors[id] = {"point": Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))),
			"foot": float(enemy.get("status_foot", 10)), "radius": float(enemy.get("status_radius", enemy.get("r", 12))),
			"carry": carry, "serial": int(old.get("serial", 0))}
		seen[id] = true
	for id: int in actors.keys():
		if not seen.has(id): actors.erase(id)

## Bounded, time-based emission; a paused frame and repeated snapshots add nothing.
func update(delta: float, particles: RefCounted) -> void:
	if delta <= 0 or actors.is_empty(): return
	var cfg := settings()
	if particles.count() >= int(cfg.soft_cap):
		for actor: Dictionary in actors.values():
			for kind: String in actor.carry: actor.carry[kind] = 0.0
		return
	var dt := minf(delta, float(cfg.max_dt))
	var budget := int(cfg.frame_budget)
	var ids := actors.keys()
	for index in range(ids.size()):
		var actor: Dictionary = actors[ids[(_cursor + index) % ids.size()]]
		for kind: String in actor.carry:
			var style: Dictionary = cfg.styles[kind]
			var due := float(actor.carry[kind]) + dt * float(style.rate)
			actor.carry[kind] = due - floorf(due)
			for n in range(mini(int(due), budget)):
				if particles.count() >= int(cfg.soft_cap): break
				_emit(particles, actor, kind, style, cfg)
				budget -= 1
	_cursor = (_cursor + 1) % ids.size()

func _emit(particles: RefCounted, actor: Dictionary, kind: String, style: Dictionary, cfg: Dictionary) -> void:
	var serial := int(actor.serial)
	actor.serial = serial + 1
	var phase := fposmod(float(serial) * 0.6180339, 1.0)
	var radius := clampf(float(actor.radius) * 0.7, float(cfg.radius_min), float(cfg.radius_max))
	var height := clampf(radius * 2.8, float(cfg.height_min), float(cfg.height_max))
	var foot: Vector2 = actor.point + Vector2(0, float(actor.foot))
	var z := height * (0.15 + phase * 0.65)
	var side := -1.0 if serial % 2 == 0 else 1.0
	# Emit at the silhouette's sides so depth-sorted body pixels cannot hide the cue.
	var offset := Vector2(side * radius * (1.05 + phase * 0.35), 0)
	var velocity := Vector2(side * float(style.speed), 0)
	var colours: Array = style.colours
	var particle: Dictionary = particles.emit(foot + offset - Vector2(0, z), velocity, Color(str(colours[serial % colours.size()])), float(style.life), str(style.mode), float(style.size), z, float(style.lift), 1.2)
	particle.gravity = float(style.gravity)
	particle.settle = false
	particle.fade = true
	particle.status_kind = kind
	if kind == "burn":
		var ramp: Array = []
		for colour: String in colours: ramp.append(Color(colour))
		particle.ramp = ramp
		particle.seed = serial
	elif kind == "freeze": particle.plus = true

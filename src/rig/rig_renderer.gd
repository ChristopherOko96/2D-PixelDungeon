extends RefCounted
## Presentation of the part rigs in the dungeon view. Reads only snapshot
## fields (attack phase and progress, hit/block counters, dying progress, lost
## parts, beam, fx events) and owns no game decisions. Keeps per-actor clip
## state, falling debris of detached parts, particles, summoning pools and
## void effects, and reports the lights they cast for the dark crypt.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
const S := RigLibrary.PIXEL_SCALE
const SHADOW := Color(0.05, 0.04, 0.09, 0.45)
const VIOLET := Color("a46fe0")
const VIOLET_DARK := Color("5f2d56")
const VIOLET_HOT := Color("f2b8ff")
const INK := Color("222222")
const HIT_TIME := 0.3
const BLOCK_TIME := 0.9
const RISE_TIME := 1.1
const REGROW_TIME := 1.2

var library: RefCounted
var _actors: Dictionary = {}
var _debris: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _pools: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _fx_seen: Dictionary = {}
var _clock := 0.0
## Beams drawn in the last draw_over (for tests and capture checks).
var beams_drawn := 0
var _rng := RandomNumberGenerator.new()


func _init(rig_library: RefCounted = null) -> void:
	library = rig_library if rig_library != null else RigLibrary.shared()
	_rng.seed = 90210


## True when the rig data loaded; otherwise the view keeps its old sprites.
func is_ready() -> bool:
	return library != null and library.ready


## Clears every actor, debris piece and effect (new run or room).
func reset() -> void:
	_actors.clear()
	_debris.clear()
	_particles.clear()
	_pools.clear()
	_flashes.clear()
	_beams.clear()
	_fx_seen.clear()


## Reads one snapshot: lost parts become debris, regrown parts scale back in,
## counters start hit/block clips, new summons rise, fx events play once.
func observe(snapshot: Dictionary) -> void:
	if not is_ready(): return
	var seen: Dictionary = {}
	for enemy: Dictionary in snapshot.get("enemies", []):
		var rig_name := str(enemy.get("rig", ""))
		if rig_name.is_empty(): continue
		var key := "e%d" % int(enemy.get("id", 0))
		seen[key] = true
		var fresh := not _actors.has(key)
		var a := _actor(key, enemy)
		var rig: Dictionary = library.rig(rig_name)
		if fresh and bool(enemy.get("summoned", false)) and float(enemy.get("dying_p", -1.0)) < 0.0: _start_rise(a, rig, enemy)
		if int(enemy.get("hits", 0)) > int(a.hits) and str(enemy.get("attack", "")).is_empty() and float(enemy.get("dying_p", -1.0)) < 0.0: _play(a, "hit", HIT_TIME)
		if int(enemy.get("blocks", 0)) > int(a.blocks): _play(a, "block", BLOCK_TIME)
		a.hits = int(enemy.get("hits", 0))
		a.blocks = int(enemy.get("blocks", 0))
		var lost: Dictionary = {}
		for id: Variant in enemy.get("lost", []): lost[str(id)] = true
		for id: String in lost:
			if not a.lost.has(id) and not fresh: _detach(a, rig, id, 1.0)
		for id: String in a.lost:
			if not lost.has(id):
				a.regrowing[id] = REGROW_TIME
				_debris = _debris.filter(func(d: Dictionary) -> bool: return not (d.key == a.key and d.id == id))
				_burst_at(Vector2(a.get("feet", Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))))) - Vector2(0, 24), VIOLET if rig_name in ["void", "bomber"] else Color("97da3f"), 12, 60.0)
		a.lost = lost
		if float(enemy.get("dying_p", -1.0)) >= 0.0 and not bool(a.dying): _start_death(a, rig, enemy)
	for key: String in _actors.keys():
		if str(key).begins_with("e") and not seen.has(key): _actors.erase(key)
	for event: Dictionary in snapshot.get("fx_events", []):
		var id := int(event.get("id", 0))
		if _fx_seen.has(id): continue
		_fx_seen[id] = true
		_play_fx(event)
	if _fx_seen.size() > 256: _fx_seen.clear()


func _actor(key: String, entity: Dictionary) -> Dictionary:
	if not _actors.has(key):
		_actors[key] = {"key": key, "t": _rng.randf_range(0.0, 3.0), "clip": "", "ct": 0.0, "clip_len": 0.0, "hits": int(entity.get("hits", 0)), "blocks": int(entity.get("blocks", 0)),
			"hurts": int(entity.get("hurts", 0)), "lost": {}, "regrowing": {}, "dying": false, "rise": 0.0, "rise_from": {}, "world": {}, "trail": [], "dead_at": -1.0}
	return _actors[key]


func _play(a: Dictionary, clip: String, length: float) -> void:
	a.clip = clip
	a.ct = 0.0
	a.clip_len = length


## Advances clocks, clips, regrowth, debris physics and effects.
func step(delta: float) -> void:
	_clock += delta
	for a: Dictionary in _actors.values():
		a.t = float(a.t) + delta
		a.ct = float(a.ct) + delta
		if not str(a.clip).is_empty() and float(a.clip_len) > 0.0 and float(a.ct) >= float(a.clip_len): a.clip = ""
		if float(a.rise) > 0.0: a.rise = maxf(0.0, float(a.rise) - delta)
		for id: String in a.regrowing.keys():
			a.regrowing[id] = float(a.regrowing[id]) - delta
			if float(a.regrowing[id]) <= 0.0: a.regrowing.erase(id)
		for point: Dictionary in a.trail: point.age = float(point.age) + delta
		a.trail = a.trail.filter(func(p: Dictionary) -> bool: return float(p.age) < 0.12)
	for d: Dictionary in _debris:
		d.life = float(d.life) + delta
		if bool(d.rest): continue
		d.vz = float(d.vz) - 520.0 * delta
		d.z = float(d.z) + float(d.vz) * delta
		d.x = float(d.x) + float(d.vx) * delta
		d.ang = float(d.ang) + float(d.spin) * delta
		if float(d.z) <= 0.0:
			d.z = 0.0
			d.vz = -float(d.vz) * 0.35
			d.vx = float(d.vx) * 0.55
			d.spin = float(d.spin) * 0.45
			if absf(float(d.vz)) < 24.0:
				d.rest = true
				d.vz = 0.0
	_debris = _debris.filter(func(d: Dictionary) -> bool: return float(d.life) < float(d.max))
	for p: Dictionary in _particles:
		p.life = float(p.life) + delta
		p.x = float(p.x) + float(p.vx) * delta
		p.y = float(p.y) + float(p.vy) * delta
		p.vy = float(p.vy) + float(p.get("grav", 0.0)) * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p.life) < float(p.max))
	if _particles.size() > 900: _particles = _particles.slice(_particles.size() - 900)
	for pool: Dictionary in _pools: pool.life = float(pool.life) + delta
	_pools = _pools.filter(func(p: Dictionary) -> bool: return float(p.life) < float(p.max))
	for flash: Dictionary in _flashes: flash.life = float(flash.life) + delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f.life) < float(f.max))


# ------------------------------------------------------------------ actors

## Draws one rigged enemy whose body centre is at `point`. Returns the screen
## y of the figure's top (for the health bar) or NAN when nothing was drawn.
func draw_enemy(canvas: CanvasItem, enemy: Dictionary, point: Vector2) -> float:
	var rig: Dictionary = library.rig(str(enemy.get("rig", "")))
	if rig.is_empty(): return NAN
	var a := _actor("e%d" % int(enemy.get("id", 0)), enemy)
	a.moving = bool(enemy.get("moving", false))
	var face := -1.0 if float(enemy.get("face", -1.0)) < 0.0 else 1.0
	var dying_p := float(enemy.get("dying_p", -1.0))
	var family: String = str(rig.family)
	# Skeletons crumble and bombers burst: nothing is left to draw.
	if dying_p >= 0.0 and (family in ["skeleton", "bomber"]): return NAN
	_clip_from_snapshot(a, rig, enemy, dying_p)
	var flash := clampf(float(enemy.get("hit_flash", 0.0)) / 0.16, 0.0, 1.0)
	return _draw_rig(canvas, a, rig, point, face, flash, true)


## Draws a hero-class player's body (the view draws the held weapon on top).
func draw_hero(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, rig_name: String, face: float, alpha: float = 1.0) -> void:
	var rig: Dictionary = library.rig(rig_name)
	if rig.is_empty(): return
	var a := _actor(key, player)
	a.moving = bool(player.get("moving", false))
	a.alpha_mul = alpha
	if int(player.get("hurts", 0)) > int(a.hurts): _play(a, "hit", HIT_TIME)
	a.hurts = int(player.get("hurts", 0))
	if float(player.get("hp", 1)) <= 0.0:
		if float(a.dead_at) < 0.0: a.dead_at = _clock
		a.clip = "death"
		a.u = clampf((_clock - float(a.dead_at)) / 1.4, 0.0, 1.0)
	else:
		a.dead_at = -1.0
		if str(a.clip) == "death": a.clip = ""
		a.u = clampf(float(a.ct) / maxf(0.001, float(a.clip_len)), 0.0, 1.0) if not str(a.clip).is_empty() else 0.0
	_draw_rig(canvas, a, rig, point, face, 0.0, false)


## Attack clips follow the host's attack phase so the strike lands on the
## active phase; death follows dying progress; hit/block/rise are local timers.
func _clip_from_snapshot(a: Dictionary, rig: Dictionary, enemy: Dictionary, dying_p: float) -> void:
	if dying_p >= 0.0:
		a.clip = "death"
		a.u = dying_p
		a.ct = float(a.ct)
		return
	if float(a.rise) > 0.0:
		a.clip = "rise"
		a.u = 1.0 - float(a.rise) / RISE_TIME
		return
	var phase := str(enemy.get("attack", ""))
	if not phase.is_empty():
		var mapping := _attack_mapping(rig, str(enemy.get("attack_kind", "")))
		var p := clampf(float(enemy.get("attack_p", 0.0)), 0.0, 1.0)
		var w_end: float = mapping[1]
		var a_end: float = mapping[2]
		a.u = w_end * p if phase == "windup" else lerpf(w_end, a_end, p) if phase == "active" else lerpf(a_end, 1.0, p)
		if str(a.clip) != str(mapping[0]): a.ct = 0.0
		a.clip = mapping[0]
		a.clip_len = 0.0
		return
	if str(a.clip) in ["hit", "block"]:
		a.u = clampf(float(a.ct) / maxf(0.001, float(a.clip_len)), 0.0, 1.0)
		return
	a.clip = ""
	a.u = 0.0


## [clip, end of windup, end of active] in clip progress, per figure and move.
func _attack_mapping(rig: Dictionary, kind: String) -> Array:
	match str(rig.family):
		"skeleton":
			match str(rig.variant):
				"bow": return ["attack", 0.7, 0.8]
				"guard": return ["attack", 0.45, 0.6]
			return ["attack", 0.6, 0.75]
		"necro": return ["summon", 0.3, 0.4] if kind == "summon" else ["attack", 0.55, 0.62]
		"brute": return ["roar", 0.4, 0.6] if kind == "roar" else ["attack", 0.45, 0.56]
		"void":
			match kind:
				"beam": return ["beam", 0.3, 0.86]
				"summon": return ["summon", 0.38, 0.5]
			return ["attack", 0.55, 0.62]
		"bomber": return ["attack", 1.0, 1.0]
	return ["attack", 0.45, 0.6]


func _start_rise(a: Dictionary, rig: Dictionary, enemy: Dictionary) -> void:
	a.rise = RISE_TIME
	var from: Dictionary = {}
	for part: Dictionary in rig.parts + rig.items: from[part.id] = {"dx": _rng.randf_range(-3, 3), "dy": _rng.randf_range(8, 13), "rot": _rng.randf_range(-1.2, 1.2)}
	a.rise_from = from
	var feet := Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))) + Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S)
	_pools.append({"x": feet.x, "y": feet.y, "r": 18.0, "life": 0.0, "max": 2.6})


func _start_death(a: Dictionary, rig: Dictionary, enemy: Dictionary) -> void:
	a.dying = true
	var family: String = str(rig.family)
	var feet: Vector2 = a.get("feet", Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))))
	match family:
		"skeleton":
			for part: Dictionary in rig.items + rig.parts: _detach(a, rig, part.id, 1.0)
			if bool(enemy.get("summoned", false)): _burst_at(feet - Vector2(0, 14), VIOLET_DARK, 14, 50.0)
		"bomber":
			if not bool(enemy.get("exploded", false)): _burst_at(feet - Vector2(0, 16), VIOLET, 18, 90.0)
		"biped", "hero", "necro":
			for item: Dictionary in rig.items: _detach(a, rig, item.id, 0.8)
		"brute":
			for id: String in ["arm", "head"]: _detach(a, rig, id, 0.5)
		"void":
			for id: String in ["claw_l", "claw_r"]: _detach(a, rig, id, 0.7)
			_flashes.append({"x": feet.x, "y": feet.y - 40.0, "r": 150.0, "life": 0.0, "max": 1.8, "color": VIOLET})


## Turns a part into falling debris from where it was last drawn.
func _detach(a: Dictionary, rig: Dictionary, id: String, impulse: float) -> void:
	var part: Dictionary = rig.by_id.get(id, {})
	if part.is_empty() or a.lost.has(id): return
	var world: Dictionary = a.world
	if not world.has(id): return
	var xform: Transform2D = world[id]
	var center: Vector2 = xform * Vector2(part.center)
	var ground: float = Vector2(a.get("feet", center)).y
	var texture: Texture2D = part.texture
	if part.get("frames") is Array and not part.frames.is_empty(): texture = part.frames[int(a.get("frame_" + id, 0)) % part.frames.size()].texture
	_debris.append({"key": a.key, "id": id, "texture": texture, "center": part.center, "x": center.x, "y": ground + _rng.randf_range(-4, 6), "z": ground - center.y,
		"vx": _rng.randf_range(-56, 56) * impulse, "vz": _rng.randf_range(70, 140) * impulse, "ang": xform.get_rotation(), "spin": _rng.randf_range(-10, 10) * impulse,
		"face": signf(xform.x.x) if absf(xform.x.x) > 0.01 else 1.0, "life": 0.0, "max": 3.0 if str(a.key).begins_with("e") and str(rig.family) == "skeleton" else 5.0, "rest": false})
	for i in range(6): _particles.append({"x": center.x, "y": center.y, "vx": _rng.randf_range(-60, 60), "vy": _rng.randf_range(-60, 20), "life": 0.0, "max": _rng.randf_range(0.25, 0.5),
		"color": VIOLET_DARK if str(rig.family) in ["void", "bomber"] else Color("fdf7ed"), "grav": 240.0})


func _draw_rig(canvas: CanvasItem, a: Dictionary, rig: Dictionary, point: Vector2, face: float, flash: float, with_items: bool) -> float:
	var pose: Dictionary = RigPoses.pose(rig, a)
	var feet := point + Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S)
	a.feet = feet
	var world := _solve(rig, a, pose, feet, face, with_items)
	a.world = world
	var dying: bool = str(a.clip) == "death"
	if not dying or not (str(rig.family) in ["void", "necro"]):
		canvas.draw_rect(Rect2(feet.x - float(rig.width), feet.y - 2, float(rig.width) * 2.0, 6), SHADOW)
	var layers: Array = []
	for part: Dictionary in rig.parts:
		if not a.lost.has(part.id) and world.has(part.id): layers.append(part)
	if with_items:
		for item: Dictionary in rig.items:
			if not a.lost.has(item.id) and world.has(item.id): layers.append(item)
	layers.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.z) < int(q.z))
	var frames: Dictionary = pose.get("frames", {})
	var alpha_of := func(part: Dictionary) -> float:
		var state: Dictionary = pose.parts.get(part.id, {})
		var alpha: float = float(state.get("alpha", 1.0))
		if float(a.rise) > 0.0 and str(rig.family) != "skeleton": alpha *= 1.0 - float(a.rise) / RISE_TIME
		alpha *= float(a.get("alpha_mul", 1.0))
		return alpha
	var layer_of := func(part: Dictionary) -> Dictionary:
		if part.get("frames") is Array and not part.frames.is_empty():
			var index: int = int(frames.get(part.id, 0)) % int(part.frames.size())
			a["frame_" + str(part.id)] = index
			return part.frames[index]
		return part
	# Void figures: a violet rim around the whole silhouette.
	var aura := float(pose.get("aura", 0.0))
	if aura > 0.0:
		var offsets := [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 1), Vector2(0, -1)] if bool(pose.get("glitch", false)) else [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for part: Dictionary in layers:
			var alpha: float = alpha_of.call(part)
			if alpha <= 0.01: continue
			var layer: Dictionary = layer_of.call(part)
			canvas.draw_set_transform_matrix(world[part.id])
			for offset: Vector2 in offsets: canvas.draw_texture(layer.white, offset, Color(VIOLET_DARK, clampf(aura, 0.0, 1.0) * alpha))
	var fuse := float(pose.get("fuse", 0.0))
	if fuse > 0.0: flash = maxf(flash, 0.8 * fuse if sin(float(a.ct) * (20.0 + 50.0 * fuse)) > 0.0 else 0.0)
	for part: Dictionary in layers:
		var alpha: float = alpha_of.call(part)
		if alpha <= 0.01: continue
		var layer: Dictionary = layer_of.call(part)
		canvas.draw_set_transform_matrix(world[part.id])
		canvas.draw_texture(layer.texture, Vector2.ZERO, Color(1, 1, 1, alpha))
		if flash > 0.0: canvas.draw_texture(layer.white, Vector2.ZERO, Color(1, 1, 1, flash * alpha))
		if bool(part.get("bow", false)): _draw_bow_string(canvas, pose)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Weapon swing trail from the blade tip.
	var weapon: Dictionary = rig.by_id.get("weapon", {})
	if bool(pose.trail) and not weapon.is_empty() and world.has("weapon") and not a.lost.has("weapon"):
		a.trail.append({"p": Transform2D(world.weapon) * Vector2(weapon.tip), "age": 0.0})
	for i in range(1, a.trail.size()):
		canvas.draw_line(a.trail[i - 1].p, a.trail[i].p, Color(0.92, 0.97, 1.0, 0.65 * (1.0 - float(a.trail[i].age) / 0.12)), 2.0)
	if pose.has("beam"): _beams.append({"key": a.key, "eye": world.get("eye", world.base) * Vector2(rig.get("eye_center", Vector2(22, 23))), "beam": pose.beam, "t": a.t, "ct": a.ct})
	return feet.y - (float(rig.ground.y) - float(rig.top) + 1.0) * S + float(pose.whole.dy) * S


func _draw_bow_string(canvas: CanvasItem, pose: Dictionary) -> void:
	var pull: float = float(pose.get("pull", 0.0))
	var top := Vector2(7.5, 3.5)
	var bottom := Vector2(7.5, 22.5)
	var middle := Vector2(7.5 - pull, 13)
	var color := Color("d3bfa9")
	canvas.draw_line(top, middle, color, 0.5)
	canvas.draw_line(middle, bottom, color, 0.5)
	if bool(pose.get("nock", false)):
		canvas.draw_line(middle, middle + Vector2(13, 0), Color("b89b73"), 0.5)
		canvas.draw_line(middle + Vector2(11, -1), middle + Vector2(13, 0), Color("eee0b9"), 0.5)
		canvas.draw_line(middle + Vector2(11, 1), middle + Vector2(13, 0), Color("eee0b9"), 0.5)


func _solve(rig: Dictionary, a: Dictionary, pose: Dictionary, feet: Vector2, face: float, with_items: bool) -> Dictionary:
	var whole: Dictionary = pose.whole
	var ground: Vector2 = rig.ground
	var pivot: Vector2 = whole.pivot if whole.pivot is Vector2 else ground
	var base := _t(feet + Vector2(float(whole.dx) * face * S, float(whole.dy) * S)) * _s(Vector2(face * S, S)) * _t(-ground) * _t(pivot) * Transform2D(float(whole.rot), Vector2.ZERO) * _s(Vector2(float(whole.sx), float(whole.sy))) * _t(-pivot)
	base.origin = base.origin.round()
	var world: Dictionary = {"base": base}
	for part: Dictionary in rig.parts: _part_world(rig, a, pose, world, part.id)
	if with_items:
		for item: Dictionary in rig.items:
			if a.lost.has(item.id): continue
			var parent: String = str(item.parent)
			var parent_world: Transform2D = world[parent] if world.has(parent) and not a.lost.has(parent) else base
			var o: Dictionary = pose.items.get(item.id, {"dx": 0.0, "dy": 0.0, "rot": 0.0})
			world[item.id] = parent_world * _t(Vector2(item.hand) + Vector2(float(o.dx), float(o.dy))) * Transform2D(float(item.rest) + float(o.rot), Vector2.ZERO) * _t(-Vector2(item.grip))
	return world


func _part_world(rig: Dictionary, a: Dictionary, pose: Dictionary, world: Dictionary, id: String) -> Transform2D:
	if world.has(id): return world[id]
	var part: Dictionary = rig.by_id[id]
	var p: Dictionary = pose.parts.get(id, {"dx": 0.0, "dy": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0})
	var parent: String = str(part.parent)
	var parent_world: Transform2D = _part_world(rig, a, pose, world, parent) if not parent.is_empty() and rig.by_id.has(parent) and not a.lost.has(parent) else world.base
	var pivot: Vector2 = part.pivot
	var local := _t(pivot + Vector2(float(p.dx), float(p.dy))) * Transform2D(float(p.rot), Vector2.ZERO) * _s(Vector2(float(p.get("sx", 1.0)), float(p.get("sy", 1.0)))) * _t(-pivot)
	world[id] = parent_world * local
	return world[id]


static func _t(offset: Vector2) -> Transform2D:
	return Transform2D(0.0, offset)


static func _s(scale: Vector2) -> Transform2D:
	return Transform2D(Vector2(scale.x, 0), Vector2(0, scale.y), Vector2.ZERO)


# ------------------------------------------------------------------ effects

## Debris and summoning pools lie on the floor, under every actor.
func draw_under(canvas: CanvasItem) -> void:
	for pool: Dictionary in _pools: _draw_pool(canvas, pool)
	for d: Dictionary in _debris:
		var fade := clampf(float(d.max) - float(d.life), 0.0, 1.0)
		canvas.draw_rect(Rect2(float(d.x) - 8, float(d.y) - 2, 16, 4), Color(SHADOW, 0.3 * fade))
		var xform := _t(Vector2(float(d.x), float(d.y) - float(d.z)).round()) * Transform2D(float(d.ang), Vector2.ZERO) * _s(Vector2(float(d.face) * S, S)) * _t(-Vector2(d.center))
		canvas.draw_set_transform_matrix(xform)
		canvas.draw_texture(d.texture, Vector2.ZERO, Color(1, 1, 1, fade))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Beams, particles and flashes are drawn over the actors. The beams list is
## rebuilt each frame by draw_enemy.
func draw_over(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var beams_by_key: Dictionary = {}
	for beam: Dictionary in _beams: beams_by_key[beam.key] = beam
	beams_drawn = 0
	for enemy: Dictionary in snapshot.get("enemies", []):
		var key := "e%d" % int(enemy.get("id", 0))
		if beams_by_key.has(key) and enemy.get("beam") is Array:
			_draw_beam(canvas, beams_by_key[key], enemy.beam)
			beams_drawn += 1
	_beams.clear()
	for p: Dictionary in _particles:
		var k := 1.0 - float(p.life) / float(p.max)
		canvas.draw_rect(Rect2(Vector2(float(p.x), float(p.y)).round(), Vector2(2, 2)), Color(p.color, k))
	for flash: Dictionary in _flashes:
		var k := float(flash.life) / float(flash.max)
		if str(flash.get("kind", "")) == "ring":
			var radius := lerpf(6.0, float(flash.r), RigPoses.ease_out(k))
			for i in range(48):
				var angle := TAU * i / 48.0
				canvas.draw_rect(Rect2(Vector2(float(flash.x), float(flash.y)) + Vector2(cos(angle), sin(angle) * 0.55) * radius, Vector2(2, 2)), Color(flash.color, 1.0 - k))


func _draw_beam(canvas: CanvasItem, drawn: Dictionary, ends: Array) -> void:
	var eye: Vector2 = drawn.eye
	var end := Vector2(float(ends[2]), float(ends[3]) - 16.0)
	var beam: Dictionary = drawn.beam
	var t: float = drawn.t
	var length := maxf(1.0, eye.distance_to(end))
	var direction := (end - eye) / length
	var warn := float(beam.get("warn", 0.0))
	if warn > 0.0:
		var flick := 0.35 + 0.35 * sin(float(drawn.ct) * 40.0)
		var s := 8.0
		while s < length:
			if int(s / 4.0) % 3 != 0: canvas.draw_rect(Rect2((eye + direction * s).round(), Vector2(2, 2)), Color(VIOLET, flick * warn))
			s += 4.0
	var k := float(beam.get("k", 0.0))
	if k <= 0.0: return
	for layer: Array in [[7.0, INK], [5.2, VIOLET_DARK], [3.4, VIOLET], [1.6, VIOLET_HOT]]:
		var s := 0.0
		while s <= length:
			var wobble := 1.1 * sin(s * 0.16 - t * 38.0) + 0.7 * sin(s * 0.055 + t * 21.0) if float(layer[0]) > 2.0 else 0.0
			var radius := (float(layer[0]) + wobble) * k * (lerpf(0.5, 1.0, s / 12.0) if s < 12.0 else 1.0)
			if radius >= 0.9:
				var side := maxf(2.0, roundf(radius * 2.0 / 2.0) * 2.0)
				canvas.draw_rect(Rect2((eye + direction * s - Vector2(side, side) * 0.5).round(), Vector2(side, side)), layer[1])
			s += 2.0
	var flare := 6.0 + 2.0 * sin(t * 50.0)
	canvas.draw_circle(eye, (flare + 1.0) * k, VIOLET)
	canvas.draw_circle(eye, flare * 0.55 * k, VIOLET_HOT)
	canvas.draw_circle(end, (flare + 3.0) * k, VIOLET_DARK)
	canvas.draw_circle(end, flare * k, VIOLET)
	canvas.draw_circle(end, flare * 0.5 * k, VIOLET_HOT)
	if _rng.randf() < 0.6:
		_particles.append({"x": end.x, "y": end.y, "vx": -direction.x * _rng.randf_range(40, 140) + _rng.randf_range(-60, 60), "vy": -direction.y * _rng.randf_range(40, 140) + _rng.randf_range(-80, 20),
			"life": 0.0, "max": _rng.randf_range(0.2, 0.45), "color": [VIOLET_HOT, VIOLET, INK][_rng.randi_range(0, 2)], "grav": 180.0})


func _draw_pool(canvas: CanvasItem, pool: Dictionary) -> void:
	var k := float(pool.life) / float(pool.max)
	var grow := RigPoses.ease_out(RigPoses.seg(k, 0.0, 0.12)) * (1.0 - RigPoses.ease_in(RigPoses.seg(k, 0.7, 1.0)))
	var rx := float(pool.r) * grow
	var ry := rx * 0.45
	if rx < 2.0: return
	var rows := int(ceil(ry / 2.0))
	for row in range(-rows, rows + 1):
		var y := float(row) * 2.0
		var half := rx * sqrt(maxf(0.0, 1.0 - pow(y / (ry + 1.0), 2.0)))
		if half < 1.0: continue
		canvas.draw_rect(Rect2(Vector2(float(pool.x) - half, float(pool.y) + y).round(), Vector2(roundf(half * 2.0), 2)), VIOLET_DARK)
		if half > 3.0: canvas.draw_rect(Rect2(Vector2(float(pool.x) - half + 2.0, float(pool.y) + y).round(), Vector2(roundf(half * 2.0 - 4.0), 2)), Color("13111c"))
	for i in range(3):
		var angle := float(pool.life) * 2.0 + i * TAU / 3.0
		canvas.draw_rect(Rect2(Vector2(float(pool.x) + cos(angle) * rx * 0.6, float(pool.y) + sin(angle) * ry * 0.6).round(), Vector2(2, 2)), Color(VIOLET, 0.8))
	if _rng.randf() < 0.3:
		_particles.append({"x": float(pool.x) + _rng.randf_range(-rx, rx) * 0.7, "y": float(pool.y), "vx": _rng.randf_range(-6, 6), "vy": _rng.randf_range(-60, -28), "life": 0.0, "max": 0.55, "color": [Color("efe6d6"), VIOLET, VIOLET_DARK][_rng.randi_range(0, 2)]})


func _play_fx(event: Dictionary) -> void:
	var point := Vector2(float(event.get("x", 0)), float(event.get("y", 0)))
	var radius := float(event.get("r", 64))
	match str(event.get("kind", "")):
		"void_burst":
			_flashes.append({"kind": "ring", "x": point.x, "y": point.y, "r": radius, "life": 0.0, "max": 0.45, "color": VIOLET})
			_flashes.append({"kind": "ring", "x": point.x, "y": point.y, "r": radius * 0.6, "life": 0.0, "max": 0.35, "color": VIOLET_HOT})
			_flashes.append({"x": point.x, "y": point.y, "r": radius * 1.6, "life": 0.0, "max": 0.5, "color": VIOLET})
			_burst_at(point, VIOLET, 36, 220.0)
			_burst_at(point, INK, 18, 140.0)
		"slam":
			_flashes.append({"kind": "ring", "x": point.x, "y": point.y, "r": radius, "life": 0.0, "max": 0.4, "color": Color("a99d93")})
			for i in range(24): _particles.append({"x": point.x + _rng.randf_range(-radius, radius) * 0.5, "y": point.y, "vx": _rng.randf_range(-100, 100), "vy": _rng.randf_range(-90, -10), "life": 0.0, "max": _rng.randf_range(0.3, 0.6), "color": [Color("7b6a5e"), Color("a99d93")][_rng.randi_range(0, 1)], "grav": 280.0})


func _burst_at(point: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count) + _rng.randf_range(-0.2, 0.2)
		var velocity := Vector2(cos(angle), sin(angle)) * speed * _rng.randf_range(0.5, 1.0)
		_particles.append({"x": point.x, "y": point.y, "vx": velocity.x, "vy": velocity.y, "life": 0.0, "max": _rng.randf_range(0.3, 0.7), "color": color})


## Light sources from void effects for the dark crypt: [Vector3(x, y, radius)].
func lights(snapshot: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for enemy: Dictionary in snapshot.get("enemies", []):
		if enemy.get("beam") is Array and str(enemy.get("attack", "")) == "active" and str(enemy.get("attack_kind", "")) == "beam":
			var ends: Array = enemy.beam
			var from := Vector2(float(ends[0]), float(ends[1]))
			var to := Vector2(float(ends[2]), float(ends[3]))
			var steps := maxi(1, int(from.distance_to(to) / 40.0))
			for i in range(steps + 1): result.append(Vector3(lerpf(from.x, to.x, float(i) / steps), lerpf(from.y, to.y, float(i) / steps) - 16.0, 68.0))
		elif str(enemy.get("rig", "")) in ["void", "bomber"] and float(enemy.get("dying_p", -1.0)) < 0.0:
			result.append(Vector3(float(enemy.get("x", 0)), float(enemy.get("y", 0)) - 8.0, 72.0 if str(enemy.rig) == "void" else 40.0))
	for pool: Dictionary in _pools: result.append(Vector3(float(pool.x), float(pool.y), 44.0))
	for flash: Dictionary in _flashes:
		if str(flash.get("kind", "")) != "ring": result.append(Vector3(float(flash.x), float(flash.y), float(flash.r) * (1.0 - float(flash.life) / float(flash.max))))
	return result

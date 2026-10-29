extends RefCounted
## Host-side body parts of rigged enemies. An enemy's HP is split over its
## rig's parts by their weights, so the parts always add up to the enemy's HP.
## A hit lands on the part at the impact point; a destroyed vital part kills,
## other parts fall off (and may grow back), and some parts enable an action
## ("attack", "cast", "block", "beam", "summon") that is lost with them.
## Only the host calls this; clients draw `parts_lost` from the snapshot.

const RigLibrary = preload("res://src/rig/rig_library.gd")

var _library: RefCounted
var _rng := RandomNumberGenerator.new()
## enemy id -> part id chosen by the caller for the next damage to that enemy.
var _pending: Dictionary = {}
## rig name -> broad-phase reach in world px.
var _reach: Dictionary = {}


func _init(library: RefCounted = null) -> void:
	_library = library if library != null else RigLibrary.shared()


## Seeds the fallback choice for damage without an impact point (statuses).
func reset(seed_value: int) -> void:
	_rng.seed = seed_value
	_pending.clear()


func has_parts(enemy: Dictionary) -> bool:
	return enemy.has("parts") and not str(enemy.get("rig", "")).is_empty()


## Splits the enemy's max HP over the rig's part weights. Unknown rigs leave
## the enemy as a single HP pool.
func attach(enemy: Dictionary, rig_name: String) -> void:
	var weights: Dictionary = _library.weights(rig_name)
	if weights.is_empty(): return
	var total := 0.0
	for weight: float in weights.values(): total += weight
	var parts: Dictionary = {}
	for id: String in weights:
		var share: float = float(enemy.max_hp) * float(weights[id]) / total
		parts[id] = {"hp": share, "max": share}
	enemy.rig = rig_name
	enemy.parts = parts
	enemy.parts_lost = []
	enemy.regrow = {}
	enemy.hp = _sum(enemy)


## Ids of parts that are still attached (and can be hit).
func alive(enemy: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in enemy.get("parts", {}):
		if not id in enemy.parts_lost: result[id] = true
	return result


## The part a projectile hits on its way from `from` to `to`, or "" for a
## miss. Samples the swept segment every 2 px against the rest-pose pixels.
func segment_part(enemy: Dictionary, from: Vector2, to: Vector2, radius: float) -> String:
	var length := from.distance_to(to)
	var steps := maxi(1, int(ceil(length / 2.0)))
	var living := alive(enemy)
	for step in range(steps + 1):
		var point := from.lerp(to, float(step) / float(steps))
		var part: String = _library.part_at(str(enemy.rig), Vector2(enemy.pos), _face(enemy), point, living, _active(enemy), radius)
		if not part.is_empty(): return part
	return ""


## Largest distance from the enemy's centre to any part pixel, in world px:
## the broad-phase radius for projectile tests (cached per rig).
func reach(enemy: Dictionary) -> float:
	var name: String = str(enemy.get("rig", ""))
	if _reach.has(name): return float(_reach[name])
	var data: Dictionary = _library.rig(name)
	if data.is_empty(): return float(enemy.get("radius", 13))
	var anchor := Vector2(data.ground.x, float(data.center.y) + float(data.hover))
	var result := 0.0
	for part: Dictionary in data.parts + data.items:
		var box: Rect2 = part.bounds
		for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			result = maxf(result, corner.distance_to(anchor))
	_reach[name] = result * float(data.get("scale", RigLibrary.PIXEL_SCALE))
	return float(_reach[name])


## The living part nearest to a world point (melee, splash, area damage).
func part_near(enemy: Dictionary, point: Vector2) -> String:
	return _library.nearest_part(str(enemy.rig), Vector2(enemy.pos), _face(enemy), point, alive(enemy), _active(enemy))


## The caller's impact part for the next damage to this enemy.
func set_pending(enemy: Dictionary, part: String) -> void:
	if not part.is_empty(): _pending[int(enemy.id)] = part


func take_pending(enemy: Dictionary) -> String:
	var id := int(enemy.get("id", -1))
	var part: String = str(_pending.get(id, ""))
	_pending.erase(id)
	return part


## Damages one part. The full damage always counts against the enemy's total
## HP (which starts as the sum of the parts), so big hits stay lethal; the hit
## part breaks off once its own HP is gone, and a broken vital part kills at
## once. An `unbreakable` part (a boss's legs, head and body) never breaks and
## never kills on its own: only the total HP decides. Without a part, a seeded
## choice prefers non-vital parts (3 in 4), like the review page.
## Returns {"part", "destroyed", "killed"}.
func damage(enemy: Dictionary, amount: float, part: String = "") -> Dictionary:
	var living := alive(enemy)
	if living.is_empty() or amount <= 0.0: return {"part": "", "destroyed": false, "killed": false}
	if part.is_empty() or not living.has(part): part = _fallback(enemy, living)
	var state: Dictionary = enemy.parts[part]
	state.hp = maxf(0.0, float(state.hp) - amount)
	enemy.hp = maxf(0.0, float(enemy.hp) - amount)
	var result := {"part": part, "destroyed": false, "killed": float(enemy.hp) <= 0.0}
	if float(state.hp) <= 0.0 and not bool(_spec(enemy, part).get("unbreakable", false)):
		result.destroyed = true
		var spec: Dictionary = _spec(enemy, part)
		if bool(spec.get("vital", false)):
			result.killed = true
			for id: String in enemy.parts: enemy.parts[id].hp = 0.0
			enemy.hp = 0.0
			return result
		_lose(enemy, part)
		for extra: String in spec.get("also_detach", []):
			if enemy.parts.has(extra) and not extra in enemy.parts_lost:
				enemy.parts[extra].hp = 0.0
				_lose(enemy, extra)
		if float(spec.get("regrow", 0.0)) > 0.0: enemy.regrow[part] = float(spec.regrow)
		enemy.part_breaks = int(enemy.get("part_breaks", 0)) + 1
	# Every part gone (no vital one hit): the enemy falls apart.
	if alive(enemy).is_empty(): result.killed = true
	if bool(result.killed): enemy.hp = 0.0
	return result


## Regrowth: a lost part returns with half its HP after its delay.
func step(enemy: Dictionary, delta: float) -> void:
	if not has_parts(enemy) or float(enemy.hp) <= 0.0: return
	var regrow: Dictionary = enemy.regrow
	for id: String in regrow.keys():
		regrow[id] = float(regrow[id]) - delta
		if float(regrow[id]) > 0.0: continue
		regrow.erase(id)
		enemy.parts_lost.erase(id)
		enemy.parts[id].hp = float(enemy.parts[id].max) * 0.5
		enemy.part_regrows = int(enemy.get("part_regrows", 0)) + 1
		# A regrown part brings its HP back to the total (up to the maximum).
		enemy.hp = minf(float(enemy.max_hp), float(enemy.hp) + float(enemy.parts[id].hp))


## False while a part that enables `action` is lost.
func can(enemy: Dictionary, action: String) -> bool:
	if not has_parts(enemy): return true
	for id: String in enemy.parts_lost:
		if str(_spec(enemy, id).get("disables", "")) == action: return false
	return true


## Movement scale from lost legs (one 0.6, both 0.35) or a skeleton's torso (0.7).
func speed_scale(enemy: Dictionary) -> float:
	if not has_parts(enemy): return 1.0
	var lost: Array = enemy.parts_lost
	if "torso" in lost and _library.rig(str(enemy.rig)).get("family", "") == "skeleton": return 0.7
	var legs := 0
	for id: String in ["leg_l", "leg_r", "foot_l", "foot_r"]:
		if id in lost: legs += 1
	return 0.35 if legs >= 2 else 0.6 if legs == 1 else 1.0


func _lose(enemy: Dictionary, id: String) -> void:
	if not id in enemy.parts_lost: enemy.parts_lost.append(id)


func _sum(enemy: Dictionary) -> float:
	var total := 0.0
	for id: String in enemy.parts:
		if not id in enemy.parts_lost: total += float(enemy.parts[id].hp)
	return total


func _spec(enemy: Dictionary, id: String) -> Dictionary:
	return _library.rig(str(enemy.get("rig", ""))).get("by_id", {}).get(id, {})


func _face(enemy: Dictionary) -> float:
	return -1.0 if float(enemy.get("face", 1.0)) < 0.0 else 1.0


func _active(enemy: Dictionary) -> String:
	return str(enemy.get("exposed_action", ""))


func _fallback(enemy: Dictionary, living: Dictionary) -> String:
	var vitals: Array[String] = []
	var others: Array[String] = []
	for id: String in living:
		if bool(_spec(enemy, id).get("vital", false)): vitals.append(id)
		else: others.append(id)
	vitals.sort()
	others.sort()
	if others.is_empty() or (not vitals.is_empty() and _rng.randf() < 0.25): return vitals[_rng.randi_range(0, vitals.size() - 1)]
	return others[_rng.randi_range(0, others.size() - 1)]

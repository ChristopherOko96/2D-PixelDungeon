extends RefCounted
## Host-side body parts of rigged enemies. An enemy's HP is split over its
## rig's parts by their weights, so the parts always add up to the enemy's HP.
## A hit lands on the part at the impact point; a destroyed vital part kills,
## other parts fall off (and may grow back), and some parts enable an action
## ("attack", "cast", "block", "beam", "summon") that is lost with them. Hell
## rigs list several attack ids per part, disable an attack once a whole part
## group is gone (both wings) and weaken attacks while parts are lost
## (scale(): "weakens" {attack: {param: factor}}, multiplied over lost parts).
## Only the host calls this; clients draw `parts_lost` from the snapshot.

const RigLibrary = preload("res://src/rig/rig_library.gd")

var _library: RefCounted
var _rng := RandomNumberGenerator.new()
## enemy key (uid, else id) -> part id chosen by the caller for the next damage.
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
	if not part.is_empty(): _pending[_key(enemy)] = part


## The pending impact part of this enemy (used once), or "".
func take_pending(enemy: Dictionary) -> String:
	var key: Variant = _key(enemy)
	var part: String = str(_pending.get(key, ""))
	_pending.erase(key)
	return part


## Damages one part. The full damage always counts against the enemy's total
## HP (which starts as the sum of the parts), so big hits stay lethal; the hit
## part breaks off once its own HP is gone, and a broken vital part kills at
## once. An `unbreakable` part (a boss's legs, head and body) never breaks and
## never kills on its own: only the total HP decides. Without a part, a seeded
## choice prefers non-vital parts (3 in 4), like the review page; on hell rigs
## it never picks a hidden `exposed` part or one without pixels (_fallback).
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
		# The rig's own delay wins; else the enemy's (a hell boss: regrow_after).
		var regrow := float(spec.get("regrow", 0.0))
		if regrow <= 0.0: regrow = float(enemy.get("regrow_after", 0.0))
		if regrow > 0.0: enemy.regrow[part] = regrow
		enemy.part_breaks = int(enemy.get("part_breaks", 0)) + 1
	# Every part gone (no vital one hit): the enemy falls apart.
	if alive(enemy).is_empty(): result.killed = true
	if bool(result.killed): enemy.hp = 0.0
	return result


## Regrowth: a lost part returns with half its HP after its delay. The parts
## that fell with it (also_detach, a tail's tip) return with it unless they
## wait for a regrowth of their own.
func step(enemy: Dictionary, delta: float) -> void:
	if not has_parts(enemy) or float(enemy.hp) <= 0.0: return
	var regrow: Dictionary = enemy.regrow
	for id: String in regrow.keys():
		regrow[id] = float(regrow[id]) - delta
		if float(regrow[id]) > 0.0: continue
		regrow.erase(id)
		enemy.parts_lost.erase(id)
		enemy.parts[id].hp = float(enemy.parts[id].max) * 0.5
		for extra: String in _spec(enemy, id).get("also_detach", []):
			if extra in enemy.parts_lost and not regrow.has(extra) and enemy.parts.has(extra):
				enemy.parts_lost.erase(extra)
				enemy.parts[extra].hp = float(enemy.parts[extra].max) * 0.5
		enemy.part_regrows = int(enemy.get("part_regrows", 0)) + 1
		# A regrown part brings its HP back to the total (up to the maximum).
		enemy.hp = minf(float(enemy.max_hp), float(enemy.hp) + float(enemy.parts[id].hp))


## The part a hit on `part` counts on: a living breakable part that would take
## an unbreakable `part` with it (also_detach: a hit on the dragon's tail tip
## counts on the severable tail_2), else `part` itself.
func carrier(enemy: Dictionary, part: String) -> String:
	if part.is_empty() or not bool(_spec(enemy, part).get("unbreakable", false)): return part
	var living := alive(enemy)
	for id: String in living:
		var spec: Dictionary = _spec(enemy, id)
		if bool(spec.get("unbreakable", false)): continue
		if part in Array(spec.get("also_detach", [])): return id
	return part


## False while a part that enables `action` is lost (its "disables" names the
## action: one string in the crypt, a list in hell rigs), or while every part
## of a rig group that disables `action` is lost (both wings: no bombing run).
func can(enemy: Dictionary, action: String) -> bool:
	if not has_parts(enemy): return true
	var lost: Array = enemy.get("parts_lost", [])
	for id: Variant in lost:
		if action in RigLibrary.disabled_actions(_spec(enemy, str(id)).get("disables", "")): return false
	var groups: Dictionary = _library.rig(str(enemy.get("rig", ""))).get("groups", {})
	for group_id: Variant in groups:
		var group: Dictionary = groups[group_id]
		if not action in RigLibrary.disabled_actions(group.get("disables", [])): continue
		var members: Array = group.get("parts", [])
		if members.is_empty(): continue
		var all_lost := true
		for member: Variant in members:
			if not str(member) in lost:
				all_lost = false
				break
		if all_lost: return false
	return true


## Strength factor of one parameter of `action` while parts are lost: the
## product of the "weakens"[action][param] factors of every lost part (1.0
## when none). Callers round counts (min 1) and treat 0 on a flag as off.
func scale(enemy: Dictionary, action: String, param: String) -> float:
	return float(weakened(enemy, action).get(param, 1.0))


## Every weakened parameter of `action` -> its combined factor (for logs and
## tests); empty while nothing that weakens `action` is lost.
func weakened(enemy: Dictionary, action: String) -> Dictionary:
	var result: Dictionary = {}
	if not has_parts(enemy): return result
	for id: Variant in enemy.get("parts_lost", []):
		var weakens: Variant = _spec(enemy, str(id)).get("weakens", {})
		if not weakens is Dictionary or not weakens.get(action) is Dictionary: continue
		var params: Dictionary = weakens[action]
		for param: Variant in params:
			result[str(param)] = float(result.get(str(param), 1.0)) * float(params[param])
	return result


## Movement scale from lost legs (one 0.6, both 0.35) or a skeleton's torso
## (0.7). A four-legged companion's leg pairs (paws, hind) count as legs.
func speed_scale(enemy: Dictionary) -> float:
	if not has_parts(enemy): return 1.0
	var lost: Array = enemy.parts_lost
	if "torso" in lost and _library.rig(str(enemy.rig)).get("family", "") == "skeleton": return 0.7
	var legs := 0
	for id: String in ["leg_l", "leg_r", "foot_l", "foot_r", "paws", "hind"]:
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


## Per-enemy key: hell monsters carry a string id and an int uid, crypt enemies
## an int id. Numbers are keyed as int so 5 and 5.0 stay the same enemy.
func _key(enemy: Dictionary) -> Variant:
	var key: Variant = enemy.get("uid", enemy.get("id", -1))
	if key is int or key is float: return int(key)
	return str(key)


func _face(enemy: Dictionary) -> float:
	return -1.0 if float(enemy.get("face", 1.0)) < 0.0 else 1.0


func _active(enemy: Dictionary) -> String:
	return str(enemy.get("exposed_action", ""))


## The part hit by damage without an impact point (statuses, burn ticks): a
## seeded choice, vital parts 1 in 4. On layered (hell) rigs only parts a hit
## could reach are candidates: no `exposed` part outside its action (the throat
## between breaths) and no part without pixels (missing image); if that leaves
## none, every living part is. Crypt rigs keep the legacy candidates, so their
## seeded sequence is unchanged.
func _fallback(enemy: Dictionary, living: Dictionary) -> String:
	var candidates: Array = living.keys()
	if bool(_library.rig(str(enemy.get("rig", ""))).get("layered", false)):
		var active := _active(enemy)
		var reachable: Array = []
		for id: Variant in candidates:
			var spec: Dictionary = _spec(enemy, str(id))
			var exposed := str(spec.get("exposed", ""))
			if not exposed.is_empty() and exposed != active: continue
			if not Rect2(spec.get("bounds", Rect2())).has_area(): continue
			reachable.append(id)
		if not reachable.is_empty(): candidates = reachable
	var vitals: Array[String] = []
	var others: Array[String] = []
	for id: String in candidates:
		if bool(_spec(enemy, id).get("vital", false)): vitals.append(id)
		else: others.append(id)
	vitals.sort()
	others.sort()
	if others.is_empty() or (not vitals.is_empty() and _rng.randf() < 0.25): return vitals[_rng.randi_range(0, vitals.size() - 1)]
	return others[_rng.randi_range(0, others.size() - 1)]

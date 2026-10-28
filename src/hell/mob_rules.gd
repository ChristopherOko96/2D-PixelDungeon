extends RefCounted
## Pure rules for themed enemies (theme.mobs / theme.roster, e.g. the Frostgruft):
## which kinds fill a room, whether a shield blocks a hit, and what a dying
## enemy splits into. No nodes, no randomness of its own: callers pass rolls.


## Kinds allowed on a floor: roster entries whose "from" floor is reached.
static func floor_roster(roster: Array, floor_n: int) -> Array:
	return roster.filter(func(e: Dictionary) -> bool: return int(e.from) <= floor_n)


## Picks one kind per roll (0..1) by roster weight; [] when nothing is allowed.
static func pick_kinds(roster: Array, floor_n: int, rolls: Array) -> Array[String]:
	var allowed := floor_roster(roster, floor_n)
	var total := 0.0
	for e: Dictionary in allowed:
		total += float(e.weight)
	var out: Array[String] = []
	if total <= 0.0:
		return out
	for roll: float in rolls:
		var at := roll * total
		var kind: String = allowed[allowed.size() - 1].kind
		for e: Dictionary in allowed:
			at -= float(e.weight)
			if at < 0.0:
				kind = e.kind
				break
		out.append(kind)
	return out


## True when a hit travelling along hit_dir strikes the shield of an enemy
## facing along facing: the hit comes from inside the shield arc (radians) in front.
static func shield_blocks(facing: Vector2, hit_dir: Vector2, arc: float) -> bool:
	if facing == Vector2.ZERO or hit_dir == Vector2.ZERO:
		return false
	return absf(angle_difference(facing.angle(), (-hit_dir).angle())) <= arc / 2.0


## The kinds a dying enemy leaves behind (def.split = {into, count}).
static func split_children(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var split: Dictionary = def.get("split", {})
	for i in range(int(split.get("count", 0))):
		out.append(str(split.into))
	return out


## Sprite name of frame i for a def with sprite / frames (frames > 1: prefix + index).
static func frame_name(def: Dictionary, i: int) -> String:
	var n := int(def.get("frames", 1))
	return str(def.sprite) + (str(i % n) if n > 1 else "")

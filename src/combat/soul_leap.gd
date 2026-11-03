extends RefCounted
## Host-owned shadow jump. Ground collision remains authoritative throughout;
## height is a rig presentation value, never permission to pass through walls.

## Lock a collision-safe destination and start the bounded anticipation phase.
static func begin(tc: RefCounted, owner: int, info: Dictionary, aim: Vector2, damage: float) -> void:
	var hero: Dictionary = tc.game.players[owner]
	var rt: Dictionary = tc.runtime(owner)
	var origin: Vector2 = hero.pos
	var target: Vector2 = tc._move(origin, aim * tc._value(info, "dist_m", rt, "soul_7") * float(tc.data.meter_px), float(tc.game.balance.player.radius))
	rt.soul_leap = {"from": origin, "to": target, "age": 0.0, "duration": float(info.leap_time), "height": float(info.leap_height) * tc._world_scale(), "info": info.duplicate(true)}
	tc._area(owner, rt, "soul_7", info, origin, float(info.radius_m) * float(tc.data.meter_px), damage)
	tc._event("soul_takeoff", origin, 24.0, {"owner": owner, "talent": "soul_7", "life": float(info.leap_time)})

## Advance the ground footprint; leave the five-second field at the landing.
static func step(tc: RefCounted, owner: int, delta: float) -> void:
	var rt: Dictionary = tc.runtime(owner)
	if not rt.has("soul_leap"): return
	var hero: Dictionary = tc.game.players.get(owner, {})
	if hero.is_empty() or int(hero.hp) <= 0:
		rt.erase("soul_leap")
		return
	var leap: Dictionary = rt.soul_leap
	leap.age = minf(float(leap.duration), float(leap.age) + delta)
	var p := float(leap.age) / float(leap.duration)
	var desired := Vector2(leap.from).lerp(leap.to, smoothstep(0.12, 0.88, p))
	hero.pos = tc._move(hero.pos, desired - Vector2(hero.pos), float(tc.game.balance.player.radius))
	if p < 1.0: return
	rt.erase("soul_leap")
	var cfg: Dictionary = leap.info
	var half := float(cfg.trail_width_m) * float(tc.data.meter_px) * 0.5
	var middle: Vector2 = (Vector2(leap.from) + Vector2(hero.pos)) * 0.5
	if Vector2(leap.from).distance_to(hero.pos) > 4.0:
		tc.zones.append({"id": tc._take_id(), "owner": owner, "talent": "soul_7", "pos": middle, "r": Vector2(leap.from).distance_to(hero.pos) * 0.5 + half,
			"path": [Vector2(leap.from), Vector2(hero.pos)], "w": half, "look": "souls_trail", "time": float(cfg.trail_time), "total": float(cfg.trail_time), "tick": 0.0, "every": 1.0,
			"dmg": 0.0, "status": "", "stage": 0, "info": cfg})
	tc._event("soul_landing", hero.pos, 32.0, {"owner": owner, "talent": "soul_7", "life": 0.6})

## Primitive hero animation state shared by Crypt/Hell/Frost.
static func snapshot(rt: Dictionary) -> Dictionary:
	if not rt.has("soul_leap"): return {}
	var leap: Dictionary = rt.soul_leap
	return {"age": float(leap.age), "duration": float(leap.duration), "height": float(leap.height)}

## Smooth vertical arc with anticipation and landing, in world pixels.
static func lift(state: Dictionary) -> float:
	if state.is_empty(): return 0.0
	var p := clampf(float(state.age) / float(state.duration), 0.0, 1.0)
	return sin(smoothstep(0.08, 0.92, p) * PI) * float(state.height)

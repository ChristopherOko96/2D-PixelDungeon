extends RefCounted
## Shared swept necromancer-shot collision in Crypt/Hell/Frost. Each short segment
## resolves its first wall or living target; a visual cannot pass a hit onward.

## Soul shots, curse projectile and bone spear share collision and impact rules.
static func owns(bullet: Dictionary) -> bool:
	return str(bullet.get("talent", "")) in ["soul_1", "soul_9", "curse_1", "minion_3"]

## Returns true when consumed. Substeps prevent a long host tick from skipping
## an enemy before a wall. Crypt targets retain the actual part-mask hit test.
static func step(tc: RefCounted, bullet: Dictionary, delta: float) -> bool:
	if bool(bullet.get("curse_spirit",false)):
		var target: Dictionary = tc.necromancer._target(tc,int(bullet.curse_target))
		if target.is_empty():
			impact(tc,bullet)
			return true
		bullet.velocity = (Vector2(target.pos)-Vector2(bullet.pos)).normalized()*float(tc.necromancer.cfg.curse.flight.speed)
	var radius := float(bullet.get("radius", 8.0))
	var travel: Vector2 = Vector2(bullet.velocity) * minf(delta, maxf(0.0, float(bullet.life)))
	var count := maxi(1, ceili(travel.length() / 2.0))
	var part := travel / count
	var body: Variant = tc.game.get("body_parts")
	for i in range(count):
		var from: Vector2 = bullet.pos
		var to := from + part
		if "chests" in tc.game and tc.game.chests.hit_segment(from, to, radius, int(bullet.owner), bullet):
			impact(tc, bullet)
			return true
		if tc._blocked(from, to, radius):
			impact(tc, bullet)
			return true
		bullet.pos = to
		for enemy: Dictionary in tc._living():
			if int(tc._eid(enemy)) in bullet.get("hit_ids",[]): continue
			if tc.game.has_method("talent_hittable") and not tc.game.talent_hittable(enemy): continue
			if Geometry2D.get_closest_point_to_segment(enemy.pos, from, to).distance_to(enemy.pos) > float(enemy.radius) + radius + 32.0: continue
			if body != null and body.has_parts(enemy):
				var hit_part: String = body.segment_part(enemy, from, to, radius)
				if hit_part.is_empty(): continue
				body.set_pending(enemy, hit_part)
			elif Geometry2D.get_closest_point_to_segment(enemy.pos, from, to).distance_to(enemy.pos) > float(enemy.radius) + radius: continue
			tc.bullet_hit(bullet, enemy)
			impact(tc, bullet, enemy)
			if str(bullet.talent) == "minion_3" and int(bullet.get("pierce",0)) > 0:
				if not bullet.has("hit_ids"): bullet.hit_ids = []
				bullet.hit_ids.append(tc._eid(enemy))
				bullet.pierce = int(bullet.pierce)-1
				continue
			return true
	bullet.life = maxf(0.0, float(bullet.life) - delta)
	if float(bullet.life) <= 0.0:
		impact(tc, bullet)
		return true
	return false

## One authoritative impact, with bounded splash only on the charged lance.
static func impact(tc: RefCounted, bullet: Dictionary, direct: Dictionary = {}) -> void:
	if str(bullet.talent) in ["curse_1","minion_3"]:
		if bool(bullet.get("necro_ended",false)): return
		if direct.is_empty(): bullet.necro_ended = true
		tc._event("necro_impact",bullet.pos,float(tc.data.meter_px)*0.7,{"talent":str(bullet.talent),"owner":int(bullet.owner),"curse_spirit":bool(bullet.get("curse_spirit",false)),"life":0.65})
		return
	if bool(bullet.get("soul_ended", false)): return
	bullet.soul_ended = true
	var owner := int(bullet.owner)
	var power := float(bullet.get("charge", 0.0))
	var talent := str(bullet.talent)
	var info: Dictionary = tc.data.talents[talent]
	var radius := float(info.get("impact_m", 0.7)) * float(tc.data.meter_px)
	if info.has("charge"): radius = lerpf(float(info.impact_m), float(info.charge.impact_m), power) * float(tc.data.meter_px)
	if talent == "soul_9" and not direct.is_empty():
		var rt: Dictionary = tc.runtime(owner)
		var previous_hit: bool = tc._talent_hit
		var target := int(rt.get("hero_target", -1))
		tc._talent_hit = true
		for enemy: Dictionary in tc._living():
			if is_same(enemy, direct) or Vector2(enemy.pos).distance_to(bullet.pos) > radius + float(enemy.radius): continue
			if tc._blocked(bullet.pos, enemy.pos, 1.0): continue
			tc._hit(owner, enemy, float(bullet.damage) * float(info.charge.splash), {}, rt, talent)
		tc._talent_hit = previous_hit
		rt.hero_target = target
	tc._event("soul_impact", bullet.pos, radius, {"owner": owner, "talent": talent, "charge": power, "dx": Vector2(bullet.velocity).normalized().x, "dy": Vector2(bullet.velocity).normalized().y, "life": 0.75})

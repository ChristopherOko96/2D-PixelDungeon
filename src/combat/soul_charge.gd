extends RefCounted
## Host-owned held Seelenlanze/Himmelsspeer. Extra power costs real resources;
## neither clients nor elapsed render time can choose charge or damage.

## Pay the base cost and start one bounded learned bar/ultimate charge.
static func begin(tc: RefCounted, id: int, talent: String, info: Dictionary, command: Dictionary) -> bool:
	var rt: Dictionary = tc.runtime(id)
	var hero: Dictionary = tc.game.players[id]
	var aim := Vector2(command.get("aim", hero.get("aim", Vector2.RIGHT)))
	if not aim.is_finite() or aim.length_squared() < 0.001: aim = Vector2.RIGHT
	rt.res = maxf(0.0, float(rt.res) - tc.cost_of(rt, talent))
	rt.cds[talent] = float(info.cd)
	rt.gcd = float(tc.data.global_cooldown)
	rt.cast_count = int(rt.get("cast_count", 0)) + 1
	rt.soul_charge = {"talent": talent, "slot": int(command.get("slot", 0)), "info": info.duplicate(true), "age": 0.0, "power": 0.0,
		"aim": aim.normalized(),"bit":tc.ULT_BIT if talent==str(rt.get("ultimate","")) else tc.BAR_BIT+int(command.get("slot",0))}
	tc._event("cast", hero.pos, 0.0, {"talent": talent, "owner": id, "angle": Vector2(rt.soul_charge.aim).angle(), "windup": float(info.charge.time), "life": float(info.charge.time)})
	return true

## The ordinary validated held-key mask controls release; no charge value is read.
static func hold(tc: RefCounted, id: int, held: bool, aim: Vector2) -> void:
	var rt: Dictionary = tc.runtime(id)
	if not rt.has("soul_charge"): return
	if aim.is_finite() and aim.length_squared() > 0.001: rt.soul_charge.aim = aim.normalized()
	if not held: release(tc, id)

## Grow only as far as the host can pay. At full power or exhaustion, release.
static func step(tc: RefCounted, id: int, delta: float) -> void:
	var rt: Dictionary = tc.runtime(id)
	if not rt.has("soul_charge"): return
	var hero: Dictionary = tc.game.players.get(id, {})
	if hero.is_empty() or int(hero.hp) <= 0:
		rt.erase("soul_charge")
		return
	var charge: Dictionary = rt.soul_charge
	var cfg: Dictionary = charge.info.charge
	var rate := float(cfg.extra_cost) / float(cfg.time)
	var time := minf(maxf(0.0, delta), float(cfg.time) - float(charge.age))
	var wanted := rate * time
	var paid := minf(wanted, maxf(0.0, float(rt.res)))
	rt.res = maxf(0.0, float(rt.res) - paid)
	charge.age = minf(float(cfg.time), float(charge.age) + paid / rate)
	charge.power = clampf(float(charge.age) / float(cfg.time), 0.0, 1.0)
	if paid < wanted - 0.00001 or float(charge.power) >= 0.99999: release(tc, id)

## Release once, with the affordable host-computed power and current aim.
static func release(tc: RefCounted, id: int) -> void:
	var rt: Dictionary = tc.runtime(id)
	if not rt.has("soul_charge"): return
	var charge: Dictionary = rt.soul_charge
	rt.erase("soul_charge")
	var hero: Dictionary = tc.game.players.get(id, {})
	if hero.is_empty() or int(hero.hp) <= 0: return
	var info: Dictionary = charge.info.duplicate(true)
	info.charge_power = float(charge.power)
	var cfg: Dictionary = info.charge
	var scale := lerpf(1.0, float(cfg.damage_mult), float(charge.power))
	var previous_stage: int=tc._ult_stage
	tc._ult_stage=int(rt.get("soul_tier",0)) if str(charge.talent)==str(rt.get("ultimate","")) else -1
	tc._run(id, hero, rt, str(charge.talent), info, charge.aim, Vector2(hero.pos) + Vector2(charge.aim) * 160.0, scale)
	tc._stage_effects(id,hero,rt,str(charge.talent),info)
	tc._ult_stage=previous_stage
	rt.cds[str(charge.talent)] = float(info.cd)
	rt.gcd = float(tc.data.global_cooldown)
	tc._event("cast", hero.pos, 0.0, {"talent": str(charge.talent), "owner": id, "angle": Vector2(charge.aim).angle(), "life": 0.5})

## Primitive charge indicator, shared by every world's rig/VFX layer.
static func snapshot(tc: RefCounted) -> Array:
	var out: Array = []
	for id: Variant in tc.runtimes:
		var rt: Dictionary = tc.runtime(int(id))
		var hero: Dictionary = tc.game.players.get(id, {})
		if not rt.has("soul_charge") or hero.is_empty(): continue
		out.append({"owner": int(id),"talent":str(rt.soul_charge.talent), "x": Vector2(hero.pos).x, "y": Vector2(hero.pos).y, "age": float(rt.soul_charge.age), "power": float(rt.soul_charge.power),
			"ax": Vector2(rt.soul_charge.aim).x, "ay": Vector2(rt.soul_charge.aim).y})
	return out

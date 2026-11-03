extends RefCounted
## Host-only one-use marks and bounded arrow pinning. No client damage values.
var context: Dictionary = {}

## Mark every visible nearby foe independently for this owner.
func mark(tc: RefCounted, owner: int, info: Dictionary, rt: Dictionary) -> void:
	var at: Vector2=tc.game.players[owner].pos
	for enemy: Dictionary in tc._living():
		if at.distance_to(enemy.pos)>float(info.radius_m)*float(tc.data.meter_px) or tc._blocked(at,enemy.pos,1): continue
		var marks: Dictionary=enemy.get("marksman_marks",{})
		marks[str(owner)]={"time":tc._value(info,"time",rt,"sniper_5"),"pct":tc._value(info,"pct",rt,"sniper_5")}
		enemy.marksman_marks=marks
		tc._event("marksman_mark",enemy.pos,20,{"owner":owner,"life":0.5})

## Scope a real direct arrow impact; callers restore it before secondary damage.
func begin(owner: int, enemy: Dictionary) -> Dictionary:
	var previous:=context
	context={"owner":owner,"enemy":enemy}
	return previous

## Restore a nested damage scope without affecting another player's mark.
func end(previous: Dictionary) -> void:
	context=previous

## Called by outgoing only inside the primary projectile/ultimate hit scope.
func bonus(owner: int, enemy: Dictionary, feedback: bool) -> float:
	if not feedback or int(context.get("owner",-1))!=owner or not is_same(context.get("enemy",{}),enemy): return 0
	return float(enemy.get("marksman_marks",{}).get(str(owner),{}).get("pct",0))

## A shielded/zero hit keeps the mark; resolved own direct damage spends it.
func dealt(tc: RefCounted, owner: int, enemy: Dictionary, resolved: float, feedback: bool) -> void:
	if resolved<=0 or bonus(owner,enemy,feedback)<=0: return
	var marks: Dictionary=enemy.get("marksman_marks",{})
	marks.erase(str(owner))
	tc._event("marksman_bonus",enemy.pos,26,{"owner":owner,"life":0.45})

## All ordinary targets in the line are carried, then held. Bosses are immune.
func pin(tc: RefCounted, owner: int, enemy: Dictionary, aim: Vector2, info: Dictionary) -> void:
	if tc._boss(enemy) or float(enemy.hp)<=0 or not info.has("pin"): return
	var rule: Dictionary=info.pin
	var power:=clampf(float(info.get("charge_power",0)),0,1)
	enemy.marksman_pin={"owner":owner,"aim":aim,"push_left":float(rule.push_time),"time":lerpf(float(rule.time_min),float(rule.time),power),"speed":lerpf(float(rule.push_m)*0.5,float(rule.push_m),power)*float(tc.data.meter_px)/float(rule.push_time)}
	enemy.knockback=Vector2.ZERO

## Same swept movement as actors; no teleport through a wall and no ice status.
func step(tc: RefCounted, delta: float) -> void:
	for enemy: Dictionary in tc._living():
		var marks: Dictionary=enemy.get("marksman_marks",{})
		for key: String in marks.keys():
			marks[key].time=float(marks[key].time)-delta
			if float(marks[key].time)<=0: marks.erase(key)
		if not enemy.has("marksman_pin"): continue
		var pin: Dictionary=enemy.marksman_pin
		pin.time=float(pin.time)-delta
		if float(pin.time)<=0 or tc._boss(enemy): enemy.erase("marksman_pin"); continue
		var moving:=minf(delta,maxf(0,float(pin.push_left)))
		if moving>0:
			enemy.pos=tc._move(enemy.pos,Vector2(pin.aim)*float(pin.speed)*moving,float(enemy.radius))
			pin.push_left=maxf(0,float(pin.push_left)-delta)
		enemy.knockback=Vector2.ZERO
		tc._hold_enemy(enemy,maxf(0.1,float(pin.time)))

## Only primitives cross the network; part textures remain process-local.
func snapshot(tc: RefCounted) -> Dictionary:
	var out:={"marks":[],"pins":[]}
	for enemy: Dictionary in tc._living():
		for key: String in enemy.get("marksman_marks",{}):
			out.marks.append({"owner":int(key),"id":tc._eid(enemy),"x":enemy.pos.x,"y":enemy.pos.y,"time":float(enemy.marksman_marks[key].time)})
		if enemy.has("marksman_pin"):
			var p: Dictionary=enemy.marksman_pin
			out.pins.append({"id":tc._eid(enemy),"x":enemy.pos.x,"y":enemy.pos.y,"ax":Vector2(p.aim).x,"ay":Vector2(p.aim).y,"time":float(p.time)})
	return out

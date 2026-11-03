extends RefCounted
## Paid ability charges recharge sequentially; the HUD receives copies only.

## Initialize lazily and preserve spent charges across same-class build edits.
static func state(rt: Dictionary, talent: String, info: Dictionary) -> Dictionary:
	if not rt.has("ability_charges"): rt.ability_charges={}
	if not rt.ability_charges.has(talent): rt.ability_charges[talent]={"left":int(info.charges),"max":int(info.charges),"timer":0.0,"recharge":float(info.cd)}
	return rt.ability_charges[talent]

## Spend exactly one charge, preserving any partially completed refill.
static func spend(rt: Dictionary, talent: String, info: Dictionary, cooldown: float) -> void:
	var charge:=state(rt,talent,info)
	charge.left=maxi(0,int(charge.left)-1)
	charge.recharge=cooldown
	rt.cds[talent]=maxf(0,cooldown-float(charge.timer)) if int(charge.left)==0 else 0.0

## Refill one by one, including long ticks, never more than the configured cap.
static func step(rt: Dictionary, delta: float) -> void:
	for talent: String in rt.get("ability_charges",{}):
		var charge: Dictionary=rt.ability_charges[talent]
		if int(charge.left)>=int(charge.max): charge.timer=0; continue
		charge.timer=float(charge.timer)+delta
		var every:=maxf(0.1,float(charge.recharge))
		while float(charge.timer)>=every and int(charge.left)<int(charge.max):
			charge.timer=float(charge.timer)-every
			charge.left=int(charge.left)+1
		if int(charge.left)>=int(charge.max): charge.timer=0
		rt.cds[talent]=maxf(0,every-float(charge.timer)) if int(charge.left)==0 else 0.0

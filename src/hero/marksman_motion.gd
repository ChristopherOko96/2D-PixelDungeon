extends RefCounted
## Presentation-only attack poses from acknowledged casts; never alters actor position or rules.
const DURATIONS := {"sniper_1":0.36,"sniper_3":0.4,"sniper_5":0.45,"sniper_7":0.42,"sniper_9":0.5,"sniper_11":0.48,"sniper_14":0.42}
var _casts: Dictionary = {}

## Observe each actor's newest cast using host age; repeated snapshots cannot restart it.
func observe(key: String, owner: int, events: Array, clock: float, alive: bool) -> void:
	if not alive:
		_casts.erase(key)
		return
	var latest: Dictionary = {}
	for event: Dictionary in events:
		var talent := str(event.get("talent",""))
		if str(event.get("kind","")) != "cast" or int(event.get("owner",-1)) != owner or not DURATIONS.has(talent): continue
		if latest.is_empty() or int(event.get("id",-1)) > int(latest.get("id",-1)): latest = event
	if latest.is_empty():
		_casts.erase(key)
		return
	var event := latest
	var talent := str(event.talent)
	var age := maxf(0,float(event.get("span",0.5))-float(event.get("life",0)))
	var previous: Dictionary = _casts.get(key,{})
	var id := int(event.get("id",-1))
	if not previous.is_empty() and id == int(previous.id) and age >= float(previous.age)-0.05:
		previous.age = age
		previous.born = minf(float(previous.born),clock-age)
		return
	_casts[key] = {"id":id,"talent":talent,"born":clock-age,"age":age,"duration":float(DURATIONS[talent])}
	if _casts.size() > 32:
		for old: String in _casts.keys():
			if clock-float(_casts[old].born) > 2: _casts.erase(old)

## A fresh run or room boundary drops retained cast IDs and local motion clocks.
func reset() -> void:
	_casts.clear()

## Current rig intent. Charge wins until release; dead and non-archer actors stay neutral.
func frame(key: String, player: Dictionary, clock: float) -> Dictionary:
	if str(player.get("class_id","")) != "archer" or float(player.get("hp",1)) <= 0: return {}
	var charge: Dictionary = player.get("talents",{}).get("charge",{})
	if str(charge.get("talent","")) == "sniper_14":
		return {"talent":"charge","p":clampf(float(charge.get("power",0)),0,1)}
	var cast: Dictionary = _casts.get(key,{})
	if cast.is_empty(): return {}
	var age := clock-float(cast.born)
	if age < 0 or age >= float(cast.duration): return {}
	return {"talent":str(cast.talent),"p":age/float(cast.duration)}

## Articulates the existing elf's actual head, torso and boots with its held bow.
static func apply(rig: Dictionary, state: Dictionary, pose: Dictionary) -> void:
	if state.is_empty(): return
	var talent := str(state.get("talent",""))
	var p := clampf(float(state.get("p",0)),0,1)
	var beat := sin(p*PI)
	if talent == "sniper_9":
		pose.whole.rot -= TAU*p
		pose.whole.dy -= sin(p*PI)*7
		pose.whole.pivot = rig.center
		return
	if talent == "charge":
		pose.whole.rot -= 0.10+0.08*p
		pose.whole.dx -= 1+p
		_move(pose,"head",-0.06*p,-p,0)
		_move(pose,"body",-0.05*p,-p,0)
		return
	if talent == "sniper_14":
		var recoil:=(1.0-pow(1.0-clampf(p/0.14,0,1),3))*(1.0-smoothstep(0.14,1,p))
		pose.whole.dx-=recoil*3
		pose.whole.rot-=recoil*0.16
		_move(pose,"head",-0.08*recoil,-recoil,0)
		_move(pose,"body",-0.08*recoil,-recoil,0)
		_move(pose,"foot_l",0,-recoil,0)
		return
	if talent == "sniper_11":
		_move(pose,"body",-0.12*beat,0,-beat)
		_move(pose,"head",-0.16*beat,0,-beat)
		pose.whole.rot -= 0.12*beat
	elif talent == "sniper_5":
		_move(pose,"body",-0.06*beat,beat,0)
		_move(pose,"head",-0.08*beat,beat,0)
	else:
		var force := 1.5 if talent in ["sniper_3","sniper_14"] else 1.0
		pose.whole.dx -= beat*1.6*force
		pose.whole.rot -= beat*0.08*force
		_move(pose,"head",-0.05*beat,-beat,0)
		_move(pose,"body",0.06*beat,-beat,0)
		_move(pose,"foot_l",0,-beat,0)
		_move(pose,"foot_r",0,beat,0)

static func _move(pose: Dictionary, id: String, angle: float, x: float, y: float) -> void:
	if not pose.parts.has(id): pose.parts[id] = {"dx":0.0,"dy":0.0,"rot":0.0,"sx":1.0,"sy":1.0,"alpha":1.0}
	pose.parts[id].rot += angle
	pose.parts[id].dx += x
	pose.parts[id].dy += y

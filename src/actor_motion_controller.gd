extends RefCounted
## Presentation state only. Counters select clips; clips never grant game actions.
var _time: float = 0.0
var _entries: Dictionary = {}
var _last_player_hp: Dictionary = {}
var _run_key: String = ""
var _room_key: String = ""
var _durations: Dictionary = {}
var _settings: Dictionary = {}

## Accept the animation catalog's timings independently of texture loading.
func configure(catalog: Dictionary) -> void:
	_durations.clear()
	for action: Dictionary in catalog.get("actions",[]):
		var duration: float = float(action.get("duration",0.2))
		if is_finite(duration) and duration > 0: _durations[str(action.id)] = duration
	_settings = catalog.get("controller",{})

## Clear transient state on session/run reset, preserving the immutable catalog.
func reset() -> void:
	_time = 0.0
	_entries.clear()
	_last_player_hp.clear()
	_run_key = ""
	_room_key = ""

## Called once per visible unpaused frame, never once per actor.
func advance(delta: float) -> void:
	if is_finite(delta) and delta > 0: _time += delta

func _duration(clip: String) -> float:
	var defaults: Dictionary = {"death_start":0.24,"death_fall":0.36,"death_settle":0.3,"spawn":0.4,"revive":0.4}
	return float(_durations.get(clip,defaults.get(clip,0.2)))

## Observe authoritative counter edges without restarting on duplicate packets.
func observe(snapshot: Dictionary) -> void:
	var run_key: String = "%s:%s" % [snapshot.get("run_seed",0),snapshot.get("run_serial",0)]
	if run_key != _run_key:
		_entries.clear()
		_last_player_hp.clear()
		_run_key = run_key
	var room_key: String = "%s:%s:%s" % [snapshot.get("floor_index",1),snapshot.get("room_layout",{}).get("id",""),snapshot.get("room_layout_revision",0)]
	if room_key != _room_key:
		_entries.clear()
		_room_key = room_key
	var seen: Dictionary = {}
	for id: Variant in snapshot.get("players",{}):
		var key: String = "p"+str(id)
		var player: Dictionary = snapshot.players[id]
		_observe_actor(key,player,true)
		_last_player_hp[key] = float(player.get("hp",0))
		seen[key] = true
	for enemy: Dictionary in snapshot.get("enemies",[]):
		var key: String = "e"+str(enemy.get("id",-1))
		_observe_actor(key,enemy,false)
		seen[key] = true
	for key: String in _entries.keys():
		if not seen.has(key): _entries.erase(key)

func _observe_actor(key: String, entity: Dictionary, player: bool) -> void:
	var hp: float = float(entity.get("hp",1))
	var hits: int = int(entity.get("hurts" if player else "hits",0))
	var shots: int = int(entity.get("shots" if player else "attacks",0))
	var blocks: int = int(entity.get("blocks",0))
	var face: Vector2 = _facing(entity,player)
	var moving: bool = bool(entity.get("moving",false))
	if not _entries.has(key):
		var entry: Dictionary = {"hp":hp,"hits":hits,"shots":shots,"blocks":blocks,"moving":moving,"direction":_direction(face),"face":face,"picked":bool(entity.get("picked",false)),"interacts":int(entity.get("interacts",0)),"event":"","event_start":_time,"event_end":_time,"event_duration":0.0,"death_start":_time,"guarding":false}
		_entries[key] = entry
		var revived: bool = player and float(_last_player_hp.get(key,1.0)) <= 0 and hp > 0
		_event(entry,"revive" if revived else "spawn")
		return
	var entry: Dictionary = _entries[key]
	if hp <= 0 and float(entry.hp) > 0: entry.death_start = _time
	if hp > 0 and float(entry.hp) <= 0:
		_event(entry,"revive")
	elif blocks > int(entry.blocks):
		_event(entry,"guard_block")
	elif hits > int(entry.hits):
		var damage: float = float(entity.get("last_hit_damage",0.0))
		var heavy: bool = damage >= float(entity.get("max_hp",8))*float(_settings.get("heavy_hit_fraction",0.35))
		_event(entry,"heavy_hit" if heavy else _hit_clip(entity,face,player))
	elif player and shots > int(entry.shots):
		var duration: float = minf(_duration("attack_primary"),maxf(0.04,float(entity.get("shot_interval",0.2))*0.85))
		_event(entry,"attack_primary",duration)
	elif int(entity.get("interacts",0)) > int(entry.interacts):
		_event(entry,"interact")
	elif player and bool(entity.get("picked",false)) and not bool(entry.picked):
		_event(entry,"celebrate")
	elif moving != bool(entry.moving) and str(entity.get("attack","")) == "":
		_event(entry,"start_moving" if moving else "stop_moving")
	elif _direction(face) != str(entry.direction) and not moving and str(entity.get("attack","")) == "":
		_event(entry,"turn_left" if Vector2(entry.face).cross(face) < 0 else "turn_right")
	var guarding: bool = str(entity.get("kind","")) == "skeleton_guard" and str(entity.get("attack","")) == "" and float(entity.get("hitstun",0)) <= 0
	if guarding and not bool(entry.guarding) and _time >= float(entry.event_end): _event(entry,"guard_raise")
	entry.merge({"hp":hp,"hits":hits,"shots":shots,"blocks":blocks,"moving":moving,"direction":_direction(face),"face":face,"picked":bool(entity.get("picked",false)),"interacts":int(entity.get("interacts",0)),"guarding":guarding},true)

func _event(entry: Dictionary, clip: String, duration: float = -1.0) -> void:
	entry.event = clip
	entry.event_start = _time
	entry.event_duration = _duration(clip) if duration < 0 else duration
	entry.event_end = _time+float(entry.event_duration)

func _facing(entity: Dictionary, player: bool) -> Vector2:
	var vector: Vector2
	if player: vector = Vector2(float(entity.get("ax",1)),float(entity.get("ay",0)))
	elif not str(entity.get("attack","")).is_empty(): vector = Vector2(float(entity.get("aim_x",1)),float(entity.get("aim_y",0)))
	else: vector = Vector2(float(entity.get("facing_x",entity.get("face",1))),float(entity.get("facing_y",0)))
	return vector.normalized() if vector.is_finite() and vector.length_squared() > 0.001 else Vector2.RIGHT

func _direction(vector: Vector2) -> String:
	if absf(vector.x) > absf(vector.y): return "east" if vector.x >= 0 else "west"
	return "north" if vector.y < 0 else "south"

func _hit_clip(entity: Dictionary, face: Vector2, player: bool) -> String:
	var incoming: Vector2 = Vector2(float(entity.get("hit_dx" if player else "dx",0)),float(entity.get("hit_dy" if player else "dy",0)))
	if incoming.length_squared() < 0.001: return "hit_front"
	var source: Vector2 = -incoming.normalized()
	if source.dot(face) > 0.5: return "hit_front"
	if source.dot(face) < -0.5: return "hit_back"
	return "hit_left" if face.cross(source) < 0 else "hit_right"

func _result(clip: String, direction: String, elapsed: float, loop: bool) -> Dictionary:
	return {"clip":clip,"direction":direction,"elapsed":maxf(0,elapsed),"loop":loop}

## Choose only states supported by actual gameplay; the studio can play all48.
func select(key: String, entity: Dictionary, player: bool) -> Dictionary:
	var entry: Dictionary = _entries.get(key,{"death_start":_time,"event":"","event_end":0.0,"event_start":0.0,"event_duration":1.0})
	var direction: String = _direction(_facing(entity,player))
	var dying: float = float(entity.get("dying_p",-1))
	if float(entity.get("hp",1)) <= 0 or dying >= 0:
		if dying >= 0:
			var clip: String = "death_start" if dying < 0.25 else "death_fall" if dying < 0.8 else "death_settle"
			var progress: float = dying/0.25 if dying < 0.25 else (dying-0.25)/0.55 if dying < 0.8 else (dying-0.8)/0.2
			return _result(clip,direction,progress*_duration(clip),false)
		var elapsed: float = _time-float(entry.death_start)
		if elapsed < _duration("death_start"): return _result("death_start",direction,elapsed,false)
		elapsed -= _duration("death_start")
		if elapsed < _duration("death_fall"): return _result("death_fall",direction,elapsed,false)
		return _result("death_settle",direction,elapsed-_duration("death_fall"),false)
	var statuses: Array = entity.get("statuses",[])
	if "freeze" in statuses: return _result("idle_alert",direction,0,false)
	var event: String = str(entry.event)
	var live_event: bool = _time < float(entry.event_end)
	if live_event and event in ["hit_front","hit_back","hit_left","hit_right","heavy_hit","guard_block","revive"]:
		return _result(event,direction,(_time-float(entry.event_start))*_duration(event)/maxf(0.001,float(entry.event_duration)),false)
	var attack: String = str(entity.get("attack",""))
	if not player and attack in ["windup","active","recovery"]:
		var progress: float = clampf(float(entity.get("attack_p",0)),0,1)
		var kind: String = str(entity.get("attack_kind",""))
		var clip: String = "attack_primary"
		if attack == "windup":
			if kind in ["soul","summon"] or bool(entity.get("boss",false)):
				clip = "charge_start" if progress < 0.2 else "charge_loop" if progress < 0.9 else "charge_release"
				progress = progress/0.2 if progress < 0.2 else (progress-0.2)/0.7 if progress < 0.9 else (progress-0.9)/0.1
			else: clip = "attack_windup"
		elif attack == "active": clip = "charge_release" if kind == "summon" else "attack_secondary" if bool(entity.get("boss",false)) else "attack_primary"
		else: clip = "attack_recover"
		return _result(clip,direction,progress*_duration(clip),false)
	if live_event:
		return _result(event,direction,(_time-float(entry.event_start))*_duration(event)/maxf(0.001,float(entry.event_duration)),false)
	if float(entity.get("hitstun",0)) > 0: return _result("stun_loop",direction,_time,true)
	if bool(entity.get("moving",false)):
		var motion: Vector2 = Vector2(float(entity.get("mx",0)),float(entity.get("my",0)))
		var face: Vector2 = _facing(entity,player)
		var dot: float = motion.normalized().dot(face) if motion.length_squared() > 0.001 else 1.0
		var clip: String = "walk_backward" if dot < -0.45 else "strafe_left" if dot < 0.45 and face.cross(motion) < 0 else "strafe_right" if dot < 0.45 else "walk_forward"
		if motion.length() >= float(_settings.get("run_speed_threshold",160)):
			if clip == "walk_forward": clip = "run_forward"
			elif clip == "walk_backward": clip = "run_backward"
		return _result(clip,direction,_time,true)
	return _result("aim_hold" if player and int(entity.get("shots",0)) > 0 else "idle_breathe" if player else "idle_alert",direction,_time,true)

## Inform the design studio which tracks have a current gameplay binding.
static func bound_actions() -> Array[String]:
	return ["idle_breathe","idle_alert","walk_forward","walk_backward","strafe_left","strafe_right","run_forward","run_backward","start_moving","stop_moving","turn_left","turn_right","aim_hold","attack_windup","attack_primary","attack_recover","attack_secondary","charge_start","charge_loop","charge_release","hit_front","hit_back","hit_left","hit_right","heavy_hit","stun_loop","guard_raise","guard_block","death_start","death_fall","death_settle","spawn","revive","interact","celebrate"]

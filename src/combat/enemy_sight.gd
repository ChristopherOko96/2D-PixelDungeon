extends RefCounted
## Host-only loss of perception. This is not freeze: damage and physical pushes still run.

## Dense steam/smoke refreshes a finite sight-loss timer without granting damage immunity.
static func expose(enemy: Dictionary, seconds: float) -> void:
	if seconds <= 0 or float(enemy.get("hp",0)) <= 0: return
	enemy.sight_blind_s = maxf(float(enemy.get("sight_blind_s",0)),seconds)
	_forget(enemy)

## Advance once per host enemy step, also after the creature leaves the cloud.
static func step(enemy: Dictionary, delta: float) -> void:
	enemy.sight_blind_s = maxf(0,float(enemy.get("sight_blind_s",0))-delta)
	if blocked(enemy): _forget(enemy)

## A blinded creature cannot acquire, track, taunt-focus or initiate a targeted attack.
static func blocked(enemy: Dictionary) -> bool:
	return float(enemy.get("sight_blind_s",0)) > 0

static func _forget(enemy: Dictionary) -> void:
	enemy.aggro = false
	enemy.aggro_target = -1
	enemy.aggro_fresh = false
	enemy.threat = {}
	enemy.threat_target = -1
	enemy.pet_focus = -1
	enemy.erase("pet_taunt")
	enemy.erase("talent_taunt")

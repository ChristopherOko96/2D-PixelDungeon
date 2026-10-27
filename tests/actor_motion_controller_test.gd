extends SceneTree
## Pure state/clock fixtures: no renderer, filesystem state, or network simulation.
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ACTOR_MOTION_FAIL: ",label)

func _initialize() -> void:
	if not FileAccess.file_exists("res://src/actor_motion_controller.gd"):
		check(false,"actor motion controller exists")
		_finish()
		return
	var controller: RefCounted = load("res://src/actor_motion_controller.gd").new()
	controller.configure({"actions":[{"id":"attack_primary","duration":0.3},{"id":"spawn","duration":0.25},{"id":"revive","duration":0.4}]})
	var player: Dictionary = {"hp":8,"max_hp":8,"shots":0,"hurts":0,"blocks":0,"ax":1.0,"ay":0.0,"mx":0.0,"my":0.0,"moving":false,"picked":false,"shot_interval":0.2}
	var snapshot: Dictionary = {"run_seed":7,"run_serial":1,"room_layout":{"id":"a"},"players":{1:player},"enemies":[]}
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "spawn","a newly appearing actor plays a spawn clip")
	controller.advance(1.0)
	player.shots = 1
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "attack_primary","an authoritative shot starts its actual attack clip")
	controller.advance(0.04)
	var before: float = controller.select("p1",player,true).elapsed
	controller.observe(snapshot)
	controller.advance(0.03)
	check(float(controller.select("p1",player,true).elapsed) > before,"duplicate snapshots do not restart a shot clip")
	player.hurts = 1
	player.hit_dx = 1.0
	player.hit_dy = 0.0
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "hit_back","hit direction selects the corresponding body reaction")
	player.blocks = 1
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "guard_block","an acknowledged block overrides generic flesh recoil")
	controller.advance(1.0)
	player.moving = true
	player.mx = 0.0
	player.my = -100.0
	controller.observe(snapshot)
	controller.advance(1.0)
	check(controller.select("p1",player,true).clip == "strafe_left","locomotion distinguishes strafing from forward walking")
	player.ax = 0.0
	player.ay = -1.0
	controller.observe(snapshot)
	controller.advance(1.0)
	check(controller.select("p1",player,true).direction == "north","north uses a real directional track instead of flipping a side sprite")
	player.hp = 0
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "death_start","death interrupts all living actions")
	controller.advance(0.3)
	check(controller.select("p1",player,true).clip == "death_fall","death proceeds to its fall sequence")
	controller.advance(2.0)
	check(controller.select("p1",player,true).clip == "death_settle","a fallen player holds the settled body rather than replaying death")
	snapshot.room_layout = {"id":"b"}
	player.hp = 4
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "revive","a revived player is recognized across a room boundary")
	snapshot.run_serial = 2
	player.shots = 0
	player.hurts = 0
	controller.observe(snapshot)
	check(controller.select("p1",player,true).clip == "spawn","a fresh same-seed run does not inherit the prior revive or attack")
	var enemy: Dictionary = {"id":8,"hp":12,"max_hp":12,"kind":"necromancer","hits":0,"attacks":0,"blocks":0,"attack":"windup","attack_kind":"summon","attack_p":0.7,"aim_x":-1.0,"aim_y":0.0}
	snapshot.enemies = [enemy]
	controller.observe(snapshot)
	check(controller.select("e8",enemy,false).clip == "charge_loop","summoning has a dedicated sustained charge sequence")
	check(controller.select("e8",enemy,false).direction == "west","a locked enemy attack uses its authoritative facing")
	_finish()

func _finish() -> void:
	print("ACTOR_MOTION checked=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

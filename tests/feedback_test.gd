extends SceneTree
## Headless checks for the game-feel layer (src/vfx/feedback.gd): counters fire
## each reaction exactly once, springs overshoot and settle, hitstop freezes,
## rapid hits restart cleanly, and room changes leave nothing behind.

const Feedback = preload("res://src/vfx/feedback.gd")
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FEEDBACK_FAIL: ", description)

func _initialize() -> void:
	var feedback = Feedback.new()
	var enemy := {"id": 7, "x": 400.0, "y": 240.0, "hp": 8, "max_hp": 8, "kind": "chaser", "face": 1.0, "hits": 3, "attacks": 0, "attack": "", "dying_p": -1.0, "dx": 1.0, "dy": 0.0}
	feedback.observe(_snapshot("room-a", [enemy]), 1)
	check(feedback.particles.count() == 0 and feedback.shake == 0.0, "an actor seen for the first time replays no old hits")

	enemy.hits = 4
	feedback.observe(_snapshot("room-a", [enemy]), 1)
	var pose: Dictionary = feedback.pose("e7", enemy, 0.0)
	check(pose.flash > 0.8 and pose.flash_color.r > pose.flash_color.b and pose.scale.x > 1.2 and pose.scale.y < 0.8, "a hit flashes red and squashes the enemy at once")
	check(feedback.particles.count() > 0 and feedback.shake > 0.0, "a hit throws particles and shakes the screen")
	var particles_after_one_hit: int = feedback.particles.count()
	feedback.observe(_snapshot("room-a", [enemy]), 1)
	check(particles_after_one_hit == feedback.particles.count(), "the same snapshot never fires a hit twice")

	# Follow-through: the spring overshoots past rest before it settles.
	var crossed := false
	for step in range(60):
		feedback.update(1.0 / 60.0)
		if feedback.pose("e7", enemy, 0.0).scale.x < 0.999: crossed = true
	check(crossed, "squash overshoots past rest (follow-through)")
	for step in range(120): feedback.update(1.0 / 60.0)
	pose = feedback.pose("e7", enemy, 0.0)
	check(absf(pose.scale.x - 1.0) < 0.06 and pose.flash == 0.0, "the deformation and flash settle back")

	# Rapid hits restart the kick instead of stacking deformation.
	for hit in range(5):
		enemy.hits = int(enemy.hits) + 1
		feedback.observe(_snapshot("room-a", [enemy]), 1)
		feedback.update(0.01)
	pose = feedback.pose("e7", enemy, 0.0)
	check(pose.scale.x < 1.5 and pose.scale.y > 0.5, "five quick hits never stack into an extreme deformation")

	enemy.attack = "windup"
	enemy.attack_p = 0.9
	for step in range(120): feedback.update(1.0 / 60.0)
	pose = feedback.pose("e7", enemy, 0.0)
	check(pose.scale.y > 1.12 and pose.scale.x < 0.9 and pose.lean < 0.0, "windup stretches tall and leans back (anticipation)")
	enemy.attack = "active"
	enemy.attacks = 1
	feedback.observe(_snapshot("room-a", [enemy]), 1)
	pose = feedback.pose("e7", enemy, 0.0)
	check(pose.scale.x > 1.15, "the active frame snaps into a forward squash")

	enemy.attack = ""
	enemy.hp = 0
	enemy.dying_p = 0.0
	var shake_before: float = feedback.shake
	feedback.observe(_snapshot("room-a", [enemy]), 1)
	check(feedback.hitstop > 0.0 and feedback.shake > shake_before, "the killing blow adds hitstop and screen shake")
	var death_pose: Dictionary = feedback.pose("e7", enemy, 0.0)
	check(death_pose.flash > 0.95 and death_pose.flash_color == Color.WHITE, "the killing blow flashes full white")

	var boss := {"id": 9, "x": 600.0, "y": 240.0, "hp": 70, "max_hp": 70, "boss": true, "kind": "boss", "face": -1.0, "hits": 0, "attacks": 0, "attack": "", "dying_p": -1.0, "dx": 1.0, "dy": 0.0}
	feedback.observe(_snapshot("room-a", [enemy, boss]), 1)
	boss.hits = 1
	feedback.observe(_snapshot("room-a", [enemy, boss]), 1)
	check(feedback.pose("e9", boss, 0.0).flash <= 0.55, "a boss hit flashes at most half strength, so a stream of shots stays readable")
	var frozen: Dictionary = feedback.pose("e7", enemy, 0.0)
	feedback.update(0.02)
	check(feedback.pose("e7", enemy, 0.0).scale == frozen.scale, "hitstop freezes the deformation")
	enemy.dying_p = 1.0
	check(feedback.pose("e7", enemy, 0.0).alpha < 0.05, "the death animation fades the body out")
	check(feedback.pose("e7", enemy, 0.0).scale.y < 0.4, "the body flattens while dying")
	for step in range(30): feedback.update(1.0 / 60.0)
	feedback.observe(_snapshot("room-a", []), 1)
	check(feedback.particles.count() > 0, "particles outlive the removed enemy")

	feedback.observe(_snapshot("room-b", []), 1)
	check(feedback.particles.count() == 0, "a room change clears particles and stains")

	var player := {"x": 300.0, "y": 240.0, "hp": 8, "max_hp": 8, "shots": 2, "hurts": 0, "ax": 1.0, "ay": 0.0}
	feedback.observe({"room_layout": {"id": "room-b"}, "enemies": [], "players": {1: player}}, 1)
	player.hurts = 1
	feedback.shake = 0.0
	feedback.observe({"room_layout": {"id": "room-b"}, "enemies": [], "players": {1: player}}, 1)
	pose = feedback.pose("p1", player, 0.0)
	check(pose.flash > 0.9 and pose.flash_color.r > pose.flash_color.g and feedback.shake >= 0.5, "a hurt local player flashes red and shakes the screen")

	# A restarted run recreates players with counters at 0 in the same room id.
	player.hurts = 0
	player.shots = 0
	feedback.observe({"room_layout": {"id": "room-b"}, "enemies": [], "players": {1: player}}, 1)
	for step in range(60): feedback.update(1.0 / 60.0)
	feedback.shake = 0.0
	player.hurts = 1
	feedback.observe({"room_layout": {"id": "room-b"}, "enemies": [], "players": {1: player}}, 1)
	check(feedback.shake > 0.0 and feedback.pose("p1", player, 0.0).flash > 0.9, "after a run restart the first hit reacts again")

	print("FEEDBACK checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _snapshot(room_id: String, enemies: Array) -> Dictionary:
	var copies: Array = []
	for enemy in enemies: copies.append(enemy.duplicate())
	return {"room_layout": {"id": room_id}, "enemies": copies, "players": {}}

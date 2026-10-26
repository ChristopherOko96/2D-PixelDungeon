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

	# Boss moves: each move has its own anticipation pose.
	var big := {"id": 20, "x": 450.0, "y": 240.0, "hp": 50, "max_hp": 94, "boss": true, "kind": "boss", "face": 1.0, "hits": 0, "attacks": 0, "impacts": 0, "attack": "windup", "attack_p": 0.9, "dying_p": -1.0, "move": "slam", "ox": 460.0, "oy": 218.0, "bx": 40.0, "by": 218.0}
	var room_c := {"room_layout": {"id": "room-c"}, "enemies": [big], "players": {}}
	feedback.observe(room_c, 1)
	var squat: Dictionary = feedback.pose("e20", big, 0.0)
	big.move = "volley"
	var swell: Dictionary = feedback.pose("e20", big, 0.0)
	big.move = "charge"
	var rear: Dictionary = feedback.pose("e20", big, 0.0)
	check(squat.scale.y < 0.75 and swell.scale.x > 1.1 and swell.scale.y > 1.1 and rear.lean < -0.2, "jump squats, volley swells, charge rears back: anticipation differs per move")
	big.move = "slam"
	big.attack = "active"
	big.attack_p = 0.5
	check(feedback.pose("e20", big, 0.0).offset.y < -120.0, "the jumping boss is drawn high in the air")
	big.attack = "recovery"
	big.impacts = 1
	feedback.shake = 0.0
	feedback.hitstop = 0.0
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [big.duplicate()], "players": {}}, 1)
	check(feedback.shake >= 0.7 and feedback.hitstop > 0.0, "a landing shakes the screen hard and adds hitstop")
	big.move = "beam"
	big.attack = "active"
	big.attack_p = 0.3
	feedback.hitstop = 0.0
	feedback.shake = 0.0
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [big.duplicate()], "players": {}}, 1)
	var sparks_before: int = feedback.particles.count()
	for step in range(10): feedback.update(1.0 / 60.0)
	check(feedback.shake > 0.25 and feedback.particles.count() > sparks_before, "the active beam keeps the screen rumbling and throws sparks where it hits")
	big.move = "charge"
	big.attack = "active"
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [big.duplicate()], "players": {}}, 1)
	for step in range(10): feedback.update(1.0 / 60.0)
	check(not feedback.ghosts.is_empty(), "a charging boss leaves an afterimage trail")

	# Turning: a face change narrows the body, then it widens facing the new way.
	var turner := {"id": 30, "x": 300.0, "y": 240.0, "hp": 5, "max_hp": 5, "kind": "imp", "face": 1.0, "hits": 0, "attacks": 0, "attack": "", "dying_p": -1.0}
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [turner.duplicate()], "players": {}}, 1)
	turner.face = -1.0
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [turner.duplicate()], "players": {}}, 1)
	var narrow: float = feedback.pose("e30", turner, 0.0).scale.x
	for step in range(20): feedback.update(1.0 / 60.0)
	check(narrow < 0.4 and feedback.pose("e30", turner, 0.0).scale.x > 0.9, "turning around narrows the sprite and widens it again")

	# Orbs and level-ups.
	var hero := {"x": 300.0, "y": 240.0, "hp": 6, "max_hp": 8, "shots": 0, "hurts": 0, "level_ups": 0, "pickups": 0}
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [], "players": {1: hero.duplicate()}, "orbs": [{"id": 5, "x": 310.0, "y": 240.0, "v": 3}]}, 1)
	feedback.particles.clear()
	hero.pickups = 1
	hero.level_ups = 1
	hero.hp = 7
	feedback.observe({"room_layout": {"id": "room-c"}, "enemies": [], "players": {1: hero.duplicate()}, "orbs": []}, 1)
	check(feedback.particles.count() > 40, "collecting an orb and levelling up burst with particles")
	check(feedback.pose("p1", hero, 0.0).level_up > 0.9, "a level-up starts the light pillar")
	for step in range(90): feedback.update(1.0 / 60.0)
	check(feedback.pose("p1", hero, 0.0).level_up == 0.0, "the level-up effect ends cleanly")

	print("FEEDBACK checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _snapshot(room_id: String, enemies: Array) -> Dictionary:
	var copies: Array = []
	for enemy in enemies: copies.append(enemy.duplicate())
	return {"room_layout": {"id": room_id}, "enemies": copies, "players": {}}

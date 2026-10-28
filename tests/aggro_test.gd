extends SceneTree
## Headless checks for the aggro rules (src/combat/aggro.gd): enemies notice
## players only within range and sight, stay locked on their target, call
## their pack, and attack only within reach.

const Aggro = preload("res://src/combat/aggro.gd")
const CONFIG := {"range": 230.0, "call_range": 160.0, "attack_range": 360.0}
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("AGGRO_FAIL: ", description)

func _initialize() -> void:
	var clear_sight := func(_from: Vector2, _to: Vector2) -> bool: return true
	var walled := func(_from: Vector2, _to: Vector2) -> bool: return false

	# Arrange: one enemy, two heroes; 1 is far, 2 is out of range.
	var enemy := _enemy(Vector2(500, 240))
	var players := {1: _player(Vector2(100, 240)), 2: _player(Vector2(900, 240))}
	check(Aggro.pick_target(enemy, players, clear_sight, CONFIG) == -1 and not enemy.get("aggro", false), "an enemy ignores heroes beyond its notice range")

	players[1].pos = Vector2(300, 240)
	check(Aggro.pick_target(enemy, players, walled, CONFIG) == -1, "a hero behind cover is not noticed")
	check(Aggro.pick_target(enemy, players, clear_sight, CONFIG) == 1 and enemy.aggro and enemy.aggro_target == 1, "a hero in range and sight is noticed and locked")

	players[2].pos = Vector2(520, 240)
	check(Aggro.pick_target(enemy, players, clear_sight, CONFIG) == 1, "a locked enemy stays on its target although another hero is closer")
	players[1].pos = Vector2(-2000, 240)
	check(Aggro.pick_target(enemy, players, walled, CONFIG) == 1, "a locked enemy keeps chasing out of range and sight")

	players[1].hp = 0
	check(Aggro.pick_target(enemy, players, walled, CONFIG) == 2 and enemy.aggro_target == 2, "when its target falls it hunts the nearest living hero")
	players[2].hp = 0
	check(Aggro.pick_target(enemy, players, walled, CONFIG) == -1, "with nobody alive there is no target")

	# Hurting an enemy locks it onto the attacker.
	var hurt := _enemy(Vector2(500, 240))
	Aggro.lock(hurt, 2)
	check(hurt.aggro and hurt.aggro_target == 2, "a hit locks the enemy onto the attacker")

	# Pack call: idle allies close by join, far ones and the dead do not.
	var leader := _enemy(Vector2(400, 240))
	var near := _enemy(Vector2(500, 240))
	var far := _enemy(Vector2(800, 240))
	var dead := _enemy(Vector2(420, 240))
	dead.hp = 0
	Aggro.lock(leader, 1)
	var pack: Array = [leader, near, far, dead]
	check(Aggro.alert_pack(leader, pack, CONFIG) == 1 and near.aggro and near.aggro_target == 1 and not far.get("aggro", false) and not dead.get("aggro", false), "a newly angry enemy calls idle allies within call range")
	check(Aggro.alert_pack(leader, pack, CONFIG) == 0, "the pack is called only once per lock")

	# Attack reach.
	check(Aggro.in_attack_range(_enemy(Vector2.ZERO), {}, 300.0, CONFIG) and not Aggro.in_attack_range(_enemy(Vector2.ZERO), {}, 400.0, CONFIG), "without its own range an enemy attacks only within attack_range")
	check(not Aggro.in_attack_range(_enemy(Vector2.ZERO), {"range": 200.0}, 300.0, CONFIG), "an attack's own range wins")
	var boss := _enemy(Vector2.ZERO)
	boss.boss = true
	check(Aggro.in_attack_range(boss, {}, 900.0, CONFIG), "a boss fights its whole arena")
	var far_players := {1: _player(Vector2(2000, 240)), 2: _player(Vector2(100, 0))}
	check(Aggro.pick_target(boss, far_players, walled, CONFIG) == 2, "a boss is always angry and faces the nearest hero anywhere")
	Aggro.lock(boss, 1)
	check(Aggro.pick_target(boss, far_players, walled, CONFIG) == 2, "a boss is never locked onto one hero")

	print("AGGRO checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _enemy(pos: Vector2) -> Dictionary:
	return {"pos": pos, "hp": 5, "boss": false}

func _player(pos: Vector2) -> Dictionary:
	return {"pos": pos, "hp": 4}

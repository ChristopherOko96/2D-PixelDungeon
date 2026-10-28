extends SceneTree
## Enemy hordes (src/dungeon/hordes.gd, assets/data/combat_hordes.json): a room
## keeps sending waves until its quota is spent, never more than the floor's
## alive cap at once and never right next to a hero; doors work during the
## fight; leaving returns the living to the quota; stairs on boss floors open
## only after the boss; kills give scaled EXP.

const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []
var game

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HORDES_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _living() -> int:
	return game.enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.hp) > 0.0).size()

func _step(seconds: float) -> void:
	for i in range(int(seconds * 30.0)):
		game.hordes.step(1.0 / 30.0)

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	check(game.hordes.enabled, "hordes are on by default")

	# Floor 1: quota 25 per room, 15 alive at most.
	var state: Dictionary = game.hordes.rooms[str(game.current_layout.id)]
	var opening := _living()
	check(int(state.total) == 25 and int(state.left) == 25 - opening, "floor 1 room: a quota of 25 including the opening group (%d)" % opening)
	check(game.hordes.alive_cap() == 15, "floor 1: at most 15 alive at once")
	_step(20.0)
	check(_living() <= 15 and _living() > opening, "waves fill the room up to the cap (%d alive)" % _living())
	var hero: Dictionary = game.players[1]
	var too_close: Array = game.enemies.filter(func(enemy: Dictionary) -> bool: return bool(enemy.get("wave", false)) and Vector2(enemy.pos).distance_to(hero.pos) < 279.0)
	check(too_close.is_empty(), "waves never spawn next to a hero")
	# Killing everything does not end the room while the quota lasts.
	game.enemies.clear()
	game._check_room_end()
	check(game.phase == "combat" and game.hordes.pending(), "an empty room with quota left keeps fighting")
	# Spend the whole quota.
	for round_index in range(40):
		_step(3.0)
		game.enemies.clear()
		if not game.hordes.pending(): break
	game._check_room_end()
	check(game.phase == "explore", "once the quota is spent and all are dead, the room is quiet")
	check(int(state.spawned) == int(state.total), "exactly the quota was sent (%d of %d)" % [int(state.spawned), int(state.total)])

	# Doors work mid-fight; leaving returns the living to the quota.
	game.room = 2
	game._spawn_room(1)
	var second: Dictionary = game.hordes.rooms[str(game.current_layout.id)]
	_step(3.0)
	var alive_before := _living()
	var left_before := int(second.left)
	var gate: Dictionary = {}
	for exit: Dictionary in game.current_layout.exits:
		if bool(exit.get("forward", false)): gate = exit
	hero.pos = game._exit_center(gate)
	game.action_times.clear()
	game._use_exit(1)
	check(not game._transition_state.is_empty(), "a door can be used while the horde is still coming")
	game._transition_state.clear()
	game.room = 3
	game._spawn_room(2)
	check(int(second.left) == left_before + alive_before, "leaving returns the living horde to the room's quota")
	game.room = 2
	game._spawn_room(3)
	check(_living() == 0 and game.phase == "combat", "coming back: no opening group again, the horde returns in waves")

	# Floor 10: larger hordes.
	game.floor_index = 10
	check(game.hordes.alive_cap() == 25, "floor 10: 25 alive at once")
	game.floor_index = 1

	# Stairs: open on strong-group floors, barred on boss floors until the boss falls.
	check(game.stairs_open(), "floor 1 (strong group): the stairs are open")
	game.floor_index = 3
	game.floor_boss_down = false
	check(not game.stairs_open(), "floor 3: the stairs stay barred while the Moderkoloss lives")
	var boss: Dictionary = game._create_enemy("moderkoloss", hero.pos + Vector2(200, 0))
	boss.miniboss = true
	game.enemies.append(boss)
	game._damage_enemy(boss, 99999.0, Vector2.RIGHT, 1)
	check(game.stairs_open(), "the mini-boss's death opens the stairs")

	# EXP: a quarter per kill with hordes on.
	var skeleton: Dictionary = game._create_enemy("skeleton", hero.pos)
	check(game.team_progress.exp_value(skeleton) <= 3, "hordes give a quarter of the EXP per kill")
	print("HORDES checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)

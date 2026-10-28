extends SceneTree
## Captures the Frostgruft boss fights from the real windowed game: Hrimgar on
## each of his three bars mid-attack, his eternal frost with safe circles, and
## the Frostleiche (floor 6) in its second phase. The hero is kept invulnerable.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_bosses.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const BossKit = preload("res://src/hell/boss_kit.gd")

var _out := "res://production/qa/evidence/frost-floors"
var _game: Node
var _boss: Dictionary


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			# invulnerable, so no red hit flash covers the fight
			_game.state.inv = 99.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String) -> void:
	# the invulnerable hero blinks on odd 1/20 s steps: start an even step, render one frame
	_game.state.t = floorf(_game.state.t * 10.0) / 10.0
	await _wait(1)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d phase=%d hp=%.0f" % [path, image.save_png(path), int(_boss.get("phase", 0)), float(_boss.get("hp", 0.0))])


func _fight(floor_n: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = FrostScene.instantiate()
	_game.start_floor = floor_n
	_game.class_id = "swordsman"
	root.add_child(_game)
	await _wait(5)
	var hall: Dictionary = {}
	for r: Dictionary in _game.W.rooms:
		if r.type == "boss":
			hall = r
	_game.player.x = (hall.bx + hall.bw / 2.0) * 96.0
	_game.player.y = (hall.by + hall.bh / 2.0 + 3.2) * 96.0
	_game.camera.position = Vector2(_game.player.x, _game.player.y - 150.0)
	_game.state.room = hall.index
	_game._start_fight(hall)
	for m: Dictionary in _game.mobs:
		if m.kind == "boss":
			_boss = m
	# only the guardian: its own summons come during the fight
	_game.mobs = [_boss]


## Plays until the boss is busy with (or just fired) one of the given attacks.
func _until_attack(kinds: Array, limit := 400) -> void:
	for i in range(limit):
		await _wait(1)
		var b: Dictionary = _boss.get("busy", {})
		if str(b.get("do", "")) in kinds and float(b.get("e", 0.0)) > 0.25:
			return
		if "zones" in kinds and not _game.zones.is_empty():
			return
		if "shots" in kinds and _game.eshots.size() > 8:
			return


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _fight(10)
	await _until_attack(["stomp", "zones"])
	await _shot("40-spiel-hrimgar-balken1.png")
	_boss.hp = 0.0
	await _wait(140)
	await _until_attack(["breath"])
	await _shot("41-spiel-hrimgar-balken2.png")
	_boss.hp = 0.0
	await _wait(140)
	await _until_attack(["spiral"])
	await _shot("42-spiel-hrimgar-balken3.png")
	_boss.busy = {}
	_boss.hp = float(_boss.max) * 0.1
	await _wait(30)
	await _shot("43-spiel-hrimgar-ewiger-frost.png")
	await _fight(6)
	_boss.hp = 0.0
	await _wait(120)
	await _until_attack(["charge", "zones"])
	await _shot("44-spiel-frostleiche-phase2.png")
	quit()

extends SceneTree
## Captures the Frostgruft HUD and relics from the real windowed game: hearts,
## mission list and banner on arrival, the status sheet, the level-up cards,
## the gravity hammer (smash, field, rock wave, meteor) and the gravity staff
## (stone golem, rock throw). The hero is kept invulnerable on a visible frame.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_hud.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")

var _out := "res://production/qa/evidence/frost-floors"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 99.0
			_game.state.hp = maxi(_game.state.hp, 3)
		await process_frame


func _shot(name: String) -> void:
	_game.state.t = floorf(_game.state.t * 10.0) / 10.0
	await _wait(1)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _start(class_id: String, floor_n: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = FrostScene.instantiate()
	_game.class_id = class_id
	_game.start_floor = floor_n
	root.add_child(_game)
	await _wait(5)


func _level_to(n: int) -> void:
	while int(_game.state.level) < n:
		HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))
	_game.state.offer = []
	_game.state.cards_due = 0


## Stands the hero on a floor cell in the middle of a big combat room, so its fight starts.
func _fight_room() -> void:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 20:
			var mid := Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0)
			var best: Vector2i = r.cells[0]
			for c: Vector2i in r.cells:
				if _game.W.grid[c.y * _game.W.cols + c.x] == 1 and Vector2(c).distance_to(mid) < Vector2(best).distance_to(mid):
					best = c
			_game.player.x = (best.x + 0.5) * 96.0
			_game.player.y = (best.y + 0.8) * 96.0
			_game.camera.position = Vector2(_game.player.x, _game.player.y)
			_game.state.room = r.index
			if not r.fight and not r.cleared:
				_game._start_fight(r)
			return


func _foe() -> Vector2:
	for m: Dictionary in _game.mobs:
		if m.spawn <= 0.0 and m.kind != "boss":
			return m.p
	return Vector2(_game.player.x + 300.0, _game.player.y)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _start("archer", 2)
	_game.state.hp = 9
	await _wait(25)
	await _shot("60-spiel-hud-ankunft.png")
	_game.state.status = true
	await _wait(5)
	await _shot("61-spiel-statusfenster.png")
	_game.state.status = false
	HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, 1))
	await _wait(12)
	await _shot("62-spiel-levelup-karten.png")
	_game.state.offer = []
	# the gravity hammer
	await _start("swordsman", 3)
	_game.state.relic = "gravity_hammer"
	_game.state.relic_on = true
	_game._relic_texture()
	_level_to(10)
	_fight_room()
	await _wait(130)
	var foe := _foe()
	_game.aim_at = foe - Vector2(0, 40)
	RelicKit.press(_game, "2")
	_game._fire(foe - Vector2(_game.player.x, _game.player.y - 40))
	await _wait(6)
	await _shot("63-spiel-hammer-schlag-feld.png")
	RelicKit.press(_game, "3")
	await _wait(8)
	await _shot("64-spiel-hammer-felsenwelle.png")
	RelicKit.press(_game, "4")
	await _wait(30)
	await _shot("65-spiel-hammer-meteor.png")
	# the gravity staff
	await _start("mage", 3)
	_game.state.relic = "gravity_staff"
	_game.state.relic_on = true
	_game._relic_texture()
	_level_to(10)
	_fight_room()
	await _wait(130)
	_game.aim_at = _foe() - Vector2(0, 40)
	RelicKit.press(_game, "4")
	RelicKit.press(_game, "3")
	await _wait(50)
	await _shot("66-spiel-stab-golem-steinwurf.png")
	quit()

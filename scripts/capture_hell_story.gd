extends SceneTree
## Captures evidence of Story 3 (Hell-Dungeon with the hero systems) from the
## real windowed game: the story choice with Story 3 and Story 4 (coming soon),
## the hero choice, the hell start room with the chosen class and the styled HUD,
## a level-up, a class skill per class against hell monsters, and Ignaroth on
## floor 3 fought by the swordsman. The hero is kept invulnerable.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_story.gd -- <output_dir>
const MainScene = preload("res://src/main.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")

var _out := "res://production/qa/evidence/hell-story"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and "state" in _game and not _game.state.is_empty():
			_game.state.inv = 5.0
		await process_frame


func _shot(name: String) -> void:
	if _game != null and is_instance_valid(_game) and "state" in _game and not _game.state.is_empty():
		_game.state.inv = 0.0
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _start(class_id: String, floor_n: int, boss := false) -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		await process_frame
	_game = HellScene.instantiate()
	_game.class_id = class_id
	_game.start_floor = floor_n
	_game.start_at_boss = boss
	root.add_child(_game)
	current_scene = _game
	await _wait(5)


func _fight_room() -> void:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= 12 and r.mobs >= 3:
			var mid := Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
			var best := INF
			for c: Vector2i in r.cells:
				var p := Vector2((c.x + 0.5) * 96.0, (c.y + 0.8) * 96.0)
				if _game._cell(c.x, c.y) == 1 and p.distance_to(mid) < best and _game._fully_inside(r, p.x, p.y) \
						and not _game.box_blocked(_game._player_box(p.x, p.y).grow(40)):
					best = p.distance_to(mid)
					_game.player.x = p.x
					_game.player.y = p.y
			_game.camera.position = Vector2(_game.player.x, _game.player.y)
			return


func _level_to(n: int) -> void:
	while int(_game.state.level) < n:
		HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))


## Takes the first offered card until none is left, so fights are not covered.
func _pick_cards() -> void:
	for i in range(30):
		if (_game.state.get("offer", []) as Array).is_empty():
			return
		CardKit.choose(_game, 0)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# the story choice and the hero choice from the real title screen
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	for i in range(30):
		await process_frame
	var menu = main.main_menu
	menu._open_stories()
	await _shot("01-story-auswahl.png")
	menu._choose_story("hell_dungeon")
	await _shot("02-heldenwahl-story3.png")
	menu._choose_class("mage")
	for i in range(60):
		await process_frame
	_game = current_scene
	print("STORY3 scene=%s class=%s hero=%s" % [_game.scene_file_path, _game.class_id, _game.hero.get("name", "")])
	await _wait(60)
	await _shot("03-hoelle-start-magier.png")
	# a level-up
	_level_to(2)
	await _wait(30)
	_level_to(3)
	await _wait(12)
	await _shot("04-hoelle-levelup.png")
	# one class skill per class against the hell monsters
	for spec: Array in [["swordsman", "1", "05-hoelle-skill-schwert.png"], ["archer", "1", "06-hoelle-skill-bogen.png"], ["mage", "2", "07-hoelle-skill-magier.png"]]:
		await _start(spec[0], 5)
		_level_to(10)
		_pick_cards()
		await _wait(30)
		_fight_room()
		await _wait(110)
		var target := Vector2(_game.player.x + 300.0, _game.player.y - 40.0)
		for m: Dictionary in _game.mobs:
			if m.spawn <= 0.0:
				target = m.p - Vector2(0, m.cy)
				break
		_game.aim_at = target
		HeroKit.press(_game, spec[1])
		await _wait(8)
		await _shot(spec[2])
		HeroKit.release(_game, spec[1])
	# Ignaroth against the swordsman
	await _start("swordsman", 3, true)
	_level_to(6)
	_pick_cards()
	for i in range(400):
		await _wait(1)
		var b: Dictionary = {}
		for m: Dictionary in _game.mobs:
			if m.boss:
				b = m
		if not b.is_empty() and b.intro == null:
			_game.player.x = b.p.x - 260.0
			_game.player.y = b.p.y + 20.0
			break
	await _wait(60)
	await _shot("08-hoelle-ignaroth-schwertkaempfer.png")
	print("HELL_STORY_CAPTURE done")
	quit(0)

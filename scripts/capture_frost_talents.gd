extends SceneTree
## Captures the talents and relic drops from the real windowed game: the
## TALENTE screen (with a few bought ranks), the floor-end screen with its soul
## crystals, the guardian's relic chest, the shadow dagger's smoke and blade
## rain, and the meteor rain master skill. Uses its own save file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_talents.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const MainMenu = preload("res://src/main_menu.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const SAVE := "user://capture_talents.cfg"

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
			_game.state.hp = maxi(_game.state.hp, 4)
		await process_frame


func _shot(name: String) -> void:
	if _game != null:
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
	_game.meta_path = SAVE
	root.add_child(_game)
	await _wait(5)


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
			_game._start_fight(r)
			return


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.crystals = 46
	store.classes.mage.ranks = {"f_core": 4, "f_spark": 2, "f_twin": 1, "f_wild": 1}
	store.classes.archer.ranks = {"s_steady": 4, "s_fleet": 4, "s_wide": 2, "s_quick": 1, "s_heavy": 2, "s_breaker": 1, "s_rain": 1}
	MetaStore.save_store(store, SAVE)
	var menu: Control = MainMenu.new()
	menu.talent_path = SAVE
	root.add_child(menu)
	await process_frame
	menu._open_talents()
	await process_frame
	await process_frame
	await _shot("70-menue-talente-magier.png")
	menu._talent_class = "archer"
	menu._build_talents()
	await process_frame
	await process_frame
	await _shot("71-menue-talente-bogen.png")
	menu.queue_free()
	await process_frame
	# floor end with crystals
	await _start("mage", 3)
	_game.state.boss_dead = true
	_game._bank_crystals()
	_game.state.won = true
	await _wait(10)
	await _shot("72-spiel-etagenende-kristalle.png")
	# the guardian's relic chest
	await _start("archer", 4)
	_game.state.relic_floor = 4
	_game.state.relic_item = "shadow_dagger"
	for r: Dictionary in _game.W.rooms:
		if r.type == "boss":
			var at := Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
			_game.player.x = at.x
			_game.player.y = at.y + 200.0
			_game.camera.position = at
			_game.state.room = r.index
			_game._clear_room(r, at)
	await _wait(40)
	await _shot("73-spiel-reliktruhe-boss.png")
	# the shadow dagger in a fight
	_game.state.relic = "shadow_dagger"
	_game.state.relic_on = true
	_game._relic_texture()
	while int(_game.state.level) < 10:
		HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))
	_game.state.offer = []
	_game.state.cards_due = 0
	_game.load_floor(3, true)
	await _wait(5)
	_fight_room()
	await _wait(120)
	var foe := Vector2(_game.player.x + 300.0, _game.player.y)
	for m: Dictionary in _game.mobs:
		if m.spawn <= 0.0:
			foe = m.p
			break
	_game.aim_at = foe
	RelicKit.press(_game, "3")
	RelicKit.press(_game, "4")
	RelicKit.press(_game, "2")
	await _wait(25)
	await _shot("74-spiel-schattendolch.png")
	# the meteor rain master skill
	await _start("mage", 3)
	_fight_room()
	await _wait(120)
	_game.state.talent.master = "meteor_rain"
	_game.aim_at = Vector2(_game.player.x + 260.0, _game.player.y)
	HeroKit.master_press(_game)
	await _wait(70)
	await _shot("75-spiel-meisterfaehigkeit-meteorschauer.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()

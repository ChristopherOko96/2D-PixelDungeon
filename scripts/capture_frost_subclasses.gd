extends SceneTree
## Captures the six further subclasses from the real windowed game: the TALENTE
## screen with a bought subclass, then each subclass in a fight with two of its
## skills and a master skill running. Uses its own save file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_subclasses.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const MainMenu = preload("res://src/main_menu.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const SubKit = preload("res://src/hell/sub_kit.gd")
const SAVE := "user://capture_subclasses.cfg"
## class, subclass, master node, skill keys pressed before the master, file name.
const SHOTS := [
	["mage", "frost", "fr_giant", ["2", "1"], "77-spiel-subklasse-frostmagier.png"],
	["mage", "necro", "ne_colossus", ["1", "2"], "78-spiel-subklasse-nekromant.png"],
	["swordsman", "tank", "ta_fortress", ["1", "2"], "79-spiel-subklasse-tankkrieger.png"],
	["swordsman", "axe", "ax_beast", ["1", "3"], "80-spiel-subklasse-axtkrieger.png"],
	["archer", "shadow", "sh_clones", ["4", "2"], "81-spiel-subklasse-schattenlaeufer.png"],
	["archer", "beast", "be_bear", ["1", "3"], "82-spiel-subklasse-tierbaendiger.png"],
]

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
	store.crystals = 120
	MetaStore.choose_sub(d, store, "mage", "frost")
	store.classes.mage.ranks = {"fr_cold": 4, "fr_focus": 2, "fr_thick": 1}
	MetaStore.save_store(store, SAVE)
	var menu: Control = MainMenu.new()
	menu.talent_path = SAVE
	root.add_child(menu)
	await process_frame
	menu._open_talents()
	await process_frame
	await process_frame
	await _shot("76-menue-talente-frostmagier.png")
	menu.queue_free()
	await process_frame
	for spec: Array in SHOTS:
		store = MetaStore.fresh(d)
		store.crystals = 999
		MetaStore.choose_sub(d, store, spec[0], spec[1])
		store.classes[spec[0]].ranks = {spec[2]: 1}
		MetaStore.save_store(store, SAVE)
		if _game != null:
			_game.queue_free()
			await process_frame
		_game = FrostScene.instantiate()
		_game.class_id = spec[0]
		_game.start_floor = 3
		_game.meta_path = SAVE
		root.add_child(_game)
		await _wait(5)
		_game.state.level = 10
		_fight_room()
		await _wait(110)
		var foe := Vector2(_game.player.x + 260.0, _game.player.y)
		for m: Dictionary in _game.mobs:
			if m.spawn <= 0.0:
				foe = m.p - Vector2(0, m.cy)
				break
		_game.aim_at = foe
		_game.player.aim = (foe - Vector2(_game.player.x, _game.player.y - 40)).normalized()
		for key: String in spec[3]:
			SubKit.press(_game, key)
		SubKit.master(_game)
		_game._fire((foe - Vector2(_game.player.x, _game.player.y - 40)).normalized())
		await _wait(50)
		await _shot(spec[4])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()

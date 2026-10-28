extends SceneTree
## Captures Story 1's combat system in the Frostgruft from the real windowed
## game: a fight with hit chips, stains and shot streaks; a guardian's hail
## warning and frost breath; the hero's conditions; loot on the floor; the bag.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_combat.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const FrostItems = preload("res://src/hell/frost_items.gd")
const FrostBag = preload("res://src/hell/frost_bag.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const SAVE := "user://capture_combat.cfg"

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
			_game.state.hp = maxi(_game.state.hp, 6)
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


func _foe() -> Dictionary:
	for m: Dictionary in _game.mobs:
		if m.spawn <= 0.0:
			return m
	return {}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# a fight: the archer shoots, chips fly, a kill stains the floor
	await _start("archer", 2)
	_fight_room()
	await _wait(90)
	for i in range(40):
		var m := _foe()
		if not m.is_empty():
			_game.state.cool = 0.0
			_game._fire((((m.p as Vector2) - Vector2(0, m.cy)) - Vector2(_game.player.x, _game.player.y - 40)).normalized())
		await _wait(2)
	await _shot("83-spiel-kampf-trefferfeedback.png")
	# a guardian's hail and a frost breath warning, the hero slowed and poisoned
	_game.mobs.clear()
	_game._spawn_mob(_game.state.room, Vector2(_game.player.x + 330.0, _game.player.y - 40.0), "ice_zombie")
	var b: Dictionary = _game.mobs[_game.mobs.size() - 1]
	b.kind = "boss"
	b.spawn = 0.0
	b.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	FrostMoves._begin(_game, b, {"move": "hail"})
	_game._spawn_mob(_game.state.room, Vector2(_game.player.x - 200.0, _game.player.y + 40.0), "ice_zombie")
	var z: Dictionary = _game.mobs[_game.mobs.size() - 1]
	z.spawn = 0.0
	z.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	FrostMoves._begin(_game, z, {"move": "frost_breath"})
	HeroFx.apply(_game, "slow", 9.0, 0.5)
	HeroFx.apply(_game, "poison", 9.0, 1.0)
	await _wait(28)
	await _shot("84-spiel-boss-moves-warnung.png")
	# loot on the floor, then the bag with weapons, potions and a crystal
	_game.mobs.clear()
	_game.state.mzones = []
	var at := Vector2(_game.player.x + 200.0, _game.player.y)
	FrostItems.drop_loot(_game, [FrostItems.make_weapon("frost_bow", false, "night"), FrostItems.make_stack("potion", "healing"), FrostItems.make_stack("crystal")], at)
	await _wait(20)
	await _shot("85-spiel-beute-am-boden.png")
	_game.state.bag.bag = [FrostItems.make_weapon("sun_bow", true, ""), FrostItems.make_weapon("void_bow", false, "leaden"),
		FrostItems.make_stack("potion", "healing", 2), FrostItems.make_stack("potion", "ice"), FrostItems.make_stack("crystal"), FrostItems.make_stack("stone")]
	_game.state.bag.known = {"healing": true}
	_game.state.bag_sel = 0
	FrostBag.toggle(_game)
	await _wait(6)
	await _shot("86-spiel-rucksack.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()

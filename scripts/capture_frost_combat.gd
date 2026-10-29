extends SceneTree
## Captures Story 1's combat system in the Frostgruft from the real windowed
## game: a fight with hit chips, stains and shot streaks; a guardian's hail
## warning and frost breath; the hero's conditions in the hero panel; loot on
## the floor; the inventory (item system 2, src/hero/story_items.gd).
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_frost_combat.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
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
	# a guardian's hail and a frost breath warning, the hero slowed and poisoned;
	# arrows still in flight are cleared so they do not fell the guardian
	_game.mobs.clear()
	_game.shots.clear()
	_game.state.toasts = []
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
	# loot on the floor, then the inventory with weapons, potions, a crystal and gear
	_game.mobs.clear()
	_game.state.mzones = []
	var items: Node = _game.story_items
	var inv: RefCounted = items.inventory
	var at := Vector2(_game.player.x + 200.0, _game.player.y)
	var loot := [inv.make_weapon("frost_bow", false, "night"), inv.make_stack("potion", "healing"), inv.make_stack("crystal")]
	for i in range(loot.size()):
		items.floor_items.append({"item": loot[i], "p": at + Vector2(i * 36.0 - 36.0, (i % 2) * 24.0)})
	await _wait(20)
	await _shot("85-spiel-beute-am-boden.png")
	items.floor_items.clear()
	for it: Dictionary in [inv.make_weapon("sun_bow", true, ""), inv.make_weapon("void_bow", false, "leaden"),
			inv.make_stack("potion", "healing", 2), inv.make_stack("potion", "ice"), inv.make_stack("crystal"), inv.make_stack("stone"),
			inv.make_gear("chain_shirt", true, "", 1)]:
		items.give(it, Vector2.ZERO)
	_game.inventory_panel.set_view(items.view())
	_game.inventory_panel.set_open(true)
	_game.inventory_panel.selected = 0
	_game.inventory_panel._refresh_buttons()
	await _wait(6)
	await _shot("86-spiel-inventar.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()

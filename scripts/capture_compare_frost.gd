extends SceneTree
## Comparison capture: the same four Frostgruft scenes as origin/main's
## scripts/capture_frost_combat.gd (shots 83-86), staged in this branch's
## version, so both can be laid side by side: a fight with the archer shooting,
## a floor guardian next to the hero, loot on the floor, the open bag (I).
## Same class, floor, room and items where this branch has them.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_compare_frost.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const SAVE := "user://capture_compare.cfg"

var _out := "res://production/qa/evidence/vergleich-main/unsere"
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
	await _wait(1)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _start(class_id: String, floor_n: int) -> void:
	_game = FrostScene.instantiate()
	_game.class_id = class_id
	_game.start_floor = floor_n
	_game.meta_path = SAVE
	root.add_child(_game)
	await _wait(5)
	_game.state.offer = []


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
	# a fight: the archer shoots into the pack
	await _start("archer", 2)
	_fight_room()
	await _wait(90)
	for i in range(40):
		var m := _foe()
		if not m.is_empty():
			_game.state.cool = 0.0
			_game._fire((((m.p as Vector2) - Vector2(0, m.cy)) - Vector2(_game.player.x, _game.player.y - 40)).normalized())
		await _wait(2)
	await _shot("83-kampf.png")
	# a floor guardian and a second foe close by (this branch has no move warnings);
	# the arrows still in flight are cleared, the level-up banner fades first
	_game.mobs.clear()
	_game.shots.clear()
	await _wait(240)
	_game._spawn_mob(_game.state.room, Vector2(_game.player.x + 330.0, _game.player.y - 40.0), "ice_zombie")
	var b: Dictionary = _game.mobs[_game.mobs.size() - 1]
	b.kind = "boss"
	b.spawn = 0.0
	_game._spawn_mob(_game.state.room, Vector2(_game.player.x - 200.0, _game.player.y + 40.0), "ice_zombie")
	_game.mobs[_game.mobs.size() - 1].spawn = 0.0
	await _wait(28)
	await _shot("84-boss.png")
	# loot on the floor: the same bow, potion and crystal
	_game.mobs.clear()
	var items: Node = _game.story_items
	var inv: RefCounted = items.inventory
	var at := Vector2(_game.player.x + 200.0, _game.player.y)
	var loot := [inv.make_weapon("frost_bow", false, "night"), inv.make_stack("potion", "healing"), inv.make_stack("crystal")]
	for i in range(loot.size()):
		items.floor_items.append({"item": loot[i], "p": at + Vector2(i * 36.0 - 36.0, (i % 2) * 24.0)})
	await _wait(20)
	await _shot("85-beute.png")
	# the bag with the same weapons, potions, crystal and stone, plus gear
	items.floor_items.clear()
	for it: Dictionary in [inv.make_weapon("sun_bow", true, ""), inv.make_weapon("void_bow", false, "leaden"),
			inv.make_stack("potion", "healing", 2), inv.make_stack("potion", "ice"), inv.make_stack("crystal"), inv.make_stack("stone"),
			inv.make_gear("chain_shirt", true, "", 1)]:
		items.give(it, Vector2.ZERO)
	_game.state.toasts = []
	_game.inventory_panel.set_view(items.view())
	_game.inventory_panel.set_open(true)
	_game.inventory_panel.selected = 0
	_game.inventory_panel._refresh_buttons()
	await _wait(6)
	await _shot("86-rucksack.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()

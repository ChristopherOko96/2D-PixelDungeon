extends SceneTree
## Captures the HUD of the story worlds (Hell-Dungeon, Frostgruft) in the
## situations that show all of it: exploring with keys, gems and a hint; a
## locked fight; the level-up cards; the status sheet (C); the guardian's bar
## in the boss hall; an interaction prompt. The hero stays unhurt.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_unified_hud.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")

var _out := "res://production/qa/evidence/hud-unified"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = maxi(int(_game.state.max_hp) - 3, 1)
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _start(world: String, class_id: String, floor_n: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = (HellScene if world == "hell" else FrostScene).instantiate()
	_game.class_id = class_id
	_game.start_floor = floor_n
	root.add_child(_game)
	await _wait(5)


func _level_to(n: int) -> void:
	while int(_game.state.level) < n:
		HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))
	_game.state.exp = int(HeroKit.need(_game.theme.leveling, int(_game.state.level)) * 0.6)


func _room(kind: String) -> Dictionary:
	var best: Dictionary = {}
	for r: Dictionary in _game.W.rooms:
		if str(r.type) == kind and (best.is_empty() or int(r.bw) * int(r.bh) > int(best.bw) * int(best.bh)):
			best = r
	return best


func _place_in(r: Dictionary) -> void:
	var middle := Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0)
	var spot := Vector2i(int(middle.x), int(middle.y))
	var near := INF
	for c: Vector2i in r.cells:
		var open := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if _game._cell_blocked(c.x + dx, c.y + dy, true): open = false
		if open and Vector2(c).distance_to(middle) < near:
			near = Vector2(c).distance_to(middle)
			spot = c
	_game.player.x = (spot.x + 0.5) * 96.0
	_game.player.y = (spot.y + 0.7) * 96.0
	_game.camera.position = Vector2(_game.player.x, _game.player.y)
	_game.state.room = r.index


func _world(world: String, class_id: String, tag: String) -> void:
	# exploring: keys, gems, level, a hint over the bar
	await _start(world, class_id, 2)
	_level_to(6)
	_game.state.offer = []
	_game.state.cards_due = 0
	_game.state.keys["A"] = true
	_game.state.gems = 3
	await _wait(200)
	_game._toast("Ein Schlüssel liegt in dieser Etage.")
	await _wait(20)
	await _shot("%s-1-erkunden" % tag)
	# a locked fight with skills on cooldown
	var fight := _room("combat")
	_place_in(fight)
	_game._start_fight(fight)
	_game.state.skill_cd["1"] = 3.0
	await _wait(90)
	await _shot("%s-2-kampf" % tag)
	# level-up cards
	CardKit.offer(_game)
	await _wait(20)
	await _shot("%s-3-karten" % tag)
	_game.state.offer = []
	_game.state.cards_due = 0
	# status sheet
	_game.state.status = true
	await _wait(10)
	await _shot("%s-4-status" % tag)
	_game.state.status = false
	# the guardian's bar
	await _start(world, class_id, 1)
	_level_to(4)
	_game.state.offer = []
	_game.state.cards_due = 0
	var hall := _room("boss")
	_place_in(hall)
	_game._start_fight(hall)
	await _wait(120)
	await _shot("%s-5-boss" % tag)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _world("hell", "mage", "hoelle")
	await _world("frost", "archer", "frost")
	quit()

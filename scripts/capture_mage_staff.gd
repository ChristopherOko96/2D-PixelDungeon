extends SceneTree
## Captures the mage's staff in every world (src/hero/hero_look.gd): held
## upright at the side, orb up, a bit shorter than the hero; a spell lifts it
## and tips it toward the target. Crypt, Hölle and Frostgruft, resting and
## casting, facing right and left. Crops are enlarged so the grip is visible.
## Usage: godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_mage_staff.gd
const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/mage-staff"
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.get("state") is Dictionary and not (_game.state as Dictionary).is_empty() and _game.state.has("inv"):
			_game.state.inv = 0.0
		await process_frame


## Saves the whole screen and a 3x crop around `center` (screen pixels).
func _shot(name: String, center: Vector2) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	var box := Rect2i(Vector2i(center) - Vector2i(80, 70), Vector2i(160, 140)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(box)
	crop.resize(box.size.x * 3, box.size.y * 3, Image.INTERPOLATE_NEAREST)
	print("CAPTURED %s result=%d" % [name, crop.save_png(_out.path_join(name + "-nah.png"))])


func _story(scene: PackedScene, label: String) -> void:
	if _game != null:
		_game.queue_free()
		await _wait(5)
	_game = scene.instantiate()
	_game.class_id = "mage"
	root.add_child(_game)
	await _wait(60)
	var hero := _screen_of(Vector2(_game.player.x, _game.player.y - 40))
	await _shot("%s-1-ruhe" % label, hero)
	_game.state.cool = 0.0
	_game._fire(Vector2(1, -0.3).normalized())
	await _wait(3)
	await _shot("%s-2-zauber" % label, hero)
	await _wait(30)
	_game.state.cool = 0.0
	_game._fire(Vector2.LEFT)
	await _wait(3)
	await _shot("%s-3-zauber-links" % label, hero)


func _screen_of(world: Vector2) -> Vector2:
	return root.get_viewport().get_canvas_transform() * world if _game.get_viewport() != null else Vector2(640, 360)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game = Game.new()
	_game = game
	root.add_child(game)
	game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	game.main_menu._open_classes(false)
	game.main_menu._choose_class("mage")
	game.set_physics_process(false)
	await _wait(30)
	var player: Dictionary = game.players[1]
	var hero: Vector2 = game.view.get_global_transform_with_canvas() * Vector2(player.pos)
	player.aim = Vector2.RIGHT
	game._broadcast_state(true)
	await _shot("01-krypta-1-ruhe", hero)
	game.perk_combat.shoot(1, Vector2(1, -0.3).normalized())
	game._broadcast_state(true)
	await _wait(1)
	await _shot("01-krypta-2-zauber", hero)
	game._leave_session()
	await _wait(5)
	game.queue_free()
	_game = null
	await _wait(5)
	await _story(HellScene, "02-hoelle")
	await _story(FrostScene, "03-frostgruft")
	quit(0)

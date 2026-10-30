extends SceneTree
## Captures Ignaroth's part rig in the real windowed Hell-Dungeon
## (src/hell/drake_rig_host.gd, docs/HOELLE-RIGS.de.md): for each form
## (floors 3, 6, 9, 10) the boss fight at its start, a moment later (parts on
## their own curves), right after a severable part is cut (debris, flash,
## stagger), the glowing wound afterwards and the form with all its severable
## parts gone. Each shot also gets a 2x close-up around the boss. The hero is
## kept invulnerable; the run keeps its meta in its own file.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_ignaroth_ingame.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const SAVE := "user://capture_ignaroth_ingame.cfg"
## Severable parts cut per form, in this order (docs/HOELLE-RIGS.de.md).
const CUTS := {
	3: ["jaw", "arm", "tail_2"],
	6: ["tail_2", "jaw", "arm"],
	9: ["wing_near", "horns", "wing_far"],
	10: ["crystal_1", "wing_near", "horns"],
}

var _out := "res://production/qa/evidence/ignaroth-ingame"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and is_instance_valid(_game) and not _game.state.is_empty():
			_game.state.inv = 5.0
			_game.state.hp = maxi(int(_game.state.hp), 6)
		await process_frame


## Saves the frame and a 2x close-up around `focus` (a world point).
func _shot(name: String, focus: Vector2) -> void:
	_game.state.inv = 0.0
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
	var box := Rect2i(Vector2i(clampi(int(screen.x) - 320, 0, image.get_width() - 640), clampi(int(screen.y) - 180, 0, image.get_height() - 360)), Vector2i(640, 360))
	var crop := image.get_region(box)
	crop.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var close := _out.path_join(name + "-nah.png")
	print("CAPTURED %s result=%d" % [close, crop.save_png(close)])


func _start(floor_n: int) -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		await process_frame
	_game = HellScene.instantiate()
	_game.meta_path = SAVE
	_game.start_floor = floor_n
	_game.start_at_boss = true
	root.add_child(_game)
	current_scene = _game
	await _wait(5)


func _boss() -> Dictionary:
	for m: Dictionary in _game.mobs:
		if str(m.get("kind", "")) == "boss" and float(m.hp) > 0.0:
			return m
	return {}


## Where to look at the boss: its body centre from the rig, else above its feet.
func _focus(m: Dictionary) -> Vector2:
	if _game.drake_rig != null and _game.drake_rig.has_rig(m):
		return _game.drake_rig.centre(m)
	return (m.p as Vector2) - Vector2(0, float(m.get("cy", 0.0)))


## Cuts `part` off through the game's own damage path (the host routes it).
func _cut(m: Dictionary, part: String) -> bool:
	var parts: Dictionary = m.get("parts", {})
	if not parts.has(part) or part in m.get("parts_lost", []):
		print("IGNAROTH_CAPTURE_NOTE %s: no living part %s" % [m.id, part])
		return false
	var dealt := float(parts[part].hp) + 1.0
	var result: Dictionary = _game.drake_rig.damage(m, dealt, part)
	print("IGNAROTH_CAPTURE_CUT %s %s -> %s" % [m.id, part, str(result)])
	return bool(result.get("destroyed", false))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for floor_n: int in [3, 6, 9, 10]:
		await _start(floor_n)
		await _wait(150)
		var m := _boss()
		if m.is_empty():
			print("IGNAROTH_CAPTURE_FAIL floor %d: no boss" % floor_n)
			continue
		var tag := "f%02d-%s" % [floor_n, str(m.id)]
		print("IGNAROTH_CAPTURE %s rig=%s parts=%s hp=%.0f" % [tag, str(m.get("rig", "")), str((m.get("parts", {}) as Dictionary).keys()), float(m.hp)])
		await _shot(tag + "-1-kampf", _focus(m))
		await _wait(45)
		await _shot(tag + "-2-bewegung", _focus(m))
		var cuts: Array = CUTS[floor_n]
		if _cut(m, str(cuts[0])):
			await _wait(2)
			await _shot(tag + "-3-abgetrennt-" + str(cuts[0]), _focus(m))
			await _wait(50)
			await _shot(tag + "-4-wunde", _focus(m))
		for i in range(1, cuts.size()):
			_cut(m, str(cuts[i]))
			await _wait(20)
		await _wait(40)
		await _shot(tag + "-5-teile-ab", _focus(m))
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0)

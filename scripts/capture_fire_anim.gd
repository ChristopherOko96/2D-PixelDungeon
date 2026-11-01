extends SceneTree
## Captures the moving fires and the flowing fountain (src/vfx/fire_anim.gd) from the real
## windowed game, in one world: a burning prop or wall torch and the fountain, each as a strip of
## close-ups a fraction of a second apart (frame to frame the flame and the water change), plus the
## time the set's moving pictures took to make.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_fire_anim.gd -- <output_dir> <frost|hell|krypta> [pixel|hd]
const SCENES := {"frost": "res://src/hell/frost_dungeon.tscn", "hell": "res://src/hell/hell_dungeon.tscn", "krypta": "res://src/hell/krypta_dungeon.tscn"}
const GRAPHICS_FILE := "user://capture_fire_anim.cfg"

var _out := "res://production/qa/evidence/fire-anim"
var _world := "frost"
var _graphics := "hd"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_world = args[1]
	if args.size() > 2:
		_graphics = args[2]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
			_game.state.banner.t = 99.0
		await process_frame


## Frames world point p (the hero below it, out of the way) and saves `count` close-ups of it,
## `gap` s apart, side by side in one strip.
func _strip(name: String, p: Vector2, count := 4, gap := 0.12) -> void:
	_game.player.x = p.x + 260.0
	_game.player.y = p.y + 200.0
	_game.camera.position = p
	await _wait(6)
	_game.camera.position = p
	await _wait(2)
	var parts: Array = []
	for k in range(count):
		var image := root.get_texture().get_image()
		var zoom: Vector2 = _game.camera.zoom
		var c: Vector2 = (p - _game.camera.get_screen_center_position()) * zoom + Vector2(image.get_width(), image.get_height()) / 2.0
		var r := Rect2i(Vector2i(c - Vector2(110, 130)), Vector2i(220, 200))
		r.position = r.position.clamp(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()) - r.size)
		var crop := image.get_region(r)
		crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
		parts.append(crop)
		var until := Time.get_ticks_msec() + int(gap * 1000.0)
		while Time.get_ticks_msec() < until:
			await _wait(1)
	var first: Image = parts[0]
	var strip := Image.create(first.get_width() * count + 8 * (count - 1), first.get_height(), false, first.get_format())
	strip.fill(Color(0.1, 0.1, 0.14))
	for k in range(count):
		strip.blit_rect(parts[k], Rect2i(Vector2i.ZERO, first.get_size()), Vector2i(k * (first.get_width() + 8), 0))
	print("CAPTURED %s result=%d" % [name, strip.save_png(_out.path_join(name + ".png"))])


## Every picture of each sprite in `names`, a row per sprite, 3x with nearest filtering, on a
## dark ground: the flame or the water changes from picture to picture, the rest stays.
func _sheet(name: String, names: Array) -> void:
	var rows: Array = []
	var width := 0
	for n: String in names:
		var pics: Array = (_game.fire_anim.get("_frames") as Dictionary).get(n, [])
		if pics.is_empty():
			continue
		var row: Array = []
		for t: Texture2D in pics:
			var im := t.get_image()
			im.resize(im.get_width() * 3, im.get_height() * 3, Image.INTERPOLATE_NEAREST)
			row.append(im)
		rows.append(row)
		width = maxi(width, row.size() * ((row[0] as Image).get_width() + 6))
	var height := 0
	for row: Array in rows:
		height += (row[0] as Image).get_height() + 6
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.18, 0.26))
	var y := 0
	for row: Array in rows:
		var x := 0
		for im: Image in row:
			sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
			x += im.get_width() + 6
		y += (row[0] as Image).get_height() + 6
	print("CAPTURED %s result=%d" % [name, sheet.save_png(_out.path_join(name + ".png"))])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", _graphics)
	cfg.save(GRAPHICS_FILE)
	_game = (load(SCENES[_world]) as PackedScene).instantiate()
	_game.class_id = "swordsman"
	_game.graphics_path = GRAPHICS_FILE
	root.add_child(_game)
	await _wait(10)
	var t0 := Time.get_ticks_usec()
	_game.fire_anim.build(_game.tex, 3 if bool(_game.theme.get("pixel", false)) else 1)
	print("FIRE_ANIM build_ms=%.0f moving=%d" % [(Time.get_ticks_usec() - t0) / 1000.0, (_game.fire_anim.get("_frames") as Dictionary).size()])
	_sheet("%s-%s-bilder" % [_world, _graphics], ["brazier_bowl", "brazier_demon", "torch_a", "wall_torch_hook", "torch_pillar_blue", "candelabra", "fountain"])
	_game.state.world_run = 4242
	_game.load_floor(1, true)
	await _wait(20)
	for r: Dictionary in _game.W.rooms:
		r.fight = false
		r.cleared = true
	_game.mobs = []
	# a burning prop (or a lit fire bowl), a wall torch, the fountain
	var fire := Vector2.INF
	var wall := Vector2.INF
	var well := Vector2.INF
	for p: Dictionary in _game.W.props:
		if fire == Vector2.INF and _game.fire_anim.has(str(p.name)):
			fire = Vector2(p.x, p.y - 50)
		if well == Vector2.INF and str(p.name) == "fountain":
			well = Vector2(p.x, p.y - 60)
	for w: Dictionary in _game.W.wall_decor:
		if wall == Vector2.INF and _game.fire_anim.has(str(w.name)):
			wall = Vector2(w.x, w.y + 50)
	for e: Dictionary in _game.W.ents:
		if e.type == "well" and well == Vector2.INF:
			well = Vector2(e.x, e.y - 60)
		if e.type == "brazier" and fire == Vector2.INF:
			e.lit = true
			fire = Vector2(e.x, e.y - 50)
	if fire != Vector2.INF:
		await _strip("%s-%s-feuer" % [_world, _graphics], fire)
	if wall != Vector2.INF:
		await _strip("%s-%s-wandfackel" % [_world, _graphics], wall)
	if well != Vector2.INF:
		await _strip("%s-%s-brunnen" % [_world, _graphics], well)
	quit()

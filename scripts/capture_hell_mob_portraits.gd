extends SceneTree
## Renders each Hell monster's part rig alone on a transparent background
## (no room, no shadow), cropped to the figure and enlarged with nearest
## filtering, so the pixels can be looked at up close.
## Usage:
##   godot --path . --resolution 640x480 -s res://scripts/capture_hell_mob_portraits.gd -- <output_dir> [id,id] [zoom]
const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")

var _out := "res://production/qa/evidence/hell-mob-portraits"
var _ids: Array = ["brandskelett", "glutschaedel", "hoellenhund", "glutimp", "blutfledermaus", "aschenpriester", "kettenschinder", "peingeist"]
var _zoom := 8
var _renderer: RigRenderer
var _view: SubViewport
var _canvas: Node2D
var _current := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _ids = args[1].split(",")
	if args.size() > 2: _zoom = int(args[2])
	_run.call_deferred()


func _draw_figure() -> void:
	if _current.is_empty(): return
	_renderer.draw_enemy(_canvas, {"rig": _current, "id": 1, "face": 1.0, "shadow": false}, Vector2(128, 136))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_view = SubViewport.new()
	_view.size = Vector2i(256, 256)
	_view.transparent_bg = true
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_figure)
	_view.add_child(_canvas)
	for id: String in _ids:
		# a fresh renderer per figure: its own idle clock, nothing left over
		_renderer = RigRenderer.new(RigLibrary.shared())
		_current = id
		for k in range(4):
			_renderer.step(1.0 / 60.0)
			_canvas.queue_redraw()
			await process_frame
		var image := _view.get_texture().get_image()
		var used := image.get_used_rect()
		if used.size.x <= 0:
			print("PORTRAIT %s empty" % id)
			continue
		var crop := image.get_region(used.grow(3).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
		crop.resize(crop.get_width() * _zoom, crop.get_height() * _zoom, Image.INTERPOLATE_NEAREST)
		var path := _out.path_join(id + ".png")
		print("PORTRAIT %s %dx%d result=%d" % [path, crop.get_width(), crop.get_height(), crop.save_png(path)])
	quit(0)

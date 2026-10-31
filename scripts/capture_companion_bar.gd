extends SceneTree
## Draws the hero strip with the companion bar under it (HudKit.hero_panel +
## HudKit.pet_panel) into an off-screen viewport and saves the picture: a
## wolf alive (one ability on cooldown, auto-cast on), a bear low on life (the
## bar turned red) and a fallen Pyro-Monster with its respawn countdown.
## Usage (windowed, the dummy renderer of --headless draws nothing):
##   godot --path . --resolution 640x240 -s res://scripts/capture_companion_bar.gd -- [output_dir]
## Emits observations only (CAPTURED <path> result=<error code>).
const HudKit = preload("res://src/ui/hud_kit.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const PixelStyle = preload("res://src/pixel_style.gd")

const CLOCK := 0.3
const COLUMN := 400.0

var _out := "res://production/qa/evidence/visual-overhaul"
var _view: SubViewport
var _canvas: Node2D
var _font: Font = PixelStyle.create_font()

# One column per case: the hero strip's data and the companion state.
var _cases: Array = [
	{"hero": {"title": "P1 · TIERMEISTER", "hp": 14, "max_hp": 20, "hp_f": 14.0, "level": 7, "exp": 0.4, "clock": CLOCK, "key": "hero1"},
		"pet": {"kind": "wolf", "name": "Wolf", "spec": "beast", "alive": true, "hp": 41.0, "hp_max": 60.0, "respawn": 0.0, "abilities": [
			{"id": "maul", "name": "Zerfleischen", "icon": "paw", "text": "", "cd": 3.4, "cd_max": 8.0, "auto": true, "key": "5"},
			{"id": "howl", "name": "Heulen", "icon": "horn", "text": "", "cd": 0.0, "cd_max": 15.0, "auto": false, "key": "6"}]}},
	{"hero": {"title": "P1 · TIERMEISTER", "hp": 9, "max_hp": 20, "hp_f": 9.0, "level": 12, "exp": 0.7, "clock": CLOCK, "key": "hero2"},
		"pet": {"kind": "bear", "name": "Bär", "spec": "beast", "alive": true, "hp": 16.0, "hp_max": 90.0, "respawn": 0.0, "abilities": [
			{"id": "swipe", "name": "Prankenhieb", "icon": "fist", "text": "", "cd": 0.0, "cd_max": 8.0, "auto": true, "key": "5"},
			{"id": "roar", "name": "Brüllen", "icon": "horn", "text": "", "cd": 11.0, "cd_max": 16.0, "auto": true, "key": "6"}]}},
	{"hero": {"title": "P1 · PYROMANT", "hp": 18, "max_hp": 20, "hp_f": 18.0, "level": 9, "exp": 0.2, "clock": CLOCK, "key": "hero3"},
		"pet": {"kind": "pyro", "name": "Pyro-Monster", "spec": "fire", "alive": false, "hp": 0.0, "hp_max": 70.0, "respawn": 12.0, "abilities": [
			{"id": "ember_fist", "name": "Glutfaust", "icon": "fist", "text": "", "cd": 0.0, "cd_max": 6.0, "auto": true, "key": "5"},
			{"id": "fire_ring", "name": "Feuerkreis", "icon": "ring", "text": "", "cd": 0.0, "cd_max": 12.0, "auto": false, "key": "6"}]}},
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _draw_cases() -> void:
	var margin := HudStyle.size("margin")
	for index in range(_cases.size()):
		var at := Vector2(margin + index * COLUMN, margin)
		var hero_rect := HudKit.hero_panel(_canvas, _font, at, _cases[index].hero)
		HudKit.pet_panel(_canvas, _font, Vector2(hero_rect.position.x, hero_rect.end.y + 6.0), hero_rect.size.x, _cases[index].pet, CLOCK)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_view = SubViewport.new()
	_view.size = Vector2i(int(COLUMN * _cases.size() + HudStyle.size("margin")), 140)
	_view.transparent_bg = false
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	# a dungeon-dark backdrop so the see-through panels read as in the game
	var backdrop := ColorRect.new()
	backdrop.color = Color("2a2430")
	backdrop.size = Vector2(_view.size)
	_view.add_child(backdrop)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_cases)
	_view.add_child(_canvas)
	for k in range(3):
		_canvas.queue_redraw()
		await process_frame
	var image := _view.get_texture().get_image()
	var path := _out.path_join("begleiterleiste.png")
	print("CAPTURED %s result=%d used=%s" % [path, image.save_png(path), image.get_used_rect()])
	var zoom := image.duplicate() as Image
	zoom.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var zoom_path := _out.path_join("begleiterleiste-2x.png")
	print("CAPTURED %s result=%d" % [zoom_path, zoom.save_png(zoom_path)])
	# the hit test: the first ability slot of the last drawn bar answers 0, a point beside the bar -1
	var slots: Array = HudKit._pet_slots
	var inside: int = HudKit.pet_slot_at((slots[0] as Rect2).get_center()) if not slots.is_empty() else -2
	print("HIT first=%d outside=%d slots=%d" % [inside, HudKit.pet_slot_at(Vector2(2, 2)), slots.size()])
	quit(0)

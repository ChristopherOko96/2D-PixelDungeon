extends CanvasLayer
## The loading screens (assets/data/ui_loading.json, hints and numbers there).
## Between floors and on entering a world one of three screens is rolled, in the
## look of the world being played (its title, floor and wall art of the chosen
## graphics set, colours and monsters): A = the big hero with a hint, B = the
## chase without a hint, C = a hint and the chase. The hero is always the one
## being played, whatever class it is.
## On the way back to the main menu: the heroes' parade on beige; the bar follows
## the menu scene's real loading (threaded), at least menu_seconds long.
## A screen ends on its own, or earlier with E, Space, Enter, a click or a gamepad button.
## Presentation only: the game waits behind it (hell_game.gd _simulation_paused).

## Ended: a story screen is gone; for the menu, `scene` is the loaded menu (null: load it yourself).
signal finished(scene: PackedScene)

const DATA_PATH := "res://assets/data/ui_loading.json"
const HERO := "res://assets/sprites/0x72/%s_%s_anim_f%d.png"
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const TITLE_FONT := preload("res://assets/fonts/pixelify_sans.ttf")
## The layout's own size; other window shapes scale it and extend the ground.
const DESIGN := Vector2(1280, 720)
const BEIGE := Color("e8dcc4")
const BEIGE_DEEP := Color("d8c7a6")
const BEIGE_LINE := Color("bfa97f")
const INK := Color("2b2233")
const INK_SOFT := Color("5d4f4a")
const GOLD := Color("d99a2b")
## One pass of the chase takes this long, each way.
const CHASE_SECONDS := 5.0

var data: Dictionary = {}
## "A", "B", "C" or "menu".
var variant := ""
## The hero's sprite name (0x72) and class of the game behind this screen.
var hero_sprite := ""
var world_id := ""
var title := ""
var floor_line := ""
## {t, x} of the hint on this screen, empty without one.
var hint: Dictionary = {}
## Seconds this screen stays at least.
var hold := 1.0

var _view: Control
var _area := Rect2(Vector2.ZERO, DESIGN)
var _t := 0.0
var _fade := -1.0
var _world: Dictionary = {}
var _tile: Texture2D
var _wall: Texture2D
var _shade: GradientTexture2D
var _mobs: Array = []
var _run: Array = []
var _idle: Array = []
var _parade: Array = []
var _menu_path := ""
var _menu_scene: PackedScene
var _menu_failed := false
var _rng := RandomNumberGenerator.new()
var _done := false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if FileAccess.file_exists(DATA_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func _ready() -> void:
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.draw.connect(_paint)
	add_child(_view)


## Which variant `roll` (0..1) falls on, by weights {"A": n, ...} out of their sum.
static func pick_variant(weights: Dictionary, roll: float) -> String:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	var at := clampf(roll, 0.0, 0.999999) * total
	var last := ""
	for key: String in weights:
		last = key
		at -= float(weights[key])
		if at < 0.0:
			return key
	return last


## The next hint for a world and class from `seen` (hint headings shown this run, changed here):
## the pool is rolled by world_share and class_share, the general hints otherwise; nothing comes
## twice until its pool has been through. {} when there are no hints.
static func next_hint(all: Dictionary, shares: Dictionary, world: String, class_id: String, seen: Array, roll: float, roll_pick: float) -> Dictionary:
	var world_share := float(shares.get("world_share", 0.5))
	var class_share := float(shares.get("class_share", 0.15))
	var key := world if roll < world_share else (class_id if roll < world_share + class_share else "general")
	var pool: Array = all.get(key, [])
	if pool.is_empty():
		pool = all.get("general", [])
	if pool.is_empty():
		return {}
	var fresh := pool.filter(func(h: Dictionary) -> bool: return not seen.has(_hint_id(key, h)))
	if fresh.is_empty():
		for h: Dictionary in pool:
			seen.erase(_hint_id(key, h))
		fresh = pool
	var picked: Dictionary = fresh[mini(int(clampf(roll_pick, 0.0, 0.999999) * fresh.size()), fresh.size() - 1)]
	seen.append(_hint_id(key, picked))
	return picked


static func _hint_id(pool: String, h: Dictionary) -> String:
	return "%s/%s" % [pool, str(h.get("t", ""))]


## A story screen. `info`: world (world id), title (a custom story's own; empty: the world's),
## floor_line, hero (sprite name), class_id, tile and wall (the loaded set's textures), seen (the
## run's shown hints, kept by the game), variant (empty: rolled).
func start_story(info: Dictionary) -> void:
	world_id = str(info.get("world", "krypta"))
	var worlds: Dictionary = data.get("worlds", {})
	_world = worlds.get(world_id, worlds.get("krypta", {}))
	title = str(info.get("title", ""))
	if title.is_empty():
		title = str(_world.get("title", world_id.to_upper()))
	floor_line = str(info.get("floor_line", ""))
	hero_sprite = str(info.get("hero", "knight_m"))
	_tile = info.get("tile")
	_wall = info.get("wall")
	variant = str(info.get("variant", ""))
	if variant.is_empty():
		variant = pick_variant(data.get("weights", {"A": 1}), _rng.randf())
	if variant != "B":
		var seen: Array = info.get("seen", [])
		hint = next_hint(data.get("hints", {}), data, world_id, str(info.get("class_id", "")), seen, _rng.randf(), _rng.randf())
	var seconds: Dictionary = data.get("seconds", {})
	hold = float(seconds.get("plain" if hint.is_empty() else "hint", 3.0))
	_run = frames_of(hero_sprite, "run")
	_idle = frames_of(hero_sprite, "idle")
	for mob: Dictionary in _world.get("mobs", []):
		var pics: Array = []
		for f in range(int(mob.get("frames", 1))):
			var path: String = str(mob.path) % f
			if ResourceLoader.exists(path):
				pics.append(load(path))
		if not pics.is_empty():
			_mobs.append({"frames": pics, "h": float(mob.get("h", 100))})
	_shade = _make_shade(Color(str(_world.get("deep", "#000000"))))


## The way back to the menu: the parade, the bar on the threaded loading of `path`.
func start_menu(path: String) -> void:
	variant = "menu"
	var menu: Dictionary = data.get("menu", {})
	title = str(menu.get("title", ""))
	hold = float(data.get("menu_seconds", 1.2))
	for sprite: Variant in menu.get("heroes", []):
		var run := frames_of(str(sprite), "run")
		if not run.is_empty():
			_parade.append(run)
	_menu_path = path
	if ResourceLoader.load_threaded_request(path) != OK:
		_menu_failed = true


## The four frames of a hero's run or idle; [] when the sprite has none.
static func frames_of(sprite: String, kind: String) -> Array:
	var out: Array = []
	for f in range(4):
		var path := HERO % [sprite, kind, f]
		if ResourceLoader.exists(path):
			out.append(load(path))
	return out


static func _make_shade(deep: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(deep, 0.15))
	gradient.set_color(1, Color(deep, 0.94))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.55)
	tex.fill_to = Vector2(1.0, 0.95)
	tex.width = 256
	tex.height = 144
	return tex


## The bar's share 0..1: time for a story screen, for the menu also the real loading.
func progress() -> float:
	var time := clampf(_t / maxf(0.01, hold), 0.0, 1.0)
	if _menu_path.is_empty() or _menu_failed or _menu_scene != null:
		return time
	var parts := []
	ResourceLoader.load_threaded_get_status(_menu_path, parts)
	return minf(time, float(parts[0]) if not parts.is_empty() else 0.0)


## True when this screen may end now (its time is up, the menu is loaded).
func ready_to_end() -> bool:
	if _t < hold:
		return false
	return _menu_path.is_empty() or _menu_failed or _menu_scene != null


func _process(delta: float) -> void:
	_t += delta
	if not _menu_path.is_empty() and _menu_scene == null and not _menu_failed:
		match ResourceLoader.load_threaded_get_status(_menu_path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_menu_scene = ResourceLoader.load_threaded_get(_menu_path) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_menu_failed = true
	if _view != null:
		_view.queue_redraw()
	if _fade < 0.0:
		if ready_to_end():
			_end()
		return
	_fade += delta
	if _fade >= float(data.get("fade", 0.25)):
		_finish()


func _end() -> void:
	# the way to the menu goes straight on (the menu's own picture replaces this one)
	if variant == "menu":
		_finish()
	elif _fade < 0.0:
		_fade = 0.0


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(_menu_scene)
	if variant != "menu":
		queue_free()


## A skip ends a story screen early; nothing reaches the game behind it.
func _input(event: InputEvent) -> void:
	if variant != "menu" and _t >= float(data.get("skip_after", 0.6)) and _is_skip(event):
		_end()
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


## E, Space, Enter, a click or a gamepad button, just pressed.
static func _is_skip(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed()
	return false


# --- drawing ---------------------------------------------------------------------

func _paint() -> void:
	var size := _view.size
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var origin := (size - DESIGN * k) / 2.0
	var alpha := 1.0
	if _fade >= 0.0:
		alpha = 1.0 - clampf(_fade / maxf(0.01, float(data.get("fade", 0.25))), 0.0, 1.0)
	_view.modulate.a = alpha
	# the ground in layout units, reaching past the layout on any window shape
	_view.draw_set_transform(origin, 0.0, Vector2(k, k))
	var area := Rect2(-origin / k, size / k)
	_area = area
	if variant == "menu":
		_paint_menu(area)
		return
	_paint_world(area)
	match variant:
		"A": _paint_a()
		"B": _paint_b()
		_: _paint_c()


func _paint_menu(area: Rect2) -> void:
	_view.draw_rect(area, BEIGE)
	_text_center(TITLE_FONT, title, 150.0, 72, INK)
	_view.draw_rect(Rect2(area.position.x, 452, area.size.x, 4), INK)
	# the dashes run under the heroes, so they run on the spot
	var off := fmod(_t * 137.0, 96.0)
	var x := area.position.x - off
	while x < area.end.x:
		_view.draw_rect(Rect2(x, 472, 40, 8), BEIGE_LINE)
		x += 96.0
	var count := _parade.size()
	for i in range(count):
		var frames: Array = _parade[i]
		_hero_frame(frames, Vector2(640.0 + (i - (count - 1) / 2.0) * 184.0, 452.0), 7.0, 10.0, false, i * 0.1)
	_bar(Rect2(240, 544, 800, 32), INK, BEIGE_DEEP, GOLD)
	_view.draw_string(FONT, Vector2(240, 610), _dots(str(data.get("menu", {}).get("status", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK_SOFT)


func _paint_world(area: Rect2) -> void:
	var deep := Color(str(_world.get("deep", "#000000")))
	_view.draw_rect(area, deep)
	if _tile != null:
		_view.draw_texture_rect(_tile, area, true)
	if _wall != null:
		# the wall strip along the top, as tall as the layout's 170 px, tiled
		var s := 170.0 / maxf(1.0, _wall.get_size().y)
		_view.draw_set_transform(_origin_of(area), 0.0, _scale_of() * s)
		_view.draw_texture_rect(_wall, Rect2(Vector2.ZERO, Vector2(area.size.x / s, _wall.get_size().y)), true)
		_restore()
	_view.draw_texture_rect(_shade, area, false)
	_particles(area)


func _origin_of(area: Rect2) -> Vector2:
	var size := _view.size
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	return (size - DESIGN * k) / 2.0 + area.position * k


func _scale_of() -> Vector2:
	var size := _view.size
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	return Vector2(k, k)


func _restore() -> void:
	var size := _view.size
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_view.draw_set_transform((size - DESIGN * k) / 2.0, 0.0, Vector2(k, k))


## A: the world's name top left, the big hero, the hint beside him, the bar below.
func _paint_a() -> void:
	_name_block(72.0, 104.0, 72, HORIZONTAL_ALIGNMENT_LEFT)
	_hero_frame(_idle, Vector2(232.0, 548.0), 12.0, 6.0, false, 0.0)
	_hint_plate(Rect2(500, 224, 708, 256), 20)
	_world_bar(Rect2(72, 584, 1136, 32), 72.0)


## B: the world's name large in the middle, the chase, the bar.
func _paint_b() -> void:
	_name_block(0.0, 118.0, 84, HORIZONTAL_ALIGNMENT_CENTER)
	_chase(496.0, 1.0)
	_world_bar(Rect2(240, 568, 800, 32), 240.0)


## C: the world's name, the hint, the chase below, the bar.
func _paint_c() -> void:
	_name_block(0.0, 84.0, 64, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_plate(Rect2(200, 168, 880, 176), 20)
	_chase(544.0, 0.72)
	_world_bar(Rect2(200, 576, 880, 32), 200.0)


func _name_block(x: float, y: float, font_size: int, align: int) -> void:
	var width := DESIGN.x if align == HORIZONTAL_ALIGNMENT_CENTER else -1.0
	var deep := Color(str(_world.get("deep", "#000000")))
	_view.draw_string_outline(TITLE_FONT, Vector2(x, y), title, align, width, font_size, 8, deep)
	_view.draw_string(TITLE_FONT, Vector2(x, y), title, align, width, font_size, Color(str(_world.get("text", "#ffffff"))))
	if floor_line != "":
		var sub := Vector2(x, y + 44.0)
		_view.draw_string_outline(FONT, sub, floor_line, align, width, 24, 6, deep)
		_view.draw_string(FONT, sub, floor_line, align, width, 24, Color(str(_world.get("soft", "#cccccc"))))


func _hint_plate(rect: Rect2, body: int) -> void:
	if hint.is_empty():
		return
	var accent := Color(str(_world.get("accent", "#ffffff")))
	_view.draw_rect(rect, Color(0.04, 0.03, 0.055, 0.8))
	_view.draw_rect(rect, accent, false, 4.0)
	var inner := rect.position + Vector2(28.0, 56.0)
	_view.draw_string(TITLE_FONT, inner, str(hint.get("t", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 56.0, 36, accent)
	_view.draw_multiline_string(FONT, inner + Vector2(0.0, 44.0), str(hint.get("x", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 56.0, body, 5, Color(str(_world.get("text", "#ffffff"))))


func _world_bar(rect: Rect2, label_x: float) -> void:
	_bar(rect, Color(str(_world.get("text", "#ffffff"))), Color(str(_world.get("track", "#222222"))), Color(str(_world.get("accent", "#ffffff"))))
	var soft := Color(str(_world.get("soft", "#cccccc")))
	var y := rect.end.y + 28.0
	_view.draw_string(FONT, Vector2(label_x, y), _dots(str(_world.get("status", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, soft)
	if _t >= float(data.get("skip_after", 0.6)):
		_view.draw_string(FONT, Vector2(rect.position.x, y), str(data.get("skip_label", "")), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 16, soft)


func _bar(rect: Rect2, edge: Color, track: Color, fill: Color) -> void:
	_view.draw_rect(rect, track)
	var inner := rect.grow(-4.0)
	var width := inner.size.x * progress()
	var x := inner.position.x
	# chunks, as in the preview: 20 px of fill, a 4 px gap
	while x < inner.position.x + width:
		_view.draw_rect(Rect2(x, inner.position.y, minf(20.0, inner.position.x + width - x), inner.size.y), fill)
		x += 24.0
	_view.draw_rect(rect, edge, false, 4.0)


## The chase along ground line `ground`: the monsters after the hero, then the hero after them.
## It starts in view, so the shortest screen shows it too.
func _chase(ground: float, size: float) -> void:
	var phase := fmod(_t + CHASE_SECONDS * 0.3, CHASE_SECONDS * 2.0)
	var back := phase >= CHASE_SECONDS
	var share := (phase - (CHASE_SECONDS if back else 0.0)) / CHASE_SECONDS
	var run := _run if not _run.is_empty() else _idle
	var parts: Array = []
	for mob: Dictionary in _mobs:
		parts.append({"frames": mob.frames, "h": float(mob.h) * size})
	# the hero is always on the right: ahead of them going right, after them going left
	parts.append({"frames": run, "h": 196.0 * size})
	var gap := 40.0 * size
	var total := 0.0
	var widths: Array = []
	for part: Dictionary in parts:
		var pic: Texture2D = part.frames[0]
		var w: float = pic.get_width() * (float(part.h) / maxf(1.0, pic.get_height()))
		widths.append(w)
		total += w + gap
	# from window edge to window edge, on any window shape
	var left := _area.position.x - total
	var right := _area.end.x + 40.0
	var x := lerpf(left, right, share) if not back else lerpf(right, left, share)
	for i in range(parts.size()):
		var part: Dictionary = parts[i]
		var frames: Array = part.frames
		var pic: Texture2D = frames[int(_t * 10.0 + i) % frames.size()]
		var rect := Rect2(x, ground - float(part.h), float(widths[i]), float(part.h))
		_flip_rect(pic, rect, back)
		x += float(widths[i]) + gap


## One sprite with its feet at `feet`, `zoom` times its size; `t` shifts the frame.
func _hero_frame(frames: Array, feet: Vector2, zoom: float, fps: float, flip: bool, t: float) -> void:
	if frames.is_empty():
		return
	var pic: Texture2D = frames[int((_t + t) * fps) % frames.size()]
	var size := pic.get_size() * zoom
	_flip_rect(pic, Rect2(feet - Vector2(size.x / 2.0, size.y), size), flip)


func _flip_rect(pic: Texture2D, rect: Rect2, flip: bool) -> void:
	if flip:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	_view.draw_texture_rect(pic, rect, false)


func _particles(area: Rect2) -> void:
	var kind := str(_world.get("particles", ""))
	if kind == "ember":
		for i in range(14):
			var share := fmod(_t / 3.2 + i * 0.137, 1.0)
			var x := area.position.x + fmod(i * 197.0, area.size.x) + share * 40.0
			_view.draw_rect(Rect2(x, area.end.y - share * area.size.y, 8, 8), Color(1.0, 0.54, 0.24, sin(share * PI)))
	elif kind == "flake":
		for i in range(40):
			var share := fmod(_t / 4.0 + i * 0.0731, 1.0)
			var x := area.position.x + fmod(i * 149.0 - share * 260.0 + 1600.0, area.size.x)
			var size := 4.0 + float(i % 3)
			_view.draw_rect(Rect2(x, area.position.y + share * area.size.y, size, size), Color(0.96, 0.97, 1.0, 0.85))


func _text_center(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
	_view.draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, DESIGN.x, font_size, color)


func _dots(text: String) -> String:
	return text + ".".repeat(int(_t * 2.5) % 4)

extends Control
## Title screen shown before any session: start a solo run, open the multiplayer
## lobby controls, or quit. Owns no game state; it only reports the choice.

signal solo_requested
signal multiplayer_requested
signal quit_requested

const SCREEN := Vector2(1280, 720)
const HEROES := ["knight_m", "elf_f", "wizzard_m", "lizard_m"]
const SPRITE_ROOT := "res://assets/sprites/0x72/"
const GOLD := Color("edbf75")
const MUTED := Color("8e96ac")

var _hero_frames: Array = []
var _hero_rects: Array[TextureRect] = []
var _clock := 0.0


func _ready() -> void:
	position = Vector2.ZERO
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.9)
	shade.size = SCREEN
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_label("BASEMENT RUN", Vector2(0, 92), 72, GOLD)
	_label("IN DIE TIEFE. ZUSAMMEN.", Vector2(0, 182), 18, MUTED)
	# The four heroes idle in a row: one per player colour in a co-op run.
	for index: int in range(HEROES.size()):
		var frames: Array = []
		for frame: int in range(4):
			frames.append(load("%s%s_idle_anim_f%d.png" % [SPRITE_ROOT, HEROES[index], frame]))
		_hero_frames.append(frames)
		var hero := TextureRect.new()
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_SCALE
		hero.size = Vector2(64, 112)
		hero.position = Vector2(SCREEN.x * 0.5 - 230 + index * 120, 228)
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hero)
		_hero_rects.append(hero)
	_button("SPIEL STARTEN", 392, 26, solo_requested.emit).grab_focus()
	_button("MEHRSPIELER", 464, 20, multiplayer_requested.emit)
	_button("BEENDEN", 528, 20, quit_requested.emit)
	_label("WASD BEWEGEN  ·  MAUS ZIELEN  ·  LINKE MAUSTASTE FEUERN  ·  OFFENE TÜR: NÄCHSTER RAUM", Vector2(0, 640), 14, MUTED)
	_refresh_heroes()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_refresh_heroes()


func _refresh_heroes() -> void:
	var frame: int = int(_clock * 6.0)
	for index: int in range(_hero_rects.size()):
		_hero_rects[index].texture = _hero_frames[index][(frame + index) % 4]


func _label(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(SCREEN.x, font_size * 1.5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _button(text: String, y: float, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size = Vector2(340, 56 if font_size > 20 else 48)
	button.position = Vector2((SCREEN.x - button.size.x) * 0.5, y)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_stylebox_override("normal", _style(Color("292b37"), Color("61523a")))
	button.add_theme_stylebox_override("hover", _style(Color("383846"), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color("383846"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("3e3a34"), Color("72dcc8")))
	button.pressed.connect(callback)
	add_child(button)
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style

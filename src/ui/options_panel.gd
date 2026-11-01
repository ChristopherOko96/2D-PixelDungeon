extends Control
## The shared options panel: volume (Gesamt, Musik, Effekte) and the display
## checks (Vollbild, Bildschirmwackeln, Kamerabewegung reduzieren, HD-Grafik).
## The pause menu shows it on its Optionen page; the title menu can use the same
## panel, so both places offer the same options.
##
## Settings live in a ConfigFile, section "options", with the keys the main menu
## writes (volume, music, effects 0-100, fullscreen, shake, graphics) plus
## camera_calm. A change rewrites only its own key; keys this panel does not
## know stay in the file. Volume is applied here (AudioMix.set_slider), the
## graphics choice is stored through GraphicsSettings. Fullscreen is stored and
## reported only: the host applies it from `changed("fullscreen", on)`.
##
## Usage: add_child(panel), then panel.setup(path) for another file (tests).
## When the panel becomes visible the Gesamt slider takes focus; focus runs top
## to bottom; Esc / ui_cancel emits back_pressed.

## The player changed a setting (key as in the settings file, value as stored).
signal changed(key: String, value: Variant)
## Esc / ui_cancel while the panel is visible, or the Zurück button.
signal back_pressed

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const AudioMix = preload("res://src/audio/audio_mix.gd")
const GraphicsSettings = preload("res://src/core/graphics_settings.gd")

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "options"
## The main menu's defaults, plus camera_calm.
const DEFAULTS := {"volume": 80, "music": 70, "effects": 85, "fullscreen": false, "shake": true, "camera_calm": false, "graphics": "pixel"}
const VOLUME_KEYS := ["volume", "music", "effects"]
const SLIDERS := [["volume", "Gesamt"], ["music", "Musik"], ["effects", "Effekte"]]
const CHECKS := [["fullscreen", "Vollbild"], ["shake", "Bildschirmwackeln"], ["camera_calm", "Kamerabewegung reduzieren"], ["graphics", "HD-Grafik"]]
const FONT_SIZE := 16
## Row width; the label column, slider and value column sit inside it.
const ROW_W := 560.0
const LABEL_W := 192.0
const SLIDER_W := 272.0

## The file the options are read from and written to.
var settings_path := DEFAULT_PATH
## The current values: DEFAULTS overlaid with the file.
var settings: Dictionary = DEFAULTS.duplicate()
## True: Esc is marked handled after back_pressed (for a host whose own Esc
## handling should not run as well). The pause leaves it false: Esc closes it.
var consume_cancel := false
## Shows the Zurück button (the title menu); the pause has its own navigation.
var show_back := false:
	set(value):
		show_back = value
		if back_button != null:
			back_button.visible = value
			_link_focus()
var sliders: Dictionary = {}
var checks: Dictionary = {}
var back_button: Button
var _values: Dictionary = {}
var _graphics_note: Label
var _exit: Control
var _built := false


func _ready() -> void:
	theme = CryptUI.create_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO: size = Vector2(ROW_W, 460)
	var y := 0.0
	_label("TON", Vector2(0, y), Vector2(ROW_W, 24), CryptUI.GOLD)
	y += 32.0
	for row: Array in SLIDERS:
		var key: String = row[0]
		_label(str(row[1]), Vector2(0, y), Vector2(LABEL_W, 32), CryptUI.BONE).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var slider := HSlider.new()
		slider.position = Vector2(LABEL_W + 8, y + 4)
		slider.size = Vector2(SLIDER_W, 24)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.focus_mode = Control.FOCUS_ALL
		slider.add_theme_stylebox_override("focus", CryptUI.box("focus"))
		slider.value_changed.connect(func(value: float) -> void: set_option(key, int(value)))
		add_child(slider)
		sliders[key] = slider
		var shown := _label("", Vector2(LABEL_W + SLIDER_W + 16, y), Vector2(ROW_W - LABEL_W - SLIDER_W - 16, 32), CryptUI.CREAM)
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_values[key] = shown
		y += 40.0
	y += 16.0
	_label("ANZEIGE", Vector2(0, y), Vector2(ROW_W, 24), CryptUI.GOLD)
	y += 32.0
	for row: Array in CHECKS:
		var key: String = row[0]
		var check := CheckButton.new()
		check.text = str(row[1])
		# the theme's row frame has a 6 px margin; shift so the text lines up with the labels
		check.position = Vector2(-6, y)
		check.size = Vector2(ROW_W + 12, 36)
		check.add_theme_font_size_override("font_size", FONT_SIZE)
		check.toggled.connect(func(on: bool) -> void: set_option(key, ("hd" if on else "pixel") if key == "graphics" else on))
		add_child(check)
		checks[key] = check
		y += 40.0
	_graphics_note = _label("", Vector2(0, y), Vector2(ROW_W, 24), CryptUI.SAND)
	y += 40.0
	back_button = Button.new()
	back_button.text = "Zurück"
	back_button.position = Vector2(0, y)
	back_button.size = Vector2(ROW_W, 40)
	back_button.add_theme_font_size_override("font_size", FONT_SIZE)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	back_button.visible = show_back
	add_child(back_button)
	_built = true
	_link_focus()
	refresh()


## Reads and writes `path` from now on (tests: user://settings_test.cfg) and reloads.
func setup(path := DEFAULT_PATH) -> void:
	settings_path = path
	refresh()


## Reads the file again and shows its values; emits nothing and applies nothing.
func refresh() -> void:
	settings = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(settings_path) == OK:
		for key: String in DEFAULTS: settings[key] = file.get_value(SECTION, key, DEFAULTS[key])
	settings.graphics = GraphicsSettings.mode(settings_path)
	if not _built: return
	for key: String in sliders: show_value(key, settings[key])
	for key: String in checks: show_value(key, settings[key])


## Sets one option: writes it to the file (every other key stays), applies the
## volume, and emits `changed`. The widgets follow without a second signal.
func set_option(key: String, value: Variant) -> void:
	if key in VOLUME_KEYS: value = clampi(int(value), 0, 100)
	settings[key] = value
	if key == "graphics":
		GraphicsSettings.store(str(value), settings_path)
	else:
		var file := ConfigFile.new()
		file.load(settings_path)
		file.set_value(SECTION, key, value)
		file.save(settings_path)
	if key in VOLUME_KEYS:
		AudioMix.ensure_buses()
		AudioMix.set_slider(key, float(value) / 100.0)
	show_value(key, value)
	changed.emit(key, value)


## Applies the three volume values (e.g. once at start-up).
func apply_audio() -> void:
	AudioMix.ensure_buses()
	for key: String in VOLUME_KEYS: AudioMix.set_slider(key, clampf(float(settings[key]) / 100.0, 0.0, 1.0))


## Shows `value` for `key` without emitting or writing (e.g. the host's real
## fullscreen state, or the graphics mode the world switched to).
func show_value(key: String, value: Variant) -> void:
	settings[key] = value
	if not _built: return
	if key in sliders:
		sliders[key].set_value_no_signal(clampf(float(value), 0.0, 100.0))
		_values[key].text = "%d %%" % int(value)
	elif key in checks:
		checks[key].set_pressed_no_signal(str(value) == "hd" if key == "graphics" else bool(value))


## A line under HD-Grafik: what the choice means in this world. Only the part
## after " · " shows (the check already says HD or Pixel); no such part hides it.
func set_graphics_note(note: String) -> void:
	if _graphics_note == null: return
	var cut := note.find(" · ")
	var rest := note.substr(cut + 3) if cut >= 0 else ""
	_graphics_note.text = rest.left(1).to_upper() + rest.substr(1)


## The control that takes focus first (the Gesamt slider).
func first_focus() -> Control:
	return sliders.get("volume")


## Up from the first slider and left from a check lead to `target` (e.g. the
## pause menu's Optionen button), so pad and keys can leave the panel.
func set_exit_focus(target: Control) -> void:
	_exit = target
	_link_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _built and is_visible_in_tree():
		_focus_first.call_deferred()


func _focus_first() -> void:
	if is_visible_in_tree() and first_focus() != null: first_focus().grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"): return
	back_pressed.emit()
	if consume_cancel: get_viewport().set_input_as_handled()


## Focus neighbours top to bottom: the sliders, the checks, Zurück when shown.
func _link_focus() -> void:
	if not _built: return
	var order: Array[Control] = []
	for row: Array in SLIDERS: order.append(sliders[row[0]])
	for row: Array in CHECKS: order.append(checks[row[0]])
	if back_button.visible: order.append(back_button)
	var exit_ok := _exit != null and is_instance_valid(_exit) and _exit.is_inside_tree() and is_inside_tree()
	for index in range(order.size()):
		var item := order[index]
		var above: Control = order[index - 1] if index > 0 else (_exit if exit_ok else item)
		var below: Control = order[index + 1] if index < order.size() - 1 else item
		item.focus_neighbor_top = item.get_path_to(above)
		item.focus_neighbor_bottom = item.get_path_to(below)
		item.focus_previous = item.focus_neighbor_top
		item.focus_next = item.focus_neighbor_bottom
		# sliders keep left / right for their value
		if not item is HSlider:
			item.focus_neighbor_left = item.get_path_to(_exit if exit_ok else item)
			item.focus_neighbor_right = item.get_path_to(item)


func _label(value: String, point: Vector2, dimensions: Vector2, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size = dimensions
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

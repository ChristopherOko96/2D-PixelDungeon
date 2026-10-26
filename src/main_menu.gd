extends Control
## Title screen: Story mode on top, Endless below, then multiplayer, options and
## quit. A small pixel scene plays behind it (torch-lit wall, heroes chased by
## goblins). Top right shows the account (guest or signed-in e-mail) with the
## saved progress; bottom right the game version. Login and options open as
## panels over the menu. Owns no game state; it reports choices by signal and
## stores options in user://settings.cfg.

## A solo run with the chosen mode and hero class.
signal start_requested(endless: bool, class_id: String)
signal multiplayer_requested
signal quit_requested
signal settings_changed(settings: Dictionary)

const Progress = preload("res://src/online/progress.gd")
const SCREEN := Vector2(1280, 720)
const SPRITE_ROOT := "res://assets/sprites/0x72/"
const HEROES := ["knight_m", "elf_f", "wizzard_m", "lizard_m"]
const CHASERS := ["goblin", "goblin", "orc_shaman"]
const FLOOR_TEXTURE := preload("res://assets/sprites/floor_stone.png")
const TORCH_TEXTURE := preload("res://assets/sprites/torch.png")
const SETTINGS_PATH := "user://settings.cfg"
const GOLD := Color("edbf75")
const MUTED := Color("8e96ac")
const TEXT := Color("d9dceb")
const FLOOR_TOP := 592.0

## Set by the game before the menu enters the tree.
var account: Node
var classes: Dictionary = {}
var class_order: Array = []
var weapons: Dictionary = {}
## Debug level list: {label, endless, floor, room}; set by the game.
var debug_entries: Array = []
var _debug_start: Dictionary = {}
var _debug_panel: Panel
var settings := {"volume": 80, "fullscreen": false, "shake": true}
# Starts mid-chase so the heroes are on screen from the first frame.
var _clock := 7.0
var _frames: Dictionary = {}
var _buttons: Array[Button] = []
var _account_label: Label
var _progress_label: Label
var _account_button: Button
var _toast: Label
var _toast_time := 0.0
var _login_panel: Panel
var _email_input: LineEdit
var _password_input: LineEdit
var _login_status: Label
var _login_buttons: Array[Button] = []
var _options_panel: Panel
var _volume_slider: HSlider
var _fullscreen_check: CheckButton
var _shake_check: CheckButton
var _class_panel: Panel
var _class_title: Label
var _class_endless := false
var _class_heroes: Array[TextureRect] = []
var _class_frames: Array = []


func _ready() -> void:
	position = Vector2.ZERO
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for name: String in HEROES + CHASERS:
		var run: Array = []
		for frame in range(4):
			run.append(load("%s%s_run_anim_f%d.png" % [SPRITE_ROOT, name, frame]))
		_frames[name] = run
	_label("BASEMENT RUN", Vector2(0, 54), Vector2(SCREEN.x, 90), 72, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label("IN DIE TIEFE.", Vector2(0, 140), Vector2(SCREEN.x, 28), 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_buttons.append(_button("STORY-MODUS", Vector2(470, 200), Vector2(340, 62), 28, _open_classes.bind(false)))
	_buttons.append(_button("ENDLOS-MODUS", Vector2(470, 274), Vector2(340, 52), 22, _open_classes.bind(true)))
	_buttons.append(_button("MEHRSPIELER", Vector2(470, 338), Vector2(340, 44), 18, multiplayer_requested.emit))
	_buttons.append(_button("OPTIONEN", Vector2(470, 394), Vector2(340, 44), 18, _open_options))
	_buttons.append(_button("BEENDEN", Vector2(470, 450), Vector2(340, 44), 18, quit_requested.emit))
	_button("LEVEL-AUSWAHL (DEBUG)", Vector2(16, 676), Vector2(220, 30), 12, _open_debug)
	_buttons[0].grab_focus()
	_account_label = _label("", Vector2(820, 20), Vector2(300, 22), 15, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_progress_label = _label("", Vector2(620, 44), Vector2(500, 20), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_account_button = _button("ANMELDEN", Vector2(1132, 18), Vector2(124, 44), 14, _on_account_button)
	_label("v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0")), Vector2(1080, 690), Vector2(184, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_toast = _label("", Vector2(0, 498), Vector2(SCREEN.x, 24), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_build_login_panel()
	_build_options_panel()
	_build_class_panel()
	_build_debug_panel()
	_load_settings()
	if account != null:
		account.changed.connect(_refresh_account)
		account.message.connect(_on_account_message)
		account.firebase.signed_in.connect(func(_email: String): _close_panels())
	_refresh_account()


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast.modulate.a = minf(1.0, _toast_time)
	if _class_panel.visible:
		for i in range(_class_heroes.size()):
			_class_heroes[i].texture = _class_frames[i][(int(_clock * 7.0) + i) % _class_frames[i].size()]
	if account != null and _login_panel.visible:
		for button in _login_buttons: button.disabled = account.firebase.busy or not account.firebase.configured()
	queue_redraw()


## Shows a short message under the buttons.
func show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 3.0


# --- Pixel scene ------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("0b0d14"))
	# Back wall with torches, then the stone floor the chase runs across.
	for column in range(21):
		var x := column * 64.0
		draw_rect(Rect2(x + 2, FLOOR_TOP - 76, 60, 30), Color("2a2638"))
		draw_rect(Rect2(x + 3, FLOOR_TOP - 75, 58, 4), Color("3b3450"))
		draw_rect(Rect2(x + 2, FLOOR_TOP - 44, 60, 40), Color("231f30"))
	for column in range(41):
		draw_texture_rect(FLOOR_TEXTURE, Rect2(column * 32.0, FLOOR_TOP, 32, 32), false, Color(0.7, 0.7, 0.78))
		draw_texture_rect(FLOOR_TEXTURE, Rect2(column * 32.0 + 16.0, FLOOR_TOP + 32, 32, 32), false, Color(0.55, 0.55, 0.62))
		draw_texture_rect(FLOOR_TEXTURE, Rect2(column * 32.0, FLOOR_TOP + 64, 32, 32), false, Color(0.4, 0.4, 0.47))
		draw_texture_rect(FLOOR_TEXTURE, Rect2(column * 32.0 + 16.0, FLOOR_TOP + 96, 32, 32), false, Color(0.28, 0.28, 0.34))
	for index in range(5):
		var torch := Vector2(110 + index * 265, FLOOR_TOP - 60)
		var flicker := sin(_clock * 7.0 + index * 1.7)
		draw_circle(torch, 70.0, Color(1.0, 0.5, 0.25, 0.05 + 0.012 * flicker))
		draw_circle(torch, 36.0, Color(1.0, 0.55, 0.3, 0.08 + 0.02 * flicker))
		draw_texture_rect(TORCH_TEXTURE, Rect2(torch - Vector2(16, 20), Vector2(32, 32)), false)
	# The chase: four heroes run right, goblins and a shaman on their heels.
	var lead := fmod(_clock * 95.0, SCREEN.x + 760.0) - 300.0
	for index in range(HEROES.size()):
		_draw_runner(HEROES[index], lead - index * 70.0, index)
	for index in range(CHASERS.size()):
		_draw_runner(CHASERS[index], lead - 400.0 - index * 62.0, index + 4)
	# Dust motes drifting up through the torchlight.
	for index in range(26):
		var x := fmod(index * 197.0 + sin(_clock * 0.4 + index) * 30.0, SCREEN.x)
		var y := fmod(700.0 - _clock * (8.0 + index % 5 * 3.0) - index * 61.0, 720.0)
		if y < 0.0: y += 720.0
		draw_rect(Rect2(roundf(x), roundf(y), 2, 2), Color(0.95, 0.78, 0.6, 0.12 + 0.08 * sin(_clock * 1.5 + index)))
	# Darken the top so the title reads.
	for band in range(8):
		draw_rect(Rect2(0, band * 24.0, SCREEN.x, 24), Color(0.04, 0.05, 0.08, 0.6 - band * 0.07))


func _draw_runner(name: String, x: float, seed: int) -> void:
	var frames: Array = _frames[name]
	var texture: Texture2D = frames[(int(_clock * 10.0) + seed) % frames.size()]
	var size := Vector2(texture.get_width(), texture.get_height()) * 3.0
	var hop: float = absf(sin(_clock * 10.0 + seed)) * 3.0
	var feet := Vector2(roundf(x), FLOOR_TOP + 70.0)
	draw_rect(Rect2(feet.x - size.x * 0.35, feet.y - 3, size.x * 0.7, 6), Color(0, 0, 0, 0.35))
	draw_texture_rect(texture, Rect2(feet - Vector2(size.x * 0.5, size.y + roundf(hop)), size), false)


# --- Account ----------------------------------------------------------------

func _refresh_account() -> void:
	var signed_in: bool = account != null and account.firebase.is_signed_in()
	_account_label.text = ("Angemeldet: " + account.display_name()) if signed_in else "Gast"
	_progress_label.text = Progress.summary(account.progress) if account != null else ""
	_account_button.text = "ABMELDEN" if signed_in else "ANMELDEN"


func _on_account_button() -> void:
	if account != null and account.firebase.is_signed_in():
		account.firebase.sign_out()
		show_toast("Abgemeldet. Du spielst jetzt als Gast.")
	else:
		_open_login()


func _on_account_message(text: String) -> void:
	if _login_panel.visible:
		_login_status.text = text
	else:
		show_toast(text)


func _build_login_panel() -> void:
	_login_panel = _panel("ANMELDEN")
	_email_input = _text_field(_login_panel, "E-Mail", Vector2(30, 70), false)
	_password_input = _text_field(_login_panel, "Passwort", Vector2(30, 122), true)
	_password_input.text_submitted.connect(func(_text: String): _submit_login(false))
	_login_buttons.append(_panel_button(_login_panel, "ANMELDEN", Vector2(30, 180), Vector2(175, 44), _submit_login.bind(false)))
	_login_buttons.append(_panel_button(_login_panel, "KONTO ERSTELLEN", Vector2(215, 180), Vector2(175, 44), _submit_login.bind(true)))
	_login_status = Label.new()
	_login_status.position = Vector2(30, 236)
	_login_status.size = Vector2(360, 66)
	_login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_status.add_theme_font_size_override("font_size", 13)
	_login_status.add_theme_color_override("font_color", GOLD)
	_login_panel.add_child(_login_status)
	_panel_button(_login_panel, "ZURÜCK", Vector2(30, 306), Vector2(360, 38), _close_panels)


func _open_login() -> void:
	_close_panels()
	_login_panel.visible = true
	var ready: bool = account != null and account.firebase.configured()
	_login_status.text = "Mit Konto wird dein Fortschritt online gespeichert." if ready else "Online-Konten sind noch nicht eingerichtet (firebase.local.json fehlt). Als Gast wird dein Fortschritt auf diesem PC gespeichert."
	_email_input.grab_focus()


func _submit_login(create: bool) -> void:
	if account == null or account.firebase.busy:
		return
	if _email_input.text.strip_edges().is_empty() or _password_input.text.is_empty():
		_login_status.text = "Bitte E-Mail und Passwort eingeben."
		return
	_login_status.text = "Konto wird erstellt …" if create else "Anmeldung läuft …"
	if create:
		account.firebase.sign_up(_email_input.text, _password_input.text)
	else:
		account.firebase.sign_in(_email_input.text, _password_input.text)


# --- Hero choice ------------------------------------------------------------

## Before a solo run: three hero cards (animated sprite, name, description,
## hearts and starting weapon). Choosing one starts the run.
func _build_class_panel() -> void:
	_class_panel = Panel.new()
	_class_panel.size = Vector2(800, 420)
	_class_panel.position = (SCREEN - _class_panel.size) * 0.5 + Vector2(0, 30)
	_class_panel.add_theme_stylebox_override("panel", _style(Color("1a1d29"), GOLD))
	_class_panel.visible = false
	add_child(_class_panel)
	_class_title = _panel_label(_class_panel, "WÄHLE DEINEN HELDEN", Vector2(30, 18))
	_class_title.size.x = 740
	_class_title.add_theme_font_size_override("font_size", 22)
	_class_title.add_theme_color_override("font_color", GOLD)
	for i in range(class_order.size()):
		var id: String = str(class_order[i])
		var hero: Dictionary = classes[id]
		var card := _make_button("", Vector2(236, 290), 14, func(): _choose_class(id))
		card.position = Vector2(30 + i * 252, 62)
		_class_panel.add_child(card)
		var frames: Array = []
		for frame in range(4):
			frames.append(load("%s%s_idle_anim_f%d.png" % [SPRITE_ROOT, hero.sprite, frame]))
		_class_frames.append(frames)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.size = Vector2(64, 112)
		picture.position = Vector2(86, 14)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		_class_heroes.append(picture)
		var weapon: Dictionary = weapons.get(str(hero.weapon), {})
		# The hero's numbers, so the choice is informed: hearts, weapon and how it hits.
		var reach: String = ("NAHKAMPF %d" % int(weapon.get("reach", 0))) if str(weapon.get("type", "")) == "melee" else ("REICHWEITE %.1f" % (float(weapon.get("speed", 0)) * float(weapon.get("life", 0)) / 100.0))
		var lines := [[str(hero.name), 18, GOLD, 136], [str(hero.description), 13, TEXT, 162],
			["%d HERZEN · %s" % [ceili(float(hero.hp) / 2.0), str(weapon.get("name", ""))], 13, Color("ef8a9a"), 214],
			["SCHADEN %s · %.1f/s\n%s · TEMPO %d" % [str(weapon.get("damage", 0)), 1.0 / maxf(float(weapon.get("interval", 1.0)), 0.01), reach, int(hero.speed)], 12, MUTED, 236]]
		for line: Array in lines:
			var label := Label.new()
			label.text = line[0]
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", line[1])
			label.add_theme_color_override("font_color", line[2])
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Lies over the card on the panel (clicks pass through to the card).
			_class_panel.add_child(label)
			label.position = card.position + Vector2(12, line[3])
			label.size = Vector2(212, 70)
	_panel_button(_class_panel, "ZURÜCK", Vector2(30, 366), Vector2(740, 38), _close_panels)


## Debug: every level as a button; a pick goes through the hero choice and
## then starts right there.
func _build_debug_panel() -> void:
	_debug_panel = _panel("LEVEL-AUSWAHL (DEBUG)")
	_debug_panel.size = Vector2(800, 470)
	_debug_panel.position = (SCREEN - _debug_panel.size) * 0.5 + Vector2(0, 20)
	for i in range(debug_entries.size()):
		var entry: Dictionary = debug_entries[i]
		var button := _panel_button(_debug_panel, str(entry.label), Vector2(30 + (i % 2) * 375, 62 + (i / 2) * 40), Vector2(365, 34), func(): _pick_debug(entry))
		button.add_theme_font_size_override("font_size", 13)
	_panel_button(_debug_panel, "ZURÜCK", Vector2(30, 420), Vector2(740, 36), _close_panels)


func _open_debug() -> void:
	_close_panels()
	_debug_panel.visible = true


func _pick_debug(entry: Dictionary) -> void:
	_open_classes(bool(entry.endless))
	_debug_start = entry
	_class_title.text = "WÄHLE DEINEN HELDEN · " + str(entry.label)


## The pending debug jump, once; empty for normal starts.
func take_debug_start() -> Dictionary:
	var jump := _debug_start
	_debug_start = {}
	return jump


func _open_classes(endless: bool) -> void:
	_close_panels()
	_debug_start = {}
	_class_endless = endless
	_class_title.text = "WÄHLE DEINEN HELDEN · " + ("ENDLOS-MODUS" if endless else "STORY-MODUS")
	_class_panel.visible = true


func _choose_class(id: String) -> void:
	_close_panels()
	start_requested.emit(_class_endless, id)


# --- Options ----------------------------------------------------------------

func _build_options_panel() -> void:
	_options_panel = _panel("OPTIONEN")
	_panel_label(_options_panel, "Lautstärke", Vector2(30, 76)).size.x = 120
	_volume_slider = HSlider.new()
	_volume_slider.position = Vector2(160, 80)
	_volume_slider.size = Vector2(230, 24)
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 5
	_volume_slider.value_changed.connect(func(value: float): _set_setting("volume", int(value)))
	_options_panel.add_child(_volume_slider)
	_fullscreen_check = _check(_options_panel, "Vollbild", Vector2(30, 126), func(on: bool): _set_setting("fullscreen", on))
	_shake_check = _check(_options_panel, "Bildschirmwackeln", Vector2(30, 176), func(on: bool): _set_setting("shake", on))
	_panel_label(_options_panel, "Version " + str(ProjectSettings.get_setting("application/config/version", "0.0.0")), Vector2(30, 240)).add_theme_color_override("font_color", MUTED)
	_panel_button(_options_panel, "ZURÜCK", Vector2(30, 306), Vector2(360, 38), _close_panels)


func _open_options() -> void:
	_close_panels()
	_options_panel.visible = true
	_volume_slider.grab_focus()


func _set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	var file := ConfigFile.new()
	for name: String in settings: file.set_value("options", name, settings[name])
	file.save(SETTINGS_PATH)


func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		for name: String in settings: settings[name] = file.get_value("options", name, settings[name])
	_volume_slider.set_value_no_signal(float(settings.volume))
	_fullscreen_check.set_pressed_no_signal(bool(settings.fullscreen))
	_shake_check.set_pressed_no_signal(bool(settings.shake))
	_apply_settings()


func _apply_settings() -> void:
	var volume: float = clampf(float(settings.volume) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume) if volume > 0.0 else -80.0)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
	settings_changed.emit(settings)


# --- Widgets ----------------------------------------------------------------

func _close_panels() -> void:
	_login_panel.visible = false
	_options_panel.visible = false
	if _debug_panel != null: _debug_panel.visible = false
	if _class_panel != null: _class_panel.visible = false
	_password_input.text = ""
	_refresh_account()
	_buttons[0].grab_focus()


func _panel(title: String) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(420, 370)
	panel.position = (SCREEN - panel.size) * 0.5 + Vector2(0, 20)
	panel.add_theme_stylebox_override("panel", _style(Color("1a1d29"), GOLD))
	panel.visible = false
	add_child(panel)
	var heading := _panel_label(panel, title, Vector2(30, 20))
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", GOLD)
	return panel


func _panel_label(panel: Panel, text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(360, 26)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", TEXT)
	panel.add_child(label)
	return label


func _text_field(panel: Panel, placeholder: String, at: Vector2, secret: bool) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.secret = secret
	input.position = at
	input.size = Vector2(360, 40)
	input.add_theme_font_size_override("font_size", 16)
	panel.add_child(input)
	return input


func _check(panel: Panel, text: String, at: Vector2, callback: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.position = at
	check.size = Vector2(360, 36)
	check.add_theme_font_size_override("font_size", 15)
	check.toggled.connect(callback)
	panel.add_child(check)
	return check


func _panel_button(panel: Panel, text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := _make_button(text, dimensions, 15, callback)
	button.position = at
	panel.add_child(button)
	return button


func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, at: Vector2, dimensions: Vector2, font_size: int, callback: Callable) -> Button:
	var button := _make_button(text, dimensions, font_size, callback)
	button.position = at
	add_child(button)
	return button


func _make_button(text: String, dimensions: Vector2, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size = dimensions
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color("767d91"))
	button.add_theme_stylebox_override("normal", _style(Color(0.16, 0.17, 0.22, 0.92), Color("61523a")))
	button.add_theme_stylebox_override("hover", _style(Color("383846"), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color("383846"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("3e3a34"), Color("72dcc8")))
	button.add_theme_stylebox_override("disabled", _style(Color("222532"), Color("35394b")))
	button.pressed.connect(callback)
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style

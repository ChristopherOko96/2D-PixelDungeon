extends Control
## Title screen: Story mode on top, Endless below, then multiplayer, options and
## quit. A small pixel scene plays behind it (torch-lit wall, heroes chased by
## the crypt's undead). Top right shows the account (guest or signed-in e-mail)
## with the saved progress; bottom right the game version. Login and options open
## as panels over the menu. Owns no game state; it reports choices by signal and
## stores options in user://settings.cfg.
##
## Ported from origin/main (357d509). codex_v2 changes: Pixel Operator 8 sizes
## (multiples of 8), the account row hides without an account, the hero choice
## is skipped while `class_order` is empty, Endless can be shown as "coming soon",
## the window mode is left to the game (it owns fullscreen), and the scene fills
## any canvas size around the centered 1280x720 composition.

## A solo run with the chosen mode and hero class.
signal start_requested(endless: bool, class_id: String)
signal multiplayer_requested
signal quit_requested
signal settings_changed(settings: Dictionary)

const Progress = preload("res://src/online/progress.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const SCREEN := Vector2(1280, 720)
const SPRITE_ROOT := "res://assets/sprites/0x72/"
const HEROES := ["knight_m", "elf_f", "wizzard_m", "lizard_m"]
const CHASERS := ["skelet", "skelet", "necromancer"]
const PROPS_ROOT := "res://assets/sprites/crypt_props/"
## Backdrop tiles are 16 px 0x72 tiles drawn at 3x.
const TILE := 48.0
const SETTINGS_PATH := "user://settings.cfg"
const GOLD := CryptUI.GOLD
const MUTED := CryptUI.MUTED
const TEXT := CryptUI.BONE
const FLOOR_TOP := 592.0

## Set by the game before the menu enters the tree.
var account: Node
var classes: Dictionary = {}
var class_order: Array = []
var weapons: Dictionary = {}
## Debug level list: {label, endless, floor, room}; set by the game.
var debug_entries: Array = []
## False until the endless mode exists: the button is shown disabled.
var endless_available := true
var _endless_button: Button
## Story campaigns in menu order (assets/data/story_campaigns.json), set by the game.
var stories: Array = []
## The story picked for the next solo start; empty until a story card is chosen.
var selected_story := ""
var _story_panel: Panel
var _story_cards: Array[Button] = []
# The visible canvas around the centered composition (see set_canvas_size).
var _canvas_origin := Vector2.ZERO
var _canvas_size := SCREEN
var _debug_start: Dictionary = {}
var _debug_panel: Panel
var settings := {"volume": 80, "fullscreen": false, "shake": true}
# Starts mid-chase so the heroes are on screen from the first frame.
var _clock := 7.0
var _frames: Dictionary = {}
var _tiles: Dictionary = {}
var _torch: Array[Texture2D] = []
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
	position = _canvas_origin
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Inherits the game's Pixel Operator 8 theme; standalone use gets its own.
	if get_parent() == null or not (get_parent() is Control and (get_parent() as Control).theme != null):
		theme = CryptUI.create_theme()
	for name: String in HEROES + CHASERS:
		var run: Array = []
		for frame in range(4):
			run.append(load("%s%s_run_anim_f%d.png" % [SPRITE_ROOT, name, frame]))
		_frames[name] = run
	for tile: String in ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8", "wall_mid", "wall_top_mid", "wall_banner_red", "wall_banner_blue", "wall_hole_1"]:
		_tiles[tile] = load(SPRITE_ROOT + tile + ".png")
	for frame in range(8): _torch.append(load("%swall_torch_f%d.png" % [PROPS_ROOT, frame]))
	# The menu card: one framed column for the mode buttons.
	var card := Panel.new()
	card.position = Vector2(446, 184)
	card.size = Vector2(388, 308)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var title := _label(CryptUI.GAME_TITLE, Vector2(0, 52), Vector2(SCREEN.x, 90), 64, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", CryptUI.INK)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_shadow_color", CryptUI.BLOOD_DARK)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_offset_x", 0)
	_label("STEIG HINAB. ÜBERLEBE DIE KRYPTA.", Vector2(0, 146), Vector2(SCREEN.x, 28), 16, CryptUI.SAND, HORIZONTAL_ALIGNMENT_CENTER)
	_buttons.append(_button("STORY-MODUS", Vector2(470, 204), Vector2(340, 62), 32, _open_stories))
	_endless_button = _button("ENDLOS-MODUS" if endless_available else "ENDLOS · BALD", Vector2(470, 278), Vector2(340, 48), 24, _open_classes.bind(true))
	_endless_button.disabled = not endless_available
	_endless_button.tooltip_text = "" if endless_available else "Der Endlos-Modus folgt in einem späteren Schritt."
	_buttons.append(_endless_button)
	_buttons.append(_button("MEHRSPIELER", Vector2(470, 338), Vector2(340, 44), 16, multiplayer_requested.emit))
	_buttons.append(_button("OPTIONEN", Vector2(470, 390), Vector2(340, 44), 16, _open_options))
	_buttons.append(_button("BEENDEN", Vector2(470, 442), Vector2(340, 36), 16, quit_requested.emit))
	_button("LEVEL-AUSWAHL (DEBUG)", Vector2(16, 676), Vector2(264, 32), 16, _open_debug)
	_buttons[0].add_theme_color_override("font_color", GOLD)
	_buttons[0].grab_focus()
	_account_label = _label("", Vector2(820, 20), Vector2(300, 22), 16, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_progress_label = _label("", Vector2(620, 44), Vector2(500, 20), 16, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_account_button = _button("ANMELDEN", Vector2(1132, 18), Vector2(124, 44), 16, _on_account_button)
	# Without online accounts the whole account row stays hidden.
	for node: Control in [_account_label, _progress_label, _account_button]: node.visible = account != null
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if not version.is_empty():
		_label("v" + version, Vector2(1080, 690), Vector2(184, 20), 16, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_toast = _label("", Vector2(0, 520), Vector2(SCREEN.x, 24), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_build_login_panel()
	_build_options_panel()
	_build_story_panel()
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


## Centers the 1280x720 composition on the visible canvas; the background scene
## fills the whole canvas. `origin` is the composition's top-left on the canvas.
func set_canvas_size(dimensions: Vector2, origin: Vector2) -> void:
	_canvas_size = dimensions
	_canvas_origin = origin
	position = origin
	queue_redraw()


## Mirrors the game's real window mode in the options (F11 can change it too).
func set_fullscreen_checked(on: bool) -> void:
	settings.fullscreen = on
	if _fullscreen_check != null: _fullscreen_check.set_pressed_no_signal(on)


# --- Pixel scene ------------------------------------------------------------

func _draw() -> void:
	# The visible canvas in local coordinates; wider screens extend the scene.
	var canvas := Rect2(-_canvas_origin, _canvas_size)
	draw_rect(canvas, CryptUI.INK)
	# 0x72 crypt wall (top edge, two brick rows) with banners and torches, then
	# the floor the chase runs across, fading into the dark.
	var first := floori(canvas.position.x / TILE) - 1
	var wall_top := FLOOR_TOP - TILE * 2.0
	for column in range(first, ceili(canvas.end.x / TILE) + 1):
		var x := column * TILE
		var tint := Color(0.62, 0.58, 0.58)
		draw_texture_rect(_tiles.wall_top_mid, Rect2(x, wall_top, TILE, TILE), false, tint)
		var feature := posmod(column, 6)
		var brick: Texture2D = _tiles.wall_banner_red if feature == 1 else _tiles.wall_banner_blue if feature == 4 else _tiles.wall_hole_1 if posmod(column, 11) == 7 else _tiles.wall_mid
		draw_texture_rect(brick, Rect2(x, wall_top + TILE, TILE, TILE), false, tint)
		for row in range(4):
			var shade := 0.72 - row * 0.15
			var variant: Texture2D = _tiles["floor_%d" % (1 + posmod(column * 7 + row * 3, 8))] if posmod(column + row * 5, 4) == 0 else _tiles.floor_1
			draw_texture_rect(variant, Rect2(x, FLOOR_TOP + row * TILE, TILE, TILE), false, Color(shade, shade * 0.95, shade * 0.95))
	if canvas.end.y > FLOOR_TOP + TILE * 4.0:
		draw_rect(Rect2(canvas.position.x, FLOOR_TOP + TILE * 4.0, canvas.size.x, canvas.end.y - FLOOR_TOP - TILE * 4.0), CryptUI.INK)
	var torch_frame := int(_clock * 10.0) % _torch.size()
	var first_torch := floori(canvas.position.x / (TILE * 6.0)) - 1
	for index in range(first_torch, ceili(canvas.end.x / (TILE * 6.0)) + 1):
		var torch := Vector2(index * TILE * 6.0 + TILE * 3.0, wall_top + TILE * 0.9)
		var flicker := sin(_clock * 7.0 + index * 1.7)
		draw_circle(torch + Vector2(0, 20), 120.0, Color(1.0, 0.55, 0.25, 0.05 + 0.012 * flicker))
		draw_circle(torch + Vector2(0, 20), 60.0, Color(1.0, 0.6, 0.3, 0.07 + 0.02 * flicker))
		draw_texture_rect(_torch[torch_frame], Rect2(torch - Vector2(24, 24), Vector2(48, 72)), false)
	# The chase: four heroes run right, skeletons and a necromancer on their heels.
	var lead := canvas.position.x + fmod(_clock * 95.0, canvas.size.x + 760.0) - 300.0
	for index in range(HEROES.size()):
		_draw_runner(HEROES[index], lead - index * 70.0, index)
	for index in range(CHASERS.size()):
		_draw_runner(CHASERS[index], lead - 400.0 - index * 62.0, index + 4)
	# Dust motes drifting up through the torchlight.
	for index in range(26):
		var x := canvas.position.x + fmod(index * 197.0 + sin(_clock * 0.4 + index) * 30.0, canvas.size.x)
		var y := fmod(700.0 - _clock * (8.0 + index % 5 * 3.0) - index * 61.0, 720.0)
		if y < 0.0: y += 720.0
		draw_rect(Rect2(roundf(x), roundf(y), 2, 2), Color(0.95, 0.78, 0.6, 0.12 + 0.08 * sin(_clock * 1.5 + index)))
	# Darken the top so the title reads; taller screens get the darkest band above.
	if canvas.position.y < 0.0:
		draw_rect(Rect2(canvas.position.x, canvas.position.y, canvas.size.x, -canvas.position.y), Color(CryptUI.INK, 0.85))
	for band in range(10):
		draw_rect(Rect2(canvas.position.x, band * 24.0, canvas.size.x, 24), Color(CryptUI.INK, 0.85 - band * 0.08))


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
	_login_status.add_theme_font_size_override("font_size", 16)
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
## Story choice: one card per campaign, numbered; locked stories show BALD.
func _build_story_panel() -> void:
	_story_panel = _panel("WÄHLE DEINE STORY")
	_story_panel.size = Vector2(800, 470)
	_story_panel.position = (SCREEN - _story_panel.size) * 0.5 + Vector2(0, 20)
	_story_cards.clear()
	for i in range(stories.size()):
		var story: Dictionary = stories[i]
		var playable := bool(story.get("playable", false))
		var card := _panel_button(_story_panel, "", Vector2(30, 62 + i * 112), Vector2(740, 102), func(): _choose_story(str(story.id)))
		card.disabled = not playable
		_story_cards.append(card)
		var lines := [["STORY %d" % int(story.get("number", i + 1)), 16, MUTED, Vector2(20, 12)],
			[str(story.get("title", "")), 24, GOLD if playable else MUTED, Vector2(20, 34)],
			[str(story.get("subtitle", "")) if playable else "BALD · " + str(story.get("subtitle", "")), 16, TEXT if playable else MUTED, Vector2(20, 70)]]
		for line: Array in lines:
			var label := Label.new()
			label.text = line[0]
			label.position = line[3]
			label.size = Vector2(700, 26)
			label.add_theme_font_size_override("font_size", line[1])
			label.add_theme_color_override("font_color", line[2])
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(label)
	_panel_button(_story_panel, "ZURÜCK", Vector2(30, 420), Vector2(740, 36), _close_panels)


func _open_stories() -> void:
	_close_panels()
	_story_panel.visible = true
	for card: Button in _story_cards:
		if not card.disabled:
			card.grab_focus()
			break


func _choose_story(id: String) -> void:
	selected_story = id
	_open_classes(false)
	for story: Dictionary in stories:
		if str(story.id) == id: _class_title.text = "WÄHLE DEINEN HELDEN · STORY %d" % int(story.get("number", 1))


func _build_class_panel() -> void:
	_class_panel = Panel.new()
	# Taller than on main: Pixel Operator 8 at 16 px needs more room per line.
	_class_panel.size = Vector2(800, 496)
	_class_panel.position = (SCREEN - _class_panel.size) * 0.5 + Vector2(0, 20)
	_class_panel.add_theme_stylebox_override("panel", CryptUI.box("panel"))
	_class_panel.visible = false
	add_child(_class_panel)
	_class_title = _panel_label(_class_panel, "WÄHLE DEINEN HELDEN", Vector2(30, 18))
	_class_title.size.x = 740
	_class_title.add_theme_font_size_override("font_size", 24)
	_class_title.add_theme_color_override("font_color", GOLD)
	for i in range(class_order.size()):
		var id: String = str(class_order[i])
		var hero: Dictionary = classes[id]
		var card := _make_button("", Vector2(236, 370), 16, func(): _choose_class(id))
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
		# 0x72 figure at 3x (48x84) leaves room for 16 px text below.
		picture.size = Vector2(48, 84)
		picture.position = Vector2(94, 10)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		_class_heroes.append(picture)
		var weapon: Dictionary = weapons.get(str(hero.weapon), {})
		# The hero's numbers, so the choice is informed: hearts, weapon and how it hits.
		var reach: String = ("NAHKAMPF %d" % int(weapon.get("reach", 0))) if str(weapon.get("type", "")) == "melee" else ("REICHWEITE %.1f" % (float(weapon.get("speed", 0)) * float(weapon.get("life", 0)) / 100.0))
		# One fact per line: 16 px Pixel Operator 8 fits about 20 characters per card.
		var damage: float = float(weapon.get("damage", 0))
		var damage_text: String = str(int(damage)) if is_equal_approx(damage, roundf(damage)) else "%.1f" % damage
		var lines := [[str(hero.name), 16, GOLD, 100, 22], [str(hero.description), 16, TEXT, 124, 120],
			["%d HERZEN\n%s" % [ceili(float(hero.hp) / 2.0), str(weapon.get("name", ""))], 16, Color("ef8a9a"), 248, 40],
			["SCHADEN %s\n%.1f ANGRIFFE/S\n%s\nTEMPO %d" % [damage_text, 1.0 / maxf(float(weapon.get("interval", 1.0)), 0.01), reach, int(hero.speed)], 16, MUTED, 290, 80]]
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
			label.size = Vector2(212, line[4])
	_panel_button(_class_panel, "ZURÜCK", Vector2(30, 444), Vector2(740, 38), _close_panels)


## Debug: every level as a button; a pick goes through the hero choice and
## then starts right there.
func _build_debug_panel() -> void:
	_debug_panel = _panel("LEVEL-AUSWAHL (DEBUG)")
	_debug_panel.size = Vector2(800, 470)
	_debug_panel.position = (SCREEN - _debug_panel.size) * 0.5 + Vector2(0, 20)
	for i in range(debug_entries.size()):
		var entry: Dictionary = debug_entries[i]
		var button := _panel_button(_debug_panel, str(entry.label), Vector2(30 + (i % 2) * 375, 62 + (i / 2) * 40), Vector2(365, 34), func(): _pick_debug(entry))
		button.add_theme_font_size_override("font_size", 16)
	_panel_button(_debug_panel, "ZURÜCK", Vector2(30, 420), Vector2(740, 36), _close_panels)


func _open_debug() -> void:
	_close_panels()
	_debug_panel.visible = true


func _pick_debug(entry: Dictionary) -> void:
	if class_order.is_empty():
		# No hero classes yet: start the picked level straight away.
		_close_panels()
		_debug_start = entry
		start_requested.emit(bool(entry.endless), "")
		return
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
	if class_order.is_empty():
		# No hero classes yet: the mode button starts the run directly.
		start_requested.emit(endless, "")
		return
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
	_volume_slider.position = Vector2(210, 80)
	_volume_slider.size = Vector2(180, 24)
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 5
	_volume_slider.value_changed.connect(func(value: float): _set_setting("volume", int(value)))
	_options_panel.add_child(_volume_slider)
	_fullscreen_check = _check(_options_panel, "Vollbild", Vector2(30, 126), func(on: bool): _set_setting("fullscreen", on))
	_shake_check = _check(_options_panel, "Bildschirmwackeln", Vector2(30, 176), func(on: bool): _set_setting("shake", on))
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if not version.is_empty():
		_panel_label(_options_panel, "Version " + version, Vector2(30, 240)).add_theme_color_override("font_color", MUTED)
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
	# The game applies `fullscreen` with its own toggle, which keeps the window rect.
	settings_changed.emit(settings)


# --- Widgets ----------------------------------------------------------------

func _close_panels() -> void:
	_login_panel.visible = false
	_options_panel.visible = false
	if _debug_panel != null: _debug_panel.visible = false
	if _class_panel != null: _class_panel.visible = false
	if _story_panel != null: _story_panel.visible = false
	_password_input.text = ""
	_refresh_account()
	_buttons[0].grab_focus()


func _panel(title: String) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(420, 370)
	panel.position = (SCREEN - panel.size) * 0.5 + Vector2(0, 20)
	panel.add_theme_stylebox_override("panel", CryptUI.box("panel"))
	panel.visible = false
	add_child(panel)
	var heading := _panel_label(panel, title, Vector2(30, 20))
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", GOLD)
	return panel


func _panel_label(panel: Panel, text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(360, 26)
	label.add_theme_font_size_override("font_size", 16)
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
	check.add_theme_font_size_override("font_size", 16)
	check.toggled.connect(callback)
	panel.add_child(check)
	return check


func _panel_button(panel: Panel, text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := _make_button(text, dimensions, 16, callback)
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
	# Frames and colours come from the shared crypt theme (CryptUI).
	button.pressed.connect(callback)
	return button


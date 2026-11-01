extends Control
## Title screen: SPIELEN (story choice; each story card offers FORTSETZEN · ETAGE n
## when its world has a save and NEU for the hero choice), TALENTE, OPTIONEN and
## BEENDEN. The small DEBUG corner (debug builds) opens the hub with the level
## choice, Testraum, talent test, Klangwerkstatt, EDITOR, the old crypt lobby
## (MEHRSPIELER) and the save slots. A small pixel scene plays behind it (torch-lit
## wall, heroes chased by the crypt's undead). Every panel dims the scene and hides
## the title card; Esc / Pad-B (ui_cancel) goes back one level (go_back). Top right
## shows the account (guest or signed-in e-mail) with the saved progress; bottom
## right the game version. Owns no game state; it reports choices by signal and
## stores options in user://settings.cfg.
##
## Ported from origin/main (357d509). codex_v2 changes: Pixel Operator 8 sizes
## (multiples of 8), the account row hides without an account, the hero choice
## is skipped while `class_order` is empty, the window mode is left to the game
## (it owns fullscreen), and the scene fills any canvas size around the centered
## 1280x720 composition.

## A solo run with the chosen mode and hero class.
signal start_requested(endless: bool, class_id: String)
signal multiplayer_requested
## Debug level choice: start a story world's scene (story "scene" in story_campaigns.json)
## with the picked hero on that floor, at its entrance, or right in its boss room when
## boss is true (src/hell/hell_game.gd start_floor / start_at_boss).
signal story_floor_requested(scene_path: String, class_id: String, floor_number: int, boss: bool)
## The player picked a hero for a story that runs in its own scene (story "scene" in story_campaigns.json).
signal story_scene_requested(scene_path: String, class_id: String)
signal quit_requested
## The talent build changed (the game resends it to the host in multiplayer).
signal talents_changed
signal settings_changed(settings: Dictionary)
## The Dungeon-Werkstatt saved the room library; the game uses `config` now.
signal rooms_saved(config: Dictionary)
## The Dungeon-Werkstatt asks to test-play a room.
signal room_test_requested(room_id: String, floor: int, class_id: String)
## Debug: the old crypt Testraum (src/game.gd start_test_arena). The DEBUG hub no longer
## emits it: its TESTRAUM opens the story Testraum (src/debug/story_testraum.gd).
signal test_arena_requested(class_id: String)
## FORTSETZEN on a story card or LADEN in the debug saves: load slot 1..3 of a mode
## ("krypta", "frost", "hell"; "crypt" = the old endless run).
signal save_load_requested(mode: String, slot: int)

const SaveStore = preload("res://src/save/save_store.gd")
const StorySave = preload("res://src/save/story_save.gd")
## The save tabs in story order (the endless tab left with the mode).
const SAVE_MODES := ["krypta", "frost", "hell"]
const Progress = preload("res://src/online/progress.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const TalentScreen = preload("res://src/ui/talent_screen.gd")
const Profile = preload("res://src/progress/profile.gd")
const AudioMix = preload("res://src/audio/audio_mix.gd")
const SoundWorkshop = preload("res://src/ui/sound_workshop.gd")
const RoomEditor = preload("res://src/editor/room_editor.gd")
const ElementSkin = preload("res://src/hero/element_skin.gd")
const SCREEN := Vector2(1280, 720)
const SPRITE_ROOT := "res://assets/sprites/0x72/"
## The chase's heroes; the mage is the 0x72 wizard, recoloured by his element (src/hero/element_skin.gd).
const HEROES := ["knight_m", "elf_f", "wizzard_m", "lizard_m"]
const CHASERS := ["skelet", "skelet", "necromancer"]
const PROPS_ROOT := "res://assets/sprites/crypt_props/"
## Backdrop tiles are 16 px 0x72 tiles drawn at 3x.
const TILE := 48.0
const GraphicsSettings = preload("res://src/core/graphics_settings.gd")
## The one options file of the game (src/core/graphics_settings.gd SETTINGS_PATH).
const SETTINGS_PATH: String = GraphicsSettings.SETTINGS_PATH
## The same options page as the pause (src/ui/options_panel.gd).
const OptionsPanel = preload("res://src/ui/options_panel.gd")
const GOLD := CryptUI.GOLD
const MUTED := CryptUI.MUTED
const TEXT := CryptUI.BONE
const FLOOR_TOP := 592.0

## Set by the game before the menu enters the tree.
var account: Node
var classes: Dictionary = {}
var class_order: Array = []
var weapons: Dictionary = {}
## Jumps into the old crypt run: {label, endless, floor, room}; set by the game. No longer
## listed in the level choice (the old crypt is obsolete); kept for _pick_debug callers.
var debug_entries: Array = []
## The story worlds of the level choice, in menu order; set by the game (game.gd _story_worlds):
## {id, title, scene, floors: [{floor, title, boss, mini, final}]}.
var story_worlds: Array = []
## The debug floor start waiting for the hero choice: {scene, floor, boss}; empty otherwise.
var _story_jump: Dictionary = {}
## The hero cards of the hero choice by class id, set by the game (game.gd _hero_cards):
## {name, sprite, role, hp, resource, kind, paths: [{name, color}]}; a class without one
## falls back to `classes` (the old crypt balance).
var hero_cards: Dictionary = {}
## Colour of the resource line on a hero card by resource kind (talents.json resources).
const RESOURCE_COLORS := {"mana": Color("8fb8ff"), "stamina": Color("e8d27a"), "rage": Color("ef6a5a")}
## Story campaigns in menu order (assets/data/story_campaigns.json), set by the game.
var stories: Array = []
## The story picked for the next solo start; empty until a story card is chosen.
var selected_story := ""
var _story_panel: Panel
## TALENTE: soul crystals and the talent trees (src/hell/meta_store.gd).
var _talent_panel: Panel
var _talent_screen: Control
## The run's lasting profile (src/progress/run_progress.gd), set by the game.
var progress: RefCounted
var _talent_class := "mage"
var talent_data: Dictionary = {}
var talent_store: Dictionary = {}
## Where the talents are saved (tests use their own file).
var talent_path := MetaStore.SAVE_PATH
## The story cards (panels) in story order; playable ones hold NEU and FORTSETZEN.
var _story_cards: Array[Control] = []
## Story id -> its NEU button (hero choice) and its FORTSETZEN button (newest save).
var _story_new: Dictionary = {}
var _story_continue: Dictionary = {}
## Story id -> the save FORTSETZEN loads: {mode, slot, floor, saved_at, text}.
var _story_resume: Dictionary = {}
var _story_back: Button
## The title card, game title and tagline: hidden while a panel is open.
var _title_nodes: Array[Control] = []
var _debug_button: Button
var _hub_buttons: Array[Button] = []
## The first world of the level choice (focused on open).
var _debug_first: Button
var _class_cards: Array[Button] = []
var _class_back_button: Button
## The hero choice's context line (story, Testraum or debug floor).
var _class_hint: Label
## The difficulty switch of the hero choice (profile "difficulty").
var _difficulty_button: Button
## True while the hero choice was opened from a story card (back leads there).
var _class_from_story := false
# The visible canvas around the centered composition (see set_canvas_size).
var _canvas_origin := Vector2.ZERO
var _canvas_size := SCREEN
var _debug_start: Dictionary = {}
## DEBUG hub (debug builds): level choice, Testraum, talent test, Klangwerkstatt.
var _hub_panel: Panel
## Darkens the menu behind every panel so it reads well (debug panels: user wish
## 2026-10-31; every panel since the UX review of 2026-11-01).
var _debug_dim: ColorRect
## How dark the dim behind the panels is (0 clear .. 1 black).
const DEBUG_DIM_ALPHA := 0.62
var _debug_panel: Panel
## The floor list of each story world by world id (see story_worlds).
var _world_panels: Dictionary = {}
## The mage's frames as loaded ("run" of the chase, "idle" of his class card), before
## the element skin (src/hero/element_skin.gd) recolours them.
var _mage_frames: Dictionary = {}
var settings := {"volume": 80, "music": 70, "effects": 85, "fullscreen": false, "shake": true, "camera_calm": false, "graphics": "pixel"}
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
## The shared options page inside _options_panel.
var _options: Control
var _volume_slider: HSlider
## Volume sliders by setting key ("volume", "music", "effects").
var _sliders: Dictionary = {}
## Klangwerkstatt (debug menu), made when first opened.
var sound_workshop: Control
## Dungeon-Werkstatt (main menu EDITOR), made when first opened.
var room_editor: Control
var _fullscreen_check: CheckButton
## Pixel / HD graphics for every world (src/core/graphics_settings.gd).
var _graphics_check: CheckButton
var _shake_check: CheckButton
var _class_panel: Panel
var _class_title: Label
var _class_endless := false
## True while the hero choice is for the Testraum.
var _arena_pick := false
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
	# The menu card: one framed column for the four title entries.
	var card := Panel.new()
	card.position = Vector2(446, 190)
	card.size = Vector2(388, 284)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var title := _label(CryptUI.GAME_TITLE, Vector2(0, 52), Vector2(SCREEN.x, 90), 64, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", CryptUI.INK)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_shadow_color", CryptUI.BLOOD_DARK)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_offset_x", 0)
	var tagline := _label("STEIG HINAB. ÜBERLEBE DIE KRYPTA.", Vector2(0, 146), Vector2(SCREEN.x, 28), 16, CryptUI.SAND, HORIZONTAL_ALIGNMENT_CENTER)
	_title_nodes.append_array([card, title, tagline])
	# Only the player's entries (UX review 2026-11-01): Endlos waits until it exists;
	# Mehrspieler, Editor and the save slots live in the DEBUG hub.
	_buttons.append(_button("SPIELEN", Vector2(470, 210), Vector2(340, 64), 32, _open_stories))
	_buttons.append(_button("TALENTE", Vector2(470, 290), Vector2(340, 48), 24, _open_talents))
	_buttons.append(_button("OPTIONEN", Vector2(470, 348), Vector2(340, 48), 24, _open_options))
	_buttons.append(_button("BEENDEN", Vector2(470, 406), Vector2(340, 48), 24, quit_requested.emit))
	# the DEBUG hub (debug builds only): one button bottom-left opens the panel with the
	# level choice, the Testraum, the talent test, the workshops, the old lobby and the saves
	_debug_button = _button("DEBUG", Vector2(16, 676), Vector2(140, 32), 16, _open_debug_hub)
	_debug_button.visible = OS.is_debug_build()
	var title_focus: Array = []
	title_focus.append_array(_buttons)
	if _debug_button.visible: title_focus.append(_debug_button)
	_chain_focus(title_focus)
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
	# the dim lies over the menu and under every panel built after it
	_debug_dim = ColorRect.new()
	_debug_dim.color = Color(CryptUI.INK, DEBUG_DIM_ALPHA)
	_debug_dim.position = Vector2(-2000, -2000)
	_debug_dim.size = SCREEN + Vector2(4000, 4000)
	_debug_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_dim.visible = false
	add_child(_debug_dim)
	_build_login_panel()
	_build_options_panel()
	_build_story_panel()
	_build_class_panel()
	_build_debug_hub()
	_build_debug_panel()
	_build_saves_panel()
	_apply_mage_skin()
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
	_sync_title()
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
	_show_panel(_login_panel)
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


# --- Story and hero choice ---------------------------------------------------

## Story choice: one card per campaign, numbered. A playable card holds NEU (the hero
## choice) and, when its world has a save, FORTSETZEN · ETAGE n above it (the newest of
## its slots, see _refresh_story_saves); locked stories say BALD VERFÜGBAR.
func _build_story_panel() -> void:
	_story_panel = _panel("WÄHLE DEINE STORY")
	# the panel grows with the stories; past four the cards get flatter so all still fit
	var step := 112.0 if stories.size() <= 4 else 448.0 / stories.size()
	_story_panel.size = Vector2(1100, 62.0 + stories.size() * step + 52.0)
	_story_panel.position = (SCREEN - _story_panel.size) * 0.5 + Vector2(0, 20)
	_story_cards.clear()
	_story_new.clear()
	_story_continue.clear()
	for i in range(stories.size()):
		var story: Dictionary = stories[i]
		var id := str(story.id)
		var playable := bool(story.get("playable", false))
		var card := Panel.new()
		card.position = Vector2(30, 62 + i * step)
		card.size = Vector2(1040, step - 10.0)
		card.add_theme_stylebox_override("panel", CryptUI.box("inset"))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_story_panel.add_child(card)
		_story_cards.append(card)
		var lines := [["STORY %d" % int(story.get("number", i + 1)), 16, MUTED, Vector2(20, 12)],
			[str(story.get("title", "")), 24, GOLD if playable else MUTED, Vector2(20, 34)],
			[str(story.get("subtitle", "")) if playable else "BALD VERFÜGBAR · " + str(story.get("subtitle", "")), 16, TEXT if playable else MUTED, Vector2(20, 70)]]
		for line: Array in lines:
			var label := Label.new()
			label.text = line[0]
			label.position = line[3]
			# playable cards keep their right side for the buttons
			label.size = Vector2(700 if playable else 1000, 26)
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.add_theme_font_size_override("font_size", line[1])
			label.add_theme_color_override("font_color", line[2])
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(label)
		if not playable:
			continue
		var half := (card.size.y - 26.0) * 0.5
		var resume := _make_button("", Vector2(280, half), 16, _continue_story.bind(id))
		resume.position = Vector2(740, 12)
		resume.add_theme_color_override("font_color", GOLD)
		card.add_child(resume)
		_story_continue[id] = resume
		var fresh := _make_button("NEU", Vector2(280, half), 16, _choose_story.bind(id))
		fresh.position = Vector2(740, 16 + half)
		card.add_child(fresh)
		_story_new[id] = fresh
	_story_back = _panel_button(_story_panel, "ZURÜCK", Vector2(30, 62.0 + stories.size() * step + 6.0), Vector2(1040, 36), _close_panels)
	_refresh_story_saves()


## FORTSETZEN · ETAGE n on every story card whose world has a save (the newest of its
## slots), NEU alone in the middle otherwise; links the card buttons for keys and pad.
func _refresh_story_saves() -> void:
	_story_resume.clear()
	var order: Array = []
	for story: Dictionary in stories:
		var id := str(story.id)
		if not _story_new.has(id):
			continue
		var resume: Button = _story_continue[id]
		var fresh: Button = _story_new[id]
		var found := _latest_save(_save_mode_of(story))
		resume.visible = not found.is_empty()
		resume.focus_mode = Control.FOCUS_ALL if resume.visible else Control.FOCUS_NONE
		var card_h: float = (fresh.get_parent() as Control).size.y
		fresh.position.y = resume.position.y + resume.size.y + 4.0 if resume.visible else (card_h - fresh.size.y) * 0.5
		if resume.visible:
			_story_resume[id] = found
			resume.text = "FORTSETZEN · ETAGE %d" % int(found.floor)
			resume.tooltip_text = str(found.text)
			order.append(resume)
		order.append(fresh)
	if _story_back != null: order.append(_story_back)
	_chain_focus(order)


## The newest save of a story mode: {mode, slot, floor, saved_at, text}; empty without one.
func _latest_save(mode: String) -> Dictionary:
	var best := {}
	if mode.is_empty():
		return best
	for slot in range(1, SaveStore.SLOTS + 1):
		var data: Dictionary = saves.read(mode, slot)
		if data.is_empty():
			continue
		if best.is_empty() or int(data.get("saved_at", 0)) > int(best.saved_at):
			best = {"mode": mode, "slot": slot, "floor": int(data.get("floor", 1)), "saved_at": int(data.get("saved_at", 0)), "text": SaveStore.describe(data)}
	return best


## A story's save mode: the world_id of the theme its scene runs (src/save/story_save.gd
## world_of_scene, the same id the world saves under); "" without a scene.
static func _save_mode_of(story: Dictionary) -> String:
	return StorySave.world_of_scene(str(story.get("scene", "")))


## FORTSETZEN on a story card: loads that world's newest save (as LADEN does in the saves).
func _continue_story(id: String) -> void:
	var found: Dictionary = _story_resume.get(id, {})
	if found.is_empty():
		return
	selected_story = id
	_close_panels()
	save_load_requested.emit(str(found.mode), int(found.slot))


func _open_stories() -> void:
	_refresh_story_saves()
	# focus the card the player came from, else the first playable one
	var focus: Control = _story_back
	for story: Dictionary in stories:
		var id := str(story.id)
		if not _story_new.has(id):
			continue
		var resume: Button = _story_continue[id]
		var pick: Control = resume if resume.visible else _story_new[id]
		if focus == _story_back or id == selected_story:
			focus = pick
		if id == selected_story:
			break
	_show_panel(_story_panel, focus)


## NEU on a story card: the hero choice for that story.
func _choose_story(id: String) -> void:
	selected_story = id
	var hint := ""
	for story: Dictionary in stories:
		if str(story.id) == id: hint = "STORY %d · %s" % [int(story.get("number", 1)), str(story.get("title", ""))]
	_open_classes(false, hint)
	_class_from_story = true


## The hero choice: one card per class (animated figure, name, role, LP, resource and the
## talent paths, from hero_cards), the difficulty switch top right and ZURÜCK. Keys and
## pad move between the cards; Enter / A picks the focused hero.
func _build_class_panel() -> void:
	_class_panel = Panel.new()
	# four heroes side by side (the necromancer joined on 29.10.2026)
	_class_panel.size = Vector2(1004, 480)
	_class_panel.position = (SCREEN - _class_panel.size) * 0.5
	_class_panel.add_theme_stylebox_override("panel", CryptUI.box("panel"))
	_class_panel.visible = false
	add_child(_class_panel)
	_class_title = _panel_label(_class_panel, "WÄHLE DEINEN HELDEN", Vector2(30, 18))
	_class_title.size.x = 620
	_class_title.add_theme_font_size_override("font_size", 24)
	_class_title.add_theme_color_override("font_color", GOLD)
	_class_hint = _panel_label(_class_panel, "", Vector2(30, 52))
	_class_hint.size = Vector2(620, 22)
	_class_hint.clip_text = true
	_class_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_class_hint.add_theme_color_override("font_color", MUTED)
	_difficulty_button = _panel_button(_class_panel, "", Vector2(674, 16), Vector2(300, 40), _cycle_difficulty)
	_class_cards.clear()
	for i in range(class_order.size()):
		var id: String = str(class_order[i])
		var hero: Dictionary = classes.get(id, {})
		var info: Dictionary = hero_cards.get(id, {})
		var card := _make_button("", Vector2(230, 316), 16, _choose_class.bind(id))
		card.position = Vector2(30 + i * 240, 84)
		_class_panel.add_child(card)
		_class_cards.append(card)
		var frames: Array = []
		# a class with an element skin shows the skin's figure (the mage: the wizard), else its own sprite
		var sprite := ElementSkin.source(id) if not ElementSkin.source(id).is_empty() else str(info.get("sprite", hero.get("sprite", "")))
		for frame in range(4):
			frames.append(load("%s%s_idle_anim_f%d.png" % [SPRITE_ROOT, sprite, frame]))
		_class_frames.append(frames)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 0x72 figure at 3x (48x84) leaves room for 16 px text below.
		picture.size = Vector2(48, 84)
		picture.position = Vector2(91, 10)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		_class_heroes.append(picture)
		# Short lines that fit the card at 16 px: name, role, LP, resource, then the paths.
		var lines: Array = [[str(info.get("name", hero.get("name", id.to_upper()))), GOLD, 100, 22]]
		if info.is_empty():
			lines.append([str(hero.get("description", "")), TEXT, 126, 120])
		else:
			lines.append([str(info.get("role", "")), TEXT, 126, 22])
			lines.append(["%d LP" % int(info.get("hp", 0)), Color("ef8a9a"), 150, 22])
			lines.append([str(info.get("resource", "")), RESOURCE_COLORS.get(str(info.get("kind", "")), TEXT), 174, 22])
			var paths: Array = info.get("paths", [])
			if not paths.is_empty():
				lines.append(["PFADE", MUTED, 206, 22])
			for p in range(paths.size()):
				lines.append([str(paths[p].name), Color(str(paths[p].color)), 230 + p * 24, 22])
		for line: Array in lines:
			var label := Label.new()
			label.text = line[0]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if int(line[3]) > 22:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				label.clip_text = true
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", line[1])
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Lies over the card on the panel (clicks pass through to the card).
			_class_panel.add_child(label)
			label.position = card.position + Vector2(12, float(line[2]))
			label.size = Vector2(206, float(line[3]))
	_class_back_button = _panel_button(_class_panel, "ZURÜCK", Vector2(30, 420), Vector2(944, 38), _class_back)
	# keys and pad: left/right between the cards, up to the difficulty, down to ZURÜCK
	for i in range(_class_cards.size()):
		var hero_card := _class_cards[i]
		var left := _class_cards[maxi(i - 1, 0)]
		var right := _class_cards[mini(i + 1, _class_cards.size() - 1)]
		hero_card.focus_neighbor_left = hero_card.get_path_to(left)
		hero_card.focus_neighbor_right = hero_card.get_path_to(right)
		hero_card.focus_neighbor_bottom = hero_card.get_path_to(_class_back_button)
		hero_card.focus_previous = hero_card.get_path_to(left)
		hero_card.focus_next = hero_card.get_path_to(right if i < _class_cards.size() - 1 else _class_back_button)
	if not _class_cards.is_empty():
		_class_back_button.focus_neighbor_top = _class_back_button.get_path_to(_class_cards[0])
		_class_back_button.focus_neighbor_bottom = _class_back_button.get_path_to(_class_back_button)
		_difficulty_button.focus_neighbor_bottom = _difficulty_button.get_path_to(_class_cards[0])
		_difficulty_button.focus_neighbor_top = _difficulty_button.get_path_to(_difficulty_button)
	_refresh_difficulty()


## The DEBUG hub (debug builds): the level choice, the Testraum (src/debug/story_testraum.gd:
## one room of a story world with every monster, boss and NPC of Krypta, Frostgruft and
## Hölle, elements, classes and cheats), the talent test profile (every class level 30, 99
## shards; casts cost mana as in a real run), the Klangwerkstatt, the Dungeon-Werkstatt
## (EDITOR), the old crypt lobby (MEHRSPIELER) and the save slots. The sub-panels' ZURÜCK
## and Esc lead back here.
func _build_debug_hub() -> void:
	_hub_panel = _panel("DEBUG")
	var entries := [["LEVEL-AUSWAHL", _open_debug], ["TESTRAUM", _open_arena], ["", _toggle_talent_test],
		["KLANGWERKSTATT", open_sound_workshop], ["EDITOR", open_room_editor.bind("")],
		["MEHRSPIELER (ALT)", _open_multiplayer], ["SPIELSTÄNDE", _open_saves]]
	_hub_panel.size = Vector2(420, 66 + entries.size() * 46 + 76)
	_hub_panel.position = (SCREEN - _hub_panel.size) * 0.5 + Vector2(0, 20)
	_hub_buttons.clear()
	for i in range(entries.size()):
		_hub_buttons.append(_panel_button(_hub_panel, str(entries[i][0]), Vector2(30, 66 + i * 46), Vector2(360, 40), entries[i][1]))
	_talent_test_button = _hub_buttons[2]
	_refresh_talent_test()
	_hub_buttons.append(_panel_button(_hub_panel, "ZURÜCK", Vector2(30, 66 + entries.size() * 46 + 14), Vector2(360, 38), _close_panels))
	_chain_focus(_hub_buttons)


func _open_debug_hub() -> void:
	_show_panel(_hub_panel, _hub_buttons[0])
	_refresh_talent_test()


## Debug: the level choice first lists the story worlds (Krypta, Frostgruft, Hölle; see
## story_worlds), one below the other. A world shows its floors, each with START (its
## entrance) and BOSS (inside its boss room); a pick goes through the hero choice and
## then starts that world's scene on that floor (story_floor_requested).
func _build_debug_panel() -> void:
	_debug_panel = _panel("LEVEL-AUSWAHL (DEBUG) · WELT WÄHLEN")
	_debug_panel.size = Vector2(800, 66 + story_worlds.size() * 86 + 66)
	_debug_panel.position = (SCREEN - _debug_panel.size) * 0.5 + Vector2(0, 20)
	var order: Array = []
	for i in range(story_worlds.size()):
		var world: Dictionary = story_worlds[i]
		var floors: Array = world.floors
		var last: Dictionary = floors[-1] if not floors.is_empty() else {"boss": "?"}
		# short: the 740 px button grows past the panel with a longer line
		var hint := "%d Etagen · Endboss %s" % [floors.size(), str(last.boss)]
		order.append(_world_button(_debug_panel, str(world.title), hint, Vector2(30, 66 + i * 86), _open_world.bind(str(world.id))))
		_world_panels[str(world.id)] = _build_world_panel(world)
	order.append(_panel_button(_debug_panel, "ZURÜCK", Vector2(30, _debug_panel.size.y - 62), Vector2(740, 36), _open_debug_hub))
	_debug_first = order[0]
	_chain_focus(order)


## One story world's floor list: per floor its number and title, START and BOSS · its
## boss (the world's last boss in gold).
func _build_world_panel(world: Dictionary) -> Panel:
	var panel := _panel("WELT · " + str(world.title))
	# wide enough for the longest names (ETAGE 10 · THRON DES GLETSCHERKOLOSSES,
	# BOSS · HRIMGAR, DER GLETSCHERKOLOSS) at 16 px
	panel.size = Vector2(1200, 520)
	panel.position = (SCREEN - panel.size) * 0.5 + Vector2(0, 20)
	var floors: Array = world.floors
	for i in range(floors.size()):
		var entry: Dictionary = floors[i]
		var y := 62.0 + i * 40.0
		var label := _panel_label(panel, "ETAGE %d · %s" % [int(entry.floor), str(entry.title).to_upper()], Vector2(30, y + 6))
		label.size = Vector2(520, 26)
		var start := _panel_button(panel, "START", Vector2(560, y), Vector2(110, 34), _pick_story_floor.bind(world, entry, false))
		if i == 0: panel.set_meta("first", start)
		var boss := _panel_button(panel, "BOSS · " + str(entry.boss).to_upper(), Vector2(680, y), Vector2(490, 34), _pick_story_floor.bind(world, entry, true))
		if bool(entry.get("final", false)): boss.add_theme_color_override("font_color", GOLD)
	_panel_button(panel, "ZURÜCK ZU DEN WELTEN", Vector2(30, 470), Vector2(1140, 36), _open_debug)
	return panel


## A floor start of the level choice: the hero choice first (the game has classes),
## then story_floor_requested in _choose_class; back leads to the world's floor list.
func _pick_story_floor(world: Dictionary, entry: Dictionary, boss: bool) -> void:
	if class_order.is_empty():
		_close_panels()
		story_floor_requested.emit(str(world.scene), "", int(entry.floor), boss)
		return
	_open_classes(false, "%s · ETAGE %d%s" % [str(world.title), int(entry.floor), " · BOSS" if boss else ""])
	_story_jump = {"scene": str(world.scene), "floor": int(entry.floor), "boss": boss, "world": str(world.id)}


func _world_button(panel: Panel, title: String, hint: String, at: Vector2, callback: Callable) -> Button:
	var button := _panel_button(panel, title + "\n" + hint, at, Vector2(740, 74), callback)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", GOLD)
	return button


## Shows the floor list of the story world `world` (its id in story_worlds), focus on its
## first START; an unknown id shows the world list.
func _open_world(world: String) -> void:
	var panel: Panel = _world_panels.get(world)
	if panel == null:
		_open_debug()
		return
	_show_panel(panel, panel.get_meta("first", null))


## Opens the Dungeon-Werkstatt over the menu at `room_id` (or the first room).
func open_room_editor(room_id: String = "") -> void:
	_hide_panels()
	if room_editor == null:
		room_editor = RoomEditor.new()
		add_child(room_editor)
		room_editor.saved.connect(func(config: Dictionary): rooms_saved.emit(config))
		room_editor.test_requested.connect(func(id: String, floor: int, class_id: String): room_test_requested.emit(id, floor, class_id))
		room_editor.closed.connect(_open_debug_hub)
	room_editor.open(room_id)


## Opens the Klangwerkstatt over the menu (sound and music choices).
func open_sound_workshop() -> void:
	_hide_panels()
	if sound_workshop == null:
		sound_workshop = SoundWorkshop.new()
		add_child(sound_workshop)
		sound_workshop.closed.connect(_open_debug_hub)
	sound_workshop.open()


func _open_debug() -> void:
	_show_panel(_debug_panel, _debug_first)


## MEHRSPIELER (debug hub): the old crypt lobby.
func _open_multiplayer() -> void:
	_close_panels()
	multiplayer_requested.emit()


func _pick_debug(entry: Dictionary) -> void:
	if class_order.is_empty():
		# No hero classes yet: start the picked level straight away.
		_close_panels()
		_debug_start = entry
		start_requested.emit(bool(entry.endless), "")
		return
	_open_classes(bool(entry.endless), "DEBUG · " + str(entry.label))
	_debug_start = entry


## Sets a debug jump without the level list (the Dungeon-Werkstatt test play).
func queue_debug_start(entry: Dictionary) -> void:
	_debug_start = entry.duplicate()


## The pending debug jump, once; empty for normal starts.
func take_debug_start() -> Dictionary:
	var jump := _debug_start
	_debug_start = {}
	return jump


## The hero choice for the story Testraum (src/debug/story_testraum.gd).
func _open_arena() -> void:
	_open_classes(false, "TESTRAUM · KRYPTA · FROSTGRUFT · HÖLLE")
	_arena_pick = true


## Opens the hero choice, focus on the first hero card; `hint` names what it starts.
## Without hero classes the run starts at once (start_requested).
func _open_classes(endless: bool = false, hint: String = "") -> void:
	_debug_start = {}
	_story_jump = {}
	_arena_pick = false
	_class_from_story = false
	if class_order.is_empty():
		# No hero classes yet: the mode button starts the run directly.
		_close_panels()
		start_requested.emit(endless, "")
		return
	_class_endless = endless
	_class_hint.text = hint if not hint.is_empty() else ("ENDLOS (ALTE KRYPTA)" if endless else "")
	_refresh_difficulty()
	_show_panel(_class_panel, _class_cards[0] if not _class_cards.is_empty() else _class_back_button)


## ZURÜCK / Esc in the hero choice: back to where it was opened from (a world's floor
## list, the debug hub, the story choice) or the title.
func _class_back() -> void:
	if not _story_jump.is_empty():
		_open_world(str(_story_jump.get("world", "")))
	elif _arena_pick or not _debug_start.is_empty():
		_open_debug_hub()
	elif _class_from_story:
		_open_stories()
	else:
		_close_panels()


## The difficulty switch of the hero choice (profile "difficulty", talents.json
## difficulties). It belongs to the story start, so it sits here, not in the talent screen.
func _refresh_difficulty() -> void:
	var data: Dictionary = progress.data if progress != null else {}
	var shown: bool = data.has("difficulties")
	_difficulty_button.visible = shown
	_difficulty_button.focus_mode = Control.FOCUS_ALL if shown else Control.FOCUS_NONE
	for card: Button in _class_cards:
		card.focus_neighbor_top = card.get_path_to(_difficulty_button if shown else card)
	if not shown:
		return
	var level := str(progress.profile.get("difficulty", "normal"))
	_difficulty_button.text = "SCHWIERIGKEIT: " + str(data.difficulties.get(level, {}).get("name", level)).to_upper()


## Steps the difficulty (Normal, Schwer, Albtraum) and saves the profile.
func _cycle_difficulty() -> void:
	var data: Dictionary = progress.data if progress != null else {}
	var order: Array = data.get("difficulties", {}).get("order", [])
	if order.is_empty():
		return
	progress.profile.difficulty = order[(order.find(str(progress.profile.get("difficulty", "normal"))) + 1) % order.size()]
	Profile.save_profile(progress.profile, progress.save_path)
	_refresh_difficulty()


func _choose_class(id: String) -> void:
	_close_panels()
	if _arena_pick:
		_arena_pick = false
		# the story Testraum: the Krypta first, the world switch sits in its panel
		var testraum: Variant = load("res://src/debug/story_testraum.gd")
		testraum.start(get_tree(), "", id)
		return
	if not _story_jump.is_empty():
		# a floor start of the level choice: that world, that floor, entrance or boss room
		var jump := _story_jump
		_story_jump = {}
		story_floor_requested.emit(str(jump.scene), id, int(jump.floor), bool(jump.boss))
		return
	var scene := _story_scene() if not _class_endless else ""
	if scene != "":
		story_scene_requested.emit(scene, id)
		return
	start_requested.emit(_class_endless, id)


## The scene of the chosen story, or "" when it plays as a crypt run.
func _story_scene() -> String:
	for story: Dictionary in stories:
		if str(story.id) == selected_story:
			return str(story.get("scene", ""))
	return ""


# --- Options ----------------------------------------------------------------

func _build_options_panel() -> void:
	_options_panel = _panel("OPTIONEN")
	_options_panel.size = Vector2(OptionsPanel.ROW_W + 60.0, 540)
	_options_panel.position = ((SCREEN - _options_panel.size) * 0.5).floor() + Vector2(0, 10)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if not version.is_empty():
		var tag := _panel_label(_options_panel, "Version " + version, Vector2(30, 24))
		tag.size.x = OptionsPanel.ROW_W
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.add_theme_color_override("font_color", MUTED)
	# the very page the pause shows: same rows, same file, Zurück at its foot
	_options = OptionsPanel.new()
	_options.position = Vector2(30, 66)
	_options.size = Vector2(OptionsPanel.ROW_W, 450)
	_options.show_back = true
	_options_panel.add_child(_options)
	_options.setup(SETTINGS_PATH)
	_options.changed.connect(func(key: String, value: Variant) -> void:
		settings[key] = value
		settings_changed.emit(settings))
	_options.back_pressed.connect(func() -> void:
		if _options_panel.visible: _close_panels())
	_sliders = _options.sliders
	_volume_slider = _options.sliders.volume
	_fullscreen_check = _options.checks.fullscreen
	_shake_check = _options.checks.shake
	_graphics_check = _options.checks.graphics


## Reads the graphics choice again (the pause menu may have switched it).
func refresh_graphics() -> void:
	settings.graphics = GraphicsSettings.mode(SETTINGS_PATH)
	if _graphics_check != null: _graphics_check.set_pressed_no_signal(settings.graphics == "hd")


func _open_options() -> void:
	refresh_graphics()
	_options.refresh()
	_show_panel(_options_panel, _volume_slider)


func _set_setting(key: String, value: Variant) -> void:
	# never write back a stale graphics choice the pause menu changed meanwhile
	if key != "graphics": settings.graphics = GraphicsSettings.mode(SETTINGS_PATH)
	settings[key] = value
	_apply_settings()
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	for name: String in settings: file.set_value("options", name, settings[name])
	file.save(SETTINGS_PATH)


func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		for name: String in settings: settings[name] = file.get_value("options", name, settings[name])
	for key: String in _sliders: _sliders[key].set_value_no_signal(float(settings[key]))
	_fullscreen_check.set_pressed_no_signal(bool(settings.fullscreen))
	_shake_check.set_pressed_no_signal(bool(settings.shake))
	if _graphics_check != null: _graphics_check.set_pressed_no_signal(str(settings.graphics) == "hd")
	_apply_settings()


func _apply_settings() -> void:
	AudioMix.ensure_buses()
	for key: String in ["volume", "music", "effects"]: AudioMix.set_slider(key, clampf(float(settings[key]) / 100.0, 0.0, 1.0))
	# The game applies `fullscreen` with its own toggle, which keeps the window rect.
	settings_changed.emit(settings)


# --- Widgets ----------------------------------------------------------------

## True while any panel of the menu is open (story, heroes, options, login, the talent
## screen, the debug panels or a workshop): the scene dims and the title card hides.
func _panel_open() -> bool:
	for panel: Control in [_login_panel, _options_panel, _story_panel, _class_panel, _hub_panel, _debug_panel, _saves_panel, _talent_panel, _talent_screen, sound_workshop, room_editor] + _world_panels.values():
		if panel != null and panel.visible: return true
	return false


## Dims the scene and hides the title card and its buttons while a panel is open, so
## nothing shines through; hidden title buttons take no focus.
func _sync_title() -> void:
	var open := _panel_open()
	if _debug_dim != null: _debug_dim.visible = open
	for node: Control in _title_nodes: node.visible = not open
	for button: Button in _buttons:
		button.visible = not open
		button.focus_mode = Control.FOCUS_NONE if open else Control.FOCUS_ALL
	if _debug_button != null:
		_debug_button.visible = not open and OS.is_debug_build()
		_debug_button.focus_mode = Control.FOCUS_ALL if _debug_button.visible else Control.FOCUS_NONE


## Hides every panel without moving the focus (openers then use _show_panel).
func _hide_panels() -> void:
	_login_panel.visible = false
	_options_panel.visible = false
	if _hub_panel != null: _hub_panel.visible = false
	if _debug_panel != null: _debug_panel.visible = false
	for panel: Panel in _world_panels.values(): panel.visible = false
	if _class_panel != null: _class_panel.visible = false
	if _story_panel != null: _story_panel.visible = false
	if _talent_panel != null: _talent_panel.visible = false
	if _talent_screen != null: _talent_screen.visible = false
	if _saves_panel != null: _saves_panel.visible = false
	_password_input.text = ""
	_refresh_account()


## Closes every panel and returns to the title, focus on its first entry.
func _close_panels() -> void:
	_hide_panels()
	_sync_title()
	_buttons[0].grab_focus()


## Opens `panel` alone over the dimmed scene and focuses `focus` (a control in it).
func _show_panel(panel: Control, focus: Control = null) -> void:
	_hide_panels()
	panel.visible = true
	_sync_title()
	if focus != null and focus.is_visible_in_tree():
		focus.grab_focus()


## Links `controls` top to bottom for arrow keys, d-pad and Tab; the ends stay put.
func _chain_focus(controls: Array) -> void:
	for i in range(controls.size()):
		var control: Control = controls[i]
		var above: Control = controls[maxi(i - 1, 0)]
		var below: Control = controls[mini(i + 1, controls.size() - 1)]
		control.focus_neighbor_top = control.get_path_to(above)
		control.focus_neighbor_bottom = control.get_path_to(below)
		control.focus_previous = control.get_path_to(above)
		control.focus_next = control.get_path_to(below)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and go_back():
		get_viewport().set_input_as_handled()


## Esc / Pad-B (ui_cancel): back exactly one level. Held → Story → Titel; Welt →
## Level-Auswahl → Debug-Hub → Titel; Spielstände → Debug-Hub; Talente, Optionen and
## Anmelden → Titel. False on the bare title and while a workshop owns the input.
func go_back() -> bool:
	if (sound_workshop != null and sound_workshop.visible) or (room_editor != null and room_editor.visible):
		return false
	if _talent_screen != null and _talent_screen.visible:
		_close_panels()
	elif _class_panel.visible:
		_class_back()
	elif _world_panels.values().any(func(panel: Panel) -> bool: return panel.visible):
		_open_debug()
	elif _debug_panel.visible or _saves_panel.visible:
		_open_debug_hub()
	elif _panel_open():
		_close_panels()
	else:
		return false
	return true


# --- Save slots ----------------------------------------------------------------

var saves := SaveStore.new()
var save_mode := "krypta"
var _saves_panel: Panel
var _save_tabs: Dictionary = {}
var _save_lines: Array[Label] = []
var _save_load: Array[Button] = []
var _save_erase: Array[Button] = []
## Slot waiting for a second click on LÖSCHEN (0 = none).
var _erase_armed := 0


func _build_saves_panel() -> void:
	_saves_panel = _panel("SPIELSTÄNDE")
	_saves_panel.size = Vector2(1000, 420)
	_saves_panel.position = (SCREEN - _saves_panel.size) * 0.5 + Vector2(0, 20)
	for i in range(SAVE_MODES.size()):
		var mode: String = SAVE_MODES[i]
		_save_tabs[mode] = _panel_button(_saves_panel, str(SaveStore.MODE_NAMES[mode]), Vector2(30 + i * 316, 66), Vector2(308, 40), _show_save_mode.bind(mode))
	var hint := _panel_label(_saves_panel, "Ein Spielstand ist der Beginn einer Etage. Laden setzt dich dorthin zurück.", Vector2(30, 118))
	hint.size = Vector2(940, 26)
	hint.add_theme_color_override("font_color", MUTED)
	for slot in range(1, SaveStore.SLOTS + 1):
		var y := 156.0 + (slot - 1) * 64.0
		var line := _panel_label(_saves_panel, "", Vector2(30, y + 10))
		line.size = Vector2(700, 26)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_save_lines.append(line)
		_save_load.append(_panel_button(_saves_panel, "LADEN", Vector2(750, y), Vector2(110, 44), func(): _load_slot(slot)))
		_save_erase.append(_panel_button(_saves_panel, "LÖSCHEN", Vector2(870, y), Vector2(100, 44), func(): _erase_slot(slot)))
	# the saves open from the DEBUG hub, so ZURÜCK leads back there
	_panel_button(_saves_panel, "ZURÜCK", Vector2(30, 356), Vector2(940, 40), _open_debug_hub)


func _open_saves() -> void:
	_show_panel(_saves_panel)
	_show_save_mode(save_mode)


## Shows the three slots of one mode with their summary lines.
func _show_save_mode(mode: String) -> void:
	save_mode = mode
	_erase_armed = 0
	for m: String in _save_tabs:
		var tab: Button = _save_tabs[m]
		if m == mode:
			tab.add_theme_color_override("font_color", GOLD)
			tab.add_theme_stylebox_override("normal", CryptUI.box("button_hover"))
		else:
			tab.remove_theme_color_override("font_color")
			tab.remove_theme_stylebox_override("normal")
	var rows := saves.summaries(mode)
	for i in range(rows.size()):
		_save_lines[i].text = str(rows[i].text)
		_save_lines[i].add_theme_color_override("font_color", MUTED if rows[i].empty else TEXT)
		_save_load[i].disabled = bool(rows[i].empty)
		_save_erase[i].disabled = bool(rows[i].empty)
		_save_erase[i].text = "LÖSCHEN"
		for button: Button in [_save_load[i], _save_erase[i]]: button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_save_tabs[mode].grab_focus()


func _load_slot(slot: int) -> void:
	_close_panels()
	save_load_requested.emit(save_mode, slot)


## First click arms the button ("SICHER?"), the second deletes the slot.
func _erase_slot(slot: int) -> void:
	if _erase_armed != slot:
		_show_save_mode(save_mode)
		_erase_armed = slot
		_save_erase[slot - 1].text = "SICHER?"
		return
	saves.erase(save_mode, slot)
	show_toast("Platz %d gelöscht." % slot)
	_show_save_mode(save_mode)


# --- Talents -------------------------------------------------------------------

## Opens the talent screen (src/ui/talent_screen.gd) on the run's profile.
var _talent_test_button: Button


## Switches the talent test profile on or off and loads the matching profile,
## so the talent screen and the next run use it at once.
func _toggle_talent_test() -> void:
	if progress == null: return
	Profile.set_debug(not Profile.debug_enabled(), progress.data)
	progress.save_path = Profile.default_path()
	progress.profile = Profile.load_profile(progress.data, progress.save_path)
	_refresh_talent_test()
	_apply_mage_skin()
	talents_changed.emit()


## The mage's wizard frames in the chase and on his class card take the colours
## of his main specialisation in the run's profile (src/hero/element_skin.gd):
## the wizard's own blue without talent points, red as a fire mage, pale ice
## blue for frost, violet for arcane. Called again whenever the talent build or
## the test profile changes.
func _apply_mage_skin() -> void:
	var class_id := "mage"
	var sprite := ElementSkin.source(class_id)
	if sprite.is_empty(): return
	var profile: Dictionary = progress.profile if progress != null and progress.get("profile") is Dictionary else {}
	var skinned := ElementSkin.element(profile, class_id)
	var recolor := func(frame: Texture2D) -> Texture2D: return ElementSkin.texture(frame, skinned, class_id)
	if _frames.has(sprite):
		if not _mage_frames.has("run"): _mage_frames.run = (_frames[sprite] as Array).duplicate()
		_frames[sprite] = (_mage_frames.run as Array).map(recolor)
	for i in range(mini(class_order.size(), _class_frames.size())):
		if str(class_order[i]) != class_id: continue
		if not _mage_frames.has("idle"): _mage_frames.idle = (_class_frames[i] as Array).duplicate()
		_class_frames[i] = (_mage_frames.idle as Array).map(recolor)


func _refresh_talent_test() -> void:
	if _talent_test_button == null: return
	var on := Profile.debug_enabled()
	_talent_test_button.text = "TALENT-TEST (DEBUG): " + ("AN" if on else "AUS")
	_talent_test_button.add_theme_color_override("font_color", GOLD if on else TEXT)


func _open_talents() -> void:
	if progress == null:
		return
	if _talent_screen == null:
		_talent_screen = TalentScreen.new()
		add_child(_talent_screen)
		_talent_screen.profile_changed.connect(func():
			_apply_mage_skin()
			talents_changed.emit())
		# ZURÜCK, Esc and Pad-B in the talent screen lead back to the title
		_talent_screen.closed.connect(_close_panels)
	_hide_panels()
	_talent_screen.open(progress.data, progress.profile, progress.save_path, _talent_class)
	_sync_title()


## Breaks text into lines of at most `width` characters (labels here sit outside containers).
static func _wrap(text: String, width: int) -> String:
	var lines: Array[String] = []
	var line := ""
	for word: String in text.split(" "):
		if line != "" and line.length() + 1 + word.length() > width:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	lines.append(line)
	return "\n".join(lines)


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


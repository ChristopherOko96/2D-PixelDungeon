extends Control
## Dungeon-Werkstatt (main menu → EDITOR): build the rooms of the story
## mode's room pool. Paint floor (walls, gates and spawn points follow by
## themselves), set markers, give the room a role and its floors, watch the
## checklist, test-play it in the real game, save. Rooms live in
## assets/data/dungeon_rooms.json ("templates"); a room the game does not
## accept yet is kept as a draft ("draft_rooms") so the story mode always
## starts. Every save keeps a backup (dungeon_editor_store.gd).
## Tools 1-8 build the room, tool 9 DEKO decorates it: the DEKO tab on the
## right holds the decor library (assets/data/dungeon_decor.json) sorted by
## category; a click picks a piece, the canvas shows where it may go.

signal closed
## The library changed on disk; the game should use `config` from now on.
signal saved(config: Dictionary)
## Test-play `room_id` on `floor` with the hero `class_id`.
signal test_requested(room_id: String, floor: int, class_id: String)

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const Store = preload("res://src/dungeon_editor_store.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Decor = preload("res://src/dungeon/decor_catalog.gd")
const RoomDoc = preload("res://src/editor/room_doc.gd")
const RoomPool = preload("res://src/editor/room_pool.gd")
const RoomCanvas = preload("res://src/editor/room_canvas.gd")
const RoomShaper = preload("res://src/editor/room_shaper.gd")
const RoomStylist = preload("res://src/editor/room_stylist.gd")
const SCREEN := Vector2(1280, 720)
const CONFIG_PATH := "res://assets/data/dungeon_rooms.json"
const NONE := Vector2i(-1, -1)
## [id, button text, hint, outline colour]
const TOOLS := [
	["floor", "1 BODEN", "BODEN: Links malen, rechts radieren. Wände entstehen von selbst.", Color("aa8d7a")],
	["erase", "2 RADIERER", "RADIERER: Boden entfernen (links). Rechts malt wieder Boden.", Color("da4e38")],
	["rect", "3 RECHTECK", "RECHTECK: Ziehen füllt Boden, mit rechts ziehen leert die Fläche.", Color("edbf75")],
	["start", "4 START", "START: Wo die Helden ankommen (links setzen).", Color("72dcc8")],
	["enemy", "5 GEGNER", "GEGNER: Startplätze der ersten Gegner. Rechts entfernt. Fehlende ergänzt das Spiel.", Color("da4e38")],
	["chest", "6 TRUHE", "TRUHE: Truhenplatz setzen. Nochmal klicken = MIMIK (beißt!), nochmal = Truhe. Rechts entfernt.", Color("edbf75")],
	["torch", "7 KERZE", "KERZE: Kerzensäulen als Licht (höchstens 16).", Color("ffb35c")],
	["stairs", "8 TREPPE", "TREPPE: Nur im Boss-Raum: der Weg zur nächsten Ebene.", Color("8fd8e6")],
	["decor", "9 DEKO", "DEKO: 1 bis 8 bauen den Raum, 9 macht ihn schön. Teil rechts im Reiter DEKO wählen.", Color("c9a0ef")],
]
const BRUSHES := [[0, "1"], [1, "3"], [2, "5"]]
const ROLE_NAMES := {"entrance": "Eingang (erster Raum)", "normal": "Normaler Raum", "boss": "Boss-Raum (letzter Raum)"}
const CLASS_NAMES := [["swordsman", "Schwertkämpfer"], ["archer", "Bogenschütze"], ["mage", "Magier"], ["necromancer", "Nekromant"]]
const KIND_TEXT := {"floor": "BODENART · FLÄCHE", "carpet": "TEPPICH · FLÄCHE", "wall": "AN DER WAND", "object": "AUF DEM BODEN"}
const RECENT_MAX := 6
const ERROR_COLOR := Color("ef8a6a")

var config_path := CONFIG_PATH
var config: Dictionary = {}
var doc: RefCounted
## Index in `config.templates` (or -1 for a new or draft room).
var room_ids: Array[String] = []
var tool := "floor"
var brush := 1
var status_text := ""
## The decor piece chosen in the library, its variant and how it is laid.
var deco_id := ""
var deco_variant := 0
var deco_random := false
var deco_rect := false
var recent: Array[String] = []
var tab := "raum"

var _canvas: Control
var _room_menu: OptionButton
var _tool_buttons: Dictionary = {}
var _brush_buttons: Array[Button] = []
var _name: LineEdit
var _role: OptionButton
var _floor_from: SpinBox
var _floor_to: SpinBox
var _width: SpinBox
var _height: SpinBox
var _hero: OptionButton
var _checks: VBoxContainer
var _status: Label
var _undo_button: Button
var _redo_button: Button
var _tab_buttons: Dictionary = {}
var _tab_nodes: Dictionary = {"raum": [], "deko": []}
var _category := ""
var _category_buttons: Dictionary = {}
var _item_grid: GridContainer
var _item_buttons: Dictionary = {}
var _pick_label: Label
var _pick_details: Label
var _mode_button: Button
var _random_button: Button
var _pipette_button: Button
var _recent_row: Control
var _auto_button: Button
var _clear_button: Button
var _thumbs: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _syncing := false
var _stroke := false
var _erasing := false
var _moving := NONE
var _pipette := false
var _leave_armed := false
var _clear_armed := false
var _check_wait := 0.0
var _layout_round := 0
var _decor_round := 0


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 7
	_build()
	set_process(true)


## Loads the library and shows `room_id` (or the first room).
func open(room_id: String = "") -> void:
	var loaded := Store.read_config(config_path)
	if not str(loaded.get("error", "")).is_empty():
		_note("Raumdaten konnten nicht gelesen werden: " + str(loaded.error))
		return
	config = loaded.config
	_fill_rooms()
	var index := room_ids.find(room_id)
	select_room(maxi(0, index))
	visible = true
	_leave_armed = false
	_canvas.grab_focus()


# --- Layout -----------------------------------------------------------------------

func _build() -> void:
	var shade := ColorRect.new()
	shade.size = SCREEN
	shade.color = CryptUI.INK
	add_child(shade)
	_panel(Rect2(8, 8, 1264, 52))
	_label("DUNGEON-WERKSTATT", Vector2(20, 18), 24, CryptUI.GOLD)
	_room_menu = OptionButton.new()
	_room_menu.position = Vector2(384, 16)
	_room_menu.size = Vector2(380, 36)
	_room_menu.clip_text = true
	_room_menu.item_selected.connect(func(index: int): _switch_room(index))
	add_child(_room_menu)
	_button("NEU", Rect2(772, 16, 78, 36), new_room)
	_button("KOPIE", Rect2(856, 16, 92, 36), duplicate_room)
	_button("LÖSCHEN", Rect2(954, 16, 108, 36), delete_room)
	_undo_button = _button("STRG+Z", Rect2(1068, 16, 96, 36), undo)
	_undo_button.tooltip_text = "Rückgängig"
	_redo_button = _button("STRG+Y", Rect2(1170, 16, 96, 36), redo)
	_redo_button.tooltip_text = "Wiederholen"
	# Tools on the left: 1-8 build the room, 9 decorates it.
	_panel(Rect2(8, 68, 176, 600))
	var y := 76.0
	for entry: Array in TOOLS:
		var id: String = entry[0]
		var button := _button(str(entry[1]), Rect2(16, y, 160, 38), func(): select_tool(id))
		button.toggle_mode = true
		_tool_buttons[id] = button
		y += 43.0
		if id == "stairs": y += 6.0
	_label("PINSEL", Vector2(18, y + 12), 16, CryptUI.MUTED)
	for index in range(BRUSHES.size()):
		var radius: int = BRUSHES[index][0]
		var button := _button(str(BRUSHES[index][1]), Rect2(92 + index * 29, y + 6, 27, 34), func(): set_brush(radius))
		button.toggle_mode = true
		_brush_buttons.append(button)
	y += 46.0
	var grid := _button("RASTER", Rect2(16, y, 160, 30), func(): _toggle_grid())
	grid.toggle_mode = true
	grid.button_pressed = true
	y += 34.0
	_button("EINPASSEN", Rect2(16, y, 160, 30), func(): _canvas.fit())
	# Suggestions: a new layout, or decor for the room as it is.
	y += 35.0
	_label("VORSCHLAG", Vector2(18, y), 14, CryptUI.MUTED)
	var shape_button := _button("GRUNDRISS", Rect2(16, y + 18, 160, 30), suggest_layout)
	shape_button.tooltip_text = "Neuer Grundriss: Gänge und Kammern zum Erkunden, im Boss-Raum ein Thronsaal. Jeder Klick ein neuer, STRG+Z zurück."
	var decor_button := _button("DEKORIEREN", Rect2(16, y + 52, 160, 30), suggest_decor)
	decor_button.tooltip_text = "Schmückt den Raum nach Regeln: Teppich in der Mitte, Säulen gespiegelt, Fackeln im Takt, Kram in die Ecken. Jeder Klick eine neue Variante."
	# The room.
	_canvas = RoomCanvas.new()
	_canvas.position = Vector2(192, 68)
	_canvas.size = Vector2(676, 600)
	add_child(_canvas)
	_canvas.cell_pressed.connect(_on_press)
	_canvas.cell_dragged.connect(_on_drag)
	_canvas.cell_released.connect(_on_release)
	_canvas.hovered.connect(_on_hover)
	# The right panel: two tabs, and the same footer for both.
	_panel(Rect2(876, 68, 396, 600))
	_tab_buttons["raum"] = _button("RAUM", Rect2(884, 76, 186, 34), func(): show_tab("raum"))
	_tab_buttons["deko"] = _button("DEKO", Rect2(1078, 76, 186, 34), func(): show_tab("deko"))
	for key: String in _tab_buttons: _tab_buttons[key].toggle_mode = true
	var before := get_child_count()
	_build_room_tab(888.0)
	_collect("raum", before)
	before = get_child_count()
	_build_decor_tab(888.0)
	_collect("deko", before)
	for entry: Array in [["TESTSPIELEN", Rect2(888, 618, 150, 40), test_play], ["SPEICHERN", Rect2(1041, 618, 122, 40), save], ["ZURÜCK", Rect2(1166, 618, 94, 40), _leave]]:
		_button(str(entry[0]), entry[1], entry[2]).add_theme_font_size_override("font_size", 14)
	# Status line.
	_status = _label("", Vector2(16, 680), 16, CryptUI.BONE)
	_status.size.x = 1248
	_status.clip_text = true
	select_tool("floor")
	set_brush(1)
	show_tab("raum")


func _build_room_tab(x: float) -> void:
	_label("NAME", Vector2(x, 116), 16, CryptUI.MUTED)
	_name = LineEdit.new()
	_name.position = Vector2(x, 136)
	_name.size = Vector2(372, 34)
	_name.text_changed.connect(func(text: String): _edit(func(): doc.set_title(text), false))
	add_child(_name)
	_label("ROLLE", Vector2(x, 176), 16, CryptUI.MUTED)
	_role = OptionButton.new()
	_role.position = Vector2(x, 196)
	_role.size = Vector2(372, 34)
	_role.clip_text = true
	for role: String in RoomPool.ROLES: _role.add_item(ROLE_NAMES[role])
	_role.item_selected.connect(func(index: int): _edit(func(): doc.set_role(RoomPool.ROLES[index])))
	add_child(_role)
	_label("KOMMT VOR AUF EBENE", Vector2(x, 236), 16, CryptUI.MUTED)
	_floor_from = _spin(Vector2(x, 256), 1, 40)
	_label("BIS", Vector2(x + 110, 262), 16, CryptUI.MUTED)
	_floor_to = _spin(Vector2(x + 156, 256), 1, 40)
	_floor_from.value_changed.connect(func(_value: float): _edit(func(): doc.set_floors(int(_floor_from.value), int(_floor_to.value)), false))
	_floor_to.value_changed.connect(func(_value: float): _edit(func(): doc.set_floors(int(_floor_from.value), int(_floor_to.value)), false))
	_label("GRÖSSE IN FELDERN", Vector2(x, 296), 16, CryptUI.MUTED)
	_width = _spin(Vector2(x, 316), RoomDoc.MIN_SIZE.x, RoomDoc.MAX_SIZE.x)
	_label("×", Vector2(x + 116, 322), 16, CryptUI.MUTED)
	_height = _spin(Vector2(x + 156, 316), RoomDoc.MIN_SIZE.y, RoomDoc.MAX_SIZE.y)
	_button("ÄNDERN", Rect2(x + 266, 316, 106, 32), _apply_size)
	_label("PRÜFUNG", Vector2(x, 356), 16, CryptUI.GOLD)
	_checks = VBoxContainer.new()
	_checks.position = Vector2(x, 376)
	_checks.size = Vector2(372, 190)
	_checks.add_theme_constant_override("separation", 0)
	add_child(_checks)
	_label("TEST-HELD", Vector2(x, 582), 16, CryptUI.MUTED)
	_hero = OptionButton.new()
	_hero.position = Vector2(x + 132, 576)
	_hero.size = Vector2(240, 32)
	for entry: Array in CLASS_NAMES: _hero.add_item(str(entry[1]))
	add_child(_hero)


## The decor library: categories, the pieces of one category, the chosen
## piece with its options, the last pieces used and the room's decor switches.
func _build_decor_tab(x: float) -> void:
	var index := 0
	for category: Dictionary in Decor.categories():
		var id := str(category.id)
		var button := _button(str(category.label), Rect2(x + (index % 3) * 125, 116 + (index / 3) * 34, 122, 30), func(): show_category(id))
		button.toggle_mode = true
		button.tooltip_text = str(category.get("hint", ""))
		_category_buttons[id] = button
		index += 1
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(x, 188)
	scroll.size = Vector2(380, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_item_grid = GridContainer.new()
	_item_grid.columns = 3
	_item_grid.add_theme_constant_override("h_separation", 5)
	_item_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(_item_grid)
	_pick_label = _label("", Vector2(x, 452), 16, CryptUI.GOLD)
	_pick_label.size.x = 372
	_pick_label.clip_text = true
	_pick_details = _label("", Vector2(x, 472), 12, CryptUI.MUTED)
	_pick_details.size.x = 372
	_pick_details.clip_text = true
	_mode_button = _button("PINSEL", Rect2(x, 490, 122, 30), _toggle_mode)
	_random_button = _button("ZUFALL", Rect2(x + 125, 490, 122, 30), _toggle_random)
	_random_button.toggle_mode = true
	_random_button.tooltip_text = "Jedes neue Teil bekommt ein zufälliges Muster."
	_pipette_button = _button("PIPETTE", Rect2(x + 250, 490, 122, 30), func(): _arm_pipette(not _pipette))
	_pipette_button.toggle_mode = true
	_pipette_button.tooltip_text = "Klick auf ein Teil im Raum übernimmt es (auch ALT + Klick)."
	_label("ZULETZT", Vector2(x, 538), 14, CryptUI.MUTED)
	_recent_row = Control.new()
	_recent_row.position = Vector2(x + 96, 526)
	_recent_row.size = Vector2(276, 40)
	add_child(_recent_row)
	_auto_button = _button("AUTO-DEKO: AN", Rect2(x, 574, 204, 32), _toggle_auto)
	_auto_button.tooltip_text = "AN: das Spiel schmückt den Raum selbst (Fackeln, Banner, Schädel), je Lauf anders. AUS: nur deine Deko."
	_clear_button = _button("DEKO LEEREN", Rect2(x + 208, 574, 164, 32), clear_decor)


## Nodes added since `before` belong to `key`'s tab.
func _collect(key: String, before: int) -> void:
	for index in range(before, get_child_count()): _tab_nodes[key].append(get_child(index))


func _panel(area: Rect2) -> void:
	var panel := Panel.new()
	panel.position = area.position
	panel.size = area.size
	panel.add_theme_stylebox_override("panel", CryptUI.box("panel"))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)


func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, area: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = area.position
	button.size = area.size
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button


func _spin(at: Vector2, low: int, high: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.position = at
	spin.size = Vector2(100, 32)
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	add_child(spin)
	return spin


## Shows the RAUM (room settings, checklist) or DEKO (library) tab.
func show_tab(key: String) -> void:
	tab = key
	for group: String in _tab_nodes:
		for node: Node in _tab_nodes[group]: node.visible = group == key
	for group: String in _tab_buttons: _tab_buttons[group].set_pressed_no_signal(group == key)
	if key == "deko" and _category.is_empty(): show_category(str(Decor.categories()[0].id))


## Fills the library grid with one category's pieces.
func show_category(id: String) -> void:
	_category = id
	for key: String in _category_buttons: _category_buttons[key].set_pressed_no_signal(key == id)
	for child: Node in _item_grid.get_children(): child.queue_free()
	_item_buttons.clear()
	for item: Dictionary in Decor.items_in(id): _item_grid.add_child(_item_cell(str(item.id)))
	_mark_selection()
	for category: Dictionary in Decor.categories():
		if str(category.id) == id: _note("%s: %s." % [str(category.label), str(category.get("hint", ""))])


## One library cell: thumbnail, name and a tag for pieces that block or shine.
func _item_cell(id: String) -> Button:
	var item := Decor.item(id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(118, 94)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _describe(id)
	button.pressed.connect(func(): pick_decor(id))
	var picture := TextureRect.new()
	picture.texture = _thumb(id, 0)
	picture.position = Vector2(6, 4)
	picture.size = Vector2(106, 50)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(picture)
	var caption := Label.new()
	caption.text = str(item.get("label", id))
	caption.position = Vector2(2, 56)
	caption.size = Vector2(114, 36)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	caption.add_theme_constant_override("line_spacing", 0)
	caption.add_theme_font_size_override("font_size", 14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	var tag := "IM WEG" if Decor.is_solid(id) else "LICHT" if Decor.gives_light(id) else ""
	if not tag.is_empty():
		var badge := Label.new()
		badge.text = tag
		badge.position = Vector2(4, 2)
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", ERROR_COLOR if tag == "IM WEG" else CryptUI.GOLD)
		badge.add_theme_color_override("font_outline_color", CryptUI.INK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
	_item_buttons[id] = button
	return button


## A thumbnail (cached): the piece on its wall or floor tile.
func _thumb(id: String, variant: int) -> Texture2D:
	var key := "%s:%d" % [id, variant]
	if not _thumbs.has(key):
		var picture: Image = Decor.preview(id, variant, true).image
		_thumbs[key] = ImageTexture.create_from_image(picture) if picture != null else null
	return _thumbs[key]


func _describe(id: String) -> String:
	var item := Decor.item(id)
	var parts: Array[String] = [str(item.get("label", id)), str(KIND_TEXT.get(str(item.get("kind", "")), ""))]
	if Decor.is_solid(id): parts.append("STEHT IM WEG")
	if Decor.gives_light(id): parts.append("LEUCHTET")
	if Decor.variants(id) > 1: parts.append("MUSTER %d/%d" % [deco_variant + 1 if id == deco_id else 1, Decor.variants(id)])
	return " · ".join(parts)


## Kind and flags of a piece, for the line under its name.
func _details(id: String) -> String:
	var parts: Array[String] = [str(KIND_TEXT.get(Decor.kind(id), ""))]
	if Decor.is_solid(id): parts.append("STEHT IM WEG")
	if Decor.gives_light(id): parts.append("LEUCHTET")
	if Decor.variants(id) > 1: parts.append("R = NÄCHSTES MUSTER")
	return " · ".join(parts)


# --- Rooms ------------------------------------------------------------------------

## All rooms: the game's pool, then drafts it does not accept yet.
func _all_rooms() -> Array:
	return Array(config.get("templates", [])) + Array(config.get("draft_rooms", []))


func _fill_rooms() -> void:
	_room_menu.clear()
	room_ids.clear()
	for room: Dictionary in _all_rooms():
		var draft: bool = Array(config.get("draft_rooms", [])).has(room)
		var floors := RoomPool.floors(room)
		var label := "%s · %s · Ebene %d-%d%s" % [_short_title(room), {"entrance": "Eingang", "normal": "Raum", "boss": "Boss"}[RoomPool.role(room)], floors[0], mini(int(floors[1]), 99), " · ENTWURF" if draft else ""]
		_room_menu.add_item(label)
		room_ids.append(str(room.id))


func _short_title(room: Dictionary) -> String:
	var title := str(room.get("title", room.get("id", "")))
	return title.get_slice(" · ", title.get_slice_count(" · ") - 1)


## Shows the room at `index` of the list (saving the current one first).
func select_room(index: int) -> void:
	var rooms := _all_rooms()
	if rooms.is_empty():
		new_room()
		return
	index = clampi(index, 0, rooms.size() - 1)
	doc = RoomDoc.from_template(rooms[index])
	_room_menu.select(index)
	_sync_controls()
	_canvas.show_room(doc)
	_refresh_checks()
	_note("%s geladen.%s" % [_short_title(doc.room), " Er formt sich je Lauf etwas anders, bis du Boden oder Deko änderst." if doc.from_recipe else ""])


func _switch_room(index: int) -> void:
	if doc != null and doc.dirty: save(false)
	select_room(index)


func new_room() -> void:
	if doc != null and doc.dirty: save(false)
	var number := 1
	while room_ids.has("raum_%02d" % number): number += 1
	doc = RoomDoc.blank("raum_%02d" % number, "Neuer Raum %d" % number)
	_store(doc.to_template(), false)
	_fill_rooms()
	_room_menu.select(room_ids.find(str(doc.room.id)))
	_sync_controls()
	_canvas.show_room(doc)
	_refresh_checks()
	_note("Neuer Raum angelegt. Male Boden, setze den START und probiere ihn mit TESTSPIELEN aus.")


func duplicate_room() -> void:
	if doc == null: return
	var copy: Dictionary = doc.to_template()
	var number := 2
	while room_ids.has("%s_%d" % [str(copy.id), number]): number += 1
	copy.id = "%s_%d" % [str(copy.id), number]
	copy.title = "%s (Kopie)" % _short_title(copy)
	if doc.dirty: save(false)
	doc = RoomDoc.from_template(copy)
	doc.dirty = true
	save(false)
	_fill_rooms()
	select_room(room_ids.find(str(copy.id)))
	_note("Kopie angelegt: " + str(copy.title))


## Deletes the current room unless the story mode would lose a needed room.
func delete_room() -> void:
	if doc == null: return
	var id := str(doc.room.id)
	var trial := config.duplicate(true)
	trial.templates = Array(trial.get("templates", [])).filter(func(room: Dictionary) -> bool: return str(room.id) != id)
	trial.draft_rooms = Array(trial.get("draft_rooms", [])).filter(func(room: Dictionary) -> bool: return str(room.id) != id)
	if not Dungeon.validate_config(trial).is_empty():
		_note("Löschen geht nicht: Der Story-Modus braucht mindestens 3 normale Räume und einen Boss-Raum.")
		return
	if not _leave_armed:
		_leave_armed = true
		_note("Nochmal LÖSCHEN drücken, um „%s“ zu entfernen." % _short_title(doc.room))
		return
	_leave_armed = false
	config = trial
	_write()
	doc = null
	_fill_rooms()
	select_room(0)
	_note("Raum gelöscht (eine Sicherung liegt in user://dungeon_editor/backups).")


# --- Tools ------------------------------------------------------------------------

func select_tool(id: String) -> void:
	tool = id
	for key: String in _tool_buttons: _tool_buttons[key].set_pressed_no_signal(key == id)
	for entry: Array in TOOLS:
		if entry[0] == id:
			_canvas.tool_color = entry[3]
			_note(str(entry[2]))
	if id == "decor":
		if tab != "deko": show_tab("deko")
		if deco_id.is_empty():
			var first: Array = Decor.items_in(_category)
			if not first.is_empty(): pick_decor(str(first[0].id))
			return
		_note(_decor_hint())
	_arm_pipette(false)
	_update_ghost()


func set_brush(radius: int) -> void:
	brush = radius
	for index in range(_brush_buttons.size()): _brush_buttons[index].set_pressed_no_signal(BRUSHES[index][0] == radius)
	_update_ghost()


func _toggle_grid() -> void:
	_canvas.show_grid = not _canvas.show_grid


## GRUNDRISS: a new layout (room_shaper.gd): chambers and corridors, a throne
## hall in a boss room. Only a suggestion the game accepts is shown; each
## click gives a new one, STRG+Z goes back.
func suggest_layout() -> void:
	if doc == null: return
	var style := "throne" if doc.role() == "boss" else "labyrinth"
	var data := RoomShaper.settings()
	var cells := RoomShaper.room_size(style, doc.size, data)
	_layout_round += 1
	var base := absi(str(doc.room.id).hash()) % 100000 + _layout_round * 7919
	var chosen: Dictionary = {}
	for attempt in range(int(data.get("attempts", 14))):
		var shape := RoomShaper.suggest(style, cells, base + attempt * 31, data)
		var trial = RoomDoc.from_template(doc.to_template())
		trial.apply_shape(shape, cells)
		if trial.ready_to_play(config):
			chosen = shape
			break
	if chosen.is_empty():
		_warn("Kein Vorschlag passte diesmal. Nochmal GRUNDRISS drücken oder den Raum vergrößern.")
		return
	doc.begin_change()
	doc.apply_shape(chosen, cells)
	_sync_controls()
	_after_change()
	_canvas.fit()
	_refresh_undo()
	_note(("Thronsaal: Vorraum, Gang und Halle; Start, Thron und Treppe sind gesetzt." if style == "throne" else "Grundriss: %d Kammern mit Gängen, %d Sackgassen mit Truhe." % [Array(chosen.main).size(), Array(chosen.side).size()]) + " DEKORIEREN schmückt ihn, nochmal GRUNDRISS gibt einen neuen.")


## DEKORIEREN: decor by rules (room_stylist.gd) for the room as it is. A
## variant the game would refuse is dropped and the next one is tried.
func suggest_decor() -> void:
	if doc == null: return
	for attempt in range(5):
		_decor_round += 1
		doc.begin_change()
		var report: Dictionary = RoomStylist.style(doc, absi(str(doc.room.id).hash()) % 100000 + _decor_round * 104729)
		if doc.generator_problems(config).is_empty():
			_after_change()
			_refresh_undo()
			if tab != "deko": show_tab("deko")
			_note("Deko: %d Kammern, %d Teppiche, %d Paare gespiegelt. Nochmal = neue Variante, STRG+Z = zurück." % [int(report.chambers), int(report.carpets), int(report.pairs)])
			return
		doc.undo()
	_after_change()
	_refresh_undo()
	_warn("Für diesen Raum fand sich keine Deko, die das Spiel annimmt. Grundriss etwas erweitern und nochmal versuchen.")


## Picks a piece from the library (switches to tool 9 DEKO).
func pick_decor(id: String, variant: int = -1) -> void:
	if Decor.item(id).is_empty(): return
	var changed := id != deco_id
	deco_id = id
	if variant >= 0: deco_variant = variant
	elif changed: deco_variant = 0
	deco_variant = posmod(deco_variant, Decor.variants(id))
	if changed:
		deco_random = bool(Decor.item(id).get("random", false))
		deco_rect = Decor.kind(id) == "carpet"
	recent.erase(id)
	recent.push_front(id)
	if recent.size() > RECENT_MAX: recent.resize(RECENT_MAX)
	var category := str(Decor.item(id).get("category", ""))
	if category != _category and _item_grid != null: show_category(category)
	if tool != "decor":
		tool = "decor"
		for key: String in _tool_buttons: _tool_buttons[key].set_pressed_no_signal(key == "decor")
		_canvas.tool_color = TOOLS[8][3]
	if tab != "deko": show_tab("deko")
	_arm_pipette(false)
	_mark_selection()
	_fill_recent()
	_update_ghost()
	_note(_decor_hint())


func _mark_selection() -> void:
	for key: String in _item_buttons: _item_buttons[key].set_pressed_no_signal(key == deco_id)
	if _pick_label == null: return
	if deco_id.is_empty():
		_pick_label.text = "AUSWAHL: noch nichts gewählt"
		_pick_details.text = ""
		_mode_button.disabled = true
		_random_button.disabled = true
		return
	_pick_label.text = str(Decor.item(deco_id).get("label", deco_id)) + ("   MUSTER %d/%d" % [deco_variant + 1, Decor.variants(deco_id)] if Decor.variants(deco_id) > 1 else "")
	_pick_details.text = _details(deco_id)
	var area := Decor.is_area(deco_id)
	_mode_button.disabled = not area and Decor.variants(deco_id) < 2
	_mode_button.text = ("RECHTECK" if deco_rect else "PINSEL") if area else "MUSTER"
	_mode_button.tooltip_text = "PINSEL malt Feld für Feld, RECHTECK zieht eine Fläche auf." if area else "Nächstes Muster (Taste R)."
	_random_button.disabled = Decor.variants(deco_id) < 2
	_random_button.set_pressed_no_signal(deco_random and Decor.variants(deco_id) > 1)


func _fill_recent() -> void:
	for child: Node in _recent_row.get_children(): child.queue_free()
	for index in range(recent.size()):
		var id: String = recent[index]
		var button := Button.new()
		button.position = Vector2(index * 46, 0)
		button.size = Vector2(40, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str(Decor.item(id).get("label", id))
		button.pressed.connect(func(): pick_decor(id))
		var picture := TextureRect.new()
		picture.texture = _thumb(id, 0)
		picture.position = Vector2(4, 4)
		picture.size = Vector2(32, 32)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		_recent_row.add_child(button)


func _toggle_mode() -> void:
	if deco_id.is_empty(): return
	if Decor.is_area(deco_id): deco_rect = not deco_rect
	else: deco_variant = (deco_variant + 1) % Decor.variants(deco_id)
	_mark_selection()
	_update_ghost()
	_note(_decor_hint())


func _toggle_random() -> void:
	deco_random = not deco_random
	_mark_selection()


func _arm_pipette(on: bool) -> void:
	_pipette = on
	if _pipette_button != null: _pipette_button.set_pressed_no_signal(on)
	if on: _note("PIPETTE: Klick auf ein Teil im Raum übernimmt es mit seinem Muster.")


## Hint line for the chosen piece.
func _decor_hint() -> String:
	if deco_id.is_empty(): return str(TOOLS[8][2])
	var label := str(Decor.item(deco_id).get("label", deco_id))
	if Decor.is_area(deco_id):
		return "DEKO %s: %s · RECHTS = WEG%s" % [label, "ZIEHEN = FLÄCHE" if deco_rect else "ZIEHEN = MALEN", " · R = MUSTER" if Decor.variants(deco_id) > 1 else ""]
	return "DEKO %s: KLICK = SETZEN · ZIEHEN = VERSCHIEBEN · RECHTS = WEG%s" % [label, " · R = MUSTER" if Decor.variants(deco_id) > 1 else ""]


## What the canvas shows under the mouse for the current tool.
func _update_ghost() -> void:
	if _canvas == null: return
	var decor_tool := tool == "decor" and not deco_id.is_empty()
	var area := decor_tool and Decor.is_area(deco_id)
	_canvas.ghost_id = deco_id if decor_tool and not area else ""
	_canvas.ghost_variant = deco_variant
	if _moving != NONE and doc != null and doc.decor.has(_moving):
		_canvas.ghost_id = str(doc.decor[_moving][0])
		_canvas.ghost_variant = int(doc.decor[_moving][1])
	_canvas.brush_radius = brush if tool in ["floor", "erase"] or (area and not deco_rect) else 0
	_check_ghost(_canvas.hover)


func _check_ghost(cell: Vector2i) -> String:
	var problem := ""
	if doc != null and tool == "decor" and not deco_id.is_empty() and cell.x >= 0:
		var id := deco_id if _moving == NONE else str(doc.decor.get(_moving, [deco_id])[0])
		if Decor.is_area(id): problem = "" if doc.floor_cells.has(cell) else "NUR AUF BODEN"
		elif _moving == NONE and doc.decor.has(cell): problem = ""
		else: problem = doc.decor_problem(id, cell, _moving)
	_canvas.ghost_ok = problem.is_empty()
	return problem


func _on_press(cell: Vector2i, button: int) -> void:
	if doc == null: return
	var right := button == MOUSE_BUTTON_RIGHT
	if tool == "decor":
		_press_decor(cell, right)
		_refresh_undo()
		return
	match tool:
		"floor", "erase":
			doc.begin_change()
			_stroke = true
			doc.brush(cell, brush, (tool == "erase") != right)
			_canvas.request_bake()
		"rect":
			_canvas.rect_from = cell
		_:
			doc.begin_change()
			if not doc.set_marker(tool, cell, right) and not right: _note("Markierungen nur auf freien Boden setzen.")
			_after_change()
	_refresh_undo()


func _on_drag(cell: Vector2i, button: int) -> void:
	if doc == null: return
	if tool == "decor":
		if _moving != NONE:
			_check_ghost(cell)
		elif _stroke and Decor.is_area(deco_id):
			doc.paint_area(deco_id, cell, brush, _erasing, deco_variant, deco_random, _rng)
			_canvas.request_bake()
		elif _stroke and _erasing:
			if doc.remove_decor(cell): _canvas.request_bake()
		return
	if not _stroke: return
	doc.brush(cell, brush, (tool == "erase") != (button == MOUSE_BUTTON_RIGHT))
	_canvas.request_bake()


func _on_release(cell: Vector2i, button: int) -> void:
	if doc == null: return
	if tool == "decor":
		_release_decor(cell, button == MOUSE_BUTTON_RIGHT)
	elif tool == "rect" and _canvas.rect_from.x >= 0:
		doc.begin_change()
		doc.fill_rect(_canvas.rect_from, cell, button != MOUSE_BUTTON_RIGHT)
		_canvas.rect_from = NONE
		_after_change()
	elif _stroke:
		_stroke = false
		_after_change()
	_refresh_undo()


## DEKO tool, mouse down: pipette, paint an area, pick up a piece to move it,
## or set a new piece; right button removes.
func _press_decor(cell: Vector2i, right: bool) -> void:
	if _pipette or (not right and Input.is_key_pressed(KEY_ALT)):
		var found: Dictionary = doc.decor_at(cell)
		_arm_pipette(false)
		if found.is_empty():
			_note("PIPETTE: Hier liegt keine Deko.")
			return
		pick_decor(str(found.id), int(found.variant))
		return
	if deco_id.is_empty():
		_note("Erst rechts im Reiter DEKO ein Teil wählen.")
		return
	_erasing = right
	if Decor.is_area(deco_id):
		doc.begin_change()
		_adopt_auto_decor()
		if deco_rect:
			_canvas.rect_from = cell
			return
		_stroke = true
		doc.paint_area(deco_id, cell, brush, right, deco_variant, deco_random, _rng)
		_canvas.request_bake()
		return
	if right:
		doc.begin_change()
		_stroke = true
		if not doc.remove_decor(cell): _note("Hier steht keine Deko. Rechts ziehen entfernt Teile.")
		_canvas.request_bake()
		return
	if doc.decor.has(cell):
		# Pick it up: the drop decides where it goes.
		_moving = cell
		_update_ghost()
		_note("Teil hochgenommen: ziehen und loslassen. Ungültige Plätze schicken es zurück.")
		return
	var problem: String = doc.decor_problem(deco_id, cell)
	if not problem.is_empty():
		_warn("HIER NICHT: " + problem)
		return
	doc.begin_change()
	var first: bool = doc.auto_decor
	var variant := Decor.pick_variant(deco_id, deco_variant, deco_random, _rng)
	problem = doc.place_decor(deco_id, cell, variant, _canvas.auto_items())
	if not problem.is_empty():
		doc.undo()
		_warn("HIER NICHT: " + problem)
		return
	_after_change()
	_note(("Die Auto-Deko gehört jetzt dir: alles lässt sich verschieben oder entfernen. " if first else "") + _decor_hint())


func _release_decor(cell: Vector2i, right: bool) -> void:
	if _moving != NONE:
		var from := _moving
		_moving = NONE
		if cell != from:
			var problem: String = doc.decor_problem(str(doc.decor[from][0]), cell, from)
			if problem.is_empty():
				doc.begin_change()
				doc.move_decor(from, cell)
				_after_change()
				_note("Verschoben. " + _decor_hint())
			else:
				_warn("Zurück an den alten Platz: " + problem)
		_update_ghost()
		return
	if _canvas.rect_from.x >= 0:
		doc.paint_area_rect(deco_id, _canvas.rect_from, cell, right, deco_variant, deco_random, _rng)
		_canvas.rect_from = NONE
		_after_change()
		return
	if _stroke:
		_stroke = false
		_after_change()


## The first decor change in a room takes over what the game placed by itself.
func _adopt_auto_decor() -> void:
	if doc.auto_decor:
		doc.adopt(_canvas.auto_items())
		_note("Die Auto-Deko gehört jetzt dir: alles lässt sich verschieben oder entfernen.")


func _toggle_auto() -> void:
	if doc == null: return
	doc.begin_change()
	doc.set_auto_decor(not doc.auto_decor, _canvas.auto_items())
	_after_change()
	_sync_decor_switches()
	_note("AUTO-DEKO AN: das Spiel ergänzt Fackeln, Banner und Schädel, je Lauf anders." if doc.auto_decor else "AUTO-DEKO AUS: nur deine Deko. Was das Spiel gesetzt hatte, ist jetzt deins.")


## Removes all decor of the room (press twice).
func clear_decor() -> void:
	if doc == null: return
	if not _clear_armed:
		_clear_armed = true
		_note("Nochmal DEKO LEEREN drücken: alle Deko dieses Raums kommt weg (STRG+Z holt sie zurück).")
		return
	_clear_armed = false
	doc.begin_change()
	doc.clear_decor()
	_after_change()
	_sync_decor_switches()
	_note("Deko geleert. Der Raum zeigt nur noch Boden, Wände und Kerzen.")


func _sync_decor_switches() -> void:
	if _auto_button != null and doc != null: _auto_button.text = "AUTO-DEKO: %s" % ("AN" if doc.auto_decor else "AUS")


func _on_hover(cell: Vector2i) -> void:
	if doc == null: return
	var inside: bool = cell.x >= 0 and cell.y >= 0 and cell.x < doc.size.x and cell.y < doc.size.y
	if not inside or _stroke: return
	var problem := _check_ghost(cell)
	if not problem.is_empty():
		_status.text = "HIER NICHT: %s   ·   Feld %d, %d" % [problem, cell.x, cell.y]
		_status.add_theme_color_override("font_color", ERROR_COLOR)
		return
	_status.add_theme_color_override("font_color", CryptUI.BONE)
	_status.text = "%s   ·   Feld %d, %d%s" % [status_text, cell.x, cell.y, "   ·   Rand bleibt Wand" if not doc.paintable(cell) else ""]


func _after_change() -> void:
	_canvas.rebake()
	_check_wait = 0.25
	_clear_armed = false
	_sync_decor_switches()


func undo() -> void:
	if doc != null and doc.undo():
		_sync_controls()
		_after_change()
	_refresh_undo()


func redo() -> void:
	if doc != null and doc.redo():
		_sync_controls()
		_after_change()
	_refresh_undo()


func _refresh_undo() -> void:
	_undo_button.disabled = doc == null or not doc.can_undo()
	_redo_button.disabled = doc == null or not doc.can_redo()


func _apply_size() -> void:
	_edit(func(): doc.resize(Vector2i(int(_width.value), int(_height.value))))
	_canvas.fit()


## Runs a property change as one undo step, then refreshes.
func _edit(change: Callable, rebake: bool = true) -> void:
	if doc == null or _syncing: return
	doc.begin_change()
	change.call()
	if rebake: _after_change()
	else: _check_wait = 0.4
	_refresh_undo()


func _sync_controls() -> void:
	_syncing = true
	_name.text = _short_title(doc.room)
	_role.select(RoomPool.ROLES.find(doc.role()))
	var floors := RoomPool.floors(doc.room)
	_floor_from.value = int(floors[0])
	_floor_to.value = mini(int(floors[1]), 40)
	_width.value = doc.size.x
	_height.value = doc.size.y
	_syncing = false
	_sync_decor_switches()
	_refresh_undo()


func _process(delta: float) -> void:
	if _check_wait > 0.0:
		_check_wait -= delta
		if _check_wait <= 0.0: _refresh_checks()


## The checklist on the right: green OK or red !! per rule. The RAUM tab
## shows !! too, so a problem is visible while decorating.
func _refresh_checks() -> void:
	for child: Node in _checks.get_children(): child.queue_free()
	if doc == null: return
	var all_ok := true
	for check: Dictionary in doc.checks(config):
		var label := Label.new()
		label.text = ("OK  " if bool(check.ok) else "!!  ") + str(check.text)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("8fd28a") if bool(check.ok) else ERROR_COLOR)
		label.clip_text = true
		label.custom_minimum_size.x = 372
		_checks.add_child(label)
		if not bool(check.ok): all_ok = false
	_tab_buttons["raum"].text = "RAUM" if all_ok else "RAUM  !!"
	_tab_buttons["raum"].add_theme_color_override("font_color", CryptUI.BONE if all_ok else ERROR_COLOR)


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	var key := event as InputEventKey
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if key.ctrl_pressed and key.keycode == KEY_Z:
		undo()
	elif key.ctrl_pressed and key.keycode == KEY_Y:
		redo()
	elif key.ctrl_pressed and key.keycode == KEY_S:
		save()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9 and not key.ctrl_pressed:
		select_tool(str(TOOLS[key.keycode - KEY_1][0]))
	elif key.keycode == KEY_TAB:
		show_tab("deko" if tab == "raum" else "raum")
	elif key.keycode == KEY_R and tool == "decor":
		cycle_variant()
	elif key.keycode == KEY_ESCAPE:
		if _moving != NONE or _pipette:
			_moving = NONE
			_arm_pipette(false)
			_update_ghost()
		else: _leave()
	else:
		return
	get_viewport().set_input_as_handled()


## R: the piece under the mouse gets its next pattern; with nothing there the
## chosen piece does.
func cycle_variant() -> void:
	var cell: Vector2i = _canvas.hover
	if doc != null and cell.x >= 0 and not doc.decor_at(cell).is_empty() and Decor.variants(str(doc.decor_at(cell).id)) > 1:
		doc.begin_change()
		doc.cycle_variant(cell)
		_after_change()
		_refresh_undo()
		return
	if not deco_id.is_empty() and Decor.variants(deco_id) > 1:
		deco_variant = (deco_variant + 1) % Decor.variants(deco_id)
		deco_random = false
		_mark_selection()
		_update_ghost()


func _warn(text: String) -> void:
	status_text = text
	if _status != null:
		_status.text = text
		_status.add_theme_color_override("font_color", ERROR_COLOR)


# --- Saving and testing -----------------------------------------------------------

## Writes the library: an accepted room into the story pool, otherwise as a
## draft. Returns true when the room is playable in the story mode.
func save(announce: bool = true) -> bool:
	if doc == null: return false
	var template: Dictionary = doc.to_template()
	var playable: bool = doc.generator_problems(config, template).is_empty()
	_store(template, playable)
	var problems := Dungeon.validate_config(config)
	if playable and not problems.is_empty():
		# The room alone is fine, but the pool as a whole is not: keep it as a draft.
		_store(template, false)
		playable = false
	if not _write(): return false
	doc.room = template
	doc.dirty = false
	_fill_rooms()
	_room_menu.select(room_ids.find(str(template.id)))
	# The game gets the library exactly as stored (plain JSON values).
	saved.emit(JSON.parse_string(JSON.stringify(config)))
	if announce: _note("Gespeichert. %s" % ("Der Raum ist ab dem nächsten Lauf im Story-Modus dabei." if playable else "Noch ENTWURF: erst wenn die Prüfung grün ist, kommt er ins Spiel."))
	return playable


## Puts `template` into the pool (`playable`) or the drafts, replacing its old copy.
func _store(template: Dictionary, playable: bool) -> void:
	var id := str(template.id)
	var pool := Array(config.get("templates", [])).filter(func(room: Dictionary) -> bool: return str(room.id) != id)
	var drafts := Array(config.get("draft_rooms", [])).filter(func(room: Dictionary) -> bool: return str(room.id) != id)
	var index := -1
	for position in range(Array(config.get("templates", [])).size()):
		if str(config.templates[position].id) == id: index = position
	if playable:
		if index >= 0: pool.insert(mini(index, pool.size()), template)
		else: pool.append(template)
	else: drafts.append(template)
	config.templates = pool
	config.draft_rooms = drafts
	if drafts.is_empty(): config.erase("draft_rooms")


func _write() -> bool:
	var result := Store.write_config(config_path, config)
	if not str(result.get("error", "")).is_empty():
		_note("Speichern fehlgeschlagen: " + str(result.error))
		return false
	return true


## Saves, then asks the game to start a run on the room's first floor with it.
func test_play() -> void:
	if doc == null: return
	if not save(false):
		_note("Testspielen geht erst, wenn die Prüfung grün ist (Reiter RAUM).")
		_refresh_checks()
		return
	var floors := RoomPool.floors(doc.room)
	test_requested.emit(str(doc.room.id), int(floors[0]), str(CLASS_NAMES[maxi(0, _hero.selected)][0]))


func _leave() -> void:
	if doc != null and doc.dirty: save(false)
	visible = false
	closed.emit()


func _note(text: String) -> void:
	status_text = text
	if _status != null:
		_status.text = text
		_status.add_theme_color_override("font_color", CryptUI.BONE)

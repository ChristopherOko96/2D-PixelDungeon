extends Node2D
## Standalone F6 authoring tool. Active game data changes only on explicit Apply.

const Model = preload("res://src/dungeon_editor_model.gd")
const Store = preload("res://src/dungeon_editor_store.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const View = preload("res://src/dungeon_view.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const Palette = preload("res://src/tile_palette.gd")
const CollisionGrid = preload("res://src/editor_collision_grid.gd")
const PlayPreview = preload("res://src/editor_play_preview.gd")
const CONFIG_PATH := "res://assets/data/dungeon_rooms.json"
const OFFSET := Vector2(32,156)
const ZOOM := 1.0
const TILE := 32.0
const FLOOR := Rect2(32,48,832,400)
const TOOLS := ["Wand malen","Boden malen","Spielerstart","Gegnerstart","Tür setzen","Boss-Treppe","Feuer setzen","Truhe setzen","Tile setzen","Bereich wählen"]
const TOOL_HELP := ["Wand mit gewähltem Tile malen","Boden mit gewähltem Tile malen","Spielerstart setzen","Gegnerstart setzen","Tür frei setzen","Treppe setzen (Boss)","Feuer setzen / löschen","Belohnungstruhe setzen","Tile nach Ebene setzen","Bereich auswählen und anschließend ersetzen, löschen oder Kollision ändern"]
const DOOR_SIDES := ["north","east","south","west"]
const DIRECTION_NAMES := ["OBEN","RECHTS","UNTEN","LINKS"]
const COLORS := [Color("72dcc8"),Color("edb563"),Color("bc91de"),Color("ed8a91")]

var model
var active_config_path := CONFIG_PATH
var _preview_layout: Dictionary = {}
var view: Node2D
var ui: Control
var overlay: Node2D
var room_menu: OptionButton
var theme_menu: OptionButton
var tool_menu: OptionButton
var slot: SpinBox
var id_input: LineEdit
var title_input: LineEdit
var boss_toggle: CheckButton
var status: Label
var draft_label: Label
var undo_button: Button
var redo_button: Button
var open_dialog: FileDialog
var save_dialog: FileDialog
var message: AcceptDialog
var _painting := false
var _erase := false
var _last_cell := Vector2i(-100,-100)
var _last_brush := 0
var _hover := Vector2i(-100,-100)
var _syncing := false
var _current_path := ""
var _test_game: Node2D
var _test_window_title := ""
var last_write_result: Dictionary = {}
var width_input: SpinBox
var height_input: SpinBox
var palette_popup: PopupPanel
var palette_grid: GridContainer
var tile_solid: CheckButton
var tile_label: Label
var selected_tile := "violet_017"
var tile_rotation := 0
var _canvas_zoom := 1.0
var tile_layer: OptionButton
var replace_toggle: CheckButton
var background_toggle: CheckButton
var grid_toggle: CheckButton
var canvas_background := Color.BLACK
var grid_visible := true
var _tool_hint: Label
var grid_legend: Label
var cell_hint: Label
var _collision_cells: Dictionary = {}
var selection_cells := Rect2i()
var _selection_anchor := Vector2i.ZERO
var _selecting := false
var _selection_room_id := ""
var selection_replace_button: Button
var selection_erase_button: Button
var selection_walkable_button: Button
var selection_block_button: Button
var _slot_label: Label
var _remove_room_button: Button

func _ready() -> void:
	get_window().title = "Dungeon-Editor · Ruhiger Pixelstil"
	var loaded := Store.read_config(active_config_path)
	if not loaded.error.is_empty():
		push_error(loaded.error)
		return
	model = Model.new(loaded.config)
	var previous_order: bool = model.config.has("room_order")
	model.clear_fixed_order()
	view = View.new()
	view.position = OFFSET
	view.scale = Vector2.ONE*_canvas_zoom
	add_child(view)
	view.set_animation_enabled(false)
	view.set_environment_animation_enabled(true)
	overlay = Node2D.new()
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	_build_ui()
	_refresh_controls()
	_refresh_room()
	_note("Raum-Bibliothek bereit. Linksklick malt, Rechtsklick löscht. Der Generator kombiniert deine Vorlagen zufällig." + (" Frühere feste Reihenfolge entfernt." if previous_order else "") + (" Alter 16-Pixel-Entwurf auf 32 Pixel umgerechnet." if loaded.get("migrated",false) else ""))
	if "--blank" in OS.get_cmdline_user_args(): new_blank_room()
	var launch_args := OS.get_cmdline_user_args()
	for index in range(launch_args.size()-1):
		if launch_args[index] == "--draft": load_draft(launch_args[index+1])

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("170d24"))
	if model != null: draw_rect(Rect2(OFFSET,model.room_size()*_canvas_zoom),canvas_background)
	draw_rect(Rect2(24,16,1232,116),Color("291538"))
	draw_rect(Rect2(24,16,1232,116),Color("764890"),false,2)
	draw_rect(Rect2(944,156,312,480),Color("291538"))
	draw_rect(Rect2(944,156,312,480),Color("764890"),false,2)

func _build_ui() -> void:
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = PixelStyle.create_theme()
	add_child(ui)
	_label("RAUM-BAUKASTEN",Vector2(32,22),Vector2(350,32),24)
	room_menu = _option(Vector2(400,22),Vector2(520,32))
	room_menu.item_selected.connect(func(index: int): _select_room(index))
	theme_menu = _option(Vector2(968,22),Vector2(264,32))
	for name in ["ZUFÄLLIGE PALETTE","VIOLET","ROSE","MOSS","AMBER"]: theme_menu.add_item(name)
	theme_menu.item_selected.connect(_set_theme)
	_button("LEERER RAUM",Vector2(32,64),Vector2(176,32),new_blank_room)
	_button("DUPLIZIEREN",Vector2(216,64),Vector2(176,32),func(): model.create_room(true); _refresh_controls(); _refresh_room())
	undo_button = _button("RÜCKGÄNGIG",Vector2(400,64),Vector2(176,32),_undo)
	redo_button = _button("WIEDERHOLEN",Vector2(584,64),Vector2(176,32),_redo)
	_button("ENTWURF LADEN",Vector2(784,64),Vector2(216,32),func(): open_dialog.popup_centered_ratio(0.7))
	_button("SPEICHERN",Vector2(1008,64),Vector2(224,32),_save_as,"Entwurf als JSON speichern; die aktive Bibliothek wird dadurch nicht ersetzt.")
	background_toggle = CheckButton.new()
	background_toggle.text = "HELL"
	background_toggle.tooltip_text = "Hellen oder schwarzen Hintergrund für die Zeichenfläche wählen."
	background_toggle.position = Vector2(26,102)
	background_toggle.size = Vector2(180,28)
	background_toggle.add_theme_font_size_override("font_size",PixelStyle.BODY_SIZE)
	background_toggle.toggled.connect(set_canvas_background)
	ui.add_child(background_toggle)
	grid_toggle = CheckButton.new()
	grid_toggle.text = "GRID"
	grid_toggle.tooltip_text = "Raster und Markierung begehbarer, blockierter und leerer Felder anzeigen."
	grid_toggle.position = Vector2(204,102)
	grid_toggle.size = Vector2(108,28)
	grid_toggle.add_theme_font_size_override("font_size",PixelStyle.BODY_SIZE)
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(enabled: bool): grid_visible = enabled; grid_legend.visible = enabled; _update_cell_hint(); overlay.queue_redraw())
	ui.add_child(grid_toggle)
	_label("B:",Vector2(320,106),Vector2(58,24),16)
	width_input = _dimension_input(Vector2(382,102),12,64)
	width_input.tooltip_text = "Breite der Zeichenfläche in32px-Tiles."
	_label("H:",Vector2(484,106),Vector2(50,24),16)
	height_input = _dimension_input(Vector2(540,102),10,48)
	height_input.tooltip_text = "Höhe der Zeichenfläche in32px-Tiles."
	_button("GRÖSSE ANWENDEN",Vector2(654,102),Vector2(266,28),_resize_selected)
	_button("PALETTE ÖFFNEN",Vector2(968,102),Vector2(264,28),_show_palette,"Tile-Palette öffnen: Grafik, Ebene, Blockierung und Ersetzen wählen.")
	_label("BAUWERKZEUG",Vector2(968,172),Vector2(264,28),24)
	tool_menu = _option(Vector2(968,210),Vector2(264,32))
	for title in TOOLS: tool_menu.add_item(title)
	_slot_label = _label("Platz",Vector2(968,252),Vector2(70,28),16)
	slot = SpinBox.new()
	slot.position = Vector2(1048,248)
	slot.size = Vector2(184,32)
	slot.min_value = 1
	slot.max_value = 4
	ui.add_child(slot)
	tool_menu.item_selected.connect(_select_tool)
	boss_toggle = CheckButton.new()
	boss_toggle.position = Vector2(960,284)
	boss_toggle.size = Vector2(150,32)
	boss_toggle.text = "BOSS"
	boss_toggle.tooltip_text = "Diese Raumvorlage ist ein Bossraum mit eigenem Abstieg."
	ui.add_child(boss_toggle)
	boss_toggle.toggled.connect(func(_value: bool): _commit_metadata())
	_remove_room_button = _button("ENTF.",Vector2(1120,286),Vector2(112,32),func():
		if model.delete_room():
			_refresh_controls()
			_refresh_room()
			_note("Raumvorlage entfernt. RÜCKGÄNGIG holt sie zurück.")
		else: _note("Mindestens ein Raum muss im Entwurf bleiben."),"Ausgewählte Raumvorlage entfernen. Rückgängig stellt sie wieder her.")
	selection_replace_button = _button("ERSETZEN",Vector2(968,248),Vector2(128,32),func(): apply_selection(false))
	selection_replace_button.tooltip_text = "Die ganze Auswahl mit der gewählten Grafik füllen."
	selection_erase_button = _button("LÖSCHEN",Vector2(1104,248),Vector2(128,32),func(): apply_selection(true))
	selection_erase_button.tooltip_text = "ERSETZEN an: alle Tile-Ebenen und Türen/Treppen der Auswahl löschen. Aus: nur die gewählte Ebene. Startplätze, Feuer und Truhe bleiben erhalten."
	selection_walkable_button = _button("FREI",Vector2(968,286),Vector2(128,32),func(): apply_selection_walkability(true))
	selection_walkable_button.size = Vector2(128,32)
	selection_walkable_button.tooltip_text = "Auswahl begehbar machen. Die gesetzten Grafiken bleiben unverändert. STRG+Z macht die Aktion rückgängig."
	selection_block_button = _button("SPERREN",Vector2(1104,286),Vector2(128,32),func(): apply_selection_walkability(false))
	selection_block_button.size = Vector2(128,32)
	selection_block_button.tooltip_text = "Auswahl für Bewegung blockieren. Die gesetzten Grafiken bleiben unverändert. STRG+Z macht die Aktion rückgängig."
	id_input = _line(Vector2(968,326),"Raum-ID: klein_mit_unterstrich")
	title_input = _line(Vector2(968,366),"Raumname")
	id_input.text_submitted.connect(func(_text: String): _commit_metadata())
	title_input.text_submitted.connect(func(_text: String): _commit_metadata())
	id_input.focus_exited.connect(_commit_metadata)
	title_input.focus_exited.connect(_commit_metadata)
	draft_label = _label("",Vector2(968,412),Vector2(264,26),16)
	cell_hint = _label("",Vector2(968,434),Vector2(264,16),16)
	_button("BIBLIOTHEK PRÜFEN",Vector2(968,450),Vector2(264,34),_validate,"Alle Raumvorlagen auf gültige Startpunkte, begehbare Wege und passende Türen prüfen.")
	_button("IM SPIEL NUTZEN",Vector2(968,494),Vector2(264,38),apply_to_game,"Den validierten Entwurf als aktive Raumbibliothek verwenden.")
	_button("RAUM SPIELEN",Vector2(968,542),Vector2(264,34),_test_room,"Den ausgewählten Raum einschließlich ungespeicherter Änderungen direkt spielen.")
	_button("ANLEITUNG",Vector2(968,590),Vector2(264,32),_help)
	grid_legend = _label("RASTER: Grün = begehbar · Rot/X = blockiert · Grau/Schraffur = kein Boden (blockiert)",Vector2(32,640),Vector2(1216,20),16)
	status = _label("",Vector2(32,663),Vector2(1216,22),16)
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	_tool_hint = _label("Q/E: 90° drehen · Links setzen / rechts löschen · STRG+Z / Y: Undo / Redo · STRG+S: speichern",Vector2(32,690),Vector2(1216,22),16)
	open_dialog = FileDialog.new()
	open_dialog.theme = ui.theme
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.json ; Dungeon-Entwurf"])
	open_dialog.file_selected.connect(load_draft)
	add_child(open_dialog)
	save_dialog = FileDialog.new()
	save_dialog.theme = ui.theme
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.json ; Dungeon-Entwurf"])
	save_dialog.file_selected.connect(save_draft)
	add_child(save_dialog)
	message = AcceptDialog.new()
	message.theme = ui.theme
	message.title = "Dungeon-Baukasten"
	message.min_size = Vector2i(780,360)
	add_child(message)
	_build_palette()
	_refresh_selection_controls()

func _dimension_input(point: Vector2, minimum: int, maximum: int) -> SpinBox:
	var field := SpinBox.new()
	field.position = point
	field.size = Vector2(94,28)
	field.min_value = minimum
	field.max_value = maximum
	field.step = 1
	ui.add_child(field)
	return field

## Starts a genuinely empty room draft; existing templates are retained.
func new_blank_room() -> void:
	clear_selection()
	if model.create_room().is_empty():
		_note("Maximal64 Raumvorlagen. Vorher eine Vorlage entfernen.")
		return
	model.resize_room(Vector2i(int(width_input.value),int(height_input.value)))
	_refresh_controls()
	_refresh_room()
	_note("Freie Zeichenfläche: erst Boden malen, dann Wände und Türen setzen. Q/E dreht. Alles außerhalb deines Bodens bleibt leer.")

func _resize_selected() -> void:
	clear_selection()
	var error: String = model.resize_room(Vector2i(int(width_input.value),int(height_input.value)))
	if not error.is_empty(): _show(error)
	else: _note("Zeichenfläche angepasst. RÜCKGÄNGIG stellt den vorherigen Stand wieder her.")
	_refresh_controls()
	_refresh_room()

func _build_palette() -> void:
	palette_popup = PopupPanel.new()
	palette_popup.theme = ui.theme
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("291538")
	panel.border_color = Color("9965b4")
	panel.set_border_width_all(2)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	palette_popup.add_theme_stylebox_override("panel",panel)
	palette_popup.size = Vector2i(548,624)
	add_child(palette_popup)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	palette_popup.add_child(body)
	var heading := Label.new()
	heading.text = "TILE WÄHLEN ·32×32 · Q/E DREHT"
	body.add_child(heading)
	var groups := OptionButton.new()
	for group: String in Palette.GROUPS: groups.add_item(group.to_upper())
	groups.item_selected.connect(func(index: int): _fill_palette(Palette.GROUPS[index]))
	body.add_child(groups)
	var layer_row := HBoxContainer.new()
	body.add_child(layer_row)
	tile_layer = OptionButton.new()
	tile_layer.custom_minimum_size = Vector2(200,32)
	tile_layer.add_item("BODEN")
	tile_layer.add_item("WAND / DEKO")
	tile_layer.select(1)
	tile_layer.item_selected.connect(func(index: int):
		if index == 0: tile_solid.set_pressed_no_signal(false)
		_refresh_tile_label())
	layer_row.add_child(tile_layer)
	tile_solid = CheckButton.new()
	tile_solid.text = "SPERRE"
	tile_solid.tooltip_text = "Dieses Wand-/Deko-Tile blockiert die Bewegung. Boden wird immer begehbar gesetzt."
	tile_solid.toggled.connect(func(_enabled: bool): _refresh_tile_label())
	layer_row.add_child(tile_solid)
	replace_toggle = CheckButton.new()
	replace_toggle.text = "ERSETZEN"
	replace_toggle.button_pressed = true
	replace_toggle.tooltip_text = "An: Das sichtbare Tile ersetzen, einschließlich Wand, Tür oder Treppe darüber. Aus: nur die gewählte Ebene bearbeiten. Rückgängig stellt alles wieder her."
	replace_toggle.add_theme_font_size_override("font_size",PixelStyle.BODY_SIZE)
	layer_row.add_child(replace_toggle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520,424)
	body.add_child(scroll)
	palette_grid = GridContainer.new()
	palette_grid.columns = 7
	scroll.add_child(palette_grid)
	tile_label = Label.new()
	tile_label.text = "Auswahl: VIOLET017 ·0°"
	body.add_child(tile_label)
	var close := Button.new()
	close.text = "ZURÜCK ZUM RAUM"
	close.pressed.connect(palette_popup.hide)
	body.add_child(close)
	_fill_palette("violet")

func _fill_palette(group: String) -> void:
	for child: Node in palette_grid.get_children():
		palette_grid.remove_child(child)
		child.queue_free()
	for id: String in Palette.ids(group):
		var button := Button.new()
		button.custom_minimum_size = Vector2(68,48)
		button.icon = Palette.texture(id)
		button.tooltip_text = "ANIMIERT · "+Palette.display_name(id)+" · Deko wird auf vorhandenen Boden gesetzt" if group == "living" else Palette.display_name(id)+(" · Krypta-Requisite64px auf32px Raster" if group == "crypt" else " · Originalzelle16×16, als32×32 separiert")
		button.pressed.connect(func(): select_tile(id); palette_popup.hide())
		palette_grid.add_child(button)

func _show_palette() -> void:
	palette_popup.popup_centered()

## Selects a separated cell without creating game state or an implicit wall.
func select_tile(id: String) -> void:
	if not Palette.valid_id(id): return
	selected_tile = id
	if id.begins_with("living_"):
		tile_layer.select(1)
		tile_solid.set_pressed_no_signal(false)
		replace_toggle.set_pressed_no_signal(false)
	if tool_menu.selected != 9: tool_menu.select(8)
	_refresh_tile_label()
	if id.begins_with("living_"): _note("Deko wird auf vorhandenen Boden gesetzt · ERSETZEN aus · nicht blockiert")
	overlay.queue_redraw()

## The paper colour is local presentation; it never creates walkable floor.
func set_canvas_background(light: bool) -> void:
	canvas_background = Color.WHITE if light else Color.BLACK
	if background_toggle != null: background_toggle.set_pressed_no_signal(light)
	queue_redraw()
	if model != null and view != null: _refresh_room()

func _select_tool(index: int) -> void:
	tool_menu.tooltip_text = TOOL_HELP[index]
	if _painting and index == 9:
		model.end_edit()
		_painting = false
	if index != 9: clear_selection()
	slot.max_value = 5 if index == 3 else 4
	if index == 0:
		tile_layer.select(1)
		tile_solid.set_pressed_no_signal(true)
	elif index == 1:
		tile_layer.select(0)
		tile_solid.set_pressed_no_signal(false)
	_refresh_tile_label()
	_refresh_room()
	_refresh_selection_controls()
	if index == 9: _selection_note()

## Quarter-turn brush rotation. Existing tiles change only when painted again.
func rotate_brush(step: int) -> void:
	tile_rotation = posmod(tile_rotation+step,4)
	_refresh_tile_label()
	if _painting and tool_menu.selected != 9 and model.editable(_last_cell): paint_at(Vector2(_last_cell)*TILE+Vector2(16,16),_erase)
	overlay.queue_redraw()

func _refresh_tile_label() -> void:
	var layer := "BODEN" if tile_layer.selected == 0 else "WAND / DEKO"
	var direction: String = DIRECTION_NAMES[tile_rotation]
	tile_label.text = "%s · %d° · %s" % [selected_tile.to_upper(),tile_rotation*90,layer]
	if tool_menu.selected == 9:
		_selection_note()
	elif tool_menu.selected == 4:
		_note("TÜR · %s · %s · Q/E: Richtung ändern · Links setzen / rechts löschen" % [direction,selected_tile])
	else:
		_note("%s · %s · %d° · %s · Links setzen / rechts löschen" % [layer,selected_tile,tile_rotation*90,"BLOCKIERT" if tile_solid.button_pressed and tile_layer.selected != 0 else "BEGEHBAR"])
	_tool_hint.text = "%s · %s · %d° · Q/E dreht · STRG+Z/Y: Undo/Redo · STRG+S: speichern" % [selected_tile,layer,tile_rotation*90]

func _label(text: String, point: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.size = dimensions
	label.add_theme_font_size_override("font_size",maxi(PixelStyle.BODY_SIZE,roundi(float(font_size)/PixelStyle.BASE_SIZE)*PixelStyle.BASE_SIZE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	label.size = dimensions
	return label

func _option(point: Vector2, dimensions: Vector2) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.position = point
	option.size = dimensions
	option.add_theme_font_size_override("font_size",PixelStyle.BODY_SIZE)
	ui.add_child(option)
	option.size = dimensions
	return option

func _button(text: String, point: Vector2, dimensions: Vector2, action: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip if not tooltip.is_empty() else text
	button.position = point
	button.size = dimensions
	button.add_theme_font_size_override("font_size",PixelStyle.BODY_SIZE)
	button.pressed.connect(action)
	ui.add_child(button)
	button.size = dimensions
	return button

func _line(point: Vector2, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.position = point
	line.size = Vector2(264,32)
	line.placeholder_text = placeholder
	line.add_theme_font_size_override("font_size",PixelStyle.BODY_SIZE)
	ui.add_child(line)
	return line

func _select_room(index: int) -> void:
	if _syncing: return
	clear_selection()
	if not _commit_metadata():
		room_menu.select(model.selected)
		return
	model.selected = index
	_refresh_controls()
	_refresh_room()

func _refresh_controls() -> void:
	if _selection_room_id != str(model.template().id): clear_selection()
	_selection_room_id = str(model.template().id)
	_syncing = true
	room_menu.clear()
	for room: Dictionary in model.config.templates:
		room_menu.add_item(str(room.title).trim_prefix("CRYPT OF THE DAMNED · "))
	room_menu.select(model.selected)
	room_menu.tooltip_text = str(model.template().title)
	var room: Dictionary = model.template()
	var freeform: bool = room.get("layout_mode","") == "freeform"
	tool_menu.set_item_text(0,"Wand malen" if freeform else "Wand / Säule")
	tool_menu.set_item_text(1,"Boden malen" if freeform else "Boden freigeben")
	tool_menu.set_item_text(4,"Tür setzen" if freeform else "Türspur am Rand")
	tool_menu.tooltip_text = TOOL_HELP[tool_menu.selected]
	id_input.text = room.id
	title_input.text = room.title
	boss_toggle.set_pressed_no_signal(room.boss)
	width_input.value = model.room_size().x/32
	height_input.value = model.room_size().y/32
	theme_menu.select(["violet","rose","moss","amber"].find(room.get("theme",""))+1)
	_syncing = false
	_refresh_selection_controls()

func _commit_metadata() -> bool:
	if _syncing or model == null: return true
	model.begin_edit()
	var error: String = model.rename_room(id_input.text,title_input.text,boss_toggle.button_pressed)
	model.end_edit()
	if not error.is_empty():
		_note(error)
		return false
	else:
		_refresh_controls()
		_refresh_room()
	return true

func _set_theme(index: int) -> void:
	model.begin_edit()
	if index == 0: model.template().erase("theme")
	else: model.set_theme(["violet","rose","moss","amber"][index-1])
	model.end_edit()
	_refresh_room()

func _refresh_room() -> void:
	var dimensions: Vector2 = model.room_size()
	_canvas_zoom = 1.0
	while dimensions.x*_canvas_zoom > 896 or dimensions.y*_canvas_zoom > 480: _canvas_zoom *= 0.5
	view.scale = Vector2.ONE*_canvas_zoom
	var layout: Dictionary = model.preview()
	_preview_layout = layout
	_collision_cells = CollisionGrid.classify(layout)
	var players := {}
	for index in range(layout.player_spawns.size()):
		var point: Vector2 = layout.player_spawns[index]
		players[index+1] = {"x":point.x,"y":point.y,"hp":8,"max_hp":8,"color":COLORS[index % 4],"ready":false,"picked":false}
	var enemies: Array = []
	for index in range(layout.enemy_spawns.size()):
		var point: Vector2 = layout.enemy_spawns[index]
		enemies.append({"x":point.x,"y":point.y,"hp":8,"max_hp":8,"boss":layout.boss and index == 0})
	view.set_state({"room_layout":layout,"phase":"explore","players":players,"enemies":enemies,"bullets":[],"seed":0,"editor_background":canvas_background,"reference_reward":not model.template().get("blank",false) or model.template().get("reward_visible",false),"perk_options":[],"presentation_layers":{"actors":not model.template().get("blank",false),"props":true,"effects":model.template().get("layout_mode","") != "freeform"}},1)
	draft_label.text = "* UNGESPEICHERT" if model.is_dirty() else "ENTWURF GESICHERT"
	undo_button.disabled = not model.can_undo()
	redo_button.disabled = not model.can_redo()
	_update_cell_hint()
	_refresh_selection_controls()
	queue_redraw()
	overlay.queue_redraw()

func _draw_overlay() -> void:
	if model == null: return
	var bounds: Rect2 = model.room_bounds()
	var grid_color := Color(0,0,0,0.16) if canvas_background == Color.WHITE else Color(1,1,1,0.14)
	if grid_visible:
		_draw_collision_cells()
		for x in range(int(ceilf(bounds.position.x/32))*32,int(bounds.end.x)+1,32): overlay.draw_line(OFFSET+Vector2(x,bounds.position.y)*_canvas_zoom,OFFSET+Vector2(x,bounds.end.y)*_canvas_zoom,grid_color,1)
		for y in range(int(ceilf(bounds.position.y/32))*32,int(bounds.end.y)+1,32): overlay.draw_line(OFFSET+Vector2(bounds.position.x,y)*_canvas_zoom,OFFSET+Vector2(bounds.end.x,y)*_canvas_zoom,grid_color,1)
	var font := PixelStyle.create_font()
	var room: Dictionary = model.template()
	for key in ["player_spawns","enemy_spawns"]:
		if tool_menu.selected not in [2,3]: continue
		for index in range(room[key].size()):
			var value: Array = room[key][index]
			var point := OFFSET+Vector2(float(value[0]),float(value[1]))*_canvas_zoom
			var color: Color = COLORS[index % 4] if key == "player_spawns" else Color("ff9a9a")
			overlay.draw_arc(point,13,0,TAU,20,color,1.0)
			overlay.draw_string(font,point+Vector2(10,17),("P" if key == "player_spawns" else "E")+str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,PixelStyle.BODY_SIZE,color)
	for exit: Dictionary in _preview_layout.get("exits",[]):
		var rect := Rect2(float(exit.rect[0]),float(exit.rect[1]),float(exit.rect[2]),float(exit.rect[3]))
		overlay.draw_rect(Rect2(OFFSET+rect.position*_canvas_zoom,rect.size*_canvas_zoom),Color("f36e6e") if exit.get("blocked",false) else Color("72dcc8"),false,2)
	if selection_cells.has_area():
		var area := Rect2(OFFSET+Vector2(selection_cells.position)*TILE*_canvas_zoom,Vector2(selection_cells.size)*TILE*_canvas_zoom)
		overlay.draw_rect(area,Color(0.25,0.63,1,0.18))
		overlay.draw_rect(area.grow(-1),Color("79baff"),false,2)
	if model.editable(_hover) and tool_menu.selected != 9:
		if tool_menu.selected == 8 or (room.get("layout_mode","") == "freeform" and tool_menu.selected in [0,1,4]):
			Palette.draw(overlay,[{"x":_hover.x,"y":_hover.y,"tile":selected_tile,"rotation":tile_rotation}],0.65,OFFSET,_canvas_zoom)
		overlay.draw_rect(Rect2(OFFSET+Vector2(_hover)*32*_canvas_zoom,Vector2(32,32)*_canvas_zoom),Color("ffcf68"),false,2)
		if tool_menu.selected == 4:
			var center := OFFSET+(Vector2(_hover)*32+Vector2(16,16))*_canvas_zoom
			var direction: Vector2 = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][tile_rotation]
			overlay.draw_line(center,center+direction*24*_canvas_zoom,Color("ffcf68"),2)

func _refresh_selection_controls() -> void:
	if selection_replace_button == null: return
	var area_mode := tool_menu.selected == 9
	selection_replace_button.visible = area_mode
	selection_erase_button.visible = area_mode
	selection_walkable_button.visible = area_mode
	selection_block_button.visible = area_mode
	selection_replace_button.disabled = not selection_cells.has_area()
	selection_erase_button.disabled = not selection_cells.has_area()
	selection_walkable_button.disabled = not selection_cells.has_area()
	selection_block_button.disabled = not selection_cells.has_area()
	_slot_label.visible = not area_mode
	slot.visible = not area_mode
	boss_toggle.visible = not area_mode
	_remove_room_button.visible = not area_mode

func _selection_note() -> void:
	if status == null: return
	if selection_cells.has_area():
		_note("AUSWAHL: %d×%d = %d Felder · Rechts ersetzen, löschen, begehbar machen oder blockieren · Esc hebt auf." % [selection_cells.size.x,selection_cells.size.y,selection_cells.get_area()])
	else: _note("BEREICH AUSWÄHLEN: Mit Linksklick ein Rechteck aufziehen · STRG+A: ganze Fläche · Entf: Auswahl löschen · Esc: aufheben.")

## Clears only local selection presentation, without touching authored data.
func clear_selection() -> void:
	selection_cells = Rect2i()
	_selecting = false
	_refresh_selection_controls()
	if overlay != null: overlay.queue_redraw()

## Selects the whole current canvas; the model clips protected legacy edges.
func select_all_cells() -> void:
	if _painting:
		model.end_edit()
		_painting = false
	tool_menu.select(9)
	_selection_room_id = str(model.template().id)
	selection_cells = Rect2i(Vector2i.ZERO,Vector2i(model.room_size()/TILE))
	_selecting = false
	_refresh_selection_controls()
	_selection_note()
	overlay.queue_redraw()

## Applies a complete selection as one model transaction and refreshes its grid.
func apply_selection(erase: bool) -> Dictionary:
	if not selection_cells.has_area(): return {"error":"Zuerst einen Bereich auswählen.","changed":0}
	var result: Dictionary = model.edit_area(selection_cells,selected_tile,tile_rotation,tile_solid.button_pressed,"floor" if tile_layer.selected == 0 else "structure",erase,replace_toggle.button_pressed)
	if not str(result.error).is_empty():
		_show(str(result.error))
		return result
	_refresh_room()
	_note("%d Felder %s · STRG+Z macht die gesamte Aktion rückgängig." % [int(result.changed),"gelöscht" if erase else "ersetzt"])
	return result

## Changes only selected collision properties; graphics and selection survive.
## One model transaction makes the complete action reversible with STRG+Z.
func apply_selection_walkability(walkable: bool) -> Dictionary:
	if not selection_cells.has_area(): return {"error":"Zuerst einen Bereich auswählen.","changed":0}
	if model == null or not model.has_method("set_area_walkability"):
		return {"error":"Begehbarkeit konnte nicht geändert werden. Bitte den Editor neu starten.","changed":0}
	var result: Dictionary = model.set_area_walkability(selection_cells,walkable)
	if not str(result.error).is_empty():
		_show(str(result.error))
		return result
	_refresh_room()
	_note("%d Felder %s · Grafik bleibt erhalten · STRG+Z macht die gesamte Aktion rückgängig." % [int(result.changed),"begehbar gemacht" if walkable else "blockiert"])
	return result

func _canvas_cell(screen: Vector2) -> Vector2i:
	var raw := Vector2i(((screen-OFFSET)/_canvas_zoom/TILE).floor())
	return raw.clamp(Vector2i.ZERO,Vector2i(model.room_size()/TILE)-Vector2i.ONE)

func _update_selection(screen: Vector2) -> void:
	var target := _canvas_cell(screen)
	var minimum := Vector2i(mini(_selection_anchor.x,target.x),mini(_selection_anchor.y,target.y))
	var maximum := Vector2i(maxi(_selection_anchor.x,target.x),maxi(_selection_anchor.y,target.y))
	selection_cells = Rect2i(minimum,maximum-minimum+Vector2i.ONE)
	_refresh_selection_controls()
	_selection_note()
	overlay.queue_redraw()

func _selection_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if _selecting: _update_selection(event.position)
		return true
	if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return false
	if not event.pressed:
		if _selecting:
			_update_selection(event.position)
			_selecting = false
		return true
	if not Rect2(OFFSET,model.room_size()*_canvas_zoom).has_point(event.position): return true
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		clear_selection()
		return true
	_selection_anchor = _canvas_cell(event.position)
	_selecting = true
	_selection_room_id = str(model.template().id)
	_update_selection(event.position)
	return true

func _draw_collision_cells() -> void:
	for key: Vector2i in _collision_cells:
		var rect := Rect2(OFFSET+Vector2(key)*TILE*_canvas_zoom,Vector2.ONE*TILE*_canvas_zoom)
		var kind: String = _collision_cells[key].kind
		match kind:
			"walkable":
				overlay.draw_rect(rect,Color(0.13,0.91,0.40,0.17))
				overlay.draw_rect(rect.grow(-1),Color(0.10,0.98,0.35,0.75),false,1)
			"wall":
				overlay.draw_rect(rect,Color(0.98,0.16,0.18,0.29))
				overlay.draw_line(rect.position+Vector2(2,2),rect.end-Vector2(2,2),Color(1,0.22,0.25,0.72),1)
				overlay.draw_line(Vector2(rect.end.x-2,rect.position.y+2),Vector2(rect.position.x+2,rect.end.y-2),Color(1,0.22,0.25,0.72),1)
			"void":
				overlay.draw_rect(rect,Color(0.34,0.38,0.43,0.13))
				overlay.draw_line(rect.position+Vector2(2,rect.size.y-2),rect.position+Vector2(rect.size.x-2,2),Color(0.48,0.52,0.58,0.34),1)

## Read-only occupancy at a cell center; actual actor clearance remains a game rule.
func grid_cell_info(cell: Vector2i) -> Dictionary:
	return _collision_cells.get(cell,{"kind":"void","blocked":true,"reason":"Außerhalb der Zeichenfläche"}).duplicate()

func _update_cell_hint() -> void:
	if cell_hint == null: return
	cell_hint.visible = grid_visible
	if not _collision_cells.has(_hover):
		cell_hint.text = "Boden / Kollision"
		return
	var info := grid_cell_info(_hover)
	cell_hint.text = "%d,%d · %s" % [_hover.x,_hover.y,"FREI" if not info.blocked else "WAND" if info.kind == "wall" else "KEIN BODEN"]
	cell_hint.tooltip_text = str(info.reason)

func _input(event: InputEvent) -> void:
	if _selecting:
		if event is InputEventMouseMotion: _update_selection(event.position)
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_update_selection(event.position)
			_selecting = false
			overlay.queue_redraw()
	# End a stroke even when its mouse release is consumed by a UI control.
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and _painting:
		model.end_edit()
		_painting = false
		_refresh_room()

func _unhandled_input(event: InputEvent) -> void:
	if model == null or not visible or open_dialog.visible or save_dialog.visible or message.visible or palette_popup.visible: return
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
		if event.keycode == KEY_ESCAPE and selection_cells.has_area():
			clear_selection()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_DELETE,KEY_BACKSPACE] and selection_cells.has_area():
			apply_selection(true)
			get_viewport().set_input_as_handled()
			return
		if get_viewport().gui_get_focus_owner() is LineEdit: return
		if event.keycode in [KEY_Q,KEY_E]:
			rotate_brush(-1 if event.keycode == KEY_Q else 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.ctrl_pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
		match event.keycode:
			KEY_A:
				select_all_cells()
				get_viewport().set_input_as_handled()
				return
			KEY_Z: _undo()
			KEY_Y: _redo()
			KEY_S: _save_as()
	if tool_menu.selected == 9 and _selection_input(event): return
	if event is InputEventMouseMotion:
		_hover = Vector2i(((event.position-OFFSET)/_canvas_zoom/TILE).floor())
		_update_cell_hint()
		if _painting: paint_drag_to((event.position-OFFSET)/_canvas_zoom,_erase)
		overlay.queue_redraw()
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if not event.pressed:
			if _painting:
				model.end_edit()
				_painting = false
				_refresh_room()
			return
		var world: Vector2 = (event.position-OFFSET)/_canvas_zoom
		if not model.room_bounds().has_point(world): return
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null: focus.release_focus()
		model.begin_edit()
		_painting = true
		_erase = event.button_index == MOUSE_BUTTON_RIGHT
		_last_cell = Vector2i(-100,-100)
		paint_at(world,_erase)

## Shared by real pointer events and the UI integration test.
## Interpolates skipped pointer cells so fast wall strokes have no gaps.
func paint_drag_to(point: Vector2, erase: bool = false) -> void:
	var target := Vector2i((point/TILE).floor())
	var previous := _last_cell
	if tool_menu.selected not in [0,1,8] or previous.x < 0:
		paint_at(point,erase)
		return
	var steps := maxi(absi(target.x-previous.x),absi(target.y-previous.y))
	if steps == 0:
		paint_at(point,erase)
		return
	for step in range(1,mini(steps,64)+1):
		var cell := Vector2i(Vector2(previous).lerp(Vector2(target),float(step)/maxi(1,steps)).round())
		paint_at(Vector2(cell)*TILE+Vector2.ONE*TILE*0.5,erase)

## Applies a single snapped tool gesture within an authoring transaction.
func paint_at(point: Vector2, erase: bool = false) -> void:
	var cell := Vector2i((point/TILE).floor())
	var allowed: bool = model.room_bounds().has_point(point) if tool_menu.selected == 4 else model.editable(cell)
	var brush := [selected_tile,tile_rotation,tool_menu.selected,tile_layer.selected,tile_solid.button_pressed,replace_toggle.button_pressed,int(slot.value),erase,model.selected].hash()
	if not allowed or (_painting and cell == _last_cell and brush == _last_brush): return
	_last_cell = cell
	_last_brush = brush
	var center := Vector2(cell)*TILE+Vector2.ONE*TILE*0.5
	if model.template().get("layout_mode","") == "freeform":
		_paint_freeform(cell,center,erase)
		_refresh_room()
		return
	if erase and tool_menu.selected in [2,3]:
		_note("Pflicht-Startpunkte mit Linksklick an eine andere Stelle setzen.")
		return
	match tool_menu.selected:
		0,1: model.paint_wall(cell,not erase and tool_menu.selected == 0)
		2: model.set_spawn("player_spawns",int(slot.value)-1,center)
		3: model.set_spawn("enemy_spawns",int(slot.value)-1,center)
		4:
			var bounds: Rect2 = model.room_bounds()
			var distances := [absf(point.y-bounds.position.y),absf(point.x-bounds.end.x),absf(point.y-bounds.end.y),absf(point.x-bounds.position.x)]
			var index: int = distances.find(distances.min())
			if distances[index] > 64: _note("Türwerkzeug am Rand verwenden. Gegenüberliegende Türspuren bleiben passend.")
			elif erase:
				var owner: Dictionary = model.template() if model.template().has("world_size") else model.config
				owner.get("door_lanes",{}).erase("vertical" if index in [0,2] else "horizontal")
			else: model.set_door_lane(["north","east","south","west"][index],point)
		5:
			if not model.template().boss: _note("Treppen sind der Abgang eines Bossraums. Aktiviere dafür BOSSRAUM.")
			elif erase:
				model.template().erase("stairs_spawn")
				_note("Treppenposition wieder automatisch bestimmen lassen.")
			else: model.template().stairs_spawn = [center.x,center.y]
		6:
			var points: Array = model.template().get("brazier_spawns",[[72,78],[824,78],[72,402],[824,402]]).duplicate(true)
			var existing := -1
			for index in range(points.size()):
				if Vector2(points[index][0],points[index][1]).distance_to(center) < 24: existing = index
			if existing >= 0 and erase: points.remove_at(existing)
			elif existing < 0 and not erase and points.size() < 16: points.append([center.x,center.y])
			model.template().brazier_spawns = points
		7:
			model.template().reward_spawn = [model.room_size().x/2,model.room_size().y/2] if erase else [center.x,center.y]
			model.template().reward_visible = not erase
		8:
			if not erase and replace_toggle.button_pressed: model.replace_visible_tile(cell,selected_tile,tile_rotation,tile_solid.button_pressed,"floor" if tile_layer.selected == 0 else "structure")
			else: model.paint_tile(cell,"" if erase else selected_tile,tile_rotation,tile_solid.button_pressed)
	_refresh_room()

func _paint_freeform(cell: Vector2i, center: Vector2, erase: bool) -> void:
	match tool_menu.selected:
		0: _paint_selected_tile(cell,erase,true,"structure")
		1: _paint_selected_tile(cell,erase,false,"floor")
		2,3:
			var group := "player_spawns" if tool_menu.selected == 2 else "enemy_spawns"
			var index := int(slot.value)-1
			if erase:
				model.remove_spawn(group,index)
			elif index > model.template()[group].size():
				_note("Setze zuerst die vorigen Startplätze: %s%d fehlt." % ["P" if group == "player_spawns" else "E",model.template()[group].size()+1])
			else: model.set_spawn(group,index,center)
		4: model.set_authored_door(cell,DOOR_SIDES[tile_rotation],selected_tile,tile_rotation,erase)
		5:
			if not model.template().boss: _note("Aktiviere BOSSRAUM, um einen Abstieg zu setzen.")
			elif erase:
				model.template().erase("stairs_spawn")
				model.template().erase("stairs_art")
			else:
				model.template().stairs_spawn = [center.x,center.y]
				model.template().stairs_art = {"tile":selected_tile,"rotation":tile_rotation}
		6:
			var points: Array = model.template().get("brazier_spawns",[]).duplicate(true)
			var existing := -1
			for index in range(points.size()):
				if Vector2(points[index][0],points[index][1]).distance_to(center) < 24: existing = index
			if existing >= 0 and erase: points.remove_at(existing)
			elif existing < 0 and not erase and points.size() < 16: points.append([center.x,center.y])
			model.template().brazier_spawns = points
		7:
			if erase: model.template().erase("reward_spawn")
			else: model.template().reward_spawn = [center.x,center.y]
			model.template().reward_visible = not erase
		8:
			_paint_selected_tile(cell,erase,tile_solid.button_pressed,"floor" if tile_layer.selected == 0 else "structure")

func _paint_selected_tile(cell: Vector2i, erase: bool, solid: bool, layer: String) -> void:
	if not erase and replace_toggle.button_pressed:
		model.replace_visible_tile(cell,selected_tile,tile_rotation,solid,layer)
	else: model.paint_tile(cell,"" if erase else selected_tile,tile_rotation,solid,layer)

func _undo() -> void:
	clear_selection()
	model.undo()
	_refresh_controls()
	_refresh_room()
	_note("Letzte Aktion rückgängig gemacht.")

func _redo() -> void:
	clear_selection()
	model.redo()
	_refresh_controls()
	_refresh_room()
	_note("Aktion wiederholt.")

func _save_as() -> void:
	if not _commit_metadata(): return
	var directory := ProjectSettings.globalize_path("res://assets/data/custom_dungeons")
	DirAccess.make_dir_recursive_absolute(directory)
	save_dialog.current_dir = directory
	save_dialog.current_file = "dungeon_mein_entwurf.json" if _current_path.is_empty() else _current_path.get_file()
	save_dialog.popup_centered_ratio(0.7)

## Saves incomplete work too. Applying it to the game has a separate validation gate.
func save_draft(path: String) -> Dictionary:
	var destination := ProjectSettings.globalize_path(path).simplify_path().replace("\\","/").to_lower()
	var active := ProjectSettings.globalize_path(active_config_path).simplify_path().replace("\\","/").to_lower()
	if destination == active:
		var rejected := {"error":"Die aktive Spieldatei wird über IM SPIEL VERWENDEN geprüft und gesichert. Wähle für deinen Entwurf einen anderen Dateinamen."}
		last_write_result = rejected
		_show(rejected.error)
		return rejected
	var result := Store.write_config(path,model.config)
	last_write_result = result
	if result.error.is_empty():
		_current_path = path
		model.mark_saved()
		_note("Entwurf gespeichert: " + path)
	else: _show(result.error)
	_refresh_room()
	return result

## Loading an unfinished draft is reversible with Undo.
func load_draft(path: String) -> void:
	clear_selection()
	var result := Store.read_config(path)
	if not result.error.is_empty():
		_show(result.error)
		return
	model.begin_edit()
	model.config = result.config.duplicate(true)
	model.ensure_defaults()
	var previous_order: bool = model.config.has("room_order")
	model.clear_fixed_order()
	model.selected = 0
	model.end_edit()
	model.mark_saved()
	_current_path = path
	_refresh_controls()
	_refresh_room()
	_note("Raumbibliothek geladen. Rückgängig stellt den vorherigen Stand wieder her." + (" Feste Reihenfolge entfernt." if previous_order else "") + (" 16×16 auf 32×32 umgerechnet; Originaldatei unverändert." if result.get("migrated",false) else ""))

func _validate() -> bool:
	if not _commit_metadata(): return false
	var errors: PackedStringArray = model.validate()
	if errors.is_empty():
		_note("PRÜFUNG BESTANDEN: Startpunkte, Wege und Türen deiner Raumvorlagen sind verwendbar.")
		return true
	var readable: Array[String] = []
	for error: String in errors.slice(0,12):
		var translated := error.replace("Template ","Raum ").replace("needs four player and five enemy finite pixel spawn pairs","braucht vier selbst gesetzte Spielerstarts und fünf Gegnerstarts").replace("has a spawn without actor clearance","hat einen Startpunkt zu nah an einer Wand oder außerhalb des gemalten Bodens").replace("has disconnected floor or unreachable spawns","hat getrennte Bodenflächen oder nicht erreichbare Startpunkte").replace("fire is inside a wall","Feuer liegt in einer Wand oder außerhalb des Bodens").replace("reward_spawn is blocked","Belohnungstruhe liegt zu nah an einer Wand").replace("stairs_spawn is blocked","Treppenabgang liegt zu nah an einer Wand").replace("room_order references a missing room","Ebenenfolge verweist auf einen fehlenden Raum").replace("room_order must end with exactly one boss room","Die Ebenenfolge muss mit genau einem Bossraum enden").replace("Dungeon requires at least three normal templates and one boss template","Die Bibliothek benötigt mindestens drei normale Räume und einen Bossraum")
		readable.append(translated)
	_show("Bitte diese Punkte korrigieren:\n\n" + "\n".join(readable))
	return false

## The only action that replaces the active game configuration; always backed up.
func apply_to_game() -> void:
	model.begin_edit()
	model.clear_fixed_order()
	model.end_edit()
	if not _validate(): return
	var result := Store.write_config(active_config_path,model.config)
	last_write_result = result
	if not result.error.is_empty(): _show(result.error)
	else:
		model.mark_saved()
		_refresh_room()
		_show("Übernommen. Starte das Hauptspiel neu (F5), um deine Räume zu verwenden.\n\nVorheriger Stand gesichert unter:\n" + str(result.get("backup","")))

## Plays only the selected unsaved room. Library publication rules stay separate.
func _test_room() -> void:
	if is_instance_valid(_test_game): return
	if not _commit_metadata(): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/balance.json"))
	if not parsed is Dictionary:
		_show("Die Balance-Datei konnte nicht geladen werden. Dein Entwurf bleibt unverändert.")
		return
	var prepared: Dictionary = PlayPreview.prepare(model.config,model.template(),parsed)
	if not prepared.error.is_empty():
		_show(prepared.error)
		return
	clear_selection()
	_test_window_title = get_window().title
	_test_game = load("res://src/game.gd").new()
	_test_game.configure_editor_preview(model.config,prepared.layout,prepared.notice)
	_test_game.editor_return_requested.connect(_return_from_test)
	get_tree().root.add_child(_test_game)
	_test_game.start_editor_preview()
	var layer := CanvasLayer.new()
	layer.layer = 30
	_test_game.add_child(layer)
	var back := Button.new()
	back.theme = ui.theme
	back.add_theme_font_size_override("font_size",16)
	back.text = "ZUM EDITOR"
	back.tooltip_text = "Raumvorschau beenden und zum unveränderten Entwurf zurückkehren."
	back.position = Vector2(520,16)
	back.size = Vector2(240,36)
	layer.add_child(back)
	back.pressed.connect(_return_from_test)
	get_window().title = "Raum spielen · "+str(model.template().title)
	visible = false

func _return_from_test() -> void:
	if is_instance_valid(_test_game):
		_test_game._leave_session()
		_test_game.queue_free()
	_test_game = null
	visible = true
	if not _test_window_title.is_empty(): get_window().title = _test_window_title
	_refresh_room()
	_note("Vorschau beendet. Alle Raumdaten und ungespeicherten Änderungen bleiben im Editor erhalten.")

func _note(text: String) -> void:
	status.text = text
	status.tooltip_text = text

func _show(text: String) -> void:
	message.dialog_text = text
	message.popup_centered(Vector2i(900,420))

func _help() -> void:
	_show("LEERER RAUM: Boden, Wände und Türen selbst malen.\nB / H: Breite und Höhe in32px-Tiles.\nPALETTE: Grafik und Ebene wählen; SPERRE blockiert.\nERSETZEN an: sichtbare Fläche. Aus: nur eine Ebene.\nLinks malen, rechts löschen, Q/E drehen.\nSTRG+Z/Y: Undo/Redo · STRG+S: Entwurf speichern.\n\nBEREICH WÄHLEN: Rechteck ziehen oder STRG+A.\nERSETZEN / LÖSCHEN: markierte Tiles bearbeiten.\nFREI / SPERREN: nur Kollision ändern; Grafik bleibt.\nEntf löscht die Auswahl; Esc hebt sie auf.\n\nStarts, Türen und Boss-Treppe selbst setzen.\nRAUM SPIELEN öffnet die ausgewählte Vorlage.\nSichere Starts werden nur in der Vorschau ergänzt.\nBIBLIOTHEK PRÜFEN validiert den Entwurf.\nIM SPIEL NUTZEN übernimmt gültige Raumvorlagen.\nDetails: docs/DUNGEON-EDITOR.de.md.")

extends Control
## Der Weltbauer: build rooms piece by piece, outside the game but on its code and data. Parts list
## on the left, the room in the middle, the selected piece's settings on the right. Rooms are files
## in assets/data/world_rooms/<world>/; TESTEN plays the saved room in the real game in its own window,
## and the game's DEBUG menu lists them too. Started by Weltbauer.cmd.
## Usage:
##   godot --path . res://src/world_editor/world_editor.tscn

const SPAWN_MODES := {"random": "Zufällig im Raum", "manual": "Von Hand gesetzt"}
## The group of the plates a floor's riddle uses (room_floor.gd).
const FLOOR_RIDDLE := "seq"
const ENEMY_CATEGORY := "Gegner"
const BOSS_CATEGORY := "Bossgegner"
const Data = preload("res://src/world_editor/world_room_data.gd")
const Catalog = preload("res://src/world_editor/world_asset_catalog.gd")
const Templates = preload("res://src/world_editor/world_room_templates.gd")
const Art = preload("res://src/world_editor/world_art.gd")
const Canvas = preload("res://src/world_editor/world_room_canvas.gd")
const Grid = preload("res://src/world_editor/world_asset_grid.gd")
const LaunchPads = preload("res://src/hell/launch_pads.gd")
const Monsters = preload("res://src/hell/hell_monsters.gd")
const Graphics = preload("res://src/core/graphics_settings.gd")
const Gates = preload("res://src/world_editor/world_gates.gd")
const Contents = preload("res://src/world_kit/room_contents.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const WINDOW := Vector2i(1600, 900)
const GROUPS := ["A", "B", "C", "D", "E", "F"]
## What a generator's crate may hold.
const CRATE_DROPS := {"random": "Zufällig (die Etage entscheidet)", "none": "Nichts", "gem": "Gold", "heart": "Herz", "undead": "Untote der Etage"}
const DIRS := {"n": "Nach oben", "e": "Nach rechts", "s": "Nach unten", "w": "Nach links"}
const LAYERS := {"floor": "Boden (unter allem)", "normal": "Normal (nach Tiefe)", "front": "Vordergrund (über allem)"}
const ALL := "Alle"
const FONT_SIZE := 14
## The tool in use stands out.
const LIT := Color(1.0, 0.85, 0.45)

var catalog: RefCounted
var art: RefCounted
var world: String = "krypta"
var view: String = "pixel"
var room: Dictionary = {}
var rooms: Array = []
var dirty := false
var _arts := {}
var _cat_filter := ALL
var _tab := "krypta"
var _entries: Array = []

var canvas: Control
var grid: Control
var _room_pick: OptionButton
var _world_pick: OptionButton
var _hero_pick: OptionButton
var _view_button: Button
var _coverage: Label
var _tab_pick: OptionButton
var _cat_pick: OptionButton
var _search: LineEdit
var _status: Label
var _hint: Label
var _problems: Label
var _inspector: VBoxContainer
var _room_box: VBoxContainer
var _brush_row: HFlowContainer
var _title_edit: LineEdit
var _floors_check: CheckBox
var _role_pick: OptionButton
var _w_spin: SpinBox
var _h_spin: SpinBox
var _mobs_spin: SpinBox
var _spawn_pick: OptionButton
var _spawn_note: Label
var _template_menu: PopupMenu
var _tool_buttons := {}
var _size_buttons := {}


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().title = "Weltbauer"
	if DisplayServer.get_name() != "headless":
		get_window().size = WINDOW
		get_window().move_to_center()
	theme = CryptUI.create_theme()
	theme.default_font_size = FONT_SIZE
	for type: String in ["Button", "Label", "OptionButton", "LineEdit", "CheckBox", "PopupMenu", "SpinBox"]:
		theme.set_font_size("font_size", type, FONT_SIZE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	view = Graphics.mode()
	catalog = Catalog.new()
	_build()
	_open_world(world)
	_set_tool("select")
	_set_brush_size(1)


## Closing the window keeps what was built.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and dirty and not room.is_empty():
		_save()


# ---------- layout ----------

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color("11131b")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 4)
	add_child(page)
	page.add_child(_top_bar())
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(middle)
	middle.add_child(_left_side())
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.clip_contents = true
	middle.add_child(center)
	center.add_child(_tool_bar())
	canvas = Canvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.catalog = catalog
	canvas.changed.connect(_on_changed)
	canvas.selected.connect(func(_o: Dictionary) -> void: _fill_inspector())
	canvas.hover_text.connect(func(t: String) -> void: _status.text = t)
	center.add_child(canvas)
	middle.add_child(_right_side())
	_hint = Label.new()
	_hint.clip_text = true
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.text = "Teil links anklicken, dann in den Raum klicken. Rechte Maustaste löscht, Mausrad zoomt, mittlere Maustaste verschiebt, Umschalt + Ziehen malt ein Rechteck."
	var foot := HBoxContainer.new()
	_status = Label.new()
	_status.custom_minimum_size.x = 140
	foot.add_child(_status)
	foot.add_child(_hint)
	page.add_child(foot)
	_template_menu = PopupMenu.new()
	add_child(_template_menu)
	_template_menu.id_pressed.connect(_on_template)


func _top_bar() -> Control:
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 6)
	_world_pick = OptionButton.new()
	for id: String in Data.WORLDS:
		_world_pick.add_item(str(Data.WORLDS[id].name))
		_world_pick.set_item_metadata(_world_pick.item_count - 1, id)
	_world_pick.item_selected.connect(func(i: int) -> void: _leave_then(func() -> void: _open_world(str(_world_pick.get_item_metadata(i)))))
	bar.add_child(_world_pick)
	_room_pick = OptionButton.new()
	_room_pick.custom_minimum_size.x = 240
	_room_pick.item_selected.connect(func(i: int) -> void: _leave_then(func() -> void: _open_room(rooms[i])))
	bar.add_child(_room_pick)
	bar.add_child(_button("NEU", _new_room))
	bar.add_child(_button("VORLAGE", _show_templates))
	bar.add_child(_button("KOPIE", _copy_room))
	bar.add_child(_button("LÖSCHEN", _delete_room))
	bar.add_child(_button("SPEICHERN", _save))
	_view_button = _button("", _toggle_view)
	_view_button.custom_minimum_size.x = 150
	bar.add_child(_view_button)
	_hero_pick = OptionButton.new()
	bar.add_child(_hero_pick)
	var test := _button("TESTEN (F5)", _test_room)
	test.add_theme_color_override("font_color", Color("7fe08a"))
	bar.add_child(test)
	return bar


func _left_side() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 360
	_tab_pick = OptionButton.new()
	box.add_child(_tab_pick)
	_tab_pick.item_selected.connect(func(i: int) -> void:
		_tab = str(_tab_pick.get_item_metadata(i))
		_cat_filter = ALL
		_fill_parts())
	var row := HBoxContainer.new()
	_cat_pick = OptionButton.new()
	_cat_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cat_pick.item_selected.connect(func(i: int) -> void:
		_cat_filter = _cat_pick.get_item_text(i).get_slice(" (", 0)
		_show_parts())
	row.add_child(_cat_pick)
	box.add_child(row)
	_search = LineEdit.new()
	_search.placeholder_text = "Suchen …"
	_search.text_changed.connect(func(_t: String) -> void: _show_parts())
	box.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	grid = Grid.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.scroll = scroll
	grid.picked.connect(_on_part)
	grid.hovered.connect(func(t: String) -> void: if t != "": _hint.text = t)
	scroll.add_child(grid)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: grid.queue_redraw())
	return box


func _tool_bar() -> Control:
	_brush_row = HFlowContainer.new()
	_tool_buttons["select"] = _button("AUSWÄHLEN", func() -> void: _set_tool("select"))
	_brush_row.add_child(_tool_buttons["select"])
	_tool_buttons["erase"] = _button("ENTFERNEN", func() -> void: _set_tool("erase"))
	_brush_row.add_child(_tool_buttons["erase"])
	_tool_buttons["port"] = _button("TÜRSTELLE", func() -> void: _set_tool("port"))
	_brush_row.add_child(_tool_buttons["port"])
	var port_pick := OptionButton.new()
	for use: String in Data.PORT_USES:
		port_pick.add_item(str(Data.PORT_USES[use]))
		port_pick.set_item_metadata(port_pick.item_count - 1, use)
	port_pick.tooltip_text = "Was die nächste Türstelle ist."
	port_pick.item_selected.connect(func(i: int) -> void:
		canvas.port_use = str(port_pick.get_item_metadata(i))
		_set_tool("port"))
	_brush_row.add_child(port_pick)
	var size_label := Label.new()
	size_label.text = "  Pinsel"
	_brush_row.add_child(size_label)
	for n: int in [1, 2, 3, 5]:
		_size_buttons[n] = _button(str(n), func() -> void: _set_brush_size(n))
		_brush_row.add_child(_size_buttons[n])
	var grid_box := CheckBox.new()
	grid_box.text = "Raster"
	grid_box.button_pressed = true
	grid_box.toggled.connect(func(on: bool) -> void: canvas.grid_on = on)
	_brush_row.add_child(grid_box)
	var feet_box := CheckBox.new()
	feet_box.text = "Kollision"
	feet_box.button_pressed = true
	feet_box.toggled.connect(func(on: bool) -> void: canvas.feet_on = on)
	_brush_row.add_child(feet_box)
	_brush_row.add_child(_button("ZURÜCK", func() -> void: canvas.undo()))
	_brush_row.add_child(_button("VOR", func() -> void: canvas.redo()))
	_brush_row.add_child(_button("EINPASSEN", func() -> void: canvas.fit()))
	return _brush_row


func _right_side() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 290
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_heading("RAUM"))
	_room_box = VBoxContainer.new()
	box.add_child(_room_box)
	_title_edit = LineEdit.new()
	_title_edit.text_changed.connect(func(t: String) -> void:
		room.title = t
		_mark_dirty())
	_room_box.add_child(_row("Name", _title_edit))
	_role_pick = OptionButton.new()
	for id: String in Data.ROLES:
		_role_pick.add_item(str(Data.ROLES[id]))
		_role_pick.set_item_metadata(_role_pick.item_count - 1, id)
	_role_pick.item_selected.connect(func(i: int) -> void:
		room.role = str(_role_pick.get_item_metadata(i))
		_mark_dirty())
	_room_box.add_child(_row("Raumart", _role_pick))
	_floors_check = CheckBox.new()
	_floors_check.text = "In Etagen verwenden"
	_floors_check.toggled.connect(func(on: bool) -> void:
		room.in_floors = on
		_mark_dirty())
	_room_box.add_child(_floors_check)
	_w_spin = _spin(Data.MIN_SIZE.x, Data.MAX_SIZE.x, _resize_room)
	_h_spin = _spin(Data.MIN_SIZE.y, Data.MAX_SIZE.y, _resize_room)
	_room_box.add_child(_row("Breite", _w_spin))
	_room_box.add_child(_row("Höhe", _h_spin))
	_mobs_spin = _spin(0, 30, func(v: float) -> void:
		room.auto_mobs = int(v)
		_mark_dirty())
	_spawn_pick = OptionButton.new()
	for id: String in SPAWN_MODES:
		_spawn_pick.add_item(str(SPAWN_MODES[id]))
		_spawn_pick.set_item_metadata(_spawn_pick.item_count - 1, id)
	_spawn_pick.item_selected.connect(func(i: int) -> void:
		room.spawn_mode = str(_spawn_pick.get_item_metadata(i))
		_show_spawn_mode()
		_mark_dirty())
	_room_box.add_child(_row("Gegner", _spawn_pick))
	_room_box.add_child(_row("Zufallsgegner", _mobs_spin))
	_spawn_note = Label.new()
	_spawn_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spawn_note.custom_minimum_size.x = 280
	_spawn_note.modulate = Color(0.75, 0.78, 0.86)
	_room_box.add_child(_spawn_note)
	var door_note := Label.new()
	door_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	door_note.custom_minimum_size.x = 280
	door_note.modulate = Color(0.75, 0.78, 0.86)
	door_note.text = "Türen entstehen nur an Türstellen. Beispiel: links Eingang, rechts Ausgang ergibt einen Raum zum Durchqueren. Geht es nur andersherum, wird der Ausgang zum Eingang. Wenige Türstellen machen den Raum seltener."
	_room_box.add_child(door_note)
	_coverage = Label.new()
	_coverage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coverage.custom_minimum_size.x = 280
	_coverage.modulate = Color(0.75, 0.78, 0.86)
	box.add_child(_heading("PIXEL UND HD"))
	box.add_child(_coverage)
	box.add_child(_heading("PRÜFUNG"))
	_problems = Label.new()
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems.custom_minimum_size.x = 280
	box.add_child(_problems)
	box.add_child(_heading("GEWÄHLTES TEIL"))
	_inspector = VBoxContainer.new()
	box.add_child(_inspector)
	return scroll


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("edbf75"))
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _spin(low: float, high: float, action: Callable, step := 1.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value_changed.connect(action)
	return s


func _row(label: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 112
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


# ---------- worlds, rooms, views ----------

func _art_for(id: String, mode: String) -> RefCounted:
	var key := id + "|" + mode
	if not _arts.has(key):
		_arts[key] = Art.new(id, mode)
	return _arts[key]


func _open_world(id: String) -> void:
	world = id
	_tab = id
	art = _art_for(id, view)
	for i in range(_world_pick.item_count):
		if str(_world_pick.get_item_metadata(i)) == id:
			_world_pick.select(i)
	_fill_tabs()
	_fill_heroes()
	_fill_parts()
	_show_coverage()
	rooms = Data.list_rooms(id)
	if rooms.is_empty():
		rooms = [Data.fresh(id, "Erster Raum")]
		dirty = true
	_open_room(rooms[0])


func _fill_tabs() -> void:
	_tab_pick.clear()
	_tab_pick.add_item(str(Data.WORLDS[world].name))
	_tab_pick.set_item_metadata(0, world)
	_tab_pick.add_item("Weitere Assets")
	_tab_pick.set_item_metadata(1, Catalog.OTHER)
	_tab_pick.select(0)


func _fill_heroes() -> void:
	_hero_pick.clear()
	var classes: Dictionary = art.theme.get("classes", {})
	for id: String in classes:
		_hero_pick.add_item(str((classes[id] as Dictionary).get("name", id)))
		_hero_pick.set_item_metadata(_hero_pick.item_count - 1, id)


## Shows the room's spawn choice and what it means.
func _show_spawn_mode() -> void:
	var mode := Data.spawn_mode(room)
	for i in range(_spawn_pick.item_count):
		if str(_spawn_pick.get_item_metadata(i)) == mode:
			_spawn_pick.select(i)
	_mobs_spin.editable = mode == "random"
	if str(room.get("role", "")) == "boss":
		_spawn_note.text = "Im Bossraum setzt die Etage den Boss. Zufällig: seine Begleiter (Anzahl 0 = wie sie die Etage vorgibt). Gesetzte Gegner zählen nur beim Einzeltest."
	elif mode == "manual":
		_spawn_note.text = "Es kommen genau die Gegner, die du aus der Kategorie Gegner in den Raum setzt. Beispiel: 2 Skelette links, 1 Nekromant rechts. Ohne gesetzte Gegner gibt es keinen Kampf, außer der Raum muss auf der Etage einen Schlüssel fallen lassen."
	else:
		_spawn_note.text = "Das Spiel verteilt die Gegner beim Betreten zufällig im Raum. Zufallsgegner ist ihre Anzahl, zum Beispiel 5. Bei 0 bestimmt die Etage die Anzahl. Gesetzte Gegner bleiben gespeichert, kommen aber nicht."


## The parts of the chosen tab: ground and game pieces first in a world, then every picture.
func _fill_parts() -> void:
	_entries = []
	if _tab != Catalog.OTHER:
		for part: Dictionary in catalog.cfg.parts:
			_entries.append(part.duplicate(true))
		_entries.append_array(_monster_parts())
	_entries.append_array(catalog.entries(_tab, art.theme))
	var counts := {}
	for e: Dictionary in _entries:
		counts[str(e.cat)] = int(counts.get(str(e.cat), 0)) + 1
	_cat_pick.clear()
	_cat_pick.add_item("%s (%d)" % [ALL, _entries.size()])
	var names: Array = ["Gelände", ENEMY_CATEGORY, BOSS_CATEGORY, "Spielteile", "Fallen"]
	names.append_array(catalog.category_names())
	names = names.filter(func(n: String) -> bool: return counts.has(n))
	for n: String in counts:
		if not names.has(n):
			names.append(n)
	for name: String in names:
		_cat_pick.add_item("%s (%d)" % [name, int(counts[name])])
	var kept := _cat_filter
	_cat_filter = ALL
	_cat_pick.select(0)
	for i in range(_cat_pick.item_count):
		if _cat_pick.get_item_text(i).get_slice(" (", 0) == kept:
			_cat_filter = kept
			_cat_pick.select(i)
	_show_parts()


## The world's enemies, in two categories of their own: common ones and bosses, by their names.
func _monster_parts() -> Array:
	var out: Array = []
	var defs := _monster_defs()
	for id: String in defs:
		var def: Dictionary = defs[id]
		out.append({"kind": "enemy", "mob": id, "label": str(def.get("name", id)), "cat": BOSS_CATEGORY if str(def.get("kind", "")) == "boss" else ENEMY_CATEGORY})
	return out


func _monster_defs() -> Dictionary:
	if art.theme.has("mobs"):
		return art.theme.mobs
	var balance: Dictionary = DataCache.load_dict(str(art.theme.get("balance", "")))
	var section: Dictionary = balance.get("monsters", {})
	return DataCache.load_dict(str(section.get("data", Monsters.DATA_PATH))).get("defs", {})


func _show_parts() -> void:
	var query := _search.text.strip_edges().to_lower()
	var list: Array = _entries.filter(func(e: Dictionary) -> bool:
		if _cat_filter != ALL and str(e.cat) != _cat_filter:
			return false
		return query == "" or str(e.label).to_lower().contains(query) or str(e.get("folder", "")).to_lower().contains(query))
	grid.show_entries(list, art)


func _on_part(e: Dictionary) -> void:
	var kind := str(e.get("kind", "prop"))
	canvas.brush = e
	# who picks an enemy to set wants enemies by hand
	if kind == "enemy" and Data.spawn_mode(room) != "manual":
		room.spawn_mode = "manual"
		_show_spawn_mode()
		_mark_dirty()
	if kind in ["gate", "secret"]:
		_set_tool("place")
		_hint.text = "%s: auf eine Mauer klicken. Die Mauer öffnet sich dort, und ob es oben/unten oder links/rechts steht, ergibt sich aus der Mauer. Grün zeigt die Stelle." % str(e.label)
	elif Canvas.TERRAIN.has(kind):
		_set_tool(kind)
		_hint.text = "%s: links malen, rechts zurücknehmen, Umschalt + Ziehen für ein Rechteck. Nebeneinander wächst alles zusammen." % str(e.label)
	elif bool(e.get("area", false)):
		_set_tool("area")
		_hint.text = "%s als Fläche: Felder daneben wachsen zu einer Fläche zusammen, ohne Kanten dazwischen." % str(e.label)
	else:
		_set_tool("place")
		_hint.text = "%s: in den Raum klicken zum Setzen (Alt: frei ohne Raster)." % str(e.label)


func _set_tool(value: String) -> void:
	canvas.tool = value
	if value == "port":
		_hint.text = "Türstelle: in die Mauer klicken. Grün Eingang, rot Ausgang, gelb beides. Nochmal klicken entfernt sie."
	for key: String in _tool_buttons:
		(_tool_buttons[key] as Button).modulate = LIT if key == value else Color.WHITE


func _set_brush_size(value: int) -> void:
	canvas.brush_size = value
	for key: int in _size_buttons:
		(_size_buttons[key] as Button).modulate = LIT if key == value else Color.WHITE


func _show_coverage() -> void:
	var c: Dictionary = Catalog.coverage(art.theme)
	var missing: int = (c.hd_only as Array).size()
	_view_button.text = "ANSICHT: %s" % str(Graphics.LABELS.get(view, view))
	_coverage.text = "%d Grafiken in beiden Ansichten\n%d nur HD: in Pixel automatisch gerastert\n%d nur Pixel: in HD unverändert" % [int(c.both), missing, (c.pixel_only as Array).size()]


## Pixel and HD: the same room in the other set, the same setting the game reads.
func _toggle_view() -> void:
	view = Graphics.other(view)
	Graphics.store(view)
	art = _art_for(world, view)
	_show_coverage()
	_fill_parts()
	canvas.show_room(room, art)


func _open_room(value: Dictionary) -> void:
	room = value
	room.erase("_path")
	dirty = false
	_room_pick.clear()
	for r: Dictionary in rooms:
		_room_pick.add_item(str(r.title))
	var at := rooms.find(value)
	if at >= 0:
		_room_pick.select(at)
	_title_edit.text = str(room.title)
	for i in range(_role_pick.item_count):
		if str(_role_pick.get_item_metadata(i)) == str(room.get("role", "combat")):
			_role_pick.select(i)
	_floors_check.set_pressed_no_signal(bool(room.get("in_floors", false)))
	_w_spin.set_value_no_signal(int(room.width))
	_h_spin.set_value_no_signal(int(room.height))
	_mobs_spin.set_value_no_signal(int(room.get("auto_mobs", 0)))
	_show_spawn_mode()
	canvas.show_room(room, art)
	_fill_inspector()
	_check_room()


func _leave_then(action: Callable) -> void:
	if dirty and not room.is_empty():
		_save()
	action.call()


func _new_room() -> void:
	_leave_then(func() -> void:
		var r := Data.fresh(world, "Raum %d" % (rooms.size() + 1))
		rooms.append(r)
		_open_room(r)
		_mark_dirty())


func _copy_room() -> void:
	_leave_then(func() -> void:
		var r: Dictionary = room.duplicate(true)
		r.title = str(room.title) + " Kopie"
		r.id = Data.new_id(str(r.title))
		rooms.append(r)
		_open_room(r)
		_mark_dirty())


func _delete_room() -> void:
	Data.remove(room)
	rooms.erase(room)
	if rooms.is_empty():
		rooms = [Data.fresh(world, "Erster Raum")]
	_open_room(rooms[0])
	_hint.text = "Raum gelöscht."


func _show_templates() -> void:
	_template_menu.clear()
	var list: Array = catalog.cfg.templates
	for i in range(list.size()):
		_template_menu.add_item(str(list[i].label), i)
	_template_menu.position = get_viewport().get_mouse_position()
	_template_menu.popup()


func _on_template(id: int) -> void:
	var spec: Dictionary = catalog.cfg.templates[id]
	_leave_then(func() -> void:
		var made := Templates.make(world, str(spec.gtype), str(spec.label))
		if made.is_empty():
			_hint.text = "Diese Welt hat keine %s." % str(spec.label)
			return
		rooms.append(made)
		_open_room(made)
		_mark_dirty()
		_hint.text = "%s als Vorlage geladen: alles darin lässt sich ändern." % str(spec.label))


func _resize_room(_v: float) -> void:
	canvas.checkpoint()
	Data.resize(room, Vector2i(int(_w_spin.value), int(_h_spin.value)))
	canvas.refresh()
	canvas.fit()
	_on_changed()


func _save() -> void:
	var error := Data.save(room)
	if error != "":
		_hint.text = error
		return
	dirty = false
	_hint.text = "Gespeichert: %s" % Data.path_of(str(room.world), str(room.id))
	var at := rooms.find(room)
	if at >= 0 and at < _room_pick.item_count:
		_room_pick.set_item_text(at, str(room.title))
	get_window().title = "Weltbauer"


## Saves and plays the room in the real game, in a window of its own.
func _test_room() -> void:
	var trouble := Data.problems(room)
	if not trouble.is_empty():
		_hint.text = trouble[0]
		return
	_save()
	var hero := str(_hero_pick.get_item_metadata(_hero_pick.selected)) if _hero_pick.selected >= 0 else ""
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--windowed", "--", "--world-room", Data.path_of(str(room.world), str(room.id)), "--hero", hero])
	OS.create_process(OS.get_executable_path(), args)
	_hint.text = "Das Spiel startet mit deinem Raum. F9 lädt ihn dort neu, sobald du wieder gespeichert hast."


func _mark_dirty() -> void:
	dirty = true
	get_window().title = "Weltbauer *"


func _on_changed() -> void:
	_mark_dirty()
	_check_room()
	_fill_inspector()


func _check_room() -> void:
	var lines: Array = []
	for t: String in Data.problems(room):
		lines.append("FEHLER: " + t)
	if lines.is_empty():
		lines.append("Spielbar")
	for t: String in Data.hints(room):
		lines.append("Hinweis: " + t)
	_problems.text = "\n".join(lines)
	_problems.add_theme_color_override("font_color", Color("e0584a") if str(lines[0]).begins_with("FEHLER") else Color("9fd8a8"))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k.pressed or k.echo or get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit:
		return
	match k.keycode:
		KEY_Z:
			if k.ctrl_pressed: canvas.undo()
		KEY_Y:
			if k.ctrl_pressed: canvas.redo()
		KEY_S:
			if k.ctrl_pressed: _save()
		KEY_D:
			if k.ctrl_pressed: canvas.duplicate_picked()
		KEY_DELETE:
			canvas.delete_picked()
		KEY_F5:
			_test_room()
		KEY_F:
			_flip_picked()
		KEY_ESCAPE:
			_set_tool("select")


func _flip_picked() -> void:
	var o: Dictionary = canvas.picked
	if not o.is_empty() and str(o.kind) == "prop":
		canvas.checkpoint()
		o.flip = not bool(o.get("flip", false))
		_touched()


func _touched() -> void:
	canvas.refresh()
	_mark_dirty()
	_check_room()


# ---------- settings of the selected piece ----------

func _fill_inspector() -> void:
	for child: Node in _inspector.get_children():
		_inspector.remove_child(child)
		child.queue_free()
	var o: Dictionary = canvas.picked
	if o.is_empty():
		var none := Label.new()
		none.text = "Nichts gewählt. Mit AUSWÄHLEN oder nach dem Setzen erscheint es hier."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 280
		_inspector.add_child(none)
		return
	var title := Label.new()
	title.text = str(o.get("asset", o.get("mob", o.kind))).get_file()
	for part: Dictionary in catalog.cfg.parts:
		if str(part.kind) == str(o.kind):
			title.text = str(part.label)
	title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	title.custom_minimum_size.x = 280
	_inspector.add_child(title)
	match str(o.kind):
		"prop":
			_choice(o, "layer", "Ebene", LAYERS, "normal")
			_check(o, "block", "Blockiert den Weg")
			if bool(o.get("block", false)):
				var foot: Array = o.get("foot", [60, 30])
				_number("Fußbreite", float(foot[0]), 4.0, 600.0, 2.0, func(v: float) -> void:
					o.foot = [v, float((o.get("foot", [60, 30]) as Array)[1])])
				_number("Fußhöhe", float(foot[1]), 4.0, 300.0, 2.0, func(v: float) -> void:
					o.foot = [float((o.get("foot", [60, 30]) as Array)[0]), v])
				_note("Fußbreite und Fußhöhe sind die Fläche in Punkten, die den Weg sperrt (roter Rahmen). 96 Punkte sind ein Feld.")
			_check(o, "flip", "Gespiegelt")
			_number("Größe", float(o.get("scale", 1.0)), 0.1, 8.0, 0.1, func(v: float) -> void: o.scale = v)
			_number("Breite", float(o.get("scale_w", 1.0)), 0.1, 8.0, 0.1, func(v: float) -> void: o.scale_w = v)
			_number("Höhe", float(o.get("scale_h", 1.0)), 0.1, 8.0, 0.1, func(v: float) -> void: o.scale_h = v)
			_note("Größe ändert das Bild gleichmäßig, Breite und Höhe nur in eine Richtung. 1 ist die Originalgröße, 2 doppelt so groß, 0,5 halb so groß. Beispiel: Beim Teppich macht Breite 1 und Höhe 3 einen dreimal so langen Läufer.")
			if o.has("frames"):
				_number("Bilder/Sek.", float(o.get("fps", 8.0)), 1.0, 30.0, 1.0, func(v: float) -> void: o.fps = v)
			_loot(o, "Inhalt beim Zerbrechen")
			_enemy_slots(o, "Kommen beim Zerbrechen heraus und lassen die Gitter fallen. Inhalt und Gegner gelten nur für Teile, die zerbrechen, etwa Vasen und Fässer.")
			_text_group(o, "opens", "Öffnet Gruppe")
			_note("Öffnet Gruppe: Zerbricht das Teil, öffnet sich jedes Tor und jeder Geheimgang dieser Gruppe in diesem Raum.")
		"launch":
			_choice(o, "dir", "Richtung", DIRS, "n")
			var cfg: Dictionary = LaunchPads.load_config()
			_number("Felder weit", float(o.get("cells", cfg.default_cells)), 1.0, float(cfg.max_cells), 1.0, func(v: float) -> void: o.cells = int(v))
			_note("Wirft den Helden in die Richtung, auch über Mauern und Gruben. Beispiel: Richtung oben, 5 Felder: Er landet 5 Felder weiter oben. Ist dort Mauer, landet er kurz davor. Grube, Moder und Stacheln sind erlaubt, das sind dann Fallen.")
			_text_group(o, "wake", "Wacht auf mit")
			_note("Wacht auf mit: Die Platte schläft dunkel und wirft nicht, bis diese Gruppe gelöst ist, etwa durch Druckplatten, eine Hebel-Fackel oder Feuerschalen derselben Gruppe. So entsteht ein Weg erst nach dem ersten Rätsel.")
		"plate":
			_group(o)
			if str(o.get("group", "A")) == FLOOR_RIDDLE:
				_note("Rätsel der Etage (Zeichen ET): Sechs solche Platten in einem geraden Raum bieten ihn der Etage als Rätselraum an. Wählt sie ihn, nimmt sie 4 bis 6 davon und würfelt die Reihenfolge. Gelöst öffnet sich das Gitter zu einem Riesentresor oder ein verborgener Gang zu einer versteckten Kammer, beides nebenan. Wählt sie ihn nicht, fehlen die Platten im Spiel. Beim Einzeltest öffnen sie nichts.")
			else:
				_number("Reihenfolge", float(o.get("order", 0)), 0.0, 16.0, 1.0, func(v: float) -> void: o.order = int(v))
				_note("0 = beliebig. 1, 2, 3 … = in dieser Reihenfolge betreten.")
				_note("Gruppe: Sind alle Platten der Gruppe betreten, öffnet sich Tor oder Geheimgang derselben Gruppe in diesem Raum. Beispiel: 3 Platten und ein Tor, alle mit Gruppe A.")
				if int(o.get("order", 0)) > 0:
					_enemy_slots(o, "Strafe: Wird diese Platte in falscher Reihenfolge betreten, kommen diese Gegner heraus, einmal. Eine Fallenplatte bekommt eine Nummer, die nie dran ist, etwa 9.")
		"lever":
			_group(o)
			_note("Gruppe: Die Fackel öffnet Tor oder Geheimgang derselben Gruppe in diesem Raum.")
		"brazier":
			_group(o)
			_note("Gruppe: Brennen alle Schalen der Gruppe, öffnet sich Tor oder Geheimgang derselben Gruppe. Das gilt nur in diesem Raum. Die Feuerschalen über die ganze Etage setzt die Etage selbst.")
		"skullheap":
			_group(o)
			_number("Treffer", float(o.get("hp", 3)), 1.0, 20.0, 1.0, func(v: float) -> void: o.hp = int(v))
			_note("Zerfällt nach den Treffern und öffnet den Geheimgang derselben Gruppe.")
		"gate":
			_choice(o, "style", "Art", Gates.labels_for(str(room.world)), Gates.DEFAULT_STYLE)
			_note("Steht in einer Mauer %s. Zum Verlegen auf eine andere Mauer ziehen." % ("mit Weg nach links/rechts" if str(o.get("dir", "v")) == "h" else "mit Weg nach oben/unten"))
			if Gates.closes(o):
				_group(o)
				_choice(o, "lock", "Schlüssel", {"": "Keiner (Rätseltor)", "A": "A", "B": "B", "C": "C"}, "")
			else:
				_note("Offener Durchgang: ohne Rätsel immer begehbar.")
		"secret":
			_note("Steht in einer Mauer %s. Zum Verlegen auf eine andere Mauer ziehen." % ("mit Weg nach links/rechts" if str(o.get("dir", "v")) == "h" else "mit Weg nach oben/unten"))
			_group(o)
			_note("Sieht im Spiel aus wie Mauer, bis Gruppe %s gelöst ist." % str(o.get("group", "A")))
		"chest":
			_loot(o, "Inhalt")
			_mimic_options(o)
			_enemy_slots(o, "Kommen beim Öffnen heraus und lassen die Gitter fallen.")
		"raw":
			var piece: Dictionary = o.ent
			if str(piece.get("type", "")) == "crate":
				_choice(piece, "drop", "Inhalt", CRATE_DROPS, "random")
				_enemy_slots(piece, "Kommen beim Zerbrechen heraus und lassen die Gitter fallen.")
		"tablet":
			var words := TextEdit.new()
			words.text = str(o.get("text", ""))
			words.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			words.custom_minimum_size = Vector2(280, 150)
			words.text_changed.connect(func() -> void:
				o.text = words.text
				_touched())
			words.focus_entered.connect(func() -> void: canvas.checkpoint())
			_inspector.add_child(_row("Text", words))
			_note("Steht der Held am Stein, liest er den Text oben im Bild. Zeilenumbrüche bleiben. Gut für Rätsel und Hinweise.")
		"key":
			_choice(o, "key", "Schlüssel", {"A": "A", "B": "B", "C": "C"}, "A")
		"spikes":
			_number("Takt", float(o.get("phase", 0)), 0.0, 1.0, 1.0, func(v: float) -> void: o.phase = int(v))
			var spike_time: float = float(_hazards().get("spike_period", 1.2))
			_note("Die Stacheln wechseln alle %s Sekunden zwischen oben und unten. Takt 0 und Takt 1 sind immer gegensätzlich: Sind die Stacheln mit Takt 0 oben, sind die mit Takt 1 unten, und umgekehrt." % _seconds(spike_time))
			_note("Beispiel: Setzt du Felder abwechselnd auf Takt 0 und 1, entsteht ein Schachbrett. Stehen alle auf Takt 0, fahren alle zugleich hoch, und man läuft im freien Moment hindurch.")
		"vent":
			_number("Versatz (s)", float(o.get("offset", 0.0)), 0.0, 8.0, 0.25, func(v: float) -> void: o.offset = v)
			var vent_time: float = float(_hazards().get("vent_period", 3.0))
			_note("Der Schacht stößt alle %s Sekunden für %s Sekunden Dampf aus. Der Versatz verschiebt den Zeitpunkt." % [_seconds(vent_time), _seconds(float(_hazards().get("vent_burst", 0.9)))])
			_note("Beispiel: Zwei Schächte mit Versatz 0 und %s stoßen abwechselnd aus." % _seconds(vent_time * 0.5))
		"enemy":
			var kinds := {}
			var defs := _monster_defs()
			for id: String in defs:
				kinds[id] = str((defs[id] as Dictionary).get("name", id))
			_choice(o, "mob", "Gegner", kinds, str(o.get("mob", "")))
			if Contents.is_chest_mob(str(o.get("mob", ""))):
				_note("Steht im Spiel als gewöhnliche Truhe da und wird erst beim Öffnen zum Monster. Das gilt in beiden Gegner-Arten des Raums. Im Weltbauer zeigt ein roter Ring und M die Falle.")
			else:
				_note("Steht genau hier und wacht auf, sobald der Held im Raum ist. Die Tore fallen, bis alle besiegt sind.")
			if Data.spawn_mode(room) != "manual" and not Contents.is_chest_mob(str(o.get("mob", ""))):
				_note("Der Raum steht auf „Zufällig“, dieser Gegner kommt deshalb nicht. Stelle rechts oben „Von Hand gesetzt“ ein.")
	_inspector.add_child(_button("LÖSCHEN (Entf)", func() -> void: canvas.delete_picked()))


## The world's timing of its floor traps (balance.hazards).
func _hazards() -> Dictionary:
	return DataCache.load_dict(str(art.theme.get("balance", ""))).get("hazards", {})


## A number of seconds as German text: 1,2.
func _seconds(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".").replace(".", ",")


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280
	l.modulate = Color(0.75, 0.78, 0.86)
	_inspector.add_child(l)


func _choice(o: Dictionary, key: String, label: String, options: Dictionary, fallback: String, refill := true) -> void:
	var pick := OptionButton.new()
	for id: String in options:
		pick.add_item(str(options[id]))
		pick.set_item_metadata(pick.item_count - 1, id)
		if id == str(o.get(key, fallback)):
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		canvas.checkpoint()
		o[key] = str(pick.get_item_metadata(i))
		_touched()
		if refill: _fill_inspector.call_deferred())
	_inspector.add_child(_row(label, pick))


func _check(o: Dictionary, key: String, label: String) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = bool(o.get(key, false))
	box.toggled.connect(func(on: bool) -> void:
		canvas.checkpoint()
		o[key] = on
		_touched()
		_fill_inspector.call_deferred())
	_inspector.add_child(box)


func _number(label: String, value: float, low: float, high: float, step: float, action: Callable) -> void:
	var s := SpinBox.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.set_value_no_signal(value)
	s.value_changed.connect(func(v: float) -> void:
		canvas.checkpoint()
		action.call(v)
		_touched())
	_inspector.add_child(_row(label, s))


func _group(o: Dictionary) -> void:
	var options := {}
	for g: String in GROUPS:
		options[g] = "Gruppe " + g
	# plates may also belong to the floor's riddle instead of this room
	if str(o.kind) == "plate":
		options[FLOOR_RIDDLE] = "Rätsel der Etage"
	_choice(o, "group", "Gruppe", options, "A")


func _text_group(o: Dictionary, key: String, label: String) -> void:
	var options := {"": "Nichts"}
	for g: String in GROUPS:
		options[g] = "Gruppe " + g
	_choice(o, key, label, options, "")


## What a chest or a breakable piece holds: kind, then which item or how much.
func _loot(o: Dictionary, label: String) -> void:
	var loot: Dictionary = o.get("loot", {"type": "none"})
	var kinds: Dictionary = catalog.cfg.loot_types
	var pick := OptionButton.new()
	for id: String in kinds:
		if id in ["auto", "hoard"] and str(o.kind) != "chest":
			continue
		pick.add_item(str(kinds[id]))
		pick.set_item_metadata(pick.item_count - 1, id)
		if id == str(loot.get("type", "none")):
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		canvas.checkpoint()
		var type := str(pick.get_item_metadata(i))
		if type == "none":
			o.erase("loot")
		elif type in ["random", "auto", "hoard"]:
			o.loot = {"type": type}
		else:
			o.loot = {"type": type, "amount": 1, "id": _first_item(type)}
		_touched()
		_fill_inspector.call_deferred())
	_inspector.add_child(_row(label, pick))
	var type := str(loot.get("type", "none"))
	if type == "hoard":
		_hoard_tier(o)
	if type in ["gold", "potion", "crystal", "stone"]:
		_number("Anzahl", float(loot.get("amount", 1)), 1.0, 200.0, 1.0, func(v: float) -> void: (o.loot as Dictionary).amount = int(v))
	if type in ["potion", "weapon", "key"]:
		var items := OptionButton.new()
		var list := _items_of(type)
		for id: String in list:
			items.add_item(str(list[id]))
			items.set_item_metadata(items.item_count - 1, id)
			if id == str(loot.get("id", "")):
				items.select(items.item_count - 1)
		items.item_selected.connect(func(i: int) -> void:
			canvas.checkpoint()
			(o.loot as Dictionary).id = str(items.get_item_metadata(i))
			_touched())
		_inspector.add_child(_row("Welche", items))


## How much a Schatz pays, by how hard its puzzle is (world_editor.json hoard_tiers, room_contents.gd).
func _hoard_tier(o: Dictionary) -> void:
	var tiers: Dictionary = catalog.cfg.get("hoard_tiers", {"1": "Stufe 1", "2": "Stufe 2", "3": "Stufe 3"})
	var pick := OptionButton.new()
	var now := str(Contents.hoard_tier(o))
	for id: String in tiers:
		pick.add_item(str(tiers[id]))
		pick.set_item_metadata(pick.item_count - 1, id)
		if id == now:
			pick.select(pick.item_count - 1)
	pick.item_selected.connect(func(i: int) -> void:
		canvas.checkpoint()
		(o.loot as Dictionary).tier = int(str(pick.get_item_metadata(i)))
		_touched())
	_inspector.add_child(_row("Stufe", pick))


## Whether a chest bites: never, always or by chance, and which monster hides in it.
func _mimic_options(o: Dictionary) -> void:
	var hidden := {}
	var defs := _monster_defs()
	for id: Variant in Contents.cfg().get("chest_mobs", []):
		if defs.has(str(id)):
			hidden[str(id)] = str((defs[str(id)] as Dictionary).get("name", id))
	if hidden.is_empty():
		_note("Diese Welt hat kein Monster, das sich als Truhe tarnt.")
		return
	var auto := str((o.get("loot", {}) as Dictionary).get("type", "")) == "auto"
	_choice(o, "mimic", "Mimik", {"no": "Nein", "yes": "Ja, immer", "random": "Zufällig"}, "random" if auto else "no")
	if str(o.get("mimic", "random" if auto else "no")) == "no":
		return
	_choice(o, "mimic_mob", "Monster", hidden, str(hidden.keys()[0]))
	_note("Sieht aus wie eine Truhe und beißt beim Öffnen. Der eingestellte Inhalt fällt, wenn das Monster besiegt ist. Zufällig: in %d von 100 Fällen." % roundi(100.0 * float(Contents.cfg().get("mimic_chance", 0.35))))


## The enemies a chest or breakable piece lets out, each chosen on its own.
func _enemy_slots(o: Dictionary, note: String) -> void:
	var kinds := {"": "Keiner", "random": "Zufällig (von der Etage)"}
	var defs := _monster_defs()
	for id: String in defs:
		if not Contents.is_chest_mob(id):
			kinds[id] = str((defs[id] as Dictionary).get("name", id))
	var chosen: Array = o.get("enemies", [])
	for slot in range(int(Contents.cfg().get("max_enemies", 2))):
		var pick := OptionButton.new()
		var now := str(chosen[slot]) if slot < chosen.size() else ""
		for id: String in kinds:
			pick.add_item(str(kinds[id]))
			pick.set_item_metadata(pick.item_count - 1, id)
			if id == now:
				pick.select(pick.item_count - 1)
		pick.item_selected.connect(func(i: int) -> void:
			canvas.checkpoint()
			var next: Array = (o.get("enemies", []) as Array).duplicate()
			if slot < next.size():
				next[slot] = str(pick.get_item_metadata(i))
			else:
				next.append(str(pick.get_item_metadata(i)))
			next = next.filter(func(id: String) -> bool: return id != "")
			if next.is_empty():
				o.erase("enemies")
			else:
				o.enemies = next
			_touched()
			_fill_inspector.call_deferred())
		_inspector.add_child(_row("Gegner %d" % (slot + 1), pick))
	_note(note)


func _first_item(type: String) -> String:
	var list := _items_of(type)
	return str(list.keys()[0]) if not list.is_empty() else ""


## id -> name of the game's real potions and weapons (assets/data/items.json).
func _items_of(type: String) -> Dictionary:
	if type == "key":
		return {"A": "Schlüssel A", "B": "Schlüssel B", "C": "Schlüssel C"}
	var data: Dictionary = DataCache.load_dict("res://assets/data/items.json")
	var out := {}
	var source: Variant = data.get("weapons" if type == "weapon" else "potions", {})
	if source is Dictionary:
		for key: String in source:
			var value: Variant = source[key]
			if value is Array:
				for item: Variant in value:
					if item is Dictionary and item.has("id"):
						out[str(item.id)] = str(item.get("name", item.id))
			elif value is Dictionary:
				out[key] = str(value.get("name", key))
	elif source is Array:
		for item: Variant in source:
			if item is Dictionary and item.has("id"):
				out[str(item.id)] = str(item.get("name", item.id))
	return out

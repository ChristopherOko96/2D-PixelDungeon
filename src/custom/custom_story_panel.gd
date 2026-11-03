extends Control
## Dedicated Custom Stories library and room workshop; edits isolated story drafts.
## Uses the same story skins, shared CryptUI and runtime-ready room data.

signal closed
signal play_requested(story: Dictionary)
signal test_requested(story: Dictionary, room_id: String)
signal continue_requested(story: Dictionary, slot: int)

const Data = preload("res://src/custom/custom_story_data.gd")
const Canvas = preload("res://src/custom/custom_room_canvas.gd")
const CryptUI = preload("res://src/ui/crypt_ui.gd")
const SaveStore = preload("res://src/save/save_store.gd")
const Graphics = preload("res://src/core/graphics_settings.gd")
const StorySave = preload("res://src/save/story_save.gd")
const Preview = preload("res://src/custom/custom_floor_preview.gd")
const WORLDS := [["krypta", "KRYPTA"], ["frost", "FROSTGRUFT"], ["hell", "HÖLLE"]]
const ROLES := [["start", "Eingang"], ["combat", "Kampfraum"], ["shop", "Shop / Schlüsselraum"], ["treasure", "Schatzkammer"], ["boss", "Bossraum"]]
const PROP_NAMES := {"crate_a": "Holzkiste", "crate_b": "Kleine Kiste", "barrel_a": "Fass", "altar": "Altar", "shop_table": "Händlertisch", "bench": "Bank", "bones_scatter": "Knochen", "skull_pile": "Schädelhaufen", "brazier_bowl": "Feuerschale", "brazier_pillar": "Feuersäule", "rune_pillar_a": "Runensäule", "cage_small": "Käfig", "banner_1": "Rotes Banner", "banner_2": "Blaues Banner", "statue": "Statue", "chest_closed": "Truhe"}

## Tools/tests can point this at their own directory; real stories live in user://.
var storage_dir: String = "user://custom_stories"
var settings_path: String = Graphics.SETTINGS_PATH
## Root for the stories' save slots and profile copies; "" is the real user:// layout
## (story_save.gd custom_saves_dir), tests point it at their scratch folder.
var save_root: String = ""
var story: Dictionary = {}
var dirty: bool = false
var _room_index: int = 0
var _editing: bool = false
var _syncing: bool = false
var _built: bool = false
var _hub: VBoxContainer
var _editor: VBoxContainer
var _library: VBoxContainer
var _world_pick: OptionButton
var _title: LineEdit
var _world: OptionButton
var _floors: SpinBox
var _count: SpinBox
var _rooms: ItemList
var _room_title: LineEdit
var _role: OptionButton
var _width: SpinBox
var _height: SpinBox
var _canvas: Control
var _props: ItemList
var _prop_ids: Array[String] = []
var _status: Label
var _checks: Label
var _draft_label: Label
var _confirm: ConfirmationDialog
var _pending_leave: Callable
var _seed: SpinBox
var _preview: Control
var _preview_button: Button
var _tools: HBoxContainer
var _canvas_controls: HBoxContainer
var _delete_confirm: ConfirmationDialog
var _delete_target: Dictionary = {}


func _ready() -> void:
	theme = CryptUI.create_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Shows the library. Opening never overwrites source rooms or the current draft.
func open() -> void:
	if not _built: _build()
	visible = true
	_show_hub()


## Restores a full draft, including unsaved data returned from a room play preview.
func edit_story(value: Dictionary, room_id: String = "") -> void:
	if not _built: _build()
	story = value.duplicate(true)
	var saved: Dictionary = Data.load_story(str(story.get("id", "")), storage_dir)
	dirty = saved.is_empty() or JSON.stringify(JSON.parse_string(JSON.stringify(saved)), "", true) != JSON.stringify(JSON.parse_string(JSON.stringify(story)), "", true)
	_room_index = 0
	for i in range(story.get("rooms", []).size()):
		if str(story.rooms[i].id) == room_id: _room_index = i
	visible = true
	_editing = true
	_hub.hide()
	_editor.show()
	show_preview(false)
	_sync_story()


## Opens a saved story by ID (also used after returning from its run).
func restore_context(story_id: String, edit: bool = true, room_id: String = "") -> void:
	var saved: Dictionary = Data.load_story(story_id, storage_dir)
	if saved.is_empty(): open()
	elif edit: edit_story(saved, room_id)
	else: open()


## Escape/back returns to the library, asking before discarding an unsaved draft.
func go_back() -> bool:
	if not visible: return false
	if _confirm.visible: _confirm.hide(); return true
	if _delete_confirm.visible: _delete_confirm.hide(); return true
	if _editing and _preview.visible: show_preview(false); return true
	if _editing:
		_request_leave(_show_hub)
	else:
		hide()
		closed.emit()
	return true


func _build() -> void:
	if _built: return
	_built = true
	var background := ColorRect.new()
	background.color = Color("17151c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var name := _label("CUSTOM STORYS", 30)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", CryptUI.GOLD)
	heading.add_child(name)
	heading.add_child(_button("ZURÜCK", go_back))
	_hub = VBoxContainer.new()
	_hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_hub)
	_hub.add_child(_label("Eigene Geschichten. Dieselben Helden, Talente, Gegner und Effekte.", 16))
	var creation := HBoxContainer.new()
	_hub.add_child(creation)
	_world_pick = OptionButton.new()
	for entry: Array in WORLDS: _world_pick.add_item(tr(str(entry[1])))
	creation.add_child(_world_pick)
	creation.add_child(_button("NEUE GESCHICHTE", _create_story))
	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hub.add_child(scroller)
	_library = VBoxContainer.new()
	_library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library.add_theme_constant_override("separation", 12)
	scroller.add_child(_library)
	_editor = VBoxContainer.new()
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_editor)
	_build_editor()
	_status = _label("", 16)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_confirm = ConfirmationDialog.new()
	_confirm.title = tr("Ungespeicherter Entwurf")
	_confirm.dialog_text = tr("Deine Änderungen sind noch nicht gespeichert. Wirklich verwerfen?")
	_confirm.ok_button_text = tr("VERWERFEN")
	_confirm.cancel_button_text = tr("WEITER BEARBEITEN")
	_confirm.confirmed.connect(func() -> void:
		dirty = false
		if _pending_leave.is_valid(): _pending_leave.call())
	add_child(_confirm)
	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.title = tr("Geschichte löschen")
	_delete_confirm.ok_button_text = tr("LÖSCHEN")
	_delete_confirm.cancel_button_text = tr("BEHALTEN")
	_delete_confirm.confirmed.connect(func() -> void: delete_story(_delete_target))
	add_child(_delete_confirm)
	_editor.hide()


func _build_editor() -> void:
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 8)
	_editor.add_child(settings)
	_title = LineEdit.new()
	_title.placeholder_text = tr("Name deiner Geschichte")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_changed.connect(func(value: String) -> void:
		if not _syncing: story.title = value; _changed())
	settings.add_child(_title)
	_world = OptionButton.new()
	for entry: Array in WORLDS: _world.add_item(tr(str(entry[1])))
	_world.item_selected.connect(_world_changed)
	settings.add_child(_world)
	settings.add_child(_label("ETAGEN", 14))
	_floors = _spin(1, 10, func(value: float) -> void:
		if not _syncing: story.floor_count = int(value); _changed())
	settings.add_child(_floors)
	settings.add_child(_label("RÄUME", 14))
	_count = _spin(4, 12, func(value: float) -> void:
		if not _syncing: story.rooms_per_floor = int(value); _changed())
	settings.add_child(_count)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_editor.add_child(body)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 230
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	left.add_child(_label("RAUMVORLAGEN", 18))
	_rooms = ItemList.new()
	_rooms.custom_minimum_size = Vector2(218, 190)
	_rooms.item_selected.connect(func(index: int) -> void: _room_index = index; _sync_room())
	left.add_child(_rooms)
	var room_actions := GridContainer.new()
	room_actions.columns = 2
	left.add_child(room_actions)
	room_actions.add_child(_button("+ LEER", _new_room))
	room_actions.add_child(_button("DUPLIZIEREN", _duplicate_room))
	room_actions.add_child(_button("ENTFERNEN", _delete_room))
	left.add_child(_label("RAUMNAME", 14))
	_room_title = LineEdit.new()
	_room_title.text_changed.connect(func(value: String) -> void:
		if not _syncing and not _room().is_empty(): _room().title = value; _changed(); _refresh_room_names())
	left.add_child(_room_title)
	left.add_child(_label("RAUMTYP", 14))
	_role = OptionButton.new()
	for entry: Array in ROLES: _role.add_item(tr(str(entry[1])))
	_role.item_selected.connect(func(index: int) -> void:
		if not _syncing and not _room().is_empty(): _room().role = ROLES[index][0]; _changed(); _refresh_room_names())
	left.add_child(_role)
	var dimensions := HBoxContainer.new()
	left.add_child(dimensions)
	_width = _spin(12, 32, func(_value: float) -> void: _resize_room())
	_height = _spin(10, 26, func(_value: float) -> void: _resize_room())
	dimensions.add_child(_width)
	dimensions.add_child(_label("×", 16))
	dimensions.add_child(_height)
	left.add_child(_label("Wände folgen deinem Boden.\nTüren: zwei Zellen breit am Rand.", 14))
	_checks = _label("", 14)
	_checks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_checks)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var tools := HBoxContainer.new()
	_tools = tools
	center.add_child(tools)
	var group := ButtonGroup.new()
	for entry: Array in [["floor", "BODEN"], ["erase", "RADIEREN"], ["rect", "RECHTECK"], ["port", "TÜR"], ["enemy", "GEGNER"]]:
		var key: String = str(entry[0])
		var button := _button(str(entry[1]), func() -> void: _canvas.set_tool(key))
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = key == "floor"
		tools.add_child(button)
	_canvas = Canvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.changed.connect(_changed)
	center.add_child(_canvas)
	# the floor preview shares the canvas's place: the run's own generator, seen from above
	_preview = Preview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.hide()
	center.add_child(_preview)
	var controls := HBoxContainer.new()
	_canvas_controls = controls
	center.add_child(controls)
	controls.add_child(_button("UNDO", func() -> void: _canvas.undo()))
	controls.add_child(_button("REDO", func() -> void: _canvas.redo()))
	controls.add_child(_button("EINPASSEN", func() -> void: _canvas.fit_room()))
	var grid := CheckButton.new()
	grid.text = tr("RASTER")
	grid.button_pressed = true
	grid.toggled.connect(func(on: bool) -> void: _canvas.grid_on = on; _canvas.queue_redraw())
	controls.add_child(grid)
	center.add_child(_label("Links setzen · Rechts löschen · Mausrad Zoom · Mittlere Maustaste verschieben", 14))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 200
	body.add_child(right)
	right.add_child(_label("WELT-ASSETS", 18))
	right.add_child(_label("Aus dem aktuellen Story-Look", 14))
	_props = ItemList.new()
	_props.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_props.fixed_icon_size = Vector2i(34, 38)
	_props.fixed_column_width = 190
	_props.item_selected.connect(func(index: int) -> void:
		_canvas.prop_name = _prop_ids[index]
		_canvas.set_tool("prop")
		_note(tr("ASSET: %s · Auf Boden klicken, rechts entfernen.") % _props.get_item_text(index)))
	right.add_child(_props)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	_editor.add_child(footer)
	_draft_label = _label("", 14)
	_draft_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_draft_label)
	footer.add_child(_label("WELT-NR.", 14))
	_seed = _spin(1, 99999, func(_value: float) -> void:
		if _preview.visible: _refresh_preview())
	_seed.value = 1
	footer.add_child(_seed)
	footer.add_child(_button("WÜRFELN", func() -> void:
		_seed.value = randi_range(1, 99999)
		show_preview(true)))
	_preview_button = _button("VORSCHAU", func() -> void: show_preview(not _preview.visible))
	footer.add_child(_preview_button)
	footer.add_child(_button("SPEICHERN", _save))
	footer.add_child(_button("RAUM TESTEN", func() -> void: _start_play(true)))
	footer.add_child(_button("GESCHICHTE SPIELEN", func() -> void: _start_play(false)))


func _show_hub() -> void:
	_editing = false
	_editor.hide()
	_hub.show()
	_status.text = tr("Eigene Räume bleiben getrennt von den Hauptstorys.")
	for child: Node in _library.get_children(): child.queue_free()
	var stories: Array = Data.list_stories(storage_dir)
	if stories.is_empty(): _library.add_child(_label("Noch keine eigene Geschichte. Wähle eine Welt und erstelle deinen ersten Entwurf.", 18))
	for saved: Dictionary in stories:
		var frame := PanelContainer.new()
		_library.add_child(frame)
		var margin := MarginContainer.new()
		for side: String in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
		frame.add_child(margin)
		var row := HBoxContainer.new()
		margin.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_label(str(saved.title), 22))
		info.add_child(_label("%s · %d Etagen · %d Raumvorlagen" % [_world_name(str(saved.world)), int(saved.floor_count), saved.rooms.size()], 14))
		row.add_child(_button("BEARBEITEN", func() -> void: edit_story(saved)))
		row.add_child(_button("LÖSCHEN", func() -> void: _ask_delete(saved)))
		var problems: Array = Data.validate(saved, true)
		var play := _button("SPIELEN", func() -> void: play_requested.emit(saved.duplicate(true)))
		play.disabled = not problems.is_empty()
		if play.disabled: play.tooltip_text = "\n".join(PackedStringArray(problems))
		row.add_child(play)
		var slot := _latest_slot(saved)
		if slot > 0: row.add_child(_button("FORTSETZEN", func() -> void: continue_requested.emit(saved.duplicate(true), slot)))


## Shows the generated floor 1 for the current world number (on) or the room canvas again.
func show_preview(on: bool) -> void:
	_canvas.visible = not on
	_tools.visible = not on
	_canvas_controls.visible = not on
	_preview.visible = on
	_preview_button.text = tr("ZUM RAUM") if on else tr("VORSCHAU")
	if on: _refresh_preview()


func _refresh_preview() -> void:
	var problem: String = _preview.show_floor(story, int(_seed.value))
	if problem.is_empty(): _note(tr("Vorschau Etage 1 · Welt-Nr. %d · %d Räume. Jede Nummer setzt deine Räume anders zusammen.") % [int(_seed.value), _preview.raw.rooms.size()])
	else: _note(tr("Keine Etage möglich: ") + problem.get_slice("\n", 0))


func _ask_delete(saved: Dictionary) -> void:
	_delete_target = saved
	_delete_confirm.dialog_text = tr("„%s“ mit allen Räumen und Spielständen endgültig löschen?") % str(saved.get("title", ""))
	_delete_confirm.popup_centered(Vector2i(570, 190))


## Deletes a saved story with its save slots and copied hero profile, then lists the rest.
func delete_story(saved: Dictionary) -> bool:
	var dirs: Array = [StorySave.custom_saves_dir(saved, false, save_root), StorySave.custom_saves_dir(saved, true, save_root)]
	var files: Array = []
	for preview: bool in [false, true]:
		var profile := StorySave.custom_profile_path(saved, preview, save_root)
		files.append_array([profile, profile.trim_suffix(".json") + ".meta.cfg"])
	var ok: bool = Data.delete_story(str(saved.get("id", "")), storage_dir, dirs, files)
	_delete_target = {}
	_show_hub()
	_note(tr("Geschichte gelöscht.") if ok else tr("Die Geschichte konnte nicht gelöscht werden."))
	return ok


func _latest_slot(saved: Dictionary) -> int:
	var saves := SaveStore.new(StorySave.custom_saves_dir(saved, false, save_root))
	var latest := 0
	var stamp := -1
	for slot in range(1, 4):
		var record: Dictionary = saves.read(str(saved.world), slot)
		if not record.is_empty() and int(record.get("saved_at", 0)) > stamp:
			latest = slot
			stamp = int(record.get("saved_at", 0))
	return latest


func _create_story() -> void:
	edit_story(Data.fresh_story(str(WORLDS[_world_pick.selected][0]), tr("Meine Geschichte")))
	dirty = true
	_refresh_checks()
	_note(tr("Ein spielbarer Vorlagensatz ist vorbereitet. Du kannst jeden Raum ändern oder leere Räume hinzufügen."))


func _sync_story() -> void:
	_syncing = true
	_title.text = str(story.get("title", ""))
	_world.select(maxi(0, ["krypta", "frost", "hell"].find(str(story.get("world", "krypta")))))
	_floors.value = int(story.get("floor_count", 1))
	_count.value = int(story.get("rooms_per_floor", 6))
	_refresh_room_names()
	_syncing = false
	_sync_room()
	_fill_props()


func _refresh_room_names() -> void:
	_rooms.clear()
	for room: Dictionary in story.get("rooms", []): _rooms.add_item("%s · %s" % [str(room.title), _role_name(str(room.role))])
	if not story.get("rooms", []).is_empty():
		_room_index = clampi(_room_index, 0, story.rooms.size() - 1)
		_rooms.select(_room_index)


func _room() -> Dictionary:
	return story.rooms[_room_index] if story.has("rooms") and _room_index >= 0 and _room_index < story.rooms.size() else {}


func _sync_room() -> void:
	_syncing = true
	var room := _room()
	_room_title.text = str(room.get("title", ""))
	_role.select(maxi(0, ["start", "combat", "shop", "treasure", "boss"].find(str(room.get("role", "combat")))))
	_width.value = int(room.get("width", 20))
	_height.value = int(room.get("height", 14))
	_canvas.settings_path = settings_path
	_canvas.configure(room, str(story.get("world", "krypta")))
	_syncing = false
	_refresh_checks()


func _world_changed(index: int) -> void:
	if _syncing: return
	story.world = WORLDS[index][0]
	_canvas.configure(_room(), str(story.world))
	_fill_props()
	_changed()


func _fill_props() -> void:
	_props.clear()
	_prop_ids.clear()
	var root: String = Canvas.skin_root(str(story.get("world", "krypta")), settings_path)
	for id: String in PROP_NAMES:
		var path := root + id + ".png"
		if not ResourceLoader.exists(path): continue
		_prop_ids.append(id)
		_props.add_item(tr(str(PROP_NAMES[id])), load(path))


func _new_room() -> void:
	var room: Dictionary = Data.fresh_room(str(story.world), "combat", "Raum A%d" % (story.rooms.size() + 1))
	room.floor = []
	room.ports = []
	room.props = []
	room.enemy_spawns = []
	story.rooms.append(room)
	_room_index = story.rooms.size() - 1
	_refresh_room_names()
	_sync_room()
	_changed()
	_note(tr("Leerer Raum: Boden malen, Türen am Rand markieren, danach Gegner und Ausstattung setzen."))


func _duplicate_room() -> void:
	if _room().is_empty(): return
	var copy: Dictionary = _room().duplicate(true)
	copy.id = "room_%d_%d" % [Time.get_ticks_msec(), story.rooms.size()]
	copy.title = str(copy.title) + tr(" (Kopie)")
	story.rooms.append(copy)
	_room_index = story.rooms.size() - 1
	_refresh_room_names()
	_sync_room()
	_changed()


func _delete_room() -> void:
	if _room().is_empty(): return
	story.rooms.remove_at(_room_index)
	_room_index = maxi(0, _room_index - 1)
	_refresh_room_names()
	_sync_room()
	_changed()


func _resize_room() -> void:
	if _syncing or _room().is_empty(): return
	var w := int(_width.value)
	var h := int(_height.value)
	for p: Array in _room().floor:
		if int(p[0]) >= w - 1 or int(p[1]) >= h - 1:
			_note(tr("Verkleinern würde Boden abschneiden. Bitte die betroffene Fläche zuerst löschen."))
			_sync_room()
			return
	_room().width = w
	_room().height = h
	for port: Dictionary in _room().ports:
		match str(port.side):
			"east": port.cell[0] = w - 1
			"south": port.cell[1] = h - 1
	_canvas.configure(_room(), str(story.world))
	_changed()


func _changed() -> void:
	dirty = true
	_refresh_checks()


func _refresh_checks() -> void:
	if not _built or _draft_label == null: return
	_draft_label.text = tr("UNGESPEICHERT") if dirty else tr("GESPEICHERTER ENTWURF")
	var problems: Array = Data.room_problems(_room(), true) if not _room().is_empty() else [tr("Noch kein Raum gewählt.")]
	_checks.text = tr("RAUM BEREIT") if problems.is_empty() else tr("NOCH ZU TUN:\n") + "\n".join(PackedStringArray(problems))
	_checks.add_theme_color_override("font_color", CryptUI.FROST if problems.is_empty() else CryptUI.GOLD)


func _save() -> void:
	var result: Dictionary = Data.save_story(story, storage_dir)
	if not str(result.get("error", "")).is_empty(): _note(str(result.error)); return
	var id: String = str(_room().get("id", ""))
	edit_story(result.get("story", story), id)
	_note(tr("Gespeichert. Entwürfe bleiben erhalten; zum Spielen müssen alle Raumprüfungen stimmen."))


func _start_play(selected_room: bool) -> void:
	var problems: Array = Data.validate(story, not selected_room)
	if selected_room: problems.append_array(Data.room_problems(_room(), true))
	if not problems.is_empty():
		_note(tr("Noch nicht spielbar: ") + str(problems[0]))
		return
	if selected_room: test_requested.emit(story.duplicate(true), str(_room().get("id", "")))
	else: play_requested.emit(story.duplicate(true))


func _request_leave(action: Callable) -> void:
	if not dirty: action.call(); return
	_pending_leave = action
	_confirm.popup_centered(Vector2i(570, 190))


func _note(message: String) -> void:
	_status.text = message


func _world_name(id: String) -> String:
	for entry: Array in WORLDS:
		if str(entry[0]) == id: return tr(str(entry[1]))
	return id


func _role_name(id: String) -> String:
	for entry: Array in ROLES:
		if str(entry[0]) == id: return tr(str(entry[1]))
	return id


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = tr(text)
	label.add_theme_font_size_override("font_size", font_size)
	label.clip_text = true
	label.custom_minimum_size.x = minf(180.0, CryptUI.create_theme().default_font.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 4.0)
	label.custom_minimum_size.y = float(font_size + 8) * float(text.count("\n") + 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = tr(text)
	label.resized.connect(func() -> void:
		var rows: int = 0
		for line: String in label.text.split("\n"):
			rows += maxi(1, ceili(label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / maxf(1, label.size.x)))
		var wanted: float = float(rows * (font_size + 8))
		if not is_equal_approx(label.custom_minimum_size.y, wanted): label.custom_minimum_size.y = wanted)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = tr(text)
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	return button


func _spin(low: int, high: int, callback: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	spin.custom_minimum_size.x = 74
	spin.value_changed.connect(callback)
	return spin


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			go_back()
			get_viewport().set_input_as_handled()
		elif _editing and event.ctrl_pressed and event.keycode == KEY_S:
			_save()
			get_viewport().set_input_as_handled()
		elif _editing and event.ctrl_pressed and event.keycode == KEY_Z and not (get_viewport().gui_get_focus_owner() is LineEdit):
			_canvas.undo()
			get_viewport().set_input_as_handled()

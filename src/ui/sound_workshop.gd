extends Control
## Klangwerkstatt (debug menu): listen to every sound event and music state,
## pick their files from the sound library (assets/data/audio_library.json),
## set level, pitch and mix category, and save the choices to
## assets/data/audio_sfx.json and audio_music.json. The game's sound and music
## players reload after a save. A developer tool: res:// is writable when the
## game runs from the project folder. The music fades out while it is open, so
## previews are heard alone.

signal closed

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const Sfx = preload("res://src/vfx/sfx.gd")
const Music = preload("res://src/audio/music.gd")
const AudioMix = preload("res://src/audio/audio_mix.gd")
const SCREEN := Vector2(1280, 720)
## Music states and the ambience, shown above the sound events.
const MUSIC_ROWS := [["music:menu", "MUSIK · MENÜ"], ["music:explore", "MUSIK · ERKUNDEN"], ["music:combat", "MUSIK · KAMPF"], ["music:boss", "MUSIK · BOSS"], ["music:ambience", "AMBIENTE (WIND, TROPFEN)"]]

var sfx_path := "res://assets/data/audio_sfx.json"
var music_path := "res://assets/data/audio_music.json"
var library_path := "res://assets/data/audio_library.json"
var sfx_table: Dictionary = {}
var music_table: Dictionary = {}
var library: Dictionary = {}
## Event name, or "music:<state>" / "music:ambience".
var selected := ""
var dirty := false

var _preview: Node
var _music_preview: AudioStreamPlayer
var _events: ItemList
var _files: ItemList
var _library_list: ItemList
var _pack: OptionButton
var _search: LineEdit
var _category: OptionButton
var _volume: HSlider
var _pitch: HSlider
var _volume_label: Label
var _pitch_label: Label
var _title: Label
## Event name and layer under the title.
var _detail: Label
var _status: Label
var _add_button: Button
var _row_keys: Array[String] = []
var _library_paths: Array[String] = []
var _pack_ids: Array[String] = []
var _leave_armed := false


func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preview = Sfx.new()
	add_child(_preview)
	_music_preview = AudioStreamPlayer.new()
	_music_preview.bus = &"Music"
	add_child(_music_preview)
	_build()
	load_tables()


## Reads the three tables and fills the lists.
func load_tables() -> void:
	sfx_table = _read(sfx_path)
	music_table = _read(music_path)
	library = _read(library_path)
	dirty = false
	_fill_events()
	_fill_packs()
	_fill_library()
	if not _row_keys.is_empty(): select(_row_keys[min(5, _row_keys.size() - 1)])


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Shows the workshop (the music hushes for clean previews).
func open() -> void:
	load_tables()
	visible = true
	Music.hush = true
	_leave_armed = false
	_events.grab_focus()


func close() -> void:
	_music_preview.stop()
	Music.hush = false
	visible = false
	closed.emit()


func _exit_tree() -> void:
	Music.hush = false


# --- Building ---------------------------------------------------------------------

func _build() -> void:
	var shade := ColorRect.new()
	shade.size = SCREEN
	shade.color = CryptUI.INK
	add_child(shade)
	var back := Panel.new()
	back.size = SCREEN
	back.add_theme_stylebox_override("panel", CryptUI.box("panel"))
	add_child(back)
	var heading := _label("KLANGWERKSTATT", Vector2(30, 16), 24, CryptUI.GOLD)
	heading.size.x = 600
	_label("Links wählen · Doppelklick hört an · HINZUFÜGEN nimmt auf · SPEICHERN schreibt", Vector2(30, 52), 16, CryptUI.MUTED).size.x = 1220
	_events = _list(Vector2(30, 84), Vector2(360, 540))
	_events.item_selected.connect(func(index: int): select(_row_keys[index]))
	_title = _label("", Vector2(410, 84), 16, CryptUI.GOLD)
	_title.size.x = 400
	_title.clip_text = true
	_category = OptionButton.new()
	_category.position = Vector2(410, 112)
	_category.size = Vector2(400, 32)
	_category.clip_text = true
	for name: String in AudioMix.category_names(): _category.add_item(_category_label(name))
	_category.item_selected.connect(_on_category)
	add_child(_category)
	_volume_label = _label("", Vector2(410, 158), 16, CryptUI.BONE)
	_volume = _slider(Vector2(610, 160), -24.0, 12.0, 1.0, _on_volume)
	_pitch_label = _label("", Vector2(410, 194), 16, CryptUI.BONE)
	_pitch = _slider(Vector2(610, 196), 0.5, 1.6, 0.01, _on_pitch)
	_detail = _label("", Vector2(410, 232), 16, CryptUI.MUTED)
	_detail.size.x = 400
	_detail.clip_text = true
	_files = _list(Vector2(410, 258), Vector2(400, 306))
	_files.item_activated.connect(func(_index: int): _play_selected_file())
	_button("ANHÖREN", Vector2(410, 576), Vector2(126, 36), _play_selected_file)
	_button("ENTFERNEN", Vector2(544, 576), Vector2(140, 36), _remove_selected_file)
	_button("TESTEN", Vector2(692, 576), Vector2(118, 36), _play_event)
	_label("BIBLIOTHEK", Vector2(830, 84), 16, CryptUI.GOLD)
	_pack = OptionButton.new()
	_pack.position = Vector2(830, 112)
	_pack.size = Vector2(200, 32)
	_pack.clip_text = true
	_pack.item_selected.connect(func(_index: int): _fill_library())
	add_child(_pack)
	_search = LineEdit.new()
	_search.position = Vector2(1040, 112)
	_search.size = Vector2(210, 32)
	_search.placeholder_text = "Suchen …"
	_search.text_changed.connect(func(_text: String): _fill_library())
	add_child(_search)
	_library_list = _list(Vector2(830, 158), Vector2(420, 406))
	_library_list.item_activated.connect(func(_index: int): _play_library())
	_button("ANHÖREN", Vector2(830, 576), Vector2(126, 36), _play_library)
	_add_button = _button("+ HINZUFÜGEN", Vector2(964, 576), Vector2(184, 36), _add_library)
	_button("STOPP", Vector2(1156, 576), Vector2(94, 36), _stop_previews)
	_status = _label("", Vector2(30, 646), 16, CryptUI.MUTED)
	_status.size.x = 740
	_button("SPEICHERN", Vector2(790, 640), Vector2(220, 40), save)
	_button("ZURÜCK", Vector2(1030, 640), Vector2(220, 40), _leave)


func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _list(at: Vector2, extent: Vector2) -> ItemList:
	var list := ItemList.new()
	list.position = at
	list.size = extent
	list.add_theme_font_size_override("font_size", 16)
	add_child(list)
	return list


func _slider(at: Vector2, low: float, high: float, step: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.position = at
	slider.size = Vector2(196, 24)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value_changed.connect(callback)
	add_child(slider)
	return slider


func _button(text: String, at: Vector2, extent: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = extent
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _category_label(name: String) -> String:
	return "%s · %s" % [name.to_upper(), str(AudioMix.category(name).get("label", ""))]


# --- Lists ------------------------------------------------------------------------

func _fill_events() -> void:
	_events.clear()
	_row_keys.clear()
	for row: Array in MUSIC_ROWS:
		_events.add_item(str(row[1]))
		_row_keys.append(str(row[0]))
	# Sorted by what they are for (the descriptions), not by technical name.
	var names: Array = sfx_table.get("events", {}).keys()
	names.sort_custom(func(a: String, b: String) -> bool: return str(sfx_table.events[a].get("label", a)).naturalnocasecmp_to(str(sfx_table.events[b].get("label", b))) < 0)
	for name: String in names:
		# What the sound is for, with its event name as the tooltip.
		var index := _events.add_item(str(sfx_table.events[name].get("label", name)))
		_events.set_item_tooltip(index, name)
		_row_keys.append(name)


func _fill_packs() -> void:
	_pack.clear()
	_pack_ids.clear()
	_pack.add_item("Alle Sounds")
	_pack_ids.append("")
	for id: String in library.get("packs", {}):
		_pack.add_item(str(library.packs[id].get("name", id)).left(28))
		_pack_ids.append(id)
	_pack.add_item("Musik")
	_pack_ids.append("music")


## Library entries of the chosen pack that match the search text.
func _fill_library() -> void:
	_library_list.clear()
	_library_paths.clear()
	var pack := _pack_ids[_pack.selected] if _pack.selected >= 0 and _pack.selected < _pack_ids.size() else ""
	var needle := _search.text.strip_edges().to_lower() if _search != null else ""
	if pack == "music":
		for id: String in library.get("music", {}):
			var track: Dictionary = library.music[id]
			if not needle.is_empty() and not (id + str(track.get("name", ""))).to_lower().contains(needle): continue
			_library_list.add_item("%s · %s (%d s)" % [str(track.get("name", id)), str(track.get("author", "")), int(track.get("seconds", 0))])
			_library_paths.append("music:" + id)
		return
	for id: String in library.get("packs", {}):
		if not pack.is_empty() and id != pack: continue
		for file: Dictionary in library.packs[id].get("files", []):
			var name := str(file.get("name", ""))
			if not needle.is_empty() and not (id + "/" + name).to_lower().contains(needle): continue
			_library_list.add_item("%s   %.2f s   %s" % [name, float(file.get("seconds", 0)), id])
			_library_paths.append(str(file.path))


## Shows one event or music state in the middle column.
func select(key: String) -> void:
	selected = key
	var index := _row_keys.find(key)
	if index >= 0 and (not _events.is_selected(index)): _events.select(index)
	_files.clear()
	var music := key.begins_with("music:")
	_category.visible = not music
	_pitch.visible = not music
	_pitch_label.visible = not music
	_add_button.text = "WÄHLEN" if music else "+ HINZUFÜGEN"
	if music:
		var spec := _music_spec(key)
		_title.text = str(MUSIC_ROWS[_row_keys.find(key)][1]) if _row_keys.find(key) >= 0 else key
		_detail.text = "TITEL (läuft in Schleife)"
		var track := str(spec.get("track", ""))
		var entry: Dictionary = library.get("music", {}).get(track, {})
		if not track.is_empty(): _files.add_item("%s · %s" % [str(entry.get("name", track)), str(entry.get("author", ""))])
		_volume.set_value_no_signal(float(spec.get("volume_db", 0.0)))
		_pitch.set_value_no_signal(1.0)
		if _pack_ids.has("music"): _pack.select(_pack_ids.find("music"))
	else:
		var spec := _event_spec(key)
		var layer := str(spec.get("with", ""))
		_title.text = str(spec.get("label", key)).to_upper()
		_detail.text = "VARIANTEN · " + key + ("  + Schicht " + layer if not layer.is_empty() else "")
		for path: String in spec.get("files", []): _files.add_item(_file_label(path))
		_volume.set_value_no_signal(float(spec.get("volume_db", 0.0)))
		_pitch.set_value_no_signal(float(spec.get("pitch", 1.0)))
		var names := AudioMix.category_names()
		var category := names.find(str(spec.get("category", "world")))
		if category >= 0: _category.select(category)
		if _pack.selected >= 0 and _pack_ids[_pack.selected] == "music": _pack.select(0)
	_fill_library()
	_update_labels()


func _event_spec(key: String) -> Dictionary:
	return sfx_table.get("events", {}).get(key, {})


func _music_spec(key: String) -> Dictionary:
	var state := key.substr(6)
	if state == "ambience": return music_table.get("ambience", {})
	return music_table.get("states", {}).get(state, {})


func _file_label(path: String) -> String:
	for id: String in library.get("packs", {}):
		for file: Dictionary in library.packs[id].get("files", []):
			if str(file.path) == path: return "%s   %.2f s   %s" % [str(file.name), float(file.get("seconds", 0)), id]
	return path.get_file()


func _update_labels() -> void:
	_volume_label.text = "PEGEL %+d dB" % int(_volume.value)
	_pitch_label.text = "TONHÖHE %.2f" % _pitch.value


# --- Editing ----------------------------------------------------------------------

func _changed(text: String) -> void:
	dirty = true
	_leave_armed = false
	_status.text = text + " · ungespeichert"


func _on_volume(value: float) -> void:
	if selected.is_empty(): return
	var spec: Dictionary = _music_spec(selected) if selected.begins_with("music:") else _event_spec(selected)
	spec.volume_db = value
	_update_labels()
	_changed("Pegel %+d dB" % int(value))


func _on_pitch(value: float) -> void:
	if selected.is_empty() or selected.begins_with("music:"): return
	_event_spec(selected).pitch = snappedf(value, 0.01)
	_update_labels()
	_changed("Tonhöhe %.2f" % value)


func _on_category(index: int) -> void:
	if selected.is_empty() or selected.begins_with("music:"): return
	var names := AudioMix.category_names()
	_event_spec(selected).category = names[index]
	_changed("Kategorie " + str(names[index]))


## Adds the chosen library file to the event, or picks the chosen track.
func _add_library() -> void:
	var index := _library_list.get_selected_items()
	if index.is_empty() or selected.is_empty(): return
	var path := _library_paths[index[0]]
	if selected.begins_with("music:"):
		if not path.begins_with("music:"):
			_status.text = "Für Musik bitte einen Titel aus „Musik“ wählen."
			return
		_music_spec(selected).track = path.substr(6)
		select(selected)
		_changed("Titel gewählt")
		return
	if path.begins_with("music:"):
		_status.text = "Musik passt nicht zu einem Sound-Ereignis."
		return
	var files: Array = _event_spec(selected).get("files", [])
	if files.has(path):
		_status.text = "Diese Datei ist schon dabei."
		return
	files.append(path)
	_event_spec(selected).files = files
	select(selected)
	_changed("Datei hinzugefügt")


func _remove_selected_file() -> void:
	var index := _files.get_selected_items()
	if index.is_empty() or selected.is_empty() or selected.begins_with("music:"): return
	var files: Array = _event_spec(selected).get("files", [])
	if files.size() <= 1:
		_status.text = "Mindestens eine Datei muss bleiben."
		return
	files.remove_at(index[0])
	select(selected)
	_changed("Datei entfernt")


# --- Listening --------------------------------------------------------------------

func _play_selected_file() -> void:
	if selected.is_empty(): return
	if selected.begins_with("music:"):
		_play_music(str(_music_spec(selected).get("track", "")))
		return
	var index := _files.get_selected_items()
	var files: Array = _event_spec(selected).get("files", [])
	if files.is_empty(): return
	_play_file(str(files[index[0] if not index.is_empty() else 0]))


func _play_library() -> void:
	var index := _library_list.get_selected_items()
	if index.is_empty(): return
	var path := _library_paths[index[0]]
	if path.begins_with("music:"): _play_music(path.substr(6))
	else: _play_file(path)


## A file at the selected event's level and pitch on its category's bus.
func _play_file(path: String) -> void:
	var spec := _event_spec(selected) if not selected.begins_with("music:") else {}
	var group := AudioMix.category(str(spec.get("category", "world")))
	_preview.preview(path, float(group.get("volume_db", 0.0)) + float(spec.get("volume_db", 0.0)), float(spec.get("pitch", 1.0)), str(group.get("bus", "SFX")))
	_status.text = "Spielt: " + path.get_file()


## Plays the event exactly as the game would, with the unsaved choices.
func _play_event() -> void:
	if selected.is_empty(): return
	if selected.begins_with("music:"):
		_play_music(str(_music_spec(selected).get("track", "")))
		return
	_preview.reload(sfx_table.duplicate(true))
	_preview.play(selected)
	_status.text = "Spielt wie im Spiel: " + selected


func _play_music(id: String) -> void:
	var entry: Dictionary = library.get("music", {}).get(id, {})
	var path := str(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return
	_music_preview.stream = load(path)
	var spec := _music_spec(selected) if selected.begins_with("music:") else {}
	_music_preview.volume_db = float(entry.get("gain_db", 0.0)) + float(spec.get("volume_db", 0.0))
	if DisplayServer.get_name() != "headless": _music_preview.play()
	_status.text = "Spielt: " + str(entry.get("name", id))


func _stop_previews() -> void:
	_music_preview.stop()
	_preview.stop_all()
	_status.text = "Gestoppt"


# --- Saving -----------------------------------------------------------------------

## Writes both tables; the game's players reload them.
func save() -> bool:
	var ok := _write(sfx_path, sfx_table) and _write(music_path, music_table)
	if ok:
		dirty = false
		Sfx.table_version += 1
		Music.table_version += 1
		_status.text = "Gespeichert: " + sfx_path.get_file() + ", " + music_path.get_file()
	else:
		_status.text = "Speichern fehlgeschlagen (läuft das Spiel aus dem Projektordner?)"
	return ok


func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, " ") + "\n")
	file.close()
	return true


func _leave() -> void:
	if dirty and not _leave_armed:
		_leave_armed = true
		_status.text = "Ungespeicherte Änderungen. Nochmal ZURÜCK verwirft sie."
		return
	close()

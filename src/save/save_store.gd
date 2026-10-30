extends RefCounted
## Local save slots: three per mode ("krypta" = Story 1, "hell", "frost", "crypt" = the endless crypt run), each one file in
## user://saves/. A save holds the state at the start of a floor; loading starts
## that floor again. Files are written with store_var without objects, so a
## save can only ever hold plain data.

const DIR := "user://saves/"
const SLOTS := 3
const VERSION := 1
## First bytes of every save file; anything else reads as an empty slot.
const MAGIC := "DELVESAVE1"
## Mode -> name shown in the menus.
const MODE_NAMES := {"krypta": "KRYPTA", "hell": "HÖLLE", "frost": "FROSTGRUFT", "crypt": "ENDLOS"}
const CLASS_NAMES := {"swordsman": "SCHWERTKÄMPFER", "archer": "BOGENSCHÜTZE", "mage": "MAGIER", "necromancer": "NEKROMANT"}

var dir := DIR


## `base` lets tests use their own folder.
func _init(base: String = DIR) -> void:
	dir = base if base.ends_with("/") else base + "/"


func path(mode: String, slot: int) -> String:
	return dir + "%s_%d.save" % [mode, slot]


## Writes `data` to the slot (1..3). Adds mode, version and the time. Returns true on success.
func write(mode: String, slot: int, data: Dictionary) -> bool:
	if slot < 1 or slot > SLOTS or not MODE_NAMES.has(mode):
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var record := data.duplicate(true)
	record.mode = mode
	record.version = VERSION
	record.saved_at = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path(mode, slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_var(record, false)
	file.close()
	return true


## The slot's data, or {} when it is empty, unreadable or from another mode.
func read(mode: String, slot: int) -> Dictionary:
	var p := path(mode, slot)
	if not FileAccess.file_exists(p):
		return {}
	var file := FileAccess.open(p, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() <= MAGIC.length() or file.get_buffer(MAGIC.length()).get_string_from_ascii() != MAGIC:
		file.close()
		return {}
	var value: Variant = file.get_var(false)
	file.close()
	if not value is Dictionary or str(value.get("mode", "")) != mode or int(value.get("version", 0)) != VERSION:
		return {}
	return value


func erase(mode: String, slot: int) -> bool:
	var p := path(mode, slot)
	return FileAccess.file_exists(p) and DirAccess.remove_absolute(ProjectSettings.globalize_path(p)) == OK


## Deletes every slot of `mode` that holds the run `run_id` (a run ends: death or
## victory; saving only pauses a run, docs/LAUF-DESIGN.de.md). Returns how many.
func erase_run(mode: String, run_id: String) -> int:
	if run_id.is_empty():
		return 0
	var gone := 0
	for slot in range(1, SLOTS + 1):
		if str(read(mode, slot).get("run_id", "")) == run_id and erase(mode, slot):
			gone += 1
	return gone


## One entry per slot: {slot, empty, text, short}. `text` is the main menu line
## ("PLATZ 2 · ..."), `short` the narrower pause menu button ("2 · ...").
func summaries(mode: String) -> Array:
	var rows: Array = []
	for slot in range(1, SLOTS + 1):
		var data := read(mode, slot)
		var line := describe(data) if not data.is_empty() else "LEER"
		rows.append({"slot": slot, "empty": data.is_empty(), "text": "PLATZ %d · %s" % [slot, line], "short": "%d · %s" % [slot, line]})
	return rows


## "MAGIER LV 7 · EBENE 3 · 29.10. 14:32" (one line in the pixel font)
static func describe(data: Dictionary) -> String:
	var hero := "%s LV %d" % [str(CLASS_NAMES.get(str(data.get("class_id", "")), str(data.get("class_id", "HELD")).to_upper())), int(data.get("level", 1))]
	var where := ("EBENE %d" if str(data.get("mode", "")) == "crypt" else "ETAGE %d") % int(data.get("floor", 1))
	var t := Time.get_datetime_dict_from_unix_time(int(data.get("saved_at", 0)) + _utc_offset())
	return "%s · %s · %02d.%02d. %02d:%02d" % [hero, where, t.day, t.month, t.hour, t.minute]


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

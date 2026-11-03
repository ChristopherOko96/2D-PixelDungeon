class_name DataCache
extends RefCounted
## One shared JSON loader for the data files under assets/data/ (BAUPLAN M0a, F3).
## A file is read and parsed once and kept by its path; the next call returns the
## kept value at the cost of one dictionary lookup. While a file can change (any
## editor build, and every path outside res://), each call also compares the file's
## modified time (FileAccess.get_modified_time, whole seconds) and reads it again
## when the time moved. Exported builds never change res:// files, so there the
## check is skipped.
##
## The shared value is frozen: every Dictionary and Array in it is read-only, so a
## caller that writes into it gets an error instead of silently changing the data
## for everyone. Take a private, writable copy with load_dict_copy() / load_json_copy().
##
## Usage:
## [codeblock]
## # every frame, cheap: shared and read-only
## var slots := int(DataCache.load_dict("res://assets/data/talents.json").get("bar_slots", 4))
## # once, to change it: a private deep copy
## var mine := DataCache.load_dict_copy("res://assets/data/talents.json")
## mine["bar_slots"] = 6
## # after writing a file twice within one second, or in tests
## DataCache.clear("user://my_file.json")
## [/codeblock]
##
## Thread-safe: one Mutex guards the cache, so worker threads may load too.
## Missing files and files that are not valid JSON give null (load_json) or an
## empty Dictionary (load_dict); JSON.parse_string reports the parse error once.

## path -> {"stamp": int (modified time when read), "value": Variant (frozen)}
static var _entries: Dictionary = {}
static var _lock: Mutex = Mutex.new()
## Test hook: when valid, called as stamp_source.call(path) -> int instead of
## FileAccess.get_modified_time, so a test can move a file's time without waiting
## for the clock. Leave it empty in game code.
static var stamp_source: Callable = Callable()
## Test hook: true forces the modified-time check on res:// paths in every build
## (it is on anyway in editor builds).
static var watch_always: bool = false


## The parsed JSON of `path`, shared and read-only; null when the file is missing
## or broken. Numbers come back as float, as JSON.parse_string gives them.
## [codeblock]
## var rules: Variant = DataCache.load_json("res://assets/data/element_rules.json")
## if rules is Dictionary: print(rules.keys())
## [/codeblock]
static func load_json(path: String) -> Variant:
	_lock.lock()
	# a kept, unwatched file costs one lookup and allocates nothing
	var known := _entries.has(path)
	var watch := _watched(path)
	if not known or watch:
		var stamp := _stamp(path) if watch else 0
		if not known or int(_entries[path].stamp) != stamp:
			_entries[path] = {"stamp": stamp, "value": _read(path)}
	var value: Variant = _entries[path].value
	_lock.unlock()
	return value


## load_json() as a Dictionary: the shared, read-only Dictionary of `path`, or an
## empty read-only one when the file is missing, broken or holds no JSON object.
## [codeblock]
## var style := DataCache.load_dict("res://assets/data/ui_hud_style.json")
## var gap := float(style.get("gap", 8.0))
## [/codeblock]
static func load_dict(path: String) -> Dictionary:
	var value: Variant = load_json(path)
	if value is Dictionary: return value
	var empty := {}
	empty.make_read_only()
	return empty


## A private, writable deep copy of load_dict(`path`) ({} when missing or broken).
## Costs a deep copy per call (about a third of a parse), so use it once, not per frame.
## [codeblock]
## var balance := DataCache.load_dict_copy("res://assets/data/hell_balance.json")
## balance["hp"] = 12  # changes only this copy
## [/codeblock]
static func load_dict_copy(path: String) -> Dictionary:
	return load_dict(path).duplicate(true)


## A private, writable deep copy of load_json(`path`) (null when missing or broken).
## [codeblock]
## var list: Variant = DataCache.load_json_copy("res://assets/data/some_list.json")
## [/codeblock]
static func load_json_copy(path: String) -> Variant:
	var value: Variant = load_json(path)
	if value is Dictionary or value is Array: return value.duplicate(true)
	return value


## Forgets the kept value of `path`, or of every file when `path` is empty, so the
## next load reads the file again (tests; a file rewritten within the same second).
## [codeblock]
## DataCache.clear()                       # everything
## DataCache.clear("user://settings.json") # one file
## [/codeblock]
static func clear(path: String = "") -> void:
	_lock.lock()
	if path.is_empty(): _entries.clear()
	else: _entries.erase(path)
	_lock.unlock()


## True when a value of `path` is kept (read at least once and not cleared).
## [codeblock]
## if not DataCache.is_cached(path): print("first read of ", path)
## [/codeblock]
static func is_cached(path: String) -> bool:
	_lock.lock()
	var kept := _entries.has(path)
	_lock.unlock()
	return kept


## True when `path` can change while the game runs, so its time is compared.
static func _watched(path: String) -> bool:
	return watch_always or not path.begins_with("res://") or OS.has_feature("editor")


## The file's modified time (0 when missing, and for files packed into an export).
static func _stamp(path: String) -> int:
	if stamp_source.is_valid(): return int(stamp_source.call(path))
	return int(FileAccess.get_modified_time(path))


## Reads and parses `path` and freezes the result; null when missing or broken.
static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_freeze(parsed)
	return parsed


## Makes every Dictionary and Array inside `value` read-only, innermost first.
static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for item: Variant in (value as Dictionary).values(): _freeze(item)
		(value as Dictionary).make_read_only()
	elif value is Array:
		for item: Variant in (value as Array): _freeze(item)
		(value as Array).make_read_only()

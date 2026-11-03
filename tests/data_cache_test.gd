extends SceneTree
## The shared JSON loader (src/core/data_cache.gd, BAUPLAN M0a/F3): one parse per
## file, a shared read-only value, private writable copies, a fresh read when the
## file's modified time moves (driven here through the stamp_source test hook, so
## no test waits for the clock), clear(), and Profile.data() / data_view() on top
## of it. Fixture files live in user:// and are removed at the end.

const Profile = preload("res://src/progress/profile.gd")
const FIXTURE := "user://data_cache_test_fixture.json"
const BROKEN := "user://data_cache_test_broken.json"
const MISSING := "user://data_cache_test_missing.json"
const FIRST := {"name": "first", "list": [1, 2, {"deep": true}], "nested": {"k": "v"}}
const SECOND := {"name": "second", "list": [], "nested": {}}

var checked := 0
var failures: Array[String] = []
## The fake modified time per path the stamp_source hook hands out.
var _fake_stamps: Dictionary = {}


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("DATA_CACHE_FAIL: ", label)


func _initialize() -> void:
	DataCache.clear()
	_test_shared_value_is_parsed_once()
	_test_shared_value_is_read_only()
	_test_copies_are_private_and_writable()
	_test_changed_stamp_reads_the_file_again()
	_test_unwatched_res_file_skips_the_stamp()
	_test_clear_forgets_one_or_all()
	_test_missing_and_broken_files()
	_test_profile_data_uses_the_cache()
	_cleanup()
	print("DATA_CACHE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value) if not value is String else str(value))
	file.close()


func _fake_stamp(path: String) -> int:
	return int(_fake_stamps.get(path, 1))


func _test_shared_value_is_parsed_once() -> void:
	_write(FIXTURE, FIRST)
	DataCache.clear()
	check(not DataCache.is_cached(FIXTURE), "nothing is kept before the first read")
	var a := DataCache.load_dict(FIXTURE)
	var b := DataCache.load_dict(FIXTURE)
	check(DataCache.is_cached(FIXTURE), "the first read keeps the file")
	check(str(a.get("name", "")) == "first", "the file's content comes back")
	check(is_same(a, b), "a second load returns the same kept Dictionary, not a new parse")
	check(is_same(DataCache.load_json(FIXTURE), a), "load_json and load_dict share the kept value")


func _test_shared_value_is_read_only() -> void:
	_write(FIXTURE, FIRST)
	DataCache.clear()
	var shared := DataCache.load_dict(FIXTURE)
	check(shared.is_read_only(), "the shared Dictionary is read-only")
	check((shared.list as Array).is_read_only(), "a nested Array is read-only too")
	check(((shared.list as Array)[2] as Dictionary).is_read_only(), "a Dictionary inside an Array is read-only")
	check((shared.nested as Dictionary).is_read_only(), "a nested Dictionary is read-only")


func _test_copies_are_private_and_writable() -> void:
	_write(FIXTURE, FIRST)
	DataCache.clear()
	var copy := DataCache.load_dict_copy(FIXTURE)
	check(not copy.is_read_only() and not (copy.nested as Dictionary).is_read_only(), "a copy is writable down to its nested values")
	copy["name"] = "changed"
	(copy.nested as Dictionary)["k"] = "changed"
	var again := DataCache.load_dict(FIXTURE)
	check(str(again.name) == "first" and str(again.nested.k) == "v", "changing a copy leaves the shared value as it was")
	check(not is_same(DataCache.load_dict_copy(FIXTURE), DataCache.load_dict_copy(FIXTURE)), "every copy is a new Dictionary")
	var json_copy: Variant = DataCache.load_json_copy(FIXTURE)
	check(json_copy is Dictionary and not (json_copy as Dictionary).is_read_only(), "load_json_copy gives a writable copy as well")


func _test_changed_stamp_reads_the_file_again() -> void:
	DataCache.stamp_source = _fake_stamp
	_fake_stamps[FIXTURE] = 100
	_write(FIXTURE, FIRST)
	DataCache.clear()
	var before := DataCache.load_dict(FIXTURE)
	_write(FIXTURE, SECOND)
	check(str(DataCache.load_dict(FIXTURE).name) == "first", "an unchanged modified time keeps the kept value")
	_fake_stamps[FIXTURE] = 101
	var after := DataCache.load_dict(FIXTURE)
	check(str(after.get("name", "")) == "second", "a moved modified time reads the file again")
	check(not is_same(before, after), "the new read replaces the kept value")
	DataCache.stamp_source = Callable()


func _test_unwatched_res_file_skips_the_stamp() -> void:
	var path := "res://assets/data/talents.json"
	var asked: Array[String] = []
	DataCache.stamp_source = func(p: String) -> int:
		asked.append(p)
		return 1
	DataCache.clear()
	DataCache.load_dict(path)
	var first_reads := asked.size()
	DataCache.load_dict(path)
	if OS.has_feature("editor"):
		check(asked.size() == first_reads + 1, "editor builds compare a res:// file's time on every load")
	else:
		check(asked.size() == 0, "exported builds never ask a res:// file's time")
	DataCache.stamp_source = Callable()


func _test_clear_forgets_one_or_all() -> void:
	_write(FIXTURE, FIRST)
	_write(BROKEN, SECOND)
	DataCache.clear()
	DataCache.load_dict(FIXTURE)
	DataCache.load_dict(BROKEN)
	DataCache.clear(FIXTURE)
	check(not DataCache.is_cached(FIXTURE) and DataCache.is_cached(BROKEN), "clear(path) forgets only that file")
	_write(FIXTURE, SECOND)
	check(str(DataCache.load_dict(FIXTURE).name) == "second", "after clear(path) the file is read again")
	DataCache.clear()
	check(not DataCache.is_cached(FIXTURE) and not DataCache.is_cached(BROKEN), "clear() forgets every file")


func _test_missing_and_broken_files() -> void:
	DataCache.clear()
	check(DataCache.load_json(MISSING) == null, "a missing file gives null")
	var empty := DataCache.load_dict(MISSING)
	check(empty.is_empty() and empty.is_read_only(), "load_dict of a missing file gives an empty read-only Dictionary")
	var copy := DataCache.load_dict_copy(MISSING)
	check(copy.is_empty() and not copy.is_read_only(), "the copy of a missing file is an empty writable Dictionary")
	_write(BROKEN, "[1, 2, 3]")
	DataCache.clear(BROKEN)
	check(DataCache.load_json(BROKEN) is Array, "a JSON array comes back from load_json")
	check(DataCache.load_dict(BROKEN).is_empty(), "load_dict of a file without a JSON object is empty")
	_write(BROKEN, "{\"not\": json")
	DataCache.clear(BROKEN)
	check(DataCache.load_json(BROKEN) == null and DataCache.load_dict(BROKEN).is_empty(), "a broken file gives null and an empty Dictionary")


func _test_profile_data_uses_the_cache() -> void:
	DataCache.clear()
	var view := Profile.data_view()
	check(not view.is_empty() and view.has("talents"), "Profile.data_view() reads talents.json")
	check(is_same(view, Profile.data_view()), "Profile.data_view() is kept, not parsed per call (F3)")
	check(view.is_read_only(), "Profile.data_view() is the shared read-only value")
	var mine := Profile.data()
	check(not mine.is_read_only() and mine.hash() == view.hash(), "Profile.data() is a writable copy with the same content")
	mine["bar_slots"] = -1
	check(int(Profile.data().get("bar_slots", 4)) != -1 and int(view.get("bar_slots", 4)) != -1, "changing Profile.data() never reaches the next caller")


func _cleanup() -> void:
	DataCache.stamp_source = Callable()
	DataCache.clear()
	for path: String in [FIXTURE, BROKEN]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

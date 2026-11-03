extends SceneTree
## The one rig data pipeline (BAUPLAN M2a): assets/data/rig_manifest.json lists
## every rig file in load order with its generator or hand source, and
## RigLibrary (src/rig/rig_library.gd) loads through it.
## - manifest: it parses; every source has an existing res:// file, a known
##   format and its own load_data slot, the order is the game's (rigs.json,
##   companions, Krypta bosses, story figures, the hell's layered rigs, the
##   needs table); every generator and hand source a step names exists;
## - library: rig_sources() is the manifest's list, a missing or broken
##   manifest gives the six RigLibrary paths; source_file() takes a load_data
##   parameter only when it differs from its default;
## - loading: a fixture manifest loads a file that has no slot (a new rig file
##   needs no code change, and may use an earlier file's image keys), a missing
##   required file fails the load, "" skips a slot, a parameter replaces the
##   manifest's file;
## - data: the real files build every rig they list, and every rig a monster,
##   companion or hero table names (the manifest's check.references) exists.
## Writes only user://rig_manifest_test/ and removes it. Deterministic.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const WORK_DIR := "user://rig_manifest_test"
## The game's load order today (src/rig/rig_library.gd before the manifest).
const ORDER := ["res://assets/data/rigs.json", "res://assets/data/companion_rigs.json", "res://assets/data/krypta_boss_rigs.json",
	"res://assets/data/story_rigs.json", "res://assets/data/hell_rigs.json", "res://assets/data/rig_actions.json"]
const FORMATS := ["crypt", "layered", "actions"]
const SLOTS := ["path", "hell_path", "companion_path", "boss_path", "story_path", "actions_path"]
## A one-pixel-art fixture figure (rigs.json's format) and the files around it.
const ART := {"dot": {"palette": {"A": "#ffffff"}, "rows": ["AA", "AA"]}}

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RIG_MANIFEST_FAIL: ", description)


func _initialize() -> void:
	var manifest := _json(RigLibrary.MANIFEST_PATH)
	test_manifest(manifest)
	test_sources(manifest)
	test_fixture_loading()
	test_real_data(manifest)
	_clean()
	print("RIG_MANIFEST checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _paths(sources: Array) -> Array[String]:
	var result: Array[String] = []
	for source: Dictionary in sources: result.append(str(source.get("path", "")))
	return result


## The manifest itself: files, formats, slots, order and every step's source.
func test_manifest(manifest: Dictionary) -> void:
	check(manifest.get("sources") is Array, "rig_manifest.json parses and lists its sources")
	var sources: Array = manifest.get("sources", [])
	check(_paths(sources) == ORDER, "the manifest keeps the game's load order %s (got %s)" % [str(ORDER), str(_paths(sources))])
	var slots: Array[String] = []
	var required := 0
	for source: Dictionary in sources:
		var path := str(source.get("path", ""))
		check(path.begins_with("res://") and FileAccess.file_exists(path), "%s exists" % path)
		check(str(source.get("format", "")) in FORMATS, "%s has a known format (%s)" % [path, str(source.get("format"))])
		var slot := str(source.get("slot", ""))
		check(slot in SLOTS and not slot in slots, "%s has its own load_data slot (%s)" % [path, slot])
		slots.append(slot)
		if bool(source.get("required", false)): required += 1
		for step: Dictionary in source.get("steps", []):
			var from := str(step.get("generator", step.get("hand", "")))
			check(not from.is_empty() and FileAccess.file_exists("res://" + from), "%s: its step source %s exists" % [path, from])
			for read: Variant in step.get("reads", []):
				check(str(read) in _paths(sources.slice(0, sources.find(source))), "%s: %s is built before it" % [path, str(read)])
	check(required == 1 and not sources.is_empty() and bool(sources[0].get("required", false)), "only rigs.json, the first file, is required")
	for entry: Dictionary in manifest.get("not_built", []):
		check(FileAccess.file_exists("res://" + str(entry.get("generator", ""))) and not str(entry.get("why", "")).is_empty(), "not_built names a generator and why: %s" % str(entry.get("generator")))


## rig_sources and source_file: the manifest's list, the fallback, the slot rule.
func test_sources(manifest: Dictionary) -> void:
	check(_paths(RigLibrary.rig_sources()) == _paths(manifest.get("sources", [])), "RigLibrary.rig_sources() is the manifest's list")
	var fallback := [RigLibrary.DATA_PATH, RigLibrary.COMPANION_PATH, RigLibrary.KRYPTA_BOSS_PATH, RigLibrary.STORY_PATH, RigLibrary.HELL_PATH, RigLibrary.ACTIONS_PATH]
	check(_paths(RigLibrary.rig_sources(WORK_DIR + "/no_such_manifest.json")) == fallback, "without a manifest the six RigLibrary files load in the old order")
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	_write(WORK_DIR + "/broken_manifest.json", "{\"sources\": [")
	check(_paths(RigLibrary.rig_sources(WORK_DIR + "/broken_manifest.json")) == fallback, "a half-written manifest falls back to the six files")
	var source := {"path": "res://a.json", "slot": "story_path"}
	check(RigLibrary.source_file(source, {"story_path": RigLibrary.STORY_PATH}) == "res://a.json", "a parameter left at its default takes the manifest's file")
	check(RigLibrary.source_file(source, {"story_path": "user://b.json"}) == "user://b.json", "a parameter other than its default replaces it")
	check(RigLibrary.source_file(source, {"story_path": ""}) == "", "an empty parameter skips the file")
	check(RigLibrary.source_file({"path": "res://c.json"}, {"story_path": ""}) == "res://c.json", "a source without a slot always loads its own file")


## A fixture manifest: a file without a slot loads, image keys carry over,
## a missing required file fails, "" skips, a parameter replaces.
func test_fixture_loading() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	_write(WORK_DIR + "/base.json", JSON.stringify({"pixel_art": ART, "rigs": {"fixture_box": _rig("dot")}}))
	_write(WORK_DIR + "/extra.json", JSON.stringify({"rigs": {"fixture_extra": _rig("dot")}}))
	_write(WORK_DIR + "/alt.json", JSON.stringify({"pixel_art": ART, "rigs": {"fixture_alt": _rig("dot")}}))
	_write(WORK_DIR + "/actions.json", JSON.stringify({"categories": ["attack"], "kind_category": {"swing": "attack"}}))
	var manifest := WORK_DIR + "/manifest.json"
	_write(manifest, JSON.stringify({"sources": [
		{"path": WORK_DIR + "/base.json", "format": "crypt", "slot": "path", "required": true},
		{"path": WORK_DIR + "/extra.json", "format": "crypt"},
		{"path": WORK_DIR + "/actions.json", "format": "actions", "slot": "actions_path"}]}))
	var library := _load(manifest)
	check(library.ready and not library.rig("fixture_box").is_empty(), "the fixture manifest's required file loads")
	check(not library.rig("fixture_extra").is_empty(), "a file without a slot loads too and uses the earlier file's image key")
	check(library.rig("skeleton").is_empty(), "only the manifest's files load (no rigs.json)")
	check(library.actions.get("categories", []) == ["attack"], "the manifest's needs table loads")
	var no_actions: RigLibrary = RigLibrary.new()
	no_actions.load_data(RigLibrary.DATA_PATH, RigLibrary.HELL_PATH, RigLibrary.COMPANION_PATH, RigLibrary.KRYPTA_BOSS_PATH, RigLibrary.STORY_PATH, "", manifest)
	check(no_actions.actions.is_empty() and not no_actions.rig("fixture_box").is_empty(), "\"\" skips the needs table, the rest still loads")
	var replaced: RigLibrary = RigLibrary.new()
	check(replaced.load_data(WORK_DIR + "/alt.json", RigLibrary.HELL_PATH, RigLibrary.COMPANION_PATH, RigLibrary.KRYPTA_BOSS_PATH, RigLibrary.STORY_PATH, RigLibrary.ACTIONS_PATH, manifest),
		"a replaced required file loads")
	check(not replaced.rig("fixture_alt").is_empty() and replaced.rig("fixture_box").is_empty(), "a parameter other than its default replaces the manifest's file")
	var missing := WORK_DIR + "/missing_manifest.json"
	_write(missing, JSON.stringify({"sources": [
		{"path": WORK_DIR + "/no_such_rigs.json", "format": "crypt", "slot": "path", "required": true},
		{"path": WORK_DIR + "/extra_alone.json", "format": "crypt"}]}))
	_write(WORK_DIR + "/extra_alone.json", JSON.stringify({"pixel_art": ART, "rigs": {"fixture_alone": _rig("dot")}}))
	var failed: RigLibrary = RigLibrary.new()
	check(not failed.load_data(RigLibrary.DATA_PATH, RigLibrary.HELL_PATH, RigLibrary.COMPANION_PATH, RigLibrary.KRYPTA_BOSS_PATH, RigLibrary.STORY_PATH, RigLibrary.ACTIONS_PATH, missing),
		"a missing required file fails the load")
	check(not failed.rig("fixture_alone").is_empty(), "the optional files still load beside a missing required one")


## The real files: every listed rig is built, every named rig exists.
func test_real_data(manifest: Dictionary) -> void:
	var library: RigLibrary = RigLibrary.new()
	check(library.load_data(), "the game's rig files load through the manifest")
	var crypt: Dictionary = {}
	var total := 0
	for source: Dictionary in manifest.get("sources", []):
		var format := str(source.get("format", ""))
		if format == "actions":
			check(not library.actions.is_empty() and library.actions == _json(str(source.path)), "the needs table %s loads" % str(source.path))
			continue
		var data := _json(str(source.path))
		var names: Array = data.get("rigs", {}).keys()
		for extra: String in ["void", "bomber", "mimic"]:
			if data.has(extra): names.append(extra)
		for name: String in names:
			total += 1
			var rig: Dictionary = library.rig(name)
			check(not rig.is_empty() and not rig.get("parts", []).is_empty(), "%s: %s is built with parts" % [str(source.path).get_file(), name])
			if format == "crypt": crypt[name] = true
			elif not crypt.has(name): check(bool(rig.get("layered", false)), "%s: %s is a layered rig" % [str(source.path).get_file(), name])
	check(total >= 60, "the manifest's files hold the game's rigs (%d)" % total)
	var named := 0
	var sprites: Array[String] = []
	for wearer: Dictionary in _wearers(manifest):
		named += 1
		if library.rig(str(wearer.rig)).is_empty():
			if bool(wearer.optional): sprites.append("%s %s" % [wearer.world, wearer.id])
			else: check(false, "%s %s (%s) wears rig '%s', which exists" % [wearer.world, wearer.id, wearer.from, wearer.rig])
	check(named >= 60, "the reference tables name the rigs of monsters, companions and heroes (%d)" % named)
	if not sprites.is_empty(): print("RIG_MANIFEST info: draw their sprite, no rig of their name: %s" % ", ".join(sprites))


## Every wearer the manifest's check.references name: {world, id, rig, optional, from}.
func _wearers(manifest: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in manifest.get("check", {}).get("references", []):
		var optional := bool(ref.get("optional", false))
		if ref.has("code"):
			var regex := RegEx.new()
			regex.compile("const\\s+%s\\s*:?=\\s*(\\{[^}\\n]*\\})" % str(ref.const))
			var found := regex.search(FileAccess.get_file_as_string(str(ref.code)))
			var table: Variant = JSON.parse_string(found.get_string(1)) if found != null else null
			check(table is Dictionary, "%s holds a one-line const %s" % [str(ref.code), str(ref.const)])
			if table is Dictionary:
				for id: String in table: result.append({"world": ref.world, "id": id, "rig": str(table[id]), "optional": optional, "from": str(ref.code).get_file()})
			continue
		var map: Variant = _json(str(ref.file))
		for key: String in str(ref.map).split("."): map = map.get(key) if map is Dictionary else null
		check(map is Dictionary, "%s has the table %s" % [str(ref.file), str(ref.map)])
		if not map is Dictionary: continue
		for id: String in map:
			if id.begins_with("_"): continue
			var entry: Variant = map[id]
			var rig: Variant = id if ref.rig == "@key" else entry if ref.rig == "@value" else entry.get(ref.rig) if entry is Dictionary else null
			if not rig is String or str(rig).is_empty(): continue
			result.append({"world": ref.world, "id": id, "rig": str(rig), "optional": optional, "from": str(ref.file).get_file()})
	return result


func _rig(image: String) -> Dictionary:
	return {"img": image, "family": "", "ground": [1, 1], "width": 2, "items": [],
		"parts": [{"id": "body", "rects": [[0, 0, 1, 1]], "pivot": [1, 1], "parent": null, "z": 1, "hp": 1, "label": "Box", "vital": true}]}


func _load(manifest: String) -> RigLibrary:
	var library: RigLibrary = RigLibrary.new()
	library.load_data(RigLibrary.DATA_PATH, RigLibrary.HELL_PATH, RigLibrary.COMPANION_PATH, RigLibrary.KRYPTA_BOSS_PATH, RigLibrary.STORY_PATH, RigLibrary.ACTIONS_PATH, manifest)
	return library


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(WORK_DIR): return
	for name: String in DirAccess.get_files_at(WORK_DIR): DirAccess.remove_absolute(WORK_DIR + "/" + name)
	DirAccess.remove_absolute(WORK_DIR)

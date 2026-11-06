extends SceneTree
## The Weltbauer knows the Frostgruft's puzzle pieces and the rooms' weather:
## - in the Frostgruft its parts list holds every piece of src/world_kit/frost_puzzles.gd, other worlds
##   do not show them;
## - every Frostgruft room opens, and every puzzle piece in it shows its settings;
## - the weather choice offers what assets/data/world_weather.json names and reads the room's setting.
## Nothing is saved.

const EditorScene = preload("res://src/world_editor/world_editor.tscn")
const Frost = preload("res://src/world_kit/frost_puzzles.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FROST_EDITOR_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ed: Node = EditorScene.instantiate()
	root.add_child(ed)
	for i in range(5):
		await process_frame
	ed._open_world("frost")
	await process_frame
	_test_parts(ed, true)
	_test_rooms(ed)
	ed.dirty = false
	ed._open_world("krypta")
	await process_frame
	_test_parts(ed, false)
	ed.dirty = false
	ed.queue_free()
	await process_frame
	print("FROST_EDITOR checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_parts(ed: Node, frost: bool) -> void:
	# Act
	ed._fill_parts()
	var kinds := {}
	for e: Dictionary in ed._entries:
		kinds[str(e.get("kind", ""))] = true
	# Assert
	for kind: String in Frost.KINDS:
		check(kinds.has(kind) == frost, "%s: the part %s %s" % [ed.world, kind, "is offered" if frost else "is not offered"])


func _test_rooms(ed: Node) -> void:
	var rooms := Data.list_rooms("frost")
	var seen := {}
	for t: Dictionary in rooms:
		# Act
		ed.dirty = false
		ed._open_room(t)
		# Assert: the weather picker shows the room's weather
		var shown := str(ed._weather_pick.get_item_metadata(ed._weather_pick.selected))
		check(shown == str(t.get("weather", "")), "%s: weather shown %s, set %s" % [t.id, shown, str(t.get("weather", ""))])
		# the ice lake box shows the file's ice_lake, in the Frostgruft
		check(ed._lake_check.button_pressed == bool(t.get("ice_lake", false)), "%s: the Eissee box shows ice_lake" % t.id)
		check(ed._lake_check.visible, "%s: the Eissee box is offered in the Frostgruft" % t.id)
		for o: Dictionary in t.objects:
			if not Frost.KINDS.has(str(o.kind)) or seen.has(str(o.kind)):
				continue
			seen[str(o.kind)] = true
			ed.canvas.picked = o
			ed._fill_inspector()
			check(ed._inspector.get_child_count() >= 3, "%s: the %s shows its settings (%d)" % [t.id, o.kind, ed._inspector.get_child_count()])
		check(not ed.dirty, "%s: opening it changes nothing" % t.id)
	check(seen.size() >= 15, "the rooms hold most puzzle pieces (%s)" % str(seen.keys()))

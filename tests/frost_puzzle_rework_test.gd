extends SceneTree
## The Frostgruft's reworked rooms (user wishes of 2026-11-06):
## - Kristallglocken: five coloured crystals side by side in one row, a melody that uses at least four
##   of them and never just runs along the row, the full polar sky over the room;
## - Spiegelgeist: hero field and ghost field fit on one screen at the room's zoom, and in the room
##   the camera really zooms out;
## - Eissee: a room file with ice_lake is ice everywhere for hero and monsters with the lake's harder
##   grip, its painted snowfields stand firm, and such rooms turn up on the floors.
## Usage:
##   godot --headless --path . --script res://tests/frost_puzzle_rework_test.gd
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FrostPuzzles = preload("res://src/world_kit/frost_puzzles.gd")
const Pack = preload("res://src/world_kit/world_pack.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const RoomFloor = preload("res://src/world_kit/room_floor.gd")
const ROOMS := "res://assets/data/world_rooms/frost/%s.json"
const BELLS := ["f_glocken_la", "f_glocken_lb", "f_glocken_lc", "f_glocken_ld"]
const LAKES := ["f_eissee_spiegel_b2", "f_eissee_weit_b3", "f_eissee_bucht_la", "f_eissee_bucht_la_gs"]
const FULL_SKY := ["night", "rime", "aurora", "diamond", "fog"]
const RUNS := [101, 202, 303, 404, 505, 606]
const M := 2
const C := 96.0

var _checked := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		printerr("FROST_REWORK_FAIL: ", what)


func _run() -> void:
	_test_bells_stand_in_a_row()
	_test_mirror_fits_one_screen()
	await _test_mirror_room_zooms_out()
	await _test_ice_lake_slides_but_snowfields_hold()
	_test_ice_lakes_come_on_floors()
	print("FROST_REWORK checked=%d failures=%d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


func _room(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ROOMS % id))


func _test_bells_stand_in_a_row() -> void:
	for id: String in BELLS:
		# Arrange
		var t := _room(id)
		var crystals: Array = (t.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) == "crystal")
		var statue: Array = (t.objects as Array).filter(func(o: Dictionary) -> bool: return str(o.kind) == "bell_statue")
		# Assert
		_check(crystals.size() == 5, "%s: five crystals (%d)" % [id, crystals.size()])
		_check(statue.size() == 1, "%s: one statue" % id)
		crystals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
		var row_y := int(floor(float(crystals[0].y) / C))
		var notes: Array = []
		for k in range(crystals.size()):
			var c := Vector2i(int(floor(float(crystals[k].x) / C)), int(floor(float(crystals[k].y) / C)))
			_check(c.y == row_y, "%s: crystal %d stands in the row" % [id, k])
			if k > 0:
				_check(c.x == int(floor(float(crystals[k - 1].x) / C)) + 1, "%s: crystal %d stands beside the one before" % [id, k])
			notes.append(int(crystals[k].note))
			_check(FrostPuzzles.crystal_tex(int(crystals[k].note)) != null, "%s: the picture of note %d" % [id, int(crystals[k].note)])
		var melody := FrostPuzzles.melody_of(statue[0].melody)
		var at := melody.map(func(n: int) -> int: return notes.find(n))
		var rising := true
		var falling := true
		for k in range(1, at.size()):
			rising = rising and int(at[k]) > int(at[k - 1])
			falling = falling and int(at[k]) < int(at[k - 1])
		_check(not rising and not falling, "%s: the melody does not just run along the row (%s)" % [id, str(at)])
		var used := {}
		for n: int in melody:
			used[n] = true
		_check(used.size() >= 4, "%s: the melody uses at least four crystals (%d)" % [id, used.size()])
		for sky: String in FULL_SKY:
			_check((t.get("weather_extra", []) as Array).has(sky), "%s: the sky has %s" % [id, sky])
	# the light puzzle rooms carry the same sky
	for id: String in ["f_prismen_la", "f_prismen_lb", "f_prismen_lc", "f_prismen_ld"]:
		for sky: String in FULL_SKY:
			_check((_room(id).get("weather_extra", []) as Array).has(sky), "%s: the sky has %s" % [id, sky])


func _test_mirror_fits_one_screen() -> void:
	# Arrange
	var t := _room("f_spiegelgeist_b3")
	var cfg := FrostPuzzles.load_config()
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_balance.json"))
	var seen := float(balance.view.width) / float(cfg.ghost.zoom) / C
	var lo := 999
	var hi := -999
	for y in range((t.cells as Array).size()):
		var row := str(t.cells[y])
		for x in range(row.length()):
			if y >= 4 and row[x] != Data.WALL:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	# Assert: from the middle between hero and ghost the camera sees both fields whole
	_check(float(hi - lo + 1) <= seen - 2.0, "the mirror's fields (%d cells) fit the zoomed view (%.1f cells)" % [hi - lo + 1, seen])
	_check(float(cfg.ghost.zoom) < 1.0, "the mirror room zooms out")


func _test_mirror_room_zooms_out() -> void:
	# Arrange
	var game: Node = FrostScene.instantiate()
	game.class_id = "mage"
	game.graphics_path = "user://rework_graphics.cfg"
	game.world_room_path = ROOMS % "f_spiegelgeist_b3"
	root.add_child(game)
	# Act
	for i in range(150):
		await process_frame
	# Assert
	_check(not game.frost_puzzles.room_ghost().is_empty(), "the hero stands in the mirror's room")
	_check(float(game.view_far) < 0.8, "the camera zoomed out (%.2f)" % float(game.view_far))
	_check(game.has_method("draw_mirror_hero"), "the ghost is drawn as the hero")
	game.queue_free()
	await process_frame


func _test_ice_lake_slides_but_snowfields_hold() -> void:
	# Arrange
	var t := _room("f_eissee_spiegel_b2")
	var game: Node = FrostScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://rework_graphics.cfg"
	game.world_room_path = ROOMS % "f_eissee_spiegel_b2"
	root.add_child(game)
	for i in range(10):
		await process_frame
	var firm_spot: String = (t.areas as Dictionary).keys()[0]
	var bits := firm_spot.split(",")
	var firm := Vector2((int(bits[0]) + M + 0.5) * C, (int(bits[1]) + M + 0.5) * C)
	# an ice cell: the first floor cell of the file that is no snowfield
	var ice := Vector2.ZERO
	for y in range((t.cells as Array).size()):
		for x in range(str(t.cells[y]).length()):
			if ice == Vector2.ZERO and str(t.cells[y])[x] == Data.FLOOR and not (t.areas as Dictionary).has("%d,%d" % [x, y]):
				ice = Vector2((x + M + 0.5) * C, (y + M + 0.5) * C)
	var lake: Dictionary = game.theme.ice_room
	# Act / Assert
	_check(bool(game.W.rooms[0].get("ice_lake", false)), "the room is an ice lake")
	_check(game.ice_room_at(ice), "its floor is ice")
	_check(not game.ice_room_at(firm), "its snowfield stands firm")
	_check(is_equal_approx(game.ice_room_grip(ice, false), float(lake.lake_grip)), "the hero slides with the lake's grip")
	_check(is_equal_approx(game.ice_room_grip(ice, true), float(lake.lake_mob_grip)), "the monsters slide with the lake's grip")
	_check(float(lake.lake_grip) > float(lake.grip), "the lake slides farther than an ice room")
	game.player.x = ice.x
	game.player.y = ice.y + 6.0
	_check(is_equal_approx(float(game.motion_kit().host.hero_grip()), float(lake.lake_grip)), "the motion host knows the lake's footing")
	game.queue_free()
	await process_frame


func _test_ice_lakes_come_on_floors() -> void:
	var pack := Pack.new("res://assets/data/frost_world.json", "res://assets/sprites/frost_hd/manifest.json")
	var seen := 0
	for run: int in RUNS:
		for n in range(1, pack.floor_count() + 1):
			# Act
			var W := RoomFloor.build(n, run, pack)
			if W.is_empty():
				continue
			var lakes: Array = (W.rooms as Array).filter(func(r: Dictionary) -> bool: return bool(r.get("ice_lake", false)))
			var ice: Array = (W.rooms as Array).filter(func(r: Dictionary) -> bool: return bool(r.get("ice", false)))
			seen += lakes.size()
			# Assert
			for r: Dictionary in lakes:
				_check(bool(r.get("ice", false)), "run %d floor %d: the lake is ice" % [run, n])
				_check(str(r.type) == "combat", "run %d floor %d: the lake is a fight room" % [run, n])
			if not lakes.is_empty():
				_check(ice.size() == lakes.size(), "run %d floor %d: no extra ice room beside a lake" % [run, n])
	_check(seen > 0, "ice lakes turn up on the floors (%d)" % seen)
	for id: String in LAKES:
		_check(bool(_room(id).get("ice_lake", false)), "%s is an ice lake" % id)
		_check(not (_room(id).get("areas", {}) as Dictionary).is_empty(), "%s has firm snowfields" % id)

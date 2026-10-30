extends SceneTree
## The snow at the Frostgruft's walls (src/hero/frost_wall_snow.gd, story-012): the contact edges
## of small hand-drawn grids (a straight north wall, left and right side walls, inner and outer
## corners, a doorway, the stairs door, the abyss side, ice), the same pieces for the same floor
## every time, every piece the game can lay drawn in both graphics sets, the theme's values all
## read, and on a real floor: the walls' collision and the game state untouched by the snow.
## Usage: godot --headless --path . --script res://tests/frost_wall_snow_test.gd

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FrostWallSnow = preload("res://src/hero/frost_wall_snow.gd")
const FrostSnow = preload("res://src/hero/frost_snow.gd")
const GRAPHICS := "user://frost_wall_snow_test.cfg"
const THEME := "res://assets/data/frost_theme.json"
const SETS := ["res://assets/sprites/frost/", "res://assets/sprites/frost_hd/"]
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FROST_WALL_SNOW_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_straight_north_wall_runs_and_turns_into_inner_corners()
	_test_side_walls_left_and_right()
	_test_outer_corner_wraps_and_owns_the_side_above()
	_test_doorway_stays_free()
	_test_stairs_door_and_wide_hanging_decor_keep_the_foot_free()
	_test_abyss_side_and_ice_get_no_snow()
	_test_same_floor_same_pieces()
	_test_every_piece_is_drawn_in_both_sets()
	_test_theme_values_are_all_read()
	_test_objects_use_contact_embedding_instead_of_drift_rings()
	await _test_real_floor_keeps_collision_and_state()
	print("FROST_WALL_SNOW checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## A grid from rows of characters: '#' wall or void, '.' snow floor, 'i' glaze ice, 'd' a doorway.
func _grid(rows: Array) -> Dictionary:
	var cols: int = str(rows[0]).length()
	var grid := PackedByteArray()
	var snow := {}
	var doors := {}
	for y in range(rows.size()):
		for x in range(cols):
			var c := str(rows[y])[x]
			grid.append(0 if c == "#" else (2 if c == "i" else 1))
			if c == ".":
				snow[y * cols + x] = true
			if c == "d":
				doors[y * cols + x] = true
	return {"grid": grid, "cols": cols, "rows": rows.size(), "snow": snow, "doors": doors}


func _edges(m: Dictionary, blocked := {}) -> Array:
	return FrostWallSnow.contacts(m.grid, m.cols, m.rows, m.snow, blocked, m.doors)


func _edge(edges: Array, side: String, x: int, y: int) -> Dictionary:
	for e: Dictionary in edges:
		if e.side == side and e.x == x and e.y == y:
			return e
	return {}


func _test_straight_north_wall_runs_and_turns_into_inner_corners() -> void:
	var edges := _edges(_grid(["#######", "#.....#", "#.....#", "#######"]))
	var mid := _edge(edges, "n", 3, 1)
	check(mid.get("a") == "run" and mid.get("b") == "run", "a straight north wall runs on along its middle")
	check(_edge(edges, "n", 1, 1).get("a") == "inner" and _edge(edges, "n", 5, 1).get("b") == "inner", "the north wall turns into the side walls at inner corners")
	check(_edge(edges, "w", 1, 1).get("a") == "inner" and _edge(edges, "e", 5, 1).get("a") == "inner", "the side walls start at those inner corners")
	var s := _edge(edges, "s", 3, 2)
	check(s.get("a") == "run" and s.get("b") == "run", "the front wall runs on as well")


func _test_side_walls_left_and_right() -> void:
	var edges := _edges(_grid(["#####", "#...#", "#...#", "#...#", "#####"]))
	var left := _edge(edges, "w", 1, 2)
	var right := _edge(edges, "e", 3, 2)
	check(not left.is_empty() and not right.is_empty(), "both side walls have contact edges")
	check(left.get("a") == "run" and left.get("b") == "run", "a left side wall runs on down its middle")
	check(right.get("a") == "run" and right.get("b") == "run", "a right side wall runs on down its middle")
	check(_edge(edges, "w", 1, 3).get("b") == "end", "a side lip runs out at the front wall")
	var lw := FrostWallSnow.new(null, {})
	var pl: Array = lw.place(left, 96.0, 1).map(func(p: Array) -> String: return p[1])
	var pr: Array = lw.place(right, 96.0, 1).map(func(p: Array) -> String: return p[1])
	check(pl.any(func(n: String) -> bool: return n.begins_with("snow_wall_lip_left_")) and pr.any(func(n: String) -> bool: return n.begins_with("snow_wall_lip_right_")),
		"left and right side walls get their own pieces (not one mirrored)")


func _test_outer_corner_wraps_and_owns_the_side_above() -> void:
	# a wall block sticking into the room: its foot has outer corners on both sides
	var m := _grid(["#######", "#..#..#", "#.....#", "#######"])
	var edges := _edges(m)
	var n := _edge(edges, "n", 3, 2)
	check(n.get("a") == "outer" and n.get("b") == "outer", "the lip at the block's foot meets outer corners at both ends")
	check(_edge(edges, "e", 2, 1).get("b") == "outer" and _edge(edges, "w", 4, 1).get("a") == "inner", "the block's sides know the corner below")
	var lw := FrostWallSnow.new(null, {})
	var names: Array = lw.place(n, 96.0, 1).map(func(p: Array) -> String: return p[1])
	check("snow_wall_corner_outer_l" in names and "snow_wall_corner_outer_r" in names, "both outer corners get their corner piece")
	var side: Array = lw.place(_edge(edges, "e", 2, 1), 96.0, 1).filter(func(p: Array) -> bool: return p[0] == "lip" and (p[2] as Vector2).y >= 96.0 + 48.0)
	check(side.is_empty(), "the side's lower half above an outer corner gets no second lip (no doubled snow)")
	var inner: Array = lw.place(_edge(edges, "n", 1, 1), 96.0, 1).map(func(p: Array) -> String: return p[1])
	var inner_side: Array = lw.place(_edge(edges, "w", 1, 1), 96.0, 1).filter(func(p: Array) -> bool: return p[0] == "lip" and (p[2] as Vector2).y < 96.0 + 48.0)
	check("snow_wall_corner_inner_l" in inner and inner_side.is_empty(), "an inner corner is one corner piece, the side's top half gets no second lip")


func _test_doorway_stays_free() -> void:
	var edges := _edges(_grid(["##d##", "#...#", "#...#", "#####"]))
	check(_edge(edges, "n", 2, 1).is_empty(), "no lip across a doorway")
	check(_edge(edges, "n", 1, 1).get("b") == "end" and _edge(edges, "n", 3, 1).get("a") == "end", "the lips beside a doorway run out")
	check(_edge(edges, "n", 1, 1).get("a") == "end", "a corner in the door's frame does not pile up")
	check(_edge(edges, "w", 1, 1).is_empty() and _edge(edges, "e", 3, 1).is_empty(), "the side walls in the door's frame stay clear")
	check(not _edge(edges, "w", 1, 2).is_empty(), "the side walls beyond the door's frame have their lip again")


func _test_stairs_door_and_wide_hanging_decor_keep_the_foot_free() -> void:
	var m := _grid(["#######", "#.....#", "#######"])
	var W := {"cols": m.cols, "wall_decor": [{"name": "door_stairs", "x": 3.5 * 96.0, "y": 96.0 - 100.0}]}
	var blocked := FrostWallSnow.blocked_north(W, 96.0, FrostWallSnow.KEEP_FREE, {"door_stairs": Vector2(80, 96)})
	var edges := _edges(m, blocked)
	check(_edge(edges, "n", 3, 1).is_empty(), "no lip at the foot of the stairs door")
	check(_edge(edges, "n", 2, 1).get("b") == "end" and _edge(edges, "n", 4, 1).get("a") == "end", "the lips beside the stairs door run out")
	var banner := {"cols": m.cols, "wall_decor": [{"name": "banner_1", "x": 2.5 * 96.0, "y": 96.0 - 68.0}]}
	check(FrostWallSnow.blocked_north(banner, 96.0, [], {"banner_1": Vector2(76, 104)}).has(1 * m.cols + 2), "a wide banner hanging past the wall's foot hangs in front of the snow")
	check(FrostWallSnow.blocked_north(banner, 96.0, [], {"banner_1": Vector2(40, 104)}).is_empty(), "a narrow hanging thing may stand in the lip")


func _test_abyss_side_and_ice_get_no_snow() -> void:
	var m := _grid(["######", "#..#.#", "#..#i#", "######"])
	var edges := _edges(m)
	check(edges.all(func(e: Dictionary) -> bool: return m.snow.has(int(e.y) * int(m.cols) + int(e.x))), "every contact edge belongs to a snow cell (the lip lies on its side, never the abyss side)")
	check(_edge(edges, "w", 4, 2).is_empty() and _edge(edges, "s", 4, 2).is_empty(), "glaze ice beside a wall gets no lip")
	check(_edge(edges, "n", 4, 1).get("a") == "inner", "a snow cell above ice still has its own north lip")


func _test_same_floor_same_pieces() -> void:
	var m := _grid(["##########", "#........#", "#........#", "##########"])
	var edges := _edges(m)
	var a := FrostWallSnow.new(null, {})
	var b := FrostWallSnow.new(null, {})
	var first := edges.map(func(e: Dictionary) -> Array: return a.place(e, 96.0, 1234))
	var again := edges.map(func(e: Dictionary) -> Array: return b.place(e, 96.0, 1234))
	check(first == again, "the same floor gets the same pieces every time (no per-frame or per-run chance)")
	check(edges == _edges(m), "the same grid gives the same contact edges")
	var other := edges.map(func(e: Dictionary) -> Array: return a.place(e, 96.0, 99))
	check(first != other, "another floor gets another arrangement")
	var names := {}
	for list: Array in first:
		for p: Array in list:
			if str(p[1]).begins_with("snow_wall_lip_h_") and not str(p[1]).contains("end"):
				names[p[1]] = true
	check(names.size() >= 4, "a long wall is laid from several different pieces (%d)" % names.size())
	# where two halves meet they agree on the join
	for e: Dictionary in edges:
		if e.side != "n" or e.a != "run" or e.b != "run":
			continue
		var right: Array = a.place(e, 96.0, 1234).filter(func(p: Array) -> bool: return p[0] == "lip")
		var nxt := _edge(edges, "n", int(e.x) + 1, int(e.y))
		if nxt.is_empty() or nxt.a != "run":
			continue
		var left: Array = a.place(nxt, 96.0, 1234).filter(func(p: Array) -> bool: return p[0] == "lip")
		var end_join := str(right[1][1]).split("_")[4][1]
		var start_join := str(left[0][1]).split("_")[4][0]
		check(end_join == start_join, "halves meeting at a cell edge agree on their join (%s %s)" % [right[1][1], left[0][1]])


func _test_every_piece_is_drawn_in_both_sets() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FrostWallSnow.DATA_PATH))
	var anchors: Dictionary = data.anchors
	var lw := FrostWallSnow.new(null, {})
	var wanted := {}
	var maps := [["#########", "#...#...#", "#.......#", "#..##...#", "#.......#", "#########"], ["##d####", "#.....#", "#.i...#", "#######"]]
	for rows: Array in maps:
		for e: Dictionary in _edges(_grid(rows)):
			for seed in range(12):
				for p: Array in lw.place(e, 96.0, seed):
					wanted[p[1]] = true
	check(wanted.size() > 20, "the test grids use many pieces (%d)" % wanted.size())
	for n: String in wanted:
		check(anchors.has(n), "%s has an anchor in frost_wall_snow.json" % n)
	for dir: String in SETS:
		var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
		for n: String in anchors:
			check(man.has(n) and ResourceLoader.exists(dir + n + ".png"), "%s is drawn in %s" % [n, dir])


func _test_theme_values_are_all_read() -> void:
	var theme: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THEME))
	for k: String in theme.snow:
		check(k == "_note" or FrostSnow.DEFAULTS.has(k), "theme snow key '%s' is read by frost_snow.gd" % k)
	check(theme.has("wall_snow"), "the theme has its wall snow block")
	for k: String in theme.get("wall_snow", {}):
		check(k == "_note" or FrostWallSnow.DEFAULTS.has(k), "theme wall_snow key '%s' is read by frost_wall_snow.gd" % k)


func _test_objects_use_contact_embedding_instead_of_drift_rings() -> void:
	var pile: Dictionary = FrostSnow.embedding_style("skull_pile", "prop")
	var urn: Dictionary = FrostSnow.embedding_style("urn_a", "prop")
	var brazier: Dictionary = FrostSnow.embedding_style("brazier_bowl", "ent")
	var bone: Dictionary = FrostSnow.embedding_style("bone_a", "prop")
	var plate: Dictionary = FrostSnow.embedding_style("rune_plate", "frame")
	check(pile.get("kind") == "baked" and urn.get("kind") == "baked" and brazier.get("kind") == "baked",
		"large props use snow baked to their true lower silhouette, not runtime drift rows")
	check(bone.get("kind") == "small" and float(bone.get("shadow", 0.0)) < 24.0,
		"a loose bone gets only a small contact mark")
	check(plate.get("kind") == "inset" and int(plate.get("clumps", -1)) <= 2,
		"a floor plate gets an inset seam and at most two accents, never a four-sided snow ring")


func _test_real_floor_keeps_collision_and_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", "pixel")
	cfg.save(GRAPHICS)
	var game: Node = FrostScene.instantiate()
	game.graphics_path = GRAPHICS
	root.add_child(game)
	for i in range(4):
		await process_frame
	var walls: Object = game.frost_snow.walls
	check(walls.edges.size() > 50, "a real floor has wall contacts (%d)" % walls.edges.size())
	check(not walls.chunks.is_empty(), "their pieces are cached per chunk")
	var grid: PackedByteArray = game.W.grid.duplicate()
	var solids := var_to_str(game.get("solids"))
	var saved := var_to_str(game.state)
	var saved_keys: Array = game.state.keys()
	saved_keys.sort()
	var before := var_to_str(walls.chunks)
	walls.build(game.frost_snow.snow)
	game.frost_snow.walls_changed()
	await process_frame
	check(game.W.grid == grid, "building the wall snow leaves the floor's grid as it was")
	check(var_to_str(game.get("solids")) == solids, "building the wall snow leaves the walls' collision as it was")
	check(var_to_str(walls.chunks) == before, "building it again gives the same pieces")
	var keys: Array = game.state.keys()
	keys.sort()
	check(not saved.contains("snow_wall") and not var_to_str(game.state).contains("snow_wall") and keys == saved_keys,
		"the wall snow is no part of the game state (nothing saved or sent)")
	var layers := (game.get("_chunk_nodes") as Array).filter(func(n: Node) -> bool: return str(n.get("kind")).begins_with("snow_"))
	check(layers.size() > 0 and layers.all(func(n: CanvasItem) -> bool: return n.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST), "the snow layers draw with nearest filtering")
	var z := {}
	for n: CanvasItem in layers:
		z[n.get("kind")] = n.z_index
	check(int(z.get("snow_ao", 0)) > 0 and int(z.get("snow_ao", 0)) < int(z.get("snow_lip", 0)) and int(z.get("snow_lip", 0)) < int(game.actors.z_index), "seams over the walls, lips over the seams, actors over the lips")
	check(int(z.get("snow_front", 0)) > 20, "the lips at front walls lie over those walls")
	game.queue_free()
	await process_frame

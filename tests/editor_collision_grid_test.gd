extends SceneTree
## Pure cell-center classification. No game, rendering, filesystem writes or peers.
var checked := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("EDITOR_GRID_FAIL ",label)

func fixture() -> Dictionary:
	var voids := [[0,0,128,32],[0,32,32,32],[96,32,32,32],[0,64,128,32]]
	return {"layout_mode":"freeform","tile_size":32,"world_size":[128,96],"play_bounds":[0,0,128,96],
		"painted_tiles":[
			{"x":1,"y":1,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"},
			{"x":2,"y":1,"tile":"violet_017","rotation":0,"solid":false,"layer":"floor"},
			{"x":1,"y":1,"tile":"violet_002","rotation":1,"solid":true,"layer":"structure"},
			{"x":2,"y":1,"tile":"items_030","rotation":0,"solid":false,"layer":"structure"}],
		"tile_obstacles":[[32,32,32,32]],"void_obstacles":voids,
		"obstacles":[[32,32,32,32]]+voids,
		"authored_doors":[{"x":0,"y":1,"side":"west","tile":"items_002","rotation":3}],
		"exits":[]}

func _initialize() -> void:
	var path := "res://src/editor_collision_grid.gd"
	check(FileAccess.file_exists(path),"collision classifier exists")
	if not FileAccess.file_exists(path):
		finish()
		return
	var Grid = load(path)
	var layout := fixture()
	var before := var_to_str(layout)
	var cells: Dictionary = Grid.classify(layout)
	check(cells.size() == 12 and cells.has(Vector2i(3,2)),"every canvas cell including edges is classified")
	check(cells[Vector2i(1,1)].kind == "wall" and cells[Vector2i(1,1)].blocked,"solid wall over floor is blocked")
	check(cells[Vector2i(2,1)].kind == "walkable" and not cells[Vector2i(2,1)].blocked,"non-solid decoration preserves walkable floor")
	check(cells[Vector2i(0,0)].kind == "void" and cells[Vector2i(0,0)].blocked,"generated void obstacles do not become red wall art")
	check(cells[Vector2i(0,1)].kind == "void" and cells[Vector2i(0,1)].blocked,"door graphic on void never invents walkable floor")
	check(var_to_str(layout) == before,"classification does not mutate snapshot or nested arrays")
	layout.painted_tiles[2].rotation = 3
	cells = Grid.classify(layout)
	check(cells[Vector2i(1,1)].kind == "wall","quarter turns do not alter square collision")
	layout.painted_tiles[2].solid = false
	layout.tile_obstacles = []
	layout.obstacles = layout.void_obstacles.duplicate(true)
	cells = Grid.classify(layout)
	check(cells[Vector2i(1,1)].kind == "walkable","replacing wall with non-solid art clears blockage immediately")
	layout.painted_tiles.remove_at(0)
	cells = Grid.classify(layout)
	check(cells[Vector2i(1,1)].kind == "void","removing floor restores void even below decoration")
	layout = fixture()
	layout.painted_tiles.append({"x":3,"y":1,"tile":"violet_002","rotation":0,"solid":true,"layer":"structure"})
	cells = Grid.classify(layout)
	check(cells[Vector2i(3,1)].kind == "wall","explicit wall on void remains a marked wall")
	var legacy := {"tile_size":32,"world_size":[128,96],"play_bounds":[16,24,96,56],"obstacles":[[64,32,32,32]],"painted_tiles":[]}
	cells = Grid.classify(legacy)
	check(cells[Vector2i(0,0)].kind == "void" and cells[Vector2i(0,1)].kind == "walkable","legacy half-cell bounds use the actual cell center")
	check(cells[Vector2i(2,1)].kind == "wall","legacy rectangle obstacles stay blocked")
	check(cells[Vector2i(3,1)].kind == "walkable","center exactly on physical bound is tested without actor radius")
	check(not cells[Vector2i(0,1)].reason.is_empty() and not cells[Vector2i(2,1)].reason.is_empty(),"hover reasons are present")
	legacy.obstacles = [[0,0,128,96]]
	cells = Grid.classify(legacy)
	check(cells[Vector2i(1,1)].kind == "wall","physical geometry overrides absent painted metadata")
	check(Grid.classify({"world_size":[1000000,1000000]}).is_empty(),"oversized snapshots are bounded")
	layout = fixture()
	layout.collision_overrides = [{"x":1,"y":1,"blocked":false},{"x":0,"y":1,"blocked":true}]
	cells = Grid.classify(layout)
	check(cells[Vector2i(1,1)].kind == "walkable" and not cells[Vector2i(1,1)].blocked,"manual walkable takes precedence over solid artwork")
	check(cells[Vector2i(0,1)].kind == "wall" and cells[Vector2i(0,1)].blocked,"manual blocked on empty background is visibly blocked")
	layout.collision_overrides = [{"x":0,"y":1,"blocked":false}]
	cells = Grid.classify(layout)
	check(cells[Vector2i(0,1)].kind == "walkable","manual invisible floor is shown as walkable")
	finish()

func finish() -> void:
	print("EDITOR_COLLISION_GRID checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)

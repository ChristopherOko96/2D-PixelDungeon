extends RefCounted
## Authoring state only. No file writes, game instances or network peers.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const HISTORY_LIMIT := 64
var config: Dictionary
var selected := 0
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _before: Dictionary = {}
var _saved := ""

func _init(initial: Dictionary) -> void:
	config = initial.duplicate(true)
	ensure_defaults()
	mark_saved()

## Makes implicit prop defaults explicit, so walls cannot silently bury them.
func ensure_defaults() -> void:
	config = Dungeon.upgrade_config(config)
	config.generator_version = Dungeon.GENERATOR_VERSION
	for room: Dictionary in config.templates:
		if room.get("layout_mode","") == "freeform":
			if not room.has("brazier_spawns"): room.brazier_spawns = []
			continue
		if not room.has("brazier_spawns"): room.brazier_spawns = [[72,78],[824,78],[72,402],[824,402]]
		if not room.has("reward_spawn"): room.reward_spawn = [448,240]

## Current room, edited within an explicit begin/end transaction.
func template() -> Dictionary:
	return config.templates[selected]

## Groups a whole brush stroke into one reversible action.
func begin_edit() -> void:
	if _before.is_empty(): _before = {"config":config.duplicate(true),"selected":selected}

## Ends the transaction; unchanged gestures do not consume undo history.
func end_edit() -> void:
	if _before.is_empty(): return
	if config != _before.config:
		if config.has("crypt_procedural"): config.crypt_procedural = false
		_undo.append(_before)
		if _undo.size() > HISTORY_LIMIT: _undo.pop_front()
		_redo.clear()
	_before = {}

## Restores the previous complete authoring state.
func undo() -> void:
	end_edit()
	if _undo.is_empty(): return
	_redo.append({"config":config.duplicate(true),"selected":selected})
	_restore(_undo.pop_back())

## Reapplies the most recently undone change.
func redo() -> void:
	if _redo.is_empty(): return
	_undo.append({"config":config.duplicate(true),"selected":selected})
	_restore(_redo.pop_back())

## Enables toolbar actions only when a matching history entry exists.
func can_undo() -> bool:
	return not _undo.is_empty()

## Whether an undone edit can be restored.
func can_redo() -> bool:
	return not _redo.is_empty()

func _restore(state: Dictionary) -> void:
	config = state.config.duplicate(true)
	selected = clampi(int(state.selected),0,config.templates.size()-1)

## Expands rectangles to editable native tile cells.
func wall_cells() -> Dictionary:
	var cells := {}
	for rect: Array in template().obstacles_tiles:
		for y in range(int(rect[1]),int(rect[1]+rect[3])):
			for x in range(int(rect[0]),int(rect[0]+rect[2])): cells[Vector2i(x,y)] = true
	return cells

## Freeform uses every canvas cell; legacy rooms retain their exterior frame.
func editable(cell: Vector2i) -> bool:
	var bounds := room_bounds()
	return bounds.encloses(Rect2(Vector2(cell)*float(config.tile_size),Vector2.ONE*float(config.tile_size)))

## Paints/erases collision cells and merges adjoining runs into rectangles.
func paint_wall(cell: Vector2i, solid: bool) -> void:
	if template().get("layout_mode","") == "freeform": return
	if not editable(cell): return
	_clear_collision_at(cell)
	var cells := wall_cells()
	if solid: cells[cell] = true
	else: cells.erase(cell)
	var rectangles: Array = []
	var dimensions := room_size()/32
	for y in range(int(dimensions.y)):
		var x := 0
		while x < int(dimensions.x):
			if not cells.has(Vector2i(x,y)):
				x += 1
				continue
			var start := x
			while x < int(dimensions.x) and cells.has(Vector2i(x,y)): x += 1
			var merged := false
			for rect: Array in rectangles:
				if int(rect[0]) == start and int(rect[2]) == x-start and int(rect[1]+rect[3]) == y:
					rect[3] = int(rect[3])+1
					merged = true
					break
			if not merged: rectangles.append([start,y,x-start,1])
	template().obstacles_tiles = rectangles

## Places one mandatory spawn slot; unsafe drafts remain editable but unpublishable.
func set_spawn(kind: String, index: int, point: Vector2) -> void:
	if kind not in ["player_spawns","enemy_spawns"] or not point.is_finite(): return
	var maximum := 4 if kind == "player_spawns" else 5
	if index < 0 or index >= maximum or index > template()[kind].size(): return
	if not room_bounds().has_point(point): return
	if index == template()[kind].size(): template()[kind].append([point.x,point.y])
	else: template()[kind][index] = [point.x,point.y]

## Removes a deliberately placed slot; remaining slot numbers close the gap.
func remove_spawn(kind: String, index: int) -> bool:
	if kind not in ["player_spawns","enemy_spawns"] or index < 0 or index >= template()[kind].size(): return false
	template()[kind].remove_at(index)
	return true

## Persists one of the four original palettes for this room.
func set_theme(theme: String) -> void:
	if theme in Dungeon.THEMES: template().theme = theme

## Opposite openings use the same lane, preserving matching room connections.
func set_door_lane(side: String, point: Vector2) -> void:
	if template().has("world_size"):
		var bounds := room_bounds()
		var local: Dictionary = template().get("door_lanes",{})
		if side in ["north","south"]: local.vertical = clampf(snappedf(point.x,32),bounds.position.x+64,bounds.end.x-64)
		elif side in ["west","east"]: local.horizontal = clampf(snappedf(point.y,32),bounds.position.y+64,bounds.end.y-64)
		template().door_lanes = local
		return
	var lanes: Dictionary = config.get("door_lanes", {})
	if side in ["north","south"]: lanes.vertical = clampf(snappedf(point.x,32),96,800)
	elif side in ["west","east"]: lanes.horizontal = clampf(snappedf(point.y,32),112,384)
	config.door_lanes = lanes

## Adds a uniquely named blank room, preserving the complete existing library.
func create_room(duplicate: bool = false) -> String:
	if config.templates.size() >= 64: return ""
	begin_edit()
	var room: Dictionary = template().duplicate(true)
	var number := 1
	var id := "room_%03d" % number
	var ids: Array = config.templates.map(func(value: Dictionary): return str(value.id))
	while id in ids:
		number += 1
		id = "room_%03d" % number
	room.id = id
	room.title = "MEIN RAUM %03d" % number
	if not duplicate:
		var size := room_size()
		room = {"id":id,"title":"MEIN RAUM %03d" % number,"boss":false,
			"layout_mode":"freeform","world_size":[size.x,size.y],"play_bounds":[0,0,size.x,size.y],
			"obstacles_tiles":[],"painted_tiles":[],"authored_doors":[],
			"player_spawns":[],"enemy_spawns":[],"brazier_spawns":[],"blank":true,"reward_visible":false}
	config.templates.append(room)
	selected = config.templates.size()-1
	end_edit()
	return id

## Effective room dimensions, independent from all other library templates.
func room_size() -> Vector2:
	var values: Array = template().get("world_size",config.world_size)
	return Vector2(values[0],values[1])

## Full canvas for freeform; legacy rooms retain their previous floor bounds.
func room_bounds() -> Rect2:
	var values: Array = template().get("play_bounds",config.play_bounds)
	return Rect2(values[0],values[1],values[2],values[3])

## Resizes one template atomically. Refuses to crop existing wall/tile/prop art.
## Freeform slots never move automatically. Legacy slots retain reflow behavior.
func resize_room(tiles: Vector2i) -> String:
	if tiles.x < 12 or tiles.x > 64 or tiles.y < 10 or tiles.y > 48: return "Raumgröße: 12–64 Felder breit und10–48 Felder hoch."
	var world := Vector2(tiles)*32
	var freeform: bool = template().get("layout_mode","") == "freeform"
	var bounds := Rect2(Vector2.ZERO,world) if freeform else Rect2(32,64,world.x-64,world.y-96)
	for rect: Array in template().obstacles_tiles:
		if not bounds.encloses(Rect2(rect[0]*32,rect[1]*32,rect[2]*32,rect[3]*32)): return "Wände liegen außerhalb der neuen Größe. Vorher entfernen oder größere Maße wählen."
	if not Dungeon.valid_painted_tiles(template().get("painted_tiles",[]),bounds): return "Gesetzte Tiles würden abgeschnitten. Vorher entfernen oder größere Maße wählen."
	for entry: Dictionary in template().get("collision_overrides",[]):
		if not bounds.encloses(Rect2(float(entry.x)*32,float(entry.y)*32,32,32)): return "Eine manuell gesetzte Begehbarkeit würde abgeschnitten. Vorher ändern oder größere Maße wählen."
	for point: Array in template().get("brazier_spawns",[]):
		if not bounds.grow(-16).has_point(Vector2(point[0],point[1])): return "Feuer liegt außerhalb der neuen Größe. Vorher versetzen."
	if freeform:
		for key: String in ["player_spawns","enemy_spawns"]:
			for point: Array in template()[key]:
				if not bounds.has_point(Vector2(point[0],point[1])): return "Ein Startpunkt würde abgeschnitten. Vorher versetzen."
		for key: String in ["reward_spawn","stairs_spawn"]:
			if template().has(key) and not bounds.has_point(Vector2(template()[key][0],template()[key][1])): return "Truhe oder Treppe würde abgeschnitten. Vorher versetzen."
		for door: Dictionary in template().get("authored_doors",[]):
			if not bounds.encloses(Rect2(float(door.x)*32,float(door.y)*32,32,32)): return "Eine Tür würde abgeschnitten. Vorher versetzen."
	begin_edit()
	template().world_size = [world.x,world.y]
	template().play_bounds = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	if freeform:
		end_edit()
		return ""
	template().door_lanes = {}
	template().player_spawns = []
	template().enemy_spawns = []
	for index in range(4): template().player_spawns.append([96+index*32,128])
	for index in range(5): template().enemy_spawns.append([world.x-96-(index%2)*32,192+(index/2)*32])
	template().reward_spawn = [world.x*0.5,world.y*0.5]
	if template().has("stairs_spawn"): template().erase("stairs_spawn")
	end_edit()
	return ""

## One chosen tile per cell; empty ID erases it. Geometry and art stay in sync.
func paint_tile(cell: Vector2i, id: String, rotation: int, solid: bool, layer: String = "structure") -> void:
	if not editable(cell) or (id != "" and not Dungeon.Palette.valid_id(id)): return
	if layer not in ["floor","structure"]: return
	_clear_collision_at(cell)
	var freeform: bool = template().get("layout_mode","") == "freeform"
	var cells: Array = template().get("painted_tiles",[]).duplicate(true)
	for index in range(cells.size()-1,-1,-1):
		var existing_layer: String = str(cells[index].get("layer","structure" if cells[index].solid else "floor"))
		if int(cells[index].x) == cell.x and int(cells[index].y) == cell.y and (not freeform or existing_layer == layer): cells.remove_at(index)
	if id != "":
		var entry := {"x":cell.x,"y":cell.y,"tile":id,"rotation":posmod(rotation,4),"solid":solid if layer != "floor" else false}
		if freeform: entry.layer = layer
		cells.append(entry)
	template().painted_tiles = cells

## Floor establishes the authored walkable footprint. Erasing it restores void.
func paint_floor(cell: Vector2i, id: String, rotation: int, erase: bool = false) -> void:
	paint_tile(cell,"" if erase else id,rotation,false,"floor")

## Visible replacement removes tile/door overlays at this cell, preserving the
## underlying floor when placing structure and all spawn/prop authoring data.
## Caller groups the whole operation in one Undo transaction.
func replace_visible_tile(cell: Vector2i, id: String, rotation: int, solid: bool, layer: String) -> void:
	if not editable(cell) or not Dungeon.Palette.valid_id(id) or layer not in ["floor","structure"]: return
	if template().get("layout_mode","") == "freeform":
		if layer == "floor": paint_tile(cell,"",0,false,"structure")
		set_authored_door(cell,"north","",0,true)
		if template().has("stairs_spawn"):
			var point: Array = template().stairs_spawn
			if Vector2i(floori(float(point[0])/32),floori(float(point[1])/32)) == cell:
				template().erase("stairs_spawn")
				template().erase("stairs_art")
	else: paint_wall(cell,false)
	paint_tile(cell,id,rotation,solid,layer)

## Edits a clipped rectangle in one Undo action. No per-cell deep copies.
## Visible erasure removes both tile layers and doors/stairs in this region;
## spawns, fire, chest and other rooms are deliberately preserved.
func edit_area(cells: Rect2i, tile: String, rotation: int, solid: bool, layer: String, erase: bool, replace_visible: bool = true) -> Dictionary:
	if cells.size.x <= 0 or cells.size.y <= 0 or cells.size.x > 64 or cells.size.y > 48:
		return {"error":"Die Auswahl muss zwischen1×1 und64×48 Felder groß sein.","changed":0}
	if layer not in ["floor","structure"] or (not erase and not Dungeon.Palette.valid_id(tile)):
		return {"error":"Wähle ein gültiges Tile und eine Ebene.","changed":0}
	var bounds := room_bounds()
	# Add as64-bit integers before clipping, never through Rect2i.end.
	var end_x: int = int(cells.position.x)+int(cells.size.x)
	var end_y: int = int(cells.position.y)+int(cells.size.y)
	var left: int = maxi(int(cells.position.x),int(ceilf(bounds.position.x/32)))
	var top: int = maxi(int(cells.position.y),int(ceilf(bounds.position.y/32)))
	var right: int = mini(end_x,int(floorf(bounds.end.x/32)))
	var bottom: int = mini(end_y,int(floorf(bounds.end.y/32)))
	if left >= right or top >= bottom: return {"error":"","changed":0}
	var targets := {}
	for y in range(top,bottom):
		for x in range(left,right): targets[Vector2i(x,y)] = true
	var room: Dictionary = template()
	var freeform: bool = room.get("layout_mode","") == "freeform"
	var updated := room.duplicate(true)
	var painted: Array = []
	for entry: Dictionary in room.get("painted_tiles",[]):
		var cell := Vector2i(int(entry.x),int(entry.y))
		var entry_layer: String = str(entry.get("layer","structure" if entry.solid else "floor"))
		var remove: bool = targets.has(cell) and (not freeform or (erase and replace_visible) or entry_layer == layer or (not erase and replace_visible and layer == "floor" and entry_layer == "structure"))
		if not remove: painted.append(entry.duplicate(true))
	if not erase:
		for cell: Vector2i in targets:
			var entry := {"x":cell.x,"y":cell.y,"tile":tile,"rotation":posmod(rotation,4),"solid":solid if layer != "floor" else false}
			if freeform: entry.layer = layer
			painted.append(entry)
	updated.painted_tiles = painted
	_clear_collision_overrides(updated,targets)
	if replace_visible:
		if freeform:
			var doors: Array = []
			for door: Dictionary in room.get("authored_doors",[]):
				if not targets.has(Vector2i(int(door.x),int(door.y))): doors.append(door.duplicate(true))
			updated.authored_doors = doors
			if room.has("stairs_spawn"):
				var point: Array = room.stairs_spawn
				if targets.has(Vector2i(floori(float(point[0])/32),floori(float(point[1])/32))):
					updated.erase("stairs_spawn")
					updated.erase("stairs_art")
		var walls := _area_walls(room)
		var removed := false
		for cell: Vector2i in targets:
			if walls.erase(cell): removed = true
		if removed: updated.obstacles_tiles = _area_wall_rectangles(walls)
	var before := _area_states(room,targets)
	var after := _area_states(updated,targets)
	var changed := 0
	for cell: Vector2i in targets:
		if before[cell] != after[cell]: changed += 1
	if changed == 0: return {"error":"","changed":0}
	end_edit()
	begin_edit()
	config.templates[selected] = updated
	end_edit()
	return {"error":"","changed":changed}

## Changes only explicit collision state, never art or object placement.
## The bounded clipped batch has one Undo entry; repeat settings are no-ops.
func set_area_walkability(cells: Rect2i, walkable: bool) -> Dictionary:
	if cells.size.x <= 0 or cells.size.y <= 0 or cells.size.x > 64 or cells.size.y > 48:
		return {"error":"Die Auswahl muss zwischen1×1 und64×48 Felder groß sein.","changed":0}
	var bounds := room_bounds()
	var end_x: int = int(cells.position.x)+int(cells.size.x)
	var end_y: int = int(cells.position.y)+int(cells.size.y)
	var left: int = maxi(int(cells.position.x),int(ceilf(bounds.position.x/32)))
	var top: int = maxi(int(cells.position.y),int(ceilf(bounds.position.y/32)))
	var right: int = mini(end_x,int(floorf(bounds.end.x/32)))
	var bottom: int = mini(end_y,int(floorf(bounds.end.y/32)))
	if left >= right or top >= bottom: return {"error":"","changed":0}
	var targets := {}
	for y in range(top,bottom):
		for x in range(left,right): targets[Vector2i(x,y)] = true
	var blocked := not walkable
	var overrides: Array = []
	var changed := 0
	for entry: Dictionary in template().get("collision_overrides",[]):
		var cell := Vector2i(int(entry.x),int(entry.y))
		var value := entry.duplicate(true)
		if targets.erase(cell) and bool(entry.blocked) != blocked:
			value.blocked = blocked
			changed += 1
		overrides.append(value)
	for cell: Vector2i in targets:
		overrides.append({"x":cell.x,"y":cell.y,"blocked":blocked})
		changed += 1
	if changed == 0: return {"error":"","changed":0}
	end_edit()
	begin_edit()
	template().collision_overrides = overrides
	end_edit()
	return {"error":"","changed":changed}

func _clear_collision_at(cell: Vector2i) -> void:
	var targets := {}
	targets[cell] = true
	_clear_collision_overrides(template(),targets)

func _clear_collision_overrides(room: Dictionary, targets: Dictionary) -> void:
	if not room.has("collision_overrides"): return
	var remaining: Array = []
	var removed := false
	for entry: Dictionary in room.collision_overrides:
		if targets.has(Vector2i(int(entry.x),int(entry.y))): removed = true
		else: remaining.append(entry.duplicate(true))
	if not removed: return
	if remaining.is_empty(): room.erase("collision_overrides")
	else: room.collision_overrides = remaining

func _area_walls(room: Dictionary) -> Dictionary:
	var result := {}
	for rect: Array in room.get("obstacles_tiles",[]):
		for y in range(int(rect[1]),int(rect[1]+rect[3])):
			for x in range(int(rect[0]),int(rect[0]+rect[2])): result[Vector2i(x,y)] = true
	return result

func _area_states(room: Dictionary, targets: Dictionary) -> Dictionary:
	var states := {}
	for cell: Vector2i in targets: states[cell] = {}
	for entry: Dictionary in room.get("collision_overrides",[]):
		var cell := Vector2i(int(entry.x),int(entry.y))
		if targets.has(cell): states[cell].collision_override = bool(entry.blocked)
	var freeform: bool = room.get("layout_mode","") == "freeform"
	for entry: Dictionary in room.get("painted_tiles",[]):
		var cell := Vector2i(int(entry.x),int(entry.y))
		if not targets.has(cell): continue
		var layer: String = str(entry.get("layer","structure" if entry.solid else "floor")) if freeform else "tile"
		states[cell][layer] = [str(entry.tile),int(entry.rotation),bool(entry.solid)]
	for door: Dictionary in room.get("authored_doors",[]):
		var cell := Vector2i(int(door.x),int(door.y))
		if targets.has(cell): states[cell].door = [str(door.side),str(door.tile),int(door.rotation)]
	if room.has("stairs_spawn"):
		var point: Array = room.stairs_spawn
		var cell := Vector2i(floori(float(point[0])/32),floori(float(point[1])/32))
		if targets.has(cell): states[cell].stairs = [float(point[0]),float(point[1]),room.get("stairs_art",{})]
	for cell: Vector2i in _area_walls(room):
		if targets.has(cell): states[cell].wall = true
	return states

func _area_wall_rectangles(walls: Dictionary) -> Array:
	var result: Array = []
	var runs := {}
	var width := int(room_size().x/32)
	for y in range(int(room_size().y/32)):
		var x := 0
		while x < width:
			if not walls.has(Vector2i(x,y)):
				x += 1
				continue
			var start := x
			while x < width and walls.has(Vector2i(x,y)): x += 1
			var key := Vector2i(start,x-start)
			var previous: int = int(runs.get(key,-1))
			if previous >= 0 and int(result[previous][1]+result[previous][3]) == y: result[previous][3] += 1
			else:
				runs[key] = result.size()
				result.append([start,y,x-start,1])
	return result

## Places a real doorway anywhere on the canvas and cuts overlaid wall art.
## No floor, opposite opening or arrival point is invented by this gesture.
func set_authored_door(cell: Vector2i, side: String, id: String, rotation: int, erase: bool = false) -> void:
	if template().get("layout_mode","") != "freeform" or not editable(cell): return
	if side not in ["north","east","south","west"] or (not erase and not Dungeon.Palette.valid_id(id)): return
	_clear_collision_at(cell)
	var doors: Array = template().get("authored_doors",[]).duplicate(true)
	for index in range(doors.size()-1,-1,-1):
		if int(doors[index].x) == cell.x and int(doors[index].y) == cell.y: doors.remove_at(index)
	if not erase:
		doors.append({"x":cell.x,"y":cell.y,"side":side,"tile":id,"rotation":posmod(rotation,4)})
		paint_tile(cell,"",0,false,"structure")
	template().authored_doors = doors

## Removes a library entry reversibly; broken floor references must be repaired.
func delete_room() -> bool:
	if config.templates.size() <= 1: return false
	begin_edit()
	config.templates.remove_at(selected)
	selected = mini(selected,config.templates.size()-1)
	end_edit()
	return true

## Renames references together so an authored floor never retains stale IDs.
func rename_room(id: String, title: String, boss: bool) -> String:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]{0,47}$")
	if pattern.search(id) == null: return "Raum-ID: Kleinbuchstaben, Zahlen und Unterstriche verwenden."
	if title.strip_edges().is_empty(): return "Bitte einen Raumnamen eintragen."
	for index in range(config.templates.size()):
		if index != selected and config.templates[index].id == id: return "Diese Raum-ID ist schon vergeben."
	var old_id: String = template().id
	template().id = id
	template().title = title.strip_edges().left(64)
	template().boss = boss
	if config.has("room_order"):
		for index in range(config.room_order.size()):
			if config.room_order[index] == old_id: config.room_order[index] = id
	return ""

## Selects a deliberate three-room floor; the final entry must be a boss room.
func set_fixed_order(ids: Array) -> void:
	config.room_order = ids.duplicate()

## Returns to seeded selection from the room library.
func clear_fixed_order() -> void:
	config.erase("room_order")

## Draws even an incomplete draft; invalid doors are highlighted by the UI.
func preview() -> Dictionary:
	return Dungeon.preview_template(template(),config)

## Full game validation plus every room's ports and four arrival slots.
func validate() -> PackedStringArray:
	var errors := Dungeon.validate_config(config)
	if not errors.is_empty(): return errors
	for room: Dictionary in config.templates:
		var layout := Dungeon.preview_template(room,config)
		if room.get("layout_mode","") == "freeform":
			for exit: Dictionary in layout.exits:
				if exit.get("blocked",false): errors.append("%s: Gesetzter Ausgang oder Ankunftsplätze blockiert." % room.title)
		else:
			for side in ["north","east","south","west"]:
				var exits: Array = layout.exits.filter(func(exit: Dictionary): return exit.kind == "door" and exit.side == side)
				if exits.is_empty() or exits[0].get("blocked",false): errors.append("%s: Tür %s oder Ankunftsplätze blockiert." % [room.title,side])
		if room.boss:
			var stairs: Array = layout.exits.filter(func(exit: Dictionary): return exit.kind == "stairs")
			if stairs.is_empty(): errors.append("%s: Treppenabgang blockiert." % room.title)
		var spawns: Array = layout.player_spawns + layout.enemy_spawns
		for first in range(spawns.size()):
			for second in range(first+1,spawns.size()):
				if spawns[first].distance_to(spawns[second]) < 24:
					errors.append("%s: Startpunkte überlappen." % room.title)
	if errors.is_empty() and config.templates.any(func(room: Dictionary): return room.get("layout_mode","") == "freeform"):
		if Dungeon.generate(3,3,config).is_empty(): errors.append("Deine Tür-Richtungen ergeben noch keinen verbundenen Dungeon bis zum Boss. Passende Gegenrichtungen ergänzen.")
	return errors

## Remembers the last successfully written draft or applied configuration.
func mark_saved() -> void:
	_saved = JSON.stringify(config,"",true)

## Reports whether edits differ from that saved state, including after undo.
func is_dirty() -> bool:
	return _saved != JSON.stringify(config,"",true)

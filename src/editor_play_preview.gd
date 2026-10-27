extends RefCounted
## Prepares one exact authored room for local play, without publishing a library.
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

## Safe preview-only starts never change the template, its art or collision mask.
## No other library rooms, four-player slots or paired ports are required.
static func prepare(config: Dictionary, template: Dictionary, balance: Dictionary) -> Dictionary:
	var room := template.duplicate(true)
	if not Dungeon.valid_room_dimensions(room,config): return {"error":"Die Raumgröße ist ungültig. Wähle eine Zeichenfläche zwischen12×10 und64×48 Feldern."}
	var values: Array = room.get("play_bounds",config.play_bounds)
	var bounds := Rect2(values[0],values[1],values[2],values[3])
	if not Dungeon.valid_painted_tiles(room.get("painted_tiles",[]),bounds): return {"error":"Der ausgewählte Raum enthält ungültige Tile-Zellen."}
	if not Dungeon.valid_collision_overrides(room.get("collision_overrides",[]),bounds): return {"error":"Der ausgewählte Raum enthält ungültige Begehbarkeitsfelder."}
	if not Dungeon.valid_authored_doors(room.get("authored_doors",[]),bounds): return {"error":"Eine Tür im ausgewählten Raum liegt außerhalb der Zeichenfläche oder hat ungültige Daten."}
	var layout := Dungeon.preview_template(room,config)
	var player_radius := float(balance.player.radius)
	var candidates := _clear_cells(layout,player_radius)
	if candidates.is_empty(): return {"error":"Kein begehbarer Bereich für den Spieler vorhanden. Setze Boden oder markiere eine Fläche mit BEGEHBAR MACHEN. Bilder als WAND/DEKO allein erzeugen keinen Boden."}
	var notices: Array[String] = []
	var decorative_floor := 0
	var actual_floor := 0
	if Dungeon.is_freeform(room):
		var manually_walkable := {}
		for override_cell: Dictionary in room.get("collision_overrides",[]):
			if not override_cell.blocked: manually_walkable[Vector2i(int(override_cell.x),int(override_cell.y))] = true
		for cell: Dictionary in room.get("painted_tiles",[]):
			if cell.get("layer","") == "floor": actual_floor += 1
			elif not cell.solid and not manually_walkable.has(Vector2i(int(cell.x),int(cell.y))) and str(cell.tile).get_slice("_",0) in ["violet","rose","moss","amber"] and str(cell.tile).get_slice("_",1) in ["017","011","019"]: decorative_floor += 1
		if decorative_floor > actual_floor: notices.append("Viele Bodenbilder sind DEKO: im Editor BEGEHBAR MACHEN oder als BODEN setzen")
	var spawn: Vector2 = candidates[0]
	var has_start := false
	for point: Vector2 in layout.player_spawns:
		if not Dungeon.segment_blocked(point,point,player_radius,layout):
			spawn = point
			has_start = true
			break
	if not has_start:
		var center := bounds.get_center()
		for point: Vector2 in candidates:
			if point.distance_squared_to(center) < spawn.distance_squared_to(center): spawn = point
		notices.append("Spielerstart ergänzt (nur Vorschau)")
	room.player_spawns = [[spawn.x,spawn.y]]
	# Rebuild ports using the preview start, so authored doors can show their
	# existing art even if the saved draft has no player slots yet.
	layout = Dungeon.preview_template(room,config)
	var enemy_radius := float(balance.boss.radius if room.get("boss",false) else balance.enemy.radius)
	var reachable := _reachable_candidates(spawn,candidates,player_radius,layout)
	var enemies: Array[Vector2] = []
	for point: Vector2 in layout.enemy_spawns:
		if point.distance_to(spawn) < player_radius*4 or Dungeon.segment_blocked(point,point,enemy_radius,layout): continue
		if Dungeon.find_path(spawn,point,enemy_radius,layout).is_empty(): continue
		enemies.append(point)
	if enemies.is_empty():
		reachable.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(spawn) > b.distance_squared_to(spawn))
		for point: Vector2 in reachable:
			if point.distance_to(spawn) < float(config.tile_size)*4 or Dungeon.segment_blocked(point,point,enemy_radius,layout): continue
			var separated := true
			for other: Vector2 in enemies:
				if point.distance_to(other) < float(config.tile_size)*2: separated = false
			if not separated or Dungeon.find_path(spawn,point,enemy_radius,layout).is_empty(): continue
			enemies.append(point)
			if enemies.size() >= int(balance.rooms.enemy_counts[0]): break
		if not enemies.is_empty(): notices.append("Gegnerstarts ergänzt (nur Vorschau)")
	if enemies.is_empty(): notices.append("Ohne Gegner: kein sicherer Start erreichbar")
	layout.player_spawns = [spawn]
	layout.enemy_spawns = enemies
	layout.editor_preview = true
	layout.id = "editor-play-"+str(room.id)
	layout.prev_id = ""
	layout.next_id = ""
	layout.grid_x = 0
	layout.grid_y = 0
	return {"error":"","layout":layout,"notice":" · ".join(notices)}

static func _clear_cells(layout: Dictionary, radius: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var dimensions: Array = layout.world_size
	for y in range(int(dimensions[1]/32)):
		for x in range(int(dimensions[0]/32)):
			var point := Vector2(x*32+16,y*32+16)
			if not Dungeon.segment_blocked(point,point,radius,layout): points.append(point)
	return points

static func _reachable_candidates(start: Vector2, candidates: Array[Vector2], radius: float, layout: Dictionary) -> Array[Vector2]:
	var cells := {}
	for point: Vector2 in candidates: cells[Vector2i((point/32).floor())] = point
	var first := Vector2i.ZERO
	var distance := INF
	var found := false
	for key: Vector2i in cells:
		var point: Vector2 = cells[key]
		if point.distance_squared_to(start) >= distance or Dungeon.segment_blocked(start,point,radius,layout): continue
		first = key
		distance = point.distance_squared_to(start)
		found = true
	if not found: return []
	var visited := {first:true}
	var queue: Array[Vector2i] = [first]
	var result: Array[Vector2] = []
	var cursor := 0
	while cursor < queue.size():
		var key: Vector2i = queue[cursor]
		cursor += 1
		result.append(cells[key])
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := key+direction
			if not cells.has(next) or visited.has(next) or Dungeon.segment_blocked(cells[key],cells[next],radius,layout): continue
			visited[next] = true
			queue.append(next)
	return result

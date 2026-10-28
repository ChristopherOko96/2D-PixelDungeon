extends RefCounted
## Seeded floor assembly and host-side geometry, independent of scenes or peers.
## Configuration schema 1 uses pixel world_size/play_bounds/spawns, tile-unit
## obstacles_tiles, and max_actor_radius for clearance. Every layout contains
## plain pixel rectangle arrays and Vector2 spawns, safe for Godot Variant RPCs.
## Geometry is conservative circle-vs-grown-AABB, not Godot physics determinism.

const SCHEMA_VERSION: int = 1
const GENERATOR_VERSION: int = 4
const MIN_ROOMS: int = 3
const MAX_ROOMS: int = 10
const EPSILON: float = 0.00001
# Subpixel separation keeps swept wall contact outside the closed navigation
# obstruction, including after Vector2's single-precision coordinate rounding.
const CONTACT_MARGIN: float = 0.001
const THEMES: Array[String] = ["rose", "moss", "amber", "violet"]
const Palette = preload("res://src/tile_palette.gd")
const CryptGenerator = preload("res://src/dungeon/crypt_generator.gd")
const Decor = preload("res://src/dungeon/decor_catalog.gd")
# Private, bounded runtime caches. Only collision arrays participate: artwork,
# room IDs and mutable editor presentation never determine reachability.
const NAVIGATION_CACHE_LIMIT: int = 32
static var _geometry_cache: Array[Dictionary] = []
static var _navigation_cache: Array[Dictionary] = []
static var _geometry_serial: int = 0

## Copies a validated native16 v2/v3 room library into native32 v4 coordinates.
## Tile rectangles and IDs are preserved; no input dictionary or file is changed.
static func upgrade_config(config: Dictionary) -> Dictionary:
	var upgraded := config.duplicate(true)
	if int(upgraded.get("tile_size",0)) != 16 or int(upgraded.get("generator_version",0)) not in [2,3]: return upgraded
	upgraded.tile_size = 32
	upgraded.generator_version = GENERATOR_VERSION
	for field: String in ["world_size","play_bounds"]:
		for index in range(upgraded[field].size()): upgraded[field][index] *= 2
	upgraded.max_actor_radius *= 2
	for room: Dictionary in upgraded.templates:
		for field: String in ["player_spawns","enemy_spawns","brazier_spawns"]:
			for point: Array in room.get(field,[]):
				point[0] *= 2
				point[1] *= 2
		for field: String in ["reward_spawn","stairs_spawn"]:
			if room.has(field):
				room[field][0] *= 2
				room[field][1] *= 2
	if upgraded.has("door_lanes"):
		for axis: String in upgraded.door_lanes: upgraded.door_lanes[axis] *= 2
	return upgraded

## Builds a repeatable connected floor; invalid data or counts return no rooms.
## First rooms rotate through seeded normal templates; only the final is a boss.
## `selected_id` forces one room into the floor (first, or last for a boss
## room): the editor's test play.
static func generate(seed: int, room_count: int, config: Dictionary, selected_id: String = "") -> Array[Dictionary]:
	config = CryptGenerator.realize(config,seed)
	var rooms: Array[Dictionary] = []
	if room_count < MIN_ROOMS or room_count > MAX_ROOMS or not validate_config(config).is_empty():
		return rooms
	if _has_freeform(config): return _generate_freeform(seed,room_count,config,selected_id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var normals: Array[Dictionary] = []
	var bosses: Array[Dictionary] = []
	for template: Dictionary in config.templates:
		if template.boss:
			bosses.append(template)
		else:
			normals.append(template)
	_shuffle(normals, rng)
	var theme_offset: int = rng.randi_range(0, THEMES.size() - 1)
	var coordinate: Vector2i = Vector2i.ZERO
	var occupied: Dictionary = {}
	var last_template: String = ""
	var authored: Array = config.get("room_order", [])
	if not authored.is_empty() and authored.size() != room_count: return []
	for index: int in range(room_count):
		if index > 0:
			# Monotonic X guarantees an available next cell. Vertical steps retain
			# the compact three-row map used by the floor HUD.
			var choices: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.RIGHT]
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
				var candidate: Vector2i = coordinate + direction
				if absi(candidate.y) <= 1 and not occupied.has(candidate):
					choices.append(direction)
			coordinate += choices[rng.randi_range(0, choices.size() - 1)]
		occupied[coordinate] = true
		var template: Dictionary
		if not authored.is_empty():
			for candidate: Dictionary in config.templates:
				if candidate.id == authored[index]: template = candidate
		elif index == room_count - 1:
			template = bosses[rng.randi_range(0, bosses.size() - 1)]
		else:
			if index > 0 and index % normals.size() == 0:
				_shuffle(normals, rng)
				if normals[0].id == last_template:
					var swap: Dictionary = normals[0]
					normals[0] = normals[1]
					normals[1] = swap
			template = normals[index % normals.size()]
		last_template = template.id
		var layout: Dictionary = _make_layout(template, config)
		layout.id = _room_id(seed, index)
		layout.grid_x = coordinate.x
		layout.grid_y = coordinate.y
		layout.prev_id = "" if index == 0 else _room_id(seed, index - 1)
		layout.next_id = "" if index == room_count - 1 else _room_id(seed, index + 1)
		layout.theme = template.get("theme", THEMES[posmod(theme_offset + index, THEMES.size())])
		layout.exits = []
		rooms.append(layout)
	for index: int in range(rooms.size()):
		var layout: Dictionary = rooms[index]
		for neighbor: int in [index - 1, index + 1]:
			if neighbor < 0 or neighbor >= rooms.size():
				continue
			var other: Dictionary = rooms[neighbor]
			var direction: Vector2i = Vector2i(other.grid_x - layout.grid_x, other.grid_y - layout.grid_y)
			var side: String = "east" if direction.x > 0 else "west" if direction.x < 0 else "south" if direction.y > 0 else "north"
			var exit: Dictionary = _make_door(side, neighbor + 1, layout)
			# Crypt rooms: the door moves into a wall (an arched gate in a north
			# wall face), never standing on the open floor.
			if layout.get("crypt_profile", false):
				var walled: Dictionary = _crypt_wall_door(side, neighbor + 1, layout)
				if not walled.is_empty(): exit = walled
			if exit.is_empty():
				return []
			exit.forward = neighbor > index
			layout.exits.append(exit)
		if index == rooms.size() - 1:
			# The boss arena has a dedicated down stair; it never doubles as a
			# return doorway and only the host decides when it becomes usable.
			var stairs: Dictionary = _make_stairs(layout)
			if stairs.is_empty():
				return []
			layout.exits.append(stairs)
	return rooms

## Presentation draft for the room editor. Blocked gateways remain visible.
## This does not approve the room for gameplay; validate_config still governs it.
static func preview_template(template: Dictionary, config: Dictionary) -> Dictionary:
	var layout := _make_layout(template,config)
	layout.id = "editor-" + str(template.id)
	layout.theme = template.get("theme","violet")
	layout.exits = []
	if is_freeform(template):
		for door: Dictionary in layout.get("authored_doors",[]):
			var exit := _make_authored_door(door,1,layout)
			if exit.is_empty():
				exit = {"id":"editor-door-%d-%d" % [door.x,door.y],"kind":"door","side":door.side,"rect":[float(door.x)*32,float(door.y)*32,32.0,32.0],"target_room":1,"blocked":true,"tile":door.tile,"rotation":door.rotation}
			layout.exits.append(exit)
		if template.boss and template.has("stairs_spawn"):
			var stairs := _make_stairs(layout)
			if not stairs.is_empty(): layout.exits.append(stairs)
		return layout
	for side: String in ["north","east","south","west"]:
		var exit := _make_door(side,1,layout)
		if exit.is_empty():
			var region := _door_region(side,layout)
			exit = {"id":side,"kind":"door","side":side,"rect":[region.position.x,region.position.y,region.size.x,region.size.y],"target_room":1,"blocked":true}
		layout.exits.append(exit)
	if template.boss:
		var stairs := _make_stairs(layout)
		if not stairs.is_empty(): layout.exits.append(stairs)
	return layout

## Returns actionable validation errors; never repairs malformed configuration.
## All spawn positions and all navigation lattice cells must remain connected at
## max_actor_radius, so the configured largest actor cannot be stranded.
static func validate_config(config: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for key: String in ["schema_version", "generator_version", "tile_size", "world_size", "play_bounds", "max_actor_radius", "templates"]:
		if not config.has(key):
			errors.append("Missing required dungeon field: %s" % key)
	if not errors.is_empty():
		return errors
	if not _integer(config.schema_version) or int(config.schema_version) != SCHEMA_VERSION:
		errors.append("Unsupported dungeon schema_version")
	if not _integer(config.generator_version) or int(config.generator_version) != GENERATOR_VERSION:
		errors.append("Unsupported dungeon generator_version")
	if not _integer(config.tile_size) or int(config.tile_size) != 32:
		errors.append("tile_size must use the native 32-pixel grid")
	if not _numbers(config.world_size, 2) or not _numbers(config.play_bounds, 4):
		errors.append("world_size/play_bounds must be finite pixel arrays")
	if not _number(config.max_actor_radius) or float(config.max_actor_radius) <= 0.0:
		errors.append("max_actor_radius must be finite and positive")
	if not config.templates is Array or config.templates.is_empty():
		errors.append("templates must be a nonempty array")
	if not errors.is_empty():
		return errors
	var bounds: Rect2 = _rect(config.play_bounds)
	var world: Vector2 = Vector2(float(config.world_size[0]), float(config.world_size[1]))
	var radius: float = float(config.max_actor_radius)
	if world.x <= 0.0 or world.y <= 0.0 or bounds.position.x < 0.0 or bounds.position.y < 0.0 or bounds.end.x > world.x or bounds.end.y > world.y or bounds.size.x <= radius * 2.0 or bounds.size.y <= radius * 2.0:
		errors.append("play_bounds must contain actor clearance and fit within world_size")
		return errors
	if config.has("door_lanes"):
		if not config.door_lanes is Dictionary:
			errors.append("door_lanes must be an object")
			return errors
		for axis: String in ["vertical","horizontal"]:
			if config.door_lanes.has(axis) and not _number(config.door_lanes[axis]): errors.append("Door lane must be finite: " + axis)
		if not errors.is_empty(): return errors
	var ids: Dictionary = {}
	var normals: int = 0
	var bosses: int = 0
	for entry: Variant in config.templates:
		if not entry is Dictionary:
			errors.append("Each template must be an object")
			continue
		var template: Dictionary = entry
		var label: String = str(template.get("id", "<unnamed>"))
		if not template.get("id") is String or label.is_empty() or ids.has(label):
			errors.append("Template IDs must be nonempty and unique: %s" % label)
		ids[label] = true
		if not template.get("title") is String or str(template.title).is_empty() or not template.get("boss") is bool:
			errors.append("Template %s needs a title and boolean boss flag" % label)
			continue
		if template.boss:
			bosses += 1
		else:
			normals += 1
		if not template.get("obstacles_tiles") is Array:
			errors.append("Template %s needs obstacles_tiles" % label)
			continue
		var geometry_valid: bool = true
		if not valid_room_dimensions(template,config):
			errors.append("Template %s has invalid room dimensions" % label)
			continue
		var room_bounds := _rect(template.get("play_bounds",config.play_bounds))
		if template.has("collision_overrides") and not valid_collision_overrides(template.collision_overrides,room_bounds):
			errors.append("Template %s has invalid collision overrides" % label)
			continue
		if template.has("layout_mode") and template.layout_mode not in ["legacy","freeform"]:
			errors.append("Template %s has invalid layout_mode" % label)
			continue
		if template.has("authored_doors") and not valid_authored_doors(template.authored_doors,room_bounds):
			errors.append("Template %s has invalid authored doors" % label)
			continue
		if template.has("door_lanes"):
			if not template.door_lanes is Dictionary:
				errors.append("Template %s has invalid door lanes" % label)
				continue
			var valid_lanes := true
			for value: Variant in template.door_lanes.values():
				if not _number(value): valid_lanes = false
			if not valid_lanes:
				errors.append("Template %s has invalid door lane values" % label)
				continue
		if not valid_painted_tiles(template.get("painted_tiles",[]),room_bounds):
			errors.append("Template %s has invalid painted tiles" % label)
			continue
		var room_cells := Vector2i(int(room_bounds.end.x / 32.0), int(room_bounds.end.y / 32.0))
		if (template.has("decor") and not Decor.valid_list(template.decor, room_cells, 2048)) or (template.has("decor_areas") and not Decor.valid_list(template.decor_areas, room_cells, 6144)) or (template.has("auto_decor") and not template.auto_decor is bool):
			errors.append("Template %s has invalid decor" % label)
			continue
		for obstacle: Variant in template.obstacles_tiles:
			if not _numbers(obstacle, 4):
				geometry_valid = false
				break
			for component: Variant in obstacle:
				if not _integer(component):
					geometry_valid = false
			var rect: Rect2 = _rect(obstacle)
			rect.position *= float(config.tile_size)
			rect.size *= float(config.tile_size)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not room_bounds.encloses(rect):
				geometry_valid = false
		if not geometry_valid:
			errors.append("Template %s obstacles must be positive tile rectangles within play_bounds" % label)
			continue
		var points_valid: bool = true
		for key: String in ["player_spawns", "enemy_spawns"]:
			var minimum: int = 4 if key == "player_spawns" else 5
			if not template.get(key) is Array or template.get(key, []).size() < minimum:
				points_valid = false
				continue
			for point: Variant in template[key]:
				if not _numbers(point, 2):
					points_valid = false
		if not points_valid:
			errors.append("Template %s needs four player and five enemy finite pixel spawn pairs" % label)
			continue
		if template.has("theme") and template.theme not in THEMES:
			errors.append("Template %s has an unknown palette" % label)
			continue
		var authored_valid := true
		if template.has("stairs_art") and not valid_stairs_art(template.stairs_art): authored_valid = false
		for key: String in ["reward_spawn","stairs_spawn"]:
			if template.has(key) and not _numbers(template[key],2): authored_valid = false
		if template.has("brazier_spawns"):
			if not template.brazier_spawns is Array or template.brazier_spawns.size() > 16: authored_valid = false
			else:
				for point: Variant in template.brazier_spawns:
					if not _numbers(point,2): authored_valid = false
		if not authored_valid:
			errors.append("Template %s has invalid authored prop coordinates" % label)
			continue
		var layout: Dictionary = _make_layout(template, config)
		var points: Array = layout.player_spawns + layout.enemy_spawns
		for point: Vector2 in points:
			if segment_blocked(point, point, radius, layout):
				points_valid = false
		if not points_valid:
			errors.append("Template %s has a spawn without actor clearance" % label)
			continue
		if not _floor_connected(layout, radius):
			errors.append("Template %s has disconnected floor or unreachable spawns" % label)
		for key: String in ["reward_spawn","stairs_spawn"]:
			if layout.has(key) and segment_blocked(layout[key],layout[key],float(config.tile_size)*0.5,layout): errors.append("%s: %s is blocked" % [label,key])
		for point: Vector2 in layout.get("brazier_spawns",[]):
			if segment_blocked(point,point,float(config.tile_size)*0.5,layout): errors.append("%s: fire is inside a wall" % label)
		if is_freeform(template):
			if not _painted_floor_connected(layout): errors.append("%s: gemalte Bodenflächen sind voneinander getrennt" % label)
			if layout.authored_doors.is_empty(): errors.append("%s: mindestens eine selbst gesetzte Tür fehlt" % label)
			for door: Dictionary in layout.authored_doors:
				if _make_authored_door(door,1,layout).is_empty(): errors.append("%s: gesetzte Tür hat keinen freien Zugang oder vier Ankunftsplätze" % label)
			if template.boss and (not template.has("stairs_spawn") or _make_stairs(layout).is_empty()): errors.append("%s: selbst gesetzte, erreichbare Boss-Treppe fehlt" % label)
	if normals < 3 or bosses < 1:
		errors.append("Dungeon requires at least three normal templates and one boss template")
	if config.has("room_order"):
		if not config.room_order is Array or config.room_order.size() < 3 or config.room_order.size() > 10:
			errors.append("room_order must name 3 to 10 rooms")
		else:
			for index in range(config.room_order.size()):
				var found := false
				for template: Variant in config.templates:
					if template is Dictionary and template.get("id","") == config.room_order[index]:
						found = true
						if template.get("boss",false) != (index == config.room_order.size()-1): errors.append("room_order must end with exactly one boss room")
				if not found: errors.append("room_order references a missing room")
	if errors.is_empty() and _has_freeform(config):
		var count: int = config.get("room_order",[]).size() if config.has("room_order") else MIN_ROOMS
		if _plan_freeform(0,count,config).is_empty(): errors.append("Raumvorlagen besitzen keine passende Folge gegenüberliegender Türseiten; Türen oder Raumfolge anpassen.")
	return errors

## Moves an actor using swept X then Y clipping against radius-grown rectangles.
## The fixed axis order permits wall sliding and prevents large-step tunneling.
## Starting positions must be valid; malformed movement leaves position unchanged.
static func move_actor(pos: Vector2, delta: Vector2, radius: float, layout: Dictionary) -> Vector2:
	if not pos.is_finite() or not delta.is_finite() or not is_finite(radius) or radius < 0.0 or not _geometry_valid(layout):
		return pos
	var bounds: Rect2 = _rect(layout.play_bounds).grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return pos
	var result: Vector2 = pos.clamp(bounds.position, bounds.end)
	if delta == Vector2.ZERO:
		return result
	var target: float = clampf(result.x + delta.x, bounds.position.x, bounds.end.x)
	for entry: Array in layout.obstacles:
		var wall: Rect2 = _rect(entry).grow(radius)
		if result.y > wall.position.y + EPSILON and result.y < wall.end.y - EPSILON:
			if delta.x > 0.0 and result.x <= wall.position.x + EPSILON:
				target = minf(target, wall.position.x - CONTACT_MARGIN)
			elif delta.x < 0.0 and result.x >= wall.end.x - EPSILON:
				target = maxf(target, wall.end.x + CONTACT_MARGIN)
	result.x = target
	target = clampf(result.y + delta.y, bounds.position.y, bounds.end.y)
	for entry: Array in layout.obstacles:
		var wall: Rect2 = _rect(entry).grow(radius)
		if result.x > wall.position.x + EPSILON and result.x < wall.end.x - EPSILON:
			if delta.y > 0.0 and result.y <= wall.position.y + EPSILON:
				target = minf(target, wall.position.y - CONTACT_MARGIN)
			elif delta.y < 0.0 and result.y >= wall.end.y - EPSILON:
				target = maxf(target, wall.end.y + CONTACT_MARGIN)
	result.y = target
	return result

## Sweeps a segment against radius-grown walls and physical room boundaries.
## Includes the full segment, so high-speed projectiles cannot cross thin pillars.
## Invalid geometry or non-finite input is treated as blocked.
static func segment_blocked(from: Vector2, to: Vector2, radius: float, layout: Dictionary) -> bool:
	if not from.is_finite() or not to.is_finite() or not is_finite(radius) or radius < 0.0:
		return true
	var geometry := _collision_geometry(layout)
	if geometry.is_empty(): return true
	var bounds: Rect2 = geometry.bounds.grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or not _inside(from, bounds) or not _inside(to, bounds):
		return true
	for wall: Rect2 in geometry.walls:
		if _segment_intersects_rect(from, to, wall.grow(radius)):
			return true
	return false

## Returns authored player spawn positions, wrapping nonnegative slot indices.
## Empty or invalid layout spawn data returns Vector2.ZERO.
static func spawn_for_player(index: int, layout: Dictionary) -> Vector2:
	return _spawn(index, layout.get("player_spawns", []))

## Returns authored enemy spawn positions, wrapping nonnegative slot indices.
## Empty or invalid layout spawn data returns Vector2.ZERO.
static func spawn_for_enemy(index: int, layout: Dictionary) -> Vector2:
	return _spawn(index, layout.get("enemy_spawns", []))

## Returns a clear party arrival slot inside the door leading back to from_room.
## Slots are separated by a tile and stay outside the doorway trigger. An unknown
## origin falls back to the authored initial spawn; no geometry is mutated.
static func entry_for_player(from_room: int, index: int, layout: Dictionary) -> Vector2:
	for exit: Dictionary in layout.get("exits", []):
		if str(exit.get("kind", "")) == "door" and int(exit.get("target_room", 0)) == from_room:
			return _spawn(index, exit.get("entry_spawns", []))
	return spawn_for_player(index, layout)

## Finds collision-free waypoints on a cardinal tile lattice, including `to`.
## Endpoints clamp to this actor's floor clearance so larger enemies can chase a
## smaller player near the floor edge. Clear direct paths return [clamped_to];
## non-finite/inside-wall endpoints and unreachable goals return [].
## Callers may cache routes and consume waypoints; no scene/physics state is used.
static func find_path(from: Vector2, to: Vector2, radius: float, layout: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = []
	if not from.is_finite() or not to.is_finite() or not is_finite(radius) or radius < 0.0:
		return result
	var geometry := _collision_geometry(layout)
	if geometry.is_empty(): return result
	var bounds: Rect2 = geometry.bounds.grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	from = from.clamp(bounds.position, bounds.end)
	to = to.clamp(bounds.position, bounds.end)
	if not segment_blocked(from, to, radius, layout):
		result.append(to)
		return result
	if segment_blocked(from, from, radius, layout) or segment_blocked(to, to, radius, layout):
		return result
	var navigation := _navigation_for(layout, radius, geometry)
	if navigation.is_empty(): return result
	var starts := _visible_navigation_cells(from, navigation)
	var goals := _visible_navigation_cells(to, navigation)
	if starts.is_empty() or goals.is_empty(): return result
	var graph: AStar2D = navigation.graph
	# Temporary endpoint nodes retain every visible candidate, including when
	# nearby lattice cells lie in different components. They never enter layout.
	var start_id: int = navigation.cells.size()
	var goal_id: int = start_id + 1
	graph.add_point(start_id, from)
	graph.add_point(goal_id, to)
	for cell: Vector2i in starts: graph.connect_points(start_id, navigation.cells[cell])
	for cell: Vector2i in goals: graph.connect_points(goal_id, navigation.cells[cell])
	var path: PackedVector2Array = graph.get_point_path(start_id, goal_id)
	graph.remove_point(start_id)
	graph.remove_point(goal_id)
	# Every graph edge and endpoint link is clearance checked. Retain the same
	# swept collision check while collapsing visible stretches of the result.
	var anchor: Vector2 = from
	var next_index: int = 1
	while next_index < path.size():
		var furthest: int = next_index
		while furthest + 1 < path.size() and not _navigation_segment_blocked(anchor, path[furthest + 1], navigation):
			furthest += 1
		anchor = path[furthest]
		result.append(anchor)
		next_index = furthest + 1
	return result

## Prepares actor-clearance graphs once before room combat. Invalid radii and
## malformed geometry are ignored; this never changes or serializes the layout.
static func prepare_navigation(layout: Dictionary, radii: Array) -> void:
	var geometry := _collision_geometry(layout)
	if geometry.is_empty(): return
	for radius: Variant in radii:
		if (radius is int or radius is float) and is_finite(float(radius)) and float(radius) >= 0.0:
			_navigation_for(layout, float(radius), geometry)

static func _room_id(seed: int, index: int) -> String:
	return "v%d-s%d-r%02d" % [GENERATOR_VERSION, seed, index + 1]

static func _make_door(side: String, target_room: int, layout: Dictionary) -> Dictionary:
	if is_freeform(layout):
		for door: Dictionary in layout.get("authored_doors",[]):
			if door.side == side:
				var authored := _make_authored_door(door,target_room,layout)
				if not authored.is_empty(): return authored
		return {}
	var region := _door_region(side,layout)
	var center := region.get_center()
	if not _rect(layout.play_bounds).encloses(region): return {}
	var player_radius := float(layout.tile_size)*0.375
	if segment_blocked(center, center, player_radius, layout) or find_path(layout.player_spawns[0], center, player_radius, layout).is_empty():
		return {}
	var exit: Dictionary = {"id": "%s-to-r%02d" % [layout.id, target_room], "kind": "door", "side": side,
		"rect": [region.position.x, region.position.y, region.size.x, region.size.y], "target_room": target_room}
	var entry_spawns: Array[Vector2] = _entry_slots(exit, layout)
	if entry_spawns.size() < 4: return {}
	exit.entry_spawns = entry_spawns
	return exit

## A door towards `side`: crypt rooms get a gate in a wall (_crypt_wall_door),
## other rooms keep their authored or lane door. `forward` marks the way on.
static func _walled_door(side: String, target_room: int, layout: Dictionary, forward: bool) -> Dictionary:
	var exit: Dictionary = _make_door(side, target_room, layout)
	if layout.get("crypt_profile", false):
		var walled := _crypt_wall_door(side, target_room, layout)
		if not walled.is_empty(): exit = walled
	if not exit.is_empty(): exit.forward = forward
	return exit

## A crypt door set into a wall: two wall cells of a north-facing wall (floor
## directly below, no floor above, wall cells on both sides for the frame). The
## face nearest the neighbour's side wins (west: leftmost, east: rightmost,
## north: topmost, south: lowest), keeping 5 cells from other exits. The exit
## trigger is the floor in front of the gate; `door_cell` is the gate's left
## wall cell, which the 0x72 renderer draws the arch over. {} when no face fits.
static func _crypt_wall_door(side: String, target_room: int, layout: Dictionary) -> Dictionary:
	if layout.get("player_spawns", []).is_empty(): return {}
	var floor_cells := {}
	var wall_cells := {}
	for entry: Dictionary in layout.get("painted_tiles", []):
		var cell := Vector2i(int(entry.x), int(entry.y))
		if str(entry.get("layer", "")) == "floor" and not bool(entry.get("solid", false)): floor_cells[cell] = true
	for entry: Dictionary in layout.get("painted_tiles", []):
		var cell := Vector2i(int(entry.x), int(entry.y))
		if bool(entry.get("solid", false)) and not floor_cells.has(cell): wall_cells[cell] = true
	var taken: Array[Vector2] = []
	for exit: Dictionary in layout.get("exits", []): taken.append(_rect(exit.rect).get_center())
	var radius := float(layout.tile_size) * 0.375
	var best: Dictionary = {}
	var best_score := INF
	for cell: Vector2i in wall_cells:
		var right := cell + Vector2i.RIGHT
		if not wall_cells.has(right) or not wall_cells.has(cell + Vector2i.LEFT) or not wall_cells.has(right + Vector2i.RIGHT): continue
		if not floor_cells.has(cell + Vector2i.DOWN) or not floor_cells.has(right + Vector2i.DOWN): continue
		if floor_cells.has(cell + Vector2i.UP) or floor_cells.has(right + Vector2i.UP): continue
		var center := Vector2((cell.x + 1) * 32.0, (cell.y + 1) * 32.0 + 16.0)
		var crowded := false
		for other: Vector2 in taken:
			if other.distance_to(center) < 160.0: crowded = true
		if crowded: continue
		var score: float = {"west": cell.x * 100.0 - cell.y, "east": -cell.x * 100.0 - cell.y, "north": cell.y * 100.0 + absf(cell.x - 32.0), "south": -cell.y * 100.0 + absf(cell.x - 32.0)}.get(side, 0.0)
		if score >= best_score: continue
		if segment_blocked(center, center, radius, layout) or find_path(layout.player_spawns[0], center, radius, layout).is_empty(): continue
		best_score = score
		best = {"cell": cell, "center": center}
	if best.is_empty(): return {}
	var gate: Vector2i = best.cell
	var region := Rect2(Vector2(best.center) - Vector2(16, 16), Vector2(32, 32))
	var result := {"id": "%s-gate-%d-%d-to-r%02d" % [layout.get("id", "authored"), gate.x, gate.y, target_room], "kind": "door", "side": "north",
		"rect": [region.position.x, region.position.y, 32.0, 32.0], "target_room": target_room, "door_cell": [gate.x, gate.y], "toward": side,
		"tile": "items_002", "rotation": 0}
	var slots := _entry_slots(result, layout)
	if slots.size() != 4: return {}
	result.entry_spawns = slots
	return result

static func _door_region(side: String, layout: Dictionary) -> Rect2:
	var bounds: Rect2 = _rect(layout.play_bounds)
	var tile: float = float(layout.tile_size)
	var center: Vector2 = bounds.get_center()
	var lanes: Dictionary = layout.get("door_lanes",{})
	if side in ["north","south"]: center.x = float(lanes.get("vertical",center.x))
	else: center.y = float(lanes.get("horizontal",center.y))
	match side:
		"north": center.y = bounds.position.y + tile * 0.5
		"south": center.y = bounds.end.y - tile * 0.5
		"west": center.x = bounds.position.x + tile * 0.5
		"east": center.x = bounds.end.x - tile * 0.5
	return Rect2(center - Vector2.ONE * tile * 0.5, Vector2.ONE * tile)

static func _entry_slots(exit: Dictionary, layout: Dictionary) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var region: Rect2 = _rect(exit.rect)
	var inward: Vector2 = {"north": Vector2.DOWN, "south": Vector2.UP, "west": Vector2.RIGHT, "east": Vector2.LEFT}[exit.side]
	var tangent: Vector2 = Vector2.RIGHT if exit.side in ["north", "south"] else Vector2.DOWN
	var tile: float = float(layout.tile_size)
	# Search in deterministic rows near the entrance. A door-adjacent pillar may
	# reject some candidates; every chosen slot still has a clear approach.
	for depth: int in range(2, 7):
		for offset: float in [-1.5, -0.5, 0.5, 1.5, -2.5, 2.5, -3.5, 3.5]:
			var point: Vector2 = region.get_center() + inward * tile * depth + tangent * tile * offset
			if segment_blocked(point, point, tile*0.375, layout) or region.grow(tile*0.375).has_point(point):
				continue
			var overlaps: bool = false
			for other: Vector2 in slots:
				if point.distance_to(other) < tile - EPSILON:
					overlaps = true
			if overlaps or segment_blocked(region.get_center(), point, tile*0.375, layout):
				continue
			slots.append(point)
			if slots.size() == 4:
				return slots
	return slots

static func _make_stairs(layout: Dictionary) -> Dictionary:
	if is_freeform(layout) and not layout.has("stairs_spawn"): return {}
	if layout.get("player_spawns",[]).is_empty(): return {}
	var bounds: Rect2 = _rect(layout.play_bounds)
	var tile: float = float(layout.tile_size)
	# Center-right keeps the boss clear of the original party spawn. A future
	# authored boss obstacle may reject it, so search nearby complete tile cells.
	var preferred: Vector2 = Vector2(bounds.position.x + bounds.size.x * 0.75, bounds.get_center().y)
	if layout.has("stairs_spawn"):
		preferred = layout.stairs_spawn
		var authored_region := Rect2(preferred-Vector2.ONE*tile*0.5,Vector2.ONE*tile)
		if bounds.encloses(authored_region) and not segment_blocked(preferred,preferred,tile*0.375,layout) and not find_path(layout.player_spawns[0],preferred,tile*0.375,layout).is_empty():
			return _with_stair_art(layout,{"id":"%s-down" % layout.get("id",layout.get("template_id","authored")),"kind":"stairs","side":"south","rect":[authored_region.position.x,authored_region.position.y,tile,tile],"target_room":0})
		return {}
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, 2), Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0)]:
		var center: Vector2 = (preferred / tile).floor() * tile + Vector2.ONE * tile * 0.5 + offset * tile
		var region: Rect2 = Rect2(center - Vector2.ONE * tile * 0.5, Vector2.ONE * tile)
		if bounds.encloses(region) and not segment_blocked(center, center, tile*0.375, layout) and not find_path(layout.player_spawns[0], center, tile*0.375, layout).is_empty():
			return _with_stair_art(layout,{"id": "%s-down" % layout.get("id",layout.get("template_id","authored")), "kind": "stairs", "side": "south", "rect": [region.position.x, region.position.y, region.size.x, region.size.y], "target_room": 0})
	return {}

static func _with_stair_art(layout: Dictionary, exit: Dictionary) -> Dictionary:
	if is_freeform(layout):
		var art: Dictionary = layout.get("stairs_art",{"tile":"violet_000","rotation":0})
		exit.tile = art.tile
		exit.rotation = art.rotation
	return exit

static func _shuffle(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Dictionary = values[index]
		values[index] = values[other]
		values[other] = swap

static func _make_layout(template: Dictionary, config: Dictionary) -> Dictionary:
	var obstacles: Array = []
	for obstacle: Array in template.obstacles_tiles:
		obstacles.append([float(obstacle[0]) * float(config.tile_size), float(obstacle[1]) * float(config.tile_size), float(obstacle[2]) * float(config.tile_size), float(obstacle[3]) * float(config.tile_size)])
	var players: Array[Vector2] = []
	var enemies: Array[Vector2] = []
	for point: Array in template.player_spawns:
		players.append(Vector2(float(point[0]), float(point[1])))
	for point: Array in template.enemy_spawns:
		enemies.append(Vector2(float(point[0]), float(point[1])))
	var layout := {"template_id": template.id, "title": template.title, "boss": template.boss,
		"accent_color": template.get("accent_color", "536b72"),
		"generator_version": int(config.generator_version), "tile_size": int(config.tile_size),
		"world_size": template.get("world_size",config.world_size).duplicate(), "play_bounds": template.get("play_bounds",config.play_bounds).duplicate(),
		"obstacles": obstacles, "player_spawns": players, "enemy_spawns": enemies}
	layout.door_lanes = template.get("door_lanes",config.get("door_lanes",{})).duplicate()
	layout.painted_tiles = template.get("painted_tiles",[]).duplicate(true)
	if is_freeform(template): layout.layout_mode = "freeform"
	layout.authored_doors = template.get("authored_doors",[]).duplicate(true)
	for key: String in ["render_style", "decoration_enabled"]:
		if template.has(key) or config.has(key): layout[key] = template.get(key,config.get(key))
	for key: String in ["crypt_profile","crypt_entrance","crypt_ambience","entrance_marker","encounter","encounter_seed","room_theme","decoration_summary"]:
		if template.has(key): layout[key] = template[key]
	if template.has("stairs_art"): layout.stairs_art = template.stairs_art.duplicate(true)
	layout.tile_obstacles = []
	var floor_cells := {}
	if template.get("crypt_profile",false):
		for cell: Dictionary in layout.painted_tiles:
			if cell.get("layer","") == "floor": floor_cells[Vector2i(int(cell.x),int(cell.y))] = true
	for cell: Dictionary in layout.painted_tiles:
		if cell.solid:
			# Contour masonry is already blocked by the merged void mask. Avoid
			# hundreds of duplicate collision boxes while preserving every sprite.
			if cell.get("crypt_wall",false) and not floor_cells.has(Vector2i(int(cell.x),int(cell.y))): continue
			var rectangle := [float(cell.x)*32,float(cell.y)*32,32.0,32.0]
			layout.obstacles.append(rectangle)
			layout.tile_obstacles.append(rectangle)
	var overrides: Array = template.get("collision_overrides",[])
	if not overrides.is_empty():
		layout.collision_overrides = overrides.duplicate(true)
		# Physical changes never erase the artwork that generated the old cover.
		layout.visual_obstacles = layout.obstacles.duplicate(true)
	if is_freeform(template):
		layout.void_obstacles = _void_rectangles(layout)
		layout.obstacles.append_array(layout.void_obstacles)
	if not overrides.is_empty(): _apply_collision_overrides(layout)
	for key: String in ["reward_spawn","stairs_spawn"]:
		if template.has(key): layout[key] = Vector2(float(template[key][0]),float(template[key][1]))
	# Chest spots painted in the editor (cells); chests.gd prefers them.
	if template.has("chest_spawns"): layout.chest_spawns = template.chest_spawns.duplicate(true)
	if template.has("mimic_spawns"): layout.mimic_spawns = template.mimic_spawns.duplicate(true)
	# Decor from the editor (drawn by crypt_0x72_art.gd; solid pieces are
	# already in obstacles_tiles).
	for key: String in ["decor", "decor_areas"]:
		if template.get(key) is Array: layout[key] = template[key].duplicate(true)
	if template.has("auto_decor"): layout.auto_decor = bool(template.auto_decor)
	if template.has("brazier_spawns"):
		layout.brazier_spawns = []
		for point: Array in template.brazier_spawns: layout.brazier_spawns.append(Vector2(float(point[0]),float(point[1])))
	return layout

## Optional per-room dimensions are bounded to12..64 by10..48 whole tiles.
## Legacy templates keep the library's original dimensions without rewriting.
static func valid_room_dimensions(room: Dictionary, config: Dictionary) -> bool:
	if not room.has("world_size") and not room.has("play_bounds"): return not is_freeform(room)
	if not _numbers(room.get("world_size"),2) or not _numbers(room.get("play_bounds"),4): return false
	var world := Vector2(room.world_size[0],room.world_size[1])
	if world.x < 384 or world.x > 2048 or world.y < 320 or world.y > 1536: return false
	if fmod(world.x,32) != 0 or fmod(world.y,32) != 0: return false
	if is_freeform(room): return _rect(room.play_bounds) == Rect2(Vector2.ZERO,world)
	return _rect(room.play_bounds) == Rect2(32,64,world.x-64,world.y-96)

## Validates a bounded, unique cell list before loading art or creating collision.
static func valid_painted_tiles(value: Variant, bounds: Rect2) -> bool:
	if not value is Array or value.size() > 6144: return false
	var occupied := {}
	for cell: Variant in value:
		if not cell is Dictionary: return false
		for key: String in ["x","y","rotation"]:
			if not _integer(cell.get(key)): return false
		if not cell.get("tile") is String or not Palette.valid_id(cell.tile) or not cell.get("solid") is bool: return false
		if cell.rotation < 0 or cell.rotation > 3: return false
		if not _cell_inside_original(cell.x,cell.y,bounds): return false
		var point := Vector2i(int(cell.x),int(cell.y))
		var layer: String = str(cell.get("layer","structure" if cell.solid else "floor"))
		if layer not in ["floor","structure"] or (layer == "floor" and cell.solid): return false
		var key := "%d,%d:%s" % [point.x,point.y,layer]
		if occupied.has(key) or not bounds.encloses(Rect2(Vector2(point)*32,Vector2(32,32))): return false
		occupied[key] = true
	return true

## Explicit mode opt-in preserves old rectangular rooms and draft formats.
static func is_freeform(room: Dictionary) -> bool:
	return room.get("layout_mode","") == "freeform"

## Optional cell mask is independent from artwork and layer solidity.
## Bounds checks use original JSON numbers before any32-bit cell conversion.
static func valid_collision_overrides(value: Variant, bounds: Rect2) -> bool:
	if not value is Array or value.size() > 3072: return false
	var occupied := {}
	for entry: Variant in value:
		if not entry is Dictionary or not _integer(entry.get("x")) or not _integer(entry.get("y")) or not entry.get("blocked") is bool: return false
		if not _cell_inside_original(entry.x,entry.y,bounds): return false
		var cell := Vector2i(int(entry.x),int(entry.y))
		if occupied.has(cell): return false
		occupied[cell] = true
	return true

## Structural validation accepts unfinished drafts; reachability is runtime-only.
static func valid_authored_doors(value: Variant, bounds: Rect2) -> bool:
	if not value is Array or value.size() > 64: return false
	var positions := {}
	for door: Variant in value:
		if not door is Dictionary: return false
		for key: String in ["x","y","rotation"]:
			if not _integer(door.get(key)): return false
		if door.get("side","") not in ["north","east","south","west"] or door.rotation < 0 or door.rotation > 3: return false
		if not door.get("tile") is String or not Palette.valid_id(door.tile): return false
		if not _cell_inside_original(door.x,door.y,bounds): return false
		var point := Vector2i(int(door.x),int(door.y))
		if positions.has(point) or not bounds.encloses(Rect2(Vector2(point)*32,Vector2(32,32))): return false
		positions[point] = true
	return true

static func _cell_inside_original(x: Variant, y: Variant, bounds: Rect2) -> bool:
	# Bounds-check original 64-bit JSON numbers before Vector2i's32-bit cast.
	return float(x) >= bounds.position.x/32.0 and float(y) >= bounds.position.y/32.0 and float(x)+1.0 <= bounds.end.x/32.0 and float(y)+1.0 <= bounds.end.y/32.0

## Optional chosen stair cell is whitelisted exactly like a painted tile.
static func valid_stairs_art(value: Variant) -> bool:
	return value is Dictionary and value.get("tile") is String and Palette.valid_id(value.tile) and _integer(value.get("rotation")) and value.rotation >= 0 and value.rotation <= 3

static func _make_authored_door(door: Dictionary, target_room: int, layout: Dictionary) -> Dictionary:
	if layout.get("player_spawns",[]).is_empty(): return {}
	var region := Rect2(float(door.x)*32,float(door.y)*32,32,32)
	var center := region.get_center()
	var radius := float(layout.tile_size)*0.375
	if segment_blocked(center,center,radius,layout) or find_path(layout.player_spawns[0],center,radius,layout).is_empty(): return {}
	var result := {"id":"%s-%d-%d-to-r%02d" % [layout.get("id","authored"),door.x,door.y,target_room],"kind":"door","side":door.side,"rect":[region.position.x,region.position.y,32.0,32.0],"target_room":target_room,"tile":door.tile,"rotation":door.rotation}
	var slots := _entry_slots(result,layout)
	if slots.size() != 4: return {}
	result.entry_spawns = slots
	return result

static func _void_rectangles(layout: Dictionary) -> Array:
	return _mask_rectangles(_floor_footprint(layout),int(layout.world_size[0]/32),int(layout.world_size[1]/32),true)

static func _floor_footprint(layout: Dictionary) -> Dictionary:
	var cells := {}
	for entry: Dictionary in layout.get("painted_tiles",[]):
		if str(entry.get("layer","structure" if entry.solid else "floor")) == "floor": cells[Vector2i(int(entry.x),int(entry.y))] = true
	for entry: Dictionary in layout.get("collision_overrides",[]):
		var key := Vector2i(int(entry.x),int(entry.y))
		if entry.blocked: cells.erase(key)
		else: cells[key] = true
	return cells

static func _apply_collision_overrides(layout: Dictionary) -> void:
	var columns := int(layout.world_size[0]/32)
	var rows := int(layout.world_size[1]/32)
	var cells := {}
	for rect: Array in layout.obstacles:
		var left := clampi(int(floorf(float(rect[0])/32)),0,columns)
		var right := clampi(int(ceilf(float(rect[0]+rect[2])/32)),0,columns)
		var top := clampi(int(floorf(float(rect[1])/32)),0,rows)
		var bottom := clampi(int(ceilf(float(rect[1]+rect[3])/32)),0,rows)
		for y in range(top,bottom):
			for x in range(left,right): cells[Vector2i(x,y)] = true
	for entry: Dictionary in layout.collision_overrides:
		var cell := Vector2i(int(entry.x),int(entry.y))
		if entry.blocked: cells[cell] = true
		else: cells.erase(cell)
	layout.obstacles = _mask_rectangles(cells,columns,rows)

static func _mask_rectangles(cells: Dictionary, columns: int, rows: int, inverted: bool = false) -> Array:
	var result: Array = []
	var previous_runs := {}
	for y in range(rows):
		var x := 0
		while x < columns:
			if cells.has(Vector2i(x,y)) == inverted:
				x += 1
				continue
			var start := x
			while x < columns and cells.has(Vector2i(x,y)) != inverted: x += 1
			var run := Vector2i(start,x-start)
			var previous: int = previous_runs.get(run,-1)
			if previous >= 0 and result[previous][1]+result[previous][3] == y*32: result[previous][3] += 32
			else:
				previous_runs[run] = result.size()
				result.append([float(start*32),float(y*32),float((x-start)*32),32.0])
	return result

static func _painted_floor_connected(layout: Dictionary) -> bool:
	# The legacy navigation lattice lies on tile corners. A detached single tile
	# has no boss-clear corner and would otherwise disappear from connectivity.
	var cells := {}
	var tile := float(layout.tile_size)
	var radius := tile*0.375
	for key: Vector2i in _floor_footprint(layout):
		var center := Vector2(key)*tile+Vector2.ONE*tile*0.5
		if not segment_blocked(center,center,radius,layout): cells[key] = center
	if cells.is_empty(): return false
	var visited := {}
	var queue: Array[Vector2i] = [cells.keys()[0]]
	visited[queue[0]] = true
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := cell+direction
			if cells.has(next) and not visited.has(next) and not segment_blocked(cells[cell],cells[next],radius,layout):
				visited[next] = true
				queue.append(next)
	return cells.size() == visited.size()

static func _has_freeform(config: Dictionary) -> bool:
	for room: Dictionary in config.templates:
		if is_freeform(room): return true
	return false

static func _opposite(side: String) -> String:
	return {"north":"south","east":"west","south":"north","west":"east"}[side]

static func _direction(side: String) -> Vector2i:
	return {"north":Vector2i.UP,"east":Vector2i.RIGHT,"south":Vector2i.DOWN,"west":Vector2i.LEFT}[side]

## Chooses a compatible isolated test sequence containing the requested room.
## Normal selections start the test; boss selections finish it. No file changes.
static func selected_room_order(seed: int, count: int, config: Dictionary, selected_id: String) -> Array[String]:
	var order: Array[String] = []
	if count < MIN_ROOMS or count > MAX_ROOMS or not validate_config(config).is_empty(): return order
	var copy := config.duplicate(true)
	copy.erase("room_order")
	var plan := _plan_freeform(seed,count,copy,selected_id)
	for layout: Dictionary in plan: order.append(str(layout.template_id))
	return order

static func _plan_freeform(seed: int, count: int, config: Dictionary, selected_id: String = "") -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var choices: Array[Dictionary] = []
	for template: Dictionary in config.templates:
		var layout := _make_layout(template,config)
		layout.id = "port-check-"+str(template.id)
		layout.ports = []
		for side: String in ["north","east","south","west"]:
			if not _make_door(side,1,layout).is_empty(): layout.ports.append(side)
		if not layout.ports.is_empty() and (not layout.boss or not _make_stairs(layout).is_empty()): choices.append(layout)
	_shuffle(choices,rng)
	var sequence: Array[Dictionary] = []
	var occupied := {}
	var budget := [12000]
	var selected_boss := false
	if not selected_id.is_empty():
		var found := false
		for candidate: Dictionary in choices:
			if candidate.template_id == selected_id:
				selected_boss = bool(candidate.boss)
				found = true
		if not found: return []
	if _search_freeform(sequence,occupied,choices,config.get("room_order",[]),count,rng,budget,selected_id,selected_boss): return sequence
	return []

static func _search_freeform(sequence: Array[Dictionary], occupied: Dictionary, choices: Array[Dictionary], order: Array, count: int, rng: RandomNumberGenerator, budget: Array, selected_id: String = "", selected_boss: bool = false) -> bool:
	budget[0] -= 1
	if budget[0] < 0: return false
	var index := sequence.size()
	if index == count: return true
	var used_templates := {}
	for entry: Dictionary in sequence: used_templates[entry.template_id] = true
	var ordered: Array[Dictionary] = []
	for choice: Dictionary in choices:
		if not used_templates.has(choice.template_id): ordered.append(choice)
	for choice: Dictionary in choices:
		if used_templates.has(choice.template_id): ordered.append(choice)
	for candidate: Dictionary in ordered:
		# A crypt campaign contains each authored map at most once. Missing or
		# incompatible templates must fail generation rather than repeat a map.
		if candidate.get("crypt_profile",false) and used_templates.has(candidate.template_id): continue
		if bool(candidate.boss) != (index == count-1): continue
		# The collapsed entrance belongs only to the first crypt, not a random
		# mid-run chamber. Other libraries retain their existing selection rules.
		if selected_id.is_empty() and choices.any(func(value: Dictionary): return value.get("crypt_entrance",false)):
			if bool(candidate.get("crypt_entrance",false)) != (index == 0): continue
		if not selected_id.is_empty() and index == (count-1 if selected_boss else 0) and candidate.template_id != selected_id: continue
		if not order.is_empty() and (index >= order.size() or candidate.template_id != order[index]): continue
		if index == 0:
			var entry := candidate.duplicate(true)
			entry.coordinate = Vector2i.ZERO
			entry.incoming = ""
			entry.outgoing = ""
			sequence.append(entry)
			occupied[Vector2i.ZERO] = true
			if _search_freeform(sequence,occupied,choices,order,count,rng,budget,selected_id,selected_boss): return true
			sequence.pop_back()
			occupied.erase(Vector2i.ZERO)
			continue
		var previous: Dictionary = sequence[index-1]
		var sides: Array = previous.ports.duplicate()
		# Seeded cardinal ordering is stable without depending on Dictionary order.
		for side_index in range(sides.size()-1,0,-1):
			var other := rng.randi_range(0,side_index)
			var swap: Variant = sides[side_index]
			sides[side_index] = sides[other]
			sides[other] = swap
		for side_value: Variant in sides:
			var side := str(side_value)
			if _opposite(side) not in candidate.ports: continue
			var coordinate: Vector2i = previous.coordinate+_direction(side)
			if occupied.has(coordinate): continue
			var entry := candidate.duplicate(true)
			entry.coordinate = coordinate
			entry.incoming = _opposite(side)
			entry.outgoing = ""
			previous.outgoing = side
			sequence.append(entry)
			occupied[coordinate] = true
			if _search_freeform(sequence,occupied,choices,order,count,rng,budget,selected_id,selected_boss): return true
			sequence.pop_back()
			occupied.erase(coordinate)
			previous.outgoing = ""
	return false

static func _generate_freeform(seed: int, count: int, config: Dictionary, selected_id: String = "") -> Array[Dictionary]:
	var plan := _plan_freeform(seed,count,config,selected_id)
	var rooms: Array[Dictionary] = []
	if plan.size() != count: return rooms
	for index in range(count):
		var layout: Dictionary = plan[index].duplicate(true)
		layout.id = _room_id(seed,index)
		layout.grid_x = layout.coordinate.x
		layout.grid_y = layout.coordinate.y
		layout.prev_id = "" if index == 0 else _room_id(seed,index-1)
		layout.next_id = "" if index == count-1 else _room_id(seed,index+1)
		layout.theme = "violet"
		for template: Dictionary in config.templates:
			if template.id == layout.template_id: layout.theme = template.get("theme",THEMES[posmod(seed+index,THEMES.size())])
		layout.exits = []
		if index > 0: layout.exits.append(_walled_door(layout.incoming,index,layout,false))
		if index < count-1: layout.exits.append(_walled_door(layout.outgoing,index+2,layout,true))
		if index == count-1: layout.exits.append(_make_stairs(layout))
		for exit: Dictionary in layout.exits:
			if exit.is_empty(): return []
		for key: String in ["coordinate","incoming","outgoing","ports"]: layout.erase(key)
		rooms.append(layout)
	return rooms

static func _spawn(index: int, points: Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var point: Variant = points[posmod(index, points.size())]
	return point if point is Vector2 else Vector2.ZERO

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and floorf(float(value)) == float(value)

static func _numbers(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for component: Variant in value:
		if not _number(component):
			return false
	return true

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

static func _geometry_valid(layout: Dictionary) -> bool:
	return not _collision_geometry(layout).is_empty()

static func _collision_geometry(layout: Dictionary) -> Dictionary:
	# Hash in engine code, then compare the complete collision inputs before a
	# hit. A hash collision or an in-place edit can never reuse stale geometry.
	var bounds_data: Variant = layout.get("play_bounds")
	var obstacle_data: Variant = layout.get("obstacles")
	if not bounds_data is Array or not obstacle_data is Array: return {}
	var signature: int = hash([bounds_data, obstacle_data])
	for index: int in range(_geometry_cache.size()):
		var cached: Dictionary = _geometry_cache[index]
		if cached.signature == signature and cached.bounds_data == bounds_data and cached.obstacle_data == obstacle_data:
			_geometry_cache.remove_at(index)
			_geometry_cache.append(cached)
			return cached
	if not _numbers(layout.get("play_bounds"), 4) or not layout.get("obstacles") is Array:
		return {}
	var walls: Array[Rect2] = []
	for entry: Variant in layout.obstacles:
		if not _numbers(entry, 4) or float(entry[2]) <= 0.0 or float(entry[3]) <= 0.0:
			return {}
		walls.append(_rect(entry))
	_geometry_serial += 1
	var geometry := {"serial":_geometry_serial,"signature":signature,
		"bounds_data":bounds_data.duplicate(true),"obstacle_data":obstacle_data.duplicate(true),
		"bounds":_rect(bounds_data),"walls":walls}
	_geometry_cache.append(geometry)
	if _geometry_cache.size() > NAVIGATION_CACHE_LIMIT: _geometry_cache.pop_front()
	return geometry

static func _navigation_for(layout: Dictionary, radius: float, geometry: Dictionary) -> Dictionary:
	if not _integer(layout.get("tile_size")) or int(layout.tile_size) < 8 or not is_finite(radius) or radius < 0.0: return {}
	var tile: float = float(layout.tile_size)
	for index: int in range(_navigation_cache.size()):
		var cached: Dictionary = _navigation_cache[index]
		if cached.geometry_serial == geometry.serial and cached.radius == radius and cached.tile == tile:
			_navigation_cache.remove_at(index)
			_navigation_cache.append(cached)
			return cached
	var bounds: Rect2 = geometry.bounds.grow(-radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0: return {}
	var walls: Array[Rect2] = []
	for wall: Rect2 in geometry.walls: walls.append(wall.grow(radius))
	var graph := AStar2D.new()
	var navigation := {"geometry_serial":geometry.serial,"radius":radius,"tile":tile,
		"bounds":bounds,"walls":walls,"cells":{},"graph":graph}
	var cells: Dictionary = navigation.cells
	for y: int in range(int(ceilf(bounds.position.y / tile)), int(floorf(bounds.end.y / tile)) + 1):
		for x: int in range(int(ceilf(bounds.position.x / tile)), int(floorf(bounds.end.x / tile)) + 1):
			var cell := Vector2i(x,y)
			var point := Vector2(cell)*tile
			if not _navigation_segment_blocked(point,point,navigation):
				var point_id: int = cells.size()
				cells[cell] = point_id
				graph.add_point(point_id,point)
	for cell: Vector2i in cells:
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i = cell+direction
			if cells.has(next) and not _navigation_segment_blocked(Vector2(cell)*tile,Vector2(next)*tile,navigation):
				graph.connect_points(cells[cell],cells[next])
	_navigation_cache.append(navigation)
	if _navigation_cache.size() > NAVIGATION_CACHE_LIMIT: _navigation_cache.pop_front()
	return navigation

static func _navigation_segment_blocked(from: Vector2, to: Vector2, navigation: Dictionary) -> bool:
	var bounds: Rect2 = navigation.bounds
	if not _inside(from,bounds) or not _inside(to,bounds): return true
	for wall: Rect2 in navigation.walls:
		if _segment_intersects_rect(from,to,wall): return true
	return false

static func _visible_navigation_cells(point: Vector2, navigation: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var tile: float = navigation.tile
	var origin := Vector2i(roundi(point.x/tile),roundi(point.y/tile))
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			var cell := origin+Vector2i(x,y)
			if navigation.cells.has(cell) and not _navigation_segment_blocked(point,Vector2(cell)*tile,navigation): result.append(cell)
	return result

static func _inside(point: Vector2, bounds: Rect2) -> bool:
	return point.x >= bounds.position.x and point.y >= bounds.position.y and point.x <= bounds.end.x and point.y <= bounds.end.y

static func _segment_intersects_rect(from: Vector2, to: Vector2, wall: Rect2) -> bool:
	var delta: Vector2 = to - from
	var entry: float = 0.0
	var exit: float = 1.0
	for axis: int in range(2):
		if absf(delta[axis]) <= EPSILON:
			if from[axis] < wall.position[axis] or from[axis] > wall.end[axis]:
				return false
		else:
			var first: float = (wall.position[axis] - from[axis]) / delta[axis]
			var second: float = (wall.end[axis] - from[axis]) / delta[axis]
			entry = maxf(entry, minf(first, second))
			exit = minf(exit, maxf(first, second))
			if entry > exit:
				return false
	return true

static func _floor_cells(layout: Dictionary, radius: float) -> Dictionary:
	var geometry := _collision_geometry(layout)
	if geometry.is_empty(): return {}
	var navigation := _navigation_for(layout,radius,geometry)
	return navigation.get("cells",{})

static func _nearby_visible_cells(point: Vector2, radius: float, layout: Dictionary, cells: Dictionary, tile: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin: Vector2i = Vector2i(roundi(point.x / tile), roundi(point.y / tile))
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var cell: Vector2i = origin + Vector2i(x, y)
			if cells.has(cell) and not segment_blocked(point, Vector2(cell) * tile, radius, layout):
				result.append(cell)
	return result

static func _floor_connected(layout: Dictionary, radius: float) -> bool:
	var geometry := _collision_geometry(layout)
	if geometry.is_empty(): return false
	var navigation := _navigation_for(layout,radius,geometry)
	if navigation.is_empty() or navigation.cells.is_empty(): return false
	var graph: AStar2D = navigation.graph
	var visited: Dictionary = {}
	var queue: Array[int] = [0]
	visited[queue[0]] = true
	var cursor: int = 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		for next: int in graph.get_point_connections(current):
			if not visited.has(next):
				visited[next] = true
				queue.append(next)
	if visited.size() != navigation.cells.size():
		return false
	for point: Vector2 in layout.player_spawns + layout.enemy_spawns:
		if _visible_navigation_cells(point,navigation).is_empty():
			return false
	return true

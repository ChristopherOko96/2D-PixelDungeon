extends RefCounted
## Enemy hordes on the host (assets/data/combat_hordes.json). Every combat room
## has a quota that grows with the floor; after the authored opening group,
## waves keep coming from spots away from (and preferably out of sight of) the
## heroes until the quota is spent, never more than the floor's alive cap at
## once. Doors stay usable the whole time, so the party can fight its way
## through. Leaving a room returns its living horde to the quota; a room whose
## quota is spent and whose enemies are dead is quiet for good.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const DATA_PATH := "res://assets/data/combat_hordes.json"

var game: Node
## False switches hordes off (single encounters as before; some tests use it).
var enabled := true
var _data: Dictionary = {}
## room id -> {total, left, timer, spawned}
var rooms: Dictionary = {}
var _points: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


func bind(owner: Node) -> void:
	game = owner
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	_data = parsed if parsed is Dictionary else {}
	enabled = bool(_data.get("enabled", true))


## A new run or floor: no room has a horde yet.
func reset(seed_value: int) -> void:
	rooms.clear()
	_points.clear()
	_rng.seed = seed_value + 271828


## EXP factor for kills while hordes are on.
func exp_scale() -> float:
	return float(_data.get("exp_scale", 0.25)) if enabled else 1.0


func _by_floor(key: String, fallback: Array) -> int:
	var range_values: Array = _data.get(key, fallback)
	var t := clampf((float(game.floor_index) - 1.0) / 9.0, 0.0, 1.0)
	return roundi(lerpf(float(range_values[0]), float(range_values[1]), t))


## Enemies allowed alive at once on this floor.
func alive_cap() -> int:
	return _by_floor("alive", [15, 25])


func _id() -> String:
	return str(game.current_layout.get("id", ""))


## True when this room already has a horde (the opening group was spawned once).
func known(room_id: String) -> bool:
	return rooms.has(room_id)


## The party enters a combat room; `opening` enemies were just spawned.
func enter(opening: int, boss_room: bool) -> void:
	_points.clear()
	if not enabled: return
	var state: Dictionary = rooms.get(_id(), {})
	if state.is_empty():
		var total := _by_floor("quota", [25, 50])
		if boss_room: total = roundi(total * float(_data.get("boss_room_scale", 0.5)))
		state = {"total": maxi(total, opening), "left": maxi(0, total - opening), "spawned": opening}
		rooms[_id()] = state
	state.timer = float(_data.get("first_wave_delay", 1.2)) if opening > 0 else 0.3
	_collect_points()


## The party leaves: living horde members go back to the room's quota.
func leave() -> void:
	if not enabled or not rooms.has(_id()): return
	var state: Dictionary = rooms[_id()]
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) > 0.0 and not bool(enemy.get("summoned", false)) and not bool(enemy.get("boss", false)) and not bool(enemy.get("miniboss", false)):
			state.left = int(state.left) + 1


## True while the room still has enemies to send.
func pending() -> bool:
	return enabled and int(rooms.get(_id(), {}).get("left", 0)) > 0


## Remaining horde of the room for the HUD: still to come plus alive.
func snapshot() -> Dictionary:
	var state: Dictionary = rooms.get(_id(), {})
	if state.is_empty(): return {}
	var alive := 0
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) > 0.0: alive += 1
	return {"left": int(state.left) + alive, "total": int(state.total)}


## Sends the next wave when it is due; call each host step while fighting.
func step(delta: float) -> void:
	if not enabled or game.phase != "combat": return
	var state: Dictionary = rooms.get(_id(), {})
	if state.is_empty() or int(state.left) <= 0: return
	var alive := 0
	for enemy: Dictionary in game.enemies:
		if float(enemy.hp) > 0.0: alive += 1
	state.timer = float(state.timer) - delta
	if float(state.timer) > 0.0 or alive >= alive_cap(): return
	state.timer = float(_data.get("wave_interval", 2.5))
	var size := mini(_rng.randi_range(int(_data.get("wave_min", 3)), int(_data.get("wave_max", 6))), mini(int(state.left), alive_cap() - alive))
	var spots := _spots(size)
	for point: Vector2 in spots:
		var kind: String = game.crypt_ai.choose_kind(int(game.room), int(state.spawned), int(state.total), false, _rng)
		var enemy: Dictionary = game._create_enemy(kind, point)
		enemy.wave = true
		enemy.nav_timer = _rng.randf_range(0.0, 0.4)
		game.enemies.append(enemy)
		game.add_fx("enemy_spawn", point, 18.0)
		state.left = int(state.left) - 1
		state.spawned = int(state.spawned) + 1
	if not spots.is_empty(): print("HORDE_WAVE room=%d enemies=%d left=%d" % [int(game.room), spots.size(), int(state.left)])


## Open floor spots of the room (every second cell, room for a large enemy).
func _collect_points() -> void:
	var layout: Dictionary = game.current_layout
	var dimensions: Array = layout.get("world_size", [1280, 720])
	for y in range(2, int(float(dimensions[1]) / 32.0) - 2, 2):
		for x in range(2, int(float(dimensions[0]) / 32.0) - 2, 2):
			var point := Vector2(x * 32, y * 32)
			if not Dungeon.segment_blocked(point, point, 20.0, layout): _points.append(point)


## Up to `count` spawn spots in a ring around the heroes (not closer than
## spawn_distance, not farther than spawn_max_distance from the nearest one),
## out of sight first; farther spots only when the ring is full.
func _spots(count: int) -> Array[Vector2]:
	var minimum := float(_data.get("spawn_distance", 280))
	var maximum := float(_data.get("spawn_max_distance", 650))
	var hidden: Array[Vector2] = []
	var seen: Array[Vector2] = []
	var distant: Array[Vector2] = []
	for point: Vector2 in _points:
		var far := true
		var visible := false
		var nearest := INF
		for player: Dictionary in game.players.values():
			if int(player.hp) <= 0: continue
			nearest = minf(nearest, point.distance_to(player.pos))
			if point.distance_to(player.pos) < minimum: far = false
			elif not visible and point.distance_to(player.pos) < 700.0 and not Dungeon.segment_blocked(player.pos, point, 0.0, game.current_layout): visible = true
		if not far: continue
		for exit: Dictionary in game.current_layout.get("exits", []):
			if point.distance_to(Dungeon._rect(exit.rect).get_center()) < 96.0: far = false
		if not far: continue
		if nearest > maximum: distant.append(point)
		elif visible: seen.append(point)
		else: hidden.append(point)
	var result: Array[Vector2] = []
	for pool: Array[Vector2] in [hidden, seen, distant]:
		while not pool.is_empty() and result.size() < count:
			var pick := _rng.randi_range(0, pool.size() - 1)
			var point: Vector2 = pool[pick]
			pool.remove_at(pick)
			if result.any(func(other: Vector2) -> bool: return other.distance_to(point) < 48.0): continue
			result.append(point)
	return result

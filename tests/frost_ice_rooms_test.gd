extends SceneTree
## The Frostgruft's rooms of nothing but ice (frost_world.json ice_rooms, frost_theme.json ice_room):
## where they come, that the hero and every monster on its feet slide far there and stand firm
## outside, flyers keep flying, and the floor shows ice instead of snow.
## Usage:
##   godot --headless --path . --script res://tests/frost_ice_rooms_test.gd
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const FLOORS_CHECKED := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const ROUNDS := 4
const MOST_PER_FLOOR := 1
const TEST_SEED := 4711
const DT := 1.0 / 60.0

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("FROST_ICE_ROOMS_FAIL: ", what)


func _run() -> void:
	seed(TEST_SEED)
	await _test_at_most_one_room_per_floor()
	await _test_only_frost()
	await _test_sliding()
	print("FROST_ICE_ROOMS_TEST_PASS" if _failed == 0 else "FROST_ICE_ROOMS_TEST_FAILED %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _new_game(scene: PackedScene) -> Node:
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	return game


func _ice_rooms(game: Node) -> Array:
	return (game.W.rooms as Array).filter(func(r: Dictionary) -> bool: return bool(r.get("ice", false)))


func _test_at_most_one_room_per_floor() -> void:
	var game: Node = await _new_game(FrostScene)
	var limits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_world.json")).ice_rooms
	var counts := {}
	for round_index in range(ROUNDS):
		for n: int in FLOORS_CHECKED:
			game.load_floor(n, false)
			var ice := _ice_rooms(game)
			counts[ice.size()] = int(counts.get(ice.size(), 0)) + 1
			_check(ice.size() <= MOST_PER_FLOOR, "floor %d: %d ice rooms" % [n, ice.size()])
			for r: Dictionary in ice:
				_check(str(r.type) in limits.types, "floor %d: only fight rooms, was %s" % [n, r.type])
				_check((r.cells as Array).size() >= int(limits.min_cells), "floor %d: the room is big enough" % n)
				for c: Vector2i in r.cells:
					var i: int = c.y * int(game.W.cols) + c.x
					_check(not game.frost_snow.snow.has(i), "floor %d: no snow in an ice room" % n)
			var others: Array = (game.W.rooms as Array).filter(func(r: Dictionary) -> bool: return not bool(r.get("ice", false)) and str(r.type) == "start")
			_check(not others.is_empty(), "floor %d: the start room stays snow" % n)
	print("FROST_ICE_ROOMS_COUNTS ", counts)
	_check(int(counts.get(1, 0)) > 0, "ice rooms still come")
	game.queue_free()
	await process_frame


## Loads floors until one has an ice room, so the sliding checks always have one to stand in.
func _load_floor_with_ice(game: Node) -> void:
	for round_index in range(ROUNDS):
		for n: int in FLOORS_CHECKED:
			game.load_floor(n, false)
			if not _ice_rooms(game).is_empty():
				return


## The cell of `room` with the longest open row to its right, so a glide has room to run.
func _open_cell(room: Dictionary) -> Vector2i:
	var cells := {}
	for c: Vector2i in room.cells:
		cells[c] = true
	var best: Vector2i = room.cells[0]
	var best_run := -1
	for c: Vector2i in room.cells:
		var run := 0
		while cells.has(c + Vector2i(run + 1, 0)):
			run += 1
		if run > best_run:
			best = c
			best_run = run
	return best


func _test_only_frost() -> void:
	var game: Node = await _new_game(KryptaScene)
	_check(_ice_rooms(game).is_empty(), "the Krypta has no ice rooms")
	_check(not game.ice_room_at(Vector2(game.player.x, game.player.y)), "and nothing slides there")
	game.queue_free()
	await process_frame


## How far the hero glides after a full run, on ice and on snow, by the game's own step.
func _hero_glide(game: Node, at: Vector2) -> float:
	game.player.x = at.x
	game.player.y = at.y
	var grip := MotionKit.FIRM
	if game.ice_room_at(at - Vector2(0.0, 6.0)):
		grip = float(game.theme.ice_room.grip)
	var mover: Variant = game.motion_kit()
	# the same grip the host reports for a knock
	_check(is_equal_approx(float(mover.host.hero_grip()), grip), "the host knows the hero's footing at %s" % at)
	var v := Vector2(float(game.hero.get("speed", 300.0)), 0.0)
	var walked := 0.0
	for i in range(240):
		v = MotionKit.slide(v, Vector2.ZERO, grip, DT)
		walked += v.length() * DT
	return walked


func _test_sliding() -> void:
	var game: Node = await _new_game(FrostScene)
	_load_floor_with_ice(game)
	var ice: Dictionary = _ice_rooms(game)[0]
	var cell := _open_cell(ice)
	var on_ice :=Vector2((cell.x + 0.5) * game.C, (cell.y + 0.5) * game.C)
	_check(game.ice_room_at(on_ice), "the room's middle is ice")
	var on_snow := Vector2(game.player.x, game.player.y)
	_check(not game.ice_room_at(on_snow), "the start room is not")
	var glide := await _hero_glide(game, on_ice)
	_check(glide >= 3.0 * float(game.C), "the hero glides at least 3 cells, was %.0f px" % glide)
	_check(await _hero_glide(game, on_snow) <= 0.01, "on snow he stops at once")
	# a monster of frost, with its real def in the real loop
	var mover: Variant = game.motion_kit()
	var free := func(_x: float, _y: float) -> bool: return false
	var grip := float(game.theme.ice_room.mob_grip)
	var step: Dictionary = mover.step_body(on_ice, Vector2(200.0, 0.0), Vector2.ZERO, grip, Vector2.ZERO, Vector2.ZERO, DT, free)
	_check((step.vel as Vector2).x > 190.0, "a monster keeps its speed from frame to frame, was %s" % step.vel)
	var wall := func(x: float, _y: float) -> bool: return x > on_ice.x
	var stopped: Dictionary = mover.step_body(on_ice, Vector2(200.0, 0.0), Vector2.ZERO, grip, Vector2.ZERO, Vector2.ZERO, DT, wall)
	_check(is_zero_approx((stopped.vel as Vector2).x), "a wall ends its slide on that axis")
	await _test_real_monster(game, ice, on_ice, on_snow)
	game.queue_free()
	await process_frame


## Monsters in the game's own loop (_update_mobs): held still by a move and given a speed, they glide
## on over the ice and stop dead on the snow; a creature of frost is no exception, a flyer never slides.
func _test_real_monster(game: Node, ice: Dictionary, on_ice: Vector2, on_snow: Vector2) -> void:
	var kind := _frost_kind(game)
	_check(not kind.is_empty(), "the Frostgruft has a creature of frost")
	var on_ice_px := _mob_glide(game, kind, ice, on_ice, 0.0)
	_check(on_ice_px >= 80.0, "a creature of frost glides on the ice, %.0f px" % on_ice_px)
	var on_snow_px := _mob_glide(game, kind, ice, on_snow, 0.0)
	_check(on_snow_px <= 1.0, "it stands firm on the snow, %.0f px" % on_snow_px)
	var flying_px := _mob_glide(game, kind, ice, on_ice, 40.0)
	_check(flying_px <= 1.0, "a flyer does not slide on the ice, %.0f px" % flying_px)
	_check(ice.get("kind", "") == "Eisfläche", "the room is labelled, was %s" % ice.get("kind", ""))


func _frost_kind(game: Node) -> String:
	for kind: String in game.theme.mobs:
		if (game.theme.mobs[kind] as Dictionary).has("chill"):
			return kind
	return ""


## How far a held monster at `at` with 200 px/s of sliding speed gets in half a second.
func _mob_glide(game: Node, kind: String, ice: Dictionary, at: Vector2, alt: float) -> float:
	game.mobs.clear()
	game._spawn_mob(int(ice.index), at, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	m.p = at
	m.hold = true
	m.alt = alt
	m.sv = Vector2(200.0, 0.0)
	# the hero far off, so nothing but the slide moves it
	game.player.x = at.x
	game.player.y = at.y + 2000.0
	for i in range(30):
		m.hold = true
		m.alt = alt
		game._update_mobs(DT)
	var moved: float = (m.p as Vector2).distance_to(at)
	game.mobs.clear()
	return moved

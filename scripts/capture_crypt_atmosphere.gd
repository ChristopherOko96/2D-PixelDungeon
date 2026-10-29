extends SceneTree
## Captures the crypt's void atmosphere (assets/data/vfx_crypt_atmosphere.json)
## from the real windowed game at fixed spots, so before/after shots line up:
##   01-fackeln-nordwand  the hero below the first north-wall torch, room cleared
##   02-kerzen-tor        the hero beside the first candle column (gate), cleared
##   03-kampf             a fresh run: enemies close in, the mage shoots (readability)
##   04-raum-spawn        the cleared room at the hero spawn (fog over the floor)
##   05-raum-spawn-3s     the same spot 3 s later: the fog has drifted on
## Same seed, same debug room, same hero spot each time; the camera ignores the
## mouse. The hero is kept invulnerable. Usage (repo root, 1280x720 window):
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_crypt_atmosphere.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const ROOM := "RAUM 02"
const SEED := 4242

## Room camera without mouse look-ahead: the frame depends on the hero only.
class StillCamera extends "res://src/room_camera.gd":
	func update(player: Vector2, _mouse_delta: Vector2, world: Vector2, viewport: Vector2, delta: float, tuning: Dictionary, frozen: bool) -> Vector2:
		return super(player, Vector2.ZERO, world, viewport, delta, tuning, frozen)

var _out := "res://production/qa/evidence/crypt-atmosphere"
var _game: Node
## Fixed hero spot (world px) held every frame while set.
var _pin := Vector2.INF


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
			if _pin.is_finite():
				_game.players[1].pos = _pin
				_game.players[1].knockback = Vector2.ZERO
			if _game.scripted_fire:
				var alive: Array = _game.enemies.filter(func(e: Dictionary) -> bool: return float(e.hp) > 0)
				_game.scripted_target = Vector2(alive[0].pos) if not alive.is_empty() else Vector2.INF
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}


## Starts a solo run in the debug room with a hero class on the fixed seed.
func _start(class_id: String) -> void:
	_game.requested_seed = SEED
	_game.main_menu._pick_debug(_entry(ROOM))
	_game.main_menu._choose_class(class_id)
	_game.room_camera = StillCamera.new()
	await _wait(30)


func _leave() -> void:
	_pin = Vector2.INF
	_game._leave_session()
	await _wait(10)


## Clears the room with the debug cheat (no waves left, doors open).
func _clear_room() -> void:
	var order: Array = _game.cheats.data.get("order", [])
	_game._send_action("cheat", order.find("clear_room"))
	# Long enough for the cheat toast to fade.
	await _wait(240)


## Pins the hero to `point` and lets the camera settle there.
func _stand(point: Vector2) -> void:
	_pin = point
	await _wait(90)


## The first of `spots` the hero can walk to from `from` (a path exists and
## ends on the spot), or INF.
func _reachable(from: Vector2, spots: Array) -> Vector2:
	for spot: Vector2 in spots:
		var path: PackedVector2Array = Dungeon.find_path(from, spot, 14.0, _game.current_layout)
		if not path.is_empty() and path[path.size() - 1].distance_to(spot) < 4.0: return spot
	return Vector2.INF


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	await _start("mage")
	var layout: Dictionary = _game.current_layout
	var spawn: Vector2 = Vector2(_game.players[1].pos).round()
	# 3) The fight: the hero holds the spawn, the room's enemies stand at fixed
	# spots around it and act from there; the mage shoots the first of them.
	_pin = spawn
	var spots := [Vector2(170, -70), Vector2(-160, 50), Vector2(140, 120), Vector2(60, -150)]
	var placed := 0
	for enemy: Dictionary in _game.enemies:
		if placed >= spots.size(): break
		if float(enemy.hp) <= 0 or bool(enemy.get("boss", false)): continue
		var spot := _reachable(spawn, [spawn + spots[placed], spawn + spots[placed] * 0.6])
		placed += 1
		if spot.is_finite(): enemy.pos = spot
	_game.scripted_fire = true
	await _wait(70)
	await _shot("03-kampf.png")
	_game.scripted_fire = false
	_game.scripted_target = Vector2.INF
	# 1) 2) 4) The same room cleared: torches, candle columns, the spawn floor.
	await _clear_room()
	var art: RefCounted = _game.view._crypt72
	var torches: Array = art.torches if art != null else []
	var candles: Array = art.candles if art != null else []
	print("ATMOSPHERE_ROOM id=%s spawn=%s torches=%d candles=%d" % [layout.get("id", ""), spawn, torches.size(), candles.size()])
	for torch: Vector2 in torches:
		var spot := _reachable(spawn, [torch + Vector2(16, 130), torch + Vector2(16, 90)])
		if not spot.is_finite(): continue
		await _stand(spot)
		await _shot("01-fackeln-nordwand.png")
		break
	for candle: Vector2 in candles:
		var spot := _reachable(spawn, [candle + Vector2(86, 70), candle + Vector2(-54, 70), candle + Vector2(16, 110)])
		if not spot.is_finite(): continue
		await _stand(spot)
		await _shot("02-kerzen-tor.png")
		break
	await _stand(spawn)
	await _shot("04-raum-spawn.png")
	await _wait(180)
	await _shot("05-raum-spawn-3s.png")
	await _leave()
	print("CAPTURE_DONE")
	quit()

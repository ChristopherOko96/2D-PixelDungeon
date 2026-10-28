extends SceneTree
## Captures evidence of the hell monsters from the real windowed game: a combat
## room with the floor's roster, the six floor bosses, and Ignaroth in all four
## phases with his arrival from the floor and from the sky, burrowing, a bomb
## flight, the transformation flash, the echoes of his earlier forms and his
## death on floor 10. The hero is kept invulnerable.
## Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_hell_monsters.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")

var _out := "res://production/qa/evidence/hell-monsters"
var _game: Node
var _last := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 5.0
		await process_frame


## Waits until check() holds (at most limit frames).
func _until(check: Callable, limit := 900) -> void:
	for i in range(limit):
		if check.call():
			return
		await _wait(1)
	print("CAPTURE_TIMEOUT after ", _last)


func _shot(name: String) -> void:
	var blink: float = _game.state.inv
	_game.state.inv = 0.0
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	_last = name
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	_game.state.inv = blink


func _put(p: Vector2) -> void:
	_game.player.x = p.x
	_game.player.y = p.y
	_game.camera.position = p


## Moves the hero beside or below the boss so the boss stays clear of the HUD at the bottom.
func _near_boss() -> void:
	var b := _boss()
	var at: Vector2 = b.intro.get("to", b.p) if b.get("intro") != null else b.p
	for off: Vector2 in [Vector2(-380, 40), Vector2(380, 40), Vector2(-260, 260), Vector2(260, 260), Vector2(0, 340)]:
		var p := at + off
		if _game._room_at_world(p.x, p.y) == b.room and not _game.box_blocked(_game._player_box(p.x, p.y).grow(30)):
			_put(p - Vector2(0, 0))
			_game.camera.position = at.lerp(p, 0.5) + Vector2(0, 80)
			break
	await _wait(20)


func _boss() -> Dictionary:
	for m: Dictionary in _game.mobs:
		if m.boss:
			return m
	return {}


## Starts floor n in its boss room; the fight begins on the next frame.
func _boss_floor(n: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = HellScene.instantiate()
	_game.start_floor = n
	_game.start_at_boss = true
	root.add_child(_game)
	await _wait(2)


## Makes the boss use the attack with this id next.
func _force(id: String) -> void:
	var b := _boss()
	var attacks: Array = b.st.attacks
	for k in range(attacks.size()):
		b.cds[k] = -100.0 if attacks[k].id == id else maxf(b.cds[k], 3.0)


func _acting(id: String) -> Callable:
	return func() -> bool: return _boss().get("act") != null and _boss().act.a.id == id


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# a combat room on floor 5 with its roster
	_game = HellScene.instantiate()
	_game.start_floor = 5
	root.add_child(_game)
	await _wait(10)
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.mobs >= 3:
			var mid := Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0) * 96.0)
			var best := INF
			for c: Vector2i in r.cells:
				var p := Vector2((c.x + 0.5) * 96.0, (c.y + 0.8) * 96.0)
				if _game._cell(c.x, c.y) == 1 and p.distance_to(mid) < best and _game._fully_inside(r, p.x, p.y) 						and not _game.box_blocked(_game._player_box(p.x, p.y).grow(40)):
					best = p.distance_to(mid)
					_put(p)
			break
	await _wait(150)
	await _shot("01-kampfraum-etage5.png")
	# the six floor bosses, each during one of its attacks
	var bosses := {1: "brocken", 2: "atem", 4: "spucke", 5: "spirale", 7: "spalter", 8: "haende"}
	var k := 2
	for n: int in bosses:
		await _boss_floor(n)
		await _wait(20)
		await _near_boss()
		await _wait(30)
		_force(bosses[n])
		await _until(_acting(bosses[n]))
		await _wait(22)
		await _shot("%02d-boss-etage%d-%s.png" % [k, n, _boss().id])
		k += 1
	# Ignaroth, phase 1: bursts out of the floor, then burrows toward the hero
	await _boss_floor(3)
	await _near_boss()
	await _until(func() -> bool: return _boss().get("intro") != null and _boss().intro.get("out", false), 200)
	await _wait(6)
	await _shot("08-ignaroth1-ausbruch.png")
	await _until(func() -> bool: return _boss().get("intro") == null, 900)
	await _near_boss()
	await _wait(20)
	await _shot("09-ignaroth1-salamander.png")
	_force("graben")
	await _until(func() -> bool: return _boss().get("act") != null and _boss().act.has("warn_t"))
	await _wait(8)
	await _shot("10-ignaroth1-eingegraben.png")
	# at 0 HP he transforms
	await _wait(80)
	_boss().hp = 0.0
	await _until(func() -> bool: return _boss().get("trans") != null and _boss().trans.t > 1.0)
	await _shot("11-ignaroth1-verwandlung-glut.png")
	await _until(func() -> bool: return _boss().trans.t > 1.62)
	await _shot("12-ignaroth1-verwandlung-blitz.png")
	await _until(func() -> bool: return _boss().trans.t > 2.6)
	await _shot("13-ignaroth-jungdrache-erscheint.png")
	# phase 2
	await _boss_floor(6)
	await _until(func() -> bool: return _boss().get("intro") == null, 900)
	await _near_boss()
	_force("schwanz")
	await _until(_acting("schwanz"))
	await _wait(12)
	await _shot("14-ignaroth2-schwanzwirbel.png")
	# phase 3: the arrival from the sky, a bomb flight and the breath
	await _boss_floor(9)
	await _near_boss()
	await _until(func() -> bool: return _boss().get("intro") != null and _boss().intro.t > 1.3, 200)
	await _shot("15-ignaroth3-einflug.png")
	await _until(func() -> bool: return _boss().get("intro") != null and _boss().intro.get("landed", false), 200)
	await _wait(5)
	await _shot("16-ignaroth3-landung.png")
	await _until(func() -> bool: return _boss().get("intro") == null, 900)
	_force("bombenflug")
	await _until(func() -> bool: return _boss().get("act") != null and _boss().act.a.id == "bombenflug" and _boss().act.t > 2.0)
	await _shot("17-ignaroth3-bombenflug.png")
	await _until(func() -> bool: return _boss().get("act") == null)
	_force("atem")
	await _until(func() -> bool: return _boss().get("act") != null and _boss().act.a.id == "atem" and _boss().act.t > 1.1)
	await _shot("18-ignaroth3-glutatem.png")
	# phase 4: the echoes, the void beams, and his death
	await _boss_floor(10)
	await _until(func() -> bool: return _boss().get("intro") == null, 900)
	await _near_boss()
	_force("echos")
	await _until(func() -> bool: return _game.mobs.any(func(m: Dictionary) -> bool: return m.has("echo") and m.spawn <= 0.0))
	await _wait(50)
	await _shot("19-ignaroth4-echos.png")
	await _until(func() -> bool: return _boss().get("act") == null)
	_force("strahlen")
	await _until(func() -> bool: return _boss().get("act") != null and _boss().act.a.id == "strahlen" and _boss().act.t > 1.6)
	await _shot("20-ignaroth4-leerenstrahlen.png")
	_boss().hp = 0.0
	await _until(func() -> bool: return _boss().get("dying") != null and _boss().dying.t > 1.6)
	await _shot("21-ignaroth4-wankt.png")
	await _until(func() -> bool: return _boss().is_empty() or _boss().dying.t > 2.68)
	await _shot("22-ignaroth4-tod.png")
	await _wait(120)
	await _shot("23-ignaroth4-besiegt-portal.png")
	print("HELL_MONSTERS_CAPTURE done")
	quit(0)

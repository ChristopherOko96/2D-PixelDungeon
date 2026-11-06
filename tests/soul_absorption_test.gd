extends "res://tests/talent_pet_test.gd"
## Seelensog presentation follows the rendered owner's staff, without changing income.
const Fx = preload("res://src/vfx/talent_fx.gd")
const Look = preload("res://src/hero/hero_look.gd")

func _run() -> void:
	var fx := Fx.new()
	check(fx.has_method("soul_absorption"), "soul reward has a staff-bound visual sample")
	if fx.has_method("soul_absorption"):
		test_moving_staff_and_owner_are_followed(fx)
		test_arrival_pulses_once_then_disappears(fx)
		test_stale_staff_uses_current_owner(fx)
	await _start()
	game.progress.save_path = "user://soul_absorption_test_profile.json"
	var rt := _hero("necromancer", {})
	rt.res = 0.0
	var victim := _foe(Vector2(80, 0))
	game._damage_enemy(victim, 99999.0, Vector2.RIGHT, 1, true)
	var events: Array = tc.snapshot().events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "souls")
	check(events.size() == 1 and float(rt.res) == 8.0, "host kill still pays eight souls and emits exactly one visual")
	if not events.is_empty():
		check(int(events[0].owner) == 1 and float(events[0].span) == 0.7, "existing owner and event lifetime remain compatible")
		tc.enemy_killed(victim, 1)
		check(tc.snapshot().events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "souls").size() == 1, "repeated death cannot replay collection")
	var full := _foe(Vector2(90, 0))
	rt.res = rt.res_max
	game._damage_enemy(full, 99999.0, Vector2.RIGHT, 1, true)
	check(float(rt.res) == float(rt.res_max), "presentation does not overfill the existing gauge")
	game._leave_session()
	game.queue_free()
	await process_frame
	var scratch := ProjectSettings.globalize_path("user://soul_absorption_test_profile.json")
	if FileAccess.file_exists(scratch): DirAccess.remove_absolute(scratch)
	print("SOUL_ABSORPTION checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _event(progress: float) -> Dictionary:
	return {"kind": "souls", "id": 71, "owner": 2, "x": 80.0, "y": 240.0, "tx": 300.0, "ty": 240.0,
		"life": 0.7 * (1.0 - progress), "span": 0.7}

func test_moving_staff_and_owner_are_followed(fx: RefCounted) -> void:
	var look := Look.new()
	fx.set_art(3.0, Vector2(0, -38))
	fx.necro_staff = Callable(look, "staff_socket")
	fx.set_necro_actors({1: {"x": 900, "y": 500}, 2: {"x": 340, "y": 260}}, [])
	look._staff_sockets.p2 = {"at": Vector2(365, 210), "clock": 10.0}
	var a: Dictionary = fx.call("soul_absorption", _event(0.4), 10.0)
	check(Vector2(a.to) == Vector2(365, 210), "soul targets recipient two's posed orb, not recipient one or old tx/ty")
	look._staff_sockets.p2 = {"at": Vector2(410, 190), "clock": 10.016}
	var b: Dictionary = fx.call("soul_absorption", _event(0.4), 10.016)
	check(Vector2(b.to) == Vector2(410, 190) and Vector2(a.at) != Vector2(b.at), "flight follows staff motion between host snapshots")
	check(float(b.progress) > float(a.progress), "flight progresses between host snapshots")
	fx.necro_staff_key = "hero"
	look._staff_sockets.hero = {"at": Vector2(450, 180), "clock": 11.0}
	var story: Dictionary = fx.call("soul_absorption", _event(0.5), 11.0)
	check(Vector2(story.to) == Vector2(450, 180), "story worlds use their hero socket key")
	fx.necro_staff = Callable()
	fx.necro_staff_key = ""

func test_arrival_pulses_once_then_disappears(fx: RefCounted) -> void:
	var early: Dictionary = fx.call("soul_absorption", _event(0.2), 20.0)
	var flying: Dictionary = fx.call("soul_absorption", _event(0.5), 21.0)
	var arriving: Dictionary = fx.call("soul_absorption", _event(0.82), 22.0)
	check(float(early.alpha) > 0.0 and float(early.pulse) == 0.0, "visible spirit rises before any intake flash")
	check(float(flying.scale) > float(arriving.scale), "soul shrinks into the staff near arrival")
	check(Vector2(arriving.at).is_equal_approx(arriving.to) and float(arriving.pulse) > 0.0, "arrival reaches the exact moving orb and pulses there")
	check(float(arriving.alpha) == 0.0, "collected spirit does not linger on the hero")
	check((fx.call("soul_absorption", _event(1.0), 23.0) as Dictionary).is_empty(), "finished event cannot replay or leave an idle halo")

func test_stale_staff_uses_current_owner(fx: RefCounted) -> void:
	var look := Look.new()
	fx.necro_staff = Callable(look, "staff_socket")
	look._staff_sockets.p2 = {"at": Vector2(-500, -500), "clock": 1.0}
	fx.set_necro_actors({2: {"x": 420, "y": 280}}, [])
	var a: Dictionary = fx.call("soul_absorption", _event(0.4), 30.0)
	check(Vector2(a.to) == Vector2(420, 242), "stale socket falls back to the moving recipient chest")
	fx.set_necro_actors({}, [])
	var b: Dictionary = fx.call("soul_absorption", _event(0.4), 31.0)
	check(Vector2(b.to) == Vector2(300, 202), "missing owner safely uses the event endpoint")
	fx.necro_staff = Callable()
	fx.set_art(2.0, Vector2(0, -14))
	fx.set_necro_actors({2: {"x": 420, "y": 280}}, [])
	var crypt: Dictionary = fx.call("soul_absorption", _event(0.4), 32.0)
	check(Vector2(crypt.to) == Vector2(420, 266), "legacy crypt uses its own body offset and two-pixel art grid")

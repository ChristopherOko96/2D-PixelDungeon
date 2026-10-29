extends SceneTree
## The polished swordsman and archer (src/hero/hero_look.gd, src/vfx/slice_fx.gd,
## hero_skills.gd sword_feel): the hero steps into each swing; Rage swings twice,
## the second time back the other way; a small enemy killed in Rage is cut in two,
## a boss never; a body thrown into a wall takes slam damage and is stunned; the
## charge flings bodies off its path; the look leans into swings, pulls the bow
## string before a shot and finds the string of a bow; a cut splits the figure
## into two halves that cover it exactly.

const Game = preload("res://src/game.gd")
const HeroLook = preload("res://src/hero/hero_look.gd")
const SliceFx = preload("res://src/vfx/slice_fx.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var checked := 0
var failures: Array[String] = []
var game: Node


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HERO_POLISH_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_look_leans_and_draws_the_bow()
	_test_slice_halves_cover_the_figure()
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game.player_classes[1] = "swordsman"
	game._host_session()
	game.requested_seed = 777
	game._begin_run()
	game.hordes.enabled = false
	_test_swing_steps_forward()
	_test_rage_swings_twice_and_cuts()
	_test_thrown_body_slams_into_wall()
	_test_charge_flings_bodies()
	game._leave_session()
	game.queue_free()
	await process_frame
	print("HERO_POLISH checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# --- look -------------------------------------------------------------------------

func _test_look_leans_and_draws_the_bow() -> void:
	var look := HeroLook.new(2.0)
	var sword := {"melee": true, "swings": 0, "class_id": "swordsman"}
	look.observe("a", sword, Vector2.ZERO, 0.0)
	sword.swings = 1
	look.observe("a", sword, Vector2.ZERO, 1.0)
	check(look.swing_progress("a", 1.05) > 0.0 and look.body_offset("a", sword, Vector2.RIGHT, 1.08).x > 0.0, "the swordsman leans into a swing")
	check(look.body_offset("a", sword, Vector2.RIGHT, 2.0) == Vector2.ZERO, "and stands straight again after it")
	check(look.face({"skills": {"whirl_time": 0.2}}, Vector2.RIGHT, 0.1) != look.face({"skills": {"whirl_time": 0.2}}, Vector2.RIGHT, 0.3), "the whirl turns the hero around")
	var archer := {"class_id": "archer", "shots": 0, "shot_interval": 0.5}
	look.observe("b", archer, Vector2.ZERO, 0.0)
	check(is_equal_approx(look._draw_amount("b", archer, 0.5, {}), 0.0), "an idle bow hangs slack")
	archer.shots = 1
	look.observe("b", archer, Vector2.ZERO, 1.0)
	var early: float = look._draw_amount("b", archer, 1.1, {})
	var later: float = look._draw_amount("b", archer, 1.4, {})
	check(early < later and later > 0.5, "between shots the string is pulled back (%.2f -> %.2f)" % [early, later])
	check(look._draw_amount("b", archer, 1.0, {"charge": 1.0}) >= 0.999, "Ballistapfeil holds a full draw")
	var bow: Dictionary = look._bow(load("res://assets/sprites/0x72/weapon_bow.png"))
	var image: Image = (bow.texture as Texture2D).get_image()
	var light := 0
	for y in range(image.get_height()):
		var c := image.get_pixel(7, y)
		if c.a > 0.5 and c.get_luminance() > 0.5: light += 1
	check(is_equal_approx(Vector2(bow.tip_a).x, 7.5) and float(bow.tip_b.y) - float(bow.tip_a.y) > 18.0 and light == 0, "the bow's own string is found and taken off for the drawn one")


func _test_slice_halves_cover_the_figure() -> void:
	var slices := SliceFx.new(null)
	var rect := PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(20, 30), Vector2(0, 30)])
	var a: PackedVector2Array = slices._clip(rect, Vector2(10, 15), Vector2(1, 1).normalized())
	var b: PackedVector2Array = slices._clip(rect, Vector2(10, 15), -Vector2(1, 1).normalized())
	var area := func(poly: PackedVector2Array) -> float:
		var s := 0.0
		for i in range(poly.size()):
			s += poly[i].cross(poly[(i + 1) % poly.size()])
		return absf(s) * 0.5
	check(a.size() >= 3 and b.size() >= 3 and is_equal_approx(area.call(a) + area.call(b), 600.0), "the two halves of a cut cover the figure exactly")
	check(slices.handles({"slice": 0.5, "dying_p": 0.1}) and not slices.handles({"slice": 0.5, "dying_p": -1.0}) and not slices.handles({"dying_p": 0.1}), "only a dying, cut enemy is drawn in halves")


# --- rules ------------------------------------------------------------------------

func _hero() -> Dictionary:
	return game.players[1]


func _fresh_hero() -> Dictionary:
	var hero := _hero()
	game.action_times.clear()
	game._server_action(1, "cheat", Array(game.cheats.order()).find("all_skills"))
	game.hero_skills._fresh(hero)
	hero.hp = int(hero.max_hp)
	hero.invulnerable = 0.0
	game.enemies.clear()
	return hero


func _foe(offset: Vector2, kind := "skeleton") -> Dictionary:
	var e: Dictionary = game._create_enemy(kind, Vector2(_hero().pos) + offset)
	game.enemies.append(e)
	return e


func _step(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		game.hero_skills.step(1.0 / 60.0)
		game._step_enemies(1.0 / 60.0) if game.has_method("_step_enemies") else null
		t += 1.0 / 60.0


func _test_swing_steps_forward() -> void:
	var hero := _fresh_hero()
	var before := Vector2(hero.pos)
	game.perk_combat.melee(1, Vector2.RIGHT)
	check(Vector2(hero.pos).x > before.x + 4.0, "the swordsman steps into the swing (%.1f px)" % (Vector2(hero.pos).x - before.x))


func _test_rage_swings_twice_and_cuts() -> void:
	var hero := _fresh_hero()
	game.hero_skills._press(1, hero, 3, ClassPerks.skill_at("swordsman", 3), Vector2(hero.pos) + Vector2(60, 0))
	check(game.hero_skills.rage_active(hero), "Rage runs")
	var small := _foe(Vector2(40, 0))
	small.hp = 1.0
	var boss := _foe(Vector2(42, 6), "skeleton")
	boss.boss = true
	boss.hp = 1.0
	var swings := int(hero.get("swings", 0))
	game.perk_combat.melee(1, Vector2.RIGHT)
	game.hero_skills.basic_attack(1, hero, Vector2.RIGHT)
	game.hero_skills.step(0.2)
	check(int(hero.swings) == swings + 2 and int(hero.swing_dir) == -1, "Rage swings twice, the second time back the other way")
	check(small.has("slice") and float(small.hp) <= 0.0, "a small enemy killed in Rage is cut in two")
	check(not boss.has("slice"), "a boss is never cut in two")
	check(game._make_snapshot().enemies.any(func(e: Dictionary) -> bool: return e.has("slice")), "clients see the cut")


func _wall_spot() -> Vector2:
	# the hero walks left until a wall stops him
	return Dungeon.move_actor(_hero().pos, Vector2(-4000, 0), float(game.balance.player.radius), game.current_layout)


func _test_thrown_body_slams_into_wall() -> void:
	var hero := _fresh_hero()
	var wall := _wall_spot()
	hero.pos = wall + Vector2(90, 0)
	var foe := _foe(Vector2(-50, 0))
	foe.hp = 500.0
	foe.max_hp = 500.0
	game.hero_skills._press(1, hero, 3, ClassPerks.skill_at("swordsman", 3), Vector2(hero.pos) + Vector2(-60, 0))
	var hp_before := float(foe.hp)
	game.hero_skills.rage_hit(1, hero, foe, Vector2.LEFT)
	var slammed := false
	for i in range(40):
		var before := Vector2(foe.pos)
		var push: Vector2 = foe.knockback
		foe.pos = Dungeon.move_actor(foe.pos, push / 60.0, float(foe.radius), game.current_layout)
		game.hero_skills.check_slam(foe, before, push, 1.0 / 60.0)
		if not foe.has("slam"):
			slammed = float(foe.hp) < hp_before
			break
	check(slammed and float(foe.hitstun) > 0.0, "a body thrown into a wall takes slam damage and is stunned")
	check(game.hero_skills.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "wall_slam"), "the slam leaves a crack (event wall_slam)")


func _test_charge_flings_bodies() -> void:
	var hero := _fresh_hero()
	hero.pos = _wall_spot() + Vector2(40, 0)
	var foe := _foe(Vector2(30, 10))
	foe.hp = 500.0
	foe.max_hp = 500.0
	game.hero_skills._press(1, hero, 2, ClassPerks.skill_at("swordsman", 2), Vector2(hero.pos) + Vector2(200, 0))
	for i in range(20):
		game.hero_skills.step(1.0 / 60.0)
	var push: Vector2 = foe.knockback
	check(push.length() > 200.0 and push.y > 0.0, "the charge flings a body off its path, to its own side (%s)" % str(push))
	check(foe.has("slam"), "a flung body can slam into a wall")

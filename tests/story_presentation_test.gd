extends SceneTree
const Presentation = preload("res://src/hell/story_presentation.gd")
const Clock = preload("res://src/physics_kit/fixed_step_clock.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("STORY_PRESENTATION_FAIL: ", label)

func _initialize() -> void:
	for fps: int in [30, 60, 120, 144, 240]:
		var p := Presentation.new()
		var clock := Clock.new({"tick_hz": 60, "max_steps_per_frame": 8})
		var hero := {"x": 0.0, "y": 0.0}
		var mob := {"tid": 1, "p": Vector2(40, 30), "hp": 10.0}
		for i in range(fps):
			clock.begin_frame(1.0 / fps)
			while clock.take_step():
				p.begin_tick(hero, [mob])
				hero.x += 360.0 / 60
				mob.p += Vector2(360.0 / 60, 0)
			p.frame(clock.pending_seconds, clock.step_seconds)
			var authoritative := Vector2(hero.x, hero.y)
			var shown := p.hero_position(hero)
			var expected := maxf(0.0, (i + 1.0) / fps - 1.0 / 60) * 360.0
			check(absf(shown.x - expected) < 0.001, "%d Hz frame %d: uniform interpolated movement" % [fps, i])
			check(p.mob_position(mob).is_equal_approx(shown + Vector2(40, 30)), "hero and mob use the same phase")
			check(authoritative == Vector2(hero.x, hero.y), "reading presentation never moves simulation")
		check(is_equal_approx(hero.x, 360), "one second of gameplay is unchanged")
	var p := Presentation.new()
	var hero := {"x": 0.0, "y": 0.0}
	var mob := {"tid": 8, "p": Vector2.ZERO, "hp": 10.0}
	p.begin_tick(hero, [mob])
	hero.x = 8.0
	mob.p = Vector2(8, 0)
	p.frame(0.005, 0.02)
	check(p.hero_position(hero) == Vector2(2, 0), "fractional frame blends previous and current")
	check(p.mob_position({"tid": 8, "p": Vector2(90, 0), "hp": 10}) == Vector2(90, 0), "reused ID cannot inherit another body's history")
	mob.hp = 0
	check(p.mob_position(mob) == mob.p, "death uses current corpse position")
	hero.x = 5000
	check(p.hero_position(hero).x == 5000, "teleport cannot sweep across the level")
	p.frame(1.0, 0.02)
	check(p.alpha == 1, "overload debt never extrapolates")
	p.reset()
	check(p._bodies.is_empty() and p._previous.is_empty(), "reset releases old bodies")
	hero.x = 10
	check(p.hero_position(hero).x == 10, "pause/floor reset cannot use stale position")
	for size: Vector2 in [Vector2(1280, 720), Vector2(1281, 721), Vector2(1920, 1080), Vector2(1365, 767)]:
		var stretch := Transform2D(Vector2(size.x / 1280, 0), Vector2(0, size.y / 720), Vector2(0.25, 0.125))
		var zoom := Vector2.ONE * (1280.0 / 1800.0)
		for i in range(80):
			var center := Vector2(-72.37, 255.9) + Vector2(0.17, 0.13) * i
			var snapped := Presentation.pixel_center(center, zoom, Vector2(1280, 720), stretch)
			var origin := stretch * Vector2(640, 360) - snapped * zoom * stretch.get_scale()
			check(origin.is_equal_approx(origin.round()), "final screen translation is integral at " + str(size))
			check(((snapped - center) * zoom * stretch.get_scale()).abs().x <= 0.50001 and ((snapped - center) * zoom * stretch.get_scale()).abs().y <= 0.50001, "snap correction stays within half a screen pixel")
	print("STORY_PRESENTATION checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

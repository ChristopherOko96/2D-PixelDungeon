extends SceneTree
## Paired query CPU; includes a rebuild when the adaptive sparse path needs it.
const Fixture = preload("res://tests/talent_spatial_queries_test.gd")
func _initialize() -> void:
	var failures := 0
	for dense: bool in [false, true]:
		for count: int in [8, 32, 128, 256]:
			var full := Fixture.FullHost.new()
			var spatial := Fixture.SpatialHost.new()
			var old := Fixture.Combat.new()
			var current := Fixture.Combat.new()
			old.game = full
			current.game = spatial
			for i in range(count):
				var point := Vector2(i % 16, i / 16) * (8.0 if dense else 240.0)
				full.enemies.append({"id": i, "p": point, "pos": point, "r": 16.0, "radius": 16.0, "hp": 10.0})
			spatial.enemies = full.enemies.duplicate(true)
			# The movement phase already supplies a density hint in the real world.
			spatial.index.rebuild(spatial.enemies)
			var times := [0, 0]
			var same := true
			for tick in range(50):
				var answers: Array = [[], []]
				for k: int in ([0, 1] if tick % 2 == 0 else [1, 0]):
					var combat: RefCounted = old if k == 0 else current
					var start := Time.get_ticks_usec()
					if k == 1 and count >= 24 and not spatial.index.prefers_full_scan(): spatial.index.rebuild(spatial.enemies)
					combat.hits.clear()
					for i in range(64):
						var point: Vector2 = full.enemies[(i * 7) % count].pos
						answers[k].append(combat._nearest(point, 100).get("id", -1))
						if i % 4 == 0: combat._area(1, {}, "", {}, point, 120, 1)
					if tick >= 10: times[k] += Time.get_ticks_usec() - start
				same = same and answers[0] == answers[1] and current.hits == old.hits
			var ratio := float(times[1]) / maxf(1.0, times[0])
			# Report dense/small costs honestly; a sparse large-horde improvement is required.
			if not same or (not dense and count >= 128 and ratio > 0.8): failures += 1
			print("TALENT_QUERY_CPU count=", count, " dense=", dense, " before_us=", times[0] / 40.0, " after_us=", times[1] / 40.0, " ratio=", ratio, " parity=", same)
	print("TALENT_QUERY_CPU_DONE failures=", failures)
	quit(1 if failures else 0)

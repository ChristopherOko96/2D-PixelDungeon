extends "res://scripts/capture_ranger_fields.gd"
## Controlled real status grants in current laboratory, no earned progression claim.
func _start() -> void:
	capture_out = "res://production/qa/evidence/enemy-status"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	await _make(true)
	game.view.set_process(false) # Presentation advances with this fixture's simulation clock.
	game.lab_action("spec", "sniper")
	game.lab_action("auto", false)
	game.lab_action("clear", null)
	game.players[1].pos = Vector2(540, 420)
	var points := [Vector2(700,360), Vector2(840,360), Vector2(980,360), Vector2(700,490), Vector2(840,490)]
	var statuses := [["burn"], ["poison"], ["wet"], ["freeze"], ["poison", "wet"]]
	for n in range(points.size()):
		_foe(points[n])
		var target: Dictionary = game.enemies[-1]
		for kind: String in statuses[n]: game.perk_combat._status(target, kind, 0.01, 10.0, 1)
	await _advance(0.65)
	var seen: Dictionary = {}
	for p: Dictionary in game.view._feedback.particles._particles:
		if p.has("status_kind"): seen[p.status_kind] = true
	if seen.size() != 4:
		printerr("STATUS_CAPTURE_FAIL expected four actual solver effects")
		quit(1)
		return
	await _photo("01-status-overview")
	root.get_texture().get_image().get_region(Rect2i(650,235,430,250)).save_png(capture_out.path_join("01-status-detail.png"))
	await _advance(0.2)
	await _photo("02-status-motion")
	for target: Dictionary in game.enemies: target.statuses.clear()
	await _advance(0.85)
	if game.view._feedback.particles._particles.any(func(p: Dictionary) -> bool: return p.has("status_kind")):
		printerr("STATUS_CAPTURE_FAIL cured effects did not expire")
		quit(1)
		return
	await _photo("03-cleansed")
	print("ENEMY_STATUS_CAPTURE checked=2 failures=0 images=3 statuses_granted_by_host=true training=true")
	game.queue_free()
	await process_frame
	quit()

func _advance(seconds: float) -> void:
	for frame in range(ceili(seconds * 60)):
		_step(1.0 / 60)
		_sync_view()
		game.view._process_view(1.0 / 60)
		await process_frame

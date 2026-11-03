extends SceneTree
const Art = preload("res://src/vfx/soul_guardian_art.gd")
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("SOUL_MOTION_FAIL: ", label)
func _initialize() -> void:
	var text := FileAccess.get_file_as_string("res://assets/data/vfx_talents.json")
	check(text.count('"soul_motion":') == 1, "one unambiguous soul motion configuration")
	var cfg: Dictionary = JSON.parse_string(text).soul_motion
	check(float(cfg.grasp_turns) < 0.75 and float(cfg.field_playback) < 1.0, "ghost motion is calmer without changing CC")
	var samples := Art.aura_samples(2.0, 7, cfg)
	var next := Art.aura_samples(2.0 + 1.0 / 60.0, 7, cfg)
	check(samples.size() == 24, "bounded dust population")
	var fronts := 0
	var moved := 0
	for i in range(samples.size()):
		var a: Dictionary = samples[i]
		var b: Dictionary = next[i]
		if float(a.depth) >= 0.0: fronts += 1
		if Vector2(a.offset) != Vector2(b.offset): moved += 1
		check(float(a.alpha) >= 0.0 and float(a.alpha) <= float(cfg.aura_opacity), "bounded dust alpha")
		check(absf(Vector2(a.offset).x) <= float(cfg.aura_radius), "dust remains near guardian")
		if Vector2(a.offset).distance_to(b.offset) > 5.0:
			check(float(a.alpha) < 0.02 or float(b.alpha) < 0.02, "loop wraps only while faded out")
	check(fronts > 0 and fronts < samples.size(), "aura has particles before and behind body")
	check(moved == samples.size(), "every mote moves between render frames")
	check(samples == Art.aura_samples(2.0, 7, cfg), "aura deterministic and independent of attack phase")
	check(samples != Art.aura_samples(2.0, 8, cfg), "simultaneous guardians have different particle phases")
	print("SOUL_MOTION checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)

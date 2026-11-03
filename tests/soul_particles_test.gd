extends SceneTree
## Shared bones and deterministic, bounded presentation particles.
const Spirit = preload("res://src/rig/soul_spirit_rig.gd")
const Motes = preload("res://src/vfx/soul_fragments.gd")
const Guardian = preload("res://src/rig/soul_guardian_rig.gd")
const Field = preload("res://src/vfx/soul_field.gd")
var checked := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("SOUL_PARTICLES_FAIL: ", label)

func _initialize() -> void:
	Spirit.prepare()
	Guardian.prepare()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vfx_talents.json")).soul_motion
	check(Spirit.rig.get("parts", []).size() == 4, "field ghost has four actual cutout bones")
	var neutral := preload("res://src/rig/rig_poses.gd").blank()
	var origin := Vector2(300, 240)
	var world: Dictionary = Spirit.solver.solve_pose(Spirit.rig, neutral, origin, 1.0, 1.0)
	for part: Dictionary in Spirit.rig.get("parts", []):
		check(Rect2(part.bounds).has_area(), "%s has approved ghost pixels" % part.id)
		check((world[part.id] * Vector2(10, 40)).is_equal_approx(origin), "%s shares the same ground anchor" % part.id)
		var image: Image = part.image
		var hard := true
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha := image.get_pixel(x, y).a
				if alpha > 0.0 and alpha < 1.0: hard = false
		check(hard, "%s keeps native hard pixels" % part.id)
	var head: Image = Spirit.rig.by_id.head.image
	var eyes := 0
	for y in range(head.get_height()):
		for x in range(head.get_width()):
			var pixel := head.get_pixel(x, y)
			if pixel.a >= 0.5 and maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.35: eyes += 1
	check(eyes > 8, "the approved dark ghost eyes survive rig extraction")
	var a: Array = Spirit.field_samples(origin, 115.2, 1.0, cfg)
	var b: Array = Spirit.field_samples(origin, 115.2, 1.0 + 1.0 / 60.0, cfg)
	check(a.size() == 5, "five independently staggered spirit births")
	var phases := {}
	var active_rising := 0
	for index in range(a.size()):
		var ghost: Dictionary = a[index]
		phases[ghost.phase] = true
		check(Vector2(ghost.base).distance_to(origin) < 115.2 * 0.8, "spirit starts inside the authoritative field")
		if float(ghost.alpha) > 0.001:
			check(Vector2(ghost.at) != Vector2(b[index].at), "visible spirit rises between render samples")
			active_rising += 1
		check(float(ghost.alpha) >= 0.0 and float(ghost.alpha) <= 1.0, "birth/death alpha bounded")
	check(phases.size() == a.size(), "spirits do not rise as one repeated sheet")
	check(active_rising > 0, "field has living rising spirits")
	var unborn: Array = Spirit.field_samples(origin, 115.2, 0.0, cfg)
	var all_born_at_surface := true
	for ghost: Dictionary in unborn:
		if not is_zero_approx(float(ghost.phase)): all_born_at_surface = false
	check(all_born_at_surface, "new field starts all spirits at their surface, not pre-aged in midair")
	check(a == Spirit.field_samples(origin, 115.2, 1.0, cfg), "sampling is stable for late snapshots")
	check(float(Spirit.field_samples(origin, 115.2, 0.0, cfg)[0].alpha) == 0.0 and float(Spirit.field_samples(origin, 115.2, 3.39999, cfg)[0].alpha) < 0.001, "spirit cycle wraps while invisible")
	var motes: Array = Field.mote_samples(origin, 115.2, 1.0, cfg)
	var mote_next: Array = Field.mote_samples(origin, 115.2, 1.0 + 1.0 / 60.0, cfg)
	check(motes.size() == 42, "field particle population is bounded")
	var moving_motes := 0
	for i in range(motes.size()):
		if Vector2(motes[i].at) != Vector2(mote_next[i].at): moving_motes += 1
	check(moving_motes == motes.size(), "all field motes move between render samples")
	for part: Dictionary in Guardian.rig.parts:
		if str(part.id) in ["tail_mid", "tail_tip"]: Motes.prepare_part("guardian:" + str(part.id), part)
	var raw: Array = Guardian.draw_parts({"motion": "hover", "face": 1.0}, 0.3, 1.6, 2.0, origin, 2.0)
	var fragmented: Array = Motes.parts(raw, 2.0, "guardian", cfg)
	var next: Array = Motes.parts(raw, 2.0 + 1.0 / 60.0, "guardian", cfg)
	check(fragmented.size() > raw.size() and fragmented.size() < 200, "tail becomes bounded source-pixel fragments")
	var moved := 0
	var stable_head := false
	var texture_ids := {}
	for index in range(fragmented.size()):
		var p: Dictionary = fragmented[index]
		texture_ids[p.texture.get_instance_id()] = true
		if str(p.id) == "head": stable_head = p.transform == raw.filter(func(v: Dictionary) -> bool: return v.id == "head")[0].transform
		if p.transform != next[index].transform: moved += 1
	check(stable_head, "fragmentation leaves the mask and its eyes intact")
	check(moved > 5, "tail fragments float independently of the bones")
	var again: Array = Motes.parts(raw, 2.0, "guardian", cfg)
	check(again == fragmented, "fragment sampling is deterministic and reuses textures")
	var wrap := Motes.sample(0.00001, 0.0, 1.8, 4, 8)
	var wrap_end := Motes.sample(1.79999, 0.0, 1.8, 4, 8)
	check(float(wrap.alpha) < 0.001 and float(wrap_end.alpha) < 0.001, "fragment recycling happens only when invisible")
	print("SOUL_PARTICLES checked=%d failures=%d" % [checked, failures])
	quit(1 if failures else 0)

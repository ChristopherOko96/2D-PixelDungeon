extends SceneTree
## Asset integration contract, separate from subjective anatomy/detail review.
var checked: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checked += 1
	if not value:
		failures += 1
		printerr("ACTOR_DETAIL_FAIL: ",label)
func _initialize() -> void:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/actor_detail_profile.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/actor_animations.json"))
	check(str(catalog.get("visual_revision","")) == str(profile.visual_revision),"the detailed visual revision is the active animation catalog")
	if failures > 0:
		_finish()
		return
	check(catalog.actions.size() == 48 and profile.actors.size() == 8,"48 independent actions and the complete eight-actor roster remain")
	for actor: Dictionary in profile.actors:
		var active: Dictionary = {}
		for candidate: Dictionary in catalog.actors:
			if str(candidate.id) == str(actor.id): active = candidate
		check(not active.is_empty() and float(active.get("render_scale",0)) == float(actor.render_scale),"native32 detail uses the declared integer world scale for "+str(actor.id))
		check(str(active.get("source_root","")) == str(profile.key_root)+str(actor.id)+"/","active animation sources use the new keys")
		for direction: String in profile.directions:
			for pose: String in profile.poses:
				var path: String = str(profile.key_root)+str(actor.id)+"/"+direction+"_"+pose+".png"
				var pixels: Image = Image.new()
				var error: Error = pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
				check(error == OK,"detailed key exists "+path)
				if error != OK: continue
				check(pixels.get_size() == Vector2i(int(actor.canvas[0]),int(actor.canvas[1])),"key has declared native canvas")
				var bounds: Rect2i = pixels.get_used_rect()
				check(bounds.end.y == int(actor.canvas[1])-1,"stable visible foot baseline with one transparent footer")
				if pose == "idle": check(bounds.size.y >= int(actor.idle_height)-3,"body detail is not reduced to the former20px silhouette")
				var colors: Dictionary = {}
				var alpha_ok: bool = true
				for y: int in range(pixels.get_height()):
					for x: int in range(pixels.get_width()):
						var color: Color = pixels.get_pixel(x,y)
						alpha_ok = alpha_ok and (color.a == 0 or color.a == 1)
						if color.a > 0: colors[color.to_rgba32()] = true
				check(alpha_ok,"alpha stays hard under nearest rendering")
				check(colors.size() >= 32 and colors.size() <= int(profile.palette_limit),"detail palette keeps material shades instead of the old20-color bottleneck")
		if str(actor.id) == "boss": check(str(active.name) == "Der Schläfer der Tiefe","the active boss has the new eldritch identity")
	_finish()
func _finish() -> void:
	print("ACTOR_DETAIL checked=%d failures=%d"%[checked,failures])
	quit(0 if failures == 0 else 1)

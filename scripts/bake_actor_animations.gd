extends SceneTree
## Offline nearest-pixel articulated pose baker. Sources are never modified.

const CATALOG: String = "res://assets/data/actor_animations.json"
const PARTS: Array[String] = ["leg_l", "leg_r", "torso", "arm_l", "arm_r", "head"]
const SCRATCH_MARGIN: int = 24
var problems: Array[String] = []
var configuration: Dictionary = {}
var catalog_path: String = CATALOG

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var catalog_index: int = args.find("--catalog")
	if catalog_index >= 0 and catalog_index+1 < args.size() and args[catalog_index+1].begins_with("res://assets/actors/") and args[catalog_index+1].ends_with(".json"):
		catalog_path = args[catalog_index+1]
	configuration = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if configuration.is_empty():
		printerr("ACTOR_BAKE: missing catalog")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/actors/baked"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(configuration.index_path).get_base_dir()))
	var index: Dictionary = {"schema_version": 1, "frames_per_clip": configuration.frames_per_clip,
		"directions": configuration.directions, "action_ids": [], "actors": {}}
	for action: Dictionary in configuration.actions: index.action_ids.append(action.id)
	for actor: Dictionary in configuration.actors:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(actor.atlas).get_base_dir()))
		var baked: Dictionary = _bake_actor(actor)
		if not baked.is_empty(): index.actors[actor.id] = baked
	index["quality_validated"] = problems.is_empty() and index.actors.size() == 8
	index["problems"] = problems
	_write_json(str(configuration.index_path), index)
	_write_json(catalog_path, configuration)
	for problem: String in problems: printerr("ACTOR_BAKE_FAIL: ", problem)
	print("ACTOR_BAKE actors=%d actions=48 directions=4 frames=6 failures=%d" % [index.actors.size(), problems.size()])
	quit(0 if problems.is_empty() else 1)

func _bake_actor(actor: Dictionary) -> Dictionary:
	var sources: Dictionary = {}
	var fingerprints: Dictionary = {}
	var size: Vector2i = Vector2i.ZERO
	for direction: String in configuration.directions:
		sources[direction] = {}
		for pose: String in ["idle", "move", "attack", "hurt"]:
			var path: String = str(actor.source_root) + direction + "_" + pose + ".png"
			if not FileAccess.file_exists(path):
				problems.append("Missing authored key: " + path)
				return {}
			var source: Image = Image.new()
			var source_error: Error = source.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			if source_error != OK or source.is_empty():
				problems.append("Unreadable authored key: " + path)
				return {}
			source.convert(Image.FORMAT_RGBA8)
			if size == Vector2i.ZERO: size = source.get_size()
			if size != source.get_size():
				problems.append("Source canvases differ for " + str(actor.id))
				return {}
			sources[direction][pose] = source
			fingerprints[direction + "_" + pose] = _digest(source.get_data())
	actor.source_size = [size.x, size.y]
	var padding: Vector2i = Vector2i(int(configuration.rig.padding[0]), int(configuration.rig.padding[1]))
	var minimum: Vector2i = size + Vector2i(padding.x * 2, padding.y + 2)
	var anchor: Vector2i = Vector2i(size.x / 2 + padding.x, size.y - 1 + padding.y)
	var scratch: Vector2i = minimum + Vector2i.ONE * SCRATCH_MARGIN * 2
	var all_frames: Array[Dictionary] = []
	var extent: Rect2i = Rect2i(Vector2i.ZERO, minimum)
	var rigs: Dictionary = {}
	for direction: String in configuration.directions:
		var model: Dictionary = _rig_model(sources[direction].idle,actor.get("rig",{}))
		rigs[direction] = {}
		for pose: String in ["idle", "move", "attack", "hurt"]:
			rigs[direction][pose] = _split_layers(sources[direction][pose], model)
	var action_index: int = 0
	for action: Dictionary in configuration.actions:
		var direction_index: int = 0
		for direction: String in configuration.directions:
			for frame: int in range(int(configuration.frames_per_clip)):
				var rig: Dictionary = rigs[direction][_pose_for_actor(actor, str(action.poses[frame]))]
				var picture: Image = _render(rig, action.frames[frame], actor, direction, scratch)
				var used: Rect2i = picture.get_used_rect()
				if used.position.x == 0 or used.position.y == 0 or used.end.x >= scratch.x or used.end.y >= scratch.y:
					problems.append("Scratch bounds exceeded: " + str(actor.id) + "/" + str(action.id))
				var position: Vector2i = used.position - Vector2i.ONE * SCRATCH_MARGIN
				extent = extent.merge(Rect2i(position, used.size))
				all_frames.append({"image": picture.get_region(used), "position": position,
					"action": action.id, "direction": direction, "column": direction_index * 6 + frame, "row": action_index})
			direction_index += 1
		action_index += 1
	var frame_size: Vector2i = extent.size
	var offset: Vector2i = -extent.position
	anchor += offset
	actor.frame_size = [frame_size.x, frame_size.y]
	actor.anchor = [anchor.x, anchor.y]
	var atlas_size: Vector2i = Vector2i(frame_size.x * 24, frame_size.y * 48)
	var atlas: Image = Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	var clips: Dictionary = {}
	var signatures: Dictionary = {}
	var frame_hashes: Dictionary = {}
	for direction: String in configuration.directions: signatures[direction] = {}
	for entry: Dictionary in all_frames:
		var action: String = str(entry.action)
		var direction: String = str(entry.direction)
		if not clips.has(action):
			clips[action] = {}
			frame_hashes[action] = {}
		if not clips[action].has(direction):
			clips[action][direction] = {"bounds": [], "distinct_frames": 0, "sequence_sha256": ""}
			frame_hashes[action][direction] = []
		var position: Vector2i = entry.position + offset
		var picture: Image = entry.image
		atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), position + Vector2i(int(entry.column) * frame_size.x, int(entry.row) * frame_size.y))
		var pixels: Image = Image.create(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
		pixels.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), position)
		frame_hashes[action][direction].append(_digest(pixels.get_data()))
		clips[action][direction].bounds.append([position.x, position.y, picture.get_width(), picture.get_height()])
	for action: String in clips:
		for direction: String in clips[action]:
			var hashes: Array = frame_hashes[action][direction]
			var distinct: Dictionary = {}
			for hash_value: String in hashes: distinct[hash_value] = true
			var sequence: String = "|".join(hashes).sha256_text()
			clips[action][direction].distinct_frames = distinct.size()
			clips[action][direction].sequence_sha256 = sequence
			if distinct.size() < 3: problems.append("Fewer than three poses: " + str(actor.id) + "/" + action + "/" + direction)
			if signatures[direction].has(sequence): problems.append("Aliased sequences: " + str(actor.id) + "/" + direction + "/" + action + " and " + str(signatures[direction][sequence]))
			signatures[direction][sequence] = action
	var atlas_result: Error = atlas.save_png(str(actor.atlas))
	var flash: Image = _white_atlas(atlas)
	var flash_result: Error = flash.save_png(str(actor.flash_atlas))
	if atlas_result != OK or flash_result != OK: problems.append("Cannot write atlas pair for " + str(actor.id))
	print("ACTOR_BAKED %s source=%s frame=%s atlas=%s pair_bytes=%d" % [actor.id, str(size), str(frame_size), str(atlas_size), atlas_size.x * atlas_size.y * 8])
	return {"source_size": [size.x, size.y], "frame_size": [frame_size.x, frame_size.y], "anchor": [anchor.x, anchor.y],
		"render_scale": actor.render_scale, "base_feet": actor.base_feet, "atlas": actor.atlas,
		"flash_atlas": actor.flash_atlas, "atlas_size": [atlas_size.x, atlas_size.y], "raw_pair_bytes": atlas_size.x * atlas_size.y * 8,
		"source_sha256s": fingerprints, "clips": clips}

func _rig_model(idle: Image, actor_rig: Dictionary = {}) -> Dictionary:
	var bounds: Rect2i = idle.get_used_rect()
	var head_end: float = bounds.position.y + bounds.size.y * float(actor_rig.get("head_end",configuration.rig.head_end))
	var waist: float = bounds.position.y + bounds.size.y * float(actor_rig.get("waist",configuration.rig.waist))
	var weighted_x: float = 0.0
	var weight: int = 0
	for y: int in range(bounds.position.y, ceili(head_end)):
		for x: int in range(bounds.position.x, bounds.end.x):
			if idle.get_pixel(x, y).a > 0.5:
				weighted_x += x
				weight += 1
	var center: float = weighted_x / maxf(1.0, weight)
	var core: float = minf(bounds.size.x * float(actor_rig.get("torso_half_width",configuration.rig.torso_half_width)), bounds.size.y * 0.22)
	core = maxf(core, 2.0)
	return {"center": center, "head_end": head_end, "waist": waist, "core": core, "top": bounds.position.y,
		"head_mask": _idle_head_mask(idle, center, head_end),
		"pivots": {"head": Vector2(center, head_end), "torso": Vector2(center, head_end + 1),
		"arm_l": Vector2(center - core, head_end), "arm_r": Vector2(center + core, head_end),
		"leg_l": Vector2(center - core * 0.5, waist), "leg_r": Vector2(center + core * 0.5, waist)}}

## Keep connected horns/hat with the head while excluding raised outer hands.
func _idle_head_mask(idle: Image, center: float, head_end: float) -> Image:
	var mask: Image = Image.create(idle.get_width(), idle.get_height(), false, Image.FORMAT_RGBA8)
	var seed: Vector2i = Vector2i(-1, -1)
	var best: float = INF
	var target: Vector2 = Vector2(center, head_end - 1)
	for y: int in range(ceili(head_end)):
		for x: int in range(idle.get_width()):
			if idle.get_pixel(x,y).a < 0.5: continue
			var distance: float = Vector2(x,y).distance_squared_to(target)
			if distance < best:
				seed = Vector2i(x,y)
				best = distance
	if seed.x < 0: return mask
	var visited: Dictionary = {seed:true}
	var queue: Array[Vector2i] = [seed]
	var cursor: int = 0
	while cursor < queue.size():
		var point: Vector2i = queue[cursor]
		cursor += 1
		for dy: int in range(-1,2):
			for dx: int in range(-1,2):
				var adjacent: Vector2i = point + Vector2i(dx,dy)
				if adjacent.x < 0 or adjacent.y < 0 or adjacent.x >= idle.get_width() or adjacent.y >= ceili(head_end): continue
				# A one-pixel margin accommodates key-art head shifts, not limbs.
				mask.set_pixelv(adjacent,Color.WHITE)
				if visited.has(adjacent) or idle.get_pixelv(adjacent).a < 0.5: continue
				visited[adjacent] = true
				queue.append(adjacent)
	return mask

## Per-actor key substitution preserves weapon hand without changing sources.
func _pose_for_actor(actor: Dictionary, pose: String) -> String:
	return str(actor.get("pose_remap", {}).get(pose, pose))

func _split_layers(source: Image, model: Dictionary) -> Dictionary:
	var layers: Dictionary = {}
	var neck_overlap: float = float(configuration.rig.neck_overlap)
	var arm_overlap: float = float(configuration.rig.arm_overlap)
	for part: String in PARTS: layers[part] = Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var color: Color = source.get_pixel(x, y)
			if color.a < 0.5: continue
			var far_side: bool = absf(x - float(model.center)) > float(model.core) + 1
			var arm_side: String = "arm_l" if x < float(model.center) else "arm_r"
			if y < float(model.head_end):
				if far_side and model.head_mask.get_pixel(x,y).a < 0.5: layers[arm_side].set_pixel(x, y, color)
				else: layers.head.set_pixel(x, y, color)
				if y >= float(model.head_end) - neck_overlap and not far_side: layers.torso.set_pixel(x, y, color)
			elif y < float(model.waist):
				if far_side: layers[arm_side].set_pixel(x, y, color)
				else: layers.torso.set_pixel(x, y, color)
				if y < float(model.head_end) + neck_overlap and not far_side: layers.head.set_pixel(x, y, color)
				if absf(x - float(model.center)) >= float(model.core) + 1 - arm_overlap:
					layers[arm_side].set_pixel(x, y, color)
			else:
				var leg: String = "leg_l" if x < float(model.center) else "leg_r"
				if far_side: layers[arm_side].set_pixel(x, y, color)
				else: layers[leg].set_pixel(x, y, color)
				if y < float(model.waist) + neck_overlap and not far_side: layers.torso.set_pixel(x, y, color)
	return {"layers": layers, "model": model}

func _render(rig: Dictionary, frame: Dictionary, actor: Dictionary, direction: String, size: Vector2i) -> Image:
	var result: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var model: Dictionary = rig.model
	var motion_scale: float = maxf(1.0, float(actor.source_size[1]) / 32.0)
	var handedness: float = -1.0 if direction == "west" else 1.0
	var root_pivot: Vector2 = Vector2(float(model.center), float(model.waist))
	var root: Transform2D = _transform(frame.root, root_pivot, motion_scale, handedness, 1.0)
	var padding: Transform2D = Transform2D(0.0, Vector2(float(configuration.rig.padding[0]) + SCRATCH_MARGIN, float(configuration.rig.padding[1]) + SCRATCH_MARGIN))
	for part: String in PARTS:
		var rotation_scale: float = float(actor.get("arm_rotation_scale", 1.0)) if part.begins_with("arm_") else 1.0
		var local: Transform2D = _transform(frame[part], model.pivots[part], motion_scale, handedness, rotation_scale)
		_draw_layer(result, rig.layers[part], padding * root * local)
	return result

func _transform(values: Array, pivot: Vector2, motion_scale: float, handedness: float, rotation_scale: float) -> Transform2D:
	var angle: float = deg_to_rad(float(values[2]) * handedness * rotation_scale)
	var scale: Vector2 = Vector2(float(values[3]), float(values[4]))
	var offset: Vector2 = Vector2(float(values[0]) * handedness, float(values[1])) * motion_scale
	return Transform2D(angle, scale, 0.0, pivot + offset) * Transform2D(0.0, -pivot)

func _draw_layer(destination: Image, source: Image, transform: Transform2D) -> void:
	var bounds: Rect2i = source.get_used_rect()
	if not bounds.has_area(): return
	var corners: Array[Vector2] = [Vector2(bounds.position), Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.end), Vector2(bounds.position.x, bounds.end.y)]
	var first: Vector2 = transform * corners[0]
	var left: float = first.x
	var right: float = first.x
	var top: float = first.y
	var bottom: float = first.y
	for corner: Vector2 in corners:
		var point: Vector2 = transform * corner
		left = minf(left, point.x)
		right = maxf(right, point.x)
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var inverse: Transform2D = transform.affine_inverse()
	for y: int in range(maxi(0, floori(top) - 1), mini(destination.get_height(), ceili(bottom) + 1)):
		for x: int in range(maxi(0, floori(left) - 1), mini(destination.get_width(), ceili(right) + 1)):
			var original: Vector2 = inverse * Vector2(x + 0.5, y + 0.5)
			var source_x: int = floori(original.x)
			var source_y: int = floori(original.y)
			if source_x < 0 or source_y < 0 or source_x >= source.get_width() or source_y >= source.get_height(): continue
			var color: Color = source.get_pixel(source_x, source_y)
			if color.a >= 0.5: destination.set_pixel(x, y, color)

func _white_atlas(source: Image) -> Image:
	var data: PackedByteArray = source.get_data()
	for pixel: int in range(0, data.size(), 4):
		if data[pixel + 3] > 0:
			data[pixel] = 255
			data[pixel + 1] = 255
			data[pixel + 2] = 255
	return Image.create_from_data(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8, data)

func _digest(data: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func _write_json(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		problems.append("Cannot write " + path)
		return
	file.store_string(JSON.stringify(value, "\t") + "\n")

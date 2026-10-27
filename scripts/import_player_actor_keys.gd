extends SceneTree
## Deterministically imports the four preserved Imagegen player key-pose sheets.
## Run with the pinned Godot binary; this is an offline asset tool, not gameplay.

const SOURCE_ROOT: String = "res://assets/actors/source/"
const KEY_ROOT: String = "res://assets/actors/keys/"
const ACTORS: Array[String] = ["player_warden", "player_ranger", "player_arcanist", "player_lizard"]
const DIRECTIONS: Array[String] = ["south", "east", "north", "west"]
const POSES: Array[String] = ["idle", "move", "attack", "hurt"]
const CANVAS_SIZE: Vector2i = Vector2i(24, 32)
const FOOT_END_Y: int = 31
const ALPHA_THRESHOLD: float = 0.6
const SHARED_PALETTE: Array[Color] = [
	Color("191426"), Color("30243e"), Color("4b3b59"), Color("67556e"),
	Color("95839a"), Color("b7a48a"), Color("d8c2a0"), Color("f2dfb7"),
	Color("fff0ce"), Color("51372d"), Color("775135"), Color("a17143"),
	Color("615665"), Color("96909b"), Color("c8c3cc"), Color("f0e8ee")]
const ACTOR_PALETTES: Dictionary = {
	"player_warden": [Color("164948"), Color("28716a"), Color("55a898"), Color("72dcc8")],
	"player_ranger": [Color("79532b"), Color("a97637"), Color("edb563"), Color("ffdc83")],
	"player_arcanist": [Color("43344f"), Color("70527f"), Color("9b76b3"), Color("bc91de")],
	"player_lizard": [Color("6c3547"), Color("a95362"), Color("ce7481"), Color("ed8a91")]
}

var failed: bool = false
var imported_count: int = 0

func _initialize() -> void:
	for actor: String in ACTORS:
		_import_actor(actor)
	print("PLAYER_KEYS_IMPORTED actors=4 keys=", imported_count, " canvas=24x32 foot_end_y=31 hard_alpha=true result=", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _import_actor(actor: String) -> void:
	var source_path: String = SOURCE_ROOT + actor + "_poses_sheet.png"
	var source: Image = Image.load_from_file(source_path)
	if source == null:
		_fail("Missing source: " + source_path)
		return
	source.convert(Image.FORMAT_RGBA8)
	var bounds_list: Array[Rect2i] = []
	var idle_maximum: Vector2i = Vector2i.ONE
	for row: int in range(4):
		for column: int in range(4):
			var bounds: Rect2i = _alpha_bounds(source, _cell(source, column, row))
			if bounds.size.x <= 0 or bounds.size.y <= 0:
				_fail("Empty source cell: " + actor + " " + str(column) + "," + str(row))
				return
			bounds_list.append(bounds)
			if row == 0:
				idle_maximum.x = maxi(idle_maximum.x, bounds.size.x)
				idle_maximum.y = maxi(idle_maximum.y, bounds.size.y)
	# Derive the actor scale only from idle. Attack width uses the padded canvas.
	# A tail or broad hat is not body size: give every idle the same 20px height.
	# Width may use the padding instead of shrinking the reptile or the wizard.
	var actor_scale: float = 20.0 / idle_maximum.y
	print("PLAYER_KEYS_SOURCE ", actor, " idle_maximum=", idle_maximum, " scale=", actor_scale)
	var palette: Array[Color] = SHARED_PALETTE.duplicate()
	for color: Color in ACTOR_PALETTES[actor]:
		palette.append(color)
	var directory: String = KEY_ROOT + actor + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var contact: Image = Image.create(96, 128, false, Image.FORMAT_RGBA8)
	contact.fill(Color.TRANSPARENT)
	var frames: Array[Dictionary] = []
	var unique_hashes: Dictionary = {}
	for row: int in range(4):
		for column: int in range(4):
			var bounds: Rect2i = bounds_list[row * 4 + column]
			var crop: Image = source.get_region(bounds)
			var source_foot_x: float = _foot_center(crop)
			var target_size: Vector2i = Vector2i(maxi(1, roundi(bounds.size.x * actor_scale)), maxi(1, roundi(bounds.size.y * actor_scale)))
			if target_size.x > CANVAS_SIZE.x or target_size.y > FOOT_END_Y:
				_fail("Pose exceeds padded canvas: " + actor + " " + DIRECTIONS[column] + "_" + POSES[row] + " " + str(target_size) + " source=" + str(bounds))
				return
			crop.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
			_palette_map(crop, palette)
			var projected_bounds: Rect2i = crop.get_used_rect()
			var intended_x: int = roundi(12.0 - source_foot_x * actor_scale)
			var target_x: int = clampi(intended_x, 0, CANVAS_SIZE.x - target_size.x)
			var target_y: int = FOOT_END_Y - projected_bounds.end.y
			var canvas: Image = Image.create(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, target_size), Vector2i(target_x, target_y))
			var name: String = DIRECTIONS[column] + "_" + POSES[row]
			var output: String = directory + name + ".png"
			if not _validate(canvas, actor + "/" + name):
				return
			if canvas.save_png(output) != OK:
				_fail("Could not save " + output)
				return
			var digest: String = canvas.get_data().hex_encode().sha256_text()
			unique_hashes[digest] = true
			imported_count += 1
			contact.blit_rect(canvas, Rect2i(Vector2i.ZERO, CANVAS_SIZE), Vector2i(column * 24, row * 32))
			var used: Rect2i = canvas.get_used_rect()
			frames.append({"key": name, "source_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "projected_size": [target_size.x, target_size.y], "origin": [target_x, target_y], "foot_anchor_clamped": target_x != intended_x, "used_rect": [used.position.x, used.position.y, used.size.x, used.size.y], "rgba_sha256": digest})
	contact.save_png(directory + "preview_contact.png")
	contact.resize(576, 768, Image.INTERPOLATE_NEAREST)
	contact.save_png(directory + "preview_zoom.png")
	var report: Dictionary = {"actor": actor, "source": source_path, "source_grid": [4, 4], "source_size": [source.get_width(), source.get_height()], "canvas": [24, 32], "nominal_idle_height": 20, "foot_end_y": FOOT_END_Y, "uniform_scale_from_idle": actor_scale, "source_direction_order": DIRECTIONS, "source_pose_order": POSES, "palette_colors": palette.size(), "unique_key_images": unique_hashes.size(), "mirrored_directions": [], "keys": frames}
	var report_file: FileAccess = FileAccess.open(directory + "import_report.json", FileAccess.WRITE)
	if report_file == null:
		_fail("Could not save import report for " + actor)
	else:
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PLAYER_KEYS_ACTOR ", actor, " scale=", actor_scale, " unique=", unique_hashes.size(), "/16")

func _cell(source: Image, column: int, row: int) -> Rect2i:
	var left: int = roundi(column * source.get_width() / 4.0)
	var right: int = roundi((column + 1) * source.get_width() / 4.0)
	var top: int = roundi(row * source.get_height() / 4.0)
	var bottom: int = roundi((row + 1) * source.get_height() / 4.0)
	return Rect2i(left, top, right - left, bottom - top)

func _alpha_bounds(source: Image, cell: Rect2i) -> Rect2i:
	# A long neighbouring staff can cross the equal cell boundary. Select the
	# largest connected actor silhouette, excluding bleed and detached VFX dots.
	var region: Image = source.get_region(cell)
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(cell.size.x * cell.size.y)
	var largest_count: int = 0
	var largest_bounds: Rect2i = Rect2i()
	for local_y: int in range(cell.size.y):
		for local_x: int in range(cell.size.x):
			var start_index: int = local_y * cell.size.x + local_x
			if visited[start_index] != 0:
				continue
			visited[start_index] = 1
			if region.get_pixel(local_x, local_y).a < ALPHA_THRESHOLD:
				continue
			var pending: Array[Vector2i] = [Vector2i(local_x, local_y)]
			var minimum: Vector2i = Vector2i(local_x, local_y)
			var maximum: Vector2i = minimum
			var count: int = 0
			while not pending.is_empty():
				var point: Vector2i = pending.pop_back()
				count += 1
				minimum.x = mini(minimum.x, point.x)
				minimum.y = mini(minimum.y, point.y)
				maximum.x = maxi(maximum.x, point.x)
				maximum.y = maxi(maximum.y, point.y)
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var neighbour: Vector2i = point + Vector2i(dx, dy)
						if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= cell.size.x or neighbour.y >= cell.size.y:
							continue
						var index: int = neighbour.y * cell.size.x + neighbour.x
						if visited[index] != 0:
							continue
						visited[index] = 1
						if region.get_pixelv(neighbour).a >= ALPHA_THRESHOLD:
							pending.append(neighbour)
			if count > largest_count:
				largest_count = count
				largest_bounds = Rect2i(cell.position + minimum, maximum - minimum + Vector2i.ONE)
	return largest_bounds

func _foot_center(crop: Image) -> float:
	var total_x: float = 0.0
	var count: int = 0
	for y: int in range(floori(crop.get_height() * 0.9), crop.get_height()):
		for x: int in range(crop.get_width()):
			if crop.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				total_x += x + 0.5
				count += 1
	return total_x / count if count > 0 else crop.get_width() * 0.5

func _palette_map(source: Image, palette: Array[Color]) -> void:
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var color: Color = source.get_pixel(x, y)
			if color.a < ALPHA_THRESHOLD:
				source.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var closest: Color = palette[0]
			var distance: float = INF
			for candidate: Color in palette:
				var difference: float = pow(color.r - candidate.r, 2) + pow(color.g - candidate.g, 2) + pow(color.b - candidate.b, 2)
				if difference < distance:
					distance = difference
					closest = candidate
			source.set_pixel(x, y, closest)

func _validate(canvas: Image, label: String) -> bool:
	var used: Rect2i = canvas.get_used_rect()
	if used.size == Vector2i.ZERO or used.end.y != FOOT_END_Y:
		_fail("Invalid foot alignment: " + label + " " + str(used))
		return false
	for y: int in range(CANVAS_SIZE.y):
		for x: int in range(CANVAS_SIZE.x):
			var alpha: float = canvas.get_pixel(x, y).a
			if alpha != 0.0 and alpha != 1.0:
				_fail("Soft alpha: " + label)
				return false
	return true

func _fail(message: String) -> void:
	failed = true
	printerr("PLAYER_KEYS_IMPORT_FAIL ", message)

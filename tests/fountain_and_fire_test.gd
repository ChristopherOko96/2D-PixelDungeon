extends SceneTree
## The fountain and the moving fires of the story worlds:
## - the fountain fills every class's resource to the top (Mana, Ausdauer, Zorn) and resets every
##   cooldown: talents, the global cooldown, companion abilities, the guard and the Shift defense
##   (src/combat/talent_combat.gd refill);
## - a fire's pictures change only its flame (stone and snow stay), a fountain's only its water
##   (src/vfx/fire_anim.gd), and fires at different places run at different points of the loop.

const Game = preload("res://src/game.gd")
const FireAnim = preload("res://src/vfx/fire_anim.gd")
var checked := 0
var failures: Array[String] = []
var game
var tc


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("FOUNTAIN_FIRE_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _start()
	for class_id: String in ["mage", "archer", "swordsman"]:
		test_fountain_fills_and_resets(class_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	test_fire_moves_only_its_flame()
	test_flame_shape_moves_from_a_still_base()
	test_water_moves_only_its_water()
	test_fires_do_not_flicker_in_step()
	print("FOUNTAIN_FIRE checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _start() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://fountain_fire_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	game.players[1].max_hp = 999
	game.players[1].hp = 999


func test_fountain_fills_and_resets(class_id: String) -> void:
	# Arrange: an emptied hero with every kind of cooldown running
	var player: Dictionary = game.players[1]
	player.class_id = class_id
	tc.reset(3)
	tc.set_build(1, {"class": class_id, "level": 30, "ranks": {}, "bar": []})
	var rt: Dictionary = tc.runtime(1)
	rt.res = 0.0
	rt.cds = {"any_talent": 12.0}
	rt.gcd = 1.0
	rt.pet_cds = {"bite": 8.0}
	rt.guard_cd = 5.0
	var guard: Dictionary = rt.defense
	if not guard.is_empty():
		guard.left = 0.0
		guard.broken = 3.0
	# Act
	var done: bool = tc.refill(1)
	# Assert
	var res_name := str(tc.data.resources[class_id].name)
	check(done, "%s: the fountain takes effect" % class_id)
	check(is_equal_approx(float(rt.res), float(rt.res_max)), "%s: %s is full" % [class_id, res_name])
	check((rt.cds as Dictionary).is_empty() and float(rt.gcd) == 0.0, "%s: talent and global cooldowns reset" % class_id)
	check((rt.pet_cds as Dictionary).is_empty() and float(rt.guard_cd) == 0.0, "%s: companion and guard cooldowns reset" % class_id)
	if not guard.is_empty():
		check(float(guard.left) == float(guard.max) and float(guard.broken) == 0.0, "%s: the Shift defense is ready again" % class_id)


## A small burning bowl: grey stone below, white snow on its rim, an orange flame with a
## near-white core above.
static func _bowl() -> Image:
	var im := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	for y in range(10, 16):
		for x in range(12):
			im.set_pixel(x, y, Color(0.4, 0.4, 0.45))   # stone
	for x in range(12):
		im.set_pixel(x, 10, Color(0.92, 0.94, 0.97))      # snow on the rim
	for y in range(2, 10):
		for x in range(3, 9):
			im.set_pixel(x, y, Color(1.0, 0.55, 0.1))     # flame
	im.set_pixel(5, 6, Color(1, 0.97, 0.9))             # its core
	return im


func test_fire_moves_only_its_flame() -> void:
	# Arrange
	var spec: Dictionary = FireAnim.new().cfg.fire
	var im := _bowl()
	# Act
	var pics := FireAnim.fire_frames(im, spec, 8)
	# Assert
	check(pics.size() == 8, "a fire gets its pictures")
	var flame_moves := false
	var still := true
	for pic: Image in pics:
		for y in range(16):
			for x in range(12):
				var changed: bool = not pic.get_pixel(x, y).is_equal_approx(im.get_pixel(x, y))
				if y < 10 and x >= 3 and x < 9 and changed:
					flame_moves = true
				if y >= 10 and changed:
					still = false
	check(flame_moves, "the flame burns: its pixels change")
	check(still, "the stone and the snow on the rim stay as drawn")
	check(FireAnim.fire_frames(Image.create(8, 8, false, Image.FORMAT_RGBA8), spec, 8).is_empty(), "a sprite without a flame gets no pictures")


func test_flame_shape_moves_from_a_still_base() -> void:
	# Arrange: the bowl's flame fills rows 2..9 (8 rows), its lowest static_share stays
	var spec: Dictionary = FireAnim.new().cfg.fire
	var im := _bowl()
	var still_rows := int(ceil(float(spec.static_share) * 8.0))
	# Act
	var pics := FireAnim.fire_frames(im, spec, 8)
	var regions := FireAnim.flame_regions(FireAnim.flame_mask(im, spec), 12, 16, spec, 1, im)
	# Assert
	var reshaped := false
	var base_still := true
	for pic: Image in pics:
		for y in range(16):
			for x in range(12):
				# there at all (the licking edge only fades a pixel, to 0.15 at the least)
				var was := im.get_pixel(x, y).a > 0.1
				var now := pic.get_pixel(x, y).a > 0.1
				if y <= 9 - still_rows and was != now:
					reshaped = true
				if y > 9 - still_rows and y <= 9 and was != now:
					base_still = false
	check(regions.size() == 1, "the bowl has one flame whose shape moves")
	check(reshaped, "the flame's shape moves: it curls and grows, pixels come and go above its base")
	check(base_still, "the flame's base stays in its bowl")
	# a flame painted into a solid stone niche (no air around it): its moves never punch a hole
	var niche := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	niche.fill(Color(0.35, 0.33, 0.38))
	for y in range(6, 18):
		for x in range(8, 16):
			niche.set_pixel(x, y, Color(1.0, 0.5, 0.1))
	var holes := 0
	var stone_hit := 0
	for pic: Image in FireAnim.fire_frames(niche, spec, 8):
		for y in range(24):
			for x in range(24):
				if pic.get_pixel(x, y).a < 0.1:
					holes += 1
				var was_stone := not (x >= 8 and x < 16 and y >= 6 and y < 18)
				if was_stone and not pic.get_pixel(x, y).is_equal_approx(niche.get_pixel(x, y)):
					stone_hit += 1
	check(holes == 0, "a flame in a solid niche never opens a hole into the sprite (%d holes)" % holes)
	check(stone_hit == 0, "and the moved flame never paints over the stone around it (%d px)" % stone_hit)


func test_water_moves_only_its_water() -> void:
	# Arrange: a grey basin with a blue jet in the middle
	var spec: Dictionary = FireAnim.new().cfg.water
	var im := Image.create(10, 14, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.35, 0.36, 0.4))
	for y in range(14):
		for x in range(4, 6):
			im.set_pixel(x, y, Color(0.2, 0.55, 0.95))
	# Act
	var pics := FireAnim.water_frames(im, spec, 8)
	# Assert
	var water_moves := false
	var basin_still := true
	for pic: Image in pics:
		for y in range(14):
			for x in range(10):
				var changed: bool = not pic.get_pixel(x, y).is_equal_approx(im.get_pixel(x, y))
				if x in [4, 5] and changed:
					water_moves = true
				elif x not in [4, 5] and changed:
					basin_still = false
	check(pics.size() == 8 and water_moves, "the fountain's water flows")
	check(basin_still, "the basin's stone stays as drawn")


func test_fires_do_not_flicker_in_step() -> void:
	# Arrange
	var anim := FireAnim.new()
	anim.build({"brazier_bowl": ImageTexture.create_from_image(_bowl())})
	# Act: the picture of two bowls at different places, at the same moment
	var pairs := 0
	for k in range(20):
		var t := k * 0.37
		if anim.frame("brazier_bowl", Vector2(100, 200), t) != anim.frame("brazier_bowl", Vector2(740, 520), t):
			pairs += 1
	# Assert
	check(anim.has("brazier_bowl") and not anim.has("barrel_a"), "only the listed fire sprites move")
	check(pairs > 0, "two fires at different places are at different points of their loop")

extends SceneTree
## Hell rigs in RigRenderer (src/rig/rig_renderer.gd), on a tiny synthetic
## layered drake rig drawn inside a real draw pass: the drake attack mapping,
## uid keys, flying, tint and alpha reaching every drawn colour and the shadow
## (spied through draw_log), the hit flash on the struck part only, glowing
## stumps at severed joints (children of a lost part vanish with it), a
## stagger on every cut, debris and chips in the rig's material from the gore
## table (vfx_gore.json), world_point following the pose, the tail whirl's
## spin, the death shedding wings/jaw/tail, a new form (same uid) or a figure
## back from dying starting complete; and the crypt's void rig still draws as
## before.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const GORE := "res://assets/data/vfx_gore.json"
const W := 24
const H := 20
const AT := Vector2(400, 300)
## Source point at the tip of the synthetic jaw.
const MOUTH := Vector2(21, 7)

var checked := 0
var failures: Array[String] = []
var _rigs: RefCounted
var _canvas: Node2D
var _pending: Dictionary = {}


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_RIG_RENDERER_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var library = RigLibrary.new()
	library.load_data()
	library.rigs["test_ember"] = _rig("3", "ember")
	library.rigs["test_obsidian"] = _rig("4", "obsidian")
	library.ready = true
	_rigs = RigRenderer.new(library)
	_canvas = Node2D.new()
	root.add_child(_canvas)
	_canvas.draw.connect(_on_draw)
	_test_mapping(library)
	await _test_keys_flags_and_flash()
	await _test_tint_and_alpha_reach_the_canvas()
	await _test_stumps_and_debris()
	await _test_cut_staggers()
	await _test_world_point()
	await _test_whirl_turns()
	await _test_death()
	await _test_new_form_starts_complete()
	await _test_crypt_void(library)
	await _test_size_cut_shadow_and_transforms()
	_test_palette_from_gore_table()
	print("HELL_RIG_RENDERER checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# ------------------------------------------------------------------ fixtures

## One full-frame layer: an opaque rect in `color`, its white silhouette.
func _layer(rect: Rect2i, color: Color) -> Dictionary:
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	image.fill_rect(rect, color)
	var white := Image.create(W, H, false, Image.FORMAT_RGBA8)
	white.fill_rect(rect, Color.WHITE)
	return {"texture": ImageTexture.create_from_image(image), "white": ImageTexture.create_from_image(white), "image": image,
		"bounds": Rect2(rect), "center": Vector2(rect.position) + Vector2(rect.size) * 0.5, "size": Vector2(W, H)}


## A small drake (facing right, 24x20 source px) in the layered builder's
## shape: one full-frame layer per part, flipbook flames, a material.
func _rig(variant: String, material: String) -> Dictionary:
	# [id, rect, pivot, parent, z]
	var specs: Array = [
		["body", Rect2i(6, 8, 10, 6), Vector2(11, 14), "", 10],
		["neck", Rect2i(15, 5, 3, 5), Vector2(16, 9), "body", 12],
		["throat", Rect2i(17, 7, 1, 2), Vector2(17, 8), "neck", 13],
		["head", Rect2i(17, 3, 5, 3), Vector2(17, 5), "neck", 14],
		["jaw", Rect2i(18, 6, 4, 2), Vector2(18, 6), "head", 13],
		["horns", Rect2i(17, 1, 2, 2), Vector2(18, 3), "head", 15],
		["arm", Rect2i(14, 14, 2, 5), Vector2(14, 14), "body", 15],
		["leg_far", Rect2i(8, 14, 2, 6), Vector2(8, 14), "body", 5],
		["leg_near", Rect2i(10, 14, 2, 6), Vector2(10, 14), "body", 16],
		["tail_1", Rect2i(3, 11, 4, 2), Vector2(6, 11), "body", 8],
		["tail_2", Rect2i(1, 12, 3, 2), Vector2(3, 12), "tail_1", 8],
		["wing_far", Rect2i(8, 2, 5, 6), Vector2(12, 8), "body", 4],
		["wing_near", Rect2i(9, 3, 5, 6), Vector2(13, 8), "body", 18],
	]
	var parts: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var colors: Array = [Color("8a2a14"), Color("c24a1c"), Color("e07a2c")] if material == "ember" else [Color("1a1424"), Color("2c2238"), Color("4a3a5e")]
	for i in range(specs.size()):
		var spec: Array = specs[i]
		var part := _layer(spec[1], colors[i % colors.size()])
		part.merge(_fields(spec[0], spec[2], spec[3], spec[4]), true)
		parts.append(part)
	# Flipbook flames on the jaw (decorative) and the tail tip.
	for flame: Array in [["mouth_flame", Vector2i(22, 6), Vector2(22, 6), "jaw", 17], ["tail_flame", Vector2i(0, 12), Vector2(1, 13), "tail_2", 9]]:
		var frames: Array[Dictionary] = []
		for k in range(4): frames.append(_layer(Rect2i(flame[1] + Vector2i(0, -(k % 2)), Vector2i(2, 2)), Color("ffb347")))
		var part: Dictionary = frames[0].duplicate()
		part.merge(_fields(flame[0], flame[2], flame[3], flame[4]), true)
		part.frames = frames
		parts.append(part)
	for part: Dictionary in parts: by_id[part.id] = part
	return {"name": "test_" + material, "family": "drake", "variant": variant, "ground": Vector2(11, 19), "width": 12.0, "center": Vector2(12, 11),
		"top": 1.0, "hover": 0.0, "size": Vector2(W, H), "parts": parts, "items": [], "by_id": by_id, "scale": 5.0, "material": material,
		"groups": {"wings": {"parts": ["wing_far", "wing_near"], "disables": ["bombenflug"]}}, "points": {"mouth": {"part": "jaw", "at": MOUTH}}}


func _fields(id: String, pivot: Vector2, parent: String, z: int) -> Dictionary:
	return {"id": id, "pivot": pivot, "parent": parent, "z": z, "hp": 10.0, "label": id, "vital": false, "disables": [], "weakens": {}, "group": "",
		"regrow": 0.0, "also_detach": [], "exposed": "", "unbreakable": id in ["body", "neck", "head", "leg_far", "leg_near"], "is_item": false}


func _enemy(rig: String, uid: int, extra: Dictionary = {}) -> Dictionary:
	var enemy := {"rig": rig, "uid": uid, "id": "drache%d" % uid, "x": AT.x, "y": AT.y, "face": 1.0, "hits": 0, "lost": [], "dying_p": -1.0, "hit_flash": 0.0}
	enemy.merge(extra, true)
	return enemy


func _on_draw() -> void:
	if _pending.has("enemy"): _pending.top = _rigs.draw_enemy(_canvas, _pending.enemy, AT)


## Draws one enemy inside the canvas's own draw pass; returns draw_enemy's top.
func _draw(enemy: Dictionary) -> float:
	_pending = {"enemy": enemy, "top": NAN}
	_canvas.queue_redraw()
	await process_frame
	await process_frame
	var top: float = _pending.top
	_pending = {}
	return top


func _in(color: Color, palette: Array) -> bool:
	for c: Color in palette:
		if color.is_equal_approx(c): return true
	return false


## The gore table's material entry (vfx_gore.json), read independently of the renderer.
func _gore(material: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GORE))
	return parsed.get("materials", {}).get(material, {}) if parsed is Dictionary else {}


# ------------------------------------------------------------------ tests

func _test_mapping(library: RefCounted) -> void:
	# Arrange
	var drake: Dictionary = library.rig("test_ember")
	var expected := {"bolt": ["bite", 0.55, 0.7], "slam": ["slam", 0.4, 0.6], "dash": ["dash", 0.35, 0.6], "burrow": ["burrow", 0.5, 0.7],
		"swing": ["swing", 0.3, 0.8], "sweep": ["sweep", 0.3, 0.9], "ring": ["roar", 0.45, 0.65], "echoes": ["roar", 0.45, 0.65],
		"beam": ["beam", 0.3, 0.9], "flight": ["flight", 0.15, 0.9], "something_else": ["bite", 0.5, 0.65]}
	# Act / Assert
	for kind: String in expected:
		var got: Array = _rigs._attack_mapping(drake, kind)
		var want: Array = expected[kind]
		check(str(got[0]) == str(want[0]) and is_equal_approx(float(got[1]), float(want[1])) and is_equal_approx(float(got[2]), float(want[2])),
			"drake attack %s maps to %s (got %s)" % [kind, want, got])
	var void_rig: Dictionary = library.rig("void")
	if not void_rig.is_empty():
		check(_rigs._attack_mapping(void_rig, "beam") == ["beam", 0.3, 0.86] and _rigs._attack_mapping(void_rig, "") == ["attack", 0.55, 0.62], "the void boss keeps its mapping")


func _test_keys_flags_and_flash() -> void:
	# Arrange: a hell monster with a string id and an int uid.
	var enemy := _enemy("test_ember", 7, {"attack": "windup", "attack_kind": "swing", "attack_p": 0.5})
	# Act
	var top: float = await _draw(enemy)
	# Assert
	var a: Dictionary = _rigs._actors.get("e7", {})
	check(is_finite(top) and not a.is_empty(), "a hell rig draws, keyed by its uid")
	check(str(a.get("clip", "")) == "swing" and is_equal_approx(float(a.get("u", 0.0)), 0.15) and a.get("windows", []) == [0.3, 0.8], "the swing windup runs on the drake clip windows")
	var drawn: Dictionary = _rigs.last_drawn("e7")
	check(drawn.get("shown", {}).has("body") and drawn.get("shown", {}).has("mouth_flame") and drawn.get("glow", {}).get("throat", 0.0) > 0.0, "every part is drawn, the throat glows")
	# Hit flash on the struck part only.
	enemy = _enemy("test_ember", 7, {"hit_flash": 0.16, "hit_part": "jaw"})
	await _draw(enemy)
	var flashed: Array = Array(_rigs.last_drawn("e7").get("flashed", []))
	check(flashed.size() == 1 and str(flashed[0]) == "jaw", "the hit flash lights only the struck jaw (%s)" % [flashed])
	enemy = _enemy("test_ember", 7, {"hit_flash": 0.16})
	await _draw(enemy)
	drawn = _rigs.last_drawn("e7")
	check(drawn.get("flashed", []).size() == drawn.get("shown", {}).size(), "without hit_part the whole body flashes")
	# Flying.
	_rigs.step(0.25)
	var ground_mouth: Vector2 = _rigs.world_point("e7", "jaw", MOUTH)
	await _draw(_enemy("test_ember", 7, {"flying": true}))
	var flying_mouth: Vector2 = _rigs.world_point("e7", "jaw", MOUTH)
	check(bool(_rigs._actors.e7.flying) and flying_mouth.y < ground_mouth.y - 20.0, "a flying dragon is drawn lifted (%.1f -> %.1f)" % [ground_mouth.y, flying_mouth.y])


## The tint and alpha the host sends reach the colour every part texture is
## drawn with, and the alpha reaches the shadow (spied through draw_log).
func _test_tint_and_alpha_reach_the_canvas() -> void:
	# Arrange
	var tint := Color(1.5, 0.6, 0.6)
	await _draw(_enemy("test_ember", 15))
	_rigs.record_draws = true
	_rigs.draw_log.clear()
	# Act
	await _draw(_enemy("test_ember", 15, {"tint": [tint.r, tint.g, tint.b], "alpha": 0.5}))
	_rigs.record_draws = false
	# Assert
	var parts: Dictionary = {}
	var wrong: Array = []
	var shadow_alpha := -1.0
	for entry: Dictionary in _rigs.draw_log:
		var color: Color = entry.color
		if entry.what == "part":
			parts[entry.id] = true
			if not color.is_equal_approx(Color(tint.r, tint.g, tint.b, 0.5)) and wrong.size() < 4: wrong.append("%s %s" % [entry.id, color])
		elif entry.what == "shadow":
			shadow_alpha = color.a
	var shown: Dictionary = _rigs.last_drawn("e15").get("shown", {})
	check(not parts.is_empty() and parts.size() == shown.size(), "every shown part is drawn once with the spied colour (%d of %d)" % [parts.size(), shown.size()])
	check(wrong.is_empty(), "tint and alpha multiply the colour every part is drawn with %s" % [wrong])
	check(is_equal_approx(shadow_alpha, RigRenderer.SHADOW.a * 0.5), "the shadow fades with the figure (alpha %.3f)" % shadow_alpha)
	# Without the fields everything is drawn as authored.
	_rigs.record_draws = true
	_rigs.draw_log.clear()
	await _draw(_enemy("test_ember", 15))
	_rigs.record_draws = false
	var plain := true
	for entry: Dictionary in _rigs.draw_log:
		if entry.what == "part" and not Color(entry.color).is_equal_approx(Color.WHITE): plain = false
		if entry.what == "shadow" and not Color(entry.color).is_equal_approx(RigRenderer.SHADOW): plain = false
	check(plain, "without tint and alpha the parts and the shadow draw untouched")


## Ignaroth's draw fields (src/hell/drake_rig_host.gd): size scales the
## figure about its body centre, cut sinks it into the floor (clipped at the
## feet, nothing at full depth), shadow false drops the rig's shadow, and
## part_transforms hands out the drawn pose of the shown parts only.
func _test_size_cut_shadow_and_transforms() -> void:
	# Arrange
	await _draw(_enemy("test_ember", 31))
	var whole: Dictionary = _rigs.part_transforms("e31")
	var feet: Vector2 = _rigs._actors.e31.feet
	# Act: grown to 1.5x
	await _draw(_enemy("test_ember", 31, {"size": 1.5}))
	var grown: Dictionary = _rigs.part_transforms("e31")
	# Assert
	check(whole.has("body") and grown.has("body") and is_equal_approx(Transform2D(grown.body).x.length(), Transform2D(whole.body).x.length() * 1.5), "size 1.5 draws the rig 1.5x larger")
	check(_rigs.part_transforms("e999").is_empty(), "an unknown actor has no drawn pose")
	_rigs.record_draws = true
	_rigs.draw_log.clear()
	await _draw(_enemy("test_ember", 31, {"shadow": false}))
	check(_rigs.draw_log.filter(func(d: Dictionary) -> bool: return str(d.what) == "shadow").is_empty(), "shadow false draws no rig shadow")
	var full: int = _rigs.draw_log.filter(func(d: Dictionary) -> bool: return str(d.what) == "part").size()
	var level_y := Transform2D(_rigs.part_transforms("e31").body).origin.y
	# Half sunk: drawn lower, fewer rows; fully sunk: nothing.
	_rigs.draw_log.clear()
	var rig: Dictionary = _rigs.library.rig("test_ember")
	var height := (float(rig.ground.y) - float(rig.top) + 1.0) * float(rig.scale)
	await _draw(_enemy("test_ember", 31, {"cut": height * 0.5}))
	var half: int = _rigs.draw_log.filter(func(d: Dictionary) -> bool: return str(d.what) == "part").size()
	var sunk_y := Transform2D(_rigs.part_transforms("e31").body).origin.y
	check(half > 0 and half <= full, "half sunk the parts above the floor are still drawn (%d of %d)" % [half, full])
	# the hittable pose is what reached the canvas: a part wholly below the floor is left out
	var drawn_ids: Dictionary = {}
	for d: Dictionary in _rigs.draw_log:
		if str(d.what) == "part": drawn_ids[str(d.id)] = true
	var half_pose: Dictionary = _rigs.part_transforms("e31")
	var shown_half: Dictionary = _rigs.last_drawn("e31").get("shown", {})
	check(half_pose.keys().all(func(id: Variant) -> bool: return drawn_ids.has(str(id))) and half_pose.size() == drawn_ids.size(), "half sunk part_transforms holds exactly the parts put on the canvas (%d of %d shown)" % [half_pose.size(), shown_half.size()])
	check(RigRenderer.key_of({"uid": 31, "id": "test_ember"}) == "e31" and RigRenderer.key_of({"id": 7}) == "e7", "key_of: e + uid, else the crypt's int id")
	check(absf(sunk_y - level_y - height * 0.5) < 3.0 and is_equal_approx(Vector2(_rigs._actors.e31.feet).y, feet.y), "a cut moves the figure down by the cut (%.1f), the feet stay on the floor" % (sunk_y - level_y))
	_rigs.draw_log.clear()
	await _draw(_enemy("test_ember", 31, {"cut": height + 15.0}))
	check(_rigs.draw_log.filter(func(d: Dictionary) -> bool: return str(d.what) == "part").is_empty(), "fully sunk nothing is drawn")
	_rigs.record_draws = false
	# Lost parts are not in the drawn pose.
	_rigs.observe({"enemies": [_enemy("test_ember", 31, {"lost": ["horns"]})]})
	await _draw(_enemy("test_ember", 31, {"lost": ["horns"]}))
	var cut_pose: Dictionary = _rigs.part_transforms("e31")
	check(not cut_pose.has("horns") and cut_pose.has("head"), "part_transforms leaves lost parts out")


func _test_stumps_and_debris() -> void:
	# Arrange: drawn once whole, so the parts have a place to fall from.
	await _draw(_enemy("test_ember", 8))
	var before: int = _rigs._particles.size()
	# Act: the host reports the jaw and the arm as lost.
	var cut := _enemy("test_ember", 8, {"lost": ["jaw", "arm"], "hit_flash": 0.16, "hit_part": "arm"})
	_rigs.observe({"enemies": [cut]})
	var chips: Array = _rigs._particles.slice(before)
	await _draw(cut)
	# Assert
	var drawn: Dictionary = _rigs.last_drawn("e8")
	var shown: Dictionary = drawn.get("shown", {})
	check(not shown.has("jaw") and not shown.has("arm") and not shown.has("mouth_flame") and shown.has("head"), "lost parts and the flame on the jaw are no longer drawn")
	var stumps: Array = drawn.get("stumps", [])
	var ids: Array = stumps.map(func(s: Dictionary) -> String: return str(s.id))
	ids.sort()
	check(ids == ["arm", "jaw"], "a glowing stump marks each severed joint (%s)" % [ids])
	var world: Dictionary = _rigs._actors.e8.world
	var rig: Dictionary = _rigs.library.rig("test_ember")
	for stump: Dictionary in stumps:
		var parent := str(rig.by_id[stump.id].parent)
		var expected: Vector2 = Transform2D(world[parent]) * Vector2(rig.by_id[stump.id].pivot)
		check(Vector2(stump.at).distance_to(expected) < 0.01, "the %s stump sits at its joint on the %s" % [stump.id, parent])
	check(drawn.get("flashed", []).size() == shown.size(), "a hit on a lost part flashes the whole body")
	var debris: Array = _rigs.debris_of("e8")
	check(debris.size() == 2 and debris.all(func(d: Dictionary) -> bool: return str(d.material) == "ember"), "both cut parts fall as ember debris")
	var ember: Dictionary = RigRenderer.palette("ember")
	var table := _gore("ember")
	check(Color(ember.chips[0]).is_equal_approx(Color.html(str(table.color))) and Color(ember.chips[1]).is_equal_approx(Color.html(str(table.stain))), "ember chips are the gore table's ember colour and stain")
	check(chips.size() >= 12 and chips.all(func(p: Dictionary) -> bool: return _in(p.color, ember.chips + [ember.glow])), "the cut sprays orange and dark brown ember chips")
	# Obsidian: the gore table's obsidian colour and stain, and its glow.
	await _draw(_enemy("test_obsidian", 9))
	before = _rigs._particles.size()
	_rigs.observe({"enemies": [_enemy("test_obsidian", 9, {"lost": ["wing_far"]})]})
	var obsidian: Dictionary = RigRenderer.palette("obsidian")
	var stray: Array = []
	var from_table := 0
	for p: Dictionary in _rigs._particles.slice(before):
		if not _in(p.color, obsidian.chips + [obsidian.glow]): stray.append(Color(p.color).to_html(false))
		if _in(p.color, [Color.html(str(_gore("obsidian").get("color", "000000"))), Color.html(str(_gore("obsidian").get("stain", "000000")))]): from_table += 1
	check(stray.is_empty(), "obsidian chips come from the obsidian palette (strays %s)" % [stray])
	check(from_table > 0, "an obsidian cut sprays the gore table's obsidian colours, like a hit on it")
	check(RigRenderer.cut_colors(_rigs.library.rig("void")) == [RigRenderer.VIOLET_DARK] if not _rigs.library.rig("void").is_empty() else true, "void chips stay violet")


## A cut reels the dragon for STAGGER_TIME; a hit landing meanwhile does not
## cut the stagger short.
func _test_cut_staggers() -> void:
	# Arrange
	await _draw(_enemy("test_ember", 13))
	# Act
	_rigs.observe({"enemies": [_enemy("test_ember", 13, {"lost": ["horns"]})]})
	var a: Dictionary = _rigs._actors.e13
	var clip := str(a.clip)
	var length := float(a.clip_len)
	_rigs.step(0.1)
	_rigs.observe({"enemies": [_enemy("test_ember", 13, {"lost": ["horns"], "hits": 1})]})
	# Assert
	check(clip == "hit" and is_equal_approx(length, RigRenderer.STAGGER_TIME), "cutting off a part staggers the dragon for %.1f s (%s, %.2f s)" % [RigRenderer.STAGGER_TIME, clip, length])
	check(str(a.clip) == "hit" and is_equal_approx(float(a.clip_len), RigRenderer.STAGGER_TIME) and float(a.ct) > 0.05, "a hit during the stagger does not cut it short")
	await _draw(_enemy("test_ember", 13, {"lost": ["horns"], "hits": 1}))
	check(str(a.clip) == "hit" and float(a.u) > 0.05 and float(a.u) < 0.2, "the stagger plays as the hit clip over its length (u %.2f)" % float(a.u))


func _test_world_point() -> void:
	# Arrange
	var enemy := _enemy("test_ember", 10)
	await _draw(enemy)
	var first: Vector2 = _rigs.world_point("e10", "jaw", MOUTH)
	var expected: Vector2 = Transform2D(_rigs._actors.e10.world.jaw) * MOUTH
	# Act: the idle sway moves on.
	_rigs.step(0.6)
	await _draw(enemy)
	var second: Vector2 = _rigs.world_point("e10", "jaw", MOUTH)
	# Assert
	check(first.distance_to(expected) < 0.01, "world_point maps the source point through the part as drawn")
	check(first.distance_to(second) > 0.5, "world_point follows the pose (%.2f px)" % first.distance_to(second))
	check(absf(first.x - (AT.x + (MOUTH.x - 11.0) * 5.0)) < 20.0 and first.y < AT.y, "the mouth point lies at the dragon's mouth (%s)" % first)
	check(_rigs.world_point("e999", "jaw", MOUTH) == Vector2.ZERO, "an unknown actor gives Vector2.ZERO")
	check(_rigs.world_point("e10", "no_such_part", MOUTH) == Vector2(_rigs._actors.e10.feet), "an unknown part gives the feet")
	_rigs.observe({"enemies": [_enemy("test_ember", 10, {"lost": ["jaw"]})]})
	await _draw(_enemy("test_ember", 10, {"lost": ["jaw"]}))
	var on_head: Vector2 = _rigs.world_point("e10", "jaw", MOUTH)
	check(on_head.distance_to(Transform2D(_rigs._actors.e10.world.head) * MOUTH) < 0.01, "a lost part's point rides on its parent")


## The tail whirl spins the figure about its vertical axis: at mid-strike the
## dragon faces the other way (its mouth behind the feet), and faces back after.
func _test_whirl_turns() -> void:
	# Arrange
	await _draw(_enemy("test_ember", 14))
	var facing: float = _rigs.world_point("e14", "jaw", MOUTH).x - AT.x
	# Act: the middle of the active phase, then the recovery's end.
	await _draw(_enemy("test_ember", 14, {"attack": "active", "attack_kind": "swing", "attack_p": 0.5}))
	var spun: float = _rigs.world_point("e14", "jaw", MOUTH).x - AT.x
	await _draw(_enemy("test_ember", 14, {"attack": "recover", "attack_kind": "swing", "attack_p": 1.0}))
	var back: float = _rigs.world_point("e14", "jaw", MOUTH).x - AT.x
	# Assert
	check(facing > 10.0 and spun < -10.0 and back > 10.0, "the tail whirl turns the dragon round and back (mouth %.1f -> %.1f -> %.1f px from the feet)" % [facing, spun, back])


func _test_death() -> void:
	# Arrange
	await _draw(_enemy("test_ember", 11))
	var dying := _enemy("test_ember", 11, {"dying_p": 0.0})
	# Act
	_rigs.observe({"enemies": [dying]})
	await _draw(dying)
	# Assert
	var a: Dictionary = _rigs._actors.e11
	var shed: Array = a.shed.keys()
	shed.sort()
	check(shed == ["horns", "jaw", "tail_2", "tail_flame", "wing_far", "wing_near"], "the dying dragon sheds wings, horns, jaw and tail (%s)" % [shed])
	var shown: Dictionary = _rigs.last_drawn("e11").get("shown", {})
	check(shown.has("body") and shown.has("neck") and shown.has("head") and not shown.has("wing_far") and not shown.has("mouth_flame"), "body, neck and head stay and collapse")
	check(_rigs.debris_of("e11").size() == 6, "every shed part falls as debris")
	check(str(a.clip) == "death", "the death pose plays")


## Ignaroth keeps its uid across its forms: the next form (another rig) or a
## figure back from dying arrives complete, nothing lost, shed or regrowing,
## with no regrowth burst and no debris.
func _test_new_form_starts_complete() -> void:
	# Arrange: form A loses its jaw.
	await _draw(_enemy("test_ember", 12))
	_rigs.observe({"enemies": [_enemy("test_ember", 12, {"lost": ["jaw"]})]})
	await _draw(_enemy("test_ember", 12, {"lost": ["jaw"]}))
	var debris_before: int = _rigs._debris.size()
	var before: int = _rigs._particles.size()
	# Act: the same uid comes back as the next form, whole.
	_rigs.observe({"enemies": [_enemy("test_obsidian", 12)]})
	var added: int = _rigs._particles.size() - before
	await _draw(_enemy("test_obsidian", 12))
	# Assert
	var a: Dictionary = _rigs._actors.e12
	check(a.lost.is_empty() and a.regrowing.is_empty() and a.shed.is_empty(), "the next form has nothing lost, shed or regrowing (regrowing %s)" % [a.regrowing.keys()])
	check(added == 0 and _rigs._debris.size() == debris_before, "the next form arrives without a regrowth burst or debris (%d particles)" % added)
	var shown: Dictionary = _rigs.last_drawn("e12").get("shown", {})
	check(shown.has("jaw") and shown.has("mouth_flame") and str(a.clip) == "", "the next form draws whole, no clip carried over")
	# A form change through dying: the dying form sheds, the next one is whole.
	_rigs.observe({"enemies": [_enemy("test_obsidian", 12, {"dying_p": 0.0})]})
	await _draw(_enemy("test_obsidian", 12, {"dying_p": 0.0}))
	var was_shed: int = a.shed.size()
	_rigs.observe({"enemies": [_enemy("test_ember", 12)]})
	await _draw(_enemy("test_ember", 12))
	shown = _rigs.last_drawn("e12").get("shown", {})
	check(was_shed > 0 and a.shed.is_empty() and not bool(a.dying) and shown.has("wing_far") and shown.has("tail_2") and str(a.clip) == "", "a form reached through dying draws whole (shed %d -> %d)" % [was_shed, a.shed.size()])
	# Same rig, back from dying.
	_rigs.observe({"enemies": [_enemy("test_ember", 12, {"dying_p": 0.3})]})
	_rigs.observe({"enemies": [_enemy("test_ember", 12)]})
	check(a.shed.is_empty() and not bool(a.dying), "a figure back from dying is whole again")


func _test_crypt_void(library: RefCounted) -> void:
	if library.rig("void").is_empty():
		check(false, "the crypt rigs load (assets/data/rigs.json)")
		return
	# Arrange: a crypt void boss as the crypt snapshot sends it (int id, no uid).
	var boss := {"rig": "void", "id": 42, "x": AT.x, "y": AT.y, "face": -1.0, "hits": 0, "lost": [], "dying_p": -1.0, "hit_flash": 0.16}
	# Act
	_rigs.observe({"enemies": [boss]})
	_rigs.record_draws = true
	_rigs.draw_log.clear()
	var top: float = await _draw(boss)
	_rigs.record_draws = false
	# Assert
	var drawn: Dictionary = _rigs.last_drawn("e42")
	check(is_finite(top) and drawn.get("shown", {}).has("core") and drawn.get("shown", {}).has("eye"), "the crypt void boss still draws")
	check(drawn.get("stumps", []).is_empty() and drawn.get("flashed", []).size() == drawn.get("shown", {}).size(), "no stumps on crypt rigs, the hit flash lights the whole body")
	check(Color(drawn.get("tint", Color.BLACK)).is_equal_approx(Color.WHITE), "crypt rigs draw untinted")
	var shadow: Array = _rigs.draw_log.filter(func(e: Dictionary) -> bool: return e.what == "shadow")
	check(shadow.size() == 1 and Color(shadow[0].color).is_equal_approx(RigRenderer.SHADOW), "the crypt shadow is unchanged")
	# Crypt rigs keep the short hit clip and never stagger.
	boss.hits = 1
	boss.hit_flash = 0.0
	_rigs.observe({"enemies": [boss]})
	check(str(_rigs._actors.e42.clip) == "hit" and is_equal_approx(float(_rigs._actors.e42.clip_len), RigRenderer.HIT_TIME), "a crypt hit still plays the %.1f s hit clip" % RigRenderer.HIT_TIME)
	boss.lost = ["claw_l"]
	_rigs.observe({"enemies": [boss]})
	check(is_equal_approx(float(_rigs._actors.e42.clip_len), RigRenderer.HIT_TIME), "a crypt rig does not stagger when it loses a part")


## The hell palettes come from vfx_gore.json (color, stain); MATERIALS fills
## what the table leaves out and stands in when the table is missing.
func _test_palette_from_gore_table() -> void:
	# Arrange / Act
	RigRenderer.load_gore()
	var ember: Dictionary = RigRenderer.palette("ember")
	var obsidian: Dictionary = RigRenderer.palette("obsidian")
	# Assert
	for pair: Array in [["ember", ember], ["obsidian", obsidian]]:
		var table := _gore(pair[0])
		var colors: Dictionary = pair[1]
		check(not table.is_empty() and Color(colors.chips[0]).is_equal_approx(Color.html(str(table.color))) and Color(colors.chips[1]).is_equal_approx(Color.html(str(table.stain))),
			"%s chips are vfx_gore.json's colour and stain (%s)" % [pair[0], colors.chips])
		var glow: Color = Color.html(str(table.glow)) if table.has("glow") else RigRenderer.MATERIALS[pair[0]].glow
		check(Color(colors.glow).is_equal_approx(glow) and Array(colors.wound).size() == 3, "%s glow and wound come from the table or the fallback" % pair[0])
	check(RigRenderer.palette("").is_empty(), "a rig without material (crypt) has no palette")
	print("palettes: ember chips %s, obsidian chips %s (vfx_gore.json), obsidian glow %s" % [_html(ember.chips), _html(obsidian.chips), Color(obsidian.glow).to_html(false)])
	# Without the table the fallbacks stand in.
	RigRenderer.load_gore("res://assets/data/no_such_gore_table.json")
	var spare: Dictionary = RigRenderer.palette("obsidian")
	check(Color(spare.chips[0]).is_equal_approx(RigRenderer.MATERIALS.obsidian.color) and Color(spare.chips[1]).is_equal_approx(RigRenderer.MATERIALS.obsidian.stain), "without vfx_gore.json obsidian falls back to dark violet")
	RigRenderer.load_gore()


func _html(colors: Array) -> String:
	return ", ".join(colors.map(func(c: Color) -> String: return c.to_html(false)))

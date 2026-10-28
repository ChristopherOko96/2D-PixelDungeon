extends SceneTree
## Archer and mage attack visuals (src/vfx/attack_fx.gd): which shots it
## draws, the colour each shot takes (weapon glow before element before
## default), a release flash for each new shot, a trail that follows the
## shot's real path and stays bounded, a burst when a shot ends, light while it
## flies, and that every found bow and staff has its own glow in items.json.

const AttackFx = preload("res://src/vfx/attack_fx.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("ATTACK_FX_FAIL: ", label)


func _initialize() -> void:
	_test_handles_and_tints()
	_test_release_trail_and_impact()
	_test_weapon_glows()
	print("ATTACK_FX checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _bullet(id: int, point: Vector2, style: String, extra: Dictionary = {}) -> Dictionary:
	var bullet := {"id": id, "x": point.x, "y": point.y, "vx": 600.0, "vy": 0.0, "owner": 1, "style": style, "element": "", "critical": false}
	bullet.merge(extra, true)
	return bullet


func _test_handles_and_tints() -> void:
	check(AttackFx.handles(_bullet(1, Vector2.ZERO, "arrow")) and AttackFx.handles(_bullet(2, Vector2.ZERO, "magic")), "hero arrows and spells are drawn here")
	check(not AttackFx.handles(_bullet(3, Vector2.ZERO, "arrow", {"owner": 0})), "enemy arrows are not")
	check(not AttackFx.handles(_bullet(4, Vector2.ZERO, "fireball")), "skill projectiles keep their own look")
	var frost := _bullet(5, Vector2.ZERO, "magic", {"element": "frost"})
	check(AttackFx.tint_for(frost, {}) == AttackFx.ELEMENT_TINTS.frost, "without a weapon glow the element colours the shot")
	check(AttackFx.tint_for(frost, {"glow": "ffd75a"}) == Color("ffd75a"), "a found weapon's glow wins over the element")
	check(AttackFx.tint_for(_bullet(6, Vector2.ZERO, "arrow"), {}) == AttackFx.ARROW_TINT, "a plain arrow keeps the default tint")


func _test_release_trail_and_impact() -> void:
	var view := AttackFx.new()
	var players := {1: {"glow": "b46cf0"}}
	view.observe({"players": players, "bullets": [_bullet(10, Vector2(100, 100), "arrow")]}, 0.0)
	check(view._flashes.size() == 1 and str(view._flashes[0].kind) == "bow", "a new arrow flashes at the bow")
	check(Color(view._tracks[10].tint) == Color("b46cf0"), "the shot remembers its weapon colour")
	for step in range(1, 40):
		view.observe({"players": players, "bullets": [_bullet(10, Vector2(100 + step * 10, 100), "arrow")]}, step * 0.016)
	var path: PackedVector2Array = view._tracks[10].path
	var length := 0.0
	for index in range(path.size() - 1): length += path[index].distance_to(path[index + 1])
	check(length <= AttackFx.CRIT_STREAK + 34.0, "the kept path stays short (%.0f px)" % length)
	var trail: PackedVector2Array = view._trail(10, Vector2(490, 100), AttackFx.STREAK)
	check(trail.size() > 5 and trail[trail.size() - 1].x < 490.0 and trail[trail.size() - 1].x >= 490.0 - AttackFx.STREAK - 1.0, "the streak runs back along the flight, no longer than its length")
	check(Array(trail).all(func(point: Vector2) -> bool: return is_equal_approx(point.y, 100.0)), "the streak lies on the path the arrow flew")
	# A young shot's streak never reaches behind the bow.
	view.observe({"players": players, "bullets": [_bullet(10, Vector2(490, 100), "arrow"), _bullet(11, Vector2(300, 200), "magic")]}, 0.7)
	var young: PackedVector2Array = view._trail(11, Vector2(306, 200), AttackFx.ORB_TRAIL)
	check(young[young.size() - 1].x >= 299.0, "a fresh spell's trail starts at the staff")
	var lights: Array = view.lights({"bullets": [_bullet(11, Vector2(300, 200), "magic")]}, func(bullet: Dictionary) -> Vector2: return Vector2(float(bullet.x), float(bullet.y)))
	check(lights.any(func(light: Vector4) -> bool: return is_equal_approx(light.x, 300.0) and light.z >= 60.0), "a flying spell lights the dark around it")
	var before := view._flashes.size()
	view.observe({"players": players, "bullets": [_bullet(11, Vector2(320, 200), "magic")]}, 0.72)
	check(not view._tracks.has(10) and view._flashes.any(func(flash: Dictionary) -> bool: return str(flash.kind) == "pierce"), "a shot that ends bursts where it was")
	view.observe({"players": players, "bullets": []}, 0.74)
	check(view._flashes.any(func(flash: Dictionary) -> bool: return str(flash.kind) == "nova"), "a spell that ends bursts in a nova")
	view.observe({"players": players, "bullets": []}, 5.0)
	check(view._flashes.is_empty() and view._tracks.is_empty(), "flashes fade and nothing is kept")
	# A shot unseen for a while (effects hidden) does not burst late.
	view.observe({"players": players, "bullets": [_bullet(12, Vector2(0, 0), "arrow")]}, 6.0)
	view._flashes.clear()
	view.observe({"players": players, "bullets": []}, 9.0)
	check(view._flashes.is_empty(), "a stale shot vanishes without a burst")
	var _unused := before


func _test_weapon_glows() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/items.json"))
	var ranged: Array = data.weapons.filter(func(weapon: Dictionary) -> bool: return str(weapon["class"]) in ["archer", "mage"] and not bool(weapon.get("start", false)) and str(weapon.rarity) != "common" or str(weapon.id) in ["hunting_bow", "ruby_staff"])
	check(ranged.all(func(weapon: Dictionary) -> bool: return Color.html_is_valid(str(weapon.get("glow", "")))), "every found bow and staff has its own glow colour")
	var colours := {}
	for weapon: Dictionary in ranged: colours[str(weapon.glow)] = true
	check(colours.size() >= 12, "the glows differ (%d colours)" % colours.size())
	check(ResourceLoader.exists("res://assets/sprites/fx/spell_orb.png") and ResourceLoader.exists("res://assets/sprites/fx/spell_burst.png"), "the neutral orb and burst sheets exist for tinting")

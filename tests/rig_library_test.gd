extends SceneTree
## Part rigs (src/rig/rig_library.gd, assets/data/rigs.json): every approved
## figure loads with its parts and items, part areas map world points the way
## the figure is drawn (2x, mirrored by facing), and exposed parts (the
## Leerenrufer's eye) only count while their action runs.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const EXPECTED := ["knight", "elf", "wizard", "skeleton", "skel_archer", "skel_guard", "necro", "tiny_zombie", "ice_zombie", "big_zombie", "frost_corpse", "bone_colossus", "void", "bomber"]
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RIG_LIBRARY_FAIL: ", description)

func _initialize() -> void:
	var library = RigLibrary.new()
	check(library.load_data(), "rigs.json loads")
	for name: String in EXPECTED:
		var rig: Dictionary = library.rig(name)
		check(not rig.is_empty(), "%s rig exists" % name)
		if rig.is_empty(): continue
		check(not rig.parts.is_empty(), "%s has parts" % name)
		for part: Dictionary in rig.parts + rig.items:
			check(part.texture is Texture2D and part.white is Texture2D, "%s.%s has a texture and a flash silhouette" % [name, part.id])
			check(Rect2(part.bounds).has_area(), "%s.%s owns pixels" % [name, part.id])
	# Skeleton: the skull is vital, the sword disables the attack.
	var skeleton: Dictionary = library.rig("skeleton")
	check(bool(skeleton.by_id.skull.vital) and str(skeleton.by_id.weapon.disables) == "attack", "skeleton: skull vital, sword disables the attack")
	check(skeleton.by_id.torso.also_detach == ["leg_l", "leg_r"], "skeleton: losing the torso also drops both legs")
	var weights: Dictionary = library.weights("skeleton")
	check(weights.size() == 5 and is_equal_approx(weights.skull, 3.0), "skeleton weights: 2 legs, torso, skull and sword")
	# Mapping: a point at the skull's centre (drawn 2x) is the skull, low points are legs.
	var origin := Vector2(400, 300)
	var alive := {"leg_l": true, "leg_r": true, "torso": true, "skull": true, "weapon": true}
	var skull_world := _world(library, "skeleton", origin, 1.0, skeleton.by_id.skull.center)
	check(library.part_at("skeleton", origin, 1.0, skull_world, alive) == "skull", "a hit at the skull's centre is a skull hit")
	var leg_world := _world(library, "skeleton", origin, 1.0, skeleton.by_id.leg_r.center)
	check(library.part_at("skeleton", origin, 1.0, leg_world, alive) == "leg_r", "a hit at the right leg is a leg hit")
	var mirrored := _world(library, "skeleton", origin, -1.0, skeleton.by_id.leg_r.center)
	check(mirrored.x < origin.x + 1.0 and library.part_at("skeleton", origin, -1.0, mirrored, alive) == "leg_r", "facing left mirrors the part areas")
	alive.erase("skull")
	check(library.part_at("skeleton", origin, 1.0, skull_world, alive) == "", "a destroyed skull is no longer hit")
	check(library.nearest_part("skeleton", origin, 1.0, skull_world, alive) != "", "the nearest living part is found for area damage")
	# Leerenrufer: the eye counts only during the beam.
	var void_rig: Dictionary = library.rig("void")
	check(void_rig.by_id.core.frames.size() == 8 and void_rig.by_id.eye.frames.size() == 3, "void: 8 body frames and 3 eye states")
	var void_alive := {"core": true, "eye": true, "claw_l": true, "claw_r": true}
	var eye_world := _world(library, "void", origin, 1.0, void_rig.eye_center)
	check(library.part_at("void", origin, 1.0, eye_world, void_alive) == "core", "outside the beam the closed eye is part of the core")
	check(library.part_at("void", origin, 1.0, eye_world, void_alive, "beam") == "eye", "during the beam the open eye is hit")
	var total := 0.0
	for weight: float in library.weights("void").values(): total += weight
	check(is_equal_approx(total, 140.0), "void weights add up to 140 like the review page")
	check(library.rig("bomber").by_id.skull.frames.size() == 8 and bool(library.rig("bomber").by_id.skull.vital), "bomber: one vital skull, 8 frames")
	check(RigLibrary.shared() == RigLibrary.shared(), "one shared library per process")
	print("RIG_LIBRARY checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)

## Inverse of RigLibrary.to_source for a source point.
func _world(library, name: String, origin: Vector2, face: float, source: Vector2) -> Vector2:
	var rig: Dictionary = library.rig(name)
	return Vector2(origin.x + (source.x - rig.ground.x) * 2.0 * (-1.0 if face < 0 else 1.0), origin.y + (source.y - rig.center.y - rig.hover) * 2.0)
